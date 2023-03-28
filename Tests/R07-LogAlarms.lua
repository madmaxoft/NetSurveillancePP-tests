-- R07-LogAlarms.lua

--[[
Asks the device to report alarms, then logs the alarms to the console.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)

The alarms are received from the device whenever they occur, as a MessageType.Alarm_Req message with JSON body:
{ "AlarmInfo" : { "Channel" : 0, "Event" : "VideoMotion", "StartTime" : "2023-03-03 12:48:20", "Status" : "Start" }, "Name" : "AlarmInfo", "SessionID" : "0x1c" }
{ "AlarmInfo" : { "Channel" : 1, "Event" : "VideoMotion", "StartTime" : "2023-03-03 18:41:31", "Status" : "Stop" }, "Name" : "AlarmInfo", "SessionID" : "0x1c" }
The device doesn't expect any response for the alarm (but normally terminates the connection if there's no keepalive sent by the client)
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





local conn = assert(nvr.connect(config.hostName, config.port))
assert(conn:login(config.username, config.passwordHash))
assert(conn:sendRequest(MessageType.Guard_Req,
	{
		Name = "",
		SessionID = conn.mSessionID
	}
))
conn:setTimeout(10)
print("Connected, ready to receive alarms.")
while (true) do
	local body, msgType = conn:receiveResponseData()
	if not(body) then
		if (msgType ~= "timeout") then
			print("Receiving a response failed: " .. tostring(msgType))
			break
		end
		-- Upon timeout, send a keepalive:
		conn:sendRequest(MessageType.KeepAlive_Req, {Name = "KeepAlive", SessionID = conn.mSessionID})
	else
		if (msgType ~= MessageType.KeepAlive_Resp) then
			print(string.format("body = %s, msgType = %d", body, msgType))
		end
	end
end
