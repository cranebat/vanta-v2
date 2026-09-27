--[[
    features/buttons/refresh.lua - STUB (vanta-v2)

    Not in the Project Rain OSS release (locked feature). ui/tabs/main.lua uses it as
    the Func of the "Refresh" button, so it must be a function. It tells you it's
    unavailable instead of silently doing nothing.
]]

return function()
    if Library and Library.Notify then
        Library:Notify("Refresh isn't available - it was locked out of the Project Rain open-source release.");
    end;
end;
