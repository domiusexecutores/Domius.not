local _ENV = (getgenv or getrenv or getfenv)()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer;

local DialogueEvent = ReplicatedStorage.BetweenSides.Remotes.Events.DialogueEvent;
local CombatEvent = ReplicatedStorage.BetweenSides.Remotes.Events.CombatEvent;
local ToolEvent = ReplicatedStorage.BetweenSides.Remotes.Events.ToolsEvent;
local QuestsNpcs = workspace.IgnoreList.Int.NPCs.Quests;
local Enemys = workspace.Playability.Enemys;

local QuestsDecriptions = require(ReplicatedStorage.MainModules.Essentials.QuestDescriptions)

local EnemiesFolders = {}
local QuestsData = {}
local CFrameAngle = CFrame.Angles(math.rad(-90), 0, 0)

local GetCurrentQuest do
	QuestsData.QuestsList = {}
	QuestsData.QuestsNPCs = {}
	QuestsData.EnemyList = {}
	
	table.clear(QuestsData.QuestsList)
	
	local CurrentQuest = nil;
	local CurrentLevel = -1;
	
	for _, QuestData in QuestsDecriptions do
		if QuestData.Goal <= 1 then continue end
		
		table.insert(QuestsData.QuestsList, {
			Level = QuestData.MinLevel;
			Target = QuestData.Target;
			NpcName = QuestData.Npc;
			Id = QuestData.Id;
		})
	end
	
	table.sort(QuestsData.QuestsList, function(a, b)
		return a.Level > b.Level;
	end)
	
	GetCurrentQuest = function()
		local Level = tonumber(Player.PlayerGui.MainUI.MainFrame.StastisticsFrame.BaseFrame.Level.Text);
		
		if Level == CurrentLevel then
			return CurrentQuest;
		end
		
		for _, QuestData in QuestsData.QuestsList do
			if QuestData.Level <= Level then
				CurrentLevel, CurrentQuest = Level, QuestData
				return QuestData
			end
		end
	end
end

local Settings = {
	ClickV2 = false;
	TweenSpeed = 125;
	SelectedTool = "CombatType";
}

local EquippedTool = nil;

local Connections = _ENV.rz_connections or {} do
	_ENV.rz_connections = Connections
	
	for i = 1, #Connections do
		Connections[i]:Disconnect()
	end
	
	table.clear(Connections)
end

local function IsAlive(Character)
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid");
		return Humanoid and Humanoid.Health > 0;
	end
end

local BodyVelocity do
	BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.Velocity = Vector3.zero
	BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	BodyVelocity.P = 1000
	
	if _ENV.tween_bodyvelocity then
		_ENV.tween_bodyvelocity:Destroy()
	end
	
	_ENV.tween_bodyvelocity = BodyVelocity
	
	local CanCollideObjects = {}
	
	local function AddObjectToBaseParts(Object)
		if Object:IsA("BasePart") and Object.CanCollide then
			table.insert(CanCollideObjects, Object)
		end
	end
	
	local function RemoveObjectsFromBaseParts(BasePart)
		local index = table.find(CanCollideObjects, BasePart)
		
		if index then
			table.remove(CanCollideObjects, index)
		end
	end
	
	local function NewCharacter(Character)
		table.clear(CanCollideObjects)
		
		for _, Object in Character:GetDescendants() do AddObjectToBaseParts(Object) end
		Character.DescendantAdded:Connect(AddObjectToBaseParts)
		Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
	end
	
	table.insert(Connections, Player.CharacterAdded:Connect(NewCharacter))
	task.spawn(NewCharacter, Player.Character)
	
	local function NoClipOnStepped(Character)
		if _ENV.OnFarm then
			for i = 1, #CanCollideObjects do
				CanCollideObjects[i].CanCollide = false
			end
		elseif Character.PrimaryPart and not Character.PrimaryPart.CanCollide then
			for i = 1, #CanCollideObjects do
				CanCollideObjects[i].CanCollide = true
			end
		end
	end
	
	local function UpdateVelocityOnStepped(Character)
		local BasePart = Character:FindFirstChild("UpperTorso")
		local Humanoid = Character:FindFirstChild("Humanoid")
		local BodyVelocity = _ENV.tween_bodyvelocity
		
		if _ENV.OnFarm and BasePart and Humanoid and Humanoid.Health > 0 then
			if BodyVelocity.Parent ~= BasePart then
				BodyVelocity.Parent = BasePart
			end
		elseif BodyVelocity.Parent then
			BodyVelocity.Parent = nil
		end
		
		if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
			BodyVelocity.Velocity = Vector3.zero
		end
	end
	
	table.insert(Connections, RunService.Stepped:Connect(function()
		local Character = Player.Character;
		
		if IsAlive(Character) then
			UpdateVelocityOnStepped(Character)
			NoClipOnStepped(Character)
		end
	end))
end

