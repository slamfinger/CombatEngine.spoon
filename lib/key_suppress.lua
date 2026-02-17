-- lib/key_suppress.lua
-- Simple time-based suppression for specific keys.
local M = {
    _until = {},
}

function M.suppress(key, duration)
    if not key then return end
    local now = hs.timer.secondsSinceEpoch()
    M._until[key] = now + (duration or 0.05)
end

function M.isSuppressed(key, now)
    if not key then return false end
    local t = M._until[key]
    if not t then return false end
    now = now or hs.timer.secondsSinceEpoch()
    if now >= t then
        M._until[key] = nil
        return false
    end
    return true
end

return M
