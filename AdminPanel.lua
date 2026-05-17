--[[
    Climb and Slide :: Premium Admin Panel
    UI Framework: Rayfield (Sirius)
    Execution: Roblox Developer Console / executor
    Single-file, production-ready, mobile + PC supported.
--]]

------------------------------------------------------------
-- 0. Prevent duplicate execution
------------------------------------------------------------
if _G.__CS_AdminPanel_Loaded then
    pcall(function() _G.__CS_AdminPanel_Cleanup() end)
end
_G.__CS_AdminPanel_Loaded = true

------------------------------------------------------------
-- 1. Services & locals
------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local PLACE_ID = game.PlaceId
local JOB_ID   = game.JobId

------------------------------------------------------------
-- 2. State container (single source of truth)
------------------------------------------------------------
local State = {
    AutoMoney         = false,
    AutoMoneyInterval = 0.15,
    InfiniteJump      = false,
    Noclip            = false,
    Fly               = false,
    FlySpeed          = 60,
    AntiAFK           = false,
    FPSBoost          = false,
    WalkSpeed         = 16,
    JumpPower         = 50,

    Connections   = {},
    AntiAFKConn   = nil,
    FPSDefaults   = {},
    BlurInstance  = nil,
    IntroGui      = nil,
    FlyConn       = nil,
    FlyBV         = nil,
    FlyBG         = nil,
}

local function trackConn(key, conn)
    if State.Connections[key] then
        pcall(function() State.Connections[key]:Disconnect() end)
    end
    State.Connections[key] = conn
end

------------------------------------------------------------
-- 3. Character helpers
------------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

local function applyWalkSpeed(v)
    State.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end

local function applyJumpPower(v)
    State.JumpPower = v
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    task.wait(0.1)
    hum.WalkSpeed = State.WalkSpeed
    hum.UseJumpPower = true
    hum.JumpPower = State.JumpPower
end)

