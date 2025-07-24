--[[ SERVICES ]] --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--[[ VARIABLES ]] --
local player = Players.LocalPlayer
local hydrationThreshold = 50
local isAutoHydrationEnabled = true
-- Add cache for validated positions
local validatedPositions = {}

--[[ TELEPORT LOCATIONS ]] --
local teleportPoints = {
    ["BASE"] = Vector3.new(-6016.00, -159.00, -28.57),
    ["CAMP1"] = Vector3.new(-3720.19, 225.00, 235.91),
    ["CAMP2"] = Vector3.new(1790.79, 105.45, -136.89),
    ["CAMP3"] = Vector3.new(5891.24, 321.00, -18.60),
    ["CAMP4"] = Vector3.new(8992.07, 595.59, 103.63),
    ["SOUTHPOLE"] = Vector3.new(10993.19, 549.13, 100.13)
}

-- Water bottle fill locations
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

--[[ FIND NEAREST CHECKPOINT ]] --
local function findNearestCheckpoint()
    local player = game.Players.LocalPlayer
    if not player then
        return 1
    end

    -- Wait for character to load if not present
    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local character = player.Character
    if not character then
        return 1
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return 1
    end

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

--[[ AUTO JUMP FUNCTION ]] --
local function startAutoJump()
    spawn(function()
        while isAutoJumping do
            local player = game.Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.Jump = true
                end
            end
            wait(0.5)
        end
    end)
end

--[[ ANTI FALL DAMAGE SYSTEM ]] --
local function setupAntiFallDamage()
    local player = game.Players.LocalPlayer
    if not player then
        return
    end

    local function protectFromDamage(char)
        if not char then
            return
        end

        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then
            return
        end

        -- Disable all damage-related states
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

        -- Connect to health changes but allow respawn
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)

        -- Additional fall damage protection
        char.ChildAdded:Connect(function(child)
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or
                    child.Name:find("Water") then
                    task.wait()
                    child:Destroy()
                end
            end
        end)

        -- Remove existing damage scripts
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or
                    child.Name:find("Water") then
                    child:Destroy()
                end
            end
        end
    end

    -- Protect current character
    if player.Character then
        protectFromDamage(player.Character)
    end

    -- Protect future characters
    player.CharacterAdded:Connect(protectFromDamage)
end

--[[ SAFETY TELEPORT FUNCTION ]] --
local function waitForTerrain(position)
    local terrain = workspace.Terrain
    local radius = 100 -- Radius area to check for obstacles

    -- Wait for terrain and obstacles to load
    local startTime = tick()
    local timeout = 5 -- Maximum wait time in seconds

    while tick() - startTime < timeout do
        local blockFound = false

        -- Check if there's any solid ground below the position
        local ray = Ray.new(position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))
        local hit, hitPosition = workspace:FindPartOnRay(ray)

        if hit then
            -- Found solid ground
            return true
        end

        task.wait(0.1)
    end

    return false -- Timeout reached
end

--[[ MOVEMENT HANDLER ]] --
local function ensureCharacterCanMove()
    local player = game.Players.LocalPlayer
    if not player or not player.Character then
        return
    end

    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and rootPart then
        -- Reset movement states
        rootPart.Anchored = false
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)

        -- Enable necessary states for movement
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)

        -- Reset velocities
        rootPart.Velocity = Vector3.new(0, 0, 0)
        rootPart.RotVelocity = Vector3.new(0, 0, 0)
    end
end

