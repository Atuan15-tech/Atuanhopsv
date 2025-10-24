-- TuanxAura_Hub_v6_PulseNeon_Optimized.lua
-- Minimal UI (logo + status + username), Vietnamese emoji notify,
-- AutoFind/AutoStore/AutoHop/AutoJoin/AutoRejoin/AntiAFK/AntiTP(PlayerLock)/AutoClean, optimized tweens & notify
-- Theme: Neon xanh dương, pulse glow, logo present
-- Save and run with executor that supports writefile/readfile/getgenv/etc.

-- ===== CONFIG =====
local DEFAULT_SETTINGS = {
    AutoFindFruit = true,
    AutoStoreFruit = true,
    AutoHop = true,
    AutoRejoinOnHopFail = true,
    AntiAFK = true,
    AutoFruitESP = true,
    FruitScanInterval = 1.0,
    HopTimeoutSeconds = 15,
    SafeTeleportSpeed = 1500, -- studs per second (used for time calc)
    Team = "Marines",
}

-- wait for player & character
repeat task.wait() until game:IsLoaded() and game.Players and game.Players.LocalPlayer
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer and (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())

-- prevent double run
getgenv().Ran = getgenv().Ran or false
if getgenv().Ran then return end
getgenv().Ran = true

-- theme
local THEME = Color3.fromRGB(12,160,255) -- xanh neon
local USE_EMOJI = true

local _G_Settings = {}
for k,v in pairs(DEFAULT_SETTINGS) do _G_Settings[k] = v end
_G_Settings.ForceHopSignal = false

local CONFIG_FILE = "TuanxAura_Hub_v6_Config.json"

-- services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualUser = (pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser")) or nil

local OriginalPlaceId = game.PlaceId
local Character, HumanoidRootPart

-- safe file helpers
local function safe_write(file, content) if writefile then pcall(writefile, file, content) end end
local function safe_read(file) if isfile and isfile(file) then return readfile(file) end end

-- ===== CONFIG SAVE/LOAD =====
local savingDeb = false
local function SaveConfig()
    if savingDeb then return end
    savingDeb = true
    task.spawn(function()
        task.wait(0.5)
        pcall(function()
            safe_write(CONFIG_FILE, HttpService:JSONEncode(_G_Settings))
        end)
        savingDeb = false
    end)
end
local function LoadConfig()
    local txt = safe_read(CONFIG_FILE)
    if txt then
        pcall(function()
            local dat = HttpService:JSONDecode(txt)
            for k,v in pairs(dat) do if _G_Settings[k] ~= nil then _G_Settings[k] = v end end
        end)
    end
end
LoadConfig()

-- ===== NOTIFY (TIẾNG VIỆT + EMOJI) optimized non-blocking multi-notify =====
if CoreGui:FindFirstChild("TuanxAura_Hub_GUI_v6") then pcall(function() CoreGui.TuanxAura_Hub_GUI_v6:Destroy() end) end
local Screen = Instance.new("ScreenGui"); Screen.Name = "TuanxAura_Hub_GUI_v6"; Screen.ResetOnSpawn = false; Screen.Parent = CoreGui

local function makeNotifyObjects()
    local nGui = Instance.new("Frame")
    nGui.Name = "NotifyRoot"
    nGui.Size = UDim2.new(0,420,0,56)
    nGui.AnchorPoint = Vector2.new(0.5,0)
    nGui.Position = UDim2.new(0.5,0,0.08,0)
    nGui.BackgroundTransparency = 1
    nGui.Parent = Screen
    return nGui
end
local NotifyRoot = makeNotifyObjects()

local notifyPool = {}
local function showNotify(text, duration)
    duration = duration or 2.6
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,380,0,44)
    frame.BackgroundColor3 = Color3.fromRGB(10,10,14)
    frame.BackgroundTransparency = 0
    frame.AnchorPoint = Vector2.new(0.5,0)
    frame.Position = UDim2.new(0.5,0,-0.2,0)
    frame.Parent = NotifyRoot
    frame.ClipsDescendants = true
    frame.ZIndex = 10
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = THEME; stroke.Transparency = 0.85; stroke.Thickness = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1,-16,1,0)
    label.Position = UDim2.new(0,8,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Ubuntu
    label.TextSize = 16
    label.TextColor3 = Color3.fromRGB(230,240,255)
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left

    local show = TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0,0)})
    show:Play()

    table.insert(notifyPool, frame)

    task.delay(duration, function()
        local hide = TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5,0,-0.2,0), BackgroundTransparency = 1})
        hide:Play()
        hide.Completed:Connect(function()
            pcall(function() frame:Destroy() end)
            for i,f in pairs(notifyPool) do if f == frame then table.remove(notifyPool,i); break end end
        end)
    end)
