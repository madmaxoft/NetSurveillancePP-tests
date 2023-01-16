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

--- True if the client logged in successfully, false if not.
local gIsLoggedIn = false

-- The cmdline args provided to this script
local args = {...}





--- Message types used by the protocol:
local MessageType =
{
	-- Note: The following values are off-by-one from the official docs, but are what was seen on wire on a real device
	Login_Req        = 1000,
	Login_Resp       = 1001,
	Logout_Req       = 1002,
	Logout_Resp      = 1003,
	ForceLogout_Req  = 1004,
	ForceLogout_Resp = 1005,
	KeepAlive_Req    = 1006,
	KeepAlive_Resp   = 1007,
	-- (end of off-by-one values)

	SysInfo_Req  = 1020,
	SysInfo_Resp = 1021,

	-- Config:
	ConfigSet_Req                = 1040,
	ConfigSet_Resp               = 1041,
	ConfigGet_Req                = 1042,
	ConfigGet_Resp               = 1043,
	DefaultConfigGet_Req         = 1044,
	DefaultConfigGet_Resp        = 1045,
	ConfigChannelTitleSet_Req    = 1046,
	ConfigChannelTitleSet_Resp   = 1047,
	ConfigChannelTitleGet_Req    = 1048,
	ConfigChannelTitleGet_Resp   = 1049,
	ConfigChannelTileDotSet_Req  = 1050,
	ConfigChannelTileDotSet_Resp = 1051,

	SystemDebug_Req  = 1052,
	SystemDebug_Resp = 1053,

	AbilityGet_Req  = 1360,
	AbilityGet_Resp = 1361,

	-- PTZ control:
	Ptz_Req = 1400,
	Ptz_Resp = 1401,

	-- Monitor (current video playback):
	Monitor_Req       = 1410,
	Monitor_Resp      = 1411,
	Monitor_Data      = 1412,
	MonitorClaim_Req  = 1413,
	MonitorClaim_Resp = 1414,

	-- Playback:
	Play_Req = 1420,
	Play_Resp = 1421,
	Play_Data = 1422,
	Play_Eof = 1423,
	PlayClaim_Req = 1424,
	PlayClaim_Resp = 1425,
	DownloadData = 1426,

	-- Intercom:
	Talk_Req = 1430,
	Talk_Resp = 1431,
	TalkToNvr_Data = 1432,
	TalkFromNvr_Data = 1433,
	TalkClaim_Req = 1434,
	TalkClaim_Resp = 1435,

	-- File search:
	FileSearch_Req         = 1440,
	FileSearch_Resp        = 1441,
	LogSearch_Req          = 1442,
	LogSearch_Resp         = 1443,
	FileSearchByTime_Req   = 1444,
	FileSearchByTyime_Resp = 1445,

	-- System management:
	SysMgr_Req     = 1450,
	SysMgr_Resp    = 1451,
	TimeQuery_Req  = 1452,
	TimeQuery_Resp = 1453,

	-- Disk management:
	DiskMgr_Req  = 1460,
	DiskMgr_Resp = 1461,

	-- User management:
	FullAuthorityListGet_Req  = 1470,
	FullAuthorityListGet_Resp = 1471,
	UsersGet_Req              = 1472,
	UsersGet_Resp             = 1473,
	GroupsGet_Req             = 1474,
	GroupsGet_Resp            = 1475,
	AddGroup_Req              = 1476,
	AddGroup_Resp             = 1477,
	ModifyGroup_Req           = 1478,
	ModifyGroup_Resp          = 1479,
	DeleteGroup_Req           = 1480,
	DeleteGroup_Resp          = 1481,
	AddUser_Req               = 1482,
	AddUser_Resp              = 1483,
	ModifyUser_Req            = 1484,
	ModifyUser_Resp           = 1485,
	DeleteUser_Req            = 1486,
	DeleteUser_Resp           = 1487,
	ModifyPassword_Req        = 1488,
	ModifyPassword_Resp       = 1489,

	-- Alarm reporting:
	Guard_Req          = 1500,
	Guard_Resp         = 1501,
	Unguard_Req        = 1502,
	Unguard_Resp       = 1503,
	Alarm_Req          = 1504,
	Alarm_Resp         = 1505,
	NetAlarm_Req       = 1506,
	NetAlarm_Resp      = 1507,
	AlarmCenterMsg_Req = 1508,

	-- SysUpgrade:
	SysUpgrade_Req      = 1520,
	SysUpgrade_Resp     = 1521,
	SysUpgradeData_Req  = 1522,
	SysUpgradeData_Resp = 1523,
	SysUpgradeProgress  = 1524,
	SysUpgradeInfo_Req  = 1525,
	SysUpgradeInfo_Resp = 1526,

	-- Time sync:
	SyncTime_Req  = 1590,
	SyncTime_Resp = 1591,
}





--- Error values, used in the packet header:
local Error =
{
	Success = 100,
	UnknownError = 101,
	Unsupported = 102,
	IllegalRequest = 103,
	UserAlreadyLoggedIn = 104,
	UserNotLoggedIn = 105,
	BadUsernameOrPassword = 106,
	NoPermission = 107,
	Timeout = 108,
	SearchFailed = 109,
	SearchSuccessReturnAll  = 110,
	SearchSuccessReturnSome = 111,
	UserAlreadyExists = 112,
	UserDoesNotExist = 113,
	GroupAlreadyExists = 114,
	GroupDoesNotExist = 115,
	MessageFormatError = 117,
	PtzProtocolNotSet = 118,
	NoFileFound = 119,
	ConfiguredToEnable = 120,
	DigitalChannelNotConnected = 121,
	SuccessNeedRestart = 150,
	UserNotLoggedIn2 = 202,
	ConfigurationDoesNotExist = 607,
	ConfigurationParsingError = 608,
}





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
