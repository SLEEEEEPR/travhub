-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  ████████╗██████╗  █████╗ ██╗   ██╗    ██╗  ██╗██╗   ██╗██████╗  ║
-- ║     ██╔══╝██╔══██╗██╔══██╗██║   ██║    ██║  ██║██║   ██║██╔══██╗ ║
-- ║     ██║   ██████╔╝███████║██║   ██║    ███████║██║   ██║██████╔╝ ║
-- ║     ██║   ██╔══██╗██╔══██║╚██╗ ██╔╝    ██╔══██║██║   ██║██╔══██╗ ║
-- ║     ██║   ██║  ██║██║  ██║ ╚████╔╝     ██║  ██║╚██████╔╝██████╔╝ ║
-- ║     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ║
-- ║      Project Delta · v3.8 · Crystal Edition · ZERO STUTTER          ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- ══ v3.6 FINAL CHANGELOG (all bugs fixed from v3.5 audit) ═══════════
--  FIX-01  CH.eye1.Transparent → CH.eye1.Transparency (typo broke happy face)
--  FIX-02  Player/AI ESP box height clamped: mmax(rPos.Y-hPos.Y, 30) — no
--          more inverted/zero-height boxes when player is prone or off-angle
--  FIX-03  LocalPlayer:GetMouse() cached once at startup — not called per frame
--  FIX-04  AntiRagdoll: moved to CharacterAdded signal — no more per-frame
--          GetDescendants() traversal (was a hidden GC killer)
--  FIX-05  GodMode: hooks Humanoid.HealthChanged instead of writing every
--          frame — far less detectable, zero repeated property spam
--  FIX-06  Loot label text cached via _lastName — no string alloc per frame
--  FIX-07  UpdateAIESP dead param removed — rainbow computed internally
--  FIX-08  sLen dead variable removed from Sniper crosshair
--  FIX-09  NoRecoil moved to Heartbeat connection — decoupled from render
--
-- ══ ANTICHEAT BYPASS (Project Delta specific) ════════════════════════
--  AC-01   HitboxExpander: client-local Part updated via RunService.Heartbeat
--          with blank name, no WeldConstraint server physics joint — zero
--          server replication footprint, part lives only in LocalPlayer.Character
--          via LocalScript scope; network ownership stays client.
--  AC-02   GodMode: HealthChanged hook with 1-frame debounce, MaxHealth set
--          once to a high but plausible value (1e6), health topped-up only on
--          actual damage event — no per-frame property spam.
--  AC-03   VIM TriggerBot: mouse position seeded from actual cursor coordinates
--          so event coords match real mouse pos — bypasses coord-mismatch checks.
--  AC-04   Aimbot Camera.CFrame writes wrapped in pcall so AC-injected
--          metamethods can't crash/detect via error propagation.
--  AC-05   NoRecoil on Heartbeat with jitter ±0.001 rad added to compensate
--          for perfectly-zero recoil signature (perfect=detectable).
--  AC-06   All Drawing API calls are client-only — no server events fired,
--          no RemoteEvent touched, zero network trace from ESP system.
--  AC-07   Hitbox part uses RunService:IsClient() guard and is never Parented
--          to workspace directly — stays under LocalPlayer.Character which is
--          replicated but the invisible 0-mass transparent part is normal in
--          many games' character rigs.
--  AC-08   Script identity preserved: no getfenv/setfenv calls, no __index
--          hooks on game/Players that ACs scan for.
-- ════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════
--  SERVICES  (all cached at top, zero GetService in hot path)
-- ══════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local _vimOk,_vimSvc   = pcall(function() return game:GetService("VirtualInputManager") end)
local VIM              = _vimOk and _vimSvc or nil
local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera
local Mouse            = LocalPlayer:GetMouse()   -- FIX-03: cached once

-- ══════════════════════════════════════════
--  MATH / TABLE LOCALS  (hot path: no global table index)
-- ══════════════════════════════════════════
local mfloor  = math.floor
local mceil   = math.ceil
local mclamp  = math.clamp
local msin    = math.sin
local mcos    = math.cos
local matan2  = math.atan2
local mrad    = math.rad
local mrandom = math.random
local mhuge   = math.huge
local mmax    = math.max
local mabs    = math.abs
local pi      = math.pi
local tinsert = table.insert
local sfmt    = string.format

-- ══════════════════════════════════════════
--  SAFE WRAPPER
-- ══════════════════════════════════════════
local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[TravHub] "..tostring(err)) end
end

-- ══════════════════════════════════════════
--  DRAWING
-- ══════════════════════════════════════════
local function NewDraw(t, props)
    local o = Drawing.new(t)
    for k,v in pairs(props) do o[k]=v end
    return o
end

-- ══════════════════════════════════════════
--  AMETHYST PALETTE
-- ══════════════════════════════════════════
local AME = {
    deep   = Color3.fromRGB(38, 12, 72),
    dark   = Color3.fromRGB(64, 20,110),
    mid    = Color3.fromRGB(120,50,200),
    bright = Color3.fromRGB(180,100,255),
    light  = Color3.fromRGB(220,160,255),
    white  = Color3.fromRGB(240,220,255),
    gold   = Color3.fromRGB(255,210,100),
    glow   = Color3.fromRGB(200,130,255),
}

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  KEY AUTH  ✦  TravHub v3.8  ·  Crystal Edition                   ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- ══ SETUP (fill in your 3 values from keyauth.cc/app) ════════════════
--   1. Go to keyauth.cc/app → select your application
--   2. Copy the three values below from your app's dashboard
--   3. Generate license keys at keyauth.cc/app → Licenses tab
--      Hand them out via Discord or sell via Sellix
-- ═════════════════════════════════════════════════════════════════════
local KA_NAME    = "Mermorz's Application"    -- App name (shown above the secret on dashboard)
local KA_OWNERID = "hLIkGaxr8u"   -- Account Settings → Owner ID (top-right profile)
local KA_SECRET  = "7f2253965f73618809126cba1ff66693c04f82888535c82709f9c17c9ceafdc1" -- Licenses tab → blurred text (App secret)
local KA_VER     = "1.0"             -- Leave as 1.0 unless you changed it on dashboard
local KA_URL     = "https://keyauth.win/api/1.2/"

-- ══════════════════════════════════════════
--  REQUEST WRAPPER  (executor compatibility)
--  Tries syn.request → request → http.request in order.
--  All three accept the same {Url,Method,Headers,Body} table.
-- ══════════════════════════════════════════
local function _kaRequest(opts)
    local fn = (syn and syn.request)
             or (type(request)=="function" and request)
             or (http and http.request)
             or (http_request)
             or nil
    if not fn then
        return nil, "No HTTP request function found on this executor"
    end
    local ok, res = pcall(fn, opts)
    if not ok then return nil, tostring(res) end
    return res, nil
end

-- ══════════════════════════════════════════
--  KEYAUTH API  (2-step: init → license login)
-- ══════════════════════════════════════════
local _kaSession = nil  -- set after successful init

local function _kaInit()
    -- Step 1: initialise session, get sessionid back
    local guid = HttpService:GenerateGUID(false):sub(1,32)  -- ≤36 chars per KA spec
    local body = ("type=init&ver=%s&hash=&enckey=%s&name=%s&ownerid=%s"):format(
        KA_VER,
        HttpService:UrlEncode(guid),
        HttpService:UrlEncode(KA_NAME),
        HttpService:UrlEncode(KA_OWNERID)
    )
    local res, err = _kaRequest({
        Url     = KA_URL,
        Method  = "POST",
        Headers = {["Content-Type"]="application/x-www-form-urlencoded"},
        Body    = body,
    })
    if err or not res then
        return false, "Network error: "..(err or "no response")
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then
        return false, "Bad server response during init"
    end
    if not data.success then
        return false, tostring(data.message or "Init failed")
    end
    _kaSession = data.sessionid
    return true, "OK"
end

local function _kaLicense(key)
    -- Step 2: submit license key against the active session
    if not _kaSession then
        return false, "Session not initialised"
    end
    -- Use UserId as HWID — best we can do from inside Roblox
    local hwid = tostring(LocalPlayer.UserId)
    local body = ("type=license&key=%s&hwid=%s&sessionid=%s&name=%s&ownerid=%s"):format(
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(hwid),
        HttpService:UrlEncode(_kaSession),
        HttpService:UrlEncode(KA_NAME),
        HttpService:UrlEncode(KA_OWNERID)
    )
    local res, err = _kaRequest({
        Url     = KA_URL,
        Method  = "POST",
        Headers = {["Content-Type"]="application/x-www-form-urlencoded"},
        Body    = body,
    })
    if err or not res then
        return false, "Network error: "..(err or "no response")
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then
        return false, "Bad server response"
    end
    return data.success == true, tostring(data.message or (data.success and "Key accepted!" or "Invalid key"))
end

-- ══════════════════════════════════════════
--  KEY GATE UI  (amethyst-themed, blocks until validated)
-- ══════════════════════════════════════════
local _keyPassed = false

do
    local _vp  = Camera.ViewportSize
    local _scx = _vp.X * 0.5
    local _scy = _vp.Y * 0.5

    -- Try to load saved key from disk
    local _savedKey = ""
    pcall(function()
        if isfile and isfile("TravHub_v38_KAKey.txt") then
            _savedKey = readfile("TravHub_v38_KAKey.txt"):gsub("%s+", "")
        end
    end)

    -- ── Panel geometry ─────────────────────────────────────────────────────────
    local _pW, _pH = 490, 250
    local _pX, _pY = _scx - _pW*0.5, _scy - _pH*0.5

    -- ── Drawing decorations (background, borders, title) ──────────────────────
    local _bg    = NewDraw("Square",{Visible=true,Filled=true, Color=Color3.new(0,0,0),Transparency=0.30,Position=Vector2.new(0,0),        Size=Vector2.new(_vp.X,_vp.Y)})
    local _panel = NewDraw("Square",{Visible=true,Filled=true, Color=AME.deep,         Transparency=0.06,Position=Vector2.new(_pX,_pY),    Size=Vector2.new(_pW,_pH)})
    local _bord  = NewDraw("Square",{Visible=true,Filled=false,Color=AME.mid,          Thickness=2,     Position=Vector2.new(_pX,_pY),    Size=Vector2.new(_pW,_pH)})
    local _ibord = NewDraw("Square",{Visible=true,Filled=false,Color=AME.dark,         Thickness=1,     Position=Vector2.new(_pX+4,_pY+4),Size=Vector2.new(_pW-8,_pH-8)})
    local _crys = {
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX,     _pY),     To=Vector2.new(_pX+22,    _pY)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX,     _pY),     To=Vector2.new(_pX,       _pY+22)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX+_pW, _pY),     To=Vector2.new(_pX+_pW-22,_pY)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX+_pW, _pY),     To=Vector2.new(_pX+_pW,   _pY+22)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX,     _pY+_pH), To=Vector2.new(_pX+22,    _pY+_pH)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX,     _pY+_pH), To=Vector2.new(_pX,       _pY+_pH-22)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX+_pW, _pY+_pH), To=Vector2.new(_pX+_pW-22,_pY+_pH)}),
        NewDraw("Line",{Visible=true,Thickness=1.5,Color=AME.bright,From=Vector2.new(_pX+_pW, _pY+_pH), To=Vector2.new(_pX+_pW,   _pY+_pH-22)}),
    }
    local _ttl  = NewDraw("Text",{Visible=true,Text="TRAV HUB",Size=40,Center=true,Outline=true,OutlineColor=AME.dark,Color=AME.bright,Position=Vector2.new(_scx,_pY+12),Font=Drawing.Fonts.GothamBold})
    local _sub  = NewDraw("Text",{Visible=true,Text="Project Delta  ·  Crystal Edition  ·  v3.8",Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.light,Position=Vector2.new(_scx,_pY+56),Font=Drawing.Fonts.Gotham})
    local _sep  = NewDraw("Line",{Visible=true,Color=AME.mid,Thickness=1,Transparency=0.45,From=Vector2.new(_pX+24,_pY+74),To=Vector2.new(_pX+_pW-24,_pY+74)})
    local _step = NewDraw("Text",{Visible=true,Text="⟳  Connecting to KeyAuth...",Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.light,Position=Vector2.new(_scx,_pY+82),Font=Drawing.Fonts.Gotham})
    local _prmpt= NewDraw("Text",{Visible=false,Text="Enter your license key:",Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.white,Position=Vector2.new(_scx,_pY+100),Font=Drawing.Fonts.Gotham})
    local _hint = NewDraw("Text",{Visible=true,Text="Please wait...",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(120,110,155),Position=Vector2.new(_scx,_pY+_pH-22),Font=Drawing.Fonts.Gotham})

    local _allDrawings = {_bg,_panel,_bord,_ibord,_ttl,_sub,_sep,_step,_prmpt,_hint}
    for _,c in ipairs(_crys) do tinsert(_allDrawings,c) end

    -- ── Real ScreenGui TextBox for input (native paste/typing support) ─────────
    local _gui = Instance.new("ScreenGui")
    _gui.Name = "TravHubKeyGate"
    _gui.ResetOnSpawn = false
    _gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() _gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)

    -- Invisible frame sized to panel
    local _frame = Instance.new("Frame")
    _frame.Size = UDim2.new(0, _pW, 0, _pH)
    _frame.Position = UDim2.new(0, _pX, 0, _pY)
    _frame.BackgroundTransparency = 1
    _frame.BorderSizePixel = 0
    _frame.Parent = _gui

    -- TextBox positioned over the input area
    local _tb = Instance.new("TextBox")
    _tb.Size = UDim2.new(0, 410, 0, 34)
    _tb.Position = UDim2.new(0.5, -205, 0, 118)
    _tb.BackgroundColor3 = Color3.fromRGB(28, 8, 58)
    _tb.BackgroundTransparency = 0.18
    _tb.BorderSizePixel = 0
    _tb.TextColor3 = Color3.fromRGB(255, 255, 255)
    _tb.PlaceholderText = "Paste or type your key here..."
    _tb.PlaceholderColor3 = Color3.fromRGB(100, 85, 130)
    _tb.Font = Enum.Font.Gotham
    _tb.TextSize = 14
    _tb.ClearTextOnFocus = false
    _tb.TextTruncate = Enum.TextTruncate.AtEnd
    _tb.Visible = false
    _tb.Parent = _frame

    -- Styled border around TextBox
    local _tbStroke = Instance.new("UIStroke")
    _tbStroke.Color = AME.mid
    _tbStroke.Thickness = 1.5
    _tbStroke.Parent = _tb

    local _busy     = false
    local _attempts = 0
    local _inputReady = false

    local function _destroyAll()
        for _,o in ipairs(_allDrawings) do pcall(function() o:Remove() end) end
        pcall(function() _gui:Destroy() end)
    end

    local function _fadeOut()
        for _=0,20 do
            for _,o in ipairs(_allDrawings) do
                pcall(function() o.Transparency = math.min((o.Transparency or 0)+0.07,1) end)
            end
            pcall(function() _tb.BackgroundTransparency = math.min(_tb.BackgroundTransparency+0.07,1) end)
            pcall(function() _tb.TextTransparency = math.min((_tb.TextTransparency or 0)+0.07,1) end)
            task.wait(0.011)
        end
        _destroyAll()
        _keyPassed = true
    end

    local function _setHint(txt, col)
        _hint.Text = txt; _hint.Color = col
    end

    local function _validate(key)
        local k = key:gsub("%s+","")
        if _busy or #k < 4 then return end
        _busy = true
        _tb.Visible = false
        _tbStroke.Color = AME.light
        _setHint("⟳  Checking key...", AME.light)

        task.spawn(function()
            local ok, msg = _kaLicense(k)
            if ok then
                pcall(function() if writefile then writefile("TravHub_v38_KAKey.txt", k) end end)
                _tbStroke.Color = Color3.fromRGB(80,255,120)
                _setHint("✦  Key accepted — loading hub...  ✦", Color3.fromRGB(80,255,120))
                task.wait(0.7)
                _fadeOut()
            else
                _attempts += 1
                _setHint(("✗  %s  (%d attempt%s)"):format(msg,_attempts,_attempts~=1 and "s" or ""), Color3.fromRGB(255,80,80))
                _tbStroke.Color = Color3.fromRGB(255,80,80)
                _tb.Text = ""
                _tb.Visible = true
                task.spawn(function() pcall(function() _tb:CaptureFocus() end) end)
                _busy = false
                task.wait(2.8)
                if not _keyPassed then
                    _tbStroke.Color = AME.mid
                    _setHint("Click the box, type or paste your key, press ENTER", Color3.fromRGB(120,110,155))
                end
            end
        end)
    end

    -- Enter key submits
    _tb.FocusLost:Connect(function(enterPressed)
        if enterPressed and not _busy then
            _validate(_tb.Text)
        end
    end)

    local function _showInputUI()
        _step.Visible  = false
        _prmpt.Visible = true
        _tb.Visible    = true
        task.spawn(function() pcall(function() _tb:CaptureFocus() end) end)
        _setHint("Click the box, type or paste your key, press ENTER", Color3.fromRGB(120,110,155))
    end

    -- ── Phase 1: init KeyAuth in background ────────────────────────────────────
    task.spawn(function()
        local initOk, initMsg = _kaInit()
        if not initOk then
            _step.Text  = "✗  "..initMsg
            _step.Color = Color3.fromRGB(255,100,100)
            _setHint("Could not reach KeyAuth — check connection.", Color3.fromRGB(255,100,100))
            task.wait(3)
            initOk, initMsg = _kaInit()
            if not initOk then
                warn("[TravHub KeyAuth] Init failed: "..initMsg)
                _fadeOut(); return
            end
        end

        _step.Text  = "✦  Connected to KeyAuth"
        _step.Color = Color3.fromRGB(100,255,160)
        task.wait(0.4)
        _inputReady = true

        if _savedKey ~= "" then
            -- Auto-validate saved key silently
            _setHint("⟳  Checking saved key...", AME.light)
            _validate(_savedKey)
        else
            _showInputUI()
        end
    end)

    -- Block until key passes
    while not _keyPassed do task.wait(0.05) end
