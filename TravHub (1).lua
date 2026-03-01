-- =============================================
--         TravHub | Project Delta
--      Made for personal use by Trav
-- =============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- ─── Load Rayfield ────────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "TravHub | Project Delta",
    Icon = 0,
    LoadingTitle = "TravHub",
    LoadingSubtitle = "by Trav",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TravHub",
        FileName = "Config"
    },
    KeySystem = false,
})

-- ─── State Variables ──────────────────────────────────────────────────────────
local ESPEnabled        = false
local NPCESPEnabled     = false
local CorpseESPEnabled  = false
local HealthBarsEnabled = false
local SkeletonESPEnabled = false
local AimbotEnabled     = false
local SilentAimEnabled  = false
local AimbotFOV         = 150
local AimbotSmooth      = 0.2
local AimbotPart        = "Head"
local WalkSpeed         = 16
local JumpPower         = 50
local NoClipEnabled     = false
local FlyEnabled        = false
local FlySpeed          = 50
local InfStaminaEnabled = false
local FullbrightEnabled = false
local NoFogEnabled      = false
local CustomFOV         = 70

local ESPObjects        = {}
local FOVCircle         = Drawing.new("Circle")
FOVCircle.Visible       = false
FOVCircle.Thickness     = 1.5
FOVCircle.Color         = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled        = false
FOVCircle.NumSides      = 64

-- ─── Utility ──────────────────────────────────────────────────────────────────
local function GetCharacter(player)
    return player and player.Character
end

