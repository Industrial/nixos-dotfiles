local _, ns = ...










































local Scheduler = {}
Scheduler.__index = Scheduler








local dps = rawget(_G, "debugprofilestop")
local osclock = os and os.clock
local function wallClock()
    if dps then return dps() / 1000 end
    return osclock and osclock() or 0
end




local debugstack_ = rawget(_G, "debugstack")
local debugtraceback = (rawget(_G, "debug") and rawget(_G, "debug").traceback) or nil
local function errorHandler(err)
    if debugstack_ then
        return tostring(err) .. "\n" .. debugstack_(2)
    elseif debugtraceback then
        return debugtraceback(tostring(err), 2)
    end
    return tostring(err)
end




function Scheduler.new()
    return setmetatable({
        jobs = {},
        queue = {},
        now = 0,
        budgetSeconds = 0.002,
        onError = nil,
    }, Scheduler)
end





function Scheduler:Register(id, spec)
    assert(type(id) == "string" and id ~= "", "Scheduler:Register requires a non-empty id")
    assert(type(spec) == "table" and type(spec.run) == "function",
        "Scheduler:Register requires { run = function }")
    self.jobs[id] = {
        id = id,
        spec = spec,
        status = "pending",
        debounceUntil = 0,
        completed = false,
    }
end




function Scheduler:IsComplete(id)
    local job = self.jobs[id]
    return job ~= nil and job.status == "complete"
end




function Scheduler:Status(id)
    local job = self.jobs[id]
    return job and job.status or nil
end

local function removeFromQueue(queue, id)
    for i = #queue, 1, -1 do
        if queue[i] == id then
            table.remove(queue, i)
            return
        end
    end
end






function Scheduler:Enqueue(id)
    local job = self.jobs[id]
    if not job then return false end
    if job.status == "complete" then return false end
    if job.status == "queued" or job.status == "running" then
        if job.spec.debounce then
            job.debounceUntil = self.now + job.spec.debounce
        end
        return true
    end



    local deps = job.spec.deps
    if deps then
        for i = 1, #deps do
            self:Enqueue(deps[i])
        end
    end
    job.status = "queued"
    job.debounceUntil = job.spec.debounce and (self.now + job.spec.debounce) or 0
    table.insert(self.queue, id)
    self:_ArmPump()
    return true
end



function Scheduler:_ArmPump()
    local frame = self._pumpFrame
    if frame and not self._pumping then
        self._pumping = true
        frame:SetScript("OnUpdate", self._pumpFn)
    end
end






function Scheduler:CancelGroup(group)
    for id, job in pairs(self.jobs) do
        if job.spec.cancelGroup == group then
            removeFromQueue(self.queue, id)
            job.status = "pending"
            job.completed = false
        end
    end
end



function Scheduler:Reset(id)
    local job = self.jobs[id]
    if not job then return end
    removeFromQueue(self.queue, id)
    job.status = "pending"
    job.completed = false
end



function Scheduler:SetBudgetMs(ms)
    self.budgetSeconds = math.max(0, (ms or 0) / 1000)
end

local function jobReady(scheduler, job)
    if job.status ~= "queued" then return false end
    if job.debounceUntil > scheduler.now then return false end
    local deps = job.spec.deps
    if deps then
        for i = 1, #deps do
            local depJob = scheduler.jobs[deps[i]]
            if not depJob or depJob.status ~= "complete" then
                return false
            end
        end
    end
    return true
end

local function pickReadyJob(scheduler)
    local queue = scheduler.queue
    for i = 1, #queue do
        local job = scheduler.jobs[queue[i]]
        if job and jobReady(scheduler, job) then
            return queue[i]
        end
    end
    return nil
end

local function makeDone(scheduler, job)
    return function(ok, err)
        if job.completed then return end
        job.completed = true
        if ok == false then
            job.status = "pending"
            if scheduler.onError then
                scheduler.onError(job.id, err)
            end
        else
            job.status = "complete"
        end
    end
end

local function runJob(scheduler, id)
    local job = scheduler.jobs[id]
    if not job then return end
    removeFromQueue(scheduler.queue, id)
    job.status = "running"
    job.completed = false
    local done = makeDone(scheduler, job)
    local ctx = { jobId = id, scheduler = scheduler }
    local ok, err = xpcall(job.spec.run, errorHandler, ctx, done)
    if not ok then
        done(false, err)
    end




end






function Scheduler:Step(elapsed, budgetSeconds)
    self.now = self.now + (elapsed or 0)
    local startWall = budgetSeconds and wallClock() or nil
    while true do
        local id = pickReadyJob(self)
        if not id then
            if self._pumping and #self.queue == 0 then
                self._pumping = false
                self._pumpFrame:SetScript("OnUpdate", nil)
            end
            return
        end
        runJob(self, id)
        if startWall and (wallClock() - startWall) > budgetSeconds then
            return
        end
    end
end





function Scheduler:StartPump(frame)
    if self._pumpFrame then return end
    assert(frame and frame.SetScript, "Scheduler:StartPump requires a frame with SetScript")
    self._pumpFrame = frame
    self._pumpFn = function(_, dt)
        self:Step(dt or 0, self.budgetSeconds)
    end
    if #self.queue > 0 then self:_ArmPump() end
end


local default = Scheduler.new()

if ns then
    ns.Scheduler = default
    ns.SchedulerType = Scheduler
end
return Scheduler
