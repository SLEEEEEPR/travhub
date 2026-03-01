-- ╔══════════════════════════════════════════════════════════╗
-- ║                                                          ║
-- ║          ████████╗██████╗  █████╗ ██╗   ██╗             ║
-- ║             ██╔══╝██╔══██╗██╔══██╗██║   ██║             ║
-- ║             ██║   ██████╔╝███████║██║   ██║             ║
-- ║             ██║   ██╔══██╗██╔══██║╚██╗ ██╔╝             ║
-- ║             ██║   ██║  ██║██║  ██║ ╚████╔╝              ║
-- ║             ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝              ║
-- ║                                                          ║
-- ║            H U B  ·  Project Delta Edition              ║
-- ║                       Version 3.0                       ║
-- ║                Personal Script by Trav                  ║
-- ╚══════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local SoundService     = game:GetService("SoundService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════
--  RAYFIELD LOADER
-- ══════════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name             = "TravHub  ·  Δ  ·  Project Delta",
    Icon             = 0,
    LoadingTitle     = "TravHub  v3.0",
    LoadingSubtitle  = "Project Delta Edition — Initializing...",
    Theme            = "Amethyst",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "TravHub_Delta",
        FileName   = "Config_v3"
    },
    KeySystem = false,
})

-- ══════════════════════════════════════════════════════════
--  GLOBAL STATE
-- ══════════════════════════════════════════════════════════
local State = {
    -- ESP
    ESPEnabled        = false,
    ESPHealthBars     = false,
    ESPTracers        = false,
    ESPNames          = true,
    ESPDistance       = true,
    ESPSkeleton       = false,
    ESPMaxDist        = 500,
    ESPTextSize       = 14,
    BoxColor          = Color3.fromRGB(220, 80, 80),
    ESPTeamCheck      = false,

    -- Aimbot
    AimbotEnabled     = false,
    SilentAim         = false,
    TriggerBot        = false,
    TeamCheck         = false,
    AimbotFOV         = 150,
    AimbotSmooth      = 0.07,
    AimbotPart        = "Head",
    FOVColor          = Color3.fromRGB(180, 100, 255),
    FOVVisible        = true,

    -- Combat
    NoRecoilEnabled   = false,
    RecoilStrength    = 0.2,
    HitboxExpander    = false,
    HitboxSize        = 6,
    AutoParry         = false,

    -- Movement
    NoClipEnabled     = false,
    SpeedEnabled      = false,
    WalkSpeed         = 16,
    JumpPowerEnabled  = false,
    JumpPower         = 50,
    InfiniteJump      = false,
    FlyEnabled        = false,
    FlySpeed          = 50,
    AntiVoid          = false,
    AutoSprint        = false,

    -- Visuals
    FullbrightEnabled = false,
    NoFogEnabled      = false,
    CustomCrosshair   = false,
    CrosshairColor    = Color3.fromRGB(255, 255, 255),
    CrosshairSize     = 12,
    CrosshairGap      = 4,
    CrosshairThick    = 2,
    HitmarkerEnabled  = false,

    -- Player
    GodModeEnabled    = false,
    AntiRagdoll       = false,
    AutoRespawn       = false,

    -- Camera / Misc
    CameraFOV         = 70,
}

-- ══════════════════════════════════════════════════════════
--  UTILITY
-- ══════════════════════════════════════════════════════════
local function GetChar(p)     return p and p.Character end
local function GetRoot(p)     local c = GetChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHead(p)     local c = GetChar(p); return c and c:FindFirstChild("Head") end
local function GetHum(p)      local c = GetChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive(p)     local h = GetHum(p); return h and h.Health > 0 end
local function IsTeammate(p)  return State.TeamCheck and p.Team == LocalPlayer.Team end

local function W2S(pos)
    local s, v = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), v
end

local function Dist3D(a, b)
    if a and b then return math.floor((a.Position - b.Position).Magnitude) end
    return 0
end

local function Notify(title, msg, duration)
    Rayfield:Notify({ Title = title, Content = msg, Duration = duration or 3 })
end

-- ══════════════════════════════════════════════════════════
--  DRAWING HELPERS
-- ══════════════════════════════════════════════════════════
local function NewDraw(t, props)
    local o = Drawing.new(t)
    for k, v in pairs(props) do o[k] = v end
    return o
end

local function HideAll(t)
    for _, o in pairs(t) do o.Visible = false end
end

-- ══════════════════════════════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════════════════════════════
local FOVCircle = NewDraw("Circle", {
    Visible   = false,
    Thickness = 1.5,
    Color     = State.FOVColor,
    Filled    = false,
    NumSides  = 64,
})

-- ══════════════════════════════════════════════════════════
--  CUSTOM CROSSHAIR DRAWINGS
-- ══════════════════════════════════════════════════════════
local CH = {
    top    = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.new(1,1,1) }),
    bot    = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.new(1,1,1) }),
    left   = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.new(1,1,1) }),
    right  = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.new(1,1,1) }),
    dot    = NewDraw("Circle", { Visible = false, Thickness = 0, Filled = true, Radius = 1.5, Color = Color3.new(1,1,1), NumSides = 12 }),
}

-- ══════════════════════════════════════════════════════════
--  HITMARKER DRAWINGS
-- ══════════════════════════════════════════════════════════
local HM = {
    tl = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.fromRGB(255, 220, 0) }),
    tr = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.fromRGB(255, 220, 0) }),
    bl = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.fromRGB(255, 220, 0) }),
    br = NewDraw("Line", { Visible = false, Thickness = 2, Color = Color3.fromRGB(255, 220, 0) }),
}
local hmActive = false
local hmTimer  = 0

