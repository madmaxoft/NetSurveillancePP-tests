#!/usr/bin/env lua

--- SimpleSimulatorDriver.lua
--[[
Runs the SimpleSimulator, waits for it to start up, then runs a program specified on the command line.
This is used as a test driver for NetSurveillancePp library protocol tests.

Usage:
	lua SimpleSimulatorDriver.lua [--expect-failure] ExeToRun ExeParams...
--]]




--- Flag telling the test that the command is expected to fail, rather than succeed
-- Settable via the "--expect-failure" cmdline flag
local gExpectFailure = false





local args = {...}
local argStart = 1
if (args[1] == "--expect-failure") then
	gExpectFailure = true
	argStart = argStart + 1
end
assert(type(args[argStart]) == "string", "Provide the command to run as a pamareter to this script")

-- Start the simulator:
local sim = io.popen("lua SimpleSimulator.lua --use-timeout --singleshot", "r")
ln = sim:read("*l")
assert(ln == "Simulator ready.", "Simulator failed to start")
print("Simulator ready, running the test program.")

-- Start the external program:
local cmdLine = table.concat(args, " ", argStart)
print("Running " .. cmdLine)
local err, msg, exitCode = os.execute(cmdLine)
sim:close()
if (gExpectFailure) then
	if (exitCode == 0) then
		print("Program was expected to fail, but it succeeded.")
		os.exit(1)
	else
		os.exit(0)
	end
else
	os.exit(exitCode)
end
