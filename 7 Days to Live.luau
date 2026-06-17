---× [ SERVICEs ] ×---
local WS         = game:GetService("Workspace")
local PLRS       = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")

---× [ VARIABLEs ] ×---
local LOC  = PLRS.LocalPlayer
local CHAR = LOC.Character or LOC.CharacterAdded:Wait()

local COLLECTABLE = {
	WS:WaitForChild("dropped"),
	WS:WaitForChild("harvest"),
}

local NPCs = {
	WS:WaitForChild("enemies"),
	WS:WaitForChild("scps"),
	WS:WaitForChild("animals"),
}

local SCRAPS    = WS:FindFirstChild("scrap") or WS
local INTERACTS = WS:FindFirstChild("interact")

---× [ REMOTEs ] ×---
local REMOTES = RS:WaitForChild("remotes")
local FALLDMG = REMOTES:FindFirstChild("fall_damage")
local SHOOT   = REMOTES:FindFirstChild("shoot")
local RELOAD  = REMOTES:FindFirstChild("reload")
local CAST    = REMOTES:FindFirstChild("cast")
local POINT   = REMOTES:FindFirstChild("fish_point")

---× [ FUNCTIONs ] ×---
local function GetCFrame()
	local root  = CHAR:FindFirstChild("HumanoidRootPart")
	if not root then return end
	return root.CFrame
end

local function breakvelocity(length)
	local PassTheLength, V3 = false, Vector3.new(0, 0, 0)
	task.delay(length or 1, function()
		PassTheLength = true
	end)
	while not PassTheLength do
		for _, v in ipairs(CHAR:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Velocity, v.RotVelocity = V3, V3
			end
		end
		task.wait()
	end
end

local function TP(obj)
	local root = CHAR:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local cf
	if typeof(obj) == "CFrame" then
		cf = obj
	elseif obj:IsA("Model") then
		cf = obj:GetPivot()
	elseif obj:IsA("BasePart") then
		cf = obj.CFrame
	end
	if cf then root.CFrame = cf + vector.create(0, 5, 0) end
end

local function COLLECT(obj, prox)
	local prompt = prox or obj:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	TP(obj)
	task.wait(0.4)
	fireproximityprompt(prompt)
end

local function FISH()
	CAST:FireServer(CHAR.HumanoidRootPart.Position)
	for i = 1, 100 do
		POINT:FireServer(true)
	end
end

---× [ SCRIPT ] ×---
-- Remove Fall Damage
if FALLDMG then
	local o; o = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if not checkcaller() and self == FALLDMG and method == "FireServer" then
			return o(self, 0)
		end
		return o(self, ...)
	end))
end

-- Remove Colourblind effect
local vision = game:GetService("Lighting"):FindFirstChild("relenas_vision")
if vision then vision:Destroy() end

-- Remove annoying easter egg
WS.ChildAdded:Connect(function(obj)
	task.wait(0.1)
	if obj.Name == "easter_egg" then obj:Destroy() end
end)

---× [ GUI ] ×---
local Dark = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/RedZenXYZ/DARK-LIBRARY/refs/heads/main/source.lua"
))()
local Lib = Dark.CreateLib()

local KILLDist = 80
local SELECTED_Harvests  = {}

-- ── Player Tab ────────────────────────────────────────────────────────────────
local PlayerTab = Lib:AddTab("Player")

local godMode = false
PlayerTab:AddToggle("God Mode", "Heal when HP drops below 80%", false, function(state)
	godMode = state
	task.spawn(function()
		while godMode do
			local hum = CHAR:FindFirstChildOfClass("Humanoid")
			if hum and (hum.Health / hum.MaxHealth) * 100 < 80 then
				FALLDMG:FireServer(-hum.MaxHealth)
			end
			task.wait(0.5)
		end
	end)
end)

-- ── Items Tab ─────────────────────────────────────────────────────────────────
local ItemsTab = Lib:AddTab("Items")

local collectAura = false
ItemsTab:AddToggle("Collect Aura", "Auto-collect nearby items within 15 studs", false, function(state)
	collectAura = state
	task.spawn(function()
		while collectAura do
			for _, t in ipairs(COLLECTABLE) do
				for _, obj in ipairs(t:GetChildren()) do
					local main = obj:FindFirstChild("main") or obj:FindFirstChild("Handle")
					if main then
						local dist = LOC:DistanceFromCharacter(main.Position)
						local prox = main:FindFirstChildOfClass("ProximityPrompt")
						if prox and dist < 15 then
							fireproximityprompt(prox)
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)
end)

local autoScrap = false
ItemsTab:AddToggle("Auto Scrap", "Collect all scraps and supply crates then return", false, function(state)
	autoScrap = state
	task.spawn(function()
		while autoScrap do task.wait(0.1)
			local oldCF = GetCFrame()
			local didTP = false

			local supply = WS:FindFirstChild("supply_crate")
			if supply and supply:FindFirstChild("hey") then
				didTP = true
				task.spawn(breakvelocity)
				COLLECT(supply.hey)
			end

			for _, obj in ipairs(SCRAPS:GetChildren()) do
				if obj.Name ~= "scrap" then continue end
				local main = obj:FindFirstChild("defaultMaterial10")
				if main then
					didTP = true
					COLLECT(main)
				end
			end

			if didTP then
				task.wait(0.5)
				TP(oldCF)
			end
		end
		task.wait(1)
	end)
end)