local function instantTeleportTo(position)
    local player = game.Players.LocalPlayer
    if not player then
        return
    end

    -- Wait for character to load if not present
    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local char = player.Character
    if not char then
        return
    end

    -- Wait for HumanoidRootPart and Humanoid
    local tries = 0
    while tries < 10 do
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            -- Create position key for cache
            local posKey = tostring(math.floor(position.X)) .. "," .. tostring(math.floor(position.Y)) .. "," ..
                               tostring(math.floor(position.Z))

            -- Reset velocities and prepare for teleport
            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.RotVelocity = Vector3.new(0, 0, 0)

            -- Check if this position has been validated before
            if not validatedPositions[posKey] then
                rootPart.Anchored = true

                -- Teleport slightly above target position
                local safeHeight = 10
                local initialPos = position + Vector3.new(0, safeHeight, 0)
                rootPart.CFrame = CFrame.new(initialPos)

                -- Wait for terrain and obstacles to load
                local terrainLoaded = waitForTerrain(position)

                if terrainLoaded then
                    validatedPositions[posKey] = true

                    -- Final teleport
                    local finalPosition = position + Vector3.new(0, 5, 0)
                    rootPart.CFrame = CFrame.new(finalPosition)

                    -- Ensure movement is restored
                    task.wait(0.2)
                    ensureCharacterCanMove()
                else
                    warn("Terrain tidak terload sepenuhnya")
                    ensureCharacterCanMove()
                end
            else
                -- Position already validated, direct teleport
                local finalPosition = position + Vector3.new(0, 5, 0)
                rootPart.CFrame = CFrame.new(finalPosition)
                task.wait(0.1)
                ensureCharacterCanMove()
            end
            break
        end
        tries = tries + 1
        wait(0.1)
    end
end

--[[ RESPAWN FUNCTION ]] --
local function respawnCharacter()
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            -- Fade out screen before respawn
            local fadeScreen = Instance.new("ScreenGui")
            local fadeFrame = Instance.new("Frame")
            fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
            fadeFrame.Size = UDim2.fromScale(1, 1)
            fadeFrame.BackgroundTransparency = 1
            fadeFrame.Parent = fadeScreen
            fadeScreen.Parent = game.CoreGui

            -- Animate fade out
            for i = 1, 10 do
                fadeFrame.BackgroundTransparency = 1 - (i / 10)
                wait(0.05)
            end

            -- Respawn the character
            humanoid.Health = 0

            -- Wait for new character
            player.CharacterAdded:Wait()
            wait(2) -- Give extra time for textures to load

            -- Animate fade in
            for i = 1, 10 do
                fadeFrame.BackgroundTransparency = i / 10
                wait(0.05)
            end

            -- Clean up
            fadeScreen:Destroy()
        end
    end
end

--[[ AUTO TELEPORT FUNCTION ]] --
local function startAutoTeleport()
    if isAutoTeleporting then
        return
    end

    currentCheckpoint = findNearestCheckpoint()
    isAutoTeleporting = true
    isAutoJumping = true
    startAutoJump()

    spawn(function()
        while isAutoTeleporting do
            if currentCheckpoint <= #checkpointOrder then
                instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                wait(0.5)
            else
                -- When reaching SOUTHPOLE
                wait(1)
                respawnCharacter() -- Respawn instead of teleporting to BASE
                wait(3) -- Wait for respawn
                if isAutoTeleporting then
                    -- Restart from CAMP1 if auto teleport is still enabled
                    currentCheckpoint = 1
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])

                    -- Show restart message
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

--[[ CHECKPOINT DETECTION ]] --
game:GetService("ReplicatedStorage").Message_Remote.OnClientEvent:Connect(function(message)
    if typeof(message) == "string" then
        -- Deteksi South Pole
        if message:find("You have made it to South Pole") then
            if isAutoTeleporting then
                -- Show South Pole completion message
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Arcan1STHub",
                    Text = "South Pole Reached! 🎯",
                    Duration = 2
                })

                wait(1)
                respawnCharacter() -- Respawn
                wait(3) -- Wait for respawn

                if isAutoTeleporting then
                    -- If auto teleport is still on, restart from CAMP1
                    currentCheckpoint = 1
                    wait(0.5) -- Tunggu sebentar setelah respawn
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Arcan1STHub",
                        Text = "Restarting from CAMP1! 🔄",
                        Duration = 3
                    })
                else
                    -- Show completion message
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Arcan1STHub",
                        Text = "Journey Completed! 🎉",
                        Duration = 3
                    })
                end

                isAutoJumping = not isAutoTeleporting -- Stop jumping if auto teleport is off
            end
            -- Deteksi Camp biasa
        elseif message:find("You have made it to Camp") then
            if isAutoTeleporting then
                -- Show execution message
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Arcan1STHub",
                    Text = "Checkpoint Completed! ⭐",
                    Duration = 2
                })

                currentCheckpoint = currentCheckpoint + 1
                if currentCheckpoint <= #checkpointOrder then
                    wait(0.5) -- Tunggu sebentar sebelum teleport ke checkpoint berikutnya
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                end
            end
        end
    end