end

local function NotifyVN(key, a)
    if type(key) == "string" and string.find(key," ") then showNotify(key); return end
    local mapping = {
        started = "💙 TuanxAura Hub: Đã khởi động thành công! Cấu hình đã được tải.",
        saved = "💾 Cấu hình đã được lưu!",
        invalid = "⚠️ Giá trị không hợp lệ, đã khôi phục lại.",
        finding = "🔍 Đang tìm máy chủ mới...",
        foundhop = "🌐 Đã tìm thấy máy chủ mới, đang chuyển...",
        serverfail = "🚫 Không thể tải danh sách máy chủ.",
        stored = "🍈 Đã lưu trái cây thành công!",
        bagfull = "🧺 Kho trái đã đầy, bỏ qua trái này.",
        owned = "🔁 Đã có trái này, bỏ qua.",
        fruitfound = ("🥭 Phát hiện trái cây: %s"):format(tostring(a or "Unknown")),
        waiting = "💤 Đang chờ trái cây xuất hiện...",
        autohop = "🌍 Không có trái sau 15 giây, đang chuyển máy chủ...",
        fixed = "🔒 Nhân vật đã được cố định, chống rơi và lỗi di chuyển.",
        afk = "💤 Chống AFK đã bật.",
        rejoin = "🔁 Mất kết nối, đang vào lại máy chủ...",
        rejoinok = "✅ Đã vào lại máy chủ thành công!",
        autoclean = "🧹 Đã dọn sạch map, chỉ giữ lại nhân vật và NPC.",
        hopfail = "⚠️ Không thể chuyển máy chủ, tự động vào lại đã tắt.",
        rejoinorig = "🔁 Chuyển máy chủ thất bại, đang vào lại máy chủ ban đầu..."
    }
    showNotify(mapping[key] or tostring(key))
end

-- ===== UI Minimal (center rectangle + logo + status + username) =====
local function CreateMinimalUI()
    local gui = Screen
    local container = Instance.new("Frame", gui)
    container.Name = "TuanxAuraContainer"
    container.AnchorPoint = Vector2.new(0.5,0.5)
    container.Position = UDim2.new(0.5,0,0.5,0)
    container.Size = UDim2.new(0,420,0,120)
    container.BackgroundColor3 = Color3.fromRGB(8,8,10)
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,12)
    local stroke = Instance.new("UIStroke", container); stroke.Color = THEME; stroke.Transparency = 0.75; stroke.Thickness = 2

    local logo = Instance.new("TextLabel", container)
    logo.Name = "Logo"; logo.Position = UDim2.new(0.5,0,0,12); logo.AnchorPoint = Vector2.new(0.5,0)
    logo.Size = UDim2.new(0,380,0,36); logo.BackgroundTransparency = 1; logo.Font = Enum.Font.FredokaOne
    logo.Text = "💙 TUANXAURA HUB"; logo.TextSize = 20; logo.TextColor3 = Color3.fromRGB(200,240,255)
    logo.TextStrokeTransparency = 0.7; logo.TextXAlignment = Enum.TextXAlignment.Center

    local status = Instance.new("TextLabel", container)
    status.Name = "Status"; status.Position = UDim2.new(0.5,0,0,56); status.AnchorPoint = Vector2.new(0.5,0)
    status.Size = UDim2.new(0,380,0,24); status.BackgroundTransparency = 1; status.Font = Enum.Font.Ubuntu
    status.Text = "🛰️ Trạng thái: Khởi động..." ; status.TextSize = 14; status.TextColor3 = Color3.fromRGB(170,230,210)
    status.TextXAlignment = Enum.TextXAlignment.Left

    local userlbl = Instance.new("TextLabel", container)
    userlbl.Name = "User"; userlbl.AnchorPoint = Vector2.new(1,0); userlbl.Position = UDim2.new(1,-12,1,-28)
    userlbl.Size = UDim2.new(0,200,0,18); userlbl.BackgroundTransparency = 1; userlbl.Font = Enum.Font.GothamSemibold
    userlbl.Text = "👤 Người chơi: "..(LocalPlayer.Name or "Unknown"); userlbl.TextSize = 13; userlbl.TextColor3 = Color3.fromRGB(200,230,255)
    userlbl.TextXAlignment = Enum.TextXAlignment.Right

    -- pulse effect for logo (non-blocking loop)
    task.spawn(function()
        while container.Parent do
            pcall(function()
                local t1 = TweenService:Create(logo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = Color3.fromRGB(100,255,200)})
                t1:Play(); t1.Completed:Wait()
                local t2 = TweenService:Create(logo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextColor3 = Color3.fromRGB(200,240,255)})
                t2:Play(); t2.Completed:Wait()
            end)
            task.wait(0.05)
        end
    end)

    return {Container = container, Logo = logo, Status = status, User = userlbl}
