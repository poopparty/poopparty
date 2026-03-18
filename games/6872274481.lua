--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local run = function(func)
    local ok, err = pcall(func)
    if not ok then
        warn('[AEROV4] module failed to load: ' .. tostring(err))
    end
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local cloneref = cloneref or function(obj)
	return obj
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getconstant, func, index)
    if success then
        return proto
    end
end

local inventoryDebounce = false
local function fireInventoryChanged()
    if inventoryDebounce then return end
    inventoryDebounce = true
    task.spawn(function()
        task.wait() 
        vapeEvents.InventoryChanged:Fire()
        inventoryDebounce = false
    end)
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
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
    attackReach = 0,
    attackReachUpdate = tick(),
    damageBlockFail = tick(),
    hand = {},
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    inventories = setmetatable({}, { __mode = "k" }), 
    matchState = 0,
    queueType = 'bedwars_test',
    tools = {},
    lastToolUpdate = 0,  
}
local Reach = {}
local HitBoxes = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

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

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function GetItems(item: string): table
	local Items: table = {};
	for _, v in next, Enum[item]:GetEnumItems() do 
		table.insert(Items, v["Name"]) ;
	end;
	return Items;
end;

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in store.inventory.inventory.items do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
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

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
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
    return Vector3.new(
        math.round(vec.X / 3) * 3,
        math.round(vec.Y / 3) * 3,
        math.round(vec.Z / 3) * 3
    )
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
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

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end
	
local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
	game.ReplicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.TeleportToLobby:FireServer()
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local function HasSeed(character)
    if not character then return false end
    return character:FindFirstChild("Seed", true) ~= nil
end

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
	end,
	Distance = function(a, b)
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end,
	Forest = function(a, b)
		local aHasSeed = HasSeed(a.Entity.Character)
		local bHasSeed = HasSeed(b.Entity.Character)
		if aHasSeed and not bHasSeed then return true end
		if not aHasSeed and bHasSeed then return false end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
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
		if entitylib.Running then entitylib.stop() end
		oldstart()

		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))

		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end

		local function customEntity(ent)
			if playersService:GetPlayerFromCharacter(ent) then return end
			local teamFunc = function(self)
				local npcTeam = self.Character:GetAttribute('Team')
				return lplr:GetAttribute('Team') ~= npcTeam
			end
			entitylib.addEntity(ent, nil, teamFunc)
		end

		for _, ent in collectionService:GetTagged('entity') do
			customEntity(ent)
		end

		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
			entitylib.removeEntity(ent)
		end))

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
		end))

		entitylib.Running = true
	end

	entitylib.addPlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, conn in ipairs(entitylib.PlayerConnections[plr]) do
				if conn and typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		end

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
					Health = (function()
						local hp = char:GetAttribute('Health') or 100
						local shield = 0
						for k, v in pairs(char:GetAttributes()) do
							if type(k) == 'string' and k:sub(1, 7) == 'Shield_' and type(v) == 'number' and v > 0 then
								shield = shield + v
							end
						end
						return hp + shield
					end)(),
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

					if not plr then
						table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
							if attr == 'Team' then
								entity.Targetable = entitylib.targetCheck(entity)
								entitylib.Events.EntityUpdated:Fire(entity)
							end
						end))
					end

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							local hp = char:GetAttribute('Health') or 100
							local shield = 0
							for k, v in pairs(char:GetAttributes()) do
								if type(k) == 'string' and k:sub(1, 7) == 'Shield_' and type(v) == 'number' and v > 0 then
									shield = shield + v
								end
							end
							entity.Health = hp + shield
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					local invUpdatePending = {}

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							if invUpdatePending[entity] then return end
							invUpdatePending[entity] = true
							task.delay(0.1, function()
								invUpdatePending[entity] = nil
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
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
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
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

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

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
		if ent.NPC then
			local npcTeam = ent.Character and ent.Character:GetAttribute('Team')
			return lplr:GetAttribute('Team') ~= npcTeam
		end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
        BalanceFile = require(replicatedStorage.TS.balance["balance-file"]).BalanceFile,
        ClientSyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
        SyncEventPriority = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['sync-event'].out),
		AbilityId = require(replicatedStorage.TS.ability['ability-id']).AbilityId,
        IdUtil = require(replicatedStorage.TS.util['id-util']).IdUtil,
		BlockSelector = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector,
		KnockbackUtilInstance = replicatedStorage.TS.damage['knockback-util'],
		BedwarsKitSkin = require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).BedwarsKitSkinMeta,
		KitController = Knit.Controllers.KitController,
		FishermanUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fisherman-util']).FishermanUtil,
		FishMeta = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fish-meta']),
	 	MatchHistroyApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistroyController = Knit.Controllers.MatchHistoryController,
		BlockEngine = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine,
		BlockSelectorMode = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelectorMode,
		EntityUtil = require(game:GetService("ReplicatedStorage").TS.entity["entity-util"]).EntityUtil,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		OfflinePlayerUtil = require(replicatedStorage.TS.player['offline-player-util']),
		PlayerUtil = require(replicatedStorage.TS.player['player-util']),
		KKKnitController = require(lplr.PlayerScripts.TS.lib.knit['knit-controller']),
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		CooldownController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/cooldown/cooldown-controller@CooldownController"),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = (Knit.Controllers.ProjectileController and Knit.Controllers.ProjectileController.enableBeam) and debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8) or {},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		SharedConstants = require(replicatedStorage.TS['shared-constants']),
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency("@easy-games/lobby:client/controllers/party-controller@PartyController"),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.shared.sound['sound-manager']).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = safeGetProto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = safeGetProto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	local preDumped = {
		EquipItem = 'SetInvItem',
		ActivateGravestone = 'ActivateGravestone',
		CollectCollectableEntity = 'CollectCollectableEntity',
		DefenderRequestPlaceBlock = 'DefenderRequestPlaceBlock',
		RequestDragonPunch = 'RequestDragonPunch',
		Harvest = 'CropHarvest',
		DepositCoins = 'DepositCoins',
		BedwarsPurchaseItem = 'BedwarsPurchaseItem',
		BedBreakEffectTriggered = 'BedBreakEffectTriggered',
		BloodAssassinSelectContract = 'BloodAssassinSelectContract',
		MimicBlock = 'MimicBlock',
		TeleportToLobby = 'TeletoLobby',
		FishCaught = 'FishCaught',
		SpawnRaven = 'SpawnRaven',
		PaladinAbilityRequest = 'PaladinAbilityRequest',
		OwlActionAbilities = 'OwlActionAbilities',
		DrillAttack = 'DrillAttack',
		UpgradeFrostyHammer = 'UpgradeFrostyHammer',
		UpgradeFlamethrower = 'UpgradeFlamethrower',
		TryBlockKick = 'TryBlockKick',   
		Ranks = 'FetchRanks',
		ResearchEnchant = 'EnchantTableResearch',
		DropDroneItem = 'DropDroneItem',
    	AttemptFireOasisProjectiles = 'AttemptFireOasisProjectiles',
	    WinEffectTriggered = 'WinEffectTriggered',
		ExtractFromDrill = 'ExtractFromDrill',
		HannahPromptTrigger = 'HannahPromptTrigger',
		DragonFlap = 'DragonFlap',
		DragonBreath = 'DragonBreath',
		AttemptCardThrow = 'AttemptCardThrow',
		LearnElementTome = 'LearnElementTome',
	    RequestMoveSlime = 'RequestMoveSlime',
    	SummonOwl = 'SummonOwl',
    	RemoveOwl = 'RemoveOwl',
    	MimicBlockPickPocketPlayer = 'MimicBlockPickPocketPlayer',
		DestroyPetrifiedPlayer = 'DestroyPetrifiedPlayer',
		UseAbility = 'useAbility',
	}

	for k, v in pairs(preDumped) do
		if not remotes[k] then
			remotes[k] = v
		end
	end

	for i, v in remoteNames do
		local remote
		if type(v) == "string" then
			remote = v
		elseif type(v) == "function" then
			local consts = debug.getconstants(v)
			remote = dumpRemote(consts)
		else
			remote = ""
		end

		if remote == '' or remote == nil then
			if not preDumped[i] then
				notif('Vape', 'Failed to grab remote ('..tostring(i)..')', 10, 'alert')
			end
			remote = preDumped[i] or ''
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	
	task.spawn(function()
		while vape.Loaded do
			task.wait(60)
			table.clear(cache)
		end
	end)

	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

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
			local cacheEntry = {
				pos,
				cost,
				path,
				timestamp = tick()
			}
			cache[blockpos] = cacheEntry
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, autotool, wallcheck, nobreak)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge
		local mag = 9e9

		local positions = (handler and handler:getContainedPositions(block) or {block.Position / 3})

		for _, v in positions do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			local dmag = dpos and (entitylib.character.RootPart.Position - dpos).Magnitude
			if dpos and dcost < cost and dmag < mag then
				cost, pos, target, path, mag = dcost, dpos, v * 3, dpath, dmag
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if not nobreak and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.2 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if autotool then
						for i, v in store.inventory.hotbar do
							if v.item and v.item.itemType == tool.itemType and i ~= (store.inventory.hotbarSlot + 1) then 
								hotbarSwitch(i - 1)
								break
							end
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			if not nobreak then
				bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
					blockRef = {blockPosition = dpos},
					hitPosition = pos,
					hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
				}):andThen(function(result)
					if result then
						if result == 'cancelled' then
							store.damageBlockFail = os.clock() + 1
							table.clear(cache)
							return
						end

						if result == 'destroyed' then
							table.clear(cache)
						end

						if effects then
							local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
							customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
							customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
							blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

							pcall(function()
								if blockhealthbar.blockHealth <= 0 then
									bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
									bedwars.BlockBreaker.healthbarMaid:DoCleaning()
									blockhealthbar.breakingBlockPosition = Vector3.zero
								else
									bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
								end
							end)
						end

						if anim then
							local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
							bedwars.ViewmodelController:playAnimation(15)
							task.wait(0.3)
							animation:Stop()
							animation:Destroy()
						end
					end
				end)
			end

			return pos, path, target
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				fireInventoryChanged()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				local now = tick()
				if not store.lastToolUpdate or now - store.lastToolUpdate > 0.5 then
					store.lastToolUpdate = now
					store.tools.sword = getSword()
					for _, v in {'stone', 'wood', 'wool'} do
						store.tools[v] = getTool(v)
					end
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	vape:Clean(function() storeChanged:disconnect() end)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		store.inventories[plr] = nil
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
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

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	pcall(function()
		bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
		bedwars.ShopItems = bedwars.Shop.ShopItems
		bedwars.Shop.getShopItem('iron_sword', lplr)
		store.shopLoaded = true
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
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
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil

		if entitylib.Connections then
			for _, conn in ipairs(entitylib.Connections) do
				if conn and type(conn) == "userdata" and conn.Connected then
					conn:Disconnect()
				end
			end
			table.clear(entitylib.Connections)
		end

		if entitylib.EntityThreads then
			for char, thread in pairs(entitylib.EntityThreads) do
				if thread and task.cancel then
					task.cancel(thread)
				end
			end
			table.clear(entitylib.EntityThreads)
		end

		if entitylib.List then
			for _, ent in ipairs(entitylib.List) do
				if ent.Connections then
					for _, conn in ipairs(ent.Connections) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
					table.clear(ent.Connections)
				end
			end
			table.clear(entitylib.List)
		end
		if entitylib.stop then
			entitylib.stop()
		end
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags', 'Fly', 'GamingChair', 'Search', 'Waypoints', 'TargetStrafe', 'Xray', 'Tracers', 'Parkour', 'AntiFall'} do
	vape:Remove(v)
end

local lastFPCheck = 0
local cachedFPResult = false
local function isFirstPerson()
    local now = tick()
    if now - lastFPCheck < 0.1 then
        return cachedFPResult
    end
    lastFPCheck = now
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then
        cachedFPResult = false
        return false
    end
    cachedFPResult = (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
    return cachedFPResult
end

local function isFrozen(entity, threshold)
    threshold = threshold or 10
    local char
    if type(entity) == "table" and entity.Character then
        char = entity.Character
    elseif type(entity) == "Instance" and entity:IsA("Model") then
        char = entity
    elseif entity == nil then
        if not entitylib.isAlive then return false end
        char = entitylib.character.Character
    else
        return false
    end

    local stacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks")
               or char:GetAttribute("FreezeStacks") or char:GetAttribute("FROZEN_STACKS")
    if stacks and stacks >= threshold then return true end

    local statusEffects = char:GetAttribute("StatusEffects")
    if type(statusEffects) == "table" then
        for effectName, stackCount in pairs(statusEffects) do
            local nameLower = tostring(effectName):lower()
            if nameLower:match("[cold|frost|freeze]") then
                if type(stackCount) == "number" then
                    if stackCount >= threshold then return true end
                elseif stackCount then
                    return true
                end
            end
        end
    end

    if char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell") then
        return true
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed <= 2 then
        return true
    end

    return false
end

local sharedRaycast = RaycastParams.new()
sharedRaycast.FilterType = Enum.RaycastFilterType.Include
sharedRaycast.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}

local function cloneRaycast()
    local r = RaycastParams.new()
    r.FilterType = sharedRaycast.FilterType
    r.FilterDescendantsInstances = sharedRaycast.FilterDescendantsInstances
    r.RespectCanCollide = sharedRaycast.RespectCanCollide
    return r
end

local function isSword()
    return store.hand and store.hand.toolType == 'sword'
end

local function hasValidWeapon()
    if not store.hand or not store.hand.tool then return false end
    local toolType = store.hand.toolType
    local toolName = store.hand.tool.Name:lower()
    if toolName:find('headhunter') then return true end
    return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
end

local function isHoldingProjectile()
    if not store.hand or not store.hand.tool then return false end
    local toolName = store.hand.tool.Name:lower()
    return toolName:find('bow') or toolName:find('crossbow') or toolName == 'headhunter' or (bedwars.ItemMeta[toolName] and bedwars.ItemMeta[toolName].projectileSource)
end

local function isHoldingPickaxe()
    if not store.hand or not store.hand.tool then return false end
    local itemName = store.hand.tool.Name:lower()
    return itemName:find("pickaxe") or itemName:find("drill") or itemName:find("gauntlet") or itemName:find("hammer") or itemName:find("axe")
end

local function isHoldingSword()
    return isSword()
end

local function isEnemy(ent)
    if not ent then return false end
    if ent.Player then
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = ent.Player:GetAttribute('Team')
        if not myTeam or not theirTeam or myTeam == theirTeam then return false end
        return select(2, whitelist:get(ent.Player))
    elseif ent.NPC then
        local npcTeam = ent.Character:GetAttribute('Team')
        if npcTeam then return lplr:GetAttribute('Team') ~= npcTeam end
        return true
    end
    return false
end

local function isTeammate(player)
    if not lplr or not player then return false end
    local myTeam = lplr:GetAttribute('Team')
    local theirTeam = player:GetAttribute('Team')
    return myTeam and theirTeam and myTeam == theirTeam
end

local function getPlayerName(player, useDisplayName)
    if not player then return '' end
    return (useDisplayName and player.DisplayName ~= "" and player.DisplayName) or player.Name
end

local armorTiers = {'none','leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
local function getArmorTier(player)
    if not player or not store.inventories[player] then return 0 end
    local chest = store.inventories[player].armor and store.inventories[player].armor[5]
    if not chest or chest == 'empty' then return 1 end
    return table.find(armorTiers, chest.itemType) or 1
end

local function checkFaceAdjacent(pos, faces)
    faces = faces or {
        Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,3,0),
        Vector3.new(0,-3,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)
    }
    for _, v in ipairs(faces) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function hasFaceBelowOrSide(pos)
    if getPlacedBlock(pos - Vector3.new(0,3,0)) then return true end
    local sides = {Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)}
    for _, v in ipairs(sides) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function nearCorner(poscheck, pos)
    local start = poscheck - Vector3.new(3,3,3)
    local fin = poscheck + Vector3.new(3,3,3)
    local dir = (pos - poscheck).Unit * 100
    local check = poscheck + dir
    return Vector3.new(
        math.clamp(check.X, start.X, fin.X),
        math.clamp(check.Y, start.Y, fin.Y),
        math.clamp(check.Z, start.Z, fin.Z)
    )
end

local function blockProximity(pos, rangeBlocks)
    rangeBlocks = rangeBlocks or 21
    local mag, best = 60, nil
    local blocks = getBlocksInPoints(
        bedwars.BlockController:getBlockPosition(pos - Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks)),
        bedwars.BlockController:getBlockPosition(pos + Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks))
    )
    for _, v in ipairs(blocks) do
        local bp = nearCorner(v, pos)
        local d = (pos - bp).Magnitude
        if hasFaceBelowOrSide(bp) and d < mag then
            mag, best = d, bp
        end
    end
    return best
end

local function getBlocksInPoints(s, e)
    local store = bedwars.BlockController:getStore()
    local list = {}
    for x = s.X, e.X do
        for y = s.Y, e.Y do
            for z = s.Z, e.Z do
                if store:getBlockAt(Vector3.new(x,y,z)) then
                    table.insert(list, Vector3.new(x,y,z) * 3)
                end
            end
        end
    end
    return list
end

local function isGUIOpen()
    return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.DIALOG)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.POPUP)
        or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
        or (bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open)
end

local function isTargetValid(ent, maxDist, checkWalls)
    if not ent or not ent.RootPart or not ent.Character then return false end
    if not entitylib.isAlive then return false end
    local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    if dist > maxDist then return false end
    if checkWalls then
        local ray = workspace:Raycast(
            entitylib.character.RootPart.Position,
            (ent.RootPart.Position - entitylib.character.RootPart.Position),
            sharedRaycast
        )
        if ray then return false end
    end
    local hum = ent.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getTargetByPriority(originPos, range, opts)
    opts = opts or {}
    local players = opts.players == nil and true or opts.players
    local npcs = opts.npcs or false
    local walls = opts.walls or false
    local sort = opts.sort or 'distance' -- 'health','armor','damage'
    local damageTracker = opts.damageTracker 

    local valid = {}
    for _, ent in ipairs(entitylib.List) do
        if (players and ent.Player) or (npcs and ent.NPC) then
            if isEnemy(ent) and ent.RootPart then
                local dist = (ent.RootPart.Position - originPos).Magnitude
                if dist <= range then
                    if walls then
                        local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), sharedRaycast)
                        if not ray then
                            table.insert(valid, ent)
                        end
                    else
                        table.insert(valid, ent)
                    end
                end
            end
        end
    end
    if #valid == 0 then return nil end

    if sort == 'distance' then
        table.sort(valid, function(a,b)
            return (a.RootPart.Position - originPos).Magnitude < (b.RootPart.Position - originPos).Magnitude
        end)
    elseif sort == 'damage' and damageTracker then
        table.sort(valid, function(a,b)
            local keyA = a.Player and a.Player.UserId or tostring(a)
            local keyB = b.Player and b.Player.UserId or tostring(b)
            return (damageTracker[keyA] or 0) > (damageTracker[keyB] or 0)
        end)
    end
    return valid[1]
end

local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled

local function getTeammates()
    local teammates = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return teammates end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                table.insert(teammates, player)
            end
        end
    end
    return teammates
end

local function getTeammateNames()
    local names = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return names end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            table.insert(names, player.Name)
        end
    end
    table.sort(names)
    return names
end

local function getNearestTeammateInRange(range, condition)
    if not entitylib.isAlive then return nil end
    local myPos = entitylib.character.RootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, player in ipairs(getTeammates()) do
        if player.Character and player.Character.PrimaryPart then
            local dist = (player.Character.PrimaryPart.Position - myPos).Magnitude
            if dist <= range then
                if condition and not condition(player) then continue end
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function getPlayerHealth(player)
    if not player or not player.Character then return 0, 100 end
    local health = player.Character:GetAttribute('Health') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.Health) or 0
    local maxHealth = player.Character:GetAttribute('MaxHealth') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.MaxHealth) or 100
    return health, maxHealth
end

local function getPlayerHealthPercent(player)
    local health, maxHealth = getPlayerHealth(player)
    if maxHealth == 0 then return 0 end
    return (health / maxHealth) * 100
end

local projectileRemote
task.spawn(function() projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance end)

run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim
	local AimPart
	local ViewMode
	local PriorityMode
	local ShakeToggle
	local ShakeAmount
	local ShopCheck
	local WorkWithProjectiles

	local lockedTarget = nil
	local rng = Random.new()

	local function isFirstPerson()
		local head = lplr.Character and lplr.Character:FindFirstChild("Head")
		if head then
			return (head.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 2
		end
		return false
	end

	local function getClosestPartToCursor(character)
		local mousePos = inputService:GetMouseLocation()
		local mouseRay = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y, 0)
		local bestAngle = math.huge
		local bestPart = nil
		local partNames = {
			'HumanoidRootPart', 'Head', 'UpperTorso', 'LowerTorso',
			'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
			'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftFoot', 'RightFoot', 'LeftHand', 'RightHand'
		}
		for _, partName in partNames do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - mouseRay.Origin).Unit
				local angle = math.acos(math.clamp(mouseRay.Direction:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart
	end

	local function isProjectileWeapon()
		if store.hand and store.hand.tool then
			local toolName = store.hand.tool.Name:lower()
			return toolName:find("bow") or toolName:find("crossbow") or toolName:find("headhunter")
		end
		return false
	end

	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					local validWeapon = store.hand.toolType == 'sword'
					if WorkWithProjectiles.Enabled then
						validWeapon = validWeapon or isProjectileWeapon()
					end
					if not validWeapon then
						lockedTarget = nil
						return
					end

					if not entitylib.isAlive then
						lockedTarget = nil
						return
					end

					if ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) >= 0.4 then
						lockedTarget = nil
						return
					end

					local currentView = isFirstPerson()
					if ViewMode.Value == "First Person" and not currentView then return end
					if ViewMode.Value == "Third Person" and currentView then return end

					if ShopCheck.Enabled and lplr.PlayerGui and lplr.PlayerGui:FindFirstChild("ItemShop") then
						lockedTarget = nil
						return
					end

					local ent
					if PriorityMode.Enabled and lockedTarget then
						local delta = (lockedTarget.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local flatDelta = delta * Vector3.new(1, 0, 1)
						if flatDelta.Magnitude > 0.001 then
							local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
							local dist = delta.Magnitude
							if dist <= Distance.Value and angle < (math.rad(AngleSlider.Value) / 2) then
								ent = lockedTarget
							else
								lockedTarget = nil
							end
						else
							lockedTarget = nil
						end
					end

					if not ent then
						ent = entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})
						if PriorityMode.Enabled and ent then
							lockedTarget = ent
						end
					end

					if KillauraTarget.Enabled and store.KillauraTarget then
						ent = store.KillauraTarget
						if PriorityMode.Enabled then
							lockedTarget = ent
						end
					end

					if ent and ent.RootPart then
						local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local flatDelta = delta * Vector3.new(1, 0, 1)
						if flatDelta.Magnitude > 0.001 then
							local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
							if angle >= (math.rad(AngleSlider.Value) / 2) then
								if PriorityMode.Enabled then lockedTarget = nil end
								return
							end
						else
							return
						end

						targetinfo.Targets[ent] = tick() + 1

						local aimPosition = ent.RootPart.Position
						if AimPart.Value == "Head" then
							local head = ent.Character and ent.Character:FindFirstChild("Head")
							if head then
								aimPosition = head.Position
							end
						elseif AimPart.Value == "Closest" then
							if ent.Character then
								local closestPart = getClosestPartToCursor(ent.Character)
								if closestPart then
									aimPosition = closestPart.Position
								end
							end
						end

						if ShakeToggle.Enabled and ShakeAmount.Value > 0 then
							local shakeIntensity = ShakeAmount.Value / 10
							aimPosition = aimPosition + Vector3.new(
								(rng:NextNumber() - 0.5) * shakeIntensity,
								(rng:NextNumber() - 0.5) * shakeIntensity,
								(rng:NextNumber() - 0.5) * shakeIntensity
							)
						end

						local aimSpeed = AimSpeed.Value
						if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
							aimSpeed = aimSpeed + 10
						end

						local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
						gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, aimSpeed * dt)
					else
						if PriorityMode.Enabled then
							lockedTarget = nil
						end
					end
				end))
			else
				lockedTarget = nil
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})

	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target'
	})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})

	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Torso', 'Head', 'Closest'},
		Default = 'Torso'
	})

	ViewMode = AimAssist:CreateDropdown({
		Name = 'View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
		Tooltip = 'Only aim in first person, third person, or always'
	})

	PriorityMode = AimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'Lock onto one target until they leave range'
	})

	ShakeToggle = AimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Function = function(callback)
			ShakeAmount.Object.Visible = callback
		end,
		Tooltip = 'Add slight jitter to aim'
	})

	ShakeAmount = AimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})

	ShopCheck = AimAssist:CreateToggle({
		Name = 'Shop Check',
		Default = false,
		Tooltip = 'Disable when shop is open'
	})

	WorkWithProjectiles = AimAssist:CreateToggle({
		Name = 'Work With Projectiles',
		Default = false,
		Tooltip = 'Also work when holding bows/crossbows (sword still required otherwise)'
	})

	task.defer(function()
		if ShakeAmount and ShakeAmount.Object then
			ShakeAmount.Object.Visible = false
		end
	end)
end)

run(function()
	local ProjectileAimAssist
	local Targets
	local PAMode
	local AimSpeed
	local ReactionTime
	local Distance
	local AngleSlider
	local AimPart
	local PriorityMode
	local ClickAim
	local VerticalAim
	local VerticalOffset
	local ShakeToggle
	local ShakeAmount
	local ShopCheck
	local FirstPersonCheck
	local StrafeMultiplier
	
	local rayCheck = cloneRaycast()
	
	local lockedTarget = nil
	local rng = Random.new()
	local lastAimCFrame = nil
	local aimingAtTarget = false
	local reactionStartTime = 0
	local hasReacted = false
	local currentTarget = nil
	
	local aerov4bad = {
		predictStrafingMovement = function(targetPlayer, targetPart, projSpeed, gravity, origin)
			if not targetPlayer or not targetPlayer.Character or not targetPart then 
				return targetPart and targetPart.Position or Vector3.zero
			end
			
			local currentPos = targetPart.Position
			local currentVel = targetPart.Velocity
			local distance = (currentPos - origin).Magnitude
			local timeToTarget = distance / projSpeed
			
			local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
			local horizontalSpeed = horizontalVel.Magnitude
			local horizontalStrength = 1.0

			if projSpeed >= 450 then
				if distance > 80 then
					horizontalStrength = 0.92
				elseif distance > 50 then
					horizontalStrength = 0.95
				else
					horizontalStrength = 0.98
				end
			elseif projSpeed >= 350 then
				if distance > 80 then
					horizontalStrength = 0.88
				elseif distance > 50 then
					horizontalStrength = 0.92
				else
					horizontalStrength = 0.95
				end
			else
				if distance > 80 then
					horizontalStrength = 1.15
				elseif distance > 50 then
					horizontalStrength = 1.10
				else
					horizontalStrength = 1.05
				end
			end
			
			local predictedHorizontal = horizontalVel * timeToTarget * horizontalStrength
			
			local verticalVel = currentVel.Y
			local isFreeFalling = verticalVel < -50
			local isFalling = verticalVel < -15 and verticalVel >= -50
			local isJumping = verticalVel > 10
			local isPeaking = verticalVel >= -3 and verticalVel <= 3
			
			local verticalStrength = 0.5
			if isFreeFalling then
				verticalStrength = 0.80
			elseif isFalling then
				verticalStrength = 0.75
			elseif isJumping then
				verticalStrength = 0.60
			elseif isPeaking then
				verticalStrength = 0.40	
			else
				verticalStrength = 0.50
			end
			
			local verticalPrediction = verticalVel * timeToTarget * verticalStrength
			
			local dropCompensation = 0
			if gravity > 0 then
				dropCompensation = 0.5 * gravity * (timeToTarget * timeToTarget)
				
				if projSpeed >= 450 then
					dropCompensation = dropCompensation * 0.6
				elseif projSpeed >= 350 then
					dropCompensation = dropCompensation * 0.75
				end
			end
			
			local finalPosX = currentPos.X + predictedHorizontal.X
			local finalPosY = currentPos.Y + verticalPrediction + dropCompensation
			local finalPosZ = currentPos.Z + predictedHorizontal.Z
			local finalPosition = Vector3.new(finalPosX, finalPosY, finalPosZ)
			
			if distance > 100 then
				local maxPredictTime = 1.5
				if timeToTarget > maxPredictTime then
					local cappedHorizontal = horizontalVel * maxPredictTime * horizontalStrength
					local cappedVertical = verticalVel * maxPredictTime * verticalStrength
					local cappedDrop = 0.5 * gravity * (maxPredictTime * maxPredictTime)
					
					if projSpeed >= 450 then
						cappedDrop = cappedDrop * 0.6
					elseif projSpeed >= 350 then
						cappedDrop = cappedDrop * 0.75
					end
					
					finalPosition = Vector3.new(
						currentPos.X + cappedHorizontal.X,
						currentPos.Y + cappedVertical + cappedDrop,
						currentPos.Z + cappedHorizontal.Z
					)
				end
			end
			
			return finalPosition
		end
	}
	
	local function getAimSpeed(sliderValue)
		local baseSpeed = 0.008
		local multiplier = 1.35
		local speed = baseSpeed * (multiplier ^ sliderValue)
		return math.min(speed, 0.95)
	end
	
	local function getTargetPart(ent)
		if not ent or not ent.Character then return nil end
		
		if AimPart.Value == "Head" then
			return ent.Character:FindFirstChild("Head") or ent.Head or ent.RootPart
		elseif AimPart.Value == "Torso" then
			return ent.Character:FindFirstChild("Torso") or ent.Character:FindFirstChild("UpperTorso") or ent.RootPart
		else
			return ent.RootPart
		end
	end
	
	local function getPredictedPosition(ent, origin)
		if not ent or not ent.RootPart then return nil end
		
		local targetBodyPart = getTargetPart(ent)
		if not targetBodyPart then return nil end
		
		if PAMode.Value == 'Aero' then
			local projSpeed = 100
			local gravity = 196.2
			
			if store.hand and store.hand.tool then
				local toolName = store.hand.tool.Name
				local itemMeta = bedwars.ItemMeta[toolName]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					local projectileType = projectileSource.projectileType
					
					if type(projectileType) == "function" then
						local success, result = pcall(projectileType, nil)
						if success then
							projectileType = result
						end
					end
					
					if projectileType then
						local projectileMeta = bedwars.ProjectileMeta[projectileType]
						if projectileMeta then
							projSpeed = projectileMeta.launchVelocity or 100
							gravity = (projectileMeta.gravitationalAcceleration or 196.2)
						end
					end
				end
			end
			
			local predictedPos = aerov4bad.predictStrafingMovement(
				ent.Player,
				targetBodyPart,
				projSpeed,
				gravity,
				origin
			)
			
			return predictedPos
		else
			local playerGravity = workspace.Gravity
			local balloons = ent.Character:GetAttribute('InflatedBalloons')
			
			if balloons and balloons > 0 then
				playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
			end
			
			if ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
				playerGravity = 6
			end
			
			if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
				for _, owl in collectionService:GetTagged('Owl') do
					if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
						playerGravity = 0
						break
					end
				end
			end
			
			local projSpeed = 100
			local gravity = 196.2
			
			if store.hand and store.hand.tool then
				local toolName = store.hand.tool.Name
				local itemMeta = bedwars.ItemMeta[toolName]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					local projectileType = projectileSource.projectileType
					
					if type(projectileType) == "function" then
						local success, result = pcall(projectileType, nil)
						if success then
							projectileType = result
						end
					end
					
					if projectileType then
						local projectileMeta = bedwars.ProjectileMeta[projectileType]
						if projectileMeta then
							projSpeed = projectileMeta.launchVelocity or 100
							gravity = (projectileMeta.gravitationalAcceleration or 196.2)
						end
					end
				end
			end
			
			local calc = prediction.SolveTrajectory(
				origin,
				projSpeed,
				gravity,
				targetBodyPart.Position,
				targetBodyPart.Velocity,
				playerGravity,
				ent.HipHeight,
				ent.Jumping and 42.6 or nil,
				rayCheck
			)
			
			return calc
		end
	end
	
	ProjectileAimAssist = vape.Categories.Combat:CreateModule({
		Name = 'ProjectileAimAssist',
		Function = function(callback)
			if callback then
				ProjectileAimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if not (entitylib.isAlive and isHoldingProjectile() and ((not ClickAim.Enabled) or (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) < 0.4)) then
						lockedTarget = nil
						currentTarget = nil
						hasReacted = false
						return
					end
					
					if ShopCheck.Enabled then
						local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
						if isShop then return end
					end
					
					if FirstPersonCheck.Enabled and not isFirstPerson() then return end
					
					local ent = nil
					
					if PriorityMode.Enabled then
						if lockedTarget and isTargetValid(lockedTarget, Distance.Value, Targets.Walls.Enabled) then
							local delta = (lockedTarget.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							
							if angle < (math.rad(AngleSlider.Value) / 2) then
								ent = lockedTarget
							else
								lockedTarget = nil
								currentTarget = nil
								hasReacted = false
							end
						else
							lockedTarget = nil
						end
						
						if not ent then
							ent = entitylib.EntityPosition({
								Range = Distance.Value,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods.Distance
							})
							
							if ent then
								lockedTarget = ent
							end
						end
					else
						lockedTarget = nil
						ent = entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods.Distance
						})
					end
					
					if ent then
						if currentTarget ~= ent then
							currentTarget = ent
							hasReacted = false
							reactionStartTime = tick()
						end
						
						if not hasReacted then
							local reactionDelay = ReactionTime.Value / 1000
							local randomVariance = (rng:NextNumber() - 0.5) * 0.3 * reactionDelay
							local actualDelay = reactionDelay + randomVariance
							
							if (tick() - reactionStartTime) < actualDelay then
								return
							else
								hasReacted = true
							end
						end
						
						pcall(function()
							local plr = ent
							vapeTargetInfo.Targets.ProjectileAimAssist = {
								Humanoid = {
									Health = (plr.Character:GetAttribute("Health") or plr.Humanoid.Health) + getShieldAttribute(plr.Character),
									MaxHealth = plr.Character:GetAttribute("MaxHealth") or plr.Humanoid.MaxHealth
								},
								Player = plr.Player
							}
						end)
						
						local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle >= (math.rad(AngleSlider.Value) / 2) then return end
						
						targetinfo.Targets[ent] = tick() + 1
						
						local origin = entitylib.character.RootPart.Position
						local predictedPosition = getPredictedPosition(ent, origin)
						
						if not predictedPosition then return end
						
						local aimPosition = predictedPosition
						
						if VerticalAim.Enabled then
							aimPosition = aimPosition + Vector3.new(0, VerticalOffset.Value, 0)
						end
						
						local finalAimSpeed = getAimSpeed(AimSpeed.Value)
						
						if StrafeMultiplier.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
							finalAimSpeed = finalAimSpeed * 1.15
						end
						
						if ShakeToggle.Enabled and ShakeAmount.Value > 0 then
							local shakeIntensity = ShakeAmount.Value / 10
							local speedVariation = 1 + ((rng:NextNumber() - 0.5) * shakeIntensity * 0.3)
							finalAimSpeed = finalAimSpeed * speedVariation
							
							local jitterAmount = ShakeAmount.Value * 0.1
							local microJitter = Vector3.new(
								(rng:NextNumber() - 0.5) * jitterAmount,
								(rng:NextNumber() - 0.5) * jitterAmount,
								(rng:NextNumber() - 0.5) * jitterAmount
							)
							aimPosition = aimPosition + microJitter
						end
						
						local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
						gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, finalAimSpeed)
						lastAimCFrame = targetCFrame
						aimingAtTarget = true
					else
						currentTarget = nil
						hasReacted = false
						
						if aimingAtTarget and lastAimCFrame then
							local retractSpeed = 0.05
							if (gameCamera.CFrame.Position - lastAimCFrame.Position).Magnitude > 0.1 then
								gameCamera.CFrame = gameCamera.CFrame:Lerp(
									CFrame.new(gameCamera.CFrame.Position, gameCamera.CFrame.Position + gameCamera.CFrame.LookVector),
									retractSpeed
								)
							else
								aimingAtTarget = false
								lastAimCFrame = nil
							end
						end
						
						if PriorityMode.Enabled then
							lockedTarget = nil
						end
					end
				end))
			else
				lockedTarget = nil
				aimingAtTarget = false
				lastAimCFrame = nil
				currentTarget = nil
				hasReacted = false
			end
		end,
		Tooltip = 'Projectile aim assist with prediction'
	})
	
	Targets = ProjectileAimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	
	PAMode = ProjectileAimAssist:CreateDropdown({
		Name = 'Prediction Mode',
		List = {'Vape', 'Aero'},
		Default = 'Aero',
		Tooltip = 'Vape = Built-in | Aero = Custom'
	})
	
	AimSpeed = ProjectileAimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6,
		Tooltip = 'How fast the aim assistant tracks'
	})
	
	ReactionTime = ProjectileAimAssist:CreateSlider({
		Name = 'Reaction Time',
		Min = 0,
		Max = 300,
		Default = 80,
		Suffix = 'ms',
		Tooltip = 'Delay before aim assist activates'
	})
	
	Distance = ProjectileAimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 25,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AngleSlider = ProjectileAimAssist:CreateSlider({
		Name = 'Max Angle',
		Min = 1,
		Max = 360,
		Default = 60,
		Tooltip = 'FOV angle for target acquisition'
	})
	
	AimPart = ProjectileAimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Root', 'Torso', 'Head'},
		Default = 'Root'
	})
	
	PriorityMode = ProjectileAimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'Lock onto one target'
	})
	
	ClickAim = ProjectileAimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true,
		Tooltip = 'Only aim when attacking'
	})
	
	VerticalAim = ProjectileAimAssist:CreateToggle({
		Name = 'Vertical Offset',
		Default = false,
		Function = function(callback)
			VerticalOffset.Object.Visible = callback
		end
	})
	
	VerticalOffset = ProjectileAimAssist:CreateSlider({
		Name = 'Offset',
		Min = -3,
		Max = 3,
		Default = 0,
		Decimal = 10,
		Visible = false
	})
	
	ShakeToggle = ProjectileAimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Function = function(callback)
			ShakeAmount.Object.Visible = callback
		end,
		Tooltip = 'Add jitter to aim'
	})
	
	ShakeAmount = ProjectileAimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})
	
	ShopCheck = ProjectileAimAssist:CreateToggle({
		Name = "Shop Check",
		Default = false,
		Tooltip = 'Disable when shop is open'
	})
	
	FirstPersonCheck = ProjectileAimAssist:CreateToggle({
		Name = "First Person Only",
		Default = false,
		Tooltip = 'Only work in first person'
	})
	
    StrafeMultiplier = ProjectileAimAssist:CreateToggle({
        Name = 'Strafe Boost',
        Tooltip = 'Faster aim when strafing'
    })

    task.defer(function()
        if VerticalOffset and VerticalOffset.Object then
            VerticalOffset.Object.Visible = false
        end
        if ShakeAmount and ShakeAmount.Object then
            ShakeAmount.Object.Visible = false
        end
    end)
end)
	
run(function()
    if isMobile then
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local Thread

        local function getSafeCPS()
            if store.hand and store.hand.toolType == 'block' and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            end
            if CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end

            local initialCPS = getSafeCPS()
            if not initialCPS then return end

            Thread = task.delay(1 / initialCPS.GetRandomValue(), function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                        local toolType = store.hand and store.hand.toolType

                        if toolType == 'block' and blockPlacer then
                            task.spawn(function()
                                blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
                            end)
                        elseif toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    if not currentCPS then
                        task.wait(0.1)
                    else
                        task.wait(1 / currentCPS.GetRandomValue())
                    end
                until not AutoClicker.Enabled
            end)
        end

        local function StopClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            AutoClick()
                        end
                    end))

                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            StopClick()
                        end
                    end))

                    for _, v in {'2', '5'} do
                        pcall(function()
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(StopClick))
                        end)
                    end
                else
                    StopClick()
                end
            end,
            Tooltip = 'Hold attack button to automatically click'
        })

        CPS = AutoClicker:CreateTwoSlider({
            Name = 'CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7
        })

        AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = true,
            Function = function(callback)
                if BlockCPS.Object then
                    BlockCPS.Object.Visible = callback
                end
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

		task.defer(function()
			if BlockCPS and BlockCPS.Object then
				BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
			end
			updateModeVisibility()  
		end)

    else
        local AutoClicker
        local ACMode
        local CPS
        local BlockCPS = {}
        local SwordCPS = {}
        local ProjectileCPS = {}
        local PlaceBlocksToggle
        local SwingSwordToggle
        local ShootProjectilesToggle
        local Thread
        local KeybindToggle
        local KeybindList
        local MouseBindToggle
        local MouseBindList
        local KeybindMode
        local CurrentKeybind = Enum.KeyCode.LeftAlt
        local CurrentMouseBind = Enum.UserInputType.MouseButton2
        local UseMouseBind = false
        local KeybindEnabled = false
        local KeybindHeld = false
        local KeybindActive = false
        local ActivationScheduled = nil
        local MIN_HOLD_TIME = 0.12

        local task_wait = task.wait
        local task_spawn = task.spawn
        local tick = tick
        local workspace_GetServerTimeNow = function() return workspace:GetServerTimeNow() end
        local projectileRemote = {InvokeServer = function() end}
        local FireDelays = {}

        task.spawn(function()
            projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
        end)

        local ammoCache = {}
        local lastAmmoCheck = 0
        local function getAmmo(check)
            local now = tick()
            if now - lastAmmoCheck < 0.5 then
                local cached = ammoCache[check]
                if cached then return cached end
            end
            for _, item in store.inventory.inventory.items do
                if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
                    ammoCache[check] = item.itemType
                    lastAmmoCheck = now
                    return item.itemType
                end
            end
            return nil
        end

        local function shootProjectile()
            if not store.hand or not store.hand.tool then return end
            if not isHoldingProjectile() then return end
            local tool = store.hand.tool
            local itemMeta = bedwars.ItemMeta[tool.Name]
            if not itemMeta or not itemMeta.projectileSource then return end
            local projectileSource = itemMeta.projectileSource
            local ammo = getAmmo(projectileSource)
            if not ammo then return end
            local projectileType = projectileSource.projectileType
            if type(projectileType) == 'function' then
                local success, result = pcall(projectileType, ammo)
                if success then projectileType = result end
            end
            if not projectileType then return end
            local projectileMeta = bedwars.ProjectileMeta[projectileType]
            if not projectileMeta then return end
            local now = tick()
            if (FireDelays[tool.Name] or 0) > now then return end
            local pos = entitylib.character.RootPart.Position
            local lookVector = gameCamera.CFrame.LookVector
            local shootPosition = (gameCamera.CFrame * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
            task_spawn(function()
                local id = httpService:GenerateGUID(true)
                local projSpeed = projectileMeta.launchVelocity or 100
                local toolName = tool.Name
                local isCrossbow = toolName:find('crossbow') ~= nil
                if isCrossbow then
                    bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
                elseif toolName:find('bow') then
                    bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
                end
                bedwars.ProjectileController:createLocalProjectile(projectileMeta, ammo, projectileType, shootPosition, id, lookVector * projSpeed, {drawDurationSeconds = 1})
                local res = projectileRemote:InvokeServer(tool, ammo, projectileType, shootPosition, pos, lookVector * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace_GetServerTimeNow() - 0.045)
                if res then
                    local shoot = projectileSource.launchSound
                    shoot = shoot and shoot[math.random(1, #shoot)] or nil
                    if shoot then bedwars.SoundManager:playSound(shoot) end
                end
            end)
            FireDelays[tool.Name] = now + (projectileSource.fireDelaySec or 0.5)
        end

        local function getSafeCPS()
            local toolType = store.hand and store.hand.toolType or nil
            if toolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            elseif toolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
                return SwordCPS
            elseif ShootProjectilesToggle and ShootProjectilesToggle.Enabled and isHoldingProjectile() and ProjectileCPS and ProjectileCPS.GetRandomValue then
                return ProjectileCPS
            elseif CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function UpdateKeybindState()
            if not KeybindEnabled then
                KeybindActive = true
                return
            end
            if KeybindMode.Value == 'Toggle' then
                return
            elseif KeybindMode.Value == 'Hold' then
                if UseMouseBind then
                    KeybindActive = inputService:IsMouseButtonPressed(CurrentMouseBind)
                else
                    KeybindActive = inputService:IsKeyDown(CurrentKeybind)
                end
            end
        end

        local function AutoClickVape()
            if Thread then task.cancel(Thread) end
            local initialCPS = getSafeCPS()
            if not initialCPS then return end
            Thread = task.delay(1 / initialCPS.GetRandomValue(), function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                        local toolType = store.hand and store.hand.toolType
                        if toolType == 'block' and blockPlacer then
                            if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                    task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                end
                            end
                        elseif toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end
                    local currentCPS = getSafeCPS()
                    task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
                until not AutoClicker.Enabled
            end)
        end

        local function AutoClickAero()
            if Thread then task.cancel(Thread) end
            Thread = task_spawn(function()
                local toolCheckCounter = 0
                repeat
                    if KeybindEnabled and KeybindMode.Value == 'Hold' then
                        if toolCheckCounter % 3 == 0 then
                            UpdateKeybindState()
                        end
                        if not KeybindActive then
                            task_wait(0.1)
                            toolCheckCounter += 1
                            continue
                        end
                    end

                    toolCheckCounter += 1

                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) and not _G.autoShootLock then
                        local toolType = store.hand and store.hand.toolType
                        if PlaceBlocksToggle.Enabled and toolType == 'block' then
                            local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                            if blockPlacer then
                                if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                    local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                    if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                        task_spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                    end
                                end
                            end
                        elseif SwingSwordToggle.Enabled and toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        elseif ShootProjectilesToggle.Enabled and isHoldingProjectile() then
                            shootProjectile()
                        end
                    end

                    local currentCPS = getSafeCPS()
                    task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
                until not AutoClicker.Enabled
            end)
        end

        local function AutoClick()
            if ACMode.Value == 'Vape' then
                AutoClickVape()
            else
                AutoClickAero()
            end
        end

        local function StartAutoClick()
            if not Thread then AutoClick() end
        end

        local function StopAutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
            if ActivationScheduled then
                task.cancel(ActivationScheduled)
                ActivationScheduled = nil
            end
        end

        local function ToggleKeybind()
            if KeybindMode.Value == 'Toggle' then
                KeybindHeld = not KeybindHeld
                KeybindActive = KeybindHeld
                if KeybindActive then StartAutoClick() else StopAutoClick() end
            end
        end

        local lastToggleRestart = 0
        local function SafeToggleRestart()
            local now = tick()
            if now - lastToggleRestart < 0.2 then return end
            lastToggleRestart = now
            if AutoClicker.Enabled then
                AutoClicker:Toggle()
                task_wait(0.05)
                AutoClicker:Toggle()
            end
        end

		local function updateModeVisibility()
			local isAero = ACMode.Value == 'Aero'
			if SwingSwordToggle and SwingSwordToggle.Object then SwingSwordToggle.Object.Visible = isAero end
			if SwordCPS and SwordCPS.Object then SwordCPS.Object.Visible = isAero and (SwingSwordToggle and SwingSwordToggle.Enabled) end
			if ShootProjectilesToggle and ShootProjectilesToggle.Object then ShootProjectilesToggle.Object.Visible = isAero end
			if ProjectileCPS and ProjectileCPS.Object then ProjectileCPS.Object.Visible = isAero and (ShootProjectilesToggle and ShootProjectilesToggle.Enabled) end
			if KeybindToggle and KeybindToggle.Object then KeybindToggle.Object.Visible = isAero end
			if KeybindMode and KeybindMode.Object then KeybindMode.Object.Visible = isAero and KeybindEnabled end
			if KeybindList and KeybindList.Object then KeybindList.Object.Visible = isAero and KeybindEnabled and not UseMouseBind end
			if MouseBindToggle and MouseBindToggle.Object then MouseBindToggle.Object.Visible = isAero and KeybindEnabled end
			if MouseBindList and MouseBindList.Object then MouseBindList.Object.Visible = isAero and KeybindEnabled and UseMouseBind end
		end

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    if KeybindEnabled and ACMode.Value == 'Aero' then
                        AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                            if UseMouseBind then
                                if input.UserInputType == CurrentMouseBind then
                                    if KeybindMode.Value == 'Hold' then StartAutoClick()
                                    elseif KeybindMode.Value == 'Toggle' then ToggleKeybind() end
                                end
                            else
                                if input.UserInputType == Enum.UserInputType.Keyboard then
                                    if input.KeyCode == CurrentKeybind then
                                        if KeybindMode.Value == 'Hold' then StartAutoClick()
                                        elseif KeybindMode.Value == 'Toggle' then ToggleKeybind() end
                                    end
                                end
                            end
                        end))
                        AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                            if KeybindMode.Value == 'Hold' then
                                if UseMouseBind then
                                    if input.UserInputType == CurrentMouseBind then StopAutoClick() end
                                else
                                    if input.UserInputType == Enum.UserInputType.Keyboard then
                                        if input.KeyCode == CurrentKeybind then StopAutoClick() end
                                    end
                                end
                            end
                        end))
                    else
                        AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                if not _G.autoShootLock then
                                    ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
                                        ActivationScheduled = nil
                                        if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                                            AutoClick()
                                        end
                                    end)
                                end
                            end
                        end))
                        AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                if ActivationScheduled then
                                    task.cancel(ActivationScheduled)
                                    ActivationScheduled = nil
                                end
                                if Thread then
                                    task.cancel(Thread)
                                    Thread = nil
                                end
                            end
                        end))
                    end
                else
                    StopAutoClick()
                    ammoCache = {}
                    lastToolName = nil
                end
            end,
            Tooltip = 'Clicks for you'
        })

        ACMode = AutoClicker:CreateDropdown({
            Name = 'AC Mode',
            List = {'Vape', 'Aero'},
            Default = 'Vape',
            Function = function(val)
                StopAutoClick()
                KeybindHeld = false
                KeybindActive = false
                updateModeVisibility()
                SafeToggleRestart()
            end
        })

        CPS = AutoClicker:CreateTwoSlider({
            Name = 'CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7
        })

        PlaceBlocksToggle = AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = true,
            Function = function(callback)
                if BlockCPS.Object then BlockCPS.Object.Visible = callback end
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        SwingSwordToggle = AutoClicker:CreateToggle({
            Name = 'Swing Sword',
            Default = true,
            Function = function(callback)
                if SwordCPS.Object then SwordCPS.Object.Visible = callback end
            end
        })

        SwordCPS = AutoClicker:CreateTwoSlider({
            Name = 'Sword CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7,
            Darker = true
        })

        ShootProjectilesToggle = AutoClicker:CreateToggle({
            Name = 'Shoot Projectiles',
            Default = true,
            Function = function(callback)
                if ProjectileCPS.Object then ProjectileCPS.Object.Visible = callback end
            end
        })

        ProjectileCPS = AutoClicker:CreateTwoSlider({
            Name = 'Projectile CPS',
            Min = 1,
            Max = 5,
            DefaultMin = 3,
            DefaultMax = 3,
            Darker = true
        })

        KeybindToggle = AutoClicker:CreateToggle({
            Name = 'Use Keybind',
            Default = false,
            Function = function(callback)
                KeybindEnabled = callback
                if KeybindList.Object then KeybindList.Object.Visible = callback and not UseMouseBind end
                if MouseBindToggle.Object then MouseBindToggle.Object.Visible = callback end
                if MouseBindList.Object then MouseBindList.Object.Visible = callback and UseMouseBind end
                if KeybindMode.Object then KeybindMode.Object.Visible = callback end
                SafeToggleRestart()
            end
        })

        KeybindMode = AutoClicker:CreateDropdown({
            Name = 'Keybind Mode',
            List = {'Hold', 'Toggle'},
            Default = 'Hold',
            Darker = true,
            Visible = false,
            Function = function(value)
                KeybindHeld = false
                KeybindActive = false
                SafeToggleRestart()
            end
        })

        KeybindList = AutoClicker:CreateDropdown({
            Name = 'Keybind',
            List = {'LeftAlt','LeftControl','LeftShift','RightAlt','RightControl','RightShift','Space','CapsLock','Tab','E','Q','R','F','G','X','Z','V','B'},
            Default = 'LeftAlt',
            Darker = true,
            Visible = false,
            Function = function(value)
                CurrentKeybind = Enum.KeyCode[value]
                KeybindHeld = false
                KeybindActive = false
                SafeToggleRestart()
            end
        })

        MouseBindToggle = AutoClicker:CreateToggle({
            Name = 'Use Mouse Button',
            Default = false,
            Visible = false,
            Function = function(callback)
                UseMouseBind = callback
                if KeybindList.Object then KeybindList.Object.Visible = KeybindEnabled and not callback end
                if MouseBindList.Object then MouseBindList.Object.Visible = KeybindEnabled and callback end
                KeybindHeld = false
                KeybindActive = false
                SafeToggleRestart()
            end
        })

        MouseBindList = AutoClicker:CreateDropdown({
            Name = 'Mouse Button',
            List = {'Right Click', 'Middle Click'},
            Default = 'Right Click',
            Darker = true,
            Visible = false,
            Function = function(value)
                local map = {['Right Click'] = Enum.UserInputType.MouseButton2, ['Middle Click'] = Enum.UserInputType.MouseButton3}
                CurrentMouseBind = map[value]
                KeybindHeld = false
                KeybindActive = false
                SafeToggleRestart()
            end
        })

        updateModeVisibility()

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = true
            end
            if SwordCPS and SwordCPS.Object then
                SwordCPS.Object.Visible = true
            end
            if ProjectileCPS and ProjectileCPS.Object then
                ProjectileCPS.Object.Visible = true
            end
            if KeybindMode and KeybindMode.Object then
                KeybindMode.Object.Visible = false
            end
            if KeybindList and KeybindList.Object then
                KeybindList.Object.Visible = false
            end
            if MouseBindToggle and MouseBindToggle.Object then
                MouseBindToggle.Object.Visible = false
            end
            if MouseBindList and MouseBindList.Object then
                MouseBindList.Object.Visible = false
            end
        end)
    end 
end)   

run(function()
    local KitRender
    local Players = playersService
    local player = Players.LocalPlayer
    local PlayerGui = player:WaitForChild("PlayerGui")

    local ids = {
        ['none'] = "rbxassetid://16493320215",
        ["random"] = "rbxassetid://79773209697352",
        ["cowgirl"] = "rbxassetid://9155462968",
        ["davey"] = "rbxassetid://9155464612",
        ["warlock"] = "rbxassetid://15186338366",
        ["ember"] = "rbxassetid://9630017904",
        ["black_market_trader"] = "rbxassetid://9630017904",
        ["yeti"] = "rbxassetid://9166205917",
        ["scarab"] = "rbxassetid://137137517627492",
        ["defender"] = "rbxassetid://131690429591874",
        ["cactus"] = "rbxassetid://104436517801089",
        ["oasis"] = "rbxassetid://120283205213823",
        ["berserker"] = "rbxassetid://90258047545241",
        ["sword_shield"] = "rbxassetid://131690429591874",
        ["airbender"] = "rbxassetid://74712750354593",
        ["gun_blade"] = "rbxassetid://138231219644853",
        ["frost_hammer_kit"] = "rbxassetid://11838567073",
        ["spider_queen"] = "rbxassetid://95237509752482",
        ["archer"] = "rbxassetid://9224796984",
        ["axolotl"] = "rbxassetid://9155466713",
        ["baker"] = "rbxassetid://9155463919",
        ["barbarian"] = "rbxassetid://9166207628",
        ["builder"] = "rbxassetid://9155463708",
        ["necromancer"] = "rbxassetid://11343458097",
        ["cyber"] = "rbxassetid://9507126891",
        ["sorcerer"] = "rbxassetid://97940108361528",
        ["bigman"] = "rbxassetid://9155467211",
        ["spirit_assassin"] = "rbxassetid://10406002412",
        ["farmer_cletus"] = "rbxassetid://9155466936",
        ["ice_queen"] = "rbxassetid://9155466204",
        ["grim_reaper"] = "rbxassetid://9155467410",
        ["spirit_gardener"] = "rbxassetid://132108376114488",
        ["hannah"] = "rbxassetid://10726577232",
        ["shielder"] = "rbxassetid://9155464114",
        ["summoner"] = "rbxassetid://18922378956",
        ["glacial_skater"] = "rbxassetid://84628060516931",
        ["dragon_sword"] = "rbxassetid://16215630104",
        ["lumen"] = "rbxassetid://9630018371",
        ["flower_bee"] = "rbxassetid://101569742252812",
        ["jellyfish"] = "rbxassetid://18129974852",
        ["melody"] = "rbxassetid://9155464915",
        ["mimic"] = "rbxassetid://14783283296",
        ["miner"] = "rbxassetid://9166208461",
        ["nazar"] = "rbxassetid://18926951849",
        ["seahorse"] = "rbxassetid://11902552560",
        ["elk_master"] = "rbxassetid://15714972287",
        ["rebellion_leader"] = "rbxassetid://18926409564",
        ["void_hunter"] = "rbxassetid://122370766273698",
        ["taliyah"] = "rbxassetid://13989437601",
        ["angel"] = "rbxassetid://9166208240",
        ["harpoon"] = "rbxassetid://18250634847",
        ["void_walker"] = "rbxassetid://78915127961078",
        ["spirit_summoner"] = "rbxassetid://95760990786863",
        ["triple_shot"] = "rbxassetid://9166208149",
        ["void_knight"] = "rbxassetid://73636326782144",
        ["regent"] = "rbxassetid://9166208904",
        ["vulcan"] = "rbxassetid://9155465543",
        ["owl"] = "rbxassetid://12509401147",
        ["dasher"] = "rbxassetid://9155467645",
        ["disruptor"] = "rbxassetid://11596993583",
        ["wizard"] = "rbxassetid://13353923546",
        ["aery"] = "rbxassetid://9155463221",
        ["agni"] = "rbxassetid://17024640133",
        ["alchemist"] = "rbxassetid://9155462512",
        ["spearman"] = "rbxassetid://9166207341",
        ["beekeeper"] = "rbxassetid://9312831285",
        ["falconer"] = "rbxassetid://17022941869",
        ["bounty_hunter"] = "rbxassetid://9166208649",
        ["blood_assassin"] = "rbxassetid://12520290159",
        ["battery"] = "rbxassetid://10159166528",
        ["steam_engineer"] = "rbxassetid://15380413567",
        ["vesta"] = "rbxassetid://9568930198",
        ["beast"] = "rbxassetid://9155465124",
        ["dino_tamer"] = "rbxassetid://9872357009",
        ["drill"] = "rbxassetid://12955100280",
        ["elektra"] = "rbxassetid://13841413050",
        ["fisherman"] = "rbxassetid://9166208359",
        ["queen_bee"] = "rbxassetid://12671498918",
        ["card"] = "rbxassetid://13841410580",
        ["frosty"] = "rbxassetid://9166208762",
        ["gingerbread_man"] = "rbxassetid://9155464364",
        ["ghost_catcher"] = "rbxassetid://9224802656",
        ["tinker"] = "rbxassetid://17025762404",
        ["ignis"] = "rbxassetid://13835258938",
        ["oil_man"] = "rbxassetid://9166206259",
        ["jade"] = "rbxassetid://9166306816",
        ["dragon_slayer"] = "rbxassetid://10982192175",
        ["paladin"] = "rbxassetid://11202785737",
        ["pinata"] = "rbxassetid://10011261147",
        ["merchant"] = "rbxassetid://9872356790",
        ["metal_detector"] = "rbxassetid://9378298061",
        ["slime_tamer"] = "rbxassetid://15379766168",
        ["nyoka"] = "rbxassetid://17022941410",
        ["midnight"] = "rbxassetid://9155462763",
        ["pyro"] = "rbxassetid://9155464770",
        ["raven"] = "rbxassetid://9166206554",
        ["santa"] = "rbxassetid://9166206101",
        ["sheep_herder"] = "rbxassetid://9155465730",
        ["smoke"] = "rbxassetid://9155462247",
        ["spirit_catcher"] = "rbxassetid://9166207943",
        ["star_collector"] = "rbxassetid://9872356516",
        ["styx"] = "rbxassetid://17014536631",
        ["block_kicker"] = "rbxassetid://15382536098",
        ["trapper"] = "rbxassetid://9166206875",
        ["hatter"] = "rbxassetid://12509388633",
        ["ninja"] = "rbxassetid://15517037848",
        ["jailor"] = "rbxassetid://11664116980",
        ["warrior"] = "rbxassetid://9166207008",
        ["mage"] = "rbxassetid://10982191792",
        ["void_dragon"] = "rbxassetid://10982192753",
        ["cat"] = "rbxassetid://15350740470",
        ["wind_walker"] = "rbxassetid://9872355499",
        ['skeleton'] = "rbxassetid://120123419412119",
        ['winter_lady'] = "rbxassetid://83274578564074",
    }

    local activeLoops = {}
    local updateDebounce = {}
    local retryThread = nil

    local function createkitrender(plr)
        local icon = Instance.new("ImageLabel")
        icon.Name = "AeroV4KitRender" 
        icon.AnchorPoint = Vector2.new(1, 0.5)
        icon.BackgroundTransparency = 1
        icon.Position = UDim2.new(1.05, 0, 0.5, 0)
        icon.Size = UDim2.new(1.5, 0, 1.5, 0)
        icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
        icon.ImageTransparency = 0.4
        icon.ScaleType = Enum.ScaleType.Crop
        local uar = Instance.new("UIAspectRatioConstraint")
        uar.AspectRatio = 1
        uar.AspectType = Enum.AspectType.FitWithinMaxSize
        uar.DominantAxis = Enum.DominantAxis.Width
        uar.Parent = icon
        icon.Image = ids[plr:GetAttribute("PlayingAsKit")] or ids["none"]
        return icon
    end

    local function removeallkitrenders()
        for key, _ in pairs(activeLoops) do
            activeLoops[key] = nil
        end
        table.clear(updateDebounce)
        
        if retryThread then
            task.cancel(retryThread)
            retryThread = nil
        end
        
        for _, v in ipairs(PlayerGui:GetDescendants()) do
            if v:IsA("ImageLabel") and v.Name == "AeroV4KitRender" then  
                v:Destroy()
            end
        end
    end

    local function refreshicon(icon, plr)
        if not icon or not icon.Parent then return end
        local kit = plr:GetAttribute("PlayingAsKit")
        local newImage = ids[kit] or ids["none"]
        if icon.Image ~= newImage then
            icon.Image = newImage
        end
    end

    local function findPlayer(label, container)
        local render = container:FindFirstChild("PlayerRender", true)
        if render and render:IsA("ImageLabel") and render.Image then
            local userId = string.match(render.Image, "id=(%d+)")
            if userId then
                local plr = Players:GetPlayerByUserId(tonumber(userId))
                if plr then return plr end
            end
        end
        local text = label.Text
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
                return plr
            end
        end
    end

    local function handleLabel(label)
        if not (label:IsA("TextLabel") and label.Name == "PlayerName") then return end
        task.spawn(function()
            local container = label.Parent
            for _ = 1, 3 do
                if container and container.Parent then
                    container = container.Parent
                end
            end
            if not container or not container:IsA("Frame") then return end
            
            local playerFound = findPlayer(label, container)
            if not playerFound then
                task.wait(0.5)
                playerFound = findPlayer(label, container)
            end
            if not playerFound then return end
            
            container.Name = playerFound.Name
            local card = container:FindFirstChild("1") and container["1"]:FindFirstChild("MatchDraftPlayerCard")
            if not card then return end
            
            local icon = card:FindFirstChild("AeroV4KitRender")  
            if not icon then
                icon = createkitrender(playerFound)
                icon.Parent = card
            end
            
            local loopKey = playerFound.UserId
            if activeLoops[loopKey] then
                activeLoops[loopKey] = nil
            end
            activeLoops[loopKey] = true
            task.spawn(function()
                while activeLoops[loopKey] and container and container.Parent and KitRender.Enabled do
                    local currentTick = tick()
                    
                    if not updateDebounce[loopKey] or (currentTick - updateDebounce[loopKey]) >= 0.3 then
                        updateDebounce[loopKey] = currentTick
                        
                        local updatedPlayer = findPlayer(label, container)
                        if updatedPlayer and updatedPlayer ~= playerFound then
                            playerFound = updatedPlayer
                        end
                        
                        if playerFound and icon and icon.Parent then
                            refreshicon(icon, playerFound)
                        end
                    end
                    
                    task.wait(0.3)  
                end
                
                activeLoops[loopKey] = nil
                updateDebounce[loopKey] = nil
            end)
        end)
    end

    local function setupKitRender()
        local success, team2 = pcall(function()
            return PlayerGui:FindFirstChild("MatchDraftApp") and
                   PlayerGui.MatchDraftApp:FindFirstChild("DraftAppBackground") and
                   PlayerGui.MatchDraftApp.DraftAppBackground:FindFirstChild("BodyContainer") and
                   PlayerGui.MatchDraftApp.DraftAppBackground.BodyContainer:FindFirstChild("Team2Column")
        end)
        
        if not success or not team2 then 
            return false 
        end
        
        for _, child in ipairs(team2:GetDescendants()) do
            if KitRender.Enabled then handleLabel(child) end
        end
        
        KitRender:Clean(team2.DescendantAdded:Connect(function(child)
            if KitRender.Enabled then handleLabel(child) end
        end))
        
        return true
    end

    KitRender = vape.Categories.Utility:CreateModule({
        Name = "KitRender (5v5)",
        Tooltip = "Allows you to see everyone's kit during kit phase (5v5, Ranked)",
        Function = function(callback)    
            if callback then
                local success = setupKitRender()
                
                if not success then
                    retryThread = task.spawn(function()
                        while KitRender.Enabled do
                            task.wait(1)
                            if setupKitRender() then
                                break
                            end
                        end
                    end)
                end
            else
                removeallkitrenders()
            end
        end
    })
end)

run(function()
    local activeConnections = {}
    local kitLabels = {}
    local updateDebounce = {}
    local retryThread = nil
    local playerMonitorThread = nil
    local processedPlayers = {}
    
    KitRender = vape.Categories.Utility:CreateModule({
        Name = "KitRender (squads)",
        Function = function(callback)   
            if callback then
                local function createKitLabel(parent, kitImage)
                    if kitLabels[parent] then
                        kitLabels[parent]:Destroy()
                    end
                    
                    local kitLabel = Instance.new("ImageLabel")
                    kitLabel.Name = "AeroV4KitIcon"
                    kitLabel.Size = UDim2.new(1, 0, 1, 0)
                    kitLabel.Position = UDim2.new(1.1, 0, 0, 0)
                    kitLabel.BackgroundTransparency = 1
                    kitLabel.Image = kitImage
                    kitLabel.Parent = parent
                    
                    kitLabels[parent] = kitLabel
                    return kitLabel
                end
                
                local function setupKitRender(obj)
                    if obj.Name == "PlayerRender" and obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Parent and obj.Parent.Parent.Parent.Parent and obj.Parent.Parent.Parent.Parent.Parent and obj.Parent.Parent.Parent.Parent.Parent.Name == "MatchDraftTeamCardRow" then
                        local Rank = obj.Parent:FindFirstChild('3')
                        if not Rank then return end
                        
                        local userId = string.match(obj.Image, "id=(%d+)")
                        if not userId then return end
                        
                        local id = tonumber(userId)
                        if not id then return end
                        
                        local plr = playersService:GetPlayerByUserId(id)
                        if not plr then return end
                        
                        local loopKey = plr.UserId
                        
                        processedPlayers[loopKey] = true
                        
                        if activeConnections[loopKey] then
                            activeConnections[loopKey]:Disconnect()
                            activeConnections[loopKey] = nil
                        end
                        
                        local function updateKit()
                            if not KitRender.Enabled then return end
                            if not Rank or not Rank.Parent then
                                if activeConnections[loopKey] then
                                    activeConnections[loopKey]:Disconnect()
                                    activeConnections[loopKey] = nil
                                end
                                if kitLabels[Rank] then
                                    kitLabels[Rank]:Destroy()
                                    kitLabels[Rank] = nil
                                end
                                return
                            end
                            
                            local kitName = plr:GetAttribute("PlayingAsKits")
                            if not kitName then
                                kitName = "none"
                            end
                            
                            local render = bedwars.BedwarsKitMeta[kitName] or bedwars.BedwarsKitMeta.none
                            
                            if kitLabels[Rank] then
                                kitLabels[Rank].Image = render.renderImage
                            else
                                createKitLabel(Rank, render.renderImage)
                            end
                        end
                        
                        updateKit()
                        
                        local connection = plr:GetAttributeChangedSignal("PlayingAsKits"):Connect(function()
                            local currentTick = tick()
                            
                            if not updateDebounce[loopKey] or (currentTick - updateDebounce[loopKey]) >= 0.1 then
                                updateDebounce[loopKey] = currentTick
                                updateKit()
                            end
                        end)
                        
                        activeConnections[loopKey] = connection
                        KitRender:Clean(connection)
                    end
                end
                
                local function setupSquadsRender()
                    local teams = lplr.PlayerGui:FindFirstChild("MatchDraftApp")
                    if not teams then
                        return false
                    end
                    
                    task.wait(0.5)
                    
                    for _, obj in teams:GetDescendants() do
                        if KitRender.Enabled then
                            task.spawn(function()
                                setupKitRender(obj)
                            end)
                        end
                    end
                    
                    KitRender:Clean(teams.DescendantAdded:Connect(function(obj)
                        if KitRender.Enabled then
                            task.wait(0.1)
                            setupKitRender(obj)
                        end
                    end))
                    
                    return true
                end
                
                playerMonitorThread = task.spawn(function()
                    while KitRender.Enabled do
                        task.wait(0.5)
                        
                        local teams = lplr.PlayerGui:FindFirstChild("MatchDraftApp")
                        if teams then
                            for _, obj in teams:GetDescendants() do
                                if obj.Name == "PlayerRender" and KitRender.Enabled then
                                    local userId = string.match(obj.Image, "id=(%d+)")
                                    if userId then
                                        local id = tonumber(userId)
                                        if id and not processedPlayers[id] then
                                            task.spawn(function()
                                                setupKitRender(obj)
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                task.spawn(function()
                    local success = setupSquadsRender()
                    
                    if not success then
                        retryThread = task.spawn(function()
                            while KitRender.Enabled do
                                task.wait(1)
                                if setupSquadsRender() then
                                    break
                                end
                            end
                        end)
                    end
                end)
            else
                if retryThread then
                    task.cancel(retryThread)
                    retryThread = nil
                end
                
                if playerMonitorThread then
                    task.cancel(playerMonitorThread)
                    playerMonitorThread = nil
                end
                
                for key, connection in pairs(activeConnections) do
                    if connection then
                        connection:Disconnect()
                    end
                    activeConnections[key] = nil
                end
                
                for parent, label in pairs(kitLabels) do
                    if label then
                        label:Destroy()
                    end
                    kitLabels[parent] = nil
                end
                
                table.clear(updateDebounce)
                table.clear(processedPlayers)
            end
        end,
        Tooltip = "Shows everyone's kit next to their rank during kit phase (squads ranked!)"
    })
end)
	
run(function()
	local Attack
	local Mine
	local Place
	local oldAttackReach, oldMineReach
	local oldIsAllowedPlacement

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				oldAttackReach = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
				
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockBreakController or not Reach.Enabled
					if not Reach.Enabled then return end
					
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							oldMineReach = oldMineReach or blockBreaker:getRange()
							blockBreaker:setRange(Mine.Value)
						end
					end)
				end)
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockEngine or not Reach.Enabled
					if not Reach.Enabled then return end
					
					pcall(function()
						if not oldIsAllowedPlacement then
							oldIsAllowedPlacement = bedwars.BlockEngine.isAllowedPlacement
							bedwars.BlockEngine.isAllowedPlacement = function(self, player, blockType, position, rotation, mouseBlockInfo)
								local result = oldIsAllowedPlacement(self, player, blockType, position, rotation, mouseBlockInfo)
								
								if not result and player == game.Players.LocalPlayer then
									local blockExists = self:getStore():getBlockAt(position)
									if not blockExists then
										return true 
									end
								end
								
								return result
							end
						end
					end)
				end)
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockPlacementController or not Reach.Enabled
					if not Reach.Enabled then return end
					
					pcall(function()
						local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
						if blockPlacer and blockPlacer.blockHighlighter then
							blockPlacer.blockHighlighter:setRange(Place.Value)
							blockPlacer.blockHighlighter.range = Place.Value
						end
					end)
				end)
				
				task.spawn(function()
					while Reach.Enabled do
						if bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
							bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
						end
						
						pcall(function()
							local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
							if blockBreaker and blockBreaker:getRange() ~= Mine.Value then
								blockBreaker:setRange(Mine.Value)
							end
						end)
						
						pcall(function()
							local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
							if blockPlacer and blockPlacer.blockHighlighter then
								if blockPlacer.blockHighlighter.range ~= Place.Value then
									blockPlacer.blockHighlighter:setRange(Place.Value)
									blockPlacer.blockHighlighter.range = Place.Value
								end
							end
						end)
						
						task.wait(0.5)
					end
				end)
			else
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
				
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(oldMineReach or 18)
					end
				end)
				
				pcall(function()
					local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
					if blockPlacer and blockPlacer.blockHighlighter then
						blockPlacer.blockHighlighter:setRange(18)
						blockPlacer.blockHighlighter.range = 18
					end
				end)
				
				if oldIsAllowedPlacement then
					pcall(function()
						bedwars.BlockEngine.isAllowedPlacement = oldIsAllowedPlacement
					end)
				end
				
				oldAttackReach, oldMineReach, oldIsAllowedPlacement = nil, nil, nil
			end
		end,
		Tooltip = 'Extends reach for attacking, mining, and placing blocks'
	})
	
	Attack = Reach:CreateSlider({
		Name = 'Attack Range',
		Min = 0,
		Max = 20,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	Mine = Reach:CreateSlider({
		Name = 'Mine Range',
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(val)
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	Place = Reach:CreateSlider({
		Name = 'Place Range',
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
					if blockPlacer and blockPlacer.blockHighlighter then
						blockPlacer.blockHighlighter:setRange(val)
						blockPlacer.blockHighlighter.range = val
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
					
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
run(function()
    local FastBreak
    local Time
    local BedCheck
    local Blacklist
    local blocks
    local string_lower = string.lower
    local string_find = string.find
    local task_wait = task.wait
    local collectionService = collectionService
    local currentBlock = nil
    local oldHitBlock = nil
    local bedCache = {}
    local blacklistCache = {}
    local lastCacheClean = 0
    local cacheCleanInterval = 5 
    
    local function isBed(block)
        if not block then return false end
        local cached = bedCache[block]
        if cached ~= nil then return cached end
        
        local result = false
        pcall(function()
            if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
                result = true
            elseif string_find(string_lower(block.Name), 'bed', 1, true) then
                result = true
            end
        end)
        
        bedCache[block] = result
        return result
    end
    
    local cachedBlacklistLower = {}
    local function updateBlacklistCache()
        if not blocks or not blocks.ListEnabled then return end
        
        cachedBlacklistLower = {}
        for _, v in pairs(blocks.ListEnabled) do
            table.insert(cachedBlacklistLower, string_lower(v))
        end
    end
    
    local function isBlacklisted(block)
        if not block or #cachedBlacklistLower == 0 then return false end
        local cached = blacklistCache[block]
        if cached ~= nil then return cached end
        
        local name = string_lower(block.Name)
        local result = false
        for i = 1, #cachedBlacklistLower do
            if string_find(name, cachedBlacklistLower[i], 1, true) then
                result = true
                break
            end
        end
        
        blacklistCache[block] = result
        return result
    end
    
    local function shouldSkip(block)
        if not block then return false end
        if BedCheck and BedCheck.Enabled and isBed(block) then return true end
        if Blacklist and Blacklist.Enabled and isBlacklisted(block) then return true end
        return false
    end
    
    local lastBreakUpdate = 0
    local breakUpdateCooldown = 0.05
    local pendingUpdate = false
    
    local function updateBreakSpeed()
        if not FastBreak or not FastBreak.Enabled then return end
        local now = tick()
        if now - lastBreakUpdate < breakUpdateCooldown then
            pendingUpdate = true
            return
        end
        lastBreakUpdate = now
        pendingUpdate = false
        
        pcall(function()
            local cooldown = (shouldSkip(currentBlock)) and 0.3 or Time.Value
            bedwars.BlockBreakController.blockBreaker:setCooldown(cooldown)
        end)
    end
    
    FastBreak = vape.Categories.Blatant:CreateModule({
        Name = 'FastBreak',
        Function = function(callback)
            if callback then
                oldHitBlock = bedwars.BlockBreaker.hitBlock
				local lastHotbarSlot = nil

				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = nil
					pcall(function()
						local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
							block = blockInfo.target.blockInstance
						end
					end)
					
					local currentSlot = store.inventory and store.inventory.hotbarSlot
					local slotChanged = currentSlot ~= lastHotbarSlot
					if slotChanged then
						lastHotbarSlot = currentSlot
					end

					if block ~= currentBlock or slotChanged then
						currentBlock = block
						updateBreakSpeed()
					end
					return oldHitBlock and oldHitBlock(self, maid, raycastparams, ...)
				end
                
                updateBlacklistCache()
                
                task.spawn(function()
                    while FastBreak.Enabled do
                        if tick() - lastCacheClean > cacheCleanInterval then
                            lastCacheClean = tick()
                            bedCache = {}
                            blacklistCache = {}
                        end
                        if pendingUpdate then updateBreakSpeed() end
                        task_wait(0.5) 
                    end
                end)
			else
				pcall(function() bedwars.BlockBreakController.blockBreaker:setCooldown(0.3) end)
				if oldHitBlock then
					bedwars.BlockBreaker.hitBlock = oldHitBlock
					oldHitBlock = nil
				end
				currentBlock = nil
				lastHotbarSlot = nil
				bedCache, blacklistCache, cachedBlacklistLower = {}, {}, {}
			end
        end,
        Tooltip = 'Decreases block hit cooldown'
    })
    
    Time = FastBreak:CreateSlider({
        Name = 'Break speed',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds',
        Function = function() updateBreakSpeed() end
    })
    
    BedCheck = FastBreak:CreateToggle({
        Name = 'Bed Check',
        Default = false,
        Tooltip = 'Use normal break speed when breaking beds',
        Function = function() bedCache = {}; updateBreakSpeed() end
    })
    
    Blacklist = FastBreak:CreateToggle({
        Name = 'Blacklist Blocks',
        Default = false,
        Tooltip = 'Use normal break speed on blacklisted blocks',
        Function = function(v)
            if blocks then blocks.Object.Visible = v end
            blacklistCache = {}
            if v then updateBlacklistCache() end
            updateBreakSpeed()
        end
    })
    
    blocks = FastBreak:CreateTextList({
        Name = 'Blacklisted Blocks',
        Placeholder = 'bed',
        Visible = false,
        Function = function()
            updateBlacklistCache()
            blacklistCache = {}
            updateBreakSpeed()
        end
    })

    task.defer(function()
        if blocks and blocks.Object then
            blocks.Object.Visible = false  
        end
    end)
end)
	
run(function()
    local Mode
    local Expand
    local AutoToggle
    local Visible
    local VisibleColor
    local Targets
    local objects, set = {}, {}
    local lastHoldingSword = false
    local autoToggleConnection = nil
    local manuallyDisabled = false

    local tick = tick
    local task_wait = task.wait
    local vector3new = Vector3.new
    local vector3one = Vector3.one

    local colorList = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 140, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        White = Color3.fromRGB(255, 255, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Pink = Color3.fromRGB(255, 50, 150),
        Black = Color3.fromRGB(0, 0, 0)
    }

    local function shouldCreateHitbox(ent)
        if not ent.Targetable then return false end
        if ent.Player and Targets and Targets.Players and Targets.Players.Enabled then return true end
        if not ent.Player and Targets and Targets.NPCs and Targets.NPCs.Enabled then return true end
        return false
    end

    local function isTargetBehindWall(ent)
        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return false end
        if not ent.RootPart then return false end
        local origin = entitylib.character.RootPart.Position
        local target = ent.RootPart.Position
        local direction = target - origin
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {entitylib.character, ent.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(origin, direction, rayParams)
        if result then
            local hitDist = (result.Position - origin).Magnitude
            local targetDist = direction.Magnitude
            if hitDist < targetDist - 0.5 then
                return true
            end
        end
        return false
    end

    local cachedExpandSize = vector3new(3, 6, 3)
    local lastExpandValue = 0
    local function updateExpandSize(val)
        if val ~= lastExpandValue then
            lastExpandValue = val
            cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
        end
    end

    local function createHitbox(ent)
        if not shouldCreateHitbox(ent) then return end
        if isTargetBehindWall(ent) then return end
        if objects[ent] then return end
        local hitbox = Instance.new('Part')
        hitbox.Size = cachedExpandSize
        hitbox.Position = ent.RootPart.Position
        hitbox.CanCollide = false
        hitbox.Massless = true
        hitbox.Transparency = Visible and Visible.Enabled and 0.5 or 1
        if Visible and Visible.Enabled and VisibleColor then
            hitbox.Color = colorList[VisibleColor.Value] or colorList.Red
        end
        hitbox.Parent = ent.Character
        local weld = Instance.new('Motor6D')
        weld.Part0 = hitbox
        weld.Part1 = ent.RootPart
        weld.Parent = hitbox
        objects[ent] = hitbox
    end

    local lastAutoToggleTime = 0
    local autoToggleCooldown = 0.1
    local function handleAutoToggle()
        if not AutoToggle.Enabled or Mode.Value ~= 'Player' then return end
        local now = tick()
        if now - lastAutoToggleTime < autoToggleCooldown then return end
        local holdingSword = isSword()
        if holdingSword ~= lastHoldingSword then
            lastHoldingSword = holdingSword
            lastAutoToggleTime = now
            if holdingSword then
                if not HitBoxes.Enabled and not manuallyDisabled then
                    HitBoxes:Toggle()
                end
            else
                if HitBoxes.Enabled then
                    manuallyDisabled = false
                    HitBoxes:Toggle()
                end
            end
        end
    end

    local function refreshAllHitboxes()
        for ent, part in pairs(objects) do
            part:Destroy()
        end
        table.clear(objects)
        local entityList = entitylib.List
        for i = 1, #entityList do
            createHitbox(entityList[i])
        end
    end

    HitBoxes = vape.Categories.Blatant:CreateModule({
        Name = 'HitBoxes',
        Function = function(callback)
            if callback then
                manuallyDisabled = false
                updateExpandSize(Expand.Value)
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                        createHitbox(ent)
                    end))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        local obj = objects[ent]
                        if obj then
                            obj:Destroy()
                            objects[ent] = nil
                        end
                    end))
                    refreshAllHitboxes()
					local hitboxThrottleCounter = 0
					HitBoxes:Clean(runService.Heartbeat:Connect(function()
						if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return end
						hitboxThrottleCounter = hitboxThrottleCounter + 1
						if hitboxThrottleCounter % 6 ~= 0 then return end 
						for ent, part in pairs(objects) do
							if isTargetBehindWall(ent) then
								part:Destroy()
								objects[ent] = nil
							end
						end
						local entityList = entitylib.List
						for i = 1, #entityList do
							local ent = entityList[i]
							if not objects[ent] then
								createHitbox(ent)
							end
						end
					end))
                end
            else
                if AutoToggle.Enabled and isSword() then
                    manuallyDisabled = true
                end
                if set then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                    set = nil
                end
                for _, part in pairs(objects) do
                    part:Destroy()
                end
                table.clear(objects)
                if not AutoToggle.Enabled then
                    lastHoldingSword = false
                end
            end
        end,
        Tooltip = 'Expands attack hitbox'
    })

	Targets = HitBoxes:CreateTargets({
		Players = true,
		Walls = false,
		NPCs = false,
		Function = function()
			if HitBoxes.Enabled and Mode.Value == 'Player' then
				refreshAllHitboxes()
			end
		end
	})

    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function(val)
            local isPlayer = val == 'Player'
            if AutoToggle then AutoToggle.Object.Visible = isPlayer end
            if Visible then Visible.Object.Visible = isPlayer end
            if VisibleColor then VisibleColor.Object.Visible = isPlayer and Visible.Enabled end
            if HitBoxes.Enabled then
                HitBoxes:Toggle()
                HitBoxes:Toggle()
            end
        end,
        Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
    })

    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 50,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            updateExpandSize(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
                else
                    for _, part in pairs(objects) do
                        part.Size = cachedExpandSize
                    end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    local autoToggleFrameCounter = 0
    AutoToggle = HitBoxes:CreateToggle({
        Name = 'Auto Toggle',
        Default = false,
        Tooltip = 'Automatically enables hitbox when holding a sword',
        Function = function(callback)
            if callback then
                if autoToggleConnection then autoToggleConnection:Disconnect() end
                lastHoldingSword = false
                autoToggleFrameCounter = 0
                autoToggleConnection = runService.Heartbeat:Connect(function()
                    autoToggleFrameCounter = autoToggleFrameCounter + 1
                    if autoToggleFrameCounter % 5 == 0 then
                        handleAutoToggle()
                    end
                end)
                handleAutoToggle()
            else
                if autoToggleConnection then
                    autoToggleConnection:Disconnect()
                    autoToggleConnection = nil
                end
                lastHoldingSword = false
            end
        end
    })

    Visible = HitBoxes:CreateToggle({
        Name = 'Visible',
        Default = false,
        Tooltip = 'Makes the hitbox visible on screen',
        Function = function(callback)
            if VisibleColor then VisibleColor.Object.Visible = callback end
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                local transparency = callback and 0.5 or 1
                local col = callback and VisibleColor and (colorList[VisibleColor.Value] or colorList.Red) or nil
                for _, part in pairs(objects) do
                    part.Transparency = transparency
                    if col then part.Color = col end
                end
            end
        end
    })

    VisibleColor = HitBoxes:CreateDropdown({
        Name = 'Hitbox Color',
        List = {'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'White', 'Cyan', 'Pink', 'Black'},
        Default = 'Red',
        Visible = false,
        Tooltip = 'Color of the visible hitbox',
        Function = function(val)
            if HitBoxes.Enabled and Mode.Value == 'Player' and Visible.Enabled then
                local col = colorList[val] or colorList.Red
                for _, part in pairs(objects) do
                    part.Color = col
                end
            end
        end
    })

    task.spawn(function()
        repeat task_wait() until Mode and Mode.Value
        local isPlayer = Mode.Value == 'Player'
        AutoToggle.Object.Visible = isPlayer
        Visible.Object.Visible = isPlayer
    end)

    task.defer(function()
        if VisibleColor and VisibleColor.Object then
            VisibleColor.Object.Visible = false
        end
    end)
end)
	
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)

-- aero killaura 
local Attacking
run(function()
    local Killaura
    local Targets
    local Sort
    local SwingRange
    local AttackRange
    local RangeCircle
    local RangeCirclePart
    local UpdateRate
    local AngleSlider
    local MaxTargets
    local Mouse
    local Swing
    local GUI
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
    local LegitAura
    local SyncHits
    local lastAttackTime = 0
    local lastManualSwing = 0
    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0
    local SophiaCheck
    local FROZEN_THRESHOLD = 10
    local SwingTime
    local SwingTimeSlider
    local swingCooldown = 0
    local ContinueSwinging
    local ContinueSwingTime
    local lastTargetTime = 0
    local continueSwingCount = 0
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote
    local TargetPriority
    local CustomHitReg
    local CustomHitRegSlider
    local lastCustomHitTime = 0
    local AirHit
    local AirHitsChance
    local CanHit = true
    
    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity)
    end)

    local function isFrozen()
        if not entitylib.isAlive then return false end
        local char = entitylib.character.Character
        if char:GetAttribute("StatusEffect_frozen") then
            return true
        end
        local hasIceBlock = char:FindFirstChild("IceBlock") or 
                        char:FindFirstChild("FrozenBlock") or 
                        char:FindFirstChild("IceShell")
        
        if hasIceBlock then
            return true
        end
        return false
    end

    local function optimizeHitData(selfpos, targetpos, delta)
        local direction = (targetpos - selfpos).Unit
        local distance = (selfpos - targetpos).Magnitude
        local optimizedSelfPos = selfpos
        local optimizedTargetPos = targetpos
        if distance > 18 then
            optimizedSelfPos = selfpos + (direction * 2.2)
            optimizedTargetPos = targetpos - (direction * 0.5)
        elseif distance > 14.4 then
            optimizedSelfPos = selfpos + (direction * 1.8)
            optimizedTargetPos = targetpos - (direction * 0.3)
        elseif distance > 10 then
            optimizedSelfPos = selfpos + (direction * 1.2)
        else
            optimizedSelfPos = selfpos + (direction * 0.6)
        end
        optimizedSelfPos = optimizedSelfPos + Vector3.new(0, 0.8, 0)
        optimizedTargetPos = optimizedTargetPos + Vector3.new(0, 1.2, 0)
        return optimizedSelfPos, optimizedTargetPos, direction
    end

    local function getOptimizedAttackTiming()
        local currentTime = tick()
        local baseDelay = 0.11 
        
        if currentTime - lastAttackTime < baseDelay then
            return false
        end
        
        return true
    end

	local function canHitWithCustomReg()
		if not CustomHitReg.Enabled then return true end
		
		local currentTime = tick()
		local targetHitsIn10Sec = CustomHitRegSlider.Value
		
		if targetHitsIn10Sec >= 35 and targetHitsIn10Sec <= 36 then
			return true
		end
		
		local delayBetweenHits = (10 / targetHitsIn10Sec) * 0.98
		
		if currentTime - lastCustomHitTime >= delayBetweenHits then
			lastCustomHitTime = currentTime
			return true
		end
		
		return false
	end

    local function FireAttackRemote(attackTable, ...)
        if not AttackRemote then return end
        if not canHitWithCustomReg() then return end

        local suc, plr = pcall(function()
            return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
        end)

        local selfpos = attackTable.validate.selfPosition.value
        local targetpos = attackTable.validate.targetPosition.value
        local actualDistance = (selfpos - targetpos).Magnitude

        store.attackReach = (actualDistance * 100) // 1 / 100
        store.attackReachUpdate = tick() + 1

        if actualDistance > 14.4 and actualDistance <= 30 then
            local direction = (targetpos - selfpos).Unit
            
            local moveDistance = math.min(actualDistance - 14.3, 8) 
            attackTable.validate.selfPosition.value = selfpos + (direction * moveDistance)
            
            local pullDistance = math.min(actualDistance - 14.3, 4)
            attackTable.validate.targetPosition.value = targetpos - (direction * pullDistance)
            
            attackTable.validate.raycast = attackTable.validate.raycast or {}
            attackTable.validate.raycast.cameraPosition = attackTable.validate.raycast.cameraPosition or {}
            attackTable.validate.raycast.cursorDirection = attackTable.validate.raycast.cursorDirection or {}
            
            local extendedOrigin = selfpos + (direction * math.min(actualDistance - 12, 15))
            attackTable.validate.raycast.cameraPosition.value = extendedOrigin
            attackTable.validate.raycast.cursorDirection.value = direction
            
            attackTable.validate.targetPosition = attackTable.validate.targetPosition or {value = targetpos}
            attackTable.validate.selfPosition = attackTable.validate.selfPosition or {value = selfpos}
        end

        if suc and plr then
            if not select(2, whitelist:get(plr)) then return end
        end

        return AttackRemote:SendToServer(attackTable, ...)
    end

    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0

    local function createRangeCircle()
        local suc, err = pcall(function()
            if (not shared.CheatEngineMode) then
                RangeCirclePart = Instance.new("MeshPart")
                RangeCirclePart.MeshId = "rbxassetid://3726303797"
                if shared.RiseMode and GuiLibrary.GUICoreColor and GuiLibrary.GUICoreColorChanged then
                    RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    GuiLibrary.GUICoreColorChanged.Event:Connect(function()
                        RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    end)
                else
                    RangeCirclePart.Color = Color3.fromHSV(BoxSwingColor["Hue"], BoxSwingColor["Sat"], BoxSwingColor.Value)
                end
                RangeCirclePart.CanCollide = false
                RangeCirclePart.Anchored = true
                RangeCirclePart.Material = Enum.Material.Neon
                RangeCirclePart.Size = Vector3.new(SwingRange.Value * 0.7, 0.01, SwingRange.Value * 0.7)
                if Killaura.Enabled then
                    RangeCirclePart.Parent = gameCamera
                end
                RangeCirclePart:SetAttribute("gamecore_GameQueryIgnore", true)
            end
        end)
        if (not suc) then
            pcall(function()
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
                notif("Killaura - Range Visualiser Circle", "There was an error creating the circle. Disabling...", 2)
            end)
        end
    end

    local function getAttackData()
        if SophiaCheck and SophiaCheck.Enabled then
            if isFrozen() then
                return false
            end
        end

        if Mouse.Enabled then
            local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            if not mousePressed then 
                return false 
            end
        end

        if GUI.Enabled then
            if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        end

        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end

        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end

		if LegitAura.Enabled then
			local lastSwing = bedwars.SwordController.lastSwing or 0
			local swingDelay = SwingTime.Enabled and SwingTimeSlider.Value or 0.2
			if (tick() - lastSwing) > swingDelay then return false end
		end

        if SwingTime.Enabled then
            local swingSpeed = SwingTimeSlider.Value
            return sword, meta, (tick() - lastAttackTime) >= swingSpeed
        else
            return sword, meta, true
        end
    end
    
    local function resetSwordCooldown()
        if bedwars.SwordController then
            bedwars.SwordController.lastAttack = 0
            bedwars.SwordController.lastSwing = 0
            
            if bedwars.SwordController.lastChargedAttackTimeMap then
                for weaponName, _ in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
                    bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
                end
            end
        end
    end

    local function shouldContinueSwinging()
        if not ContinueSwinging.Enabled then return false end
        
        if lastTargetTime == 0 then
            return false
        end
        
        local timeSinceLastTarget = tick() - lastTargetTime
        local swingDuration = ContinueSwingTime.Value
        
        if timeSinceLastTarget <= swingDuration then
            return true
        end
        
        return false
    end

    local preserveSwordIcon = false
    local sigridcheck = false

    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            
            if callback then
                
                lastSwingServerTime = Workspace:GetServerTimeNow()
                lastSwingServerTimeDelta = 0
                lastAttackTime = 0
                swingCooldown = 0
                resetSwordCooldown() 
                lastTargetTime = 0 
                continueSwingCount = 0

                if RangeCircle.Enabled then
                    createRangeCircle()
                end
                if inputService.TouchEnabled and not preserveSwordIcon then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
                    end)
                end

                if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    local args = {...}
                                    if not Attacking then
                                        pcall(function()
                                            bedwars.ViewmodelController:playAnimation(select(2, unpack(args)))
                                        end)
                                    end
                                end
                            }
                        }
                    }

                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true

                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end

                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end

                            if not started then
                                task.wait(1 / UpdateRate.Value)
                            end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end

                repeat
                    if SophiaCheck and SophiaCheck.Enabled then
                        if isFrozen() then
                            Attacking = false
                            store.KillauraTarget = nil
                            task.wait(0.3)
                            continue
                        end
                    end
                    
                    pcall(function()
                        if entitylib.isAlive and entitylib.character.HumanoidRootPart then
                            TweenService:Create(RangeCirclePart, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = entitylib.character.HumanoidRootPart.Position - Vector3.new(0, entitylib.character.Humanoid.HipHeight, 0)}):Play()
                        end
                    end)

                    local attacked, sword, meta, canAttack = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
                    pcall(function() vapeTargetInfo.Targets.Killaura = nil end)

                    if sword and canAttack then
                        if sigridcheck and entitylib.isAlive and lplr.Character:FindFirstChild("elk") then return end
                        local isClaw = string.find(string.lower(tostring(sword and sword.itemType or "")), "summoner_claw")
                        
                        local selfpos = entitylib.character.RootPart.Position
                        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                        local maxAngle = math.rad(AngleSlider.Value) / 2
                        local allSwingTargets = {}
                        local allAttackTargets = {}

                        if Targets.Players.Enabled then
                            local playerTargets = entitylib.AllPosition({
                                Range = SwingRange.Value,
                                Wallcheck = false,
                                Part = 'RootPart',
                                Players = true,
                                NPCs = false,
                                Limit = MaxTargets.Value,
                                Sort = sortmethods[Sort.Value]
                            })
                            for _, v in playerTargets do
                                table.insert(allSwingTargets, {entity = v, isPlayer = true})
                            end
                        end

                        if Targets.NPCs.Enabled then
                            local npcTargets = entitylib.AllPosition({
                                Range = SwingRange.Value,
                                Wallcheck = false,
                                Part = 'RootPart',
                                Players = false,
                                NPCs = true,
                                Limit = MaxTargets.Value,
                                Sort = sortmethods[Sort.Value]
                            })
                            for _, v in npcTargets do
                                table.insert(allSwingTargets, {entity = v, isPlayer = false})
                            end
                        end

                        if TargetPriority.Value == 'Players First' then
                            table.sort(allSwingTargets, function(a, b)
                                if a.isPlayer ~= b.isPlayer then
                                    return a.isPlayer
                                end
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        elseif TargetPriority.Value == 'NPCs First' then
                            table.sort(allSwingTargets, function(a, b)
                                if a.isPlayer ~= b.isPlayer then
                                    return not a.isPlayer
                                end
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        else
                            table.sort(allSwingTargets, function(a, b)
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        end

                        local swingPlrs = {}
                        for i = 1, math.min(#allSwingTargets, MaxTargets.Value) do
                            table.insert(swingPlrs, allSwingTargets[i].entity)
                        end

                        if Targets.Players.Enabled then
                            local playerTargets = entitylib.AllPosition({
                                Range = SwingRange.Value,
                                Wallcheck = Targets.Walls.Enabled or nil,
                                Part = 'RootPart',
                                Players = true,
                                NPCs = false,
                                Limit = MaxTargets.Value,
                                Sort = sortmethods[Sort.Value]
                            })
                            for _, v in playerTargets do
                                table.insert(allAttackTargets, {entity = v, isPlayer = true})
                            end
                        end

                        if Targets.NPCs.Enabled then
                            local npcTargets = entitylib.AllPosition({
                                Range = SwingRange.Value,
                                Wallcheck = Targets.Walls.Enabled or nil,
                                Part = 'RootPart',
                                Players = false,
                                NPCs = true,
                                Limit = MaxTargets.Value,
                                Sort = sortmethods[Sort.Value]
                            })
                            for _, v in npcTargets do
                                table.insert(allAttackTargets, {entity = v, isPlayer = false})
                            end
                        end

                        if TargetPriority.Value == 'Players First' then
                            table.sort(allAttackTargets, function(a, b)
                                if a.isPlayer ~= b.isPlayer then
                                    return a.isPlayer
                                end
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        elseif TargetPriority.Value == 'NPCs First' then
                            table.sort(allAttackTargets, function(a, b)
                                if a.isPlayer ~= b.isPlayer then
                                    return not a.isPlayer
                                end
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        else
                            table.sort(allAttackTargets, function(a, b)
                                return (a.entity.RootPart.Position - selfpos).Magnitude < (b.entity.RootPart.Position - selfpos).Magnitude
                            end)
                        end

                        local attackPlrs = {}
                        for i = 1, math.min(#allAttackTargets, MaxTargets.Value) do
                            table.insert(attackPlrs, allAttackTargets[i].entity)
                        end
                        
                        local hasValidSwingTargets = false
                        local hasValidAttackTargets = false
                        
                        for _, v in swingPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                            if angle <= maxAngle then
                                hasValidSwingTargets = true
                                break
                            end
                        end
                        
                        for _, v in attackPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                            if angle <= maxAngle then  
                                hasValidAttackTargets = true
                                break
                            end
                        end
                        
                        if hasValidSwingTargets or hasValidAttackTargets then
                            lastTargetTime = tick()
                        end
                        
                        local shouldSwing = hasValidSwingTargets or hasValidAttackTargets or shouldContinueSwinging()
                        
                        if shouldSwing then
                            switchItem(sword.tool, 0)
                            
                            if hasValidAttackTargets then
                                for _, v in attackPlrs do
                                    local delta = (v.RootPart.Position - selfpos)
                                    local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                    local swingAngle = math.rad(AngleSlider.Value)
                                    if angle > (swingAngle / 2) then continue end

                                    table.insert(attacked, {
                                        Entity = v,
                                        Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                                    })
                                    targetinfo.Targets[v] = tick() + 1
                                    pcall(function()
                                        local plr = v
                                        vapeTargetInfo.Targets.Killaura = {
                                            Humanoid = {
                                                Health = (plr.Character:GetAttribute("Health") or plr.Humanoid.Health) + getShieldAttribute(plr.Character),
                                                MaxHealth = plr.Character:GetAttribute("MaxHealth") or plr.Humanoid.MaxHealth
                                            },
                                            Player = plr.Player
                                        }
                                    end)
                                    if not Attacking then
                                        Attacking = true
                                        store.KillauraTarget = v
                                        if not isClaw then
                                            if not Swing.Enabled and AnimDelay <= tick() and not LegitAura.Enabled then
                                                local swingSpeed = 0.25
                                                if SwingTime.Enabled then
                                                    swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                                elseif meta.sword.respectAttackSpeedForEffects then
                                                    swingSpeed = meta.sword.attackSpeed
                                                end
                                                AnimDelay = tick() + swingSpeed
                                                bedwars.SwordController:playSwordEffect(meta, false)
                                                if meta.displayName:find(' Scythe') then
                                                    bedwars.ScytheController:playLocalAnimation()
                                                end

												if vape.ThreadFix then
													setthreadidentity(8)
													task.defer(function()
														setthreadidentity(2)
													end)
												end
                                            end
                                        end
                                    end

									local canHit = delta.Magnitude <= AttackRange.Value
									local extendedRangeCheck = delta.Magnitude <= (AttackRange.Value + 2) 

									if not canHit and not extendedRangeCheck then continue end

                                    if AirHit.Enabled then
                                        local chance = math.random(0, 100)
                                        local state = v.Character.Humanoid:GetState()
                                        if state == Enum.HumanoidStateType.Jumping then
                                            if chance > AirHitsChance.Value then 
                                                CanHit = false
                                                continue
                                            else
                                                CanHit = true
                                            end
                                        elseif state == Enum.HumanoidStateType.Freefall then
                                            if chance > AirHitsChance.Value then
                                                CanHit = false 
                                                continue 
                                            else
                                                CanHit = true
                                            end
                                        else
                                            CanHit = true
                                        end
                                    else
                                        CanHit = true
                                    end

                                    if not CanHit then continue end

                                    if SyncHits.Enabled then
                                        local swingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                        if (tick() - swingCooldown) < (swingSpeed * 0.7) then 
                                            continue 
                                        end
                                     local timeSinceLastSwing = tick() - swingCooldown
                                        local requiredDelay = math.max(swingSpeed * 0.8, 0.1) 
                                        
                                        if timeSinceLastSwing < requiredDelay then 
                                            continue 
                                        end
                                    end

                                    local actualRoot = v.Character.PrimaryPart
                                    if actualRoot then
                                        local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector

                                        local pos = selfpos
                                        local targetPos = actualRoot.Position

                                        if not SyncHits.Enabled or (tick() - swingCooldown) >= 0.1 then
                                            swingCooldown = tick()
                                        end
                                        lastSwingServerTimeDelta = workspace:GetServerTimeNow() - lastSwingServerTime
                                        lastSwingServerTime = workspace:GetServerTimeNow()

                                        store.attackReach = (delta.Magnitude * 100) // 1 / 100
                                        store.attackReachUpdate = tick() + 1

                                        if SwingTime.Enabled then
                                            lastAttackTime = tick()

                                            if delta.Magnitude < 14.4 and SwingTimeSlider.Value > 0.11 then
                                                AnimDelay = tick()
                                            end
                                        end

                                        if isClaw then
                                            KaidaController:request(v.Character)
                                        else
                                            local attackData = {
                                                weapon = sword.tool,
                                                entityInstance = v.Character,
                                                chargedAttack = {chargeRatio = 0},
                                                validate = {
                                                    raycast = {
                                                        cameraPosition = {value = pos + Vector3.new(0, 2, 0)},
                                                        cursorDirection = {value = dir}
                                                    },
                                                    targetPosition = {value = targetPos},
                                                    selfPosition = {value = pos + Vector3.new(0, 1, 0)}
                                                }
                                            }
                                            
                                            attackData.validate = attackData.validate or {}
                                            attackData.validate.raycast = attackData.validate.raycast or {}
                                            attackData.validate.targetPosition = attackData.validate.targetPosition or {value = targetPos}
                                            attackData.validate.selfPosition = attackData.validate.selfPosition or {value = pos}
                                            
                                            attackData.validate.raycast.cameraPosition = attackData.validate.raycast.cameraPosition or {value = pos}
                                            attackData.validate.raycast.cursorDirection = attackData.validate.raycast.cursorDirection or {value = dir}
                                            
                                            FireAttackRemote(attackData)
                                        end
                                    end
                                end
                            else
                                Attacking = true
                                if not isClaw then
                                    if not Swing.Enabled and AnimDelay <= tick() and not LegitAura.Enabled then
                                        local swingSpeed = 0.25
                                        if SwingTime.Enabled then
                                            swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                        elseif meta.sword.respectAttackSpeedForEffects then
                                            swingSpeed = meta.sword.attackSpeed
                                        end
                                        AnimDelay = tick() + swingSpeed
                                        bedwars.SwordController:playSwordEffect(meta, false)
                                        if meta.displayName:find(' Scythe') then
                                            bedwars.ScytheController:playLocalAnimation()
                                        end

										if vape.ThreadFix then
											setthreadidentity(8)
											task.defer(function()
												setthreadidentity(2)
											end)
										end
                                    end
                                end

                                local currentSwingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                local minSwingDelay = math.max(currentSwingSpeed, 0.05)
                                
                                if not SyncHits.Enabled or (tick() - swingCooldown) >= minSwingDelay then
                                    swingCooldown = tick()
                                end
                            end
                        end
                    end

                    pcall(function()
                        for i, v in Boxes do
                            v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                            if v.Adornee then
                                v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                v.Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end

                        for i, v in Particles do
                            v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                            v.Parent = attacked[i] and gameCamera or nil
                        end
                    end)

                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                    end
                    pcall(function() if RangeCirclePart ~= nil then RangeCirclePart.Parent = gameCamera end end)

                    task.wait(1 / UpdateRate.Value)
                until not Killaura.Enabled
            else
                
                lastTargetTime = 0
                continueSwingCount = 0
                
                store.KillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = true
                    end)
                end
                Attacking = false
				pcall(function()
					setthreadidentity(2)
				end)
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
                if RangeCirclePart ~= nil then RangeCirclePart:Destroy() end
            end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.'
    })

    pcall(function()
        local PSI = Killaura:CreateToggle({
            Name = 'Preserve Sword Icon',
            Function = function(callback)
                preserveSwordIcon = callback
            end,
            Default = true
        })
        PSI.Object.Visible = inputService.TouchEnabled
    end)

    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    
    TargetPriority = Killaura:CreateDropdown({
        Name = 'Target Priority',
        List = {'Players First', 'NPCs First', 'Distance'},
        Default = 'Players First',
        Tooltip = 'Choose which targets to prioritize'
    })
    
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    SwingRange = Killaura:CreateSlider({
        Name = 'Swing range',
        Min = 1,
        Max = 40, 
        Default = 22, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AttackRange = Killaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
        Max = 20,
        Default = 14, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    RangeCircle = Killaura:CreateToggle({
        Name = "Range Visualiser",
        Function = function(call)
            if call then
                createRangeCircle()
            else
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
            end
        end
    })
    AngleSlider = Killaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
    UpdateRate = Killaura:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 360,
        Default = 60,
        Suffix = 'hz'
    })
    MaxTargets = Killaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 8,
        Default = 5
    })
    Sort = Killaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    SwingTime = Killaura:CreateToggle({
        Name = 'Custom Swing Time',
        Function = function(callback)
            SwingTimeSlider.Object.Visible = callback
        end
    })
    SwingTimeSlider = Killaura:CreateSlider({
        Name = 'Swing Time',
        Min = 0,
        Max = 1,
        Default = 0.42,
        Decimal = 100,
        Visible = false
    })
    ContinueSwinging = Killaura:CreateToggle({
        Name = 'Continue Swinging',
        Tooltip = 'Swing X times after losing target (based on swing speed)',
        Function = function(callback)
            if ContinueSwingTime then
                ContinueSwingTime.Object.Visible = callback
            end
        end
    })
    ContinueSwingTime = Killaura:CreateSlider({
        Name = 'Swing Duration',
        Min = 0,  
        Max = 5,  
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })
    CustomHitReg = Killaura:CreateToggle({
        Name = 'Custom Hit Reg',
        Tooltip = 'Limit how many hits per second',
        Function = function(callback)
            if CustomHitRegSlider then
                CustomHitRegSlider.Object.Visible = callback
            end
            if callback then
                lastCustomHitTime = 0
            end
        end
    })
    
    CustomHitRegSlider = Killaura:CreateSlider({
        Name = 'Hits Per Second',
        Min = 1,
        Max = 36,
        Default = 30,
        Tooltip = 'Maximum hits per second',
        Visible = false
    })
    
    AirHit = Killaura:CreateToggle({
        Name = "Air Hits",
        Default = true,
        Tooltip = 'enables the air hits feature',
        Function = function(v)
            if AirHitsChance then
                AirHitsChance.Object.Visible = v
            end
        end
    })
    
    AirHitsChance = Killaura:CreateSlider({
        Name = 'Air Hits Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = "%",
        Decimal = 5,
        Tooltip = 'checks if it can hit someone when they are in the air',
        Darker = true,
        Visible = false
    })
    SyncHits = Killaura:CreateToggle({
        Name = 'Sync Hits',
        Tooltip = 'Waits for sword animation before attacking'
    })
    Killaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false,
        Function = function(hue, sat, val)
            if Killaura.Enabled and RangeCirclePart ~= nil then
                RangeCirclePart.Color = Color3.fromHSV(hue, sat, val)
            end
        end
    })
    BoxAttackColor = Killaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    Killaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = Killaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = Killaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = Killaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = Killaura:CreateToggle({Name = 'Face target'})
    Animation = Killaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if Killaura.Enabled then
                Killaura:Toggle()
                Killaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = Killaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = Killaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = Killaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Limit = Killaura:CreateToggle({
        Name = 'Limit to items',
        Function = function(callback)
            if inputService.TouchEnabled and Killaura.Enabled then
                pcall(function()
                    lplr.PlayerGui.MobileUI['2'].Visible = callback
                end)
            end
        end,
        Tooltip = 'Only attacks when the sword is held'
    })
    LegitAura = Killaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually'
    })
    Killaura:CreateToggle({
        Name = "Sigrid Check",
        Default = false,
        Function = function(call)
            sigridcheck = call
        end
    })
    SophiaCheck = Killaura:CreateToggle({
        Name = 'Sophia Check',
        Tooltip = 'Stops Killaura when frozen by Sophia',
        Default = false
    })
end)

-- granddad killaura
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura = {}
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'GrandKillaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, fake)
					debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				local swingCooldown = 0
				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or math.max(ChargeTime.Value, 0.11))
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end
								if delta.Magnitude < 14.4 and (tick() - swingCooldown) < math.max(ChargeTime.Value, 0.02) then continue end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									swingCooldown = tick()
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
										AnimDelay = tick()
									end

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										lastSwingServerTimeDelta = 0.5,
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					--#attacked > 0 and #attacked * 0.02 or
					task.wait(1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, bedwars.Knit)
				debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ChargeTime = Killaura:CreateSlider({
		Name = 'Swing time',
		Min = 0,
		Max = 0.5,
		Default = 0.42,
		Decimal = 100
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)
	
run(function()
    local NoFall
    local Mode
    local Chance
    local SpoofCap
    local DamageAccuracy
    local AutoToggle
    local HealthThreshold

    local rand = Random.new()
    local rayParams = RaycastParams.new()

    local BLOCKCAST_SIZE = Vector3.new(3, 3, 3)
    local activationCheck = 0
    local lastRNGValue = 100

    rayParams.CollisionGroup = "Default"

    local function canActivate()
        local now = tick()
        if now - activationCheck > 0.5 then
            activationCheck = now
            lastRNGValue = rand:NextNumber(0, 100)
        end
        if lastRNGValue > Chance.Value then return false end
        if not AutoToggle.Enabled then return true end
        local humanoid = entitylib.character and entitylib.character.Humanoid
        if not humanoid then return false end
        return humanoid.Health <= HealthThreshold.Value
    end

    local function runDamageAccuracyMode()
        local tracked = 0
        local extraGravity = 0
        NoFall:Clean(runService.PreSimulation:Connect(function(dt)
            if entitylib.isAlive then
                local root = store.rootpart or entitylib.character.RootPart
                local velocity = root.AssemblyLinearVelocity
                if velocity.Y < -85 then
                    rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                    rayParams.CollisionGroup = root.CollisionGroup
                    local rootSize = root.Size.Y / 2.5 + entitylib.character.HipHeight
                    local checkDistance = Vector3.new(0, (tracked * 0.1) - rootSize, 0)
                    local ray = workspace:Blockcast(root.CFrame, BLOCKCAST_SIZE, checkDistance, rayParams)
                    if not ray then
                        local Failed = rand:NextNumber(0, 100) < DamageAccuracy.Value
                        local velo = velocity.Y
                        if Failed then
                            root.AssemblyLinearVelocity = Vector3.new(velocity.X, velo + 0.5, velocity.Z)
                        else
                            root.AssemblyLinearVelocity = Vector3.new(velocity.X, -86, velocity.Z)
                        end
                        root.CFrame = root.CFrame + Vector3.new(0, (Failed and -extraGravity or extraGravity) * dt, 0)
                        extraGravity = extraGravity + (Failed and workspace.Gravity or -workspace.Gravity) * dt
                        tracked = velo
                    else
                        tracked = velocity.Y
                    end
                else
                    extraGravity = 0
                    tracked = 0
                end
            end
        end))
    end

    NoFall = vape.Categories.Blatant:CreateModule({
        Name = 'NoFall',
Function = function(callback)
            if callback then
                if Mode.Value == 'Spoof' then
                    local extraGravity = 0
                    NoFall:Clean(runService.PreSimulation:Connect(function(dt)
                        if not entitylib.isAlive then return end
                        local root = store.rootpart or entitylib.character.RootPart
                        local velocity = root.AssemblyLinearVelocity
                        if velocity.Y < -85 then
                            rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                            rayParams.CollisionGroup = root.CollisionGroup
                            local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                            local ray = workspace:Blockcast(root.CFrame, BLOCKCAST_SIZE, Vector3.new(0, (velocity.Y * 0.1) - rootSize, 0), rayParams)
                            if not ray then
                                root.AssemblyLinearVelocity = Vector3.new(velocity.X, -(SpoofCap.Value), velocity.Z)
                                root.CFrame += Vector3.new(0, extraGravity * dt, 0)
                                extraGravity += -workspace.Gravity * dt
                            end
                        else
                            extraGravity = 0
                        end
                    end))

                elseif Mode.Value == 'Gravity' then
                    local extraGravity = 0
                    local tracked = 0
                    NoFall:Clean(runService.PreSimulation:Connect(function(dt)
                        if not entitylib.isAlive then return end
                        local root = entitylib.character.RootPart
                        if root.AssemblyLinearVelocity.Y < -85 then
                            rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                            rayParams.CollisionGroup = root.CollisionGroup
                            local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                            local ray = workspace:Blockcast(root.CFrame, BLOCKCAST_SIZE, Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
                            if not ray then
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -86, root.AssemblyLinearVelocity.Z)
                                root.CFrame += Vector3.new(0, extraGravity * dt, 0)
                                extraGravity += -workspace.Gravity * dt
                            end
                        else
                            extraGravity = 0
                        end
                    end))

                elseif Mode.Value == 'Teleport' then
                    local active = true
                    NoFall:Clean(function() active = false end)
                    task.spawn(function()
                        local tracked = 0
                        repeat
                            if entitylib.isAlive then
                                local root = entitylib.character.RootPart
                                local velocity = root.AssemblyLinearVelocity
                                tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, velocity.Y) or 0
                                if tracked < -85 and canActivate() then
                                    rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                    rayParams.CollisionGroup = root.CollisionGroup
                                    local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                                    local ray = workspace:Blockcast(root.CFrame, BLOCKCAST_SIZE, Vector3.new(0, -1000, 0), rayParams)
                                    if ray then
                                        root.CFrame -= Vector3.new(0, root.Position.Y - (ray.Position.Y + rootSize), 0)
                                        tracked = 0
                                    end
                                end
                            end
                            task.wait(0.03)
                        until not active
                    end)

                elseif Mode.Value == 'Damage Accuracy' then
                    runDamageAccuracyMode()
                end
            end
        end,
        Tooltip = 'Prevents taking fall damage.'
    })

    Mode = NoFall:CreateDropdown({
        Name = 'Mode',
        List = {'Spoof', 'Gravity', 'Teleport', 'Damage Accuracy'},
        Default = 'Spoof',
        Function = function(val)
            if SpoofCap and SpoofCap.Object then
                SpoofCap.Object.Visible = val == 'Spoof'
            end
            if DamageAccuracy and DamageAccuracy.Object then
                DamageAccuracy.Object.Visible = val == 'Damage Accuracy'
            end
            if NoFall.Enabled then
                NoFall:Toggle()
                NoFall:Toggle()
            end
        end
    })

    Chance = NoFall:CreateSlider({
        Name = 'Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%',
        Tooltip = 'Chance for NoFall to activate'
    })

    SpoofCap = NoFall:CreateSlider({
        Name = 'Spoof Velocity Cap',
        Min = 30,
        Max = 86,
        Default = 86,
        Suffix = '',
        Tooltip = 'Lower = less fall damage. 86 = original, 30 = barely any damage'
    })

    DamageAccuracy = NoFall:CreateSlider({
        Name = 'Damage Accuracy',
        Min = 0,
        Max = 100,
        Suffix = '%',
        Default = 0,
        Decimal = 1,
        Tooltip = '0% = no damage, 100% = full damage',
        Visible = false
    })

    AutoToggle = NoFall:CreateToggle({
        Name = "Auto Toggle",
        Default = false,
        Function = function(val)
            HealthThreshold.Object.Visible = val
        end,
        Tooltip = "Only activate when health is below threshold"
    })

    HealthThreshold = NoFall:CreateSlider({
        Name = "Health Threshold",
        Min = 10,
        Max = 100,
        Default = 50,
        Tooltip = "Activate only when HP is below this"
    })
    HealthThreshold.Object.Visible = false

    task.defer(function()
        if SpoofCap and SpoofCap.Object then
            SpoofCap.Object.Visible = Mode.Value == 'Spoof'
        end
        if DamageAccuracy and DamageAccuracy.Object then
            DamageAccuracy.Object.Visible = Mode.Value == 'Damage Accuracy'
        end
        if HealthThreshold and HealthThreshold.Object then
            HealthThreshold.Object.Visible = AutoToggle.Enabled
        end
    end)
end)
	
run(function()
    local old
    local SophiaCheck
    local FROZEN_THRESHOLD = 10

    local NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if callback then
                old = modifier.addModifier
                modifier.addModifier = function(self, tab)
                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return old(self, tab)
                    end

                    if tab.moveSpeedMultiplier then
                        tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                    end
                    return old(self, tab)
                end

                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then
                        modifier:removeModifier(i)
                    end
                end
            else
                modifier.addModifier = old
                old = nil
            end
        end,
        Tooltip = 'Prevents slowing down when using items.'
    })

    SophiaCheck = NoSlowdown:CreateToggle({
        Name = 'Sophia Check',
        Tooltip = 'Allows slowdown ONLY when completely frozen',
        Default = false
    })
end)

run(function()
	local PAMode
	local TargetPart
	local Targets
	local TargetPots
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local TargetVisualiser
	local DesirePAHideCursor
	local DesirePACursorViewMode
	local DesirePACursorLimitBow
	local DesirePACursorShowGUI
	local DesirePAWorkMode
	local SortMethod
	local AeroPAChargePercent
	local RandomHeadPercent
	local RandomTorsoPercent
	local CustomPrediction          
	local HorizontalMultiplier      
	local VerticalMultiplier       
	local rayCheck = cloneRaycast()
	local old
	if not getgenv()._aerov4_original_calcLaunch then
		-- will be set when we first hook it (note to self)
	end
	local math_sqrt = math.sqrt
	local math_abs = math.abs
	local math_min = math.min
	local math_max = math.max
	local math_cos = math.cos
	local math_rad = math.rad
	local cachedPots = {}
	local lastPotScan = 0
	local POT_SCAN_INTERVAL = 2

	local lockedRandomPart = nil
	local wasHovering = false

	local aerov4bad = {
		predictStrafingMovement = function(targetPlayer, targetPart, projSpeed, gravity, origin)
			if not targetPlayer or not targetPlayer.Character or not targetPart then
				return targetPart and targetPart.Position or Vector3.zero
			end

			local currentPos = targetPart.Position
			local currentVel = targetPart.Velocity
			local totalDist = (currentPos - origin).Magnitude

			local t0 = totalDist / projSpeed
			local predictedPos = currentPos + Vector3.new(currentVel.X * t0, 0, currentVel.Z * t0)
			local t1 = (predictedPos - origin).Magnitude / projSpeed
			local t = (t0 + t1) * 0.5

			local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
			local predictedHorizontal = horizontalVel * t

			local verticalVel = currentVel.Y
			local heightDiff = origin.Y - currentPos.Y
			local verticalPrediction = 0
			local isJumping = verticalVel > 5
			local isFalling = verticalVel < -3

			if isJumping then
				local timeToApex = verticalVel / gravity
				local rawPrediction
				if t <= timeToApex then
					rawPrediction = verticalVel * t - 0.5 * gravity * t * t
				else
					local apexHeight = (verticalVel * verticalVel) / (2 * gravity)
					local fallTime = t - timeToApex
					rawPrediction = apexHeight - 0.5 * gravity * fallTime * fallTime
				end
				local heightScale = math.clamp(1 - math.abs(heightDiff) / 100, 0.3, 1.0)
				verticalPrediction = rawPrediction * 0.38 * heightScale
			elseif isFalling then
				local rawFall = verticalVel * t - 0.5 * gravity * t * t
				local heightScale = math.clamp(1 - math.abs(heightDiff) / 100, 0.2, 1.0)
				local distScale = math.clamp(1 - (totalDist - 20) / 160, 0.15, 1.0)
				verticalPrediction = math.clamp(rawFall * 0.26 * heightScale * distScale, -12, 0)
			end

			local finalPosition = currentPos + predictedHorizontal + Vector3.new(0, verticalPrediction, 0)

			local floorY = currentPos.Y - 4
			if finalPosition.Y < floorY then
				finalPosition = Vector3.new(finalPosition.X, floorY, finalPosition.Z)
			end

			return finalPosition
		end,

		smoothAim = function(currentCFrame, targetPosition, distance)
			return CFrame.new(currentCFrame.Position, targetPosition)
		end
	}

	local function updatePotCache()
		local currentTime = tick()
		if currentTime - lastPotScan < POT_SCAN_INTERVAL then return end
		lastPotScan = currentTime
		table.clear(cachedPots)
		local pots = collectionService:GetTagged("desert_pot")
		if #pots == 0 then
			for _, obj in pairs(workspace:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "desert_pot" then
					table.insert(cachedPots, obj)
				end
			end
		else
			cachedPots = pots
		end
	end

	local function getPotTarget(originPos)
		updatePotCache()
		local closestPot = nil
		local closestDistance = Range.Value
		local rangeSquared = Range.Value * Range.Value
		for _, obj in pairs(cachedPots) do
			if not obj or not obj.Parent then continue end
			local delta = obj.Position - originPos
			local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if distanceSquared > rangeSquared then continue end
			local distance = math_sqrt(distanceSquared)
			if distance >= closestDistance then continue end
			local deltaFlat = Vector3.new(delta.X, 0, delta.Z)
			local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			local dotProduct = localfacing:Dot(deltaFlat.Unit)
			local fovThreshold = math_cos(math_rad(FOV.Value) / 2)
			if dotProduct >= fovThreshold then
				if Targets.Walls.Enabled then
					local ray = workspace:Raycast(originPos, delta, rayCheck)
					if not ray then
						closestPot = obj
						closestDistance = distance
					end
				else
					closestPot = obj
					closestDistance = distance
				end
			end
		end
		return closestPot
	end

	local function getAeroPATarget(originPos)
		local validTargets = {}
		local rangeSquared = Range.Value * Range.Value
		local fovThreshold = math_cos(math_rad(FOV.Value) / 2)

		for _, ent in entitylib.List do
			if not Targets.Players.Enabled and ent.Player then continue end
			if not Targets.NPCs.Enabled and ent.NPC then continue end
			if not ent.Targetable then continue end
			if not ent.Character or not ent.RootPart then continue end
			local partKey = (TargetPart.Value == 'Closest' or TargetPart.Value == 'Randomize') and 'RootPart' or TargetPart.Value
			local selectedPart = ent[partKey] or ent.RootPart
			if not selectedPart then continue end
			local delta = selectedPart.Position - originPos
			local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if distanceSquared > rangeSquared then continue end
			local deltaFlat = Vector3.new(delta.X, 0, delta.Z)
			local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			if deltaFlat.Magnitude < 0.001 then continue end
			if localfacing:Dot(deltaFlat.Unit) < fovThreshold then continue end
			if Targets.Walls.Enabled then
				local ray = workspace:Raycast(originPos, delta, rayCheck)
				if ray then continue end
			end
			table.insert(validTargets, ent)
		end

		if #validTargets == 0 then return nil end

		table.sort(validTargets, sortmethods[SortMethod.Value])
		return validTargets[1]
	end

	local function pickRandomPart(character)
		local roll = math.random(1, 100)
		if roll <= RandomHeadPercent.Value then
			return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
		else
			return character:FindFirstChild('HumanoidRootPart')
		end
	end

	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local CoreConnections = {}
	local cursorRenderConnection
	local lastGUIState = false
	local UserInputService = inputService

	local function isFrostStaff(tool)
		if not tool then return false end
		local toolName = tool.Name or ""
		return toolName:find("frost_staff") or toolName == "FROST_STAFF_1" or toolName == "FROST_STAFF_2" or toolName == "FROST_STAFF_3"
	end

	local function getFrostStaffCooldown(toolName)
		if toolName:find("frost_staff_3") then return 0.16
		elseif toolName:find("frost_staff_2") then return 0.18
		else return 0.2 end
	end

	local function shouldPAWork()
		if PAMode.Value ~= 'DesirePA' then return true end
		local inFirstPerson = isFirstPerson()
		if DesirePAWorkMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then return not inFirstPerson
		else return true end
	end

	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then return false end
		return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
	end

	local function hasFrostStaffEquipped()
		if not store.hand or not store.hand.tool then return false end
		return isFrostStaff(store.hand.tool)
	end

	local function shouldHideCursor()
		if PAMode.Value ~= 'DesirePA' or not DesirePAHideCursor.Enabled then return false end
		if DesirePACursorShowGUI.Enabled and isGUIOpen() then return false end
		if DesirePACursorLimitBow.Enabled and not hasBowEquipped() and not hasFrostStaffEquipped() then return false end
		local inFirstPerson = isFirstPerson()
		if DesirePACursorViewMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePACursorViewMode.Value == 'Third Person' then return not inFirstPerson
		else return true end
	end

	local function updateCursor()
		pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
	end

	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local function updateOutline(target, isPot)
		if targetOutline then
			pcall(function() targetOutline:Destroy() end)
			targetOutline = nil
		end
		if target and TargetVisualiser and TargetVisualiser.Enabled then
			pcall(function()
				targetOutline = Instance.new("Highlight")
				targetOutline.FillTransparency = 1
				targetOutline.OutlineColor = isPot and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(255, 0, 0)
				targetOutline.OutlineTransparency = 0
				targetOutline.Adornee = isPot and target or target.Character
				targetOutline.Parent = isPot and target or target.Character
			end)
		end
	end

	local function handlePlayerSelection()
		local function selectTarget(target)
			if not target or not target.Parent then return end
			local plr = playersService:GetPlayerFromCharacter(target.Parent)
			if plr then
				if selectedTarget == plr then
					selectedTarget = nil
					updateOutline(nil)
				else
					selectedTarget = plr
					updateOutline(plr)
				end
			end
		end
		local con
		if isMobile then
			con = UserInputService.TouchTapInWorld:Connect(function(touchPos)
				if not hovering then updateOutline(nil); return end
				if not ProjectileAimbot.Enabled then pcall(function() con:Disconnect() end); updateOutline(nil); return end
				local ray = workspace.CurrentCamera:ScreenPointToRay(touchPos.X, touchPos.Y)
				local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
				if result and result.Instance then selectTarget(result.Instance) end
			end)
			table.insert(CoreConnections, con)
		end
	end

	local function updateOptionsVisibility()
		local mode = PAMode.Value
		local isRandom = TargetPart.Value == 'Randomize'
		if DesirePAHideCursor then DesirePAHideCursor.Object.Visible = (mode == 'DesirePA') end
		if DesirePACursorViewMode then DesirePACursorViewMode.Object.Visible = (mode == 'DesirePA') end
		if DesirePACursorLimitBow then DesirePACursorLimitBow.Object.Visible = (mode == 'DesirePA') end
		if DesirePACursorShowGUI then DesirePACursorShowGUI.Object.Visible = (mode == 'DesirePA') end
		if DesirePAWorkMode then DesirePAWorkMode.Object.Visible = (mode == 'DesirePA') end
		if SortMethod then SortMethod.Object.Visible = (mode == 'AeroPA') end
		if AeroPAChargePercent then AeroPAChargePercent.Object.Visible = (mode == 'AeroPA') end
		if RandomHeadPercent then RandomHeadPercent.Object.Visible = isRandom end
		if RandomTorsoPercent then RandomTorsoPercent.Object.Visible = isRandom end
		if CustomPrediction then
			CustomPrediction.Object.Visible = true  
		end
		if HorizontalMultiplier then
			HorizontalMultiplier.Object.Visible = CustomPrediction and CustomPrediction.Enabled
		end
		if VerticalMultiplier then
			VerticalMultiplier.Object.Visible = CustomPrediction and CustomPrediction.Enabled
		end
	end

	local ProjectileAimbot

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				if PAMode.Value == 'DesirePA' and DesirePAHideCursor.Enabled and not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
				end

				handlePlayerSelection()

				if not getgenv()._aerov4_original_calcLaunch then
					getgenv()._aerov4_original_calcLaunch = bedwars.ProjectileController.calculateImportantLaunchValues
				end
				old = getgenv()._aerov4_original_calcLaunch
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero

					if not wasHovering then
						lockedRandomPart = nil
					end
					wasHovering = true
					hovering = true

					local plr
					local targetingPot = false
					local potTarget = nil

					if selectedTarget and selectedTarget.Character and selectedTarget.Character.PrimaryPart then
						local dist = (selectedTarget.Character.PrimaryPart.Position - originPos).Magnitude
						if dist <= Range.Value then
							if PAMode.Value == 'AeroPA' and AeroPATargetPriority.Value == 'Forest' and not HasSeed(selectedTarget.Character) then
								selectedTarget = nil
								updateOutline(nil)
							else
								plr = selectedTarget
							end
						else
							selectedTarget = nil
							updateOutline(nil)
						end
					end

					if not plr then
						if PAMode.Value == 'AeroPA' and SortMethod.Value ~= 'Distance' then
							plr = getAeroPATarget(originPos)
						else
							local entityPart = (TargetPart.Value == 'Closest' or TargetPart.Value == 'Randomize') and 'RootPart' or TargetPart.Value
							plr = entitylib.EntityMouse({
								Part = entityPart,
								Range = FOV.Value,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled,
								Origin = originPos
							})
							if plr and not plr.Targetable then plr = nil end
						end
					end

					if targetingPot then
						updateOutline(potTarget, true)
					elseif plr then
						updateOutline(plr, false)
					else
						updateOutline(nil)
					end

					if not shouldPAWork() then
						hovering = false
						wasHovering = false
						return old(...)
					end

					if targetingPot and potTarget then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then hovering = false; wasHovering = false; return old(...) end
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + projmeta.fromPositionOffset
						local newlook = CFrame.new(offsetpos, potTarget.Position + Vector3.new(0, 1.2, 0))
						hovering = false
						wasHovering = false
						return {
							initialVelocity = newlook.LookVector * projSpeed,
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = 5
						}

					elseif plr and plr.Character then
						local targetBodyPart = nil

						local partsList = {
							'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
							'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
							'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
							'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
						}

						if TargetPart.Value == 'Closest' then
							local mousePos = inputService:GetMouseLocation()
							local mouseRay = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y, 0)
							local closestAngle = math.huge
							for _, partName in partsList do
								local part = plr.Character:FindFirstChild(partName)
								if part then
									local dirTopart = (part.Position - mouseRay.Origin).Unit
									local angle = math.acos(math.clamp(mouseRay.Direction:Dot(dirTopart), -1, 1))
									if angle < closestAngle then
										closestAngle = angle
										targetBodyPart = part
									end
								end
							end
							if not targetBodyPart then targetBodyPart = plr.RootPart end

						elseif TargetPart.Value == 'Randomize' then
							if not lockedRandomPart or not lockedRandomPart.Parent then
								lockedRandomPart = pickRandomPart(plr.Character)
							end
							targetBodyPart = lockedRandomPart

						elseif TargetPart.Value == 'Head' then
							targetBodyPart = plr.Character:FindFirstChild('Head') or plr.Head
						elseif TargetPart.Value == 'RootPart' then
							targetBodyPart = plr.Character:FindFirstChild('HumanoidRootPart') or plr.RootPart
						else
							targetBodyPart = plr[TargetPart.Value]
						end

						if not targetBodyPart then targetBodyPart = plr.RootPart end
						if not targetBodyPart then hovering = false; wasHovering = false; return old(...) end

						local dist = (targetBodyPart.Position - originPos).Magnitude
						if dist > Range.Value then hovering = false; wasHovering = false; return old(...) end

						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then hovering = false; wasHovering = false; return old(...) end

						local isFrostStaffProjectile = false
						if projmeta and projmeta.projectile then
							isFrostStaffProjectile = projmeta.projectile:find("frosty_snowball") ~= nil
						end

						local usingFrostStaff = false
						if store.hand and store.hand.tool then
							usingFrostStaff = isFrostStaff(store.hand.tool)
							if usingFrostStaff then isFrostStaffProjectile = true end
						end

						local isTurretProjectile = projmeta.projectile:find('turret') ~= nil or projmeta.projectile:find('vulcan') ~= nil

						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') and not isFrostStaffProjectile and not isTurretProjectile then
							hovering = false; wasHovering = false; return old(...)
						end

						if table.find(Blacklist.ListEnabled, projmeta.projectile) then
							hovering = false; wasHovering = false; return old(...)
						end

						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity

						if balloons and balloons > 0 then
							playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
						end

						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end

						if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
									break
								end
							end
						end

						local targetVelocity = targetBodyPart.Velocity
						if CustomPrediction and CustomPrediction.Enabled then
							local hMult = (HorizontalMultiplier and HorizontalMultiplier.Value or 100) / 100
							local vMult = (VerticalMultiplier and VerticalMultiplier.Value or 100) / 100
							targetVelocity = Vector3.new(
								targetVelocity.X * hMult,
								targetVelocity.Y * vMult,
								targetVelocity.Z * hMult
							)
						end

						if PAMode.Value == 'SavyPA' then
							local newlook = CFrame.new(offsetpos, targetBodyPart.Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
							local calc = prediction.SolveTrajectory(
								newlook.p, projSpeed, gravity,
								targetBodyPart.Position,
								projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity,  
								playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck
							)
							if calc then
								if targetinfo and targetinfo.Targets then targetinfo.Targets[plr] = tick() + 1 end
								hovering = false
								wasHovering = false
								return {
									initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
									positionFrom = offsetpos,
									deltaT = lifetime,
									gravitationalAcceleration = gravity,
									drawDurationSeconds = 5
								}
							end

						elseif PAMode.Value == 'AeroPA' then
							local distance = (targetBodyPart.Position - offsetpos).Magnitude
							local rawLook = CFrame.new(offsetpos, targetBodyPart.Position)
							local tempPart = {
								Position = targetBodyPart.Position,
								Velocity = targetVelocity
							}
							local predictedPosition = aerov4bad.predictStrafingMovement(plr.Player, tempPart, projSpeed, gravity, offsetpos)
							local newlook = aerov4bad.smoothAim(rawLook, predictedPosition, distance)
							if projmeta.projectile ~= 'owl_projectile' then
								newlook = newlook * CFrame.new(bedwars.BowConstantsTable.RelX or 0, bedwars.BowConstantsTable.RelY or 0, bedwars.BowConstantsTable.RelZ or 0)
							end
							local calc = prediction.SolveTrajectory(
								newlook.p, projSpeed, gravity, predictedPosition,
								projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity,
								playerGravity, plr.HipHeight, plr.Jumping and 50 or nil, rayCheck
							)
							if calc then
								if targetinfo and targetinfo.Targets then targetinfo.Targets[plr] = tick() + 1 end
								local customDrawDuration = 0.58 * (AeroPAChargePercent.Value / 100)
								if usingFrostStaff then
									customDrawDuration = getFrostStaffCooldown(store.hand.tool.Name) * (AeroPAChargePercent.Value / 100)
								end
								local finalDirection = (calc - newlook.p).Unit
								local angleFromHorizontal = math.acos(math.clamp(finalDirection:Dot(Vector3.new(0, 1, 0)), -1, 1))
								if angleFromHorizontal > math.rad(1) and angleFromHorizontal < math.rad(179) then
									hovering = false
									wasHovering = false
									return {
										initialVelocity = finalDirection * projSpeed,
										positionFrom = offsetpos,
										deltaT = lifetime,
										gravitationalAcceleration = gravity,
										drawDurationSeconds = customDrawDuration
									}
								end
							end

						else
							local newlook = CFrame.new(offsetpos, targetBodyPart.Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
							local calc = prediction.SolveTrajectory(
								newlook.p, projSpeed, gravity,
								targetBodyPart.Position,
								projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity,
								playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck
							)
							if calc then
								if targetinfo and targetinfo.Targets then targetinfo.Targets[plr] = tick() + 1 end
								local customDrawDuration = 5
								if usingFrostStaff then customDrawDuration = getFrostStaffCooldown(store.hand.tool.Name) end
								hovering = false
								wasHovering = false
								return {
									initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
									positionFrom = offsetpos,
									deltaT = lifetime,
									gravitationalAcceleration = gravity,
									drawDurationSeconds = customDrawDuration
								}
							end
						end
					end

					hovering = false
					wasHovering = false
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = getgenv()._aerov4_original_calcLaunch or old
				if targetOutline then
					pcall(function() targetOutline:Destroy() end)
					targetOutline = nil
				end
				selectedTarget = nil
				lockedRandomPart = nil
				wasHovering = false
				for i, v in pairs(CoreConnections) do
					pcall(function() v:Disconnect() end)
				end
				table.clear(CoreConnections)
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				pcall(function() inputService.MouseIconEnabled = true end)
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})

	PAMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Mode',
		List = {'Vape', 'AeroPA', 'DesirePA', 'SavyPA'},
		Default = 'Vape',
		Tooltip = 'Select prediction algorithm',
		Function = function() updateOptionsVisibility() end
	})

	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Tooltip = 'Select which body part to aim at',
		Function = function()
			lockedRandomPart = nil
			wasHovering = false
			updateOptionsVisibility()
		end
	})

	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})

	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'}
	})

	RandomHeadPercent = ProjectileAimbot:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Tooltip = 'Percentage chance to aim at head when Randomize is selected'
	})

	RandomTorsoPercent = ProjectileAimbot:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Tooltip = 'Percentage chance to aim at torso/rootpart when Randomize is selected'
	})

	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})

	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Maximum distance for target locking'
	})

	TargetVisualiser = ProjectileAimbot:CreateToggle({
		Name = "Target Visualiser",
		Default = true,
		Function = function(callback)
			if not callback then updateOutline(nil) end
		end
	})

	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})

	DesirePAWorkMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Work Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both'
	})

	DesirePAHideCursor = ProjectileAimbot:CreateToggle({
		Name = 'Hide Cursor',
		Default = false,
		Function = function(callback)
			if callback and ProjectileAimbot.Enabled and PAMode.Value == 'DesirePA' then
				if not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
				end
				updateCursor()
			else
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				pcall(function() inputService.MouseIconEnabled = true end)
			end
		end
	})

	DesirePACursorViewMode = ProjectileAimbot:CreateDropdown({
		Name = 'Cursor View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'First Person',
		Darker = true,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled and PAMode.Value == 'DesirePA' then
				updateCursor()
			end
		end
	})

	DesirePACursorLimitBow = ProjectileAimbot:CreateToggle({
		Name = 'Limit to Bow',
		Darker = true,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled and PAMode.Value == 'DesirePA' then
				updateCursor()
			end
		end
	})

	DesirePACursorShowGUI = ProjectileAimbot:CreateToggle({
		Name = 'Show on GUI',
		Darker = true,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled and PAMode.Value == 'DesirePA' then
				updateCursor()
			end
		end
	})

    TargetPots = ProjectileAimbot:CreateToggle({
        Name = 'Desert Pots',
        Default = false,
        Tooltip = 'Target desert pots'
    })

    SortMethod = ProjectileAimbot:CreateDropdown({
        Name = 'Sort Method',
        List = {'Distance', 'Damage', 'Threat', 'Kit', 'Health', 'Angle', 'Forest'},
        Default = 'Distance',
        Tooltip = 'prioritize targets'
    })

	AeroPAChargePercent = ProjectileAimbot:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
		Darker = true,
		Tooltip = 'Control bow charge percentage (affects damage): 100% = full damage, 50% = half damage, etc.'
	})

	CustomPrediction = ProjectileAimbot:CreateToggle({
		Name = 'Custom Prediction',
		Default = false,
		Tooltip = 'Enable to customize horizontal/vertical prediction multipliers :D',
		Function = function()
			updateOptionsVisibility()
		end
	})

	HorizontalMultiplier = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal Multiplier',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = '%',
		Visible = false,
		Tooltip = 'Adjust horizontal prediction strength (0% = none, 100% = normal, 200% = double)'
	})

	VerticalMultiplier = ProjectileAimbot:CreateSlider({
		Name = 'Vertical Multiplier',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = '%',
		Visible = false,
		Tooltip = 'Adjust vertical prediction strength (0% = none, 100% = normal, 200% = double)'
	})

	updateOptionsVisibility()

    updateOptionsVisibility()

    vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
        if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled and PAMode.Value == 'DesirePA' then
            updateCursor()
        end
    end))

    task.defer(function()
        updateOptionsVisibility()
    end)
end)

run(function()
	local shooting, old = false
	local AutoShootInterval
	local AutoShootSwitchSpeed
	local AutoShootRange
	local AutoShootFOV
	local AutoShootWaitDelay
	local lastAutoShootTime = 0
	local autoShootEnabled = false
	local KillauraTargetCheck
	local FirstPersonCheck
	
	_G.autoShootLock = _G.autoShootLock or false

	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local cachedBows = {}
	local cachedSwordSlot = nil
	local cachedHasArrows = false
	local lastInventoryUpdate = 0
	local INVENTORY_CACHE_TIME = 0.5
	local lastTargetCheck = 0
	local lastTargetResult = false
	local TARGET_CHECK_INTERVAL = 0.15
	
	local math_acos = math.acos
	local math_rad = math.rad
	local tick = tick
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function updateInventoryCache()
		local now = tick()
		if now - lastInventoryUpdate < INVENTORY_CACHE_TIME then
			return
		end
		lastInventoryUpdate = now
		
		local arrowItem = getItem('arrow')
		cachedHasArrows = arrowItem and arrowItem.amount > 0
		
		table.clear(cachedBows)
		cachedSwordSlot = nil
		
		local hotbar = store.inventory.hotbar
		for i = 1, #hotbar do
			local v = hotbar[i]
			if v.item and v.item.itemType then
				local itemMeta = bedwars.ItemMeta[v.item.itemType]
				if itemMeta then
					if itemMeta.projectileSource then
						local projectileSource = itemMeta.projectileSource
						if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
							table.insert(cachedBows, i - 1)
						end
					end
					if itemMeta.sword and not cachedSwordSlot then
						cachedSwordSlot = i - 1
					end
				end
			end
		end
	end
	
	local function hasArrows()
		updateInventoryCache()
		return cachedHasArrows
	end
	
	local function getBows()
		updateInventoryCache()
		return cachedBows
	end
	
	local function getSwordSlot()
		updateInventoryCache()
		return cachedSwordSlot
	end
	
	local function hasValidTarget()
		if KillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		end
		
		local now = tick()
		if now - lastTargetCheck < TARGET_CHECK_INTERVAL then
			return lastTargetResult
		end
		lastTargetCheck = now
		
		if not entitylib.isAlive then 
			lastTargetResult = false
			return false 
		end
		
		local myPos = entitylib.character.RootPart.Position
		local myLook = entitylib.character.RootPart.CFrame.LookVector
		local rangeSquared = AutoShootRange.Value * AutoShootRange.Value
		local fovRad = math_rad(AutoShootFOV.Value)
		local myTeam = lplr:GetAttribute('Team')
		
		for _, entity in entitylib.List do
			if entity.Player == lplr then continue end
			if not entity.Character then continue end
			
			local rootPart = entity.RootPart
			if not rootPart then continue end
			
			if entity.Player then
				if myTeam == entity.Player:GetAttribute('Team') then
					continue
				end
			else
				if not entity.Targetable then
					continue
				end
			end
			
			local pos = rootPart.Position
			local dx = pos.X - myPos.X
			local dy = pos.Y - myPos.Y
			local dz = pos.Z - myPos.Z
			local distanceSquared = dx * dx + dy * dy + dz * dz
			
			if distanceSquared > rangeSquared then continue end
			
			local distance = math.sqrt(distanceSquared)
			if distance < 0.01 then 
				lastTargetResult = true
				return true 
			end
			
			local toTargetX = dx / distance
			local toTargetY = dy / distance
			local toTargetZ = dz / distance
			local dot = myLook.X * toTargetX + myLook.Y * toTargetY + myLook.Z * toTargetZ
			local angle = math_acos(math.max(-1, math.min(1, dot)))
			
			if angle <= fovRad then
				lastTargetResult = true
				return true
			end
		end
		
		lastTargetResult = false
		return false
	end
	
	local AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				autoShootEnabled = true
				
				lastInventoryUpdate = 0
				updateInventoryCache()
				
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and proj and (proj == 'arrow' or bedwars.ProjectileMeta[proj] and bedwars.ProjectileMeta[proj].combat) and not _G.autoShootLock then
						task.spawn(function()
							if not hasArrows() then
								return
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								return
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									return
								end
							else
								if not hasValidTarget() then
									return
								end
							end
							
							local bows = getBows()
							if #bows > 0 then
								_G.autoShootLock = true
								task.wait(AutoShootWaitDelay.Value)
								local selected = store.inventory.hotbarSlot
								for i = 1, #bows do
									local v = bows[i]
									if hotbarSwitch(v) then
										task.wait(0.05)
										leftClick()
										task.wait(0.05)
									end
								end
								hotbarSwitch(selected)
								_G.autoShootLock = false
							end
						end)
					end
					return old(...)
				end
				
				task.spawn(function()
					repeat
						task.wait(0.15) 
						if autoShootEnabled and not _G.autoShootLock then
							if not hasArrows() then
								continue
							end
							
							if not isSword() then
								continue
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							local hasTarget = false
							if KillauraTargetCheck.Enabled then
								hasTarget = store.KillauraTarget ~= nil
							else
								hasTarget = hasValidTarget()
							end
							
							if not hasTarget then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoShootTime) >= AutoShootInterval.Value then
								local bows = getBows()
								
								if #bows > 0 then
									_G.autoShootLock = true
									lastAutoShootTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for i = 1, #bows do
										local bowSlot = bows[i]
										if hotbarSwitch(bowSlot) then
											task.wait(AutoShootSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									local swordSlot = getSwordSlot()
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoShootEnabled
				end)
			else
				autoShootEnabled = false
				if old then
					bedwars.ProjectileController.createLocalProjectile = old
				end
				_G.autoShootLock = false
				
				table.clear(cachedBows)
				cachedSwordSlot = nil
				cachedHasArrows = false
				lastInventoryUpdate = 0
			end
		end,
		Tooltip = 'Automatically switches to bows and shoots them'
	})
	
	AutoShootInterval = AutoShoot:CreateSlider({
		Name = 'Shoot Interval',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to auto-shoot bows'
	})
	
	AutoShootSwitchSpeed = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and shooting (lower = faster)'
	})
	
	AutoShootWaitDelay = AutoShoot:CreateSlider({
		Name = 'Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)'
	})
	
	AutoShootRange = AutoShoot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to auto-shoot'
	})
	
	AutoShootFOV = AutoShoot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	KillauraTargetCheck = AutoShoot:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only auto-shoot when Killaura has a target (overrides Range/FOV)'
	})
	
	FirstPersonCheck = AutoShoot:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
	
	vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
		lastInventoryUpdate = 0
	end))
end)

run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "Leave Party",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)
	
run(function()
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = cloneRaycast()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
					if entitylib.isAlive then
						if not Fly.Enabled and not LongJump.Enabled then
							bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
							if Mode.Value == 'CFrame' then
								local state = entitylib.character.Humanoid:GetState()
								if state == Enum.HumanoidStateType.Climbing then return end
			
								local root, velo = entitylib.character.RootPart, getSpeed()
								local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
			
								if WallCheck.Enabled then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayCheck.CollisionGroup = root.CollisionGroup
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end
			
								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end
					end
				end))
			else
				bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Method',
		List = {'Bedwars', 'CFrame'},
		Default = 'CFrame'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
    AlwaysJump = Speed:CreateToggle({
        Name = 'Always Jump',
        Visible = false,
        Darker = true
    })

    task.defer(function()
        if AlwaysJump and AlwaysJump.Object then
            AlwaysJump.Object.Visible = false   
        end
    end)
end)
	
run(function()
	local KitESP
	local Notify
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
		star_collector = {'stars', 'crit_star'},
		black_market_trader = {'shadow_coin', 'shadow_coin'},
		miner = {'petrified-player', 'large_rock'},
		trapper = {'snap_trap', 'snap_trap'},
		mage = {'ElementTome', 'mage_spellbook'},
	}
	local NONTaggedKits = {
		necromancer = {'Gravestone', true},
		battery = {'Open', true},
	}
	local DescendantKits = {
		['farmer_cletus'] = {
			{'carrot', 'carrot_seeds'},
			{'melon', 'melon_seeds'},
			{'pumpkin', 'pumpkin_seeds'},
		},
	}

	local function getStarImage(v)
		local parent = v and v.Parent
		if parent and parent:IsA("Model") then
			local modelName = parent.Name
			if modelName == "CritStar" or modelName:lower():find("crit") then
				return bedwars.getIcon({itemType = 'crit_star'}, true)
			elseif modelName == "VitalityStar" or modelName:lower():find("vitality") then
				return bedwars.getIcon({itemType = 'vitality_star'}, true)
			end
		end
		return bedwars.getIcon({itemType = 'crit_star'}, true)
	end

	local function Added(v, icon, non)
		if Reference[v] then return end
		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
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
		if non then
			image.Image = icon
		else
			image.Image = bedwars.getIcon({itemType = icon}, true)
		end
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end

	local function AddedStar(v)
		if not v or not v.Parent then return end
		if Reference[v] then return end

		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'star'
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
		image.Image = getStarImage(v)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local currentConnections = {}
	local currentKit = nil

	local function disconnectAll()
		for _, conn in ipairs(currentConnections) do
			conn:Disconnect()
		end
		table.clear(currentConnections)
	end

	local function addKit(tag, icon)
		if tag == 'stars' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v:IsA("Model") and v.PrimaryPart then
					task.wait(0.1)
					AddedStar(v.PrimaryPart)
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v:IsA("Model") and v.PrimaryPart then
					AddedStar(v.PrimaryPart)
				end
			end
			return
		end

		local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			Added(v.PrimaryPart, icon, false)
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
		for _, v in collectionService:GetTagged(tag) do
			Added(v.PrimaryPart, icon, false)
		end
	end

	local function addKitNon(objName, icon)
		if typeof(icon) == "boolean" then
			if objName == "Gravestone" then
				icon = "rbxassetid://6307844310"
			elseif objName == "Open" then
				icon = "rbxassetid://10159166528"
			else
				icon = bedwars.getIcon({itemType = icon}, true) or ''
			end
		else
			icon = bedwars.getIcon({itemType = icon}, true)
		end
		local connAdded = workspace.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				task.wait(0.1)
				if child.PrimaryPart then
					Added(child, icon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.ChildRemoved:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				if Reference[child] then
					Reference[child]:Destroy()
					Reference[child] = nil
				end
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function addKitDescendant(partName, icon)
		local resolvedIcon = bedwars.getIcon({itemType = icon}, true)
		
		local function shouldSkip(obj)
			local p = obj.Parent
			while p and p ~= workspace do
				if p.Name == partName then return true end
				p = p.Parent
			end
			return false
		end

		for _, obj in workspace:GetDescendants() do
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end
		local connAdded = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				task.wait(0.1)
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.DescendantRemoving:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and Reference[obj] then
				Reference[obj]:Destroy()
				Reference[obj] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function setupKit(kitName)
		local kit = ESPKits[kitName]
		local nontag = NONTaggedKits[kitName]
		local desctag = DescendantKits[kitName]
		if kit then
			addKit(kit[1], kit[2])
		end
		if nontag then
			addKitNon(nontag[1], nontag[2])
		end
		if desctag then
			for _, entry in ipairs(desctag) do
				addKitDescendant(entry[1], entry[2])
			end
		end
	end

	KitESP = vape.Categories.Kits:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				task.spawn(function()
					while KitESP.Enabled do
						if not currentKit then
							repeat
								task.wait()
							until store.equippedKit ~= '' or not KitESP.Enabled
							if not KitESP.Enabled then break end
						end
						local newKit = store.equippedKit
						if newKit ~= currentKit then
							disconnectAll()
							Folder:ClearAllChildren()
							table.clear(Reference)
							if newKit ~= '' then
								setupKit(newKit)
							end
							currentKit = newKit
						end
						task.wait(1)
					end
					disconnectAll()
					Folder:ClearAllChildren()
					table.clear(Reference)
					currentKit = nil
				end)
			else
				disconnectAll()
				Folder:ClearAllChildren()
				table.clear(Reference)
				currentKit = nil
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Notify = KitESP:CreateToggle({
		Name = "Notify",
		Default = false
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

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local CollectionService = collectionService
	
	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}
	
	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then 
					return lootType, config
				end
			end
		end
		return nil
	end
	
	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end
	
	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)
		
		if not icon or icon == "" then
			return nil
		end
		
		return icon
	end
	
	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end 
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(40, 40)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle
		
		local blur = addBlur(billboard)
		blur.Visible = true 
		
		local iconImage = getProperIcon(config.icon)
		
		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0) 
			image.BackgroundTransparency = 0.3 
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.new(0, 0, 0) 
			frame.BackgroundTransparency = 0.3 
			frame.BorderSizePixel = 0
			frame.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame
			
			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
		end
		
		Reference[lootHandle] = billboard
	end
	
	local function Removed(lootHandle)
		if Reference[lootHandle] then
			Reference[lootHandle]:Destroy()
			Reference[lootHandle] = nil
		end
	end
	
	local function findExistingLoot()
		local tagged = CollectionService:GetTagged('ItemDrop')
		for _, drop in ipairs(tagged) do
			local handle = drop:FindFirstChild('Handle')
			if handle then
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					if not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	local function refreshLootType(lootType)
		if not LootESP.Enabled then return end
		
		local enabled = isLootEnabled(lootType)
		
		if not enabled then
			for handle, billboard in pairs(Reference) do
				if billboard.Name == lootType then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		else
			local tagged = CollectionService:GetTagged('ItemDrop')
			for _, drop in ipairs(tagged) do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local dropLootType, config = getLootType(drop.Name)
					if dropLootType == lootType and not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()
				
				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end
					
					task.defer(function()
						local handle = drop:FindFirstChild('Handle')
						if not handle then return end
						
						local lootType, config = getLootType(drop.Name)
						if lootType and isLootEnabled(lootType) then
							Added(handle, lootType, config)
						end
					end)
				end))
				
				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					local handle = drop:FindFirstChild('Handle')
					if handle then
						Removed(handle)
					end
				end))
				
			else
				for handle, billboard in pairs(Reference) do
					billboard:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for loot drops (iron, diamond, emerald)'
	})
	
	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshLootType('iron')
		end,
		Default = true
	})
	
	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshLootType('diamond')
		end,
		Default = true
	})
	
	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshLootType('emerald')
		end,
		Default = true
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
    local ShowKits
    local Rank
    local Enchant
    local Scale
    local FontOption
    local Teammates
    local DistanceCheck
    local DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local methodused
    local lastUpdate = {}
    local kitCache = {}
    local equipmentCache = {}
    local enchantCache = {}
    local enchantConnections = {}
    local tick = tick
    local math_floor = math.floor
    local math_round = math.round
    local math_clamp = math.clamp
    local math_huge = math.huge
    local string_format = string.format
    local vector2new = Vector2.new
    local vector3new = Vector3.new
    local color3fromHSV = Color3.fromHSV
    local color3new = Color3.new
    local udim2fromOffset = UDim2.fromOffset

    local kitImageIds = {
        ['none'] = "rbxassetid://16493320215",
        ["random"] = "rbxassetid://79773209697352",
        ["cowgirl"] = "rbxassetid://9155462968",
        ["davey"] = "rbxassetid://9155464612",
        ["warlock"] = "rbxassetid://15186338366",
        ["ember"] = "rbxassetid://9630017904",
        ["black_market_trader"] = "rbxassetid://9630017904",
        ["yeti"] = "rbxassetid://9166205917",
        ["scarab"] = "rbxassetid://137137517627492",
        ["defender"] = "rbxassetid://131690429591874",
        ["cactus"] = "rbxassetid://104436517801089",
        ["oasis"] = "rbxassetid://120283205213823",
        ["berserker"] = "rbxassetid://90258047545241",
        ["sword_shield"] = "rbxassetid://131690429591874",
        ["airbender"] = "rbxassetid://74712750354593",
        ["gun_blade"] = "rbxassetid://138231219644853",
        ["frost_hammer_kit"] = "rbxassetid://11838567073",
        ["spider_queen"] = "rbxassetid://95237509752482",
        ["archer"] = "rbxassetid://9224796984",
        ["axolotl"] = "rbxassetid://9155466713",
        ["baker"] = "rbxassetid://9155463919",
        ["barbarian"] = "rbxassetid://9166207628",
        ["builder"] = "rbxassetid://9155463708",
        ["necromancer"] = "rbxassetid://11343458097",
        ["cyber"] = "rbxassetid://9507126891",
        ["sorcerer"] = "rbxassetid://97940108361528",
        ["bigman"] = "rbxassetid://9155467211",
        ["spirit_assassin"] = "rbxassetid://10406002412",
        ["farmer_cletus"] = "rbxassetid://9155466936",
        ["ice_queen"] = "rbxassetid://9155466204",
        ["grim_reaper"] = "rbxassetid://9155467410",
        ["spirit_gardener"] = "rbxassetid://132108376114488",
        ["hannah"] = "rbxassetid://10726577232",
        ["shielder"] = "rbxassetid://9155464114",
        ["summoner"] = "rbxassetid://18922378956",
        ["glacial_skater"] = "rbxassetid://84628060516931",
        ["dragon_sword"] = "rbxassetid://16215630104",
        ["lumen"] = "rbxassetid://9630018371",
        ["flower_bee"] = "rbxassetid://101569742252812",
        ["jellyfish"] = "rbxassetid://18129974852",
        ["melody"] = "rbxassetid://9155464915",
        ["mimic"] = "rbxassetid://14783283296",
        ["miner"] = "rbxassetid://9166208461",
        ["nazar"] = "rbxassetid://18926951849",
        ["seahorse"] = "rbxassetid://11902552560",
        ["elk_master"] = "rbxassetid://15714972287",
        ["rebellion_leader"] = "rbxassetid://18926409564",
        ["void_hunter"] = "rbxassetid://122370766273698",
        ["taliyah"] = "rbxassetid://13989437601",
        ["angel"] = "rbxassetid://9166208240",
        ["harpoon"] = "rbxassetid://18250634847",
        ["void_walker"] = "rbxassetid://78915127961078",
        ["spirit_summoner"] = "rbxassetid://95760990786863",
        ["triple_shot"] = "rbxassetid://9166208149",
        ["void_knight"] = "rbxassetid://73636326782144",
        ["regent"] = "rbxassetid://9166208904",
        ["vulcan"] = "rbxassetid://9155465543",
        ["owl"] = "rbxassetid://12509401147",
        ["dasher"] = "rbxassetid://9155467645",
        ["disruptor"] = "rbxassetid://11596993583",
        ["wizard"] = "rbxassetid://13353923546",
        ["aery"] = "rbxassetid://9155463221",
        ["agni"] = "rbxassetid://17024640133",
        ["alchemist"] = "rbxassetid://9155462512",
        ["spearman"] = "rbxassetid://9166207341",
        ["beekeeper"] = "rbxassetid://9312831285",
        ["falconer"] = "rbxassetid://17022941869",
        ["bounty_hunter"] = "rbxassetid://9166208649",
        ["blood_assassin"] = "rbxassetid://12520290159",
        ["battery"] = "rbxassetid://10159166528",
        ["steam_engineer"] = "rbxassetid://15380413567",
        ["vesta"] = "rbxassetid://9568930198",
        ["beast"] = "rbxassetid://9155465124",
        ["dino_tamer"] = "rbxassetid://9872357009",
        ["drill"] = "rbxassetid://12955100280",
        ["elektra"] = "rbxassetid://13841413050",
        ["fisherman"] = "rbxassetid://9166208359",
        ["queen_bee"] = "rbxassetid://12671498918",
        ["card"] = "rbxassetid://13841410580",
        ["frosty"] = "rbxassetid://9166208762",
        ["gingerbread_man"] = "rbxassetid://9155464364",
        ["ghost_catcher"] = "rbxassetid://9224802656",
        ["tinker"] = "rbxassetid://17025762404",
        ["ignis"] = "rbxassetid://13835258938",
        ["oil_man"] = "rbxassetid://9166206259",
        ["jade"] = "rbxassetid://9166306816",
        ["dragon_slayer"] = "rbxassetid://10982192175",
        ["paladin"] = "rbxassetid://11202785737",
        ["pinata"] = "rbxassetid://10011261147",
        ["merchant"] = "rbxassetid://9872356790",
        ["metal_detector"] = "rbxassetid://9378298061",
        ["slime_tamer"] = "rbxassetid://15379766168",
        ["nyoka"] = "rbxassetid://17022941410",
        ["midnight"] = "rbxassetid://9155462763",
        ["pyro"] = "rbxassetid://9155464770",
        ["raven"] = "rbxassetid://9166206554",
        ["santa"] = "rbxassetid://9166206101",
        ["sheep_herder"] = "rbxassetid://9155465730",
        ["smoke"] = "rbxassetid://9155462247",
        ["spirit_catcher"] = "rbxassetid://9166207943",
        ["star_collector"] = "rbxassetid://9872356516",
        ["styx"] = "rbxassetid://17014536631",
        ["block_kicker"] = "rbxassetid://15382536098",
        ["trapper"] = "rbxassetid://9166206875",
        ["hatter"] = "rbxassetid://12509388633",
        ["ninja"] = "rbxassetid://15517037848",
        ["jailor"] = "rbxassetid://11664116980",
        ["warrior"] = "rbxassetid://9166207008",
        ["mage"] = "rbxassetid://10982191792",
        ["void_dragon"] = "rbxassetid://10982192753",
        ["cat"] = "rbxassetid://15350740470",
        ["wind_walker"] = "rbxassetid://9872355499",
        ['skeleton'] = "rbxassetid://120123419412119",
        ['winter_lady'] = "rbxassetid://83274578564074",
    }

    local enchantImageMap = nil
    local function buildEnchantMap()
        if enchantImageMap then return enchantImageMap end
        enchantImageMap = {}
        task.spawn(function()
            if vape.ThreadFix then setthreadidentity(8) end
            local ok, meta = pcall(function()
                return require(game:GetService('ReplicatedStorage').TS.enchant['enchant-meta'])
            end)
            if not ok or not meta then return end
            for _, subMeta in pairs({meta.EnchantMeta, meta.ToolEnchantMeta, meta.ArmorEnchantMeta}) do
                if type(subMeta) == 'table' then
                    for _, v in pairs(subMeta) do
                        if type(v) == 'table' and v.statusEffect and v.image then
                            enchantImageMap[v.statusEffect] = v.image
                        end
                    end
                end
            end
        end)
        return enchantImageMap
    end

    local function getActiveEnchantImage(char)
        if not char then return '' end
        local map = buildEnchantMap()
        for attr, val in pairs(char:GetAttributes()) do
            if attr:sub(1, 13) == 'StatusEffect_' and type(val) == 'number' and val < 0 then
                local effectName = attr:sub(14)
                if not effectName:find('stacks') then
                    local img = map[effectName]
                    if img and img ~= '' then return img end
                end
            end
        end
        return ''
    end

    local Added = {
        Normal = function(ent)
            if not Targets.Players.Enabled and ent.Player then return end
            if not Targets.NPCs.Enabled and ent.NPC then return end
            if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
            Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

            if Health.Enabled then
                Strings[ent] = Strings[ent] .. ' ' .. math_round(ent.Health)
            end

            if Distance.Enabled then
                Strings[ent] = '[%s] ' .. Strings[ent]
            end
            local textSize = 14 * Scale.Value
            local fontFace = FontOption.Value
            local size = getfontsize(removeTags(Strings[ent]), textSize, fontFace, vector2new(100000, 100000))
            local nametag = Instance.new('TextLabel')
            nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
            nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
            nametag.AnchorPoint = vector2new(0.5, 1)
            nametag.BackgroundColor3 = color3new()
            nametag.BackgroundTransparency = Background.Value
            nametag.BorderSizePixel = 0
            nametag.Visible = false
            nametag.Text = Strings[ent]
            nametag.TextColor3 = entitylib.getEntityColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
            nametag.RichText = true
            nametag.TextSize = textSize
            nametag.FontFace = fontFace
            nametag.Parent = Folder

            if Equipment.Enabled then
                for i, v in { 'Hand', 'Helmet', 'Chestplate', 'Boots' } do
                    local Icon = Instance.new('ImageLabel')
                    Icon.Name = v
                    Icon.Size = udim2fromOffset(30, 30)
                    Icon.Position = udim2fromOffset(-60 + (i * 30), -30)
                    Icon.BackgroundTransparency = 1
                    Icon.Image = ''
                    Icon.Parent = nametag
                end

                if ent.Player and store.inventories[ent.Player] then
                    local inventory = store.inventories[ent.Player]
                    if nametag.Hand then
                        nametag.Hand.Image = bedwars.getIcon(inventory.hand or { itemType = '' }, true)
                    end
                    if nametag.Helmet then
                        nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or { itemType = '' }, true)
                    end
                    if nametag.Chestplate then
                        nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or { itemType = '' }, true)
                    end
                    if nametag.Boots then
                        nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or { itemType = '' }, true)
                    end
                end
            end

            if ShowKits.Enabled and ent.Player then
                local kitIcon = Instance.new('ImageLabel')
                kitIcon.Name = 'KitIcon'
                kitIcon.Size = udim2fromOffset(30, 30)
                kitIcon.AnchorPoint = vector2new(0.5, 0)
                kitIcon.BackgroundTransparency = 1
                kitIcon.Image = ''

                if Equipment.Enabled then
                    kitIcon.Position = udim2fromOffset(110, -30)
                else
                    kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
                end

                kitIcon.Parent = nametag

                local kit = ent.Player:GetAttribute('PlayingAsKits')
                if kit then
                    local kitImage = kitImageIds[kit:lower()]
                    kitIcon.Image = kitImage or kitImageIds["none"]
                    kitCache[ent] = kitImage or kitImageIds["none"]
                else
                    kitIcon.Image = kitImageIds["none"]
                    kitCache[ent] = kitImageIds["none"]
                end
            end

            if Rank.Enabled and ent.Player then
                local rankIcon = Instance.new('ImageLabel')
                rankIcon.Name = 'RankIcon'
                rankIcon.Size = udim2fromOffset(30, 30)
                rankIcon.Position = udim2fromOffset(size.X + 10, -4)
                rankIcon.BackgroundTransparency = 1
                rankIcon.Image = ''
                rankIcon.Parent = nametag

                task.spawn(function()
                    if vape.ThreadFix then setthreadidentity(8) end
                    local plr = playersService:GetPlayerFromCharacter(ent.Character)
                    if not plr then return end

                    local ok, success, data = pcall(function()
                        return bedwars.Client:Get(remotes.Ranks):CallServerAsync({ plr.UserId }):await()
                    end)

                    if vape.ThreadFix then setthreadidentity(8) end

                    if ok and success and type(data) == "table" then
                        local division = data[1] and data[1].rankDivision
                        if division and bedwars.RankMeta and bedwars.RankMeta[division] then
                            rankIcon.Image = bedwars.RankMeta[division].image
                        end
                    end
                end)
            end

            if Enchant.Enabled and ent.Player and ent.Character then
                local Icon = Instance.new('ImageLabel')
                Icon.Name = 'EnchantIcon'
                Icon.Size = udim2fromOffset(30, 30)
                Icon.Position = udim2fromOffset(-30, -4)
                Icon.BackgroundTransparency = 1
                Icon.Image = getActiveEnchantImage(ent.Character)
                Icon.Parent = nametag
                enchantCache[ent] = Icon.Image
                enchantConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
                    if attr:sub(1, 13) == 'StatusEffect_' then
                        local newImage = getActiveEnchantImage(ent.Character)
                        if enchantCache[ent] ~= newImage then
                            Icon.Image = newImage
                            enchantCache[ent] = newImage
                        end
                    end
                end)
            end

            Reference[ent] = nametag
            lastUpdate[ent] = 0
        end,

        Drawing = function(ent)
            if not Targets.Players.Enabled and ent.Player then return end
            if not Targets.NPCs.Enabled and ent.NPC then return end
            if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

            local nametag = {}
            nametag.BG = Drawing.new('Square')
            nametag.BG.Filled = true
            nametag.BG.Transparency = 1 - Background.Value
            nametag.BG.Color = color3new()
            nametag.BG.ZIndex = 1
            nametag.Text = Drawing.new('Text')
            nametag.Text.Size = 15 * Scale.Value
            nametag.Text.Font = 0
            nametag.Text.ZIndex = 2
            Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

            if Health.Enabled then
                Strings[ent] = Strings[ent] .. ' ' .. math_round(ent.Health)
            end

            if Distance.Enabled then
                Strings[ent] = '[%s] ' .. Strings[ent]
            end

            if ShowKits.Enabled and ent.Player then
                local kit = ent.Player:GetAttribute('PlayingAsKits')
                if kit then
                    local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
                    Strings[ent] = Strings[ent] .. ' (' .. kitName .. ')'
                end
            end

            nametag.Text.Text = Strings[ent]
            nametag.Text.Color = entitylib.getEntityColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
            nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
            Reference[ent] = nametag
            lastUpdate[ent] = 0
        end
    }

    local Removed = {
        Normal = function(ent)
            local v = Reference[ent]
            if v then
                Reference[ent] = nil
                Strings[ent] = nil
                Sizes[ent] = nil
                lastUpdate[ent] = nil
                kitCache[ent] = nil
                equipmentCache[ent] = nil
                enchantCache[ent] = nil
                if enchantConnections[ent] then
                    enchantConnections[ent]:Disconnect()
                    enchantConnections[ent] = nil
                end
                v:Destroy()
            end
        end,
        Drawing = function(ent)
            local v = Reference[ent]
            if v then
                Reference[ent] = nil
                Strings[ent] = nil
                Sizes[ent] = nil
                lastUpdate[ent] = nil
                kitCache[ent] = nil
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
            local nametag = Reference[ent]
            if not nametag then return end

            local now = tick()
            if lastUpdate[ent] and (now - lastUpdate[ent]) < 0.2 then return end
            lastUpdate[ent] = now

            Sizes[ent] = nil
            Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

            if Health.Enabled then
                Strings[ent] = Strings[ent] .. ' ' .. math_round(ent.Health)
            end

            if Distance.Enabled then
                Strings[ent] = '[%s] ' .. Strings[ent]
            end

            if Equipment.Enabled and ent.Player and store.inventories[ent.Player] then
                local inventory = store.inventories[ent.Player]
                local currentEquip = {
                    inventory.hand and inventory.hand.itemType or '',
                    inventory.armor[4] and inventory.armor[4].itemType or '',
                    inventory.armor[5] and inventory.armor[5].itemType or '',
                    inventory.armor[6] and inventory.armor[6].itemType or ''
                }

                local equipKey = table.concat(currentEquip, "|")
                if equipmentCache[ent] ~= equipKey then
                    equipmentCache[ent] = equipKey
                    if nametag.Hand then
                        nametag.Hand.Image = bedwars.getIcon(inventory.hand or { itemType = '' }, true)
                    end
                    if nametag.Helmet then
                        nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or { itemType = '' }, true)
                    end
                    if nametag.Chestplate then
                        nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or { itemType = '' }, true)
                    end
                    if nametag.Boots then
                        nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or { itemType = '' }, true)
                    end
                end
            end

            local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
            nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
            nametag.Text = Strings[ent]
        end,

        Drawing = function(ent)
            local nametag = Reference[ent]
            if nametag then
                if vape.ThreadFix then setthreadidentity(8) end
                Sizes[ent] = nil
                Strings[ent] = ent.Player and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

                if Health.Enabled then
                    Strings[ent] = Strings[ent] .. ' ' .. math_round(ent.Health)
                end

                if Distance.Enabled then
                    Strings[ent] = '[%s] ' .. Strings[ent]
                    nametag.Text.Text = entitylib.isAlive and string_format(Strings[ent], math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
                else
                    nametag.Text.Text = Strings[ent]
                end

                if ShowKits.Enabled and ent.Player then
                    local kit = ent.Player:GetAttribute('PlayingAsKits')
                    if kit then
                        local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
                        nametag.Text.Text = nametag.Text.Text .. ' (' .. kitName .. ')'
                    end
                end

                nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
                nametag.Text.Color = entitylib.getEntityColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
            end
        end
    }

    local ColorFunc = {
        Normal = function(hue, sat, val)
            local color = color3fromHSV(hue, sat, val)
            for i, v in Reference do
                v.TextColor3 = entitylib.getEntityColor(i) or color
            end
        end,
        Drawing = function(hue, sat, val)
            local color = color3fromHSV(hue, sat, val)
            for i, v in Reference do
                v.Text.Color = entitylib.getEntityColor(i) or color
            end
        end
    }

    local frameCounter = 0
    Loop = {
        Normal = function()
            frameCounter = frameCounter + 1
            local skipPosition = frameCounter % 2 == 0

            for ent, nametag in Reference do
                if DistanceCheck.Enabled then
                    local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math_huge
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        nametag.Visible = false
                        continue
                    end
                end

                local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
                nametag.Visible = headVis
                if not headVis then continue end

                if skipPosition then
                    nametag.Position = udim2fromOffset(headPos.X, headPos.Y)
                end

                if Distance.Enabled then
                    local mag = entitylib.isAlive and math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
                    if Sizes[ent] ~= mag then
                        nametag.Text = string_format(Strings[ent], mag)
                        local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
                        nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
                        Sizes[ent] = mag
                    end
                end

                if Equipment.Enabled and frameCounter % 30 == 0 then
                    if ent.Player and store.inventories[ent.Player] then
                        local inventory = store.inventories[ent.Player]
                        local currentEquip = {
                            inventory.hand and inventory.hand.itemType or '',
                            inventory.armor[4] and inventory.armor[4].itemType or '',
                            inventory.armor[5] and inventory.armor[5].itemType or '',
                            inventory.armor[6] and inventory.armor[6].itemType or ''
                        }
                        local equipKey = table.concat(currentEquip, "|")
                        if equipmentCache[ent] ~= equipKey then
                            equipmentCache[ent] = equipKey
                            if nametag.Hand then
                                nametag.Hand.Image = bedwars.getIcon(inventory.hand or { itemType = '' }, true)
                            end
                            if nametag.Helmet then
                                nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or { itemType = '' }, true)
                            end
                            if nametag.Chestplate then
                                nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or { itemType = '' }, true)
                            end
                            if nametag.Boots then
                                nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or { itemType = '' }, true)
                            end
                        end
                    end
                end

                if ShowKits.Enabled and frameCounter % 30 == 0 then
                    local kitIcon = nametag:FindFirstChild('KitIcon')
                    if kitIcon and ent.Player then
                        local kit = ent.Player:GetAttribute('PlayingAsKits')
                        local newKitImage = kit and (kitImageIds[kit:lower()] or kitImageIds["none"]) or kitImageIds["none"]
                        if kitCache[ent] ~= newKitImage then
                            kitIcon.Image = newKitImage
                            kitCache[ent] = newKitImage
                        end
                    end
                end
            end
        end,

        Drawing = function()
            frameCounter = frameCounter + 1

            for ent, nametag in Reference do
                if DistanceCheck.Enabled then
                    local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math_huge
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        nametag.Text.Visible = false
                        nametag.BG.Visible = false
                        continue
                    end
                end

                local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
                nametag.Text.Visible = headVis
                nametag.BG.Visible = headVis
                if not headVis then continue end

                if Distance.Enabled then
                    local mag = entitylib.isAlive and math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
                    if Sizes[ent] ~= mag then
                        nametag.Text.Text = string_format(Strings[ent], mag)
                        nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
                        Sizes[ent] = mag
                    end
                end

                nametag.BG.Position = vector2new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
                nametag.Text.Position = nametag.BG.Position + vector2new(4, 3)
            end
        end
    }

    NameTags = vape.Categories.Render:CreateModule({
        Name = 'NameTags',
        Function = function(callback)
            if callback then
                methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
                frameCounter = 0

                if Removed[methodused] then
                    NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
                end

                if Added[methodused] then
                    for _, v in entitylib.List do
                        if Reference[v] then Removed[methodused](v) end
                        Added[methodused](v)
                    end
                    NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                        if Reference[ent] then Removed[methodused](ent) end
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
                lastUpdate = {}
                kitCache = {}
                equipmentCache = {}
                enchantCache = {}
                enchantConnections = {}
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

    ShowKits = NameTags:CreateToggle({
        Name = 'Show Kits',
        Function = function()
            if NameTags.Enabled then
                NameTags:Toggle()
                NameTags:Toggle()
            end
        end,
        Tooltip = 'Shows player kits with icons in nametags'
    })

    Rank = NameTags:CreateToggle({
        Name = 'Rank',
        Tooltip = 'Displays player\'s rank icon',
        Function = function()
            if NameTags.Enabled then
                NameTags:Toggle()
                NameTags:Toggle()
            end
        end
    })

    Enchant = NameTags:CreateToggle({
        Name = 'Enchant',
        Tooltip = 'Displays active weapon enchant icon',
        Default = true,
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

    task.defer(function()
        if DistanceLimit and DistanceLimit.Object then
            DistanceLimit.Object.Visible = false
        end
    end)
end)

run(function()
	local BedAlarm
	local DetectionRange
	local RepeatNotifications
	local NotificationDelay
	local UseDisplayName
	local NotifyKits
	local TepearlCheck
	local TepearlRange
	local HighlightEnemies
	local HighlightColor
	local PlayAlarmSound
	local AlarmSoundId
	local AlarmVolume
	local AlarmActive = false
	local PlayersNearBed = {}
	local LastNotificationTime = {}
	local CachedBed = nil
	local CachedBedPosition = nil
	local LastBedCheck = 0
	local PearlCache = {} 
	local LastPearlCheck = {}
	local ActiveHighlights = {}
	local AlarmSound = nil
	
	local function getKitName(kitId)
		if bedwars.BedwarsKitMeta[kitId] then
			return bedwars.BedwarsKitMeta[kitId].name
		end
		return kitId:gsub("_", " "):gsub("^%l", string.upper)
	end
	
	local function getOwnBed()
		local currentTime = tick()
		
		if CachedBed and CachedBed.Parent and (currentTime - LastBedCheck) < 2 then
			return CachedBed, CachedBedPosition
		end
		
		if not entitylib.isAlive then 
			CachedBed = nil
			CachedBedPosition = nil
			return nil 
		end
		
		local playerTeam = lplr:GetAttribute('Team')
		if not playerTeam then 
			CachedBed = nil
			CachedBedPosition = nil
			return nil 
		end
		
		local tagged = collectionService:GetTagged('bed')
		for _, bed in ipairs(tagged) do
			if bed:GetAttribute('Team'..playerTeam..'NoBreak') then
				CachedBed = bed
				CachedBedPosition = bed.Position
				LastBedCheck = currentTime
				return bed, CachedBedPosition
			end
		end
		
		CachedBed = nil
		CachedBedPosition = nil
		return nil
	end
	
	local function getPlayerName(ent)
		if not ent.Player then return ent.Character.Name end
		return UseDisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name
	end
	
	local function getPlayerKit(ent)
		if not ent.Player then return nil end
		local kit = ent.Player:GetAttribute('PlayingAsKits')
		if kit and kit ~= 'none' then
			return getKitName(kit)
		end
		return nil
	end
	
	local function isHoldingPearl(ent, currentTime)
		if not ent.Player then return false end
		
		local lastCheck = LastPearlCheck[ent] or 0
		if (currentTime - lastCheck) < 0.5 and PearlCache[ent] ~= nil then
			return PearlCache[ent]
		end
		
		local inventory = store.inventories[ent.Player]
		if not inventory then 
			PearlCache[ent] = false
			LastPearlCheck[ent] = currentTime
			return false 
		end
		
		local handItem = inventory.hand
		
		if handItem and handItem.itemType then
			local itemType = handItem.itemType:lower()
			local hasPearl = itemType == 'telepearl' or itemType == 'teleport_pearl' or itemType:find('pearl', 1, true)
			PearlCache[ent] = hasPearl
			LastPearlCheck[ent] = currentTime
			return hasPearl
		end
		
		PearlCache[ent] = false
		LastPearlCheck[ent] = currentTime
		return false
	end
	
	local function createHighlight(ent)
		if not HighlightEnemies.Enabled then return end
		if ActiveHighlights[ent] then return end
		
		local character = ent.Character
		if not character then return end
		
		local highlight = Instance.new("Highlight")
		highlight.Name = "BedAlarmHighlight"
		highlight.Adornee = character
		local hue, sat, val = HighlightColor.Hue, HighlightColor.Sat, HighlightColor.Value
		local color = Color3.fromHSV(hue, sat, val)
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		
		ActiveHighlights[ent] = highlight
	end
	
	local function removeHighlight(ent)
		if ActiveHighlights[ent] then
			ActiveHighlights[ent]:Destroy()
			ActiveHighlights[ent] = nil
		end
	end
	
	local function playAlarm()
		if not PlayAlarmSound.Enabled then return end
		
		if AlarmSound and AlarmSound.Playing then
			return
		end
		
		if not AlarmSound then
			AlarmSound = Instance.new("Sound")
			AlarmSound.Name = "BedAlarmSound"
			AlarmSound.SoundId = "rbxassetid://" .. AlarmSoundId.Value
			AlarmSound.Volume = AlarmVolume.Value / 100
			AlarmSound.Looped = true
			AlarmSound.Parent = workspace
		end
		
		AlarmSound.SoundId = "rbxassetid://" .. AlarmSoundId.Value
		AlarmSound.Volume = AlarmVolume.Value / 100
		AlarmSound:Play()
	end
	
	local function stopAlarm()
		if AlarmSound and AlarmSound.Playing then
			AlarmSound:Stop()
		end
	end
	
	local function createNotification(ent, hasPearl)
		local playerName = getPlayerName(ent)
		local message = playerName..' is near your bed!'
		
		if hasPearl then
			message = playerName..' is near your bed WITH A PEARL!'
		end
		
		if NotifyKits.Enabled then
			local kit = getPlayerKit(ent)
			if kit then
				if hasPearl then
					message = playerName..' is near your bed WITH A PEARL! (Kit: '..kit..')'
				else
					message = playerName..' is near your bed! (Kit: '..kit..')'
				end
			end
		end
		
		notif('Bed Alarm', message, 3)
	end
	
	local lastCheckTime = 0
	local function checkPlayers()
		if not BedAlarm.Enabled then return end
		if not entitylib.isAlive then return end
		
		local currentTime = tick()
		
		if (currentTime - lastCheckTime) < 0.1 then
			return
		end
		lastCheckTime = currentTime
		
		local bed, bedPosition = getOwnBed()
		if not bed or not bedPosition then return end
		
		local currentPlayersNear = {}
		local normalRange = DetectionRange.Value
		local pearlRangeEnabled = TepearlCheck.Enabled
		local pearlRange = pearlRangeEnabled and TepearlRange.Value or normalRange
		
		local normalRangeSq = normalRange * normalRange
		local pearlRangeSq = pearlRange * pearlRange
		
		local anyoneNear = false
		
		for _, ent in ipairs(entitylib.List) do
			if not ent.Targetable then continue end
			
			local distanceVector = ent.RootPart.Position - bedPosition
			local distanceSq = distanceVector.X * distanceVector.X + distanceVector.Y * distanceVector.Y + distanceVector.Z * distanceVector.Z
			
			local hasPearl = false
			local inRange = false
			
			if pearlRangeEnabled and distanceSq <= pearlRangeSq then
				hasPearl = isHoldingPearl(ent, currentTime)
				if hasPearl then
					inRange = true
				end
			end
			
			if not inRange and distanceSq <= normalRangeSq then
				inRange = true
			end
			
			if inRange then
				currentPlayersNear[ent] = true
				anyoneNear = true
				
				createHighlight(ent)
				
				local shouldNotify = false
				
				if not PlayersNearBed[ent] then
					shouldNotify = true
				elseif RepeatNotifications.Enabled then
					local lastTime = LastNotificationTime[ent] or 0
					if currentTime - lastTime >= NotificationDelay.Value then
						shouldNotify = true
					end
				end
				
				if shouldNotify then
					createNotification(ent, hasPearl)
					LastNotificationTime[ent] = currentTime
				end
			else
				removeHighlight(ent)
			end
		end
		
		if anyoneNear then
			playAlarm()
		else
			stopAlarm()
		end
		
		for ent, _ in pairs(ActiveHighlights) do
			if not currentPlayersNear[ent] then
				removeHighlight(ent)
			end
		end
		
		PlayersNearBed = currentPlayersNear
	end
	
	BedAlarm = vape.Categories.Utility:CreateModule({
		Name = 'BedAlarm',
		Function = function(callback)
			if callback then
				local bed = getOwnBed()
				if not bed then
					notif('BedAlarm', 'Cannot locate your bed!', 3)
					BedAlarm:Toggle()
					return
				end
				
				AlarmActive = true
				PlayersNearBed = {}
				LastNotificationTime = {}
				PearlCache = {}
				LastPearlCheck = {}
				ActiveHighlights = {}
				lastCheckTime = 0
				
				BedAlarm:Clean(runService.Heartbeat:Connect(checkPlayers))
			else
				AlarmActive = false
				
				stopAlarm()
				if AlarmSound then
					AlarmSound:Destroy()
					AlarmSound = nil
				end
				
				for ent, highlight in pairs(ActiveHighlights) do
					if highlight then
						highlight:Destroy()
					end
				end
				
				table.clear(PlayersNearBed)
				table.clear(LastNotificationTime)
				table.clear(PearlCache)
				table.clear(LastPearlCheck)
				table.clear(ActiveHighlights)
				CachedBed = nil
				CachedBedPosition = nil
			end
		end,
		Tooltip = 'Alerts you when enemies are near your bed'
	})
	
	DetectionRange = BedAlarm:CreateSlider({
		Name = 'Detection Range',
		Function = function() end,
		Default = 30,
		Min = 10,
		Max = 100,
		Tooltip = 'Distance in studs to detect players near bed'
	})
	
	TepearlCheck = BedAlarm:CreateToggle({
		Name = 'Telepearl Check',
		Function = function(callback)
			if TepearlRange and TepearlRange.Object then
				TepearlRange.Object.Visible = callback
			end
		end,
		Default = false,
		Tooltip = 'Extended detection range for players holding pearls'
	})
	
	TepearlRange = BedAlarm:CreateSlider({
		Name = 'Pearl Range',
		Function = function() end,
		Default = 250,
		Min = 100,
		Max = 500,
		Visible = false,
		Tooltip = 'Detection range for players with pearls'
	})
	
	RepeatNotifications = BedAlarm:CreateToggle({
		Name = 'Repeat Notifications',
		Function = function(callback)
			if NotificationDelay and NotificationDelay.Object then
				NotificationDelay.Object.Visible = callback
			end
		end,
		Default = false,
		Tooltip = 'Continue notifying while players remain near bed'
	})
	
	NotificationDelay = BedAlarm:CreateSlider({
		Name = 'Notification Delay',
		Function = function() end,
		Default = 5,
		Min = 1,
		Max = 10,
		Visible = false,
		Tooltip = 'Seconds between repeat notifications'
	})
	
	UseDisplayName = BedAlarm:CreateToggle({
		Name = 'Show Display Name',
		Function = function() end,
		Default = true,
		Tooltip = 'Show player display names instead of usernames'
	})
	
	NotifyKits = BedAlarm:CreateToggle({
		Name = 'Notify Kits',
		Function = function() end,
		Default = true,
		Tooltip = 'Include player kit in notification'
	})
	
	HighlightEnemies = BedAlarm:CreateToggle({
		Name = 'Highlight Enemies',
		Function = function(callback)
			if HighlightColor and HighlightColor.Object then
				HighlightColor.Object.Visible = callback
			end
			
			if not callback then
				for ent, highlight in pairs(ActiveHighlights) do
					if highlight then
						highlight:Destroy()
					end
				end
				table.clear(ActiveHighlights)
			end
		end,
		Default = false,
		Tooltip = 'Highlight enemies near your bed through walls'
	})
	
	HighlightColor = BedAlarm:CreateColorSlider({
		Name = 'Highlight Color',
		Function = function(hue, sat, val)
			local newColor = Color3.fromHSV(hue, sat, val)
			for ent, highlight in pairs(ActiveHighlights) do
				if highlight then
					highlight.FillColor = newColor
					highlight.OutlineColor = newColor
				end
			end
		end,
		Default = 1,
		Visible = false,
		Tooltip = 'Color of the enemy highlight'
	})
	
	PlayAlarmSound = BedAlarm:CreateToggle({
		Name = 'Play Alarm Sound',
		Function = function(callback)
			if AlarmSoundId and AlarmSoundId.Object then
				AlarmSoundId.Object.Visible = callback
			end
			if AlarmVolume and AlarmVolume.Object then
				AlarmVolume.Object.Visible = callback
			end
			
			if not callback then
				stopAlarm()
			end
		end,
		Default = false,
		Tooltip = 'Play alarm sound when enemies are near bed'
	})
	
	AlarmSoundId = BedAlarm:CreateTextBox({
		Name = 'Alarm Sound ID',
		Function = function(value)
			if AlarmSound then
				AlarmSound.SoundId = "rbxassetid://" .. value
			end
		end,
		Default = '6518811702',
		Visible = false,
		Tooltip = 'Roblox sound asset ID'
	})
	
	AlarmVolume = BedAlarm:CreateSlider({
		Name = 'Alarm Volume',
		Function = function(value)
			if AlarmSound then
				AlarmSound.Volume = value / 100
			end
		end,
		Default = 50,
		Min = 1,
		Max = 100,
		Visible = false,
		Tooltip = 'Volume of the alarm sound'
	})
end)
	
run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local ChestContents = {} 
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getEnabledItemsSet()
		local set = {}
		for _, v in ipairs(List.ListEnabled) do
			set[v] = true
		end
		return set
	end
	
	local function nearStorageItem(item, enabledSet)
		for itemName in pairs(enabledSet) do
			if item:find(itemName, 1, true) then return itemName end
		end
		return nil
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then
			v.Enabled = false
			return
		end
		
		local chestitems = chest:GetChildren()
		local enabledSet = getEnabledItemsSet()
		
		local newItems = {}
		for _, item in ipairs(chestitems) do
			if enabledSet[item.Name] or nearStorageItem(item.Name, enabledSet) then
				newItems[item.Name] = true
			end
		end
		
		local contentsKey = table.concat(table.create(#chestitems, function(i) return chestitems[i].Name end), "|")
		if ChestContents[v] == contentsKey then
			return 
		end
		ChestContents[v] = contentsKey
		
		for _, obj in ipairs(v.Frame:GetChildren()) do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				if not newItems[obj.Name] then
					obj:Destroy()
				else
					newItems[obj.Name] = nil 
				end
			end
		end
		
		v.Enabled = next(newItems) ~= nil or #v.Frame:GetChildren() > 1 
		
		for itemName in pairs(newItems) do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Name = itemName
			blockimage.Size = UDim2.fromOffset(31, 31)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = itemName}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
		if Reference[v] then return end
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(35, 35)
		billboard.AlwaysOnTop = true
		billboard.Adornee = v
		
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = Background.Enabled and (1 - Color.Opacity) or 1
		frame.BorderSizePixel = 0
		frame.Parent = billboard
		
		local uilist = Instance.new('UIListLayout')
		uilist.FillDirection = Enum.FillDirection.Horizontal
		uilist.HorizontalAlignment = Enum.HorizontalAlignment.Left
		uilist.VerticalAlignment = Enum.VerticalAlignment.Top
		uilist.SortOrder = Enum.SortOrder.LayoutOrder
		uilist.Padding = UDim.new(0, 2)
		uilist.Parent = frame
		
		local blur = addBlur(billboard)
		blur.Name = 'Blur'
		blur.Visible = Background.Enabled
		blur.Parent = frame
		
		Reference[v] = billboard
		ChestContents[v] = ""
		
		refreshAdornee(billboard)
	end
	
	local function Removed(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
			ChestContents[v] = nil
		end
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				local tagged = collectionService:GetTagged('chest')
				for _, v in ipairs(tagged) do
					Added(v)
				end
				
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removed))
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(function(chest)
					if Reference[chest] then
						refreshAdornee(Reference[chest])
					end
				end))
				StorageESP:Clean(runService.Heartbeat:Connect(function()
					local now = tick()
					if not StorageESP._lastCleanup or now - StorageESP._lastCleanup < 2 then return end
					StorageESP._lastCleanup = now
					for chest, billboard in pairs(Reference) do
						if not chest or not chest.Parent then
							Removed(chest)
						end
					end
				end))
			else
				for chest in pairs(Reference) do
					Removed(chest)
				end
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			table.clear(ChestContents)
			for _, v in pairs(Reference) do
				refreshAdornee(v)
			end
		end
	})
	
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(Reference) do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				local blur = v.Frame:FindFirstChild('Blur')
				if blur then
					blur.Visible = callback
				end
			end
		end,
		Default = true
	})
	
    Color = StorageESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in pairs(Reference) do
                v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                v.Frame.BackgroundTransparency = 1 - opacity
            end
        end,
        Darker = true
    })

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)
	
run(function()
	local AutoKit
	local Legit
	local Targets
	local Toggles = {}
	local AutoKitFunctions

	local function kitCollection(id, func, range, specific)
		repeat
			if entitylib.isAlive then
				local objs = type(id) == 'table' and id or collection(id, AutoKit)
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= range then
						local success, err = pcall(func, v)
						task.wait(0.05)  
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end

	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})

	Targets = AutoKit:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	Legit = AutoKit:CreateToggle({Name = 'Legit'})

	AutoKitFunctions = {
		spider_queen = function()
			local isAiming = false
			local aimingTarget = nil

			repeat
				if entitylib.isAlive and bedwars.AbilityController then

					if isAiming and (not aimingTarget or not aimingTarget.RootPart) then
						isAiming = false
						aimingTarget = nil
					end

					if not isAiming then
						local target = entitylib.EntityPosition({
							Range = Legit.Enabled and 50 or 80,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Distance
						})

						if target and bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_aim') then
							aimingTarget = target
							bedwars.AbilityController:useAbility('spider_queen_web_bridge_aim')
							isAiming = true
						end
					end

					if isAiming and aimingTarget and aimingTarget.RootPart then
						if bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_fire') then
							local localPosition = entitylib.character.RootPart.Position
							local targetPosition = aimingTarget.RootPart.Position
							local direction = (targetPosition - localPosition).Unit

							bedwars.AbilityController:useAbility('spider_queen_web_bridge_fire', newproxy(true), {
								direction = direction
							})

							isAiming = false
							aimingTarget = nil
							task.wait(0.3)
						end
					end

					if bedwars.AbilityController:canUseAbility('spider_queen_summon_spiders') then
						bedwars.AbilityController:useAbility('spider_queen_summon_spiders')
					end
				end

				task.wait(0.05)
			until not AutoKit.Enabled
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...

				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						if not Legit.Enabled or isHoldingPickaxe() then
							task.spawn(bedwars.breakBlock, block, false, nil, true)
							task.spawn(bedwars.breakBlock, block, false, nil, true)
						end
					end
				end

				return unpack(res)
			end

			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		wizard = function()
			math.randomseed(os.clock() * 1e6)
			local roll = math.random(0, 100)
			repeat
				local ability = lplr:GetAttribute("WizardAbility")
				if not ability then
					task.wait(0.85)
					continue
				end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 32 or 50,
					Part = "RootPart",
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Wallcheck = Targets.Walls.Enabled,
					Sort = sortmethods.Distance
				})

				if not plr or not store.hand.tool then
					task.wait(0.85)
					continue
				end

				local itemType = store.hand.tooltype
				local targetPos = plr.RootPart.Position

				if bedwars.AbilityController:canUseAbility(ability) then
					bedwars.AbilityController:useAbility(ability, newproxy(true), {target = targetPos})
				end

				if itemType == "wizard_staff_2" or itemType == "wizard_staff_3" then
					local plr2 = entitylib.EntityPosition({
						Range = Legit.Enabled and 13 or 20,
						Part = "RootPart",
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Distance
					})
					if plr2 then
						local targetPos2 = plr2.RootPart.Position
						if roll <= 50 then
							if bedwars.AbilityController:canUseAbility("SHOCKWAVE") then
								bedwars.AbilityController:useAbility("SHOCKWAVE", newproxy(true), {target = Vector3.zero})
								roll = math.random(0, 100)
							end
						else
							if bedwars.AbilityController:canUseAbility(ability) then
								bedwars.AbilityController:useAbility(ability, newproxy(true), {target = targetPos2})
								roll = math.random(0, 100)
							end
						end
					end
				end

				if itemType == "wizard_staff_3" then
					local plr3 = entitylib.EntityPosition({
						Range = Legit.Enabled and 12 or 18,
						Part = "RootPart",
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Distance
					})
					if plr3 then
						local targetPos3 = plr3.RootPart.Position
						if roll <= 40 then
							if bedwars.AbilityController:canUseAbility(ability) then
								bedwars.AbilityController:useAbility(ability, newproxy(true), {target = targetPos3})
								roll = math.random(0, 100)
							end
						elseif roll <= 70 then
							if bedwars.AbilityController:canUseAbility("SHOCKWAVE") then
								bedwars.AbilityController:useAbility("SHOCKWAVE", newproxy(true), {target = Vector3.zero})
								roll = math.random(0, 100)
							end
						else
							if bedwars.AbilityController:canUseAbility("LIGHTNING_STORM") then
								bedwars.AbilityController:useAbility("LIGHTNING_STORM", newproxy(true), {target = targetPos3})
								roll = math.random(0, 100)
							end
						end
					end
				end

				task.wait(0.85)
			until not AutoKit.Enabled
		end,
		necromancer = function()
			local r = Legit.Enabled and 8 or 12
			kitCollection('Gravestone', function(v)
				local armorType              = v:GetAttribute('ArmorType')
				local weaponType             = v:GetAttribute('SwordType')
				local associatedPlayerUserId = v:GetAttribute('GravestonePlayerUserId')
				local secret                 = v:GetAttribute('GravestoneSecret')
				local position               = v:GetAttribute('GravestonePosition')

				local ok, result = pcall(function()
					return bedwars.Client:Get(remotes.ActivateGravestone).instance:InvokeServer({
						skeletonData = {
							armorType              = armorType,
							weaponType             = weaponType,
							associatedPlayerUserId = associatedPlayerUserId
						},
						secret   = secret,
						position = position
					})
				end)

				if ok and result and result.success then
					local NecroController = bedwars.Knit.Controllers.NecromancerController
					if NecroController then
						pcall(function()
							NecroController:useGravestone(lplr, v)
						end)
					end
				end
			end, r, false)
		end,
		midnight = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				if bedwars.AbilityController:canUseAbility('midnight') then
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 20 or 30,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Distance
					})

					if plr or not Legit.Enabled then
						bedwars.AbilityController:useAbility('midnight')
						task.wait(0.5)
					end
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
				if Legit.Enabled then
					task.spawn(function()
						local track = bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.FISHING_ROD_PULLING)
						task.wait(3.5)
						pcall(function() if track then track:Stop() end end)
						pcall(function() result({win = true}) end)
					end)
				else
					pcall(function() result({win = true}) end)
				end
			end

			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		sorcerer = function()
			local r = Legit.Enabled and 12 or 16
			kitCollection('alchemy_crystal', function(v)
				bedwars.Client:Get(remotes.CollectCollectableEntity):SendToServer({id = v:GetAttribute("Id"), collectableName = v.Name})
				
				task.wait(0.1)
				
				if not v or not v.Parent then
					pcall(function() bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH) end)
					pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM) end)
					pcall(function() bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST) end)
				end
			end, r, false)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...

				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end

				return unpack(res)
			end

			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		battery = function()
			repeat
				if entitylib.isAlive then
					local overlapParams = OverlapParams.new()
					overlapParams.MaxParts = 0
					
					local range = Legit.Enabled and 6 or 25

					for _, part in workspace:GetPartBoundsInRadius(entitylib.character.RootPart.Position, range, overlapParams) do
						if part:IsA("BasePart") then
							local batteryId = bedwars.BatteryEffectsController:getBatteryIdFromPart(part)
							if batteryId and batteryId ~= 0 then
								local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(batteryId)
								if BatteryInfo then
									local now = workspace:GetServerTimeNow()
									if BatteryInfo.activateTime < now and (BatteryInfo.consumeTime or 0) + 0.5 < now then
										BatteryInfo.consumeTime = now
										pcall(function()
											bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = batteryId})
										end)
									end
								end
							end
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		alchemist = function()
			local r = Legit.Enabled and 8 or 16
			kitCollection('alchemist_ingedients', function(v)
				bedwars.Client:Get(remotes.CollectCollectableEntity):SendToServer({id = v:GetAttribute("Id"), collectableName = v.Name})
			end, r, false)
		end,
		defender = function()
			repeat
				if not entitylib.isAlive then task.wait(0.1); continue end

				local hasScanner = false
				if Legit.Enabled then
					local handItem = lplr.Character:FindFirstChild('HandInvItem')
					hasScanner = handItem and handItem.Value and handItem.Value.Name:find('defense_scanner')
					if not hasScanner then task.wait(0.1); continue end
				end

				local DefenderController = bedwars.Knit.Controllers.DefenderKitController
				if not DefenderController then task.wait(0.1); continue end

				for blockPos, _ in DefenderController.currentSchematic do
					if not AutoKit.Enabled then break end
					if not entitylib.isAlive then break end

					if Legit.Enabled then
						local handItem = lplr.Character:FindFirstChild('HandInvItem')
						local stillHasScanner = handItem and handItem.Value and handItem.Value.Name:find('defense_scanner')
						if not stillHasScanner then break end
					end

					pcall(function()
						DefenderController:requestPlaceDefenderBlock(blockPos)
					end)

					task.wait(Legit.Enabled and 0.3 or 0.05)
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		block_kicker = function()
			local player = game.Players.LocalPlayer
			repeat
				if entitylib.isAlive and bedwars.AbilityController then
					local character = player.Character
					local blockCount = 0
					if character then
						blockCount = character:GetAttribute('BlockKickerKit_BlockCount') or player:GetAttribute('BlockKickerKit_BlockCount') or 0 -- 0 for fallback :D
					else
						blockCount = player:GetAttribute('BlockKickerKit_BlockCount') or 0
					end
					if blockCount <= 2 and bedwars.AbilityController:canUseAbility('BLOCK_STOMP') then
						bedwars.AbilityController:useAbility('BLOCK_STOMP')
						task.wait(0.8)
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				local character = playersService.LocalPlayer.Character
				if not character or not character.PrimaryPart then return end

				bedwars.DragonSlayerController:deleteEmblem(v)

				local playerPos = character:GetPrimaryPartCFrame().Position
				local targetPos = v:GetPrimaryPartCFrame().Position * Vector3.new(1, 0, 1) + Vector3.new(0, playerPos.Y, 0)
				local lookAtCFrame = CFrame.new(playerPos, targetPos)

				character:PivotTo(lookAtCFrame)
				bedwars.DragonSlayerController:playPunchAnimation(lookAtCFrame - lookAtCFrame.Position)
				bedwars.Client:Get(remotes.RequestDragonPunch):SendToServer({target = v})
			end, 18, true)
		end,
		drill = function()
			local userId = lplr.UserId

			repeat
				if entitylib.isAlive then
					local drills = collectionService:GetTagged("Drill")
					for _, drill in ipairs(drills) do
						if drill:GetAttribute("PlacedByUserId") == userId then
							pcall(function()
								bedwars.Client:Get(remotes.ExtractFromDrill).instance:FireServer({ drill = drill })
							end)
						end
					end
				end
				task.wait(0.5)
			until not AutoKit.Enabled
		end,
		hannah = function()
			local range = Legit.Enabled and 12 or 30
			kitCollection('HannahExecuteInteraction', function(victim)
				local success = bedwars.Client:Get(remotes.HannahPromptTrigger).instance:InvokeServer({
					user = lplr,
					victimEntity = victim
				})
				if success then
					local icon = victim:FindFirstChild('Hannah Execution Icon')
					if icon then
						icon:Destroy()
					end
				end
			end, range, true)
		end,
		jailor = function()
			local r = Legit.Enabled and 9 or 20
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, r, false)
		end,
		grim_reaper = function()
			local r = Legit.Enabled and 35 or 120
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({secret = v:GetAttribute('GrimReaperSoulSecret')})
				end
			end, r, false)
		end,
		farmer_cletus = function(sets)
			local r = Legit.Enabled and 6 or 10
			kitCollection('HarvestableCrop', function(v)
				bedwars.Client:Get(remotes.Harvest):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)})
				bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
				bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
				bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
			end, r, false)
		end,
		taliyah = function(sets)
			local r = Legit.Enabled and 6 or 8
			kitCollection('HarvestableCrop', function(v)
				bedwars.Client:Get(remotes.Harvest):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)})
				bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
				bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
				bedwars.SoundManager:playSound(bedwars.SoundList[currentsound] or bedwars.SoundList['CHICKEN_ATTACK_1'])
			end, r, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end

				if ent and getItem('guitar') then
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({healTarget = ent.Character})
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
        mimic = function()
            repeat
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end

                local localPosition = entitylib.character.RootPart.Position
                for _, v in entitylib.List do
                    if v.Targetable and v.Character and v.Player then
                        local distance = (v.RootPart.Position - localPosition).Magnitude
                        if distance <= (Legit.Enabled and 12 or 30) then
                            if collectionService:HasTag(v.Character, "MimicBLockPickPocketPlayer") then
                                pcall(function()
                                    bedwars.Client:Get(remotes.MimicBlockPickPocketPlayer).instance:InvokeServer(v.Player)
                                end)
                                task.wait(0.5)
                            end
                        end
                    end
                end

                task.wait(0.1)
            until not AutoKit.Enabled
        end,
		pinata = function()
			local r = Legit.Enabled and 8 or 18
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get(remotes.DepositCoins):CallServer(v)
				end
			end, r, true)
		end,
		spirit_assassin = function()
			local r = Legit.Enabled and 35 or 120
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, r, true)
		end,
		void_knight = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local currentTier = lplr:GetAttribute('VoidKnightTier') or 0
				local haltedProgress = lplr:GetAttribute('VoidKnightHaltedProgress')

				if haltedProgress then
					task.wait(0.5)
					continue
				end

				if currentTier < 4 then
					if currentTier < 3 then
						local ironAmount = getItem('iron')
						ironAmount = ironAmount and ironAmount.amount or 0
						if ironAmount >= 10 and bedwars.AbilityController:canUseAbility('void_knight_consume_iron') then
							bedwars.AbilityController:useAbility('void_knight_consume_iron')
							task.wait(0.5)
						end
					end

					if currentTier >= 2 and currentTier < 4 then
						local emeraldAmount = getItem('emerald')
						emeraldAmount = emeraldAmount and emeraldAmount.amount or 0
						if emeraldAmount >= 1 and bedwars.AbilityController:canUseAbility('void_knight_consume_emerald') then
							bedwars.AbilityController:useAbility('void_knight_consume_emerald')
							task.wait(0.5)
						end
					end
				end

				if currentTier >= 4 and bedwars.AbilityController:canUseAbility('void_knight_ascend') then
					local shouldAscend = false

					local health = lplr.Character:GetAttribute('Health') or 100
					local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
					if health < (maxHealth * 0.5) then shouldAscend = true end

					if not shouldAscend then
						local plr = entitylib.EntityPosition({
							Range = Legit.Enabled and 30 or 50,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Health
						})
						if plr then shouldAscend = true end
					end

					if shouldAscend then
						bedwars.AbilityController:useAbility('void_knight_ascend')
						task.wait(16)
					end
				end

				task.wait(0.5)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local player = lplr

			local oldFlap = bedwars.VoidDragonController.flapWings
			bedwars.VoidDragonController.flapWings = function(self, ...)
				local result = oldFlap(self, ...)
				if result ~= false and self.inDragonForm then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
				end
				return result
			end

			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldFlap
			end)

			repeat
				if entitylib.isAlive and bedwars.VoidDragonController and bedwars.VoidDragonController.inDragonForm then
					local target = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Distance
					})

					if target and target.RootPart then
						local shouldFire = true
						if Legit.Enabled then
							local myPos = entitylib.character.RootPart.Position
							local myForward = entitylib.character.RootPart.CFrame.LookVector
							local toTarget = (target.RootPart.Position - myPos).Unit
							local dot = myForward:Dot(toTarget)
							local angle = math.acos(dot) * (180 / math.pi) 

							if angle > 90 then
								shouldFire = false
							end
						end

						if shouldFire then
							bedwars.Client:Get(remotes.DragonBreath).instance:FireServer({
								player = player,
								targetPoint = target.RootPart.Position
							})
							task.wait(1) 
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		cactus = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				if bedwars.AbilityController:canUseAbility('cactus_fire') then
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 18 or 40,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Health
					})

					if plr then
						bedwars.AbilityController:useAbility('cactus_fire')
						task.wait(0.5)
					end
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		card = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				if bedwars.AbilityController:canUseAbility('CARD_THROW') then
					local plr = entitylib.EntityPosition({
						Range = Legit.Enabled and 30 or 60,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods.Health
					})

					if plr then
						bedwars.AbilityController:useAbility('CARD_THROW')
						task.wait(0.1)
						pcall(function()
							bedwars.Client:Get(remotes.AttemptCardThrow).instance:FireServer({targetEntityInstance = plr.Character})
						end)
						task.wait(0.5)
					end
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		black_market_trader = function()
			local r = Legit.Enabled and 8 or 16
			kitCollection('shadow_coin', function(v)
				bedwars.Client:Get(remotes.CollectCollectableEntity):SendToServer({id = v:GetAttribute("Id"), collectableName = 'shadow_coin'})
			end, r, false)
		end,
		beekeeper = function()
			local r = Legit.Enabled and 8 or 30
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end, r, false)
		end,
		summoner = function()
			local lastAttackTime = 0
			local attackCooldown = 0.65

			local function getPlayerClawLevel()
				local handItem = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
				if handItem and handItem.Value then
					local itemType = handItem.Value.Name
					if itemType == 'summoner_claw_1' then return 1 end
					if itemType == 'summoner_claw_2' then return 2 end
					if itemType == 'summoner_claw_3' then return 3 end
					if itemType == 'summoner_claw_4' then return 4 end
				end

				if store and store.inventory and store.inventory.hotbar then
					for _, v in pairs(store.inventory.hotbar) do
						if v.item then
							local itemType = v.item.itemType
							if itemType == 'summoner_claw_1' then return 1 end
							if itemType == 'summoner_claw_2' then return 2 end
							if itemType == 'summoner_claw_3' then return 3 end
							if itemType == 'summoner_claw_4' then return 4 end
						end
					end
				end
				return 1 
			end

			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local isCasting = false
				if Legit.Enabled then
					if lplr.Character:GetAttribute("Casting") or
					lplr.Character:GetAttribute("UsingAbility") or
					lplr.Character:GetAttribute("SummonerCasting") then
						isCasting = true
					end

					local humanoid = lplr.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
						isCasting = true
					end
				end

				if Legit.Enabled and isCasting then task.wait(0.1); continue end
				if (workspace:GetServerTimeNow() - lastAttackTime) < attackCooldown then task.wait(0.1); continue end

				local handItem = lplr.Character:FindFirstChild('HandInvItem')
				local hasClaw = handItem and handItem.Value and handItem.Value.Name:find('summoner_claw')
				if not hasClaw then task.wait(0.1); continue end

				local plr = entitylib.EntityPosition({
					Range = Legit.Enabled and 23 or 35,
					Part = 'RootPart',
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Wallcheck = Targets.Walls.Enabled,
					Sort = sortmethods.Health
				})

				if plr and Legit.Enabled and (entitylib.character.RootPart.Position - plr.RootPart.Position).Magnitude > 23 then
					plr = nil
				end

				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)

					lastAttackTime = workspace:GetServerTimeNow()

					pcall(function()
						bedwars.AnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CHARACTER_SWIPE), {looped = false})
					end)

					task.spawn(function()
						pcall(function()
							local clawModel = replicatedStorage.Assets.Misc.Kaida.Summoner_DragonClaw:Clone()
							clawModel.Parent = workspace

							local clawLevel = getPlayerClawLevel()
							local clawColors = {
								Color3.fromRGB(75, 75, 75),    
								Color3.fromRGB(255, 255, 255),  
								Color3.fromRGB(43, 229, 229),   
								Color3.fromRGB(49, 229, 94)     
							}
							local nailMesh = clawModel:FindFirstChild("dragon_claw_nail_mesh")
							if nailMesh and nailMesh:IsA("MeshPart") then
								nailMesh.Color = clawColors[clawLevel] or clawColors[1]
							end

							if bedwars.KnightClient and bedwars.KnightClient.Controllers.SummonerKitSkinController then
								if bedwars.KnightClient.Controllers.SummonerKitSkinController:isPrismaticSkin(lplr) then
									bedwars.KnightClient.Controllers.SummonerKitSkinController:applyClawRGB(clawModel)
								end
							end

							if gameCamera.CFrame.Position and (gameCamera.CFrame.Position - entitylib.character.RootPart.Position).Magnitude < 1 then
								for _, part in clawModel:GetDescendants() do
									if part:IsA('MeshPart') then
										part.Transparency = 0.6
									end
								end
							end

							local rootPart = entitylib.character.RootPart
							local Unit = Vector3.new(shootDir.X, 0, shootDir.Z).Unit
							local startPos = rootPart.Position + Unit:Cross(Vector3.new(0, 1, 0)).Unit * -1 * 5 + Unit * 6
							local direction = (startPos + shootDir * 13 - startPos).Unit
							local cframe = CFrame.new(startPos, startPos + direction)

							clawModel:PivotTo(cframe)
							clawModel.PrimaryPart.Anchored = true

							if clawModel:FindFirstChild('AnimationController') then
								local animator = clawModel.AnimationController:FindFirstChildOfClass('Animator')
								if animator then
									bedwars.AnimationUtil:playAnimation(animator, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CLAW_ATTACK), {looped = false, speed = 1})
								end
							end

							pcall(function()
								local sounds = {
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_1,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_2,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_3,
									bedwars.SoundList.SUMMONER_CLAW_ATTACK_4
								}
								bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)], {position = rootPart.Position})
							end)

							task.wait(0.65)
							clawModel:Destroy()
						end)
					end)

					bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		bigman = function()
			local r = Legit.Enabled and 6 or 10
			kitCollection('treeOrb', function(v)
				if not v or not v.Parent then return end
				local treeOrbSecret = v:GetAttribute('TreeOrbSecret')
				if not treeOrbSecret then return end

				if entitylib.isAlive then
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
					bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end

				local success = bedwars.Client:Get('ConsumeTreeOrb'):CallServer({
					treeOrbSecret = treeOrbSecret
				})

				if success then
					v:Destroy()
				end
			end, r, false)
		end,
		star_collector = function()
			local r = Legit.Enabled and 10 or 18
			local starCooldowns = {}
			local STAR_COOLDOWN = 0.5
			kitCollection('stars', function(v)
				if starCooldowns[v] and tick() - starCooldowns[v] < STAR_COOLDOWN then
					return
				end
				starCooldowns[v] = tick()

				bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
            	bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, r, false)
		end,
		spirit_summoner = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local hasStaff = false
				for _, item in store.inventory.inventory.items do
					if item.itemType == 'spirit_staff' then
						hasStaff = true
						break
					end
				end

				if hasStaff then
					local spiritCount = lplr:GetAttribute('ReadySummonedAttackSpirits') or 0
					if spiritCount < 10 then
						local hasStone = false
						for _, item in store.inventory.inventory.items do
							if item.itemType == 'summon_stone' then
								hasStone = true
								break
							end
						end

						if hasStone and bedwars.AbilityController:canUseAbility('summon_attack_spirit') then
							bedwars.AbilityController:useAbility('summon_attack_spirit')
							task.wait(0.5)
						end
					end
				end

				task.wait(0.2)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			local r = Legit.Enabled and 8 or 10
			kitCollection('hidden-metal', function(v)
				if Legit.Enabled then
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
					bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
				end
				bedwars.Client:Get('CollectCollectableEntity'):SendToServer({id = v:GetAttribute('Id')})
			end, r, false)
		end,
		mage = function()
			local r = Legit.Enabled and 8 or 16
			kitCollection('ElementTome', function(v)
				local secret = v:GetAttribute('TomeSecret')
				if secret then
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
					bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)

					local result = bedwars.Client:Get(remotes.LearnElementTome).instance:InvokeServer({secret = secret})

					if result and result.success then
						v:Destroy()
						task.wait(0.5)
					end
				end
			end, r, false)
		end,
		warlock = function()
			local lastTarget
			local abilityActive = false
			local range = Legit.Enabled and 12 or 30

			repeat
				if not entitylib.isAlive then
					lastTarget = nil
					abilityActive = false
					task.wait(0.1)
					continue
				end

				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = range,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled
					})

					if plr and plr.Character ~= lastTarget then
						if not abilityActive then
							bedwars.AbilityController:useAbility("WARLOCK_LINK")
							abilityActive = true
						end

						local success = pcall(function()
							bedwars.Client:Get(remotes.WarlockTarget):CallServer({
								target = plr.Character
							})
						end)

						if not success then
							plr = nil
							abilityActive = false
						end
					end

					if not plr then
						abilityActive = false
					end

					lastTarget = plr and plr.Character
				else
					lastTarget = nil
					abilityActive = false
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
	}

	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)

run(function()
    local anim
    local asset
    local trackingConnection
    local lastPosition
    local NightmareEmote
    local cachedRootPart
    local cachedHumanoid
    local lastValidationCheck = 0
    
    NightmareEmote = vape.Categories.World:CreateModule({
        Name = "NightmareEmote",
        Function = function(call)
            if call then
                local l__GameQueryUtil__8
                if (not shared.CheatEngineMode) then 
                    l__GameQueryUtil__8 = require(game:GetService("ReplicatedStorage")['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil 
                else
                    local backup = {}; function backup:setQueryIgnored() end; l__GameQueryUtil__8 = backup;
                end
                local l__TweenService__9 = tweenService
                local player = playersService.LocalPlayer
                local character = player.Character
                
                if not character then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                local humanoid = character:WaitForChild("Humanoid")
                local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                
                if not rootPart then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                cachedRootPart = rootPart
                cachedHumanoid = humanoid
                lastPosition = rootPart.Position
                lastValidationCheck = 0
                
                local v10 = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("NightmareEmote"):Clone()
                asset = v10
                v10.Parent = game.Workspace
                
                local descendants = v10:GetDescendants()
                for _, part in ipairs(descendants) do
                    if part:IsA("BasePart") then
                        l__GameQueryUtil__8:setQueryIgnored(part, true)
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                
                local l__Outer__15 = v10:FindFirstChild("Outer")
                if l__Outer__15 then
                    l__TweenService__9:Create(l__Outer__15, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Outer__15.Orientation + Vector3.new(0, 360, 0)
                    }):Play()
                end
                
                local l__Middle__16 = v10:FindFirstChild("Middle")
                if l__Middle__16 then
                    l__TweenService__9:Create(l__Middle__16, TweenInfo.new(12.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Middle__16.Orientation + Vector3.new(0, -360, 0)
                    }):Play()
                end
                
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://9191822700"
                anim = humanoid:LoadAnimation(anim)
                anim:Play()
                
                local movementThresholdSq = 0.1 * 0.1
                
                trackingConnection = runService.RenderStepped:Connect(function()
                    if not asset or not asset.Parent then 
                        if trackingConnection then
                            trackingConnection:Disconnect()
                        end
                        return 
                    end
                    
                    local currentTime = tick()
                    
                    if (currentTime - lastValidationCheck) > 0.5 then
                        if not character or not character.Parent then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        if not cachedRootPart or not cachedRootPart.Parent then
                            cachedRootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                        end
                        
                        if not cachedHumanoid or not cachedHumanoid.Parent then
                            cachedHumanoid = character:FindFirstChildOfClass("Humanoid")
                        end
                        
                        if not cachedRootPart or not cachedHumanoid or cachedHumanoid.Health <= 0 then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastValidationCheck = currentTime
                    end
                    
                    if lastPosition and cachedRootPart then
                        local currentPosition = cachedRootPart.Position
                        local dx = currentPosition.X - lastPosition.X
                        local dy = currentPosition.Y - lastPosition.Y
                        local dz = currentPosition.Z - lastPosition.Z
                        local distanceMovedSq = dx * dx + dy * dy + dz * dz
                        
                        if distanceMovedSq > movementThresholdSq then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastPosition = currentPosition
                    end
                    
                    if cachedRootPart then
                        v10:SetPrimaryPartCFrame(cachedRootPart.CFrame * CFrame.new(0, -3, 0))
                    end
                end)
                
                NightmareEmote:Clean(trackingConnection)
                
            else 
                if trackingConnection then
                    trackingConnection:Disconnect()
                    trackingConnection = nil
                end
                
                if anim then 
                    anim:Stop()
                    anim = nil
                end
                
                if asset then
                    asset:Destroy() 
                    asset = nil
                end
                
                lastPosition = nil
                cachedRootPart = nil
                cachedHumanoid = nil
                lastValidationCheck = 0
            end
        end
    })
end)
	
run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)

run(function()
    local ProximityMaxDistance
    local MaxDistance
    local oldDistances = {}
    local addedConnection
    local removedConnection
    local trackedPrompts = {}
    
    ProximityMaxDistance = vape.Categories.Utility:CreateModule({
        Name = "ProximityExtender",
        Function = function(callback)
            
            if callback then
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                
                local function applyToPrompt(prompt)
                    if not prompt:IsA("ProximityPrompt") then return end
                    if trackedPrompts[prompt] then return end 
                    
                    trackedPrompts[prompt] = true
                    oldDistances[prompt] = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = MaxDistance.Value
                end
                
                local function scanForPrompts(parent)
                    for _, obj in ipairs(parent:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            applyToPrompt(obj)
                        end
                    end
                end
                
                scanForPrompts(workspace)
                
                addedConnection = workspace.DescendantAdded:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        applyToPrompt(obj)
                    end
                end)
                
                removedConnection = workspace.DescendantRemoving:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        oldDistances[obj] = nil
                        trackedPrompts[obj] = nil
                    end
                end)
                
                MaxDistance.Function = function(value)
                    for prompt in pairs(trackedPrompts) do
                        if prompt and prompt.Parent then
                            prompt.MaxActivationDistance = value
                        end
                    end
                end
            else
                if addedConnection then
                    addedConnection:Disconnect()
                    addedConnection = nil
                end
                
                if removedConnection then
                    removedConnection:Disconnect()
                    removedConnection = nil
                end
                
                for prompt, dist in pairs(oldDistances) do
                    if prompt and prompt.Parent then
                        pcall(function()
                            prompt.MaxActivationDistance = dist
                        end)
                    end
                end
                
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                MaxDistance.Function = function() end
            end
        end,
        Tooltip = "Increases the MaxActivationDistance for all ProximityPrompts in the game"
    })
    
    MaxDistance = ProximityMaxDistance:CreateSlider({
        Name = 'Max Distance',
        Min = 10,
        Max = 20,
        Default = 20,
        Tooltip = 'Control the distance it extends'
    })
end)
	
run(function()
	local AutoVoidDrop
	local OwlCheck
	local DropToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil,
		gold = nil
	}
	local cachedLowestPoint
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end

				cachedLowestPoint = math.huge
				for _, v in pairs(store.blocks) do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < cachedLowestPoint then
						cachedLowestPoint = point
					end
				end

				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < cachedLowestPoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for itemType, toggle in pairs(DropToggles) do
									if toggle.Enabled then
										local item = getItem(itemType)
										if item then
											local dropped = bedwars.Client:Get(remotes.DropItem):CallServer({
												item = item.tool,
												amount = item.amount
											})
		
											if dropped then
												dropped:SetAttribute('ClientDropTime', tick() + 100)
											end
										end
									end
								end
								break
							end
						end
					end

					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
	DropToggles.iron = AutoVoidDrop:CreateToggle({
		Name = 'Drop Iron',
		Tooltip = 'Drop iron when falling into void',
		Default = true
	})
	DropToggles.diamond = AutoVoidDrop:CreateToggle({
		Name = 'Drop Diamond',
		Tooltip = 'Drop diamonds when falling into void',
		Default = true
	})
	DropToggles.emerald = AutoVoidDrop:CreateToggle({
		Name = 'Drop Emerald',
		Tooltip = 'Drop emeralds when falling into void',
		Default = true
	})
	DropToggles.gold = AutoVoidDrop:CreateToggle({
		Name = 'Drop Gold',
		Tooltip = 'Drop gold when falling into void',
		Default = true
	})
end)
	
run(function()
	local PickupRange
	local Range
	local Lower
	local Network
	local PickupDelay
	local FastPickup
	local FastPickupDelay
	local lastPickupTime = 0
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				local rangeSquared = Range.Value * Range.Value
				
				if FastPickup.Enabled then
					task.spawn(function()
						repeat
							if entitylib.isAlive then
								local localPosition = entitylib.character.RootPart.Position
								for _, v in items do
									if tick() - (v:GetAttribute('ClientDropTime') or 0) < 0.1 then continue end
									task.spawn(function()
										task.wait(FastPickupDelay.Value)
										if bedwars and bedwars.Client and remotes.PickupItem then
											bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
												itemDrop = v
											}):andThen(function(suc)
												if suc and bedwars.SoundList then
													bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
													local itemMeta = bedwars.ItemMeta[v.Name]
													if itemMeta then
														local sound = itemMeta.pickUpOverlaySound
														if sound then
															bedwars.SoundManager:playSound(sound, {
																position = v.Position,
																volumeMultiplier = 0.9
															})
														end
													end
												end
											end)
										end
									end)
								end
							end
							task.wait(0.05)
						until not PickupRange.Enabled or not FastPickup.Enabled
					end)
				end

				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local humanoidHealth = entitylib.character.Humanoid.Health
						local currentTime = tick()
						local pickupDelaySeconds = PickupDelay.Value / 1000
						rangeSquared = Range.Value * Range.Value

						for _, v in pairs(items) do
							if (currentTime - (v:GetAttribute('ClientDropTime') or 0)) < 2 then continue end
							if (currentTime - lastPickupTime) < pickupDelaySeconds then continue end

							if isnetworkowner(v) and Network.Enabled and humanoidHealth > 0 then
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0))
							end

							local offset = v.Position - localPosition
							local distanceSquared = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

							if distanceSquared <= rangeSquared then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end

								bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
									itemDrop = v
								}):andThen(function(suc)
									if suc then
										lastPickupTime = tick()
										if bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local itemMeta = bedwars.ItemMeta[v.Name]
											if itemMeta then
												local sound = itemMeta.pickUpOverlaySound
												if sound then
													bedwars.SoundManager:playSound(sound, {
														position = v.Position,
														volumeMultiplier = 0.9
													})
												end
											end
										end
									end
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			else
				lastPickupTime = 0
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})

	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	PickupDelay = PickupRange:CreateSlider({
		Name = 'Pickup Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Tooltip = 'Delay between picking up items (milliseconds)',
		Suffix = 'ms'
	})
	Lower = PickupRange:CreateToggle({
		Name = 'Feet Check'
	})
	FastPickup = PickupRange:CreateToggle({
		Name = 'Fast Pickup',
		Default = false,
		Tooltip = 'Instantly picks up all loot in range',
		Function = function(callback)
			if FastPickupDelay and FastPickupDelay.Object then
				FastPickupDelay.Object.Visible = callback
			end
		end
	})
    FastPickupDelay = PickupRange:CreateSlider({
        Name = 'Fast Pickup Delay',
        Min = 0,
        Max = 0.5,
        Default = 0.05,
        Decimal = 100,
        Suffix = 's',
        Tooltip = 'Delay before fast picking up items',
        Visible = false
    })

    task.defer(function()
        if FastPickupDelay and FastPickupDelay.Object then
            FastPickupDelay.Object.Visible = false   
        end
    end)
end)
	
run(function()
	local ShopTierBypass
	local tiered, nexttier = {}, {}
	local originalGetShop
	local shopItemsTracked = {}
	
	local function applyBypassToItem(item)
		if item and type(item) == "table" then
			if not tiered[item] then 
				tiered[item] = item.tiered 
			end
			if not nexttier[item] then 
				nexttier[item] = item.nextTier 
			end
			item.nextTier = nil
			item.tiered = nil
			shopItemsTracked[item] = true
		end
	end
	
	local function applyBypassToTable(tbl)
		if tbl and type(tbl) == "table" then
			for _, item in pairs(tbl) do
				if type(item) == "table" then
					applyBypassToItem(item)
				end
			end
		end
	end
	
	local function getShopController()
		local success, result = pcall(function()
			local RuntimeLib = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
			if RuntimeLib then
				return RuntimeLib.import(script, game:GetService("ReplicatedStorage"), "TS", "games", "bedwars", "shop", "bedwars-shop")
			end
		end)
		
		if success then
			return result
		end
		
		local shopModule = game:GetService("ReplicatedStorage"):FindFirstChild("TS"):FindFirstChild("games"):FindFirstChild("bedwars"):FindFirstChild("shop"):FindFirstChild("bedwars-shop")
		if shopModule and shopModule:IsA("ModuleScript") then
			return require(shopModule)
		end
		
		return nil
	end
	
	ShopTierBypass = vape.Categories.Utility:CreateModule({
		Name = 'ShopTierBypass',
		Function = function(callback)
			if callback then
				local function collectAndBypass()
					local itemsSeen = {}
					if bedwars.Shop and bedwars.Shop.ShopItems then
						for _, v in pairs(bedwars.Shop.ShopItems) do
							itemsSeen[v] = true
						end
					end
					if bedwars.ShopItems then
						for _, v in pairs(bedwars.ShopItems) do
							itemsSeen[v] = true
						end
					end
					
					local shopController = getShopController()
					if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
						local shopTable = shopController.BedwarsShop.getShop()
						if type(shopTable) == "table" then
							for _, v in pairs(shopTable) do
								itemsSeen[v] = true
							end
						end
					end
					for item, _ in pairs(itemsSeen) do
						applyBypassToItem(item)
					end
				end
				collectAndBypass()
				if bedwars.Shop and bedwars.Shop.getShop and not originalGetShop then
					originalGetShop = bedwars.Shop.getShop
					bedwars.Shop.getShop = function(...)
						local result = originalGetShop(...)
						if type(result) == "table" then
							applyBypassToTable(result)
						end
						return result
					end
				end
				
				local shopController = getShopController()
				if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
					if not tiered["shopControllerHooked"] then
						tiered["shopControllerHooked"] = true
						local originalControllerGetShop = shopController.BedwarsShop.getShop
						shopController.BedwarsShop.getShop = function(...)
							local result = originalControllerGetShop(...)
							if type(result) == "table" then
								applyBypassToTable(result)
							end
							return result
						end
					end
				end
			else
				for item, _ in pairs(shopItemsTracked) do
					if item and type(item) == "table" then
						if tiered[item] ~= nil then
							item.tiered = tiered[item]
						end
						if nexttier[item] ~= nil then
							item.nextTier = nexttier[item]
						end
					end
				end
				
				if tiered["shopControllerHooked"] then
					tiered["shopControllerHooked"] = nil
				end
				
				if originalGetShop then
					bedwars.Shop.getShop = originalGetShop
					originalGetShop = nil
				end
				
				table.clear(tiered)
				table.clear(nexttier)
				table.clear(shopItemsTracked)
			end
		end,
		Tooltip = 'Lets you buy things like armor and tools early.'
	})
end)
	
run(function()
	vape.Categories.World:CreateModule({
		Name = 'AntiAFK',
		Function = function(callback)
			if callback then
				pcall(function()
					for _, v in getconnections(lplr.Idled) do
						v:Disconnect()
					end
				end)

				pcall(function()
					for _, v in getconnections(runService.Heartbeat) do
						if type(v.Function) == 'function' then
							local constants = debug.getconstants(v.Function)
							if constants and table.find(constants, remotes.AfkStatus) then
								v:Disconnect()
							end
						end
					end
				end)

				pcall(function()
					local afkRemote = bedwars.Client:Get(remotes.AfkStatus)
					if afkRemote then
						afkRemote:SendToServer({
							afk = false
						})
					end
				end)
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local AutoTool
	local old, event
	
	local function hotbarSwitchItem(block)
		if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
			local itemMeta = bedwars.ItemMeta[block.Name]
			if not itemMeta or not itemMeta.block then return false end
			local tool, slot = store.tools[itemMeta.block.breakType], nil
			local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
			if tool then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
				end
	
				if hotbarSwitch(slot) then
					if event and inputService:IsMouseButtonPressed(0) then 
						event:Fire() 
					end
					return true
				end
			end
		end
	end

	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				event = Instance.new('BindableEvent')
				AutoTool:Clean(event)
				AutoTool:Clean(event.Event:Connect(function()
					pcall(function()
						contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
					end)
				end))
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block
					pcall(function()
						local info = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						block = info and info.target and info.target.blockInstance or nil
					end)
					local switched = false
					pcall(function()
						switched = hotbarSwitchItem(block)
					end)
					if switched then return end
					return old(self, maid, raycastparams, ...)
				end
			else
				bedwars.BlockBreaker.hitBlock = old
				old = nil
			end
		end,
		Tooltip = 'Automatically selects the correct tool'
	})
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local DelayToggle
	local DelaySlider
	local TeamFilter
	local Delays = {}
	
	local function isTeamChest(chest)
		if not TeamFilter.Enabled then return false end
		
		local chestTeam = chest:GetAttribute('Team')
		local myTeam = lplr:GetAttribute('Team')
		
		return chestTeam and myTeam and chestTeam == myTeam
	end
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		if not chest then return end
		
		if isTeamChest(chest) then return end
		
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + (DelayToggle.Enabled and DelaySlider.Value or 0.2)
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					if DelayToggle.Enabled then
						task.wait(DelaySlider.Value / #chestitems) 
					end
					
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
	TeamFilter = ChestSteal:CreateToggle({
		Name = 'Team Chest Filter',
		Tooltip = 'Avoid stealing from your own team\'s chests',
		Default = false
	})
	DelayToggle = ChestSteal:CreateToggle({
		Name = 'Delay',
		Function = function(callback)
			DelaySlider.Object.Visible = callback
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end
	})
    DelaySlider = ChestSteal:CreateSlider({
        Name = 'Delay Time',
        Min = 0.1,
        Max = 5,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false  
        end
    end)
end)
	
run(function()
	local AutoBank
	local UIToggle
	local GUICheck
	local UI
	local Chests
	local Items = {}
	local BankToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil
	}
	local cachedChest
	local lastChestCheck = 0
	local lastHotbarUpdate = 0
	local LootBank
	local LootBankDelay
	local LootBankTeamFilter
	local LootDelays = {}

	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end

	local function refreshBank(echest)
		for i, v in pairs(Items) do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end

	local function nearChest()
		if not entitylib.isAlive then return false end

		local pos = entitylib.character.RootPart.Position
		local maxDistanceSq = 22 * 22

		for _, chest in pairs(Chests) do
			if chest.Parent then
				local offset = chest.Position - pos
				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
				if distanceSq < maxDistanceSq then
					return true
				end
			end
		end

		return false
	end

	local function isEnemyChest(chest)
		if not LootBankTeamFilter.Enabled then return true end
		local chestTeam = chest:GetAttribute('Team')
		local myTeam = lplr:GetAttribute('Team')
		if not chestTeam or not myTeam then return true end
		return chestTeam ~= myTeam
	end

	local function handleState()
		local currentTime = tick()

		if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
			cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
			lastChestCheck = currentTime
		end

		if not cachedChest then return end

		if not nearChest() and not GUICheck.Enabled then
			return
		end

		local itemsToDeposit = {}
		for _, v in ipairs(store.inventory.inventory.items) do
			local itemInfo = Items[v.itemType]
			if itemInfo and BankToggles[v.itemType] and BankToggles[v.itemType].Enabled then
				table.insert(itemsToDeposit, v)
			end
		end

	if #itemsToDeposit > 0 then
		for _, v in ipairs(itemsToDeposit) do
			if v.tool then  
				bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(cachedChest, v.tool)
			end
		end
			task.defer(function()
				if cachedChest and cachedChest.Parent then
					refreshBank(cachedChest)
				end
			end)
		end
	end

	local function handleLootBank(enemyChests)
		if not LootBank.Enabled then return end
		if not entitylib.isAlive then return end
		if not cachedChest or not cachedChest.Parent then return end

		local localPosition = entitylib.character.RootPart.Position
		local delayVal = LootBankDelay.Value

		for _, chestPart in ipairs(enemyChests) do
			if (localPosition - chestPart.Position).Magnitude <= 18 then
				local folderValue = chestPart:FindFirstChild('ChestFolderValue')
				local chest = folderValue and folderValue.Value or nil
				if not chest then continue end
				if not isEnemyChest(chestPart) then continue end

				local chestitems = chest:GetChildren()
				if #chestitems <= 1 then continue end
				if (LootDelays[chest] or 0) >= tick() then continue end

				LootDelays[chest] = tick() + delayVal

				bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
				task.wait(0.05)

				for _, v in ipairs(chestitems) do
					if v:IsA('Accessory') then
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
						task.wait(0.05)
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(cachedChest, v)
						end)
					end
				end

				bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)

				task.defer(function()
					if cachedChest and cachedChest.Parent then
						refreshBank(cachedChest)
					end
				end)
			end
		end
	end

	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('chest', AutoBank)
				cachedChest = nil
				lastChestCheck = 0
				lastHotbarUpdate = 0
				table.clear(LootDelays)

				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 32)
				UI.Position = UDim2.fromOffset(0, -240)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)

				local Sort = Instance.new('UIListLayout')
				Sort.FillDirection = Enum.FillDirection.Horizontal
				Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
				Sort.SortOrder = Enum.SortOrder.LayoutOrder
				Sort.Parent = UI

				addItem('iron', true)
				addItem('diamond', false)
				addItem('emerald', true)

				local cachedHotbar
				local guiInset = guiService:GetGuiInset().Y

				repeat
					local currentTime = tick()

					if (currentTime - lastHotbarUpdate) > 0.5 then
						local playerGui = lplr.PlayerGui
						if playerGui then
							local hotbar = playerGui:FindFirstChild('hotbar')
							if hotbar then
								local container = hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
								if container then
									cachedHotbar = container
									UI.Position = UDim2.fromOffset(0, (container.AbsolutePosition.Y + guiInset) - 40)
									lastHotbarUpdate = currentTime
								end
							end
						end
					end

					local shouldBank = false

					if GUICheck.Enabled then
						shouldBank = bedwars.AppController:isAppOpen('ChestApp') or
						             bedwars.AppController:isAppOpen('BedwarsAppIds.CHEST_INVENTORY')
					else
						shouldBank = nearChest()
					end

					if shouldBank then
						handleState()
					end

					if LootBank.Enabled then
						handleLootBank(Chests)
					end

					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
				table.clear(LootDelays)
				cachedChest = nil
			end
		end,
		Tooltip = 'automatically puts resources in ender chest'
	})

	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled and UI then
				UI.Visible = callback
			end
		end,
		Default = true
	})

	GUICheck = AutoBank:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'only banks when chest is open (bypasses distance limit)'
	})

	BankToggles.iron = AutoBank:CreateToggle({
		Name = 'Bank Iron',
		Tooltip = 'auto bank iron',
		Default = true
	})

	BankToggles.diamond = AutoBank:CreateToggle({
		Name = 'Bank Diamond',
		Tooltip = 'auto bank diamonds',
		Default = true
	})

	BankToggles.emerald = AutoBank:CreateToggle({
		Name = 'Bank Emerald',
		Tooltip = 'auto bank emeralds',
		Default = true
	})

	LootBank = AutoBank:CreateToggle({
		Name = 'Rob',
		Tooltip = 'takes loot from enemy chests nearby and sends it straight to ur bank',
		Function = function(callback)
			if LootBankDelay then LootBankDelay.Object.Visible = callback end
			if LootBankTeamFilter then LootBankTeamFilter.Object.Visible = callback end
			if not callback then table.clear(LootDelays) end
		end,
		Default = false
	})

	LootBankDelay = AutoBank:CreateSlider({
		Name = 'Rob Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 's',
		Tooltip = 'cooldown per chest so u dont spam it',
		Visible = false
	})

    LootBankTeamFilter = AutoBank:CreateToggle({
        Name = 'Skip Team Chests',
        Tooltip = 'never rob ur own team fr',
        Default = true,
        Visible = false
    })

    task.defer(function()
        if LootBankDelay and LootBankDelay.Object then
            LootBankDelay.Object.Visible = false
        end
        if LootBankTeamFilter and LootBankTeamFilter.Object then
            LootBankTeamFilter.Object.Visible = false
        end
    end)
end)
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Client:Get(remotes.BedwarsPurchaseItem):CallServerAsync({
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
	local function buyUpgrade(upgradeType, currencytable)
		if not Upgrades.Enabled then return end
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local bought = false
	
		for i = currentTier, #upgrade.tiers do
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
	
			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
				currencytable.diamond -= tier.cost
				bought = true
			else
				break
			end
		end
	
		return bought
	end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	local KeepBuying = AutoBuy:CreateToggle({
		Name = 'Keep Buying',
		Tooltip = 'Always buys the set amount from item list, ignoring current inventory',
		Function = function(callback)
			if callback then
				npctick = tick()
			end
		end
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/skip50',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					local isPost = tab[4] and tab[4]:lower():find('after')
					local skipAmount = tab[4] and tonumber(tab[4]:match('%d+')) or nil
					
					(isPost and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
						if not store.shopLoaded then return end
						
						local success, v = pcall(function()
							return bedwars.Shop.getShopItem(tab[2], lplr)
						end)
						
						if not success or not v then
							return false
						end
						
						local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
						local currentAmount = item and item.amount or 0
						local targetAmount = tonumber(tab[3])
						
						if tab[2] == 'arrow' and skipAmount then
							local hasBow = getBow()
							local hasCrossbow = getItem('crossbow')
							local hasHeadhunter = getItem('headhunter_bow')
							if not (hasBow or hasCrossbow or hasHeadhunter) then
								return false
							end
						end
						
						if KeepBuying.Enabled then
							local purchasesNeeded = math.ceil(targetAmount / v.amount)
							
							if purchasesNeeded > 0 and canBuy(v, currencytable, purchasesNeeded) then
								for _ = 1, purchasesNeeded do
									buyItem(v, currencytable)
								end
								return true
							end
						else
							local needToBuy = math.max(0, targetAmount - currentAmount)
							
							if needToBuy <= 0 then
								return false
							end

							if skipAmount and currentAmount >= skipAmount then
								return false
							end
							
							local purchasesNeeded = math.ceil(needToBuy / v.amount)
							
							if canBuy(v, currencytable, purchasesNeeded) then
								for _ = 1, purchasesNeeded do
									buyItem(v, currencytable)
								end
								return true
							end
						end
						
						return false
					end
				end
			end
		end
	})
end)
	
run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					for _ = 1, 4 do
						if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
					end
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
					
					if apple then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = apple.tool
						})
					end
				end
			end
	
			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = shield.tool
						})
					end
				end
			end
		end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						consumeCheck(attribute)
					end
				end))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
end)
	
run(function()
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('newvape/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getcustomasset('newvape/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getcustomasset('newvape/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		textbutton.MouseButton1Click:Connect(function()
			optionapi:AddHotbar()
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		function optionapi:AddHotbar(data)
			local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('newvape/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'Automatically arranges hotbar to your liking.'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)

run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = tick()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
					
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
				oldclickhold = nil
				oldshowprogress = nil
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)
	
run(function()
	local FastDrop
	local DropDelay
	local ItemList
	local lastDropTime = 0
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				lastDropTime = 0
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						if tick() - lastDropTime >= (DropDelay.Value / 1000) then
							local handItem = store.hand and store.hand.tool
							if handItem then
								local itemType = handItem.Name
								local listEnabled = ItemList.ListEnabled
								
								local shouldDrop = true
								if #listEnabled > 0 then
									shouldDrop = table.find(listEnabled, itemType) ~= nil
								end
								
								if shouldDrop then
									task.spawn(bedwars.ItemDropController.dropItemInHand)
									lastDropTime = tick()
								end
							end
							task.wait()
						else
							task.wait(0.01)
						end
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			else
				lastDropTime = 0
			end
		end,
		Tooltip = 'Drops items fast'
	})
	
	DropDelay = FastDrop:CreateSlider({
		Name = 'Drop Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Tooltip = 'Delay between drops (milliseconds)',
		Suffix = 'ms'
	})
	
	ItemList = FastDrop:CreateTextList({
		Name = 'Item Whitelist',
		Placeholder = 'Item name (e.g., wool_blue)',
		Tooltip = 'Only drop these items (leave empty to drop all)\nUse item meta names like: wool_blue, iron, diamond'
	})
end)
	
run(function()
    local BedPlates
    local Background
    local TeamColor
    local Color = {}
    local Reference = {}
    local BlockCache = {} 
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    
	local teamColors = {
		[1] = {name = "Blue",   color = Color3.fromRGB(85, 150, 255)},
		[2] = {name = "Orange", color = Color3.fromRGB(255, 150, 50)},
		[3] = {name = "Pink",   color = Color3.fromRGB(255, 100, 200)},
		[4] = {name = "Yellow", color = Color3.fromRGB(255, 255, 50)}
	}
    
    local function getBedTeamColor(bed)
        local teamId = bed:GetAttribute('TeamID')
        if teamId and teamColors[teamId] then
            return teamColors[teamId]
        end
        return Color3.new(1, 1, 1)
    end
    
    local function scanSide(self, start, tab)
        for _, side in ipairs(sides) do
            for i = 1, 15 do
                local block = getPlacedBlock(start + (side * i))
                if not block or block == self then break end
                if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
                    table.insert(tab, block.Name)
                end
            end
        end
    end
    
    local function refreshAdornee(v)
        local start = v.Adornee.Position
        
        local newBlocks = {}
        scanSide(v.Adornee, start, newBlocks)
        scanSide(v.Adornee, start + Vector3.new(0, 0, 3), newBlocks)
        
        table.sort(newBlocks, function(a, b)
            local aMeta = bedwars.ItemMeta[a]
            local bMeta = bedwars.ItemMeta[b]
            local aHealth = aMeta and aMeta.block and aMeta.block.health or 0
            local bHealth = bMeta and bMeta.block and bMeta.block.health or 0
            return aHealth > bHealth
        end)
        
        local blockKey = table.concat(newBlocks, ",")
        
        if BlockCache[v] == blockKey then
            v.Enabled = #newBlocks > 0
            return
        end
        BlockCache[v] = blockKey
        
        local children = v.Frame:GetChildren()
        for _, obj in ipairs(children) do
            if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
                obj:Destroy()
            end
        end
        
        v.Enabled = #newBlocks > 0
        
        for _, block in ipairs(newBlocks) do
            local blockimage = Instance.new('ImageLabel')
            blockimage.Size = UDim2.fromOffset(32, 32)
            blockimage.BackgroundTransparency = 1
            blockimage.Image = bedwars.getIcon({itemType = block}, true)
            blockimage.Parent = v.Frame
        end
    end
    
    local function Added(v)
        if Reference[v] then return end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'bed'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = TeamColor.Enabled and getBedTeamColor(v) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        frame.BackgroundTransparency = 1 - (Background.Enabled and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
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
        BlockCache[v] = ""
        refreshAdornee(billboard)
    end
    
    local function refreshNear(data)
        local blockPos = data.blockRef.blockPosition * 3
        local maxDistanceSq = 30 * 30 
        
        for bed, billboard in pairs(Reference) do
            if bed.Parent then
                local offset = blockPos - bed.Position
                local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
                
                if distanceSq <= maxDistanceSq then
                    refreshAdornee(billboard)
                end
            end
        end
    end
    
    BedPlates = vape.Categories.Minigames:CreateModule({
        Name = 'BedPlates',
        Function = function(callback)
            if callback then
                table.clear(BlockCache)
                
                local tagged = collectionService:GetTagged('bed')
                for _, v in ipairs(tagged) do 
                    Added(v)
                end
                
                BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
                BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
                    if Reference[v] then
                        Reference[v]:Destroy()
                        Reference[v] = nil
                        BlockCache[v] = nil
                    end
                end))
            else
                for _, v in pairs(Reference) do
                    v:Destroy()
                end
                table.clear(Reference)
                table.clear(BlockCache)
            end
        end,
        Tooltip = 'Displays blocks over the bed'
    })
    
    Background = BedPlates:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then 
                Color.Object.Visible = callback and not TeamColor.Enabled
            end
            for _, v in pairs(Reference) do
                v.Frame.BackgroundTransparency = 1 - (callback and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
                local blur = v:FindFirstChild('Blur')
                if blur then
                    blur.Visible = callback
                end
            end
        end,
        Default = true
    })
    
    TeamColor = BedPlates:CreateToggle({
        Name = 'Team Color',
        Tooltip = 'Use bed team color instead of custom color',
        Default = true,
        Function = function(callback)
            if Color.Object then
                Color.Object.Visible = Background.Enabled and not callback
            end
            for bed, billboard in pairs(Reference) do
                billboard.Frame.BackgroundColor3 = callback and getBedTeamColor(bed) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and (callback and 0.5 or Color.Opacity) or 0)
            end
        end
    })
    
    Color = BedPlates:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for bed, v in pairs(Reference) do
                if not TeamColor.Enabled then
                    v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                end
                if Background.Enabled and not TeamColor.Enabled then
                    v.Frame.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Visible = false,
        Darker = true
    })
end)

local function safeIsBreakable(pos)
    if not bedwars.BlockController then return false end
    local ok, result = pcall(function()
        return bedwars.BlockController:isBlockBreakable({blockPosition = pos / 3}, lplr)
    end)
    return ok and result
end
	
run(function()
	local Breaker
	local Delay
	local Range
	local UpdateRate
	local Bed
	local Tesla
	local Hive
	local IronOre
	local Pinata
	local LuckyBlock
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local AutoTool
	local LimitItem
	local MouseDown
	local parts = {}
	local tempSortTable = {}

	local function isSameTeam(userId)
		if not userId then return false end
		local localTeam = lplr:GetAttribute('Team')
		if not localTeam then return false end
		for _, player in playersService:GetPlayers() do
			if player.UserId == userId and player:GetAttribute('Team') == localTeam then
				return true
			end
		end
		return false
	end

	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if block:GetAttribute('NoHealthbar') then return end
		if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
			self.healthbarMaid:DoCleaning()
			self.healthbarBlockRef = blockRef
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			self.healthbarPart = part
			bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)

			local mounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('newvape/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = self.healthbarProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)

			self.healthbarMaid:GiveTask(function()
				cleanCheck = false
				self.healthbarBlockRef = nil
				bedwars.Roact.unmount(mounted)
				if self.healthbarPart then
					self.healthbarPart:Destroy()
				end
				self.healthbarPart = nil
			end)

			bedwars.RuntimeLib.Promise.delay(5):andThen(function()
				if cleanCheck then
					self.healthbarMaid:DoCleaning()
				end
			end)
		end

		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1),
			BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end

	local hit = 0

	local function passesChecks(v)
		local placedBy = v:GetAttribute('PlacedByUserId')
		if not SelfBreak.Enabled then
			if placedBy == lplr.UserId then return false end
			if isSameTeam(placedBy) then return false end
		else
			if placedBy == lplr.UserId and (v.Name == 'bed' or v.Name == 'team_chest') then return false end
		end
		if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then return false end
		if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then return false end
		return true
	end

	local function doBreak(block)
		hit += 1
		local target, path, endpos = bedwars.breakBlock(block, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, AutoTool.Enabled)
		if path then
			local currentnode = target
			for _, part in parts do
				part.Position = currentnode or Vector3.zero
				if currentnode then
					part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
				end
				currentnode = path[currentnode]
			end
		end
		task.wait(Delay.Value)
		return true
	end

	local function attemptBreakBed(beds, localPosition)
		if not beds then return false end
		if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end

		local closestBed, closestDist = nil, math.huge
		for _, bedModel in ipairs(beds) do
			local dist = (bedModel.Position - localPosition).Magnitude
			if dist <= Range.Value and dist < closestDist then
				closestDist = dist
				closestBed = bedModel
			end
		end
		if not closestBed then return false end

		local bedBlock = getPlacedBlock(closestBed.Position)
		if not bedBlock then return false end

		if bedwars.BlockController:isBlockBreakable({blockPosition = bedBlock.Position / 3}, lplr) and passesChecks(bedBlock) then
			for i, part in ipairs(parts) do
				if i == 1 then
					part.Position = bedBlock.Position
					part.BoxHandleAdornment.Color3 = Color3.new(1, 0, 0)
				else
					part.Position = Vector3.zero
				end
			end
			return doBreak(bedBlock)
		end
		return false
	end

	local function attemptBreakTargets(localPosition)
		if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end

		local hasTargets = (Tesla and Tesla.Enabled) or (Hive and Hive.Enabled) or (IronOre and IronOre.Enabled) or (Pinata and Pinata.Enabled)
		if not hasTargets then return false end

		table.clear(tempSortTable)
		for _, v in store.blocks do
			if not v or not v:IsA('BasePart') then continue end
			local name = v.Name
			local included = (Tesla.Enabled and name == 'tesla_trap')
				or (Hive.Enabled and name == 'beehive')
				or (IronOre.Enabled and name == 'iron_ore_mesh_block')
				or (Pinata.Enabled and name == 'pinata')
			if not included then continue end
			local dist = (v.Position - localPosition).Magnitude
			if dist <= Range.Value then
				table.insert(tempSortTable, v)
			end
		end

		if #tempSortTable == 0 then return false end

		table.sort(tempSortTable, function(a, b)
			return (a.Position - localPosition).Magnitude < (b.Position - localPosition).Magnitude
		end)

		for _, v in tempSortTable do
			if v.Name ~= 'iron_ore_mesh_block' then
				if not bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then continue end
				if not passesChecks(v) then continue end
			end
			return doBreak(v)
		end

		return false
	end

	local function attemptBreak(tab, localPosition)
		if not tab then return false end
		if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end

		table.clear(tempSortTable)
		for _, v in tab do
			local dist = (v.Position - localPosition).Magnitude
			if dist <= Range.Value then
				table.insert(tempSortTable, v)
			end
		end

		if #tempSortTable == 0 then return false end

		table.sort(tempSortTable, function(a, b)
			return (a.Position - localPosition).Magnitude < (b.Position - localPosition).Magnitude
		end)

		for _, v in tempSortTable do
			if not bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then continue end
			if not passesChecks(v) then continue end
			return doBreak(v)
		end

		return false
	end

	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				if #parts == 0 then
					for _ = 1, 30 do
						local part = Instance.new('Part')
						part.Anchored = true
						part.CanQuery = false
						part.CanCollide = false
						part.Transparency = 1
						part.Parent = gameCamera
						local highlight = Instance.new('BoxHandleAdornment')
						highlight.Size = Vector3.one
						highlight.AlwaysOnTop = true
						highlight.ZIndex = 1
						highlight.Transparency = 0.5
						highlight.Adornee = part
						highlight.Parent = part
						table.insert(parts, part)
					end
				end

				local beds        = collection('bed', Breaker)
				local luckyblocks = collection('LuckyBlock', Breaker)

				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end

					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position

						if Bed.Enabled and attemptBreakBed(beds, localPosition) then continue end
						if attemptBreakTargets(localPosition) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblocks, localPosition) then continue end

						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Breaker.Enabled
			else
				for _, v in parts do
					v.Parent = nil
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})

	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = Breaker:CreateSlider({
		Name = 'Break Delay',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	Tesla = Breaker:CreateToggle({
		Name = 'Break Tesla',
		Default = true
	})
	Hive = Breaker:CreateToggle({
		Name = 'Break Hive',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = false
	})
	Pinata = Breaker:CreateToggle({
		Name = 'Break Pinata',
		Default = false
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({Name = 'Animation'})
	SelfBreak = Breaker:CreateToggle({
		Name = 'Self Break',
		Tooltip = "When OFF: never breaks your own or any teammate's blocks. When ON: can break your own placed blocks (still skips beds/chests)."
	})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Tooltip = 'Automatically switches to the best tool for breaking blocks'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
	MouseDown = Breaker:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'Only breaks blocks when holding left click'
	})

	task.defer(function()
		if CustomHealth and CustomHealth.Object then
			CustomHealth.Object.Visible = Effect.Enabled
		end
	end)
end)
	
run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Categories.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self) 
					return old(self, Value.Value) 
				end
				bedwars.FovController.getFOV = function() 
					return Value.Value 
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
			
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	local originalAddGameNametag
	local nametagHooked = false
	
	FPSBoost = vape.Categories.BoostFPS:CreateModule({
		Name = 'FPSBoost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end

				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end

				-- REMOVED NAMETAG 
				--[[
				if not nametagHooked then
					originalAddGameNametag = bedwars.NametagController.addGameNametag
					bedwars.NametagController.addGameNametag = function(player, ...)
						if player == lplr then
							return originalAddGameNametag(player, ...)
						end
						return
					end
					nametagHooked = true
				end
				
				if bedwars.AppController then
					for _, v in bedwars.AppController:getOpenApps() do
						if v and v.app then
							local appName = tostring(v.app)
							if appName:find('Nametag') or (v.getDisplayName and tostring(v.getDisplayName()):find('Nametag')) then
								local isLocalPlayer = false
								
								if v.player and v.player == lplr then
									isLocalPlayer = true
								elseif appName:find(lplr.Name) or appName:find('LocalPlayer') then
									isLocalPlayer = true
								elseif v.getPlayer and v.getPlayer() == lplr then
									isLocalPlayer = true
								end
								
								if not isLocalPlayer then
									bedwars.AppController:closeApp(v)
								end
							end
						end
					end
				end
				]]--
			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				
				if nametagHooked and originalAddGameNametag then
					bedwars.NametagController.addGameNametag = originalAddGameNametag
					nametagHooked = false
				end
				
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'Improves the framerate by turning off certain effects'
	})
	
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)

run(function()
    HitFix = vape.Categories.Legit:CreateModule({
        Name = 'HitFix',
		Function = function(callback)
			debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
			debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
		end,
		Tooltip = 'Changes the raycast function to the correct one'
	})
end)

run(function() 
    local MatchHistory
    
    MatchHistory = vape.Categories.Utility:CreateModule({
        Name = "ClearMatchHistory",
        Tooltip = "Resets ur match history",
        Function = function(callback)
            
            if callback then 
                MatchHistory:Toggle(false)
                local TeleportService = game:GetService("TeleportService")
                local data = TeleportService:GetLocalPlayerTeleportData()
                TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer, data)
            end
        end,
    }) 
end)

run(function()
	local ViewMatchHistory
	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local d = nil
				bedwars.MatchHistroyController:requestMatchHistory(lplr.Name):andThen(function(Data)
					if Data then
						bedwars.AppController:openApp({app = bedwars.MatchHistroyApp,appId = "MatchHistoryApp",},Data)
					end
				end)
			else
				return
			end
		end,
		Tooltip = "matchhisory"
	})																								
end)

run(function()
    local InvisibleCursor = {}
    local isActive = false
    local renderConnection
    local ViewMode = {Value = 'First Person'}
    local LimitToItems = {Enabled = false}
    local ShowOnGUI = {Enabled = false}
    local lastCursorState = nil
    
    local function hasBowEquipped()
        if not store.hand or not store.hand.tool then
            return false
        end
        
        local toolName = store.hand.tool.Name:lower()
        return toolName:find('bow') ~= nil or toolName:find('crossbow') ~= nil
    end
    
    local function shouldHideCursor()
        if not isActive then return false end
        
        if ShowOnGUI.Enabled and isGUIOpen() then
            return false
        end
        
        if LimitToItems.Enabled and not hasBowEquipped() then
            return false
        end
        
        local inFirstPerson = isFirstPerson()
    
        if ViewMode.Value == 'First Person' then
            return inFirstPerson
        elseif ViewMode.Value == 'Third Person' then
            return not inFirstPerson
        elseif ViewMode.Value == 'Both' then
            return true
        end
        
        return false
    end
    
    local function updateCursor()
        local shouldHide = shouldHideCursor()
        
        if lastCursorState == shouldHide then
            return 
        end
        
        lastCursorState = shouldHide
        inputService.MouseIconEnabled = not shouldHide
    end
    
    InvisibleCursor = vape.Categories.Utility:CreateModule({
        Name = 'InvisibleCursor',
        Function = function(callback)
            if callback then
                isActive = true
                lastCursorState = nil
                
                if renderConnection then
                    renderConnection:Disconnect()
                end
                
				renderConnection = runService.RenderStepped:Connect(updateCursor)
				InvisibleCursor:Clean(renderConnection)

				InvisibleCursor:Clean(vapeEvents.InventoryChanged.Event:Connect(updateCursor))
            else
                isActive = false
                
                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end
                
                inputService.MouseIconEnabled = true
                lastCursorState = nil
            end
        end,
        Tooltip = 'Hides cursor based on view mode and item settings'
    })
    
    ViewMode = InvisibleCursor:CreateDropdown({
        Name = 'View Mode',
        List = {'First Person', 'Third Person', 'Both'},
        Default = 'First Person',
        Tooltip = 'Choose when to hide cursor\nFirst Person: Only in 1st person\nThird Person: Only in 3rd person\nBoth: Always hide',
        Function = function(val)
            ViewMode.Value = val
            updateCursor()
        end
    })
    
    LimitToItems = InvisibleCursor:CreateToggle({
        Name = 'Limit to Bow',
        Default = false,
        Tooltip = 'Only hide cursor when holding a bow/crossbow',
        Function = function(val)
            LimitToItems.Enabled = val
            updateCursor()
        end
    })
    
    ShowOnGUI = InvisibleCursor:CreateToggle({
        Name = 'Show on GUI',
        Default = false,
        Tooltip = 'Show cursor when any GUI is open (inventory, shop, etc)',
        Function = function(val)
            ShowOnGUI.Enabled = val
            updateCursor()
        end
    })
end)

run(function()
    local BCR
    local Value
    local CpsConstants = nil
    
    BCR = vape.Categories.Blatant:CreateModule({
        Name = "BlockCPSRemover",
        Function = function(callback)
            
            if callback then
                task.wait(1)
                
                pcall(function()
                    CpsConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants
                end)
                
                if not CpsConstants then
                    pcall(function()
                        CpsConstants = bedwars.CpsConstants
                    end)
                end
                
                if CpsConstants then
                    local newCPS = Value.Value == 0 and 1000 or Value.Value
                    CpsConstants.BLOCK_PLACE_CPS = newCPS
                    
                    if isMobile then
                        for _, v in {'2', '5'} do
                            pcall(function()
                                BCR:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(function()
                                    if CpsConstants then
                                        local currentValue = Value.Value == 0 and 1000 or Value.Value
                                        CpsConstants.BLOCK_PLACE_CPS = currentValue
                                    end
                                end))
                            end)
                        end
                    end
                    
                    task.spawn(function()
                        while BCR.Enabled do
                            local currentValue = Value.Value == 0 and 1000 or Value.Value
                            if CpsConstants.BLOCK_PLACE_CPS ~= currentValue then
                                CpsConstants.BLOCK_PLACE_CPS = currentValue
                            end
                            task.wait(0.3)
                        end
                    end)
                end
                
            else
                if CpsConstants then
                    CpsConstants.BLOCK_PLACE_CPS = 12
                end
            end
        end,
        Tooltip = 'Simple CPS modifier (Mobile + Desktop)'
    })
    
    Value = BCR:CreateSlider({
        Name = "CPS Limit",
        Suffix = "CPS",
        Tooltip = "Higher = faster but more ghost blocks",
        Default = 12,
        Min = 12,
        Max = 20,
        Function = function()
            if BCR.Enabled and CpsConstants then
                local newCPS = Value.Value == 0 and 1000 or Value.Value
                CpsConstants.BLOCK_PLACE_CPS = newCPS
            end
        end,
    })
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local AlertDuration
	local ClosetDetect
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local blacklistedusernames = {
		['phantomviperr2'] = true,
		['gavin2015shadow'] = true,
		['clocksurge'] = true,
		['amcoolll3'] = true,
		['zorflow'] = true,
		['dreamingnostaigia'] = true,
		['featheredtwilight'] = true,
		['imabot122356'] = true,
		['hobyboynum'] = true,
	}
	local teamNameMap = { [1] = 'Blue', [2] = 'Orange', [3] = 'Pink', [4] = 'Yellow' }
	local joined = {}
	local detectedPlayers = {}
	local processing = {}

	getgenv()._aerov4_staffCounts = {spec=0, closet=0, mod=0, impossible=0}
	local function refreshStaffCounts()
		local c = {spec=0, closet=0, mod=0, impossible=0}
		for _, data in pairs(detectedPlayers) do
			local ct = data.checktype
			if ct == 'spectator' then
				c.spec += 1
			elseif ct == 'closet' then
				c.closet += 1
			elseif ct == 'impossible_join' then
				c.impossible += 1
			else
				c.mod += 1
			end
		end
		getgenv()._aerov4_staffCounts = c
		vapeEvents.StaffCountUpdate:Fire()
	end

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
		if detectedPlayers[plr.UserId] then return end

		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end

		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId

		detectedPlayers[playerId] = {
			name = playerName,
			checktype = checktype,
			detectedTime = tick()
		}

		local alertMsg = 'Staff Detected (' .. checktype .. '): ' .. playerName .. ' (' .. playerId .. ')'
		notif('StaffDetector', alertMsg, duration, 'alert')
		whitelist.customtags[playerName] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}

		local isClanCheck = checktype:find('clan')
		if Party.Enabled and not isClanCheck then
			pcall(bedwars.PartyController.leaveParty)
		end

		local modeValue = Mode.Value
		if modeValue == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected (' .. checktype .. ')\n' .. playerName .. ' (' .. playerId .. ')',
				Duration = duration,
			})
		elseif modeValue == 'Requeue' then
			pcall(bedwars.QueueController.leaveQueue)
			bedwars.QueueController:joinQueue(store.queueType)
		elseif modeValue == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif modeValue == 'AutoConfig' then
			local safe = {AutoClicker = true, Reach = true, Sprint = true, HitFix = true, StaffDetector = true}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (safe[i] or v.Category == 'Render') then
					if v.Enabled then v:Toggle() end
					v:SetBind('')
				end
			end
		end
		refreshStaffCounts()
	end

	local function closetFunction(plr)
		if detectedPlayers[plr.UserId] then return end

		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end

		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId
		local teamNum = tonumber(plr:GetAttribute('Team'))
		local team = teamNum and teamNameMap[teamNum] or 'Unknown'

		detectedPlayers[playerId] = {
			name = playerName,
			checktype = 'closet',
			detectedTime = tick()
		}

		local alertMsg = 'KNOWN CLOSETCHEATER: ' .. playerName .. ' | Team: ' .. team
		notif('StaffDetector', alertMsg, duration, 'alert')
		whitelist.customtags[playerName] = {{text = 'CHEATER', color = Color3.fromRGB(255, 140, 0)}}
		refreshStaffCounts()
	end

	local function checkCloset(plr)
		if not ClosetDetect or not ClosetDetect.Enabled then return false end
		if plr == lplr then return false end
		local lowerName = plr.Name:lower()
		if blacklistedusernames[lowerName] then
			task.spawn(function()
				local waited = 0
				while not plr:GetAttribute('Team') and waited < 10 do
					task.wait(0.5)
					waited = waited + 0.5
				end
				closetFunction(plr)
			end)
			return true
		end
		return false
	end

	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if processing[plr.UserId] then return end
		processing[plr.UserId] = true
		if checkCloset(plr) then
			processing[plr.UserId] = nil
			return
		end
		if table.find(blacklisteduserids, plr.UserId) or (Users and table.find(Users.ListEnabled, tostring(plr.UserId))) then
			staffFunction(plr, 'blacklisted_user')
			processing[plr.UserId] = nil
			return
		end
		if getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
			processing[plr.UserId] = nil
			return
		end
		local function spectatorFunction(plr)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then
				repeat task.wait() until vape.Loaded
			end
			local duration = AlertDuration.Value
			local playerName = plr.Name
			local playerId = plr.UserId
			detectedPlayers[playerId] = {
				name = playerName,
				checktype = 'spectator',
				detectedTime = tick()
			}
			local alertMsg = 'Spectator: ' .. playerName .. ' (' .. tostring(playerId) .. ') [Has friend in server]'
			notif('StaffDetector', alertMsg, duration, 'warning')
			refreshStaffCounts()
		end

		local function checkJoin()
			if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') then
				local hasAnyFriendInServer = false
				for _, serverPlayer in ipairs(playersService:GetPlayers()) do
					if serverPlayer ~= plr then
						local suc, result = pcall(function()
							return plr:IsFriendsWith(serverPlayer.UserId)
						end)
						if suc and result then
							hasAnyFriendInServer = true
							break
						end
					end
				end

				if hasAnyFriendInServer then
					spectatorFunction(plr)
				else
					staffFunction(plr, 'impossible_join')
				end
				return true
			end
			return false
		end

		local spectatorConnection
		spectatorConnection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
			if checkJoin() then
				spectatorConnection:Disconnect()
				processing[plr.UserId] = nil
			end
		end)
		StaffDetector:Clean(spectatorConnection)

		if checkJoin() then
			processing[plr.UserId] = nil
			return
		end
		if Clans.Enabled then
			local function checkClanTag()
				local clanTag = plr:GetAttribute('ClanTag')
				if clanTag and table.find(blacklistedclans, clanTag) then
					staffFunction(plr, 'blacklisted_clan_' .. clanTag:lower())
				end
			end

			if plr:GetAttribute('ClanTag') then
				checkClanTag()
			else
				local clanConnection
				clanConnection = plr:GetAttributeChangedSignal('ClanTag'):Connect(function()
					clanConnection:Disconnect()
					checkClanTag()
				end)
				StaffDetector:Clean(clanConnection)
				task.delay(5, function()
					if clanConnection then
						clanConnection:Disconnect()
					end
				end)
			end
		end

		processing[plr.UserId] = nil
	end

	local function playerRemoving(plr)
		local userId = plr.UserId
		joined[userId] = nil
		processing[userId] = nil

		if detectedPlayers[userId] then
			local data = detectedPlayers[userId]
			local leaveMsg = data.name .. ' (' .. data.checktype .. ') has left the server'
			notif('StaffDetector', leaveMsg, AlertDuration.Value, 'warning')
			if whitelist.customtags[data.name] then
				whitelist.customtags[data.name] = nil
			end
			detectedPlayers[userId] = nil
			refreshStaffCounts()
		end
	end

	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				StaffDetector:Clean(playersService.PlayerRemoving:Connect(playerRemoving))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
				table.clear(processing)
				table.clear(detectedPlayers)
				refreshStaffCounts()
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})

	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})

	AlertDuration = StaffDetector:CreateSlider({
		Name = 'Alert Duration',
		Min = 5,
		Max = 120,
		Default = 60,
		Suffix = 's',
		Tooltip = 'How long the alert notification stays on screen'
	})

	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})

	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
	})

	ClosetDetect = StaffDetector:CreateToggle({
		Name = 'Known Cheaters',
		Default = true,
		Tooltip = 'Alerts when a known closet cheater joins your game'
	})

	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})

	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)',
		Function = function() end  
	})

	task.defer(function()
		if Profile and Profile.Object then
			Profile.Object.Visible = (Mode.Value == 'Profile')
		end
	end)
end)

run(function()
	local StaffHUD
	local ShowSpec
	local ShowCloset
	local ShowMod
	local ShowImpossible

	local STAFF_GROUP_ID = 5774246
	local STAFF_MIN_RANK = 100
	local closetNames = {
		['phantomviperr2']=true,['gavin2015shadow']=true,['clocksurge']=true,
		['amcoolll3']=true,['zorflow']=true,['dreamingnostaigia']=true,
		['featheredtwilight']=true,['imabot122356']=true,['hobyboynum']=true,
	}
	local closetIds = {1502104539,3826146717,4531785383,1049767300,4926350670,653085195,184655415,2752307430,5087196317,5744061325,1536265275}

	local rowDefs = {
		{key='spec',       label='Spec',       color=Color3.fromRGB(100,180,255), order=1},
		{key='closet',     label='Closet',     color=Color3.fromRGB(255,140,0),   order=2},
		{key='mod',        label='Mod',        color=Color3.fromRGB(255,60,60),   order=3},
		{key='impossible', label='Impossible', color=Color3.fromRGB(200,50,255),  order=4},
	}

	local tracked  = {}
	local counts   = {spec=0, closet=0, mod=0, impossible=0}
	local watchers = {}

	local gui = Instance.new('ScreenGui')
	gui.Name = 'StaffHUD'
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = vape.gui
	gui.Enabled = false

	local frame = Instance.new('Frame')
	frame.Name = 'Container'
	frame.Parent = gui
	frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(1,1)
	frame.Position = UDim2.new(1,-8,1,-8)
	frame.Size = UDim2.new(0,110,0,14)
	frame.AutomaticSize = Enum.AutomaticSize.Y

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0,6)
	uicorner.Parent = frame

	local pad = Instance.new('UIPadding')
	pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
	pad.PaddingTop=UDim.new(0,4)  pad.PaddingBottom=UDim.new(0,4)
	pad.Parent = frame

	local layout = Instance.new('UIListLayout')
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,2)
	layout.Parent = frame

	local rowObjects = {}
	for _, r in rowDefs do
		local lbl = Instance.new('TextLabel')
		lbl.Name = r.key
		lbl.Parent = frame
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,13)
		lbl.TextColor3 = r.color
		lbl.TextSize = 11
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3 = Color3.new(0,0,0)
		lbl.LayoutOrder = r.order
		lbl.Visible = false
		rowObjects[r.key] = lbl
	end

	local function updateDisplay()
		if not StaffHUD or not StaffHUD.Enabled then gui.Enabled = false return end
		local toggleMap = {spec=ShowSpec,closet=ShowCloset,mod=ShowMod,impossible=ShowImpossible}
		local anyVisible = false
		for _, r in rowDefs do
			local show = toggleMap[r.key] and toggleMap[r.key].Enabled
			rowObjects[r.key].Text = r.label .. ': ' .. (counts[r.key] or 0)
			rowObjects[r.key].Visible = show
			if show then anyVisible = true end
		end
		gui.Enabled = anyVisible
	end

	local function setTracked(userId, newCat)
		local old = tracked[userId]
		if old == newCat then return end
		if old then counts[old] = math.max(0,(counts[old] or 1)-1) end
		if newCat then
			tracked[userId] = newCat
			counts[newCat] = (counts[newCat] or 0) + 1
		else
			tracked[userId] = nil
		end
		updateDisplay()
	end

	local function removePlayer(userId)
		setTracked(userId, nil)
		if watchers[userId] then
			for _, c in ipairs(watchers[userId]) do pcall(function() c:Disconnect() end) end
			watchers[userId] = nil
		end
	end

	local function hasFriendInServer(plr)
		for _, other in ipairs(playersService:GetPlayers()) do
			if other ~= plr then
				local ok, res = pcall(function() return plr:IsFriendsWith(other.UserId) end)
				if ok and res then return true end
			end
		end
		return false
	end

	local function recheckSpec(plr)
		if not StaffHUD or not StaffHUD.Enabled then return end
		local cat = tracked[plr.UserId]
		if cat == 'closet' or cat == 'mod' then return end

		if plr:GetAttribute('Spectator') == true then
			task.spawn(function()
				local hasFriend = hasFriendInServer(plr)
				setTracked(plr.UserId, hasFriend and 'spec' or 'impossible')
			end)
		else
			if cat == 'spec' or cat == 'impossible' then
				setTracked(plr.UserId, nil)
			end
		end
	end

	local function watchPlayer(plr)
		if plr == lplr or watchers[plr.UserId] then return end
		local conns = {}
		table.insert(conns, plr:GetAttributeChangedSignal('Spectator'):Connect(function()
			recheckSpec(plr)
		end))
		table.insert(conns, plr:GetAttributeChangedSignal('Team'):Connect(function()
			recheckSpec(plr)
		end))
		watchers[plr.UserId] = conns
	end

	local function classifyPlayer(plr)
		if plr == lplr then return end
		if closetNames[plr.Name:lower()] or table.find(closetIds, plr.UserId) then
			setTracked(plr.UserId, 'closet')
			watchPlayer(plr)
			return
		end

		watchPlayer(plr)
		recheckSpec(plr)
		task.spawn(function()
			if not StaffHUD or not StaffHUD.Enabled then return end
			local ok, rank = pcall(function() return plr:GetRankInGroup(STAFF_GROUP_ID) end)
			if ok and rank >= STAFF_MIN_RANK then
				setTracked(plr.UserId, 'mod')
			end
		end)
	end

	local function cleanAll()
		for _, conns in pairs(watchers) do
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		end
		table.clear(watchers)
		table.clear(tracked)
		counts = {spec=0, closet=0, mod=0, impossible=0}
	end

	StaffHUD = vape.Categories.Utility:CreateModule({
		Name = 'StaffHUD',
		Function = function(callback)
			if callback then
				cleanAll()
				for _, plr in ipairs(playersService:GetPlayers()) do
					classifyPlayer(plr)
				end
				StaffHUD:Clean(playersService.PlayerAdded:Connect(function(plr)
					classifyPlayer(plr)
				end))
				StaffHUD:Clean(playersService.PlayerRemoving:Connect(function(plr)
					removePlayer(plr.UserId)
				end))
				updateDisplay()
			else
				cleanAll()
				gui.Enabled = false
			end
		end,
		Tooltip = 'Live corner counter: Spectators, Closet Cheaters, Mods and Impossible Joins'
	})

	ShowSpec       = StaffHUD:CreateToggle({Name='Spectators',      Default=true, Function=function() updateDisplay() end})
	ShowCloset     = StaffHUD:CreateToggle({Name='Closet Cheaters', Default=true, Function=function() updateDisplay() end})
	ShowMod        = StaffHUD:CreateToggle({Name='Mods',            Default=true, Function=function() updateDisplay() end})
	ShowImpossible = StaffHUD:CreateToggle({Name='Impossible Joins',Default=true, Function=function() updateDisplay() end})

	vape:Clean(function()
		cleanAll()
		pcall(function() gui:Destroy() end)
	end)
end)

run(function()
	local KaidaKillaura
	local Targets
	local AttackRange
	local UpdateRate
	local MouseDown
	local GUICheck
	local ShowAnimation
	local AutoAbility
	local AbilityDistance
	local SwingDuringAbility
	local lastAttackTime = 0
	local lastAbilityTime = 0
	local attackCooldown = 0.65
	local abilityCooldown = 22
	local isChargingAbility = false

	local SummonerKitController = nil
	local function getSummonerController()
		if SummonerKitController then return SummonerKitController end
		pcall(function()
			SummonerKitController = bedwars.KnitClient.Controllers.SummonerKitController
		end)
		return SummonerKitController
	end

	local function isActuallyCharging()
		if isChargingAbility then return true end
		local ctrl = getSummonerController()
		if ctrl then
			local ok, result = pcall(function()
				return ctrl:isPlayerCastingSpell(lplr)
			end)
			if ok and result then return true end
		end
		return false
	end

	local function getSpellLevel()
		local level = 1
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getPlayerSpellLevel(lplr)
			if result then level = result end
		end)
		return level
	end

	local function getCastTime(level)
		local castTime = 2
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getTotalCastTimeRequired(level)
			if result then castTime = result end
		end)
		return castTime
	end

	local function fireUseAbility(abilityName)
		pcall(function()
			game:GetService("ReplicatedStorage")
				:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
				:WaitForChild("useAbility"):FireServer(abilityName)
		end)
	end

	local function doAutoAbility()
		if isChargingAbility then return end
		isChargingAbility = true

		fireUseAbility("summoner_start_charging")

		local level = getSpellLevel()
		local castTime = getCastTime(level)
		task.wait(math.max(castTime, 0.5))

		if isChargingAbility then
			fireUseAbility("summoner_finish_charging")
		end

		lastAbilityTime = tick()
		isChargingAbility = false
	end

	local function getPlayerClawLevel()
		local handItem = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if handItem and handItem.Value then
			local itemType = handItem.Value.Name
			if itemType == 'summoner_claw_1' then return 1 end
			if itemType == 'summoner_claw_2' then return 2 end
			if itemType == 'summoner_claw_3' then return 3 end
			if itemType == 'summoner_claw_4' then return 4 end
		end
		if store and store.inventory and store.inventory.hotbar then
			for _, v in pairs(store.inventory.hotbar) do
				if v.item then
					local itemType = v.item.itemType
					if itemType == 'summoner_claw_1' then return 1 end
					if itemType == 'summoner_claw_2' then return 2 end
					if itemType == 'summoner_claw_3' then return 3 end
					if itemType == 'summoner_claw_4' then return 4 end
				end
			end
		end
		return 1
	end

	KaidaKillaura = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				lastAttackTime = 0
				lastAbilityTime = 0
				isChargingAbility = false

				repeat
					if not entitylib.isAlive then
						task.wait(0.1)
						continue
					end

					if GUICheck.Enabled then
						if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
							task.wait(0.1)
							continue
						end
					end

					local handItem = lplr.Character:FindFirstChild('HandInvItem')
					local hasClaw = false
					if handItem and handItem.Value then
						hasClaw = handItem.Value.Name:find('summoner_claw') ~= nil
					end

					if not hasClaw then
						task.wait(0.1)
						continue
					end

					if MouseDown.Enabled then
						if not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							task.wait(1.2)
							continue
						end
					end

					local plr = entitylib.EntityPosition({
						Range = AttackRange.Value,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled or nil
					})

					if plr then
						local localPosition = entitylib.character.RootPart.Position
						local targetDistance = (localPosition - plr.RootPart.Position).Magnitude
						local now = tick()

						if AutoAbility.Enabled and targetDistance <= AbilityDistance.Value then
							if not isChargingAbility and (now - lastAbilityTime) >= abilityCooldown then
								task.spawn(doAutoAbility)
							end
						end

						local charging = isActuallyCharging()

						if not SwingDuringAbility.Enabled and charging then
							task.wait(0.05)
							continue
						end

						if (now - lastAttackTime) >= attackCooldown then
							local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
							localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
							lastAttackTime = now

							if ShowAnimation.Enabled then
								task.spawn(function()
									pcall(function()
										local clawLevel = getPlayerClawLevel()
										bedwars.AnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CHARACTER_SWIPE), {
											looped = false
										})
										local clawModel = replicatedStorage.Assets.Misc.Kaida.Summoner_DragonClaw:Clone()
										local clawColors = {
											Color3.fromRGB(75, 75, 75),
											Color3.fromRGB(255, 255, 255),
											Color3.fromRGB(43, 229, 229),
											Color3.fromRGB(49, 229, 94)
										}
										local nailMesh = clawModel:FindFirstChild("dragon_claw_nail_mesh")
										if nailMesh and nailMesh:IsA("MeshPart") then
											nailMesh.Color = clawColors[clawLevel] or clawColors[1]
										end
										if bedwars.KnightClient and bedwars.KnightClient.Controllers.SummonerKitSkinController then
											if bedwars.KnightClient.Controllers.SummonerKitSkinController:isPrismaticSkin(lplr) then
												bedwars.KnightClient.Controllers.SummonerKitSkinController:applyClawRGB(clawModel)
											end
										end
										clawModel.Parent = workspace
										local camera = workspace.CurrentCamera
										if camera and (camera.CFrame.Position - entitylib.character.RootPart.Position).Magnitude < 1 then
											for _, part in clawModel:GetDescendants() do
												if part:IsA('MeshPart') then
													part.Transparency = 0.6
												end
											end
										end
										local rootPart = entitylib.character.RootPart
										local Unit = Vector3.new(shootDir.X, 0, shootDir.Z).Unit
										local startPos = rootPart.Position + Unit:Cross(Vector3.new(0, 1, 0)).Unit * -1 * 5 + Unit * 6
										local direction = (startPos + shootDir * 13 - startPos).Unit
										local cframe = CFrame.new(startPos, startPos + direction)
										clawModel:PivotTo(cframe)
										clawModel.PrimaryPart.Anchored = true
										if clawModel:FindFirstChild('AnimationController') then
											local animator = clawModel.AnimationController:FindFirstChildOfClass('Animator')
											if animator then
												bedwars.AnimationUtil:playAnimation(animator, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SUMMONER_CLAW_ATTACK), {
													looped = false,
													speed = 1
												})
											end
										end
										pcall(function()
											local sounds = {
												bedwars.SoundList.SUMMONER_CLAW_ATTACK_1,
												bedwars.SoundList.SUMMONER_CLAW_ATTACK_2,
												bedwars.SoundList.SUMMONER_CLAW_ATTACK_3,
												bedwars.SoundList.SUMMONER_CLAW_ATTACK_4
											}
											bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)], {
												position = rootPart.Position
											})
										end)
										task.wait(0.75)
										clawModel:Destroy()
									end)
								end)
							end

							bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
								position = localPosition,
								direction = shootDir,
								clientTime = workspace:GetServerTimeNow()
							})
						end
					else
						if isChargingAbility then
							isChargingAbility = false
							fireUseAbility("summoner_finish_charging")
						end
					end

					task.wait(1 / UpdateRate.Value)
				until not KaidaKillaura.Enabled

				isChargingAbility = false
			end
		end,
		Tooltip = 'Auto attacks with Summoner claw'
	})

	Targets = KaidaKillaura:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	AttackRange = KaidaKillaura:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	UpdateRate = KaidaKillaura:CreateSlider({
		Name = 'Update Rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})

	MouseDown = KaidaKillaura:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'Only attacks while holding left click'
	})

	GUICheck = KaidaKillaura:CreateToggle({
		Name = 'GUI Check'
	})

	ShowAnimation = KaidaKillaura:CreateToggle({
		Name = 'Show Animation',
		Default = true
	})

	SwingDuringAbility = KaidaKillaura:CreateToggle({
		Name = 'Swing During Ability',
		Default = true,
		Tooltip = 'Continue claw attacks while charging ability'
	})

	AutoAbility = KaidaKillaura:CreateToggle({
		Name = 'Auto Ability',
		Default = false,
		Tooltip = 'Automatically uses ability when enemy is within distance',
		Function = function(callback)
			if not callback then
				isChargingAbility = false
			end
			AbilityDistance.Object.Visible = callback
		end
	})

    AbilityDistance = KaidaKillaura:CreateSlider({
        Name = 'Ability Distance',
        Min = 3,
        Max = 15,
        Default = 6,
        Visible = false,
        Tooltip = 'Distance to trigger ability',
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    task.defer(function()
        if AbilityDistance and AbilityDistance.Object then
            AbilityDistance.Object.Visible = false   
        end
    end)
end)

run(function()
    local MetalDetector
    local CollectionToggle
    local LimitToItem
    local Animation
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local HoldingCheck
    local DistanceCheck
    local DistanceLimit
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local lastNotification = 0
    local notificationPending = false
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionActive = false
    local collectedMetals = {}
    local animationDebounce = {}

    local function isHoldingMetalDetector()
        if not store.hand or not store.hand.tool then return false end
        return store.hand.tool.Name == 'metal_detector'
    end

    local function sendNotification(count)
        notif("Metal ESP", string.format("%d metals spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue == 0 then return end
        local currentTime = tick()
        local remaining = notificationCooldown - (currentTime - lastNotification)
        if remaining <= 0 then
            sendNotification(#spawnQueue)
            lastNotification = currentTime
            spawnQueue = {}
            notificationPending = false
        elseif not notificationPending then
            notificationPending = true
            task.delay(remaining, function()
                if #spawnQueue > 0 then
                    sendNotification(#spawnQueue)
                    lastNotification = tick()
                    spawnQueue = {}
                end
                notificationPending = false
            end)
        end
    end

    local function getProperImage()
        return bedwars.getIcon({itemType = 'iron'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'hidden-metal'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'metal', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
    end

    local function setupESP()
        for _, v in collectionService:GetTagged('hidden-metal') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        MetalDetector:Clean(collectionService:GetInstanceAddedSignal('hidden-metal'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end))

        MetalDetector:Clean(collectionService:GetInstanceRemovedSignal('hidden-metal'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))

        MetalDetector:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if HoldingCheck.Enabled and not isHoldingMetalDetector() then
                    shouldShow = false
                end

                if shouldShow and DistanceCheck.Enabled and entitylib.isAlive then
                    local distance = (entitylib.character.RootPart.Position - v.Position).Magnitude
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        shouldShow = false
                    end
                end

                billboard.Enabled = shouldShow
            end
        end))
    end

    local function collectMetal(metalModel)
        local metalId = metalModel:GetAttribute('Id')
        if not metalId then return false end
        if collectedMetals[metalId] then return false end

        collectedMetals[metalId] = true

        local success = pcall(function()
            bedwars.Client:Get(remotes.CollectCollectableEntity).instance:FireServer({ id = metalId })
        end)

        if Animation.Enabled then
            local currentTick = tick()
            if not animationDebounce[metalId] or (currentTick - animationDebounce[metalId]) >= 0.5 then
                animationDebounce[metalId] = currentTick
                pcall(function()
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
                    bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
                end)
            end
        end

        task.delay(2, function()
            collectedMetals[metalId] = nil
            animationDebounce[metalId] = nil
        end)
        
        return success
    end

    local function startAutoCollect()
        if collectionActive then return end
        collectionActive = true
        
        task.spawn(function()
            while MetalDetector.Enabled and CollectionToggle.Enabled and collectionActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                if LimitToItem.Enabled and not isHoldingMetalDetector() then 
                    task.wait(0.5)
                    continue 
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local collectedThisCycle = false
								
				for _, v in collectionService:GetTagged('hidden-metal') do
					if not MetalDetector.Enabled or not CollectionToggle.Enabled or not collectionActive then 
						break 
					end
					
					if v:IsA("Model") and v.PrimaryPart then
						local distance = (localPosition - v.PrimaryPart.Position).Magnitude
						
						if distance <= range then
							if collectMetal(v) then
								collectedThisCycle = true
								if CollectionDelay.Enabled and DelaySlider.Value > 0 then
									task.wait(DelaySlider.Value)
								else
									task.wait(0.15)
								end
							end
						end
					end
				end
                
                task.wait(collectedThisCycle and 0.3 or 0.5)
            end
            
            collectionActive = false
        end)
    end

    local function stopAutoCollect()
        collectionActive = false
        table.clear(collectedMetals)
        table.clear(animationDebounce)
    end

    MetalDetector = vape.Categories.Kits:CreateModule({
        Name = 'AutoMetal',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                if CollectionToggle.Enabled then
                    startAutoCollect()
                end
            else
                stopAutoCollect()
                Folder:ClearAllChildren()
                table.clear(Reference)
                spawnQueue = {}
                lastNotification = 0
                notificationPending = false
            end
        end,
        Tooltip = 'automatically collects hidden metal and esp'
    })
    
    CollectionToggle = MetalDetector:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'automatically collect metals',
        Function = function(callback)
            if LimitToItem and LimitToItem.Object then LimitToItem.Object.Visible = callback end
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback and CollectionDelay and CollectionDelay.Enabled
            end
            
            if MetalDetector.Enabled then
                if callback then
                    startAutoCollect()
                else
                    stopAutoCollect()
                end
            end
        end
    })
    
    LimitToItem = MetalDetector:CreateToggle({
        Name = 'Limit to Items',
        Default = true,
        Tooltip = 'only works when holding metal_detector'
    })
    
    Animation = MetalDetector:CreateToggle({
        Name = 'Animation',
        Default = true,
        Tooltip = 'play shovel dig animation and sound'
    })
    
    CollectionDelay = MetalDetector:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'add delay before collecting metal',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = MetalDetector:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Visible = false,
        Tooltip = 'delay in seconds before collecting'
    })
    
    RangeSlider = MetalDetector:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'control distance you want to collect metal'
    })
    
    ESPToggle = MetalDetector:CreateToggle({
        Name = 'Metal ESP',
        Default = false,
        Tooltip = 'shows metal locations',
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if HoldingCheck and HoldingCheck.Object then HoldingCheck.Object.Visible = callback end
            if DistanceCheck and DistanceCheck.Object then DistanceCheck.Object.Visible = callback end
            if DistanceLimit and DistanceLimit.Object then
                DistanceLimit.Object.Visible = (callback and DistanceCheck.Enabled)
            end

            if not callback then
                if ESPColor and ESPColor.Object then
                    ESPColor.Object.Visible = false
                end
                if DistanceLimit and DistanceLimit.Object then
                    DistanceLimit.Object.Visible = false
                end
            else
                if ESPBackground and ESPBackground.Enabled then
                    if ESPColor and ESPColor.Object then
                        ESPColor.Object.Visible = true
                    end
                end
                if DistanceCheck and DistanceCheck.Enabled then
                    if DistanceLimit and DistanceLimit.Object then
                        DistanceLimit.Object.Visible = true
                    end
                end
            end
            
            if MetalDetector.Enabled then
                if callback then setupESP() else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = MetalDetector:CreateToggle({
        Name = 'Notify',
        Default = false,
        Tooltip = 'get notifications when metals spawn'
    })
    
    ESPBackground = MetalDetector:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    local blur = v:FindFirstChild("BlurEffect")
                    if blur then blur.Visible = callback end
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                end
            end
        end
    })
    
    ESPColor = MetalDetector:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    
    HoldingCheck = MetalDetector:CreateToggle({
        Name = 'Holding Detector',
        Default = false,
        Tooltip = 'only show esp when holding metal detector'
    })
    
    DistanceCheck = MetalDetector:CreateToggle({
        Name = 'Distance Check',
        Default = false,
        Tooltip = 'only show metals within distance range',
        Function = function(callback)
            if DistanceLimit and DistanceLimit.Object then
                DistanceLimit.Object.Visible = callback
            end
        end
    })
    
    DistanceLimit = MetalDetector:CreateTwoSlider({
        Name = 'Metal Distance',
        Min = 0,
        Max = 256,
        DefaultMin = 0,
        DefaultMax = 64,
        Darker = true,
        Tooltip = 'distance range for showing metals'
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = CollectionDelay.Enabled  
        end
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = false end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = false end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = false end
        if HoldingCheck and HoldingCheck.Object then HoldingCheck.Object.Visible = false end
        if DistanceCheck and DistanceCheck.Object then DistanceCheck.Object.Visible = false end
        if DistanceLimit and DistanceLimit.Object then DistanceLimit.Object.Visible = false end
    end)
end)

run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	local processedShadows = {}
	
	local function removeShadow(obj)
		if obj:IsA("BasePart") and not processedShadows[obj] then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
			processedShadows[obj] = true
		end
	end
	
	ShadowRemover = vape.Categories.BoostFPS:CreateModule({
		Name = 'ShadowRemover',
		Function = function(callback)
			if callback then
				local descendants = workspace:GetDescendants()
				
				task.spawn(function()
					for i, obj in descendants do
						removeShadow(obj)
						if i % 100 == 0 then
							task.wait()
						end
					end
				end)
				
				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ShadowRemover.Enabled then
						removeShadow(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, shadow in pairs(originalShadows) do
					if obj and obj.Parent then
						pcall(function()
							obj.CastShadow = shadow
						end)
					end
				end
				
				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
				table.clear(processedShadows)
			end
		end,
		Tooltip = 'Removes shadows from all parts for FPS boost'
	})
end)

run(function()
	local WhiteHits
	WhiteHits = vape.Categories.Legit:CreateModule({
		Name = "WhiteHits",
		Function = function(callback)
			repeat
				for i, v in entitylib.List do 
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight then 
						highlight.FillTransparency = 1
						if not highlight:GetAttribute("TransparencyHooked") then
							highlight:GetPropertyChangedSignal("FillTransparency"):Connect(function()
								highlight.FillTransparency = 1
							end)
							highlight:SetAttribute("TransparencyHooked", true)
						end
					end
				end
				task.wait(0.1)
			until not WhiteHits.Enabled
		end
	})
end)

run(function()
    local AutoLani
    local PlayerDropdown
    local RefreshButton
    local DelaySlider
    local AutoBuyToggle
    local GUICheck
    local DelayBuySlider
    local LimitItems
    local TargetModeDropdown
    local HealthActivationToggle
    local HealthThresholdSlider
    local TeammateHealthToggle
    local TeammateHealthSlider
    local running = false
    local buyRunning = false
    local buyLoopThread = nil

    local function isHoldingScepter()
        if not entitylib.isAlive then return false end
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == "scepter" then
                return true
            end
        end
        return false
    end

    local function isPlayerAlive(player)
        if not player or not player.Character then return false end
        local humanoid = player.Character:FindFirstChild("Humanoid")
        return humanoid and humanoid.Health > 0
    end

    local function isPlayerInVoid(player)
        if not player or not player.Character then return true end
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then return rootPart.Position.Y < 0 end
        return true
    end

    local function getTargetPlayer()
        local myTeam = lplr:GetAttribute('Team')
        if not myTeam then return nil end
        local mode = TargetModeDropdown.Value

        if mode == "Specific Player" then
            local targetName = PlayerDropdown.Value
            if not targetName or targetName == "" then return nil end
            local targetPlayer = playersService:FindFirstChild(targetName)
            if targetPlayer and targetPlayer:GetAttribute('Team') == myTeam then
                if isPlayerAlive(targetPlayer) and not isPlayerInVoid(targetPlayer) then
                    return targetPlayer
                end
            end
            return nil

        elseif mode == "Lowest Health" then
            local lowestHealth = math.huge
            local lowestPlayer = nil
            for _, player in playersService:GetPlayers() do
                if player ~= lplr and player:GetAttribute('Team') == myTeam then
                    if isPlayerAlive(player) and not isPlayerInVoid(player) then
                        local hp = getPlayerHealthPercent(player)
                        if hp < lowestHealth and hp > 0 then
                            lowestHealth = hp
                            lowestPlayer = player
                        end
                    end
                end
            end
            return lowestPlayer

        elseif mode == "Closest" then
            if not entitylib.isAlive then return nil end
            local myPos = entitylib.character.RootPart.Position
            local closestDist = math.huge
            local closestPlayer = nil
            for _, player in playersService:GetPlayers() do
                if player ~= lplr and player:GetAttribute('Team') == myTeam then
                    if isPlayerAlive(player) and not isPlayerInVoid(player) then
                        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (player.Character.HumanoidRootPart.Position - myPos).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestPlayer = player
                            end
                        end
                    end
                end
            end
            return closestPlayer

        elseif mode == "Furthest" then
            if not entitylib.isAlive then return nil end
            local myPos = entitylib.character.RootPart.Position
            local furthestDist = 0
            local furthestPlayer = nil
            for _, player in playersService:GetPlayers() do
                if player ~= lplr and player:GetAttribute('Team') == myTeam then
                    if isPlayerAlive(player) and not isPlayerInVoid(player) then
                        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (player.Character.HumanoidRootPart.Position - myPos).Magnitude
                            if dist > furthestDist then
                                furthestDist = dist
                                furthestPlayer = player
                            end
                        end
                    end
                end
            end
            return furthestPlayer

        elseif mode == "Random" then
            local valid = {}
            for _, player in playersService:GetPlayers() do
                if player ~= lplr and player:GetAttribute('Team') == myTeam then
                    if isPlayerAlive(player) and not isPlayerInVoid(player) then
                        table.insert(valid, player)
                    end
                end
            end
            if #valid > 0 then return valid[math.random(1, #valid)] end
            return nil
        end

        return nil
    end

    local function shouldActivateByHealth()
        if not HealthActivationToggle.Enabled then return true end
        if not entitylib.isAlive then return false end
        local myHp = getPlayerHealthPercent(lplr)
        if myHp <= HealthThresholdSlider.Value then return true end
        if TeammateHealthToggle.Enabled then
            local target = getTargetPlayer()
            if target then
                local targetHp = getPlayerHealthPercent(target)
                if targetHp <= TeammateHealthSlider.Value then return true end
            end
        end
        return false
    end

    local function getShopNPC()
        if not entitylib.isAlive then return false end
        local localPosition = entitylib.character.RootPart.Position
        for _, v in store.shop do
            if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                return true
            end
        end
        return false
    end

    local function buyScepter()
        pcall(function()
            bedwars.Client:Get(remotes.BedwarsPurchaseItem).instance:InvokeServer({
                shopItem = {
                    currency = "iron",
                    itemType = "scepter",
                    amount = 1,
                    price = 45,
                    category = "Combat",
                    requiresKit = {"paladin"},
                    lockAfterPurchase = true
                },
                shopId = "1_item_shop"
            })
        end)
    end

    local function startBuyLoop()
        if buyLoopThread then
            task.cancel(buyLoopThread)
            buyLoopThread = nil
        end
        buyRunning = true
        buyLoopThread = task.spawn(function()
            while buyRunning and AutoBuyToggle.Enabled and AutoLani.Enabled do
                local canBuy = GUICheck.Enabled
                    and bedwars.AppController:isAppOpen('BedwarsItemShopApp')
                    or (not GUICheck.Enabled and getShopNPC())
                if canBuy then
                    buyScepter()
                end
                task.wait(DelayBuySlider.Value)
            end
            buyLoopThread = nil
        end)
    end

    local function stopBuyLoop()
        buyRunning = false
        if buyLoopThread then
            task.cancel(buyLoopThread)
            buyLoopThread = nil
        end
    end

    AutoLani = vape.Categories.Kits:CreateModule({
        Name = "AutoLani",
        Function = function(callback)
            running = callback
            if callback then
                task.spawn(function()
                    AutoLani:Clean(lplr:GetAttributeChangedSignal("PaladinStartTime"):Connect(function()
                        if not running then return end
                        if not shouldActivateByHealth() then return end
                        if LimitItems.Enabled and not isHoldingScepter() then
                            notif("AutoLani", "bro u aint even holding the scepter 💀", 3)
                            return
                        end

                        pcall(function()
                            local handItem = store.inventory and store.inventory.inventory and store.inventory.inventory.hand
                            if handItem then
                                bedwars.Client:Get(remotes.ConsumeItem).instance:InvokeServer({ item = handItem.tool })
                            end
                        end)

                        task.wait(DelaySlider.Value)

                        if bedwars.AbilityController:canUseAbility('PALADIN_ABILITY') then
                            local targetPlayer = getTargetPlayer()
                            if targetPlayer and targetPlayer.Character then
                                bedwars.Client:Get(remotes.PaladinAbilityRequest):SendToServer({ target = targetPlayer })
                                notif("AutoLani", "tp'd to " .. targetPlayer.Name .. " don't die lol", 2)
                            else
                                bedwars.Client:Get(remotes.PaladinAbilityRequest):SendToServer({})
                                notif("AutoLani", "used ability on self fr fr", 2)
                            end
                            task.wait(0.022)
                            bedwars.AbilityController:useAbility('PALADIN_ABILITY')
                        else
                            notif("AutoLani", "ability on cooldown rn 😭", 2)
                        end
                    end))
                end)

                if AutoBuyToggle.Enabled then startBuyLoop() end

                AutoLani:Clean(playersService.PlayerAdded:Connect(function()
                    task.wait(0.5)
                    PlayerDropdown:SetList(getTeammateNames())
                end))
                AutoLani:Clean(playersService.PlayerRemoving:Connect(function()
                    task.wait(0.5)
                    PlayerDropdown:SetList(getTeammateNames())
                end))
                AutoLani:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(1)
                    PlayerDropdown:SetList(getTeammateNames())
                end))
            else
                running = false
                stopBuyLoop()
            end
        end,
        Tooltip = "auto tp to teammates w paladin scepter"
    })

    TargetModeDropdown = AutoLani:CreateDropdown({
        Name = "Target Mode",
        List = {"Specific Player", "Lowest Health", "Closest", "Furthest", "Random"},
        Default = "Specific Player",
        Function = function(val)
            if PlayerDropdown then
                PlayerDropdown.Object.Visible = (val == "Specific Player")
            end
        end,
        Tooltip = "who to tp to"
    })

    local function teammateListWithNone()
        local list = {"None"}
        for _, name in ipairs(getTeammateNames()) do
            table.insert(list, name)
        end
        return list
    end

    PlayerDropdown = AutoLani:CreateDropdown({
        Name = "Teammate",
        List = teammateListWithNone(),
        Tooltip = "pick ur teammate"
    })

    RefreshButton = AutoLani:CreateButton({
        Name = "Refresh Teammates",
        Function = function()
            task.spawn(function()
                local newNames = getTeammateNames()
                local newList = {"None"}
                for _, name in ipairs(newNames) do
                    table.insert(newList, name)
                end
                if PlayerDropdown then
                    pcall(function()
                        PlayerDropdown:Change(newList)
                        if #newList > 1 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[2] or "None")
                            else
                                PlayerDropdown:SetValue(PlayerDropdown.Value)
                            end
                        end
                    end)
                end
                notif("AutoLani", #newList > 0 and "refreshed, got " .. #newList .. " teammates 👍" or "no teammates found bro 💀", 2)
            end)
        end,
        Tooltip = "refresh the teammate list"
    })

    DelaySlider = AutoLani:CreateSlider({
        Name = "Teleport Delay",
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = "s",
        Tooltip = "delay before tping"
    })

    LimitItems = AutoLani:CreateToggle({
        Name = "Limit to Scepter",
        Default = true,
        Tooltip = "only tp when u holdin the scepter"
    })

    HealthActivationToggle = AutoLani:CreateToggle({
        Name = "Health Activation",
        Default = false,
        Function = function(val)
            if HealthThresholdSlider then HealthThresholdSlider.Object.Visible = val end
            if TeammateHealthToggle then TeammateHealthToggle.Object.Visible = val end

            if not val then
                if TeammateHealthSlider and TeammateHealthSlider.Object then
                    TeammateHealthSlider.Object.Visible = false
                end
            else
                if TeammateHealthToggle and TeammateHealthToggle.Enabled then
                    if TeammateHealthSlider and TeammateHealthSlider.Object then
                        TeammateHealthSlider.Object.Visible = true
                    end
                end
            end
        end,
        Tooltip = "only use ability based on hp"
    })

    HealthThresholdSlider = AutoLani:CreateSlider({
        Name = "Self Health %",
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = "%",
        Tooltip = "use ability when ur hp is below this",
        Visible = false
    })

    TeammateHealthToggle = AutoLani:CreateToggle({
        Name = "Teammate Health Check",
        Default = false,
        Function = function(val)
            if TeammateHealthSlider then TeammateHealthSlider.Object.Visible = val end
        end,
        Tooltip = "also check teammate hp",
        Visible = false
    })

    TeammateHealthSlider = AutoLani:CreateSlider({
        Name = "Teammate Health %",
        Min = 1,
        Max = 100,
        Default = 30,
        Suffix = "%",
        Tooltip = "use ability when teammate hp is below this",
        Visible = false
    })

    AutoBuyToggle = AutoLani:CreateToggle({
        Name = "Auto Buy Scepter",
        Default = false,
        Function = function(val)
            if GUICheck then GUICheck.Object.Visible = val end
            if DelayBuySlider then DelayBuySlider.Object.Visible = val end
            if val and AutoLani.Enabled then
                startBuyLoop()
            else
                stopBuyLoop()
            end
        end,
        Tooltip = "auto cop scepters from shop"
    })

    GUICheck = AutoLani:CreateToggle({
        Name = "GUI Check",
        Default = false,
        Tooltip = "only buy when shop is open",
        Visible = false
    })

    DelayBuySlider = AutoLani:CreateSlider({
        Name = "Buy Delay",
        Min = 0.1,
        Max = 2,
        Default = 0.3,
        Decimal = 10,
        Suffix = "s",
        Tooltip = "delay between buys",
        Visible = false
    })

    task.defer(function()
        if PlayerDropdown and PlayerDropdown.Object then
            PlayerDropdown.Object.Visible = true
        end
        if HealthThresholdSlider and HealthThresholdSlider.Object then
            HealthThresholdSlider.Object.Visible = false
        end
        if TeammateHealthToggle and TeammateHealthToggle.Object then
            TeammateHealthToggle.Object.Visible = false
        end
        if TeammateHealthSlider and TeammateHealthSlider.Object then
            TeammateHealthSlider.Object.Visible = false
        end
        if GUICheck and GUICheck.Object then GUICheck.Object.Visible = false end
        if DelayBuySlider and DelayBuySlider.Object then DelayBuySlider.Object.Visible = false end
    end)
end)

run(function()
	local AutoPearl
	local LimitItems

	local rayCheck = cloneRaycast()
	rayCheck.RespectCanCollide = true

	local scanParams = cloneRaycast()
	scanParams.RespectCanCollide = true
	scanParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)

	local function isHoldingPearl()
		if not entitylib.isAlive then return false end
		local hand = store.inventory and store.inventory.inventory and store.inventory.inventory.hand
		return hand and hand.itemType == 'telepearl'
	end

	local function getPearlHotbarSlot()
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == 'telepearl' then
				return i - 1, v.item
			end
		end
		return nil, nil
	end

	local function throwPearl(pos, spot, pearlTool)
		local meta = bedwars.ProjectileMeta.telepearl
		local offsets = {
			Vector3.new(0, -1.5, 0),
			Vector3.new(0, 0, 0),
			Vector3.new(0, 1, 0),
			Vector3.new(0, -3, 0),
		}

		local calc, usedSpot
		for _, offset in offsets do
			local trySpot = spot + offset
			calc = prediction.SolveTrajectory(
				pos,
				meta.launchVelocity,
				meta.gravitationalAcceleration,
				trySpot,
				Vector3.zero,
				workspace.Gravity,
				0, 0, nil, false,
				lplr:GetNetworkPing()
			)
			if calc then
				usedSpot = trySpot
				break
			end
		end

		if not calc then return false end

		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
		projectileRemote:InvokeServer(
			pearlTool,
			'telepearl', 'telepearl',
			pos, pos, dir,
			httpService:GenerateGUID(true),
			{drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)},
			workspace:GetServerTimeNow() - 0.045
		)
		return true
	end

	local function isValidLandingSpot(pos, scanP)
		local headCheck = workspace:Raycast(pos + Vector3.new(0, 0.1, 0), Vector3.new(0, 3, 0), scanP)
		if headCheck then return false end
		local groundCheck = workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -2, 0), scanP)
		return groundCheck ~= nil
	end

	local function findBestLandingSpot(origin)
		local char = lplr.Character
		if not char then return nil end

		scanParams.FilterDescendantsInstances = {char, gameCamera}

		local meta = bedwars.ProjectileMeta.telepearl
		local candidates = {}

		local distances = {4, 6, 8, 10, 12, 16, 20, 24, 30}
		local angleSteps = 32

		for _, dist in distances do
			for step = 0, angleSteps - 1 do
				local angle = (step / angleSteps) * math.pi * 2
				local offsetX = math.cos(angle) * dist
				local offsetZ = math.sin(angle) * dist

				local checkOrigin = Vector3.new(
					origin.X + offsetX,
					origin.Y + 50,
					origin.Z + offsetZ
				)

				local downRay = workspace:Raycast(checkOrigin, Vector3.new(0, -120, 0), scanParams)
				if downRay then
					local hitPos = downRay.Position
					local normal = downRay.Normal
					local block = downRay.Instance

					if normal.Y > 0.7 and block and block:IsA("BasePart") then
						local landingSpot = hitPos + Vector3.new(0, 0.1, 0)

						if isValidLandingSpot(landingSpot, scanParams) then
							local calc = prediction.SolveTrajectory(
								origin,
								meta.launchVelocity,
								meta.gravitationalAcceleration,
								landingSpot,
								Vector3.zero,
								workspace.Gravity,
								0, 0, nil, false,
								lplr:GetNetworkPing()
							)

							if calc then
								local dist2d = Vector2.new(origin.X - landingSpot.X, origin.Z - landingSpot.Z).Magnitude
								local heightDiff = landingSpot.Y - origin.Y
								table.insert(candidates, {
									spot = landingSpot,
									dist = dist2d,
									heightDiff = heightDiff,
									calc = calc
								})
							end
						end
					end
				end
			end
		end

		if #candidates == 0 then return nil end
		table.sort(candidates, function(a, b)
			local aAbove = a.heightDiff >= -10
			local bAbove = b.heightDiff >= -10
			if aAbove ~= bAbove then return aAbove end
			return a.dist < b.dist
		end)

		return candidates[1].spot
	end

	local function doPearl(pos, spot, pearl)
		local pearlSlot, pearlItem = getPearlHotbarSlot()
		if not pearlSlot or not pearlItem then return end

		if LimitItems.Enabled then
			if not isHoldingPearl() then return end
			throwPearl(pos, spot, pearlItem.tool)
			return
		end

		local originalSlot = store.inventory.hotbarSlot

		if isHoldingPearl() then
			throwPearl(pos, spot, pearlItem.tool)
		else
			hotbarSwitch(pearlSlot)
			task.wait(0.08)
			throwPearl(pos, spot, pearlItem.tool)
			task.wait(0.05)
			hotbarSwitch(originalSlot)
		end
	end

	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local lastThrowTime = 0
				local throwCooldown = 0.3
				local pearlTriggered = false

				local voidRayParams = RaycastParams.new()
				voidRayParams.FilterType = Enum.RaycastFilterType.Blacklist
				voidRayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}

				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						local currentTime = tick()
						voidRayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}

						local velY = root.AssemblyLinearVelocity.Y
						local falling = velY < -60
						local isJumping = velY > 5
						local noGroundBelow = not workspace:Raycast(root.Position, Vector3.new(0, -120, 0), voidRayParams)

						if pearl and falling and noGroundBelow and not isJumping then
							if not pearlTriggered and (currentTime - lastThrowTime) >= throwCooldown then
								pearlTriggered = true
								lastThrowTime = currentTime
								local ground = findBestLandingSpot(root.Position)
								if ground then
									task.spawn(doPearl, root.Position, ground, pearl)
								end
							end
						else
							pearlTriggered = false
						end
					else
						pearlTriggered = false
					end
					task.wait(0.05)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'automatically pearls to safety when falling into void'
	})

	LimitItems = AutoPearl:CreateToggle({
		Name = 'Limit to Pearl',
		Default = false,
		Tooltip = 'only pearls when already holding pearl, no switching'
	})
end)

run(function()
	local AutoUMA
	local CycleMode
	local AttackMode
	local HealMode
	local Range
	local AutoSummon
	local TargetVisualiser
	local PriorityDropdown
	local CollectionService = collectionService
	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local old
	local summonThread = nil
	local currentAffinity = nil
	local generatorCache = {}
	local lastCacheUpdate = 0
	local priorityOrders = {
        ['Emerald > Diamond > Gold'] = {'emerald', 'diamond', 'iron'},
        ['Diamond > Emerald > Gold'] = {'diamond', 'emerald', 'iron'},
        ['Gold > Diamond > Emerald'] = {'iron', 'diamond', 'emerald'}
    }
	
	local lootNames = {
		emerald = {"Emerald", "EmeraldOre"},
		diamond = {"Diamond", "DiamondOre"},
		iron = {"IronIngot", "IronOre"}
	}
	
	local function updateOutline(target)
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
		if target and TargetVisualiser.Enabled then
			targetOutline = Instance.new("Highlight")
			targetOutline.FillTransparency = 0.5
			targetOutline.OutlineColor = Color3.fromRGB(255, 215, 0)
			targetOutline.OutlineTransparency = 0
			targetOutline.Adornee = target
			targetOutline.Parent = target
		end
	end
	
	local function clearOutline()
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
	end
	
	local function updateGeneratorCache()
		if tick() - lastCacheUpdate < 2 then return end
		
		generatorCache = {}
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == 'GeneratorAdornee' then
				table.insert(generatorCache, obj)
			end
		end
		lastCacheUpdate = tick()
	end
	
	local function isGeneratorLoot(drop)
		if drop:GetAttribute('OreGenDrop') then
			return true
		end
		
		updateGeneratorCache()
		
		local pos = drop:FindFirstChild('Handle') and drop.Handle.Position
		if not pos then return false end
		
		for _, gen in ipairs(generatorCache) do
			local genPos = gen:GetPivot().Position
			if (pos - genPos).Magnitude <= 20 then
				return true
			end
		end
		
		return false
	end
	
	local function getClosestLoot(originPos)
		local closest, closestDist = nil, math.huge
		local priorityOrder = priorityOrders[PriorityDropdown.Value] or priorityOrders['Emerald > Diamond > Iron']
		
		for _, itemType in ipairs(priorityOrder) do
			for _, drop in ipairs(CollectionService:GetTagged('ItemDrop')) do
				if not drop:FindFirstChild('Handle') then continue end
				if not isGeneratorLoot(drop) then continue end
				
				local dropName = drop.Name:lower()
				local isTargetType = false
				
				for _, name in ipairs(lootNames[itemType]) do
					if dropName:find(name:lower()) then
						isTargetType = true
						break
					end
				end
				
				if isTargetType then
					local dist = (drop.Handle.Position - originPos).Magnitude
					if dist <= Range.Value and dist < closestDist then
						closest = drop.Handle
						closestDist = dist
					end
				end
			end
			
			if closest then return closest end
		end
		
		return closest
	end
	
	local function switchAffinity(targetAffinity)
		local currentAff = lplr:GetAttribute('SpiritSummonerAffinity')
		if currentAff ~= targetAffinity then
			pcall(function()
				if bedwars.AbilityController:canUseAbility('spirit_summoner_switch_affinity') then
					bedwars.AbilityController:useAbility('spirit_summoner_switch_affinity')
					task.wait(0.1)
				end
			end)
		end
	end
	
	local function getTeammateHealth(plr)
		if not plr.Character then return 100 end
		local health = plr.Character:GetAttribute('Health') or 100
		local maxHealth = plr.Character:GetAttribute('MaxHealth') or 100
		return health, maxHealth
	end
	
	local function getLowHealthTeammate()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		
		for _, plr in ipairs(game:GetService('Players'):GetPlayers()) do
			if plr ~= lplr and plr:GetAttribute('Team') == myTeam then
				local health, maxHealth = getTeammateHealth(plr)
				if health <= 40 and health > 0 then
					return plr
				end
			end
		end
		return nil
	end
	
	local function startAutoSummon()
		if summonThread then
			task.cancel(summonThread)
			summonThread = nil
		end
		
		summonThread = task.spawn(function()
			while AutoUMA.Enabled and AutoSummon.Enabled do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				
				local hasStaff = false
				for _, item in ipairs(store.inventory.inventory.items) do
					if item.itemType == 'spirit_staff' then
						hasStaff = true
						break
					end
				end
				
				if hasStaff then
					local attackSpirits = lplr:GetAttribute('ReadySummonedAttackSpirits') or 0
					local healSpirits = lplr:GetAttribute('ReadySummonedHealSpirits') or 0
					local totalSpirits = attackSpirits + healSpirits
					
					if totalSpirits < 10 then
						local hasStone = false
						for _, item in ipairs(store.inventory.inventory.items) do
							if item.itemType == 'summon_stone' then
								hasStone = true
								break
							end
						end
						
						if hasStone then
							pcall(function()
								if bedwars.AbilityController:canUseAbility('summon_attack_spirit') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
									task.wait(0.5)
								end
							end)
						end
					end
				end
				
				task.wait(0.5)
			end
		end)
	end
	
	local function stopAutoSummon()
		if summonThread then
			task.cancel(summonThread)
			summonThread = nil
		end
	end
	
	AutoUMA = vape.Categories.Kits:CreateModule({
		Name = 'AutoUma',
		Function = function(callback)
			if callback then
				if not getgenv()._aerov4_original_calcLaunch then
					getgenv()._aerov4_original_calcLaunch = bedwars.ProjectileController.calculateImportantLaunchValues
				end
				old = getgenv()._aerov4_original_calcLaunch
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					hovering = true
					local self, projmeta, worldmeta, origin, shootpos = ...
					
					if not (projmeta.projectile == 'attack_spirit' or projmeta.projectile == 'heal_spirit') then
						hovering = false
						clearOutline()
						return old(...)
					end
					
					local originPos = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					local target = nil
					local targetPos = nil
					
					if CycleMode.Enabled then
						local targetLoot = getClosestLoot(originPos)
						if targetLoot and (targetLoot.Position - originPos).Magnitude <= Range.Value then
							target = targetLoot
							targetPos = targetLoot.Position
							updateOutline(targetLoot)
						else
							clearOutline()
						end
					end
					
					if HealMode.Enabled and not CycleMode.Enabled then
						local lowTeammate = getLowHealthTeammate()
						if lowTeammate and lowTeammate.Character and lowTeammate.Character.PrimaryPart then
							switchAffinity('heal')
							local dist = (lowTeammate.Character.PrimaryPart.Position - originPos).Magnitude
							if dist <= Range.Value then
								target = lowTeammate.Character.PrimaryPart
								targetPos = lowTeammate.Character.PrimaryPart.Position + Vector3.new(0, 2, 0)
								updateOutline(lowTeammate.Character)
							else
								clearOutline()
							end
						else
							clearOutline()
						end
					end
					
					if AttackMode.Enabled and not CycleMode.Enabled and not (HealMode.Enabled and getLowHealthTeammate()) then
						switchAffinity('attack')
						local plr = entitylib.EntityMouse({
							Part = 'RootPart',
							Range = 1000,
							Players = true,
							NPCs = true,
							Wallcheck = false,
							Origin = originPos
						})
						
						if plr and plr.RootPart and (plr.RootPart.Position - originPos).Magnitude <= Range.Value then
							target = plr.RootPart
							targetPos = plr.RootPart.Position + Vector3.new(0, 2, 0)
							updateOutline(plr.Character)
						else
							clearOutline()
						end
					end
					
					if target and targetPos then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							hovering = false
							clearOutline()
							return old(...)
						end
						
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + projmeta.fromPositionOffset
						
						local direction = (targetPos - offsetpos).Unit
						local distance = (targetPos - offsetpos).Magnitude
						local timeToReach = distance / projSpeed
						local dropAmount = 0.5 * gravity * (timeToReach * timeToReach)
						local adjustedTarget = targetPos + Vector3.new(0, dropAmount, 0)
						
						local newlook = CFrame.new(offsetpos, adjustedTarget)
						
						hovering = false
						return {
							initialVelocity = newlook.LookVector * projSpeed,
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = 5
						}
					end
					
					hovering = false
					clearOutline()
					return old(...)
				end
				
				if AutoSummon.Enabled then
					startAutoSummon()
				end
			else
				if old then
					bedwars.ProjectileController.calculateImportantLaunchValues = getgenv()._aerov4_original_calcLaunch or old
					old = nil
				end
				clearOutline()
				stopAutoSummon()
				selectedTarget = nil
			end
		end,
		Tooltip = 'Spirit Summoner automation - lock onto loot, enemies, or heal teammates'
	})
	
	CycleMode = AutoUMA:CreateToggle({
		Name = 'Cycle',
		Function = function(callback)
			if callback then
				if AttackMode.Enabled then
					AttackMode:Toggle()
				end
				if HealMode.Enabled then
					HealMode:Toggle()
				end
				PriorityDropdown.Object.Visible = true
			else
				PriorityDropdown.Object.Visible = false
				clearOutline()
			end
		end,
		Tooltip = 'Lock onto generator loot (iron/diamond/emerald) with priority system'
	})
	
	PriorityDropdown = AutoUMA:CreateDropdown({
		Name = 'Loot Priority',
		List = {'Emerald > Diamond > Iron', 'Diamond > Emerald > Iron', 'Iron > Diamond > Emerald'},
		Default = 'Emerald > Diamond > Iron',
		Darker = true
	})
	PriorityDropdown.Object.Visible = false
	
	AttackMode = AutoUMA:CreateToggle({
		Name = 'Attack',
		Function = function(callback)
			if callback then
				if CycleMode.Enabled then
					CycleMode:Toggle()
				end
				if HealMode.Enabled then
					HealMode:Toggle()
				end
				clearOutline()
			else
				clearOutline()
			end
		end,
		Tooltip = 'Lock onto enemies and attack them'
	})
	
	HealMode = AutoUMA:CreateToggle({
		Name = 'Heal',
		Function = function(callback)
			if callback then
				if CycleMode.Enabled then
					CycleMode:Toggle()
				end
				if AttackMode.Enabled then
					AttackMode:Toggle()
				end
				clearOutline()
			else
				clearOutline()
			end
		end,
		Tooltip = 'Heal teammates below 40 HP'
	})
	
	AutoSummon = AutoUMA:CreateToggle({
		Name = 'Auto Summon',
		Function = function(callback)
			if callback and AutoUMA.Enabled then
				startAutoSummon()
			else
				stopAutoSummon()
			end
		end,
		Default = true,
		Tooltip = 'Automatically summons spirits when you have summon stones'
	})
	
	TargetVisualiser = AutoUMA:CreateToggle({
		Name = 'Target Visualiser',
		Function = function(callback)
			if not callback then
				clearOutline()
			end
		end,
		Default = true,
		Tooltip = 'Shows gold outline on locked target'
	})
	
	Range = AutoUMA:CreateSlider({
		Name = 'Lock Range',
		Min = 10,
		Max = 500,
		Default = 70,
		Tooltip = 'Maximum distance to lock onto targets'
	})
end)

run(function()
    local Caitlyn
    local MethodDropdown
    local LowHealthSlider
    local ExecuteRangeSlider
    local HitRangeSlider
    local ProximityRangeSlider
    local connections = {}
    local Players = playersService
    local lplr = Players.LocalPlayer
    local currentTarget = nil
    local lastHitTime = 0
    local lastContractSelect = 0
    
    local function selectContract(targetPlayer)
        if not entitylib.isAlive then return false end
        if tick() - lastContractSelect < 0.1 then return false end
        
        local storeState = bedwars.Store:getState()
        local activeContract = storeState.Kit.activeContract
        local availableContracts = storeState.Kit.availableContracts or {}
        
        if activeContract then return false end
        if #availableContracts == 0 then return false end
        
        for _, contract in pairs(availableContracts) do
            if contract.target == targetPlayer then
                bedwars.Client:Get(remotes.BloodAssassinSelectContract):SendToServer({
                    contractId = contract.id
                })
                lastContractSelect = tick()
                return true
            end
        end
        return false
    end
    
    local function executeOnLowHealth()
        if not currentTarget or tick() - lastHitTime > 3 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local humanoid = currentTarget.Character:FindFirstChild("Humanoid")
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local health = humanoid.Health
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if health > 0 and health <= LowHealthSlider.Value and distance <= ExecuteRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function contractOnHit()
        if not currentTarget or tick() - lastHitTime > 0.5 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if distance <= HitRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function proximityContract()
        if not entitylib.isAlive then return end
        
        local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local closestPlayer = nil
        local closestDistance = ProximityRangeSlider.Value
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                
                if theirRoot and humanoid and humanoid.Health > 0 then
                    local distance = (myRoot.Position - theirRoot.Position).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
        
        if closestPlayer then
            selectContract(closestPlayer)
        end
    end
    
    Caitlyn = vape.Categories.Kits:CreateModule({
        Name = 'AutoCaitlyn',
        Function = function(callback)
            if callback then
                local damageConnection = vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if not entitylib.isAlive then return end
                    
                    local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
                    local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                
                    if attacker == lplr and victim and victim ~= lplr then
                        currentTarget = victim
                        lastHitTime = tick()
                    end
                end)
                table.insert(connections, damageConnection)
                
                task.spawn(function()
                    repeat
                        if entitylib.isAlive then
                            local method = MethodDropdown.Value
                            
                            if method == "Execute on Low HP" then
                                executeOnLowHealth()
                            elseif method == "Contract on Hit" then
                                contractOnHit()
                            elseif method == "Proximity Select" then
                                proximityContract()
                            end
                        end
                        task.wait(0.1)
                    until not Caitlyn.Enabled
                end)
            else
                for _, conn in pairs(connections) do
                    if typeof(conn) == "RBXScriptConnection" then
                        conn:Disconnect()
                    end
                end
                table.clear(connections)
                
                currentTarget = nil
                lastHitTime = 0
            end
        end,
        Tooltip = 'Auto contract selection for Caitlyn'
    })
    
    MethodDropdown = Caitlyn:CreateDropdown({
        Name = 'Method',
        List = {"Execute on Low HP", "Contract on Hit", "Proximity Select"},
        Default = "Execute on Low HP",
        Tooltip = 'Contract selection method',
        Function = function(value)
            LowHealthSlider.Object.Visible = (value == "Execute on Low HP")
            ExecuteRangeSlider.Object.Visible = (value == "Execute on Low HP")
            HitRangeSlider.Object.Visible = (value == "Contract on Hit")
            ProximityRangeSlider.Object.Visible = (value == "Proximity Select")
        end
    })
    
    LowHealthSlider = Caitlyn:CreateSlider({
        Name = 'Select HP',
        Min = 10,
        Max = 100,
        Default = 30,
        Tooltip = 'HP value to execute contract'
    })
    
    ExecuteRangeSlider = Caitlyn:CreateSlider({
        Name = 'Select Range',
        Min = 5,
        Max = 50,
        Default = 20,
        Suffix = ' studs',
        Tooltip = 'Range to select contract'
    })
    
    HitRangeSlider = Caitlyn:CreateSlider({
        Name = 'Hit Range',
        Min = 10,
        Max = 200,
        Default = 100,
        Suffix = ' studs',
        Tooltip = 'Max range to select a contract when hitting the player'
    })
    
    ProximityRangeSlider = Caitlyn:CreateSlider({
        Name = 'Proximity Range',
        Min = 10,
        Max = 200,
        Default = 50,
        Suffix = ' studs',
        Tooltip = 'Range to auto select nearby players'
    })
    
    LowHealthSlider.Object.Visible = true
    ExecuteRangeSlider.Object.Visible = true
    HitRangeSlider.Object.Visible = false
    ProximityRangeSlider.Object.Visible = false
end)

run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	local processedParts = {}
	local lastCleanup = 0
	
	local function cleanupDeadReferences()
		for obj, _ in pairs(originalMaterials) do
			if not obj or not obj.Parent then
				originalMaterials[obj] = nil
				processedParts[obj] = nil
			end
		end
	end
	
	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if processedParts[obj] then return end
			
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				obj.Material = Enum.Material.Plastic
				obj.Reflectance = 0
				processedParts[obj] = true
			end
		end
	end
	
	local function restoreNeon()
		for obj, data in pairs(originalMaterials) do
			if obj and obj.Parent then
				pcall(function()
					obj.Material = data.Material
					obj.Reflectance = data.Reflectance
				end)
			end
		end
		table.clear(originalMaterials)
		table.clear(processedParts)
	end
	
	local function batchProcessParts(parts, batchSize)
		local count = 0
		for i, part in ipairs(parts) do
			if part and part.Parent then
				removeNeonFromPart(part)
				count = count + 1
			end
			
			if i % batchSize == 0 then
				task.wait()
			end
		end
		return count
	end
	
	RemoveNeon = vape.Categories.BoostFPS:CreateModule({
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local allParts = {}
					for _, v in pairs(workspace:GetDescendants()) do
						if v:IsA("BasePart") then
							table.insert(allParts, v)
						end
					end
					
					batchProcessParts(allParts, 50)
				end)
				
				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					if RemoveNeon.Enabled then
						removeNeonFromPart(obj)
					end
				end)
				
				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						task.wait(5)
						
						if RemoveNeon.Enabled then
							local newParts = {}
							for _, v in pairs(workspace:GetDescendants()) do
								if v:IsA("BasePart") and not processedParts[v] and v.Material == Enum.Material.Neon then
									table.insert(newParts, v)
								end
							end
							
							if #newParts > 0 then
								batchProcessParts(newParts, 25)
							end
							
							if tick() - lastCleanup > 15 then
								cleanupDeadReferences()
								lastCleanup = tick()
							end
						end
					end
				end)
			else
				if neonConnection then
					neonConnection:Disconnect()
					neonConnection = nil
				end
				if safetyLoop then
					task.cancel(safetyLoop)
					safetyLoop = nil
				end
				restoreNeon()
			end
		end,
		Tooltip = 'Removes all neon materials for better FPS'
	})
end)

run(function()
    local Fisherman
    local AutoMinigameToggle
    local CompleteDelaySlider
    local PullAnimationToggle
    local MinigameAnimationToggle
    local FishermanSpyToggle
    local IgnoreTeammatesToggle
    local BlacklistOption
    local Blacklist
    local ESPToggle
    local ESPNotifyToggle
    local Players    = playersService
    local RunService = runService
    local lplr       = Players.LocalPlayer
	local RandomizeToggle
    local RandomRange
	local waitTime
    local fishNames = {
        fish_iron    = "Iron Fish",
        fish_diamond = "Diamond Fish",
        fish_gold    = "Gold Fish",
        fish_special = "Special Fish",
        fish_emerald = "Emerald Fish",
    }

    local function buildMessage(fishModel, drops)
        local fishName = fishNames[fishModel] or fishModel

        if fishModel == "fish_special" then
            if drops and drops[1] then
                return "You caught a " .. fishName .. "! You will receive a " .. tostring(drops[1].itemType)
            else
                return "You caught a " .. fishName .. "! (special item incoming)"
            end
        end

        if drops and drops[1] then
            local drop = drops[1]
            return "You caught a " .. fishName .. "! Receiving " ..
                   tostring(drop.amount) .. "x " .. tostring(drop.itemType)
        end

        return "You caught a " .. fishName .. "!"
    end

    local notifQueue = {}

    local function safeNotif(title, message, duration)
        table.insert(notifQueue, { title = title, message = message, duration = duration or 5 })
    end

    local heartbeatConn = nil

    local autoMinigameActive    = false
    local pullAnimationTrack    = nil
    local successAnimationTrack = nil
    local espOld                = nil

    local function stopAllAnimations()
        if pullAnimationTrack then
            pcall(function() pullAnimationTrack:Stop() end)
            pullAnimationTrack = nil
        end
        if successAnimationTrack then
            pcall(function() successAnimationTrack:Stop() end)
            successAnimationTrack = nil
        end
    end

    local function setupESP()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end
        if espOld then return end 
        espOld = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if ESPToggle.Enabled and ESPNotifyToggle.Enabled and dropData and dropData.fishModel then
                safeNotif("Fisherman ESP", buildMessage(dropData.fishModel, dropData.drops), 8)
            end
            return espOld(self, dropData, result)
        end

        Fisherman:Clean(function()
            if espOld then
                bedwars.FishingMinigameController.startMinigame = espOld
                espOld = nil
            end
        end)
    end

    local function cleanupESP()
        if espOld then
            bedwars.FishingMinigameController.startMinigame = espOld
            espOld = nil
        end
    end

    local function setupAutoMinigame()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end

        local old = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if not AutoMinigameToggle.Enabled then
                return old(self, dropData, result)
            end

            if BlacklistOption.Enabled and dropData and dropData.fishModel then
                if table.find(Blacklist.ListEnabled, dropData.fishModel) then
                    local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    return old(self, dropData, result)
                end
            end

            autoMinigameActive = true
            stopAllAnimations()

            local waitTime = 0
            if RandomizeToggle and RandomizeToggle.Enabled then
                local min = RandomRange.ValueMin
                local max = RandomRange.ValueMax
                waitTime = min + (max - min) * math.random()
            else
                waitTime = CompleteDelaySlider.Value
            end

            task.spawn(function()
                if PullAnimationToggle.Enabled and waitTime > 0 then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_PULLING
                        )
                    end)
                    if ok and track then pullAnimationTrack = track end
                end

                if waitTime > 0 then
                    task.wait(waitTime)
                end

                if pullAnimationTrack then
                    pcall(function() pullAnimationTrack:Stop() end)
                    pullAnimationTrack = nil
                end

                if MinigameAnimationToggle.Enabled then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_CATCH_SUCCESS
                        )
                    end)
                    if ok and track then successAnimationTrack = track end
                end

                if result then
                    pcall(function() result({ win = true }) end)
                end

                task.wait(0.5)

                if successAnimationTrack then
                    pcall(function() successAnimationTrack:Stop() end)
                    successAnimationTrack = nil
                end

                autoMinigameActive = false
            end)
        end

        Fisherman:Clean(function()
            bedwars.FishingMinigameController.startMinigame = old
            stopAllAnimations()
        end)
    end

    local function setupFishermanSpy()
        if not bedwars or not bedwars.Client then
            warn("[AutoFisher] bedwars.Client not found")
            return
        end

        bedwars.Client:WaitFor(remotes.FishCaught):andThen(function(rbx)
            Fisherman:Clean(rbx:Connect(function(tbl)
                local char = tbl.catchingPlayer and tbl.catchingPlayer.Character
                if not char then return end

                local fish    = tbl.dropData and tbl.dropData.fishModel
                local plrName = char.Name
                local str     = plrName:sub(1,1):upper() .. plrName:sub(2)
                local strfish = fishNames[tostring(fish)] or "Unknown Fish"

                if IgnoreTeammatesToggle.Enabled then
                    local currentPlr = Players:GetPlayerFromCharacter(char)
                    if currentPlr and currentPlr.Team == lplr.Team then return end
                end

                safeNotif("Fisherman Spy", str .. " caught a " .. strfish, 8)
            end))
        end)
    end

    Fisherman = vape.Categories.Kits:CreateModule({
        Name    = "AutoFisher",
        Tooltip = "Auto minigame, loot ESP, blacklist, and spy for the Fisherman kit",
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled           then setupESP()          end
                if AutoMinigameToggle.Enabled  then setupAutoMinigame() end
                if FishermanSpyToggle.Enabled  then setupFishermanSpy() end

                heartbeatConn = RunService.Heartbeat:Connect(function()
                    if #notifQueue == 0 then return end
                    local entry = table.remove(notifQueue, 1)
                    pcall(notif, entry.title, entry.message, entry.duration)
                end)
                Fisherman:Clean(heartbeatConn)

            else
                autoMinigameActive = false
                stopAllAnimations()
                cleanupESP()
                notifQueue = {} 
            end
        end
    })

    AutoMinigameToggle = Fisherman:CreateToggle({
        Name    = "Auto Minigame",
        Default = false,
        Tooltip = "Automatically complete the fishing minigame",
        Function = function(cv)
            if CompleteDelaySlider and CompleteDelaySlider.Object then 
                CompleteDelaySlider.Object.Visible = cv and not (RandomizeToggle and RandomizeToggle.Enabled) 
            end
            if PullAnimationToggle     and PullAnimationToggle.Object     then PullAnimationToggle.Object.Visible     = cv end
            if MinigameAnimationToggle and MinigameAnimationToggle.Object then MinigameAnimationToggle.Object.Visible = cv end
            if RandomizeToggle and RandomizeToggle.Object then RandomizeToggle.Object.Visible = cv end
            if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv and RandomizeToggle.Enabled end
            if Fisherman.Enabled and cv then setupAutoMinigame() end
        end
    })

    CompleteDelaySlider = Fisherman:CreateSlider({
        Name    = "Complete Delay",
        Min     = 0,
        Max     = 5,
        Default = 1,
        Decimal = 10,
        Suffix  = "s",
        Visible = false,
        Tooltip = "Delay before auto-completing (looks more legit)"
    })

    RandomizeToggle = Fisherman:CreateToggle({
        Name    = "Randomize Timing",
        Default = false,
        Tooltip = "Use random delay between min and max instead of fixed delay",
        Function = function(cv)
            if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv end
            if CompleteDelaySlider and CompleteDelaySlider.Object then CompleteDelaySlider.Object.Visible = not cv end
        end
    })

    RandomRange = Fisherman:CreateTwoSlider({
        Name    = "Random Delay Range",
        Min     = 0.1,
        Max     = 5,
        DefaultMin = 0.5,
        DefaultMax = 2,
        Decimal = 10,
        Visible = false,
        Tooltip = "Minimum and maximum delay for random timing"
    })

    PullAnimationToggle = Fisherman:CreateToggle({
        Name    = "Pull Animation",
        Default = true,
        Visible = false,
        Tooltip = "Play rod-pulling animation during delay (requires delay > 0)"
    })

    MinigameAnimationToggle = Fisherman:CreateToggle({
        Name    = "Success Animation",
        Default = true,
        Visible = false,
        Tooltip = "Play catch-success animation on completion"
    })

    BlacklistOption = Fisherman:CreateToggle({
        Name    = "Blacklist",
        Default = false,
        Tooltip = "Auto-jump and skip auto-complete for blacklisted fish",
        Function = function(cv)
            if Blacklist and Blacklist.Object then Blacklist.Object.Visible = cv end
        end
    })

    Blacklist = Fisherman:CreateTextList({
        Name    = "Blacklist Fish",
        Default = { "fish_iron" }
    })

    ESPToggle = Fisherman:CreateToggle({
        Name    = "Fisherman ESP",
        Default = false,
        Tooltip = "Shows what fish you are catching and what loot you will receive",
        Function = function(cv)
            if ESPNotifyToggle and ESPNotifyToggle.Object then ESPNotifyToggle.Object.Visible = cv end
            if Fisherman.Enabled then
                if cv then setupESP() else cleanupESP() end
            end
        end
    })

    ESPNotifyToggle = Fisherman:CreateToggle({
        Name    = "Notify Loot",
        Default = true,
        Visible = false,
        Tooltip = "Show a notification with the fish name and loot details"
    })

    FishermanSpyToggle = Fisherman:CreateToggle({
        Name    = "Fish Spy",
        Default = false,
        Tooltip = "Get notified when other players catch fish",
        Function = function(cv)
            if IgnoreTeammatesToggle and IgnoreTeammatesToggle.Object then IgnoreTeammatesToggle.Object.Visible = cv end
            if Fisherman.Enabled and cv then setupFishermanSpy() end
        end
    })

    IgnoreTeammatesToggle = Fisherman:CreateToggle({
        Name    = "Ignore Teammates",
        Default = true,
        Visible = false,
        Tooltip = "Don't notify for teammates catching fish"
    })
end)

run(function()
    local AutoWhisper
    local PlayerDropdown
    local AutoHeal
    local AutoHealSlider
    local AutoFly
    local LimitToItem
    local RefreshButton
    local running = false
    local healRunning = false
    local flyRunning = false
    local currentTarget = nil
    local currentMountedPlayer = nil
    local fallCheckTimer = 0
    local hasActivatedFly = false
    
    local function isHoldingOwlOrb()
        if not entitylib.isAlive then return false end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == "owl_orb" then
                return true
            end
        end
        return false
    end
    
    local function getMountedPlayer()
        local owlTarget = lplr:GetAttribute('OwlTarget')
        if owlTarget then
            return playersService:GetPlayerByUserId(owlTarget)
        end
        return nil
    end
    
    local function mountBirdToPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return false end
        
        if LimitToItem.Enabled and not isHoldingOwlOrb() then
            return false
        end
        
        local success = false
        pcall(function()
            local result = bedwars.Client:Get(remotes.SummonOwl).instance:InvokeServer(targetPlayer)
            
            if result then
            task.wait(0.05)
            
            pcall(function()
    			bedwars.Client:Get(remotes.UseAbility).instance:FireServer("SUMMON_OWL")
			end)
                
                currentMountedPlayer = targetPlayer
                success = true
            end
        end)
        
        return success
    end
    
    local function demountOwl()
        pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("DEACTIVE_OWL")
            
            task.wait(0.05)
            
            bedwars.Client:Get(remotes.RemoveOwl).instance:FireServer()
        end)
        
        currentMountedPlayer = nil
    end
    
    local function healTarget()
        if not currentTarget then return end
        
        pcall(function()
            bedwars.Client:Get(remotes.OwlActionAbilities):SendToServer({
                target = currentTarget,
                ability = "owl_heal"
            })
            task.wait(0.022)
            
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("OWL_HEAL")
        end)
    end
    
    local function isFalling(player)
        if not player or not player.Character or not player.Character.PrimaryPart then
            return false
        end
        
        local velocity = player.Character.PrimaryPart.AssemblyLinearVelocity.Y
        return velocity < -20
    end
    
    local function isAboveVoid(player)
        if not player or not player.Character or not player.Character.PrimaryPart then
            return false
        end
        
        local rayOrigin = player.Character.PrimaryPart.Position
        local rayDirection = Vector3.new(0, -1000, 0)
        
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {player.Character, gameCamera}
        raycastParams.RespectCanCollide = true
        
        local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        if not rayResult then
            return true
        end
        
        return rayResult.Distance > 200
    end
    
    local function activateFly()
        if not currentTarget then return end
        
        pcall(function()
            bedwars.Client:Get(remotes.OwlActionAbilities):SendToServer({
                target = currentTarget,
                ability = "owl_lift"
            })
            task.wait(0.022)
            
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("OWL_LIFT")
            
            hasActivatedFly = true
            task.spawn(function()
                task.wait(85)
                hasActivatedFly = false
            end)
        end)
    end
    
    AutoWhisper = vape.Categories.Kits:CreateModule({
        Name = "AutoWhisper",
        Function = function(callback)
            running = callback
            healRunning = callback
            flyRunning = callback
            
            if callback then
                task.spawn(function()
                    while running do
                        if LimitToItem.Enabled and not isHoldingOwlOrb() then
                            task.wait(0.2)
                            continue
                        end
                        
                        local targetPlayer = playersService:FindFirstChild(PlayerDropdown.Value)
                        if targetPlayer then
                            currentTarget = targetPlayer
                            
                            local mountedTo = getMountedPlayer()
                            
                            if mountedTo ~= targetPlayer then
                                if mountedTo and mountedTo ~= targetPlayer then
                                    demountOwl()
                                    task.wait(0.3)
                                end
                                
                                if not mountedTo or mountedTo ~= targetPlayer then
                                    local success = mountBirdToPlayer(targetPlayer)
                                    if not success then
                                        task.wait(0.5)
                                    else
                                        task.wait(1)
                                    end
                                end
                            else
                                task.wait(0.5)
                            end
                        else
                            task.wait(0.5)
                        end
                    end
                end)
                
                if AutoHeal.Enabled then
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget and currentMountedPlayer == currentTarget then
                                local health, maxHealth = getPlayerHealth(currentTarget)
                                local healthPercent = (health / maxHealth) * 100
                                
                                if healthPercent < AutoHealSlider.Value and healthPercent < 90 then
                                    healTarget()
                                    task.wait(8.5)
                                end
                            end
                            
                            task.wait(0.5)
                        end
                    end)
                end
                
                if AutoFly.Enabled then
                    task.spawn(function()
                        while flyRunning and AutoFly.Enabled do
                            if currentTarget and currentMountedPlayer == currentTarget and not hasActivatedFly then
                                if isFalling(currentTarget) and isAboveVoid(currentTarget) then
                                    fallCheckTimer = fallCheckTimer + 0.1
                                    
                                    if fallCheckTimer >= 0.5 then
                                        activateFly()
                                        fallCheckTimer = 0
                                    end
                                else
                                    fallCheckTimer = 0
                                end
                            else
                                fallCheckTimer = 0
                            end
                            
                            task.wait(0.1)
                        end
                    end)
                end
                
                AutoWhisper:Clean(playersService.PlayerAdded:Connect(function()
                    task.wait(0.5)
                    local newList = getTeammateNames()
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                end))
                
                AutoWhisper:Clean(playersService.PlayerRemoving:Connect(function(player)
                    task.wait(0.5)
                    local newList = getTeammateNames()
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                    
                    if currentTarget == player then
                        currentTarget = nil
                        currentMountedPlayer = nil
                    end
                end))
                
                AutoWhisper:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(0.5)
                    local newList = getTeammateNames()
                    if PlayerDropdown then
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            end
                        end
                    end
                    currentTarget = nil
                    currentMountedPlayer = nil
                    hasActivatedFly = false
                end))
                
            else
                running = false
                healRunning = false
                flyRunning = false
                currentTarget = nil
                currentMountedPlayer = nil
                hasActivatedFly = false
                fallCheckTimer = 0
            end
        end,
        Tooltip = "Automatically mount bird to teammate, heal them, and save from void"
    })
    
    PlayerDropdown = AutoWhisper:CreateDropdown({
        Name = "Mount Target",
        List = {},
        Function = function(val)
            if val then
                local targetPlayer = playersService:FindFirstChild(val)
                if targetPlayer then
                    currentTarget = targetPlayer
                end
            end
        end,
        Tooltip = "Select teammate to mount owl to"
    })
    
    RefreshButton = AutoWhisper:CreateButton({
        Name = "Refresh Teammates",
        Function = function()
            task.spawn(function()
                local newList = getTeammateNames()
                
                if PlayerDropdown then
                    pcall(function()
                        PlayerDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            else
                                PlayerDropdown:SetValue(PlayerDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("Auto Whisper", string.format("Refreshed teammate list (%d teammates)", #newList), 2)
            end)
        end,
        Tooltip = "Manually refresh the teammate list"
    })
    
    LimitToItem = AutoWhisper:CreateToggle({
        Name = "Limit to Owl Orb",
        Default = true,
        Function = function(val)
        end,
        Tooltip = "Only mount owl when holding owl_orb item"
    })

    AutoFly = AutoWhisper:CreateToggle({
        Name = "Auto Fly",
        Default = true,
        Function = function(val)
            if AutoWhisper.Enabled then
                if val then
                    flyRunning = true
                    hasActivatedFly = false
                    fallCheckTimer = 0
                    
                    task.spawn(function()
                        while flyRunning and AutoFly.Enabled do
                            if currentTarget and currentMountedPlayer == currentTarget and not hasActivatedFly then
                                if isFalling(currentTarget) and isAboveVoid(currentTarget) then
                                    fallCheckTimer = fallCheckTimer + 0.1
                                    
                                    if fallCheckTimer >= 0.5 then
                                        activateFly()
                                        fallCheckTimer = 0
                                    end
                                else
                                    fallCheckTimer = 0
                                end
                            else
                                fallCheckTimer = 0
                            end
                            
                            task.wait(0.1)
                        end
                    end)
                else
                    flyRunning = false
                    hasActivatedFly = false
                    fallCheckTimer = 0
                end
            end
        end,
        Tooltip = "Automatically activate lift when target is falling into void"
    })
    
    AutoHeal = AutoWhisper:CreateToggle({
        Name = "Auto Heal",
        Default = true,
        Function = function(val)
            if AutoHealSlider and AutoHealSlider.Object then
                AutoHealSlider.Object.Visible = val
            end
            
            if AutoWhisper.Enabled then
                if val then
                    healRunning = true
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget and currentMountedPlayer == currentTarget then
                                local health, maxHealth = getPlayerHealth(currentTarget)
                                local healthPercent = (health / maxHealth) * 100
                                
                                if healthPercent < AutoHealSlider.Value and healthPercent < 90 then
                                    healTarget()
                                    task.wait(8.5)
                                end
                            end
                            
                            task.wait(0.5)
                        end
                    end)
                else
                    healRunning = false
                end
            end
        end,
        Tooltip = "Automatically heal target when health drops below threshold"
    })
    
    AutoHealSlider = AutoWhisper:CreateSlider({
        Name = "Heal Threshold",
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = "%",
        Tooltip = "Heal when target's health drops below this percentage (stops at 90%)"
    })
end)

run(function()
    local Eldertree
    local CollectionToggle
    local Animation
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local SwordCheck
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionRunning = false

    local function sendNotification(count)
        notif("Eldertree ESP", string.format("%d orbs spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function isHoldingSword()
        if not store.hand or not store.hand.tool then return false end
        local meta = bedwars.ItemMeta[store.hand.tool.Name]
        return meta and meta.sword
    end

    local function getProperImage()
        return bedwars.getIcon({itemType = 'natures_essence_1'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'treeOrb'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'orb', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
    end

    local function setupESP()
        for _, v in collectionService:GetTagged('treeOrb') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        Eldertree:Clean(collectionService:GetInstanceAddedSignal('treeOrb'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                task.wait(0.1)
                Added(v.PrimaryPart)
            end
        end))

        Eldertree:Clean(collectionService:GetInstanceRemovedSignal('treeOrb'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))
        
        Eldertree:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

				if SwordCheck.Enabled and isHoldingSword() then
					shouldShow = false
				end

                billboard.Enabled = shouldShow
            end
        end))
    end

	local function collectOrb(orb)
		if not orb or not orb.Parent then return false end
		
		local treeOrbSecret = orb:GetAttribute('TreeOrbSecret')
		if not treeOrbSecret then return false end
		
		if entitylib.isAlive then
			bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
			bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
			bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
		end
		
		local success = bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({
			treeOrbSecret = treeOrbSecret
		})
		
		if success then
			orb:Destroy()
			return true
		end
		return false
	end

    local function startCollection()
        collectionRunning = true
        task.spawn(function()
            while collectionRunning and Eldertree.Enabled and CollectionToggle.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local orbsFound = false
                
                for _, v in collectionService:GetTagged('treeOrb') do
                    if not collectionRunning or not Eldertree.Enabled or not CollectionToggle.Enabled then 
                        break 
                    end
                    
                    if v:IsA("Model") and v.PrimaryPart then
                        local orbPos = v.PrimaryPart.Position
                        local distance = (localPosition - orbPos).Magnitude
                        
                        if distance <= range then
                            orbsFound = true
                            
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if collectOrb(v) then
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if not orbsFound then
                    task.wait(0.2)
                else
                    task.wait(0.1)
                end
            end
            collectionRunning = false
        end)
    end

    Eldertree = vape.Categories.Kits:CreateModule({
        Name = 'AutoEldertree',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
            else
                collectionRunning = false
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
        Tooltip = 'automatically collects tree orbs and esp'
    })
    
    CollectionToggle = Eldertree:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'automatically collect tree orbs',
        Function = function(callback)
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end

            if not callback then
                if DelaySlider and DelaySlider.Object then
                    DelaySlider.Object.Visible = false
                end
            else
                if CollectionDelay and CollectionDelay.Enabled then
                    if DelaySlider and DelaySlider.Object then
                        DelaySlider.Object.Visible = true
                    end
                end
            end
            
            if callback and Eldertree.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    Animation = Eldertree:CreateToggle({
        Name = 'Animation',
        Default = true,
        Tooltip = 'play collection animation and sound'
    })
    
    CollectionDelay = Eldertree:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'add delay before collecting orbs',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Eldertree:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'delay in seconds before collecting'
    })
    
    RangeSlider = Eldertree:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'control distance you want to collect orbs'
    })

    ESPToggle = Eldertree:CreateToggle({
        Name = 'Eldertree ESP',
        Default = false,
        Tooltip = 'shows tree orb locations',
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = callback end

            if not callback then
                if ESPColor and ESPColor.Object then
                    ESPColor.Object.Visible = false
                end
            else
                if ESPBackground and ESPBackground.Enabled then
                    if ESPColor and ESPColor.Object then
                        ESPColor.Object.Visible = true
                    end
                end
            end
            
            if Eldertree.Enabled then
                if callback then 
                    setupESP() 
                else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = Eldertree:CreateToggle({
        Name = 'Notify',
        Default = false,
        Tooltip = 'get notifications when orbs spawn'
    })
    
    ESPBackground = Eldertree:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    ESPColor = Eldertree:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    SwordCheck = Eldertree:CreateToggle({
        Name = 'Sword Check',
        Default = false,
        Tooltip = 'only show esp when holding a sword'
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false
        end
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = false end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = false end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = false end
        if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = false end
    end)
end)

run(function()
    local StarCollector
    local CollectionToggle
    local Animation
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local SwordCheck
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local starCooldowns = {}
    local COOLDOWN_TIME = 0.5
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionRunning = false

    local function sendNotification(count)
        notif("Star ESP", string.format("%d stars spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function isHoldingSword()
        if not store.hand or not store.hand.tool then return false end
        local meta = bedwars.ItemMeta[store.hand.tool.Name]
        return meta and meta.sword
    end

    local function getProperImage(v)
        local parent = v.Parent
        if parent and parent:IsA("Model") then
            local modelName = parent.Name
            if modelName == "CritStar" then
                return bedwars.getIcon({itemType = 'crit_star'}, true)
            elseif modelName == "VitalityStar" then
                return bedwars.getIcon({itemType = 'vitality_star'}, true)
            elseif modelName:find("vitality") or modelName:lower():find("vitality") then
                return bedwars.getIcon({itemType = 'vitality_star'}, true)
            elseif modelName:find("crit") or modelName:lower():find("crit") then
                return bedwars.getIcon({itemType = 'crit_star'}, true)
            end
        end
        return bedwars.getIcon({itemType = 'crit_star'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'stars'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage(v)
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'star', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
        starCooldowns[v] = nil
    end

    local function setupESP()
        for _, v in collectionService:GetTagged('stars') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        StarCollector:Clean(collectionService:GetInstanceAddedSignal('stars'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                task.wait(0.1)
                Added(v.PrimaryPart)
            end
        end))

        StarCollector:Clean(collectionService:GetInstanceRemovedSignal('stars'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))
        
        StarCollector:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if SwordCheck.Enabled and isHoldingSword() then
                    shouldShow = false
                end

                billboard.Enabled = shouldShow
            end
        end))
    end

    local function collectStar(star)
        if not star or not star.Parent then return end
        
        if Animation.Enabled and entitylib.isAlive then
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
            bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
        end
        
        bedwars.StarCollectorController:collectEntity(lplr, star, star.Name)
    end

	local function startCollection()
		collectionRunning = true
		task.spawn(function()
			while collectionRunning and StarCollector.Enabled and CollectionToggle.Enabled do
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local localPosition = entitylib.character.RootPart.Position
				local range = RangeSlider.Value
				local collected = false

				for _, v in collectionService:GetTagged('stars') do
					if not collectionRunning or not StarCollector.Enabled or not CollectionToggle.Enabled then
						break
					end

					if v:IsA("Model") and v.PrimaryPart then
						local starPos = v.PrimaryPart.Position
						local distance = (localPosition - starPos).Magnitude

						if distance <= range then
							local lastAttempt = starCooldowns[v]
							if lastAttempt and tick() - lastAttempt < COOLDOWN_TIME then
								continue
							end
							starCooldowns[v] = tick()
							collectStar(v)
							collected = true
							break
						end
					end
				end

				task.wait(collected and 0.1 or 0.2)
			end
			collectionRunning = false
		end)
	end

    StarCollector = vape.Categories.Kits:CreateModule({
        Name = 'AutoStar',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
            else
                collectionRunning = false
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(spawnQueue)
                table.clear(starCooldowns)
                lastNotification = 0
            end
        end,
        Tooltip = 'automatically collects stars and esp'
    })
    
    CollectionToggle = StarCollector:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'automatically collect stars',
        Function = function(callback)
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
            if callback and StarCollector.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    Animation = StarCollector:CreateToggle({
        Name = 'Animation',
        Default = true,
        Tooltip = 'play collection animation and sound'
    })
    
    RangeSlider = StarCollector:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 18,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'control distance you want to collect stars'
    })
    
    ESPToggle = StarCollector:CreateToggle({
        Name = 'Star ESP',
        Default = false,
        Tooltip = 'shows star locations',
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = callback end
            
            if StarCollector.Enabled then
                if callback then 
                    setupESP() 
                else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = StarCollector:CreateToggle({
        Name = 'Notify',
        Default = false,
        Tooltip = 'get notifications when stars spawn'
    })
    
    ESPBackground = StarCollector:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    ESPColor = StarCollector:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    SwordCheck = StarCollector:CreateToggle({
        Name = 'Sword Check',
        Default = false,
        Tooltip = 'only show esp when holding a sword'
    })

    task.defer(function()
        local espOn = ESPToggle and ESPToggle.Enabled
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = espOn end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = espOn end
        if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = espOn end
    end)
end)

run(function()
    local Melody
    local SelfHeal
    local TeammateHeal
    local RangeSlider
    local healRunning = false
    local lastHealTime = 0
    local healCooldown = 1

    local function getItem(itemName)
        if not entitylib.isAlive then return false end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == itemName then
                return true
            end
        end
        return false
    end

    local function getLowestHealthTeammate()
        if not entitylib.isAlive then return nil end
        
        local localPosition = entitylib.character.RootPart.Position
        local range = RangeSlider.Value
        local lowestHp = math.huge
        local targetEntity = nil
        
        for _, v in entitylib.List do
            if v.Player and v.Player ~= lplr and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
                local distance = (localPosition - v.RootPart.Position).Magnitude
                
                if distance <= range and v.Health < lowestHp and v.Health < v.MaxHealth then
                    lowestHp = v.Health
                    targetEntity = v
                end
            end
        end
        
        return targetEntity
    end

    local function shouldSelfHeal()
        if not entitylib.isAlive then return false end
        
        local currentHealth = lplr.Character:GetAttribute('Health') or 0
        local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
        
        return currentHealth < maxHealth
    end

    local function performHeal(target)
        local currentTime = tick()
        if currentTime - lastHealTime < healCooldown then
            return false
        end
        
        if not getItem('guitar') then
            return false
        end
        
        bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
            healTarget = target
        })
        
        lastHealTime = currentTime
        return true
    end

    local function startHealing()
        healRunning = true
        task.spawn(function()
            while healRunning and Melody.Enabled do
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end
                
                if not getItem('guitar') then
                    task.wait(0.2)
                    continue
                end
                
                local healed = false
                
                if SelfHeal.Enabled and shouldSelfHeal() then
                    if performHeal(lplr.Character) then
                        healed = true
                    end
                end
                
                if not healed and TeammateHeal.Enabled then
                    local teammate = getLowestHealthTeammate()
                    if teammate then
                        if performHeal(teammate.Character) then
                            healed = true
                        end
                    end
                end
                
                task.wait(0.1)
            end
            healRunning = false
        end)
    end

    Melody = vape.Categories.Kits:CreateModule({
        Name = 'AutoMelody',
        Function = function(callback)
            if callback then
                lastHealTime = 0
                startHealing()
            else
                healRunning = false
                lastHealTime = 0
            end
        end,
        Tooltip = 'Automatically heals yourself and teammates with guitar'
    })
    
    SelfHeal = Melody:CreateToggle({
        Name = 'Self Heal',
        Default = true,
        Tooltip = 'Automatically heal yourself when damaged'
    })
    
    TeammateHeal = Melody:CreateToggle({
        Name = 'Teammate Heal',
        Default = true,
        Tooltip = 'Automatically heal teammates when damaged',
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then
                RangeSlider.Object.Visible = callback
            end
        end
    })
    
    RangeSlider = Melody:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 51,
        Default = 30,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Maximum distance to heal teammates'
    })
end)

run(function()
    local Zeno
    local Targets
	local Targets
	local LightningStrike
	local LightningStorm
	local AutoShockwave
	local ShockwaveRange
	local AbilityRange
	local abilityRunning = false
	local lastAbilityUse = 0
	local lastShockwaveUse = 0
	local damageTracker = {}
	local rayCheck = cloneRaycast()

    local function trackDamage(entity, damage)
        local key = entity.Player and entity.Player.UserId or tostring(entity)
        if not damageTracker[key] then
            damageTracker[key] = 0
        end
        damageTracker[key] = damageTracker[key] + (damage or 1)
    end

    local function isHoldingWizardStaff()
        if not store.hand or not store.hand.tool then return false end
        local itemType = store.hand.tooltype or store.hand.tool.Name
        return itemType and (itemType:find("wizard_staff") or itemType:find("zeno"))
    end

    local function useAbility(abilityType, targetPos)
        local success = pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer(abilityType, {
                target = targetPos
            })
        end)

        if success then
            lastAbilityUse = tick()
        end

        return success
    end

    local function performShockwave()
        if not AutoShockwave.Enabled then return false end
        if not entitylib.isAlive then return false end
        if not isHoldingWizardStaff() then return false end

        local currentTime = tick()
        if (currentTime - lastShockwaveUse) < 1 then
            return false
        end

        local originPos = entitylib.character.RootPart.Position
        local shockRange = ShockwaveRange.Value

        local nearbyEnemies = 0
        for _, ent in entitylib.List do
            if ent.RootPart then
                local isValidEnemy = false

                if Targets.Players.Enabled and ent.Player and ent.Player ~= lplr then
                    isValidEnemy = isEnemy(ent)
                elseif Targets.NPCs.Enabled and ent.NPC then
                    isValidEnemy = isEnemy(ent)
                end

                if isValidEnemy then
                    local distance = (ent.RootPart.Position - originPos).Magnitude
                    if distance <= shockRange then
                        nearbyEnemies = nearbyEnemies + 1
                    end
                end
            end
        end

        if nearbyEnemies > 0 then
            local success = pcall(function()
                game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("SHOCKWAVE", {
                    target = Vector3.zero
                })
            end)

            if success then
                lastShockwaveUse = currentTime
                return true
            end
        end

        return false
    end

	local function performLightningAbility()
		if not entitylib.isAlive then return false end
		if not isHoldingWizardStaff() then return false end

		local originPos = entitylib.character.RootPart.Position
		local range = AbilityRange.Value
		local target = nil
		local entities = entitylib.AllPosition({
			Range = range,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 1,
			Sort = sortmethods[SortMethod.Value]
		})
		target = entities and entities[1]

        if not target or not target.RootPart then return false end
        if not isEnemy(target) then return false end
        local targetPos = target.RootPart.Position

        local usedAny = false

        if LightningStorm.Enabled then
            if bedwars.AbilityController:canUseAbility("LIGHTNING_STORM") then
                trackDamage(target, 4)
                useAbility("LIGHTNING_STORM", targetPos)
                usedAny = true
            end
        end

        if LightningStrike.Enabled then
            if bedwars.AbilityController:canUseAbility("LIGHTNING_STRIKE") then
                trackDamage(target, 1)
                useAbility("LIGHTNING_STRIKE", targetPos)
                usedAny = true
            end
        end

        return usedAny
    end

    local function startAbilityLoop()
        abilityRunning = true
        task.spawn(function()
            while abilityRunning and Zeno.Enabled do
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end

                local usedShockwave = performShockwave()

                if not usedShockwave then
                    performLightningAbility()
                end

                task.wait(0.01)
            end
            abilityRunning = false
        end)
    end

    Zeno = vape.Categories.Kits:CreateModule({
        Name = 'AutoZeno',
        Function = function(callback)
            if callback then
                lastAbilityUse = 0
                lastShockwaveUse = 0
                damageTracker = {}
                startAbilityLoop()
            else
                abilityRunning = false
                lastAbilityUse = 0
                lastShockwaveUse = 0
                damageTracker = {}
            end
        end,
        Tooltip = 'Automatically uses Zeno wizard abilities on ENEMIES only'
    })

    Targets = Zeno:CreateTargets({
        Players = true,
        NPCs = false,
        Walls = true
    })

    SortMethod = Zeno:CreateDropdown({
        Name = 'Sort Method',
        List = {'Distance', 'Damage', 'Threat', 'Kit', 'Health', 'Angle', 'Forest'},
        Default = 'Distance',
        Tooltip = 'How to prioritize targets'
    })

    LightningStrike = Zeno:CreateToggle({
        Name = 'Lightning Strike',
        Default = true,
        Tooltip = 'Use Lightning Strike ability'
    })

    LightningStorm = Zeno:CreateToggle({
        Name = 'Lightning Storm',
        Default = true,
        Tooltip = 'Use Lightning Storm ability (higher priority)'
    })

    AutoShockwave = Zeno:CreateToggle({
        Name = 'Auto Shockwave',
        Default = false,
        Tooltip = 'Automatically use shockwave when enemies are nearby',
        Function = function(callback)
            if ShockwaveRange and ShockwaveRange.Object then
                ShockwaveRange.Object.Visible = callback
            end
        end
    })

    ShockwaveRange = Zeno:CreateSlider({
        Name = 'Shockwave Range',
        Min = 1,
        Max = 12,
        Default = 8,
        Suffix = ' studs',
        Visible = false,
        Tooltip = 'Range to activate shockwave'
    })

    AbilityRange = Zeno:CreateSlider({
        Name = 'Ability Range',
        Min = 1,
        Max = 50,
        Default = 30,
        Suffix = ' studs',
        Tooltip = 'Max range for lightning ability'
    })
end)

run(function()
    local GeneratorESP
    DiamondToggle = nil
    EmeraldToggle = nil
    TeamGenToggle = nil
    ShowOwnTeamGen = nil
    ShowEnemyTeamGen = nil
    local UIStyle
    local CollectionService = collectionService
    local RunService = runService
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local CompactFolder = Instance.new('Folder')
    CompactFolder.Parent = vape.gui
    local teamColors = {
        [1] = {name = "Blue",   color = Color3.fromRGB(85, 150, 255)},
        [2] = {name = "Orange", color = Color3.fromRGB(255, 150, 50)},
        [3] = {name = "Pink",   color = Color3.fromRGB(255, 100, 200)},
        [4] = {name = "Yellow", color = Color3.fromRGB(255, 255, 50)}
    }

    local generatorTypes = {
        diamond = {
            keywords = {'diamond'},
            color = Color3.fromRGB(85, 200, 255),
            icon = 'diamond',
            displayName = 'Diamond',
            isTeamGen = false
        },
        emerald = {
            keywords = {'emerald'},
            color = Color3.fromRGB(0, 255, 100),
            icon = 'emerald',
            displayName = 'Emerald',
            isTeamGen = false
        }
    }

    local compactUI = Instance.new('ScreenGui')
    compactUI.Name = 'GeneratorCompactUI'
    compactUI.Parent = vape.gui
    compactUI.Enabled = false
    compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    compactUI.DisplayOrder = 10
    compactUI.ResetOnSpawn = false

    local mainFrame = Instance.new('Frame')
    mainFrame.Name = 'MainFrame'
    mainFrame.Parent = compactUI
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Position = UDim2.new(1, -130, 0.5, -50)
    mainFrame.Size = UDim2.new(0, 120, 0, 100)
    mainFrame.AnchorPoint = Vector2.new(0, 0.5)

    local uicorner = Instance.new('UICorner')
    uicorner.CornerRadius = UDim.new(0, 8)
    uicorner.Parent = mainFrame

    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Parent = mainFrame
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "GEN ESP"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.new(0, 0, 0)

    local diamondFrame = Instance.new('Frame')
    diamondFrame.Name = 'DiamondFrame'
    diamondFrame.Parent = mainFrame
    diamondFrame.BackgroundTransparency = 1
    diamondFrame.Size = UDim2.new(1, -20, 0, 25)
    diamondFrame.Position = UDim2.new(0, 10, 0, 35)

    local diamondIcon = Instance.new('ImageLabel')
    diamondIcon.Name = 'DiamondIcon'
    diamondIcon.Parent = diamondFrame
    diamondIcon.BackgroundTransparency = 1
    diamondIcon.Size = UDim2.new(0, 18, 0, 18)
    diamondIcon.Position = UDim2.new(0, 0, 0.5, -9)
    diamondIcon.Image = bedwars.getIcon({itemType = 'diamond'}, true)

    local diamondTimer = Instance.new('TextLabel')
    diamondTimer.Name = 'DiamondTimer'
    diamondTimer.Parent = diamondFrame
    diamondTimer.BackgroundTransparency = 1
    diamondTimer.Size = UDim2.new(1, -25, 1, 0)
    diamondTimer.Position = UDim2.new(0, 25, 0, 0)
    diamondTimer.Text = "00"
    diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
    diamondTimer.TextSize = 18
    diamondTimer.Font = Enum.Font.GothamBold
    diamondTimer.TextXAlignment = Enum.TextXAlignment.Left

    local emeraldFrame = Instance.new('Frame')
    emeraldFrame.Name = 'EmeraldFrame'
    emeraldFrame.Parent = mainFrame
    emeraldFrame.BackgroundTransparency = 1
    emeraldFrame.Size = UDim2.new(1, -20, 0, 25)
    emeraldFrame.Position = UDim2.new(0, 10, 0, 65)

    local emeraldIcon = Instance.new('ImageLabel')
    emeraldIcon.Name = 'EmeraldIcon'
    emeraldIcon.Parent = emeraldFrame
    emeraldIcon.BackgroundTransparency = 1
    emeraldIcon.Size = UDim2.new(0, 18, 0, 18)
    emeraldIcon.Position = UDim2.new(0, 0, 0.5, -9)
    emeraldIcon.Image = bedwars.getIcon({itemType = 'emerald'}, true)

    local emeraldTimer = Instance.new('TextLabel')
    emeraldTimer.Name = 'EmeraldTimer'
    emeraldTimer.Parent = emeraldFrame
    emeraldTimer.BackgroundTransparency = 1
    emeraldTimer.Size = UDim2.new(1, -25, 1, 0)
    emeraldTimer.Position = UDim2.new(0, 25, 0, 0)
    emeraldTimer.Text = "00"
    emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
    emeraldTimer.TextSize = 18
    emeraldTimer.Font = Enum.Font.GothamBold
    emeraldTimer.TextXAlignment = Enum.TextXAlignment.Left

    local diamondTimes = {}
    local emeraldTimes = {}

    local function getMyTeamId()
        local myTeam = lplr:GetAttribute('Team')
        if myTeam == nil then return nil end
        return tonumber(myTeam)
    end

    local function getGeneratorTeamId(generatorId)
        local teamNum = string.match(generatorId, "^(%d+)_generator")
        if teamNum then
            return tonumber(teamNum)
        end
        return nil
    end

    local function isTeamGenerator(generatorId)
        return string.match(generatorId, "^%d+_generator") ~= nil
    end

    local function getGeneratorType(generatorId)
        local idLower = string.lower(generatorId)

        if isTeamGenerator(generatorId) then
            return 'teamgen', {
                color = Color3.fromRGB(200, 200, 200),
                icon = 'iron',
                displayName = 'Team Gen',
                isTeamGen = true
            }
        end

        for genType, config in pairs(generatorTypes) do
            for _, keyword in ipairs(config.keywords) do
                if idLower:find(keyword) then
                    return genType, config
                end
            end
        end
        return nil, nil
    end

    local function isGeneratorEnabled(genType, teamId)
        if genType == 'diamond' then
            return DiamondToggle.Enabled
        elseif genType == 'emerald' then
            return EmeraldToggle.Enabled
        elseif genType == 'teamgen' then
            if not TeamGenToggle.Enabled then return false end
            local myTeamId = getMyTeamId()
            if not myTeamId or not teamId then return TeamGenToggle.Enabled end
            if teamId == myTeamId then
                return ShowOwnTeamGen.Enabled
            else
                return ShowEnemyTeamGen.Enabled
            end
        end
        return false
    end

    local function getProperIcon(iconType)
        local icon = bedwars.getIcon({itemType = iconType}, true)
        if not icon or icon == "" then return nil end
        return icon
    end

    local function getTierText(generatorAdornee)
        if not generatorAdornee then return nil end
        if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
        local reactTree = generatorAdornee:FindFirstChild('RoactTree')
        if not reactTree then return nil end
        local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
        if not teamApp then return nil end
        local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
        if globalGen then
            for _, child in pairs(globalGen:GetDescendants()) do
                if child:IsA('TextLabel') then
                    local text = child.Text
                    if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
                        return child
                    end
                end
            end
        end
        local teamGenMain = teamApp:FindFirstChild('TeamGenMain')
        if teamGenMain then
            for _, child in pairs(teamGenMain:GetDescendants()) do
                if child:IsA('TextLabel') then
                    local text = child.Text
                    if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
                        return child
                    end
                end
            end
        end
        return nil
    end

    local function extractTierLevel(tierText)
        if not tierText or tierText == "" then return "0" end
        if tierText == "0" then return "0" end
        local tierMatch = tierText:match("Tier%s+([IVX]+)")
        if tierMatch then return tierMatch end
        if tierText:match("^[IVX]+$") then return tierText end
        local numTier = tierText:match("Tier%s+(%d+)")
        if numTier then
            local num = tonumber(numTier)
            if num == 0 then return "0"
            elseif num == 1 then return "I"
            elseif num == 2 then return "II"
            elseif num == 3 then return "III"
            end
        end
        return "0"
    end

    local function getCountdownText(generatorAdornee)
        if not generatorAdornee then return nil end
        if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
        local reactTree = generatorAdornee:FindFirstChild('RoactTree')
        if not reactTree then return nil end
        local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
        if not teamApp then return nil end
        local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
        if not globalGen then return nil end
        local countdown = globalGen:FindFirstChild('Countdown')
        if not countdown then return nil end
        local textLabel = countdown:FindFirstChild('Text')
        if not textLabel then
            if countdown:IsA('TextLabel') then return countdown end
            return nil
        end
        return textLabel
    end

    local function extractSecondsFromText(text)
        if not text or text == "" then return 0 end
        local seconds = text:match("%[(%d+)%]")
        if seconds then return tonumber(seconds) or 0 end
        local justNumber = text:match("(%d+)")
        if justNumber then return tonumber(justNumber) or 0 end
        return 0
    end

    local function getResourceCount(position, resourceType)
        local count = 0
        for _, drop in pairs(CollectionService:GetTagged('ItemDrop')) do
            if drop:FindFirstChild('Handle') then
                local dropName = drop.Name:lower()
                if dropName:find(resourceType) then
                    local dist = (drop.Handle.Position - position).Magnitude
                    if dist <= 10 then
                        local amount = drop:GetAttribute('Amount') or 1
                        count = count + amount
                    end
                end
            end
        end
        return count
    end

    local function updateCompactUI()
        if not GeneratorESP.Enabled or UIStyle.Value ~= 'Compact' then
            compactUI.Enabled = false
            return
        end
        compactUI.Enabled = true
        local bestDiamondTime = math.huge
        local bestEmeraldTime = math.huge
        for generatorAdornee, ref in pairs(Reference) do
            if ref and not ref.isTeamGen and generatorAdornee and generatorAdornee.Parent then
                local countdownText = getCountdownText(generatorAdornee)
                if countdownText and countdownText.Text then
                    local timeLeft = extractSecondsFromText(countdownText.Text)
                    if ref.genType == 'diamond' and timeLeft > 0 and timeLeft < bestDiamondTime then
                        bestDiamondTime = timeLeft
                    elseif ref.genType == 'emerald' and timeLeft > 0 and timeLeft < bestEmeraldTime then
                        bestEmeraldTime = timeLeft
                    end
                end
            end
        end
        diamondTimes[1] = bestDiamondTime ~= math.huge and bestDiamondTime or 0
        emeraldTimes[1] = bestEmeraldTime ~= math.huge and bestEmeraldTime or 0
        if bestDiamondTime == math.huge then
            diamondTimer.Text = "00"
        else
            diamondTimer.Text = string.format("%02d", bestDiamondTime)
            if bestDiamondTime <= 5 then
                diamondTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
            elseif bestDiamondTime <= 10 then
                diamondTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
            end
        end
        if bestEmeraldTime == math.huge then
            emeraldTimer.Text = "00"
        else
            emeraldTimer.Text = string.format("%02d", bestEmeraldTime)
            if bestEmeraldTime <= 5 then
                emeraldTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
            elseif bestEmeraldTime <= 10 then
                emeraldTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
            end
        end
    end

    local function clearAllESP()
        Folder:ClearAllChildren()
        table.clear(Reference)
        compactUI.Enabled = false
    end

    local function createESP(generatorAdornee, genType, config, position, teamId)
        if not isGeneratorEnabled(genType, teamId) then return end
        if Reference[generatorAdornee] then return end

        if UIStyle.Value == 'Compact' then
            Reference[generatorAdornee] = {
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = config.isTeamGen
            }
            return
        end

        local displayColor = config.color
        local teamName = nil
        if config.isTeamGen and teamId and teamColors[teamId] then
            displayColor = teamColors[teamId].color
            teamName = teamColors[teamId].name
        end

        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'generator-esp-' .. genType
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = generatorAdornee

        if config.isTeamGen then
            billboard.Size = UDim2.fromOffset(180, 55)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
        else
            billboard.Size = UDim2.fromOffset(80, 30)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
        end

        local blur = addBlur(billboard)
        blur.Visible = true

        if config.isTeamGen and teamName then
            local dot = Instance.new('Frame')
            dot.Name = 'TeamDot'
            dot.Parent = billboard
            dot.Size = UDim2.fromOffset(8, 8)
            dot.Position = UDim2.new(0, 10, 0, 5)
            dot.BackgroundColor3 = displayColor
            dot.BorderSizePixel = 0
            local dotCorner = Instance.new('UICorner')
            dotCorner.CornerRadius = UDim.new(1, 0)
            dotCorner.Parent = dot

            local teamLabel = Instance.new('TextLabel')
            teamLabel.Name = 'TeamLabel'
            teamLabel.Parent = billboard
            teamLabel.BackgroundTransparency = 1
            teamLabel.Size = UDim2.new(1, 0, 0, 18)
            teamLabel.Position = UDim2.new(0, 0, 0, 0)
            teamLabel.Text = teamName
            teamLabel.TextColor3 = displayColor
            teamLabel.TextSize = 13
            teamLabel.Font = Enum.Font.GothamBold
            teamLabel.TextStrokeTransparency = 0.4
            teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            teamLabel.TextXAlignment = Enum.TextXAlignment.Center
        end

        local frame = Instance.new('Frame')
        frame.Size = config.isTeamGen and UDim2.new(1, 0, 0, 35) or UDim2.fromScale(1, 1)
        frame.Position = config.isTeamGen and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        if config.isTeamGen and teamId and teamColors[teamId] then
            local stripe = Instance.new('Frame')
            stripe.Name = 'TeamStripe'
            stripe.Parent = frame
            stripe.Size = UDim2.new(0, 3, 1, 0)
            stripe.Position = UDim2.new(0, 0, 0, 0)
            stripe.BackgroundColor3 = displayColor
            stripe.BorderSizePixel = 0
            local stripeCorner = Instance.new('UICorner')
            stripeCorner.CornerRadius = UDim.new(0, 3)
            stripeCorner.Parent = stripe
        end

        local uicorner2 = Instance.new('UICorner')
        uicorner2.CornerRadius = UDim.new(0, 6)
        uicorner2.Parent = frame

        if config.isTeamGen then
            local tierLabel = Instance.new('TextLabel')
            tierLabel.Name = 'Tier'
            tierLabel.Size = UDim2.new(0, 25, 1, 0)
            tierLabel.Position = UDim2.new(0, 8, 0, 0)
            tierLabel.BackgroundTransparency = 1
            tierLabel.Text = "0"
            tierLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            tierLabel.TextSize = 16
            tierLabel.Font = Enum.Font.GothamBold
            tierLabel.TextStrokeTransparency = 0.5
            tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            tierLabel.Parent = frame

            local resources = {
                {name = 'iron',    color = Color3.fromRGB(200, 200, 200), icon = 'iron',    xOffset = 35},
                {name = 'diamond', color = Color3.fromRGB(85, 200, 255),  icon = 'diamond', xOffset = 85},
                {name = 'emerald', color = Color3.fromRGB(0, 255, 100),   icon = 'emerald', xOffset = 135}
            }

            local resourceLabels = {}
            for _, resource in ipairs(resources) do
                local iconImage = getProperIcon(resource.icon)
                if iconImage then
                    local image = Instance.new('ImageLabel')
                    image.Size = UDim2.fromOffset(18, 18)
                    image.Position = UDim2.new(0, resource.xOffset, 0.5, 0)
                    image.AnchorPoint = Vector2.new(0, 0.5)
                    image.BackgroundTransparency = 1
                    image.Image = iconImage
                    image.Parent = frame
                end
                local countLabel = Instance.new('TextLabel')
                countLabel.Name = resource.name .. '_count'
                countLabel.Size = UDim2.new(0, 25, 1, 0)
                countLabel.Position = UDim2.new(0, resource.xOffset + 20, 0, 0)
                countLabel.BackgroundTransparency = 1
                countLabel.Text = "0"
                countLabel.TextColor3 = resource.color
                countLabel.TextSize = 16
                countLabel.Font = Enum.Font.GothamBold
                countLabel.TextStrokeTransparency = 0.5
                countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                countLabel.TextXAlignment = Enum.TextXAlignment.Left
                countLabel.Parent = frame
                resourceLabels[resource.name] = countLabel
            end

            Reference[generatorAdornee] = {
                billboard = billboard,
                tierLabel = tierLabel,
                ironLabel = resourceLabels.iron,
                diamondLabel = resourceLabels.diamond,
                emeraldLabel = resourceLabels.emerald,
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = true
            }
        else
            local iconImage = getProperIcon(config.icon)
            if iconImage then
                local image = Instance.new('ImageLabel')
                image.Size = UDim2.fromOffset(20, 20)
                image.Position = UDim2.new(0, 5, 0.5, 0)
                image.AnchorPoint = Vector2.new(0, 0.5)
                image.BackgroundTransparency = 1
                image.Image = iconImage
                image.Parent = frame
            end
            local timerLabel = Instance.new('TextLabel')
            timerLabel.Name = 'Timer'
            timerLabel.Size = UDim2.new(0, 30, 1, 0)
            timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
            timerLabel.AnchorPoint = Vector2.new(0.5, 0)
            timerLabel.BackgroundTransparency = 1
            timerLabel.Text = "00"
            timerLabel.TextColor3 = displayColor
            timerLabel.TextSize = 18
            timerLabel.Font = Enum.Font.GothamBold
            timerLabel.TextStrokeTransparency = 0.5
            timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            timerLabel.Parent = frame
            local amountLabel = Instance.new('TextLabel')
            amountLabel.Name = 'Amount'
            amountLabel.Size = UDim2.new(0, 20, 1, 0)
            amountLabel.Position = UDim2.new(1, -20, 0, 0)
            amountLabel.BackgroundTransparency = 1
            amountLabel.Text = "0"
            amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            amountLabel.TextSize = 16
            amountLabel.Font = Enum.Font.GothamBold
            amountLabel.TextStrokeTransparency = 0.5
            amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            amountLabel.Parent = frame
            Reference[generatorAdornee] = {
                billboard = billboard,
                timerLabel = timerLabel,
                amountLabel = amountLabel,
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = false
            }
        end
    end

    local function updateESP(generatorAdornee)
        local ref = Reference[generatorAdornee]
        if not ref then return end
        if UIStyle.Value == 'Compact' then return end

        if ref.isTeamGen then
            if ref.tierLabel then
                local tierTextLabel = getTierText(generatorAdornee)
                if tierTextLabel and tierTextLabel.Text then
                    ref.tierLabel.Text = extractTierLevel(tierTextLabel.Text)
                else
                    ref.tierLabel.Text = "0"
                end
            end
            if ref.ironLabel then
                ref.ironLabel.Text = tostring(getResourceCount(ref.position, 'iron'))
            end
            if ref.diamondLabel then
                ref.diamondLabel.Text = tostring(getResourceCount(ref.position, 'diamond'))
            end
            if ref.emeraldLabel then
                ref.emeraldLabel.Text = tostring(getResourceCount(ref.position, 'emerald'))
            end
        else
            local countdownText = getCountdownText(generatorAdornee)
            if countdownText and countdownText.Text then
                local timeLeft = extractSecondsFromText(countdownText.Text)
                if ref.timerLabel then
                    ref.timerLabel.Text = string.format("%02d", timeLeft)
                    if timeLeft <= 5 then
                        ref.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                    elseif timeLeft <= 10 then
                        ref.timerLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                    else
                        ref.timerLabel.TextColor3 = generatorTypes[ref.genType].color
                    end
                end
            else
                if ref.timerLabel then
                    ref.timerLabel.Text = "00"
                    ref.timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
            end
            if ref.amountLabel then
                ref.amountLabel.Text = tostring(getResourceCount(ref.position, ref.genType))
            end
        end
    end

    local function processGeneratorAdornee(obj)
        if obj.Name ~= 'GeneratorAdornee' then return end
        local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
        if not ok then return end
        if generatorId == nil then return end
        if type(generatorId) ~= 'string' then return end
        if generatorId == '' then return end

        local position = obj:GetPivot().Position
        local genType, config = getGeneratorType(generatorId)
        if not genType or not config then return end

        local teamId = getGeneratorTeamId(generatorId)
        if isGeneratorEnabled(genType, teamId) then
            createESP(obj, genType, config, position, teamId)
        end
    end

    local function findAllGenerators()
        for _, obj in pairs(workspace:GetDescendants()) do
            pcall(processGeneratorAdornee, obj)
        end
    end

    local function refreshESP()
        clearAllESP()
        if GeneratorESP.Enabled then
            findAllGenerators()
        end
    end

    local updateTimer = 0

    GeneratorESP = vape.Categories.Render:CreateModule({
        Name = 'GeneratorESP',
        Function = function(callback)
            if callback then
                findAllGenerators()

                GeneratorESP:Clean(workspace.DescendantAdded:Connect(function(obj)
                    if not GeneratorESP.Enabled then return end
                    task.wait(0.2)
                    pcall(processGeneratorAdornee, obj)
                end))

                GeneratorESP:Clean(RunService.Heartbeat:Connect(function(dt)
                    if not GeneratorESP.Enabled then return end
                    updateTimer = updateTimer + dt
                    if updateTimer < 0.2 then return end
                    updateTimer = 0
                    for generatorAdornee, ref in pairs(Reference) do
                        if generatorAdornee and generatorAdornee.Parent then
                            updateESP(generatorAdornee)
                        else
                            if ref.billboard then ref.billboard:Destroy() end
                            Reference[generatorAdornee] = nil
                        end
                    end
                    updateCompactUI()
                end))

                GeneratorESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
                    if not GeneratorESP.Enabled then return end
                    if Reference[obj] then
                        if Reference[obj].billboard then Reference[obj].billboard:Destroy() end
                        Reference[obj] = nil
                    end
                end))
            else
                clearAllESP()
            end
        end,
        Tooltip = 'ESP for generators showing timer and item counts'
    })

    UIStyle = GeneratorESP:CreateDropdown({
        Name = 'UI Style',
        List = {'Original', 'Compact'},
        Default = 'Original',
        Function = function() refreshESP() end,
        Tooltip = 'Choose between original billboard ESP or compact side UI'
    })

    DiamondToggle = GeneratorESP:CreateToggle({
        Name = 'Diamond',
        Function = function() refreshESP() end,
        Default = true
    })

    EmeraldToggle = GeneratorESP:CreateToggle({
        Name = 'Emerald',
        Function = function() refreshESP() end,
        Default = true
    })

    TeamGenToggle = GeneratorESP:CreateToggle({
        Name = 'Team Generators',
        Function = function(callback)
            if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = callback end
            if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = callback end
            refreshESP()
        end,
        Default = true
    })

    ShowOwnTeamGen = GeneratorESP:CreateToggle({
        Name = 'Show Own Team',
        Function = function() refreshESP() end,
        Default = false,
        Visible = true
    })

    ShowEnemyTeamGen = GeneratorESP:CreateToggle({
        Name = 'Show Enemy Teams',
        Function = function() refreshESP() end,
        Default = true,
        Visible = true
    })
end)

run(function()
    local Gingerbread
    local LimitToItem
    local BreakDelay
    local BreakDelaySlider
    local AutoSwitch
    local SwitchMode
    
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local lastBreakTime = 0
    local lastPlaceTime = 0
    local placeCheckConnection
    local justPlacedGumdrop = false
    local lastPlacedPosition = nil
    
    _G.gingerLock = _G.gingerLock or false
    
    local function getPickaxeSlot()
        for i, v in store.inventory.hotbar do
            if v.item and bedwars.ItemMeta[v.item.itemType] then
                local meta = bedwars.ItemMeta[v.item.itemType]
                if meta.breakBlock then
                    return i - 1
                end
            end
        end
        return nil
    end
    
    local function getGumdropSlot()
        for i, v in store.inventory.hotbar do
            if v.item and v.item.itemType == "gumdrop_bounce_pad" then
                return i - 1
            end
        end
        return nil
    end
    
    local function getPredictedPosition()
        if not (lplr.Character and lplr.Character.PrimaryPart) then return nil end
        local root = lplr.Character.PrimaryPart
        local velocity = root.AssemblyLinearVelocity
        local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        local speed = horizontalVelocity.Magnitude
        if speed < 1 then return root.Position end
        local predictionTime = math.clamp(speed / 40, 0.15, 0.35)
        return root.Position + (horizontalVelocity * predictionTime)
    end
    
    local function tryPlaceGumdrop()
        if not AutoSwitch.Enabled or _G.gingerLock then return end
        if not (lplr.Character and lplr.Character.PrimaryPart) then return end
        
        local inFirstPerson = isFirstPerson()
        if SwitchMode.Value == 'First Person' and not inFirstPerson then return end
        if SwitchMode.Value == 'Third Person' and inFirstPerson then return end
        
        local velocity = lplr.Character.PrimaryPart.AssemblyLinearVelocity.Y
        if velocity >= -5 then return end
        
        local gumdropSlot = getGumdropSlot()
        if not gumdropSlot then return end
        
        local root = lplr.Character.PrimaryPart
        local targetPos = getPredictedPosition() or root.Position
        local checkPos = targetPos - Vector3.new(0, 3, 0)
        local groundBlockPos = nil
        
        for i = 1, 16 do
            local testPos = checkPos - Vector3.new(0, 3 * (i - 1), 0)
            local block, blockpos = getPlacedBlock(roundPos(testPos))
            if block then
                groundBlockPos = blockpos * 3
                break
            end
        end
        
        if not groundBlockPos then return end
        
        local distanceToGround = root.Position.Y - groundBlockPos.Y
        if distanceToGround < 9 or distanceToGround > 18 then return end
        
        local placePos = groundBlockPos + Vector3.new(0, 3, 0)
        if lastPlacedPosition and (lastPlacedPosition - placePos).Magnitude < 1 then return end
        if getPlacedBlock(placePos) then return end
        
        _G.gingerLock = true
        
        if hotbarSwitch(gumdropSlot) then
            task.wait(0.03)
            local success = pcall(function()
                bedwars.placeBlock(placePos, "gumdrop_bounce_pad", false)
            end)
            
            if success then
                lastPlaceTime = tick()
                justPlacedGumdrop = true
                lastPlacedPosition = placePos
                
                task.wait(0.03)
                local pickaxeSlot = getPickaxeSlot()
                if pickaxeSlot then
                    hotbarSwitch(pickaxeSlot)
                    task.wait(0.08)
                    local placedBlock = getPlacedBlock(placePos)
                    if placedBlock and placedBlock.Name == "gumdrop_bounce_pad" then
                        task.spawn(bedwars.breakBlock, placedBlock, false, nil, true)
                        lastBreakTime = tick()
                    end
                end
            end
        end
        
        _G.gingerLock = false
    end
    
    Gingerbread = vape.Categories.Kits:CreateModule({
        Name = 'AutoGinger',
        Function = function(callback)
            if callback then
                local old = bedwars.LaunchPadController.attemptLaunch
                bedwars.LaunchPadController.attemptLaunch = function(...)
                    local res = {old(...)}
                    local self, block = ...
                    
                    if block:GetAttribute('PlacedByUserId') == lplr.UserId and
                       (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then

                        if LimitToItem.Enabled and not isHoldingPickaxe() then
                            return unpack(res)
                        end

                        local shouldAutoSwitch = AutoSwitch.Enabled and not isHoldingPickaxe() and cameraAllowed and not _G.gingerLock

                        if shouldAutoSwitch then
                            local pickaxeSlot = getPickaxeSlot()
                            if pickaxeSlot then
                                _G.gingerLock = true
                                task.spawn(function()
                                    if hotbarSwitch(pickaxeSlot) then
                                        task.wait(0.03)
                                        task.spawn(bedwars.breakBlock, block, false, nil, true)
                                        task.spawn(bedwars.breakBlock, block, false, nil, true)
                                        lastBreakTime = tick()
                                        justPlacedGumdrop = false
                                    end
                                    _G.gingerLock = false
                                end)
                            end
                        else
                            local currentTime = tick()
                            local shouldBreak = true
                            if not AutoSwitch.Enabled and BreakDelay.Enabled and not justPlacedGumdrop then
                                if (currentTime - lastBreakTime) < BreakDelaySlider.Value then
                                    shouldBreak = false
                                end
                            end
                            if shouldBreak then
                                task.spawn(bedwars.breakBlock, block, false, nil, true)
                                task.spawn(bedwars.breakBlock, block, false, nil, true)
                                lastBreakTime = currentTime
                                justPlacedGumdrop = false
                            end
                        end

                        local cameraAllowed = true
                        if AutoSwitch.Enabled then
                            local inFirstPerson = isFirstPerson()
                            if SwitchMode.Value == 'First Person' and not inFirstPerson then
                                cameraAllowed = false
                            elseif SwitchMode.Value == 'Third Person' and inFirstPerson then
                                cameraAllowed = false
                            end
                        end

                        if isHoldingPickaxe() then
                            local currentTime = tick()
                            local shouldBreak = true
                            
                            if not AutoSwitch.Enabled and BreakDelay.Enabled and not justPlacedGumdrop then
                                if (currentTime - lastBreakTime) < BreakDelaySlider.Value then
                                    shouldBreak = false
                                end
                            end
                            
                            if shouldBreak then
                                task.spawn(bedwars.breakBlock, block, false, nil, true)
                                task.spawn(bedwars.breakBlock, block, false, nil, true)
                                lastBreakTime = currentTime
                                justPlacedGumdrop = false
                            end
                        elseif AutoSwitch.Enabled and cameraAllowed and not _G.gingerLock then
                            local pickaxeSlot = getPickaxeSlot()
                            if pickaxeSlot then
                                _G.gingerLock = true
                                task.spawn(function()
                                    if hotbarSwitch(pickaxeSlot) then
                                        task.wait(0.03)
                                        task.spawn(bedwars.breakBlock, block, false, nil, true)
                                        task.spawn(bedwars.breakBlock, block, false, nil, true)
                                        lastBreakTime = tick()
                                        justPlacedGumdrop = false
                                    end
                                    _G.gingerLock = false
                                end)
                            end
                        end
                    end
                    
                    return unpack(res)
                end
                
				if AutoSwitch.Enabled then
                    if placeCheckConnection then
                        placeCheckConnection:Disconnect()
                        placeCheckConnection = nil
                    end
                    placeCheckConnection = runService.RenderStepped:Connect(function()
                        if not _G.gingerLock and entitylib.isAlive and tick() - lastPlaceTime > 0.15 then
                            tryPlaceGumdrop()
                        end
                    end)
                end
                
                Gingerbread:Clean(function()
                    bedwars.LaunchPadController.attemptLaunch = old
                    if placeCheckConnection then
                        placeCheckConnection:Disconnect()
                        placeCheckConnection = nil
                    end
                end)
            else
                lastBreakTime = 0
                lastPlaceTime = 0
                justPlacedGumdrop = false
                lastPlacedPosition = nil
                _G.gingerLock = false
                if placeCheckConnection then
                    placeCheckConnection:Disconnect()
                    placeCheckConnection = nil
                end
            end
        end,
        Tooltip = 'Advanced gumdrop loop with movement prediction'
    })

    LimitToItem = Gingerbread:CreateToggle({
        Name = 'Limit to Pickaxe',
        Default = true,
        Tooltip = 'only breaks gumdrop when holding a pickaxe'
    })
    
    BreakDelay = Gingerbread:CreateToggle({
        Name = 'Break Delay',
        Default = false,
        Function = function(callback)
            if BreakDelaySlider and BreakDelaySlider.Object then
                BreakDelaySlider.Object.Visible = callback and not AutoSwitch.Enabled
            end
        end,
        Tooltip = 'Add delay before breaking gumdrops'
    })
    
    BreakDelaySlider = Gingerbread:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Visible = false,
        Tooltip = 'Delay in seconds before breaking'
    })
    
	AutoSwitch = Gingerbread:CreateToggle({
        Name = 'Auto-Switch',
        Default = false,
        Function = function(callback)
            if SwitchMode and SwitchMode.Object then SwitchMode.Object.Visible = callback end
            if BreakDelay and BreakDelay.Object then BreakDelay.Object.Visible = not callback end
            if BreakDelaySlider and BreakDelaySlider.Object then
                BreakDelaySlider.Object.Visible = (not callback) and BreakDelay.Enabled
            end
            if LimitToItem and LimitToItem.Object then LimitToItem.Object.Visible = not callback end

            if placeCheckConnection then
                placeCheckConnection:Disconnect()
                placeCheckConnection = nil
            end

            if callback and Gingerbread.Enabled then
                placeCheckConnection = runService.RenderStepped:Connect(function()
                    if not _G.gingerLock and entitylib.isAlive and tick() - lastPlaceTime > 0.15 then
                        tryPlaceGumdrop()
                    end
                end)
            end
        end,
        Tooltip = 'Auto-switch, break, and place with smart movement prediction'
    })
    
    SwitchMode = Gingerbread:CreateDropdown({
        Name = 'Camera Mode',
        List = {'Both', 'First Person', 'Third Person'},
        Default = 'Both',
        Visible = false,
        Tooltip = 'Which camera mode to work in'
    })
end)

run(function()
    local Beekeeper
    local CollectionToggle
	local LimitToNet
	local maxBeehiveLevel = 10
    local maxedBeehives = {}
    local maxedNotificationSent = {}
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local BeesESP
    local BeesNotify
    local BeesBackground
    local BeesColor
    local BeehiveESP
    local ShowOtherBeehives
    local BeehiveBackground
    local BeehiveColor
    local AutoDeposit
    local DepositDelay
    local DepositDelaySlider
    local DepositRange
    local ESPLimitToNet  
    local collectionRunning = false
    local depositRunning = false
    local BeesFolder = Instance.new('Folder')
    BeesFolder.Parent = vape.gui
    local BeehiveFolder = Instance.new('Folder')
    BeehiveFolder.Parent = vape.gui
    local BeesReference = {}
    local BeehiveReference = {}
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1

    local function sendNotification(count)
        notif("Bee ESP", string.format("%d bees spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function getBeeIcon()
        return bedwars.getIcon({itemType = 'bee'}, true)
    end

    local function AddedBee(v)
        if BeesReference[v] then return end
        local model = v.Parent
        if model then
            if model.Name:find("TamedBee") or model:FindFirstChild("TamedBee") then
                return 
            end
            
            if model:GetAttribute("IsTamed") or model:GetAttribute("Tamed") then
                return 
            end
            
            for _, tag in pairs(collectionService:GetTags(model)) do
                if tag:lower():find("tamed") then
                    return 
                end
            end
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeesFolder
        billboard.Name = 'bee'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = BeesBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(BeesColor.Hue, BeesColor.Sat, BeesColor.Value)
        image.BackgroundTransparency = 1 - (BeesBackground.Enabled and BeesColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getBeeIcon()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        BeesReference[v] = billboard
        
        if BeesNotify.Enabled then
            table.insert(spawnQueue, {item = 'bee', time = tick()})
            processSpawnQueue()
        end
    end

    local function RemovedBee(v)
        if BeesReference[v] then
            BeesReference[v]:Destroy()
            BeesReference[v] = nil
        end
    end

    local function isMyBeehive(beehive)
        if not beehive then return false end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        return placedBy and placedBy == lplr.UserId
    end
    
    local function getBeehiveOwnerName(beehive)
        if not beehive then return "Unknown" end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        if not placedBy then return "Unknown" end
        
        local player = game.Players:GetPlayerByUserId(placedBy)
        if player then
            return player.Name
        end
        
        return "Player"
    end

    local function AddedBeehive(beehive)
        local isOwn = isMyBeehive(beehive)
        
        if not isOwn and not (ShowOtherBeehives and ShowOtherBeehives.Enabled) then 
            return 
        end
        
        if BeehiveReference[beehive] then return end
        
        local level = beehive:GetAttribute("Level") or 0
        local isMaxed = level >= maxBeehiveLevel and isOwn
        
        if isMaxed and isOwn then
            maxedBeehives[beehive] = true
        end
        
        local ownerName = isOwn and nil or getBeehiveOwnerName(beehive)
        local hasOwnerName = ownerName ~= nil
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeehiveFolder
        billboard.Name = 'beehive-esp'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
        billboard.Size = isMaxed and UDim2.fromOffset(90, 40) or (hasOwnerName and UDim2.fromOffset(120, 40) or UDim2.fromOffset(80, 30))
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = beehive
        
        local blur = addBlur(billboard)
        blur.Visible = BeehiveBackground.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = isMaxed and Color3.fromRGB(255, 50, 50) or Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and (isMaxed and 0.5 or BeehiveColor.Opacity) or 0)
        frame.BorderSizePixel = 0
        frame.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 6)
        uicorner.Parent = frame
        
        if hasOwnerName then
            local nameLabel = Instance.new('TextLabel')
            nameLabel.Name = 'OwnerName'
            nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, -20)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = ownerName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextStrokeTransparency = 0.5
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = billboard
        end
        
        local homeImage = Instance.new('TextLabel')
        homeImage.Size = UDim2.fromOffset(20, 20)
        homeImage.Position = UDim2.new(0, 5, 0.5, 0)
        homeImage.AnchorPoint = Vector2.new(0, 0.5)
        homeImage.BackgroundTransparency = 1
        homeImage.Text = isOwn and "🏠" or "🏘️"
        homeImage.TextSize = 16
        homeImage.Parent = frame
        
        local beeImage = Instance.new('ImageLabel')
        beeImage.Size = UDim2.fromOffset(18, 18)
        beeImage.Position = UDim2.new(0.5, -5, 0.5, 0)
        beeImage.AnchorPoint = Vector2.new(0, 0.5)
        beeImage.BackgroundTransparency = 1
        beeImage.Image = getBeeIcon()
        beeImage.Parent = frame
        
        local levelLabel = Instance.new('TextLabel')
        levelLabel.Name = 'Level'
        levelLabel.Size = UDim2.new(0, 25, 1, 0)
        levelLabel.Position = UDim2.new(1, -30, 0, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = tostring(level)
        levelLabel.TextColor3 = isMaxed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 255, 255)
        levelLabel.TextSize = 16
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.TextStrokeTransparency = 0.5
        levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        levelLabel.Parent = frame
        
        if isMaxed and isOwn then
            local maxText = Instance.new('TextLabel')
            maxText.Name = 'MaxText'
            maxText.Size = UDim2.new(1, 0, 0.4, 0)
            maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
            maxText.BackgroundTransparency = 1
            maxText.Text = "MAX"
            maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
            maxText.TextSize = 12
            maxText.Font = Enum.Font.GothamBold
            maxText.TextStrokeTransparency = 0.5
            maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
            maxText.Parent = billboard
        end
        
        BeehiveReference[beehive] = {
            billboard = billboard,
            levelLabel = levelLabel,
            beehive = beehive,
            isMaxed = isMaxed,
            isOwn = isOwn
        }
        
        local function updateLevel()
            local level = beehive:GetAttribute("Level") or 0
            local isMaxed = level >= maxBeehiveLevel and isOwn
            
            if isMaxed and isOwn then
                maxedBeehives[beehive] = true
                
                if not maxedNotificationSent[beehive] then
                    notif("Bee Keeper", "Beehive is full (MAX)", 3)
                    maxedNotificationSent[beehive] = true
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if not maxText then
                        maxText = Instance.new('TextLabel')
                        maxText.Name = 'MaxText'
                        maxText.Size = UDim2.new(1, 0, 0.4, 0)
                        maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
                        maxText.BackgroundTransparency = 1
                        maxText.Text = "MAX"
                        maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
                        maxText.TextSize = 12
                        maxText.Font = Enum.Font.GothamBold
                        maxText.TextStrokeTransparency = 0.5
                        maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
                        maxText.Parent = BeehiveReference[beehive].billboard
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and 0.5 or 0)
                    end
                end
            else
                if isOwn then
                    maxedBeehives[beehive] = nil
                    maxedNotificationSent[beehive] = nil
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if maxText then
                        maxText:Destroy()
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and BeehiveColor.Opacity or 0)
                    end
                end
            end
            
            if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                BeehiveReference[beehive].levelLabel.Text = tostring(level)
            end
            
            if BeehiveReference[beehive] then
                BeehiveReference[beehive].isMaxed = isMaxed
            end
        end
        
        updateLevel()
        
        if isOwn then
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(updateLevel))
        else
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(function()
                local level = beehive:GetAttribute("Level") or 0
                if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                    BeehiveReference[beehive].levelLabel.Text = tostring(level)
                end
            end))
        end
    end


    local function RemovedBeehive(beehive)
        if BeehiveReference[beehive] then
            BeehiveReference[beehive].billboard:Destroy()
            BeehiveReference[beehive] = nil
        end
    end

    local function setupBeesESP()
        for _, v in collectionService:GetTagged('bee') do
            if v:IsA("Model") and v.PrimaryPart then
                if not v.Name:find("TamedBee") and not v:FindFirstChild("TamedBee") then
                    AddedBee(v.PrimaryPart)
                end
            end
        end

        Beekeeper:Clean(collectionService:GetInstanceAddedSignal('bee'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                task.wait(0.1)
                if not v.Name:find("TamedBee") and not v:FindFirstChild("TamedBee") then
                    AddedBee(v.PrimaryPart)
                end
            end
        end))

        Beekeeper:Clean(collectionService:GetInstanceRemovedSignal('bee'):Connect(function(v)
            if v.PrimaryPart then
                RemovedBee(v.PrimaryPart)
            end
        end))
        

    end

    local function setupBeehiveESP()
        for _, beehive in collectionService:GetTagged('beehive') do
            AddedBeehive(beehive)
        end

        Beekeeper:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(function(beehive)
            task.wait(0.1)
            AddedBeehive(beehive)
        end))

        Beekeeper:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(function(beehive)
            RemovedBeehive(beehive)
        end))
    end

    local function isHoldingBeeNet()
        if not store.hand or not store.hand.tool then return false end
        return store.hand.tool.Name == 'bee_net' or store.hand.tool.Name == 'bee-net'
    end

    local function startCollection()
        collectionRunning = true
        task.spawn(function()
            while collectionRunning and Beekeeper.Enabled and CollectionToggle.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                if LimitToNet.Enabled and not isHoldingBeeNet() then
                    task.wait(0.5)
                    continue
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local beesFound = false
                
                for _, v in collectionService:GetTagged('bee') do
                    if not collectionRunning or not Beekeeper.Enabled or not CollectionToggle.Enabled then 
                        break 
                    end
                    
                    if LimitToNet.Enabled and not isHoldingBeeNet() then
                        break
                    end
                    
                    if v:IsA("Model") and v.PrimaryPart then
                        local beePos = v.PrimaryPart.Position
                        local distance = (localPosition - beePos).Magnitude
                        
                        if distance <= range then
                            beesFound = true
                            
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if LimitToNet.Enabled and not isHoldingBeeNet() then
                                break
                            end
                            
                            local beeId = v:GetAttribute('BeeId')
                            if beeId then
                                bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = beeId})
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if not beesFound then
                    task.wait(0.2)
                else
                    task.wait(0.1)
                end
            end
            collectionRunning = false
        end)
    end

    local function startDeposit()
        depositRunning = true
        task.spawn(function()
            while depositRunning and Beekeeper.Enabled and AutoDeposit.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                local currentTool = store.hand and store.hand.tool
                if not currentTool or currentTool.Name ~= 'bee' then
                    task.wait(0.1)
                    continue
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = DepositRange.Value
                local depositedThisCycle = false
                
                local availableBeehives = {}
                for _, beehive in collectionService:GetTagged('beehive') do
                    if isMyBeehive(beehive) and not maxedBeehives[beehive] then
                        local beehivePos = beehive.Position
                        local distance = (localPosition - beehivePos).Magnitude
                        
                        if distance <= range then
                            table.insert(availableBeehives, {
                                beehive = beehive,
                                distance = distance
                            })
                        end
                    end
                end
                
                table.sort(availableBeehives, function(a, b)
                    return a.distance < b.distance
                end)
                
                for _, beehiveData in ipairs(availableBeehives) do
                    if not depositRunning or not Beekeeper.Enabled or not AutoDeposit.Enabled then 
                        break 
                    end
                    local beehive = beehiveData.beehive
                    if maxedBeehives[beehive] then
                        continue
                    end
                    
                    local prompt = beehive:FindFirstChildOfClass("ProximityPrompt")
                    
                    if prompt and prompt.Enabled then
                        if DepositDelay.Enabled and DepositDelaySlider.Value > 0 then
                            local originalDuration = prompt.HoldDuration
                            prompt.HoldDuration = DepositDelaySlider.Value
                            
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                task.wait(DepositDelaySlider.Value)
                                prompt:InputHoldEnd()
                            end
                            
                            task.wait(DepositDelaySlider.Value + 0.1)
                            prompt.HoldDuration = originalDuration
                        else
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                prompt:InputHoldEnd()
                            end
                            task.wait(0.1)
                        end
                        
                        depositedThisCycle = true
                        break 
                    end
                end
                
                if not depositedThisCycle and #availableBeehives > 0 then
                    local allMaxed = true
                    for _, beehiveData in ipairs(availableBeehives) do
                        if not maxedBeehives[beehiveData.beehive] then
                            allMaxed = false
                            break
                        end
                    end
                    
                    if allMaxed then
                        notif("Bee Keeper", "All nearby beehives are full", 3)
                    end
                end
                
                task.wait(depositedThisCycle and 0.3 or 0.2)
            end
            depositRunning = false
        end)
    end

    Beekeeper = vape.Categories.Kits:CreateModule({
        Name = 'AutoBeekeeper',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then
                    if BeesESP.Enabled then
                        setupBeesESP()
                    end
                    if BeehiveESP.Enabled then
                        setupBeehiveESP()
                    end
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
                
                if AutoDeposit.Enabled then
                    startDeposit()
                end
                
                Beekeeper:Clean(runService.RenderStepped:Connect(function()
                    if not ESPToggle.Enabled then return end
                    
                    for v, billboard in pairs(BeesReference) do
                        if not v or not v.Parent then
                            RemovedBee(v)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        billboard.Enabled = shouldShow
                    end
                    
                    for beehive, ref in pairs(BeehiveReference) do
                        if not beehive or not beehive.Parent then
                            RemovedBeehive(beehive)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        if ref.billboard then
                            ref.billboard.Enabled = shouldShow
                        end
                    end
                end))
            else
                collectionRunning = false
                depositRunning = false
                BeesFolder:ClearAllChildren()
                BeehiveFolder:ClearAllChildren()
                table.clear(BeesReference)
                table.clear(BeehiveReference)
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
        Tooltip = 'Automatically collects bees and manages beehives'
    })
    
    CollectionToggle = Beekeeper:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'Automatically collect bees',
        Function = function(callback)
            if LimitToNet and LimitToNet.Object then LimitToNet.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
            if callback and Beekeeper.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    LimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
        Tooltip = 'Only collect bees when holding bee net'
    })
    
    CollectionDelay = Beekeeper:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'Add delay before collecting bees',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Beekeeper:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before collecting'
    })
    
    RangeSlider = Beekeeper:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 30,
        Default = 18,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Control distance you want to collect bees'
    })
    
    ESPToggle = Beekeeper:CreateToggle({
        Name = 'ESP',
        Default = true,
        Tooltip = 'ESP for bees and beehives',
		Function = function(callback)
			if BeesESP and BeesESP.Object then BeesESP.Object.Visible = callback end
			if BeehiveESP and BeehiveESP.Object then BeehiveESP.Object.Visible = callback end
			if ESPLimitToNet and ESPLimitToNet.Object then ESPLimitToNet.Object.Visible = callback end

			if not callback then
				if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
				if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
				if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
				if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
				if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
				if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
			else
				if BeesESP and BeesESP.Enabled then
					if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = true end
					if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = true end
					if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
				end
				if BeehiveESP and BeehiveESP.Enabled then
					if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = true end
					if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = true end
					if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
				end
			end

			if Beekeeper.Enabled then
				if callback then
					if BeesESP.Enabled then setupBeesESP() end
					if BeehiveESP.Enabled then setupBeehiveESP() end
				else
					BeesFolder:ClearAllChildren()
					BeehiveFolder:ClearAllChildren()
					table.clear(BeesReference)
					table.clear(BeehiveReference)
				end
			end
		end
    })
    
    ESPLimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
        Tooltip = 'Only show ESP when holding bee net'
    })
    
    BeesESP = Beekeeper:CreateToggle({
        Name = 'Bees',
        Default = false,
        Tooltip = 'Show bee locations',
        Function = function(callback)
            if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = callback end
            if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = callback end
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeesESP() else
                    BeesFolder:ClearAllChildren()
                    table.clear(BeesReference)
                end
            end
        end
    })
    
    BeesNotify = Beekeeper:CreateToggle({
        Name = 'Notify',
        Default = false,
        Tooltip = 'Get notifications when bees spawn'
    })
    
    BeesBackground = Beekeeper:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            for _, v in BeesReference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and BeesColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
	BeesColor = Beekeeper:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in BeesReference do
				if v and v:FindFirstChild("ImageLabel") then
					v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.ImageLabel.BackgroundTransparency = 1 - opacity
				end
			end
		end,
		Darker = true
	})
    
    BeehiveESP = Beekeeper:CreateToggle({
        Name = 'Beehives',
        Default = false,
        Tooltip = 'Show your beehive locations with bee count',
        Function = function(callback)
            if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = callback end
            if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = callback end
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeehiveESP() else
                    BeehiveFolder:ClearAllChildren()
                    table.clear(BeehiveReference)
                end
            end
        end
    })
    
    ShowOtherBeehives = Beekeeper:CreateToggle({
        Name = 'Show Others',
        Default = false,
        Tooltip = 'Show other players\' beehives with their usernames',
        Function = function(callback)
            if Beekeeper.Enabled and ESPToggle.Enabled and BeehiveESP.Enabled then
                BeehiveFolder:ClearAllChildren()
                table.clear(BeehiveReference)
                setupBeehiveESP()
            end
        end
    })
    
    BeehiveBackground = Beekeeper:CreateToggle({
        Name = 'Beehive Background',
        Default = true,
        Function = function(callback)
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame then
                        if ref.isMaxed and ref.isOwn then
                            frame.BackgroundTransparency = 1 - (callback and 0.5 or 0)
                        else
                            frame.BackgroundTransparency = 1 - (callback and BeehiveColor.Opacity or 0)
                        end
                    end
                    if ref.billboard:FindFirstChild("Blur") then
                        ref.billboard.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    BeehiveColor = Beekeeper:CreateColorSlider({
        Name = 'Beehive Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame and not (ref.isMaxed and ref.isOwn) then
                        frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        frame.BackgroundTransparency = 1 - opacity
                    end
                end
            end
        end,
        Darker = true
    })
    
    AutoDeposit = Beekeeper:CreateToggle({
        Name = 'Auto Deposit',
        Default = false,
        Tooltip = 'Automatically deposit bees into your beehives',
		Function = function(callback)
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = callback end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = (callback and DepositDelay.Enabled) end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = callback end
			
			if not callback then
				if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			end

			if callback and Beekeeper.Enabled then
				startDeposit()
			else
				depositRunning = false
			end
		end
    })
    
    DepositDelay = Beekeeper:CreateToggle({
        Name = 'Deposit Delay',
        Default = false,
        Tooltip = 'Add delay before depositing bees',
        Function = function(callback)
            if DepositDelaySlider and DepositDelaySlider.Object then
                DepositDelaySlider.Object.Visible = callback
            end
        end
    })
    
    DepositDelaySlider = Beekeeper:CreateSlider({
        Name = 'Deposit Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before depositing'
    })
    
    DepositRange = Beekeeper:CreateSlider({
        Name = 'Deposit Range',
        Min = 1,
        Max = 15,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Range to deposit bees into beehives'
    })
	task.defer(function()
		if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = CollectionDelay.Enabled end
		if not ESPToggle.Enabled or not BeesESP.Enabled then
			if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
			if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
		else
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
		end

		if not ESPToggle.Enabled or not BeehiveESP.Enabled then
			if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
			if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
		else
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
		end

		if AutoDeposit and not AutoDeposit.Enabled then
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = false end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = false end
		end

		if DepositDelaySlider and DepositDelaySlider.Object then
			DepositDelaySlider.Object.Visible = (AutoDeposit.Enabled and DepositDelay.Enabled)
		end
	end)
end)

run(function()
    local AutoNoelle
    local HealSlimeToggle
    local HealSlimeDropdown
    local HealSlimeRefresh
    local VoidSlimeToggle
    local VoidSlimeDropdown
    local VoidSlimeRefresh
    local StickySlimeToggle
    local StickySlimeDropdown
    local StickySlimeRefresh
    local FrostySlimeToggle
    local FrostySlimeDropdown
    local FrostySlimeRefresh
    
    local running = false
    local slimeCheckThread = nil
    
    local SLIME_TYPES = {
        HEALING = 0,
        VOID = 1,
        STICKY = 2,
        FROSTY = 3
    }
    
    local SLIME_NAMES = {
        [SLIME_TYPES.HEALING] = "Blessed Slime",
        [SLIME_TYPES.VOID] = "Void Slime",
        [SLIME_TYPES.STICKY] = "Sticky Slime",
        [SLIME_TYPES.FROSTY] = "Frosty Slime"
    }
    
    local function getMySlimes()
        local mySlimes = {}
        
        for _, slimeData in collectionService:GetTagged('SlimeData') do
            if slimeData:WaitForChild("Tamer", 0.1) and slimeData.Tamer.Value == lplr.UserId then
                local slimeType = slimeData:GetAttribute("SlimeType")
                local slimeId = slimeData:GetAttribute("Id")
                
                if slimeType ~= nil and slimeId ~= nil then
                    if not mySlimes[slimeType] then
                        mySlimes[slimeType] = {}
                    end
                    table.insert(mySlimes[slimeType], {
                        data = slimeData,
                        id = slimeId,
                        type = slimeType
                    })
                end
            end
        end
        
        return mySlimes
    end
    
    local function getSlimeCurrentTarget(slimeData)
        if not slimeData or not slimeData:FindFirstChild("Following") then
            return nil
        end
        
        local followingUserId = slimeData.Following.Value
        if followingUserId == 0 or followingUserId ~= followingUserId or not followingUserId then
            return nil
        end
        
        return playersService:GetPlayerByUserId(followingUserId)
    end
    
    local function moveSlimeToPlayer(slimeId, targetPlayer)
        if not targetPlayer then return false end
        
        pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("SLIME_DIRECT")
            
            task.wait(0.05)
            
            bedwars.Client:Get(remotes.RequestMoveSlime).instance:InvokeServer({
                slimeId = slimeId,
                targetPlayerUserId = targetPlayer.UserId
            })
        end)
        
        return true
    end
    
    local function retractSlimeToSelf(slimeId)
        pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer("SLIME_DIRECT")
            
            task.wait(0.05)
            
            bedwars.Client:Get(remotes.RequestMoveSlime).instance:InvokeServer({
                slimeId = slimeId,
                targetPlayerUserId = lplr.UserId
            })
        end)
    end
    
    local function manageSlimeType(slimeType, targetDropdown)
        local targetName = targetDropdown.Value
        
        local mySlimes = getMySlimes()
        local slimesOfType = mySlimes[slimeType]
        
        if not slimesOfType or #slimesOfType == 0 then
            return
        end
        
        if targetName == "None" or targetName == "" then
            for _, slimeInfo in ipairs(slimesOfType) do
                local currentTarget = getSlimeCurrentTarget(slimeInfo.data)
                
                if currentTarget and currentTarget ~= lplr then
                    retractSlimeToSelf(slimeInfo.id)
                    task.wait(0.15)
                end
            end
            return
        end
        
        local targetPlayer = playersService:FindFirstChild(targetName)
        if not targetPlayer then
            return
        end
        
        if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        
        for _, slimeInfo in ipairs(slimesOfType) do
            local currentTarget = getSlimeCurrentTarget(slimeInfo.data)
            
            if currentTarget ~= targetPlayer then
                moveSlimeToPlayer(slimeInfo.id, targetPlayer)
                task.wait(0.15)
            end
        end
    end
    
    local function startSlimeManagement()
        if slimeCheckThread then
            task.cancel(slimeCheckThread)
            slimeCheckThread = nil
        end
        
        running = true
        slimeCheckThread = task.spawn(function()
            while running and AutoNoelle.Enabled do
                if HealSlimeToggle.Enabled then
                    manageSlimeType(SLIME_TYPES.HEALING, HealSlimeDropdown)
                end
                
                if VoidSlimeToggle.Enabled then
                    manageSlimeType(SLIME_TYPES.VOID, VoidSlimeDropdown)
                end
                
                if StickySlimeToggle.Enabled then
                    manageSlimeType(SLIME_TYPES.STICKY, StickySlimeDropdown)
                end
                
                if FrostySlimeToggle.Enabled then
                    manageSlimeType(SLIME_TYPES.FROSTY, FrostySlimeDropdown)
                end
                
                task.wait(1.5)
            end
            slimeCheckThread = nil
        end)
    end
    
    local function stopSlimeManagement()
        running = false
        if slimeCheckThread then
            task.cancel(slimeCheckThread)
            slimeCheckThread = nil
        end
    end
    
    AutoNoelle = vape.Categories.Kits:CreateModule({
        Name = "AutoNoelle",
        Function = function(callback)
            running = callback
            
            if callback then
                startSlimeManagement()
                
                AutoNoelle:Clean(playersService.PlayerAdded:Connect(function()
                    task.wait(0.5)
                    local newList = getTeammateNames()
                    if HealSlimeDropdown then HealSlimeDropdown:Change(newList) end
                    if VoidSlimeDropdown then VoidSlimeDropdown:Change(newList) end
                    if StickySlimeDropdown then StickySlimeDropdown:Change(newList) end
                    if FrostySlimeDropdown then FrostySlimeDropdown:Change(newList) end
                end))
                
                AutoNoelle:Clean(playersService.PlayerRemoving:Connect(function()
                    task.wait(0.5)
                    local newList = getTeammateNames()
                    if HealSlimeDropdown then HealSlimeDropdown:Change(newList) end
                    if VoidSlimeDropdown then VoidSlimeDropdown:Change(newList) end
                    if StickySlimeDropdown then StickySlimeDropdown:Change(newList) end
                    if FrostySlimeDropdown then FrostySlimeDropdown:Change(newList) end
                end))
                
                AutoNoelle:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(1)
                    local newList = getTeammateNames()
                    if HealSlimeDropdown then HealSlimeDropdown:Change(newList) end
                    if VoidSlimeDropdown then VoidSlimeDropdown:Change(newList) end
                    if StickySlimeDropdown then StickySlimeDropdown:Change(newList) end
                    if FrostySlimeDropdown then FrostySlimeDropdown:Change(newList) end
                end))
            else
                stopSlimeManagement()
            end
        end,
        Tooltip = "Automatically manages slimes to follow specific teammates"
    })
    
    HealSlimeToggle = AutoNoelle:CreateToggle({
        Name = "Heal Slime",
        Default = false,
        Tooltip = "Assign heal slime to teammate",
        Function = function(callback)
            if HealSlimeDropdown and HealSlimeDropdown.Object then
                HealSlimeDropdown.Object.Visible = callback
            end
            if HealSlimeRefresh and HealSlimeRefresh.Object then
                HealSlimeRefresh.Object.Visible = callback
            end
            
            if callback and AutoNoelle.Enabled then
                startSlimeManagement()
            end
        end
    })
    
    local function teammateListWithNone()
        local list = {"None"}
        for _, name in ipairs(getTeammateNames()) do
            table.insert(list, name)
        end
        return list
    end

    HealSlimeDropdown = AutoNoelle:CreateDropdown({
        Name = "Heal Target",
        List = teammateListWithNone(),
        Function = function(val)
        end,
        Tooltip = "Select teammate for heal slime"
    })
    
    HealSlimeRefresh = AutoNoelle:CreateButton({
        Name = "Refresh Heal List",
        Function = function()
            task.spawn(function()
                local newList = getTeammateNames()
                
                if HealSlimeDropdown then
                    pcall(function()
                        HealSlimeDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not HealSlimeDropdown.Value or HealSlimeDropdown.Value == "" or not table.find(newList, HealSlimeDropdown.Value) then
                                HealSlimeDropdown:SetValue(newList[1])
                            else
                                HealSlimeDropdown:SetValue(HealSlimeDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("Auto Noelle", string.format("Refreshed heal list (%d teammates)", #newList - 1), 2)
            end)
        end,
        Tooltip = "Manually refresh heal teammate list"
    })
    
    VoidSlimeToggle = AutoNoelle:CreateToggle({
        Name = "Damage Slime",
        Default = false,
        Tooltip = "Assign Damage slime to teammate",
        Function = function(callback)
            if VoidSlimeDropdown and VoidSlimeDropdown.Object then
                VoidSlimeDropdown.Object.Visible = callback
            end
            if VoidSlimeRefresh and VoidSlimeRefresh.Object then
                VoidSlimeRefresh.Object.Visible = callback
            end
            
            if callback and AutoNoelle.Enabled then
                startSlimeManagement()
            end
        end
    })
    
    VoidSlimeDropdown = AutoNoelle:CreateDropdown({
        Name = "Damage Target",
        List = getTeammateNames(),
        Function = function(val)
        end,
        Tooltip = "Select teammate for Damage slime"
    })
    
    VoidSlimeRefresh = AutoNoelle:CreateButton({
        Name = "Refresh Damage List",
        Function = function()
            task.spawn(function()
                local newList = getTeammateNames()
                
                if VoidSlimeDropdown then
                    pcall(function()
                        VoidSlimeDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not VoidSlimeDropdown.Value or VoidSlimeDropdown.Value == "" or not table.find(newList, VoidSlimeDropdown.Value) then
                                VoidSlimeDropdown:SetValue(newList[1])
                            else
                                VoidSlimeDropdown:SetValue(VoidSlimeDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("Auto Noelle", string.format("Refreshed Damage list (%d teammates)", #newList - 1), 2)
            end)
        end,
        Tooltip = "Manually refresh Damage teammate list"
    })
    
    StickySlimeToggle = AutoNoelle:CreateToggle({
        Name = "Cycle Slime",
        Default = false,
        Tooltip = "Assign cycle slime to teammate",
        Function = function(callback)
            if StickySlimeDropdown and StickySlimeDropdown.Object then
                StickySlimeDropdown.Object.Visible = callback
            end
            if StickySlimeRefresh and StickySlimeRefresh.Object then
                StickySlimeRefresh.Object.Visible = callback
            end
            
            if callback and AutoNoelle.Enabled then
                startSlimeManagement()
            end
        end
    })
    
    StickySlimeDropdown = AutoNoelle:CreateDropdown({
        Name = "Cycle Target",
        List = getTeammateNames(),
        Function = function(val)
        end,
        Tooltip = "Select teammate for cycle slime"
    })
    
    StickySlimeRefresh = AutoNoelle:CreateButton({
        Name = "Refresh Cycle List",
        Function = function()
            task.spawn(function()
                local newList = getTeammateNames()
                
                if StickySlimeDropdown then
                    pcall(function()
                        StickySlimeDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not StickySlimeDropdown.Value or StickySlimeDropdown.Value == "" or not table.find(newList, StickySlimeDropdown.Value) then
                                StickySlimeDropdown:SetValue(newList[1])
                            else
                                StickySlimeDropdown:SetValue(StickySlimeDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("Auto Noelle", string.format("Refreshed Cycle list (%d teammates)", #newList - 1), 2)
            end)
        end,
        Tooltip = "Manually refresh Cycle teammate list"
    })
    
    FrostySlimeToggle = AutoNoelle:CreateToggle({
        Name = "Slow Slime",
        Default = false,
        Tooltip = "Assign Slow slime to teammate",
        Function = function(callback)
            if FrostySlimeDropdown and FrostySlimeDropdown.Object then
                FrostySlimeDropdown.Object.Visible = callback
            end
            if FrostySlimeRefresh and FrostySlimeRefresh.Object then
                FrostySlimeRefresh.Object.Visible = callback
            end
            
            if callback and AutoNoelle.Enabled then
                startSlimeManagement()
            end
        end
    })
    
    FrostySlimeDropdown = AutoNoelle:CreateDropdown({
        Name = "Slow Target",
        List = getTeammateNames(),
        Function = function(val)
        end,
        Tooltip = "Select teammate for slow slime"
    })
    
    FrostySlimeRefresh = AutoNoelle:CreateButton({
        Name = "Refresh Slow List",
        Function = function()
            task.spawn(function()
                local newList = getTeammateNames()
                
                if FrostySlimeDropdown then
                    pcall(function()
                        FrostySlimeDropdown:Change(newList)
                        
                        if #newList > 0 then
                            if not FrostySlimeDropdown.Value or FrostySlimeDropdown.Value == "" or not table.find(newList, FrostySlimeDropdown.Value) then
                                FrostySlimeDropdown:SetValue(newList[1])
                            else
                                FrostySlimeDropdown:SetValue(FrostySlimeDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("Auto Noelle", string.format("Refreshed slow list (%d teammates)", #newList - 1), 2)
            end)
        end,
        Tooltip = "Manually refresh slow teammate list"
    })

    task.defer(function()
        if HealSlimeDropdown and HealSlimeDropdown.Object then HealSlimeDropdown.Object.Visible = false end
        if HealSlimeRefresh and HealSlimeRefresh.Object then HealSlimeRefresh.Object.Visible = false end
        if VoidSlimeDropdown and VoidSlimeDropdown.Object then VoidSlimeDropdown.Object.Visible = false end
        if VoidSlimeRefresh and VoidSlimeRefresh.Object then VoidSlimeRefresh.Object.Visible = false end
        if StickySlimeDropdown and StickySlimeDropdown.Object then StickySlimeDropdown.Object.Visible = false end
        if StickySlimeRefresh and StickySlimeRefresh.Object then StickySlimeRefresh.Object.Visible = false end
        if FrostySlimeDropdown and FrostySlimeDropdown.Object then FrostySlimeDropdown.Object.Visible = false end
        if FrostySlimeRefresh and FrostySlimeRefresh.Object then FrostySlimeRefresh.Object.Visible = false end
    end)
end)

run(function()
    local Kaliyah
    local AutoPunch
    local RangeSlider
    local PunchDelay
    local DelaySlider
    local NoSlow
    local punchActive = false
    local punchDebounce = {}

    local function getKaliyahTargets()
        local targets = {}
        if not entitylib.isAlive then return targets end
        
        local localPosition = entitylib.character.RootPart.Position
        local range = RangeSlider.Value
        
        for _, v in collectionService:GetTagged('KaliyahPunchInteraction') do
            if v:IsA("Model") and v.PrimaryPart then
                local distance = (localPosition - v.PrimaryPart.Position).Magnitude
                if distance <= range then
                    table.insert(targets, v)
                end
            end
        end
        
        return targets
    end

    local function punchTarget(target)
        local targetId = target:GetAttribute('Id') or tostring(target)
        
        if punchDebounce[targetId] then return false end
        punchDebounce[targetId] = true
        
        local character = lplr.Character
        if not character or not character.PrimaryPart then 
            punchDebounce[targetId] = nil
            return false 
        end
        
        pcall(function()
            bedwars.DragonSlayerController:deleteEmblem(target)
        end)
        
        local playerPos = character:GetPrimaryPartCFrame().Position
        local targetPos = target:GetPrimaryPartCFrame().Position * Vector3.new(1, 0, 1) + Vector3.new(0, playerPos.Y, 0)
        local lookAtCFrame = CFrame.new(playerPos, targetPos)
        
        character:PivotTo(lookAtCFrame)
        
        pcall(function()
            bedwars.DragonSlayerController:playPunchAnimation(lookAtCFrame - lookAtCFrame.Position)
        end)
        
        local success = pcall(function()
            bedwars.Client:Get(remotes.RequestDragonPunch):SendToServer({
                target = target
            })
        end)
        
        task.delay(3, function()
            punchDebounce[targetId] = nil
        end)
        
        return success
    end

    local function startAutoPunch()
        if punchActive then return end
        punchActive = true
        
        task.spawn(function()
            while Kaliyah.Enabled and AutoPunch.Enabled and punchActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                local targets = getKaliyahTargets()
                local punchedThisCycle = false
                
                for _, target in targets do
                    if not Kaliyah.Enabled or not AutoPunch.Enabled or not punchActive then 
                        break 
                    end
                    
                    if PunchDelay.Enabled and DelaySlider.Value > 0 then
                        task.wait(DelaySlider.Value)
                    end
                    
                    if punchTarget(target) then
                        punchedThisCycle = true
                        task.wait(0.2)
                    end
                end
                
                task.wait(punchedThisCycle and 0.5 or 0.3)
            end
            
            punchActive = false
        end)
    end

    local function stopAutoPunch()
        punchActive = false
        table.clear(punchDebounce)
    end

    local originalPlayPunchAnimation
    local function hookNoSlow()
        if not bedwars.DragonSlayerController then return end
        
        originalPlayPunchAnimation = bedwars.DragonSlayerController.playPunchAnimation
        
        bedwars.DragonSlayerController.playPunchAnimation = function(self, arg2)
            if NoSlow.Enabled then
                local any_import_result1_6_upvr = debug.getupvalue(originalPlayPunchAnimation, 1)
                local GameAnimationUtil_upvr = debug.getupvalue(originalPlayPunchAnimation, 2)
                local Players_upvr = debug.getupvalue(originalPlayPunchAnimation, 3)
                local AnimationType_upvr = debug.getupvalue(originalPlayPunchAnimation, 4)
                local KnitClient_upvr = debug.getupvalue(originalPlayPunchAnimation, 5)
                local RunService_upvr = debug.getupvalue(originalPlayPunchAnimation, 6)
                
                local any_new_result1_upvr_2 = any_import_result1_6_upvr.new()
                local any_playAnimation_result1_upvr_2 = GameAnimationUtil_upvr:playAnimation(Players_upvr.LocalPlayer, AnimationType_upvr.DRAGON_SLAYER_PUNCH)
                any_new_result1_upvr_2:GiveTask(function()
                    local var137 = any_playAnimation_result1_upvr_2
                    if var137 ~= nil then
                        var137:Stop()
                    end
                end)
                
                any_new_result1_upvr_2:GiveTask(RunService_upvr.Heartbeat:Connect(function()
                    local Character = Players_upvr.LocalPlayer.Character
                    local var141 = Character
                    if var141 ~= nil then
                        var141 = var141.PrimaryPart
                    end
                    if not var141 then
                        any_new_result1_upvr_2:DoCleaning()
                        return nil
                    end
                    Character:PivotTo(CFrame.new(Character:GetPrimaryPartCFrame().Position) * arg2)
                end))
                
                task.delay(0.46, function()
                    any_new_result1_upvr_2:DoCleaning()
                end)
                
                return any_new_result1_upvr_2
            else
                return originalPlayPunchAnimation(self, arg2)
            end
        end
    end

    local function unhookNoSlow()
        if originalPlayPunchAnimation and bedwars.DragonSlayerController then
            bedwars.DragonSlayerController.playPunchAnimation = originalPlayPunchAnimation
        end
    end

    Kaliyah = vape.Categories.Kits:CreateModule({
        Name = 'AutoKaliyah',
        Function = function(callback)
            if callback then
                if AutoPunch.Enabled then
                    startAutoPunch()
                end
                if NoSlow.Enabled then
                    hookNoSlow()
                end
            else
                stopAutoPunch()
                unhookNoSlow()
            end
        end,
        Tooltip = 'Dragon Slayer kit features - AutoPunch and NoSlow'
    })
    
    AutoPunch = Kaliyah:CreateToggle({
        Name = 'Auto Punch',
        Default = false,
        Tooltip = 'Automatically punch dragon emblems',
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if PunchDelay and PunchDelay.Object then PunchDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and PunchDelay.Enabled) end
            if not callback then
                if DelaySlider and DelaySlider.Object then
                    DelaySlider.Object.Visible = false
                end
            else
                if PunchDelay and PunchDelay.Enabled then
                    if DelaySlider and DelaySlider.Object then
                        DelaySlider.Object.Visible = true
                    end
                end
            end
            
            if Kaliyah.Enabled then
                if callback then
                    startAutoPunch()
                else
                    stopAutoPunch()
                end
            end
        end
    })
    
    RangeSlider = Kaliyah:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 100,
        Default = 18,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Distance to auto punch emblems'
    })
    
    PunchDelay = Kaliyah:CreateToggle({
        Name = 'Punch Delay',
        Default = false,
        Tooltip = 'Add delay before punching',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Kaliyah:CreateSlider({
        Name = 'Delay',
        Min = 1,
        Max = 3,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before punching'
    })
    
    NoSlow = Kaliyah:CreateToggle({
        Name = 'No Slow',
        Default = false,
        Tooltip = 'Remove movement lock when punching',
        Function = function(callback)
            if Kaliyah.Enabled then
                if callback then
                    hookNoSlow()
                else
                    unhookNoSlow()
                end
            end
        end
    })

    task.defer(function()
        if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = false end
        if PunchDelay and PunchDelay.Object then PunchDelay.Object.Visible = false end
        if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = false end
    end)
end)

run(function()
	local CrocBlocks
	local connections = {}
	local originalData = {}
	local processedBlocks = {}
	local TEXTURE_ID = 'rbxassetid://125197310764304'

	local function isBlock(obj)
		if not obj:IsA('BasePart') then return false end
		return collectionService:HasTag(obj, 'block') or
			(bedwars.ItemMeta and bedwars.ItemMeta[obj.Name] and bedwars.ItemMeta[obj.Name].block ~= nil)
	end

	local function applyTexture(obj)
		if not obj or not obj.Parent or processedBlocks[obj] then return end
		if not isBlock(obj) then return end

		local saved = {
			Material = obj.Material,
			Color = obj.Color,
			TextureID = obj:IsA('MeshPart') and obj.TextureID or nil,
			clones = {}
		}

		for _, child in obj:GetChildren() do
			if child:IsA('Decal') or child:IsA('Texture') or child:IsA('SurfaceAppearance') or child:IsA('SpecialMesh') then
				local clone = child:Clone()
				clone.Parent = workspace.CurrentCamera
				table.insert(saved.clones, {clone = clone, class = child.ClassName})
				child:Destroy()
			end
		end

		originalData[obj] = saved

		if obj:IsA('MeshPart') then
			pcall(function() obj.TextureID = '' end)
		end
		pcall(function() obj.Material = Enum.Material.SmoothPlastic end)

		for _, face in Enum.NormalId:GetEnumItems() do
			local decal = Instance.new('Decal')
			decal.Name = 'CrocBlock'
			decal.Texture = TEXTURE_ID
			decal.Face = face
			decal.Parent = obj
		end

		processedBlocks[obj] = true
	end

	local function restoreTexture(obj)
		if not obj then return end

		if obj:IsA('BasePart') then
			for _, child in obj:GetChildren() do
				if child:IsA('Decal') and child.Name == 'CrocBlock' then
					child:Destroy()
				end
			end
		end

		local saved = originalData[obj]
		if saved and obj.Parent then
			pcall(function() obj.Material = saved.Material end)
			pcall(function() obj.Color = saved.Color end)
			if saved.TextureID and obj:IsA('MeshPart') then
				pcall(function() obj.TextureID = saved.TextureID end)
			end
			for _, entry in saved.clones do
				pcall(function()
					local restored = entry.clone:Clone()
					restored.Parent = obj
					entry.clone:Destroy()
				end)
			end
		end

		originalData[obj] = nil
		processedBlocks[obj] = nil
	end

	local function processAll(apply)
		task.spawn(function()
			local descendants = workspace:GetDescendants()
			for i, obj in descendants do
				if apply then
					applyTexture(obj)
				else
					restoreTexture(obj)
				end
				if i % 50 == 0 then task.wait() end
			end
		end)
	end

	CrocBlocks = vape.Categories.Blatant:CreateModule({
		Name = 'CrocBlocks',
		Function = function(callback)
			if callback then
				processAll(true)
				table.insert(connections, workspace.DescendantAdded:Connect(function(obj)
					if CrocBlocks.Enabled and isBlock(obj) then
						applyTexture(obj)
					end
				end))
			else
				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				processAll(false)
				task.delay(2, function()
					for _, data in originalData do
						for _, entry in data.clones do
							pcall(function() entry.clone:Destroy() end)
						end
					end
					table.clear(originalData)
					table.clear(processedBlocks)
				end)
			end
		end,
		Tooltip = 'Replaces all block textures with the croc texture on all sides'
	})
end)

run(function()
	local GreyPlayers
	local stored = {} 
	local connections = {}

	local function makeGray(character)
		if not character or character == lplr.Character then return end

		local data = {}
		for _, obj in ipairs(character:GetDescendants()) do
			if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
				data[obj] = { Parent = obj.Parent }
				obj.Parent = nil

			elseif obj:IsA("BasePart") and obj.Parent == character then
				local props = {
					Color = obj.Color,
					Material = obj.Material,
					Transparency = obj.Transparency,
					Reflectance = obj.Reflectance,
				}
				if obj:IsA("MeshPart") then
					props.TextureID = obj.TextureID
				end
				data[obj] = props

				obj.Color = Color3.new(0.5, 0.5, 0.5)
				obj.Material = Enum.Material.SmoothPlastic
				obj.Transparency = 0
				obj.Reflectance = 0
				if obj:IsA("MeshPart") then
					obj.TextureID = ""
				end

			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				if obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Parent == character then
					data[obj] = {
						Transparency = obj.Transparency,
						Texture = obj.Texture,
					}
					obj.Transparency = 1
				end
			end
		end
		stored[character] = data
	end

	local function restore(character)
		local data = stored[character]
		if not data then return end
		for obj, props in pairs(data) do
			if obj and obj.Parent == nil and props.Parent then
				obj.Parent = props.Parent
			end
			if obj and obj.Parent then
				for prop, val in pairs(props) do
					if prop ~= "Parent" then
						pcall(function() obj[prop] = val end)
					end
				end
			end
		end
		stored[character] = nil
	end

	local function onPlayerAdded(player)
		if player == lplr then return end
		local conn = player.CharacterAdded:Connect(function(char)
			if GreyPlayers.Enabled then
				makeGray(char)
			end
		end)
		table.insert(connections, conn)
		if player.Character then
			makeGray(player.Character)
		end
	end

	local function onPlayerRemoving(player)
		if player == lplr then return end
		if player.Character then
			restore(player.Character)
		end
	end

	GreyPlayers = vape.Categories.BoostFPS:CreateModule({
		Name = 'GreyPlayers',
		Function = function(callback)
			if callback then
				for _, player in ipairs(playersService:GetPlayers()) do
					onPlayerAdded(player)
				end
				local addedConn = playersService.PlayerAdded:Connect(onPlayerAdded)
				local removingConn = playersService.PlayerRemoving:Connect(onPlayerRemoving)
				table.insert(connections, addedConn)
				table.insert(connections, removingConn)

				GreyPlayers:Clean(function()
					for _, conn in ipairs(connections) do conn:Disconnect() end
					table.clear(connections)
					for char in pairs(stored) do
						if char and char.Parent then
							restore(char)
						end
					end
					table.clear(stored)
				end)
			else
			end
		end,
		Tooltip = 'Removes clothing/accessories, turns body parts gray, keeps weapons untouched.'
	})
end)

run(function()
	local ElektraExtender
	local RS = game.ReplicatedStorage
	local EXTRA_BLOCKS = 2
	local savedDepth    = nil
	local savedCooldown = nil
	local savedDuration = nil
	local BF = nil
	local heartbeat = nil

	local function getBF()
		if BF then return BF end
		pcall(function()
			BF = require(RS.TS.balance["balance-file"]).BalanceFile
		end)
		return BF
	end

	local function getCtrl()
		local c = nil
		pcall(function()
			c = require(RS.rbxts_include.node_modules["@easy-games"].knit.src)
				.KnitClient.Controllers.ElektraController
		end)
		return c
	end

	local function apply()
		local bf = getBF()
		if bf and bf.ELEKTRA then
			if not savedDepth then
				savedDepth    = bf.ELEKTRA.ELECTRIC_DASH_DEPTH_GOAL
				savedCooldown = bf.ELEKTRA.ELECTRIC_DASH_COOLDOWN
				savedDuration = bf.ELEKTRA.ELECTRIC_DASH_DURATION
			end
			bf.ELEKTRA.ELECTRIC_DASH_DEPTH_GOAL = savedDepth + (EXTRA_BLOCKS * 4) -- shhhh
			bf.ELEKTRA.ELECTRIC_DASH_COOLDOWN   = 0
			bf.ELEKTRA.ELECTRIC_DASH_DURATION   = 0
		end

		heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
			local c = getCtrl()
			if c then
				c.dashReadyTime = -1
				c.lastDash      = -math.huge
			end
		end)
	end

	local function revert()
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
		local bf = getBF()
		if bf and bf.ELEKTRA and savedDepth then
			bf.ELEKTRA.ELECTRIC_DASH_DEPTH_GOAL = savedDepth
			bf.ELEKTRA.ELECTRIC_DASH_COOLDOWN   = savedCooldown
			bf.ELEKTRA.ELECTRIC_DASH_DURATION   = savedDuration
		end
		savedDepth    = nil
		savedCooldown = nil
		savedDuration = nil
	end

	ElektraExtender = vape.Categories.Kits:CreateModule({
		Name     = "ElektraExtender",
		Function = function(enabled)
			if enabled then apply() else revert() end
		end,
		Tooltip  = "Extends Elektra dash + removes client cooldown"
	})

	ElektraExtender:CreateSlider({
		Name     = "Extra Blocks",
		Min      = 1,
		Max      = 3,
		Default  = 2,
		Decimal  = 1,
		Function = function(val)
			EXTRA_BLOCKS = math.floor(val)
			if ElektraExtender.Enabled then
				local bf = getBF()
				if bf and bf.ELEKTRA and savedDepth then
					bf.ELEKTRA.ELECTRIC_DASH_DEPTH_GOAL = savedDepth + (EXTRA_BLOCKS * 4)
				end
			end
		end
	})
end)
