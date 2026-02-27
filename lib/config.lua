-- Spoons/CombatEngine.spoon/lib/config.lua
-- 整合版：保留所有原始数据字段 + 原 app_utils 逻辑

local M = {}

-- ==========================================
-- 1. 原始 config 数据字段 (完全保留)
-- ==========================================
M.debug = false
M.gameBundleID = "com.netease.immortal"
M.gameBundleIDs = { "com.netease.immortal" ,"com.netease.mumu.nemux-global.emulator" }
M.gameProcessNames = {}
M.doubleTapWindow = 0.35
M.syntheticDelay = 30000 
M.syntheticSuppressWindow = 0.05 

-- ==========================================
-- 2. 整合原 app_utils 的环境检测逻辑 (完全保留逻辑)
-- ==========================================

-- 原 isgame 函数 (保留逻辑一致性)
function M.isGame(app)
    if not app then return false end
    local bid = app:bundleID()
    local name = app:name()
    
    -- 优先检查 gameBundleIDs 列表
    if M.gameBundleIDs and type(M.gameBundleIDs) == "table" then
        for _, id in ipairs(M.gameBundleIDs) do
            if bid == id then return true end
        end
        
        -- 检查进程名列表
        if M.gameProcessNames and type(M.gameProcessNames) == "table" and name then
            for _, pname in ipairs(M.gameProcessNames) do
                if name == pname then return true end
            end
        end
        
        -- 调试信息输出
        if M.debug then
            print("[Config] App not matched: " .. (name or "unknown") .. " (" .. (bid or "no bundleID") .. ")")
        end
        
        -- 如果列表存在但不匹配，则返回 false
        return false
    end
    
    -- 回退到单个 gameBundleID 匹配
    return bid == M.gameBundleID
end

-- 原 isFrontmostgame 函数
function M.isFrontmostGame()
    return M.isGame(hs.application.frontmostApplication())
end

-- 补充：便捷的 Alert 提示
function M.alert(msg)
    hs.alert.show(msg, 0.5)
end

return M
