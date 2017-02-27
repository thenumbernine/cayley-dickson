#!/usr/bin/env lua
--[[
print all spacings of 7-mobius-strips in 15x15 grid such that all pairs of mobius strips share 3 elements in common

spacings of 3-sets in 7x7 grid such that all pairs of 3-sets share 3 elements in common
1 2 . 3 . .  .
. 2 5 . 7 .  .
. . 5 3 . 6  .
. . . 3 7 . -4
1 . . . 7 6  .
. 2 . . . 6 -4
1 . 5 . . . -4

--]]
local code = require 'template' [[
require 'ext'
local matrix = require 'matrix'

local allSoFar = table()

<? 
--[=[ mobius strips in sedenions
local m = 3		-- number of elements in common
local n = 7		-- size of subset to look for
local p = 15	-- size of space to scan
--]=]
-- [=[
local m = 3
local n = 3
local p = 7
--]=]

for i=1,n do ?>
for o<?=i?>=<?=i==1 and 0 or 'o'..(i-1)..'+1'?>,<?=i==1 and 0 or p-1?> do
<? end ?>
	local offsets = table{o1,o2,o3,o4,o5,o6,o7}
print(offsets:unpack())	
	local m = matrix.zeros(<?=p?>,<?=p?>) 
	local function _m(x) return (x-1)%<?=p?>+1 end
	for i=1,<?=p?> do
		for _,j in ipairs(offsets) do
			m[i][_m(i+j)] = 1
		end
	end
	local n = m * m:transpose()
print(m)
print(n)	
	if n == matrix.lambda({<?=p?>,<?=p?>}, function(i,j)
		if i==j then return <?=n?> end
		return <?=m?>
	end) then
		local expanded = range(<?=p?>):map(function(i)
			return offsets:find(i-1) and 'x' or '.'
		end)
		
		local found = allSoFar:find(nil, function(sofar) 
			for shift=0,<?=p-1?> do
				local shifted = range(<?=p?>):map(function(i)
					return expanded[(i-1+shift)%<?=p?>+1]
				end):concat()
				if shifted == sofar.expanded:concat() then return true end 
			end	
		end)
			
		allSoFar:insert{
			offsets = table(offsets),
			expanded = table(expanded),
		}
		
		print('order #'..#allSoFar, offsets:concat' ', expanded:concat' ', found and ('translation isomorphic to '..found) or '')
	end
<? for i=1,n do ?>
end
<? end ?>
]]
print(code)
assert(load(code))()
