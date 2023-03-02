-- R03-EnumChannelTitlesNoLogin.lua

--[[
Connects to a real device and enumerates the channel titles, without actually logging in.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)
The device doesn't respond to this request at all.
Additionally, trying logging in with a bad username and password first and then enumerating has the same result, no answer.
--]]




local nvr = require("Nvr")
local json = require("dkjson")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





local dev = assert(nvr.connect(config.hostName, config.port))
-- dev:login("badUser", "bad-Hash")
local channelTitles, msg, resp = dev:enumChannelTitles()
if not(channelTitles) then
	print("Failed to enumerate channel titles without logging in")
	print("Error: " .. tostring(msg))
	print("Response: " .. json.encode(resp))
	return
end
print("Received channel titles:")
for _, cht in ipairs(channelTitles) do
	print(cht)
end
