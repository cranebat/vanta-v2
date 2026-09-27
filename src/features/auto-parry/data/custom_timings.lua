--[[
    custom_timings.lua

    This module doesn't exist in the OSS release (it's one of the "certain loading
    modules" Rain stripped) but animator-handler.lua requires it and calls two methods
    on it unconditionally:

        for name in custom_timings:sync() do ... end          -- lists names for the UI
        local data, name = custom_timings:lookup(id)           -- exact animation-ID lookup,
                                                                -- checked BEFORE data/base.lua

    Its contract is exact-animation-ID keyed, same shape as data/base.lua's own table -
    it's meant for timings a user hand-adds/overrides, not a generic formula. APC's
    timings are generic per-weapon-TYPE formulas, not per-exact-ID, so they don't belong
    behind this interface at all - they're wired into animator-handler.lua's fallback
    path instead (see data/apc_fallback.lua), which only runs when *neither* this table
    nor data/base.lua has an exact match.

    This file is intentionally just an empty, always-miss table: it makes the require
    succeed and the two call sites behave correctly (no entries, no crash), without
    inventing any timing data. Add entries to `entries` below (keyed by animation ID
    string) if you ever want to hand-override a specific move.
]]

local custom_timings = {};

-- entries[animation_id] = { data = <timing-data-table>, name = "Some Name" }
local entries = {};

function custom_timings:lookup(id: string)
    local entry = entries[id];
    if not entry then
        return nil, nil;
    end;
    return entry.data, entry.name;
end

function custom_timings:sync()
    -- Callers do `for name in custom_timings:sync() do`, i.e. ONE loop variable, so this
    -- must return a plain iterator function yielding just the name each call, not an
    -- ipairs()-style (index, value) pair.
    local names = {};
    for _, entry in pairs(entries) do
        table.insert(names, entry.name);
    end;
    local i = 0;
    return function()
        i += 1;
        return names[i];
    end;
end

return custom_timings;
