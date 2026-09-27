local anti_ap_breaker = {}

local dead_tracks = setmetatable({}, { __mode = "k" })
local track_seen_at = setmetatable({}, { __mode = "k" })
local priority_cache = {};
local recent_plays = {}; -- "entity|animId" -> tick() of last play (Duplicate Spam)

-- Keep recent_plays small.
task.spawn(function()
    while task.wait(10) do
        local now = tick();
        for key, t in recent_plays do
            if now - t > 5 then recent_plays[key] = nil end;
        end;
    end;
end);

function anti_ap_breaker:on()
    return aztup.flags.basic_validation
end

function anti_ap_breaker:compatibility()
    return aztup.flags.compatibility_mode_anti_ap_breaker
end

function anti_ap_breaker:is_filter_on(flag)
    return aztup_options.validation_filters.Value[flag]
end;

function anti_ap_breaker:is_filter_log_on(flag)
    return aztup_options.validation_log_filters.Value[flag]
end;

function anti_ap_breaker:log(type, ...)
    
    if not aztup.flags.anti_ap_breaker_debug then return end
    if not self:is_filter_log_on(type) then return end

    setthreadidentity(8)
    Logger:short_notify("[Anti AP]", string.format(...))
end

--[[
    Vanta: Flash Immunity (always on while Anti AP Breaker is on).

    "Flash" breakers (including Vanta's own, see animator-handler flash_break) make a
    real attack look fake for the first ~100ms - Core/Idle priority, or a huge speed -
    because the stock checks above only look once, right as the animation starts.
    Instead of rejecting straight away, we wait (max 400ms - longer than the longest
    Vanta Flash) for the animation to
    settle and judge it on how it looks after that. The time waited is taken off the
    parry timing, so the parry still lands on time.

    Only animations that fail one of these start checks are ever delayed; everything
    else goes through exactly as before. An animation that stays Core/fast the whole
    time is still rejected, just up to 400ms later.

    If the flash was a speed boost, the attacker's animation may have jumped ahead
    and so end early on our side; we keep treating it as playing until it would
    have naturally ended, so the parry isn't cancelled as "ended early".
]]
local settled_tracks = setmetatable({}, { __mode = "k" });
local expected_end = setmetatable({}, { __mode = "k" });

function anti_ap_breaker:still_expected(track)
    local t = expected_end[track];
    return t ~= nil and tick() < t
end

function anti_ap_breaker:flash_reason(track)
    if self:is_filter_on("S >= X (S = Speed)") and track.Speed >= aztup.flags.anti_ap_breaker_max_speed then
        return "speed"
    end;
    -- Length 0 = animation not loaded yet; leave that to initial_check (unchanged).
    if self:is_filter_on("Length <= Xms") and track.Speed > 0 and track.Length > 0 and track.Length / track.Speed <= (aztup.flags.anti_ap_breaker_length_ms / 1000) then
        return "length"
    end;
    if self:is_filter_on("Core Priority") and track.Priority == Enum.AnimationPriority.Core then
        return "core priority"
    end;
    if self:is_filter_on("Idle Priority") and track.Priority == Enum.AnimationPriority.Idle then
        return "idle priority"
    end;
    return nil
end

-- Returns how many seconds were spent waiting (0 = no wait, the normal case).
function anti_ap_breaker:settle(defender, track)
    if not defender.is_player or not self:on() then
        return 0
    end;

    local reason = self:flash_reason(track);
    if not reason then
        return 0
    end;

    local started = tick();
    while track.IsPlaying and self:flash_reason(track) and tick() - started < 0.4 do
        task.wait();
    end;

    local waited = tick() - started;
    if not self:flash_reason(track) then
        settled_tracks[track] = true;
        if (reason == "speed" or reason == "length") and track.Speed > 0 and track.Length > 0 then
            expected_end[track] = started + track.Length / track.Speed;
        end;
        self:log("Flash Breaker", "Flash breaker settled (%s) after %dms - treating as real", reason, math.floor(waited * 1000));
    end;
    return waited
end

function anti_ap_breaker:initial_check(defender, track)
    if not defender.is_player or not self:on() then
        return false    
end

    
    if track.Speed >= aztup.flags.anti_ap_breaker_max_speed and self:is_filter_on("S >= X (S = Speed)") then
        self:log("S >= X (S = Speed)", "Speed is too high, Speed: %.1f", track.Speed)
        return true
    end;

    if track.Length / track.Speed <= (aztup.flags.anti_ap_breaker_length_ms / 1000) and self:is_filter_on("Length <= Xms") then
        self:log("Length <= Xms", "Length is too short, Length: %.1f", track.Length)
        return true
    end;

    if track.Priority == Enum.AnimationPriority.Core and self:is_filter_on("Core Priority") then
        self:log("Core Priority", "Track is core priority")
        return true
    end;

    if track.Priority == Enum.AnimationPriority.Idle and self:is_filter_on("Idle Priority") then
        self:log("Idle Priority", "Track is idle priority")
        return true
    end;

    if track.Speed == 0 and self:is_filter_on("Speed == 0") then
        return self:log("Speed == 0", "Track is frozen")
end

    -- Vanta: Late Start. Already 85%+ through when first seen - a real attack can't
    -- still land from there; breakers play tracks from the end.
    if self:is_filter_on("Late Start") and not settled_tracks[track] and track.Length > 0 and track.TimePosition / track.Length >= 0.85 then
        self:log("Late Start", "Track started %d%% through", math.floor(track.TimePosition / track.Length * 100))
        return true
    end;

    -- Vanta: Duplicate Spam. Same animation from the same player replayed within
    -- 150ms - no real attack repeats that fast. The first one is still handled.
    if self:is_filter_on("Duplicate Spam") then
        local key = tostring(defender.entity) .. "|" .. tostring(track.Animation and track.Animation.AnimationId);
        local now = tick();
        local last = recent_plays[key];
        recent_plays[key] = now;
        if last and now - last < 0.15 then
            self:log("Duplicate Spam", "Same anim replayed after %dms", math.floor((now - last) * 1000))
            return true
        end;
    end;

    track_seen_at[track] = tick();
    priority_cache[track] = track.Priority;

    task.delay(30, function()
        priority_cache[track] = nil;
    end);

    return false
end;

function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end

    return val
end;

function anti_ap_breaker:handle_fadetime(track)
    return track.WeightCurrent < clamp(clamp(track.WeightTarget / 2, 1 / 120, tick() - (track_seen_at[track] or 0)), 0, 0.2)
end;

local asset_id = require("@src/utility/asset_id")
function anti_ap_breaker:handle_priority_hiding(defender, track)
    local humanoid = defender.entity:FindFirstChild("Humanoid");
    local hidden_count = 0;
    local highest_priority = 1000;
    
    for _, other_track in humanoid:GetPlayingAnimationTracks() do
        if track == other_track then continue end
        if other_track.Priority.Value == 1000 then continue end
        if track.Priority.Value >= other_track.Priority.Value then continue end;
        if other_track.WeightCurrent <= track.WeightCurrent / 2 then continue end
        if other_track.WeightTarget <= 0.3 then continue end
        if other_track.Speed == 0 and other_track.TimePosition >= track.Length - 0.01 or other_track.TimePosition <= 0.01 then continue end;
        if not asset_id.get_id(other_track.Animation.AnimationId) then continue end
        if self:final_check(defender, other_track, true) then continue end
        hidden_count += 1;
        
        if highest_priority > other_track.Priority.Value then
            highest_priority = other_track.Priority.Value;
        end; 
    end

    return highest_priority ~= 1000 and highest_priority > track.Priority.Value
end;

function anti_ap_breaker:final_check(defender, track, skip)
    if not self:on() then
        return false    
end

    -- Vanta: Demotion Immunity. Real attacks never have their priority lowered while
    -- playing; breakers (e.g. Aggressive 3) do it so the attack looks "hidden" behind
    -- other animations or faded out. If the priority is lower than when we first saw
    -- it, it's a real attack being hidden - don't call it fake.
    local first_priority = priority_cache[track];
    if first_priority and track.Priority.Value < first_priority.Value then
        if not skip then
            self:log("Flash Breaker", "Priority was lowered mid-attack (breaker) - treating as real");
        end;
        return false
    end;
    
        
    local alive = self:is_playing(track, defender.entity);
    if alive and self:handle_fadetime(track) and self:is_filter_on("Fadetime") then 
        if not skip then
            self:log("Fadetime", "Track is faded", track.WeightCurrent)
        end;
        return true
    end;
    
    if track.WeightTarget <= (aztup.flags.anti_ap_breaker_minimum_wt / 100) and self:is_filter_on("WT <= X (WT = WeightTarget)") then 
        if track.WeightCurrent < (aztup.flags.anti_ap_breaker_minimum_wt / 100) or not alive then
            if not skip then
                self:log("WT <= X (WT = WeightTarget)", "Track is too lightweight. WT - %.2f, WC - %.2f", track.WeightTarget, track.WeightCurrent)
            end;
            return true
        end;
    end;

    if self:is_filter_on("Priority Hiding") and not skip and self:handle_priority_hiding(defender, track) then
        if not skip then
            self:log("Priority Hiding", "Track is hidden behind another anims priority.");
        end;
        return true
    end
    
    return false
end;

function anti_ap_breaker:is_fully_dead(track, entity)
    return not table.find(entity:FindFirstChild("Humanoid"):GetPlayingAnimationTracks(), track)
end;

function anti_ap_breaker:is_playing(track, entity)
    return track.IsPlaying or table.find(entity:FindFirstChild("Humanoid"):GetPlayingAnimationTracks(), track)
end;

return anti_ap_breaker