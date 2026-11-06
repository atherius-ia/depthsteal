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
local cineCount = 0
local nf = { on = false }
local tr = {}
local bs = { on = false, mode = 1 }
local bossBusy = false
local setBoss, setClickMode
local startClock = os.clock()
local frontPos
local zones, selected, zoneCounter = {}, nil, 0
local conns = {}
local logLine -- forward declaration (dipakai Anti-AFK sebelum didefinisikan)

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

-- Tap SENTUHAN (bukan mouse/keyboard) supaya game tetap di mode layar sentuh
local VIMtouch
pcall(function() VIMtouch = game:GetService("VirtualInputManager") end)
local touchSeq = 0
local function tapScreen(x, y)
    if not VIMtouch then return false end
    touchSeq += 1
    local tid = touchSeq % 1000 + 1
    return (pcall(function()
        VIMtouch:SendTouchEvent(tid, 0, x, y)
        task.wait(0.05)
        VIMtouch:SendTouchEvent(tid, 2, x, y)
    end))
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

local COL_BLUE = Color3.fromRGB(60, 120, 200)
local COL_GREY = Color3.fromRGB(55, 55, 70)
local COL_RED = Color3.fromRGB(180, 40, 40)
local COL_GREEN = Color3.fromRGB(40, 150, 60)

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
title.Text = "Training + Boss + Steal"
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

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -32)
content.Position = UDim2.new(0, 0, 0, 32)
content.BackgroundTransparency = 1
content.Parent = main

local tabBar = Instance.new("ScrollingFrame")
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 0
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.Parent = content
do
    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 4)
    tl.SortOrder = Enum.SortOrder.LayoutOrder
    tl.Parent = tabBar
    local tp = Instance.new("UIPadding")
    tp.PaddingLeft = UDim.new(0, 8)
    tp.PaddingRight = UDim.new(0, 8)
    tp.PaddingTop = UDim.new(0, 3)
    tp.PaddingBottom = UDim.new(0, 3)
    tp.Parent = tabBar
end

local pagesHolder = Instance.new("Frame")
pagesHolder.Position = UDim2.new(0, 0, 0, 30)
pagesHolder.Size = UDim2.new(1, 0, 1, -82)
pagesHolder.BackgroundTransparency = 1
pagesHolder.ClipsDescendants = true
pagesHolder.Parent = content

local footer = Instance.new("Frame")
footer.Position = UDim2.new(0, 0, 1, -52)
footer.Size = UDim2.new(1, 0, 0, 52)
footer.BackgroundTransparency = 1
footer.Parent = content

local info = Instance.new("TextLabel")
info.Position = UDim2.new(0, 10, 0, 0)
info.Size = UDim2.new(1, -20, 0, 16)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(200, 200, 210)
info.Font = Enum.Font.Gotham
info.TextSize = 11
info.TextXAlignment = Enum.TextXAlignment.Left
info.Parent = footer

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 10, 0, 16)
status.Size = UDim2.new(1, -20, 0, 34)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 220, 120)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Siap"
status.Parent = footer

local cur
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
    r.Parent = cur
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

local function mkInfoLabel(h, text, color)
    local r = mkRow(h)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.Text = text
    l.Parent = r
    return l
end

local pages, tabBtns, firstTab = {}, {}, nil
local function selectTab(name)
    for n, p in pairs(pages) do
        p.Visible = (n == name)
        tabBtns[n].BackgroundColor3 = (n == name) and COL_BLUE or COL_GREY
    end
end

