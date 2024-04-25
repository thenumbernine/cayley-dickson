#!/usr/bin/env luajit

local table = require 'ext.table'
local range = require 'ext.range'
local CayleyDickson = require 'cayley-dickson'

local c = CayleyDickson(4)
print(c)

local function hex(i)
	if i < 10 then return i end
	return string.char(('A'):byte() + i - 10)
end

local function shortname(e)
	return (e.negative and '-' or '') .. hex(e.index)
end

local allTriplets = c:getTriplets()

print'triplets:'
for i,t in ipairs(allTriplets) do
	print('t'..i, table.unpack(t))
end


local function tripletsOf(e)
	local ts = table()
	for _,t in ipairs(allTriplets) do
		for j=1,3 do
			if t[j].index == e.index then
				if e.negative then
					ts:insert(table{
						-t[j],
						t[(j+1)%3+1], 
						t[j%3+1],
					})
				else
					ts:insert(table{
						t[j],
						t[j%3+1],
						t[(j+1)%3+1],
					})
				end
				break
			end
		end
	end
	return ts
end

local es = table(c[1])
es:remove(1)

for i,e in ipairs(es) do
	io.write('triplets of e'..shortname(e)..':')
	for _,t in ipairs(tripletsOf(e)) do
		io.write(' '..t:mapi(shortname):concat'')
	end
	print()
end

print'triplets of ei * ej:'
local tripletMap = table()
for i,ei in ipairs(es) do
	tripletMap[i] = table()
	for j,ej in ipairs(es) do
		local ek = ei * ej
		tripletMap[i][j] = select(2, allTriplets:find(nil, function(t)
			return table.find(t, nil, function(ti) return ti.index == ek.index end)
		end))
	end
	print(range(#tripletMap[1]):mapi(function(j) 
		local tij = tripletMap[i][j]	
		return tij 
			and table.map(tij, shortname):concat()	--table.map(tij, function(e) return e.index end):concat()
			or '...'
	end):concat' ')
end

print('unique mobius rings:')
local function tablesAreEqual(a,b)
	if #a ~= #b then return false end
	for i=1,#a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- offsets of indexes to form triplets within the mobius strip
local offsets = table{0,1,3}
local function fillMobius(...)
	local initM = table{...}
	return coroutine.wrap(function()
		local function recurse(m)
			for i=1,math.huge do
				if not m[i+offsets[1]] then
					for _,e in ipairs(es) do
						m[i+offsets[1]] = e
						recurse(table(m))
					end
					return
				elseif not m[i+offsets[2]] then
					for _,t in ipairs(tripletsOf(m[i+offsets[1]])) do
						if not m:find(nil, function(t2) return t2.index == t[2].index end) then
							m[i+offsets[2]] = t[2]
							recurse(table(m))
						end
					end
					return
				elseif not m[i+offsets[3]] then
					local t3 = m[i+offsets[1]] * m[i+offsets[2]]
					for j=1,#m-offsets[3]-1 do
						if tablesAreEqual(m:sub(j,j+offsets:last()), m:sub(#m-offsets:last(),#m)) then
							coroutine.yield(m:sub(1,#m-offsets[3]-1))
							return 
						end
					end
					m[i+offsets[3]] = t3
					recurse(m)
					return
				end
			end
		end
		recurse(table(initM))
	end)
end

local initM = table{...}:mapi(function(i)
	local neg = i:sub(1,1) == '-'
	if neg then i = i:sub(2) end
	i = assert(tonumber(i, 16))
	local e = assert(es[i])
	if neg then e = -e end
	return e
end)

local dontOmitIsomorphisms = false

local function mobiusStrips()
	local all = table()
	local uniqueset = table()
	for m in fillMobius(initM:unpack()) do
		local key = m:mapi(function(e) return e.index end):sort():concat'_'
		if dontOmitIsomorphisms or not uniqueset[key] then
			all:insert(m)
			uniqueset[key] = true
		end
	end
	return all
end

local all = mobiusStrips()
for i,m in ipairs(all) do
	print('ring #'..hex(i)..': '..m:mapi(shortname):concat' ')
end

print('number of unique mobius rings:',#all)
