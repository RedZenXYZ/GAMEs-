--[[
    Terraria TD Remastered
    Lobby Auto Queue + Match (macro recorder shell) — built on DARK Lib
    (RedZenXYZ/DARK-LIBRARY)
]]

-- ── Wait for the game to fully load, then give it a beat to settle ─────
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(1)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local LocalPlayer        = Players.LocalPlayer

local TWEEN_MEDIUM = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── Place detection ──────────────────────────────────────────────────
local LOBBY_PLACE_ID = 119757349390174

local function IsInLobby()
    return game.PlaceId == LOBBY_PLACE_ID
end

local function GetPlaceName()
    return MarketplaceService:GetProductInfo(game.PlaceId).Name
end

local PlaceNameOk, CurrentPlaceName = pcall(GetPlaceName)
if not PlaceNameOk then
    warn("[TDR] GetProductInfo failed, treating place name as unknown: " .. tostring(CurrentPlaceName))
    CurrentPlaceName = nil
end

local function IsInMatch()
    return CurrentPlaceName == "Match"
end

print(string.format(
    "[TDR] PlaceId=%s  PlaceName=%s  InLobby=%s  InMatch=%s",
    tostring(game.PlaceId), tostring(CurrentPlaceName), tostring(IsInLobby()), tostring(IsInMatch())
))
if not IsInLobby() and not IsInMatch() then
    warn("[TDR] Neither Lobby nor Match detected for this place — no tabs will be built.")
end

-- ── DARK Lib ─────────────────────────────────────────────────────────
local Dark
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/RedZenXYZ/DARK-LIBRARY/main/source.lua"))()
    end)
    if not ok or not result then
        warn("[TDR] Failed to load DARK Lib: " .. tostring(result))
        return
    end
    Dark = result
end
print("[TDR] DARK Lib loaded.")

local Lib = Dark.CreateLib()
print("[TDR] Lib window created.")

-- ── Logger: buffers entries; the Log tab (built at the end) shows them live ─
local MAX_LOG_LINES = 300
local LogEntries = {}
local LogSink = nil              -- set by the Log tab once it exists
local LogGameRemotes = true      -- Log tab toggle: show remotes the game/player fires

local function Log(level, text)
    local entry = {level = level, text = text, time = os.date("%H:%M:%S")}
    table.insert(LogEntries, entry)
    if #LogEntries > MAX_LOG_LINES then table.remove(LogEntries, 1) end
    print(string.format("[TDR][%s] %s", level, text))
    if LogSink then pcall(LogSink, entry) end
end

-- Same as GetFullName() but built from .Parent only, so it's safe inside a __namecall hook
local function PathOf(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, ".")
end

local function Describe(v)
    local t = typeof(v)
    if t == "CFrame" then
        local p = v.Position
        return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
    elseif t == "Instance" then
        return "Instance<" .. PathOf(v) .. ">"
    elseif t == "string" then
        return '"' .. v .. '"'
    elseif t == "table" then
        return "{table}"
    end
    return tostring(v)
end