------------------------------------------------------------
-- 4. Intro / loading animation with blur
------------------------------------------------------------
local function showIntro()
    local intro = Instance.new("ScreenGui")
    intro.Name = "CS_AdminIntro"
    intro.IgnoreGuiInset = true
    intro.ResetOnSpawn = false
    intro.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    intro.DisplayOrder = 9999
    intro.Parent = (gethui and gethui()) or CoreGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    bg.BorderSizePixel = 0
    bg.BackgroundTransparency = 1
    bg.Parent = intro

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(360, 120)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.Parent = intro

    local corner = Instance.new("UICorner", card)
    corner.CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke", card)
    stroke.Color = Color3.fromRGB(0, 220, 255)
    stroke.Thickness = 1.4
    stroke.Transparency = 1

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -24, 0, 32)
    title.Position = UDim2.fromOffset(12, 14)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "CLIMB & SLIDE"
    title.TextTransparency = 1
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, -24, 0, 18)
    sub.Position = UDim2.fromOffset(12, 46)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextColor3 = Color3.fromRGB(150, 200, 255)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "Premium hub loading..."
    sub.TextTransparency = 1
    sub.Parent = card

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(1, -24, 0, 6)
    barBack.Position = UDim2.new(0, 12, 1, -22)
    barBack.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
    barBack.BorderSizePixel = 0
    barBack.BackgroundTransparency = 1
    barBack.Parent = card
    Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = Lighting
    State.BlurInstance = blur

    local quick = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(bg,    quick, {BackgroundTransparency = 0.25}):Play()
    TweenService:Create(card,  quick, {BackgroundTransparency = 0}):Play()
    TweenService:Create(stroke,quick, {Transparency = 0}):Play()
    TweenService:Create(title, quick, {TextTransparency = 0}):Play()
    TweenService:Create(sub,   quick, {TextTransparency = 0}):Play()
    TweenService:Create(barBack, quick, {BackgroundTransparency = 0}):Play()
    TweenService:Create(blur,  quick, {Size = 18}):Play()

    TweenService:Create(barFill,
        TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = UDim2.new(1, 0, 1, 0)}
    ):Play()

    State.IntroGui = intro
    task.wait(1.55)

    local fadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(bg,    fadeInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(card,  fadeInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(stroke,fadeInfo, {Transparency = 1}):Play()
    TweenService:Create(title, fadeInfo, {TextTransparency = 1}):Play()
    TweenService:Create(sub,   fadeInfo, {TextTransparency = 1}):Play()
    TweenService:Create(barBack,fadeInfo,{BackgroundTransparency = 1}):Play()
    TweenService:Create(barFill,fadeInfo,{BackgroundTransparency = 1}):Play()
    local blurOut = TweenService:Create(blur, fadeInfo, {Size = 0})
    blurOut:Play()
    blurOut.Completed:Wait()
    intro:Destroy()
    blur:Destroy()
    State.IntroGui = nil
    State.BlurInstance = nil
end

------------------------------------------------------------
-- 5. Load Rayfield
------------------------------------------------------------
showIntro()

-- Try multiple Rayfield sources; sirius.menu has been serving a broken build
-- ("Template is not a valid member of Frame 'Notifications'"), so we fall
-- back to the official GitHub raw URL and a mirror.
local RAYFIELD_SOURCES = {
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}

local Rayfield, lastErr
for _, url in ipairs(RAYFIELD_SOURCES) do
    local ok, errOrLib = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and errOrLib then
        Rayfield = errOrLib
        break
    else
        lastErr = errOrLib
    end
end

if not Rayfield then
    warn("[CS Admin] Failed to load Rayfield from any source: " .. tostring(lastErr))
    return
end

------------------------------------------------------------
-- 6. Window
------------------------------------------------------------
local Window = Rayfield:CreateWindow({
    Name              = "Climb & Slide  •  Premium Hub",
    Icon              = 0,
    LoadingTitle      = "Climb & Slide",
    LoadingSubtitle   = "by velocruel",
    Theme             = "Amethyst",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = true,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "CS_PremiumHub",
        FileName   = "Config_" .. tostring(PLACE_ID)
    },
    Discord = { Enabled = false, Invite = "", RememberJoins = true },
    KeySystem = false,
    KeySettings = {
        Title    = "Climb & Slide",
        Subtitle = "Key System",
        Note     = "Enter your access key",
        FileName = "CS_Key",
        SaveKey  = true,
        GrabKeyFromSite = false,
        Key = { "climbandslide" }
    },
})

-- Rayfield's :Notify can throw if its internal Notifications template is
-- missing (CDN ships a bad build occasionally). Wrap in pcall so a notif
-- failure never breaks a callback.
local function notify(title, content, duration, image)
    pcall(function()
        Rayfield:Notify({
            Title    = title or "Climb & Slide",
            Content  = content or "",
            Duration = duration or 4,
            Image    = image or 4483362458,
        })
    end)
end

------------------------------------------------------------
-- 7. Tabs
------------------------------------------------------------
local MainTab     = Window:CreateTab("Main",      4483362458)
local PlayerTab   = Window:CreateTab("Player",    7733765137)
local MovementTab = Window:CreateTab("Movement",  4483362458)
local MiscTab     = Window:CreateTab("Misc",      7733765137)
local SettingsTab = Window:CreateTab("Settings",  4483362458)
local CreditsTab  = Window:CreateTab("Credits",   7733765137)

------------------------------------------------------------
-- 8. MAIN TAB :: Auto Money
------------------------------------------------------------
MainTab:CreateSection("Farming")

-- Configurable money amount. The original captured value is preserved as the
-- default; the slider/input below let you push it higher live.
local DEFAULT_MONEY = 4.2266505545686663e+43
State.MoneyAmount = DEFAULT_MONEY

local function buildAutoMoneyArgs()
    return {
        "AnalyticsRE",
        "Update_Money",
        "Slide Down",
        "Give",
        State.MoneyAmount,
        205482029046,
    }
end

local function fireAutoMoneyOnce()
    local funnel = ReplicatedStorage:FindFirstChild("R_Funnel")
    if not funnel then
        funnel = ReplicatedStorage:WaitForChild("R_Funnel", 5)
    end
    if funnel and funnel:IsA("RemoteEvent") then
        funnel:FireServer(unpack(buildAutoMoneyArgs()))
    end
end

MainTab:CreateToggle({
    Name         = "Auto Money",
    CurrentValue = false,
    Flag         = "AutoMoney",
    Callback = function(value)
        State.AutoMoney = value
        if value then
            notify("Auto Money", "Enabled — farming started", 3, 4483362458)
            task.spawn(function()
                while State.AutoMoney do
                    local ok2 = pcall(fireAutoMoneyOnce)
                    if not ok2 then
                        -- back off briefly on failure to avoid tight error loop
                        task.wait(0.5)
                    end
                    task.wait(State.AutoMoneyInterval)
                end
            end)
        else
            notify("Auto Money", "Disabled", 3, 4483362458)
        end
    end,
})

MainTab:CreateSlider({
    Name         = "Auto Money Interval (seconds)",
    Range        = {0.1, 2.0},
    Increment    = 0.05,
    Suffix       = "s",
    CurrentValue = 0.15,
    Flag         = "AutoMoneyInterval",
    Callback = function(value)
        -- Hard floor 0.1s to prevent spam-induced client crashes
        State.AutoMoneyInterval = math.max(0.1, value)
    end,
})

MainTab:CreateInput({
    Name = "Money Amount (per fire)",
    PlaceholderText = "e.g. 1e50, 9e99, 4.22e43",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local n = tonumber(text)
        if n and n > 0 then
            State.MoneyAmount = n
            notify("Money Amount", ("Set to %s"):format(tostring(n)), 3)
        else
            notify("Money Amount", "Invalid number — keeping previous value", 3)
        end
    end,
})

MainTab:CreateButton({
    Name = "Preset: Default (4.22e+43)",
    Callback = function()
        State.MoneyAmount = DEFAULT_MONEY
        notify("Money Amount", "Reset to default", 2)
    end,
})

MainTab:CreateButton({
    Name = "Preset: Insane (1e+99)",
    Callback = function()
        State.MoneyAmount = 1e99
        notify("Money Amount", "Set to 1e+99", 2)
    end,
})

MainTab:CreateButton({
    Name = "Preset: Max (math.huge)",
    Callback = function()
        State.MoneyAmount = math.huge
        notify("Money Amount", "Set to math.huge — server may reject", 3)
    end,
})

MainTab:CreateButton({
    Name = "Fire Once (Manual)",
    Callback = function()
        local ok2, err2 = pcall(fireAutoMoneyOnce)
        if ok2 then
            notify("Manual Fire", "Remote fired successfully", 2)
        else
            notify("Manual Fire", "Failed: " .. tostring(err2), 4)
        end
    end,
})

------------------------------------------------------------
-- 9. PLAYER TAB :: Speed / Jump / Infinite Jump
------------------------------------------------------------
PlayerTab:CreateSection("Stats")

PlayerTab:CreateSlider({
    Name         = "WalkSpeed",
    Range        = {16, 300},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(v) applyWalkSpeed(v) end,
})

PlayerTab:CreateSlider({
    Name         = "JumpPower",
    Range        = {50, 500},
    Increment    = 5,
    Suffix       = "",
    CurrentValue = 50,
    Flag         = "JumpPower",
    Callback     = function(v) applyJumpPower(v) end,
})

PlayerTab:CreateButton({
    Name = "Reset Stats",
    Callback = function()
        applyWalkSpeed(16)
        applyJumpPower(50)
        notify("Stats", "WalkSpeed & JumpPower reset", 3)
    end,
})

PlayerTab:CreateSection("Abilities")

PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfiniteJump",
    Callback = function(value)
        State.InfiniteJump = value
        if value then
            local c = UserInputService.JumpRequest:Connect(function()
                local hum = getHumanoid()
                if hum and State.InfiniteJump then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            trackConn("InfiniteJump", c)
            notify("Infinite Jump", "Enabled", 2)
        else
            trackConn("InfiniteJump", nil)
            notify("Infinite Jump", "Disabled", 2)
        end
    end,
})

PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(value)
        State.Noclip = value
        if value then
            local c = RunService.Stepped:Connect(function()
                if not State.Noclip then return end
                local char = LocalPlayer.Character
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end)
            trackConn("Noclip", c)
            notify("Noclip", "Enabled — you can pass through parts", 3)
        else
            trackConn("Noclip", nil)
            notify("Noclip", "Disabled", 2)
        end
    end,
})

------------------------------------------------------------
-- 10. MOVEMENT TAB :: Fly
------------------------------------------------------------
MovementTab:CreateSection("Fly")

local function stopFly()
    State.Fly = false
    if State.FlyConn then State.FlyConn:Disconnect() State.FlyConn = nil end
    if State.FlyBV then State.FlyBV:Destroy() State.FlyBV = nil end
    if State.FlyBG then State.FlyBG:Destroy() State.FlyBG = nil end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

local function startFly()
    local hum = getHumanoid()
    local root = getRoot()
    if not (hum and root) then return end

    stopFly()
    State.Fly = true

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = root

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9e4
    bg.D = 1000
    bg.CFrame = root.CFrame
    bg.Parent = root

    State.FlyBV = bv
    State.FlyBG = bg
    hum.PlatformStand = true

    State.FlyConn = RunService.RenderStepped:Connect(function()
        if not State.Fly then return end
        local camera = workspace.CurrentCamera
        if not camera then return end

        local dir = Vector3.zero
        local move = LocalPlayer:GetAttribute("FlyMove")
        -- Keyboard input
        if UserInputService.KeyboardEnabled then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        end
        -- Mobile uses thumbstick via Humanoid.MoveDirection
        if UserInputService.TouchEnabled and hum.MoveDirection.Magnitude > 0 then
            local md = hum.MoveDirection
            dir = dir + (camera.CFrame.LookVector * md.Z * -1) + (camera.CFrame.RightVector * md.X)
        end

        if dir.Magnitude > 0 then
            bv.Velocity = dir.Unit * State.FlySpeed
        else
            bv.Velocity = Vector3.zero
        end
        bg.CFrame = camera.CFrame
    end)
