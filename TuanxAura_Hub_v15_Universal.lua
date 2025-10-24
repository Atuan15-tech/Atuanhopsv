-- TuanxAura_Hub_v15_Universal.lua
-- Universal-compatible version: minimal assumptions, no writefile/getgenv, safe timeouts
-- Features: Neon UI + loading, Notify (Vietnamese + emoji), Toggle UI button, AutoFindFruit (first found), AutoStore, AutoHop after timeout, Safe tween fallback, Anti-AFK

-- ========== CONFIG ==========
local SETTINGS = {
    AutoFindFruit = true,
    AutoStoreFruit = true,
    AutoHop = true,
    AutoRejoinOnHopFail = true,
    FruitScanInterval = 1.0,     -- seconds
    HopTimeoutSeconds = 30,      -- seconds of continuous no-fruit before hop
    SafeTeleportSpeed = 1200,    -- studs/sec (tween speed calculation)
    CharacterWaitTimeout = 8,    -- seconds to wait before fallback
    GameLoadTimeout = 8,         -- seconds to wait for game:IsLoaded() before continuing
}

-- ========== SAFETY GUARDS ==========
if _G.TuanxAura_Ran then
    -- already running
    return
end
_G.TuanxAura_Ran = true

-- get services safely
local function gs(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    if ok then return s end
    return nil
end

local Players = gs("Players")
local TweenService = gs("TweenService")
local ReplicatedStorage = gs("ReplicatedStorage")
local HttpService = gs("HttpService")
local TeleportService = gs("TeleportService")
local CoreGui = gs("CoreGui")
local Workspace = gs("Workspace")
local UserInputService = gs("UserInputService")

-- fallback nil guards
Players = Players or game.Players
TweenService = TweenService or game:GetService("TweenService")
ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
HttpService = HttpService or game:GetService("HttpService")
TeleportService = TeleportService or game:GetService("TeleportService")
CoreGui = CoreGui or game:GetService("CoreGui")
Workspace = Workspace or game:GetService("Workspace")
UserInputService = UserInputService or game:GetService("UserInputService")

local LocalPlayer = (Players and Players.LocalPlayer) or nil

-- ========== NON-BLOCKING WAIT FOR LOAD/PLAYER ==========
local function waitForGameLoad(timeout)
    timeout = timeout or SETTINGS.GameLoadTimeout
    local start = tick()
    repeat
        if pcall(function() return game:IsLoaded() end) then
            if game:IsLoaded() then return true end
        end
        task.wait(0.05)
    until tick() - start >= timeout
    return false
end

local function waitForLocalPlayer(timeout)
    timeout = timeout or SETTINGS.CharacterWaitTimeout
    local start = tick()
    while (not LocalPlayer) and tick() - start < timeout do
        LocalPlayer = Players and Players.LocalPlayer
        task.wait(0.05)
    end
    return LocalPlayer ~= nil
end

local function waitForCharacter(timeout)
    timeout = timeout or SETTINGS.CharacterWaitTimeout
    if not LocalPlayer then return false end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return true end
    local got = false
    local start = tick()
    local con
    con = LocalPlayer.CharacterAdded:Connect(function(char)
        if char and char:FindFirstChild("HumanoidRootPart") then
            got = true
        else
            pcall(function() char:WaitForChild("HumanoidRootPart", 2) end)
            if char:FindFirstChild("HumanoidRootPart") then got = true end
        end
    end)
    if LocalPlayer.Character then
        if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then got = true end
    end
    repeat task.wait(0.05) until got or tick() - start >= timeout
    if con then con:Disconnect() end
    return got
end

-- Run without waiting forever
waitForGameLoad()
waitForLocalPlayer()
waitForCharacter()

-- attempt to refresh LocalPlayer/Character references
LocalPlayer = Players and Players.LocalPlayer or LocalPlayer
local function getHRP()
    if LocalPlayer and LocalPlayer.Character then return LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end
    return nil
end

-- ========== THEME ==========
local THEME = Color3.fromRGB(0, 255, 230) -- neon blue
local FONT_HEADER = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.Ubuntu

-- ========== UTILS ==========
local function SetProps(inst, tbl)
    for k, v in pairs(tbl) do
        pcall(function() inst[k] = v end)
    end
    return inst
end

local function safeInvokeStore(originalName, tool)
    if not ReplicatedStorage then return nil end
    local okRemotes = pcall(function() return ReplicatedStorage:FindFirstChild("Remotes") end)
    if not okRemotes then return nil end
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    if not rem then return nil end
    local comm = rem:FindFirstChild("CommF_")
    if not comm then return nil end
    local ok, res = pcall(function() return comm:InvokeServer("StoreFruit", originalName, tool) end)
    if ok then return res end
    return nil
end

-- ========== UI (create quickly, minimal dependencies) ==========
pcall(function()
    if CoreGui:FindFirstChild("TuanxAura_v15_UI") then
        CoreGui.TuanxAura_v15_UI:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TuanxAura_v15_UI"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            ScreenGui.Parent = LocalPlayer.PlayerGui
        else
            ScreenGui.Parent = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
        end
    end)
end

local NotifyRoot = SetProps(Instance.new("Frame"), {
    Name = "NotifyRoot",
    Parent = ScreenGui,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.06, 0),
    Size = UDim2.new(0, 420, 0, 60),
    BackgroundTransparency = 1,
})

