print("Hello")
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
        local ok, err = pcall(function()
            UI.CreateQueue:InvokeServer(Config.Map, Config.Act, Config.Mode, 1, "")
            task.wait(0.5) -- let the queue register server-side before starting it
            UI.StartQueue:InvokeServer()
        end)
        if ok then
            UpdateStatus()
        else
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
    local PlayMacro, AddMacroListEntry, SaveMacros, LoadMacros

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
        if not remote then return false end
        return (pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(...)
            else
                remote:FireServer(...)
            end
        end))
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
            while MatchConfig.AutoPlayMacro do
                if SelectedMacro then
                    local lastAction = SelectedMacro.Actions[#SelectedMacro.Actions]
                    local duration = lastAction and lastAction.t or 0
                    PlayMacro(SelectedMacro)
                    task.wait(duration + 1)
                else
                    task.wait(1)
                end
            end
            AutoPlayRunning = false
        end)
    end

    MakeCustomToggle(TogglesHolder, "Auto-Replay", MatchConfig.AutoReplay, function(state)
        MatchConfig.AutoReplay = state
        SaveMatchConfig()
        if state then StartAutoReplay() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Collect Items", MatchConfig.AutoCollectItems, function(state)
        MatchConfig.AutoCollectItems = state
        SaveMatchConfig()
        if state then StartAutoCollect() else StopAutoCollect() end
    end)

    MakeCustomToggle(TogglesHolder, "Auto-Play Macro", MatchConfig.AutoPlayMacro, function(state)
        MatchConfig.AutoPlayMacro = state
        SaveMatchConfig()
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
                actions[j] = {t = action.t, remote = action.remote, method = action.method, args = args}
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
                actions[j] = {t = action.t, remote = action.remote, method = action.method, args = args}
            end
            out[i] = {Name = macro.Name, Actions = actions}
        end
        return out
    end

    SaveMacros = function()
        pcall(function()
            if isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            writefile(MACRO_FILE, jsonencode(SerializeMacros(Macros)))
            print("Macros have been saved.")
        end)
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
    PlayMacro = function(macro)
        task.spawn(function()
            local startedAt = tick()
            for _, action in ipairs(macro.Actions) do
                local remaining = action.t - (tick() - startedAt)
                if remaining > 0 then task.wait(remaining) end
                local remote = RemotesByLabel[action.remote]
                if remote then
                    pcall(function()
                        if action.method == "InvokeServer" then
                            remote:InvokeServer(table.unpack(action.args))
                        else
                            remote:FireServer(table.unpack(action.args))
                        end
                    end)
                end
            end
        end)
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
        else
            Recording = false
            RecordButton.Text = "Record"
            RecordButton.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
            if CurrentMacro then
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
        table.insert(CurrentMacro.Actions, {
            t = tick() - RecordStart,
            remote = label,
            method = method,
            args = {...},
        })
    end

    -- Every RemoteEvent/RemoteFunction under Events gets tracked dynamically
    -- (PlaceTower, TowerTargeting, UpgradeTower, SellTower, Skip, StartMatch,
    -- ReplayMatch, and anything else that shows up), instead of a fixed list.
    -- Runs in its own thread so a slow/missing remote can never block the UI.
    local TargetRemotes = {}
    local IGNORED_REMOTES = {PickupDrop = true}

    local function RegisterRemote(inst)
        local isRemote = inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")
        if isRemote and not IGNORED_REMOTES[inst.Name] then
            local label = inst:GetFullName():match("Events%.(.+)") or inst.Name
            TargetRemotes[inst] = label
            RemotesByLabel[label] = inst
        end
    end

    task.spawn(function()
        local ok, Events = pcall(function()
            return ReplicatedStorage:WaitForChild("Events", 15)
        end)
        if not (ok and Events) then return end

        for _, inst in ipairs(Events:GetDescendants()) do
            RegisterRemote(inst)
        end
        Events.DescendantAdded:Connect(RegisterRemote)

        local OldNamecall
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Recording and (method == "InvokeServer" or method == "FireServer") then
                local label = TargetRemotes[self]
                if label then
                    RecordAction(label, method, ...)
                end
            end
            return OldNamecall(self, ...)
        end))
    end)

    -- Resume any toggles that were saved as on, now that everything above is set up
    if MatchConfig.AutoCollectItems then StartAutoCollect() end
    if MatchConfig.AutoReplay then StartAutoReplay() end
    if MatchConfig.AutoPlayMacro then StartAutoPlayMacro() end
    print("[TDR] Match tab built.")
end
