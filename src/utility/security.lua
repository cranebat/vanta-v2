--[[
    utility/security.lua (vanta-v2)

    Empty (0 bytes) in the Project Rain OSS release. Now holds the log nuker ported
    from the original Vanta build (src/security/anti_detection.lua):

    LogService:GetLogHistory() is hooked to return an empty history to the game's own
    scripts, so anything they collect from the output log comes back empty.

    Change vs. the original Vanta hook: calls made by the executor itself (checkcaller)
    still get the real history, so your executor's console/debugging keeps working.

    Required once, early, from init.lua.
]]

local LogService = game:GetService("LogService");

local ok, err = pcall(function()
    local old_get_log_history;
    old_get_log_history = hookfunction(LogService.GetLogHistory, newcclosure(function(...)
        if checkcaller() then
            return old_get_log_history(...);
        end;
        return {};
    end));
end);

if not ok then
    warn("[vanta] log nuker failed to hook GetLogHistory: " .. tostring(err));
end;

return ok;
