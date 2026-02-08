--[[
    Arcan1ST Antarctica Script - Reyna Edition
    Version: 2.1.0-Reyna
    Fixed & Improved
]]--

--[[ CONFIGURATION ]] --
local Config = {
    Version = "2.1.0-Reyna",
    Debug = false,
    
    Hydration = {
        Enabled = true,
        Threshold = 50,
        TargetLevel = 99
    },
    
    AutoComplete = {
        TeleportDelay = 0.5,
        JumpInterval = 0.5,
        RespawnDelay = 3
    },
    
    AntiCheat = {
        SpoofSpeed = true,
        SpoofJump = true,
        DefaultSpeed = 16,
        DefaultJump = 50
    }
}

--[[ LOAD WINDUI (Stable Version) ]] --
local WindUI = loadstring(game:HttpGet('https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/main.client.lua'))()

--[[ TEMA REYNA (Eye of Reyna Style) ]] --
local ReynaTheme = {
    Name = "Reyna",
    Accent = Color3.fromRGB(160, 32, 240), -- Ungu Neon Reyna
    Outline = Color3.fromRGB(80, 0, 120),
    Text = Color3.fromRGB(240, 230, 255),
    PlaceholderText = Color3.fromRGB(150, 130, 180),
    Background = Color3.fromRGB(15, 10, 25), -- Hitam Kebiruan Gelap
    Item = Color3.fromRGB(25, 20, 35),
    ItemOutline = Color3.fromRGB(50, 30, 70),
}
WindUI:AddTheme(ReynaTheme)

--[[ MODULE: AntarcticaHub ]] --
local AntarcticaHub = {}
AntarcticaHub.__index = AntarcticaHub

--[[ SERVICE CACHE ]] --
AntarcticaHub.Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(game.GetService, game, serviceName)
        if success then
            rawset(self, serviceName, service)
            return service
        end
        return nil
    end
})

--[[ TELEPORT DATA ]] --
AntarcticaHub.Locations = {
    Checkpoints = {
        {Name = "BASE", Position = Vector3.new(-6016.00, -159.00, -28.57)},
        {Name = "CAMP1", Position = Vector3.new(-3720.19, 225.00, 235.91)},
        {Name = "CAMP2", Position = Vector3.new(1790.79, 105.45, -136.89)},
        {Name = "CAMP3", Position = Vector3.new(5891.24, 321.00, -18.60)},
        {Name = "CAMP4", Position = Vector3.new(8992.07, 595.59, 103.63)},
        {Name = "SOUTHPOLE", Position = Vector3.new(10993.19, 549.13, 100.13)}
    },
    
    FillBottle = {
        BASE = Vector3.new(-6042.84, -158.95, -59.00),
        CAMP1 = Vector3.new(-3718.06, 228.94, 261.38),
        CAMP2 = Vector3.new(1799.14, 105.37, -161.86),
        CAMP3 = Vector3.new(5885.90, 321.00, 4.62),
        CAMP4 = Vector3.new(9000.03, 597.40, 88.02)
    },
    
    CampNames = {
        BASE = "BaseCamp",
        CAMP1 = "Camp1",
        CAMP2 = "Camp2",
        CAMP3 = "Camp3",
        CAMP4 = "Camp4"
    }
}

--[[ STATE MANAGEMENT ]] --
AntarcticaHub.State = {
    currentCheckpoint = 1,
    isAutoTeleporting = false,
    isAutoJumping = false,
    isAutoHydrationEnabled = true,
    validatedPositions = {},
    cachedPlayer = nil,
    cachedCharacter = nil,
    cachedHumanoid = nil,
    cachedRootPart = nil
}

--[[ UI ELEMENTS STORAGE ]] --
AntarcticaHub.UI = {
    HydrationToggle = nil,
    AutoCompleteButton = nil,
    Window = nil,
}

--[[ UTILITY MODULE ]] --
AntarcticaHub.Utils = {}

function AntarcticaHub.Utils.log(message, level)
    level = level or "INFO"
    if Config.Debug or level == "ERROR" then
        print(string.format("[Arcan1ST][%s] %s", level, message))
    end