end  -- end key gate scope

-- ══════════════════════════════════════════
--  FRAME TICK  (single read per RenderStepped, shared by all rainbow callers)
-- ══════════════════════════════════════════
local _frameTick = 0
local function RainbowHSV(speed, offset)
    return Color3.fromHSV(((_frameTick*(speed or 1)+(offset or 0))%1), 1, 1)
end

-- ══════════════════════════════════════════
--  VIEWPORT CACHE
-- ══════════════════════════════════════════
local VP    = Camera.ViewportSize
local VP_CX = VP.X*0.5
local VP_CY = VP.Y*0.5
local VP_BOT= Vector2.new(VP_CX, VP.Y)
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    VP=Camera.ViewportSize; VP_CX=VP.X*0.5; VP_CY=VP.Y*0.5
    VP_BOT=Vector2.new(VP_CX,VP.Y)
end)

-- ══════════════════════════════════════════
--  BOOT ANIMATION
-- ══════════════════════════════════════════
local function PlayBootAnimation()
    local vp=Camera.ViewportSize; local cx=vp.X/2; local cy=vp.Y/2
    local function easeOut(t) return 1-(1-t)^3 end
    local function easeInOut(t) return t<0.5 and 4*t^3 or 1-(-2*t+2)^3/2 end
    local function lerp(a,b,t) return a+(b-a)*t end
    local bg=NewDraw("Square",{Visible=true,Filled=true,Color=Color3.new(0,0,0),Transparency=0,Position=Vector2.new(0,0),Size=Vector2.new(vp.X,vp.Y)})
    local pW,pH=540,260; local pX=cx-pW/2; local pY=cy-pH/2
    local panelBg    =NewDraw("Square",{Visible=false,Filled=true, Color=AME.deep,Transparency=0.08,Position=Vector2.new(pX,pY),    Size=Vector2.new(pW,pH)})
    local panelBorder=NewDraw("Square",{Visible=false,Filled=false,Color=AME.mid, Thickness=2,      Position=Vector2.new(pX,pY),    Size=Vector2.new(pW,pH)})
    local panelInner =NewDraw("Square",{Visible=false,Filled=false,Color=AME.dark,Thickness=1,      Position=Vector2.new(pX+4,pY+4),Size=Vector2.new(pW-8,pH-8)})
    local crystalDefs={
        {Vector2.new(pX-2,pY-2),  Vector2.new(pX-20,pY-36), Vector2.new(pX+16,pY-2),  AME.bright},
        {Vector2.new(pX+12,pY-2), Vector2.new(pX+24,pY-24), Vector2.new(pX+36,pY-2),  AME.mid},
        {Vector2.new(pX-2,pY+12), Vector2.new(pX-22,pY+32), Vector2.new(pX-2,pY+30),  AME.light},
        {Vector2.new(pX+pW+2,pY-2),  Vector2.new(pX+pW+20,pY-36), Vector2.new(pX+pW-16,pY-2), AME.bright},
        {Vector2.new(pX+pW-12,pY-2), Vector2.new(pX+pW-24,pY-24), Vector2.new(pX+pW-36,pY-2), AME.mid},
        {Vector2.new(pX-2,pY+pH+2),  Vector2.new(pX-20,pY+pH+36), Vector2.new(pX+16,pY+pH+2),  AME.bright},
        {Vector2.new(pX+pW+2,pY+pH+2), Vector2.new(pX+pW+20,pY+pH+36), Vector2.new(pX+pW-16,pY+pH+2), AME.mid},
        {Vector2.new(cx-8,pY-2),  Vector2.new(cx,pY-22),    Vector2.new(cx+8,pY-2),   AME.light},
        {Vector2.new(cx-8,pY+pH+2), Vector2.new(cx,pY+pH+22), Vector2.new(cx+8,pY+pH+2), AME.light},
    }
    local crystalLines={}
    for _,c in ipairs(crystalDefs) do
        tinsert(crystalLines,{
            NewDraw("Line",{Visible=false,Color=c[4],Thickness=1.5,From=c[1],To=c[2]}),
            NewDraw("Line",{Visible=false,Color=c[4],Thickness=1.5,From=c[2],To=c[3]}),
            NewDraw("Line",{Visible=false,Color=c[4],Thickness=1.5,From=c[3],To=c[1]}),
        })
    end
    local titleGlow  =NewDraw("Text",{Visible=false,Text="TRAV HUB",Size=58,Center=true,Outline=false,Color=AME.mid,Transparency=0.8,Position=Vector2.new(cx,cy-66),Font=Drawing.Fonts.GothamBold})
    local titleShadow=NewDraw("Text",{Visible=false,Text="TRAV HUB",Size=52,Center=true,Outline=false,Color=AME.deep,Position=Vector2.new(cx+2,cy-62),Font=Drawing.Fonts.GothamBold})
    local titleText  =NewDraw("Text",{Visible=false,Text="TRAV HUB",Size=52,Center=true,Outline=true,OutlineColor=AME.dark,Color=AME.bright,Position=Vector2.new(cx,cy-64),Font=Drawing.Fonts.GothamBold})
    local subText    =NewDraw("Text",{Visible=false,Text="Project Delta  ·  Crystal Edition  ·  v3.8",Size=14,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.light,Position=Vector2.new(cx,cy-18),Font=Drawing.Fonts.Gotham})
    local sepLine    =NewDraw("Line", {Visible=false,Color=AME.mid,Thickness=1,From=Vector2.new(cx-190,cy+4),To=Vector2.new(cx+190,cy+4)})
    local sepDotL    =NewDraw("Circle",{Visible=false,Filled=true,Color=AME.bright,Radius=3,NumSides=12,Thickness=0,Position=Vector2.new(cx-190,cy+4)})
    local sepDotR    =NewDraw("Circle",{Visible=false,Filled=true,Color=AME.bright,Radius=3,NumSides=12,Thickness=0,Position=Vector2.new(cx+190,cy+4)})
    local byText     =NewDraw("Text", {Visible=false,Text="v3.8  ·  by Trav  ·  Zero Stutter Edition",Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.white,Position=Vector2.new(cx,cy+16),Font=Drawing.Fonts.Gotham})
    local barW=320; local barH=5; local barX=cx-barW/2; local barY=pY+pH-42
    local barBg  =NewDraw("Square",{Visible=false,Filled=true,Color=AME.dark,Position=Vector2.new(barX,barY),Size=Vector2.new(barW,barH)})
    local barFill=NewDraw("Square",{Visible=false,Filled=true,Color=AME.bright,Position=Vector2.new(barX,barY),Size=Vector2.new(0,barH)})
    local loadTxt=NewDraw("Text",  {Visible=false,Text="",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.glow,Position=Vector2.new(cx,barY+12),Font=Drawing.Fonts.Gotham})
    local msgs={"Initialising Drawing API...","Loading ESP systems...","Calibrating aimbot...","Configuring zoom optics...","Building loot scanner...","Encrypting session...","✦  Ready  ✦"}
    for i=0,20 do
        local t=i/20
        bg.Transparency=1-easeOut(t)*0.93
        panelBg.Visible=true; panelBorder.Visible=true; panelInner.Visible=true
        panelBg.Transparency=1-easeOut(t)*0.92
        panelBorder.Transparency=1-easeOut(t)
        panelInner.Transparency=1-easeOut(t)
        task.wait(0.013)
    end
    for _,set in ipairs(crystalLines) do for _,l in ipairs(set) do l.Visible=true end task.wait(0.018) end
    sepLine.Visible=true; sepDotL.Visible=true; sepDotR.Visible=true; task.wait(0.06)
    titleGlow.Visible=true; task.wait(0.05)
    titleShadow.Visible=true; task.wait(0.03)
    titleText.Visible=true; task.wait(0.08)
    subText.Visible=true; task.wait(0.06)
    byText.Visible=true; task.wait(0.10)
    barBg.Visible=true; barFill.Visible=true; loadTxt.Visible=true
    for idx,msg in ipairs(msgs) do
        loadTxt.Text=msg
        local sp=(idx-1)/#msgs; local ep=idx/#msgs
        for j=0,22 do
            local pct=lerp(sp,ep,easeInOut(j/22))
            barFill.Size=Vector2.new(barW*pct,barH)
            titleGlow.Transparency=0.72+msin(tick()*1.8)*0.14
            task.wait(0.011)
        end
        task.wait(0.04)
    end
    barFill.Size=Vector2.new(barW,barH); loadTxt.Color=AME.light; task.wait(0.45)
    local all={bg,panelBg,panelBorder,panelInner,titleGlow,titleShadow,titleText,subText,sepLine,sepDotL,sepDotR,byText,barBg,barFill,loadTxt}
    for _,set in ipairs(crystalLines) do for _,l in ipairs(set) do tinsert(all,l) end end
    for i=0,24 do
        local fade=easeOut(i/24)
        for _,o in ipairs(all) do pcall(function() o.Transparency=math.min((o.Transparency or 0)+fade*0.12,1) end) end
        task.wait(0.011)
    end
    for _,o in ipairs(all) do pcall(function() o:Remove() end) end
end
Safe(PlayBootAnimation)

-- ══════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window   = Rayfield:CreateWindow({
    Name="TravHub  ✦  Project Delta",
    Icon=0,
    LoadingTitle="TravHub  v3.8",
    LoadingSubtitle="Crystal Edition  ·  Zero Stutter Edition",
    Theme="Amethyst",
    DisableRayfieldPrompts=true,
    DisableBuildWarnings=true,
    ConfigurationSaving={Enabled=true,FolderName="TravHub_Delta",FileName="Config_v38"},
    KeySystem=false,
})

-- ══════════════════════════════════════════
--  GLOBAL STATE
-- ══════════════════════════════════════════
local State = {
    -- Player ESP
    ESPEnabled=false, ESPHealthBars=false, ESPTracers=false,
    ESPNames=true, ESPDistance=true, ESPWeapon=true,
    ESPSkeleton=false, ESPMaxDist=500, ESPTextSize=14,
    BoxColor=Color3.fromRGB(220,80,80), ESPRainbow=false, ESPTeamCheck=false,
    ESPFillBox=true, ESPCornerBox=false, ESPBoxEnabled=true,

    -- AI ESP
    AIESPEnabled=false, AIBoxColor=Color3.fromRGB(255,160,30),
    AIESPNames=true, AIESPHealth=true, AIESPTracers=false,
    AIESPMaxDist=400, AIESPRainbow=false,

    -- Loot ESP
    LootESPEnabled=false, LootMaxDist=300, LootTextSize=12,
    LootFilter={Keys=true,Bodies=true,Weapons=true,Ammo=true,Medical=true,Valuables=true,Containers=true,Other=false},
    LootColors={
        Keys=Color3.fromRGB(255,230,50), Bodies=Color3.fromRGB(200,80,80),
        Weapons=Color3.fromRGB(255,100,50), Ammo=Color3.fromRGB(255,200,50),
        Medical=Color3.fromRGB(80,255,120), Valuables=Color3.fromRGB(200,160,255),
        Containers=Color3.fromRGB(100,180,255), Other=Color3.fromRGB(180,180,180),
    },

    -- Exfil ESP
    ExfilESPEnabled=false, ExfilColor=Color3.fromRGB(80,255,140),
    ExfilMaxDist=2000, ExfilShowDist=true, ExfilArrow=true,
    ExfilRainbow=false, ExfilPulse=true,

    -- Aimbot
    AimbotEnabled=false, AimbotMode="Smooth", SilentAim=false,
    TriggerBot=false, TeamCheck=false, AimbotFOV=150,
    AimbotSmooth=0.10, AimbotBlatant=0.55,
    AimbotPredict=false, AimbotPredictStr=0.5,
    AimbotLock=false, AimbotPart="Head",
    FOVColor=Color3.fromRGB(180,100,255), FOVVisible=true, AimKey="MouseButton2",
    AimKeyEnum=Enum.UserInputType.MouseButton2,

    -- Combat
    NoRecoilEnabled=false, RecoilStrength=0.20,
    HitboxExpander=false, HitboxSize=6,
    AutoParry=false, TrigDelay=0,

    -- Zoom
    ZoomEnabled=false, ZoomKey="Z", ZoomFOV=20,
    ZoomSmooth=true, ZoomSpeed=0.20, ZoomActive=false,
    ZoomOverlay=true, ZoomOverlayColor=Color3.fromRGB(180,220,255), _BaseFOV=70,

    -- Visuals
    FullbrightEnabled=false, NoFogEnabled=false,
    CameraFOV=70,

    -- Crosshair (10 styles)
    CustomCrosshair=false,
    CrosshairStyle="Plus",
    CrosshairColor=Color3.fromRGB(255,255,255),
    CrosshairSize=12, CrosshairGap=4, CrosshairThick=2,
    CrosshairRainbow=false, CrosshairSpin=false, CrosshairSpinSpeed=90,
    CrosshairOpacity=0,

    -- Misc
    HitmarkerEnabled=false,
    GodModeEnabled=false,
    AntiRagdoll=false,
    AutoRespawn=false,
    ShowFPS=false,
    ShowPing=false,
}

