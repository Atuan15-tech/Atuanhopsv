-- TuanxAura_Hub_v18_Upgraded.lua
-- Upgraded universal hub: optimized tweening, robust ESP, auto-store from backpack (no need to equip),
-- session timer, improved auto-rejoin, lightweight and executor-friendly.

-- CONFIG
local SETTINGS = {
    AutoFindFruit = true,
    AutoStoreFruit = true,         -- store from backpack/held without equipping
    AutoHop = true,
    AutoRejoinOnHopFail = true,
    FruitScanInterval = 1.0,
    HopTimeoutSeconds = 30,
    SafeTeleportSpeed = 350,       -- reduced speed to avoid teleport issues
    StoreAttemptInterval = 1.2,    -- how often to attempt storing backpack fruits
    ESPUpdateInterval = 0.9,
    SessionTimerUpdate = 1.0,
    CharacterWaitTimeout = 6,
    GameLoadTimeout = 6,
}

-- SAFETY (prevent double-run)
if _G.TuanxAura_Ran then return end
_G.TuanxAura_Ran = true

-- SERVICES (safe get)
local function gs(n) local ok,s = pcall(function() return game:GetService(n) end); return ok and s or nil end
local Players = gs("Players") or game.Players
local TweenService = gs("TweenService") or game:GetService("TweenService")
local ReplicatedStorage = gs("ReplicatedStorage") or game:GetService("ReplicatedStorage")
local HttpService = gs("HttpService") or game:GetService("HttpService")
local TeleportService = gs("TeleportService") or game:GetService("TeleportService")
local Workspace = gs("Workspace") or game:GetService("Workspace")
local CoreGui = gs("CoreGui") or game:GetService("CoreGui")
local UserInputService = gs("UserInputService") or game:GetService("UserInputService")

local LocalPlayer = Players and Players.LocalPlayer

-- NON-BLOCKING WAIT (short timeouts)
local function quickWaitForLocalPlayer(timeout)
    timeout = timeout or SETTINGS.CharacterWaitTimeout
    local s = tick()
    while (not LocalPlayer) and tick()-s < timeout do
        LocalPlayer = Players and Players.LocalPlayer
        task.wait(0.05)
    end
    return LocalPlayer ~= nil
end
quickWaitForLocalPlayer(SETTINGS.CharacterWaitTimeout)

local function getHRP()
    if LocalPlayer and LocalPlayer.Character then
        return LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- THEME
local THEME = Color3.fromRGB(0,255,210)
local FONT_H = Enum.Font.FredokaOne
local FONT_B = Enum.Font.Ubuntu

-- UTILS
local function SetProps(inst, props)
    for k,v in pairs(props) do pcall(function() inst[k] = v end) end
    return inst
end

local function safeInvokeStore(name, tool)
    if not ReplicatedStorage then return nil end
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    if not rem then return nil end
    local comm = rem:FindFirstChild("CommF_")
    if not comm then return nil end
    local ok,res = pcall(function() return comm:InvokeServer("StoreFruit", name, tool) end)
    if ok then return res end
    return nil
end

-- UI CREATION (no loading, UI always visible)
pcall(function() if CoreGui:FindFirstChild("TuanxAura_v18") then CoreGui.TuanxAura_v18:Destroy() end end)
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "TuanxAura_v18"; ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent and LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then ScreenGui.Parent = LocalPlayer.PlayerGui end

local function makeNotify(text, dur)
    dur = dur or 2.6
    if not ScreenGui.Parent then return end
    local root = ScreenGui:FindFirstChild("NotifyRoot") or SetProps(Instance.new("Frame"), {Name="NotifyRoot", Parent=ScreenGui, AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0.06,0), Size=UDim2.new(0,420,0,60), BackgroundTransparency=1})
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,380,0,44); f.AnchorPoint = Vector2.new(0.5,0); f.Position = UDim2.new(0.5,0,-0.2,0); f.BackgroundColor3 = Color3.fromRGB(14,14,16); f.Parent = root
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", f); stroke.Color = THEME; stroke.Transparency = 0.75; stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", f); lbl.Size = UDim2.new(1,-16,1,0); lbl.Position = UDim2.new(0,8,0,0); lbl.BackgroundTransparency = 1; lbl.Font = FONT_B; lbl.TextSize = 16; lbl.TextColor3 = Color3.fromRGB(230,240,255); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = text
    pcall(function() local t = TweenService:Create(f, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0.5,0,0,0)}); t:Play() end)
    task.delay(dur, function() pcall(function() local t2 = TweenService:Create(f, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position=UDim2.new(0.5,0,-0.2,0)}); t2:Play(); t2.Completed:Wait(); f:Destroy() end) end)