local function makeNotify(text, duration)
    duration = duration or 2.6
    if not NotifyRoot or not NotifyRoot.Parent then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 44)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, -0.2, 0)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    frame.Parent = NotifyRoot
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = THEME; stroke.Transparency = 0.8; stroke.Thickness = 1

    local lbl = SetProps(Instance.new("TextLabel"), {
        Parent = frame,
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Font = FONT_BODY,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(230, 240, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text or "",
    })

    pcall(function()
        local t = TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 0)})
        t:Play()
    end)
    task.delay(duration, function()
        pcall(function()
            local t2 = TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, -0.2, 0)})
            t2:Play()
            t2.Completed:Wait()
            frame:Destroy()
        end)
    end)
end

local function NotifyVN(key, extra)
    local mapping = {
        started = "💙 TuanxAura Hub: Đã khởi động! Cấu hình đã được tải.",
        saved = "💾 Cấu hình đã lưu.",
        invalid = "⚠️ Giá trị không hợp lệ, đã khôi phục.",
        stored = "🍈 Đã lưu trái thành công!",
        bagfull = "🧺 Kho trái đã đầy, bỏ qua trái này.",
        owned = "🔁 Đã có trái này, bỏ qua.",
        waiting = "💤 Đang chờ trái xuất hiện...",
        autohop = "🌍 Không có trái sau "..tostring(SETTINGS.HopTimeoutSeconds).."s, đang chuyển server...",
        rejoin = "🔁 Mất kết nối, đang vào lại...",
    }
    local text = mapping[key] or tostring(key)
    if extra then text = text .. " " .. tostring(extra) end
    makeNotify(text)
end

-- Loading UI (center)
local LoadingFrame = SetProps(Instance.new("Frame"), {
    Parent = ScreenGui,
    Name = "LoadingFrame",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 420, 0, 160),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10),
})
SetProps(Instance.new("UICorner"), {Parent = LoadingFrame, CornerRadius = UDim.new(0, 12)})

local titleLabel = SetProps(Instance.new("TextLabel"), {
    Parent = LoadingFrame,
    Size = UDim2.new(1, -28, 0, 46),
    Position = UDim2.new(0, 14, 0, 12),
    BackgroundTransparency = 1,
    Font = FONT_HEADER,
    TextSize = 22,
    TextColor3 = THEME,
    Text = "",
    TextXAlignment = Enum.TextXAlignment.Center,
})

local subLabel = SetProps(Instance.new("TextLabel"), {
    Parent = LoadingFrame,
    Size = UDim2.new(1, -28, 0, 18),
    Position = UDim2.new(0, 14, 0, 64),
    BackgroundTransparency = 1,
    Font = FONT_BODY,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(170, 230, 210),
    Text = "🔍 Đang chuẩn bị...",
    TextXAlignment = Enum.TextXAlignment.Center,
})