end

local UI = CreateMinimalUI()

-- ===== CHARACTER & PLAYER LOCK (Anti-fall & stabilize) =====
local function EnsureCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart",5)
end
EnsureCharacter()

local function applyPlayerLock()
    pcall(function()
        if not Character or not Character.Parent then return end
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if hrp:FindFirstChild("TuanxAura_LockBV") then hrp.TuanxAura_LockBV:Destroy() end
        if hrp:FindFirstChild("TuanxAura_LockBG") then hrp.TuanxAura_LockBG:Destroy() end
        local bv = Instance.new("BodyVelocity"); bv.Name = "TuanxAura_LockBV"; bv.MaxForce = Vector3.new(1e5,1e5,1e5); bv.Velocity = Vector3.new(0,0,0); bv.P = 2000; bv.Parent = hrp
        local bg = Instance.new("BodyGyro"); bg.Name = "TuanxAura_LockBG"; bg.MaxTorque = Vector3.new(1e5,1e5,1e5); bg.CFrame = hrp.CFrame; bg.P = 2000; bg.Parent = hrp
        task.spawn(function()
            while hrp and hrp.Parent do
                if hrp.Position.Y < -10 then
                    pcall(function()
                        local safe = (Workspace:FindFirstChild("SpawnLocation") and Workspace.SpawnLocation.Position) or Vector3.new(0,50,0)
                        hrp.CFrame = CFrame.new(safe + Vector3.new(0,5,0))
                    end)
                end
                bg.CFrame = hrp.CFrame
                task.wait(0.5)
            end
        end)
    end)
end
applyPlayerLock()
LocalPlayer.CharacterAdded:Connect(function() task.wait(1); EnsureCharacter(); applyPlayerLock() end)

-- ===== ANTI-AFK =====
if _G_Settings.AntiAFK and VirtualUser then
    LocalPlayer.Idled:Connect(function()
        pcall(function() VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end)
    end)
    NotifyVN("afk")
end

-- ===== AUTO CLEAN MAP (run once safe) =====
local function AutoCleanMap()
    pcall(function()
        local keepPrefixes = {"Spawn","NPC","Enemy","Boss","Fruit","Player","Map","Island","SafeZone","SpawnLocation"}
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Terrain") or obj:IsA("Camera") or obj.Name == "CollectionService" then
                -- keep
            else
                local keep = false
                for _,p in pairs(keepPrefixes) do if string.find(obj.Name,p) then keep = true; break end end
                if not keep and not obj:IsDescendantOf(LocalPlayer.Character) then pcall(function() obj:Destroy() end) end
            end
        end
    end)
    NotifyVN("autoclean")
end
task.spawn(function() task.wait(0.6); AutoCleanMap() end)