local PlayerTP do
	local TweenCreator = {} do
		TweenCreator.__index = TweenCreator
		
		local tweens = {}
		local EasingStyle = Enum.EasingStyle.Linear
		
		function TweenCreator.new(obj, time, prop, value)
			local self = setmetatable({}, TweenCreator)
			
			self.tween = TweenService:Create(obj, TweenInfo.new(time, EasingStyle), { [prop] = value })
			self.tween:Play()
			self.value = value
			self.object = obj
			
			if tweens[obj] then
				tweens[obj]:destroy()
			end
			
			tweens[obj] = self
			return self
		end
		
		function TweenCreator:destroy()
			self.tween:Pause()
			self.tween:Destroy()
			
			tweens[self.object] = nil
			setmetatable(self, nil)
		end
		
		function TweenCreator:stopTween(obj)
			if obj and tweens[obj] then
				tweens[obj]:destroy()
			end
		end
	end
	
	local function TweenStopped()
		if not BodyVelocity.Parent and IsAlive(Player.Character) then
			TweenCreator:stopTween(Player.Character:FindFirstChild("HumanoidRootPart"))
		end
	end
	
	local lastCFrame = nil;
	local lastTeleport = 0;
	
	PlayerTP = function(TargetCFrame)
		if not IsAlive(Player.Character) or not Player.Character.PrimaryPart then
			return false
		elseif (tick() - lastTeleport) <= 1 and lastCFrame == TargetCFrame then
			return false
		end
		
		local Character = Player.Character
		local Humanoid = Character.Humanoid
		local PrimaryPart = Character.PrimaryPart
		
		if Humanoid.Sit then Humanoid.Sit = false return end
		
		lastTeleport = tick()
		lastCFrame = TargetCFrame
		_ENV.OnFarm = true
		
		local teleportPosition = TargetCFrame.Position;
		local Distance = (PrimaryPart.Position - teleportPosition).Magnitude;
		
		if Distance < Settings.TweenSpeed then
			PrimaryPart.CFrame = TargetCFrame
			return TweenCreator:stopTween(PrimaryPart)
		end
		
		TweenCreator.new(PrimaryPart, Distance / Settings.TweenSpeed, "CFrame", TargetCFrame)
	end
	
	table.insert(Connections, BodyVelocity:GetPropertyChangedSignal("Parent"):Connect(TweenStopped))
end

local CurrentTime = workspace:GetServerTimeNow()

local function DealDamage(Enemies)
	CurrentTime = workspace:GetServerTimeNow()
	
	CombatEvent:FireServer("DealDamage", {
		CallTime = CurrentTime;
		DelayTime = workspace:GetServerTimeNow() - CurrentTime;
		Combo = 1;
		Results = Enemies;
	})
end

local function GetMobFromFolder(Folder, EnemyName)
	for _, Enemy in Folder:GetChildren() do
		if Enemy:GetAttribute("Respawned") and Enemy:GetAttribute("Ready") then
			if Enemy:GetAttribute("OriginalName") == EnemyName then
				return Enemy;
			end
		end
	end
end

local function GetClosestEnemy(EnemyName)
	local EnemyFolder = EnemiesFolders[EnemyName]
	
	if EnemyFolder then
		return GetMobFromFolder(EnemyFolder, EnemyName)
	end
	
	local Islands = Enemys:GetChildren()
	
	for i = 1, #Islands do
		local Enemies = Islands[i]:GetChildren()
		
		for x = 1, #Enemies do
			if Enemies[x]:GetAttribute("OriginalName") == EnemyName then
				EnemiesFolders[EnemyName] = Islands[i]
				return GetMobFromFolder(Islands[i], EnemyName)
			end
		end
	end
end

local function BringEnemies(Enemies, Target)
	for _, Enemy in Enemies do
		local RootPart = Enemy:FindFirstChild("HumanoidRootPart")
		
		if RootPart then
			RootPart.Size = Vector3.one * 30
			RootPart.CFrame = Target
		end
	end
	
	pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
end

local function IsSelectedTool(Tool)
	return Tool:GetAttribute(Settings.SelectedTool)
end

local function EquipCombat(Activate)
	if not IsAlive(Player.Character) then return end
	
	if EquippedTool and IsSelectedTool(EquippedTool) then
		if Activate then
			EquippedTool:Activate()
		end
		
		if EquippedTool.Parent == Player.Backpack then
			Player.Character.Humanoid:EquipTool(EquippedTool)
		elseif EquippedTool.Parent ~= Player.Character then
			EquippedTool = nil;
		end
		return nil
	end
	
	local Equipped = Player.Character:FindFirstChildOfClass("Tool")
	
	if Equipped and IsSelectedTool(Equipped) then
		EquippedTool = Equipped
		return nil;
	end
	
	for _, Tool in Player.Backpack:GetChildren() do
		if Tool:IsA("Tool") and IsSelectedTool(Tool) then
			EquippedTool = Tool
			return nil;
		end
	end
end

local function HasQuest(EnemyName)
	local QuestFrame = Player.PlayerGui.MainUI.MainFrame.CurrentQuest;
	local GoalLabel = QuestFrame:FindFirstChild("Goal") or QuestFrame:FindFirstChild("GoalText") or QuestFrame:FindFirstChild("Objective");
	
	if GoalLabel then
		return QuestFrame.Visible and GoalLabel.Text:find(EnemyName);
	end
	
	return false;
end

