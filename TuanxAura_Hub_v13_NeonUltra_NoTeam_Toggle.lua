-- TuanxAura_Hub_v13_NeonUltra_NoTeam_Toggle.lua
-- Features:
-- - Neon blue UI with loading progress (%) and typewriter header
-- - AutoFindFruit (priority: Mythic -> Legendary -> Rare -> Common)
-- - AutoStoreFruit (skip if owned or bag full)
-- - AutoHop if no fruit seen for 30 seconds
-- - AutoRejoin and optional AutoExecute toggle in config
-- - Safe Tween teleport to fruit with fallback
-- - Notify in Vietnamese with emoji (immediate, non-blocking)
-- - Display distance to targeted fruit
-- - Toggle UI button (square with rounded corners) centered at bottom + RightShift hotkey
-- - NO auto join team, NO player lock, NO auto clean map
-- Save and run using an executor that supports writefile/readfile/getgenv, etc.

local DEFAULT_SETTINGS = {
    AutoFindFruit = true,
    AutoStoreFruit = true,
    AutoHop = true,
    AutoRejoinOnHopFail = true,
    AutoExecute = true,
    FruitScanInterval = 1.0,
    HopTimeoutSeconds = 30,
    SafeTeleportSpeed = 1500,
}

repeat task.wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer and (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())

getgenv().Ran = getgenv().Ran or false
if getgenv().Ran then return end
getgenv().Ran = true

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = (pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser")) or nil

local CONFIG_FILE = "TuanxAura_v13_Config.json"
local THEME = Color3.fromRGB(0,255,230)
local FONT_HEADER = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.Ubuntu

local function safe_write(file, content) if writefile then pcall(writefile, file, content) end end
local function safe_read(file) if isfile and isfile(file) then return readfile(file) end end

local _G_Settings = {}
for k,v in pairs(DEFAULT_SETTINGS) do _G_Settings[k] = v end

local function LoadConfig()
    local txt = safe_read(CONFIG_FILE)
    if txt then
        pcall(function()
            local dat = HttpService:JSONDecode(txt)
            for k,v in pairs(dat) do if _G_Settings[k] ~= nil then _G_Settings[k] = v end end
        end)
    end
end
local saveDeb = false
local function SaveConfig()
    if saveDeb then return end
    saveDeb = true
    task.spawn(function()
        task.wait(0.5)
        pcall(function() safe_write(CONFIG_FILE, HttpService:JSONEncode(_G_Settings)) end)
        saveDeb = false
    end)
end
LoadConfig()

-- Notify
if CoreGui:FindFirstChild("TuanxAura_v13_GUI") then pcall(function() CoreGui.TuanxAura_v13_GUI:Destroy() end) end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TuanxAura_v13_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local NotifyRoot = Instance.new("Frame")
NotifyRoot.Name = "NotifyRoot"
NotifyRoot.AnchorPoint = Vector2.new(0.5,0)
NotifyRoot.Position = UDim2.new(0.5,0,0.08,0)
NotifyRoot.Size = UDim2.new(0,420,0,56)
NotifyRoot.BackgroundTransparency = 1
NotifyRoot.Parent = ScreenGui

local function showNotify(text, duration)
    duration = duration or 2.6
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,380,0,44)
    frame.Position = UDim2.new(0.5,0,-0.2,0)
    frame.AnchorPoint = Vector2.new(0.5,0)
    frame.BackgroundColor3 = Color3.fromRGB(10,10,14)
    frame.Parent = NotifyRoot
    frame.ClipsDescendants = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = THEME; stroke.Transparency = 0.8; stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1,-16,1,0); lbl.Position = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1; lbl.Font = FONT_BODY; lbl.TextSize = 16
    lbl.TextColor3 = Color3.fromRGB(230,240,255); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    frame.Position = UDim2.new(0.5,0,-0.2,0)
    local showTw = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0,0)})
    showTw:Play()
    task.delay(duration, function()
        local hide = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5,0,-0.2,0)})
        hide:Play()
        hide.Completed:Connect(function() pcall(function() frame:Destroy() end) end)
    end)
end

