
return function(tab)

    local pvp = tab:newGroupBox("Assistance", false);
    
        pvp:newToggle("easy_roll_cancel", "Easy Roll Cancel", false, "Allows you to press M1 mid dash to cancel it.", nil);
    pvp:newToggleWithKeybind("auto_dustlunge", "Auto Assassination", false, "Allows you to hold M1 to attack, Doesn't follow the No Aerial Logic.", nil);
    pvp:newKeybind("auto_dustlunge_bind", "Auto Assassination Bind (hold)", 'V', function(on)
        aztup.features.auto_dustlunge.held = on;
    end, "Hold", true, false); 

    local auto_dustlunge_dependency_box = pvp:newDependencyBox("auto_dustlunge");
    auto_dustlunge_dependency_box:newToggle("auto_dustlunge_debug", "Auto Assassination Debug", false, "Displays the dustlunge hitbox.", nil);

    pvp:newToggle("m1_hold", "M1 Hold", false, "Allows you to hold M1 to attack, Doesn't follow the No Aerial Logic.", nil);

    local no_stun = tab:newGroupBox("No Stun", false);
    no_stun:newToggle(           "fast_swing",           "Remove Weapon Endlag", false, "Removes endlag & stuff from swinging (same effect can be done with no stun)", nil);
    no_stun:newRiskyToggleWithKeybind("no_stun",              "No Stun", false, "Removes all stun from the game."); 

    local attach_to_back = tab:newGroupBox("Attach to Back", false); 
    attach_to_back:newToggleWithKeybind("attach_to_back", "Attach to Back", false, "Allows you to attach to the back of your target, M1/M2 to select a target.", nil);
    attach_to_back:newSlider("atb_x_offset", "X Offset", 0, -150, 150, 1, true, "s");
    attach_to_back:newSlider("atb_y_offset", "Y Offset", 0, -150, 150, 1, true, "s");
    attach_to_back:newSlider("atb_z_offset", "Z Offset", 5, -150, 150, 1, true, "s");
    attach_to_back:newToggle("atb_lock_rotation",   "Ignore Rotation", false, "Forces you to be looking at the mob.", nil);
    attach_to_back:newToggle("atb_prevent_voiding", "Prevent Voiding Self", false, "Prevents attach to back from voiding you.", nil);
    attach_to_back:newToggle("atb_rotate",   "Rotate Towards", false, "Forces you to be looking at the mob.", nil);
    attach_to_back:newSlider("atb_speed",    "Control Speed", 16.5, 1, 100, 1, true, "st/s");

    attach_to_back:newDropdown('allowed_atb_targets', 'Allowed Targets', {
        "Guildmates",
        "Players",
        "Mobs" 
    },{
        "Guildmates",
        "Players",
        "Mobs"
    }, true, "Allowed targets to attach to back of.");

    local stun_effects = {
        "LightningStun",
        "PreventAction",
        "OffhandAttack",
        "UsingCritical",
        "MobileAction",
        "MediumAttack",
        "CarryObject",
        "PreventRoll",
        "LightAttack",
        "HeavyAttack",
        "InDialogue",
        "UsingSpell",
        "NoParkour",
        "NoJumpAlt",
        "Blocking",
        "NoAttack",
        "Carried",
        "Falling",
        "Chilled",
        "Pinned",
        "Action",
        "Dodged",
        "NoJump",
        "NoRoll",
        "NoMove",
        "Stun",
    };

    no_stun:newDropdown('no_stun_items', 'Removed Effects', stun_effects, stun_effects, true, 'Effects that No Stun will remove');


    local m1_hold_dependency_box = pvp:newDependencyBox("m1_hold");
    m1_hold_dependency_box:newToggle("no_aerials", "Spoof No Air", false, "Never Aerials when holding M1.", nil);

    
    
    
    
    
    
    

    local anim_speed_changer = tab:newGroupBox("Anim Speed Changer", true); 
    anim_speed_changer:newToggleWithKeybind("anim_speed_changer", "Anim Speed Changer", false, "Changes the speed of your animations, Only affects auto parry timings", nil, true);
    anim_speed_changer:newToggleWithKeybind("switch_speeds", "Switch Speed", false, "Instead of randomly generating a value between your min/max, Switch between them.", nil, true);

    local type_dependency_box = anim_speed_changer:newDependencyBox("anim_speed_changer");
    type_dependency_box:newDropdown("anim_speed_changer_types", "Affected Anim Types", {
        "Criticals",
        "Untagged",
        "Mantras",
        "Bells",
        "M1s",
    },{}, true, "Types of anims that the speed changer will affect, Some anims are currently untagged.");
    
    local function make_speed_slider(flag, display)
        local slider_dependency_box, raw_slider = anim_speed_changer:newDependencyBox();

        slider_dependency_box:newMinMaxSlider(flag, display, { Min = 0.9, Max = 1.10 }, 0.1, 2.10, 2, true, "x");

        raw_slider:SetupDependencies({{ 
            aztup_toggles.anim_speed_changer, true
        }, { 
            aztup_options.anim_speed_changer_types, display:gsub(" Speed", "")
        }});
    end
    make_speed_slider("anim_critical_speed", "Criticals");
    make_speed_slider("anim_untagged_speed", "Untagged");
    make_speed_slider("anim_mantra_speed", "Mantras");
    make_speed_slider("anim_bell_speed", "Bells");
    make_speed_slider("anim_m1_speed", "M1s");

    

    







