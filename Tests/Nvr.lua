-- Nvr.lua

--[[
Implements the Nvr library, providing (synchronous) access to a real device

Provides a Device class, representing a single device, created by calling this module's connect() method.
The Device class implements methods for sending and receiving requests to and from the device; each call
is blocking.
--]]





--- LuaSocket is used for the network communication
local socket = require("socket")

--- Json parsing and serializing is required
local json = require("dkjson")

-- Load the utilities:
dofile("NvrUtils.lua")





--- This module itself (returned by requiring this file)
-- Contains the entrypoints to create Device objects
local Nvr = {}





--- Class prototype representing a single TCP connection to a device
-- Provides the functions available to the objects of this class
local Connection =
{
	-- The socket to be used for communicating with the device (will be set by Nvr.connect())
	mSocket = nil,

	-- The session ID reported by the device (will be set by Device:login())
	mSessionID = 0,

	-- The sequence number of the next packet to send
	mSequenceNum = 0,
}
Connection.__index = Connection





--- Connects to the specified hostname and port
-- Doesn't send any information yet.
-- Returns a Connection object on success, nil and error message on failure
function Nvr.connect(aHostName, aPort)
	assert(type(aHostName) == "string")
	assert(type(aPort) == "number")
	assert(aPort > 0)
	assert(aPort < 65536)

	-- Connect the socket:
	local skt = socket.tcp()
	local isSuccess, msg = skt:connect(aHostName, aPort)
	if not(isSuccess) then
		return nil, msg
	end

	-- Create a new Connection instance:
	local res = {mSocket = skt}
	setmetatable(res, Connection)

	return res
end





--- Sends the specified request through the connection
-- The payload can be either a direct string to send, or a table, which will be first converted to JSON
-- Returns true on success, nil and message on failure
function Connection:sendRequest(aMessageType, aPayload)
	assert(type(aMessageType) == "number")
	assert((type(aPayload) == "string") or (type(aPayload) == "table"))
	assert(type(self.mSocket) == "userdata")  -- We need a valid socket

	-- If the payload is a table, JSON-encode it first:
	if (type(aPayload) == "table") then
		aPayload = json.encode(aPayload)
	end

	-- Send the data:
	local isSuccess, msg
	isSuccess, msg = self.mSocket:send(serializeHeader(self.mSessionID, self.mSequenceNum, aMessageType, string.len(aPayload)))
	if not(isSuccess) then
		return nil, "Failed to send the header: " .. tostring(msg)
	end
	isSuccess, msg = self.mSocket:send(aPayload)
	if not(isSuccess) then
		return nil, "Failed to send the payload: " .. tostring(msg)
	end
	self.mSequenceNum = self.mSequenceNum + 1
	return true
end





--- Receives a single JSON response from the device on the Connection
-- Returns the response as a table parsed from JSON and the message type indicated in the protocol on success
-- Returns nil and message on failure
-- Note that responses from the device that indicate a device-side error (the Ret field) are still
-- reported as success; use Connection:checkResponse() to process those
function Connection:receiveResponse()
	-- Receive the response data:
	local resp, msg = self:receiveResponseData()
	if not(resp) then
		return nil, "Failed to receive response data: " .. tostring(msg)
	end
	local messageType = msg

	-- Parse into JSON:
	local res
	res, msg = json.decode(resp)
	if not(res) then
		return nil, "Failed to parse the response: " .. tostring(msg)
	end

	return res, messageType
end





--- Receives a single response from the device on the Connection
-- If aAllowLargePayload is true, doesn't check the PayloadLength
-- Returns the response as a raw string and the message type indicated in the protocol on success
-- Returns nil and message on failure
function Connection:receiveResponseData(aAllowLargePayload)
	assert(not(aAllowLargePayload) or (aAllowLargePayload == true))

	-- Receive the header:
	local hdr, msg = self.mSocket:receive(20)
	if not(hdr) then
		return nil, "Failed to receive response header: " .. tostring(msg)
	end
	local parsedHdr = parseHeader(hdr)
	if (parsedHdr.Head ~= 0xff) then
		return nil, "Not a NetSurveillance protocol, the header is wrong"
	end
	if (parsedHdr.MessageType > 2000) then
		return nil, "Not a NetSurveillance protocol, the MessageType is too large"
	end
	if not(aAllowLargePayload) then
		if (parsedHdr.PayloadLength > 65536) then
			return nil, "Not a NetSurveillanceProtocol, the PayloadLength is too large"
		end
	end

	-- Receive the body
	if (parsedHdr.PayloadLength == 0) then
		return "", parsedHdr.MessageType
	end
	local body
	body, msg = self.mSocket:receive(parsedHdr.PayloadLength)
	if not(body) then
		return nil, "Failed to receive response data: " .. tostring(msg)
	end
	return body, parsedHdr.MessageType
