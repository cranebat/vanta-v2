local storage_service = identifyexecutor() == "Synapse Z" and services.MemStorageService or services.MemStorageService;

if identifyexecutor() == "Synapse Z" then
    local existing_data = storage_service:GetItem("persistent_data");
    if not existing_data or #existing_data <= 0 then
        storage_service:SetItem("persistent_data", "{}");
    end
elseif not storage_service:HasItem("persistent_data") then
    storage_service:SetItem("persistent_data", "{}");
end

--[[
    Vanta: automation state is also saved to workspace/Vanta/persistent_data.json.
    MemStorageService (executor memory) isn't guaranteed to survive a server hop on
    every executor; the file always does. On load, if memory is empty, the file is
    used - but only if it was saved in the last 20 minutes (a running automation
    refreshes it every minute), so an old automation never restarts days later.
]]
local BACKUP_FILE = "Vanta/persistent_data.json";
local BACKUP_MAX_AGE = 20 * 60;

local function write_backup(current)
    pcall(function()
        writefile(BACKUP_FILE, services.HttpService:JSONEncode({
            saved_at = os.time(),
            data = current,
        }));
    end);
end

local function read_backup()
    local ok, result = pcall(function()
        if not isfile(BACKUP_FILE) then return nil end;
        local saved = services.HttpService:JSONDecode(readfile(BACKUP_FILE));
        if typeof(saved) ~= "table" or typeof(saved.data) ~= "string" then return nil end;
        if os.time() - (tonumber(saved.saved_at) or 0) > BACKUP_MAX_AGE then return nil end;
        services.HttpService:JSONDecode(saved.data); -- make sure it's valid
        return saved.data
    end);
    return ok and result or nil
end

local persistent_data = {} do
    persistent_data.__index = persistent_data;
    persistent_data.current = storage_service:GetItem("persistent_data") or "{}";

    if persistent_data.current == "{}" or persistent_data.current == "" then
        local backup = read_backup();
        if backup and backup ~= "{}" then
            persistent_data.current = backup;
            pcall(function()
                storage_service:SetItem("persistent_data", backup);
            end);
        end;
    end;

    local function store(self)
        storage_service:SetItem("persistent_data", self.current);
        write_backup(self.current);
    end

    function persistent_data:wipe()
        self.current = "{}";
        store(self);
    end

    function persistent_data:set(key, value)
        local decoded = services.HttpService:JSONDecode(self.current);
        decoded[key] = value;

        self.current = services.HttpService:JSONEncode(decoded);
        store(self);
    end;

    function persistent_data:remove(key)
        local decoded = services.HttpService:JSONDecode(self.current);
        decoded[key] = nil;
        self.current = services.HttpService:JSONEncode(decoded);
        store(self);
    end;

    -- Refreshes the backup's timestamp (called every minute while an automation runs).
    function persistent_data:touch()
        write_backup(self.current);
    end;

    function persistent_data:get(key, or_default)
        return services.HttpService:JSONDecode(self.current)[key] or or_default
end;
end;

return persistent_data