local function NotifyVN(key, a)
    local mapping = {
        started = "💙 TuanxAura Hub: Đã khởi động! Cấu hình đã được tải.",
        saved = "💾 Cấu hình đã lưu.",
        invalid = "⚠️ Giá trị không hợp lệ, đã khôi phục.",
        stored = "🍈 Đã lưu trái thành công!",
        bagfull = "🧺 Kho trái đã đầy, bỏ qua trái này.",
        owned = "🔁 Đã có trái này, bỏ qua.",
        fruitfound = ("🥭 Phát hiện trái: %s"):format(tostring(a or "Unknown")),
        waiting = "💤 Đang chờ trái xuất hiện...",
        autohop = "🌍 Không có trái sau 30 giây, đang chuyển máy chủ...",
        rejoin = "🔁 Mất kết nối, đang vào lại...",
        rejoinok = "✅ Đã vào lại máy chủ!",
    }
    if type(key)=="string" and string.find(key," ") then showNotify(key) else showNotify(mapping[key] or tostring(key)) end
end

-- Loading UI
local LoadingGui = Instance.new("Frame")
LoadingGui.Name = "LoadingGui"
LoadingGui.AnchorPoint = Vector2.new(0.5,0.5)
LoadingGui.Position = UDim2.new(0.5,0,0.5,0)
LoadingGui.Size = UDim2.new(0,420,0,160)
LoadingGui.BackgroundColor3 = Color3.fromRGB(8,8,10)
Instance.new("UICorner", LoadingGui).CornerRadius = UDim.new(0,12)
LoadingGui.Parent = ScreenGui

local header = Instance.new("TextLabel", LoadingGui)
header.Name = "Header"; header.Size = UDim2.new(1,-28,0,46); header.Position = UDim2.new(0,14,0,12)
header.BackgroundTransparency = 1; header.Font = FONT_HEADER; header.TextSize = 22; header.TextColor3 = THEME
header.Text = ""; header.TextXAlignment = Enum.TextXAlignment.Center

local subtitle = Instance.new("TextLabel", LoadingGui)
subtitle.Name = "Subtitle"; subtitle.Size = UDim2.new(1,-28,0,18); subtitle.Position = UDim2.new(0,14,0,64)
subtitle.BackgroundTransparency = 1; subtitle.Font = FONT_BODY; subtitle.TextSize = 14; subtitle.TextColor3 = Color3.fromRGB(170,230,210)
subtitle.Text = "🔍 Đang chuẩn bị..." ; subtitle.TextXAlignment = Enum.TextXAlignment.Center

local progressBarBg = Instance.new("Frame", LoadingGui)
progressBarBg.Name = "PB_BG"; progressBarBg.Position = UDim2.new(0.06,0,0,100); progressBarBg.Size = UDim2.new(0.88,0,0,14)
progressBarBg.BackgroundColor3 = Color3.fromRGB(18,18,20); Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0,8)

local progressBar = Instance.new("Frame", progressBarBg)
progressBar.Name = "PB"; progressBar.Size = UDim2.new(0,0,1,0); progressBar.BackgroundColor3 = THEME; Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0,8)

local progressLabel = Instance.new("TextLabel", LoadingGui)
progressLabel.Name = "PLabel"; progressLabel.Size = UDim2.new(0.2,0,0,18); progressLabel.Position = UDim2.new(0.8,0,0,70)
progressLabel.BackgroundTransparency = 1; progressLabel.Font = FONT_BODY; progressLabel.TextSize = 13; progressLabel.TextColor3 = Color3.fromRGB(200,255,245)
progressLabel.Text = "0%"; progressLabel.TextXAlignment = Enum.TextXAlignment.Right

