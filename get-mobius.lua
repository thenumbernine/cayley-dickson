#!/usr/bin/env rua
local CayleyDickson = require 'cayley-dickson'

local c = CayleyDickson(4)
print(c)

local mod1 = |x, p| ((x-1) % p + 1)		-- modulo of 1-based indexes

local shortname = |e| ((e.negative and '-' or '') .. e.index:hex())

local allTriplets = c:getTriplets()

print'quaternions:'
for i,t in ipairs(allTriplets) do
	print('t'..i, table.unpack(t))
end

local function getQuaternionTriplets(e)
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
	io.write('quaternions of e'..shortname(e)..':')
	for _,t in ipairs(getQuaternionTriplets(e)) do
		io.write(' '..t:mapi(shortname):concat'')
	end
	print()
end

print'quaternions of ei * ej:'
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

print('unique mobius octonions in sedenions:')
local function tablesAreEqual(a,b)
	if #a ~= #b then return false end
	for i=1,#a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- offsets of indexes to form triplets within the mobius strip
local quaternionInOctonionOffsets = table{0,1,3}
local function fillMobius(offsets, getSub, ...)
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
					for _,t in ipairs(getSub(m[i+offsets[1]])) do
						if not m:find(nil, function(t2) return t2.index == t[2].index end) then
							m[i+offsets[2]] = t[2]
							recurse(table(m))
						end
					end
					return
				else
					for k=3,#offsets do
						if not m[i+offsets[k]] then
							-- TODO don't use mul ... use pre-stored sets ...
							local t3 = m[i+offsets[k-2]] * m[i+offsets[k-1]]
							for j=1,#m-offsets[k]-1 do
								if tablesAreEqual(m:sub(j,j+offsets[k]), m:sub(#m-offsets[k],#m)) then
									coroutine.yield(m:sub(1,#m-offsets[k]-1))
									return 
								end
							end
							m[i+offsets[k]] = t3
							recurse(m)
							return
						end
					end
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
	local allOctonionsInSedenion = table()
	local uniqueset = table()
	for m in fillMobius(quaternionInOctonionOffsets, getQuaternionTriplets, initM:unpack()) do
		local key = m:mapi(function(e) return e.index end):sort():concat'_'
		if dontOmitIsomorphisms or not uniqueset[key] then
			allOctonionsInSedenion:insert(m)
			uniqueset[key] = true
		end
	end
	return allOctonionsInSedenion
end

local allOctonionsInSedenion = mobiusStrips()
for i,m in ipairs(allOctonionsInSedenion) do
	print('oct #'..i:hex()..': '..m:mapi(shortname):concat' ')
end

print('number of unique mobius octonions in sedenions:', #allOctonionsInSedenion)

-- now remove the trailing minus-parity rings
print('sign-agnostic:')
local signAgnosticOctInSed = table(allOctonionsInSedenion):mapi(|o| table(o):mapi(|e| e.negative and -e or e))
for i=1,#signAgnosticOctInSed do
	local m = signAgnosticOctInSed[i]
	if #m == 14 then
		for j=1,7 do
			assert.eq(m[j+7].index, m[j].index)
		end
		m = table.sub(m, 1, 7)
		signAgnosticOctInSed[i] = m
	end
end
for i,m in ipairs(signAgnosticOctInSed) do
	print('oct #'..i:hex()..': '..m:mapi(shortname):concat' ')
end

-- now, with allOctonionsInSedenion ...
-- ... go through each triplet of e's that are in triplets of r's ...
print('looking for quaternions of octonions that contain each quaternions of basis elements...')
print('...such that the subsequent has two in common with the previous...')
print('...and each triplet of octonions should possess each element once, except the basis triplet which appears 3 times')
do
	local function findOctTripletContainingBasii(i1, i2, i3)
		local results = table()
		--[[ why is this running away when it works a few lines earlier?
		for m in fillMobius(quaternionInOctonionOffsets, getQuaternionTriplets, i1, i2, i3) do
			results:insert(table(m))
		end
		--]]
		-- [[
		for _,o in ipairs(signAgnosticOctInSed) do
			local ofs1 = table.find(o, nil, |e| e.index == i1)
			local ofs2 = table.find(o, nil, |e| e.index == i2)
			local ofs3 = table.find(o, nil, |e| e.index == i3)
			if ofs1 and ofs2 and ofs3 then
				if mod1(ofs2+1, #o) == ofs1 then
					-- reversed
					assert.len(o, 7)
					o = {
						o[mod1(ofs1+0, 7)],
						o[mod1(ofs1+6, 7)],
						o[mod1(ofs1+5, 7)],	-- \
						o[mod1(ofs1+2, 7)], -- |- these two are interchangeable 
						o[mod1(ofs1+1, 7)], -- /
						o[mod1(ofs1+3, 7)], -- \_ these two are interchangeable
						o[mod1(ofs1+4, 7)], -- /
					}
					ofs1 = 1
					ofs2 = 2
					ofs3 = 4
				elseif mod1(ofs2+2, #o) == ofs1 then
					o = {
						o[mod1(ofs1+0, 7)],
						o[mod1(ofs1+5, 7)],
						o[mod1(ofs1+6, 7)],
						o[mod1(ofs1+4, 7)],
						o[mod1(ofs1+1, 7)],
						o[mod1(ofs1+3, 7)],
						o[mod1(ofs1+2, 7)],
					}
					ofs1 = 1
					ofs2 = 2
					ofs3 = 4				
				elseif mod1(ofs2+3, #o) == ofs1 then
					o = {
						o[mod1(ofs1+0, 7)],
						o[mod1(ofs1+4, 7)],
						o[mod1(ofs1+6, 7)],
						o[mod1(ofs1+5, 7)],
						o[mod1(ofs1+3, 7)],
						o[mod1(ofs1+1, 7)],
						o[mod1(ofs1+2, 7)],
					}
					ofs1 = 1
					ofs2 = 2
					ofs3 = 4							
				end
				if mod1(ofs1+1, #o) ~= ofs2 then
					error("idk this order "..tolua{ofs1=ofs1, ofs2=ofs2, ofs3=ofs3}..' for '..o:mapi(shortname):concat' ')
				end
				results:insert(range(#o):mapi(|i| o[mod1(i + ofs1-1, #o)]))
			end
		end
		--]]
		return results
	end

	local startIndexes = table{1,2,3}
	local searchOffsets = table{1,2,4}	-- 1,2,4 == spacing

	local searchForBasisIndexes, sedTriplet
	searchForBasisIndexes = startIndexes 
	sedTriplet = findOctTripletContainingBasii(searchForBasisIndexes:unpack())
	print('triplet containing '..searchForBasisIndexes:concat' ')
	for _,o in ipairs(sedTriplet) do
		print(' '..o:mapi(shortname):concat' ')
	end

	for iter=1,6 do
		searchForBasisIndexes = searchOffsets:mapi(|i| sedTriplet[1][i+1].index)
		sedTriplet = findOctTripletContainingBasii(searchForBasisIndexes:unpack())
		print('triplet containing '..searchForBasisIndexes:concat' ')
		for _,o in ipairs(sedTriplet) do
			print(' '..o:mapi(shortname):concat' ')
		end
	end
end



--[[ TODO fill sedenion mobius ...
local octonionInSedenionOffsets = {0, 1, 2, 4, 5, 8, 10} 
local function getSubOctonions(e)
	local ts = table()
	for _,t in ipairs(allOctonionsInSedenion) do
		for j=1,7 do
			if t[j].index == e.index then
				ts:insert(table{
					t[j],
					t[j%7+1],
					t[(j+1)%7+1],
					t[(j+2)%7+1],
					t[(j+3)%7+1],
					t[(j+4)%7+1],
					t[(j+5)%7+1],
				})
				break
			end
		end
	end
	return ts
end

for m in fillMobius(octonionInSedenionOffsets, getSubOctonions, 1, 2, 4, 3) do
	print(m:concat' ')
end
--]]
