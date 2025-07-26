-- R16 - RemotePlayback.lua

--[[
Connects to a real device and downloads a short clip of a remote playback file, as raw data.
The data needs to be further parsed in order to extract the actual video stream.
The playback data is used as a reference, since it is the same all the time, so multiple runs can be compared.
--]]



local nvr = require("Nvr")
local utils = require("Utils")




--- The number of packets to capture:
local gNumPackets = 200

--- The start time of the recording to be played back:
local gStartTime = os.time(
{
	year = 2025,
	month = 07,
	day = 25,
	hour = 12,
	minute = 0,
	second = 0
})

--- The filename of the recording to be played back:
local gFileName = "/idea0/2025-07-25/001/12.00.00-12.37.37[R][@104b0a][0].h264"




-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local fOut = assert(io.open("R16-out.raw", "wb"))





local devControl = assert(nvr.connect(config.hostName, config.port))
assert(devControl:login(config.username, config.passwordHash))
local devData = assert(nvr.connect(config.hostName, config.port))
devData.mSessionID = devControl.mSessionID

local reqClaim =
{
	Name = "OPPlayBack",
	OPPlayBack =
	{
		Action = "Claim",
		StartTime = os.date("%Y-%m-%d %H:%M:%S", gStartTime),
		EndTime = os.date("%Y-%m-%d %H:%M:%S", gStartTime + 60 * 60),
		Parameter =
		{
			FileName = gFileName,
			TransMode = "TCP",
		},
	},
}
local reqStart =
{
	Name = "OPPlayBack",
	OPPlayBack =
	{
		Action = "Start",
		StartTime = os.date("%Y-%m-%d %H:%M:%S", gStartTime),
		EndTime = os.date("%Y-%m-%d %H:%M:%S", gStartTime + 60 * 60),
		Parameter =
		{
			FileName = gFileName,
			TransMode = "TCP",
		},
	},
}
print("Sending a Claim Request through the Data connection:")
utils.printTable(reqClaim)

devData:sendRequest(MessageType.PlayClaim_Req, reqClaim)
local isSuccess, msgType, resp = devData:receiveAndCheckResponse()
if not(isSuccess) then
	print("Claim NOT successful: " .. tostring(msgType))
	if (type(resp) == "table") then
		utils.printTable(resp)
	end
else
	print("Claim received SUCCESS response:")
	utils.printTable(resp)
end

print("Sending a Start Request through the Control connection:")
utils.printTable(reqStart)
devControl:sendRequest(MessageType.Play_Req, reqStart)
isSuccess, msgType, resp = devControl:receiveAndCheckResponse()
if not(isSuccess) then
	print("Start NOT successful: " .. tostring(msgType))
	if (type(resp) == "table") then
		utils.printTable(resp)
	end
else
	print("Start received SUCCESS response:")
	utils.printTable(resp)
end

-- Receive response packets with video data:
for i = 0, gNumPackets do
	local data, msgType = devData:receiveResponseData(false)
	if not(data) then
		print("Response #" .. i .. " failed: " .. tostring(msgType))
	else
		print("Response #" .. i .. " successful.")
	end
	fOut:write(data)
end
fOut:close()