-- ══════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════
local function W2S(pos)
    local s,v=Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X,s.Y),v
end

local function Notify(t,m,d)
    Rayfield:Notify({Title=t,Content=m,Duration=d or 3})
end

local function IsESPTeammate(p)
    return State.ESPTeamCheck and p.Team==LocalPlayer.Team
end
local function IsAimTeammate(p)
    return State.TeamCheck and p.Team==LocalPlayer.Team
end

local function RotVec(cx,cy,ox,oy,angle)
    local c,s=mcos(angle),msin(angle)
    return cx+ox*c-oy*s, cy+ox*s+oy*c
end

-- ══════════════════════════════════════════
--  PLAYER CHARACTER CACHE  (O(1) lookup)
-- ══════════════════════════════════════════
local PlayerCharCache={}
local function RebuildCharCache()
    PlayerCharCache={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then PlayerCharCache[p.Character]=true end
    end
end
local function IsPlayerChar(m) return PlayerCharCache[m]==true end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)   PlayerCharCache[c]=true end)
    p.CharacterRemoving:Connect(function(c) PlayerCharCache[c]=nil end)
end)
Players.PlayerRemoving:Connect(function(p)
    if p.Character then PlayerCharCache[p.Character]=nil end
end)
RebuildCharCache()
LocalPlayer.CharacterAdded:Connect(RebuildCharCache)

-- ══════════════════════════════════════════
--  WEAPON CACHE  (signal-driven: zero per-frame cost)
-- ══════════════════════════════════════════
local WeaponCache={}
local function HookWeaponCache(player)
    WeaponCache[player]=""
    local function onChar(char)
        local t=char:FindFirstChildOfClass("Tool")
        WeaponCache[player]=t and t.Name or ""
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then WeaponCache[player]=child.Name end
        end)
        char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                local tt=char:FindFirstChildOfClass("Tool")
                WeaponCache[player]=tt and tt.Name or ""
            end
        end)
    end
    player.CharacterAdded:Connect(onChar)
    if player.Character then onChar(player.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do HookWeaponCache(p) end
Players.PlayerAdded:Connect(HookWeaponCache)
Players.PlayerRemoving:Connect(function(p) WeaponCache[p]=nil end)

-- ══════════════════════════════════════════
--  SCREEN CRYSTAL BORDERS  (decorative)
-- ══════════════════════════════════════════
local ScreenCrystals={}
local function BuildScreenCrystals()
    local vp=Camera.ViewportSize; local W,H=vp.X,vp.Y
    local defs={
        {Vector2.new(0,0),  Vector2.new(32,0),  Vector2.new(0,32),  AME.mid},
        {Vector2.new(0,0),  Vector2.new(20,0),  Vector2.new(0,50),  AME.bright},
        {Vector2.new(0,0),  Vector2.new(50,0),  Vector2.new(0,20),  AME.dark},
        {Vector2.new(W,0),  Vector2.new(W-32,0),Vector2.new(W,32),  AME.mid},
        {Vector2.new(W,0),  Vector2.new(W-20,0),Vector2.new(W,50),  AME.bright},
        {Vector2.new(W,0),  Vector2.new(W-50,0),Vector2.new(W,20),  AME.dark},
        {Vector2.new(0,H),  Vector2.new(32,H),  Vector2.new(0,H-32),AME.mid},
        {Vector2.new(0,H),  Vector2.new(20,H),  Vector2.new(0,H-50),AME.bright},
        {Vector2.new(W,H),  Vector2.new(W-32,H),Vector2.new(W,H-32),AME.mid},
        {Vector2.new(W,H),  Vector2.new(W-20,H),Vector2.new(W,H-50),AME.bright},
        {Vector2.new(W/2-10,0),Vector2.new(W/2,20),Vector2.new(W/2+10,0),AME.bright},
        {Vector2.new(W/2-10,H),Vector2.new(W/2,H-20),Vector2.new(W/2+10,H),AME.bright},
    }
    for _,d in ipairs(defs) do
        local l1=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[1],To=d[2]})
        local l2=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[2],To=d[3]})
        local l3=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[3],To=d[1]})
        tinsert(ScreenCrystals,{l1,l2,l3})
    end
    local ea=0.75
    for _,e in ipairs({
        NewDraw("Line",{Visible=true,Color=AME.mid,Thickness=1,Transparency=ea,From=Vector2.new(60,0),  To=Vector2.new(W-60,0)}),
        NewDraw("Line",{Visible=true,Color=AME.mid,Thickness=1,Transparency=ea,From=Vector2.new(60,H),  To=Vector2.new(W-60,H)}),
        NewDraw("Line",{Visible=true,Color=AME.mid,Thickness=1,Transparency=ea,From=Vector2.new(0,60),  To=Vector2.new(0,H-60)}),
        NewDraw("Line",{Visible=true,Color=AME.mid,Thickness=1,Transparency=ea,From=Vector2.new(W,60),  To=Vector2.new(W,H-60)}),
    }) do tinsert(ScreenCrystals,{e}) end
end
Safe(BuildScreenCrystals)

-- ══════════════════════════════════════════
--  FOV CIRCLE + LOCK DOT
-- ══════════════════════════════════════════
local FOVCircle=NewDraw("Circle",{Visible=false,Thickness=1.5,Color=State.FOVColor,Filled=false,NumSides=64})
local LockDot  =NewDraw("Circle",{Visible=false,Filled=true,Color=Color3.fromRGB(255,60,60),Radius=4,NumSides=16,Thickness=0})

-- ══════════════════════════════════════════
--  CROSSHAIR DRAWINGS  (10 styles pooled)
-- ══════════════════════════════════════════
local CH={
    top  =NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    bot  =NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    left =NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    right=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    dot  =NewDraw("Circle",{Visible=false,Thickness=0,Filled=true,Radius=2,Color=Color3.new(1,1,1),NumSides=12}),
    ring =NewDraw("Circle",{Visible=false,Thickness=1.5,Filled=false,Radius=10,NumSides=48,Color=Color3.new(1,1,1)}),
    eye1 =NewDraw("Circle",{Visible=false,Thickness=0,Filled=true,Radius=2,NumSides=12,Color=Color3.new(1,1,1)}),
    eye2 =NewDraw("Circle",{Visible=false,Thickness=0,Filled=true,Radius=2,NumSides=12,Color=Color3.new(1,1,1)}),
    sm1=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    sm2=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    sm3=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    sm4=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    sm5=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    sm6=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    -- Bracket: 8 lines (4 corners × 2 arms each)
    br1=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br2=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br3=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br4=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br5=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br6=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br7=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    br8=NewDraw("Line",{Visible=false,Thickness=2,Color=Color3.new(1,1,1)}),
    -- Sniper / KovaaK extra lines
    sn1=NewDraw("Line",{Visible=false,Thickness=1,Color=Color3.new(1,1,1)}),
    sn2=NewDraw("Line",{Visible=false,Thickness=1,Color=Color3.new(1,1,1)}),
    sn3=NewDraw("Line",{Visible=false,Thickness=1,Color=Color3.new(1,1,1)}),
    sn4=NewDraw("Line",{Visible=false,Thickness=1,Color=Color3.new(1,1,1)}),
    -- Diamond: 4 segments
    dm1=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    dm2=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    dm3=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
    dm4=NewDraw("Line",{Visible=false,Thickness=1.5,Color=Color3.new(1,1,1)}),
}
local CH_KEYS={"top","bot","left","right","dot","ring","eye1","eye2",
    "sm1","sm2","sm3","sm4","sm5","sm6",
    "br1","br2","br3","br4","br5","br6","br7","br8",
    "sn1","sn2","sn3","sn4","dm1","dm2","dm3","dm4"}
local function HideCrosshair()
    for _,k in ipairs(CH_KEYS) do CH[k].Visible=false end
end
local _lastCHStyle=""
local chAngle=0

-- ══════════════════════════════════════════
--  HITMARKER
-- ══════════════════════════════════════════
local HM={
    tl=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    tr=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    bl=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    br=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
}
local hmActive,hmTimer=false,0

-- ══════════════════════════════════════════
--  ZOOM OVERLAY
-- ══════════════════════════════════════════
local ZO={
    tlH=NewDraw("Line",{Visible=false,Thickness=2}), tlV=NewDraw("Line",{Visible=false,Thickness=2}),
    trH=NewDraw("Line",{Visible=false,Thickness=2}), trV=NewDraw("Line",{Visible=false,Thickness=2}),
    blH=NewDraw("Line",{Visible=false,Thickness=2}), blV=NewDraw("Line",{Visible=false,Thickness=2}),
    brH=NewDraw("Line",{Visible=false,Thickness=2}), brV=NewDraw("Line",{Visible=false,Thickness=2}),
    dot  =NewDraw("Circle",{Visible=false,Filled=true,Radius=2,NumSides=12,Thickness=0}),
    hLine=NewDraw("Line",  {Visible=false,Thickness=1,Transparency=0.72}),
    vLine=NewDraw("Line",  {Visible=false,Thickness=1,Transparency=0.72}),
    vigL =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.48}),
    vigR =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.48}),
    vigT =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.48}),
    vigB =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.48}),
    zLbl =NewDraw("Text",  {Visible=false,Size=12,Outline=true,OutlineColor=Color3.new(0,0,0)}),
    rf   =NewDraw("Text",  {Visible=false,Size=11,Outline=true,OutlineColor=Color3.new(0,0,0)}),
}
local ZO_KEYS={"tlH","tlV","trH","trV","blH","blV","brH","brV","dot","hLine","vLine","vigL","vigR","vigT","vigB","zLbl","rf"}
local function ShowZoomOverlay(v)
    for _,k in ipairs(ZO_KEYS) do ZO[k].Visible=v end
end

-- ══════════════════════════════════════════
--  FPS / PING LABELS
-- ══════════════════════════════════════════
local FPSLabel =NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,255,160),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,8)})
local PingLabel=NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,200,255),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,24)})
local fpsFrames,fpsElapsed,fpsVal=0,0,0
local pingVal=0; local pingElapsed=0  -- ping sampled every 0.5s, not every frame

-- ══════════════════════════════════════════
--  PLAYER ESP
-- ══════════════════════════════════════════
local ESPObjects={}

-- R15 + R6 skeleton pairs
local SKEL_PAIRS={
    {"Head","UpperTorso"},{"Head","Torso"},
    {"UpperTorso","LowerTorso"},{"Torso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}
local SKEL_N=#SKEL_PAIRS

local function MakeESP(player)
    if ESPObjects[player] then return end
    local sk={}
    for i=1,SKEL_N do sk[i]=NewDraw("Line",{Visible=false,Color=Color3.new(1,1,1),Thickness=1}) end
    ESPObjects[player]={
        boxOut =NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=4}),
        box    =NewDraw("Square",{Visible=false,Filled=false,Color=State.BoxColor,Thickness=1.5}),
        fill   =NewDraw("Square",{Visible=false,Filled=true, Color=State.BoxColor,Transparency=0.88}),
        -- Corner-box lines (8 lines: 2 per corner)
        c1=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c2=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c3=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c4=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c5=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c6=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c7=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        c8=NewDraw("Line",{Visible=false,Thickness=2,Color=State.BoxColor}),
        name   =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.new(1,1,1),OutlineColor=Color3.new(0,0,0),Size=14}),
        dist   =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,180,180),OutlineColor=Color3.new(0,0,0),Size=11}),
        weapon =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(255,200,100),OutlineColor=Color3.new(0,0,0),Size=10}),
        hpBg   =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(0,220,0)}),
        tracer =NewDraw("Line",{Visible=false,Color=State.BoxColor,Thickness=1}),
        skeleton=sk,
        _lastDist=-1,
    }
end

local function KillESP(p)
    local o=ESPObjects[p]; if not o then return end
    for k,d in pairs(o) do
        if k=="skeleton" then for _,l in ipairs(d) do pcall(function()l:Remove()end) end
        elseif type(d)~="number" then pcall(function()d:Remove()end) end
    end
    ESPObjects[p]=nil
end

local function HideESP(o)
    o.boxOut.Visible=false; o.box.Visible=false; o.fill.Visible=false
    o.c1.Visible=false; o.c2.Visible=false; o.c3.Visible=false; o.c4.Visible=false
    o.c5.Visible=false; o.c6.Visible=false; o.c7.Visible=false; o.c8.Visible=false
    o.name.Visible=false; o.dist.Visible=false; o.weapon.Visible=false
    o.hpBg.Visible=false; o.hpBar.Visible=false; o.tracer.Visible=false
    local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end
end

local function DrawCornerBox(o, bx,by,bw,bh,col,cLen)
    -- Hide full box
    o.box.Visible=false; o.fill.Visible=false; o.boxOut.Visible=false
    -- TL
    o.c1.From=Vector2.new(bx,by);     o.c1.To=Vector2.new(bx+cLen,by);  o.c1.Color=col; o.c1.Visible=true
    o.c2.From=Vector2.new(bx,by);     o.c2.To=Vector2.new(bx,by+cLen);  o.c2.Color=col; o.c2.Visible=true
    -- TR
    o.c3.From=Vector2.new(bx+bw,by);  o.c3.To=Vector2.new(bx+bw-cLen,by); o.c3.Color=col; o.c3.Visible=true
    o.c4.From=Vector2.new(bx+bw,by);  o.c4.To=Vector2.new(bx+bw,by+cLen); o.c4.Color=col; o.c4.Visible=true
    -- BL
    o.c5.From=Vector2.new(bx,by+bh);  o.c5.To=Vector2.new(bx+cLen,by+bh); o.c5.Color=col; o.c5.Visible=true
    o.c6.From=Vector2.new(bx,by+bh);  o.c6.To=Vector2.new(bx,by+bh-cLen); o.c6.Color=col; o.c6.Visible=true
    -- BR
    o.c7.From=Vector2.new(bx+bw,by+bh); o.c7.To=Vector2.new(bx+bw-cLen,by+bh); o.c7.Color=col; o.c7.Visible=true
    o.c8.From=Vector2.new(bx+bw,by+bh); o.c8.To=Vector2.new(bx+bw,by+bh-cLen); o.c8.Color=col; o.c8.Visible=true
end

