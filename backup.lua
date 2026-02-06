--[[ 
    ARCAN1ST HUB -  REMASTERED EDITION
    OPTIMIZED FOR: Performance, Safety, & Stability
    Features: Smart FPS Boost, Anti-AFK, Enhanced GUI with Minimize, Legit/Blatant Mode
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")

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
    CurrentCheckpoint = 1
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
end

local function HookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Script") and (v.Name:find("Damage") or v.Name:find("Fall")) then
            pcall(function() v.Disabled = true end)
        end
    end
    
    local oldHp = hum.Health
    hum.HealthChanged:Connect(function(newHp)
        if newHp < oldHp and (oldHp - newHp) > 10 then 
            hum.Health = oldHp 
        end
        oldHp = hum.Health
    end)
end

local function ProcessHydration()
    if not LocalPlayer.Character then return end
    
    local currentHydration = LocalPlayer:GetAttribute("Hydration") or 100
    if currentHydration < 40 then
        local tool = LocalPlayer.Character:FindFirstChild("Water Bottle") or LocalPlayer.Backpack:FindFirstChild("Water Bottle")
        
        if tool then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if tool.Parent ~= LocalPlayer.Character and hum then 
                hum:EquipTool(tool) 
            end
            task.wait(0.5)
            
            if tool:FindFirstChild("RemoteEvent") then
                tool.RemoteEvent:FireServer()
                task.wait(1)
                
                if (LocalPlayer:GetAttribute("Hydration") or 0) <= currentHydration then
                    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                    if (myPos - Waypoints["SOUTHPOLE"]).Magnitude > 500 then
                        local nearest, minDist = "BASE", math.huge
                        
                        for name, pos in pairs(BottlePoints) do
                            local dist = (myPos - pos).Magnitude
                            if dist < minDist then minDist = dist; nearest = name end
                        end
                        
                        local savedPos = myPos
                        local oldJump = State.AutoJump
                        State.AutoJump = false
                        
                        SafeTeleport(BottlePoints[nearest])
                        task.wait(0.5)
                        ReplicatedStorage.Events.EnergyHydration:FireServer("FillBottle", CampMapping[nearest], "Water")
                        task.wait(1)
                        SafeTeleport(savedPos)
                        
                        State.AutoJump = oldJump
                        if State.AutoJump then
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
            end
        end
    end
end

local function StartLoop()
    State.AutoTeleport = true
    State.AutoJump = true
    
    task.spawn(function()
        while State.AutoTeleport do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
            end
            
            if State.CurrentCheckpoint <= #CheckpointOrder then
                SafeTeleport(Waypoints[CheckpointOrder[State.CurrentCheckpoint]])
                task.wait(0.8)
            else
                Notify("Winner", "Loop Finished! Resetting...", 3)
                task.wait(1)
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid.Health = 0
                end
                
                LocalPlayer.CharacterAdded:Wait()
                task.wait(3)
                
                if State.AutoTeleport then
                    State.CurrentCheckpoint = 1
                    LocalPlayer:RequestStreamAroundAsync(Waypoints["CAMP1"])
                    SafeTeleport(Waypoints["CAMP1"])
                else
                    break
                end
            end
        end
    end)
    
    task.spawn(function()
        while State.AutoJump do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.Jump = true
            end
            task.wait(0.5)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoHydration then
            pcall(ProcessHydration)
        end
    end
end)

if ReplicatedStorage:FindFirstChild("Message_Remote") then
    ReplicatedStorage.Message_Remote.OnClientEvent:Connect(function(msg)
        if not State.AutoTeleport then return end
        if string.find(msg, "made it to Camp") then
            State.CurrentCheckpoint = State.CurrentCheckpoint + 1
        elseif string.find(msg, "South Pole") then
            State.CurrentCheckpoint = #CheckpointOrder + 1
        end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Arcan1ST_"
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

local isDragging, dragStart, startPos = false, nil, nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

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

local speedBtn = CreateBtn("⚙️ Mode: BLATANT (Instant)", Color3.fromRGB(120, 50, 200), function(b)
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
Notify("Arcan1ST", " Edition Loaded! ✅", 3)