-- ══════════════════════════════════════════════════════════
--  FPS / PING OVERLAY
-- ══════════════════════════════════════════════════════════
local FPSLabel  = NewDraw("Text", { Visible = false, Size = 13, Color = Color3.fromRGB(180,255,180), Outline = true, OutlineColor = Color3.new(0,0,0), Position = Vector2.new(8, 8) })
local PingLabel = NewDraw("Text", { Visible = false, Size = 13, Color = Color3.fromRGB(180,220,255), Outline = true, OutlineColor = Color3.new(0,0,0), Position = Vector2.new(8, 24) })

local fpsCounter, fpsFrames, fpsElapsed = 0, 0, 0

-- ══════════════════════════════════════════════════════════
--  ESP OBJECT POOL
-- ══════════════════════════════════════════════════════════
local ESPObjects = {}

-- Skeleton joint pairs (standard R6/R15 compatible)
local SKELETON_PAIRS = {
    {"Head",       "UpperTorso"},  {"Head",       "Torso"},
    {"UpperTorso", "LowerTorso"},  {"Torso",      "HumanoidRootPart"},
    {"UpperTorso", "LeftUpperArm"},{"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},   {"RightLowerArm","RightHand"},
    {"LowerTorso", "LeftUpperLeg"},{"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},   {"RightLowerLeg","RightFoot"},
    -- R6 fallbacks
    {"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Left Arm","Left Leg"},{"Right Arm","Right Leg"},
}

local function MakeESP(player)
    if ESPObjects[player] then return end
    local skel = {}
    for i = 1, #SKELETON_PAIRS do
        skel[i] = NewDraw("Line", { Visible = false, Color = Color3.fromRGB(255,255,255), Thickness = 1 })
    end
    ESPObjects[player] = {
        boxOut  = NewDraw("Square", { Visible=false, Filled=false, Color=Color3.new(0,0,0),            Thickness=3.5 }),
        box     = NewDraw("Square", { Visible=false, Filled=false, Color=State.BoxColor,               Thickness=1.5 }),
        fill    = NewDraw("Square", { Visible=false, Filled=true,  Color=State.BoxColor, Transparency=0.88 }),
        name    = NewDraw("Text",   { Visible=false, Center=true,  Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Size=14 }),
        dist    = NewDraw("Text",   { Visible=false, Center=true,  Outline=true, Color=Color3.fromRGB(180,180,180), OutlineColor=Color3.new(0,0,0), Size=11 }),
        weapon  = NewDraw("Text",   { Visible=false, Center=true,  Outline=true, Color=Color3.fromRGB(255,200,100), OutlineColor=Color3.new(0,0,0), Size=10 }),
        hpBg    = NewDraw("Square", { Visible=false, Filled=true,  Color=Color3.new(0,0,0), Transparency=0.4 }),
        hpBar   = NewDraw("Square", { Visible=false, Filled=true,  Color=Color3.fromRGB(0,255,0) }),
        tracer  = NewDraw("Line",   { Visible=false, Color=State.BoxColor, Thickness=1 }),
        skeleton= skel,
    }
end

local function KillESP(p)
    if ESPObjects[p] then
        for k, o in pairs(ESPObjects[p]) do
            if k == "skeleton" then
                for _, l in ipairs(o) do l:Remove() end
            else
                o:Remove()
            end
        end
        ESPObjects[p] = nil
    end
end

local function GetWeaponName(player)
    local char = GetChar(player)
    if not char then return "" end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and tool.Name or ""
end

local function UpdateESP()
    local myRoot = GetRoot(LocalPlayer)
    local vp     = Camera.ViewportSize
    local bottom = Vector2.new(vp.X / 2, vp.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not ESPObjects[player] then MakeESP(player) end
        local o = ESPObjects[player]

        if not State.ESPEnabled or not IsAlive(player) or IsTeammate(player) then
            HideAll(o)
            for _, l in ipairs(o.skeleton) do l.Visible = false end
            continue
        end

        local char  = GetChar(player)
        local root  = char and char:FindFirstChild("HumanoidRootPart")
        local head  = char and char:FindFirstChild("Head")
        local hum   = GetHum(player)
        if not root or not head then
            HideAll(o)
            for _, l in ipairs(o.skeleton) do l.Visible = false end
            continue
        end

        local dist = Dist3D(myRoot, root)
        if dist > State.ESPMaxDist then
            HideAll(o)
            for _, l in ipairs(o.skeleton) do l.Visible = false end
            continue
        end

        local rPos, onScreen = W2S(root.Position)
        local hPos           = W2S(head.Position + Vector3.new(0, 0.7, 0))
        if not onScreen then
            HideAll(o)
            for _, l in ipairs(o.skeleton) do l.Visible = false end
            continue
        end

        local bh  = rPos.Y - hPos.Y
        local bw  = bh * 0.55
        local bx  = rPos.X - bw / 2
        local by  = hPos.Y
        local col = State.BoxColor

        -- Outline + box
        o.boxOut.Size     = Vector2.new(bw+2, bh+2)
        o.boxOut.Position = Vector2.new(bx-1, by-1)
        o.boxOut.Visible  = true

        o.box.Color    = col
        o.box.Size     = Vector2.new(bw, bh)
        o.box.Position = Vector2.new(bx, by)
        o.box.Visible  = true

        -- Filled box (subtle tint)
        o.fill.Color    = col
        o.fill.Size     = Vector2.new(bw, bh)
        o.fill.Position = Vector2.new(bx, by)
        o.fill.Visible  = true

        -- Name
        o.name.Text     = player.Name
        o.name.Size     = State.ESPTextSize
        o.name.Position = Vector2.new(rPos.X, by - State.ESPTextSize - 2)
        o.name.Visible  = State.ESPNames

        -- Distance
        o.dist.Text     = dist .. " m"
        o.dist.Position = Vector2.new(rPos.X, rPos.Y + 3)
        o.dist.Visible  = State.ESPDistance

        -- Weapon name
        local wpn = GetWeaponName(player)
        o.weapon.Text     = wpn ~= "" and ("["..wpn.."]") or ""
        o.weapon.Position = Vector2.new(rPos.X, rPos.Y + 14)
        o.weapon.Visible  = wpn ~= ""

        -- Health bar
        if State.ESPHealthBars and hum then
            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            local r   = math.floor((1 - pct) * 255)
            local g   = math.floor(pct * 255)
            o.hpBg.Size     = Vector2.new(4, bh + 2)
            o.hpBg.Position = Vector2.new(bx - 7, by - 1)
            o.hpBg.Visible  = true
            o.hpBar.Color    = Color3.fromRGB(r, g, 0)
            o.hpBar.Size     = Vector2.new(4, bh * pct)
            o.hpBar.Position = Vector2.new(bx - 7, by + bh - bh * pct)
            o.hpBar.Visible  = true
        else
            o.hpBg.Visible  = false
            o.hpBar.Visible = false
        end

        -- Tracer
        if State.ESPTracers then
            o.tracer.Color   = col
            o.tracer.From    = bottom
            o.tracer.To      = Vector2.new(rPos.X, rPos.Y)
            o.tracer.Visible = true
        else
            o.tracer.Visible = false
        end

        -- Skeleton
        if State.ESPSkeleton then
            for i, pair in ipairs(SKELETON_PAIRS) do
                local line = o.skeleton[i]
                local pA   = char:FindFirstChild(pair[1])
                local pB   = char:FindFirstChild(pair[2])
                if pA and pB then
                    local sA, oA = W2S(pA.Position)
                    local sB, oB = W2S(pB.Position)
                    if oA and oB then
                        line.From    = sA
                        line.To      = sB
                        line.Color   = col
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, l in ipairs(o.skeleton) do l.Visible = false end
        end
    end
end

-- ══════════════════════════════════════════════════════════
--  AIMBOT  —  GetClosest
-- ══════════════════════════════════════════════════════════
local function GetClosest()
    local center   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) and not IsTeammate(p) then
            local char = GetChar(p)
            local part = char and (char:FindFirstChild(State.AimbotPart) or GetRoot(p))
            if part then
                local sp, on = W2S(part.Position)
                if on then
                    local d = (center - sp).Magnitude
                    if d < State.AimbotFOV and d < bd then
                        bd, best = d, p
                    end
                end
            end
        end
    end
    return best
end

-- ══════════════════════════════════════════════════════════
--  HITBOX EXPANDER
-- ══════════════════════════════════════════════════════════
local HitboxObjects = {}

local function UpdateHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = GetChar(p)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            if State.HitboxExpander then
                if not HitboxObjects[p] then
                    local part = Instance.new("Part")
                    part.Name        = "HitboxExpand"
                    part.Anchored    = false
                    part.CanCollide  = false
                    part.Transparency = 1
                    part.Size        = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                    local weld       = Instance.new("WeldConstraint")
                    weld.Part0       = root
                    weld.Part1       = part
                    weld.Parent      = part
                    part.Parent      = char
                    HitboxObjects[p] = part
                else
                    HitboxObjects[p].Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                end
            else
                if HitboxObjects[p] then
                    HitboxObjects[p]:Destroy()
                    HitboxObjects[p] = nil
                end
            end
        else
            if HitboxObjects[p] then
                pcall(function() HitboxObjects[p]:Destroy() end)
                HitboxObjects[p] = nil
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════
--  CROSSHAIR UPDATE
-- ══════════════════════════════════════════════════════════
local function UpdateCrosshair()
    local vp  = Camera.ViewportSize
    local cx  = vp.X / 2
    local cy  = vp.Y / 2
    local gap = State.CrosshairGap
    local sz  = State.CrosshairSize
    local col = State.CrosshairColor
    local th  = State.CrosshairThick

    local show = State.CustomCrosshair

    for _, l in pairs(CH) do l.Visible = show end

    if not show then return end

    CH.top.From   = Vector2.new(cx,      cy - gap);   CH.top.To   = Vector2.new(cx,      cy - gap - sz)
    CH.bot.From   = Vector2.new(cx,      cy + gap);   CH.bot.To   = Vector2.new(cx,      cy + gap + sz)
    CH.left.From  = Vector2.new(cx - gap, cy);        CH.left.To  = Vector2.new(cx - gap - sz, cy)
    CH.right.From = Vector2.new(cx + gap, cy);        CH.right.To = Vector2.new(cx + gap + sz, cy)
    CH.dot.Position = Vector2.new(cx, cy)

    for k, l in pairs(CH) do
        l.Color     = col
        if k ~= "dot" then l.Thickness = th end
    end
end

-- ══════════════════════════════════════════════════════════
--  HITMARKER TRIGGER  (hook damage events)
-- ══════════════════════════════════════════════════════════
local function TriggerHitmarker()
    if not State.HitmarkerEnabled then return end
    hmActive = true
    hmTimer  = 0.25
end

-- Try to detect hits via humanoid health changes on remote enemies
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        local hum = GetHum(p)
        if hum then
            hum.HealthChanged:Connect(function(hp)
                if hp < hum.Health then TriggerHitmarker() end
            end)
        end
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.HealthChanged:Connect(function(hp)
                if hp < hum.Health then TriggerHitmarker() end
            end)
        end
    end)
end)

