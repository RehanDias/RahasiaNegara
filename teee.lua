local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local isAutoHydrationEnabled = true

local teleportPoints = {
    ["BASE"]      = Vector3.new(-6016.00, -159.00, -28.57),
    ["CAMP1"]     = Vector3.new(-3720.19, 225.00, 235.91),
    ["CAMP2"]     = Vector3.new(1790.79, 105.45, -136.89),
    ["CAMP3"]     = Vector3.new(5891.24, 321.00, -18.60),
    ["CAMP4"]     = Vector3.new(8992.07, 595.59, 103.63),
    ["SOUTHPOLE"] = Vector3.new(10993.19, 549.13, 100.13)
}

local fillBottleLocations = {
    ["BASE"]  = Vector3.new(-6042.84, -158.95, -59.00),
    ["CAMP1"] = Vector3.new(-3718.06, 228.94, 261.38),
    ["CAMP2"] = Vector3.new(1799.14, 105.37, -161.86),
    ["CAMP3"] = Vector3.new(5885.90, 321.00, 4.62),
    ["CAMP4"] = Vector3.new(9000.03, 597.40, 88.02)
}

local campNameMapping = {
    ["BASE"]  = "BaseCamp",
    ["CAMP1"] = "Camp1",
    ["CAMP2"] = "Camp2",
    ["CAMP3"] = "Camp3",
    ["CAMP4"] = "Camp4"
}

local checkpointOrder = {"CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE"}
local currentCheckpoint = 1
local isAutoTeleporting = false
local isAutoJumping = false

local function rng(a, b)
    return a + math.random() * (b - a)
end

local function randWait(a, b)
    task.wait(rng(a, b))
end

local function randOffset()
    return Vector3.new(rng(-1.8, 1.8), 0, rng(-1.8, 1.8))
end

local function ensureCharacterCanMove()
    local p = game.Players.LocalPlayer
    if not p or not p.Character then return end
    local humanoid = p.Character:FindFirstChild("Humanoid")
    local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
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

local function saferTeleport(position)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    root.AssemblyLinearVelocity = Vector3.new(rng(-4, 4), rng(2, 6), rng(-4, 4))

    local willAnchor = math.random() < 0.45
    if willAnchor then root.Anchored = true end

    local finalPos = position + Vector3.new(0, rng(4, 8), 0) + randOffset()
    local target = CFrame.new(finalPos) * CFrame.Angles(0, math.rad(rng(-15, 15)), 0)

    local steps = math.random(9, 15)
    for i = 1, steps do
        root.CFrame = root.CFrame:Lerp(target, i / steps)
        task.wait(rng(0.018, 0.065))
    end

    root.CFrame = target
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    randWait(0.6, 1.4)
    ensureCharacterCanMove()
end

local function findNearestCheckpoint()
    local p = game.Players.LocalPlayer
    if not p then return 1 end
    if not p.Character then p.CharacterAdded:Wait() end
    local character = p.Character
    if not character then return 1 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 1 end
    local currentPos = hrp.Position
    local nearestDist = math.huge
    local nearestIndex = 1
    for i, checkpointName in ipairs(checkpointOrder) do
        local dist = (currentPos - teleportPoints[checkpointName]).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIndex = i
        end
    end
    return nearestIndex
end

local function startAutoJump()
    task.spawn(function()
        while isAutoJumping do
            local p = game.Players.LocalPlayer
            if p and p.Character then
                local humanoid = p.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.Jump = true
                end
            end
            task.wait(rng(0.45, 0.75))
        end
    end)
end

local function setupAntiFallDamage()
    local p = game.Players.LocalPlayer
    if not p then return end
    local function protectFromDamage(char)
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") then
                    task.wait()
                    child:Destroy()
                end
            end
        end)
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") then
                    child:Destroy()
                end
            end
        end
    end
    if p.Character then protectFromDamage(p.Character) end
    p.CharacterAdded:Connect(protectFromDamage)
end

local function respawnCharacter()
    local p = game.Players.LocalPlayer
    if p and p.Character then
        local humanoid = p.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
    end
end

local function startAutoTeleport()
    if isAutoTeleporting then return end
    currentCheckpoint = findNearestCheckpoint()
    isAutoTeleporting = true
    isAutoJumping = true
    startAutoJump()
    task.spawn(function()
        while isAutoTeleporting do
            if currentCheckpoint <= #checkpointOrder then
                saferTeleport(teleportPoints[checkpointOrder[currentCheckpoint]])
                randWait(1.4, 3.0)
            else
                randWait(1.5, 2.8)
                respawnCharacter()
                randWait(3.5, 6.0)
                if isAutoTeleporting then
                    currentCheckpoint = 1
                    randWait(0.6, 1.5)
                    saferTeleport(teleportPoints[checkpointOrder[currentCheckpoint]])
                end
                break
            end
        end
    end)
