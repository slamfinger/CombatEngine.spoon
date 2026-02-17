--- combat_engine.lua
local lock = require("synthetic_lock")
local suppress = require("key_suppress")
local config = require("config")

local CombatEngine = {}
CombatEngine.__index = CombatEngine

function CombatEngine.new(skills, fullConfig)
    local instance = setmetatable({}, CombatEngine)
    instance.name = (fullConfig and fullConfig.name) or "极速异步引擎"

    skills = skills or {}
    -- 1. 自动填充回落键 (Primary Key)
    local pCfg = fullConfig and ((fullConfig.config and fullConfig.config.primary) or fullConfig.primary or fullConfig)
    if #skills < 5 then
        if pCfg and pCfg.key then
            table.insert(skills, { key = pCfg.key, cd = 0, duration = 0, isPrimary = true })
        else
            table.insert(skills, { key = "space", cd = 0, duration = 0, isPrimary = true })
        end
    end

    instance.skills = skills
    instance.state = {
        running = false,
        nextReadyAt = {},
        activeKey = nil,
        activeIdx = nil,
        actionUntil = 0,
        lastHighPrioAt = 0,
        minInterval = 0.3,
        currentRandomInterval = 0.3,
        primaryResumeAt = 0,
        isBusy = false,
        mainTimer = nil,
        pendingTimer = nil,
        pendingKey = nil
    }

    local now = hs.timer.secondsSinceEpoch()
    for i = 1, #instance.skills do instance.state.nextReadyAt[i] = now end
    return instance
end

function CombatEngine:isRunning()
    return self.state and self.state.running
end

--- 1. 底层按键执行 (协调层)

function CombatEngine:_postRawKey(key, isDown)
    if not self.state.running then return end
    hs.eventtap.event.newKeyEvent({}, key, isDown):post()
end

function CombatEngine:_physicalPress(key, duration, callback)
    if not self.state.running then return end
    
    self:_postRawKey(key, true)
    self.state.pendingKey = key
    local delay = (duration and duration > 0) and duration or 0.05
    
    self.state.pendingTimer = hs.timer.doAfter(delay, function()
        if not self.state or not self.state.running then 
            self.state.pendingTimer = nil
            return 
        end
        
        self.state.pendingTimer = nil
        self.state.pendingKey = nil
        self:_postRawKey(key, false)
        
        if callback then callback() end
    end)
end

--- 2. 核心战斗逻辑

function CombatEngine:_onTick()
    if not self.state.running then return end
    if self.state.isBusy then
        self:_scheduleNext(hs.timer.secondsSinceEpoch())
        return
    end
    
    local now = hs.timer.secondsSinceEpoch()

    -- 3. 扫描 1-4 优先级技能
    local targetIdx = nil
    for i = 1, 4 do
        if self.skills[i] and now >= self.state.nextReadyAt[i] then
            if (now - self.state.lastHighPrioAt) >= self.state.currentRandomInterval then
                targetIdx = i
                break
            end
        end
    end

    -- 4. 动作执行流
    if targetIdx then
        if self.state.activeIdx ~= targetIdx then
            self.state.isBusy = true
            
            if self.state.activeKey then 
                self:_postRawKey(self.state.activeKey, false) 
                self.state.activeKey = nil
            end
            
            local s = self.skills[targetIdx]
            self.state.lastHighPrioAt = now
            self.state.currentRandomInterval = self.state.minInterval + (math.random(0, 100) / 1000)
            self.state.nextReadyAt[targetIdx] = now + (s.cd or 0)
            
            if (s.duration or 0) > 0 then
                -- 持续施法
                self.state.activeKey = s.key
                self.state.activeIdx = targetIdx
                self.state.actionUntil = now + s.duration
                self:_postRawKey(s.key, true)
                self.state.isBusy = false 
            else
                -- 瞬发
                self.state.activeIdx = targetIdx
                self:_physicalPress(s.key, 0.05, function()
                    self.state.activeKey = nil
                    self.state.activeIdx = nil
                    self.state.actionUntil = 0 
                    self.state.isBusy = false
                    self.state.primaryResumeAt = hs.timer.secondsSinceEpoch() + (math.random(0, 150) / 1000)
                    self:_onTick() 
                end)
            end
        end
    else
        -- 5. 5号位逻辑优化
        local now = hs.timer.secondsSinceEpoch()
        local isActionDone = (self.state.activeIdx and self.state.activeIdx <= 4 and now >= self.state.actionUntil)
        local isNothingActive = (not self.state.activeIdx)

        if isActionDone or isNothingActive then
            if isActionDone and self.state.activeKey then
                self:_postRawKey(self.state.activeKey, false)
                self.state.activeKey = nil
                self.state.activeIdx = nil
                self.state.primaryResumeAt = now + (math.random(0, 150) / 1000)
            end

            if self.state.activeIdx ~= 5 and now >= self.state.primaryResumeAt then
                local ps = self.skills[5]
                if ps then
                    self.state.activeKey = ps.key
                    self.state.activeIdx = 5
                    self.state.actionUntil = 0 
                    self:_postRawKey(ps.key, true)
                end
            end
        end
    end

    self:_scheduleNext(now)
