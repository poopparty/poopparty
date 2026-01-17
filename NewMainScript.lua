local SecurityModule = {}

local EXPECTED_REPO_OWNER = "poopparty"
local EXPECTED_REPO_NAME = "poopparty"
local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"

local function clearSecurityFolderIfDifferent(username)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
        return
    end
    
    if isfile('newvape/security/validated') then
        local success, validationData = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile('newvape/security/validated'))
        end)
        
        if not success or (validationData and validationData.username ~= username) then
            for _, file in listfiles('newvape/security') do
                if isfile(file) then
                    delfile(file)
                end
            end
        end
    end
end

local function createValidationFile(username, repoInfo)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    
    local validationData = {
        username = username,
        timestamp = os.time(),
        repo_owner = repoInfo.owner,
        repo_name = repoInfo.name,
        validated = true,
        checksum = game:GetService("HttpService"):GenerateGUID(false)
    }
    
    local encoded = game:GetService("HttpService"):JSONEncode(validationData)
    writefile('newvape/security/validated', encoded)
    writefile('newvape/security/'..username, tostring(os.time()))
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

local function getRepoInfo()
    local commitUrl = 'https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME
    return {
        owner = EXPECTED_REPO_OWNER,
        name = EXPECTED_REPO_NAME,
        url = commitUrl
    }
end

local function SecurityCheck(loginData)
    if not loginData or type(loginData) ~= "table" then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "wrong loadstring bitch. dm aero",
            Duration = 3
        })
        return false
    end
    
    local inputUsername = loginData.Username
    local inputPassword = loginData.Password
    
    if not inputUsername or not inputPassword then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error", 
            Text = "missing yo credentials fuck u doing? dm aero",
            Duration = 3
        })
        return false
    end
    
    clearSecurityFolderIfDifferent(inputUsername)
    
    local accounts = fetchAccounts()
    if not accounts then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Connection Error",
            Text = "failed to check if its yo account check your wifi it might be shitty. dm aero",
            Duration = 3
        })
        return false
    end
    
    local accountFound = false
    local accountActive = false
    for _, account in pairs(accounts) do
        if account.Username == inputUsername and account.Password == inputPassword then
            accountFound = true
            accountActive = account.IsActive == true
            break
        end
    end
    
    if not accountFound then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Access Denied",
            Text = "wrong info dm 5qvx for access",
            Duration = 3
        })
        return false
    end
    
    if not accountActive then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Account Inactive",
            Text = "Your account is currently inactive.",
            Duration = 3
        })
        return false
    end
    
    local repoInfo = getRepoInfo()
    createValidationFile(inputUsername, repoInfo)
    
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