end

function AntarcticaHub.Utils.safeCall(func, ...)
    local args = {...}
    local success, result = pcall(function()
        return func(table.unpack(args))
    end)
    if not success then
        AntarcticaHub.Utils.log(tostring(result), "ERROR")
        return nil
    end
    return result
end

function AntarcticaHub.Utils.notify(title, text, duration)
    WindUI:Notify({
        Title = title or "Arcan1STHub",
        Content = text,
        Duration = duration or 3,
        Icon = "eye",
    })
end

function AntarcticaHub.Utils.createPosKey(position)
    return string.format("%d,%d,%d", 
        math.floor(position.X), 
        math.floor(position.Y), 
        math.floor(position.Z)
    )
end

--[[ PLAYER MODULE ]] --
AntarcticaHub.Player = {}

function AntarcticaHub.Player.get()
    if not AntarcticaHub.State.cachedPlayer then
        AntarcticaHub.State.cachedPlayer = AntarcticaHub.Services.Players.LocalPlayer
    end
    return AntarcticaHub.State.cachedPlayer
end

function AntarcticaHub.Player.getCharacter()
    local player = AntarcticaHub.Player.get()
    if not player then return nil end
    
    if not AntarcticaHub.State.cachedCharacter or not AntarcticaHub.State.cachedCharacter.Parent then
        AntarcticaHub.State.cachedCharacter = player.Character
    end
    return AntarcticaHub.State.cachedCharacter
end

function AntarcticaHub.Player.getHumanoid()
    if AntarcticaHub.State.cachedHumanoid and AntarcticaHub.State.cachedHumanoid.Parent then
        return AntarcticaHub.State.cachedHumanoid
    end
    
    local character = AntarcticaHub.Player.getCharacter()
    if character then
        AntarcticaHub.State.cachedHumanoid = character:FindFirstChild("Humanoid")
    end
    return AntarcticaHub.State.cachedHumanoid
end

function AntarcticaHub.Player.getRootPart()
    if AntarcticaHub.State.cachedRootPart and AntarcticaHub.State.cachedRootPart.Parent then
        return AntarcticaHub.State.cachedRootPart
    end
    
    local character = AntarcticaHub.Player.getCharacter()
    if character then
        AntarcticaHub.State.cachedRootPart = character:FindFirstChild("HumanoidRootPart")
    end
    return AntarcticaHub.State.cachedRootPart
end

function AntarcticaHub.Player.clearCache()
    AntarcticaHub.State.cachedCharacter = nil
    AntarcticaHub.State.cachedHumanoid = nil
    AntarcticaHub.State.cachedRootPart = nil
end

function AntarcticaHub.Player.respawn()
    local humanoid = AntarcticaHub.Player.getHumanoid()
    if humanoid then
        humanoid.Health = 0
    end
end

function AntarcticaHub.Player.getAttribute(attributeName)
    local player = AntarcticaHub.Player.get()
    if player then
        return player:GetAttribute(attributeName)
    end
    return nil
end

--[[ ANTI-CHEAT BYPASS MODULE ]] --
AntarcticaHub.AntiCheat = {}

function AntarcticaHub.AntiCheat.setupValueSpoof()
    if not Config.AntiCheat.SpoofSpeed and not Config.AntiCheat.SpoofJump then
        return
    end
    
    local success = pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        
        setreadonly(mt, false)
        
        mt.__index = newcclosure(function(self, key)
            if checkcaller and not checkcaller() then
                if self:IsA("Humanoid") then
                    if Config.AntiCheat.SpoofSpeed and key == "WalkSpeed" then
                        return Config.AntiCheat.DefaultSpeed
                    elseif Config.AntiCheat.SpoofJump and key == "JumpPower" then
                        return Config.AntiCheat.DefaultJump
                    end
                end
            end
            return oldIndex(self, key)
        end)
        
        setreadonly(mt, true)
        AntarcticaHub.Utils.log("Value spoofing enabled", "INFO")
    end)
    
    if not success then
        AntarcticaHub.Utils.log("Failed to setup value spoof", "ERROR")
    end
end

