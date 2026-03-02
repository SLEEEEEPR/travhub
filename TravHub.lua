-- ╔══════════════════════════════════════════════════════════╗
-- ║  TravHub  ·  Project Delta  ·  v3.9  Crystal Edition     ║
-- ║  Clean Build — Fixed crosshair, Xeno-compatible          ║
-- ╚══════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════
--  SERVICES
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
local Mouse            = LocalPlayer:GetMouse()

-- ══════════════════════════════════════════
--  ERROR SURFACING
-- ══════════════════════════════════════════
local function ShowError(msg)
    local s = tostring(msg):sub(1,120)
    warn("[TravHub FATAL] "..s)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="⚠ TravHub Error",Text=s,Duration=12})
    end)
end
local function ShowInfo(msg) warn("[TravHub] "..tostring(msg)) end

local _ok, _err = xpcall(function()

-- ══════════════════════════════════════════
--  MATH LOCALS
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

local function Safe(fn,...) pcall(fn,...) end

local function NewDraw(t,props)
    local o = Drawing.new(t)
    for k,v in pairs(props) do o[k]=v end
    return o
end

-- ══════════════════════════════════════════
--  AMETHYST PALETTE
-- ══════════════════════════════════════════
local AME = {
    deep   = Color3.fromRGB(38,12,72),
    dark   = Color3.fromRGB(64,20,110),
    mid    = Color3.fromRGB(120,50,200),
    bright = Color3.fromRGB(180,100,255),
    light  = Color3.fromRGB(220,160,255),
    white  = Color3.fromRGB(240,220,255),
    gold   = Color3.fromRGB(255,210,100),
    glow   = Color3.fromRGB(200,130,255),
}

-- ══════════════════════════════════════════
--  KEYAUTH CONFIG
-- ══════════════════════════════════════════
local KA_NAME    = "Mermorz's Application"
local KA_OWNERID = "hIIkGaxr8u"
local KA_SECRET  = "7f2253965f73618809126cba1ff66693c04f82888535c82709f9c17c9ceafdc1"
local KA_VER     = "1.0"
local KA_URL     = "https://keyauth.win/api/1.2/"

-- ══════════════════════════════════════════
--  HTTP WRAPPER  (Xeno: global request())
-- ══════════════════════════════════════════
local function _kaRequest(opts)
    local fn = nil
    if type(request)=="function"                              then fn=request
    elseif syn and type(syn.request)=="function"              then fn=syn.request
    elseif type(http_request)=="function"                     then fn=http_request
    elseif http and type(http.request)=="function"            then fn=http.request
    end
    if not fn then return nil,"No HTTP function found" end
    local ok,res = pcall(fn,opts)
    if not ok then return nil,tostring(res) end
    return res,nil
end

-- ══════════════════════════════════════════
--  KEYAUTH API
-- ══════════════════════════════════════════
local _kaSession = nil

local function _kaInit()
    local guid = HttpService:GenerateGUID(false):sub(1,32)
    local body = ("type=init&ver=%s&hash=&enckey=%s&name=%s&ownerid=%s&secret=%s"):format(
        KA_VER,
        HttpService:UrlEncode(guid),
        HttpService:UrlEncode(KA_NAME),
        HttpService:UrlEncode(KA_OWNERID),
        HttpService:UrlEncode(KA_SECRET)
    )
    local res,err = _kaRequest({
        Url=KA_URL, Method="POST",
        Headers={["Content-Type"]="application/x-www-form-urlencoded"},
        Body=body,
    })
    if err or not res then return false,"Network error: "..(err or "no response") end
    local ok,data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then return false,"Bad init response" end
    if not data.success then return false,tostring(data.message or "Init failed") end
    _kaSession = data.sessionid
    return true,"OK"
end

local function _kaLicense(key)
    if not _kaSession then return false,"Session not initialised" end
    local hwid = tostring(LocalPlayer.UserId)
    local body = ("type=license&key=%s&hwid=%s&sessionid=%s&name=%s&ownerid=%s"):format(
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(hwid),
        HttpService:UrlEncode(_kaSession),
        HttpService:UrlEncode(KA_NAME),
        HttpService:UrlEncode(KA_OWNERID)
    )
    local res,err = _kaRequest({
        Url=KA_URL, Method="POST",
        Headers={["Content-Type"]="application/x-www-form-urlencoded"},
        Body=body,
    })
    if err or not res then return false,"Network error: "..(err or "no response") end
    local ok,data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then return false,"Bad license response" end
    return data.success==true, tostring(data.message or (data.success and "Accepted" or "Invalid key"))
end

-- ══════════════════════════════════════════
--  KEY GATE UI
-- ══════════════════════════════════════════
local _keyPassed = false

do
    local _saved = ""
    pcall(function()
        if type(isfile)=="function" and isfile("TravHub_v39_Key.txt") then
            _saved = readfile("TravHub_v39_Key.txt"):gsub("%s+","")
        end
    end)

    local _gui = Instance.new("ScreenGui")
    _gui.Name="TravHubKeyGate"; _gui.ResetOnSpawn=false
    _gui.DisplayOrder=9999; _gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
    pcall(function() _gui.Parent=LocalPlayer.PlayerGui end)
    if not _gui.Parent then pcall(function() _gui.Parent=LocalPlayer:WaitForChild("PlayerGui",5) end) end

    local _overlay = Instance.new("Frame")
    _overlay.Size=UDim2.new(1,0,1,0); _overlay.BackgroundColor3=Color3.new(0,0,0)
    _overlay.BackgroundTransparency=0.45; _overlay.BorderSizePixel=0; _overlay.ZIndex=1
    _overlay.Parent=_gui

    local _panel = Instance.new("Frame")
    _panel.Size=UDim2.new(0,490,0,240); _panel.Position=UDim2.new(0.5,-245,0.5,-120)
    _panel.BackgroundColor3=Color3.fromRGB(12,4,28); _panel.BackgroundTransparency=0.05
    _panel.BorderSizePixel=0; _panel.ZIndex=2; _panel.Active=true; _panel.Parent=_gui

    local _stroke = Instance.new("UIStroke")
    _stroke.Color=Color3.fromRGB(160,80,255); _stroke.Thickness=2; _stroke.Parent=_panel

    local function _mkC(xA,yA,w,h)
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,w,0,h)
        f.Position=UDim2.new(xA,0,yA,0); f.BackgroundColor3=Color3.fromRGB(200,130,255)
        f.BorderSizePixel=0; f.ZIndex=3; f.Parent=_panel
    end
    _mkC(0,0,22,2);_mkC(0,0,2,22);_mkC(1,0,-22,2);_mkC(1,0,-2,22)
    _mkC(0,1,22,-2);_mkC(0,1,2,-22);_mkC(1,1,-22,-2);_mkC(1,1,-2,-22)

    local function _lbl(txt,y,sz,col,vis)
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,sz+4)
        l.Position=UDim2.new(0,0,0,y); l.BackgroundTransparency=1; l.Text=txt
        l.TextColor3=col; l.Font=Enum.Font.GothamBold; l.TextSize=sz
        l.ZIndex=3; l.Visible=vis~=false; l.Parent=_panel; return l
    end
    _lbl("TRAV HUB",8,36,Color3.fromRGB(200,130,255))
    _lbl("Project Delta  ·  Crystal Edition  ·  v3.9",54,12,Color3.fromRGB(160,130,200))

    local _sep=Instance.new("Frame"); _sep.Size=UDim2.new(1,-48,0,1); _sep.Position=UDim2.new(0,24,0,80)
    _sep.BackgroundColor3=Color3.fromRGB(100,60,160); _sep.BorderSizePixel=0; _sep.ZIndex=3; _sep.Parent=_panel

    local _step=_lbl("⟳  Connecting to KeyAuth...",88,12,Color3.fromRGB(160,130,200))
    _step.Font=Enum.Font.Gotham

    local _prmpt=_lbl("Enter your license key:",108,12,Color3.fromRGB(220,200,255),false)
    _prmpt.Font=Enum.Font.Gotham

    local _tb=Instance.new("TextBox"); _tb.Size=UDim2.new(1,-80,0,34)
    _tb.Position=UDim2.new(0,40,0,130); _tb.BackgroundColor3=Color3.fromRGB(28,8,58)
    _tb.BackgroundTransparency=0.1; _tb.BorderSizePixel=0; _tb.TextColor3=Color3.fromRGB(255,255,255)
    _tb.PlaceholderText=""; _tb.Font=Enum.Font.Gotham; _tb.TextSize=14
    _tb.ClearTextOnFocus=false; _tb.TextTruncate=Enum.TextTruncate.AtEnd
    _tb.ZIndex=4; _tb.Visible=false; _tb.Parent=_panel
    local _tbS=Instance.new("UIStroke"); _tbS.Color=Color3.fromRGB(160,80,255); _tbS.Thickness=1.5; _tbS.Parent=_tb

    local _hint=_lbl("Please wait...",_panel.Size.Y.Offset-26,11,Color3.fromRGB(120,100,160))
    _hint.Font=Enum.Font.Gotham

    -- Drag
    local _drag=Instance.new("Frame"); _drag.Size=UDim2.new(1,0,0,128)
    _drag.Position=UDim2.new(0,0,0,0); _drag.BackgroundTransparency=1; _drag.ZIndex=5; _drag.Parent=_panel
    local _dg,_ds,_dp=false,nil,nil
    _drag.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then _dg=true;_ds=i.Position;_dp=_panel.Position end end)
    _drag.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then _dg=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if _dg and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-_ds
            _panel.Position=UDim2.new(_dp.X.Scale,_dp.X.Offset+d.X,_dp.Y.Scale,_dp.Y.Offset+d.Y)
        end
    end)

    local _busy=false; local _attempts=0
    local function _setHint(t,c) _hint.Text=t; _hint.TextColor3=c end
    local function _fadeOut()
        for i=0,10 do
            local t=i/10
            pcall(function() _overlay.BackgroundTransparency=0.45+t*0.55 end)
            pcall(function() _panel.BackgroundTransparency=0.05+t*0.95 end)
            task.wait(0.016)
        end
        pcall(function() _gui:Destroy() end)
        _keyPassed=true
    end

    local function _showInput()
        _step.Visible=false; _prmpt.Visible=true; _tb.Visible=true; _tb.TextEditable=true
        task.wait(0.1); pcall(function() _tb:CaptureFocus() end)
        _setHint("Type or paste your key, then press ENTER",Color3.fromRGB(120,100,160))
    end

    local function _validate(key)
        local k=key:gsub("%s+","")
        if _busy or #k<4 then return end
        _busy=true; _tb.TextEditable=false
        _tbS.Color=Color3.fromRGB(180,160,255)
        _setHint("⟳  Checking key...",Color3.fromRGB(180,160,255))
        task.spawn(function()
            local ok,msg=_kaLicense(k)
            if ok then
                pcall(function() if type(writefile)=="function" then writefile("TravHub_v39_Key.txt",k) end end)
                _tbS.Color=Color3.fromRGB(80,255,120)
                _setHint("✦  Key accepted — loading hub...  ✦",Color3.fromRGB(80,255,120))
                task.wait(0.8); _fadeOut()
            else
                _attempts+=1
                _setHint(("✗  %s  (%d attempt%s)"):format(msg,_attempts,_attempts~=1 and "s" or ""),Color3.fromRGB(255,80,80))
                _tbS.Color=Color3.fromRGB(255,80,80)
                _tb.Text=""; _prmpt.Visible=true; _tb.Visible=true; _tb.TextEditable=true
                _busy=false; task.wait(0.15); pcall(function() _tb:CaptureFocus() end)
                task.wait(2.5)
                if not _keyPassed then _tbS.Color=Color3.fromRGB(160,80,255); _setHint("Type or paste your key, then press ENTER",Color3.fromRGB(120,100,160)) end
            end
        end)
    end

    _tb.FocusLost:Connect(function(enter) if enter and not _busy then _validate(_tb.Text) end end)

    -- Timeout guard — never hang forever
    local _initDone=false
    task.delay(12,function()
        if not _initDone and not _keyPassed then
            _step.Text="⚠ Connection slow — enter key manually"
            _step.TextColor3=Color3.fromRGB(255,200,80)
            _showInput()
        end
    end)

    task.spawn(function()
        ShowInfo("Connecting to KeyAuth...")
        local initOk,initMsg=_kaInit()
        _initDone=true
        if not initOk then
            ShowInfo("KeyAuth init failed: "..initMsg)
            _step.Text="✗  "..initMsg; _step.TextColor3=Color3.fromRGB(255,100,100)
            _setHint("Retrying...",Color3.fromRGB(255,150,80)); task.wait(3)
            initOk,initMsg=_kaInit()
            if not initOk then
                ShowInfo("Retry failed — showing input")
                _step.Text="⚠ Can't reach KeyAuth"; _step.TextColor3=Color3.fromRGB(255,120,0)
                _setHint("Enter key manually (offline mode)",Color3.fromRGB(255,180,80))
                _showInput(); return
            end
        end
        _step.Text="✦  Connected"; _step.TextColor3=Color3.fromRGB(100,255,160)
        ShowInfo("Connected. Checking saved key...")
        task.wait(0.4)
        if _saved~="" then
            _setHint("⟳  Checking saved key...",Color3.fromRGB(180,160,255))
            _validate(_saved)
        else
            _showInput()
        end
    end)

    while not _keyPassed do task.wait(0.05) end
end

ShowInfo("Key gate passed. Loading hub...")

-- ══════════════════════════════════════════
--  FRAME TICK + VIEWPORT
-- ══════════════════════════════════════════
local _tick=0
local function RainbowHSV(speed,offset)
    return Color3.fromHSV(((_tick*(speed or 1)+(offset or 0))%1),1,1)
end

local VP=Camera.ViewportSize; local VP_CX=VP.X*0.5; local VP_CY=VP.Y*0.5
local VP_BOT=Vector2.new(VP_CX,VP.Y)
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    VP=Camera.ViewportSize; VP_CX=VP.X*0.5; VP_CY=VP.Y*0.5; VP_BOT=Vector2.new(VP_CX,VP.Y)
end)

-- ══════════════════════════════════════════
--  BOOT ANIMATION
-- ══════════════════════════════════════════
local function PlayBoot()
    local vp=Camera.ViewportSize; local cx=vp.X/2; local cy=vp.Y/2
    local function eOut(t) return 1-(1-t)^3 end
    local function eIO(t) return t<0.5 and 4*t^3 or 1-(-2*t+2)^3/2 end
    local bg=NewDraw("Square",{Visible=true,Filled=true,Color=Color3.new(0,0,0),Transparency=0,Position=Vector2.new(0,0),Size=Vector2.new(vp.X,vp.Y)})
    local pW,pH=540,260; local pX=cx-pW/2; local pY=cy-pH/2
    local pBg=NewDraw("Square",{Visible=false,Filled=true,Color=AME.deep,Transparency=0.08,Position=Vector2.new(pX,pY),Size=Vector2.new(pW,pH)})
    local pBd=NewDraw("Square",{Visible=false,Filled=false,Color=AME.mid,Thickness=2,Position=Vector2.new(pX,pY),Size=Vector2.new(pW,pH)})
    local pIn=NewDraw("Square",{Visible=false,Filled=false,Color=AME.dark,Thickness=1,Position=Vector2.new(pX+4,pY+4),Size=Vector2.new(pW-8,pH-8)})
    local title=NewDraw("Text",{Visible=false,Text="TRAV HUB",Size=52,Center=true,Outline=true,OutlineColor=AME.dark,Color=AME.bright,Position=Vector2.new(cx,cy-64),Font=Drawing.Fonts.GothamBold})
    local sub=NewDraw("Text",{Visible=false,Text="Project Delta  ·  Crystal Edition  ·  v3.9",Size=14,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.light,Position=Vector2.new(cx,cy-18),Font=Drawing.Fonts.Gotham})
    local by=NewDraw("Text",{Visible=false,Text="v3.9  ·  by Trav  ·  Clean Build",Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.white,Position=Vector2.new(cx,cy+16),Font=Drawing.Fonts.Gotham})
    local sep=NewDraw("Line",{Visible=false,Color=AME.mid,Thickness=1,From=Vector2.new(cx-190,cy+4),To=Vector2.new(cx+190,cy+4)})
    local barW=320; local barH=5; local barX=cx-barW/2; local barY=pY+pH-42
    local bBg=NewDraw("Square",{Visible=false,Filled=true,Color=AME.dark,Position=Vector2.new(barX,barY),Size=Vector2.new(barW,barH)})
    local bFl=NewDraw("Square",{Visible=false,Filled=true,Color=AME.bright,Position=Vector2.new(barX,barY),Size=Vector2.new(0,barH)})
    local bTx=NewDraw("Text",{Visible=false,Text="",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=AME.glow,Position=Vector2.new(cx,barY+12),Font=Drawing.Fonts.Gotham})
    for i=0,20 do
        local t=eOut(i/20)
        bg.Transparency=1-t*0.93
        pBg.Visible=true;pBd.Visible=true;pIn.Visible=true
        pBg.Transparency=1-t*0.92;pBd.Transparency=1-t;pIn.Transparency=1-t
        task.wait(0.013)
    end
    sep.Visible=true;task.wait(0.06);title.Visible=true;task.wait(0.05)
    sub.Visible=true;task.wait(0.06);by.Visible=true;task.wait(0.10)
    bBg.Visible=true;bFl.Visible=true;bTx.Visible=true
    local msgs={"Initialising Drawing API...","Loading ESP systems...","Calibrating aimbot...","Configuring zoom optics...","Building loot scanner...","Encrypting session...","✦  Ready  ✦"}
    for idx,msg in ipairs(msgs) do
        bTx.Text=msg
        local sp=(idx-1)/#msgs; local ep=idx/#msgs
        for j=0,22 do
            local pct=sp+(ep-sp)*eIO(j/22); bFl.Size=Vector2.new(barW*pct,barH); task.wait(0.011)
        end
        task.wait(0.04)
    end
    bFl.Size=Vector2.new(barW,barH); task.wait(0.45)
    local all={bg,pBg,pBd,pIn,title,sub,by,sep,bBg,bFl,bTx}
    for i=0,24 do
        local f=eOut(i/24)
        for _,o in ipairs(all) do pcall(function() o.Transparency=math.min((o.Transparency or 0)+f*0.12,1) end) end
        task.wait(0.011)
    end
    for _,o in ipairs(all) do pcall(function() o:Remove() end) end
end
Safe(PlayBoot)

