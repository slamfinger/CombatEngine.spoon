local config = require("config")

local M = {}
M.__index = M

function M.new(mouseCenterer)
    local self = setmetatable({}, M)
    self.mouseCenterer = mouseCenterer
    self.config = {
        bundleID = config.gameBundleID,
        relX = 0.10566, 
        relY = 0.81941, 
        radius = 105,           
        cursorSpeed = 0.6,      
    }
    
    self.active = false
    self.virtualOffset = {x = 0, y = 0}
    self.ignoreCount = 0
    self.startPos = {x = 0, y = 0}
    
    self._cachedJoystickCenter = {x = 0, y = 0}
    self._cachedScreenCenter = {x = 0, y = 0}
    
    self.vCursor = hs.canvas.new({x=0, y=0, w=19, h=19})
    self.vCursor[1] = {
        type = "segments",
        coordinates = {
            {x = 1.0,  y = 0}, {x = 0.3,  y = 13.5}, {x = 4.0,  y = 11.0},
            {x = 6.2,  y = 16.5}, {x = 9.0,  y = 15.0}, {x = 6.5,  y = 10.2},
            {x = 11.3, y = 9.7}, {x = 1.0,  y = 0}
        },
        fillColor = {black = 1, alpha = 0.85},
        strokeColor = {white = 1, alpha = 1},
        strokeWidth = 1,
        action = "strokeAndFill"
    }

    self.tap = hs.eventtap.new({
        hs.eventtap.event.types.rightMouseDown,
        hs.eventtap.event.types.rightMouseUp,
        hs.eventtap.event.types.rightMouseDragged 
    }, function(event)
        if event:getProperty(hs.eventtap.event.properties.eventSourceUserData) == 999 then
            return false 
        end

        local type = event:getType()
        
        if type == hs.eventtap.event.types.rightMouseDown then
            local frontApp = hs.application.frontmostApplication()
            -- Note: We still use the bundleID from self.config initialized from shared config
            if not frontApp or frontApp:bundleID() ~= self.config.bundleID then return false end
            
            local win = frontApp:mainWindow()
            if not win then return false end
            
            local f = win:frame()
            local mousePos = hs.mouse.absolutePosition()

            if mousePos.x < f.x or mousePos.x > (f.x + f.w) or 
               mousePos.y < f.y or mousePos.y > (f.y + f.h) then
                return false 
            end

            self.active = true
            self._cachedScreenCenter = { x = f.x + f.w / 2, y = f.y + f.h / 2 }
            self._cachedJoystickCenter = { 
                x = math.floor(f.x + f.w * self.config.relX), 
                y = math.floor(f.y + f.h * self.config.relY) 
            }
            
            self.startPos = mousePos
            self.virtualOffset = {
                x = self.startPos.x - self._cachedScreenCenter.x,
                y = self.startPos.y - self._cachedScreenCenter.y
            }
            
            self.ignoreCount = 3 
            
            if self.mouseCenterer and self.mouseCenterer.suspend then self.mouseCenterer:suspend() end
            self.vCursor:topLeft({x = self.startPos.x - 1, y = self.startPos.y - 1}):show()
            
            hs.mouse.absolutePosition(self._cachedJoystickCenter)
            self:_postClick(hs.eventtap.event.types.leftMouseDown, self._cachedJoystickCenter)
            
            return true

        elseif not self.active then
            return false
        end

        if type == hs.eventtap.event.types.rightMouseDragged then
            local dx = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaX)
            local dy = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaY)

            if self.ignoreCount > 0 then self.ignoreCount = self.ignoreCount - 1; return true end

            self.virtualOffset.x = self.virtualOffset.x + (dx * self.config.cursorSpeed)
            self.virtualOffset.y = self.virtualOffset.y + (dy * self.config.cursorSpeed)
            
            local dist = math.sqrt(self.virtualOffset.x^2 + self.virtualOffset.y^2)
            local rawAngle = math.atan2(self.virtualOffset.y, self.virtualOffset.x)
            
            local ratio = dist > 5 and 1.0 or 0.0
            
            local targetX = math.floor(self._cachedJoystickCenter.x + math.cos(rawAngle) * self.config.radius * ratio)
            local targetY = math.floor(self._cachedJoystickCenter.y + math.sin(rawAngle) * self.config.radius * ratio)
            
            self.vCursor:topLeft({
                x = self._cachedScreenCenter.x + self.virtualOffset.x - 1,
                y = self._cachedScreenCenter.y + self.virtualOffset.y - 1
            })

            hs.mouse.absolutePosition({x = targetX, y = targetY})
            self:_postClick(hs.eventtap.event.types.leftMouseDragged, {x = targetX, y = targetY})
            return true

        elseif type == hs.eventtap.event.types.rightMouseUp then
            self.active = false
            self:_postClick(hs.eventtap.event.types.leftMouseUp, hs.mouse.absolutePosition())
            self.vCursor:hide()
            
            hs.mouse.absolutePosition({
                x = math.floor(self._cachedScreenCenter.x + self.virtualOffset.x),
                y = math.floor(self._cachedScreenCenter.y + self.virtualOffset.y)
            })
            
            if self.mouseCenterer and self.mouseCenterer.resume then self.mouseCenterer:resume() end
            return true
        end
        
        return false
    end)
    return self
end

function M:_postClick(etype, pos)
    local evt = hs.eventtap.event.newMouseEvent(etype, pos)
    evt:setProperty(hs.eventtap.event.properties.eventSourceUserData, 999)
    evt:post()
end

function M:press(pos)
    self:_postClick(hs.eventtap.event.types.leftMouseDown, pos)
end

function M:drag(pos)
    self:_postClick(hs.eventtap.event.types.leftMouseDragged, pos)
end

function M:release(pos)
    self:_postClick(hs.eventtap.event.types.leftMouseUp, pos)
end

function M:centerNow()
    if self.active then return end
    local frontApp = hs.application.frontmostApplication()
    if frontApp and frontApp:bundleID() == config.gameBundleID then
        local win = frontApp:mainWindow()
        if win then
            local f = win:frame()
            hs.mouse.absolutePosition({ x = f.x + f.w/2, y = f.y + f.h/2 })
        end
    end
end

function M:start() self.tap:start(); return self end

function M:stop() 
    if self.active then
        self:release(hs.mouse.absolutePosition())
        hs.mouse.absolutePosition({
            x = math.floor(self._cachedScreenCenter.x + self.virtualOffset.x),
            y = math.floor(self._cachedScreenCenter.y + self.virtualOffset.y)
        })
    end
    self.active = false
    self.vCursor:hide()
    self.tap:stop() 
    return self 
end

function M:destroy()
    self:stop()
    if self.vCursor then
        self.vCursor:delete()
        self.vCursor = nil
    end
    return self
end

return M
