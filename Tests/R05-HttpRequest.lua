-- R05-HttpRequest

--[[
ChatGPT seems to think that the NetSurveillance/Sofia NVRs accept HTTP GET requests
on the same port as the main comm. Let's try it.

Most of the code was written by ChatGPT itself, I only changed it to use the RealDevice config.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)
There is no response from the device, it is unlikely to accept HTTP requests.
--]]


-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")

local socket = require("socket")

-- Connect to the XM NVR
local client = socket.tcp()
client:settimeout(5)
client:connect(config.hostName, config.port)

-- Send the request for a video stream
local request = "GET /video?channel=1&subtype=0 HTTP/1.1\r\n" ..
                "Host: " .. config.hostName .. "\r\n" ..
                "Authorization: Basic YWRtaW46YWRtaW4=\r\n" ..  -- Note: Bad auth header, but we should still see *some* reply
                "Connection: keep-alive\r\n" ..
                "User-Agent: XMplayer\r\n\r\n"
client:send(request)

-- Receive the video stream and save it to a local file
local file = io.open("response.raw", "wb")
while true do
  local data, status, partial = client:receive(1024)
  if data then
    file:write(data)
  elseif status == "closed" then
    break
  elseif status == "timeout" then
    socket.sleep(0.1)
  else
    print("Error: " .. status)
    break
  end
end
file:close()

-- Close the connection
client:close()