end

game:GetService("ReplicatedStorage").Message_Remote.OnClientEvent:Connect(function(message)
    if typeof(message) == "string" then
        if message:find("You have made it to South Pole") then
            if isAutoTeleporting then
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Arcan1STHub",
                    Text = "South Pole Reached! 🎯",
                    Duration = 2
                })
                randWait(1.0, 2.0)
                respawnCharacter()
                randWait(3.0, 5.0)
                if isAutoTeleporting then
                    currentCheckpoint = 1
                    randWait(0.5, 1.5)
                    saferTeleport(teleportPoints[checkpointOrder[currentCheckpoint]])
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Arcan1STHub",
                        Text = "Restarting from CAMP1! 🔄",
                        Duration = 3
                    })
                else
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Arcan1STHub",
                        Text = "Journey Completed! 🎉",
                        Duration = 3
                    })
                end
                isAutoJumping = not isAutoTeleporting
            end
        elseif message:find("You have made it to Camp") then
            if isAutoTeleporting then
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Arcan1STHub",
                    Text = "Checkpoint Completed! ⭐",
                    Duration = 2
                })
                currentCheckpoint = currentCheckpoint + 1
                if currentCheckpoint <= #checkpointOrder then
                    randWait(0.7, 1.6)
                    saferTeleport(teleportPoints[checkpointOrder[currentCheckpoint]])
                end
            end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "Arcan1ST-Antartica"

local MinimizedFrame = Instance.new("Frame", ScreenGui)
MinimizedFrame.Size = UDim2.new(0, 120, 0, 30)
MinimizedFrame.Position = UDim2.new(0, 50, 0.4, 0)
MinimizedFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MinimizedFrame.BorderSizePixel = 0
MinimizedFrame.Active = true
MinimizedFrame.Visible = false
Instance.new("UICorner", MinimizedFrame).CornerRadius = UDim.new(0, 8)

local MinimizedDragArea = Instance.new("Frame", MinimizedFrame)
MinimizedDragArea.Size = UDim2.new(1, 0, 1, 0)
MinimizedDragArea.BackgroundTransparency = 1
MinimizedDragArea.Active = true

local isDragging = false
local dragStart = nil
local startPos = nil

MinimizedDragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = MinimizedFrame.Position
        local connection
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
                if connection then connection:Disconnect() end
            end
        end)
    end
end)

MinimizedDragArea.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if isDragging then
            local delta = input.Position - dragStart
            MinimizedFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

local MinimizedLabel = Instance.new("TextButton", MinimizedFrame)
MinimizedLabel.Size = UDim2.new(1, 0, 1, 0)
MinimizedLabel.BackgroundTransparency = 1
MinimizedLabel.Text = "🎯 Arcan1ST"
MinimizedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizedLabel.Font = Enum.Font.SourceSansBold
MinimizedLabel.TextSize = 14

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Position = UDim2.new(0, 50, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.AutomaticSize = Enum.AutomaticSize.Y
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 25)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 5, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Arcan1STHub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinimizeBtn = Instance.new("TextButton", TitleBar)
MinimizeBtn.Size = UDim2.new(0, 20, 0, 20)
MinimizeBtn.Position = UDim2.new(1, -45, 0, 3)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 16
MinimizeBtn.BorderSizePixel = 0
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(1, -25, 0, 3)
CloseBtn.Text = "❌"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 12
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

local ButtonHolder = Instance.new("Frame", MainFrame)
ButtonHolder.Size = UDim2.new(1, -10, 0, 0)
ButtonHolder.Position = UDim2.new(0, 5, 0, 30)
ButtonHolder.BackgroundTransparency = 1
ButtonHolder.AutomaticSize = Enum.AutomaticSize.Y

local layout = Instance.new("UIListLayout", ButtonHolder)
layout.Padding = UDim.new(0, 5)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

local Watermark = Instance.new("TextLabel", MainFrame)
Watermark.Size = UDim2.new(1, 0, 0, 20)
Watermark.Position = UDim2.new(0, 0, 1, -20)
Watermark.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Watermark.Text = "by Arcan1ST ⭐"
Watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
Watermark.Font = Enum.Font.SourceSansBold
Watermark.TextSize = 12
Watermark.BorderSizePixel = 0
Instance.new("UICorner", Watermark).CornerRadius = UDim.new(0, 8)