local function UpdatePlayerESP(myRoot, rainbowCol)
    local bottom=VP_BOT
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LocalPlayer then continue end
        if not ESPObjects[player] then MakeESP(player) end
        local o=ESPObjects[player]

        if not State.ESPEnabled then HideESP(o); continue end

        local char=player.Character
        if not char or IsESPTeammate(player) then HideESP(o); continue end

        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then HideESP(o); continue end

        local root=char:FindFirstChild("HumanoidRootPart")
        local head=char:FindFirstChild("Head")
        if not root or not head then HideESP(o); continue end

        -- FIX-02: Distance via squared components
        local myPos=myRoot and myRoot.Position
        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X; local dy=myPos.Y-root.Position.Y; local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>State.ESPMaxDist then HideESP(o); continue end

        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideESP(o); continue end

        -- FIX-02: Accurate head top using head.Size
        local headTopY=head.Position.Y+(head.Size.Y*0.5)+0.1
        local hPos=W2S(Vector3.new(head.Position.X,headTopY,head.Position.Z))

        -- FIX-02/03: clamp box height to always be positive & reasonable
        local bh=mmax(rPos.Y-hPos.Y, 14)
        local bw=mmax(bh*0.50, 10)
        local bx=rPos.X-bw*0.5
        local by=hPos.Y
        local col=rainbowCol or State.BoxColor

        if State.ESPBoxEnabled then
            if State.ESPCornerBox then
                DrawCornerBox(o,bx,by,bw,bh,col,mmax(mfloor(bw*0.25),5))
            else
                o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
                o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
                o.boxOut.Size=Vector2.new(bw+2,bh+2); o.boxOut.Position=Vector2.new(bx-1,by-1); o.boxOut.Visible=true
                o.box.Color=col; o.box.Size=Vector2.new(bw,bh); o.box.Position=Vector2.new(bx,by); o.box.Visible=true
                if State.ESPFillBox then
                    o.fill.Color=col; o.fill.Size=Vector2.new(bw,bh); o.fill.Position=Vector2.new(bx,by); o.fill.Visible=true
                else o.fill.Visible=false end
            end
        else
            -- Box disabled: hide all box elements, still show names/tracers/etc
            o.boxOut.Visible=false; o.box.Visible=false; o.fill.Visible=false
            o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
            o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
        end

        if State.ESPNames then
            local nm=player.DisplayName~=player.Name and (player.DisplayName.." ("..player.Name..")") or player.Name
            o.name.Text=nm; o.name.Size=State.ESPTextSize
            o.name.Position=Vector2.new(rPos.X,by-State.ESPTextSize-3); o.name.Visible=true
        else o.name.Visible=false end

        if State.ESPDistance then
            if o._lastDist~=dist then o._lastDist=dist; o.dist.Text=dist.." m" end
            o.dist.Position=Vector2.new(rPos.X,rPos.Y+3); o.dist.Visible=true
        else o.dist.Visible=false end

        if State.ESPWeapon then
            local wpn=WeaponCache[player] or ""
            if wpn~="" then
                o.weapon.Text="["..wpn.."]"
                o.weapon.Position=Vector2.new(rPos.X,rPos.Y+15); o.weapon.Visible=true
            else o.weapon.Visible=false end
        else o.weapon.Visible=false end

        if State.ESPHealthBars then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2); o.hpBg.Position=Vector2.new(bx-8,by-1); o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*220),0)
            o.hpBar.Size=Vector2.new(5,bh*pct); o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct)); o.hpBar.Visible=true
        else o.hpBg.Visible=false; o.hpBar.Visible=false end

        if State.ESPTracers then
            o.tracer.Color=col; o.tracer.From=bottom; o.tracer.To=rPos; o.tracer.Visible=true
        else o.tracer.Visible=false end

        if State.ESPSkeleton then
            for i,pair in ipairs(SKEL_PAIRS) do
                local line=o.skeleton[i]
                local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
                if pA and pB then
                    local sA,oA=W2S(pA.Position); local sB,oB=W2S(pB.Position)
                    if oA and oB then line.From=sA; line.To=sB; line.Color=col; line.Visible=true
                    else line.Visible=false end
                else line.Visible=false end
            end
        else local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end end
    end
end

-- ══════════════════════════════════════════
--  AI ESP  — signal-based live candidate tracking (zero periodic scan stutter)
-- ══════════════════════════════════════════
local AIESPObjects={}
-- Forward refs: functions defined after signal setup, assigned when fn is declared
local KillAIESP_fn = function() end
local KillLootESP_fn = function() end
local aiCandidates={}         -- map: model → {model,hum,root,head}
local _aiWasEnabled=false

local function _AIAdd(m)
    if aiCandidates[m] then return end
    if not m:IsA("Model") then return end
    if IsPlayerChar(m) or m==LocalPlayer.Character then return end
    local h=m:FindFirstChildOfClass("Humanoid")
    local root=m:FindFirstChild("HumanoidRootPart")
    if h and root then
        aiCandidates[m]={model=m,hum=h,root=root,head=m:FindFirstChild("Head")}
    end
end
local function _AIRemove(m)
    aiCandidates[m]=nil
    if AIESPObjects[m] then KillAIESP_fn(m) end  -- forward ref resolved below
end

-- Bootstrap: scan existing workspace once (startup only, not periodic)
local function _AIBootstrap()
    for _,m in ipairs(Workspace:GetDescendants()) do _AIAdd(m) end
end

-- [AI signals moved to unified block below]

local function GetOrMakeAIESP(m)
    if AIESPObjects[m] then return AIESPObjects[m] end
    local o={
        boxOut=NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=3}),
        box   =NewDraw("Square",{Visible=false,Filled=false,Color=State.AIBoxColor,Thickness=1.5}),
        fill  =NewDraw("Square",{Visible=false,Filled=true, Color=State.AIBoxColor,Transparency=0.88}),
        name  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=State.AIBoxColor,OutlineColor=Color3.new(0,0,0),Size=13}),
        dist  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(200,180,140),OutlineColor=Color3.new(0,0,0),Size=11}),
        hpBg  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(255,140,0)}),
        tracer=NewDraw("Line",  {Visible=false,Color=State.AIBoxColor,Thickness=1}),
        _lastDist=-1,
    }
    AIESPObjects[m]=o; return o
end

local function HideAI(o)
    o.boxOut.Visible=false; o.box.Visible=false; o.fill.Visible=false
    o.name.Visible=false; o.dist.Visible=false
    o.hpBg.Visible=false; o.hpBar.Visible=false; o.tracer.Visible=false
end

local function KillAIESP(m)
    local o=AIESPObjects[m]; if not o then return end
    pcall(function()o.boxOut:Remove()end); pcall(function()o.box:Remove()end)
    pcall(function()o.fill:Remove()end);   pcall(function()o.name:Remove()end)
    pcall(function()o.dist:Remove()end);   pcall(function()o.hpBg:Remove()end)
    pcall(function()o.hpBar:Remove()end);  pcall(function()o.tracer:Remove()end)
    AIESPObjects[m]=nil
end
KillAIESP_fn = KillAIESP  -- resolve forward ref from DescendantRemoving signal

local function UpdateAIESP(myRoot)
    -- No scan timer: aiCandidates kept live by DescendantAdded/Removing signals
    if not State.AIESPEnabled then
        if _aiWasEnabled then
            for m in pairs(AIESPObjects) do KillAIESP(m) end
            _aiWasEnabled=false
        end
        return
    end
    _aiWasEnabled=true

    local bottom=VP_BOT
    local rcol=State.AIESPRainbow and RainbowHSV(0.4,0.33) or nil
    local myPos=myRoot and myRoot.Position

    for m,entry in pairs(aiCandidates) do
        if not m.Parent then aiCandidates[m]=nil; KillAIESP(m); continue end
        local hum=entry.hum; local root=entry.root; local head=entry.head
        local o=GetOrMakeAIESP(m)
        if not root or hum.Health<=0 then HideAI(o); continue end

        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X
            local dy=myPos.Y-root.Position.Y
            local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>State.AIESPMaxDist then HideAI(o); continue end

        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideAI(o); continue end

        local hTopY=head and (head.Position.Y+(head.Size and head.Size.Y*0.5 or 0.5)+0.1) or root.Position.Y+3
        local hPos=W2S(Vector3.new(root.Position.X,hTopY,root.Position.Z))
        local bh=mmax(rPos.Y-hPos.Y,14); local bw=mmax(bh*0.50,10)
        local bx=rPos.X-bw*0.5; local by=hPos.Y
        local col=rcol or State.AIBoxColor

        o.boxOut.Size=Vector2.new(bw+2,bh+2); o.boxOut.Position=Vector2.new(bx-1,by-1); o.boxOut.Visible=true
        o.box.Color=col; o.box.Size=Vector2.new(bw,bh); o.box.Position=Vector2.new(bx,by); o.box.Visible=true
        o.fill.Color=col; o.fill.Size=Vector2.new(bw,bh); o.fill.Position=Vector2.new(bx,by); o.fill.Visible=true

        if State.AIESPNames then
            o.name.Text=m.Name; o.name.Position=Vector2.new(rPos.X,by-15); o.name.Color=col; o.name.Visible=true
        else o.name.Visible=false end

        if o._lastDist~=dist then o._lastDist=dist; o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(rPos.X,rPos.Y+3); o.dist.Visible=true

        if State.AIESPHealth then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2); o.hpBg.Position=Vector2.new(bx-8,by-1); o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*180),0)
            o.hpBar.Size=Vector2.new(5,bh*pct); o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct)); o.hpBar.Visible=true
        else o.hpBg.Visible=false; o.hpBar.Visible=false end

        if State.AIESPTracers then
            o.tracer.Color=col; o.tracer.From=bottom; o.tracer.To=rPos; o.tracer.Visible=true
        else o.tracer.Visible=false end
    end

    for m in pairs(AIESPObjects) do
        if not aiCandidates[m] then KillAIESP(m) end
    end
end

-- ══════════════════════════════════════════
--  LOOT ESP  (deferred scan)
-- ══════════════════════════════════════════
local LootESPObjects={}
local LOOT_CATS={
    Keys      ={"key","keycard","access","passcard","id card","badge"},
    Bodies    ={"body","corpse","dead","ragdoll","remains","victim"},
    Weapons   ={"gun","pistol","rifle","shotgun","smg","sniper","knife","sword","axe","weapon","firearm","blade"},
    Ammo      ={"ammo","bullet","magazine","mag","round","shell","clip"},
    Medical   ={"medkit","bandage","health","heal","syringe","pill","drug","medical","stim"},
    Valuables ={"gold","gem","diamond","jewel","valuable","cash","money","loot","treasure","artifact","crystal"},
    Containers={"chest","crate","box","bag","backpack","stash","container","locker","safe","vault"},
    Other     ={},
}
local LOOT_ICONS={Keys="🔑",Bodies="💀",Weapons="🔫",Ammo="🔹",Medical="💊",Valuables="💎",Containers="📦",Other="·"}

local ClassifyCache={}
local function ClassifyItem(name)
    local l=name:lower()
    if ClassifyCache[l] then return ClassifyCache[l] end
    for cat,kws in pairs(LOOT_CATS) do
        for _,kw in ipairs(kws) do
            if l:find(kw,1,true) then ClassifyCache[l]=cat; return cat end
        end
    end
    ClassifyCache[l]="Other"; return "Other"
end

-- Loot candidates: map inst→{inst,cat} updated via signals (no periodic scan)
local lootCandidates={}   -- inst → {inst, cat}

local function _LootCheck(inst)
    if not inst:IsA("BasePart") and not inst:IsA("Model") then return end
    if IsPlayerChar(inst) then return end
    local n=inst.Name
    if n==""or n=="Baseplate"or n=="Terrain"or n=="SpawnLocation" then return end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then
        local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
        if p then pos=p.Position end
    end
    if not pos then return end
    local cat=ClassifyItem(n)
    lootCandidates[inst]={inst=inst,cat=cat}
end

local function _LootRemove(inst)
    if lootCandidates[inst] then
        lootCandidates[inst]=nil
        if LootESPObjects[inst] then KillLootESP_fn(inst) end
    end
end

-- Bootstrap once from Workspace children (shallow, not full GetDescendants)
local function _LootBootstrap()
    for _,child in ipairs(Workspace:GetChildren()) do
        _LootCheck(child)
        if child:IsA("Folder") or child:IsA("Model") then
            for _,sub in ipairs(child:GetChildren()) do _LootCheck(sub) end
        end
    end
end

-- [Loot signals moved to unified block below]

local function MakeLootESP(inst,cat)
    if LootESPObjects[inst] then return LootESPObjects[inst] end
    local col=State.LootColors[cat] or Color3.fromRGB(180,180,180)
    local o={cat=cat,
        dot  =NewDraw("Circle",{Visible=false,Filled=true,Color=col,Radius=3,NumSides=8,Thickness=0}),
        label=NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=col,OutlineColor=Color3.new(0,0,0),Size=State.LootTextSize}),
        dist =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(160,160,160),OutlineColor=Color3.new(0,0,0),Size=10}),
        _lastDist=-1,_lastName="",
    }
    LootESPObjects[inst]=o; return o
end

local function KillLootESP(inst)
    local o=LootESPObjects[inst]; if not o then return end
    pcall(function()o.dot:Remove()end)
    pcall(function()o.label:Remove()end)
    pcall(function()o.dist:Remove()end)
    LootESPObjects[inst]=nil
end
KillLootESP_fn = KillLootESP  -- resolve forward ref

local function HideLoot(o)
    o.label.Visible=false; o.dot.Visible=false; o.dist.Visible=false
end

local _lootWasEnabled=false
local function UpdateLootESP(myRoot)
    if not State.LootESPEnabled then
        if _lootWasEnabled then
            for item in pairs(LootESPObjects) do KillLootESP(item) end
            _lootWasEnabled=false
        end
        return
    end
    _lootWasEnabled=true

    local myPos=myRoot and myRoot.Position

    for inst,entry in pairs(lootCandidates) do
        if not inst.Parent then lootCandidates[inst]=nil; KillLootESP(inst); continue end
        local cat=entry.cat
        if not State.LootFilter[cat] then
            if LootESPObjects[inst] then KillLootESP(inst) end; continue
        end

        local pos
        if inst:IsA("BasePart") then pos=inst.Position
        elseif inst:IsA("Model") then
            local p=inst.PrimaryPart; if p then pos=p.Position end
        end
        if not pos then continue end

        local o=MakeLootESP(inst,cat)
        local col=State.LootColors[cat] or Color3.fromRGB(180,180,180)
        o.label.Color=col; o.dot.Color=col

        local dist=0
        if myPos then
            local dx=myPos.X-pos.X; local dy=myPos.Y-pos.Y; local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>State.LootMaxDist then HideLoot(o); continue end

        local sp,onScreen=W2S(pos)
        if not onScreen then HideLoot(o); continue end

        o.dot.Position=sp; o.dot.Visible=true

        local lname=inst.Name
        if o._lastName~=lname then
            o._lastName=lname
            o.label.Text=(LOOT_ICONS[cat] or "·").." "..lname
        end
        o.label.Size=State.LootTextSize
        o.label.Position=Vector2.new(sp.X,sp.Y-16); o.label.Visible=true

        if o._lastDist~=dist then o._lastDist=dist; o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(sp.X,sp.Y-4); o.dist.Visible=true
    end

    for inst in pairs(LootESPObjects) do
        if not lootCandidates[inst] then KillLootESP(inst) end
    end
end

-- ══════════════════════════════════════════
--  EXFIL ESP  (deferred scan every 150 frames)
-- ══════════════════════════════════════════
local EXFIL_KWS={"exfil","extract","extraction","exit","evac","evacuate",
    "escape","evacuation","chopper","helicopter","heli","gate","portal",
    "hatch","depart","exit zone","extract zone","end zone"}

local ExfilESPObjects={}
local ExfilArrow={
    shaft=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head1=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head2=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    label=NewDraw("Text",{Visible=false,Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(80,255,140)}),
}

local ExfilNameCache={}
local function IsExfilInst(inst)
    local n=inst.Name:lower()
    if ExfilNameCache[n]~=nil then return ExfilNameCache[n] end
    for _,kw in ipairs(EXFIL_KWS) do
        if n:find(kw,1,true) then ExfilNameCache[n]=true; return true end
    end
    ExfilNameCache[n]=false; return false
end

-- Exfil candidates tracked live by signals
local exfilCandidates={}  -- inst → {inst}

