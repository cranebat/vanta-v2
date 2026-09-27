--[[
    data/gun_projectile.lua (Vanta)

    Follows a projectile a caster fires (Fire Gun, Wind Gun, ...) and says when it's
    about to hit you. We don't know these projectiles' part names, so a projectile is
    recognised by what it does: a part that appears in workspace.Thrown next to the
    caster and then flies straight at you. Its speed comes from its velocity (or from
    how far it moved between frames, for projectiles moved by CFrame), and the parry
    fires when the time until it reaches you drops below your ping + a small lead.

    Parts that fly past you, sit still, or belong to a character are ignored.
]]

local gun_projectile = {};

local SPAWN_RADIUS = 15;   -- studs from the caster a new part must appear within
local MIN_SPEED = 25;      -- studs/s towards you to count as "coming at you"
local AIM = 0.85;          -- how directly at you it must be heading (cosine)

local function lead()
    return (aztup.flags.gun_parry_lead or 120) / 1000
end

function gun_projectile.new_tracker(caster)
    local tracker = { caster = caster, parts = {}, seen_incoming = false };

    function tracker:consider(part)
        if not part:IsA("BasePart") then return end;
        local root = caster:FindFirstChild("HumanoidRootPart");
        if not root or (part.Position - root.Position).Magnitude > SPAWN_RADIUS then return end;
        local model = part:FindFirstAncestorOfClass("Model");
        if model and model:FindFirstChildOfClass("Humanoid") then return end;
        self.parts[part] = { pos = part.Position, t = tick() };
    end

    -- true when a tracked projectile will reach you within ping + lead.
    function tracker:impact_soon()
        local me = local_player.root_part;
        if not me then return false end;
        local window = Latency:get_ping() + lead();

        for part, info in self.parts do
            if not part.Parent then
                self.parts[part] = nil;
                continue
            end;

            local now, pos = tick(), part.Position;
            local velocity = part.AssemblyLinearVelocity;
            if velocity.Magnitude < 5 and now - info.t > 1 / 240 then
                velocity = (pos - info.pos) / (now - info.t);
            end;
            info.pos, info.t = pos, now;

            local to_me = me.Position - pos;
            local distance = to_me.Magnitude;
            if distance < 0.5 or velocity.Magnitude < 1 then continue end;

            local closing = velocity:Dot(to_me.Unit);
            if closing > MIN_SPEED and velocity.Unit:Dot(to_me.Unit) > AIM then
                self.seen_incoming = true;
                if distance / closing <= window then
                    return true
                end;
            end;
        end;
        return false
    end

    return tracker
end

-- Watches what `caster` fires for up to `max_time` seconds (giving up after `search`
-- seconds if nothing appeared). Calls on_incoming() the first time something is seen
-- flying at you. Returns true when it's about to hit (parry now).
function gun_projectile.wait_for_impact(caster, search, max_time, on_incoming)
    local thrown = workspace:FindFirstChild("Thrown");
    if not thrown then return false end;

    local tracker = gun_projectile.new_tracker(caster);
    local conn = thrown.DescendantAdded:Connect(function(part)
        tracker:consider(part);
    end);

    local started, hit, notified = tick(), false, false;
    while tick() - started < (max_time or 2.5) do
        if tick() - started > (search or 0.8) and next(tracker.parts) == nil then break end;
        if tracker:impact_soon() then
            hit = true;
        end;
        if tracker.seen_incoming and not notified then
            notified = true;
            if on_incoming then pcall(on_incoming) end;
        end;
        if hit then break end;
        task.wait();
    end;

    conn:Disconnect();
    return hit
end

return gun_projectile;