local HydrationBtn = Instance.new("TextButton", ButtonHolder)
HydrationBtn.Size = UDim2.new(1, 0, 0, 30)
HydrationBtn.Text = "💧 Auto Hydration: ON"
HydrationBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HydrationBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
HydrationBtn.Font = Enum.Font.SourceSansBold
HydrationBtn.TextSize = 14
HydrationBtn.BorderSizePixel = 0
HydrationBtn.TextXAlignment = Enum.TextXAlignment.Left
HydrationBtn.TextWrapped = false
HydrationBtn.LayoutOrder = 0
Instance.new("UIPadding", HydrationBtn).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", HydrationBtn).CornerRadius = UDim.new(0, 6)

HydrationBtn.MouseButton1Click:Connect(function()
    isAutoHydrationEnabled = not isAutoHydrationEnabled
    if isAutoHydrationEnabled then
        HydrationBtn.Text = "💧 Auto Hydration: ON"
        HydrationBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
    else
        HydrationBtn.Text = "💧 Auto Hydration: OFF"
        HydrationBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end
end)

local AutoTpBtn = Instance.new("TextButton", ButtonHolder)
AutoTpBtn.Size = UDim2.new(1, 0, 0, 30)
AutoTpBtn.Text = "🎯 Auto Complete"
AutoTpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoTpBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
AutoTpBtn.Font = Enum.Font.SourceSansBold
AutoTpBtn.TextSize = 14
AutoTpBtn.BorderSizePixel = 0
AutoTpBtn.TextXAlignment = Enum.TextXAlignment.Left
AutoTpBtn.TextWrapped = false
AutoTpBtn.LayoutOrder = 1
Instance.new("UIPadding", AutoTpBtn).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", AutoTpBtn).CornerRadius = UDim.new(0, 6)

local buttonOrder = {"BASE", "CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE"}

for i, name in ipairs(buttonOrder) do
    local pos = teleportPoints[name]
    local btn = Instance.new("TextButton", ButtonHolder)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Text = "📍 " .. name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextWrapped = false
    btn.LayoutOrder = i + 1
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 10)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        saferTeleport(pos)
    end)
end

local function stopAutoComplete()
    isAutoTeleporting = false
    isAutoJumping = false
    local p = game.Players.LocalPlayer
    if p and p.Character then
        local humanoid = p.Character:FindFirstChild("Humanoid")
        local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            rootPart.Anchored = false
            humanoid.PlatformStand = false
            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.RotVelocity = Vector3.new(0, 0, 0)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

AutoTpBtn.MouseButton1Click:Connect(function()
    if isAutoTeleporting then
        stopAutoComplete()
        AutoTpBtn.Text = "🎯 Auto Complete"
        AutoTpBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Auto Complete",
            Text = "Stopped ⏹",
            Duration = 2
        })
    else
        startAutoTeleport()
        AutoTpBtn.Text = "⏹ Stop Auto Complete"
        AutoTpBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    stopAutoComplete()
    ScreenGui:Destroy()
end)

local function getNearestCamp()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return "BASE" end
    local pos = char.HumanoidRootPart.Position
    if (pos - teleportPoints["SOUTHPOLE"]).Magnitude < 500 then return nil end
    local closestCamp = nil
    local shortestDistance = math.huge
    for campName, campPos in pairs(teleportPoints) do
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

local function isBottleFull()
    local char = player.Character
    if not char then return false end
    local bottle = char:FindFirstChild("Water Bottle")
    if bottle then
        local fullAttr = bottle:GetAttribute("WaterAmount") or bottle:GetAttribute("Amount") or bottle:GetAttribute("Water")
        if fullAttr then
            return fullAttr >= 95
        end
    end
    return false
end

local function tryDrink()
    local char = player.Character
    if not char then return false end

    local humanoid = char:FindFirstChild("Humanoid")
    local bottle = char:FindFirstChild("Water Bottle")

    if not bottle then
        local bp = player.Backpack:FindFirstChild("Water Bottle")
        if bp and humanoid then
            humanoid:EquipTool(bp)
            task.wait(rng(0.45, 0.85))
            bottle = char:FindFirstChild("Water Bottle")
        end
    end

    if bottle and bottle:FindFirstChild("RemoteEvent") then
        task.wait(rng(0.08, 0.25))
        bottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

