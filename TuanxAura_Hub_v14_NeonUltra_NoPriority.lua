-- TuanxAura_Hub_v14_NeonUltra_NoPriority.lua
-- Version: v14 (No fruit priority - picks fruits in discovery order)
-- Features: Neon UI, AutoFindFruit (first found), AutoStore, AutoHop after 30s, SafeTween, Notify VN

local DEFAULT_SETTINGS = {
    AutoFindFruit = true,
    AutoStoreFruit = true,
    AutoHop = true,
    AutoRejoinOnHopFail = true,
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
local UserInputService = game:GetService("UserInputService")

local THEME = Color3.fromRGB(0,255,230)
local FONT_HEADER = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.Ubuntu

local function safe_write(name, content)
    if type(writefile) == "function" then pcall(writefile, name, content) end
end
local function safe_read(name)
    if type(isfile) == "function" and isfile(name) then local ok,txt = pcall(function() return readfile(name) end); if ok then return txt end end; return nil
end

if CoreGui:FindFirstChild("TuanxAura_v14_GUI") then pcall(function() CoreGui.TuanxAura_v14_GUI:Destroy() end) end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TuanxAura_v14_GUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.Parent = CoreGui

local NotifyRoot = Instance.new("Frame")
NotifyRoot.Name = "NotifyRoot"; NotifyRoot.AnchorPoint = Vector2.new(0.5,0); NotifyRoot.Position = UDim2.new(0.5,0,0.06,0)
NotifyRoot.Size = UDim2.new(0,420,0,60); NotifyRoot.BackgroundTransparency = 1; NotifyRoot.Parent = ScreenGui

local function makeNotify(msg, duration)
    duration = duration or 2.6
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,380,0,44); frame.Position = UDim2.new(0.5,0,-0.2,0); frame.AnchorPoint = Vector2.new(0.5,0)
    frame.BackgroundColor3 = Color3.fromRGB(12,12,14); frame.ClipsDescendants = true; frame.Parent = NotifyRoot
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = THEME; stroke.Transparency = 0.8; stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1,-16,1,0); lbl.Position = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1; lbl.Font = FONT_BODY; lbl.TextSize = 16; lbl.TextColor3 = Color3.fromRGB(230,240,255); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = msg
    local showTw = TweenService:Create(frame, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0,0)})
    showTw:Play()
    task.delay(duration, function()
        local hide = TweenService:Create(frame, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5,0,-0.2,0)})
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
    if type(key) == "string" and string.find(key, " ") then makeNotify(key) else makeNotify((mapping[key] or tostring(key)) .. (a and (" "..tostring(a)) or "")) end
end

-- Loading UI
local LoadingGui = Instance.new("Frame")
LoadingGui.Name = "LoadingGui"; LoadingGui.AnchorPoint = Vector2.new(0.5,0.5); LoadingGui.Position = UDim2.new(0.5,0,0.5,0)
LoadingGui.Size = UDim2.new(0,420,0,160); LoadingGui.BackgroundColor3 = Color3.fromRGB(8,8,10); Instance.new("UICorner", LoadingGui).CornerRadius = UDim.new(0,12)
LoadingGui.Parent = ScreenGui

local header = Instance.new("TextLabel", LoadingGui)
header.Size = UDim2.new(1,-28,0,46); header.Position = UDim2.new(0,14,0,12); header.BackgroundTransparency = 1; header.Font = FONT_HEADER; header.TextSize = 22; header.TextColor3 = THEME
header.Text = ""; header.TextXAlignment = Enum.TextXAlignment.Center

local subtitle = Instance.new("TextLabel", LoadingGui)
subtitle.Size = UDim2.new(1,-28,0,18); subtitle.Position = UDim2.new(0,14,0,64); subtitle.BackgroundTransparency = 1; subtitle.Font = FONT_BODY; subtitle.TextSize = 14; subtitle.TextColor3 = Color3.fromRGB(170,230,210)
subtitle.Text = "🔍 Đang chuẩn bị..." ; subtitle.TextXAlignment = Enum.TextXAlignment.Center

local progressBarBg = Instance.new("Frame", LoadingGui)
progressBarBg.Position = UDim2.new(0.06,0,0,100); progressBarBg.Size = UDim2.new(0.88,0,0,14); progressBarBg.BackgroundColor3 = Color3.fromRGB(18,18,20); Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0,8)
local progressBar = Instance.new("Frame", progressBarBg)
progressBar.Size = UDim2.new(0,0,1,0); progressBar.BackgroundColor3 = THEME; Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0,8)
local progressLabel = Instance.new("TextLabel", LoadingGui)
progressLabel.Size = UDim2.new(0.2,0,0,18); progressLabel.Position = UDim2.new(0.8,0,0,70); progressLabel.BackgroundTransparency = 1; progressLabel.Font = FONT_BODY; progressLabel.TextSize = 13; progressLabel.TextColor3 = Color3.fromRGB(200,255,245)
progressLabel.Text = "0%"; progressLabel.TextXAlignment = Enum.TextXAlignment.Right

