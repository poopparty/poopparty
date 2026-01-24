--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
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
	damage = {},
	damageBlockFail = tick(),
	hand = {},
	localHand = {},
	inventory = {
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
local InfiniteFly = {}
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
	for _, wool in (inv or store.inventory.inventory.items) do
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
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
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
		if ent.NPC then return true end
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
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
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
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = debug.getproto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = debug.getproto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = debug.getproto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = debug.getproto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
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
		EquipItem = 'SetInvItem'
	}

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' then
			if not preDumped[i] then
				notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
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
							if v.item and v.item.tool == tool.tool and i ~= (store.inventory.hotbarSlot + 1) then 
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

			if effects then
				return pos, path, target
			end
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
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
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

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			local changedBlockPos = data.blockRef.blockPosition * 3
			for i, v in cache do
				local cachedTargetPos = v[1]
				local cachedPath = v[3]
				local shouldClear = false
				
				if (changedBlockPos - cachedTargetPos).Magnitude <= 30 then
					shouldClear = true
				else
					for pathNode in cachedPath do
						if (changedBlockPos - pathNode).Magnitude <= 3 then
							shouldClear = true
							break
						end
					end
				end
				
				if shouldClear then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
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
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
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
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end

local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
	game.ReplicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.TeleportToLobby:FireServer()
end

run(function()
	local function isFirstPerson()
		if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return nil end
		return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
	end
	
	local function hasValidWeapon()
		if not store.hand or not store.hand.tool then return false end
		local toolType = store.hand.toolType
		local toolName = store.hand.tool.Name:lower()
		if toolName:find('headhunter') then
			return true
		end
		return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
	end
	
	local function isHoldingProjectile()
		if not store.hand or not store.hand.tool then return false end
		local toolName = store.hand.tool.Name
		if toolName == "headhunter" or toolName:lower():find("headhunter") then
			return true
		end
		if toolName:lower():find("bow") or toolName:lower():find("crossbow") then
			return true
		end
		local toolMeta = bedwars.ItemMeta[toolName]
		if toolMeta and toolMeta.projectileSource then
			return true
		end
		return false
	end
	
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeMultiplier
	local KillauraTarget
	local ClickAim
	local ShopCheck
	local FirstPersonCheck
	local VerticalAim
	local VerticalOffset
	local AimPart
	local ProjectileMode
	local ProjectileAimSpeed
	local ProjectileDistance
	local ProjectileAngle
	local WorkWithAllItems
	local PriorityMode
	local ThirdPersonAim
	local ShakeToggle
	local ShakeAmount
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}
	
	local lockedTarget = nil
	local rng = Random.new()
	
	local function isTargetValid(ent, currentDistance)
		if not ent or not ent.RootPart or not ent.Character then return false end
		if not entitylib.isAlive then return false end
		local distance = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
		if distance > currentDistance then return false end
		
		if Targets.Walls.Enabled then
			local ray = workspace:Raycast(
				entitylib.character.RootPart.Position,
				(ent.RootPart.Position - entitylib.character.RootPart.Position),
				rayCheck
			)
			if ray then return false end
		end
		
		local humanoid = ent.Character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return false end
		
		return true
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					local validWeaponCheck = WorkWithAllItems.Enabled or hasValidWeapon()
					
					if not (entitylib.isAlive and validWeaponCheck and ((not ClickAim.Enabled) or (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) < 0.4)) then
						lockedTarget = nil
						return
					end
					
					if ShopCheck.Enabled then
						local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
						if isShop then return end
					end
					
					if FirstPersonCheck.Enabled and not isFirstPerson() then return end
					
					local holdingProjectile = isHoldingProjectile()
					local useProjectileMode = ProjectileMode.Enabled and holdingProjectile
					local currentDistance = useProjectileMode and ProjectileDistance.Value or Distance.Value
					local currentAngle = useProjectileMode and ProjectileAngle.Value or AngleSlider.Value
					local ent = nil
					
					if PriorityMode.Enabled then
						if lockedTarget and isTargetValid(lockedTarget, currentDistance) then
							local delta = (lockedTarget.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							
							if angle < (math.rad(currentAngle) / 2) then
								ent = lockedTarget
							else
								lockedTarget = nil
							end
						else
							lockedTarget = nil
						end
						
						if not ent then
							ent = KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
								Range = currentDistance,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods[Sort.Value]
							})
							
							if ent then
								lockedTarget = ent
							end
						end
					else
						lockedTarget = nil
						ent = KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
							Range = currentDistance,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})
					end
					
					if ent then
						pcall(function()
							local plr = ent
							vapeTargetInfo.Targets.AimAssist = {
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
						if angle >= (math.rad(currentAngle) / 2) then return end
						
						targetinfo.Targets[ent] = tick() + 1
						
						local aimPosition = ent.RootPart.Position
						
						if AimPart.Value ~= "Root" then
							local targetPart = ent.Character:FindFirstChild(AimPart.Value == "Head" and "Head" or "Torso")
							if targetPart then
								aimPosition = targetPart.Position
							end
						end
						
						if useProjectileMode then
							local projSpeed = 100
							local gravity = 196.2
							
							if store.hand.tool then
								local toolMeta = bedwars.ItemMeta[store.hand.tool.Name]
								if toolMeta and toolMeta.projectileSource then
									local projectileType = toolMeta.projectileSource.projectileType
									
									if type(projectileType) == "function" then
										local success, result = pcall(projectileType, nil)
										if success then
											projectileType = result
										else
											success, result = pcall(projectileType, 'arrow')
											if success then
												projectileType = result
											end
										end
									end
									
									if projectileType and bedwars.ProjectileMeta[projectileType] then
										local projectileMeta = bedwars.ProjectileMeta[projectileType]
										projSpeed = projectileMeta.launchVelocity or projectileMeta.speed or 100
										gravity = projectileMeta.gravitationalAcceleration or 196.2
									end
								end
							end
							
							local balloons = ent.Character:GetAttribute('InflatedBalloons')
							local playerGravity = workspace.Gravity
							
							if balloons and balloons > 0 then
								playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
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
							
							local originPos = gameCamera.CFrame.Position
							local targetPart = ent.Character:FindFirstChild(AimPart.Value == "Head" and "Head" or AimPart.Value == "Torso" and "Torso" or "RootPart")
							if not targetPart then targetPart = ent.RootPart end
							
							local targetVelocity = targetPart.Velocity
							local calc = prediction.SolveTrajectory(
								originPos,
								projSpeed,
								gravity,
								targetPart.Position,
								targetVelocity,
								playerGravity,
								ent.HipHeight,
								ent.Jumping and 42.6 or nil,
								rayCheck
							)
							
							if calc then
								local predictedPosition = calc
								
								if VerticalAim.Enabled then
									predictedPosition = predictedPosition + Vector3.new(0, VerticalOffset.Value, 0)
								end
								
								if ShakeToggle.Enabled and ShakeAmount.Value > 0 then
									local shake = Vector3.new(
										(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1,
										(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1,
										(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1
									)
									predictedPosition = predictedPosition + shake
								end
								
								local finalAimSpeed = ProjectileAimSpeed.Value * 0.01
								if StrafeMultiplier.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
									finalAimSpeed = finalAimSpeed * 1.3
								end
								
								local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, predictedPosition)
								gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, finalAimSpeed)
							end
						else
							if VerticalAim.Enabled then
								aimPosition = aimPosition + Vector3.new(0, VerticalOffset.Value, 0)
							end
							
							if ShakeToggle.Enabled and ShakeAmount.Value > 0 then
								local shake = Vector3.new(
									(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1,
									(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1,
									(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.1
								)
								aimPosition = aimPosition + shake
							end
							
							local finalAimSpeed = AimSpeed.Value * 0.01
							if StrafeMultiplier.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
								finalAimSpeed = finalAimSpeed * 1.3
							end
							
							if ThirdPersonAim.Enabled then
								entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(
									CFrame.lookAt(entitylib.character.RootPart.CFrame.p, 
									Vector3.new(aimPosition.X, entitylib.character.RootPart.Position.Y, aimPosition.Z)), 
									finalAimSpeed * 100 * dt
								)
							else
								gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, aimPosition), finalAimSpeed)
							end
						end
					else
						if PriorityMode.Enabled then
							lockedTarget = nil
						end
					end
				end))
			else
				lockedTarget = nil
			end
		end
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
		Default = 25,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max Angle',
		Min = 1,
		Max = 180,
		Default = 60
	})
	
	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Root', 'Torso', 'Head'},
		Default = 'Root'
	})
	
	ProjectileMode = AimAssist:CreateToggle({
		Name = 'Projectile Mode',
		Default = false,
		Function = function(callback)
			ProjectileAimSpeed.Object.Visible = callback
			ProjectileDistance.Object.Visible = callback
			ProjectileAngle.Object.Visible = callback
		end
	})
	
	ProjectileAimSpeed = AimAssist:CreateSlider({
		Name = 'Projectile Speed',
		Min = 1,
		Max = 15,
		Default = 8,
		Visible = false
	})
	
	ProjectileDistance = AimAssist:CreateSlider({
		Name = 'Projectile Distance',
		Min = 1,
		Max = 100,
		Default = 50,
		Visible = false,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	
	ProjectileAngle = AimAssist:CreateSlider({
		Name = 'Projectile Angle',
		Min = 1,
		Max = 180,
		Default = 90,
		Visible = false
	})
	
	PriorityMode = AimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false
	})
	
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use Killaura Target'
	})
	
	VerticalAim = AimAssist:CreateToggle({
		Name = 'Vertical Offset',
		Default = false,
		Function = function(callback)
			VerticalOffset.Object.Visible = callback
		end
	})
	
	VerticalOffset = AimAssist:CreateSlider({
		Name = 'Offset',
		Min = -3,
		Max = 3,
		Default = 0,
		Decimal = 10,
		Visible = false
	})
	
	ShakeToggle = AimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Function = function(callback)
			ShakeAmount.Object.Visible = callback
		end
	})
	
	ShakeAmount = AimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 0,
		Max = 100,
		Default = 10,
		Visible = false
	})
	
	ShopCheck = AimAssist:CreateToggle({
		Name = "Shop Check",
		Default = false
	})
	
	FirstPersonCheck = AimAssist:CreateToggle({
		Name = "First Person Only",
		Default = false
	})
	
	ThirdPersonAim = AimAssist:CreateToggle({
		Name = 'Third Person Aim',
		Default = false
	})
	
	StrafeMultiplier = AimAssist:CreateToggle({
		Name = 'Strafe Boost'
	})
	
	WorkWithAllItems = AimAssist:CreateToggle({
		Name = 'Work With All Items',
		Default = false
	})
end)
	
run(function()
    local AutoClicker
    local CPS
    local BlockCPS = {}
    local SwordCPS = {}
    local PlaceBlocksToggle
    local SwingSwordToggle
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

    local function AutoClick()
        if Thread then
            task.cancel(Thread)
        end
    
        Thread = task.delay(1 / 7, function()
            repeat
                if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                    if PlaceBlocksToggle.Enabled and store.hand.toolType == 'block' then
                        local blockPlacer = bedwars.BlockPlacementController.blockPlacer
                        if blockPlacer then
                            if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                    task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                end
                            end
                        end
                    
                    elseif SwingSwordToggle.Enabled and store.hand.toolType == 'sword' then
                        bedwars.SwordController:swingSwordAtMouse(0.39)
                    end
                end
                
                local currentCPS
                if store.hand.toolType == 'block' and PlaceBlocksToggle.Enabled then
                    currentCPS = BlockCPS
                elseif store.hand.toolType == 'sword' and SwingSwordToggle.Enabled then
                    currentCPS = SwordCPS
                else
                    currentCPS = CPS 
                end
    
                task.wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
            until not AutoClicker.Enabled or (KeybindEnabled and KeybindMode.Value == 'Hold' and not KeybindActive)
        end)
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

    local function StartAutoClick()
        if AutoClicker.Enabled and not Thread and not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
            AutoClick()
        end
    end

    local function StopAutoClick()
        if Thread then
            task.cancel(Thread)
            Thread = nil
        end
    end

    local function ToggleKeybind()
        if KeybindMode.Value == 'Toggle' then
            KeybindHeld = not KeybindHeld
            KeybindActive = KeybindHeld
            
            if KeybindActive then
                StartAutoClick()
            else
                StopAutoClick()
            end
        end
    end
    
    AutoClicker = vape.Categories.Combat:CreateModule({
        Name = 'AutoClicker',
        Function = function(callback)
            if callback then
                if KeybindEnabled then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if UseMouseBind then
                            if input.UserInputType == CurrentMouseBind then
                                if KeybindMode.Value == 'Hold' then
                                    StartAutoClick()
                                elseif KeybindMode.Value == 'Toggle' then
                                    ToggleKeybind()
                                end
                            end
                        else
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                if input.KeyCode == CurrentKeybind then
                                    if KeybindMode.Value == 'Hold' then
                                        StartAutoClick()
                                    elseif KeybindMode.Value == 'Toggle' then
                                        ToggleKeybind()
                                    end
                                end
                            end
                        end
                    end))
    
                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if KeybindMode.Value == 'Hold' then
                            if UseMouseBind then
                                if input.UserInputType == CurrentMouseBind then
                                    StopAutoClick()
                                end
                            else
                                if input.UserInputType == Enum.UserInputType.Keyboard then
                                    if input.KeyCode == CurrentKeybind then
                                        StopAutoClick()
                                    end
                                end
                            end
                        end
                    end))
                else
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            AutoClick()
                        end
                    end))
    
                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
                            task.cancel(Thread)
                            Thread = nil
                        end
                    end))
    
                    if inputService.TouchEnabled then
                        pcall(function()
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
                                if Thread then
                                    task.cancel(Thread)
                                    Thread = nil
                                end
                            end))
                        end)
                    end
                end
                
                if KeybindEnabled and KeybindMode.Value == 'Hold' then
                    AutoClicker:Clean(runService.Heartbeat:Connect(function()
                        UpdateKeybindState()
                    end))
                end
            else
                StopAutoClick()
            end
        end,
        Tooltip = 'Clicks for you because your finger is too fucking slow'
    })
    
    KeybindToggle = AutoClicker:CreateToggle({
        Name = 'Use Keybind',
        Default = false,
        Tooltip = 'Use a keybind instead of mouse button to activate AutoClicker',
        Function = function(callback)
            KeybindEnabled = callback
            if KeybindList.Object then
                KeybindList.Object.Visible = callback and not UseMouseBind
            end
            if MouseBindToggle.Object then
                MouseBindToggle.Object.Visible = callback
            end
            if MouseBindList.Object then
                MouseBindList.Object.Visible = callback and UseMouseBind
            end
            if KeybindMode.Object then
                KeybindMode.Object.Visible = callback
            end
            
            if AutoClicker.Enabled then
                AutoClicker:Toggle()
                task.wait()
                AutoClicker:Toggle()
            end
        end
    })

    KeybindMode = AutoClicker:CreateDropdown({
        Name = 'Keybind Mode',
        List = {'Hold', 'Toggle'},
        Default = 'Hold',
        Darker = true,
        Visible = false,
        Tooltip = 'Hold: Activate while holding key\nToggle: Press to turn on/off',
        Function = function(value)
            KeybindHeld = false
            KeybindActive = false
            if AutoClicker.Enabled and KeybindEnabled then
                AutoClicker:Toggle()
                task.wait(0.1)
                AutoClicker:Toggle()
            end
        end
    })

    local keybindOptions = {
        "LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift",
        "Space", "CapsLock", "Tab", "E", "Q", "R", "F", "G", "X", "Z", "V", "B"
    }
    
    KeybindList = AutoClicker:CreateDropdown({
        Name = 'Keybind',
        List = keybindOptions,
        Default = "LeftAlt",
        Darker = true,
        Visible = false,
        Function = function(value)
            CurrentKeybind = Enum.KeyCode[value]
            KeybindHeld = false
            KeybindActive = false
            if AutoClicker.Enabled and KeybindEnabled then
                AutoClicker:Toggle()
                task.wait(0.1)
                AutoClicker:Toggle()
            end
        end
    })

    MouseBindToggle = AutoClicker:CreateToggle({
        Name = 'Use Mouse Button',
        Default = false,
        Tooltip = 'Use a mouse button instead of keyboard key',
        Function = function(callback)
            UseMouseBind = callback
            if KeybindList.Object then
                KeybindList.Object.Visible = KeybindEnabled and not callback
            end
            if MouseBindList.Object then
                MouseBindList.Object.Visible = KeybindEnabled and callback
            end
            
            KeybindHeld = false
            KeybindActive = false
            
            if AutoClicker.Enabled and KeybindEnabled then
                AutoClicker:Toggle()
                task.wait(0.1)
                AutoClicker:Toggle()
            end
        end
    })

    local mouseBindOptions = {
        "Right Click",
        "Middle Click"
    }
    
    local mouseBindEnumMap = {
        ["Right Click"] = Enum.UserInputType.MouseButton2,
        ["Middle Click"] = Enum.UserInputType.MouseButton3
    }
    
    MouseBindList = AutoClicker:CreateDropdown({
        Name = 'Mouse Button',
        List = mouseBindOptions,
        Default = "Right Click",
        Darker = true,
        Visible = false,
        Tooltip = 'Select which mouse button to use',
        Function = function(value)
            CurrentMouseBind = mouseBindEnumMap[value]
            KeybindHeld = false
            KeybindActive = false
            if AutoClicker.Enabled and KeybindEnabled then
                AutoClicker:Toggle()
                task.wait(0.1)
                AutoClicker:Toggle()
            end
        end
    })

    KeybindList.Object.Visible = false
    MouseBindToggle.Object.Visible = false
    MouseBindList.Object.Visible = false
    KeybindMode.Object.Visible = false
    
    PlaceBlocksToggle = AutoClicker:CreateToggle({
        Name = 'Place Blocks',
        Default = true,
        Tooltip = 'Automatically places blocks so you stop fucking up your builds',
        Function = function(callback)
            if BlockCPS.Object then
                BlockCPS.Object.Visible = callback
            end
        end
    })
    
    BlockCPS = AutoClicker:CreateTwoSlider({
        Name = 'Block CPS',
        Min = 1,
        Max = 12,
        DefaultMin = 12,
        DefaultMax = 12,
        Darker = true,
        Tooltip = 'How fast your lazy ass places blocks per second'
    })

    SwingSwordToggle = AutoClicker:CreateToggle({
        Name = 'Swing Sword',
        Default = true,
        Tooltip = 'Automatically swings your sword because your clicking is pathetic',
        Function = function(callback)
            if SwordCPS.Object then
                SwordCPS.Object.Visible = callback
            end
        end
    })

    SwordCPS = AutoClicker:CreateTwoSlider({
        Name = 'Sword CPS',
        Min = 1,
        Max = 9,
        DefaultMin = 7,
        DefaultMax = 7,
        Darker = true,
        Tooltip = 'How many times your sword swings per second (more than your tiny dick can handle)'
    })
end)

run(function()
    local KitRender
    local Players = game:GetService("Players")
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

    KitRender = vape.Categories.Utility:CreateModule({
        Name = "KitRender (5v5)",
        Tooltip = "Allows you to see everyone's kit during kit phase (5v5, Ranked)",
        Function = function(callback)    
            if callback then
                task.spawn(function()
                    local success, team2 = pcall(function()
                        return PlayerGui:WaitForChild("MatchDraftApp", 5):WaitForChild("DraftAppBackground", 5):WaitForChild("BodyContainer", 5):WaitForChild("Team2Column", 5)
                    end)
                    
                    if not success or not team2 then return end
                    
                    for _, child in ipairs(team2:GetDescendants()) do
                        if KitRender.Enabled then handleLabel(child) end
                    end
                    
                    KitRender:Clean(team2.DescendantAdded:Connect(function(child)
                        if KitRender.Enabled then handleLabel(child) end
                    end))
                end)
            else
                removeallkitrenders()
            end
        end
    })
end)

run(function()
    local oldranks = {}
    local activeLoops = {}
    local updateDebounce = {}
    
    KitRender = vape.Categories.Utility:CreateModule({
        Name = "KitRender (sqauds)",
        Function = function(callback)   
            if callback then
                task.spawn(function()
                    local teams = lplr.PlayerGui:WaitForChild("MatchDraftApp")
                    if teams then
                        local function setupKitRender(obj)
                            if obj.Name == "PlayerRender" and obj.Parent.Parent.Parent.Parent.Parent.Name == "MatchDraftTeamCardRow" then
                                local Rank = obj.Parent:FindFirstChild('3')
                                if not Rank then return end
                                
                                local userId = string.match(obj.Image, "id=(%d+)")
                                if not userId then return end
                                
                                obj:SetAttribute("AeroV4KitRenderUserID", tonumber(userId))
                                local id = tonumber(userId)
                                local plr = playersService:GetPlayerByUserId(id)
                                
                                if not plr then return end
                                
                                local loopKey = plr.UserId
                                
                                if activeLoops[loopKey] then
                                    activeLoops[loopKey] = nil
                                end
                                
                                local render = bedwars.BedwarsKitMeta[plr:GetAttribute("PlayingAsKits")] or bedwars.BedwarsKitMeta.none
                                if not oldranks[Rank] then
                                    oldranks[Rank] = Rank.Image
                                end
                                Rank.Image = render.renderImage
                                Rank:SetAttribute("AeroV4KitRenderWM", true)
                                
                                activeLoops[loopKey] = true
                                
                                KitRender:Clean(plr:GetAttributeChangedSignal("PlayingAsKits"):Connect(function()
                                    if not activeLoops[loopKey] or not KitRender.Enabled then return end
                                    
                                    local currentTick = tick()
                                    
                                    if not updateDebounce[loopKey] or (currentTick - updateDebounce[loopKey]) >= 0.1 then
                                        updateDebounce[loopKey] = currentTick
                                        
                                        if Rank and Rank.Parent then
                                            render = bedwars.BedwarsKitMeta[plr:GetAttribute("PlayingAsKits")] or bedwars.BedwarsKitMeta.none
                                            Rank.Image = render.renderImage
                                        else
                                            activeLoops[loopKey] = nil
                                            updateDebounce[loopKey] = nil
                                        end
                                    end
                                end))
                            end
                        end
                        
                        for i, obj in teams:GetDescendants() do
                            if KitRender.Enabled then
                                setupKitRender(obj)
                            end
                        end
                        
                        KitRender:Clean(teams.DescendantAdded:Connect(function(obj)
                            if KitRender.Enabled then
                                setupKitRender(obj)
                            end
                        end))
                    end
                end)
            else
                for key, _ in pairs(activeLoops) do
                    activeLoops[key] = nil
                end
                table.clear(updateDebounce)
                
                for i, v in lplr.PlayerGui.MatchDraftApp:GetDescendants() do
                    if v:GetAttribute("AeroV4KitRenderWM") then
                        if oldranks[v] then
                            v.Image = oldranks[v]
                        end
                        oldranks[v] = nil
                        v:SetAttribute("AeroV4KitRenderWM", nil)
                    end
                end
            end
        end,
        Tooltip = "Allows you to see everyone's kit during kit phase (squads ranked!)"
    })
end)
	
run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = os.clock()
					return false
				end
			else
				bedwars.SwordController.isClickingTooFast = old
			end
		end,
		Tooltip = 'Remove the CPS cap'
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
		Max = 30,
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
	local TriggerBot
	local CPS
	local ProjectileMode
	local ProjectileFireRate
	local ProjectileWaitDelay
	local ProjectileFirstPerson
	local rayParams = RaycastParams.new()
	local lastProjectileShot = 0
	local wasHoldingProjectile = false
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		local success = pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.02)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
		return success
	end
	
	local function isFirstPerson()
		return gameCamera.CFrame.Position.Magnitude - (gameCamera.Focus.Position).Magnitude < 1
	end
	
	local function isHoldingProjectile()
		if not entitylib.isAlive then return false end
		
		local currentSlot = store.inventory.hotbarSlot
		local slotItem = store.inventory.hotbar[currentSlot + 1]
		
		if slotItem and slotItem.item and slotItem.item.itemType then
			local itemMeta = bedwars.ItemMeta[slotItem.item.itemType]
			if itemMeta and itemMeta.projectileSource then
				local projectileSource = itemMeta.projectileSource
				if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
					return true
				end
			end
		end
		
		return false
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local doAttack = false
					local holdingProjectile = isHoldingProjectile()
					
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) and entitylib.isAlive then
						if ProjectileMode.Enabled and holdingProjectile then
							if ProjectileFirstPerson.Enabled and not isFirstPerson() then
								wasHoldingProjectile = false
							else
								if holdingProjectile and not wasHoldingProjectile then
									task.wait(ProjectileWaitDelay.Value)
									leftClick()
									lastProjectileShot = tick()
									wasHoldingProjectile = true
								elseif holdingProjectile then
									local currentTime = tick()
									if (currentTime - lastProjectileShot) >= ProjectileFireRate.Value then
										leftClick()
										lastProjectileShot = currentTime
									end
								else
									wasHoldingProjectile = false
								end
							end
						elseif store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
							rayParams.FilterDescendantsInstances = {lplr.Character}
	
							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								local limit = (attackRange)
								for _, ent in entitylib.List do
									doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end
	
							doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						else
							wasHoldingProjectile = false
						end
					end
	
					task.wait(doAttack and not holdingProjectile and 1 / CPS.GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	
	ProjectileMode = TriggerBot:CreateToggle({
		Name = 'Projectile Mode',
		Tooltip = 'Auto-shoots crossbow/bow when holding projectile weapon'
	})
	
	ProjectileFireRate = TriggerBot:CreateSlider({
		Name = 'Projectile Fire Rate',
		Min = 0.1,
		Max = 3,
		Default = 1.2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How fast to auto-fire (1.2 = every 1.2 seconds)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
	ProjectileWaitDelay = TriggerBot:CreateSlider({
		Name = 'Projectile Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
	ProjectileFirstPerson = TriggerBot:CreateToggle({
		Name = 'Projectile First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
end)

run(function()
	local ZoomUncapper
	local ZoomAmount = {Value = 500}
	local oldMaxZoom
	
	ZoomUncapper = vape.Categories.Render:CreateModule({
		Name = 'ZoomUncapper',
		Function = function(callback)		
			if callback then
				oldMaxZoom = lplr.CameraMaxZoomDistance
				lplr.CameraMaxZoomDistance = ZoomAmount.Value
			else
				if oldMaxZoom then
					lplr.CameraMaxZoomDistance = oldMaxZoom
				end
			end
		end,
		Tooltip = 'Uncaps camera zoom distance'
	})
	
	ZoomAmount = ZoomUncapper:CreateSlider({
		Name = 'Zoom Distance',
		Min = 20,
		Max = 600,
		Default = 100,
		Function = function(val)
			if ZoomUncapper.Enabled then
				lplr.CameraMaxZoomDistance = val
			end
		end
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
					local shouldReduce = rand:NextNumber(0, 100) <= Chance.Value
					
					if not shouldReduce then
						return old(root, mass, dir, knockback, ...)
					end
					
					local targetCheckPassed = true
					if TargetCheck.Enabled then
						local nearbyTargets = entitylib.EntityPosition({
							Range = 50,
							Part = 'RootPart',
							Players = true
						})
						targetCheckPassed = #nearbyTargets > 0
					end
					
					if targetCheckPassed then
						if knockback then
							knockback = {
								horizontal = knockback.horizontal or 1,
								vertical = knockback.vertical or 1
							}
							
							if Horizontal.Value ~= 100 then
								knockback.horizontal = knockback.horizontal * (Horizontal.Value / 100)
							end
							if Vertical.Value ~= 100 then
								knockback.vertical = knockback.vertical * (Vertical.Value / 100)
							end
						else
							knockback = {
								horizontal = Horizontal.Value / 100,
								vertical = Vertical.Value / 100
							}
						end
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
		Default = 100,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 100,
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
	
local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or vape.Modules.InfiniteFly.Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos.Y, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)
	
run(function()
	local FastBreak
	local Time
	local BedCheck
	
	local currentBlock = nil
	local oldHitBlock = nil
	
	local function isBed(block)
		if not block then return false end
		
		if collectionService:HasTag(block, 'bed') then
			return true
		end
		
		if block.Parent and collectionService:HasTag(block.Parent, 'bed') then
			return true
		end
		
		local blockName = block.Name:lower()
		if blockName:find('bed') then
			return true
		end
		
		return false
	end
	
	local function updateBreakSpeed()
		if not FastBreak.Enabled then return end
		
		if BedCheck.Enabled and currentBlock and isBed(currentBlock) then
			bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
		else
			bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
		end
	end
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				oldHitBlock = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
					
					if block and block.target and block.target.blockInstance then
						currentBlock = block.target.blockInstance
					else
						currentBlock = nil
					end
					
					updateBreakSpeed()
					
					return oldHitBlock(self, maid, raycastparams, ...)
				end
				
				task.spawn(function()
					repeat
						updateBreakSpeed()
						task.wait(0.1)
					until not FastBreak.Enabled
				end)
			else
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
				
				if oldHitBlock then
					bedwars.BlockBreaker.hitBlock = oldHitBlock
					oldHitBlock = nil
				end
				
				currentBlock = nil
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds',
		Function = function()
			updateBreakSpeed()
		end
	})
	
	BedCheck = FastBreak:CreateToggle({
		Name = 'Bed Check',
		Default = false,
		Tooltip = 'Use normal break speed when breaking beds',
		Function = function()
			updateBreakSpeed()
		end
	})
end)
	
local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local lastonground = false
	local MobileButtons
	local FlyAnywayProgressBar = {Enabled = false}
	local FlyAnywayProgressBarFrame
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0
	local mobileControls = {}
	local groundtime = nil
	local onground = false
	local flyCooldownActive = false
	local lastGroundTouchTime = 0
	local MAX_FLY_TIME = 2.5

	local function createMobileButton(name, position, icon)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.new(0, 60, 0, 60)
		button.Position = position
		button.BackgroundTransparency = 0.2
		button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		button.BorderSizePixel = 0
		button.Text = icon
		button.TextScaled = true
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Font = Enum.Font.SourceSansBold
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		return button
	end

	local function cleanupMobileControls()
		for _, control in pairs(mobileControls) do
			if control then
				control:Destroy()
			end
		end
		mobileControls = {}
	end

	local function updateProgressBar()
		if not FlyAnywayProgressBarFrame then return end
		
		if not entitylib.isAlive then
			FlyAnywayProgressBarFrame.Visible = false
			return
		end
		
		local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
		
		if flyAllowed then
			FlyAnywayProgressBarFrame.Frame.Size = UDim2.new(1, 0, 0, 20)
			FlyAnywayProgressBarFrame.TextLabel.Text = "∞"
			FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled
			return
		end
		
		local newray = getPlacedBlock(entitylib.character.HumanoidRootPart.Position + Vector3.new(0, (entitylib.character.Humanoid.HipHeight * -2) - 1, 0))
		onground = newray and true or false
		
		if onground then
			groundtime = nil
			flyCooldownActive = false
			lastGroundTouchTime = tick()
			
			FlyAnywayProgressBarFrame.Frame.Size = UDim2.new(1, 0, 0, 20)
			FlyAnywayProgressBarFrame.TextLabel.Text = string.format("%.1fs", MAX_FLY_TIME)
			FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
			
			if FlyAnywayProgressBarFrame.Frame:FindFirstChild("Tween") then
				FlyAnywayProgressBarFrame.Frame.Tween:Destroy()
			end
		else
			if not groundtime then
				groundtime = tick() + MAX_FLY_TIME
				flyCooldownActive = false
			end
			
			local timeLeft = math.max(0, groundtime - tick())
			local progress = timeLeft / MAX_FLY_TIME
			
			FlyAnywayProgressBarFrame.Frame.Size = UDim2.new(progress, 0, 0, 20)
			FlyAnywayProgressBarFrame.TextLabel.Text = string.format("%.1fs", timeLeft)
			FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
			
			if timeLeft <= 0 and not flyCooldownActive then
				flyCooldownActive = true
			end
		end
		
		lastonground = onground
	end

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end

				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))

				task.spawn(function()
					repeat
						task.wait()
						if entitylib.isAlive then
							entitylib.groundTick = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.groundTick
						end
					until not Fly.Enabled
				end)

				Fly:Clean(runService.RenderStepped:Connect(function(delta)
					if FlyAnywayProgressBar.Enabled and Fly.Enabled then
						updateProgressBar()
					end
				end))

				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
						local mass = (1.95 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = (tick() - entitylib.character.AirTime)
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
										root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))

				local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled
				local MobileEnabled = MobileButtons.Enabled or isMobile
				if MobileEnabled then
					local gui = Instance.new("ScreenGui")
					gui.Name = "FlyControls"
					gui.ResetOnSpawn = false
					gui.Parent = lplr.PlayerGui

					local upButton = createMobileButton("UpButton", UDim2.new(0.9, -70, 0.7, -140), "↑")
					local downButton = createMobileButton("DownButton", UDim2.new(0.9, -70, 0.7, -70), "↓")

					mobileControls.UpButton = upButton
					mobileControls.DownButton = downButton
					mobileControls.ScreenGui = gui

					upButton.Parent = gui
					downButton.Parent = gui

					Fly:Clean(upButton.MouseButton1Down:Connect(function()
						up = 1
					end))
					Fly:Clean(upButton.MouseButton1Up:Connect(function()
						up = 0
					end))
					Fly:Clean(downButton.MouseButton1Down:Connect(function()
						down = -1
					end))
					Fly:Clean(downButton.MouseButton1Up:Connect(function()
						down = 0
					end))
				end

				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							if not mobileControls.UpButton then
								up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
							end
						end))
					end)
				end
			else
				if FlyAnywayProgressBarFrame then
					FlyAnywayProgressBarFrame.Visible = false
				end
				lastonground = nil
				groundtime = nil
				flyCooldownActive = false
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
				cleanupMobileControls()
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	FlyAnywayProgressBar = Fly:CreateToggle({
		Name = "Progress Bar",
		Function = function(callback)
			if callback then
				FlyAnywayProgressBarFrame = Instance.new("Frame")
				FlyAnywayProgressBarFrame.AnchorPoint = Vector2.new(0.5, 0)
				FlyAnywayProgressBarFrame.Position = UDim2.new(0.5, 0, 1, -200)
				FlyAnywayProgressBarFrame.Size = UDim2.new(0.2, 0, 0, 20)
				FlyAnywayProgressBarFrame.BackgroundTransparency = 0.5
				FlyAnywayProgressBarFrame.BorderSizePixel = 0
				FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.new(0, 0, 0)
				FlyAnywayProgressBarFrame.Visible = false
				FlyAnywayProgressBarFrame.Parent = vape.gui
				
				local FlyAnywayProgressBarFrame2 = Instance.new("Frame")
				FlyAnywayProgressBarFrame2.Name = "Frame"
				FlyAnywayProgressBarFrame2.AnchorPoint = Vector2.new(0, 0)
				FlyAnywayProgressBarFrame2.Position = UDim2.new(0, 0, 0, 0)
				FlyAnywayProgressBarFrame2.Size = UDim2.new(1, 0, 0, 20)
				FlyAnywayProgressBarFrame2.BackgroundTransparency = 0
				FlyAnywayProgressBarFrame2.BorderSizePixel = 0
				FlyAnywayProgressBarFrame2.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
				FlyAnywayProgressBarFrame2.Visible = true
				FlyAnywayProgressBarFrame2.Parent = FlyAnywayProgressBarFrame
				
				local FlyAnywayProgressBartext = Instance.new("TextLabel")
				FlyAnywayProgressBartext.Name = "TextLabel"
				FlyAnywayProgressBartext.Text = "2.5s"
				FlyAnywayProgressBartext.Font = Enum.Font.Gotham
				FlyAnywayProgressBartext.TextStrokeTransparency = 0
				FlyAnywayProgressBartext.TextColor3 = Color3.new(0.9, 0.9, 0.9)
				FlyAnywayProgressBartext.TextSize = 20
				FlyAnywayProgressBartext.Size = UDim2.new(1, 0, 1, 0)
				FlyAnywayProgressBartext.BackgroundTransparency = 1
				FlyAnywayProgressBartext.Position = UDim2.new(0, 0, 0, 0)
				FlyAnywayProgressBartext.Parent = FlyAnywayProgressBarFrame
			else
				if FlyAnywayProgressBarFrame then 
					FlyAnywayProgressBarFrame:Destroy() 
					FlyAnywayProgressBarFrame = nil 
				end
			end
		end,
		Tooltip = "show amount of Fly time",
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
	MobileButtons = Fly:CreateToggle({
		Name = "Mobile Buttons",
		Function = function() 
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end
	})
end)
	
run(function()
	local Mode
	local Expand
	local AutoToggle
	local AutoToggleProjectiles
	local objects, set = {}
	local lastToolType = nil
	local autoToggleConnection = nil
	
	local projectileTools = {
		'bow',
		'crossbow',
		'snow_cannon',
		'tactical_crossbow',
		'turret',
		'headhunter_bow',
		'void_turret',
		'ice_turret',
		'light_bow'
	}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	local function isSword()
		if not store.hand or not store.hand.tool then return false end
		local toolType = store.hand.toolType
		return toolType == 'sword'
	end
	
	local function isProjectile()
		if not store.hand or not store.hand.tool then return false end
		local itemType = store.hand.itemType
		return table.find(projectileTools, itemType) ~= nil
	end
	
	local function isBlock()
		if not store.hand or not store.hand.tool then return false end
		local toolType = store.hand.toolType
		return toolType == 'block'
	end
	
	local function shouldDisableHitbox()
		if AutoToggleProjectiles.Enabled and isProjectile() then
			return true
		end
		if isBlock() then
			return true
		end
		return false
	end
	
	local function handleAutoToggle()
		if not AutoToggle.Enabled or Mode.Value ~= 'Player' then return end
		
		local shouldBeDisabled = shouldDisableHitbox()
		local currentState = not shouldBeDisabled
		
		if currentState ~= lastToolType then
			lastToolType = currentState
			
			if currentState then
				if not HitBoxes.Enabled then
					HitBoxes:Toggle()
				end
			else
				if HitBoxes.Enabled then
					HitBoxes:Toggle()
				end
			end
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
				
				if not AutoToggle.Enabled then
					lastToolType = nil
				end
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function(val)
			if AutoToggle then
				AutoToggle.Object.Visible = (val == 'Player')
			end
			if AutoToggleProjectiles then
				AutoToggleProjectiles.Object.Visible = (val == 'Player')
			end
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
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AutoToggle = HitBoxes:CreateToggle({
		Name = 'Auto Toggle',
		Default = false,
		Visible = false,
		Tooltip = 'Auto disables hitbox when holding blocks or projectiles',
		Function = function(callback)
			if callback then
				if autoToggleConnection then
					autoToggleConnection:Disconnect()
				end
				lastToolType = nil
				autoToggleConnection = runService.Heartbeat:Connect(handleAutoToggle)
				handleAutoToggle()
			else
				if autoToggleConnection then
					autoToggleConnection:Disconnect()
					autoToggleConnection = nil
				end
				lastToolType = nil
			end
		end
	})
	
	AutoToggleProjectiles = HitBoxes:CreateToggle({
		Name = 'Projectile Toggle',
		Default = true,
		Visible = false,
		Tooltip = 'Disables hitbox when holding projectile weapons to prevent ghosting',
		Function = function(callback)
			if AutoToggle.Enabled then
				handleAutoToggle()
			end
		end
	})
	
	task.spawn(function()
		repeat task.wait() until Mode.Value
		AutoToggle.Object.Visible = (Mode.Value == 'Player')
		AutoToggleProjectiles.Object.Visible = (Mode.Value == 'Player')
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
    local isFrozen = false
    local frozenStacks = 0
    local frozenCheckConnection
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
    
    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity)
    end)

    local function checkFrozenStatus()
        if not entitylib.isAlive then
            isFrozen = false
            frozenStacks = 0
            return
        end
        
        local char = entitylib.character.Character
        frozenStacks = 0
        isFrozen = false
        
        local coldStacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks") or char:GetAttribute("FreezeStacks")
        if coldStacks then
            frozenStacks = coldStacks
            isFrozen = frozenStacks >= FROZEN_THRESHOLD
            return
        end
        
        local statusEffects = char:GetAttribute("StatusEffects") or {}
        if type(statusEffects) == "table" then
            for effectName, stackCount in pairs(statusEffects) do
                local nameLower = tostring(effectName):lower()
                if nameLower:find("cold") or nameLower:find("frost") or nameLower:find("freeze") then
                    if type(stackCount) == "number" then
                        frozenStacks = stackCount
                        isFrozen = stackCount >= FROZEN_THRESHOLD
                        return
                    elseif stackCount then
                        frozenStacks = FROZEN_THRESHOLD
                        isFrozen = true
                        return
                    end
                end
            end
        end
        
        local hasIceBlock = char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell")
        local hasFullIceParticles = 0
        
        for _, child in pairs(char:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                local nameLower = child.Name:lower()
                if nameLower:find("ice") or nameLower:find("frost") or nameLower:find("snow") then
                    hasFullIceParticles = hasFullIceParticles + 1
                end
            end
        end
        
        if hasIceBlock or hasFullIceParticles >= 5 then
            frozenStacks = FROZEN_THRESHOLD
            isFrozen = true
            return
        end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid.WalkSpeed <= 2 then
                frozenStacks = FROZEN_THRESHOLD
                isFrozen = true
                return
            elseif humanoid.WalkSpeed < 10 then
                frozenStacks = math.floor(((16 - humanoid.WalkSpeed) / 14) * 10)
                frozenStacks = math.clamp(frozenStacks, 1, 10)
                isFrozen = frozenStacks >= FROZEN_THRESHOLD
                return
            end
        end
        
        local frostEffects = 0
        for _, child in pairs(char:GetDescendants()) do
            if child:IsA("BasePart") then
                if child.Material == Enum.Material.Ice or child.Material == Enum.Material.Snow then
                    frostEffects = frostEffects + 2
                end
                if child.Color.r < 0.4 and child.Color.b > 0.7 then
                    frostEffects = frostEffects + 1
                end
            elseif child:IsA("Decal") and (child.Texture:lower():find("ice") or child.Texture:lower():find("frost")) then
                frostEffects = frostEffects + 3
            end
        end
        
        if frostEffects >= 8 then
            frozenStacks = 9
            isFrozen = false
        elseif frostEffects >= 10 then
            frozenStacks = FROZEN_THRESHOLD
            isFrozen = true
        else
            frozenStacks = math.floor(frostEffects / 2)
        end
    end

    local function setupStackMonitoring()
        if not frozenCheckConnection then
            frozenCheckConnection = runService.Heartbeat:Connect(function()
                if not entitylib.isAlive then
                    frozenStacks = 0
                    isFrozen = false
                    return
                end
                
                local char = entitylib.character.Character
                local previousStacks = frozenStacks
                
                local newStacks = char:GetAttribute("ColdStacks") or 
                                 char:GetAttribute("FrostStacks") or 
                                 char:GetAttribute("FreezeStacks") or 
                                 char:GetAttribute("FROZEN_STACKS") or 0
                
                if newStacks > 0 then
                    frozenStacks = newStacks
                    isFrozen = frozenStacks >= FROZEN_THRESHOLD
                    return
                end
                
                checkFrozenStatus()
            end)
        end
    end

	local function optimizeHitData(selfpos, targetpos, delta)
		local direction = (targetpos - selfpos).Unit
		local distance = (selfpos - targetpos).Magnitude
		
		local optimizedSelfPos = selfpos
		local optimizedTargetPos = targetpos
		
		if distance > 16 then
			optimizedSelfPos = selfpos + (direction * 3.2)
			optimizedTargetPos = targetpos - (direction * 1.8)
		elseif distance > 14 then
			optimizedSelfPos = selfpos + (direction * 2.4)
			optimizedTargetPos = targetpos - (direction * 1.2)
		elseif distance > 12 then
			optimizedSelfPos = selfpos + (direction * 1.6)
			optimizedTargetPos = targetpos - (direction * 0.4)
		else
			optimizedSelfPos = selfpos + (direction * 0.8)
		end
		
		optimizedSelfPos = optimizedSelfPos + Vector3.new(0, 1.1, 0)
		optimizedTargetPos = optimizedTargetPos + Vector3.new(0, 0.9, 0)
		
		return optimizedSelfPos, optimizedTargetPos, direction
	end

    local function getOptimizedAttackTiming()
        local currentTime = tick()
        local baseDelay = 0.09
        
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

		if actualDistance > 13 and actualDistance <= 20 then
			local direction = (targetpos - selfpos).Unit
			
			local selfExtend, targetPull
			if actualDistance > 16 then
				selfExtend = 3.5
				targetPull = 2.0
			elseif actualDistance > 14 then
				selfExtend = 2.8
				targetPull = 1.5
			else
				selfExtend = 2.0
				targetPull = 0.8
			end
			
			attackTable.validate.selfPosition.value = selfpos + (direction * selfExtend) + Vector3.new(0, 0.6, 0)
			attackTable.validate.targetPosition.value = targetpos - (direction * targetPull) + Vector3.new(0, 0.4, 0)
			
			attackTable.validate.raycast = attackTable.validate.raycast or {}
			attackTable.validate.raycast.cameraPosition = attackTable.validate.raycast.cameraPosition or {}
			attackTable.validate.raycast.cursorDirection = attackTable.validate.raycast.cursorDirection or {}
			
			attackTable.validate.raycast.cameraPosition.value = selfpos + (direction * selfExtend) + Vector3.new(0, 1.8, 0)
			attackTable.validate.raycast.cursorDirection.value = direction
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
            checkFrozenStatus()
            
            if frozenStacks >= FROZEN_THRESHOLD then
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
            if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
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
                if SophiaCheck and SophiaCheck.Enabled then
                    checkFrozenStatus()
                    setupStackMonitoring()
                end
                
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
                        checkFrozenStatus()
                        
                        if isFrozen then
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
						elseif TargetPriority.Value == 'Both' then
							table.sort(allSwingTargets, function(a, b)
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
						elseif TargetPriority.Value == 'Both' then
							table.sort(allAttackTargets, function(a, b)
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
                                                end
                                            end
                                        end
                                    end

									local canHit = delta.Magnitude <= AttackRange.Value
									local extendedRangeCheck = delta.Magnitude <= (AttackRange.Value + 2)

									if not canHit and not extendedRangeCheck then continue end

									if delta.Magnitude > 13 and delta.Magnitude <= 15 then
										task.wait(0.01) 
									end

									if SyncHits.Enabled then
										local swingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
										local requiredDelay = math.max(swingSpeed * 0.65, 0.08) 
										
										if (tick() - swingCooldown) < requiredDelay then 
											continue 
										end
									end

                                    local actualRoot = v.Character.PrimaryPart
                                    if actualRoot then
                                        local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector

                                        local pos = selfpos
                                        local targetPos = actualRoot.Position

										if delta.Magnitude > 13 and delta.Magnitude < 15 then
											pos = pos + (dir * 0.4)
											targetPos = targetPos + Vector3.new(0, 0.2, 0)
										end

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
                if frozenCheckConnection then
                    frozenCheckConnection:Disconnect()
                    frozenCheckConnection = nil
                end
                frozenStacks = 0
                isFrozen = false
                
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
		List = {'Players First', 'NPCs First', 'Distance', 'Both'},
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
        Max = 240,
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
        Tooltip = 'Stops Killaura ONLY when completely frozen',
        Function = function(callback)
            if callback then
                if Killaura.Enabled then
                    setupStackMonitoring()
                    checkFrozenStatus()
                end
            else
                if frozenCheckConnection then
                    frozenCheckConnection:Disconnect()
                    frozenCheckConnection = nil
                end
                frozenStacks = 0
                isFrozen = false
            end
        end,
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
	local SophiaCheck
	local isFrozen = false
	local frozenStacks = 0
	local frozenCheckConnection
	local FROZEN_THRESHOLD = 10
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function clampRange(value)
		return math.min(value, 18) 
	end

	local function checkFrozenStatus()
		if not entitylib.isAlive then
			isFrozen = false
			frozenStacks = 0
			return
		end
		
		local char = entitylib.character.Character
		frozenStacks = 0
		isFrozen = false
		
		local coldStacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks") or char:GetAttribute("FreezeStacks")
		if coldStacks then
			frozenStacks = coldStacks
			isFrozen = frozenStacks >= FROZEN_THRESHOLD
			return
		end
		
		local statusEffects = char:GetAttribute("StatusEffects") or {}
		if type(statusEffects) == "table" then
			for effectName, stackCount in pairs(statusEffects) do
				local nameLower = tostring(effectName):lower()
				if nameLower:find("cold") or nameLower:find("frost") or nameLower:find("freeze") then
					if type(stackCount) == "number" then
						frozenStacks = stackCount
						isFrozen = stackCount >= FROZEN_THRESHOLD
						return
					elseif stackCount then
						frozenStacks = FROZEN_THRESHOLD
						isFrozen = true
						return
					end
				end
			end
		end
		
		local hasIceBlock = char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell")
		local hasFullIceParticles = 0
		
		for _, child in pairs(char:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				local nameLower = child.Name:lower()
				if nameLower:find("ice") or nameLower:find("frost") or nameLower:find("snow") then
					hasFullIceParticles = hasFullIceParticles + 1
				end
			end
		end
		
		if hasIceBlock or hasFullIceParticles >= 5 then
			frozenStacks = FROZEN_THRESHOLD
			isFrozen = true
			return
		end
		
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.WalkSpeed <= 2 then
				frozenStacks = FROZEN_THRESHOLD
				isFrozen = true
				return
			elseif humanoid.WalkSpeed < 10 then
				frozenStacks = math.floor(((16 - humanoid.WalkSpeed) / 14) * 10)
				frozenStacks = math.clamp(frozenStacks, 1, 10)
				isFrozen = frozenStacks >= FROZEN_THRESHOLD
				return
			end
		end
		
		local frostEffects = 0
		for _, child in pairs(char:GetDescendants()) do
			if child:IsA("BasePart") then
				if child.Material == Enum.Material.Ice or child.Material == Enum.Material.Snow then
					frostEffects = frostEffects + 2
				end
				if child.Color.r < 0.4 and child.Color.b > 0.7 then
					frostEffects = frostEffects + 1
				end
			elseif child:IsA("Decal") and (child.Texture:lower():find("ice") or child.Texture:lower():find("frost")) then
				frostEffects = frostEffects + 3
			end
		end
		
		if frostEffects >= 8 then
			frozenStacks = 9
			isFrozen = false
		elseif frostEffects >= 10 then
			frozenStacks = FROZEN_THRESHOLD
			isFrozen = true
		else
			frozenStacks = math.floor(frostEffects / 2)
		end
	end

	local function setupStackMonitoring()
		if not frozenCheckConnection then
			frozenCheckConnection = runService.Heartbeat:Connect(function()
				if not entitylib.isAlive then
					frozenStacks = 0
					isFrozen = false
					return
				end
				
				local char = entitylib.character.Character
				local previousStacks = frozenStacks
				
				local newStacks = char:GetAttribute("ColdStacks") or 
								 char:GetAttribute("FrostStacks") or 
								 char:GetAttribute("FreezeStacks") or 
								 char:GetAttribute("FROZEN_STACKS") or 0
				
				if newStacks > 0 then
					frozenStacks = newStacks
					isFrozen = frozenStacks >= FROZEN_THRESHOLD
					return
				end
				
				checkFrozenStatus()
			end)
		end
	end

	local function getAttackData()
		if SophiaCheck and SophiaCheck.Enabled then
			checkFrozenStatus()
			
			if frozenStacks >= FROZEN_THRESHOLD then
				return false
			end
		end

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
				if SophiaCheck and SophiaCheck.Enabled then
					checkFrozenStatus()
					setupStackMonitoring()
				end

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
					if SophiaCheck and SophiaCheck.Enabled then
						checkFrozenStatus()
						
						if isFrozen then
							Attacking = false
							store.KillauraTarget = nil
							task.wait(0.3)
							continue
						end
					end

					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = clampRange(SwingRange.Value), 
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
									Check = delta.Magnitude > clampRange(AttackRange.Value) and BoxSwingColor or BoxAttackColor 
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

								if delta.Magnitude > clampRange(AttackRange.Value) then continue end 
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

					task.wait(1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				if frozenCheckConnection then
					frozenCheckConnection:Disconnect()
					frozenCheckConnection = nil
				end
				frozenStacks = 0
				isFrozen = false

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
	SophiaCheck = Killaura:CreateToggle({
		Name = 'Sophia Check',
		Tooltip = 'Stops Killaura ONLY when completely frozen',
		Function = function(callback)
			if callback then
				if Killaura.Enabled then
					setupStackMonitoring()
					checkFrozenStatus()
				end
			else
				if frozenCheckConnection then
					frozenCheckConnection:Disconnect()
					frozenCheckConnection = nil
				end
				frozenStacks = 0
				isFrozen = false
			end
		end,
		Default = false
	})
end)
																																			
run(function()
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function launchProjectile(item, pos, proj, speed, dir)
		if not pos then return end
	
		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
		switchItem(item.tool, 0)
		task.wait(0.1)
		bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
		if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Client:Get(remotes.CannonAim):SendToServer({
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			launchProjectile(item, pos, 'fireball', 60, dir)
		end,
		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,
		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))
	
				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
	
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)
	
run(function() 
	local NoFall
	local DamageAccuracy

	local rayParams = RaycastParams.new()
	local rand = Random.new()

	NoFall = vape.Categories.Blatant:CreateModule({ 
		Name = 'No Fall',
		Function = function(callback)
			if callback then
				local tracked, extraGravity, velocity = 0, 0, 0
				NoFall:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = store.rootpart or entitylib.character.RootPart
						if root.AssemblyLinearVelocity.Y < -85 then
							rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayParams.CollisionGroup = root.CollisionGroup

							local rootSize = root.Size.Y / 2.5 + entitylib.character.HipHeight
							local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
							if not ray then
								local Failed = rand:NextNumber(0, 100) < (DamageAccuracy.Value)
								local velo = root.AssemblyLinearVelocity.Y

								if Failed then 
									root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, velo + 0.5, root.AssemblyLinearVelocity.Z)
								else
									root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -86, root.AssemblyLinearVelocity.Z)
								end

								velocity = velo
								root.CFrame = root.CFrame + Vector3.new(0, (Failed and -extraGravity or extraGravity) * dt, 0)
								extraGravity = extraGravity + (Failed and workspace.Gravity or -workspace.Gravity) * dt
							else
								velocity = root.AssemblyLinearVelocity.Y
							end
						else
							extraGravity = 0
						end
					end
				end))
			end
		end,
		Tooltip = 'Prevents you from taking fall dmg. Lower = less chances of fall dmg'
	})

	DamageAccuracy = NoFall:CreateSlider({
		Name = 'Damage Accuracy',
		Min = 0,
		Max = 100,
		Suffix = '%',
		Default = 0,
		Decimal = 5
	})
end)

run(function()
    local moduleData = {
        Connections = {},
        CurrentDuration = 1
    }
    
    local function updateAllPrompts(duration)
        for _, prompt in workspace:GetDescendants() do
            if prompt:IsA("ProximityPrompt") then
                prompt.HoldDuration = duration
            end
        end
    end
    
    local ProximityPromptDuration = vape.Categories.Utility:CreateModule({
        Name = 'Proximity Prompt Duration',
        Function = function(callback)
            
            if callback then
                for _, conn in ipairs(moduleData.Connections) do
                    if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                        conn:Disconnect()
                    end
                end
                moduleData.Connections = {}
                
                updateAllPrompts(moduleData.CurrentDuration)
                
                local connection = workspace.DescendantAdded:Connect(function(descendant)
                    if descendant:IsA("ProximityPrompt") then
                        task.wait(0.05)
                        descendant.HoldDuration = moduleData.CurrentDuration
                    end
                end)
                
                table.insert(moduleData.Connections, connection)
                
            else
                for _, conn in ipairs(moduleData.Connections) do
                    if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                        conn:Disconnect()
                    end
                end
                moduleData.Connections = {}
            end
        end,
        Tooltip = 'Set custom duration for all proximity prompts'
    })
    
    local ProximityDurationSlider = ProximityPromptDuration:CreateSlider({
        Name = 'Duration',
        Min = 0,
        Max = 10,
        Default = 1,
        Decimal = 100,
        Suffix = 's',
        Function = function(value)
            moduleData.CurrentDuration = value
            if ProximityPromptDuration.Enabled then
                updateAllPrompts(value)
            end
        end
    })
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
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
end)

run(function()
    local VanessaCharger
    local ChargeDelay
    local DelaySlider
    
    local oldGetChargeTime
    local lastChargeTime = 0
    
    VanessaCharger = vape.Categories.Blatant:CreateModule({
        Name = 'VanessaCharger',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat task.wait() until bedwars.TripleShotProjectileController
                    
                    if bedwars.TripleShotProjectileController then
                        oldGetChargeTime = bedwars.TripleShotProjectileController.getChargeTime
                        
                        bedwars.TripleShotProjectileController.getChargeTime = function(self)
                            local currentTime = tick()
                            if ChargeDelay.Enabled then
                                local delayAmount = DelaySlider.Value
                                if currentTime - lastChargeTime < delayAmount then
                                    return oldGetChargeTime(self)
                                end
                            end
                            
                            lastChargeTime = currentTime
                            return 0
                        end
                        
                        bedwars.TripleShotProjectileController.overchargeStartTime = tick()
                    end
                end)
            else
                if oldGetChargeTime and bedwars.TripleShotProjectileController then
                    bedwars.TripleShotProjectileController.getChargeTime = oldGetChargeTime
                end
                lastChargeTime = 0
            end
        end,
        Tooltip = 'Auto charges Vanessa triple shot\nMakes arrows instant charge'
    })
    
    ChargeDelay = VanessaCharger:CreateToggle({
        Name = 'Charge Delay',
        Default = true,
        Tooltip = 'Add delay between auto charges',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = VanessaCharger:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 5,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Visible = true,
        Tooltip = 'Delay in seconds between charges (0 = instant spam)'
    })
    
    task.spawn(function()
        repeat task.wait() until VanessaCharger.Object and VanessaCharger.Object.Parent
        task.wait(0.05)
        if ChargeDelay.Enabled and DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = true
        elseif DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false
        end
    end)
end)

run(function()
	local PAMode
	local TargetPart
	local Targets
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
	
	local AeroPATargetPriority
	local AeroPAHealthMode
	local AeroPAArmorMode
	local AeroPAChargePercent  

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}
	local old
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local function getArmorTier(player)
		if not player or not store.inventories[player] then return 0 end
		local inventory = store.inventories[player]
		local chestplate = inventory.armor and inventory.armor[5]
		if not chestplate or chestplate == 'empty' then return 1 end
		return table.find(armors, chestplate.itemType) or 1
	end
	
	local function getAeroPATarget(originPos)
		local validTargets = {}
		
		for _, ent in entitylib.List do
			if not Targets.Players.Enabled and ent.Player then continue end
			if not Targets.NPCs.Enabled and ent.NPC then continue end
			if not ent.Character or not ent.RootPart then continue end
			if not ent[TargetPart.Value] then continue end
			
			local distance = (ent[TargetPart.Value].Position - originPos).Magnitude
			if distance > Range.Value then continue end
			
			if Targets.Walls.Enabled then
				local ray = workspace:Raycast(originPos, (ent[TargetPart.Value].Position - originPos), rayCheck)
				if ray then continue end
			end
			
			local delta = (ent.RootPart.Position - originPos)
			local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
			if angle >= (math.rad(FOV.Value) / 2) then continue end
			
			table.insert(validTargets, ent)
		end
		
		if #validTargets == 0 then return nil end
		
		if AeroPATargetPriority.Value == 'Health' then
			table.sort(validTargets, function(a, b)
				local healthA = (a.Character:GetAttribute("Health") or a.Humanoid.Health)
				local healthB = (b.Character:GetAttribute("Health") or b.Humanoid.Health)
				
				if AeroPAHealthMode.Value == 'Lowest' then
					return healthA < healthB
				else 
					return healthA > healthB
				end
			end)
		elseif AeroPATargetPriority.Value == 'Armor' then
			table.sort(validTargets, function(a, b)
				local armorA = a.Player and getArmorTier(a.Player) or 1
				local armorB = b.Player and getArmorTier(b.Player) or 1
				
				if AeroPAArmorMode.Value == 'Weakest' then
					return armorA < armorB
				else 
					return armorA > armorB
				end
			end)
		end
		
		return validTargets[1]
	end
	
	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local CoreConnections = {}
	local cursorRenderConnection
	local lastGUIState = false
	
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	local function isFrostStaff(tool)
		if not tool then return false end
		local toolName = tool.Name or ""
		return toolName:find("frost_staff") or toolName == "FROST_STAFF_1" or toolName == "FROST_STAFF_2" or toolName == "FROST_STAFF_3"
	end
	
	local function getFrostStaffProjectile(toolName)
		if toolName:find("frost_staff_1") then
			return "frosty_snowball_1"
		elseif toolName:find("frost_staff_2") then
			return "frosty_snowball_2"
		elseif toolName:find("frost_staff_3") then
			return "frosty_snowball_3"
		end
		return "frosty_snowball_1"
	end
	
	local function getFrostStaffDamage(toolName)
		if toolName:find("frost_staff_1") then
			return 4  
		elseif toolName:find("frost_staff_2") then
			return 7  
		elseif toolName:find("frost_staff_3") then
			return 12 
		end
		return 4
	end
	
	local function getFrostStaffCooldown(toolName)
		if toolName:find("frost_staff_1") then
			return 0.2  
		elseif toolName:find("frost_staff_2") then
			return 0.18 
		elseif toolName:find("frost_staff_3") then
			return 0.16 
		end
		return 0.2
	end
	
	local function isFirstPerson()
		if not (lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")) then 
			return false 
		end
		
		local characterPos = lplr.Character.HumanoidRootPart.Position
		local cameraPos = gameCamera.CFrame.Position
		local distance = (characterPos - cameraPos).Magnitude
		
		return distance < 5 
	end
	
	local function shouldPAWork()
		if PAMode.Value ~= 'DesirePA' then return true end
		
		local inFirstPerson = isFirstPerson()
		
		if DesirePAWorkMode.Value == 'First Person' then
			return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then
			return not inFirstPerson
		elseif DesirePAWorkMode.Value == 'Both' then
			return true
		end
		
		return true
	end
	
	local function isGUIOpen()
		local guiLayers = {
			bedwars.UILayers.MAIN or 'Main',
			bedwars.UILayers.DIALOG or 'Dialog',
			bedwars.UILayers.POPUP or 'Popup'
		}
		
		for _, layerName in pairs(guiLayers) do
			if bedwars.AppController:isLayerOpen(layerName) then
				return true
			end
		end
		
		if bedwars.AppController:isAppOpen('BedwarsItemShopApp') then
			return true
		end
		
		if bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open then
			return true
		end
		
		return false
	end
	
	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then
			return false
		end
		
		local toolType = store.hand.toolType
		return toolType == 'bow' or toolType == 'crossbow'
	end
	
	local function hasFrostStaffEquipped()
		if not store.hand or not store.hand.tool then
			return false
		end
		return isFrostStaff(store.hand.tool)
	end
	
	local function shouldHideCursor()
		if PAMode.Value ~= 'DesirePA' or not DesirePAHideCursor.Enabled then return false end
		
		if DesirePACursorShowGUI.Enabled and isGUIOpen() then
			return false
		end
		
		if DesirePACursorLimitBow.Enabled then
			if not hasBowEquipped() and not hasFrostStaffEquipped() then
				return false
			end
		end
		
		local inFirstPerson = isFirstPerson()
		
		if DesirePACursorViewMode.Value == 'First Person' then
			return inFirstPerson
		elseif DesirePACursorViewMode.Value == 'Third Person' then
			return not inFirstPerson
		elseif DesirePACursorViewMode.Value == 'Both' then
			return true
		end
		
		return false
	end
	
	local function updateCursor()
		if shouldHideCursor() then
			pcall(function()
				inputService.MouseIconEnabled = false
			end)
		else
			pcall(function()
				inputService.MouseIconEnabled = true
			end)
		end
	end
	
	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local aeroprediction = {
		SolveTrajectory = function(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
			local eps = 1e-9
			
			local function isZero(d)
				return (d > -eps and d < eps)
			end

			local function cuberoot(x)
				return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
			end

			local function solveQuadric(c0, c1, c2)
				local s0, s1
				local p, q, D
				p = c1 / (2 * c0)
				q = c2 / c0
				D = p * p - q

				if isZero(D) then
					s0 = -p
					return s0
				elseif (D < 0) then
					return
				else
					local sqrt_D = math.sqrt(D)
					s0 = sqrt_D - p
					s1 = -sqrt_D - p
					return s0, s1
				end
			end

			local function solveCubic(c0, c1, c2, c3)
				local s0, s1, s2
				local num, sub
				local A, B, C
				local sq_A, p, q
				local cb_p, D

				if c0 == 0 then
					return solveQuadric(c1, c2, c3)
				end

				A = c1 / c0
				B = c2 / c0
				C = c3 / c0
				sq_A = A * A
				p = (1 / 3) * (-(1 / 3) * sq_A + B)
				q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
				cb_p = p * p * p
				D = q * q + cb_p

				if isZero(D) then
					if isZero(q) then
						s0 = 0
						num = 1
					else
						local u = cuberoot(-q)
						s0 = 2 * u
						s1 = -u
						num = 2
					end
				elseif (D < 0) then
					local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
					local t = 2 * math.sqrt(-p)
					s0 = t * math.cos(phi)
					s1 = -t * math.cos(phi + math.pi / 3)
					s2 = -t * math.cos(phi - math.pi / 3)
					num = 3
				else
					local sqrt_D = math.sqrt(D)
					local u = cuberoot(sqrt_D - q)
					local v = -cuberoot(sqrt_D + q)
					s0 = u + v
					num = 1
				end

				sub = (1 / 3) * A
				if (num > 0) then s0 = s0 - sub end
				if (num > 1) then s1 = s1 - sub end
				if (num > 2) then s2 = s2 - sub end

				return s0, s1, s2
			end

			local function solveQuartic(c0, c1, c2, c3, c4)
				local s0, s1, s2, s3
				local coeffs = {}
				local z, u, v, sub
				local A, B, C, D
				local sq_A, p, q, r
				local num

				A = c1 / c0
				B = c2 / c0
				C = c3 / c0
				D = c4 / c0

				sq_A = A * A
				p = -0.375 * sq_A + B
				q = 0.125 * sq_A * A - 0.5 * A * B + C
				r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

				if isZero(r) then
					coeffs[3] = q
					coeffs[2] = p
					coeffs[1] = 0
					coeffs[0] = 1

					local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
					num = #results
					s0, s1, s2 = results[1], results[2], results[3]
				else
					coeffs[3] = 0.5 * r * p - 0.125 * q * q
					coeffs[2] = -r
					coeffs[1] = -0.5 * p
					coeffs[0] = 1

					s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
					z = s0

					u = z * z - r
					v = 2 * z - p

					if isZero(u) then
						u = 0
					elseif (u > 0) then
						u = math.sqrt(u)
					else
						return
					end
					if isZero(v) then
						v = 0
					elseif (v > 0) then
						v = math.sqrt(v)
					else
						return
					end

					coeffs[2] = z - u
					coeffs[1] = q < 0 and -v or v
					coeffs[0] = 1

					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = #results
					s0, s1 = results[1], results[2]

					coeffs[2] = z + u
					coeffs[1] = q < 0 and v or -v
					coeffs[0] = 1

					if (num == 0) then
						local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
						num = num + #results2
						s0, s1 = results2[1], results2[2]
					end
					if (num == 1) then
						local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
						num = num + #results2
						s1, s2 = results2[1], results2[2]
					end
					if (num == 2) then
						local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
						num = num + #results2
						s2, s3 = results2[1], results2[2]
					end
				end

				sub = 0.25 * A
				if (num > 0) then s0 = s0 - sub end
				if (num > 1) then s1 = s1 - sub end
				if (num > 2) then s2 = s2 - sub end
				if (num > 3) then s3 = s3 - sub end

				return {s3, s2, s1, s0}
			end

			local disp = targetPos - origin
			local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
			local h, j, k = disp.X, disp.Y, disp.Z
			local l = -.5 * gravity

			if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
				local estTime = (disp.Magnitude / projectileSpeed)
				local origq = q
				for i = 1, 100 do
					q = origq - (.5 * playerGravity) * estTime
					local velo = targetVelocity * 0.016
					local ray = workspace:Raycast(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), 
						Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
					
					if ray then
						local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
						estTime = estTime - math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
						targetPos = newTarget
						j = (targetPos - origin).Y
						q = 0
						break
					else
						break
					end
				end
			end

			local solutions = solveQuartic(
				l*l,
				-2*q*l,
				q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
				2*j*q + 2*h*p + 2*k*r,
				j*j + h*h + k*k
			)
			
			if solutions then
				local posRoots = {}
				for _, v in solutions do
					if v > 0 then
						table.insert(posRoots, v)
					end
				end
				posRoots[1] = posRoots[1]

				if posRoots[1] then
					local t = posRoots[1]
					local d = (h + p*t)/t
					local e = (j + q*t - l*t*t)/t
					local f = (k + r*t)/t
					return origin + Vector3.new(d, e, f)
				end
			elseif gravity == 0 then
				local t = (disp.Magnitude / projectileSpeed)
				local d = (h + p*t)/t
				local e = (j + q*t - l*t*t)/t
				local f = (k + r*t)/t
				return origin + Vector3.new(d, e, f)
			end
		end
	}

	local function updateOutline(target)
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
		if target and TargetVisualiser.Enabled then
			targetOutline = Instance.new("Highlight")
			targetOutline.FillTransparency = 1
			targetOutline.OutlineColor = Color3.fromRGB(255, 0, 0)
			targetOutline.OutlineTransparency = 0
			targetOutline.Adornee = target.Character
			targetOutline.Parent = target.Character
		end
	end

	local function handlePlayerSelection()
		local function selectTarget(target)
			if not target then return end
			if target and target.Parent then
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
		end
		
		local con
		if isMobile then
			con = UserInputService.TouchTapInWorld:Connect(function(touchPos)
				if not hovering then updateOutline(nil); return end
				if not ProjectileAimbot.Enabled then pcall(function() con:Disconnect() end); updateOutline(nil); return end
				local ray = workspace.CurrentCamera:ScreenPointToRay(touchPos.X, touchPos.Y)
				local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
				if result and result.Instance then
					selectTarget(result.Instance)
				end
			end)
			table.insert(CoreConnections, con)
		end
	end
	
	local function updateOptionsVisibility()
		local mode = PAMode.Value
		
		if DesirePAHideCursor then
			DesirePAHideCursor.Object.Visible = (mode == 'DesirePA')
		end
		if DesirePACursorViewMode then
			DesirePACursorViewMode.Object.Visible = (mode == 'DesirePA')
		end
		if DesirePACursorLimitBow then
			DesirePACursorLimitBow.Object.Visible = (mode == 'DesirePA')
		end
		if DesirePACursorShowGUI then
			DesirePACursorShowGUI.Object.Visible = (mode == 'DesirePA')
		end
		if DesirePAWorkMode then
			DesirePAWorkMode.Object.Visible = (mode == 'DesirePA')
		end
		
		if AeroPATargetPriority then
			AeroPATargetPriority.Object.Visible = (mode == 'AeroPA')
		end
		if AeroPAHealthMode then
			AeroPAHealthMode.Object.Visible = (mode == 'AeroPA' and AeroPATargetPriority.Value == 'Health')
		end
		if AeroPAArmorMode then
			AeroPAArmorMode.Object.Visible = (mode == 'AeroPA' and AeroPATargetPriority.Value == 'Armor')
		end
		if AeroPAChargePercent then
			AeroPAChargePercent.Object.Visible = (mode == 'AeroPA')
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
				
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					hovering = true
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					
					local plr
					if selectedTarget and selectedTarget.Character and selectedTarget.Character.PrimaryPart and (selectedTarget.Character.PrimaryPart.Position - originPos).Magnitude <= Range.Value then
						plr = selectedTarget
					else
						if (PAMode.Value == 'AeroPA' and AeroPATargetPriority.Value ~= 'Distance') then
							plr = getAeroPATarget(originPos)
						else
							plr = entitylib.EntityMouse({
								Part = TargetPart.Value,
								Range = FOV.Value,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled,
								Origin = originPos
							})
						end
					end
					
					updateOutline(plr)
					
					if not shouldPAWork() then
						hovering = false
						return old(...)
					end
	
					if plr and plr.Character and plr[TargetPart.Value] and (plr[TargetPart.Value].Position - originPos).Magnitude <= Range.Value then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							hovering = false
							return old(...)
						end
	
						local isFrostStaffProjectile = false
						if projmeta and projmeta.projectile then
							isFrostStaffProjectile = projmeta.projectile:find("frosty_snowball") or false
						end
						
						local usingFrostStaff = false
						local frostStaffTier = 0
						if store.hand and store.hand.tool then
							usingFrostStaff = isFrostStaff(store.hand.tool)
							if usingFrostStaff then
								isFrostStaffProjectile = true
								if store.hand.tool.Name:find("frost_staff_2") then
									frostStaffTier = 2
								elseif store.hand.tool.Name:find("frost_staff_3") then
									frostStaffTier = 3
								else
									frostStaffTier = 1
								end
							end
						end

						local isLassoProjectile = projmeta.projectile == 'lasso'
						local isTurretProjectile = projmeta.projectile:find('turret') or projmeta.projectile:find('vulcan') or false

						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') and not isFrostStaffProjectile and not isLassoProjectile and not isTurretProjectile then
							hovering = false
							return old(...)
						end

						if table.find(Blacklist.ListEnabled, projmeta.projectile) then
							hovering = false
							return old(...)
						end
	
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
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

						if store.hand and store.hand.tool then
							if projmeta.projectile == 'lasso' then
								local targetPos = plr[TargetPart.Value].Position
								local targetVelocity = plr[TargetPart.Value].Velocity
								local distance = (targetPos - offsetpos).Magnitude
								local timeToReach = distance / projSpeed
								
								local predictedPos = targetPos + (targetVelocity * timeToReach)
								
								local horizontalOffset = Vector3.new(predictedPos.X - targetPos.X, 0, predictedPos.Z - targetPos.Z)
								if horizontalOffset.Magnitude > 10 then
									horizontalOffset = horizontalOffset.Unit * 10
									predictedPos = Vector3.new(
										targetPos.X + horizontalOffset.X,
										predictedPos.Y,
										targetPos.Z + horizontalOffset.Z
									)
								end
								
								local dropCompensation = 0.34 * gravity * (timeToReach * timeToReach)
								
								local distanceMultiplier = math.min(distance / 50, 2.5)  
								local finalArc = dropCompensation * distanceMultiplier
								
								predictedPos = predictedPos + Vector3.new(0, finalArc, 0)
								
								local newlook = CFrame.new(offsetpos, predictedPos)
								
								if targetinfo and targetinfo.Targets then
									targetinfo.Targets[plr] = tick() + 1
								end
								
								hovering = false
								return {
									initialVelocity = newlook.LookVector * projSpeed,
									positionFrom = offsetpos,
									deltaT = lifetime,
									gravitationalAcceleration = gravity,
									drawDurationSeconds = 5
								}
							end
							if isTurretProjectile then
								local targetPos = plr[TargetPart.Value].Position
								local targetVelocity = plr[TargetPart.Value].Velocity
								local distance = (targetPos - offsetpos).Magnitude
								local timeToReach = distance / projSpeed
								
								local predictedPos = targetPos + (targetVelocity * timeToReach)
								
								local dropCompensation = 0.5 * gravity * (timeToReach * timeToReach)
								predictedPos = predictedPos + Vector3.new(0, dropCompensation, 0)
								
								local newlook = CFrame.new(offsetpos, predictedPos)
								
								if targetinfo and targetinfo.Targets then
									targetinfo.Targets[plr] = tick() + 1
								end
								
								hovering = false
								return {
									initialVelocity = newlook.LookVector * projSpeed,
									positionFrom = offsetpos,
									deltaT = lifetime,
									gravitationalAcceleration = gravity,
									drawDurationSeconds = 5
								}
							end
							if usingFrostStaff then
								local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
								
								local targetVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity
								local jumpValue = plr.Jumping and (PAMode.Value == 'AeroPA' and 50 or 42.6) or nil
								
								local frostSpeed = 180 
								
								if frostStaffTier == 2 then
									frostSpeed = 190
								elseif frostStaffTier == 3 then
									frostSpeed = 200
								end
								
								local calc
								if PAMode.Value == 'AeroPA' then
									calc = aeroprediction.SolveTrajectory(newlook.p, frostSpeed, gravity, plr[TargetPart.Value].Position, targetVelocity, playerGravity, plr.HipHeight, jumpValue, rayCheck)
								else
									calc = prediction.SolveTrajectory(newlook.p, frostSpeed, gravity, plr[TargetPart.Value].Position, targetVelocity, playerGravity, plr.HipHeight, jumpValue, rayCheck)
								end
								
								if calc then
									if targetinfo and targetinfo.Targets then
										targetinfo.Targets[plr] = tick() + 1
									end
									
									local customDrawDuration = getFrostStaffCooldown(store.hand.tool.Name)
									local chargePercent = 100
									
									if PAMode.Value == 'AeroPA' and AeroPAChargePercent then
										chargePercent = AeroPAChargePercent.Value
										customDrawDuration = customDrawDuration * (chargePercent / 100)
									end
									
									hovering = false
									return {
										initialVelocity = CFrame.new(newlook.Position, calc).LookVector * frostSpeed,
										positionFrom = offsetpos,
										deltaT = 2,
										gravitationalAcceleration = gravity,
										drawDurationSeconds = customDrawDuration
									}
								end
							elseif store.hand.tool.Name:find("spellbook") then
								local targetPos = plr.RootPart.Position
								local selfPos = lplr.Character.PrimaryPart.Position
								local expectedTime = (selfPos - targetPos).Magnitude / 160
								targetPos = targetPos + (plr.RootPart.Velocity * expectedTime)
								hovering = false
								return {
									initialVelocity = (targetPos - selfPos).Unit * 160,
									positionFrom = offsetpos,
									deltaT = 2,
									gravitationalAcceleration = 1,
									drawDurationSeconds = 5
								}
							elseif store.hand.tool.Name:find("chakram") then
								local targetPos = plr.RootPart.Position
								local selfPos = lplr.Character.PrimaryPart.Position
								local expectedTime = (selfPos - targetPos).Magnitude / 80
								targetPos = targetPos + (plr.RootPart.Velocity * expectedTime)
								hovering = false
								return {
									initialVelocity = (targetPos - selfPos).Unit * 80,
									positionFrom = offsetpos,
									deltaT = 2,
									gravitationalAcceleration = 1,
									drawDurationSeconds = 5
								}
							end
						end
	
						local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						
						local targetVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity
						local jumpValue = plr.Jumping and (PAMode.Value == 'AeroPA' and 50 or 42.6) or nil
						
						local calc
						if PAMode.Value == 'AeroPA' then
							calc = aeroprediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, targetVelocity, playerGravity, plr.HipHeight, jumpValue, rayCheck)
						else
							calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, targetVelocity, playerGravity, plr.HipHeight, jumpValue, rayCheck)
						end
						
						if calc then
							if targetinfo and targetinfo.Targets then
								targetinfo.Targets[plr] = tick() + 1
							end
							
							local customDrawDuration = 5
							if PAMode.Value == 'AeroPA' and AeroPAChargePercent then
								local maxChargeTime = 1.1
								customDrawDuration = (AeroPAChargePercent.Value / 100) * maxChargeTime
							end
							
							hovering = false
							return {
								initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
								positionFrom = offsetpos,
								deltaT = lifetime,
								gravitationalAcceleration = gravity,
								drawDurationSeconds = customDrawDuration  
							}
						end
					end
	
					hovering = false
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
				if targetOutline then
					targetOutline:Destroy()
					targetOutline = nil
				end
				selectedTarget = nil
				for i,v in pairs(CoreConnections) do
					pcall(function() v:Disconnect() end)
				end
				table.clear(CoreConnections)
				
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				
				pcall(function()
					inputService.MouseIconEnabled = true
				end)
			end
		end,
		Tooltip = 'Unified projectile aimbot with multiple modes. AeroPA includes charge control.'
	})
	
	PAMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Mode',
		List = {'Vape', 'AeroPA', 'DesirePA'},
		Default = 'Vape',
		Tooltip = 'Select prediction algorithm',
		Function = function()
			updateOptionsVisibility()
		end
	})
	
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
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
		Default = true
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then
				Blacklist.Object.Visible = call
			end
		end
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'}
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
				pcall(function()
					inputService.MouseIconEnabled = true
				end)
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
	
	AeroPATargetPriority = ProjectileAimbot:CreateDropdown({
		Name = 'Target Priority',
		List = {'Distance', 'Health', 'Armor'},
		Default = 'Distance',
		Tooltip = 'How to prioritize targets',
		Function = function()
			updateOptionsVisibility()
		end
	})
	
	AeroPAHealthMode = ProjectileAimbot:CreateDropdown({
		Name = 'Health Mode',
		List = {'Lowest', 'Highest'},
		Default = 'Lowest',
		Darker = true,
		Tooltip = 'Target lowest or highest health players'
	})
	
	AeroPAArmorMode = ProjectileAimbot:CreateDropdown({
		Name = 'Armor Mode',
		List = {'Weakest', 'Strongest'},
		Default = 'Weakest',
		Darker = true,
		Tooltip = 'Target weakest or strongest armored players'
	})
	
	AeroPAChargePercent = ProjectileAimbot:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
		Darker = true,
		Tooltip = 'Control bow charge percentage (affects damage): 100% = full damage, 50% = half damage, etc.'
	})
	
	updateOptionsVisibility()
	
	vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
		if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled and PAMode.Value == 'DesirePA' then
			updateCursor()
		end
	end))
end)
	
local function isFirstPerson()
	if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return false end
	return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

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
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function hasArrows()
		local arrowItem = getItem('arrow')
		return arrowItem and arrowItem.amount > 0
	end
	
	local function getBows()
		local bows = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType then
				local itemMeta = bedwars.ItemMeta[v.item.itemType]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
						table.insert(bows, i - 1)
					end
				end
			end
		end
		return bows
	end
	
	local function getSwordSlot()
		for i, v in store.inventory.hotbar do
			if v.item and bedwars.ItemMeta[v.item.itemType] then
				local meta = bedwars.ItemMeta[v.item.itemType]
				if meta.sword then
					return i - 1
				end
			end
		end
		return nil
	end
	
	local function hasValidTarget()
		if KillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			if not entitylib.isAlive then return false end
			
			local myPos = entitylib.character.RootPart.Position
			local myLook = entitylib.character.RootPart.CFrame.LookVector
			
			for _, entity in entitylib.List do
				if entity.Player == lplr then continue end
				if not entity.Character then continue end
				if not entity.RootPart then continue end
				
				if entity.Player then
					if lplr:GetAttribute('Team') == entity.Player:GetAttribute('Team') then
						continue
					end
				else
					if not entity.Targetable then
						continue
					end
				end
				
				local distance = (entity.RootPart.Position - myPos).Magnitude
				if distance > AutoShootRange.Value then continue end
				
				local toTarget = (entity.RootPart.Position - myPos).Unit
				local dot = myLook:Dot(toTarget)
				local angle = math.acos(dot)
				local fovRad = math.rad(AutoShootFOV.Value)
				
				if angle <= fovRad then
					return true
				end
			end
			
			return false
		end
	end
	
	local AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				autoShootEnabled = true
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
								for _, v in bows do
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
						task.wait(0.1)
						if autoShootEnabled and not _G.autoShootLock then
							if not hasArrows() then
								continue
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									continue
								end
							else
								if not hasValidTarget() then
									continue
								end
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoShootTime) >= AutoShootInterval.Value then
								local bows = getBows()
								local swordSlot = getSwordSlot()
								
								if #bows > 0 then
									_G.autoShootLock = true
									lastAutoShootTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for _, bowSlot in bows do
										if hotbarSwitch(bowSlot) then
											task.wait(AutoShootSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
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
end)

run(function()
	local AutoGloopInterval
	local AutoGloopSwitchSpeed
	local AutoGloopWaitDelay
	local AutoGloopRange
	local AutoGloopFOV
	local lastAutoGloopTime = 0
	local autoGloopEnabled = false
	local GloopKillauraTargetCheck
	local FirstPersonCheck
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function hasGloop()
		local gloopItem = getItem('glue_projectile')
		return gloopItem and gloopItem.amount > 0
	end
	
	local function getGloopSlots()
		local gloops = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType then
				if v.item.itemType == 'glue_projectile' then
					table.insert(gloops, i - 1)
				end
			end
		end
		return gloops
	end
	
	local function getSwordSlot()
		for i, v in store.inventory.hotbar do
			if v.item and bedwars.ItemMeta[v.item.itemType] then
				local meta = bedwars.ItemMeta[v.item.itemType]
				if meta.sword then
					return i - 1
				end
			end
		end
		return nil
	end
	
	local function getClosestTargetDistance()
		if not entitylib.isAlive then return math.huge end
		
		local myPos = entitylib.character.RootPart.Position
		local myLook = entitylib.character.RootPart.CFrame.LookVector
		local closestDist = math.huge
		
		for _, entity in entitylib.List do
			if entity.Player == lplr then continue end
			if not entity.Character then continue end
			if not entity.RootPart then continue end
			
			if entity.Player then
				if lplr:GetAttribute('Team') == entity.Player:GetAttribute('Team') then
					continue
				end
			else
				if not entity.Targetable then
					continue
				end
			end
			
			local distance = (entity.RootPart.Position - myPos).Magnitude
			if distance > AutoGloopRange.Value then continue end
			
			local toTarget = (entity.RootPart.Position - myPos).Unit
			local dot = myLook:Dot(toTarget)
			local angle = math.acos(dot)
			local fovRad = math.rad(AutoGloopFOV.Value)
			
			if angle <= fovRad then
				closestDist = math.min(closestDist, distance)
			end
		end
		
		return closestDist
	end
	
	local function hasValidTarget()
		if GloopKillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			return getClosestTargetDistance() <= AutoGloopRange.Value
		end
	end
	
	local AutoGloop = vape.Categories.Utility:CreateModule({
		Name = 'AutoGloop',
		Function = function(callback)
			if callback then
				autoGloopEnabled = true
				
				task.spawn(function()
					repeat
						task.wait(0.1)
						if autoGloopEnabled and not _G.autoShootLock then
							if not hasGloop() then
								continue
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if not hasValidTarget() then
								continue
							end
							
							local closestDist = getClosestTargetDistance()
							if closestDist > 14 then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoGloopTime) >= AutoGloopInterval.Value then
								local gloops = getGloopSlots()
								local swordSlot = getSwordSlot()
								
								if #gloops > 0 then
									_G.autoShootLock = true
									lastAutoGloopTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for _, gloopSlot in gloops do
										if hotbarSwitch(gloopSlot) then
											task.wait(AutoGloopSwitchSpeed.Value)
											task.wait(AutoGloopWaitDelay.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoGloopEnabled
				end)
			else
				autoGloopEnabled = false
			end
		end,
		Tooltip = 'Automatically throws gloop at close range enemies (under 12 studs)'
	})
	
	AutoGloopInterval = AutoGloop:CreateSlider({
		Name = 'Throw Interval',
		Min = 0.1,
		Max = 16,
		Default = 0.8,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to throw gloop'
	})
	
	AutoGloopSwitchSpeed = AutoGloop:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and throwing (lower = faster)'
	})
	
	AutoGloopWaitDelay = AutoGloop:CreateSlider({
		Name = 'Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before throwing (helps prevent ghosting)'
	})
	
	AutoGloopRange = AutoGloop:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to detect targets'
	})
	
	AutoGloopFOV = AutoGloop:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	GloopKillauraTargetCheck = AutoGloop:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only throw gloop when Killaura has a target'
	})
	
	FirstPersonCheck = AutoGloop:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local AutoFireInterval
	local AutoFireWaitDelay
	local autoFireEnabled = false
	local lastAutoFireTime = 0
	local wasHoldingBow = false
	local KillauraTargetCheck
	local FirstPersonCheck
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function isFirstPerson()
		return gameCamera.CFrame.Position.Magnitude - (gameCamera.Focus.Position).Magnitude < 1
	end
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function isHoldingBow()
		if not entitylib.isAlive then return false end
		
		local currentSlot = store.inventory.hotbarSlot
		local slotItem = store.inventory.hotbar[currentSlot + 1]
		
		if slotItem and slotItem.item and slotItem.item.itemType then
			local itemMeta = bedwars.ItemMeta[slotItem.item.itemType]
			if itemMeta and itemMeta.projectileSource then
				local projectileSource = itemMeta.projectileSource
				if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
					return true
				end
			end
		end
		
		return false
	end
	
	local function hasValidTarget()
		if KillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			return true
		end
	end
	
	local AutoFire = vape.Categories.Utility:CreateModule({
		Name = 'AutoFire',
		Function = function(callback)
			if callback then
				autoFireEnabled = true
				wasHoldingBow = false
				
				task.spawn(function()
					repeat
						task.wait(0.05)
						if autoFireEnabled and entitylib.isAlive then
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if not hasValidTarget() then
								continue
							end
							
							local holdingBow = isHoldingBow()
							
							if holdingBow and not wasHoldingBow then
								task.wait(AutoFireWaitDelay.Value)
								leftClick()
								lastAutoFireTime = tick()
								wasHoldingBow = true
							elseif holdingBow then
								local currentTime = tick()
								if (currentTime - lastAutoFireTime) >= AutoFireInterval.Value then
									task.wait(AutoFireWaitDelay.Value)
									lastAutoFireTime = currentTime
									leftClick()
								end
							else
								wasHoldingBow = false
							end
						end
					until not autoFireEnabled
				end)
			else
				autoFireEnabled = false
				wasHoldingBow = false
			end
		end,
		Tooltip = 'Automatically clicks when holding a bow/crossbow/headhunter - shoots instantly on pull out'
	})
	
	AutoFireInterval = AutoFire:CreateSlider({
		Name = 'Fire Rate',
		Min = 0.1,
		Max = 3,
		Default = 1.2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How fast to auto-fire (1.2 = every 1.2 seconds)'
	})
	
	AutoFireWaitDelay = AutoFire:CreateSlider({
		Name = 'Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)'
	})
	
	KillauraTargetCheck = AutoFire:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only auto-fire when Killaura has a target'
	})
	
	FirstPersonCheck = AutoFire:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local HandCheck
	local FireSpeed
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					local holdingCrossbow = store.hand and store.hand.tool and store.hand.tool.Name:find('crossbow')
					
					if HandCheck.Enabled and not holdingCrossbow then
						task.wait(0.1)
						continue
					end
					
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {workspace.Map}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
										local switched = switchItem(item.tool)
	
										task.spawn(function()
											local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											
											if holdingCrossbow then
												local AnimationType = bedwars.AnimationType
												if item.tool.Name:find('crossbow') then
													bedwars.GameAnimationUtil:playAnimation(lplr, AnimationType.CROSSBOW_FIRE)
												elseif item.tool.Name:find('bow') then
													bedwars.GameAnimationUtil:playAnimation(lplr, AnimationType.BOW_FIRE)
												end
											else
												local shootAnim = bedwars.ItemMeta[item.tool.Name].thirdPerson and bedwars.ItemMeta[item.tool.Name].thirdPerson.shootAnimation
												if shootAnim then
													bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
												end
											end
											
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + (itemMeta.fireDelaySec / FireSpeed.Value)
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HandCheck = ProjectileAura:CreateToggle({
		Name = 'Hand Check',
		Default = false,
		Tooltip = 'Only shoot when holding a crossbow'
	})
	FireSpeed = ProjectileAura:CreateSlider({
		Name = 'Fire Speed',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Lower = faster, Higher = slower. 1.0 = normal speed'
	})
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
    local AutoChargeBow = {Enabled = false}
    local old
    
    AutoChargeBow = vape.Categories.Utility:CreateModule({
        Name = 'AutoChargeBow',
        Function = function(callback)
            if callback then
                old = bedwars.ProjectileController.calculateImportantLaunchValues
                bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
                    local self, projmeta, worldmeta, origin, shootpos = ...
                    
                    if projmeta.projectile:find('arrow') then
                        local pos = shootpos or self:getLaunchPosition(origin)
                        if not pos then
                            return old(...)
                        end
                        
                        local meta = projmeta:getProjectileMeta()
                        local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
                        local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
                        local projSpeed = (meta.launchVelocity or 100)
                        local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
                        
                        local camera = workspace.CurrentCamera
                        local mouse = lplr:GetMouse()
                        local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
                        
                        local targetPoint = unitRay.Origin + (unitRay.Direction * 1000)
                        local aimDirection = (targetPoint - offsetpos).Unit
                        
                        local newlook = CFrame.new(offsetpos, targetPoint) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
                        local finalDirection = (targetPoint - newlook.Position).Unit
                        
                        return {
                            initialVelocity = finalDirection * projSpeed,
                            positionFrom = offsetpos,
                            deltaT = lifetime,
                            gravitationalAcceleration = gravity,
                            drawDurationSeconds = 5
                        }
                    end
                    
                    return old(...)
                end
            else
                bedwars.ProjectileController.calculateImportantLaunchValues = old
            end
        end,
        Tooltip = 'Automatically charges your bow to full power with trajectory line preview'
    })
end)

run(function()
    local moduleConnectionList = {}
    local hiddenModels = {}
    local hiddenParticles = {}
    local originalProperties = {}
    
    local Aerov4TitanRemover = vape.Categories.BoostFPS:CreateModule({
        Name = 'Titan Remover',
        Function = function(callback)
            if callback then
                for _, conn in ipairs(moduleConnectionList) do
                    if conn and type(conn) == "userdata" and conn.Connected then
                        conn:Disconnect()
                    end
                end
                moduleConnectionList = {}
                
                hiddenModels = {}
                hiddenParticles = {}
                originalProperties = {}

                local function hideTitanAssets()
                    for _, model in workspace:GetDescendants() do
                        if model:IsA("Model") then
                            local modelName = model.Name:lower()
                            
                            if modelName:find("titan") or modelName:find("golem") or modelName:find("bhaa") or 
                               modelName == "titan" or modelName == "spiritgolem" or modelName == "voidgolem" then
                                
                                if model.Parent and not hiddenModels[model] then
                                    hiddenModels[model] = true
                                    
                                    for _, part in model:GetDescendants() do
                                        if part:IsA("BasePart") then
                                            originalProperties[part] = {
                                                Transparency = part.Transparency,
                                                CanCollide = part.CanCollide,
                                                CastShadow = part.CastShadow,
                                                CanQuery = part.CanQuery
                                            }
                                            
                                            part.Transparency = 1
                                            part.CanCollide = false
                                            part.CastShadow = false
                                            part.CanQuery = false
                                            
                                        elseif part:IsA("Decal") or part:IsA("Texture") then
                                            originalProperties[part] = {
                                                Transparency = part.Transparency
                                            }
                                            part.Transparency = 1
                                            
                                        elseif part:IsA("ParticleEmitter") then
                                            originalProperties[part] = {
                                                Enabled = part.Enabled
                                            }
                                            part.Enabled = false
                                            hiddenParticles[part] = true
                                            
                                        elseif part:IsA("SurfaceGui") or part:IsA("BillboardGui") then
                                            originalProperties[part] = {
                                                Enabled = part.Enabled
                                            }
                                            part.Enabled = false
                                        end
                                    end
                                end
                            end
                        elseif model:IsA("ParticleEmitter") then
                            local parentName = model.Parent and model.Parent.Name:lower() or ""
                            if parentName:find("titan") or parentName:find("golem") or parentName:find("bhaa") or 
                               parentName:find("effect") and (parentName:find("slam") or parentName:find("shockwave")) then
                                
                                if not hiddenParticles[model] then
                                    originalProperties[model] = {
                                        Enabled = model.Enabled
                                    }
                                    hiddenParticles[model] = true
                                    model.Enabled = false
                                end
                            end
                        end
                    end
                    
                    local function hideBossBars()
                        for _, screenGui in game:GetService("CoreGui"):GetDescendants() do
                            if screenGui:IsA("ScreenGui") and (screenGui.Name:find("BossBar") or screenGui.Name:find("Boss")) then
                                if not originalProperties[screenGui] then
                                    originalProperties[screenGui] = {
                                        Enabled = screenGui.Enabled
                                    }
                                end
                                screenGui.Enabled = false
                            end
                        end
                        
                        local player = game:GetService("Players").LocalPlayer
                        if player and player:FindFirstChild("PlayerGui") then
                            for _, screenGui in player.PlayerGui:GetDescendants() do
                                if screenGui:IsA("ScreenGui") and (screenGui.Name:find("BossBar") or screenGui.Name:find("Boss")) then
                                    if not originalProperties[screenGui] then
                                        originalProperties[screenGui] = {
                                            Enabled = screenGui.Enabled
                                        }
                                    end
                                    screenGui.Enabled = false
                                end
                            end
                        end
                    end
                    
                    pcall(hideBossBars)
                end

                hideTitanAssets()
                
                local lastCheck = tick()
                local heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
                    if tick() - lastCheck > 0.5 then
                        hideTitanAssets()
                        lastCheck = tick()
                    end
                end)
                table.insert(moduleConnectionList, heartbeatConnection)
                
                local descendantConnection = workspace.DescendantAdded:Connect(function(descendant)
                    if descendant:IsA("Model") then
                        local name = descendant.Name:lower()
                        if name:find("titan") or name:find("golem") or name:find("bhaa") then
                            task.wait(0.1)
                            hideTitanAssets()
                        end
                    elseif descendant:IsA("ParticleEmitter") then
                        local parentName = descendant.Parent and descendant.Parent.Name:lower() or ""
                        if parentName:find("titan") or parentName:find("golem") or parentName:find("bhaa") then
                            if not originalProperties[descendant] then
                                originalProperties[descendant] = {
                                    Enabled = descendant.Enabled
                                }
                            end
                            descendant.Enabled = false
                        end
                    elseif descendant:IsA("Sound") then
                        local soundName = descendant.Name:lower()
                        if soundName:find("titan") or soundName:find("golem") or soundName:find("bhaa") then
                            if not originalProperties[descendant] then
                                originalProperties[descendant] = {
                                    Volume = descendant.Volume
                                }
                            end
                            descendant.Volume = 0
                        end
                    end
                end)
                table.insert(moduleConnectionList, descendantConnection)
                
                task.spawn(function()
                    local collectionService = game:GetService("CollectionService")
                    local tagsToMonitor = {"Bhaa", "spiritGolem", "GolemBoss", "Titan"}
                    
                    for _, tag in tagsToMonitor do
                        local success, result = pcall(function()
                            return collectionService:GetTagged(tag)
                        end)
                        
                        if success then
                            for _, obj in result do
                                if obj:IsA("Model") and not hiddenModels[obj] then
                                    task.wait(0.1)
                                    hideTitanAssets()
                                end
                            end
                            
                            local tagAddedConnection = collectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
                                if obj:IsA("Model") then
                                    task.wait(0.1)
                                    hideTitanAssets()
                                end
                            end)
                            table.insert(moduleConnectionList, tagAddedConnection)
                        end
                    end
                end)
                
            else
                for _, conn in ipairs(moduleConnectionList) do
                    if conn and type(conn) == "userdata" and conn.Connected then
                        pcall(function()
                            conn:Disconnect()
                        end)
                    end
                end
                moduleConnectionList = {}
                
                for object, properties in pairs(originalProperties) do
                    if object and object.Parent then
                        pcall(function()
                            for prop, value in pairs(properties) do
                                if object[prop] ~= nil then
                                    object[prop] = value
                                end
                            end
                        end)
                    end
                end
                
                hiddenModels = {}
                hiddenParticles = {}
                originalProperties = {}
            end
        end,
        Tooltip = 'Removes Titan/Bhaa models and effects for FPS boost'
    })
end)
	
run(function()
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
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
					if entitylib.isAlive and not Fly.Enabled and not InfiniteFly.Enabled and not LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
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
				end))
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 30,
		Default = 30,
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
end)
	
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
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
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
    local Notify = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    
    local ESPKits = {
        alchemist = {'alchemist_ingedients', 'wild_flower', 'ingredients'},
        beekeeper = {'bee', 'bee', 'bees'},
        ghost_catcher = {'ghost', 'ghost_orb', 'ghosts'},
        sheep_herder = {'SheepModel', 'purple_hay_bale', 'sheep'},
        sorcerer = {'alchemy_crystal', 'alchemy_crystal', 'crystals'},
        black_market_trader = {'shadow_coin', 'shadow_coin', 'coins'},
        miner = {'petrified-player', 'stone', 'petrified players'},
        necromancer = {'Gravestone', 'gravestone', 'gravestones'},
        battery = {'Open', 'battery', 'batteries'}
    }
    
    local kitNames = {
        alchemist = "Alchemist",
        beekeeper = "Beekeeper",
        bigman = "Bigman",
        ghost_catcher = "Ghost Catcher",
        sheep_herder = "Sheep Herder",
        sorcerer = "Sorcerer",
        black_market_trader = "Black Market Trader",
        miner = "Miner",
        necromancer = "Necromancer",
        battery = "Battery"
    }
    
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1
    local minerCache = {}
    local gravestoneCache = {}
    local batteryCache = {}
    
    local function isOnMyTeam(petrifiedModel)
        if not petrifiedModel then return false end
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = petrifiedModel:GetAttribute('Team')
        
        if not theirTeam or not myTeam then return true end
        
        return theirTeam == myTeam
    end
    
    local function sendNotification(itemName, count)
        notif("Kit ESP", string.format("%d %s spawned", count, itemName), 3)
    end
    
    local function sendMinerNotification(playerName, count)
        if count > 1 then
            notif("Kit ESP", string.format("%d petrified players spawned", count), 3)
        else
            notif("Kit ESP", string.format("Petrified player: %s", playerName), 3)
        end
    end
    
    local function processSpawnQueue()
        for kit, items in pairs(spawnQueue) do
            if #items > 0 then
                local currentTime = tick()
                if currentTime - lastNotification >= notificationCooldown then
                    if kit == 'miner' then
                        local playerNames = {}
                        for _, item in ipairs(items) do
                            if item.playerName then
                                table.insert(playerNames, item.playerName)
                            end
                        end
                        if #playerNames > 0 then
                            sendMinerNotification(playerNames[1], #playerNames)
                        end
                    else
                        sendNotification(ESPKits[kit][3], #items)
                    end
                    lastNotification = currentTime
                    spawnQueue[kit] = {}
                else
                    task.delay(notificationCooldown - (currentTime - lastNotification), function()
                        if spawnQueue[kit] and #spawnQueue[kit] > 0 then
                            if kit == 'miner' then
                                local playerNames = {}
                                for _, item in ipairs(spawnQueue[kit]) do
                                    if item.playerName then
                                        table.insert(playerNames, item.playerName)
                                    end
                                end
                                if #playerNames > 0 then
                                    sendMinerNotification(playerNames[1], #playerNames)
                                end
                            else
                                sendNotification(ESPKits[kit][3], #spawnQueue[kit])
                            end
                            spawnQueue[kit] = {}
                        end
                    end)
                end
            end
        end
    end
    
    local function getProperImage(v, icon)      
        if store.equippedKit == 'sorcerer' then
            return bedwars.getIcon({itemType = 'alchemy_crystal'}, true) or bedwars.getIcon({itemType = 'wild_flower'}, true)
        end
        
        if store.equippedKit == 'miner' then
            return bedwars.getIcon({itemType = 'stone'}, true) or bedwars.getIcon({itemType = 'rock'}, true)
        end
        
        if store.equippedKit == 'necromancer' then
            return "rbxassetid://6307844310" 
        end
        
        if store.equippedKit == 'battery' then
            return "rbxassetid://10159166528"
        end
        
        return bedwars.getIcon({itemType = icon}, true)
    end
    
    local function Added(v, icon, itemName, isMiner, isGravestone, isBattery)
        if isMiner then
            local petrifiedModel = v.Parent
            if not petrifiedModel then return end
            
            if isOnMyTeam(petrifiedModel) then
                return
            end
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = icon
        
        if isMiner then
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
            billboard.Size = UDim2.fromOffset(100, 40)
            
            local blur = addBlur(billboard)
            blur.Visible = Background.Enabled
            
            local frame = Instance.new('Frame')
            frame.Size = UDim2.fromScale(1, 1)
            frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
            frame.BorderSizePixel = 0
            frame.Parent = billboard
            
            local uicorner = Instance.new('UICorner')
            uicorner.CornerRadius = UDim.new(0, 4)
            uicorner.Parent = frame
            
            local text = Instance.new('TextLabel')
            text.Size = UDim2.fromScale(1, 1)
            text.Position = UDim2.fromScale(0.5, 0.5)
            text.AnchorPoint = Vector2.new(0.5, 0.5)
            text.BackgroundTransparency = 1
            text.Text = "Petrified: " .. v.Parent.Name
            text.TextColor3 = Color3.new(1, 1, 1)
            text.TextScaled = true
            text.Font = Enum.Font.GothamBold
            text.Parent = frame
            
            minerCache[v.Parent] = billboard
        elseif isGravestone then
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
            billboard.Size = UDim2.fromOffset(40, 40)
            
            local blur = addBlur(billboard)
            blur.Visible = Background.Enabled
            
            local image = Instance.new('ImageLabel')
            image.Size = UDim2.fromOffset(40, 40)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
            image.BorderSizePixel = 0
            image.Image = getProperImage(v, icon)
            image.Parent = billboard
            
            local uicorner = Instance.new('UICorner')
            uicorner.CornerRadius = UDim.new(0, 4)
            uicorner.Parent = image
            
            local text = Instance.new('TextLabel')
            text.Size = UDim2.new(1, 0, 0.3, 0)
            text.Position = UDim2.new(0, 0, 0.7, 0)
            text.Text = "Grave"
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.new(1, 1, 1)
            text.TextScaled = true
            text.Parent = billboard
            
            gravestoneCache[v.Parent] = billboard
        elseif isBattery then
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
            billboard.Size = UDim2.fromOffset(40, 40)
            
            local blur = addBlur(billboard)
            blur.Visible = Background.Enabled
            
            local image = Instance.new('ImageLabel')
            image.Size = UDim2.fromOffset(40, 40)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
            image.BorderSizePixel = 0
            image.Image = getProperImage(v, icon)
            image.Parent = billboard
            
            local uicorner = Instance.new('UICorner')
            uicorner.CornerRadius = UDim.new(0, 4)
            uicorner.Parent = image
            
            local text = Instance.new('TextLabel')
            text.Size = UDim2.new(1, 0, 0.3, 0)
            text.Position = UDim2.new(0, 0, 0.7, 0)
            text.Text = "Battery"
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.new(1, 1, 1)
            text.TextScaled = true
            text.Parent = billboard
            
            batteryCache[v.Parent] = billboard
        else
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
            billboard.Size = UDim2.fromOffset(36, 36)
            
            local blur = addBlur(billboard)
            blur.Visible = Background.Enabled
            
            local image = Instance.new('ImageLabel')
            image.Size = UDim2.fromOffset(36, 36)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
            image.BorderSizePixel = 0
            image.Image = getProperImage(v, icon)
            image.Parent = billboard
            
            local uicorner = Instance.new('UICorner')
            uicorner.CornerRadius = UDim.new(0, 4)
            uicorner.Parent = image
        end
        
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        if not isMiner and not isGravestone and not isBattery then
            Reference[v] = billboard
        end
        
        if Notify.Enabled and store.equippedKit then
            local kit = store.equippedKit
            if ESPKits[kit] then
                if not spawnQueue[kit] then
                    spawnQueue[kit] = {}
                end
                if isMiner then
                    table.insert(spawnQueue[kit], {
                        playerName = v.Parent.Name,
                        time = tick()
                    })
                else
                    table.insert(spawnQueue[kit], {
                        item = itemName,
                        time = tick()
                    })
                end
                processSpawnQueue()
            end
        end
    end
    
    local function findGravestones()
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model.Name == "Gravestone" then
                if model.PrimaryPart then
                    if not gravestoneCache[model] then
                        Added(model.PrimaryPart, 'gravestone', 'gravestones', false, true, false)
                    end
                end
            end
        end
    end
    
    local function findBatteries()
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model.Name == "Open" then
                if model.PrimaryPart then
                    if not batteryCache[model] then
                        Added(model.PrimaryPart, 'battery', 'batteries', false, false, true)
                    end
                end
            end
        end
    end
    
    local function addKit(tag, icon, itemName, isMiner, isGravestone, isBattery)
        if isGravestone then
            KitESP:Clean(workspace.ChildAdded:Connect(function(child)
                if child:IsA("Model") and child.Name == "Gravestone" then
                    task.wait(0.1)
                    if child.PrimaryPart then
                        Added(child.PrimaryPart, icon, itemName, false, true, false)
                    end
                end
            end))
            
            KitESP:Clean(workspace.ChildRemoved:Connect(function(child)
                if child:IsA("Model") and child.Name == "Gravestone" then
                    if gravestoneCache[child] then
                        gravestoneCache[child]:Destroy()
                        gravestoneCache[child] = nil
                    end
                end
            end))
            
            findGravestones()
        elseif isBattery then
            KitESP:Clean(workspace.ChildAdded:Connect(function(child)
                if child:IsA("Model") and child.Name == "Open" then
                    task.wait(0.1)
                    if child.PrimaryPart then
                        Added(child.PrimaryPart, icon, itemName, false, false, true)
                    end
                end
            end))
            
            KitESP:Clean(workspace.ChildRemoved:Connect(function(child)
                if child:IsA("Model") and child.Name == "Open" then
                    if batteryCache[child] then
                        batteryCache[child]:Destroy()
                        batteryCache[child] = nil
                    end
                end
            end))
            
            findBatteries()
        else
            KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
                if v.PrimaryPart then
                    Added(v.PrimaryPart, icon, itemName, isMiner, false, false)
                end
            end))
            
            KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
                if isMiner then
                    if minerCache[v] then
                        minerCache[v]:Destroy()
                        minerCache[v] = nil
                    end
                else
                    if v.PrimaryPart and Reference[v.PrimaryPart] then
                        Reference[v.PrimaryPart]:Destroy()
                        Reference[v.PrimaryPart] = nil
                    end
                end
            end))
            
            for _, v in collectionService:GetTagged(tag) do
                if v.PrimaryPart then
                    Added(v.PrimaryPart, icon, itemName, isMiner, false, false)
                end
            end
        end
    end
    
    KitESP = vape.Categories.Render:CreateModule({
        Name = 'KitESP',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
                local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
                if kit then
                    if store.equippedKit == 'miner' then
                        addKit('petrified-player', 'stone', 'petrified players', true, false, false)
                    elseif store.equippedKit == 'necromancer' then
                        addKit('Gravestone', 'gravestone', 'gravestones', false, true, false)
                    elseif store.equippedKit == 'battery' then
                        addKit('Open', 'battery', 'batteries', false, false, true)
                    else
                        addKit(kit[1], kit[2], kit[3], false, false, false)
                    end
                else
                    if Notify.Enabled then
                        notif("Kit ESP", "No active kit detected", 3)
                    end
                end
            else
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(spawnQueue)
                table.clear(minerCache)
                table.clear(gravestoneCache)
                table.clear(batteryCache)
                lastNotification = 0
            end
        end,
        Tooltip = 'ESP for certain kit related objects'
    })
    
    Background = KitESP:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then Color.Object.Visible = callback end
            for _, v in Reference do
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                    if v.Blur then
                        v.Blur.Visible = callback
                    end
                end
            end
            for _, v in minerCache do
                if v and v.Frame then
                    v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                    if v.Blur then
                        v.Blur.Visible = callback
                    end
                end
            end
            for _, v in gravestoneCache do
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                    if v.Blur then
                        v.Blur.Visible = callback
                    end
                end
            end
            for _, v in batteryCache do
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                    if v.Blur then
                        v.Blur.Visible = callback
                    end
                end
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
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
            for _, v in minerCache do
                if v and v.Frame then
                    v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.Frame.BackgroundTransparency = 1 - opacity
                end
            end
            for _, v in gravestoneCache do
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
            for _, v in batteryCache do
                if v and v.ImageLabel then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    
    Notify = KitESP:CreateToggle({
        Name = 'Notify',
        Function = function(callback)
            if callback then
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
        Tooltip = 'Get notifications when kit items spawn'
    })
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local CollectionService = game:GetService("CollectionService")
	
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
				if nameLower:find(keyword) then
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
	
	local function findExistingLoot()
		for _, drop in CollectionService:GetTagged('ItemDrop') do
			if not drop:FindFirstChild('Handle') then continue end
			
			local lootType, config = getLootType(drop.Name)
			if lootType and isLootEnabled(lootType) then
				if not Reference[drop.Handle] then
					Added(drop.Handle, lootType, config)
				end
			end
		end
	end
	
	local function refreshESP()
		Folder:ClearAllChildren()
		table.clear(Reference)
		
		if LootESP.Enabled then
			findExistingLoot()
		end
	end
	
	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()
				
				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end
					
					task.wait(0.1) 
					if not drop:FindFirstChild('Handle') then return end
					
					local lootType, config = getLootType(drop.Name)
					if lootType and isLootEnabled(lootType) then
						Added(drop.Handle, lootType, config)
					end
				end))
				
				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					if drop:FindFirstChild('Handle') and Reference[drop.Handle] then
						Reference[drop.Handle]:Destroy()
						Reference[drop.Handle] = nil
					end
				end))
				
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for loot drops (iron, diamond, emerald)'
	})
	
	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshESP()
		end,
		Default = true
	})
	
	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshESP()
		end,
		Default = true
	})
	
	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshESP()
		end,
		Default = true
	})
end)

run(function()
    local PotESP
    local Background
    local Color = {}
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    
    local function Added(potPart)
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = "DesertPot"
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
        billboard.Size = UDim2.fromOffset(40, 40)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = potPart
        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled
        local textFrame = Instance.new('Frame')
        textFrame.Size = UDim2.fromScale(1, 1)
        textFrame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        textFrame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
        textFrame.BorderSizePixel = 0
        textFrame.Parent = billboard
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = textFrame
        local textLabel = Instance.new('TextLabel')
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Position = UDim2.fromScale(0.5, 0.5)
        textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "POT"
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextStrokeTransparency = 0.5
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.Parent = textFrame
        Reference[potPart] = billboard
    end
    
    local function findExistingPots()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "desert_pot" then
                if not Reference[obj] then
                    Added(obj)
                end
            end
        end
    end
    
    PotESP = vape.Categories.Render:CreateModule({
        Name = 'PotESP',
        Function = function(callback)
            if callback then
                findExistingPots()
                
                PotESP:Clean(workspace.DescendantAdded:Connect(function(obj)
                    if PotESP.Enabled and obj:IsA("BasePart") and obj.Name == "desert_pot" then
                        task.wait(0.1) 
                        Added(obj)
                    end
                end))
                
                PotESP:Clean(workspace.DescendantRemoved:Connect(function(obj)
                    if obj:IsA("BasePart") and obj.Name == "desert_pot" and Reference[obj] then
                        Reference[obj]:Destroy()
                        Reference[obj] = nil
                    end
                end))
                
            else
                Folder:ClearAllChildren()
                table.clear(Reference)
            end
        end,
        Tooltip = 'ESP for desert pots'
    })
    
    Background = PotESP:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            for _, billboard in pairs(Reference) do
                if billboard and billboard.Frame then
                    local frame = billboard:FindFirstChildOfClass("Frame")
                    if frame then
                        frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                        if billboard.Blur then
                            billboard.Blur.Visible = callback
                        end
                    end
                end
            end
        end,
        Default = true
    })
    
    Color = PotESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, billboard in pairs(Reference) do
                if billboard and billboard.Frame then
                    local frame = billboard:FindFirstChildOfClass("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        frame.BackgroundTransparency = 1 - opacity
                    end
                end
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
    local ShowKits 
    local Scale
    local FontOption
    local Teammates
    local DistanceCheck
    local DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local methodused
    
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
    
    local Added = {
        Normal = function(ent)
            if not Targets.Players.Enabled and ent.Player then return end
            if not Targets.NPCs.Enabled and ent.NPC then return end
            if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
            
            local nametag = Instance.new('TextLabel')
            Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
            
            if Health.Enabled then
                local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
                Strings[ent] = Strings[ent]..' '..math.round(ent.Health)..''
            end
            
            if Distance.Enabled then
                Strings[ent] = '[%s] '..Strings[ent]
            end
            
            if Equipment.Enabled then
                for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots'} do
                    local Icon = Instance.new('ImageLabel')
                    Icon.Name = v
                    Icon.Size = UDim2.fromOffset(30, 30)
                    Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
                    Icon.BackgroundTransparency = 1
                    Icon.Image = ''
                    Icon.Parent = nametag
                end
            end
            
            if ShowKits.Enabled and ent.Player then
                local kitIcon = Instance.new('ImageLabel')
                kitIcon.Name = 'KitIcon'
                kitIcon.Size = UDim2.fromOffset(30, 30)
                kitIcon.AnchorPoint = Vector2.new(0.5, 0)
                kitIcon.BackgroundTransparency = 1
                kitIcon.Image = ''
                
                if Equipment.Enabled then
                    kitIcon.Position = UDim2.fromOffset(90, -30)
                else
                    kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
                end
                
                kitIcon.Parent = nametag
                
                local kit = ent.Player:GetAttribute('PlayingAsKits')
                if kit then
                    local kitImage = kitImageIds[kit:lower()]
                    if kitImage then
                        kitIcon.Image = kitImage
                    else
                        kitIcon.Image = kitImageIds["none"]
                    end
                else
                    kitIcon.Image = kitImageIds["none"]
                end
            end
            
            nametag.TextSize = 14 * Scale.Value
            nametag.FontFace = FontOption.Value
            local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
            nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
            nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
            nametag.AnchorPoint = Vector2.new(0.5, 1)
            nametag.BackgroundColor3 = Color3.new()
            nametag.BackgroundTransparency = Background.Value
            nametag.BorderSizePixel = 0
            nametag.Visible = false
            nametag.Text = Strings[ent]
            nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            nametag.RichText = true
            nametag.Parent = Folder
            Reference[ent] = nametag
        end,
        Drawing = function(ent)
            if not Targets.Players.Enabled and ent.Player then return end
            if not Targets.NPCs.Enabled and ent.NPC then return end
            if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
            
            local nametag = {}
            nametag.BG = Drawing.new('Square')
            nametag.BG.Filled = true
            nametag.BG.Transparency = 1 - Background.Value
            nametag.BG.Color = Color3.new()
            nametag.BG.ZIndex = 1
            nametag.Text = Drawing.new('Text')
            nametag.Text.Size = 15 * Scale.Value
            nametag.Text.Font = 0
            nametag.Text.ZIndex = 2
            Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
            
            if Health.Enabled then
                Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
            end
            
            if Distance.Enabled then
                Strings[ent] = '[%s] '..Strings[ent]
            end
            
            if ShowKits.Enabled and ent.Player then
                local kit = ent.Player:GetAttribute('PlayingAsKits')
                if kit then
                    local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
                    Strings[ent] = Strings[ent]..' ('..kitName..')'
                end
            end
            
            nametag.Text.Text = Strings[ent]
            nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
            Reference[ent] = nametag
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
            local nametag = Reference[ent]
            if nametag then
                Sizes[ent] = nil
                Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
                
                if Health.Enabled then
                    local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
                    Strings[ent] = Strings[ent]..' '..math.round(ent.Health)..''
                end
                
                if Distance.Enabled then
                    Strings[ent] = '[%s] '..Strings[ent]
                end
                
                if Equipment.Enabled and ent.Player and store.inventories[ent.Player] then
                    local inventory = store.inventories[ent.Player]
                    if nametag.Hand then
                        nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
                    end
                    if nametag.Helmet then
                        nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
                    end
                    if nametag.Chestplate then
                        nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
                    end
                    if nametag.Boots then
                        nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
                    end
                end
                
                local kitIcon = nametag:FindFirstChild('KitIcon')
                
                if ShowKits.Enabled and ent.Player then
                    if not kitIcon then
                        kitIcon = Instance.new('ImageLabel')
                        kitIcon.Name = 'KitIcon'
                        kitIcon.Size = UDim2.fromOffset(30, 30)
                        kitIcon.AnchorPoint = Vector2.new(0.5, 0)
                        kitIcon.BackgroundTransparency = 1
                        kitIcon.Image = ''
                        kitIcon.Parent = nametag
                    end
                    
                    if Equipment.Enabled then
                        kitIcon.Position = UDim2.fromOffset(90, -30)
                    else
                        kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
                    end
                    
                    local kit = ent.Player:GetAttribute('PlayingAsKits')
                    if kit then
                        local kitImage = kitImageIds[kit:lower()]
                        if kitImage and kitIcon.Image ~= kitImage then
                            kitIcon.Image = kitImage
                        end
                    else
                        if kitIcon.Image ~= kitImageIds["none"] then
                            kitIcon.Image = kitImageIds["none"]
                        end
                    end
                elseif kitIcon then
                    kitIcon:Destroy()
                end
                
                local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
                nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
                nametag.Text = Strings[ent]
            end
        end,
        Drawing = function(ent)
            local nametag = Reference[ent]
            if nametag then
                if vape.ThreadFix then setthreadidentity(8) end
                Sizes[ent] = nil
                Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
                
                if Health.Enabled then
                    Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
                end
                
                if Distance.Enabled then
                    Strings[ent] = '[%s] '..Strings[ent]
                    nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
                else
                    nametag.Text.Text = Strings[ent]
                end
                
                if ShowKits.Enabled and ent.Player then
                    local kit = ent.Player:GetAttribute('PlayingAsKits')
                    if kit then
                        local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
                        nametag.Text.Text = nametag.Text.Text..' ('..kitName..')'
                    end
                end
                
                nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
                nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            end
        end
    }
    
    local ColorFunc = {
        Normal = function(hue, sat, val)
            local color = Color3.fromHSV(hue, sat, val)
            for i, v in Reference do
                v.TextColor3 = entitylib.getEntityColor(i) or color
            end
        end,
        Drawing = function(hue, sat, val)
            local color = Color3.fromHSV(hue, sat, val)
            for i, v in Reference do
                v.Text.Color = entitylib.getEntityColor(i) or color
            end
        end
    }
    
    local Loop = {
        Normal = function()
            for ent, nametag in Reference do
                if DistanceCheck.Enabled then
                    local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        nametag.Visible = false
                        continue
                    end
                end
                
                local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
                nametag.Visible = headVis
                if not headVis then continue end
                
                if Distance.Enabled then
                    local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
                    if Sizes[ent] ~= mag then
                        nametag.Text = string.format(Strings[ent], mag)
                        local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
                        nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
                        Sizes[ent] = mag
                    end
                end
                
                local kitIcon = nametag:FindFirstChild('KitIcon')
                if ShowKits.Enabled and kitIcon then
                    if Equipment.Enabled then
                        kitIcon.Position = UDim2.fromOffset(90, -30)
                    else
                        kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
                    end
                    
                    if ent.Player then
                        local kit = ent.Player:GetAttribute('PlayingAsKits')
                        if kit then
                            local kitImage = kitImageIds[kit:lower()]
                            if kitImage and kitIcon.Image ~= kitImage then
                                kitIcon.Image = kitImage
                            end
                        else
                            if kitIcon.Image ~= kitImageIds["none"] then
                                kitIcon.Image = kitImageIds["none"]
                            end
                        end
                    end
                end
                
                nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
            end
        end,
        Drawing = function()
            for ent, nametag in Reference do
                if DistanceCheck.Enabled then
                    local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        nametag.Text.Visible = false
                        nametag.BG.Visible = false
                        continue
                    end
                end
                
                local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
                nametag.Text.Visible = headVis
                nametag.BG.Visible = headVis
                if not headVis then continue end
                
                if Distance.Enabled then
                    local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
                    if Sizes[ent] ~= mag then
                        nametag.Text.Text = string.format(Strings[ent], mag)
                        nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
                        Sizes[ent] = mag
                    end
                end
                
                nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
                nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
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
	local BedAlarm
	local DetectionRange
	local RepeatNotifications
	local NotificationDelay
	local UseDisplayName
	local NotifyKits
	local AlarmActive = false
	local PlayersNearBed = {}
	local LastNotificationTime = {}
	
	local function getKitName(kitId)
		if bedwars.BedwarsKitMeta[kitId] then
			return bedwars.BedwarsKitMeta[kitId].name
		end
		return kitId:gsub("_", " "):gsub("^%l", string.upper)
	end
	
	local function getOwnBed()
		if not entitylib.isAlive then return nil end
		local playerTeam = lplr:GetAttribute('Team')
		if not playerTeam then return nil end
		
		for _, bed in collectionService:GetTagged('bed') do
			if bed:GetAttribute('Team'..playerTeam..'NoBreak') then
				return bed
			end
		end
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
	
	local function createNotification(ent)
		local playerName = getPlayerName(ent)
		local message = playerName..' is near your bed!'
		
		if NotifyKits.Enabled then
			local kit = getPlayerKit(ent)
			if kit then
				message = playerName..' is near your bed! (Kit: '..kit..')'
			end
		end
		
		notif('Bed Alarm', message, 3, 'warning')
	end
	
	local function checkPlayers()
		if not BedAlarm.Enabled then return end
		if not entitylib.isAlive then return end
		
		local bed = getOwnBed()
		if not bed then return end
		
		local bedPosition = bed.Position
		local currentTime = tick()
		local currentPlayersNear = {}
		
		for _, ent in entitylib.List do
			if ent.Targetable and ent.Player then
				local distance = (ent.RootPart.Position - bedPosition).Magnitude
				
				if distance <= DetectionRange.Value then
					currentPlayersNear[ent] = true
					
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
						createNotification(ent)
						LastNotificationTime[ent] = currentTime
					end
				end
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
					notif('BedAlarm', 'Cannot locate your bed!', 3, 'error')
					BedAlarm:Toggle()
					return
				end
				
				AlarmActive = true
				PlayersNearBed = {}
				LastNotificationTime = {}
				
				BedAlarm:Clean(runService.Heartbeat:Connect(checkPlayers))
			else
				AlarmActive = false
				table.clear(PlayersNearBed)
				table.clear(LastNotificationTime)
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
	
	RepeatNotifications = BedAlarm:CreateToggle({
		Name = 'Repeat Notifications',
		Function = function(callback)
			NotificationDelay.Object.Visible = callback
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
				blockimage.Size = UDim2.fromOffset(31, 31)
				blockimage.BackgroundTransparency = 1
				blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:WaitForChild('ChestFolderValue', 3)
		if not (chest and StorageESP.Enabled) then return end
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
		corner.CornerRadius = UDim.new(0, 6)
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
		Name = 'Storage ESP',
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
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		spider_queen = function()
			local isAiming = false
			local aimingTarget = nil
			
			repeat
				if entitylib.isAlive and bedwars.AbilityController then
					local plr = entitylib.EntityPosition({
						Range = not Legit.Enabled and 80 or 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
					
					if plr and not isAiming and bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_aim') then
						bedwars.AbilityController:useAbility('spider_queen_web_bridge_aim')
						isAiming = true
						aimingTarget = plr
						task.wait(0.1)
					end
					
					if isAiming and aimingTarget and aimingTarget.RootPart then
						local localPosition = entitylib.character.RootPart.Position
						local targetPosition = aimingTarget.RootPart.Position
						
						local direction
						if Legit.Enabled then
							direction = (targetPosition - localPosition).Unit
						else
							direction = (targetPosition - localPosition).Unit
						end
						
						if bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_fire') then
							bedwars.AbilityController:useAbility('spider_queen_web_bridge_fire', newproxy(true), {
								direction = direction
							})
							isAiming = false
							aimingTarget = nil
							task.wait(0.3)
						end
					end
					
					if isAiming and (not aimingTarget or not aimingTarget.RootPart) then
						isAiming = false
						aimingTarget = nil
					end
					
					local summonAbility = 'spider_queen_summon_spiders'
					if bedwars.AbilityController:canUseAbility(summonAbility) then
						bedwars.AbilityController:useAbility(summonAbility)
					end
				end
				
				task.wait(0.05)
			until not AutoKit.Enabled
		end,
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		nazar = function()
			local empoweredMode = false
			local lastHitTime = 0
			local hitTimeout = 3
			
			local HEAL_THRESHOLD_PERCENT = 0.55
			local MIN_LIFE_FORCE_TO_HEAL = 25 
			local CONSUME_COOLDOWN = 3 
			local lastConsumeTime = 0
			
			local function enableEmpower()
				if not empoweredMode and bedwars.AbilityController:canUseAbility('enable_life_force_attack') then
					bedwars.AbilityController:useAbility('enable_life_force_attack')
					empoweredMode = true
				end
			end
			
			local function disableEmpower()
				if empoweredMode and bedwars.AbilityController:canUseAbility('disable_life_force_attack') then
					bedwars.AbilityController:useAbility('disable_life_force_attack')
					empoweredMode = false
				end
			end
			
			local function tryConsumeLifeForce()
				if not entitylib.isAlive then return end
				
				local currentTime = workspace:GetServerTimeNow()
				
				if (currentTime - lastConsumeTime) < CONSUME_COOLDOWN then
					return
				end
				
				local health = lplr.Character:GetAttribute('Health') or 100
				local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
				local lifeForce = lplr:GetAttribute('LifeForce') or 0  
				
				local healthPercent = health / maxHealth

				if healthPercent < HEAL_THRESHOLD_PERCENT and lifeForce >= MIN_LIFE_FORCE_TO_HEAL and health < maxHealth then
					if bedwars.AbilityController:canUseAbility('consume_life_foce') then
						bedwars.AbilityController:useAbility('consume_life_foce')
						lastConsumeTime = currentTime
					end
				end
			end
			
			AutoKit:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
				if not entitylib.isAlive then return end
				
				local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
				local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
				
				if attacker == lplr and victim and victim ~= lplr then
					lastHitTime = workspace:GetServerTimeNow()
					enableEmpower()
				end
			end))
			
			AutoKit:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				if not entitylib.isAlive then return end
				
				local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
				local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
				
				if killer == lplr and killed and killed ~= lplr then
					disableEmpower()
				end
			end))
			
			repeat
				if entitylib.isAlive then
					local currentTime = workspace:GetServerTimeNow()
					
					if empoweredMode and (currentTime - lastHitTime) >= hitTimeout then
						disableEmpower()
					end
					
					tryConsumeLifeForce()
				else
					if empoweredMode then
						disableEmpower()
					end
				end
				
				task.wait(0.1)
			until not AutoKit.Enabled
			
			if empoweredMode then
				disableEmpower()
			end
		end,
		defender = function()
		    repeat
			    if not entitylib.isAlive then task.wait(0.1); continue end
				local handItem = lplr.Character:FindFirstChild('HandInvItem')
				local hasScanner = false
				if handItem and handItem.Value then
					local itemType = handItem.Value.Name
					hasScanner = itemType:find('defense_scanner')
				end
				
				if not hasScanner then
					task.wait(0.1)
					continue
				end

				for i, v in workspace:GetChildren() do
					if v:IsA("BasePart") then
						if v.Name == "DefenderSchematicBlock" then
							v.Transparency = 0.85
							v.Grid.Transparency = 1
							local BP = bedwars.BlockController:getBlockPosition(v.Position)
							bedwars.Client:Get("DefenderRequestPlaceBlock"):CallServer({["blockPos"] = BP})
							pcall(function()
								local sounds = {
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_04,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_03,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_02,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_01
								}

								for i = 4, 1, -1 do
									bedwars.SoundManager:playSound(sounds[i], {
										position = BP,
										playbackSpeedMultiplier = 0.8
									})
									task.wait(0.082)
								end
							end)
							
							task.wait(Legit.Enabled and math.random(1,2) - math.random() or (0.5 - math.random()))
						end
					end
				end

				AutoKit:Clean(workspace.ChildAdded:Connect(function(v)
					if v:IsA("BasePart") then
						if v.Name == "DefenderSchematicBlock" then
							v.Transparency = 0.85
							v.Grid.Transparency = 1
							local BP = bedwars.BlockController:getBlockPosition(v.Position)
							bedwars.Client:Get("DefenderRequestPlaceBlock"):SendToServer({["blockPos"] = BP})
							pcall(function()
								local sounds = {
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_04,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_03,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_02,
									bedwars.SoundList.DEFENDER_UPGRADE_DEFENSE_01
								}

								for i = 4, 1, -1 do
									bedwars.SoundManager:playSound(sounds[i], {
										position = BP,
										playbackSpeedMultiplier = 0.8
									})
									task.wait(0.082)
								end
							end)
							
							task.wait(math.random(1,2) - math.random())
						end
					end
				end))
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})
	
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
	
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
	
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
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
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
					target = v
				})
			end, 18, true)
		end,
		drill = function()
			repeat
				if not AutoKit.Enabled then
					break
				end
		
				local foundDrill = false
				for _, child in workspace:GetDescendants() do
					if child:IsA("Model") and child.Name == "Drill" then
						local drillPrimaryPart = child.PrimaryPart
						if drillPrimaryPart then
							foundDrill = true
							local args = {
								{
									drill = child
								}
							}
							local success, err = pcall(function()
								game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("ExtractFromDrill"):FireServer(unpack(args))
							end)
		
							task.wait(0.05)
						end
					elseif child:IsA("BasePart") and child.Name == "Drill" then
						foundDrill = true
						local args = {
							{
								drill = child
							}
						}
						local success, err = pcall(function()
							game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("ExtractFromDrill"):FireServer(unpack(args))
						end)
		
						task.wait(0.05)
					end
				end
				task.wait(0.5)
			until not AutoKit.Enabled
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end
	
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...

				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						if Legit.Enabled then
							local handItem = store.inventory.inventory.hand
							if handItem then
								local itemMeta = bedwars.ItemMeta[handItem.itemType]
								if itemMeta and itemMeta.breakBlock then
									task.spawn(bedwars.breakBlock, block, false, nil, true)
								end
							end
						else
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
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
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
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
						healTarget = ent.Character
					})
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
									local success = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("MimicBlockPickPocketPlayer"):InvokeServer(v.Player)
								end)
								task.wait(0.5)
							end
						end
					end
				end
				
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Client:Get(remotes.MinerDig):SendToServer({
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get(remotes.DepositPinata):CallServer(v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		void_knight = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local currentTier = lplr:GetAttribute('VoidKnightTier') or 0
				local currentProgress = lplr:GetAttribute('VoidKnightProgress') or 0
				local currentKills = lplr:GetAttribute('VoidKnightKills') or 0
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
					if health < (maxHealth * 0.5) then
						shouldAscend = true
					end
					
					if not shouldAscend then
						local plr = entitylib.EntityPosition({
							Range = Legit.Enabled and 30 or 50,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Health
						})
						if plr then
							shouldAscend = true
						end
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
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Client:Get(remotes.DragonBreath):SendToServer({
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
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
						Range = Legit.Enabled and 60 or 80,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
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
		dragon_sword = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local swordCount = lplr:GetAttribute('SwordCount') or 0
				
				if swordCount > 0 then
					if swordCount >= 3 then
						local nearbyEnemies = 0
						local localPos = entitylib.character.RootPart.Position
						
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - localPos).Magnitude <= 30 then
								nearbyEnemies += 1
							end
						end
						
						if nearbyEnemies >= 2 then
							pcall(function()
								game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("DragonSwordUlt"):FireServer()
							end)
							task.wait(2)
							continue
						end
					end
					
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Sort = sortmethods.Health
					})
					
					if plr and bedwars.AbilityController:canUseAbility('dragon_sword') then
						bedwars.AbilityController:useAbility('dragon_sword')
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
						Range = Legit.Enabled and 50 or 80,
						Part = 'RootPart',
						Players = true,
						NPCs = false,
						Sort = sortmethods.Health
					})
					
					if plr then
						bedwars.AbilityController:useAbility('CARD_THROW')
						
						task.wait(0.1)
						pcall(function()
							replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("AttemptCardThrow"):FireServer({
								targetEntityInstance = plr.Character
							})
						end)
						
						task.wait(0.5)
					end
				end
				
				task.wait(0.1)
			until not AutoKit.Enabled
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
		mage = function()
			kitCollection('ElementTome', function(v)
				local secret = v:GetAttribute('TomeSecret')
				if secret then
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
					bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
					
					local result = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("LearnElementTome"):InvokeServer({
						secret = secret
					})
					
					if result and result.success then
						v:Destroy()
						task.wait(0.5)
					end
				end
			end, 10, false)
		end,
		necromancer = function()
			kitCollection('Gravestone', function(v)
				local secret = v:GetAttribute('GravestoneSecret')
				local position = v:GetAttribute('GravestonePosition')
				local userId = v:GetAttribute('GravestonePlayerUserId')
				local armorType = v:GetAttribute('ArmorType')
				local swordType = v:GetAttribute('SwordType')
				
				if secret and position then
					pcall(function()
						bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PLACE_BLOCK)
						
						local humanoid = lplr.Character and lplr.Character:FindFirstChild("Humanoid")
						if humanoid then
							local anim = Instance.new("Animation")
							anim.AnimationId = "rbxassetid://11337806332"
							local animTrack = humanoid:LoadAnimation(anim)
							animTrack:Play()
						end
					end)
					task.wait(0.1)
					local success = replicatedStorage:WaitForChild("rbxts_include")
						:WaitForChild("node_modules")
						:WaitForChild("@rbxts")
						:WaitForChild("net")
						:WaitForChild("out")
						:WaitForChild("_NetManaged")
						:WaitForChild("ActivateGravestone")
						:InvokeServer({
							secret = secret,
							position = position,
							skeletonData = {
								associatedPlayerUserId = userId,
								armorType = armorType,
								weaponType = swordType
							}
						})
					
					if success and success.success then
						task.spawn(function()
							pcall(function()
								local gravestoneBeams = replicatedStorage:FindFirstChild("Assets")
									and replicatedStorage.Assets:FindFirstChild("Effects")
									and replicatedStorage.Assets.Effects:FindFirstChild("GravestoneBeams")
								
								if gravestoneBeams and lplr.Character then
									local beamClone = gravestoneBeams:Clone()
									beamClone.CFrame = v:GetPivot()
									beamClone.Parent = workspace
									
									for _, beam in pairs(beamClone:GetChildren()) do
										if beam:IsA("Beam") then
											beam.Attachment0 = v.Root.GravestoneModel.Gravestone.BeamAttachment
											
											local leftHand = lplr.Character:WaitForChild("LeftHand", 3)
											if leftHand then
												local leftGrip = leftHand:WaitForChild("LeftGripAttachment", 3)
												if leftGrip then
													beam.Attachment1 = leftGrip
													beam.Enabled = true
												end
											end
										end
									end
									
									task.delay(1, function()
										beamClone:Destroy()
									end)
								end
							end)
						end)
						
						task.wait(0.5)
					end
				end
			end, 12, true)
		end,
		warlock = function()
			local lastTarget
			repeat
				if not entitylib.isAlive then
					lastTarget = nil
					task.wait(0.1)
					continue
				end
				
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = false
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}
	
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
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
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
	local CannonHandController = bedwars.CannonHandController
	local CannonController = bedwars.CannonController

	local oldLaunchSelf = CannonHandController.launchSelf
	local oldStopAiming = CannonController.stopAiming
	local oldStartAiming = CannonController.startAiming

	local function isHoldingPickaxe()
		if not entitylib.isAlive then return false end
		
		local handItem = store.hand
		if not handItem or not handItem.tool then return false end
		
		local itemName = handItem.tool.Name:lower()
		local isPickaxe = itemName:find("pickaxe") or 
						 itemName:find("drill") or 
						 itemName:find("gauntlet") or
						 itemName:find("hammer") or
						 itemName:find("axe")
		
		return isPickaxe
	end

	local function getNearestCannon()
		local nearest
		local nearestDist = math.huge

		for i,v in pairs(CannonController.getCannons()) do
			pcall(function()
				local dist = (v.Position - lplr.Character.PrimaryPart.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = v
				end
			end)
		end

		return nearest
	end

	local speed_was_disabled = nil

	local function disableSpeed()
		pcall(function()
			if vape.Modules.Speed.Enabled then
				vape.Modules.Speed:Toggle(false)
				speed_was_disabled = true
			else
				speed_was_disabled = false
			end	
		end)
	end

	local function enableSpeed()
		task.wait(3)
		if speed_was_disabled then
			pcall(function()
				if not vape.Modules.Speed.Enabled then
					vape.Modules.Speed:Toggle(false)
				end
				speed_was_disabled = nil
			end)
		end
	end
	
	local function breakCannon(cannon, shootfunc)
		if BetterDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
			notif("BetterDavey", "You need to HOLD a pickaxe to break cannons!", 3)
			if BetterDaveyAutojump.Enabled then
				lplr.Character.Humanoid:ChangeState(3)
			end
			local res = shootfunc()
			enableSpeed()
			return res
		end
		
		local pos = cannon.Position
		local res
		task.delay(0.2, function()
			local block, blockpos = getPlacedBlock(pos)
			if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
				local broken = 0.1
				if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
					broken = 0.4
					bedwars.breakBlock(block, true, true)
				end

				task.delay(broken, function()
					if BetterDaveyAutojump.Enabled then
						lplr.Character.Humanoid:ChangeState(3)
					end
					res = shootfunc()
					task.spawn(bedwars.breakBlock, block, false, nil, true)
					return res
				end)
			end
		end)
	end

	BetterDavey = vape.Categories.Utility:CreateModule({
		Name = 'BetterDavey',
		Function = function(callback)
			if callback then
				local stopIndex = 0

				CannonHandController.launchSelf = function(...)
					disableSpeed()

					if BetterDaveyAutoBreak.Enabled then
						local cannon = getNearestCannon()
						if cannon then
							local args = {...}
							local result = breakCannon(cannon, function() return oldLaunchSelf(unpack(args)) end)
							enableSpeed()
							return result
						else
							if BetterDaveyAutojump.Enabled then
								lplr.Character.Humanoid:ChangeState(3)
							end
							local res = oldLaunchSelf(...)
							enableSpeed()
							return res
						end
					else
						if BetterDaveyAutojump.Enabled then
							lplr.Character.Humanoid:ChangeState(3)
						end
						local res = oldLaunchSelf(...)
						enableSpeed()
						return res
					end
				end

				CannonController.stopAiming = function(...)
					stopIndex += 1

					if BetterDaveyAutoLaunch.Enabled and stopIndex == 2 then
						if BetterDaveyAutoBreak.Enabled and BetterDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
							notif("BetterDavey", "Hold a pickaxe to auto-break!", 3)
							return oldStopAiming(...)
						end
						
						local cannon = getNearestCannon()
						if cannon then
							CannonHandController:launchSelf(cannon)
						end
					end

					return oldStopAiming(...)
				end

				CannonController.startAiming = function(...)
					stopIndex = 0
					return oldStartAiming(...)
				end
			else
				CannonHandController.launchSelf = oldLaunchSelf
				CannonController.stopAiming = oldStopAiming
				CannonController.startAiming = oldStartAiming
			end
		end
	})
	
	BetterDaveyAutojump = BetterDavey:CreateToggle({
		Name = 'Auto jump',
		Default = true,
		HoverText = 'Automatically jumps when launching from a cannon',
		Function = function() end
	})
	
	BetterDaveyAutoLaunch = BetterDavey:CreateToggle({
		Name = 'Auto launch',
		Default = true,
		HoverText = 'Automatically launches you from a cannon when you finish aiming',
		Function = function() end
	})
	
	BetterDaveyAutoBreak = BetterDavey:CreateToggle({
		Name = 'Auto break',
		Default = true,
		HoverText = 'Automatically breaks a cannon when you launch from it',
		Function = function() end
	})
	
	BetterDaveyPickaxeCheck = BetterDavey:CreateToggle({
		Name = 'Pickaxe Check',
		Default = true,
		HoverText = 'Must be HOLDING a pickaxe to break cannons\nWill NOT switch tools automatically',
		Function = function() end
	})
end)

run(function()
    local anim
    local asset
    local trackingConnection
    local NightmareEmote
    
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
                local l__TweenService__9 = game:GetService("TweenService")
                local player = game:GetService("Players").LocalPlayer
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
                
                local v10 = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("NightmareEmote"):Clone()
                asset = v10
                v10.Parent = game.Workspace
                
                local v11 = v10:GetDescendants()
                local function v12(p8)
                    if p8:IsA("BasePart") then
                        l__GameQueryUtil__8:setQueryIgnored(p8, true)
                        p8.CanCollide = false
                        p8.Anchored = true
                    end
                end
                
                for v13, v14 in ipairs(v11) do
                    v12(v14, v13 - 1, v11)
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
                
                trackingConnection = game:GetService("RunService").RenderStepped:Connect(function()
                    if not asset or not asset.Parent then 
                        trackingConnection:Disconnect()
                        return 
                    end
                    
                    if not character or not character.Parent then
                        asset:Destroy()
                        asset = nil
                        trackingConnection:Disconnect()
                        NightmareEmote:Toggle()
                        return
                    end
                    
                    local currentRoot = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                    local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
                    
                    if not currentRoot or not currentHumanoid or currentHumanoid.Health <= 0 then
                        asset:Destroy()
                        asset = nil
                        trackingConnection:Disconnect()
                        NightmareEmote:Toggle()
                        return
                    end
                
                    v10:SetPrimaryPartCFrame(currentRoot.CFrame * CFrame.new(0, -3, 0))
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
            end
        end
    })
end)

run(function()
    local AutoCounter
    local TntCount
    local LimitItem

    local function fixPosition(pos)
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end

    local allOurTnt = {}
    local ourTntPositions = {}

    local originalPlaceBlock = bedwars.placeBlock
    bedwars.placeBlock = function(pos, blockType, ...)
        local result = originalPlaceBlock(pos, blockType, ...)

        if blockType == "tnt" then
            local fixedPos = fixPosition(pos)
            ourTntPositions[tostring(fixedPos)] = true
            
            task.spawn(function()
                task.wait(0.3)
                for _, obj in workspace:GetDescendants() do
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        local distance = (fixPosition(obj.Position) - fixedPos).Magnitude
                        if distance < 2 then
                            allOurTnt[obj] = true
                        end
                    end
                end
            end)
        end

        return result
    end

    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "tnt" and obj:IsA("Part") then
            task.wait(0.1)

            local placerId = obj:GetAttribute("PlacedByUserId")
            if placerId and placerId == lplr.UserId then
                allOurTnt[obj] = true
                ourTntPositions[tostring(fixPosition(obj.Position))] = true
            else
                local tntPos = tostring(fixPosition(obj.Position))
                if ourTntPositions[tntPos] then
                    allOurTnt[obj] = true
                end
            end

            obj.AncestryChanged:Connect(function()
                if not obj.Parent then
                    allOurTnt[obj] = nil
                    ourTntPositions[tostring(fixPosition(obj.Position))] = nil
                end
            end)
        end
    end)

    local function isEnemyTnt(tntBlock)
        if not tntBlock then return false end

        if allOurTnt[tntBlock] then
            return false
        end

        local tntPos = tostring(fixPosition(tntBlock.Position))
        if ourTntPositions[tntPos] then
            allOurTnt[tntBlock] = true
            return false
        end

        local placerId = tntBlock:GetAttribute("PlacedByUserId")
        if placerId and placerId == lplr.UserId then
            allOurTnt[tntBlock] = true
            ourTntPositions[tntPos] = true
            return false
        end

        return true
    end

    local function isHoldingTnt()
        local currentTool = store.hand.tool
        return currentTool and currentTool.Name == "tnt"
    end

    AutoCounter = vape.Categories.World:CreateModule({
        Name = 'AutoCounter',
        Function = function(callback)
            
            if callback then
                local counteredTnt = {}

                for _, obj in workspace:GetDescendants() do
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        local placerId = obj:GetAttribute("PlacedByUserId")
                        if placerId and placerId == lplr.UserId then
                            allOurTnt[obj] = true
                            ourTntPositions[tostring(fixPosition(obj.Position))] = true
                        end
                    end
                end

                repeat
                    if not entitylib.isAlive then
                        task.wait(0.1)
                        continue
                    end

                    if LimitItem.Enabled and not isHoldingTnt() then
                        task.wait(0.1)
                        continue
                    end

                    if not getItem("tnt") then
                        task.wait(0.1)
                        continue
                    end

                    for _, obj in workspace:GetDescendants() do
                        if obj.Name == "tnt" and obj:IsA("Part") and not counteredTnt[obj] then
                            if isEnemyTnt(obj) then
                                local distance = (entitylib.character.RootPart.Position - obj.Position).Magnitude

                                if distance <= 30 then
                                    local placedCount = 0
                                    
                                    for _, side in Enum.NormalId:GetEnumItems() do
                                        if LimitItem.Enabled and not isHoldingTnt() then
                                            break
                                        end

                                        if placedCount >= TntCount.Value then break end

                                        local sideVec = Vector3.fromNormalId(side)
                                        if sideVec.Y == 0 then
                                            local placePos = fixPosition(obj.Position + sideVec * 3.5)

                                            if not getPlacedBlock(placePos) and getItem("tnt") then
                                                if LimitItem.Enabled and not isHoldingTnt() then
                                                    break
                                                end

                                                bedwars.placeBlock(placePos, "tnt")
                                                placedCount = placedCount + 1
                                                task.wait(0.05)
                                            end
                                        end
                                    end

                                    counteredTnt[obj] = true

                                    task.spawn(function()
                                        if obj.Parent then
                                            obj.AncestryChanged:Wait()
                                        end
                                        counteredTnt[obj] = nil
                                    end)
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoCounter.Enabled
            else
                table.clear(allOurTnt)
                table.clear(ourTntPositions)
            end
        end,
        Tooltip = 'Automatically places TNT around enemy TNT'
    })

    TntCount = AutoCounter:CreateSlider({
        Name = 'TNT Count',
        Min = 1,
        Max = 5,
        Default = 3
    })

    LimitItem = AutoCounter:CreateToggle({
        Name = 'Limit to TNT',
        Default = true,
        Tooltip = 'Only works when holding TNT'
    })
end)

run(function()
	local AutoPearl
	local LimitItem
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function firePearl(pos, spot, item)
		switchItem(item.tool)
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
			projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
		end
	
		if store.hand then
			switchItem(store.hand.tool)
		end
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			
			if callback then
				local check
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							local shouldThrow = true
							if LimitItem.Enabled then
								shouldThrow = store.hand.tool and store.hand.tool.Name == 'telepearl'
							end
							
							if shouldThrow and not check then
								check = true
								local ground = getNearGround(20)

								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'Automatically throws a pearl onto nearby ground'
	})
	
	LimitItem = AutoPearl:CreateToggle({
		Name = 'Limit to items',
		Default = false,
		Tooltip = 'Only throw pearls when holding a pearl'
	})
end)


	
run(function()
	local AutoPlay
	local Random
	local BypassAFK
	local queuedThisMatch = false
	local afkRemote
	
	local function isEveryoneDead()
		local success, result = pcall(function()
			if not bedwars or not bedwars.Store then return false end
			local state = bedwars.Store:getState()
			if state and state.Party and state.Party.members then
				return #state.Party.members <= 0
			end
			return false
		end)
		
		return success and result or false
	end
	
	local function canQueue()
		local success, result = pcall(function()
			if not bedwars or not bedwars.Store then return false end
			local state = bedwars.Store:getState()
			return state 
				and state.Game 
				and not state.Game.customMatch 
				and state.Party 
				and state.Party.leader 
				and state.Party.leader.userId == lplr.UserId 
				and state.Party.queueState == 0
		end)
		
		return success and result or false
	end
	
	local function joinQueue()
		if not canQueue() then return end
		if queuedThisMatch then return end
		
		pcall(function()
			if not bedwars or not bedwars.QueueController then 
				return 
			end
			
			if Random.Enabled then
				local listofmodes = {}
				if bedwars.QueueMeta then
					for i, v in bedwars.QueueMeta do
						if type(v) == 'table' and not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
							table.insert(listofmodes, i) 
						end
					end
				end
				
				if #listofmodes > 0 then
					bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
					notif('AutoPlay', 'Joined random queue: '..listofmodes[math.random(1, #listofmodes)], 3)
				else
					bedwars.QueueController:joinQueue('bedwars_test')
					notif('AutoPlay', 'Joined bedwars_test queue', 3)
				end
			else
				local queueType = store.queueType or 'bedwars_test'
				bedwars.QueueController:joinQueue(queueType)
				notif('AutoPlay', 'Joined '..queueType..' queue', 3)
			end
			
			queuedThisMatch = true
		end)
	end
	
	local function findAFKRemote()
		if afkRemote and afkRemote.Parent then return afkRemote end
		
		pcall(function()
			for _, v in replicatedStorage:GetDescendants() do
				if v:IsA('RemoteEvent') and v.Name == 'AfkInfo' then
					afkRemote = v
					return
				end
			end
		end)
		
		return afkRemote
	end
	
	local function bypassAFK()
		if not BypassAFK.Enabled then return end
		
		pcall(function()
			local remote = findAFKRemote()
			if remote and remote.Parent then
				remote:FireServer({afk = false})
			else
				local cam = workspace.CurrentCamera
				if cam then
					cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.001), 0)
				end
			end
		end)
	end
	
	local function checkInstantQueue()
		if not entitylib.isAlive then
			local hasBed = false
			pcall(function()
				if not bedwars or not bedwars.Store then return end
				local state = bedwars.Store:getState()
				if state and state.Bed and lplr.Team then
					local teamName = lplr.Team.Name
					if state.Bed[teamName] then
						hasBed = true
					end
				end
			end)
			
			return not hasBed and isEveryoneDead()
		end
		
		return false
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				queuedThisMatch = false
				
				task.spawn(function()
					repeat
						bypassAFK()
						task.wait(30)
					until not AutoPlay.Enabled
				end)
				
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.entityInstance == lplr.Character then
						task.wait(0.5)
						
						if not queuedThisMatch and checkInstantQueue() then
							bypassAFK()
							task.wait(0.2)
							joinQueue()
						end
					end
				end))
				
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					if not queuedThisMatch then
						bypassAFK()
						task.wait(0.5)
						joinQueue()
					end
					
					task.delay(3, function()
						queuedThisMatch = false
					end)
				end))
				
				AutoPlay:Clean(bedwars.Store.changed:connect(function(state, oldState)
					if state.Game and state.Game.matchState == 2 and 
					   oldState.Game and oldState.Game.matchState ~= 2 then
						if not queuedThisMatch then
							task.wait(1)
							bypassAFK()
							task.wait(0.3)
							joinQueue()
						end
					end
				end))
			end
		end,
		Tooltip = 'Automatically queues after match ends and bypasses AFK'
	})
	
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random gamemode'
	})
	
	BypassAFK = AutoPlay:CreateToggle({
		Name = 'Bypass AFK',
		Default = true,
		Tooltip = 'Prevents AFK kick by sending fake activity'
	})
end)

run(function()
    local ProximityMaxDistance = {Enabled = false}
    local MaxDistance
    local oldDistances = {}
    local addedConnection
    
    ProximityMaxDistance = vape.Categories.Utility:CreateModule({
        Name = "ProximityExtender",
        Function = function(callback)
            
            if callback then
                oldDistances = {}
                
                local function applyToPrompt(prompt)
                    if prompt:IsA("ProximityPrompt") then
                        if oldDistances[prompt] == nil then
                            oldDistances[prompt] = prompt.MaxActivationDistance
                        end
                        prompt.MaxActivationDistance = MaxDistance.Value
                    end
                end
                
                for _, obj in ipairs(workspace:GetDescendants()) do
                    applyToPrompt(obj)
                end
                
                addedConnection = workspace.DescendantAdded:Connect(function(obj)
                    applyToPrompt(obj)
                end)
            else
                if addedConnection then
                    addedConnection:Disconnect()
                    addedConnection = nil
                end
                
                for prompt, dist in pairs(oldDistances) do
                    if prompt and prompt.Parent then
                        prompt.MaxActivationDistance = dist
                    end
                end
                oldDistances = {}
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
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'aerov4 on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)
	
run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
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
end)
	
run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
							end
							
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								task.spawn(function()
									bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.SoundManager:playSound(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
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
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)
	
run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Utility:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)
	
run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local adjacent, lastpos, label = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local isHoldingSwordOrTool = store.hand.toolType == 'sword' or (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].sword)
			if not isHoldingSwordOrTool then
				local wool, amount = getWool()
				if wool then
					return wool, amount
				else
					for _, item in store.inventory.inventory.items do
						if bedwars.ItemMeta[item.itemType].block then
							return item.itemType, item.amount
						end
					end
				end
			end
		end
	
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()

						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end

						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end

						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end

							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end

								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										task.spawn(bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end

					task.wait(0.03)
				until not Scaffold.Enabled
			else
				if label then
					label.Visible = false
				end
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				if label then
					label:Destroy()
					label = nil
				end
			end
		end
	})
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
        
        -- alt method: check if the module exists as a regular module if not gg
        local shopModule = game:GetService("ReplicatedStorage"):FindFirstChild("TS"):FindFirstChild("games"):FindFirstChild("bedwars"):FindFirstChild("shop"):FindFirstChild("bedwars-shop")
        if shopModule and shopModule:IsA("ModuleScript") then
            return require(shopModule)
        end
        
        return nil
    end
    
    ShopTierBypass = vape.Categories.Utility:CreateModule({
        Name = 'Shop Tier Bypass',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.shopLoaded or not ShopTierBypass.Enabled
                if ShopTierBypass.Enabled then
                    for _, v in pairs(bedwars.Shop.ShopItems) do
                        tiered[v] = v.tiered
                        nexttier[v] = v.nextTier
                        v.nextTier = nil
                        v.tiered = nil
                        shopItemsTracked[v] = true
                    end
                    
                    if bedwars.Shop.getShop and not originalGetShop then
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
                    local shopController = getShopController()
                    if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
                    end
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
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Disables Snap Traps'
	})
end)
	
run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end
	
				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
						v:Disconnect()
					end
				end
	
				bedwars.Client:Get(remotes.AfkStatus):SendToServer({
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)

run(function()
    local AutoBuildUp
    local LimitItem
    local facesOnly = {
        Vector3.new(3, 0, 0),   
        Vector3.new(-3, 0, 0), 
        Vector3.new(0, 3, 0),   
        Vector3.new(0, -3, 0),  
        Vector3.new(0, 0, 3),   
        Vector3.new(0, 0, -3) 
    }
    
    local function checkFaceAdjacent(pos)
        for _, v in facesOnly do
            if getPlacedBlock(pos + v) then
                return true
            end
        end
        return false
    end
    
    local function hasFaceBelowOrSide(pos)
        if getPlacedBlock(pos - Vector3.new(0, 3, 0)) then
            return true
        end
        
        for _, v in facesOnly do
            if v.Y == 0 and getPlacedBlock(pos + v) then
                return true
            end
        end
        
        return false
    end
    
    local function nearCorner(poscheck, pos)
        local startpos = poscheck - Vector3.new(3, 3, 3)
        local endpos = poscheck + Vector3.new(3, 3, 3)
        local check = poscheck + (pos - poscheck).Unit * 100
        return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
    end
    
    local function blockProximity(pos)
        local mag, returned = 60
        local tab = getBlocksInPoints(
            bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), 
            bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21))
        )
        
        for _, v in tab do
            local blockpos = nearCorner(v, pos)
            local newmag = (pos - blockpos).Magnitude
            
            if hasFaceBelowOrSide(blockpos) and newmag < mag then
                mag, returned = newmag, blockpos
            end
        end
        
        table.clear(tab)
        return returned
    end
    
    local function getScaffoldBlock()
        if LimitItem.Enabled then
            if store.hand.toolType == 'block' then
                return store.hand.tool.Name
            end
            return nil
        else
            local wool = getWool()
            if wool then
                return wool
            else
                for _, item in store.inventory.inventory.items do
                    if bedwars.ItemMeta[item.itemType].block then
                        return item.itemType
                    end
                end
            end
        end
        return nil
    end
    
    local function canPlaceAtPosition(blockpos)
        if not checkFaceAdjacent(blockpos) then
            return false
        end
        
        local checkBelow = blockpos - Vector3.new(0, 3, 0)
        local hasSupport = false
        
        for i = 1, 10 do
            if getPlacedBlock(checkBelow) then
                hasSupport = true
                break
            end
            checkBelow = checkBelow - Vector3.new(0, 3, 0)
        end
        
        return hasSupport or hasFaceBelowOrSide(blockpos)
    end
    
    AutoBuildUp = vape.Categories.World:CreateModule({
        Name = 'AutoBuildUp',
        Function = function(callback)
            
            if callback then
                repeat
                    if entitylib.isAlive then
                        local wool = getScaffoldBlock()
                        
                        if wool then
                            local root = entitylib.character.RootPart
                            
                            if inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
                                local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
                                
                                local block, blockpos = getPlacedBlock(currentpos)
                                if not block then
                                    blockpos = blockpos * 3
                                    
                                    if hasFaceBelowOrSide(blockpos) then
                                        if canPlaceAtPosition(blockpos) then
                                            task.spawn(bedwars.placeBlock, blockpos, wool, false)
                                        end
                                    else
                                        local nearestBlock = blockProximity(currentpos)
                                        if nearestBlock and canPlaceAtPosition(nearestBlock) then
                                            task.spawn(bedwars.placeBlock, nearestBlock, wool, false)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    task.wait(0.03)
                until not AutoBuildUp.Enabled
            end
        end,
        Tooltip = 'Automatically places blocks under you ONLY when jumping (no corner connections)'
    })
    
    LimitItem = AutoBuildUp:CreateToggle({
        Name = 'Limit to items',
        Default = false,
        Tooltip = 'Only place blocks when holding a block item'
    })
end)

run(function()
    local AutoBuildStraight
    local LimitItem
    local Range
    
    local facesOnly = {
        Vector3.new(3, 0, 0),   
        Vector3.new(-3, 0, 0), 
        Vector3.new(0, 3, 0),   
        Vector3.new(0, -3, 0),  
        Vector3.new(0, 0, 3),   
        Vector3.new(0, 0, -3) 
    }
    
    local function checkFaceAdjacent(pos)
        for _, v in facesOnly do
            if getPlacedBlock(pos + v) then
                return true
            end
        end
        return false
    end
    
    local function getScaffoldBlock()
        if LimitItem.Enabled then
            if store.hand.toolType == 'block' then
                return store.hand.tool.Name
            end
            return nil
        else
            local wool = getWool()
            if wool then
                return wool
            else
                for _, item in store.inventory.inventory.items do
                    if bedwars.ItemMeta[item.itemType].block then
                        return item.itemType
                    end
                end
            end
        end
        return nil
    end
    
    AutoBuildStraight = vape.Categories.World:CreateModule({
        Name = 'AutoBuildStraight',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        local wool = getScaffoldBlock()
                        
                        if wool then
                            local root = entitylib.character.RootPart
                            local humanoid = entitylib.character.Humanoid
                            
                            if humanoid.MoveDirection.Magnitude > 0.1 then
                                local lookDir = gameCamera.CFrame.LookVector
                                local horizontalLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
                                
                                local playerFeetPos = root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0)
                                
                                for distance = 3, Range.Value, 3 do
                                    local checkPos = playerFeetPos + (horizontalLook * distance)
                                    local currentpos = roundPos(checkPos)
                                    
                                    local block, blockpos = getPlacedBlock(currentpos)
                                    
                                    if not block then
                                        blockpos = blockpos * 3
                                        
                                        if checkFaceAdjacent(blockpos) then
                                            task.spawn(bedwars.placeBlock, blockpos, wool, false)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    task.wait(0.05)
                until not AutoBuildStraight.Enabled
            end
        end,
        Tooltip = 'Automatically extends blocks straight ahead when moving'
    })
    
    Range = AutoBuildStraight:CreateSlider({
        Name = 'Range',
        Min = 3,
        Max = 30,
        Default = 12,
        Tooltip = 'Maximum distance ahead to place blocks'
    })
    
    LimitItem = AutoBuildStraight:CreateToggle({
        Name = 'Limit to items',
        Default = false,
        Tooltip = 'Only place blocks when holding a block item'
    })
end)
	
run(function()
	local AutoSuffocate
	local Range
	local LimitItem
	local InstantSuffocate
	local SmartMode
	local RequireMouseDown 
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	
	local function countSurroundingBlocks(pos)
		local count = 0
		for _, side in Enum.NormalId:GetEnumItems() do
			if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
			local checkPos = fixPosition(pos + Vector3.fromNormalId(side) * 2)
			if getPlacedBlock(checkPos) then
				count += 1
			end
		end
		return count
	end
	
	local function isInVoid(pos)
		for i = 1, 10 do
			local checkPos = fixPosition(pos - Vector3.new(0, i * 3, 0))
			if getPlacedBlock(checkPos) then
				return false
			end
		end
		return true
	end
	
	local function getSmartSuffocationBlocks(ent)
		local rootPos = ent.RootPart.Position
		local headPos = ent.Head.Position
		local needPlaced = {}
		local surroundingBlocks = countSurroundingBlocks(rootPos)
		local inVoid = isInVoid(rootPos)
		
		if surroundingBlocks >= 1 and surroundingBlocks <= 2 then
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				if not getPlacedBlock(sidePos) then
					table.insert(needPlaced, sidePos)
				end
			end
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		elseif inVoid then
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
			table.insert(needPlaced, fixPosition(headPos + Vector3.new(0, 3, 0)))
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				table.insert(needPlaced, sidePos)
			end
			table.insert(needPlaced, fixPosition(headPos))
		
		elseif surroundingBlocks == 3 then
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				if not getPlacedBlock(sidePos) then
					table.insert(needPlaced, sidePos)
				end
			end
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		elseif surroundingBlocks >= 4 then
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		else
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				table.insert(needPlaced, sidePos)
			end
			table.insert(needPlaced, fixPosition(headPos))
		end
		
		return needPlaced
	end
	
	local function getBasicSuffocationBlocks(ent)
		local needPlaced = {}
		
		for _, side in Enum.NormalId:GetEnumItems() do
			side = Vector3.fromNormalId(side)
			if side.Y ~= 0 then continue end
			
			side = fixPosition(ent.RootPart.Position + side * 2)
			if not getPlacedBlock(side) then
				table.insert(needPlaced, side)
			end
		end
		
		if #needPlaced < 3 then
			table.insert(needPlaced, fixPosition(ent.Head.Position))
			table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))
		end
		
		return needPlaced
	end
	
	AutoSuffocate = vape.Categories.World:CreateModule({
		Name = 'AutoSuffocate',
		Function = function(callback)
			if callback then
				repeat
					if RequireMouseDown.Enabled and not inputService:IsMouseButtonPressed(0) then
						task.wait(0.05)
						continue
					end
					
					local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()
	
					if item then
						local plrs = entitylib.AllPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = true
						})
	
						for _, ent in plrs do
							local needPlaced = SmartMode.Enabled and getSmartSuffocationBlocks(ent) or getBasicSuffocationBlocks(ent)
	
							if InstantSuffocate.Enabled then
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
									end
								end
							else
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
										break
									end
								end
							end
						end
					end
	
					task.wait(InstantSuffocate.Enabled and 0.05 or 0.09)
				until not AutoSuffocate.Enabled
			end
		end,
		Tooltip = 'Places blocks on nearby confined entities'
	})
	
	Range = AutoSuffocate:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Function = function() end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	SmartMode = AutoSuffocate:CreateToggle({
		Name = 'Smart Mode',
		Default = true,
		Tooltip = 'Detects scenarios: walls, void, corners, open areas'
	})
	
	LimitItem = AutoSuffocate:CreateToggle({
		Name = 'Limit to Items',
		Default = true,
		Function = function() end
	})
	
	InstantSuffocate = AutoSuffocate:CreateToggle({
		Name = 'Instant Suffocate',
		Function = function() end,
		Tooltip = 'Instantly places all suffocation blocks instead of one at a time'
	})
	
	RequireMouseDown = AutoSuffocate:CreateToggle({
		Name = 'Require Mouse Down',
		Default = false,
		Function = function() end,
		Tooltip = 'Requires left mouse button to be held down to activate'
	})
end)
	
run(function()
	local AutoTool
	local old, event
	
	local function switchHotbarItem(block)
		if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
			local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
			if tool then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
				end
	
				if hotbarSwitch(slot) then
					if inputService:IsMouseButtonPressed(0) then 
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
					contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
				end))
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
					if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
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
	local BedProtector
	
	local function getBedNear()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude < 20 and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
				return v
			end
		end
	end
	
	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[item.itemType].block
			if block then
				table.insert(blocks, {item.itemType, block.health})
			end
		end
		table.sort(blocks, function(a, b) 
			return a[2] > b[2]
		end)
		return blocks
	end
	
	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end
	
	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				local bed = getBedNear()
				bed = bed and bed.Position or nil
				if bed then
					for i, block in getBlocks() do
						for _, pos in getPyramid(i, 3) do
							if not BedProtector.Enabled then break end
							if getPlacedBlock(bed + pos) then continue end
							bedwars.placeBlock(bed + pos, block[1], false)
						end
					end
					if BedProtector.Enabled then 
						BedProtector:Toggle() 
					end
				else
					notif('BedProtector', 'Cant locate bed', 5)
					BedProtector:Toggle()
				end
			end
		end,
		Tooltip = 'Places strongest blocks around the bed'
	})
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local DelayToggle
	local DelaySlider
	local Delays = {}
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
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
end)
	
run(function()
	local Schematica
	local File
	local Mode
	local Transparency
	local parts, guidata, poschecklist = {}, {}, {}
	local point1, point2
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				if Vector3.new(x, y, z) ~= Vector3.zero then
					table.insert(poschecklist, Vector3.new(x, y, z))
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in poschecklist do
			if getPlacedBlock(pos + v) then return true end
		end
		return false
	end
	
	local function getPlacedBlocksInPoints(s, e)
		local list, blocks = {}, bedwars.BlockController:getStore()
		for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
			for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
				for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
					local vec = Vector3.new(x, y, z)
					local block = blocks:getBlockAt(vec)
					if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
						list[vec] = block
					end
				end
			end
		end
		return list
	end
	
	local function loadMaterials()
		for _, v in guidata do 
			v:Destroy() 
		end
		local suc, read = pcall(function() 
			return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
		end)
	
		if suc and read then
			local items = {}
			for _, v in read do 
				items[v[2]] = (items[v[2]] or 0) + 1 
			end
			
			for i, v in items do
				local holder = Instance.new('Frame')
				holder.Size = UDim2.new(1, 0, 0, 32)
				holder.BackgroundTransparency = 1
				holder.Parent = Schematica.Children
				local icon = Instance.new('ImageLabel')
				icon.Size = UDim2.fromOffset(24, 24)
				icon.Position = UDim2.fromOffset(4, 4)
				icon.BackgroundTransparency = 1
				icon.Image = bedwars.getIcon({itemType = i}, true)
				icon.Parent = holder
				local text = Instance.new('TextLabel')
				text.Size = UDim2.fromOffset(100, 32)
				text.Position = UDim2.fromOffset(32, 0)
				text.BackgroundTransparency = 1
				text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextColor3 = uipallet.Text
				text.TextSize = 14
				text.FontFace = uipallet.Font
				text.Parent = holder
				table.insert(guidata, holder)
			end
			table.clear(read)
			table.clear(items)
		end
	end
	
	local function save()
		if point1 and point2 then
			local tab = getPlacedBlocksInPoints(point1, point2)
			local savetab = {}
			point1 = point1 * 3
			for i, v in tab do
				i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
				table.insert(savetab, {
					{
						x = i.X, 
						y = i.Y, 
						z = i.Z
					}, 
					v.Name
				})
			end
			point1, point2 = nil, nil
			writefile(File.Value, httpService:JSONEncode(savetab))
			notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
			loadMaterials()
			table.clear(tab)
			table.clear(savetab)
		else
			local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
			if mouseinfo and mouseinfo.target then
				if point1 then
					point2 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
				else
					point1 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 1', 3)
				end
			end
		end
	end
	
	local function load(read)
		local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
		if mouseinfo and mouseinfo.target then
			local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)
	
			for _, v in read do
				local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
				if parts[blockpos] then continue end
				local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
				if handler then
					local part = handler:place(blockpos / 3, 0)
					part.Transparency = Transparency.Value
					part.CanCollide = false
					part.Anchored = true
					part.Parent = workspace
					parts[blockpos] = part
				end
			end
			table.clear(read)
	
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in parts do
						if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
							if not Schematica.Enabled then break end
							if not getItem(v.Name) then continue end
							bedwars.placeBlock(i, v.Name, false)
							task.delay(0.1, function()
								local block = getPlacedBlock(i)
								if block then
									v:Destroy()
									parts[i] = nil
								end
							end)
						end
					end
				end
				task.wait()
			until getTableSize(parts) <= 0
	
			if getTableSize(parts) <= 0 and Schematica.Enabled then
				notif('Schematica', 'Finished building', 5)
				Schematica:Toggle()
			end
		end
	end
	
	Schematica = vape.Categories.World:CreateModule({
		Name = 'Schematica',
		Function = function(callback)
			if callback then
				if not File.Value:find('.json') then
					notif('Schematica', 'Invalid file', 3)
					Schematica:Toggle()
					return
				end
	
				if Mode.Value == 'Save' then
					save()
					Schematica:Toggle()
				else
					local suc, read = pcall(function() 
						return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
					end)
	
					if suc and read then
						load(read)
					else
						notif('Schematica', 'Missing / corrupted file', 3)
						Schematica:Toggle()
					end
				end
			else
				for _, v in parts do 
					v:Destroy() 
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Save and load placements of buildings'
	})
	File = Schematica:CreateTextBox({
		Name = 'File',
		Function = function()
			loadMaterials()
			point1, point2 = nil, nil
		end
	})
	Mode = Schematica:CreateDropdown({
		Name = 'Mode',
		List = {'Load', 'Save'}
	})
	Transparency = Schematica:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.7,
		Decimal = 10,
		Function = function(val)
			for _, v in parts do 
				v.Transparency = val 
			end
		end
	})
end)
	
run(function()
	local ArmorSwitch
	local Mode
	local Targets
	local Range
	
	ArmorSwitch = vape.Categories.Inventory:CreateModule({
		Name = 'ArmorSwitch',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Toggle' then
					repeat
						local state = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) and true or false
	
						for i = 0, 2 do
							if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
						task.wait(0.1)
					until not ArmorSwitch.Enabled
				else
					ArmorSwitch:Toggle()
					for i = 0, 2 do
						bedwars.Store:dispatch({
							type = 'InventorySetArmorItem',
							item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
							armorSlot = i
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
			end
		end,
		Tooltip = 'Puts on / takes off armor when toggled for baiting.'
	})
	Mode = ArmorSwitch:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'}
	})
	Targets = ArmorSwitch:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ArmorSwitch:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
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
		for i, v in Items do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end
	
	local function nearChest()
		if entitylib.isAlive then
			local pos = entitylib.character.RootPart.Position
			for _, chest in Chests do
				if (chest.Position - pos).Magnitude < 22 then
					return true
				end
			end
		end
	end
	
	local function handleState()
		local chest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
		if not chest then return end
		
		if not nearChest() and not GUICheck.Enabled then 
			return 
		end
	
		for _, v in store.inventory.inventory.items do
			local item = Items[v.itemType]
			if item and BankToggles[v.itemType] and BankToggles[v.itemType].Enabled then
				task.spawn(function()
					bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(chest, v.tool)
					refreshBank(chest)
				end)
			end
		end
	end
	
	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('personal-chest', AutoBank)
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
	
				repeat
					local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
					hotbar = hotbar and hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
					if hotbar then
						UI.Position = UDim2.fromOffset(0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 40)
					end
	
					local shouldBank = false
					
					if GUICheck.Enabled then
						if bedwars.AppController:isAppOpen('ChestApp') or 
						   bedwars.AppController:isAppOpen('BedwarsAppIds.CHEST_INVENTORY') then
							shouldBank = true
						end
					else
						shouldBank = nearChest()
					end
					
					if shouldBank then
						handleState()
					end
	
					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
			end
		end,
		Tooltip = 'Automatically puts resources in ender chest'
	})
	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled then
				UI.Visible = callback
			end
		end,
		Default = true
	})
	GUICheck = AutoBank:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'Only banks items when chest is open (bypasses distance limit)'
	})
	BankToggles.iron = AutoBank:CreateToggle({
		Name = 'Bank Iron',
		Tooltip = 'Automatically bank iron',
		Default = true
	})
	BankToggles.diamond = AutoBank:CreateToggle({
		Name = 'Bank Diamond',
		Tooltip = 'Automatically bank diamonds',
		Default = true
	})
	BankToggles.emerald = AutoBank:CreateToggle({
		Name = 'Bank Emerald',
		Tooltip = 'Automatically bank emeralds',
		Default = true
	})
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
		bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
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
    local BuyBlocksModule
    local GUICheck
    local DelaySlider
    local running = false

    local function getShopNPC()
        local shopFound = false
        if entitylib.isAlive then
            local localPosition = entitylib.character.RootPart.Position
            for _, v in store.shop do
                if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                    shopFound = true
                    break
                end
            end
        end
        return shopFound
    end

    BuyBlocksModule = vape.Categories.Inventory:CreateModule({
        Name = "BuyBlocks",
        Function = function(enabled)
            running = enabled

            if enabled then
                task.spawn(function()
                    while running do
                        local canBuy = true
                        
                        if GUICheck.Enabled then
                            if bedwars.AppController:isAppOpen('BedwarsItemShopApp') then
                                canBuy = true
                            else
                                canBuy = false
                            end
                        else
                            canBuy = getShopNPC()
                        end

                        if canBuy then
                            local args = {
                                {
                                    shopItem = {
                                        currency = "iron",
                                        itemType = "wool_white",
                                        amount = 16,
                                        price = 8,
                                        disabledInQueue = {
                                            "mine_wars"
                                        },
                                        category = "Blocks"
                                    },
                                    shopId = "1_item_shop"
                                }
                            }

                            pcall(function()
                                game:GetService("ReplicatedStorage")
                                :WaitForChild("rbxts_include")
                                :WaitForChild("node_modules")
                                :WaitForChild("@rbxts")
                                :WaitForChild("net")
                                :WaitForChild("out")
                                :WaitForChild("_NetManaged")
                                :WaitForChild("BedwarsPurchaseItem")
                                :InvokeServer(unpack(args))
                            end)
                        end

                        task.wait(DelaySlider.Value)
                    end
                end)
            end
        end,
        Tooltip = "Automatically buys wool blocks"
    })

    GUICheck = BuyBlocksModule:CreateToggle({
        Name = "GUI Check",
        Tooltip = "Only buy when shop GUI is open",
        Default = false
    })

    DelaySlider = BuyBlocksModule:CreateSlider({
        Name = "Delay",
        Min = 0.1,
        Max = 2,
        Default = 0.1,
        Decimal = 10,
        Tooltip = "Delay between purchases (seconds)"
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
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						task.spawn(bedwars.ItemDropController.dropItemInHand)
						task.wait()
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			end
		end,
		Tooltip = 'Drops items fast when you hold Q'
	})
end)
	
run(function()
	local BedPlates
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, side in sides do
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
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local alreadygot = {}
		scanSide(v.Adornee, start, alreadygot)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
		end)
		v.Enabled = #alreadygot > 0
	
		for _, block in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
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
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.Minigames:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do 
					task.spawn(Added, v) 
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then 
				Color.Object.Visible = callback 
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
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
    local GetHost = {Enabled = false}
    
    GetHost = vape.Categories.Utility:CreateModule({
        Name = "GetHost (Client-Sided)",
        Tooltip = "Client Sided Host Panel",
        Function = function(callback)
            
            if callback then
                game.Players.LocalPlayer:SetAttribute("CustomMatchRole", "host")
            else
                game.Players.LocalPlayer:SetAttribute("CustomMatchRole", nil)
            end
        end
    })
end)

run(function()
	local char = lplr.Character or lplr.CharacterAdded:wait()
	local Headless = {Enabled = false}
	local faceTransparencyBackup = nil
	
	Headless = vape.Categories.Utility:CreateModule({
		PerformanceModeBlacklisted = true,
		Name = 'Headless',
		Tooltip = 'free headless 2025',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat 
						task.wait()
						if entitylib.isAlive and entitylib.character.Character and entitylib.character.Head then
							entitylib.character.Head.Transparency = 1
							
							local face = entitylib.character.Head:FindFirstChild('face')
							if face and face:IsA("Decal") and faceTransparencyBackup == nil then
								faceTransparencyBackup = face.Transparency
								face.Transparency = 1
							end
						end
					until not Headless.Enabled
				end)
			else
				if entitylib.isAlive and entitylib.character.Character and entitylib.character.Head then
					entitylib.character.Head.Transparency = 0
					
					local face = entitylib.character.Head:FindFirstChild('face')
					if face and face:IsA("Decal") and faceTransparencyBackup ~= nil then
						face.Transparency = faceTransparencyBackup
						faceTransparencyBackup = nil
					end
				end
			end
		end,
		Default = false
	})
end)

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(game:GetService("Players").LocalPlayer.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Players = game:GetService("Players")

	shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT = shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT or Knit.Controllers.PermissionController.hasAnyPermissions
	shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT = shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT or Knit.Controllers.MatchController.getPlayerParty

	local AC_MOD_View = {
		playerConnections = {},
		Enabled = false,
		Friends = {}, 
		parties = {}, 
		teamMap = {}, 
		display = {},
		isRefreshing = false,
		cacheDirty = true,
		disable_disguises = false,
		disguises = {},
		teamData = {}
	}

	AC_MOD_View.controller = Knit.Controllers.PermissionController
	AC_MOD_View.match_controller = Knit.Controllers.MatchController

	function AC_MOD_View:getPartyById(displayId)
		if not displayId then return end
		displayId = tostring(displayId)
		if self.display[displayId] then return self.display[displayId] end
		for _, party in pairs(self.parties) do
			if party.displayId == tostring(displayId) then
				self.display[displayId] = party
				return party
			end
		end
	end

	function AC_MOD_View:refreshDisplayCache()
		for _, plr in pairs(Players:GetPlayers()) do
			local playerId = tostring(plr.UserId)

			local playerPartyId = self.teamMap[playerId]
			if playerPartyId ~= nil then
				self:getPartyById(playerPartyId)
			end
			task.wait()
		end
	end

	function AC_MOD_View:refreshDisplayCacheAsync()
		task.spawn(self.refreshDisplayCache, self)
	end

	function AC_MOD_View:getPlayerTeamData(plr)
		if self.teamData[plr] then return self.teamData[plr] end

		self.teamData[plr] = {}

		local teamMembers = {}
		local playerTeam = plr.Team 
		if not playerTeam then
			return teamMembers 
		end

		local playerId = tostring(plr.UserId)
		self.Friends[playerId] = self.Friends[playerId] or {}

		for _, otherPlayer in pairs(Players:GetPlayers()) do
			if otherPlayer == plr then continue end 

			local otherPlayerId = tostring(otherPlayer.UserId)
			local areFriends = self.Friends[playerId][otherPlayerId]

			if areFriends == nil then
				local suc, res = pcall(function()
					return plr:IsFriendsWith(otherPlayer.UserId)
				end)
				areFriends = suc and res or false

				if suc then
					self.Friends = self.Friends or {}
					self.Friends[playerId] = self.Friends[playerId] or {}
					self.Friends[playerId][otherPlayerId] = areFriends
					self.Friends[otherPlayerId] = self.Friends[otherPlayerId] or {}
					self.Friends[otherPlayerId][playerId] = areFriends
				end
			end

			if areFriends and otherPlayer.Team == playerTeam then
				table.insert(teamMembers, otherPlayerId)
			end
		end

		self.teamData[plr] = teamMembers

		return teamMembers
	end

	function AC_MOD_View:refreshPlayerTeamData()
		for i,v in pairs(Players:GetPlayers()) do
			self:getPlayerTeamData(v)
			task.wait()
		end
	end

	function AC_MOD_View:refreshPlayerTeamDataAsync()
		task.spawn(self.refreshPlayerTeamData, self)
	end

	function AC_MOD_View:refreshTeamMap()
		local allTeams = {}
		for _, p in pairs(Players:GetPlayers()) do
			local teamMembers = self:getPlayerTeamData(p)
			if teamMembers and #teamMembers > 0 then 
				allTeams[p] = teamMembers
			end
		end

		local validTeams = {}
		for playerInTeams, members in pairs(allTeams) do
			local playerIdInTeams = tostring(playerInTeams.UserId)
			local cleanedMembers = {}

			for _, memberId in pairs(members) do
				local memberIdStr = tostring(memberId)
				if memberIdStr == playerIdInTeams then
					print("Warning: Player " .. playerIdInTeams .. " has themselves in their team list.")
				else
					table.insert(cleanedMembers, memberIdStr)
				end
			end

			if #cleanedMembers > 0 then
				validTeams[playerInTeams] = cleanedMembers
			end
		end

		self.parties = {}
		self.teamMap = {}
		local teamId = 0
		for playerInTeams, members in pairs(validTeams) do
			local playerIdInTeams = tostring(playerInTeams.UserId)
			if not self.teamMap[playerIdInTeams] then
				self.teamMap[playerIdInTeams] = teamId
				table.insert(self.parties, {
					displayId = tostring(teamId),
					members = members
				})
				teamId = teamId + 1

				for _, memberId in pairs(members) do
					self.teamMap[memberId] = teamId - 1
				end
			end
		end

		self.cacheDirty = false
		self.isRefreshing = false
	end

	function AC_MOD_View:refreshTeamMapAsync()
		if self.isRefreshing then return end 
		self.isRefreshing = true
		task.spawn(function()
			self:refreshTeamMap()
		end)
	end

	function AC_MOD_View:getPlayerParty(plr)
		if not plr or not plr:IsA("Player") then
			return nil
		end

		local playerId = tostring(plr.UserId)

		if self.cacheDirty or not next(self.teamMap) then
			self:refreshTeamMapAsync()
		end

		local playerPartyId = self.teamMap[playerId]
		if playerPartyId ~= nil then
			return self:getPartyById(playerPartyId)
		end

		return nil 
	end

	AC_MOD_View.mockGetPlayerParty = function(self, plr)
		local parties = self.parties 
		if parties ~= nil and #parties > 0 then
			return shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT(self, plr)
		end
		return AC_MOD_View:getPlayerParty(plr)
	end

	function AC_MOD_View:toggleDisableDisguises()
		if not self.Enabled then return end
		if self.disable_disguises then
			for _,v in pairs(Players:GetPlayers()) do
				if v == Players.LocalPlayer then continue end
				if tostring(v:GetAttribute("Disguised")) == "true" then
					v:SetAttribute("Disguised", false)
					notif("Remove Disguises", "Disabled streamer mode for "..tostring(v.Name).."!", 3)
					table.insert(self.disguises, v)
				end
			end
		else
			for i,v in pairs(self.disguises) do
				if tostring(v:GetAttribute("Disguised")) ~= "true" then
					v:SetAttribute("Disguised", true)
					notif("Remove Disguises", "Re - enabled Streamer mode for "..tostring(v.Name).."!", 2)
				end
			end
			table.clear(self.disguises)
		end
	end

	function AC_MOD_View:refreshCore()
		self:refreshTeamMapAsync()
		self:refreshDisplayCacheAsync()
		self:refreshPlayerTeamDataAsync()

		self:toggleDisableDisguises()
	end

	function AC_MOD_View:refreshCoreAsync()
		task.spawn(self.refreshCore, self)
	end

	function AC_MOD_View:init()
		self.Enabled = true
		self.controller.hasAnyPermissions = function(self)
			return true
		end
		self.match_controller.getPlayerParty = self.mockGetPlayerParty

		self.playerConnections = {
			added = Players.PlayerAdded:Connect(function(player)
				self.cacheDirty = true
				self:refreshCoreAsync()
				player:GetPropertyChangedSignal("Team"):Connect(function()
					self.cacheDirty = true
					self:refreshCoreAsync()
				end)
			end),
			removed = Players.PlayerRemoving:Connect(function(player)
				local playerId = tostring(player.UserId)
				self.Friends[playerId] = nil 
				for _, cache in pairs(self.Friends) do
					cache[playerId] = nil
				end
				self.cacheDirty = true
				self:refreshCoreAsync()
			end)
		}

		self:refreshCore()
	end

	function AC_MOD_View:disable()
		self.Enabled = false

		self.controller.hasAnyPermissions = shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT
		self.match_controller.getPlayerParty = shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT

		if self.playerConnections then
			for _, v in pairs(self.playerConnections) do
				pcall(function() v:Disconnect() end)
			end
			table.clear(self.playerConnections)
		end

		self.parties = {}
		self.teamMap = {}
		self.Friends = {}
		self.display = {}
		self.teamData = {}
		self.cacheDirty = true

		self:toggleDisableDisguises()
	end
	shared.ACMODVIEWENABLED = false
	AC_MOD_View.moduleInstance = vape.Categories.World:CreateModule({
		Name = "AC MOD View",
		Function = function(call)
			shared.ACMODVIEWENABLED = call
			if call then
				AC_MOD_View:init()
			else
				AC_MOD_View:disable()
			end
		end
	})

	AC_MOD_View.disableDisguisesToggle = AC_MOD_View.moduleInstance:CreateToggle({
		Name = "Remove Disguises",
		Function = function(call)
			AC_MOD_View.disable_disguises = call
			AC_MOD_View:toggleDisableDisguises()
		end,
		Default = true
	})
end)
	
run(function()
	local Breaker
	local Delay
	local Range
	local UpdateRate
	local Custom
	local Bed
	local LuckyBlock
	local AutoTool
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local LimitItem
	local BreakClosestBlock
	local MouseDown
	local customlist, parts = {}, {}
	local lastPlayerPosition = nil
	local currentTargetBlock = nil
	
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
			Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end
	
	local hit = 0
	
	local sides = {}
	for _, v in Enum.NormalId:GetEnumItems() do
		if v.Name == "Bottom" then continue end
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function hasDirectPathToBed(bedPos, playerPos)
		local direction = (bedPos - playerPos).Unit
		local distance = (bedPos - playerPos).Magnitude
		
		for i = 3, distance, 3 do
			local checkPos = playerPos + (direction * i)
			local block = getPlacedBlock(checkPos)
			
			if block and (checkPos - bedPos).Magnitude > 3 then
				if bedwars.BlockController:isBlockBreakable({blockPosition = checkPos / 3}, lplr) then
					return false, checkPos 
				end
			end
		end
		
		return true, nil
	end

	local function findClosestBlockInPath(bedPos, playerPos)
		local closestBlock = nil
		local closestDistance = math.huge
		local closestPos = nil
		local closestNormal = nil

		local vectorToNormalId = {
			[Vector3.new(1, 0, 0)] = Enum.NormalId.Right,
			[Vector3.new(-1, 0, 0)] = Enum.NormalId.Left,
			[Vector3.new(0, 1, 0)] = Enum.NormalId.Top,
			[Vector3.new(0, -1, 0)] = Enum.NormalId.Bottom,
			[Vector3.new(0, 0, 1)] = Enum.NormalId.Front,
			[Vector3.new(0, 0, -1)] = Enum.NormalId.Back
		}

		for _, side in sides do
			for i = 1, 15 do
				local blockPos = bedPos + (side * i)
				local block = getPlacedBlock(blockPos)
				if not block or block:GetAttribute("NoBreak") then break end
				
				if bedwars.BlockController:isBlockBreakable({blockPosition = blockPos / 3}, lplr) then
					local distToPlayer = (playerPos - blockPos).Magnitude
					
					if distToPlayer < closestDistance then
						closestDistance = distToPlayer
						closestBlock = block
						closestPos = blockPos
						local normalizedSide = side.Unit 
						for vector, normalId in pairs(vectorToNormalId) do
							if (normalizedSide - vector).Magnitude < 0.01 then 
								closestNormal = normalId
								break
							end
						end
					end
				end
			end
		end

		return closestBlock, closestPos, closestNormal
	end

	local function hasPlayerMoved(currentPos, threshold)
		if not lastPlayerPosition then
			lastPlayerPosition = currentPos
			return true
		end
		
		local moved = (currentPos - lastPlayerPosition).Magnitude > (threshold or 2)
		if moved then
			lastPlayerPosition = currentPos
		end
		return moved
	end
	
	local function attemptBreak(tab, localPosition, isBed)
		if not tab then return end
		if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return false
		end
		
		table.sort(tab, function(a, b)
			return (a.Position - localPosition).Magnitude < (b.Position - localPosition).Magnitude
		end)
		
		for _, v in tab do
			if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
				if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
				if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
				if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end

				if isBed and BreakClosestBlock.Enabled then
					hit += 1
					
					local hasPath, blockingPos = hasDirectPathToBed(v.Position, localPosition)
					
					if hasPath then
						local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, AutoTool.Enabled)
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
					else
						local playerMoved = hasPlayerMoved(localPosition, 2)
						local targetChanged = currentTargetBlock ~= v
						
						if playerMoved or targetChanged or not currentTargetBlock then
							currentTargetBlock = v
						end
						
						local closestBlock, closestPos, closestNormal = findClosestBlockInPath(v.Position, localPosition)
						
						if closestBlock and closestPos then
							local target, path, endpos = bedwars.breakBlock(closestBlock, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, AutoTool.Enabled)
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
					end
				else
					hit += 1
					local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, AutoTool.Enabled)
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
			end
		end

		return false
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
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
	
				local beds = collection('bed', Breaker)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron-ore', Breaker)
				customlist = collection('block', Breaker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)

				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if attemptBreak(Bed.Enabled and beds, localPosition, true) then continue end
						if attemptBreak(customlist, localPosition, false) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition, false) then continue end
						if attemptBreak(IronOre.Enabled and ironores, localPosition, false) then continue end
	
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Breaker.Enabled
			else
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
				lastPlayerPosition = nil
				currentTargetBlock = nil
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
		Suffix = "s" 
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
		Name = 'Custom',
		Function = function()
			if not customlist then return end
			table.clear(customlist)
			for _, obj in store.blocks do
				if table.find(Custom.ListEnabled, obj.Name) then
					table.insert(customlist, obj)
				end
			end
		end
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
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
	SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Tooltip = 'Automatically switches to the best tool for breaking blocks'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
	BreakClosestBlock = Breaker:CreateToggle({
		Name = 'Break Closest Block',
		Tooltip = 'Only breaks blocks if they block the path to bed. Breaks bed directly if path is clear.',
		Default = false
	})
	MouseDown = Breaker:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'Only breaks blocks when holding left click'
	})
end)

run(function()
	local AntiSuffocate
	local AutoBreak
	local LimitItem
	local BreakDelay
	local connections = {}
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	local function getSurroundingBlocks(pos)
		local blocks = {}
		for _, side in pairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
			local checkPos = fixPosition(pos + Vector3.fromNormalId(side) * 2)
			local block = getPlacedBlock(checkPos)
			if block then
				table.insert(blocks, {block = block, pos = checkPos, side = side})
			end
		end
		local headPos = fixPosition(pos + Vector3.new(0, 3, 0))
		local headBlock = getPlacedBlock(headPos)
		if headBlock then
			table.insert(blocks, {block = headBlock, pos = headPos, side = Enum.NormalId.Top, priority = 1})
		end
		local feetPos = fixPosition(pos - Vector3.new(0, 3, 0))
		local feetBlock = getPlacedBlock(feetPos)
		if feetBlock then
			table.insert(blocks, {block = feetBlock, pos = feetPos, side = Enum.NormalId.Bottom, priority = 2})
		end
		
		return blocks
	end
	
	local function isSuffocating()
		if not entitylib.isAlive then return false end
		
		local pos = entitylib.character.RootPart.Position
		local blocks = getSurroundingBlocks(pos)
		
		local sideBlocks = 0
		local hasHead = false
		local hasFeet = false
		
		for _, blockData in pairs(blocks) do
			if blockData.priority == 1 then
				hasHead = true
			elseif blockData.priority == 2 then
				hasFeet = true
			else
				sideBlocks += 1
			end
		end
		
		return (sideBlocks >= 4 and hasHead) or (sideBlocks >= 3 and hasHead and hasFeet)
	end
	
	local function switchToBreakTool(block)
		if not block or block:GetAttribute('NoBreak') then return false end
		
		local breakType = bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].block and bedwars.ItemMeta[block.Name].block.breakType
		if not breakType then return false end
		
		local tool = store.tools[breakType]
		if not tool then return false end
		
		for i, v in pairs(store.inventory.hotbar) do
			if v.item and v.item.itemType == tool.itemType then
				if hotbarSwitch(i - 1) then
					return true
				end
			end
		end
		
		return false
	end
	
	local function getMostDangerousBlock(blocks)
		local headBlock = nil
		local mostSurrounded = nil
		local maxNeighbors = 0
		
		for _, blockData in pairs(blocks) do
			if blockData.priority == 1 then
				headBlock = blockData
			elseif not blockData.priority then 
				local neighbors = 0
				for _, other in pairs(blocks) do
					if other ~= blockData and not other.priority then
						neighbors += 1
					end
				end
				if neighbors > maxNeighbors then
					maxNeighbors = neighbors
					mostSurrounded = blockData
				end
			end
		end
		
		return headBlock or mostSurrounded or blocks[1]
	end
	
	local lastBreakTime = 0
	local function breakDangerousBlock()
		if not AutoBreak or not AutoBreak.Enabled then return end
		if not entitylib.isAlive then return end
		local currentTime = tick()
		if currentTime - lastBreakTime < BreakDelay.Value then return end
		if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name] and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then
			return
		end
		local pos = entitylib.character.RootPart.Position
		local blocks = getSurroundingBlocks(pos)
		if #blocks < 5 then return end 
		local targetBlock = getMostDangerousBlock(blocks)
		if not targetBlock then return end
		if not bedwars.BlockController:isBlockBreakable({blockPosition = targetBlock.pos / 3}, lplr) then return end
		if not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name] and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then
			if not switchToBreakTool(targetBlock.block) then return end
			task.wait(0.1)
		end
		local success = pcall(function()
			bedwars.breakBlock(targetBlock.block, true, false, nil, false)
		end)
		
		if success then
			lastBreakTime = currentTime
			if notif then
				local blockName = bedwars.ItemMeta[targetBlock.block.Name] and bedwars.ItemMeta[targetBlock.block.Name].displayName or targetBlock.block.Name
				notif("[Anti-Suffocate] Breaking " .. blockName)
			end
		end
	end
	
	AntiSuffocate = vape.Categories.World:CreateModule({
		Name = 'AntiSuffocate',
		Function = function(callback)
			if callback then
				local checkConn = runService.Heartbeat:Connect(function()
					if not AntiSuffocate.Enabled then return end
					
					if isSuffocating() then
						breakDangerousBlock()
					end
				end)
				table.insert(connections, checkConn)
			else
				for _, conn in pairs(connections) do
					if typeof(conn) == "RBXScriptConnection" then
						conn:Disconnect()
					end
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Automatically breaks blocks when being suffocated'
	})
	
	if AntiSuffocate then
		AutoBreak = AntiSuffocate:CreateToggle({
			Name = 'Auto Break',
			Default = true,
			Tooltip = 'Automatically breaks the most dangerous suffocation block'
		})
		
		LimitItem = AntiSuffocate:CreateToggle({
			Name = 'Limit to Items',
			Default = false,
			Tooltip = 'Only breaks when holding a tool (will auto-switch if disabled)'
		})
		
		BreakDelay = AntiSuffocate:CreateSlider({
			Name = 'Break Delay',
			Min = 0,
			Max = 0.5,
			Default = 0.15,
			Decimal = 100,
			Tooltip = 'Delay between breaking blocks',
			Suffix = 's'
		})
	end
end)
	
run(function()
	local BedBreakEffect
	local Mode
	local List
	local NameToId = {}
	
	BedBreakEffect = vape.Categories.Legit:CreateModule({
		Name = 'Bed Break Effect',
		Function = function(callback)
			if callback then
	            BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
	                firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
	                    player = data.player,
	                    position = data.bedBlockPosition * 3,
	                    effectType = NameToId[List.Value],
	                    teamId = data.brokenBedTeam.id,
	                    centerBedPosition = data.bedBlockPosition * 3
	                })
	            end))
	        end
		end,
		Tooltip = 'Custom bed break effects'
	})
	local BreakEffectName = {}
	for i, v in bedwars.BedBreakEffectMeta do
		table.insert(BreakEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(BreakEffectName)
	List = BedBreakEffect:CreateDropdown({
		Name = 'Effect',
		List = BreakEffectName
	})
end)
	
run(function()
	vape.Categories.BoostFPS:CreateModule({
		Name = 'Clean Kit',
		Function = function(callback)
			if callback then
				bedwars.WindWalkerController.spawnOrb = function() end
				local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
				if zephyreffect then 
					zephyreffect.Visible = false 
				end
			end
		end,
		Tooltip = 'Removes zephyr status indicator'
	})
end)
	
run(function()
	local old
	local Image
	
	local Crosshair = vape.Categories.Legit:CreateModule({
		Name = 'Crosshair',
		Function = function(callback)
			if callback then
				old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
			else
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
				old = nil
			end
	
			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = 'Custom first person crosshair depending on the image choosen.'
	})
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'image id (roblox)',
		Function = function(enter)
			if enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)
	
run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke
	local suc, tab = pcall(function()
		return debug.getupvalue(bedwars.DamageIndicator, 2)
	end)
	tab = suc and tab or {}
	local oldvalues, oldfont = {}
	
	DamageIndicator = vape.Categories.Legit:CreateModule({
		Name = 'Damage Indicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
				debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
				tab.strokeThickness = Stroke.Enabled and 1 or false
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
				debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
			end
		end,
		Tooltip = 'Customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
				tab.strokeThickness = callback and 1 or false
			end
		end
	})
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
		Name = 'FPS Boost',
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
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Categories.Legit:CreateModule({
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
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Categories.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)
	
run(function()
	local KillEffect
	local Mode
	local List
	local NameToId = {}
	
	local killeffects = {
		Gravity = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			local nametag = char:FindFirstChild('Nametag', true)
			if highlight then
				highlight:Destroy()
			end
			if nametag then
				nametag:Destroy()
			end
	
			task.spawn(function()
				local partvelo = {}
				for _, v in char:GetDescendants() do
					if v:IsA('BasePart') then
						partvelo[v.Name] = v.Velocity
					end
				end
				char.Archivable = true
				local clone = char:Clone()
				clone.Humanoid.Health = 100
				clone.Parent = workspace
				game:GetService('Debris'):AddItem(clone, 30)
				char:Destroy()
				task.wait(0.01)
				clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				clone:BreakJoints()
				task.wait(0.01)
				for _, v in clone:GetDescendants() do
					if v:IsA('BasePart') then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
						bodyforce.Parent = v
						v.CanCollide = true
						v.Velocity = partvelo[v.Name] or Vector3.zero
					end
				end
			end)
		end,
		Lightning = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			if highlight then
				highlight:Destroy()
			end
			local startpos = 1125
			local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
			local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)
	
			for i = startpos - 75, 0, -75 do
				local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
				if i == 0 then
					newpos2 = Vector3.zero
				end
				local part = Instance.new('Part')
				part.Size = Vector3.new(1.5, 1.5, 77)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
				part.Parent = workspace
				local part2 = part:Clone()
				part2.Size = Vector3.new(3, 3, 78)
				part2.Color = Color3.new(0.7, 0.7, 0.7)
				part2.Transparency = 0.7
				part2.Material = Enum.Material.SmoothPlastic
				part2.Parent = workspace
				game:GetService('Debris'):AddItem(part, 0.5)
				game:GetService('Debris'):AddItem(part2, 0.5)
				bedwars.QueryUtil:setQueryIgnored(part, true)
				bedwars.QueryUtil:setQueryIgnored(part2, true)
				if i == 0 then
					local soundpart = Instance.new('Part')
					soundpart.Transparency = 1
					soundpart.Anchored = true
					soundpart.Size = Vector3.zero
					soundpart.Position = startcf
					soundpart.Parent = workspace
					bedwars.QueryUtil:setQueryIgnored(soundpart, true)
					local sound = Instance.new('Sound')
					sound.SoundId = 'rbxassetid://6993372814'
					sound.Volume = 2
					sound.Pitch = 0.5 + (math.random(1, 3) / 10)
					sound.Parent = soundpart
					sound:Play()
					sound.Ended:Connect(function()
						soundpart:Destroy()
					end)
				end
				newpos = newpos2
			end
		end,
		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Categories.Legit:CreateModule({
		Name = 'Kill Effect',
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			List.Object.Visible = val == 'Bedwars'
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
	List = KillEffect:CreateDropdown({
		Name = 'Bedwars',
		List = KillEffectName,
		Function = function(val)
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', NameToId[val])
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Categories.Legit:CreateModule({
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
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = tick()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then 
			table.clear(alreadypicked) 
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat 
				task.wait() 
				chosensong = list[math.random(1, #list)] 
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Categories.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				repeat
					if not songobj.Playing then choosesong() end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then 
				songobj.Volume = val / 100 
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local SoundChanger
	local List
	local soundlist = {}
	local old
	
	SoundChanger = vape.Categories.Legit:CreateModule({
		Name = 'SoundChanger',
		Function = function(callback)
			if callback then
				old = bedwars.SoundManager.playSound
				bedwars.SoundManager.playSound = function(self, id, ...)
					if soundlist[id] then
						id = soundlist[id]
					end
	
					return old(self, id, ...)
				end
			else
				bedwars.SoundManager.playSound = old
				old = nil
			end
		end,
		Tooltip = 'Change ingame sounds to custom ones.'
	})
	List = SoundChanger:CreateTextList({
		Name = 'Sounds',
		Placeholder = '(DAMAGE_1/ben.mp3)',
		Function = function()
			table.clear(soundlist)
			for _, entry in List.ListEnabled do
				local split = entry:split('/')
				local id = bedwars.SoundList[split[1]]
				if id and #split > 1 then
					soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
				end
			end
		end
	})
end)
	
run(function()
	local UICleanup
	local OpenInv
	local KillFeed
	local OldTabList
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local old, new = {}, {}
	local oldkillfeed
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			local typing = type(old[func][ind])
			if typing == 'function' or typing == 'userdata' then return end
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end
	
		new[func][ind] = val
		if UICleanup.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	UICleanup = vape.Categories.Legit:CreateModule({
		Name = 'UI Cleanup',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				if OpenInv.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				end
	
				if KillFeed.Enabled then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
	
				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Cleans up the UI for kits & main'
	})
	UICleanup:CreateToggle({
		Name = 'Resize Health',
		Function = function(callback)
			modifyconstant(HotbarApp, 60, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'No Hotbar Numbers',
		Function = function(callback)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
			modifyconstant(func, 71, callback and 0 or nil)
		end,
		Default = true
	})
	OpenInv = UICleanup:CreateToggle({
		Name = 'No Inventory Button',
		Function = function(callback)
			modifyconstant(HotbarApp, 78, callback and 0 or nil)
			if UICleanup.Enabled then
				if callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = 'No Kill Feed',
		Function = function(callback)
			if UICleanup.Enabled then
				if callback then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = 'Old Player List',
		Function = function(callback)
			if UICleanup.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'Fix Queue Card',
		Function = function(callback)
			modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
		end,
		Default = true
	})
end)
	
run(function()
    local WinEffect
    local List
    local NameToId = {}
    
    WinEffect = vape.Categories.Legit:CreateModule({
        Name = "WinEffect",
        Function = function(callback)
            if callback then
                WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    for i, v in getconnections(bedwars.Client:Get("WinEffectTriggered").instance.OnClientEvent) do
                        if v.Function then
                            v.Function({
                                winEffectType = NameToId[List.Value],
                                winningPlayer = lplr
                            })
                        end
                    end
                end))
            end
        end,
        Tooltip = "Allows you to select any clientside win effect"
    })
    
    local WinEffectName = {}
    for i, v in bedwars.WinEffectMeta do
        table.insert(WinEffectName, v.name)
        NameToId[v.name] = i
    end
    table.sort(WinEffectName)
    
    List = WinEffect:CreateDropdown({
        Name = "Effects",
        List = WinEffectName
    })
end)

run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local NoBob
	local Rots = {}
	local old, oldc1
	
	Viewmodel = vape.Categories.Combat:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				if viewmodel then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel then
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				old = nil
			end
		end,
		Tooltip = 'Changes the viewmodel animations'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Default = -0.2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Default = true,
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
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
	local ItemlessLongjump = {Enabled = false}

	ItemlessLongjump = vape.Categories.Blatant:CreateModule({
		Name = "ItemlessLongjump",
		Function = function(call)
			ItemlessLongjump.Enabled = call
			if call then
				lplr.Character.HumanoidRootPart.Velocity = lplr.Character.HumanoidRootPart.Velocity + Vector3.new(0, 100, 0)
				task.wait(0.3)
				for i = 1, 4 do
					task.wait(0.4)
					lplr.Character.HumanoidRootPart.Velocity = lplr.Character.HumanoidRootPart.Velocity + Vector3.new(0, 75, 0)
				end
				task.wait(0.025)
				for i = 1, 2 do
					task.wait(0.125)
					lplr.Character.HumanoidRootPart.Velocity = lplr.Character.HumanoidRootPart.Velocity + Vector3.new(0, 85, 0)
				end
			else
				workspace.Gravity = 192.6
			end
		end,
		Tooltip = "lets u longjump without items/kits (thanks soyred)"
	})
end)

run(function()
	local lightingService = cloneref(game:GetService('Lighting'))
	local lightingsettings = {}
	local lightingchanged = false
	local Fullbright = {Enabled = false}
	local BrightnessSlider
	
	Fullbright = vape.Categories.World:CreateModule({
		Name = "Fullbright",
		Function = function(callback)
			if callback then
				lightingsettings.Brightness = lightingService.Brightness
				lightingsettings.ClockTime = lightingService.ClockTime
				lightingsettings.FogEnd = lightingService.FogEnd
				lightingsettings.GlobalShadows = lightingService.GlobalShadows
				lightingsettings.OutdoorAmbient = lightingService.OutdoorAmbient
				lightingsettings.Ambient = lightingService.Ambient
				lightingsettings.ExposureCompensation = lightingService.ExposureCompensation
				
				lightingchanged = true
				
				local brightnessValue = BrightnessSlider and BrightnessSlider.Value or 5
				lightingService.Brightness = brightnessValue
				lightingService.ClockTime = 14  
				lightingService.FogEnd = 100000 
				lightingService.GlobalShadows = false  
				lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)  
				lightingService.Ambient = Color3.fromRGB(255, 255, 255)  
				lightingService.ExposureCompensation = 1  
				
				lightingchanged = false
				
				local brightnessConnection = lightingService:GetPropertyChangedSignal("Brightness"):Connect(function()
					if not lightingchanged then
						lightingchanged = true
						lightingService.Brightness = brightnessValue
						lightingchanged = false
					end
				end)
				
				local ambientConnection = lightingService:GetPropertyChangedSignal("Ambient"):Connect(function()
					if not lightingchanged then
						lightingchanged = true
						lightingService.Ambient = Color3.fromRGB(255, 255, 255)
						lightingchanged = false
					end
				end)
				
				local exposureConnection = lightingService:GetPropertyChangedSignal("ExposureCompensation"):Connect(function()
					if not lightingchanged then
						lightingchanged = true
						lightingService.ExposureCompensation = 1
						lightingchanged = false
					end
				end)
				
				Fullbright:Clean(brightnessConnection)
				Fullbright:Clean(ambientConnection)
				Fullbright:Clean(exposureConnection)
				
			else
				lightingchanged = true
				
				if lightingsettings.Brightness then
					lightingService.Brightness = lightingsettings.Brightness
				end
				if lightingsettings.ClockTime then
					lightingService.ClockTime = lightingsettings.ClockTime
				end
				if lightingsettings.FogEnd then
					lightingService.FogEnd = lightingsettings.FogEnd
				end
				if lightingsettings.GlobalShadows ~= nil then
					lightingService.GlobalShadows = lightingsettings.GlobalShadows
				end
				if lightingsettings.OutdoorAmbient then
					lightingService.OutdoorAmbient = lightingsettings.OutdoorAmbient
				end
				if lightingsettings.Ambient then
					lightingService.Ambient = lightingsettings.Ambient
				end
				if lightingsettings.ExposureCompensation then
					lightingService.ExposureCompensation = lightingsettings.ExposureCompensation
				end
				
				lightingchanged = false
				
				table.clear(lightingsettings)
			end
		end,
		HoverText = "Makes everything bright and removes shadows"
	})
	
	BrightnessSlider = Fullbright:CreateSlider({
		Name = "Brightness",
		Min = 1,
		Max = 10,
		Default = 5,
		Function = function(value)
			if Fullbright.Enabled then
				lightingchanged = true
				lightingService.Brightness = value
				lightingchanged = false
			end
		end
	})
	
	local ExtraBright = Fullbright:CreateToggle({
		Name = "Extra Bright",
		Function = function(callback)
			if Fullbright.Enabled then
				lightingchanged = true
				if callback then
					lightingService.Brightness = 10
					lightingService.Ambient = Color3.fromRGB(255, 255, 255)
					lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
					lightingService.ExposureCompensation = 2
					
					if not lightingService:FindFirstChild("VapeSun") then
						local sun = Instance.new("SunRaysEffect")
						sun.Name = "VapeSun"
						sun.Intensity = 0.1
						sun.Spread = 1
						sun.Parent = lightingService
					end
				else
					lightingService.Brightness = BrightnessSlider.Value
					lightingService.Ambient = Color3.fromRGB(255, 255, 255)
					lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
					lightingService.ExposureCompensation = 1
					
					local sun = lightingService:FindFirstChild("VapeSun")
					if sun then
						sun:Destroy()
					end
				end
				lightingchanged = false
			end
		end
	})
	
	local NoShadows = Fullbright:CreateToggle({
		Name = "No Shadows",
		Function = function(callback)
			if Fullbright.Enabled then
				lightingchanged = true
				lightingService.GlobalShadows = not callback
				lightingchanged = false
			end
		end,
		Default = true
	})
end)

run(function()
	local Clutch
	local runService = game:GetService("RunService")
	local workspace = game:GetService("Workspace")
	local HoldBase = 0.15
	local FallVelocity = -6
	local lastPlace = 0
	local UseBlacklisted_Blocks
	local blacklisted
	local clutchCount = 0
	local lastResetTime = 0
	
	local function callPlace(blockpos, wool, rotate)
		local placeFn
		if type(vape) == "table" and type(vape.clean) == "function" then
			vape:clean(blockpos, wool, rotate)
			return
		end
		if type(vape) == "table" and type(vape.place) == "function" then
			placeFn = vape.place
		elseif type(place) == "function" then
			placeFn = place
		else
			placeFn = bedwars.placeBlock
		end
		task.spawn(placeFn, blockpos, wool, rotate)
	end

	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end

	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end

	local function getClutchBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		end
		return nil, 0
	end

	Clutch = vape.Categories.Utility:CreateModule({
		Name = 'Clutch',
		Function = function(call)
			
			if call then
				clutchCount = 0
				lastResetTime = os.clock()
				
				Clutch:Clean(runService.Heartbeat:Connect(function()
					if not Clutch.Enabled then
						return
					end
					if not entitylib.isAlive then
						return
					end
					local root = entitylib.character.RootPart
					if not root or inputService:GetFocusedTextBox() then
						return
					end

					if Clutch.HeightCheck and Clutch.HeightCheck.Enabled then
						local minHeight = (Clutch.MinHeight and Clutch.MinHeight.Value) or 20
						if root.Position.Y < minHeight then
							return
						end
					end

					if Clutch.MinBlocks and Clutch.MinBlocks.Enabled then
						local _, amount = getClutchBlock()
						local minRequired = (Clutch.MinBlockAmount and Clutch.MinBlockAmount.Value) or 5
						if amount < minRequired then
							if Clutch.NotifyLowBlocks and Clutch.NotifyLowBlocks.Enabled then
								notif('Clutch', 'Low on blocks! ('..amount..' left)', 2)
							end
							return
						end
					end

					if Clutch.LimitToItems and Clutch.LimitToItems.Enabled then
						if getClutchBlock then
							if store.hand.toolType ~= "block" then
								return
							end
						end
					end
					
					local wool = select(1, getClutchBlock())
					if not wool then
						return
					end
					
					if wool and not UseBlacklisted_Blocks.Enabled then
						for i,v in blacklisted.ListEnabled do
							if wool == v then
								return																																																																																																																																																																									
							end																																																																																																																																																																												
						end
					end
					
					if Clutch.RequireMouse and Clutch.RequireMouse.Enabled and not inputService:IsMouseButtonPressed(0) then
						return
					end
					
					local vy = root.Velocity.Y
					local now = os.clock()
					
					if (now - lastResetTime) > 5 then
						clutchCount = 0
						lastResetTime = now
					end
					
					local speedVal = (Clutch.Speed and Clutch.Speed.Value) or 0
					local cooldown = math.clamp(HoldBase - (speedVal * 0.015), 0.01, HoldBase)
					
					if vy < FallVelocity and (now - lastPlace) > cooldown then
						local target = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 4.5, 0))
						local exists, blockpos = getPlacedBlock(target)
						
						if not exists then
							local prox = blockProximity(target)
							local placePos = prox or (target * 3)
							
							callPlace(placePos, wool, false)
							lastPlace = now
							clutchCount = clutchCount + 1
							
							
							if Clutch.SilentAim and Clutch.SilentAim.Enabled then
								local camera = workspace.CurrentCamera
								local camCFrame = camera and camera.CFrame
								local camType = camera and camera.CameraType
								local camSubject = camera and camera.CameraSubject
								local lv = root.CFrame.LookVector
								local newLook = -Vector3.new(lv.X, 0, lv.Z).Unit
								local rootPos = root.Position
								root.CFrame = CFrame.new(rootPos, rootPos + newLook)
								if camera and camCFrame then
									camera.CameraType = camType
									camera.CameraSubject = camSubject
									camera.CFrame = camCFrame
								end
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Automatically places a block when falling to clutch'
	})

	UseBlacklisted_Blocks = Clutch:CreateToggle({
		Name = "Use Blacklisted Blocks",
		Default = false,
		Tooltip = "Allows clutching with blacklisted blocks"
	})

	blacklisted = Clutch:CreateTextList({
		Name = "Blacklisted Blocks",
		Placeholder = "tnt"
	})
	
	Clutch.LimitToItems = Clutch:CreateToggle({
		Name = 'Limit to items',
		Default = false,
		Tooltip = "Only clutch when holding blocks"
	})

	Clutch.RequireMouse = Clutch:CreateToggle({
		Name = 'Require mouse down',
		Default = false,
		Tooltip = "Only clutch when holding left click"
	})

	Clutch.SilentAim = Clutch:CreateToggle({
		Name = 'Silent Aim',
		Default = false,
		Tooltip = "Looks down while placing without moving camera"
	})

	Clutch.HeightCheck = Clutch:CreateToggle({
		Name = 'Height Check',
		Default = false,
		Tooltip = "Only clutch above minimum height (prevents void clutching)"
	})

	Clutch.MinBlocks = Clutch:CreateToggle({
		Name = 'Min Block Check',
		Default = false,
		Tooltip = "Disables clutch when running low on blocks"
	})

	Clutch.NotifyClutch = Clutch:CreateToggle({
		Name = 'Notify Clutch',
		Default = false,
		Tooltip = "Shows notification when you clutch"
	})

	Clutch.NotifyLowBlocks = Clutch:CreateToggle({
		Name = 'Notify Low Blocks',
		Default = false,
		Tooltip = "Warns you when running out of blocks"
	})

	Clutch.AutoDisable = Clutch:CreateToggle({
		Name = 'Auto Disable',
		Default = false,
		Tooltip = "Disables clutch when you run out of blocks"
	})

	Clutch.Speed = Clutch:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 9,
		Default = 6,
		Tooltip = "How fast to place blocks"
	})

	Clutch.MinHeight = Clutch:CreateSlider({
		Name = 'Min Height',
		Min = 0,
		Max = 50,
		Default = 20,
		Tooltip = "Minimum Y position to clutch (prevents void)"
	})

	Clutch.MinBlockAmount = Clutch:CreateSlider({
		Name = 'Min Block Amount',
		Min = 1,
		Max = 32,
		Default = 5,
		Tooltip = "Minimum blocks required to clutch"
	})

	task.spawn(function()
		while task.wait(0.5) do
			if Clutch.Enabled and Clutch.AutoDisable and Clutch.AutoDisable.Enabled then
				local wool, amount = getClutchBlock()
				if amount == 0 then
					notif('Clutch', 'Out of blocks! Auto disabled.', 3)
					Clutch:Toggle()
				end
			end
		end
	end)
end)

run(function()
    local InvisibleCursor = {}
    local isActive = false
    local renderConnection
    local ViewMode = {Value = 'First Person'}
    local LimitToItems = {Enabled = false}
    local ShowOnGUI = {Enabled = false}
    
    local function isFirstPerson()
        if not (lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")) then 
            return false 
        end
        
        local characterPos = lplr.Character.HumanoidRootPart.Position
        local cameraPos = gameCamera.CFrame.Position
        local distance = (characterPos - cameraPos).Magnitude
        
        return distance < 5 
    end
    
    local function isGUIOpen()
        local guiLayers = {
            bedwars.UILayers.MAIN or 'Main',
            bedwars.UILayers.DIALOG or 'Dialog',
            bedwars.UILayers.POPUP or 'Popup'
        }
        
        for _, layerName in pairs(guiLayers) do
            if bedwars.AppController:isLayerOpen(layerName) then
                return true
            end
        end
        
        if bedwars.AppController:isAppOpen('BedwarsItemShopApp') then
            return true
        end
        
        if bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open then
            return true
        end
        
        return false
    end
    
    local function hasBowEquipped()
        if not store.hand or not store.hand.toolType then
            return false
        end
        
        local toolType = store.hand.toolType
        return toolType == 'bow' or toolType == 'crossbow'
    end
    
    local function shouldHideCursor()
        if not isActive then return false end
        
        if ShowOnGUI.Enabled and isGUIOpen() then
            return false
        end
        
        if LimitToItems.Enabled then
            if not hasBowEquipped() then
                return false
            end
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
        if shouldHideCursor() then
            pcall(function()
                inputService.MouseIconEnabled = false
            end)
        else
            pcall(function()
                inputService.MouseIconEnabled = true
            end)
        end
    end
    
    InvisibleCursor = vape.Categories.Utility:CreateModule({
        Name = 'InvisibleCursor',
        Function = function(callback)
            
            if callback then
                isActive = true
                
                if renderConnection then
                    renderConnection:Disconnect()
                end
                
                renderConnection = runService.RenderStepped:Connect(updateCursor)
                
                vape:Clean(vapeEvents.InventoryChanged.Event:Connect(updateCursor))
                
                notif('Invisible Cursor', 'Cursor hiding enabled', 2)
            else
                isActive = false
                
                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end
                
                pcall(function()
                    inputService.MouseIconEnabled = true
                end)
            end
        end,
        Tooltip = 'Hides cursor based on view mode and item settings'
    })
    
    ViewMode = InvisibleCursor:CreateDropdown({
        Name = 'View Mode',
        List = {'First Person', 'Third Person', 'Both'},
        Default = 'First Person',
        Tooltip = 'Choose when to hide cursor',
        Function = updateCursor
    })
    
    LimitToItems = InvisibleCursor:CreateToggle({
        Name = 'Limit to Bow',
        Tooltip = 'Only hide cursor when holding a bow/crossbow',
        Function = updateCursor
    })
    
    ShowOnGUI = InvisibleCursor:CreateToggle({
        Name = 'Show on GUI',
        Tooltip = 'Show cursor when any GUI is open (inventory, shop, etc)',
        Function = updateCursor
    })
    
    vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
        updateCursor()
    end))
    
    local lastGUIState = false
    local function checkGUIState()
        local currentGUIState = isGUIOpen()
        if lastGUIState ~= currentGUIState then
            updateCursor()
            lastGUIState = currentGUIState
        end
    end
    
    if renderConnection then
        vape:Clean(renderConnection)
        renderConnection = runService.RenderStepped:Connect(function()
            checkGUIState()
            updateCursor()
        end)
    end
end)

run(function()
    local SlimeTamer = vape.Categories.Utility:CreateModule({
        Name = 'Slime ESP',
        Function = function(callback)
            if callback then
                if not _G.SlimeESP then _G.SlimeESP = {} end
                _G.SlimeESP.espBoxes = {}
                _G.SlimeESP.billboards = {}
                _G.SlimeESP.enabled = true
                
                local espBoxes = _G.SlimeESP.espBoxes
                local billboards = _G.SlimeESP.billboards
                local enabled = _G.SlimeESP.enabled
                
                local function updateESP()
                    for _, box in pairs(espBoxes) do
                        if box and box.Parent then
                            box:Remove()
                        end
                    end
                    for _, billboard in pairs(billboards) do
                        if billboard and billboard.Parent then
                            billboard:Remove()
                        end
                    end
                    
                    for i = #espBoxes, 1, -1 do
                        espBoxes[i] = nil
                    end
                    for i = #billboards, 1, -1 do
                        billboards[i] = nil
                    end
    
                    for _, slimeModel in pairs(collectionService:GetTagged("SlimeModel")) do
                        if slimeModel and slimeModel.PrimaryPart then
                            local box = Instance.new("BoxHandleAdornment")
                            box.Adornee = slimeModel.PrimaryPart
                            box.AlwaysOnTop = true
                            box.Size = Vector3.new(4, 4, 4)
                            box.Color3 = Color3.fromRGB(0, 255, 0)
                            box.Transparency = 0.5
                            box.ZIndex = 10
                            box.Parent = game.Workspace.CurrentCamera
                            
                            local billboard = Instance.new("BillboardGui")
                            billboard.Adornee = slimeModel.PrimaryPart
                            billboard.Size = UDim2.new(0, 100, 0, 50)
                            billboard.StudsOffset = Vector3.new(0, 3, 0)
                            billboard.AlwaysOnTop = true
                            billboard.Parent = game.Workspace.CurrentCamera
                            
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.fromRGB(255, 255, 255)
                            label.TextStrokeTransparency = 0
                            label.TextSize = 14
                            label.Font = Enum.Font.SourceSansBold
                            label.Parent = billboard
                            
                            local slimeData = slimeModel:FindFirstChild("SlimeData")
                            if slimeData and slimeData.Value then
                                local slimeType = slimeData.Value:GetAttribute("SlimeType")
                                local typeNames = {
                                    [0] = "HEALING",
                                    [1] = "VOID", 
                                    [2] = "STICKY",
                                    [3] = "FROSTY"
                                }
                                label.Text = typeNames[slimeType] or "UNKNOWN"
                                
                                local typeColors = {
                                    [0] = Color3.fromRGB(255, 255, 0),
                                    [1] = Color3.fromRGB(255, 0, 255), 
                                    [2] = Color3.fromRGB(0, 255, 0), 
                                    [3] = Color3.fromRGB(0, 200, 255)  
                                }
                                label.TextColor3 = typeColors[slimeType] or Color3.fromRGB(255, 255, 255)
                                box.Color3 = typeColors[slimeType] or Color3.fromRGB(0, 255, 0)
                            else
                                label.Text = "NO DATA"
                            end
                            
                            table.insert(espBoxes, box)
                            table.insert(billboards, billboard)
                        end
                    end
                end
                
                if _G.SlimeESP.connection then
                    _G.SlimeESP.connection:Disconnect()
                end
                
                _G.SlimeESP.connection = game:GetService("RunService").RenderStepped:Connect(function()
                    if enabled then
                        pcall(updateESP)
                    else
                        if _G.SlimeESP.connection then
                            _G.SlimeESP.connection:Disconnect()
                            _G.SlimeESP.connection = nil
                        end
                    end
                end)
                
            else
                _G.SlimeESP.enabled = false
                
                if _G.SlimeESP.connection then
                    _G.SlimeESP.connection:Disconnect()
                    _G.SlimeESP.connection = nil
                end
                
                if _G.SlimeESP.espBoxes then
                    for _, box in pairs(_G.SlimeESP.espBoxes) do
                        if box and box.Parent then
                            pcall(function() box:Remove() end)
                        end
                    end
                    _G.SlimeESP.espBoxes = {}
                end
                
                if _G.SlimeESP.billboards then
                    for _, billboard in pairs(_G.SlimeESP.billboards) do
                        if billboard and billboard.Parent then
                            pcall(function() billboard:Remove() end)
                        end
                    end
                    _G.SlimeESP.billboards = {}
                end
            end
        end,
        Tooltip = 'See all slimes with colors by type'
    })
end)

run(function()
	local SeizureMode
	local Intensity
	local Frequency
	local HeadShake
	local ArmShake
	
	SeizureMode = vape.Categories.Blatant:CreateModule({
		Name = 'Seizure Mode',
		Function = function(callback)
			if callback then
				local originalCFrames = {}
				local shakeConnections = {}
				local isShaking = true
				local seizureLoopConnection
				local characterAddedConnection
				local characterRemovingConnection
				
				local function shakePart(part, intensity, headMode)
					if not part then return end
					
					local originalCFrame = part.CFrame
					originalCFrames[part] = originalCFrame
					
					local connection = runService.Heartbeat:Connect(function(delta)
						if not isShaking or not part or not part.Parent then
							connection:Disconnect()
							return
						end
						
						if headMode then
							local xShake = math.random(-intensity, intensity) * 0.1
							local yShake = math.random(-intensity, intensity) * 0.1
							local zShake = math.random(-intensity, intensity) * 0.1
							
							local rx = math.rad(math.random(-intensity * 5, intensity * 5))
							local ry = math.rad(math.random(-intensity * 5, intensity * 5))
							local rz = math.rad(math.random(-intensity * 5, intensity * 5))
							
							part.CFrame = originalCFrame * CFrame.new(xShake, yShake, zShake) * CFrame.Angles(rx, ry, rz)
						else
							local xShake = math.random(-intensity * 2, intensity * 2) * 0.1
							local yShake = math.random(-intensity * 2, intensity * 2) * 0.1
							local zShake = math.random(-intensity * 2, intensity * 2) * 0.1
							
							local rx = math.rad(math.random(-intensity * 10, intensity * 10))
							local ry = math.rad(math.random(-intensity * 10, intensity * 10))
							local rz = math.rad(math.random(-intensity * 10, intensity * 10))
							
							part.CFrame = originalCFrame * CFrame.new(xShake, yShake, zShake) * CFrame.Angles(rx, ry, rz)
						end
					end)
					
					table.insert(shakeConnections, connection)
					return connection
				end
				
				local function stopAllShaking()
					isShaking = false
					
					for _, conn in pairs(shakeConnections) do
						if conn then
							conn:Disconnect()
						end
					end
					table.clear(shakeConnections)
					
					if seizureLoopConnection then
						seizureLoopConnection:Disconnect()
						seizureLoopConnection = nil
					end
					
					if characterAddedConnection then
						characterAddedConnection:Disconnect()
						characterAddedConnection = nil
					end
					
					if characterRemovingConnection then
						characterRemovingConnection:Disconnect()
						characterRemovingConnection = nil
					end
					
					for part, originalCFrame in pairs(originalCFrames) do
						if part and part.Parent then
							part.CFrame = originalCFrame
						end
					end
					table.clear(originalCFrames)
				end
				
				local function startSeizure()
					if not entitylib.isAlive then return end
					
					local character = entitylib.character.Character
					if not character then return end
					
					for _, conn in pairs(shakeConnections) do
						if conn then
							conn:Disconnect()
						end
					end
					table.clear(shakeConnections)
					
					local shakeIntensity = Intensity.Value
					
					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						shakePart(rootPart, shakeIntensity, false)
					end
					
					if HeadShake.Enabled then
						local head = character:FindFirstChild("Head")
						if head then
							shakePart(head, shakeIntensity, true)
						end
					end
					
					if ArmShake.Enabled then
						local leftArm = character:FindFirstChild("Left Arm")
						local rightArm = character:FindFirstChild("Right Arm")
						
						local leftUpperArm = character:FindFirstChild("LeftUpperArm")
						local rightUpperArm = character:FindFirstChild("RightUpperArm")
						
						if leftArm then
							shakePart(leftArm, shakeIntensity, false)
						elseif leftUpperArm then
							shakePart(leftUpperArm, shakeIntensity, false)
						end
						
						if rightArm then
							shakePart(rightArm, shakeIntensity, false)
						elseif rightUpperArm then
							shakePart(rightUpperArm, shakeIntensity, false)
						end
						
						local leftLowerArm = character:FindFirstChild("LeftLowerArm")
						local rightLowerArm = character:FindFirstChild("RightLowerArm")
						
						if leftLowerArm then
							shakePart(leftLowerArm, shakeIntensity * 1.5, false)
						end
						if rightLowerArm then
							shakePart(rightLowerArm, shakeIntensity * 1.5, false)
						end
					end
					
					local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
					if torso and math.random(1, 3) == 1 then
						shakePart(torso, shakeIntensity * 0.5, false)
					end
				end
				
				startSeizure()
				
				local frequencyTimer = 0
				seizureLoopConnection = runService.Heartbeat:Connect(function(delta)
					if not isShaking then return end
					
					frequencyTimer = frequencyTimer + delta
					
					if frequencyTimer >= (1 / Frequency.Value) then
						frequencyTimer = 0
						
						if math.random(1, 20) == 1 then
							isShaking = false
							for _, conn in pairs(shakeConnections) do
								if conn then
									conn:Disconnect()
								end
							end
							table.clear(shakeConnections)
							
							task.wait(0.1)
							
							if SeizureMode.Enabled then
								isShaking = true
								startSeizure()
							end
						else
							if isShaking then
								for _, conn in pairs(shakeConnections) do
									if conn then
										conn:Disconnect()
									end
								end
								table.clear(shakeConnections)
								
								startSeizure()
							end
						end
					end
				end)
				
				characterAddedConnection = lplr.CharacterAdded:Connect(function()
					task.wait(0.5)
					if SeizureMode.Enabled and isShaking then
						startSeizure()
					end
				end)
				
				characterRemovingConnection = lplr.CharacterRemoving:Connect(function()
					stopAllShaking()
				end)
				
				SeizureMode.cleanupFunc = stopAllShaking
				
			else
				if SeizureMode.cleanupFunc then
					SeizureMode.cleanupFunc()
					SeizureMode.cleanupFunc = nil
				end
				
				if entitylib.isAlive then
					local character = entitylib.character.Character
					if character then
						for _, part in character:GetChildren() do
							if part:IsA("BasePart") then
								part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, 0, 0)
							end
						end
						
						local humanoid = character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid.AutoRotate = true
						end
					end
				end
			end
		end,
		Tooltip = 'Makes your character shake uncontrollably like having a seizure'
	})
	
	Intensity = SeizureMode:CreateSlider({
		Name = 'Intensity',
		Min = 1,
		Max = 100,
		Default = 50,
		Function = function(val)
			if SeizureMode.Enabled then
				SeizureMode:Toggle()
				SeizureMode:Toggle()
			end
		end
	})
	
	Frequency = SeizureMode:CreateSlider({
		Name = 'Frequency',
		Min = 1,
		Max = 60,
		Default = 20,
		Suffix = 'hz',
		Function = function(val)
			if SeizureMode.Enabled then
				SeizureMode:Toggle()
				SeizureMode:Toggle()
			end
		end
	})
	
	HeadShake = SeizureMode:CreateToggle({
		Name = 'Head Shake',
		Default = true,
		Function = function()
			if SeizureMode.Enabled then
				SeizureMode:Toggle()
				SeizureMode:Toggle()
			end
		end
	})
	
	ArmShake = SeizureMode:CreateToggle({
		Name = 'Arm Shake',
		Default = true,
		Function = function()
			if SeizureMode.Enabled then
				SeizureMode:Toggle()
				SeizureMode:Toggle()
			end
		end
	})
	
	SeizureMode:CreateToggle({
		Name = 'Screen Shake',
		Default = false,
		Function = function(callback)
			if SeizureMode.Enabled then
				SeizureMode:Toggle()
				SeizureMode:Toggle()
			end
		end,
		Tooltip = 'Shakes the camera screen too for extra effect'
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
		Tooltip = 'Simple CPS modifier'
	})
	
	Value = BCR:CreateSlider({
		Name = "CPS Limit",
		Suffix = "CPS",
		Tooltip = "Higher = faster but more ghost blocks",
		Default = 67,
		Min = 12,
		Max = 100,
		Function = function()
			if BCR.Enabled and CpsConstants then
				local newCPS = Value.Value == 0 and 1000 or Value.Value
				CpsConstants.BLOCK_PLACE_CPS = newCPS
			end
		end,
	})
end)

run(function()
	local FastBow
	local Delay
	local oldSetOnCooldown
	
	task.spawn(function()
		repeat task.wait() until bedwars.ProjectileMeta and shared.vape
		
		for projectileName, projectileData in pairs(bedwars.ProjectileMeta) do
			if projectileData.projectile then
				local itemMeta = bedwars.ItemMeta[projectileData.projectile.itemType or '']
				if itemMeta and itemMeta.projectileSource then
					itemMeta.projectileSource.fireDelaySec = Delay.Value
				end
			end
		end
	end)
	
	FastBow = vape.Categories.Combat:CreateModule({
		Name = 'Fast Bow',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until bedwars.CooldownController
					
					if not oldSetOnCooldown then
						oldSetOnCooldown = bedwars.CooldownController.setOnCooldown
					end
					
					bedwars.CooldownController.setOnCooldown = function(self, cooldownId, duration, options, ...)
						if FastBow.Enabled and (tostring(cooldownId):find("proj-source") or tostring(cooldownId):find("bow") or tostring(cooldownId):find("crossbow")) then
							duration = Delay.Value
						end
						return oldSetOnCooldown(self, cooldownId, duration, options, ...)
					end
				end)
				
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						item.projectileSource.fireDelaySec = Delay.Value
					end
				end
			else
				if oldSetOnCooldown then
					bedwars.CooldownController.setOnCooldown = oldSetOnCooldown
				end
				
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						local originalDelay = item.projectileSource.originalFireDelaySec or 1
						item.projectileSource.fireDelaySec = originalDelay
					end
				end
			end
		end,
		Tooltip = 'Reduces bow/crossbow fire delay(not every shot will hit but its fun to add ig)'
	})
	
	Delay = FastBow:CreateSlider({
		Name = 'Fire Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's',
		Function = function(val)
			if FastBow.Enabled then
				for _, item in pairs(bedwars.ItemMeta) do
					if item.projectileSource then
						if not item.projectileSource.originalFireDelaySec then
							item.projectileSource.originalFireDelaySec = item.projectileSource.fireDelaySec
						end
						item.projectileSource.fireDelaySec = val
					end
				end
			end
		end
	})
end)

run(function()
    local PlayerLevelSet = {Enabled = false}
    local PlayerLevel = {Value = 100}
    local originalLevel = nil  
    
    PlayerLevelSet = vape.Categories.Utility:CreateModule({
        Name = 'SetPlayerLevel',
        Tooltip = 'Sets your player level to 100 (client sided)',
        Function = function(calling)
            if calling then                 
                if PlayerLevelSet.Enabled and not originalLevel then
                    originalLevel = game.Players.LocalPlayer:GetAttribute("PlayerLevel") or 1
                end
                
                game.Players.LocalPlayer:SetAttribute("PlayerLevel", PlayerLevel.Value)
            else
                if originalLevel then
                    game.Players.LocalPlayer:SetAttribute("PlayerLevel", originalLevel)
                    originalLevel = nil  
                end
            end
        end
    })
    
    PlayerLevel = PlayerLevelSet:CreateSlider({
        Name = 'Sets your player level(client side)',
        Function = function() 
            if PlayerLevelSet.Enabled then 
                game.Players.LocalPlayer:SetAttribute("PlayerLevel", PlayerLevel.Value) 
            end 
        end,
        Min = 1,
        Max = 1000,
        Default = 100
    })
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
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
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
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
			for _ = 1, 12 do
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
		elseif getRole(plr, 5774246) >= 100 then
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
	
			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
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
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
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
	
	-- REMOVED so u can keep staff detector off if u want
	-- task.spawn(function()
	--     repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
	--     if vape.Loaded and not StaffDetector.Enabled then
	--         StaffDetector:Toggle()
	--     end
	-- end)
end)

shared.slowmode = 0
run(function()
    local HttpService = game:GetService("HttpService")
    local StaffDetectionSystem = {
        Enabled = false
    }
    local StaffDetectionSystemConfig = {
        GameMode = "Bedwars",
        CustomGroupEnabled = false,
        IgnoreOnline = false,
        AutoCheck = false,
        MemberLimit = 50,
        CustomGroupId = "",
        CustomRoles = {}
    }
    local StaffDetectionSystemStaffData = {
        Games = {
            Bedwars = {groupId = 5774246, roles = {79029254, 86172137, 43926962, 37929139, 87049509, 37929138}},
            PS99 = {groupId = 5060810, roles = {33738740, 33738765}}
        },
        Detected = {}
    }

    local DetectionUtils = {
        resetSlowmode = function() end,
        fetchUsersInRole = function() end,
        fetchUserPresence = function() end,
        fetchGroupRoles = function() end,
        getDetectionConfig = function() end,
        scanStaff = function() end
    }

    DetectionUtils = {
        resetSlowmode = function()
            task.spawn(function()
                while shared.slowmode > 0 do
                    shared.slowmode = shared.slowmode - 1
                    task.wait(1)
                end
                shared.slowmode = 0
            end)
        end,

        fetchUsersInRole = function(groupId, roleId, cursor)
            local url = string.format("https://groups.roblox.com/v1/groups/%d/roles/%d/users?limit=%d%s", groupId, roleId, StaffDetectionSystemConfig.MemberLimit, cursor and "&cursor=" .. cursor or "")
            local success, response = pcall(function()
                return request({Url = url, Method = "GET"})
            end)
            return success and HttpService:JSONDecode(response.Body) or {}
        end,

        fetchUserPresence = function(userIds)
            local success, response = pcall(function()
                return request({
                    Url = "https://presence.roblox.com/v1/presence/users",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({userIds = userIds})
                })
            end)
            return success and HttpService:JSONDecode(response.Body) or {userPresences = {}}
        end,

        fetchGroupRoles = function(groupId)
            local success, response = pcall(function()
                return request({
                    Url = "https://groups.roblox.com/v1/groups/" .. groupId .. "/roles",
                    Method = "GET"
                })
            end)
            if success and response.StatusCode == 200 then
                local roles = {}
                for _, role in pairs(HttpService:JSONDecode(response.Body).roles) do
                    table.insert(roles, role.id)
                end
                return true, roles
            end
            return false, nil, "Failed to fetch roles: " .. (success and response.StatusCode or "Network error")
        end,

        getDetectionConfig = function()
            if StaffDetectionSystemConfig.CustomGroupEnabled then
                if not StaffDetectionSystemConfig.CustomGroupId or StaffDetectionSystemConfig.CustomGroupId == "" then
                    return false, nil, "Custom Group ID not specified", false, nil, "Custom"
                end
                if #StaffDetectionSystemConfig.CustomRoles == 0 then
                    return true, tonumber(StaffDetectionSystemConfig.CustomGroupId), nil, false, nil, "Custom roles not specified"
                end
                local success, roles, error = DetectionUtils.fetchGroupRoles(StaffDetectionSystemConfig.CustomGroupId)
                return true, tonumber(StaffDetectionSystemConfig.CustomGroupId), nil, success, roles, error, "Custom"
            else
                local gameData = StaffDetectionSystemStaffData.Games[StaffDetectionSystemConfig.GameMode]
                return true, gameData.groupId, nil, true, gameData.roles, nil, "Normal"
            end
        end,

        scanStaff = function(groupId, roleId)
            local users, userIds = {}, {}
            local cursor = nil
            repeat
                local data = DetectionUtils.fetchUsersInRole(groupId, roleId, cursor)
                for _, user in pairs(data.data or {}) do
                    table.insert(users, user)
                    table.insert(userIds, user.userId)
                end
                cursor = data.nextPageCursor
            until not cursor

            local presenceData = DetectionUtils.fetchUserPresence(userIds)
            for _, user in pairs(users) do
                for _, presence in pairs(presenceData.userPresences) do
                    if user.userId == presence.userId then
                        user.presenceType = presence.userPresenceType
                        user.lastLocation = presence.lastLocation
                        break
                    end
                end
            end
            return users
        end
    }

    local function processStaffCheck()
        if shared.slowmode > 0 and not StaffDetectionSystemConfig.AutoCheck then
            notif("StaffDetector", "Slowmode active! Wait " .. shared.slowmode .. " seconds", shared.slowmode)
            return
        end

        shared.slowmode = 5
        DetectionUtils.resetSlowmode()
        notif("StaffDetector", "Checking staff presence...", 5)

        local groupSuccess, groupId, groupError, rolesSuccess, roles, rolesError, mode = DetectionUtils.getDetectionConfig()
        if not groupSuccess or not rolesSuccess then
            shared.slowmode = 0
            if groupError then notif("StaffDetector", groupError, 5) end
            if rolesError then notif("StaffDetector", rolesError, 5) end
            return
        end

        local detectedStaff, uniqueIds = {}, {}
        for _, roleId in pairs(roles) do
            for _, user in pairs(DetectionUtils.scanStaff(groupId, roleId)) do
				local resolve = {
					["Offline"] = '<font color="rgb(128,128,128)">Offline</font>',
					["Online"] = '<font color="rgb(0,255,0)">Online</font>',
					["In Game"] = '<font color="rgb(16, 150, 234)">In Game</font>',
					["In Studio"] = '<font color="rgb(255,165,0)">In Studio</font>'
				}
                local status = ({
                    [0] = "Offline",
                    [1] = "Online",
                    [2] = "In Game",
                    [3] = "In Studio"
                })[user.presenceType or 0]

                if (status == "In Game" or (not StaffDetectionSystemConfig.IgnoreOnline and status == "Online")) and
                   not table.find(uniqueIds, user.userId) then
                    table.insert(uniqueIds, user.userId)
                    local userData = {UserID = tostring(user.userId), Username = user.username, Status = status}
                    if not table.find(detectedStaff, userData) then
                        table.insert(detectedStaff, userData)
                        notif("StaffDetector", "@" .. userData.Username .. "(" .. userData.UserID .. ") is " .. resolve[status], 7)
                    end
                end
            end
        end
        notif("StaffDetector", #detectedStaff .. " staff members detected online/in-game!", 7)
    end

    StaffDetectionSystem = vape.Categories.Utility:CreateModule({
        Name = 'StaffFetcher - Roblox',
        Function = function(enabled)
            
            StaffDetectionSystem.Enabled = enabled
            if enabled then
                if StaffDetectionSystemConfig.AutoCheck then
                    task.spawn(function()
                        repeat
                            processStaffCheck()
                            task.wait(30)
                        until not StaffDetectionSystem.Enabled or not StaffDetectionSystemConfig.AutoCheck
                        StaffDetectionSystem:Toggle(false)
                    end)
                else
                    processStaffCheck()
                    StaffDetectionSystem:Toggle(false)
                end
            end
        end,
        Tooltip = "Checks for staff presence in Roblox groups"
    })

    local StaffDetectionSystemUI = {}

    local gameList = {}
    for game in pairs(StaffDetectionSystemStaffData.Games) do table.insert(gameList, game) end
    StaffDetectionSystemUI.GameSelector = StaffDetectionSystem:CreateDropdown({
        Name = "Game Mode",
        Function = function(value) StaffDetectionSystemConfig.GameMode = value end,
        List = gameList
    })

    StaffDetectionSystemUI.RolesList = StaffDetectionSystem:CreateTextList({
        Name = "Custom Roles",
        TempText = "Role ID (number)",
        Function = function(values) StaffDetectionSystemConfig.CustomRoles = values end
    })

    StaffDetectionSystemUI.GroupIdInput = StaffDetectionSystem:CreateTextBox({
        Name = "Custom Group ID",
        TempText = "Group ID (number)",
        Function = function(value) StaffDetectionSystemConfig.CustomGroupId = value end
    })

    StaffDetectionSystem:CreateToggle({
        Name = "Custom Group",
        Function = function(enabled)
            StaffDetectionSystemConfig.CustomGroupEnabled = enabled
            StaffDetectionSystemUI.GroupIdInput.Object.Visible = enabled
            StaffDetectionSystemUI.RolesList.Object.Visible = enabled
            StaffDetectionSystemUI.GameSelector.Object.Visible = not enabled
        end,
        Tooltip = "Use a custom staff group",
        Default = false
    })

    StaffDetectionSystem:CreateToggle({
        Name = "Ignore Online Staff",
        Function = function(enabled) StaffDetectionSystemConfig.IgnoreOnline = enabled end,
        Tooltip = "Only show in-game staff, ignoring online staff",
        Default = false
    })

    StaffDetectionSystem:CreateSlider({
        Name = "Member Limit",
        Min = 1,
        Max = 100,
        Function = function(value) StaffDetectionSystemConfig.MemberLimit = value end,
        Default = 50
    })

    StaffDetectionSystem:CreateToggle({
        Name = "Auto Check",
        Function = function(enabled)
            StaffDetectionSystemConfig.AutoCheck = enabled
            if enabled and shared.slowmode > 0 then
                notif("StaffDetector", "Disable Auto Check to use manually during slowmode!", 5)
            end
        end,
        Tooltip = "Automatically check every 30 seconds",
        Default = false
    })

    StaffDetectionSystemUI.GroupIdInput.Object.Visible = false
    StaffDetectionSystemUI.RolesList.Object.Visible = false
end)

--[[run(function()
    local tppos2 = nil
    local TweenSpeed = 0.7
    local HeightOffset = 5
    local BedTP = {}
    
    local TS = game:GetService("TweenService")

    local function teleportWithTween(char, destination)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            destination = destination + Vector3.new(0, HeightOffset, 0)
            local currentPosition = root.Position
            if (destination - currentPosition).Magnitude > 0.5 then
                if lplr.Character then
                    lplr.Character:SetAttribute('LastTeleported', 0)
                end
                
                local tweenInfo = TweenInfo.new(TweenSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                local goal = {CFrame = CFrame.new(destination)}
                local tween = TS:Create(root, tweenInfo, goal)
                tween:Play()
                tween.Completed:Wait()
                
                if lplr.Character then
                    lplr.Character:SetAttribute('LastTeleported', 0)
                end
                
                if BedTP and BedTP.Toggle then
                    BedTP:Toggle(false)
                end
            end
        end
    end

    local function killPlayer(player)
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end

    local function getEnemyBed(range)
        range = range or math.huge
        local bed = nil
        local player = lplr

        local localPos = player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position or Vector3.zero
        local playerTeam = player:GetAttribute('Team')
        local beds = collectionService:GetTagged('bed')

        for _, v in ipairs(beds) do 
            if v:GetAttribute('PlacedByUserId') == 0 then
                local bedTeam = v:GetAttribute('id'):sub(1, 1)
                if bedTeam ~= playerTeam then 
                    local bedPosition = v.Position
                    local bedDistance = (localPos - bedPosition).Magnitude
                    if bedDistance < range then 
                        bed = v
                        range = bedDistance
                    end
                end
            end
        end

        if not bed then 
            notif("BedTP", 'No enemy beds found. Total beds: '..#beds, 5)
        else
            notif("BedTP", 'Teleporting to bed at position: '..tostring(bed.Position), 3)
        end

        return bed
    end

    BedTP = vape.Categories.Blatant:CreateModule({
        ["Name"] = "BedTP",
        ["Function"] = function(callback)
            if callback then
                task.spawn(function()
                    BedTP:Clean(lplr.CharacterAdded:Connect(function(char)
                        if tppos2 then 
                            task.spawn(function()
                                local root = char:WaitForChild("HumanoidRootPart", 9000000000)
                                if root and tppos2 then 
                                    teleportWithTween(char, tppos2)
                                    tppos2 = nil
                                end
                            end)
                        end
                    end))
                    local bed = getEnemyBed()
                    if bed then 
                        tppos2 = bed.Position
                        killPlayer(lplr)
                    else
                        if BedTP and BedTP.Toggle then
                            BedTP:Toggle(false)
                        end
                    end
                end)
            end
        end
    })
end)--]]

--[[run(function()
	local Value
	local VerticalValue
	local WallCheck
	local NoFallDamage
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	overlapCheck.RespectCanCollide = true
	local up, down = 0, 0
	local success, proper = false, true
	local clone, oldroot, hip, valid
	
	local groundHit
	task.spawn(function()
		if bedwars and bedwars.Client and remotes.GroundHit then
			groundHit = bedwars.Client:Get(remotes.GroundHit).instance
		end
	end)
	
	local function doClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then return false end
			
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			oldroot.Parent = gameCamera
			bedwars.QueryUtil:setQueryIgnored(oldroot, true)
			clone.CFrame = oldroot.CFrame
			lplr.Character.PrimaryPart = clone
			lplr.Character.Parent = workspace
			
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then v.Part0 = clone end
					if v.Part1 == oldroot then v.Part1 = clone end
				end
			end
			
			return true
		end
		return false
	end
	
	local function revertClone()
		if not oldroot or not oldroot.Parent or not entitylib.isAlive then return false end
		
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		lplr.Character.Parent = workspace
		oldroot.CanCollide = true
		
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then v.Part0 = oldroot end
				if v.Part1 == clone then v.Part1 = oldroot end
			end
		end
		
		local oldclonepos = clone.Position.Y
		if clone then
			clone:Destroy()
			clone = nil
		end
		
		local origcf = {oldroot.CFrame:GetComponents()}
		if valid then origcf[2] = oldclonepos end
		
		oldroot.CFrame = CFrame.new(unpack(origcf))
		oldroot.Transparency = 1
		oldroot = nil
		entitylib.character.Humanoid.HipHeight = hip or 2
	end
	
	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly',
		Function = function(callback)
			
			frictionTable.InfiniteFly = callback or nil
			updateVelocity()
			
			if callback then
				if vape.Modules.Invisibility and vape.Modules.Invisibility.Enabled then
					vape.Modules.Invisibility:Toggle()
					notif('InfiniteFly', 'Invisibility cannot be used with InfiniteFly', 3, 'warning')
				end
	
				if not proper then
					notif('InfiniteFly', 'Broken state detected', 3, 'alert')
					InfiniteFly:Toggle()
					return
				end
	
				success = doClone()
				if not success then
					InfiniteFly:Toggle()
					return
				end
	
				local tracked = 0
				
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, root.AssemblyLinearVelocity.Y) or 0
						
						if tracked < -85 and groundHit then
							groundHit:FireServer(nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
							tracked = 0  
						end
						
						local mass = 1.5 + ((up + down) * VerticalValue.Value)
						local moveDirection = entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						
						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then 
								destination = ((ray.Position + ray.Normal) - root.Position) 
							end
						end
						
						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
	
						local speedCFrame = {oldroot.CFrame:GetComponents()}
						if isnetworkowner(oldroot) then
							speedCFrame[1] = clone.CFrame.X
							speedCFrame[3] = clone.CFrame.Z
							if speedCFrame[2] < 2000 then speedCFrame[2] = 100000 end
							oldroot.CFrame = CFrame.new(unpack(speedCFrame))
							oldroot.Velocity = Vector3.new(clone.Velocity.X, oldroot.Velocity.Y, clone.Velocity.Z)
						else
							speedCFrame[2] = clone.CFrame.Y
							clone.CFrame = CFrame.new(unpack(speedCFrame))
						end
					end
				end))
				
				up, down = 0, 0
				
				InfiniteFly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				
				InfiniteFly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						InfiniteFly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
				
			else
				if success and clone and oldroot and proper then
					proper = false
					
					overlapCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					overlapCheck.CollisionGroup = oldroot.CollisionGroup
					
					local ray = workspace:Blockcast(CFrame.new(oldroot.Position.X, clone.CFrame.p.Y, oldroot.Position.Z), Vector3.new(3, entitylib.character.HipHeight, 3), Vector3.new(0, -1000, 0), rayCheck)
					local origcf = {clone.CFrame:GetComponents()}
					
					origcf[1] = oldroot.Position.X
					origcf[2] = ray and ray.Position.Y + entitylib.character.HipHeight or clone.CFrame.p.Y
					origcf[3] = oldroot.Position.Z
					
					oldroot.CanCollide = true
					oldroot.Transparency = 0
					oldroot.CFrame = CFrame.new(unpack(origcf))
	
					local touched = false
					
					local noFallConnection
					if NoFallDamage.Enabled then
						local extraGravity = 0
						local rand = Random.new()
						
						noFallConnection = runService.PreSimulation:Connect(function(dt)
							if clone and entitylib.isAlive then
								local root = entitylib.character.RootPart
								
								if root.AssemblyLinearVelocity.Y < -85 then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayCheck.CollisionGroup = root.CollisionGroup
									
									local rootSize = root.Size.Y / 2.5 + entitylib.character.HipHeight
									local checkRay = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -rootSize, 0), rayCheck)
									
									if not checkRay then
										local velo = root.AssemblyLinearVelocity.Y
										
										root.AssemblyLinearVelocity = Vector3.new(
											root.AssemblyLinearVelocity.X, 
											-86, 
											root.AssemblyLinearVelocity.Z
										)
										
										root.CFrame = root.CFrame + Vector3.new(0, extraGravity * dt, 0)
										extraGravity = extraGravity + (-workspace.Gravity) * dt
									else
										extraGravity = 0
									end
								else
									extraGravity = 0
								end
							end
						end)
					end
					
					local connection = runService.PreSimulation:Connect(function()
						if oldroot then
							oldroot.Velocity = Vector3.zero
							valid = false
							
							if touched then return end
							
							local cf = {clone.CFrame:GetComponents()}
							cf[2] = oldroot.CFrame.Y
							local newcf = CFrame.new(unpack(cf))
							
							for _, v in workspace:GetPartBoundsInBox(newcf, oldroot.Size, overlapCheck) do
								if (v.Position.Y + (v.Size.Y / 2)) > (newcf.p.Y + 0.5) then
									touched = true
									return
								end
							end
							
							if not workspace:Raycast(newcf.Position, Vector3.new(0, -entitylib.character.HipHeight, 0), rayCheck) then return end
							
							oldroot.CFrame = newcf
							oldroot.Velocity = (clone.Velocity * Vector3.new(1, 0, 1))
							valid = true
						end
					end)
	
					notif('InfiniteFly', 'Landing' .. (NoFallDamage.Enabled and ' (Safe)' or ''), 1.1)
					
					local landingLoop = runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							local tracked = root.AssemblyLinearVelocity.Y
							
							if tracked < -85 and groundHit then
								groundHit:FireServer(nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
							end
						end
					end)
					
					InfiniteFly:Clean(landingLoop)
					
					task.delay(1.1, function()
						notif('InfiniteFly', 'Landed!', 1)
						connection:Disconnect()
						landingLoop:Disconnect()
						if noFallConnection then noFallConnection:Disconnect() end
						proper = true
						
						if groundHit then
							local root = entitylib.character.RootPart
							if root.AssemblyLinearVelocity.Y < 0 then
								groundHit:FireServer(nil, Vector3.new(0, root.AssemblyLinearVelocity.Y, 0), workspace:GetServerTimeNow())
							end
						end
						
						if oldroot and clone then 
							revertClone() 
						end
					end)
				end
			end
		end,
		ExtraText = function() 
			return 'Heatseeker' 
		end,
		Tooltip = 'Makes you go zoom'
	})
	
	Value = InfiniteFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	
	VerticalValue = InfiniteFly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	
	WallCheck = InfiniteFly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	
	NoFallDamage = InfiniteFly:CreateToggle({
		Name = 'No Fall Damage',
		Default = true,
		Tooltip = 'prevent fall damage'
	})
end)--]]

run(function()
	local DoubleHighJump = {Enabled = false}
	local DoubleHighJumpHeight = {Value = 500}
	local DoubleHighJumpHeight2 = {Value = 500}
	local jumps = 0
	DoubleHighJump = vape.Categories.Blatant:CreateModule({
		Name = "DoubleHighJump",
		NoSave = true,
		Tooltip = "UP+UP And AWAYYYY",
		Function = function(callback)
			if callback then 
				task.spawn(function()
					if entitylib.isAlive and lplr.Character:WaitForChild("Humanoid").FloorMaterial == Enum.Material.Air or jumps > 0 then 
						DoubleHighJump:Toggle(false) 
						return
					end
					for i = 1, 2 do 
						if not entitylib.isAlive then
							DoubleHighJump:Toggle(false) 
							return  
						end
						if i == 2 and lplr.Character:WaitForChild("Humanoid").FloorMaterial ~= Enum.Material.Air then 
							continue
						end
						lplr.Character:WaitForChild("HumanoidRootPart").Velocity = Vector3.new(0, i == 1 and DoubleHighJumpHeight.Value or DoubleHighJumpHeight2.Value, 0)
						jumps = i
						task.wait(i == 1 and 1 or 0.3)
					end
					task.spawn(function()
						for i = 1, 20 do 
							if entitylib.isAlive then 
								lplr.Character:WaitForChild("Humanoid"):ChangeState(Enum.HumanoidStateType.Landed)
							end
						end
					end)
					task.delay(1.6, function() jumps = 0 end)
					if DoubleHighJump.Enabled then
					   DoubleHighJump:Toggle(false)
					end
				end)
			end
		end
	})
	DoubleHighJumpHeight = DoubleHighJump:CreateSlider({
		Name = "First Jump",
		Min = 50,
		Max = 500,
		Default = 500,
		Function = function() end
	})
	DoubleHighJumpHeight2 = DoubleHighJump:CreateSlider({
		Name = "Second Jump",
		Min = 50,
		Max = 450,
		Default = 450,
		Function = function() end
	})
end)

run(function()
	local LegacyAnimation
	
	local function ensureAttribute()
		local workspace = game:GetService("Workspace")
		
		if workspace:GetAttribute("RbxLegacyAnimationBlending") == nil then
			workspace:SetAttribute("RbxLegacyAnimationBlending", false)
		end
	end
	
	local function setLegacyAnimation(enabled)
		local workspace = game:GetService("Workspace")
		
		ensureAttribute()
		
		workspace:SetAttribute("RbxLegacyAnimationBlending", enabled)
	end
	
	LegacyAnimation = vape.Categories.Render:CreateModule({
		Name = 'LegacyAnimation',
		Function = function(callback)
			
			if callback then
				ensureAttribute()
				
				setLegacyAnimation(true)
			else
				setLegacyAnimation(false)
			end
		end,
		Tooltip = 'Enables Roblox legacy animation blending'
	})
end)

--[[run(function()
	local AG
	local RH
	local ShowPath
	local PickupEnabled = false
	local scaffoldEnabled = false
	local pathParts = {}
	
	local function enablePickupRange()
		if PickupEnabled then return end
		PickupEnabled = true
		
		task.spawn(function()
			while AG.Enabled do
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					local items = collectionService:GetTagged("ItemDrop")
					
					for _, v in items do
						if not v or not v:IsDescendantOf(workspace) then continue end
						if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
						
						local distance = (localPosition - v.Position).Magnitude
						if distance <= 10 then
							if (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
							
							task.spawn(function()
								pcall(function()
									bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
										itemDrop = v
									})
								end)
							end)
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
	
	local adjacent = {}
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		end
		
		local wool, amount = getWool()
		if wool then
			return wool, amount
		end
		
		for _, item in store.inventory.inventory.items do
			if bedwars.ItemMeta[item.itemType].block then
				return item.itemType, item.amount
			end
		end
		
		return nil, 0
	end
	
	local function needsScaffold()
		if not entitylib.isAlive then return false end
		
		local root = entitylib.character.RootPart
		local moveDir = entitylib.character.Humanoid.MoveDirection
		
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
		
		local belowRay = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
		if not belowRay then
			return true
		end
		
		if moveDir.Magnitude > 0.1 then
			local checkPos = root.Position + (moveDir * 3)
			local aheadRay = workspace:Raycast(checkPos, Vector3.new(0, -6, 0), rayParams)
			if not aheadRay then
				return true
			end
		end
		
		return false
	end
	
	local function doScaffold()
		if not entitylib.isAlive or not scaffoldEnabled then return end
		
		if not needsScaffold() then return end
		
		local wool, amount = getScaffoldBlock()
		if not wool then return end
		
		local blockItem
		for slot, item in store.inventory.hotbar do
			if item.item and item.item.itemType == wool then
				blockItem = slot - 1
				break
			end
		end
		
		if blockItem then
			if store.inventory.hotbarSlot ~= blockItem then
				bedwars.ClientStoreHandler:dispatch({
					type = 'InventorySelectHotbarSlot',
					slot = blockItem
				})
				task.wait(0.05)
			end
		end
		
		local root = entitylib.character.RootPart
		local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0) + entitylib.character.Humanoid.MoveDirection * 3)
		
		local block, blockpos = getPlacedBlock(currentpos)
		if not block then
			blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
			if blockpos then
				task.spawn(bedwars.placeBlock, blockpos, wool, false)
			end
		end
	end
	
	local function buyBlocks()
		local maxAttempts = 100
		local attempts = 0
		local buyDelay = 0.15
		
		notif("Shop", "Starting to buy blocks...", 2, "info")
		
		while attempts < maxAttempts and AG.Enabled do
			local woolCount = 0
			if store.inventory and store.inventory.inventory and store.inventory.inventory.items then
				for _, item in store.inventory.inventory.items do
					if item.itemType and item.itemType:find("wool") then
						woolCount = woolCount + item.amount
					end
				end
			end
			
			if woolCount >= 128 then
				notif("Shop", "Got max blocks! (" .. woolCount .. ")", 3, "success")
				break
			end
			
			local success = pcall(function()
				local args = {
					{
						shopItem = {
							currency = "iron",
							itemType = "wool_white",
							amount = 16,
							price = 8,
							disabledInQueue = {
								"mine_wars"
							},
							category = "Blocks"
						},
						shopId = "1_item_shop"
					}
				}
				
				game:GetService("ReplicatedStorage")
					:WaitForChild("rbxts_include")
					:WaitForChild("node_modules")
					:WaitForChild("@rbxts")
					:WaitForChild("net")
					:WaitForChild("out")
					:WaitForChild("_NetManaged")
					:WaitForChild("BedwarsPurchaseItem")
					:InvokeServer(unpack(args))
			end)
			
			if success then
				attempts = attempts + 1
				if attempts % 5 == 0 then
					notif("Shop", "bought some blocks (" .. woolCount .. "/128)", 1, "info")
				end
			else
				notif("Shop", "your broke only got " .. woolCount .. " blocks", 3, "alert")
				break
			end
			
			task.wait(buyDelay)
		end
		
		return true
	end
	
	local function clearPathVisuals()
		for _, part in pathParts do
			part:Destroy()
		end
		table.clear(pathParts)
	end
	
	local function drawPath(path)
		clearPathVisuals()
		if not ShowPath.Enabled then return end
		
		for i, pos in path do
			local part = Instance.new("Part")
			part.Size = Vector3.new(2, 0.2, 2)
			part.Position = pos
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Transparency = 0.3
			
			local progress = i / #path
			part.Color = Color3.fromHSV(0.3 * (1 - progress), 1, 1)
			
			part.Parent = workspace
			table.insert(pathParts, part)
		
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 50, 0, 50)
			billboard.StudsOffset = Vector3.new(0, 2, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = part
			
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = tostring(i)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextScaled = true
			label.Font = Enum.Font.SourceSansBold
			label.Parent = billboard
		end
	end
	
	local function hasObstacle(pos)
		if getPlacedBlock(pos) then return true end
		
		if getPlacedBlock(pos + Vector3.new(0, 6, 0)) then return true end
		
		if getPlacedBlock(pos + Vector3.new(0, 3, 0)) then return true end
		
		return false
	end
	
	local function isSafePosition(pos)
		if pos.Y < 0 then return false end
		
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
		
		local ray = workspace:Raycast(pos, Vector3.new(0, -5, 0), rayParams)
		if not ray then return false end
		
		if ray.Distance > 4 then return false end
		
		return true
	end
	
	local function findPath(startPos, endPos)
		local gridSize = 3
		local maxDistance = 30000
		
		local function snapToGround(pos)
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Blacklist
			rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
			
			local ray = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), rayParams)
			if ray then
				return ray.Position + Vector3.new(0, 0.5, 0) 
			end
			return pos
		end
		
		local function roundToGrid(pos)
			local rounded = Vector3.new(
				math.floor(pos.X / gridSize + 0.5) * gridSize,
				math.floor(pos.Y / gridSize + 0.5) * gridSize,
				math.floor(pos.Z / gridSize + 0.5) * gridSize
			)
			return snapToGround(rounded)
		end
		
		startPos = roundToGrid(startPos)
		endPos = roundToGrid(endPos)
		
		local function makeNode(pos, parent, g, h)
			return {
				pos = pos,
				parent = parent,
				g = g or 0,
				h = h or 0,
				f = (g or 0) + (h or 0)
			}
		end
		
		local function heuristic(pos1, pos2)
			return (pos1 - pos2).Magnitude
		end
		
		local function getNeighbors(pos)
			local neighbors = {}
			local directions = {
				Vector3.new(gridSize, 0, 0),
				Vector3.new(-gridSize, 0, 0),
				Vector3.new(0, 0, gridSize),
				Vector3.new(0, 0, -gridSize),
				Vector3.new(gridSize, 0, gridSize),
				Vector3.new(-gridSize, 0, gridSize),
				Vector3.new(gridSize, 0, -gridSize),
				Vector3.new(-gridSize, 0, -gridSize)
			}
			
			for _, dir in directions do
				local newPos = snapToGround(pos + dir)
				
				if (newPos - startPos).Magnitude > maxDistance then continue end
				
				if not hasObstacle(newPos) then
					table.insert(neighbors, newPos)
				else
					local upPos = snapToGround(pos + dir + Vector3.new(0, gridSize, 0))
					if not hasObstacle(upPos) then
						table.insert(neighbors, upPos)
					end
					
					local upPos2 = snapToGround(pos + dir + Vector3.new(0, gridSize * 2, 0))
					if not hasObstacle(upPos2) then
						table.insert(neighbors, upPos2)
					end
				end
			end
			
			return neighbors
		end
		
		local openSet = {makeNode(startPos, nil, 0, heuristic(startPos, endPos))}
		local closedSet = {}
		local openSetMap = {[tostring(startPos)] = openSet[1]}
		
		local iterations = 0
		local maxIterations = 2000 
		
		while #openSet > 0 and iterations < maxIterations do
			iterations = iterations + 1
			
			table.sort(openSet, function(a, b) return a.f < b.f end)
			local current = table.remove(openSet, 1)
			openSetMap[tostring(current.pos)] = nil
			
			if (current.pos - endPos).Magnitude < gridSize * 2 then
				local path = {}
				local node = current
				while node do
					table.insert(path, 1, node.pos)
					node = node.parent
				end
				return path
			end
			
			closedSet[tostring(current.pos)] = true
			
			for _, neighborPos in getNeighbors(current.pos) do
				local neighborKey = tostring(neighborPos)
				
				if not closedSet[neighborKey] then
					local g = current.g + (neighborPos - current.pos).Magnitude
					local h = heuristic(neighborPos, endPos)
					local neighbor = makeNode(neighborPos, current, g, h)
					
					local existingNode = openSetMap[neighborKey]
					if not existingNode or g < existingNode.g then
						openSetMap[neighborKey] = neighbor
						if not existingNode then
							table.insert(openSet, neighbor)
						else
							existingNode.g = g
							existingNode.f = g + h
							existingNode.parent = current
						end
					end
				end
			end
			
			if iterations % 50 == 0 then
				task.wait()
			end
		end
		
		return nil 
	end
	
	local function isSuffocated()
		if not entitylib.isAlive then return false end
		
		local rootPart = entitylib.character.RootPart
		local headPos = entitylib.character.Head.Position
		
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
		
		local upRay = workspace:Raycast(headPos, Vector3.new(0, 2, 0), rayParams)
		if upRay then return true end
		
		local surroundedCount = 0
		local directions = {
			Vector3.new(2, 0, 0),
			Vector3.new(-2, 0, 0),
			Vector3.new(0, 0, 2),
			Vector3.new(0, 0, -2)
		}
		
		for _, dir in directions do
			local ray = workspace:Raycast(rootPart.Position, dir, rayParams)
			if ray and ray.Distance < 2.5 then
				surroundedCount = surroundedCount + 1
			end
		end
		
		return surroundedCount >= 3
	end
	
	local function hasBlockInFront(direction)
		if not entitylib.isAlive then return false end
		
		local rootPart = entitylib.character.RootPart
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
		
		for yOffset = 0, 3, 1 do
			local checkPos = rootPart.Position + Vector3.new(0, yOffset, 0)
			local ray = workspace:Raycast(checkPos, direction * 3, rayParams)
			if ray then
				return true
			end
		end
		
		return false
	end
	
	local function followPath(path)
		if not path or #path == 0 then return false end
		
		for i, waypoint in path do
			if not AG.Enabled or not entitylib.isAlive then return false end
			
			local character = entitylib.character
			local humanoid = character.Humanoid
			local rootPart = character.RootPart
			
			notif("Path Finder", "Waypoint " .. i .. "/" .. #path, 1, "info")
			
			local startTime = tick()
			local timeout = 15
			local lastPos = rootPart.Position
			local stuckTimer = 0
			local lastJumpTime = 0
			
			while tick() - startTime < timeout do
				if not AG.Enabled or not entitylib.isAlive then return false end
				
				local currentPos = rootPart.Position
				local distance = (waypoint - currentPos).Magnitude
				
				if distance < 5 then
					break
				end
				
				humanoid:MoveTo(waypoint)
				
				local moved = (currentPos - lastPos).Magnitude
				if moved < 0.3 then
					stuckTimer = stuckTimer + 0.2
					
					if stuckTimer > 0.6 and (tick() - lastJumpTime) > 1 then
						notif("STUCK", "jumping over", 0.5, "alert")
						
						humanoid:MoveTo(waypoint)
						task.wait(0.1)
						humanoid.Jump = true
						pcall(function()
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end)
						lastJumpTime = tick()
						task.wait(0.5)
						
						stuckTimer = 0
					end
				else
					stuckTimer = 0
				end
				lastPos = currentPos
				
				local heightDiff = waypoint.Y - currentPos.Y
				
				if heightDiff > 2 and (tick() - lastJumpTime) > 1 then
					humanoid.Jump = true
					pcall(function()
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end)
					lastJumpTime = tick()
					notif("Jump", "Going up", 0.3, "info")
					task.wait(0.5)
					continue
				end
				
				task.wait(0.2)
			end
		end
		
		return true
	end
	
	local function findShopKeeper()
		local shop = workspace:FindFirstChild("1_item_shop")
		if not shop then return nil end
		
		local merchant = shop:FindFirstChild("desertMerchant")
		if not merchant then return nil end
		
		for _, child in merchant:GetDescendants() do
			if child:IsA("BasePart") and (child.Name == "HumanoidRootPart" or child.Name == "Head") then
				return child.Position
			end
		end
		
		return nil
	end
	
	local function findEnemyBed()
		if not lplr:GetAttribute("Team") then return nil end
		
		local closestBed = nil
		local closestDist = math.huge
		
		for _, bed in collectionService:GetTagged("bed") do
			if bed:GetAttribute("id") and bed:GetAttribute("id") ~= lplr:GetAttribute("Team").."_bed" then
				if bed:GetAttribute("NoBreak") then continue end
				
				local dist = (bed.Position - lplr.Character.PrimaryPart.Position).Magnitude
				if dist < closestDist then
					closestBed = bed
					closestDist = dist
				end
			end
		end
		
		return closestBed and closestBed.Position or nil
	end
	
	local function breakBed()
		if not entitylib.isAlive then return false end
		
		notif("Breaker", "starting to break bed...", 2, "info")
		
		local function getBestTool()
			local bestSlot = nil
			local bestTool = nil
			
			for slot, item in store.inventory.hotbar do
				if item.item and bedwars.ItemMeta[item.item.itemType] then
					local meta = bedwars.ItemMeta[item.item.itemType]
					if meta.sword or meta.breakBlock then
						if not bestTool or (meta.sword and not bestTool.sword) then
							bestSlot = slot - 1
							bestTool = meta
						end
					end
				end
			end
			
			return bestSlot
		end
		
		local maxTime = 30
		local startTime = tick()
		local originalSlot = store.inventory.hotbarSlot
		
		while tick() - startTime < maxTime and AG.Enabled and entitylib.isAlive do
			local localPosition = entitylib.character.RootPart.Position
			
			local beds = collectionService:GetTagged("bed")
			local bedTable = {}
			
			for _, v in beds do
				if v:GetAttribute("id") and v:GetAttribute("id") ~= lplr:GetAttribute("Team").."_bed" then
					if v:GetAttribute("NoBreak") or (v:GetAttribute("BedShieldEndTime") or 0) > workspace:GetServerTimeNow() then continue end
					
					local distance = (v.Position - localPosition).Magnitude
					if distance < 30 and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
						table.insert(bedTable, v)
					end
				end
			end
			
			if #bedTable == 0 then
				notif("Breaker", "got the bed", 3, "success")
				if originalSlot then
					bedwars.ClientStoreHandler:dispatch({
						type = 'InventorySelectHotbarSlot',
						slot = originalSlot
					})
				end
				return true
			end
			
			table.sort(bedTable, function(a, b)
				return (a.Position - localPosition).Magnitude < (b.Position - localPosition).Magnitude
			end)
			
			local bestSlot = getBestTool()
			if bestSlot and store.inventory.hotbarSlot ~= bestSlot then
				bedwars.ClientStoreHandler:dispatch({
					type = 'InventorySelectHotbarSlot',
					slot = bestSlot
				})
				task.wait(0.05)
			end
			
			for _, v in bedTable do
				if (v.Position - localPosition).Magnitude < 30 then
					local target, path, endpos = bedwars.breakBlock(v, false, false, nil, true)
					task.wait(0.25)
					break
				end
			end
			
			task.wait(0.1)
		end
		
		if originalSlot then
			bedwars.ClientStoreHandler:dispatch({
				type = 'InventorySelectHotbarSlot',
				slot = originalSlot
			})
		end
		
		notif("Breaker", "breaking randomly stopped", 3, "alert")
		return false
	end
	
	local function configureKillaura()
		if not vape.Modules.Killaura then return end
		
		pcall(function()
			if vape.Modules.Killaura.api.AngleSlider then
				vape.Modules.Killaura.api.AngleSlider:SetValue(360)
			end
			
			if vape.Modules.Killaura.api.SwingRange then
				vape.Modules.Killaura.api.SwingRange:SetValue(40)
			end
			
			if vape.Modules.Killaura.api.AttackRange then
				vape.Modules.Killaura.api.AttackRange:SetValue(35)
			end
			
			if vape.Modules.Killaura.api.GUI and not vape.Modules.Killaura.api.GUI.Enabled then
				vape.Modules.Killaura.api.GUI:Toggle()
			end
			
			if vape.Modules.Killaura.api.Limit and not vape.Modules.Killaura.api.Limit.Enabled then
				vape.Modules.Killaura.api.Limit:Toggle()
			end
			
			if vape.Modules.Killaura.api.Targets then
				if vape.Modules.Killaura.api.Targets.Walls and not vape.Modules.Killaura.api.Targets.Walls.Enabled then
					vape.Modules.Killaura.api.Targets.Walls:Toggle()
				end
				
				if vape.Modules.Killaura.api.Targets.NPCs and not vape.Modules.Killaura.api.Targets.NPCs.Enabled then
					vape.Modules.Killaura.api.Targets.NPCs:Toggle()
				end
			end
			
			notif("Killaura", "KA Sets: 360° angle, 40 swing, 35 attack, walls + NPCs", 3, "info")
		end)
	end
	
	local function runBotSequence()
		if not entitylib.isAlive then return end
		
		notif("Path Finder", "we finna start bitches", 2, "info")
		
		configureKillaura()
		
		enablePickupRange()
		notif("Path Finder", "pickup range enabled", 2, "success")
		
		task.wait(9)
		
		if not AG.Enabled or not entitylib.isAlive then return end
		
		local shopPos = findShopKeeper()
		if not shopPos then
			notif("Path Finder", "shop keeper not found!", 5, "alert")
			return
		end
		
		notif("Path Finder", "calculating path to shop...", 3, "info")
		local pathToShop = findPath(lplr.Character.PrimaryPart.Position, shopPos)
		
		if not pathToShop then
			notif("Path Finder", "cant finda. valid apth to shop", 5, "alert")
			return
		end
		
		notif("Path Finder", "found path (" .. #pathToShop .. " waypoints) walking to shop...", 3, "success")
		drawPath(pathToShop)
		
		local success = followPath(pathToShop)
		if not success then
			notif("Path Finder", "cant reach shop", 5, "alert")
			clearPathVisuals()
			return
		end
		
		notif("Path Finder", "reached shop", 3, "success")
		clearPathVisuals()
		
		buyBlocks()
		
		task.wait(2)
		
		if not AG.Enabled or not entitylib.isAlive then return end
		
		local bedPos = findEnemyBed()
		if not bedPos then
			notif("Path Finder", "cant find other team bed", 5, "alert")
			return
		end
		
		notif("Path Finder", "making a path to bed..", 3, "info")
		local pathToBed = findPath(lplr.Character.PrimaryPart.Position, bedPos)
		
		if not pathToBed then
			notif("Path Finder", "cant find a valid path to bed", 5, "alert")
			return
		end
		
		notif("Path Finder", "found the path, walking to bed..", 3, "success")
		drawPath(pathToBed)
		
		scaffoldEnabled = true
		
		task.spawn(function()
			while AG.Enabled and entitylib.isAlive and scaffoldEnabled do
				doScaffold()
				task.wait(0.01)
			end
		end)
		
		if vape.Modules.Killaura and not vape.Modules.Killaura.Enabled then
			vape.Modules.Killaura:Toggle()
		end
		
		success = followPath(pathToBed)
		if not success then
			notif("Path Finder", "failed to reach bed", 5, "alert")
			clearPathVisuals()
			scaffoldEnabled = false
			return
		end
		
		scaffoldEnabled = false
		
		notif("Path Finder", "reached enemy bed", 3, "success")
		clearPathVisuals()
		
		breakBed()
		
		if vape.Modules.Killaura and vape.Modules.Killaura.Enabled then
			vape.Modules.Killaura:Toggle()
		end
		
		notif("Bot", "Waiting for match end...", 3, "info")
	end
	
	AG = vape.Categories.Utility:CreateModule({
		Name = "AccountGrinding",
		Tooltip = "A* pathfinding with visualization",
		Function = function(callback)
			if callback then
				task.spawn(runBotSequence)
				
				AG:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						clearPathVisuals()
						if not RH.Value then
							return lobby()
						end
						
						local TeleportService = game:GetService("TeleportService")
						local data = TeleportService:GetLocalPlayerTeleportData()
						TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer, data)
					end
				end))
				
				AG:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					clearPathVisuals()
					if not RH.Value then
						return lobby()
					end
					
					local TeleportService = game:GetService("TeleportService")
					local data = TeleportService:GetLocalPlayerTeleportData()
					TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer, data)
				end))
			else
				PickupEnabled = false
				scaffoldEnabled = false
				clearPathVisuals()
			end
		end
	})

	RH = AG:CreateToggle({
		Name = "Reset History",
		Default = false,
		Tooltip = "Teleport to new game instead of lobby"
	})
	
	ShowPath = AG:CreateToggle({
		Name = "Show Path",
		Default = true,
		Tooltip = "Visualize the path with colored blocks"
	})
end)--]]

run(function()
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() 
						module = require(lplr.PlayerScripts.PlayerModule).controls 
					end)
					if not suc then module = {} end
				end
				
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = game.Workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = game.Workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = '"I need safe walk to main jugg" - desire'
	})
end)

run(function()
	local KaidaKillaura
	local Targets
	local AttackRange
	local UpdateRate
	local MouseDown
	local GUICheck
	local ShowAnimation
	local PerfectAbility
	local AbilityDistance
	local SwingDuringAbility
	local lastAttackTime = 0
	local lastAbilityTime = 0
	local attackCooldown = 0.65
	local abilityCooldown = 22
	local isChargingAbility = false
	local abilityStartTime = 0
	
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
	
	KaidaKillaura = vape.Categories.Blatant:CreateModule({
		Name = 'Kaida Killaura',
		Function = function(callback)
			
			if callback then
				if store.equippedKit ~= 'summoner' then
					notif('Kaida Killaura', 'You need to be using Summoner kit!', 3, 'alert')
					KaidaKillaura:Toggle()
					return
				end
				
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
						local itemType = handItem.Value.Name
						hasClaw = itemType:find('summoner_claw')
					end
					
					if not hasClaw then
						task.wait(0.1)
						continue
					end
					
					if MouseDown.Enabled then
						local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						if not mousePressed then
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
						local currentTime = workspace:GetServerTimeNow()
						
						if PerfectAbility.Enabled and targetDistance <= AbilityDistance.Value then
							if (currentTime - lastAbilityTime) >= abilityCooldown then
								if not isChargingAbility then
									pcall(function()
										game:GetService("ReplicatedStorage")
											:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
											:WaitForChild("useAbility"):FireServer("summoner_start_charging")
									end)
									isChargingAbility = true
									abilityStartTime = currentTime
								end
								
								local chargeTime = currentTime - abilityStartTime
								if chargeTime >= 0.5 then
									pcall(function()
										game:GetService("ReplicatedStorage")
											:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
											:WaitForChild("useAbility"):FireServer("summoner_finish_charging")
									end)
									isChargingAbility = false
									lastAbilityTime = currentTime
								end
							end
						else
							if isChargingAbility then
								isChargingAbility = false
							end
						end
						if (currentTime - lastAttackTime) >= attackCooldown then
							if isChargingAbility and not SwingDuringAbility.Enabled then
								task.wait(0.05)
								continue
							end
							
							local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
							localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
							lastAttackTime = currentTime
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
										if camera and camera.CFrame.Position and (camera.CFrame.Position - entitylib.character.RootPart.Position).Magnitude < 1 then
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
								clientTime = currentTime
							})
						end
					else
						if isChargingAbility then
							isChargingAbility = false
						end
					end
					
					task.wait(1 / UpdateRate.Value)
				until not KaidaKillaura.Enabled
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
		Tooltip = 'Continue claw attacks while charging ability (disable for legit gameplay)'
	})
	
	PerfectAbility = KaidaKillaura:CreateToggle({
		Name = 'Perfect Ability',
		Default = false,
		Tooltip = 'Uses ability with minimum 0.5s charge when enemy is close',
		Function = function(callback)
			AbilityDistance.Object.Visible = callback
		end
	})
	
	AbilityDistance = KaidaKillaura:CreateSlider({
		Name = 'Ability Distance',
		Min = 3,
		Max = 15,
		Default = 6,
		Visible = false,
		Tooltip = 'Distance to trigger ability (in studs, 3 studs = 1 block)',
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
    local OGNametags = vape.Categories.Render:CreateModule({
        Name = "OG Nametags",
        Function = function(callback)
            
            if callback then
                local storedNametags = {}
                local localPlayer = playersService.LocalPlayer
                local localTeamId = localPlayer and localPlayer:GetAttribute("Team")
                
                local function createOGNametag(character)
                    if not character then return end
                    
                    local head = character:FindFirstChild("Head")
                    if not head then return end
                    
                    local originalNametag = head:FindFirstChild("Nametag")
                    if originalNametag then
                        storedNametags[character] = originalNametag:Clone()
                        originalNametag:Destroy()
                    end
                    
                    local oldOGNametag = head:FindFirstChild("OGNametag")
                    if oldOGNametag then oldOGNametag:Destroy() end
                    
                    local nametag = Instance.new("BillboardGui")
                    nametag.Name = "OGNametag"
                    nametag.Size = UDim2.fromScale(5, 0.65)
                    nametag.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
                    nametag.AlwaysOnTop = true
                    nametag.MaxDistance = 150
                    nametag.ResetOnSpawn = false
                    nametag.AutoLocalize = false
                    nametag.Adornee = head
                    
                    local mainContainer = Instance.new("Frame")
                    mainContainer.Name = "MainContainer"
                    mainContainer.Size = UDim2.fromScale(1, 1)
                    mainContainer.BackgroundTransparency = 1
                    mainContainer.BorderSizePixel = 0
                    mainContainer.Parent = nametag
                    
                    local teamCircle = Instance.new("Frame")
                    teamCircle.Name = "TeamCircle"
                    teamCircle.Size = UDim2.fromScale(0.15, 0.8)
                    teamCircle.Position = UDim2.fromScale(0.05, 0.1)
                    teamCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    teamCircle.BackgroundTransparency = 0.3
                    teamCircle.BorderSizePixel = 0
                    
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(1, 0)
                    corner.Parent = teamCircle
                    
                    teamCircle.Parent = mainContainer
                    
                    local nameBg = Instance.new("Frame")
                    nameBg.Name = "NameBackground"
                    nameBg.Size = UDim2.fromScale(0.7, 0.8)
                    nameBg.Position = UDim2.fromScale(0.25, 0.1)
                    nameBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    nameBg.BackgroundTransparency = 0.5
                    nameBg.BorderSizePixel = 0
                    
                    local outline = Instance.new("UIStroke")
                    outline.Thickness = 1.5
                    outline.Color = Color3.fromRGB(255, 255, 255)
                    outline.Parent = nameBg
                    
                    nameBg.Parent = mainContainer
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Name = "Name"
                    
                    local player = playersService:GetPlayerFromCharacter(character)
                    local displayName = character.Name
                    
                    if player then
                        local clanTag = player:GetAttribute("ClanTag")
                        if clanTag and clanTag ~= "" then
                            displayName = "[" .. clanTag .. "] " .. displayName
                        end
                    end
                    
                    nameLabel.Text = displayName
                    nameLabel.Size = UDim2.fromScale(0.95, 0.9)
                    nameLabel.Position = UDim2.fromScale(0.5, 0.5)
                    nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.Font = Enum.Font.GothamMedium
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.BorderSizePixel = 0
                    nameLabel.TextScaled = true
                    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
                    
                    nameLabel.Parent = nameBg
                    
                    nametag.Parent = head
                    
                    local teamId = player and player:GetAttribute("Team") or character:GetAttribute("Team")
                    
                    if teamId then
                        task.spawn(function()
                            local success, KnitClient = pcall(function()
                                return require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['knit'].src).KnitClient
                            end)
                            
                            if success and KnitClient and KnitClient.Controllers and KnitClient.Controllers.TeamController then
                                local team = KnitClient.Controllers.TeamController:getTeamById(teamId)
                                if team and team.color then
                                    teamCircle.BackgroundColor3 = team.color
                                    outline.Color = team.color
                                    
                                    local localPlayer = playersService.LocalPlayer
                                    local localTeamId = localPlayer and localPlayer:GetAttribute("Team")
                                    
                                    if teamId == localTeamId then
                                        nameLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
                                    else
                                        nameLabel.TextColor3 = Color3.fromRGB(255, 0, 0) 
                                    end
                                end
                            end
                        end)
                    end
                end
                
                for _, player in playersService:GetPlayers() do
                    if player.Character then
                        createOGNametag(player.Character)
                    end
                    
                    player.CharacterAdded:Connect(function(character)
                        task.wait(0.1)
                        createOGNametag(character)
                    end)
                end
                
                for _, entity in collectionService:GetTagged("entity") do
                    if entity:IsA("Model") then
                        createOGNametag(entity)
                    end
                end
                
                playersService.PlayerAdded:Connect(function(player)
                    if player.Character then
                        createOGNametag(player.Character)
                    end
                    
                    player.CharacterAdded:Connect(function(character)
                        task.wait(0.1)
                        createOGNametag(character)
                    end)
                end)
                
                collectionService:GetInstanceAddedSignal("entity"):Connect(function(entity)
                    if entity:IsA("Model") then
                        task.wait(0.1)
                        createOGNametag(entity)
                    end
                end)
                
            else
                for _, player in playersService:GetPlayers() do
                    if player.Character then
                        local head = player.Character:FindFirstChild("Head")
                        if head then
                            local ogNametag = head:FindFirstChild("OGNametag")
                            if ogNametag then
                                ogNametag:Destroy()
                            end
                            
                            if storedNametags[player.Character] then
                                local restoredNametag = storedNametags[player.Character]:Clone()
                                restoredNametag.Parent = head
                                storedNametags[player.Character] = nil
                            end
                        end
                    end
                end
                
                for _, entity in collectionService:GetTagged("entity") do
                    if entity:IsA("Model") then
                        local head = entity:FindFirstChild("Head")
                        if head then
                            local ogNametag = head:FindFirstChild("OGNametag")
                            if ogNametag then
                                ogNametag:Destroy()
                            end
                            
                            if storedNametags[entity] then
                                local restoredNametag = storedNametags[entity]:Clone()
                                restoredNametag.Parent = head
                                storedNametags[entity] = nil
                            end
                        end
                    end
                end
                
                table.clear(storedNametags)
            end
        end,
        Tooltip = "Replaces all nametags with OG BedWars nametags"
    })
end)

run(function()
	local NoNameTag
	local originalNametag = nil
	local nametagConnection = nil
	
	NoNameTag = vape.Categories.Utility:CreateModule({
		Name = 'NoNameTag',
		Tooltip = 'Removes your NameTag',
		Function = function(callback)
			
			if callback then
				if entitylib.isAlive and lplr.Character.Head:FindFirstChild('Nametag') then
					originalNametag = lplr.Character.Head.Nametag:Clone()
				end
				
				nametagConnection = runService.RenderStepped:Connect(function()
					pcall(function()
						if entitylib.isAlive and lplr.Character.Head:FindFirstChild('Nametag') then
							lplr.Character.Head.Nametag:Destroy()
						end
					end)
				end)
				
				NoNameTag:Clean(lplr.CharacterAdded:Connect(function()
					task.wait(0.5) 
					if NoNameTag.Enabled then
						originalNametag = nil
						if lplr.Character and lplr.Character:FindFirstChild('Head') then
							pcall(function()
								if lplr.Character.Head:FindFirstChild('Nametag') then
									originalNametag = lplr.Character.Head.Nametag:Clone()
									lplr.Character.Head.Nametag:Destroy()
								end
							end)
						end
					end
				end))
			else
				if nametagConnection then
					nametagConnection:Disconnect()
					nametagConnection = nil
				end
				
				if originalNametag then
					pcall(function()
						if entitylib.isAlive and lplr.Character.Head then
							local existing = lplr.Character.Head:FindFirstChild('Nametag')
							if existing then
								existing:Destroy()
							end
							
							local restoredTag = originalNametag:Clone()
							restoredTag.Parent = lplr.Character.Head
							
							restoredTag.Visible = true
						end
					end)
				else
					pcall(function()
						if entitylib.isAlive and lplr.Character.Head then
							local existing = lplr.Character.Head:FindFirstChild('Nametag')
							if not existing then
								lplr:SetAttribute("ForceNametagUpdate", tick())
							end
						end
					end)
				end
			end
		end,
	})
end)

run(function()
	local AutoEmptyGameTP
	local TeleportOnMatchEnd
	
	local function isGameEmpty()
		return #playersService:GetPlayers() <= 1
	end
	
	local function isEveryoneDead()
		for _, player in playersService:GetPlayers() do
			if player ~= lplr and player:GetAttribute("PlayingAsKit") then
				if player.Character and player.Character:GetAttribute("Health") > 0 then
					return false
				end
			end
		end
		return true
	end
	
	local function teleportToNewGame()
		if isGameEmpty() then return end 
		
		local TeleportService = game:GetService("TeleportService")
		local data = TeleportService:GetLocalPlayerTeleportData()
		
		notif("AutoEmptyGameTP", "tping to new game...", 3)
		task.wait(0.5) 
		
		AutoEmptyGameTP:Clean(TeleportService:Teleport(game.PlaceId, lplr, data))
	end
	
	local function handleMatchCompletion()
		if store.matchState == 2 then 
			teleportToNewGame()
		end
	end
	
	AutoEmptyGameTP = vape.Categories.Blatant:CreateModule({
		Name = 'AutoEmptyGameTP',
		Function = function(callback)
			
			if callback then
				if TeleportOnMatchEnd.Enabled then
					AutoEmptyGameTP:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
						task.wait(1) 
						handleMatchCompletion()
					end))
					
					AutoEmptyGameTP:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
						if deathTable.finalKill and deathTable.entityInstance == lplr.Character then
							task.wait(1) 
							if isEveryoneDead() and store.matchState ~= 2 then
								teleportToNewGame()
							end
						end
					end))
				else
					if not isGameEmpty() then
						notif("AutoEmptyGameTP", "finding empty game...", 4)
						task.wait(1.5) 
						teleportToNewGame()
					else
						notif("AutoEmptyGameTP", "already in empty game", 3)
						AutoEmptyGameTP:Toggle() 
					end
				end
			end
		end,
		Tooltip = 'teleports you to an empty\nuseful for resetting match history]'
	})
	
	TeleportOnMatchEnd = AutoEmptyGameTP:CreateToggle({
		Name = "Teleport After Match",
		Default = true,
		Tooltip = "waits until match ends (win/loss) before teleporting\ndisable for instant teleport to empty game(idea from soyred)"
	})
end)

run(function()
	local WoolColorChanger
	local WoolChanged = {}
	
	local function isValidWoolBlock(obj)
		if not obj:IsA("BasePart") then
			return false
		end
		
		if obj.Name ~= "wool_orange" then
			return false
		end
		
		local parent = obj.Parent
		if parent then
			if parent.Name == "Viewmodel" or parent.Parent and parent.Parent.Name == "Viewmodel" then
				return false
			end
			
			if parent:IsA("Accessory") or parent:IsA("Tool") then
				return false
			end
			
			local ancestor = parent
			while ancestor do
				if ancestor:IsA("Model") and playersService:GetPlayerFromCharacter(ancestor) then
					return false
				end
				ancestor = ancestor.Parent
			end
		end
		
		return true
	end
	
	local function changeWoolColor(block)
		if not isValidWoolBlock(block) then return block end
		
		if not WoolChanged[block] then
			WoolChanged[block] = {
				originalName = block.Name,
				originalColor = block.Color,
				originalMaterial = block.Material,
				originalTextures = {},
				changed = false
			}
			
			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceGui") then
					table.insert(WoolChanged[block].originalTextures, {
						instance = child,
						parent = block
					})
					child.Parent = nil
				end
			end
			
			block.Name = "wool_red"
			block.Color = Color3.fromRGB(196, 40, 28) 
			block.Material = Enum.Material.Fabric 
			
			WoolChanged[block].changed = true
			
			local colorConnection = block:GetPropertyChangedSignal("Color"):Connect(function()
				if WoolColorChanger.Enabled and block.Color ~= Color3.fromRGB(196, 40, 28) then
					block.Color = Color3.fromRGB(196, 40, 28)
				end
			end)
			
			local nameConnection = block:GetPropertyChangedSignal("Name"):Connect(function()
				if WoolColorChanger.Enabled and block.Name ~= "wool_red" then
					block.Name = "wool_red"
				end
			end)
			
			local childAddedConnection = block.ChildAdded:Connect(function(child)
				if WoolColorChanger.Enabled and (child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceGui")) then
					child.Parent = nil
				end
			end)
			
			WoolChanged[block].connections = {colorConnection, nameConnection, childAddedConnection}
		end
		
		return block
	end
	
	local function scanAndChangeWool()
		if not WoolColorChanger.Enabled then return end
		
		for _, descendant in workspace:GetDescendants() do
			if isValidWoolBlock(descendant) then
				changeWoolColor(descendant)
			end
		end
	end
	
	local function reverseChanges()
		for block, data in WoolChanged do
			if data.changed and block.Parent then
				if data.connections then
					for _, connection in data.connections do
						connection:Disconnect()
					end
				end
				
				block.Name = data.originalName
				block.Color = data.originalColor
				block.Material = data.originalMaterial
				
				for _, textureData in data.originalTextures do
					if textureData.instance then
						textureData.instance.Parent = textureData.parent
					end
				end
				
				data.changed = false
			end
		end
		
		for block, data in WoolChanged do
			if not block.Parent then
				WoolChanged[block] = nil
			end
		end
	end
	
	WoolColorChanger = vape.Categories.Render:CreateModule({
		Name = 'REDvsBLUE (wool)',
		Function = function(callback)
			if callback then
				for block, data in WoolChanged do
					if data.connections then
						for _, connection in data.connections do
							connection:Disconnect()
						end
					end
				end
				table.clear(WoolChanged)
				
				scanAndChangeWool()
				
				local descendantAddedConnection
				descendantAddedConnection = workspace.DescendantAdded:Connect(function(descendant)
					task.wait(0.05) 
					if WoolColorChanger.Enabled and isValidWoolBlock(descendant) then
						changeWoolColor(descendant)
					end
				end)
				
				local descendantRemovingConnection
				descendantRemovingConnection = workspace.DescendantRemoving:Connect(function(descendant)
					if WoolChanged[descendant] then
						if WoolChanged[descendant].connections then
							for _, connection in WoolChanged[descendant].connections do
								connection:Disconnect()
							end
						end
						WoolChanged[descendant] = nil
					end
				end)
				
				WoolColorChanger.connections = {
					descendantAddedConnection,
					descendantRemovingConnection
				}
				
			else
				if WoolColorChanger.connections then
					for _, connection in WoolColorChanger.connections do
						if connection then
							connection:Disconnect()
						end
					end
					WoolColorChanger.connections = nil
				end
				
				reverseChanges()
			end
		end,
		Tooltip = 'Changes orange wool blocks to red wool (client-side only, lag-free)'
	})
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
                task.wait(0.1)
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
        
        if Animation.Enabled then
            local currentTick = tick()
            if not animationDebounce[metalId] or (currentTick - animationDebounce[metalId]) >= 0.5 then
                animationDebounce[metalId] = currentTick
                bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
                bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
            end
        end
        
        local success = pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CollectCollectableEntity"):FireServer({
                id = metalId
            })
        end)
        
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
                        local metalPos = v.PrimaryPart.Position
                        local distance = (localPosition - metalPos).Magnitude
                        
                        if distance <= range then
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if collectMetal(v) then
                                collectedThisCycle = true
                                task.wait(0.15) 
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
        Name = 'Metal Detector',
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
                table.clear(spawnQueue)
                lastNotification = 0
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
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
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
end)

run(function()
    local FakeLag
    local Mode
    local Delay
    local TransmissionOffset
    local DynamicIntensity
    local originalRemotes = {}
    local queuedCalls = {}
    local isProcessing = false
    local callInterception = {}
    
    local function backupRemoteMethods()
        if not bedwars or not bedwars.Client then return end
        
        local oldGet = bedwars.Client.Get
        callInterception.oldGet = oldGet
        
        for name, path in pairs(remotes) do
            local remote = oldGet(bedwars.Client, path)
            if remote and remote.SendToServer then
                originalRemotes[path] = remote.SendToServer
            end
        end
    end
    
    local function processDelayedCalls()
        if isProcessing then return end
        isProcessing = true
        
        task.spawn(function()
            while FakeLag.Enabled and #queuedCalls > 0 do
                local currentTime = tick()
                local toExecute = {}
                
                for i = #queuedCalls, 1, -1 do
                    local call = queuedCalls[i]
                    if currentTime >= call.executeTime then
                        table.insert(toExecute, 1, call)
                        table.remove(queuedCalls, i)
                    end
                end
                
                for _, call in ipairs(toExecute) do
                    pcall(function()
                        if call.remote and call.method == "FireServer" then
                            call.remote:FireServer(unpack(call.args))
                        elseif call.remote and call.method == "InvokeServer" then
                            call.remote:InvokeServer(unpack(call.args))
                        elseif call.originalFunc then
                            call.originalFunc(call.remote, unpack(call.args))
                        end
                    end)
                end
                
                task.wait(0.001)
            end
            isProcessing = false
        end)
    end
    
    local function queueRemoteCall(remote, method, originalFunc, ...)
        local currentDelay = Delay.Value
        
        if Mode.Value == "Dynamic" then
            if entitylib.isAlive then
                local intensity = DynamicIntensity.Value / 100
                
                local velocity = entitylib.character.HumanoidRootPart.Velocity.Magnitude
                if velocity > 20 then
                    currentDelay = currentDelay * (1 + intensity * 0.5)
                end
                
                local lastDamage = entitylib.character.Character:GetAttribute('LastDamageTakenTime') or 0
                if tick() - lastDamage < 2 then
                    currentDelay = currentDelay * (1 + intensity * 0.7)
                end
            end
        elseif Mode.Value == "Repel" then
            if entitylib.isAlive then
                local nearestDist = math.huge
                for _, entity in ipairs(entitylib.List) do
                    if entity.Targetable and entity.Player and entity.Player ~= lplr then
                        local dist = (entity.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                        end
                    end
                end
                
                if nearestDist < 15 then
                    local repelFactor = (15 - nearestDist) / 15
                    currentDelay = currentDelay * (1 + (repelFactor * 2))
                end
            end
        end
        
        if TransmissionOffset.Value > 0 then
            local jitter = math.random(-TransmissionOffset.Value, TransmissionOffset.Value)
            currentDelay = math.max(0, currentDelay + jitter)
        end
        
        table.insert(queuedCalls, {
            remote = remote,
            method = method,
            originalFunc = originalFunc,
            args = {...},
            executeTime = tick() + (currentDelay / 1000)
        })
        
        processDelayedCalls()
    end
    
    local function interceptRemotes()
        if not bedwars or not bedwars.Client then return end
        
        local oldGet = callInterception.oldGet
        bedwars.Client.Get = function(self, remotePath)
            local remote = oldGet(self, remotePath)
            
            if remote and remote.SendToServer then
                local originalSend = remote.SendToServer
                remote.SendToServer = function(self, ...)
                    if FakeLag.Enabled and Delay.Value > 0 then
                        queueRemoteCall(self, "SendToServer", originalSend, ...)
                        return
                    end
                    return originalSend(self, ...)
                end
            end
            
            return remote
        end
        
        local function interceptSpecificRemote(path)
            local remote = oldGet(bedwars.Client, path)
            if remote and remote.FireServer then
                local originalFire = remote.FireServer
                remote.FireServer = function(self, ...)
                    if FakeLag.Enabled and Delay.Value > 0 then
                        queueRemoteCall(self, "FireServer", originalFire, ...)
                        return
                    end
                    return originalFire(self, ...)
                end
            end
        end
        
        if remotes.AttackEntity then interceptSpecificRemote(remotes.AttackEntity) end
        if remotes.PlaceBlockEvent then interceptSpecificRemote(remotes.PlaceBlockEvent) end
        if remotes.BreakBlockEvent then interceptSpecificRemote(remotes.BreakBlockEvent) end
    end
    
    FakeLag = vape.Categories.Utility:CreateModule({
        Name = 'FakeLag',
        Function = function(callback)
            if callback then
                backupRemoteMethods()
                interceptRemotes()
                
                vape:CreateNotification("FakeLag", 
                    string.format("Enabled - %s mode (%dms)", Mode.Value, Delay.Value), 
                    3)
            else
                if bedwars and bedwars.Client and callInterception.oldGet then
                    bedwars.Client.Get = callInterception.oldGet
                end
                
                for _, call in ipairs(queuedCalls) do
                    pcall(function()
                        if call.originalFunc then
                            call.originalFunc(call.remote, unpack(call.args))
                        end
                    end)
                end
                table.clear(queuedCalls)
                
                vape:CreateNotification("FakeLag", "Disabled", 3)
            end
        end,
        Tooltip = 'simulate fake lag n shit'
    })
    
    Mode = FakeLag:CreateDropdown({
        Name = 'Mode',
        List = {'Latency', 'Dynamic', 'Repel'},
        Default = 'Latency'
    })
    
    Delay = FakeLag:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 500,
        Default = 150,
        Suffix = 'ms'
    })
    
    DynamicIntensity = FakeLag:CreateSlider({
        Name = 'Intensity',
        Min = 0,
        Max = 100,
        Default = 50,
        Suffix = '%'
    })
end)

run(function()
	local NoCollision
	local connections = {}
	
	local function removeCollision(character)
		if not character then return end
		
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
			end
		end
	end
	
	local function restoreCollision(character)
		if not character then return end
		
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
				part.CanQuery = true
			end
		end
	end

	local function hasValidWeapon()
		if not store.hand or not store.hand.tool then return false end
		local toolType = store.hand.toolType
		local toolName = store.hand.tool.Name:lower()
		if toolName:find('headhunter') then
			return true
		end
		return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow' or 
		       toolType == 'axe' or toolType == 'pickaxe' or toolType == 'shears'
	end

	local function updateAllCollisions()
		local isWeaponEquipped = hasValidWeapon()
		for _, entity in pairs(entitylib.List) do
			if entity.Character and entity.Character.Parent then
				if isWeaponEquipped then
					restoreCollision(entity.Character)
				else
					removeCollision(entity.Character)
				end
			end
		end
	end
	
	NoCollision = vape.Categories.World:CreateModule({
		Name = 'NoCollision',
		Function = function(callback)
			if callback then
				local heartbeatConn = runService.Heartbeat:Connect(function()
					if not NoCollision.Enabled then return end
					updateAllCollisions()
				end)
				table.insert(connections, heartbeatConn)
				
				local function handleEntities()
					for _, entity in pairs(entitylib.List) do
						if entity.Character and entity.Character.Parent then
							if not hasValidWeapon() then
								removeCollision(entity.Character)
							end
						end
					end
				end
				handleEntities()
				
				local entityAddedConn = entitylib.Events.EntityAdded:Connect(function(entity)
					if not NoCollision.Enabled then return end
					if entity.Character then
						task.wait(0.1)
						if not hasValidWeapon() then
							removeCollision(entity.Character)
						end
					end
				end)
				table.insert(connections, entityAddedConn)
				
				local function onToolChanged()
					if not NoCollision.Enabled then return end
					updateAllCollisions()
				end
				
				local toolChangedConn
				if store and store.hand and store.hand.toolChanged then
					toolChangedConn = store.hand.toolChanged:Connect(onToolChanged)
					table.insert(connections, toolChangedConn)
				end
				
				updateAllCollisions()
			else
				for _, conn in pairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)
				
				for _, entity in pairs(entitylib.List) do
					if entity.Character then
						restoreCollision(entity.Character)
					end
				end
			end
		end,
		Tooltip = 'Mine through players and NPCs (collision restored only when weapons are equipped)'
	})
end)

run(function()
	local Mode
	local jumps = 0
	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = "Infinite Jump",
		Tooltip = "jumpjumpjump",
		Function = function(callback)
			if callback then
				jumps = 0														
				InfiniteFly:Clean(inputService.JumpRequest:Connect(function()
					jumps += 1
					if jumps > 1 and Mode.Value == "Velocity" then
						local power = math.sqrt(2 * workspace.Gravity * entitylib.character.Humanoid.JumpHeight)
						entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, power, entitylib.character.RootPart.Velocity.Z)
					elseif Mode.Value == "Jump" then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			end
		end,
		ExtraText = function() return Mode.Value or "HeatSeeker" end
	})
	Mode = InfiniteFly:CreateDropdown({
		Name = "Mode",
		List = {"Jump", "Velocity"}
	})
end)

run(function()
    local FalseBan
    local PlayerDropdown
    local InvisibleCharacters = {}
    local CharacterConnections = {}
    
    local function makeCharacterInvisible(character, player)
        if InvisibleCharacters[character] then return end
        local parts = {}
        local accessories = {}
        local nametag = nil
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if character:FindFirstChild("Head") then
            local head = character.Head
            if head:FindFirstChild("Nametag") then
                nametag = head.Nametag:Clone()
                head.Nametag:Destroy()
            end
        end
        
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                parts[part] = {
                    Transparency = part.Transparency,
                    CanCollide = part.CanCollide,
                    CastShadow = part.CastShadow
                }
                part.Transparency = 1
                part.CanCollide = false
                part.CastShadow = false
            elseif part:IsA("Decal") or part:IsA("Texture") then
                parts[part] = {Transparency = part.Transparency}
                part.Transparency = 1
            elseif part:IsA("ParticleEmitter") or part:IsA("Trail") then
                parts[part] = {Enabled = part.Enabled}
                part.Enabled = false
            elseif part:IsA("Accessory") then
                accessories[part] = {
                    Accessory = part,
                    Parent = part.Parent
                }
                part.Parent = nil
            end
        end
        
        if humanoid and humanoid.RootPart then
            parts[humanoid.RootPart] = parts[humanoid.RootPart] or {}
            parts[humanoid.RootPart].Transparency = 1
            humanoid.RootPart.Transparency = 1
            humanoid.RootPart.CanCollide = false
        end
        
        InvisibleCharacters[character] = {
            Parts = parts,
            Accessories = accessories,
            Nametag = nametag,
            Player = player,
            Connections = {}
        }
        
        local connections = InvisibleCharacters[character].Connections
        
        table.insert(connections, character.DescendantAdded:Connect(function(descendant)
            task.wait()
            if FalseBan.Enabled and InvisibleCharacters[character] then
                if descendant:IsA("BasePart") then
                    descendant.Transparency = 1
                    descendant.CanCollide = false
                    descendant.CastShadow = false
                elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
                    descendant.Transparency = 1
                elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                    descendant.Enabled = false
                elseif descendant:IsA("Accessory") then
                    local data = {
                        Accessory = descendant,
                        Parent = descendant.Parent
                    }
                    InvisibleCharacters[character].Accessories[descendant] = data
                    descendant.Parent = nil
                elseif descendant.Name == "Nametag" and descendant.Parent == character.Head then
                    descendant:Destroy()
                end
            end
        end))
        
        table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                restoreCharacterVisibility(character)
            end
        end))
        
        if humanoid then
            table.insert(connections, humanoid.Died:Connect(function()
                task.wait(2)
                restoreCharacterVisibility(character)
            end))
        end
    end
    
    function restoreCharacterVisibility(character)
        if not InvisibleCharacters[character] then return end
        
        local data = InvisibleCharacters[character]
        
        for part, properties in data.Parts do
            if part and part.Parent then
                if part:IsA("BasePart") then
                    part.Transparency = properties.Transparency or 0
                    part.CanCollide = properties.CanCollide ~= nil and properties.CanCollide or true
                    part.CastShadow = properties.CastShadow ~= nil and properties.CastShadow or true
                elseif part:IsA("Decal") or part:IsA("Texture") then
                    part.Transparency = properties.Transparency or 0
                elseif part:IsA("ParticleEmitter") or part:IsA("Trail") then
                    part.Enabled = properties.Enabled ~= nil and properties.Enabled or true
                end
            end
        end
        
        for accessory, accessoryData in data.Accessories do
            if accessory and accessoryData.Parent then
                pcall(function()
                    accessory.Parent = accessoryData.Parent
                end)
            end
        end
        
        if data.Nametag and character:FindFirstChild("Head") then
            pcall(function()
                local existingTag = character.Head:FindFirstChild("Nametag")
                if existingTag then
                    existingTag:Destroy()
                end
                
                local restoredTag = data.Nametag:Clone()
                restoredTag.Parent = character.Head
                restoredTag.Visible = true
            end)
        end
        
        for _, connection in data.Connections do
            pcall(function()
                connection:Disconnect()
            end)
        end
        
        InvisibleCharacters[character] = nil
    end
    
    local function getPlayerList()
        local playerList = {}
        
        for _, player in playersService:GetPlayers() do
            if player ~= lplr then
                table.insert(playerList, player.Name)
            end
        end
        
        table.sort(playerList)
        return playerList
    end
    
    local function setupPlayerConnections(player)
        if CharacterConnections[player] then return end
        
        local connections = {}
        
        table.insert(connections, player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            if FalseBan.Enabled and PlayerDropdown.Value == player.Name then
                makeCharacterInvisible(character, player)
            end
        end))
        
        table.insert(connections, player.CharacterRemoving:Connect(function(character)
            restoreCharacterVisibility(character)
        end))
        
        CharacterConnections[player] = connections
    end
    
    local function processSelectedPlayer()
        if PlayerDropdown.Value and PlayerDropdown.Value ~= "" then
            local player = playersService:FindFirstChild(PlayerDropdown.Value)
            if player and player.Character then
                makeCharacterInvisible(player.Character, player)
            end
        end
    end
    
    FalseBan = vape.Categories.Render:CreateModule({
        Name = 'FalseBan',
        Function = function(callback)
            if callback then
                for _, player in playersService:GetPlayers() do
                    if player ~= lplr then
                        setupPlayerConnections(player)
                    end
                end
                
                FalseBan:Clean(playersService.PlayerAdded:Connect(function(player)
                    if player == lplr then return end
                    
                    setupPlayerConnections(player)
                    
                    if player.Character and FalseBan.Enabled and PlayerDropdown.Value == player.Name then
                        task.wait(0.5)
                        makeCharacterInvisible(player.Character, player)
                    end
                end))
                
                FalseBan:Clean(playersService.PlayerRemoving:Connect(function(player)
                    if CharacterConnections[player] then
                        for _, connection in CharacterConnections[player] do
                            pcall(function()
                                connection:Disconnect()
                            end)
                        end
                        CharacterConnections[player] = nil
                    end
                    
                    if player.Character then
                        restoreCharacterVisibility(player.Character)
                    end
                end))
                
                processSelectedPlayer()
            else
                for character, _ in InvisibleCharacters do
                    restoreCharacterVisibility(character)
                end
                table.clear(InvisibleCharacters)
                
                for player, connections in CharacterConnections do
                    for _, connection in connections do
                        pcall(function()
                            connection:Disconnect()
                        end)
                    end
                end
                table.clear(CharacterConnections)
            end
        end,
        Tooltip = 'Select a player to make invisible (removes nametag too)'
    })
    
    PlayerDropdown = FalseBan:CreateDropdown({
        Name = 'Select Player',
        List = getPlayerList(),
        Function = function(val)
            if FalseBan.Enabled then
                FalseBan:Toggle()
                FalseBan:Toggle()
            end
        end
    })
end)

run(function()
    local YuziDasher
    local DashDelay
    local DelaySlider
    local KeybindToggle
    local KeybindList
    local MouseBindToggle
    local MouseBindList
    local KeybindMode
    local ImpulseSlider
    local JumpHeightSlider
    local CurrentKeybind = Enum.KeyCode.Q
    local CurrentMouseBind = Enum.UserInputType.MouseButton2
    local UseMouseBind = false
    local KeybindEnabled = false
    local KeybindHeld = false
    local KeybindActive = false
    local canDash = true
    local lastClickTime = 0
    
    local function PerformDash()
        if not canDash then
            return
        end
        
        if not entitylib.isAlive then
            return
        end
        
        local heldItem = store.hand.tool
        if not heldItem or not (heldItem.Name:find("dao") or heldItem.Name:find("yuzi")) then
            return
        end
        
        local character = lplr.Character
        if not (character and character.PrimaryPart) then
            return
        end

        canDash = false
        
        task.spawn(function()
            local originalJumpHeight = character.Humanoid.JumpHeight
            
            if bedwars.DasherKit and bedwars.DasherKit.canDashAttribute then
                pcall(function()
                    character:SetAttribute(bedwars.DasherKit.canDashAttribute, nil)
                end)
            end
            
            pcall(function()
                character:SetAttribute('CanDash', 0)
            end)
            
            local lookVector = gameCamera.CFrame.LookVector
            local origin = character.PrimaryPart.Position
            
            pcall(function()
                local SwingMissRemote = game:GetService("ReplicatedStorage"):FindFirstChild("rbxts_include")
                if SwingMissRemote then
                    SwingMissRemote = SwingMissRemote:FindFirstChild("node_modules")
                    if SwingMissRemote then
                        SwingMissRemote = SwingMissRemote:FindFirstChild("@rbxts")
                        if SwingMissRemote then
                            SwingMissRemote = SwingMissRemote:FindFirstChild("net")
                            if SwingMissRemote then
                                SwingMissRemote = SwingMissRemote:FindFirstChild("out")
                                if SwingMissRemote then
                                    SwingMissRemote = SwingMissRemote:FindFirstChild("_NetManaged")
                                    if SwingMissRemote then
                                        SwingMissRemote = SwingMissRemote:FindFirstChild("SwordSwingMiss")
                                        if SwingMissRemote then
                                            SwingMissRemote:FireServer({
                                                weapon = heldItem,
                                                chargeRatio = 0
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            task.wait(0.05)
            if bedwars.AbilityController:canUseAbility('dash') then
                bedwars.AbilityController:useAbility('dash', nil, {
                    direction = lookVector,
                    origin = origin,
                    weapon = heldItem.Name
                })
                
                pcall(function()
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
                end)
                
                pcall(function()
                    local hrp = character.HumanoidRootPart
                    local mass = hrp.AssemblyMass or 5
                    hrp:ApplyImpulse(lookVector.Unit * Vector3.new(1, 0, 1) * mass * ImpulseSlider.Value)
                    character.Humanoid.JumpHeight = JumpHeightSlider.Value
                    character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
                
                task.delay(0.5, function()
                    if character and character.Humanoid then
                        pcall(function()
                            character.Humanoid.JumpHeight = originalJumpHeight
                            
                            if bedwars.JumpHeightController then
                                bedwars.JumpHeightController:setJumpHeight(game:GetService("StarterPlayer").CharacterJumpHeight)
                            end
                        end)
                    end
                end)
            end
            
            local delayTime = DashDelay.Enabled and DelaySlider.Value or 0.5
            task.wait(delayTime)
            canDash = true
        end)
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
    
    local function ToggleKeybind()
        if KeybindMode.Value == 'Toggle' then
            KeybindHeld = not KeybindHeld
            KeybindActive = KeybindHeld
            
            if KeybindActive then
                PerformDash()
            end
        end
    end
    
    YuziDasher = vape.Categories.Blatant:CreateModule({
        Name = 'YuziDasher',
        Function = function(callback)
            if callback then
                if KeybindEnabled then
                    YuziDasher:Clean(inputService.InputBegan:Connect(function(input)
                        if UseMouseBind then
                            if input.UserInputType == CurrentMouseBind then
                                if KeybindMode.Value == 'Hold' then
                                    PerformDash()
                                elseif KeybindMode.Value == 'Toggle' then
                                    ToggleKeybind()
                                end
                            end
                        else
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                if input.KeyCode == CurrentKeybind then
                                    if KeybindMode.Value == 'Hold' then
                                        PerformDash()
                                    elseif KeybindMode.Value == 'Toggle' then
                                        ToggleKeybind()
                                    end
                                end
                            end
                        end
                    end))
                    
                    YuziDasher:Clean(inputService.InputEnded:Connect(function(input)
                        if KeybindMode.Value == 'Hold' then
                            if UseMouseBind then
                                if input.UserInputType == CurrentMouseBind then
                                end
                            else
                                if input.UserInputType == Enum.UserInputType.Keyboard then
                                    if input.KeyCode == CurrentKeybind then
                                    end
                                end
                            end
                        end
                    end))
                    
                    if KeybindMode.Value == 'Hold' then
                        YuziDasher:Clean(runService.Heartbeat:Connect(function()
                            UpdateKeybindState()
                            if KeybindActive then
                                PerformDash()
                            end
                        end))
                    end
                else
                    YuziDasher:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
                        if gameProcessed then
                            return
                        end
                        
                        if not (input.UserInputType == input.KeyCode == Enum.KeyCode.Q) then
                            return
                        end
                        
                        PerformDash()
                    end))
                end
            else
                canDash = true
                KeybindHeld = false
                KeybindActive = false
            end
        end,
        Tooltip = 'Customizable keybind Yuzi Dasher'
    })
    
    KeybindToggle = YuziDasher:CreateToggle({
        Name = 'Use Keybind',
        Default = false,
        Tooltip = 'Use a custom keybind instead of Q/Right Click',
        Function = function(callback)
            KeybindEnabled = callback
            if KeybindList.Object then
                KeybindList.Object.Visible = callback and not UseMouseBind
            end
            if MouseBindToggle.Object then
                MouseBindToggle.Object.Visible = callback
            end
            if MouseBindList.Object then
                MouseBindList.Object.Visible = callback and UseMouseBind
            end
            if KeybindMode.Object then
                KeybindMode.Object.Visible = callback
            end
            
            if YuziDasher.Enabled then
                YuziDasher:Toggle()
                task.wait()
                YuziDasher:Toggle()
            end
        end
    })
    
    KeybindMode = YuziDasher:CreateDropdown({
        Name = 'Keybind Mode',
        List = {'Hold', 'Toggle'},
        Default = 'Hold',
        Darker = true,
        Visible = false,
        Tooltip = 'Hold: Activate while holding key\nToggle: Press to turn on/off',
        Function = function(value)
            KeybindHeld = false
            KeybindActive = false
            if YuziDasher.Enabled and KeybindEnabled then
                YuziDasher:Toggle()
                task.wait(0.1)
                YuziDasher:Toggle()
            end
        end
    })
    
    local keybindOptions = {
        "Q", "E", "R", "F", "G", "X", "Z", "V", "B",
        "LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift",
        "Space", "CapsLock", "Tab"
    }
    
    KeybindList = YuziDasher:CreateDropdown({
        Name = 'Keybind',
        List = keybindOptions,
        Default = "Q",
        Darker = true,
        Visible = false,
        Function = function(value)
            CurrentKeybind = Enum.KeyCode[value]
            KeybindHeld = false
            KeybindActive = false
            if YuziDasher.Enabled and KeybindEnabled then
                YuziDasher:Toggle()
                task.wait(0.1)
                YuziDasher:Toggle()
            end
        end
    })
    
    MouseBindToggle = YuziDasher:CreateToggle({
        Name = 'Use Mouse Button',
        Default = false,
        Tooltip = 'Use a mouse button instead of keyboard key',
        Function = function(callback)
            UseMouseBind = callback
            if KeybindList.Object then
                KeybindList.Object.Visible = KeybindEnabled and not callback
            end
            if MouseBindList.Object then
                MouseBindList.Object.Visible = KeybindEnabled and callback
            end
            
            KeybindHeld = false
            KeybindActive = false
            
            if YuziDasher.Enabled and KeybindEnabled then
                YuziDasher:Toggle()
                task.wait(0.1)
                YuziDasher:Toggle()
            end
        end
    })
    
    local mouseBindOptions = {
        "Right Click",
        "Middle Click"
    }
    
    local mouseBindEnumMap = {
        ["Right Click"] = Enum.UserInputType.MouseButton2,
        ["Middle Click"] = Enum.UserInputType.MouseButton3
    }
    
    MouseBindList = YuziDasher:CreateDropdown({
        Name = 'Mouse Button',
        List = mouseBindOptions,
        Default = "Right Click",
        Darker = true,
        Visible = false,
        Tooltip = 'Select which mouse button to use',
        Function = function(value)
            CurrentMouseBind = mouseBindEnumMap[value]
            KeybindHeld = false
            KeybindActive = false
            if YuziDasher.Enabled and KeybindEnabled then
                YuziDasher:Toggle()
                task.wait(0.1)
                YuziDasher:Toggle()
            end
        end
    })
    KeybindList.Object.Visible = false
    MouseBindToggle.Object.Visible = false
    MouseBindList.Object.Visible = false
    KeybindMode.Object.Visible = false

    DashDelay = YuziDasher:CreateToggle({
        Name = 'Dash Delay',
        Default = false,
        Tooltip = 'Custom delay between dashes',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = YuziDasher:CreateSlider({
        Name = 'Delay (s)',
        Min = 0.1,
        Max = 2,
        Default = 0.5,
        Darker = true,
        Visible = false,
        Tooltip = 'Delay between dashes in seconds'
    })

    ImpulseSlider = YuziDasher:CreateSlider({
        Name = 'Impulse Multiplier',
        Min = 10,
        Max = 500,
        Default = 100,
        Tooltip = 'controls dash speed'
    })

    JumpHeightSlider = YuziDasher:CreateSlider({
        Name = 'Jump Height',
        Min = 0,
        Max = 50,
        Default = 10,
        Tooltip = 'Controls jump height during dash'
    })
    
    task.spawn(function()
        repeat
            task.wait()
        until YuziDasher.Object and YuziDasher.Object.Parent
        
        task.wait(0.05)
        
        if DashDelay.Enabled and DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = true
        elseif DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false
        end
    end)
end)

run(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")		
	local FishermanESP
	local originalCreateElement = nil
	local moduleEnabled = false
	local notificationQueue = {}
	
	local fishNames = {
		fish_iron = "iron fish",
		fish_diamond = "diamond fish",
		fish_gold = "gold fish",
		fish_special = "special fish",
		fish_emerald = "emerald fish"
	}
	
	local function processNotificationQueue()
		while #notificationQueue > 0 do
			local fishType = table.remove(notificationQueue, 1)
			local fishName = fishNames[fishType] or fishType
			notif('FishermanESP', 'This fish is a ' .. fishName, 3)
		end
	end

	task.spawn(function()
		while true do
			processNotificationQueue()
			task.wait(0.1)
		end
	end)
	
	FishermanESP = vape.Categories.Utility:CreateModule({
		Name = 'FishermanESP',
		Function = function(callback)
			if callback then
				moduleEnabled = true
				task.spawn(function()
					wait(1)
					local success = pcall(function()
						local Roact = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src"))
						
						if originalCreateElement == nil then
							originalCreateElement = Roact.createElement
						end
						
						Roact.createElement = function(component, props, ...)
							local result = originalCreateElement(component, props, ...)
							
							if moduleEnabled and props and props.fishType then
								local fishType = props.fishType
								if props.decaySpeedMultiplier then
									table.insert(notificationQueue, fishType)
								end
							end
							
							return result
						end
					end)
					
					if success then
					else
						notif('FishermanESP', 'failed to hook try rejoining', 5)
						FishermanESP:Toggle()
					end
				end)
			else
				moduleEnabled = false
				if originalCreateElement then
					pcall(function()
						local Roact = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src"))
						Roact.createElement = originalCreateElement
						originalCreateElement = nil
					end)
				end
				notificationQueue = {}
			end
		end,
		Tooltip = 'Shows what fish you are catching'
	})
end)

run(function()
	local TextureRemover
	local connections = {}
	local originalTextures = {}
	
	local function removeTextures(obj)
		if obj.Name == "Nametag" and obj.Parent and obj.Parent.Parent == lplr.Character then
			return
		end
		
		if obj:IsA("BasePart") then
			if not originalTextures[obj] then
				originalTextures[obj] = {
					Material = obj.Material,
					TextureID = obj:IsA("MeshPart") and obj.TextureID or nil
				}
			end
			
			obj.Material = Enum.Material.SmoothPlastic
			if obj:IsA("MeshPart") then
				obj.TextureID = ""
			end
			
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			if not originalTextures[obj] then
				originalTextures[obj] = {
					Texture = obj.Texture,
					Transparency = obj.Transparency
				}
			end
			obj.Transparency = 1
			
		elseif obj:IsA("SurfaceAppearance") then
			if not originalTextures[obj] then
				originalTextures[obj] = {
					ColorMap = obj.ColorMap,
					NormalMap = obj.NormalMap,
					RoughnessMap = obj.RoughnessMap,
					MetalnessMap = obj.MetalnessMap
				}
			end
			obj.ColorMap = ""
			obj.NormalMap = ""
			obj.RoughnessMap = ""
			obj.MetalnessMap = ""
		end
	end
	
	local function processWorkspace()
		for _, obj in pairs(workspace:GetDescendants()) do
			removeTextures(obj)
		end
	end
	
	TextureRemover = vape.Categories.BoostFPS:CreateModule({
		Name = 'Texture Remover',
		Function = function(callback)
			if callback then
				processWorkspace()
				
				local conn = workspace.DescendantAdded:Connect(function(obj)
					if TextureRemover.Enabled then
						removeTextures(obj)
					end
				end)
				table.insert(connections, conn)
				
			else
				for obj, props in pairs(originalTextures) do
					if obj and obj.Parent then
						pcall(function()
							for prop, val in pairs(props) do
								if val ~= nil then
									obj[prop] = val
								end
							end
						end)
					end
				end
				
				for _, conn in pairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalTextures)
			end
		end,
		Tooltip = 'Removes all textures and makes blocks white for FPS boost'
	})
end)

run(function()
	local ParticleRemover
	local connections = {}
	local originalParticles = {}
	
	local function removeParticle(obj)
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
			if not originalParticles[obj] then
				originalParticles[obj] = obj.Enabled
			end
			obj.Enabled = false
		elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			if not originalParticles[obj] then
				originalParticles[obj] = obj.Enabled
			end
			obj.Enabled = false
		end
	end
	
	ParticleRemover = vape.Categories.BoostFPS:CreateModule({
		Name = 'Particle Remover',
		Function = function(callback)
			if callback then
				for _, obj in pairs(workspace:GetDescendants()) do
					removeParticle(obj)
				end
				
				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ParticleRemover.Enabled then
						removeParticle(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, enabled in pairs(originalParticles) do
					if obj and obj.Parent then
						pcall(function()
							obj.Enabled = enabled
						end)
					end
				end
				
				for _, conn in pairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalParticles)
			end
		end,
		Tooltip = 'Removes all particle effects for FPS boost'
	})
end)

run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	
	local function removeShadow(obj)
		if obj:IsA("BasePart") then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
		end
	end
	
	ShadowRemover = vape.Categories.BoostFPS:CreateModule({
		Name = 'Shadow Remover',
		Function = function(callback)
			if callback then
				for _, obj in pairs(workspace:GetDescendants()) do
					removeShadow(obj)
				end
				
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
				
				for _, conn in pairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
			end
		end,
		Tooltip = 'Removes shadows from all parts for FPS boost'
	})
end)

run(function()
	local ArmorRemover
	local connections = {}
	local hiddenArmor = {}
	
	local function hideArmor(character)
		if not character or character == lplr.Character then return end
		
		for _, obj in pairs(character:GetDescendants()) do
			if obj:IsA("Accessory") then
				if not hiddenArmor[obj] then
					hiddenArmor[obj] = {
						Parent = obj.Parent,
						Character = character
					}
				end
				obj.Parent = nil
			end
		end
	end
	
	ArmorRemover = vape.Categories.BoostFPS:CreateModule({
		Name = 'Armor Remover',
		Function = function(callback)
			if callback then
				for _, player in pairs(game.Players:GetPlayers()) do
					if player ~= lplr and player.Character then
						hideArmor(player.Character)
					end
				end
				
				local conn1 = game.Players.PlayerAdded:Connect(function(player)
					if player == lplr then return end
					player.CharacterAdded:Connect(function(char)
						if ArmorRemover.Enabled then
							task.wait(0.5)
							hideArmor(char)
						end
					end)
				end)
				table.insert(connections, conn1)
				
				for _, player in pairs(game.Players:GetPlayers()) do
					if player == lplr then continue end
					local conn2 = player.CharacterAdded:Connect(function(char)
						if ArmorRemover.Enabled then
							task.wait(0.5)
							hideArmor(char)
						end
					end)
					table.insert(connections, conn2)
				end
				
				local conn3 = workspace.DescendantAdded:Connect(function(obj)
					if ArmorRemover.Enabled and obj:IsA("Accessory") then
						task.wait(0.1)
						local char = obj.Parent
						if char and char ~= lplr.Character and char:FindFirstChild("Humanoid") then
							hiddenArmor[obj] = {
								Parent = obj.Parent,
								Character = char
							}
							obj.Parent = nil
						end
					end
				end)
				table.insert(connections, conn3)
			else
				for obj, data in pairs(hiddenArmor) do
					if obj then
						pcall(function()
							if data.Parent and data.Parent.Parent then
								obj.Parent = data.Parent
							elseif data.Character and data.Character.Parent then
								obj.Parent = data.Character
							end
						end)
					end
				end
				
				for _, conn in pairs(connections) do
					pcall(function()
						conn:Disconnect()
					end)
				end
				table.clear(connections)
				table.clear(hiddenArmor)
			end
		end,
		Tooltip = 'Hides armor visuals for FPS boost (armor still works)'
	})
end)

run(function()
	local PotatoMode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local blockColors = {
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["glass"] = Color3.fromRGB(200, 220, 240),
		["planks"] = Color3.fromRGB(200, 170, 120),
		["end_stone"] = Color3.fromRGB(240, 230, 180),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["wool"] = Color3.fromRGB(200, 200, 200),
	}
	
	local function getBlockColor(blockName)
		if blockColors[blockName] then
			return blockColors[blockName]
		end
		
		if string.find(blockName:lower(), "wool") then
			local colorPart = blockName:match("wool_(.+)")
			if colorPart and blockColors["wool_" .. colorPart] then
				return blockColors["wool_" .. colorPart]
			end
			return blockColors["wool"] or Color3.fromRGB(200, 200, 200)
		end
		
		for name, color in pairs(blockColors) do
			if string.find(blockName:lower(), name:lower()) then
				return color
			end
		end
		
		return Color3.fromRGB(150, 150, 150)
	end
	
	local function simplifyBlock(block)
		if not block or not block.Parent then return end
		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}
			
			for _, child in ipairs(block:GetChildren()) do
				if child:IsA("Texture") or child:IsA("Decal") then
					originalProperties[block].Textures[#originalProperties[block].Textures + 1] = {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child.StudsPerTileU,
						StudsPerTileV = child.StudsPerTileV,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					}
				end
			end
		end
		
		pcall(function()
			block.Material = Enum.Material.SmoothPlastic
			
			local blockColor = getBlockColor(block.Name)
			block.Color = blockColor
			
			for _, child in ipairs(block:GetChildren()) do
				if child:IsA("Texture") or child:IsA("Decal") then
					child:Destroy()
				end
			end
			
			if block:IsA("MeshPart") and block.TextureID ~= "" then
				block.TextureID = ""
			end
		end)
	end
	
	local function restoreBlock(block)
		if not block or not block.Parent then return end
		
		local props = originalProperties[block]
		if not props then return end
		
		pcall(function()
			block.Material = props.Material or Enum.Material.Plastic
			block.Color = props.Color or Color3.fromRGB(255, 255, 255)
			
			if props.TextureID and block:IsA("MeshPart") then
				block.TextureID = props.TextureID
			end
			
			for _, textureProps in ipairs(props.Textures) do
				local newTexture
				if textureProps.Class == "Texture" then
					newTexture = Instance.new("Texture")
					newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
					newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
				else
					newTexture = Instance.new("Decal")
					newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
				end
				
				newTexture.Texture = textureProps.Texture or ""
				newTexture.Face = textureProps.Face or Enum.NormalId.Front
				newTexture.Transparency = textureProps.Transparency or 0
				newTexture.Parent = block
			end
		end)
		
		originalProperties[block] = nil
	end
	
	local function processExistingBlocks(simplify)
		local blocksToProcess = {}
		for _, obj in pairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and (obj.Name:find("wool") or obj.Name:find("clay") or 
			   obj.Name:find("wood") or obj.Name:find("stone") or obj.Name:find("glass") or
			   obj.Name:find("plank") or obj.Name:find("bed") or obj.Name:find("obsidian") or
			   obj.Name:find("sand") or obj.Name:find("end") or obj.Name:find("tnt") or
			   obj.Name:find("barrier") or obj.Name:find("magic") or obj.Name:find("concrete") or
			   obj.Name:find("_block") or obj:IsA("Seat")) then
				
				table.insert(blocksToProcess, obj)
			end
		end
		
		task.spawn(function()
			for i, block in ipairs(blocksToProcess) do
				if block and block.Parent then
					if simplify then
						simplifyBlock(block)
					else
						restoreBlock(block)
					end
				end
				if i % 5 == 0 then 
					task.wait(0.01)
				end
			end
		end)
	end
	
	local function setupBlockMonitor(simplify)
		for _, conn in pairs(blockMonitorConnections) do
			if conn then
				conn:Disconnect()
			end
		end
		table.clear(blockMonitorConnections)
		
		if not simplify then return end
		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") and (descendant.Name:find("wool") or descendant.Name:find("clay") or 
			   descendant.Name:find("wood") or descendant.Name:find("stone") or descendant.Name:find("glass") or
			   descendant.Name:find("plank") or descendant.Name:find("bed") or descendant.Name:find("obsidian") or
			   descendant.Name:find("sand") or descendant.Name:find("end") or descendant.Name:find("tnt") or
			   descendant.Name:find("barrier") or descendant.Name:find("magic") or descendant.Name:find("concrete") or
			   descendant.Name:find("_block") or descendant:IsA("Seat")) then
				task.wait(0.05)
				simplifyBlock(descendant)
			end
		end)
		
		table.insert(blockMonitorConnections, mainConn)
	end
	
	PotatoMode = vape.Categories.BoostFPS:CreateModule({
		Name = 'Potato Mode',
		Function = function(callback)
			if callback then
				processExistingBlocks(true)
				setupBlockMonitor(true)
				
			else
				processExistingBlocks(false)
				for _, conn in pairs(blockMonitorConnections) do
					if conn then
						conn:Disconnect()
					end
				end
				table.clear(blockMonitorConnections)
			end
		end,
		Tooltip = 'Removes block textures but keeps colors (like old FFlag) - No lighting changes'
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
	local DamageHighlight
	local ColorPicker
	local FillTransparency
	local OutlineTransparency
	local hookedHighlights = {}
	
	DamageHighlight = vape.Categories.Legit:CreateModule({
		Name = "DamageHighlight",
		Function = function(callback)
			if callback then
				repeat
					for i, v in entitylib.List do 
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight and not hookedHighlights[highlight] then
							local color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
							highlight.FillColor = color
							highlight.OutlineColor = color
							highlight.FillTransparency = FillTransparency.Value
							highlight.OutlineTransparency = OutlineTransparency.Value
							
							highlight:GetPropertyChangedSignal("FillColor"):Connect(function()
								if DamageHighlight.Enabled then
									local customColor = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
									highlight.FillColor = customColor
								end
							end)
							
							highlight:GetPropertyChangedSignal("OutlineColor"):Connect(function()
								if DamageHighlight.Enabled then
									local customColor = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
									highlight.OutlineColor = customColor
								end
							end)
							
							highlight:GetPropertyChangedSignal("FillTransparency"):Connect(function()
								if DamageHighlight.Enabled then
									highlight.FillTransparency = FillTransparency.Value
								end
							end)
							
							highlight:GetPropertyChangedSignal("OutlineTransparency"):Connect(function()
								if DamageHighlight.Enabled then
									highlight.OutlineTransparency = OutlineTransparency.Value
								end
							end)
							
							hookedHighlights[highlight] = true
						elseif highlight and hookedHighlights[highlight] then
							local color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
							highlight.FillColor = color
							highlight.OutlineColor = color
							highlight.FillTransparency = FillTransparency.Value
							highlight.OutlineTransparency = OutlineTransparency.Value
						end
					end
					task.wait(0.1)
				until not DamageHighlight.Enabled
			else
				table.clear(hookedHighlights)
			end
		end,
		Tooltip = 'Customize damage highlight colors and transparency'
	})
	
	ColorPicker = DamageHighlight:CreateColorSlider({
		Name = 'Highlight Color',
		DefaultValue = 0,
		DefaultOpacity = 1,
		Tooltip = 'Color for damage highlights',
		Function = function()
			if DamageHighlight.Enabled then
				for i, v in entitylib.List do 
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight then
						local color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
						highlight.FillColor = color
						highlight.OutlineColor = color
					end
				end
			end
		end
	})
	
	FillTransparency = DamageHighlight:CreateSlider({
		Name = 'Fill Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimal = 100,
		Tooltip = 'Transparency of the fill (0 = solid, 1 = invisible)',
		Function = function()
			if DamageHighlight.Enabled then
				for i, v in entitylib.List do 
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight then
						highlight.FillTransparency = FillTransparency.Value
					end
				end
			end
		end
	})
	
	OutlineTransparency = DamageHighlight:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Tooltip = 'Transparency of the outline (0 = solid, 1 = invisible)',
		Function = function()
			if DamageHighlight.Enabled then
				for i, v in entitylib.List do 
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight then
						highlight.OutlineTransparency = OutlineTransparency.Value
					end
				end
			end
		end
	})
end)

run(function()
    local AutoLani
    local PlayerDropdown
    local DelaySlider
    local AutoBuyToggle
    local GUICheck
    local DelayBuySlider
    local LimitItems
    local running = false
    local buyRunning = false
    
    local function getTeammateList()
        local teammates = {}
        local myTeam = lplr:GetAttribute('Team')
        
        if not myTeam then return {} end
        
        for _, player in playersService:GetPlayers() do
            if player ~= lplr then
                local playerTeam = player:GetAttribute('Team')
                if playerTeam and playerTeam == myTeam then
                    table.insert(teammates, player.Name)
                end
            end
        end
        
        table.sort(teammates)
        return teammates
    end
    
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
    
    local function getScepterTool()
        if not entitylib.isAlive then return nil end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == "scepter" then
                return handItem.tool
            end
        end
        return nil
    end
    
    local function consumeScepter()
        local scepterTool = getScepterTool()
        if scepterTool then
            pcall(function()
                local args = {
                    {
                        item = scepterTool
                    }
                }
                game:GetService("ReplicatedStorage")
                    :WaitForChild("rbxts_include")
                    :WaitForChild("node_modules")
                    :WaitForChild("@rbxts")
                    :WaitForChild("net")
                    :WaitForChild("out")
                    :WaitForChild("_NetManaged")
                    :WaitForChild("ConsumeItem")
                    :InvokeServer(unpack(args))
            end)
        end
    end
    
    local function getShopNPC()
        local shopFound = false
        if entitylib.isAlive then
            local localPosition = entitylib.character.RootPart.Position
            for _, v in store.shop do
                if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                    shopFound = true
                    break
                end
            end
        end
        return shopFound
    end
    
    local function buyScepter()
        pcall(function()
            local args = {
                {
                    shopItem = {
                        currency = "iron",
                        itemType = "scepter",
                        amount = 1,
                        price = 45,
                        category = "Combat",
                        requiresKit = {
                            "paladin"
                        },
                        lockAfterPurchase = true
                    },
                    shopId = "1_item_shop"
                }
            }
            game:GetService("ReplicatedStorage")
                :WaitForChild("rbxts_include")
                :WaitForChild("node_modules")
                :WaitForChild("@rbxts")
                :WaitForChild("net")
                :WaitForChild("out")
                :WaitForChild("_NetManaged")
                :WaitForChild("BedwarsPurchaseItem")
                :InvokeServer(unpack(args))
        end)
    end
    
    AutoLani = vape.Categories.Kits:CreateModule({
        Name = "Auto Lani",
        Function = function(callback)
            running = callback
            buyRunning = callback
            
            if callback then
                task.spawn(function()
                    AutoLani:Clean(lplr:GetAttributeChangedSignal("PaladinStartTime"):Connect(function()
                        if not running then return end
                        
                        if LimitItems.Enabled then
                            if not isHoldingScepter() then
                                return
                            end
                        end
                        consumeScepter()
                        local delay = DelaySlider.GetRandomValue()
                        task.wait(delay)
                        if bedwars.AbilityController:canUseAbility('PALADIN_ABILITY') then
                            local targetPlayer = playersService:FindFirstChild(PlayerDropdown.Value)
                            
                            if targetPlayer and targetPlayer.Character then
                                bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({target = targetPlayer})
                            else
                                bedwars.Client:Get("PaladinAbilityRequest"):SendToServer({})
                            end
                            
                            task.wait(0.022)
                            bedwars.AbilityController:useAbility('PALADIN_ABILITY')
                        end
                    end))
                end)
                
                if AutoBuyToggle.Enabled then
                    task.spawn(function()
                        while buyRunning and AutoBuyToggle.Enabled do
                            local canBuy = true
                            
                            if GUICheck.Enabled then
                                if bedwars.AppController:isAppOpen('BedwarsItemShopApp') then
                                    canBuy = true
                                else
                                    canBuy = false
                                end
                            else
                                canBuy = getShopNPC()
                            end
                            
                            if canBuy then
                                buyScepter()
                            end
                            
                            task.wait(1 / DelayBuySlider.GetRandomValue())
                        end
                    end)
                end
                
                AutoLani:Clean(playersService.PlayerAdded:Connect(function()
                    task.wait(0.5)
                    PlayerDropdown:SetList(getTeammateList())
                end))
                
                AutoLani:Clean(playersService.PlayerRemoving:Connect(function()
                    task.wait(0.5)
                    PlayerDropdown:SetList(getTeammateList())
                end))
                
                AutoLani:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(0.5)
                    PlayerDropdown:SetList(getTeammateList())
                end))
                
            else
                running = false
                buyRunning = false
            end
        end,
        Tooltip = "Automatically teleports to selected teammate using Paladin ability"
    })
    
    PlayerDropdown = AutoLani:CreateDropdown({
        Name = "Teammate",
        List = getTeammateList(),
        Function = function(val)
        end,
        Tooltip = "Select teammate to teleport to"
    })
    
    DelaySlider = AutoLani:CreateTwoSlider({
        Name = "Teleport Delay",
        Min = 0,
        Max = 2,
        DefaultMin = 0.4,
        DefaultMax = 1.33,
        Decimal = 10,
        Suffix = "s",
        Tooltip = "Delay before teleporting to teammate"
    })
    
    LimitItems = AutoLani:CreateToggle({
        Name = "Limit to Scepter",
        Default = true,
        Function = function(val)
        end,
        Tooltip = "Only teleport when holding scepter"
    })
    
    AutoBuyToggle = AutoLani:CreateToggle({
        Name = "Auto Buy Scepter",
        Default = false,
        Function = function(val)
            if GUICheck then
                GUICheck.Object.Visible = val
            end
            if DelayBuySlider then
                DelayBuySlider.Object.Visible = val
            end
            
            if AutoLani.Enabled then
                if val then
                    buyRunning = true
                    task.spawn(function()
                        while buyRunning and AutoBuyToggle.Enabled do
                            local canBuy = true
                            
                            if GUICheck.Enabled then
                                if bedwars.AppController:isAppOpen('BedwarsItemShopApp') then
                                    canBuy = true
                                else
                                    canBuy = false
                                end
                            else
                                canBuy = getShopNPC()
                            end
                            
                            if canBuy then
                                buyScepter()
                            end
                            
                            task.wait(1 / DelayBuySlider.GetRandomValue())
                        end
                    end)
                else
                    buyRunning = false
                end
            end
        end,
        Tooltip = "Automatically buys scepter when near shop"
    })
    
    GUICheck = AutoLani:CreateToggle({
        Name = "GUI Check",
        Default = false,
        Function = function(val)
        end,
        Tooltip = "Only buy when shop GUI is open",
        Visible = false
    })
    
    DelayBuySlider = AutoLani:CreateTwoSlider({
        Name = "Buy Delay",
        Min = 0.1,
        Max = 2,
        DefaultMin = 0.1,
        DefaultMax = 0.4,
        Decimal = 10,
        Suffix = "s",
        Tooltip = "Delay between purchase attempts",
        Visible = false
    })
end)

run(function()
	local AutoPearl
	local LegitSwitch
	local LimitItems

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function isHoldingPearl()
		if not entitylib.isAlive then return false end
		
		local inventory = store.inventory
		if inventory and inventory.inventory and inventory.inventory.hand then
			local handItem = inventory.inventory.hand
			if handItem and handItem.itemType == "telepearl" then
				return true
			end
		end
		return false
	end
	
	local function firePearl(pos, spot, item)
		if LimitItems.Enabled then
			if not isHoldingPearl() then
				return
			end
		else
			if LegitSwitch.Enabled then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.tool == item.tool and i ~= (store.inventory.hotbarSlot + 1) then 
						hotbarSwitch(i - 1)
						task.wait(0.1)
						break
					end
				end
			else
				switchItem(item.tool)
			end
		end
		
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0, nil, false, lplr:GetNetworkPing())

		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
		end
	
		if not LimitItems.Enabled then
			if store.hand then
				switchItem(store.hand.tool)
			end
		end
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'Auto Pearl',
		Function = function(callback)
			if callback then
				local check
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if pearl and root.Velocity.Y < -80 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = getNearGround(20)
	
								if ground then
									getgenv().CancelSwitch = os.clock() + 0.3
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
	})

	LegitSwitch = AutoPearl:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Uses hotbar switching instead of instant switch'
	})
	
	LimitItems = AutoPearl:CreateToggle({
		Name = 'Limit to Pearl',
		Default = false,
		Tooltip = 'Only throw pearl when already holding it (no switching)'
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
	
	local CollectionService = game:GetService("CollectionService")
	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local old
	local summonThread = nil
	local currentAffinity = nil
	
	local priorityOrders = {
		['Emerald > Diamond > Iron'] = {'emerald', 'diamond', 'iron'},
		['Diamond > Emerald > Iron'] = {'diamond', 'emerald', 'iron'},
		['Iron > Diamond > Emerald'] = {'iron', 'diamond', 'emerald'}
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
	
	local function getClosestLoot(originPos)
		local closest, closestDist = nil, math.huge
		local priorityOrder = priorityOrders[PriorityDropdown.Value] or priorityOrders['Emerald > Diamond > Iron']
		
		for _, itemType in priorityOrder do
			for _, drop in CollectionService:GetTagged('ItemDrop') do
				if not drop:FindFirstChild('Handle') then continue end
				
				local itemName = drop.Name:lower()
				if itemName:find(itemType) then
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
		
		for _, plr in game:GetService('Players'):GetPlayers() do
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
					local attackSpirits = lplr:GetAttribute('ReadySummonedAttackSpirits') or 0
					local healSpirits = lplr:GetAttribute('ReadySummonedHealSpirits') or 0
					local totalSpirits = attackSpirits + healSpirits
					
					if totalSpirits < 10 then
						local hasStone = false
						for _, item in store.inventory.inventory.items do
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
				
				task.wait(0.2)
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
		Name = 'AutoUMA',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
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
					bedwars.ProjectileController.calculateImportantLaunchValues = old
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
		Tooltip = 'Lock onto loot (iron/diamond/emerald) with priority system'
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
		Tooltip = 'Heal teammates below 40 HP (switches to attack above 50 HP)'
	})
	
	Range = AutoUMA:CreateSlider({
		Name = 'Lock Range',
		Min = 10,
		Max = 70,
		Default = 70,
		Tooltip = 'Maximum distance to lock onto targets'
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
end)

run(function()
    local Caitlyn
    local ContractVisuals
    local FillTransparency
    local OutlineTransparency
    local ColorPicker
    local AutoKitToggle
    local MethodDropdown
    local LowHealthSlider
    local ExecuteRangeSlider
    local HitRangeSlider
    local ProximityRangeSlider
    local connections = {}
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lplr = Players.LocalPlayer
    local currentTarget = nil
    local lastHitTime = 0
    local lastContractSelect = 0
    local activeHighlight = nil
    local originalHighlightSettings = {}
    
    local function findActiveContractTarget()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                for _, obj in pairs(player.Character:GetDescendants()) do
                    if obj:IsA("Highlight") and obj.Name ~= "VapeHighlight" and obj.Name ~= "_DamageHighlight_" then
                        return player, player.Character, obj
                    end
                end
            end
        end
        return nil, nil, nil
    end
    
    local function enhanceHighlight()
        if not ContractVisuals.Enabled then return end
        
        local targetPlayer, targetChar, highlight = findActiveContractTarget()
        
        if highlight then
            if not originalHighlightSettings[highlight] then
                originalHighlightSettings[highlight] = {
                    FillColor = highlight.FillColor,
                    FillTransparency = highlight.FillTransparency,
                    OutlineColor = highlight.OutlineColor,
                    OutlineTransparency = highlight.OutlineTransparency,
                    DepthMode = highlight.DepthMode
                }
            end
            
            activeHighlight = highlight
            
            highlight.FillTransparency = FillTransparency.Value
            highlight.OutlineTransparency = OutlineTransparency.Value
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            local color = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Value)
            highlight.FillColor = color
            highlight.OutlineColor = color
        else
            activeHighlight = nil
        end
    end
    
    local function restoreHighlight()
        for highlight, settings in pairs(originalHighlightSettings) do
            if highlight and highlight.Parent then
                highlight.FillColor = settings.FillColor
                highlight.FillTransparency = settings.FillTransparency
                highlight.OutlineColor = settings.OutlineColor
                highlight.OutlineTransparency = settings.OutlineTransparency
                highlight.DepthMode = settings.DepthMode
            end
        end
        table.clear(originalHighlightSettings)
    end
    
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
                bedwars.Client:Get("BloodAssassinSelectContract"):SendToServer({
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
        Name = 'Caitlyn Kit',
        Function = function(callback)
            if callback then
                if ContractVisuals.Enabled then
                    local updateConn = RunService.RenderStepped:Connect(function()
                        if not Caitlyn.Enabled or not ContractVisuals.Enabled then return end
                        enhanceHighlight()
                    end)
                    table.insert(connections, updateConn)
                end
                
                if AutoKitToggle.Enabled then
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
                            if AutoKitToggle.Enabled and entitylib.isAlive then
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
                        until not Caitlyn.Enabled or not AutoKitToggle.Enabled
                    end)
                end
            else
                for _, conn in pairs(connections) do
                    if typeof(conn) == "RBXScriptConnection" then
                        conn:Disconnect()
                    end
                end
                table.clear(connections)
                
                restoreHighlight()
                currentTarget = nil
                activeHighlight = nil
                lastHitTime = 0
            end
        end,
        Tooltip = 'Contract visuals and auto kit caitlyn'
    })
    
    ContractVisuals = Caitlyn:CreateToggle({
        Name = 'Contract Visuals',
        Default = false,
        Tooltip = 'Makes contract target more visible',
        Function = function(callback)
            if FillTransparency and FillTransparency.Object then
                FillTransparency.Object.Visible = callback
            end
            if OutlineTransparency and OutlineTransparency.Object then
                OutlineTransparency.Object.Visible = callback
            end
            if ColorPicker and ColorPicker.Object then
                ColorPicker.Object.Visible = callback
            end
            
            if not callback then
                restoreHighlight()
            end
        end
    })
    
    FillTransparency = Caitlyn:CreateSlider({
        Name = 'Fill Transparency',
        Min = 0,
        Max = 1,
        Default = 0.3,
        Decimal = 100,
        Visible = false,
        Tooltip = 'Lower = more cool fill'
    })
    
    OutlineTransparency = Caitlyn:CreateSlider({
        Name = 'Outline Transparency',
        Min = 0,
        Max = 1,
        Default = 0,
        Decimal = 100,
        Visible = false,
        Tooltip = 'Lower = more cool outline'
    })
    
    ColorPicker = Caitlyn:CreateColorSlider({
        Name = 'Contract Highlight Color',
        DefaultValue = 0,
        DefaultOpacity = 1,
        Visible = false,
        Tooltip = 'Custom contract highlight color'
    })
    
    AutoKitToggle = Caitlyn:CreateToggle({
        Name = 'Auto Contract',
        Default = false,
        Tooltip = 'Automatically select contracts based on method',
        Function = function(callback)
            if MethodDropdown and MethodDropdown.Object then
                MethodDropdown.Object.Visible = callback
            end
            
            if callback then
                local method = MethodDropdown.Value
                if LowHealthSlider and LowHealthSlider.Object then
                    LowHealthSlider.Object.Visible = (method == "Execute on Low HP")
                end
                if ExecuteRangeSlider and ExecuteRangeSlider.Object then
                    ExecuteRangeSlider.Object.Visible = (method == "Execute on Low HP")
                end
                if HitRangeSlider and HitRangeSlider.Object then
                    HitRangeSlider.Object.Visible = (method == "Contract on Hit")
                end
                if ProximityRangeSlider and ProximityRangeSlider.Object then
                    ProximityRangeSlider.Object.Visible = (method == "Proximity Select")
                end
            else
                if LowHealthSlider and LowHealthSlider.Object then LowHealthSlider.Object.Visible = false end
                if ExecuteRangeSlider and ExecuteRangeSlider.Object then ExecuteRangeSlider.Object.Visible = false end
                if HitRangeSlider and HitRangeSlider.Object then HitRangeSlider.Object.Visible = false end
                if ProximityRangeSlider and ProximityRangeSlider.Object then ProximityRangeSlider.Object.Visible = false end
            end
        end
    })
    
    MethodDropdown = Caitlyn:CreateDropdown({
        Name = 'Method',
        List = {"Execute on Low HP", "Contract on Hit", "Proximity Select"},
        Default = "Execute on Low HP",
        Visible = false,
        Tooltip = 'Contract selection method',
        Function = function(value)
            if not AutoKitToggle.Enabled then return end
            
            if LowHealthSlider and LowHealthSlider.Object then
                LowHealthSlider.Object.Visible = (value == "Execute on Low HP")
            end
            if ExecuteRangeSlider and ExecuteRangeSlider.Object then
                ExecuteRangeSlider.Object.Visible = (value == "Execute on Low HP")
            end
            if HitRangeSlider and HitRangeSlider.Object then
                HitRangeSlider.Object.Visible = (value == "Contract on Hit")
            end
            if ProximityRangeSlider and ProximityRangeSlider.Object then
                ProximityRangeSlider.Object.Visible = (value == "Proximity Select")
            end
        end
    })
    
    LowHealthSlider = Caitlyn:CreateSlider({
        Name = 'Select HP',
        Min = 10,
        Max = 100,
        Default = 30,
        Visible = false,
        Tooltip = 'HP value to execute contract'
    })
    
    ExecuteRangeSlider = Caitlyn:CreateSlider({
        Name = 'Select Range',
        Min = 5,
        Max = 50,
        Default = 20,
        Suffix = ' studs',
        Visible = false,
        Tooltip = 'Range to select contract'
    })
    
    HitRangeSlider = Caitlyn:CreateSlider({
        Name = 'Hit Range',
        Min = 10,
        Max = 200,
        Default = 100,
        Suffix = ' studs',
        Visible = false,
        Tooltip = 'Max range to select a contract when hitting the player'
    })
    
    ProximityRangeSlider = Caitlyn:CreateSlider({
        Name = 'Proximity Range',
        Min = 10,
        Max = 200,
        Default = 50,
        Suffix = ' studs',
        Visible = false,
        Tooltip = 'Range to auto select nearby players (ran out of ideas...)'
    })
end)

run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	
	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				obj.Material = Enum.Material.Plastic
				obj.Reflectance = 0
			end
		end
	end
	local function restoreNeon()
		for obj, data in originalMaterials do
			if obj and obj.Parent then
				obj.Material = data.Material
				obj.Reflectance = data.Reflectance
			end
		end
		table.clear(originalMaterials)
	end
	
	RemoveNeon = vape.Categories.BoostFPS:CreateModule({
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				for _, v in workspace:GetDescendants() do
					removeNeonFromPart(v)
				end
				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					task.wait()
					removeNeonFromPart(obj)
				end)
				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						for _, v in workspace:GetDescendants() do
							removeNeonFromPart(v)
						end
						task.wait(1)
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
	local FakePos
	
	FakePos = vape.Categories.Blatant:CreateModule({
		Name = "FakePos",
		Tooltip = 'Desyncs your position from the server (Fake Position)',
		Function = function(callback)
			if callback then
				setfflag('NextGenReplicatorEnabledWrite4', 'true')
				if store.fakePosEnabled == nil then
					store.fakePosEnabled = true
				end
			else
				setfflag('NextGenReplicatorEnabledWrite4', 'false')
				if store.fakePosEnabled ~= nil then
					store.fakePosEnabled = false
				end
			end
		end
	})
	
	setfflag('NextGenReplicatorEnabledWrite4', 'false')
end)

run(function()
	local RemoveEffects
	
	RemoveEffects = vape.Categories.BoostFPS:CreateModule({
		Name = "RemoveEffects",
		Function = function(callback)
			if callback then
				if not store.originalVignette then
					store.originalVignette = bedwars.VignetteController.createVignette
				end
				
				if not store.originalDebuffEffect then
					store.originalDebuffEffect = bedwars.DebuffEffectController and bedwars.DebuffEffectController.createEffect
				end
				
				if not store.originalStatusEffect then
					store.originalStatusEffect = bedwars.StatusEffectController and bedwars.StatusEffectController.createEffect
				end
				
				bedwars.VignetteController.createVignette = function(...)
					return nil
				end
				
				if bedwars.DebuffEffectController then
					bedwars.DebuffEffectController.createEffect = function(...)
						return nil
					end
				end
				
				if bedwars.StatusEffectController then
					bedwars.StatusEffectController.createEffect = function(...)
						return nil
					end
				end
				
				if bedwars.VignetteController.currentVignette then
					bedwars.VignetteController.currentVignette:Destroy()
					bedwars.VignetteController.currentVignette = nil
				end
				
				local screenGui = lplr:FindFirstChild("PlayerGui")
				if screenGui then
					for _, gui in pairs(screenGui:GetChildren()) do
						if gui:IsA("ScreenGui") and (gui.Name:find("Vignette") or gui.Name:find("Effect") or gui.Name:find("Debuff")) then
							gui:Destroy()
						end
					end
				end
				
			else
				if store.originalVignette then
					bedwars.VignetteController.createVignette = store.originalVignette
					store.originalVignette = nil
				end
				
				if store.originalDebuffEffect and bedwars.DebuffEffectController then
					bedwars.DebuffEffectController.createEffect = store.originalDebuffEffect
					store.originalDebuffEffect = nil
				end
				
				if store.originalStatusEffect and bedwars.StatusEffectController then
					bedwars.StatusEffectController.createEffect = store.originalStatusEffect
					store.originalStatusEffect = nil
				end
			end
		end,
		Tooltip = 'Removes annoying screen effects (static, glooped effects, etc.)'
	})
end)

run(function()
	local ShopTaxDisabler
	local oldDispatch
	local oldtax
	local oldadded
	local olditems
	local oldRemoteConnection
	
	ShopTaxDisabler = vape.Categories.Blatant:CreateModule({
		Name = "ShopTaxDisabler",
		Function = function(callback)
			if callback then
				oldtax = bedwars.ShopTaxController.isTaxed
				oldadded = bedwars.ShopTaxController.getAddedTax
				olditems = bedwars.ShopTaxController.getTaxedItems
				oldDispatch = bedwars.Store.dispatch
				
				bedwars.Store.dispatch = function(...)
					local arg = select(2, ...)
					if arg and typeof(arg) == 'table' and arg.type == 'IncrementTaxState' then
						return nil
					end
					return oldDispatch(...)
				end
				
				bedwars.ShopTaxController.isTaxed = function(...)
					return false
				end
				
				bedwars.ShopTaxController.getTaxedItems = function(...)
					return {}
				end
				
				bedwars.ShopTaxController.getAddedTax = function(...)
					return 0
				end
				
				if bedwars.ShopTaxController.taxStateUpdateEvent then
					oldRemoteConnection = bedwars.ShopTaxController.taxStateUpdateEvent.Connect
					bedwars.ShopTaxController.taxStateUpdateEvent.Connect = function() 
						return {Disconnect = function() end}
					end
				end
				
				bedwars.ShopTaxController.hasTax = false
				bedwars.ShopTaxController.taxedItems = {}
				bedwars.ShopTaxController.addedTaxMap = {}
			else
				if oldDispatch then
					bedwars.Store.dispatch = oldDispatch
				end
				if oldtax then
					bedwars.ShopTaxController.isTaxed = oldtax
				end
				if oldadded then
					bedwars.ShopTaxController.getAddedTax = oldadded
				end
				if olditems then
					bedwars.ShopTaxController.getTaxedItems = olditems
				end
				if oldRemoteConnection then
					bedwars.ShopTaxController.taxStateUpdateEvent.Connect = oldRemoteConnection
				end
				
				oldDispatch = nil
				oldtax = nil
				oldadded = nil
				olditems = nil
				oldRemoteConnection = nil
			end
		end,
		Tooltip = 'Disables shop tax bypass (in beta!!)'
	})
end)

run(function()
	local MiloExploit
	local Blocks
	local old
	MiloExploit = vape.Categories.Utility:CreateModule({
		Name = "MiloExploit",
		Function = function(callback)
			if not callback then
				return
			end

			MiloExploit:Toggle(false)
			old = bedwars.MimicController.onAbilityUsed
			bedwars.MimicController.onAbilityUsed = function(s1,s2)
				if not entitylib.isAlive then
					return nil
				end
				task.spawn(function()
					local v88 = {
						["data"] = {
							["blockType"] = Blocks.Value or 'wool_red'
						}
					}
					bedwars.Client:Get("MimicBlock"):SendToServer(v88)
				end)
			end
			if bedwars.AbilityController:canUseAbility("MIMIC_BLOCK") then
				bedwars.AbilityController:useAbility('MIMIC_BLOCK')
				task.wait(2)
				bedwars.MimicController.onAbilityUsed = old
				old = nil
			end
		end,
		Tooltip = 'Allows you to mimic any block you want without the block being there',
	})
	Blocks = MiloExploit:CreateTextBox({
		Name = "Blocks",
		Tooltip = 'Only use meta names (ex. wool_blue wool_red (like its customs))',
		Default = 'obsidian'
	})
end)

run(function()
	local Lobby
	Lobby = vape.Categories.Utility:CreateModule({
		Name = 'Lobby',
		Function = function(callback)
			if not callback then
				return
			end
			Lobby:Toggle(false)
			local s,err = pcall(function()
				bedwars.Client:Get("TeleportToLobby"):SendToServer()
			end)
			if not s then
				warn(err)
				task.wait(8)
				lobby()
			end
		end
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
    local ShowLootToggle
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local lplr = Players.LocalPlayer
    
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    
    local fishNames = {
        fish_iron = "Iron Fish",
        fish_diamond = "Diamond Fish",
        fish_gold = "Gold Fish",
        fish_special = "Special Fish",
        fish_emerald = "Emerald Fish"
    }
    
    local originalCreateElement = nil
    local moduleEnabled = false
    local notificationQueue = {}
    local autoMinigameActive = false
    local pullAnimationTrack = nil
    local successAnimationTrack = nil
    local playerBobberTracking = {}
    local fishingPlayers = {}
    
    local function processNotificationQueue()
        while #notificationQueue > 0 do
            local fishType = table.remove(notificationQueue, 1)
            local fishName = fishNames[fishType] or fishType
            notif('Fisherman ESP', 'Catching a ' .. fishName, 3)
        end
    end
    
    task.spawn(function()
        while true do
            processNotificationQueue()
            task.wait(0.1)
        end
    end)
    
    local function setupAutoMinigame()
        local old = bedwars.FishingMinigameController.startMinigame
        bedwars.FishingMinigameController.startMinigame = function(_, dropData, result)
            if not AutoMinigameToggle.Enabled then
                return old(_, dropData, result)
            end
            
            autoMinigameActive = true
            
            if PullAnimationToggle.Enabled and CompleteDelaySlider.Value > 0 then
                pullAnimationTrack = bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.FISHING_ROD_PULLING)
            end
            
            if CompleteDelaySlider.Value > 0 then
                task.wait(CompleteDelaySlider.Value)
            end
            
            if pullAnimationTrack then
                pullAnimationTrack:Stop()
                pullAnimationTrack = nil
            end
            
            if MinigameAnimationToggle.Enabled then
                successAnimationTrack = bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.FISHING_ROD_CATCH_SUCCESS)
            end
            
            result({win = true})
            
            task.wait(0.5)
            if successAnimationTrack then
                successAnimationTrack:Stop()
                successAnimationTrack = nil
            end
            
            autoMinigameActive = false
        end
        
        Fisherman:Clean(function()
            bedwars.FishingMinigameController.startMinigame = old
            if pullAnimationTrack then
                pullAnimationTrack:Stop()
                pullAnimationTrack = nil
            end
            if successAnimationTrack then
                successAnimationTrack:Stop()
                successAnimationTrack = nil
            end
        end)
    end
    
    local function setupESP()
        task.spawn(function()
            wait(1)
            local success = pcall(function()
                local Roact = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src"))
                
                if originalCreateElement == nil then
                    originalCreateElement = Roact.createElement
                end
                
                Roact.createElement = function(component, props, ...)
                    local result = originalCreateElement(component, props, ...)
                    
                    if moduleEnabled and props and props.fishType then
                        local fishType = props.fishType
                        if props.decaySpeedMultiplier then
                            table.insert(notificationQueue, fishType)
                        end
                    end
                    
                    return result
                end
            end)
            
            if not success then
                notif('Fisherman ESP', 'Failed to hook, try rejoining', 5)
                if ESPToggle then ESPToggle:Toggle() end
            end
        end)
    end
    
    local function setupFishermanSpy()
        local bobberAddedConnection = workspace.DescendantAdded:Connect(function(descendant)
            if not FishermanSpyToggle.Enabled then return end
            if descendant.Name ~= "fisherman_bobber" then return end
            
            task.wait(0.1) 
            
            local shooterId = descendant:GetAttribute("ProjectileShooter")
            if not shooterId or shooterId == lplr.UserId then return end
            
            local player = Players:GetPlayerByUserId(shooterId)
            if not player then return end
            
            if IgnoreTeammatesToggle.Enabled and player.Team == lplr.Team then
                return
            end
            
            notif('Fisherman Spy', player.Name .. ' is fishing!', 3)
            
            playerBobberTracking[descendant] = {
                player = player,
                userId = shooterId,
                addedTime = tick()
            }
            fishingPlayers[shooterId] = true
        end)
        
        local bobberRemovedConnection = workspace.DescendantRemoving:Connect(function(descendant)
            if not FishermanSpyToggle.Enabled then return end
            if descendant.Name ~= "fisherman_bobber" then return end
            
            local trackingData = playerBobberTracking[descendant]
            if not trackingData then return end
            
            trackingData.removedTime = tick()
        end)
        
        local fishDetectorConnection = workspace.DescendantAdded:Connect(function(descendant)
            if not FishermanSpyToggle.Enabled then return end
            
            local itemName = descendant.Name
            
            if not fishNames[itemName] then return end
            
            local mostRecentPlayer = nil
            local mostRecentTime = 0
            
            for bobber, data in pairs(playerBobberTracking) do
                if data.removedTime and data.removedTime > mostRecentTime then
                    if tick() - data.removedTime < 2 then
                        mostRecentTime = data.removedTime
                        mostRecentPlayer = data.player
                    end
                end
            end
            
            if mostRecentPlayer then
                local fishType = fishNames[itemName]
                
                local message = mostRecentPlayer.Name .. ' caught a ' .. fishType
                if ShowLootToggle.Enabled then
                    message = message .. ' (' .. itemName .. ')'
                end
                
                notif('Fisherman Spy', message, 5)
                
                for bobber, data in pairs(playerBobberTracking) do
                    if data.player == mostRecentPlayer then
                        playerBobberTracking[bobber] = nil
                    end
                end
                fishingPlayers[mostRecentPlayer.UserId] = nil
            end
        end)
        
        local cleanupTask = task.spawn(function()
            while Fisherman.Enabled and FishermanSpyToggle.Enabled do
                task.wait(5)
                
                local currentTime = tick()
                for bobber, data in pairs(playerBobberTracking) do
                    if data.addedTime and currentTime - data.addedTime > 5 then
                        playerBobberTracking[bobber] = nil
                        if data.userId then
                            fishingPlayers[data.userId] = nil
                        end
                    end
                end
            end
        end)
        
        Fisherman:Clean(bobberAddedConnection)
        Fisherman:Clean(bobberRemovedConnection)
        Fisherman:Clean(fishDetectorConnection)
        Fisherman:Clean(function()
            task.cancel(cleanupTask)
        end)
    end
    
    Fisherman = vape.Categories.Kits:CreateModule({
        Name = 'Fisherman Kit',
        Function = function(callback)
            if callback then
                if AutoMinigameToggle.Enabled then
                    setupAutoMinigame()
                end
                
                if ESPToggle.Enabled then
                    moduleEnabled = true
                    setupESP()
                end
                
                if FishermanSpyToggle.Enabled then
                    setupFishermanSpy()
                end
            else
                moduleEnabled = false
                autoMinigameActive = false
                
                if pullAnimationTrack then
                    pullAnimationTrack:Stop()
                    pullAnimationTrack = nil
                end
                if successAnimationTrack then
                    successAnimationTrack:Stop()
                    successAnimationTrack = nil
                end
                
                if originalCreateElement then
                    pcall(function()
                        local Roact = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src"))
                        Roact.createElement = originalCreateElement
                        originalCreateElement = nil
                    end)
                end
                
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(notificationQueue)
                table.clear(playerBobberTracking)
                table.clear(fishingPlayers)
            end
        end,
        Tooltip = 'All-in-one Fisherman module'
    })
    
    AutoMinigameToggle = Fisherman:CreateToggle({
        Name = 'Auto Minigame',
        Default = false,
        Tooltip = 'Automatically complete fishing minigame',
        Function = function(callback)
            if CompleteDelaySlider and CompleteDelaySlider.Object then 
                CompleteDelaySlider.Object.Visible = callback 
            end
            if PullAnimationToggle and PullAnimationToggle.Object then 
                PullAnimationToggle.Object.Visible = callback 
            end
            if MinigameAnimationToggle and MinigameAnimationToggle.Object then 
                MinigameAnimationToggle.Object.Visible = callback 
            end
            
            if Fisherman.Enabled and callback then
                setupAutoMinigame()
            end
        end
    })
    
    CompleteDelaySlider = Fisherman:CreateSlider({
        Name = 'Complete Delay',
        Min = 0,
        Max = 5,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false,
        Tooltip = 'Delay before completing minigame'
    })
    
    PullAnimationToggle = Fisherman:CreateToggle({
        Name = 'Pull Animation',
        Default = true,
        Visible = false,
        Tooltip = 'Play pulling animation during delay (only if delay > 0)'
    })
    
    MinigameAnimationToggle = Fisherman:CreateToggle({
        Name = 'Finished Animation',
        Default = true,
        Visible = false,
        Tooltip = 'Play success animation on complete'
    })
    
    FishermanSpyToggle = Fisherman:CreateToggle({
        Name = 'Fisherman Spy',
        Default = false,
        Tooltip = 'See what other players catch',
        Function = function(callback)
            if IgnoreTeammatesToggle and IgnoreTeammatesToggle.Object then 
                IgnoreTeammatesToggle.Object.Visible = callback 
            end
            if ShowLootToggle and ShowLootToggle.Object then 
                ShowLootToggle.Object.Visible = callback 
            end
            
            if Fisherman.Enabled and callback then
                setupFishermanSpy()
            end
        end
    })
    
    IgnoreTeammatesToggle = Fisherman:CreateToggle({
        Name = 'Ignore Teammates',
        Default = true,
        Visible = false,
        Tooltip = 'Only notifes 4 enemy'
    })
    
    ESPToggle = Fisherman:CreateToggle({
        Name = 'Fish ESP',
        Default = false,
        Tooltip = 'Shows what fish you are catching',
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            
            if Fisherman.Enabled then
                moduleEnabled = callback
                if callback then
                    setupESP()
                else
                    if originalCreateElement then
                        pcall(function()
                            local Roact = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src"))
                            Roact.createElement = originalCreateElement
                            originalCreateElement = nil
                        end)
                    end
                    notificationQueue = {}
                end
            end
        end
    })
    
    ESPNotify = Fisherman:CreateToggle({
        Name = 'Notify Fish Type',
        Default = true,
        Visible = false,
        Tooltip = 'Get notifications of fish type'
    })
    
    ESPBackground = Fisherman:CreateToggle({
        Name = 'Background',
        Default = true,
        Visible = false,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
        end
    })
    
    ESPColor = Fisherman:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Visible = false,
        Darker = true
    })
end)

run(function()
    local RamilKit
    local AutoTornado
    local AutoMovingTornado
    local RangeSlider
    local MovingRangeSlider
    local AngleSlider
    local MaxTargets
    local Targets
    local UpdateRate
    local Animation
    local SortMethod
    
    local function isRamilKit()
        return store.equippedKit == 'airbender'
    end
    
    local function canUseAbility(abilityName)
        return bedwars.AbilityController:canUseAbility(abilityName)
    end
    
    local function useAbility(abilityName)
        bedwars.AbilityController:useAbility(abilityName)
    end
    
    RamilKit = vape.Categories.Kits:CreateModule({
        Name = 'Ramil Kit',
        Function = function(callback)
            if callback then
                if not isRamilKit() then
                    vape:CreateNotification('Auto Ramil', 'Airbender kit required!', 5, 'warning')
                    RamilKit:Toggle()
                    return
                end
                task.spawn(function()
                    repeat
                        if not entitylib.isAlive then 
                            task.wait(0.1) 
                            continue 
                        end
                        local plrs = entitylib.AllPosition({
                            Range = RangeSlider.Value,
                            Wallcheck = Targets.Walls.Enabled,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Limit = MaxTargets.Value,
                            Sort = sortmethods[SortMethod.Value]
                        })
                        local char = entitylib.character
                        local root = char.RootPart
                        if AutoTornado.Enabled and plrs and plrs[1] and plrs[1].RootPart then
                            local ent = plrs[1]
                            local delta = ent.RootPart.Position - root.Position
                            local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                            local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                            
                            if angle <= (math.rad(AngleSlider.Value) / 2) then
                                if canUseAbility('airbender_tornado') then
                                    if Animation.Enabled then
                                        bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.AIRBENDER_CAST)
                                    end
                                    useAbility('airbender_tornado')
                                end
                            end
                        end
                        if AutoMovingTornado.Enabled then
                            local movingPlrs = entitylib.AllPosition({
                                Range = MovingRangeSlider.Value,
                                Wallcheck = Targets.Walls.Enabled,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Limit = MaxTargets.Value,
                                Sort = sortmethods[SortMethod.Value]
                            })
                            
                            if movingPlrs and movingPlrs[1] and movingPlrs[1].RootPart then
                                local ent = movingPlrs[1]
                                local delta = ent.RootPart.Position - root.Position
                                local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                                local angle = math.acos(localFacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                
                                if angle <= (math.rad(AngleSlider.Value) / 2) then
                                    if canUseAbility('airbender_moving_tornado') then
                                        if Animation.Enabled then
                                            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.AIRBENDER_CHARGING)
                                        end
                                        useAbility('airbender_moving_tornado')
                                    end
                                end
                            end
                        end
                        
                        task.wait(1 / UpdateRate.Value)
                    until not RamilKit.Enabled
                end)
            end
        end,
        Tooltip = 'Automatically uses Ramil tornadoes on enemies'
    })
    
    AutoTornado = RamilKit:CreateToggle({
        Name = 'Auto Tornado',
        Default = true,
        Tooltip = 'Automatically use stationary tornado',
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then 
                RangeSlider.Object.Visible = callback 
            end
        end
    })
    
    RangeSlider = RamilKit:CreateSlider({
        Name = 'Tornado Range',
        Min = 1,
        Max = 30,
        Default = 18,
        Visible = true,
        Suffix = function(v)
            return v == 1 and ' stud' or ' studs'
        end,
        Tooltip = 'Range for stationary tornado'
    })
    
    AutoMovingTornado = RamilKit:CreateToggle({
        Name = 'Auto Moving Tornado',
        Default = false,
        Tooltip = 'Automatically use moving tornado',
        Function = function(callback)
            if MovingRangeSlider and MovingRangeSlider.Object then
                MovingRangeSlider.Object.Visible = callback
            end
        end
    })
    
    MovingRangeSlider = RamilKit:CreateSlider({
        Name = 'Moving Range',
        Min = 1,
        Max = 35,
        Default = 20,
        Visible = false,
        Darker = true,
        Suffix = function(v)
            return v == 1 and ' stud' or ' studs'
        end,
        Tooltip = 'Range for moving tornado'
    })
    
    AngleSlider = RamilKit:CreateSlider({
        Name = 'FOV Angle',
        Min = 0,
        Max = 360,
        Default = 180,
        Suffix = '°',
        Tooltip = 'Field of view angle for targeting'
    })
    
    MaxTargets = RamilKit:CreateSlider({
        Name = 'Max Targets',
        Min = 1,
        Max = 5,
        Default = 2,
        Tooltip = 'Maximum number of targets to check'
    })
    
    SortMethod = RamilKit:CreateDropdown({
        Name = 'Sort Method',
        List = {'Distance', 'Health', 'Threat', 'Damage', 'Kit', 'Angle'},
        Default = 'Distance',
        Tooltip = 'How to prioritize targets'
    })
    
    UpdateRate = RamilKit:CreateSlider({
        Name = 'Update Rate',
        Min = 1,
        Max = 60,
        Default = 20,
        Suffix = ' hz',
        Tooltip = 'How often to check for targets'
    })
    
    Targets = RamilKit:CreateTargets({
        Players = true,
        NPCs = false,
        Walls = true
    })
end)

run(function()
	local InstantBattery
	
	InstantBattery = vape.Categories.Kits:CreateModule({
		Name = 'InstantBattery',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for i, v in bedwars.BatteryEffectsController.liveBatteries do
							if (v.position - localPosition).Magnitude <= 10 then
								local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
								if BatteryInfo and BatteryInfo.activateTime <= workspace:GetServerTimeNow() then
									bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
								end
							end
						end
					end
					task.wait() 
				until not InstantBattery.Enabled
			end
		end,
		Tooltip = 'Instantly consumes batteries with no delay or cooldown(0.75 was cooldown btw 0 better then anything)'
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
    
    local function getTeammateList()
        local teammates = {}
        local myTeam = lplr:GetAttribute('Team')
        
        if not myTeam then return {} end
        
        for _, player in playersService:GetPlayers() do
            if player ~= lplr then
                local playerTeam = player:GetAttribute('Team')
                if playerTeam and playerTeam == myTeam then
                    table.insert(teammates, player.Name)
                end
            end
        end
        
        table.sort(teammates)
        return teammates
    end
    
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
    
    local function demountOwl()
        pcall(function()
            game:GetService("ReplicatedStorage")
                :WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
                :WaitForChild("useAbility")
                :FireServer("DEACTIVE_OWL")
            
            task.wait(0.05)
            
            game:GetService("ReplicatedStorage")
                :WaitForChild("rbxts_include")
                :WaitForChild("node_modules")
                :WaitForChild("@rbxts")
                :WaitForChild("net")
                :WaitForChild("out")
                :WaitForChild("_NetManaged")
                :WaitForChild("RemoveOwl")
                :FireServer()
        end)
        
        currentMountedPlayer = nil
    end
    
    local function mountBirdToPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return false end
        
        if LimitToItem.Enabled and not isHoldingOwlOrb() then
            return false
        end
        
        local success = false
        pcall(function()
            local result = game:GetService("ReplicatedStorage")
                :WaitForChild("rbxts_include")
                :WaitForChild("node_modules")
                :WaitForChild("@rbxts")
                :WaitForChild("net")
                :WaitForChild("out")
                :WaitForChild("_NetManaged")
                :WaitForChild("SummonOwl")
                :InvokeServer(targetPlayer)
            
            if result then
                task.wait(0.05)
                
                game:GetService("ReplicatedStorage")
                    :WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
                    :WaitForChild("useAbility")
                    :FireServer("SUMMON_OWL")
                
                currentMountedPlayer = targetPlayer
                success = true
            end
        end)
        
        return success
    end
    
    local function getTargetHealth(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return 0, 100 end
        
        local health = 0
        local maxHealth = 100
        
        pcall(function()
            local character = targetPlayer.Character
            health = character:GetAttribute("Health") or (character:FindFirstChildOfClass("Humanoid") and character.Humanoid.Health) or 0
            maxHealth = character:GetAttribute("MaxHealth") or (character:FindFirstChildOfClass("Humanoid") and character.Humanoid.MaxHealth) or 100
        end)
        
        return health, maxHealth
    end
    
    local function healTarget()
        if not currentTarget then return end
        
        pcall(function()
            bedwars.Client:Get("OwlActionAbilities"):SendToServer({
                target = currentTarget,
                ability = "owl_heal"
            })
            task.wait(0.022)
            
            game:GetService("ReplicatedStorage")
                :WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
                :WaitForChild("useAbility")
                :FireServer("OWL_HEAL")
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
            bedwars.Client:Get("OwlActionAbilities"):SendToServer({
                target = currentTarget,
                ability = "owl_lift"
            })
            task.wait(0.022)
            
            game:GetService("ReplicatedStorage")
                :WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
                :WaitForChild("useAbility")
                :FireServer("OWL_LIFT")
            
            hasActivatedFly = true
            task.spawn(function()
                task.wait(85)
                hasActivatedFly = false
            end)
        end)
    end
    
    AutoWhisper = vape.Categories.Kits:CreateModule({
        Name = "Auto Whisper",
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
                                local health, maxHealth = getTargetHealth(currentTarget)
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
                    local newList = getTeammateList()
                    if PlayerDropdown then
                        PlayerDropdown:SetList(newList)
                    end
                end))
                
                AutoWhisper:Clean(playersService.PlayerRemoving:Connect(function(player)
                    task.wait(0.5)
                    local newList = getTeammateList()
                    if PlayerDropdown then
                        PlayerDropdown:SetList(newList)
                    end
                    
                    if currentTarget == player then
                        currentTarget = nil
                        currentMountedPlayer = nil
                    end
                end))
                
                AutoWhisper:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function()
                    task.wait(0.5)
                    local newList = getTeammateList()
                    if PlayerDropdown then
                        PlayerDropdown:SetList(newList)
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
        List = getTeammateList(),
        Function = function(val)
            local targetPlayer = playersService:FindFirstChild(val)
            if targetPlayer then
                currentTarget = targetPlayer
            end
        end,
        Tooltip = "Select teammate to mount owl to"
    })
    
    RefreshButton = AutoWhisper:CreateButton({
        Name = "Refresh Teammates",
        Function = function()
            task.spawn(function()
                local newList = getTeammateList()
                
                if PlayerDropdown and PlayerDropdown.SetList then
                    pcall(function()
                        PlayerDropdown:SetList(newList)
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
    
    AutoHeal = AutoWhisper:CreateToggle({
        Name = "Auto Heal",
        Default = true,
        Function = function(val)
            if AutoHealSlider then
                AutoHealSlider.Object.Visible = val
            end
            
            if AutoWhisper.Enabled then
                if val then
                    healRunning = true
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget and currentMountedPlayer == currentTarget then
                                local health, maxHealth = getTargetHealth(currentTarget)
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
    end

    local function collectOrb(orb)
        if not orb or not orb.Parent then return false end
        
        local treeOrbSecret = orb:GetAttribute('TreeOrbSecret')
        if not treeOrbSecret then return false end
        
        if Animation.Enabled and entitylib.isAlive then
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
            bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
            bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
        end
        
        bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({
            treeOrbSecret = treeOrbSecret
        })
        
        orb:Destroy()
        return true
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
        Name = 'Eldertree',
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
        Max = 30,
        Default = 12,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'control distance you want to collect orbs'
    })
    
    ESPToggle = Eldertree:CreateToggle({
        Name = 'Orb ESP',
        Default = false,
        Tooltip = 'shows tree orb locations',
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            
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
end)

run(function()
    local StarCollector
    local CollectionToggle
    local Animation
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
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
    end

    local function collectStar(star)
        if not star or not star.Parent then return false end
        
        if Animation.Enabled and entitylib.isAlive then
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
            bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
            bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
        end
        
        bedwars.StarCollectorController:collectEntity(lplr, star, star.Name)
        
        return true
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
                local starsFound = false
                
                for _, v in collectionService:GetTagged('stars') do
                    if not collectionRunning or not StarCollector.Enabled or not CollectionToggle.Enabled then 
                        break 
                    end
                    
                    if v:IsA("Model") and v.PrimaryPart then
                        local starPos = v.PrimaryPart.Position
                        local distance = (localPosition - starPos).Magnitude
                        
                        if distance <= range then
                            starsFound = true
                            
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if collectStar(v) then
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if not starsFound then
                    task.wait(0.2)
                else
                    task.wait(0.1)
                end
            end
            collectionRunning = false
        end)
    end

    StarCollector = vape.Categories.Kits:CreateModule({
        Name = 'Star Collector',
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
        Tooltip = 'automatically collects stars and esp'
    })
    
    CollectionToggle = StarCollector:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'automatically collect stars',
        Function = function(callback)
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
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
    
    CollectionDelay = StarCollector:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'add delay before collecting stars',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = StarCollector:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'delay in seconds before collecting'
    })
    
    RangeSlider = StarCollector:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 30,
        Default = 20,
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
        Name = 'Melody',
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
    local Warden
    local CollectionToggle
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local AngleSlider
    local collectionRunning = false
    local soulsCache = {}

    local function collectSoul(soul)
        if not soul or not soul.Parent then return false end
        
        bedwars.JailorController:collectEntity(lplr, soul, 'JailorSoul')
        
        return true
    end

    local function getFOVAngle(soulPosition)
        if not entitylib.isAlive then return 360 end
        
        local character = entitylib.character
        if not character or not character.RootPart then return 360 end
        
        local camera = gameCamera
        local cameraCFrame = camera.CFrame
        local cameraLookVector = cameraCFrame.LookVector * Vector3.new(1, 0, 1)
        local directionToSoul = (soulPosition - cameraCFrame.Position) * Vector3.new(1, 0, 1)
        
        if directionToSoul.Magnitude == 0 then return 0 end
        
        local angle = math.deg(math.acos(cameraLookVector:Dot(directionToSoul.Unit)))
        return angle
    end

    local function startCollection()
        collectionRunning = true
        task.spawn(function()
            while collectionRunning and Warden.Enabled and CollectionToggle.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local maxAngle = AngleSlider.Value
                local soulsFound = false
                
                for soulId, _ in pairs(soulsCache) do
                    local soul = workspace:FindFirstChild(soulId)
                    if not soul then
                        soulsCache[soulId] = nil
                    end
                end
                
                for _, v in collectionService:GetTagged('jailor_soul') do
                    if not collectionRunning or not Warden.Enabled or not CollectionToggle.Enabled then 
                        break 
                    end
                    
                    if v:IsA("Model") and v.PrimaryPart then
                        local soulPos = v.PrimaryPart.Position
                        local distance = (localPosition - soulPos).Magnitude
                        
                        local angle = getFOVAngle(soulPos)
                        
                        if distance <= range and angle <= maxAngle then
                            soulsFound = true
                            soulsCache[v.Name] = true
                            
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if collectSoul(v) then
                                task.wait(0.1)
                            end
                        else
                            soulsCache[v.Name] = nil
                        end
                    end
                end
                
                if not soulsFound then
                    task.wait(0.2)
                else
                    task.wait(0.1)
                end
            end
            collectionRunning = false
        end)
    end

    Warden = vape.Categories.Kits:CreateModule({
        Name = 'Warden',
        Function = function(callback)
            if callback then
                if CollectionToggle.Enabled then
                    startCollection()
                end
            else
                collectionRunning = false
                table.clear(soulsCache)
            end
        end,
        Tooltip = 'Automatically collects jailor souls with FOV control'
    })
    
    CollectionToggle = Warden:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'Automatically collect souls',
        Function = function(callback)
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if AngleSlider and AngleSlider.Object then AngleSlider.Object.Visible = callback end
            
            if callback and Warden.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    CollectionDelay = Warden:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'Add delay before collecting souls',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Warden:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before collecting'
    })
    
    RangeSlider = Warden:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 30,
        Default = 20,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Control distance you want to collect souls'
    })
    
    AngleSlider = Warden:CreateSlider({
        Name = 'FOV Angle',
        Min = 1,
        Max = 360,
        Default = 180,
        Suffix = '°',
        Tooltip = 'FOV (self explanatory)'
    })
end)

run(function()
    local Zeno
    local Targets
    local TargetPriority
    local HealthMode
    local ArmorMode
    
    local LightningStrike
    local LightningStorm
    local AutoShockwave
    local ShockwaveRange
    local AbilityRange
    local AbilityDelay
    
    local abilityRunning = false
    local lastAbilityUse = 0
    local lastShockwaveUse = 0
    local damageTracker = {}
    
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}
    
    local armors = {
        'none',
        'leather_chestplate',
        'iron_chestplate',
        'diamond_chestplate',
        'emerald_chestplate'
    }
    
    local function getArmorTier(player)
        if not player or not store.inventories[player] then return 0 end
        local inventory = store.inventories[player]
        local chestplate = inventory.armor and inventory.armor[5]
        if not chestplate or chestplate == 'empty' then return 1 end
        return table.find(armors, chestplate.itemType) or 1
    end
    
    local function trackDamage(entity, damage)
        local key = entity.Player and entity.Player.UserId or tostring(entity)
        if not damageTracker[key] then
            damageTracker[key] = 0
        end
        damageTracker[key] = damageTracker[key] + (damage or 1)
    end
    
    local function getMostDamagedEntity()
        local highestDamage = 0
        local targetKey = nil
        
        for key, damage in pairs(damageTracker) do
            if damage > highestDamage then
                highestDamage = damage
                targetKey = key
            end
        end
        
        if not targetKey then return nil end
        
        for _, ent in entitylib.List do
            local key = ent.Player and ent.Player.UserId or tostring(ent)
            if key == targetKey and ent.RootPart then
                return ent
            end
        end
        
        return nil
    end
    
    local function getTargetByPriority(originPos, range)
        if TargetPriority.Value == 'Damaged' then
            local target = getMostDamagedEntity()
            if target and target.RootPart then
                local distance = (target.RootPart.Position - originPos).Magnitude
                if distance <= range then
                    return target
                end
            end
        end
        
        local validTargets = {}
        
        for _, ent in entitylib.List do
            if not Targets.Players.Enabled and ent.Player then continue end
            if not Targets.NPCs.Enabled and ent.NPC then continue end
            if not ent.Character or not ent.RootPart then continue end
            
            local distance = (ent.RootPart.Position - originPos).Magnitude
            if distance > range then continue end
            
            if Targets.Walls.Enabled then
                local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), rayCheck)
                if ray then continue end
            end
            
            table.insert(validTargets, ent)
        end
        
        if #validTargets == 0 then return nil end
        
        if TargetPriority.Value == 'Health' then
            table.sort(validTargets, function(a, b)
                local healthA = (a.Character:GetAttribute("Health") or a.Humanoid.Health)
                local healthB = (b.Character:GetAttribute("Health") or b.Humanoid.Health)
                
                if HealthMode.Value == 'Lowest' then
                    return healthA < healthB
                else
                    return healthA > healthB
                end
            end)
        elseif TargetPriority.Value == 'Armor' then
            table.sort(validTargets, function(a, b)
                local armorA = a.Player and getArmorTier(a.Player) or 1
                local armorB = b.Player and getArmorTier(b.Player) or 1
                
                if ArmorMode.Value == 'Weakest' then
                    return armorA < armorB
                else
                    return armorA > armorB
                end
            end)
        else
            table.sort(validTargets, function(a, b)
                local distA = (a.RootPart.Position - originPos).Magnitude
                local distB = (b.RootPart.Position - originPos).Magnitude
                return distA < distB
            end)
        end
        
        return validTargets[1]
    end
    
    local function useAbility(abilityType, targetPos)
        local success = pcall(function()
            local remote = game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility")
            remote:FireServer(abilityType, {
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
        
        local currentTime = tick()
        if (currentTime - lastShockwaveUse) < 1 then
            return false
        end
        
        local originPos = entitylib.character.RootPart.Position
        local shockRange = ShockwaveRange.Value
        
        local nearbyEnemies = 0
        for _, ent in entitylib.List do
            if ent.RootPart then
                if (Targets.Players.Enabled and ent.Player and ent.Player ~= lplr) or 
                   (Targets.NPCs.Enabled and ent.NPC) then
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
    
    local function switchToAbility(targetAbility)
        local currentAbility = lplr:GetAttribute('WizardAbility')
        if currentAbility == targetAbility then
            return true
        end
        
        lplr:SetAttribute('WizardAbility', targetAbility)
        task.wait(0.1)
        return true
    end
    
    local function performLightningAbility()
        if not entitylib.isAlive then return false end
        
        local originPos = entitylib.character.RootPart.Position
        local range = AbilityRange.Value
        
        local target = getTargetByPriority(originPos, range)
        if not target or not target.RootPart then return false end
        
        local targetPos = target.RootPart.Position
        
        if LightningStorm.Enabled then
            if switchToAbility("LIGHTNING_STORM") then
                if bedwars.AbilityController:canUseAbility("LIGHTNING_STORM") then
                    trackDamage(target, 4)
                    return useAbility("LIGHTNING_STORM", targetPos)
                end
            end
        end
        
        if LightningStrike.Enabled then
            if switchToAbility("LIGHTNING_STRIKE") then
                if bedwars.AbilityController:canUseAbility("LIGHTNING_STRIKE") then
                    trackDamage(target, 1)
                    return useAbility("LIGHTNING_STRIKE", targetPos)
                end
            end
        end
        
        return false
    end
    
    local function startAbilityLoop()
        abilityRunning = true
        task.spawn(function()
            while abilityRunning and Zeno.Enabled do
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end
                
                local currentTime = tick()
                local delayTime = AbilityDelay.Value
                
                performShockwave()
                
                if (currentTime - lastAbilityUse) >= delayTime then
                    performLightningAbility()
                end
                
                task.wait(0.05)
            end
            abilityRunning = false
        end)
    end
    
    Zeno = vape.Categories.Kits:CreateModule({
        Name = 'Zeno',
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
        Tooltip = 'Automatically uses Zeno wizard abilities on enemies'
    })
    
    Targets = Zeno:CreateTargets({
        Players = true,
        NPCs = false,
        Walls = true
    })
    
    local methods = {'Distance', 'Health', 'Armor', 'Damaged'}
    
    TargetPriority = Zeno:CreateDropdown({
        Name = 'Target Priority',
        List = methods,
        Default = 'Distance',
        Tooltip = 'How to prioritize targets',
        Function = function(val)
            if HealthMode and HealthMode.Object then
                HealthMode.Object.Visible = (val == 'Health')
            end
            if ArmorMode and ArmorMode.Object then
                ArmorMode.Object.Visible = (val == 'Armor')
            end
        end
    })
    
    HealthMode = Zeno:CreateDropdown({
        Name = 'Health Mode',
        List = {'Lowest', 'Highest'},
        Default = 'Lowest',
        Visible = false,
        Tooltip = 'Target lowest or highest health players'
    })
    
    ArmorMode = Zeno:CreateDropdown({
        Name = 'Armor Mode',
        List = {'Weakest', 'Strongest'},
        Default = 'Weakest',
        Visible = false,
        Tooltip = 'Target weakest or strongest armored players'
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
    
    AbilityDelay = Zeno:CreateSlider({
        Name = 'Ability Delay',
        Min = 0,
        Max = 2,
        Default = 0.3,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay between use'
    })
end)

