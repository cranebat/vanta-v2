--[[
    features/loader.lua

    Stock OSS release has this file as a 32-byte placeholder ("-- Omitted. Do this
    yourself. <3"). This is the real implementation.

    Auto Parry, the farms (automation/loader.lua) and the two visuals entry points
    (visuals/player_esp, visuals/base_esp) are wired directly in init.lua and don't go
    through here. This loader is for everything else under src/features/** that follows
    generic_feature.lua's {id, enable, disable} shape - Rain's ~100 secondary features
    (buttons, combat helpers, exploits, misc, movement, qol, removals, spoofing).

    None of those are ported into vanta-v2 yet (explicitly deprioritized - "other stuff
    is less important" - versus the loading system and APC timings). `feature_modules`
    below is the manifest to fill in as they get added; until then this is a safe no-op.
]]

local loader = {};

-- Add "@src/features/<...>" entries here as more of Project Rain's secondary features
-- get copied into src/features/** and confirmed to export a generic_feature-shaped table.
local feature_modules = {};

function loader.initialize()
    for _, path in feature_modules do
        local ok, feature = pcall(require, path);
        if not ok then
            warn("[vanta] features/loader: failed to require " .. tostring(path) .. ": " .. tostring(feature));
            continue;
        end;

        if typeof(feature) ~= "table" or not feature.id then
            warn("[vanta] features/loader: " .. tostring(path) .. " didn't return a generic_feature-shaped table, skipping");
            continue;
        end;

        aztup.features[feature.id] = feature;
    end;
end

return loader;