task.spawn(function()
    local title = "💎 TUANXAURA HUB 💙"
    for i = 1, #title do header.Text = string.sub(title, 1, i); task.wait(0.03) end
    local stages = {{text="🔍 Đang tải module...", t=0.25}, {text="⚙️ Khởi tạo hệ thống...", t=0.30}, {text="🧠 Kết nối dữ liệu...", t=0.30}, {text="🚀 Hoàn tất! Sẵn sàng...", t=0.15}}
    local pct = 0
    for _,st in pairs(stages) do
        subtitle.Text = st.text
        local target = pct + math.floor(st.t * 100)
        while pct < target do
            pct = math.clamp(pct + math.random(4,10), 0, 100)
            progressBar:TweenSize(UDim2.new(pct/100,0,1,0), "Out", "Quad", 0.06, true)
            progressLabel.Text = tostring(math.floor(pct)).."%"
            task.wait(0.02)
        end
    end
    progressBar:TweenSize(UDim2.new(1,0,1,0), "Out", "Quad", 0.25, true)
    progressLabel.Text = "100%"
    subtitle.Text = "✅ Hoàn tất! Chào "..(LocalPlayer.Name or "Người chơi")
    task.wait(0.8)
    local fade = TweenService:Create(LoadingGui, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
    fade:Play(); fade.Completed:Wait()
    pcall(function() LoadingGui:Destroy() end)
end)

-- Main UI
local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"; MainContainer.AnchorPoint = Vector2.new(0.5,0.5); MainContainer.Position = UDim2.new(0.5,0,0.5,0)
MainContainer.Size = UDim2.new(0,420,0,120); MainContainer.BackgroundColor3 = Color3.fromRGB(8,8,10); Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0,12); MainContainer.Parent = ScreenGui

local header2 = Instance.new("TextLabel", MainContainer)
header2.Size = UDim2.new(1,-28,0,38); header2.Position = UDim2.new(0,14,0,10); header2.BackgroundTransparency = 1; header2.Font = FONT_HEADER; header2.TextSize = 20; header2.TextColor3 = THEME
header2.Text = "💎 TUANXAURA HUB 💙"; header2.TextXAlignment = Enum.TextXAlignment.Center

local statusLabel = Instance.new("TextLabel", MainContainer)
statusLabel.Name = "Status"; statusLabel.Size = UDim2.new(1,-28,0,22); statusLabel.Position = UDim2.new(0,14,0,52)
statusLabel.BackgroundTransparency = 1; statusLabel.Font = FONT_BODY; statusLabel.TextSize = 14; statusLabel.TextColor3 = Color3.fromRGB(170,230,210)
statusLabel.Text = "🛰️ Trạng thái: Đang khởi động..." ; statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local userLabel = Instance.new("TextLabel", MainContainer)
userLabel.Size = UDim2.new(0.5, -20,0,18); userLabel.Position = UDim2.new(0,14,1,-28)
userLabel.BackgroundTransparency = 1; userLabel.Font = FONT_BODY; userLabel.TextSize = 13; userLabel.TextColor3 = Color3.fromRGB(200,230,255)
userLabel.Text = "👤 Người chơi: "..(LocalPlayer.Name or "Unknown"); userLabel.TextXAlignment = Enum.TextXAlignment.Left

local distLabel = Instance.new("TextLabel", MainContainer)
distLabel.Size = UDim2.new(0.5, -20,0,18); distLabel.Position = UDim2.new(1,-210,1,-28)
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

-- Toggle button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleUIButton"; toggleButton.Size = UDim2.new(0,64,0,38); toggleButton.Position = UDim2.new(0.5, -32, 1, -76)
toggleButton.AnchorPoint = Vector2.new(0.5,1); toggleButton.BackgroundColor3 = Color3.fromRGB(12,12,14); toggleButton.BorderSizePixel = 0; toggleButton.AutoButtonColor = true
toggleButton.Text = "UI"; toggleButton.Font = FONT_BODY; toggleButton.TextSize = 14; toggleButton.TextColor3 = Color3.fromRGB(200,255,245)
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
toggleButton.MouseEnter:Connect(function() makeNotify("💡 Bật/Tắt Hub UI") end)

-- Fruit scan & selection (no priority)
local function scanFruits()
    local fruits = {}
    for _,obj in pairs(Workspace:GetDescendants()) do
        if obj and obj:IsA("Model") and obj.Name and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            if not obj:IsDescendantOf(LocalPlayer.Character) then table.insert(fruits, obj) end
        end
    end
    return fruits
end

local function chooseFirstFruit(list) if not list or #list==0 then return nil end; return list[1] end

local function SafeTweenToPosition(targetPos, speed)
    if not LocalPlayer or not LocalPlayer.Character then return false end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local dist = (hrp.Position - targetPos).Magnitude
    local time = math.clamp(dist / (speed or DEFAULT_SETTINGS.SafeTeleportSpeed), 0.35, 4.0)
    local ok = pcall(function() local tw = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(targetPos + Vector3.new(0,2,0))}); tw:Play(); tw.Completed:Wait() end)
    if not ok then pcall(function() hrp.CFrame = CFrame.new(targetPos + Vector3.new(0,2,0)) end) end
    return true
