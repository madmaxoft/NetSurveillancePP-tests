-- Utils.lua

--[[
Implements common utility functions.

Usage:
local utils = require("Utils")
utils.printTable(...)
--]]





local Utils = {}





--- Recursively prints the specified table
function Utils.printTable(aTable, aIndent)
	assert(type(aTable) == "table")
	assert(not(aIndent) or (type(aIndent) == "string"))
	
	aIndent = aIndent or ""
	print(aIndent .. "{")
	local indent = aIndent .. "\t"
	for k, v in pairs(aTable) do
		if (type(v) == "table") then
			print(indent .. tostring(k) .. " =")
			Utils.printTable(v, indent)
		elseif (type(v) == "string") then
			print(indent .. tostring(k) .. " = \"" .. v .. "\",")
		else
			print(indent .. tostring(k) .. " = " .. tostring(v) .. ",")
		end
	end
	print(aIndent .. "},")
end





return Utils