local function TakeQuest(QuestName, QuestId)
	local Npc = QuestsNpcs:FindFirstChild(QuestName, true)
	local RootPart = Npc and Npc.PrimaryPart
	
	if RootPart then
		DialogueEvent:FireServer("Quests", { ["NpcName"] = QuestName; ["QuestName"] = QuestId })
		PlayerTP(RootPart.CFrame)
	end
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
	Title = "Domius - Vox Seas",
	SubTitle = "by mini hell",
	TabWidth = 160,
	Size = UDim2.fromOffset(500, 300),
	Acrylic = true,
	Theme = "Darker",
	MinimizeKey = Enum.KeyCode.End
})
local t = Window:AddTab({
	Title = "Farm",
	Icon = "home"
})
local se = Window:AddTab({
	Title = "Status",
	Icon = "sun-medium"
})

local s = Window:AddTab({
	Title = "Settings",
	Icon = "settings"
})
local sv = Window:AddTab({
	Title = "Shop",
	Icon = "shopping-cart"
})
local st = Window:AddTab({
	Title = "Esp",
	Icon = "eye"
})
local f = Window:AddTab({
	Title = "Fruit",
	Icon = "activity"
})


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueEvent = ReplicatedStorage.BetweenSides.Remotes.Events.DialogueEvent

local SwordShop = {
    ["Katana"] = function()
        DialogueEvent:FireServer("InsertShop", "Katana")
    end,
    ["Cutlass"] = function()
        DialogueEvent:FireServer("InsertShop", "Cutlass")
    end,
    ["Dual Katana"] = function()
        DialogueEvent:FireServer("InsertShop", "Dual Katana")
    end,
    ["Bisento"] = function()
        DialogueEvent:FireServer("InsertShop", "Bisento")
    end,
}

local FightingStyles = {
    ["Eletric"] = function()
        DialogueEvent:FireServer("LearnFightingStyle", "Eletric")
    end,
    ["Water Kung-Fu"] = function()
        DialogueEvent:FireServer("LearnFightingStyle", "Water Kung-Fu")
    end,
    ["Dark Step"] = function()
        DialogueEvent:FireServer("LearnFightingStyle", "Dark Step")
    end,
}

local GunShop = {
    ["Slingshot"] = function()
        DialogueEvent:FireServer("InsertShop", "Slingshot")
    end,
    ["Flintlock"] = function()
        DialogueEvent:FireServer("InsertShop", "Flintlock")
    end,
    ["Musket"] = function()
        DialogueEvent:FireServer("InsertShop", "Musket")
    end,
}

local armas = {}
for armaName in pairs(SwordShop) do
    table.insert(armas, armaName)
end
local armaSelecionada = armas[1]

local estilos = {}
for styleName in pairs(FightingStyles) do
    table.insert(estilos, styleName)
end
local estiloSelecionado = estilos[1]

local guns = {}
for gunName in pairs(GunShop) do
    table.insert(guns, gunName)
end
local gunSelecionada = guns[1]

local dropdownArma = sv:AddDropdown("SelectWeapon", {
    Title = "Select Sword To Buy",
    Values = armas,
    Default = armaSelecionada,
    Callback = function(selected)
        armaSelecionada = selected
    end
})

local dropdownEstilo = sv:AddDropdown("SelectFightingStyle", {
    Title = "Select Fighting Style",
    Values = estilos,
    Default = estiloSelecionado,
    Callback = function(selected)
        estiloSelecionado = selected
    end
})

local dropdownGun = sv:AddDropdown("SelectGun", {
    Title = "Select Gun To Buy",
    Values = guns,
    Default = gunSelecionada,
    Callback = function(selected)
        gunSelecionada = selected
    end
})

local autoBuyAtivo = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function loadSettings(settingName, defaultValue)
    local success, result = pcall(function()
        return player:WaitForChild("PlayerGui"):FindFirstChild("DomiusSettings") and player.PlayerGui.DomiusSettings:FindFirstChild(settingName) and player.PlayerGui.DomiusSettings[settingName].Value
    end)
    return success and result or defaultValue
end

local function saveSetting(settingName, value)
    local success, _ = pcall(function()
        local settingsFolder = player:WaitForChild("PlayerGui"):FindFirstChild("DomiusSettings")
        if not settingsFolder then
            settingsFolder = Instance.new("Folder")
            settingsFolder.Name = "DomiusSettings"
            settingsFolder.Parent = player.PlayerGui
        end
        local settingValue = Instance.new("BoolValue")
        settingValue.Name = settingName
        settingValue.Value = value
        settingValue.Parent = settingsFolder
    end)
end

local defaultAutoBuy = loadSettings("AutoBuyToggle", false)
local toggle = sv:AddToggle("AutoBuyToggle", {
    Title = "Auto Buy",
    Description = "",
    Default = defaultAutoBuy,
    Callback = function(state)
        autoBuyAtivo = state
        saveSetting("AutoBuyToggle", state)
        if autoBuyAtivo then
            if SwordShop[armaSelecionada] then
                SwordShop[armaSelecionada]()
            elseif FightingStyles[estiloSelecionado] then
                FightingStyles[estiloSelecionado]()
            elseif GunShop[gunSelecionada] then
                GunShop[gunSelecionada]()
            end
        end
    end
})
local configSection = sv:AddSection("Others:")
local DialogueEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("BetweenSides")
    :WaitForChild("Remotes")
    :WaitForChild("Events")
    :WaitForChild("DialogueEvent")