function AntarcticaHub.AntiCheat.setupKickProtection()
    local success = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall
        
        setreadonly(mt, false)
        
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            
            if method == "Kick" then
                AntarcticaHub.Utils.log("Kick attempt blocked", "INFO")
                return nil
            end
            
            return oldNamecall(self, ...)
        end))
        
        setreadonly(mt, true)
        AntarcticaHub.Utils.log("Kick protection enabled", "INFO")
    end)
    
    if not success then
        AntarcticaHub.Utils.log("Failed to setup kick protection", "ERROR")
    end
end

function AntarcticaHub.AntiCheat.setupFallDamageProtection()
    local player = AntarcticaHub.Player.get()
    if not player then return end
    
    local function protectCharacter(character)
        if not character then return end
        
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then return end
        
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)
        
        character.ChildAdded:Connect(function(child)
            if child:IsA("Script") then
                local name = child.Name:lower()
                if name:find("fall") or name:find("damage") or name:find("freeze") or name:find("water") then
                    task.wait(0.1)
                    child:Destroy()
                end
            end
        end)
    end
    
    if player.Character then
        protectCharacter(player.Character)
    end
    
    player.CharacterAdded:Connect(function(character)
        task.wait(1)
        protectCharacter(character)
        AntarcticaHub.Player.clearCache()
    end)
end

--[[ MOVEMENT MODULE ]] --
AntarcticaHub.Movement = {}

function AntarcticaHub.Movement.ensureCanMove()
    local humanoid = AntarcticaHub.Player.getHumanoid()
    local rootPart = AntarcticaHub.Player.getRootPart()
    
    if not humanoid or not rootPart then return end
    
    rootPart.Anchored = false
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
    
    local states = {
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.GettingUp
    }
    
    for _, state in ipairs(states) do
        humanoid:SetStateEnabled(state, true)
    end
    
    rootPart.Velocity = Vector3.zero
    rootPart.RotVelocity = Vector3.zero
end

function AntarcticaHub.Movement.waitForTerrain(position, timeout)
    timeout = timeout or 5
    local startTime = tick()
    
    while tick() - startTime < timeout do
        local ray = Ray.new(position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))
        local hit = workspace:FindPartOnRay(ray)
        
        if hit then
            return true
        end
        
        task.wait(0.1)
    end
    
    return false
end

function AntarcticaHub.Movement.teleportTo(position)
    local rootPart = AntarcticaHub.Player.getRootPart()
    if not rootPart then return false end
    
    local posKey = AntarcticaHub.Utils.createPosKey(position)
    
    rootPart.Velocity = Vector3.zero
    rootPart.RotVelocity = Vector3.zero
    
    if not AntarcticaHub.State.validatedPositions[posKey] then
        rootPart.Anchored = true
        
        local safeHeight = 10
        local initialPos = position + Vector3.new(0, safeHeight, 0)
        rootPart.CFrame = CFrame.new(initialPos)
        
        local terrainLoaded = AntarcticaHub.Movement.waitForTerrain(position, 5)
        
        if terrainLoaded then
            AntarcticaHub.State.validatedPositions[posKey] = true
        end
    end
    
    local finalPosition = position + Vector3.new(0, 5, 0)
    rootPart.CFrame = CFrame.new(finalPosition)
    
    task.wait(0.2)
    AntarcticaHub.Movement.ensureCanMove()
    
    return true
end

function AntarcticaHub.Movement.findNearestCheckpoint()
    local rootPart = AntarcticaHub.Player.getRootPart()
    if not rootPart then return 1 end
    
    local currentPos = rootPart.Position
    local nearestDist = math.huge
    local nearestIndex = 1
    
    for i = 2, #AntarcticaHub.Locations.Checkpoints do
        local checkpoint = AntarcticaHub.Locations.Checkpoints[i]
        local dist = (currentPos - checkpoint.Position).Magnitude
        
        if dist < nearestDist then
            nearestDist = dist
            nearestIndex = i
        end
    end
    
    return nearestIndex
end

--[[ AUTO JUMP MODULE ]] --
AntarcticaHub.AutoJump = {}

