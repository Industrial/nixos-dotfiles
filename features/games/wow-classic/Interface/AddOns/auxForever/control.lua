select(2, ...) 'aux'

local event_frame = CreateFrame'Frame'

local listeners = {}

-- auxForever: unused events are unregistered once per frame only after a listener was killed.
-- aux used to compare every listener with every other listener on every frame, all game long,
-- even with the auction house closed.
local killed_any = false

-- 0.8.2.1 (outside review 2026-11-10, R-18): an event goes to the listeners in the order they were
-- made, from a list that is only built again after a listener was added or removed. aux walked the
-- listeners table itself, and a callback that starts a scan adds listeners to it during that walk;
-- Lua leaves the rest of such a walk undefined, so a listener could be skipped (its scan then waited
-- out a timeout) or called twice. A listener made while an event is handed out gets the next event.
local order, order_stale = {}, true

local function listener_order()
    if order_stale then
        order_stale = false
        -- a new list each time: an event being handed out keeps the one it started with
        local list = {}
        for id, listener in pairs(listeners) do
            if not listener.killed then
                listener.id = id
                tinsert(list, listener)
            end
        end
        sort(list, function(a, b) return a.id < b.id end)
        order = list
    end
    return order
end

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
        order_stale = true
        for event in pairs(dropped) do
            if not needed[event] then
                event_frame:UnregisterEvent(event)
            end
        end
    end)

	event_frame:SetScript('OnEvent', function(_, event, ...)
        local list = listener_order()
        for i = 1, #list do
            local listener = list[i]
            if not listener.killed and event == listener.event then
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
        order_stale = true
        event_frame:RegisterEvent(event)
        return listener_id
    end
end

do
    local threads, kill_signals, error_handlers = {}, {}, {}

    -- auxForever: an error inside a thread used to leave whatever it was doing marked as running
    -- forever (a search stuck on "Updating"). Its error handler now cleans up first; the error is
    -- still raised so BugSack shows it.
    -- 0.8.2.1 (outside review 2026-11-10, R-07, FB-027): long loops paused every so many items, so a
    -- Full scan read 100 auctions a frame however little of the frame that took, and its length was
    -- set by the frame rate (215,090 auctions in about 48 seconds, Tyler, 2026-11-09). A thread now
    -- gets a share of each frame by the clock: coro_due says when it is used up. Without the game's
    -- clock (debugprofilestop, milliseconds) the old counts are used.
    local slice_start

    local function resume(thread_id, thread)
        local clock = debugprofilestop
        slice_start = clock and clock() or nil
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

    -- 0.8.2.1 (outside review 2026-11-10, R-18): the threads to run this frame are listed first (one
    -- list, used again every frame). A thread that starts another (a scan that ends and starts the
    -- next) adds to the threads table, which must not happen while that table itself is walked. The
    -- new thread already ran up to its first pause when it was made; it goes on next frame.
    local running = {}

    CreateFrame'Frame':SetScript('OnUpdate', function()
        local n = 0
        for thread_id in pairs(threads) do
            n = n + 1
            running[n] = thread_id
        end
        for i = n + 1, #running do
            running[i] = nil
        end
        for i = 1, n do
            local thread_id = running[i]
            local thread = threads[thread_id]
            if thread then
                local status = coroutine.status(thread)
                if status == 'dead' or kill_signals[thread_id] then
                    kill_signals[thread_id] = nil
                    threads[thread_id] = nil
                    error_handlers[thread_id] = nil
                elseif status == 'suspended' then
                    resume(thread_id, thread)
                end
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

    -- milliseconds of one frame a thread may use before it pauses (a start value: 60 frames a
    -- second leave about 16 for everything)
    M.SLICE_MS = 8

    -- whether a loop at its i-th item should pause now: when the thread's share of this frame is
    -- used up (looked at every 10 items), or every `every` items when the game has no clock
    function M.coro_due(i, every)
        local clock = debugprofilestop
        if clock and slice_start then
            return i % 10 == 0 and clock() - slice_start >= SLICE_MS
        end
        return i % every == 0
    end

    -- pauses a loop when coro_due says so
    function M.coro_slice(i, every)
        if coro_due(i, every) then
            coroutine.yield()
        end
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