local FightingStyles = {
    "Eletric",
    "Water Kung-Fu",
    "Dark Step"
}

local Dropdown = sv:AddDropdown("DropdownFightingStyle", {
    Title = "Select Fighting equip",
    Description = "",
    Values = FightingStyles,
    Default = "Dark Step",
    Callback = function(selected)
        local args = {
            [1] = "LearnFightingStyle",
            [2] = selected
        }
        DialogueEvent:FireServer(unpack(args))
    end
})
local sectionJobid = se:AddSection("Job Id:");

local currentJobId = ""

local jobInput = se:AddInput("JobInput", {
    Title = "JobId",
    Default = "",
    Placeholder = "input id",
    Numeric = false,
    Finished = false,
    Callback = function(text)
        currentJobId = text
        print("JobId:", currentJobId)
    end
})
se:AddButton({
    Title = "Teleport",
    Description = "",
    Callback = function()
        if currentJobId ~= "" then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, currentJobId, game.Players.LocalPlayer)
        else
            warn("nil")
        end
    end
})

se:AddButton({
    Title = "Clear Job Id",
    Description = "",
    Callback = function()
        currentJobId = ""
        jobInput:SetValue("")
    end
})

local islands = {
    ["Air jump island"] = CFrame.new(3303.12891, 9.49221897, -4136.46143),
    ["Central town"] = CFrame.new(2326.60352, 20.7244968, 838.597168),
    ["Coliseu"] = CFrame.new(-4089.19922, 10.0127153, -2372.26758),
    ["Dark arena"] = CFrame.new(-6438.03369, 15.020503, 2314.52441),
    ["Foosha village"] = CFrame.new(1874.23999, 27.9421139, -1067.56494),
    ["Fontain"] = CFrame.new(11044.6348, 55.2471962, 792.368408),
    ["Frost island"] = CFrame.new(-444.063904, 46.759716, -368.136841),
    ["Marine Ford"] = CFrame.new(-1060.97742, 34.3808327, -4585.67578),
    ["Marine island"] = CFrame.new(5033.81543, 50.0766907, -3067.79883),
    ["Orange town"] = CFrame.new(-943.09906, 34.0286331, 2689.40356),
    ["Prison"] = CFrame.new(1718.66589, 16.9887753, 3948.1792),
    ["Sandstorm"] = CFrame.new(5962.16016, 16.7446957, 4912.18994),
    ["Sharkman park"] = CFrame.new(10534.1055, 28.371645, -3097.31543),
    ["Shipwreck"] = CFrame.new(343.907776, 9.84692097, 6004.5166),
    ["Skypie down"] = CFrame.new(7900.93848, 593.714172, -4896.42529),
    ["Skypie upper"] = CFrame.new(6788.604, 981.022583, -5876.46875),
    ["Vulcan island"] = CFrame.new(4132.79883, 38.5931206, -8863.64355),
    ["Werewolf island"] = CFrame.new(5719.46191, 19.0924568, 777.310059)
}

local espObjects = {}
local espAtivo = false
local renderConnection = nil