end

MovementTab:CreateToggle({
    Name         = "Fly",
    CurrentValue = false,
    Flag         = "Fly",
    Callback = function(value)
        if value then
            startFly()
            notify("Fly", "Enabled — WASD / Space / Shift  •  Mobile: joystick + jump", 4)
        else
            stopFly()
            notify("Fly", "Disabled", 2)
        end
    end,
})

MovementTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {10, 300},
    Increment    = 5,
    Suffix       = "",
    CurrentValue = 60,
    Flag         = "FlySpeed",
    Callback     = function(v) State.FlySpeed = v end,
})

-- Mobile Fly Up / Down floating buttons
local mobileFlyGui
local function ensureMobileFlyButtons()
    if not UserInputService.TouchEnabled then return end
    if mobileFlyGui then return end

    mobileFlyGui = Instance.new("ScreenGui")
    mobileFlyGui.Name = "CS_MobileFly"
    mobileFlyGui.ResetOnSpawn = false
    mobileFlyGui.IgnoreGuiInset = true
    mobileFlyGui.Parent = (gethui and gethui()) or CoreGui

    local function mkBtn(text, posY)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(56, 56)
        b.Position = UDim2.new(1, -72, 1, posY)
        b.AnchorPoint = Vector2.new(0, 1)
        b.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        b.BackgroundTransparency = 0.15
        b.BorderSizePixel = 0
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 24
        b.TextColor3 = Color3.fromRGB(0, 220, 255)
        b.AutoButtonColor = false
        b.Visible = false
        b.Parent = mobileFlyGui
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(0, 220, 255)
        s.Thickness = 1.2
        s.Transparency = 0.3
        return b
    end

    local upBtn   = mkBtn("▲", -160)
    local downBtn = mkBtn("▼", -90)

    local holdingUp, holdingDown = false, false
    upBtn.MouseButton1Down:Connect(function()   holdingUp = true end)
    upBtn.MouseButton1Up:Connect(function()     holdingUp = false end)
    downBtn.MouseButton1Down:Connect(function() holdingDown = true end)
    downBtn.MouseButton1Up:Connect(function()   holdingDown = false end)

    RunService.RenderStepped:Connect(function()
        upBtn.Visible   = State.Fly
        downBtn.Visible = State.Fly
        if State.Fly and State.FlyBV then
            local cur = State.FlyBV.Velocity
            if holdingUp then
                State.FlyBV.Velocity = Vector3.new(cur.X, State.FlySpeed, cur.Z)
            elseif holdingDown then
                State.FlyBV.Velocity = Vector3.new(cur.X, -State.FlySpeed, cur.Z)
            end
        end
    end)
