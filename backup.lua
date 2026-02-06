local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/RehanDias/UIR/refs/heads/main/test.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")

local SETTINGS = {
    FPS_BOOST_AUTO = false,
    TWEEN_SPEED = 0
}

if getgenv().Arcan1ST_Running then
    StarterGui:SetCore("SendNotification", {
        Title = "Arcan1ST", Text = "Script Already Running!", Duration = 3
    })
    return
end
getgenv().Arcan1ST_Running = true

local LocalPlayer = Players.LocalPlayer
local State = {
    AutoTeleport = false,
    AutoJump = false,
    AutoHydration = false,
    CurrentCheckpoint = 1,
    WaitingForConfirmation = false
}

local Waypoints = {
    ["BASE"] = Vector3.new(-6016.00, -159.00, -28.57),
    ["CAMP1"] = Vector3.new(-3720.19, 225.00, 235.91),
    ["CAMP2"] = Vector3.new(1790.79, 105.45, -136.89),
    ["CAMP3"] = Vector3.new(5891.24, 321.00, -18.60),
    ["CAMP4"] = Vector3.new(8992.07, 595.59, 103.63),
    ["SOUTHPOLE"] = Vector3.new(10993.19, 549.13, 100.13)
}

local BottlePoints = {
    ["BASE"] = Vector3.new(-6042.84, -158.95, -59.00),
    ["CAMP1"] = Vector3.new(-3718.06, 228.94, 261.38),
    ["CAMP2"] = Vector3.new(1799.14, 105.37, -161.86),
    ["CAMP3"] = Vector3.new(5885.90, 321.00, 4.62),
    ["CAMP4"] = Vector3.new(9000.03, 597.40, 88.02)
}

local CampMapping = {
    ["BASE"] = "BaseCamp", ["CAMP1"] = "Camp1", 
    ["CAMP2"] = "Camp2", ["CAMP3"] = "Camp3", ["CAMP4"] = "Camp4"
}
local CheckpointOrder = {"CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE"}

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local function Notify(title, text, dur)
    StarterGui:SetCore("SendNotification", {
        Title = title, Text = text, Duration = dur or 2
    })
end

local function SmartBoostFPS()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 2
    
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
            pcall(function() v.Enabled = false end)
        end
    end
    
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Parent:FindFirstChild("Humanoid") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
        elseif v:IsA("Texture") or v:IsA("Decal") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
            v.Enabled = false
        end
    end
    
    workspace.Terrain.WaterWaveSize = 0
    workspace.Terrain.WaterReflectance = 0
    workspace.Terrain.WaterTransparency = 0
    
    Notify("FPS Booster", "Safe Mode Activated 🚀")
end

local function EnsureCharacterCanMove()
    if not LocalPlayer or not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and rootPart then
        rootPart.Anchored = false
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        
        rootPart.Velocity = Vector3.new(0, 0, 0)
        rootPart.RotVelocity = Vector3.new(0, 0, 0)
    end
end

local function SafeTeleport(targetPos)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local root = char.HumanoidRootPart
    root.Velocity = Vector3.zero 
    root.AssemblyLinearVelocity = Vector3.zero
    
    LocalPlayer:RequestStreamAroundAsync(targetPos)
    
    local finalCFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))

    if SETTINGS.TWEEN_SPEED > 0 then
        local distance = (root.Position - targetPos).Magnitude
        local duration = distance / SETTINGS.TWEEN_SPEED
        local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(root, info, {CFrame = finalCFrame})
        tween:Play()
        task.wait(duration)
    else
        task.wait(0.5)
        root.CFrame = finalCFrame
    end
    
    task.wait(0.2)
    EnsureCharacterCanMove()
end

local function HookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
    hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Script") and (v.Name:find("Damage") or v.Name:find("Fall") or v.Name:find("freeze") or v.Name:find("Water")) then
            pcall(function() v.Disabled = true end)
        end
    end
    
    char.ChildAdded:Connect(function(child)
        if child:IsA("Script") then
            if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or child.Name:find("Water") then
                task.wait()
                child:Destroy()
            end
        end
    end)
    
    local lastHp = hum.Health
    hum.HealthChanged:Connect(function(hp)
        if hp < lastHp and hp > 0 then
            hum.Health = lastHp
        end
        lastHp = hp
    end)
end