end

--- 3. 启停控制 (状态同步核心)

function CombatEngine:_resetInternalState()
    local now = hs.timer.secondsSinceEpoch()
    
    if self.state.pendingTimer then
        self.state.pendingTimer:stop()
        self.state.pendingTimer = nil
    end
    self.state.pendingKey = nil

    self.state.activeKey = nil
    self.state.activeIdx = nil
    self.state.actionUntil = 0
    self.state.lastHighPrioAt = now - 10
    self.state.currentRandomInterval = 0
    self.state.isBusy = false
    self.state.primaryResumeAt = 0
    
    for i = 1, #self.skills do 
        self.state.nextReadyAt[i] = now 
    end
end

function CombatEngine:start()
    if self.state.running then self:stop() end
    
    self:_resetInternalState()
    lock.acquire()
    self.state.running = true
    if not self.state._rngSeeded then
        math.randomseed(os.time())
        self.state._rngSeeded = true
    end
    
    self:_scheduleNext(hs.timer.secondsSinceEpoch())
end

function CombatEngine:_scheduleNext(now)
    if not self.state.running then return end
    if self.state.mainTimer then
        self.state.mainTimer:stop()
        self.state.mainTimer = nil
    end

    local target = self:_computeNextTime(now)
    local delay = target - now
    if delay < 0.005 then delay = 0.005 end
    if delay > 0.03 then delay = 0.03 end

    self.state.mainTimer = hs.timer.doAfter(delay, function() self:_onTick() end)
end

function CombatEngine:_computeNextTime(now)
    local earliest = now + 0.02
    local earliestHigh = nil

    for i = 1, 4 do
        local s = self.skills[i]
        if s then
            local t = self.state.nextReadyAt[i] or now
            local intervalAt = (self.state.lastHighPrioAt or 0) + (self.state.currentRandomInterval or 0.3)
            if t < intervalAt then t = intervalAt end
            if not earliestHigh or t < earliestHigh then earliestHigh = t end
        end
    end

    if earliestHigh and earliestHigh < earliest then
        earliest = earliestHigh
    end

    if self.state.activeIdx and self.state.activeIdx <= 4 and self.state.actionUntil and self.state.actionUntil > now then
        if self.state.actionUntil < earliest then earliest = self.state.actionUntil end
    end

    if self.state.activeIdx ~= 5 and self.state.primaryResumeAt and self.state.primaryResumeAt > now then
        if self.state.primaryResumeAt < earliest then earliest = self.state.primaryResumeAt end
    end

    return earliest
end

function CombatEngine:stop()
    self.state.running = false
    
    if self.state.mainTimer then 
        self.state.mainTimer:stop() 
        self.state.mainTimer = nil 
    end
    
    if self.state.activeKey then 
        hs.eventtap.event.newKeyEvent({}, self.state.activeKey, false):post() 
    end
    
    if self.state.pendingTimer then
        self.state.pendingTimer:stop()
        self.state.pendingTimer = nil
    end
    if self.state.pendingKey then
        hs.eventtap.event.newKeyEvent({}, self.state.pendingKey, false):post()
        suppress.suppress(self.state.pendingKey, config.syntheticSuppressWindow or 0.05)
        self.state.pendingKey = nil
    end

    lock.release()
    self:_resetInternalState()
end

return CombatEngine
