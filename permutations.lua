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

return permutations
