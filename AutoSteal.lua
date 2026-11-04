local function fatal(msg)
    warn(msg)
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.ResetOnSpawn = false
        local okp = pcall(function() g.Parent = game:GetService("CoreGui") end)
        if not okp or not g.Parent then
            g.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        end
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0.8, 0, 0, 140)
        t.Position = UDim2.new(0.1, 0, 0, 10)
        t.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
        t.TextColor3 = Color3.new(1, 1, 1)
        t.TextWrapped = true
        t.TextSize = 14
        t.Text = tostring(msg)
        t.Parent = g
    end)
end

local ok, err = xpcall(function()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.AutoStealCleanup then pcall(env.AutoStealCleanup) end
if env.AutoRowCleanup then pcall(env.AutoRowCleanup) end

local alive, running, runId = true, false, 0
local pickupOn, trainOn = true, false
local stabOn, onlyList = true, false
local keepY, syncY, baseY = true, true, nil
local afkOn, afkCount = true, 0
local skipGuardOn, skipCatchOn, logOn = false, false, false
local startClock = os.clock()
local safePos, frontPos
local zones, selected, zoneCounter = {}, nil, 0
local conns = {}

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "AutoStealUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local host
if gethui then pcall(function() host = gethui() end) end
if not host then
    local ok2 = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if ok2 then host = gui.Parent end
end
gui.Parent = host or lp:WaitForChild("PlayerGui")

local function round(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = o
end

local cam = workspace.CurrentCamera
local vh = cam and cam.ViewportSize.Y or 420
local FULL_H = clamp(vh - 40, 220, 520)

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, FULL_H)
main.Position = UDim2.new(0, 20, 0, 10)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
round(main, 10)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 32)
bar.BackgroundColor3 = Color3.fromRGB(40, 40, 54)
bar.BorderSizePixel = 0
bar.Parent = main
round(bar, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Training + Steal + Egg"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local function barButton(text, xOffset, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 22)
    b.Position = UDim2.new(1, xOffset, 0, 5)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Parent = bar
    round(b, 6)
    return b
end
local minBtn = barButton("-", -62, Color3.fromRGB(90, 90, 110))
local closeBtn = barButton("X", -32, Color3.fromRGB(190, 60, 60))

local body = Instance.new("ScrollingFrame")
body.Size = UDim2.new(1, 0, 1, -32)
body.Position = UDim2.new(0, 0, 0, 32)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 12)
pad.Parent = body

local order = 0
local function nxt() order += 1 return order end

local function mkBtn(p, text, color)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = p
    round(b, 6)
    return b
end

local function mkRow(h)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, h or 32)
    r.BackgroundTransparency = 1
    r.LayoutOrder = nxt()
    r.Parent = body
    return r
end

