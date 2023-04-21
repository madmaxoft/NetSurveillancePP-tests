-- R09-ManySnapshots.lua

--[[
Requests many snapshots of the current live video from a device in a row, using the NET_SNAP_REQ message.
Real devices do sometimes report "timeout" error instead of the snapshot.
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





local dev = assert(nvr.connect(config.hostName, config.port))
assert(dev:login(config.username, config.passwordHash))

-- Send N requests in a row
local N = 30
for i = 1, N do
	assert(dev:sendRequest(MessageType.NetSnap_Req,
		{
			Name = "OPSNAP",
			OPSNAP =
			{
				Channel = 0,
			}
		}
	))
end
for i = 1, N do
	local pic, msgType = assert(dev:receiveResponseData(true))
	if (
		(string.len(pic) < 1000) and
		string.find(pic, "Ret:"))
	then
		print("The device returned an error:\n" .. pic)
	end
end
print("Done.")
