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
	local lightingService = cloneref(game:GetService('Lighting'))
	local isnetworkowner = identifyexecutor and table.find({'Volcano', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
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
		lastKrystalUpdateCheck = 0,
		BedAlarmNotifyTick = 0,
		BedAlarmIsTrigged = false,
		BedAlarmHighlightedEnimes = {},
		BedAlarm = {},
		BedAlarmSoundTick = 0,
		silasAbilityTime = 0,
		terraStompTime = 0,
		terraKickTime = 0,
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

	-- KILLAURA FIX HELPER: humanized attack sender
	local killauraAttackState = killauraAttackState or { count = 0, last = 0 }

	local function sendKillauraAttack(sword, targetEntity, pos, dir, delta)
		local BURST_LIMIT = 20
		local BURST_RESET_SECS = 1.0
		local JITTER_MAX_DELTA = 0.12
		local HUMAN_PAUSE_MIN, HUMAN_PAUSE_MAX = 0.25, 0.55

		-- attempt to resolve AttackRemote if it's not in local scope
		if not AttackRemote or not (AttackRemote.FireServer) then
			AttackRemote = bedwars.Client and bedwars.Client:Get(remotes.AttackEntity) or AttackRemote
			AttackRemote = AttackRemote and AttackRemote.instance or AttackRemote
		end

		local now = tick()
		if now - killauraAttackState.last > BURST_RESET_SECS then
			killauraAttackState.count = 0
		end
		killauraAttackState.count = killauraAttackState.count + 1
		killauraAttackState.last = now

		if killauraAttackState.count > BURST_LIMIT then
			task.wait(HUMAN_PAUSE_MIN + (math.random() * (HUMAN_PAUSE_MAX - HUMAN_PAUSE_MIN)))
			killauraAttackState.count = 0
			killauraAttackState.last = tick()
		end

		-- compute baseline delta with a small random jitter
		local baseline = 0.5
		if bedwars and bedwars.SwordController and bedwars.SwordController.lastAttack then
			local srvNow = (workspace and workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or tick()
			baseline = math.clamp(srvNow - (bedwars.SwordController.lastAttack or srvNow), 0, 5) or baseline
			if baseline == 0 then baseline = 0.5 end
		end
		local jitter = (math.random() - 0.5) * JITTER_MAX_DELTA
		local lastSwingDelta = math.max(0, baseline + jitter)

		-- safe remote call
		if AttackRemote and AttackRemote.FireServer then
			pcall(function()
				AttackRemote:FireServer({
					weapon = sword.tool,
					chargedAttack = { chargeRatio = 0 },
					lastSwingServerTimeDelta = lastSwingDelta,
					entityInstance = targetEntity.Character,
					validate = {
						raycast = {
							cameraPosition = { value = pos },
							cursorDirection = { value = dir }
						},
						targetPosition = { value = (targetEntity.Character and (targetEntity.Character.PrimaryPart or targetEntity.Character:FindFirstChild('HumanoidRootPart')) and (targetEntity.Character.PrimaryPart or targetEntity.Character:FindFirstChild('HumanoidRootPart')).Position) or dir },
						selfPosition = { value = pos }
					}
				})
			end)
		end

		-- keep local bookkeeping consistent
		swingCooldown = tick()
		if bedwars and bedwars.SwordController then
			bedwars.SwordController.lastAttack = (workspace and workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or tick()
		end
		store.attackReach = (delta.Magnitude * 100) // 1 / 100
		store.attackReachUpdate = tick() + 1
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
			if entitylib.Running then entitylib.stop() end

			local function customEntity(ent)
				if playersService:GetPlayerFromCharacter(ent) then return end
				if collectionService:HasTag(ent.Parent, 'entity') then return end
				local teamFunc = function(self)
					local npcTeam = self.Character:GetAttribute('Team')
					return lplr:GetAttribute('Team') ~= npcTeam
				end
				entitylib.addEntity(ent, nil, teamFunc)
			end

			table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
				entitylib.addPlayer(v)
			end))
			table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
				entitylib.removePlayer(v)
			end))

