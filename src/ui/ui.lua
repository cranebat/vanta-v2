 
local tab, _ = require("@src/utility/ui/wrapper");

return {
    initialize = function()
        local creation_order = {
            "Main",
            "Visuals",
            "Combat",
            "Auto Parry",
            "Automation"
        };
 
        for _, tab_name in pairs(creation_order) do
            aztup.tabs[tab_name] = tab.new(tab_name); 
        end

        for _, module in list_modules("ui/tabs/*") do
            local func, data = require(module);
            
            if not aztup.tabs[data.name] then 
                continue            
end;
            
            xpcall(func, warn, aztup.tabs[data.name]);   
        end

        local ThemeManager = require("@src/utility/librarys/managers/ThemeManager");
        local SaveManager = require("@src/utility/librarys/managers/SaveManager");
        
        aztup.tabs.UI = tab.new("UI");

        SaveManager:SetLibrary(aztup.ui)
        SaveManager:IgnoreThemeSettings() 
        ThemeManager:SetLibrary(aztup.ui);

        SaveManager:SetIgnoreIndexes({
            "fly",
            "noclip",
            "speed",
            "infinite_jump",
            "spotify_redirect_url",
            "start_hidden",
            "start_minimized",
            "ap_builder_timing",
            "ap_builder_offset",
            "ap_builder_scale",
            "ap_builder_action",
            "ap_builder_when",
            "ap_builder_hx",
            "ap_builder_hy",
            "ap_builder_hz",
            "ap_builder_ox",
            "ap_builder_oy",
            "ap_builder_oz",
            "ap_builder_type",
            "ap_builder_ball",
            
        })
        SaveManager:SetFolder('Vanta/Deepwoken-Config')
        ThemeManager:SetFolder('Vanta/Deepwoken-Config')
        SaveManager:BuildConfigSection(aztup.tabs.UI.Tab);
        ThemeManager:ApplyToTab(aztup.tabs.UI.Tab);

        -- Vanta: edge glow + font picker (before autoload so saved values apply).
        xpcall(function()
            require("@src/ui/appearance").build(aztup.tabs.UI);
        end, warn);

        task.spawn(pcall, require("@src/ui/config_converter"));
        task.spawn(xpcall, require("@src/ui/tabs/ui"), warn, aztup.tabs.UI);

        task.spawn(function()
            aztup_toggles.mod_detector:SetValue(true);
        end);
        
        local start = tick();
        if aztup.automation:has_any() then
            task.spawn(pcall, function()
                SaveManager:LoadAutoloadConfig()
            end);
        else
            SaveManager:LoadAutoloadConfig()
        end;
        local custom_name = not LPH_OBFUSCATED and isfile("custom_name.txt") and readfile("custom_name.txt") or nil;
        Library.PRWindow:SetWindowTitle((function()
		    if custom_name then
		    	return string.format(LPH_ENCSTR("%s"), custom_name:gsub("|ACCENT", "<font color=\"#" .. Library.AccentColor:ToHex() .. "\">"))		    
end
		    return string.format(LPH_ENCSTR("<font color=\"#%s\">vanta</font>"), Library.AccentColor:ToHex())
	    end)())

        aztup.auto_loaded = true;
    end;
} 