local function UpdateHitmarker(dt)
    if not State.HitmarkerEnabled or not hmActive then
        for _, l in pairs(HM) do l.Visible = false end
        return
    end
    hmTimer = hmTimer - dt
    if hmTimer <= 0 then
        hmActive = false
        for _, l in pairs(HM) do l.Visible = false end
        return
    end
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    local s  = 8
    local col= Color3.fromRGB(255, 220, 0)
    HM.tl.From = Vector2.new(cx-2, cy-2); HM.tl.To = Vector2.new(cx-2-s, cy-2-s)
    HM.tr.From = Vector2.new(cx+2, cy-2); HM.tr.To = Vector2.new(cx+2+s, cy-2-s)
    HM.bl.From = Vector2.new(cx-2, cy+2); HM.bl.To = Vector2.new(cx-2-s, cy+2+s)
    HM.br.From = Vector2.new(cx+2, cy+2); HM.br.To = Vector2.new(cx+2+s, cy+2+s)
    for _, l in pairs(HM) do l.Color = col; l.Visible = true; l.Thickness = 2 end
end

-- ══════════════════════════════════════════════════════════
--  NO RECOIL STATE
-- ══════════════════════════════════════════════════════════
local lastCamCF = nil

-- ══════════════════════════════════════════════════════════
--  FLY SYSTEM
-- ══════════════════════════════════════════════════════════
local flyActive    = false
local flyBodyVel   = nil
local flyBodyGyro  = nil

