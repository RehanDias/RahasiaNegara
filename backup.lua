--[[ 
    ARCAN1ST HUB - FIXED EDITION
    Features: Smart FPS Boost, Anti-AFK, Enhanced GUI, Auto Progress Detection
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local SETTINGS = {
    FPS_BOOST_AUTO = false,
    WAIT_FOR_LOAD = true,
    TWEEN_SPEED = 0,
    THEME = {
        Main = Color3.fromRGB(20, 20, 25),
        TitleBar = Color3.fromRGB(30, 30, 40),
        Accent = Color3.fromRGB(0, 255, 128),
        Text = Color3.fromRGB(240, 240, 240),
        Button = Color3.fromRGB(45, 45, 55)
    }
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

-- ========== GUI CREATION - CLEANED UP ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Arcan1ST_Hub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 240, 0, 400)
MainFrame.Position = UDim2.new(0.08, 0, 0.25, 0)
MainFrame.BackgroundColor3 = SETTINGS.THEME.Main
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = SETTINGS.THEME.Accent
MainStroke.Thickness = 2

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = SETTINGS.THEME.TitleBar
TitleBar.BorderSizePixel = 0
local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 10)
local TitleBarBottom = Instance.new("Frame", TitleBar)
TitleBarBottom.Size = UDim2.new(1, 0, 0, 10)
TitleBarBottom.Position = UDim2.new(0, 0, 1, -10)
TitleBarBottom.BackgroundColor3 = SETTINGS.THEME.TitleBar
TitleBarBottom.BorderSizePixel = 0

local TitleIcon = Instance.new("TextLabel", TitleBar)
TitleIcon.Size = UDim2.new(0, 30, 0, 30)
TitleIcon.Position = UDim2.new(0, 5, 0, 5)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text = "🎯"
TitleIcon.TextSize = 20
TitleIcon.Font = Enum.Font.GothamBold

local TitleText = Instance.new("TextLabel", TitleBar)
TitleText.Size = UDim2.new(1, -100, 1, 0)
TitleText.Position = UDim2.new(0, 40, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "ARCAN1ST"
TitleText.TextColor3 = Color3.new(1, 1, 1)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 15
TitleText.TextXAlignment = Enum.TextXAlignment.Left

local TitleAccent = Instance.new("TextLabel", TitleBar)
TitleAccent.Size = UDim2.new(0, 40, 1, 0)
TitleAccent.Position = UDim2.new(0, 110, 0, 0)
TitleAccent.BackgroundTransparency = 1
TitleAccent.Text = "HUB"
TitleAccent.TextColor3 = SETTINGS.THEME.Accent
TitleAccent.Font = Enum.Font.GothamBold
TitleAccent.TextSize = 15
TitleAccent.TextXAlignment = Enum.TextXAlignment.Left

local MinimizeBtn = Instance.new("TextButton", TitleBar)
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -62, 0, 6)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.new(1, 1, 1)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 20
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.BackgroundColor3 = SETTINGS.THEME.Main
ContentFrame.BorderSizePixel = 0

local ScrollFrame = Instance.new("ScrollingFrame", ContentFrame)
ScrollFrame.Size = UDim2.new(1, -10, 1, -10)
ScrollFrame.Position = UDim2.new(0, 5, 0, 5)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = SETTINGS.THEME.Accent
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local UIList = Instance.new("UIListLayout", ScrollFrame)
UIList.Padding = UDim.new(0, 7)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local TargetIcon = Instance.new("TextButton", ScreenGui)
TargetIcon.Name = "TargetIcon"
TargetIcon.Size = UDim2.new(0, 55, 0, 55)
TargetIcon.Position = UDim2.new(0.08, 0, 0.25, 0)
TargetIcon.BackgroundColor3 = SETTINGS.THEME.TitleBar
TargetIcon.Text = "🎯"
TargetIcon.TextSize = 28
TargetIcon.Font = Enum.Font.GothamBold
TargetIcon.TextColor3 = SETTINGS.THEME.Accent
TargetIcon.Visible = false
Instance.new("UICorner", TargetIcon).CornerRadius = UDim.new(0, 27)
local IconStroke = Instance.new("UIStroke", TargetIcon)
IconStroke.Color = SETTINGS.THEME.Accent
IconStroke.Thickness = 2

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if isMinimized then
        TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 240, 0, 40)}):Play()
        task.wait(0.3)
        MainFrame.Visible = false
        TargetIcon.Visible = true
        TargetIcon.Position = MainFrame.Position
    else
        MainFrame.Visible = true
        TargetIcon.Visible = false
        TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 240, 0, 400)}):Play()
    end