-- ══════════════════════════════════════════
--  RAYFIELD LOADER
-- ══════════════════════════════════════════
ShowInfo("Loading Rayfield...")
local Rayfield = nil
local _rfURLs = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/UI-Libraries/Rayfield/main/source.lua",
}
for i,url in ipairs(_rfURLs) do
    ShowInfo("Trying URL "..i)
    local ok,res = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and res then Rayfield=res; ShowInfo("Rayfield loaded from URL "..i); break
    else ShowInfo("URL "..i.." failed: "..tostring(res)) end
end
if not Rayfield then ShowError("Rayfield failed to load. Check internet/executor HTTP."); return end

local Window = Rayfield:CreateWindow({
    Name="TravHub  ✦  Project Delta",
    Icon=0, LoadingTitle="TravHub  v3.9",
    LoadingSubtitle="Crystal Edition  ·  Clean Build",
    Theme="Amethyst",
    DisableRayfieldPrompts=true, DisableBuildWarnings=true,
    ConfigurationSaving={Enabled=true,FolderName="TravHub_Delta",FileName="Config_v39"},
    KeySystem=false,
})

-- ══════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════
local S = {
    -- Player ESP
    ESPEnabled=false, ESPHealthBars=false, ESPTracers=false,
    ESPNames=true, ESPDistance=true, ESPWeapon=true, ESPSkeleton=false,
    ESPMaxDist=500, ESPTextSize=14,
    BoxColor=Color3.fromRGB(220,80,80), ESPRainbow=false, ESPTeamCheck=false,
    ESPFillBox=true, ESPCornerBox=false, ESPBoxEnabled=true,
    -- AI ESP
    AIESPEnabled=false, AIBoxColor=Color3.fromRGB(255,160,30),
    AIESPNames=true, AIESPHealth=true, AIESPTracers=false,
    AIESPMaxDist=400, AIESPRainbow=false,
    -- AI Aimbot
    AIAimbotEnabled=false, AIAimbotMode="Smooth", AIAimbotFOV=150,
    AIAimbotSmooth=0.10, AIAimbotBlatant=0.55, AIAimbotPart="Head",
    AIAimbotLock=false, AIAimbotKey="MouseButton2",
    AIFOVColor=Color3.fromRGB(255,160,30), AIFOVVisible=true,
    -- Loot ESP
    LootESPEnabled=false, LootMaxDist=300, LootTextSize=12,
    LootFilter={Keys=true,Bodies=true,Weapons=true,Ammo=true,Medical=true,
        Valuables=true,Containers=true,Armor=true,Explosives=true,Tools=true,Other=false},
    LootColors={
        Keys=Color3.fromRGB(255,230,50), Bodies=Color3.fromRGB(200,80,80),
        Weapons=Color3.fromRGB(255,100,50), Ammo=Color3.fromRGB(255,200,50),
        Medical=Color3.fromRGB(80,255,120), Valuables=Color3.fromRGB(200,160,255),
        Containers=Color3.fromRGB(100,180,255), Armor=Color3.fromRGB(100,200,255),
        Explosives=Color3.fromRGB(255,80,50), Tools=Color3.fromRGB(200,200,100),
        Other=Color3.fromRGB(180,180,180),
    },
    -- Exfil ESP
    ExfilESPEnabled=false, ExfilColor=Color3.fromRGB(80,255,140),
    ExfilMaxDist=2000, ExfilShowDist=true, ExfilArrow=true,
    ExfilRainbow=false, ExfilPulse=true,
    -- Player Aimbot
    AimbotEnabled=false, AimbotMode="Smooth", AimbotFOV=150,
    AimbotSmooth=0.10, AimbotBlatant=0.55, AimbotPredict=false,
    AimbotPredictStr=0.5, AimbotLock=false, AimbotPart="Head",
    TeamCheck=false, AimKey="MouseButton2",
    FOVColor=Color3.fromRGB(180,100,255), FOVVisible=true,
    TriggerBot=false, TrigDelay=0, SilentAim=false,
    -- Zoom
    ZoomEnabled=false, ZoomKey="Z", ZoomFOV=20, ZoomSmooth=true,
    ZoomSpeed=0.18, ZoomOverlay=true, ZoomOverlayColor=Color3.fromRGB(180,220,255),
    ZoomActive=false, _BaseFOV=70,
    -- Combat
    NoRecoilEnabled=false, RecoilStrength=0.20,
    HitboxExpander=false, HitboxSize=6,
    -- Visuals
    FullbrightEnabled=false, NoFogEnabled=false, CameraFOV=70,
    HitmarkerEnabled=false, ShowFPS=false, ShowPing=false,
    -- Crosshair
    CrosshairEnabled=false, CrosshairStyle="Plus",
    CrosshairColor=Color3.fromRGB(0,255,120),
    CrosshairSize=18, CrosshairGap=5, CrosshairThick=2,
    CrosshairRainbow=false, CrosshairSpin=false, CrosshairSpinSpeed=90,
    CrosshairOpacity=0,
}

-- ══════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════
local function W2S(pos)
    local s,v = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X,s.Y), v
end
local function Notify(t,m,d) Rayfield:Notify({Title=t,Content=m,Duration=d or 3}) end
local function RotVec(cx,cy,ox,oy,angle)
    local c,s=mcos(angle),msin(angle)
    return cx+ox*c-oy*s, cy+ox*s+oy*c
end

-- ══════════════════════════════════════════
--  PLAYER CHARACTER CACHE
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
    p.CharacterAdded:Connect(function(c) PlayerCharCache[c]=true end)
    p.CharacterRemoving:Connect(function(c) PlayerCharCache[c]=nil end)
end)
Players.PlayerRemoving:Connect(function(p) if p.Character then PlayerCharCache[p.Character]=nil end end)
RebuildCharCache()
LocalPlayer.CharacterAdded:Connect(RebuildCharCache)

-- ══════════════════════════════════════════
--  WEAPON CACHE
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
--  SCREEN CRYSTAL BORDERS
-- ══════════════════════════════════════════
local ScreenCrystals={}
local function BuildCrystals()
    local vp=Camera.ViewportSize; local W,H=vp.X,vp.Y
    local defs={
        {Vector2.new(0,0),  Vector2.new(32,0),  Vector2.new(0,32),  AME.mid},
        {Vector2.new(0,0),  Vector2.new(20,0),  Vector2.new(0,50),  AME.bright},
        {Vector2.new(W,0),  Vector2.new(W-32,0),Vector2.new(W,32),  AME.mid},
        {Vector2.new(W,0),  Vector2.new(W-20,0),Vector2.new(W,50),  AME.bright},
        {Vector2.new(0,H),  Vector2.new(32,H),  Vector2.new(0,H-32),AME.mid},
        {Vector2.new(0,H),  Vector2.new(20,H),  Vector2.new(0,H-50),AME.bright},
        {Vector2.new(W,H),  Vector2.new(W-32,H),Vector2.new(W,H-32),AME.mid},
        {Vector2.new(W,H),  Vector2.new(W-20,H),Vector2.new(W,H-50),AME.bright},
    }
    for _,d in ipairs(defs) do
        local l1=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[1],To=d[2]})
        local l2=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[2],To=d[3]})
        local l3=NewDraw("Line",{Visible=true,Color=d[4],Thickness=1.5,Transparency=0.25,From=d[3],To=d[1]})
        tinsert(ScreenCrystals,{l1,l2,l3})
    end
end
Safe(BuildCrystals)

-- ══════════════════════════════════════════
--  FOV CIRCLES + LOCK DOTS
-- ══════════════════════════════════════════
local FOVCircle    = NewDraw("Circle",{Visible=false,Thickness=1.5,Color=S.FOVColor,Filled=false,NumSides=64})
local LockDot      = NewDraw("Circle",{Visible=false,Filled=true,Color=Color3.fromRGB(255,60,60),Radius=4,NumSides=16,Thickness=0})
local AIFOVCircle  = NewDraw("Circle",{Visible=false,Thickness=1.5,Color=Color3.fromRGB(255,160,30),Filled=false,NumSides=64})
local AILockDot    = NewDraw("Circle",{Visible=false,Filled=true,Color=Color3.fromRGB(255,160,30),Radius=4,NumSides=16,Thickness=0})

-- ══════════════════════════════════════════
--  CROSSHAIR DRAWINGS

-- ══════════════════════════════════════════
--  CROSSHAIR DRAWINGS
--  Shared pool — hide all each frame, draw only active style.
--  Wrapped in pcall so a Drawing API hiccup never silently kills it.
-- ══════════════════════════════════════════
local _CHPool = {
    lines  = {},
    shadow = {},   -- dark outlines drawn behind each line for contrast
    circles= {},
}
for i=1,12 do
    _CHPool.shadow[i] = NewDraw("Line",  {Visible=false,Thickness=4,  Color=Color3.new(0,0,0)})
    _CHPool.lines[i]  = NewDraw("Line",  {Visible=false,Thickness=2,  Color=Color3.new(0,1,0.47)})
end
for i=1,4  do _CHPool.circles[i]= NewDraw("Circle",{Visible=false,Filled=true,Radius=3,NumSides=16,Thickness=0,Color=Color3.new(0,1,0.47)}) end
-- one ring for Circle/Sniper styles
local _CHRing       = NewDraw("Circle",{Visible=false,Thickness=1.5,Filled=false,NumSides=64,Radius=10,Color=Color3.new(0,1,0.47)})
local _CHRingShadow = NewDraw("Circle",{Visible=false,Thickness=4,  Filled=false,NumSides=64,Radius=10,Color=Color3.new(0,0,0)})

local function _HideCH()
    for _,l in ipairs(_CHPool.lines)   do l.Visible=false end
    for _,l in ipairs(_CHPool.shadow)  do l.Visible=false end
    for _,c in ipairs(_CHPool.circles) do c.Visible=false end
    _CHRing.Visible=false
    _CHRingShadow.Visible=false
end

local _prevCHStyle=""
local _chAngle=0
local _chFirstDraw=true

local function UpdateCrosshair(dt)
    if not S.CrosshairEnabled then
        if _prevCHStyle~="" then _HideCH(); _prevCHStyle="" end
        return
    end

    local ok,err=pcall(function()
        local style=S.CrosshairStyle
        if style~=_prevCHStyle then _HideCH(); _prevCHStyle=style; _chAngle=0 end
        if S.CrosshairSpin then _chAngle=(_chAngle+mrad(S.CrosshairSpinSpeed)*dt)%(pi*2) end

        local cx  = VP_CX
        local cy  = VP_CY
        local col = S.CrosshairRainbow and RainbowHSV(0.6) or S.CrosshairColor
        local th  = mmax(S.CrosshairThick,1)
        local op  = mclamp(S.CrosshairOpacity,0,1)
        local gap = S.CrosshairGap
        local sz  = S.CrosshairSize
        local ca  = mcos(_chAngle)
        local sa  = msin(_chAngle)
        local L   = _CHPool.lines
        local C   = _CHPool.circles

        -- Rotate an offset around centre
        local function R(ox,oy)
            return Vector2.new(cx+ox*ca-oy*sa, cy+ox*sa+oy*ca)
        end
        local _lineIdx=0
        local function SetLine(x1,y1,x2,y2)
            _lineIdx=_lineIdx+1
            local d  = L[_lineIdx]
            local sh = _CHPool.shadow[_lineIdx]
            if sh then
                sh.From=R(x1,y1);sh.To=R(x2,y2)
                sh.Thickness=th+2;sh.Transparency=mclamp(op+0.1,0,1);sh.Visible=true
            end
            d.From=R(x1,y1); d.To=R(x2,y2)
            d.Color=col; d.Thickness=th; d.Transparency=op; d.Visible=true
        end
        local function SetDot(d,ox,oy,r)
            d.Position=R(ox,oy); d.Color=col
            d.Filled=true; d.Radius=r or mmax(th,2); d.Transparency=op; d.Visible=true
        end

        _HideCH()  -- clear every frame so style changes are clean

        if style=="Plus" then
            SetLine( 0,-gap,   0,-(gap+sz))
            SetLine( 0, gap,   0,  gap+sz)
            SetLine(-gap,0, -(gap+sz),0)
            SetLine( gap,0,   gap+sz, 0)
            SetDot(C[1],0,0)

        elseif style=="X" then
            local a45=_chAngle+pi/4; local c2=mcos(a45); local s2=msin(a45)
            local function SL45(x1,y1,x2,y2)
                _lineIdx=_lineIdx+1
                local d=L[_lineIdx]; local sh=_CHPool.shadow[_lineIdx]
                if sh then sh.From=Vector2.new(cx+x1*c2-y1*s2,cy+x1*s2+y1*c2);sh.To=Vector2.new(cx+x2*c2-y2*s2,cy+x2*s2+y2*c2);sh.Thickness=th+2;sh.Transparency=mclamp(op+0.1,0,1);sh.Visible=true end
                d.From=Vector2.new(cx+x1*c2-y1*s2,cy+x1*s2+y1*c2);d.To=Vector2.new(cx+x2*c2-y2*s2,cy+x2*s2+y2*c2);d.Color=col;d.Thickness=th;d.Transparency=op;d.Visible=true
            end
            SL45( 0,-gap,  0,-(gap+sz)); SL45( 0, gap,  0,  gap+sz)
            SL45(-gap,0,-(gap+sz),0);    SL45( gap,0,  gap+sz, 0)
            SetDot(C[1],0,0)

        elseif style=="Dot" then
            SetDot(C[1],0,0,mclamp(sz*0.45,3,14))

        elseif style=="Circle" then
            _CHRingShadow.Position=Vector2.new(cx,cy); _CHRingShadow.Radius=mmax(gap+sz*0.5,4)
            _CHRingShadow.Thickness=th+2; _CHRingShadow.Transparency=mclamp(op+0.1,0,1); _CHRingShadow.Visible=true
            _CHRing.Position=Vector2.new(cx,cy); _CHRing.Color=col
            _CHRing.Radius=mmax(gap+sz*0.5,4); _CHRing.Thickness=th; _CHRing.Transparency=op; _CHRing.Visible=true
            SetDot(C[1],0,0)

        elseif style=="T-Shape" then
            SetLine( 0,-gap,  0,-(gap+sz))
            SetLine(-gap,0,-(gap+sz),0)
            SetLine( gap,0,  gap+sz, 0)
            SetDot(C[1],0,0)

        elseif style=="KovaaK" then
            SetLine( 0,-gap,  0,-(gap+sz)); SetLine( 0, gap,  0,  gap+sz)
            SetLine(-gap,0,-(gap+sz),0);    SetLine( gap,0,  gap+sz, 0)
            local tOff=gap+sz+4; local tLen=5
            SetLine( 0,-(tOff),  0,-(tOff+tLen)); SetLine( 0,  tOff,   0,  tOff+tLen)
            SetLine(-(tOff),0,-(tOff+tLen),0);    SetLine(  tOff, 0,  tOff+tLen, 0)
            SetDot(C[1],0,0)

        elseif style=="Sniper" then
            local vpX,vpY=VP.X,VP.Y; local snOp=mclamp(op+0.28,0,1)
            local pts={{0,cy,cx-gap,cy},{cx+gap,cy,vpX,cy},{cx,0,cx,cy-gap},{cx,cy+gap,cx,vpY}}
            for i,p in ipairs(pts) do
                local sh=_CHPool.shadow[i]
                if sh then sh.From=Vector2.new(p[1],p[2]);sh.To=Vector2.new(p[3],p[4]);sh.Thickness=3;sh.Transparency=mclamp(snOp+0.1,0,1);sh.Visible=true end
                L[i].From=Vector2.new(p[1],p[2]);L[i].To=Vector2.new(p[3],p[4]);L[i].Color=col;L[i].Thickness=1;L[i].Transparency=snOp;L[i].Visible=true
            end
            _CHRingShadow.Position=Vector2.new(cx,cy);_CHRingShadow.Radius=mmax(gap,6);_CHRingShadow.Thickness=3;_CHRingShadow.Transparency=mclamp(op+0.1,0,1);_CHRingShadow.Visible=true
            _CHRing.Position=Vector2.new(cx,cy);_CHRing.Color=col;_CHRing.Radius=mmax(gap,6);_CHRing.Thickness=1;_CHRing.Transparency=op;_CHRing.Visible=true
            C[1].Position=Vector2.new(cx,cy);C[1].Radius=2;C[1].Color=col;C[1].Transparency=op;C[1].Visible=true

        elseif style=="Diamond" then
            local r=sz+gap
            local ptT=R(0,-r);local ptR=R(r,0);local ptB=R(0,r);local ptL=R(-r,0)
            local dm={{ptT,ptR},{ptR,ptB},{ptB,ptL},{ptL,ptT}}
            for i,p in ipairs(dm) do
                local sh=_CHPool.shadow[i]
                if sh then sh.From=p[1];sh.To=p[2];sh.Thickness=th+2;sh.Transparency=mclamp(op+0.1,0,1);sh.Visible=true end
                L[i].From=p[1];L[i].To=p[2];L[i].Color=col;L[i].Thickness=th;L[i].Transparency=op;L[i].Visible=true
            end
            SetDot(C[1],0,0)

        elseif style=="Bracket" then
            local a2=mmax(mfloor(sz*0.45),4)
            local bx1=cx-gap-sz;local bx2=cx+gap+sz;local by1=cy-gap-sz;local by2=cy+gap+sz
            SetLine(bx1-cx,by1-cy, bx1+a2-cx,by1-cy); SetLine(bx1-cx,by1-cy, bx1-cx,by1+a2-cy)
            SetLine(bx2-cx,by1-cy, bx2-a2-cx,by1-cy); SetLine(bx2-cx,by1-cy, bx2-cx,by1+a2-cy)
            SetLine(bx1-cx,by2-cy, bx1+a2-cx,by2-cy); SetLine(bx1-cx,by2-cy, bx1-cx,by2-a2-cy)
            SetLine(bx2-cx,by2-cy, bx2-a2-cx,by2-cy); SetLine(bx2-cx,by2-cy, bx2-cx,by2-a2-cy)
            SetDot(C[1],0,0)

        elseif style=="Happy Face" then
            local fR=sz+gap
            C[1].Position=Vector2.new(cx-fR*0.35,cy-fR*0.3);C[1].Radius=mmax(th,2);C[1].Color=col;C[1].Transparency=op;C[1].Visible=true
            C[2].Position=Vector2.new(cx+fR*0.35,cy-fR*0.3);C[2].Radius=mmax(th,2);C[2].Color=col;C[2].Transparency=op;C[2].Visible=true
            local smR=fR*0.52; local smCY=cy+fR*0.12; local pts={}
            for i=0,6 do local ang=mrad(20)+mrad(140)/6*i; pts[i+1]=Vector2.new(cx+mcos(ang)*smR,smCY+msin(ang)*smR) end
            for i=1,6 do
                local sh=_CHPool.shadow[i]
                if sh then sh.From=pts[i];sh.To=pts[i+1];sh.Thickness=th+2;sh.Transparency=mclamp(op+0.1,0,1);sh.Visible=true end
                L[i].From=pts[i];L[i].To=pts[i+1];L[i].Color=col;L[i].Thickness=th;L[i].Transparency=op;L[i].Visible=true
            end
        end

                -- First draw confirmation
        if _chFirstDraw then
            _chFirstDraw=false
            ShowInfo("Crosshair drawing OK — style: "..style)
        end
    end)

    if not ok then
        warn("[TravHub Crosshair Error] "..tostring(err))
        _HideCH()
    end