local function LoadingSequence()
    local title = "💎 TUANXAURA HUB 💙"
    header.Text = ""
    for i = 1, #title do
        header.Text = string.sub(title,1,i)
        task.wait(0.03)
    end
    local stages = {
        {text="🔍 Đang tải module...", t=0.25},
        {text="⚙️ Khởi tạo hệ thống...", t=0.30},
        {text="🧠 Kết nối dữ liệu...", t=0.30},
        {text="🚀 Hoàn tất! Sẵn sàng...", t=0.15},
    }
    local pct = 0
    for _,st in pairs(stages) do
        subtitle.Text = st.text
        local target = pct + math.floor(st.t*100)
        while pct < target do
            pct = math.clamp(pct + math.random(3,8), 0, 100)
            progressBar:TweenSize(UDim2.new(pct/100,0,1,0), "Out", "Quad", 0.06, true)
            progressLabel.Text = tostring(math.floor(pct)).."%"
            task.wait(0.02)
        end
    end
    progressBar:TweenSize(UDim2.new(1,0,1,0), "Out", "Quad", 0.25, true)
    progressLabel.Text = "100%"
    subtitle.Text = "✅ Hoàn tất! Chào "..(LocalPlayer.Name or "Người chơi")
    task.wait(0.8)
    local fade = TweenService:Create(LoadingGui, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
    fade:Play()
    fade.Completed:Wait()
    pcall(function() LoadingGui:Destroy() end)
end
task.spawn(LoadingSequence)

-- Main UI
local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"
MainContainer.AnchorPoint = Vector2.new(0.5,0.5)
MainContainer.Position = UDim2.new(0.5,0,0.5,0)
MainContainer.Size = UDim2.new(0,420,0,120)
MainContainer.BackgroundColor3 = Color3.fromRGB(8,8,10)
Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0,12)
MainContainer.Parent = ScreenGui

local header2 = Instance.new("TextLabel", MainContainer)
header2.Name = "Header2"; header2.Size = UDim2.new(1,-28,0,38); header2.Position = UDim2.new(0,14,0,10)
header2.BackgroundTransparency = 1; header2.Font = FONT_HEADER; header2.TextSize = 20; header2.TextColor3 = THEME
header2.Text = "💎 TUANXAURA HUB 💙"; header2.TextXAlignment = Enum.TextXAlignment.Center

local statusLabel = Instance.new("TextLabel", MainContainer)
statusLabel.Name = "Status"; statusLabel.Size = UDim2.new(1,-28,0,22); statusLabel.Position = UDim2.new(0,14,0,52)
statusLabel.BackgroundTransparency = 1; statusLabel.Font = FONT_BODY; statusLabel.TextSize = 14; statusLabel.TextColor3 = Color3.fromRGB(170,230,210)
statusLabel.Text = "🛰️ Trạng thái: Đang khởi động..." ; statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local userLabel = Instance.new("TextLabel", MainContainer)
userLabel.Name = "User"; userLabel.Size = UDim2.new(0.5, -20,0,18); userLabel.Position = UDim2.new(0,14,1,-28)
userLabel.BackgroundTransparency = 1; userLabel.Font = FONT_BODY; userLabel.TextSize = 13; userLabel.TextColor3 = Color3.fromRGB(200,230,255)
userLabel.Text = "👤 Người chơi: "..(LocalPlayer.Name or "Unknown"); userLabel.TextXAlignment = Enum.TextXAlignment.Left

local distLabel = Instance.new("TextLabel", MainContainer)
distLabel.Name = "Dist"; distLabel.Size = UDim2.new(0.5, -20,0,18); distLabel.Position = UDim2.new(1,-210,1,-28)
distLabel.BackgroundTransparency = 1; distLabel.Font = FONT_BODY; distLabel.TextSize = 13; distLabel.TextColor3 = Color3.fromRGB(200,230,255)
distLabel.Text = "🍍 Cách: -- m"; distLabel.TextXAlignment = Enum.TextXAlignment.Right

task.spawn(function()
    while MainContainer.Parent do
        pcall(function()
            local a = TweenService:Create(header2, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = Color3.fromRGB(120,255,200)})
            a:Play(); a.Completed:Wait()
            local b = TweenService:Create(header2, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = THEME})
            b:Play(); b.Completed:Wait()
        end)
        task.wait(0.05)
    end
end)

-- Toggle button square rounded, center bottom
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleUIButton"
toggleButton.Size = UDim2.new(0,64,0,38)
toggleButton.Position = UDim2.new(0.5, -32, 1, -76)
toggleButton.AnchorPoint = Vector2.new(0.5,1)
toggleButton.BackgroundColor3 = Color3.fromRGB(12,12,14)
toggleButton.BorderSizePixel = 0
toggleButton.AutoButtonColor = true
toggleButton.Text = "UI"
toggleButton.Font = FONT_BODY
toggleButton.TextSize = 14
toggleButton.TextColor3 = Color3.fromRGB(200,255,245)
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0,10)
local strokeTB = Instance.new("UIStroke", toggleButton); strokeTB.Color = THEME; strokeTB.Transparency = 0.7; strokeTB.Thickness = 1.5
toggleButton.Parent = ScreenGui

