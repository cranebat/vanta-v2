local Signal = require("@src/utility/signal");
local Keybinds = base_require(game:GetService("ReplicatedStorage"):WaitForChild("KeyBinds"));

local DefendActionManager = {} do
    DefendActionManager.actions_to_play_through = {};
    DefendActionManager.currently_handling = {};
    DefendActionManager.on_update = Signal.new();
    DefendActionManager.block = {}
    DefendActionManager.unblock = {}

    local sent_actions = 0;
    function DefendActionManager.block:FireServer()
        sent_actions += 1;
        task.delay(1, function()
            sent_actions -= 1;
        end);

        if sent_actions >= 75 then
            return        
end

        local remote = KeyHandler:get_cache("Block");

        if remote and not remote:IsDescendantOf(local_player.character) then
            remote = nil
        end
        
        if not remote then
            remote = KeyHandler:get_key("Block")
        end
        
        if not remote then return end 
        remote:FireServer()
    end

    function DefendActionManager.unblock:FireServer()
        sent_actions += 1;
        task.delay(1, function()
            sent_actions -= 1;
        end);

        if sent_actions >= 75 then
            return        
end

        local remote = KeyHandler:get_cache("Unblock");

        if remote and not remote:IsDescendantOf(local_player.character) then
            remote = nil
        end
        
        if not remote then
            remote = KeyHandler:get_key("Unblock")
        end
        
        if not remote then return end 
        remote:FireServer()
    end

    function DefendActionManager:add_action(mob, action_type, when, seq_tag_or_other)
        self._action_seq_counter = (self._action_seq_counter or 0) + 1

        table.insert(self.actions_to_play_through, {
            mob = mob,
            type = action_type,
            when = when,
            seq = seq_tag_or_other,  
            other = seq_tag_or_other, 
            _action_id = self._action_seq_counter,
        });

        self.on_update:fire();

        -- Vanta: if it's due now, handle it this frame instead of waiting for the
        -- next Heartbeat (that added 0-1 frame of random delay to every parry/dodge).
        -- Deferred rather than called inline so update() is never re-entered while
        -- it's walking the queue.
        if when <= tick() and sent_actions < 75 and self.update then
            task.defer(function()
                if sent_actions < 75 then
                    self:update();
                end;
            end);
        end;
    end;

    function DefendActionManager:wrap_add_action(type)
        return function(_, mob, delay)
            self:add_action(mob, type, tick() + delay);
        end    
end;

    DefendActionManager.queue_block_task = DefendActionManager:wrap_add_action("block");
    DefendActionManager.queue_unblock_task = function(self, mob, delay, seq)
        
        if seq then
            for i = #self.actions_to_play_through, 1, -1 do
                local v = self.actions_to_play_through[i]
                if v.type == "unblock" and (v.seq == seq or v.other == seq) then
                    
                    local new_when = tick() + delay;
                    if new_when > v.when then
                        v.when = new_when;
                    end
                    return                