end

local function HideAllCrosshair() _HideCH() end  -- kept for toggle callback compatibility

-- ══════════════════════════════════════════
--  HITMARKER
-- ══════════════════════════════════════════
local HM = {
    tl=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    tr=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    bl=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
    br=NewDraw("Line",{Visible=false,Thickness=2.5,Color=Color3.fromRGB(255,220,0)}),
}
local hmActive,hmTimer = false,0
local function TriggerHitmarker() if S.HitmarkerEnabled then hmActive=true; hmTimer=0.28 end end
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
    if not S.HitmarkerEnabled or not hmActive then
        HM.tl.Visible=false;HM.tr.Visible=false;HM.bl.Visible=false;HM.br.Visible=false; return
    end
    hmTimer=hmTimer-dt
    if hmTimer<=0 then hmActive=false; HM.tl.Visible=false;HM.tr.Visible=false;HM.bl.Visible=false;HM.br.Visible=false; return end
    local cx=VP_CX; local cy=VP_CY; local s=9
    local tr=1-mclamp(hmTimer/0.28,0,1)
    HM.tl.Transparency=tr; HM.tr.Transparency=tr; HM.bl.Transparency=tr; HM.br.Transparency=tr
    HM.tl.From=Vector2.new(cx-2,cy-2); HM.tl.To=Vector2.new(cx-2-s,cy-2-s); HM.tl.Visible=true
    HM.tr.From=Vector2.new(cx+2,cy-2); HM.tr.To=Vector2.new(cx+2+s,cy-2-s); HM.tr.Visible=true
    HM.bl.From=Vector2.new(cx-2,cy+2); HM.bl.To=Vector2.new(cx-2-s,cy+2+s); HM.bl.Visible=true
    HM.br.From=Vector2.new(cx+2,cy+2); HM.br.To=Vector2.new(cx+2+s,cy+2+s); HM.br.Visible=true
end

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
local function ShowZoomOverlay(v) for _,k in ipairs(ZO_KEYS) do ZO[k].Visible=v end end

-- ══════════════════════════════════════════
--  FPS / PING
-- ══════════════════════════════════════════
local FPSLabel  = NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,255,160),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,8)})
local PingLabel = NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,200,255),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,24)})
local fpsFrames,fpsElapsed,fpsVal,pingVal = 0,0,0,0

-- ══════════════════════════════════════════
--  PLAYER ESP
-- ══════════════════════════════════════════
local ESPObjects = {}
local SKEL_PAIRS={
    {"Head","UpperTorso"},{"Head","Torso"},{"UpperTorso","LowerTorso"},{"Torso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local SKEL_N = #SKEL_PAIRS

local function MakeESP(player)
    if ESPObjects[player] then return end
    local sk={}; for i=1,SKEL_N do sk[i]=NewDraw("Line",{Visible=false,Color=Color3.new(1,1,1),Thickness=1}) end
    ESPObjects[player]={
        boxOut=NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=4}),
        box   =NewDraw("Square",{Visible=false,Filled=false,Color=S.BoxColor,Thickness=1.5}),
        fill  =NewDraw("Square",{Visible=false,Filled=true,Color=S.BoxColor,Transparency=0.88}),
        c1=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c2=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c3=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c4=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c5=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c6=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c7=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c8=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        name  =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.new(1,1,1),OutlineColor=Color3.new(0,0,0),Size=14}),
        dist  =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,180,180),OutlineColor=Color3.new(0,0,0),Size=11}),
        weapon=NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(255,200,100),OutlineColor=Color3.new(0,0,0),Size=10}),
        hpBg  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(0,220,0)}),
        tracer=NewDraw("Line",{Visible=false,Color=S.BoxColor,Thickness=1}),
        skeleton=sk, _lastDist=-1,
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
    o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
    o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
    o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
    o.name.Visible=false;o.dist.Visible=false;o.weapon.Visible=false
    o.hpBg.Visible=false;o.hpBar.Visible=false;o.tracer.Visible=false
    local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end
end

local function DrawCornerBox(o,bx,by,bw,bh,col)
    o.box.Visible=false;o.fill.Visible=false;o.boxOut.Visible=false
    local cLen=mmax(mfloor(bw*0.25),5)
    o.c1.From=Vector2.new(bx,by);       o.c1.To=Vector2.new(bx+cLen,by);      o.c1.Color=col; o.c1.Visible=true
    o.c2.From=Vector2.new(bx,by);       o.c2.To=Vector2.new(bx,by+cLen);      o.c2.Color=col; o.c2.Visible=true
    o.c3.From=Vector2.new(bx+bw,by);    o.c3.To=Vector2.new(bx+bw-cLen,by);   o.c3.Color=col; o.c3.Visible=true
    o.c4.From=Vector2.new(bx+bw,by);    o.c4.To=Vector2.new(bx+bw,by+cLen);   o.c4.Color=col; o.c4.Visible=true
    o.c5.From=Vector2.new(bx,by+bh);    o.c5.To=Vector2.new(bx+cLen,by+bh);   o.c5.Color=col; o.c5.Visible=true
    o.c6.From=Vector2.new(bx,by+bh);    o.c6.To=Vector2.new(bx,by+bh-cLen);   o.c6.Color=col; o.c6.Visible=true
    o.c7.From=Vector2.new(bx+bw,by+bh); o.c7.To=Vector2.new(bx+bw-cLen,by+bh);o.c7.Color=col; o.c7.Visible=true
    o.c8.From=Vector2.new(bx+bw,by+bh); o.c8.To=Vector2.new(bx+bw,by+bh-cLen);o.c8.Color=col; o.c8.Visible=true
end

local function UpdatePlayerESP(myRoot,rcol)
    local bottom=VP_BOT
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LocalPlayer then continue end
        if not ESPObjects[player] then MakeESP(player) end
        local o=ESPObjects[player]
        if not S.ESPEnabled then HideESP(o); continue end
        local char=player.Character
        if not char or (S.ESPTeamCheck and player.Team==LocalPlayer.Team) then HideESP(o); continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then HideESP(o); continue end
        local root=char:FindFirstChild("HumanoidRootPart")
        local head=char:FindFirstChild("Head")
        if not root or not head then HideESP(o); continue end
        local myPos=myRoot and myRoot.Position
        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X; local dy=myPos.Y-root.Position.Y; local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.ESPMaxDist then HideESP(o); continue end
        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideESP(o); continue end
        local headTopY=head.Position.Y+(head.Size.Y*0.5)+0.1
        local hPos=W2S(Vector3.new(head.Position.X,headTopY,head.Position.Z))
        local bh=mmax(rPos.Y-hPos.Y,14); local bw=mmax(bh*0.50,10)
        local bx=rPos.X-bw*0.5; local by=hPos.Y
        local col=rcol or S.BoxColor
        if S.ESPBoxEnabled then
            if S.ESPCornerBox then
                DrawCornerBox(o,bx,by,bw,bh,col)
            else
                o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
                o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
                o.boxOut.Size=Vector2.new(bw+2,bh+2);o.boxOut.Position=Vector2.new(bx-1,by-1);o.boxOut.Visible=true
                o.box.Color=col;o.box.Size=Vector2.new(bw,bh);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
                if S.ESPFillBox then
                    o.fill.Color=col;o.fill.Size=Vector2.new(bw,bh);o.fill.Position=Vector2.new(bx,by);o.fill.Visible=true
                else o.fill.Visible=false end
            end
        else
            o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
            o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
            o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
        end
        if S.ESPNames then
            local nm=player.DisplayName~=player.Name and (player.DisplayName.." ("..player.Name..")") or player.Name
            o.name.Text=nm;o.name.Size=S.ESPTextSize
            o.name.Position=Vector2.new(rPos.X,by-S.ESPTextSize-3);o.name.Visible=true
        else o.name.Visible=false end
        if S.ESPDistance then
            if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
            o.dist.Position=Vector2.new(rPos.X,rPos.Y+3);o.dist.Visible=true
        else o.dist.Visible=false end
        if S.ESPWeapon then
            local wpn=WeaponCache[player] or ""
            if wpn~="" then o.weapon.Text="["..wpn.."]";o.weapon.Position=Vector2.new(rPos.X,rPos.Y+15);o.weapon.Visible=true
            else o.weapon.Visible=false end
        else o.weapon.Visible=false end
        if S.ESPHealthBars then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2);o.hpBg.Position=Vector2.new(bx-8,by-1);o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*220),0)
            o.hpBar.Size=Vector2.new(5,bh*pct);o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct));o.hpBar.Visible=true
        else o.hpBg.Visible=false;o.hpBar.Visible=false end
        if S.ESPTracers then
            o.tracer.Color=col;o.tracer.From=bottom;o.tracer.To=rPos;o.tracer.Visible=true
        else o.tracer.Visible=false end
        if S.ESPSkeleton then
            for i,pair in ipairs(SKEL_PAIRS) do
                local line=o.skeleton[i]
                local pA=char:FindFirstChild(pair[1]);local pB=char:FindFirstChild(pair[2])
                if pA and pB then
                    local sA,oA=W2S(pA.Position);local sB,oB=W2S(pB.Position)
                    if oA and oB then line.From=sA;line.To=sB;line.Color=col;line.Visible=true
                    else line.Visible=false end
                else line.Visible=false end
            end
        else local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end end
    end
end

-- ══════════════════════════════════════════
--  AI ESP
-- ══════════════════════════════════════════
local AIESPObjects={}
local aiCandidates={}
local _aiWasEnabled=false

local function _AIAdd(m)
    if aiCandidates[m] then return end
    if not m:IsA("Model") then return end
    if IsPlayerChar(m) or m==LocalPlayer.Character then return end
    local h=m:FindFirstChildOfClass("Humanoid"); local root=m:FindFirstChild("HumanoidRootPart")
    if h and root then aiCandidates[m]={model=m,hum=h,root=root,head=m:FindFirstChild("Head")} end
end
local function _AIRemove(m) aiCandidates[m]=nil end
local function _AIBootstrap() for _,m in ipairs(Workspace:GetDescendants()) do _AIAdd(m) end end

local function GetOrMakeAIESP(m)
    if AIESPObjects[m] then return AIESPObjects[m] end
    local o={
        boxOut=NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=3}),
        box   =NewDraw("Square",{Visible=false,Filled=false,Color=S.AIBoxColor,Thickness=1.5}),
        fill  =NewDraw("Square",{Visible=false,Filled=true,Color=S.AIBoxColor,Transparency=0.88}),
        name  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.AIBoxColor,OutlineColor=Color3.new(0,0,0),Size=13}),
        dist  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(200,180,140),OutlineColor=Color3.new(0,0,0),Size=11}),
        hpBg  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(255,140,0)}),
        tracer=NewDraw("Line",  {Visible=false,Color=S.AIBoxColor,Thickness=1}),
        _lastDist=-1,
    }
    AIESPObjects[m]=o; return o
end

local function HideAI(o)
    o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
    o.name.Visible=false;o.dist.Visible=false;o.hpBg.Visible=false;o.hpBar.Visible=false;o.tracer.Visible=false
end
local function KillAIESP(m)
    local o=AIESPObjects[m]; if not o then return end
    for _,k in ipairs({"boxOut","box","fill","name","dist","hpBg","hpBar","tracer"}) do pcall(function()o[k]:Remove()end) end
    AIESPObjects[m]=nil
end

local aiLockedTarget=nil; local lastAITargetPos={}; local _prevAILockedTarget=nil

local AimKeyMap={
    MouseButton2=function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end,
    C=function() return UserInputService:IsKeyDown(Enum.KeyCode.C) end,
    Q=function() return UserInputService:IsKeyDown(Enum.KeyCode.Q) end,
    E=function() return UserInputService:IsKeyDown(Enum.KeyCode.E) end,
    F=function() return UserInputService:IsKeyDown(Enum.KeyCode.F) end,
}
local function IsAimKeyDown(key) local fn=AimKeyMap[key or S.AimKey]; return fn and fn() or false end

local function GetBestAITarget()
    local cx=VP_CX; local cy=VP_CY
    local acquireFOV=S.AIAimbotFOV
    local keepFOV=acquireFOV*3.0

    if S.AIAimbotLock and aiLockedTarget then
        local m=aiLockedTarget; local entry=aiCandidates[m]
        local valid=false
        if entry and m.Parent and entry.hum.Health>0 then
            local part=m:FindFirstChild(S.AIAimbotPart) or entry.root
            if part then
                local sp,on=W2S(part.Position)
                if on then
                    local dx=sp.X-cx; local dy=sp.Y-cy
                    if (dx*dx+dy*dy)^0.5<keepFOV then valid=true end
                end
            end
        end
        if valid then return aiLockedTarget end
        lastAITargetPos[aiLockedTarget]=nil
        aiLockedTarget=nil
    end

    local best,bd=nil,mhuge
    for m,entry in pairs(aiCandidates) do
        if not m.Parent or entry.hum.Health<=0 then continue end
        local part=m:FindFirstChild(S.AIAimbotPart) or entry.root
        if part then
            local sp,on=W2S(part.Position)
            if on then
                local dx=sp.X-cx; local dy=sp.Y-cy; local d=(dx*dx+dy*dy)^0.5
                if d<acquireFOV and d<bd then bd=d; best=m end
            end
        end
    end
    if best then
        if best~=_prevAILockedTarget then lastAITargetPos[best]=nil; _prevAILockedTarget=best end
        if S.AIAimbotLock then aiLockedTarget=best end
    end
    return best
end

local function RunAIAimbot(camCF,dt)
    AIFOVCircle.Position=Vector2.new(VP_CX,VP_CY); AIFOVCircle.Radius=S.AIAimbotFOV
    AIFOVCircle.Color=S.AIFOVColor; AIFOVCircle.Visible=S.AIAimbotEnabled and S.AIFOVVisible
    if not S.AIAimbotEnabled then AILockDot.Visible=false; return end
    local target=GetBestAITarget()
    if target then
        local entry=aiCandidates[target]
        if entry then
            local part=target:FindFirstChild(S.AIAimbotPart) or entry.root
            if part then local sp,on=W2S(part.Position); AILockDot.Position=sp; AILockDot.Visible=on end
        end
    else AILockDot.Visible=false end
    if not IsAimKeyDown(S.AIAimbotKey) or not target then return end
    local entry=aiCandidates[target]; if not entry then return end
    local part=target:FindFirstChild(S.AIAimbotPart) or entry.root; if not part then return end
    local pos=part.Position
    local prev=lastAITargetPos[target]; lastAITargetPos[target]=pos
    if prev then pos=pos+(pos-prev)*2 end  -- simple 2-frame prediction for AI
    local targetCF=CFrame.new(camCF.Position,pos)
    local safeDt=mclamp(dt,0.001,0.05)
    if S.AIAimbotMode=="Instant" then
        pcall(function() Camera.CFrame=targetCF end)
    elseif S.AIAimbotMode=="Blatant" then
        local alpha=mclamp(1-(1-S.AIAimbotBlatant)^(safeDt*60),0.01,0.99)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    else
        local sp2d=W2S(pos); local dx2=sp2d.X-VP_CX; local dy2=sp2d.Y-VP_CY
        local distBoost=mclamp((dx2*dx2+dy2*dy2)^0.5/mmax(S.AIAimbotFOV,1),0,1)*S.AIAimbotSmooth*0.8
        local alpha=mclamp(1-(1-(S.AIAimbotSmooth+distBoost))^(safeDt*60),0.005,0.95)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    end
end

local function UpdateAIESP(myRoot)
    if not S.AIESPEnabled then
        if _aiWasEnabled then for m in pairs(AIESPObjects) do KillAIESP(m) end; _aiWasEnabled=false end
        return
    end
    _aiWasEnabled=true
    local bottom=VP_BOT
    local rcol=S.AIESPRainbow and RainbowHSV(0.4,0.33) or nil
    local myPos=myRoot and myRoot.Position
    for m,entry in pairs(aiCandidates) do
        if not m.Parent then aiCandidates[m]=nil; KillAIESP(m); continue end
        local hum=entry.hum; local root=entry.root; local head=entry.head
        local o=GetOrMakeAIESP(m)
        if not root or hum.Health<=0 then HideAI(o); continue end
        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X; local dy=myPos.Y-root.Position.Y; local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.AIESPMaxDist then HideAI(o); continue end
        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideAI(o); continue end
        local hTopY=head and (head.Position.Y+(head.Size and head.Size.Y*0.5 or 0.5)+0.1) or root.Position.Y+3
        local hPos=W2S(Vector3.new(root.Position.X,hTopY,root.Position.Z))
        local bh=mmax(rPos.Y-hPos.Y,14); local bw=mmax(bh*0.50,10)
        local bx=rPos.X-bw*0.5; local by=hPos.Y
        local col=rcol or S.AIBoxColor
        o.boxOut.Size=Vector2.new(bw+2,bh+2);o.boxOut.Position=Vector2.new(bx-1,by-1);o.boxOut.Visible=true
        o.box.Color=col;o.box.Size=Vector2.new(bw,bh);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
        o.fill.Color=col;o.fill.Size=Vector2.new(bw,bh);o.fill.Position=Vector2.new(bx,by);o.fill.Visible=true
        if S.AIESPNames then o.name.Text=m.Name;o.name.Position=Vector2.new(rPos.X,by-15);o.name.Color=col;o.name.Visible=true
        else o.name.Visible=false end
        if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(rPos.X,rPos.Y+3);o.dist.Visible=true
        if S.AIESPHealth then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2);o.hpBg.Position=Vector2.new(bx-8,by-1);o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*180),0)
            o.hpBar.Size=Vector2.new(5,bh*pct);o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct));o.hpBar.Visible=true
        else o.hpBg.Visible=false;o.hpBar.Visible=false end
        if S.AIESPTracers then o.tracer.Color=col;o.tracer.From=bottom;o.tracer.To=rPos;o.tracer.Visible=true
        else o.tracer.Visible=false end
    end
    for m in pairs(AIESPObjects) do if not aiCandidates[m] then KillAIESP(m) end end
end