end

-- Main frame
local Main = SetProps(Instance.new("Frame"), {Name="MainFrame", Parent=ScreenGui, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,420,0,120), BackgroundColor3=Color3.fromRGB(8,8,10)})
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,12)
local Title = SetProps(Instance.new("TextLabel"), {Parent=Main, Size=UDim2.new(1,-28,0,38), Position=UDim2.new(0,14,0,10), BackgroundTransparency=1, Font=FONT_H, TextSize=20, TextColor3=THEME, Text="💎 TUANXAURA HUB 💙", TextXAlignment=Enum.TextXAlignment.Center})
local Status = SetProps(Instance.new("TextLabel"), {Parent=Main, Name="Status", Size=UDim2.new(1,-28,0,22), Position=UDim2.new(0,14,0,52), BackgroundTransparency=1, Font=FONT_B, TextSize=14, TextColor3=Color3.fromRGB(170,230,210), Text="🛰️ Trạng thái: Khởi động...", TextXAlignment=Enum.TextXAlignment.Left})
local User = SetProps(Instance.new("TextLabel"), {Parent=Main, Size=UDim2.new(0.5,-20,0,18), Position=UDim2.new(0,14,1,-28), BackgroundTransparency=1, Font=FONT_B, TextSize=13, TextColor3=Color3.fromRGB(200,230,255), Text="👤 "..(LocalPlayer and LocalPlayer.Name or "Người chơi"), TextXAlignment=Enum.TextXAlignment.Left})
local Dist = SetProps(Instance.new("TextLabel"), {Parent=Main, Name="Dist", Size=UDim2.new(0.5,-20,0,18), Position=UDim2.new(1,-210,1,-28), BackgroundTransparency=1, Font=FONT_B, TextSize=13, TextColor3=Color3.fromRGB(200,230,255), Text="🍍 Cách: -- m", TextXAlignment=Enum.TextXAlignment.Right})
local TimerLabel = SetProps(Instance.new("TextLabel"), {Parent=Main, Name="Timer", Size=UDim2.new(0.4,0,0,18), Position=UDim2.new(0.03,0,1,-28), BackgroundTransparency=1, Font=FONT_B, TextSize=13, TextColor3=Color3.fromRGB(200,230,255), Text="⏱ 00:00", TextXAlignment=Enum.TextXAlignment.Left})

-- SESSION TIMER
local joinTick = tick()
task.spawn(function()
    while Main and Main.Parent do
        local elapsed = math.max(0, math.floor(tick() - joinTick))
        local m = math.floor(elapsed/60); local s = elapsed%60
        pcall(function() TimerLabel.Text = string.format("⏱ %02d:%02d", m, s) end)
        task.wait(SETTINGS.SessionTimerUpdate)
    end
end)

makeNotify("⚡ TuanxAura Hub đang khởi động...")

-- ESP management
local ESP = {} -- fruit -> {highlight, billboard, label}
local function createESPForFruit(fruit)
    if not fruit or not fruit:IsA("Model") or not fruit:FindFirstChild("Handle") then return end
    if ESP[fruit] then return end
    local handle = fruit.Handle
    local hl = Instance.new("Highlight"); hl.Parent = handle; hl.Adornee = handle; hl.FillColor = THEME; hl.FillTransparency = 0.68; hl.OutlineTransparency = 0.9
    local bb = Instance.new("BillboardGui"); bb.Name = "FruitBB"; bb.Adornee = handle; bb.Size = UDim2.new(0,140,0,36); bb.StudsOffset = Vector3.new(0,2.6,0); bb.AlwaysOnTop = true; bb.Parent = handle
    local lbl = SetProps(Instance.new("TextLabel"), {Parent=bb, BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Font=FONT_B, TextSize=14, TextColor3=Color3.fromRGB(230,240,255), Text="Fruit", TextWrapped=true})
    ESP[fruit] = {hl=hl, bb=bb, lbl=lbl}
end
local function removeESP(fruit)
    local rec = ESP[fruit]
    if rec then
        pcall(function() if rec.hl then rec.hl:Destroy() end end)
        pcall(function() if rec.bb then rec.bb:Destroy() end end)
        ESP[fruit] = nil
    end
end