end)

TargetIcon.MouseButton1Click:Connect(function()
    isMinimized = false
    MainFrame.Visible = true
    TargetIcon.Visible = false
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
        {Size = UDim2.new(0, 240, 0, 400)}):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    State.AutoTeleport = false
    State.AutoJump = false
    State.AutoHydration = false
    EnsureCharacterCanMove()
    ScreenGui:Destroy()
    getgenv().Arcan1ST_Running = false
end)

local function CreateBtn(text, col, func)
    local btn = Instance.new("TextButton", ScrollFrame)
    btn.Size = UDim2.new(0.95, 0, 0, 36)
    btn.Text = text
    btn.BackgroundColor3 = col
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(
            math.min(col.R * 255 + 25, 255),
            math.min(col.G * 255 + 25, 255),
            math.min(col.B * 255 + 25, 255)
        ) / 255}):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = col}):Play()
    end)
    
    btn.MouseButton1Click:Connect(function() func(btn) end)
    return btn
end

CreateBtn("⚡ BOOST FPS (SAFE)", Color3.fromRGB(255, 150, 0), function(b)
    SmartBoostFPS()
    b.Text = "✅ FPS BOOSTED"
    task.wait(1.5)
    b.Text = "⚡ BOOST FPS (SAFE)"
end)

CreateBtn("💧 Auto Hydration: OFF", Color3.fromRGB(70, 70, 85), function(b)
    State.AutoHydration = not State.AutoHydration
    b.Text = State.AutoHydration and "💧 Auto Hydration: ON" or "💧 Auto Hydration: OFF"
    b.BackgroundColor3 = State.AutoHydration and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(70, 70, 85)
end)

CreateBtn("⚙️ Mode: BLATANT (Instant)", Color3.fromRGB(120, 50, 200), function(b)
    if SETTINGS.TWEEN_SPEED == 0 then
        SETTINGS.TWEEN_SPEED = 500
        b.Text = "⚙️ Mode: LEGIT (Tween)"
        b.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
        Notify("Mode", "Legit Mode (500 speed)")
    else
        SETTINGS.TWEEN_SPEED = 0
        b.Text = "⚙️ Mode: BLATANT (Instant)"
        b.BackgroundColor3 = Color3.fromRGB(120, 50, 200)
        Notify("Mode", "Blatant Mode (Instant TP)")
    end
end)

CreateBtn("🚀 START AUTO LOOP", SETTINGS.THEME.Accent, function(b)
    if State.AutoTeleport then
        State.AutoTeleport = false
        State.AutoJump = false
        EnsureCharacterCanMove()
        b.Text = "🚀 START AUTO LOOP"
        b.BackgroundColor3 = SETTINGS.THEME.Accent
        Notify("Arcan1ST", "Loop Stopped")
    else
        StartLoop()
        b.Text = "⏹ STOP LOOP"
        b.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        Notify("Arcan1ST", "Loop Started")
    end
end)

local Divider = Instance.new("Frame", ScrollFrame)
Divider.Size = UDim2.new(0.9, 0, 0, 2)
Divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
Divider.BorderSizePixel = 0

for _, camp in ipairs(CheckpointOrder) do
    CreateBtn("📍 " .. camp, Color3.fromRGB(60, 60, 90), function()
        SafeTeleport(Waypoints[camp])
        Notify("Teleport", "Moved to " .. camp)
    end)
end

if SETTINGS.FPS_BOOST_AUTO then SmartBoostFPS() end
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

Notify("Arcan1ST", "Fixed Edition Loaded! ✅", 3)
