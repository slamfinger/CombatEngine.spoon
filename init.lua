--- === CombatEngine ===
---
--- Combat automation engine for Hammerspoon.
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "CombatEngine"
obj.version = "1.3"
obj.author = "Antigravity"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT"

-- Default schemes
obj.schemes = {
    {
        name = "猎魔人",
        data = {
            { key = "1", cd = 9.0,  duration = 0 },
            { key = "2", cd = 9.0,  duration = 0 },
            { key = "3", cd = 20.0, duration = 0},
            { key = "4", cd = 20, duration = 10}, 
        },
        config = { primary = { key = "space"} }
    },
    {
        name = "死灵",
        data = {
            { key = "1", cd = 9.0,  duration = 0 },
            { key = "2", cd = 9.0,  duration = 0 },
            { key = "3", cd = 10,  duration = 0}, 
            { key = "4", cd = 2.0, duration = 0 }, 
        },
        config = { primary = { key = "space" } }
    },
    {
        name = "野蛮人",
        data = {
            { key = "1", cd = 12,  duration = 0 },
            { key = "2", cd = 12,  duration = 0 },
            { key = "3", cd = 9, duration = 0 },
            { key = "4", cd = 20.0, duration = 10 },
        },
        config = { primary = { key = "space" } }
    }
}

function obj:init()
    -- Set up internal library path
    local script_path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    package.path = script_path .. "lib/?.lua;" .. package.path
    
    -- Load internal configuration
    self.config = require("config")
    
    -- Load internal modules
    self.playerManager = require("player_manager")
    self.inputHandler = require("input_handler")
    
    return self
end

--- CombatEngine:start(schemes)
--- Method
--- Starts the combat engine with the provided schemes or defaults.
---
--- Parameters:
---  * schemes - (Optional) A table containing player configuration schemes. Defaults to self.schemes.
function obj:start(schemes)
    local activeSchemes = schemes or self.schemes
    if activeSchemes then
        self.playerManager.initPlayers(activeSchemes)
    end
    self.inputHandler.start()
    
    if self.config.debug then
        print("-------------------------------------------")
        print("CombatEngine Spoon 已启动")
        print("当前方案数：" .. (activeSchemes and #activeSchemes or "未指定"))
        print("-------------------------------------------")
    end
    
    return self
end

--- CombatEngine:stop()
--- Method
--- Stops the combat engine and cleans up listeners.
function obj:stop()
    self.inputHandler.stop()
    self.playerManager.stopAll("CombatEngine Stopped")
    return self
end

return obj
