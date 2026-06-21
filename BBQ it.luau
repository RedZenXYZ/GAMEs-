-- VARIABLEs
local Plr = game:GetService("Players").LocalPlayer
local Inventory = Plr.Backpack
local PlayerLot = game:GetService("Workspace").PlayerLots[Plr.Name]

local HttpService     = game:GetService("HttpService")
local RepStorage = game:GetService("ReplicatedStorage")

local Rep_Meats = RepStorage:WaitForChild("Meats")
local Rep_Totems = RepStorage:WaitForChild("Totems")

-- UIs
local TotemsShop = Plr.PlayerGui.Shop.Main.Content.TotemsPage
local MeatsShop = Plr.PlayerGui.MeatShop.Main.Content

-- data
local Money = Plr.Money

local Meats,Meats_Name = {}, {}
local Totems,Totems_Name = {}, {}

for _,rarity in Rep_Meats:GetChildren() do
	for _,meat in rarity:GetChildren() do
		table.insert(Meats_Name, meat.Name)
		Meats[meat.Name] = {
			Name = meat.Name or "Name not founded",
			Price = meat:GetAttribute("BasePrice") or "1",
			Frame = MeatsShop[rarity.Name .. "Page"][meat.Name]
		}
	end
end

for _,totem in Rep_Totems:GetChildren() do
	table.insert(Totems_Name, totem.Name)
	Totems[totem.Name] = {
		Name = totem.Name,
		Price = totem:GetAttribute("Price") or "1",
		Frame = TotemsShop[totem.Name]
	}
end

---× [ Helper FUNCTIONs ] ×---
local function IsTable(build)
   if build:GetAttribute("PriceBoost") then
      return true
   end
   return false
end

local function IsSmoker(build)
   return build:GetAttribute("IsSmoker")
end

local function IsGrill(build)
   if build:GetAttribute("HeatPerSecond") and not build:GetAttribute("IsSmoker") then
      return true
   end
   return false
end

local function IsPerfect(meat)
   local State = meat:WaitForChild("CookBillboard").BG.StateLabel.Text:lower()
   if State == "perfect" or State == "overcooked" then
      return true
   end
   return false
end

local function CleanName(meat)
	return meat.Name:gsub("%s*%([^)]*%)", ""):match("^%s*(.-)%s*$")
end

local function GetMeatsFromGrill(grill)
   local meats, empty_spots = {}, {}
   for _,spot in grill.GrillSpots:GetChildren() do
      local State = spot:FindFirstChildWhichIsA("BasePart") and meats or empty_spots
      table.insert(State, spot)
   end
   return meats, empty_spots
end

local function GetMeatsFromInv()
   local cooked_meats, raw_meats = {}, {}
   for _,meat in Inventory:GetChildren() do
      local State = meat.Name:lower():match(" raw ") and raw_meats or cooked_meats
      table.insert(State, meat)
   end
   return cooked_meats, raw_meats
end

local function GetSpotsFromTable(Table)
	local spots, meats = {}, {}
	for _,spot in Table.Plates:GetChildren() do
		local State = spot:FindFirstChildWhichIsA("BasePart") and meats or spots
		table.insert(State, spot)
	end
	return spots, meats
end

-- Shop
local function HasEnoughMoney(price)
	return Money.Value > price
end

local function GetStockLabel(frame)
	for _,frame in frame:GetChildren() do
		local label = frame:FindFirstChild("StockLabel")
		if label then
			return label
		end
	end
end

local function IsStocked(item)
	local label = GetStockLabel(item)
	return label.TextColor3 == Color3.fromRGB(120, 220, 120)
end

-- Inv
local function IsTotem(item)
	return table.find(Totems_Name, CleanName(item))
end

--+ [ REMOTEs ] +--
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
-- Lot Remotes
local PickUp_remote = Remotes:WaitForChild("PickupMeat")
local Place_remote = Remotes:WaitForChild("PlaceMeat")

local function PickUp(spot)
	PickUp_remote:FireServer(spot)
end

local function Place(spot, meat)
	local args = {
		spot,
		CleanName(meat)
	}
	Place_remote:FireServer(unpack(args))
end

-- Shop Remotes
local BuyMeat_remote = Remotes:WaitForChild("BuyMeat")
local BuyItem_remote = Remotes:WaitForChild("BuyShopItem")

local function BuyItem(item)
	if item == nil then return end
	if HasEnoughMoney(item.Price) and IsStocked(item.Frame) then
		BuyItem_remote:FireServer(item.Name, false)
	end
end

local function BuyMeat(meat)
	if meat == nil then return end
	if HasEnoughMoney(meat.Price) and IsStocked(meat.Frame) then
		BuyMeat_remote:FireServer(meat.Name, false)
	end
end

-- Build Remotes
local PickObject = Remotes:WaitForChild("PickupObject")
local PlaceObject = Remotes:WaitForChild("PlaceObject")

---× [ UI ] ×---
local Dark = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/RedZenXYZ/DARK-LIBRARY/refs/heads/main/source.lua"
))()
local Lib = Dark.CreateLib()
local Main = Lib:AddTab("MAIN")
Main:AddTextLabel("Automatic Stuffs")

