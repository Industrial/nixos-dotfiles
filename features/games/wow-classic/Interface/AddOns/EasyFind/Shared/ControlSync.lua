local _, ns = ...

local Utils = ns.Utils
local pairs = Utils.pairs



























local ControlSync = {}
ns.ControlSync = ControlSync

local registrations = {}

local function LiveGate(reg)
    if reg.live then return reg.live() end
    return reg.available()
end

local function Dirty(reg, state)
    return reg.isDirty and reg.isDirty(state) or false
end

local function Arm(reg)
    if reg._armed then return end
    reg._armed = true
    local function tick()
        local db = EasyFind and EasyFind.db
        if not (db and db[reg.pendingKey]) then
            reg._armed = false
            return
        end
        if LiveGate(reg) then
            reg._armed = false
            ControlSync.Deliver(reg.key)
            return
        end
        Utils.SafeAfter(1, tick)
    end
    Utils.SafeAfter(1, tick)
end




function ControlSync.Deliver(key)
    local reg = registrations[key]
    local db = EasyFind and EasyFind.db
    if not (reg and db) then return end
    if reg.liveApply and LiveGate(reg) then
        Utils.SafeAfter(0.3, function()
            if not LiveGate(reg) then return end
            reg.liveApply(reg.state())
            if reg.clearDirty then reg.clearDirty(reg.state()) end
        end)
    end
    db[reg.pendingKey] = false
end

function ControlSync.Register(reg)
    registrations[reg.key] = reg
    return reg
end

function ControlSync.MarkPending(key)
    local reg = registrations[key]
    local db = EasyFind and EasyFind.db
    if not (reg and db) then return end
    db[reg.pendingKey] = true
    Arm(reg)
end




function ControlSync.Push(key)
    local reg = registrations[key]
    local db = EasyFind and EasyFind.db
    if not (reg and db) then return false end
    local state = reg.state()
    if not reg.available() then
        db[reg.pendingKey] = true
        Arm(reg)
        return false
    end
    reg.push(state)
    if not LiveGate(reg) and Dirty(reg, state) then
        db[reg.pendingKey] = true
        Arm(reg)
        return true
    end
    db[reg.pendingKey] = false
    if reg.liveApply and LiveGate(reg) then
        Utils.SafeAfter(0.3, function()
            if not LiveGate(reg) then return end
            reg.liveApply(reg.state())
            if reg.clearDirty then reg.clearDirty(reg.state()) end
        end)
    elseif reg.clearDirty and not Dirty(reg, state) then
        reg.clearDirty(state)
    end
    return true
end


function ControlSync.Sync(key)
    local reg = registrations[key]
    local db = EasyFind and EasyFind.db
    if not (reg and db) then return false end
    if db[reg.pendingKey] then
        return ControlSync.Push(key)
    end
    if not reg.available() then return false end
    reg.pull(reg.state())
    return true
end



function ControlSync.ArmAtLoginIfNeeded(key)
    local reg = registrations[key]
    local db = EasyFind and EasyFind.db
    if not (reg and db) then return end
    if db[reg.pendingKey] then
        Arm(reg)
        return
    end
    if reg.reconcile then
        Utils.SafeAfter(1, function()
            if EasyFind.db and not EasyFind.db[reg.pendingKey] and reg.available() then
                reg.pull(reg.state())
            end
        end)
    end
end

function ControlSync.ArmAllAtLogin()
    for key in pairs(registrations) do
        ControlSync.ArmAtLoginIfNeeded(key)
    end
end
