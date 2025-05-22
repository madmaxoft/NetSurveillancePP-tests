-- NvrUtils.lua

--[[
Provides utilities related to the NVR protocol:
- symbolic constants
- parsing for 2-byte and 4-byte uints
- writing 2-byte and 4-byte uints
- parsing and serializing the packet header

This file is expected to be included by doing:
dofile("NvrUtils.lua")
which puts all the functions from here into the global namespace.

At this moment, the file is shared between:
	- the SimpleSimulator, for testing the NetSurveillancePp lib
	- the Nvr class, for checking real devices' responses
--]]




--- Message types used by the protocol:
MessageType =
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

	-- Capture control:
	NetSnap_Req    = 1560,
	NetSnap_Resp   = 1561,
	SetIFrame_Req  = 1562,
	SetIFrame_Resp = 1563,

	-- Time sync:
	SyncTime_Req  = 1590,
	SyncTime_Resp = 1591,
}

-- Catch attempts to use undefined message types:
setmetatable(MessageType,
	{
		__index = function(aType)
			assert(false, "Using an undefined message type (" .. tostring(aType) .. ")")
		end,
		__newindex = function(aType)
			assert(false, "Writing to a read-only table (" .. tostring(aType) .. ")")
		end
	}
)





--- Error values, used in the packet header:
Error =
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
	IncorrectPassword = 203,
	IllegalUser = 204,
	UserLocked = 205,

	ConfigurationDoesNotExist = 607,
	ConfigurationParsingError = 608,
}





--- Map of ErrorCode -> description for the errors:
local gErrorCodeDescriptions =
{
	[Error.Success] = "Success",
	[Error.UnknownError] = "Unknown error",
	[Error.Unsupported] = "Unsuported",
	[Error.IllegalRequest] = "Illegal request",
	[Error.UserAlreadyLoggedIn] = "User already logged in",
	[Error.UserNotLoggedIn] = "User not logged in",
	[Error.BadUsernameOrPassword] = "Bad username or password",
	[Error.NoPermission] = "No permission",
	[Error.Timeout] = "Timeout",
	[Error.SearchFailed] = "Search failed",
	[Error.SearchSuccessReturnAll]  = "Search success, returned all",
	[Error.SearchSuccessReturnSome] = "Search success, returned some",
	[Error.UserAlreadyExists] = "User already exists",
	[Error.UserDoesNotExist] = "User doesn't exist",
	[Error.GroupAlreadyExists] = "Group already exists",
	[Error.GroupDoesNotExist] = "Group doesn't exist",
	[Error.MessageFormatError] = "Message format error",
	[Error.PtzProtocolNotSet] = "PTZ protocol not set",
	[Error.NoFileFound] = "No file found",
	[Error.ConfiguredToEnable] = "Configured to enable",
	[Error.DigitalChannelNotConnected] = "Digital channel not connected",
	[Error.SuccessNeedRestart] = "Success, need restart",
	[Error.UserNotLoggedIn2] = "User not logged in",
	[Error.IncorrectPassword] = "Incorrect password",
	[Error.IllegalUser] = "Illegal user",
	[Error.UserLocked] = "User locked",
	[Error.ConfigurationDoesNotExist] = "Configuration doesn't exist",
	[Error.ConfigurationParsingError] = "Configuration parsing error",
}





--- A map of ErrorCode -> true for all error codes that should be considered success
local gIsErrorCodeSuccess =
{
	[Error.Success] = true,
	[Error.SearchSuccessReturnAll] = true,
	[Error.SearchSuccessReturnSome] = true,
	[Error.SuccessNeedRestart] = true,
}





--- Parses raw 4 bytes into a 32-bit number
function parseUint32(aRawData)
	assert(type(aRawData) == "string")
	assert(string.len(aRawData) == 4)

	return
		string.byte(aRawData, 1) +
		string.byte(aRawData, 2) * 256 +
		string.byte(aRawData, 3) * 65536 +
		string.byte(aRawData, 4) * 256 * 65536
end





--- Parses raw 2 bytes into a 16-bit number
function parseUint16(aRawData)
	assert(type(aRawData) == "string")
	assert(string.len(aRawData) == 2)

	return
		string.byte(aRawData, 1) +
		string.byte(aRawData, 2) * 256
end





--- Serializes the 16-bit number into 2 raw bytes of the on-wire protocol
function writeUint16(aValue)
	assert(type(aValue) == "number")
	assert(aValue >= 0)
	assert(aValue < 65536)

	return string.char(
		aValue % 256,
		math.floor(aValue / 256) % 256
	)
end





--- Serializes the 32-bit number into 4 raw bytes of the on-wire protocol
function writeUint32(aValue)
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
function parseHeader(aRawData)
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





--- Returns a string containing the serialized 20-byte header of a NetSurveillance packet
function serializeHeader(aSessionID, aSequenceNum, aMessageType, aPayloadLen)
	assert(type(aSessionID) == "number")
	assert(type(aSequenceNum) == "number")
	assert(type(aMessageType) == "number")
	assert(type(aPayloadLen) == "number")

	return
		string.char(255, 0, 0, 0) .. -- Head, Version, Reserved1, Reserved2
		writeUint32(aSessionID) ..
		writeUint32(aSequenceNum) ..
		"\0\0" ..  -- TotalPkt, CurrPkt
		writeUint16(aMessageType) ..
		writeUint32(aPayloadLen)
end





--- Returns a string describing the error code, plus the numeric code itself
-- If the error code is not one of the recognized ones, returns an "unknown error <num>" string
function errorToString(aErrorCode)
	assert(type(aErrorCode) == "number")
	local desc = gErrorCodeDescriptions[aErrorCode]
	if (desc) then
		return desc .. string.format(" (%d)", aErrorCode)
	end
	return string.format("Unknown error code (%d)", aErrorCode)
end





--- Returns true if the specified error code should be considered a success
function isSuccessCode(aErrorCode)
	local isSuccess = gIsErrorCodeSuccess[aErrorCode]
	if not(isSuccess) then
		return false
	end
	return true
end
