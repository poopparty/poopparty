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

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

local function downloadPremadeProfiles(commit)
    local httpService = game:GetService('HttpService')
    if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end
    local success, response = pcall(function()
        return game:HttpGet('https://api.github.com/repos/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/contents/profiles/premade?ref='..commit)
    end)
    if success and response then
        local ok, files = pcall(function() return httpService:JSONDecode(response) end)
        if ok and type(files) == 'table' then
            for _, file in pairs(files) do
                if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                    local filePath = 'newvape/profiles/premade/'..file.name
                    if not isfile(filePath) then
                        local dl = file.download_url or ('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..commit..'/profiles/premade/'..file.name)
                        local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                        if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                    end
                end
            end
        end
    end
end

local function downloadPremadeProfiles(commit)
    local httpService = game:GetService('HttpService')
    if not isfolder('newvape/profiles/premade') then
        makefolder('newvape/profiles/premade')
    end

    local success, response = pcall(function()
        return game:HttpGet('https://api.github.com/repos/poopparty/poopparty/contents/profiles/premade?ref=' .. commit)
    end)

    if success and response then
        local ok, files = pcall(function()
            return httpService:JSONDecode(response)
        end)

        if ok and type(files) == 'table' then
            for _, file in pairs(files) do
                if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                    local filePath = 'newvape/profiles/premade/' .. file.name
                    if not isfile(filePath) then
                        local dl = file.download_url or ('https://raw.githubusercontent.com/poopparty/poopparty/' .. commit .. '/profiles/premade/' .. file.name)
                        local ds, dc = pcall(function()
                            return game:HttpGet(dl, true)
                        end)
                        if ds and dc and dc ~= '404: Not Found' then
                            writefile(filePath, dc)
                        end
                    end
                end
            end
        end
    end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/poopparty/poopparty')
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
	downloadPremadeProfiles(commit)
	writefile('newvape/profiles/commit.txt', commit)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')()
