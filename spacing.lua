#!/usr/bin/env lua
-- print all spacings of 7-mobius-strips in 15x15 grid such that all pairs of mobius strips share 3 elements in common
require 'ext'
local matrix = require 'matrix'
for o1=0,15 do
	for o2=o1+1,15 do
		for o3=o2+1,15 do
			for o4=o3+1,15 do
				for o5=o4+1,15 do
					for o6=o5+1,15 do
						for o7=o6+1,15 do
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
								print('offsets:', offsets:unpack())
								--print(m,'\n')
								--print(n,'\n')
							end
						end
					end
				end
			end
		end
	end
end