end)

--[[ GUI CREATION ]] --
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "Arcan1ST-Antartica"

-- Create MinimizedFrame with proper dragging
local MinimizedFrame = Instance.new("Frame", ScreenGui)
MinimizedFrame.Size = UDim2.new(0, 120, 0, 30)
MinimizedFrame.Position = UDim2.new(0, 50, 0.4, 0)
MinimizedFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MinimizedFrame.BorderSizePixel = 0
MinimizedFrame.Active = true
MinimizedFrame.Visible = false
Instance.new("UICorner", MinimizedFrame).CornerRadius = UDim.new(0, 8)

-- Create drag handle for MinimizedFrame
local MinimizedDragArea = Instance.new("Frame", MinimizedFrame)
MinimizedDragArea.Size = UDim2.new(1, 0, 1, 0)
MinimizedDragArea.BackgroundTransparency = 1
MinimizedDragArea.Active = true

-- Dragging functionality for MinimizedFrame
local UserInputService = game:GetService("UserInputService")
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
                if connection then
                    connection:Disconnect()
                end
            end
        end)
    end
end)

MinimizedDragArea.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if isDragging then
            local delta = input.Position - dragStart
            MinimizedFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale,
                startPos.Y.Offset + delta.Y)
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
MainFrame.AutomaticSize = Enum.AutomaticSize.Y -- Enable automatic Y sizing
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

--[[ TITLE BAR ]] --
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

--[[ MINIMIZE BUTTON ]] --
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

--[[ CLOSE BUTTON ]] --
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

--[[ BUTTON CONTAINER ]] --
local ButtonHolder = Instance.new("Frame", MainFrame)
ButtonHolder.Size = UDim2.new(1, -10, 0, 0)
ButtonHolder.Position = UDim2.new(0, 5, 0, 30)
ButtonHolder.BackgroundTransparency = 1
ButtonHolder.AutomaticSize = Enum.AutomaticSize.Y -- Enable automatic Y sizing

local layout = Instance.new("UIListLayout", ButtonHolder)
layout.Padding = UDim.new(0, 5)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

--[[ WATERMARK ]] --
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

--[[ CREATE HYDRATION BUTTON ]] --
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
HydrationBtn.LayoutOrder = 0 -- First button
Instance.new("UIPadding", HydrationBtn).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", HydrationBtn).CornerRadius = UDim.new(0, 6)

--[[ CREATE AUTO COMPLETE BUTTON ]] --
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
AutoTpBtn.LayoutOrder = 1 -- Second button
Instance.new("UIPadding", AutoTpBtn).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", AutoTpBtn).CornerRadius = UDim.new(0, 6)

--[[ CREATE TELEPORT BUTTONS ]] --
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
    btn.LayoutOrder = i + 1 -- Start after Auto Complete button
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 10)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        instantTeleportTo(pos)
    end)
end

-- Add this function to handle proper stopping
local function stopAutoComplete()
    isAutoTeleporting = false
    isAutoJumping = false

    -- Reset character states
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

        if humanoid and rootPart then
            -- Reset all movement states
            rootPart.Anchored = false
            humanoid.PlatformStand = false

            -- Reset velocities
            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.RotVelocity = Vector3.new(0, 0, 0)

            -- Enable all movement states
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            humanoid:ChangeState(Enum.HumanoidStateType.Running)

            -- Make sure character is on the ground
            local currentPosition = rootPart.Position
            local groundPosition = currentPosition - Vector3.new(0, 3, 0)
            rootPart.CFrame = CFrame.new(groundPosition)
        end
    end
end

--[[ BUTTON HANDLERS ]] --
AutoTpBtn.MouseButton1Click:Connect(function()
    if isAutoTeleporting then
        stopAutoComplete() -- Use the new function to stop properly
        AutoTpBtn.Text = "🎯 Auto Complete"
        AutoTpBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 75)

        -- Show notification that auto complete is stopped
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
    stopAutoComplete() -- Make sure to stop properly when closing GUI
    ScreenGui:Destroy()