function AntarcticaHub.AutoJump.start()
    if AntarcticaHub.State.isAutoJumping then return end
    AntarcticaHub.State.isAutoJumping = true
    
    task.spawn(function()
        while AntarcticaHub.State.isAutoJumping do
            local humanoid = AntarcticaHub.Player.getHumanoid()
            if humanoid then
                humanoid.Jump = true
            end
            task.wait(Config.AutoComplete.JumpInterval)
        end
    end)
end

function AntarcticaHub.AutoJump.stop()
    AntarcticaHub.State.isAutoJumping = false
end

--[[ AUTO COMPLETE MODULE ]] --
AntarcticaHub.AutoComplete = {}

function AntarcticaHub.AutoComplete.start()
    if AntarcticaHub.State.isAutoTeleporting then return end
    
    AntarcticaHub.State.currentCheckpoint = AntarcticaHub.Movement.findNearestCheckpoint()
    AntarcticaHub.State.isAutoTeleporting = true
    AntarcticaHub.AutoJump.start()
    
    task.spawn(function()
        while AntarcticaHub.State.isAutoTeleporting do
            if AntarcticaHub.State.currentCheckpoint <= #AntarcticaHub.Locations.Checkpoints then
                local checkpoint = AntarcticaHub.Locations.Checkpoints[AntarcticaHub.State.currentCheckpoint]
                AntarcticaHub.Movement.teleportTo(checkpoint.Position)
                task.wait(Config.AutoComplete.TeleportDelay)
            else
                task.wait(1)
                AntarcticaHub.Player.respawn()
                task.wait(Config.AutoComplete.RespawnDelay)
                
                if AntarcticaHub.State.isAutoTeleporting then
                    AntarcticaHub.State.currentCheckpoint = 2
                    local checkpoint = AntarcticaHub.Locations.Checkpoints[AntarcticaHub.State.currentCheckpoint]
                    AntarcticaHub.Movement.teleportTo(checkpoint.Position)
                    AntarcticaHub.Utils.notify("Arcan1STHub", "Restarting from CAMP1! 🔄", 3)
                end
                break
            end
        end
    end)
end

function AntarcticaHub.AutoComplete.stop()
    AntarcticaHub.State.isAutoTeleporting = false
    AntarcticaHub.AutoJump.stop()
    AntarcticaHub.Movement.ensureCanMove()
    
    local rootPart = AntarcticaHub.Player.getRootPart()
    if rootPart then
        local currentPos = rootPart.Position
        local groundPos = currentPos - Vector3.new(0, 3, 0)
        rootPart.CFrame = CFrame.new(groundPos)
    end
end

function AntarcticaHub.AutoComplete.onCheckpointReached(message)
    if not AntarcticaHub.State.isAutoTeleporting then return end
    
    if message:find("You have made it to South Pole") then
        AntarcticaHub.Utils.notify("Arcan1STHub", "South Pole Reached! 🎯", 2)
        
        task.wait(1)
        AntarcticaHub.Player.respawn()
        task.wait(Config.AutoComplete.RespawnDelay)
        
        if AntarcticaHub.State.isAutoTeleporting then
            AntarcticaHub.State.currentCheckpoint = 2
            local checkpoint = AntarcticaHub.Locations.Checkpoints[AntarcticaHub.State.currentCheckpoint]
            AntarcticaHub.Movement.teleportTo(checkpoint.Position)
            AntarcticaHub.Utils.notify("Arcan1STHub", "Restarting from CAMP1! 🔄", 3)
        else
            AntarcticaHub.Utils.notify("Arcan1STHub", "Journey Completed! 🎉", 3)
        end
        
        AntarcticaHub.State.isAutoJumping = AntarcticaHub.State.isAutoTeleporting
        
    elseif message:find("You have made it to Camp") then
        AntarcticaHub.Utils.notify("Arcan1STHub", "Checkpoint Completed! ⭐", 2)
        
        AntarcticaHub.State.currentCheckpoint = AntarcticaHub.State.currentCheckpoint + 1
        if AntarcticaHub.State.currentCheckpoint <= #AntarcticaHub.Locations.Checkpoints then
            task.wait(Config.AutoComplete.TeleportDelay)
            local checkpoint = AntarcticaHub.Locations.Checkpoints[AntarcticaHub.State.currentCheckpoint]
            AntarcticaHub.Movement.teleportTo(checkpoint.Position)
        end
    end
