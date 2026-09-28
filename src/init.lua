--[[
    init.lua (vanta-v2)

    Rewritten bootstrap for the Project Rain OSS + APC-timings hybrid.

    What changed vs. the stock OSS init.lua, and why:
      - Dropped `require("@src/luarmor_init_script")` - that's Rain's proprietary
        licensing/anti-tamper loader ("anti-skid for the codebase"), not present in the
        OSS tree and explicitly out of scope per the brief.
      - Dropped the localhost:441 dev-tools fetch - that only ever talked to the original
        author's own dev machine.
      - Dropped `@src/security/user_service` - the "related security infra (server
        stuff) or logging" the brief said to leave out. `user_service` is stubbed to an
        empty table below so anything that references it as a bare global doesn't error.
      - A few optional requires (auto-builder, visuals/player_esp, visuals/base_esp,
        setup_auto_load) are wrapped in pcall + warn so one failing module can't stop
        the whole script from booting.
      - Assets it writes (fonts, sounds, the race-morph GUI) are embedded by
        build/bundle.py, same as Rain's own bundler did.
      - Removed Rain's first-run Terms of Service screen and the premade-config download
        from Rain's server (files.project-rain.net).
      - Workspace folder is "Vanta" (was "Project Rain"); existing files are copied over
        once on first run. Log nuker (utility/security.lua) is hooked first thing.
      - Everything else (folder setup, the aztup table + detach-on-reload, farms, feature
        loader, Auto Parry, UI) is the same sequence as stock.
]]

if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded();
end;

env = getgenv();

-- Log nuker (utility/security.lua). Hook once per executor session - re-running the
-- loadstring shouldn't stack another hook on top of the previous one.
if not env.vanta_log_nuker_active then
    env.vanta_log_nuker_active = require("@src/utility/security");
end;

if not LPH_OBFUSCATED then
    require(LPH_ENCSTR("@src/utility/librarys/luraph_sdk"));
end;

-- One-time migration: the workspace folder used to be "Project Rain". If that exists
-- and "Vanta" doesn't yet, copy everything across (configs, sounds, fonts, farm state)
-- so nothing is lost. The old folder is left in place, untouched.
xpcall(function()
    local OLD_ROOT, NEW_ROOT = "Project " .. "Rain", "Vanta";
    if not isfolder(OLD_ROOT) or isfolder(NEW_ROOT) then
        return;
    end;

    local copied, failed = 0, 0;
    local function copy_dir(from, to)
        makefolder(to);
        for _, path in listfiles(from) do
            local name = path:gsub("\\", "/"):match("([^/]+)$");
            local src, dst = from .. "/" .. name, to .. "/" .. name;
            if isfolder(src) then
                copy_dir(src, dst);
            else
                local ok = pcall(function()
                    writefile(dst, readfile(src));
                end);
                if ok then copied += 1 else failed += 1 end;
            end;
        end;
    end;

    copy_dir(OLD_ROOT, NEW_ROOT);
    print(string.format("[vanta] migrated %d files from '%s' to '%s' (%d failed)", copied, OLD_ROOT, NEW_ROOT, failed));
end, warn);

xpcall(function()
    for _, path in {
        "Vanta",
        "Vanta/Assets",
        "Vanta/Assets/Hit Sounds",
        "Vanta/Assets/Parry Sounds",
        "Vanta/Fonts",
        "Vanta/Deepwoken-Config",
        "Vanta/Deepwoken-Config/CustomGlobalOrnaments",
        "Vanta/Deepwoken-Config/CustomRaces",
        "Vanta/Deepwoken-Config/Preferences",
        "Vanta/Deepwoken-Config/CustomEnchantments",
    } do
        if not isfolder(path) then
            makefolder(path);
        end;
    end;

    if not isfile("Vanta/script_state") then
        writefile("Vanta/script_state", game:GetService("HttpService"):JSONEncode({
            ["last_executed"] = tick(),
            ["last_executed_version"] = "vanta-v2-dev",
            ["build_id"] = game:GetService("HttpService"):GenerateGUID(false),
        }));
    end;
end, warn);