local function criarESP()
    for name, cframe in pairs(islands) do
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Size = Vector3.new(10, 10, 10)
        part.CFrame = cframe
        part.Name = "ESP_" .. name
        part.Parent = workspace

        local highlight = Instance.new("Highlight")
        highlight.Adornee = part
        highlight.FillColor = Color3.fromRGB(0, 0, 255)
        highlight.OutlineColor = Color3.fromRGB(0, 0, 255)
        highlight.FillTransparency = 0.7
        highlight.Parent = part

        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Adornee = part
        billboardGui.Size = UDim2.new(0, 200, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 12, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = part

        local textLabel = Instance.new("TextLabel")
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextSize = 18
        textLabel.Text = name .. " | calculando..."
        textLabel.Parent = billboardGui

        espObjects[part] = {
            highlight = highlight,
            label = textLabel,
            name = name,
            part = part
        }
    end

    renderConnection = RunService.RenderStepped:Connect(function()
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        for part, data in pairs(espObjects) do
            local dist = (hrp.Position - part.Position).Magnitude
            data.label.Text = data.name .. " | " .. math.floor(dist) .. " distância"
        end
    end)
end

local function removerESP()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end

    for part, data in pairs(espObjects) do
        if data.part then
            data.part:Destroy()
        end
    end
    espObjects = {}
end

local defaultIslandsESP = loadSettings("IslandsESP", false)
local espToggle = st:AddToggle("IslandsESP", {
    Title = "ESP Island",
    Description = "",
    Default = defaultIslandsESP,
    Callback = function(state)
        espAtivo = state
        saveSetting("IslandsESP", state)
        if espAtivo then
            criarESP()
            print("Islands ESP ativado")
        else
            removerESP()
            print("Islands ESP desativado")
        end
    end
})
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local espObjects = {}
local espAtivo = false

local renderConnection = nil
local playerAddedConnection = nil
local playerRemovingConnection = nil

local function createESPForPlayer(targetPlayer)
    if targetPlayer == player then return end
    if espObjects[targetPlayer] then return end

    local character = targetPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "PlayerESP"
    billboardGui.Adornee = hrp
    billboardGui.Size = UDim2.new(0, 150, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = hrp

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 14
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Parent = billboardGui

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.Font = Enum.Font.SourceSans
    distLabel.TextSize = 12
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Parent = billboardGui

    espObjects[targetPlayer] = {
        billboardGui = billboardGui,
        nameLabel = nameLabel,
        distLabel = distLabel,
        player = targetPlayer,
        hrp = hrp
    }

    local function update()
        local team = targetPlayer.Team
        nameLabel.Text = targetPlayer.Name
        if team == Teams.Pirates then
            nameLabel.TextColor3 = Color3.new(1, 0, 0)
            distLabel.TextColor3 = Color3.new(1, 0, 0)
        else
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
            distLabel.TextColor3 = Color3.new(1, 1, 1)
        end
    end

    update()
    local conn = targetPlayer:GetPropertyChangedSignal("Team"):Connect(update)

    espObjects[targetPlayer].teamConnection = conn
end

local function removeESP(targetPlayer)
    if espObjects[targetPlayer] then
        local data = espObjects[targetPlayer]
        if data.billboardGui then data.billboardGui:Destroy() end
        if data.teamConnection then data.teamConnection:Disconnect() end
        espObjects[targetPlayer] = nil
    end
end

local function limparTodosESP()
    for targetPlayer, _ in pairs(espObjects) do
        removeESP(targetPlayer)
    end
end

local function onPlayerAdded(plr)
    if not espAtivo then return end
    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        createESPForPlayer(plr)
    end
    plr.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart")
        createESPForPlayer(plr)
    end)
end

local function onPlayerRemoving(plr)
    removeESP(plr)
end

local defaultPlayersESP = loadSettings("PlayersESP", false)
local espToggle = st:AddToggle("PlayersESP", {
    Title = "ESP Player",
    Description = "",
    Default = defaultPlayersESP,
    Callback = function(state)
        espAtivo = state
        saveSetting("PlayersESP", state)
        if espAtivo then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    createESPForPlayer(plr)
                end
                plr.CharacterAdded:Connect(function(char)
                    char:WaitForChild("HumanoidRootPart")
                    createESPForPlayer(plr)
                end)
            end
            playerAddedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
            playerRemovingConnection = Players.PlayerRemoving:Connect(onPlayerRemoving)

            renderConnection = RunService.RenderStepped:Connect(function()
                local localChar = player.Character
                local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
                if not localHrp then return end

                for targetPlayer, data in pairs(espObjects) do
                    if targetPlayer.Character and data.hrp then
                        local dist = (localHrp.Position - data.hrp.Position).Magnitude
                        data.distLabel.Text = math.floor(dist) .. " distância"
                    else
                        removeESP(targetPlayer)
                    end
                end
            end)

            print("Players ESP ativado")
        else
            if playerAddedConnection then playerAddedConnection:Disconnect() end
            if playerRemovingConnection then playerRemovingConnection:Disconnect() end
            if renderConnection then renderConnection:Disconnect() end
            limparTodosESP()
            print("Players ESP desativado")
        end
    end
})
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local droppedToolsFolder = Workspace:WaitForChild("Playability"):WaitForChild("DroppedTools")

local espObjects = {}
local espConnection

local function createESP(part)
    if espObjects[part] then return end
    if not part:IsA("BasePart") then return end

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Adornee = part
    billboardGui.Size = UDim2.new(0, 150, 0, 40)
    billboardGui.StudsOffset = Vector3.new(0, part.Size.Y + 1, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 14
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    nameLabel.Text = part.Name
    nameLabel.Parent = billboardGui

    local distLabel = Instance.new("TextLabel")
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.Font = Enum.Font.SourceSans
    distLabel.TextSize = 12
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    distLabel.Parent = billboardGui

    espObjects[part] = {
        billboardGui = billboardGui,
        nameLabel = nameLabel,
        distLabel = distLabel,
        part = part,
    }
end

local function removeESP(part)
    if espObjects[part] then
        espObjects[part].billboardGui:Destroy()
        espObjects[part] = nil
    end
end

local function updateESP()
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local existingParts = {}

    for _, obj in pairs(droppedToolsFolder:GetChildren()) do
        if obj:IsA("BasePart") and obj.Transparency < 1 then
            existingParts[obj] = true
            if not espObjects[obj] then
                createESP(obj)
            end
        elseif obj:FindFirstChildWhichIsA("BasePart") then
            local part = obj:FindFirstChildWhichIsA("BasePart")
            existingParts[part] = true
            if not espObjects[part] then
                createESP(part)
            end
        end
    end

    for part, _ in pairs(espObjects) do
        if not existingParts[part] then
            removeESP(part)
        end
    end

    for part, data in pairs(espObjects) do
        if part and hrp then
            local dist = (hrp.Position - part.Position).Magnitude
            data.distLabel.Text = math.floor(dist) .. " distância"
        end
    end
end

local defaultFruitESP = loadSettings("FruitESP", false)
local toggle = st:AddToggle("FruitESP", {
    Title = "ESP Fruit",
    Default = defaultFruitESP,
    Callback = function(state)
        saveSetting("FruitESP", state)
        if state then
            espConnection = RunService.RenderStepped:Connect(updateESP)
        else
            if espConnection then
                espConnection:Disconnect()
                espConnection = nil
            end
            for part in pairs(espObjects) do
                removeESP(part)
            end
        end
    end
})
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

getgenv().TeleportDelay = getgenv().TeleportDelay or 1
getgenv().LastCollect = 0

local function getAvailableFruits()
    local fruits = {}
    local success, err = pcall(function()
        local droppedTools = Workspace:WaitForChild("Playability"):WaitForChild("DroppedTools")
        for _, tool in ipairs(droppedTools:GetChildren()) do
            if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
                local dist = (tool.Handle.Position - rootPart.Position).Magnitude
                table.insert(fruits, {
                    Object = tool,
                    Position = tool.Handle.Position,
                    Distance = dist
                })
            end
        end
    end)
    if not success then warn("Erro ao buscar frutas: " .. err) end
    return fruits
end

local function collectFruit(fruit)
    if not fruit or not fruit.Object or not fruit.Object:FindFirstChild("Handle") then return end
    
    local handle = fruit.Object.Handle
    local touchInterest = nil
    
    for _, v in ipairs(handle:GetChildren()) do
        if v.ClassName == "TouchTransmitter" or v.ClassName == "TouchInterest" then
            touchInterest = v
            break
        end
    end
    
    if touchInterest then
        local success, err = pcall(function()
            firetouchinterest(handle, rootPart, 0)
            task.wait(0.1)
            firetouchinterest(handle, rootPart, 1)
        end)
        if not success then
            warn("Erro ao ativar TouchInterest: "..tostring(err))
        end
    end
end

local function selectFruit(fruits)
    if #fruits == 0 then return nil end
    table.sort(fruits, function(a, b) return a.Distance < b.Distance end)
    return fruits[1]
end

local defaultCollectFruit = loadSettings("CollectFruit", false)
getgenv().TeleportToFruit = defaultCollectFruit
local toggle = f:AddToggle("CollectFruit", {
    Title = "Collect Fruit",
    Default = defaultCollectFruit,
    Callback = function(state)
        getgenv().TeleportToFruit = state
        saveSetting("CollectFruit", state)
    end
})

RunService.Heartbeat:Connect(function()
    if not getgenv().TeleportToFruit then return end
    if tick() - getgenv().LastCollect < getgenv().TeleportDelay then return end
    if not rootPart or not rootPart.Parent then
        rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
    end
    
    local availableFruits = getAvailableFruits()
    if #availableFruits > 0 then
        local selected = selectFruit(availableFruits)
        if selected then
            collectFruit(selected)
            getgenv().LastCollect = tick()
        end
    end
end)
local toggle = f:AddToggle("AutoStoreToggle", {
    Title = "Auto store",
    Default = true,
    Callback = function(state)
        getgenv().AutoStore = state
        if state then
            coroutine.wrap(function()
                while getgenv().AutoStore do
                    -- Atualiza o backpack a cada loop
                    local fruits = {}
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") and item.Name:lower():find("fruit") then
                            table.insert(fruits, item)
                        end
                    end

                    for _, fruit in ipairs(fruits) do
                        if not getgenv().AutoStore then break end

                        equipTool(fruit)
                        -- Envia o evento para armazenar
                        toolsEvent:FireServer("StoreFruit")

                        -- Espera um pouco para garantir que o servidor processou
                        task.wait(0.3)

                        -- Desequipa para evitar ficar preso na fruta
                        unequipTool()

                        -- Dá uma pausa pequena antes da próxima fruta
                        task.wait(0.1)
                    end

                    -- Se não tiver frutas no backpack, espera um pouco antes de checar de novo
                    if #fruits == 0 then
                        task.wait(1)
                    end
                end
            end)()
        end
    end
})
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local placeId = game.PlaceId

getgenv().AutoHopEnabled = false

local visitedServers = {}  -- tabela para guardar IDs visitados
local foundAnything = ""
local actualHour = os.date("!*t").hour

-- Atualiza/reset a lista de servidores visitados a cada nova hora
local function resetVisitedIfNeeded()
    if not visitedServers.hour or visitedServers.hour ~= actualHour then
        visitedServers = {hour = actualHour}
    end
end

local function showDomiusGui(seconds)
    local playerGui = player:WaitForChild("PlayerGui")
    local existingGui = playerGui:FindFirstChild("DomiusFullscreen")
    if existingGui then existingGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DomiusFullscreen"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = playerGui

    local Background = Instance.new("Frame")
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Background.BackgroundTransparency = 0.65
    Background.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.AnchorPoint = Vector2.new(0.5, 0.5)
    Title.Position = UDim2.new(0.5, 0, 0.4, 0)
    Title.Size = UDim2.new(0.8, 0, 0.1, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBlack
    Title.Text = "Domius New Sever"
    Title.TextColor3 = Color3.fromRGB(200, 200, 255)
    Title.TextScaled = true
    Title.TextWrapped = true
    Title.Parent = Background

    local Subtitle = Instance.new("TextLabel")
    Subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
    Subtitle.Position = UDim2.new(0.5, 0, 0.48, 0)
    Subtitle.Size = UDim2.new(0.8, 0, 0.06, 0)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Font = Enum.Font.GothamMedium
    Subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Subtitle.TextScaled = true
    Subtitle.TextWrapped = true
    Subtitle.Parent = Background

    local Reason = Instance.new("TextLabel")
    Reason.AnchorPoint = Vector2.new(0.5, 0.5)
    Reason.Position = UDim2.new(0.5, 0, 0.55, 0)
    Reason.Size = UDim2.new(0.9, 0, 0.05, 0)
    Reason.BackgroundTransparency = 1
    Reason.Font = Enum.Font.Gotham
    Reason.Text = "Find New Server [ MAIN ]"
    Reason.TextColor3 = Color3.fromRGB(180, 180, 180)
    Reason.TextScaled = true
    Reason.TextWrapped = true
    Reason.Parent = Background

    local Info = Instance.new("TextLabel")
    Info.AnchorPoint = Vector2.new(0.5, 0.5)
    Info.Position = UDim2.new(0.5, 0, 0.61, 0)
    Info.Size = UDim2.new(0.9, 0, 0.04, 0)
    Info.BackgroundTransparency = 1
    Info.Font = Enum.Font.Gotham
    Info.Text = "Discord.gg/domius"
    Info.TextColor3 = Color3.fromRGB(160, 160, 160)
    Info.TextScaled = true
    Info.TextWrapped = true
    Info.Parent = Background

    for i = seconds, 1, -1 do
        Subtitle.Text = "Hop Fruit in " .. i .. "s..."
        task.wait(1)
    end

    ScreenGui:Destroy()
end

local function TPReturner()
    resetVisitedIfNeeded()

    local Site
    if foundAnything == "" then
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
    end

    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    else
        foundAnything = ""
    end

    for _, v in ipairs(Site.data) do
        local serverID = tostring(v.id)
        local isNotFull = tonumber(v.playing) < tonumber(v.maxPlayers)
        local notVisited = not visitedServers[serverID]

        if isNotFull and notVisited then
            visitedServers[serverID] = true
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, serverID, player)
            end)
            return -- Sai para evitar múltiplos teleports seguidos
        end
    end
end

local function HopLoop()
    while getgenv().AutoHopEnabled do
        while getgenv().ChestsCount and getgenv().ChestsCount > 0 do
            task.wait(1)
        end
        showDomiusGui(3) -- Aumentado para 12 segundos
        pcall(function()
            TPReturner()
            if foundAnything ~= "" then
                TPReturner()
            end
        end)
        task.wait(0.1)
    end
end

local Toggle = f:AddToggle("AutoHopper", {
    Title = "Hop Server Fruit",
    Description = "",
    Default = getgenv().Setting and getgenv().Setting.AutoHOP == true,
    Callback = function(state)
        getgenv().AutoHopEnabled = state
        if state then
            coroutine.wrap(HopLoop)()
        end
    end
})
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Cria ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToggleButtonGui"
screenGui.Parent = game:GetService("CoreGui")
screenGui.ResetOnSpawn = false

-- Cria botão maior e redondo
local button = Instance.new("ImageButton")
button.Size = UDim2.new(0, 50, 0, 50)  -- Aumentado para 50x50
button.Position = UDim2.new(0, 10, 0, 10) -- posição inicial
button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
button.BackgroundTransparency = 0.2
button.AutoButtonColor = true
button.Image = "rbxassetid://136627086197355"
button.Parent = screenGui

-- Arredondar bordas para círculo perfeito
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 25) -- metade do tamanho do botão (50/2)
corner.Parent = button

