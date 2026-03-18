local folderToClean = "newvape"
local folderToKeep = "profiles"
local reinstallUrl = "https://raw.githubusercontent.com/wrealaero/poopparty/main/NewMainScript.lua"

local function deleteRecursive(path, keepPath)
    if path == keepPath then return end
    if isfolder and isfolder(path) then
        for _, item in ipairs(listfiles(path)) do
            deleteRecursive(item, keepPath)
        end
        if path ~= keepPath then
            if delfolder then delfolder(path) else pcall(delfolder, path) end
        end
    else
        delfile(path)
    end
end

if not isfolder(folderToClean) then
    print("folder '" .. folderToClean .. "' not found.")
    return
end

local keepFullPath = folderToClean .. "/" .. folderToKeep
if not isfolder(keepFullPath) then
    print("warning nigga: '" .. keepFullPath .. "' missing  - everything boutta get deleted gang")
end

for _, item in ipairs(listfiles(folderToClean)) do
    if item ~= keepFullPath then
        deleteRecursive(item, keepFullPath)
    end
end

print("loading aerov4...")
task.wait(1) --no no crash dabo
loadstring(game:HttpGet(reinstallUrl, true))()
