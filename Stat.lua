-- made by wrello

-- About
--[[
A module for easily modifiable smooth tweening stats.
]]

type Config_TYPE = {
	max: number?,
	startingVal: number?,
	dir: number?,
	lifeTweenInfo: TweenInfo?,
	speedMult: number?,
	roundOff: number?,
	static: boolean?
}

local TS = game:GetService("TweenService")

local default_config = {
	startingVal = 100,
	dir = 1,
	lifeTweenInfo = TweenInfo.new(),
	speedMult = 1,
	static = false
}

local DEFAULT_TWEEN_INFO = TweenInfo.new()

local Stat = {}
Stat.__index = Stat

function Stat.new(config: Config_TYPE?)
	local self = setmetatable({}, Stat)
	
	for k, v in pairs(default_config) do
		self["_" .. k] = config and config[k] or v
	end
	
	self._numVal = Instance.new("NumberValue")
	self._numVal.Value = self._startingVal
	
	self._changedSig = Instance.new("BindableEvent")
	
	self._numVal.Changed:Connect(function(newVal)
		self._changedSig:Fire(math.floor(newVal + (config.roundOff or 0)), newVal / self.Max)
	end)
	
	self.Changed = self._changedSig.Event
	self.Max = config.max or config.startingVal
	
	if not self._static then
		self:Grow()
	end
	
	return self
end

function Stat:_play(goalVal, tweenInfo)
	local hadTweenInfo = tweenInfo ~= nil
	
	if self._tween then
		self._tween:Cancel()
	end
	
	if not tweenInfo then
		local duration = math.abs(self._numVal.Value - goalVal) / self.Max * (self._lifeTweenInfo.Time / self._speedMult)
		
		if duration == 0 then
			return
		end
		
		tweenInfo = TweenInfo.new(duration, self._lifeTweenInfo.EasingStyle, self._lifeTweenInfo.EasingDirection)
	end
	
	self._tween = TS:Create(self._numVal, tweenInfo, { Value = goalVal })
	self._tween:Play()
	
	if not self._static then
		task.spawn(function()
			local status = self._tween.Completed:Wait()

			if hadTweenInfo then
				self:Grow()
			end
		end)
	end
end

function Stat:_clamp(val)
	return math.clamp(val, 0, self.Max)
end

function Stat:Get(): number
	return self._numVal.Value
end

function Stat:Set(val: number, tweenInfo: TweenInfo?)
	local goalVal = self:_clamp(val)
	
	if tweenInfo then
		self:Inc(goalVal-self._numVal.Value, tweenInfo)
	else
		self:_play(goalVal, DEFAULT_TWEEN_INFO)
	end
	
	return self._tween
end

function Stat:Grow(dir: number?, speedMult: number?): Tween
	assert(not self._static, "this is a static stat, it can't grow")

	if dir and dir ~= self._dir and not speedMult then
		self._speedMult = 1
	else
		self._speedMult = speedMult or self._speedMult
	end

	self._dir = dir or self._dir
	
	self:_play((self.Max*2 + (self._dir-1)*self.Max)/2)
	
	return self._tween
end

function Stat:Inc(inc: number, tweenInfo: TweenInfo?): Tween
	local goalVal = self:_clamp(self._numVal.Value + inc)
	
	if not tweenInfo then
		self:Set(goalVal)
	else
		self:_play(goalVal, tweenInfo)
	end
	
	return self._tween
end

function Stat:Freeze()
	if self._tween and not self._frozen then
		self._frozen = true
		self._tween:Pause()
	end
end

function Stat:Unfreeze()
	if self._tween and self._frozen then
		self._frozen = false
		self._tween:Play()
	end
end

return Stat