local silent_aim = tab:newGroupBox("Silent Aim", true); 
    silent_aim:newToggle("silent_aim", "Silent Aim", false, "Automatically aims for you.", nil);
    silent_aim:newToggle("force_chime_opponent", "Force Chime (solo) Opponent", false, "Forces silent aim to be on the chime opponent with no FOV check.", nil);

    silent_aim:newToggle("show_fov", "Show FOV", false, "Displays your silent aim FOV.", nil);
    silent_aim:newToggle("fov_filled", "Fill FOV", false, "Displays your silent aim FOV.", nil);
    silent_aim:newSlider("fov_transparency", "Transparency", 0.1, 0, 1, 2, true, "");
    silent_aim:newSlider("prediction", "Prediction", 15, 0, 200, 2, true, "%");
    silent_aim:newSlider("fov_radius", "FOV", 90, 1, 2000, 1, true, "px");
    silent_aim:newDropdown('allowed_sa_targets', 'Allowed Targets', {
        "Guildmates",
        "Players",
        "Mobs"
    },{
        "Players",
        "Mobs"
    }, true, "Allowed targets to silent aim at.");


    local safe_input = tab:newGroupBox("Safe Input", false);
    safe_input:newLabel("Safe Input requires M1 Hold & AP.", true);
    safe_input:newLabel("Some moves arent tagged.", true);
    safe_input:newToggle("block_input", "Block Input [WIP]", false, "Blocks input when doing a action, Also known as 'Safe Input', Requires 'M1 Hold' to block M1s.", nil);
         
    local punishable_time_box, raw_punishable = safe_input:newDependencyBox(); 
    punishable_time_box:newSlider("bi_punishable_time", "Punishable Time", 650, 1, 1000, 1, true, "ms");
    
    local dynamic_extra_punishable_time_box, raw_extra_punishable = safe_input:newDependencyBox();
    dynamic_extra_punishable_time_box:newSlider("extra_bi_punishable_time", "Extra Punishable Time", 0, -500, 500, 1, true, "ms");
     
    safe_input:newDropdown('bi_punishable_type', 'Punishable Type', {
        "Dynamic",
        "Custom",
        "Always"
    }, "Custom", false, "What block input will use for the time frame when you can be punished, Dynamic may be inconsistent on certain weapons (e.g: rifle)")    
    safe_input:newDropdown('allowed_bi_targets', 'Allowed Targets', {
        "PVE",
        "PVP"
    },{
        "PVE",
        "PVP"
    }, true, "What block input will trigger on.")
    
    safe_input:newDropdown('blocked_safe_input_user_moves', 'Blocked Moves', {
        "Criticals",
        "M1s", 
        "M2s",
    },{ 
        "M1s"
    }, true, "Safe Input Triggers, Some moves are currently untagged or skip.");

    safe_input:newDropdown('blocked_safe_input_moves', 'Dont Against', {
        "Animations",
        "Critical",
        "Untagged",
        "Effects",
        "Mantra",
        "Parts",
        "Bell",
        "M1",
    },{}, true, "Block Input Triggers, Some moves are currently untagged or skip.");
    raw_punishable:SetupDependencies({{ 
        aztup_options.bi_punishable_type, "Custom"
    }});

    raw_extra_punishable:SetupDependencies({{ 
        aztup_options.bi_punishable_type, "Dynamic"
    }});

    local mantra_sliding = tab:newGroupBox("Mantra Slidecast", true);
    mantra_sliding:newToggleWithKeybind("mantra_slidecasting", "Mantra Slidecasting", false, "Automatically slides after doing certain actions.", nil);
    local mantra_sliding_dependency_box = mantra_sliding:newDependencyBox("mantra_slidecasting");
    mantra_sliding_dependency_box:newSlider("mantra_slidecasting_chance", "Trigger Chance", 70, 1, 100, 0, true, "%");

    mantra_sliding_dependency_box:newDropdown('mantra_slidecasting_mantras', 'Trigger Mantras', {}, {}, true, "Mantras that trigger action sliding.");
    mantra_sliding_dependency_box:newButton("Load Mantras", function()
        local mantras = {};
        for _, mantra in local_player.instance.Backpack:GetChildren() do
            if not mantra.Name:find("Mantra:") or mantra.Name:find("RecalledMantra:") then continue end        

            table.insert(mantras, mantra:GetAttribute("DefaultName"));
        end

        aztup_options.mantra_slidecasting_mantras:SetValues(mantras);
    end);
    local action_rolling = tab:newGroupBox("Mantra Rolling", true);
    action_rolling:newToggleWithKeybind("action_rolling", "Mantra Rolling", false, "Automatically rolls after doing certain actions.", nil, false);
    local action_rolling_dependency_box = action_rolling:newDependencyBox("action_rolling");

    action_rolling_dependency_box:newSlider("action_rolling_chance", "Trigger Chance", 70, 1, 100, 0, true, "%");
    action_rolling_dependency_box:newDropdown('action_rolling_mantras', 'Trigger Mantras', {}, {}, true, "Mantras that trigger action rolling.");
    action_rolling_dependency_box:newButton("Load Mantras", function()
        local mantras = {};
        for _, mantra in local_player.instance.Backpack:GetChildren() do
            if not mantra.Name:find("Mantra:") or mantra.Name:find("RecalledMantra:") then continue end        

            table.insert(mantras, mantra:GetAttribute("DefaultName"));
        end

        aztup_options.action_rolling_mantras:SetValues(mantras);
    end);

    local backstab_movestacker = tab:newGroupBox("Backstab Movestacker", true);
    backstab_movestacker:newToggleWithKeybind("backstab_movestacker", "Backstab Movestacker", false, "Automatically casts in a Authority Ensign backstab ('Backstabber' tal req).", nil);
    local backstab_movestacker_dependency_box = backstab_movestacker:newDependencyBox("backstab_movestacker");
    backstab_movestacker_dependency_box:newDropdown('backstab_movestacker_mantras', 'Trigger Mantras', {}, {}, true, "Mantras that will trigger during a backstab.");
    backstab_movestacker_dependency_box:newButton("Load Mantras", function()
        local mantras = {};
        for _, mantra in local_player.instance.Backpack:GetChildren() do
            if not mantra.Name:find("Mantra:") or mantra.Name:find("RecalledMantra:") then continue end        
            
            table.insert(mantras, mantra:GetAttribute("DefaultName"));
        end

        aztup_options.backstab_movestacker_mantras:SetValues(mantras);
    end);


end, {
    name = "Combat"
}