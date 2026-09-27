--[[
    apc_fallback.lua

    Generic per-weapon-type Auto Parry timing, ported from APC (Lycoris Rewrite)'s
    WeaponTest.lua windup formulas. Used by animator-handler.lua when an animation has
    no exact-ID timing (custom_timings / data/base.lua).

    v2 (Vanta): the fallback used to run on *every* untimed animation played by anyone
    holding a weapon, so mantra casts (e.g. Ice Eruption), emotes, movement etc. were
    treated as an M1 swing and parried. It now classifies the animation first:

      1. Known mantra (matched against mantras.json, e.g. "Eruption:Ice" -> anim
         path/name containing "eruptionice" / "iceeruption"):
           - listed in UNPARRIABLE below  -> Dodge at that timing
           - otherwise, "Unknown Mantras" setting: Ignore (default) or Dodge
         A mantra is never parried by the M1 formula any more.
      2. Anything whose path looks like a non-attack (movement, emotes, idle, ...)
         -> ignored.
      3. Everything else -> APC weapon windup formula (unchanged), plus the
         "APC Timing Offset" slider.

    Not ported from WeaponTest.lua (busy-wait sub-cases that would stall the hot path):
    Pistol "Shot", Rifle "2", Bow spark-wait, Titus/Evengarde boss specials.
]]

local weapon = require("@src/features/auto-parry/data/weapon");

local apc_fallback = {};

--------------------------------------------------------------------------- mantras

-- Unparriable mantras -> dodge. Timings are from the original Vanta build's named
-- table ("Eruption" 550ms dodge, "Tornado" 400ms dodge); they are NOT verified
-- in-game - tune with the "Unparriable Dodge Offset" slider.
local UNPARRIABLE = {
    ["Ice Eruption"] = { when = 0.55, size = 60 },
    ["Tornado"]      = { when = 0.40, size = 40 },
};
apc_fallback.UNPARRIABLE = UNPARRIABLE;