-- ══════════════════════════════════════════
--  LOOT ESP
-- ══════════════════════════════════════════
local LOOT_BLACKLIST={
    Head=true,Face=true,Torso=true,HumanoidRootPart=true,
    UpperTorso=true,LowerTorso=true,
    ["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
    LeftUpperArm=true,RightUpperArm=true,LeftLowerArm=true,RightLowerArm=true,
    LeftHand=true,RightHand=true,LeftUpperLeg=true,RightUpperLeg=true,
    LeftLowerLeg=true,RightLowerLeg=true,LeftFoot=true,RightFoot=true,
    Baseplate=true,Terrain=true,SpawnLocation=true,Sky=true,Sun=true,
    Part=true,UnionOperation=true,Decal=true,Texture=true,SpecialMesh=true,
    -- Project Delta hitbox parts
    HeadTopHitBox=true,FaceHitBox=true,HeadHitBox=true,BodyHitBox=true,
    TorsoHitBox=true,ChestHitBox=true,ArmHitBox=true,LegHitBox=true,
    HandHitBox=true,FootHitBox=true,UpperTorsoHitBox=true,LowerTorsoHitBox=true,
    LeftArmHitBox=true,RightArmHitBox=true,LeftLegHitBox=true,RightLegHitBox=true,
    NeckHitBox=true,BackHitBox=true,SpineHitBox=true,
}
local LOOT_BAD_KWS={"hitbox","hit_box","hitzone","hit_zone","damagebox","damage_box","hurtbox","hurt_box","collision","nametag","billboard","highlight","selection","attachment"}
local function _IsBadName(n)
    local l=n:lower()
    for _,kw in ipairs(LOOT_BAD_KWS) do if l:find(kw,1,true) then return true end end
    return false
end

local LOOT_CATS={
    Keys={"keycard","key card","access card","id card","passcard","badge","fob","room key","master key","storage key","cabinet key","cell key","red keycard","blue keycard","green keycard","yellow keycard","black keycard","vip key"},
    Bodies={"body","corpse","dead","ragdoll","remains","victim","fallen","skeleton","bones","player body","dead body","loot body"},
    Weapons={"gun","pistol","revolver","rifle","carbine","assault","shotgun","pump","smg","submachine","sniper","dmr","marksman","bolt","lmg","machine gun","knife","combat knife","sword","axe","hatchet","weapon","firearm","blade","crossbow","ak","m4","ar15","glock"},
    Ammo={"ammo","ammunition","bullet","bullets","magazine","mag","round","rounds","shell","shells","clip","cartridge","9mm","556","762","308","12 gauge","buckshot"},
    Medical={"medkit","med kit","first aid","bandage","gauze","tourniquet","health","heal","syringe","injector","epi","adrenaline","pill","pills","painkiller","morphine","stim","stimulant","blood bag","splint","drug","medication","antidote","food","water","drink","ration"},
    Valuables={"gold","silver","platinum","gem","gemstone","diamond","ruby","emerald","jewel","jewelry","valuable","rare","artifact","relic","cash","money","wallet","currency","coin","token","credit","loot","treasure","bounty","intel","document","usb"},
    Containers={"chest","crate","supply crate","loot crate","box","case","briefcase","bag","duffel","backpack","rucksack","stash","cache","container","locker","footlocker","safe","vault","strongbox"},
    Armor={"helmet","ballistic helmet","tactical helmet","vest","plate carrier","body armor","armor","armour","plates","chest rig","gas mask","respirator","shield"},
    Explosives={"grenade","frag","flashbang","smoke","incendiary","molotov","explosive","bomb","ied","mine","claymore","landmine","c4","rpg","rocket"},
    Tools={"toolkit","tool kit","tools","repair kit","screwdriver","lockpick","pick","crowbar","rope","radio","walkie","flashlight","torch","compass","map","gps","tracker","battery","batteries","fuel","parachute"},
    Other={},
}
local LOOT_ICONS={Keys="🔑",Bodies="💀",Weapons="🔫",Ammo="🔹",Medical="💊",Valuables="💎",Containers="📦",Armor="🛡",Explosives="💣",Tools="🔧",Other="·"}
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

local LootESPObjects={}
local lootCandidates={}
local function _LootCheck(inst)
    if not inst:IsA("BasePart") and not inst:IsA("Model") then return end
    if IsPlayerChar(inst) then return end
    local n=inst.Name
    if n=="" or LOOT_BLACKLIST[n] or _IsBadName(n) then return end
    local anc=inst.Parent
    while anc and anc~=Workspace do
        if IsPlayerChar(anc) then return end
        if anc==LocalPlayer.Character then return end
        for _,p in ipairs(Players:GetPlayers()) do if anc==p.Character then return end end
        anc=anc.Parent
    end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart"); if p then pos=p.Position end end
    if not pos then return end
    local cat=ClassifyItem(n)
    if cat=="Other" and #n<4 then return end
    lootCandidates[inst]={inst=inst,cat=cat}
end
local function _LootRemove(inst)
    if lootCandidates[inst] then lootCandidates[inst]=nil end
    if LootESPObjects[inst] then
        local o=LootESPObjects[inst]
        pcall(function()o.dot:Remove()end);pcall(function()o.label:Remove()end);pcall(function()o.dist:Remove()end)
        LootESPObjects[inst]=nil
    end
end
local function _LootBootstrap()
    for _,child in ipairs(Workspace:GetChildren()) do
        _LootCheck(child)
        if child:IsA("Folder") or child:IsA("Model") then
            for _,sub in ipairs(child:GetChildren()) do _LootCheck(sub) end
        end
    end
end

local function MakeLootESP(inst,cat)
    if LootESPObjects[inst] then return LootESPObjects[inst] end
    local col=S.LootColors[cat] or Color3.fromRGB(180,180,180)
    local o={cat=cat,
        dot  =NewDraw("Circle",{Visible=false,Filled=true,Color=col,Radius=3,NumSides=8,Thickness=0}),
        label=NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=col,OutlineColor=Color3.new(0,0,0),Size=S.LootTextSize}),
        dist =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(160,160,160),OutlineColor=Color3.new(0,0,0),Size=10}),
        _lastDist=-1,_lastName="",
    }
    LootESPObjects[inst]=o; return o
end

local _lootWasEnabled=false
local function UpdateLootESP(myRoot)
    if not S.LootESPEnabled then
        if _lootWasEnabled then
            for item in pairs(LootESPObjects) do _LootRemove(item) end
            _lootWasEnabled=false
        end; return
    end
    _lootWasEnabled=true
    local myPos=myRoot and myRoot.Position
    for inst,entry in pairs(lootCandidates) do
        if not inst.Parent then _LootRemove(inst); continue end
        local cat=entry.cat
        if not S.LootFilter[cat] then if LootESPObjects[inst] then _LootRemove(inst) end; continue end
        local pos
        if inst:IsA("BasePart") then pos=inst.Position
        elseif inst:IsA("Model") then local p=inst.PrimaryPart; if p then pos=p.Position end end
        if not pos then continue end
        local o=MakeLootESP(inst,cat)
        local col=S.LootColors[cat] or Color3.fromRGB(180,180,180)
        o.label.Color=col; o.dot.Color=col
        local dist=0
        if myPos then
            local dx=myPos.X-pos.X; local dy=myPos.Y-pos.Y; local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.LootMaxDist then o.label.Visible=false;o.dot.Visible=false;o.dist.Visible=false; continue end
        local sp,onScreen=W2S(pos)
        if not onScreen then o.label.Visible=false;o.dot.Visible=false;o.dist.Visible=false; continue end
        o.dot.Position=sp; o.dot.Visible=true
        local lname=inst.Name
        if o._lastName~=lname then o._lastName=lname; o.label.Text=(LOOT_ICONS[cat] or "·").." "..lname end
        o.label.Size=S.LootTextSize
        o.label.Position=Vector2.new(sp.X,sp.Y-16);o.label.Visible=true
        if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(sp.X,sp.Y-4);o.dist.Visible=true
    end
    for inst in pairs(LootESPObjects) do if not lootCandidates[inst] then _LootRemove(inst) end end
end

-- ══════════════════════════════════════════
--  EXFIL ESP
-- ══════════════════════════════════════════
local EXFIL_KWS={"exfil","extract","extraction","exit","evac","evacuate","escape","chopper","helicopter","heli","gate","portal","hatch","depart","exit zone","extract zone","end zone"}
local ExfilNameCache={}
local function IsExfil(inst)
    local n=inst.Name:lower()
    if ExfilNameCache[n]~=nil then return ExfilNameCache[n] end
    for _,kw in ipairs(EXFIL_KWS) do if n:find(kw,1,true) then ExfilNameCache[n]=true; return true end end
    ExfilNameCache[n]=false; return false
end
local exfilCandidates={}
local ExfilESPObjects={}
local function _ExfilCheck(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not IsExfil(inst) then return end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart"); if p then pos=p.Position end end
    if pos then exfilCandidates[inst]={inst=inst,pos=pos} end
end
local function _ExfilRemove(inst) exfilCandidates[inst]=nil end
local function _ExfilBootstrap() for _,d in ipairs(Workspace:GetDescendants()) do _ExfilCheck(d) end end

local ExfilArrow={
    shaft=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head1=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head2=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    label=NewDraw("Text",{Visible=false,Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(80,255,140)}),
}

local function GetOrMakeExfilESP(inst)
    if ExfilESPObjects[inst] then return ExfilESPObjects[inst] end
    local o={
        box    =NewDraw("Square",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=2}),
        boxGlow=NewDraw("Square",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=5,Transparency=0.65}),
        pulse  =NewDraw("Circle",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=1.5,NumSides=48,Radius=0}),
        label  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=14}),
        dist   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,255,180),OutlineColor=Color3.new(0,0,0),Size=12}),
        icon   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=18}),
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
    o.box.Visible=false;o.boxGlow.Visible=false;o.pulse.Visible=false
    o.label.Visible=false;o.dist.Visible=false;o.icon.Visible=false
end

local _exfilWasEnabled=false
local function UpdateExfilESP(dt,myRoot)
    ExfilArrow.shaft.Visible=false;ExfilArrow.head1.Visible=false
    ExfilArrow.head2.Visible=false;ExfilArrow.label.Visible=false
    if not S.ExfilESPEnabled then
        if _exfilWasEnabled then for inst in pairs(ExfilESPObjects) do KillExfilESP(inst) end; _exfilWasEnabled=false end
        return
    end
    _exfilWasEnabled=true
    local col=S.ExfilRainbow and RainbowHSV(0.3,0.66) or S.ExfilColor
    local myPos=myRoot and myRoot.Position
    local nearDist,nearPos=mhuge,nil
    for inst,entry in pairs(exfilCandidates) do
        if not inst.Parent then exfilCandidates[inst]=nil; KillExfilESP(inst); continue end
        local pos=entry.pos
        local o=GetOrMakeExfilESP(inst)
        local dist=0
        if myPos then
            local dx=myPos.X-pos.X;local dy=myPos.Y-pos.Y;local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist<nearDist then nearDist=dist; nearPos=pos end
        o.box.Color=col;o.boxGlow.Color=col;o.pulse.Color=col;o.label.Color=col;o.icon.Color=col
        if not S.ExfilShowDist or dist>S.ExfilMaxDist then HideExfil(o); continue end
        local sp,onScreen=W2S(pos)
        if not onScreen then HideExfil(o); continue end
        local bSz=mclamp(80-dist*0.08,18,80); local bx=sp.X-bSz*0.5; local by=sp.Y-bSz*0.5
        o.boxGlow.Size=Vector2.new(bSz+6,bSz+6);o.boxGlow.Position=Vector2.new(bx-3,by-3);o.boxGlow.Visible=true
        o.box.Size=Vector2.new(bSz,bSz);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
        if S.ExfilPulse then
            o._pulseT=(o._pulseT+dt*1.2)%1
            o.pulse.Radius=bSz*0.5+o._pulseT*40; o.pulse.Position=sp
            o.pulse.Transparency=(1-o._pulseT)*0.1; o.pulse.Visible=true
        else o.pulse.Visible=false end
        o.icon.Text="🚁";o.icon.Position=Vector2.new(sp.X,by-22);o.icon.Visible=true
        o.label.Text=inst.Name;o.label.Size=13;o.label.Position=Vector2.new(sp.X,by-10);o.label.Visible=true
        if S.ExfilShowDist then
            if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist<1000 and (dist.." m") or sfmt("%.1f km",dist/1000) end
            o.dist.Position=Vector2.new(sp.X,by+bSz+4);o.dist.Visible=true
        else o.dist.Visible=false end
    end
    for inst in pairs(ExfilESPObjects) do if not exfilCandidates[inst] then KillExfilESP(inst) end end
    if S.ExfilArrow and nearPos and myRoot then
        local sp,onScreen=W2S(nearPos)
        if not onScreen then
            local cx=VP_CX;local cy=VP_CY
            local ang=matan2(sp.Y-cy,sp.X-cx); local mar=65
            local mx=mclamp(cx+mcos(ang)*(cx-mar),mar,VP.X-mar)
            local my=mclamp(cy+msin(ang)*(cy-mar),mar,VP.Y-mar)
            local ax=cx+(mx-cx)*0.85;local ay=cy+(my-cy)*0.85
            local tipX=cx+(mx-cx)*0.93;local tipY=cy+(my-cy)*0.93
            local h1x,h1y=RotVec(tipX,tipY,-10,-5,ang)
            local h2x,h2y=RotVec(tipX,tipY,-10,5,ang)
            ExfilArrow.shaft.From=Vector2.new(ax,ay);ExfilArrow.shaft.To=Vector2.new(tipX,tipY)
            ExfilArrow.head1.From=Vector2.new(tipX,tipY);ExfilArrow.head1.To=Vector2.new(h1x,h1y)
            ExfilArrow.head2.From=Vector2.new(tipX,tipY);ExfilArrow.head2.To=Vector2.new(h2x,h2y)
            local dstr=nearDist<1000 and (nearDist.." m") or sfmt("%.1f km",nearDist/1000)
            ExfilArrow.label.Text="EXFIL  "..dstr; ExfilArrow.label.Position=Vector2.new(ax,ay-14)
            for _,d in pairs(ExfilArrow) do pcall(function() d.Color=col; d.Visible=true end) end
        end
    end
end

-- ══════════════════════════════════════════
--  UNIFIED WORKSPACE SIGNAL
-- ══════════════════════════════════════════
Workspace.DescendantAdded:Connect(function(d)
    task.defer(function()
        if not d or not d.Parent then return end
        if d:IsA("Model") then _AIAdd(d) end
        _LootCheck(d); _ExfilCheck(d)
    end)
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then aiCandidates[d]=nil end
    _LootRemove(d); _ExfilRemove(d)
end)

-- ══════════════════════════════════════════
--  PLAYER AIMBOT  (Universal — Project Delta & Rivals)
-- ══════════════════════════════════════════
local lockedTarget=nil; local lastTargetPos={}; local _prevLockedTarget=nil

-- Part priority list — tried in order when user-selected part isn't found
local AIM_PARTS={"Head","UpperTorso","Torso","HumanoidRootPart","RootPart","LowerTorso"}

local function FindAimPart(char)
    if not char then return nil end
    local pref=char:FindFirstChild(S.AimbotPart)
    if pref and pref:IsA("BasePart") then return pref end
    for _,name in ipairs(AIM_PARTS) do
        local p=char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end

-- Universal alive check — handles Humanoid.Health, custom Attributes, and Values
local function IsTargetAlive(player)
    local char=player.Character
    if not char then return false end

    -- Standard Humanoid check
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.Health<=0 then return false end
        if hum.Health==0 and hum.MaxHealth==0 then return false end
    end

    -- Bool/Int "Dead" or "IsDead" value
    local dv=char:FindFirstChild("Dead") or char:FindFirstChild("IsDead")
    if dv then
        if dv:IsA("BoolValue") and dv.Value then return false end
        if (dv:IsA("IntValue") or dv:IsA("NumberValue")) and dv.Value~=0 then return false end
    end

    -- Bool/Int "Alive" or "IsAlive" value
    local av=char:FindFirstChild("Alive") or char:FindFirstChild("IsAlive")
    if av then
        if av:IsA("BoolValue") and not av.Value then return false end
        if (av:IsA("IntValue") or av:IsA("NumberValue")) and av.Value==0 then return false end
    end

    -- Attribute-based health (Rivals uses char Attributes for HP)
    local ok,hp=pcall(function() return char:GetAttribute("Health") or char:GetAttribute("HP") or char:GetAttribute("hp") end)
    if ok and type(hp)=="number" and hp<=0 then return false end

    -- NumberValue/IntValue named Health or HP inside character
    local hpv=char:FindFirstChild("Health") or char:FindFirstChild("HP") or char:FindFirstChild("hp")
    if hpv and (hpv:IsA("NumberValue") or hpv:IsA("IntValue") or hpv:IsA("FloatValue")) then
        if hpv.Value<=0 then return false end
    end

    -- If we found no Humanoid at all, still allow targeting (some games remove it)
    return true
end

local function GetBestTarget()
    local cx=VP_CX; local cy=VP_CY
    local acquireFOV=S.AimbotFOV
    local keepFOV=acquireFOV*3.0

    if S.AimbotLock and lockedTarget then
        local p=lockedTarget; local char=p and p.Character
        local valid=false
        if char and not (S.TeamCheck and p.Team==LocalPlayer.Team) then
            if IsTargetAlive(p) then
                local part=FindAimPart(char)
                if part then
                    local sp,on=W2S(part.Position)
                    if on then
                        local dx=sp.X-cx; local dy=sp.Y-cy
                        if (dx*dx+dy*dy)^0.5<keepFOV then valid=true end
                    end
                end
            end
        end
        if valid then return lockedTarget end
        lastTargetPos[lockedTarget]=nil; lockedTarget=nil
    end

    local best,bd=nil,mhuge
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer then continue end
        if S.TeamCheck and p.Team==LocalPlayer.Team then continue end
        local char=p.Character
        if not char then continue end
        if not IsTargetAlive(p) then continue end
        local part=FindAimPart(char)
        if not part then continue end
        local sp,on=W2S(part.Position)
        if not on then continue end
        local dx=sp.X-cx; local dy=sp.Y-cy; local d=(dx*dx+dy*dy)^0.5
        if d<acquireFOV and d<bd then bd=d; best=p end
    end

    if best then
        if best~=_prevLockedTarget then lastTargetPos[best]=nil; _prevLockedTarget=best end
        if S.AimbotLock then lockedTarget=best end
    end
    return best
end