end)

--[[ HYDRATION SYSTEM ]] --
local function getNearestCamp()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return "BASE"
    end

    local pos = char.HumanoidRootPart.Position

    -- Check if player is at or near SOUTHPOLE
    local southPolePos = teleportPoints["SOUTHPOLE"]
    local distanceToSouthPole = (pos - southPolePos).Magnitude
    if distanceToSouthPole < 500 then -- If within 500 studs of SOUTHPOLE
        return nil -- Return nil to indicate we shouldn't refill
    end

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
    if not character then
        return false
    end

    local waterBottle = character:FindFirstChild("Water Bottle")
    if waterBottle and waterBottle:FindFirstChild("RemoteEvent") then
        waterBottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

local function fillBottleAtCamp(campName)
    -- Store current auto-jump state
    local wasAutoJumping = isAutoJumping

    -- Convert camp name to proper case sensitive format for the remote event
    local properCampName = campNameMapping[campName] or campName

    -- Get the specific fill location for this camp
    local fillLocation = fillBottleLocations[campName]
    if fillLocation then
        -- Temporarily disable auto-jump for refill
        isAutoJumping = false

        -- Ensure water bottle is equipped
        local character = player.Character
        local backpack = player:WaitForChild("Backpack")
        local waterBottle = character:FindFirstChild("Water Bottle") or backpack:FindFirstChild("Water Bottle")

        if waterBottle and waterBottle:IsA("Tool") then
            -- If bottle is in backpack, equip it
            if waterBottle.Parent == backpack then
                local humanoid = character:WaitForChild("Humanoid")
                humanoid:EquipTool(waterBottle)
                wait(0.3) -- Wait for equip animation
            end

            -- Teleport to fill location and perform fill action
            instantTeleportTo(fillLocation)
            wait(0.3)

            -- Fill bottle
            local args = {"FillBottle", properCampName, "Water"}
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("EnergyHydration"):FireServer(unpack(args))
            wait(0.5)

            -- Return to checkpoint immediately after filling
            if teleportPoints[campName] then
                instantTeleportTo(teleportPoints[campName])
            end
        else
            warn("Water Bottle tidak ditemukan di Backpack atau Character!")
        end

        -- Restore previous auto-jump state
        isAutoJumping = wasAutoJumping
        if wasAutoJumping then
            startAutoJump()
        end
    end
end

--[[ INITIALIZE HYDRATION SYSTEM ]] --
spawn(function()
    RunService.RenderStepped:Connect(function()
        if not isAutoHydrationEnabled then
            return
        end

        local hydration = player:GetAttribute("Hydration")
        -- Only proceed if hydration exists and is below threshold
        if hydration then
            -- Add extra check to prevent drinking if hydration is already high
            if hydration >= 99 then
                return -- Skip everything if hydration is already at or near 100%
            end

            if hydration < 50 then -- Only drink when below 50%
                -- Try to drink and check if hydration increases
                local beforeDrinkHydration = hydration
                local drinkSuccess = tryDrink()

                task.wait(0.3) -- Wait for hydration update

                -- Check if drinking actually increased hydration
                local afterDrinkHydration = player:GetAttribute("Hydration")
                local hydrationIncreased = afterDrinkHydration > beforeDrinkHydration

                if hydrationIncreased then
                    -- Keep drinking until we reach near 100%
                    while player:GetAttribute("Hydration") < 99 do
                        local currentHydration = player:GetAttribute("Hydration")
                        local success = tryDrink()

                        task.wait(0.3) -- Wait for hydration update
                        local newHydration = player:GetAttribute("Hydration")

                        -- Exit if we've reached target hydration
                        if newHydration >= 99 then
                            break
                        end

                        -- If hydration didn't increase or drink failed, we need to refill
                        if not success or newHydration <= currentHydration then
                            local nearestCamp = getNearestCamp()
                            if nearestCamp then -- Will be nil if at SOUTHPOLE
                                fillBottleAtCamp(nearestCamp)
                                task.wait(0.3)
                                -- Try drinking again after refill
                                tryDrink()
                            end
                            break -- Exit loop if we're at SOUTHPOLE or drinking failed after refill
                        end

                        task.wait(0.2) -- Small wait between drinks
                    end
                else
                    -- Initial drink didn't increase hydration, try to refill if not at SOUTHPOLE
                    local nearestCamp = getNearestCamp()
                    if nearestCamp then
                        fillBottleAtCamp(nearestCamp)

                        -- After refilling, drink until near 100%
                        task.wait(0.3)
                        while player:GetAttribute("Hydration") < 99 do
                            local currentHydration = player:GetAttribute("Hydration")
                            -- Exit if we've reached target hydration
                            if currentHydration >= 99 then
                                break
                            end

                            local success = tryDrink()
                            task.wait(0.3)
                            local newHydration = player:GetAttribute("Hydration")

                            -- Stop if drink failed or hydration not increasing
                            if not success or newHydration <= currentHydration then
                                break
                            end

                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end)
end)