local function GetNearestCamp()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return "BASE"
    end
    
    local pos = char.HumanoidRootPart.Position
    local southPolePos = Waypoints["SOUTHPOLE"]
    local distanceToSouthPole = (pos - southPolePos).Magnitude
    
    if distanceToSouthPole < 500 then
        return nil
    end
    
    local closestCamp = nil
    local shortestDistance = math.huge
    
    for campName, campPos in pairs(Waypoints) do
        if campName ~= "SOUTHPOLE" then
            local dist = (pos - campPos).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestCamp = campName
            end
        end
    end
    
    return closestCamp
end

local function TryDrink()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local waterBottle = character:FindFirstChild("Water Bottle")
    if waterBottle and waterBottle:FindFirstChild("RemoteEvent") then
        waterBottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

local function FillBottleAtCamp(campName)
    local wasAutoJumping = State.AutoJump
    local properCampName = CampMapping[campName] or campName
    local fillLocation = BottlePoints[campName]
    
    if fillLocation then
        State.AutoJump = false
        
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local waterBottle = character:FindFirstChild("Water Bottle") or backpack:FindFirstChild("Water Bottle")
        
        if waterBottle and waterBottle:IsA("Tool") then
            if waterBottle.Parent == backpack then
                local humanoid = character:WaitForChild("Humanoid")
                humanoid:EquipTool(waterBottle)
                task.wait(0.3)
            end
            
            SafeTeleport(fillLocation)
            task.wait(0.3)
            
            local args = {"FillBottle", properCampName, "Water"}
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("EnergyHydration"):FireServer(unpack(args))
            task.wait(0.5)
            
            if Waypoints[campName] then
                SafeTeleport(Waypoints[campName])
            end
        end
        
        State.AutoJump = wasAutoJumping
        if wasAutoJumping then
            task.spawn(function()
                while State.AutoJump do
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                        LocalPlayer.Character.Humanoid.Jump = true
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
end

task.spawn(function()
    RunService.RenderStepped:Connect(function()
        if not State.AutoHydration then return end
        
        local hydration = LocalPlayer:GetAttribute("Hydration")
        if hydration then
            if hydration >= 99 then return end
            
            if hydration < 50 then
                local beforeDrinkHydration = hydration
                TryDrink()
                task.wait(0.3)
                
                local afterDrinkHydration = LocalPlayer:GetAttribute("Hydration")
                local hydrationIncreased = afterDrinkHydration > beforeDrinkHydration
                
                if hydrationIncreased then
                    while LocalPlayer:GetAttribute("Hydration") < 99 do
                        local currentHydration = LocalPlayer:GetAttribute("Hydration")
                        local success = TryDrink()
                        task.wait(0.3)
                        local newHydration = LocalPlayer:GetAttribute("Hydration")
                        
                        if newHydration >= 99 then break end
                        
                        if not success or newHydration <= currentHydration then
                            local nearestCamp = GetNearestCamp()
                            if nearestCamp then
                                FillBottleAtCamp(nearestCamp)
                                task.wait(0.3)
                                TryDrink()
                            end
                            break
                        end
                        task.wait(0.2)
                    end
                else
                    local nearestCamp = GetNearestCamp()
                    if nearestCamp then
                        FillBottleAtCamp(nearestCamp)
                        task.wait(0.3)
                        while LocalPlayer:GetAttribute("Hydration") < 99 do
                            local currentHydration = LocalPlayer:GetAttribute("Hydration")
                            if currentHydration >= 99 then break end
                            
                            local success = TryDrink()
                            task.wait(0.3)
                            local newHydration = LocalPlayer:GetAttribute("Hydration")
                            if not success or newHydration <= currentHydration then break end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end)
end)

local function RespawnCharacter()
    local wasAutoTeleporting = State.AutoTeleport
    State.AutoTeleport = false
    State.AutoJump = false
    
    local args = {"Died"}
    ReplicatedStorage:WaitForChild("Events"):WaitForChild("CharacterHandler"):FireServer(unpack(args))
    
    local newCharacter = LocalPlayer.CharacterAdded:Wait()
    newCharacter:WaitForChild("Humanoid")
    newCharacter:WaitForChild("HumanoidRootPart")
    task.wait(1)
    
    HookCharacter(newCharacter)
    
    if wasAutoTeleporting then
        State.AutoTeleport = true
        State.AutoJump = true
        Notify("Auto Complete", "Resumed after respawn ▶️", 2)
    end
end

local function StartLoop()
    State.AutoTeleport = true
    State.AutoJump = true
    
    task.spawn(function()
        while State.AutoJump do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.Jump = true
            end
            task.wait(0.5)
        end
    end)
    
    task.spawn(function()
        while State.AutoTeleport do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
            end
            
            if State.CurrentCheckpoint <= #CheckpointOrder then
                local targetCamp = CheckpointOrder[State.CurrentCheckpoint]
                Notify("Progress", "Going to " .. targetCamp .. "...", 2)
                
                SafeTeleport(Waypoints[targetCamp])
                
                State.WaitingForConfirmation = true
                local timeout = 0
                while State.WaitingForConfirmation and State.AutoTeleport and timeout < 30 do
                    task.wait(1)
                    timeout = timeout + 1
                end
                
                if timeout >= 30 then
                    Notify("Warning", "Confirmation timeout, moving on...", 2)
                    State.CurrentCheckpoint = State.CurrentCheckpoint + 1
                    State.WaitingForConfirmation = false
                end
                
            else
                Notify("Winner", "South Pole Reached! Resetting...", 3)
                task.wait(1)
                RespawnCharacter()
                task.wait(3)
                
                if State.AutoTeleport then
                    State.CurrentCheckpoint = 1
                    LocalPlayer:RequestStreamAroundAsync(Waypoints["CAMP1"])
                    Notify("Loop", "Restarting from Camp 1...", 2)
                else
                    break
                end
            end
        end
    end)
end

if ReplicatedStorage:FindFirstChild("Message_Remote") then
    ReplicatedStorage.Message_Remote.OnClientEvent:Connect(function(msg)
        if not State.AutoTeleport then return end
        
        if string.find(msg, "made it to Camp") then
            State.WaitingForConfirmation = false
            State.CurrentCheckpoint = State.CurrentCheckpoint + 1
            Notify("Checkpoint", "Confirmed! Moving to next camp", 2)
        elseif string.find(msg, "South Pole") then
            State.WaitingForConfirmation = false
            State.CurrentCheckpoint = #CheckpointOrder + 1
            Notify("Victory", "South Pole Confirmed!", 2)
        end
    end)
end

local Window = Library:CreateWindow({
    Name = "ARCAN1ST HUB",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Arcan1ST",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("🏠 Main", nil)
local TeleportTab = Window:CreateTab("📍 Teleport", nil)

local MainSection = MainTab:CreateSection("Main Features")

MainTab:CreateButton({
    Name = "⚡ Boost FPS (Safe)",
    Callback = function()
        SmartBoostFPS()
    end
})

MainTab:CreateToggle({
    Name = "💧 Auto Hydration",
    CurrentValue = false,
    Flag = "AutoHydration",
    Callback = function(Value)
        State.AutoHydration = Value
        if Value then
            Notify("Auto Hydration", "Enabled", 2)
        else
            Notify("Auto Hydration", "Disabled", 2)
        end
    end
})

MainTab:CreateToggle({
    Name = "⚙️ Legit Mode (Tween)",
    CurrentValue = false,
    Flag = "LegitMode",
    Callback = function(Value)
        if Value then
            SETTINGS.TWEEN_SPEED = 500
            Notify("Mode", "Legit Mode (500 speed)", 2)
        else
            SETTINGS.TWEEN_SPEED = 0
            Notify("Mode", "Blatant Mode (Instant TP)", 2)
        end
    end
})

MainTab:CreateToggle({
    Name = "🚀 Auto Loop (Start)",
    CurrentValue = false,
    Flag = "AutoLoop",
    Callback = function(Value)
        if Value then
            StartLoop()
            Notify("Arcan1ST", "Loop Started", 2)
        else
            State.AutoTeleport = false
            State.AutoJump = false
            EnsureCharacterCanMove()
            Notify("Arcan1ST", "Loop Stopped", 2)
        end
    end
})

local TeleportSection = TeleportTab:CreateSection("Camp Teleports")

for _, camp in ipairs(CheckpointOrder) do
    TeleportTab:CreateButton({
        Name = "→ " .. camp,
        Callback = function()
            SafeTeleport(Waypoints[camp])
            Notify("Teleport", "Moved to " .. camp, 2)
        end
    })
end

if SETTINGS.FPS_BOOST_AUTO then 
    SmartBoostFPS() 
end

HookCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
LocalPlayer.CharacterAdded:Connect(HookCharacter)

task.spawn(function()
    if LocalPlayer.Character then
        EnsureCharacterCanMove()
    end
    
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        EnsureCharacterCanMove()
    end)
    
    task.spawn(function()
        while task.wait(1) do
            if LocalPlayer.Character then
                local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                if rootPart and rootPart.Anchored or (humanoid and humanoid.PlatformStand) then
                    EnsureCharacterCanMove()
                end
            end
        end
    end)
end)

Notify("Arcan1ST", "Loaded Successfully! ✅", 3)
