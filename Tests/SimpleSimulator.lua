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

--- True if the client asked for alarm notifications.
local gWantsAlarms = false

--- Number of timeouts that need to happen before an alarm is sent to the client
-- Decremented upon each timeout; when it reaches zero, an alarm is sent and this timer reset to another random value
local gNumTimeoutsBeforeAlarm = math.random(1, 3)

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
	print("Sending payload of type " .. tostring(aMessageType) .. ".")
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





local function processPayloadNetSnap(aClient, aHeader, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aHeader) == "table")
	assert(type(aPayload) == "string")

	-- User needs to be logged in:
	if not(gIsLoggedIn) then
		print("Cannot send OPSNAP response, not logged in.")
		return sendPayload(aClient, MessageType.NetSnap_Resp, {Ret = Error.UserNotLoggedIn})
	end

	-- We only support the OPSNAP request:
	local j = assert(json.decode(aPayload))
	if (j.Name ~= "OPSNAP") then
		print("Cannot send OPSNAP response, requesting unknown Name: " .. tostring(j.Name))
		return sendPayload(aClient, MessageType.NetSnap_Resp, {Ret = Error.IllegalRequest})
	end
	if (not(j.OPSNAP) or (type(j.OPSNAP) ~= "table")) then
		print("Cannot send OPSNAP response, there is no params: " .. type(j.OPSNAP))
		return sendPayload(aClient, MessageType.NetSnap_Resp, {Ret = Error.IllegalRequest})
	end
	if (not(j.OPSNAP.Channel) or not(tostring(j.OPSNAP.Channel))) then
		print("Cannot send OPSNAP response, cannot parse Channel param: " .. tostring(j.OPSNAP.Channel))
		return sendPayload(aClient, MessageType.NetSnap_Resp, {Ret = Error.IllegalRequest})
	end

	-- Success, send bogus data:
	print("Sending an example picture (OPSNAP) data.")
	sendPayload(aClient, MessageType.NetSnap_Resp, "bogusdata")
end





local function processPayloadGuard(aClient, aHeader, aPayload)
	assert(type(aClient) == "userdata")
	assert(type(aHeader) == "table")
	assert(type(aPayload) == "string")

	-- User needs to be logged in:
	if not(gIsLoggedIn) then
		print("Cannot send Guard response, not logged in.")
		return sendPayload(aClient, MessageType.Guard_Resp, {Ret = Error.UserNotLoggedIn})
	end

	-- Success, start sending alarms
	print("Client will receive alarms")
	gWantsAlarms = true
	aClient:settimeout(1)  -- Timeout after 1 second when reporting alarms
	sendPayload(aClient, MessageType.Guard_Resp, '{ "Name" : "", "Ret" : 100, "SessionID" : "0x0000000D" }')
end





local function processPayloadSysInfo(aClient, aHeader, aPayload)
	assert(type(aHeader) == "table")
	assert(type(aHeader.MessageType) == "number")
	assert(type(aPayload) == "string")

	local j = assert(json.decode(aPayload))
	if (j.Name == "SystemInfo") then
		-- Send bogus SysInfo data:
		print("Sending an example SysInfo SystemInfo data.")
		sendPayload(aClient, MessageType.SysInfo_Resp,
			{
				SystemInfo =
				{
					AlarmInChannel = 0,
					AlarmOutChannel = 0,
					AudioInChannel = 0,
				},
				Name = "SystemInfo",
				Ret = Error.Success,
				SessionID = 0x0d,
			}
		)
	end

	-- Send an error: Unknown config name:
	return sendPayload(aClient, MessageType.SysInfo_Resp, {Ret = Error.IllegalRequest, Msg = "Unknown SysInfo name"})
end





local function processPayloadAbility(aClient, aHeader, aPayload)
	assert(type(aHeader) == "table")
	assert(type(aHeader.MessageType) == "number")
	assert(type(aPayload) == "string")

	local j = assert(json.decode(aPayload))
	if (j.Name == "MultiLanguage") then
		-- Send bogus Ability data:
		print("Sending an example Ability MultiLanguage data.")
		sendPayload(aClient, MessageType.AbilityGet_Resp,
			{
				MultiLanguage = {"English", "Czech", "Slovakia"},
				Name = "MultiLanguage",
				Ret = Error.Success,
				SessionID = 0x0d,
			}
		)
	end

	-- Send an error: Unknown config name:
	return sendPayload(aClient, MessageType.AbilityGet_Resp, {Ret = Error.IllegalRequest, Msg = "Unknown Ability name"})
end





