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

-- ── Logger: prints to the executor console ──────────────────────────────
local LogGameRemotes = false     -- set true to also print every remote the game/player fires

local function Log(level, text)
    print(string.format("[TDR][%s] %s", level, text))
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

-- ── Little notification in the middle of the screen (one at a time) ─────────
local NotifyGui = nil
local NotifyToken = 0

local function Notify(title, text, seconds)
    if not NotifyGui or not NotifyGui.Parent then
        NotifyGui = Instance.new("ScreenGui")
        NotifyGui.Name = "TDRNotify"
        NotifyGui.ResetOnSpawn = false
        NotifyGui.DisplayOrder = 998
        local ok = pcall(function() NotifyGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not ok or not NotifyGui.Parent then NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    end

    NotifyToken = NotifyToken + 1
    local token = NotifyToken
    for _, child in ipairs(NotifyGui:GetChildren()) do child:Destroy() end

    -- no background: just outlined text, bottom centre, 50px up
    local frame = Instance.new("Frame", NotifyGui)
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -50)
    frame.Size = UDim2.new(0, 200, 0, 34)
    frame.BackgroundTransparency = 1

    local top = Instance.new("TextLabel", frame)
    top.Size = UDim2.new(1, 0, 0, 12)
    top.BackgroundTransparency = 1
    top.Text = title
    top.TextColor3 = Color3.fromRGB(190, 190, 198)
    top.TextSize = 10
    top.Font = Enum.Font.GothamMedium
    top.TextStrokeColor3 = Color3.new(0, 0, 0)
    top.TextTransparency = 1
    top.TextStrokeTransparency = 1

    local main = Instance.new("TextLabel", frame)
    main.Size = UDim2.new(1, -8, 0, 20)
    main.Position = UDim2.new(0, 4, 0, 13)
    main.BackgroundTransparency = 1
    main.Text = text
    main.TextColor3 = Color3.fromRGB(240, 240, 245)
    main.Font = Enum.Font.GothamBold
    main.TextScaled = true
    main.TextStrokeColor3 = Color3.new(0, 0, 0)
    main.TextTransparency = 1
    main.TextStrokeTransparency = 1
    local cap = Instance.new("UITextSizeConstraint", main)
    cap.MaxTextSize = 15

    local function fade(visible, duration)
        local info = TweenInfo.new(duration)
        for _, label in ipairs({top, main}) do
            TweenService:Create(label, info, {
                TextTransparency = visible and 0 or 1,
                TextStrokeTransparency = visible and 0.35 or 1,
            }):Play()
        end
    end

    fade(true, 0.15)
    task.delay(seconds or 2.5, function()
        if token ~= NotifyToken or not frame.Parent then return end
        fade(false, 0.4)
        task.wait(0.45)
        if frame.Parent then frame:Destroy() end
    end)
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
            Log("er the 1--[[
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

-- ── Logger: prints to the executor console ──────────────────────────────
local LogGameRemotes = false     -- set true to also print every remote the game/player fires

local function Log(level, text)
    print(string.format("[TDR][%s] %s", level, text))
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

-- ── Little notification in the middle of the screen (one at a time) ─────────
local NotifyGui = nil
local NotifyToken = 0

local function Notify(title, text, seconds)
    if not NotifyGui or not NotifyGui.Parent then
        NotifyGui = Instance.new("ScreenGui")
        NotifyGui.Name = "TDRNotify"
        NotifyGui.ResetOnSpawn = false
        NotifyGui.DisplayOrder = 998
        local ok = pcall(function() NotifyGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not ok or not NotifyGui.Parent then NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    end

    NotifyToken = NotifyToken + 1
    local token = NotifyToken
    for _, child in ipairs(NotifyGui:GetChildren()) do child:Destroy() end

    -- no background: just outlined text, bottom centre, 50px up
    local frame = Instance.new("Frame", NotifyGui)
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -50)
    frame.Size = UDim2.new(0, 200, 0, 34)
    frame.BackgroundTransparency = 1

    local top = Instance.new("TextLabel", frame)
    top.Size = UDim2.new(1, 0, 0, 12)
    top.BackgroundTransparency = 1
    top.Text = title
    top.TextColor3 = Color3.fromRGB(190, 190, 198)
    top.TextSize = 10
    top.Font = Enum.Font.GothamMedium
    top.TextStrokeColor3 = Color3.new(0, 0, 0)
    top.TextTransparency = 1
    top.TextStrokeTransparency = 1

    local main = Instance.new("TextLabel", frame)
    main.Size = UDim2.new(1, -8, 0, 20)
    main.Position = UDim2.new(0, 4, 0, 13)
    main.BackgroundTransparency = 1
    main.Text = text
    main.TextColor3 = Color3.fromRGB(240, 240, 245)
    main.Font = Enum.Font.GothamBold
    main.TextScaled = true
    main.TextStrokeColor3 = Color3.new(0, 0, 0)
    main.TextTransparency = 1
    main.TextStrokeTransparency = 1
    local cap = Instance.new("UITextSizeConstraint", main)
    cap.MaxTextSize = 15

    local function fade(visible, duration)
        local info = TweenInfo.new(duration)
        for _, label in ipairs({top, main}) do
            TweenService:Create(label, info, {
                TextTransparency = visible and 0 or 1,
                TextStrokeTransparency = visible and 0.35 or 1,
            }):Play()
        end
    end

    fade(true, 0.15)
    task.delay(seconds or 2.5, function()
        if token ~= NotifyToken or not frame.Parent then return end
        fade(false, 0.4)
        task.wait(0.45)
        if frame.Parent then frame:Destroy() end
    end)
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
        AutoUpgrade       = false,
        AutoFish          = false,
        FishMode          = "Cast + catch",
        MacroMode         = "Timed",
        Delays            = {},
        CollectMode       = "TouchInterest",
        AutoPlayMacro     = false,
        SelectedMacroName = nil,
    }
    local COLLECT_MODES = {"TouchInterest", "Tween", "MoveTo"}
    local FISH_MODES    = {"Cast + catch", "Catch only"}
    local MACRO_MODES   = {"Timed", "Mana"} -- Timed: recorded timeline. Mana: go as soon as there's enough mana

    -- Delays the automations use, in seconds; adjustable in the Settings tab
    local DELAY_SETTINGS = {
        {key = "TeleportDwell",      label = "Tween collect: time on each drop",         default = 0.2,  min = 0.02, max = 2},
        {key = "TeleportReturn",     label = "Tween collect: pause after returning",     default = 0.25, min = 0,    max = 3},
        {key = "TweenSpeed",         label = "Tween collect: speed (studs per second)",  default = 120,  min = 20,   max = 400},
        {key = "MoveToTimeout",      label = "MoveTo collect: give up on a drop after",  default = 4,    min = 1,    max = 15},
        {key = "MoveToRevisit",      label = "MoveTo collect: skip a visited drop for",  default = 5,    min = 0,    max = 30},
        {key = "ReplayDelay",        label = "Auto-Replay: wait before replaying",       default = 3,    min = 0,    max = 15},
        {key = "ReplayDropWait",     label = "Auto-Replay: wait for drops to be collected", default = 8, min = 0,    max = 60},
        {key = "ReplayTweenTimeout", label = "Auto-Replay: tween to leftover drops for", default = 10,  min = 0,    max = 60},
        {key = "UpgradeCooldown",    label = "Auto-Upgrade: retry a failed upgrade after", default = 3,  min = 0,    max = 15},
        {key = "UpgradePoll",        label = "Auto-Upgrade: check mana every",           default = 0.2,  min = 0.05, max = 2},
        {key = "FishCatchDelay",     label = "Auto-Fish: wait before reeling in",        default = 0.15, min = 0,    max = 2},
        {key = "FishRecastDelay",    label = "Auto-Fish: wait before the next cast",     default = 1.5,  min = 0,    max = 10},
        {key = "ManaModeGap",        label = "Mana mode: minimum gap between actions",   default = 0.15, min = 0,    max = 2},
        {key = "ActionRetries",      label = "Rejected place/upgrade: retries",           default = 5,    min = 0,    max = 20},
        {key = "ActionRetryDelay",   label = "Rejected place/upgrade: wait before retry", default = 0.3,  min = 0.05, max = 3},
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
    if MatchConfig.CollectMode == "Teleport" then MatchConfig.CollectMode = "Tween" end -- renamed
    if not table.find(COLLECT_MODES, MatchConfig.CollectMode) then
        MatchConfig.CollectMode = "TouchInterest"
    end
    if not table.find(MACRO_MODES, MatchConfig.MacroMode) then
        MatchConfig.MacroMode = "Timed"
    end
    if not table.find(FISH_MODES, MatchConfig.FishMode) then
        MatchConfig.FishMode = "Cast + catch"
    end
    if type(MatchConfig.Delays) ~= "table" then MatchConfig.Delays = {} end
    for _, def in ipairs(DELAY_SETTINGS) do
        local v = MatchConfig.Delays[def.key]
        if type(v) ~= "number" then v = def.default end
        MatchConfig.Delays[def.key] = math.clamp(v, def.min, def.max)
    end

    -- Forward-declared so earlier UI closures can call later definitions
    local Macros = {}
    local SelectedMacro, SelectedRow = nil, nil
    local RemotesByLabel = {}
    local TargetRemotes = {}          -- [remote instance] = label (filled by the remote scan)
    local FishArgs = nil              -- args of the last General.Fish cast you made by hand
    local Playing = false             -- true while a macro is running (blocks overlapping runs)
    local HookInstalled = false
    local SelfCalls = 0               -- lets the remote spy skip calls this script makes itself
    local PlayMacro, RunMacro, AddMacroListEntry, SaveMacros, LoadMacros
    local StopPlayback                -- cancels the macro that is playing
    local PlayToken = 0               -- bumped to cancel a playback
    local SetAutoReplay, SetAutoPlayMacro, SetAutoUpgrade -- flip those toggles from code
    local _unused

    local MacroLabels = {}            -- [macro] = its label in the Macros list
    local MacroListeners = {}         -- called when macros are added / renamed / deleted
    local function NotifyMacros()
        for _, fn in ipairs(MacroListeners) do
            local ok, err = pcall(fn)
            if not ok then Log("error", "Macro list refresh failed: " .. tostring(err)) end
        end
    end

    -- Fires a remote using the right method for its class (never trusts a stored
    -- method name), returns pcall's (ok, result). Packs varargs HERE, not in the
    -- closure, since a nested function can't use ... directly.
    local function CallRemote(remote, ...)
        local args = table.pack(...)
        if HookInstalled and TargetRemotes[remote] then
            SelfCalls = SelfCalls + 1 -- the hook consumes this synchronously
        end
        local ok, res, extra = pcall(function()
            if remote:IsA("RemoteFunction") then
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            else
                return remote:FireServer(table.unpack(args, 1, args.n))
            end
        end)
        SelfCalls = 0 -- anything unconsumed means the call never reached the hook
        return ok, res, extra
    end

    -- ── Mana: PlayerGui.Main.Mana.Value (NumberValue) ─────────────────────
    local function GetManaValue()
        local gui  = LocalPlayer:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("Main")
        local mana = main and main:FindFirstChild("Mana")
        return mana and mana:FindFirstChild("Value")
    end

    -- Blocks until mana >= cost (60s cap). Never blocks if the value isn't found.
    local function WaitForMana(cost, tag, cancelled)
        local v = GetManaValue()
        if not v then
            Log("warn", "Mana value not found (PlayerGui.Main.Mana.Value), not waiting")
            return true
        end
        if v.Value >= cost then return true end

        local t0 = tick()
        Log("info", string.format("%s waiting for mana: %.0f/%.0f", tag, v.Value, cost))
        while v.Value < cost and tick() - t0 < 60 and not (cancelled and cancelled()) do task.wait() end -- every frame
        if cancelled and cancelled() then return false end
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
            if conn.Connected then conn:Dilocal folder = GetUnitsFolder()
        if folder and id ~= nil then
            for _, u in ipairs(folder:GetChildren()) do
                if tostring(u:GetAttribute("ID")) == tostring(id) then return u end
            end
        end
        return nil
    end

    local function WaitForUnit(id, timeout)
        local deadline = tick() + (timeout or 2)
        local unit = FindUnitById(id)
        while not unit and tick() < deadline do
            task.wait(0.1)
            unit = FindUnitById(id)
        end
        return unit
    end

    local function GetPlaceCost(unitName)
        local data = GetUnitsData()
        local info = data and data[unitName]
        local step = info and info.Upgrades and info.Upgrades[0]
        return step and step.Cost
    end

    local function GetUpgradeCost(unit)
        local data = GetUnitsData()
        local info = data and data[unit.Name]
        local nextLevel = (unit:GetAttribute("Upgrade") or 0) + 1
        local step = info and info.Upgrades and info.Upgrades[nextLevel]
        return step and step.Cost
    end

    -- Helpers below must never abort a playback: run them guarded
    local function Safe(fn, ...)
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
        Log("error", "Unit helper failed: " .. tostring(a))
        return nil
    end

    -- Exact cost of this place/upgrade right now (also returns the unit for
    -- upgrades), falling back to the cost recorded with the macro.
    local function RequiredMana(action)
        if action.remote == "Battle.PlaceTower" then
            local cost = GetPlaceCost(action.args[1])
            if cost then return cost, "Units" end
        elseif action.remote == "UI.UpgradeTower" then
            local unit = WaitForUnit(action.args[1], 2) -- right after a placement it may not have replicated yet
            if unit then
                local cost = GetUpgradeCost(unit)
                if cost then return cost, "Units", unit end
            else
                Log("warn", "UpgradeTower: no unit with ID " .. tostring(action.args[1]) .. " in workspace.Battle.Units (placement failed?)")
            end
        end
        if action.mana and action.mana > 0 then return action.mana, "recorded" end
        return nil
    end

    -- Info + sequencing: after a place/upgrade call returns, wait (max 1.5s) for the
    -- change to show up so the next action sees fresh state, and log what happened.
    local function SnapshotBefore(action, unit)
        if action.remote == "Battle.PlaceTower" then
            local ids = {}
            local folder = GetUnitsFolder()
            if folder then
                for _, u in ipairs(folder:GetChildren()) do
                    ids[tostring(u:GetAttribute("ID"))] = true
                end
            end
            return {kind = "place", ids = ids}
        elseif action.remote == "UI.UpgradeTower" and unit then
            return {kind = "upgrade", unit = unit, level = unit:GetAttribute("Upgrade") or 0}
        end
        return nil
    end

    local function ConfirmAction(action, snap, tag)
        if not snap then return end
        local deadline = tick() + 1.5

        if snap.kind == "place" then
            local found = nil
            while not found and tick() < deadline do
                local folder = GetUnitsFolder()
                if folder then
                    for _, u in ipairs(folder:GetChildren()) do
                        if u.Name == action.args[1] and not snap.ids[tostring(u:GetAttribute("ID"))] then
                            found = u
                        end
                    end
                end
                if not found then task.wait(0.1) end
            end
            if found then
                Log("ok", string.format("%s confirmed: %s placed (ID %s)", tag, found.Name, tostring(found:GetAttribute("ID"))))
            else
                Log("warn", tag .. " not confirmed: no new '" .. tostring(action.args[1]) .. "' in workspace.Battle.Units")
            end

        elseif snap.kind == "upgrade" then
            while (snap.unit:GetAttribute("Upgrade") or 0) <= snap.level and snap.unit.Parent and tick() < deadline do
                task.wait(0.1)
            end
            local now = snap.unit:GetAttribute("Upgrade") or 0
            if now > snap.level then
                Log("ok", string.format("%s confirmed: %s ID %s level %d -> %d",
                    tag, snap.unit.Name, tostring(snap.unit:GetAttribute("ID")), snap.level, now))
            else
                Log("warn", string.format("%s not applied: %s ID %s still level %d",
                    tag, snap.unit.Name, tostring(snap.unit:GetAttribute("ID")), snap.level))
            end
        end
    end

    -- While recording: exact cost from the Units data when possible, otherwise
    -- measure the mana drop (WatchManaCost). Runs right after the call is captured,
    -- before the server has applied it, so levels/IDs are still the "before" state.
    -- While recording: learn which unit a placement created (its ID attribute), so the
    -- Editor can group later upgrades / targeting / sell under the right unit.
    local ClaimedUnitIds = {}

    local function TrackPlacedUnit(action)
        local before = {}
        local folder = GetUnitsFolder()
        if folder then
            for _, u in ipairs(folder:GetChildren()) do
                before[tostring(u:GetAttribute("ID"))] = true
            end
        end

        local deadline = tick() + 3
        while tick() < deadline do
            folder = GetUnitsFolder()
            if folder then
                for _, u in ipairs(folder:GetChildren()) do
                    local id = u:GetAttribute("ID")
                    if id ~= nil and u.Name == action.args[1]
                        and not before[tostring(id)] and not ClaimedUnitIds[tostring(id)] then
                        ClaimedUnitIds[tostring(id)] = true
                        action.unitId = id
                        Log("info", string.format("REC %s placed as ID %s", tostring(action.args[1]), tostring(id)))
                        return
                    end
                end
            end
            task.wait(0.1)
        end
        Log("warn", "REC could not read the new unit's ID for " .. tostring(action.args[1])
            .. " (the Editor will assume placement order)")
    end

    local function CaptureCost(action)
        if action.remote == "Battle.PlaceTower" then
            task.spawn(TrackPlacedUnit, action)
        end
        local cost = nil
        if action.remote == "Battle.PlaceTower" then
            cost = GetPlaceCost(action.args[1])
        elseif action.remote == "UI.UpgradeTower" then
            local unit = FindUnitById(action.args[1])
            if unit then cost = GetUpgradeCost(unit) end
        end

        if cost then
            action.mana = cost
            Log("info", string.format("REC %s costs %s mana (Units data)", action.remote, tostring(cost)))
        else
            WatchManaCost(action)
        end
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

    local TogglesHolder = Instance.new("ScrollingFrame", RightBox)
    TogglesHolder.Size = UDim2.new(1, -12, 1, -38)
    TogglesHolder.Position = UDim2.new(0, 6, 0, 32)
    TogglesHolder.BackgroundTransparency = 1
    TogglesHolder.BorderSizePixel = 0
    TogglesHolder.ScrollBarThickness = 3
    TogglesHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
    TogglesHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TogglesHolder.ClipsDescendants = true
    local TogglesPad = Instance.new("UIPadding", TogglesHolder)
    TogglesPad.PaddingRight = UDim.new(0, 6) -- keep rows clear of the scrollbar

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

        local function apply(newState)
            state = newState
            local knobX = state and (trackW - (trackH - 6) - 3) or 3
            TweenService:Create(knob, TWEEN_MEDIUM, {Position = UDim2.new(0, knobX, 0.5, 0)}):Play()
            TweenService:Create(track, TWEEN_MEDIUM, {
                BackgroundColor3 = state and Color3.fromRGB(100, 180, 255) or Color3.fromRGB(55, 55, 60)
            }):Play()
            if callback then callback(state) end
        end

        hit.MouseButton1Click:Connect(function() apply(not state) end)

        -- second return: lets other buttons (Stop all, the quick-stop pop-up) flip this
        -- toggle exactly like a tap would, including saving and stopping its loop
        return row, function(value)
            if value ~= state then apply(value) end
        end
    end

    -- ── Auto-Collect Items: touch every part under workspace.Drops that
    -- actually has a TouchTransmitter (meaning something listens for touch) ─
    -- Three ways to pick them up (MatchConfig.CollectMode, switchable live):
    --   TouchInterest  firetouchinterest from your root part, no movement
    --   Teleport       hop onto each drop, then back to where you were
    --   MoveTo         walk to the nearest drop (skips ones just visited / unreachable)
    local AutoCollectRunning = false

    local function GetCollectTargets()
        local targets = {}
        local folder = Workspace:FindFirstChild("Drops")
        if folder then
            for _, part in ipairs(folder:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") then
                    targets[#targets + 1] = part
                end
            end
        end
        return targets
    end

    local function StartAutoCollect()
        if AutoCollectRunning then return end
        AutoCollectRunning = true
        task.spawn(function()
            local lastMode = nil
            local visited = {}          -- [part] = tick() it was last visited (MoveTo)
            local warnedTouch = false

            while MatchConfig.AutoCollectItems do
                local mode      = MatchConfig.CollectMode
                local character = LocalPlayer.Character
                local hrp       = character and character:FindFirstChild("HumanoidRootPart")
                local hum       = character and character:FindFirstChildOfClass("Humanoid")

                if mode ~= lastMode then
                    Log("info", "Auto-Collect mode: " .. mode)
                    lastMode = mode
                end

                if not hrp then
                    task.wait(0.5) -- dead / respawning

                elseif mode == "TouchInterest" then
                    if firetouchinterest then
                        for _, part in ipairs(GetCollectTargets()) do
                            firetouchinterest(hrp, part, 0)
                            firetouchinterest(hrp, part, 1)
                        end
                    elseif not warnedTouch then
                        warnedTouch = true
                        Log("error", "This executor has no firetouchinterest; use Teleport or MoveTo")
                    end
                    RunService.Heartbeat:Wait()

                elseif mode == "Teleport" then
                    local targets = GetCollectTargets()
                    if #targets == 0 then
                        task.wait(0.25)
                    else
                        local home = hrp.CFrame
                        for _, part in ipairs(targets) do
                            if not MatchConfig.AutoCollectItems or not hrp.Parent then break end
                            if part.Parent then
                                hrp.CFrame = part.CFrame
                                task.wait(MatchConfig.Delays.TeleportDwell) -- let the touch register before leaving
                            end
                        end
                        if hrp.Parent then
                            hrp.CFrame = home
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        task.wait(MatchConfig.Delays.TeleportReturn)
                    end

                elseif mode == "MoveTo" then
                    local now = tick()
                    local best, bestDist = nil, math.huge
                    for _, part in ipairs(GetCollectTargets()) do
                        local seen = visited[part]
                        if not (seen and now - seen < MatchConfig.Delays.MoveToRevisit) then
                            local d = (part.Position - hrp.Position).Magnitude
                            if d < bestDist then best, bestDist = part, d end
                        end
                    end

                    if best and hum then
                        hum:MoveTo(best.Position)
                        local t0 = tick()
                        while MatchConfig.AutoCollectItems
                            and MatchConfig.CollectMode == "MoveTo"
                            and best.Parent
                            and hrp.Parent
                            and tick() - t0 < MatchConfig.Delays.MoveToTimeout
                            and (hrp.Position - best.Position).Magnitude > 3 do
                            task.wait(0.1)
                        end
                        visited[best] = tick() -- reached, collected, or timed out: don't loop on it
                    else
                        task.wait(0.25)
                    end

                else
                    task.wait(0.5)
                end
            end

            -- stop any walk in progress
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and lastMode == "MoveTo" then hum:MoveTo(hrp.Position) end
            AutoCollectRunning = false
        end)
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
        return ok, res
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
                        local delay = MatchConfig.Delays.ReplayDelay
                        Log("info", string.format("Auto-Replay: Rewards visible, replaying in %gs", delay))
                        task.wait(delay)
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

    -- ── Auto-Upgrade: keep spending mana on upgrades, one unit at a time ─────────
    -- Picks the lowest-level unit first (ties: cheapest next upgrade, then lowest ID),
    -- waits until its next upgrade is affordable, fires UI.UpgradeTower with the unit's
    -- ID, and confirms the level went up. Costs come from the Units data; units with no
    -- next upgrade are maxed and skipped. Pauses while a macro plays or Rewards is up.
    local AutoUpgradeRunning = false

    local function PickUpgradeTarget(failUntil)
        local folder = GetUnitsFolder()
        local data = GetUnitsData()
        if not (folder and data) then return nil end

        local best, bestLevel, bestCost, bestId = nil, 0, 0, 0
        for _, unit in ipairs(folder:GetChildren()) do
            local id = unit:GetAttribute("ID")
            local info = data[unit.Name]
            local ups = info and info.Upgrades
            local cooling = failUntil[unit] and tick() < failUntil[unit]
            if id ~= nil and ups and not cooling then
                local level = unit:GetAttribute("Upgrade") or 0
                local step = ups[level + 1]
                if step and step.Cost then -- no next step = maxed
                    local idNum = tonumber(id) or 0
                    local better = not best
                        or level < bestLevel
                        or (level == bestLevel and (step.Cost < bestCost
                            or (step.Cost == bestCost and idNum < bestId)))
                    if better then best, bestLevel, bestCost, bestId = unit, level, step.Cost, idNum end
                end
            end
        end
        return best, bestCost, bestLevel
    end

    local function StartAutoUpgrade()
        if AutoUpgradeRunning then return end
        AutoUpgradeRunning = true
        task.spawn(function()
            local failUntil = {}   -- [unit] = tick() until which we leave it alone after a failed upgrade
            local warnedData, warnedMana, pausedLogged = false, false, false

            while MatchConfig.AutoUpgrade do
                local rewards = GetRewardsFrame()
                if Playing or (rewards and rewards.Visible) then
                    if Playing and not pausedLogged then
                        pausedLogged = true
                        Log("info", "Auto-Upgrade paused while a macro plays")
                    end
                    task.wait(0.5)
                else
                    pausedLogged = false
                    local mana = GetManaValue()
                    if not GetUnitsData() then
                        if not warnedData then
                            warnedData = true
                            Log("error", "Auto-Upgrade needs the Units data (ReplicatedStorage.Modules.Content.Units)")
                        end
                        task.wait(2)
                    elseif not mana then
                        if not warnedMana then
                            warnedMana = true
                            Log("warn", "Auto-Upgrade: mana value not found (PlayerGui.Main.Mana.Value)")
                        end
                        task.wait(1)
                    else
                        local unit, cost, level = PickUpgradeTarget(failUntil)
                        if unit and mana.Value >= cost then
                            local id = unit:GetAttribute("ID")
                            local tag = string.format("AUTO %s ID %s", unit.Name, tostring(id))
                            local snap = {kind = "upgrade", unit = unit, level = level}

                            local done = false
                            task.spawn(function()
                                FireRemoteByLabel("UI.UpgradeTower", id)
                                done = true
                            end)
                            local deadline = tick() + 5
                            while not done and tick() < deadline do task.wait(0.05) end

                            Safe(ConfirmAction, {remote = "UI.UpgradeTower", args = {id}}, snap, tag)
                            if (unit:GetAttribute("Upgrade") or 0) <= level then
                                failUntil[unit] = tick() + MatchConfig.Delays.UpgradeCooldown -- didn't apply: leave it alone briefly
                            end
                        elseif unit then
                            task.wait(MatchConfig.Delays.UpgradePoll) -- saving up for it
                        else
                            task.wait(0.5) -- nothing upgradable right now
                        end
                    end
                end
            end
            AutoUpgradeRunning = false
        end)
    end

    -- ── Auto-Fish (built from the fishing probe log) ────────────────────────────
    --   cast   General.Fish:InvokeServer(<point on workspace.Map.Lake.Cover>, Color3(0, 0.0667, 1))
    --          It YIELDS until a fish is on the line, then returns (fishName, {Rod, Bait, ...}).
    --          If you cast by hand once, those exact args are remembered and reused.
    --   catch  General.CatchFish:InvokeServer(), then a notification shows the fish name.
    -- "Cast + catch" runs the whole loop. "Catch only": you cast by hand, and when the
    -- game's own Fish call returns (a fish is on the line) this reels it in for you.
    local FISH_COLOR = Color3.new(0, 0.0666667, 1)
    local AutoFishRunning = false
    local Reeling = false

    -- A point on the lake surface near you, a few studs in from the shore
    local function PickCastPoint()
        local map = Workspace:FindFirstChild("Map")
        local lake = map and map:FindFirstChild("Lake")
        local cover = lake and lake:FindFirstChild("Cover")
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (cover and hrp) then return nil end

        local localPos = cover.CFrame:PointToObjectSpace(hrp.Position)
        local hx, hz = cover.Size.X / 2 - 3, cover.Size.Z / 2 - 3
        local x = math.clamp(localPos.X, -hx, hx)
        local z = math.clamp(localPos.Z, -hz, hz)
        local inward = Vector3.new(-x, 0, -z) -- toward the middle of the lake
        if inward.Magnitude > 0.1 then
            local step = inward.Unit * math.min(5, inward.Magnitude)
            x, z = x + step.X, z + step.Z
        end
        return cover.CFrame:PointToWorldSpace(Vector3.new(x, cover.Size.Y / 2, z))
    end

    -- A fish is on the line: reel it in and show what it was
    local function ReelIn(fishName)
        if Reeling then return end
        Reeling = true
        task.wait(MatchConfig.Delays.FishCatchDelay)
        local ok, res = FireRemoteByLabel("General.CatchFish")
        local name = tostring(fishName)
        if ok and res ~= false then
            Log("ok", "Auto-Fish: caught " .. name)
            Notify("Caught", name, 3)
        else
            Log("warn", "Auto-Fish: CatchFish failed for " .. name .. " (" .. tostring(res) .. ")")
            Notify("Got away", name, 3)
        end
        Reeling = false
    end

    local function StartAutoFish()
        if AutoFishRunning then return end
        AutoFishRunning = true
        task.spawn(function()
            local fails = 0
            local warnedHook = false

            while MatchConfig.AutoFish do
                if MatchConfig.FishMode == "Catch only" then
                    if not HookInstalled and not warnedHook then
                        warnedHook = true
                        Log("warn", "Auto-Fish (Catch only) needs the remote hook, which isn't installed")
                    end
                    task.wait(0.5) -- the remote hook reels in when your own cast returns

                else
                    local remote = RemotesByLabel["General.Fish"]
                    local args = FishArgs
                    if not args then
                        local point = PickCastPoint()
                        if point then args = table.pack(point, FISH_COLOR) end
                    end

                    if not remote then
                        Log("error", "Auto-Fish: remote General.Fish not found")
                        task.wait(3)
                    elseif not args then
                        Log("error", "Auto-Fish: workspace.Map.Lake.Cover or your character wasn't found")
                        task.wait(3)
                    else
                        Log("send", ">> General.Fish(" .. DescribeArgs(args, args.n) .. ")  [waits until a fish is on the line]")
                        local t0 = tick()
                        local ok, name = CallRemote(remote, table.unpack(args, 1, args.n))
                        if not MatchConfig.AutoFish then break end -- turned off while waiting

                        if ok and type(name) == "string" then
                            fails = 0
                            Log("ok", string.format("<< General.Fish: %s on the line after %.1fs", name, tick() - t0))
                            ReelIn(name)
                            task.wait(MatchConfig.Delays.FishRecastDelay) -- let the rod reset before the next cast
                        else
                            fails = fails + 1
                            Log("warn", string.format("<< General.Fish gave no fish (%s), %d in a row",
                                ok and Describe(name) or tostring(name), fails))
                            task.wait(math.min(2 + fails, 10))
                        end
                    end
                end
            end
            AutoFishRunning = false
        end)
    end

    _unused, SetAutoReplay = MakeCustomToggle(TogglesHolder, "Auto-Replay", MatchConfig.AutoReplay, function(state)
        MatchConfig.AutoReplay = state
        SaveMatchConfig()
        Log("info", "Auto-Replay " .. (state and "ON" or "OFF"))
        if state then StartAutoReplay() end
    end)

    _unused, SetAutoPlayMacro = MakeCustomToggle(TogglesHolder, "Auto-Play Macro", MatchConfig.AutoPlayMacro, function(state)
        MatchConfig.AutoPlayMacro = state
        SaveMatchConfig()
        Log("info", "Auto-Play Macro " .. (state and "ON" or "OFF"))
        if state then StartAutoPlayMacro() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Collect Items", MatchConfig.AutoCollectItems, function(state)
        MatchConfig.AutoCollectItems = state
        SaveMatchConfig()
        Log("info", "Auto-Collect Items " .. (state and "ON" or "OFF"))
        if state then StartAutoCollect() end -- turning it off ends the loop on its own
    end)

    -- Mode selector sits right under the Auto-Collect toggle: click to cycle
    local function MakeModeRow(parent, labelText, options, initial, callback)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
        row.BackgroundTransparency = 0.3
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(0, 38, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(230, 230, 230)
        label.TextScaled = true
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(1, -60, 0, 22)
        btn.Position = UDim2.new(0, 52, 0.5, -11)
        btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        btn.TextColor3 = Color3.fromRGB(235, 235, 235)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local index = table.find(options, initial) or 1
        btn.Text = options[index]
        btn.MouseButton1Click:Connect(function()
            index = index % #options + 1
            btn.Text = options[index]
            if callback then callback(options[index]) end
        end)
        return row
    end

    MakeModeRow(TogglesHolder, "Mode", COLLECT_MODES, MatchConfig.CollectMode, function(mode)
        MatchConfig.CollectMode = mode
        SaveMatchConfig()
    end)

    _unused, SetAutoUpgrade = MakeCustomToggle(TogglesHolder, "Auto-Upgrade", MatchConfig.AutoUpgrade, function(state)
        MatchConfig.AutoUpgrade = state
        SaveMatchConfig()
        Log("info", "Auto-Upgrade " .. (state and "ON" or "OFF"))
        if state then StartAutoUpgrade() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Fish", MatchConfig.AutoFish, function(state)
        MatchConfig.AutoFish = state
        SaveMatchConfig()
        Log("info", "Auto-Fish " .. (state and "ON" or "OFF"))
        if state then StartAutoFish() end
    end)

    MakeModeRow(TogglesHolder, "Fish", FISH_MODES, MatchConfig.FishMode, function(mode)
        MatchConfig.FishMode = mode
        SaveMatchConfig()
        Log("info", "Fish mode: " .. mode)
    end)

    -- Stops every macro-style automation: Auto-Replay, Auto-Play Macro (and the macro
    -- that's playing right now) and Auto-Upgrade. Collect and Fish are left alone.
    local function StopAllMacros()
        if SetAutoReplay then SetAutoReplay(false) end
        if SetAutoPlayMacro then SetAutoPlayMacro(false) end
        if SetAutoUpgrade then SetAutoUpgrade(false) end
        StopPlayback()
        Log("info", "Stopped Auto-Replay, Auto-Play Macro and Auto-Upgrade")
    end

    local StopAllBtn = Instance.new("TextButton", RightBox)
    StopAllBtn.Size = UDim2.new(0, 62, 0, 20)
    StopAllBtn.AnchorPoint = Vector2.new(1, 0)
    StopAllBtn.Position = UDim2.new(1, -8, 0, 7)
    StopAllBtn.BackgroundColor3 = Color3.fromRGB(170, 55, 55)
    StopAllBtn.Text = "Stop all"
    StopAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopAllBtn.TextSize = 11
    StopAllBtn.Font = Enum.Font.GothamBold
    StopAllBtn.AutoButtonColor = false
    Instance.new("UICorner", StopAllBtn).CornerRadius = UDim.new(0, 6)
    StopAllBtn.Activated:Connect(StopAllMacros)

    -- Small pop-up at the middle of the right edge. It only shows while something it can
    -- stop is running, so it stays out of the way (drag it if it's in the way).
    local PopupGui = Instance.new("ScreenGui")
    PopupGui.Name = "TDRQuickStop"
    PopupGui.ResetOnSpawn = false
    PopupGui.DisplayOrder = 997
    local okPopup = pcall(function() PopupGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not okPopup or not PopupGui.Parent then PopupGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Popup = Instance.new("Frame", PopupGui)
    Popup.AnchorPoint = Vector2.new(1, 0.5)
    Popup.Position = UDim2.new(1, -8, 0.5, 0)
    Popup.Size = UDim2.new(0, 136, 0, 0)
    Popup.AutomaticSize = Enum.AutomaticSize.Y
    Popup.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    Popup.BackgroundTransparency = 0.2
    Popup.Visible = false
    Popup.Active = true
    Popup.Draggable = true
    Instance.new("UICorner", Popup).CornerRadius = UDim.new(0, 8)
    AddPadding(Popup, 5)
    local PopupLayout = Instance.new("UIListLayout", Popup)
    PopupLayout.Padding = UDim.new(0, 4)
    PopupLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function MakePopupRow(order, onStop)
        local row = Instance.new("Frame", Popup)
        row.Size = UDim2.new(1, 0, 0, 26)
        row.LayoutOrder = order
        row.BackgroundTransparency = 1
        row.Visible = false

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(1, -48, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(230, 230, 230)
        label.TextSize = 11
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 44, 0, 22)
        btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = UDim2.new(1, 0, 0.5, 0)
        btn.BackgroundColor3 = Color3.fromRGB(170, 55, 55)
        btn.Text = "Stop"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.Activated:Connect(onStop)
        return row, label
    end

    local ReplayRow, ReplayLabel = MakePopupRow(1, function()
        if SetAutoReplay then SetAutoReplay(false) end
    end)
    local MacroRow, MacroLabel = MakePopupRow(2, function()
        if SetAutoPlayMacro then SetAutoPlayMacro(false) end
        StopPlayback()
    end)
    local UpgradeRow, UpgradeLabel = MakePopupRow(3, function()
        if SetAutoUpgrade then SetAutoUpgrade(false) end
    end)
    ReplayLabel.Text = "Auto-Replay"
    UpgradeLabel.Text = "Auto-Upgrade"

    task.spawn(function()
        while PopupGui.Parent do
            local replay  = MatchConfig.AutoReplay
            local macro   = MatchConfig.AutoPlayMacro or Playing
            local upgrade = MatchConfig.AutoUpgrade
            ReplayRow.Visible = replay
            MacroRow.Visible = macro
            UpgradeRow.Visible = upgrade
            MacroLabel.Text = Playing and "Macro (playing)" or "Auto-Play Macro"
            Popup.Visible = replay or macro or upgrade
            task.wait(0.25)
        end
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
                actions[j] = {t = action.t, remote = action.remote, method = action.method, mana = action.mana, unitId = action.unitId, args = args}
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
                actions[j] = {t = action.t, remote = action.remote, method = action.method, mana = action.mana, unitId = action.unitId, args = args}
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
        MacroLabels[macro] = label

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
            MacroLabels[macro] = nil
            row:Destroy()
            SaveMacros()
            NotifyMacros()
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
                        NotifyMacros()
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
    -- error / missing remote is printed to the console. Only one macro runs at a time.
    RunMacro = function(macro)
        if Playing then
            Log("warn", "Already playing a macro, ignoring '" .. macro.Name .. "'")
            return false
        end
        Playing = true
        PlayToken = PlayToken + 1
        local token = PlayToken

        local total = #macro.Actions
        local okCount, failCount, missing, pending = 0, 0, 0, 0

        local ran, err = pcall(function()
            Log("info", string.format("PLAY '%s' (%d actions)", macro.Name, total))

            -- costs come from the game's Units data; the recorded cost is only a fallback
            if not GetUnitsData() then
                local unknownCost = 0
                for _, a in ipairs(macro.Actions) do
                    if (a.remote == "Battle.PlaceTower" or a.remote == "UI.UpgradeTower") and not a.mana then
                        unknownCost = unknownCost + 1
                    end
                end
                if unknownCost > 0 then
                    Log("warn", unknownCost .. " place/upgrade action(s) have no cost to wait for (no Units data, nothing recorded)")
                end
            end

            local startedAt = tick()
            local lag = 0 -- how far the timeline has slipped (mana waits, slow answers)
            for i, action in ipairs(macro.Actions) do
                local target = action.t + lag
                local remaining = target - (tick() - startedAt)
                while remaining > 0 and token == PlayToken do
                    task.wait(math.min(remaining, 0.2))
                    remaining = target - (tick() - startedAt)
                end
                if token ~= PlayToken then
                    Log("info", "Playback stopped")
                    break
                end

                local remote = RemotesByLabel[action.remote]
                local tag = string.format("#%d/%d %s", i, total, action.remote)
                if not remote then
                    missing = missing + 1
                    Log("error", tag .. " - remote not found, skipped")
                else
                    local need, source, unit = Safe(RequiredMana, action)
                    if need and need > 0 then
                        WaitForMana(need, tag .. " [" .. source .. "]", function() return token ~= PlayToken end)
                    end
                    if token ~= PlayToken then
                        Log("info", "Playback stopped")
                        break
                    end
                    local snap = Safe(SnapshotBefore, action, unit)

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
                    Safe(ConfirmAction, action, snap, tag)
                end

                local late = (tick() - startedAt) - target
                if late > 0.25 then lag = lag + late end
            end

            -- let in-flight calls report back before summarizing
            local deadline = tick() + 10
            while pending > 0 and tick() < deadline and token == PlayToken do task.wait(0.1) end
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

    StopPlayback = function()
        if Playing then
            PlayToken = PlayToken + 1
            Log("info", "Stopping the playing macro")
        end
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
            for k in pairs(ClaimedUnitIds) do ClaimedUnitIds[k] = nil end
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
                NotifyMacros()
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
        task.defer(CaptureCost, action) -- exact cost from Units data, else measures the mana drop
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
        local label = TargetRemotes[self]
        if label == "General.Fish" and SelfCalls == 0 then
            FishArgs = table.pack(...) -- learn exactly how the game casts; Auto-Fish reuses it
        end
        if SelfCalls == 0 and not Recording and not LogGameRemotes then return end

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
                local own = SelfCalls > 0 -- a call this script is making (HandleRemoteCall consumes the flag)
                local ok, err = pcall(HandleRemoteCall, self, method, ...)
                if not ok then task.defer(Log, "error", "Remote hook error: " .. tostring(err)) end
                if setnamecallmethod then setnamecallmethod(method) end -- nested namecalls can overwrite it

                -- Catch only: the game's own Fish call returning means a fish is on the line
                if method == "InvokeServer" and not own and TargetRemotes[self] == "General.Fish" then
                    local result = table.pack(OldNamecall(self, ...))
                    if MatchConfig.AutoFish and MatchConfig.FishMode == "Catch only"
                        and type(result[1]) == "string" then
                        task.defer(function()
                            Log("ok", "Auto-Fish: fish on the line: " .. result[1])
                            ReelIn(result[1])
                        end)
                    end
                    return table.unpack(result, 1, result.n)
                end
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

    -- ═══ Macro Editor tab ═══════════════════════════════════════════════
    -- Left: pick a macro. Right: its actions in order, each with an editable
    -- time and mana cost, a test-fire button and delete. Every edit saves.
    do
        local ETab  = Lib:AddTab("Editor", "full")
        local ERoot = ETab.Content
        AddPadding(ERoot, 4)

        local EditingMacro = nil
        local RebuildActions

        local function MakeLabel(parent, text, size, pos)
            local l = Instance.new("TextLabel", parent)
            l.Size = size
            l.Position = pos
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextColor3 = Color3.fromRGB(230, 230, 230)
            l.TextSize = 13
            l.Font = Enum.Font.GothamBold
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextTruncate = Enum.TextTruncate.AtEnd
            return l
        end

        local function MakeButton(parent, text, size, pos, color)
            local b = Instance.new("TextButton", parent)
            b.Size = size
            b.Position = pos
            b.BackgroundColor3 = color or Color3.fromRGB(55, 55, 60)
            b.Text = text
            b.TextColor3 = Color3.fromRGB(235, 235, 235)
            b.TextSize = 10
            b.Font = Enum.Font.GothamBold
            b.AutoButtonColor = false
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            return b
        end

        local function MakeInput(parent, placeholder, size, pos)
            local t = Instance.new("TextBox", parent)
            t.Size = size
            t.Position = pos
            t.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
            t.BackgroundTransparency = 0.2
            t.PlaceholderText = placeholder
            t.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
            t.Text = ""
            t.TextColor3 = Color3.fromRGB(220, 220, 225)
            t.TextSize = 11
            t.Font = Enum.Font.Gotham
            t.ClearTextOnFocus = false
            Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)
            return t
        end

        -- Left box: macro picker
        local PickBox = Instance.new("Frame", ERoot)
        PickBox.Size = UDim2.new(0.3, -6, 1, 0)
        PickBox.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
        PickBox.BackgroundTransparency = 0.3
        Instance.new("UICorner", PickBox).CornerRadius = UDim.new(0, 10)
        MakeLabel(PickBox, "Macros", UDim2.new(1, -12, 0, 22), UDim2.new(0, 8, 0, 6))

        local PickList = Instance.new("ScrollingFrame", PickBox)
        PickList.Size = UDim2.new(1, -12, 1, -38)
        PickList.Position = UDim2.new(0, 6, 0, 32)
        PickList.BackgroundTransparency = 1
        PickList.BorderSizePixel = 0
        PickList.ScrollBarThickness = 4
        PickList.CanvasSize = UDim2.new(0, 0, 0, 0)
        PickList.AutomaticCanvasSize = Enum.AutomaticSize.Y
        PickList.ClipsDescendants = true
        local PickLayout = Instance.new("UIListLayout", PickList)
        PickLayout.Padding = UDim.new(0, 4)
        PickLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Right box: the open macro's actions
        local EditBox = Instance.new("Frame", ERoot)
        EditBox.Size = UDim2.new(0.7, -6, 1, 0)
        EditBox.Position = UDim2.new(0.3, 6, 0, 0)
        EditBox.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
        EditBox.BackgroundTransparency = 0.3
        Instance.new("UICorner", EditBox).CornerRadius = UDim.new(0, 10)

        local EditTitle = MakeLabel(EditBox, "Select a macro to edit", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 6))
        local ShiftBox  = MakeInput(EditBox, "shift (s)", UDim2.new(0, 60, 0, 24), UDim2.new(0, 6, 0, 32))
        local ShiftBtn  = MakeButton(EditBox, "Shift all", UDim2.new(0, 70, 0, 24), UDim2.new(0, 72, 0, 32))
        local DupBtn    = MakeButton(EditBox, "Duplicate", UDim2.new(0, 76, 0, 24), UDim2.new(0, 148, 0, 32))
        local ExpandBtn   = MakeButton(EditBox, "Expand all", UDim2.new(0, 76, 0, 24), UDim2.new(0, 6, 0, 60))
        local CollapseBtn = MakeButton(EditBox, "Collapse all", UDim2.new(0, 82, 0, 24), UDim2.new(0, 88, 0, 60))

        local ActionList = Instance.new("ScrollingFrame", EditBox)
        ActionList.Size = UDim2.new(1, -12, 1, -96)
        ActionList.Position = UDim2.new(0, 6, 0, 90)
        ActionList.BackgroundTransparency = 1
        ActionList.BorderSizePixel = 0
        ActionList.ScrollBarThickness = 4
        ActionList.CanvasSize = UDim2.new(0, 0, 0, 0)
        ActionList.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ActionList.ClipsDescendants = true
        local ActionLayout = Instance.new("UIListLayout", ActionList)
        ActionLayout.Padding = UDim.new(0, 4)
        ActionLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- helpers
        local function UpdateTitle()
            if EditingMacro then
                local last = EditingMacro.Actions[#EditingMacro.Actions]
                EditTitle.Text = string.format("%s  (%d actions, %.1fs)",
                    EditingMacro.Name, #EditingMacro.Actions, last and last.t or 0)
            else
                EditTitle.Text = "Select a macro to edit"
            end
        end

        local function SyncMainLabel()
            local lbl = EditingMacro and MacroLabels[EditingMacro]
            if lbl then
                lbl.Text = string.format("%s  (%d)", EditingMacro.Name, #EditingMacro.Actions)
            end
        end

        local function SortActions(macro) -- stable: equal times keep their order
            for i, a in ipairs(macro.Actions) do a._order = i end
            table.sort(macro.Actions, function(x, y)
                if x.t ~= y.t then return x.t < y.t end
                return x._order < y._order
            end)
            for _, a in ipairs(macro.Actions) do a._order = nil end
        end

        local function UniqueName(base)
            local name, n = base, 1
            local function taken(nm)
                for _, m in ipairs(Macros) do
                    if m.Name == nm then return true end
                end
                return false
            end
            while taken(name) do
                n = n + 1
                name = base .. " " .. n
            end
            return name
        end

        local function CloneMacro(macro)
            local copy = {Name = UniqueName(macro.Name .. " copy"), Actions = {}}
            for i, a in ipairs(macro.Actions) do
                local args = {}
                for k, v in ipairs(a.args) do args[k] = v end
                copy.Actions[i] = {t = a.t, remote = a.remote, method = a.method, mana = a.mana, unitId = a.unitId, args = args}
            end
            return copy
        end

        -- Which unit groups are open (kept across rebuilds). Keys: a PlaceTower action
        -- table, or the strings "other" / "orphan:<id>".
        local Expanded = {}

        -- A unit = its PlaceTower plus every action whose first argument is that unit's
        -- ID (upgrade / targeting / sell). Macros recorded before unit IDs were saved
        -- assume IDs count up from 0 in placement order (marked with a "?").
        local function GroupActions(macro)
            local groups, byId, orphans, other = {}, {}, {}, nil
            local placeCount = 0

            for i, a in ipairs(macro.Actions) do
                if a.remote == "Battle.PlaceTower" then
                    placeCount = placeCount + 1
                    local id, guessed = a.unitId, false
                    if id == nil then id, guessed = placeCount - 1, true end -- IDs start at 0
                    local g = {key = a, unit = tostring(a.args[1]), id = id, guessed = guessed,
                        items = {{i = i, action = a}}}
                    groups[#groups + 1] = g
                    if not byId[tostring(id)] then byId[tostring(id)] = g end
                end
            end

            for i, a in ipairs(macro.Actions) do
                if a.remote ~= "Battle.PlaceTower" then
                    local id = a.args[1]
                    local isUnitAction = string.find(a.remote, "Tower", 1, true)
                        and (type(id) == "number" or tonumber(id) ~= nil)
                    local g
                    if isUnitAction then
                        g = byId[tostring(id)]
                        if not g then
                            local key = "orphan:" .. tostring(id)
                            g = orphans[key]
                            if not g then
                                g = {key = key, name = "Unit ID " .. tostring(id) .. " (no placement)", id = id, items = {}}
                                orphans[key] = g
                                groups[#groups + 1] = g
                            end
                        end
                    else
                        if not other then other = {key = "other", name = "Other actions", items = {}} end
                        g = other
                    end
                    g.items[#g.items + 1] = {i = i, action = a}
                end
            end

            if other then groups[#groups + 1] = other end
            for _, g in ipairs(groups) do
                table.sort(g.items, function(x, y) return x.i < y.i end)
            end
            return groups
        end

        -- Two-line label for one action: what it is (with its cost from the Units
        -- data) and its arguments
        local function DescribeItem(g, action, upgradeOrdinal)
            local data = GetUnitsData()
            local info = data and g.unit and data[g.unit]
            local ups = info and info.Upgrades

            if action.remote == "Battle.PlaceTower" then
                local step = ups and ups[0]
                return "Place" .. ((step and step.Cost) and ("  (cost " .. step.Cost .. ")") or ""),
                    DescribeArgs(action.args)
            elseif action.remote == "UI.UpgradeTower" then
                local step = ups and ups[upgradeOrdinal]
                return "Upgrade " .. upgradeOrdinal .. ((step and step.Cost) and ("  (cost " .. step.Cost .. ")") or ""),
                    "ID " .. tostring(action.args[1])
            elseif action.remote == "General.SellTower" then
                return "Sell", "ID " .. DescribeArgs(action.args)
            elseif action.remote == "Battle.TowerTargeting" then
                return "Change target", "ID " .. DescribeArgs(action.args)
            end
            return action.remote, DescribeArgs(action.args)
        end

        local function BuildRow(macro, i, action, parent, order, line1, line2)
            local row = Instance.new("Frame", parent)
            row.Size = UDim2.new(1, -14, 0, 40)
            row.LayoutOrder = order
            row.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
            row.BackgroundTransparency = 0.3
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local timeBox = MakeInput(row, "sec", UDim2.new(0, 52, 0, 22), UDim2.new(0, 6, 0.5, -11))
            timeBox.Text = string.format("%.2f", action.t)
            timeBox.FocusLost:Connect(function()
                local n = tonumber(timeBox.Text)
                if n and n >= 0 then
                    action.t = n
                    SortActions(macro)
                    SaveMacros()
                    RebuildActions()
                else
                    timeBox.Text = string.format("%.2f", action.t)
                end
            end)

            local info = Instance.new("TextLabel", row)
            info.Size = UDim2.new(1, -184, 1, 0)
            info.Position = UDim2.new(0, 64, 0, 0)
            info.BackgroundTransparency = 1
            info.Font = Enum.Font.Gotham
            info.TextSize = 11
            info.TextColor3 = Color3.fromRGB(210, 210, 215)
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.TextWrapped = true
            info.TextTruncate = Enum.TextTruncate.AtEnd
            info.Text = line1 .. "\n" .. line2

            local manaBox = MakeInput(row, "mana", UDim2.new(0, 44, 0, 22), UDim2.new(1, -114, 0.5, -11))
            manaBox.Text = action.mana and tostring(action.mana) or ""
            manaBox.FocusLost:Connect(function()
                local txt = manaBox.Text
                local n = tonumber(txt)
                if txt == "" then
                    action.mana = nil
                    SaveMacros()
                elseif n and n >= 0 then
                    action.mana = n > 0 and math.ceil(n) or nil
                    manaBox.Text = action.mana and tostring(action.mana) or ""
                    SaveMacros()
                else
                    manaBox.Text = action.mana and tostring(action.mana) or ""
                end
            end)

            local testBtn = MakeButton(row, "Test", UDim2.new(0, 34, 0, 22), UDim2.new(1, -66, 0.5, -11),
                Color3.fromRGB(60, 150, 90))
            testBtn.MouseButton1Click:Connect(function()
                local remote = RemotesByLabel[action.remote]
                local tag = string.format("EDIT #%d %s", i, action.remote)
                if not remote then
                    Log("error", tag .. " - remote not found")
                else
                    Log("send", string.format(">> %s(%s)", tag, DescribeArgs(action.args)))
                    task.spawn(function()
                        local ok, res = CallRemote(remote, table.unpack(action.args))
                        if ok then
                            Log("ok", "<< " .. tag .. " returned " .. Describe(res))
                        else
                            Log("error", "<< " .. tag .. " error: " .. tostring(res))
                        end
                    end)
                end
            end)

            local delBtn = MakeButton(row, "✕", UDim2.new(0, 22, 0, 22), UDim2.new(1, -28, 0.5, -11),
                Color3.fromRGB(150, 50, 50))
            delBtn.MouseButton1Click:Connect(function()
                table.remove(macro.Actions, i)
                SaveMacros()
                RebuildActions()
            end)
        end

        local UNIT_ACTIONS = {
            upgrade = {label = "UI.UpgradeTower",       title = "Upgrade"},
            sell    = {label = "General.SellTower",     title = "Sell"},
            target  = {label = "Battle.TowerTargeting", title = "Change target"},
        }

        -- Insert a new action for this unit (its ID is the argument), one second after
        -- the unit's last action. Adjust the time in the row that appears.
        local function AddUnitAction(macro, g, kind)
            local def = UNIT_ACTIONS[kind]
            local last = g.items[#g.items]
            local t = (last and last.action.t or 0) + 1

            local remote = RemotesByLabel[def.label]
            local action = {
                t = t,
                remote = def.label,
                method = (remote and remote:IsA("RemoteEvent")) and "FireServer" or "InvokeServer",
                args = {g.id},
            }

            if kind == "upgrade" and g.unit then
                local data = GetUnitsData()
                local ups = data and data[g.unit] and data[g.unit].Upgrades
                local ordinal = 1
                for _, item in ipairs(g.items) do
                    if item.action.remote == "UI.UpgradeTower" then ordinal = ordinal + 1 end
                end
                local step = ups and ups[ordinal]
                if step and step.Cost then
                    action.mana = step.Cost
                elseif ups then
                    Log("warn", g.unit .. " has no upgrade " .. ordinal .. " (already max level)")
                end
            end

            if not remote then
                Log("warn", "Editor: remote " .. def.label .. " not found right now; added anyway")
            end

            table.insert(macro.Actions, action)
            SortActions(macro)
            Expanded[g.key] = true
            SaveMacros()
            RebuildActions()
            Log("info", string.format("Editor: added %s for ID %s at %.2fs", def.title, tostring(g.id), t))
        end

        -- One collapsible group: header (click to open) + its action rows
        local function BuildGroup(macro, g, order)
            local frame = Instance.new("Frame", ActionList)
            frame.Size = UDim2.new(1, 0, 0, 0)
            frame.AutomaticSize = Enum.AutomaticSize.Y
            frame.BackgroundTransparency = 1
            frame.LayoutOrder = order
            local layout = Instance.new("UIListLayout", frame)
            layout.Padding = UDim.new(0, 3)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- rows sit indented under the header

            local open = Expanded[g.key] == true
            local upgrades, others = 0, 0
            for _, item in ipairs(g.items) do
                local r = item.action.remote
                if r == "UI.UpgradeTower" then
                    upgrades = upgrades + 1
                elseif r ~= "Battle.PlaceTower" then
                    others = others + 1
                end
            end

            local summary
            if g.unit then
                summary = string.format("%s  (ID %s%s)  @%.1fs  -  %d upgrade%s", g.unit, tostring(g.id),
                    g.guessed and "?" or "", g.key.t, upgrades, upgrades == 1 and "" or "s")
                if others > 0 then summary = summary .. string.format(", %d other", others) end
            else
                summary = string.format("%s  -  %d action%s", g.name, #g.items, #g.items == 1 and "" or "s")
            end

            local header = Instance.new("TextButton", frame)
            header.Size = UDim2.new(1, 0, 0, 30)
            header.LayoutOrder = 0
            header.BackgroundColor3 = open and Color3.fromRGB(45, 65, 90) or Color3.fromRGB(35, 35, 40)
            header.BackgroundTransparency = 0.2
            header.Font = Enum.Font.GothamMedium
            header.TextSize = 12
            header.TextColor3 = Color3.fromRGB(230, 230, 230)
            header.TextXAlignment = Enum.TextXAlignment.Left
            header.TextTruncate = Enum.TextTruncate.AtEnd
            header.AutoButtonColor = false
            header.Text = (open and "[-]  " or "[+]  ") .. summary
            Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)
            local pad = Instance.new("UIPadding", header)
            pad.PaddingLeft = UDim.new(0, 8)
            pad.PaddingRight = UDim.new(0, 34)
            header.MouseButton1Click:Connect(function()
                Expanded[g.key] = not open
                RebuildActions()
            end)

            if g.key ~= "other" then -- delete the whole unit (placement + everything under it)
                local delGroup = MakeButton(header, "✕", UDim2.new(0, 22, 0, 22), UDim2.new(1, -26, 0.5, -11),
                    Color3.fromRGB(150, 50, 50))
                delGroup.MouseButton1Click:Connect(function()
                    local indices = {}
                    for _, item in ipairs(g.items) do indices[#indices + 1] = item.i end
                    table.sort(indices, function(x, y) return x > y end) -- highest first so indices stay valid
                    for _, idx in ipairs(indices) do table.remove(macro.Actions, idx) end
                    SaveMacros()
                    RebuildActions()
                    Log("info", "Editor: removed " .. #indices .. " action(s) of " .. summary)
                end)
            end

            if open then
                local upgradeOrdinal = 0
                for idx, item in ipairs(g.items) do
                    if item.action.remote == "UI.UpgradeTower" then upgradeOrdinal = upgradeOrdinal + 1 end
                    local line1, line2 = DescribeItem(g, item.action, upgradeOrdinal)
                    BuildRow(macro, item.i, item.action, frame, idx, line1, line2)
                end

                if g.id ~= nil then -- add more actions to this unit
                    local bar = Instance.new("Frame", frame)
                    bar.Size = UDim2.new(1, -14, 0, 28)
                    bar.LayoutOrder = #g.items + 1
                    bar.BackgroundTransparency = 1
                    local kinds = {
                        {"upgrade", "+ Upgrade", Color3.fromRGB(60, 150, 90)},
                        {"sell",    "+ Sell",    Color3.fromRGB(150, 50, 50)},
                        {"target",  "+ Target",  Color3.fromRGB(60, 110, 170)},
                    }
                    for n, k in ipairs(kinds) do
                        local btn = MakeButton(bar, k[2], UDim2.new(1 / 3, -4, 1, 0),
                            UDim2.new((n - 1) / 3, 2, 0, 0), k[3])
                        btn.MouseButton1Click:Connect(function()
                            AddUnitAction(macro, g, k[1])
                        end)
                    end
                end
            end
        end

        RebuildActions = function()
            local scroll = ActionList.CanvasPosition
            for _, child in ipairs(ActionList:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end -- keep the UIListLayout
            end
            if EditingMacro then
                for order, g in ipairs(GroupActions(EditingMacro)) do
                    BuildGroup(EditingMacro, g, order)
                end
            end
            UpdateTitle()
            SyncMainLabel()
            task.delay(0.05, function() ActionList.CanvasPosition = scroll end) -- keep your place after an edit
        end

        local function SetAllExpanded(open)
            if EditingMacro then
                for _, g in ipairs(GroupActions(EditingMacro)) do Expanded[g.key] = open end
                RebuildActions()
            end
        end

        local function RefreshPicker()
            for _, child in ipairs(PickList:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local stillExists = false
            for _, macro in ipairs(Macros) do
                if macro == EditingMacro then stillExists = true end

                local btn = Instance.new("TextButton", PickList)
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = (macro == EditingMacro) and Color3.fromRGB(45, 65, 90) or Color3.fromRGB(30, 30, 34)
                btn.BackgroundTransparency = 0.3
                btn.Text = "  " .. macro.Name
                btn.TextColor3 = Color3.fromRGB(210, 210, 215)
                btn.TextSize = 12
                btn.Font = Enum.Font.Gotham
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.AutoButtonColor = false
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                btn.MouseButton1Click:Connect(function()
                    EditingMacro = macro
                    RefreshPicker()
                    RebuildActions()
                end)
            end

            if EditingMacro and not stillExists then
                EditingMacro = nil
                RebuildActions()
            else
                UpdateTitle()
            end
        end

        ShiftBtn.MouseButton1Click:Connect(function()
            local d = tonumber(ShiftBox.Text)
            if EditingMacro and d then
                for _, a in ipairs(EditingMacro.Actions) do
                    a.t = math.max(0, a.t + d)
                end
                SaveMacros()
                RebuildActions()
                Log("info", string.format("Editor: shifted '%s' by %+.2fs", EditingMacro.Name, d))
            end
        end)

        DupBtn.MouseButton1Click:Connect(function()
            if EditingMacro then
                local copy = CloneMacro(EditingMacro)
                table.insert(Macros, copy)
                AddMacroListEntry(copy)
                SaveMacros()
                EditingMacro = copy
                NotifyMacros()
                RebuildActions()
                Log("info", "Editor: duplicated as '" .. copy.Name .. "'")
            end
        end)

        ExpandBtn.MouseButton1Click:Connect(function() SetAllExpanded(true) end)
        CollapseBtn.MouseButton1Click:Connect(function() SetAllExpanded(false) end)

        table.insert(MacroListeners, RefreshPicker)
        RefreshPicker()
        Log("info", "Editor tab built")
    end

    -- ═══ Settings tab: adjust the delays the automations use ══════════════
    do
        local STab  = Lib:AddTab("Settings", "full")
        local SRoot = STab.Content
        AddPadding(SRoot, 4)

        local Box = Instance.new("Frame", SRoot)
        Box.Size = UDim2.new(1, 0, 1, 0)
        Box.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
        Box.BackgroundTransparency = 0.3
        Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 10)

        local title = Instance.new("TextLabel", Box)
        title.Size = UDim2.new(1, -100, 0, 22)
        title.Position = UDim2.new(0, 10, 0, 6)
        title.BackgroundTransparency = 1
        title.Text = "Delays (seconds)"
        title.TextColor3 = Color3.fromRGB(230, 230, 230)
        title.TextSize = 13
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left

        local resetBtn = Instance.new("TextButton", Box)
        resetBtn.Size = UDim2.new(0, 76, 0, 22)
        resetBtn.AnchorPoint = Vector2.new(1, 0)
        resetBtn.Position = UDim2.new(1, -8, 0, 6)
        resetBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        resetBtn.Text = "Reset all"
        resetBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        resetBtn.TextSize = 11
        resetBtn.Font = Enum.Font.GothamBold
        resetBtn.AutoButtonColor = false
        Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

        local list = Instance.new("ScrollingFrame", Box)
        list.Size = UDim2.new(1, -12, 1, -40)
        list.Position = UDim2.new(0, 6, 0, 34)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 4
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ClipsDescendants = true
        local layout = Instance.new("UIListLayout", list)
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        local function Fmt(v) return tostring(math.round(v * 100) / 100) end

        local inputs = {}
        for i, def in ipairs(DELAY_SETTINGS) do
            local row = Instance.new("Frame", list)
            row.Size = UDim2.new(1, -8, 0, 40)
            row.LayoutOrder = i
            row.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
            row.BackgroundTransparency = 0.3
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local name = Instance.new("TextLabel", row)
            name.Size = UDim2.new(1, -84, 0, 18)
            name.Position = UDim2.new(0, 8, 0, 4)
            name.BackgroundTransparency = 1
            name.Text = def.label
            name.TextColor3 = Color3.fromRGB(225, 225, 230)
            name.TextSize = 11
            name.Font = Enum.Font.GothamMedium
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd

            local hint = Instance.new("TextLabel", row)
            hint.Size = UDim2.new(1, -84, 0, 14)
            hint.Position = UDim2.new(0, 8, 0, 22)
            hint.BackgroundTransparency = 1
            hint.Text = string.format("default %s   range %s - %s", Fmt(def.default), Fmt(def.min), Fmt(def.max))
            hint.TextColor3 = Color3.fromRGB(130, 130, 138)
            hint.TextSize = 9
            hint.Font = Enum.Font.Gotham
            hint.TextXAlignment = Enum.TextXAlignment.Left

            local input = Instance.new("TextBox", row)
            input.Size = UDim2.new(0, 64, 0, 26)
            input.AnchorPoint = Vector2.new(1, 0.5)
            input.Position = UDim2.new(1, -8, 0.5, 0)
            input.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
            input.TextColor3 = Color3.fromRGB(230, 230, 235)
            input.TextSize = 12
            input.Font = Enum.Font.GothamBold
            input.ClearTextOnFocus = false
            input.Text = Fmt(MatchConfig.Delays[def.key])
            Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
            inputs[def.key] = input

            input.FocusLost:Connect(function()
                local n = tonumber(input.Text)
                if n then
                    MatchConfig.Delays[def.key] = math.clamp(n, def.min, def.max)
                    SaveMatchConfig()
                end
                input.Text = Fmt(MatchConfig.Delays[def.key]) -- shows the clamped / unchanged value
            end)
        end

        resetBtn.Activated:Connect(function()
            for _, def in ipairs(DELAY_SETTINGS) do
                MatchConfig.Delays[def.key] = def.default
                inputs[def.key].Text = Fmt(def.default)
            end
            SaveMatchConfig()
            Log("info", "Settings: delays reset to defaults")
        end)
    end

    -- Resume any toggles that were saved as on, now that everything above is set up
    if MatchConfig.AutoCollectItems then StartAutoCollect() end
    if MatchConfig.AutoUpgrade then StartAutoUpgrade() end
    if MatchConfig.AutoFish then StartAutoFish() end
    if MatchConfig.AutoReplay then StartAutoReplay() end
    if MatchConfig.AutoPlayMacro then StartAutoPlayMacro() end
    print("[TDR] Match tab built.")
end