local pb_bg = SetProps(Instance.new("Frame"), {
    Parent = LoadingFrame,
    Position = UDim2.new(0.06, 0, 0, 100),
    Size = UDim2.new(0.88, 0, 0, 14),
    BackgroundColor3 = Color3.fromRGB(18, 18, 20),
})
SetProps(Instance.new("UICorner", pb_bg), {CornerRadius = UDim.new(0, 8)})
local pb = SetProps(Instance.new("Frame"), {Parent = pb_bg, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = THEME})
SetProps(Instance.new("UICorner", pb), {CornerRadius = UDim.new(0, 8)})
local pb_label = SetProps(Instance.new("TextLabel"), {
    Parent = LoadingFrame,
    Size = UDim2.new(0.2, 0, 0, 18),
    Position = UDim2.new(0.8, 0, 0, 70),
    BackgroundTransparency = 1,
    Font = FONT_BODY,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(200, 255, 245),
    Text = "0%",
    TextXAlignment = Enum.TextXAlignment.Right,
})

task.spawn(function()
    local title = "💎 TUANXAURA HUB 💙"
    for i = 1, #title do
        pcall(function() titleLabel.Text = string.sub(title, 1, i) end)
        task.wait(0.03)
    end
    local stages = {
        {text = "🔍 Đang tải module...", t = 0.25},
        {text = "⚙️ Khởi tạo hệ thống...", t = 0.30},
        {text = "🧠 Kết nối dữ liệu...", t = 0.30},
        {text = "🚀 Hoàn tất! Sẵn sàng...", t = 0.15},
    }
    local pct = 0
    for _, st in pairs(stages) do
        pcall(function() subLabel.Text = st.text end)
        local target = pct + math.floor(st.t * 100)
        while pct < target do
            pct = math.min(100, pct + math.random(4, 10))
            pcall(function() pb:TweenSize(UDim2.new(pct / 100, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.06, true) end)
            pcall(function() pb_label.Text = tostring(math.floor(pct)) .. "%" end)
            task.wait(0.02)
        end
    end
    pcall(function() pb:TweenSize(UDim2.new(1, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true) end)
    pcall(function() pb_label.Text = "100%" end)
    pcall(function() subLabel.Text = "✅ Hoàn tất! Chào " .. (LocalPlayer and LocalPlayer.Name or "Người chơi") end)
    task.wait(0.7)
    pcall(function() LoadingFrame:Destroy() end)
end)

-- Main minimal UI
local MainFrame = SetProps(Instance.new("Frame"), {
    Parent = ScreenGui,
    Name = "MainFrame",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 420, 0, 120),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10),
})
SetProps(Instance.new("UICorner", MainFrame), {CornerRadius = UDim.new(0, 12)})

local header_label = SetProps(Instance.new("TextLabel"), {
    Parent = MainFrame,
    Size = UDim2.new(1, -28, 0, 38),
    Position = UDim2.new(0, 14, 0, 10),
    BackgroundTransparency = 1,
    Font = FONT_HEADER,
    TextSize = 20,
    TextColor3 = THEME,
    Text = "💎 TUANXAURA HUB 💙",
    TextXAlignment = Enum.TextXAlignment.Center,
})

local status_label = SetProps(Instance.new("TextLabel"), {
    Parent = MainFrame,
    Name = "StatusLabel",
    Size = UDim2.new(1, -28, 0, 22),
    Position = UDim2.new(0, 14, 0, 52),
    BackgroundTransparency = 1,
    Font = FONT_BODY,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(170, 230, 210),
    Text = "🛰️ Trạng thái: Đang khởi động...",
    TextXAlignment = Enum.TextXAlignment.Left,
})

local user_label = SetProps(Instance.new("TextLabel"), {
    Parent = MainFrame,
    Size = UDim2.new(0.5, -20, 0, 18),
    Position = UDim2.new(0, 14, 1, -28),
    BackgroundTransparency = 1,
    Font = FONT_BODY,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(200, 230, 255),
    Text = "👤 Người chơi: " .. (LocalPlayer and LocalPlayer.Name or "Unknown"),
    TextXAlignment = Enum.TextXAlignment.Left,
})

local dist_label = SetProps(Instance.new("TextLabel"), {
    Parent = MainFrame,
    Name = "DistLabel",
    Size = UDim2.new(0.5, -20, 0, 18),
    Position = UDim2.new(1, -210, 1, -28),
    BackgroundTransparency = 1,
    Font = FONT_BODY,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(200, 230, 255),
    Text = "🍍 Cách: -- m",
    TextXAlignment = Enum.TextXAlignment.Right,
})

