--===========================--
--[[       SERVICES         ]]--
--===========================--
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")

--===========================--
--[[       WIND UI          ]]--
--===========================--
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local function Notify(title, content, duration)
    WindUI:Notify({
        Title    = title,
        Content  = content,
        Duration = duration or 3,
        Icon     = "info",
    })
end

--===========================--
--[[      CONSTANTS         ]]--
--===========================--
local player              = Players.LocalPlayer
local HYDRATION_THRESHOLD = 50
local HYDRATION_MAX       = 99
local SOUTHPOLE_RADIUS    = 500
local SAFE_HEIGHT         = 5
local ABOVE_HEIGHT        = 10
local TERRAIN_TIMEOUT     = 5

--===========================--
--[[    TELEPORT DATA       ]]--
--===========================--
local teleportPoints = {
    BASE      = Vector3.new(-6016.00,  -159.00,   -28.57),
    CAMP1     = Vector3.new(-3720.19,   225.00,   235.91),
    CAMP2     = Vector3.new( 1790.79,   105.45,  -136.89),
    CAMP3     = Vector3.new( 5891.24,   321.00,   -18.60),
    CAMP4     = Vector3.new( 8992.07,   595.59,   103.63),
    SOUTHPOLE = Vector3.new(10993.19,   549.13,   100.13),
}

local fillBottleLocations = {
    BASE  = Vector3.new(-6042.84, -158.95,  -59.00),
    CAMP1 = Vector3.new(-3718.06,  228.94,  261.38),
    CAMP2 = Vector3.new( 1799.14,  105.37, -161.86),
    CAMP3 = Vector3.new( 5885.90,  321.00,    4.62),
    CAMP4 = Vector3.new( 9000.03,  597.40,   88.02),
}

local campNameMapping = {
    BASE  = "BaseCamp",
    CAMP1 = "Camp1",
    CAMP2 = "Camp2",
    CAMP3 = "Camp3",
    CAMP4 = "Camp4",
}

local checkpointOrder   = { "CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE" }
local campButtonOrder   = { "BASE", "CAMP1", "CAMP2", "CAMP3", "CAMP4", "SOUTHPOLE" }

--===========================--
--[[      STATE FLAGS       ]]--
--===========================--
local currentCheckpoint      = 1
local isAutoTeleporting      = false
local isAutoJumping          = false
local isAutoHydrationEnabled = true
local validatedPositions     = {}

--===========================--
--[[      UTILITIES         ]]--
--===========================--

-- Kembalikan (humanoid, rootPart) dari karakter saat ini
local function getCharParts()
    local char = player.Character
    if not char then return nil, nil end
    return char:FindFirstChild("Humanoid"),
           char:FindFirstChild("HumanoidRootPart")
end

--===========================--
--[[ FIND NEAREST CHECKPOINT]]--
--===========================--
local function findNearestCheckpoint()
    local _, rootPart = getCharParts()
    if not rootPart then return 1 end

    local pos         = rootPart.Position
    local nearestDist = math.huge
    local nearestIdx  = 1

    for i, name in ipairs(checkpointOrder) do
        local dist = (pos - teleportPoints[name]).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestIdx  = i
        end
    end
    return nearestIdx
end

--===========================--
--[[      AUTO JUMP         ]]--
--===========================--
local function startAutoJump()
    task.spawn(function()
        while isAutoJumping do
            local humanoid = getCharParts()
            if humanoid then
                humanoid.Jump = true
            end
            task.wait(0.5)
        end
    end)
end

--===========================--
--[[   ANTI FALL DAMAGE     ]]--
--===========================--
local function removeDamageScripts(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Script") then
            local n = child.Name
            if n:find("Fall") or n:find("Damage") or n:find("freeze") or n:find("Water") then
                child:Destroy()
            end
        end
    end
end

local function setupAntiFallDamage()
    local function protectChar(char)
        if not char then return end

        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end

        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying,      true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics,     false)

        -- Blokir pengurangan HP tapi izinkan kematian (Health = 0)
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth and health > 0 then
                humanoid.Health = lastHealth
            end
            lastHealth = health
        end)

        -- Hapus script damage baru yang ditambahkan
        char.ChildAdded:Connect(function(child)
            if child:IsA("Script") then
                local n = child.Name
                if n:find("Fall") or n:find("Damage") or n:find("freeze") or n:find("Water") then
                    task.wait()
                    child:Destroy()
                end
            end
        end)

        removeDamageScripts(char)
    end

    if player.Character then protectChar(player.Character) end
    player.CharacterAdded:Connect(protectChar)