local function processPayloadGetConfig(aClient, aHeader, aPayload)
	assert(type(aHeader) == "table")
	assert(type(aHeader.MessageType) == "number")
	assert(type(aPayload) == "string")

	local j = assert(json.decode(aPayload))
	if (j.Name == "General.General") then
		-- Send bogus config data:
		print("Sending an example config General.General data.")
		sendPayload(aClient, MessageType.ConfigGet_Resp,
			{
				["General.General"] =
				{
					LocalNo = 8,
					AutoLogout = 0,
					ScreenAutoShutdown = 10,
					ScreenSaveTime = 0,
					OverWrite = "OverWrite",
					VideoOutPut = "AUTO",
					MachineName = "XiongMai",
					SnapInterval = 2,
				},
				Name = "General.General",
				Ret = Error.Success,
				SessionID = 0x0d,
			}
		)
	end

	-- Send an error: Unknown config name:
	return sendPayload(aClient, MessageType.ConfigGet_Resp, {Ret = Error.IllegalRequest, Msg = "Unknown config name"})
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
	elseif (aHeader.MessageType == MessageType.NetSnap_Req) then
		return processPayloadNetSnap(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.Guard_Req) then
		return processPayloadGuard(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.SysInfo_Req) then
		return processPayloadSysInfo(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.AbilityGet_Req) then
		return processPayloadAbility(aClient, aHeader, aPayload)
	elseif (aHeader.MessageType == MessageType.ConfigGet_Req) then
		return processPayloadGetConfig(aClient, aHeader, aPayload)
	-- TODO: Other message types
	end
	assert(false, "Unhandled mesasge type: " .. tostring(aHeader.MessageType))
end





--- Sends a single alarm event to the client
-- An alarm event consists of a Start and Stop packet
local function sendAlarm(aClient)
	assert(type(aClient) == "userdata")

	print("Sending an alarm.")
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	sendPayload(aClient, MessageType.Alarm_Req, '{ "AlarmInfo" : { "Channel" : 0, "Event" : "VideoMotion", "StartTime" : "' .. timestamp .. '", "Status" : "Start" }, "Name" : "AlarmInfo", "SessionID" : "0xd" }')
	sendPayload(aClient, MessageType.Alarm_Req, '{ "AlarmInfo" : { "Channel" : 0, "Event" : "VideoMotion", "StartTime" : "' .. timestamp .. '", "Status" : "Stop" }, "Name" : "AlarmInfo", "SessionID" : "0xd" }')
end





--- Receives exactly the specified number of bytes from the client
-- Returns the received bytes, as a string, on success
-- If the requested number of bytes is zero, returns an empty string
-- If there's a timeout while receiving, either sends an alarm (if alarm monitoring has been requested) or raises an error (if not)
-- If there's any other error while receiving, throws the error
local function receiveBytesFromClient(aClient, aNumBytes)
	assert(type(aClient) == "userdata")
	assert(type(aNumBytes) == "number")

	local received = ""
	while (aNumBytes > 0) do
		local d, msg, partial = aClient:receive(aNumBytes)
		if not(d) then
			if (msg == "timeout") then
				-- Timeout waiting for the next request, send an alarm if alarm monitoring is on:
				if (gWantsAlarms) then
					gNumTimeoutsBeforeAlarm = gNumTimeoutsBeforeAlarm - 1
					if (gNumTimeoutsBeforeAlarm <= 0) then
						sendAlarm(aClient)
						gNumTimeoutsBeforeAlarm = math.random(1, 3)
					end
					received = received .. (partial or "")
					aNumBytes = aNumBytes - string.len(partial or "")
				else
					error(msg)
				end
			else
				-- Another error from the socket, raise it:
				error(msg)
			end
		else
			-- Received without any problems
			received = received .. d
			aNumBytes = aNumBytes - string.len(d)
		end
	end
	return received
end





local function simulateClient(aClient)
	assert(type(aClient) == "userdata")

	while (true) do
		local header = parseHeader(receiveBytesFromClient(aClient, 20))
		print("Received a header, want payload: " .. header.PayloadLength .. " bytes")
		local payload = receiveBytesFromClient(aClient, header.PayloadLength)
		processPayload(aClient, header, payload)
	end
end





-- Simulate:
local server = assert(socket.bind("localhost", 34567, 0))
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
	print("Client connected: " .. tostring(client:getpeername()))
	local res, msg = pcall(simulateClient, client)
	if not(res) then
		print("Client terminated: " .. tostring(msg))
	end
	if (gIsSingleShot) then
		return
	end
	gWantsAlarms = false
end