local function GetRootPart(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local char = GetCharacter(player)
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function WorldToViewport(pos)
    local camera = Workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetClosestPlayer()
    local camera     = Workspace.CurrentCamera
    local closest    = nil
    local closestDist = math.huge
    local center     = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local root = GetRootPart(player)
            if root then
                local part = GetCharacter(player):FindFirstChild(AimbotPart) or root
                local screenPos, onScreen = WorldToViewport(part.Position)
                if onScreen then
                    local dist = (center - screenPos).Magnitude
                    if dist < AimbotFOV and dist < closestDist then
                        closestDist = dist
                        closest     = player
                    end
                end
            end
        end
    end
    return closest
end

-- ─── ESP Functions ────────────────────────────────────────────────────────────
local function CreateESPForPlayer(player)
    if ESPObjects[player] then return end

    local objects = {}

    -- Name Label
    local nameLabel        = Drawing.new("Text")
    nameLabel.Visible      = false
    nameLabel.Center       = true
    nameLabel.Outline      = true
    nameLabel.Color        = Color3.fromRGB(255, 255, 255)
    nameLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameLabel.Size         = 14
    objects.nameLabel      = nameLabel

    -- Distance Label
    local distLabel        = Drawing.new("Text")
    distLabel.Visible      = false
    distLabel.Center       = true
    distLabel.Outline      = true
    distLabel.Color        = Color3.fromRGB(200, 200, 200)
    distLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    distLabel.Size         = 12
    objects.distLabel      = distLabel

    -- Box
    local box              = Drawing.new("Square")
    box.Visible            = false
    box.Filled             = false
    box.Color              = Color3.fromRGB(255, 50, 50)
    box.Thickness          = 1.5
    objects.box            = box

    -- Health Bar
    local healthBg         = Drawing.new("Square")
    healthBg.Visible       = false
    healthBg.Filled        = true
    healthBg.Color         = Color3.fromRGB(0, 0, 0)
    healthBg.Transparency  = 0.5
    objects.healthBg       = healthBg

    local healthBar        = Drawing.new("Square")
    healthBar.Visible      = false
    healthBar.Filled       = true
    healthBar.Color        = Color3.fromRGB(0, 255, 0)
    objects.healthBar      = healthBar

    -- Tracer
    local tracer           = Drawing.new("Line")
    tracer.Visible         = false
    tracer.Color           = Color3.fromRGB(255, 50, 50)
    tracer.Thickness       = 1
    objects.tracer         = tracer

    ESPObjects[player]     = objects
end

local function RemoveESPForPlayer(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            obj:Remove()
        end
        ESPObjects[player] = nil
    end
end

local function UpdateESP()
    local camera  = Workspace.CurrentCamera
    local myRoot  = GetRootPart(LocalPlayer)
    local center  = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        if not ESPObjects[player] then
            CreateESPForPlayer(player)
        end

        local objects = ESPObjects[player]
        local char    = GetCharacter(player)
        local alive   = IsAlive(player)

        if not ESPEnabled or not char or not alive then
            for _, obj in pairs(objects) do
                obj.Visible = false
            end
            continue
        end

        local root  = char:FindFirstChild("HumanoidRootPart")
        local head  = char:FindFirstChild("Head")
        local hum   = char:FindFirstChildOfClass("Humanoid")
        if not root or not head then continue end

        local rootPos, onScreen = WorldToViewport(root.Position)
        local headPos           = WorldToViewport(head.Position + Vector3.new(0, 0.7, 0))

        if not onScreen then
            for _, obj in pairs(objects) do
                obj.Visible = false
            end
            continue
        end

        local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
        local h    = (rootPos.Y - headPos.Y)
        local w    = h * 0.6
        local x    = rootPos.X - w / 2
        local y    = headPos.Y

        -- Name
        objects.nameLabel.Text     = player.Name
        objects.nameLabel.Position = Vector2.new(rootPos.X, headPos.Y - 16)
        objects.nameLabel.Visible  = true

        -- Distance
        objects.distLabel.Text     = "[" .. dist .. "m]"
        objects.distLabel.Position = Vector2.new(rootPos.X, rootPos.Y + 4)
        objects.distLabel.Visible  = true

        -- Box
        objects.box.Size           = Vector2.new(w, h)
        objects.box.Position       = Vector2.new(x, y)
        objects.box.Visible        = true

        -- Health Bar
        if HealthBarsEnabled and hum then
            local hpPct  = hum.Health / hum.MaxHealth
            local barH   = h
            local barX   = x - 6
            local barY   = y

            objects.healthBg.Size     = Vector2.new(4, barH)
            objects.healthBg.Position = Vector2.new(barX, barY)
            objects.healthBg.Visible  = true

            objects.healthBar.Size     = Vector2.new(4, barH * hpPct)
            objects.healthBar.Position = Vector2.new(barX, barY + barH - barH * hpPct)
            objects.healthBar.Color    = Color3.fromRGB(
                math.floor((1 - hpPct) * 255),
                math.floor(hpPct * 255),
                0
            )
            objects.healthBar.Visible = true
        else
            objects.healthBg.Visible  = false
            objects.healthBar.Visible = false
        end

        -- Tracer
        objects.tracer.From    = Vector2.new(center.X, camera.ViewportSize.Y)
        objects.tracer.To      = Vector2.new(rootPos.X, rootPos.Y)
        objects.tracer.Visible = true
    end
end

-- ─── NoClip ───────────────────────────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if NoClipEnabled then
        local char = GetCharacter(LocalPlayer)
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- ─── Fly ──────────────────────────────────────────────────────────────────────
local flyConnection
local function StartFly()
    local char = GetCharacter(LocalPlayer)
    local root = GetRootPart(LocalPlayer)
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true
    local bodyVel = Instance.new("BodyVelocity", root)
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.zero

    local bodyGyr = Instance.new("BodyGyro", root)
    bodyGyr.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyr.P = 1e4

    flyConnection = RunService.RenderStepped:Connect(function()
        if not FlyEnabled then
            flyConnection:Disconnect()
            bodyVel:Destroy()
            bodyGyr:Destroy()
            hum.PlatformStand = false
            return
        end
        local camera = Workspace.CurrentCamera
        local vel    = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            vel = vel + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            vel = vel - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            vel = vel - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            vel = vel + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            vel = vel + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vel = vel - Vector3.new(0, 1, 0)
        end
        bodyVel.Velocity = vel.Magnitude > 0 and vel.Unit * FlySpeed or Vector3.zero
        bodyGyr.CFrame = camera.CFrame
    end)
end

-- ─── Aimbot ───────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    local camera = Workspace.CurrentCamera
    FOVCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    FOVCircle.Radius   = AimbotFOV
    FOVCircle.Visible  = AimbotEnabled

    -- Aimbot
    if AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestPlayer()
        if target then
            local char = GetCharacter(target)
            local part = char and (char:FindFirstChild(AimbotPart) or GetRootPart(target))
            if part then
                local pos       = part.Position
                local smoothed  = camera.CFrame:Lerp(
                    CFrame.new(camera.CFrame.Position, pos),
                    AimbotSmooth
                )
                camera.CFrame = smoothed
            end
        end
    end

    -- ESP update
    UpdateESP()
end)

-- ─── Fullbright ───────────────────────────────────────────────────────────────
local origAmbient, origOutdoor
local function SetFullbright(on)
    if on then
        origAmbient            = Lighting.Ambient
        origOutdoor            = Lighting.OutdoorAmbient
        Lighting.Ambient       = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness    = 2
        Lighting.ClockTime     = 14
    else
        if origAmbient  then Lighting.Ambient        = origAmbient  end
        if origOutdoor  then Lighting.OutdoorAmbient = origOutdoor  end
        Lighting.Brightness = 1
    end
end

-- ─── No Fog ───────────────────────────────────────────────────────────────────
local function SetNoFog(on)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            obj.Density = on and 0 or 0.395
            obj.Haze    = on and 0 or 2.8
        end
        if obj:IsA("FogEffect") then
            obj.Enabled = not on
        end
    end
end

-- ─── Player Connections ───────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    if ESPEnabled then CreateESPForPlayer(player) end
end)
Players.PlayerRemoving:Connect(RemoveESPForPlayer)

