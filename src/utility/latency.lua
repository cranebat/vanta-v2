local latency = {};
local ping = services.Stats:FindFirstChild("Data Ping", true);
local notified = false;

local function raw_ping()
    if not ping then
        if not notified then
            notified = true;
            Logger:short_notify("Cant find ping stat, Ignore this if kicked.");
        end
        return 0
end

    local val;
    local old = getthreadidentity();
    setthreadidentity(8);
    val = ping:GetValue();
    setthreadidentity(old);
    return val / 1000
end

--[[
    Vanta: Ping Smoothing (Auto Parry -> Advanced, on by default).
    Every timing subtracts ping, so a single spike used to make that parry fire early.
    Now the median of the last ~2s of samples is used: one-off spikes are ignored,
    real ping changes still come through within a second or two.
]]
local SAMPLE_EVERY = 0.25;
local MAX_SAMPLES = 8;
local samples = {};

local function add_sample()
    table.insert(samples, raw_ping());
    if #samples > MAX_SAMPLES then
        table.remove(samples, 1);
    end;
end

-- Sampled in the background so the window is always the last ~2s, even after
-- standing around idle.
-- One sampler per load: re-executing the script replaces the token and the old
-- loop stops.
local session = {};
getgenv().vanta_latency_session = session;
task.spawn(function()
    while task.wait(SAMPLE_EVERY) do
        if getgenv().vanta_latency_session ~= session then break end;
        pcall(add_sample);
    end;
end);

local function smoothed_ping()
    if #samples == 0 then
        pcall(add_sample);
        if #samples == 0 then return 0 end;
    end;

    local sorted = table.clone(samples);
    table.sort(sorted);
    local n = #sorted;
    if n % 2 == 1 then
        return sorted[(n + 1) / 2]
    end;
    return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
end

function latency:get_ping()
    if aztup and aztup.flags and aztup.flags.ping_smoothing == false then
        return raw_ping()
    end;
    return smoothed_ping()
end;

function latency:get_raw_ping()
    return raw_ping()
end;

function latency:half_ping()
    return latency:get_ping() / 2
end;

return latency
