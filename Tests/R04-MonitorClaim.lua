-- R04-MonitorClaim.lua

--[[
Requests live video from a device, using the MONITOR_CLAIM_REQ and MONITOR_REQ messages.
Stores the received video to a file, terminating after 5 seconds.

Tested on firmwares:
	- V4.03.R11.J5980233.12201.140000.0000001 (NVR)
	- V4.03.R11.C6380235.12201.140000.0000000 (NVR-test)
	- V4.03.R11.C638014A.12201.142300.0000000 (DVR-test)
	- V4.03.R11.34531191.1000 (DVR-old)
Seems to work on all. If there's a mismatch between the channels in the OPMonitor-Claim and OPMonitor-Start
packets, returns a 103 error.
The device may send both video and audio frames.
--]]





local nvr = require("Nvr")

-- The specific real device's configuration, provide your own as needed (there's a RealDeviceConfig.sample.lua)
local config = require("RealDeviceConfig")





--- Prints the data (string) as both hex and ascii, in a 16-byte-wide layout
local function printHex(aData)
	assert(type(aData) == "string")

	local len = string.len(aData)
	print("Dumping " .. tostring(len) .. " bytes of data:")
	for i = 0, len - 1, 16 do
		local bytes = { string.byte(aData, i + 1, i + 16) }  -- bytes[1] through bytes[16] are the ASCII codes to print on this line
		local hex = {}
		for j = 1, 16 do
			if (i + j <= len) then
				hex[j] = string.format("%02x", bytes[j])
			else
				hex[j] = "  "
			end
		end
		local filtered = {}
		for j = 1, 16 do
			if (i + j > len) then
				filtered[j] = " "
			elseif ((bytes[j] < 32) or (bytes[j] > 127)) then
				filtered[j] = "."
			else
				filtered[j] = string.char(bytes[j])
			end
		end
		print(table.concat(hex, " ") .. " | " .. table.concat(filtered, ""))
	end
end





--- The output file, once it is open for writing
local gFileOut

--- The buffer for the incoming data
-- Data is appended to it, when received, until a whole data-frame is available for processing
local gBuffer = ""

--- Map of stream format (T byte in the I-frame header) to output file extension
local gFileExt =
{
	[1] = "mp4",
	[2] = "h264",
	[3] = "h265",
}





--- Processes a single frame in gBuffer
-- aLengthOffset specifies the offset into gBuffer from which the Length field should be read
-- aLengthSize specifies the number of bytes of the Length field; must be 2 or 4
-- If gBuffer contains the whole frame, writes the frame data into the output file and removes the data from gBuffer
local function processFrame(aLengthOffset, aLengthSize)
	assert(type(aLengthOffset) == "number")

	local lenBytes = { string.byte(gBuffer, aLengthOffset, aLengthOffset + aLengthSize - 1) }
	lenBytes[4] = lenBytes[4] or 0
	lenBytes[3] = lenBytes[3] or 0
	assert(lenBytes[4] == 0, "Unexpected frame larger than 16 MiB received")
	local frameLen = lenBytes[1] + 256 * lenBytes[2] + 65536 * lenBytes[3]
	if (string.len(gBuffer) <= aLengthOffset + aLengthSize + frameLen) then
		-- Not enough data in the buffer yet
		return
	end
	assert(gFileOut, "Output file has not been opened yet, received out-of-order data.")
	gFileOut:write(string.sub(gBuffer, aLengthOffset + aLengthSize, aLengthOffset + aLengthSize + frameLen))
	gBuffer = string.sub(gBuffer, aLengthOffset + aLengthSize + frameLen)
end





--- Processes a single incoming packet:
-- The first ever packet containing an I-frame will open the output file (name depends on the data format: H.264 or H.265)
-- After receiving the first packet, the Length field in the packet is observed and data is joined even across packets
-- The raw H.264 or H.265 data is parsed out of the packet and saved into the output file
local function processPacket(aData)
	assert(type(aData) == "string")

	gBuffer = gBuffer .. aData
	local len = string.len(gBuffer)
	if (len < 8) then
		-- Not a complete header yet
		return
	end
	local bytes = { string.byte(gBuffer, 1, 4) }
	if ((bytes[1] ~= 0) or (bytes[2] ~= 0) or (bytes[3] ~= 1)) then
		assert(false, "Invalid header signature")
	end
	if (bytes[4] == 0xfc) then
		-- I-frame, 16 bytes long header with additional info
		-- If it is the first frame received, open the output file:
		if not(gFileOut) then
			local format = string.byte(gBuffer, 5) % 16
			local fileName = "video." .. (gFileExt[format] or "raw")
			print("Saving to file " .. fileName .. ", format " .. tostring(format))
			gFileOut = assert(io.open(fileName, "wb"))
		end
		print("I-frame")
		return processFrame(13, 4)
	elseif (bytes[4] == 0xfd) then
		-- P-frame, 8 bytes long header
		print("P-frame")
		return processFrame(5, 4)
	elseif (bytes[4] == 0xfa) then
		-- Audio frame, 8 bytes long header, 2-bytes long Length
		print("audio-frame")
		return processFrame(7, 2)
	end
	assert(false, "Unhandled message type: " .. string.format("%02x", bytes[4]))
end





-- Connect the main conn:
local cnMain = assert(nvr.connect(config.hostName, config.port))
assert(cnMain:login(config.username, config.passwordHash))

-- Connect the monitor conn and claim it:
print("Claiming monitor:")
local cnMon = assert(nvr.connect(config.hostName, config.port))
cnMon.mSessionID = cnMain.mSessionID
assert(cnMon:sendRequest(MessageType.MonitorClaim_Req,
	{
		Name = "OPMonitor",
		OPMonitor =
		{
			Action = "Claim",
			Parameter =
			{
				Channel = 1,
				CombinMode = "NONE",
				StreamType = "Main",
				TransMode = "TCP"
			}
		},
		SessionID = cnMon.mSessionID
	}
))
print(assert(cnMon:receiveAndCheckResponse()))

-- Start monitoring:
print("Requesting monitoring:")
assert(cnMain:sendRequest(MessageType.Monitor_Req,
	{
		Name = "OPMonitor",
		OPMonitor =
		{
			Action = "Start",
			Parameter =
			{
				Channel = 1,
				CombinMode = "NONE",
				StreamType = "Main",
				TransMode = "TCP"
			}
		},
		SessionID = cnMon.mSessionID
	}
))
print(assert(cnMain:receiveAndCheckResponse()))

-- Process monitor-data packets into a file for 5 seconds:
print("Waiting for data packets:")
local numPackets = 0
local startTime = os.time()
while (os.difftime(os.time(), startTime) < 10) do
	local rsp, msgType = assert(cnMon:receiveResponseData())
	processPacket(rsp)
	numPackets = numPackets + 1
end
print(string.format("All done, processed %d packets.", numPackets))
