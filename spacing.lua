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


here are the findings:
m n p:
0, 0, 2 order #1		. .	
0, 1, 2 order #1	0	x .	
2, 2, 2 order #1	0 1	x x	
0, 0, 3 order #1		. . .	
0, 1, 3 order #1	0	x . .	
1, 2, 3 order #1	0 1	x x .	
3, 3, 3 order #1	0 1 2	x x x	
0, 0, 4 order #1		. . . .	
0, 1, 4 order #1	0	x . . .	
2, 3, 4 order #1	0 1 2	x x x .	
4, 4, 4 order #1	0 1 2 3	x x x x	
0, 0, 5 order #1		. . . . .	
0, 1, 5 order #1	0	x . . . .	
3, 4, 5 order #1	0 1 2 3	x x x x .	
5, 5, 5 order #1	0 1 2 3 4	x x x x x	
0, 0, 6 order #1		. . . . . .	
0, 1, 6 order #1	0	x . . . . .	
4, 5, 6 order #1	0 1 2 3 4	x x x x x .	
6, 6, 6 order #1	0 1 2 3 4 5	x x x x x x	
0, 0, 7 order #1		. . . . . . .	
0, 1, 7 order #1	0	x . . . . . .	
1, 3, 7 order #1	0 1 3	x x . x . . .	
2, 4, 7 order #1	0 1 2 4	x x x . x . .	
5, 6, 7 order #1	0 1 2 3 4 5	x x x x x x .	
7, 7, 7 order #1	0 1 2 3 4 5 6	x x x x x x x	
0, 0, 8 order #1		. . . . . . . .	
0, 1, 8 order #1	0	x . . . . . . .	
6, 7, 8 order #1	0 1 2 3 4 5 6	x x x x x x x .	
8, 8, 8 order #1	0 1 2 3 4 5 6 7	x x x x x x x x	
0, 0, 9 order #1		. . . . . . . . .	
0, 1, 9 order #1	0	x . . . . . . . .	
7, 8, 9 order #1	0 1 2 3 4 5 6 7	x x x x x x x x .	
9, 9, 9 order #1	0 1 2 3 4 5 6 7 8	x x x x x x x x x	
0, 0, 10 order #1		. . . . . . . . . .	
0, 1, 10 order #1	0	x . . . . . . . . .	
8, 9, 10 order #1	0 1 2 3 4 5 6 7 8	x x x x x x x x x .	
10, 10, 10 order #1	0 1 2 3 4 5 6 7 8 9	x x x x x x x x x x	
0, 0, 11 order #1		. . . . . . . . . . .	
0, 1, 11 order #1	0	x . . . . . . . . . .	
2, 5, 11 order #1	0 1 2 4 7	x x x . x . . x . . .	
3, 6, 11 order #1	0 1 2 4 5 7	x x x . x x . x . . .	
9, 10, 11 order #1	0 1 2 3 4 5 6 7 8 9	x x x x x x x x x x .	
11, 11, 11 order #1	0 1 2 3 4 5 6 7 8 9 10	x x x x x x x x x x x	
0, 0, 12 order #1		. . . . . . . . . . . .	
0, 1, 12 order #1	0	x . . . . . . . . . . .	
10, 11, 12 order #1	0 1 2 3 4 5 6 7 8 9 10	x x x x x x x x x x x .	
12, 12, 12 order #1	0 1 2 3 4 5 6 7 8 9 10 11	x x x x x x x x x x x x	
0, 0, 13 order #1		. . . . . . . . . . . . .	
0, 1, 13 order #1	0	x . . . . . . . . . . . .	
1, 4, 13 order #1	0 1 3 9	x x . x . . . . . x . . .	
6, 9, 13 order #1	0 1 2 3 4 5 7 9 10	x x x x x x . x . x x . .	
11, 12, 13 order #1	0 1 2 3 4 5 6 7 8 9 10 11	x x x x x x x x x x x x .	
13, 13, 13 order #1	0 1 2 3 4 5 6 7 8 9 10 11 12	x x x x x x x x x x x x x	
0, 0, 14 order #1		. . . . . . . . . . . . . .	
0, 1, 14 order #1	0	x . . . . . . . . . . . . .	
12, 13, 14 order #1	0 1 2 3 4 5 6 7 8 9 10 11 12	x x x x x x x x x x x x x .	
14, 14, 14 order #1	0 1 2 3 4 5 6 7 8 9 10 11 12 13	x x x x x x x x x x x x x x	
0, 0, 15 order #1		. . . . . . . . . . . . . . .	
0, 1, 15 order #1	0	x . . . . . . . . . . . . . .	
3, 7, 15 order #1	0 1 2 4 5 8 10	x x x . x x . . x . x . . . .	
4, 8, 15 order #1	0 1 2 3 5 7 8 11	x x x x . x . x x . . x . . .	
13, 14, 15 order #1	0 1 2 3 4 5 6 7 8 9 10 11 12 13	x x x x x x x x x x x x x x .	
15, 15, 15 order #1	0 1 2 3 4 5 6 7 8 9 10 11 12 13 14	x x x x x x x x x x x x x x x	



--]]
local code = require 'template' [[
require 'ext'
local matrix = require 'matrix'

local once = true
local allSoFar = table()

<? 
local m = tonumber(arg[1]) or 1
local n = tonumber(arg[2]) or 3
local p = tonumber(arg[3]) or 7

--[=[ sedenions in 32-ions
local m = 7
local n = 15
local p = 31
--]=]
--[=[ octonions in sedenions
local m = 3		-- number of elements in common
local n = 7		-- size of subset to look for
local p = 15	-- size of space to scan
--]=]
--[=[ quaternions in octonions
local m = 1
local n = 3
local p = 7
--]=]

?>

local check = matrix.lambda({<?=p?>,<?=p?>}, function(i,j)
	if i==j then return <?=n?> end
	return <?=m?>
end)

<?
local range = require 'ext.range'
for i=1,n do ?>
for o<?=i?>=<?=i==1 and 0 or 'o'..(i-1)..'+1'?>,<?=i==1 and 0 or p-1?> do
<? end ?>
	local offsets = table{<?=range(n):mapi(function(i) return 'o'..i end):concat','?>}
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
	if n == check then
		local expanded = range(<?=p?>):mapi(function(i)
			return offsets:find(i-1) and 'x' or '.'
		end)
		
		local found = allSoFar:find(nil, function(sofar) 
			for shift=0,<?=p-1?> do
				local shifted = range(<?=p?>):mapi(function(i)
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
		if once then
			print('found')
			os.exit(0)
		end
	end
<? for i=1,n do ?>
end
<? end ?>
error"didn't find any"
]]
print(require 'template.showcode'(code))
assert(load(code))(...)
