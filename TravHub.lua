-- ╔══════════════════════════════════════════╗
-- ║        TravHub  |  Project Delta         ║
-- ║         Personal Script by Trav          ║
-- ║               Version 2.0               ║
-- ╚══════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer

-- ═══════════════════════════════════════════
--   LOAD RAYFIELD
-- ═══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name              = "TravHub  ·  Project Delta",
    Icon              = 0,
    LoadingTitle      = "TravHub",
    LoadingSubtitle   = "Initializing modules...",
    Theme             = "Amethyst",
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = false,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "TravHub",
        FileName   = "Config"
    },
    KeySystem = false,
})

-- ═══════════════════════════════════════════
--   STATE
-- ═══════════════════════════════════════════
local State = {
    ESPEnabled        = false,
    HealthBars        = false,
    Tracers           = false,
    ESPTextSize       = 14,
    BoxColor          = Color3.fromRGB(220, 80, 80),

    AimbotEnabled     = false,
    AimbotFOV         = 150,
    AimbotSmooth      = 0.07,
    AimbotPart        = "Head",
    FOVColor          = Color3.fromRGB(255, 255, 255),

    NoRecoilEnabled   = false,
    RecoilStrength    = 0.2,

    NoClipEnabled     = false,

    FullbrightEnabled = false,
    NoFogEnabled      = false,
}

local ESPObjects = {}

-- ═══════════════════════════════════════════
--   FOV CIRCLE
-- ═══════════════════════════════════════════
local FOVCircle       = Drawing.new("Circle")
FOVCircle.Visible     = false
FOVCircle.Thickness   = 1.5
FOVCircle.Color       = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled      = false
FOVCircle.NumSides    = 64

-- ═══════════════════════════════════════════
--   UTILITY
-- ═══════════════════════════════════════════
local function GetChar(p)  return p and p.Character end
local function GetRoot(p)  local c = GetChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum(p)   local c = GetChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive(p)  local h = GetHum(p);  return h and h.Health > 0 end

local function W2S(pos)
    local s, v = Workspace.CurrentCamera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), v
end

local function GetClosest()
    local cam    = Workspace.CurrentCamera
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) then
            local c    = GetChar(p)
            local part = c and (c:FindFirstChild(State.AimbotPart) or GetRoot(p))
            if part then
                local sp, onScreen = W2S(part.Position)
                if onScreen then
                    local d = (center - sp).Magnitude
                    if d < State.AimbotFOV and d < bestDist then
                        bestDist, best = d, p
                    end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════
--   ESP
-- ═══════════════════════════════════════════
local function MakeESP(player)
    if ESPObjects[player] then return end
    local function D(t, props)
        local o = Drawing.new(t)
        for k, v in pairs(props) do o[k] = v end
        return o
    end
    ESPObjects[player] = {
        boxOut   = D("Square", {Visible=false, Filled=false, Color=Color3.new(0,0,0), Thickness=3.5}),
        box      = D("Square", {Visible=false, Filled=false, Color=State.BoxColor,    Thickness=1.5}),
        name     = D("Text",   {Visible=false, Center=true,  Outline=true, Color=Color3.new(1,1,1), OutlineColor=Color3.new(0,0,0), Size=14}),
        dist     = D("Text",   {Visible=false, Center=true,  Outline=true, Color=Color3.fromRGB(180,180,180), OutlineColor=Color3.new(0,0,0), Size=11}),
        hpBg     = D("Square", {Visible=false, Filled=true,  Color=Color3.new(0,0,0), Transparency=0.5}),
        hpBar    = D("Square", {Visible=false, Filled=true,  Color=Color3.fromRGB(0,255,0)}),
        tracer   = D("Line",   {Visible=false, Color=State.BoxColor, Thickness=1}),
    }
end

local function KillESP(p)
    if ESPObjects[p] then
        for _, o in pairs(ESPObjects[p]) do o:Remove() end
        ESPObjects[p] = nil
    end
end

local function HideAll(t) for _, o in pairs(t) do o.Visible = false end end