local Auto_PickUp = false
Main:AddToggle("Auto PickUp", "Automatically pick perfect/overcooked progress meat", function(state)
	Auto_PickUp = state
	while Auto_PickUp do task.wait(0.5)
		for _,grill in PlayerLot:GetChildren() do
			if IsSmoker(grill) or IsGrill(grill) then
				local meats, _ = GetMeatsFromGrill(grill)
				for _,meat in meats do
					if IsPerfect(meat:FindFirstChildWhichIsA("BasePart")) then
						PickUp(meat)
					end
				end
			end
		end
	end
end)

local Auto_Grill = false
Main:AddToggle("Auto Grill", "", function(state)
	Auto_Grill = state
	while Auto_Grill do task.wait(0.5)
		local _, raw_meats = GetMeatsFromInv()
		if #raw_meats == 0 then continue end
		local idx = 1
		for _,grill in PlayerLot:GetChildren() do
			if (IsGrill(grill) or IsSmoker(grill)) and idx <= #raw_meats then
				local _, empty_spots = GetMeatsFromGrill(grill)
				for _,spot in empty_spots do
					if idx > #raw_meats then break end
					Place(spot, raw_meats[idx])
					idx += 1
					task.wait(0.1)
				end
			end
		end
	end
end)

local Auto_Sell = false
Main:AddToggle("Auto Sell", "Automatically place meats on tables", function(state)
	Auto_Sell = state
	while Auto_Sell do task.wait(0.5)
		local cooked_meats, _ = GetMeatsFromInv()
		if #cooked_meats == 0 then continue end
		local idx = 1
		for _,build in PlayerLot:GetChildren() do
			if IsTable(build) and idx <= #cooked_meats then
				local spots, _ = GetSpotsFromTable(build)
				for _,spot in spots do
					if idx > #cooked_meats then break end
					Place(spot, cooked_meats[idx])
					idx += 1
					task.wait(0.1)
				end
			end
		end
	end
end)

local Shop = Lib:AddTab("SHOP")

local Selected_Meats = {}
local Selected_Totems = {}
local ok, result = pcall(readfile, "Selected_Lists.txt")
if ok and result then
	local result = HttpService:JSONDecode(result)
	Selected_Totems = result.T
	Selected_Meats = result.M
end

Shop:AddTextLabel("Meats")
local SM = Shop:AddDropdown("Select Meats", "", Meats_Name, true, function(list)
	Selected_Meats = list
end)
SM:SelectOption(Selected_Meats, true)

Shop:AddTextLabel("Totems")
local ST = Shop:AddDropdown("Select Totems", "", Totems_Name, true, function(list)
	Selected_Totems = list
end)
ST:SelectOption(Selected_Totems, true)

local Auto_Buy = false
Shop:AddToggle("Auto Buy", "", function(state)
	Auto_Buy = state
	while Auto_Buy do task.wait(0.2)
		for _,meat in Selected_Meats do
			BuyMeat(Meats[meat])
		end
		
		for _,totem in Selected_Totems do
			BuyItem(Totems[totem])
		end
	end
end)

Shop:AddTextLabel("Save Lists")
Shop:AddButton("Save", "", function()
	writefile("Selected_Lists.txt", HttpService:JSONEncode({T = Selected_Totems, M = Selected_Meats}))
end)

local Other = Lib:AddTab("OTHERS")
Other:AddTextLabel("Build")
Other:AddButton("Pick all Meats from Tables", "", function()
	for _,build in PlayerLot:GetChildren() do
		local spots = build:FindFirstChild("GrillSpots") or build:FindFirstChild("Plates")
		if not spots then continue end
		for _,spot in spots:GetChildren() do
			if spot:FindFirstChildWhichIsA("BasePart") then
				PickUp(spot)
			end
		end
	end
end)

Other:AddButton("Pick all Builds from your Lot", "equip hammer first", function()
	for _,build in PlayerLot:GetChildren() do
		if build:IsA("Model") then
			PickObject:FireServer(build)
		end
	end
end)

Other:AddButton("Instantly place all build", "equip your build you want to place first", function()
	local build = Plr.Character:FindFirstChildOfClass("Tool")
	for i = 1,(build:GetAttribute("StackCount") or 1) do
		local args = {
			CleanName(build),
			PlayerLot.Important.Pivot.CFrame:ToObjectSpace(workspace.PlacementPreview:GetPivot())
		}
		PlaceObject:FireServer(unpack(args))
	end
end)

local Auto_Place = false
Other:AddToggle("Auto Place Totems", "Place the first totem first", function(state)
	Auto_Place = state
	while Auto_Place do task.wait(1)
		for _,totem in Inventory:GetChildren() do
			if IsTotem(totem) then
				local PlacedTotem = PlayerLot:FindFirstChild(CleanName(totem) .. "_Placed")
				if PlacedTotem then
					PlaceObject:FireServer(CleanName(totem), PlayerLot.Important.Pivot.CFrame:ToObjectSpace(PlacedTotem:GetPivot()))
				end
			end
		end
	end
end)
