--- input_handler.lua
local config = require("config")
local appUtils = require("app_utils")
local playerManager = require("player_manager")
local lock = require("synthetic_lock")
local suppress = require("key_suppress")

local M = {
    tapState = {},
    -- 核心映射表，确保 InputHandler 与 Manager 步调一致
    digitKeys = { ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4 },
    digitKeyCodes = {
        [hs.keycodes.map["1"]] = 1,
        [hs.keycodes.map["2"]] = 2,
        [hs.keycodes.map["3"]] = 3,
        [hs.keycodes.map["4"]] = 4
    },
    idxToChar = { [1] = "1", [2] = "2", [3] = "3", [4] = "4" },
    eventTap = nil,
    escTap = nil,
    appWatcher = nil
}

function M.start()
    M.stop()
    -- 1. 核心事件监听 (拦截、判定意图)
    M.eventTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(e)
        local keyCode = e:getKeyCode()
        local idx = M.digitKeyCodes[keyCode]
        local char = idx and M.idxToChar[idx] or nil
        
        local etype = e:getType()
        local now = hs.timer.secondsSinceEpoch()
        local tapWindow = config.doubleTapWindow or 0.35
        
        -- 【过滤层】合成键不拦截、非目标键不拦截、非游戏环境不拦截
        if lock.isLocked() or not idx or not appUtils.isFrontmostgame() then return false end
        if suppress.isSuppressed(char, now) then return true end
        if etype == hs.eventtap.event.types.keyDown and
           e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1 then
            return true
        end
        
        M.tapState[idx] = M.tapState[idx] or { lastTap = 0, timer = nil }
        local state = M.tapState[idx]

        -- A. 处理物理抬起 (KeyUp)
        if etype == hs.eventtap.event.types.keyUp then
            -- 脚本运行时放行所有物理抬起，由 CombatEngine 控制逻辑
            if playerManager.isAnyRunning() then return false end
            return false
        end

        -- B. 处理物理按下 (KeyDown)
        
        -- 【场景 A：脚本正在运行】
        if playerManager.isAnyRunning() then
            -- 运行中检测到双击 -> 执行切换或停止
            if now - state.lastTap <= tapWindow then
                state.lastTap = 0
                if state.timer then state.timer:stop(); state.timer = nil end
                playerManager.toggle(idx, char, true)
                return true 
            end
            
            -- 运行中检测到单击 -> 判定为“手动抢占”
            state.lastTap = now
            playerManager.interruptAndPassThrough(char, M.digitKeys)
            return false -- 放行物理按下信号，让用户瞬间接管操作
        end

        -- 【场景 B：脚本未运行】
        -- 用于判定双击启动（不拦截单击）
        if now - state.lastTap <= tapWindow then
            if state.timer then state.timer:stop(); state.timer = nil end
            state.lastTap = 0
            playerManager.toggle(idx, char, true)
            return true
        end

        -- 初次按下：进入等待判定窗口，但放行物理按下
        state.lastTap = now
        if state.timer then state.timer:stop() end
        state.timer = hs.timer.doAfter(tapWindow, function()
            state.timer = nil
            state.lastTap = 0
        end)

        return false
    end):start()

    -- 2. Esc 键逻辑 (紧急打断)
    M.escTap = hs.eventtap.new({ hs.eventtap.event.types.keyUp }, function(e)
        if e:getKeyCode() ~= hs.keycodes.map["escape"] then return false end
        
        if appUtils.isFrontmostgame() and playerManager.isAnyRunning() then
            playerManager.stopAll("Esc手动取消")
            if hs.alert then hs.alert.show("已停止运行") end
            return true
        end
        return false
    end):start()

    -- 3. 应用切换监听 (系统级生命周期管理)
    M.appWatcher = hs.application.watcher.new(function(appName, eventType, app)
        if eventType == hs.application.watcher.activated then
            if appUtils.isgame(app) then
                playerManager.activateSystem()
            else
                playerManager.deactivateSystem("应用失焦")
            end
        elseif (eventType == hs.application.watcher.deactivated or 
                eventType == hs.application.watcher.terminated) and appUtils.isgame(app) then
            playerManager.deactivateSystem("游戏关闭/切出")
        end
    end):start()

    -- 初始状态同步
    if appUtils.isFrontmostgame() then
        playerManager.activateSystem()
    end
end

function M.stop()
    if M.eventTap then M.eventTap:stop(); M.eventTap = nil end
    if M.escTap then M.escTap:stop(); M.escTap = nil end
    if M.appWatcher then M.appWatcher:stop(); M.appWatcher = nil end

    for _, state in pairs(M.tapState) do
        if state.timer then state.timer:stop() end
    end
    M.tapState = {}
end

return M
