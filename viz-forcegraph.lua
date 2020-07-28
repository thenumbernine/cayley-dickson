#!/usr/bin/env luajit
require 'ext'
local ForceDirectedGraph = require 'force-directed-graph'
local CayleyDickson = require 'cayley-dickson'

local m = assert(tonumber(... or 2), "expected <n>")
local c = CayleyDickson(m)
print(c)
local n = #c-1

local nodes = range(n):mapi(function(i)
	return 'e'..i
end)
local weights = range(n):mapi(function(i)
	return range(n):mapi(function(j)
		return 0
	end)
end)
for i=1,n do
	for j=1,n do
		if not c[i+1][j+1].negative then
			weights[i][j] = 1
			weights[j][c[i+1][j+1].index] = 1
		end
	end
end
print(tolua(weights))

local app = ForceDirectedGraph{
	nodes = nodes,
	weights = weights,
}
app:run()
