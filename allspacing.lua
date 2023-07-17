#!/usr/bin/env lua
require 'ext'
for p=2,15 do
	for n=0,p do
		for m=0,n do
			if os.execute('./spacing.lua '..m..' '..n..' '..p..' > tmp') then
				local tmp = path'tmp':read()
				path'tmp':remove()
				local lines = tmp:trim():split'\n'
				assert(lines[#lines] == 'found')
				local result = lines[#lines-1]
				print(table{m,n,p}:concat', '..' '..result)
			else
				--print('bad', m, n, p)
			end
		end
	end
end
