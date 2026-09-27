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
      - Everything else (folder setup, the aztup table + detach-on-reload, TOS/config
        picker, farms, feature loader, Auto Parry, UI) is the same sequence as stock.
]]

if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded();
end;

env = getgenv();
if not LPH_OBFUSCATED then
    require(LPH_ENCSTR("@src/utility/librarys/luraph_sdk"));
end;

xpcall(function()
    for _, path in {
        "Project Rain",
        "Project Rain/Assets",
        "Project Rain/Assets/Hit Sounds",
        "Project Rain/Assets/Parry Sounds",
        "Project Rain/Fonts",
        "Project Rain/Deepwoken-Config",
        "Project Rain/Deepwoken-Config/CustomGlobalOrnaments",
        "Project Rain/Deepwoken-Config/CustomRaces",
        "Project Rain/Deepwoken-Config/Preferences",
        "Project Rain/Deepwoken-Config/CustomEnchantments",
    } do
        if not isfolder(path) then
            makefolder(path);
        end;
    end;

    if not isfile("Project Rain/script_state") then
        writefile("Project Rain/script_state", game:GetService("HttpService"):JSONEncode({
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

local hasnt_accepted_tos = not isfile("Project Rain/tos_accepted_82126_0822UTC0.txt");

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
    if not isfile("Project Rain/Assets/proximity.mp3") then
        writefile("Project Rain/Assets/proximity.mp3", decode_asset(inline_asset_b96("@assets/proximity.mp3")));
    end;
    if not isfile("Project Rain/Assets/Parry Sounds/Ultrakill Parry.mp3") then
        writefile("Project Rain/Assets/Parry Sounds/Ultrakill Parry.mp3", decode_asset(inline_asset_b96("@assets/Ultrakill Parry.mp3")));
    end;
    if not isfile("Project Rain/Assets/notification.mp3") then
        writefile("Project Rain/Assets/notification.mp3", decode_asset(inline_asset_b96("@assets/notification.mp3")));
    end;
    if not isfile("Project Rain/Deepwoken-Config/GuiItself.rbxm") then
        writefile("Project Rain/Deepwoken-Config/GuiItself.rbxm", decode_asset(inline_asset_b96("@assets/DeepwokenMorphs/GuiItself.rbxm")));
    end;
end);

-- Fonts are written synchronously: custom_font.lua (required right below) loads them.
if not isfile("Project Rain/Fonts/Lexend.ttf") then
    writefile("Project Rain/Fonts/Lexend.ttf", decode_asset(inline_asset_b96("@assets/lexend.ttf")));
end;
if not isfile("Project Rain/Fonts/Lexend-Bold.ttf") then
    writefile("Project Rain/Fonts/Lexend-Bold.ttf", decode_asset(inline_asset_b96("@assets/lexend-bold.ttf")));
end;
if not isfile("Project Rain/Fonts/Lexend-Medium.ttf") then
    writefile("Project Rain/Fonts/Lexend-Medium.ttf", decode_asset(inline_asset_b96("@assets/lexend-medium.ttf")));
end;

lexend = require("@src/utility/custom_font");

if hasnt_accepted_tos then
    pcall(function()
        require(LPH_ENCSTR("@src/ui/tos"));

        if not isfile("Project Rain\\Deepwoken-Config\\settings\\default_conf.json")
            and not isfile("Project Rain/inquired_about_default_config.txt")
            and not isfile("Project Rain\\Deepwoken-Config\\settings\\autoload.txt") then
            writefile("Project Rain/inquired_about_default_config.txt", "true");
            require(LPH_ENCSTR("@src/ui/choice_frame")).set(nil,
                function()
                    local ok, config_content = pcall(game.HttpGet, game, "https://files.project-rain.net/configs/premade.json");
                    if ok then
                        writefile("Project Rain\\Deepwoken-Config\\settings\\default_conf.json", config_content);
                        writefile("Project Rain\\Deepwoken-Config\\settings\\autoload.txt", "default_conf");
                    end;
                end,
                function() end
            );
        end;
    end);

    task.wait(1.5);
end;

env.signal = require("@src/utility/signal");
loaded_signal = env.signal.new();
env.LOAD_START_TIME = tick();
aztup.silent_mode = isfile("Project Rain/silent_mode_toggle");
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
        messagebox("You have 'Silent Mode' enabled, which means you won't see the UI until you open it with the keybind. This notification is disable-able in the fast flags area of UI.", "Project Rain", 0);
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
