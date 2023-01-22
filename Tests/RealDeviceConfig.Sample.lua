-- RealDeviceConfig.Sample.lua

--[[
This is the sample configuration of a real device.

Copy this as a RealDeviceConfig.lua and change the values below to match your setup.
For the password hash, you can use the 00-SofiaHash test / utility
--]]




return
{
	hostName = "nvr",  -- Can be either IP or name
	port = 34567,
	username = "admin",
	passwordHash = "6QNMIQGe",  -- Hash of the "admin" default password
}