-- Função para simular tecla End
local function pressEndKey()
    local vm = game:GetService("VirtualInputManager")
    vm:SendKeyEvent(true, Enum.KeyCode.End, false, game)
    vm:SendKeyEvent(false, Enum.KeyCode.End, false, game)
end

-- Executa o toggle logo ao rodar o script
pressEndKey()

-- Drag logic
local dragging = false
local dragInput, dragStart, startPos

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = button.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
        button.Position = newPos
    end
end)

-- Clique do botão: simula tecla End + animação com aumento de tamanho
button.MouseButton1Click:Connect(function()
    pressEndKey()
    local grow = TweenService:Create(button, TweenInfo.new(0.15), {Size = UDim2.new(0, 60, 0, 60)})
    local shrink = TweenService:Create(button, TweenInfo.new(0.15), {Size = UDim2.new(0, 50, 0, 50)})
    grow:Play()
    grow.Completed:Connect(function()
        shrink:Play()
    end)
end)
local sesico = t:AddSection("Farming:")

local toggle = t:AddToggle("Auto Farm Level", {
	Title = "Auto Farm Level",
	Default = false,
	Callback = function(state)
		_ENV.OnFarm = state
		
		while task.wait() and _ENV.OnFarm do
			local CurrentQuest = GetCurrentQuest()
			if not CurrentQuest then continue end
			
			if not HasQuest(CurrentQuest.Target) then
				TakeQuest(CurrentQuest.NpcName, CurrentQuest.Id)
				continue
			end
			
			local Enemy = GetClosestEnemy(CurrentQuest.Target)
			if not Enemy then continue end
			
			local HumanoidRootPart = Enemy:FindFirstChild("HumanoidRootPart")
			
			if HumanoidRootPart then
				if not HumanoidRootPart:FindFirstChild("BodyVelocity") then
					local BV = Instance.new("BodyVelocity", HumanoidRootPart)
					BV.Velocity = Vector3.zero
					BV.MaxForce = Vector3.one * math.huge
				end
				
				HumanoidRootPart.Size = Vector3.one * 35
				HumanoidRootPart.CanCollide = false
				
				EquipCombat(true)
				DealDamage({ Enemy })
				PlayerTP((HumanoidRootPart.CFrame + Vector3.yAxis * 10) * CFrameAngle)
			end
		end
	end
})
local selectedStat = "Defense"
local pointsPerCycle = 1
local auto = false