-- SCAN & UPDATE ESP
local function scanWorkspaceForFruits()
    local fruits = {}
    for _,obj in pairs(Workspace:GetDescendants()) do
        if obj and obj:IsA("Model") and obj.Name and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            table.insert(fruits, obj)
        end
    end
    return fruits
end

task.spawn(function()
    while true do
        local fruits = scanWorkspaceForFruits()
        local present = {}
        for _,f in pairs(fruits) do present[f]=true; if not ESP[f] then createESPForFruit(f) end end
        for f,_ in pairs(ESP) do if not present[f] then removeESP(f) end end
        local hrp = getHRP()
        for f,rec in pairs(ESP) do
            pcall(function()
                local name = f.Name or (f.GetAttribute and f:GetAttribute("OriginalName")) or "Trái"
                local dist = hrp and math.floor((hrp.Position - f.Handle.Position).Magnitude) or nil
                if dist then rec.lbl.Text = string.format("🍍 %s (%dm)", tostring(name), dist) else rec.lbl.Text = tostring("🍍 "..tostring(name)) end
            end)
        end
        task.wait(SETTINGS.ESPUpdateInterval)
    end
end)
-- SAFE STEP-BY-STEP TELEPORT function (replaces SafeTweenToPosition)
local function TeleportToFruit(fruitHandle)
    local HumanoidRootPart = getHRP()
    if not HumanoidRootPart or not HumanoidRootPart.Parent or not fruitHandle then return false end
    if not fruitHandle:IsDescendantOf(Workspace) then return false end

    local SafeMoveSpeed = 250 -- tốc độ di chuyển an toàn
    local stepDelay = 0.03    -- thời gian delay mỗi bước di chuyển
    local stopDistance = 5    -- dừng khi còn cách 5 stud

    local startPos = HumanoidRootPart.Position
    local targetPos = fruitHandle.Position + Vector3.new(0, 2, 0)
    local totalDistance = (targetPos - startPos).Magnitude

    -- Tránh chia cho 0 nếu ở quá gần
    if totalDistance < stopDistance then return true end

    local direction = (targetPos - startPos).Unit

    local startTime = tick()
    local maxDuration = math.min(30, totalDistance / SafeMoveSpeed + 1) -- giới hạn an toàn

    while HumanoidRootPart and HumanoidRootPart.Parent and fruitHandle and fruitHandle:IsDescendantOf(Workspace) do
        local currentPos = HumanoidRootPart.Position
        local distanceLeft = (targetPos - currentPos).Magnitude

        if distanceLeft <= stopDistance then break end
        if tick() - startTime > maxDuration then break end

        -- Cập nhật lại hướng di chuyển để đi theo vật thể nếu nó di chuyển
        local currentDirection = (targetPos - currentPos).Unit

        local moveStep = currentDirection * SafeMoveSpeed * stepDelay
        
        -- Di chuyển CFrame và nhìn về mục tiêu
        pcall(function() HumanoidRootPart.CFrame = CFrame.new(currentPos + moveStep, targetPos) end)

        task.wait(stepDelay)
    end

    task.wait(0.2)
    return true
end

-- ATTEMPT STORE: from held + backpack, non-blocking and debounced
local storeDebounce = false
local function AttemptStoreFruit()
    if not SETTINGS.AutoStoreFruit then return false end
    if storeDebounce then return false end
    storeDebounce = true
    task.spawn(function()
        local storedAny = false
        pcall(function()
            if not LocalPlayer then return end
            local held = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if held and string.find(held.Name or "", "Fruit") then
                local original = (held.GetAttribute and held:GetAttribute("OriginalName")) or held.Name
                local res = safeInvokeStore(original, held)
                if res and res ~= false and res ~= "Full" then storedAny = true; makeNotify("🍈 Đã lưu trái thành công!") end
                if res == "Full" then makeNotify("🧺 Túi trái đầy, bỏ qua trái này.") end
            end
            if LocalPlayer.Backpack then
                for _,tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool and string.find(tool.Name or "", "Fruit") then
                        local original = (tool.GetAttribute and tool:GetAttribute("OriginalName")) or tool.Name
                        local res = safeInvokeStore(original, tool)
                        if res and res ~= false and res ~= "Full" then storedAny = true; makeNotify("🍈 Đã lưu trái trong túi!") end
                        if res == "Full" then makeNotify("🧺 Túi trái đầy, bỏ qua trái trong túi.") end
                        task.wait(0.18)
                    end
                end
            end
        end)
        task.wait(SETTINGS.StoreAttemptInterval)
        storeDebounce = false
        return storedAny
    end)
    return true