--[[ INITIALIZE PROTECTION ]] --
spawn(function()
    local player = game.Players.LocalPlayer

    -- Wait for character to load if not already loaded
    if not player.Character then
        player.CharacterAdded:Wait()
    end

    setupAntiFallDamage()

    -- Setup character protection for future respawns
    player.CharacterAdded:Connect(function(char)
        wait(1) -- Wait for character to fully load
        setupAntiFallDamage()

        -- Additional safety: Connect to touched events
        char.DescendantAdded:Connect(function(desc)
            if desc:IsA("Script") and desc.Name:find("Damage") then
                desc:Destroy()
            end
        end)
    end)
end)

--[[ INITIALIZE CHARACTER MOVEMENT ]] --
spawn(function()
    local player = game.Players.LocalPlayer

    -- Fix current character
    if player.Character then
        ensureCharacterCanMove()
    end

    -- Fix future characters
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5) -- Wait for character to fully load
        ensureCharacterCanMove()
    end)

    -- Periodically check and fix movement
    spawn(function()
        while wait(1) do
            if player.Character then
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if rootPart and rootPart.Anchored or (humanoid and humanoid.PlatformStand) then
                    ensureCharacterCanMove()
                end
            end
        end
    end)
end)

--[[ MINIMIZE/MAXIMIZE HANDLER ]] --
MinimizeBtn.MouseButton1Click:Connect(function()
    -- Save current position before minimizing
    local currentPos = MainFrame.Position
    MinimizedFrame.Position = currentPos
    MainFrame.Visible = false
    MinimizedFrame.Visible = true
    MinimizedFrame.Active = true
    MinimizedFrame.Draggable = false -- Disable default dragging
end)

MinimizedLabel.MouseButton1Click:Connect(function()
    -- Save current position before maximizing
    local currentPos = MinimizedFrame.Position
    MainFrame.Position = currentPos
    MainFrame.Visible = true
    MinimizedFrame.Visible = false
end)

-- Enhanced dragging system for MinimizedFrame
local dragging = false
local dragStart = nil
local startPos = nil
local dragInput = nil

-- Make entire MinimizedFrame draggable
local function updateDrag(input)
    if dragging then
        local delta = input.Position - dragStart
        MinimizedFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale,
            startPos.Y.Offset + delta.Y)
    end
end

MinimizedFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- Function to update positions between frames
local function updatePosition(from, to)
    from.Changed:Connect(function(property)
        if property == "Position" and from.Visible then
            to.Position = from.Position
        end
    end)
end

-- Keep positions synced between frames
updatePosition(MainFrame, MinimizedFrame)
updatePosition(MinimizedFrame, MainFrame)

--[[ SET MAIN FRAME WIDTH ]] --
MainFrame.Size = UDim2.new(0, 180, 0, 0) -- Width fixed, height automatic

--[[ UPDATE WATERMARK POSITION ]] --
spawn(function()
    while wait() do
        if MainFrame.Visible then
            local totalHeight = ButtonHolder.AbsoluteSize.Y + 50 -- 30 for title + 20 for watermark
            Watermark.Position = UDim2.new(0, 0, 0, totalHeight)
        end
    end
end)
