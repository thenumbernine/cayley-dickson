#!/usr/bin/env lua
-- print all spacings of 7-mobius-strips in 15x15 grid such that all pairs of mobius strips share 3 elements in common
require 'ext'
local template = require 'template'
assert(load(template([[
local matrix = require 'matrix'

local allSoFar = table()

<? for i=1,7 do ?>
for o<?=i?>=<?=i==1 and 0 or 'o'..(i-1)..'+1'?>,<?=i==1 and 0 or 15?> do
<? end ?>
	local offsets = table{o1,o2,o3,o4,o5,o6,o7}
	local m = matrix.zeros(15,15) 
	local function _m(x) return (x-1)%15+1 end
	for i=1,15 do
		for _,j in ipairs(offsets) do
			m[i][_m(i+j)] = 1
		end
	end
	local n = m * m:transpose()
	if n == matrix.lambda({15,15}, function(i,j)
		if i==j then return 7 end
		return 3
	end) then
		local expanded = range(15):map(function(i)
			return offsets:find(i-1) and 'x' or '.'
		end)
		
		local found = allSoFar:find(nil, function(sofar) 
			for shift=0,14 do
				local shifted = range(15):map(function(i)
					return expanded[(i-1+shift)%15+1]
				end):concat()
				if shifted == sofar.expanded:concat() then return true end 
			end	
		end)
			
		allSoFar:insert{
			offsets = table(offsets),
			expanded = table(expanded),
		}
		
		print('order #'..#allSoFar, offsets:concat' ', expanded:concat' ', found and ('isomorphic to '..found) or '')
		
		--print(m,'\n')
		--print(n,'\n')
	end
<? for i=1,7 do ?>
end
<? end ?>
]])))()
