-- made by wrello

--[[
Lightweight custom Maid class
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _things = {} }, Maid)
end

function Maid:Add(thing)
	table.insert(self._things, thing)
	
	return thing
end

function Maid:Clean()
	for _, thing in ipairs(self._things) do
		local type = typeof(thing)
		
		if type == "Instance" then
			if thing:IsA("AnimationTrack") then
				thing:Stop()
			else
				thing:Destroy()
			end
		elseif type == "table" then
			thing:Destroy()
		elseif type == "RBXScriptConnection" then
			thing:Disconnect()
		elseif type == "function" then
			thing()
		elseif type == "thread" then
			pcall(task.cancel, thing)
		end
	end
end

function Maid:Destroy()
	self:Clean()
end

return Maid