end

--===========================--
--[[ ENSURE CHARACTER MOVES ]]--
--===========================--
local function ensureCharacterCanMove()
    local humanoid, rootPart = getCharParts()
    if not humanoid or not rootPart then return end

    rootPart.Anchored                 = false
    humanoid.PlatformStand            = false
    rootPart.AssemblyLinearVelocity   = Vector3.zero
    rootPart.AssemblyAngularVelocity  = Vector3.zero

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,   true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,  true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,   true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,  true)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
end

--===========================--
--[[    WAIT FOR TERRAIN    ]]--
--===========================--
-- Pakai workspace:Raycast() — Ray.new() sudah deprecated
local function waitForTerrain(position)
    local origin    = position + Vector3.new(0, ABOVE_HEIGHT, 0)
    local direction = Vector3.new(0, -(ABOVE_HEIGHT * 2), 0)
    local startTime = os.clock()

    while os.clock() - startTime < TERRAIN_TIMEOUT do
        if workspace:Raycast(origin, direction) then return true end
        task.wait(0.1)
    end
    return false
end

--===========================--
--[[   INSTANT TELEPORT     ]]--
--===========================--
local function instantTeleportTo(position)
    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local humanoid, rootPart
    local tries = 0
    repeat
        humanoid, rootPart = getCharParts()
        if not rootPart then task.wait(0.1) end
        tries += 1
    until rootPart or tries >= 10

    if not rootPart then
        warn("[Arcan1ST] Gagal mendapat HumanoidRootPart")
        return
    end

    rootPart.AssemblyLinearVelocity  = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    local posKey = ("%d,%d,%d"):format(
        math.floor(position.X),
        math.floor(position.Y),
        math.floor(position.Z)
    )

    if not validatedPositions[posKey] then
        rootPart.Anchored = true
        rootPart.CFrame   = CFrame.new(position + Vector3.new(0, ABOVE_HEIGHT, 0))

        local loaded = waitForTerrain(position)
        if loaded then
            validatedPositions[posKey] = true
        else
            warn("[Arcan1ST] Terrain belum terload sepenuhnya, melanjutkan...")
        end

        rootPart.CFrame = CFrame.new(position + Vector3.new(0, SAFE_HEIGHT, 0))
        task.wait(0.2)
        ensureCharacterCanMove()
    else
        rootPart.CFrame = CFrame.new(position + Vector3.new(0, SAFE_HEIGHT, 0))
        task.wait(0.1)
        ensureCharacterCanMove()
    end
end

--===========================--
--[[       RESPAWN          ]]--
--===========================--
local function respawnCharacter()
    local humanoid = getCharParts()
    if humanoid then humanoid.Health = 0 end
end

--===========================--
--[[   STOP AUTO COMPLETE   ]]--
--===========================--
local function stopAutoComplete()
    isAutoTeleporting = false
    isAutoJumping     = false

    local humanoid, rootPart = getCharParts()
    if humanoid and rootPart then
        rootPart.Anchored                 = false
        humanoid.PlatformStand            = false
        rootPart.AssemblyLinearVelocity   = Vector3.zero
        rootPart.AssemblyAngularVelocity  = Vector3.zero

        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running,   true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,  true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,   true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,  true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)

        rootPart.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 3, 0))
    end

    Notify("Auto Complete", "Stopped ⏹", 2)
end