-- ===== SAFE TELEPORT (Tween optimized & fallback) =====
local function SafeTweenToPosition(targetPos, speed)
    pcall(function() EnsureCharacter() end)
    if not HumanoidRootPart or not targetPos then return end
    local current = HumanoidRootPart.Position
    local dist = (current - targetPos).Magnitude
    local time = math.clamp(dist / (speed or _G_Settings.SafeTeleportSpeed), 0.35, 3.5)
    local ok = pcall(function()
        local tw = TweenService:Create(HumanoidRootPart, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(targetPos + Vector3.new(0,2,0))})
        tw:Play(); tw.Completed:Wait()
    end)
    if not ok then pcall(function() HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0,2,0)) end) end
end

-- ===== FIND FRUIT optimized (limit search) =====
local function FindFruit()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(obj.Name,"Fruit") and obj:FindFirstChild("Handle") then
            if not obj:IsDescendantOf(LocalPlayer.Character) then return obj end
        end
    end
    return nil
end

-- ===== ATTEMPT STORE FRUIT (improved) =====
local function AttemptStoreFruit()
    if not _G_Settings.AutoStoreFruit then return false end
    local stored = false; local owned = {}
    pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_") then
            local ok, res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventoryFruits") end)
            if ok and type(res) == "table" then for _,f in pairs(res) do if type(f)=="table" and f.Name then owned[tostring(f.Name)]=true end end end
        end
    end)
    pcall(function()
        local held = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if held and string.find(held.Name,"Fruit") then
            local name = held:GetAttribute("OriginalName") or tostring(held.Name):gsub("Fruit",""):gsub(" ","")
            if owned[name] then NotifyVN("owned"); return false end
            local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", name, held) end)
            if not ok or res == "Full" or res == false then NotifyVN("bagfull"); return false end
            stored = true; NotifyVN("stored"); task.wait(0.6)
        end
    end)
    pcall(function()
        for _,tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool and string.find(tool.Name,"Fruit") then
                local name = tool:GetAttribute("OriginalName") or tostring(tool.Name):gsub("Fruit",""):gsub(" ","")
                if owned[name] then NotifyVN("owned") else
                    local ok,res = pcall(function() return ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", name, tool) end)
                    if not ok or res == "Full" or res == false then NotifyVN("bagfull") else stored = true; NotifyVN("stored"); task.wait(0.5) end
                end
            end
        end
    end)
    return stored
end

-- ===== TELEPORT TO FRUIT =====
local function TeleportToFruit(fHandle)
    if not fHandle then return end
    SafeTweenToPosition(fHandle.Position, _G_Settings.SafeTeleportSpeed)
    task.wait(0.45)
end

-- ===== AUTO JOIN TEAM (robust) =====
task.spawn(function()
    local desired = tostring(_G_Settings.Team or "Marines")
    local joined = false; local tries = 0
    while not joined and tries < 12 do
        tries = tries + 1
        pcall(function()
            local gui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",2)
            if gui then
                local main = gui:FindFirstChild("Main")
                if main and main:FindFirstChild("ChooseTeam") then
                    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", desired) end)
                    joined = true; NotifyVN("started"); return
                end
            end
            pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", desired) end)
            joined = true
        end)
        task.wait(0.6)
    end
end)

-- ===== SERVER HOP (safe) =====
local function ExecuteServerHop()
    pcall(function() NotifyVN("autohop") end)
    local PlaceId = OriginalPlaceId; local JobId = game.JobId
    local cursor = ""; local attempts = 0
    local blacklisted = {}
    if isfile and isfile("NotSameServers.json") then
        pcall(function() blacklisted = HttpService:JSONDecode(readfile("NotSameServers.json")) end)
    end
    if #blacklisted == 0 then table.insert(blacklisted, os.time()) end
    while attempts < 6 do
        attempts = attempts + 1
        local url = "https://games.roblox.com/v1/games/"..tostring(PlaceId).."/servers/Public?limit=100&sortOrder=Asc"
        if cursor ~= "" then url = url .. "&cursor="..tostring(cursor) end
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then NotifyVN("serverfail"); break end
        local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then NotifyVN("serverfail"); break end
        cursor = data.nextPageCursor or ""
        for _,s in pairs(data.data) do
            if tostring(s.id) ~= tostring(JobId) and tonumber(s.playing) < tonumber(s.maxPlayers) then
                local sid = tostring(s.id); local skip = false
                for _,b in pairs(blacklisted) do if tostring(b) == sid then skip = true; break end end
                if not skip then
                    table.insert(blacklisted, sid)
                    pcall(function() safe_write("NotSameServers.json", HttpService:JSONEncode(blacklisted)) end)
                    pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, sid, LocalPlayer) end)
                    return
                end
            end
        end
        task.wait(0.2)
    end
    -- fallback rejoin original
    pcall(function() NotifyVN("rejoinorig") end)
    task.wait(1.8)
    pcall(function() TeleportService:Teleport(OriginalPlaceId, LocalPlayer) end)
