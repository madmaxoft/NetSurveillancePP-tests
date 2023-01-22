-- R00-ConnectAndLogin.lua

--[[
Connects and logs into a real device.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
Good login is accepted, as assumed.
Good username + bad password combo returns Ret = 203, yet it assigns a SessionID
Bad username + any password combo returns Ret = 205, yet it assigns a SessionID
--]]




local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
print("Login successful")
