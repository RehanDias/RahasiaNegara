local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local function Notify(title, content, duration)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
        Icon = "info"
    })
end

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
    local player = game.Players.LocalPlayer
    if not player then
        return 1
    end

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
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or
                    child.Name:find("Water") then
                    task.wait()
                    child:Destroy()
                end
            end
        end)

        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Script") then
                if child.Name:find("Fall") or child.Name:find("Damage") or child.Name:find("freeze") or
                    child.Name:find("Water") then
                    child:Destroy()
                end
            end
        end
    end

    if player.Character then
        protectFromDamage(player.Character)
    end

    player.CharacterAdded:Connect(protectFromDamage)
end

local function waitForTerrain(position)
    local terrain = workspace.Terrain
    local radius = 100

    local startTime = tick()
    local timeout = 5

    while tick() - startTime < timeout do
        local blockFound = false

        local ray = Ray.new(position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))
        local hit, hitPosition = workspace:FindPartOnRay(ray)

        if hit then
            return true
        end

        task.wait(0.1)
    end

    return false
end

local function ensureCharacterCanMove()
    local player = game.Players.LocalPlayer
    if not player or not player.Character then
        return
    end

    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

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

local function instantTeleportTo(position)
    local player = game.Players.LocalPlayer
    if not player then
        return
    end

    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local char = player.Character
    if not char then
        return
    end

    local tries = 0
    while tries < 10 do
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            local posKey = tostring(math.floor(position.X)) .. "," .. tostring(math.floor(position.Y)) .. "," ..
                               tostring(math.floor(position.Z))

            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.RotVelocity = Vector3.new(0, 0, 0)

            if not validatedPositions[posKey] then
                rootPart.Anchored = true

                local safeHeight = 10
                local initialPos = position + Vector3.new(0, safeHeight, 0)
                rootPart.CFrame = CFrame.new(initialPos)

                local terrainLoaded = waitForTerrain(position)

                if terrainLoaded then
                    validatedPositions[posKey] = true

                    local finalPosition = position + Vector3.new(0, 5, 0)
                    rootPart.CFrame = CFrame.new(finalPosition)

                    task.wait(0.2)
                    ensureCharacterCanMove()
                else
                    warn("Terrain tidak terload sepenuhnya")
                    ensureCharacterCanMove()
                end
            else
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

local function respawnCharacter()
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
    end
end

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
                wait(1)
                respawnCharacter()
                wait(3)
                if isAutoTeleporting then
                    currentCheckpoint = 1
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])

                    Notify("Arcan1ST Script", "Restarting from CAMP1! 🔄", 3)
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
                Notify("Arcan1STHub", "South Pole Reached! 🎯", 2)

                wait(1)
                respawnCharacter()
                wait(3)

                if isAutoTeleporting then
                    currentCheckpoint = 1
                    wait(0.5)
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                    Notify("Arcan1STHub", "Restarting from CAMP1! 🔄", 3)
                else
                    Notify("Arcan1STHub", "Journey Completed! 🎉", 3)
                end

                isAutoJumping = not isAutoTeleporting
            end
        elseif message:find("You have made it to Camp") then
            if isAutoTeleporting then
                Notify("Arcan1STHub", "Checkpoint Completed! ⭐", 2)

                currentCheckpoint = currentCheckpoint + 1
                if currentCheckpoint <= #checkpointOrder then
                    wait(0.5)
                    instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                end
            end
        end
    end
end)

local function stopAutoComplete()
    isAutoTeleporting = false
    isAutoJumping = false

    local player = game.Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

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
    
    Notify("Auto Complete", "Stopped ⏹", 2)
end

local function getNearestCamp()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return "BASE"
    end

    local pos = char.HumanoidRootPart.Position

    local southPolePos = teleportPoints["SOUTHPOLE"]
    local distanceToSouthPole = (pos - southPolePos).Magnitude
    if distanceToSouthPole < 500 then
        return nil
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

            instantTeleportTo(fillLocation)
            task.wait(0.3)

            local args = {"FillBottle", properCampName, "Water"}
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("EnergyHydration"):FireServer(unpack(args))
            task.wait(0.5)

            if teleportPoints[campName] then
                instantTeleportTo(teleportPoints[campName])
            end
        else
            warn("Water Bottle tidak ditemukan di Backpack atau Character!")
        end

        isAutoJumping = wasAutoJumping
        if wasAutoJumping then
            startAutoJump()
        end
    end
end

task.spawn(function()
    RunService.RenderStepped:Connect(function()
        if not isAutoHydrationEnabled then
            return
        end

        local hydration = player:GetAttribute("Hydration")
        if hydration then
            if hydration >= 99 then
                return
            end

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

                        if newHydration >= 99 then
                            break
                        end

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
                            if currentHydration >= 99 then
                                break
                            end

                            local success = tryDrink()
                            task.wait(0.3)
                            local newHydration = player:GetAttribute("Hydration")
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

task.spawn(function()
    local player = game.Players.LocalPlayer

    if not player.Character then
        player.CharacterAdded:Wait()
    end

    setupAntiFallDamage()

    player.CharacterAdded:Connect(function(char)
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
    local player = game.Players.LocalPlayer

    if player.Character then
        ensureCharacterCanMove()
    end

    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        ensureCharacterCanMove()
    end)

    task.spawn(function()
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

local Window = WindUI:CreateWindow({
    Title = "Arcan1ST Hub",
    Icon = "snowflake",
    Author = "@Arcan1ST_",
    Folder = "Arcan1ST-Antarctica",
    Transparent = true,
    Theme = "Dark"
})

local AutoTab = Window:AddTab({
    Title = "Automation",
    Icon = "bot"
})

AutoTab:AddParagraph({
    Title = "Expedition Status",
    Content = "Use these features to complete the journey automatically."
})

AutoTab:AddToggle({
    Title = "Auto Complete Journey",
    Description = "Auto teleport from Camp to Camp until South Pole.",
    Value = false,
    Callback = function(state)
        if state then
            startAutoTeleport()
        else
            stopAutoComplete()
        end
    end
})

AutoTab:AddToggle({
    Title = "Auto Hydration",
    Description = "Auto drink & refill water when < 50%.",
    Value = true,
    Callback = function(state)
        isAutoHydrationEnabled = state
        if state then
            Notify("Hydration", "Auto Hydration Enabled 💧", 2)
        else
            Notify("Hydration", "Auto Hydration Disabled", 2)
        end
    end
})

local TeleportTab = Window:AddTab({
    Title = "Teleports",
    Icon = "map-pin"
})

TeleportTab:AddParagraph({
    Title = "Manual Teleport",
    Content = "Click the buttons below to instantly teleport."
})

local camps = {"BASE", "CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE"}
for _, campName in ipairs(camps) do
    TeleportTab:AddButton({
        Title = "Teleport to " .. campName,
        Icon = "map-pin",
        Callback = function()
            instantTeleportTo(teleportPoints[campName])
            Notify("Teleport", "Going to " .. campName, 2)
        end
    })
end

local MiscTab = Window:AddTab({
    Title = "Settings",
    Icon = "settings"
})

MiscTab:AddButton({
    Title = "Respawn Character",
    Icon = "skull",
    Callback = function()
        respawnCharacter()
        Notify("Respawn", "Respawning character...", 2)
    end
})

MiscTab:AddButton({
    Title = "Fix Movement",
    Description = "Click if character is stuck/frozen.",
    Icon = "activity",
    Callback = function()
        ensureCharacterCanMove()
        Notify("Fix", "Movement reset successfully.", 2)
    end
})

Notify("Arcan1ST Hub", "Script Loaded Successfully! ❄️", 5)