end

--[[ HYDRATION MODULE ]] --
AntarcticaHub.Hydration = {}

function AntarcticaHub.Hydration.getNearestCamp()
    local rootPart = AntarcticaHub.Player.getRootPart()
    if not rootPart then return "BASE" end
    
    local currentPos = rootPart.Position
    
    local southPolePos = AntarcticaHub.Locations.Checkpoints[6].Position
    if (currentPos - southPolePos).Magnitude < 500 then
        return nil
    end
    
    local closestCamp = "BASE"
    local shortestDist = math.huge
    
    for name, position in pairs(AntarcticaHub.Locations.FillBottle) do
        local dist = (currentPos - position).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            closestCamp = name
        end
    end
    
    return closestCamp
end

function AntarcticaHub.Hydration.tryDrink()
    local character = AntarcticaHub.Player.getCharacter()
    if not character then return false end
    
    local waterBottle = character:FindFirstChild("Water Bottle")
    if waterBottle and waterBottle:FindFirstChild("RemoteEvent") then
        waterBottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

function AntarcticaHub.Hydration.fillBottle(campName)
    local wasJumping = AntarcticaHub.State.isAutoJumping
    AntarcticaHub.State.isAutoJumping = false
    
    local properCampName = AntarcticaHub.Locations.CampNames[campName] or campName
    local fillLocation = AntarcticaHub.Locations.FillBottle[campName]
    
    if not fillLocation then return false end
    
    local character = AntarcticaHub.Player.getCharacter()
    local player = AntarcticaHub.Player.get()
    
    if not character or not player then
        AntarcticaHub.State.isAutoJumping = wasJumping
        return false
    end
    
    local backpack = player:FindFirstChild("Backpack")
    local waterBottle = character:FindFirstChild("Water Bottle") or (backpack and backpack:FindFirstChild("Water Bottle"))
    
    if not waterBottle or not waterBottle:IsA("Tool") then
        warn("Water Bottle not found")
        AntarcticaHub.State.isAutoJumping = wasJumping
        return false
    end
    
    if waterBottle.Parent == backpack then
        local humanoid = AntarcticaHub.Player.getHumanoid()
        if humanoid then
            humanoid:EquipTool(waterBottle)
            task.wait(0.3)
        end
    end
    
    AntarcticaHub.Movement.teleportTo(fillLocation)
    task.wait(0.3)
    
    local args = {"FillBottle", properCampName, "Water"}
    local events = AntarcticaHub.Services.ReplicatedStorage:FindFirstChild("Events")
    if events then
        local energyHydration = events:FindFirstChild("EnergyHydration")
        if energyHydration then
            energyHydration:FireServer(unpack(args))
        end
    end
    
    task.wait(0.5)
    
    local checkpointPos = nil
    for _, checkpoint in ipairs(AntarcticaHub.Locations.Checkpoints) do
        if checkpoint.Name == campName then
            checkpointPos = checkpoint.Position
            break
        end
    end
    
    if checkpointPos then
        AntarcticaHub.Movement.teleportTo(checkpointPos)
    end
    
    AntarcticaHub.State.isAutoJumping = wasJumping
    if wasJumping then
        AntarcticaHub.AutoJump.start()
    end
    
    return true
end