task.spawn(function()
    while MainFrame and MainFrame.Parent do
        pcall(function()
            TweenService:Create(header_label, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = Color3.fromRGB(120, 255, 200)}):Play()
            task.wait(1.2)
            TweenService:Create(header_label, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = THEME}):Play()
            task.wait(1.2)
        end)
    end
end)

-- Toggle button (square rounded) center bottom
local toggleBtn = SetProps(Instance.new("TextButton"), {
    Parent = ScreenGui,
    Name = "ToggleBtn",
    Size = UDim2.new(0, 64, 0, 38),
    Position = UDim2.new(0.5, -32, 1, -76),
    AnchorPoint = Vector2.new(0.5, 1),
    BackgroundColor3 = Color3.fromRGB(12, 12, 14),
    BorderSizePixel = 0,
    Text = "UI",
    Font = FONT_BODY,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(200, 255, 245),
})
SetProps(Instance.new("UICorner", toggleBtn), {CornerRadius = UDim.new(0, 10)})
local strokeTB = SetProps(Instance.new("UIStroke", toggleBtn), {Color = THEME, Transparency = 0.7, Thickness = 1.4})

local uiVisible = true
local function setUIVisible(v)
    uiVisible = v
    if uiVisible then
        MainFrame.Visible = true
        pcall(function() TweenService:Create(MainFrame, TweenInfo.new(0.28), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play() end)
    else
        pcall(function() TweenService:Create(MainFrame, TweenInfo.new(0.28), {Position = UDim2.new(0.5, 0, 0.75, 0)}):Play() end)
        task.delay(0.28, function() pcall(function() MainFrame.Visible = false end) end)
    end
end

toggleBtn.MouseButton1Click:Connect(function() setUIVisible(not uiVisible) end)
UserInputService.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.RightShift then setUIVisible(not uiVisible) end end)
toggleBtn.MouseEnter:Connect(function() makeNotify("💡 Bật/Tắt Hub UI") end)

-- ========== FRUIT SCAN & LOGIC (NO PRIORITY) ==========
local function scanFruits()
    local fruits = {}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj and obj:IsA("Model") and obj.Name and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            if not LocalPlayer or not LocalPlayer.Character or not obj:IsDescendantOf(LocalPlayer.Character) then
                table.insert(fruits, obj)
            end
        end
    end
    return fruits
end

local function chooseFirst(list)
    if not list or #list == 0 then return nil end
    return list[1]
end

local function safeTweenTo(pos, speed)
    speed = speed or SETTINGS.SafeTeleportSpeed
    pcall(function()
        local hrp = getHRP()
        if not hrp then return end
        local dist = (hrp.Position - pos).Magnitude
        local t = math.clamp(dist / speed, 0.35, 4.0)
        local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))})
        tw:Play()
        tw.Completed:Wait()
    end)
    pcall(function()
        local hrp = getHRP()
        if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) end
    end)
end

local function AttemptStoreFruit()
    if not SETTINGS.AutoStoreFruit then return false end
    local stored = false
    pcall(function()
        if not LocalPlayer then return end
        local held = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if held and string.find(held.Name or "", "Fruit") then
            local originalName = (held.GetAttribute and held:GetAttribute("OriginalName")) or held.Name
            local res = safeInvokeStore(originalName, held)
            if res and res ~= false and res ~= "Full" then stored = true; makeNotify("🍈 Đã lưu trái thành công!") end
            if res == "Full" then makeNotify("🧺 Kho trái đã đầy, bỏ qua trái này.") end
        end
    end)
    pcall(function()
        if LocalPlayer and LocalPlayer.Backpack then
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if tool and string.find(tool.Name or "", "Fruit") then
                    local originalName = (tool.GetAttribute and tool:GetAttribute("OriginalName")) or tool.Name
                    local res = safeInvokeStore(originalName, tool)
                    if res and res ~= false and res ~= "Full" then stored = true; makeNotify("🍈 Đã lưu trái thành công!") end
                end
            end
        end
    end)
    return stored
end