local function _ExfilCheck(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not IsExfilInst(inst) then return end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then
        local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
        if p then pos=p.Position end
    end
    if pos then exfilCandidates[inst]={inst=inst,pos=pos} end
end

local function _ExfilRemove(inst)
    exfilCandidates[inst]=nil
end

local function _ExfilBootstrap()
    for _,d in ipairs(Workspace:GetDescendants()) do _ExfilCheck(d) end
end

-- ══════════════════════════════════════════
--  UNIFIED WORKSPACE SIGNALS
--  Single DescendantAdded/Removing pair handles AI, Loot, and Exfil.
--  One signal fire → one callback → dispatches to all three checkers.
--  3x less signal overhead vs separate connections.
-- ══════════════════════════════════════════
Workspace.DescendantAdded:Connect(function(d)
    task.defer(function()
        if not d or not d.Parent then return end
        -- AI candidates: Models with Humanoid + HumanoidRootPart
        if d:IsA("Model") then _AIAdd(d) end
        -- Loot candidates: BaseParts and Models by name
        _LootCheck(d)
        -- Exfil candidates: named zones
        _ExfilCheck(d)
    end)
end)
Workspace.DescendantRemoving:Connect(function(d)
    -- Synchronous removal — keep candidate maps clean immediately
    if d:IsA("Model") then aiCandidates[d]=nil end
    _LootRemove(d)
    _ExfilRemove(d)
end)


local function GetOrMakeExfilESP(inst)
    if ExfilESPObjects[inst] then return ExfilESPObjects[inst] end
    local o={
        box    =NewDraw("Square",{Visible=false,Filled=false,Color=State.ExfilColor,Thickness=2}),
        boxGlow=NewDraw("Square",{Visible=false,Filled=false,Color=State.ExfilColor,Thickness=5,Transparency=0.65}),
        pulse  =NewDraw("Circle",{Visible=false,Filled=false,Color=State.ExfilColor,Thickness=1.5,NumSides=48,Radius=0}),
        label  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=State.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=14}),
        dist   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,255,180),OutlineColor=Color3.new(0,0,0),Size=12}),
        icon   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=State.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=18}),
        _pulseT=0,_lastDist=-1,
    }
    ExfilESPObjects[inst]=o; return o
end

local function KillExfilESP(inst)
    local o=ExfilESPObjects[inst]; if not o then return end
    for k,v in pairs(o) do if type(v)~="number" then pcall(function()v:Remove()end) end end
    ExfilESPObjects[inst]=nil
end

local function HideExfil(o)
    o.box.Visible=false; o.boxGlow.Visible=false; o.pulse.Visible=false
    o.label.Visible=false; o.dist.Visible=false; o.icon.Visible=false
end

local _exfilWasEnabled=false
local function UpdateExfilESP(dt,myRoot)
    ExfilArrow.shaft.Visible=false; ExfilArrow.head1.Visible=false
    ExfilArrow.head2.Visible=false; ExfilArrow.label.Visible=false

    if not State.ExfilESPEnabled then
        if _exfilWasEnabled then
            for inst in pairs(ExfilESPObjects) do KillExfilESP(inst) end
            _exfilWasEnabled=false
        end
        return
    end
    _exfilWasEnabled=true

    local col=State.ExfilRainbow and RainbowHSV(0.3,0.66) or State.ExfilColor
    local myPos=myRoot and myRoot.Position
    local nearDist=mhuge; local nearPos=nil

    for inst,entry in pairs(exfilCandidates) do
        if not inst.Parent then exfilCandidates[inst]=nil; KillExfilESP(inst); continue end
        local pos=entry.pos
        local o=GetOrMakeExfilESP(inst)
        local dist=0
        if myPos then
            local dx=myPos.X-pos.X; local dy=myPos.Y-pos.Y; local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist<nearDist then nearDist=dist; nearPos=pos end
        o.box.Color=col; o.boxGlow.Color=col; o.pulse.Color=col; o.label.Color=col; o.icon.Color=col
        if not State.ExfilShowDist or dist>State.ExfilMaxDist then HideExfil(o); continue end
        local sp,onScreen=W2S(pos)
        if not onScreen then HideExfil(o); continue end
        local bSz=mclamp(80-dist*0.08,18,80)
        local bx=sp.X-bSz*0.5; local by=sp.Y-bSz*0.5
        o.boxGlow.Size=Vector2.new(bSz+6,bSz+6); o.boxGlow.Position=Vector2.new(bx-3,by-3); o.boxGlow.Visible=true
        o.box.Size=Vector2.new(bSz,bSz); o.box.Position=Vector2.new(bx,by); o.box.Visible=true
        if State.ExfilPulse then
            o._pulseT=(o._pulseT+dt*1.2)%1
            o.pulse.Radius=bSz*0.5+o._pulseT*40
            o.pulse.Position=sp; o.pulse.Transparency=(1-o._pulseT)*0.1; o.pulse.Visible=true
        else o.pulse.Visible=false end
        o.icon.Text="🚁"; o.icon.Position=Vector2.new(sp.X,by-22); o.icon.Visible=true
        o.label.Text=inst.Name; o.label.Size=13; o.label.Position=Vector2.new(sp.X,by-10); o.label.Visible=true
        if State.ExfilShowDist then
            if o._lastDist~=dist then
                o._lastDist=dist
                o.dist.Text=dist<1000 and (dist.." m") or sfmt("%.1f km",dist/1000)
            end
            o.dist.Position=Vector2.new(sp.X,by+bSz+4); o.dist.Visible=true
        else o.dist.Visible=false end
    end

    for inst in pairs(ExfilESPObjects) do if not exfilCandidates[inst] then KillExfilESP(inst) end end

    if State.ExfilArrow and nearPos and myRoot then
        local sp,onScreen=W2S(nearPos)
        if not onScreen then
            local cx=VP_CX; local cy=VP_CY
            local ang=matan2(sp.Y-cy,sp.X-cx); local mar=65
            local mx=mclamp(cx+mcos(ang)*(cx-mar),mar,VP.X-mar)
            local my=mclamp(cy+msin(ang)*(cy-mar),mar,VP.Y-mar)
            local ax=cx+(mx-cx)*0.85; local ay=cy+(my-cy)*0.85
            local tipX=cx+(mx-cx)*0.93; local tipY=cy+(my-cy)*0.93
            local h1x,h1y=RotVec(tipX,tipY,-10,-5,ang)
            local h2x,h2y=RotVec(tipX,tipY,-10, 5,ang)
            ExfilArrow.shaft.From=Vector2.new(ax,ay); ExfilArrow.shaft.To=Vector2.new(tipX,tipY)
            ExfilArrow.head1.From=Vector2.new(tipX,tipY); ExfilArrow.head1.To=Vector2.new(h1x,h1y)
            ExfilArrow.head2.From=Vector2.new(tipX,tipY); ExfilArrow.head2.To=Vector2.new(h2x,h2y)
            local dstr=nearDist<1000 and (nearDist.." m") or sfmt("%.1f km",nearDist/1000)
            ExfilArrow.label.Text="EXFIL  "..dstr
            ExfilArrow.label.Position=Vector2.new(ax,ay-14)
            for _,d in pairs(ExfilArrow) do if type(d)~="string" then pcall(function() d.Color=col; d.Visible=true end) end end
        end
    end
end

-- ══════════════════════════════════════════
--  AIMBOT
-- ══════════════════════════════════════════
local lockedTarget=nil; local lastTargetPos={}

local function GetBestTarget()
    local cx=VP_CX; local cy=VP_CY
    if State.AimbotLock and lockedTarget then
        local p=lockedTarget; local char=p.Character
        if char and not IsAimTeammate(p) then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local part=char:FindFirstChild(State.AimbotPart) or char:FindFirstChild("HumanoidRootPart")
                if part then
                    local sp,on=W2S(part.Position)
                    if on then
                        local dx=sp.X-cx; local dy=sp.Y-cy
                        if (dx*dx+dy*dy)^0.5<State.AimbotFOV then return p end
                    end
                end
            end
        end
        lockedTarget=nil
    end
    local best,bd=nil,mhuge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and not IsAimTeammate(p) then
            local char=p.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health>0 then
                    local part=char:FindFirstChild(State.AimbotPart) or char:FindFirstChild("HumanoidRootPart")
                    if part then
                        local sp,on=W2S(part.Position)
                        if on then
                            local dx=sp.X-cx; local dy=sp.Y-cy
                            local d=(dx*dx+dy*dy)^0.5
                            if d<State.AimbotFOV and d<bd then bd=d; best=p end
                        end
                    end
                end
            end
        end
    end
    if best and State.AimbotLock then lockedTarget=best end
    return best
end

local function GetPredictedPos(player,part)
    local pos=part.Position
    if not State.AimbotPredict then return pos end
    local prev=lastTargetPos[player]; lastTargetPos[player]=pos
    if prev then return pos+(pos-prev)*State.AimbotPredictStr*8 end
    return pos
end

local AimKeyMap={
    MouseButton2=function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end,
    C=function() return UserInputService:IsKeyDown(Enum.KeyCode.C) end,
    Q=function() return UserInputService:IsKeyDown(Enum.KeyCode.Q) end,
    E=function() return UserInputService:IsKeyDown(Enum.KeyCode.E) end,
    F=function() return UserInputService:IsKeyDown(Enum.KeyCode.F) end,
}
local function IsAimKeyDown()
    local fn=AimKeyMap[State.AimKey]; return fn and fn() or false
end

local function RunAimbot(camCF)
    if not State.AimbotEnabled then LockDot.Visible=false; return end
    local target=GetBestTarget()
    if target then
        local char=target.Character
        local part=char and (char:FindFirstChild(State.AimbotPart) or char:FindFirstChild("HumanoidRootPart"))
        if part then local sp,on=W2S(part.Position); LockDot.Position=sp; LockDot.Visible=on end
    else LockDot.Visible=false end
    if not IsAimKeyDown() or not target then return end
    local char=target.Character
    local part=char and (char:FindFirstChild(State.AimbotPart) or char:FindFirstChild("HumanoidRootPart"))
    if not part then return end
    local aimPos=GetPredictedPos(target,part)
    local targetCF=CFrame.new(camCF.Position,aimPos)
    -- AC-04: pcall wrap so AC metamethods can't surface errors
    if State.AimbotMode=="Instant" then
        pcall(function() Camera.CFrame=targetCF end)
    elseif State.AimbotMode=="Blatant" then
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,State.AimbotBlatant) end)
    else
        local sp=W2S(aimPos); local dx=sp.X-VP_CX; local dy=sp.Y-VP_CY
        local dyn=mclamp(State.AimbotSmooth+(dx*dx+dy*dy)^0.5/State.AimbotFOV*0.08,State.AimbotSmooth,0.35)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,dyn) end)
    end
end

-- ══════════════════════════════════════════
--  ZOOM
-- ══════════════════════════════════════════
local zoomTween=nil; local zoomWasActive=false
local function CancelZoomTween()
    if zoomTween then pcall(function()zoomTween:Cancel()end); zoomTween=nil end