local function newTab(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = pagesHolder

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = page
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 6)
    p.PaddingBottom = UDim.new(0, 8)
    p.PaddingLeft = UDim.new(0, 8)
    p.PaddingRight = UDim.new(0, 12)
    p.Parent = page

    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, math.max(54, #name * 8 + 18), 1, 0)
    tb.BackgroundColor3 = COL_GREY
    tb.Text = name
    tb.TextColor3 = Color3.new(1, 1, 1)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 11
    tb.LayoutOrder = nxt()
    tb.Parent = tabBar
    round(tb, 6)

    pages[name] = page
    tabBtns[name] = tb
    tb.Activated:Connect(function() selectTab(name) end)
    cur = page
    if not firstTab then
        firstTab = name
        selectTab(name)
    end
end

-- ===== Tab TRAINING =====
newTab("Training")
mkHeader("AUTO TRAINING")

local trainBtn = mkBtn(mkRow(38), "Auto Training: OFF", COL_RED)
trainBtn.Size = UDim2.new(1, 0, 1, 0)
trainBtn.TextSize = 14

local trainStatus = mkInfoLabel(18, "Boost terkirim: 0")

tr.posBtn = mkBtn(mkRow(32), "Set Posisi Training", COL_BLUE)
tr.posBtn.Size = UDim2.new(1, 0, 1, 0)
tr.promptBox = mkField("Teks prompt training (opsional)", "")
tr.nameBox = mkField("Nama objek training (opsional)", "")
tr.seatBox = mkField("Folder/nama kursi training", "RowingMachines")
tr.scanBtn = mkBtn(mkRow(32), "Scan Area Training (ke log)", COL_GREY)
tr.scanBtn.Size = UDim2.new(1, 0, 1, 0)

-- ===== Tab BOSS =====
newTab("Boss")
mkHeader("AUTO BOSS (prioritas di atas training)")

bs.btn = mkBtn(mkRow(38), "Auto Boss: OFF", COL_RED)
bs.btn.Size = UDim2.new(1, 0, 1, 0)
bs.btn.TextSize = 14

bs.status = mkInfoLabel(30, "Boss: mati")

bs.tpBaseBtn = mkBtn(mkRow(34), "Teleport ke Base (respawn)", COL_BLUE)
bs.tpBaseBtn.Size = UDim2.new(1, 0, 1, 0)

bs.setSafe = mkBtn(mkRow(32), "Set Zona Aman Boss (posisi saya)", COL_BLUE)
bs.setSafe.Size = UDim2.new(1, 0, 1, 0)

bs.setZone = mkBtn(mkRow(32), "Set Zona Boss (posisi saya)", COL_BLUE)
bs.setZone.Size = UDim2.new(1, 0, 1, 0)

bs.keyBox = mkField("Teks notif boss", "fight in")
bs.filterBox = mkField("Filter nama boss (opsional)", "")
bs.goBox = mkField("Teks tombol GO", "go")
bs.afterGoBox = mkField("Tunggu teleport setelah GO (dtk)", "4")
bs.nameBox = mkField("Nama objek boss (opsional)", "")
bs.rangeBox = mkField("Teks IN RANGE", "in range")
bs.fireBox = mkField("Teks tombol FIRE", "fire")
bs.fightMaxBox = mkField("Batas waktu fight (dtk)", "240")
bs.tpBox = mkField("Teks tombol TP (acuan rumah)", "ocean")
bs.homeNameBox = mkField("Nama tombol rumah (opsional)", "home")
bs.clickYBox = mkField("Offset klik Y (px)", "0")

bs.modeBtn = mkBtn(mkRow(32), "Metode klik: SINYAL+SENTUH", COL_GREY)
bs.modeBtn.Size = UDim2.new(1, 0, 1, 0)

bs.testGo, bs.testHome = twoBtns("Tes GO", COL_GREY, "Tes Rumah", COL_GREY)
bs.testFire, bs.testWalk = twoBtns("Tes FIRE", COL_GREY, "Tes Jalan ke Boss", COL_GREY)
bs.scanBoss = mkBtn(mkRow(32), "Scan Nama Boss (ke log)", COL_GREY)
bs.scanBoss.Size = UDim2.new(1, 0, 1, 0)

bs.bossRespawnBtn = mkBtn(mkRow(32), "Respawn ke base bila tombol rumah gagal: ON", COL_GREEN)
bs.bossRespawnBtn.Size = UDim2.new(1, 0, 1, 0)
bs.bossRespawnOn = true

-- ===== Tab STEAL =====
newTab("Steal")
mkHeader("AUTO STEAL + PICKUP EGG")

local toggle = mkBtn(mkRow(40), "Auto Steal: OFF", COL_RED)
toggle.Size = UDim2.new(1, 0, 1, 0)
toggle.TextSize = 16

local btnAdd, btnDel = twoBtns("Simpan Zona", COL_BLUE, "Hapus Zona", COL_RED)

local zoneBox = Instance.new("Frame")
zoneBox.Size = UDim2.new(1, 0, 0, 0)
zoneBox.AutomaticSize = Enum.AutomaticSize.Y
zoneBox.BackgroundTransparency = 1
zoneBox.LayoutOrder = nxt()
zoneBox.Parent = cur
local zl = Instance.new("UIListLayout")
zl.Padding = UDim.new(0, 4)
zl.Parent = zoneBox

local btnFront = mkBtn(mkRow(32), "Set Depan", COL_BLUE)
btnFront.Size = UDim2.new(1, 0, 1, 0)

local speedBox = mkField("Speed (studs/dtk)", "60")
local yOffsetBox = mkField("Offset Y (studs)", "0")
local syncWaitBox = mkField("Tunggu di depan sblm steal (dtk)", "2")
local afterStealBox = mkField("Jeda cadangan (dtk, bila GUI kosong)", "3")
local cineKeyBox = mkField("Tunggu GUI setelah steal", "hatchreveal/device")
local cineTimeoutBox = mkField("Batas tunggu GUI (dtk)", "10")
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

-- ===== Tab SKIP CINEMATIC =====
newTab("Skip")
mkHeader("SKIP CINEMATIC (eksperimental)")

local guardKeyBox = mkField("Kata kunci guardian", "guardian,entrance")
local catchKeyBox = mkField("Kata kunci catch", "catch,cinematic")

local skipGuardBtn = mkBtn(mkRow(32), "Skip Guardian Entrance: OFF", COL_GREY)
skipGuardBtn.Size = UDim2.new(1, 0, 1, 0)

local skipCatchBtn = mkBtn(mkRow(32), "Skip Catch Cinematic: OFF", COL_GREY)
skipCatchBtn.Size = UDim2.new(1, 0, 1, 0)

-- ===== Tab DROP =====
newTab("Drop")
mkHeader("AUTO DROP TELUR UKURAN KECIL")

bs.dropBtn = mkBtn(mkRow(38), "Auto Drop Small: OFF", COL_GREY)
bs.dropBtn.Size = UDim2.new(1, 0, 1, 0)
bs.dropBtn.TextSize = 14

bs.dropStatus = mkInfoLabel(30, "Drop: mati")

bs.dropSizeBox = mkField("Ukuran yang di-drop", "small")
bs.dropTextBox = mkField("Teks tombol DROP", "drop")
bs.dropSureBox = mkField("Teks tombol konfirmasi", "sure")

mkHeader("INVENTORI PENUH")
bs.invBtn = mkBtn(mkRow(32), "Respawn bila inventori penuh: ON", COL_GREEN)
bs.invBtn.Size = UDim2.new(1, 0, 1, 0)
bs.invTrainBtn = mkBtn(mkRow(32), "Training ON setelah inv penuh: ON", COL_GREEN)
bs.invTrainBtn.Size = UDim2.new(1, 0, 1, 0)
bs.invTrainOn = true
bs.setSafe2 = mkBtn(mkRow(32), "Set Zona Aman Steal (posisi saya)", COL_BLUE)
bs.setSafe2.Size = UDim2.new(1, 0, 1, 0)
bs.tpBaseBtn2 = mkBtn(mkRow(34), "Teleport ke Base (respawn)", COL_BLUE)
bs.tpBaseBtn2.Size = UDim2.new(1, 0, 1, 0)
bs.invTextBox = mkField("Teks notifikasi penuh", "inventory full")
bs.respawnTextBox = mkField("Teks tombol respawn (opsional)", "respawn")

-- ===== Tab LOG =====
newTab("Log")
mkHeader("LOG & ALAT BANTU")

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

bs.scanGui = mkBtn(mkRow(32), "Scan GUI tampil (tombol & teks)", COL_GREY)
bs.scanGui.Size = UDim2.new(1, 0, 1, 0)

bs.scanBoss = mkBtn(mkRow(32), "Scan Objek Boss di Sekitar (nama)", COL_GREY)
bs.scanBoss.Size = UDim2.new(1, 0, 1, 0)

local scanBtn = mkBtn(mkRow(32), "Scan Prompt di Sekitar Saya", COL_GREY)
scanBtn.Size = UDim2.new(1, 0, 1, 0)

local liftBtn = mkBtn(mkRow(32), "Naikkan posisi +5 Y (darurat)", COL_GREY)
liftBtn.Size = UDim2.new(1, 0, 1, 0)

-- ===== Tab CONFIG =====
newTab("Config")
mkHeader("CONFIG")

local cfgNameBox = mkField("Nama config", "default")
local btnSave, btnLoad = twoBtns("Save Config", COL_BLUE, "Load Config", COL_BLUE)
local btnList, btnAuto = twoBtns("Daftar Config", COL_GREY, "Auto-load: OFF", COL_GREY)

-- ===== Tab NOTIF DISCORD =====
newTab("Discord")
mkHeader("NOTIF DISCORD (disconnect/kick)")

nf.url = mkField("URL webhook", "")
nf.ping = mkField("ID Discord (ping, opsional)", "")
nf.btn = mkBtn(mkRow(32), "Notif Discord: OFF", COL_GREY)
nf.btn.Size = UDim2.new(1, 0, 1, 0)
nf.test = mkBtn(mkRow(32), "Simpan & Tes Webhook", COL_BLUE)
nf.test.Size = UDim2.new(1, 0, 1, 0)

-- ===== Tab ANTI AFK =====
newTab("AFK")
mkHeader("ANTI AFK")

local afkBtn = mkBtn(mkRow(32), "Anti-AFK: ON", COL_GREEN)
afkBtn.Size = UDim2.new(1, 0, 1, 0)

local afkStatus = mkInfoLabel(18, "Aktif 0:00:00 | Dicegah: 0")

local function refresh()
    for i, z in ipairs(zones) do
        z.btn.BackgroundColor3 = (i == selected) and COL_BLUE or COL_GREY
    end
    info.Text = string.format("Zona:%d Depan:%s Latih:%s Boss:%s",
        #zones, frontPos and "OK" or "-",
        (tr.pos or tr.rel or tostring(tr.seatBox.Text):match("%S")) and "OK" or "-",
        bs.pos and "OK" or "-")
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

-- ===== Setter toggle =====
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

-- ===== Anti-AFK (Updated & Fixed for Mobile) =====
do
    local VIM = game:GetService("VirtualInputManager")

    local function disableIdledConnections()
        if getconnections then
            for _, conn in ipairs(getconnections(lp.Idled)) do
                if conn.Disable then
                    conn:Disable()
                elseif conn.Disconnect then
                    conn:Disconnect()
                end
            end
        end
    end
    pcall(disableIdledConnections)

    local function sendVirtualTap()
        if not afkOn then return end
        pcall(function()
            local cam = workspace.CurrentCamera
            local viewport = cam and cam.ViewportSize or Vector2.new(800, 600)
            local x = viewport.X - 50
            local y = 50

            if tapScreen(x, y) then afkCount += 1 end
        end)
    end

    table.insert(conns, lp.Idled:Connect(function()
        if afkOn then
            sendVirtualTap()
        end
    end))

    task.spawn(function()
        while alive do
            task.wait(300)
            if afkOn then
                sendVirtualTap()
                if logOn then
                    logLine("[Anti-AFK] Sentuhan virtual dikirim untuk reset timer AFK")
                end
            end
        end
    end)
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
local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")

local logLines = {}
function logLine(s)
    print(s)
    logLines[#logLines + 1] = s
    if #logLines > 80 then table.remove(logLines, 1) end
    local from = math.max(1, #logLines - 7)
    logLabel.Text = table.concat(logLines, "\n", from, #logLines)
end

local cinematicUntil = 0
local function markCinematic()
    cinematicUntil = os.clock() + 10
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

local watched = setmetatable({}, { __mode = "k" })
local function watch(o)
    if watched[o] then return end
    if o:IsA("ScreenGui") then
        watched[o] = true
        o:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not alive or not o.Enabled then return end
            if logOn then logLine("[nyala] " .. o.Name) end
            if skipGuardOn or skipCatchOn then
                local gk, ck = currentKeys()
                if cinematicHit(o, gk, ck) then
                    pcall(hideInst, o)
                    markCinematic(); logLine("[skip] " .. o.Name)
                end
            end
        end)
    elseif o:IsA("GuiObject") then
        watched[o] = true
        o:GetPropertyChangedSignal("Visible"):Connect(function()
            if not alive or not o.Visible then return end
            if logOn then logLine("[tampil] " .. shortName(o)) end
            if skipGuardOn or skipCatchOn then
                local gk, ck = currentKeys()
                if cinematicHit(o, gk, ck) then
                    pcall(hideInst, o)
                    markCinematic(); logLine("[skip] " .. shortName(o))
                end
            end
        end)
    end
end

for _, g in ipairs(pg:GetChildren()) do
    if g:IsA("ScreenGui") and g ~= gui then
        watch(g)
        for _, f in ipairs(g:GetChildren()) do watch(f) end
    end
end

table.insert(conns, pg.DescendantAdded:Connect(function(inst)
    if not (inst:IsA("ScreenGui") or inst:IsA("GuiObject")) then return end
    if inst == gui or inst:IsDescendantOf(gui) then return end
    if inst:IsA("GuiObject") and inst.Parent then
        local key = cineKeyBox.Text:lower():match("^%s*(.-)%s*$")
        if key ~= "" and (inst.Parent.Name .. "/" .. inst.Name):lower():find(key, 1, true) then
            cineCount += 1
        end
    end
    local top = isTopLevel(inst)
    if top then watch(inst) end
    if logOn and top then logLine("[baru] " .. shortName(inst)) end
    if skipGuardOn or skipCatchOn then
        local gk, ck = currentKeys()
        if cinematicHit(inst, gk, ck) then
            pcall(hideInst, inst)
            markCinematic(); logLine("[skip] " .. shortName(inst))
            task.defer(function()
                pcall(hideInst, inst)
                status.Text = "Skip: " .. inst.Name
            end)
        end
    end
end))

task.spawn(function()
    while alive do
        if skipGuardOn or skipCatchOn then
            local gk, ck = currentKeys()
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= gui then
                    if g.Enabled and cinematicHit(g, gk, ck) then
                        pcall(hideInst, g)
                        markCinematic(); logLine("[skip] " .. g.Name)
                        status.Text = "Skip: " .. g.Name
                    end
                    if g.Enabled then
                        for _, f in ipairs(g:GetChildren()) do
                            if f:IsA("GuiObject") and f.Visible and cinematicHit(f, gk, ck) then
                                pcall(hideInst, f)
                                markCinematic(); logLine("[skip] " .. shortName(f))
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

do
    local lastCam
    local seenScriptable = false
    local camName = "AutoStealSkipCam"
    pcall(function() RunService:UnbindFromRenderStep(camName) end)
    RunService:BindToRenderStep(camName, Enum.RenderPriority.Last.Value, function()
        local c = workspace.CurrentCamera
        if not c then return end
        if logOn and c.CameraType ~= lastCam then
            lastCam = c.CameraType
            logLine("[kamera] " .. (tostring(c.CameraType):gsub("Enum.CameraType.", "")))
        end
        if c.CameraType == Enum.CameraType.Scriptable then
            if (skipGuardOn or skipCatchOn) and os.clock() < cinematicUntil then
                local h = getHRP()
                if h then
                    local pos = h.Position
                    local back = -h.CFrame.LookVector
                    c.CFrame = CFrame.lookAt(pos + back * 12 + Vector3.new(0, 6, 0), pos + Vector3.new(0, 2, 0))
                    c.FieldOfView = 70
                    seenScriptable = true
                end
            end
        elseif seenScriptable then
            seenScriptable = false
            cinematicUntil = 0
        end
    end)
    table.insert(conns, { Disconnect = function()
        pcall(function() RunService:UnbindFromRenderStep(camName) end)
    end })
end

skipGuardBtn.Activated:Connect(function() setSkipGuard(not skipGuardOn) end)
skipCatchBtn.Activated:Connect(function() setSkipCatch(not skipCatchOn) end)

logBtn.Activated:Connect(function()
    logOn = not logOn
    logBtn.Text = "Log GUI dan kamera: " .. (logOn and "ON" or "OFF")
    logBtn.BackgroundColor3 = logOn and COL_GREEN or COL_GREY
    if logOn then
        logLine("== Log aktif. Picu cinematic sekarang ==")
        status.Text = "Log aktif: lihat kotak log di tab Log"
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
    local lastEnds, lastFire = nil, -math.huge
    while alive do
        if not boostRemote then
            local r = RS:FindFirstChild("Remotes")
            boostRemote = r and r:FindFirstChild("RequestRowingBoost")
        end
        if trainOn then
            local state = attr("State")
            local window = attr("RowBoostWindow")
            local ends = attr("RowBoostEndsAt")
            if boostRemote and state == "Training" and type(window) == "number" then
                local fresh = (window ~= trainLast) or (type(ends) == "number" and ends ~= lastEnds)
                if fresh then
                    trainLast = window
                    if type(ends) == "number" then lastEnds = ends end
                    if os.clock() - lastFire >= 0.5 then
                        lastFire = os.clock()
                        local okf = pcall(function()
                            boostRemote:FireServer({ window = window })
                        end)
                        if okf then
                            trainCount += 1
                            if logOn then
                                logLine("[boost] window=" .. tostring(window) .. " ends=" .. tostring(ends))
                            end
                        end
                    end
                end
            else
                trainLast = nil
                lastEnds = nil
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

local function setTrain(on)
    trainOn = on
    trainLast = nil
    trainBtn.Text = "Auto Training: " .. (on and "ON" or "OFF")
    trainBtn.BackgroundColor3 = on and COL_GREEN or COL_RED
    if not on then
        trainStatus.Text = "Boost terkirim: " .. trainCount
    end
end

trainBtn.Activated:Connect(function() setTrain(not trainOn) end)

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

local function syncHeight(speed, id)
    local h = getHRP()
    if not h then return false end

    status.Text = "Ke depan dulu"
    baseY = h.Position.Y
    if not moveTo(frontPos, speed, 1.5, id) then return false end

    if keepY and syncY then
        baseY = frontPos.Y
        local yOff = tonumber(yOffsetBox.Text) or 0
        h = getHRP()
        if not h then return false end
        status.Text = "Menyamakan tinggi"
        local tgt = Vector3.new(h.Position.X, baseY + yOff, h.Position.Z)
        if not moveTo(tgt, math.min(speed, 20), 0.2, id, true) then return false end
    end

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

-- ===== Auto masuk Training =====
tr.retryNow = false
do
    local function inTraining()
        return attr("State") == "Training"
    end

    local function trainWalk(target, speed, stopDist)
        local t0 = os.clock()
        while alive and trainOn and not running and not bossBusy do
            local hrp = getHRP()
            if not hrp then return false end
            local delta = target - hrp.Position
            local dist = delta.Magnitude
            if dist <= stopDist + 0.05 then return true end
            local dt = RunService.Heartbeat:Wait()
            local step = math.min(dist - stopDist, speed * dt)
            local newPos = hrp.Position + delta.Unit * step
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude > 0.01 then
                hrp.CFrame = CFrame.lookAt(newPos, newPos + flat)
            else
                hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if os.clock() - t0 > 60 then return false end
        end
        return false
    end

    local function waitTraining(maxT)
        local t0 = os.clock()
        while alive and trainOn and not running and not bossBusy and os.clock() - t0 < maxT do
            if inTraining() then return true end
            task.wait(0.2)
        end
        return inTraining()
    end

    local function findTrainPrompt(pos)
        local key = tostring(tr.promptBox.Text):lower():match("^%s*(.-)%s*$")
        local best, bd
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled then
                local pp = promptPos(p)
                if pp then
                    local d = (pp - pos).Magnitude
                    if d <= 15 and (key == "" or promptText(p):find(key, 1, true))
                        and (not best or d < bd) then
                        best, bd = p, d
                    end
                end
            end
        end
        return best
    end

    local function pressPrompt(p)
        pcall(function() p.RequiresLineOfSight = false end)
        if fireproximityprompt and pcall(fireproximityprompt, p) then return end
        pcall(function()
            p:InputHoldBegin()
            task.wait((p.HoldDuration or 0) + 0.2)
            p:InputHoldEnd()
        end)
    end

    local function captureRef(why)
        local hrp = getHRP()
        if hrp and attr("State") ~= "Training" then
            tr.ref = hrp.CFrame
            if logOn then logLine("[ref] referensi spawn diambil (" .. why .. ")") end
        end
    end

    task.spawn(function()
        local t0 = os.clock()
        while alive and not getHRP() and os.clock() - t0 < 15 do task.wait(0.2) end
        task.wait(0.5)
        captureRef("awal")
    end)

    table.insert(conns, lp.CharacterAdded:Connect(function(ch)
        ch:WaitForChild("HumanoidRootPart", 10)
        task.wait(1)
        captureRef("respawn")
        tr.retryNow = true
    end))

    local function findByName(key, from)
        key = key:lower()
        local bestPos, bd
        for _, d in ipairs(workspace:GetDescendants()) do
            local pos
            if d:IsA("BasePart") and d.Name:lower():find(key, 1, true) then
                pos = d.Position + Vector3.new(0, d.Size.Y / 2 + 3, 0)
            elseif d:IsA("Model") and d.Name:lower():find(key, 1, true) then
                pos = d:GetPivot().Position + Vector3.new(0, 3, 0)
            end
            if pos then
                local dist = (pos - from).Magnitude
                if not bestPos or dist < bd then bestPos, bd = pos, dist end
            end
        end
        return bestPos
    end

    local function findFreeSeat(key)
        local hrp = getHRP()
        if not hrp then return nil end
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        key = key:lower()
        local best, bd
        for _, d in ipairs(workspace:GetDescendants()) do
            if (d:IsA("Seat") or d:IsA("VehicleSeat")) and not d.Disabled
                and (d.Occupant == nil or d.Occupant == hum)
                and d:GetFullName():lower():find(key, 1, true) then
                local dist = (d.Position - hrp.Position).Magnitude
                if not best or dist < bd then best, bd = d, dist end
            end
        end
        return best
    end

    local function trySit(seat)
        local hrp = getHRP()
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
        if hum.SeatPart ~= seat then
            hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        local t0 = os.clock()
        while alive and trainOn and not running and not bossBusy and os.clock() - t0 < 2
            and hum.SeatPart ~= seat do
            task.wait(0.1)
        end
        if hum.SeatPart ~= seat then
            pcall(function() seat:Sit(hum) end)
            task.wait(0.5)
        end
        if logOn then
            logLine("[kursi] " .. seat:GetFullName() .. " duduk=" .. tostring(hum.SeatPart == seat))
        end
    end

    tr.ownSeatKey = function()
        local map = workspace:FindFirstChild("Map")
        local bases = map and map:FindFirstChild("Bases")
        if not bases then return nil end
        for _, b in ipairs(bases:GetChildren()) do
            local owner = b:GetAttribute("OwnerUserId")
            local idx = b:GetAttribute("BaseIndex")
            if owner ~= nil and idx ~= nil and tostring(owner) == tostring(lp.UserId) then
                return ".rowingmachine" .. tostring(idx) .. "."
            end
        end
        return nil
    end

    local function targets()
        local list = {}
        local hrp = getHRP()
        if not hrp then return list end
        local from = hrp.Position
        local skey = tostring(tr.seatBox.Text):match("^%s*(.-)%s*$")
        if skey ~= "" then
            local seat
            if skey:lower() == "rowingmachines" then
                local own = tr.ownSeatKey()
                if own then seat = findFreeSeat(own) end
            end
            seat = seat or findFreeSeat(skey)
            if seat then
                list[#list + 1] = { label = "kursi", pos = seat.Position + Vector3.new(0, 3, 0), seat = seat }
            end
        end
        local key = tostring(tr.nameBox.Text):match("^%s*(.-)%s*$")
        if key ~= "" then
            local pos = findByName(key, from)
            if pos then list[#list + 1] = { label = "nama", pos = pos } end
        end
        if tr.rel and tr.ref then
            list[#list + 1] = { label = "relatif", pos = tr.ref:PointToWorldSpace(tr.rel) }
        end
        if tr.pos then
            list[#list + 1] = { label = "absolut", pos = tr.pos }
        end
        local out = {}
        for _, t in ipairs(list) do
            if (t.pos - from).Magnitude <= 1500 then out[#out + 1] = t end
        end
        return out
    end

    tr.posBtn.Activated:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        tr.pos = hrp.Position
        if tr.ref then
            tr.rel = tr.ref:PointToObjectSpace(hrp.Position)
            status.Text = "Posisi training disimpan (absolut + relatif ke spawn). Save Config!"
        else
            tr.rel = nil
            status.Text = "Disimpan absolut saja (referensi spawn belum ada). Save Config!"
        end
        refresh()
    end)

    tr.scanBtn.Activated:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        logLine("== Scan area training ==")
        logLine(string.format("pos=%.0f,%.0f,%.0f State=%s", hrp.Position.X, hrp.Position.Y,
            hrp.Position.Z, tostring(attr("State"))))
        logLine("[ref] " .. (tr.ref and "ada" or "belum ada") .. " | rel=" .. tostring(tr.rel))

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { lp.Character }
        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), params)
        if hit and hit.Instance then
            logLine("[bawah] " .. hit.Instance:GetFullName() .. " (" .. hit.Instance.ClassName .. ")")
            local a = hit.Instance.Parent
            local n = 0
            while a and a ~= workspace and n < 6 do
                local attrs = {}
                for k, v in pairs(a:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
                for _, c in ipairs(a:GetChildren()) do
                    if c:IsA("ValueBase") then attrs[#attrs + 1] = c.Name .. "=" .. tostring(c.Value) end
                end
                local extra = ""
                if #attrs > 0 then
                    extra = " {" .. table.concat(attrs, ", ", 1, math.min(#attrs, 6)) .. "}"
                end
                logLine("[induk] " .. a.Name .. " (" .. a.ClassName .. ")" .. extra)
                a = a.Parent
                n += 1
            end
        else
            logLine("[bawah] tidak ada objek di bawah karakter")
        end

        local rl = lp.RespawnLocation
        logLine("[spawn] RespawnLocation=" .. (rl and rl:GetFullName() or "nil"))

        local shown, spawns, nearestSpawn, sd = 0, 0, nil, nil
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local pp = promptPos(d)
                if pp and (pp - hrp.Position).Magnitude <= 25 and shown < 6 then
                    shown += 1
                    logLine("[prompt] " .. d:GetFullName() .. " | " .. d.ActionText .. "/" .. d.ObjectText)
                end
            elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
                if (d.Position - hrp.Position).Magnitude <= 25 and shown < 6 then
                    shown += 1
                    logLine("[seat] " .. d:GetFullName())
                end
            elseif d:IsA("SpawnLocation") then
                spawns += 1
                local dd = (d.Position - hrp.Position).Magnitude
                if not nearestSpawn or dd < sd then nearestSpawn, sd = d, dd end
            end
        end
        logLine("[spawn] jumlah SpawnLocation=" .. spawns)
        if nearestSpawn then
            logLine(string.format("[spawn] terdekat: %s (%.0f studs)", nearestSpawn:GetFullName(), sd))
        end
        logLine("== selesai: tekan Salin Log ==")
    end)

    task.spawn(function()
        local lastTry = os.clock() - 9
        tr.try = 0
        while alive do
            local st = attr("State")
            if trainOn and not running and not bossBusy and getHRP()
                and st ~= nil and st ~= "Training"
                and (os.clock() - lastTry >= 12 or tr.retryNow) then
                tr.retryNow = false
                lastTry = os.clock()
                local list = targets()
                if #list == 0 then
                    local skey = tostring(tr.seatBox.Text):match("%S")
                    if skey then
                        status.Text = "Training: tidak ada kursi kosong ditemukan"
                    else
                        local has = tr.pos or tr.rel or tostring(tr.nameBox.Text):match("%S")
                        status.Text = has and "Training: target di luar jangkauan (server beda?), Set ulang"
                            or "Training: isi nama kursi atau Set Posisi Training dulu"
                    end
                else
                    local i = (tr.try % #list) + 1
                    local t = list[i]
                    local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
                    status.Text = "Training: menuju posisi (" .. t.label .. ")"
                    if trainWalk(t.pos, speed, 2) then
                        if t.seat then trySit(t.seat) end
                        status.Text = "Training: menunggu mulai"
                        if not waitTraining(4) and alive and trainOn and not running and not bossBusy then
                            local p = findTrainPrompt(t.pos)
                            if p then
                                status.Text = "Training: menekan " .. tostring(p.ObjectText)
                                pressPrompt(p)
                                waitTraining(5)
                            end
                        end
                    end
                    if inTraining() then
                        tr.try = i - 1
                        status.Text = "Training dimulai (" .. t.label .. ")"
                    else
                        tr.try = i
                    end
                end
            end
            task.wait(0.5)
        end
    end)

    table.insert(conns, lp.AttributeChanged:Connect(function(name)
        if logOn and name ~= "RowBoostWindow" then
            logLine("[attr] " .. name .. " = " .. tostring(lp:GetAttribute(name)))
        end
    end))
    logBtn.Activated:Connect(function()
        task.delay(0.1, function()
            if logOn then
                logLine("[state] State=" .. tostring(attr("State")) .. " | remote boost="
                    .. tostring(boostRemote ~= nil))
            end
        end)
    end)
end

-- ===== Auto Boss =====
do
    local GuiService = game:GetService("GuiService")
    local VIM
    pcall(function() VIM = game:GetService("VirtualInputManager") end)

    local function say(s)
        bs.status.Text = "Boss: " .. s
        status.Text = "Boss: " .. s
    end

    local function norm(s)
        s = tostring(s or ""):lower():gsub("[^%w%s]", "")
        s = s:gsub("%s+", " ")
        return (s:match("^%s*(.-)%s*$"))
    end

    local function visibleDeep(o)
        local c = o
        while c and c ~= game do
            if c:IsA("GuiObject") and not c.Visible then return false end
            if c:IsA("ScreenGui") then return c.Enabled end
            c = c.Parent
        end
        return false
    end

    local function findByText(key, root, exact)
        key = norm(key)
        if key == "" then return nil end
        for _, o in ipairs((root or pg):GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and not o:IsDescendantOf(gui) then
                local t = norm(o.Text)
                local hit
                if exact then hit = (t == key) else hit = (t:find(key, 1, true) ~= nil) end
                if hit and o.AbsoluteSize.X > 1 and visibleDeep(o) then
                    local btn = (o:IsA("GuiButton") and o) or o:FindFirstAncestorWhichIsA("GuiButton") or o
                    return btn, o
                end
            end
        end
        return nil
    end

    local function groupText(root)
        local parts = {}
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
                parts[#parts + 1] = norm(d.Text)
            end
        end
        return table.concat(parts, " ")
    end

    local function findNotice()
        local key = norm(bs.keyBox.Text)
        if key == "" then return nil end
        local filt = norm(bs.filterBox.Text)
        local goKey = bs.goBox.Text
        for _, o in ipairs(pg:GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and not o:IsDescendantOf(gui)
                and norm(o.Text):find(key, 1, true) and visibleDeep(o) then
                local anc = o.Parent
                for _ = 1, 5 do
                    if not anc or anc == pg then break end
                    local goBtn = findByText(goKey, anc, true)
                    if goBtn then
                        if filt == "" or groupText(anc):find(filt, 1, true) then
                            return goBtn, o
                        end
                        break
                    end
                    anc = anc.Parent
                end
            end
        end
        return nil
    end

    local function findFire()
        return (findByText(bs.fireBox.Text, nil, true))
    end

    local function inRange()
        return findByText(bs.rangeBox.Text, nil, false) ~= nil
    end

    local function findHomeBtn()
        local hkey = tostring(bs.homeNameBox.Text):lower():match("^%s*(.-)%s*$")
        if hkey ~= "" then
            for _, o in ipairs(pg:GetDescendants()) do
                if o:IsA("GuiButton") and not o:IsDescendantOf(gui)
                    and o.Name:lower():find(hkey, 1, true) and o.AbsoluteSize.X > 1 and visibleDeep(o) then
                    return o
                end
            end
        end
        for _, k in ipairs(splitKeys(bs.tpBox.Text)) do
            local tpBtn = findByText(k, nil, false)
            if tpBtn then
                local tpPos = tpBtn.AbsolutePosition
                local tpCy = tpPos.Y + tpBtn.AbsoluteSize.Y / 2
                local root = tpBtn
                for _ = 1, 3 do
                    local p = root.Parent
                    if not p or p:IsA("PlayerGui") then break end
                    root = p
                end
                local best, bx
                for _, o in ipairs(root:GetDescendants()) do
                    if o:IsA("GuiButton") and o ~= tpBtn and not o:IsDescendantOf(tpBtn)
                        and o.AbsoluteSize.X > 1 and visibleDeep(o) then
                        local cy = o.AbsolutePosition.Y + o.AbsoluteSize.Y / 2
                        local right = o.AbsolutePosition.X + o.AbsoluteSize.X
                        if math.abs(cy - tpCy) < 30 and right <= tpPos.X + 4 and (not best or right > bx) then
                            best, bx = o, right
                        end
                    end
                end
                if best then return best end
            end
        end
        return nil
    end

    local function flash(g)
        pcall(function()
            local f = Instance.new("Frame")
            f.BackgroundTransparency = 1
            f.Position = UDim2.fromOffset(g.AbsolutePosition.X, g.AbsolutePosition.Y)
            f.Size = UDim2.fromOffset(g.AbsoluteSize.X, g.AbsoluteSize.Y)
            f.ZIndex = 100
            local s = Instance.new("UIStroke")
            s.Color = Color3.fromRGB(255, 40, 40)
            s.Thickness = 3
            s.Parent = f
            f.Parent = gui
            task.delay(1.5, function() f:Destroy() end)
        end)
    end

    local function guiCenter(g)
        local p, s = g.AbsolutePosition, g.AbsoluteSize
        local x, y = p.X + s.X / 2, p.Y + s.Y / 2
        local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
        if not (sg and sg.IgnoreGuiInset) then
            local inset = GuiService:GetGuiInset()
            x, y = x + inset.X, y + inset.Y
        end
        return x, y + (tonumber(bs.clickYBox.Text) or 0)
    end

    local function clickGui(g, forceMode)
        if not g or not g.Parent then return false end
        local mode = forceMode or bs.mode
        local did = false
        if mode == 1 or mode == 3 then
            local btn = (g:IsA("GuiButton") and g) or g:FindFirstAncestorWhichIsA("GuiButton")
            if btn then
                for _, name in ipairs({ "Activated", "MouseButton1Click" }) do
                    local sig = btn[name]
                    if firesignal then
                        if pcall(firesignal, sig) then did = true end
                    elseif getconnections then
                        local okc, cons = pcall(getconnections, sig)
                        if okc and type(cons) == "table" then
                            for _, c in ipairs(cons) do
                                if pcall(function() c:Fire() end) then did = true end
                            end
                        end
                    end
                end
            end
        end
        if mode == 1 or mode == 2 then
            if VIM then
                local x, y = guiCenter(g)
                if tapScreen(x, y) then did = true end
            end
        end
        return did
    end

    local function walk(target, speed, stopDist, maxT)
        local t0 = os.clock()
        while alive and (bs.on or bs.walkTest) and not running do
            local hrp = getHRP()
            if not hrp then return false end
            local delta = target - hrp.Position
            local dist = delta.Magnitude
            if dist <= stopDist + 0.05 then return true end
            local dt = RunService.Heartbeat:Wait()
            local step = math.min(dist - stopDist, speed * dt)
            local newPos = hrp.Position + delta.Unit * step
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude > 0.01 then
                hrp.CFrame = CFrame.lookAt(newPos, newPos + flat)
            else
                hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if os.clock() - t0 > maxT then return false end
        end
        return false
    end

    local bossObj
    local function bossObjPos()
        local key = tostring(bs.nameBox.Text):lower():match("^%s*(.-)%s*$")
        if key == "" then return nil end
        if not (bossObj and bossObj.Parent) then
            bossObj = nil
            local hrp = getHRP()
            local bd
            for _, d in ipairs(workspace:GetDescendants()) do
                if (d:IsA("Model") or d:IsA("BasePart")) and d.Name:lower():find(key, 1, true)
                    and not (lp.Character and d:IsDescendantOf(lp.Character)) then
                    local p = d:IsA("Model") and d:GetPivot().Position or d.Position
                    local dist = hrp and (p - hrp.Position).Magnitude or 0
                    if not bossObj or dist < bd then bossObj, bd = d, dist end
                end
            end
        end
        if bossObj then
            return bossObj:IsA("Model") and bossObj:GetPivot().Position or bossObj.Position
        end
        return nil
    end

    local function approach(speed, maxT)
        local tgt, stop = bossObjPos(), 12
        if not tgt then tgt, stop = bs.pos, 2 end
        if not tgt then
            say("zona boss belum diset (Set Zona Boss / nama objek)")
            return false
        end
        say("menuju zona boss")
        return walk(tgt, speed, stop, maxT or 40)
    end

    local nextOk = 0
    local nextFight = 0

    local function runBoss(goBtn, inFight)
        bossBusy = true
        bossObj = nil
        local okr, e = pcall(function()
            local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
            local hrp = getHRP()
            if not hrp then return end
            local start = hrp.Position
            if logOn then logLine("[boss] mulai, State=" .. tostring(attr("State"))) end

            if inFight then
                if logOn then logLine("[boss] fight terdeteksi tanpa GO, auto fire") end
            else
                local wait = clamp(tonumber(bs.afterGoBox.Text) or 4, 1, 15)
                local moved = false
                for attempt = 1, 3 do
                    if not (alive and bs.on) then return end
                    local btn = goBtn
                    if not btn or not btn.Parent or not visibleDeep(btn) then
                        btn = findNotice()
                    end
                    if not btn then break end
                    say("tekan GO (" .. attempt .. ")")
                    clickGui(btn, attempt > 1 and 1 or nil)
                    local t0 = os.clock()
                    while os.clock() - t0 < wait and alive and bs.on do
                        task.wait(0.2)
                        local h = getHRP()
                        if h and (h.Position - start).Magnitude > 40 then moved = true break end
                    end
                    if moved then break end
                    goBtn = nil
                end
                if not moved then
                    nextOk = os.clock() + 90
                    say("GO tidak memindahkan karakter (cek Tes GO / metode klik)")
                    return
                end
                task.wait(0.8)
                local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.SeatPart then pcall(function() hum.Sit = false end) end
                if logOn then logLine("[boss] setelah GO, State=" .. tostring(attr("State"))) end

            end

            if inFight then
                if not inRange() then approach(speed, 15) end
            else
                approach(speed)
            end

            local fightMax = clamp(tonumber(bs.fightMaxBox.Text) or 240, 30, 900)
            local tStart = os.clock()
            local seenFire, lastSeen, lastRange = false, os.clock(), 0
            local cached
            say("menunggu fight mulai")
            while alive and bs.on and not running do
                local now = os.clock()
                local fb = cached
                if not (fb and fb.Parent and visibleDeep(fb)) then
                    fb = findFire()
                    cached = fb
                end
                if fb then
                    if not seenFire then
                        seenFire = true
                        say("auto fire")
                        if logOn then logLine("[boss] FIRE terlihat, State=" .. tostring(attr("State"))) end
                    end
                    lastSeen = now
                    clickGui(fb)
                end
                if seenFire and now - lastRange > 1.5 then
                    lastRange = now
                    if not inRange() then approach(speed, 6) end
                end
                if seenFire and now - lastSeen > 4 then break end
                if not seenFire and now - tStart > 90 then
                    say("fight tidak mulai (cek teks FIRE)")
                    break
                end
                if now - tStart > fightMax then break end
                task.wait(0.12)
            end
            if not (alive and bs.on) then return end

            task.wait(1.5)
            say("kembali ke rumah")
            local before = getHRP() and getHRP().Position
            local went = false
            for attempt = 1, 4 do
                if not (alive and bs.on) then return end
                local home = findHomeBtn()
                if home then
                    clickGui(home, attempt > 1 and 1 or nil)
                    local t0 = os.clock()
                    while os.clock() - t0 < 4 and alive and bs.on do
                        task.wait(0.2)
                        local h = getHRP()
                        if h and before and (h.Position - before).Magnitude > 40 then went = true break end
                    end
                    if went then break end
                else
                    task.wait(1)
                end
            end
            if not went and bs.bossRespawnOn and bs.tpBase and alive and bs.on then
                say("tombol rumah tidak ada, respawn ke base")
                if logOn then logLine("[boss] tombol rumah gagal, respawn ke base") end
                went = bs.tpBase("boss")
            end
            if went then
                say("selesai, kembali ke training")
            else
                say("gagal kembali ke base (cek Tes Rumah)")
            end
            task.wait(1)
        end)
        if not okr then
            say("error: " .. tostring(e))
            warn(e)
        end
        nextOk = math.max(nextOk, os.clock() + 30)
        nextFight = os.clock() + 8
        bossBusy = false
        tr.retryNow = true
    end

    task.spawn(function()
        while alive do
            if bs.on and not running and not bossBusy then
                if os.clock() >= nextOk then
                    local goBtn = findNotice()
                    if goBtn then runBoss(goBtn) end
                end
                -- Sudah di arena (GO manual) dan tombol FIRE terlihat: langsung auto fire
                if not bossBusy and os.clock() >= nextFight and findFire() then
                    runBoss(nil, true)
                end
            end
            task.wait(0.5)
        end
    end)

    setBoss = function(on)
        bs.on = on
        bs.btn.Text = "Auto Boss: " .. (on and "ON" or "OFF")
        bs.btn.BackgroundColor3 = on and COL_GREEN or COL_RED
        if on then
            bs.status.Text = "Boss: menunggu notifikasi"
        else
            bs.status.Text = "Boss: mati"
        end
    end
    bs.btn.Activated:Connect(function() setBoss(not bs.on) end)

    local MODE_NAMES = { "SINYAL+SENTUH", "SENTUH saja", "SINYAL saja" }
    setClickMode = function(m)
        m = tonumber(m) or 1
        if m < 1 or m > #MODE_NAMES then m = 1 end
        bs.mode = m
        bs.modeBtn.Text = "Metode klik: " .. MODE_NAMES[m]
    end
    bs.modeBtn.Activated:Connect(function() setClickMode(bs.mode % #MODE_NAMES + 1) end)
    setClickMode(1)

    bs.setZone.Activated:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        bs.pos = hrp.Position
        status.Text = "Zona boss disimpan. Save Config!"
        refresh()
    end)

    bs.testGo.Activated:Connect(function()
        local b = findNotice()
        if not b then
            status.Text = "Tes GO: notifikasi boss tidak terlihat"
            return
        end
        flash(b)
        clickGui(b)
        status.Text = "Tes GO: ditekan (kotak merah = tombol yang ditemukan)"
    end)

    bs.testHome.Activated:Connect(function()
        local b = findHomeBtn()
        if not b then
            status.Text = "Tes Rumah: tombol rumah tidak ditemukan"
            return
        end
        flash(b)
        clickGui(b)
        status.Text = "Tes Rumah: ditekan (kotak merah = tombol yang ditemukan)"
    end)

    bs.testFire.Activated:Connect(function()
        local b = findFire()
        if not b then
            status.Text = "Tes FIRE: tombol FIRE tidak terlihat"
            return
        end
        flash(b)
        clickGui(b)
        status.Text = "Tes FIRE: ditekan (kotak merah = tombol yang ditemukan)"
    end)

    bs.scanBoss.Activated:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        logLine("== Scan objek dekat boss (radius 400) ==")
        local seen, list = {}, {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if (d:IsA("Model") or d:IsA("BasePart")) and not (lp.Character and d:IsDescendantOf(lp.Character)) then
                local p
                if d:IsA("Model") then
                    local okp, pv = pcall(function() return d:GetPivot().Position end)
                    p = okp and pv or nil
                else
                    p = d.Position
                end
                if p then
                    local dist = (p - hrp.Position).Magnitude
                    if dist <= 400 then
                        local isModel = d:IsA("Model")
                        local npc = isModel and d:FindFirstChildOfClass("Humanoid") ~= nil
                            and Players:GetPlayerFromCharacter(d) == nil
                        local e = seen[d.Name]
                        if not e then
                            e = { name = d.Name, n = 0, dist = dist, npc = npc, model = isModel }
                            seen[d.Name] = e
                            list[#list + 1] = e
                        end
                        e.n += 1
                        if dist < e.dist then e.dist = dist end
                        if npc then e.npc = true end
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if a.npc ~= b.npc then return a.npc end
            if a.model ~= b.model then return a.model end
            return a.dist < b.dist
        end)
        for i = 1, math.min(#list, 20) do
            local e = list[i]
            logLine(string.format("[%s] %s x%d, %.0f studs", e.npc and "NPC" or (e.model and "Model" or "Part"),
                e.name, e.n, e.dist))
        end
        if bs.nameBox.Text == "" and list[1] and list[1].npc then
            bs.nameBox.Text = list[1].name
            logLine("Nama objek boss diisi otomatis: " .. list[1].name)
            status.Text = "Nama boss diisi: " .. list[1].name .. " (cek log, Save Config)"
        else
            status.Text = "Scan selesai, lihat tab Log"
        end
    end)

    bs.testWalk.Activated:Connect(function()
        if bossBusy or bs.walkTest then return end
        task.spawn(function()
            bs.walkTest = true
            local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
            local okw = approach(speed, 40)
            bs.walkTest = false
            status.Text = okw and "Tes Jalan: sampai di zona boss" or "Tes Jalan: gagal / zona belum diset"
        end)
    end)

    bs.scanBoss.Activated:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        logLine("== Scan objek boss (radius 500) ==")
        local list, seen = {}, {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Model") and not (lp.Character and d:IsDescendantOf(lp.Character))
                and not Players:GetPlayerFromCharacter(d) then
                local okp, pos = pcall(function() return d:GetPivot().Position end)
                if okp then
                    local dist = (pos - hrp.Position).Magnitude
                    local hum = d:FindFirstChildOfClass("Humanoid") ~= nil
                    if dist <= 500 and not seen[d.Name] and (hum or d.Parent == workspace
                        or (d.Parent and d.Parent:IsA("Folder"))) then
                        seen[d.Name] = true
                        list[#list + 1] = { name = d.Name, dist = dist, hum = hum,
                            path = (d:GetFullName():gsub("^Workspace%.", "")) }
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if a.hum ~= b.hum then return a.hum end
            return a.dist < b.dist
        end)
        if #list == 0 then
            logLine("tidak ada model di dekat (coba dekati bossnya)")
            return
        end
        for i = 1, math.min(#list, 15) do
            local o = list[i]
            logLine(string.format("%s%s | %.0f stud | %s", o.hum and "[NPC] " or "", o.name, o.dist, o.path))
        end
        local top = list[1]
        if top.hum then
            bs.nameBox.Text = top.name
            status.Text = "Nama objek boss terisi: " .. top.name .. " (cek log, Save Config)"
        else
            status.Text = "Tidak ada NPC terdeteksi, lihat daftar di log"
        end
    end)

    bs.scanGui.Activated:Connect(function()
        logLine("== Scan GUI tampil ==")
        local n = 0
        for _, o in ipairs(pg:GetDescendants()) do
            if n >= 50 then break end
            if not o:IsDescendantOf(gui) and (o:IsA("GuiButton") or o:IsA("TextLabel"))
                and o.AbsoluteSize.X > 1 and visibleDeep(o) then
                local txt = ""
                if o:IsA("TextLabel") or o:IsA("TextButton") then txt = o.Text end
                if o:IsA("GuiButton") or txt ~= "" then
                    n += 1
                    local path = (o:GetFullName():gsub("^.-PlayerGui%.", ""))
                    txt = (txt:gsub("\n", " "))
                    logLine(string.format("[gui] %s | %s | %s", path, txt, o.ClassName))
                end
            end
        end
        logLine("== selesai (" .. n .. " item): tekan Salin Log ==")
    end)

    -- ===== Auto Drop telur ukuran kecil (Fixed Auto Tap Reset Viewport) =====
    ;(function()
        local dropOn, dropBusy = false, false
        local multCache

        local function dsay(t)
            bs.dropStatus.Text = "Drop: " .. t
            status.Text = "Drop: " .. t
        end

        local function isMult(o)
            local t = tostring(o.Text):gsub("[\128-\255]", "")
            return t:match("^%s*[xX]?%s*%d+%.%d+%s*$") ~= nil
        end

        local function findMult()
            if multCache and multCache.Parent and isMult(multCache) and visibleDeep(multCache) then
                return multCache
            end
            multCache = nil
            for _, o in ipairs(pg:GetDescendants()) do
                if o:IsA("TextLabel") and o.Text ~= "" and not o:IsDescendantOf(gui)
                    and o.AbsoluteSize.X > 1 and isMult(o) and visibleDeep(o) then
                    multCache = o
                    return o
                end
            end
            return nil
        end

        local function readTier(m)
            local sg = m:FindFirstAncestorWhichIsA("ScreenGui")
            if not sg then return nil end
            local mp, ms = m.AbsolutePosition, m.AbsoluteSize
            local mx = mp.X + ms.X / 2
            local best, bd
            for _, o in ipairs(sg:GetDescendants()) do
                if o ~= m and o:IsA("TextLabel") and o.AbsoluteSize.X > 1 then
                    local t = tostring(o.Text):gsub("[\128-\255]", "")
                    t = t:match("^%s*(%a+)%s*$")
                    if t and t:lower() ~= "luck" and visibleDeep(o) then
                        local p, sz = o.AbsolutePosition, o.AbsoluteSize
                        local dy = p.Y - mp.Y
                        local dx = math.abs(p.X + sz.X / 2 - mx)
                        if dy >= -5 and dy <= 150 and dx <= 160 then
                            local d = dy + dx
                            if not bd or d < bd then best, bd = t, d end
                        end
                    end
                end
            end
            return best
        end

        local function isDropSize(t)
            local n = norm(t)
            for _, k in ipairs(splitKeys(bs.dropSizeBox.Text)) do
                if n == norm(k) then return true end
            end
            return false
        end

        local function findDropBtn(key)
            key = norm(key)
            if key == "" then return nil end
            for _, o in ipairs(pg:GetDescendants()) do
                if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" and not o:IsDescendantOf(gui) then
                    local t = norm(o.Text)
                    if (t == key or t:sub(1, #key + 1) == key .. " ")
                        and o.AbsoluteSize.X > 1 and visibleDeep(o) then
                        local btn = (o:IsA("GuiButton") and o) or o:FindFirstAncestorWhichIsA("GuiButton") or o
                        return btn, o
                    end
                end
            end
            return nil
        end

        -- Hotkey diganti TAP SENTUHAN pada tombolnya (bukan SendKeyEvent),
        -- supaya Roblox tidak pindah ke mode input PC
        local function pressHotkey(lbl)
            if not (VIM and lbl and lbl.Parent) then return false end
            local btn = (lbl:IsA("GuiButton") and lbl) or lbl:FindFirstAncestorWhichIsA("GuiButton") or lbl
            local okp, x, y = pcall(guiCenter, btn)
            if not okp then return false end
            return tapScreen(x, y)
        end

        -- Auto Tap layar kosong (reset UI mode penutup animasi)
        local function resetViewportFocus()
            if not VIM then return end
            pcall(function()
                local cam = workspace.CurrentCamera
                local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
                local rx = vp.X * 0.8
                local ry = vp.Y * 0.5
                tapScreen(rx, ry)
            end)
        end

        local function doDrop()
            local clicks, t0 = 0, os.clock()
            local lastFound = t0

            while alive and dropOn and os.clock() - t0 < 15 and clicks < 10 do
                local b, lbl = findDropBtn(bs.dropTextBox.Text)
                if not b then b, lbl = findDropBtn(bs.dropSureBox.Text) end

                if b then
                    lastFound = os.clock()
                    clicks += 1
                    dsay("tekan tombol (" .. clicks .. ")")

                    clickGui(b)

                    -- pressHotkey kini tap sentuhan (aman, tidak memicu mode PC)
                    pressHotkey(lbl)

                    task.wait(0.35)
                else
                    if clicks > 0 and os.clock() - lastFound > 0.8 then break end
                    if clicks == 0 and os.clock() - t0 > 5 then break end
                    task.wait(0.15)
                end
            end

            if clicks > 0 then
                task.wait(0.2)
                resetViewportFocus()
            end

            return clicks
        end

        task.spawn(function()
            local lastTier, pendingSince, goneSince
            while alive do
                local active = dropOn and not dropBusy
                if active then
                    local now = os.clock()
                    local m = findMult()
                    local tier = m and readTier(m) or nil
                    if tier then
                        if tier ~= lastTier and logOn then logLine("[ukuran] " .. tier) end
                        lastTier = tier
                        pendingSince = pendingSince or now
                        goneSince = nil
                    elseif pendingSince then
                        goneSince = goneSince or now
                        if now - goneSince >= 0.8 or now - pendingSince > 30 then
                            local final = lastTier
                            lastTier, pendingSince, goneSince = nil, nil, nil
                            if final and isDropSize(final) then
                                dropBusy = true
                                dsay("ukuran " .. final:upper() .. ", di-drop")
                                local okd, n = pcall(doDrop)
                                dropBusy = false
                                if okd and n > 0 then
                                    dsay("selesai (" .. n .. " tekan)")
                                else
                                    dsay("tombol DROP tidak ditemukan (cek teks tombol)")
                                end
                            elseif final then
                                dsay("ukuran " .. final:upper() .. ", dipertahankan")
                            end
                        end
                    end
                    task.wait(pendingSince and 0.1 or 0.35)
                else
                    lastTier, pendingSince, goneSince = nil, nil, nil
                    task.wait(0.3)
                end
            end
        end)

        bs.dropSet = function(on)
            dropOn = on
            bs.dropOn = on
            bs.dropBtn.Text = "Auto Drop Small: " .. (on and "ON" or "OFF")
            bs.dropBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
            bs.dropStatus.Text = on and "Drop: menunggu animasi ukuran" or "Drop: mati"
        end
        bs.dropBtn.Activated:Connect(function() bs.dropSet(not dropOn) end)
    end)()

    -- ===== Inventori penuh =====
    ;(function()
        local invOn, lastTrig = true, -math.huge

        local function respawnNow()
            local ch = lp.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local rb = findByText(bs.respawnTextBox.Text, nil, false)
            if rb then
                clickGui(rb)
                task.wait(1.2)
            end
            if lp.Character == ch and hum and hum.Health > 0 then
                pcall(function() hum.Health = 0 end)
                task.wait(1.5)
            end
            if lp.Character == ch and ch and ch.Parent then
                pcall(function() ch:BreakJoints() end)
            end
        end

        -- Teleport ke base = respawn karakter (spawn game = base). Dipakai oleh
        -- inventori penuh, fallback Auto Boss, dan tombol manual.
        local tpBusy = false

        -- Game me-respawn di posisi terakhir, jadi pindah dulu ke zona aman
        local function goSafe(kind)
            local target
            if kind == "boss" then target = bs.safePos else target = bs.safePosSteal end
            target = target or tr.pos
            if not target then
                status.Text = "Zona Aman " .. (kind == "boss" and "Boss" or "Steal") .. " belum diset, respawn tanpa pindah"
                if logOn then logLine("[base] zona aman " .. tostring(kind) .. " belum diset") end
                return false
            end
            local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
            local t0 = os.clock()
            local ok = false
            setStand(true)
            while alive and os.clock() - t0 < 90 do
                local hrp = getHRP()
                if not hrp then break end
                local delta = target - hrp.Position
                local dist = delta.Magnitude
                if dist <= 2 then ok = true break end
                local dt = RunService.Heartbeat:Wait()
                local newPos = hrp.Position + delta.Unit * math.min(dist, speed * dt)
                hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            setStand(false)
            if ok then task.wait(1.2) end -- beri waktu server mencatat posisi
            return ok
        end

        bs.tpBase = function(kind)
            if tpBusy then return false end
            tpBusy = true
            local ch = lp.Character
            status.Text = "Pindah ke zona aman..."
            pcall(goSafe, kind)
            status.Text = "Respawn..."
            pcall(respawnNow)
            local t0 = os.clock()
            while alive and lp.Character == ch and os.clock() - t0 < 10 do task.wait(0.2) end
            local moved = lp.Character ~= ch
            if moved then
                local t1 = os.clock()
                while alive and not getHRP() and os.clock() - t1 < 6 do task.wait(0.2) end
            end
            tpBusy = false
            return moved
        end

        task.spawn(function()
            while alive do
                if invOn and running and os.clock() - lastTrig > 20 then
                    local b, lbl = findByText(bs.invTextBox.Text, nil, false)
                    if b and (not lbl or lbl.TextTransparency < 0.9) then
                        lastTrig = os.clock()
                        if bs.stopSteal then bs.stopSteal() end
                        status.Text = "Inventori penuh: Auto Steal off, respawn"
                        if logOn then logLine("[inventori] penuh, respawn") end
                        local okTp = bs.tpBase("steal")
                        if okTp and bs.invTrainOn then
                            setTrain(true)
                            tr.retryNow = true
                            status.Text = "Inventori penuh: sudah di base, Auto Training ON"
                            if logOn then logLine("[inventori] respawn selesai, training ON") end
                        end
                    end
                end
                task.wait(0.4)
            end
        end)

        bs.invSet = function(on)
            invOn = on
            bs.invOn = on
            bs.invBtn.Text = "Respawn bila inventori penuh: " .. (on and "ON" or "OFF")
            bs.invBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
        end
        bs.invSet(true)
        bs.invBtn.Activated:Connect(function() bs.invSet(not invOn) end)

        local function manualTp(kind)
            if bs.stopSteal then bs.stopSteal() end
            status.Text = "Teleport ke base (respawn)..."
            if logOn then logLine("[base] teleport manual (respawn)") end
            task.spawn(function()
                local ok = bs.tpBase(kind)
                status.Text = ok and "Sudah respawn di base" or "Respawn gagal / sedang berjalan"
            end)
        end
        local function showSafe()
            local v, w = bs.safePos, bs.safePosSteal
            bs.setSafe.Text = v and string.format("Zona Aman Boss: %.0f, %.0f, %.0f (ketuk = ganti)", v.X, v.Y, v.Z)
                or "Set Zona Aman Boss (posisi saya)"
            bs.setSafe2.Text = w and string.format("Zona Aman Steal: %.0f, %.0f, %.0f (ketuk = ganti)", w.X, w.Y, w.Z)
                or "Set Zona Aman Steal (posisi saya)"
        end
        bs.showSafe = showSafe
        bs.setSafe.Activated:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            bs.safePos = hrp.Position
            showSafe()
            status.Text = "Zona aman Boss disimpan. Save Config!"
        end)
        bs.setSafe2.Activated:Connect(function()
            local hrp = getHRP()
            if not hrp then return end
            bs.safePosSteal = hrp.Position
            showSafe()
            status.Text = "Zona aman Steal disimpan. Save Config!"
        end)
        showSafe()
        bs.tpBaseBtn.Activated:Connect(function() manualTp("boss") end)
        bs.tpBaseBtn2.Activated:Connect(function() manualTp("steal") end)

        bs.bossRespawnSet = function(on)
            bs.bossRespawnOn = on
            bs.bossRespawnBtn.Text = "Respawn ke base bila tombol rumah gagal: " .. (on and "ON" or "OFF")
            bs.bossRespawnBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
        end
        bs.bossRespawnBtn.Activated:Connect(function() bs.bossRespawnSet(not bs.bossRespawnOn) end)

        bs.invTrainSet = function(on)
            bs.invTrainOn = on
            bs.invTrainBtn.Text = "Training ON setelah inv penuh: " .. (on and "ON" or "OFF")
            bs.invTrainBtn.BackgroundColor3 = on and COL_GREEN or COL_GREY
        end
        bs.invTrainBtn.Activated:Connect(function() bs.invTrainSet(not bs.invTrainOn) end)
    end)()
end

-- ===== Satu siklus =====
local function cycle(id)
    local speed = clamp(tonumber(speedBox.Text) or 60, 5, 500)
    local afterSteal = math.max(0, tonumber(afterStealBox.Text) or 3)
    local waitFront = math.max(0, tonumber(frontBox.Text) or 1.5)
    local radius = clamp(tonumber(radiusBox.Text) or 100, 5, 2000)
    local z = zones[selected]
    if not z then return end

    if not syncHeight(speed, id) then return end

    status.Text = "Menuju " .. z.name
    if not moveTo(z.pos, speed, 1.5, id) then return end
    if not pause(0.5, id) then return end

    local eggs = collectEggs(z, radius, speed, id)
    if not alivePath(id) then return end
    local c0 = cineCount
    local stolen = doSteals(z, radius, speed, id)
    if not alivePath(id) then return end

    if stolen > 0 then
        local cineKey = cineKeyBox.Text:match("%S")
        if cineKey then
            local timeout = clamp(tonumber(cineTimeoutBox.Text) or 10, 1, 60)
            local t0 = os.clock()
            if cineCount == c0 then status.Text = "Menunggu " .. cineKeyBox.Text end
            while alivePath(id) and cineCount == c0 and os.clock() - t0 < timeout do
                task.wait(0.05)
            end
            if not alivePath(id) then return end
            status.Text = (cineCount > c0) and "GUI terdeteksi, lanjut ke depan"
                or "Batas tunggu habis, lanjut ke depan"
        elseif afterSteal > 0 then
            status.Text = string.format("Steal: %d | jeda %.1f dtk", stolen, afterSteal)
            if not pause(afterSteal, id) then return end
        end
    else
        status.Text = string.format("Pickup: %d | Steal: %d", eggs, stolen)
        if eggs == 0 then
            if not pause(1, id) then return end
        end
    end

    local hh = getHRP()
    if hh then baseY = hh.Position.Y end
    status.Text = "Kembali ke depan"
    if not moveTo(frontPos, speed, 1.5, id) then return end

    status.Text = "Tunggu " .. waitFront .. " dtk"
    pause(waitFront, id)
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

pickBtn.Activated:Connect(function() setPickup(not pickupOn) end)
onlyBtn.Activated:Connect(function() setOnly(not onlyList) end)
stabBtn.Activated:Connect(function() setStab(not stabOn) end)
keepYBtn.Activated:Connect(function() setKeepY(not keepY) end)
syncBtn.Activated:Connect(function() setSyncY(not syncY) end)

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
    if on and not (zones[selected] and frontPos) then
        status.Text = "Lengkapi dulu: pilih zona dan Set Depan"
        return
    end
    if on then
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
bs.stopSteal = function() setRunning(false) end

-- ===== CONFIG (save / load) =====
local FOLDER = "AutoStealConfig"
local hasFS = (writefile and readfile and isfile and isfolder and makefolder) and true or false

local fieldMap = {
    speed = speedBox,
    yOffset = yOffsetBox,
    syncWait = syncWaitBox,
    afterSteal = afterStealBox,
    cineKey = cineKeyBox,
    trainPrompt = tr.promptBox,
    trainName = tr.nameBox,
    trainSeat = tr.seatBox,
    cineTimeout = cineTimeoutBox,
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
    bossKey = bs.keyBox,
    bossFilter = bs.filterBox,
    bossGo = bs.goBox,
    bossAfterGo = bs.afterGoBox,
    bossName = bs.nameBox,
    bossRange = bs.rangeBox,
    bossFire = bs.fireBox,
    bossFightMax = bs.fightMaxBox,
    bossTp = bs.tpBox,
    bossHome = bs.homeNameBox,
    bossClickY = bs.clickYBox,
    dropSizes = bs.dropSizeBox,
    dropText = bs.dropTextBox,
    dropSure = bs.dropSureBox,
    invText = bs.invTextBox,
    respawnText = bs.respawnTextBox,
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
    c.toggles.train = trainOn
    c.toggles.boss = bs.on
    c.toggles.drop = bs.dropOn == true
    c.toggles.inv = bs.invOn == true
    c.toggles.bossRespawn = bs.bossRespawnOn == true
    c.toggles.invTrain = bs.invTrainOn == true
    c.clickMode = bs.mode
    if frontPos then c.front = v3t(frontPos) end
    if tr.pos then c.trainPos = v3t(tr.pos) end
    if tr.rel then c.trainRel = v3t(tr.rel) end
    if bs.pos then c.bossPos = v3t(bs.pos) end
    if bs.safePos then c.safePos = v3t(bs.safePos) end
    if bs.safePosSteal then c.safePosSteal = v3t(bs.safePosSteal) end
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
        if c.toggles.train ~= nil then setTrain(c.toggles.train == true) end
        if c.toggles.boss ~= nil then setBoss(c.toggles.boss == true) end
        if c.toggles.drop ~= nil and bs.dropSet then bs.dropSet(c.toggles.drop == true) end
        if c.toggles.inv ~= nil and bs.invSet then bs.invSet(c.toggles.inv == true) end
        if c.toggles.bossRespawn ~= nil and bs.bossRespawnSet then bs.bossRespawnSet(c.toggles.bossRespawn == true) end
        if c.toggles.invTrain ~= nil and bs.invTrainSet then bs.invTrainSet(c.toggles.invTrain == true) end
    end
    if type(c.clickMode) == "number" then setClickMode(c.clickMode) end
    frontPos = t3v(c.front)
    tr.pos = t3v(c.trainPos)
    tr.rel = t3v(c.trainRel)
    bs.pos = t3v(c.bossPos)
    bs.safePos = t3v(c.safePos)
    bs.safePosSteal = t3v(c.safePosSteal)
    if bs.showSafe then bs.showSafe() end
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

-- ===== Notifikasi Discord =====
do
    local GuiService = game:GetService("GuiService")
    local NOTIF_FILE = FOLDER .. "/_notif.json"
    local MASK = "(tersimpan - ketik untuk ganti)"
    local stored = ""
    local lastSent = -math.huge

    local CODES = {
        [267] = "dikeluarkan (kick) oleh game/developer",
        [268] = "dikeluarkan karena perilaku client dianggap tidak wajar",
        [273] = "akun yang sama masuk dari perangkat lain",
        [277] = "koneksi ke server terputus",
        [278] = "dikeluarkan karena tidak ada aktivitas (idle)",
        [279] = "gagal terhubung ke game",
    }

    local function nz(v)
        v = tostring(v or "")
        return v == "" and "-" or v
    end

    local function validUrl(u)
        u = tostring(u or ""):match("^%s*(.-)%s*$")
        for _, h in ipairs({ "discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com" }) do
            local prefix = "https://" .. h .. "/api/webhooks/"
            if u:sub(1, #prefix) == prefix and u:sub(#prefix + 1):match("^%d+/[%w_%-]+$") then
                return true
            end
        end
        return false
    end

    local function currentUrl()
        local t = tostring(nf.url.Text or ""):match("^%s*(.-)%s*$")
        if t:sub(1, 8) == "https://" then return t end
        return stored
    end

    local function setNotif(on)
        nf.on = on
        nf.btn.Text = "Notif Discord: " .. (on and "ON" or "OFF")
        nf.btn.BackgroundColor3 = on and COL_GREEN or COL_GREY
    end

    local function saveNotif()
        if not hasFS then return false end
        return pcall(function()
            if not isfolder(FOLDER) then makefolder(FOLDER) end
            writefile(NOTIF_FILE, HttpService:JSONEncode({
                url = stored, ping = nf.ping.Text, on = nf.on,
            }))
        end)
    end

    local function post(url, payload)
        local req = (syn and syn.request) or request or http_request or (fluxus and fluxus.request)
        if not req then return false, "executor tidak mendukung request" end
        local okr, res = pcall(req, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
        if not okr then return false, tostring(res) end
        local code = type(res) == "table" and (res.StatusCode or res.status_code) or nil
        if code and code >= 200 and code < 300 then return true end
        return false, "HTTP " .. tostring(code)
    end

    local function notify(title, desc, color)
        local url = currentUrl()
        if not validUrl(url) then return false, "URL webhook belum valid" end
        local ping = tostring(nf.ping.Text or ""):match("^%s*(%d+)%s*$")
        return post(url, {
            username = "AutoSteal",
            content = ping and ("<@" .. ping .. ">") or nil,
            embeds = {{
                title = title,
                description = desc,
                color = color,
                fields = {
                    { name = "Akun", value = nz(lp.Name), inline = true },
                    { name = "PlaceId", value = nz(game.PlaceId), inline = true },
                    { name = "Server", value = nz(tostring(game.JobId):sub(1, 8)), inline = true },
                    { name = "Status script", value = nz(tostring(status.Text):sub(1, 100)), inline = false },
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }},
        })
    end

    local function onDisconnect(msg)
        if not alive or not nf.on then return end
        msg = tostring(msg or "")
        if msg == "" then return end
        if os.clock() - lastSent < 20 then return end
        lastSent = os.clock()
        local code = tonumber(msg:match("[Ee]rror [Cc]ode:?%s*(%d+)"))
        local desc = "**Pesan dari game:**\n" .. msg:sub(1, 500)
        if code then
            desc = desc .. "\n\n**Kode " .. code .. "**"
            if CODES[code] then desc = desc .. ": " .. CODES[code] end
        end
        task.spawn(function()
            local okn, err = notify("Karakter terputus / terkick", desc, 15158332)
            if not okn then warn("Notif Discord gagal: " .. tostring(err)) end
        end)
    end

    table.insert(conns, GuiService.ErrorMessageChanged:Connect(function()
        local okm, msg = pcall(function() return GuiService:GetErrorMessage() end)
        if okm and msg and msg ~= "" then onDisconnect(msg) end
    end))

    task.spawn(function()
        pcall(function()
            local cg = game:GetService("CoreGui")
            local gui2 = cg:WaitForChild("RobloxPromptGui", 10)
            local overlay = gui2 and gui2:WaitForChild("promptOverlay", 10)
            if not overlay then return end
            table.insert(conns, overlay.ChildAdded:Connect(function(ch)
                if ch.Name ~= "ErrorPrompt" then return end
                task.wait(0.3)
                local best = ""
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("TextLabel") and #d.Text > #best then best = d.Text end
                end
                onDisconnect(best)
            end))
        end)
    end)

    nf.btn.Activated:Connect(function()
        if not nf.on and not validUrl(currentUrl()) then
            status.Text = "Isi URL webhook Discord dulu, lalu tekan Simpan & Tes"
            return
        end
        setNotif(not nf.on)
        saveNotif()
        status.Text = "Notif Discord: " .. (nf.on and "aktif" or "mati")
    end)

    nf.test.Activated:Connect(function()
        local url = currentUrl()
        if not validUrl(url) then
            status.Text = "URL tidak valid (harus URL webhook Discord)"
            return
        end
        stored = url
        nf.url.Text = MASK
        saveNotif()
        status.Text = "Mengirim tes ke Discord..."
        task.spawn(function()
            local okn, err = notify("Tes notifikasi",
                "Webhook terhubung. Pesan akan dikirim kalau karakter terputus atau terkick.", 3447003)
            status.Text = okn and "Tes terkirim ke Discord" or ("Tes gagal: " .. tostring(err))
        end)
    end)

    nf.ping.FocusLost:Connect(function() saveNotif() end)

    if hasFS then
        pcall(function()
            if isfile(NOTIF_FILE) then
                local d = HttpService:JSONDecode(readfile(NOTIF_FILE))
                if type(d) == "table" then
                    if type(d.url) == "string" and validUrl(d.url) then
                        stored = d.url
                        nf.url.Text = MASK
                    end
                    if type(d.ping) == "string" then nf.ping.Text = d.ping end
                    setNotif(d.on == true and stored ~= "")
                end
            end
        end)
    end
    if nf.on then
        task.spawn(function()
            notify("Script aktif",
                "Script dijalankan. Kalau pesan ini muncul tanpa Anda menjalankannya, berarti game reconnect dan script ter-eksekusi ulang.",
                3066993)
        end)
    end
end

-- ===== HUD FPS & Ping =====
do
    local Stats = game:GetService("Stats")

    local hud = Instance.new("TextLabel")
    hud.Name = "FpsPingHUD"
    hud.Size = UDim2.new(0, 120, 0, 40)
    hud.Position = UDim2.new(1, -130, 0, 10)
    hud.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    hud.BackgroundTransparency = 0.25
    hud.BorderSizePixel = 0
    hud.Font = Enum.Font.GothamBold
    hud.TextSize = 12
    hud.TextColor3 = Color3.new(1, 1, 1)
    hud.Text = "FPS: --\nPing: -- ms"
    hud.Parent = gui
    round(hud, 8)

    -- Tombol toggle 3D rendering (hemat GPU/baterai untuk AFK lama)
    local render3d = true
    local rBtn = Instance.new("TextButton")
    rBtn.Name = "Toggle3DRender"
    rBtn.Size = UDim2.new(0, 120, 0, 28)
    rBtn.Position = UDim2.new(1, -130, 0, 56)
    rBtn.BackgroundColor3 = COL_GREEN
    rBtn.Text = "3D: ON"
    rBtn.TextColor3 = Color3.new(1, 1, 1)
    rBtn.Font = Enum.Font.GothamBold
    rBtn.TextSize = 12
    rBtn.Parent = gui
    round(rBtn, 8)

    local function set3d(on)
        render3d = on
        pcall(function() RunService:Set3dRenderingEnabled(on) end)
        rBtn.Text = on and "3D: ON" or "3D: OFF"
        rBtn.BackgroundColor3 = on and COL_GREEN or COL_RED
    end
    rBtn.Activated:Connect(function() set3d(not render3d) end)

    -- Pastikan 3D menyala lagi saat script ditutup / dijalankan ulang
    table.insert(conns, { Disconnect = function()
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end })

    local function getPing()
        local ms
        pcall(function()
            ms = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if not ms then
            pcall(function() ms = lp:GetNetworkPing() * 1000 end)
        end
        return ms
    end

    local frames, last = 0, os.clock()
    table.insert(conns, RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last < 0.5 then return end
        local fps = frames / (now - last)
        frames, last = 0, now

        local ping = getPing()
        local fpsCol = fps >= 50 and COL_GREEN or (fps >= 30 and Color3.fromRGB(220, 170, 40) or COL_RED)
        local pingCol = (not ping and COL_GREY) or (ping <= 100 and COL_GREEN) or (ping <= 200 and Color3.fromRGB(220, 170, 40)) or COL_RED

        hud.Text = string.format("FPS: %s\nPing: %s", render3d and tostring(math.floor(fps + 0.5)) or "3D off", ping and (math.floor(ping + 0.5) .. " ms") or "--")
        hud.TextColor3 = (fpsCol == COL_GREEN and pingCol == COL_GREEN) and Color3.new(1, 1, 1)
            or ((fpsCol == COL_RED or pingCol == COL_RED) and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 220, 120))
    end))
end

-- ===== Minimize / close =====
local minimized = false
minBtn.Activated:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    main.Size = UDim2.new(0, 260, 0, minimized and 32 or FULL_H)
    minBtn.Text = minimized and "+" or "-"
end)

local function close()
    alive, running, trainOn = false, false, false
    bs.on = false
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