-- ========== SERVER HOP (simple) ==========
local function ExecuteServerHop()
    makeNotify("🌍 Không có trái, đang chuyển server...")
    local PlaceId = game.PlaceId
    local LocalJobId = game.JobId
    local Cursor = ""
    local Blacklisted = {}
    if type(isfile) == "function" and isfile("NotSameServers.json") then
        pcall(function() Blacklisted = HttpService:JSONDecode(readfile("NotSameServers.json")) end)
    end
    if #Blacklisted == 0 then table.insert(Blacklisted, os.time()) end
    for page = 1, 5 do
        local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
        if Cursor ~= "" then url = url .. "&cursor=" .. tostring(Cursor) end
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then break end
        local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then break end
        Cursor = data.nextPageCursor or ""
        for _, sv in pairs(data.data) do
            local valid = tonumber(sv.playing) and tonumber(sv.maxPlayers) and (tonumber(sv.playing) < tonumber(sv.maxPlayers)) and tostring(sv.id) ~= tostring(LocalJobId)
            if valid then
                local sid = tostring(sv.id)
                local skip = false
                for i = 1, #Blacklisted do if tostring(Blacklisted[i]) == sid then skip = true; break end end
                if not skip then
                    table.insert(Blacklisted, sid)
                    pcall(function() if type(writefile) == "function" then writefile("NotSameServers.json", HttpService:JSONEncode(Blacklisted)) end end)
                    pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, sid, LocalPlayer) end)
                    return
                end
            end
        end
        task.wait(0.18)
    end
    pcall(function() TeleportService:Teleport(PlaceId, LocalPlayer) end)
end

-- ========== AUTO-REJOIN & ANTI-AFK ==========
task.spawn(function()
    while true do
        if not LocalPlayer or not LocalPlayer.Parent then
            makeNotify("🔁 Mất kết nối — đang cố vào lại...")
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
        task.wait(3)
    end
end)

pcall(function()
    local vu_ok, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
    if vu_ok and VirtualUser and LocalPlayer then
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end
end)

-- ========== MAIN LOOP ==========
local lastScan = 0
local noFruitTimer = 0
local currentTarget = nil

makeNotify("⚡ TuanxAura Hub đang khởi động...")

task.spawn(function()
    while true do
        local now = tick()
        if now - lastScan >= (SETTINGS.FruitScanInterval or 1) then
            lastScan = now
            local fruits = scanFruits()
            if fruits and #fruits > 0 then
                noFruitTimer = 0
                local fruit = chooseFirst(fruits)
                if fruit and fruit:FindFirstChild("Handle") then
                    currentTarget = fruit
                    local fname = fruit.Name or (fruit.GetAttribute and fruit:GetAttribute("OriginalName")) or "Trái"
                    makeNotify("🥭 Phát hiện trái: " .. tostring(fname))
                    pcall(function() status_label.Text = "🥭 Đang di chuyển tới: " .. tostring(fname) end)
                    pcall(function() safeTweenTo(fruit.Handle.Position, SETTINGS.SafeTeleportSpeed) end)
                    task.wait(0.4)
                    pcall(AttemptStoreFruit)
                end
            else
                noFruitTimer = noFruitTimer + (SETTINGS.FruitScanInterval or 1)
                pcall(function() status_label.Text = ("💤 Không thấy trái... (%.1fs)"):format(noFruitTimer) end)
                if SETTINGS.AutoHop and noFruitTimer >= (SETTINGS.HopTimeoutSeconds or 30) then
                    noFruitTimer = 0
                    task.spawn(ExecuteServerHop)
                end
            end
        end

        pcall(function()
            if currentTarget and currentTarget:FindFirstChild("Handle") and getHRP() then
                local d = math.floor((getHRP().Position - currentTarget.Handle.Position).Magnitude)
                dist_label.Text = "🍍 Cách: " .. tostring(d) .. " m"
            else
                dist_label.Text = "🍍 Cách: -- m"
            end
        end)

        task.wait(0.12)
    end
end)

task.spawn(function()
    while true do
        pcall(AttemptStoreFruit)
        task.wait(2)
    end
end)

task.spawn(function()
    task.wait(1.1)
    makeNotify("💙 TuanxAura Hub: Sẵn sàng, " .. (LocalPlayer and LocalPlayer.Name or "Người chơi"))
    pcall(function() status_label.Text = "✅ Đã sẵn sàng" end)
end)

-- End of file
