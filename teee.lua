local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local hydrationThreshold = 50
local isAutoHydrationEnabled = true
local validatedPositions = {}

local teleportPoints = {
    ["BASE"] = Vector3.new(-6016.00, -159.00, -28.57),
    ["CAMP1"] = Vector3.new(-3720.19, 225.00, 235.91),
    ["CAMP2"] = Vector3.new(1790.79, 105.45, -136.89),
    ["CAMP3"] = Vector3.new(5891.24, 321.00, -18.60),
    ["CAMP4"] = Vector3.new(8992.07, 595.59, 103.63),
    ["SOUTHPOLE"] = Vector3.new(10993.19, 549.13, 100.13)
}

local fillBottleLocations = {
    ["BASE"] = Vector3.new(-6042.84, -158.95, -59.00),
    ["CAMP1"] = Vector3.new(-3718.06, 228.94, 261.38),
    ["CAMP2"] = Vector3.new(1799.14, 105.37, -161.86),
    ["CAMP3"] = Vector3.new(5885.90, 321.00, 4.62),
    ["CAMP4"] = Vector3.new(9000.03, 597.40, 88.02)
}

local campNameMapping = {
    ["BASE"] = "BaseCamp",
    ["CAMP1"] = "Camp1",
    ["CAMP2"] = "Camp2",
    ["CAMP3"] = "Camp3",
    ["CAMP4"] = "Camp4"
}

local checkpointOrder = {"CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE"}
local currentCheckpoint = 1
local isAutoTeleporting = false
local isAutoJumping = false

local function findNearestCheckpoint()
    local p = game.Players.LocalPlayer
    if not p then return 1 end
    if not p.Character then
        p.CharacterAdded:Wait()
    end
    local character = p.Character
    if not character then return 1 end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return 1 end
    local currentPos = humanoidRootPart.Position
    local nearestDist = math.huge
    local nearestIndex = 1
    for i, checkpointName in ipairs(checkpointOrder) do
        local checkpointPos = teleportPoints[checkpointName]
        local dist = (currentPos - checkpointPos).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIndex = i
        end
    end
    return nearestIndex
end

local function startAutoJump()
    spawn(function()
        while isAutoJumping do
            local p = game.Players.LocalPlayer
            if p and p.Character then
                local humanoid = p.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.Jump = true
                end
            end
            wait(0.5)
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
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or child.Name:find("Water") then
                    task.wait()
                    child:Destroy()
                end
            end
        end)
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or child.Name:find("Water") then
                    child:Destroy()
                end
            end
        end
    end
    if p.Character then
        protectFromDamage(p.Character)
    end
    p.CharacterAdded:Connect(protectFromDamage)
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

local function tweenTo(position)
    local p = game.Players.LocalPlayer
    if not p then return end
    if not p.Character then
        p.CharacterAdded:Wait()
    end
    local char = p.Character
    if not char then return end
    local tries = 0
    while tries < 10 do
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            local posKey = tostring(math.floor(position.X)) .. "," .. tostring(math.floor(position.Y)) .. "," .. tostring(math.floor(position.Z))

            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.RotVelocity = Vector3.new(0, 0, 0)
            rootPart.Anchored = true

            local targetCFrame = CFrame.new(position + Vector3.new(0, 5, 0))
            local distance = (rootPart.Position - targetCFrame.Position).Magnitude
            local tweenSpeed = 200
            local duration = math.clamp(distance / tweenSpeed, 0.3, 6)

            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
            tween:Play()
            tween.Completed:Wait()

            validatedPositions[posKey] = true
            task.wait(0.2)
            ensureCharacterCanMove()
            break
        end
        tries = tries + 1
        wait(0.1)
    end
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
    spawn(function()
        while isAutoTeleporting do
            if currentCheckpoint <= #checkpointOrder then
                tweenTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                wait(0.5)
            else
                wait(1)
                respawnCharacter()
                wait(3)
                if isAutoTeleporting then
                    currentCheckpoint = 1
                    tweenTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Arcan1ST Script",
                        Text = "Restarting from CAMP1! 🔄",
                        Duration = 3
                    })
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
                wait(1)
                respawnCharacter()
                wait(3)
                if isAutoTeleporting then
                    currentCheckpoint = 1
                    wait(0.5)
                    tweenTo(teleportPoints[checkpointOrder[currentCheckpoint]])
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
                    wait(0.5)
                    tweenTo(teleportPoints[checkpointOrder[currentCheckpoint]])
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
HydrationBtn.Text = "💧 Auto Hydration"
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
        tweenTo(pos)
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
            local currentPosition = rootPart.Position
            local groundPosition = currentPosition - Vector3.new(0, 3, 0)
            rootPart.CFrame = CFrame.new(groundPosition)
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
    local southPolePos = teleportPoints["SOUTHPOLE"]
    local distanceToSouthPole = (pos - southPolePos).Magnitude
    if distanceToSouthPole < 500 then return nil end
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