local StatsEvent = game:GetService("ReplicatedStorage")
    :WaitForChild("BetweenSides")
    :WaitForChild("Remotes")
    :WaitForChild("Events")
    :WaitForChild("StatsEvent")

local Dropdown = t:AddDropdown("DropdownStat", {
    Title = "Select Status",
    Description = "",
    Values = {"Defense", "Gun", "Sword", "Strength", "DevilFruit"},
    Default = "Defense",
    Callback = function(v)
        selectedStat = v
    end
})

local Slider = t:AddSlider("SliderPoints", {
    Title = "Amount",
    Description = "",
    Default = 1,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        pointsPerCycle = v
    end
})

local Toggle = t:AddToggle("ToggleAutoStatus", {
    Title = "Auto Status",
    Default = false,
    Callback = function(state)
        auto = state
        if auto then
            task.spawn(function()
                while auto do
                    for i = 1, pointsPerCycle do
                        local args = {
                            [1] = "UpgradeStat",
                            [2] = {
                                Defense = 0,
                                Gun = 0,
                                Sword = 0,
                                Strength = 0,
                                DevilFruit = 0
                            }
                        }
                        args[2][selectedStat] = 1
                        StatsEvent:FireServer(unpack(args))
                        task.wait(0.1)
                    end
                    task.wait(0.3)
                end
            end)
        end
    end
})