end
ensureMobileFlyButtons()

------------------------------------------------------------
-- 11. MISC TAB :: Anti AFK / FPS / Rejoin / Server Hop
------------------------------------------------------------
MiscTab:CreateSection("Utility")

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(value)
        State.AntiAFK = value
        if State.AntiAFKConn then State.AntiAFKConn:Disconnect() State.AntiAFKConn = nil end
        if value then
            State.AntiAFKConn = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
            notify("Anti AFK", "Enabled — you will not be kicked for idling", 3)
        else
            notify("Anti AFK", "Disabled", 2)
        end
    end,
})

MiscTab:CreateToggle({
    Name = "FPS Boost",
    CurrentValue = false,
    Flag = "FPSBoost",
    Callback = function(value)
        State.FPSBoost = value
        if value then
            -- snapshot defaults so we can restore
            if not State.FPSDefaults.snapshot then
                State.FPSDefaults.snapshot = {}
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        State.FPSDefaults.snapshot[v] = v.Enabled
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        State.FPSDefaults.snapshot[v] = v.Transparency
                    end
                end
            end

            for v, _ in pairs(State.FPSDefaults.snapshot) do
                if v and v.Parent then
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                end
            end

            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                    if v ~= State.BlurInstance then
                        State.FPSDefaults[v] = v.Enabled
                        v.Enabled = false
                    end
                end
            end
            State.FPSDefaults.globalShadows = Lighting.GlobalShadows
            State.FPSDefaults.fog = Lighting.FogEnd
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e6
            notify("FPS Boost", "Enabled — visuals reduced", 3)
        else
            for v, val in pairs(State.FPSDefaults.snapshot or {}) do
                if v and v.Parent then
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = val
                    end
                end
            end
            for v, val in pairs(State.FPSDefaults) do
                if typeof(v) == "Instance" and v.Parent then
                    pcall(function() v.Enabled = val end)
                end
            end
            if State.FPSDefaults.globalShadows ~= nil then Lighting.GlobalShadows = State.FPSDefaults.globalShadows end
            if State.FPSDefaults.fog ~= nil then Lighting.FogEnd = State.FPSDefaults.fog end
            State.FPSDefaults = {}
            notify("FPS Boost", "Disabled — visuals restored", 3)
        end
    end,
})

MiscTab:CreateSection("Teleport")

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        notify("Rejoin", "Teleporting back to this server...", 3)
        task.wait(0.4)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, JOB_ID, LocalPlayer)
        end)
    end,
})

