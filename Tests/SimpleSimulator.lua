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

--- Specifies whether the server should only accept a single connection.
-- Set by the "--singleshot" cmdline param
local gIsSingleShot = false

--- The Session ID to be reported to the library
local gSessionID = 0

--- The Sequence number to be used for the protocol. Incremented after each packet sent.
local gSequenceNum = 0

-- The cmdline args provided to this script
local args = {...}

-- Message types used by the protocol:
local MESSAGETYPE_LOGIN_REQ = 999
local MESSAGETYPE_LOGIN_RESP = 1000





--- Parses raw 4 bytes into a 32-bit number
local function parseUint32(aRawData)
	assert(type(aRawData) == "string")
	assert(string.len(aRawData) == 4)

	return
		string.byte(aRawData, 1) +
		string.byte(aRawData, 2) * 256 +
		string.byte(aRawData, 3) * 65536 +
		string.byte(aRawData, 4) * 256 * 65536
end





--- Parses raw 2 bytes into a 16-bit number
local function parseUint16(aRawData)
	assert(type(aRawData) == "string")
	assert(string.len(aRawData) == 2)

	return
		string.byte(aRawData, 1) +
		string.byte(aRawData, 2) * 256
end





--- Serializes the 16-bit number into 2 raw bytes of the on-wire protocol
local function writeUint16(aValue)
	assert(type(aValue) == "number")
	assert(aValue >= 0)
	assert(aValue < 65536)

	return string.char(
		aValue % 256,
		math.floor(aValue / 256) % 256
	)
end





--- Serializes the 32-bit number into 4 raw bytes of the on-wire protocol
local function writeUint32(aValue)
	assert(type(aValue) == "number")
	assert(aValue >= 0)

	return string.char(
		aValue % 0xff,
		math.floor(aValue / 256) % 256,
		math.floor(aValue / 65536) % 256,
		math.floor(aValue / 65536 / 256) % 256
	)
end





--- Parses the header values from the 20-byte raw data header
-- aRawData is the 20 bytes received from the socket
-- Returns a dict-table with populated items: "Head", "Version", "Reserved1", "Reserved2", "SessionID",
-- "SequenceNum","TotalPkt", "CurrPkt", "MessageType" and "PayloadLength"
local function parseHeader(aRawData)
	assert(type(aRawData) == "string")
	assert(string.len(aRawData) == 20)

	return
	{
		Head = string.byte(aRawData, 1),
		Version = string.byte(aRawData, 2),
		Reserved1 = string.byte(aRawData, 3),
		Reserved2 = string.byte(aRawData, 4),
		SessionID = parseUint32(string.sub(aRawData, 5, 8)),
		SequenceNum = parseUint32(string.sub(aRawData, 9, 12)),
		TotalPkt = string.byte(aRawData, 13),
		CurrPkt = string.byte(aRawData, 14),
		MessageType = parseUint16(string.sub(aRawData, 15, 16)),
		PayloadLength = parseUint32(string.sub(aRawData, 17, 20))
	}
end





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
	aClient:send("\xff\0\0\0")  -- Head, Version, Reserved1, Reserved2
	aClient:send(writeUint32(gSessionID))
	aClient:send(writeUint32(gSequenceNum))
	aClient:send("\0\0")  -- TotalPkt, CurrPkt
	aClient:send(writeUint16(aMessageType))
	aClient:send(writeUint32(string.len(aPayload)))
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
		sendPayload(aClient, MESSAGETYPE_LOGIN_RESP, {Ret = 106})
		aClient:close()
		return
	end

	print("Access allowed.")
	return sendPayload(aClient, MESSAGETYPE_LOGIN_RESP, '{ "AliveInterval" : 21, "ChannelNum" : 4, "DataUseAES" : false, "DeviceType " : "HVR", "ExtraChannel" : 0, "Ret" : 100, "SessionID" : "0x0000000D" }')
end





--- Processes the payload
local function processPayload(aClient, aHeader, aPayload)
	assert(type(aHeader) == "table")
	assert(type(aHeader.MessageType) == "number")
	assert(type(aPayload) == "string")

	if (aHeader.MessageType == MESSAGETYPE_LOGIN_REQ) then
		return processPayloadLoginReq(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MESSAGETYPE_LOGIN_RESP) then
		-- CMS/ VMS send MESSAGETYPE_LOGIN_RESP instead of MESSAGETYPE_LOGIN_REQ, account for that:
		return processPayloadLoginReq(aClient, aHeader, aPayload)
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