local uiVisible = true
local function SetUIVisible(v)
    uiVisible = v
    if v then
        MainContainer.Visible = true
        TweenService:Create(MainContainer, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5,0,0.5,0), BackgroundTransparency = 0}):Play()
    else
        TweenService:Create(MainContainer, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5,0,0.75,0), BackgroundTransparency = 1}):Play()
        task.delay(0.3, function() MainContainer.Visible = false end)
    end
end

toggleButton.MouseButton1Click:Connect(function() SetUIVisible(not uiVisible) end)
UserInputService.InputBegan:Connect(function(input, gpe) if not gpe and input.KeyCode == Enum.KeyCode.RightShift then SetUIVisible(not uiVisible) end end)
toggleButton.MouseEnter:Connect(function() showNotify("💡 Bật/Tắt Hub UI") end)

-- PRIORITY lists
local PRIORITY = {
    Mythic = {"leopard","dragon","kitsune","t-rex","tyrant","spirit","control","gravity","venom","shadow","dough"},
    Legendary = {"buddha","magma","phoenix","string","quake","light","ice","love"},
    Rare = {"flame","sand","dark","diamond","rubber"},
}
local tierValue = {Mythic=4,Legendary=3,Rare=2,Common=1}
local function fruitTier(name)
    if not name then return "Common" end
    local n = string.lower(name)
    for _,v in pairs(PRIORITY.Mythic) do if string.find(n,v) then return "Mythic" end end
    for _,v in pairs(PRIORITY.Legendary) do if string.find(n,v) then return "Legendary" end end
    for _,v in pairs(PRIORITY.Rare) do if string.find(n,v) then return "Rare" end end
    return "Common"
end

local function scanFruits()
    local fruits = {}
    for _,obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(obj.Name,"Fruit") and obj:FindFirstChild("Handle") then
            if not obj:IsDescendantOf(LocalPlayer.Character) then table.insert(fruits,obj) end
        end
    end
    return fruits
end

local function chooseBestFruit(list)
    if not list or #list==0 then return nil end
    local best, score = nil, -1
    for _,f in pairs(list) do
        local name = f.Name or (f:GetAttribute and f:GetAttribute("OriginalName")) or ""
        local tier = fruitTier(name)
        local s = tierValue[tier] or 1
        if f:FindFirstChild("Handle") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (f.Handle.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            s = s + (1 / math.max(1, dist/50))
        end
        if s > score then best,score = f,s end
    end
    return best
end

-- Safe tween to pos
local function SafeTweenToPosition(pos, speed)
    if not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    local time = math.clamp(dist / (speed or _G_Settings.SafeTeleportSpeed), 0.35, 3.5)
    local ok = pcall(function()
        local tw = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(pos + Vector3.new(0,2,0))})
        tw:Play(); tw.Completed:Wait()
    end)
    if not ok then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0,2,0)) end) end
end

-- Attempt store
local function AttemptStoreFruit()
    if not _G_Settings.AutoStoreFruit then return false end
    local success = false
    pcall(function()
        local held = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if held and string.find(held.Name,"Fruit") then
            local name = held:GetAttribute("OriginalName") or held.Name
            local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", name, held) end)
            if ok and res and res ~= false and res ~= "Full" then success = true; NotifyVN("stored") else NotifyVN("bagfull") end
        end
    end)
    pcall(function()
        for _,tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool and string.find(tool.Name,"Fruit") then
                local name = tool:GetAttribute("OriginalName") or tool.Name
                local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", name, tool) end)
                if ok and res and res ~= false and res ~= "Full" then success = true; NotifyVN("stored") end
            end
        end
    end)
    return success
end