local function RunAimbot(camCF,dt)
    FOVCircle.Position=Vector2.new(VP_CX,VP_CY); FOVCircle.Radius=S.AimbotFOV
    FOVCircle.Color=S.FOVColor; FOVCircle.Visible=S.AimbotEnabled and S.FOVVisible
    if not S.AimbotEnabled then LockDot.Visible=false; return end

    local target=GetBestTarget()
    if target then
        local part=FindAimPart(target.Character)
        if part then local sp,on=W2S(part.Position); LockDot.Position=sp; LockDot.Visible=on end
    else LockDot.Visible=false end

    if not IsAimKeyDown(S.AimKey) or not target then return end
    local part=FindAimPart(target.Character)
    if not part then return end

    local pos=part.Position
    if S.AimbotPredict then
        local prev=lastTargetPos[target]; lastTargetPos[target]=pos
        if prev then pos=pos+(pos-prev)*(S.AimbotPredictStr*5) end
    else lastTargetPos[target]=pos end

    local targetCF=CFrame.new(camCF.Position,pos)
    local safeDt=mclamp(dt,0.001,0.05)

    if S.AimbotMode=="Instant" then
        pcall(function() Camera.CFrame=targetCF end)
    elseif S.AimbotMode=="Blatant" then
        local alpha=mclamp(1-(1-S.AimbotBlatant)^(safeDt*60),0.01,0.99)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    else
        local sp2d=W2S(pos); local dx2=sp2d.X-VP_CX; local dy2=sp2d.Y-VP_CY
        local distBoost=mclamp((dx2*dx2+dy2*dy2)^0.5/mmax(S.AimbotFOV,1),0,1)*S.AimbotSmooth*0.8
        local alpha=mclamp(1-(1-(S.AimbotSmooth+distBoost))^(safeDt*60),0.005,0.95)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    end
end

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
local function ShowZoomOverlay(v) for _,k in ipairs(ZO_KEYS) do ZO[k].Visible=v end end

-- ══════════════════════════════════════════
--  FPS / PING
-- ══════════════════════════════════════════
local FPSLabel  = NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,255,160),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,8)})
local PingLabel = NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(160,200,255),Outline=true,OutlineColor=Color3.new(0,0,0),Position=Vector2.new(8,24)})
local fpsFrames,fpsElapsed,fpsVal,pingVal = 0,0,0,0

-- ══════════════════════════════════════════
--  PLAYER ESP
-- ══════════════════════════════════════════
local ESPObjects = {}
local SKEL_PAIRS={
    {"Head","UpperTorso"},{"Head","Torso"},{"UpperTorso","LowerTorso"},{"Torso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local SKEL_N = #SKEL_PAIRS

local function MakeESP(player)
    if ESPObjects[player] then return end
    local sk={}; for i=1,SKEL_N do sk[i]=NewDraw("Line",{Visible=false,Color=Color3.new(1,1,1),Thickness=1}) end
    ESPObjects[player]={
        boxOut=NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=4}),
        box   =NewDraw("Square",{Visible=false,Filled=false,Color=S.BoxColor,Thickness=1.5}),
        fill  =NewDraw("Square",{Visible=false,Filled=true,Color=S.BoxColor,Transparency=0.88}),
        c1=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c2=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c3=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c4=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c5=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c6=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c7=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        c8=NewDraw("Line",{Visible=false,Thickness=2,Color=S.BoxColor}),
        name  =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.new(1,1,1),OutlineColor=Color3.new(0,0,0),Size=14}),
        dist  =NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,180,180),OutlineColor=Color3.new(0,0,0),Size=11}),
        weapon=NewDraw("Text",{Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(255,200,100),OutlineColor=Color3.new(0,0,0),Size=10}),
        hpBg  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(0,220,0)}),
        tracer=NewDraw("Line",{Visible=false,Color=S.BoxColor,Thickness=1}),
        skeleton=sk, _lastDist=-1,
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
    o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
    o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
    o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
    o.name.Visible=false;o.dist.Visible=false;o.weapon.Visible=false
    o.hpBg.Visible=false;o.hpBar.Visible=false;o.tracer.Visible=false
    local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end
end

local function DrawCornerBox(o,bx,by,bw,bh,col)
    o.box.Visible=false;o.fill.Visible=false;o.boxOut.Visible=false
    local cLen=mmax(mfloor(bw*0.25),5)
    o.c1.From=Vector2.new(bx,by);       o.c1.To=Vector2.new(bx+cLen,by);      o.c1.Color=col; o.c1.Visible=true
    o.c2.From=Vector2.new(bx,by);       o.c2.To=Vector2.new(bx,by+cLen);      o.c2.Color=col; o.c2.Visible=true
    o.c3.From=Vector2.new(bx+bw,by);    o.c3.To=Vector2.new(bx+bw-cLen,by);   o.c3.Color=col; o.c3.Visible=true
    o.c4.From=Vector2.new(bx+bw,by);    o.c4.To=Vector2.new(bx+bw,by+cLen);   o.c4.Color=col; o.c4.Visible=true
    o.c5.From=Vector2.new(bx,by+bh);    o.c5.To=Vector2.new(bx+cLen,by+bh);   o.c5.Color=col; o.c5.Visible=true
    o.c6.From=Vector2.new(bx,by+bh);    o.c6.To=Vector2.new(bx,by+bh-cLen);   o.c6.Color=col; o.c6.Visible=true
    o.c7.From=Vector2.new(bx+bw,by+bh); o.c7.To=Vector2.new(bx+bw-cLen,by+bh);o.c7.Color=col; o.c7.Visible=true
    o.c8.From=Vector2.new(bx+bw,by+bh); o.c8.To=Vector2.new(bx+bw,by+bh-cLen);o.c8.Color=col; o.c8.Visible=true
end

local function UpdatePlayerESP(myRoot,rcol)
    local bottom=VP_BOT
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LocalPlayer then continue end
        if not ESPObjects[player] then MakeESP(player) end
        local o=ESPObjects[player]
        if not S.ESPEnabled then HideESP(o); continue end
        local char=player.Character
        if not char or (S.ESPTeamCheck and player.Team==LocalPlayer.Team) then HideESP(o); continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then HideESP(o); continue end
        local root=char:FindFirstChild("HumanoidRootPart")
        local head=char:FindFirstChild("Head")
        if not root or not head then HideESP(o); continue end
        local myPos=myRoot and myRoot.Position
        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X; local dy=myPos.Y-root.Position.Y; local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.ESPMaxDist then HideESP(o); continue end
        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideESP(o); continue end
        local headTopY=head.Position.Y+(head.Size.Y*0.5)+0.1
        local hPos=W2S(Vector3.new(head.Position.X,headTopY,head.Position.Z))
        local bh=mmax(rPos.Y-hPos.Y,14); local bw=mmax(bh*0.50,10)
        local bx=rPos.X-bw*0.5; local by=hPos.Y
        local col=rcol or S.BoxColor
        if S.ESPBoxEnabled then
            if S.ESPCornerBox then
                DrawCornerBox(o,bx,by,bw,bh,col)
            else
                o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
                o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
                o.boxOut.Size=Vector2.new(bw+2,bh+2);o.boxOut.Position=Vector2.new(bx-1,by-1);o.boxOut.Visible=true
                o.box.Color=col;o.box.Size=Vector2.new(bw,bh);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
                if S.ESPFillBox then
                    o.fill.Color=col;o.fill.Size=Vector2.new(bw,bh);o.fill.Position=Vector2.new(bx,by);o.fill.Visible=true
                else o.fill.Visible=false end
            end
        else
            o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
            o.c1.Visible=false;o.c2.Visible=false;o.c3.Visible=false;o.c4.Visible=false
            o.c5.Visible=false;o.c6.Visible=false;o.c7.Visible=false;o.c8.Visible=false
        end
        if S.ESPNames then
            local nm=player.DisplayName~=player.Name and (player.DisplayName.." ("..player.Name..")") or player.Name
            o.name.Text=nm;o.name.Size=S.ESPTextSize
            o.name.Position=Vector2.new(rPos.X,by-S.ESPTextSize-3);o.name.Visible=true
        else o.name.Visible=false end
        if S.ESPDistance then
            if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
            o.dist.Position=Vector2.new(rPos.X,rPos.Y+3);o.dist.Visible=true
        else o.dist.Visible=false end
        if S.ESPWeapon then
            local wpn=WeaponCache[player] or ""
            if wpn~="" then o.weapon.Text="["..wpn.."]";o.weapon.Position=Vector2.new(rPos.X,rPos.Y+15);o.weapon.Visible=true
            else o.weapon.Visible=false end
        else o.weapon.Visible=false end
        if S.ESPHealthBars then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2);o.hpBg.Position=Vector2.new(bx-8,by-1);o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*220),0)
            o.hpBar.Size=Vector2.new(5,bh*pct);o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct));o.hpBar.Visible=true
        else o.hpBg.Visible=false;o.hpBar.Visible=false end
        if S.ESPTracers then
            o.tracer.Color=col;o.tracer.From=bottom;o.tracer.To=rPos;o.tracer.Visible=true
        else o.tracer.Visible=false end
        if S.ESPSkeleton then
            for i,pair in ipairs(SKEL_PAIRS) do
                local line=o.skeleton[i]
                local pA=char:FindFirstChild(pair[1]);local pB=char:FindFirstChild(pair[2])
                if pA and pB then
                    local sA,oA=W2S(pA.Position);local sB,oB=W2S(pB.Position)
                    if oA and oB then line.From=sA;line.To=sB;line.Color=col;line.Visible=true
                    else line.Visible=false end
                else line.Visible=false end
            end
        else local sk=o.skeleton; for i=1,SKEL_N do sk[i].Visible=false end end
    end
end

-- ══════════════════════════════════════════
--  AI ESP
-- ══════════════════════════════════════════
local AIESPObjects={}
local aiCandidates={}
local _aiWasEnabled=false

local function _AIAdd(m)
    if aiCandidates[m] then return end
    if not m:IsA("Model") then return end
    if IsPlayerChar(m) or m==LocalPlayer.Character then return end
    local h=m:FindFirstChildOfClass("Humanoid"); local root=m:FindFirstChild("HumanoidRootPart")
    if h and root then aiCandidates[m]={model=m,hum=h,root=root,head=m:FindFirstChild("Head")} end
end
local function _AIRemove(m) aiCandidates[m]=nil end
local function _AIBootstrap() for _,m in ipairs(Workspace:GetDescendants()) do _AIAdd(m) end end

local function GetOrMakeAIESP(m)
    if AIESPObjects[m] then return AIESPObjects[m] end
    local o={
        boxOut=NewDraw("Square",{Visible=false,Filled=false,Color=Color3.new(0,0,0),Thickness=3}),
        box   =NewDraw("Square",{Visible=false,Filled=false,Color=S.AIBoxColor,Thickness=1.5}),
        fill  =NewDraw("Square",{Visible=false,Filled=true,Color=S.AIBoxColor,Transparency=0.88}),
        name  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.AIBoxColor,OutlineColor=Color3.new(0,0,0),Size=13}),
        dist  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(200,180,140),OutlineColor=Color3.new(0,0,0),Size=11}),
        hpBg  =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.new(0,0,0),Transparency=0.45}),
        hpBar =NewDraw("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(255,140,0)}),
        tracer=NewDraw("Line",  {Visible=false,Color=S.AIBoxColor,Thickness=1}),
        _lastDist=-1,
    }
    AIESPObjects[m]=o; return o
end

local function HideAI(o)
    o.boxOut.Visible=false;o.box.Visible=false;o.fill.Visible=false
    o.name.Visible=false;o.dist.Visible=false;o.hpBg.Visible=false;o.hpBar.Visible=false;o.tracer.Visible=false
end
local function KillAIESP(m)
    local o=AIESPObjects[m]; if not o then return end
    for _,k in ipairs({"boxOut","box","fill","name","dist","hpBg","hpBar","tracer"}) do pcall(function()o[k]:Remove()end) end
    AIESPObjects[m]=nil
end

local aiLockedTarget=nil; local lastAITargetPos={}; local _prevAILockedTarget=nil

local AimKeyMap={
    MouseButton2=function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end,
    C=function() return UserInputService:IsKeyDown(Enum.KeyCode.C) end,
    Q=function() return UserInputService:IsKeyDown(Enum.KeyCode.Q) end,
    E=function() return UserInputService:IsKeyDown(Enum.KeyCode.E) end,
    F=function() return UserInputService:IsKeyDown(Enum.KeyCode.F) end,
}
local function IsAimKeyDown(key) local fn=AimKeyMap[key or S.AimKey]; return fn and fn() or false end

local function GetBestAITarget()
    local cx=VP_CX; local cy=VP_CY
    local acquireFOV=S.AIAimbotFOV
    local keepFOV=acquireFOV*3.0

    if S.AIAimbotLock and aiLockedTarget then
        local m=aiLockedTarget; local entry=aiCandidates[m]
        local valid=false
        if entry and m.Parent and entry.hum.Health>0 then
            local part=m:FindFirstChild(S.AIAimbotPart) or entry.root
            if part then
                local sp,on=W2S(part.Position)
                if on then
                    local dx=sp.X-cx; local dy=sp.Y-cy
                    if (dx*dx+dy*dy)^0.5<keepFOV then valid=true end
                end
            end
        end
        if valid then return aiLockedTarget end
        lastAITargetPos[aiLockedTarget]=nil
        aiLockedTarget=nil
    end

    local best,bd=nil,mhuge
    for m,entry in pairs(aiCandidates) do
        if not m.Parent or entry.hum.Health<=0 then continue end
        local part=m:FindFirstChild(S.AIAimbotPart) or entry.root
        if part then
            local sp,on=W2S(part.Position)
            if on then
                local dx=sp.X-cx; local dy=sp.Y-cy; local d=(dx*dx+dy*dy)^0.5
                if d<acquireFOV and d<bd then bd=d; best=m end
            end
        end
    end
    if best then
        if best~=_prevAILockedTarget then lastAITargetPos[best]=nil; _prevAILockedTarget=best end
        if S.AIAimbotLock then aiLockedTarget=best end
    end
    return best
end

local function RunAIAimbot(camCF,dt)
    AIFOVCircle.Position=Vector2.new(VP_CX,VP_CY); AIFOVCircle.Radius=S.AIAimbotFOV
    AIFOVCircle.Color=S.AIFOVColor; AIFOVCircle.Visible=S.AIAimbotEnabled and S.AIFOVVisible
    if not S.AIAimbotEnabled then AILockDot.Visible=false; return end
    local target=GetBestAITarget()
    if target then
        local entry=aiCandidates[target]
        if entry then
            local part=target:FindFirstChild(S.AIAimbotPart) or entry.root
            if part then local sp,on=W2S(part.Position); AILockDot.Position=sp; AILockDot.Visible=on end
        end
    else AILockDot.Visible=false end
    if not IsAimKeyDown(S.AIAimbotKey) or not target then return end
    local entry=aiCandidates[target]; if not entry then return end
    local part=target:FindFirstChild(S.AIAimbotPart) or entry.root; if not part then return end
    local pos=part.Position
    local prev=lastAITargetPos[target]; lastAITargetPos[target]=pos
    if prev then pos=pos+(pos-prev)*2 end  -- simple 2-frame prediction for AI
    local targetCF=CFrame.new(camCF.Position,pos)
    local safeDt=mclamp(dt,0.001,0.05)
    if S.AIAimbotMode=="Instant" then
        pcall(function() Camera.CFrame=targetCF end)
    elseif S.AIAimbotMode=="Blatant" then
        local alpha=mclamp(1-(1-S.AIAimbotBlatant)^(safeDt*60),0.01,0.99)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    else
        local sp2d=W2S(pos); local dx2=sp2d.X-VP_CX; local dy2=sp2d.Y-VP_CY
        local distBoost=mclamp((dx2*dx2+dy2*dy2)^0.5/mmax(S.AIAimbotFOV,1),0,1)*S.AIAimbotSmooth*0.8
        local alpha=mclamp(1-(1-(S.AIAimbotSmooth+distBoost))^(safeDt*60),0.005,0.95)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    end
end

local function UpdateAIESP(myRoot)
    if not S.AIESPEnabled then
        if _aiWasEnabled then for m in pairs(AIESPObjects) do KillAIESP(m) end; _aiWasEnabled=false end
        return
    end
    _aiWasEnabled=true
    local bottom=VP_BOT
    local rcol=S.AIESPRainbow and RainbowHSV(0.4,0.33) or nil
    local myPos=myRoot and myRoot.Position
    for m,entry in pairs(aiCandidates) do
        if not m.Parent then aiCandidates[m]=nil; KillAIESP(m); continue end
        local hum=entry.hum; local root=entry.root; local head=entry.head
        local o=GetOrMakeAIESP(m)
        if not root or hum.Health<=0 then HideAI(o); continue end
        local dist=0
        if myPos then
            local dx=myPos.X-root.Position.X; local dy=myPos.Y-root.Position.Y; local dz=myPos.Z-root.Position.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.AIESPMaxDist then HideAI(o); continue end
        local rPos,onScreen=W2S(root.Position)
        if not onScreen then HideAI(o); continue end
        local hTopY=head and (head.Position.Y+(head.Size and head.Size.Y*0.5 or 0.5)+0.1) or root.Position.Y+3
        local hPos=W2S(Vector3.new(root.Position.X,hTopY,root.Position.Z))
        local bh=mmax(rPos.Y-hPos.Y,14); local bw=mmax(bh*0.50,10)
        local bx=rPos.X-bw*0.5; local by=hPos.Y
        local col=rcol or S.AIBoxColor
        o.boxOut.Size=Vector2.new(bw+2,bh+2);o.boxOut.Position=Vector2.new(bx-1,by-1);o.boxOut.Visible=true
        o.box.Color=col;o.box.Size=Vector2.new(bw,bh);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
        o.fill.Color=col;o.fill.Size=Vector2.new(bw,bh);o.fill.Position=Vector2.new(bx,by);o.fill.Visible=true
        if S.AIESPNames then o.name.Text=m.Name;o.name.Position=Vector2.new(rPos.X,by-15);o.name.Color=col;o.name.Visible=true
        else o.name.Visible=false end
        if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(rPos.X,rPos.Y+3);o.dist.Visible=true
        if S.AIESPHealth then
            local pct=mclamp(hum.Health/mmax(hum.MaxHealth,1),0,1)
            o.hpBg.Size=Vector2.new(5,bh+2);o.hpBg.Position=Vector2.new(bx-8,by-1);o.hpBg.Visible=true
            o.hpBar.Color=Color3.fromRGB(mfloor((1-pct)*255),mfloor(pct*180),0)
            o.hpBar.Size=Vector2.new(5,bh*pct);o.hpBar.Position=Vector2.new(bx-8,by+bh*(1-pct));o.hpBar.Visible=true
        else o.hpBg.Visible=false;o.hpBar.Visible=false end
        if S.AIESPTracers then o.tracer.Color=col;o.tracer.From=bottom;o.tracer.To=rPos;o.tracer.Visible=true
        else o.tracer.Visible=false end
    end
    for m in pairs(AIESPObjects) do if not aiCandidates[m] then KillAIESP(m) end end
