--[[
    Arcan1ST Antarctica Script
    Version: 2.0.0
    Improved Architecture & Performance
]]--

--[[ CONFIGURATION ]] --
local Config = {
    Version = "2.0.0",
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
    AntarcticaHub.Utils.safeCall(function()
        AntarcticaHub.Services.StarterGui:SetCore("SendNotification", {
            Title = title or "Arcan1STHub",
            Text = text,
            Duration = duration or 3
        })
    end)
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
        
        -- Disable damage states
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        
        -- Health protection
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)
        
        -- Remove damage scripts
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
    
    -- Protect current and future characters
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
    
    -- Reset states
    rootPart.Anchored = false
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
    
    -- Enable movement states
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
    
    -- Reset velocities
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
    
    -- Reset velocities
    rootPart.Velocity = Vector3.zero
    rootPart.RotVelocity = Vector3.zero
    
    -- Check if position is validated
    if not AntarcticaHub.State.validatedPositions[posKey] then
        rootPart.Anchored = true
        
        -- Initial teleport above target
        local safeHeight = 10
        local initialPos = position + Vector3.new(0, safeHeight, 0)
        rootPart.CFrame = CFrame.new(initialPos)
        
        -- Wait for terrain
        local terrainLoaded = AntarcticaHub.Movement.waitForTerrain(position, 5)
        
        if terrainLoaded then
            AntarcticaHub.State.validatedPositions[posKey] = true
        end
    end
    
    -- Final teleport
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
    
    for i = 2, #AntarcticaHub.Locations.Checkpoints do -- Skip BASE
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
                -- Reached end
                task.wait(1)
                AntarcticaHub.Player.respawn()
                task.wait(Config.AutoComplete.RespawnDelay)
                
                if AntarcticaHub.State.isAutoTeleporting then
                    AntarcticaHub.State.currentCheckpoint = 2 -- Start from CAMP1
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
    
    -- Ensure character is on ground
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
    
    -- Check if near South Pole
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
    
    -- Equip bottle if needed
    if waterBottle.Parent == backpack then
        local humanoid = AntarcticaHub.Player.getHumanoid()
        if humanoid then
            humanoid:EquipTool(waterBottle)
            task.wait(0.3)
        end
    end
    
    -- Teleport and fill
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
    
    -- Return to checkpoint
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
                -- Keep drinking
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
                -- Need refill
                local camp = AntarcticaHub.Hydration.getNearestCamp()
                if camp then
                    AntarcticaHub.Hydration.fillBottle(camp)
                    task.wait(0.3)
                    
                    -- Drink after refill
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

--[[ GUI MODULE ]] --
AntarcticaHub.GUI = {}

