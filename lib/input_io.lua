-- Spoons/CombatEngine.spoon/lib/input_io.lua
-- 整合版：包含执行、标记、锁机制 (synthetic_lock) 与 时间抑制 (key_suppress)

local config = require("config")
local M = {}

-- ==========================================
-- 1. 内部状态 (整合原 lock 与 suppress 的私有数据)
-- ==========================================
M.SYNTHETIC_USER_DATA = 999
local _lockCount = 0            -- 对应原 synthetic_lock._count
local _suppressUntil = {}       -- 对应原 key_suppress._until
local _trackedKeys = {}         -- 记录脚本按下的键，防止回环

local function now() return hs.timer.secondsSinceEpoch() end

-- ==========================================
-- 2. 锁逻辑 (原 synthetic_lock 功能)
-- ==========================================
function M.acquire()
    _lockCount = _lockCount + 1
    _G.__KSP_synthetic = true -- 保留原全局标记兼容性
end

function M.release()
    if _lockCount == 0 then
        if config.debug then print("input_io: release called with count=0") end
        return
    end
    _lockCount = _lockCount - 1
    if _lockCount == 0 then
        _G.__KSP_synthetic = false
    end
end

function M.isLocked()
    return _lockCount > 0
end

-- ==========================================
-- 3. 抑制逻辑 (原 key_suppress 功能)
-- ==========================================
function M.suppress(key, duration)
    if not key then return end
    _suppressUntil[key] = now() + (duration or config.syntheticSuppressWindow or 0.05)
end

function M.isSuppressed(key)
    if not key then return false end
    local t = _suppressUntil[key]
    if not t then return false end
    if now() >= t then
        _suppressUntil[key] = nil
        return false
    end
    return true
end

-- ==========================================
-- 4. 判定逻辑 (供 input_handler 调用)
-- ==========================================
-- 这是一个高度整合的判定函数，只要满足以下任一条件，即判定为脚本合成事件
function M.isSyntheticEvent(ev)
    if not ev then return false end

    -- A. 检查 UserData 烙印 (最快、最准)
    if ev:getProperty(hs.eventtap.event.properties.eventSourceUserData) == M.SYNTHETIC_USER_DATA then
        return true
    end

    -- B. 检查引用计数锁状态
    if M.isLocked() then return true end

    -- C. 检查当前键是否在追踪名单或抑制期内
    local code = ev:getKeyCode()
    local char = hs.keycodes.charactersForCode(code)
    if char and (M.isSuppressed(char) or _trackedKeys[code]) then
        return true
    end

    return false
end

-- ==========================================
-- 5. 执行逻辑 (整合后的统一发送口)
-- ==========================================
local function post(val, isDown)
    local app = hs.application.frontmostApplication()
    if not config.isGame(app) then return end

    -- A. 自动化上锁
    M.acquire()

    -- B. 构造并发送事件
    local ev = hs.eventtap.event.newKeyEvent({}, val, isDown)
    ev:setProperty(hs.eventtap.event.properties.keyboardEventAutorepeat, 0)
    ev:setProperty(hs.eventtap.event.properties.eventSourceUserData, M.SYNTHETIC_USER_DATA)
    
    -- C. 状态追踪
    local code = hs.keycodes.map[val]
    if code then _trackedKeys[code] = isDown and true or nil end
    
    -- D. 自动抑制 (仅在按下时触发)
    if isDown then M.suppress(val) end

    ev:post(app)

    -- E. 延时解锁 (给系统 50ms 处理时间，防止瞬间解锁导致的拦截误伤)
    hs.timer.doAfter(0.05, function()
        M.release()
    end)
end

-- 公开 API
function M.sendKeyDown(key) post(key, true) end
function M.sendKeyUp(key) post(key, false) end
function M.sendKeyPress(key, duration, callback)
    M.sendKeyDown(key)
    hs.timer.doAfter(duration or 0.05, function()
        M.sendKeyUp(key)
        if callback then callback() end
    end)
end

return M