MiscTab:CreateButton({
    Name = "Server Hop (Random)",
    Callback = function()
        notify("Server Hop", "Searching for a server...", 3)
        task.spawn(function()
            local httpGet = (syn and syn.request) or (http and http.request) or nil
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PLACE_ID)
            local servers
            local success = pcall(function()
                local body = game:HttpGet(url)
                servers = HttpService:JSONDecode(body)
            end)
            if not success or not servers or not servers.data then
                notify("Server Hop", "Failed to fetch server list", 4)
                return
            end
            local candidates = {}
            for _, s in ipairs(servers.data) do
                if s.id ~= JOB_ID and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                    table.insert(candidates, s.id)
                end
            end
            if #candidates == 0 then
                notify("Server Hop", "No available servers found", 4)
                return
            end
            local pick = candidates[math.random(1, #candidates)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, pick, LocalPlayer)
            end)
        end)
    end,
})

------------------------------------------------------------
-- 12. SETTINGS TAB :: Config save / unload
------------------------------------------------------------
SettingsTab:CreateSection("Configuration")

SettingsTab:CreateLabel("Settings auto-save via Rayfield. Toggles, sliders and inputs persist between sessions.")

SettingsTab:CreateButton({
    Name = "Reset UI Position",
    Callback = function()
        pcall(function() Rayfield:LoadConfiguration() end)
        notify("Settings", "UI position reset", 2)
    end,
})

SettingsTab:CreateButton({
    Name = "Unload Script",
    Callback = function()
        if _G.__CS_AdminPanel_Cleanup then _G.__CS_AdminPanel_Cleanup() end
    end,
})

SettingsTab:CreateInput({
    Name = "Custom WalkSpeed Value",
    PlaceholderText = "Enter a number (e.g. 120)",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local n = tonumber(text)
        if n then
            applyWalkSpeed(math.clamp(n, 16, 1000))
            notify("WalkSpeed", "Set to " .. n, 2)
        end
    end,
})

------------------------------------------------------------
-- 13. CREDITS TAB
------------------------------------------------------------
CreditsTab:CreateSection("About")
CreditsTab:CreateLabel("Climb & Slide  •  Premium Hub")
CreditsTab:CreateLabel("Built with Rayfield UI by Sirius.")
CreditsTab:CreateLabel("Developer: velocruel")
CreditsTab:CreateLabel("Version: 1.0.0")
CreditsTab:CreateLabel("")
CreditsTab:CreateLabel("This hub is provided as-is for educational use.")
CreditsTab:CreateLabel("Mobile + PC supported. Drag the top bar to move.")

CreditsTab:CreateSection("Acknowledgements")
CreditsTab:CreateLabel("• Rayfield Interface Suite — Sirius")
CreditsTab:CreateLabel("• Roblox TweenService for smooth motion")
CreditsTab:CreateLabel("• Community feedback & testers")

------------------------------------------------------------
-- 14. Cleanup function
------------------------------------------------------------
_G.__CS_AdminPanel_Cleanup = function()
    State.AutoMoney    = false
    State.InfiniteJump = false
    State.Noclip       = false
    State.AntiAFK      = false
    State.FPSBoost     = false

    for k, c in pairs(State.Connections) do
        pcall(function() c:Disconnect() end)
        State.Connections[k] = nil
    end
    if State.AntiAFKConn then pcall(function() State.AntiAFKConn:Disconnect() end) end
    stopFly()

    if mobileFlyGui then pcall(function() mobileFlyGui:Destroy() end) mobileFlyGui = nil end
    if State.BlurInstance then pcall(function() State.BlurInstance:Destroy() end) end
    if State.IntroGui then pcall(function() State.IntroGui:Destroy() end) end

    pcall(function() Rayfield:Destroy() end)
    notify("Climb & Slide", "Hub unloaded", 2)
    _G.__CS_AdminPanel_Loaded = false
end

------------------------------------------------------------
-- 15. Final boot
------------------------------------------------------------
pcall(function() Rayfield:LoadConfiguration() end)
applyWalkSpeed(State.WalkSpeed)
applyJumpPower(State.JumpPower)

-- Wait a beat so Rayfield's Notifications frame is fully built before the
-- first :Notify call (avoids "Template is not a valid member" race).
task.delay(0.6, function()
    notify("Climb & Slide", "Hub loaded successfully — enjoy!", 4, 4483362458)
end)
