-- Vanta: Auto Parry tab.
--   Left:  Main (everyday settings), Advanced (tuning most people never touch), Other.
--   Right: Reactions, Humanize, PVE, PVP.
return function(tab)

    local autoparry_tabbox = tab:newTabbox("Auto Parry", false);
    local ap_main = autoparry_tabbox:newTab("Main");
    local advanced = autoparry_tabbox:newTab("Advanced");

    ap_main:newToggleWithKeybind("auto_parry", "Auto Parry", false, "Automatically parry/defend incoming attacks.", function(val) 
        task.delay(1, function()
            if aztup.flags.aggressive_validation and val then
                Logger:long_notify_sound("It is not recommended to keep aggressive anti ap breaker on unless you are being broken, It will heavily affect timings.")
            end;

            if val and not next(aztup_options.allowed_targets.Value) then
                Logger:long_notify_sound("Please select at least 1 allowed target for Auto Parry to work.");
            end
    
            repeat task.wait() until local_player.instance:GetAttribute("EnablePingCompensation") ~= nil;
            if not local_player.instance:GetAttribute("EnablePingCompensation") then
                Logger:long_notify_sound("For the best experience, please enable Ping Compensation in the deepwoken settings.");
            end
        end)
    end, true);

    local auto_parry_dependency_box = ap_main:newDependencyBox("auto_parry");
    auto_parry_dependency_box:newDivider();

    auto_parry_dependency_box:newToggleWithKeybind("auto_parry_debug",      "Debug Notifications", false, "Gives debug notifications.", function(val)
        if not val then return end
        if not aztup.silent_mode then return end

        messagebox("You have 'Silent Mode' enabled, You cannot use Debug Notifications with 'Silent Mode'.", "Vanta", 0) 
        aztup_toggles.auto_parry_debug:SetValue(false);
    end, false);    

    auto_parry_dependency_box:newToggle("block_overrides_ap", "Block Overrides Auto Parry", true,
        "While you're holding block yourself, Auto Parry does nothing - no parries, dodges, blocks or reactions - and never releases your block.");

    auto_parry_dependency_box:newToggleWithKeybind("ap_randomization", "Humanization", false, "Adds extra randomization to actions.", function(val) end, false);
    
    auto_parry_dependency_box:newToggleWithKeybind("auto_feint", "Auto Feint", false, "Automatically feint attacks when Auto Parry wants to parry.");
    auto_parry_dependency_box:newDivider();

    auto_parry_dependency_box:newDropdown('fallbacks', 'Fallbacks', {
        "Curse of the Unbidden",
        "Prediction",
        "Block",
        "Vent",
    },{
        "Curse of the Unbidden"
    }, true, 'Fallbacks for Auto Parry')

    auto_parry_dependency_box:newDropdown('filters', 'Filters', {
        "Dont Parry If Enemy Hit In Criticals",
        "Dont Parry If Mob Block Broken",
        "Dont Parry In Chime Countdown",
        "Dont Parry If Not Mob Target",
        "Dont Parry If Not In Combat",
        "Dont Parry If Holding Block",
        "Dont Parry If In Payback",
        "Dont Parry If Off Roblox",
        "Dont Parry If Off Screen",
        "Dont Parry If Guildmate",
        
    	"Dont Parry In AP Frames",
        "Dont Parry If Knocked",
        "Dont Parry If Typing",
        "Dont Parry If Ally",
        "Dont Roll",
    },{
        ""
    }, true, 'Filters for Auto Parry')

    auto_parry_dependency_box:newDropdown('allowed_targets', 'Allowed Targets', {
        "Unknown",
    	"PVE",
        "PVP",
        "All"
    },{
        "Unknown",
    	"PVE",
        "PVP",
        "All"
    }, true, 'Allowed targets that Auto Parry will Parry')

    local feint_chance_dependency_box, raw_feint_chance = ap_main:newDependencyBox();

    feint_chance_dependency_box:newDropdown('blocked_auto_feint_moves', 'Dont Against Types', {
        "Critical",
        "Untagged",
        "Mantra",
        "M1",
    },{}, true, "Blocked Auto Feint Types, Some moves are currently untagged or skip.");

    feint_chance_dependency_box:newDropdown('auto_feint_own_tags', 'Auto Feint Our Move Types', {
        "M1",
        "Mantra",
    },{"M1", "Mantra"}, true, "Only feint our own attack if it's one of these move types.");
    feint_chance_dependency_box:newDivider();

    feint_chance_dependency_box:newSlider("feint_chance", "Feint Chance", 100, 0, 100, 1, true, "%");

    raw_feint_chance:SetupDependencies({
        {aztup_toggles.auto_feint, true},
        {aztup_toggles.auto_parry, true}
    })

    ------------------------------------------------------------------ Advanced
    advanced:newLabel("Fine tuning. The defaults are fine for most people.", true);

    advanced:newSlider("apc_timing_offset", "M1 Timing Offset", 0, -150, 150, 0, true, "ms", nil,
        "Shift parries on player weapon M1s earlier (-) or later (+).");
    advanced:newSlider("twinblade_m1_offset", "Twinblade M1 Offset", -35, -200, 100, 0, true, "ms", nil,
        "Shift parries on ALL twinblade M1s (Death's Reverie, Scalesplitter, ...). Negative = earlier.");

    advanced:newSlider("unparriable_dodge_offset", "Unparriable Move Latency", 0, -200, 200, 0, true, "ms", nil,
        "Shift the dodge for moves you can't parry (Ice Eruption, Tornado) earlier (-) or later (+).");
    advanced:newDropdown("unknown_mantra_mode", "Untimed Mantras", { "Ignore", "Dodge" }, "Ignore", false,
        "Mantras with no timing: ignore them, or roll after the delay below if in range.");
    advanced:newSlider("unknown_mantra_dodge_delay", "Untimed Mantra Dodge Delay", 450, 100, 1500, 0, true, "ms");
    advanced:newSlider("unknown_mantra_range", "Untimed Mantra Range", 40, 10, 150, 0, true, " studs");
    advanced:newDivider();

    advanced:newSlider("feint_reaction_jitter", "Feint Reaction Jitter", 0, 0, 150, 0, true, "ms", nil,
        "Random +/- added to Feint Reaction Time each time.");
    advanced:newSlider("block_early_ms", "Block Early By", 200, 60, 500, 0, true, "ms", nil,
        "Block Instead Of Parry: how long before the hit to start holding block (too late and it becomes a parry).");
    advanced:newSlider("block_hold_ms", "Block Hold After Hit", 250, 50, 800, 0, true, "ms", nil,
        "Block Instead Of Parry: how long to keep holding block after the hit.");
    advanced:newSlider("misstime_early_ms", "Misstime Early By", 220, 150, 500, 0, true, "ms", nil,
        "Fake Misstime Parry: how long before the hit the fake parry tap happens.");
    advanced:newSlider("multi_hit_guard_duration", "Multi-Hit Guard Duration", 2500, 500, 5000, 0, true, "ms", nil,
        "Longest Multi-Hit Guard keeps defending after a failed parry (it also stops after ~0.9s without being hit).");
    advanced:newSlider("tick_guard_range", "Moving Multi-Hit Range", 15, 5, 40, 0, true, " studs", nil,
        "Moving Multi-Hit Guard: how close the attacker must get before it rolls/blocks.");
    advanced:newSlider("gun_parry_lead", "Projectile Parry Lead", 120, 0, 300, 0, true, "ms", nil,
        "Fire Gun / Wind Gun: how long before the projectile reaches you to parry (on top of your ping). Raise if you parry too late, lower if too early.");
    advanced:newSlider("back_dodge_walk_delay", "Walk Forward Delay", 60, 0, 300, 0, true, "ms", nil,
        "Walk Forward On Back Dodge: wait after the roll starts before walking forward (too early turns it into a forward roll).");
    advanced:newSlider("back_dodge_walk_duration", "Walk Forward Duration", 350, 100, 1000, 0, true, "ms", nil,
        "Walk Forward On Back Dodge: how long to walk forward for.");
    advanced:newDivider();

    advanced:newSlider("dont_process_players_over_studs", "Dont Process Players Over", 500, 1, 10000, 1, true, "s");
    advanced:newSlider("dont_process_mobs_over_studs", "Dont Process Mobs Over", 2000, 1, 10000, 1, true, "s");
    advanced:newSlider("task_concurrency", "Task Concurrency", 20, 15, 750, 0, true, " actions");
    advanced:newToggleWithKeybind("log_speed_changes", "Debug Speed Changes", false, "Gives AP debug notifs on speed changes.", nil, false);
    advanced:newToggle("apc_debug_skips", "Debug Skipped Anims", false,
        "With Debug Notifications on, also show animations Auto Parry ignored and why.");
    advanced:newDivider();

    advanced:newToggleWithKeybind("basic_validation",       "Anti AP Breaker", true, "", nil, true);
    local anti_ap_breaker, raw_anti_ap_breaker = advanced:newDependencyBox();

    raw_anti_ap_breaker:SetupDependencies({
        {aztup_toggles.basic_validation, true},
    })

    anti_ap_breaker:newToggleWithKeybind("aggressive_validation",       "More Aggressive Checks", false, "", nil, true);
    anti_ap_breaker:newToggle("anti_ap_breaker_debug",       "Validation Notifications", false, "", nil, false);
    anti_ap_breaker:newToggleWithKeybind("reveal_animations",       "Reveal Animations", true, "", nil, true);

    anti_ap_breaker:newDropdown('validation_filters', 'Validation Filters', {
        "WT <= X (WT = WeightTarget)",
        "S >= X (S = Speed)",
        "Priority Hiding",
        "Core Priority",
        "Idle Priority",
        "Length <= Xms",
        "Fadetime",
        "Late Start",
        "Duplicate Spam",
    },{
        "WT <= X (WT = WeightTarget)",
        "Core Priority",
        "Idle Priority",
        "Priority Hiding",
        "S >= X (S = Speed)",
        "Fadetime"
    }, true, 'Filters for AP breaker. Late Start: skips anims first seen 85%+ finished. Duplicate Spam: ignores the same anim replayed within 150ms by the same player.')

    anti_ap_breaker:newDropdown('validation_log_filters', 'Validation Log Filters', {
        "WT <= X (WT = WeightTarget)",
        "S >= X (S = Speed)",
        "Priority Hiding",
        "Core Priority",
        "Idle Priority",
        "Length <= Xms",
        "Fadetime",
        "Late Start",
        "Duplicate Spam",
        "Flash Breaker",
    },{
        "WT <= X (WT = WeightTarget)",
        "Core Priority",
        "Idle Priority",
        "Priority Hiding",
        "S >= X (S = Speed)",
        "Late Start",
        "Duplicate Spam",
        "Flash Breaker",
    }, true, 'Logging Filters for AP breaker.')

    local speed_max, raw_speed_max = advanced:newDependencyBox("validation_filters", "S >= X (S = Speed)", true);
    speed_max:newSlider("anti_ap_breaker_max_speed", "Max Speed", 5, 1, 100, 1, true, "x");
    raw_speed_max:SetupDependencies({{ 
        aztup_options.validation_filters, "S >= X (S = Speed)"
    }, { 
        aztup_toggles.basic_validation, true
    }}); 

    local weight_target_selector, raw_weight_target = advanced:newDependencyBox("validation_filters", "WT <= X (WT = WeightTarget)", true);
    weight_target_selector:newSlider("anti_ap_breaker_minimum_wt", "Minimum WT", 10, 10, 100, 1, true, "x Weight");
    raw_weight_target:SetupDependencies({{ 
        aztup_options.validation_filters, "WT <= X (WT = WeightTarget)"
    }, { 
        aztup_toggles.basic_validation, true
    }});

    local time_x_ms, raw_time_x_ms = advanced:newDependencyBox("validation_filters", "Length <= Xms", true);
    time_x_ms:newSlider("anti_ap_breaker_length_ms", "Minimum Length", 50, 1, 500, 1, true, "ms");
    raw_time_x_ms:SetupDependencies({{ 
        aztup_options.validation_filters, "Length <= Xms"
    }, { 
        aztup_toggles.basic_validation, true
    }});

    ------------------------------------------------------------------ Right column
    local reactions_tabbox = tab:newTabbox("Reactions", true);
    local reactions = reactions_tabbox:newTab("Reactions");

    reactions:newDropdown("reaction_targets", "Apply Reactions To", { "PVP", "PVE" }, { "PVP", "PVE" }, true,
        "Which fights the reactions below are used in.");

    reactions:newSlider("feint_reaction_chance", "Feint Reaction Chance", 100, 0, 100, 0, true, "%", nil,
        "Chance to react to an enemy's feint and not parry it. 100% = never parries a feint it sees. Lower = sometimes gets baited, which looks more human.");
    reactions:newSlider("feint_reaction_ms", "Feint Reaction Time", 0, 0, 400, 0, true, "ms", nil,
        "How long after a feint before Auto Parry reacts to it. 0 = instant. A parry due inside this window still goes out, like a human getting baited by a fast feint.");
    reactions:newDivider();

    reactions:newSlider("block_instead_chance", "Block Instead Of Parry", 0, 0, 100, 0, true, "%", nil,
        "Chance to hold block through the hit instead of parrying.");
    reactions:newSlider("dodge_instead_chance", "Dodge Instead Of Parry", 0, 0, 100, 0, true, "%", nil,
        "Chance to roll instead of parrying (only when a roll is available).");
    reactions:newSlider("misstime_chance", "Fake Misstime Parry", 0, 0, 100, 0, true, "%", nil,
        "Chance to tap block early (looks like a mistimed parry), then roll when the hit actually lands.");
    reactions:newDivider();

    reactions:newToggle("multi_hit_guard", "Multi-Hit Guard", true,
        "For mantras that keep hitting (Sinister Halo, Electro Carve, Ice Carve): if the first parry doesn't go through, roll - or hold block if you can't roll - for the rest of the move.");
    reactions:newToggle("tick_move_guard", "Moving Multi-Hit Guard", true,
        "Ice Carve, Electro Carve, Twister Kicks: if the attacker walks into range after the move has started, roll - or hold block if you can't roll - until they leave range or the move ends.");
    reactions:newSlider("max_block_posture", "Don't Block Above Posture", 85, 10, 100, 0, true, "%", nil,
        "Auto Parry won't HOLD block (Multi-Hit Guard, Block Instead Of Parry, Block fallback) once your posture is above this. Quick parry taps aren't affected.");
    reactions:newDivider();

    reactions:newToggle("back_dodge_walk_forward", "Walk Forward On Back Dodge", false,
        "When Auto Parry rolls backwards, walks forward during the roll so you stay roughly where you were. Looks more human.");
    reactions:newSlider("back_dodge_walk_chance", "Walk Forward Chance", 100, 0, 100, 0, true, "%", nil,
        "How often it walks forward on a back dodge.");

    local randomization_dependency_box = reactions_tabbox:newTab("Humanize"):newDependencyBox("ap_randomization");
    randomization_dependency_box:newLabel("Turn on Humanization (Main tab) to use these.", true);

    randomization_dependency_box:newSlider("parry_to_dodge_chance_undefined",    "Force Dodge Chance (Untagged)", 0, 0, 100, 1, true, "%");
    randomization_dependency_box:newSlider("parry_to_dodge_chance_mantra",      "Force Dodge Chance (Mantras)", 0, 0, 100, 1, true, "%");
    randomization_dependency_box:newSlider("parry_to_dodge_chance_critical",   "Force Dodge Chance (Crits)", 0, 0, 100, 1, true, "%");
    randomization_dependency_box:newSlider("parry_to_dodge_chance_m1",          "Force Dodge Chance (M1)", 0, 0, 100, 1, true, "%");
    randomization_dependency_box:newSlider("parry_to_fallback_chance",   "Parry -> Fallback Chance", 0, 0, 100, 1, true, "%");

    randomization_dependency_box:newToggle("only_convert_dodge_if_possible", "Only Convert Dodge If Possible", false, "Only converts parries to dodges if the dodge is possible.", nil);

    local function create_settings_page(tab, id)
        tab:newToggle(id.."blatant_roll_with_anims","Blatant Roll w/ Anims", false, "Plays a anim while using blatant roll.", nil);
        tab:newToggle(id.."roll_if_unequipped",     "Roll If Unequipped", false, "Rolls if you have no weapon equipped.", nil);
        
        tab:newToggle(id.."blatant_crouch",         "Blatant Crouch", false, "Fires the crouch remote & skips any animation.", nil);
        tab:newToggle(id.."blatant_roll",           "Blatant Roll", false, "Fires the remote instead of going thru the client.", nil);

        tab:newToggle(id.."roll_cancel",            "Roll Cancel", false, "Automatically cancels your rolls by M2ing.", nil);
        tab:newToggle(id.."auto_equip",             "Auto Equip", false, "Automatically will equip your weapon.", nil);

        tab:newSlider(id.."max_roll_cancel_delay", "Max Cancel Delay", 150, 1, 200, 1, true, "ms");
        tab:newSlider(id.."min_roll_cancel_delay", "Min Cancel Delay", 70, 1, 200, 1, true, "ms");
        tab:newSlider(id.."roll_cancel_chance", "Cancel Chance", 90, 1, 100, 1, true, "%");
        tab:newSlider(id.."parry_chance", "Parry Chance", 100, 1, 100, 1, true, "%");
    end

    create_settings_page(reactions_tabbox:newTab("PVE"), "pve_")
    create_settings_page(reactions_tabbox:newTab("PVP"), "pvp_")


    local other = autoparry_tabbox:newTab("Other");
    other:newToggle("view_hitboxes", "View hitboxes", false, "Log anims to console.", nil);
    other:newSlider("max_boxes", "Max Hitboxes", 5, 1, 100, 0, true, "hbs");
    other:newSlider("hb_trans", "Hitbox Transparency", 100, 1, 100, 1, true, "%");
    other:newToggle("show_hitbox_simulation", "View hitbox simulation", false, "Show hitbox simulation.", nil);
    local hitbox_dependency = other:newDependencyBox("show_hitbox_simulation");
    hitbox_dependency:newDropdown("HS_HitboxType", "Hitbox Type", {
        "Block",
        "Ball", 
        "Cylinder"
    }, "Block", false, "Type of hitbox shape to visualize.", nil);

    hitbox_dependency:newSlider("HS_HitboxSizeX", "Hitbox Size X", 4, 0.1, 250, 1, true, "studs", nil);
    hitbox_dependency:newSlider("HS_HitboxSizeY", "Hitbox Size Y", 4, 0.1, 250, 1, true, "studs", nil);
    hitbox_dependency:newSlider("HS_HitboxSizeZ", "Hitbox Size Z", 4, 0.1, 250, 1, true, "studs", nil);
    hitbox_dependency:newSlider("HS_ShiftOffset", "Shift Offset", 0, -250, 30, 1, true, "studs", nil);


    local function get_list()
        local list = {};

        for _, name in getgenv().timing_names and getgenv().timing_names() or {} do
            table.insert(list, name);
        end;

        for _, name in getgenv().effect_names or {} do
            table.insert(list, name);
        end

        return list    