local function StartFly()
    local char = GetChar(LocalPlayer)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or flyActive then return end
    flyActive = true
    local hum = GetHum(LocalPlayer)
    if hum then hum.PlatformStand = true end

    flyBodyVel           = Instance.new("BodyVelocity")
    flyBodyVel.Velocity  = Vector3.zero
    flyBodyVel.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
    flyBodyVel.Parent    = root

    flyBodyGyro          = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque= Vector3.new(1e9, 1e9, 1e9)
    flyBodyGyro.P        = 1e5
    flyBodyGyro.CFrame   = root.CFrame
    flyBodyGyro.Parent   = root
end

local function StopFly()
    flyActive = false
    if flyBodyVel  then flyBodyVel:Destroy();  flyBodyVel  = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    local hum = GetHum(LocalPlayer)
    if hum then hum.PlatformStand = false end
end

local function UpdateFly()
    if not State.FlyEnabled then return end
    if not flyActive then StartFly() end
    local root = GetRoot(LocalPlayer)
    if not flyBodyVel or not flyBodyGyro or not root then return end

    local cam    = Camera
    local dir    = Vector3.zero
    local speed  = State.FlySpeed

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        dir = dir + cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        dir = dir - cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        dir = dir - cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        dir = dir + cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        dir = dir + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        dir = dir - Vector3.new(0, 1, 0)
    end

    flyBodyVel.Velocity  = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
    flyBodyGyro.CFrame   = cam.CFrame
end

-- ══════════════════════════════════════════════════════════
--  AUTO-SPRINT
-- ══════════════════════════════════════════════════════════
local function DoAutoSprint()
    if not State.AutoSprint then return end
    local char = GetChar(LocalPlayer)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- Find sprint function/remote via common naming patterns
    local sprintEvent = char:FindFirstChild("SprintEvent") or
                        LocalPlayer.PlayerScripts:FindFirstChild("Sprint") or
                        game:GetService("ReplicatedStorage"):FindFirstChild("Sprint")
    if sprintEvent and sprintEvent:IsA("RemoteEvent") then
        pcall(function() sprintEvent:FireServer(true) end)
    end
end

-- ══════════════════════════════════════════════════════════
--  ANTI-VOID
-- ══════════════════════════════════════════════════════════
local lastSafePos = nil
RunService.Heartbeat:Connect(function()
    if not State.AntiVoid then return end
    local root = GetRoot(LocalPlayer)
    if not root then return end
    if root.Position.Y > -50 then
        lastSafePos = root.CFrame
    elseif lastSafePos then
        root.CFrame = lastSafePos
    end
end)

-- ══════════════════════════════════════════════════════════
--  GOD MODE  (attempt local reflect)
-- ══════════════════════════════════════════════════════════
local function ApplyGodMode()
    local hum = GetHum(LocalPlayer)
    if not hum then return end
    if State.GodModeEnabled then
        hum.MaxHealth = math.huge
        hum.Health    = math.huge
    end
end

-- ══════════════════════════════════════════════════════════
--  AUTO PARRY / BLOCK
-- ══════════════════════════════════════════════════════════
local function TryAutoParry()
    if not State.AutoParry then return end
    -- Project Delta common block/parry remote patterns
    local rs   = game:GetService("ReplicatedStorage")
    local block = rs:FindFirstChild("Block") or rs:FindFirstChild("Parry") or rs:FindFirstChild("Guard")
    if block and block:IsA("RemoteEvent") then
        pcall(function() block:FireServer() end)
    end
    -- Also try via local scripts or bindable events
    local char = GetChar(LocalPlayer)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local parryFunc = tool:FindFirstChild("Parry") or tool:FindFirstChild("Block")
            if parryFunc and parryFunc:IsA("RemoteEvent") then
                pcall(function() parryFunc:FireServer() end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════
--  ANTI RAGDOLL
-- ══════════════════════════════════════════════════════════
local function ApplyAntiRagdoll()
    if not State.AntiRagdoll then return end
    local char = GetChar(LocalPlayer)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
            v.Enabled = false
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,      false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,  false)
    end
end

-- ══════════════════════════════════════════════════════════
--  FULLBRIGHT / FOG
-- ══════════════════════════════════════════════════════════
local _oA, _oO, _oB, _oC
local function SetFullbright(on)
    if on then
        _oA = Lighting.Ambient;        _oO = Lighting.OutdoorAmbient
        _oB = Lighting.Brightness;     _oC = Lighting.ClockTime
        Lighting.Ambient        = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Brightness     = 2
        Lighting.ClockTime      = 14
    else
        if _oA then Lighting.Ambient        = _oA end
        if _oO then Lighting.OutdoorAmbient = _oO end
        if _oB then Lighting.Brightness     = _oB end
        if _oC then Lighting.ClockTime      = _oC end
    end