--===========================--
--[[   START AUTO TELEPORT  ]]--
--===========================--
local function startAutoTeleport()
    if isAutoTeleporting then return end

    currentCheckpoint = findNearestCheckpoint()
    isAutoTeleporting = true
    isAutoJumping     = true
    startAutoJump()

    task.spawn(function()
        while isAutoTeleporting do
            if currentCheckpoint <= #checkpointOrder then
                instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
                task.wait(0.5)
            else
                task.wait(1)
                respawnCharacter()
                task.wait(3)

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

--===========================--
--[[ CHECKPOINT DETECTION   ]]--
--===========================--
ReplicatedStorage:WaitForChild("Message_Remote").OnClientEvent:Connect(function(message)
    if type(message) ~= "string" then return end

    if message:find("You have made it to South Pole") then
        if not isAutoTeleporting then
            Notify("Arcan1STHub", "Journey Completed! 🎉", 3)
            return
        end

        Notify("Arcan1STHub", "South Pole Reached! 🎯", 2)
        task.wait(1)
        respawnCharacter()
        task.wait(3)

        if isAutoTeleporting then
            currentCheckpoint = 1
            task.wait(0.5)
            instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
            Notify("Arcan1STHub", "Restarting from CAMP1! 🔄", 3)
        end

        isAutoJumping = isAutoTeleporting

    elseif message:find("You have made it to Camp") then
        if not isAutoTeleporting then return end

        Notify("Arcan1STHub", "Checkpoint Completed! ⭐", 2)
        currentCheckpoint += 1

        if currentCheckpoint <= #checkpointOrder then
            task.wait(0.5)
            instantTeleportTo(teleportPoints[checkpointOrder[currentCheckpoint]])
        end
    end
end)

--===========================--
--[[   HYDRATION SYSTEM     ]]--
--===========================--
local function getNearestCamp()
    local _, rootPart = getCharParts()
    if not rootPart then return "BASE" end

    local pos = rootPart.Position

    -- Di sekitar SOUTHPOLE → tidak perlu refill
    if (pos - teleportPoints.SOUTHPOLE).Magnitude < SOUTHPOLE_RADIUS then
        return nil
    end

    local closestCamp  = nil
    local shortestDist = math.huge

    for campName, campPos in pairs(teleportPoints) do
        if campName ~= "SOUTHPOLE" then
            local dist = (pos - campPos).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                closestCamp  = campName
            end
        end
    end
    return closestCamp
end

local function tryDrink()
    local char = player.Character
    if not char then return false end

    local bottle = char:FindFirstChild("Water Bottle")
    if bottle and bottle:FindFirstChild("RemoteEvent") then
        bottle.RemoteEvent:FireServer()
        return true
    end
    return false
end

local function fillBottleAtCamp(campName)
    local fillLocation = fillBottleLocations[campName]
    if not fillLocation then return end

    local wasAutoJumping = isAutoJumping
    isAutoJumping = false

    local char     = player.Character
    local backpack = player:WaitForChild("Backpack")
    local bottle   = (char and char:FindFirstChild("Water Bottle"))
                  or backpack:FindFirstChild("Water Bottle")

    if bottle and bottle:IsA("Tool") then
        if bottle.Parent == backpack then
            local humanoid = char:WaitForChild("Humanoid")
            humanoid:EquipTool(bottle)
            task.wait(0.3)
        end

        instantTeleportTo(fillLocation)
        task.wait(0.3)

        local properName = campNameMapping[campName] or campName
        -- Pakai table.unpack (unpack() sudah deprecated)
        ReplicatedStorage:WaitForChild("Events")
            :WaitForChild("EnergyHydration")
            :FireServer(table.unpack({ "FillBottle", properName, "Water" }))
        task.wait(0.5)

        if teleportPoints[campName] then
            instantTeleportTo(teleportPoints[campName])
        end
    else
        warn("[Arcan1ST] Water Bottle tidak ditemukan!")
    end

    isAutoJumping = wasAutoJumping
    if wasAutoJumping then startAutoJump() end
end

-- Auto Hydration — loop biasa, bukan RenderStepped (jauh lebih efisien)
task.spawn(function()
    while true do
        task.wait(0.5)

        if not isAutoHydrationEnabled then continue end

        local hydration = player:GetAttribute("Hydration")
        if not hydration or hydration >= HYDRATION_MAX then continue end
        if hydration >= HYDRATION_THRESHOLD then continue end

        local before = player:GetAttribute("Hydration")
        tryDrink()
        task.wait(0.3)

        local after = player:GetAttribute("Hydration")

        if after > before then
            -- Botol masih ada isinya, terus minum
            while (player:GetAttribute("Hydration") or 0) < HYDRATION_MAX do
                local cur     = player:GetAttribute("Hydration")
                local success = tryDrink()
                task.wait(0.3)
                local new = player:GetAttribute("Hydration")

                if new >= HYDRATION_MAX then break end
                if not success or new <= cur then
                    local camp = getNearestCamp()
                    if camp then
                        fillBottleAtCamp(camp)
                        task.wait(0.3)
                        tryDrink()
                    end
                    break
                end
                task.wait(0.2)
            end
        else
            -- Botol kosong → isi dulu
            local camp = getNearestCamp()
            if not camp then continue end

            fillBottleAtCamp(camp)
            task.wait(0.3)

            while (player:GetAttribute("Hydration") or 0) < HYDRATION_MAX do
                local cur     = player:GetAttribute("Hydration")
                local success = tryDrink()
                task.wait(0.3)
                local new = player:GetAttribute("Hydration")
                if not success or new <= cur then break end
                task.wait(0.2)
            end
        end
    end
end)

--===========================--
--[[    INITIALIZATION      ]]--
--===========================--

-- Anti fall damage
task.spawn(function()
    if not player.Character then player.CharacterAdded:Wait() end
    setupAntiFallDamage()

    player.CharacterAdded:Connect(function(char)
        task.wait(1)
        setupAntiFallDamage()
        char.DescendantAdded:Connect(function(desc)
            if desc:IsA("Script") and desc.Name:find("Damage") then
                desc:Destroy()
            end
        end)
    end)
end)

-- Pastikan karakter bisa bergerak
task.spawn(function()
    if player.Character then ensureCharacterCanMove() end

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        ensureCharacterCanMove()
    end)

    task.spawn(function()
        while true do
            task.wait(1)
            local _, rootPart = getCharParts()
            local humanoid    = getCharParts()
            if rootPart and (rootPart.Anchored or (humanoid and humanoid.PlatformStand)) then
                ensureCharacterCanMove()
            end
        end
    end)
end)