end





--- Checks if the response contains an error code
-- Returns the response and message type from the params if the response contains Ret = Error.Success
-- Returns nil and the error description on failure
-- Returns nil and message type if the response is nil
-- The message type is not directly used for checking, but it allows chaining the function together with Device:receiveResponse():
-- local resp, msgType = conn:checkResponse(conn:receiveResponse())
function Connection:checkResponse(aResponse, aMessageType)
	-- If the response is not set, assume chaining from a failed receiveResponse() and relay:
	if (aResponse == nil) then
		return nil, aMessageType
	end

	assert(type(aResponse) == "table")
	assert(type(aMessageType) == "number")

	-- Check the Ret field:
	if (aResponse.Ret == nil) then
		return nil, "The response doesn't contain a return code"
	end
	if (type(aResponse.Ret) ~= "number") then
		return nil, "The response's return code is not a number"
	end
	if (isSuccessCode(aResponse.Ret)) then
		return aResponse, aMessageType
	end
	return nil, "The device returned error code: " .. errorToString(aResponse.Ret)
end





--- Receives a response and checks its Ret field for errors
-- On success, returns true, the message type from the header and the parsed response
-- On failure, returns nil, the error message and optionally the parsed response
function Connection:receiveAndCheckResponse()
	-- Receive the response:
	local resp, msg = self:receiveResponse()
	if not(resp) then
		return nil, msg
	end
	local msgType = msg

	-- Check the response:
	local isSuccess
	isSuccess, msg = self:checkResponse(resp, msgType)
	if not(isSuccess) then
		return nil, msg, resp
	end

	return true, msgType, resp
end





--- Sends the login request to the device and parses the response.
-- aPasswordHash is the SofiaHash of the real password
-- Returns the device's response (parsed into a table) and stores the mSessionID on success
-- On failure, returns nil, error message and possibly device's response as a table parsed from JSON
function Connection:login(aUsername, aPasswordHash)
	assert(type(aUsername) == "string")
	assert(type(aPasswordHash) == "string")
	assert(string.len(aPasswordHash) == 8)  -- The hash is always 8 characters long
	assert(type(self.mSocket) == "userdata")  -- We need a valid socket

	-- Send the login request:
	local isSuccess, msg = self:sendRequest(MessageType.Login_Req,
		{
			LoginType = "DVRIP-Web",
			EncryptType = "MD5",
			UserName = aUsername,
			PassWord = aPasswordHash,
		}
	)
	if not(isSuccess) then
		return nil, msg
	end

	-- Receive the response:
	local resp, msgType
	isSuccess, msgType, resp = self:receiveAndCheckResponse()
	if (resp and resp.SessionID) then
		self.mSessionID = tonumber(resp.SessionID)  -- Store the SessionID even on failure - if it is present, we want it
	end
	if not(isSuccess) then
		return nil, msgType, resp
	end

	-- Check the SessionID:
	if not(resp.SessionID) then
		return nil, "The response is missing the SessionID value", resp
	end
	if not(self.mSessionID) then
		return nil, "The response's SessionID is not a number", resp
	end

	return resp
end





--- Enumerates the channel titles
-- Returns an array-table of the channel titles on success
-- On failure, returns nil, message and possibly the device's response as a table parsed from JSON
function Connection:enumChannelTitles()
	assert(type(self.mSocket) == "userdata")  -- We need a valid socket

	-- Send the request:
	local isSuccess, msg = self:sendRequest(MessageType.ConfigChannelTitleGet_Req,
		{
			Name = "ChannelTitle",
			SessionID = string.format("0x%x", self.mSessionID),
		}
	)
	if not(isSuccess) then
		return nil, msg
	end

	-- Receive the response:
	local resp, msgType
	isSuccess, msgType, resp = self:receiveAndCheckResponse()
	if not(isSuccess) then
		return nil, msgType, resp
	end

	-- Process the response:
	if not(resp.ChannelTitle) then
		return nil, "The response is missing the ChannelTitle value", resp
	end
	if ((type(resp.ChannelTitle) ~= "table") or not(resp.ChannelTitle[1])) then
		return nil, "The response's ChannelTitle value is not an array", resp
	end

	return resp.ChannelTitle
end





return Nvr
