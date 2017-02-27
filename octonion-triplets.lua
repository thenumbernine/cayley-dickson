#!/usr/bin/env luajit

require 'ext'
local CayleyDickson = require 'cayley-dickson'

--[[ iterates through all permutations of the provided table
args:
	elements = what elements to permute
	callback = what to call back with
	[internal]
	index = constructed index to be passed to the callback
	[optional]
	size = how many elements to return.  default is the length
--]]

local table = require 'ext.table'
local function permutations(args)
	local parity = args.parity or 1
	local p = args.elements
	local callback = args.callback
	local index = args.index
	if args.size then
		if index and #index == args.size then
			return callback(index, parity)
		end
	else
		if #p == 0 then
			return callback(index, parity)
		end
	end
	for i=1,#p do
		local subset = table(p)
		local subindex = table(index)
		subindex:insert(subset:remove(i))
		parity = parity * -1		-- TODO times -1 or times the distance of the swap?
		if permutations{
			elements = subset, 
			callback = callback, 
			index = subindex,
			size = args.size,
			parity = parity,
		} then 
			return true 
		end
	end
end

local function getEsForTs(ts)
	local es = table()
	for i,t in ipairs(ts) do
		for _,e in ipairs(t) do
			es[e.index] = es[e.index] or table()
			es[e.index]:insert(i)
		end
	end
	return es
end

local o = CayleyDickson(3)
local ts = o:getTriplets()
local es = getEsForTs(ts)

print'original order:'
for i,t in ipairs(ts) do
	print('t'..i, t[1], t[2], t[3])
end
print()
print'elements in each triplet:'
for i,e in ipairs(es) do
	print('e'..i, 't'..e[1], 't'..e[2], 't'..e[3])
end
os.exit()
-- no need for permutations, they're already equal

permutations{
	elements = range(7),
	callback = function(is)
		local ts2 = is:map(function(i) return ts[i] end)
		print('perm',table.unpack(is))
		for i,t in ipairs(ts2) do
			print(i,table.unpack(t))
		end
		local es = getEsForTs(ts2)
os.exit()
	end,
}
