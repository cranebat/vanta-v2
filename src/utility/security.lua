--[[
    utility/security.lua (vanta-v2) - log nuker

    LogService:GetLogHistory() returns the REAL output history with only the
    entries that give the script away removed (same approach as the script that
    fixed this detection). An empty history was itself a tell - an anticheat can
    print its own line and check it comes back - so nothing else is touched.

    Removed entries:
      - anything mentioning Vanta / Project Rain / the script's internals,
      - executor API names (hookfunction, getgc, checkcaller, ...),
      - the script's own debug / warning messages,
      - errors from executor-run code: they have an empty script name
        (":35071: attempt to index nil ...", "Script '', Line 35071"), which game
        scripts never produce.

    Hooked two ways, because a game script can call it either way:
      - LogService:GetLogHistory()           (method call, __namecall - also
                                               handled in features/hooking.lua)
      - LogService.GetLogHistory(LogService) (hookfunction)

    The executor itself still sees the full history (so your console keeps
    working), unless strict mode is on: UI tab -> Script Toggles ->
    "log nuker: hide from executor too" (rejoin to apply).
]]

local LogService = game:GetService("LogService");

-- Case-insensitive plain-text matches.
local BLOCKED_TEXT = {
    -- the script itself
    "vanta", "project rain", "aztup", "lph_", "@src/", "luraph",
    -- executor API names
    "hookfunction", "hookmetamethod", "getgc", "checkcaller", "getrawmetatable",
    "getnamecallmethod", "setthreadidentity", "getthreadidentity", "getconnections",
    "getupvalue", "setupvalue", "getsenv", "getgenv", "firesignal", "loadstring",
    "isexecutorclosure", "newcclosure", "debug.profileend(",
    -- the script's own debug / warning output
    "[auto feint]", "[feint]", "[apc]", "[fire gun]", "[anti ap]", "[ap]",
    "[lightning stream]", "[auto builder]", "[auto progression]", "[racemorph]",
    "[projectile timings]", "[detach", "[hooking]", "[set bools bad wtf]",
    "register your tags", "getloadedmodules might be failing", "failed to get sea_cl_func",
    "failed to get fallback from", "turn ap on stupid", "effect-handler run() failed",
    "invalid@projectile-timing", "failed to load timing file", "failed to run timing file",
    "not ported yet", "reloaded projectile timings",
};

-- Lua patterns (checked against the lowercased message).
local BLOCKED_PATTERNS = {
    "^:%d+:",          -- error from executor code: empty chunk name
    "^%[string ",      -- error from loadstring'd code
    "script '', line", -- stack trace line for executor code
    "^%[[wie]%]: ",    -- Logger's [W]: / [I]: / [E]: prefixes
};

local function is_blocked(message)
    if typeof(message) ~= "string" then return false end;
    local lower = message:lower();
    for _, text in BLOCKED_TEXT do
        if lower:find(text, 1, true) then return true end;
    end;
    for _, pattern in BLOCKED_PATTERNS do
        if lower:find(pattern) then return true end;
    end;
    return false
end

-- Returns a filtered copy of a GetLogHistory() result.
local function filter_history(history)
    if typeof(history) ~= "table" then return history end;
    local out = {};
    for _, entry in history do
        local message = typeof(entry) == "table" and entry.message;
        if not is_blocked(message) then
            table.insert(out, entry);
        end;
    end;
    return out
end
getgenv().vanta_filter_log_history = filter_history;

-- Strict mode is read straight from the fast-flags file (fflags isn't loaded yet).
local strict = false;
pcall(function()
    if isfile("Vanta/fflags.txt") then
        strict = game:GetService("HttpService"):JSONDecode(readfile("Vanta/fflags.txt")).log_nuker_strict == true;
    end;
end);
getgenv().vanta_log_nuker_strict = strict;

local function should_filter()
    return not checkcaller() or getgenv().vanta_log_nuker_strict
end

local status = {};

-- 1) Method calls: LogService:GetLogHistory()
local namecall_ok, namecall_err = pcall(function()
    local old_namecall;
    old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if self == LogService and getnamecallmethod() == "GetLogHistory" and should_filter() then
            return filter_history(old_namecall(self, ...));
        end;
        return old_namecall(self, ...);
    end));
end);
table.insert(status, "method call " .. (namecall_ok and "hooked" or ("FAILED (" .. tostring(namecall_err) .. ")")));

-- 2) Direct function calls: LogService.GetLogHistory(LogService)
local func_ok, func_err = pcall(function()
    local old_get_log_history;
    old_get_log_history = hookfunction(LogService.GetLogHistory, newcclosure(function(...)
        local history = old_get_log_history(...);
        if should_filter() then
            return filter_history(history);
        end;
        return history;
    end));
end);
table.insert(status, "function " .. (func_ok and "hooked" or ("FAILED (" .. tostring(func_err) .. ")")));

-- (This line itself is filtered out of the game's view.)
print("[vanta] log nuker: " .. table.concat(status, ", ") .. (strict and " (strict: filtered for the executor too)" or " (executor still sees the full log)"));

return namecall_ok or func_ok;
