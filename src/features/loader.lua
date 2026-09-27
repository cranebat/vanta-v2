--[[
    features/loader.lua (vanta-v2)

    The stock OSS file is a 32-byte placeholder ("-- Omitted. Do this yourself. <3").
    What it has to do is fully determined by the rest of the source:

      1. Define the global `Feature` - every feature file does
         `Feature:new("id", signal, fn)` and nothing else defines it.
         It's features/generic_feature.lua.
      2. Require every feature module. Feature files return a Feature object; a few
         (features/auto-parry/auto-parry.lua) return nil and exist only for their side
         effects - auto-parry.lua sets getgenv().DefendActionManager and Latency, which
         animator-handler.lua uses on every parry, and nothing else requires it.
      3. Register returned Feature objects in aztup.features[id]. utility/ui/wrapper.lua
         does the rest: when a toggle with that id flips on, it connects feature.conn to
         feature.update (and calls enable/disable).

    Runs from init.lua after hooking/UI library/utilities are set up and before
    animator-handler and the UI tabs, matching the stock init.lua order.
]]

Feature = require("@src/features/generic_feature");
getgenv().Feature = Feature;

-- Not auto-loaded here, each for a specific reason:
local SKIP_PREFIXES = {
    "@src/features/generic_feature",      -- the base class itself (set above)
    "@src/features/hooking",               -- required explicitly by init.lua, earlier
    "@src/features/loader",                -- this file
    "@src/features/buttons/",              -- plain functions, required by the tabs as button callbacks
    "@src/features/auto-builder/",         -- required explicitly by init.lua as env.ab_builder
    "@src/features/visuals/player_esp",    -- called explicitly by init.lua after the UI exists
    "@src/features/visuals/base_esp",      -- same
    "@src/features/auto-parry/data/",      -- timing data / helpers, required by the handlers
    "@src/features/auto-parry/handlers/",  -- animator-handler is spawned by init.lua after this
    "@src/features/auto-parry/fallbacks/", -- loaded by the handlers
    "@src/features/auto-parry/services/",
    "@src/features/auto-parry/util/",
    "@src/features/auto-parry/builder",    -- locked-feature stub, used by the Combat tab
};

local function skipped(path)
    for _, prefix in SKIP_PREFIXES do
        if path:sub(1, #prefix) == prefix then
            return true;
        end;
    end;
    return false;
end

local loader = {};

function loader.initialize()
    local loaded, failed = 0, 0;

    for _, path in list_modules("features/**") do
        if skipped(path) then
            continue;
        end;

        local ok, result = pcall(require, path);
        if not ok then
            failed += 1;
            warn("[vanta] feature failed to load: " .. path .. "\n" .. tostring(result));
            continue;
        end;

        -- A feature file can register itself (exploits/ap_breaker.lua does); otherwise
        -- register whatever Feature object it returned.
        if typeof(result) == "table" and typeof(result.id) == "string" then
            aztup.features[result.id] = result;
        end;
        loaded += 1;
    end;

    if Logger and Logger.log then
        Logger.log(string.format("[vanta] features loaded: %d ok, %d failed", loaded, failed));
    end;
end

return loader;
