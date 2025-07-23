-- R15-DownloadShortLive.lua

--[[
Connects to a real device and downloads a short clip of the live stream, as raw data.
The data needs to be further parsed in order to extract the actual video stream.
--]]



local nvr = require("Nvr")
local utils = require("Utils")





-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local fOut = assert(io.open("R15-out.raw", "wb"))





local devControl = assert(nvr.connect(config.hostName, config.port))
assert(devControl:login(config.username, config.passwordHash))
local devData = assert(nvr.connect(config.hostName, config.port))
devData.mSessionID = devControl.mSessionID

local reqClaim =
{
	Name = "OPMonitor",
	OPMonitor =
	{
		Action = "Claim",
		Parameter =
		{
			Channel = 0,
			CombinMode = "NONE",
			StreamType = "Main",
			TransMode = "TCP",
		},
	},
}
local reqStart =
{
	Name = "OPMonitor",
	OPMonitor =
	{
		Action = "Start",
		Parameter =
		{
			Channel = 0,
			CombinMode = "NONE",
			StreamType = "Main",
			TransMode = "TCP",
		},
	},
}
print("Sending a Claim Request through the Data connection:")
utils.printTable(reqClaim)

devData:sendRequest(MessageType.MonitorClaim_Req, reqClaim)
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
devControl:sendRequest(MessageType.Monitor_Req, reqStart)
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

-- Receive 20 full response packets with video data:
for i = 0, 20 do
	local data, msgType = devData:receiveResponseData(false)
	if not(data) then
		print("Response #" .. i .. " failed: " .. tostring(msgType))
	else
		print("Response #" .. i .. " successful.")
	end
	fOut:write(data)
end
fOut:close()
