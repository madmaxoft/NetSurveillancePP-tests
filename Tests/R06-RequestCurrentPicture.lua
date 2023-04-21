-- R06-RequestCurrentPicture.lua

--[[
Requests a picture of the current live video from a device, using the under-documented NET_SNAP_REQ message.
Stores the received picture to a file.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
		Seems to require only the Channel parameter with the "OPSNAP" method (acquired from a disassembled
		NetSDK.dll, function H264_DVR_CatchPic); the returned picture has a predefined resolution, with
		no obvious method of requesting a different one.
	- V4.03.R11.34531191.1000 (DVR-old)
		Doesn't seem support the "OPSNAP" method, returns error code 102 in a regular JSON

Sometimes the firmware gets "stuck" when requesting a snapshot, it will not reply for several seconds and
then respond with a Ret=108 json response ("timeout"). It will keep reporting timeout for all subsequent
snapshot requests, not even a day of inactivity and session closure clears the timeout.
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))
assert(dev:sendRequest(MessageType.NetSnap_Req,
	{
		Name = "OPSNAP",
		OPSNAP =
		{
			Channel = 0,
		}
	}
))
local pic, msgType = assert(dev:receiveResponseData(true))
local f = assert(io.open("pic.jpg", "wb"))
f:write(pic)
f:close()
print("Done.")