function AntarcticaHub.Hydration.monitor()
    local lastCheck = 0
    local CHECK_INTERVAL = 0.5
    
    AntarcticaHub.Services.RunService.Heartbeat:Connect(function()
        if not AntarcticaHub.State.isAutoHydrationEnabled then return end
        
        local now = tick()
        if now - lastCheck < CHECK_INTERVAL then return end
        lastCheck = now
        
        local hydration = AntarcticaHub.Player.getAttribute("Hydration")
        if not hydration or hydration >= Config.Hydration.TargetLevel then return end
        
        if hydration < Config.Hydration.Threshold then
            local beforeDrink = hydration
            AntarcticaHub.Hydration.tryDrink()
            
            task.wait(0.3)
            
            local afterDrink = AntarcticaHub.Player.getAttribute("Hydration")
            
            if afterDrink and afterDrink > beforeDrink then
                while true do
                    local current = AntarcticaHub.Player.getAttribute("Hydration")
                    if not current or current >= Config.Hydration.TargetLevel then break end
                    
                    local success = AntarcticaHub.Hydration.tryDrink()
                    task.wait(0.3)
                    
                    local newLevel = AntarcticaHub.Player.getAttribute("Hydration")
                    if not success or not newLevel or newLevel <= current then
                        local camp = AntarcticaHub.Hydration.getNearestCamp()
                        if camp then
                            AntarcticaHub.Hydration.fillBottle(camp)
                        end
                        break
                    end
                    
                    task.wait(0.2)
                end
            else
                local camp = AntarcticaHub.Hydration.getNearestCamp()
                if camp then
                    AntarcticaHub.Hydration.fillBottle(camp)
                    task.wait(0.3)
                    
                    while true do
                        local current = AntarcticaHub.Player.getAttribute("Hydration")
                        if not current or current >= Config.Hydration.TargetLevel then break end
                        
                        AntarcticaHub.Hydration.tryDrink()
                        task.wait(0.3)
                        
                        local newLevel = AntarcticaHub.Player.getAttribute("Hydration")
                        if not newLevel or newLevel <= current then break end
                        
                        task.wait(0.2)
                    end
                end
            end
        end
    end)
end

--[[ WINDUI GUI MODULE ]] --
AntarcticaHub.GUI = {}

