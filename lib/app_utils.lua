-- lib/app_utils.lua
local config = require("config")
local M = {}

function M.isgame(app)
    if not app then return false end
    local bid = app:bundleID()
    local name = app:name()
    if config.gameBundleIDs and type(config.gameBundleIDs) == "table" then
        for _, id in ipairs(config.gameBundleIDs) do
            if bid == id then return true end
        end
        if config.gameProcessNames and type(config.gameProcessNames) == "table" and name then
            for _, pname in ipairs(config.gameProcessNames) do
                if name == pname then return true end
            end
        end
        if config.debug then
            print("App not matched: " .. (name or "unknown") .. " (" .. (bid or "no bundleID") .. ")")
        end
        return false
    end
    return bid == config.gameBundleID
end

function M.isFrontmostgame()
    return M.isgame(hs.application.frontmostApplication())
end

return M
