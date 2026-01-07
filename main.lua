repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local function validateSecurity()
    local HttpService = game:GetService("HttpService")
    
    if not isfile('newvape/security/validated') then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "no validation file found",
            Duration = 5
        })
        return false, nil
    end
    
    local validationContent = readfile('newvape/security/validated')
    local success, validationData = pcall(function()
        return HttpService:JSONDecode(validationContent)
    end)
    
    if not success or not validationData then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "corrupted validation file",
            Duration = 5
        })
        return false, nil
    end
    
    if not validationData.username or not validationData.repo_owner or not validationData.repo_name or not validationData.validated then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "invalid validation data",
            Duration = 5
        })
        return false, nil
    end
    
    if not isfile('newvape/security/'..validationData.username) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "user validation missing",
            Duration = 5
        })
        return false, nil
    end
    
    local EXPECTED_REPO_OWNER = "poopparty"
    local EXPECTED_REPO_NAME = "poopparty"
    
    if validationData.repo_owner ~= EXPECTED_REPO_OWNER or validationData.repo_name ~= EXPECTED_REPO_NAME then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "unauthorized repository detected",
            Duration = 5
        })
        return false, nil
    end
    
    local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"
    
    local function fetchAccounts()
        local success, response = pcall(function()
            return game:HttpGet(ACCOUNT_SYSTEM_URL)
        end)
        if success and response then
            local accountsTable = loadstring(response)()
            if accountsTable and accountsTable.Accounts then
                return accountsTable.Accounts
            end
        end
        return nil
    end
    
    local accounts = fetchAccounts()
    if not accounts then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Connection Error",
            Text = "failed to verify account status",
            Duration = 5
        })
        return false, nil
    end
    
    local accountValid = false
    local accountActive = false
    for _, account in pairs(accounts) do
        if account.Username == validationData.username then
            accountValid = true
            accountActive = account.IsActive == true
            break
        end
    end
    
    if not accountValid then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Access Revoked",
            Text = "your account is no longer authorized",
            Duration = 5
        })
        return false, nil
    end
    
    if not accountActive then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Account Inactive",
            Text = "your account is currently inactive",
            Duration = 5
        })
        return false, nil
    end
    
    return true, validationData.username
end

local securityPassed, validatedUsername = validateSecurity()
if not securityPassed then
    return
end

shared.ValidatedUsername = validatedUsername

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

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function checkAccountActive()
    local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"
    
    local function fetchAccounts()
        local success, response = pcall(function()
            return game:HttpGet(ACCOUNT_SYSTEM_URL)
        end)
        if success and response then
            local accountsTable = loadstring(response)()
            if accountsTable and accountsTable.Accounts then
                return accountsTable.Accounts
            end
        end
        return nil
    end
    
    local accounts = fetchAccounts()
    if not accounts then 
        return true 
    end
    
    for _, account in pairs(accounts) do
        if account.Username == shared.ValidatedUsername then
            return account.IsActive == true
        end
    end
    return false
end

local activeCheckRunning = false
local function startActiveCheck()
    if activeCheckRunning then return end
    activeCheckRunning = true
    
    while task.wait(30) do
        if shared.vape then
            local isActive = checkAccountActive()
            
            if not isActive then
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Access Revoked",
                    Text = "Your account has been deactivated.",
                    Duration = 5
                })
                
                task.wait(2)
                
                if shared.vape and shared.vape.Uninject then
                    shared.vape:Uninject()
                else
                    shared.vape = nil
                    if getgenv and getgenv().vape then
                        getgenv().vape = nil
                    end
                end
                break
            end
        else
            break
        end
    end
    activeCheckRunning = false
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

    if shared.ValidatedUsername then
        task.spawn(function()
            startActiveCheck()
        end)
    end

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', 'wsg, '..shared.ValidatedUsername..'! '..(vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI'), 5)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
