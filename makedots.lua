#! /usr/bin/env luajit

local bit = require 'bit'
local table = require 'ext.table'
local CayleyDickson = require 'cayley-dickson'

local cayleyDicksonTables = table()
for i=0,5 do
	print('table '..i)
	local c = CayleyDickson(i)
	cayleyDicksonTables[i] = c
	print(c)
	local f = assert(io.open('cayley-dickson-'..bit.lshift(1,i)..'.dot', 'w'))
	c:printTripletDotGraph(function(s) f:write(s,'\n') end)
	f:close()
end



--[[
local sedenions = cayleyDicksonTables[4]
local triplets = sedenions:getTriplets()

for _,triplet in ipairs(triplets) do
	print(table.map(triplet,tostring):concat(' -> '))
end
--]]