local function DescribeArgs(args, n)
    local out = {}
    for i = 1, (n or #args) do out[i] = Describe(args[i]) end
    return table.concat(out, ", ")
end

-- ── Config (save/load so Auto Queue survives auto-execute reloads) ─────
local SAVE_DIR  = "TerrariaTDRemastered"
local SAVE_FILE = SAVE_DIR .. "/lobby_queue.json"

local Config = {
    Map       = "Forest",
    Act       = 1,
    Mode      = "Journey",
    AutoQueue = false,
}

function jsonencode(Table)
	return game:GetService("HttpService"):JSONEncode(Table)
end

function jsondecode(TableString)
	return game:GetService("HttpService"):JSONDecode(TableString)
end

local function LoadConfig()
    local ok, result = pcall(function()
        if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
        if isfile and isfile(SAVE_FILE) then
            return jsondecode(readfile(SAVE_FILE))
        end
    end)
    if ok and type(result) == "table" then
        for k, v in pairs(Config) do
            if result[k] == nil then result[k] = v end
        end
        Config = result
    end
end

function SaveConfig()
    if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
    writefile(SAVE_FILE, jsonencode(Config))
    print("Config has been saved.")
end

LoadConfig()

-- ── Maps / Acts / Modes ─────────────────────────────────────────────────
local MAP_ACTS   = {Forest = 6, Desert = 5}
local MAP_NAMES  = {"Forest", "Desert"}
local MODE_NAMES = {"Journey", "Classic", "Expert", "Master"}

local function ActOptions(mapName)
    local opts = {}
    for i = 1, (MAP_ACTS[mapName] or 1) do
        opts[i] = i
    end
    return opts
end

-- ═════════════════════════════════════════════════════════════════════
-- UI HELPER
-- ═════════════════════════════════════════════════════════════════════
local function AddPadding(parent, top, bottom, left, right)
	local UIPadding = Instance.new("UIPadding", parent)
	UIPadding.PaddingTop = UDim.new(0, top)
	UIPadding.PaddingBottom = UDim.new(0, bottom or top)
	UIPadding.PaddingLeft = UDim.new(0, left or top)
	UIPadding.PaddingRight = UDim.new(0, right or top)

	return UIPadding
end

-- ═════════════════════════════════════════════════════════════════════
-- LOBBY TAB
-- ═════════════════════════════════════════════════════════════════════
if IsInLobby() then
    print("[TDR] Building Lobby tab...")
    local Tab = Lib:AddTab("Lobby Queue")

    local Status = Tab:AddTextLabel(
        string.format("%s | %s | %s", Config.Map, Config.Act, Config.Mode),
        12, Color3.fromRGB(160, 160, 165)
    )

    local function UpdateStatus()
        Status:SetText(string.format("%s | %s | %s", Config.Map, Config.Act, Config.Mode))
    end

    local ActDrop -- forward-declared so the Map callback can update it

    Tab:AddDropdown("Map", "Selected map", MAP_NAMES, "single", function(val)
        Config.Map = val
        if Config.Act > (MAP_ACTS[val] or 1) then Config.Act = 1 end
        ActDrop:SetOptions(ActOptions(val))
        SaveConfig()
        UpdateStatus()
    end)

    ActDrop = Tab:AddDropdown("Act", "Selected act", ActOptions(Config.Map), "single", function(val)
        Config.Act = val
        SaveConfig()
        UpdateStatus()
    end)

    Tab:AddDropdown("Mode", "Difficulty", MODE_NAMES, "single", function(val)
        Config.Mode = val
        SaveConfig()
        UpdateStatus()
    end)

    -- ── Queue logic ────────────────────────────────────────────────────
    local function DoQueue()
        local UI = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UI")
        Log("send", string.format(">> CreateQueue(%s, %s, %s, 1, \"\")",
            tostring(Config.Map), tostring(Config.Act), tostring(Config.Mode)))
        local ok, err = pcall(function()
            local r1 = UI.CreateQueue:InvokeServer(Config.Map, Config.Act, Config.Mode, 1, "")
            Log("ok", "<< CreateQueue returned: " .. Describe(r1))
            task.wait(0.5) -- let the queue register server-side before starting it
            Log("send", ">> StartQueue()")
            local r2 = UI.StartQueue:InvokeServer()
            Log("ok", "<< StartQueue returned: " .. Describe(r2))
        end)
        if ok then
            UpdateStatus()
        else
            Log("error", "Queue failed: " .. tostring(err))
            Status:SetText("Queue failed — " .. tostring(err))
        end
        return ok
    end

    Tab:AddButton("Queue Now", "Create + start a queue with the selection above", function()
        DoQueue()
    end)

    Tab:AddToggle("Auto Queue", "Queue automatically when the lobby loads", Config.AutoQueue, function(state)
        Config.AutoQueue = state
        SaveConfig()
        if state then DoQueue() end
    end)

    -- If auto-execute drops us back into the lobby with Auto Queue saved on, fire right away
    if Config.AutoQueue then
        DoQueue()
    end
    print("[TDR] Lobby tab built.")
end

-- ═════════════════════════════════════════════════════════════════════
-- MATCH TAB — full custom UI:
--   left-top box    = recorded macros list (Select / Play per row)
--   left-bottom box = its own box for the record bar
--   right box       = toggles (shrunk ~30px)
-- Editing a recorded macro is a separate tab, not built yet.
-- ═════════════════════════════════════════════════════════════════════
if IsInMatch() then
    print("[TDR] Building Match tab...")
    local Tab = Lib:AddTab("Match", "full")
    local Root = Tab.Content
    AddPadding(Root, 4)

    -- ── Match config: toggle states + selected macro, saved like Lobby's ──
    local MATCH_SAVE_FILE = SAVE_DIR .. "/match_config.json"
    local MatchConfig = {
        AutoReplay        = false,
        AutoCollectItems  = false,
        AutoPlayMacro     = false,
        SelectedMacroName = nil,
    }

    local function LoadMatchConfig()
        local ok, result = pcall(function()
            if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            if isfile and isfile(MATCH_SAVE_FILE) then
                return jsondecode(readfile(MATCH_SAVE_FILE))
            end
        end)
        if ok and type(result) == "table" then
            for k, v in pairs(MatchConfig) do
                if result[k] == nil then result[k] = v end
            end
            MatchConfig = result
        end
    end

    local function SaveMatchConfig()
        pcall(function()
            if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            writefile(MATCH_SAVE_FILE, jsonencode(MatchConfig))
            print("Match config has been saved.")
        end)
    end

    LoadMatchConfig()

    -- Forward-declared so earlier UI closures can call later definitions
    local Macros = {}
    local SelectedMacro, SelectedRow = nil, nil
    local RemotesByLabel = {}
    local TargetRemotes = {}          -- [remote instance] = label (filled by the remote scan)
    local Playing = false             -- true while a macro is running (blocks overlapping runs)
    local HookInstalled = false
    local SelfCalls = 0               -- lets the remote spy skip calls this script makes itself
    local PlayMacro, RunMacro, AddMacroListEntry, SaveMacros, LoadMacros

    -- Fires a remote using the right method for its class (never trusts a stored
    -- method name), returns pcall's (ok, result). Packs varargs HERE, not in the
    -- closure, since a nested function can't use ... directly.
    local function CallRemote(remote, ...)
        local args = table.pack(...)
        if HookInstalled and TargetRemotes[remote] then
            SelfCalls = SelfCalls + 1 -- the hook consumes this synchronously
        end
        local ok, res = pcall(function()
            if remote:IsA("RemoteFunction") then
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            else
                return remote:FireServer(table.unpack(args, 1, args.n))
            end
        end)
        SelfCalls = 0 -- anything unconsumed means the call never reached the hook
        return ok, res
    end

    -- ── Mana: PlayerGui.Main.Mana.Value (NumberValue) ─────────────────────
    local function GetManaValue()
        local gui  = LocalPlayer:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("Main")
        local mana = main and main:FindFirstChild("Mana")
        return mana and mana:FindFirstChild("Value")
    end

    -- Blocks until mana >= cost (60s cap). Never blocks if the value isn't found.
    local function WaitForMana(cost, tag)
        local v = GetManaValue()
        if not v then
            Log("warn", "Mana value not found (PlayerGui.Main.Mana.Value), not waiting")
            return true
        end
        if v.Value >= cost then return true end

        local t0 = tick()
        Log("info", string.format("%s waiting for mana: %.0f/%.0f", tag, v.Value, cost))
        while v.Value < cost and tick() - t0 < 60 do task.wait(0.1) end
        if v.Value >= cost then
            Log("ok", string.format("%s mana ready after %.1fs (%.0f)", tag, tick() - t0, v.Value))
            return true
        end
        Log("warn", string.format("%s mana wait timed out (%.0f/%.0f), firing anyway", tag, v.Value, cost))
        return false
    end

    -- While recording: after an action is captured, the first drop in mana
    -- (within 1.5s) is that action's cost. A newer action cancels the older watch.
    local CostWatcher = nil
    local function WatchManaCost(action)
        if CostWatcher then CostWatcher:Disconnect(); CostWatcher = nil end
        local v = GetManaValue()
        if not v then return end

        local before = v.Value
        local conn
        conn = v.Changed:Connect(function(new)
            if new < before then
                action.mana = math.ceil((before - new) - 1e-6)
                Log("info", string.format("REC %s costs %d mana", action.remote, action.mana))
                conn:Disconnect()
                if CostWatcher == conn then CostWatcher = nil end
            end
        end)
        CostWatcher = conn
        task.delay(1.5, function()
            if conn.Connected then conn:Disconnect() end
            if CostWatcher == conn then CostWatcher = nil end
        end)
    end

    -- ── Left-top box: recorded macros list ──────────────────────────────
    local MacroBox = Instance.new("Frame", Root)
    MacroBox.Size = UDim2.new(0.7, -6, 0.8, 0)
    MacroBox.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    MacroBox.BackgroundTransparency = 0.3
    Instance.new("UICorner", MacroBox).CornerRadius = UDim.new(0, 10)
    AddPadding(MacroBox, 4)

    local MacroHeader = Instance.new("TextLabel", MacroBox)
    MacroHeader.Size = UDim2.new(1, 0, 0, 22)
    MacroHeader.BackgroundTransparency = 1
    MacroHeader.Text = "Macros"
    MacroHeader.TextColor3 = Color3.fromRGB(230, 230, 230)
    MacroHeader.TextSize = 13
    MacroHeader.Font = Enum.Font.GothamBold
    MacroHeader.TextXAlignment = Enum.TextXAlignment.Left

    local MacroList = Instance.new("ScrollingFrame", MacroBox)
    MacroList.Size = UDim2.new(1, 0, 1, -26)
    MacroList.Position = UDim2.new(0, 0, 0, 26)
    MacroList.BackgroundTransparency = 1
    MacroList.BorderSizePixel = 0
    MacroList.ScrollBarThickness = 4
    MacroList.CanvasSize = UDim2.new(0, 0, 0, 0)
    MacroList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MacroList.ClipsDescendants = true

    local MacroListLayout = Instance.new("UIListLayout", MacroList)
    MacroListLayout.Padding = UDim.new(0, 4)
    MacroListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- ── Left-bottom box: its own box for the record bar ──────────────────
    local RecordBox = Instance.new("Frame", Root)
    RecordBox.Size = UDim2.new(0.7, -6, 0.2, -4)
    RecordBox.Position = UDim2.new(0, 0, 0.8, 4)
    RecordBox.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    RecordBox.BackgroundTransparency = 0.3
    Instance.new("UICorner", RecordBox).CornerRadius = UDim.new(0, 10)
    AddPadding(RecordBox, 4)

    local RecordHeader = Instance.new("TextLabel", RecordBox)
    RecordHeader.Size = UDim2.new(0.8, 0, 0.3, 0)
    RecordHeader.Position = UDim2.new(0, 3, 0, 0)
    RecordHeader.BackgroundTransparency = 1
    RecordHeader.Text = "Record"
    RecordHeader.TextColor3 = Color3.fromRGB(230, 230, 230)
    RecordHeader.TextSize = 12
    RecordHeader.Font = Enum.Font.GothamBold
    RecordHeader.TextXAlignment = Enum.TextXAlignment.Left

    local RecordBar = Instance.new("Frame", RecordBox)
    RecordBar.Size = UDim2.new(1, 0, 0.7, 0)
    RecordBar.Position = UDim2.new(0, 0, 1, 2)
    RecordBar.AnchorPoint = Vector2.new(0, 1)
    RecordBar.BackgroundTransparency = 1

    local NameBox = Instance.new("TextBox", RecordBar)
    NameBox.Size = UDim2.new(0.65, -4, 1, 0)
    NameBox.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    NameBox.BackgroundTransparency = 0.2
    NameBox.PlaceholderText = "Macro name..."
    NameBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
    NameBox.Text = ""
    NameBox.TextColor3 = Color3.fromRGB(220, 220, 225)
    NameBox.TextSize = 12
    NameBox.Font = Enum.Font.Gotham
    NameBox.ClearTextOnFocus = false
    Instance.new("UICorner", NameBox).CornerRadius = UDim.new(0, 8)
    local nbPad = Instance.new("UIPadding", NameBox)
    nbPad.PaddingLeft = UDim.new(0, 8)

    local RecordButton = Instance.new("TextButton", RecordBar)
    RecordButton.Size = UDim2.new(0.35, -4, 1, 0)
    RecordButton.Position = UDim2.new(0.65, 4, 0, 0)
    RecordButton.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
    RecordButton.Text = "Record"
    RecordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RecordButton.TextSize = 12
    RecordButton.Font = Enum.Font.GothamBold
    RecordButton.AutoButtonColor = false
    Instance.new("UICorner", RecordButton).CornerRadius = UDim.new(0, 8)

    local RightBox = Instance.new("Frame", Root)
    RightBox.Size = UDim2.new(0.3, 0, 1, 0)
    RightBox.Position = UDim2.new(1, 0, 0, 0)
    RightBox.AnchorPoint = Vector2.new(1, 0)
    RightBox.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    RightBox.BackgroundTransparency = 0.3
    Instance.new("UICorner", RightBox).CornerRadius = UDim.new(0, 10)

    local RightHeader = Instance.new("TextLabel", RightBox)
    RightHeader.Size = UDim2.new(1, -12, 0, 22)
    RightHeader.Position = UDim2.new(0, 8, 0, 6)
    RightHeader.BackgroundTransparency = 1
    RightHeader.Text = "Toggles"
    RightHeader.TextColor3 = Color3.fromRGB(230, 230, 230)
    RightHeader.TextSize = 13
    RightHeader.Font = Enum.Font.GothamBold
    RightHeader.TextXAlignment = Enum.TextXAlignment.Left

    local TogglesHolder = Instance.new("Frame", RightBox)
    TogglesHolder.Size = UDim2.new(1, -12, 1, -38)
    TogglesHolder.Position = UDim2.new(0, 6, 0, 32)
    TogglesHolder.BackgroundTransparency = 1

    local TogglesLayout = Instance.new("UIListLayout", TogglesHolder)
    TogglesLayout.Padding = UDim.new(0, 6)
    TogglesLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function MakeCustomToggle(parent, name, initial, callback)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
        row.BackgroundTransparency = 0.3
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(230, 230, 230)
        label.TextScaled = true
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left

        local trackW, trackH = 40, 22
        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(0, trackW, 0, trackH)
        track.AnchorPoint = Vector2.new(1, 0.5)
        track.Position = UDim2.new(1, -10, 0.5, 0)
        track.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", track)
        knob.Size = UDim2.new(0, trackH - 6, 0, trackH - 6)
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Position = UDim2.new(0, 3, 0.5, 0)
        knob.BackgroundColor3 = Color3.fromRGB(200, 200, 205)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local hit = Instance.new("TextButton", row)
        hit.Size = UDim2.new(1, 0, 1, 0)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.ZIndex = 5

        local state = initial or false
        if state then
            knob.Position = UDim2.new(0, trackW - (trackH - 6) - 3, 0.5, 0)
            track.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
        end

        hit.MouseButton1Click:Connect(function()
            state = not state
            local knobX = state and (trackW - (trackH - 6) - 3) or 3
            TweenService:Create(knob, TWEEN_MEDIUM, {Position = UDim2.new(0, knobX, 0.5, 0)}):Play()
            TweenService:Create(track, TWEEN_MEDIUM, {
                BackgroundColor3 = state and Color3.fromRGB(100, 180, 255) or Color3.fromRGB(55, 55, 60)
            }):Play()
            if callback then callback(state) end
        end)

        return row
    end

    -- ── Auto-Collect Items: touch every part under workspace.Drops that
    -- actually has a TouchTransmitter (meaning something listens for touch) ─
    local AutoCollectConnection = nil

    local function StartAutoCollect()
        if AutoCollectConnection then return end
        AutoCollectConnection = RunService.Heartbeat:Connect(function()
            local character  = LocalPlayer.Character
            local hrp        = character and character:FindFirstChild("HumanoidRootPart")
            local dropsFolder = Workspace:FindFirstChild("Drops")
            if not (hrp and dropsFolder) then return end

            for _, part in ipairs(dropsFolder:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") then
                    firetouchinterest(hrp, part, 0)
                    firetouchinterest(hrp, part, 1)
                end
            end
        end)
    end

    local function StopAutoCollect()
        if AutoCollectConnection then
            AutoCollectConnection:Disconnect()
            AutoCollectConnection = nil
        end
    end

    -- ── Shared remote-fire helper (used by Auto-Replay) ─────────────────────
    local function FireRemoteByLabel(label, ...)
        local remote = RemotesByLabel[label]
        if not remote then
            Log("error", "Remote not found: " .. label)
            return false
        end
        Log("send", ">> " .. label .. "(" .. DescribeArgs(table.pack(...)) .. ")")
        local ok, res = CallRemote(remote, ...)
        if ok then
            Log("ok", "<< " .. label .. " returned: " .. Describe(res))
        else
            Log("error", "<< " .. label .. " error: " .. tostring(res))
        end
        return ok
    end

    -- ── Auto-Replay: wait for the Rewards menu to be visible, then wait 3s
    -- and replay; if it's already visible when enabled, skip straight to the
    -- 3s delay instead of waiting for a Visible change that already happened ─
    local function GetRewardsFrame()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local main = playerGui and playerGui:FindFirstChild("Main")
        return main and main:FindFirstChild("Rewards")
    end

    local AutoReplayRunning = false

    local function StartAutoReplay()
        if AutoReplayRunning then return end
        AutoReplayRunning = true
        task.spawn(function()
            while MatchConfig.AutoReplay do
                local rewards = GetRewardsFrame()
                if rewards then
                    if not rewards.Visible then
                        local signal = rewards:GetPropertyChangedSignal("Visible")
                        while MatchConfig.AutoReplay and not rewards.Visible do
                            signal:Wait()
                        end
                    end
                    if MatchConfig.AutoReplay and rewards.Visible then
                        Log("info", "Auto-Replay: Rewards visible, replaying in 3s")
                        task.wait(3)
                        if MatchConfig.AutoReplay then
                            FireRemoteByLabel("General.ReplayMatch")
                        end
                        -- don't re-trigger instantly next loop — wait for it to hide first
                        while MatchConfig.AutoReplay and rewards.Visible do
                            task.wait(0.25)
                        end
                    end
                else
                    task.wait(0.5)
                end
            end
            AutoReplayRunning = false
        end)
    end

    -- ── Auto-Play Macro: repeat the selected macro while the toggle is on ──
    local AutoPlayRunning = false

    local function StartAutoPlayMacro()
        if AutoPlayRunning then return end
        AutoPlayRunning = true
        task.spawn(function()
            local warnedNoSelection = false
            while MatchConfig.AutoPlayMacro do
                local rewards = GetRewardsFrame()
                -- never start while the results screen is up; wait for the next match
                while MatchConfig.AutoPlayMacro and rewards and rewards.Visible do
                    task.wait(0.5)
                end
                if not MatchConfig.AutoPlayMacro then break end

                if SelectedMacro and not Playing then
                    warnedNoSelection = false
                    Log("info", "Auto-Play: starting '" .. SelectedMacro.Name .. "'")
                    RunMacro(SelectedMacro)
                    -- play once per match: wait for this match to end (Rewards shows),
                    -- the loop top then waits for it to hide again (next match)
                    if rewards then
                        while MatchConfig.AutoPlayMacro and not rewards.Visible do
                            task.wait(0.5)
                        end
                    else
                        task.wait(5)
                    end
                else
                    if not SelectedMacro and not warnedNoSelection then
                        warnedNoSelection = true
                        Log("warn", "Auto-Play: no macro selected (use Select on a macro)")
                    end
                    task.wait(1)
                end
            end
            AutoPlayRunning = false
        end)
    end

    MakeCustomToggle(TogglesHolder, "Auto-Replay", MatchConfig.AutoReplay, function(state)
        MatchConfig.AutoReplay = state
        SaveMatchConfig()
        Log("info", "Auto-Replay " .. (state and "ON" or "OFF"))
        if state then StartAutoReplay() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Collect Items", MatchConfig.AutoCollectItems, function(state)
        MatchConfig.AutoCollectItems = state
        SaveMatchConfig()
        Log("info", "Auto-Collect Items " .. (state and "ON" or "OFF"))
        if state then StartAutoCollect() else StopAutoCollect() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Play Macro", MatchConfig.AutoPlayMacro, function(state)
        MatchConfig.AutoPlayMacro = state
        SaveMatchConfig()
        Log("info", "Auto-Play Macro " .. (state and "ON" or "OFF"))
        if state then StartAutoPlayMacro() end
    end)

    -- ── Macro persistence (CFrame/Vector3 aren't JSON-safe, so wrap them) ─
    local MACRO_FILE = SAVE_DIR .. "/macros.json"

    local function SerializeValue(v)
        local t = typeof(v)
        if t == "CFrame" then
            return {__t = "CFrame", c = {v:GetComponents()}}
        elseif t == "Vector3" then
            return {__t = "Vector3", x = v.X, y = v.Y, z = v.Z}
        else
            return v
        end
    end

    local function DeserializeValue(v)
        if type(v) == "table" and v.__t == "CFrame" then
            return CFrame.new(table.unpack(v.c))
        elseif type(v) == "table" and v.__t == "Vector3" then
            return Vector3.new(v.x, v.y, v.z)
        else
            return v
        end
    end

    local function SerializeMacros(list)
        local out = {}
        for i, macro in ipairs(list) do
            local actions = {}
            for j, action in ipairs(macro.Actions) do
                local args = {}
                for k, v in ipairs(action.args) do
                    args[k] = SerializeValue(v)
                end
                actions[j] = {t = action.t, remote = action.remote, method = action.method, mana = action.mana, args = args}
            end
            out[i] = {Name = macro.Name, Actions = actions}
        end
        return out
    end

    local function DeserializeMacros(raw)
        local out = {}
        for i, macro in ipairs(raw) do
            local actions = {}
            for j, action in ipairs(macro.Actions) do
                local args = {}
                for k, v in ipairs(action.args) do
                    args[k] = DeserializeValue(v)
                end
                actions[j] = {t = action.t, remote = action.remote, method = action.method, mana = action.mana, args = args}
            end
            out[i] = {Name = macro.Name, Actions = actions}
        end
        return out
    end

    SaveMacros = function()
        local ok, err = pcall(function()
            if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            writefile(MACRO_FILE, jsonencode(SerializeMacros(Macros)))
        end)
        if ok then
            Log("ok", "Macros saved (" .. #Macros .. ")")
        else
            Log("error", "Saving macros failed: " .. tostring(err))
        end
    end

    -- ── Macro list rows: name, Select (marks it for Auto-Play), Play ─────
    AddMacroListEntry = function(macro)
        local row = Instance.new("Frame", MacroList)
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
        row.BackgroundTransparency = 0.3
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        -- Label doubles as a button so a double-click can trigger rename
        local label = Instance.new("TextButton", row)
        label.Size = UDim2.new(1, -120, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = string.format("%s  (%d)", macro.Name, #macro.Actions)
        label.TextColor3 = Color3.fromRGB(210, 210, 215)
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.AutoButtonColor = false

        local SelectBtn = Instance.new("TextButton", row)
        SelectBtn.Size = UDim2.new(0, 40, 0, 20)
        SelectBtn.AnchorPoint = Vector2.new(1, 0.5)
        SelectBtn.Position = UDim2.new(1, -72, 0.5, 0)
        SelectBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        SelectBtn.Text = "Select"
        SelectBtn.TextSize = 10
        SelectBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
        SelectBtn.Font = Enum.Font.GothamMedium
        SelectBtn.AutoButtonColor = false
        Instance.new("UICorner", SelectBtn).CornerRadius = UDim.new(0, 6)

        local PlayBtn = Instance.new("TextButton", row)
        PlayBtn.Size = UDim2.new(0, 36, 0, 20)
        PlayBtn.AnchorPoint = Vector2.new(1, 0.5)
        PlayBtn.Position = UDim2.new(1, -32, 0.5, 0)
        PlayBtn.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
        PlayBtn.Text = "Play"
        PlayBtn.TextSize = 10
        PlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        PlayBtn.Font = Enum.Font.GothamBold
        PlayBtn.AutoButtonColor = false
        Instance.new("UICorner", PlayBtn).CornerRadius = UDim.new(0, 6)

        local DeleteBtn = Instance.new("TextButton", row)
        DeleteBtn.Size = UDim2.new(0, 22, 0, 20)
        DeleteBtn.AnchorPoint = Vector2.new(1, 0.5)
        DeleteBtn.Position = UDim2.new(1, -6, 0.5, 0)
        DeleteBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        DeleteBtn.Text = "✕"
        DeleteBtn.TextSize = 11
        DeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DeleteBtn.Font = Enum.Font.GothamBold
        DeleteBtn.AutoButtonColor = false
        Instance.new("UICorner", DeleteBtn).CornerRadius = UDim.new(0, 6)

        if MatchConfig.SelectedMacroName == macro.Name then
            SelectedMacro, SelectedRow = macro, row
            row.BackgroundColor3 = Color3.fromRGB(45, 65, 90)
        end

        SelectBtn.MouseButton1Click:Connect(function()
            if SelectedRow then
                SelectedRow.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
            end
            SelectedMacro, SelectedRow = macro, row
            row.BackgroundColor3 = Color3.fromRGB(45, 65, 90)
            MatchConfig.SelectedMacroName = macro.Name
            SaveMatchConfig()
        end)

        PlayBtn.MouseButton1Click:Connect(function()
            PlayMacro(macro)
        end)

        DeleteBtn.MouseButton1Click:Connect(function()
            local idx = table.find(Macros, macro)
            if idx then table.remove(Macros, idx) end
            if SelectedMacro == macro then
                SelectedMacro, SelectedRow = nil, nil
                MatchConfig.SelectedMacroName = nil
                SaveMatchConfig()
            end
            row:Destroy()
            SaveMacros()
        end)

        -- Double-click the label (two clicks within 0.4s) to rename in place
        local lastLabelClick = 0
        label.MouseButton1Click:Connect(function()
            local now = tick()
            if now - lastLabelClick < 0.4 then
                lastLabelClick = 0

                local editBox = Instance.new("TextBox", row)
                editBox.Size = label.Size
                editBox.Position = label.Position
                editBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                editBox.BackgroundTransparency = 0.1
                editBox.Text = macro.Name
                editBox.TextColor3 = Color3.fromRGB(230, 230, 230)
                editBox.TextSize = 12
                editBox.Font = Enum.Font.Gotham
                editBox.TextXAlignment = Enum.TextXAlignment.Left
                editBox.ClearTextOnFocus = false
                Instance.new("UICorner", editBox).CornerRadius = UDim.new(0, 6)
                local editPad = Instance.new("UIPadding", editBox)
                editPad.PaddingLeft = UDim.new(0, 4)

                label.Visible = false
                editBox:CaptureFocus()

                editBox.FocusLost:Connect(function()
                    local newName = editBox.Text
                    if newName ~= "" then
                        macro.Name = newName
                        label.Text = string.format("%s  (%d)", macro.Name, #macro.Actions)
                        if SelectedMacro == macro then
                            MatchConfig.SelectedMacroName = macro.Name
                            SaveMatchConfig()
                        end
                        SaveMacros()
                    end
                    editBox:Destroy()
                    label.Visible = true
                end)
            else
                lastLabelClick = now
            end
        end)

        return row
    end

    LoadMacros = function()
        local ok, raw = pcall(function()
            if isfile and isfile(MACRO_FILE) then
                return jsondecode(readfile(MACRO_FILE))
            end
        end)
        if ok and type(raw) == "table" then
            Macros = DeserializeMacros(raw)
            for _, macro in ipairs(Macros) do
                AddMacroListEntry(macro)
            end
        end
    end

    -- ── Playback: replays each recorded remote call at its recorded offset ─
    -- Every call runs in its own thread so one InvokeServer the server never
    -- answers can't stall the rest of the timeline, and every send / return /
    -- error / missing remote goes to the Log tab. Only one macro runs at a time.
    RunMacro = function(macro)
        if Playing then
            Log("warn", "Already playing a macro, ignoring '" .. macro.Name .. "'")
            return false
        end
        Playing = true

        local total = #macro.Actions
        local okCount, failCount, missing, pending = 0, 0, 0, 0

        local ran, err = pcall(function()
            Log("info", string.format("PLAY '%s' (%d actions)", macro.Name, total))

            -- place/upgrade actions recorded before mana support have no cost to wait for
            local unknownCost = 0
            for _, a in ipairs(macro.Actions) do
                if (a.remote == "Battle.PlaceTower" or a.remote == "UI.UpgradeTower") and not a.mana then
                    unknownCost = unknownCost + 1
                end
            end
            if unknownCost > 0 then
                Log("warn", unknownCost .. " place/upgrade action(s) have no recorded mana cost; re-record to enable mana waiting")
            end

            local startedAt = tick()
            local lag = 0 -- how far the timeline has slipped (mana waits, slow answers)
            for i, action in ipairs(macro.Actions) do
                local target = action.t + lag
                local remaining = target - (tick() - startedAt)
                if remaining > 0 then task.wait(remaining) end

                local remote = RemotesByLabel[action.remote]
                local tag = string.format("#%d/%d %s", i, total, action.remote)
                if not remote then
                    missing = missing + 1
                    Log("error", tag .. " - remote not found, skipped")
                else
                    if action.mana and action.mana > 0 then
                        WaitForMana(action.mana, tag)
                    end

                    Log("send", string.format(">> %s(%s) @%.1fs", tag, DescribeArgs(action.args), action.t))
                    pending = pending + 1
                    local done = false
                    task.spawn(function()
                        local t0 = tick()
                        local ok, res = CallRemote(remote, table.unpack(action.args))
                        local dt = tick() - t0
                        if not ok then
                            failCount = failCount + 1
                            Log("error", string.format("<< %s error: %s (%.2fs)", tag, tostring(res), dt))
                        elseif res == false then
                            failCount = failCount + 1
                            Log("warn", string.format("<< %s returned false, server rejected it? (%.2fs)", tag, dt))
                        else
                            okCount = okCount + 1
                            Log("ok", string.format("<< %s returned %s (%.2fs)", tag, Describe(res), dt))
                        end
                        pending = pending - 1
                        done = true
                    end)

                    -- RemoteFunction: wait for the server's answer (5s cap) so the next
                    -- action (targeting / upgrade / sell) runs after this one landed
                    if remote:IsA("RemoteFunction") then
                        local deadline = tick() + 5
                        while not done and tick() < deadline do task.wait(0.05) end
                    end
                end

                local late = (tick() - startedAt) - target
                if late > 0.25 then lag = lag + late end
            end

            -- let in-flight calls report back before summarizing
            local deadline = tick() + 10
            while pending > 0 and tick() < deadline do task.wait(0.1) end
            if pending > 0 then
                Log("warn", pending .. " call(s) never returned (server not answering?)")
            end
        end)

        Playing = false
        if not ran then Log("error", "Playback crashed: " .. tostring(err)) end
        Log("info", string.format("DONE '%s': %d ok, %d failed/rejected, %d missing remote",
            macro.Name, okCount, failCount, missing))
        return ran
    end

    PlayMacro = function(macro)
        task.spawn(RunMacro, macro)
    end

    LoadMacros()

    -- ── Macro recording ───────────────────────────────────────────────────
    -- Wired up before remote scanning below, so the button always works
    -- even if remote discovery is slow or something under it errors.
    local Recording = false
    local RecordStart = 0
    local CurrentMacro = nil

    RecordButton.MouseButton1Click:Connect(function()
        if not Recording then
            Recording = true
            RecordStart = tick()
            CurrentMacro = {
                Name = NameBox.Text ~= "" and NameBox.Text or ("Macro_" .. os.date("%H%M%S")),
                Actions = {},
            }
            RecordButton.Text = "Stop"
            RecordButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            Log("info", "REC start '" .. CurrentMacro.Name .. "'")
            if not HookInstalled then
                Log("error", "Remote hook is not installed, nothing will be captured")
            end
        else
            Recording = false
            RecordButton.Text = "Record"
            RecordButton.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
            if CurrentMacro then
                local count = #CurrentMacro.Actions
                Log(count > 0 and "info" or "warn",
                    string.format("REC stop '%s': %d actions", CurrentMacro.Name, count))
                local hasInstance = false
                for _, a in ipairs(CurrentMacro.Actions) do
                    for _, v in ipairs(a.args) do
                        if typeof(v) == "Instance" then hasInstance = true end
                    end
                end
                if hasInstance then
                    Log("warn", "Macro has Instance arguments; they can't be saved to disk (this session only)")
                end
                table.insert(Macros, CurrentMacro)
                AddMacroListEntry(CurrentMacro)
                SaveMacros()
            end
            CurrentMacro = nil
            NameBox.Text = ""
        end
    end)

    local function RecordAction(label, method, ...)
        if not CurrentMacro then return end
        local action = {
            t = tick() - RecordStart,
            remote = label,
            method = method,
            args = {...},
        }
        table.insert(CurrentMacro.Actions, action)
        task.defer(WatchManaCost, action) -- measures what this call cost in mana
    end

    -- Every RemoteEvent/RemoteFunction under Events gets tracked dynamically
    -- (PlaceTower, TowerTargeting, UpgradeTower, SellTower, Skip, StartMatch,
    -- ReplayMatch, and anything else that shows up), instead of a fixed list.
    -- Runs in its own thread so a slow/missing remote can never block the UI.
    local IGNORED_REMOTES = {PickupDrop = true}
    local scanned = false

    local function RegisterRemote(inst)
        local isRemote = inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")
        if isRemote and not IGNORED_REMOTES[inst.Name] then
            local label = inst:GetFullName():match("Events%.(.+)") or inst.Name
            TargetRemotes[inst] = label
            RemotesByLabel[label] = inst
            if scanned then Log("info", "Remote added: " .. label) end
        end
    end

    -- Called from the __namecall hook for every client->server call on a tracked
    -- remote that this script did not make itself.
    local function OnGameRemote(label, method, ...)
        local recording = Recording
        if recording then RecordAction(label, method, ...) end
        if recording or LogGameRemotes then
            local args = table.pack(...)
            task.defer(function()
                Log("send", string.format("%s %s (%s) %s",
                    recording and "REC" or "GAME", label, method, DescribeArgs(args)))
            end)
        end
    end

    local LastKey, LastTime = nil, 0

    -- A remote we haven't tracked (outside Events, created late, or replaced by
    -- the game) is picked up the first time it fires while recording.
    local function TrackUnknownRemote(remote)
        if typeof(remote) ~= "Instance" or IGNORED_REMOTES[remote.Name] then return nil end
        local path = PathOf(remote)
        if not path:find("^ReplicatedStorage") or path:find("DefaultChatSystemChatEvents", 1, true) then
            return nil
        end
        local label = path:match("Events%.(.+)") or path
        TargetRemotes[remote] = label
        RemotesByLabel[label] = remote
        task.defer(Log, "info", "Auto-tracking remote first seen while recording: " .. label)
        return label
    end

    -- Every client->server call lands here, from both hook layers
    local function HandleRemoteCall(self, method, ...)
        if SelfCalls == 0 and not Recording and not LogGameRemotes then return end

        local label = TargetRemotes[self]
        if not label then
            if not Recording then return end
            label = TrackUnknownRemote(self)
            if not label then return end
        end

        local args = table.pack(...)
        local key = label .. "|" .. DescribeArgs(args, args.n)
        local now = tick()
        if key == LastKey and now - LastTime < 0.05 then return end -- other hook layer already saw it
        LastKey, LastTime = key, now

        if SelfCalls > 0 then
            SelfCalls = SelfCalls - 1 -- our own call (playback/auto), already logged
            return
        end
        OnGameRemote(label, method, table.unpack(args, 1, args.n))
    end

    local function HookRemoteMethod(className, methodName)
        local ok, err = pcall(function()
            local probe = Instance.new(className)
            local orig
            orig = hookfunction(probe[methodName], newcclosure(function(self, ...)
                pcall(HandleRemoteCall, self, methodName, ...)
                return orig(self, ...)
            end))
            probe:Destroy()
        end)
        if ok then
            Log("info", "Hooked " .. className .. "." .. methodName)
        else
            Log("warn", "Could not hook " .. className .. "." .. methodName .. ": " .. tostring(err))
        end
    end

    task.spawn(function()
        local ok, Events = pcall(function()
            return ReplicatedStorage:WaitForChild("Events", 15)
        end)
        if not (ok and Events) then
            Log("error", "ReplicatedStorage.Events not found after 15s; recording and playback unavailable")
            return
        end

        for _, inst in ipairs(Events:GetDescendants()) do
            RegisterRemote(inst)
        end
        scanned = true
        Events.DescendantAdded:Connect(RegisterRemote)

        local labels = {}
        for _, label in pairs(TargetRemotes) do labels[#labels + 1] = label end
        table.sort(labels)
        Log("info", string.format("Tracking %d remotes: %s", #labels, table.concat(labels, ", ")))

        local OldNamecall
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" or method == "FireServer" then
                local ok, err = pcall(HandleRemoteCall, self, method, ...)
                if not ok then task.defer(Log, "error", "Remote hook error: " .. tostring(err)) end
                if setnamecallmethod then setnamecallmethod(method) end -- nested namecalls can overwrite it
            end
            return OldNamecall(self, ...)
        end))

        -- Also hook the method functions themselves: calls that don't use obj:Method()
        -- syntax (pcall(remote.InvokeServer, remote, ...), cached method references)
        -- never reach __namecall. HandleRemoteCall dedupes calls both layers see.
        HookRemoteMethod("RemoteFunction", "InvokeServer")
        HookRemoteMethod("RemoteEvent", "FireServer")
        HookRemoteMethod("UnreliableRemoteEvent", "FireServer")

        HookInstalled = true
        Log("info", "Remote hooks installed")
    end)

    -- Resume any toggles that were saved as on, now that everything above is set up
    if MatchConfig.AutoCollectItems then StartAutoCollect() end
    if MatchConfig.AutoReplay then StartAutoReplay() end
    if MatchConfig.AutoPlayMacro then StartAutoPlayMacro() end
    print("[TDR] Match tab built.")
end

-- ═════════════════════════════════════════════════════════════════════
-- LOG TAB — live view of what the script sends, receives and decides.
-- Entries logged before this tab exists are buffered and flushed here.
-- ═════════════════════════════════════════════════════════════════════
do
    local LOG_COLORS = {
        info  = Color3.fromRGB(170, 170, 175),
        send  = Color3.fromRGB(110, 170, 255),
        ok    = Color3.fromRGB(100, 200, 130),
        warn  = Color3.fromRGB(230, 190, 80),
        error = Color3.fromRGB(235, 95, 95),
    }

    local Tab = Lib:AddTab("Log", "full")
    local Root = Tab.Content
    AddPadding(Root, 4)

    local Box = Instance.new("Frame", Root)
    Box.Size = UDim2.new(1, 0, 1, 0)
    Box.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    Box.BackgroundTransparency = 0.3
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 10)

    local Title = Instance.new("TextLabel", Box)
    Title.Size = UDim2.new(0, 60, 0, 22)
    Title.Position = UDim2.new(0, 10, 0, 6)
    Title.BackgroundTransparency = 1
    Title.Text = "Log"
    Title.TextColor3 = Color3.fromRGB(230, 230, 230)
    Title.TextSize = 13
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local function MakeBarButton(text, rightOffset, width)
        local b = Instance.new("TextButton", Box)
        b.Size = UDim2.new(0, width, 0, 22)
        b.AnchorPoint = Vector2.new(1, 0)
        b.Position = UDim2.new(1, -rightOffset, 0, 6)
        b.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(230, 230, 230)
        b.TextSize = 11
        b.Font = Enum.Font.GothamMedium
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local ClearBtn = MakeBarButton("Clear", 8, 50)
    local CopyBtn  = MakeBarButton("Copy", 64, 50)
    local SpyBtn   = MakeBarButton("Spy: ON", 120, 70)

    local List = Instance.new("ScrollingFrame", Box)
    List.Size = UDim2.new(1, -12, 1, -40)
    List.Position = UDim2.new(0, 6, 0, 34)
    List.BackgroundTransparency = 1
    List.BorderSizePixel = 0
    List.ScrollBarThickness = 4
    List.CanvasSize = UDim2.new(0, 0, 0, 0)
    List.AutomaticCanvasSize = Enum.AutomaticSize.Y
    List.ClipsDescendants = true

    local ListLayout = Instance.new("UIListLayout", List)
    ListLayout.Padding = UDim.new(0, 2)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local Rows = {}
    local rowOrder = 0

    local function AddRow(entry)
        local nearBottom = List.CanvasPosition.Y + List.AbsoluteWindowSize.Y >= List.AbsoluteCanvasSize.Y - 24
        rowOrder = rowOrder + 1

        local row = Instance.new("TextLabel", List)
        row.Size = UDim2.new(1, -6, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundTransparency = 1
        row.LayoutOrder = rowOrder
        row.Font = Enum.Font.Code
        row.TextSize = 11
        row.TextWrapped = true
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextYAlignment = Enum.TextYAlignment.Top
        row.TextColor3 = LOG_COLORS[entry.level] or LOG_COLORS.info
        row.Text = string.format("[%s] %s", entry.time, entry.text)

        table.insert(Rows, row)
        if #Rows > MAX_LOG_LINES then
            table.remove(Rows, 1):Destroy()
        end

        if nearBottom then -- only follow the tail if you were already at the bottom
            task.delay(0.03, function()
                List.CanvasPosition = Vector2.new(0, math.max(0, List.AbsoluteCanvasSize.Y - List.AbsoluteWindowSize.Y))
            end)
        end
    end

    ClearBtn.MouseButton1Click:Connect(function()
        for _, r in ipairs(Rows) do r:Destroy() end
        table.clear(Rows)
        table.clear(LogEntries)
    end)

    CopyBtn.MouseButton1Click:Connect(function()
        local lines = {}
        for _, e in ipairs(LogEntries) do
            lines[#lines + 1] = string.format("[%s][%s] %s", e.time, e.level, e.text)
        end
        local clip = setclipboard or toclipboard
        if clip then
            clip(table.concat(lines, "\n"))
            Log("ok", "Copied " .. #lines .. " log lines to the clipboard")
        else
            Log("warn", "This executor has no clipboard function")
        end
    end)

    local function RefreshSpyButton()
        SpyBtn.Text = LogGameRemotes and "Spy: ON" or "Spy: OFF"
        SpyBtn.BackgroundColor3 = LogGameRemotes and Color3.fromRGB(60, 110, 170) or Color3.fromRGB(55, 55, 60)
    end
    RefreshSpyButton()

    SpyBtn.MouseButton1Click:Connect(function()
        LogGameRemotes = not LogGameRemotes
        RefreshSpyButton()
    end)

    for _, entry in ipairs(LogEntries) do AddRow(entry) end
    LogSink = AddRow
    print("[TDR] Log tab built.")
end
