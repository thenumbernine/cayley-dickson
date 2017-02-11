#!/usr/bin/env luajit

require 'ext'
local permutations = require 'permutations'

local CayleyDickson = require 'cayley-dickson'
local permutations = require 'permutations'

local cs = range(4):map(CayleyDickson)
print(cs[1])
print(cs[2])
print(cs[4])

local function findSubsets(sup, sub)
	local n = #sup-1
	local m = #sub-1
	print(m,n)
	-- search all in-order subset permutations of n-1 size inside m-1
	local done
	local indexes = range(m)
	while not done do
		print(indexes:unpack())
		
		for i=#indexes,1,-1 do
			indexes[i] = indexes[i] + 1
			if indexes[i] < (indexes[i+1] or n+1) then break end
			print('resetting',i)
			for j=i,m do
				indexes[j] = (indexes[j-1] or 0) + 1
			end
			if i == 1 then done = true end	
		end
	end
end

findSubsets(cs[3], cs[2])