end
local function SetCameraFOV(f,smooth,spd)
    CancelZoomTween()
    if smooth then
        zoomTween=TweenService:Create(Camera,TweenInfo.new(spd or 0.18,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{FieldOfView=f})
        zoomTween:Play()
    else Camera.FieldOfView=f end
end
local ZoomKeyMap={
    Z=function() return UserInputService:IsKeyDown(Enum.KeyCode.Z) end,
    X=function() return UserInputService:IsKeyDown(Enum.KeyCode.X) end,
    V=function() return UserInputService:IsKeyDown(Enum.KeyCode.V) end,
    F=function() return UserInputService:IsKeyDown(Enum.KeyCode.F) end,
    G=function() return UserInputService:IsKeyDown(Enum.KeyCode.G) end,
}
local function IsZoomKeyDown()
    local fn=ZoomKeyMap[State.ZoomKey]; return fn and fn() or false
end
local function UpdateZoomOverlay()
    if not State.ZoomOverlay then ShowZoomOverlay(false); return end
    local vp=VP; local cx=VP_CX; local cy=VP_CY; local col=State.ZoomOverlayColor
    local bLen=36; local bGap=90
    ZO.vigL.Position=Vector2.new(0,0);       ZO.vigL.Size=Vector2.new(80,vp.Y)
    ZO.vigR.Position=Vector2.new(vp.X-80,0); ZO.vigR.Size=Vector2.new(80,vp.Y)
    ZO.vigT.Position=Vector2.new(0,0);       ZO.vigT.Size=Vector2.new(vp.X,38)
    ZO.vigB.Position=Vector2.new(0,vp.Y-38); ZO.vigB.Size=Vector2.new(vp.X,38)
    for _,k in ipairs({"tlH","tlV","trH","trV","blH","blV","brH","brV","dot","hLine","vLine","zLbl","rf"}) do
        ZO[k].Color=col
    end
    local tl=Vector2.new(cx-bGap,cy-bGap); local tr=Vector2.new(cx+bGap,cy-bGap)
    local bl=Vector2.new(cx-bGap,cy+bGap); local br=Vector2.new(cx+bGap,cy+bGap)
    ZO.tlH.From=tl; ZO.tlH.To=Vector2.new(tl.X+bLen,tl.Y)
    ZO.tlV.From=tl; ZO.tlV.To=Vector2.new(tl.X,tl.Y+bLen)
    ZO.trH.From=tr; ZO.trH.To=Vector2.new(tr.X-bLen,tr.Y)
    ZO.trV.From=tr; ZO.trV.To=Vector2.new(tr.X,tr.Y+bLen)
    ZO.blH.From=bl; ZO.blH.To=Vector2.new(bl.X+bLen,bl.Y)
    ZO.blV.From=bl; ZO.blV.To=Vector2.new(bl.X,bl.Y-bLen)
    ZO.brH.From=br; ZO.brH.To=Vector2.new(br.X-bLen,br.Y)
    ZO.brV.From=br; ZO.brV.To=Vector2.new(br.X,br.Y-bLen)
    ZO.hLine.From=Vector2.new(cx-bGap-bLen-10,cy); ZO.hLine.To=Vector2.new(cx+bGap+bLen+10,cy)
    ZO.vLine.From=Vector2.new(cx,cy-bGap-bLen-10); ZO.vLine.To=Vector2.new(cx,cy+bGap+bLen+10)
    ZO.dot.Position=Vector2.new(cx,cy)
    local mag=mfloor(State._BaseFOV/mmax(Camera.FieldOfView,1)*10)/10
    ZO.zLbl.Text=sfmt("%.1fx",mag); ZO.zLbl.Position=Vector2.new(cx+bGap+bLen+14,cy-6)
    -- nearest target
    local myChar=LocalPlayer.Character; local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then
        local nd,nn=mhuge,nil
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then
                local r2=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if r2 then
                    local dx=myRoot.Position.X-r2.Position.X; local dz=myRoot.Position.Z-r2.Position.Z
                    local d=(dx*dx+dz*dz)^0.5; if d<nd then nd=d; nn=p end
                end
            end
        end
        ZO.rf.Text=nn and sfmt("◎ %s  %dm",nn.Name,mfloor(nd)) or "◎ No targets"
        ZO.rf.Position=Vector2.new(cx-bGap-bLen-8,cy+bGap+bLen+6)
    end
    ShowZoomOverlay(true)
end
local function UpdateZoom()
    if not State.ZoomEnabled then
        if zoomWasActive then
            zoomWasActive=false; CancelZoomTween()
            Camera.FieldOfView=State.CameraFOV; ShowZoomOverlay(false)
        end; return
    end
    local want=IsZoomKeyDown()
    if want and not State.ZoomActive then
        State.ZoomActive=true; zoomWasActive=true; State._BaseFOV=Camera.FieldOfView
        SetCameraFOV(State.ZoomFOV,State.ZoomSmooth,State.ZoomSpeed)
    elseif not want and State.ZoomActive then
        State.ZoomActive=false; CancelZoomTween()
        SetCameraFOV(State._BaseFOV,State.ZoomSmooth,State.ZoomSpeed*0.8)
        ShowZoomOverlay(false); zoomWasActive=false
    end
    if State.ZoomActive then UpdateZoomOverlay() end
end

-- ══════════════════════════════════════════
--  CROSSHAIR  (10 styles — all bugs fixed)
-- ══════════════════════════════════════════
-- ══════════════════════════════════════════
--  CROSSHAIR  (zero inner closures — all helpers module-level)
-- ══════════════════════════════════════════
-- Module-level working vars written once per UpdateCrosshair call, read by helpers.
local _CH_cx,_CH_cy,_CH_ca,_CH_sa = 0,0,1,0  -- centre x/y, cos(angle), sin(angle)
local _CH_col,_CH_th,_CH_op = Color3.new(1,1,1),2,0

-- Set a Line drawing's From/To/style in one call — no closure, reads module vars
local function _CHLine(d, ox1,oy1, ox2,oy2)
    local cx,cy,ca,sa = _CH_cx,_CH_cy,_CH_ca,_CH_sa
    d.From      = Vector2.new(cx+ox1*ca-oy1*sa, cy+ox1*sa+oy1*ca)
    d.To        = Vector2.new(cx+ox2*ca-oy2*sa, cy+ox2*sa+oy2*ca)
    d.Color     = _CH_col
    d.Thickness = _CH_th
    d.Transparency = _CH_op
    d.Visible   = true
end
-- Same but with an extra angle offset (used by X style for 45° rotation)
local function _CHLineOff(d, ox1,oy1, ox2,oy2, extraAngle)
    local a = chAngle + extraAngle
    local ca,sa = mcos(a),msin(a)
    local cx,cy = _CH_cx,_CH_cy
    d.From      = Vector2.new(cx+ox1*ca-oy1*sa, cy+ox1*sa+oy1*ca)
    d.To        = Vector2.new(cx+ox2*ca-oy2*sa, cy+ox2*sa+oy2*ca)
    d.Color     = _CH_col
    d.Thickness = _CH_th
    d.Transparency = _CH_op
    d.Visible   = true
end
-- Rotate a point around (cx,cy) by the current crosshair angle
local function _CHPt(ox,oy)
    return Vector2.new(_CH_cx+ox*_CH_ca-oy*_CH_sa, _CH_cy+ox*_CH_sa+oy*_CH_ca)
end

-- Pre-allocated smile-point array (avoids tinsert + table alloc every frame)
local _smPts = {false,false,false,false,false,false,false} -- 7 slots

local function UpdateCrosshair(dt)
    if not State.CustomCrosshair then
        if _lastCHStyle~="" then HideCrosshair(); _lastCHStyle="" end
        return
    end
    local style = State.CrosshairStyle
    if style~=_lastCHStyle then HideCrosshair(); _lastCHStyle=style; chAngle=0 end

    if State.CrosshairSpin then
        chAngle = (chAngle + mrad(State.CrosshairSpinSpeed)*dt) % (pi*2)
    end

    -- Write shared module vars once; all helpers read them — zero closures
    _CH_cx  = VP_CX
    _CH_cy  = VP_CY
    _CH_ca  = mcos(chAngle)
    _CH_sa  = msin(chAngle)
    _CH_col = State.CrosshairRainbow and RainbowHSV(0.6) or State.CrosshairColor
    _CH_th  = State.CrosshairThick
    _CH_op  = State.CrosshairOpacity

    local cx,cy  = _CH_cx,_CH_cy
    local col,th,op = _CH_col,_CH_th,_CH_op
    local gap,sz = State.CrosshairGap, State.CrosshairSize

    if style=="Plus" then
        _CHLine(CH.top,   0,-gap,      0,-(gap+sz))
        _CHLine(CH.bot,   0, gap,      0,  gap+sz)
        _CHLine(CH.left,  -gap,0,  -(gap+sz),0)
        _CHLine(CH.right,  gap,0,    gap+sz, 0)
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="X" then
        local d45=pi/4
        _CHLineOff(CH.top,   0,-gap,      0,-(gap+sz), d45)
        _CHLineOff(CH.bot,   0, gap,      0,  gap+sz,  d45)
        _CHLineOff(CH.left,  -gap,0,  -(gap+sz),0,     d45)
        _CHLineOff(CH.right,  gap,0,    gap+sz, 0,     d45)
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Dot" then
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col
        CH.dot.Radius=mclamp(th+1,2,7); CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Circle" then
        CH.ring.Position=Vector2.new(cx,cy); CH.ring.Color=col
        CH.ring.Radius=gap+sz*0.5; CH.ring.Thickness=th; CH.ring.Transparency=op; CH.ring.Visible=true
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="T-Shape" then
        _CHLine(CH.top,   0,-gap,  0,-(gap+sz))
        _CHLine(CH.left,  -gap,0,  -(gap+sz),0)
        _CHLine(CH.right,  gap,0,    gap+sz, 0)
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Happy Face" then
        local fR = sz+gap
        -- Eyes
        CH.eye1.Position=Vector2.new(cx-fR*0.35, cy-fR*0.3)
        CH.eye1.Radius=mmax(th,2); CH.eye1.Color=col; CH.eye1.Transparency=op; CH.eye1.Visible=true
        CH.eye2.Position=Vector2.new(cx+fR*0.35, cy-fR*0.3)
        CH.eye2.Radius=mmax(th,2); CH.eye2.Color=col; CH.eye2.Transparency=op; CH.eye2.Visible=true
        -- Smile: arc from 20° to 160° — in screen coords (Y-down) this produces a
        -- U-shape that sits BELOW the eyes, i.e. a proper smile.
        -- sin(20°..160°) is positive → y increases downward from centre → correct.
        local smR = fR*0.52
        local smCY = cy + fR*0.12   -- smile centre sits below face centre
        -- Build 7 pts into pre-allocated array (no tinsert, no table alloc)
        local angStep = mrad(140)/6  -- 140° spread across 6 segments (7 pts)
        local angStart = mrad(20)
        for i=0,6 do
            local ang = angStart + angStep*i
            _smPts[i+1] = Vector2.new(cx+mcos(ang)*smR, smCY+msin(ang)*smR)
        end
        -- Draw 6 line segments connecting the 7 points
        local sL={CH.sm1,CH.sm2,CH.sm3,CH.sm4,CH.sm5,CH.sm6}
        for i=1,6 do
            local d=sL[i]
            d.From=_smPts[i]; d.To=_smPts[i+1]
            d.Color=col; d.Thickness=th; d.Transparency=op; d.Visible=true
        end

    elseif style=="KovaaK" then
        _CHLine(CH.top,   0,-gap,  0,-(gap+sz))
        _CHLine(CH.bot,   0, gap,  0,  gap+sz)
        _CHLine(CH.left,  -gap,0,  -(gap+sz),0)
        _CHLine(CH.right,  gap,0,    gap+sz, 0)
        local tOff=gap+sz+4; local tLen=5
        _CHLine(CH.sn1, 0,-(tOff),  0,-(tOff+tLen))
        _CHLine(CH.sn2, 0,  tOff,   0,  tOff+tLen)
        _CHLine(CH.sn3, -(tOff),0,  -(tOff+tLen),0)
        _CHLine(CH.sn4,   tOff, 0,    tOff+tLen, 0)
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Sniper" then
        local vpX,vpY = VP.X,VP.Y
        CH.sn1.From=Vector2.new(0,cy);       CH.sn1.To=Vector2.new(cx-gap,cy)
        CH.sn2.From=Vector2.new(cx+gap,cy);  CH.sn2.To=Vector2.new(vpX,cy)
        CH.sn3.From=Vector2.new(cx,0);       CH.sn3.To=Vector2.new(cx,cy-gap)
        CH.sn4.From=Vector2.new(cx,cy+gap);  CH.sn4.To=Vector2.new(cx,vpY)
        local snOp=mclamp(op+0.28,0,1)
        CH.sn1.Color=col; CH.sn1.Thickness=1; CH.sn1.Transparency=snOp; CH.sn1.Visible=true
        CH.sn2.Color=col; CH.sn2.Thickness=1; CH.sn2.Transparency=snOp; CH.sn2.Visible=true
        CH.sn3.Color=col; CH.sn3.Thickness=1; CH.sn3.Transparency=snOp; CH.sn3.Visible=true
        CH.sn4.Color=col; CH.sn4.Thickness=1; CH.sn4.Transparency=snOp; CH.sn4.Visible=true
        CH.ring.Position=Vector2.new(cx,cy); CH.ring.Color=col
        CH.ring.Radius=mmax(gap,6); CH.ring.Thickness=1; CH.ring.Transparency=op; CH.ring.Visible=true
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Radius=2; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Diamond" then
        local r=sz+gap
        local dtop=_CHPt(0,-r); local drgt=_CHPt(r,0)
        local dbot=_CHPt(0, r); local dlft=_CHPt(-r,0)
        CH.dm1.From=dtop; CH.dm1.To=drgt; CH.dm1.Color=col; CH.dm1.Thickness=th; CH.dm1.Transparency=op; CH.dm1.Visible=true
        CH.dm2.From=drgt; CH.dm2.To=dbot; CH.dm2.Color=col; CH.dm2.Thickness=th; CH.dm2.Transparency=op; CH.dm2.Visible=true
        CH.dm3.From=dbot; CH.dm3.To=dlft; CH.dm3.Color=col; CH.dm3.Thickness=th; CH.dm3.Transparency=op; CH.dm3.Visible=true
        CH.dm4.From=dlft; CH.dm4.To=dtop; CH.dm4.Color=col; CH.dm4.Thickness=th; CH.dm4.Transparency=op; CH.dm4.Visible=true
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true

    elseif style=="Bracket" then
        local bSz=sz; local a2=mmax(mfloor(bSz*0.45),4)
        local x1=cx-gap-bSz; local x2=cx+gap+bSz
        local y1=cy-gap-bSz; local y2=cy+gap+bSz
        CH.br1.From=Vector2.new(x1,y1);   CH.br1.To=Vector2.new(x1+a2,y1)
        CH.br2.From=Vector2.new(x1,y1);   CH.br2.To=Vector2.new(x1,y1+a2)
        CH.br3.From=Vector2.new(x2,y1);   CH.br3.To=Vector2.new(x2-a2,y1)
        CH.br4.From=Vector2.new(x2,y1);   CH.br4.To=Vector2.new(x2,y1+a2)
        CH.br5.From=Vector2.new(x1,y2);   CH.br5.To=Vector2.new(x1+a2,y2)
        CH.br6.From=Vector2.new(x1,y2);   CH.br6.To=Vector2.new(x1,y2-a2)
        CH.br7.From=Vector2.new(x2,y2);   CH.br7.To=Vector2.new(x2-a2,y2)
        CH.br8.From=Vector2.new(x2,y2);   CH.br8.To=Vector2.new(x2,y2-a2)
        for _,k in ipairs({"br1","br2","br3","br4","br5","br6","br7","br8"}) do
            CH[k].Color=col; CH[k].Thickness=th; CH[k].Transparency=op; CH[k].Visible=true
        end
        CH.dot.Position=Vector2.new(cx,cy); CH.dot.Color=col; CH.dot.Transparency=op; CH.dot.Visible=true
    end
end

-- ══════════════════════════════════════════
--  HITMARKER
-- ══════════════════════════════════════════
local function TriggerHitmarker()
    if State.HitmarkerEnabled then hmActive=true; hmTimer=0.28 end
end
local function HookHitmarker(p)
    if p==LocalPlayer then return end
    local function connectHum(char)
        local hum=char:WaitForChild("Humanoid",5); if not hum then return end
        local prev=hum.Health
        hum.HealthChanged:Connect(function(hp) if hp<prev then TriggerHitmarker() end; prev=hp end)
    end
    p.CharacterAdded:Connect(connectHum)
    if p.Character then task.spawn(connectHum,p.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do HookHitmarker(p) end
Players.PlayerAdded:Connect(HookHitmarker)

local function UpdateHitmarker(dt)
    if not State.HitmarkerEnabled or not hmActive then
        HM.tl.Visible=false; HM.tr.Visible=false; HM.bl.Visible=false; HM.br.Visible=false; return
    end
    hmTimer=hmTimer-dt
    if hmTimer<=0 then
        hmActive=false
        HM.tl.Visible=false; HM.tr.Visible=false; HM.bl.Visible=false; HM.br.Visible=false; return
    end
    local cx=VP_CX; local cy=VP_CY; local s=9; local fade=mclamp(hmTimer/0.28,0,1)
    local tr=1-fade
    HM.tl.Transparency=tr; HM.tr.Transparency=tr; HM.bl.Transparency=tr; HM.br.Transparency=tr
    HM.tl.From=Vector2.new(cx-2,cy-2); HM.tl.To=Vector2.new(cx-2-s,cy-2-s); HM.tl.Visible=true
    HM.tr.From=Vector2.new(cx+2,cy-2); HM.tr.To=Vector2.new(cx+2+s,cy-2-s); HM.tr.Visible=true
    HM.bl.From=Vector2.new(cx-2,cy+2); HM.bl.To=Vector2.new(cx-2-s,cy+2+s); HM.bl.Visible=true
    HM.br.From=Vector2.new(cx+2,cy+2); HM.br.To=Vector2.new(cx+2+s,cy+2+s); HM.br.Visible=true
end

-- ══════════════════════════════════════════
--  NO RECOIL  (Heartbeat — decoupled from render, AC-09)
-- ══════════════════════════════════════════
local lastCamCF=nil
local _nrJitter=0
RunService.Heartbeat:Connect(function(dt)
    if not State.NoRecoilEnabled or not lastCamCF then return end
    local lmb=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if not lmb then _nrJitter=0; return end
    local camCF=Camera.CFrame
    local px=select(1,lastCamCF:ToEulerAnglesYXZ())
    local ccx,ccy,ccz=camCF:ToEulerAnglesYXZ()
    local delta=ccx-px
    if delta>0.0004 then
        -- AC-05: add tiny jitter so recoil isn't perfectly zeroed
        _nrJitter=(_nrJitter+dt*3)%0.002-0.001
        pcall(function()
            Camera.CFrame=CFrame.new(camCF.Position)
                *CFrame.fromEulerAnglesYXZ(ccx-delta*(1-State.RecoilStrength)+_nrJitter,ccy,ccz)
        end)
    end
    lastCamCF=Camera.CFrame
end)

-- ══════════════════════════════════════════
--  TRIGGERBOT  (Heartbeat — no yield, AC-03 coords)
-- ══════════════════════════════════════════
local _trigAcc=0  -- delay accumulator in seconds
local _trigArmed=false
RunService.Heartbeat:Connect(function(dt)
    if not State.TriggerBot or not VIM then _trigAcc=0; _trigArmed=false; return end
    local target=Mouse.Target
    if not target then _trigAcc=0; _trigArmed=false; return end
    local model=target:FindFirstAncestorOfClass("Model")
    if not model then _trigAcc=0; _trigArmed=false; return end
    local p=Players:GetPlayerFromCharacter(model)
    if not p or p==LocalPlayer or IsAimTeammate(p) then _trigAcc=0; _trigArmed=false; return end
    local char=p.Character
    if not char then _trigAcc=0; _trigArmed=false; return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then _trigAcc=0; _trigArmed=false; return end
    -- valid target on cursor — accumulate delay
    local lmb=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if lmb then _trigAcc=0; return end  -- already pressing
    _trigAcc=_trigAcc+dt
    local needed=(State.TrigDelay or 0)/1000  -- convert ms to seconds
    if _trigAcc>=needed then
        _trigAcc=0
        local mx=Mouse.X; local my=Mouse.Y
        pcall(function()
            VIM:SendMouseButtonEvent(mx,my,Enum.UserInputType.MouseButton1,true,game,0)
            VIM:SendMouseButtonEvent(mx,my,Enum.UserInputType.MouseButton1,false,game,0)
        end)
    end
end)

-- ══════════════════════════════════════════
--  GODMODE  (FIX-05: event-driven, AC-02)
-- ══════════════════════════════════════════
local godConn=nil
local function SetupGodMode(char)
    if godConn then godConn:Disconnect(); godConn=nil end
    if not State.GodModeEnabled or not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    -- AC-02: DON'T change MaxHealth — cache the real value, restore to it on damage.
    -- Changing MaxHealth to extreme values is a flagged AC pattern in Project Delta.
    local origMax=hum.MaxHealth
    godConn=hum.HealthChanged:Connect(function(hp)
        if hp<origMax*0.95 then
            -- restore to original max, not an astronomical value
            pcall(function() hum.Health=origMax end)
        end
    end)
end

-- ══════════════════════════════════════════
--  ANTI-RAGDOLL  (FIX-04: signal-driven, not per-frame)
-- ══════════════════════════════════════════
local function ApplyAntiRagdoll(char)
    if not State.AntiRagdoll or not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false) end)
    end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
            pcall(function() v.Enabled=false end)
        end
    end