end

-- SERVER HOP simple implementation
local function ExecuteServerHop()
    makeNotify("🌍 Không có trái, đang chuyển server...")
    local PlaceId = game.PlaceId; local LocalJobId = game.JobId
    local Cursor = ""; local Blacklisted = {}
    if type(isfile) == "function" and isfile("NotSameServers.json") then pcall(function() Blacklisted = HttpService:JSONDecode(readfile("NotSameServers.json")) end) end
    if #Blacklisted == 0 then table.insert(Blacklisted, os.time()) end
    for page=1,5 do
        local url = "https://games.roblox.com/v1/games/"..tostring(PlaceId).."/servers/Public?sortOrder=Asc&limit=100"
        if Cursor ~= "" then url = url .. "&cursor=" .. tostring(Cursor) end
        local ok,res = pcall(function() return game:HttpGet(url) end)
        if not ok or not res then break end
        local ok2,data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then break end
        Cursor = data.nextPageCursor or ""
        for _,sv in pairs(data.data) do
            if tonumber(sv.playing) and tonumber(sv.maxPlayers) and tonumber(sv.playing) < tonumber(sv.maxPlayers) and tostring(sv.id) ~= tostring(LocalJobId) then
                local sid = tostring(sv.id); local skip=false
                for i=1,#Blacklisted do if tostring(Blacklisted[i])==sid then skip=true; break end end
                if not skip then table.insert(Blacklisted,sid); pcall(function() if type(writefile)=="function" then writefile("NotSameServers.json", HttpService:JSONEncode(Blacklisted)) end end); pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, sid, LocalPlayer) end); return end
            end
        end
        task.wait(0.2)
    end
    pcall(function() TeleportService:Teleport(PlaceId, LocalPlayer) end)
end

-- AUTO REJOIN basic
task.spawn(function()
    while true do
        if not LocalPlayer or not LocalPlayer.Parent then
            makeNotify("🔁 Bị rớt — đang cố vào lại...")
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
        task.wait(3)
    end
end)

-- ANTI-AFK if VirtualUser available
pcall(function()
    local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
    if ok and vu and LocalPlayer then
        LocalPlayer.Idled:Connect(function() pcall(function() vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1); vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end) end)
    end
end)

-- MAIN LOOP: scan fruits, move, store, hop
local lastScan = 0; local noFruitTimer = 0; local currentTarget = nil
makeNotify("💙 TuanxAura Hub: Sẵn sàng, "..(LocalPlayer and LocalPlayer.Name or "Người chơi"))

task.spawn(function()
    while true do
        local now = tick()
        if now - lastScan >= (SETTINGS.FruitScanInterval or 1) then
            lastScan = now
            local fruits = scanWorkspaceForFruits()
            if fruits and #fruits > 0 then
                noFruitTimer = 0
                local target = fruits[1] -- first-found (no priority)
                if target and target:FindFirstChild("Handle") then
                    currentTarget = target
                    local fname = target.Name or (target.GetAttribute and target:GetAttribute("OriginalName")) or "Trái"
                    makeNotify("🥭 Phát hiện trái: "..tostring(fname))
                    pcall(function() Status.Text = "🥭 Đang tới: "..tostring(fname) end)
                    pcall(function() SafeTweenToPosition(target.Handle.Position, SETTINGS.SafeTeleportSpeed) end)
                    task.wait(0.45)
                    pcall(AttemptStoreFruit)
                end
            else
                noFruitTimer = noFruitTimer + (SETTINGS.FruitScanInterval or 1)
                pcall(function() Status.Text = ("💤 Không thấy trái... (%.1fs)"):format(noFruitTimer) end)
                if SETTINGS.AutoHop and noFruitTimer >= (SETTINGS.HopTimeoutSeconds or 30) then
                    noFruitTimer = 0
                    task.spawn(ExecuteServerHop)
                end
            end
        end
        -- update distance label
        pcall(function()
            if currentTarget and currentTarget:FindFirstChild("Handle") and getHRP() then
                local d = math.floor((getHRP().Position - currentTarget.Handle.Position).Magnitude)
                Dist.Text = "🍍 Cách: "..tostring(d).." m"
            else
                Dist.Text = "🍍 Cách: -- m"
            end
        end)
        task.wait(0.12)
    end
end)

-- periodic store attempts (backpack)
task.spawn(function()
    while true do
        pcall(AttemptStoreFruit)
        task.wait(SETTINGS.StoreAttemptInterval)
    end
end)

-- End of file
