select(2, ...) 'aux'

local event_frame = CreateFrame'Frame'

local listeners = {}

-- auxForever: unused events are unregistered once per frame only after a listener was killed.
-- aux used to compare every listener with every other listener on every frame, all game long,
-- even with the auction house closed.
local killed_any = false

function event.AUX_LOADED()
	event_frame:SetScript('OnUpdate', function()
        if not killed_any then
            return
        end
        killed_any = false
        local needed, dropped = {}, {}
        for id, listener in pairs(listeners) do
            if listener.killed then
                listeners[id] = nil
                dropped[listener.event] = true
            else
                needed[listener.event] = true
            end
        end
        for event in pairs(dropped) do
            if not needed[event] then
                event_frame:UnregisterEvent(event)
            end
        end
    end)

	event_frame:SetScript('OnEvent', function(_, event, ...)
        for id, listener in pairs(listeners) do
            if listener.killed then
                listeners[id] = nil
            elseif event == listener.event then
                listener.cb(...)
            end
        end
    end)
end

function M.kill_listener(listener_id)
	local listener = listeners[listener_id]
	if listener then
		listener.killed = true
		killed_any = true
	end
end

do
    local id = 0
    function M.event_listener(event, cb)
        local listener_id = id
        id = id + 1
        listeners[listener_id] = {
            event = event,
            cb = cb,
        }
        event_frame:RegisterEvent(event)
        return listener_id
    end
end

do
    local threads, kill_signals, error_handlers = {}, {}, {}

    -- auxForever: an error inside a thread used to leave whatever it was doing marked as running
    -- forever (a search stuck on "Updating"). Its error handler now cleans up first; the error is
    -- still raised so BugSack shows it.
    local function resume(thread_id, thread)
        local ok, message = coroutine.resume(thread)
        if not ok then
            threads[thread_id] = nil
            local on_error = error_handlers[thread_id]
            error_handlers[thread_id] = nil
            if on_error then
                on_error(message)
            end
            error(message, 0)
        end
    end

    CreateFrame'Frame':SetScript('OnUpdate', function()
        for thread_id, thread in pairs(threads) do
            local status = coroutine.status(thread)
            if status == 'dead' or kill_signals[thread_id] then
                kill_signals[thread_id] = nil
                threads[thread_id] = nil
                error_handlers[thread_id] = nil
            elseif status == 'suspended' then
                resume(thread_id, thread)
            end
        end
    end)

    -- auxForever: /aux memory detail
    function M.thread_count()
        local n = 0
        for _ in pairs(threads) do n = n + 1 end
        return n
    end

    function M.coro_thread(f, on_error)
        local thread = coroutine.create(f)
        local thread_id = tostring(thread)
        threads[thread_id] = thread
        error_handlers[thread_id] = on_error
        resume(thread_id, thread)
    end

    function M.coro_wait()
        coroutine.yield()
    end

    function M.coro_kill(thread_id)
        kill_signals[thread_id] = true
    end

    function M.coro_id()
        return tostring(coroutine.running())
    end
end

-- auxForever: /aux memory detail
function M.listener_count()
    local n = 0
    for _ in pairs(listeners) do n = n + 1 end
    return n
end