function AntarcticaHub.GUI.create()
    -- Create Window
    local Window = WindUI:CreateWindow({
        Title = "Arcan1ST Hub",
        Subtitle = "Eye of Reyna Edition",
        Icon = "rbxassetid://6031075931",
        Author = "by Arcan1ST",
        Folder = "Arcan1STAntarctica",
        Size = UDim2.fromOffset(550, 420),
        Theme = "Reyna",
        Transparent = true,
        Resizable = true,
        SideBarWidth = 170,
        HasOutline = true,
    })
    
    AntarcticaHub.UI.Window = Window
    
    -- Create Tabs
    local MainTab = Window:Tab({
        Title = "Main",
        Icon = "home",
    })
    
    local TeleportsTab = Window:Tab({
        Title = "Teleports",
        Icon = "map-pin",
    })
    
    local SettingsTab = Window:Tab({
        Title = "Settings",
        Icon = "settings",
    })
    
    --[[ MAIN TAB ]] --
    
    -- Status Section
    local StatusSection = MainTab:Section({
        Title = "Status",
        Icon = "activity",
    })
    
    StatusSection:Paragraph({
        Title = "Welcome Agent",
        Desc = "Use Eye of Reyna's power to dominate Antarctica. Toggle features below to automate your journey or control manually.",
        Icon = "eye",
    })
    
    -- Automation Section
    local AutoSection = MainTab:Section({
        Title = "Automation",
        Icon = "zap",
    })
    
    AntarcticaHub.UI.AutoCompleteButton = AutoSection:Button({
        Title = "Start Auto Complete",
        Desc = "Automatically complete the entire journey",
        Icon = "play",
        Callback = function()
            if AntarcticaHub.State.isAutoTeleporting then
                AntarcticaHub.AutoComplete.stop()
                AntarcticaHub.UI.AutoCompleteButton:SetTitle("Start Auto Complete")
                AntarcticaHub.Utils.notify("Auto Complete", "Stopped ⏹", 2)
            else
                AntarcticaHub.AutoComplete.start()
                AntarcticaHub.UI.AutoCompleteButton:SetTitle("Stop Auto Complete")
                AntarcticaHub.Utils.notify("Auto Complete", "Started! 🚀", 2)
            end
        end
    })
    
    AntarcticaHub.UI.HydrationToggle = AutoSection:Toggle({
        Title = "Auto Hydration",
        Desc = "Automatically drink and refill water",
        Icon = "droplet",
        Value = Config.Hydration.Enabled,
        Callback = function(state)
            AntarcticaHub.State.isAutoHydrationEnabled = state
            local statusText = state and "Enabled ✓" or "Disabled ✗"
            AntarcticaHub.Utils.notify("Auto Hydration", statusText, 2)
        end
    })
    
    -- Manual Section
    local ManualSection = MainTab:Section({
        Title = "Manual Controls",
        Icon = "hand",
    })
    
    ManualSection:Button({
        Title = "Drink Water",
        Desc = "Manually drink from bottle",
        Icon = "coffee",
        Callback = function()
            local success = AntarcticaHub.Hydration.tryDrink()
            if success then
                AntarcticaHub.Utils.notify("Hydration", "Drinking... 💧", 1.5)
            else
                AntarcticaHub.Utils.notify("Hydration", "No water bottle!", 2)
            end
        end
    })
    
    ManualSection:Button({
        Title = "Fill Water Bottle",
        Desc = "Refill at nearest camp",
        Icon = "glass-water",
        Callback = function()
            local camp = AntarcticaHub.Hydration.getNearestCamp()
            if camp then
                AntarcticaHub.Hydration.fillBottle(camp)
                AntarcticaHub.Utils.notify("Hydration", "Refilling at " .. camp, 2)
            else
                AntarcticaHub.Utils.notify("Hydration", "No camp nearby!", 2)
            end
        end
    })
    
    ManualSection:Button({
        Title = "Respawn Character",
        Desc = "Respawn instantly",
        Icon = "refresh-cw",
        Callback = function()
            AntarcticaHub.Player.respawn()
            AntarcticaHub.Utils.notify("Player", "Respawning...", 2)
        end
    })
    
    --[[ TELEPORTS TAB ]] --
    
    local CheckpointsSection = TeleportsTab:Section({
        Title = "Game Checkpoints",
        Icon = "flag",
    })
    
    local icons = {
        "home", "tent-tree", "mountain", "mountain-snow", "flag-triangle-right", "target"
    }
    
    local descriptions = {
        "Base Camp - Starting point",
        "Camp 1 - First checkpoint",
        "Camp 2 - Second checkpoint",
        "Camp 3 - Third checkpoint",
        "Camp 4 - Fourth checkpoint",
        "South Pole - Final destination"
    }
    
    for i, checkpoint in ipairs(AntarcticaHub.Locations.Checkpoints) do
        CheckpointsSection:Button({
            Title = checkpoint.Name,
            Desc = descriptions[i],
            Icon = icons[i] or "map",
            Callback = function()
                AntarcticaHub.Movement.teleportTo(checkpoint.Position)
                AntarcticaHub.Utils.notify("Teleport", "→ " .. checkpoint.Name, 2)
            end
        })
    end
    
    --[[ SETTINGS TAB ]] --
    
    local TimingSection = SettingsTab:Section({
        Title = "Timing Configuration",
        Icon = "clock",
    })
    
    TimingSection:Slider({
        Title = "Teleport Delay",
        Desc = "Delay between teleports",
        Step = 0.1,
        Value = {
            Min = 0.1,
            Max = 3.0,
            Default = Config.AutoComplete.TeleportDelay,
        },
        Callback = function(value)
            Config.AutoComplete.TeleportDelay = value
        end
    })
    
    TimingSection:Slider({
        Title = "Jump Interval",
        Desc = "Time between jumps",
        Step = 0.1,
        Value = {
            Min = 0.1,
            Max = 2.0,
            Default = Config.AutoComplete.JumpInterval,
        },
        Callback = function(value)
            Config.AutoComplete.JumpInterval = value
        end
    })
    
    TimingSection:Slider({
        Title = "Respawn Delay",
        Desc = "Wait time after respawn",
        Step = 0.5,
        Value = {
            Min = 1.0,
            Max = 10.0,
            Default = Config.AutoComplete.RespawnDelay,
        },
        Callback = function(value)
            Config.AutoComplete.RespawnDelay = value
        end
    })
    
    local HydrationSection = SettingsTab:Section({
        Title = "Hydration Settings",
        Icon = "droplet",
    })
    
    HydrationSection:Slider({
        Title = "Hydration Threshold",
        Desc = "Trigger auto-drink below this",
        Step = 1,
        Value = {
            Min = 10,
            Max = 90,
            Default = Config.Hydration.Threshold,
        },
        Callback = function(value)
            Config.Hydration.Threshold = value
        end
    })
    
    HydrationSection:Slider({
        Title = "Hydration Target",
        Desc = "Stop drinking at this level",
        Step = 1,
        Value = {
            Min = 50,
            Max = 99,
            Default = Config.Hydration.TargetLevel,
        },
        Callback = function(value)
            Config.Hydration.TargetLevel = value
        end
    })
    
    local ProtectionSection = SettingsTab:Section({
        Title = "Protection",
        Icon = "shield",
    })
    
    ProtectionSection:Toggle({
        Title = "Speed Spoof",
        Desc = "Hide modified walk speed",
        Icon = "gauge",
        Value = Config.AntiCheat.SpoofSpeed,
        Callback = function(state)
            Config.AntiCheat.SpoofSpeed = state
        end
    })
    
    ProtectionSection:Toggle({
        Title = "Jump Spoof",
        Desc = "Hide modified jump power",
        Icon = "arrow-up",
        Value = Config.AntiCheat.SpoofJump,
        Callback = function(state)
            Config.AntiCheat.SpoofJump = state
        end
    })
    
    ProtectionSection:Toggle({
        Title = "Debug Mode",
        Desc = "Show console messages (F9)",
        Icon = "bug",
        Value = Config.Debug,
        Callback = function(state)
            Config.Debug = state
        end
    })
    
    local InfoSection = SettingsTab:Section({
        Title = "Information",
        Icon = "info",
    })
    
    InfoSection:Paragraph({
        Title = "Eye of Reyna Edition",
        Desc = "Antarctica automation script with Reyna-themed UI. Features auto-completion, intelligent hydration, teleports, and anti-cheat protection.",
        Icon = "eye",
    })
    
    InfoSection:Button({
        Title = "Reload Script",
        Desc = "Restart the script",
        Icon = "rotate-cw",
        Callback = function()
            AntarcticaHub.AutoComplete.stop()
            AntarcticaHub.Utils.notify("System", "Reloading...", 2)
            task.wait(1)
            AntarcticaHub:Init()
        end
    })
    
    -- Toggle Key Setup with Keybind
    SettingsTab:Keybind({
        Title = "Toggle UI Key",
        Desc = "Hotkey to open/close menu",
        Value = Enum.KeyCode.RightControl,
        Callback = function(key)
            -- WindUI handles this natively
        end
    })
    
    return Window