local function UpdateESP()
    local cam    = Workspace.CurrentCamera
    local myRoot = GetRoot(LocalPlayer)
    local bottom = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not ESPObjects[player] then MakeESP(player) end
        local o = ESPObjects[player]

        if not State.ESPEnabled or not IsAlive(player) then HideAll(o); continue end

        local c    = GetChar(player)
        local root = c and c:FindFirstChild("HumanoidRootPart")
        local head = c and c:FindFirstChild("Head")
        local hum  = GetHum(player)
        if not root or not head then HideAll(o); continue end

        local rPos, onScreen = W2S(root.Position)
        local hPos           = W2S(head.Position + Vector3.new(0, 0.7, 0))
        if not onScreen then HideAll(o); continue end

        local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
        local bh   = rPos.Y - hPos.Y
        local bw   = bh * 0.55
        local bx, by = rPos.X - bw / 2, hPos.Y

        o.boxOut.Size = Vector2.new(bw+2,bh+2); o.boxOut.Position = Vector2.new(bx-1,by-1); o.boxOut.Visible = true
        o.box.Color   = State.BoxColor
        o.box.Size    = Vector2.new(bw,bh);     o.box.Position    = Vector2.new(bx,by);      o.box.Visible    = true

        o.name.Text     = player.Name
        o.name.Size     = State.ESPTextSize
        o.name.Position = Vector2.new(rPos.X, by - State.ESPTextSize - 2)
        o.name.Visible  = true

        o.dist.Text     = dist .. "m"
        o.dist.Position = Vector2.new(rPos.X, rPos.Y + 3)
        o.dist.Visible  = true

        if State.HealthBars and hum then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            o.hpBg.Size  = Vector2.new(4,bh);        o.hpBg.Position  = Vector2.new(bx-7,by);  o.hpBg.Visible  = true
            o.hpBar.Color    = Color3.fromRGB(math.floor((1-pct)*255), math.floor(pct*255), 0)
            o.hpBar.Size     = Vector2.new(4,bh*pct)
            o.hpBar.Position = Vector2.new(bx-7, by+bh - bh*pct)
            o.hpBar.Visible  = true
        else
            o.hpBg.Visible  = false
            o.hpBar.Visible = false
        end

        if State.Tracers then
            o.tracer.Color   = State.BoxColor
            o.tracer.From    = bottom
            o.tracer.To      = Vector2.new(rPos.X, rPos.Y)
            o.tracer.Visible = true
        else
            o.tracer.Visible = false
        end
    end
end

-- ═══════════════════════════════════════════
--   NO RECOIL
-- ═══════════════════════════════════════════
local lastCamCF = nil

RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera

    -- FOV circle
    FOVCircle.Position = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    FOVCircle.Radius   = State.AimbotFOV
    FOVCircle.Color    = State.FOVColor
    FOVCircle.Visible  = State.AimbotEnabled

    -- Aimbot
    if State.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosest()
        if target then
            local c    = GetChar(target)
            local part = c and (c:FindFirstChild(State.AimbotPart) or GetRoot(target))
            if part then
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, part.Position), State.AimbotSmooth)
            end
        end
    end

    -- No Recoil: cancel upward pitch drift
    if State.NoRecoilEnabled and lastCamCF then
        local px = select(1, lastCamCF:ToEulerAnglesYXZ())
        local cx, cy, cz = cam.CFrame:ToEulerAnglesYXZ()
        local delta = cx - px
        if delta > 0.0005 then
            local newPitch = cx - delta * (1 - State.RecoilStrength)
            cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromEulerAnglesYXZ(newPitch, cy, cz)
        end
    end
    lastCamCF = cam.CFrame

    UpdateESP()
end)

-- ═══════════════════════════════════════════
--   NOCLIP
-- ═══════════════════════════════════════════
RunService.Stepped:Connect(function()
    if State.NoClipEnabled then
        local c = GetChar(LocalPlayer)
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end end
    end
end)

-- ═══════════════════════════════════════════
--   FULLBRIGHT / FOG
-- ═══════════════════════════════════════════
local _oA, _oO, _oB, _oC
local function SetFullbright(on)
    if on then
        _oA = Lighting.Ambient; _oO = Lighting.OutdoorAmbient
        _oB = Lighting.Brightness; _oC = Lighting.ClockTime
        Lighting.Ambient = Color3.new(1,1,1); Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Brightness = 2; Lighting.ClockTime = 14
    else
        if _oA then Lighting.Ambient = _oA end
        if _oO then Lighting.OutdoorAmbient = _oO end
        if _oB then Lighting.Brightness = _oB end
        if _oC then Lighting.ClockTime = _oC end
    end
end

local function SetNoFog(on)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then obj.Density = on and 0 or 0.395; obj.Haze = on and 0 or 2.8 end
        if obj:IsA("FogEffect")  then obj.Enabled = not on end
    end
end

Players.PlayerAdded:Connect(function(p) if State.ESPEnabled then MakeESP(p) end end)
Players.PlayerRemoving:Connect(KillESP)
LocalPlayer.CharacterAdded:Connect(function()
    if State.NoFogEnabled      then SetNoFog(true)      end
    if State.FullbrightEnabled then SetFullbright(true) end
end)

-- ══════════════════════════════════════════════════════════
--   TABS
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────
--  TAB 1  ·  ESP
-- ─────────────────────────────────────────
local TabESP = Window:CreateTab("ESP", 4483362458)

TabESP:CreateSection("Player Outlines")

TabESP:CreateToggle({
    Name="Enable ESP", CurrentValue=false, Flag="ESP_Enable",
    Callback=function(v)
        State.ESPEnabled = v
        if not v then for _, o in pairs(ESPObjects) do HideAll(o) end end
    end
})

TabESP:CreateToggle({
    Name="Health Bars", CurrentValue=false, Flag="ESP_HP",
    Callback=function(v) State.HealthBars = v end
})

TabESP:CreateToggle({
    Name="Tracers", CurrentValue=false, Flag="ESP_Tracers",
    Callback=function(v) State.Tracers = v end
})

TabESP:CreateSection("Appearance")

TabESP:CreateSlider({
    Name="Text Size", Range={10,22}, Increment=1, Suffix=" px",
    CurrentValue=14, Flag="ESP_TxtSz",
    Callback=function(v) State.ESPTextSize = v end
})

