-- made by wrello, started 9/6/2021
-- last updated 12/12/2022

-- About
--[[
Turns a table into instances that when changed, update the table.

For example:

local dataTable = {
	_children = {
		foo = {
			_value = 0, -- Will automatically be of class "NumberValue"
			_className = "IntValue", -- Will force foo to be of class "IntValue",
			_name = "Foo", -- If '_name' is not provided, the instance's name will default to the key, i.e. "foo"

			_children = {
				bar = {} -- Will automatically register as a folder with the name "bar"
			}
		}
	},

	_ignore = true -- This will make sure the children of this tabel level will not be parented to a folder, i.e. parented directly to the player
}

TableToInstances(dataTable, player)

player.foo.Value = 5

print(dataTable._children.foo._value)
]]

local SUPPORTED_VALUE_TYPES = {"BoolValue", "StringValue", "NumberValue", "IntValue"}
local UNSUPPORTED_VALUE_TYPE_ERROR = "cannot load or save %s with a value type of %s"

local function reconcileInstanceData(instanceData, name)
	if instanceData._children == nil then
		instanceData._children = {}
	end

	if not instanceData._ignore then
		if instanceData._name == nil and name then
			instanceData._name = name
		end
		
		instanceData._name = tostring(instanceData._name)
		
		if instanceData._attributes == nil then
			instanceData._attributes = {}
		end

		if instanceData._className == nil then
			if instanceData._value then
				local type = typeof(instanceData._value)

				if type == "number" then
					instanceData._className = "NumberValue"
				elseif type == "boolean" then
					instanceData._className = "BoolValue"
				elseif type == "string" then
					instanceData._className = "StringValue"
				else
					error(UNSUPPORTED_VALUE_TYPE_ERROR:format(instanceData._name, type))
				end
			else
				instanceData._className = "Folder"
			end
		end
	end
end

local function addChild(children, child)
	local childInstanceData = instanceToInstanceData(child)

	children[childInstanceData._name] = childInstanceData

	autoUpdate(child, childInstanceData, children)
end

function instanceToInstanceData(inst)
	local instanceData = {
		_name = inst.Name,
		_attributes = inst:GetAttributes(),
		_className = inst.ClassName,
		_children = {}
	}

	if inst:IsA("ValueBase") then
		assert(table.find(SUPPORTED_VALUE_TYPES, inst.ClassName), UNSUPPORTED_VALUE_TYPE_ERROR:format(inst:GetFullName(), inst.ClassName))

		instanceData._value = inst.Value
	end
	
	for _, child in ipairs(inst:GetChildren()) do
		addChild(instanceData._children, child)
	end
	
	return instanceData
end

local function removeChild(children, child)
	for k, childInstanceData in pairs(children) do
		if childInstanceData._name == child.Name then
			children[k] = nil
		end
	end
end

function autoUpdate(inst, instanceData, siblings)
	local parent = inst.Parent
	local connections = {}
	
	local function updateKeyAmongSiblings()
		for k, v in pairs(siblings) do
			if v == instanceData then
				siblings[k] = nil
				siblings[instanceData._name] = instanceData
				break
			end
		end
	end
	
	if siblings then
		updateKeyAmongSiblings()
	end
	
	if inst:IsA("ValueBase") then
		assert(table.find(SUPPORTED_VALUE_TYPES, inst.ClassName), UNSUPPORTED_VALUE_TYPE_ERROR:format(inst:GetFullName(), inst.ClassName))

		table.insert(connections, inst.Changed:Connect(function(val)
			instanceData._value = val
		end))
	end
	
	table.insert(connections, inst:GetPropertyChangedSignal("Name"):Connect(function()
		instanceData._name = inst.Name
		
		updateKeyAmongSiblings()
	end))
	
	table.insert(connections, inst.ChildAdded:Connect(function(child)
		addChild(instanceData._children, child)
	end))

	table.insert(connections, inst.ChildRemoved:Connect(function(child)
		removeChild(instanceData._children, child)
	end))

	table.insert(connections, inst.AttributeChanged:Connect(function()
		instanceData._attributes = inst:GetAttributes()
	end))
	
	table.insert(connections, inst.AncestryChanged:Connect(function(child, newParent)
		if child == inst and newParent ~= parent then
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end

			table.clear(connections)
		end
	end))
end

local function instanceDataToInstance(instanceData, parent, name, siblings)
	reconcileInstanceData(instanceData, name)

	local inst = parent

	if not instanceData._ignore then
		inst = Instance.new(instanceData._className)

		inst.Name = instanceData._name

		if instanceData._value then
			inst.Value = instanceData._value
		end

		for attrName, attrVal in pairs(instanceData._attributes) do
			inst:SetAttribute(attrName, attrVal)
		end

		inst.Parent = parent
		
		-- Auto update everything after it's finished
		task.defer(function()
			autoUpdate(inst, instanceData, siblings)
		end)
	end
	
	for k, v in pairs(instanceData._children) do
		instanceDataToInstance(v, inst, k, instanceData._children)
	end
end

local function tableToInstances(src, dst)
	instanceDataToInstance(src, dst)
	
	dst:SetAttribute("InstanceTableLoaded", true)
	
	return src
end

return setmetatable({
	AwaitLoad = function(dst)
		if not dst:GetAttribute("InstanceTableLoaded") then
			dst:GetAttributeChangedSignal("InstanceTableLoaded"):Wait()
		end
	end,
}, {
	__call = function(_, ...)
		return tableToInstances(...)
	end
})
