-- R12-SysInfoWithLogin.lua

--[[
Connects to a real device and tries to query SysInfo after logging in.
Used to display the real device's answer.
--]]




local nvr = require("Nvr")
local utils = require("Utils")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
local sysInfo, msg = assert(dev:getSysInfo("SystemInfo"))
print("Received SysInfo:")
utils.printTable(sysInfo)
