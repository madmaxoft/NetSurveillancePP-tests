-- R01-ConnectAndLoginTwice.lua

--[[
Connects to a real device and tries to login twice.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)
Seems to work fine, the second login is accepted and gets the same SessionID
--]]




local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
print("First login successful")
local isSuccess, msg = dev:login(config.username, config.passwordHash)
if not(isSuccess) then
	print("Logging in twice failed:")
	print(msg)
else
	print("Second login successful")
end
