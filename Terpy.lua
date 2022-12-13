-- made by wrello, started 1/7/2022
-- last update 12/12/2022
-- v1.3.2

--[[

	[ TERMS ]

		"Terpy objects" - All descendants of the container that have transparency
		related properties, and the container itself if it does.

		"overall transparency" - The goal transparency of every Terpy Object relative
		to their original transparencies (or not if the 'ignoreOriginalTransparencies'
		optional boolean argument was set to true when calling ':SetTransparency()' or
		':TweenTransparency()').

			Example:

			1) object original transparency = .5
			2) new overall transparency = .5
			3) object's new transparency relative to original transparency = .25


	[ CONSTRUCTOR ]

		<Terpy_INSTANCE> Terpy.new(<any> container, <boolean?> startTransparent)

			Creates a new Terpy instance. If
			start transparent is true, then the Terpy objects will
			become transparent upon construction of the new Terpy.


    [ METHODS ]

        <void> Terpy:SetTransparency(<number> transparency, <boolean?> ignoreOriginalTransparencies)

			Sets the Terpy objects' transparencies
			instantly (relative to their original transparencies
			if not 'ignoreOriginalTransparencies').


        <Tween> Terpy:TweenTransparency(<TweenInfo> tweenInfo, <number> transparency, <boolean?> ignoreOriginalTransparencies)

 			Use on the client only for smooth tweens.

           	Tweens the Terpy objects' transparencies
			over a period of time (relative to their original
			transparencies if not 'ignoreOriginalTransparencies').

		<void> Terpy:Destroy()

			Disconnects connections and cancels + destroys tweens 
			(called automatically when the container gets destroyed).


	[ PROPERTIES ]

		@readonly

		<number> Terpy.Transparency

			The current overall transparency of the collection of
			Terpy objects.


    [ USAGE ]

        -- In a LocalScript in StarterPlayerScripts

        local Terpy = require(script.Terpy)

    	local dummyModelTerpy = Terpy.new(workspace.Dummy)
    	local goalTransparency = 1
    	local ignoreOriginalTransparencies = true

    	dummyModelTerpy:SetTransparency(goalTransparency, ignoreOriginalTransparencies) -- Sets the model completely invisible (all descendants with transparency related properties get this value)

    	task.wait(2)

    	local tweenInfo = TweenInfo.new(1)
    	goalTransparency = 0

    	dummyModelTerpy:TweenTransparency(tweenInfo, goalTransparency) -- Tweens the model back to its original visibility (all descendants with transparency related properties go back to their original values)

--]]

type Terpy_STATIC = {
	new: (container: any, startTransparent: boolean?) -> Terpy_INSTANCE
}
type Terpy_INSTANCE = {
	Transparency: number,
	SetTransparency: (self: Terpy_INSTANCE, goalTransparency: number, ignoreOriginalTransparencies: boolean?) -> (),
	TweenTransparency: (self: Terpy_INSTANCE, tweenInfo: TweenInfo, goalTransparency: number, ignoreOriginalTransparencies: boolean?) -> Tween,
	Destroy: (self: Terpy_INSTANCE) -> ()
}

local TS = game:GetService("TweenService")

local objectInfo = {
	{
		checkMethod = "ClassName.find",
		checkMethodInputs = { "Image[BL]", "ViewportFrame" },
		transparencyProps = { "ImageTransparency" }
	},

	{
		checkMethod = "ClassName.find",
		checkMethodInputs = { "^Selection" },
		transparencyProps = { "SurfaceTransparency", "Transparency" }
	},

	{
		checkMethod = "ClassName.find",
		checkMethodInputs = { "Text[BL]" },
		transparencyProps = { "TextTransparency", "TextStrokeTransparency" }
	},

	{
		checkMethod = "IsA",
		checkMethodInputs = { "GuiObject" },
		transparencyProps = { "BackgroundTransparency" }
	},

	{
		checkMethod = "IsA",
		checkMethodInputs = { "BasePart", "Decal", "Texture", "ImageHandleAdornment", "SurfaceSelection", "UIStroke" },
		transparencyProps = { "Transparency" }
	},

	{
		checkMethod = "IsA",
		checkMethodInputs = { "ScrollingFrame" },
		transparencyProps = { "ScrollBarImageTransparency" }
	},
}

local function getTransparencyProps(object, goalTransparency)
	local totalTransparencyProps = {}

	for _, objInfo in ipairs(objectInfo) do
		local checkMethodTokens = string.split(objInfo.checkMethod, ".")
		local currToken = object
		local hasTransparencyProp = false

		local len = #checkMethodTokens

		for i = 1, len-1 do
			currToken = currToken[checkMethodTokens[i]]
		end

		for _, checkMethodInput in ipairs(objInfo.checkMethodInputs) do
			hasTransparencyProp = currToken[checkMethodTokens[len]](currToken, checkMethodInput)

			if hasTransparencyProp then
				break
			end
		end

		if hasTransparencyProp then
			for _, transparencyProp in ipairs(objInfo.transparencyProps) do
				totalTransparencyProps[transparencyProp] = goalTransparency or object[transparencyProp]
			end
		end
	end

	if next(totalTransparencyProps) == nil then return nil end

	return totalTransparencyProps
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local Terpy = {}
Terpy.__index = Terpy