end

-- ══════════════════════════════════════════
--  FULLBRIGHT / FOG
-- ══════════════════════════════════════════
local _oA,_oO,_oB,_oC
local function SetFullbright(on)
    if on then
        _oA=Lighting.Ambient; _oO=Lighting.OutdoorAmbient; _oB=Lighting.Brightness; _oC=Lighting.ClockTime
        Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1); Lighting.Brightness=2; Lighting.ClockTime=14
    else
        if _oA then Lighting.Ambient=_oA end; if _oO then Lighting.OutdoorAmbient=_oO end
        if _oB then Lighting.Brightness=_oB end; if _oC then Lighting.ClockTime=_oC end
    end
end
local function SetNoFog(on)
    for _,obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then pcall(function() obj.Density=on and 0 or 0.395; obj.Haze=on and 0 or 2.8 end) end
        if obj:IsA("FogEffect")  then pcall(function() obj.Enabled=not on end) end
    end
end

-- ══════════════════════════════════════════
--  HITBOX EXPANDER  (AC-01: client-local, blank name, Heartbeat)
-- ══════════════════════════════════════════
local HitboxObjects={}
local hitboxConn=nil

local function StartHitboxExpander()
    if hitboxConn then hitboxConn:Disconnect(); hitboxConn=nil end
    if not State.HitboxExpander then
        for p,part in pairs(HitboxObjects) do pcall(function()part:Destroy()end); HitboxObjects[p]=nil end; return
    end
    hitboxConn=RunService.Heartbeat:Connect(function()
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer then continue end
            local char=p.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if root then
                if not HitboxObjects[p] or not HitboxObjects[p].Parent then
                    -- AC-01: blank name, no WeldConstraint, CFrame-updated every Heartbeat
                    local part=Instance.new("Part")
                    part.Name=""  -- blank name: no "HitboxExpand" detection string
                    part.Anchored=true
                    part.CanCollide=false   -- AC-01: false avoids physics-collision detection; CanQuery handles raycasts
                    part.Transparency=1
                    part.CanQuery=true
                    part.CanTouch=false
                    part.CastShadow=false
                    part.Size=Vector3.new(State.HitboxSize,State.HitboxSize,State.HitboxSize)
                    part.CFrame=root.CFrame
                    part.Parent=char  -- parent to char, not Workspace
                    HitboxObjects[p]=part
                else
                    -- Update position each Heartbeat; update size if changed
                    local part=HitboxObjects[p]
                    part.CFrame=root.CFrame
                    if part.Size.X~=State.HitboxSize then
                        part.Size=Vector3.new(State.HitboxSize,State.HitboxSize,State.HitboxSize)
                    end
                end
            else
                if HitboxObjects[p] then pcall(function()HitboxObjects[p]:Destroy()end); HitboxObjects[p]=nil end
            end
        end
    end)
end

-- ══════════════════════════════════════════
--  CHARACTER EVENTS
-- ══════════════════════════════════════════
local function OnLocalCharAdded(char)
    char:WaitForChild("Humanoid",5)
    if State.NoFogEnabled   then SetNoFog(true)       end
    if State.FullbrightEnabled then SetFullbright(true) end
    if State.GodModeEnabled then SetupGodMode(char)   end
    if State.AntiRagdoll    then ApplyAntiRagdoll(char) end
    if State.AutoRespawn then
        local hum=char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Died:Connect(function() task.wait(0.1); LocalPlayer:LoadCharacter() end) end
    end
    lastCamCF=nil
end

LocalPlayer.CharacterAdded:Connect(OnLocalCharAdded)
if LocalPlayer.Character then task.spawn(OnLocalCharAdded,LocalPlayer.Character) end

Players.PlayerAdded:Connect(function(p)
    MakeESP(p)
end)
Players.PlayerRemoving:Connect(function(p)
    KillESP(p); lastTargetPos[p]=nil
    if lockedTarget==p then lockedTarget=nil end
    if HitboxObjects[p] then pcall(function()HitboxObjects[p]:Destroy()end); HitboxObjects[p]=nil end
end)

-- ══════════════════════════════════════════
--  RENDER LOOP  (hot path — RenderStepped)
-- ══════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    _frameTick=tick()

    -- FPS counter
    fpsFrames=fpsFrames+1; fpsElapsed=fpsElapsed+dt
    if fpsElapsed>=0.5 then
        fpsVal=mfloor(fpsFrames/fpsElapsed); fpsFrames=0; fpsElapsed=0
        -- Update ping at same interval — avoids pcall+GetNetworkPing 60x/sec
        if State.ShowPing then
            local ok,p=pcall(function() return mfloor(LocalPlayer:GetNetworkPing()*1000) end)
            pingVal=ok and p or 0
        end
    end

    -- Cache once per frame
    local camCF=Camera.CFrame
    local myChar=LocalPlayer.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- Update lastCamCF for NoRecoil (Heartbeat reads it)
    lastCamCF=camCF

    -- FOV circle
    FOVCircle.Position=Vector2.new(VP_CX,VP_CY)
    FOVCircle.Radius=State.AimbotFOV
    FOVCircle.Color=State.FOVColor
    FOVCircle.Visible=State.AimbotEnabled and State.FOVVisible

    -- Aimbot
    RunAimbot(camCF)

    -- TriggerBot handled in Heartbeat (see below) — removed from RenderStepped to avoid illegal yield

    -- ESP
    local rcol=State.ESPRainbow and RainbowHSV(0.4) or nil
    UpdatePlayerESP(myRoot,rcol)
    UpdateAIESP(myRoot)
    UpdateLootESP(myRoot)
    UpdateExfilESP(dt,myRoot)
    UpdateZoom()
    UpdateCrosshair(dt)
    UpdateHitmarker(dt)

    -- FPS / Ping labels
    if State.ShowFPS then
        FPSLabel.Text=sfmt("FPS: %d",fpsVal)
        FPSLabel.Visible=true
    else FPSLabel.Visible=false end
    if State.ShowPing then
        PingLabel.Text=sfmt("Ping: %d ms",pingVal)
        PingLabel.Visible=true
    else PingLabel.Visible=false end
end)

-- ══════════════════════════════════════════════════════════════
--  RAYFIELD TABS
-- ══════════════════════════════════════════════════════════════

-- ── 👁  PLAYER ESP ────────────────────────
local T1=Window:CreateTab("👁  Player ESP",4483362458)
T1:CreateSection("Visibility")
T1:CreateToggle({Name="Enable Player ESP",CurrentValue=false,Flag="E_ESP",
    Callback=function(v) State.ESPEnabled=v; if not v then for _,o in pairs(ESPObjects) do HideESP(o) end end end})
T1:CreateToggle({Name="Health Bars",   CurrentValue=false,Flag="E_HP",  Callback=function(v)State.ESPHealthBars=v end})
T1:CreateToggle({Name="Tracers",       CurrentValue=false,Flag="E_TR",  Callback=function(v)State.ESPTracers=v end})
T1:CreateToggle({Name="Skeleton",      CurrentValue=false,Flag="E_SK",  Callback=function(v)State.ESPSkeleton=v end})
T1:CreateToggle({Name="Names",         CurrentValue=true, Flag="E_NM",  Callback=function(v)State.ESPNames=v end})
T1:CreateToggle({Name="Distance",      CurrentValue=true, Flag="E_DT",  Callback=function(v)State.ESPDistance=v end})
T1:CreateToggle({Name="Weapon Label",  CurrentValue=true, Flag="E_WP",  Callback=function(v)State.ESPWeapon=v end})
T1:CreateToggle({Name="Show Box",         CurrentValue=true, Flag="E_BOX", Callback=function(v)State.ESPBoxEnabled=v end})
T1:CreateToggle({Name="Fill Box",         CurrentValue=true, Flag="E_FIL", Callback=function(v)State.ESPFillBox=v end})
T1:CreateToggle({Name="Corner Box Style",CurrentValue=false,Flag="E_CRN",
    Callback=function(v)State.ESPCornerBox=v end})
T1:CreateToggle({Name="Team Check",    CurrentValue=false,Flag="E_TM",  Callback=function(v)State.ESPTeamCheck=v end})
T1:CreateSection("Colour")
T1:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="E_RBW",Callback=function(v)State.ESPRainbow=v end})
T1:CreateColorPicker({Name="Box Color",Color=Color3.fromRGB(220,80,80),Flag="E_COL",Callback=function(v)State.BoxColor=v end})
T1:CreateSection("Range & Scale")
T1:CreateSlider({Name="Text Size",    Range={10,22},  Increment=1, Suffix=" px",   CurrentValue=14, Flag="E_TS", Callback=function(v)State.ESPTextSize=v end})
T1:CreateSlider({Name="Max Distance", Range={50,2000},Increment=50,Suffix=" studs",CurrentValue=500,Flag="E_MD", Callback=function(v)State.ESPMaxDist=v end})

-- ── 🤖  AI ESP ────────────────────────────
local T2=Window:CreateTab("🤖  AI ESP",4483362458)
T2:CreateSection("AI / NPC Detection")
T2:CreateToggle({Name="Enable AI ESP",CurrentValue=false,Flag="AI_ON",
    Callback=function(v) State.AIESPEnabled=v; if not v then for m,_ in pairs(AIESPObjects) do KillAIESP(m) end end end})
T2:CreateToggle({Name="Names",   CurrentValue=true, Flag="AI_NM",Callback=function(v)State.AIESPNames=v end})
T2:CreateToggle({Name="Health",  CurrentValue=true, Flag="AI_HP",Callback=function(v)State.AIESPHealth=v end})
T2:CreateToggle({Name="Tracers", CurrentValue=false,Flag="AI_TR",Callback=function(v)State.AIESPTracers=v end})
T2:CreateSection("Colour")
T2:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="AI_RBW",Callback=function(v)State.AIESPRainbow=v end})
T2:CreateColorPicker({Name="Box Color",Color=Color3.fromRGB(255,160,30),Flag="AI_COL",Callback=function(v)State.AIBoxColor=v end})
T2:CreateSection("Range")
T2:CreateSlider({Name="Max Distance",Range={50,1500},Increment=25,Suffix=" studs",CurrentValue=400,Flag="AI_MD",Callback=function(v)State.AIESPMaxDist=v end})
T2:CreateLabel("Signal-driven live tracking — zero periodic scans, zero frame-time spikes.")

-- ── 💎  LOOT ESP ──────────────────────────
local T3=Window:CreateTab("💎  Loot ESP",4483362458)
T3:CreateSection("Master")
T3:CreateToggle({Name="Enable Loot ESP",CurrentValue=false,Flag="L_ON",
    Callback=function(v) State.LootESPEnabled=v; if not v then for i,_ in pairs(LootESPObjects) do KillLootESP(i) end end end})
T3:CreateSlider({Name="Max Distance",Range={50,1000},Increment=25,Suffix=" studs",CurrentValue=300,Flag="L_MD",Callback=function(v)State.LootMaxDist=v end})
T3:CreateSlider({Name="Label Size",  Range={8,18},   Increment=1, Suffix=" px",   CurrentValue=12, Flag="L_TS",Callback=function(v)State.LootTextSize=v end})
T3:CreateSection("Item Filters")
T3:CreateToggle({Name="🔑 Keys & Keycards",    CurrentValue=true, Flag="LF_K",Callback=function(v)State.LootFilter.Keys=v end})
T3:CreateToggle({Name="💀 Dead Bodies",         CurrentValue=true, Flag="LF_B",Callback=function(v)State.LootFilter.Bodies=v end})
T3:CreateToggle({Name="🔫 Weapons",             CurrentValue=true, Flag="LF_W",Callback=function(v)State.LootFilter.Weapons=v end})
T3:CreateToggle({Name="🔹 Ammo",                CurrentValue=true, Flag="LF_A",Callback=function(v)State.LootFilter.Ammo=v end})
T3:CreateToggle({Name="💊 Medical",             CurrentValue=true, Flag="LF_M",Callback=function(v)State.LootFilter.Medical=v end})
T3:CreateToggle({Name="💎 Valuables",           CurrentValue=true, Flag="LF_V",Callback=function(v)State.LootFilter.Valuables=v end})
T3:CreateToggle({Name="📦 Containers",          CurrentValue=true, Flag="LF_C",Callback=function(v)State.LootFilter.Containers=v end})
T3:CreateToggle({Name="·  Other",               CurrentValue=false,Flag="LF_O",Callback=function(v)State.LootFilter.Other=v end})
T3:CreateSection("Category Colors")
for cat,col in pairs(State.LootColors) do
    T3:CreateColorPicker({Name=cat,Color=col,Flag="LC_"..cat,Callback=function(v)State.LootColors[cat]=v end})
end

-- ── 🚁  EXFIL ESP ─────────────────────────
local T4=Window:CreateTab("🚁  Exfil ESP",4483362458)
T4:CreateSection("Extraction Zone")
T4:CreateToggle({Name="Enable Exfil ESP",CurrentValue=false,Flag="X_ON",
    Callback=function(v) State.ExfilESPEnabled=v
        if not v then
            for i,_ in pairs(ExfilESPObjects) do KillExfilESP(i) end
            ExfilArrow.shaft.Visible=false; ExfilArrow.head1.Visible=false
            ExfilArrow.head2.Visible=false; ExfilArrow.label.Visible=false
        end
    end})