end

local function SetNoFog(on)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            obj.Density = on and 0 or 0.395
            obj.Haze    = on and 0 or 2.8
        end
        if obj:IsA("FogEffect") then obj.Enabled = not on end
    end
end

-- ══════════════════════════════════════════════════════════
--  RENDER STEPPED  —  main loop
-- ══════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)

    -- FPS counter
    fpsFrames  = fpsFrames + 1
    fpsElapsed = fpsElapsed + dt
    if fpsElapsed >= 0.5 then
        fpsCounter  = math.floor(fpsFrames / fpsElapsed)
        fpsFrames   = 0
        fpsElapsed  = 0
    end

    -- FOV circle
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Radius   = State.AimbotFOV
    FOVCircle.Color    = State.FOVColor
    FOVCircle.Visible  = State.AimbotEnabled and State.FOVVisible

    -- Aimbot (hold RMB)
    if State.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosest()
        if target then
            local char = GetChar(target)
            local part = char and (char:FindFirstChild(State.AimbotPart) or GetRoot(target))
            if part then
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, part.Position),
                    State.AimbotSmooth
                )
            end
        end
    end

    -- Silent Aim (override mouse target)
    if State.SilentAim then
        local target = GetClosest()
        if target then
            local char = GetChar(target)
            local part = char and (char:FindFirstChild(State.AimbotPart) or GetRoot(target))
            if part then
                -- Override aim via camera subject trick
                pcall(function()
                    local mouse = LocalPlayer:GetMouse()
                    mouse.TargetFilter = Workspace
                end)
            end
        end
    end

    -- Trigger bot
    if State.TriggerBot then
        local mouse  = LocalPlayer:GetMouse()
        local target = mouse.Target
        if target then
            local model = target:FindFirstAncestorOfClass("Model")
            if model then
                local p = Players:GetPlayerFromCharacter(model)
                if p and p ~= LocalPlayer and IsAlive(p) and not IsTeammate(p) then
                    -- Simulate mouse1 press
                    pcall(function()
                        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            local uis = game:GetService("VirtualInputManager")
                            if uis then
                                uis:SendMouseButtonEvent(0, 0, Enum.UserInputType.MouseButton1, true, game, 0)
                                uis:SendMouseButtonEvent(0, 0, Enum.UserInputType.MouseButton1, false, game, 0)
                            end
                        end
                    end)
                end
            end
        end
    end

    -- No Recoil
    if State.NoRecoilEnabled and lastCamCF then
        local px              = select(1, lastCamCF:ToEulerAnglesYXZ())
        local cx, cy, cz      = Camera.CFrame:ToEulerAnglesYXZ()
        local delta           = cx - px
        if delta > 0.0005 then
            local newPitch    = cx - delta * (1 - State.RecoilStrength)
            Camera.CFrame     = CFrame.new(Camera.CFrame.Position) * CFrame.fromEulerAnglesYXZ(newPitch, cy, cz)
        end
    end
    lastCamCF = Camera.CFrame

    -- Fly
    UpdateFly()

    -- ESP
    UpdateESP()

    -- Crosshair
    UpdateCrosshair()

    -- Hitmarker
    UpdateHitmarker(dt)

    -- FPS / Ping overlay
    FPSLabel.Text  = string.format("FPS: %d", fpsCounter)
    PingLabel.Text = string.format("Ping: %d ms", LocalPlayer:GetNetworkPing and math.floor(LocalPlayer:GetNetworkPing() * 1000) or 0)

    -- God mode heartbeat
    ApplyGodMode()

    -- Anti-ragdoll
    ApplyAntiRagdoll()

    -- Auto sprint
    DoAutoSprint()
end)

-- ══════════════════════════════════════════════════════════
--  STEPPED  —  NoClip + Hitboxes
-- ══════════════════════════════════════════════════════════
RunService.Stepped:Connect(function()
    -- NoClip
    if State.NoClipEnabled then
        local char = GetChar(LocalPlayer)
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end

    -- Hitbox expander
    UpdateHitboxes()
end)

-- ══════════════════════════════════════════════════════════
--  INPUT  —  Infinite Jump + Fly toggle
-- ══════════════════════════════════════════════════════════
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = GetHum(LocalPlayer)
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ══════════════════════════════════════════════════════════
--  CHARACTER / PLAYER EVENTS
-- ══════════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function(p)
    if State.ESPEnabled then MakeESP(p) end
end)
Players.PlayerRemoving:Connect(KillESP)

local function OnCharAdded(char)
    char:WaitForChild("Humanoid", 5)
    if State.NoFogEnabled      then SetNoFog(true)       end
    if State.FullbrightEnabled then SetFullbright(true)  end
    if State.SpeedEnabled      then
        local hum = GetHum(LocalPlayer)
        if hum then hum.WalkSpeed = State.WalkSpeed end
    end
    if State.JumpPowerEnabled  then
        local hum = GetHum(LocalPlayer)
        if hum then hum.JumpPower = State.JumpPower end
    end
    if State.AutoRespawn then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                task.wait(0.1)
                LocalPlayer:LoadCharacter()
            end)
        end
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharAdded)
if LocalPlayer.Character then OnCharAdded(LocalPlayer.Character) end

-- ══════════════════════════════════════════════════════════
--  ╔═══════════════════════════════════╗
--  ║           T A B S                ║
--  ╚═══════════════════════════════════╝
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
--  TAB 1  ·  ESP
-- ─────────────────────────────────────────────────────────
local TabESP = Window:CreateTab("👁  ESP", 4483362458)