-- Server hop
local function ExecuteServerHop()
    NotifyVN("autohop")
    local PlaceId = game.PlaceId; local JobId = game.JobId
    local cursor=""; local blacklist={}
    if isfile and isfile("NotSameServers.json") then pcall(function() blacklist = HttpService:JSONDecode(readfile("NotSameServers.json")) end) end
    if #blacklist==0 then table.insert(blacklist,os.time()) end
    for page=1,5 do
        local url = "https://games.roblox.com/v1/games/"..tostring(PlaceId).."/servers/Public?limit=100&sortOrder=Asc"
        if cursor~="" then url = url.."&cursor="..tostring(cursor) end
        local ok,res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then NotifyVN("serverfail"); break end
        local ok2,data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then NotifyVN("serverfail"); break end
        cursor = data.nextPageCursor or ""
        for _,s in pairs(data.data) do
            if tostring(s.id)~=tostring(JobId) and tonumber(s.playing) < tonumber(s.maxPlayers) then
                local sid = tostring(s.id); local skip=false
                for _,b in pairs(blacklist) do if tostring(b)==sid then skip=true; break end end
                if not skip then
                    table.insert(blacklist,sid)
                    pcall(function() safe_write("NotSameServers.json", HttpService:JSONEncode(blacklist)) end)
                    pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, sid, LocalPlayer) end)
                    return
                end
            end
        end
        task.wait(0.2)
    end
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

-- Auto rejoin basic
local rejoinAttempts = 0
local function TryRejoin()
    if rejoinAttempts > 3 then return end
    rejoinAttempts = rejoinAttempts + 1
    NotifyVN("rejoin")
    task.wait(2)
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

task.spawn(function()
    while true do
        if not LocalPlayer or not LocalPlayer.Parent then pcall(TryRejoin) end
        task.wait(3)
    end
end)

-- MAIN loop
local lastScan = 0
local noFruitTimer = 0
local currentTarget = nil

task.spawn(function()
    while true do
        local now = tick()
        if now - lastScan >= (_G_Settings.FruitScanInterval or 1) then
            lastScan = now
            local fruits = scanFruits()
            if #fruits > 0 then
                noFruitTimer = 0
                local best = chooseBestFruit(fruits)
                if best then
                    currentTarget = best
                    local name = best.Name or (best:GetAttribute and best:GetAttribute("OriginalName")) or "Unknown"
                    NotifyVN("fruitfound", name)
                    statusLabel.Text = "🥭 Đang di chuyển tới: "..name
                    if best:FindFirstChild("Handle") then
                        pcall(function() SafeTweenToPosition(best.Handle.Position, _G_Settings.SafeTeleportSpeed) end)
                        task.wait(0.5)
                        pcall(function() AttemptStoreFruit() end)
                    end
                end
            else
                noFruitTimer = noFruitTimer + (_G_Settings.FruitScanInterval or 1)
                statusLabel.Text = ("💤 Không thấy trái... (%.1fs)"):format(noFruitTimer)
                if _G_Settings.AutoHop and noFruitTimer >= (_G_Settings.HopTimeoutSeconds or 30) then
                    noFruitTimer = 0
                    task.spawn(function() ExecuteServerHop() end)
                end
            end
        end

        -- update distance
        pcall(function()
            if currentTarget and currentTarget:FindFirstChild("Handle") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local d = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Handle.Position).Magnitude)
                distLabel.Text = "🍍 Cách: "..tostring(d).." m"
            else
                distLabel.Text = "🍍 Cách: -- m"
            end
        end)

        task.wait(0.12)
    end
end)

-- periodic auto-store
task.spawn(function()
    while true do
        pcall(AttemptStoreFruit)
        task.wait(2)
    end
end)

-- config autosave
task.spawn(function()
    while true do SaveConfig(); task.wait(60) end
end)

-- anti-afk
if VirtualUser then
    LocalPlayer.Idled:Connect(function()
        pcall(function() VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end)
    end)
end

-- ready notify
task.spawn(function() task.wait(1.2); NotifyVN("started") end)

-- AutoExecute on respawn/join (best-effort)
if _G_Settings.AutoExecute then
    task.spawn(function()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(2)
            if _G_Settings.AutoExecute then
                pcall(function()
                    if readfile and isfile and isfile("TuanxAura_Hub_v13_NoTeam.lua") then
                        local s = readfile("TuanxAura_Hub_v13_NoTeam.lua")
                        if s then
                            local f,err = loadstring(s)
                            if f then pcall(f) end
                        end
                    end
                end)
            end
        end)
    end)
end

-- end
