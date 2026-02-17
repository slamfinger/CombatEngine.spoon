-- Spoons/CombatEngine.spoon/lib/config.lua
local M = {}

-- 默认配置
M.debug = true
M.gameBundleID = "com.netease.immortal"
M.gameBundleIDs = { "com.netease.immortal" }
M.gameProcessNames = {}
M.doubleTapWindow = 0.35
M.syntheticDelay = 30000 -- 补发按键的微秒级延迟
M.syntheticSuppressWindow = 0.05 -- stop 补发 keyUp 后的抑制窗口(秒)

return M
