-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSRoutines = private.NewLib("RareScannerRoutines")
local RSLogger = private.ImportLib("RareScannerLogger")

-- Presupuesto de tiempo seguro en milisegundos por frame
local MAX_FRAME_TIME_MS = 2.0

local function getBudgetMS()
	local fps = GetFramerate()
	if (fps and fps > 0) then
		local frameDuration = 1000 / fps
		return math.min(MAX_FRAME_TIME_MS, frameDuration * 0.15)
	end
	
	return MAX_FRAME_TIME_MS
end

-----------------------------------------------------------------------
-- LoopIndexRoutine (Para iterar por índice numérico o número total)
-----------------------------------------------------------------------
local LoopIndexRoutine = {}
LoopIndexRoutine.__index = LoopIndexRoutine

function LoopIndexRoutine:New()
	return setmetatable({}, LoopIndexRoutine)
end

function LoopIndexRoutine:Init(getterItems, processChunk, onfinishCallback, ...)
	self.context = {}
	self.context.currentIndex = 1
	self.context.getterItems = getterItems
	self.context.processChunk = processChunk
	self.context.onfinishCallback = onfinishCallback
	self.context.arguments = { ... }
	self.context.finished = false
	self.isRunning = false
end

function LoopIndexRoutine:Run(processChunk, onfinishCallback)
	if (self.context.finished or self.isRunning) then
		return true
	end
	
	self.isRunning = true

	local callback = processChunk or self.context.processChunk
	local finishCallback = onfinishCallback or self.context.onfinishCallback

	-- Obtención correcta de los datos desde la función o tabla pasados como getter
	local getterData
	if (type(self.context.getterItems) == "function") then
		if (self.context.arguments and #self.context.arguments > 0) then
			getterData = self.context.getterItems(unpack(self.context.arguments))
		else
			getterData = self.context.getterItems()
		end
	else
		getterData = self.context.getterItems
	end

	local totalCount = 0
	if (tonumber(getterData)) then
		totalCount = tonumber(getterData)
	elseif (type(getterData) == "table") then
		totalCount = #getterData
	end

	local function processBatch()
		-- Si no hay ítems o se superó el límite, finaliza
		if (totalCount == 0 or self.context.currentIndex > totalCount) then
			self.context.finished = true
			self.isRunning = false

			if (finishCallback) then
				finishCallback(self.context)
			end
			
			return true
		end

		local deadline = debugprofilestop() + getBudgetMS()

		while (self.context.currentIndex <= totalCount) do
			local i = self.context.currentIndex
			self.context.currentIndex = self.context.currentIndex + 1

			if (callback) then
				callback(self.context, i)
			end

			if (debugprofilestop() >= deadline) then
				C_Timer.After(0, processBatch)
				return false
			end
		end

		self.context.finished = true
		self.isRunning = false

		if (finishCallback) then
			finishCallback(self.context)
		end

		return true
	end

	return processBatch()
end

function LoopIndexRoutine:Restart(callback)
	if (callback) then
		callback(self.context)
	end
	
	return true
end

function LoopIndexRoutine:IsRunning()
	return self.isRunning and not self.context.finished
end

function LoopIndexRoutine:Reset()
	if (self.context) then
		self.context.currentIndex = 1
		self.context.finished = false
	end
	
	self.isRunning = false
end

-----------------------------------------------------------------------
-- InvertedLoopIndexRoutine (Itera índices en orden inverso: de N a 1)
-----------------------------------------------------------------------
local InvertedLoopIndexRoutine = {}
InvertedLoopIndexRoutine.__index = InvertedLoopIndexRoutine

function InvertedLoopIndexRoutine:New()
	return setmetatable({}, InvertedLoopIndexRoutine)
end

function InvertedLoopIndexRoutine:Init(getterItems, processChunk, onfinishCallback, ...)
	self.context = {}
	self.context.getterItems = getterItems
	self.context.processChunk = processChunk
	self.context.onfinishCallback = onfinishCallback
	self.context.arguments = { ... }
	self.context.finished = false
	self.isRunning = false
	self.totalCount = nil
end

function InvertedLoopIndexRoutine:Run(processChunk, onfinishCallback)
	if (self.context.finished or self.isRunning) then
		return true
	end
	
	self.isRunning = true

	local callback = processChunk or self.context.processChunk
	local finishCallback = onfinishCallback or self.context.onfinishCallback

	-- Obtención de los datos la primera vez
	if (not self.totalCount) then
		local getterData
		if (type(self.context.getterItems) == "function") then
			if (self.context.arguments and #self.context.arguments > 0) then
				getterData = self.context.getterItems(unpack(self.context.arguments))
			else
				getterData = self.context.getterItems()
			end
		else
			getterData = self.context.getterItems
		end

		if (tonumber(getterData)) then
			self.totalCount = tonumber(getterData)
		elseif (type(getterData) == "table") then
			self.totalCount = #getterData
		else
			self.totalCount = 0
		end

		-- Inicializamos el índice en el último elemento (al final)
		self.context.currentIndex = self.totalCount
	end

	local function processBatch()
		if (self.totalCount == 0 or self.context.currentIndex < 1) then
			self.context.finished = true
			self.isRunning = false

			if (finishCallback) then
				finishCallback(self.context)
			end
			
			return true
		end

		local deadline = debugprofilestop() + getBudgetMS()

		while (self.context.currentIndex >= 1) do
			local i = self.context.currentIndex
			self.context.currentIndex = self.context.currentIndex - 1

			if (callback) then
				callback(self.context, i)
			end

			if (debugprofilestop() >= deadline) then
				C_Timer.After(0, processBatch)
				return false
			end
		end

		self.context.finished = true
		self.isRunning = false

		if (finishCallback) then
			finishCallback(self.context)
		end

		return true
	end

	return processBatch()
end

function InvertedLoopIndexRoutine:IsRunning()
	return self.isRunning and not self.context.finished
end

function InvertedLoopIndexRoutine:Reset()
	if (self.context) then
		self.context.currentIndex = nil
		self.context.finished = false
	end
	
	self.totalCount = nil
	self.isRunning = false
end

-----------------------------------------------------------------------
-- LoopRoutine (Para iterar tablas clave-valor / diccionarios)
-----------------------------------------------------------------------
local LoopRoutine = {}
LoopRoutine.__index = LoopRoutine

function LoopRoutine:New()
	return setmetatable({}, LoopRoutine)
end

function LoopRoutine:Init(getterItems, processChunk, onfinishCallback, ...)
	self.context = {}
	self.context.currentIndex = 1
	self.context.getterItems = getterItems
	self.context.processChunk = processChunk
	self.context.onfinishCallback = onfinishCallback
	self.context.arguments = { ... }
	self.context.finished = false
	self.isRunning = false
	self.nextKey = nil
	self.currentTable = nil
end

function LoopRoutine:Run(processChunk, onfinishCallback)
	if (self.context.finished or self.isRunning) then
		return true
	end
	
	self.isRunning = true

	local callback = processChunk or self.context.processChunk
	local finishCallback = onfinishCallback or self.context.onfinishCallback

	if (not self.currentTable) then
		if (type(self.context.getterItems) == "function") then
			if (self.context.arguments and #self.context.arguments > 0) then
				self.currentTable = self.context.getterItems(unpack(self.context.arguments))
			else
				self.currentTable = self.context.getterItems()
			end
		else
			self.currentTable = self.context.getterItems
		end
	end

	local function processBatch()
		if (not self.currentTable) then
			self.context.finished = true
			self.isRunning = false
			if (finishCallback) then
				finishCallback(self.context)
			end
			
			return true
		end

		local deadline = debugprofilestop() + getBudgetMS()
		local key, value = next(self.currentTable, self.nextKey)

		while (key ~= nil) do
			self.nextKey = key
			self.context.currentIndex = self.context.currentIndex + 1

			if (callback) then
				callback(self.context, key, value)
			end

			if (debugprofilestop() >= deadline) then
				C_Timer.After(0, processBatch)
				return false
			end

			key, value = next(self.currentTable, self.nextKey)
		end

		self.context.finished = true
		self.isRunning = false
		self.nextKey = nil
		self.currentTable = nil

		if (finishCallback) then
			finishCallback(self.context)
		end

		return true
	end

	return processBatch()
end

function LoopRoutine:Restart(callback)
	if (callback) then
		callback(self.context)
	end
	
	return true
end

function LoopRoutine:IsRunning()
	return self.isRunning and not self.context.finished
end

function LoopRoutine:Reset()
	if (self.context) then
		self.context.currentIndex = 1
		self.context.finished = false
	end
	
	self.nextKey = nil
	self.currentTable = nil
	self.isRunning = false
end

-----------------------------------------------------------------------
-- ChainLoopRoutine (Ejecuta varias rutinas secuencialmente)
-----------------------------------------------------------------------
local ChainLoopRoutine = {}
ChainLoopRoutine.__index = ChainLoopRoutine

function ChainLoopRoutine:New()
	return setmetatable({}, ChainLoopRoutine)
end

function ChainLoopRoutine:Init(chainLoopRoutines)
	self.context = {}
	self.context.chainLoopRoutines = chainLoopRoutines
	self.context.finished = false
	self.isRunning = false
end

function ChainLoopRoutine:Run(onfinishCallback)
	if (self.context.finished or self.isRunning) then
		return
	end

	local totalRoutines = self.context.chainLoopRoutines and #self.context.chainLoopRoutines or 0

	if (totalRoutines == 0) then
		RSLogger:PrintDebugMessage("ChainLoopRoutine: No hay rutinas en la cadena para ejecutar.")
		
		self.context.finished = true
		if (onfinishCallback) then
			onfinishCallback(self.context)
		end
		
		return
	end

	self.isRunning = true

	local function step(currentIndex)
		local currentRoutine = self.context.chainLoopRoutines[currentIndex]

		if (currentRoutine) then
			--RSLogger:PrintDebugMessage(string.format("ChainLoopRoutine: Ejecutando rutina [%d/%d]", currentIndex, totalRoutines))

			if (currentRoutine.Reset) then
				currentRoutine:Reset()
			end

			-- Guardamos el callback original registrado en Init()
			local originalCallback = currentRoutine.context and currentRoutine.context.onfinishCallback

			-- Invocamos Run ejecutando el callback propio Y DESPUÉS el siguiente paso
			currentRoutine:Run(nil, function(ctx)
				if (originalCallback) then
					originalCallback(ctx)
				end
				step(currentIndex + 1)
			end)
		else
			--RSLogger:PrintDebugMessage("ChainLoopRoutine: Cadena finalizada con éxito.")

			self.context.finished = true
			self.isRunning = false

			if (onfinishCallback) then
				onfinishCallback(self.context)
			end
		end
	end

	step(1)
end

function ChainLoopRoutine:IsRunning()
	return self.isRunning and not self.context.finished
end

function ChainLoopRoutine:Reset()
	if (self.context) then
		self.context.finished = false
		if (self.context.chainLoopRoutines) then
			for _, routine in ipairs(self.context.chainLoopRoutines) do
				if routine.Reset then
					routine:Reset()
				end
			end
		end
	end
	
	self.isRunning = false
end

-----------------------------------------------------------------------
-- Métodos de exportación del AddOn
-----------------------------------------------------------------------
function RSRoutines.LoopRoutineNew()
	return LoopRoutine:New()
end

function RSRoutines.LoopIndexRoutineNew()
	return LoopIndexRoutine:New()
end

function RSRoutines.InvertedLoopIndexRoutineNew()
	return InvertedLoopIndexRoutine:New()
end

function RSRoutines.ChainLoopRoutineNew()
	return ChainLoopRoutine:New()
end