-- Clean up a previous load in this same executor session (re-running the loadstring
-- in Volt without a full game restart) before building a fresh aztup table.
if env.aztup then
    if env.Markers then
        for _, marker in env.Markers:get() do
            marker:Destroy();
        end;
        table.clear(env.Markers._marked_instances);
        table.clear(env.Markers);
        getgenv().Markers = nil;
    end;

    xpcall(function()
        env.aztup:detach();
    end, warn);
    env.aztup = nil;
end;

env.aztup = {
    detach = function(self)
        if self.maid then
            self.maid:do_cleaning();
        end;

        if self.features then
            for _, feature in pairs(self.features) do
                xpcall(function()
                    feature:disable();
                end, function(...)
                    warn(string.format("[detach %s]", feature.id or "none"), ...);
                end);
            end;
        end;

        if self.ui then
            self.ui:Unload();
        end;
    end,
    features = {},
    flags = {},
    farms = {},
    tabs = {},
};

-- Explicitly out of scope (security/licensing infra). Stubbed so anything referencing
-- it as a bare global doesn't error; nothing here actually enforces or phones home.
user_service = { is_valid = function() return true end };
getgenv().user_service = user_service;


env.persistent_data = require("@src/utility/persistent_data");
env.Logger = require(LPH_ENCSTR("@src/utility/logger"));
aztup.automation = require(LPH_ENCSTR("@src/automation/loader"));
env.fflags = require("@src/utility/fflags");

pcall(function()
    if fflags:get("auto_load") and script_key then
        require("@src/utility/setup_auto_load");
    end;
end);

if aztup.automation:should_auto_start() then
    local requests = services.ReplicatedStorage:WaitForChild("Requests");
    local start = requests:WaitForChild("StartMenu"):WaitForChild("Start");
    repeat
        start:FireServer();
        task.wait(0.5);
    until game:GetService("Players").LocalPlayer.Character;
    task.wait(1);
end;

local hook_ok, hook_result = pcall(function()
    return require(LPH_ENCSTR("@src/features/hooking"));
end);

if not hook_ok or not hook_result then
    return game:GetService("Players").LocalPlayer:Kick("[vanta] failed to hook, kicking to prevent bans\n" .. tostring(hook_result));
end;

-- Same as stock init.lua: each inline_asset_b96(...) is replaced by build/bundle.py with
-- base64(zstd(file)) at build time, decoded here and written once to the workspace.
function decode_asset(asset)
    local decoded = services.EncodingService:Base64Decode(buffer.fromstring(asset));
    local decompressed = services.EncodingService:DecompressBuffer(decoded, Enum.CompressionAlgorithm.Zstd);
    return buffer.tostring(decompressed);
end;

task.spawn(pcall, function()
    if not isfile("Vanta/Assets/proximity.mp3") then
        writefile("Vanta/Assets/proximity.mp3", decode_asset(inline_asset_b96("@assets/proximity.mp3")));
    end;
    if not isfile("Vanta/Assets/Parry Sounds/Ultrakill Parry.mp3") then
        writefile("Vanta/Assets/Parry Sounds/Ultrakill Parry.mp3", decode_asset(inline_asset_b96("@assets/Ultrakill Parry.mp3")));
    end;
    if not isfile("Vanta/Assets/notification.mp3") then
        writefile("Vanta/Assets/notification.mp3", decode_asset(inline_asset_b96("@assets/notification.mp3")));
    end;
    if not isfile("Vanta/Deepwoken-Config/GuiItself.rbxm") then
        writefile("Vanta/Deepwoken-Config/GuiItself.rbxm", decode_asset(inline_asset_b96("@assets/DeepwokenMorphs/GuiItself.rbxm")));
    end;
end);

-- Fonts are written synchronously: custom_font.lua (required right below) loads them.
if not isfile("Vanta/Fonts/Lexend.ttf") then
    writefile("Vanta/Fonts/Lexend.ttf", decode_asset(inline_asset_b96("@assets/lexend.ttf")));
