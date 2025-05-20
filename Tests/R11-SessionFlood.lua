-- R11-SessionFlood.lua

--[[
Attempts to flood the NVR with too many sessions. Opens as many sessions to the device as possible.

Tested on firmwares:
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
		The NVR accepts about a 100 sessions in an eyeblink, then struggles to SYN-ACK the next
		TCP connection for a few seconds, then blazingly fast accepts another 100 sessions again, and repeats.
		This looks suspicious, so existing-session verification was added (whether the old sessions don't
		just silently die).
		After adding the check for alive connections, the NVR drops connections after ~280 are made (though
		the test executes for tens of minutes then).
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")

local idx = 1
local conns = {}
while (true) do
	print("Connecting session " .. idx)
	conns[idx] = assert(nvr.connect(config.hostName, config.port))
	assert(conns[idx]:login(config.username, config.passwordHash))
	print("  SessionID = " .. tostring(conns[idx].mSessionID))

	-- Every 10 sessions, verify that the old sessions are still alive:
	if ((idx % 10) == 0) then
		print("  (Verifying old sessions are still alive...)")
		for i = 1, idx do
			assert(conns[i]:sendRecvKeepAlive())
		end
	end

	idx = idx + 1
end