local function fillBottleAtCamp(campName)
    local wasAutoJumping = isAutoJumping
    isAutoJumping = false

    local properCampName = campNameMapping[campName] or campName
    local fillLocation = fillBottleLocations[campName]
    if not fillLocation then
        isAutoJumping = wasAutoJumping
        return
    end
    if isBottleFull() then
        isAutoJumping = wasAutoJumping
        return
    end

    local character = player.Character
    local backpack = player:WaitForChild("Backpack")
    local waterBottle = character:FindFirstChild("Water Bottle") or backpack:FindFirstChild("Water Bottle")

    if waterBottle and waterBottle:IsA("Tool") then
        if waterBottle.Parent == backpack then
            local humanoid = character:WaitForChild("Humanoid")
            humanoid:EquipTool(waterBottle)
            randWait(0.4, 0.7)
        end
        saferTeleport(fillLocation)
        randWait(1.3, 2.6)
        if math.random() < 0.45 then task.wait(rng(0.7, 1.6)) end

        ReplicatedStorage:WaitForChild("Events"):WaitForChild("EnergyHydration"):FireServer("FillBottle", properCampName, "Water")

        randWait(0.9, 1.8)
        if teleportPoints[campName] then
            saferTeleport(teleportPoints[campName])
        end
    end

    isAutoJumping = wasAutoJumping
    if wasAutoJumping then startAutoJump() end
end

task.spawn(function()
    while true do
        task.wait(rng(6, 11))

        if not isAutoHydrationEnabled then continue end

        local hydration = player:GetAttribute("Hydration")
        if not hydration or hydration >= 93 then continue end

        if hydration > 40 and math.random(100) <= 42 then
            continue
        end

        local target = math.random(84, 96)

        while true do
            local cur = player:GetAttribute("Hydration")
            if not cur or cur >= target then break end
            tryDrink()
            if cur > 75 then
                randWait(1.0, 2.0)
            else
                randWait(0.6, 1.3)
            end
        end

        if hydration < 50 and math.random(100) <= 35 then
            local nearest = getNearestCamp()
            if nearest then
                randWait(1.0, 2.0)
                fillBottleAtCamp(nearest)
            end
        end
    end
end)

task.spawn(function()
    local p = game.Players.LocalPlayer
    if not p.Character then p.CharacterAdded:Wait() end
    setupAntiFallDamage()
    p.CharacterAdded:Connect(function(char)
        task.wait(1)
        setupAntiFallDamage()
        char.DescendantAdded:Connect(function(desc)
            if desc:IsA("Script") and desc.Name:find("Damage") then
                desc:Destroy()
            end
        end)
    end)
end)

task.spawn(function()
    local p = game.Players.LocalPlayer
    if p.Character then ensureCharacterCanMove() end
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        ensureCharacterCanMove()
    end)
    task.spawn(function()
        while task.wait(rng(10, 16)) do
            if p.Character then
                local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = p.Character:FindFirstChild("Humanoid")
                if (rootPart and rootPart.Anchored) or (humanoid and humanoid.PlatformStand) then
                    ensureCharacterCanMove()
                end
            end
        end
    end)
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    local currentPos = MainFrame.Position
    MinimizedFrame.Position = currentPos
    MainFrame.Visible = false
    MinimizedFrame.Visible = true
    MinimizedFrame.Active = true
end)

MinimizedLabel.MouseButton1Click:Connect(function()
    local currentPos = MinimizedFrame.Position
    MainFrame.Position = currentPos
    MainFrame.Visible = true
    MinimizedFrame.Visible = false
end)

local dragging = false
local dragStart2 = nil
local startPos2 = nil
local dragInput = nil

local function updateDrag(input)
    if dragging then
        local delta = input.Position - dragStart2
        MinimizedFrame.Position = UDim2.new(startPos2.X.Scale, startPos2.X.Offset + delta.X, startPos2.Y.Scale, startPos2.Y.Offset + delta.Y)
    end
end

MinimizedFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart2 = input.Position
        startPos2 = MinimizedFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MinimizedFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

local function syncPosition(from, to)
    from.Changed:Connect(function(property)
        if property == "Position" and from.Visible then
            to.Position = from.Position
        end
    end)
end

syncPosition(MainFrame, MinimizedFrame)
syncPosition(MinimizedFrame, MainFrame)

MainFrame.Size = UDim2.new(0, 180, 0, 0)

task.spawn(function()
    while task.wait() do
        if MainFrame.Visible then
            local totalHeight = ButtonHolder.AbsoluteSize.Y + 50
            Watermark.Position = UDim2.new(0, 0, 0, totalHeight)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(rng(30, 60))
        if isAutoTeleporting and math.random(100) <= 22 then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(rng(-25, 25)), 0)
                task.wait(rng(0.4, 1.2))
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(rng(15, 40))
        if isAutoTeleporting and math.random() < 0.35 then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.new(rng(-6, 6), 0, rng(-6, 6))
                task.wait(rng(0.3, 0.8))
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
end)