end
            end;
        end

        self:add_action(mob, "unblock", tick() + delay, seq);
    end;

    local random = Random.new();
    function DefendActionManager:queue_generic_parry_task_no_convert(mob)
        self._current_parry_seq = (self._current_parry_seq or 0) + 1
        local seq = self._current_parry_seq

        self:add_action(mob, "block", tick(), seq);
        self:add_action(mob, "unblock", tick() + 0.1, seq);
    end;
    
    function DefendActionManager:queue_generic_parry_task(mob, t)
        self._current_parry_seq = (self._current_parry_seq or 0) + 1
        local seq = self._current_parry_seq

        self:add_action(mob, "block", tick(), seq);
        self:add_action(mob, "unblock", tick() + (t or 0.1), seq);
    end;

    function DefendActionManager:queue_generic_dodge_task(mob)
        self:add_action(mob, "dodge", tick());
    end;

    
    local fallback_manager = require("@src/features/auto-parry/fallbacks/manager");

    local chance_fail_action_order = { "Parry", "Dodge", "Skip" }
    local chance_fail_action_lookup = {
        ["Parry"] = true,
        ["Dodge"] = true,
        ["Skip"] = true,
    }

    function DefendActionManager:normalize_chance_fail_weights(actions_or_weights)
        local weights = {}

        if typeof(actions_or_weights) == "string" then
            if chance_fail_action_lookup[actions_or_weights] then
                weights[actions_or_weights] = 100
            end
        elseif typeof(actions_or_weights) == "table" then
            if #actions_or_weights > 0 then
                for _, action in ipairs(actions_or_weights) do
                    if chance_fail_action_lookup[action] then
                        weights[action] = (weights[action] or 0) + 1
                    end
                end
            else
                for action, amount in pairs(actions_or_weights) do
                    if not chance_fail_action_lookup[action] then
                        continue
                    end

                    if typeof(amount) == "number" then
                        weights[action] = math.max(0, amount)
                    elseif amount then
                        weights[action] = 1
                    end
                end
            end
        end

        local total = 0
        for _, action in ipairs(chance_fail_action_order) do
            total += weights[action] or 0
        end

        if total <= 0 then
            weights = { Skip = 100 }
        end

        return weights
    end

    function DefendActionManager:roll_chance_fail_action(weights)
        local total = 0
        for _, action in ipairs(chance_fail_action_order) do
            total += weights[action] or 0
        end

        if total <= 0 then
            return "Skip"
        end

        local rolled = math.random() * total
        local running = 0

        for _, action in ipairs(chance_fail_action_order) do
            local amount = weights[action] or 0
            if amount > 0 then
                running += amount
                if rolled <= running then
                    return action
                end
            end
        end

        return "Skip"
    end

    function DefendActionManager:execute_failed_parry_variation(mob, actions_or_weights)
        local weights = self:normalize_chance_fail_weights(actions_or_weights)
        local chosen = self:roll_chance_fail_action(weights)

        return chosen or "Skip"
    end

    -- Vanta: Walk Forward On Back Dodge. A roll with no movement input (or while
    -- moving backwards) is a back roll; holding W for a moment once the roll has
    -- started keeps you roughly where you were, like a player stepping back in.
    local VirtualInputManager = game:GetService("VirtualInputManager");
    local function is_back_roll()
        local humanoid, root = local_player.humanoid, local_player.root_part;
        if not humanoid or not root then return false end;
        local move = humanoid.MoveDirection;
        return move.Magnitude < 0.1 or move.Unit:Dot(root.CFrame.LookVector) < -0.5
    end

    local function walk_forward_after_roll(was_back_roll)
        if not was_back_roll or not aztup.flags.back_dodge_walk_forward then return end;
        if math.random() * 100 >= (aztup.flags.back_dodge_walk_chance or 100) then return end;

        local UIS = services.UserInputService;
        if UIS:IsKeyDown(Enum.KeyCode.W) then return end; -- you're already walking forward

        local delay_s = (aztup.flags.back_dodge_walk_delay or 60) / 1000;
        local duration = (aztup.flags.back_dodge_walk_duration or 350) / 1000;

        -- Don't let auto sprint turn the fake W press into a sprint.
        local sprint = aztup.features and aztup.features.auto_sprint;
        if sprint and sprint.resume_at then
            sprint.resume_at = math.max(sprint.resume_at, tick() + delay_s + duration + 0.15);
        end;

        task.spawn(function()
            task.wait(delay_s);
            if UIS:IsKeyDown(Enum.KeyCode.W) then return end;

            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game);
            task.wait(duration);
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game);
        end);
    end

    LPH_NO_VIRTUALIZE(function()
        function DefendActionManager:defend_action_block(action, dont_pass)
        
            if aztup.flags.ap_randomization then
                if math.random() < aztup.flags.parry_to_fallback_chance / 100 then
                    if fallback_manager:execute() then
                        return                    
end;
                end
            end
        
            if not dont_pass then
                if not local_player.tracker:can_parry() then
                    local should_return = false;
                
                    if local_player.tracker:can_dodge() then
                        should_return = true;
                        return self:defend_action_dodge(action)                    
else
                        if fallback_manager:execute() then
                            should_return = true;
                        end;
                    end
                
                    if should_return or not aztup_options.fallbacks.Value.Block then  
                        local seq = action.seq
                        if seq then
                            for j = #self.actions_to_play_through, 1, -1 do
                                local other = self.actions_to_play_through[j]
                                if other.type == "unblock" and other.other == seq then
                                    table.remove(self.actions_to_play_through, j)
                                end;
                            end;
                        end
                        return                    
elseif aztup_options.fallbacks.Value.Block then
                        if aztup.flags.auto_parry_debug then
                            setthreadidentity(8);
                            Logger:short_notify("[AP] Forced to block fallback.")
                        end
                    end;
                end;
            end
        
            if getgenv().block_call then 
                getgenv().block_call(true)
            end;
        
            return self.block:FireServer()
        end;
    
    
        function DefendActionManager:defend_action_dodge(action)
            local type = action.mob.Name:sub(1, 1) == "." and "pve_" or "pvp_"
            local back_roll = is_back_roll();
            if aztup.flags[type .. "blatant_roll"] and not action.full then
                KeyHandler:get_key("Dodge"):FireServer("roll", nil, nil, false);
                walk_forward_after_roll(back_roll);
            
                if aztup.flags[type .. "blatant_roll_with_anims"] then
                    task.spawn(function() 
                        
                        local l_Movement_0 = game:GetService("ReplicatedStorage").Assets.Anims.Movement;
                        local l_ForwardRoll_0 = l_Movement_0.Roll.ForwardRoll;
                        local l_BackRoll_0 = l_Movement_0.Roll.BackRoll;
                        local l_RightRoll_0 = l_Movement_0.Roll.RightRoll;
                        local l_LeftRoll_0 = l_Movement_0.Roll.LeftRoll;
                        
                        local l_LookVector_0 = local_player.root_part.CFrame.LookVector;
                        local l_MoveDirection_1 = local_player.humanoid.MoveDirection;
                        if l_MoveDirection_1.Magnitude < 0.1 then
                            l_MoveDirection_1 = -l_LookVector_0;
                        end;
                        local v224;
                        local v227 = math.deg((math.acos((math.clamp(l_MoveDirection_1:Dot(l_LookVector_0), -1, 1)))));
                        local v228 = nil;
                        if v227 <= 45 then
                            v224 = l_ForwardRoll_0;
                        elseif v227 > 45 and v227 < 135 then
                            v228 = math.deg((math.acos((math.clamp(l_MoveDirection_1:Dot((Vector3.new(-l_LookVector_0.z, 0, l_LookVector_0.x))), -1, 1)))));
                            v224 = if v228 <= 45 then l_RightRoll_0 else if v228 > 135 then l_LeftRoll_0 else l_BackRoll_0;
                        else
                            v224 = l_BackRoll_0;
                        end;
                        local l_ForwardWaterDash_0 = l_Movement_0.WaterDash.ForwardWaterDash;
                        local l_BackWaterDash_0 = l_Movement_0.WaterDash.BackWaterDash;
                        local l_RightWaterDash_0 = l_Movement_0.WaterDash.RightWaterDash;
                        local l_LeftWaterDash_0 = l_Movement_0.WaterDash.LeftWaterDash;
                        local v86 = {
                            [l_ForwardRoll_0] = l_ForwardWaterDash_0, 
                            [l_BackRoll_0] = l_BackWaterDash_0, 
                            [l_RightRoll_0] = l_RightWaterDash_0, 
                            [l_LeftRoll_0] = l_LeftWaterDash_0
                        };
                        
                        local anim = EffectReplicator:FindEffect("ClientSwim") and v86[v224] or v224;
                        
                        local first_roll_track = local_player.humanoid:LoadAnimation(anim);
                        first_roll_track:Play(0.1, 1, 1);
                        task.wait()
                        first_roll_track:Stop(0.1);
                        
                        local v68 = local_player.humanoid:LoadAnimation(l_Movement_0.Roll.CancelRight);
                        v68:Play();
                    end)
                end
            
                return task.delay(.15, function()
                    KeyHandler:get_key("StopDodge"):FireServer({
                        W = false,
                        Right = true,
                        S = false,
                        NOAERIALS = false
                    }, EffectReplicator:HasEffect("LightAttack"))
                end)            
end;
        
            local roll_cancel = aztup.flags[type .. "roll_cancel"];
        
            if getgenv().requesting_dodge then 
                getgenv().requesting_dodge()
            end;
        
            Keybinds.ForceActionDown("Dodge")
            Keybinds.ForceActionUp("Dodge")
            walk_forward_after_roll(back_roll);
        
            if roll_cancel and aztup.flags[type .. "roll_cancel_chance"] > (math.random() * 100) and not action.full then
                task.wait(math.random(aztup.flags[type .. "min_roll_cancel_delay"], aztup.flags[type .. "max_roll_cancel_delay"] >= aztup.flags[type .. "min_roll_cancel_delay"] and aztup.flags[type .. "max_roll_cancel_delay"] or aztup.flags[type .. "min_roll_cancel_delay"]) / 1000)
                
                local client_feint = EffectReplicator:CreateEffect("ClientFeint");
                
                if client_feint then
                    client_feint:Debris(0.1);
                end;
            end
        
            return        
end;
    
    
        function DefendActionManager:defend_action_unblock()
            self.unblock:FireServer()
            
            if getgenv().block_call then 
                task.delay(math.random(1, 5) / 100, function()
                    getgenv().block_call(false)
                end)
            end;

            task.spawn(function() 
                local start = tick();
                while (tick() - start <= 0.05 or EffectReplicator:FindEffect("Blocking")) and task.wait() do
                    self.unblock:FireServer();
                end
            end)
        end;
    end)();

    function DefendActionManager:update() 
        LPH_NO_VIRTUALIZE(function()
            self._block_count = self._block_count or 0
            self._dodge_until = self._dodge_until or 0
            self._block_started_at = self._block_started_at or 0

            -- Vanta: used to wipe the WHOLE queue once it held more than 5 entries,
            -- which dropped real parries when several enemies attacked at once. Now
            -- only entries more than 1s overdue are dropped, plus a hard cap.
            do
                local now = tick();
                local queue = self.actions_to_play_through;
                for i = #queue, 1, -1 do
                    local v = queue[i];
                    if v.when < now - 1 and not self.currently_handling[v] then
                        table.remove(queue, i);
                    end;
                end;
                while #queue > 40 do
                    table.remove(queue, 1);
                end;
            end

            -- Vanta: Block Overrides Auto Parry. While you're holding block yourself,
            -- every queued parry / dodge / block / unblock is dropped - no matter what
            -- triggered it (animations, effects, projectiles, reactions). Unblocks are
            -- dropped too so the script never releases your block.
            if aztup.flags.block_overrides_ap ~= false and general:raw_is_holding_f() then
                if #self.actions_to_play_through > 0 then
                    table.clear(self.actions_to_play_through);
                    if aztup.flags.auto_parry_debug then
                        setthreadidentity(8);
                        Logger:short_notify("[AP] Holding block - skipped.");
                    end;
                end;
                self._block_count = 0;
                self._block_started_at = 0;
                return;
            end

            if self._block_count > 0 then
                local has_pending_unblock = false
                for i = #self.actions_to_play_through, 1, -1 do
                    if self.actions_to_play_through[i].type == "unblock" then
                        has_pending_unblock = true
                        break
                    end
                end

                
                if self._block_started_at == 0 then
                    self._block_started_at = tick()
                end

                
                if (not has_pending_unblock) and (tick() - self._block_started_at > 0.25) then
                    self._block_count = 0
                    self._block_started_at = 0
                    self:defend_action_unblock()
                end
            else
                self._block_started_at = 0

                
                
                
                
                
                if EffectReplicator:FindEffect("Blocking") and not self._stray_block_unblocking and not general:raw_is_holding_f() then
                    self._stray_block_unblocking = true

                    if getgenv().block_call then
                        getgenv().block_call(false)
                    end;

                    task.spawn(function()
                        while EffectReplicator:FindEffect("Blocking") and not general:raw_is_holding_f() and task.wait() do
                            self.unblock:FireServer();
                        end
                        self._stray_block_unblocking = false
                    end)
                end
            end

            
            
            local to_process = {};
            local to_remove = {};

            for i = #self.actions_to_play_through, 1, -1 do 
                local v = self.actions_to_play_through[i]

                if tick() >= v.when and not self.currently_handling[v] then
                    local mob = v.mob
                    local allowed_targets = aztup_options.allowed_targets.Value;

                    local filtered = false;
                    if not mob then
                        if not allowed_targets.Unknown and not allowed_targets.All then
                            filtered = true;
                        end;
                    else
                        if not allowed_targets.PVP and services.Players:GetPlayerFromCharacter(mob) and not allowed_targets.All then
                            filtered = true;
                        end;
                    
                        if not allowed_targets.PVE and mob.Name:sub(1,1) == "." and not allowed_targets.All then
                            filtered = true;
                        end;
                    end;

                    if filtered then
                        
                        if v.type == "block" and v.seq then
                            for j = #self.actions_to_play_through, 1, -1 do
                                local other = self.actions_to_play_through[j]
                                if other.type == "unblock" and (other.seq == v.seq or other.other == v.seq) then
                                    table.remove(self.actions_to_play_through, j)
                                    if j < i then i = i - 1 end
                                end
                            end
                        end
                        table.remove(self.actions_to_play_through, i)
                        continue
                    end
                
                    local typ = v.type

                    if typ == "dodge" and (self._block_count or 0) > 0 then
                        table.remove(self.actions_to_play_through, i)
                        continue
                    end

                    if typ == "block" and tick() < self._dodge_until then
                        local delta = self._dodge_until - tick()
                        v.when = self._dodge_until

                        
                        if v.seq then
                            for j = #self.actions_to_play_through, 1, -1 do
                                local other = self.actions_to_play_through[j]
                                if other.type == "unblock" and (other.seq == v.seq or other.other == v.seq) then
                                    other.when = other.when + delta;
                                end
                            end;
                        end
                        continue
                    end

                    self.currently_handling[v] = true
                    table.remove(self.actions_to_play_through, i)

                    task.spawn(function()
                        if typ == "block" then
                            self._block_count = math.max(0, (self._block_count or 0) + 1)
                            if self._block_count == 1 then
                                self._block_started_at = tick()
                                self:defend_action_block(v, v.other)
                            end
                        elseif typ == "unblock" then    
                            if (self._block_count or 0) > 0 then
                                self._block_count = math.max(0, (self._block_count or 0) - 1)
                                if self._block_count == 0 then
                                    self._block_started_at = 0
                                    self:defend_action_unblock(v)
                                end
                            end
                        elseif typ == "dodge" then
                            self._dodge_until = tick() + 0.1;
                            self:defend_action_dodge(v)
                        end

                        self.currently_handling[v] = nil
                    end)

                    if typ == "block" or typ == "dodge" then
                        break                    
end;
                end
            end
        end)();
    end;

    local last = tick();
    LPH_NO_VIRTUALIZE(function()
        
        
        
        

        
        
        

        aztup.maid:give_task(services.RunService.Heartbeat:Connect(function()
            if tick() - last < 1 / 30 then
                return            
end

            if sent_actions >= 75 then
                return            
end
            
            DefendActionManager:update();
        end));
    end)();
end;

return DefendActionManager