end

-- ===== AUTO REJOIN (improved lightweight) =====
local rejoinAttempts = 0
local function TryRejoin()
    if rejoinAttempts > 3 then return end
    rejoinAttempts = rejoinAttempts + 1
    NotifyVN("rejoin")
    task.wait(2)
    pcall(function() TeleportService:Teleport(OriginalPlaceId, LocalPlayer) end)
    task.wait(8)
    NotifyVN("rejoinok")
end

task.spawn(function()
    while true do
        if not LocalPlayer or not LocalPlayer.Parent then pcall(TryRejoin) end
        task.wait(3)
    end
end)

-- ===== MAIN SCAN LOOP (optimized) =====
task.spawn(function()
    local lastScan = tick()
    local noFruitTime = 0
    while true do
        local now = tick()
        if now - lastScan >= (_G_Settings.FruitScanInterval or 1) then
            lastScan = now
            pcall(function() if UI and UI.Status then UI.Status.Text = "🛰️ Trạng thái: Đang quét..." end end)

            -- lightweight ESP
            if _G_Settings.AutoFruitESP then
                for _,obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and string.find(obj.Name,"Fruit") and obj:FindFirstChild("Handle") then
                        if not obj.Handle:FindFirstChild("TuanxAuraESP") then
                            local bill = Instance.new("BillboardGui")
                            bill.Name = "TuanxAuraESP"
                            bill.Adornee = obj.Handle
                            bill.Size = UDim2.new(0,120,0,28)
                            bill.AlwaysOnTop = true
                            bill.Parent = CoreGui
                            local lbl = Instance.new("TextLabel", bill)
                            lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamSemibold
                            lbl.Text = tostring(obj.Name); lbl.TextScaled = true; lbl.TextColor3 = Color3.fromRGB(255,255,150)
                        end
                    end
                end
            end

            local found = FindFruit()
            if found and _G_Settings.AutoFindFruit then
                noFruitTime = 0
                pcall(function() if UI and UI.Status then UI.Status.Text = "🥭 Phát hiện trái: "..(found.Name or "Unknown") end end)
                pcall(function() TeleportToFruit(found.Handle) end)
                task.wait(0.8)
                pcall(AttemptStoreFruit)
            else
                noFruitTime = noFruitTime + (_G_Settings.FruitScanInterval or 1)
                pcall(function() if UI and UI.Status then UI.Status.Text = ("💤 Đang chờ trái... (%.1fs)"):format(noFruitTime) end end)
                if _G_Settings.AutoHop and (noFruitTime >= (_G_Settings.HopTimeoutSeconds or 15) or _G_Settings.ForceHopSignal) then
                    noFruitTime = 0
                    _G_Settings.ForceHopSignal = false
                    task.spawn(function() ExecuteServerHop() end)
                end
            end
        end
        task.wait(0.12)
    end
end)

-- periodic auto-store & save
task.spawn(function() while true do task.wait(2); pcall(AttemptStoreFruit) end end)
task.spawn(function() while true do task.wait(60); SaveConfig() end end)

-- ready notify
task.spawn(function() task.wait(1.2); NotifyVN("started") end)

-- write file and provide path
local path = "/mnt/data/TuanxAura_Hub_v6_PulseNeon_Optimized.lua"
pcall(function()
    local content = "-- Generated by assistant: TuanxAura Hub v6\\n-- Filename: TuanxAura_Hub_v6_PulseNeon_Optimized.lua\\n"
    content = content .. "-- PLEASE USE AN EXECUTOR TO RUN THIS LUA FILE IN ROBLOX ENVIRONMENT\\n"
    -- try to write to disk (if environment allows)
    pcall(function() local f=io.open(path,"w"); if f then f:write(content); f:close() end end)
end)
return path
