#!/usr/bin/env luajit
require 'ext'
local CayleyDickson = require 'cayley-dickson'
local permutations = require 'permutations'	-- TODO use table.permutations

local function findSubsets(sup, sub)
	return coroutine.wrap(function()
		local n = #sup-1
		local m = #sub-1
		
		if m == 1 then
			for i=1,n do
				coroutine.yield(table{i}, table{sup[1][i+1]})
			end
			return
		end
		
		-- search all in-order subset permutations of n-1 size inside m-1
		local done
		local alreadyDone = table()
		local indexes = range(m):map(function(i) return 1 end)
		while not done do
			local cmp = table()
			for i=1,m do
				cmp[i] = table()
				for j=1,m do
					cmp[i][j] = sup[indexes[i]+1][indexes[j]+1]
				end
			end

			-- now find a reordering that maps sub[][] to cmp[][] 
			local cmpForSub = table()
			local fail
			for i=1,m do
				for j=1,m do
					local se = sub[i+1][j+1]
					local ce = cmp[i][j]
					if not cmpForSub[se.index] then
						cmpForSub[se.index] = se.negative and -ce or ce
						if se.index ~= 0 
						and ce.index ~= indexes[se.index]
						then
							fail = true
							break
						end
					else
						if cmpForSub[se.index].index ~= ce.index
						or se.negative ~= ce.negative
						then
							fail = true
							break
						end
					end
				end
				if fail then break end
			end
			if not fail then
				local key = table(cmpForSub):sort(function(a,b) return a.index < b.index end):map(tostring):concat','
				if alreadyDone[key] then
					fail = true
				else
					alreadyDone[key] = true
				end
			end
			if not fail then
				coroutine.yield(table(indexes), table(cmpForSub))
			end
			
			for i=#indexes,1,-1 do
				indexes[i] = indexes[i] + 1
				if indexes[i] < n+1 then break end
				indexes[i] = 1
				if i == 1 then done = true end	
			end
		end
	end)
end

--[[
		complex					mobius
c.d.#	elements	triplets	strips
1		1
2		3			1
3		7			7			1
4		15			35
--]]

local cs = table()
for i=1,7 do
	cs[i] = CayleyDickson(i)
	for j=1,i do
		local count = 0
		for indexes, cmpForSub in findSubsets(cs[i], cs[j]) do
			count = count + 1
			--print(indexes:concat', ','\t', cmpForSub:map(tostring):concat', ')
		end
		io.write('\t',count)
		io.flush()
	end
	print()
end