TabESP:CreateSection("Player Outlines")

TabESP:CreateToggle({
    Name="Enable ESP", CurrentValue=false, Flag="ESP_Enable",
    Callback=function(v)
        State.ESPEnabled = v
        if not v then
            for _, o in pairs(ESPObjects) do
                HideAll(o)
                if o.skeleton then for _, l in ipairs(o.skeleton) do l.Visible = false end end
            end
        end
    end
})
TabESP:CreateToggle({ Name="Health Bars",  CurrentValue=false, Flag="ESP_HP",      Callback=function(v) State.ESPHealthBars = v end })
TabESP:CreateToggle({ Name="Tracers",      CurrentValue=false, Flag="ESP_Tracers", Callback=function(v) State.Tracers = v; State.ESPTracers = v end })
TabESP:CreateToggle({ Name="Skeleton",     CurrentValue=false, Flag="ESP_Skel",    Callback=function(v) State.ESPSkeleton = v end })
TabESP:CreateToggle({ Name="Show Names",   CurrentValue=true,  Flag="ESP_Names",   Callback=function(v) State.ESPNames = v end })
TabESP:CreateToggle({ Name="Show Distance",CurrentValue=true,  Flag="ESP_Dist",    Callback=function(v) State.ESPDistance = v end })
TabESP:CreateToggle({ Name="Team Check (hide teammates)", CurrentValue=false, Flag="ESP_Team", Callback=function(v) State.ESPTeamCheck = v; State.TeamCheck = v end })

TabESP:CreateSection("Appearance")

TabESP:CreateSlider({
    Name="Text Size", Range={10,22}, Increment=1, Suffix=" px",
    CurrentValue=14, Flag="ESP_TxtSz",
    Callback=function(v) State.ESPTextSize = v end
})
TabESP:CreateSlider({
    Name="Max Render Distance", Range={50,2000}, Increment=50, Suffix=" studs",
    CurrentValue=500, Flag="ESP_MaxD",
    Callback=function(v) State.ESPMaxDist = v end
})
TabESP:CreateColorPicker({
    Name="Box / Tracer / Skeleton Color", Color=Color3.fromRGB(220,80,80), Flag="ESP_Color",
    Callback=function(v) State.BoxColor = v end
})

-- ─────────────────────────────────────────────────────────
--  TAB 2  ·  AIMBOT
-- ─────────────────────────────────────────────────────────
local TabAim = Window:CreateTab("🎯  Aimbot", 4483362458)

TabAim:CreateSection("Targeting")

TabAim:CreateToggle({
    Name="Enable Aimbot  (Hold RMB)", CurrentValue=false, Flag="Aim_Enable",
    Callback=function(v) State.AimbotEnabled = v; FOVCircle.Visible = v and State.FOVVisible end
})
TabAim:CreateToggle({
    Name="Silent Aim", CurrentValue=false, Flag="Aim_Silent",
    Callback=function(v) State.SilentAim = v end
})
TabAim:CreateToggle({
    Name="Trigger Bot", CurrentValue=false, Flag="Aim_Trigger",
    Callback=function(v) State.TriggerBot = v end
})
TabAim:CreateToggle({
    Name="Team Check (don't aim at teammates)", CurrentValue=false, Flag="Aim_Team",
    Callback=function(v) State.TeamCheck = v end
})

TabAim:CreateDropdown({
    Name="Target Hitbox",
    Options={"Head","HumanoidRootPart","Torso","UpperTorso","LeftUpperArm","RightUpperArm"},
    CurrentOption={"Head"}, Flag="Aim_Part",
    Callback=function(v) State.AimbotPart = v[1] or "Head" end
})

TabAim:CreateSection("Configuration")

TabAim:CreateSlider({
    Name="FOV Radius", Range={30,600}, Increment=5, Suffix=" px",
    CurrentValue=150, Flag="Aim_FOV",
    Callback=function(v) State.AimbotFOV = v end
})
TabAim:CreateSlider({
    Name="Smoothness  (higher = more natural)", Range={1,20}, Increment=1,
    CurrentValue=7, Flag="Aim_Smooth",
    Callback=function(v) State.AimbotSmooth = 0.26 - (v * 0.012) end
})

TabAim:CreateSection("FOV Indicator")

TabAim:CreateToggle({
    Name="Show FOV Circle", CurrentValue=true, Flag="Aim_FOVVis",
    Callback=function(v) State.FOVVisible = v; FOVCircle.Visible = State.AimbotEnabled and v end
})
TabAim:CreateColorPicker({
    Name="FOV Circle Color", Color=Color3.fromRGB(180,100,255), Flag="Aim_FOVCol",
    Callback=function(v) State.FOVColor = v; FOVCircle.Color = v end
})

-- ─────────────────────────────────────────────────────────
--  TAB 3  ·  COMBAT
-- ─────────────────────────────────────────────────────────
local TabCombat = Window:CreateTab("⚔️  Combat", 4483362458)

TabCombat:CreateSection("Recoil Control")

TabCombat:CreateToggle({
    Name="No Recoil", CurrentValue=false, Flag="Combat_NR",
    Callback=function(v) State.NoRecoilEnabled = v; lastCamCF = nil end
})
TabCombat:CreateSlider({
    Name="Reduction Amount", Range={10,100}, Increment=5, Suffix="%",
    CurrentValue=80, Flag="Combat_NRStr",
    Callback=function(v) State.RecoilStrength = 1 - (v / 100) end
})
TabCombat:CreateLabel("Tip: 75–85% looks the most natural in killcams.")

TabCombat:CreateSection("Hitbox")

