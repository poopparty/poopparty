local EXPECTED_REPO_OWNER = "poopparty"
local EXPECTED_REPO_NAME = "poopparty"
local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"

local function getHWID()
    local hwid = nil
    
    if gethwid then
        hwid = gethwid()
    elseif getexecutorname then
        local executor_name = getexecutorname()
        local unique_str = executor_name .. tostring(game:GetService("UserInputService"):GetGamepadState(Enum.UserInputType.Gamepad1))
        
        if syn and syn.crypt and syn.crypt.hash then
            hwid = syn.crypt.hash(unique_str)
        elseif crypt and crypt.hash then
            hwid = crypt.hash(unique_str)
        else
            hwid = game:GetService("HttpService"):GenerateGUID(false)
        end
    end
    
    if not hwid and game:GetService("RbxAnalyticsService") then
        local success, result = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if success and result then
            hwid = result
        end
    end
    
    if not hwid then
        hwid = tostring(math.random(100000, 999999)) .. tostring(os.time())
    end
    
    return hwid
end

local function clearSecurityFolder()
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
        return
    end
    
    for _, file in listfiles('newvape/security') do
        if isfile(file) then
            delfile(file)
        end
    end
end

local function createValidationFile(username, hwid)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    
    local validationData = {
        username = username,
        hwid = hwid,
        timestamp = os.time()
    }
    
    local encoded = game:GetService("HttpService"):JSONEncode(validationData)
    writefile('newvape/security/validated', encoded)
end

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

local function SecurityCheck(loginData)
    if not loginData or type(loginData) ~= "table" then
        game.StarterGui:SetCore("SendNotification", {
            Title = "error",
            Text = "wrong loadstring bitch. dm aero",
            Duration = 3
        })
        return false
    end
    
    local inputUsername = loginData.Username
    local inputPassword = loginData.Password
    
    if not inputUsername or not inputPassword then
        game.StarterGui:SetCore("SendNotification", {
            Title = "error", 
            Text = "missing yo credentials fuck u doing? dm aero",
            Duration = 3
        })
        return false
    end
    
    clearSecurityFolder()
    
    local currentHWID = getHWID()
    
    local accounts = fetchAccounts()
    if not accounts then
        game.StarterGui:SetCore("SendNotification", {
            Title = "error",
            Text = "failed to check if its yo account check your wifi it might be shitty. dm aero",
            Duration = 3
        })
        return false
    end
    
    local accountFound = false
    local correctPassword = false
    local accountActive = false
    local accountHWID = nil
    local foundUsername = nil
    
    for _, account in pairs(accounts) do
        if account.Username == inputUsername then
            accountFound = true
            foundUsername = account.Username
            if account.Password == inputPassword then
                correctPassword = true
                accountActive = account.IsActive == true
                accountHWID = account.HWID
            end
            break
        end
    end
    
    if not accountFound then
        game.StarterGui:SetCore("SendNotification", {
            Title = "access denied",
            Text = "username not found. dm 5qvx for access",
            Duration = 3
        })
        return false
    end
    
    if not correctPassword then
        game.StarterGui:SetCore("SendNotification", {
            Title = "access denied",
            Text = "wrong password for " .. inputUsername,
            Duration = 3
        })
        return false
    end
    
    if not accountActive then
        game.StarterGui:SetCore("SendNotification", {
            Title = "account inactive",
            Text = "your account is currently inactive",
            Duration = 3
        })
        return false
    end
    
    if not accountHWID or accountHWID == "" or accountHWID == "your-hwid-here" or accountHWID:find("hwid-here") then
        game.StarterGui:SetCore("SendNotification", {
            Title = "no hwid set",
            Text = "your account has no hwid set. contact aero to set it up",
            Duration = 10
        })
        return false
    end
    
    if currentHWID ~= accountHWID then
        game.StarterGui:SetCore("SendNotification", {
            Title = "hwid mismatch",
            Text = "this device is not authorized for this account",
            Duration = 5
        })
        return false
    end
    
    createValidationFile(inputUsername, currentHWID)
    
    return true
end

local passedArgs = ... or {}

if not SecurityCheck(passedArgs) then
    return
end

if not isfolder('newvape/security') then
    makefolder('newvape/security')
end

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    writefile(file, '')
end

local function downloadFile(path, func)
    if not isfile(path) then
        local suc, res = pcall(function()
            return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
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

local function wipeFolder(path)
    if not isfolder(path) then return end
    for _, file in listfiles(path) do
        if file:find('loader') then continue end
        if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
            delfile(file)
        end
    end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

if not shared.VapeDeveloper then
    local _, subbed = pcall(function()
        return game:HttpGet('https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME)
    end)
    local commit = subbed:find('currentOid')
    commit = commit and subbed:sub(commit + 13, commit + 52) or nil
    commit = commit and #commit == 40 and commit or 'main'
    if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
        wipeFolder('newvape')
        wipeFolder('newvape/games')
        wipeFolder('newvape/guis')
        wipeFolder('newvape/libraries')
    end
    writefile('newvape/profiles/commit.txt', commit)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')()