local function mkHeader(text)
    local r = mkRow(20)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(120, 170, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
end

local function twoBtns(textA, colA, textB, colB)
    local r = mkRow()
    local a = mkBtn(r, textA, colA)
    a.Size = UDim2.new(0.5, -3, 1, 0)
    local b = mkBtn(r, textB, colB)
    b.Size = UDim2.new(0.5, -3, 1, 0)
    b.Position = UDim2.new(0.5, 3, 0, 0)
    return a, b
end

local function mkField(label, default)
    local r = mkRow(28)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(0.5, 0, 1, 0)
    t.Position = UDim2.new(0.5, 0, 0, 0)
    t.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    t.Text = default
    t.TextColor3 = Color3.new(1, 1, 1)
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.ClearTextOnFocus = false
    t.Parent = r
    round(t, 6)
    return t
end

local COL_BLUE = Color3.fromRGB(60, 120, 200)
local COL_GREY = Color3.fromRGB(55, 55, 70)
local COL_RED = Color3.fromRGB(180, 40, 40)
local COL_GREEN = Color3.fromRGB(40, 150, 60)

-- ===== Menu AUTO TRAINING =====
mkHeader("AUTO TRAINING")

local trainBtn = mkBtn(mkRow(38), "Auto Training: OFF", COL_RED)
trainBtn.Size = UDim2.new(1, 0, 1, 0)
trainBtn.TextSize = 14

local trainRow = mkRow(18)
local trainStatus = Instance.new("TextLabel")
trainStatus.Size = UDim2.new(1, 0, 1, 0)
trainStatus.BackgroundTransparency = 1
trainStatus.TextColor3 = Color3.fromRGB(200, 200, 210)
trainStatus.Font = Enum.Font.Gotham
trainStatus.TextSize = 12
trainStatus.TextXAlignment = Enum.TextXAlignment.Left
trainStatus.Text = "Boost terkirim: 0"
trainStatus.Parent = trainRow

-- ===== Menu ANTI AFK =====
mkHeader("ANTI AFK")

local afkBtn = mkBtn(mkRow(32), "Anti-AFK: ON", COL_GREEN)
afkBtn.Size = UDim2.new(1, 0, 1, 0)

local afkRow = mkRow(18)
local afkStatus = Instance.new("TextLabel")
afkStatus.Size = UDim2.new(1, 0, 1, 0)
afkStatus.BackgroundTransparency = 1
afkStatus.TextColor3 = Color3.fromRGB(200, 200, 210)
afkStatus.Font = Enum.Font.Gotham
afkStatus.TextSize = 12
afkStatus.TextXAlignment = Enum.TextXAlignment.Left
afkStatus.Text = "Aktif 0:00:00 | Dicegah: 0"
afkStatus.Parent = afkRow

-- ===== Menu CONFIG =====
mkHeader("CONFIG")

local cfgNameBox = mkField("Nama config", "default")
local btnSave, btnLoad = twoBtns("Save Config", COL_BLUE, "Load Config", COL_BLUE)
local btnList, btnAuto = twoBtns("Daftar Config", COL_GREY, "Auto-load: OFF", COL_GREY)

-- ===== Menu AUTO STEAL =====
mkHeader("AUTO STEAL + PICKUP EGG")

local btnAdd, btnDel = twoBtns("Simpan Zona", COL_BLUE, "Hapus Zona", COL_RED)

local zoneBox = Instance.new("Frame")
zoneBox.Size = UDim2.new(1, 0, 0, 0)
zoneBox.AutomaticSize = Enum.AutomaticSize.Y
zoneBox.BackgroundTransparency = 1
zoneBox.LayoutOrder = nxt()
zoneBox.Parent = body
local zl = Instance.new("UIListLayout")
zl.Padding = UDim.new(0, 4)
zl.Parent = zoneBox

local btnFront, btnSafe = twoBtns("Set Depan", COL_BLUE, "Set Aman", COL_BLUE)

local speedBox = mkField("Speed (studs/dtk)", "60")
local yOffsetBox = mkField("Offset Y (studs)", "0")
local syncWaitBox = mkField("Tunggu di depan sblm steal (dtk)", "2")
local afterStealBox = mkField("Jeda setelah steal (dtk)", "3")
local frontBox = mkField("Tunggu di depan (dtk)", "1.5")
local radiusBox = mkField("Radius cari prompt", "100")
local stealBox = mkField("Maks steal / siklus", "1")
local filterBox = mkField("Teks steal (opsional)", "")
local priorityBox = mkField("Urutan rarity (pertama = utama)", "mythic,legendary,epic,rare")

local onlyBtn = mkBtn(mkRow(30), "Hanya rarity di daftar: OFF", COL_GREY)
onlyBtn.Size = UDim2.new(1, 0, 1, 0)

local pickTextBox = mkField("Teks pickup egg", "pick up")
local maxPickBox = mkField("Maks pickup / siklus", "2")
local holdBox = mkField("Tahan pickup (dtk, 0=auto)", "0")

local pickBtn = mkBtn(mkRow(32), "Pickup Egg: ON", COL_GREEN)
pickBtn.Size = UDim2.new(1, 0, 1, 0)

local stabBtn = mkBtn(mkRow(32), "Stabilizer gerak: ON", COL_GREEN)
stabBtn.Size = UDim2.new(1, 0, 1, 0)

local keepYBtn = mkBtn(mkRow(32), "Jaga ketinggian Y: ON", COL_GREEN)
keepYBtn.Size = UDim2.new(1, 0, 1, 0)

local syncBtn = mkBtn(mkRow(32), "Sinkron tinggi di Depan: ON", COL_GREEN)
syncBtn.Size = UDim2.new(1, 0, 1, 0)

mkHeader("SKIP CINEMATIC (eksperimental)")

local guardKeyBox = mkField("Kata kunci guardian", "guardian,entrance")
local catchKeyBox = mkField("Kata kunci catch", "catch,cinematic")

local skipGuardBtn = mkBtn(mkRow(32), "Skip Guardian Entrance: OFF", COL_GREY)
skipGuardBtn.Size = UDim2.new(1, 0, 1, 0)

local skipCatchBtn = mkBtn(mkRow(32), "Skip Catch Cinematic: OFF", COL_GREY)
skipCatchBtn.Size = UDim2.new(1, 0, 1, 0)

local logBtn = mkBtn(mkRow(32), "Log GUI dan kamera: OFF", COL_GREY)
logBtn.Size = UDim2.new(1, 0, 1, 0)

local logRow = mkRow(110)
local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, 0, 1, 0)
logLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
logLabel.TextColor3 = Color3.fromRGB(190, 230, 190)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 10
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.ClipsDescendants = true
logLabel.Text = "(log kosong)"
logLabel.Parent = logRow
round(logLabel, 6)

local btnCopyLog, btnClearLog = twoBtns("Salin Log", COL_BLUE, "Hapus Log", COL_GREY)

local liftBtn = mkBtn(mkRow(32), "Naikkan posisi +5 Y (darurat)", COL_GREY)
liftBtn.Size = UDim2.new(1, 0, 1, 0)

local scanBtn = mkBtn(mkRow(32), "Scan Prompt di Sekitar Saya", COL_GREY)
scanBtn.Size = UDim2.new(1, 0, 1, 0)

local toggle = mkBtn(mkRow(40), "Auto Steal: OFF", COL_RED)
toggle.Size = UDim2.new(1, 0, 1, 0)
toggle.TextSize = 16

local infoRow = mkRow(18)
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 1, 0)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(200, 200, 210)
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.Parent = infoRow

local statusRow = mkRow(36)
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 1, 0)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 220, 120)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.Text = "Siap"
status.Parent = statusRow