TabCombat:CreateToggle({
    Name="Hitbox Expander", CurrentValue=false, Flag="Combat_HBX",
    Callback=function(v) State.HitboxExpander = v end
})
TabCombat:CreateSlider({
    Name="Hitbox Size", Range={2,20}, Increment=1, Suffix=" studs",
    CurrentValue=6, Flag="Combat_HBXSz",
    Callback=function(v) State.HitboxSize = v end
})
TabCombat:CreateLabel("Larger hitbox = easier to hit enemies.")

TabCombat:CreateSection("Defense")

TabCombat:CreateToggle({
    Name="Auto Parry / Block", CurrentValue=false, Flag="Combat_AP",
    Callback=function(v) State.AutoParry = v end
})
TabCombat:CreateLabel("Fires parry remote — may vary by game version.")

-- ─────────────────────────────────────────────────────────
--  TAB 4  ·  MOVEMENT
-- ─────────────────────────────────────────────────────────
local TabMove = Window:CreateTab("🏃  Movement", 4483362458)

TabMove:CreateSection("Walk / Jump")

TabMove:CreateToggle({
    Name="Speed Hack", CurrentValue=false, Flag="Move_Speed",
    Callback=function(v)
        State.SpeedEnabled = v
        local hum = GetHum(LocalPlayer)
        if hum then hum.WalkSpeed = v and State.WalkSpeed or 16 end
    end
})
TabMove:CreateSlider({
    Name="Walk Speed", Range={16,200}, Increment=2, Suffix=" stud/s",
    CurrentValue=40, Flag="Move_WSpdVal",
    Callback=function(v)
        State.WalkSpeed = v
        if State.SpeedEnabled then
            local hum = GetHum(LocalPlayer)
            if hum then hum.WalkSpeed = v end
        end
    end
})
TabMove:CreateToggle({
    Name="Jump Power", CurrentValue=false, Flag="Move_JmpT",
    Callback=function(v)
        State.JumpPowerEnabled = v
        local hum = GetHum(LocalPlayer)
        if hum then hum.JumpPower = v and State.JumpPower or 50 end
    end
})
TabMove:CreateSlider({
    Name="Jump Height", Range={50,500}, Increment=10, Suffix=" stud/s",
    CurrentValue=100, Flag="Move_JmpVal",
    Callback=function(v)
        State.JumpPower = v
        if State.JumpPowerEnabled then
            local hum = GetHum(LocalPlayer)
            if hum then hum.JumpPower = v end
        end
    end
})
TabMove:CreateToggle({
    Name="Infinite Jump", CurrentValue=false, Flag="Move_IJ",
    Callback=function(v) State.InfiniteJump = v end
})
TabMove:CreateToggle({
    Name="Auto Sprint", CurrentValue=false, Flag="Move_AS",
    Callback=function(v) State.AutoSprint = v end
})

TabMove:CreateSection("Advanced Mobility")

TabMove:CreateToggle({
    Name="Fly  (WASD + Space/Shift)", CurrentValue=false, Flag="Move_Fly",
    Callback=function(v)
        State.FlyEnabled = v
        if not v then StopFly() end
    end
})
TabMove:CreateSlider({
    Name="Fly Speed", Range={10,300}, Increment=5, Suffix=" stud/s",
    CurrentValue=50, Flag="Move_FlySpd",
    Callback=function(v) State.FlySpeed = v end
})
TabMove:CreateToggle({
    Name="NoClip  (walk through walls)", CurrentValue=false, Flag="Move_NC",
    Callback=function(v) State.NoClipEnabled = v end
})
TabMove:CreateToggle({
    Name="Anti-Void  (prevent falling out of map)", CurrentValue=false, Flag="Move_AV",
    Callback=function(v) State.AntiVoid = v end
})
TabMove:CreateLabel("Caution: fly + noclip are visible to others.")

-- ─────────────────────────────────────────────────────────
--  TAB 5  ·  VISUALS
-- ─────────────────────────────────────────────────────────
local TabVis = Window:CreateTab("🎨  Visuals", 4483362458)

TabVis:CreateSection("Lighting")

TabVis:CreateToggle({
    Name="Fullbright", CurrentValue=false, Flag="Vis_FB",
    Callback=function(v) State.FullbrightEnabled = v; SetFullbright(v) end
})
TabVis:CreateToggle({
    Name="Remove Fog", CurrentValue=false, Flag="Vis_Fog",
    Callback=function(v) State.NoFogEnabled = v; SetNoFog(v) end
})

TabVis:CreateSection("Camera")

TabVis:CreateSlider({
    Name="Field of View", Range={50,120}, Increment=1, Suffix="°",
    CurrentValue=70, Flag="Vis_FOV",
    Callback=function(v)
        State.CameraFOV = v
        Camera.FieldOfView = v
    end
})

TabVis:CreateSection("Custom Crosshair")

TabVis:CreateToggle({
    Name="Enable Custom Crosshair", CurrentValue=false, Flag="Vis_CH",
    Callback=function(v) State.CustomCrosshair = v end
})
TabVis:CreateSlider({
    Name="Crosshair Size", Range={4,40}, Increment=1, Suffix=" px",
    CurrentValue=12, Flag="Vis_CHSz",
    Callback=function(v) State.CrosshairSize = v end
})
TabVis:CreateSlider({
    Name="Crosshair Gap",  Range={0,20}, Increment=1, Suffix=" px",
    CurrentValue=4, Flag="Vis_CHGap",
    Callback=function(v) State.CrosshairGap = v end
})
TabVis:CreateSlider({
    Name="Crosshair Thickness", Range={1,5}, Increment=1, Suffix=" px",
    CurrentValue=2, Flag="Vis_CHTh",
    Callback=function(v) State.CrosshairThick = v end
})
TabVis:CreateColorPicker({
    Name="Crosshair Color", Color=Color3.fromRGB(255,255,255), Flag="Vis_CHCol",
    Callback=function(v) State.CrosshairColor = v end
})