TabESP:CreateColorPicker({
    Name="Box & Tracer Color", Color=Color3.fromRGB(220,80,80), Flag="ESP_Color",
    Callback=function(v) State.BoxColor = v end
})

-- ─────────────────────────────────────────
--  TAB 2  ·  AIMBOT
-- ─────────────────────────────────────────
local TabAim = Window:CreateTab("Aimbot", 4483362458)

TabAim:CreateSection("Targeting")

TabAim:CreateToggle({
    Name="Enable Aimbot  (Hold RMB)", CurrentValue=false, Flag="Aim_Enable",
    Callback=function(v) State.AimbotEnabled = v; FOVCircle.Visible = v end
})

TabAim:CreateDropdown({
    Name="Target Hitbox",
    Options={"Head","HumanoidRootPart","Torso","UpperTorso"},
    CurrentOption={"Head"}, Flag="Aim_Part",
    Callback=function(v) State.AimbotPart = v[1] or "Head" end
})

TabAim:CreateSection("Configuration")

TabAim:CreateSlider({
    Name="FOV Radius", Range={30,500}, Increment=5, Suffix=" px",
    CurrentValue=150, Flag="Aim_FOV",
    Callback=function(v) State.AimbotFOV = v end
})

TabAim:CreateSlider({
    Name="Smoothness  (higher = more natural)", Range={1,20}, Increment=1,
    CurrentValue=7, Flag="Aim_Smooth",
    Callback=function(v) State.AimbotSmooth = 0.26 - (v * 0.012) end
})

TabAim:CreateSection("FOV Circle")

TabAim:CreateColorPicker({
    Name="FOV Color", Color=Color3.fromRGB(255,255,255), Flag="Aim_FOVCol",
    Callback=function(v) State.FOVColor = v; FOVCircle.Color = v end
})

-- ─────────────────────────────────────────
--  TAB 3  ·  COMBAT
-- ─────────────────────────────────────────
local TabCombat = Window:CreateTab("Combat", 4483362458)

TabCombat:CreateSection("Recoil Control")

TabCombat:CreateToggle({
    Name="No Recoil", CurrentValue=false, Flag="Combat_NR",
    Callback=function(v) State.NoRecoilEnabled = v; lastCamCF = nil end
})

TabCombat:CreateSlider({
    Name="Reduction Amount", Range={10,100}, Increment=5, Suffix="%",
    CurrentValue=80, Flag="Combat_NRStr",
    Callback=function(v)
        -- 100% = fully cancel recoil, 10% = barely cancel
        State.RecoilStrength = 1 - (v / 100)
    end
})

TabCombat:CreateLabel("Tip: 75-85% looks the most natural.")

-- ─────────────────────────────────────────
--  TAB 4  ·  MOVEMENT
-- ─────────────────────────────────────────
local TabMove = Window:CreateTab("Movement", 4483362458)

TabMove:CreateSection("Mobility")

TabMove:CreateToggle({
    Name="NoClip", CurrentValue=false, Flag="Move_NC",
    Callback=function(v) State.NoClipEnabled = v end
})

TabMove:CreateLabel("Use NoClip carefully — others can see.")

-- ─────────────────────────────────────────
--  TAB 5  ·  VISUALS
-- ─────────────────────────────────────────
local TabVis = Window:CreateTab("Visuals", 4483362458)

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
    Name="Field of View", Range={70,120}, Increment=1, Suffix="°",
    CurrentValue=70, Flag="Vis_FOV",
    Callback=function(v) Workspace.CurrentCamera.FieldOfView = v end
})

-- ─────────────────────────────────────────
--  TAB 6  ·  MISC
-- ─────────────────────────────────────────
local TabMisc = Window:CreateTab("Misc", 4483362458)

TabMisc:CreateSection("Utilities")

TabMisc:CreateButton({
    Name="Teleport to Spawn",
    Callback=function()
        local r = GetRoot(LocalPlayer)
        if r then r.CFrame = CFrame.new(0, 10, 0) end
        Rayfield:Notify({Title="TravHub", Content="Teleported to spawn.", Duration=3})
    end
})

TabMisc:CreateButton({
    Name="Rejoin Server",
    Callback=function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

TabMisc:CreateButton({
    Name="Copy Player List",
    Callback=function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(list, p.Name .. " (" .. p.DisplayName .. ")")
        end
        setclipboard(table.concat(list, "\n"))
        Rayfield:Notify({Title="TravHub", Content="Copied to clipboard!", Duration=3})
    end
})

TabMisc:CreateSection("About")
TabMisc:CreateLabel("TravHub v2.0  ·  Project Delta")
TabMisc:CreateLabel("Personal use only — made for Trav")

-- ═══════════════════════════════════════════
--   STARTUP NOTIFY
-- ═══════════════════════════════════════════
task.wait(1.2)
Rayfield:Notify({
    Title    = "TravHub v2.0",
    Content  = "Loaded. Stay lowkey 🤫",
    Duration = 5,
    Image    = 4483362458,
})

Rayfield:LoadConfiguration()