end;
    local chance_label;

    other:newDropdown('m1_timing_hitbox_type', 'M1 Hitbox Type', {
        "Square",
        "Ball"
    }, {
        "Ball"
    }, false, "M1 Timings & their hitbox type.", function() end, true);
    other:newDropdown('blocked_timings', 'Blocked Timings', {}, {}, true, "Disallowed Timings.", function() end, true);
    other:newDropdown('chance_timings', 'Chance Editor', {}, {}, false, "Change Timing Chances.", function() end, true);
    other:newSlider("chance_parry_weight", "Parry Chance", 100, 0, 100, 0, true, "%");
    other:newSlider("chance_dodge_weight", "Dodge Chance", 0, 0, 100, 0, true, "%");
    other:newSlider("chance_skip_weight", "Skip Chance", 0, 0, 100, 0, true, "%");

    other:newButton("Load List", function()
        local list = get_list();
        aztup_options.blocked_timings:SetValues(list);
        aztup_options.chance_timings:SetValues(list);
    end);

    other:newButton("Normalize Chances", function()
        local buckets = {
            { key = "Parry", option = aztup_options.chance_parry_weight },
            { key = "Dodge", option = aztup_options.chance_dodge_weight },
            { key = "Skip", option = aztup_options.chance_skip_weight },
        };

        local total = 0;
        for _, bucket in ipairs(buckets) do
            bucket.value = math.max(0, tonumber(bucket.option.Value) or 0);
            total += bucket.value;
        end;

        if total <= 0 then
            aztup_options.chance_parry_weight:SetValue(100);
            aztup_options.chance_dodge_weight:SetValue(0);
            aztup_options.chance_skip_weight:SetValue(0);
            Logger:notify("all 0, set parry back to 100", 4);
            return        
end;

        local used = 0;
        for _, bucket in ipairs(buckets) do
            local exact = (bucket.value / total) * 100;
            bucket.normalized = math.floor(exact);
            bucket.frac = exact - bucket.normalized;
            used += bucket.normalized;
        end;

        local remaining = 100 - used;
        table.sort(buckets, function(a, b)
            if a.frac == b.frac then
                return a.key < b.key            
end;

            return a.frac > b.frac        
end);

        for i = 1, remaining do
            buckets[i].normalized += 1;
        end;

        for _, bucket in ipairs(buckets) do
            bucket.option:SetValue(bucket.normalized);
        end;
    end);
    
    other:newButton("Set", function()
        local timing_name = aztup_options.chance_timings.Value;
        local outcome_weights = {
            ["Parry"] = aztup_options.chance_parry_weight.Value,
            ["Dodge"] = aztup_options.chance_dodge_weight.Value,
            ["Skip"] = aztup_options.chance_skip_weight.Value,
        };
        if not timing_name or timing_name == "" then
            Logger:notify("no timing selected!", 5);
            return        
end;
        
        chance_store:add_chance(timing_name, outcome_weights);
        chance_store:save_chances();
        if chance_store.on_load_function then
            chance_store.on_load_function();
        end;
    end);

    other:newButton("Clear", function()
        table.clear(chance_store.chances);
        if chance_store.on_load_function then
            chance_store.on_load_function();
        end;
        chance_store:save_chances();
    end, true);

    chance_label = other:newLabel("", true, true);
    chance_label:Hide();

    chance_store:on_load(function()
        local store = {"Current Chances:"};
        local override_store = {"Current Chances:"};
    
        for t, _ in pairs(chance_store.chances) do
            local entry = chance_store:get_entry(t);
            local outcome_weights = entry and (entry.outcome_weights or entry.fail_weights) or { Parry = 100 };
            local total_weight = 0;
            for _, amount in pairs(outcome_weights) do
                total_weight += typeof(amount) == "number" and math.max(0, amount) or 0;
            end;

            if total_weight <= 0 then
                outcome_weights = { Skip = 100 };
                total_weight = 100;
            end;

            local chance_parts = {};
            local colored_parts = {};
            for _, action_name in {
                "Parry",
                "Dodge",
                "Skip"
            } do
                local amount = outcome_weights[action_name] or 0;
                if amount == 0 then continue end
                local pct = math.floor((amount / total_weight) * 100 + 0.5);
                local fmt_action_name = ({
                    ["Parry"] = "Parry",
                    ["Dodge"] = "Dodge",
                    ["Skip"] = "Skip",
                })[action_name];
                local color = Color3.fromRGB(255, 85, 88):Lerp(Color3.new(0.403922, 1, 0.403922), pct / 100):ToHex();

                table.insert(chance_parts, string.format('%s %d%%', fmt_action_name, pct));
                table.insert(colored_parts, string.format('<font color="#%s">%s %d%%</font>', color, fmt_action_name, pct));
            end;

            local chance_text = #chance_parts > 0 and table.concat(chance_parts, ", ") or "Skip 100%";
            local chance_text_colored = #colored_parts > 0 and table.concat(colored_parts, ", ") or '<font color="#FF5558">Skip 100%</font>';
            table.insert(override_store, string.format('%s: %s', t, chance_text));
            table.insert(store, string.format('%s: %s', t, chance_text_colored));
        end;
        
        if #store == 1 then
            table.clear(store);
            table.clear(override_store);
            chance_label:Hide();
        else
            chance_label:Show();
        end;

        chance_label:SetText(table.concat(store, "\n"), table.concat(override_store, "\n"));    
    end);

    other:newToggle("info_logger", "Timing Logger", false, "Log anims to console.", nil);
    other:newSlider("info_logger_range", "Timing Logger Range", 1, 1, 500, 0, true, "s");
    if can_edit_internal_timings or isfile("builder.rbxm") then
        local debug = tab:newGroupBox("Debug", true);

        local function play_action(type)
            local DefendActionManager = getgenv().DefendActionManager;
            if not DefendActionManager then
                return warn("turn ap on stupid HON")            
