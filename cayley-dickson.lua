--[[
0 = real
1 = complex
2 = quaternion
3 = octonion
4 = sedenion
--]]
local table = require 'ext.table'
local class = require 'ext.class'
local bit = require 'bit'

local function negative(i,j,x)
	if x == 1 then return false end
	if x == 2 then
		return i == 1 and j == 1
	end
	local prevx = bit.rshift(x,1)
	local previ = i%prevx
	local prevj = j%prevx
	if j >= prevx then
		previ, prevj = prevj, previ	-- right half transpose recursive lookup
	end
	local sign = negative(previ, prevj, prevx)
	if i >= prevx then
		-- flip from j=1 to j=prevx
		if j >= 1 and j <= prevx then sign = not sign end
	end
	return sign 
end


local function defaultConcat(a,b) return tostring(a) .. tostring(b) end


-- index and negative
local Element = class()

function Element:init(args)
	assert(args)
	self.index = assert(args.index)
	self.negative = not not args.negative
end
function Element:__tostring()
	return (self.negative and '-' or '') .. 'e' .. self.index
end
Element.__concat = defaultConcat


local CayleyDickson = class()

function CayleyDickson:init(n)
	local x = 2^n
	for i=1,x do
		self[i] = {}
		for j=1,x do
			self[i][j] = Element{index=bit.bxor(i-1,j-1), negative=negative(i-1,j-1,x)}
		end
	end
end

function CayleyDickson:__tostring()
	local s = ''
	local x = #self
	for j=0,x-1 do
		s=s..'\te'..j
	end
	s=s..'\n'
	for i=0,x-1 do
		s=s..'e'..i
		for j=0,x-1 do
			local index = self[i+1][j+1].index
			local negative = self[i+1][j+1].negative
			s=s..'\t'..(negative == true and '-' or '')..'e'..index
		end
		s=s..'\n'
	end
	s=s..'\n'
	return s
end

function CayleyDickson:getTriplets()
	local x = #self
	local foundSet = {}
	local found = table()
	for i=1,x-1 do
		for j=1,x-1 do
			local entry = self[i+1][j+1]
			if not entry.negative then
				local i,j = i,j
				local k = entry.index
				if j < i then i,j,k = j,k,i end
				if j < i then i,j,k = j,k,i end
				if k < i then i,j,k = k,i,j end
				local triplet = table{i,j,k}
				local key = triplet:concat('_')
				if not foundSet[key] then
					foundSet[key] = true
					found:insert{
						Element{index=i},
						Element{index=j},
						Element{index=k},
					}
				end
			end
		end
	end
	return found
end

function CayleyDickson:printTripletDotGraph(output)
	output = output or print
	local x = #self
	output('digraph CayleyDickson'..x..' {')
	for _,triplet in ipairs(self:getTriplets()) do
		local i,j,k = table.map(triplet, function(el) return el.index end):unpack()
		output('\te'..i..' -> e'..j..' -> e'..k..' -> e'..i..';')
	end
	output('}')
end

return CayleyDickson
