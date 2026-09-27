local sprint_keys, started_sprint, feature = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D
}, nil, nil;

-- The game's own sprint function lives in InputClient's StopSprint handler env.
-- Cached per StopSprint remote (it changes on respawn).
local cached_remote, cached_sprint_func, cached_stop_handler;
local function get_sprint_funcs()
    local character = local_player.character;
    local character_handler = character and character:FindFirstChild("CharacterHandler");
    local requests = character_handler and character_handler:FindFirstChild("Requests");
    local stop_sprint = requests and requests:FindFirstChild("StopSprint");
    if not stop_sprint then return nil end

    if stop_sprint == cached_remote and cached_sprint_func then
        return cached_sprint_func, cached_stop_handler
    end;

    for _, connection in getconnections(stop_sprint.OnClientEvent) do
        local func = connection.Function;
        if not func or not debug.getinfo(func).source:find("InputClient") then continue end

        local sprint_func = getfenv(func).Sprint;
        if sprint_func then
            cached_remote, cached_sprint_func, cached_stop_handler = stop_sprint, sprint_func, func;
            return sprint_func, func
        end;
    end;

    return nil
end

feature = Feature:new("auto_sprint", services.UserInputService.InputBegan, LPH_NO_VIRTUALIZE(function(input: InputObject, gp: boolean)
    if gp or not table.find(sprint_keys, input.KeyCode) or started_sprint then return end

    started_sprint = true;

    task.delay(aztup.flags.auto_sprint_delay, function()
        if not started_sprint then return end

        local sprint_func = get_sprint_funcs();
        if not sprint_func then return end

        while local_player.humanoid.MoveDirection.Magnitude >= 0.1 do
            -- Vanta: No Running Attacks pauses auto sprint for a moment after each M1.
            if tick() >= (feature.resume_at or 0)
                and not EffectReplicator:FindEffect("Sprinting")
                and not EffectReplicator:FindEffect("ClientCrouch")
            then
                sprint_func(true);
            end;

            task.wait();
        end;
    end);

    local move_direction_conn;
    move_direction_conn = local_player.humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        if local_player.humanoid.MoveDirection.Magnitude <= 0.1 then
            started_sprint = false;
            move_direction_conn:Disconnect();
            return
end
    end);
end))

--[[
    Vanta: No Running Attacks (Automation -> Options).

    Used by the LeftClick hook in features/hooking.lua. When you M1 while sprinting:
      1. sprint is stopped and the click is held back,
      2. the click is sent once the game confirms you're not sprinting
         -> it registers as a normal M1, not a running attack,
      3. as soon as the M1 has started, sprint is turned straight back on, so you
         keep your speed during the swing.
    Works whether the sprint came from auto sprint or from you.
]]
feature.resume_at = 0;
feature.m1_pending = false;

-- Hold auto sprint off while an M1 is being converted (safety cap: 1s).
function feature.hold_sprint()
    feature.resume_at = tick() + 1;
end

function feature.resume_sprinting()
    feature.resume_at = 0;

    local humanoid = local_player.humanoid;
    if not humanoid or humanoid.MoveDirection.Magnitude < 0.1 then return end;
    if EffectReplicator:FindEffect("Sprinting") or EffectReplicator:FindEffect("ClientCrouch") then return end;

    local sprint_func = get_sprint_funcs();
    if sprint_func then
        pcall(sprint_func, true);
    end;
end

function feature.stop_sprinting()
    feature.hold_sprint();

    local sprint_func, stop_handler = get_sprint_funcs();
    if sprint_func then
        pcall(sprint_func, false);
    end;

    -- If Sprint(false) didn't do it, run the game's own StopSprint handler.
    task.delay(1 / 30, function()
        if stop_handler and EffectReplicator:FindEffect("Sprinting") then
            pcall(stop_handler);
        end;
    end);
end

return feature