end

-- ══════════════════════════════════════════
--  LOOT ESP
-- ══════════════════════════════════════════
local LOOT_BLACKLIST={
    Head=true,Face=true,Torso=true,HumanoidRootPart=true,
    UpperTorso=true,LowerTorso=true,
    ["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
    LeftUpperArm=true,RightUpperArm=true,LeftLowerArm=true,RightLowerArm=true,
    LeftHand=true,RightHand=true,LeftUpperLeg=true,RightUpperLeg=true,
    LeftLowerLeg=true,RightLowerLeg=true,LeftFoot=true,RightFoot=true,
    Baseplate=true,Terrain=true,SpawnLocation=true,Sky=true,Sun=true,
    Part=true,UnionOperation=true,Decal=true,Texture=true,SpecialMesh=true,
    -- Project Delta hitbox parts
    HeadTopHitBox=true,FaceHitBox=true,HeadHitBox=true,BodyHitBox=true,
    TorsoHitBox=true,ChestHitBox=true,ArmHitBox=true,LegHitBox=true,
    HandHitBox=true,FootHitBox=true,UpperTorsoHitBox=true,LowerTorsoHitBox=true,
    LeftArmHitBox=true,RightArmHitBox=true,LeftLegHitBox=true,RightLegHitBox=true,
    NeckHitBox=true,BackHitBox=true,SpineHitBox=true,
}
local LOOT_BAD_KWS={"hitbox","hit_box","hitzone","hit_zone","damagebox","damage_box","hurtbox","hurt_box","collision","nametag","billboard","highlight","selection","attachment"}
local function _IsBadName(n)
    local l=n:lower()
    for _,kw in ipairs(LOOT_BAD_KWS) do if l:find(kw,1,true) then return true end end
    return false
end

local LOOT_CATS={
    Keys={"keycard","key card","access card","id card","passcard","badge","fob","room key","master key","storage key","cabinet key","cell key","red keycard","blue keycard","green keycard","yellow keycard","black keycard","vip key"},
    Bodies={"body","corpse","dead","ragdoll","remains","victim","fallen","skeleton","bones","player body","dead body","loot body"},
    Weapons={"gun","pistol","revolver","rifle","carbine","assault","shotgun","pump","smg","submachine","sniper","dmr","marksman","bolt","lmg","machine gun","knife","combat knife","sword","axe","hatchet","weapon","firearm","blade","crossbow","ak","m4","ar15","glock"},
    Ammo={"ammo","ammunition","bullet","bullets","magazine","mag","round","rounds","shell","shells","clip","cartridge","9mm","556","762","308","12 gauge","buckshot"},
    Medical={"medkit","med kit","first aid","bandage","gauze","tourniquet","health","heal","syringe","injector","epi","adrenaline","pill","pills","painkiller","morphine","stim","stimulant","blood bag","splint","drug","medication","antidote","food","water","drink","ration"},
    Valuables={"gold","silver","platinum","gem","gemstone","diamond","ruby","emerald","jewel","jewelry","valuable","rare","artifact","relic","cash","money","wallet","currency","coin","token","credit","loot","treasure","bounty","intel","document","usb"},
    Containers={"chest","crate","supply crate","loot crate","box","case","briefcase","bag","duffel","backpack","rucksack","stash","cache","container","locker","footlocker","safe","vault","strongbox"},
    Armor={"helmet","ballistic helmet","tactical helmet","vest","plate carrier","body armor","armor","armour","plates","chest rig","gas mask","respirator","shield"},
    Explosives={"grenade","frag","flashbang","smoke","incendiary","molotov","explosive","bomb","ied","mine","claymore","landmine","c4","rpg","rocket"},
    Tools={"toolkit","tool kit","tools","repair kit","screwdriver","lockpick","pick","crowbar","rope","radio","walkie","flashlight","torch","compass","map","gps","tracker","battery","batteries","fuel","parachute"},
    Other={},
}
local LOOT_ICONS={Keys="🔑",Bodies="💀",Weapons="🔫",Ammo="🔹",Medical="💊",Valuables="💎",Containers="📦",Armor="🛡",Explosives="💣",Tools="🔧",Other="·"}
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

local LootESPObjects={}
local lootCandidates={}
local function _LootCheck(inst)
    if not inst:IsA("BasePart") and not inst:IsA("Model") then return end
    if IsPlayerChar(inst) then return end
    local n=inst.Name
    if n=="" or LOOT_BLACKLIST[n] or _IsBadName(n) then return end
    local anc=inst.Parent
    while anc and anc~=Workspace do
        if IsPlayerChar(anc) then return end
        if anc==LocalPlayer.Character then return end
        for _,p in ipairs(Players:GetPlayers()) do if anc==p.Character then return end end
        anc=anc.Parent
    end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart"); if p then pos=p.Position end end
    if not pos then return end
    local cat=ClassifyItem(n)
    if cat=="Other" and #n<4 then return end
    lootCandidates[inst]={inst=inst,cat=cat}
end
local function _LootRemove(inst)
    if lootCandidates[inst] then lootCandidates[inst]=nil end
    if LootESPObjects[inst] then
        local o=LootESPObjects[inst]
        pcall(function()o.dot:Remove()end);pcall(function()o.label:Remove()end);pcall(function()o.dist:Remove()end)
        LootESPObjects[inst]=nil
    end
end
local function _LootBootstrap()
    for _,child in ipairs(Workspace:GetChildren()) do
        _LootCheck(child)
        if child:IsA("Folder") or child:IsA("Model") then
            for _,sub in ipairs(child:GetChildren()) do _LootCheck(sub) end
        end
    end
end

local function MakeLootESP(inst,cat)
    if LootESPObjects[inst] then return LootESPObjects[inst] end
    local col=S.LootColors[cat] or Color3.fromRGB(180,180,180)
    local o={cat=cat,
        dot  =NewDraw("Circle",{Visible=false,Filled=true,Color=col,Radius=3,NumSides=8,Thickness=0}),
        label=NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=col,OutlineColor=Color3.new(0,0,0),Size=S.LootTextSize}),
        dist =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(160,160,160),OutlineColor=Color3.new(0,0,0),Size=10}),
        _lastDist=-1,_lastName="",
    }
    LootESPObjects[inst]=o; return o
end

local _lootWasEnabled=false
local function UpdateLootESP(myRoot)
    if not S.LootESPEnabled then
        if _lootWasEnabled then
            for item in pairs(LootESPObjects) do _LootRemove(item) end
            _lootWasEnabled=false
        end; return
    end
    _lootWasEnabled=true
    local myPos=myRoot and myRoot.Position
    for inst,entry in pairs(lootCandidates) do
        if not inst.Parent then _LootRemove(inst); continue end
        local cat=entry.cat
        if not S.LootFilter[cat] then if LootESPObjects[inst] then _LootRemove(inst) end; continue end
        local pos
        if inst:IsA("BasePart") then pos=inst.Position
        elseif inst:IsA("Model") then local p=inst.PrimaryPart; if p then pos=p.Position end end
        if not pos then continue end
        local o=MakeLootESP(inst,cat)
        local col=S.LootColors[cat] or Color3.fromRGB(180,180,180)
        o.label.Color=col; o.dot.Color=col
        local dist=0
        if myPos then
            local dx=myPos.X-pos.X; local dy=myPos.Y-pos.Y; local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist>S.LootMaxDist then o.label.Visible=false;o.dot.Visible=false;o.dist.Visible=false; continue end
        local sp,onScreen=W2S(pos)
        if not onScreen then o.label.Visible=false;o.dot.Visible=false;o.dist.Visible=false; continue end
        o.dot.Position=sp; o.dot.Visible=true
        local lname=inst.Name
        if o._lastName~=lname then o._lastName=lname; o.label.Text=(LOOT_ICONS[cat] or "·").." "..lname end
        o.label.Size=S.LootTextSize
        o.label.Position=Vector2.new(sp.X,sp.Y-16);o.label.Visible=true
        if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist.." m" end
        o.dist.Position=Vector2.new(sp.X,sp.Y-4);o.dist.Visible=true
    end
    for inst in pairs(LootESPObjects) do if not lootCandidates[inst] then _LootRemove(inst) end end
end

-- ══════════════════════════════════════════
--  EXFIL ESP
-- ══════════════════════════════════════════
local EXFIL_KWS={"exfil","extract","extraction","exit","evac","evacuate","escape","chopper","helicopter","heli","gate","portal","hatch","depart","exit zone","extract zone","end zone"}
local ExfilNameCache={}
local function IsExfil(inst)
    local n=inst.Name:lower()
    if ExfilNameCache[n]~=nil then return ExfilNameCache[n] end
    for _,kw in ipairs(EXFIL_KWS) do if n:find(kw,1,true) then ExfilNameCache[n]=true; return true end end
    ExfilNameCache[n]=false; return false
end
local exfilCandidates={}
local ExfilESPObjects={}
local function _ExfilCheck(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not IsExfil(inst) then return end
    local pos
    if inst:IsA("BasePart") then pos=inst.Position
    elseif inst:IsA("Model") then local p=inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart"); if p then pos=p.Position end end
    if pos then exfilCandidates[inst]={inst=inst,pos=pos} end
end
local function _ExfilRemove(inst) exfilCandidates[inst]=nil end
local function _ExfilBootstrap() for _,d in ipairs(Workspace:GetDescendants()) do _ExfilCheck(d) end end

local ExfilArrow={
    shaft=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head1=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    head2=NewDraw("Line",{Visible=false,Color=Color3.fromRGB(80,255,140),Thickness=2.5}),
    label=NewDraw("Text",{Visible=false,Size=12,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(80,255,140)}),
}

local function GetOrMakeExfilESP(inst)
    if ExfilESPObjects[inst] then return ExfilESPObjects[inst] end
    local o={
        box    =NewDraw("Square",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=2}),
        boxGlow=NewDraw("Square",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=5,Transparency=0.65}),
        pulse  =NewDraw("Circle",{Visible=false,Filled=false,Color=S.ExfilColor,Thickness=1.5,NumSides=48,Radius=0}),
        label  =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=14}),
        dist   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=Color3.fromRGB(180,255,180),OutlineColor=Color3.new(0,0,0),Size=12}),
        icon   =NewDraw("Text",  {Visible=false,Center=true,Outline=true,Color=S.ExfilColor,OutlineColor=Color3.new(0,0,0),Size=18}),
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
    o.box.Visible=false;o.boxGlow.Visible=false;o.pulse.Visible=false
    o.label.Visible=false;o.dist.Visible=false;o.icon.Visible=false
end

local _exfilWasEnabled=false
local function UpdateExfilESP(dt,myRoot)
    ExfilArrow.shaft.Visible=false;ExfilArrow.head1.Visible=false
    ExfilArrow.head2.Visible=false;ExfilArrow.label.Visible=false
    if not S.ExfilESPEnabled then
        if _exfilWasEnabled then for inst in pairs(ExfilESPObjects) do KillExfilESP(inst) end; _exfilWasEnabled=false end
        return
    end
    _exfilWasEnabled=true
    local col=S.ExfilRainbow and RainbowHSV(0.3,0.66) or S.ExfilColor
    local myPos=myRoot and myRoot.Position
    local nearDist,nearPos=mhuge,nil
    for inst,entry in pairs(exfilCandidates) do
        if not inst.Parent then exfilCandidates[inst]=nil; KillExfilESP(inst); continue end
        local pos=entry.pos
        local o=GetOrMakeExfilESP(inst)
        local dist=0
        if myPos then
            local dx=myPos.X-pos.X;local dy=myPos.Y-pos.Y;local dz=myPos.Z-pos.Z
            dist=mfloor((dx*dx+dy*dy+dz*dz)^0.5)
        end
        if dist<nearDist then nearDist=dist; nearPos=pos end
        o.box.Color=col;o.boxGlow.Color=col;o.pulse.Color=col;o.label.Color=col;o.icon.Color=col
        if not S.ExfilShowDist or dist>S.ExfilMaxDist then HideExfil(o); continue end
        local sp,onScreen=W2S(pos)
        if not onScreen then HideExfil(o); continue end
        local bSz=mclamp(80-dist*0.08,18,80); local bx=sp.X-bSz*0.5; local by=sp.Y-bSz*0.5
        o.boxGlow.Size=Vector2.new(bSz+6,bSz+6);o.boxGlow.Position=Vector2.new(bx-3,by-3);o.boxGlow.Visible=true
        o.box.Size=Vector2.new(bSz,bSz);o.box.Position=Vector2.new(bx,by);o.box.Visible=true
        if S.ExfilPulse then
            o._pulseT=(o._pulseT+dt*1.2)%1
            o.pulse.Radius=bSz*0.5+o._pulseT*40; o.pulse.Position=sp
            o.pulse.Transparency=(1-o._pulseT)*0.1; o.pulse.Visible=true
        else o.pulse.Visible=false end
        o.icon.Text="🚁";o.icon.Position=Vector2.new(sp.X,by-22);o.icon.Visible=true
        o.label.Text=inst.Name;o.label.Size=13;o.label.Position=Vector2.new(sp.X,by-10);o.label.Visible=true
        if S.ExfilShowDist then
            if o._lastDist~=dist then o._lastDist=dist;o.dist.Text=dist<1000 and (dist.." m") or sfmt("%.1f km",dist/1000) end
            o.dist.Position=Vector2.new(sp.X,by+bSz+4);o.dist.Visible=true
        else o.dist.Visible=false end
    end
    for inst in pairs(ExfilESPObjects) do if not exfilCandidates[inst] then KillExfilESP(inst) end end
    if S.ExfilArrow and nearPos and myRoot then
        local sp,onScreen=W2S(nearPos)
        if not onScreen then
            local cx=VP_CX;local cy=VP_CY
            local ang=matan2(sp.Y-cy,sp.X-cx); local mar=65
            local mx=mclamp(cx+mcos(ang)*(cx-mar),mar,VP.X-mar)
            local my=mclamp(cy+msin(ang)*(cy-mar),mar,VP.Y-mar)
            local ax=cx+(mx-cx)*0.85;local ay=cy+(my-cy)*0.85
            local tipX=cx+(mx-cx)*0.93;local tipY=cy+(my-cy)*0.93
            local h1x,h1y=RotVec(tipX,tipY,-10,-5,ang)
            local h2x,h2y=RotVec(tipX,tipY,-10,5,ang)
            ExfilArrow.shaft.From=Vector2.new(ax,ay);ExfilArrow.shaft.To=Vector2.new(tipX,tipY)
            ExfilArrow.head1.From=Vector2.new(tipX,tipY);ExfilArrow.head1.To=Vector2.new(h1x,h1y)
            ExfilArrow.head2.From=Vector2.new(tipX,tipY);ExfilArrow.head2.To=Vector2.new(h2x,h2y)
            local dstr=nearDist<1000 and (nearDist.." m") or sfmt("%.1f km",nearDist/1000)
            ExfilArrow.label.Text="EXFIL  "..dstr; ExfilArrow.label.Position=Vector2.new(ax,ay-14)
            for _,d in pairs(ExfilArrow) do pcall(function() d.Color=col; d.Visible=true end) end
        end
    end
end

-- ══════════════════════════════════════════
--  UNIFIED WORKSPACE SIGNAL
-- ══════════════════════════════════════════
Workspace.DescendantAdded:Connect(function(d)
    task.defer(function()
        if not d or not d.Parent then return end
        if d:IsA("Model") then _AIAdd(d) end
        _LootCheck(d); _ExfilCheck(d)
    end)
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then aiCandidates[d]=nil end
    _LootRemove(d); _ExfilRemove(d)
end)

-- ══════════════════════════════════════════
--  PLAYER AIMBOT
-- ══════════════════════════════════════════
local lockedTarget=nil; local lastTargetPos={}; local _prevLockedTarget=nil

--[[
    AIMBOT FIXES:
    FIX-A1: Separate acquire FOV vs keep-lock FOV.
            Lock is maintained up to 3x the FOV radius.
            This prevents lock dropping while smooth aim is still catching up.
    FIX-A2: Prediction multiplier removed (*8 caused massive overshoot).
            Now uses AimbotPredictStr directly as frames-ahead (0.5 to 5).
    FIX-A3: Smooth and Blatant modes are now frame-rate independent via dt.
            (1-(1-alpha)^(dt*60)) gives consistent speed at any FPS.)
    FIX-A4: lastTargetPos is cleared when target changes to prevent
            bad prediction on the first frame after switching targets.
]]

local function GetBestTarget()
    local cx=VP_CX; local cy=VP_CY
    local acquireFOV=S.AimbotFOV
    local keepFOV=acquireFOV*3.0  -- keep lock up to 3x radius so smooth aim can catch up

    -- Validate existing locked target (FIX-A1)
    if S.AimbotLock and lockedTarget then
        local p=lockedTarget; local char=p and p.Character
        local valid=false
        if char and not (S.TeamCheck and p.Team==LocalPlayer.Team) then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local part=char:FindFirstChild(S.AimbotPart) or char:FindFirstChild("HumanoidRootPart")
                if part then
                    local sp,on=W2S(part.Position)
                    -- Only drop lock if VERY far outside FOV or off screen entirely
                    if on then
                        local dx=sp.X-cx; local dy=sp.Y-cy
                        if (dx*dx+dy*dy)^0.5 < keepFOV then valid=true end
                    end
                end
            end
        end
        if valid then return lockedTarget end
        -- Target lost — clear prediction data so next target starts clean
        lastTargetPos[lockedTarget]=nil
        lockedTarget=nil
    end

    -- Find best new target (closest to crosshair within acquire FOV)
    local best,bd=nil,mhuge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and not (S.TeamCheck and p.Team==LocalPlayer.Team) then
            local char=p.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health>0 then
                    local part=char:FindFirstChild(S.AimbotPart) or char:FindFirstChild("HumanoidRootPart")
                    if part then
                        local sp,on=W2S(part.Position)
                        if on then
                            local dx=sp.X-cx; local dy=sp.Y-cy; local d=(dx*dx+dy*dy)^0.5
                            if d<acquireFOV and d<bd then bd=d; best=p end
                        end
                    end
                end
            end
        end
    end

    if best then
        -- FIX-A4: clear old prediction data when acquiring a new target
        if best~=_prevLockedTarget then
            lastTargetPos[best]=nil
            _prevLockedTarget=best
        end
        if S.AimbotLock then lockedTarget=best end
    end
    return best