if CAST and POINT then
	local autoFish = false
	ItemsTab:AddToggle("Auto Fish", "Rapidly cast and reel fishing", false, function(state)
		autoFish = state
		task.spawn(function()
			while autoFish do
				task.spawn(FISH)
				task.wait(0.1)
			end
		end)
	end)
end

local tpcActive = false
ItemsTab:AddToggle("Teleport Collect", "TP to each harvest item and collect it", false, function(state)
	tpcActive = state
	task.spawn(function()
		local oldCF = GetCFrame()
		while tpcActive do
			local didTP = false
			for _, obj in ipairs(COLLECTABLE[2]:GetChildren()) do
				if not tpcActive then break end
				if not table.find(SELECTED_Harvests, obj.Name) then continue end
				local main = obj:FindFirstChild("main") or obj:FindFirstChild("Handle")
				if main then
					didTP = true
					COLLECT(main)
				end
			end
			if didTP then
				task.wait(0.5)
				TP(oldCF)
			end
			task.wait()
		end
	end)
end)

local harvestNames = {}
local seen = {}
for _, harvest in ipairs(COLLECTABLE[2]:GetChildren()) do
	if not seen[harvest.Name] then
		seen[harvest.Name] = true
		table.insert(harvestNames, harvest.Name)
	end
end

local SelectedDropdown = ItemsTab:AddDropdown("Select List", "collect these items during Teleport Collect", harvestNames, "multiple", function(list)
	SELECTED_Harvests = list
end)
COLLECTABLE[2].ChildAdded:Connect(function(harvest)
	if not seen[harvest.Name] then
		seen[harvest.Name] = true
		table.insert(harvestNames, harvest.Name)
		SelectedDropdown:UpdateOptions(harvestNames)
	end
end)

ItemsTab:AddTextLabel("Items")

ItemsTab:AddButton("Get Batteries", "Collect all batteries in the world", function()
	local oldCF = GetCFrame()
	for _, battery in ipairs(WS:GetDescendants()) do
		if battery.Name == "battery" then
			local main = battery:GetChildren()[1]
			if main then
				COLLECT(battery, main:FindFirstChildOfClass("ProximityPrompt"))
			end
		end
	end
	TP(oldCF)
end)

ItemsTab:AddButton("Get Glass Bottles", "Collect all Glasses in the world", function()
	local oldCF = GetCFrame()
	for _,obj in WS:GetDescendants() do
		if obj:IsA("MeshPart") and obj.Name == "glass" then
			COLLECT(obj)
		end
	end
	TP(oldCF)
end)

ItemsTab:AddButton("Get DogTags", "Collect all dogtags in dropped folder", function()
	local oldCF = GetCFrame()
	for _, obj in ipairs(COLLECTABLE[1]:GetChildren()) do
		if obj.Name == "Dog Tag" then
			COLLECT(obj.Handle)
		end
	end
	TP(oldCF)
end)

-- ── Gun Tab ───────────────────────────────────────────────────────────────────
local GunTab = Lib:AddTab("Gun")

GunTab:AddSlider("Kill Distance", "Max distance to shoot NPCs", 10, 500, 5, 80, function(val)
	KILLDist = val
end)

local killAura = false
GunTab:AddToggle("Kill Aura", "Shoot all NPCs within kill distance", false, function(state)
	killAura = state
	task.spawn(function()
		while killAura do
			local gun = CHAR:FindFirstChildOfClass("Tool")
			for _, t in ipairs(NPCs) do
				if not gun then break end
				for _, npc in ipairs(t:GetChildren()) do
					local hum  = npc:FindFirstChildOfClass("Humanoid")
					local root = npc:FindFirstChild("HumanoidRootPart")
					if not (root and hum) then continue end
					if hum.Health > 0 and LOC:DistanceFromCharacter(root.Position) < KILLDist then
						SHOOT:FireServer(
							CFrame.new(root.Position + Vector3.new(0, 0, 5)),
							root.CFrame
						)
					end
				end
			end
			task.wait(0.1)
		end
	end)
end)

local infAmmo = false
GunTab:AddToggle("Inf Ammo", "Spam reload remote", false, function(state)
	infAmmo = state
	task.spawn(function()
		while infAmmo do
			RELOAD:FireServer()
			task.wait(0.1)
		end
	end)
end)

-- ── Location Tab ──────────────────────────────────────────────────────────────
local LocationTab = Lib:AddTab("Location")

local spawnCF = (WS:FindFirstChild("SpawnLocation") and WS.SpawnLocation.CFrame)
	or CHAR:WaitForChild("HumanoidRootPart").CFrame

LocationTab:AddButton("Spawn", "Teleport to spawn", function()
	TP(spawnCF)
end)

local ignore = {"note", "glass"}
if INTERACTS then
	LocationTab:AddTextLabel("Others")
	for _, interactable in ipairs(INTERACTS:GetChildren()) do
		if table.find(ignore, interactable.Name) then continue end -- skip the ignore objects
		
		LocationTab:AddButton(interactable.Name, nil, function()
			TP(interactable:FindFirstChildOfClass("Part") or interactable)
		end)
	end
end
INTERACTS.ChildAdded:Connect(function(interactable)
	task.wait(0.1)
	if table.find(ignore, interactable.Name) then return end
	
	LocationTab:AddButton(interactable.Name, nil, function()
		TP(interactable:FindFirstChildOfClass("Part") or interactable)
	end)
end)