end;

            local entity = local_player.character

            if type == "Parry" then
                DefendActionManager:queue_generic_parry_task_no_convert(entity);
            elseif type == "Dodge" then
                DefendActionManager:add_action(entity, "dodge", tick());
            elseif type == "Forced Full Dodge" then
                DefendActionManager:defend_action_dodge({
                    mob = entity,
                    type = "dodge",
                    full = true,
                    when = tick()
                });
            elseif type == "Start Block" then
                DefendActionManager:add_action(entity, "block", tick());
            elseif type == "End Block" then
                DefendActionManager:add_action(entity, "unblock", tick());
            elseif type == "Crouch" then
                task.spawn(function()
                    local_player.character:WaitForChild("CharacterHandler"):WaitForChild("Requests"):WaitForChild("ServerCrouch"):FireServer(true);
                    task.wait(1);
                    local_player.character:WaitForChild("CharacterHandler"):WaitForChild("Requests"):WaitForChild("ServerCrouch"):FireServer(false);
                end);
            elseif type == "Jump" or type == "Legit Jump" then
                if #services.Players:GetPlayers() == 1 and type ~= "Legit Jump" then
                    local_player.character.CharacterHandler.Requests.Jump:FireServer();
                    local_player.root_part.CFrame *= CFrame.new(0, 50, 0);
                else
                    local jump_func = nil;
                    local upvalues = getupvalues(base_require(game:GetService("ReplicatedStorage").Modules.CharacterControllers.Human));

                    for _, upvalue in upvalues do
                        if typeof(upvalue) == "table" and rawget(upvalue, "Jump") then
                            jump_func = rawget(upvalue, "Jump");
                        end;
                    end;

                    if jump_func({
                        Humanoid = local_player.humanoid,
                        RootPart = local_player.root_part,
                        GroundSensor = local_player.root_part:FindFirstChild("GroundSensor")
                    }) then
                        local_player.character.CharacterHandler.Requests.Jump:FireServer();

                        local jump_anim = local_player.humanoid:LoadAnimation(local_player.character.CharacterHandler.InputClient.Jump);
                        jump_anim:Play(0.05);

                        task.delay(0.4, function()
                            jump_anim:AdjustSpeed(0.5);
                            jump_anim:Stop(0.1);
                        end);
                    end;
                end;
            end;
        end;

        for _, action_type in {
            "Parry",
            "Dodge",
            "Forced Full Dodge",
            "Start Block",
            "End Block",
            "Jump",
            "Legit Jump",
            "Crouch"
        } do
            debug:newButton("Play " .. action_type, function()
                xpcall(play_action, warn, action_type);
            end);
        end;
    end;

end, {
    name = "Auto Parry"
}