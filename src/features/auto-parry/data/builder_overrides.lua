--[[
    data/builder_overrides.lua (Vanta AP Builder)

    Holds your AP Builder edits, applies them to Auto Parry live, saves them to
    workspace/Vanta/ap_builder.json, and exports them for adding to the official
    timings.

    Per timing name:
      offset_ms     - added to every action's timing (all timings, incl. scripted/APC)
      hitbox_scale  - % applied to every action's hitbox (all timings)
      actions[i]    - exact values for data timings: when (s), type, hitbox {X,Y,Z},
                      offset {X,Y,Z}, shape ("ball" or nil)
]]

local HttpService = game:GetService("HttpService");
local SAVE_FILE = "Vanta/ap_builder.json";

local builder = { entries = {} };

local function load()
    local ok, data = pcall(function()
        return isfile(SAVE_FILE) and HttpService:JSONDecode(readfile(SAVE_FILE)) or nil
    end);
    if ok and typeof(data) == "table" then
        builder.entries = data;
    end;
end
load();

local save_queued = false;
function builder.save()
    if save_queued then return end;
    save_queued = true;
    task.delay(0.5, function()
        save_queued = false;
        pcall(writefile, SAVE_FILE, HttpService:JSONEncode(builder.entries));
    end);
end

local function enabled()
    return aztup.flags.ap_builder_enabled ~= false
end

function builder.entry(name, create)
    local e = builder.entries[name];
    if not e and create then
        e = {};
        builder.entries[name] = e;
    end;
    return e
end

-- Actions are stored with string keys ("1", "2", ...) so the JSON stays an object.
function builder.action(name, index, create)
    local e = builder.entry(name, create);
    if not e then return nil end;
    e.actions = e.actions or (create and {} or nil);
    if not e.actions then return nil end;
    local key = tostring(index);
    local a = e.actions[key];
    if not a and create then
        a = {};
        e.actions[key] = a;
    end;
    return a
end

-- Seconds to add to a timing's actions.
function builder.offset(name)
    if not enabled() or not name then return 0 end;
    local e = builder.entries[name];
    return e and e.offset_ms and e.offset_ms / 1000 or 0
end

-- Hitbox multiplier.
function builder.hitbox_scale(name)
    if not enabled() or not name then return 1 end;
    local e = builder.entries[name];
    return e and e.hitbox_scale and e.hitbox_scale / 100 or 1
end

-- Actions are numbered in time order (ties keep their original order) - the same
-- order Auto Parry runs them in - so edit #N always means the same action.
function builder.sorted(actions)
    local indexed = {};
    for i, a in actions do
        table.insert(indexed, { i = i, a = a });
    end;
    table.sort(indexed, function(x, y)
        local wx, wy = x.a.when or 0, y.a.when or 0;
        if wx ~= wy then return wx < wy end;
        return x.i < y.i
    end);
    local out = {};
    for n, item in indexed do out[n] = item.a end;
    return out
end

local function xyz(v)
    return { X = v.X or v[1] or 0, Y = v.Y or v[2] or 0, Z = v.Z or v[3] or 0 }
end

-- Data timings (a static `actions` list, no `run`): returns a copy with the
-- per-action edits applied, or the original if there are none.
function builder.apply_static(name, data)
    if not enabled() or not name or not data or data.run or not data.actions then return data end;
    local e = builder.entries[name];
    if not e or not e.actions or next(e.actions) == nil then return data end;

    local copy = table.clone(data);
    copy.actions = builder.sorted(data.actions);
    for key, edit in e.actions do
        local i = tonumber(key);
        local base = i and copy.actions[i];
        if base then
            local a = table.clone(base);
            if edit.when ~= nil then a.when = edit.when end;
            if edit.type ~= nil then a.type = edit.type end;
            if edit.hitbox ~= nil then a.hitbox = xyz(edit.hitbox) end;
            if edit.offset ~= nil then
                local o = xyz(edit.offset);
                a.offset = CFrame.new(o.X, o.Y, o.Z);
            end;
            if edit.shape ~= nil then a.shape = edit.shape ~= "" and edit.shape or nil end;
            copy.actions[i] = a;
        end;
    end;
    return copy
end

function builder.reset(name)
    builder.entries[name] = nil;
    builder.save();
end

function builder.reset_all()
    table.clear(builder.entries);
    builder.save();
end

-- Removes empty entries / defaults so the export only has real changes.
local function cleaned()
    local out = {};
    for name, e in builder.entries do
        local c = {};
        if e.offset_ms and e.offset_ms ~= 0 then c.offset_ms = e.offset_ms end;
        if e.hitbox_scale and e.hitbox_scale ~= 100 then c.hitbox_scale = e.hitbox_scale end;
        if e.actions then
            for key, a in e.actions do
                if next(a) ~= nil then
                    c.actions = c.actions or {};
                    c.actions[key] = a;
                end;
            end;
        end;
        if next(c) ~= nil then out[name] = c end;
    end;
    return out
end

function builder.count()
    local n = 0;
    for _ in cleaned() do n += 1 end;
    return n
end

function builder.export()
    return "VANTA_AP_BUILDER " .. HttpService:JSONEncode(cleaned())
end

return builder;
