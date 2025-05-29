-- R12-SysInfoWithoutLogin.lua

--[[
Connects to a real device and tries to query SysInfo without logging in

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
		- Doesn't reply, closes the socket after a 30s timeout
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)
		- TODO
--]]




local nvr = require("Nvr")
local utils = require("Utils")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





local dev = assert(nvr.connect(config.hostName, config.port))
local sysInfo, msg = assert(dev:getSysInfo("SystemInfo"))
print("Received SysInfo:")
utils.printTable(sysInfo)