function AntarcticaHub.GUI.create()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Arcan1ST-Antarctica"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = game.CoreGui
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 200, 0, 0)
    MainFrame.Position = UDim2.new(0, 50, 0.4, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.AutomaticSize = Enum.AutomaticSize.Y
    MainFrame.Parent = ScreenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = MainFrame
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -60, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Arcan1STHub v" .. Config.Version
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    -- Minimize Button
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    MinimizeBtn.Position = UDim2.new(1, -55, 0, 2.5)
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
    MinimizeBtn.Font = Enum.Font.SourceSansBold
    MinimizeBtn.TextSize = 18
    MinimizeBtn.BorderSizePixel = 0
    MinimizeBtn.Parent = TitleBar
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = MinimizeBtn
    
    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 25, 0, 25)
    CloseBtn.Position = UDim2.new(1, -28, 0, 2.5)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.TextSize = 16
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseBtn
    
    -- Button Container
    local ButtonHolder = Instance.new("Frame")
    ButtonHolder.Size = UDim2.new(1, -20, 0, 0)
    ButtonHolder.Position = UDim2.new(0, 10, 0, 40)
    ButtonHolder.BackgroundTransparency = 1
    ButtonHolder.AutomaticSize = Enum.AutomaticSize.Y
    ButtonHolder.Parent = MainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = ButtonHolder
    
    -- Create Buttons
    local function createButton(text, color, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = color
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = order
        btn.Parent = ButtonHolder
        
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 10)
        padding.Parent = btn
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        
        return btn
    end
    
    -- Auto Hydration Button
    local HydrationBtn = createButton("💧 Auto Hydration: ON", Color3.fromRGB(60, 180, 75), 1)
    
    -- Auto Complete Button
    local AutoCompleteBtn = createButton("🎯 Auto Complete", Color3.fromRGB(60, 180, 75), 2)
    
    -- Teleport Buttons
    local teleportButtons = {}
    for i, checkpoint in ipairs(AntarcticaHub.Locations.Checkpoints) do
        local btn = createButton("📍 " .. checkpoint.Name, Color3.fromRGB(60, 120, 200), i + 2)
        btn.MouseButton1Click:Connect(function()
            AntarcticaHub.Movement.teleportTo(checkpoint.Position)
        end)
        table.insert(teleportButtons, btn)
    end
    
    -- Watermark
    local Watermark = Instance.new("TextLabel")
    Watermark.Size = UDim2.new(1, 0, 0, 25)
    Watermark.Position = UDim2.new(0, 0, 1, -25)
    Watermark.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Watermark.Text = "by Arcan1ST ⭐"
    Watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
    Watermark.Font = Enum.Font.SourceSansBold
    Watermark.TextSize = 12
    Watermark.BorderSizePixel = 0
    Watermark.Parent = MainFrame
    
    local waterCorner = Instance.new("UICorner")
    waterCorner.CornerRadius = UDim.new(0, 8)
    waterCorner.Parent = Watermark
    
    -- Minimized Frame
    local MinimizedFrame = Instance.new("Frame")
    MinimizedFrame.Size = UDim2.new(0, 140, 0, 35)
    MinimizedFrame.Position = UDim2.new(0, 50, 0.4, 0)
    MinimizedFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    MinimizedFrame.BorderSizePixel = 0
    MinimizedFrame.Active = true
    MinimizedFrame.Visible = false
    MinimizedFrame.Parent = ScreenGui
    
    local minFrameCorner = Instance.new("UICorner")
    minFrameCorner.CornerRadius = UDim.new(0, 8)
    minFrameCorner.Parent = MinimizedFrame
    
    local MinimizedLabel = Instance.new("TextButton")
    MinimizedLabel.Size = UDim2.new(1, 0, 1, 0)
    MinimizedLabel.BackgroundTransparency = 1
    MinimizedLabel.Text = "🎯 Arcan1ST"
    MinimizedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizedLabel.Font = Enum.Font.SourceSansBold
    MinimizedLabel.TextSize = 16
    MinimizedLabel.Parent = MinimizedFrame
    
    -- Button Events
    HydrationBtn.MouseButton1Click:Connect(function()
        AntarcticaHub.State.isAutoHydrationEnabled = not AntarcticaHub.State.isAutoHydrationEnabled
        HydrationBtn.Text = string.format("💧 Auto Hydration: %s", 
            AntarcticaHub.State.isAutoHydrationEnabled and "ON" or "OFF")
        HydrationBtn.BackgroundColor3 = AntarcticaHub.State.isAutoHydrationEnabled and 
            Color3.fromRGB(60, 180, 75) or Color3.fromRGB(180, 60, 60)
    end)
    
    AutoCompleteBtn.MouseButton1Click:Connect(function()
        if AntarcticaHub.State.isAutoTeleporting then
            AntarcticaHub.AutoComplete.stop()
            AutoCompleteBtn.Text = "🎯 Auto Complete"
            AutoCompleteBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
            AntarcticaHub.Utils.notify("Auto Complete", "Stopped ⏹", 2)
        else
            AntarcticaHub.AutoComplete.start()
            AutoCompleteBtn.Text = "⏹ Stop Auto Complete"
            AutoCompleteBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        AntarcticaHub.AutoComplete.stop()
        ScreenGui:Destroy()
    end)
    
    MinimizeBtn.MouseButton1Click:Connect(function()
        local currentPos = MainFrame.Position
        MinimizedFrame.Position = currentPos
        MainFrame.Visible = false
        MinimizedFrame.Visible = true
    end)
    
    MinimizedLabel.MouseButton1Click:Connect(function()
        local currentPos = MinimizedFrame.Position
        MainFrame.Position = currentPos
        MainFrame.Visible = true
        MinimizedFrame.Visible = false
    end)
    
    -- Dragging for MinimizedFrame
    local UserInputService = AntarcticaHub.Services.UserInputService
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    MinimizedFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MinimizedFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    MinimizedFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MinimizedFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return ScreenGui
end

--[[ INITIALIZATION ]] --
function AntarcticaHub:Init()
    self.Utils.log("Initializing Arcan1ST Antarctica Hub v" .. Config.Version)
    
    -- Setup anti-cheat bypasses
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
    
    -- Setup character respawn handler
    local player = self.Player.get()
    if player then
        player.CharacterAdded:Connect(function(character)
            task.wait(1)
            self.Player.clearCache()
            self.Movement.ensureCanMove()
        end)
    end
    
    -- Start hydration monitor
    self.Hydration.monitor()
    
    -- Create GUI
    self.GUI.create()
    
    self.Utils.log("Initialization complete")
    self.Utils.notify("Arcan1STHub", "Loaded successfully! v" .. Config.Version, 3)
end

-- Initialize the hub
AntarcticaHub:Init()

return AntarcticaHub