function Terpy.new(container: any, startTransparent: boolean?): Terpy_INSTANCE
	local self = setmetatable({
		Transparency = 0,

		_container = container,
		_tweens = {},
		_conns = {}
	}, Terpy)

	self:_listenContainerDestroyed()
	self:_listenDescendantAddedRemoved()
	self:_initialCache()

	if startTransparent then
		self:SetTransparency(1)
	end

	return self
end

-- Init
function Terpy:_listenContainerDestroyed()
	table.insert(self._conns, self._container.Destroying:Connect(function()
		self:Destroy()
	end))
end

function Terpy:_listenDescendantAddedRemoved()
	table.insert(self._conns, self._container.DescendantAdded:Connect(function(obj)
		self:_cache(obj)
	end))

	table.insert(self._conns, self._container.DescendantRemoving:Connect(function(obj)
		self._originalTransparencies[obj] = nil
		table.remove(self._terpyObjects, table.find(self._terpyObjects, obj))

		for i, tween in ipairs(self._tweens) do
			if tween.Instance == obj then
				if tween.PlaybackState == Enum.PlaybackState.Playing then
					tween:Cancel()
				end

				tween:Destroy()

				table.remove(self._tweens, i)

				break
			end
		end
	end))
end

function Terpy:_initialCache()
	self._terpyObjects = {}
	self._originalTransparencies = {}

	for _, obj in ipairs(self._container:GetDescendants()) do
		self:_cache(obj)
	end

	self:_cache(self._container)
end

-- Private
function Terpy:_playTweens()
	for _, tween in ipairs(self._tweens) do
		tween:Play()
	end
end

function Terpy:_cancelTweens()
	for _, tween in ipairs(self._tweens) do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end

		tween:Destroy()
	end

	table.clear(self._tweens)
end

function Terpy:_cache(obj)
	local originalTransparencies = getTransparencyProps(obj)

	if originalTransparencies then
		self._originalTransparencies[obj] = originalTransparencies

		table.insert(self._terpyObjects, obj)

		for transparencyProperty, originalTransparency in pairs(originalTransparencies) do
			obj[transparencyProperty] = lerp(originalTransparency, 1, self.Transparency)
		end
	end
end

-- Public
--[[
     Sets the overall transparency instantly.
	@param(transparency : number) The transparency to set each descendant to (relative to their original transparencies if not 'ignoreOriginalTransparencies')
	@param(ignoreOriginalTransparencies : boolean?) Optional argument in order to set all descendant transparencies to the given transparency regardless of their original transparencies
]]
function Terpy:SetTransparency(goalTransparency: number, ignoreOriginalTransparencies: boolean?)
	self.Transparency = goalTransparency

	self:_cancelTweens()

	for _, terpyObj in ipairs(self._terpyObjects) do
		for transparencyProperty, originalTransparency in pairs(self._originalTransparencies[terpyObj]) do
			if ignoreOriginalTransparencies then
				terpyObj[transparencyProperty] = goalTransparency
			else
				terpyObj[transparencyProperty] = lerp(originalTransparency, 1, goalTransparency)
			end
		end
	end
end

--[[
	 Tweens the overall transparency over a period of time (use on the client only for smooth tweens).
	@param(tweenInfo : TweenInfo) The tween info with which to tween each descendant
	@param(transparency : number) The transparency to tween each descendant to (relative to their original transparencies if not 'ignoreOriginalTransparencies')
	@param(ignoreOriginalTransparencies : boolean?) Optional argument in order to tween all descendant transparencies to the given transparency regardless of their original transparencies
	@return(Tween) A tween to use events on such as '.Completed:Wait()'
]]
function Terpy:TweenTransparency(tweenInfo: TweenInfo, goalTransparency: number, ignoreOriginalTransparencies: boolean?): Tween
	self.Transparency = goalTransparency

	self:_cancelTweens()

	for _, terpyObj in ipairs(self._terpyObjects) do
		local propertyTable = {}

		for transparencyProperty, originalTransparency in pairs(self._originalTransparencies[terpyObj]) do
			if ignoreOriginalTransparencies then
				propertyTable[transparencyProperty] = goalTransparency
			else
				propertyTable[transparencyProperty] = lerp(originalTransparency, 1, goalTransparency)
			end
		end

		table.insert(self._tweens, TS:Create(terpyObj, tweenInfo, propertyTable))
	end

	self:_playTweens()

	return self._tweens[1]
end

--[[
	 Disconnects connections and cancels + destroys tweens (called automatically when the container gets destroyed).
]]
function Terpy:Destroy()
	for _, conn in ipairs(self._conns) do
		conn:Disconnect()
	end

	self:_cancelTweens()
end

return Terpy :: Terpy_STATIC
