--[[
    features/auto-parry/builder.lua - STUB (vanta-v2)

    The Timing Builder isn't in the Project Rain OSS release (locked feature).
    Call sites this satisfies:
      ui/tabs/combat.lua:  timing_builder:set_visible(val)
                           timing_builder.on_close = function() ... end
      animator-handler:    getgenv().timing_builder:load_track(track, entity)
                           (only if getgenv().timing_builder is set - this stub
                            deliberately does NOT set it, so that path stays off)
]]

local timing_builder = {
    on_close = nil,
};

function timing_builder:set_visible(visible)
    if not visible then
        return;
    end;

    if Library and Library.Notify then
        Library:Notify("Timing Builder isn't available - it was locked out of the Project Rain open-source release.");
    end;

    -- Flip the toggle back off so the UI doesn't claim it's open.
    if self.on_close then
        task.defer(self.on_close);
    end;
end

function timing_builder:load_track() end

return timing_builder;
