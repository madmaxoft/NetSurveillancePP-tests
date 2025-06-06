-- R14-FileSearch.lua

--[[
Connects to a real device and sends a file search query.
--]]





local nvr = require("Nvr")
local utils = require("Utils")


-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
local req = 
{
	Name = "OPFileQuery",
	OPFileQuery =
	{
		BeginTime = os.date("%Y-%m-%d %H:%M:%S", os.time() - 24 * 60 * 60),
		Channel = 0,
		DriverTypeMask = "0x0000FFFF",
		EndTime = os.date("%Y-%m-%d %H:%M:%S"),
		Event = "AMRH",
		Type = "h264"
	},
}
print("Request:")
utils.printTable(req)
dev:sendRequest(MessageType.FileSearch_Req, req)
local isSuccess, msgType, resp = dev:receiveAndCheckResponse()
if not(isSuccess) then
	print("NOT successful: " .. tostring(msgType))
	if (type(resp) == "table") then
		utils.printTable(resp)
	end
else
	print("Received SUCCESS response:")
	utils.printTable(resp)
end
