--[[
    apc_fallback.lua

    Generic per-weapon-type Auto Parry timing, ported from APC (Lycoris Rewrite)'s
    WeaponTest.lua windup formulas.

    Project Rain's own data/base.lua only covers named, per-exact-animation-ID moves
    (mantras, spells, bosses - 129 hardcoded entries). Ordinary weapon M1 swings aren't
    in there at all (that table was the "Timings" data Rain stripped from the OSS
    release). This module is what actually "imports APC timings into Project Rain":
    when animator-handler.lua can't find an exact-ID match, it calls apc_fallback.build()
    instead of giving up, and gets back a normal PR timing-data table (with a `run`
    function) built from APC's live track.Speed + weapon.type formulas.

    Ported 1:1 from APC's WeaponTest.lua where the formula is a plain function of
    (track.Speed, weapon.ss). Not ported (on purpose, see README/notes to the user):
      - APC's own hitbox/prediction/blockfollow tuning (timing.pbfb, timing.htype,
        timing.pfht, etc.) - those are knobs on APC's *own* defender engine and have
        no equivalent field on PR's action/hitbox contract.
      - The busy-wait sub-branches (Pistol "Shot", Rifle "2", Bow spark-wait) that block
        on task.wait() until track.Speed changes or a part appears. PR calls `data.run`
        synchronously off the animation-played hot path with a task concurrency limiter;
        blocking there for multiple frames per enemy is a real stall risk, so those
        variants fall back to the plain per-type formula instead of the exact sub-case.
      - The Evengarde / Titus boss-specific special-cased loops (self:action spam,
        M1-windup-only-once-per-4s guards) - narrow boss workarounds, not general timings.
    All of the above are individually portable later if they turn out to matter; they
    were deliberately left out for now since "other stuff is less important" per the
    brief - this file is only the generic per-weapon windup.
]]

local weapon = require("@src/features/auto-parry/data/weapon");

local apc_fallback = {};

-- entity: the Character whose weapon/track we're evaluating.
-- Returns a PR-shaped timing `data` table (see data/base.lua for the shape), or nil if
-- APC has no formula for this entity's current weapon (no weapon equipped, or a type
-- APC itself doesn't cover, e.g. thrown/unarmed edge cases).
function apc_fallback.build(entity)
    local w = weapon.data(entity);
    if not w or not w.type then
        return nil;
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

            local length = w.length or 4;
            action.when = windup;
            action.type = "Parry";
            action.hitbox = Vector3.new(length * 2.1, length * 2.1, length * 2.1);
            action:push();
        end,
    };
end

return apc_fallback;
