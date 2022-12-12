-- made by wrello

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({ _signal = signal, Handler = handler }, Connection)
end

function Connection:Disconnect()
	table.remove(self._signal._connections, table.find(self._signal._connections, self))
end

local Signal = {}
Signal.__index = Signal

function Signal.new() : RBXScriptSignal
	return setmetatable({ _connections = {}, _waitingThreads = {} }, Signal)
end

function Signal:Wait()
	table.insert(self._waitingThreads, coroutine.running())

	return coroutine.yield()
end

function Signal:Connect(handler)
	local conn = Connection.new(self, handler)
	
	table.insert(self._connections, conn)
	
	return conn
end

function Signal:Fire(...)
	for _, waitingThread in ipairs(self._waitingThreads) do
		task.spawn(waitingThread, ...)
	end
	
	for _, conn in ipairs(self._connections) do
		task.spawn(conn.Handler, ...)
	end
	
	table.clear(self._waitingThreads)
end

return Signal