end

local function AttemptStoreFruit()
    if not DEFAULT_SETTINGS.AutoStoreFruit then return false end
    local stored = false
    pcall(function()
        local held = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if held and string.find(held.Name or "", "Fruit") then
            local originalName = (held.GetAttribute and held:GetAttribute("OriginalName")) or held.Name
            if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_") then
                local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", originalName, held) end)
                if ok and res ~= false and res ~= "Full" then stored = true; makeNotify("🍈 Đã lưu trái thành công!") else if res == "Full" then makeNotify("🧺 Kho trái đã đầy, bỏ qua trái này.") end end
            end
        end
    end)
    pcall(function()
        if LocalPlayer.Backpack then
            for _,tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if tool and string.find(tool.Name or "", "Fruit") then
                    local originalName = (tool.GetAttribute and tool:GetAttribute("OriginalName")) or tool.Name
                    if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_") then
                        local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", originalName, tool) end)
                        if ok and res ~= false and res ~= "Full" then stored = true; makeNotify("🍈 Đã lưu trái thành công!") end
                    end
                end
            end
        end
    end)
    return stored
end

local function ExecuteServerHop()
    makeNotify("🌍 Không có trái sau "..tostring(DEFAULT_SETTINGS.HopTimeoutSeconds).." giây, đang chuyển server...")
    local PlaceId = game.PlaceId; local LocalJobId = game.JobId; local Cursor = ""; local BlacklistedServers = {}
    if type(isfile) == "function" and isfile("NotSameServers.json") then pcall(function() BlacklistedServers = HttpService:JSONDecode(readfile("NotSameServers.json")) end) end
    if #BlacklistedServers == 0 then table.insert(BlacklistedServers, os.time()) end
    for page = 1, 5 do
        local url = "https://games.roblox.com/v1/games/"..tostring(PlaceId).."/servers/Public?sortOrder=Asc&limit=100"
        if Cursor ~= "" then url = url.."&cursor="..tostring(Cursor) end
        local ok,res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then break end
        local ok2,data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then break end
        Cursor = data.nextPageCursor or ""
        for _,Server in pairs(data.data) do
            if tonumber(Server.maxPlayers) and tonumber(Server.playing) and tostring(Server.id) ~= tostring(LocalJobId) and tonumber(Server.playing) < tonumber(Server.maxPlayers) then
                local sid = tostring(Server.id); local skip = false
                for i = 1, #BlacklistedServers do if tostring(BlacklistedServers[i]) == sid then skip = true; break end end
                if not skip then table.insert(BlacklistedServers, sid); pcall(function() safe_write("NotSameServers.json", HttpService:JSONEncode(BlacklistedServers)) end); pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, sid, LocalPlayer) end); return end
        end
        task.wait(0.2)
    end
    pcall(function() TeleportService:Teleport(PlaceId, LocalPlayer) end)
end

task.spawn(function() while true do if not LocalPlayer or not LocalPlayer.Parent then makeNotify("🔁 Mất kết nối, đang vào lại..."); task.wait(2); pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end; task.wait(3) end end)

-- MAIN LOOP
local lastScan = 0; local noFruitTimer = 0; local currentTarget = nil
task.spawn(function()
    while true do
        local now = tick()
        if now - lastScan >= (DEFAULT_SETTINGS.FruitScanInterval or 1) then
            lastScan = now
            local fruits = scanFruits()
            if #fruits > 0 then
                noFruitTimer = 0
                local firstFruit = chooseFirstFruit(fruits)
                if firstFruit and firstFruit:FindFirstChild("Handle") then
                    currentTarget = firstFruit
                    local name = firstFruit.Name or (firstFruit:GetAttribute and firstFruit:GetAttribute("OriginalName")) or "Unknown"
                    makeNotify("🥭 Phát hiện trái: "..tostring(name))
                    statusLabel.Text = "🥭 Đang di chuyển tới: "..name
                    pcall(function() SafeTweenToPosition(firstFruit.Handle.Position, DEFAULT_SETTINGS.SafeTeleportSpeed) end)
                    task.wait(0.5)
                    pcall(AttemptStoreFruit)
                end
            else
                noFruitTimer = noFruitTimer + (DEFAULT_SETTINGS.FruitScanInterval or 1)
                statusLabel.Text = ("💤 Không thấy trái... (%.1fs)"):format(noFruitTimer)
                if DEFAULT_SETTINGS.AutoHop and noFruitTimer >= (DEFAULT_SETTINGS.HopTimeoutSeconds or 30) then
                    noFruitTimer = 0
                    task.spawn(ExecuteServerHop)
                end
            end
        end
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

-- periodic store safety
task.spawn(function() while true do pcall(AttemptStoreFruit); task.wait(2) end end)

-- anti-afk
pcall(function() local VirtualUser = game:GetService("VirtualUser"); LocalPlayer.Idled:Connect(function() pcall(function() VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end) end) end)

-- ready notify
task.spawn(function() task.wait(1.2); makeNotify("💙 TuanxAura Hub: Sẵn sàng, "..(LocalPlayer.Name or "Người chơi")) end)

