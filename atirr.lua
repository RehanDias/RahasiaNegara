-- ambil service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("ActionRemote")
local Players = game:GetService("Players")
local player = Players.LocalPlayer


local actions = {
    "Burpee",
    "Situps",
    "Jumping Jack",
    "Think Hard",
    "Aura Farm"
}

local delayTime = 60 -- detik per action
local farming = false
local mode = "Idle" -- "Manual" atau "Auto"

-- GUI utama
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 270)
mainFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- judul
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 30)
title.Position = UDim2.new(0, 10, 0, 5)
title.Text = "Farming Menu"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- label mode
local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, -20, 0, 20)
modeLabel.Position = UDim2.new(0, 10, 0, 35)
modeLabel.Text = "Mode: "..mode
modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.SourceSans
modeLabel.TextSize = 16
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = mainFrame

-- tombol close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = mainFrame

-- tombol minimize
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -70, 0, 5)
minimizeBtn.Text = "-"
minimizeBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
minimizeBtn.TextColor3 = Color3.new(1,1,1)
minimizeBtn.Parent = mainFrame

-- scroll list actions
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -20, 0, 100)
scrollingFrame.Position = UDim2.new(0, 10, 0, 60)
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #actions * 30)
scrollingFrame.ScrollBarThickness = 6
scrollingFrame.BackgroundTransparency = 0.3
scrollingFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
scrollingFrame.Parent = mainFrame

-- daftar tombol action manual
local actionButtons = {}
for i, act in ipairs(actions) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 25)
    btn.Position = UDim2.new(0, 5, 0, (i-1) * 30)
    btn.Text = act
    btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = scrollingFrame
    actionButtons[#actionButtons+1] = btn
end

-- input delay time (DIBUAT DI ATAS START/STOP)
local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0.5, -15, 0, 25)
delayLabel.Position = UDim2.new(0, 10, 0, 170)
delayLabel.Text = "Delay (detik):"
delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
delayLabel.BackgroundTransparency = 1
delayLabel.Font = Enum.Font.SourceSans
delayLabel.TextSize = 16
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = mainFrame

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.new(0.5, -15, 0, 25)
delayBox.Position = UDim2.new(0.5, 5, 0, 170)
delayBox.Text = tostring(delayTime)
delayBox.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
delayBox.TextColor3 = Color3.new(1,1,1)
delayBox.ClearTextOnFocus = false
delayBox.Font = Enum.Font.SourceSans
delayBox.TextSize = 16
delayBox.Parent = mainFrame

delayBox.FocusLost:Connect(function(enterPressed)
    local val = tonumber(delayBox.Text)
    if val and val > 0 then
        delayTime = val
        print("DelayTime diubah menjadi:", delayTime)
    else
        delayBox.Text = tostring(delayTime)
    end
end)

-- tombol start/stop
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.5, -15, 0, 40)
startBtn.Position = UDim2.new(0, 10, 1, -50)
startBtn.Text = "START"
startBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Parent = mainFrame

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0.5, -15, 0, 40)
stopBtn.Position = UDim2.new(0.5, 5, 1, -50)
stopBtn.Text = "STOP"
stopBtn.BackgroundColor3 = Color3.fromRGB(120,120,120)
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Parent = mainFrame

-- fungsi untuk update tombol manual
local function setManualButtonsEnabled(enabled)
    for _, btn in ipairs(actionButtons) do
        btn.Active = enabled
        btn.AutoButtonColor = enabled
        btn.BackgroundColor3 = enabled and Color3.fromRGB(80,80,80) or Color3.fromRGB(40,40,40)
    end
end

-- fake gerakan dengan lompat beneran
local function fakeMove()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        task.wait(0.1)
    end
end

-- transisi sebelum action baru (khusus AUTO)
local function playTransition(newAction)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        repeat task.wait() until humanoid:GetState() == Enum.HumanoidStateType.Freefall
        repeat task.wait() until humanoid:GetState() == Enum.HumanoidStateType.Landed 
            or humanoid:GetState() == Enum.HumanoidStateType.Running 
            or humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics
        task.wait(0.2)
    end
    remote:FireServer(newAction)
end

-- fungsi farming AUTO
local function startFarming()
    if farming then return end
    farming = true
    mode = "Auto"
    modeLabel.Text = "Mode: "..mode
    startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    setManualButtonsEnabled(false)
    local first = true
    while farming do
        for _, action in ipairs(actions) do
            if not farming then break end
            if first then
                remote:FireServer(action)
                first = false
            else
                playTransition(action)
            end
            print("Action baru (Auto):", action)
            task.wait(delayTime)
        end
    end
end

-- fungsi stop farming
local function stopFarming()
    farming = false
    mode = "Idle"
    modeLabel.Text = "Mode: "..mode
    startBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    fakeMove()
    print("Farming dihentikan.")
    setManualButtonsEnabled(true)
    startBtn.Active = true
    startBtn.AutoButtonColor = true
end

-- koneksi tombol action MANUAL
for i, act in ipairs(actions) do
    local btn = actionButtons[i]
    btn.MouseButton1Click:Connect(function()
        if farming then return end
        mode = "Manual"
        modeLabel.Text = "Mode: "..mode
        startBtn.Active = false
        startBtn.AutoButtonColor = false
        startBtn.BackgroundColor3 = Color3.fromRGB(100,0,0)
        remote:FireServer(act)
        print("Manual Action:", act)
    end)
end

-- koneksi tombol utama
startBtn.MouseButton1Click:Connect(startFarming)
stopBtn.MouseButton1Click:Connect(stopFarming)

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

minimizeBtn.MouseButton1Click:Connect(function()
    local isVisible = scrollingFrame.Visible
    scrollingFrame.Visible = not isVisible
    startBtn.Visible = not isVisible
    stopBtn.Visible = not isVisible
    modeLabel.Visible = not isVisible
    delayLabel.Visible = not isVisible
    delayBox.Visible = not isVisible
    mainFrame.Size = scrollingFrame.Visible and UDim2.new(0,300,0,270) or UDim2.new(0,300,0,40)
end)
