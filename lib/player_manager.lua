-- Spoons/CombatEngine.spoon/lib/player_manager.lua

-- 【修改】：引用新模块，移除旧的 synthetic_lock
local CombatEngine = require("combat_engine")
local inputIO = require("input_io")
local config = require("config")

local M = {
    players = {},
    joystick = nil,
    _isSwitching = false -- 内部私有锁：防止切换期间的重复触发
}

-- [私有工具] 发送合成按键并管理全局变量锁 (逻辑与原 sendSyntheticKey 完全一致)
local function sendSyntheticKey(char, isDown, resetDelay)
    -- 【修改】：使用 inputIO 接管锁的获取
    inputIO.acquire()
    
    -- 【修改】：通过 inputIO 发送按键，确保带上 999 标签，并记录追踪状态
    if isDown then
        inputIO.sendKeyDown(char)
    else
        inputIO.sendKeyUp(char)
    end
    
    if resetDelay then
        hs.timer.doAfter(resetDelay, function()
            -- 【修改】：使用 inputIO 释放锁
            inputIO.release()
        end)
    else
        inputIO.release()
    end
end

-- 激活系统 (通常由 AppWatcher 调用)
function M.activateSystem()
    if M.joystick then M.joystick:start() end
    -- 【修改】：确保锁处于干净状态 (清除所有引用计数)
    while inputIO.isLocked() do inputIO.release() end
end

-- 停用系统 (应用切换、切屏、游戏关闭时调用)
function M.deactivateSystem(reason)
    M.stopAll(reason or "系统失焦")
    if M.joystick then M.joystick:stop() end
end

-- 停止所有正在运行的脚本
function M.stopAll(reason)
    for _, p in pairs(M.players) do 
        if p and p:isRunning() then 
            p:stop(reason) 
        end 
    end
    -- 【修改】：强制重置全局锁，直到 isLocked 为 false
    while inputIO.isLocked() do inputIO.release() end
    M._isSwitching = false
end

-- 处理“手动抢占”逻辑
function M.interruptAndPassThrough(char, digitKeys)
    -- 【修改】：上锁
    inputIO.acquire()
    
    -- 1. 瞬间释放所有受管辖的按键
    for keyChar, _ in pairs(digitKeys) do
        -- 【修改】：走 inputIO 的发送逻辑，确保不被 input_handler 再次拦截
        inputIO.sendKeyUp(keyChar)
    end
    
    -- 2. 5ms 极速解锁
    hs.timer.doAfter(0.005, function() 
        inputIO.release()
    end)
end

-- 统一的 Toggle (启动/停止/切换) 逻辑
function M.toggle(index, char, isHotkey)
    if M._isSwitching then return end
    
    local p = M.players[index]
    if not p then return end
    
    if p:isRunning() then
        -- 停止逻辑
        M.stopAll("手动停止")
        if hs.alert then hs.alert.show("已停止: " .. (p.name or index)) end
    else
        -- 启动逻辑
        M._isSwitching = true
        M.stopAll("切换")
        
        -- 发送一个合成 Up 确保环境干净
        sendSyntheticKey(char, false, 0.01)

        -- 给予 15ms 的物理缓冲
        hs.timer.doAfter(0.015, function()
            if M.players[index] then
                M.players[index]:start({ triggeredByHotkey = isHotkey })
                if hs.alert then hs.alert.show("启动: " .. (p.name or index)) end
                
                if M.joystick and M.joystick.centerNow then
                    M.joystick:centerNow()
                end
            end
            M._isSwitching = false
        end)
    end
end

-- 执行“单击补偿”
function M.executeSingleTap(char)
    if M.isAnyRunning() then return end
    
    sendSyntheticKey(char, true)
    hs.timer.doAfter((config.syntheticDelay or 30000) / 1000000, function()
        sendSyntheticKey(char, false, 0.02)
    end)
end

function M.isAnyRunning()
    for _, p in pairs(M.players) do 
        if p and p:isRunning() then return true end 
    end
    return false
end

-- 强制重置系统
function M.forceReset()
    M.stopAll("强制重置")
    -- 【修改】：彻底解锁
    while inputIO.isLocked() do inputIO.release() end
    M._isSwitching = false
    if hs.alert then hs.alert.show("⚠️ 系统状态已重置") end
end

-- 模块重载逻辑
function M.reloadModules()
    package.loaded["joystickTap"] = nil
    local ok, JoystickClass = pcall(require, "joystickTap")
    if not ok then
        print("警告: 无法加载 joystickTap 模块")
        return
    end
    
    if M.joystick then 
        pcall(function()
            if M.joystick.destroy then
                M.joystick:destroy()
            else
                M.joystick:stop()
            end
        end)
    end
    M.joystick = JoystickClass.new(nil)
end

-- 初始化 Player 实例
function M.initPlayers(schemes)
    M.stopAll("Init Cleanup")
    package.loaded["combat_engine"] = nil
    local NewEngine = require("combat_engine")

    M.players = {}
    for i, item in ipairs(schemes) do
        item.id = i 
        M.players[i] = NewEngine.new(item.data, item)
    end
end

-- 初始化模块
pcall(M.reloadModules)

return M