TabVis:CreateSection("Hit Feedback")

TabVis:CreateToggle({
    Name="Hitmarker", CurrentValue=false, Flag="Vis_HM",
    Callback=function(v) State.HitmarkerEnabled = v end
})

TabVis:CreateSection("Performance Overlay")

local perfVisible = false
TabVis:CreateToggle({
    Name="FPS / Ping Overlay", CurrentValue=false, Flag="Vis_Perf",
    Callback=function(v)
        perfVisible        = v
        FPSLabel.Visible   = v
        PingLabel.Visible  = v
    end
})

-- ─────────────────────────────────────────────────────────
--  TAB 6  ·  PLAYER
-- ─────────────────────────────────────────────────────────
local TabPlayer = Window:CreateTab("🛡️  Player", 4483362458)

TabPlayer:CreateSection("Survival")

TabPlayer:CreateToggle({
    Name="God Mode  (local visual only)", CurrentValue=false, Flag="Plr_God",
    Callback=function(v)
        State.GodModeEnabled = v
        if not v then
            local hum = GetHum(LocalPlayer)
            if hum then hum.MaxHealth = 100; hum.Health = 100 end
        end
    end
})
TabPlayer:CreateToggle({
    Name="Anti-Ragdoll", CurrentValue=false, Flag="Plr_AR",
    Callback=function(v) State.AntiRagdoll = v end
})
TabPlayer:CreateToggle({
    Name="Auto Respawn", CurrentValue=false, Flag="Plr_AutoResp",
    Callback=function(v) State.AutoRespawn = v end
})
TabPlayer:CreateLabel("God mode only affects your local view. Anti-ragdoll prevents physics flinging.")

TabPlayer:CreateSection("Info")

TabPlayer:CreateButton({
    Name="Show My Stats",
    Callback=function()
        local hum = GetHum(LocalPlayer)
        if hum then
            Notify("Player Stats",
                string.format("HP: %.0f / %.0f  |  Speed: %.0f  |  Jump: %.0f",
                hum.Health, hum.MaxHealth, hum.WalkSpeed, hum.JumpPower), 5)
        end
    end
})

-- ─────────────────────────────────────────────────────────
--  TAB 7  ·  MISC
-- ─────────────────────────────────────────────────────────
local TabMisc = Window:CreateTab("🔧  Misc", 4483362458)

TabMisc:CreateSection("Quick Actions")

TabMisc:CreateButton({
    Name="Teleport to Spawn  (0,10,0)",
    Callback=function()
        local root = GetRoot(LocalPlayer)
        if root then root.CFrame = CFrame.new(0, 10, 0) end
        Notify("TravHub", "Teleported to world spawn.", 3)
    end
})

TabMisc:CreateButton({
    Name="Teleport to Nearest Player",
    Callback=function()
        local myRoot = GetRoot(LocalPlayer)
        if not myRoot then return end
        local best, bd = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then
                local r = GetRoot(p)
                if r then
                    local d = Dist3D(myRoot, r)
                    if d < bd then bd, best = d, p end
                end
            end
        end
        if best then
            local r = GetRoot(best)
            if r then
                myRoot.CFrame = r.CFrame + Vector3.new(0, 3, 4)
                Notify("TravHub", "Teleported to " .. best.Name, 3)
            end
        else
            Notify("TravHub", "No other players found.", 3)
        end
    end
})

TabMisc:CreateButton({
    Name="Rejoin Server",
    Callback=function()
        Notify("TravHub", "Rejoining...", 2)
        task.wait(0.5)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

TabMisc:CreateButton({
    Name="Server Hop",
    Callback=function()
        Notify("TravHub", "Hopping to new server...", 2)
        task.wait(0.5)
        local servers = {}
        pcall(function()
            local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local res = game:HttpGet(url)
            local data = game:GetService("HttpService"):JSONDecode(res)
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s.id)
                end
            end
        end)
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        else
            Notify("TravHub", "No available servers found. Rejoining instead.", 4)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end
})

TabMisc:CreateSection("Utilities")

TabMisc:CreateButton({
    Name="Copy Player List",
    Callback=function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(list, p.Name .. " (" .. p.DisplayName .. ")")
        end
        setclipboard(table.concat(list, "\n"))
        Notify("TravHub", "Copied " .. #list .. " players to clipboard.", 3)
    end
})

TabMisc:CreateButton({
    Name="Print All Remote Events (console)",
    Callback=function()
        local found = 0
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                print("[TravHub Remote] " .. v:GetFullName())
                found = found + 1
            end
        end
        Notify("TravHub", "Logged " .. found .. " remotes to console.", 4)
    end
})

TabMisc:CreateButton({
    Name="Clear Unused Effects / Particles",
    Callback=function()
        local count = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                if not v:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
                    v.Enabled = false
                    count = count + 1
                end
            end
        end
        Notify("TravHub", "Disabled " .. count .. " particle emitters.", 3)
    end
})

TabMisc:CreateSection("About")
TabMisc:CreateLabel("TravHub v3.0  ·  Project Delta Edition")
TabMisc:CreateLabel("Personal use only — made for Trav  🔒")
TabMisc:CreateLabel("Stay lowkey. 🤫")

-- ══════════════════════════════════════════════════════════
--  STARTUP
-- ══════════════════════════════════════════════════════════
Rayfield:LoadConfiguration()

task.wait(1.0)

Notify("TravHub v3.0 ⚡", "Project Delta Edition loaded.\n11 features across 7 tabs — stay lowkey 🤫", 6)