end

local function RunAimbot(camCF,dt)
    FOVCircle.Position=Vector2.new(VP_CX,VP_CY); FOVCircle.Radius=S.AimbotFOV
    FOVCircle.Color=S.FOVColor; FOVCircle.Visible=S.AimbotEnabled and S.FOVVisible
    if not S.AimbotEnabled then LockDot.Visible=false; return end

    local target=GetBestTarget()
    if target then
        local char=target.Character
        local part=char and (char:FindFirstChild(S.AimbotPart) or char:FindFirstChild("HumanoidRootPart"))
        if part then local sp,on=W2S(part.Position); LockDot.Position=sp; LockDot.Visible=on end
    else LockDot.Visible=false end

    if not IsAimKeyDown(S.AimKey) or not target then return end

    local char=target.Character
    local part=char and (char:FindFirstChild(S.AimbotPart) or char:FindFirstChild("HumanoidRootPart"))
    if not part then return end

    local pos=part.Position

    -- FIX-A2: Prediction without the *8 overshoot multiplier
    -- AimbotPredictStr (0.1–1.0 from slider) * 5 = 0.5 to 5 frames ahead
    if S.AimbotPredict then
        local prev=lastTargetPos[target]
        lastTargetPos[target]=pos
        if prev then
            local frames=S.AimbotPredictStr*5
            pos=pos+(pos-prev)*frames
        end
    else
        lastTargetPos[target]=pos
    end

    local targetCF=CFrame.new(camCF.Position,pos)
    local safeDt=mclamp(dt,0.001,0.05)  -- clamp dt so lag spikes don't cause jumps

    if S.AimbotMode=="Instant" then
        pcall(function() Camera.CFrame=targetCF end)

    elseif S.AimbotMode=="Blatant" then
        -- FIX-A3: frame-rate independent blatant snap
        local alpha=1-(1-S.AimbotBlatant)^(safeDt*60)
        alpha=mclamp(alpha,0.01,0.99)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)

    else -- Smooth
        -- FIX-A3: frame-rate independent smooth tracking
        -- Slight dynamic boost when target is far from centre so it doesn't crawl
        local sp2d=W2S(pos)
        local dx2=sp2d.X-VP_CX; local dy2=sp2d.Y-VP_CY
        local screenDist=(dx2*dx2+dy2*dy2)^0.5
        -- boost up to 80% extra speed at edge of FOV, proportional to distance
        local distBoost=mclamp(screenDist/mmax(S.AimbotFOV,1),0,1)*S.AimbotSmooth*0.8
        local baseAlpha=S.AimbotSmooth+distBoost
        -- convert per-frame alpha to frame-rate independent alpha
        local alpha=1-(1-baseAlpha)^(safeDt*60)
        alpha=mclamp(alpha,0.005,0.95)
        pcall(function() Camera.CFrame=camCF:Lerp(targetCF,alpha) end)
    end
end

-- ══════════════════════════════════════════
--  ZOOM
-- ══════════════════════════════════════════
local zoomTween=nil
local function CancelZoomTween() if zoomTween then pcall(function()zoomTween:Cancel()end); zoomTween=nil end end
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
local function IsZoomKeyDown() local fn=ZoomKeyMap[S.ZoomKey]; return fn and fn() or false end

local function UpdateZoomOverlay()
    if not S.ZoomOverlay then ShowZoomOverlay(false); return end
    local cx=VP_CX;local cy=VP_CY;local col=S.ZoomOverlayColor
    local bLen=36;local bGap=90
    ZO.vigL.Position=Vector2.new(0,0);ZO.vigL.Size=Vector2.new(80,VP.Y)
    ZO.vigR.Position=Vector2.new(VP.X-80,0);ZO.vigR.Size=Vector2.new(80,VP.Y)
    ZO.vigT.Position=Vector2.new(0,0);ZO.vigT.Size=Vector2.new(VP.X,38)
    ZO.vigB.Position=Vector2.new(0,VP.Y-38);ZO.vigB.Size=Vector2.new(VP.X,38)
    for _,k in ipairs({"tlH","tlV","trH","trV","blH","blV","brH","brV","dot","hLine","vLine","zLbl","rf"}) do ZO[k].Color=col end
    local tl=Vector2.new(cx-bGap,cy-bGap);local tr=Vector2.new(cx+bGap,cy-bGap)
    local bl=Vector2.new(cx-bGap,cy+bGap);local br=Vector2.new(cx+bGap,cy+bGap)
    ZO.tlH.From=tl;ZO.tlH.To=Vector2.new(tl.X+bLen,tl.Y)
    ZO.tlV.From=tl;ZO.tlV.To=Vector2.new(tl.X,tl.Y+bLen)
    ZO.trH.From=tr;ZO.trH.To=Vector2.new(tr.X-bLen,tr.Y)
    ZO.trV.From=tr;ZO.trV.To=Vector2.new(tr.X,tr.Y+bLen)
    ZO.blH.From=bl;ZO.blH.To=Vector2.new(bl.X+bLen,bl.Y)
    ZO.blV.From=bl;ZO.blV.To=Vector2.new(bl.X,bl.Y-bLen)
    ZO.brH.From=br;ZO.brH.To=Vector2.new(br.X-bLen,br.Y)
    ZO.brV.From=br;ZO.brV.To=Vector2.new(br.X,br.Y-bLen)
    ZO.hLine.From=Vector2.new(cx-bGap-bLen-10,cy);ZO.hLine.To=Vector2.new(cx+bGap+bLen+10,cy)
    ZO.vLine.From=Vector2.new(cx,cy-bGap-bLen-10);ZO.vLine.To=Vector2.new(cx,cy+bGap+bLen+10)
    ZO.dot.Position=Vector2.new(cx,cy)
    local mag=mfloor(S._BaseFOV/mmax(Camera.FieldOfView,1)*10)/10
    ZO.zLbl.Text=sfmt("%.1fx",mag);ZO.zLbl.Position=Vector2.new(cx+bGap+bLen+14,cy-6)
    local myChar=LocalPlayer.Character; local myRoot2=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot2 then
        local nd,nn=mhuge,nil
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then
                local r2=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if r2 then
                    local dx=myRoot2.Position.X-r2.Position.X;local dz=myRoot2.Position.Z-r2.Position.Z
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
    if not S.ZoomEnabled then
        if S.ZoomActive then
            S.ZoomActive=false; CancelZoomTween(); Camera.FieldOfView=S.CameraFOV; ShowZoomOverlay(false)
        end; return
    end
    local want=IsZoomKeyDown()
    if want and not S.ZoomActive then
        S.ZoomActive=true; S._BaseFOV=Camera.FieldOfView
        SetCameraFOV(S.ZoomFOV,S.ZoomSmooth,S.ZoomSpeed)
    elseif not want and S.ZoomActive then
        S.ZoomActive=false; CancelZoomTween()
        SetCameraFOV(S._BaseFOV,S.ZoomSmooth,S.ZoomSpeed*0.8)
        ShowZoomOverlay(false)
    end
    if S.ZoomActive then UpdateZoomOverlay() end
end

-- ══════════════════════════════════════════
--  NO RECOIL  (Heartbeat)
-- ══════════════════════════════════════════
local lastCamCF=nil; local _nrJitter=0
RunService.Heartbeat:Connect(function(dt)
    if not S.NoRecoilEnabled or not lastCamCF then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then _nrJitter=0; return end
    local camCF=Camera.CFrame
    local px=select(1,lastCamCF:ToEulerAnglesYXZ())
    local ccx,ccy,ccz=camCF:ToEulerAnglesYXZ()
    local delta=ccx-px
    if delta>0.0004 then
        _nrJitter=(_nrJitter+dt*3)%0.002-0.001
        pcall(function()
            Camera.CFrame=CFrame.new(camCF.Position)*CFrame.fromEulerAnglesYXZ(ccx-delta*(1-S.RecoilStrength)+_nrJitter,ccy,ccz)
        end)
    end
    lastCamCF=Camera.CFrame
end)

-- ══════════════════════════════════════════
--  TRIGGERBOT  (Heartbeat)
-- ══════════════════════════════════════════
local _trigAcc=0
RunService.Heartbeat:Connect(function(dt)
    if not S.TriggerBot or not VIM then _trigAcc=0; return end
    local target=Mouse.Target; if not target then _trigAcc=0; return end
    local model=target:FindFirstAncestorOfClass("Model"); if not model then _trigAcc=0; return end
    local p=Players:GetPlayerFromCharacter(model)
    if not p or p==LocalPlayer or (S.TeamCheck and p.Team==LocalPlayer.Team) then _trigAcc=0; return end
    local char=p.Character; if not char then _trigAcc=0; return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then _trigAcc=0; return end
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then _trigAcc=0; return end
    _trigAcc=_trigAcc+dt
    if _trigAcc>=(S.TrigDelay or 0)/1000 then
        _trigAcc=0
        pcall(function()
            local mx=Mouse.X;local my=Mouse.Y
            VIM:SendMouseButtonEvent(mx,my,Enum.UserInputType.MouseButton1,true,game,0)
            VIM:SendMouseButtonEvent(mx,my,Enum.UserInputType.MouseButton1,false,game,0)
        end)
    end
end)

-- ══════════════════════════════════════════
--  HITBOX EXPANDER
-- ══════════════════════════════════════════
local HitboxObjects={}; local hitboxConn=nil
local function StartHitboxExpander()
    if hitboxConn then hitboxConn:Disconnect(); hitboxConn=nil end
    if not S.HitboxExpander then
        for p,part in pairs(HitboxObjects) do pcall(function()part:Destroy()end); HitboxObjects[p]=nil end; return
    end
    hitboxConn=RunService.Heartbeat:Connect(function()
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer then continue end
            local char=p.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
            if root then
                if not HitboxObjects[p] or not HitboxObjects[p].Parent then
                    local part=Instance.new("Part")
                    part.Name=""; part.Anchored=true; part.CanCollide=false
                    part.Transparency=1; part.CanQuery=true; part.CanTouch=false
                    part.CastShadow=false; part.Size=Vector3.new(S.HitboxSize,S.HitboxSize,S.HitboxSize)
                    part.CFrame=root.CFrame; part.Parent=char; HitboxObjects[p]=part
                else
                    local part=HitboxObjects[p]; part.CFrame=root.CFrame
                    if part.Size.X~=S.HitboxSize then part.Size=Vector3.new(S.HitboxSize,S.HitboxSize,S.HitboxSize) end
                end
            else
                if HitboxObjects[p] then pcall(function()HitboxObjects[p]:Destroy()end); HitboxObjects[p]=nil end
            end
        end
    end)
end

-- ══════════════════════════════════════════
--  FULLBRIGHT / FOG
-- ══════════════════════════════════════════
local _oA,_oO,_oB,_oC
local function SetFullbright(on)
    if on then
        _oA=Lighting.Ambient;_oO=Lighting.OutdoorAmbient;_oB=Lighting.Brightness;_oC=Lighting.ClockTime
        Lighting.Ambient=Color3.new(1,1,1);Lighting.OutdoorAmbient=Color3.new(1,1,1);Lighting.Brightness=2;Lighting.ClockTime=14
    else
        if _oA then Lighting.Ambient=_oA end;if _oO then Lighting.OutdoorAmbient=_oO end
        if _oB then Lighting.Brightness=_oB end;if _oC then Lighting.ClockTime=_oC end
    end
end
local function SetNoFog(on)
    for _,obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then pcall(function() obj.Density=on and 0 or 0.395; obj.Haze=on and 0 or 2.8 end) end
        if obj:IsA("FogEffect")  then pcall(function() obj.Enabled=not on end) end
    end
end

-- ══════════════════════════════════════════
--  CHARACTER EVENTS
-- ══════════════════════════════════════════
local function OnLocalCharAdded(char)
    char:WaitForChild("Humanoid",5)
    if S.NoFogEnabled     then SetNoFog(true) end
    if S.FullbrightEnabled then SetFullbright(true) end
    lastCamCF=nil
end
LocalPlayer.CharacterAdded:Connect(OnLocalCharAdded)
if LocalPlayer.Character then task.spawn(OnLocalCharAdded,LocalPlayer.Character) end

Players.PlayerAdded:Connect(function(p) MakeESP(p) end)
Players.PlayerRemoving:Connect(function(p)
    KillESP(p); lastTargetPos[p]=nil
    if lockedTarget==p then lockedTarget=nil; _prevLockedTarget=nil end
    if HitboxObjects[p] then pcall(function()HitboxObjects[p]:Destroy()end); HitboxObjects[p]=nil end
end)

-- ══════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    _tick=tick()
    fpsFrames=fpsFrames+1; fpsElapsed=fpsElapsed+dt
    if fpsElapsed>=0.5 then
        fpsVal=mfloor(fpsFrames/fpsElapsed); fpsFrames=0; fpsElapsed=0
        if S.ShowPing then
            local ok,p=pcall(function() return mfloor(LocalPlayer:GetNetworkPing()*1000) end)
            pingVal=ok and p or 0
        end
    end
    local camCF=Camera.CFrame
    local myChar=LocalPlayer.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    lastCamCF=camCF
    RunAimbot(camCF,dt); RunAIAimbot(camCF,dt)
    local rcol=S.ESPRainbow and RainbowHSV(0.4) or nil
    UpdatePlayerESP(myRoot,rcol)
    UpdateAIESP(myRoot)
    UpdateLootESP(myRoot)
    UpdateExfilESP(dt,myRoot)
    UpdateZoom()
    UpdateCrosshair(dt)
    UpdateHitmarker(dt)
    if S.ShowFPS then FPSLabel.Text=sfmt("FPS: %d",fpsVal); FPSLabel.Visible=true else FPSLabel.Visible=false end
    if S.ShowPing then PingLabel.Text=sfmt("Ping: %d ms",pingVal); PingLabel.Visible=true else PingLabel.Visible=false end
end)

-- ══════════════════════════════════════════════════════
--  RAYFIELD TABS
-- ══════════════════════════════════════════════════════

-- ── TAB 1: Player ESP ──────────────────────────────────
local T1=Window:CreateTab("👁  Player ESP",4483362458)
T1:CreateSection("Visibility")
T1:CreateToggle({Name="Enable Player ESP",CurrentValue=false,Flag="E_ESP",Callback=function(v) S.ESPEnabled=v; if not v then for _,o in pairs(ESPObjects) do HideESP(o) end end end})
T1:CreateToggle({Name="Health Bars",  CurrentValue=false,Flag="E_HP", Callback=function(v)S.ESPHealthBars=v end})
T1:CreateToggle({Name="Tracers",      CurrentValue=false,Flag="E_TR", Callback=function(v)S.ESPTracers=v end})
T1:CreateToggle({Name="Skeleton",     CurrentValue=false,Flag="E_SK", Callback=function(v)S.ESPSkeleton=v end})
T1:CreateToggle({Name="Names",        CurrentValue=true, Flag="E_NM", Callback=function(v)S.ESPNames=v end})
T1:CreateToggle({Name="Distance",     CurrentValue=true, Flag="E_DT", Callback=function(v)S.ESPDistance=v end})
T1:CreateToggle({Name="Weapon Label", CurrentValue=true, Flag="E_WP", Callback=function(v)S.ESPWeapon=v end})
T1:CreateToggle({Name="Show Box",     CurrentValue=true, Flag="E_BOX",Callback=function(v)S.ESPBoxEnabled=v end})
T1:CreateToggle({Name="Fill Box",     CurrentValue=true, Flag="E_FIL",Callback=function(v)S.ESPFillBox=v end})
T1:CreateToggle({Name="Corner Box",   CurrentValue=false,Flag="E_CRN",Callback=function(v)S.ESPCornerBox=v end})
T1:CreateToggle({Name="Team Check",   CurrentValue=false,Flag="E_TM", Callback=function(v)S.ESPTeamCheck=v end})
T1:CreateSection("Colour")
T1:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="E_RBW",Callback=function(v)S.ESPRainbow=v end})
T1:CreateColorPicker({Name="Box Color",Color=Color3.fromRGB(220,80,80),Flag="E_COL",Callback=function(v)S.BoxColor=v end})
T1:CreateSection("Range")
T1:CreateSlider({Name="Text Size",   Range={10,22},  Increment=1, Suffix=" px",   CurrentValue=14, Flag="E_TS",Callback=function(v)S.ESPTextSize=v end})
T1:CreateSlider({Name="Max Distance",Range={50,2000},Increment=50,Suffix=" studs",CurrentValue=500,Flag="E_MD",Callback=function(v)S.ESPMaxDist=v end})

-- ── TAB 2: AI ESP ──────────────────────────────────────
local T2=Window:CreateTab("🤖  AI ESP",4483362458)
T2:CreateSection("AI / NPC Detection")
T2:CreateToggle({Name="Enable AI ESP",CurrentValue=false,Flag="AI_ON",Callback=function(v) S.AIESPEnabled=v; if not v then for m in pairs(AIESPObjects) do KillAIESP(m) end end end})
T2:CreateToggle({Name="Names",  CurrentValue=true, Flag="AI_NM",Callback=function(v)S.AIESPNames=v end})
T2:CreateToggle({Name="Health", CurrentValue=true, Flag="AI_HP",Callback=function(v)S.AIESPHealth=v end})
T2:CreateToggle({Name="Tracers",CurrentValue=false,Flag="AI_TR",Callback=function(v)S.AIESPTracers=v end})
T2:CreateSection("Colour")
T2:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="AI_RBW",Callback=function(v)S.AIESPRainbow=v end})
T2:CreateColorPicker({Name="Box Color",Color=Color3.fromRGB(255,160,30),Flag="AI_COL",Callback=function(v)S.AIBoxColor=v end})
T2:CreateSection("Range")
T2:CreateSlider({Name="Max Distance",Range={50,1500},Increment=25,Suffix=" studs",CurrentValue=400,Flag="AI_MD",Callback=function(v)S.AIESPMaxDist=v end})
T2:CreateSection("AI Aimbot")
T2:CreateToggle({Name="Enable AI Aimbot",CurrentValue=false,Flag="AA_ON",Callback=function(v) S.AIAimbotEnabled=v; if not v then AILockDot.Visible=false; aiLockedTarget=nil end end})
T2:CreateDropdown({Name="Aim Mode",Options={"Smooth","Blatant","Instant"},CurrentOption={"Smooth"},Flag="AA_MODE",Callback=function(v)S.AIAimbotMode=v[1] or "Smooth" end})
T2:CreateDropdown({Name="Aim Key",Options={"MouseButton2","C","Q","E","F"},CurrentOption={"MouseButton2"},Flag="AA_KEY",Callback=function(v)S.AIAimbotKey=v[1] or "MouseButton2" end})
T2:CreateDropdown({Name="Target Part",Options={"Head","HumanoidRootPart","UpperTorso","Torso"},CurrentOption={"Head"},Flag="AA_PART",Callback=function(v)S.AIAimbotPart=v[1] or "Head"; aiLockedTarget=nil end})
T2:CreateToggle({Name="Lock-On",CurrentValue=false,Flag="AA_LOCK",Callback=function(v)S.AIAimbotLock=v; aiLockedTarget=nil end})
T2:CreateSlider({Name="Smooth Speed",Range={1,25},Increment=1,CurrentValue=5,Flag="AA_SS",Callback=function(v)S.AIAimbotSmooth=0.025+v*0.014 end})
T2:CreateSlider({Name="Snap Speed",Range={30,99},Increment=1,Suffix="%",CurrentValue=55,Flag="AA_BS",Callback=function(v)S.AIAimbotBlatant=v/100 end})
T2:CreateSlider({Name="FOV Radius",Range={20,700},Increment=5,Suffix=" px",CurrentValue=150,Flag="AA_FOV",Callback=function(v)S.AIAimbotFOV=v end})
T2:CreateToggle({Name="Show FOV Circle",CurrentValue=true,Flag="AA_FOVV",Callback=function(v)S.AIFOVVisible=v end})
T2:CreateColorPicker({Name="FOV Color",Color=Color3.fromRGB(255,160,30),Flag="AA_FOVC",Callback=function(v)S.AIFOVColor=v; AIFOVCircle.Color=v end})

