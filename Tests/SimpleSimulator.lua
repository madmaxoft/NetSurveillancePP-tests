#!/usr/bin/env lua

--- SimpleSimulator.lua
--[[
A script that works as a simple DVR simulator. It is used for testing the NetSurveillancePp library
implementation of the DVR protocol.
It can be run either manually to provide the counter-piece for manual testing, or it can be run
through the SimpleSimulatorDriver script that starts it in tandem with a tested program.

The simulator accepts a hard-coded login of goodUser / goodPassword, it refuses any other combination.

The following cmdline params are accepted:
--use-timeout - Set a 10-second timeout on the server socket; exits if there's no incoming connection within that time.
--singleshot - Only accept 1 connection, then exits
--]]




local socket = require("socket")
local json = require("dkjson")
dofile("NvrUtils.lua")

--- Specifies whether the server should only accept a single connection.
-- Set by the "--singleshot" cmdline param
local gIsSingleShot = false

--- The Session ID to be reported to the library
local gSessionID = 0

--- The Sequence number to be used for the protocol. Incremented after each packet sent.
local gSequenceNum = 0

--- True if the client logged in successfully, false if not.
local gIsLoggedIn = false

-- The cmdline args provided to this script
local args = {...}





--- Sends the specified payload over the socket
local function sendPayload(aClient, aMessageType, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aMessageType) == "number")
	assert((type(aPayload) == "string") or (type(aPayload) == "table"))

	-- If the payload is a table, JSON-encode it first:
	if (type(aPayload) == "table") then
		aPayload = json.encode(aPayload)
	end

	-- Send the data:
	aClient:send(serializeHeader(gSessionID, gSequenceNum, aMessageType, string.len(aPayload)))
	aClient:send(aPayload)
	gSequenceNum = gSequenceNum + 1
end





--- Processes a login-request payload
-- Checks the login, if correct, sends the OK response
local function processPayloadLoginReq(aClient, aHeader, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aHeader) == "table")
	assert(type(aPayload) == "string")

	print("Received a Login req")
	gSessionID = 0x0000000d;

	local j = assert(json.decode(aPayload))
	if ((j.UserName ~= "goodUser") or (j.EncryptType ~= "MD5") or (j.PassWord ~= "HfhyFPRN")) then
		print("Bad username, password or encryption, refusing login")
		sendPayload(aClient, MessageType.Login_Resp, {Ret = Error.BadUsernameOrPassword})
		aClient:close()
		return
	end

	print("Access allowed.")
	gIsLoggedIn = true
	return sendPayload(aClient, MessageType.Login_Resp, '{ "AliveInterval" : 21, "ChannelNum" : 4, "DataUseAES" : false, "DeviceType " : "HVR", "ExtraChannel" : 0, "Ret" : 100, "SessionID" : "0x0000000D" }')
end





--- Sends back the keepalive "pong" packet.
local function processPayloadKeepAlive(aClient, aHeader, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aHeader) == "table")
	assert(type(aPayload) == "string")

	return sendPayload(aClient, MessageType.KeepAlive_Resp, '{ "Ret" : 100, "SessionID" : "0x0000000D" }')
end





local function processPayloadConfigChannelTitleGet(aClient, aHeader, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aHeader) == "table")
	assert(type(aPayload) == "string")

	-- User needs to be logged in:
	if not(gIsLoggedIn) then
		print("Cannot send ChannelTitle response, not logged in.")
		return sendPayload(aClient, MessageType.ConfigChannelTitleGet_Resp, {Ret = Error.UserNotLoggedIn})
	end

	-- We only support the ChannelTitle request:
	local j = assert(json.decode(aPayload))
	if (j.Name ~= "ChannelTitle") then
		print("Cannot send ChannelTitle response, requesting unknown Name: " .. tostring(j.Name))
		return sendPayload(aClient, MessageType.ConfigChannelTitleGet_Resp, {Ret = Error.IllegalRequest})
	end

	-- Send a valid ChannelTitle response:
	print("Sending an example ChannelTitle response.")
	return sendPayload(aClient, MessageType.ConfigChannelTitleGet_Resp,
		{
			Ret = Error.Success,
			Name = "ChannelTitle",
			ChannelTitle =
			{
				"Channel 1",
				"Channel 2",
				"Channel 3",
				"Channel 4"
			}
		}
	)
end





--- Processes the payload
local function processPayload(aClient, aHeader, aPayload)
	assert(type(aHeader) == "table")
	assert(type(aHeader.MessageType) == "number")
	assert(type(aPayload) == "string")

	if (aHeader.MessageType == MessageType.Login_Req) then
		return processPayloadLoginReq(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.KeepAlive_Req) then
		return processPayloadKeepAlive(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.ConfigChannelTitleGet_Req) then
		return processPayloadConfigChannelTitleGet(aClient, aHeader, aPayload)
	-- TODO: Other message types
	end
end





local function simulateClient(aClient)
	assert(type(aClient) == "userdata")

	while (true) do
		local header = parseHeader(assert(aClient:receive(20)))
		print("Received a header, want payload: " .. header.PayloadLength .. " bytes")
		local payload
		if (header.PayloadLength > 0) then
			payload = assert(aClient:receive(header.PayloadLength))
		else
			payload = ""
		end
		processPayload(aClient, header, payload)
	end
end





-- Simulate:
local server = assert(socket.bind("localhost", 34567))
for _, arg in ipairs(args) do
	if (arg == "--use-timeout") then
		server:settimeout(10)
	end
	if (arg == "--singleshot") then
		gIsSingleShot = true
	end
end
print("Simulator ready.\n\n")
io.output():flush()
while (true) do
	local client = assert(server:accept())
	local res, msg = pcall(simulateClient, client)
	if (gIsSingleShot) then
		return
	end
end