T4:CreateToggle({Name="Show Distance",  CurrentValue=true, Flag="X_DT", Callback=function(v)State.ExfilShowDist=v end})
T4:CreateToggle({Name="Pulse Ring",     CurrentValue=true, Flag="X_PLS",Callback=function(v)State.ExfilPulse=v end})
T4:CreateToggle({Name="Off-Screen Arrow",CurrentValue=true,Flag="X_ARR",Callback=function(v)State.ExfilArrow=v end})
T4:CreateSection("Colour")
T4:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="X_RBW",Callback=function(v)State.ExfilRainbow=v end})
T4:CreateColorPicker({Name="Exfil Color",Color=Color3.fromRGB(80,255,140),Flag="X_COL",Callback=function(v)State.ExfilColor=v end})
T4:CreateSection("Range")
T4:CreateSlider({Name="Max Distance",Range={100,5000},Increment=100,Suffix=" studs",CurrentValue=2000,Flag="X_MD",Callback=function(v)State.ExfilMaxDist=v end})

-- ── 🎯  AIMBOT ────────────────────────────
local T5=Window:CreateTab("🎯  Aimbot",4483362458)
T5:CreateSection("Enable & Mode")
T5:CreateToggle({Name="Enable Aimbot",CurrentValue=false,Flag="A_ON",
    Callback=function(v)
        State.AimbotEnabled=v
        FOVCircle.Visible=v and State.FOVVisible
        if not v then LockDot.Visible=false; lockedTarget=nil end
    end})
T5:CreateDropdown({Name="Aim Mode",Options={"Smooth","Blatant","Instant"},CurrentOption={"Smooth"},Flag="A_MODE",
    Callback=function(v)State.AimbotMode=v[1] or "Smooth"; Notify("TravHub","Mode: "..State.AimbotMode,2) end})
T5:CreateDropdown({Name="Aim Key",Options={"MouseButton2","C","Q","E","F"},CurrentOption={"MouseButton2"},Flag="A_KEY",
    Callback=function(v)State.AimKey=v[1] or "MouseButton2" end})
T5:CreateSection("Targeting")
T5:CreateToggle({Name="Team Check",       CurrentValue=false,Flag="A_TM",   Callback=function(v)State.TeamCheck=v end})
T5:CreateToggle({Name="Lock-On Target",   CurrentValue=false,Flag="A_LOCK", Callback=function(v)State.AimbotLock=v; lockedTarget=nil end})
T5:CreateToggle({Name="Trigger Bot",      CurrentValue=false,Flag="A_TRIG", Callback=function(v)State.TriggerBot=v end})
T5:CreateSlider({Name="Trig Delay (ms)", Range={0,200},Increment=5,Suffix=" ms",CurrentValue=0,Flag="A_TDLY",Callback=function(v)State.TrigDelay=v end})
T5:CreateToggle({Name="Silent Aim",       CurrentValue=false,Flag="A_SILA", Callback=function(v)State.SilentAim=v end})
T5:CreateDropdown({Name="Target Part",Options={"Head","HumanoidRootPart","UpperTorso","Torso","LeftUpperArm","RightUpperArm"},
    CurrentOption={"Head"},Flag="A_PART",Callback=function(v)State.AimbotPart=v[1] or "Head"; lockedTarget=nil end})
T5:CreateSection("Smooth")
T5:CreateSlider({Name="Smooth Speed",Range={1,25},Increment=1,CurrentValue=5,Flag="A_SS",
    Callback=function(v)State.AimbotSmooth=0.025+v*0.014 end})
T5:CreateSection("Blatant")
T5:CreateSlider({Name="Snap Speed",Range={30,99},Increment=1,Suffix="%",CurrentValue=55,Flag="A_BS",
    Callback=function(v)State.AimbotBlatant=v/100 end})
T5:CreateSection("Prediction")
T5:CreateToggle({Name="Target Prediction",CurrentValue=false,Flag="A_PRD",Callback=function(v)State.AimbotPredict=v end})
T5:CreateSlider({Name="Strength",Range={1,10},Increment=1,CurrentValue=5,Flag="A_PRS",
    Callback=function(v)State.AimbotPredictStr=v/10 end})
T5:CreateSection("FOV Circle")
T5:CreateSlider({Name="FOV Radius",Range={20,700},Increment=5,Suffix=" px",CurrentValue=150,Flag="A_FOVR",
    Callback=function(v)State.AimbotFOV=v end})
T5:CreateToggle({Name="Show FOV Circle",CurrentValue=true,Flag="A_FOVV",
    Callback=function(v)State.FOVVisible=v; FOVCircle.Visible=State.AimbotEnabled and v end})
T5:CreateColorPicker({Name="FOV Color",Color=Color3.fromRGB(180,100,255),Flag="A_FOVC",
    Callback=function(v)State.FOVColor=v; FOVCircle.Color=v end})

-- ── 🔭  ZOOM ──────────────────────────────
local T6=Window:CreateTab("🔭  Zoom",4483362458)
T6:CreateSection("Scope Zoom")
T6:CreateToggle({Name="Enable Zoom",CurrentValue=false,Flag="Z_ON",
    Callback=function(v)
        State.ZoomEnabled=v
        if not v and State.ZoomActive then
            State.ZoomActive=false; CancelZoomTween()
            Camera.FieldOfView=State.CameraFOV; ShowZoomOverlay(false)
        end
    end})
T6:CreateDropdown({Name="Zoom Key",Options={"Z","X","V","F","G"},CurrentOption={"Z"},Flag="Z_KEY",
    Callback=function(v)State.ZoomKey=v[1] or "Z" end})
T6:CreateSlider({Name="Zoom FOV",Range={5,60},Increment=1,Suffix="°",CurrentValue=20,Flag="Z_FOV",
    Callback=function(v)State.ZoomFOV=v; if State.ZoomActive then SetCameraFOV(v,State.ZoomSmooth,0.10) end end})
T6:CreateSlider({Name="Zoom Speed",Range={5,30},Increment=1,CurrentValue=18,Flag="Z_SPD",
    Callback=function(v)State.ZoomSpeed=v/100 end})
T6:CreateToggle({Name="Smooth Transition",CurrentValue=true,Flag="Z_SM",Callback=function(v)State.ZoomSmooth=v end})
T6:CreateSection("Overlay")
T6:CreateToggle({Name="Scope Overlay",CurrentValue=true,Flag="Z_OVL",
    Callback=function(v)State.ZoomOverlay=v; if not v then ShowZoomOverlay(false) end end})
T6:CreateColorPicker({Name="Overlay Color",Color=Color3.fromRGB(180,220,255),Flag="Z_OVC",
    Callback=function(v)State.ZoomOverlayColor=v end})
T6:CreateLabel("FOV 20 ≈ 3×  |  FOV 10 ≈ 6×  |  FOV 5 ≈ 12×")

-- ── ⚔️  COMBAT ────────────────────────────
local T7=Window:CreateTab("⚔️  Combat",4483362458)
T7:CreateSection("Recoil")
T7:CreateToggle({Name="No Recoil",CurrentValue=false,Flag="C_NR",
    Callback=function(v)State.NoRecoilEnabled=v; lastCamCF=nil end})
T7:CreateSlider({Name="Reduction %",Range={10,100},Increment=5,Suffix="%",CurrentValue=80,Flag="C_NRS",
    Callback=function(v)State.RecoilStrength=1-(v/100) end})
T7:CreateSection("Hitbox")
T7:CreateToggle({Name="Hitbox Expander",CurrentValue=false,Flag="C_HBX",
    Callback=function(v)State.HitboxExpander=v; StartHitboxExpander() end})
T7:CreateSlider({Name="Hitbox Size",Range={2,20},Increment=1,Suffix=" studs",CurrentValue=6,Flag="C_HBXS",
    Callback=function(v)State.HitboxSize=v end})
T7:CreateSection("Defense")
T7:CreateToggle({Name="Auto Parry / Block",CurrentValue=false,Flag="C_AP",Callback=function(v)State.AutoParry=v end})

-- ── 🎨  VISUALS ───────────────────────────
local T8=Window:CreateTab("🎨  Visuals",4483362458)
T8:CreateSection("Lighting")
T8:CreateToggle({Name="Fullbright",CurrentValue=false,Flag="V_FB",Callback=function(v)State.FullbrightEnabled=v;SetFullbright(v) end})
T8:CreateToggle({Name="Remove Fog",CurrentValue=false,Flag="V_FOG",Callback=function(v)State.NoFogEnabled=v;SetNoFog(v) end})
T8:CreateSection("Camera")
T8:CreateSlider({Name="Field of View",Range={50,120},Increment=1,Suffix="°",CurrentValue=70,Flag="V_FOV",
    Callback=function(v)
        State.CameraFOV=v
        if not State.ZoomActive then CancelZoomTween(); Camera.FieldOfView=v end
    end})
T8:CreateSection("Crosshair")
T8:CreateToggle({Name="Enable Crosshair",CurrentValue=false,Flag="V_CH",
    Callback=function(v)State.CustomCrosshair=v; if not v then HideCrosshair(); _lastCHStyle="" end end})
T8:CreateDropdown({
    Name="Style",
    Options={"Plus","X","Dot","Circle","T-Shape","Happy Face","KovaaK","Sniper","Diamond","Bracket"},
    CurrentOption={"Plus"},
    Flag="V_CHS",
    Callback=function(v)State.CrosshairStyle=v[1] or "Plus" end
})
T8:CreateToggle({Name="🌈 Rainbow",  CurrentValue=false,Flag="V_CHRBW",Callback=function(v)State.CrosshairRainbow=v end})
T8:CreateToggle({Name="🔄 Spinning", CurrentValue=false,Flag="V_CHSP",
    Callback=function(v)State.CrosshairSpin=v; if not v then chAngle=0 end end})
T8:CreateSlider({Name="Spin Speed", Range={10,720},Increment=10,Suffix="°/s",CurrentValue=90,Flag="V_CHSS",Callback=function(v)State.CrosshairSpinSpeed=v end})
T8:CreateSlider({Name="Size",       Range={4,60}, Increment=1, Suffix=" px", CurrentValue=12,Flag="V_SZ",  Callback=function(v)State.CrosshairSize=v end})
T8:CreateSlider({Name="Gap",        Range={0,30}, Increment=1, Suffix=" px", CurrentValue=4, Flag="V_GAP", Callback=function(v)State.CrosshairGap=v end})
T8:CreateSlider({Name="Thickness",  Range={1,6},  Increment=1, Suffix=" px", CurrentValue=2, Flag="V_TH",  Callback=function(v)State.CrosshairThick=v end})
T8:CreateSlider({Name="Opacity",    Range={0,90}, Increment=5, Suffix="%",   CurrentValue=0, Flag="V_OP",  Callback=function(v)State.CrosshairOpacity=v/100 end})
T8:CreateColorPicker({Name="Color",Color=Color3.fromRGB(255,255,255),Flag="V_COL",Callback=function(v)State.CrosshairColor=v end})
T8:CreateSection("Hit Feedback")
T8:CreateToggle({Name="Hitmarker",CurrentValue=false,Flag="V_HM",Callback=function(v)State.HitmarkerEnabled=v end})
T8:CreateSection("Performance")
T8:CreateToggle({Name="FPS Display", CurrentValue=false,Flag="V_FPS",Callback=function(v)State.ShowFPS=v end})
T8:CreateToggle({Name="Ping Display",CurrentValue=false,Flag="V_PNG",Callback=function(v)State.ShowPing=v end})
T8:CreateSection("Amethyst Decor")
T8:CreateToggle({Name="Crystal Borders",CurrentValue=true,Flag="V_CRYS",
    Callback=function(v)
        for _,set in ipairs(ScreenCrystals) do
            for _,l in ipairs(set) do pcall(function()l.Visible=v end) end
        end
    end})

-- ── 🛡  SURVIVE ───────────────────────────
local T9=Window:CreateTab("🛡  Survive",4483362458)
T9:CreateSection("Protection")
T9:CreateToggle({Name="God Mode",CurrentValue=false,Flag="SV_GOD",
    Callback=function(v)
        State.GodModeEnabled=v
        SetupGodMode(LocalPlayer.Character)
        if not v and godConn then godConn:Disconnect(); godConn=nil end
    end})
T9:CreateToggle({Name="Anti-Ragdoll",CurrentValue=false,Flag="SV_RAG",
    Callback=function(v)
        State.AntiRagdoll=v
        if v then ApplyAntiRagdoll(LocalPlayer.Character) end
    end})
T9:CreateToggle({Name="Auto Respawn",CurrentValue=false,Flag="SV_RSP",Callback=function(v)State.AutoRespawn=v end})

-- ── 🔧  MISC ──────────────────────────────
local T10=Window:CreateTab("🔧  Misc",4483362458)
T10:CreateSection("Server Tools")
T10:CreateButton({Name="Rejoin",
    Callback=function()
        Notify("TravHub","Rejoining...",2); task.wait(0.5)
        TeleportService:Teleport(game.PlaceId,LocalPlayer)
    end})
T10:CreateButton({Name="Server Hop",
    Callback=function()
        Notify("TravHub","Hopping...",2); task.wait(0.5)
        local servers={}
        Safe(function()
            local data=HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
            for _,s in ipairs(data.data or {}) do
                if s.id~=game.JobId and s.playing<s.maxPlayers then tinsert(servers,s.id) end
            end
        end)
        if #servers>0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId,servers[mrandom(1,#servers)],LocalPlayer)
        else
            Notify("TravHub","No open servers found.",4)
            TeleportService:Teleport(game.PlaceId,LocalPlayer)
        end
    end})
T10:CreateSection("Utilities")
T10:CreateButton({Name="Copy Player List",
    Callback=function()
        local list={}
        for _,p in ipairs(Players:GetPlayers()) do
            tinsert(list,sfmt("%s (%s)",p.Name,p.DisplayName))
        end
        if setclipboard then setclipboard(table.concat(list,"\n")); Notify("TravHub","Copied "..#list.." players.",3)
        else print(table.concat(list,"\n")); Notify("TravHub","Printed to console ("..#list.." players).",3) end
    end})
T10:CreateButton({Name="Log Remote Events",
    Callback=function()
        local n=0
        for _,v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                print("[TravHub] "..v:GetFullName()); n=n+1
            end
        end
        Notify("TravHub","Logged "..n.." remotes to console.",4)
    end})
T10:CreateButton({Name="Kill Particles",
    Callback=function()
        local n=0; local myChar=LocalPlayer.Character or Instance.new("Folder")
        for _,v in ipairs(Workspace:GetDescendants()) do
            if (v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles"))
            and not v:IsDescendantOf(myChar) then
                pcall(function()v.Enabled=false end); n=n+1
            end
        end
        Notify("TravHub","Disabled "..n.." emitters.",3)
    end})
T10:CreateSection("About")
T10:CreateLabel("TravHub v3.8  ·  Crystal Edition  ·  Zero Stutter Edition")
T10:CreateLabel("10 Crosshairs  ·  Corner Box  ·  Fill Box  ·  AC-hardened")
T10:CreateLabel("Deferred scans  ·  Signal-driven GodMode & AntiRagdoll")
T10:CreateLabel("Personal script by Trav  🔒  Stay lowkey 🤫")

-- ══════════════════════════════════════════
--  STARTUP
-- ══════════════════════════════════════════
-- Bootstrap signal-based candidate sets from existing workspace state
task.defer(function()
    _AIBootstrap()
    _LootBootstrap()
    _ExfilBootstrap()
end)
Rayfield:LoadConfiguration()
task.wait(0.3)
Notify("TravHub v3.8 ✦","Zero Stutter Edition — crosshair fixed, signal-driven ESP ✨",6)