end;
if not isfile("Vanta/Fonts/Lexend-Bold.ttf") then
    writefile("Vanta/Fonts/Lexend-Bold.ttf", decode_asset(inline_asset_b96("@assets/lexend-bold.ttf")));
end;
if not isfile("Vanta/Fonts/Lexend-Medium.ttf") then
    writefile("Vanta/Fonts/Lexend-Medium.ttf", decode_asset(inline_asset_b96("@assets/lexend-medium.ttf")));
end;

lexend = require("@src/utility/custom_font");


env.signal = require("@src/utility/signal");
loaded_signal = env.signal.new();
env.LOAD_START_TIME = tick();
aztup.silent_mode = isfile("Vanta/silent_mode_toggle");
aztup.maid = require("@src/utility/maid").new();

if not aztup.ui then
    aztup.ui = require("@src/utility/librarys/ui");
end;

env.server_utility = require("@src/utility/deepwoken/servers");
env.local_player = require("@src/utility/player-data");
env.general = require("@src/utility/deepwoken/general_utilitys");
env.InstanceWatcher = require("@src/utility/instancewatcher");
env.BindableFunction = require("@src/utility/bindablefunction");
env.Markers = require("@src/utility/markers").new();
env.MarkedInstanceCreator = require("@src/utility/markedinstancecreator");
env.StateMachine = require("@src/utility/statemachine");
env.Tween = require("@src/utility/deepwoken/safe_tween");
env.EffectReplicatorHandler = require("@src/utility/deepwoken/effect_replicator_handler");
env.LoopUtil = require("@src/utility/loop");
env.scheduler = require("@src/utility/scheduler");
env.TargetFilter = require("@src/features/auto-parry/util/target-filter");

pcall(function()
    env.ab_builder = require("@src/features/auto-builder/auto_builder");
end);

aztup.automation.initialize();

require("@src/features/auto-parry/block-input-manager");
require("@src/features/loader").initialize();

task.spawn(pcall, function()
    require(LPH_ENCSTR("@src/features/auto-parry/handlers/animator-handler"));
end);

chance_store = require("@src/features/auto-parry/data/chance_store");
getgenv().chance_store = chance_store;

require(LPH_ENCSTR("@src/ui/ui")).initialize();

for _, path in { "@src/features/visuals/player_esp", "@src/features/visuals/base_esp" } do
    local ok, mod = pcall(require, path);
    if ok and typeof(mod) == "function" then
        pcall(mod);
    elseif not ok then
        warn("[vanta] not ported yet, skipping: " .. path);
    end;
end;

if not fflags:get("dont_notify_on_first_exec") and aztup.silent_mode then
    if not persistent_data:get("has_executed_before") then
        messagebox("You have 'Silent Mode' enabled, which means you won't see the UI until you open it with the keybind. This notification is disable-able in the fast flags area of UI.", "Vanta", 0);
    end;

    persistent_data:set("has_executed_before", true);
end;

shared.unloaded = false;
Library:OnUnload(function()
    if shared.unloaded then return end;
    shared.unloaded = true;

    if env.aztup then
        if env.Markers then
            for _, marker in env.Markers:get() do
                marker:Destroy();
            end;
            table.clear(env.Markers._marked_instances);
            table.clear(env.Markers);
            getgenv().Markers = nil;
        end;

        env.aztup:detach();
        env.aztup = nil;
    end;

    Library.Unloaded = true;
end);

if not aztup.silent_mode then
    Logger.log("Not in silent mode.");
end;

Logger.log(string.format("Loaded in %.2fs.", tick() - env.LOAD_START_TIME));
loaded_signal:fire();

-- Resume any automation that was running before the server hop / re-execute
-- (this call is in Rain's original init.lua; it was missing from Vanta's).
xpcall(function()
    if aztup.automation:has_any() then
        aztup.automation:start();
    end;
end, warn);
