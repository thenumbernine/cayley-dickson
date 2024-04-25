#!/usr/bin/env lua
local string = require 'ext.string'
local table = require 'ext.table'
local path = require 'ext.path'
for p=2,15 do
	for n=0,p do
		for m=0,n do
			-- TODO figure out if ctrl-c was pressed and genuinely quit 
			if os.execute('./spacing.lua '..m..' '..n..' '..p..' > tmp') then
				local tmp = path'tmp':read()
				path'tmp':remove()
				local lines = string.split(string.trim(tmp), '\n')
				assert(lines[#lines] == 'found')
				local result = lines[#lines-1]
				print(table{m,n,p}:concat', '..' '..result)
			else
				--print('bad', m, n, p)
			end
		end
	end
end
