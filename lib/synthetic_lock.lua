-- lib/synthetic_lock.lua
-- Simple ref-counted synthetic input lock to avoid premature unlocks.
local config = require("config")
local M = {
    _count = 0,
}

function M.acquire()
    M._count = M._count + 1
    _G.__KSP_synthetic = true
end

function M.release()
    if M._count == 0 then
        if config.debug then
            print("synthetic_lock: release called with count=0")
        end
        return
    end
    M._count = M._count - 1
    if M._count == 0 then
        _G.__KSP_synthetic = false
    end
end

function M.reset()
    M._count = 0
    _G.__KSP_synthetic = false
end

function M.count()
    return M._count
end

function M.isLocked()
    return M._count > 0
end

return M