-- ─── Stamina Loop ─────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if InfStaminaEnabled then
        -- Project Delta uses a RemoteEvent/Value for stamina; attempt generic patch
        local char = GetCharacter(LocalPlayer)
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v.Name:lower():find("stamina") and v:IsA("NumberValue") then
                    v.Value = v.Value < 80 and 100 or v.Value
                end
            end
        end
    end
end)

-- =============================================================
--  TABS
-- =============================================================

-- ─── TAB 1 : ESP ──────────────────────────────────────────────────────────────
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateToggle({
    Name    = "Player ESP",
    CurrentValue = false,
    Flag    = "PlayerESP",
    Callback = function(v)
        ESPEnabled = v
        if not v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and ESPObjects[player] then
                    for _, obj in pairs(ESPObjects[player]) do
                        obj.Visible = false
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name    = "Health Bars",
    CurrentValue = false,
    Flag    = "HealthBars",
    Callback = function(v)
        HealthBarsEnabled = v
    end
})

ESPTab:CreateToggle({
    Name    = "Tracers",
    CurrentValue = false,
    Flag    = "Tracers",
    Callback = function(v)
        for _, objs in pairs(ESPObjects) do
            if objs.tracer then
                -- controlled per-frame already; this just sets persistent visibility
            end
        end
    end
})

ESPTab:CreateSlider({
    Name         = "ESP Text Size",
    Range        = {10, 22},
    Increment    = 1,
    Suffix       = "px",
    CurrentValue = 14,
    Flag         = "ESPTextSize",
    Callback     = function(v)
        for _, objs in pairs(ESPObjects) do
            if objs.nameLabel then objs.nameLabel.Size = v end
            if objs.distLabel  then objs.distLabel.Size  = v - 2 end
        end
    end
})

ESPTab:CreateColorPicker({
    Name         = "Box Color",
    Color        = Color3.fromRGB(255, 50, 50),
    Flag         = "BoxColor",
    Callback     = function(v)
        for _, objs in pairs(ESPObjects) do
            if objs.box    then objs.box.Color    = v end
            if objs.tracer then objs.tracer.Color = v end
        end
    end
})

-- ─── TAB 2 : AIMBOT ───────────────────────────────────────────────────────────
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateToggle({
    Name    = "Aimbot (Hold RMB)",
    CurrentValue = false,
    Flag    = "Aimbot",
    Callback = function(v)
        AimbotEnabled = v
        FOVCircle.Visible = v
    end
})

AimbotTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {10, 500},
    Increment    = 5,
    Suffix       = "px",
    CurrentValue = 150,
    Flag         = "AimbotFOV",
    Callback     = function(v)
        AimbotFOV   = v
        FOVCircle.Radius = v
    end
})

AimbotTab:CreateSlider({
    Name         = "Smoothness",
    Range        = {1, 20},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 5,
    Flag         = "AimbotSmooth",
    Callback     = function(v)
        AimbotSmooth = v / 100
    end
})