local function tryDrink()
    local character = player.Character
    if not character then return false end
    local waterBottle = character:FindFirstChild("Water Bottle")
    if waterBottle and waterBottle:FindFirstChild("RemoteEvent") then
        waterBottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

local function fillBottleAtCamp(campName)
    local wasAutoJumping = isAutoJumping
    local properCampName = campNameMapping[campName] or campName
    local fillLocation = fillBottleLocations[campName]
    if fillLocation then
        isAutoJumping = false
        local character = player.Character
        local backpack = player:WaitForChild("Backpack")
        local waterBottle = character:FindFirstChild("Water Bottle") or backpack:FindFirstChild("Water Bottle")
        if waterBottle and waterBottle:IsA("Tool") then
            if waterBottle.Parent == backpack then
                local humanoid = character:WaitForChild("Humanoid")
                humanoid:EquipTool(waterBottle)
                task.wait(0.3)
            end
            tweenTo(fillLocation)
            task.wait(0.3)
            local args = {"FillBottle", properCampName, "Water"}
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("EnergyHydration"):FireServer(unpack(args))
            task.wait(0.5)
            if teleportPoints[campName] then
                tweenTo(teleportPoints[campName])
            end
        else
            warn("Water Bottle tidak ditemukan di Backpack atau Character!")
        end
        isAutoJumping = wasAutoJumping
        if wasAutoJumping then startAutoJump() end
    end
end

task.spawn(function()
    RunService.RenderStepped:Connect(function()
        if not isAutoHydrationEnabled then return end
        local hydration = player:GetAttribute("Hydration")
        if hydration then
            if hydration >= 99 then return end
            if hydration < 50 then
                local beforeDrinkHydration = hydration
                tryDrink()
                task.wait(0.3)
                local afterDrinkHydration = player:GetAttribute("Hydration")
                local hydrationIncreased = afterDrinkHydration > beforeDrinkHydration
                if hydrationIncreased then
                    while player:GetAttribute("Hydration") < 99 do
                        local currentHydration = player:GetAttribute("Hydration")
                        local success = tryDrink()
                        task.wait(0.3)
                        local newHydration = player:GetAttribute("Hydration")
                        if newHydration >= 99 then break end
                        if not success or newHydration <= currentHydration then
                            local nearestCamp = getNearestCamp()
                            if nearestCamp then
                                fillBottleAtCamp(nearestCamp)
                                task.wait(0.3)
                                tryDrink()
                            end
                            break
                        end
                        task.wait(0.2)
                    end
                else
                    local nearestCamp = getNearestCamp()
                    if nearestCamp then
                        fillBottleAtCamp(nearestCamp)
                        task.wait(0.3)
                        while player:GetAttribute("Hydration") < 99 do
                            local currentHydration = player:GetAttribute("Hydration")
                            if currentHydration >= 99 then break end
                            local success = tryDrink()
                            task.wait(0.3)
                            local newHydration = player:GetAttribute("Hydration")
                            if not success or newHydration <= currentHydration then break end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end)
end)

task.spawn(function()
    local p = game.Players.LocalPlayer
    if not p.Character then p.CharacterAdded:Wait() end
    setupAntiFallDamage()
    p.CharacterAdded:Connect(function(char)
        wait(1)
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
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        ensureCharacterCanMove()
    end)
    task.spawn(function()
        while wait(1) do
            if p.Character then
                local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = p.Character:FindFirstChild("Humanoid")
                if rootPart and rootPart.Anchored or (humanoid and humanoid.PlatformStand) then
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
    MinimizedFrame.Draggable = false
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
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
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

local function updatePosition(from, to)
    from.Changed:Connect(function(property)
        if property == "Position" and from.Visible then
            to.Position = from.Position
        end
    end)
end

updatePosition(MainFrame, MinimizedFrame)
updatePosition(MinimizedFrame, MainFrame)

MainFrame.Size = UDim2.new(0, 180, 0, 0)

task.spawn(function()
    while task.wait() do
        if MainFrame.Visible then
            local totalHeight = ButtonHolder.AbsoluteSize.Y + 50
            Watermark.Position = UDim2.new(0, 0, 0, totalHeight)
        end
    end
end)