end

--[[ INITIALIZATION ]] --
function AntarcticaHub:Init()
    self.Utils.log("Initializing Arcan1ST Antarctica Hub - Reyna Edition v" .. Config.Version)
    
    -- Setup anti-cheat
    self.AntiCheat.setupValueSpoof()
    self.AntiCheat.setupKickProtection()
    self.AntiCheat.setupFallDamageProtection()
    
    -- Setup message listener
    local replicatedStorage = self.Services.ReplicatedStorage
    local messageRemote = replicatedStorage:FindFirstChild("Message_Remote")
    
    if messageRemote then
        messageRemote.OnClientEvent:Connect(function(message)
            if typeof(message) == "string" then
                self.AutoComplete.onCheckpointReached(message)
            end
        end)
    end
    
    -- Setup character respawn
    local player = self.Player.get()
    if player then
        player.CharacterAdded:Connect(function(character)
            task.wait(1)
            self.Player.clearCache()
            self.Movement.ensureCanMove()
        end)
    end
    
    -- Start monitors
    self.Hydration.monitor()
    
    -- Create GUI
    self.GUI.create()
    
    self.Utils.log("Initialization complete")
    
    -- Welcome notification
    WindUI:Notify({
        Title = "Welcome Agent",
        Content = "Eye of Reyna Edition loaded successfully!\nPress Right Ctrl to toggle UI.",
        Icon = "eye",
        Duration = 5
    })
end

-- Initialize the hub
AntarcticaHub:Init()

return AntarcticaHub