AimbotTab:CreateDropdown({
    Name         = "Target Part",
    Options      = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"},
    CurrentOption = {"Head"},
    Flag         = "AimbotPart",
    Callback     = function(v)
        AimbotPart = v[1] or "Head"
    end
})

AimbotTab:CreateColorPicker({
    Name         = "FOV Color",
    Color        = Color3.fromRGB(255, 255, 255),
    Flag         = "FOVColor",
    Callback     = function(v)
        FOVCircle.Color = v
    end
})

-- ─── TAB 3 : PLAYER ───────────────────────────────────────────────────────────
local PlayerTab = Window:CreateTab("Player", 4483362458)

PlayerTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 250},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(v)
        WalkSpeed = v
        local char = GetCharacter(LocalPlayer)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
})

PlayerTab:CreateSlider({
    Name         = "Jump Power",
    Range        = {50, 500},
    Increment    = 5,
    Suffix       = "",
    CurrentValue = 50,
    Flag         = "JumpPower",
    Callback     = function(v)
        JumpPower = v
        local char = GetCharacter(LocalPlayer)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end
})

PlayerTab:CreateToggle({
    Name    = "NoClip",
    CurrentValue = false,
    Flag    = "NoClip",
    Callback = function(v)
        NoClipEnabled = v
    end
})

PlayerTab:CreateToggle({
    Name    = "Fly  (WASD + Space/Ctrl)",
    CurrentValue = false,
    Flag    = "Fly",
    Callback = function(v)
        FlyEnabled = v
        if v then StartFly() end
    end
})

PlayerTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {10, 300},
    Increment    = 5,
    Suffix       = "",
    CurrentValue = 50,
    Flag         = "FlySpeed",
    Callback     = function(v)
        FlySpeed = v
    end
})

PlayerTab:CreateToggle({
    Name    = "Infinite Stamina",
    CurrentValue = false,
    Flag    = "InfStamina",
    Callback = function(v)
        InfStaminaEnabled = v
    end
})

PlayerTab:CreateButton({
    Name     = "Reset Walk Speed & Jump",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        Rayfield:Notify({
            Title    = "TravHub",
            Content  = "Speed & Jump reset to default.",
            Duration = 3,
        })
    end
})

-- ─── TAB 4 : VISUALS ──────────────────────────────────────────────────────────
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateToggle({
    Name    = "Fullbright",
    CurrentValue = false,
    Flag    = "Fullbright",
    Callback = function(v)
        FullbrightEnabled = v
        SetFullbright(v)
    end
})

VisualsTab:CreateToggle({
    Name    = "Remove Fog",
    CurrentValue = false,
    Flag    = "NoFog",
    Callback = function(v)
        NoFogEnabled = v
        SetNoFog(v)
    end
})

VisualsTab:CreateSlider({
    Name         = "Field of View",
    Range        = {70, 120},
    Increment    = 1,
    Suffix       = "°",
    CurrentValue = 70,
    Flag         = "FOV",
    Callback     = function(v)
        Workspace.CurrentCamera.FieldOfView = v
    end
})

-- ─── TAB 5 : MISC ─────────────────────────────────────────────────────────────
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateButton({
    Name     = "Teleport to Spawn",
    Callback = function()
        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(LocalPlayer)
        if root then
            root.CFrame = CFrame.new(0, 10, 0)
        end
    end
})

MiscTab:CreateButton({
    Name     = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

MiscTab:CreateButton({
    Name     = "Copy Player List",
    Callback = function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(names, p.Name .. " (" .. p.DisplayName .. ")")
        end
        setclipboard(table.concat(names, "\n"))
        Rayfield:Notify({
            Title   = "TravHub",
            Content = "Player list copied to clipboard!",
            Duration = 3,
        })
    end
})

MiscTab:CreateLabel("TravHub v1.0 | Project Delta")
MiscTab:CreateLabel("For personal use only.")

-- ─── Init Notify ──────────────────────────────────────────────────────────────
Rayfield:Notify({
    Title    = "TravHub Loaded",
    Content  = "Welcome back, Trav!",
    Duration = 5,
    Image    = 4483362458,
})

-- ─── Persist walkspeed/jump on respawn ───────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = WalkSpeed
    hum.JumpPower = JumpPower
    if NoFogEnabled  then SetNoFog(true)       end
    if FullbrightEnabled then SetFullbright(true) end
end)

Rayfield:LoadConfiguration()