local configSection = s:AddSection("Config")

local toggle = s:AddToggle("Click V2", {
	Title = "Click V2",
	Default = false,
	Callback = function(state)
		Settings.ClickV2 = state
	end
})
local Slider = s:AddSlider("SliderExample", {
    Title = "Tween Speed",
    Description = "Adjust the movement speed",
    Default = 125,
    Min = 50,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

local Dropdown = s:AddDropdown("DropdownExample", {
    Title = "Select Tool",
    Description = "Choose the tool you want to use",
    Values = {"CombatType", "Sword", "Gun", "Magic"},
    Default = "CombatType",
    Multi = false,
    Callback = function(Value)
        Settings.SelectedTool = Value
    end
})
local configSection = s:AddSection("Time:")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueEvent = ReplicatedStorage:WaitForChild("BetweenSides").Remotes.Events.DialogueEvent

local function chooseTeam(teamName)
    task.delay(2, function()
        local args = {
            [1] = "Team",
            [2] = teamName
        }
        DialogueEvent:FireServer(unpack(args))
    end)
end

s:AddButton({
    Title = "Join Marines",
    Description = "",
    Callback = function()
        chooseTeam("Marines")
    end
})

s:AddButton({
    Title = "Join Pirates",
    Description = "",
    Callback = function()
        chooseTeam("Pirates")
    end
})
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local function boostGraphics()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 1
    Lighting.Ambient = Color3.new(1,1,1)
    Lighting.OutdoorAmbient = Color3.new(1,1,1)
    
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Explosion") then
            v:Destroy()
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("MeshPart") or v:IsA("Part") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
        elseif v:IsA("UnionOperation") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
        end
    end

    for _, v in pairs(StarterGui:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
            v:Destroy()
        end
    end
end

local function removeCharacterDetails()
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("MeshPart") or part:IsA("Part") or part:IsA("Accessory") then
            part.Transparency = 1
        end
    end
end

s:AddButton({
    Title = "Boost Fps",
    Description = "",
    Callback = function()
        boostGraphics()
        removeCharacterDetails()
        RunService.RenderStepped:Connect(function()
            boostGraphics()
        end)
    end
})
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local noFogConnection

local function enableNoFog()
    if noFogConnection then return end -- evita múltiplas conexões

    noFogConnection = RunService.RenderStepped:Connect(function()
        if Lighting:FindFirstChildOfClass("Atmosphere") then
            Lighting:FindFirstChildOfClass("Atmosphere"):Destroy()
        end

        Lighting.FogStart = 0
        Lighting.FogEnd = 1e9
        Lighting.FogColor = Color3.new(1,1,1)

        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") then
                obj.Enabled = false
            end
            if obj:IsA("FogVolume") then
                obj:Destroy()
            end
        end
    end)
end

s:AddButton({
    Title = "No Fog",
    Description = "",
    Callback = function()
        enableNoFog()
    end
})