-- mantras.json: { ["Eruption:Ice"] = "Ice Eruption", ... }
local mantra_patterns = {}; -- { {needle, display}, ... }
do
    local ok, list = pcall(require, "@src/features/removals/mantra_revealer/mantras");
    if ok and typeof(list) == "table" then
        for key, display in list do
            local skill, element = key:match("^(.-):(.+)$");
            if skill and element then
                local s, e = skill:lower(), element:lower();
                local compact = (display:lower():gsub("[^%w]", ""));
                table.insert(mantra_patterns, { s .. e, display });
                table.insert(mantra_patterns, { e .. s, display });
                table.insert(mantra_patterns, { compact, display });
            end;
        end;
        -- Longest needle first so the most specific match wins.
        table.sort(mantra_patterns, function(a, b) return #a[1] > #b[1] end);
    end;
end;

-- Matched against the *start* of each path segment / name word, so "controllers"
-- doesn't count as "roll" etc.
local NON_ATTACK_WORDS = {
    "mantra", "spell", "movement", "emote", "gesture", "idle", "climb", "swim",
    "carry", "walk", "sprint", "crouch", "ragdoll", "knocked", "parried", "blocking",
    "roll", "wallrun", "vault", "execute", "eruption", "cast",
};

local function describe(track, path)
    local raw = { path or "" };
    local anim = track and track.Animation;
    if anim then
        table.insert(raw, anim.Name);
        -- Only use the full location when it's game assets; otherwise just the
        -- parent's name (e.g. the mantra tool) so player names never get matched.
        local ok, full = pcall(anim.GetFullName, anim);
        if ok and full:find("^ReplicatedStorage") then
            table.insert(raw, full);
        elseif anim.Parent and not anim.Parent:IsA("Model") then
            table.insert(raw, anim.Parent.Name);
        end;
    end;

    local text = table.concat(raw, " ");
    local tokens = {};
    for word in text:gmatch("[^%s_%-%.:/{}]+") do
        table.insert(tokens, word:lower());
    end;
    return table.concat(tokens), tokens;
end

local function identify_mantra(joined)
    for _, p in mantra_patterns do
        if #p[1] >= 6 and joined:find(p[1], 1, true) then
            return p[2];
        end;
    end;
    return nil;
end

local function dodge_data(name, when, size)
    return {
        source = "apc_fallback",
        action_type = "Spell",
        name = name,
        run = function(action)
            action.when = math.max(0, when + ((aztup.flags.unparriable_dodge_offset or 0) / 1000));
            action.type = "Dodge";
            action.shape = "ball";
            action.hitbox = Vector3.new(size, size, size);
            action.name = name .. " (dodge)";
            action:push();
        end,
    };
end

-- Rain's Fire/Shadow Eruption entries: if the caster only owns Ice Eruption (so it
-- can't be the move that entry is for), swap in the Ice Eruption dodge.
local ERUPTION_OWNERS = {
    ["FireEruption"] = "Mantra:EruptionFire{{Fire Eruption}}",
    ["ShadowEruption-Generic"] = "Mantra:EruptionShadow{{Shadow Eruption}}",
};

function apc_fallback.override(entity, entry_name)
    local own = entry_name and ERUPTION_OWNERS[entry_name];
    if not own then return nil end;

    local player = game:GetService("Players"):GetPlayerFromCharacter(entity);
    local backpack = player and player:FindFirstChild("Backpack");
    if not backpack then return nil end;

    if backpack:FindFirstChild("Mantra:EruptionIce{{Ice Eruption}}") and not backpack:FindFirstChild(own) then
        local r = UNPARRIABLE["Ice Eruption"];
        return dodge_data("Ice Eruption", r.when, r.size);
    end;
    return nil;
end

--------------------------------------------------------------------------- build

-- entity: attacker. track: the AnimationTrack. path: "Folder/Sub/AnimName" under
-- ReplicatedStorage.Assets.Anims if the id is known there (else nil).
-- Returns (data, reason): data is a PR timing table or nil; reason is for debug.
function apc_fallback.build(entity, track, path)
    if aztup.flags.apc_fallback_enabled == false then
        return nil, "APC fallback off";
    end;

    local joined, tokens = describe(track, path);

    local mantra = identify_mantra(joined);
    if mantra then
        local rule = UNPARRIABLE[mantra];
        if rule then
            return dodge_data(mantra, rule.when, rule.size);
        end;

        local mode = aztup_options and aztup_options.unknown_mantra_mode and aztup_options.unknown_mantra_mode.Value;
        if mode == "Dodge" then
            return dodge_data(mantra, (aztup.flags.unknown_mantra_dodge_delay or 450) / 1000, aztup.flags.unknown_mantra_range or 40);
        end;
        return nil, "untimed mantra: " .. mantra;
    end;

    -- Generic "eruption" anim with no element in its name: if the caster's only
    -- eruption mantra is Ice Eruption, it's that.
    if joined:find("eruption", 1, true) then
        local player = game:GetService("Players"):GetPlayerFromCharacter(entity);
        local backpack = player and player:FindFirstChild("Backpack");
        if backpack and backpack:FindFirstChild("Mantra:EruptionIce{{Ice Eruption}}") then
            local others = 0;
            for _, tool in backpack:GetChildren() do
                if tool.Name:find("^Mantra:Eruption") and tool.Name ~= "Mantra:EruptionIce{{Ice Eruption}}" then
                    others += 1;
                end;
            end;
            if others == 0 then
                local r = UNPARRIABLE["Ice Eruption"];
                return dodge_data("Ice Eruption", r.when, r.size);
            end;
        end;
    end;

    for _, token in tokens do
        for _, word in NON_ATTACK_WORDS do
            if token:sub(1, #word) == word then
                return nil, "not an attack (" .. token .. ")";
            end;
        end;
    end;

    local w = weapon.data(entity);
    if not w or not w.type then
        return nil, "no weapon";
    end;

    return {
        source = "apc_fallback",
        action_type = "M1",
        name = "APC " .. w.type,
        run = function(action)
            -- `track` and `weapon` are injected as globals by animator-handler.lua's
            -- setfenv before this runs, same as every other data.run entry in base.lua.
            local w = weapon or {};
            local speed = track.Speed;
            if not speed or speed == 0 then
                return;
            end;

            local windup;
            if w.type == "Greataxe" and speed ~= 1.0 then
                windup = (0.171 / speed) + 0.120;
            elseif w.type == "Greataxe" then
                windup = (0.171 / speed) + (0.250 / (w.ss or 1));
            elseif w.type == "Greathammer" and speed ~= 1.0 then
                windup = (0.150 / speed) + 0.200;
            elseif w.type == "Greathammer" then
                windup = (0.150 / speed) + (0.250 / (w.ss or 1));
            elseif w.type == "Greatcannon" and speed ~= 1.0 then
                windup = (0.155 / speed) + 0.160;
            elseif w.type == "Greatcannon" then
                windup = (0.155 / speed) + 0.300;
            elseif w.type == "Rapier" then
                windup = (0.155 / speed) + 0.120;
            elseif w.type == "Rifle" then
                windup = (0.174 / speed) + 0.125;
            elseif w.type == "Club" then
                windup = (0.180 / speed) + 0.100;
            elseif w.type == "Twinblade" then
                windup = (0.200 / speed) + 0.050;
            elseif w.type == "Spear" then
                windup = (0.150 / speed) + 0.100;
            elseif w.type == "Greatsword" then
                windup = (0.158 / speed) + 0.150;
            elseif w.type == "Fist" then
                windup = (0.140 / speed) + 0.130;
            elseif w.type == "Dagger" then
                windup = (0.200 / speed) + 0.075;
            elseif w.type == "Staff" then
                windup = 0.350;
            elseif w.type == "Sword" then
                windup = (0.200 / speed) + 0.100;
            elseif w.type == "Bow" then
                windup = 0.1;
            elseif w.type == "Pistol" then
                windup = 0.350 / (w.ss or 1);
            end;

            if not windup or windup ~= windup or windup == math.huge then
                return;
            end;

            windup = math.max(0, windup + ((aztup.flags.apc_timing_offset or 0) / 1000));

            local length = w.length or 4;
            action.when = windup;
            action.type = "Parry";
            action.hitbox = Vector3.new(length * 2.1, length * 2.1, length * 2.1);
            action:push();
        end,
    };
end

return apc_fallback;
