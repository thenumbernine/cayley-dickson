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

TODO use table.permutations
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

local function compareTsAndEs(ts, es)	
	for i=1,#es do
		local t = table(ts[i]):map(function(t) return t.index end):sort()
		local e = table(es[i]):sort()
		if t:concat',' ~= e:concat',' then return false end
	end
	return true
end

-- true if there are no e_i within t_i
local function tsGood(ts)
	for i,t in ipairs(ts) do
		for j,e in ipairs(t) do
			if e.index == i then return false end
		end
	end
	return true
end

-- true if there are no t_i within e_i
local function esGood(es)
	for i,e in ipairs(es) do
		for j,t in ipairs(e) do
			if t == i then return false end
		end
	end
	return true
end

local o = CayleyDickson(3)
local ts = o:getTriplets()
--[[
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
print('same?',compareTsAndEs(ts, es))
print('ts good?', tsGood(ts))
print('es good?', esGood(es))
os.exit()
--]]
-- no need for permutations, they're already equal
-- but this permutation doesn't have the property that t_i does not contain e_i.  in fact, it may or may not.
-- is there such an arrangement with this constraint as well?

local origTs = ts
permutations{
	elements = range(7),
	callback = function(is)
		local ts = is:map(function(i) return origTs[i] end)
		local es = getEsForTs(ts)

--[[
		print'original order:'
		for i,t in ipairs(ts) do
			print('t'..i, t[1], t[2], t[3])
		end
		print()
		print'elements in each triplet:'
		for i,e in ipairs(es) do
			print('e'..i, 't'..e[1], 't'..e[2], 't'..e[3])
		end
--]]	
		local same = compareTsAndEs(ts, es)
		local tg = tsGood(ts)
		local eg = esGood(es)
		--if same and (tg or eg) then	--0
		--if same then	--28
		--if tg or eg then	--144
		if not same and not tg and not eg then	--4868
			io.write('perm:'..table.concat(is, ','))
			io.write(' same:'..same)
			io.write(' ts:'..tg)
			io.write(' es:'..eg)
			print()
		end
	end,
}