-- ── TAB 3: Loot ESP ────────────────────────────────────
local T3=Window:CreateTab("💎  Loot ESP",4483362458)
T3:CreateSection("Master")
T3:CreateToggle({Name="Enable Loot ESP",CurrentValue=false,Flag="L_ON",Callback=function(v) S.LootESPEnabled=v; if not v then for i in pairs(LootESPObjects) do _LootRemove(i) end end end})
T3:CreateSlider({Name="Max Distance",Range={50,1000},Increment=25,Suffix=" studs",CurrentValue=300,Flag="L_MD",Callback=function(v)S.LootMaxDist=v end})
T3:CreateSlider({Name="Label Size",  Range={8,18},   Increment=1, Suffix=" px",   CurrentValue=12, Flag="L_TS",Callback=function(v)S.LootTextSize=v end})
T3:CreateSection("Item Filters")
T3:CreateToggle({Name="🔑 Keys",      CurrentValue=true, Flag="LF_K", Callback=function(v)S.LootFilter.Keys=v end})
T3:CreateToggle({Name="💀 Bodies",    CurrentValue=true, Flag="LF_B", Callback=function(v)S.LootFilter.Bodies=v end})
T3:CreateToggle({Name="🔫 Weapons",   CurrentValue=true, Flag="LF_W", Callback=function(v)S.LootFilter.Weapons=v end})
T3:CreateToggle({Name="🔹 Ammo",      CurrentValue=true, Flag="LF_A", Callback=function(v)S.LootFilter.Ammo=v end})
T3:CreateToggle({Name="💊 Medical",   CurrentValue=true, Flag="LF_M", Callback=function(v)S.LootFilter.Medical=v end})
T3:CreateToggle({Name="💎 Valuables", CurrentValue=true, Flag="LF_V", Callback=function(v)S.LootFilter.Valuables=v end})
T3:CreateToggle({Name="📦 Containers",CurrentValue=true, Flag="LF_C", Callback=function(v)S.LootFilter.Containers=v end})
T3:CreateToggle({Name="🛡 Armor",     CurrentValue=true, Flag="LF_AR",Callback=function(v)S.LootFilter.Armor=v end})
T3:CreateToggle({Name="💣 Explosives",CurrentValue=true, Flag="LF_EX",Callback=function(v)S.LootFilter.Explosives=v end})
T3:CreateToggle({Name="🔧 Tools",     CurrentValue=true, Flag="LF_TL",Callback=function(v)S.LootFilter.Tools=v end})
T3:CreateToggle({Name="· Other",      CurrentValue=false,Flag="LF_O", Callback=function(v)S.LootFilter.Other=v end})

-- ── TAB 4: Exfil ESP ───────────────────────────────────
local T4=Window:CreateTab("🚁  Exfil ESP",4483362458)
T4:CreateSection("Extraction Zone")
T4:CreateToggle({Name="Enable Exfil ESP",CurrentValue=false,Flag="X_ON",Callback=function(v)
    S.ExfilESPEnabled=v
    if not v then
        for i in pairs(ExfilESPObjects) do KillExfilESP(i) end
        ExfilArrow.shaft.Visible=false;ExfilArrow.head1.Visible=false
        ExfilArrow.head2.Visible=false;ExfilArrow.label.Visible=false
    end
end})
T4:CreateToggle({Name="Show Distance",   CurrentValue=true, Flag="X_DT", Callback=function(v)S.ExfilShowDist=v end})
T4:CreateToggle({Name="Pulse Ring",      CurrentValue=true, Flag="X_PLS",Callback=function(v)S.ExfilPulse=v end})
T4:CreateToggle({Name="Off-Screen Arrow",CurrentValue=true, Flag="X_ARR",Callback=function(v)S.ExfilArrow=v end})
T4:CreateToggle({Name="🌈 Rainbow",CurrentValue=false,Flag="X_RBW",Callback=function(v)S.ExfilRainbow=v end})
T4:CreateColorPicker({Name="Exfil Color",Color=Color3.fromRGB(80,255,140),Flag="X_COL",Callback=function(v)S.ExfilColor=v end})
T4:CreateSlider({Name="Max Distance",Range={100,5000},Increment=100,Suffix=" studs",CurrentValue=2000,Flag="X_MD",Callback=function(v)S.ExfilMaxDist=v end})

-- ── TAB 5: Aimbot ──────────────────────────────────────
local T5=Window:CreateTab("🎯  Aimbot",4483362458)
T5:CreateSection("Enable & Mode")
T5:CreateToggle({Name="Enable Aimbot",CurrentValue=false,Flag="A_ON",Callback=function(v) S.AimbotEnabled=v; if not v then LockDot.Visible=false; lockedTarget=nil end end})
T5:CreateDropdown({Name="Aim Mode",Options={"Smooth","Blatant","Instant"},CurrentOption={"Smooth"},Flag="A_MODE",Callback=function(v)S.AimbotMode=v[1] or "Smooth" end})
T5:CreateDropdown({Name="Aim Key",Options={"MouseButton2","C","Q","E","F"},CurrentOption={"MouseButton2"},Flag="A_KEY",Callback=function(v)S.AimKey=v[1] or "MouseButton2" end})
T5:CreateSection("Targeting")
T5:CreateToggle({Name="Team Check",     CurrentValue=false,Flag="A_TM",   Callback=function(v)S.TeamCheck=v end})
T5:CreateToggle({Name="Lock-On",        CurrentValue=false,Flag="A_LOCK", Callback=function(v)S.AimbotLock=v; lockedTarget=nil end})
T5:CreateToggle({Name="Trigger Bot",    CurrentValue=false,Flag="A_TRIG", Callback=function(v)S.TriggerBot=v end})
T5:CreateSlider({Name="Trig Delay",Range={0,200},Increment=5,Suffix=" ms",CurrentValue=0,Flag="A_TDLY",Callback=function(v)S.TrigDelay=v end})
T5:CreateDropdown({Name="Target Part",Options={"Head","HumanoidRootPart","UpperTorso","Torso"},CurrentOption={"Head"},Flag="A_PART",Callback=function(v)S.AimbotPart=v[1] or "Head"; lockedTarget=nil end})
T5:CreateSection("Smooth")
T5:CreateSlider({Name="Smooth Speed",Range={1,25},Increment=1,CurrentValue=5,Flag="A_SS",Callback=function(v)S.AimbotSmooth=0.025+v*0.014 end})
T5:CreateSection("Blatant")
T5:CreateSlider({Name="Snap Speed",Range={30,99},Increment=1,Suffix="%",CurrentValue=55,Flag="A_BS",Callback=function(v)S.AimbotBlatant=v/100 end})
T5:CreateSection("Prediction")
T5:CreateToggle({Name="Target Prediction",CurrentValue=false,Flag="A_PRD",Callback=function(v)S.AimbotPredict=v end})
T5:CreateSlider({Name="Strength",Range={1,10},Increment=1,CurrentValue=5,Flag="A_PRS",Callback=function(v)S.AimbotPredictStr=v/10 end})
T5:CreateSection("FOV")
T5:CreateSlider({Name="FOV Radius",Range={20,700},Increment=5,Suffix=" px",CurrentValue=150,Flag="A_FOV",Callback=function(v)S.AimbotFOV=v end})
T5:CreateToggle({Name="Show FOV Circle",CurrentValue=true,Flag="A_FOVV",Callback=function(v)S.FOVVisible=v end})
T5:CreateColorPicker({Name="FOV Color",Color=Color3.fromRGB(180,100,255),Flag="A_FOVC",Callback=function(v)S.FOVColor=v; FOVCircle.Color=v end})

-- ── TAB 6: Zoom ────────────────────────────────────────
local T6=Window:CreateTab("🔭  Zoom",4483362458)
T6:CreateSection("Scope Zoom")
T6:CreateToggle({Name="Enable Zoom",CurrentValue=false,Flag="Z_ON",Callback=function(v)
    S.ZoomEnabled=v
    if not v and S.ZoomActive then S.ZoomActive=false; CancelZoomTween(); Camera.FieldOfView=S.CameraFOV; ShowZoomOverlay(false) end
end})
T6:CreateDropdown({Name="Zoom Key",Options={"Z","X","V","F","G"},CurrentOption={"Z"},Flag="Z_KEY",Callback=function(v)S.ZoomKey=v[1] or "Z" end})
T6:CreateSlider({Name="Zoom FOV",Range={5,60},Increment=1,Suffix="°",CurrentValue=20,Flag="Z_FOV",Callback=function(v)S.ZoomFOV=v; if S.ZoomActive then SetCameraFOV(v,S.ZoomSmooth,0.10) end end})
T6:CreateSlider({Name="Zoom Speed",Range={5,30},Increment=1,CurrentValue=18,Flag="Z_SPD",Callback=function(v)S.ZoomSpeed=v/100 end})
T6:CreateToggle({Name="Smooth Transition",CurrentValue=true,Flag="Z_SM",Callback=function(v)S.ZoomSmooth=v end})
T6:CreateToggle({Name="Scope Overlay",CurrentValue=true,Flag="Z_OVL",Callback=function(v)S.ZoomOverlay=v; if not v then ShowZoomOverlay(false) end end})
T6:CreateColorPicker({Name="Overlay Color",Color=Color3.fromRGB(180,220,255),Flag="Z_OVC",Callback=function(v)S.ZoomOverlayColor=v end})

-- ── TAB 7: Combat ──────────────────────────────────────
local T7=Window:CreateTab("⚔️  Combat",4483362458)
T7:CreateSection("Recoil")
T7:CreateToggle({Name="No Recoil",CurrentValue=false,Flag="C_NR",Callback=function(v)S.NoRecoilEnabled=v; lastCamCF=nil end})
T7:CreateSlider({Name="Reduction %",Range={10,100},Increment=5,Suffix="%",CurrentValue=80,Flag="C_NRS",Callback=function(v)S.RecoilStrength=1-(v/100) end})
T7:CreateSection("Hitbox")
T7:CreateToggle({Name="Hitbox Expander",CurrentValue=false,Flag="C_HBX",Callback=function(v)S.HitboxExpander=v; StartHitboxExpander() end})
T7:CreateSlider({Name="Hitbox Size",Range={2,20},Increment=1,Suffix=" studs",CurrentValue=6,Flag="C_HBXS",Callback=function(v)S.HitboxSize=v end})

-- ── TAB 8: Visuals ─────────────────────────────────────
local T8=Window:CreateTab("🎨  Visuals",4483362458)
T8:CreateSection("Lighting")
T8:CreateToggle({Name="Fullbright", CurrentValue=false,Flag="V_FB", Callback=function(v)S.FullbrightEnabled=v;SetFullbright(v) end})
T8:CreateToggle({Name="Remove Fog", CurrentValue=false,Flag="V_FOG",Callback=function(v)S.NoFogEnabled=v;SetNoFog(v) end})
T8:CreateSection("Camera")
T8:CreateSlider({Name="Field of View",Range={50,120},Increment=1,Suffix="°",CurrentValue=70,Flag="V_FOV",Callback=function(v)
    S.CameraFOV=v; if not S.ZoomActive then CancelZoomTween(); Camera.FieldOfView=v end
end})
T8:CreateSection("Crosshair")
T8:CreateToggle({Name="Enable Crosshair",CurrentValue=false,Flag="V_CH",Callback=function(v)
    S.CrosshairEnabled=v; if not v then HideAllCrosshair(); _prevStyle="" end
end})
T8:CreateDropdown({Name="Style",Options={"Plus","X","Dot","Circle","T-Shape","KovaaK","Sniper","Diamond","Bracket","Happy Face"},CurrentOption={"Plus"},Flag="V_CHS",Callback=function(v)
    S.CrosshairStyle=v[1] or "Plus"
end})
T8:CreateToggle({Name="🌈 Rainbow", CurrentValue=false,Flag="V_CHRBW",Callback=function(v)S.CrosshairRainbow=v end})
T8:CreateToggle({Name="🔄 Spinning",CurrentValue=false,Flag="V_CHSP", Callback=function(v)S.CrosshairSpin=v; if not v then _chAngle=0 end end})
T8:CreateSlider({Name="Spin Speed", Range={10,720},Increment=10,Suffix="°/s",CurrentValue=90,Flag="V_CHSS",Callback=function(v)S.CrosshairSpinSpeed=v end})
T8:CreateSlider({Name="Size",       Range={4,60},  Increment=1, Suffix=" px",CurrentValue=12,Flag="V_SZ",  Callback=function(v)S.CrosshairSize=v end})
T8:CreateSlider({Name="Gap",        Range={0,30},  Increment=1, Suffix=" px",CurrentValue=4, Flag="V_GAP", Callback=function(v)S.CrosshairGap=v end})
T8:CreateSlider({Name="Thickness",  Range={1,6},   Increment=1, Suffix=" px",CurrentValue=2, Flag="V_TH",  Callback=function(v)S.CrosshairThick=v end})
T8:CreateSlider({Name="Opacity",    Range={0,90},  Increment=5, Suffix="%",  CurrentValue=0, Flag="V_OP",  Callback=function(v)S.CrosshairOpacity=v/100 end})
T8:CreateColorPicker({Name="Color",Color=Color3.fromRGB(255,255,255),Flag="V_COL",Callback=function(v)S.CrosshairColor=v end})
T8:CreateSection("Hit Feedback")
T8:CreateToggle({Name="Hitmarker",CurrentValue=false,Flag="V_HM",Callback=function(v)S.HitmarkerEnabled=v end})
T8:CreateSection("Performance")
T8:CreateToggle({Name="FPS Display", CurrentValue=false,Flag="V_FPS",Callback=function(v)S.ShowFPS=v end})
T8:CreateToggle({Name="Ping Display",CurrentValue=false,Flag="V_PNG",Callback=function(v)S.ShowPing=v end})
T8:CreateSection("Decoration")
T8:CreateToggle({Name="Crystal Borders",CurrentValue=true,Flag="V_CRYS",Callback=function(v)
    for _,set in ipairs(ScreenCrystals) do for _,l in ipairs(set) do pcall(function()l.Visible=v end) end end
end})

-- ── TAB 9: Misc ────────────────────────────────────────
local T9=Window:CreateTab("🔧  Misc",4483362458)
T9:CreateSection("Server Tools")
T9:CreateButton({Name="Rejoin",Callback=function()
    Notify("TravHub","Rejoining...",2); task.wait(0.5)
    TeleportService:Teleport(game.PlaceId,LocalPlayer)
end})
T9:CreateButton({Name="Server Hop",Callback=function()
    Notify("TravHub","Hopping...",2); task.wait(0.5)
    local servers={}
    Safe(function()
        local data=HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
        for _,sv in ipairs(data.data or {}) do
            if sv.id~=game.JobId and sv.playing<sv.maxPlayers then tinsert(servers,sv.id) end
        end
    end)
    if #servers>0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId,servers[mrandom(1,#servers)],LocalPlayer)
    else
        Notify("TravHub","No open servers found.",4); TeleportService:Teleport(game.PlaceId,LocalPlayer)
    end
end})
T9:CreateSection("Utilities")
T9:CreateButton({Name="Copy Player List",Callback=function()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do tinsert(list,sfmt("%s (%s)",p.Name,p.DisplayName)) end
    if type(setclipboard)=="function" then
        setclipboard(table.concat(list,"\n")); Notify("TravHub","Copied "..#list.." players.",3)
    else print(table.concat(list,"\n")); Notify("TravHub","Printed "..#list.." players to console.",3) end
end})
T9:CreateButton({Name="Log Remote Events",Callback=function()
    local n=0
    for _,v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then print("[TravHub] "..v:GetFullName()); n=n+1 end
    end
    Notify("TravHub","Logged "..n.." remotes.",4)
end})
T9:CreateButton({Name="Kill Particles",Callback=function()
    local n=0; local myChar=LocalPlayer.Character or Instance.new("Folder")
    for _,v in ipairs(Workspace:GetDescendants()) do
        if (v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles"))
        and not v:IsDescendantOf(myChar) then pcall(function()v.Enabled=false end); n=n+1 end
    end
    Notify("TravHub","Disabled "..n.." emitters.",3)
end})
T9:CreateSection("About")
T9:CreateLabel("TravHub v3.9  ·  Crystal Edition  ·  Clean Build")
T9:CreateLabel("Fixed crosshair  ·  No Trap/Survive tabs  ·  Xeno-compatible")

-- ══════════════════════════════════════════
--  BOOTSTRAP
-- ══════════════════════════════════════════
task.defer(function() _AIBootstrap(); _LootBootstrap(); _ExfilBootstrap() end)
Rayfield:LoadConfiguration()
task.wait(0.3)
Notify("TravHub v3.9 ✦","Clean Build loaded successfully 🔮",5)
ShowInfo("Hub fully loaded.")

-- end xpcall wrapper
end, function(err) return debug.traceback(err,2) end)

if not _ok then
    warn("[TravHub FATAL CRASH]\n"..tostring(_err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title="⚠ TravHub Crashed",
            Text=tostring(_err):sub(1,140),
            Duration=15,
        })
    end)
end