local function refresh()
    for i, z in ipairs(zones) do
        z.btn.BackgroundColor3 = (i == selected) and COL_BLUE or COL_GREY
    end
    info.Text = string.format("Zona: %d | Depan: %s | Aman: %s",
        #zones, frontPos and "OK" or "-", safePos and "OK" or "-")
end
refresh()

-- ===== Drag =====
do
    local dragging, dragStart, startPos
    table.insert(conns, bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))
    table.insert(conns, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

-- ===== Setter toggle (dipakai tombol dan load config) =====
local function setPickup(on)
    pickupOn = on
    pickBtn.Text = "Pickup Egg: " .. (on and "ON" or "OFF")
    pickBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function setOnly(on)
    onlyList = on
    onlyBtn.Text = "Hanya rarity di daftar: " .. (on and "ON" or "OFF")
    onlyBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function setStab(on)
    stabOn = on
    stabBtn.Text = "Stabilizer gerak: " .. (on and "ON" or "OFF")
    stabBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
    if not on then
        local c = lp.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end
    end
end

local function setKeepY(on)
    keepY = on
    keepYBtn.Text = "Jaga ketinggian Y: " .. (on and "ON" or "OFF")
    keepYBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function setSyncY(on)
    syncY = on
    syncBtn.Text = "Sinkron tinggi di Depan: " .. (on and "ON" or "OFF")
    syncBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function setAfk(on)
    afkOn = on
    afkBtn.Text = "Anti-AFK: " .. (on and "ON" or "OFF")
    afkBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

-- ===== Anti-AFK =====
do
    local VU
    pcall(function() VU = game:GetService("VirtualUser") end)
    table.insert(conns, lp.Idled:Connect(function()
        if not afkOn or not VU then return end
        local okv = pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
        if okv then afkCount += 1 end
    end))
    if not VU then
        afkStatus.Text = "VirtualUser tidak tersedia"
    end
end

task.spawn(function()
    while alive do
        local s = math.floor(os.clock() - startClock)
        afkStatus.Text = string.format("Aktif %d:%02d:%02d | Dicegah: %d",
            math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60, afkCount)
        task.wait(1)
    end
end)

afkBtn.Activated:Connect(function() setAfk(not afkOn) end)

-- ===== Skip cinematic (Guardian Entrance / Catch) =====
-- Cara kerja: sembunyikan GUI cinematic berdasarkan kata kunci pada namanya,
-- dan kembalikan kamera ke mode normal kalau game memakainya untuk cinematic.
local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")

-- Log ditampilkan di kotak log dalam menu (dan juga di console)
local logLines = {}
local function logLine(s)
    print(s)
    logLines[#logLines + 1] = s
    if #logLines > 80 then table.remove(logLines, 1) end
    local from = math.max(1, #logLines - 7)
    logLabel.Text = table.concat(logLines, "\n", from, #logLines)
end

local function setSkipGuard(on)
    skipGuardOn = on
    skipGuardBtn.Text = "Skip Guardian Entrance: " .. (on and "ON" or "OFF")
    skipGuardBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function setSkipCatch(on)
    skipCatchOn = on
    skipCatchBtn.Text = "Skip Catch Cinematic: " .. (on and "ON" or "OFF")
    skipCatchBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
end

local function splitKeys(s)
    local l = {}
    for w in string.gmatch(tostring(s):lower(), "[^,]+") do
        w = w:match("^%s*(.-)%s*$")
        if w ~= "" then l[#l + 1] = w end
    end
    return l
end

local function nameMatches(name, keys)
    name = tostring(name):lower()
    for _, k in ipairs(keys) do
        if name:find(k, 1, true) then return true end
    end
    return false
end

local function currentKeys()
    return splitKeys(guardKeyBox.Text), splitKeys(catchKeyBox.Text)
end

local function cinematicHit(inst, gk, ck)
    if skipGuardOn and nameMatches(inst.Name, gk) then return true end
    if skipCatchOn and nameMatches(inst.Name, ck) then return true end
    return false
end

local function hideInst(inst)
    if inst:IsA("ScreenGui") then
        inst.Enabled = false
    elseif inst:IsA("GuiObject") then
        inst.Visible = false
    end
end

local function isTopLevel(inst)
    return inst:IsA("ScreenGui")
        or (inst:IsA("GuiObject") and inst.Parent ~= nil and inst.Parent:IsA("ScreenGui"))
end

local function shortName(inst)
    local n = inst.Name
    local p = inst.Parent
    if p and p ~= pg then n = p.Name .. "/" .. n end
    return n .. " (" .. inst.ClassName .. ")"
end

-- Pantau ScreenGui (Enabled) dan frame tingkat atas (Visible): dicatat di log saat menyala
local watched = setmetatable({}, { __mode = "k" })
local function watch(o)
    if watched[o] then return end
    if o:IsA("ScreenGui") then
        watched[o] = true
        o:GetPropertyChangedSignal("Enabled"):Connect(function()
            if alive and logOn and o.Enabled then logLine("[nyala] " .. o.Name) end
        end)
    elseif o:IsA("GuiObject") then
        watched[o] = true
        o:GetPropertyChangedSignal("Visible"):Connect(function()
            if alive and logOn and o.Visible then logLine("[tampil] " .. shortName(o)) end
        end)
    end
end

for _, g in ipairs(pg:GetChildren()) do
    if g:IsA("ScreenGui") and g ~= gui then
        watch(g)
        for _, f in ipairs(g:GetChildren()) do watch(f) end
    end
end

-- GUI yang baru muncul
table.insert(conns, pg.DescendantAdded:Connect(function(inst)
    if not (inst:IsA("ScreenGui") or inst:IsA("GuiObject")) then return end
    if inst == gui or inst:IsDescendantOf(gui) then return end
    local top = isTopLevel(inst)
    if top then watch(inst) end
    if logOn and top then logLine("[baru] " .. shortName(inst)) end
    if skipGuardOn or skipCatchOn then
        local gk, ck = currentKeys()
        if cinematicHit(inst, gk, ck) then
            task.defer(function()
                pcall(hideInst, inst)
                status.Text = "Skip: " .. inst.Name
            end)
        end
    end
end))

-- GUI yang sudah ada tapi dinyalakan game saat cinematic
task.spawn(function()
    while alive do
        if skipGuardOn or skipCatchOn then
            local gk, ck = currentKeys()
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= gui then
                    if g.Enabled and cinematicHit(g, gk, ck) then
                        pcall(hideInst, g)
                        status.Text = "Skip: " .. g.Name
                    end
                    if g.Enabled then
                        for _, f in ipairs(g:GetChildren()) do
                            if f:IsA("GuiObject") and f.Visible and cinematicHit(f, gk, ck) then
                                pcall(hideInst, f)
                                status.Text = "Skip: " .. f.Name
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Kamera cinematic: kembalikan ke kamera normal
do
    local lastCam
    table.insert(conns, RunService.RenderStepped:Connect(function()
        local c = workspace.CurrentCamera
        if not c then return end
        if logOn and c.CameraType ~= lastCam then
            lastCam = c.CameraType
            logLine("[kamera] " .. (tostring(c.CameraType):gsub("Enum.CameraType.", "")))
        end
        if (skipGuardOn or skipCatchOn) and c.CameraType == Enum.CameraType.Scriptable then
            local ch = lp.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum then
                c.CameraSubject = hum
                c.CameraType = Enum.CameraType.Custom
            end
        end
    end))
end

skipGuardBtn.Activated:Connect(function() setSkipGuard(not skipGuardOn) end)
skipCatchBtn.Activated:Connect(function() setSkipCatch(not skipCatchOn) end)

logBtn.Activated:Connect(function()
    logOn = not logOn
    logBtn.Text = "Log GUI dan kamera: " .. (logOn and "ON" or "OFF")
    logBtn.BackgroundColor3 = logOn and COL_GREEN or COL_GREY
    if logOn then
        logLine("== Log aktif. Picu cinematic sekarang ==")
        status.Text = "Log aktif: lihat kotak log di menu"
    else
        status.Text = "Log dimatikan"
    end
end)

btnCopyLog.Activated:Connect(function()
    if not setclipboard then
        status.Text = "Executor ini tidak mendukung setclipboard"
        return
    end
    local okc = pcall(setclipboard, table.concat(logLines, "\n"))
    status.Text = okc and ("Log disalin (" .. #logLines .. " baris)") or "Gagal menyalin log"
end)

btnClearLog.Activated:Connect(function()
    logLines = {}
    logLabel.Text = "(log kosong)"
end)

-- ===== Auto Training =====
local boostRemote
local trainCount, trainLast = 0, nil

local function attr(name)
    local v = lp:GetAttribute(name)
    if v == nil and lp.Character then
        v = lp.Character:GetAttribute(name)
    end
    return v
end

task.spawn(function()
    local lastText = ""
    while alive do
        if trainOn then
            if not boostRemote then
                local r = RS:FindFirstChild("Remotes")
                boostRemote = r and r:FindFirstChild("RequestRowingBoost")
            end
            local state = attr("State")
            local window = attr("RowBoostWindow")
            if boostRemote and state == "Training" and type(window) == "number" then
                if window ~= trainLast then
                    trainLast = window
                    local okf = pcall(function()
                        boostRemote:FireServer({ window = window })
                    end)
                    if okf then trainCount += 1 end
                end
            else
                trainLast = nil
            end
            local txt = string.format("State: %s | Boost: %d", tostring(state), trainCount)
            if not boostRemote then txt = "Remote boost belum ditemukan" end
            if txt ~= lastText then
                lastText = txt
                trainStatus.Text = txt
            end
        end
        task.wait(0.05)
    end
end)

trainBtn.Activated:Connect(function()
    trainOn = not trainOn
    trainLast = nil
    trainBtn.Text = "Auto Training: " .. (trainOn and "ON" or "OFF")
    trainBtn.BackgroundColor3 = trainOn and COL_GREEN or COL_RED
    if not trainOn then
        trainStatus.Text = "Boost terkirim: " .. trainCount
    end
end)

-- ===== Stabilizer =====
table.insert(conns, RunService.Stepped:Connect(function()
    if stabOn and running then
        local h = getHRP()
        if h then
            h.AssemblyLinearVelocity = Vector3.zero
            h.AssemblyAngularVelocity = Vector3.zero
        end
    end
end))

local function setStand(on)
    if not stabOn then return end
    local c = lp.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = on end) end
end

-- ===== Gerak =====
local function alivePath(id)
    return alive and running and id == runId
end

local function pause(t, id)
    local t0 = os.clock()
    while alivePath(id) and os.clock() - t0 < t do
        task.wait(0.05)
    end
    return alivePath(id)
end

-- exact = true: pakai target apa adanya (tanpa kunci Y / offset), dipakai untuk menyamakan tinggi
local function moveToRaw(target, speed, stopDist, id, exact)
    stopDist = stopDist or 1.5
    if not exact then
        local yOff = tonumber(yOffsetBox.Text) or 0
        if keepY and baseY then
            target = Vector3.new(target.X, baseY + yOff, target.Z)
        else
            target = target + Vector3.new(0, yOff, 0)
        end
    end
    while alivePath(id) do
        local hrp = getHRP()
        if not hrp then return false end
        local cur = hrp.Position
        local delta = target - cur
        local dist = delta.Magnitude
        if dist <= stopDist + 0.05 then return true end
        local dt = RunService.Heartbeat:Wait()
        local step = math.min(dist - stopDist, speed * dt)
        local newPos = cur + delta.Unit * step
        local flat = Vector3.new(delta.X, 0, delta.Z)
        if flat.Magnitude > 0.01 then
            hrp.CFrame = CFrame.lookAt(newPos, newPos + flat)
        else
            hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    return false
end

local function moveTo(target, speed, stopDist, id, exact)
    setStand(true)
    local r = moveToRaw(target, speed, stopDist, id, exact)
    setStand(false)
    return r
end

-- Selalu jalan ke titik Depan, tunggu agar tinggi kapal menyesuaikan, baru ke zona steal
local function syncHeight(speed, id)
    local h = getHRP()
    if not h then return false end

    status.Text = "Ke depan dulu"
    baseY = h.Position.Y -- tahan tinggi saat ini selama berjalan ke depan
    if not moveTo(frontPos, speed, 1.5, id) then return false end

    -- Opsional: samakan tinggi ke Y titik Depan (hanya jika Jaga Y + Sinkron aktif)
    if keepY and syncY then
        baseY = frontPos.Y
        local yOff = tonumber(yOffsetBox.Text) or 0
        h = getHRP()
        if not h then return false end
        status.Text = "Menyamakan tinggi"
        local tgt = Vector3.new(h.Position.X, baseY + yOff, h.Position.Z)
        if not moveTo(tgt, math.min(speed, 20), 0.2, id, true) then return false end
    end

    -- Tunggu di depan supaya tinggi kapal sudah sesuai
    local w = clamp(tonumber(syncWaitBox.Text) or 2, 0, 10)
    status.Text = string.format("Tunggu di depan %.1f dtk", w)
    return pause(w, id)
end

-- ===== Prompt =====
local function promptPos(p)
    local part = p.Parent
    if not part then return nil end
    if part:IsA("BasePart") then
        return part.Position
    elseif part:IsA("Attachment") then
        return part.WorldPosition
    elseif part:IsA("Model") then
        return part:GetPivot().Position
    end
end

local function promptText(p)
    return (p.ActionText .. " " .. p.ObjectText):lower()
end

local function isPickup(p)
    local key = pickTextBox.Text:lower()
    if key == "" then return false end
    return promptText(p):find(key, 1, true) ~= nil
end

local function promptAlive(p)
    return p.Parent ~= nil and p:IsDescendantOf(workspace) and p.Enabled
end

local function parsePriority()
    local l = {}
    for w in string.gmatch(priorityBox.Text:lower(), "[^,]+") do
        w = w:match("^%s*(.-)%s*$")
        if w ~= "" then l[#l + 1] = w end
    end
    return l
end

local function rankOf(p, l)
    local t = promptText(p)
    for i, w in ipairs(l) do
        if t:find(w, 1, true) then return #l - i + 1, w end
    end
    return 0, nil
end

local function scanPrompts(center, radius, want)
    local res = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled then
            local pos = promptPos(p)
            if pos and (pos - center).Magnitude <= radius and want(p) then
                table.insert(res, { p = p, pos = pos })
            end
        end
    end
    return res
end

local function nearest(cands, taken)
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bd, br
    for _, e in ipairs(cands) do
        if not taken[e.p] and promptAlive(e.p) then
            local d = (e.pos - hrp.Position).Magnitude
            local r = e.rank or 0
            if not best or r > br or (r == br and d < bd) then
                best, bd, br = e, d, r
            end
        end
    end
    return best
end

-- ===== Steal: tembak instan =====
local function triggerInstant(p, attempt)
    pcall(function()
        p.RequiresLineOfSight = false
        p.HoldDuration = 0
    end)
    if attempt ~= 2 and fireproximityprompt then
        if pcall(fireproximityprompt, p) then return end
    end
    pcall(function()
        p:InputHoldBegin()
        task.wait(0.2)
        p:InputHoldEnd()
    end)
end

local function takePrompt(p, speed, id)
    for attempt = 1, 3 do
        if not alivePath(id) or not promptAlive(p) then break end
        local ppos = promptPos(p)
        if not ppos then break end
        local stop = (attempt == 3) and 2 or clamp((p.MaxActivationDistance or 10) - 4, 2.5, 8)
        if not moveTo(ppos, speed, stop, id) then return false end
        if not pause(0.3, id) then return false end
        triggerInstant(p, attempt)
        if not pause(0.5, id) then return false end
        if not promptAlive(p) then return true end
    end
    return not promptAlive(p)
end

-- ===== Pickup egg: tahan prompt =====
local function holdTime(p)
    local manual = tonumber(holdBox.Text) or 0
    if manual > 0 then return manual end
    local h = p.HoldDuration or 0
    if h >= 0.5 then return h + 0.4 end
    return 6
end

local function holdPrompt(p, id)
    local hrp = getHRP()
    if not hrp then return false end
    local dur = holdTime(p)
    local anchor = hrp.CFrame
    pcall(function() p.RequiresLineOfSight = false end)
    pcall(function() p:InputHoldBegin() end)

    local t0 = os.clock()
    local done = false
    while os.clock() - t0 < dur do
        if not alivePath(id) then break end
        if not promptAlive(p) then done = true break end
        local h = getHRP()
        if not h then break end
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        if (h.Position - anchor.Position).Magnitude > 0.5 then
            h.CFrame = anchor
        end
        status.Text = string.format("Tahan pickup %.1f / %.1f dtk", os.clock() - t0, dur)
        RunService.Heartbeat:Wait()
    end
    pcall(function() p:InputHoldEnd() end)
    return done
end

local function takeEgg(p, speed, id)
    for attempt = 1, 2 do
        if not alivePath(id) or not promptAlive(p) then break end
        local ppos = promptPos(p)
        if not ppos then break end
        local stop = clamp((p.MaxActivationDistance or 10) - 4, 2.5, 6)
        if not moveTo(ppos, speed, stop, id) then return false end
        if not pause(0.4, id) then return false end
        if holdPrompt(p, id) then return true end
        if not alivePath(id) then return false end
        if not pause(0.4, id) then return false end
        if not promptAlive(p) then return true end
    end
    return not promptAlive(p)
end

local function collectEggs(z, radius, speed, id)
    if not pickupOn then return 0 end
    local maxPick = clamp(math.floor(tonumber(maxPickBox.Text) or 2), 0, 20)
    if maxPick == 0 then return 0 end
    local cands = scanPrompts(z.pos, radius, isPickup)
    status.Text = "Egg di radius: " .. #cands
    local taken, got = {}, 0
    while got < maxPick and alivePath(id) do
        local e = nearest(cands, taken)
        if not e then break end
        taken[e.p] = true
        status.Text = "Menuju egg: " .. e.p.ObjectText
        if takeEgg(e.p, speed, id) then got += 1 end
    end
    return got
end

local function doSteals(z, radius, speed, id)
    local maxSteal = clamp(math.floor(tonumber(stealBox.Text) or 1), 0, 10)
    if maxSteal == 0 then return 0 end
    local filter = filterBox.Text:lower()
    local prio = parsePriority()

    local found = scanPrompts(z.pos, radius, function(p)
        if isPickup(p) then return false end
        if filter ~= "" and not promptText(p):find(filter, 1, true) then return false end
        return true
    end)

    local cands = {}
    for _, e in ipairs(found) do
        local r, w = rankOf(e.p, prio)
        e.rank, e.word = r, w
        if r > 0 or not onlyList then
            cands[#cands + 1] = e
        end
    end

    status.Text = "Target steal di zona: " .. #cands
    local taken, got = {}, 0
    while got < maxSteal and alivePath(id) do
        local e = nearest(cands, taken)
        if not e then break end
        taken[e.p] = true
        status.Text = "Steal: " .. (e.word and e.word:upper() or e.p.ObjectText)
        if takePrompt(e.p, speed, id) then got += 1 end
    end
    return got
end

-- ===== Satu siklus =====
local function cycle(id)
    local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
    local afterSteal = math.max(0, tonumber(afterStealBox.Text) or 3)
    local waitFront = math.max(0, tonumber(frontBox.Text) or 1.5)
    local radius = clamp(tonumber(radiusBox.Text) or 100, 5, 2000)
    local z = zones[selected]
    if not z then return end

    -- 1) Dari zona aman ke Depan dulu, tunggu tinggi kapal sesuai, baru ke zona steal
    if not syncHeight(speed, id) then return end

    status.Text = "Menuju " .. z.name
    if not moveTo(z.pos, speed, 1.5, id) then return end
    if not pause(0.5, id) then return end

    local eggs = collectEggs(z, radius, speed, id)
    if not alivePath(id) then return end
    local stolen = doSteals(z, radius, speed, id)
    if not alivePath(id) then return end

    if stolen > 0 and afterSteal > 0 then
        status.Text = string.format("Steal: %d | jeda %.1f dtk", stolen, afterSteal)
        if not pause(afterSteal, id) then return end
    else
        status.Text = string.format("Pickup: %d | Steal: %d", eggs, stolen)
        if eggs == 0 and stolen == 0 then
            if not pause(1, id) then return end
        end
    end

    status.Text = "Kembali ke depan zona aman"
    if not moveTo(frontPos, speed, 1.5, id) then return end

    status.Text = "Tunggu " .. waitFront .. " dtk"
    if not pause(waitFront, id) then return end

    status.Text = "Masuk zona aman"
    if not moveTo(safePos, speed, 1.5, id) then return end

    status.Text = "Jeda sebelum siklus berikut"
    pause(2, id)
end

-- ===== Zona =====
local function addZone(name, pos)
    local z = { name = name, pos = pos }
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 28)
    b.Text = string.format("%s (%.0f, %.0f, %.0f)", name, pos.X, pos.Y, pos.Z)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.BackgroundColor3 = COL_GREY
    b.Parent = zoneBox
    round(b, 6)
    z.btn = b
    table.insert(zones, z)
    b.Activated:Connect(function()
        selected = table.find(zones, z)
        refresh()
    end)
    selected = #zones
    refresh()
    return z
end

local function clearZones()
    for _, z in ipairs(zones) do
        pcall(function() z.btn:Destroy() end)
    end
    zones = {}
    selected = nil
    zoneCounter = 0
end

btnAdd.Activated:Connect(function()
    local hrp = getHRP()
    if not hrp then return end
    zoneCounter += 1
    addZone("Zona " .. zoneCounter, hrp.Position)
end)

btnDel.Activated:Connect(function()
    local z = zones[selected]
    if not z then return end
    z.btn:Destroy()
    table.remove(zones, selected)
    selected = (#zones > 0) and math.min(selected, #zones) or nil
    refresh()
end)

btnFront.Activated:Connect(function()
    local hrp = getHRP()
    if hrp then frontPos = hrp.Position refresh() end
end)

btnSafe.Activated:Connect(function()
    local hrp = getHRP()
    if hrp then safePos = hrp.Position refresh() end
end)

pickBtn.Activated:Connect(function() setPickup(not pickupOn) end)
onlyBtn.Activated:Connect(function() setOnly(not onlyList) end)
stabBtn.Activated:Connect(function() setStab(not stabOn) end)
keepYBtn.Activated:Connect(function() setKeepY(not keepY) end)
syncBtn.Activated:Connect(function() setSyncY(not syncY) end)

-- Tombol darurat: angkat karakter (dan kapal yang menyatu dengannya) 5 studs
liftBtn.Activated:Connect(function()
    local h = getHRP()
    if not h then return end
    h.CFrame = h.CFrame + Vector3.new(0, 5, 0)
    h.AssemblyLinearVelocity = Vector3.zero
    if baseY then baseY = baseY + 5 end
    status.Text = "Posisi dinaikkan +5 Y"
end)

scanBtn.Activated:Connect(function()
    local hrp = getHRP()
    if not hrp then return end
    local radius = clamp(tonumber(radiusBox.Text) or 100, 5, 2000)
    local prio = parsePriority()
    local found = scanPrompts(hrp.Position, radius, function() return true end)
    status.Text = "Scan: " .. #found .. " prompt (lihat console)"
    print("== Scan prompt, radius " .. radius .. " ==")
    for _, e in ipairs(found) do
        local p = e.p
        local r, w = rankOf(p, prio)
        print(string.format("%.0f studs | %s | Action=%q Object=%q Hold=%.1f MaxDist=%.0f | pickup=%s rank=%d(%s)",
            (e.pos - hrp.Position).Magnitude, p:GetFullName(), p.ActionText, p.ObjectText,
            p.HoldDuration, p.MaxActivationDistance, tostring(isPickup(p)), r, tostring(w)))
        local ad = p.Parent
        if ad and ad:IsA("Attachment") then ad = ad.Parent end
        if ad and (ad:IsA("BasePart") or ad:IsA("Model")) then
            pcall(function()
                local h = Instance.new("Highlight")
                h.Adornee = ad
                if isPickup(p) then
                    h.FillColor = Color3.fromRGB(0, 255, 100)
                elseif r > 0 then
                    h.FillColor = Color3.fromRGB(255, 140, 0)
                else
                    h.FillColor = Color3.fromRGB(255, 255, 120)
                end
                h.Parent = workspace
                task.delay(4, function() h:Destroy() end)
            end)
        end
    end
end)

local function setRunning(on)
    if on and not (zones[selected] and frontPos and safePos) then
        status.Text = "Lengkapi dulu: pilih zona, Set Depan, Set Aman"
        return
    end
    if on then
        -- Ketinggian awal (dipakai kalau Jaga Y ON; tiap siklus disegarkan di titik Depan bila Sinkron ON)
        local h = getHRP()
        baseY = h and h.Position.Y or nil
    end
    runId += 1
    running = on
    toggle.Text = "Auto Steal: " .. (on and "ON" or "OFF")
    toggle.BackgroundColor3 = on and COL_GREEN or COL_RED
    if not on then
        status.Text = "Berhenti"
        setStand(false)
    end
end

toggle.Activated:Connect(function() setRunning(not running) end)

-- ===== CONFIG (save / load) =====
local FOLDER = "AutoStealConfig"
local hasFS = (writefile and readfile and isfile and isfolder and makefolder) and true or false

local fieldMap = {
    speed = speedBox,
    yOffset = yOffsetBox,
    syncWait = syncWaitBox,
    afterSteal = afterStealBox,
    waitFront = frontBox,
    radius = radiusBox,
    maxSteal = stealBox,
    filter = filterBox,
    priority = priorityBox,
    pickText = pickTextBox,
    maxPick = maxPickBox,
    hold = holdBox,
    guardKey = guardKeyBox,
    catchKey = catchKeyBox,
}

local function cfgPath(name) return FOLDER .. "/" .. name .. ".json" end
local metaPath = FOLDER .. "/_meta.dat"

local function cleanName(n)
    n = tostring(n or ""):gsub("[^%w_%-]", "_")
    if n == "" then n = "default" end
    return n
end

local function v3t(v) return { x = v.X, y = v.Y, z = v.Z } end
local function t3v(t)
    if type(t) == "table" and type(t.x) == "number" and type(t.y) == "number" and type(t.z) == "number" then
        return Vector3.new(t.x, t.y, t.z)
    end
end

local function collectConfig()
    local c = { v = 1, fields = {}, toggles = {}, zones = {} }
    for k, box in pairs(fieldMap) do c.fields[k] = box.Text end
    c.toggles.pickup = pickupOn
    c.toggles.stab = stabOn
    c.toggles.onlyList = onlyList
    c.toggles.keepY = keepY
    c.toggles.syncY = syncY
    c.toggles.afk = afkOn
    c.toggles.skipGuard = skipGuardOn
    c.toggles.skipCatch = skipCatchOn
    if frontPos then c.front = v3t(frontPos) end
    if safePos then c.safe = v3t(safePos) end
    for _, z in ipairs(zones) do
        local t = v3t(z.pos)
        t.name = z.name
        c.zones[#c.zones + 1] = t
    end
    c.selected = selected
    return c
end

local function applyConfig(c)
    setRunning(false)
    if type(c.fields) == "table" then
        for k, box in pairs(fieldMap) do
            if c.fields[k] ~= nil then box.Text = tostring(c.fields[k]) end
        end
    end
    if type(c.toggles) == "table" then
        if c.toggles.pickup ~= nil then setPickup(c.toggles.pickup == true) end
        if c.toggles.stab ~= nil then setStab(c.toggles.stab == true) end
        if c.toggles.onlyList ~= nil then setOnly(c.toggles.onlyList == true) end
        if c.toggles.keepY ~= nil then setKeepY(c.toggles.keepY == true) end
        if c.toggles.syncY ~= nil then setSyncY(c.toggles.syncY == true) end
        if c.toggles.afk ~= nil then setAfk(c.toggles.afk == true) end
        if c.toggles.skipGuard ~= nil then setSkipGuard(c.toggles.skipGuard == true) end
        if c.toggles.skipCatch ~= nil then setSkipCatch(c.toggles.skipCatch == true) end
    end
    frontPos = t3v(c.front)
    safePos = t3v(c.safe)
    clearZones()
    if type(c.zones) == "table" then
        for i, zd in ipairs(c.zones) do
            local pos = t3v(zd)
            if pos then
                addZone(type(zd.name) == "string" and zd.name or ("Zona " .. i), pos)
            end
        end
    end
    zoneCounter = #zones
    if type(c.selected) == "number" and zones[c.selected] then
        selected = c.selected
    elseif #zones > 0 then
        selected = 1
    end
    refresh()
end

local meta = { autoload = false, last = "default" }

local function saveMeta()
    if not hasFS then return end
    pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        writefile(metaPath, HttpService:JSONEncode(meta))
    end)
end

local function loadMeta()
    if not hasFS then return end
    pcall(function()
        if isfile(metaPath) then
            local m = HttpService:JSONDecode(readfile(metaPath))
            if type(m) == "table" then
                meta.autoload = (m.autoload == true)
                meta.last = cleanName(m.last)
            end
        end
    end)
end

local function setAutoBtn()
    btnAuto.Text = "Auto-load: " .. (meta.autoload and "ON" or "OFF")
    btnAuto.BackgroundColor3 = meta.autoload and COL_GREEN or COL_GREY
end

local function saveConfig(name)
    if not hasFS then
        status.Text = "Executor ini tidak mendukung writefile/readfile"
        return
    end
    name = cleanName(name)
    local okw, e = pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        writefile(cfgPath(name), HttpService:JSONEncode(collectConfig()))
    end)
    if okw then
        cfgNameBox.Text = name
        meta.last = name
        saveMeta()
        status.Text = "Config disimpan: " .. name
    else
        status.Text = "Gagal simpan: " .. tostring(e)
    end
end

local function loadConfig(name)
    if not hasFS then
        status.Text = "Executor ini tidak mendukung writefile/readfile"
        return false
    end
    name = cleanName(name)
    local path = cfgPath(name)
    local okx, exists = pcall(isfile, path)
    if not okx or not exists then
        status.Text = "Config tidak ditemukan: " .. name
        return false
    end
    local okr, c = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not okr or type(c) ~= "table" then
        status.Text = "File config rusak: " .. name
        return false
    end
    local oka, e = pcall(applyConfig, c)
    if not oka then
        status.Text = "Gagal terapkan config: " .. tostring(e)
        return false
    end
    cfgNameBox.Text = name
    meta.last = name
    saveMeta()
    status.Text = string.format("Config dimuat: %s (%d zona)", name, #zones)
    return true
end

btnSave.Activated:Connect(function() saveConfig(cfgNameBox.Text) end)
btnLoad.Activated:Connect(function() loadConfig(cfgNameBox.Text) end)

btnList.Activated:Connect(function()
    if not listfiles or not hasFS then
        status.Text = "Executor ini tidak mendukung listfiles"
        return
    end
    local oks, files = pcall(function()
        if not isfolder(FOLDER) then return {} end
        return listfiles(FOLDER)
    end)
    if not oks then
        status.Text = "Gagal membaca folder config"
        return
    end
    local names = {}
    for _, f in ipairs(files) do
        local n = tostring(f):match("([^/\\]+)%.json$")
        if n then names[#names + 1] = n end
    end
    table.sort(names)
    if #names == 0 then
        status.Text = "Belum ada config tersimpan"
    else
        status.Text = "Config: " .. table.concat(names, ", ")
    end
    print("== Config tersimpan ==")
    for _, n in ipairs(names) do print(n) end
end)

btnAuto.Activated:Connect(function()
    if not hasFS then
        status.Text = "Executor ini tidak mendukung writefile/readfile"
        return
    end
    meta.autoload = not meta.autoload
    meta.last = cleanName(cfgNameBox.Text)
    saveMeta()
    setAutoBtn()
    status.Text = meta.autoload
        and ("Auto-load aktif, config: " .. meta.last)
        or "Auto-load dimatikan"
end)

-- ===== Minimize / close =====
local minimized = false
minBtn.Activated:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = UDim2.new(0, 260, 0, minimized and 32 or FULL_H)
    minBtn.Text = minimized and "+" or "-"
end)

local function close()
    alive, running, trainOn = false, false, false
    runId += 1
    local c = lp.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
    for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
    gui:Destroy()
end
closeBtn.Activated:Connect(close)
env.AutoStealCleanup = close

-- ===== Auto-load saat script dijalankan =====
loadMeta()
setAutoBtn()
cfgNameBox.Text = meta.last
if meta.autoload then
    loadConfig(meta.last)
end

-- ===== Loop utama =====
task.spawn(function()
    while alive do
        if running and getHRP() then
            local okc, e = pcall(cycle, runId)
            if not okc then
                status.Text = "Error: " .. tostring(e)
                warn(e)
                setStand(false)
                task.wait(1)
            end
        end
        task.wait(0.1)
    end
end)

end, debug.traceback)

if not ok then fatal(err) end