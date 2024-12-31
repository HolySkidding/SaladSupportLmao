local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local runservice = runService
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	pots = {},
	attackReach = 0,
	localHand = {},
	attackReachUpdate = tick(),
	damage = {},
	equippedKit = "",
	damageBlockFail = tick(),
	grapple = tick(),
	scythe = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	localInventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly
local StoreDamage
local TrapDisabler
local bedwars, remotes, sides, oldinvrender = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end


local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end


local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end


local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	vape:Clean(vapeEvents.KnockbackReceived.Event:Connect(function()
		notif('StoreDamage', 'Added damage packet: '..#store.damage, 3)
	end))

	store.blocks = collection('block', gui)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
	sessioninfo:AddItem('Packets', 0, function()
		return #store.damage
	end, false)

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		local old = getthreadidentity()
		setthreadidentity(2)
		setthreadidentity(old)
	end)

	vape:Clean(function()
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end
	
run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local bedparts = bed:GetChildren()
		table.sort(bedparts, function(a, b) 
			return a.Name > b.Name 
		end)
	
		for _, part in bedparts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local boxhandle = Instance.new('BoxHandleAdornment')
				boxhandle.Size = part.Size + Vector3.new(.01, .01, .01)
				boxhandle.AlwaysOnTop = true
				boxhandle.ZIndex = 2
				boxhandle.Visible = true
				boxhandle.Adornee = part
				boxhandle.Color3 = part.Color
				if part.Name == 'Legs' then
					boxhandle.Color3 = Color3.fromRGB(167, 112, 64)
					boxhandle.Size = part.Size + Vector3.new(.01, -1, .01)
					boxhandle.CFrame = CFrame.new(0, -0.4, 0)
					boxhandle.ZIndex = 0
				end
				boxhandle.Parent = BedFolder
			end
		end
		table.clear(bedparts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed) 
					task.delay(0.2, Added, bed) 
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do 
					Added(bed) 
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)
	
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local KitESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'wild_flower'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'}
	}
	
	local function Added(v, icon)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local function addKit(tag, icon)
		KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			Added(v.PrimaryPart, icon)
		end))
		KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end))
		for _, v in collectionService:GetTagged(tag) do
			Added(v.PrimaryPart, icon)
		end
	end
	
	KitESP = vape.Categories.Render:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
					local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
					if kit then
						addKit(kit[1], kit[2])
					end
			    end)
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = KitESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Equipment
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	local fontitems = {'Arial'}
	local kititems = {
		jade = 'jade_hammer',
		archer = 'tactical_crossbow',
		cowgirl = 'lasso',
		dasher = 'wood_dao',
		axolotl = 'axolotl',
		yeti = 'snowball',
		smoke = 'smoke_block',
		trapper = 'snap_trap',
		pyro = 'flamethrower',
		davey = 'cannon',
		regent = 'void_axe',
		baker = 'apple',
		builder = 'builder_hammer',
		farmer_cletus = 'carrot_seeds',
		melody = 'guitar',
		barbarian = 'rageblade',
		gingerbread_man = 'gumdrop_bounce_pad',
		spirit_catcher = 'spirit',
		fisherman = 'fishing_rod',
		oil_man = 'oil_consumable',
		santa = 'tnt',
		miner = 'miner_pickaxe',
		sheep_herder = 'crook',
		beast = 'speed_potion',
		metal_detector = 'metal_detector',
		cyber = 'drone',
		vesta = 'damage_banner',
		lumen = 'light_sword',
		ember = 'infernal_saber',
		queen_bee = 'bee'
	}
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			local EntityNameTag = Instance.new('TextLabel')
			EntityNameTag.BackgroundColor3 = Color3.new()
			EntityNameTag.BorderSizePixel = 0
			EntityNameTag.Visible = false
			EntityNameTag.RichText = true
			EntityNameTag.AnchorPoint = Vector2.new(0.5, 1)
			EntityNameTag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			EntityNameTag.FontFace = FontOption.Value
			EntityNameTag.TextSize = 14 * Scale.Value
			EntityNameTag.BackgroundTransparency = Background.Value
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = EntityNameTag
				end
			end
			local nametagSize = getfontsize(removeTags(Strings[ent]), EntityNameTag.TextSize, EntityNameTag.FontFace, Vector2.new(100000, 100000))
			EntityNameTag.Size = UDim2.fromOffset(nametagSize.X + 8, nametagSize.Y + 7)
			EntityNameTag.Text = Strings[ent]
			EntityNameTag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			EntityNameTag.Parent = Folder
			Reference[ent] = EntityNameTag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			local EntityNameTag = {}
			EntityNameTag.BG = Drawing.new('Square')
			EntityNameTag.BG.Filled = true
			EntityNameTag.BG.Transparency = 1 - Background.Value
			EntityNameTag.BG.Color = Color3.new()
			EntityNameTag.BG.ZIndex = 1
			EntityNameTag.Text = Drawing.new('Text')
			EntityNameTag.Text.Size = 15 * Scale.Value
			EntityNameTag.Text.Font = (math.clamp((table.find(fontitems, FontOption.Value) or 1) - 1, 0, 3))
			EntityNameTag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
			EntityNameTag.Text.Text = Strings[ent]
			EntityNameTag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
			Reference[ent] = EntityNameTag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function() 
						obj.Visible = false 
						obj:Remove() 
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local EntityNameTag = Reference[ent]
			if EntityNameTag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
				if Equipment.Enabled and store.inventories[ent.Player] then
					local inventory = store.inventories[ent.Player]
				end
				local nametagSize = getfontsize(removeTags(Strings[ent]), EntityNameTag.TextSize, EntityNameTag.FontFace, Vector2.new(100000, 100000))
				EntityNameTag.Size = UDim2.fromOffset(nametagSize.X + 8, nametagSize.Y + 7)
				EntityNameTag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local EntityNameTag = Reference[ent]
			if EntityNameTag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					EntityNameTag.Text.Text = entitylib.isAlive and string.format(Strings[ent], (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude // 1) or Strings[ent]
				else
					EntityNameTag.Text.Text = Strings[ent]
				end
				EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
				EntityNameTag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local tagColor = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or tagColor
			end
		end,
		Drawing = function(hue, sat, val)
			local tagColor = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Text.Color = entitylib.getEntityColor(i) or tagColor
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, EntityNameTag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						EntityNameTag.Visible = false
						continue
					end
				end
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				EntityNameTag.Visible = headVis
				if not headVis then
					continue
				end
				if Distance.Enabled and entitylib.isAlive then
					local mag = (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude // 1
					if Sizes[ent] ~= mag then
						EntityNameTag.Text = string.format(Strings[ent], mag)
						local nametagSize = getfontsize(removeTags(EntityNameTag.Text), EntityNameTag.TextSize, EntityNameTag.FontFace, Vector2.new(100000, 100000))
						EntityNameTag.Size = UDim2.fromOffset(nametagSize.X + 8, nametagSize.Y + 7)
						Sizes[ent] = mag
					end
				end
				EntityNameTag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, EntityNameTag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						EntityNameTag.Text.Visible = false
						EntityNameTag.BG.Visible = false
						continue
					end
				end
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				EntityNameTag.Text.Visible = headVis
				EntityNameTag.BG.Visible = headVis and Background.Enabled
				if not headVis then
					continue
				end
				if Distance.Enabled and entitylib.isAlive then
					local mag = (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude // 1
					if Sizes[ent] ~= mag then
						EntityNameTag.Text.Text = string.format(Strings[ent], mag)
						EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				EntityNameTag.BG.Position = Vector2.new(headPos.X - (EntityNameTag.BG.Size.X / 2), headPos.Y + (EntityNameTag.BG.Size.Y / 2))
				EntityNameTag.Text.Position = EntityNameTag.BG.Position + Vector2.new(4, 2.5)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then 
							Removed[methodused](v) 
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then 
							Removed[methodused](ent) 
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do 
						Updated[methodused](v) 
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do 
						Removed[methodused](i) 
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true, 
		Function = function()
		if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end,
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function() 
			if NameTags.Enabled then 
				NameTags:Toggle() 
				NameTags:Toggle() 
			end 
		end,
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function nearStorageItem(item)
		for _, v in List.ListEnabled do
			if item:find(v) then return v end
		end
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then 
			v.Enabled = false 
			return 
		end
	
		local chestitems = chest and chest:GetChildren() or {}
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then 
				obj:Destroy() 
			end
		end
	
		v.Enabled = false
		local alreadygot = {}
		for _, item in chestitems do
			if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
				alreadygot[item.Name] = true
				v.Enabled = true
				local blockimage = Instance.new('ImageLabel')
				blockimage.Size = UDim2.fromOffset(32, 32)
				blockimage.BackgroundTransparency = 1
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:FindFirstChild('ChestFolderValue')
		if not chest then return end
		chest = chest.Value
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		StorageESP:Clean(chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		task.spawn(refreshAdornee, billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				for _, v in collectionService:GetTagged('chest') do 
					task.spawn(Added, v) 
				end
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do 
				task.spawn(refreshAdornee, v)
			end
		end
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined = {}
	
	local function getRole(plr, id)
		local suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if not suc then
			notif('StaffDetector', res, 30, 'alert')
		end
		return suc and res or 0
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function checkFriends(list)
		for _, v in list do
			if joined[v] then
				return joined[v]
			end
		end
		return nil
	end
	
	local function checkJoin(plr, connection)
		if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
			connection:Disconnect()
			local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
			for _ = 1, 4 do
				for _, v in pages:GetCurrentPage() do
					table.insert(tab, v.Id)
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
	
			local friend = checkFriends(tab)
			if not friend then
				staffFunction(plr, 'impossible_join')
				return true
			else
				notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
			end
		end
	end
	
	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
			return
		end
	
		if getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
		else
			local connection
			connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
				checkJoin(plr, connection)
			end)
			StaffDetector:Clean(connection)
			if checkJoin(plr, connection) then
				return
			end
	
			if not plr:GetAttribute('ClanTag') then
				plr:GetAttributeChangedSignal('ClanTag'):Wait()
			end
	
			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded then
				connection:Disconnect()
				staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			StaffDetector:Toggle()
		end
	end)
end)
	
run(function()
	StoreDamage = vape.Categories.Utility:CreateModule({
		Name = 'StoreDamage',
		Tooltip = 'Store damage knockback packets for certain modules.'
	})
end)
	
run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Disables Snap Traps'
	})
end)
	
run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Legit:CreateModule({
		Name = 'Hit Color',
		Function = function(callback)
			if callback then 
				repeat
					for i, v in entitylib.List do 
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then 
							if not table.find(done, highlight) then 
								table.insert(done, highlight) 
							end
							highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							highlight.FillTransparency = Color.Opacity
						end
					end
					task.wait(0.1)
				until not HitColor.Enabled
			else
				for i, v in done do 
					v.FillColor = Color3.new(1, 0, 0)
					v.FillTransparency = 0.4
				end
				table.clear(done)
			end
		end,
		Tooltip = 'Customize the hit highlight options'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)

run(function()
	local Sprint
	local old
	local SprintSpeed = {Value = 21}
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			if callback then
				shared.sprintconn = true 
				task.spawn(function()
					while task.wait() do 
						repeat task.wait() until game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
						if shared.sprintconn then 
							game.Players.LocalPlayer:SetAttribute("Sprinting", true)
							game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = SprintSpeed.Value
							game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {FieldOfView = 120}):Play()
						end 
					end 
			    end)
			else 
				shared.sprintconn = false 
				game.Players.LocalPlayer:SetAttribute("Sprinting", false)
				game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = SprintSpeed.Value 
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {FieldOfView = 80}):Play()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
	SprintSpeed = Sprint:CreateSlider({
		Name = 'Sprint Speed',
		Function = function(val) end,
		Default = 21,
		Min = 1,
		Max = 30,
		Decimal = 10
	})
end)
local runService = game:GetService("RunService")

local RunLoops = {
    RenderStepTable = {},
    StepTable = {},
    HeartTable = {}
}
local vapeConnections = {}
local function BindToLoop(tableName, service, name, func)
	local oldfunc = func
	func = function(delta) pcall(function() oldfunc(delta) end) end
    if RunLoops[tableName][name] == nil then
        RunLoops[tableName][name] = service:Connect(func)
        table.insert(vapeConnections, RunLoops[tableName][name])
    end
end

local function UnbindFromLoop(tableName, name)
    if RunLoops[tableName][name] then
        RunLoops[tableName][name]:Disconnect()
        RunLoops[tableName][name] = nil
    end
end

function RunLoops:BindToRenderStep(name, func)
    BindToLoop("RenderStepTable", runService.RenderStepped, name, func)
end

function RunLoops:UnbindFromRenderStep(name)
    UnbindFromLoop("RenderStepTable", name)
end

function RunLoops:BindToStepped(name, func)
    BindToLoop("StepTable", runService.Stepped, name, func)
end

function RunLoops:UnbindFromStepped(name)
    UnbindFromLoop("StepTable", name)
end

function RunLoops:BindToHeartbeat(name, func)
    BindToLoop("HeartTable", runService.Heartbeat, name, func)
end

function RunLoops:UnbindFromHeartbeat(name)
    UnbindFromLoop("HeartTable", name)
end	
local bedwars = {
    ProjectileRemote = "ProjectileFire",
    EquipItemRemote = "SetInvItem",
    DamageBlockRemote = "DamageBlock",
    ReportRemote = "ReportPlayer",
    PickupRemote = "PickupItemDrop",
    CannonAimRemote = "AimCannon",
    CannonLaunchRemote = "LaunchSelfFromCannon",
    AttackRemote = "SwordHit",
    GuitarHealRemote = "PlayGuitar",
	EatRemote = "ConsumeItem",
	SpawnRavenRemote = "SpawnRaven",
	MageRemote = "LearnElementTome",
	DragonRemote = "RequestDragonPunch",
	ConsumeSoulRemote = "ConsumeGrimReaperSoul",
	TreeRemote = "ConsumeTreeOrb",
	PickupMetalRemote = "CollectCollectableEntity",
	BatteryRemote = "ConsumeBattery"
}
bedwars.getInventory = function(plr)
	local inv = {
		items = {},
		armor = {}
	}
	local repInv = plr.Character and plr.Character:FindFirstChild("InventoryFolder") and plr.Character:FindFirstChild("InventoryFolder").Value
	if repInv then
		if repInv.ClassName and repInv.ClassName == "Folder" then
			for i,v in pairs(repInv:GetChildren()) do
				if not v:GetAttribute("CustomSpawned") then
					table.insert(inv.items, {
						tool = v,
						itemType = tostring(v),
						amount = v:GetAttribute("Amount")
					})
				end
			end
		end
	end
	local plrInvTbl = {
		"ArmorInvItem_0",
		"ArmorInvItem_1",
		"ArmorInvItem_2"
	}
	local function allowed(char)
		local state = true
		for i,v in pairs(plrInvTbl) do if (not char:FindFirstChild(v)) then state = false end end
		return state
	end
	local plrInv = plr.Character and allowed(plr.Character)
	if plrInv then
		for i,v in pairs(plrInvTbl) do
			table.insert(inv.armor, tostring(plr.Character:FindFirstChild(v).Value) == "" and "empty" or tostring(plr.Character:FindFirstChild(v).Value) ~= "" and {
				tool = v,
				itemType = tostring(plr.Character:FindFirstChild(v).Value)
			})
		end
	end
	return inv
end
bedwars.StoreController = {}
function bedwars.StoreController:updateLocalInventory()
	store.localInventory.inventory = bedwars.getInventory(game:GetService("Players").LocalPlayer)
end
function bedwars.StoreController:updateStore()
	task.spawn(function() pcall(function() self:updateLocalInventory() end) end)
end
function bedwars.StoreController:fetchLocalHand()
	repeat task.wait() until game:GetService("Players").LocalPlayer.Character
	return game:GetService("Players").LocalPlayer.Character:FindFirstChild("HandInvItem")
end
function bedwars.StoreController:updateLocalInventory()
	store.localInventory.inventory = bedwars.getInventory(game:GetService("Players").LocalPlayer)
end
function bedwars.StoreController:updateBowConstantsTable(targetPos)
	bedwars.BowConstantsTable = getBowConstants(targetPos)
end
function bedwars.StoreController:updateStoreBlocks()
	store.blocks = collectionService:GetTagged("block")
end
function bedwars.StoreController:updateLocalHand()
	local currentHand = bedwars.StoreController:fetchLocalHand()
	if (not currentHand) then store.localHand = {} return end
	local handType = ""
	if currentHand and currentHand.Value and currentHand.Value ~= "" then
		local handData = bedwars.ItemTable[tostring(currentHand.Value)]
		handType = handData.sword and "sword" or handData.block and "block" or tostring(currentHand.Value):find("bow") and "bow"
	end
	store.localHand = {tool = currentHand and currentHand.Value, itemType = currentHand and currentHand.Value and tostring(currentHand.Value) or "", Type = handType, amount = currentHand and currentHand:GetAttribute("Amount") and type(currentHand:GetAttribute("Amount")) == "number" or 0}
end
bedwars.getKit = function(plr)
	return plr:GetAttribute("PlayingAsKit") or "none"
end
function bedwars.StoreController:updateEquippedKit()
	store.equippedKit = bedwars.getKit(game:GetService("Players").LocalPlayer)
end

task.spawn(function()
	repeat
		task.spawn(function() pcall(function() self:updateLocalHand() end) end)
		task.wait(0.1)
		task.spawn(function() pcall(function() self:updateLocalInventory() end) end)
		task.wait(0.1)
		task.spawn(function() pcall(function() self:updateEquippedKit() end) end)
		task.wait(0.1)
		task.spawn(function() pcall(function() self:updateStoreBlocks() end) end)
	until (not shared.VapeExecuted)
end)
local animm = [[
    ["rbxassetid://4947108314","rbxassetid://10218627926","rbxassetid://10218629442","rbxassetid://10214626638","rbxassetid://4866397461","rbxassetid://6955840280","rbxassetid://4968114448","rbxassetid://10218699239","rbxassetid://10218701944","rbxassetid://10218703519","rbxassetid://8089110185","rbxassetid://8089505302","rbxassetid://10217600036","rbxassetid://8089691925","rbxassetid://8089691925","rbxassetid://7137919839","rbxassetid://7138391787","rbxassetid://7138977483","rbxassetid://8091867276","rbxassetid://7084343749","rbxassetid://7084340549","rbxassetid://7191015002","rbxassetid://7192473967","rbxassetid://7228927934","rbxassetid://7265117930","rbxassetid://7265176148","rbxassetid://7265126872","rbxassetid://7279161624","rbxassetid://7344997658","rbxassetid://7303855489","rbxassetid://7316973269","rbxassetid://7303852773","rbxassetid://7333833151","rbxassetid://7333834312","rbxassetid://7333865905","rbxassetid://7378131388","rbxassetid://7377150622","rbxassetid://7341023369","rbxassetid://7341724549","rbxassetid://7341729415","rbxassetid://7344012158","rbxassetid://7344363114","rbxassetid://7612262880","rbxassetid://7612249925","rbxassetid://7612253494","rbxassetid://7612260842","rbxassetid://7612271230","rbxassetid://7612272806","http://www.roblox.com/asset/?id=2506281703","rbxassetid://7750810950","rbxassetid://7678634308","rbxassetid://7678967790","rbxassetid://7678633088","rbxassetid://7678631993","rbxassetid://7678964011","rbxassetid://7678965451","rbxassetid://7678969462","rbxassetid://7809672003","rbxassetid://7812099560","rbxassetid://7773364077","rbxassetid://7773360849","rbxassetid://7773351603","rbxassetid://7859839607","rbxassetid://8326193340","rbxassetid://8326199589","rbxassetid://8326203676","rbxassetid://9377667626","rbxassetid://9377657655","rbxassetid://9377674292","rbxassetid://7795775580","rbxassetid://7795772083","rbxassetid://7798913514","rbxassetid://7789127251","rbxassetid://7789132571","rbxassetid://7789135031","rbxassetid://7789129657","rbxassetid://7789136489","rbxassetid://7809644502","rbxassetid://7809648342","rbxassetid://7809652714","rbxassetid://7806878751","rbxassetid://7806875767","rbxassetid://7806877261","rbxassetid://7813383834","rbxassetid://7813386439","rbxassetid://12216367516","rbxassetid://12216363669","rbxassetid://8255572687","rbxassetid://7806877261","rbxassetid://8270473553","rbxassetid://8273509507","rbxassetid://8479223196","rbxassetid://13754082474","rbxassetid://8479246017","rbxassetid://13736781867","rbxassetid://8562696835","rbxassetid://8562796116","rbxassetid://8562798663","rbxassetid://8562805232","rbxassetid://8562802601","rbxassetid://8597637450","rbxassetid://8597631365","rbxassetid://8597640053","rbxassetid://8597635485","rbxassetid://8596310810","rbxassetid://8596308385","rbxassetid://8596315739","rbxassetid://8596304027","rbxassetid://8659050168","rbxassetid://8659055472","rbxassetid://8715973557","rbxassetid://8715969346","rbxassetid://8715970706","rbxassetid://8715971525","rbxassetid://8715972442","rbxassetid://8721453419","rbxassetid://8789340437","rbxassetid://8789342166","rbxassetid://8789343400","rbxassetid://8789346393","rbxassetid://8795210389","rbxassetid://8795211816","rbxassetid://8795213345","rbxassetid://8860291893","rbxassetid://8860294521","rbxassetid://15222797648","rbxassetid://8860301164","rbxassetid://8860304406","rbxassetid://8934264605","rbxassetid://9122876410","rbxassetid://9122874800","rbxassetid://9126974144","rbxassetid://9126971836","rbxassetid://7587254905","rbxassetid://7587251769","rbxassetid://9126968930","rbxassetid://9126966808","rbxassetid://9126964985","rbxassetid://9126960273","rbxassetid://9063819853","rbxassetid://9063824140","rbxassetid://9063825235","rbxassetid://9120877927","rbxassetid://9120876177","rbxassetid://9120874016","rbxassetid://9129166579","rbxassetid://9191822700","rbxassetid://9192502477","rbxassetid://9192537959","rbxassetid://9252905304","rbxassetid://9252906710","rbxassetid://9238708771","rbxassetid://9252414412","rbxassetid://9251904379","rbxassetid://10319683687","rbxassetid://9440191148","rbxassetid://9441258742","rbxassetid://9375413409","rbxassetid://9377290642","rbxassetid://9378575104","rbxassetid://9611598457","rbxassetid://9611595934","rbxassetid://9611593451","rbxassetid://9611590898","rbxassetid://9611589202","rbxassetid://9611585335","rbxassetid://9611580812","rbxassetid://9611583074","rbxassetid://7678964011","rbxassetid://9864852757","rbxassetid://9864865649","rbxassetid://9864868578","rbxassetid://9864856688","rbxassetid://9864862289","rbxassetid://9864849979","rbxassetid://15675488525","rbxassetid://15675496747","rbxassetid://15675501290","rbxassetid://15675479887","rbxassetid://15675505658","rbxassetid://15675512952","rbxassetid://9856698893","rbxassetid://9856685551","rbxassetid://9856683160","rbxassetid://9831602429","rbxassetid://9831598198","rbxassetid://9839531631","rbxassetid://9839883811","rbxassetid://9839886828","rbxassetid://9839888721","rbxassetid://9839890526","rbxassetid://9839891493","rbxassetid://9839892870","rbxassetid://9839895344","rbxassetid://9839898743","rbxassetid://9839901354","rbxassetid://9839903072","rbxassetid://9839904507","rbxassetid://9839906716","rbxassetid://9867544534","rbxassetid://9867542874","rbxassetid://10136680169","rbxassetid://10136690461","rbxassetid://10136683575","rbxassetid://10136686823","rbxassetid://10136696418","rbxassetid://10136708060","rbxassetid://17506421726","rbxassetid://17506149751","rbxassetid://17506140931","rbxassetid://17506145936","rbxassetid://17506191573","rbxassetid://17585445034","rbxassetid://17506444952","rbxassetid://17506428930","rbxassetid://17506439072","rbxassetid://17506432318","rbxassetid://10012798975","rbxassetid://10012801384","rbxassetid://10012803390","rbxassetid://10012807780","rbxassetid://10012809666","rbxassetid://10013028800","rbxassetid://10265861814","rbxassetid://10265860371","rbxassetid://10265859074","rbxassetid://10265857584","rbxassetid://10218627926","rbxassetid://10214980235","rbxassetid://10482596209","rbxassetid://10562148548","rbxassetid://10715396337","rbxassetid://10715398768","rbxassetid://10725339583","rbxassetid://10725343381","rbxassetid://10725374175","rbxassetid://10727303147","rbxassetid://10727311989","rbxassetid://10797836355","rbxassetid://10839556043","rbxassetid://10929821826","rbxassetid://10929823776","rbxassetid://10330414101","rbxassetid://10974619315","rbxassetid://10974620511","rbxassetid://10967393413","rbxassetid://10968521285","rbxassetid://10968517527","rbxassetid://10968519485","rbxassetid://10967390363","rbxassetid://10967393413","rbxassetid://10967403161","rbxassetid://10967408759","rbxassetid://10971149413","rbxassetid://10971167460","rbxassetid://10967395596","rbxassetid://10967398521","rbxassetid://10967430892","rbxassetid://10967424821","rbxassetid://10993451841","rbxassetid://10993447503","rbxassetid://10993441429","rbxassetid://507777826","rbxassetid://507766666","rbxassetid://11337797621","rbxassetid://11337806332","rbxassetid://11330409797","rbxassetid://11168690401","rbxassetid://11170471222","rbxassetid://11170405197","rbxassetid://11334031737","rbxassetid://11332572784","rbxassetid://11332580758","rbxassetid://11332794283","rbxassetid://88484764881675","rbxassetid://11344417710","rbxassetid://11349370934","rbxassetid://11351296209","rbxassetid://10151942122","rbxassetid://11335317741","rbxassetid://11335944308","rbxassetid://11335939861","rbxassetid://11335946098","rbxassetid://11335948044","rbxassetid://11335949902","rbxassetid://11335952059","rbxassetid://11335957099","rbxassetid://15109633819","rbxassetid://15109104048","rbxassetid://15163965120","rbxassetid://11359358843","rbxassetid://11359361472","rbxassetid://11360820470","rbxassetid://11360828906","rbxassetid://11360825341","rbxassetid://11360393656","rbxassetid://11360465649","rbxassetid://11360590199","rbxassetid://11466075174","rbxassetid://11466087489","rbxassetid://11466089949","rbxassetid://15579059113","rbxassetid://15579056095","rbxassetid://15579051768","rbxassetid://11589224081","rbxassetid://11589229922","rbxassetid://11589228216","rbxassetid://11589599080","rbxassetid://11638653144","rbxassetid://11639024720","rbxassetid://11648222146","rbxassetid://11648236162","rbxassetid://11648231227","rbxassetid://11656790607","rbxassetid://11656802136","rbxassetid://11656804453","rbxassetid://11656807830","rbxassetid://11656810237","rbxassetid://11656813294","rbxassetid://11716391954","rbxassetid://11527150810","rbxassetid://11527152902","rbxassetid://13786964487","rbxassetid://10003881960","rbxassetid://507767968","rbxassetid://11710365271","rbxassetid://11710363907","rbxassetid://11710365271","rbxassetid://11710363907","rbxassetid://11662833571","rbxassetid://11662830694","rbxassetid://11815458908","rbxassetid://11816922699","rbxassetid://11823544087","rbxassetid://11824356500","rbxassetid://11824358904","rbxassetid://11824362467","rbxassetid://11825470206","rbxassetid://11825471805","rbxassetid://11825472952","rbxassetid://11812561836","rbxassetid://11812574266","rbxassetid://11812571469","rbxassetid://11812576446","rbxassetid://11812578981","rbxassetid://11812581749","rbxassetid://11812584056","rbxassetid://11812586078","rbxassetid://507767714","rbxassetid://9192502477","rbxassetid://11893779759","rbxassetid://11893785331","rbxassetid://11893818911","rbxassetid://11893821398","rbxassetid://11893824273","rbxassetid://9311866246","rbxassetid://12368592771","rbxassetid://12368609498","rbxassetid://12368612047","rbxassetid://12368614859","rbxassetid://12492151702","rbxassetid://12510093671","rbxassetid://12253267408","rbxassetid://12253346018","rbxassetid://12270960897","rbxassetid://12504555509","rbxassetid://12504557705","rbxassetid://12504552202","rbxassetid://12504553779","rbxassetid://12516697532","rbxassetid://12511655326","rbxassetid://12503692071","rbxassetid://12503688334","rbxassetid://12503685427","rbxassetid://12503682277","rbxassetid://12503677635","rbxassetid://12503673154","rbxassetid://12510308591","rbxassetid://12510310149","rbxassetid://12511988691","rbxassetid://12662217125","rbxassetid://12949904445","rbxassetid://12950368130","rbxassetid://12955846975","rbxassetid://13200058714","rbxassetid://13200066664","rbxassetid://13200070355","rbxassetid://13350768596","rbxassetid://13417977042","rbxassetid://13421598314","rbxassetid://13421630105","rbxassetid://13421635091","rbxassetid://13421344632","rbxassetid://13421343360","rbxassetid://13421339706","rbxassetid://13421342038","rbxassetid://13610595617","rbxassetid://13623697534","rbxassetid://13628273032","rbxassetid://13884869899","rbxassetid://13836234644","rbxassetid://13816190401","rbxassetid://13816207519","rbxassetid://13816205964","rbxassetid://13802531000","rbxassetid://13816174473","rbxassetid://13802569648","rbxassetid://13816181777","rbxassetid://13802533099","rbxassetid://13802574645","rbxassetid://13802534928","rbxassetid://13802577117","rbxassetid://13836107195","rbxassetid://13802346346","rbxassetid://13802354449","rbxassetid://13802341021","rbxassetid://13802789440","rbxassetid://13802501742","rbxassetid://13802503894","rbxassetid://13802360949","rbxassetid://13803017609","rbxassetid://14818394124","rbxassetid://14818397096","rbxassetid://14818399271","rbxassetid://14818401399","rbxassetid://14832098691","rbxassetid://14826593808","rbxassetid://14818405595","rbxassetid://14818409727","rbxassetid://14818415238","rbxassetid://14818419608","rbxassetid://14818421228","rbxassetid://14825327321","rbxassetid://14826597599","rbxassetid://14818426667","rbxassetid://13824362377","rbxassetid://13824360571","rbxassetid://13824356126","rbxassetid://13832610521","rbxassetid://15292880207","rbxassetid://15372698690","rbxassetid://13832407332","rbxassetid://13959281720","rbxassetid://13972301190","rbxassetid://13972258051","rbxassetid://13972245244","rbxassetid://13972247211","rbxassetid://13972266676","rbxassetid://13989576556","rbxassetid://13989476808","rbxassetid://14144204917","rbxassetid://14221445556","rbxassetid://14222068655","rbxassetid://14313448583","rbxassetid://14556323386","rbxassetid://14648342674","rbxassetid://14648347760","rbxassetid://14648357130","rbxassetid://14648353797","rbxassetid://15342016105","rbxassetid://15341993477","rbxassetid://15342001399","rbxassetid://15342109976","rbxassetid://15342010246","rbxassetid://15342163947","rbxassetid://15342013373","rbxassetid://15342019329","rbxassetid://15342166957","rbxassetid://15342112880","rbxassetid://15342116373","rbxassetid://15342119259","rbxassetid://15342124234","rbxassetid://15342121878","rbxassetid://15342106884","rbxassetid://15343508494","rbxassetid://15343510655","rbxassetid://15343513048","rbxassetid://15343515033","rbxassetid://15343518839","rbxassetid://15343520959","rbxassetid://15343522927","rbxassetid://15038446169","rbxassetid://15047198064","rbxassetid://15049027475","rbxassetid://15049043717","rbxassetid://15049046389","rbxassetid://15156484047","rbxassetid://15156482547","rbxassetid://15156533711","rbxassetid://15156534608","rbxassetid://15156535781","rbxassetid://15156536793","rbxassetid://15115197929","rbxassetid://15115193168","rbxassetid://15373991191","rbxassetid://15380788448","rbxassetid://15380793354","rbxassetid://15380806336","rbxassetid://15372298978","rbxassetid://15373974499","rbxassetid://15372579955","rbxassetid://15374022218","rbxassetid://15375664237","rbxassetid://15300633633","rbxassetid://15300635527","rbxassetid://15300627661","rbxassetid://9192537959","rbxassetid://8089691925","rbxassetid://15289979546","rbxassetid://15289984121","rbxassetid://15289986084","rbxassetid://15289993610","rbxassetid://15289994986","rbxassetid://15289996167","rbxassetid://15516100146","rbxassetid://15516831003","rbxassetid://15516838704","rbxassetid://15547022986","rbxassetid://70553236950121","rbxassetid://15626237284","rbxassetid://15635399688","rbxassetid://15635395428","rbxassetid://15635401689","rbxassetid://15635101063","rbxassetid://15635104702","rbxassetid://15635092718","rbxassetid://15635090186","rbxassetid://15635098249","rbxassetid://15635082747","rbxassetid://15635095855","rbxassetid://15718553150","rbxassetid://15718571472","rbxassetid://15718712635","rbxassetid://16103041428","rbxassetid://16041084761","rbxassetid://16121171382","rbxassetid://16121154921","rbxassetid://16121259239","rbxassetid://15957298650","rbxassetid://18940347665","rbxassetid://16188995989","rbxassetid://16207610278","rbxassetid://16189090932","rbxassetid://16207657266","rbxassetid://16213950809","rbxassetid://16213931417","rbxassetid://16213911098","rbxassetid://16078348649","rbxassetid://16078431456","rbxassetid://15957012743","rbxassetid://15957613199","rbxassetid://16021243563","rbxassetid://16027355800","rbxassetid://16027386258","rbxassetid://16345791610","rbxassetid://16345780403","rbxassetid://16345772684","rbxassetid://16345766142","rbxassetid://16345756467","rbxassetid://16346536576","rbxassetid://16212495993","rbxassetid://16212561014","rbxassetid://16212583504","rbxassetid://16189206250","rbxassetid://16189197150","rbxassetid://16211215341","rbxassetid://16380995701","rbxassetid://16380586221","rbxassetid://16747376157","rbxassetid://16747309833","rbxassetid://17020362631","rbxassetid://17020611181","rbxassetid://17020658915","rbxassetid://17020673038","rbxassetid://17020683826","rbxassetid://16988700808","rbxassetid://16911464220","rbxassetid://16911455174","rbxassetid://16988737597","rbxassetid://16911515194","rbxassetid://17013515016","rbxassetid://16992904279","rbxassetid://16992948586","rbxassetid://16993146387","rbxassetid://17005373942","rbxassetid://17005443950","rbxassetid://17005452651","rbxassetid://17005474564","rbxassetid://17005478049","rbxassetid://17014392466","rbxassetid://17014694332","rbxassetid://17014685680","rbxassetid://17015088549","rbxassetid://17014679185","rbxassetid://17020293078","rbxassetid://17163673526","rbxassetid://17185654263","rbxassetid://17185645880","rbxassetid://17591748964","rbxassetid://17293524766","rbxassetid://17293533214","rbxassetid://17293541753","rbxassetid://17373180147","rbxassetid://17591550344","rbxassetid://17591546665","rbxassetid://4866397461","rbxassetid://6322507715","rbxassetid://17758860662","rbxassetid://17850691818","rbxassetid://18187673414","rbxassetid://18187704330","rbxassetid://18187713599","rbxassetid://18187808211","rbxassetid://18187816162","rbxassetid://17822066122","rbxassetid://17821817836","rbxassetid://17821814805","rbxassetid://18100843503","rbxassetid://18139176774","rbxassetid://18139286974","rbxassetid://18139371341","rbxassetid://18139449632","rbxassetid://18139544207","rbxassetid://18139594250","rbxassetid://18141262865","rbxassetid://18141277227","rbxassetid://18141308820","rbxassetid://18141337961","rbxassetid://18141323810","rbxassetid://18141344315","rbxassetid://18235278774","rbxassetid://18307432586","rbxassetid://18940311157","rbxassetid://18940338338","rbxassetid://18822231397","rbxassetid://18822223933","rbxassetid://18880977516","rbxassetid://18881167004","rbxassetid://18881170678","rbxassetid://18964803587","rbxassetid://18952573846","rbxassetid://18952568667","rbxassetid://18962872942","rbxassetid://18962876225","rbxassetid://18962879498","rbxassetid://18962883152","rbxassetid://18962915587","rbxassetid://18962924858","rbxassetid://18962932742","rbxassetid://18962941706","rbxassetid://18963527757","rbxassetid://18943653074","rbxassetid://18963741484","rbxassetid://18964634583","rbxassetid://18928303535","rbxassetid://134416898758421","rbxassetid://134306887202419","rbxassetid://97382046467034","rbxassetid://122034773281447","rbxassetid://126369484455062","rbxassetid://118007103075909","rbxassetid://129661520644579","rbxassetid://71609703089093","rbxassetid://74367792804542","rbxassetid://86374982002713","rbxassetid://117720097980326","rbxassetid://106289341191484","rbxassetid://91329846793280","rbxassetid://98422622290835","rbxassetid://84290882560174","rbxassetid://507777826","rbxassetid://507766666","rbxassetid://75965507114292","rbxassetid://134857617320911","rbxassetid://70420955912162","rbxassetid://121080822791176","rbxassetid://134808073555309","rbxassetid://131430116235084","rbxassetid://80489674772960","rbxassetid://127623781341268","rbxassetid://136187952457531","rbxassetid://87659811570826","rbxassetid://73009470190911","rbxassetid://140013801772699","rbxassetid://98170422286148","rbxassetid://80732866421916","rbxassetid://128159993860890","rbxassetid://75048305578239","rbxassetid://7050488867","rbxassetid://98931972253729","rbxassetid://82125911338262","rbxassetid://104161606057057","rbxassetid://140300979233839","rbxassetid://86112745890624"]
]]
local animtype = [[
    {"GLUE_TRAP_CHARGING_ALERTED":303,"PUNCH":5,"SWORD_SWING_3":4,"WINTER_BOSS_DEATH":342,"PINATA_HIT_2":222,"ELK_CHARGING":180,"BEAR_CLAWS_SWIPE":156,"FP_HANDS_RUNNING_HEAD":298,"CHEERS_BOTTLE":379,"GREAT_HAMMER_CHARGED_SWING":416,"PISTOL_IDLE":135,"KNIFE_1":324,"SCYTHE_SLASH_1_FP":407,"ROBLOX_DEFAULT_FREEFALL":325,"AXOLOTL_SWIM":61,"FP_HOLD":11,"TURTLE_IDLE":619,"DIAMOND_GUARDIAN_ATTACK_2":369,"TARGET_DUMMY_RANGED_ATTACK":530,"SLOW_CLAP":380,"CARD_THROW":442,"PINATA_FEED":223,"VOID_DRAGON_IDLE":256,"DRAGON_SWORD_ULT_FP":542,"GOLDEN_GOOSE_SCARED":479,"MERCHANT_CURTAIN_OPEN":389,"CHICKEN_RUN":444,"SKELETON_SPAWN":267,"KNEEL_DOWN":601,"DROPPED_THIS_KING":592,"PARTY_UP":141,"KEEPER_SPAWN":271,"GOLEM_BOSS_HAMMER_SLAM":375,"EAGLE_RECOIL":580,"GRIM_REAPER_DEAD_TO_ME_EMOTE":608,"GOLDEN_GOOSE_LAY_EGG":478,"HEAVENLY_SWORD_SWING":164,"VOID_DRAGON_FLYING":258,"ROCK_PAPER_SCISSORS":183,"CRAB_BOSS_WALK":468,"REPAIR_ENCHANT_TABLE":88,"WINTER_BOSS_SLAM_AXE":345,"WIZARD_LIGHTNING_CAST":25,"SWORD_IDLE":0,"HARPOON_RETURN":609,"CRAB_BOSS_DIG_UP":465,"GLUE_TRAP_IDLE":300,"PENGUIN_KILL_EFFECT_3":523,"STAR_ITEM_CONSUME":187,"FP_HANNAH_ATTACK":238,"LARGE_FALL_2":294,"GHOST_IDLE":79,"SCYTHE_PULL_1":411,"LASER_SWORD_SWING_1":328,"PISTOL_SHOOT":134,"TARGET_DUMMY_DAMAGED":525,"PIRATES_GOODBYE":233,"FP_CROSSBOW_AIM":16,"PALADIN_LAND":269,"STAR_RANDOM_SPIN":186,"EAGLE_DIVE":578,"FP_CARROT_CANNON_IDLE":139,"PENGUIN_JUMP_2":205,"HALLOWEEN_BOSS_CAST":281,"WIZARD_BALL_CAST":26,"WARLOCK_IDLE":487,"JUGGERNAUT_ATTACK_3_FP":319,"ENCHANT_TABLE_GLITCHED_IDLE":242,"MINER_MINE_STONE":129,"PLAYER_VACUUM_SUCK":169,"SEAHORSE_SWIM_LOOP":355,"HARPOON_ATTACK_START":613,"ELK_IDLE":179,"SKELETON_WALK":263,"CROSSBOW_AIM":127,"SHIELD_SWORD_IDLE":457,"WINTER_BOSS_RUN":349,"CRAB_HEAD_SCRATCH":629,"FP_INFERNO_SWORD_SPIN":166,"ANGEL_WINGS_WINGS_IDLE":596,"RAPIER_THRUST_1":548,"GAUNTLETS_HOOK_1ST":431,"TARGET_DUMMY_ALERT":527,"BEACH_VACATION":184,"CURSED_COFFIN_RESPAWN":482,"FP_TWIRLBLADE_ATTACK_1":121,"OIL_SPIT":85,"BOOK_READ":260,"JUGGERNAUT_LEAP_FP":312,"ROCK_OUT":140,"TENNIS_RACKET_IDLE":229,"SCYTHE_SLASH":95,"BOBA_BLASTER_FIRE":149,"HANNAH_ATTACK":237,"WIZARD_ABILITY_SWITCH":27,"GAUNTLETS_CHARGE_SUPER_PUNCH":427,"VACUUM_STARTUP":56,"GRAVEYARD_DIG":277,"PLACE_BLOCK":606,"INFERNAL_SHIELD_CHARGE":385,"JUGGERNAUT_ATTACK_1_FP":317,"WINTER_BOSS_SPAWN":347,"JELLY_SQUISH":90,"OWL_GRAB":359,"CRAB_BOSS_STAB_50":469,"FP_JAILOR_IMPRISON":331,"GLUE_TRAP_CHARGING":302,"GLUE_TRAP_FLYING":299,"PINATA_IDLE_3":220,"USE_CROSS":270,"ZEN_HOVER":262,"FISHING_ROD_PULLING":75,"FLYING_CLOUD_IDLE":399,"EATING_POPCORN":496,"WINTER_BOSS_IDLE":343,"SCYTHE_SLASH_2":406,"CRAB_BOSS_FLIP_GROUND":466,"GAUNTLETS_IDLE":428,"TALL_PENGUIN_WALK":103,"FLAMETHROWER_USE":31,"JUGGERNAUT_ATTACK_1":314,"ANGEL_WINGS_PLAYER_FLY":598,"SCYTHE_SPIN":409,"FROSTY_HAMMER_1":335,"FP_HANDS_RUNNING":292,"JUGGERNAUT_SPIN":307,"GOODNIGHT_DANCE":638,"FP_SPEAR_STAB":659,"HEADHUNTER_SHOOT_FP":394,"FP_TWIRLBLADE_ATTACK_SPIN":123,"FROSTY_HAMMER_3_FP":340,"SNAP_TRAP_CLOSE":71,"CHICKEN_JUMP":447,"SUMMONER_DRAGON_ATTACK":633,"NET_CATCH":37,"FP_SLEDGEHAMMER_SWING":322,"SUMMON_SNOW":520,"DAGGER_SWING_2":402,"SEAHORSE_SPAWN":354,"PAINT_SHOTGUN_SHOOT":130,"HEADHUNTER_AIM":395,"VOID_DRAGON_BREATH":253,"GAUNTLETS_IDLE_1ST":435,"ELK_WALKING":176,"ELK_FALLING":177,"FP_HANDS_RUNNING_RIGHT_ARM":297,"DODO_BIRD_WALK":44,"SPIDER_QUEEN_IDLE_AGGRO":685,"SPIDER_BOSS_SPIN":664,"VOID_DRAGON_BREATH_FIRE":255,"FP_EQUIP":13,"DODO_BIRD_SQUAWK":48,"RAVEN_SPAWN":34,"BUILDER_HAMMER_HIT":6,"FP_SWING_SWORD":15,"WARLOCK_CHARGE_UP":490,"FROSTY_HAMMER_3":337,"AXOLOTL_EASTER_ABILITY":69,"USE_GRAVESTONE":266,"FP_HEAVENLY_SWORD_SWING":165,"ENCHANT_TABLE_LOOP":91,"SPIRIT_ASSASSIN_KILL_EFFECT_GHOST_2":558,"NINJA_RUN":515,"FLAMETHROWER_IDLE":30,"TINKER_FALL":587,"DUCK_ATTACK":113,"SAW_ATTACK_2":383,"FROSTY_HAMMER_2_FP":339,"TARGET_DUMMY_DEATH":526,"GRENADE_THROW":54,"WIGGLE":182,"LUCKY_BOX_OPEN":356,"AXOLOTL_EASTER_SWIM":68,"TINKER_ATTACK":583,"BIG_PENGUIN_WALK":107,"DRAGON_SLAYER_PUNCH":247,"FP_WALK":19,"LASSO_CHARGE":22,"BOW_DRAW":126,"RAVEN_HOLD":38,"CHARGED_HAMMER_SWING":323,"JUGGERNAUT_SPIN_FP":313,"TALL_PENGUIN_JUMP":104,"CARROT_CANNON_IDLE":137,"CLASSIC_PENGUIN_WALK":209,"ROCKET_LAUNCHER_SHOT":51,"SHEEP_IDLE":145,"GOLD_FISH_SWIM":655,"GRAVEYARD_JUMP":278,"TRAPPER_SLASH":72,"OWL_SHOOT":358,"SPIDER_IDLE":486,"SPIRIT_ASSASSIN_SPIN_EMOTE":555,"HARPOON_VICTIM_STUN":610,"HALLOWEEN_ALTAR_LOOP":289,"SWORD_SWING_2":3,"CRAB_BOSS_DEATH":463,"TRIUMPH_STATUE_3":645,"SPEAR_IDLE":82,"COMET_VOLLEY_SHOOTING_TO_FALLING_TRANSITION":536,"TAME_SHEEP":146,"HALLOWEEN_RAVEN_FLIGHT":280,"CRAB_BOSS_STAB_130":471,"SIDE_TO_SIDE":142,"HALLOWEEN_BOSS_WAVE":287,"CLASSIC_PENGUIN_SMALL_ATTACK":212,"PINATA_IDLE_2":219,"DRAGON_SWORD_FIRE":543,"SHEEP_JUMP":144,"CHEST_OPEN":96,"SHEEP_WALK":143,"CHICKEN_FLAP":448,"CARROT_CANNON_SHOOT":136,"HALLOWEEN_ALTAR_SKULL_ROTATE":288,"PINATA_HIT_1":221,"CRAB_BOSS_BARRAGE_ATTACK":461,"DEFAULT_SPIDER_LOOKING":668,"AXOLOTL_ABILITY":62,"FP_DAGGER_SLASH":227,"SHOVEL_DIG":160,"DRAGON_SLAYER_LAUNCH_IMPACT":249,"WINTER_BOSS_DASH_ATTACK":341,"BEAR_CLAWS_FLURRY":157,"DISMANTLE_KILL_EFFECT_UPPER":635,"KNIGHT_SHIELD_RAISE_SHIELD":689,"FUNKY_DANCE":639,"FP_CARROT_CANNON_SHOOT":138,"SWORD_SWING":1,"USE_TABLET":28,"LARGE_FALL_3":295,"GREAT_HAMMER_SWING_2":415,"GOLDEN_GOOSE_IDLE":477,"SHIELD_SWORD_WALKING":456,"NORMAL_PENGUIN_IDLE":98,"EQUIP_3":10,"FIRE_SHEEP_ATTACK":363,"VOID_DRAGON_BREATH_CHARGE":254,"VOID_PORTAL_IDLE":200,"DINO_IDLE":175,"LASER_SWORD_SWING_3RD_PERSON_2":326,"CRAB_BOSS_IDLE":460,"DRAGON_BREATH":245,"HALLOWEEN_BOSS_IDLE":284,"TOURNAMENT_WINNER":662,"HALLOWEEN_BOSS_SUMMON":286,"THROW_CHICKEN":449,"VOID_CRAB_RIGHT_ATTACK":191,"KNIGHTS_BOW":261,"MERCHANT_WAGON_IDLE":390,"CRAB_BOSS_STAB_90":470,"GREAT_HAMMER_SWING_2_FP":419,"GATHER_BOT_WALK_CARRY_ITEM":501,"ENCHANT_TABLE_GLITCHED_ACTION":241,"GAUNTLETS_SUPER_PUNCH_1ST":433,"SPIRIT_ASSASSIN_AD":155,"SNIPER_PENGUIN_SHOOT_2":206,"FLAMETHROWER_UPGRADE":32,"CRAB_BOSS_SPAWN":467,"YETI_ROAR":89,"DAGGER_SWING_1":401,"TWIRLBLADE_ATTACK_2":118,"FP_PAINT_SHOTGUN_SHOOT":132,"HOLD_CHICKEN":450,"CRAB_BOSS_STAB_270":473,"ROBLOX_DEFAULT_IDLE":672,"PENGUIN_ATTACK_2":202,"TINKER_PLACE_BLOCK":589,"TINKER_JUMP":586,"TWIRLBLADE_ATTACK_IDLE":120,"VOID_DRAGON_WING_TRANSFORM":252,"FISHING_ROD_CAST":73,"RIFT_REVIVE":279,"SCYTHE_PULL":93,"VOID_DRAGON_TRANSFORM":259,"DINO_WALKING":170,"FORGE":400,"SCISSOR_SWORD_SWING_1":553,"GAUNTLETS_UPPERCUT":425,"VACUUM_IDLE":57,"SPEAR_STARTUP":83,"DRAGON_FLYING":244,"SPIDER_WEBBED":483,"GLUE_TRAP_JUMP":301,"WIZARD_LIGHTNING_STRIKE_CAST":388,"JUGGERNAUT_GROUND_STAB_FP":311,"SPIDER_QUEEN_WEB_SPRAY":687,"FROSTY_HAMMER_2":336,"LUXURY_CHAIR":437,"AXOLOTL_SPIN":63,"DIAMOND_GUARDIAN_MOVE":367,"KEEPER_IDLE":272,"DIAMOND_GUARDIAN_IDLE":366,"GAUNTLETS_JAB":422,"OIL_EAT":84,"CLASSIC_WIZARD_PENGUIN_IDLE":216,"FP_TWIRLBLADE_ATTACK_2":122,"CHARGE_SHIELD_CHARGE":50,"JADE_HAMMER_IDLE":39,"TWIRLBLADE_ATTACK_SPIN":119,"BIG_PENGUIN_JUMP":108,"EQUIP_1":8,"SCYTHE_SLASH_1":405,"JUGGERNAUT_ATTACK_3":316,"NINJA_THROW_CHAKRAM_RIGHT":516,"JUGGERNAUT_PULL_SWORD":305,"GAUNTLETS_CROSS":423,"TENNIS_RACKET_HIT":228,"NORMAL_PENGUIN_ATTACK":97,"GREAT_HAMMER_CHARGED_SWING_FP":420,"SPIDER_GUARD_SHOOT":678,"PARTY_POPPER_HOLD":350,"STATUE":41,"FISHING_ROD_CATCH_SUCCESS":77,"HANG_GLIDER_ARM":87,"WINTER_BOSS_SLAM_FRONT":346,"HALLOWEEN_WREN_COFFIN_OPEN_CLOSE":694,"KNIGHT_SHIELD_THIRD_PERSON_BASH":693,"KNIGHT_SHIELD_FP_BASH":692,"BLASTING_OFF_AGAIN_0":571,"KNIGHT_SHIELD_FP_DEFEND":691,"RAVEN_LOOP":33,"KNIGHT_SHIELD_FP_GUARD_DOWN":690,"REPAIR_SNOW_CONE_MACHINE":230,"LASER_SWORD_SWING_3RD_PERSON_1":327,"TRIUMPH_STATUE_2_FRAME":648,"SPIDER_QUEEN_LANDING":686,"SPEAR_CHARGE_1":656,"SPIDER_QUEEN_IDLE":684,"AXOLOTL_EASTER_IDLE":67,"GOLEM_BOSS_FIST_SLAM":376,"GOLEM_BOSS_IDLE":372,"BROOM_SWEEP":441,"SILLY_LEGS_DANCE":594,"FP_HANDS_IDLE":291,"SPIDER_QUEEN_WEB_CAST_SKY":682,"ROCKET_LAUNCHER_IDLE":53,"SPIDER_GUARD_DEATH":680,"EAT":7,"SPIDER_GUARD_PULL":679,"GRIDDY":637,"KICK_1":510,"WARRIOR_SPIDER_ATTACK_2":676,"TORNADO_LAUNCHER_HOLD":150,"SLIME_TAMER_FLUTE_USE":507,"REBELLION_POINT_SWORD":652,"FP_USE_ITEM":14,"MINING_FP":674,"VOID_DRAGON_RUNNING":257,"GOLEM_BOSS_SPAWN":371,"INFERNAL_SHIELD_LEAP":386,"MINING":673,"STAR_IDLE":185,"ROBLOX_DEFAULT_WALK":671,"DEFAULT_SPIDER_IDLE":670,"DEFAULT_SPIDER_SCRATCHING":669,"SCYTHE_SLASH_2_FP":408,"HALLOWEEN_BOSS_DEATH":283,"DEFAULT_SPIDER_DANCE":666,"TURTLE_HEAD_SCRATCH":623,"BLASTING_OFF_AGAIN_4":575,"RAPIER_THRUST_2":549,"WARLOCK_FORWARD_CAST":489,"DEFAULT_SPIDER_WALK":665,"PICKAXE_SWORD":663,"GAUNTLETS_CROSS_1ST":430,"SPRING_PUNCH_ATTACK":661,"GHOST_FLIP":78,"SAW_ATTACK":382,"NIGHTMARE_LOOP":147,"POGO_STICK_MOUNT":660,"FP_SPEAR_CHARGE":658,"COMET_VOLLEY_TARGETING_IDLE":537,"CLASSIC_WIZARD_PENGUIN_ATTACK":217,"DINO_HIT":173,"CLASSIC_PENGUIN_IDLE":210,"MELODY_ROCKSTAR_AD":154,"SWORD_SWING_1":2,"DAGGER_SWING_FP":404,"REBELLION_FORWARD":653,"WARRIOR_SPIDER_ATTACK_1":675,"SKELETON_IDLE":264,"SPIRIT_ASSASSIN_KILL_EFFECT_GHOST_3":559,"TRIUMPH_STATUE_3_FRAME":649,"SPIDER_QUEEN_DEATH":688,"TRIUMPH_STATUE_1_FRAME":647,"TRIUMPH_STATUE_4":646,"TRIUMPH_STATUE_2":644,"VOID_CRAB_WALKING":199,"COMET_VOLLEY_ASCEND":534,"ALCHEMY_CIRCLE_KILL_EFFECT":642,"RAVEN_ATTACK_KILL_EFFECT":641,"SEAHORSE_IDLE_LOOP":352,"SWORD_TWIRL":640,"SPITTER_SPIT":677,"WINTER_BOSS_RAISE_AXE":344,"JUGGERNAUT_ATTACK_2":315,"COMET_VOLLEY_FALLING":535,"MERCHANT_IDLE":391,"DISMANTLE_KILL_EFFECT_LOWER":636,"SUMMONER_CLAW_ATTACK":634,"CRAB_DANCE_EMOTE":632,"SIT_ON_DODO_BIRD":49,"DRILL_SPIN_LOOP":384,"ICY_DELIGHT":631,"LASER_SWORD_SWING_2":329,"CRAB_HEAD_SWAY":628,"FACE_PALM":436,"GOLDEN_GOOSE_GLIDE":476,"GATHER_BOT_CONSTRUCTION":499,"CLASSIC_TNT_PENGUIN_ATTACK":214,"CRAB_IDLE":625,"DIAMOND_GUARDIAN_ATTACK_1":368,"TURTLE_DANCE":624,"TURTLE_HEAD_SWAY":622,"DAGGER_CHARGE":224,"PENGUIN_WALK_2":203,"TURTLE_WALK":620,"GAUNTLETS_UPPERCUT_1ST":432,"JELLYFISH_IDLE":615,"JELLYFISH_MOUNT_IDLE":618,"JELLYFISH_SPAWN":617,"SNAP_TRAP_SETUP":70,"PALADIN_JUMP":268,"JELLYFISH_ATTACK":616,"SLEDGEHAMMER_SWING":321,"EASTER_BUNNY_EMOTE_BUNNY":159,"HARPOON_STTACK":614,"HARPOON_HANG_IDLE":612,"HARPOON_HANG":611,"JUGGERNAUT_ATTACK_2_FP":318,"DODO_BIRD_JUMP":45,"FLOAT_AWAY_LOOP":605,"FLOAT_AWAY_HIT":604,"ELEKTRA_DASH":603,"KNEEL_IDLE":602,"LARGE_FALL_1":293,"HANNAH_JUMP_DOWN":234,"CONGA_DANCE":599,"CLASSIC_SNIPER_PENGUIN_ATTACK":213,"BARBARIAN_RAGEBLADE_MASTER":455,"ANGEL_WINGS_PLAYER_IDLE":597,"HEAVEN_ASCEND":595,"DROPPED_THIS_KING_LONG":593,"PUSH_UP_GLASSES":591,"DAO_CHARGE":109,"TINKER_HEAVY_ATTACK":590,"TALL_PENGUIN_ATTACK":101,"TINKER_BREAK_BLOCK":588,"DRAGON_MORTAR_GET_UP":562,"GAUNTLETS_CHARGE_SUPER_PUNCH_1ST":434,"TINKER_AIM":585,"TINKER_IDLE":584,"BOOMERANG_THROW":519,"MENDING_CANOPY_CHARGE":581,"NINJA_THROW_CHAKRAM_LEFT":517,"DODO_BIRD_FALL":46,"EAGLE_ATTACK":579,"KEEPER_ATTACK":274,"EAGLE_WING_FLAP":577,"EAGLE_SOAR":576,"FP_DAGGER_CHARGE":226,"GUITAR_HEAL":21,"GRIM_REAPER_CONSUME":24,"COIN_TOSS":239,"AXOLOTL_REINDEER_SWIM":65,"BLASTING_OFF_AGAIN_2":573,"HEADHUNTER_SHOOT":393,"BLASTING_OFF_AGAIN_1":572,"GREAT_HAMMER_SWING_1_FP":418,"EGG_HUNT_GOLDEN_GOOSE_DANCE":569,"MAP_TROPHY_HOLD":568,"BOW_FIRE":125,"MAP_TROPHY_THROW":567,"DRAGON_KILL_EFFECT":566,"CELEBRATION":565,"KNEEL_UP":600,"QUEEN_BEE_FLOAT":381,"DRAGON_MORTAR_FIRE":563,"DRAGON_MORTAR_SETUP":561,"TRAIN_ENGINE_LOOP":531,"OWL_INTERACTION":362,"GAUNTLETS_HOOK":424,"JAILOR_IMPRISON":330,"HANG_GLIDER_BODY":86,"WARLOCK_ENTER_SCENE":491,"HALLOWEEN_BOSS_SPAWN":285,"BEE_FLAP":36,"VOID_CRAB_CLEANING":197,"DRAGON_SMASH_1":545,"SEARCHING_FAR_AWAY":232,"FROSTY_HAMMER_1_FP":338,"TRIUMPH_STATUE_4_FRAME":650,"SPIRIT_ASSASSIN_KILL_EFFECT_GHOST_1":557,"SCYTHE_SPIN_FP":410,"SPIRIT_ASSASSIN_KILL_EFFECT_PLAYER":556,"FROSTY_HAMMER_UPGRADE":333,"NORMAL_PENGUIN_JUMP":100,"DAVEY_JUMP_DOWN":235,"SCYTHE_SWING":94,"WAND_CAST":551,"CROSSBOW_FIRE":128,"NORMAL_PENGUIN_WALK":99,"VOID_CRAB_MIDDLE_ATTACK":198,"FORK_TRIDENT_IDLE":454,"WAND_IDLE":550,"DRAGON_SWIRL":547,"TWIRLBLADE_ATTACK_1":117,"MEDITATE":357,"DRAGON_SWORD_FIRE_FP":544,"DRAGON_SWORD_ULT":541,"SORCERER_SPELL_CHARGE":540,"WIND_TUNNEL_FLYING":539,"DAGGER_SWING_2_FP":403,"SLIME_MOVEMENT":506,"KICKER_STOMP":509,"TRAIN_COAL_CABIN_LOOP":532,"HALLOWEEN_BOSS_CAST_BEAM":282,"DUCK_JUMP":114,"TURN_AROUND":492,"TARGET_DUMMY_SOLO_ATTACK":528,"ELK_JUMP":178,"TARGET_DUMMY_SPAWN":524,"PENGUIN_KILL_EFFECT_2":522,"PENGUIN_KILL_EFFECT_1":521,"JUGGERNAUT_STAB_GROUND":308,"TINKER_RUN":582,"SNIPER_PENGUIN_WALKING_2":207,"FP_HEAVENLY_SWORD_CHARGE":168,"BOXING_GLOVE_UPPER_CUT":439,"KICK_4":513,"KICK_3":512,"KICK_2":511,"BLASTING_OFF_AGAIN_3":574,"INFERNO_SWORD_SPIN":162,"PAINT_SHOTGUN_IDLE":131,"SLIME_TAMER_FLUTE_USE_FP":508,"FP_SHIELD_USE":18,"ENVELOPE_THROW":564,"DINO_FALLING":171,"AXOLOTL_IDLE":60,"CHICKEN_ATTACK":446,"TRAIN_PASSANGER_CABIN_LOOP":533,"GOLDEN_GOOSE_SITTING":480,"SLIME_JUMP":505,"VACUUM_GHOST_CAPTURED":58,"FISHING_ROD_IDLE":74,"JUGGERNAUT_SWING":309,"INFERNO_SWORD_CHARGE":161,"STEAM_ENGINEER_OVERCLOCK":503,"GATHER_BOT_IDLE":502,"GATHER_BOT_WALK":500,"FP_LASSO_CHARGE":23,"GOLDEN_GOOSE_WALKING":481,"CRAB_WALK_RIGHT":626,"BOW_AIM":124,"KEEPER_WALK":273,"CAUGHT_IN_4K":497,"SLIME_IDLE":504,"FIRE_SHEEP_SPAWN":365,"RAVEN_THROW":35,"STURDY":495,"CLASSIC_WIZARD_PENGUIN_WALK":215,"WEREWOLF_HOWL":494,"TRIUMPH_STATUE_1":643,"WEREWOLF_CHARGE":493,"FP_PAINT_SHOTGUN_IDLE":133,"TARGET_DUMMY_SPIN_ATTACK":529,"WARLOCK_WALK":488,"EQUIP_2":9,"PINATA_IDLE_1":218,"TURTLE_BLINK":621,"GREAT_HAMMER_CHARGE_FP":421,"BIG_PENGUIN_ATTACK":105,"VOID_CRAB_JUMP":189,"SPIDER_ATTACK":484,"JUGGERNAUT_POSE":310,"CHICKEN_IDLE":445,"VOID_CRAB_DEATH":193,"DEVOUR_ACTION":452,"CLIMB_ROPE":276,"VOID_CRAB_BEAM_ATTACK":188,"EGG_HUNT_PLAYER_DANCE":570,"GOLDEN_GOOSE_FLY":475,"PAN_CHARGE":153,"CRAB_BOSS_STAB_310":474,"SEAHORSE_BEAM":351,"HALLOWEEN_ALTAR_JUMP":290,"SUCKED_INTO_HOLE":498,"SCISSOR_SWORD_COMBO_STRIKE":552,"SPIDER_WALK":485,"VOID_CRAB_FALLING":195,"GREAT_HAMMER_SWING_1":414,"DUCK_WALK":111,"DRAGON_SLAYER_LAUNCH_LOOP":248,"TORNADO_LAUNCHER_SHOOT":151,"PIRATE_SHIP_FLY":231,"BIG_PENGUIN_IDLE":106,"CRAB_BOSS_DIG_DOWN":464,"DRAGON_SMASH_2":546,"DUCK_IDLE":112,"CRAB_BOSS_CLAW_ATTACK":462,"SHIELD_SWORD_WALKING_FP":458,"VOID_CRAB_IDLE":196,"CONDIMENT_GUN_FP":453,"VACUUM_LAUNCH":59,"REBELLION_WAVE_FLAG":651,"FROSTY_SHIELD_SUMMON":334,"WINTER_BOSS_SPIN":348,"GUITAR_PLAY":20,"DEFAULT_SPIDER_BITE":667,"NECROMANCER_SUMMON":265,"FP_INFERNO_SWORD_CHARGE":167,"ASCEND":42,"FORGE_CRYSTAL_GROW":443,"DINO_JUMP":172,"SPIDER_QUEEN_FLY_UP":683,"GIANT_GLOVE_FLICK":440,"KICK_5":514,"VOID_DRAGON_WINGS_FLAP":250,"DRAGON_GLIDING":246,"CRAB_BLINK":627,"GOLEM_BOSS_HAMMER_RAISE":374,"DODO_BIRD_IDLE":43,"SMOKE_JUMP_DOWN":236,"MERCHANT_PURCHASE":392,"VOID_CRAB_ATTACKED":192,"GAUNTLETS_SUPER_PUNCH":426,"OPEN_CRATE":116,"SPRAY":29,"TALL_PENGUIN_IDLE":102,"JADE_HAMMER_SLAM":40,"GREAT_HAMMER_CHARGE":417,"FP_HANDS_RUNNING_LEFT_ARM":296,"FISHING_ROD_CATCH_FAIL":76,"CRAB_BOSS_STAB_230":472,"SHIELD_SWORD_IDLE_FP":459,"FP_CROSSBOW_FIRE":17,"CLASSIC_PENGUIN_JUMP":211,"INFERNAL_SHIELD_SLAM":387,"SCYTHE_PULL_1_FP":412,"OWL_FLY":360,"BREAK_BLOCK":607,"MIRROR_KILL_EFFECT":240,"GLUE_TRAP_CHARGING_IDLE":304,"OWL_HEAL":361,"KIT_MASTERY_EMOTE":560,"COMET_VOLLEY_COMET_FIRED":538,"FLYING_LUCKY_BLOCK_FLAP":398,"DINO_CHARGING":174,"CRYSTAL_GROW":451,"FLYING_BACKPACK_FLAP":397,"DISCO_DANCE":378,"GAUNTLETS_JAB_1ST":429,"AXOLOTL_REINDEER_ABILITY":66,"NINJA_THROW_CHAKRAM_SHORTENED":518,"HEAVENLY_SWORD_CHARGE":163,"VOID_PORTAL_EXCITED":201,"GOLEM_BOSS_DEATH":377,"DUCK_HONK":115,"CLASSIC_PENGUIN_ATTACK":208,"GOLEM_BOSS_MOVE":373,"HEADHUNTER_AIM_FP":396,"VOID_CRAB_LEFT_ATTACK":190,"DAO_DASH":110,"DIAMOND_GUARDIAN_DEATH":370,"ELK_UPPERCUT":181,"KEEPER_ATTACK_2":275,"VOID_CRAB_EYE_MOVEMENT":194,"FIRE_SHEEP_CHARGE":364,"SUMMONER_CHARACTER_SWIPE":654,"DAGGER_SLASH":225,"BLACKHOLE_CONSUME":243,"VOID_DRAGON_GLIDE":251,"WARRIOR_SPIDER_WALK":681,"SCYTHE_HOLD":413,"AXOLOTL_REINDEER_IDLE":64,"SCISSOR_SWORD_SWING_2":554,"FROSTY_HAMMER_SLAM":332,"CRAB_DANCE":630,"ROCKET_LAUNCHER_RELOAD":52,"KAZOTSKY_KICK":438,"JUGGERNAUT_ULTIMATE":320,"JUGGERNAUT_LEAP_ATTACK":306,"SPEAR_STAB_1":657,"SPEAR_THROW":81,"GHOST_SPIN":80,"PAN_SWING":152,"VACUUM_SUCK":55,"EASTER_BUNNY_EMOTE_PLAYER":158,"FP_HOLD_SWORD":12,"SEAHORSE_SHOOT":353,"PENGUIN_IDLE_2":204,"DODO_BIRD_FLUTTER":47,"BOBA_BLASTER_IDLE":148,"SCYTHE_IDLE":92}
]]
bedwars.ProdAnimationsMeta = game:GetService("HttpService"):JSONDecode(animm)
bedwars.AnimationTypeMeta = game:GetService("HttpService"):JSONDecode(animtype)
bedwars.AnimationType = bedwars.AnimationTypeMeta
bedwars.AnimationController = {
	ProdAnimationsMeta = bedwars.ProdAnimationsMeta,
	AnimationTypeMeta = bedwars.AnimationTypeMeta
}
function bedwars.AnimationController:getAssetId(IndexId)
	return bedwars.AnimationController.ProdAnimationsMeta[IndexId]
end
bedwars.AnimationUtil = {}
function bedwars.AnimationUtil:playAnimation(plr, id)
    repeat task.wait() until plr.Character
    local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then warn("[bedwars.AnimationUtil:playAnimation]: Humanoid not found in the character"); return end
    local animation = Instance.new("Animation")
    animation.AnimationId = id
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local animationTrack = animator:LoadAnimation(animation)
    animationTrack:Play()
    return animationTrack 
end
function bedwars.AnimationUtil:fetchAnimationIndexId(name)
	if not bedwars.AnimationController.AnimationTypeMeta[name] then return nil end
	for i,v in pairs(bedwars.AnimationController.AnimationTypeMeta) do
		if i == name then return v end
	end
	return nil
end
bedwars.GameAnimationUtil = {}
bedwars.GameAnimationUtil.playAnimation = function(plr, id)
	return bedwars.AnimationUtil:playAnimation(plr, bedwars.AnimationController:getAssetId(id))
end
bedwars.ViewmodelController = {}
function bedwars.ViewmodelController:playAnimation(id)
	return bedwars.AnimationUtil:playAnimation(game:GetService("Players").LocalPlayer, bedwars.AnimationController:getAssetId(id))
end
bedwars.SwordController = {
    lastSwing = tick(),
	lastAttack = game.Workspace:GetServerTimeNow()
}
bedwars.SwordController.isClickingTooFast = function() end
function bedwars.SwordController:canSee() return true end
function bedwars.SwordController:playSwordEffect(swordmeta, status)
	task.spawn(function()
		local animation
		local animName = swordmeta.displayName:find(" Scythe") and "SCYTHE_SWING" or "SWORD_SWING"
		local animCooldown = swordmeta.displayName:find(" Scythe") and 0.3 or 0.15
		local lplr = game:GetService("Players").LocalPlayer
		animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(bedwars.AnimationUtil:fetchAnimationIndexId(animName)))
		task.wait(animCooldown)
		if animation ~= nil then animation:Stop(); animation:Destroy() end
	end)
end
function bedwars.SwordController:swingSwordAtMouse()
	pcall(function() return bedwars.Client:Get("SwordSwingMiss"):FireServer({["weapon"] = store.localHand.tool, ["chargeRatio"] = 0}) end)
end
bedwars.BlockController = {}
function bedwars.BlockController:isBlockBreakable() return true end
function bedwars.BlockController:getBlockPosition(block)
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {game:GetService("Players").LocalPlayer.Character}
    RayParams.IgnoreWater = true
    local RayRes = game.Workspace:Raycast(type(block) == "userdata" and block.Position or block + Vector3.new(0, 30, 0), Vector3.new(0, -35, 0), RayParams)
    local targetBlock
    if RayRes then
        targetBlock = RayRes.Instance or type(block) == "userdata" and black or nil		
        local function resolvePos(pos) return Vector3.new(math.round(pos.X / 3), math.round(pos.Y / 3), math.round(pos.Z / 3)) end
        return resolvePos(targetBlock.Position)
    else
        return false
    end
end
function bedwars.BlockController:getBlockPosition2(position)
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {game:GetService("Players").LocalPlayer.Character, game.Workspace.Camera}
    RayParams.IgnoreWater = true
    local startPosition = position + Vector3.new(0, 30, 0)
    local direction = Vector3.new(0, -35, 0)
    local RayRes = game.Workspace:Raycast(startPosition, direction, RayParams)
    if RayRes then
        local targetBlock = RayRes.Instance
        if targetBlock then
            local function resolvePos(pos)
                return Vector3.new(
                    math.round(pos.X / 3),
                    math.round(pos.Y / 3),
                    math.round(pos.Z / 3)
                )
            end
            return resolvePos(targetBlock.Position)
        end
    end
    return nil
end

local function getBestTool(block)
	local tool = nil
	local blockmeta = bedwars.ItemTable[block]
	local blockType = blockmeta.block and blockmeta.block.breakType
	if blockType then
		local best = 0
		for i,v in pairs(store.localInventory.inventory.items) do
			local meta = bedwars.ItemTable[v.itemType]
			if meta.breakBlock and meta.breakBlock[blockType] and meta.breakBlock[blockType] >= best then
				best = meta.breakBlock[blockType]
				tool = v
			end
		end
	end
	return tool
end
function bedwars.BlockController:calculateBlockDamage(plr, posTbl)
	local tool = getBestTool(tostring(posTbl.block))
	local tooldmg = bedwars.ItemTable[tostring(tool.itemType)].breakBlock
	if table.find(tooldmg, tostring(tool)) then tooldmg = tooldmg[tostring(tool)] else
		for i,v in pairs(tooldmg) do tooldmg = v break end
	end
	return tooldmg
end
function bedwars.BlockController:getAnimationController()
	return bedwars.AnimationController
end
function bedwars.BlockController:resolveBreakPosition(pos)
	return Vector3.new(math.round(pos.X / 3), math.round(pos.Y / 3), math.round(pos.Z / 3))
end
function bedwars.BlockController:resolveRaycastResult(block)
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.FilterDescendantsInstances = {game:GetService("Players").LocalPlayer.Character}
	RayParams.IgnoreWater = true
	return game.Workspace:Raycast(block.Position + Vector3.new(0, 30, 0), Vector3.new(0, -35, 0), RayParams)
end
local cachedNormalSides = {}
for i,v in pairs(Enum.NormalId:GetEnumItems()) do if v.Name ~= "Bottom" then table.insert(cachedNormalSides, v) end end
local function getPlacedBlock(pos, strict)
	if (not pos) then warn(debug.traceback("[getPlacedBlock]: pos is nil!")) return nil end
    local regionSize = Vector3.new(1, 1, 1)
    local region = Region3.new(pos - regionSize / 2, pos + regionSize / 2)
    local parts = game.Workspace:FindPartsInRegion3(region, nil, math.huge)
	local res 
    for _, part in pairs(parts) do
        if part and part.ClassName and part.ClassName == "Part" and part.Parent then
			if strict then
				if part.Parent.Name == 'Blocks' and part.Parent.ClassName == "Folder" then res = part end
			else
				res = part 
			end
        end
		break
    end
    return res
end
function bedwars.BlockController:getStore()
	local tbl = {}
	function tbl:getBlockData(pos)
		return getPlacedBlock(pos)
	end
	function tbl:getBlockAt(pos)
		return getPlacedBlock(pos)
	end
	return tbl
end
local function isBlockCovered(pos)
	local coveredsides = 0
	for i, v in pairs(cachedNormalSides) do
		local blockpos = (pos + (Vector3.FromNormalId(v) * 3))
		local block = getPlacedBlock(blockpos)
		if block then
			coveredsides = coveredsides + 1
		end
	end
	return coveredsides == #cachedNormalSides
end
local failedBreak = 0
bedwars.breakBlock = function(block, anim)
	if block.Name == "bed" and tostring(block:GetAttribute("TeamId")) == tostring(game:GetService("Players").LocalPlayer:GetAttribute("Team")) then return end
    local resolvedPos = bedwars.BlockController:getBlockPosition(block)
    if resolvedPos then
		local result = bedwars.Client:Get(bedwars.DamageBlockRemote):InvokeServer({
            blockRef = {
                blockPosition = resolvedPos
            },
            hitPosition = resolvedPos,
            hitNormal = resolvedPos
        })
		if result ~= "failed" then
			failedBreak = 0
			task.spawn(function()
				local animation
				if anim then
					local lplr = game:GetService("Players").LocalPlayer
					animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(bedwars.AnimationUtil:fetchAnimationIndexId("BREAK_BLOCK")))
				end
				task.wait(0.3)
				if animation ~= nil then
					animation:Stop()
					animation:Destroy()
				end
			end)
		else
			failedBreak = failedBreak + 1
		end
    end
end
bedwars.Client = {}
local cache = {} 
local namespaceCache = {}
local function getRemotes(paths)
    local allRemotes = {}
    local function filterDescendants(descendants, classNames)
        local filtered = {}
        if typeof(classNames) ~= "table" then
            classNames = {classNames}
        end
        for _, descendant in pairs(descendants) do
            for _, className in pairs(classNames) do
                if descendant:IsA(className) then
                    table.insert(filtered, descendant)
                    break 
                end
            end
        end
        return filtered
    end
    for _, path in pairs(paths) do
        local objectToGetDescendantsFrom = game
        for _, subfolder in pairs(string.split(path, ".")) do
            objectToGetDescendantsFrom = objectToGetDescendantsFrom:FindFirstChild(subfolder)
            if not objectToGetDescendantsFrom then
                break
            end
        end
        if objectToGetDescendantsFrom then
            local remotes = filterDescendants(objectToGetDescendantsFrom:GetDescendants(), {"BindableEvent", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"})
            for _, remote in pairs(remotes) do
                table.insert(allRemotes, remote)
            end
        end
    end
    return allRemotes
end
function bedwars.Client:Get(remName, customTable, resRequired)
    if cache[remName] then
        return cache[remName] 
    end
    local remotes = customTable or getRemotes({"ReplicatedStorage"})
    for _, v in pairs(remotes) do
        if v.Name == remName or string.find(v.Name, remName) then  
            local remote
            if not resRequired then
                remote = v
            else
                local tbl = {}
                function tbl:InvokeServer()
                    local tbl2 = {}
                    local res = v:InvokeServer()
                    function tbl2:andThen(func)
                        func(res)
                    end
                    return tbl2
                end
                remote = tbl
            end
            
            cache[remName] = remote 
            return remote
        end
    end
    local backupTable = {}
    function backupTable:FireServer() return false end
    function backupTable:InvokeServer() return false end
    cache[remName] = backupTable
    return backupTable
end
bedwars.getIcon = function(item, showinv)
	local itemmeta = bedwars.ItemTable[item.itemType]
	if itemmeta and showinv then
		return itemmeta.image or ""
	end
	return ""
end
bedwars.ItemHandler = {}
bedwars.ItemHandler.ItemMeta = {
	ARMOR_SCALE = 0.04,
	items = {
	  fake_bed = {
		image = "rbxassetid://7911164143",
		block = {
		  disableInventoryPickup = true,
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  minecraftConversions = { {
			blockId = 8023
		  } },
		  seeThrough = true,
		  health = 18
		},
		displayName = "Fake Bed"
	  },
	  clay_dark_green = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 13,
			blockId = 159
		  }, {
			blockData = 1,
			blockId = 18
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765812", "rbxassetid://16991765812", "rbxassetid://16991765812", "rbxassetid://16991765812", "rbxassetid://16991765812", "rbxassetid://16991765812" }
		  }
		},
		image = "rbxassetid://7884367424",
		displayName = "Dark Green Clay"
	  },
	  world_edit_wand = {
		firstPerson = {
		  verticalOffset = -0.8
		},
		image = "rbxassetid://16009857584",
		sharingDisabled = true,
		displayName = "World Edit Wand"
	  },
	  duck_spawn_egg = {
		image = "rbxassetid://8732031366",
		consumable = {
		  soundOverride = "None",
		  consumeTime = 3.5,
		  disableAnimation = true,
		  cancelOnDamage = true
		},
		displayName = "Duck Egg"
	  },
	  large_bush = {
		block = {
		  dontPlaceInPublicMatch = true,
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 12000
		  } },
		  seeThrough = true,
		  canReplace = true,
		  unbreakable = true
		},
		displayName = "Large Bush"
	  },
	  party_hat_launcher = {
		projectileSource = {
		  activeReload = true,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "party_hat_missile" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8649937489" },
		  fireDelaySec = 2.2
		},
		image = "rbxassetid://17580323633",
		description = "",
		displayName = "Party Hat Launcher"
	  },
	  wood_plank_spruce = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 5
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991767936", "rbxassetid://16991767936", "rbxassetid://16991767936", "rbxassetid://16991767936", "rbxassetid://16991767936", "rbxassetid://16991767936" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884373190",
		displayName = "Spruce Wood Plank"
	  },
	  og_diamond_sword = {
		image = "rbxassetid://6875481413",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 42
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Diamond Sword"
	  },
	  wood_dagger = {
		image = "rbxassetid://13832902263",
		sharingDisabled = true,
		description = "Dash behind your enemy and strike them in the back for bonus damage.",
		damage = 8,
		sword = {
		  attackSpeed = 0.25,
		  ignoreDamageCooldown = true,
		  swingSounds = { "rbxassetid://13833149867", "rbxassetid://13833150378", "rbxassetid://13833150864", "rbxassetid://13833151323" },
		  knockbackMultiplier = {
			vertical = 0.5,
			horizontal = 0.5
		  },
		  swingAnimations = { 403, 404 },
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 406, 405 },
		  applyCooldownOnMiss = true,
		  damage = 8
		},
		displayName = "Wood Dagger",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  boba_pearl = {
		hotbarFillRight = true,
		image = "rbxassetid://9194313932",
		description = "Ammo for the Boba Blaster.",
		displayName = "Boba Pearl"
	  },
	  telepearl = {
		image = "rbxassetid://6874950144",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "telepearl" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		description = "A magical teleportation orb that can be thrown.",
		displayName = "Telepearl"
	  },
	  turtle_backpack = {
		backpack = {
		  activeAbility = false
		},
		image = "rbxassetid://9006935204",
		maxStackSize = {
		  amount = 1
		},
		displayName = "Turtle Shell"
	  },
	  party_cannon = {
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12018
		  } },
		  breakType = "stone",
		  health = 300,
		  disableInventoryPickup = true,
		  denyPlaceOn = true,
		  collectionServiceTags = { "cannon-type" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		image = "rbxassetid://11967427804",
		description = "Now it's really a party.",
		displayName = "Firework Cannon"
	  },
	  emerald_dao = {
		daoSword = {
		  armorMultiplier = 0.7,
		  dashDamage = 30.800000000000004
		},
		image = "rbxassetid://8665071630",
		description = "Charge to dash forward. Downgrades to a Diamond Dao upon death.",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		skins = { "emerald_dao_tiger", "emerald_dao_victorious", "emerald_dao_cursed" },
		sword = {
		  daoDash = true,
		  attackSpeed = 0.3,
		  damage = 55
		},
		sharingDisabled = true,
		displayName = "Emerald Dao"
	  },
	  rainbow_backpack = {
		image = "rbxassetid://12813669743",
		description = "Summon prisms that attack nearby enemies.",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  activeAbility = false
		},
		displayName = "Prismatic Backpack"
	  },
	  wool_brown = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  breakType = "wool",
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://15380238175", "rbxassetid://15380238175", "rbxassetid://15380238175", "rbxassetid://15380238175", "rbxassetid://15380238175", "rbxassetid://15380238175" }
		  },
		  blastResistance = 0.65,
		  wool = true
		},
		image = "rbxassetid://15380238075",
		displayName = "Brown Wool"
	  },
	  glitch_popup_cube = {
		glitched = true,
		image = "rbxassetid://7976208116",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glitch_popup_cube" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		displayName = "Popup Tower?"
	  },
	  royale_bed = {
		footstepSound = 2,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12005
		  } },
		  blastProof = true,
		  blastResistance = 10000000,
		  breakType = "wood",
		  health = 18,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "royale-bed" },
		  healthType = 1,
		  breakSound = nil
		},
		displayName = "Bed"
	  },
	  vending_machine = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  collectionServiceTags = { "VendingMachine" },
		  minecraftConversions = { {
			blockId = 8009
		  } },
		  health = 20
		},
		displayName = "Vending Machine"
	  },
	  wild_flower = {
		image = "rbxassetid://9134545166",
		description = "Alchemist crafting material.",
		displayName = "Flower"
	  },
	  dizzy_toad = {
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "dizzy_toad" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://10086864455",
		description = "Throw at players to make them dizzy",
		displayName = "Dizzy Toad"
	  },
	  cobblestone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 4
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://8296848659", "rbxassetid://8296848659", "rbxassetid://8296848659", "rbxassetid://8296848659", "rbxassetid://8296848659", "rbxassetid://8296848659" }
		  }
		},
		image = "rbxassetid://8296848529",
		displayName = "Cobblestone"
	  },
	  tinker_weapon_2 = {
		image = "rbxassetid://17016574967",
		sharingDisabled = true,
		replaces = { "tinker_weapon_1" },
		skins = { "fish_tank_iron_chainsaw" },
		sword = {
		  attackRange = 17,
		  attackSpeed = 0.35,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Iron Chainsaw"
	  },
	  unstable_portal = {
		image = "rbxassetid://100881763858968",
		description = "Teleport you to a random location",
		maxStackSize = {
		  amount = 2
		},
		sharingDisabled = true,
		consumable = {
		  blockingStatusEffects = { "grounded" },
		  consumeTime = 0.5
		},
		displayName = "Unstable Portal"
	  },
	  sky_scythe = {
		image = "rbxassetid://13629036006",
		sharingDisabled = true,
		sword = {
		  swingSounds = { "rbxassetid://13620704058", "rbxassetid://13620704708", "rbxassetid://13620705283" },
		  attackSpeed = 1,
		  firstPersonSwingAnimations = { 166 },
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { 162 },
		  applyCooldownOnMiss = true,
		  damage = 50
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Sky Scythe"
	  },
	  diamond_gauntlets = {
		replaces = { "wood_gauntlets", "stone_gauntlets", "iron_gauntlets" },
		description = "Punch rapidly to deal more damage with combos. Downgrades to Iron Gauntlets upon death.",
		sword = {
		  idleAnimation = 430,
		  swingSounds = { },
		  ignoreDamageCooldown = true,
		  attackSpeed = 0.21,
		  damage = 34
		},
		displayName = "Diamond Gauntlets",
		image = "rbxassetid://14839096364",
		sharingDisabled = true,
		damage = 34,
		disableFirstPersonHoldAnimation = true,
		firstPerson = {
		  scale = 1,
		  verticalOffset = -1.2
		}
	  },
	  tinker_machine_upgrade_4 = {
		sharingDisabled = true,
		image = "rbxassetid://17016816172",
		description = "Reduces incoming projectile damage and knockback",
		displayName = "Void Mech Upgrade"
	  },
	  wizard_stick = {
		image = "rbxassetid://13420388305",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 13
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Zeno's Twig"
	  },
	  slate_tiles = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 168
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://10859697603", "rbxassetid://10859697603", "rbxassetid://10859697603", "rbxassetid://10859697603", "rbxassetid://10859697603", "rbxassetid://10859697603" }
		  }
		},
		image = "rbxassetid://10859697544",
		displayName = "Slate Tiles"
	  },
	  wool_pink = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768418", "rbxassetid://16991768418", "rbxassetid://16991768418", "rbxassetid://16991768418", "rbxassetid://16991768418", "rbxassetid://16991768418" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 6,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923578533",
		displayName = "Pink Wool"
	  },
	  melon = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8015
		  } },
		  placedBy = {
			itemType = "melon_seeds"
		  },
		  breakType = "wood",
		  health = 5,
		  seeThrough = true,
		  disableFlamableByTeammates = true,
		  disableInventoryPickup = true,
		  hideDamageTextures = true,
		  breakSound = nil
		},
		image = "rbxassetid://6915428682",
		displayName = "Melon"
	  },
	  wool_orange = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768271", "rbxassetid://16991768271", "rbxassetid://16991768271", "rbxassetid://16991768271", "rbxassetid://16991768271", "rbxassetid://16991768271" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923578297",
		displayName = "Orange Wool"
	  },
	  gum_block = {
		footstepSound = 8,
		block = {
		  disableInventoryPickup = true,
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  disableEnemyInventoryPickup = true,
		  collectionServiceTags = { "GumBlock" },
		  minecraftConversions = { {
			blockId = 8026
		  } },
		  health = 4
		},
		displayName = "Gum Block"
	  },
	  clay_gray = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 9,
			blockId = 159
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765869", "rbxassetid://16991765869", "rbxassetid://16991765869", "rbxassetid://16991765869", "rbxassetid://16991765869", "rbxassetid://16991765869" }
		  }
		},
		image = "rbxassetid://7884367563",
		displayName = "Gray Clay"
	  },
	  spike_shell_backpack = {
		image = "rbxassetid://11272107426",
		description = "Take reduced damage based on the direction of the attack and reflect that damage back to the enemy.",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  activeAbility = false
		},
		displayName = "Spike Shell"
	  },
	  glue_projectile_charging = {
		image = "rbxassetid://15579506278",
		description = "A throwable glue trap! Hit players will be grounded and slowed.",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 5
		  },
		  fireDelaySec = 1,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glue_projectile_charging" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		sharingDisabled = true,
		displayName = "Charging Gloop"
	  },
	  iron_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.24,
		  slot = 1
		},
		image = "rbxassetid://6874272631",
		sharingDisabled = true,
		displayName = "Iron Chestplate"
	  },
	  broken_snow_cone_machine = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  collectionServiceTags = { "BrokenSnowConeMachine" },
		  noSuffocation = true,
		  minecraftConversions = { {
			blockId = 12010
		  } }
		},
		displayName = "Broken Snow Cone Machine"
	  },
	  broken_altar_block = {
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "broken-altar-block" },
		  health = 20
		},
		displayName = "Broken Altar"
	  },
	  mage_spellbook = {
		image = "rbxassetid://11003634601",
		description = "Cast powerful spells at your enemies!",
		multiProjectileSource = {
		  mage_spell_ice = {
			maxStrengthChargeSec = 0.25,
			fireDelaySec = 0.8,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529576", "rbxassetid://10969529368", "rbxassetid://10969529454" },
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  mage_spell_base = {
			maxStrengthChargeSec = 0.25,
			fireDelaySec = 1.2,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529727", "rbxassetid://10969529817", "rbxassetid://10969529761" },
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  mage_spell_fire = {
			maxStrengthChargeSec = 0.25,
			fireDelaySec = 0.8,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529606", "rbxassetid://10969529694", "rbxassetid://10969529644" },
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  mage_spell_nature = {
			maxStrengthChargeSec = 0.25,
			fireDelaySec = 0.8,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529190", "rbxassetid://10969529321", "rbxassetid://10969529409" },
			firstPerson = {
			  fireAnimation = 14
			}
		  }
		},
		sharingDisabled = true,
		displayName = "Mage Spellbook"
	  },
	  dirt = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 3
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://7852097294", "rbxassetid://7852097294", "rbxassetid://7852097294", "rbxassetid://7852097294", "rbxassetid://7852097294", "rbxassetid://7852097294" }
		  }
		},
		image = "rbxassetid://7884368936",
		displayName = "Dirt"
	  },
	  snap_trap = {
		image = "rbxassetid://7805515071",
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 8001
		  } },
		  collectionServiceTags = { "snap_trap" },
		  disableEnemyInventoryPickup = true,
		  health = 18
		},
		displayName = "Snap Trap"
	  },
	  emerald_egg = {
		image = "rbxassetid://13031415391",
		description = "A one-time-purchase souvenir for the Egg Hunt Event",
		displayNameColor = nil,
		sharingDisabled = true,
		displayName = "Emerald Egg"
	  },
	  merchant_region_block = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Merchant Region Block"
	  },
	  golden_apple = {
		maxStackSize = {
		  amount = 4
		},
		image = "rbxassetid://12444096542",
		consumable = {
		  consumeTime = 0.5
		},
		displayName = "Golden Apple"
	  },
	  brick = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 45
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://12948863341", "rbxassetid://12948863341", "rbxassetid://12948863341", "rbxassetid://12948863341", "rbxassetid://12948863341", "rbxassetid://12948863341" }
		  }
		},
		image = "rbxassetid://7884366460",
		displayName = "Brick"
	  },
	  pogo_stick = {
		image = "rbxassetid://105174521741104",
		description = "",
		displayName = "Pogo Stick"
	  },
	  camera_turret = {
		image = "rbxassetid://7290567966",
		sharingDisabled = true,
		skins = { "camera_turret_lunar", "camera_turret_vampire", "camera_turret_cream_soda" },
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8019
		  } },
		  disableInventoryPickup = true,
		  blastResistance = 2.915,
		  breakType = "stone",
		  health = 50,
		  seeThrough = true,
		  collectionServiceTags = { "Turret", "engineer-turret" },
		  projectileSource = {
			fireDelaySec = 0.25,
			relativeOverride = {
			  relX = 0,
			  relY = 0,
			  relZ = 0
			},
			projectileType = nil,
			launchSound = { "rbxassetid://7290187805" },
			hitSounds = { { "rbxassetid://6866062188" } }
		  },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Camera Turret"
	  },
	  healing_turret = {
		image = "rbxassetid://9557924389",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "HealingTurret" },
		  noSuffocation = true,
		  health = 100
		},
		displayName = "Healing Fountain"
	  },
	  spirit = {
		image = "rbxassetid://7498308261",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 8
		},
		projectileSource = {
		  maxStrengthChargeSec = 1.5,
		  ammoItemTypes = { "spirit" },
		  minStrengthScalar = 0.2,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  fireDelaySec = 0.6
		},
		displayName = "Spirit"
	  },
	  glitch_wood_sword = {
		glitched = true,
		image = "rbxassetid://6875480974",
		pickUpOverlaySound = "rbxassetid://10859056155",
		sword = {
		  attackSpeed = 0.3,
		  damage = 42
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Wood Sword?"
	  },
	  shadow_coin = {
		keepOnDeath = true,
		image = "rbxassetid://18938976671",
		sharingDisabled = true,
		displayName = "Shadow Coin"
	  },
	  iron_gauntlets = {
		replaces = { "wood_gauntlets", "stone_gauntlets" },
		description = "Punch rapidly to deal more damage with combos. Downgrades to Stone Gauntlets upon death.",
		sword = {
		  idleAnimation = 430,
		  swingSounds = { },
		  ignoreDamageCooldown = true,
		  attackSpeed = 0.21,
		  damage = 24
		},
		displayName = "Iron Gauntlets",
		image = "rbxassetid://14839144410",
		sharingDisabled = true,
		damage = 24,
		disableFirstPersonHoldAnimation = true,
		firstPerson = {
		  scale = 1,
		  verticalOffset = -1.2
		}
	  },
	  stun_grenade = {
		image = "rbxassetid://10086863810",
		hotbarFillRight = true,
		displayName = "Stun Grenade"
	  },
	  murderer_throwing_knife = {
		image = "rbxassetid://8479269961",
		description = "Deadly.",
		projectileSource = {
		  fireDelaySec = 7,
		  projectileType = nil
		},
		sharingDisabled = true,
		displayName = "Throwing Knife"
	  },
	  diamond_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 57
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://7861529819", "rbxassetid://7861529819", "rbxassetid://7861529819", "rbxassetid://7861529819", "rbxassetid://7861529819", "rbxassetid://7861529819" }
		  }
		},
		image = "rbxassetid://7884368860",
		displayName = "Diamond Block"
	  },
	  huge_lucky_block = {
		block = {
		  disableInventoryPickup = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  minecraftConversions = { {
			blockId = 9010
		  } },
		  luckyBlock = {
			allowedPolarity = { "neutral", "positive" },
			timeBetweenDropsSec = 0.5,
			allowedRarity = { 60, 25, 10, 3 },
			drops = { {
			  luckMultiplier = 1
			}, {
			  luckMultiplier = 1
			}, {
			  luckMultiplier = 2
			}, {
			  luckMultiplier = 2
			}, {
			  luckMultiplier = 4
			} }
		  },
		  health = 150
		},
		displayName = "Huge Lucky Block"
	  },
	  damage_orb_diamond = {
		removeFromCustoms = true,
		image = "rbxassetid://12132682148",
		description = "Grants +2% damage.",
		displayName = "Damage Orb"
	  },
	  wood_bow = {
		image = "rbxassetid://6869295332",
		sharingDisabled = true,
		skins = { "wood_bow_demon_empress_vanessa", "wood_bow_lunar_dragon", "wood_bow_valentine" },
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  multiShotChargeTime = 1,
		  fireDelaySec = 0.6,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "volley_arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  maxStrengthChargeSec = 0.65,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.3333333333333333
		},
		firstPerson = {
		  verticalOffset = 0
		},
		displayName = "Bow"
	  },
	  rainbow_axe = {
		sword = {
		  attackSpeed = 0.75,
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			vertical = 0.8,
			horizontal = 1.5
		  },
		  applyCooldownOnMiss = true,
		  damage = 35
		},
		image = "rbxassetid://12811586114",
		description = "Impale enemies with fragments of light.",
		displayName = "Radiant Axe"
	  },
	  iron_axe = {
		image = "rbxassetid://6875481370",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  wood = 12
		},
		displayName = "Iron Axe"
	  },
	  wizard_staff_2 = {
		image = "rbxassetid://13397121643",
		sharingDisabled = true,
		skins = { "wizard_staff_2_anniversary", "gold_victorious_wizard_staff_2", "platinum_victorious_wizard_staff_2", "diamond_victorious_wizard_staff_2", "emerald_victorious_wizard_staff_2", "nightmare_victorious_wizard_staff_2" },
		replaces = { "wizard_staff" },
		multiProjectileSource = {
		  lightning_strike = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 25
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  electric_orb = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 26
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  }
		},
		displayName = "Wizard Staff II"
	  },
	  pumpkin = {
		image = "rbxassetid://11403476091",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8015
		  } },
		  placedBy = {
			itemType = "pumpkin_seeds"
		  },
		  breakType = "wood",
		  health = 5,
		  seeThrough = true,
		  disableFlamableByTeammates = true,
		  disableInventoryPickup = true,
		  hideDamageTextures = true,
		  breakSound = nil
		},
		displayName = "Pumpkin"
	  },
	  murderer_dagger = {
		image = "rbxassetid://10993361352",
		sharingDisabled = true,
		displayName = "Murderer Dagger"
	  },
	  marble = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://7861531930", "rbxassetid://7861531930", "rbxassetid://7861531930", "rbxassetid://7861531930", "rbxassetid://7861531930", "rbxassetid://7861531930" }
		  },
		  health = 8,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 155
		  } }
		},
		image = "rbxassetid://6594536339",
		displayName = "Marble"
	  },
	  orange = {
		image = "rbxassetid://13465460651",
		description = "Consume to heal a small amount",
		maxStackSize = {
		  amount = 4
		},
		consumable = {
		  consumeTime = 0.8,
		  consumeCooldown = 0.5,
		  requiresMissingHealth = true
		},
		displayName = "Health Orange"
	  },
	  egg_launcher = {
		removeFromCustoms = true,
		image = "rbxassetid://13033176844",
		projectileSource = {
		  activeReload = true,
		  ammoItemTypes = { "easter_egg_projectile" },
		  fireDelaySec = 2.2,
		  projectileType = nil,
		  launchSound = { "rbxassetid://13024113952" },
		  thirdPerson = {
			fireAnimation = 51,
			aimAnimation = 53
		  }
		},
		displayName = "Egg Launcher"
	  },
	  andesite_polished = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 6,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072552916", "rbxassetid://9072552916", "rbxassetid://9072552916", "rbxassetid://9072552916", "rbxassetid://9072552916", "rbxassetid://9072552916" }
		  }
		},
		image = "rbxassetid://9072552793",
		displayName = "Polished Andesite"
	  },
	  hot_air_balloon_deploy = {
		consumable = {
		  consumeTime = 2,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		image = "rbxassetid://13701861348",
		description = "Take your whole team to the skies!",
		displayName = "Hot Air Balloon"
	  },
	  party_popper = {
		thirdPerson = {
		  holdAnimation = 352
		},
		image = "rbxassetid://11967427626",
		description = "Time to party!",
		displayName = "Party Popper"
	  },
	  tinker_machine_upgrade_2 = {
		sharingDisabled = true,
		image = "rbxassetid://17016629772",
		description = "Unlocks Self-Destruct ability",
		displayName = "Diamond Mech Upgrade"
	  },
	  iron_pickaxe_sword = {
		sword = {
		  swingAnimations = { },
		  attackSpeed = 1,
		  swingSounds = { "rbxassetid://11715551373" },
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			disabled = true
		  },
		  applyCooldownOnMiss = true,
		  damage = 1
		},
		image = "rbxassetid://6875481325",
		description = "Handy tool for mining crystals",
		displayName = "Iron PickAxe"
	  },
	  invisibility_potion = {
		image = "rbxassetid://7836794914",
		description = "Drink to gain the effects of invisibility.",
		crafting = { },
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  consumeTime = 0.8,
		  potion = true,
		  statusEffect = {
			duration = 30,
			statusEffectType = "invisibility"
		  }
		},
		displayName = "Invisiblity Potion"
	  },
	  ice = {
		footstepSound = 7,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 79
		  }, {
			blockId = 174
		  }, {
			blockId = 212
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766460", "rbxassetid://16991766460", "rbxassetid://16991766460", "rbxassetid://16991766460", "rbxassetid://16991766460", "rbxassetid://16991766460" }
		  }
		},
		image = "rbxassetid://7884369431",
		displayName = "Ice"
	  },
	  solar_panel = {
		image = "rbxassetid://11775182157",
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  noSuffocation = true,
		  collectionServiceTags = { "SolarPanel" },
		  minecraftConversions = { {
			blockId = 12017
		  } },
		  health = 30
		},
		displayName = "Solar Panel"
	  },
	  marble_pillar = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 155
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766637", "rbxassetid://16991766637", "rbxassetid://16991766587", "rbxassetid://16991766587", "rbxassetid://16991766587", "rbxassetid://16991766587" }
		  }
		},
		image = "rbxassetid://7884370206",
		displayName = "Marble Pillar"
	  },
	  spirit_tier_1 = {
		image = "rbxassetid://90021560389940",
		description = "Upgrades your current spirit tier, making your spirits stronger.",
		displayName = "Spirit Tier I"
	  },
	  void_turret = {
		image = "rbxassetid://9942058258",
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8011
		  } },
		  blastResistance = 4,
		  breakType = "stone",
		  health = 25,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "Turret", "void-turret" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Void Turret"
	  },
	  damage_orb_emerald = {
		removeFromCustoms = true,
		image = "rbxassetid://12132684852",
		description = "Grants +2% damage.",
		displayName = "Damage Orb"
	  },
	  galactite_brick = {
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 112
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9839888790", "rbxassetid://9839888790", "rbxassetid://9839888790", "rbxassetid://9839888790", "rbxassetid://9839888790", "rbxassetid://9839888790" }
		  }
		},
		image = "rbxassetid://9839888714",
		displayName = "Galactite Brick"
	  },
	  anniversary_balloon = {
		image = "rbxassetid://17580323788",
		description = "Use up to three times to gain slowfall and jump boost.",
		maxStackSize = {
		  amount = 3
		},
		cooldownId = "balloon",
		displayName = "Balloon"
	  },
	  carrot_rocket = {
		image = "rbxassetid://9133691017",
		hotbarFillRight = true,
		displayName = "Carrot Rocket"
	  },
	  metal_detector = {
		image = "rbxassetid://9378643217",
		sharingDisabled = true,
		displayName = "Metal Detector"
	  },
	  stone_pillar = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 202
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://12938322729", "rbxassetid://12938322729", "rbxassetid://10859697821", "rbxassetid://10859697821", "rbxassetid://10859697821", "rbxassetid://10859697821" }
		  }
		},
		image = "rbxassetid://10859697750",
		displayName = "Stone Pillar"
	  },
	  golden_bow = {
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  ammoItemTypes = { "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.25,
		  maxStrengthChargeSec = 0.5,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.25
		},
		image = "rbxassetid://8479270340",
		displayName = "Golden Bow"
	  },
	  wizard_staff = {
		image = "rbxassetid://13397121945",
		sharingDisabled = true,
		skins = { "wizard_staff_anniversary", "gold_victorious_wizard_staff", "platinum_victorious_wizard_staff", "diamond_victorious_wizard_staff", "emerald_victorious_wizard_staff", "nightmare_victorious_wizard_staff" },
		multiProjectileSource = {
		  lightning_strike = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 25
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  electric_orb = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 26
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  }
		},
		displayName = "Wizard Staff I"
	  },
	  summon_stone = {
		maxStackSize = {
		  amount = 10
		},
		image = "rbxassetid://78731218979246",
		sharingDisabled = true,
		displayName = "Summon Stone"
	  },
	  lobby_spring_punch = {
		removeFromCustoms = true,
		image = "rbxassetid://89187423732739",
		description = "Yeet your enemies with a spring loaded punch!",
		maxStackSize = {
		  amount = 1
		},
		sharingDisabled = true,
		thirdPerson = {
		  holdAnimation = 53
		},
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Punch Gun"
	  },
	  banana_peel = {
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "banana_peel" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		image = "rbxassetid://7681234378",
		description = "Opponents that walk over the peel will ragdoll.",
		displayName = "Banana Peel"
	  },
	  crystalheart_seed = {
		image = "rbxassetid://100738065488362",
		description = "Plant near a team generator for a 10% speed increase or a global generator for a 50% speed increase when fully grown",
		sharingDisabled = true,
		placesBlock = {
		  blockType = "crystalheart_flower"
		},
		displayName = "Crystalheart Seed"
	  },
	  hero_magical_girl_scepter = {
		image = "rbxassetid://16101841584",
		description = "Harness the power of the sun to deal explosive damage to foes!",
		tierUpgradeElements = { {
		  tierDescription = { "+1 Projectile On Charged Attack (3 Total)" }
		}, {
		  tierDescription = { "Status Effects Can Now Stack", "3rd Stack Of Solar Flare Consumes Stacks", "Every 3rd Stack Causes An Explosion" }
		}, {
		  tierDescription = { "+2 Projectiles On Charged Attack (5 Total)" }
		} },
		itemCatalog = {
		  collection = 3
		},
		firstPerson = {
		  verticalOffset = 0
		},
		multiProjectileSource = {
		  hero_magical_girl_scepter_multi_projectile = {
			multiShotCount = 3,
			multiShot = true,
			multiShotChargeTime = 0.5,
			fireDelaySec = 1,
			minStrengthScalar = 1,
			projectileType = nil,
			launchSound = { "rbxassetid://16111537253", "rbxassetid://16111537565", "rbxassetid://16111581322", "rbxassetid://16111537689" },
			multiShotDelay = 0.1
		  },
		  hero_magical_girl_scepter_projectile = {
			multiShotCount = 3,
			multiShot = true,
			multiShotChargeTime = 0.5,
			fireDelaySec = 1,
			minStrengthScalar = 1,
			projectileType = nil,
			launchSound = { "rbxassetid://16111537253", "rbxassetid://16111537565", "rbxassetid://16111581322", "rbxassetid://16111537689" },
			multiShotDelay = 0.1
		  }
		},
		displayName = "Hero's Magical Scepter"
	  },
	  fireball = {
		image = "rbxassetid://7192711008",
		description = "Throw fireball that explodes on impact.",
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 5
		  },
		  fireDelaySec = 1,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "fireball" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://7192289445" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		sharingDisabled = true,
		displayName = "Fireball"
	  },
	  bear_claws = {
		firstPerson = {
		  scale = 0.8
		},
		image = "rbxassetid://9434318163",
		sword = {
		  attackSpeed = 0.8,
		  swingAnimations = { 156 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.1
			},
			ignoreEffectsOnFullyCharged = true,
			maxChargeTimeSec = 1,
			bonusDamage = 15
		  },
		  knockbackMultiplier = {
			horizontal = 0.1
		  },
		  firstPersonSwingAnimations = { 156 },
		  swingSounds = { "rbxassetid://15171393432" },
		  applyCooldownOnMiss = true,
		  damage = 45
		},
		displayName = "Bear Claw"
	  },
	  birch_log = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 17
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991765432", "rbxassetid://16991765432", "rbxassetid://16991765391", "rbxassetid://16991765391", "rbxassetid://16991765391", "rbxassetid://16991765391" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884365859",
		displayName = "Birch Log"
	  },
	  sleep_splash_potion = {
		image = "rbxassetid://9134319146",
		description = "Places players hit by the potion in a sleep state until the effect wears off.",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  fireDelaySec = 0.4,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.7,
		  ammoItemTypes = { "sleep_splash_potion" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = { }
		},
		displayName = "Sleep Splash Potion"
	  },
	  angel_wings = {
		image = "rbxassetid://17193022208",
		description = "Magical pair of wings.",
		removeFromCustoms = true,
		sharingDisabled = true,
		backpack = { },
		displayName = "Angel Wings"
	  },
	  hot_potato = {
		description = "Harmful potato that damages the player carrying it. Explodes when the holder dies.",
		sword = {
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.95,
			  delay = 0.25
			},
			minChargeTimeSec = 0.5,
			chargedSwingAnimations = { 164 },
			firstPersonChargedSwingAnimations = { 165 },
			maxChargeTimeSec = 1
		  },
		  knockbackMultiplier = {
			vertical = 1,
			horizontal = 2
		  },
		  attackSpeed = 0.75,
		  damage = 0
		},
		displayName = "Hot Potato",
		image = "rbxassetid://11465631173",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		projectileSource = {
		  fireDelaySec = 1,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.6,
		  ammoItemTypes = { "hot_potato" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 54
		  }
		},
		removeFromCustoms = true,
		firstPerson = {
		  scale = 0.8
		}
	  },
	  lucky_block = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  greedyMesh = {
			textures = { "rbxassetid://7843804042", "rbxassetid://7843804042", "rbxassetid://7843804042", "rbxassetid://7843804042", "rbxassetid://7843804042", "rbxassetid://7843804042" }
		  },
		  disableInventoryPickup = true,
		  collectionServiceTags = { "LuckyBlock" },
		  luckyBlock = {
			drops = { {
			  luckMultiplier = 1
			} }
		  },
		  minecraftConversions = { {
			blockId = 9000
		  } }
		},
		image = "rbxassetid://7884369916",
		displayName = "Lucky Block"
	  },
	  lobby_kaida_claw = {
		actsAsSwordGroup = true,
		image = "rbxassetid://18974202582",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		cooldownId = "summoner_claw_attack",
		keepOnDeath = true,
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Kaida Claw"
	  },
	  red_sand = {
		footstepSound = 3,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 12
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072732694", "rbxassetid://9072732694", "rbxassetid://9072732694", "rbxassetid://9072732694", "rbxassetid://9072732694", "rbxassetid://9072732694" }
		  }
		},
		image = "rbxassetid://9072732616",
		displayName = "Red Sand"
	  },
	  snow = {
		footstepSound = 6,
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 78
		  }, {
			blockId = 80
		  } },
		  health = 1,
		  greedyMesh = {
			textures = { "rbxassetid://16991766975", "rbxassetid://16991766975", "rbxassetid://16991766975", "rbxassetid://16991766975", "rbxassetid://16991766975", "rbxassetid://16991766975" }
		  }
		},
		image = "rbxassetid://7884371442",
		displayName = "Snow"
	  },
	  stone_brick_builder = {
		image = "rbxassetid://10717427173",
		description = "Build a stone wall",
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  health = 75,
		  blastResistance = 1.73
		},
		displayName = "Stone Wall Builder"
	  },
	  laser_sword = {
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		image = "rbxassetid://11775182286",
		sword = {
		  respectAttackSpeedForEffects = true,
		  attackSpeed = 0.4,
		  hitSound = "rbxassetid://11753700711",
		  swingSounds = { "rbxassetid://11753700600", "rbxassetid://11753700890", "rbxassetid://11753700803" },
		  swingAnimations = { 329, 328 },
		  applyCooldownOnMiss = true,
		  damage = 42
		},
		displayName = "Laser Sword"
	  },
	  headhunt_skull = {
		image = "rbxassetid://13489446736",
		sharingDisabled = true,
		disableDroppedItemMerge = true,
		description = "The skull of an enemy. Turn in at drop points to earn points",
		hotbarFillRight = true,
		displayName = "Skull"
	  },
	  invisible_landmine = {
		image = "rbxassetid://9434319010",
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8011
		  } },
		  maxPlaced = 6,
		  breakType = "stone",
		  health = 25,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "invisible-landmine" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Invisible Landmine"
	  },
	  carrot = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8016
		  } },
		  placedBy = {
			itemType = "carrot_seeds"
		  },
		  breakType = "wood",
		  health = 5,
		  seeThrough = true,
		  disableFlamableByTeammates = true,
		  disableInventoryPickup = true,
		  hideDamageTextures = true,
		  breakSound = nil
		},
		image = "rbxassetid://3677675280",
		displayName = "Carrot"
	  },
	  glue_trap_charging = {
		removeFromCustoms = true,
		image = "rbxassetid://7192711008",
		description = "Glue enemy to the ground",
		displayName = "Glue Trap"
	  },
	  bacon_blade = {
		image = "rbxassetid://14839882835",
		sharingDisabled = true,
		sword = {
		  hitSound = "rbxassetid://14900125962",
		  swingSounds = { "rbxassetid://14900126267", "rbxassetid://14900126384", "rbxassetid://14900126457", "rbxassetid://14900126543" },
		  attackSpeed = 0.3,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Bacon Blade"
	  },
	  wool_builder = {
		image = "rbxassetid://10717426564",
		description = "Build a wool wall",
		footstepSound = 5,
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  health = 8,
		  blastResistance = 0.65,
		  wool = true,
		  flammable = true
		},
		removeFromCustoms = true,
		displayName = "Wool Wall"
	  },
	  glitch_tactical_crossbow = {
		glitched = true,
		projectileSource = {
		  multiShotCount = 3,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  multiShot = true,
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		image = "rbxassetid://7051149016",
		displayName = "Tactical Crossbow?"
	  },
	  iron_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 42
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://7852098030", "rbxassetid://7852098030", "rbxassetid://7852098030", "rbxassetid://7852098030", "rbxassetid://7852098030", "rbxassetid://7852098030" }
		  }
		},
		image = "rbxassetid://7884369517",
		displayName = "Iron Block"
	  },
	  pumpkin_bomb_2 = {
		image = "rbxassetid://11403476091",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "pumpkin_bomb_2" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Jack o'Boom (Large)"
	  },
	  clay_red = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 14,
			blockId = 159
		  }, {
			blockData = 14,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766155", "rbxassetid://16991766155", "rbxassetid://16991766155", "rbxassetid://16991766155", "rbxassetid://16991766155", "rbxassetid://16991766155" }
		  }
		},
		image = "rbxassetid://7884368246",
		displayName = "Red Clay"
	  },
	  manual_cannon = {
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12011
		  } },
		  breakType = "stone",
		  health = 50,
		  disableInventoryPickup = true,
		  denyPlaceOn = true,
		  collectionServiceTags = { "cannon-type" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		image = "rbxassetid://10717427560",
		description = "Shoots a single TNT at a time",
		displayName = "Manual Cannon"
	  },
	  rainbow_arrow = {
		hotbarFillRight = true,
		image = "rbxassetid://12813670017",
		description = "Ammo for the Spectrum Bow.",
		displayName = "Spectrum Arrow"
	  },
	  iron_helmet = {
		armor = {
		  damageReductionMultiplier = 0.2,
		  slot = 0
		},
		image = "rbxassetid://6874272559",
		sharingDisabled = true,
		displayName = "Iron Helmet"
	  },
	  vitality_star = {
		consumable = {
		  consumeTime = 1,
		  soundOverride = "None",
		  animationOverride = 187
		},
		description = "Consume to gain a health buff for yourself and nearby teammates!",
		image = "rbxassetid://9866757969",
		sharingDisabled = true,
		displayName = "Vitality Star"
	  },
	  clay_light_green = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 5,
			blockId = 159
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7872906008", "rbxassetid://7872906008", "rbxassetid://7872906008", "rbxassetid://7872906008", "rbxassetid://7872906008", "rbxassetid://7872906008" }
		  }
		},
		image = "rbxassetid://7884367872",
		displayName = "Light Green Clay"
	  },
	  sparkler = {
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		image = "rbxassetid://11967707388",
		sword = {
		  attackSpeed = 0.3,
		  damage = 38
		},
		displayName = "Sparkler Sword"
	  },
	  infernal_saber = {
		image = "rbxassetid://9620506030",
		sharingDisabled = true,
		skins = { "infernal_saber_krampus" },
		sword = {
		  knockbackMultiplier = {
			horizontal = 0.5
		  },
		  chargedAttack = {
			minChargeTimeSec = 1,
			walkSpeedModifier = {
			  multiplier = 1
			},
			maxChargeTimeSec = 1,
			attackCooldown = 0.5
		  },
		  attackSpeed = 0.3,
		  damage = 40
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Infernal Saber"
	  },
	  christmas_scaffold = {
		image = "rbxassetid://116346363779293",
		sharingDisabled = true,
		footstepSound = 2,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  flammable = true,
		  blastResistance = 1.4,
		  health = 1,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "scaffold" },
		  greedyMesh = {
			textures = { "rbxassetid://140661205602211", "rbxassetid://140661205602211", "rbxassetid://127832405061521", "rbxassetid://127832405061521", "rbxassetid://127832405061521", "rbxassetid://127832405061521" },
			rotation = { }
		  },
		  breakType = "wood"
		},
		displayName = "Scaffold"
	  },
	  natures_essence_3 = {
		image = "rbxassetid://11003449842",
		removeFromCustoms = true,
		displayName = "Nature's Essence III"
	  },
	  glass = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  minecraftConversions = { {
			blockId = 20
		  }, {
			blockData = 0,
			blockId = 95
		  }, {
			blockData = 1,
			blockId = 95
		  }, {
			blockData = 2,
			blockId = 95
		  }, {
			blockData = 3,
			blockId = 95
		  }, {
			blockData = 4,
			blockId = 95
		  }, {
			blockData = 5,
			blockId = 95
		  }, {
			blockData = 6,
			blockId = 95
		  }, {
			blockData = 7,
			blockId = 95
		  }, {
			blockData = 8,
			blockId = 95
		  }, {
			blockData = 9,
			blockId = 95
		  }, {
			blockData = 10,
			blockId = 95
		  }, {
			blockData = 11,
			blockId = 95
		  }, {
			blockData = 12,
			blockId = 95
		  }, {
			blockData = 13,
			blockId = 95
		  }, {
			blockData = 14,
			blockId = 95
		  }, {
			blockData = 15,
			blockId = 95
		  } },
		  health = 1
		},
		image = "rbxassetid://6909521321",
		displayName = "Glass"
	  },
	  frost_crystal = {
		image = "rbxassetid://11847445215",
		sharingDisabled = true,
		displayName = "Frost Crystal"
	  },
	  diamond_capture_block = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil
		},
		removeFromCustoms = true,
		displayName = "Diamond Capture Block"
	  },
	  iron_scythe = {
		replaces = { "stone_scythe", "stone_scythe" },
		image = "rbxassetid://13832903446",
		sharingDisabled = true,
		damage = 30,
		description = "Attack enemies from farther away and pull them toward you. Downgrades to Stone Scythe on death.",
		sword = {
		  chargedAttack = {
			disableOnGrounded = true,
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 2,
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			bonusDamage = 4
		  },
		  idleAnimation = 415,
		  attackSpeed = 0.4,
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 30
		},
		displayName = "Iron Scythe",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  grappling_hook = {
		projectileSource = {
		  waitForHit = true,
		  fireDelaySec = 1,
		  thirdPerson = {
			fireAnimation = 151,
			aimAnimation = 150
		  },
		  projectileType = nil,
		  launchSound = { "rbxassetid://13488974503" },
		  blockingStatusEffects = { "grounded" }
		},
		image = "rbxassetid://9499344892",
		description = "Launch, grapple, and pull yourself along for fast travel.",
		displayName = "Grapple Hook"
	  },
	  necromancer_staff = {
		image = "rbxassetid://11350214469",
		sharingDisabled = true,
		skins = { "necromancer_staff_christmas" },
		projectileSource = {
		  fireDelaySec = 0.6,
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://10999341919" },
		  maxStrengthChargeSec = 0.25
		},
		displayName = "Necromancer Staff"
	  },
	  lobby_pogo_stick = {
		image = "rbxassetid://105174521741104",
		description = "",
		displayName = "Pogo Stick"
	  },
	  chicken_deploy = {
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 451,
			idleAnimation = 452
		  },
		  ammoItemTypes = { "chicken_deploy" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://13988247449",
		sharingDisabled = true,
		displayName = "Chicken"
	  },
	  void_sword = {
		image = "rbxassetid://9873021357",
		sword = {
		  attackSpeed = 0.3,
		  damage = 42
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Void Sword"
	  },
	  block_kicker_block = {
		sharingDisabled = true,
		image = "rbxassetid://6869295400",
		hotbarFillRight = true,
		displayName = "Block Kicker Block"
	  },
	  spear = {
		image = "rbxassetid://7808151805",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 10
		},
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "spear" },
		  walkSpeedMultiplier = 0.2,
		  projectileType = nil,
		  maxStrengthChargeSec = 0.25,
		  fireDelaySec = 0.7
		},
		displayName = "Spear"
	  },
	  flying_lucky_block = {
		image = "rbxassetid://17182946276",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  disableInventoryPickup = true,
		  luckyBlock = {
			categories = { "flying" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  health = 15
		},
		displayName = "Flying Lucky Block"
	  },
	  growing_halloween_lucky_block = {
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  denyPlaceOn = true,
		  collectionServiceTags = { "GrowingHalloweenLuckyBlock" },
		  seeThrough = true,
		  unbreakable = true
		},
		displayName = "Growing Halloween Lucky Block"
	  },
	  portable_vending_machine = {
		image = "rbxassetid://11272093702",
		description = "Visit the Shop anywhere and unlock the Blind-Box in the Shop. Purchasing an item will put the vending machine on cooldown.",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  activeAbility = true
		},
		displayName = "Portable Vending Machine"
	  },
	  infernal_shield = {
		image = "rbxassetid://7051149149",
		description = "Deflect incoming projectiles while shield is raised.",
		skins = { "infernal_shield_summer" },
		firstPerson = {
		  scale = 0.8
		},
		sharingDisabled = true,
		displayName = "Infernal Shield"
	  },
	  diamond_great_hammer = {
		image = "rbxassetid://13832632374",
		sharingDisabled = true,
		replaces = { "wood_great_hammer", "stone_great_hammer", "iron_great_hammer" },
		damage = 48,
		sword = {
		  attackSpeed = 0.6,
		  swingAnimations = { 416, 417 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.9
			},
			minChargeTimeSec = 0.75,
			chargedSwingAnimations = { 418 },
			attackCooldown = 0.65,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 0.75,
			chargedSwingSounds = { "rbxassetid://11715550908" },
			bonusDamage = 16.799999999999997,
			firstPersonChargedSwingAnimations = { 422 },
			chargingEffects = {
			  thirdPersonAnim = 419,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 423
			},
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.2
			}
		  },
		  multiHitCheckDurationSec = 0.25,
		  knockbackMultiplier = {
			vertical = 1.1,
			horizontal = 1.2
		  },
		  attackRange = 15,
		  firstPersonSwingAnimations = { 420, 421 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  applyCooldownOnMiss = true,
		  damage = 48
		},
		description = "Deal large amounts of knockback to enemies. Downgrades to an Iron Great Hammer upon death.",
		displayName = "Diamond Great Hammer"
	  },
	  easter_egg_projectile = {
		image = "rbxassetid://13031413739",
		hotbarFillRight = true,
		displayName = "EGG"
	  },
	  clay_blue = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 11,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765574", "rbxassetid://16991765574", "rbxassetid://16991765574", "rbxassetid://16991765574", "rbxassetid://16991765574", "rbxassetid://16991765574" }
		  }
		},
		image = "rbxassetid://7884367119",
		displayName = "Blue Clay"
	  },
	  diamond_scythe = {
		replaces = { "stone_scythe", "stone_scythe", "iron_scythe" },
		image = "rbxassetid://13832903875",
		sharingDisabled = true,
		damage = 42,
		description = "Attack enemies from farther away and pull them toward you. Downgrades to Iron Scythe on death.",
		sword = {
		  chargedAttack = {
			disableOnGrounded = true,
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 2,
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			bonusDamage = 4
		  },
		  idleAnimation = 415,
		  attackSpeed = 0.4,
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 42
		},
		displayName = "Diamond Scythe",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  emerald_boots = {
		armor = {
		  damageReductionMultiplier = 0.2,
		  slot = 2
		},
		image = "rbxassetid://6931675942",
		sharingDisabled = true,
		displayName = "Emerald Boots"
	  },
	  granite = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072525939", "rbxassetid://9072525939", "rbxassetid://9072525939", "rbxassetid://9072525939", "rbxassetid://9072525939", "rbxassetid://9072525939" }
		  }
		},
		image = "rbxassetid://9072553261",
		displayName = "Granite"
	  },
	  rocket_belt = {
		image = "rbxassetid://10480113919",
		description = "The moment you doubt whether you can fly, you cease forever to be able to do it.",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  cooldown = 10
		},
		displayName = "Rocket Belt"
	  },
	  tesla_trap = {
		image = "rbxassetid://7498163110",
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 18,
		  seeThrough = true,
		  collectionServiceTags = { "tesla-trap" },
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 8022
		  } }
		},
		displayName = "Tesla Coil Trap"
	  },
	  zipline = {
		image = "rbxassetid://7051148904",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "zipline" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		displayName = "Zipline Launcher"
	  },
	  void_dirt = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 3
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://15958116043", "rbxassetid://15958116043", "rbxassetid://15958116043", "rbxassetid://15958116043", "rbxassetid://15958116043", "rbxassetid://15958116043" }
		  }
		},
		displayName = "Void Dirt"
	  },
	  turtle_shell = {
		image = "rbxassetid://9006935204",
		maxStackSize = {
		  amount = 1
		},
		displayName = "Turtle Shell"
	  },
	  spirit_tier_3 = {
		image = "rbxassetid://90992798955903",
		description = "Upgrades your current spirit tier, making your spirits stronger.",
		displayName = "Spirit Tier III"
	  },
	  heat_seeking_rock = {
		firstPerson = {
		  scale = 0.7
		},
		image = "rbxassetid://7681398025",
		guidedProjectileSource = {
		  guidedProjectile = "heat_seeking_rock",
		  consumeItem = "heat_seeking_rock"
		},
		displayName = "Heat Seeking Rock"
	  },
	  moss_block = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 48
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10866261237", "rbxassetid://10866261237", "rbxassetid://10866261237", "rbxassetid://10866261237", "rbxassetid://10866261237", "rbxassetid://10866261237" },
			materialColor = { nil, nil, nil, nil, nil }
		  }
		},
		image = "rbxassetid://10866497548",
		displayName = "Moss Block"
	  },
	  flag = {
		footstepSound = 2,
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12006
		  } },
		  blastProof = true,
		  breakType = "wood",
		  health = 18,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "flag" },
		  seeThrough = true,
		  breakSound = nil
		},
		displayName = "Flag"
	  },
	  ice_fishing_rod = {
		image = "rbxassetid://7807308581",
		firstPerson = {
		  verticalOffset = -1
		},
		displayName = "Fishing Rod"
	  },
	  red_sandstone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 179
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7843853920", "rbxassetid://7843853920", "rbxassetid://7843853920", "rbxassetid://7843853920", "rbxassetid://7843853920", "rbxassetid://7843853920" }
		  }
		},
		image = "rbxassetid://7884370687",
		displayName = "Red Sandstone"
	  },
	  crook = {
		displayName = "Crook"
	  },
	  sparkling_apple_juice = {
		consumable = {
		  potion = true,
		  consumeTime = 1
		},
		image = "rbxassetid://11967427500",
		description = "Drink to gain a one minute speed and jump boost!",
		displayName = "Sparkling Apple Juice"
	  },
	  glitch_taser = {
		glitched = true,
		image = "rbxassetid://7911162966",
		pickUpOverlaySound = "rbxassetid://10859056155",
		sword = {
		  attackSpeed = 6,
		  swingAnimations = { 5 },
		  knockbackMultiplier = {
			vertical = 0,
			horizontal = 0
		  },
		  swingSounds = { },
		  damage = 1
		},
		displayName = "Taser?"
	  },
	  egg_block = {
		image = "rbxassetid://3677675280",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8424
		  } },
		  unbreakable = true,
		  breakType = "wood",
		  seeThrough = true,
		  disableInventoryPickup = true,
		  disableFlamableByTeammates = true,
		  collectionServiceTags = { "egg-block" },
		  flammable = false,
		  breakSound = nil
		},
		displayName = "Collectable Egg"
	  },
	  tablet = {
		skins = { "tablet_lunar", "tablet_vampire", "tablet_cream_soda" },
		image = "rbxassetid://7290617886",
		sharingDisabled = true,
		displayName = "Tablet"
	  },
	  gashapon = {
		maxStackSize = {
		  amount = 1
		},
		image = "rbxassetid://8273441274",
		description = "Contains a random item, no refunds",
		displayName = "Blind Box"
	  },
	  warlock_staff = {
		image = "rbxassetid://15186577197",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		skins = { "warlock_staff_christmas_spirit" },
		firstPerson = {
		  scale = 0.7,
		  verticalOffset = 0.6
		},
		keepOnDeath = true,
		displayName = "Warlock Staff"
	  },
	  bee = {
		image = "rbxassetid://7343272839",
		sharingDisabled = true,
		displayName = "Bee"
	  },
	  stone_brick = {
		footstepSound = 1,
		block = {
		  blastResistance = 2,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 98
		  }, {
			blockData = 6,
			blockId = 1
		  } },
		  regenSpeed = 0.1,
		  greedyMesh = {
			textures = { "rbxassetid://16991767326", "rbxassetid://16991767326", "rbxassetid://16991767326", "rbxassetid://16991767326", "rbxassetid://16991767326", "rbxassetid://16991767326" }
		  },
		  health = 75
		},
		image = "rbxassetid://7884372079",
		displayName = "Stone Brick"
	  },
	  rainbow_pot_of_gold = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 1000,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "LuckyBlock" },
		  luckyBlock = {
			categories = { "rainbow" },
			timeBetweenDropsSec = 0.2,
			allowedPolarity = { "positive" },
			drops = { {
			  luckMultiplier = 2
			}, {
			  luckMultiplier = 2
			}, {
			  luckMultiplier = 4
			} }
		  },
		  minecraftConversions = { {
			blockId = 658
		  } }
		},
		displayName = "Rainbow Pot of Gold"
	  },
	  tennis_ball = {
		hotbarFillRight = true,
		image = "rbxassetid://10392205271",
		description = "Explosive ammo for the tennis racket.",
		displayName = "Exploding Tennis Ball"
	  },
	  wood_plank_maple = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 4,
			blockId = 5
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991767778", "rbxassetid://16991767778", "rbxassetid://16991767778", "rbxassetid://16991767778", "rbxassetid://16991767778", "rbxassetid://16991767778" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884372787",
		displayName = "Maple Wood Plank"
	  },
	  bed = {
		footstepSound = 2,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12005
		  } },
		  blastProof = true,
		  noRegen = true,
		  blastResistance = 10000000,
		  breakType = "wood",
		  health = 18,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "bed" },
		  healthType = 1,
		  breakSound = nil
		},
		displayName = "Bed"
	  },
	  snowball = {
		maxStackSize = {
		  amount = 80
		},
		image = "rbxassetid://7911163294",
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "snowball" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8165640372" },
		  fireDelaySec = 0.22
		},
		displayName = "Snowball"
	  },
	  iron_chainsaw = {
		displayName = "FP Iron Chainsaw"
	  },
	  boba_blaster = {
		thirdPerson = {
		  holdAnimation = 148
		},
		image = "rbxassetid://9188763408",
		projectileSource = {
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  thirdPerson = {
			fireAnimation = 149
		  },
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "boba_pearl" },
		  maxStrengthChargeSec = 0.6,
		  activeReload = true,
		  launchSound = { "rbxassetid://9185484755" },
		  walkSpeedMultiplier = 0.4
		},
		displayName = "Boba Blaster"
	  },
	  global_generator_gadget = {
		gadget = true,
		image = "rbxassetid://15579417392",
		description = "Used to create a global generator above its position.",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "CreativeGadget" },
		  minecraftConversions = { {
			blockId = 9005
		  } },
		  breakableOnlyByHosts = true
		},
		displayName = "Global Generator Gadget"
	  },
	  blunderbuss = {
		image = "rbxassetid://10722841562",
		projectileSource = {
		  projectileType = nil,
		  launchSound = { "rbxassetid://10714200509" },
		  fireDelaySec = 0.7
		},
		displayName = "Blunderbuss"
	  },
	  pinata = {
		image = "rbxassetid://10013673974",
		sharingDisabled = true,
		footstepSound = 1,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 35,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "piggy-bank" },
		  minecraftConversions = { {
			blockId = 8013
		  } },
		  seeThrough = true
		},
		displayName = "Piñata"
	  },
	  player_vacuum = {
		image = "rbxassetid://9679750852",
		displayName = "Vacuum"
	  },
	  mushrooms = {
		image = "rbxassetid://9134534696",
		description = "Alchemist crafting material.",
		displayName = "Mushrooms"
	  },
	  clay_yellow = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 4,
			blockId = 159
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766313", "rbxassetid://16991766313", "rbxassetid://16991766313", "rbxassetid://16991766313", "rbxassetid://16991766313", "rbxassetid://16991766313" }
		  }
		},
		image = "rbxassetid://7884368673",
		displayName = "Yellow Clay"
	  },
	  robbery_ball = {
		image = "rbxassetid://7977038485",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "robbery_ball" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Robbery Ball"
	  },
	  chicken_shop_item = {
		image = "rbxassetid://13990235477",
		displayName = "Egg"
	  },
	  leather_boots = {
		armor = {
		  damageReductionMultiplier = 0.08,
		  slot = 2
		},
		image = "rbxassetid://6855466456",
		sharingDisabled = true,
		displayName = "Leather Boots"
	  },
	  feather_bow = {
		skins = { "feather_bow_demon_empress_vanessa" },
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 1,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  ammoItemTypes = { "arrow" },
		  walkSpeedMultiplier = 0.25,
		  maxStrengthChargeSec = 0.9,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.25
		},
		image = "rbxassetid://6869295332",
		displayName = "Feather Bow"
	  },
	  glitch_guitar = {
		glitched = true,
		image = "rbxassetid://12509567989",
		pickUpOverlaySound = "rbxassetid://10859056155",
		displayName = "Guitar?"
	  },
	  dragon_beath = {
		projectileSource = {
		  activeReload = true,
		  projectileType = nil,
		  launchSound = { "rbxassetid://9252994838" },
		  fireDelaySec = 3
		},
		description = "Source of the void energy",
		displayName = "Dragon Breath"
	  },
	  glitch_apple = {
		glitched = true,
		image = "rbxassetid://6985765179",
		pickUpOverlaySound = "rbxassetid://10859056155",
		maxStackSize = {
		  amount = 4
		},
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		displayName = "Apple?"
	  },
	  volley_arrow = {
		image = "rbxassetid://6869295400",
		displayName = "Volley Arrow"
	  },
	  bee_net = {
		image = "rbxassetid://7343519004",
		sharingDisabled = true,
		displayName = "Bee Net"
	  },
	  smoke_bomb = {
		image = "rbxassetid://8532898334",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  cancelOnDamage = true,
		  consumeTime = 0.5
		},
		displayName = "Smoke Bomb"
	  },
	  rocket_launcher = {
		image = "rbxassetid://7680994780",
		projectileSource = {
		  activeReload = true,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "rocket_launcher_missile" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://7681584765" },
		  fireDelaySec = 2.2
		},
		displayName = "Rocket Launcher"
	  },
	  rocket_launcher_missile = {
		image = "rbxassetid://7682148316",
		hotbarFillRight = true,
		displayName = "Rocket"
	  },
	  ufo_deploy = {
		image = "rbxassetid://11977366776",
		consumable = {
		  consumeTime = 3,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "UFO"
	  },
	  pirate_sword_fp = {
		image = "rbxassetid://10729541408",
		displayName = "Pirate Sword"
	  },
	  zipline_base = {
		image = "rbxassetid://7051148904",
		block = {
		  seeThrough = true,
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 8017
		  } },
		  health = 20
		},
		displayName = "Zipline Base"
	  },
	  jump_boots = {
		armor = {
		  damageReductionMultiplier = 0.08,
		  slot = 2
		},
		image = "rbxassetid://7911163797",
		displayName = "Jump Boots"
	  },
	  emerald_helmet = {
		armor = {
		  damageReductionMultiplier = 0.24,
		  slot = 0
		},
		image = "rbxassetid://6931675766",
		sharingDisabled = true,
		displayName = "Emerald Helmet"
	  },
	  sleigh_deploy = {
		image = "rbxassetid://99857605333058",
		consumable = {
		  consumeTime = 3,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Sleigh"
	  },
	  glitched_lucky_block = {
		glitched = true,
		image = "rbxassetid://10866119664",
		pickUpOverlaySound = "rbxassetid://10859056155",
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 17,
		  greedyMesh = {
			textures = { "rbxassetid://10849259593", "rbxassetid://10849259593", "rbxassetid://10849259593", "rbxassetid://10849259593", "rbxassetid://10849259593", "rbxassetid://10849259593" }
		  },
		  minecraftConversions = { {
			blockId = 12014
		  } },
		  collectionServiceTags = { "GlitchedLuckyBlock" },
		  luckyBlock = {
			categories = { "glitch" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  disableInventoryPickup = true
		},
		displayName = "Glitched Lucky Block"
	  },
	  rainbow_staff = {
		multiProjectileSource = {
		  rainbow_bridge = {
			maxStrengthChargeSec = 0.25,
			cooldownId = "rainbow_staff",
			thirdPerson = {
			  fireAnimation = 25
			},
			fireDelaySec = 8,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529727", "rbxassetid://10969529817", "rbxassetid://10969529761" },
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  rainbow_bridge_gadget = {
			maxStrengthChargeSec = 0.25,
			cooldownId = "rainbow_staff",
			thirdPerson = {
			  fireAnimation = 25
			},
			fireDelaySec = 8,
			minStrengthScalar = 0.7692307692307692,
			projectileType = nil,
			launchSound = { "rbxassetid://10969529727", "rbxassetid://10969529817", "rbxassetid://10969529761" },
			firstPerson = {
			  fireAnimation = 14
			}
		  }
		},
		image = "rbxassetid://12813669578",
		description = "Create rainbow bridges that give a speed boost for you and your team!",
		displayName = "Mirage Staff"
	  },
	  soulvine_seed = {
		image = "rbxassetid://100872989657438",
		description = "Grants nearby allies a 2% damage buff when fully grown",
		sharingDisabled = true,
		placesBlock = {
		  blockType = "soulvine_flower"
		},
		displayName = "Soulvine Seed"
	  },
	  hotdog_bat = {
		image = "rbxassetid://14191270696",
		description = "The time has come to play with your food",
		sword = {
		  attackSpeed = 1,
		  swingAnimations = { 162 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.7
			},
			minChargeTimeSec = 0.3,
			chargedSwingAnimations = { 162 },
			attackCooldown = 0.7,
			maxChargeTimeSec = 1.5,
			chargedSwingSounds = { },
			bonusKnockback = {
			  vertical = 0,
			  horizontal = 0.3
			},
			firstPersonChargedSwingAnimations = { 166 },
			chargingEffects = {
			  thirdPersonAnim = 161,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 167
			}
		  },
		  knockbackMultiplier = {
			vertical = 0,
			horizontal = 0.3
		  },
		  attackRange = 17.3,
		  firstPersonSwingAnimations = { 166 },
		  swingSounds = { },
		  applyCooldownOnMiss = true,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Hotdog Bat"
	  },
	  gumdrop_bounce_pad = {
		image = "rbxassetid://8270466544",
		block = {
		  minecraftConversions = { {
			blockId = 8005
		  } },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  disableEnemyInventoryPickup = true,
		  collectionServiceTags = { "launch-pad" },
		  seeThrough = true,
		  health = 2
		},
		sharingDisabled = true,
		displayName = "Gumdrop Bounce Pad"
	  },
	  wizard_staff_3 = {
		image = "rbxassetid://13397121485",
		sharingDisabled = true,
		skins = { "wizard_staff_3_anniversary", "gold_victorious_wizard_staff_3", "platinum_victorious_wizard_staff_3", "diamond_victorious_wizard_staff_3", "emerald_victorious_wizard_staff_3", "nightmare_victorious_wizard_staff_3" },
		replaces = { "wizard_staff", "wizard_staff_2" },
		multiProjectileSource = {
		  lightning_strike = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 25
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  },
		  electric_orb = {
			cooldownId = "wizard_staff",
			fireDelaySec = 1,
			projectileType = nil,
			thirdPerson = {
			  fireAnimation = 26
			},
			firstPerson = {
			  fireAnimation = 14
			}
		  }
		},
		displayName = "Wizard Staff III"
	  },
	  thorns = {
		image = "rbxassetid://9134549615",
		description = "Alchemist crafting material.",
		displayName = "Thorns"
	  },
	  lasso = {
		image = "rbxassetid://7192710930",
		sharingDisabled = true,
		skins = { "lasso_mummy", "lasso_wrangler_reindeer_lassy" },
		projectileSource = {
		  maxStrengthChargeSec = 0.5,
		  fireDelaySec = 8,
		  walkSpeedMultiplier = 0.25,
		  projectileType = nil,
		  minStrengthScalar = 0.5,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		displayName = "Lasso"
	  },
	  rainbow_bow = {
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  ammoItemTypes = { "rainbow_arrow" },
		  walkSpeedMultiplier = 0.25,
		  maxStrengthChargeSec = 0.5,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.25
		},
		image = "rbxassetid://12811607153",
		description = "Shoot rainbow arrows that split into many different explosions.",
		displayName = "Spectrum Bow"
	  },
	  halloween_lucky_block = {
		image = "rbxassetid://15093670805",
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  greedyMesh = {
			textures = { "rbxassetid://17367713724", "rbxassetid://17367713724", "rbxassetid://17367713680", "rbxassetid://17367713680", "rbxassetid://17367713680", "rbxassetid://17367713680" }
		  },
		  collectionServiceTags = { "HalloweenLuckyBlock" },
		  luckyBlock = {
			categories = { "halloween" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  disableInventoryPickup = true
		},
		displayName = "Halloween Lucky Block"
	  },
	  chicken_emerald = {
		image = "rbxassetid://13980233671",
		displayName = "Emerald Chicken"
	  },
	  beehive = {
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8020
		  } },
		  breakType = "stone",
		  health = 25,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "beehive" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		image = "rbxassetid://7343272692",
		sharingDisabled = true,
		displayName = "Beehive"
	  },
	  block_repair_tool = {
		image = "rbxassetid://130181835534959",
		description = "Use to repair blocks",
		blockRepair = { },
		sharingDisabled = true,
		displayName = "Repair Tool"
	  },
	  flower_purple = {
		block = {
		  dontPlaceInPublicMatch = true,
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 31
		  }, {
			blockId = 37
		  } },
		  seeThrough = true,
		  canReplace = true,
		  unbreakable = true
		},
		displayName = "Purple Flower"
	  },
	  diamond_pickaxe = {
		image = "rbxassetid://6875481462",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  stone = 20
		},
		displayName = "Diamond Pickaxe"
	  },
	  siege_tnt = {
		image = "rbxassetid://14719641593",
		sharingDisabled = true,
		footstepSound = 3,
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://14719641761", "rbxassetid://14719641761", "rbxassetid://14719641708", "rbxassetid://14719641708", "rbxassetid://14719641708", "rbxassetid://14719641708" }
		  },
		  health = 1
		},
		displayName = "Siege TNT"
	  },
	  damage_banner = {
		image = "rbxassetid://9557924197",
		description = "Place banner that grants 'Fire II' to yourself and any team member inside banner radius.",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 40,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "flag-kit" },
		  unbreakableByTeammates = true,
		  minecraftConversions = { {
			blockId = 12007
		  } }
		},
		sharingDisabled = true,
		displayName = "Fire Banner"
	  },
	  impulse_gun = {
		image = "rbxassetid://13629029360",
		description = "Use with caution.",
		maxStackSize = {
		  amount = 1
		},
		thirdPerson = {
		  holdAnimation = 53
		},
		displayName = "Impulse Gun"
	  },
	  barbarian_helmet = {
		armor = {
		  damageReductionMultiplier = 1,
		  slot = 0
		},
		image = "rbxassetid://14559460074",
		sharingDisabled = true,
		displayName = "Barbarian Helmet"
	  },
	  diamond_axe = {
		image = "rbxassetid://6883832539",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  wood = 17
		},
		displayName = "Diamond Axe"
	  },
	  small_bush = {
		block = {
		  dontPlaceInPublicMatch = true,
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 175
		  } },
		  seeThrough = true,
		  canReplace = true,
		  unbreakable = true
		},
		displayName = "Small Bush"
	  },
	  festive_sword_wave1 = {
		displayName = "Festive Sword Wave1"
	  },
	  stone_player_block = {
		footstepSound = 0,
		block = {
		  greedyMesh = {
			textures = { "rbxassetid://8536406963" }
		  },
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  health = 6,
		  minecraftConversions = { {
			blockId = 8008
		  } },
		  disableInventoryPickup = true
		},
		displayName = "Stone Player Block"
	  },
	  iron_sword = {
		image = "rbxassetid://6875481281",
		description = "Downgrades to a Stone Sword upon death.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 30
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Iron Sword"
	  },
	  firework_arrow = {
		image = "rbxassetid://8665953060",
		hotbarFillRight = true,
		displayName = "Firework Arrow"
	  },
	  void_chainsaw = {
		displayName = "FP Void Chainsaw"
	  },
	  knockback_fish = {
		image = "rbxassetid://7976208326",
		description = "Deals massive knockback but minimal damage.",
		sword = {
		  swingSounds = { "rbxassetid://7396760496" },
		  knockbackMultiplier = {
			horizontal = 2
		  },
		  attackSpeed = 0.3,
		  damage = 1
		},
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Knockback Fish"
	  },
	  spider_web = {
		image = "rbxassetid://15056224013",
		description = "When an enemy steps on the Spider Web trap they will be stunned and attacked by a spider.",
		maxStackSize = {
		  amount = 7
		},
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 8003
		  } },
		  collectionServiceTags = { "spider_web" },
		  maxPlaced = 7,
		  health = 1
		},
		displayName = "Spider Web"
	  },
	  aquamarine_lantern = {
		footstepSound = 1,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 169
		  } },
		  health = 10,
		  pointLight = {
			Color = nil,
			Brightness = 0.7,
			Range = 27,
			Shadows = true
		  },
		  greedyMesh = {
			textures = { "rbxassetid://12946930317", "rbxassetid://12946930317", "rbxassetid://12946930317", "rbxassetid://12946930317", "rbxassetid://12946930317", "rbxassetid://12946930317" }
		  }
		},
		image = "rbxassetid://12948863284",
		displayName = "Aquamarine Lantern"
	  },
	  popup_cube = {
		image = "rbxassetid://7976208116",
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "popup_cube" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		displayName = "Popup Tower"
	  },
	  wood_sword = {
		image = "rbxassetid://6875480974",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Wood Sword"
	  },
	  stone_axe = {
		image = "rbxassetid://6875481224",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  wood = 8
		},
		displayName = "Stone Axe"
	  },
	  flower_crossbow = {
		image = "rbxassetid://13278689419",
		sharingDisabled = true,
		skins = { "flower_crossbow_frost_queen", "gold_victorious_flower_crossbow", "platinum_victorious_flower_crossbow", "diamond_victorious_flower_crossbow", "emerald_victorious_flower_crossbow", "nightmare_victorious_flower_crossbow" },
		projectileSource = {
		  multiShotChargeTime = 1.3,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		displayName = "Floral Crossbow"
	  },
	  glitch_big_shield = {
		glitched = true,
		image = "rbxassetid://7863380423",
		pickUpOverlaySound = "rbxassetid://10859056155",
		consumable = {
		  consumeTime = 1.8
		},
		displayName = "Big Shield?"
	  },
	  glitch_void_sword = {
		glitched = true,
		image = "rbxassetid://9873021357",
		sword = {
		  attackSpeed = 0.3,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Void Sword?"
	  },
	  break_speed_axolotl = {
		image = "rbxassetid://7863779927",
		displayName = "Break Speed Axolotl"
	  },
	  flying_cloud_deploy = {
		consumable = {
		  consumeTime = 1,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		image = "rbxassetid://13619831247",
		description = "Weaponized floating cloud of destruction",
		displayName = "Flying Cloud"
	  },
	  smoke_grenade = {
		projectileSource = {
		  fireDelaySec = 0.4,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.4,
		  ammoItemTypes = { "smoke_grenade" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = { }
		},
		image = "rbxassetid://7681033200",
		description = "Creates a blast of smoke where it lands.",
		displayName = "Smoke Grenade"
	  },
	  wool_red = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768524", "rbxassetid://16991768524", "rbxassetid://16991768524", "rbxassetid://16991768524", "rbxassetid://16991768524", "rbxassetid://16991768524" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 14,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923579098",
		displayName = "Red Wool"
	  },
	  wood_great_hammer = {
		image = "rbxassetid://13832631568",
		sharingDisabled = true,
		description = "Deal large amounts of knockback to enemies.",
		sword = {
		  attackSpeed = 0.6,
		  swingAnimations = { 416, 417 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.9
			},
			minChargeTimeSec = 0.75,
			chargedSwingAnimations = { 418 },
			attackCooldown = 0.65,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 0.75,
			chargedSwingSounds = { "rbxassetid://11715550908" },
			bonusDamage = 8.049999999999999,
			firstPersonChargedSwingAnimations = { 422 },
			chargingEffects = {
			  thirdPersonAnim = 419,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 423
			},
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.2
			}
		  },
		  multiHitCheckDurationSec = 0.25,
		  knockbackMultiplier = {
			vertical = 1.1,
			horizontal = 1.2
		  },
		  attackRange = 15,
		  firstPersonSwingAnimations = { 420, 421 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  applyCooldownOnMiss = true,
		  damage = 23
		},
		damage = 23,
		displayName = "Wood Great Hammer"
	  },
	  stone_gauntlets = {
		replaces = { "wood_gauntlets" },
		description = "Punch rapidly to deal more damage with combos. Downgrades to Wood Gauntlets upon death.",
		sword = {
		  idleAnimation = 430,
		  swingSounds = { },
		  ignoreDamageCooldown = true,
		  attackSpeed = 0.21,
		  damage = 20
		},
		displayName = "Stone Gauntlets",
		image = "rbxassetid://14839096152",
		sharingDisabled = true,
		damage = 20,
		disableFirstPersonHoldAnimation = true,
		firstPerson = {
		  scale = 1,
		  verticalOffset = -1.2
		}
	  },
	  orions_belt_bow = {
		projectileSource = {
		  multiShotCount = 3,
		  chargeBeginSound = { "rbxassetid://7987032429" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  minStrengthScalar = 0.25,
		  multiShot = true,
		  ammoItemTypes = { "star" },
		  walkSpeedMultiplier = 0.25,
		  maxStrengthChargeSec = 0.5,
		  launchSound = { "rbxassetid://10969529761" },
		  multiShotDelay = 0.1
		},
		image = "rbxassetid://11774789128",
		description = "Shoots a constellation of explosive stars.",
		displayName = "Constellation Bow"
	  },
	  rageblade = {
		image = "rbxassetid://7051149237",
		sharingDisabled = true,
		skins = { "rageblade_deep_void", "rageblade_victorious", "rageblade_bunny", "rageblade_corrupted" },
		sword = {
		  attackSpeed = 0.24,
		  damage = 70
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Rageblade"
	  },
	  frosty_hammer = {
		image = "rbxassetid://11831565831",
		description = "",
		keepOnDeath = true,
		sword = {
		  attackSpeed = 0.3,
		  noApplyDamageCooldown = false,
		  ignoreDamageCooldown = false,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 15 },
		  swingAnimations = { 335, 336, 337 },
		  hitSound = "rbxassetid://11715551081",
		  applyCooldownOnMiss = true,
		  damage = 25
		},
		sharingDisabled = true,
		displayName = "Frosty Hammer"
	  },
	  wood_axe = {
		image = "rbxassetid://6875481089",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  wood = 4
		},
		displayName = "Wood Axe"
	  },
	  tinker_weapon_4 = {
		image = "rbxassetid://17016574837",
		sharingDisabled = true,
		replaces = { "tinker_weapon_3" },
		skins = { "fish_tank_emerald_chainsaw" },
		sword = {
		  attackRange = 17,
		  attackSpeed = 0.35,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Emerald Chainsaw"
	  },
	  purple_hay_bale = {
		image = "rbxassetid://12291381738",
		description = "Used to feed Fire Sheep",
		displayName = "Purple Hay Bale"
	  },
	  clay = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 82
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7861526072", "rbxassetid://7861526072", "rbxassetid://7861526072", "rbxassetid://7861526072", "rbxassetid://7861526072", "rbxassetid://7861526072" }
		  }
		},
		image = "rbxassetid://7884366829",
		displayName = "Clay"
	  },
	  party_hat_missile = {
		image = "rbxassetid://17580323459",
		hotbarFillRight = true,
		displayName = "Hat Missile"
	  },
	  hang_glider = {
		firstPerson = {
		  scale = 0.7
		},
		image = "rbxassetid://8216181054",
		maxStackSize = {
		  amount = 1
		},
		displayName = "Hang Glider"
	  },
	  frozen_fortress = {
		image = "rbxassetid://15625717321",
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "frozen_fortress" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		displayName = "Frozen Fortress"
	  },
	  wood_pickaxe = {
		image = "rbxassetid://6875481046",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  stone = 5
		},
		displayName = "Wood Pickaxe"
	  },
	  sticky_slime = {
		removeFromCustoms = true,
		image = "rbxassetid://15295064061",
		description = "Attracts nearby resources with a chance to duplicate them.",
		displayName = "Sticky Slime"
	  },
	  bomb_controller = {
		image = "rbxassetid://10648652428",
		description = "don't press the red button",
		displayName = "bomb controller"
	  },
	  fishing_rod = {
		image = "rbxassetid://7807308581",
		sharingDisabled = true,
		projectileSource = {
		  projectileType = nil,
		  launchSound = { "rbxassetid://7806060976" },
		  fireDelaySec = 0
		},
		firstPerson = {
		  verticalOffset = -1
		},
		displayName = "Fishing Rod"
	  },
	  portal_gun = {
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 151,
			aimAnimation = 150
		  },
		  projectileType = nil,
		  activeReload = true,
		  fireDelaySec = 3
		},
		image = "rbxassetid://9378655884",
		description = "Create portal rifts that can be linked and traveled between.",
		displayName = "Portal Gun"
	  },
	  toy_hammer = {
		image = "rbxassetid://10086863582",
		description = "Hit players for huge knockback",
		sword = {
		  hitSound = "rbxassetid://10084313910",
		  knockbackMultiplier = {
			horizontal = 2.5
		  },
		  attackSpeed = 0.3,
		  damage = 10
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Toy Hammer"
	  },
	  speed_boots = {
		armor = {
		  damageReductionMultiplier = 0.08,
		  slot = 2
		},
		image = "rbxassetid://7911163144",
		displayName = "Speed Boots"
	  },
	  watering_can = {
		image = "rbxassetid://6915423754",
		displayName = "Watering Can"
	  },
	  glitch_trumpet = {
		glitched = true,
		image = "rbxassetid://10857089714",
		description = "Make some noise!",
		pickUpOverlaySound = "rbxassetid://10859056155",
		thirdPerson = {
		  holdAnimation = 148
		},
		displayName = "Trumpet?"
	  },
	  steel_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 15
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10859697716", "rbxassetid://10859697716", "rbxassetid://10859697716", "rbxassetid://10859697716", "rbxassetid://10859697716", "rbxassetid://10859697716" }
		  }
		},
		image = "rbxassetid://10859697667",
		displayName = "Steel Block"
	  },
	  barrel = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 84
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://14968393691", "rbxassetid://14968393691", "rbxassetid://14968393626", "rbxassetid://14968393626", "rbxassetid://14968393626", "rbxassetid://14968393626" }
		  }
		},
		image = "rbxassetid://14968393558",
		displayName = "Barrel"
	  },
	  og_emerald_sword = {
		image = "rbxassetid://6931677551",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 55
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Emerald Sword"
	  },
	  lobby_shrink_potion = {
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		image = "rbxassetid://7911163448",
		description = "Consume potion to grow yourself a bigger head.",
		displayName = "Shrink Potion"
	  },
	  bookshelf = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 47
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10866360672", "rbxassetid://10866360672", "rbxassetid://10866119486", "rbxassetid://10866119486", "rbxassetid://10866119486", "rbxassetid://10866119486" }
		  },
		  health = 15
		},
		image = "rbxassetid://10866360547",
		displayName = "Bookshelf"
	  },
	  styx_exit_portal = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  disableEnemyInventoryPickup = true,
		  health = 20,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "styx-exit-portal" },
		  unbreakableByTeammates = true,
		  breakType = "stone"
		},
		image = "rbxassetid://17009847852",
		sharingDisabled = true,
		displayName = "Confluence Portal"
	  },
	  black_market_upgrade_3 = {
		image = "rbxassetid://95888205553099",
		description = "Unlocks: (Invis Potion)",
		sharingDisabled = true,
		consumable = {
		  consumeTime = 0.5,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Black Market Upgrade 3"
	  },
	  ballista = {
		image = "rbxassetid://17858940835",
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  breakSound = nil,
		  breakType = "stone",
		  health = 8,
		  seeThrough = true,
		  collectionServiceTags = { "Ballista" },
		  disableInventoryPickup = false,
		  projectileSource = {
			relativeOverride = {
			  relX = 0,
			  relY = 0,
			  relZ = 0
			},
			projectileType = nil,
			launchSound = { "rbxassetid://17845137969", "rbxassetid://17845138487", "rbxassetid://17845138212", "rbxassetid://17845137556" },
			fireDelaySec = 1.8
		  }
		},
		displayName = "Ballista"
	  },
	  melon_seeds = {
		image = "rbxassetid://6956387796",
		placesBlock = {
		  blockType = "melon"
		},
		displayName = "Melon Seeds"
	  },
	  mass_hammer = {
		image = "rbxassetid://8938480294",
		sword = {
		  swingSounds = { },
		  cooldown = {
			cooldownBar = {
			  color = nil
			}
		  },
		  attackSpeed = 1.5,
		  attackRange = 15,
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			vertical = 1.2,
			horizontal = 1.2
		  },
		  applyCooldownOnMiss = true,
		  damage = 35
		},
		displayName = "Mass Hammer"
	  },
	  apple = {
		image = "rbxassetid://6985765179",
		maxStackSize = {
		  amount = 4
		},
		skins = { "apple_spirit" },
		consumable = {
		  requiresMissingHealth = true,
		  consumeTime = 0.8
		},
		displayName = "Health Apple"
	  },
	  stone_scythe = {
		replaces = { "stone_scythe" },
		image = "rbxassetid://13832902442",
		sharingDisabled = true,
		damage = 25,
		description = "Attack enemies from farther away and pull them toward you. Downgrades to Wood Scythe on death.",
		sword = {
		  chargedAttack = {
			disableOnGrounded = true,
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 2,
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			bonusDamage = 4
		  },
		  idleAnimation = 415,
		  attackSpeed = 0.4,
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 25
		},
		displayName = "Stone Scythe",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  magma_block = {
		footstepSound = 1,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 213
		  } },
		  blastProof = true,
		  breakType = "stone",
		  health = 10,
		  greedyMesh = {
			textures = { "rbxassetid://9439108691", "rbxassetid://9439108691", "rbxassetid://9439108691", "rbxassetid://9439108691", "rbxassetid://9439108691", "rbxassetid://9439108691" }
		  },
		  breakSound = nil,
		  collectionServiceTags = { "MagmaBlock" },
		  pointLight = {
			Color = nil,
			Brightness = 4,
			Range = 8,
			Shadows = true
		  },
		  breakableOnlyByHosts = true
		},
		image = "rbxassetid://9439108582",
		displayName = "Magma Block"
	  },
	  hunters_echo = {
		consumable = {
		  animationOverride = 262,
		  disableSoundRepeat = true,
		  closeOnComplete = true,
		  consumeTime = 2,
		  soundOverride = "rbxassetid://10999499246",
		  cancelOnDamage = true
		},
		image = "rbxassetid://14978481226",
		description = "Emit a global echo that will briefly reveal all hiders",
		displayName = "Hunter's Echo"
	  },
	  iron_dao = {
		daoSword = {
		  armorMultiplier = 0.8,
		  dashDamage = 23.1
		},
		image = "rbxassetid://8665071395",
		description = "Charge to dash forward. Downgrades to a Stone Dao upon death.",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		skins = { "iron_dao_tiger", "iron_dao_victorious", "iron_dao_cursed" },
		sword = {
		  daoDash = true,
		  attackSpeed = 0.3,
		  damage = 30
		},
		sharingDisabled = true,
		displayName = "Iron Dao"
	  },
	  spirit_dagger_left = {
		skins = { "silentnight_spirit_dagger_left", "gold_victorious_spirit_dagger_left", "platinum_victorious_spirit_dagger_left", "diamond_victorious_spirit_dagger_left", "nightmare_victorious_spirit_dagger_left" },
		image = "rbxassetid://6875480974",
		sword = {
		  swingAnimations = { 5 },
		  attackSpeed = 0.3,
		  damage = 0
		},
		displayName = "Spirit Dagger"
	  },
	  void_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.34,
		  slot = 1
		},
		image = "rbxassetid://9866786852",
		displayName = "Void Chestplate"
	  },
	  lucky_snow_cone = {
		consumable = {
		  statusEffect = {
			incrementStacks = 5,
			statusEffectType = "snow_cone"
		  },
		  consumeTime = 0.5
		},
		image = "rbxassetid://10489888627",
		description = "Worth five Snow Cone stacks!",
		displayName = "Lucky Snow Cone"
	  },
	  large_rock = {
		image = "rbxassetid://7681398025",
		projectileSource = {
		  fireDelaySec = 0.4,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  ammoItemTypes = { "large_rock" }
		},
		displayName = "Large Rock (Very)"
	  },
	  firework_crate = {
		image = "rbxassetid://15798166084",
		description = "Rain down fire on your enemies!",
		footstepSound = 3,
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 8005
		  } },
		  health = 1
		},
		displayName = "Firework Crate"
	  },
	  tactical_crossbow = {
		image = "rbxassetid://7051149016",
		sharingDisabled = true,
		skins = { "tactical_crossbow_lunar_dragon" },
		projectileSource = {
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		displayName = "Tactical Crossbow"
	  },
	  owl_orb = {
		image = "rbxassetid://12509662844",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		skins = { "owl_orb_fire" },
		keepOnDeath = true,
		displayName = "OWL"
	  },
	  sand = {
		footstepSound = 3,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 12
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7843856590", "rbxassetid://7843856590", "rbxassetid://7843856590", "rbxassetid://7843856590", "rbxassetid://7843856590", "rbxassetid://7843856590" }
		  }
		},
		image = "rbxassetid://7884370902",
		displayName = "Sand"
	  },
	  juggernaut_boots = {
		armor = {
		  damageReductionMultiplier = 0.22,
		  slot = 2
		},
		image = "rbxassetid://8730011123",
		displayName = "Juggernaut Boots"
	  },
	  meteor_shower = {
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "meteor_shower" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		image = "rbxassetid://11774788978",
		description = "Summon a barrage of meteors!",
		displayName = "Meteor Shower"
	  },
	  flying_broom_deploy = {
		image = "rbxassetid://15115405598",
		description = "Clean up the skies with a flying broom!",
		itemCatalog = {
		  collection = 2
		},
		consumable = {
		  consumeTime = 1,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Flying Broom"
	  },
	  defense_banner = {
		image = "rbxassetid://9557924054",
		description = "Place banner that grants 'Anti Knockback' to yourself and any team member inside banner radius.",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 40,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "flag-kit" },
		  unbreakableByTeammates = true,
		  minecraftConversions = { {
			blockId = 12008
		  } }
		},
		sharingDisabled = true,
		displayName = "Defense Banner"
	  },
	  wormhole = {
		image = "rbxassetid://11192696778",
		description = "Teleport to base after 4 seconds of standing still.",
		maxStackSize = {
		  amount = 1
		},
		cooldownId = "wormhole",
		consumable = {
		  animationOverride = 38,
		  walkSpeedMultiplier = 0,
		  consumeTime = 4,
		  cancelOnDamage = true,
		  soundOverride = "rbxassetid://10999341919"
		},
		displayName = "Wormhole"
	  },
	  stone_pickaxe = {
		image = "rbxassetid://6875481184",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  stone = 8
		},
		displayName = "Stone Pickaxe"
	  },
	  serpents_touch_potion = {
		image = "rbxassetid://99777727368131",
		description = "A deadly toxin that inflicts lingering pain on those struck by the user’s weapon. (30 seconds)",
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  consumeTime = 0.8,
		  potion = true,
		  statusEffect = {
			duration = 30,
			statusEffectType = "serpents_touch_potion"
		  }
		},
		displayName = "Serpent's Touch"
	  },
	  villain_magical_girl_rapier = {
		image = "rbxassetid://16101848170",
		description = "A twisted blade borne of wrath and misery. Deal critical damage to low health enemies. 'They will see as much mercy as I once received...'",
		tierUpgradeElements = { {
		  tierDescription = { "+2 Projectiles On Enhanced Attack" }
		}, {
		  tierDescription = { "Projectiles Can Now Critically Strike" }
		}, {
		  tierDescription = { "+2 Projectiles On Enhanced Attack" }
		} },
		itemCatalog = {
		  collection = 3
		},
		sword = {
		  attackSpeed = 0.5,
		  attackRange = 12,
		  swingSounds = { },
		  respectAttackSpeedForEffects = true,
		  applyCooldownOnMiss = true,
		  damage = 44
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Villain's Magical Rapier"
	  },
	  shield_axolotl = {
		image = "rbxassetid://7863780357",
		displayName = "Shield Axolotl"
	  },
	  ice_sword = {
		image = "rbxassetid://8164577874",
		sharingDisabled = true,
		skins = { "ice_sword_tiger_brawler", "ice_sword_bunny" },
		sword = {
		  attackSpeed = 0.35,
		  damage = 47
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Ice Sword"
	  },
	  pumpkin_bomb_3 = {
		image = "rbxassetid://11403476091",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "pumpkin_bomb_3" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Jack o'Boom (Huge)"
	  },
	  c4_bomb = {
		image = "rbxassetid://10648647141",
		description = "it explodes",
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "c4_bomb" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8165640372" },
		  fireDelaySec = 0.15
		},
		hotbarFillRight = true,
		displayName = "Remote Explosive"
	  },
	  clay_pink = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 6,
			blockId = 159
		  }, {
			blockData = 2,
			blockId = 159
		  }, {
			blockData = 6,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766060", "rbxassetid://16991766060", "rbxassetid://16991766060", "rbxassetid://16991766060", "rbxassetid://16991766060", "rbxassetid://16991766060" }
		  }
		},
		image = "rbxassetid://7884368035",
		displayName = "Pink Clay"
	  },
	  forge_lucky_block = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "ForgeLuckyBlock" },
		  luckyBlock = {
			categories = { "forge" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  greedyMesh = {
			textures = { "rbxassetid://15644713593", "rbxassetid://15644713593", "rbxassetid://15644713480", "rbxassetid://15644713480", "rbxassetid://15644713480", "rbxassetid://15644713480" }
		  }
		},
		image = "rbxassetid://15644713419",
		displayName = "Forge Lucky Block"
	  },
	  diorite = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 3,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072525496", "rbxassetid://9072525496", "rbxassetid://9072525496", "rbxassetid://9072525496", "rbxassetid://9072525496", "rbxassetid://9072525496" }
		  }
		},
		image = "rbxassetid://9072525407",
		displayName = "Diorite"
	  },
	  void_portal = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  collectionServiceTags = { "VoidPortal" },
		  minecraftConversions = { {
			blockId = 8010
		  } },
		  health = 20
		},
		displayName = "Void Portal"
	  },
	  crit_star = {
		consumable = {
		  consumeTime = 1,
		  soundOverride = "None",
		  animationOverride = 187
		},
		description = "Consume to gain a crit rate buff for yourself and nearby teammates!",
		image = "rbxassetid://9866757805",
		sharingDisabled = true,
		displayName = "Crit Star"
	  },
	  oil_consumable = {
		projectileSource = {
		  walkSpeedMultiplier = 0.5,
		  ammoItemTypes = { "oil_consumable" },
		  minStrengthScalar = 0.25,
		  projectileType = nil,
		  maxStrengthChargeSec = 0.25,
		  fireDelaySec = 1.5
		},
		image = "rbxassetid://7808151981",
		sharingDisabled = true,
		displayName = "Oil Blob"
	  },
	  mythic_scythe = {
		itemCatalog = {
		  collection = 1
		},
		description = "The Nocturne's charged attack ignores a large amount of the enemy's armor. Downgrades to Diamond Scythe on death.",
		sword = {
		  chargedAttack = {
			disableOnGrounded = true,
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 2,
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			bonusDamage = 4
		  },
		  idleAnimation = 415,
		  attackSpeed = 0.4,
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 54
		},
		displayName = "Nocturne",
		image = "rbxassetid://13832902921",
		sharingDisabled = true,
		replaces = { "stone_scythe", "stone_scythe", "iron_scythe", "diamond_scythe" },
		damage = 54,
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  smoke_block = {
		image = "rbxassetid://8538034673",
		sharingDisabled = true,
		footstepSound = 0,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8006
		  } },
		  maxPlaced = 20,
		  breakType = "grass",
		  health = 6,
		  seeThrough = true,
		  collectionServiceTags = { "smoke_block" },
		  greedyMesh = {
			textures = { "rbxassetid://8536406963" }
		  },
		  breakSound = nil
		},
		displayName = "Smoke Block"
	  },
	  stone_great_hammer = {
		image = "rbxassetid://13832631765",
		sharingDisabled = true,
		replaces = { "wood_great_hammer" },
		damage = 29,
		sword = {
		  attackSpeed = 0.6,
		  swingAnimations = { 416, 417 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.9
			},
			minChargeTimeSec = 0.75,
			chargedSwingAnimations = { 418 },
			attackCooldown = 0.65,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 0.75,
			chargedSwingSounds = { "rbxassetid://11715550908" },
			bonusDamage = 10.149999999999999,
			firstPersonChargedSwingAnimations = { 422 },
			chargingEffects = {
			  thirdPersonAnim = 419,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 423
			},
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.2
			}
		  },
		  multiHitCheckDurationSec = 0.25,
		  knockbackMultiplier = {
			vertical = 1.1,
			horizontal = 1.2
		  },
		  attackRange = 15,
		  firstPersonSwingAnimations = { 420, 421 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  applyCooldownOnMiss = true,
		  damage = 29
		},
		description = "Deal large amounts of knockback to enemies. Downgrades to a Wood Great Hammer upon death.",
		displayName = "Stone Great Hammer"
	  },
	  void_growth = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 214
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://15957915625", "rbxassetid://15957915625", "rbxassetid://15957915625", "rbxassetid://15957915625", "rbxassetid://15957915625", "rbxassetid://15957915625" }
		  }
		},
		displayName = "Void Growth"
	  },
	  cannon_ball = {
		maxStackSize = {
		  amount = 2
		},
		displayName = "Cannon Ball"
	  },
	  ghost_orb = {
		image = "rbxassetid://15122215131",
		description = "A spectral orb that when hurled, turns players ghostly, making them float!",
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.4,
		  ammoItemTypes = { "ghost_orb" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		itemCatalog = {
		  collection = 2
		},
		displayName = "Ghost Orb"
	  },
	  spike_trap = {
		image = "rbxassetid://10322206238",
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 12003
		  } },
		  collectionServiceTags = { "spike_trap" },
		  maxPlaced = 14,
		  health = 20
		},
		displayName = "Spike Trap"
	  },
	  pirate_shovel = {
		image = "rbxassetid://10797226616",
		description = "Dig enemy blocks for treasure",
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  stone = 20
		},
		displayName = "Pirate Shovel"
	  },
	  flower_headhunter = {
		image = "rbxassetid://13887697290",
		description = "Nature's adaptation of the legendary Headhunter. Attracts a swarm of bees!",
		skins = { "flower_headhunter_frost_queen", "gold_victorious_flower_headhunter", "platinum_victorious_flower_headhunter", "diamond_victorious_flower_headhunter", "emerald_victorious_flower_headhunter", "nightmare_victorious_flower_headhunter" },
		projectileSource = {
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 395,
			aimAnimation = 397
		  },
		  launchSound = { "rbxassetid://13406717420", "rbxassetid://13406717139", "rbxassetid://13406717258", "rbxassetid://13406717028" },
		  firstPerson = {
			fireAnimation = 396,
			aimAnimation = 398
		  }
		},
		sharingDisabled = true,
		displayName = "Floral Headhunter"
	  },
	  pirate_gunpowder_barrel = {
		image = "rbxassetid://13465460559",
		maxStackSize = {
		  amount = 10
		},
		footstepSound = 2,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "ExplosiveBarrel" },
		  minecraftConversions = { {
			blockId = 8024
		  } }
		},
		displayName = "Gunpowder Barrel"
	  },
	  iron_boots = {
		armor = {
		  damageReductionMultiplier = 0.12,
		  slot = 2
		},
		image = "rbxassetid://6874272718",
		sharingDisabled = true,
		displayName = "Iron Boots"
	  },
	  life_headhunter = {
		replaces = { "life_crossbow" },
		description = "Does not use arrows, instead consuming health when fired. Gain life force on successful hits.",
		sharingDisabled = true,
		skins = { "life_headhunter_mummy" },
		projectileSource = {
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://128364711264624", "rbxassetid://97099816203576" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 395,
			aimAnimation = 397
		  },
		  launchSound = { "rbxassetid://101272423230044" },
		  firstPerson = {
			fireAnimation = 396,
			aimAnimation = 398
		  }
		},
		image = "rbxassetid://96063940465952",
		displayName = "Life Headhunter"
	  },
	  stone_sword = {
		image = "rbxassetid://6875481137",
		description = "Downgrades to a Wood Sword upon death.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Stone Sword"
	  },
	  owl_shooter = {
		image = "rbxassetid://11204094589",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		projectileSource = {
		  fireDelaySec = 0.2,
		  relativeOverride = {
			relX = 0.01,
			relY = 0.01,
			relZ = 0.01
		  },
		  projectileType = nil,
		  launchSound = { "rbxassetid://7290187805" },
		  hitSounds = { { "rbxassetid://6866062188" } }
		},
		displayName = "OWL"
	  },
	  andesite = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 5,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072525162", "rbxassetid://9072525162", "rbxassetid://9072525162", "rbxassetid://9072525162", "rbxassetid://9072525162", "rbxassetid://9072525162" }
		  }
		},
		image = "rbxassetid://9072552631",
		displayName = "ANDESITE"
	  },
	  helicopter_deploy = {
		image = "rbxassetid://9559559860",
		consumable = {
		  consumeTime = 3,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Minicopter"
	  },
	  bedrock = {
		footstepSound = 1,
		block = {
		  health = 10,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  minecraftConversions = { {
			blockId = 7
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9207284200", "rbxassetid://9207284200", "rbxassetid://9207284200", "rbxassetid://9207284200", "rbxassetid://9207284200", "rbxassetid://9207284200" }
		  },
		  breakableOnlyByHosts = true
		},
		image = "rbxassetid://9207283973",
		displayName = "Bedrock"
	  },
	  frying_pan = {
		image = "rbxassetid://9253246741",
		description = "Charge weapon to increase damage and knockback.",
		sword = {
		  chargedAttack = {
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			maxChargeTimeSec = 1,
			bonusDamage = 4
		  },
		  knockbackMultiplier = {
			horizontal = 1
		  },
		  attackSpeed = 0.3,
		  damage = 18
		},
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Frying Pan"
	  },
	  mythic_great_hammer = {
		replaces = { "wood_great_hammer", "stone_great_hammer", "iron_great_hammer", "diamond_great_hammer" },
		image = "rbxassetid://13832631998",
		sharingDisabled = true,
		damage = 67,
		itemCatalog = {
		  collection = 1
		},
		sword = {
		  attackSpeed = 0.6,
		  swingAnimations = { 416, 417 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.9
			},
			minChargeTimeSec = 0.75,
			chargedSwingAnimations = { 418 },
			attackCooldown = 0.65,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 0.75,
			chargedSwingSounds = { "rbxassetid://11715550908" },
			bonusDamage = 23.45,
			firstPersonChargedSwingAnimations = { 422 },
			chargingEffects = {
			  thirdPersonAnim = 419,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 423
			},
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.2
			}
		  },
		  multiHitCheckDurationSec = 0.25,
		  knockbackMultiplier = {
			vertical = 1.1,
			horizontal = 1.2
		  },
		  attackRange = 15,
		  firstPersonSwingAnimations = { 420, 421 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  applyCooldownOnMiss = true,
		  damage = 67
		},
		description = "Charge your hammer to activate an aura of healing for your teammates. Bonus healing on a successful charged attack. Downgrades to a Diamond Great Hammer upon death.",
		displayName = "Paragon"
	  },
	  festive_sword_wave = {
		displayName = "Festive Sword Wave"
	  },
	  tennis_racket = {
		image = "rbxassetid://10392204924",
		description = "Used to hit explosive tennis balls.",
		maxStackSize = {
		  amount = 10
		},
		thirdPerson = {
		  holdAnimation = 229
		},
		projectileSource = {
		  fireDelaySec = 0.4,
		  projectileType = nil,
		  thirdPerson = {
			fireAnimation = 228
		  },
		  walkSpeedMultiplier = 0.4,
		  launchScreenShake = {
			config = {
			  duration = 0.11,
			  magnitude = 0.04,
			  cycles = 1
			}
		  },
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "tennis_ball" },
		  maxStrengthChargeSec = 0.65,
		  activeReload = true,
		  launchSound = { "rbxassetid://10359187338", "rbxassetid://10361850937" },
		  firstPerson = {
			fireAnimation = 228
		  }
		},
		firstPerson = {
		  scale = 0.8,
		  holdAnimation = 229,
		  verticalOffset = -2
		},
		displayName = "Tennis Racket"
	  },
	  heal_banner = {
		image = "rbxassetid://9557924389",
		description = "Place banner that heals yourself and any team member inside banner radius.",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 40,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "flag-kit" },
		  unbreakableByTeammates = true,
		  minecraftConversions = { {
			blockId = 12009
		  } }
		},
		sharingDisabled = true,
		displayName = "Heal Banner"
	  },
	  raven = {
		image = "rbxassetid://7343272003",
		sharingDisabled = true,
		displayName = "Raven"
	  },
	  void_bait = {
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "void_bait" },
		  greedyMesh = {
			textures = { }
		  }
		},
		displayName = "Void Rock"
	  },
	  drone = {
		image = "rbxassetid://9507317177",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		guidedProjectileSource = {
		  guidedProjectile = "drone"
		},
		displayName = "Drone"
	  },
	  crystalheart_flower = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  hideDamageTextures = true,
		  placedBy = {
			itemType = "crystalheart_seed"
		  },
		  noRegen = true,
		  breakSound = nil,
		  healthType = 1,
		  seeThrough = true,
		  breakType = "grass",
		  health = 10,
		  disableInventoryPickup = true,
		  disableFlamableByTeammates = true,
		  collectionServiceTags = { "SpiritGardenerFlower" },
		  unbreakableByTeammates = true,
		  noSuffocation = true
		},
		displayName = "Crystalheart Flower"
	  },
	  soulvine_flower = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  hideDamageTextures = true,
		  placedBy = {
			itemType = "soulvine_seed"
		  },
		  noRegen = true,
		  breakSound = nil,
		  healthType = 1,
		  seeThrough = true,
		  breakType = "grass",
		  health = 10,
		  disableInventoryPickup = true,
		  disableFlamableByTeammates = true,
		  collectionServiceTags = { "SpiritGardenerFlower" },
		  unbreakableByTeammates = true,
		  noSuffocation = true
		},
		image = "rbxassetid://115936053361895",
		displayName = "Soulvine Flower"
	  },
	  tearbloom_flower = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  hideDamageTextures = true,
		  placedBy = {
			itemType = "tearbloom_seed"
		  },
		  noRegen = true,
		  breakSound = nil,
		  healthType = 1,
		  seeThrough = true,
		  breakType = "wood",
		  health = 10,
		  disableInventoryPickup = true,
		  disableFlamableByTeammates = true,
		  collectionServiceTags = { "SpiritGardenerFlower" },
		  unbreakableByTeammates = true,
		  noSuffocation = true
		},
		image = "rbxassetid://127974458998118",
		displayName = "Tearbloom Flower"
	  },
	  beachball = {
		image = "rbxassetid://18149456734",
		consumable = {
		  consumeTime = 1,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Beach Ball"
	  },
	  lobby_dragon_mortar = {
		image = "rbxassetid://16212332887",
		description = "Launch a festive dragon rocket to deal damage in an area!",
		displayName = "Dragon Mortar"
	  },
	  lobby_boomerang = {
		image = "rbxassetid://115717861330143",
		sharingDisabled = true,
		projectileSource = {
		  fireDelaySec = 0.3,
		  maxStrengthChargeSec = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		description = "Go bananas with this bundle of boomerangs!",
		displayName = "Bananarang"
	  },
	  frosted_snowball = {
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "frosted_snowball" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8165640372" },
		  fireDelaySec = 0.3
		},
		image = "rbxassetid://7911163294",
		sharingDisabled = true,
		displayName = "Frosted Snowball"
	  },
	  tactical_headhunter = {
		image = "rbxassetid://13887697172",
		description = "A tactical adaptation of the legendary Headhunter, this weapon deals massive damage!",
		skins = { "tactical_headhunter_lunar_dragon" },
		projectileSource = {
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 395,
			aimAnimation = 397
		  },
		  launchSound = { "rbxassetid://13406717420", "rbxassetid://13406717139", "rbxassetid://13406717258", "rbxassetid://13406717028" },
		  firstPerson = {
			fireAnimation = 396,
			aimAnimation = 398
		  }
		},
		sharingDisabled = true,
		displayName = "Tactical Headhunter"
	  },
	  sand_spear = {
		image = "rbxassetid://13034426218",
		description = "Damages enemies and can be stuck to surfaces to bounce players into the air.",
		maxStackSize = {
		  amount = 99
		},
		projectileSource = {
		  fireDelaySec = 0.7,
		  projectileType = nil,
		  thirdPerson = {
			fireAnimation = 81
		  },
		  walkSpeedMultiplier = 0.7,
		  ammoItemTypes = { "sand_spear" },
		  minStrengthScalar = 0.7692307692307692,
		  maxStrengthChargeSec = 0.25,
		  launchSound = { "rbxassetid://13032311986" },
		  firstPerson = {
			fireAnimation = 81
		  }
		},
		displayName = "Skorp Stinger"
	  },
	  tnt = {
		image = "rbxassetid://7884372237",
		sharingDisabled = true,
		footstepSound = 3,
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://16991767491", "rbxassetid://16991767491", "rbxassetid://16991767398", "rbxassetid://16991767398", "rbxassetid://16991767398", "rbxassetid://16991767398" }
		  },
		  health = 1
		},
		displayName = "TNT"
	  },
	  jump_pad = {
		block = {
		  minecraftConversions = { {
			blockId = 100005
		  } },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  disableEnemyInventoryPickup = true,
		  collectionServiceTags = { "launch-pad" },
		  seeThrough = true,
		  health = 2
		},
		image = "rbxassetid://9414655737",
		displayName = "Jump Pad"
	  },
	  barrier = {
		footstepSound = 1,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 166
		  } },
		  blastProof = true,
		  breakType = "stone",
		  health = 1,
		  seeThrough = true,
		  collectionServiceTags = { "BARRIER_BLOCK" },
		  breakSound = nil,
		  breakableOnlyByHosts = true
		},
		image = "rbxassetid://10569969807",
		displayName = "Barrier"
	  },
	  spirit_staff = {
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 26
		  },
		  projectileType = nil,
		  maxStrengthChargeSec = 0,
		  fireDelaySec = 0.8
		},
		image = "rbxassetid://111613461466718",
		sharingDisabled = true,
		displayName = "Spirit Staff"
	  },
	  harpoon = {
		image = "rbxassetid://18249733341",
		description = "Throw at your target and quickly leap to them.",
		projectileSource = {
		  fireDelaySec = 8,
		  firstPerson = {
			fireAnimation = 14
		  },
		  projectileType = nil,
		  launchSound = { "rbxassetid://18188220858" },
		  blockingStatusEffects = { "grounded" }
		},
		sharingDisabled = true,
		displayName = "Trident"
	  },
	  wool_shear = {
		breakBlock = {
		  wool = 5
		},
		image = "rbxassetid://7261638571",
		sharingDisabled = true,
		displayName = "Shears"
	  },
	  poison_splash_potion = {
		image = "rbxassetid://9135917252",
		description = "Splash potion that deals damage over time to enemies in the splash area.",
		maxStackSize = {
		  amount = 2
		},
		projectileSource = {
		  fireDelaySec = 0.4,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.7,
		  ammoItemTypes = { "poison_splash_potion" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = { }
		},
		displayName = "Poison Splash Potion"
	  },
	  clay_purple = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 10,
			blockId = 159
		  }, {
			blockData = 10,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766106", "rbxassetid://16991766106", "rbxassetid://16991766106", "rbxassetid://16991766106", "rbxassetid://16991766106", "rbxassetid://16991766106" }
		  }
		},
		image = "rbxassetid://7884368099",
		displayName = "Purple Clay"
	  },
	  knight_shield = {
		durability = {
		  itemHealth = 100
		},
		image = "rbxassetid://76984958562000",
		description = "Reduces incoming damage and knockback when held and can be used to bash enemies when in a defensive stance.",
		maxStackSize = {
		  amount = 1
		},
		firstPerson = {
		  verticalOffset = -0.9
		},
		sword = {
		  swingAnimations = { 696 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  attackSpeed = 0.8,
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			horizontal = 1.5
		  },
		  applyCooldownOnMiss = true,
		  damage = 30
		},
		sharingDisabled = true,
		displayName = "Guard's Shield"
	  },
	  enchant_table = {
		image = "rbxassetid://8270942991",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "enchant-table" },
		  minecraftConversions = { {
			blockId = 8004
		  } },
		  health = 20
		},
		displayName = "Enchant Table"
	  },
	  crystal_ore = {
		displayNameColor = nil,
		image = "rbxassetid://9866758117",
		hotbarFillRight = true,
		displayName = "Mysterious Crystal"
	  },
	  merchant_heal_buff = {
		removeFromCustoms = true,
		displayName = "Healing Buff"
	  },
	  spider_queen_web = {
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  breakSound = nil,
		  disableInCreative = true,
		  flammable = true,
		  minecraftConversions = { {
			blockId = 8033
		  } },
		  blastResistance = 0.3,
		  health = 1,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  cannotPathfindOn = true,
		  flameSpreadStopChance = 0.1,
		  breakType = "wool"
		},
		image = "rbxassetid://15056224013",
		description = "",
		displayName = "Spider Queen's Web"
	  },
	  teleport_block = {
		image = "rbxassetid://9369048721",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  health = 8,
		  collectionServiceTags = { "teleport_block" },
		  minecraftConversions = { {
			blockId = 8002
		  } },
		  seeThrough = true
		},
		displayName = "Teleport Block"
	  },
	  trumpet = {
		thirdPerson = {
		  holdAnimation = 148
		},
		image = "rbxassetid://10857089714",
		description = "Make some noise!",
		displayName = "Trumpet"
	  },
	  wood_plank_oak_builder = {
		image = "rbxassetid://10717426899",
		description = "Build a wood wall",
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  health = 30,
		  blastResistance = 1.4
		},
		displayName = "Oak Plank Wall"
	  },
	  spring_punch = {
		image = "rbxassetid://89187423732739",
		description = "Yeet your enemies with a spring loaded punch!",
		maxStackSize = {
		  amount = 1
		},
		thirdPerson = {
		  holdAnimation = 53
		},
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Punch Gun"
	  },
	  throwing_knife = {
		image = "rbxassetid://8479269961",
		projectileSource = {
		  multiShotCount = 3,
		  fireDelaySec = 0.8,
		  multiShot = true,
		  ammoItemTypes = { "throwing_knife" },
		  maxStrengthChargeSec = 0.4,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  multiShotDelay = 0.2
		},
		displayName = "Throwing Knife"
	  },
	  invisible_cloak = {
		image = "rbxassetid://18952530979",
		description = "become invisible after staying still",
		maxStackSize = {
		  amount = 1
		},
		sharingDisabled = true,
		backpack = {
		  cooldown = 10
		},
		displayName = "Cloak"
	  },
	  emerald_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.4,
		  slot = 1
		},
		image = "rbxassetid://6931675868",
		sharingDisabled = true,
		displayName = "Emerald Chestplate"
	  },
	  guards_spear = {
		image = "rbxassetid://127232846136294",
		sharingDisabled = true,
		sword = {
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 1,
			  delay = 0.2
			},
			minChargeTimeSec = 0.2,
			chargedSwingAnimations = { },
			firstPersonChargedSwingAnimations = { 122 },
			maxChargeTimeSec = 1
		  },
		  attackSpeed = 0.5,
		  attackRange = 17.5,
		  idleAnimation = 415,
		  swingAnimations = { },
		  respectAttackSpeedForEffects = true,
		  damage = 30
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Spear"
	  },
	  chicken_leather = {
		image = "rbxassetid://13980233415",
		displayName = "Leather Chicken"
	  },
	  team_door = {
		image = "rbxassetid://10322205747",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  collectionServiceTags = { "CanNoclip", "TeamDoor" },
		  minecraftConversions = { {
			blockId = 12004
		  } },
		  health = 20
		},
		displayName = "Team Door"
	  },
	  pumpkin_seeds = {
		image = "rbxassetid://11164828140",
		description = "Can be harvested into a throwable explosive!",
		sharingDisabled = true,
		placesBlock = {
		  blockType = "pumpkin"
		},
		displayName = "Pumpkin Seeds"
	  },
	  time_bomb_potion = {
		crafting = {
		  recipe = {
			timeToCraft = 3,
			ingredients = { "emerald_block", "emerald_block", "emerald_block" },
			result = "time_bomb_potion"
		  }
		},
		image = "rbxassetid://9135921093",
		consumable = {
		  potion = true,
		  consumeTime = 0.6
		},
		displayName = "Time Bomb Potion"
	  },
	  summoner_claw_3 = {
		actsAsSwordGroup = true,
		cooldownId = "summoner_claw_attack",
		keepOnDeath = true,
		displayName = "Summoner Claw III",
		image = "rbxassetid://18974198162",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		replaces = { "summoner_claw_2" },
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  scythe = {
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		image = "rbxassetid://8479270510",
		sword = {
		  idleAnimation = 92,
		  knockbackMultiplier = {
			vertical = 2,
			horizontal = 1.3
		  },
		  swingAnimations = { 94 },
		  attackSpeed = 1,
		  damage = 70
		},
		displayName = "Scythe"
	  },
	  sticky_firework = {
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "sticky_firework" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://10086863934",
		description = "Throw at players to launch them into the sky",
		displayName = "Sticky Firework"
	  },
	  summoner_claw_2 = {
		actsAsSwordGroup = true,
		cooldownId = "summoner_claw_attack",
		keepOnDeath = true,
		displayName = "Summoner Claw II",
		image = "rbxassetid://18974200883",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		replaces = { "summoner_claw_1" },
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  guided_missile = {
		firstPerson = {
		  scale = 0.7
		},
		image = "rbxassetid://8042313266",
		guidedProjectileSource = {
		  guidedProjectile = "guided_missile",
		  consumeItem = "guided_missile"
		},
		displayName = "Guided Missile"
	  },
	  summoner_claw_1 = {
		actsAsSwordGroup = true,
		image = "rbxassetid://18974199292",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		cooldownId = "summoner_claw_attack",
		keepOnDeath = true,
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Summoner Claw I"
	  },
	  life_crossbow = {
		replaces = { "life_bow" },
		description = "Does not use arrows, instead consuming health when fired. Gain life force on successful hits.",
		sharingDisabled = true,
		skins = { "life_crossbow_mummy" },
		projectileSource = {
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://128364711264624", "rbxassetid://97099816203576" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://73187588463348" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		image = "rbxassetid://70683200838838",
		displayName = "Life Crossbow"
	  },
	  firework_rocket_launcher = {
		projectileSource = {
		  activeReload = true,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "firework_rocket_missile" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8649937489" },
		  fireDelaySec = 2.2
		},
		image = "rbxassetid://15798141956",
		description = "",
		displayName = "Firework Rocket Launcher"
	  },
	  life_bow = {
		image = "rbxassetid://115560591356432",
		description = "Does not use arrows, instead consuming health when fired. Gain life force on successful hits.",
		sharingDisabled = true,
		skins = { "life_bow_mummy" },
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 0.6,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://128364711264624", "rbxassetid://97099816203576" } },
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  walkSpeedMultiplier = 0.35,
		  maxStrengthChargeSec = 0.65,
		  launchSound = { "rbxassetid://73187588463348" },
		  minStrengthScalar = 0.3333333333333333
		},
		firstPerson = {
		  verticalOffset = 0
		},
		displayName = "Life Bow"
	  },
	  tinkers_wrench = {
		image = "rbxassetid://11533277908",
		description = "Deals a small amount of damage",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.35,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Tinker's Wrench"
	  },
	  juggernaut_helmet = {
		armor = {
		  damageReductionMultiplier = 0.26,
		  slot = 0
		},
		image = "rbxassetid://8730010634",
		displayName = "Juggernaut Helmet"
	  },
	  og_wood_crossbow = {
		image = "rbxassetid://6869295265",
		sharingDisabled = true,
		skins = { "wood_crossbow_demon_empress_vanessa", "flower_crossbow_frost_queen" },
		projectileSource = {
		  multiShotChargeTime = 1.6,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		displayName = "Crossbow"
	  },
	  limestone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 121
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://18880491571", "rbxassetid://18880491571", "rbxassetid://18880491571", "rbxassetid://18880491571", "rbxassetid://18880491571", "rbxassetid://18880491571" }
		  }
		},
		displayName = "Limestone"
	  },
	  lucky_block_item_smelter = {
		footstepSound = 2,
		image = "rbxassetid://8562772907",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "chest" },
		  seeThrough = true,
		  health = 30
		},
		displayName = "Smelter"
	  },
	  ninja_chakram_1 = {
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  fireDelaySec = 0.4,
		  walkSpeedMultiplier = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		image = "rbxassetid://15515026452",
		sharingDisabled = true,
		displayName = "Stone Chakram"
	  },
	  classic_auto_turret = {
		image = "rbxassetid://7290567966",
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12002
		  } },
		  maxPlaced = 10,
		  disableInventoryPickup = true,
		  blastResistance = 4,
		  breakType = "stone",
		  health = 25,
		  seeThrough = true,
		  collectionServiceTags = { "Turret", "void-turret", "auto-turret" },
		  projectileSource = {
			fireDelaySec = 0.3,
			relativeOverride = {
			  relX = 0,
			  relY = 0,
			  relZ = 0
			},
			projectileType = nil,
			launchSound = { "rbxassetid://6866062104" },
			hitSounds = { { "rbxassetid://6866062188" } }
		  },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Auto Turret"
	  },
	  cutlass_ghost = {
		image = "rbxassetid://10729541018",
		sword = {
		  attackSpeed = 0.3,
		  damage = 0
		},
		displayName = "Ghost Cutlass"
	  },
	  juggernaut_crate = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "juggernaut-crate" },
		  minecraftConversions = { {
			blockId = 8007
		  } },
		  health = 20
		},
		displayName = "Juggernaut Crate"
	  },
	  black_market_reroll_items = {
		image = "rbxassetid://16261227767",
		description = "Rerolls all of the below discounted items",
		sharingDisabled = true,
		consumable = {
		  consumeTime = 0.5,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Reroll Discounted Items"
	  },
	  clay_black = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 15,
			blockId = 159
		  }, {
			blockData = 7,
			blockId = 35
		  }, {
			blockData = 15,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765519", "rbxassetid://16991765519", "rbxassetid://16991765519", "rbxassetid://16991765519", "rbxassetid://16991765519", "rbxassetid://16991765519" }
		  }
		},
		image = "rbxassetid://7884367004",
		displayName = "Black Clay"
	  },
	  cloak = {
		image = "",
		description = "Move in shadow!",
		removeFromCustoms = true,
		sharingDisabled = true,
		backpack = { },
		displayName = "Cloak"
	  },
	  reaper_scythe = {
		image = "rbxassetid://17768761460",
		sharingDisabled = true,
		sword = {
		  firstPersonSwingAnimations = { 409, 410 },
		  idleAnimation = 415,
		  respectAttackSpeedForEffects = true,
		  attackSpeed = 1.5,
		  swingAnimations = { 407, 408 },
		  applyCooldownOnMiss = true,
		  damage = 0
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Grim Reaper's Scythe"
	  },
	  snow_cone = {
		consumable = {
		  statusEffect = {
			incrementStacks = 1,
			statusEffectType = "snow_cone"
		  },
		  consumeTime = 0.5
		},
		image = "rbxassetid://10489888403",
		description = "Consume for 1 Snow Cone stack!",
		displayName = "Snow Cone"
	  },
	  tearbloom_seed = {
		image = "rbxassetid://124501620590187",
		description = "Heals nearby allies for 1 health per second when fully grown",
		sharingDisabled = true,
		placesBlock = {
		  blockType = "tearbloom_flower"
		},
		displayName = "Tearbloom Seed"
	  },
	  black_market_upgrade_1 = {
		image = "rbxassetid://95888205553099",
		description = "Unlocks: (Serpent's Touch Potion), (Fury Potion)",
		sharingDisabled = true,
		consumable = {
		  consumeTime = 0.5,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Black Market Upgrade 1"
	  },
	  guitar = {
		skins = { "guitar_rockstar", "guitar_holiday_cozy", "guitar_siren" },
		image = "rbxassetid://7085044606",
		sharingDisabled = true,
		displayName = "Guitar"
	  },
	  stone_dagger = {
		replaces = { "wood_dagger" },
		image = "rbxassetid://13832902818",
		sharingDisabled = true,
		damage = 11,
		description = "Dash behind your enemy and strike them in the back for bonus damage. Downgrades to Wood Dagger on death.",
		sword = {
		  attackSpeed = 0.25,
		  ignoreDamageCooldown = true,
		  swingSounds = { "rbxassetid://13833149867", "rbxassetid://13833150378", "rbxassetid://13833150864", "rbxassetid://13833151323" },
		  knockbackMultiplier = {
			vertical = 0.5,
			horizontal = 0.5
		  },
		  swingAnimations = { 403, 404 },
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 406, 405 },
		  applyCooldownOnMiss = true,
		  damage = 11
		},
		displayName = "Stone Dagger",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  falconer_headhunter = {
		image = "rbxassetid://17014870420",
		description = "Blessed by the wind, this lightweight weapon enables skilled archers to hunt their prey with speed and accuracy. Hit headshots for massive damage!",
		replaces = { "falconer_crossbow", "wood_crossbow", "falconer_bow", "wood_bow" },
		projectileSource = {
		  multiShotChargeTime = 2,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  thirdPerson = {
			fireAnimation = 395,
			aimAnimation = 397
		  },
		  launchSound = { "rbxassetid://13406717420", "rbxassetid://13406717139", "rbxassetid://13406717258", "rbxassetid://13406717028" },
		  firstPerson = {
			fireAnimation = 396,
			aimAnimation = 398
		  }
		},
		sharingDisabled = true,
		displayName = "Feather-light Headhunter"
	  },
	  cannon = {
		skins = { "cannon_ghost", "gold_victorious_cannon", "platinum_victorious_cannon", "diamond_victorious_cannon", "emerald_victorious_cannon", "nightmare_victorious_cannon", "cannon_deepsea" },
		image = "rbxassetid://7121221753",
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "cannon" },
		  minecraftConversions = { {
			blockId = 8018
		  } },
		  health = 8
		},
		displayName = "Cannon"
	  },
	  jellyfish = {
		placesBlock = {
		  blockType = "jellyfish_block_snapping"
		},
		image = "rbxassetid://18129975091",
		sharingDisabled = true,
		displayName = "Jellyfish"
	  },
	  glitch_stun_grenade = {
		glitched = true,
		image = "rbxassetid://10086863810",
		pickUpOverlaySound = "rbxassetid://10859056155",
		hotbarFillRight = true,
		displayName = "Stun Grenade?"
	  },
	  classic_shock_wave_turret = {
		image = "rbxassetid://10322206511",
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 2,
		  breakType = "stone",
		  health = 18,
		  seeThrough = true,
		  collectionServiceTags = { "shock-wave-turret" },
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 12001
		  } }
		},
		displayName = "Shock Wave Turret"
	  },
	  clay_dark_brown = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 7,
			blockId = 159
		  }, {
			blockData = 12,
			blockId = 35
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765722", "rbxassetid://16991765722", "rbxassetid://16991765722", "rbxassetid://16991765722", "rbxassetid://16991765722", "rbxassetid://16991765722" }
		  }
		},
		image = "rbxassetid://7884367299",
		displayName = "Dark Brown Clay"
	  },
	  critical_strike_3_enchant = {
		maxStackSize = {
		  amount = 1
		},
		image = "rbxassetid://9618671880",
		description = "Give you the Critical Strike enchant, lasts 180 seconds",
		displayName = "Criticle Strike"
	  },
	  static_3_enchant = {
		maxStackSize = {
		  amount = 1
		},
		image = "rbxassetid://8268259009",
		description = "Give you the static enchant, lasts 180 seconds",
		displayName = "Element of Static"
	  },
	  vacuum = {
		image = "rbxassetid://7813758517",
		description = "Used to capture a ghost. If a ghost is already caught, you can fire the ghost to deal damage.",
		projectileSource = {
		  projectileType = nil,
		  launchSound = { "rbxassetid://7806060367" },
		  fireDelaySec = 0
		},
		sharingDisabled = true,
		displayName = "Vacuum"
	  },
	  void_crystal = {
		displayNameColor = nil,
		image = "rbxassetid://9866758117",
		hotbarFillRight = true,
		displayName = "Void Crystal"
	  },
	  scepter = {
		image = "rbxassetid://11204094589",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  animationOverride = 270,
		  cancelOnDamage = true,
		  consumeTime = 1,
		  soundOverride = "None",
		  blockingStatusEffects = { "grounded" }
		},
		displayName = "Scepter of Light"
	  },
	  fire_3_enchant = {
		maxStackSize = {
		  amount = 1
		},
		image = "rbxassetid://8268259203",
		description = "Give you the fire enchant, lasts 180 seconds",
		displayName = "Element of Fire"
	  },
	  clay_tan = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 172
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766219", "rbxassetid://16991766219", "rbxassetid://16991766219", "rbxassetid://16991766219", "rbxassetid://16991766219", "rbxassetid://16991766219" }
		  }
		},
		image = "rbxassetid://7884368312",
		displayName = "Tan Clay"
	  },
	  drawbridge = {
		skins = { "drawbridge_christmas" },
		image = "rbxassetid://12210620616",
		description = "Hit with your hammer to toggle a scaffold bridge!",
		drawBridgeSource = { },
		footstepSound = 1,
		block = {
		  blastResistance = 1.4,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://12210620676", "rbxassetid://12210620676", "rbxassetid://12210620676", "rbxassetid://12210620676", "rbxassetid://12210620676", "rbxassetid://12210620676" },
			rotation = { }
		  },
		  disableInventoryPickup = true,
		  maxPlaced = 24,
		  health = 10
		},
		sharingDisabled = true,
		displayName = "Bridge Printer"
	  },
	  leather_helmet = {
		armor = {
		  damageReductionMultiplier = 0.12,
		  slot = 0
		},
		image = "rbxassetid://6855466216",
		sharingDisabled = true,
		displayName = "Leather Helmet"
	  },
	  stone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991767248", "rbxassetid://16991767248", "rbxassetid://16991767248", "rbxassetid://16991767248", "rbxassetid://16991767248", "rbxassetid://16991767248" }
		  }
		},
		image = "rbxassetid://7884371892",
		displayName = "Stone"
	  },
	  multi_break_tool = {
		sharingDisabled = true,
		image = "rbxassetid://17580233223",
		breakBlockSoundOverride = {
		  stone = { "rbxassetid://17578667711", "rbxassetid://17578667564", "rbxassetid://17578667976", "rbxassetid://17578667251" },
		  wood = { "rbxassetid://17578667049", "rbxassetid://17578665942", "rbxassetid://17578666891", "rbxassetid://17578665743" },
		  wool = { "rbxassetid://17578666527", "rbxassetid://17578665503", "rbxassetid://17578666360", "rbxassetid://17578666224" }
		},
		breakBlock = {
		  stone = 20,
		  wood = 2,
		  wool = 5
		},
		firstPerson = {
		  holdAnimation = 30,
		  verticalOffset = 1
		},
		breakBlockSwingAnimationOverride = 31,
		disableFirstPersonWalkAnimation = true,
		displayName = "Handheld Drill"
	  },
	  survival_crate = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Crate"
	  },
	  lasso_coin = {
		image = "rbxassetid://14978481303",
		keepOnDeath = true,
		displayNameColor = nil,
		disableDroppingInQueues = { "lasso_wars" },
		sharingDisabled = true,
		hotbarFillRight = true,
		displayName = "Coin"
	  },
	  slate_brick = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 11,
			blockId = 159
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://9072526507", "rbxassetid://9072526507", "rbxassetid://9072526507", "rbxassetid://9072526507", "rbxassetid://9072526507", "rbxassetid://9072526507" }
		  }
		},
		image = "rbxassetid://9072553631",
		displayName = "Slate Brick"
	  },
	  lasso_hook = {
		image = "rbxassetid://17009847852",
		block = {
		  health = 50,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableEnemyInventoryPickup = true,
		  collectionServiceTags = { "lasso-hook-block" },
		  seeThrough = true,
		  unbreakable = true
		},
		displayName = "Lasso Hook"
	  },
	  void_boots = {
		armor = {
		  damageReductionMultiplier = 0.16,
		  slot = 2
		},
		image = "rbxassetid://9866786979",
		displayName = "Void Boots"
	  },
	  guilded_iron = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 41
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10859696347", "rbxassetid://10859696347", "rbxassetid://10859696347", "rbxassetid://10859696347", "rbxassetid://10859696347", "rbxassetid://10859696347" }
		  }
		},
		image = "rbxassetid://10859696266",
		displayName = "Guilded Iron Block"
	  },
	  altar_block_three = {
		image = "rbxassetid://8270942991",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "altar-block" },
		  health = 20
		},
		displayName = "Altar"
	  },
	  altar_block_two = {
		image = "rbxassetid://8270942991",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "altar-block" },
		  health = 20
		},
		displayName = "Altar"
	  },
	  altar_block_one = {
		image = "rbxassetid://8270942991",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "altar-block" },
		  health = 20
		},
		displayName = "Altar"
	  },
	  emerald_chainsaw = {
		displayName = "FP Emerald Chainsaw"
	  },
	  diamond_chainsaw = {
		displayName = "FP Diamond Chainsaw"
	  },
	  wood_chainsaw = {
		displayName = "FP Wood Chainsaw"
	  },
	  flamethrower = {
		cooldownId = "flamethrower_use",
		image = "rbxassetid://7343272403",
		sharingDisabled = true,
		displayName = "Flamethrower"
	  },
	  condiment_gun = {
		firstPerson = {
		  holdAnimation = 455
		},
		image = "rbxassetid://14191270899",
		sharingDisabled = true,
		displayName = "Condiment Gun"
	  },
	  noctium_blade_4 = {
		image = "rbxassetid://100238229901987",
		description = "A blade forged from the powerful void metal, Noctium.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.35,
		  damage = 47
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Noctium Blade IV"
	  },
	  noctium_blade_3 = {
		image = "rbxassetid://101450000021943",
		description = "A blade forged from the powerful void metal, Noctium.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.35,
		  damage = 33
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Noctium Blade III"
	  },
	  noctium_blade_2 = {
		image = "rbxassetid://85834734397116",
		description = "A blade forged from the powerful void metal, Noctium.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.35,
		  damage = 27
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Noctium Blade II"
	  },
	  block_hunt_coin = {
		image = "rbxassetid://14978481303",
		keepOnDeath = true,
		displayNameColor = nil,
		disableDroppingInQueues = { "block_hunt" },
		sharingDisabled = true,
		hotbarFillRight = true,
		displayName = "Coin"
	  },
	  noctium_blade = {
		image = "rbxassetid://87316819930592",
		description = "A blade forged from the powerful void metal, Noctium.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.35,
		  damage = 22
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Noctium Blade I"
	  },
	  styx_entrance_portal = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  disableEnemyInventoryPickup = true,
		  health = 20,
		  seeThrough = true,
		  collectionServiceTags = { "styx-entrance-portal" },
		  unbreakableByTeammates = true,
		  breakType = "stone"
		},
		image = "rbxassetid://17009847852",
		sharingDisabled = true,
		displayName = "Confluence Portal"
	  },
	  hot_chocolate = {
		consumable = {
		  consumeTime = 1,
		  potion = true,
		  soundOverride = "rbxassetid://15609606503"
		},
		image = "rbxassetid://15625715830",
		description = "Drink to gain protection from the snow!",
		displayName = "Hot Chocolate"
	  },
	  healing_fountain = {
		block = {
		  health = 9999,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "HealingFountain" },
		  noSuffocation = true,
		  unbreakable = true
		},
		displayName = "Healing Fountain"
	  },
	  void_chicken_incubator = {
		image = "rbxassetid://17018554829",
		displayName = "Void Nest"
	  },
	  emerald_chicken_nest = {
		image = "rbxassetid://17018554648",
		displayName = "Emerald Nest"
	  },
	  emerald_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 133
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://7843773857", "rbxassetid://7843773857", "rbxassetid://7843773857", "rbxassetid://7843773857", "rbxassetid://7843773857", "rbxassetid://7843773857" }
		  }
		},
		image = "rbxassetid://7884369019",
		displayName = "Emerald Block"
	  },
	  chicken_iron = {
		image = "rbxassetid://13980233520",
		displayName = "Iron Chicken"
	  },
	  diamond_chicken_nest = {
		image = "rbxassetid://17018554494",
		displayName = "Diamond Nest"
	  },
	  emerald = {
		image = "rbxassetid://6850538075",
		displayNameColor = nil,
		pickUpOverlaySound = "rbxassetid://10649778581",
		hotbarFillRight = true,
		displayName = "Emerald"
	  },
	  iron_chicken_nest = {
		image = "rbxassetid://17018554326",
		displayName = "Iron Nest"
	  },
	  impulse_grenade = {
		projectileSource = {
		  fireDelaySec = 0.4,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.4,
		  ammoItemTypes = { "impulse_grenade" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = { }
		},
		image = "rbxassetid://7681106844",
		description = "Delayed explosive grenade that deals little damage but massive knockback.",
		displayName = "Impulse Grenade"
	  },
	  cluster_bomb = {
		image = "rbxassetid://17009910977",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 5
		},
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "cluster_bomb" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		displayName = "Cluster Bomb"
	  },
	  wool_cyan = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768048", "rbxassetid://16991768048", "rbxassetid://16991768048", "rbxassetid://16991768048", "rbxassetid://16991768048", "rbxassetid://16991768048" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 9,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923577311",
		displayName = "Cyan Wool"
	  },
	  tinker_machine_upgrade_1 = {
		image = "rbxassetid://17023879326",
		sharingDisabled = true,
		displayName = "Iron Mech Upgrade"
	  },
	  stone_dao = {
		daoSword = {
		  armorMultiplier = 0.8,
		  dashDamage = 19.8
		},
		image = "rbxassetid://8665071212",
		description = "Charge to dash forward. Downgrades to a Wood Dao upon death.",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		skins = { "stone_dao_tiger", "stone_dao_victorious", "stone_dao_cursed" },
		sword = {
		  daoDash = true,
		  attackSpeed = 0.3,
		  damage = 25
		},
		sharingDisabled = true,
		displayName = "Stone Dao"
	  },
	  repair_tool = {
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 5
		  },
		  fireDelaySec = 0.3,
		  maxStrengthChargeSec = 0.15,
		  ammoItemTypes = { "repair_tool" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://11533277908",
		description = "Throw to repair the map from Sledgehammer strikes",
		displayName = "Map Repair"
	  },
	  noxious_sledgehammer = {
		disableDroppingInQueues = { "infected" },
		image = "rbxassetid://11533278150",
		description = "An infected Sledgehammer that poisons enemies & breaks map blocks.",
		displayName = "Noxious Sledgehammer"
	  },
	  miner_pickaxe = {
		breakBlock = {
		  stone = 30
		},
		sharingDisabled = true,
		skins = { "miner_pickaxe_space", "miner_pickaxe_winter" },
		firstPerson = {
		  verticalOffset = -0.8
		},
		displayName = "Miner Pickaxe"
	  },
	  granite_polished = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072553427", "rbxassetid://9072553427", "rbxassetid://9072553427", "rbxassetid://9072553427", "rbxassetid://9072553427", "rbxassetid://9072553427" }
		  }
		},
		image = "rbxassetid://9072553350",
		displayName = "Polished Granite"
	  },
	  ninja_chakram_3 = {
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  fireDelaySec = 0.4,
		  walkSpeedMultiplier = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		image = "rbxassetid://15515023612",
		sharingDisabled = true,
		displayName = "Diamond Chakram"
	  },
	  tinker_weapon_5 = {
		image = "rbxassetid://17024056501",
		sharingDisabled = true,
		replaces = { "tinker_weapon_4" },
		skins = { "fish_tank_void_chainsaw" },
		sword = {
		  attackRange = 17,
		  attackSpeed = 0.35,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Void Chainsaw"
	  },
	  glitch_infernal_shield = {
		glitched = true,
		image = "rbxassetid://7051149149",
		pickUpOverlaySound = "rbxassetid://10859056155",
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Infernal Shield?"
	  },
	  tinker_machine_upgrade_3 = {
		sharingDisabled = true,
		image = "rbxassetid://17016816025",
		description = "Increases strength of Self-Destruct",
		displayName = "Emerald Mech Upgrade"
	  },
	  speed_boost = {
		displayName = "Speed Boost"
	  },
	  wood_plank_birch = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 5
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991767611", "rbxassetid://16991767611", "rbxassetid://16991767611", "rbxassetid://16991767611", "rbxassetid://16991767611", "rbxassetid://16991767611" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884372418",
		displayName = "Birch Wood Plank"
	  },
	  sandstone_polished = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 98
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://10859697352", "rbxassetid://10859697352", "rbxassetid://10859697352", "rbxassetid://10859697352", "rbxassetid://10859697352", "rbxassetid://10859697352" }
		  }
		},
		image = "rbxassetid://10859697278",
		displayName = "Sandstone Polished"
	  },
	  tinker_weapon_3 = {
		image = "rbxassetid://17016574694",
		sharingDisabled = true,
		replaces = { "tinker_weapon_2" },
		skins = { "fish_tank_diamond_chainsaw" },
		sword = {
		  attackRange = 17,
		  attackSpeed = 0.35,
		  damage = 20
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Diamond Chainsaw"
	  },
	  glitch_wood_bow = {
		glitched = true,
		image = "rbxassetid://6869295332",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 1.1,
		  projectileType = nil,
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "volley_arrow", "tnt" },
		  walkSpeedMultiplier = 0.35,
		  maxStrengthChargeSec = 0.65,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.3333333333333333
		},
		displayName = "Bow?"
	  },
	  charge_shield = {
		cooldownId = "charge_shield",
		image = "rbxassetid://7745351893",
		firstPerson = {
		  scale = 0.8
		},
		displayName = "Charge Shield"
	  },
	  villain_comet_volley = {
		image = "rbxassetid://16040490553",
		description = "Ascend to celestial heights before unleashing a volley of comets on the world below! Slain foes are converted into Emerald ore deposits.",
		tierUpgradeElements = { {
		  tierDescription = { "5 Total Comets", "70 Damage Per Comet", "Low Yield Emerald Ore" }
		}, {
		  tierDescription = { "7 Total Comets", "90 Damage Per Comet", "Medium Yield Emerald Ore" }
		}, {
		  tierDescription = { "9 Total Comets", "120 Damage Per Comet", "High Yield Emerald Ore" }
		} },
		itemCatalog = {
		  collection = 3
		},
		consumable = {
		  consumeTime = 0.8,
		  soundOverride = "None",
		  walkSpeedMultiplier = 0.5
		},
		displayName = "Villain's Comet Volley"
	  },
	  christmas_tree_deploy = {
		image = "rbxassetid://73183813669277",
		consumable = {
		  consumeTime = 1,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Christmas Tree"
	  },
	  clay_orange = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 159
		  }, {
			blockData = 1,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766008", "rbxassetid://16991766008", "rbxassetid://16991766008", "rbxassetid://16991766008", "rbxassetid://16991766008", "rbxassetid://16991766008" }
		  }
		},
		image = "rbxassetid://7884367973",
		displayName = "Orange Clay"
	  },
	  health_drop = {
		displayName = "Health Drop"
	  },
	  shrink_potion = {
		crafting = { },
		image = "rbxassetid://7911163448",
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		displayName = "Shrink Potion"
	  },
	  target_dummy_block_tier_4 = {
		image = "rbxassetid://15635693582",
		description = "",
		maxStackSize = {
		  amount = 1
		},
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "target-dummy-block" },
		  minecraftConversions = { {
			blockId = 8032
		  } },
		  health = 350
		},
		sharingDisabled = true,
		displayName = "Enlightened Defender"
	  },
	  blue_tile = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 22
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16238617352", "rbxassetid://16238617352", "rbxassetid://16238617352", "rbxassetid://16238617352", "rbxassetid://16238617352", "rbxassetid://16238617352" }
		  }
		},
		displayName = "Blue Tile"
	  },
	  dragon_mortar = {
		image = "rbxassetid://16212332887",
		description = "Launch a festive dragon rocket to deal damage in an area!",
		displayName = "Dragon Mortar"
	  },
	  firecrackers = {
		image = "rbxassetid://16211743648",
		description = "Celebrate the lunar new year with some firecrackers!",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "firecrackers" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8649937489" },
		  fireDelaySec = 1
		},
		displayName = "Firecrackers"
	  },
	  villain_scissor_sword = {
		image = "rbxassetid://16122815086",
		description = "Swords, like villains, can come from anywhere! Land combo hits to increase your attack speed.",
		tierUpgradeElements = { {
		  tierDescription = { "Apply the decay status on successful hits." }
		}, {
		  tierDescription = { "Unlock charged attack, performing a 3-strike combo." }
		}, {
		  tierDescription = { "The decay status now stacks, decreasing max health further." }
		} },
		sword = {
		  chargedAttack = {
			walkSpeedModifier = {
			  delay = 0.25,
			  multiplier = 1.1
			},
			minChargeTimeSec = 1.5,
			chargedSwingAnimations = { 554 },
			attackCooldown = 12,
			fireAtFullCharge = true,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 1.5,
			chargedSwingSounds = { "rbxassetid://16122342556", "rbxassetid://16122342556", "rbxassetid://16122342321" },
			enableCondition = nil,
			chargingEffects = {
			  sound = "rbxassetid://16122343234"
			}
		  },
		  skipSwingEffects = true,
		  attackSpeed = 0.698,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Villain's Scissor Sword"
	  },
	  stopwatch = {
		cooldownId = "stopwatch",
		image = "rbxassetid://7871761250",
		consumable = {
		  soundOverride = "None",
		  consumeTime = 1.5,
		  disableAnimation = true
		},
		displayName = "Stopwatch"
	  },
	  hero_scissor_sword = {
		image = "rbxassetid://16122815522",
		description = "Swords, like heroes, can be forged from anything! Land combo hits to increase your attack speed.",
		tierUpgradeElements = { {
		  tierDescription = { "Gain a sharpened status on successful hits." }
		}, {
		  tierDescription = { "Unlock charged attack, performing a 3-strike combo." }
		}, {
		  tierDescription = { "A well-time sword swing can now cut projectiles." }
		} },
		itemCatalog = {
		  collection = 3
		},
		sword = {
		  chargedAttack = {
			walkSpeedModifier = {
			  delay = 0.25,
			  multiplier = 1.1
			},
			minChargeTimeSec = 1.5,
			chargedSwingAnimations = { 554 },
			attackCooldown = 12,
			fireAtFullCharge = true,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 1.5,
			chargedSwingSounds = { "rbxassetid://16122343478", "rbxassetid://16122343478", "rbxassetid://16122343090" },
			enableCondition = nil,
			ignoreEffectsOnFullyCharged = true,
			chargingEffects = {
			  sound = "rbxassetid://16122343234"
			}
		  },
		  skipSwingEffects = true,
		  attackSpeed = 0.698,
		  damage = 25
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Hero's Scissor Sword"
	  },
	  scaffold = {
		image = "rbxassetid://12210853999",
		sharingDisabled = true,
		footstepSound = 2,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  flammable = true,
		  blastResistance = 1.4,
		  health = 1,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "scaffold" },
		  greedyMesh = {
			textures = { "rbxassetid://12211060975", "rbxassetid://12211060975", "rbxassetid://12210854096", "rbxassetid://12210854096", "rbxassetid://12210854096", "rbxassetid://12210854096" },
			rotation = { }
		  },
		  breakType = "wood"
		},
		skins = { "scaffolding_christmas" },
		displayName = "Scaffold"
	  },
	  mending_canopy_staff_tier_3 = {
		image = "rbxassetid://17007892915",
		description = "When the sun shine, we shine together! Now with Overcharge!",
		replaces = { "mending_canopy_staff_tier_2" },
		firstPerson = {
		  scale = 0.5
		},
		sharingDisabled = true,
		displayName = "Mending Canopy III"
	  },
	  wool_green = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768151", "rbxassetid://16991768151", "rbxassetid://16991768151", "rbxassetid://16991768151", "rbxassetid://16991768151", "rbxassetid://16991768151" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 5,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923577655",
		displayName = "Green Wool"
	  },
	  block_hunt_chameleon_fruit = {
		image = "rbxassetid://14983595388",
		maxStackSize = {
		  amount = 1
		},
		removeFromCustoms = true,
		consumable = {
		  consumeTime = 1
		},
		displayName = "Chameleon Fruit"
	  },
	  spawn_gadget = {
		gadget = true,
		image = "rbxassetid://15579417392",
		description = "Used to set a team spawn location at its position.",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "CreativeGadget" },
		  minecraftConversions = { {
			blockId = 9004
		  } },
		  breakableOnlyByHosts = true
		},
		displayName = "Team Spawn Gadget"
	  },
	  hero_magical_girl_rapier = {
		image = "rbxassetid://16101841796",
		description = "Forged with a courageous heart. Deal critical damage to high health enemies. 'Give me the strength to face my fears!'",
		tierUpgradeElements = { {
		  tierDescription = { "+2 Projectiles On Enhanced Attack" }
		}, {
		  tierDescription = { "Projectiles Can Now Critically Strike" }
		}, {
		  tierDescription = { "+2 Projectiles On Enhanced Attack" }
		} },
		itemCatalog = {
		  collection = 3
		},
		sword = {
		  attackSpeed = 0.5,
		  attackRange = 12,
		  swingSounds = { },
		  respectAttackSpeedForEffects = true,
		  applyCooldownOnMiss = true,
		  damage = 44
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Hero's Magical Rapier"
	  },
	  villain_protector_wand = {
		image = "rbxassetid://16031908526",
		description = "Grants you the power to cast heals and bubble barriers on yourself!",
		tierUpgradeElements = { {
		  tierDescription = { "Added Bubble Cast Ability", "Bubble Applies Knockback/Damage When Popped", "No Fall Damage Inside Bubble" }
		}, {
		  tierDescription = { "Heal Duration Increased", "Bubble Destroys Projectiles", "Pop Knockback/Damage Increased" }
		}, {
		  tierDescription = { "Heal Affects Nearby Teammates", "Bubble Deflects Projectiles", "Pop Knockback/Damage Increased" }
		} },
		itemCatalog = {
		  collection = 3
		},
		displayName = "Villain's Protector Wand"
	  },
	  red_sandstone_smooth = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 168
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://10859697202", "rbxassetid://10859697202", "rbxassetid://10859697202", "rbxassetid://10859697202", "rbxassetid://10859697202", "rbxassetid://10859697202" }
		  }
		},
		image = "rbxassetid://10859697143",
		displayName = "Red Sandstone Smooth"
	  },
	  hero_protector_wand = {
		image = "rbxassetid://16031906827",
		description = "Grants you the power to cast heals and bubble barriers on your teammates!",
		tierUpgradeElements = { {
		  tierDescription = { "Added Bubble Cast Ability", "Bubble Applies Knockback/Damage When Popped", "No Fall Damage Inside Bubble" }
		}, {
		  tierDescription = { "Heal Duration Increased", "Bubble Destroys Projectiles", "Pop Knockback/Damage Increased" }
		}, {
		  tierDescription = { "Heal Affects Nearby Teammates", "Bubble Deflects Projectiles", "Pop Knockback/Damage Increased" }
		} },
		itemCatalog = {
		  collection = 3
		},
		displayName = "Hero's Protector Wand"
	  },
	  void_block = {
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "void_block" },
		  greedyMesh = {
			textures = { "rbxassetid://9871962653", "rbxassetid://9871962545", "rbxassetid://9871962545", "rbxassetid://9871962545", "rbxassetid://9871962545", "rbxassetid://9871962545" }
		  }
		},
		image = "rbxassetid://9871961934",
		displayName = "Void Rock"
	  },
	  magical_hero_lucky_block = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "MagicalHeroLuckyBlock" },
		  luckyBlock = {
			categories = { "magical_hero", "magical_villain" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  minecraftConversions = { {
			blockId = 12117
		  } }
		},
		image = "rbxassetid://16114559103",
		displayName = "Magical Hero Lucky Block"
	  },
	  heal_splash_potion = {
		image = "rbxassetid://9135912233",
		description = "Splash potion that heals anyone inside the splash area.",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  fireDelaySec = 0.4,
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.7,
		  ammoItemTypes = { "heal_splash_potion" },
		  minStrengthScalar = 0.3333333333333333,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = { }
		},
		displayName = "Heal Splash Potion"
	  },
	  spread_cannon = {
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12013
		  } },
		  breakType = "stone",
		  health = 150,
		  disableInventoryPickup = true,
		  denyPlaceOn = true,
		  collectionServiceTags = { "cannon-type" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		image = "rbxassetid://10717427375",
		description = "Rapidly fires three TNT at a time",
		displayName = "Spread Cannon"
	  },
	  natures_essence_2 = {
		image = "rbxassetid://11003449842",
		removeFromCustoms = true,
		displayName = "Nature's Essence II"
	  },
	  falconer_bow = {
		image = "rbxassetid://17014870717",
		description = "Blessed by the wind, this lightweight weapon enables skilled archers to hunt their prey with speed and accuracy",
		replaces = { "wood_bow" },
		sharingDisabled = true,
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  multiShotChargeTime = 1,
		  fireDelaySec = 0.6,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  ammoItemTypes = { "firework_arrow", "arrow", "volley_arrow", "iron_arrow" },
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  maxStrengthChargeSec = 0.65,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.3333333333333333
		},
		firstPerson = {
		  verticalOffset = 0
		},
		displayName = "Feather-light Bow"
	  },
	  world_guard_wand = {
		firstPerson = {
		  verticalOffset = -0.8
		},
		image = "rbxassetid://16009857460",
		sharingDisabled = true,
		displayName = "World Guard Wand"
	  },
	  carrot_seeds = {
		image = "rbxassetid://6956387835",
		placesBlock = {
		  blockType = "carrot"
		},
		displayName = "Carrot Seeds"
	  },
	  new_years_lucky_block_2024 = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  greedyMesh = {
			textures = { "rbxassetid://15800004825", "rbxassetid://15800004825", "rbxassetid://15800004825", "rbxassetid://15800004825", "rbxassetid://15800004825", "rbxassetid://15800004825" }
		  },
		  minecraftConversions = { {
			blockId = 12116
		  } },
		  collectionServiceTags = { "NewYearsLuckyBlock" },
		  luckyBlock = {
			categories = { "new_years" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  disableInventoryPickup = true
		},
		image = "rbxassetid://15800004718",
		displayName = "New Years Lucky Block"
	  },
	  firework_rocket_missile = {
		image = "rbxassetid://15798141772",
		hotbarFillRight = true,
		displayName = "Firework Rocket"
	  },
	  drill = {
		image = "rbxassetid://12955099508",
		sharingDisabled = true,
		displayName = "Drill"
	  },
	  black_market_shop = {
		skins = { "halloween_black_market_shop", "holiday_black_market_shop" },
		block = {
		  noSuffocation = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  collectionServiceTags = { "single-space-block" },
		  unbreakableByTeammates = true,
		  disableInventoryPickup = true
		},
		sharingDisabled = true,
		displayName = "BLACK_MARKET_SHOP"
	  },
	  squad_launcher = {
		footstepSound = 2,
		image = "",
		block = {
		  noSuffocation = true,
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "squad-launcher" },
		  seeThrough = true,
		  health = 30
		},
		displayName = "Squad Launcher"
	  },
	  wood_dao = {
		daoSword = {
		  armorMultiplier = 0.8,
		  dashDamage = 16.5
		},
		image = "rbxassetid://8665070999",
		description = "Charge to dash forward.",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		skins = { "wood_dao_tiger", "wood_dao_victorious", "wood_dao_cursed" },
		sword = {
		  daoDash = true,
		  attackSpeed = 0.3,
		  damage = 20
		},
		sharingDisabled = true,
		displayName = "Wood Dao"
	  },
	  wool_white = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768606", "rbxassetid://16991768606", "rbxassetid://16991768606", "rbxassetid://16991768606", "rbxassetid://16991768606", "rbxassetid://16991768606" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923579263",
		displayName = "White Wool"
	  },
	  chicken_diamond = {
		image = "rbxassetid://13980233777",
		displayName = "Diamond Chicken"
	  },
	  snowball_launcher = {
		image = "rbxassetid://15628201582",
		description = "Launch snowballs that can slow or freeze enemies!",
		maxStackSize = {
		  amount = 1
		},
		firstPerson = {
		  verticalOffset = 0
		},
		thirdPerson = {
		  holdAnimation = 53
		},
		multiProjectileSource = {
		  mega_frozen_snowball = {
			minStrengthScalar = 1,
			maxStrengthChargeSec = 0.2,
			multiShotChargeTime = 1,
			ammoItemTypes = { "snowball" },
			fireDelaySec = 0.1,
			projectileType = nil,
			launchSound = { "rbxassetid://15628271415" },
			thirdPerson = {
			  aimAnimation = 53,
			  fireAnimation = 51,
			  idleAnimation = 53
			}
		  },
		  rapid_frozen_snowball = {
			multiShotCount = 8,
			multiShotChargeTime = 1,
			fireDelaySec = 0.05,
			projectileType = nil,
			maxStrengthChargeSec = 0.2,
			ammoItemTypes = { "snowball" },
			multiShot = true,
			thirdPerson = {
			  aimAnimation = 53,
			  fireAnimation = 51,
			  idleAnimation = 53
			},
			minStrengthScalar = 1,
			multiShotDelay = 0.05
		  },
		  spread_frozen_snowball = {
			multiShotCount = 10,
			multiShotChargeTime = 1,
			fireDelaySec = 0,
			projectileType = nil,
			maxStrengthChargeSec = 0.2,
			ammoItemTypes = { "snowball" },
			multiShot = true,
			thirdPerson = {
			  aimAnimation = 53,
			  fireAnimation = 51,
			  idleAnimation = 53
			},
			minStrengthScalar = 1,
			multiShotDelay = 0
		  },
		  frozen_snowball = {
			minStrengthScalar = 1,
			maxStrengthChargeSec = 0.3,
			ammoItemTypes = { "snowball" },
			fireDelaySec = 0.2,
			projectileType = nil,
			launchSound = { "rbxassetid://15628271708", "rbxassetid://15628271169", "rbxassetid://15628271324", "rbxassetid://15628271888" },
			thirdPerson = {
			  aimAnimation = 53,
			  fireAnimation = 51,
			  idleAnimation = 53
			}
		  }
		},
		displayName = "Snowball Launcher"
	  },
	  target_dummy_block_tier_3 = {
		image = "rbxassetid://15635691654",
		description = "",
		maxStackSize = {
		  amount = 1
		},
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "target-dummy-block" },
		  minecraftConversions = { {
			blockId = 8031
		  } },
		  health = 300
		},
		sharingDisabled = true,
		displayName = "Emerald Defender"
	  },
	  broken_enchant_table = {
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "broken-enchant-table" },
		  minecraftConversions = { {
			blockData = 1,
			blockId = 8004
		  } },
		  health = 20
		},
		displayName = "Broken Enchant Table"
	  },
	  target_dummy_block_tier_2 = {
		image = "rbxassetid://15635689543",
		description = "",
		maxStackSize = {
		  amount = 1
		},
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "target-dummy-block" },
		  minecraftConversions = { {
			blockId = 8030
		  } },
		  health = 250
		},
		sharingDisabled = true,
		displayName = "Diamond Defender"
	  },
	  warrior_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.36,
		  slot = 1
		},
		image = "rbxassetid://7343992770",
		displayName = "Warrior Chestplate"
	  },
	  glitch_snowball = {
		glitched = true,
		image = "rbxassetid://7911163294",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "glitch_snowball" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8165640372" },
		  fireDelaySec = 0.15
		},
		displayName = "Snowball?"
	  },
	  enchant_table_glitched = {
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "enchant-table" },
		  minecraftConversions = { {
			blockData = 2,
			blockId = 8004
		  } },
		  health = 20
		},
		displayName = "Glitched Enchant Table"
	  },
	  throwable_egg = {
		sharingDisabled = true,
		image = "rbxassetid://13988247733",
		description = "Bring back to your base!",
		displayName = "Egg"
	  },
	  damage_axolotl = {
		image = "rbxassetid://7863780231",
		displayName = "Damage Axolotl"
	  },
	  hero_comet_volley = {
		image = "rbxassetid://16040496465",
		description = "Ascend to celestial heights before unleashing a volley of comets on the world below! Slain foes are converted into Diamond ore deposits.",
		tierUpgradeElements = { {
		  tierDescription = { "5 Total Comets", "70 Damage Per Comet", "Low Yield Diamond Ore" }
		}, {
		  tierDescription = { "7 Total Comets", "90 Damage Per Comet", "Medium Yield Diamond Ore" }
		}, {
		  tierDescription = { "9 Total Comets", "120 Damage Per Comet", "High Yield Diamond Ore" }
		} },
		itemCatalog = {
		  collection = 3
		},
		consumable = {
		  consumeTime = 0.8,
		  soundOverride = "None",
		  walkSpeedMultiplier = 0.5
		},
		displayName = "Hero's Comet Volley"
	  },
	  glowstone = {
		footstepSound = 1,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 89
		  } },
		  health = 10,
		  pointLight = {
			Color = nil,
			Brightness = 0.7,
			Range = 27,
			Shadows = true
		  },
		  greedyMesh = {
			textures = { "rbxassetid://12946930610", "rbxassetid://12946930610", "rbxassetid://12946930610", "rbxassetid://12946930610", "rbxassetid://12946930610", "rbxassetid://12946930610" }
		  }
		},
		image = "rbxassetid://12948863407",
		displayName = "Glowstone"
	  },
	  bananarang = {
		image = "rbxassetid://115717861330143",
		sharingDisabled = true,
		projectileSource = {
		  fireDelaySec = 0.3,
		  maxStrengthChargeSec = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		description = "Go bananas with this bundle of boomerangs!",
		displayName = "Bananarang"
	  },
	  diamond_boots = {
		armor = {
		  damageReductionMultiplier = 0.2,
		  slot = 2
		},
		image = "rbxassetid://6874272964",
		sharingDisabled = true,
		displayName = "Diamond Boots"
	  },
	  ninja_chakram_4 = {
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  fireDelaySec = 0.4,
		  walkSpeedMultiplier = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		image = "rbxassetid://15515027427",
		sharingDisabled = true,
		displayName = "Emerald Chakram"
	  },
	  team_generator_gadget = {
		gadget = true,
		image = "rbxassetid://15579417392",
		description = "Used to create a team generator above its position.",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "CreativeGadget" },
		  minecraftConversions = { {
			blockId = 9006
		  } },
		  breakableOnlyByHosts = true
		},
		displayName = "Team Generator Gadget"
	  },
	  jump_potion = {
		maxStackSize = {
		  amount = 2
		},
		image = "rbxassetid://7836794681",
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		displayName = "Jump Potion"
	  },
	  ninja_chakram_2 = {
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  fireDelaySec = 0.4,
		  walkSpeedMultiplier = 1,
		  projectileType = nil,
		  minStrengthScalar = 1,
		  firstPerson = {
			fireAnimation = 14,
			aimAnimation = 23
		  }
		},
		image = "rbxassetid://15515025342",
		sharingDisabled = true,
		displayName = "Iron Chakram"
	  },
	  void_axe = {
		firstPerson = {
		  verticalOffset = -1.2
		},
		image = "rbxassetid://8322058718",
		sharingDisabled = true,
		displayName = "Void Axe"
	  },
	  juggernaut_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.42,
		  slot = 1
		},
		image = "rbxassetid://8730010865",
		displayName = "Juggernaut Chestplate"
	  },
	  slime_tamer_flute = {
		sharingDisabled = true,
		image = "rbxassetid://15295083414",
		description = "Used to direct slimes around.",
		displayName = "Slime Tamer's Flute"
	  },
	  headhunter = {
		replaces = { "wood_crossbow" },
		description = "A legendary weapon of unmatched precision and deadly force, the Headhunter was crafted for the expert hunter. Hit headshots for massive damage!",
		image = "rbxassetid://13421692306",
		skins = { "tactical_headhunter_lunar_dragon", "headhunter_valentine", "headhunter_demon_empress" },
		projectileSource = {
		  multiShotChargeTime = 2,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 395,
			aimAnimation = 397
		  },
		  launchSound = { "rbxassetid://13406717420", "rbxassetid://13406717139", "rbxassetid://13406717258", "rbxassetid://13406717028" },
		  firstPerson = {
			fireAnimation = 396,
			aimAnimation = 398
		  }
		},
		sharingDisabled = true,
		displayName = "Headhunter"
	  },
	  frosty_slime = {
		removeFromCustoms = true,
		image = "rbxassetid://15295050177",
		description = "Slows the movement speed of enemies hit by this teammate.",
		displayName = "Frosty Slime"
	  },
	  carrot_cannon = {
		image = "rbxassetid://9134613651",
		projectileSource = {
		  multiShotCount = 4,
		  fireDelaySec = 1,
		  projectileType = nil,
		  launchScreenShake = {
			config = {
			  duration = 0.15,
			  magnitude = 0.07,
			  cycles = 2
			}
		  },
		  thirdPerson = {
			fireAnimation = 136
		  },
		  firstPerson = {
			fireAnimation = 138
		  },
		  walkSpeedMultiplier = 0.6,
		  launchSoundConfig = {
			pitch = nil
		  },
		  ammoItemTypes = { "carrot_rocket" },
		  multiShot = true,
		  activeReload = true,
		  launchSound = { "rbxassetid://9135893336" },
		  multiShotDelay = 0.1
		},
		thirdPerson = {
		  holdAnimation = 137
		},
		firstPerson = {
		  holdAnimation = 139
		},
		displayName = "Carrot Cannon"
	  },
	  void_slime = {
		removeFromCustoms = true,
		image = "rbxassetid://15295057154",
		description = "Boosts damage of teammate.",
		displayName = "Void Slime"
	  },
	  healing_slime = {
		removeFromCustoms = true,
		image = "rbxassetid://15295059428",
		description = "Restores teammate's missing health.",
		displayName = "Blessed Slime"
	  },
	  gather_bot_pro = {
		image = "rbxassetid://15359021160",
		description = "A robot that locates emeralds and returns them to the personal crate",
		consumable = {
		  animationOverride = 501,
		  disableJump = true,
		  walkSpeedMultiplier = 0,
		  consumeTime = 1.8,
		  disableSoundRepeat = true,
		  soundOverride = "rbxassetid://15372210309"
		},
		sharingDisabled = true,
		displayName = "Emmy-Z2"
	  },
	  void_helmet = {
		armor = {
		  damageReductionMultiplier = 0.2,
		  slot = 0
		},
		image = "rbxassetid://9866786767",
		displayName = "Void Helmet"
	  },
	  gather_bot_basic = {
		image = "rbxassetid://15359021293",
		description = "A robot that locates diamonds and returns them to the team crate",
		consumable = {
		  animationOverride = 501,
		  disableJump = true,
		  walkSpeedMultiplier = 0,
		  consumeTime = 1.8,
		  disableSoundRepeat = true,
		  soundOverride = "rbxassetid://15372210309"
		},
		sharingDisabled = true,
		displayName = "Dimmy-X1"
	  },
	  rainbow_key = {
		image = "rbxassetid://12811672398",
		firstPerson = {
		  verticalOffset = -0.8
		},
		displayName = "Rainbow Key"
	  },
	  block_kicker_boot = {
		image = "rbxassetid://6874272718",
		sharingDisabled = true,
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  fireDelaySec = 0.5,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  minStrengthScalar = 0.5,
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  maxStrengthChargeSec = 3,
		  launchSound = { "rbxassetid://6866062104" },
		  walkSpeedMultiplier = 0.01
		},
		firstPerson = {
		  verticalOffset = 0
		},
		displayName = "Boot"
	  },
	  baguette = {
		firstPerson = {
		  scale = 0.8
		},
		image = "rbxassetid://7392211056",
		sword = {
		  swingSounds = { "rbxassetid://7396760496" },
		  knockbackMultiplier = {
			vertical = 1.2,
			horizontal = 1.5
		  },
		  attackSpeed = 0.4,
		  damage = 1
		},
		displayName = "Knockback Baguette"
	  },
	  slime_block = {
		footstepSound = 3,
		image = "rbxassetid://8273432599",
		block = {
		  elasticity = {
			elasticityPercent = 0.7,
			bounceSound = "rbxassetid://6857999096"
		  },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://16991766905", "rbxassetid://16991766905", "rbxassetid://16991766905", "rbxassetid://16991766905", "rbxassetid://16991766905", "rbxassetid://16991766905" }
		  },
		  health = 1,
		  fallDamageMultiplier = 0,
		  minecraftConversions = { {
			blockId = 165
		  } }
		},
		displayName = "Slime Block"
	  },
	  fury_potion = {
		image = "rbxassetid://122851344376912",
		description = "A potent mixture that fills the user with uncontrollable rage and power.  Increases attack speed by 20 % for (35 seconds)",
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  consumeTime = 0.8,
		  potion = true,
		  statusEffect = {
			duration = 35,
			statusEffectType = "fury_potion"
		  }
		},
		displayName = "Fury Potion"
	  },
	  speed_potion = {
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		crafting = { },
		maxStackSize = {
		  amount = 2
		},
		image = "rbxassetid://7836794566",
		displayName = "Speed Potion"
	  },
	  wood_gauntlets = {
		description = "Punch rapidly to deal more damage with combos.",
		image = "rbxassetid://14839095983",
		disableFirstPersonHoldAnimation = true,
		damage = 16,
		displayName = "Wood Gauntlets",
		sword = {
		  idleAnimation = 430,
		  swingSounds = { },
		  ignoreDamageCooldown = true,
		  attackSpeed = 0.21,
		  damage = 16
		},
		sharingDisabled = true,
		firstPerson = {
		  scale = 1,
		  verticalOffset = -1.2
		}
	  },
	  grimoire = {
		image = "rbxassetid://15107951466",
		description = "An ancient tome of dark magic. Gain a long-term power and a temporary curse.",
		itemCatalog = {
		  collection = 2
		},
		consumable = {
		  consumeTime = 1.5,
		  soundOverride = "rbxassetid://15112990538",
		  animationOverride = 260
		},
		displayName = "Grimoire"
	  },
	  clay_green = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 13,
			blockId = 251
		  }, {
			blockData = 5,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991765938", "rbxassetid://16991765938", "rbxassetid://16991765938", "rbxassetid://16991765938", "rbxassetid://16991765938", "rbxassetid://16991765938" }
		  }
		},
		image = "rbxassetid://7884367698",
		displayName = "Green Clay"
	  },
	  excalibur = {
		image = "",
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  breakSound = nil,
		  unbreakable = true,
		  breakType = "stone",
		  health = 8,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "Excalibur" },
		  seeThrough = true
		},
		displayName = "Excalibur"
	  },
	  berserker_3_enchant = {
		maxStackSize = {
		  amount = 1
		},
		image = "rbxassetid://17443716702",
		description = "Give you the berserker enchant, lasts 180 seconds",
		displayName = "Heart of Berserker"
	  },
	  lantern_block = {
		footstepSound = 1,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 123
		  } },
		  health = 10,
		  pointLight = {
			Color = nil,
			Brightness = 0.7,
			Range = 27,
			Shadows = true
		  },
		  greedyMesh = {
			textures = { "rbxassetid://12948863498", "rbxassetid://12948863498", "rbxassetid://12948863498", "rbxassetid://12948863498", "rbxassetid://12948863498", "rbxassetid://12948863498" }
		  }
		},
		image = "rbxassetid://12948863466",
		displayName = "Lantern Block"
	  },
	  grenade_launcher = {
		image = "rbxassetid://10086864148",
		projectileSource = {
		  activeReload = true,
		  minStrengthScalar = 0.7692307692307692,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "stun_grenade" },
		  fireDelaySec = 2.2,
		  projectileType = nil,
		  launchSound = { "rbxassetid://9135893336" },
		  thirdPerson = {
			fireAnimation = 51,
			aimAnimation = 53
		  }
		},
		displayName = "Rocket Launcher"
	  },
	  natures_essence_4 = {
		image = "rbxassetid://11003449842",
		removeFromCustoms = true,
		displayName = "Nature's Essence IV"
	  },
	  wood_plank_oak = {
		footstepSound = 2,
		block = {
		  flameSpreadStopChance = 0.4,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 5
		  } },
		  regenSpeed = 0.15,
		  flammable = true,
		  breakType = "wood",
		  health = 35,
		  greedyMesh = {
			textures = { "rbxassetid://16991767868", "rbxassetid://16991767868", "rbxassetid://16991767868", "rbxassetid://16991767868", "rbxassetid://16991767868", "rbxassetid://16991767868" }
		  },
		  blastResistance = 1.4,
		  breakSound = nil
		},
		image = "rbxassetid://7884372987",
		displayName = "Oak Plank"
	  },
	  haybale = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 170
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://14969029474", "rbxassetid://14969029474", "rbxassetid://14969029405", "rbxassetid://14969029405", "rbxassetid://14969029405", "rbxassetid://14969029405" }
		  }
		},
		image = "rbxassetid://14968393791",
		displayName = "Haybale"
	  },
	  grass = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 2
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://7911371279", "rbxassetid://7843778275", "rbxassetid://7911371120", "rbxassetid://7911371120", "rbxassetid://7911371120", "rbxassetid://7911371120" }
		  }
		},
		image = "rbxassetid://7911370722",
		displayName = "Grass"
	  },
	  mythic_gauntlets = {
		itemCatalog = {
		  collection = 1
		},
		description = "The Warfists have a charged attack that breaks blocks and damages enemies in front of you. Downgrades to Diamond Gauntlets upon death.",
		sword = {
		  chargedAttack = {
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 1
			},
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 0.75,
			walkSpeedModifier = {
			  multiplier = 0.9
			}
		  },
		  idleAnimation = 430,
		  swingSounds = { },
		  ignoreDamageCooldown = true,
		  attackSpeed = 0.21,
		  damage = 45
		},
		displayName = "Warfists",
		image = "rbxassetid://14839096268",
		sharingDisabled = true,
		replaces = { "wood_gauntlets", "stone_gauntlets", "iron_gauntlets", "diamond_gauntlets" },
		damage = 45,
		disableFirstPersonHoldAnimation = true,
		firstPerson = {
		  scale = 1,
		  verticalOffset = -1.2
		}
	  },
	  arrow_board = {
		block = {
		  collectionServiceTags = { "ArrowBoard" },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Arrow Board"
	  },
	  diorite_polished = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 4,
			blockId = 1
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9072553173", "rbxassetid://9072553173", "rbxassetid://9072553173", "rbxassetid://9072553173", "rbxassetid://9072553173", "rbxassetid://9072553173" }
		  }
		},
		image = "rbxassetid://9072553104",
		displayName = "Polished Diorite"
	  },
	  broken_arrow_board = {
		block = {
		  collectionServiceTags = { "ArrowBoard" },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Broken Arrow Board"
	  },
	  nest = {
		block = {
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Nest"
	  },
	  lightning_coil = {
		image = "rbxassetid://15122132404",
		description = "Shocking for all players!",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 8028
		  } },
		  health = 60
		},
		itemCatalog = {
		  collection = 2
		},
		displayName = "Frankenstein Lightning Coil"
	  },
	  radioactive_plant = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 2,
		  breakType = "stone",
		  health = 18,
		  seeThrough = true,
		  collectionServiceTags = { "radioactive-plant" },
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 8027
		  } }
		},
		image = "rbxassetid://14399105222",
		description = "Consumes Iron and Diamonds to deal radiation damage to nearby enemy players and blocks.",
		displayName = "Radioactive Plant"
	  },
	  paint_shotgun = {
		image = "rbxassetid://9135902677",
		firstPerson = {
		  holdAnimation = 133
		},
		displayName = "Paint Blaster"
	  },
	  wool_blue = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991767991", "rbxassetid://16991767991", "rbxassetid://16991767991", "rbxassetid://16991767991", "rbxassetid://16991767991", "rbxassetid://16991767991" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 11,
			blockId = 35
		  }, {
			blockData = 3,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923577182",
		displayName = "Blue Wool"
	  },
	  hickory_log = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 3,
			blockId = 17
		  }, {
			blockData = 0,
			blockId = 162
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991766405", "rbxassetid://16991766405", "rbxassetid://16991766362", "rbxassetid://16991766362", "rbxassetid://16991766362", "rbxassetid://16991766362" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884369330",
		displayName = "Hickory Log"
	  },
	  iron_pickaxe = {
		image = "rbxassetid://6875481325",
		sharingDisabled = true,
		firstPerson = {
		  verticalOffset = -0.8
		},
		breakBlock = {
		  stone = 13
		},
		displayName = "Iron Pickaxe"
	  },
	  sandstone_smooth = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 3,
			blockId = 98
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://10859697497", "rbxassetid://10859697497", "rbxassetid://10859697497", "rbxassetid://10859697497", "rbxassetid://10859697497", "rbxassetid://10859697497" }
		  }
		},
		image = "rbxassetid://10859697439",
		displayName = "Sandstone Smooth"
	  },
	  gumball_launcher = {
		image = "rbxassetid://14193833399",
		firstPerson = {
		  verticalOffset = 0
		},
		projectileSource = {
		  multiShotChargeTime = 1,
		  fireDelaySec = 1.5,
		  walkSpeedMultiplier = 0.35,
		  projectileType = nil,
		  launchSound = { "rbxassetid://14191014619", "rbxassetid://14191014232", "rbxassetid://14191013874" },
		  hitSounds = { { "rbxassetid://14191013768", "rbxassetid://14191013625", "rbxassetid://14191014109" } }
		},
		thirdPerson = {
		  holdAnimation = 53
		},
		displayName = "Gumball Launcher"
	  },
	  fork_trident_projectile = {
		displayName = "Fork Trident Projectile"
	  },
	  attack_helicopter_deploy = {
		consumable = {
		  consumeTime = 3,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		image = "rbxassetid://10236878231",
		description = "Weaponized flying death machine.",
		displayName = "Attack Minicopter"
	  },
	  galactite = {
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 87
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://15966093089", "rbxassetid://15966093089", "rbxassetid://15966093089", "rbxassetid://15966093089", "rbxassetid://15966093089", "rbxassetid://15966093089" }
		  }
		},
		image = "rbxassetid://15966082316",
		displayName = "Galactite"
	  },
	  villain_magical_girl_scepter = {
		image = "rbxassetid://16101848037",
		description = "Command the darkness of the moon and poison your enemies!",
		tierUpgradeElements = { {
		  tierDescription = { "+1 Projectile On Charged Attack (3 Total)" }
		}, {
		  tierDescription = { "Status Effects Can Now Stack", "3rd Stack Of Lunar Venom Consumes Stacks", "Consumed Stacks Deal Damage & Infect All Nearby Players" }
		}, {
		  tierDescription = { "+2 Projectiles On Charged Attack (5 Total)" }
		} },
		itemCatalog = {
		  collection = 3
		},
		firstPerson = {
		  verticalOffset = 0
		},
		multiProjectileSource = {
		  villain_magical_girl_scepter_projectile = {
			multiShotCount = 3,
			multiShot = true,
			multiShotChargeTime = 0.5,
			fireDelaySec = 1,
			minStrengthScalar = 1,
			projectileType = nil,
			launchSound = { "rbxassetid://16111432428", "rbxassetid://16111433823", "rbxassetid://16111432828", "rbxassetid://16111432196" },
			multiShotDelay = 0.1
		  },
		  villain_magical_girl_scepter_multi_projectile = {
			multiShotCount = 3,
			multiShot = true,
			multiShotChargeTime = 0.5,
			fireDelaySec = 1,
			minStrengthScalar = 1,
			projectileType = nil,
			launchSound = { "rbxassetid://16111432428", "rbxassetid://16111433823", "rbxassetid://16111432828", "rbxassetid://16111432196" },
			multiShotDelay = 0.1
		  }
		},
		displayName = "Villain's Magical Scepter"
	  },
	  red_sandstone_polished = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 168
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://10859697059", "rbxassetid://10859697059", "rbxassetid://10859697059", "rbxassetid://10859697059", "rbxassetid://10859697059", "rbxassetid://10859697059" }
		  }
		},
		image = "rbxassetid://10859696978",
		displayName = "Red Sandstone Polished"
	  },
	  gold = {
		displayNameColor = nil,
		image = "rbxassetid://13465460696",
		hotbarFillRight = true,
		displayName = "Gold"
	  },
	  pumpkin_bomb_1 = {
		image = "rbxassetid://11403476091",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "pumpkin_bomb_1" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Jack o'Boom"
	  },
	  chest = {
		footstepSound = 2,
		image = "rbxassetid://8562772907",
		block = {
		  seeThrough = true,
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "chest" },
		  minecraftConversions = { {
			blockId = 54
		  } },
		  health = 30
		},
		displayName = "Chest"
	  },
	  can_of_beans = {
		consumable = {
		  consumeTime = 0.5
		},
		image = "rbxassetid://13918757728",
		description = "Explosive!",
		displayName = "Can of beans"
	  },
	  team_crate = {
		footstepSound = 2,
		image = "rbxassetid://14146743816",
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "chest", "team-crate" },
		  seeThrough = true,
		  health = 30
		},
		displayName = "Team Crate"
	  },
	  double_edge_sword = {
		image = "rbxassetid://8995895533",
		description = "Heal yourself by hitting or eliminating other players while taking damage over time.",
		sword = {
		  attackSpeed = 0.3,
		  damage = 35
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Double Edge Sword"
	  },
	  spirit_bridge = {
		image = "rbxassetid://13835255693",
		description = "",
		maxStackSize = {
		  amount = 2
		},
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.6,
		  ammoItemTypes = { "spirit_bridge" },
		  minStrengthScalar = 0.5,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  fireDelaySec = 1
		},
		sharingDisabled = true,
		displayName = "Spirit Bridge"
	  },
	  wool_yellow = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991768659", "rbxassetid://16991768659", "rbxassetid://16991768659", "rbxassetid://16991768659", "rbxassetid://16991768659", "rbxassetid://16991768659" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 4,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923579520",
		displayName = "Yellow Wool"
	  },
	  cosmic_lucky_block = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 15,
		  greedyMesh = {
			textures = { "rbxassetid://11773163645", "rbxassetid://11773163645", "rbxassetid://11773163645", "rbxassetid://11773163645", "rbxassetid://11773163645", "rbxassetid://11773163645" }
		  },
		  disableInventoryPickup = true,
		  collectionServiceTags = { "LuckyBlock" },
		  luckyBlock = {
			categories = { "cosmic" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  minecraftConversions = { {
			blockId = 12015
		  } }
		},
		image = "rbxassetid://11773163557",
		displayName = "Cosmic Lucky Block"
	  },
	  wood_scythe = {
		image = "rbxassetid://13832901787",
		sharingDisabled = true,
		description = "Attack enemies from farther away and pull them toward you.",
		damage = 20,
		sword = {
		  chargedAttack = {
			disableOnGrounded = true,
			showHoldProgressAfterSec = 0.2,
			maxChargeTimeSec = 2,
			bonusKnockback = {
			  vertical = 0.5,
			  horizontal = 0.5
			},
			bonusDamage = 4
		  },
		  idleAnimation = 415,
		  attackSpeed = 0.4,
		  respectAttackSpeedForEffects = true,
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 20
		},
		displayName = "Wood Scythe",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  satellite_dish = {
		image = "rbxassetid://11585161152",
		description = "Send signals to disrupt your foes, earning resources on their shop purchases.",
		footstepSound = 1,
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12016
		  } },
		  blastProof = true,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 20,
		  disableEnemyInventoryPickup = true,
		  collectionServiceTags = { "satellite-dish" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		sharingDisabled = true,
		displayName = "Satellite Dish"
	  },
	  block_radar = {
		image = "rbxassetid://14985503526",
		sharingDisabled = true,
		displayName = "Block Radar"
	  },
	  pirate_flag = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 40,
		  disableInventoryPickup = true,
		  seeThrough = true,
		  collectionServiceTags = { "pirate-flag" },
		  unbreakableByTeammates = true,
		  minecraftConversions = { {
			blockId = 12022
		  } }
		},
		image = "rbxassetid://10797226392",
		description = "Periodically collects nearby dropped items",
		displayName = "Pirate Flag"
	  },
	  arrow = {
		sharingDisabled = true,
		image = "rbxassetid://6869295400",
		hotbarFillRight = true,
		displayName = "Arrow"
	  },
	  mending_canopy_staff_tier_2 = {
		image = "rbxassetid://17007888794",
		description = "When the sun shine, we shine together! Now with knockback!",
		replaces = { "mending_canopy_staff_tier_1" },
		firstPerson = {
		  scale = 0.5
		},
		sharingDisabled = true,
		displayName = "Mending Canopy II"
	  },
	  jellyfish_block_snapping = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil
		},
		removeFromCustoms = true,
		sharingDisabled = true,
		displayName = "Jellyfish Block Snapper"
	  },
	  forcefield_potion = {
		image = "rbxassetid://8795406077",
		consumable = {
		  cancelOnDamage = true,
		  consumeTime = 1.5
		},
		displayName = "Forcefield Potion"
	  },
	  nest_deposit_block = {
		block = {
		  collectionServiceTags = { "NestDepositBlock" },
		  breakType = "wool",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Nest Deposit Zone"
	  },
	  jellyfish_mount_deploy = {
		image = "rbxassetid://18129974979",
		description = "Fly around on this wild jellyfish!",
		consumable = {
		  consumeTime = 0.5,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		sharingDisabled = true,
		displayName = "Jellyfish Mount"
	  },
	  hammer = {
		image = "rbxassetid://6955848801",
		sharingDisabled = true,
		skins = { "nutcracker_hammer" },
		fortifiesBlock = true,
		displayName = "Hammer"
	  },
	  forge = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "forge-block" },
		  minecraftConversions = { {
			blockId = 8025
		  } },
		  health = 20
		},
		displayName = "Forge"
	  },
	  obsidian = {
		footstepSound = 1,
		block = {
		  minecraftConversions = { {
			blockId = 49
		  } },
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastResistance = 10,
		  regenSpeed = 0.2,
		  greedyMesh = {
			textures = { "rbxassetid://16991766822", "rbxassetid://16991766822", "rbxassetid://16991766822", "rbxassetid://16991766822", "rbxassetid://16991766822", "rbxassetid://16991766822" }
		  },
		  health = 150
		},
		image = "rbxassetid://8105569883",
		displayName = "Obsidian"
	  },
	  void_teleport_portal = {
		image = "rbxassetid://17208701108",
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8002
		  } },
		  maxPlaced = 2,
		  breakType = "stone",
		  health = 8,
		  seeThrough = true,
		  collectionServiceTags = { "void_teleport_portal" },
		  disableInventoryPickup = true,
		  breakSound = nil
		},
		displayName = "Teleport Block"
	  },
	  sandstone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 24
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7872908360", "rbxassetid://7872908360", "rbxassetid://7872908360", "rbxassetid://7872908360", "rbxassetid://7872908360", "rbxassetid://7872908360" }
		  }
		},
		image = "rbxassetid://7884371048",
		displayName = "Sandstone"
	  },
	  mythic_dagger = {
		replaces = { "wood_dagger", "stone_dagger", "iron_dagger", "diamond_dagger" },
		image = "rbxassetid://13832903272",
		sharingDisabled = true,
		damage = 28,
		itemCatalog = {
		  collection = 1,
		  summary = "Dagger that applies 4s of poison on hit. Downgrades to Diamond Dagger on death."
		},
		sword = {
		  attackSpeed = 0.25,
		  ignoreDamageCooldown = true,
		  swingSounds = { "rbxassetid://13833149867", "rbxassetid://13833150378", "rbxassetid://13833150864", "rbxassetid://13833151323" },
		  knockbackMultiplier = {
			vertical = 0.5,
			horizontal = 0.5
		  },
		  swingAnimations = { 403, 404 },
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 406, 405 },
		  applyCooldownOnMiss = true,
		  damage = 28
		},
		displayName = "Deathbloom",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  double_rainbow_boots = {
		armor = {
		  damageReductionMultiplier = 0.24,
		  slot = 2
		},
		image = "rbxassetid://12813706493",
		description = "Jump through seven colors of the rainbow!",
		displayName = "Double Rainbow Boots"
	  },
	  merchant_damage_buff = {
		removeFromCustoms = true,
		displayName = "Damage Buff"
	  },
	  diamond_dao = {
		daoSword = {
		  armorMultiplier = 0.75,
		  dashDamage = 27.500000000000004
		},
		image = "rbxassetid://8665071845",
		description = "Charge to dash forward. Downgrades to an Iron Dao upon death.",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		skins = { "diamond_dao_tiger", "diamond_dao_victorious", "diamond_dao_cursed" },
		sword = {
		  daoDash = true,
		  attackSpeed = 0.3,
		  damage = 42
		},
		sharingDisabled = true,
		displayName = "Diamond Dao"
	  },
	  laser_pickaxe = {
		breakBlockCooldown = 0.15,
		breakBlock = {
		  stone = 22
		},
		description = "Break blocks from afar with this powerful laserbeam!",
		displayName = "Laser Pickaxe",
		image = "rbxassetid://92568899407180",
		sharingDisabled = true,
		breakBlockSwingAnimationOverride = 31,
		breakBlockRange = 36,
		disableFirstPersonWalkAnimation = true,
		firstPerson = {
		  scale = 0.75,
		  holdAnimation = 30,
		  verticalOffset = 0.4
		}
	  },
	  mysterious_box = {
		consumable = {
		  consumeTime = 0.5,
		  animationOverride = 116,
		  soundOverride = "None"
		},
		image = "rbxassetid://8273441274",
		sharingDisabled = true,
		displayName = "Mysterious Box"
	  },
	  giant_potion = {
		crafting = { },
		image = "rbxassetid://7911163626",
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		displayName = "Giant Potion"
	  },
	  kobblak = {
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 216
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://9859003198", "rbxassetid://9859003198", "rbxassetid://9859003106", "rbxassetid://9859003106", "rbxassetid://9859003106", "rbxassetid://9859003106" }
		  }
		},
		image = "rbxassetid://9859002988",
		displayName = "Kobblak"
	  },
	  iron_dagger = {
		replaces = { "wood_dagger", "stone_dagger" },
		image = "rbxassetid://13832903755",
		sharingDisabled = true,
		damage = 15,
		description = "Dash behind your enemy and strike them in the back for bonus damage. Downgrades to Stone Dagger on death.",
		sword = {
		  attackSpeed = 0.25,
		  ignoreDamageCooldown = true,
		  swingSounds = { "rbxassetid://13833149867", "rbxassetid://13833150378", "rbxassetid://13833150864", "rbxassetid://13833151323" },
		  knockbackMultiplier = {
			vertical = 0.5,
			horizontal = 0.5
		  },
		  swingAnimations = { 403, 404 },
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 406, 405 },
		  applyCooldownOnMiss = true,
		  damage = 15
		},
		displayName = "Iron Dagger",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  treasure_chest = {
		consumable = {
		  animationOverride = 270,
		  walkSpeedMultiplier = 0,
		  consumeTime = 0.6,
		  consumeCooldown = 0.5,
		  soundOverride = ""
		},
		image = "rbxassetid://13547810867",
		description = "Open for a chance at pirate's treasure",
		displayName = "Treasure Chest"
	  },
	  bed_gadget = {
		gadget = true,
		image = "rbxassetid://15579417392",
		description = "Used to create a bed at its position.",
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  collectionServiceTags = { "CreativeGadget" },
		  minecraftConversions = { {
			blockId = 9003
		  } },
		  breakableOnlyByHosts = true
		},
		displayName = "Bed Gadget"
	  },
	  void_turret_tablet = {
		keepOnDeath = true,
		image = "rbxassetid://9942058467",
		hotbarFillRight = true,
		displayName = "Void Turret Tablet"
	  },
	  oak_log = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 17
		  }, {
			blockId = 35
		  }, {
			blockData = 8,
			blockId = 159
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991766755", "rbxassetid://16991766755", "rbxassetid://16991766678", "rbxassetid://16991766678", "rbxassetid://16991766678", "rbxassetid://16991766678" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884370279",
		displayName = "Oak Log"
	  },
	  tornado_launcher = {
		image = "rbxassetid://9193792144",
		description = "Launch a mini tornado that deals damage & launches up any players caught in its path.",
		projectileSource = {
		  launchScreenShake = {
			config = {
			  duration = 0.15,
			  magnitude = 0.07,
			  cycles = 2
			}
		  },
		  fireDelaySec = 3,
		  thirdPerson = {
			fireAnimation = 151,
			aimAnimation = 150
		  },
		  projectileType = nil,
		  launchSound = { "rbxassetid://9252994838" },
		  activeReload = true
		},
		thirdPerson = { },
		displayName = "Tornado Launcher"
	  },
	  stone_slab = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 8,
			blockId = 43
		  }, {
			blockData = 0,
			blockId = 43
		  }, {
			blockData = 0,
			blockId = 44
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://8105570960", "rbxassetid://8105570960", "rbxassetid://8105570960", "rbxassetid://8105570960", "rbxassetid://8105570960", "rbxassetid://8105570960" }
		  }
		},
		image = "rbxassetid://8105570787",
		displayName = "Stone Slab"
	  },
	  blackhole_bomb = {
		image = "rbxassetid://7976208473",
		projectileSource = {
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "blackhole_bomb" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6760544639" },
		  fireDelaySec = 0.4
		},
		displayName = "Blackhole"
	  },
	  rainbow_lucky_block = {
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  breakType = "stone",
		  health = 30,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "LuckyBlock" },
		  luckyBlock = {
			categories = { "rainbow" },
			allowedPolarity = { "negative" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  minecraftConversions = { {
			blockId = 657
		  } }
		},
		image = "rbxassetid://12813794908",
		displayName = "Rainbow Lucky Block"
	  },
	  big_wood_sword = {
		firstPerson = { },
		image = "rbxassetid://6875480974",
		sword = {
		  knockbackMultiplier = {
			vertical = 2
		  },
		  attackSpeed = 0.3,
		  damage = 20
		},
		displayName = "Big Wood Sword"
	  },
	  ember = {
		keepOnDeath = true,
		image = "rbxassetid://7343272545",
		sharingDisabled = true,
		displayName = "Ember"
	  },
	  personal_chest = {
		footstepSound = 2,
		image = "rbxassetid://8164577594",
		block = {
		  seeThrough = true,
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  collectionServiceTags = { "chest", "personal-chest" },
		  minecraftConversions = { {
			blockId = 130
		  } },
		  health = 30
		},
		displayName = "Personal Chest"
	  },
	  brewing_cauldron = {
		image = "rbxassetid://9134530108",
		sharingDisabled = true,
		crafting = {
		  recipes = { {
			timeToCraft = 4,
			ingredients = { "mushrooms", "mushrooms", "mushrooms" },
			result = "sleep_splash_potion"
		  }, {
			timeToCraft = 7,
			ingredients = { "thorns", "thorns", "wild_flower" },
			result = "big_shield"
		  }, {
			timeToCraft = 5,
			ingredients = { "thorns", "mushrooms", "mushrooms" },
			result = "poison_splash_potion"
		  }, {
			timeToCraft = 5,
			ingredients = { "wild_flower", "wild_flower", "wild_flower" },
			result = "heal_splash_potion"
		  } }
		},
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8021
		  } },
		  breakType = "stone",
		  health = 25,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "brewing_cauldron" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Brewing Cauldron"
	  },
	  emerald_sword = {
		image = "rbxassetid://6931677551",
		description = "Comes with an emerald shield that fully blocks the first instance of damage in a fight. Downgrades to a Diamond Sword upon death.",
		itemCatalog = {
		  collection = 1
		},
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 55
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Emerald Sword"
	  },
	  chicken_egg_block = {
		block = {
		  denyPlaceOn = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 8016
		  } },
		  breakType = "wood",
		  health = 5,
		  seeThrough = true,
		  disableFlamableByTeammates = true,
		  placedBy = {
			itemType = "chicken_egg"
		  },
		  breakSound = nil
		},
		image = "rbxassetid://3677675280",
		displayName = "Egg"
	  },
	  iron = {
		displayNameColor = nil,
		image = "rbxassetid://6850537969",
		hotbarFillRight = true,
		displayName = "Iron"
	  },
	  warrior_boots = {
		armor = {
		  damageReductionMultiplier = 0.2,
		  slot = 2
		},
		image = "rbxassetid://7343993019",
		displayName = "Warrior Boots"
	  },
	  flower_bow = {
		image = "rbxassetid://13278689311",
		sharingDisabled = true,
		skins = { "flower_bow_frost_queen", "gold_victorious_flower_bow", "platinum_victorious_flower_bow", "diamond_victorious_flower_bow", "emerald_victorious_flower_bow", "nightmare_victorious_flower_bow" },
		projectileSource = {
		  chargeBeginSound = { "rbxassetid://6866062236" },
		  multiShotChargeTime = 0.8,
		  fireDelaySec = 0.6,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  thirdPerson = {
			aimAnimation = 124,
			fireAnimation = 125,
			drawAnimation = 126
		  },
		  ammoItemTypes = { "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  maxStrengthChargeSec = 0.65,
		  launchSound = { "rbxassetid://6866062104" },
		  minStrengthScalar = 0.3333333333333333
		},
		firstPerson = {
		  verticalOffset = 0
		},
		displayName = "Floral Bow"
	  },
	  black_market_upgrade_2 = {
		image = "rbxassetid://95888205553099",
		description = "Unlocks: (Mini Shield Potion)",
		sharingDisabled = true,
		consumable = {
		  consumeTime = 0.5,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Black Market Upgrade 2"
	  },
	  beehive_grenade = {
		image = "rbxassetid://12671499151",
		description = "Explosive beehive that comes with a large kick! Hitting yourself will reset glide cooldown.",
		maxStackSize = {
		  amount = 5
		},
		projectileSource = {
		  ammoItemTypes = { "beehive_grenade" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 54
		  }
		},
		sharingDisabled = true,
		displayName = "Beehive Grenade"
	  },
	  fork_trident = {
		image = "rbxassetid://14315230530",
		description = "A trident worthy of a feast",
		maxStackSize = {
		  amount = 1
		},
		firstPerson = {
		  scale = 0.8
		},
		sword = {
		  attackSpeed = 0.3,
		  knockbackMultiplier = {
			horizontal = 1.1
		  },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			chargingEffects = {
			  thirdPersonAnim = 83,
			  firstPersonAnim = 226
			},
			walkSpeedModifier = {
			  multiplier = 0.7
			},
			minChargeTimeSec = 0.7,
			chargedSwingAnimations = { 81 },
			chargedSwingSounds = { "rbxassetid://14316533753" },
			firstPersonChargedSwingAnimations = { 227 },
			maxChargeTimeSec = 0.7,
			attackCooldown = 0.5
		  },
		  swingSounds = { },
		  attackRange = 9,
		  firstPersonSwingAnimations = { 121, 122 },
		  swingAnimations = { 117, 118 },
		  applyCooldownOnMiss = true,
		  damage = 30
		},
		projectileSource = {
		  projectileType = nil,
		  fireDelaySec = 1,
		  ammoItemTypes = { "fork_trident" }
		},
		displayName = "Fork Trident"
	  },
	  food_lucky_block = {
		block = {
		  greedyMesh = {
			textures = { "rbxassetid://14192272804", "rbxassetid://14192272281", "rbxassetid://14192272698", "rbxassetid://14192272698", "rbxassetid://14192272698", "rbxassetid://14192272698" }
		  },
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  disableInventoryPickup = true,
		  luckyBlock = {
			categories = { "food" },
			drops = { {
			  luckMultiplier = 2
			} }
		  },
		  health = 15
		},
		image = "rbxassetid://14192272584",
		displayName = "Food Lucky Block"
	  },
	  drill_controller = {
		image = "rbxassetid://7290617886",
		sharingDisabled = true,
		displayName = "Tablet"
	  },
	  blunderbuss_bullet = {
		removeFromCustoms = true,
		displayName = "Blunderbuss Bullet"
	  },
	  diamond_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.32,
		  slot = 1
		},
		image = "rbxassetid://6874272898",
		sharingDisabled = true,
		displayName = "Diamond Chestplate"
	  },
	  chicken_void = {
		image = "rbxassetid://13980233120",
		displayName = "Void Chicken"
	  },
	  sheriff_crossbow = {
		image = "rbxassetid://7051149016",
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  fireDelaySec = 1.15,
		  walkSpeedMultiplier = 0.35,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  hitSounds = { { "rbxassetid://6866062188" } }
		},
		sharingDisabled = true,
		displayName = "Sheriff Crossbow"
	  },
	  diamond_dagger = {
		replaces = { "wood_dagger", "stone_dagger", "iron_dagger" },
		image = "rbxassetid://13832904133",
		sharingDisabled = true,
		damage = 21,
		description = "Dash behind your enemy and strike them in the back for bonus damage. Downgrades to Iron Dagger on death.",
		sword = {
		  attackSpeed = 0.25,
		  ignoreDamageCooldown = true,
		  swingSounds = { "rbxassetid://13833149867", "rbxassetid://13833150378", "rbxassetid://13833150864", "rbxassetid://13833151323" },
		  knockbackMultiplier = {
			vertical = 0.5,
			horizontal = 0.5
		  },
		  swingAnimations = { 403, 404 },
		  attackRange = 10.5,
		  respectAttackSpeedForEffects = true,
		  firstPersonSwingAnimations = { 406, 405 },
		  applyCooldownOnMiss = true,
		  damage = 21
		},
		displayName = "Diamond Dagger",
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  iron_arrow = {
		image = "rbxassetid://15579506183",
		sharingDisabled = true,
		description = "Increased projectile damage",
		hotbarFillRight = true,
		displayName = "Iron Arrow"
	  },
	  santa_bomb = {
		image = "rbxassetid://8273495195",
		description = "Throw to mark a location to drop 3 TNT bombs.",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.4,
		  ammoItemTypes = { "santa_bomb" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  fireDelaySec = 0.2
		},
		sharingDisabled = true,
		displayName = "Santa Strafe"
	  },
	  fisherman_coral = {
		footstepSound = 1,
		block = {
		  blastResistance = 5,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 8012
		  } },
		  regenSpeed = 0.2,
		  greedyMesh = {
			textures = { "rbxassetid://7843775572", "rbxassetid://7843775572", "rbxassetid://7843775572", "rbxassetid://7843775572", "rbxassetid://7843775572", "rbxassetid://7843775572" }
		  },
		  health = 210
		},
		image = "rbxassetid://7884369108",
		displayName = "Coral"
	  },
	  teleporting_hatter = {
		image = "rbxassetid://12291381738",
		description = "N/A",
		displayName = "Teleporting Hatter"
	  },
	  fire_sheep_statue = {
		image = "rbxassetid://12291381909",
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  breakSound = nil,
		  maxPlaced = 1,
		  breakType = "stone",
		  health = 100000,
		  seeThrough = true,
		  disableInventoryPickup = true,
		  collectionServiceTags = { },
		  unbreakableByTeammates = true,
		  minecraftConversions = { {
			blockId = 656
		  } }
		},
		displayName = "Fire Sheep Statue"
	  },
	  throwable_bridge = {
		image = "rbxassetid://10866146253",
		projectileSource = {
		  ammoItemTypes = { "throwable_bridge" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  maxStrengthChargeSec = 0.25,
		  fireDelaySec = 0.15
		},
		displayName = "Portable Bridge"
	  },
	  christmas_drawbridge = {
		image = "rbxassetid://122137461128449",
		description = "Hit with your hammer to toggle a scaffold bridge!",
		drawBridgeSource = { },
		footstepSound = 1,
		block = {
		  blastResistance = 1.4,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  greedyMesh = {
			textures = { "rbxassetid://97798420366864", "rbxassetid://97798420366864", "rbxassetid://97798420366864", "rbxassetid://97798420366864", "rbxassetid://97798420366864", "rbxassetid://97798420366864" },
			rotation = { }
		  },
		  disableInventoryPickup = true,
		  maxPlaced = 24,
		  health = 10
		},
		sharingDisabled = true,
		displayName = "Bridge Printer"
	  },
	  falconer_crossbow = {
		image = "rbxassetid://17014870547",
		description = "Blessed by the wind, this lightweight weapon enables skilled archers to hunt their prey with speed and accuracy",
		firstPerson = {
		  scale = 0.9,
		  verticalOffset = -0.25
		},
		replaces = { "falconer_bow", "wood_bow", "wood_crossbow" },
		projectileSource = {
		  multiShotChargeTime = 1.6,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		sharingDisabled = true,
		displayName = "Feather-light Crossbow"
	  },
	  volatile_stone = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  pointLight = {
			Color = nil,
			Brightness = 0.4,
			Range = 12,
			Shadows = true
		  },
		  minecraftConversions = { {
			blockId = 12020
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://15380237968", "rbxassetid://15380237968", "rbxassetid://15380237968", "rbxassetid://15380237968", "rbxassetid://15380237968", "rbxassetid://15380237968" }
		  }
		},
		image = "rbxassetid://15380237898",
		displayName = "Volatile Stone"
	  },
	  magic_glass = {
		image = "rbxassetid://72863067929207",
		description = "Attacks and projectiles phase through this magic window!",
		footstepSound = 4,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  greedyMesh = {
			textures = { "rbxassetid://121238080563616", "rbxassetid://121238080563616", "rbxassetid://121238080563616", "rbxassetid://121238080563616", "rbxassetid://121238080563616", "rbxassetid://121238080563616" }
		  },
		  health = 20
		},
		displayName = "Magic Glass"
	  },
	  spirit_tier_2 = {
		image = "rbxassetid://111150395505933",
		description = "Upgrades your current spirit tier, making your spirits stronger.",
		displayName = "Spirit Tier II"
	  },
	  spruce_log = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 1,
			blockId = 17
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991767140", "rbxassetid://16991767140", "rbxassetid://16991767062", "rbxassetid://16991767062", "rbxassetid://16991767062", "rbxassetid://16991767062" }
		  },
		  health = 30
		},
		image = "rbxassetid://7884371618",
		displayName = "Spruce Log"
	  },
	  auto_cannon = {
		block = {
		  noSuffocation = true,
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12012
		  } },
		  breakType = "stone",
		  health = 100,
		  disableInventoryPickup = true,
		  denyPlaceOn = true,
		  collectionServiceTags = { "cannon-type" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		image = "rbxassetid://10717427845",
		description = "Automatically fires TNT on an interval",
		displayName = "Auto Cannon"
	  },
	  star = {
		hotbarFillRight = true,
		image = "rbxassetid://11774788771",
		description = "Ammo for the Constellation Bow.",
		displayName = "Star"
	  },
	  ballista_ammo = {
		hotbarFillRight = true,
		image = "rbxassetid://17858940500",
		description = "Explosive ballista ammunition to smash through enemy defenses",
		displayName = "Explosive Arrow"
	  },
	  candy = {
		image = "rbxassetid://10013673573",
		sharingDisabled = true,
		displayNameColor = nil,
		hotbarFillRight = true,
		displayName = "Candy"
	  },
	  copper_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 14
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10859696172", "rbxassetid://10859696172", "rbxassetid://10859696172", "rbxassetid://10859696172", "rbxassetid://10859696172", "rbxassetid://10859696172" }
		  }
		},
		image = "rbxassetid://10859696115",
		displayName = "Copper Block"
	  },
	  flying_backpack = {
		image = "rbxassetid://13630754419",
		description = "It's got wings!",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  cooldown = 1,
		  activeAbility = true
		},
		displayName = "Flying Backpack"
	  },
	  spirit_dagger = {
		skins = { "silentnight_spirit_dagger", "gold_victorious_spirit_dagger", "platinum_victorious_spirit_dagger", "diamond_victorious_spirit_dagger", "nightmare_victorious_spirit_dagger" },
		image = "rbxassetid://16385255903",
		sword = {
		  swingAnimations = { 5 },
		  attackSpeed = 0.3,
		  damage = 0
		},
		displayName = "Spirit Dagger"
	  },
	  healing_backpack = {
		image = "rbxassetid://10562874983",
		description = "Gradually heal you and nearby teammates over 10 seconds.",
		maxStackSize = {
		  amount = 1
		},
		backpack = {
		  activeAbility = false
		},
		displayName = "First Aid Kit"
	  },
	  twirlblade = {
		image = "rbxassetid://8795403035",
		sword = {
		  attackSpeed = 1,
		  knockbackMultiplier = {
			horizontal = 1.1
		  },
		  respectAttackSpeedForEffects = true,
		  swingSounds = { },
		  firstPersonSwingAnimations = { 121, 122 },
		  attackRange = 18,
		  swingAnimations = { 117, 118 },
		  cooldown = {
			cooldownBar = {
			  color = nil
			}
		  },
		  applyCooldownOnMiss = true,
		  damage = 50
		},
		displayName = "Twirlblade"
	  },
	  pirate_telescope = {
		image = "rbxassetid://10797226885",
		description = "Grants nearby allies enhanced projectiles",
		displayName = "Pirate Telescope"
	  },
	  orbital_satellite_tablet = {
		consumable = {
		  consumeTime = 0
		},
		image = "rbxassetid://11776141709",
		description = "Controls the Orbital Satellite Laser",
		displayName = "Orbital Satellite Tablet"
	  },
	  pumpkin_block = {
		footstepSound = 2,
		block = {
		  breakType = "wood",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 86
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://14968394203", "rbxassetid://14968394203", "rbxassetid://14968394120", "rbxassetid://14968394120", "rbxassetid://14968394120", "rbxassetid://14968394120" }
		  }
		},
		image = "rbxassetid://14968393998",
		displayName = "Pumpkin Block"
	  },
	  glue_trap = {
		removeFromCustoms = true,
		image = "rbxassetid://7192711008",
		description = "Glue enemy to the ground",
		displayName = "Glue Trap"
	  },
	  pie = {
		skins = { "pie_spirit" },
		image = "rbxassetid://6985761399",
		consumable = {
		  consumeTime = 0.8
		},
		displayName = "Speed Pie"
	  },
	  glue_projectile = {
		image = "rbxassetid://11467634330",
		description = "A throwable glue trap! Hit players will be grounded and slowed.",
		maxStackSize = {
		  amount = 3
		},
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 5
		  },
		  fireDelaySec = 1,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glue_projectile" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		sharingDisabled = true,
		displayName = "Gloop"
	  },
	  santa_bomb_siege = {
		image = "rbxassetid://8273495195",
		description = "Throw to mark a location to drop a Siege TNT bomb.",
		maxStackSize = {
		  amount = 1
		},
		projectileSource = {
		  maxStrengthChargeSec = 1,
		  walkSpeedMultiplier = 0.4,
		  ammoItemTypes = { "santa_bomb_siege" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  fireDelaySec = 0.2
		},
		sharingDisabled = true,
		displayName = "Santa Siege"
	  },
	  natures_essence_1 = {
		image = "rbxassetid://11003449842",
		removeFromCustoms = true,
		displayName = "Nature's Essence I"
	  },
	  baseball_bat = {
		sword = {
		  attackSpeed = 6,
		  swingSounds = { },
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			horizontal = 5
		  },
		  applyCooldownOnMiss = true,
		  damage = 100
		},
		displayName = "Baseball Bat"
	  },
	  new_years_lucky_block = {
		block = {
		  greedyMesh = {
			textures = { "rbxassetid://11958841720", "rbxassetid://11958841720", "rbxassetid://11958841720", "rbxassetid://11958841720", "rbxassetid://11958841720", "rbxassetid://11958841720" }
		  },
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  minecraftConversions = { {
			blockId = 12016
		  } },
		  disableInventoryPickup = true,
		  health = 15
		},
		image = "rbxassetid://11958841642",
		displayName = "New Years Lucky Block"
	  },
	  diamond = {
		image = "rbxassetid://6850538161",
		displayNameColor = nil,
		pickUpOverlaySound = "rbxassetid://10649778845",
		hotbarFillRight = true,
		displayName = "Diamond"
	  },
	  cursed_coffin = {
		image = "rbxassetid://15105666015",
		description = "A chilling chest. Place it down to embrace the night...and become a vampire.",
		footstepSound = 2,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  maxPlaced = 1,
		  breakType = "wood",
		  health = 25,
		  seeThrough = true,
		  blastResistance = 10000000,
		  collectionServiceTags = { "cursed-coffin" },
		  unbreakableByTeammates = true,
		  disableInventoryPickup = true
		},
		itemCatalog = {
		  collection = 2
		},
		displayName = "Cursed Coffin"
	  },
	  pit = {
		projectileSource = {
		  thirdPerson = {
			fireAnimation = 5
		  },
		  fireDelaySec = 1,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "pit" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://101095778694841",
		description = "Throw this item to create a pit at its location. Try make enemies fall into the void!",
		displayName = "Construction Pit"
	  },
	  desert_pot = {
		footstepSound = 1,
		block = {
		  minecraftConversions = { {
			blockId = 8023
		  } },
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil
		},
		displayName = "Pot"
	  },
	  big_shield = {
		maxStackSize = {
		  amount = 3
		},
		image = "rbxassetid://7863380423",
		consumable = {
		  consumeTime = 1.8
		},
		displayName = "Big Shield"
	  },
	  wool_purple = {
		footstepSound = 5,
		block = {
		  placeSound = nil,
		  breakSound = nil,
		  regenSpeed = 0.05,
		  flammable = true,
		  blastResistance = 0.65,
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7923578873", "rbxassetid://7923578873", "rbxassetid://7923578873", "rbxassetid://7923578873", "rbxassetid://7923578873", "rbxassetid://7923578873" }
		  },
		  wool = true,
		  minecraftConversions = { {
			blockData = 10,
			blockId = 35
		  } },
		  breakType = "wool"
		},
		image = "rbxassetid://7923578762",
		displayName = "Purple Wool"
	  },
	  battle_axe = {
		image = "rbxassetid://8795403259",
		sword = {
		  swingSounds = { },
		  cooldown = {
			cooldownBar = {
			  color = nil
			}
		  },
		  attackSpeed = 2,
		  attackRange = 21,
		  respectAttackSpeedForEffects = true,
		  knockbackMultiplier = {
			horizontal = 2
		  },
		  applyCooldownOnMiss = true,
		  damage = 50
		},
		displayName = "Battle Axe"
	  },
	  tinker_weapon_1 = {
		image = "rbxassetid://17024056282",
		sharingDisabled = true,
		skins = { "fish_tank_wood_chainsaw" },
		sword = {
		  attackRange = 17,
		  respectAttackSpeedForEffects = true,
		  attackSpeed = 0.35,
		  damage = 10
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Wood Chainsaw"
	  },
	  ceramic = {
		footstepSound = 1,
		block = {
		  health = 20,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  regenSpeed = 0.1,
		  minecraftConversions = { {
			blockId = 8014
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://16991765474", "rbxassetid://16991765474", "rbxassetid://16991765474", "rbxassetid://16991765474", "rbxassetid://16991765474", "rbxassetid://16991765474" }
		  }
		},
		image = "rbxassetid://7884366622",
		displayName = "Blastproof Ceramic"
	  },
	  diamond_sword = {
		image = "rbxassetid://6875481413",
		description = "Downgrades to an Iron Sword upon death.",
		sharingDisabled = true,
		sword = {
		  attackSpeed = 0.3,
		  damage = 42
		},
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		},
		displayName = "Diamond Sword"
	  },
	  light_sword = {
		image = "rbxassetid://9620517732",
		sharingDisabled = true,
		firstPerson = {
		  scale = 0.8
		},
		skins = { "heavenly_sword_festive_lumen" },
		sword = {
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.85,
			  delay = 0.25
			},
			maxChargeTimeSec = 1.25,
			chargedSwingAnimations = { 164 },
			firstPersonChargedSwingAnimations = { 165 },
			minChargeTimeSec = 0.65
		  },
		  knockbackMultiplier = {
			horizontal = 1
		  },
		  attackSpeed = 0.3,
		  damage = 47
		},
		projectileSource = {
		  minStrengthScalar = 1,
		  projectileType = nil,
		  maxStrengthChargeSec = 1,
		  fireDelaySec = 0.3
		},
		displayName = "Light Sword"
	  },
	  dragon_egg = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  health = 500,
		  unbreakable = true
		},
		displayName = "Dragon Egg"
	  },
	  glitch_grenade_launcher = {
		glitched = true,
		image = "rbxassetid://10086864148",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  activeReload = true,
		  minStrengthScalar = 0.7692307692307692,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glitch_stun_grenade" },
		  fireDelaySec = 2.2,
		  projectileType = nil,
		  launchSound = { "rbxassetid://9135893336" },
		  thirdPerson = {
			fireAnimation = 51,
			aimAnimation = 53
		  }
		},
		displayName = "Rocket Launcher?"
	  },
	  mending_canopy_staff_tier_1 = {
		image = "rbxassetid://17007883118",
		description = "When the sun shine, we shine together!",
		firstPerson = {
		  scale = 0.5
		},
		sharingDisabled = true,
		displayName = "Mending Canopy I"
	  },
	  juggernaut_rage_blade = {
		sword = {
		  attackSpeed = 0.55,
		  attackRange = 15,
		  knockbackMultiplier = {
			horizontal = 1.4,
			vertical = 1.2
		  },
		  swingAnimations = { },
		  applyCooldownOnMiss = true,
		  damage = 35
		},
		image = "rbxassetid://7051149237",
		description = "Only the worthy shall wield this blade.",
		displayName = "Jugg Rage Blade"
	  },
	  glitch_throwable_bridge = {
		glitched = true,
		image = "rbxassetid://10866146253",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glitch_throwable_bridge" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Portable Bridge?"
	  },
	  glitch_robbery_ball = {
		glitched = true,
		image = "rbxassetid://7977038485",
		pickUpOverlaySound = "rbxassetid://10859056155",
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "glitch_robbery_ball" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		displayName = "Robbery Ball?"
	  },
	  void_grass = {
		footstepSound = 0,
		block = {
		  breakType = "grass",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 3
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://15957915501", "rbxassetid://15957915204", "rbxassetid://15957915344", "rbxassetid://15957915344", "rbxassetid://15957915344", "rbxassetid://15957915344" }
		  }
		},
		displayName = "Kresh"
	  },
	  teleport_hat = {
		image = "rbxassetid://12510119944",
		description = "Throw onto target players to gain the a teleport and peek ability.",
		maxStackSize = {
		  amount = 1
		},
		projectileSource = {
		  fireDelaySec = 10,
		  cooldownId = "hat_toss",
		  minStrengthScalar = 0.7692307692307692,
		  ammoItemTypes = { "teleport_hat" },
		  maxStrengthChargeSec = 0.25,
		  projectileType = nil,
		  launchSound = { "rbxassetid://8165640372" },
		  cooldownBar = {
			colorGradient = nil
		  }
		},
		sharingDisabled = true,
		displayName = "Teleport Hat"
	  },
	  jade_hammer = {
		firstPerson = {
		  verticalOffset = -1.2
		},
		image = "rbxassetid://7343272236",
		sharingDisabled = true,
		displayName = "Jade Hammer"
	  },
	  balloon = {
		image = "rbxassetid://7122143895",
		description = "Use up to three times to gain slowfall and jump boost.",
		maxStackSize = {
		  shouldDropExtras = false,
		  amount = 5
		},
		cooldownId = "balloon",
		displayName = "Balloon"
	  },
	  snow_cone_machine = {
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  seeThrough = true,
		  collectionServiceTags = { "SnowConeMachine" },
		  noSuffocation = true,
		  minecraftConversions = { {
			blockData = 2,
			blockId = 12010
		  } }
		},
		displayName = "Snow Cone Machine"
	  },
	  disco_grenade = {
		image = "rbxassetid://15798166322",
		description = "Dance Dance Dance",
		maxStackSize = {
		  amount = 5
		},
		projectileSource = {
		  ammoItemTypes = { "disco_grenade" },
		  fireDelaySec = 0.3,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 54
		  }
		},
		displayName = "Disco Grenade"
	  },
	  big_head_potion = {
		consumable = {
		  potion = true,
		  consumeTime = 0.8
		},
		image = "rbxassetid://9192325186",
		description = "Consume potion to grow yourself a bigger head.",
		displayName = "Big Head Potion"
	  },
	  diamond_helmet = {
		armor = {
		  damageReductionMultiplier = 0.24,
		  slot = 0
		},
		image = "rbxassetid://6874272793",
		sharingDisabled = true,
		displayName = "Diamond Helmet"
	  },
	  iron_ore = {
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 12021
		  } },
		  noRegen = true,
		  seeThrough = true,
		  breakType = "stone",
		  health = 100,
		  disableInventoryPickup = true,
		  blastResistance = 0.25,
		  collectionServiceTags = { "iron-ore" },
		  unbreakableByTeammates = true,
		  breakSound = nil
		},
		displayName = "Iron Ore"
	  },
	  dino_deploy = {
		image = "rbxassetid://9855535867",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		consumable = {
		  keepOnConsume = true,
		  consumeTime = 2,
		  disableAnimation = true,
		  soundOverride = "None"
		},
		displayName = "Dino"
	  },
	  invisible_block = {
		footstepSound = 4,
		block = {
		  disableInventoryPickup = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil
		},
		removeFromCustoms = true,
		displayName = "Void Rock"
	  },
	  gold_block = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 4,
			blockId = 251
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://13456088345", "rbxassetid://13456088345", "rbxassetid://13456088345", "rbxassetid://13456088345", "rbxassetid://13456088345", "rbxassetid://13456088345" }
		  }
		},
		image = "rbxassetid://13465465532",
		displayName = "Gold Block"
	  },
	  health_regen_axolotl = {
		image = "rbxassetid://7863780097",
		displayName = "Health Regen Axolotl"
	  },
	  shears = {
		breakBlock = {
		  wool = 5
		},
		image = "rbxassetid://7261638571",
		sharingDisabled = true,
		displayName = "Shears"
	  },
	  chicken_egg = {
		placesBlock = {
		  blockType = "chicken_egg_block"
		},
		image = "rbxassetid://13988247733",
		sharingDisabled = true,
		displayName = "Egg"
	  },
	  clay_white = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 0,
			blockId = 251
		  }, {
			blockData = 0,
			blockId = 159
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://16991766265", "rbxassetid://16991766265", "rbxassetid://16991766265", "rbxassetid://16991766265", "rbxassetid://16991766265", "rbxassetid://16991766265" }
		  }
		},
		image = "rbxassetid://7884368439",
		displayName = "White Clay"
	  },
	  lucky_block_trap = {
		block = {
		  greedyMesh = {
			textures = { "rbxassetid://7843813175", "rbxassetid://7843813175", "rbxassetid://7843813175", "rbxassetid://7843813175", "rbxassetid://7843813175", "rbxassetid://7843813175" }
		  },
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  blastProof = true,
		  disableInventoryPickup = true,
		  minecraftConversions = { {
			blockId = 9002
		  } },
		  health = 15
		},
		image = "rbxassetid://7884370012",
		displayName = "Lucky Block Trap"
	  },
	  wood_crossbow = {
		replaces = { "wood_bow" },
		sharingDisabled = true,
		skins = { "wood_crossbow_demon_empress_vanessa", "wood_crossbow_valentine" },
		projectileSource = {
		  multiShotChargeTime = 1.6,
		  fireDelaySec = 1.15,
		  projectileType = nil,
		  hitSounds = { { "rbxassetid://6866062188" } },
		  reload = {
			reloadSound = { "rbxassetid://6869254094" }
		  },
		  ammoItemTypes = { "firework_arrow", "arrow", "iron_arrow" },
		  walkSpeedMultiplier = 0.35,
		  thirdPerson = {
			fireAnimation = 128,
			aimAnimation = 127
		  },
		  launchSound = { "rbxassetid://6866062104" },
		  firstPerson = {
			fireAnimation = 17,
			aimAnimation = 16
		  }
		},
		image = "rbxassetid://6869295265",
		displayName = "Crossbow"
	  },
	  big_apple = {
		image = "rbxassetid://75449163962073",
		description = "You'll be full after this",
		maxStackSize = {
		  amount = 2
		},
		consumable = {
		  requiresMissingHealth = true,
		  consumeTime = 2.75
		},
		displayName = "The Big Apple"
	  },
	  stone_tiles = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockId = 201
		  } },
		  greedyMesh = {
			textures = { "rbxassetid://10859698016", "rbxassetid://10859698016", "rbxassetid://10859698016", "rbxassetid://10859698016", "rbxassetid://10859698016", "rbxassetid://10859698016" }
		  }
		},
		image = "rbxassetid://10859697942",
		displayName = "Stone Tiles"
	  },
	  summoner_claw_4 = {
		actsAsSwordGroup = true,
		cooldownId = "summoner_claw_attack",
		keepOnDeath = true,
		displayName = "Summoner Claw IV",
		image = "rbxassetid://18974202582",
		sharingDisabled = true,
		maxStackSize = {
		  amount = 1
		},
		replaces = { "summoner_claw_3" },
		firstPerson = {
		  scale = 0.8,
		  verticalOffset = -1.2
		}
	  },
	  mini_shield = {
		maxStackSize = {
		  amount = 3
		},
		image = "rbxassetid://7863380185",
		consumable = {
		  consumeTime = 0.8
		},
		displayName = "Mini Shield"
	  },
	  target_dummy_block_tier_1 = {
		image = "rbxassetid://15635687324",
		description = "",
		maxStackSize = {
		  amount = 1
		},
		block = {
		  seeThrough = true,
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  disableInventoryPickup = true,
		  collectionServiceTags = { "target-dummy-block" },
		  minecraftConversions = { {
			blockId = 8029
		  } },
		  health = 100
		},
		sharingDisabled = true,
		displayName = "Iron Defender"
	  },
	  leather_chestplate = {
		armor = {
		  damageReductionMultiplier = 0.16,
		  slot = 1
		},
		image = "rbxassetid://6876833204",
		sharingDisabled = true,
		displayName = "Leather Chestplate"
	  },
	  warrior_helmet = {
		armor = {
		  damageReductionMultiplier = 0.24,
		  slot = 0
		},
		image = "rbxassetid://7343992908",
		displayName = "Warrior Helmet"
	  },
	  clay_light_brown = {
		footstepSound = 1,
		block = {
		  breakType = "stone",
		  placeSound = nil,
		  breakSound = nil,
		  minecraftConversions = { {
			blockData = 12,
			blockId = 159
		  }, {
			blockData = 12,
			blockId = 251
		  } },
		  health = 8,
		  greedyMesh = {
			textures = { "rbxassetid://7872905675", "rbxassetid://7872905675", "rbxassetid://7872905675", "rbxassetid://7872905675", "rbxassetid://7872905675", "rbxassetid://7872905675" }
		  }
		},
		image = "rbxassetid://7884367792",
		displayName = "Light Brown Clay"
	  },
	  taser = {
		image = "rbxassetid://7911162966",
		sword = {
		  attackSpeed = 6,
		  swingAnimations = { 5 },
		  knockbackMultiplier = {
			vertical = 0,
			horizontal = 0
		  },
		  swingSounds = { },
		  damage = 1
		},
		displayName = "Taser"
	  },
	  swap_ball = {
		projectileSource = {
		  fireDelaySec = 0.15,
		  maxStrengthChargeSec = 0.25,
		  ammoItemTypes = { "swap_ball" },
		  minStrengthScalar = 0.7692307692307692,
		  projectileType = nil,
		  launchSound = { "rbxassetid://6866223756" },
		  firstPerson = {
			fireAnimation = 14
		  }
		},
		image = "rbxassetid://7681107021",
		description = "Hit players with the ball to swap positions with them.",
		displayName = "Swap Ball"
	  },
	  purple_lucky_block = {
		block = {
		  placeSound = nil,
		  minecraftConversions = { {
			blockId = 9001
		  } },
		  blastProof = true,
		  breakType = "stone",
		  health = 30,
		  greedyMesh = {
			textures = { "rbxassetid://8105570571", "rbxassetid://8105570571", "rbxassetid://8105570571", "rbxassetid://8105570571", "rbxassetid://8105570571", "rbxassetid://8105570571" }
		  },
		  disableInventoryPickup = true,
		  luckyBlock = {
			allowedPolarity = { "positive", "neutral" },
			allowedRarity = { 25, 10, 3 },
			drops = { {
			  luckMultiplier = 4
			} }
		  },
		  breakSound = nil
		},
		image = "rbxassetid://8105570365",
		displayName = "Purple Lucky Block"
	  },
	  iron_great_hammer = {
		image = "rbxassetid://13832632230",
		sharingDisabled = true,
		replaces = { "wood_great_hammer", "stone_great_hammer" },
		damage = 35,
		sword = {
		  attackSpeed = 0.6,
		  swingAnimations = { 416, 417 },
		  respectAttackSpeedForEffects = true,
		  chargedAttack = {
			walkSpeedModifier = {
			  multiplier = 0.9
			},
			minChargeTimeSec = 0.75,
			chargedSwingAnimations = { 418 },
			attackCooldown = 0.65,
			showHoldProgressAfterSec = 0.25,
			maxChargeTimeSec = 0.75,
			chargedSwingSounds = { "rbxassetid://11715550908" },
			bonusDamage = 12.25,
			firstPersonChargedSwingAnimations = { 422 },
			chargingEffects = {
			  thirdPersonAnim = 419,
			  sound = "rbxassetid://9252451221",
			  firstPersonAnim = 423
			},
			bonusKnockback = {
			  vertical = 0.1,
			  horizontal = 0.2
			}
		  },
		  multiHitCheckDurationSec = 0.25,
		  knockbackMultiplier = {
			vertical = 1.1,
			horizontal = 1.2
		  },
		  attackRange = 15,
		  firstPersonSwingAnimations = { 420, 421 },
		  swingSounds = { "rbxassetid://11715551373", "rbxassetid://11715550945" },
		  applyCooldownOnMiss = true,
		  damage = 35
		},
		description = "Deal large amounts of knockback to enemies. Downgrades to a Stone Great Hammer upon death.",
		displayName = "Iron Great Hammer"
	  }
	},
	getItemMeta = nil
  }
bedwars.ItemHandler.getItemMeta = function(item)
    for i,v in pairs(bedwars.ItemHandler.ItemMeta) do
        if i == item then return v end
    end
    return nil
end
bedwars.ItemTable = bedwars.ItemHandler.ItemMeta.items
function bedwars.Client:GetNamespace(nameSpace, blacklist)
    local cacheKey = nameSpace .. (blacklist and table.concat(blacklist, ",") or "")
    if namespaceCache[cacheKey] then
        return namespaceCache[cacheKey]
    end
    local remotes = getRemotes({"ReplicatedStorage"})
    local resolvedRemotes = {}
    blacklist = blacklist or {}
    for _, v in pairs(remotes) do
        if (v.Name == nameSpace or string.find(v.Name, nameSpace)) and not table.find(blacklist, v.Name) then
            table.insert(resolvedRemotes, v)
        end
    end
    local resolveFunctionTable = {Namespace = resolvedRemotes}
    function resolveFunctionTable:Get(remName)
        return bedwars.Client:Get(remName, resolvedRemotes)
    end
    namespaceCache[cacheKey] = resolveFunctionTable 
    return resolveFunctionTable
end

function bedwars.Client:WaitFor(remName)
	local tbl = {}
	function tbl:andThen(func)
		repeat task.wait() until bedwars.Client:Get(remName)
		func(bedwars.Client:Get(remName).OnClientEvent)
	end
	return tbl
end 
local cache = {}
local function getItemNear(itemName, inv)
    inv = inv or store.localInventory.inventory.items
    if cache[itemName] then
        local cachedItem, cachedSlot = cache[itemName].item, cache[itemName].slot
        if inv[cachedSlot] and inv[cachedSlot].itemType == cachedItem.itemType then
            return cachedItem, cachedSlot
        else
            cache[itemName] = nil
        end
    end
    for slot, item in pairs(inv) do
        if item.itemType == itemName or item.itemType:find(itemName) then
            cache[itemName] = { item = item, slot = slot }
            return item, slot
        end
    end
    return nil
end
local function switchItem(tool)
	if (entitylib.isAlive and lplr.Character:FindFirstChild("HandInvItem")) then
		if lplr.Character:FindFirstChild("HandInvItem").Value ~= tool then
			bedwars.Client:Get(bedwars.EquipItemRemote):InvokeServer({
				hand = tool
			})
			local started = tick()
			repeat task.wait() until (tick() - started) > 0.3 or lplr.Character:FindFirstChild("HandInvItem") and lplr.Character:FindFirstChild("HandInvItem").Value == tool
		end
	end
end
bedwars.breakBlock2 = function(block)
	if block.Name == "bed" and tostring(block:GetAttribute("TeamId")) == tostring(game:GetService("Players").LocalPlayer:GetAttribute("Team")) then return end
	local RayRes = bedwars.BlockController:resolveRaycastResult(block)
	local res
	if RayRes then
		res = RayRes.Instance or block	
		local result = bedwars.Client:Get(bedwars.DamageBlockRemote):InvokeServer({
			blockRef = {
				blockPosition = bedwars.BlockController:resolveBreakPosition(res.Position)
			},
			hitPosition = bedwars.BlockController:resolveBreakPosition(res.Position),
			hitNormal = bedwars.BlockController:resolveBreakPosition(res.Position)
		})
		if result ~= "failed" then
			failedBreak = 0
			task.spawn(function()
				local animation
				if anim then
					local lplr = game:GetService("Players").LocalPlayer
					animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(bedwars.AnimationUtil:fetchAnimationIndexId("BREAK_BLOCK")))
				end
				task.wait(0.3)
				if animation ~= nil then
					animation:Stop()
					animation:Destroy()
				end
			end)
		else
			failedBreak = failedBreak + 1
		end
	end
end
run(function()
	local NoFall = {Enabled = false}
	local oldfall
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = "NoFall",
		Function = function(callback)
			if callback then
				bedwars.Client:Get("GroundHit"):FireServer()
			end
		end,
		HoverText = "Prevents taking fall damage."
	})
end)
run(function()
	local AutoConsume = {Enabled = false}
	function chck(item)
		if workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:FindFirstChild(item) then
			return true, 1
		end
		return false
	end
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = "AutoConsume",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait()
						if chck("speed_potion") then
							bedwars.Client:Get(bedwars.EatRemote):InvokeServer({
								["item"] = workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:WaitForChild("speed_potion")
							})
						end
						if game.Players.LocalPlayer.Character.Humanoid and game.Players.LocalPlayer.Character.Humanoid.Health < 80 then
							if chck("apple") then
								bedwars.Client:Get(bedwars.EatRemote):InvokeServer({
									["item"] = workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:WaitForChild("apple")
								})
							end
							if chck("pie") then
								bedwars.Client:Get(bedwars.EatRemote):InvokeServer({
									["item"] = workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:WaitForChild("pie")
								})
							end
						end
					until (not AutoConsume.Enabled)
				end)
			end
		end,
	})
end)
run(function()
	local Nuker = {Enabled = false}
	local nukerrange = {Value = 1}
	local nukerslowmode = {Value = 0.2}
	local nukereffects = {Enabled = false}
	local nukeranimation = {Enabled = false}
	local nukernofly = {Enabled = false}
	local nukerlegit = {Enabled = false}
	local nukerown = {Enabled = false}
	local nukerbeds = {Enabled = false}
	local luckyblocktable = {}

	Nuker = vape.Categories.Minigames:CreateModule({
		Name = "Breaker",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						if (not nukernofly.Enabled) then
							local tool = (not nukerlegit.Enabled) and {Name = "wood_axe"} or {Name = "wood_pickaxe"} or store.localHand.tool 
							if nukerbeds.Enabled then
								for i, obj in pairs(collectionService:GetTagged("bed")) do
									if obj.Parent ~= nil then
										if ((entitylib.character.HumanoidRootPart.Position) - obj.Position).magnitude <= nukerrange.Value then
											if tool and bedwars.ItemTable[tool.Name].breakBlock then
												bedwars.breakBlock2(obj, nukeranimation.Enabled)
												task.wait(nukerslowmode.Value/10)
												break
											end
										end
									end
								end
							end
							for i, obj in pairs(luckyblocktable) do
								if entitylib.isAlive then
									if obj and obj.Parent ~= nil then
										if ((entitylib.character.HumanoidRootPart.Position) - obj.Position).magnitude <= nukerrange.Value and (nukerown.Enabled or obj:GetAttribute("PlacedByUserId") ~= lplr.UserId) then
											if tool and bedwars.ItemTable[tool.Name].breakBlock then
												bedwars.breakBlock(obj, nukeranimation.Enabled)
												break
											end
										end
									end
								end
							end
						end
						task.wait()
					until (not Nuker.Enabled)
				end)
			else
				luckyblocktable = {}
			end
		end,
		HoverText = "Automatically destroys beds & luckyblocks around you."
	})
	nukerrange = Nuker:CreateSlider({
		Name = "Break range",
		Min = 1,
		Max = 30,
		Function = function(val) end,
		Default = 30
	})
	nukerlegit = Nuker:CreateToggle({
		Name = "Hand Check",
		Function = function() end
	})
	nukeranimation = Nuker:CreateToggle({
		Name = "Break Animation",
		Function = function() end
	})
	nukerown = Nuker:CreateToggle({
		Name = "Self Break",
		Function = function() end,
	})
	nukerbeds = Nuker:CreateToggle({
		Name = "Break Beds",
		Function = function(callback) end,
		Default = true
	})
	nukernofly = Nuker:CreateToggle({
		Name = "Fly Disable",
		Function = function() end
	})
end)

run(function()
	local stored = {}
	local AutoReport = {Enabled = false}
	AutoReport = vape.Categories.Utility:CreateModule({
		Name = "AutoReport",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait()
						for _, player in ipairs(game:GetService("Players"):GetPlayers()) do if player ~= game.Players.LocalPlayer then table.insert(args, player.UserId) end end
						game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("ReportPlayer"):FireServer(unpack(args))
					until (not AutoReport.Enabled)
				end)
			end
		end
	})
end)

run(function()
	local FieldOfView = {Enabled = false}
	local FieldOfViewZoom = {Enabled = false}
	local FieldOfViewValue = {Value = 70}
	local oldfov
	FieldOfView = vape.Categories.Render:CreateModule({
		Name = "FOVChanger",
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				if FieldOfViewZoom.Enabled then
					task.spawn(function()
						repeat
							task.wait()
						until inputService:IsKeyDown(Enum.KeyCode[FieldOfView.Keybind ~= "" and FieldOfView.Keybind or "C"]) == false
						if FieldOfView.Enabled then
							FieldOfView.ToggleButton(false)
						end
					end)
				end
				task.spawn(function()
					repeat
						gameCamera.FieldOfView = FieldOfViewValue.Value
						task.wait()
					until (not FieldOfView.Enabled)
				end)
			else
				gameCamera.FieldOfView = oldfov
			end
		end
	})
	FieldOfViewValue = FieldOfView:CreateSlider({
		Name = 'FOV',
		Function = function(val) end,
		Default = 80,
		Min = 30,
		Max = 120,
		Decimal = 10
	})
	FieldOfViewZoom = FieldOfView:CreateToggle({
		Name = "Zoom",
		Function = function() end,
		HoverText = "optifine zoom lol"
	})
end)
run(function()
	local chests = {}
	local ChestStealer = {Enabled = false}
	for i,v in pairs(workspace:GetChildren()) do
		if v.Name == "chest" then
			table.insert(chests,v)
		end
	end
	ChestStealer = vape.Categories.Inventory:CreateModule({
		Name = "ChestStealer",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait()
						task.wait(0.15)
						task.spawn(function()
							for i, v in pairs(chests) do
								local Magnitude = (v.Position - workspace[game.Players.LocalPlayer.Name].HumanoidRootPart.Position).Magnitude
								if Magnitude <= 30 then
									for _, item in pairs(v.ChestFolderValue.Value:GetChildren()) do
										if item:IsA("Accessory") then
											task.wait()
											game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):FindFirstChild("@rbxts").net.out._NetManaged:FindFirstChild("Inventory/ChestGetItem"):InvokeServer(v.ChestFolderValue.Value, item)
										end
									end
								end
							end
						end)
					until (not ChestStealer.Enabled)
				end)
			end
		end,
	})
end)
run(function()
	local function getallblocks2(pos, normal)
		local blocks = {}
		local lastfound = nil
		for i = 1, 20 do
			local blockpos = (pos + (Vector3.FromNormalId(normal) * (i * 3)))
			local extrablock = getPlacedBlock(blockpos)
			local covered = true
			if extrablock and extrablock.Parent ~= nil then
				if bedwars.BlockController:isBlockBreakable({blockPosition = blockpos}, lplr) then
					table.insert(blocks, extrablock:GetAttribute("NoBreak") and "unbreakable" or extrablock.Name)
				else
					table.insert(blocks, "unbreakable")
					break
				end
				lastfound = extrablock
				if covered == false then
					break
				end
			else
				break
			end
		end
		return blocks
	end

	local function getallbedblocks(pos)
		local blocks = {}
		for i,v in pairs(cachedNormalSides) do
			for i2,v2 in pairs(getallblocks2(pos, v)) do
				if table.find(blocks, v2) == nil and v2 ~= "bed" then
					table.insert(blocks, v2)
				end
			end
			for i2,v2 in pairs(getallblocks2(pos + Vector3.new(0, 0, 3), v)) do
				if table.find(blocks, v2) == nil and v2 ~= "bed" then
					table.insert(blocks, v2)
				end
			end
		end
		return blocks
	end

	local function refreshAdornee(v)
		local bedblocks = getallbedblocks(v.Adornee.Position)
		for i2,v2 in pairs(v.Frame:GetChildren()) do
			if v2:IsA("ImageLabel") then
				v2:Remove()
			end
		end
		for i3,v3 in pairs(bedblocks) do
			local blockimage = Instance.new("ImageLabel")
			blockimage.Size = UDim2.new(0, 32, 0, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = v3}, true)
			blockimage.Parent = v.Frame
		end
	end

	local BedPlatesFolder = Instance.new("Folder")
	BedPlatesFolder.Name = "BedPlatesFolder"
	BedPlatesFolder.Parent = game:GetService("CoreGui")
	local BedPlatesTable = {}
	local BedPlates = {Enabled = false}

	local function addBed(v)
		local billboard = Instance.new("BillboardGui")
		billboard.Parent = BedPlatesFolder
		billboard.Name = "bed"
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 1.5)
		billboard.Size = UDim2.new(0, 42, 0, 42)
		billboard.AlwaysOnTop = true
		billboard.Adornee = v
		BedPlatesTable[v] = billboard
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 0.5
		frame.Parent = billboard
		local uilistlayout = Instance.new("UIListLayout")
		uilistlayout.FillDirection = Enum.FillDirection.Horizontal
		uilistlayout.Padding = UDim.new(0, 4)
		uilistlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		uilistlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		uilistlayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			billboard.Size = UDim2.new(0, math.max(uilistlayout.AbsoluteContentSize.X + 12, 42), 0, 42)
		end)
		uilistlayout.Parent = frame
		local uicorner = Instance.new("UICorner")
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = frame
		refreshAdornee(billboard)
	end

	BedPlates = vape.Categories.Minigames:CreateModule({
		Name = "BedPlates",
		Function = function(callback)
			if callback then
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(function(p5)
					for i, v in pairs(BedPlatesFolder:GetChildren()) do
						if v.Adornee then
							if ((p5.blockRef.blockPosition * 3) - v.Adornee.Position).magnitude <= 20 then
								refreshAdornee(v)
							end
						end
					end
				end))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(p5)
					for i, v in pairs(BedPlatesFolder:GetChildren()) do
						if v.Adornee then
							if ((p5.blockRef.blockPosition * 3) - v.Adornee.Position).magnitude <= 20 then
								refreshAdornee(v)
							end
						end
					end
				end))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal("bed"):Connect(function(v)
					addBed(v)
				end))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal("bed"):Connect(function(v)
					if BedPlatesTable[v] then
						BedPlatesTable[v]:Destroy()
						BedPlatesTable[v] = nil
					end
				end))
				for i, v in pairs(collectionService:GetTagged("bed")) do
					addBed(v)
				end
			else
				BedPlatesFolder:ClearAllChildren()
			end
		end
	})
end)
run(function()
    local FPSBoost = {Enabled = false}
    local settings = {
        shadowsEnabled = true,
        particlesEnabled = true,
        renderDistance = 1000,
        textureQuality = 1,
        decorations = true,
        lighting = true,
        maxParticles = 100
    }
    FPSBoost = vape.Categories.Render:CreateModule({
        Name = "FPSBoost",
        Function = function(callback)
            if callback then
                local lighting = game:GetService("Lighting")
                local terrain = workspace.Terrain
                local originals = {
                    brightness = lighting.Brightness,
                    globalShadows = lighting.GlobalShadows,
                    fogEnd = lighting.FogEnd,
                    waterWaveSize = terrain.WaterWaveSize,
                    waterWaveSpeed = terrain.WaterWaveSpeed
                }
                if not settings.shadowsEnabled then
                    lighting.GlobalShadows = false
                end
                if not settings.lighting then
                    lighting.Brightness = 1
                    lighting.FogEnd = 9e9
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                end
                settings.renderDistance = math.clamp(settings.renderDistance, 100, 10000)
                for _, descendant in pairs(workspace:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        if not settings.decorations and descendant.Name:lower():find("decoration") then
                            descendant.Transparency = 1
                        end
                        descendant.CastShadow = settings.shadowsEnabled
                    end
                end
                for _, particle in pairs(workspace:GetDescendants()) do
                    if particle:IsA("ParticleEmitter") then
                        if not settings.particlesEnabled then
                            particle.Enabled = false
                        else
                            particle.Rate = math.min(particle.Rate, settings.maxParticles)
                        end
                    end
                end
                if settings.textureQuality < 1 then
                    settings.savedTextures = {}
                    for _, v in pairs(game:GetDescendants()) do
                        if v:IsA("Texture") or v:IsA("Decal") then
                            settings.savedTextures[v] = v.Transparency
                            v.Transparency = 1
                        end
                    end
                end
            else
                local lighting = game:GetService("Lighting")
                lighting.GlobalShadows = true
                lighting.Brightness = 2
                lighting.FogEnd = 100000
                workspace.Terrain.WaterWaveSize = 0.15
                workspace.Terrain.WaterWaveSpeed = 10
                if settings.savedTextures then
                    for texture, transparency in pairs(settings.savedTextures) do
                        if texture then
                            texture.Transparency = transparency
                        end
                    end
                end
            end
        end
    })
    FPSBoost:CreateToggle({
        Name = "Shadows",
        Function = function(callback) 
            settings.shadowsEnabled = callback
        end,
        Default = true
    })
    FPSBoost:CreateToggle({
        Name = "Particles",
        Function = function(callback)
            settings.particlesEnabled = callback
        end,
        Default = true
    })
    FPSBoost:CreateToggle({
        Name = "Decorations",
        Function = function(callback)
            settings.decorations = callback
        end,
        Default = true
    })
    FPSBoost:CreateToggle({
        Name = "Lighting Effects",
        Function = function(callback)
            settings.lighting = callback
        end,
        Default = true
    })
    FPSBoost:CreateSlider({
        Name = "Render Distance",
        Min = 100,
        Max = 10000,
        Function = function(val)
            settings.renderDistance = val
        end,
        Default = 1000
    })
    FPSBoost:CreateSlider({
        Name = "Texture Quality",
        Min = 0,
        Max = 1,
        Function = function(val)
            settings.textureQuality = val
        end,
        Default = 1
    })
    FPSBoost:CreateSlider({
        Name = "Max Particles",
        Min = 0,
        Max = 500,
        Function = function(val)
            settings.maxParticles = val
        end,
        Default = 100
    })
end)
run(function()
	local PickupRangeRange = {Value = 1}
	local PickupRange = {Enabled = false}
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = "PickupRange",
		Function = function(callback)
			if callback then
				local pickedup = {}
				task.spawn(function()
					repeat
						local itemdrops = collectionService:GetTagged("ItemDrop")
						for i,v in pairs(itemdrops) do
							if entitylib.isAlive and (v:GetAttribute("ClientDropTime") and tick() - v:GetAttribute("ClientDropTime") > 2 or v:GetAttribute("ClientDropTime") == nil) then
								if ((entitylib.character.HumanoidRootPart.Position) - v.Position).magnitude <= PickupRangeRange.Value and (pickedup[v] == nil or pickedup[v] <= tick()) then
									task.spawn(function()
										pickedup[v] = tick() + 0.2
										bedwars.Client:Get(bedwars.PickupRemote):InvokeServer({itemDrop = v})
									end)
								end
							end
						end
						task.wait(0.2)
					until (not PickupRange.Enabled)
				end)
			end
		end
	})
	PickupRangeRange = PickupRange:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 10,
		Function = function() end,
		Default = 10
	})
end)
run(function()
	local KitESP = {Enabled = false}
	local espobjs = {}
	local espfold = Instance.new("Folder")
	espfold.Parent = game:GetService("CoreGui")

	local function espadd(v, icon)
		local billboard = Instance.new("BillboardGui")
		billboard.Parent = espfold
		billboard.Name = "iron"
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 1.5)
		billboard.Size = UDim2.new(0, 32, 0, 32)
		billboard.AlwaysOnTop = true
		billboard.Adornee = v
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 0.5
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		image.Size = UDim2.new(0, 32, 0, 32)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Parent = billboard
		local uicorner = Instance.new("UICorner")
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		espobjs[v] = billboard
	end

	local function addKit(tag, icon, custom)
		if (not custom) then
			KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				espadd(v.PrimaryPart, icon)
			end))
			KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if espobjs[v.PrimaryPart] then
					espobjs[v.PrimaryPart]:Destroy()
					espobjs[v.PrimaryPart] = nil
				end
			end))
			for i,v in pairs(collectionService:GetTagged(tag)) do
				espadd(v.PrimaryPart, icon)
			end
		else
			local function check(v)
				if v.Name == tag and v.ClassName == "Model" then
					espadd(v.PrimaryPart, icon)
				end
			end
			KitESP:Clean(game.Workspace.ChildAdded:Connect(check))
			KitESP:Clean(game.Workspace.ChildRemoved:Connect(function(v)
				pcall(function()
					if espobjs[v.PrimaryPart] then
						espobjs[v.PrimaryPart]:Destroy()
						espobjs[v.PrimaryPart] = nil
					end
				end)
			end))
			for i,v in pairs(game.Workspace:GetChildren()) do
				check(v)
			end
		end
	end

	KitESP = vape.Categories.Render:CreateModule({
		Name = "KitESP",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until store.equippedKit ~= ""
					if KitESP.Enabled then
						if store.equippedKit == "metal_detector" then
							addKit("hidden-metal", "iron")
						elseif store.equippedKit == "beekeeper" then
							addKit("bee", "bee")
						elseif store.equippedKit == "bigman" then
							addKit("treeOrb", "natures_essence_1")
						elseif store.equippedKit == "alchemist" then
							addKit("Thorns", "thorns", true)
							addKit("Mushrooms", "mushrooms", true)
							addKit("Flower", "wild_flower", true)
						elseif store.equippedKit == "star_collector" then
							addKit("CritStar", "crit_star", true)
							addKit("VitalityStar", "vitality_star", true)
						end
					end
				end)
			else
				espfold:ClearAllChildren()
				table.clear(espobjs)
			end
		end
	})
end)
run(function()
	local nobobdepth = {Value = 8}
	local nobobhorizontal = {Value = 8}
	local nobobvertical = {Value = -2}
	local rotationx = {Value = 0}
	local rotationy = {Value = 0}
	local rotationz = {Value = 0}
	local oldc1
	local oldfunc
	local nobob = vape.Categories.Render:CreateModule({
		Name = "NoBob",
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild("Viewmodel")
			if viewmodel then
				if callback then
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_DEPTH_OFFSET", -(nobobdepth.Value / 10))
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_HORIZONTAL_OFFSET", (nobobhorizontal.Value / 10))
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_VERTICAL_OFFSET", (nobobvertical.Value / 10))
					oldc1 = viewmodel.RightHand.RightWrist.C1
					viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(rotationx.Value), math.rad(rotationy.Value), math.rad(rotationz.Value))
				else
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_DEPTH_OFFSET", 0)
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_HORIZONTAL_OFFSET", 0)
					lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_VERTICAL_OFFSET", 0)
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
			end
		end,
		HoverText = "Removes the ugly bobbing when you move and makes sword farther"
	})
	nobobdepth = nobob:CreateSlider({
		Name = "Depth",
		Min = 0,
		Max = 24,
		Default = 8,
		Function = function(val)
			if nobob.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_DEPTH_OFFSET", -(val / 10))
			end
		end
	})
	nobobhorizontal = nobob:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 24,
		Default = 8,
		Function = function(val)
			if nobob.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_HORIZONTAL_OFFSET", (val / 10))
			end
		end
	})
	nobobvertical= nobob:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 24,
		Default = -2,
		Function = function(val)
			if nobob.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel["viewmodel-controller"]:SetAttribute("ConstantManager_VERTICAL_OFFSET", (val / 10))
			end
		end
	})
	rotationx = nobob:CreateSlider({
		Name = "RotX",
		Min = 0,
		Max = 360,
		Function = function(val)
			if nobob.Enabled then
				gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(rotationx.Value), math.rad(rotationy.Value), math.rad(rotationz.Value))
			end
		end
	})
	rotationy = nobob:CreateSlider({
		Name = "RotY",
		Min = 0,
		Max = 360,
		Function = function(val)
			if nobob.Enabled then
				gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(rotationx.Value), math.rad(rotationy.Value), math.rad(rotationz.Value))
			end
		end
	})
	rotationz = nobob:CreateSlider({
		Name = "RotZ",
		Min = 0,
		Max = 360,
		Function = function(val)
			if nobob.Enabled then
				gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(rotationx.Value), math.rad(rotationy.Value), math.rad(rotationz.Value))
			end
		end
	})
end)
bedwars.BalloonController = {}
function bedwars.BalloonController:inflateBalloon()
	bedwars.Client:Get("InflateBalloon"):FireServer()
end
local autobankballoon = false
run(function()
	local Fly = {Enabled = false}
	local FlyMode = {Value = "CFrame"}
	local FlyVerticalSpeed = {Value = 40}
	local FlyVertical = {Enabled = true}
	local FlyAutoPop = {Enabled = true}
	local FlyAnyway = {Enabled = false}
	local FlyAnywayProgressBar = {Enabled = false}
	local FlyTP = {Enabled = false}
	local FlyAnywayProgressBarFrame
	local olddeflate
	local FlyUp = false
	local FlyDown = false
	local FlyCoroutine
	local groundtime = tick()
	local onground = false
	local lastonground = false
	local alternatelist = {"Normal", "AntiCheat A", "AntiCheat B"}

	local function inflateBalloon()
		if not Fly.Enabled then return end
		if entitylib.isAlive and (lplr.Character:GetAttribute("InflatedBalloons") or 0) < 1 then
			autobankballoon = true
			if getItem("balloon") then
				bedwars.BalloonController:inflateBalloon()
				return true
			end
		end
		return false
	end
	shared.zephyrActive = false
	shared.scytheActive = false
	shared.SpeedBoostEnabled = false
	shared.scytheSpeed = 5
	local lastdamagetick = tick()
	local function getSpeed(reduce)
		local speed = 0
		if lplr.Character then
			local SpeedDamageBoost = lplr.Character:GetAttribute("SpeedBoost")
			if SpeedDamageBoost and SpeedDamageBoost > 1 then
				speed = speed + (8 * (SpeedDamageBoost - 1))
			end
			if store.grapple > tick() then
				speed = speed + 90
			end
			if store.scythe > tick() and shared.scytheActive then
				speed = speed + shared.scytheSpeed
			end
			if lplr.Character:GetAttribute("GrimReaperChannel") then
				speed = speed + 20
			end
			if lastdamagetick > tick() and shared.SpeedBoostEnabled then
				speed = speed + 10
			end;
			local armor = store.localInventory.inventory.armor[3]
			if type(armor) ~= "table" then armor = {itemType = ""} end
			if armor.itemType == "speed_boots" then
				speed = speed + 12
			end
			if store.zephyrOrb ~= 0 then
				speed = speed + 12
			end
			if store.zephyrOrb ~= 0 and shared.zephyrActive then
				isZephyr = true
			else
				isZephyr = false
			end
		end
		return reduce and speed ~= 1 and math.max(speed * (0.8 - (0.3 * math.floor(speed))), 1) or speed
	end
	Fly = vape.Categories.Blatant:CreateModule({
		Name = "Fly",
		Function = function(callback)
			if callback then
				olddeflate = bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				Fly:Clean(inputService.InputBegan:Connect(function(input1)
					if FlyVertical.Enabled and inputService:GetFocusedTextBox() == nil then
						if input1.KeyCode == Enum.KeyCode.Space or input1.KeyCode == Enum.KeyCode.ButtonA then
							FlyUp = true
						end
						if input1.KeyCode == Enum.KeyCode.LeftShift or input1.KeyCode == Enum.KeyCode.ButtonL2 then
							FlyDown = true
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input1)
					if input1.KeyCode == Enum.KeyCode.Space or input1.KeyCode == Enum.KeyCode.ButtonA then
						FlyUp = false
					end
					if input1.KeyCode == Enum.KeyCode.LeftShift or input1.KeyCode == Enum.KeyCode.ButtonL2 then
						FlyDown = false
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
							FlyUp = jumpButton.ImageRectOffset.X == 146
						end))
						FlyUp = jumpButton.ImageRectOffset.X == 146
					end)
				end
				Fly:Clean(vapeEvents.BalloonPopped.Event:Connect(function(poppedTable)
					if poppedTable.inflatedBalloon and poppedTable.inflatedBalloon:GetAttribute("BalloonOwner") == lplr.UserId then
						lastonground = not onground
						repeat task.wait() until (lplr.Character:GetAttribute("InflatedBalloons") or 0) <= 0 or not Fly.Enabled
						inflateBalloon()
					end
				end))
				Fly:Clean(vapeEvents.AutoBankBalloon.Event:Connect(function()
					repeat task.wait() until getItem("balloon")
					inflateBalloon()
				end))

				local balloons
				if entitylib.isAlive and (not store.queueType:find("mega")) then
					balloons = inflateBalloon()
				end
				local megacheck = store.queueType:find("mega") or store.queueType == "winter_event"

				task.spawn(function()
					repeat task.wait() until store.queueType ~= "bedwars_test" or (not Fly.Enabled)
					if not Fly.Enabled then return end
					megacheck = store.queueType:find("mega") or store.queueType == "winter_event"
				end)

				local flyAllowed = entitylib.isAlive and ((lplr.Character:GetAttribute("InflatedBalloons") and lplr.Character:GetAttribute("InflatedBalloons") > 0) or store.matchState == 2 or megacheck) and 1 or 0

				if FlyAnywayProgressBarFrame and flyAllowed <= 0 and (not balloons) then
					FlyAnywayProgressBarFrame.Visible = true
					pcall(function() FlyAnywayProgressBarFrame.Frame:TweenSize(UDim2.new(1, 0, 0, 20), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0, true) end)
				end

				groundtime = tick() + (2.6)
				FlyCoroutine = coroutine.create(function()
					repeat
						repeat task.wait() until (groundtime - tick()) < 0.6 and not onground
						flyAllowed = ((lplr.Character and lplr.Character:GetAttribute("InflatedBalloons") and lplr.Character:GetAttribute("InflatedBalloons") > 0) or store.matchState == 2 or megacheck) and 1 or 0
						if (not Fly.Enabled) then break end
						local Flytppos = -99999
						if flyAllowed <= 0 and FlyTP.Enabled and entitylib.isAlive then
							local ray = game.Workspace:Raycast(entitylib.character.HumanoidRootPart.Position, Vector3.new(0, -1000, 0), store.blockRaycast)
							if ray then
								Flytppos = entitylib.character.HumanoidRootPart.Position.Y
								local args = {entitylib.character.HumanoidRootPart.CFrame:GetComponents()}
								args[2] = ray.Position.Y + (entitylib.character.HumanoidRootPart.Size.Y / 2) + entitylib.character.Humanoid.HipHeight
								entitylib.character.HumanoidRootPart.CFrame = CFrame.new(unpack(args))
								task.wait(0.12)
								if (not Fly.Enabled) then break end
								flyAllowed = ((lplr.Character and lplr.Character:GetAttribute("InflatedBalloons") and lplr.Character:GetAttribute("InflatedBalloons") > 0) or store.matchState == 2 or megacheck) and 1 or 0
								if flyAllowed <= 0 and Flytppos ~= -99999 and entitylib.isAlive then
									local args = {entitylib.character.HumanoidRootPart.CFrame:GetComponents()}
									args[2] = Flytppos
									entitylib.character.HumanoidRootPart.CFrame = CFrame.new(unpack(args))
								end
							end
						end
					until (not Fly.Enabled)
				end)
				coroutine.resume(FlyCoroutine)
				Fly:Clean(runService.Heartbeat:Connect(function(delta)
					if entitylib.isAlive then
						local playerMass = (entitylib.character.HumanoidRootPart:GetMass() - 1.4) * (delta * 100)
						flyAllowed = ((lplr.Character:GetAttribute("InflatedBalloons") and lplr.Character:GetAttribute("InflatedBalloons") > 0) or store.matchState == 2 or megacheck) and 1 or 0
						playerMass = playerMass + (flyAllowed > 0 and 4 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)

						if FlyAnywayProgressBarFrame then
							FlyAnywayProgressBarFrame.Visible = flyAllowed <= 0
							FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
							pcall(function()
								FlyAnywayProgressBarFrame.Frame.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
							end)
						end

						if flyAllowed <= 0 then
							local newray = getPlacedBlock(entitylib.character.HumanoidRootPart.Position + Vector3.new(0, (entitylib.character.Humanoid.HipHeight * -2) - 1, 0))
							onground = newray and true or false
							if lastonground ~= onground then
								if (not onground) then
									groundtime = tick() + (2.6)
									if FlyAnywayProgressBarFrame then
										FlyAnywayProgressBarFrame.Frame:TweenSize(UDim2.new(0, 0, 0, 20), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, groundtime - tick(), true)
									end
								else
									if FlyAnywayProgressBarFrame then
										FlyAnywayProgressBarFrame.Frame:TweenSize(UDim2.new(1, 0, 0, 20), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0, true)
									end
								end
							end
							if FlyAnywayProgressBarFrame then
								FlyAnywayProgressBarFrame.TextLabel.Text = math.max(onground and 2.5 or math.floor((groundtime - tick()) * 10) / 10, 0).."s"
							end
							lastonground = onground
						else
							onground = true
							lastonground = true
						end

						local flyVelocity = entitylib.character.Humanoid.MoveDirection * (FlyMode.Value == "Normal" and FlySpeed.Value or 20)
						entitylib.character.HumanoidRootPart.Velocity = flyVelocity + (Vector3.new(0, playerMass + (FlyUp and FlyVerticalSpeed.Value or 0) + (FlyDown and -FlyVerticalSpeed.Value or 0), 0))
						if FlyMode.Value ~= "Normal" then
							entitylib.character.HumanoidRootPart.CFrame = entitylib.character.HumanoidRootPart.CFrame + (entitylib.character.Humanoid.MoveDirection * ((FlySpeed.Value + getSpeed()) - 20)) * delta
						end
					end
				end))
			else
				pcall(function() coroutine.close(FlyCoroutine) end)
				autobankballoon = false
				waitingforballoon = false
				lastonground = nil
				FlyUp = false
				FlyDown = false
				if FlyAnywayProgressBarFrame then
					FlyAnywayProgressBarFrame.Visible = false
				end
				if FlyAutoPop.Enabled then
					if entitylib.isAlive and lplr.Character:GetAttribute("InflatedBalloons") then
						for i = 1, lplr.Character:GetAttribute("InflatedBalloons") do
							olddeflate()
						end
					end
				end
				bedwars.BalloonController.deflateBalloon = olddeflate
				olddeflate = nil
			end
		end,
		HoverText = "Makes you go zoom (longer Fly discovered by exelys and Cqded)",
		ExtraText = function()
			return "Heatseeker"
		end
	})
	FlySpeed = Fly:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 23,
		Function = function(val) end,
		Default = 23
	})
	FlyVerticalSpeed = Fly:CreateSlider({
		Name = "Vertical Speed",
		Min = 1,
		Max = 100,
		Function = function(val) end,
		Default = 44
	})
	FlyVertical = Fly:CreateToggle({
		Name = "Y Level",
		Function = function() end,
		Default = true
	})
	FlyAutoPop = Fly:CreateToggle({
		Name = "Pop Balloon",
		Function = function() end,
		HoverText = "Pops balloons when Fly is disabled."
	})
	local oldcamupdate
	local camcontrol
	FlyTP = Fly:CreateToggle({
		Name = "TP Down",
		Function = function() end,
		Default = true
	})
end)
local anims = {
    Normal = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(295), math.rad(55), math.rad(290)), Time = 0.05},
        {CFrame = CFrame.new(0.69, -0.71, 0.6) * CFrame.Angles(math.rad(200), math.rad(60), math.rad(1)), Time = 0.05}
    },
    Slow = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(295), math.rad(55), math.rad(290)), Time = 0.15},
        {CFrame = CFrame.new(0.69, -0.71, 0.6) * CFrame.Angles(math.rad(200), math.rad(60), math.rad(1)), Time = 0.15}
    },
    New = {
        {CFrame = CFrame.new(0.69, -0.77, 1.47) * CFrame.Angles(math.rad(-33), math.rad(57), math.rad(-81)), Time = 0.12},
        {CFrame = CFrame.new(0.74, -0.92, 0.88) * CFrame.Angles(math.rad(147), math.rad(71), math.rad(53)), Time = 0.12}
    },
    Latest = {
        {CFrame = CFrame.new(0.69, -0.7, 0.1) * CFrame.Angles(math.rad(-65), math.rad(55), math.rad(-51)), Time = 0.1},
        {CFrame = CFrame.new(0.16, -1.16, 0.5) * CFrame.Angles(math.rad(-179), math.rad(54), math.rad(33)), Time = 0.1}
    },
    ["Vertical Spin"] = {
        {CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), math.rad(8), math.rad(5)), Time = 0.1},
        {CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(180), math.rad(3), math.rad(13)), Time = 0.1},
        {CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), math.rad(-5), math.rad(8)), Time = 0.1},
        {CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(-0), math.rad(-0)), Time = 0.1}
    },
    Exhibition = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
    },
    ["Exhibition Old"] = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
        {CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
    }
}

local weaplist = {
    {"rageblade", 100}, {"emerald_sword", 99}, {"deathbloom", 99},
    {"glitch_void_sword", 98}, {"sky_scythe", 98}, {"diamond_sword", 97},
    {"iron_sword", 96}, {"stone_sword", 95}, {"wood_sword", 94},
    {"emerald_dao", 93}, {"diamond_dao", 99}, {"diamond_dagger", 99},
    {"diamond_great_hammer", 99}, {"diamond_scythe", 99}, {"iron_dao", 97},
    {"iron_scythe", 97}, {"iron_dagger", 97}, {"iron_great_hammer", 97},
    {"stone_dao", 96}, {"stone_dagger", 96}, {"stone_great_hammer", 96},
    {"stone_scythe", 96}, {"wood_dao", 95}, {"wood_scythe", 95},
    {"wood_great_hammer", 95}, {"wood_dagger", 95}, {"frosty_hammer", 1}
}

local function getweapon()
    local bestrank = 0
    local inv = workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value
    local bestweap
    
    for _, weap in ipairs(weaplist) do
        if weap[2] > bestrank and inv:FindFirstChild(weap[1]) then
            bestweap = weap[1]
            bestrank = weap[2]
        end
    end
    return inv:FindFirstChild(bestweap)
end

local function gettargets(range, maxTargets, angleLimit)
    local targets = {}
    local playerPos = game.Players.LocalPlayer.Character.PrimaryPart.Position
    local playerLook = game.Players.LocalPlayer.Character.PrimaryPart.CFrame.LookVector * Vector3.new(1, 0, 1)
    
    for _, plr in pairs(game.Players:GetPlayers()) do
        pcall(function()
            if plr == game.Players.LocalPlayer or plr.Team == game.Players.LocalPlayer.Team then return end
            if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then return end
            
            local dist = (plr.Character.PrimaryPart.Position - playerPos).Magnitude
            
            if plr.Character.Humanoid.Health > 0 and dist <= range then
                if angleLimit then
                    local delta = (plr.Character.PrimaryPart.Position - playerPos)
                    local angle = math.acos(playerLook:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                    if angle > (math.rad(angleLimit) / 2) then return end
                end
                
                local targetData = {
                    Player = plr,
                    Character = plr.Character,
                    Health = plr.Character.Humanoid.Health,
                    MaxHealth = plr.Character.Humanoid.MaxHealth
                }
                
                table.insert(targets, targetData)
                targetinfo.Targets[targetData] = tick() + 1
            end
        end)
    end
    
    table.sort(targets, function(a, b)
        local distA = (a.Character.PrimaryPart.Position - playerPos).Magnitude
        local distB = (b.Character.PrimaryPart.Position - playerPos).Magnitude
        return distA < distB
    end)
    
    if maxTargets and #targets > maxTargets then
        for i = maxTargets + 1, #targets do
            targets[i] = nil
        end
    end
    
    return targets
end

run(function()
    local animating
    local Killaura = {Enabled = false}
    local baseweld = workspace.Camera.Viewmodel.RightHand.RightWrist.C0
    local viewmdl = workspace.Camera.Viewmodel.RightHand.RightWrist
    local AnimDelay = tick()
    local AnimTween
    local armC0
    local Attacking = false
    local Boxes = {}
    local Particles = {}
    
    Killaura = vape.Categories.Blatant:CreateModule({
        Name = "Killaura",
        Function = function(callback)
            if callback then 
                if Killaura.Animation then
                    armC0 = workspace.Camera.Viewmodel.RightHand.RightWrist.C0
                    
                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                local first = not started
                                started = true
                                
                                if Killaura.AnimationMode == "Random" then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end
                                
                                for _, v in anims[Killaura.AnimationMode or "Normal"] do
                                    local tweenTime = first and (Killaura.NoTween and 0.001 or 0.1) or v.Time / (Killaura.AnimationSpeed or 1)
                                    AnimTween = game:GetService("TweenService"):Create(viewmdl, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if not (Killaura.Enabled and Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = game:GetService("TweenService"):Create(viewmdl, TweenInfo.new(Killaura.NoTween and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end
                            
                            if not started then
                                task.wait(1 / (Killaura.UpdateRate or 60))
                            end
                        until not (Killaura.Enabled and Killaura.Animation)
                    end)
                end
                
                auraconn = game:GetService("RunService").Heartbeat:Connect(function()
                    local targets = gettargets(Killaura.range or 18, Killaura.MaxTargets or 5, Killaura.AngleLimit or 360)
                    if #targets == 0 then 
                        Attacking = false
                        return 
                    end
                    local weap = getweapon()
                    if Killaura.weaponcheck then
                        if not game.Players.LocalPlayer.Character:FindFirstChild(weap.Name) then
                            return
                        end
                    else
                        if workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:FindFirstChild(weap.Name) then
                            bedwars.Client:Get(bedwars.EquipItemRemote):InvokeServer({
                                ["hand"] = workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:WaitForChild(weap.Name)
                            })
                        end
                    end
                    Attacking = true
                    for i, v in pairs(Boxes) do
                        v.Adornee = targets[i] and targets[i].Character.PrimaryPart or nil
                        if v.Adornee then
                            v.Color3 = Color3.fromHSV(Killaura.BoxColor.Hue, Killaura.BoxColor.Sat, Killaura.BoxColor.Value)
                            v.Transparency = 1 - Killaura.BoxColor.Opacity
                        end
                    end
                    for i, v in pairs(Particles) do
                        v.Position = targets[i] and targets[i].Character.PrimaryPart.Position or Vector3.new(9e9, 9e9, 9e9)
                        v.Parent = targets[i] and workspace.CurrentCamera or nil
                    end
                    if Killaura.Face and targets[1] then
                        local vec = targets[1].Character.PrimaryPart.Position * Vector3.new(1, 0, 1)
                        game.Players.LocalPlayer.Character.PrimaryPart.CFrame = CFrame.lookAt(
                            game.Players.LocalPlayer.Character.PrimaryPart.Position,
                            Vector3.new(vec.X, game.Players.LocalPlayer.Character.PrimaryPart.Position.Y, vec.Z)
                        )
                    end
                    
                    for _, targ in ipairs(targets) do
                        task.spawn(function()
                            bedwars.Client:Get(bedwars.AttackRemote):FireServer({
                                chargedAttack = {chargeRatio = 0},
                                entityInstance = targ.Character,
                                validate = {
                                    raycast = {
                                        cameraPosition = workspace.CurrentCamera.CFrame.Position,
                                        cursorDirection = (targ.Character.PrimaryPart.Position - workspace.CurrentCamera.CFrame.Position).Unit
                                    },
                                    targetPosition = {value = targ.Character.PrimaryPart.Position},
                                    selfPosition = {value = game.Players.LocalPlayer.Character.PrimaryPart.Position}
                                },
                                weapon = weap
                            })
                        end)
                    end
                end)
            else
                Attacking = false
                if auraconn then
                    auraconn:Disconnect()
                end
                if viewmdl then
                    game:GetService("TweenService"):Create(viewmdl, TweenInfo.new(0.1), {C0 = baseweld}):Play()
                end
                for _, v in pairs(Boxes) do
                    v.Adornee = nil
                end
                for _, v in pairs(Particles) do
                    v.Parent = nil
                end
                
                table.clear(targetinfo.Targets)
            end
        end
    })

    Killaura:CreateToggle({
        Name = "Weapon Check",
        Function = function(callback)
            Killaura.weaponcheck = callback
        end
    })

    Killaura:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 22,
        Default = 18,
        Function = function(val)
            Killaura.range = val
        end
    })

	Killaura:CreateSlider({
        Name = "Max Targets",
        Min = 1,
        Max = 10,
        Default = 5,
        Function = function(val)
            Killaura.MaxTargets = val
        end
    })
    
    Killaura:CreateSlider({
        Name = "Angle Limit",
        Min = 1,
        Max = 360,
        Default = 360,
        Function = function(val)
            Killaura.AngleLimit = val
        end
    })

	Killaura:CreateToggle({
        Name = "Animation",
        Function = function(callback)
            Killaura.Animation = callback
        end
    })
	Killaura:CreateToggle({
        Name = "Face Target",
        Function = function(callback)
            Killaura.Face = callback
        end
    })
	Killaura:CreateToggle({
        Name = "No Animation Tween",
        Function = function(callback)
            Killaura.NoTween = callback
        end
    })
	Killaura:CreateDropdown({
        Name = "Animation Mode",
        List = {"Normal", "Slow", "New", "Latest", "Vertical Spin", "Exhibition", "Exhibition Old", "Random"},
        Function = function(val)
            Killaura.AnimationMode = val
        end
    })
	
    Killaura:CreateSlider({
        Name = "Animation Speed",
        Min = 0.5,
        Max = 2,
        Default = 1,
        Increment = 0.1,
        Function = function(val)
            Killaura.AnimationSpeed = val
        end
    })

    Killaura:CreateSlider({
        Name = "Update Rate",
        Min = 1,
        Max = 120,
        Default = 60,
        Function = function(val)
            Killaura.UpdateRate = val
        end
    })
	Killaura:CreateColorSlider({
        Name = "Box Color",
        Function = function(h, s, v, o)
            Killaura.BoxColor = {
                Hue = h,
                Sat = s,
                Value = v,
                Opacity = o
            }
        end
    })
end)
bedwars.FishermanController = {}
bedwars.FishermanController.startMinigame = function() end
run(function()
	local AutoKit = {Enabled = false, Connections = {}}
	local AutoKitTrinity = {Value = "Void"}
	local oldfish
	local function GetTeammateThatNeedsMost()
		local plrs = GetAllNearestHumanoidToPosition(true, 30, 1000, true)
		local lowest, lowestplayer = 10000, nil
		for i,v in pairs(plrs) do
			if not v.Targetable then
				if v.Character:GetAttribute("Health") <= lowest and v.Character:GetAttribute("Health") < v.Character:GetAttribute("MaxHealth") then
					lowest = v.Character:GetAttribute("Health")
					lowestplayer = v
				end
			end
		end
		return lowestplayer
	end

	local AutoKit_Functions = {
		["star_collector"] = function()
			local function fetchItem(obj)
				local args = {
					[1] = {
						["id"] = obj:GetAttribute("Id"),
						["collectableName"] = obj.Name
					}
				}
				local res = bedwars.Client:Get("CollectCollectableEntity"):FireServer(unpack(args))
			end
			local allowedNames = {"CritStar", "VitalityStar"}
			task.spawn(function()
				repeat
					task.wait()
					if entitylib.isAlive then 
						local maxDistance = 30
						for i,v in pairs(game.Workspace:GetChildren()) do
							if v.Parent and v.ClassName == "Model" and table.find(allowedNames, v.Name) and game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
								local pos1 = game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position
								local pos2 = v.PrimaryPart.Position
								if (pos1 - pos2).Magnitude <= maxDistance then
									fetchItem(v)
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["spirit_assassin"] = function()
			repeat
				task.wait()
				bedwars.SpiritAssassinController:Invoke()
			until (not AutoKit.Enabled)
		end,
		["alchemist"] = function()
			AutoKit:Clean(game:GetService("Players").LocalPlayer.Chatted:Connect(function(msg)
				if AutoKit.Enabled then
					local parts = string.split(msg, " ")
					if parts[1] and (parts[1] == "/recipes" or parts[1] == "/potions") then
						local potions = bedwars.ItemTable["brewing_cauldron"].crafting.recipes
						local function resolvePotionsData(data)
							local finalData = {}
							for i,v in pairs(data) do
								local result = v.result
								local brewingTime = v.timeToCraft
								local recipe = ""
								for i2, v2 in pairs(v.ingredients) do
									recipe = recipe ~= "" and recipe.." + "..tostring(v2) or recipe == "" and recipe..tostring(v2)
								end
								table.insert(finalData, {
									Result = result, 
									BrewingTime = brewingTime,
									Recipe = recipe
								})
							end
							return finalData
						end
						for i,v in pairs(resolvePotionsData(potions)) do
							local text = v.Result..": "..v.Recipe.." ("..tostring(v.BrewingTime).."seconds)"
							game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
								Text = text,
								Color = Color3.new(255, 255, 255),
								Font = Enum.Font.SourceSans,
								FontSize = Enum.FontSize.Size36
							})
						end
					end
				end
			end))
			local function fetchItem(obj)
				local args = {
					[1] = {
						["id"] = obj:GetAttribute("Id"),
						["collectableName"] = obj.Name
					}
				}
				local res = bedwars.Client:Get("CollectCollectableEntity"):FireServer(unpack(args))
			end
			local allowedNames = {"Thorns", "Mushrooms", "Flower"}
			task.spawn(function()
				repeat
					task.wait()
					if entitylib.isAlive then 
						local maxDistance = 30
						for i,v in pairs(game.Workspace:GetChildren()) do
							if v.Parent and v.ClassName == "Model" and table.find(allowedNames, v.Name) and game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
								local pos1 = game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position
								local pos2 = v.PrimaryPart.Position
								if (pos1 - pos2).Magnitude <= maxDistance then
									fetchItem(v)
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["melody"] = function()
			task.spawn(function()
				repeat
					task.wait(0.1)
					if getItem("guitar") then
						local plr = GetTeammateThatNeedsMost()
						if plr and healtick <= tick() then
							bedwars.Client:Get(bedwars.GuitarHealRemote):FireServer({
								healTarget = plr.Character
							})
							healtick = tick() + 2
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["bigman"] = function()
			task.spawn(function()
				repeat
					task.wait()
					local itemdrops = collectionService:GetTagged("treeOrb")
					for i,v in pairs(itemdrops) do
						if entitylib.isAlive and v:FindFirstChild("Spirit") and (entitylib.character.HumanoidRootPart.Position - v.Spirit.Position).magnitude <= 20 then
							if bedwars.Client:Get(bedwars.TreeRemote):InvokeServer({
								treeOrbSecret = v:GetAttribute("TreeOrbSecret")
							}) then
								v:Destroy()
								collectionService:RemoveTag(v, "treeOrb")
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["metal_detector"] = function()
			task.spawn(function()
				repeat
					task.wait()
					local itemdrops = collectionService:GetTagged("hidden-metal")
					for i,v in pairs(itemdrops) do
						if entitylib.isAlive and v.PrimaryPart and (entitylib.character.HumanoidRootPart.Position - v.PrimaryPart.Position).magnitude <= 20 then
							bedwars.Client:Get(bedwars.PickupMetalRemote):InvokeServer({
								id = v:GetAttribute("Id")
							})
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["grim_reaper"] = function()
			task.spawn(function()
				repeat
					task.wait()
					local itemdrops = bedwars.GrimReaperController:fetchSoulsByPosition()
					for i,v in pairs(itemdrops) do
						if entitylib.isAlive then
							local res = bedwars.Client:Get(bedwars.ConsumeSoulRemote):InvokeServer({
								secret = v:GetAttribute("GrimReaperSoulSecret")
							})
							v:Destroy()
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["farmer_cletus"] = function()
			task.spawn(function()
				repeat
					task.wait()
					local itemdrops = collectionService:GetTagged("HarvestableCrop")
					for i,v in pairs(itemdrops) do
						if entitylib.isAlive and (entitylib.character.HumanoidRootPart.Position - v.Position).magnitude <= 10 then
							bedwars.Client:Get("CropHarvest"):InvokeServer({
								position = bedwars.BlockController:getBlockPosition(v)
							})
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["dragon_slayer"] = function()
			local lastFired
			task.spawn(function()
				repeat
					task.wait(0.5)
					if entitylib.isAlive then
						for i,v in pairs(bedwars.DragonSlayerController:fetchDragonEmblems()) do
							local data = bedwars.DragonSlayerController:fetchDragonEmblemData(v)
							if data.stackCount >= 3 then
								local ctarget = bedwars.DragonSlayerController:resolveTarget(v:GetPrimaryPartCFrame())
								bedwars.DragonSlayerController:deleteEmblem(v)
								if ctarget then 
									task.spawn(function()
										bedwars.Client:Get(bedwars.DragonRemote):FireServer({
											target = ctarget
										})
									end)
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["mage"] = function()
			task.spawn(function()
				repeat
					task.wait(0.1)
					if entitylib.isAlive then
						for i, v in pairs(collectionService:GetTagged("TomeGuidingBeam")) do
							local obj = v.Parent and v.Parent.Parent and v.Parent.Parent.Parent
							if obj and (entitylib.character.HumanoidRootPart.Position - obj.PrimaryPart.Position).Magnitude < 5 and obj:GetAttribute("TomeSecret") then
								local res = bedwars.Client:Get(bedwars.MageRemote):InvokeServer({
									secret = obj:GetAttribute("TomeSecret")
								})
								if res.success and res.element then
									bedwars.GameAnimationUtil.playAnimation(lplr, bedwars.AnimationType.PUNCH)
									bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									local sound = bedwars.MageKitUtil.MageElementVisualizations[res.element].learnSound
									if sound and sound ~= "" then
										local activeSound = bedwars.SoundManager:playSound(sound)
										if activeSound then task.wait(0.3) pcall(function() activeSound:Stop(); activeSound:Destroy() end) end
									end
									pcall(function() obj:Destroy() end)
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["miner"] = function()
			task.spawn(function()
				repeat 
					task.wait(0.1)
					if entitylib.isAlive then
						for i,v in pairs(game.Workspace:GetChildren()) do
							local a = game.Workspace:GetChildren()[i]
							if a.ClassName == "Model" and #a:GetChildren() > 1 then
								if a:GetAttribute("PetrifyId") then
									bedwars.Client:Get("DestroyPetrifiedPlayer"):FireServer({
										["petrifyId"] = a:GetAttribute("PetrifyId")
									})
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["sorcerer"] = function()
			task.spawn(function()
				repeat 
					task.wait(0.1)
					if entitylib.isAlive then
						local player = game.Players.LocalPlayer
						local character = player.Character or player.CharacterAdded:Wait()
						local thresholdDistance = 10
						for i, v in pairs(game.Workspace:GetChildren()) do
							local a = v
							pcall(function()
								if a.ClassName == "Model" and #a:GetChildren() > 1 then
									if a:GetAttribute("Id") then
										local c = (a:FindFirstChild(a.Name:lower().."_PESP") or Instance.new("BoxHandleAdornment"))
										c.Name = a.Name:lower().."_PESP"
										c.Parent = a
										c.Adornee = a
										c.AlwaysOnTop = true
										c.ZIndex = 0
										task.spawn(function()
											local d = a:WaitForChild("2")
											c.Size = d.Size
										end)
										c.Transparency = 0.3
										c.Color = BrickColor.new("Magenta")
										local playerPosition = character.HumanoidRootPart.Position
										local partPosition = a.PrimaryPart.Position
										local distance = (playerPosition - partPosition).Magnitude
										if distance <= thresholdDistance then
											bedwars.Client:Get("CollectCollectableEntity"):FireServer({
												["id"] = a:GetAttribute("Id"),
												["collectableName"] = "AlchemyCrystal"
											})
										end
									end
								end
							end)
						end										
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["nazar"] = function()
			task.spawn(function()
				repeat 
					task.wait(0.5)
					if entitylib.isAlive then
						bedwars.AbilityController:useAbility("enable_life_force_attack")
						local function shouldUse()
							local lplr = game:GetService("Players").LocalPlayer
							if not (lplr.Character:FindFirstChild("Humanoid")) then
								local healthbar = pcall(function() return lplr.PlayerGui.hotbar['1'].HotbarHealthbarContainer["1"] end)
								local classname = pcall(function() return healthbar.ClassName end)
								if healthbar and classname == "TextLabel" then 
									local health = tonumber(healthbar.Text)
									if health < 100 then return true, "SucBackup" else return false, "SucBackup" end
								else
									return true, "Backup"
								end
							else
								if lplr.Character.Humanoid.Health < lplr.Character.Humanoid.MaxHealth then return true else return false end
							end
						end
						local val, extra = shouldUse()
						if extra then if shared.VoidDev then print("Using backup method: "..tostring(extra)) end end
						if val then
							bedwars.AbilityController:useAbility("consume_life_foce")
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["necromancer"] = function()
			local function activateGrave(obj)
				if (not obj) then return warn("[AutoKit - necromancer.activateGrave]: No object specified!") end
				local required_args = {
					armorType = obj:GetAttribute("ArmorType"),
					weaponType = obj:GetAttribute("SwordType"),
					associatedPlayerUserId = obj:GetAttribute("GravestonePlayerUserId"),
					secret = obj:GetAttribute("GravestoneSecret"),
					position = obj:GetAttribute("GravestonePosition")
				}
				for i,v in pairs(required_args) do
					if (not v) then return warn("[AutoKit - necromancer.activateGrave]: A required arg is missing! ArgName: "..tostring(i).." ObjectName: "..tostring(obj.Name)) end
				end
				bedwars.Client:Get("ActivateGravestone"):InvokeServer({
					["skeletonData"] = {
						["armorType"] = armorType,
						["weaponType"] = weaponType,
						["associatedPlayerUserId"] = associatedPlayerUserId
					},
					["secret"] = secret,
					["position"] = position
				})
			end
			local function verifyAttributes(obj)
				if (not obj) then return warn("[AutoKit - necromancer.verifyAttributes]: No object specified!") end
				local required_attributes = {"ArmorType", "GravestonePlayerUserId", "GravestonePosition", "GravestoneSecret", "SwordType"}
				for i,v in pairs(required_attributes) do
					if (not obj:GetAttribute(v)) then print(v.." not found in "..obj.Name); return false end
				end
				return true
			end
			task.spawn(function()
				repeat
					task.wait(0.1)
					if entitylib.isAlive then
						for i,v in pairs(game.Workspace:GetChildren()) do
							local a = game.Workspace:GetChildren()[i]
							if (not a) then return warn("[AutoKit - Core]: The object went missing before it could get used!") end
							if a.ClassName == "Model" and a:FindFirstChild("Root") and a.Name == "Gravestone" then
								if verifyAttributes(a) then
									local res = activateGrave(a)
									warn("[AutoKit - necromancer.activateGrave - RESULT]: "..tostring(res))
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end,
		["jailor"] = function()
			local function activateSoul(obj)
				bedwars.Client:Get("CollectCollectableEntity"):FireServer({
					["id"] = obj:GetAttribute("Id"),
					["collectableName"] = "JailorSoul"
				})
			end
			local function verifyAttributes(obj)
				if obj:GetAttribute("Id") then return true else return false end
			end
			task.spawn(function()
				repeat
					task.wait(0.1)
					if entitylib.isAlive then
						for i,v in pairs(game.Workspace:GetChildren()) do
							local a = game.Workspace:GetChildren()[i]
							if (not a) then return end
							if a.ClassName == "Model" and a.Name == "JailorSoul" then
								if verifyAttributes(a) then
									local res = activateSoul(a)
								end
							end
						end
					end
				until (not AutoKit.Enabled)
			end)
		end
	}

	AutoKit = vape.Categories.Utility:CreateModule({
		Name = "AutoKit",
		Function = function(callback)
			if callback then
				oldfish = bedwars.FishermanController.startMinigame
				bedwars.FishermanController.startMinigame = function(Self, dropdata, func) func({win = true}) end
				task.spawn(function()
					repeat task.wait() until store.equippedKit ~= ""
					if AutoKit.Enabled then
						if AutoKit_Functions[store.equippedKit] then task.spawn(AutoKit_Functions[store.equippedKit]) end
					end
				end)
			else
				bedwars.FishermanController.startMinigame = oldfish
				oldfish = nil
			end
		end,
		HoverText = "Automatically uses a kits ability"
	})
	local function resolveKitName(kitName)
		local repstorage = game:GetService("ReplicatedStorage")
		local KitMeta = bedwars.KitMeta
		if KitMeta[kitName] then return (KitMeta[kitName].name or kitName) else return kitName end
	end
	local function isSupportedKit(kit) if AutoKit_Functions[kit] then return "Supported" else return "Not Supported" end end
	AutoKitTrinity = AutoKit:CreateDropdown({
		Name = "Angel",
		List = {"Void", "Light"},
		Function = function() end
	})
	AutoKitTrinity.Object.Visible = (store.equippedKit == "angel")
end)

run(function()
    function nearestplrs(range)
        local nearest
        local nearestd = math.huge
        for i,v in pairs(game.Players:GetPlayers()) do
            pcall(function()
                if v == game.Players.LocalPlayer or v.Team == game.Players.LocalPlayer.Team then return end
                if v.Character.Humanoid.health > 0 and (v.Character.PrimaryPart.Position - game.Players.LocalPlayer.Character.PrimaryPart.Position).Magnitude < nearestd and (v.Character.PrimaryPart.Position - game.Players.LocalPlayer.Character.PrimaryPart.Position).Magnitude <= range then
                    nearest = v
                    nearestd = (v.Character.PrimaryPart.Position - game.Players.LocalPlayer.Character.PrimaryPart.Position).Magnitude
                end
            end)
        end
        return nearest
    end
    local AimAssist = {Enabled = false}
    local smoothness = 0.5 
    local function lerp(a, b, t)
        return a + (b - a) * t
    end
    local function angle(current, target)
        local diff = target - current
        return math.atan2(math.sin(diff), math.cos(diff))
    end
    AimAssist = vape.Categories.Combat:CreateModule({
        Name = "AimAssist",
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat task.wait(0)
                        local target = nearestplrs(20)
                        if target then
                            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                local currentCF = game.Workspace.CurrentCamera.CFrame
                                local targetCF = CFrame.new(currentCF.Position, target.Character.HumanoidRootPart.Position)
                                local currentX, currentY, currentZ = currentCF:ToOrientation()
                                local targetX, targetY, targetZ = targetCF:ToOrientation()
                                local newY = currentY + angle(currentY, targetY) * smoothness
                                local newX = lerp(currentX, targetX, smoothness)
                                game.Workspace.CurrentCamera.CFrame = CFrame.new(currentCF.Position) * CFrame.fromOrientation(newX, newY, currentZ)
                            end
                        end
                    until (not AimAssist.Enabled)
                end)
            end
        end,
    })
    AimAssist:CreateSlider({
        Name = "Smoothness",
        Min = 0,
        Max = 1,
        Default = 0.5,
		Decimal = 10,
        Function = function(val)
            smoothness = val
        end
    })
end)

function place(pos,block)
	local args = { 
		[1] = { 
			['blockType'] = block,
		    ['position'] = Vector3.new(pos.X / 3,pos.Y / 3,pos.Z / 3),
			['blockData'] = 0
	    } 
	}
	game.ReplicatedStorage.rbxts_include.node_modules:WaitForChild("@easy-games"):WaitForChild("block-engine").node_modules:WaitForChild("@rbxts").net.out:WaitForChild("_NetManaged").PlaceBlock:InvokeServer(unpack(args))
end
run(function()
	local Scaffold = {Enabled = false}
	Scaffold = vape.Categories.Blatant:CreateModule({
		Name = "Scaffold",
		Function = function(callback)
			if callback then
				task.spawn(function()
					scaffoldRun = game:GetService("RunService").RenderStepped:Connect(function()
						if game.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
							local velo = lplr.Character.PrimaryPart.Velocity
							lplr.Character.PrimaryPart.Velocity = Vector3.new(velo.X,10,velo.Z)
						end
						local block 
						for i,v in pairs(workspace[game.Players.LocalPlayer.Name].InventoryFolder.Value:GetChildren()) do
							if v.Name:lower():find("wool") then
								block = v.Name
							end
						end
						place((lplr.Character.PrimaryPart.CFrame + lplr.Character.PrimaryPart.CFrame.LookVector * 1) - Vector3.new(0,4.5,0),block)
						if not Scaffold.Enabled then return end
						place((lplr.Character.PrimaryPart.CFrame + lplr.Character.PrimaryPart.CFrame.LookVector * 2) - Vector3.new(0,4.5,0),block)
						if not Scaffold.Enabled then return end
						place((lplr.Character.PrimaryPart.CFrame + lplr.Character.PrimaryPart.CFrame.LookVector * 3) - Vector3.new(0,4.5,0),block)
					end)
				end)
			else
				pcall(function()
					scaffoldRun:Disconnect()
				end)
			end 
		end
	})
end)

run(function()
    local NetManaged = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
    local function PurchaseItem(cfg)
        local args = {
            [1] = {
                ["shopItem"] = cfg,
                ["shopId"] = "1_item_shop"
            }
        }
        NetManaged:WaitForChild("BedwarsPurchaseItem"):InvokeServer(unpack(args))
    end
    
    local AutoBuy = {
        Enabled = false,
        buyswords = true,
        buyarmor = true,
		buypickaxes = false, 
		buyaxes = false
    }

    local configs = {
        stone_sword = {
            itemType = "stone_sword",
            price = 70,
            currency = "iron",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"barbarian", "dasher", "frost_hammer_kit", "tinker"},
            superiorItems = {"iron_sword"},
            disabledInQueue = {"tnt_wars"}
        },
        iron_sword = {
            itemType = "iron_sword",
            price = 70,
            currency = "iron",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"barbarian", "dasher", "frost_hammer_kit", "tinker"},
            superiorItems = {"diamond_sword"},
            disabledInQueue = {"tnt_wars"}
        },
        diamond_sword = {
            itemType = "diamond_sword",
            price = 70,
            currency = "emerald",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"barbarian", "dasher", "frost_hammer_kit", "tinker"},
            superiorItems = {"emerald_sword"},
            disabledInQueue = {"tnt_wars"}
        },
        leather_armor = {
            itemType = "leather_chestplate",
            price = 50,
            currency = "iron",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"bigman", "tinker"},
            customDisplayName = "Leather Armor",
            spawnWithItems = {"leather_helmet", "leather_chestplate", "leather_boots"},
            nextTier = "iron_chestplate"
        },
        iron_armor = {
            itemType = "iron_chestplate",
            price = 120,
            currency = "iron",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"bigman", "tinker"},
            customDisplayName = "Iron Armor",
            spawnWithItems = {"iron_helmet", "iron_chestplate", "iron_boots"},
            nextTier = "diamond_chestplate",
            tiered = true
        },
        diamond_armor = {
            itemType = "diamond_chestplate",
            price = 8,
            currency = "diamond",
            category = "Combat",
            lockAfterPurchase = true,
            ignoredByKit = {"bigman", "tinker"},
            customDisplayName = "Diamond Armor",
            spawnWithItems = {"diamond_helmet", "diamond_chestplate", "diamond_boots"}
        },
		stone_pickaxe = {
            itemType = "stone_pickaxe",
            price = 20,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            superiorItems = {"iron_pickaxe"},
            disabledInQueue = {"tnt_wars"}
        },
		iron_pickaxe = {
            itemType = "iron_pickaxe",
            price = 20,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            superiorItems = {"diamond_pickaxe"},
            disabledInQueue = {"tnt_wars"}
        },
		diamond_pickaxe = {
            itemType = "diamond_pickaxe",
            price = 60,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            disabledInQueue = {"tnt_wars"}
        },
		wood_axe = {
            itemType = "wood_axe",
            price = 20,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            superiorItems = {"stone_axe"},
            disabledInQueue = {"tnt_wars"}
        },
		stone_axe = {
            itemType = "stone_axe",
            price = 20,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            superiorItems = {"iron_axe"},
            disabledInQueue = {"tnt_wars"}
        },
		iron_axe = {
            itemType = "iron_axe",
            price = 20,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            superiorItems = {"diamond_axe"},
            disabledInQueue = {"tnt_wars"}
        },
		diamond_axe = {
            itemType = "diamond_axe",
            price = 60,
            currency = "iron",
            category = "Tools",
            lockAfterPurchase = true,
            ignoredByKit = {},
            disabledInQueue = {"tnt_wars"}
        },
    }
    
    AutoBuy = vape.Categories.Inventory:CreateModule({
        Name = "AutoBuy",
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat task.wait()
                        local inventory = workspace[game:GetService("Players").LocalPlayer.Name].InventoryFolder.Value
                        if AutoBuy.buyswords then
                            if inventory:FindFirstChild("wood_sword") then
                                PurchaseItem(configs.stone_sword)
							elseif inventory:FindFirstChild("stone_sword") then
                                PurchaseItem(configs.iron_sword)
                            elseif inventory:FindFirstChild("iron_sword") then
                                PurchaseItem(configs.diamond_sword)
                            end
                        end
						if AutoBuy.buyarmor then
                            if not inventory:FindFirstChild("leather_chestplate") and not inventory:FindFirstChild("iron_chestplate") and not inventory:FindFirstChild("diamond_chestplate") then
                                PurchaseItem(configs.leather_armor)
							elseif inventory:FindFirstChild("leather_chestplate") then
                                PurchaseItem(configs.iron_armor)
                            elseif inventory:FindFirstChild("iron_chestplate") then
                                PurchaseItem(configs.diamond_armor)
                            end
                        end
						if AutoBuy.buypickaxes then
                            if inventory:FindFirstChild("wood_pickaxe") then
                                PurchaseItem(configs.stone_pickaxe)
							elseif inventory:FindFirstChild("stone_pickaxe") then
                                PurchaseItem(configs.iron_pickaxe)
                            elseif inventory:FindFirstChild("iron_pickaxe") then
                                PurchaseItem(configs.diamond_pickaxe)
                            end
                        end
						if AutoBuy.buyaxes then
							if not inventory:FindFirstChild("wood_axe") and not inventory:FindFirstChild("stone_axe") and not inventory:FindFirstChild("iron_axe") and not inventory:FindFirstChild("diamond_axe") then
                                PurchaseItem(configs.wood_axe) 
                            elseif inventory:FindFirstChild("wood_axe") then
                                PurchaseItem(configs.stone_axe)
							elseif inventory:FindFirstChild("stone_axe") then
                                PurchaseItem(configs.iron_axe)
                            elseif inventory:FindFirstChild("iron_axe") then
                                PurchaseItem(configs.diamond_axe)
                            end
                        end
                    until (not AutoBuy.Enabled)
                end)
            end
        end
    })
    
    AutoBuy:CreateToggle({
        Name = "Buy Swords",
        Function = function(callback)
            AutoBuy.buyswords = callback
        end
    })
    AutoBuy:CreateToggle({
        Name = "Buy Armor",
        Function = function(callback)
            AutoBuy.buyarmor = callback
        end
    })
	AutoBuy:CreateToggle({
        Name = "Buy Pickaxes",
        Function = function(callback)
            AutoBuy.buypickaxes = callback
        end
    })
	AutoBuy:CreateToggle({
        Name = "Buy Axes",
        Function = function(callback)
            AutoBuy.buyaxes = callback
        end
    })
end)

run(function()
	game.Players.LocalPlayer.CharacterAdded:Connect(function(newchar)
		game.Players.LocalPlayer.Character = newchar
	end)
	game.Players.LocalPlayer.CharacterRemoving:Connect(function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if inffly then
			inffly:Destroy()
			inffly = nil 
		end
		workspace.CurrentCamera.CameraSubject = game.Players.LocalPlayer.Character
	end)
	local InfiniteFly = {Enabled = false}
	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = "InfiniteFly",
		Function = function(callback)
			if callback then
				inffly = Instance.new("Part", workspace) 
				inffly.Anchored = true
				inffly.CanCollide = true
				inffly.CFrame = game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").CFrame
				inffly.Transparency = 1
				inffly.Size = Vector3.new(0.5, 0.5, 0.5)
				game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").CFrame += Vector3.new(0, 1000000, 0)
				workspace.CurrentCamera.CameraSubject = inffly
				conn = game:GetService("RunService").Heartbeat:Connect(function()
					if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
						local humanoidRootPart = game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
						if humanoidRootPart.Position.Y < inffly.Position.Y then
							humanoidRootPart.CFrame += Vector3.new(0, 1000000, 0)
						end

						if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
							inffly.CFrame += Vector3.new(0, 0.45, 0)
						end
						if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
							inffly.CFrame += Vector3.new(0, -0.45, 0)
						end

						inffly.CFrame = CFrame.new(humanoidRootPart.CFrame.X, inffly.CFrame.Y, humanoidRootPart.CFrame.Z)
					end
				end)
			else
				pcall(function()
					if conn then
						conn:Disconnect()
						conn = nil 
					end
					if inffly then
						for i = 1, 15 do
							task.wait(0.01)
							game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").Velocity = Vector3.new(0, 0, 0)
							game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").CFrame = inffly.CFrame
						end
						inffly:Destroy()
						inffly = nil 
					end
				end)
				workspace.CurrentCamera.CameraSubject = game.Players.LocalPlayer.Character
			end
		end
	})
end)
	
run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Legit:CreateModule({
		Name = 'Reach Display',
		Function = function(callback)
			if callback then
				repeat
					label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
					task.wait(0.4)
				until not ReachDisplay.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41)
	})
	ReachDisplay:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	ReachDisplay:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0.00 studs'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = ReachDisplay.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
