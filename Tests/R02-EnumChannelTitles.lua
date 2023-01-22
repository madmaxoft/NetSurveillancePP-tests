-- R02-EnumChannelTitles.lua

--[[
Connects to a real device and enumerates the channel titles.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
If the logged-in user's group has the ChannelTitle right, the request normally proceeds.
If the logged-in user's group doesn't have the ChannelTitle right, the request normally succeeds as well (wtf?)
--]]




local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
local channelTitles, msg = assert(dev:enumChannelTitles())
print("Received channel titles:")
for _, cht in ipairs(channelTitles) do
	print(cht)
end