--===========================--
--[[      WIND UI WINDOW    ]]--
--===========================--
local Window = WindUI:CreateWindow({
    Title       = "Arcan1ST Hub",
    Icon        = "snowflake",
    Author      = "@Arcan1ST_",
    Folder      = "Arcan1ST-Antarctica",
    Transparent = true,
    Theme       = "Dark",
})

--===========================--
--[[   TAB: AUTOMATION      ]]--
--===========================--
local AutoTab = Window:AddTab({
    Title = "Automation",
    Icon  = "bot",
})

AutoTab:AddParagraph({
    Title   = "Expedition Status",
    Content = "Gunakan fitur ini untuk menyelesaikan perjalanan secara otomatis.",
})

AutoTab:AddToggle({
    Title       = "Auto Complete Journey",
    Description = "Auto teleport dari Camp ke Camp hingga South Pole.",
    Value       = false,
    Callback    = function(state)
        if state then
            startAutoTeleport()
        else
            stopAutoComplete()
        end
    end,
})

AutoTab:AddToggle({
    Title       = "Auto Hydration",
    Description = "Auto minum & isi ulang air ketika hydration < 50%.",
    Value       = true,
    Callback    = function(state)
        isAutoHydrationEnabled = state
        if state then
            Notify("Hydration", "Auto Hydration Enabled 💧", 2)
        else
            Notify("Hydration", "Auto Hydration Disabled ⏸", 2)
        end
    end,
})

--===========================--
--[[   TAB: TELEPORTS       ]]--
--===========================--
local TeleportTab = Window:AddTab({
    Title = "Teleports",
    Icon  = "map-pin",
})

TeleportTab:AddParagraph({
    Title   = "Manual Teleport",
    Content = "Klik tombol di bawah untuk langsung berpindah lokasi.",
})

for _, campName in ipairs(campButtonOrder) do
    TeleportTab:AddButton({
        Title    = "Teleport to " .. campName,
        Icon     = "map-pin",
        Callback = function()
            instantTeleportTo(teleportPoints[campName])
            Notify("Teleport", "Pergi ke " .. campName .. "...", 2)
        end,
    })
end

--===========================--
--[[   TAB: SETTINGS        ]]--
--===========================--
local MiscTab = Window:AddTab({
    Title = "Settings",
    Icon  = "settings",
})

MiscTab:AddButton({
    Title    = "Respawn Character",
    Icon     = "skull",
    Callback = function()
        respawnCharacter()
        Notify("Respawn", "Karakter di-respawn...", 2)
    end,
})

MiscTab:AddButton({
    Title       = "Fix Movement",
    Description = "Klik jika karakter stuck atau frozen.",
    Icon        = "activity",
    Callback    = function()
        ensureCharacterCanMove()
        Notify("Fix", "Movement berhasil di-reset ✅", 2)
    end,
})

MiscTab:AddButton({
    Title       = "Clear Teleport Cache",
    Description = "Reset cache validasi posisi jika ada masalah teleport.",
    Icon        = "trash-2",
    Callback    = function()
        validatedPositions = {}
        Notify("Cache", "Teleport cache di-reset ✅", 2)
    end,
})

--===========================--
Notify("Arcan1ST Hub", "Script berhasil dimuat! ❄️", 5)
