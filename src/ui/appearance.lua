--[[
    ui/appearance.lua (vanta-v2)

    Vanta-only UI settings, shown as an "Appearance" groupbox on the UI tab:

      Edge Glow   - a soft glow around the main window's border in the current accent
                    colour. Built from layered UIStrokes (no image assets). Every stroke
                    is registered with the library's theme registry as 'AccentColor', so
                    it recolours itself whenever the accent changes (ThemeManager, colour
                    picker, config load).

      UI Font     - Lexend (original), Gotham, Montserrat, Roboto Mono, plus any
                    .ttf/.otf dropped into workspace/Vanta/Fonts/Custom. Switches live:
                    every text object in the UI library's ScreenGui gets the new family
                    (keeping its weight/style), and text created later (notifications,
                    dropdown lists, tooltips) is converted as it appears. Only the UI
                    library's own ScreenGui is touched - game UI and other script windows
                    are left alone. The choice is remembered in Vanta/ui_font.txt.
]]

local Appearance = {};

local HttpService = game:GetService("HttpService");

--------------------------------------------------------------------------- edge glow

local GLOW_LAYERS = 10;

local glow = {
    enabled = true,
    size = 14,        -- px the glow reaches out from the border
    intensity = 45,   -- % opacity right at the border
    folder = nil,
    strokes = {},
};

local function update_glow()
    if not glow.folder then return end;

    -- Layers overlap: the band closest to the border is covered by every layer, the
    -- outermost by just one, so opacity fades outward. Per-layer alpha is chosen so all
    -- layers stacked together reach `intensity` at the border.
    local target = math.clamp(glow.intensity / 100, 0, 0.95);
    local per_layer_alpha = 1 - (1 - target) ^ (1 / GLOW_LAYERS);

    for i, stroke in glow.strokes do
        stroke.Thickness = math.max(1, glow.size * i / GLOW_LAYERS);
        stroke.Transparency = 1 - per_layer_alpha;
        stroke.Enabled = glow.enabled;
    end;
end

local function create_glow(holder)
    if glow.folder then return end;

    local folder = Instance.new("Folder");
    folder.Name = "VantaEdgeGlow";

    for i = 1, GLOW_LAYERS do
        local layer = Instance.new("Frame");
        layer.Name = "GlowLayer" .. i;
        layer.BackgroundTransparency = 1;
        layer.BorderSizePixel = 0;
        layer.Size = UDim2.fromScale(1, 1);
        layer.ZIndex = 0; -- global ZIndex: stays under the window and any popup
        layer.Parent = folder;

        local stroke = Instance.new("UIStroke");
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        stroke.LineJoinMode = Enum.LineJoinMode.Miter; -- the window has square corners
        stroke.Color = Library.AccentColor;
        stroke.Parent = layer;

        Library:AddToRegistry(stroke, { Color = "AccentColor" });
        glow.strokes[i] = stroke;
    end;

    folder.Parent = holder; -- child of the window frame: moves, scales and hides with it
    glow.folder = folder;
    update_glow();
end

--------------------------------------------------------------------------- fonts

local CUSTOM_FONT_DIR = "Vanta/Fonts/Custom";
local FONT_SAVE_FILE = "Vanta/ui_font.txt";

local families = {};      -- display name -> font family (asset id string)
local known_families = {}; -- family -> true, for everything we're allowed to swap
local font_order = {};
local current_family;

local function register_family(name, family)
    if not family or families[name] then return end;
    families[name] = family;
    known_families[family] = true;
    table.insert(font_order, name);
end

local function load_custom_fonts()
    if not isfolder(CUSTOM_FONT_DIR) then
        pcall(makefolder, CUSTOM_FONT_DIR);
        return;
    end;

    for _, path in listfiles(CUSTOM_FONT_DIR) do
        local file = path:gsub("\\", "/"):match("([^/]+)$");
        local name, ext = file:match("^(.+)%.(%a+)$");
        ext = ext and ext:lower();
        if name and (ext == "ttf" or ext == "otf") then
            local ok, family = pcall(function()
                -- One file serves every weight, so bold/medium text doesn't fall back
                -- to Roblox's default font.
                local asset = getcustomasset(CUSTOM_FONT_DIR .. "/" .. file);
                local faces = {};
                for _, face in { { "Regular", 400 }, { "Medium", 500 }, { "Bold", 700 } } do
                    table.insert(faces, { name = face[1], weight = face[2], style = "normal", assetId = asset });
                end;
                local json_path = CUSTOM_FONT_DIR .. "/" .. name .. ".family.json";
                writefile(json_path, HttpService:JSONEncode({ name = name, faces = faces }));
                return getcustomasset(json_path);
            end);
            if ok then
                register_family(name .. " (custom)", family);
            else
                warn("[vanta] couldn't load custom font " .. file .. ": " .. tostring(family));
            end;
        end;
    end;
end

local function build_font_list()
    register_family("Lexend", lexend and lexend.regular and lexend.regular.Family);
    register_family("Gotham", Font.fromEnum(Enum.Font.Gotham).Family);
    register_family("Montserrat", Font.fromEnum(Enum.Font.Montserrat).Family);
    register_family("Roboto Mono", Font.fromEnum(Enum.Font.RobotoMono).Family);
    load_custom_fonts();
end

local function retarget(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end;
    local face = obj.FontFace;
    if face.Family == current_family or not known_families[face.Family] then return end;
    obj.FontFace = Font.new(current_family, face.Weight, face.Style);
end

local function apply_font(name)
    local family = families[name];
    if not family then return end;
    current_family = family;

    -- Elements created from now on (the library reads these when building text).
    Library.Font = Font.new(family, Enum.FontWeight.Regular, Enum.FontStyle.Normal);
    if lexend then
        lexend.regular = Font.new(family, Enum.FontWeight.Regular, Enum.FontStyle.Normal);
        lexend.medium = Font.new(family, Enum.FontWeight.Medium, Enum.FontStyle.Normal);
        lexend.bold = Font.new(family, Enum.FontWeight.Bold, Enum.FontStyle.Normal);
    end;

    -- Everything that already exists.
    for _, obj in Library.ScreenGui:GetDescendants() do
        retarget(obj);
    end;

    pcall(writefile, FONT_SAVE_FILE, name);
end

--------------------------------------------------------------------------- window controls

--[[
    Minimise / maximise buttons in the top-left of the title bar, both animated.
      Minimise: window folds up to just its title bar (click again to unfold).
      Maximise: window grows to fill most of the screen, centred (click again to go
                back to the size and place it was before).
    They combine: minimising a maximised window folds it at its maximised width, and
    unfolding returns it to maximised.
]]
local TweenService = game:GetService("TweenService");
local TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
local TITLE_HEIGHT = 23;

local function add_window_controls(window)
    local outer, inner, main = window.Holder, window.Inner, window.MainSection;
    if not (outer and inner and main) then return end

    local state = {
        minimised = false,
        maximised = false,
        normal_size = outer.Size,
        normal_position = outer.Position,
        tween = nil,
    };

    local function screen_size()
        local camera = workspace.CurrentCamera;
        local scale = (Library.GetUIScale and Library:GetUIScale()) or 1;
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720);
        return viewport / scale;
    end

    local function target()
        local size, position;
        if state.maximised then
            local screen = screen_size();
            size = UDim2.fromOffset(math.floor(screen.X * 0.9), math.floor(screen.Y * 0.88));
            -- Centre regardless of the window's anchor point.
            local anchor = outer.AnchorPoint;
            position = UDim2.new(0.5, (anchor.X - 0.5) * size.X.Offset, 0.5, (anchor.Y - 0.5) * size.Y.Offset);
        else
            size, position = state.normal_size, state.normal_position;
        end;
        if state.minimised then
            size = UDim2.new(size.X.Scale, size.X.Offset, 0, TITLE_HEIGHT);
        end;
        return size, position;
    end

    local function apply(instant)
        if state.tween then state.tween:Cancel() end;
        local size, position = target();

        if state.minimised then
            main.Visible = false; -- hide the contents first, then fold up
        end;

        if instant then
            outer.Size, outer.Position = size, position;
            main.Visible = not state.minimised;
            return
        end;

        local tween = TweenService:Create(outer, TWEEN, { Size = size, Position = position });
        state.tween = tween;
        tween.Completed:Connect(function(status)
            if status == Enum.PlaybackState.Completed and not state.minimised then
                main.Visible = true; -- unfolded: show contents again
            end;
        end);
        tween:Play();
    end

    -- Icons are drawn with frames (not font glyphs) so they look the same in every
    -- UI font.
    local function icon_bar(parent)
        local bar = Library:Create('Frame', {
            BackgroundColor3 = Library.FontColor;
            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.fromScale(0.5, 0.62);
            Size = UDim2.fromOffset(8, 2);
            ZIndex = 3;
            Parent = parent;
        });
        Library:AddToRegistry(bar, { BackgroundColor3 = 'FontColor' });
        return bar;
    end

    local function icon_box(parent)
        local box = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.fromOffset(8, 8);
            ZIndex = 3;
            Parent = parent;
        });
        local stroke = Instance.new("UIStroke");
        stroke.Color = Library.FontColor;
        stroke.Thickness = 1;
        stroke.Parent = box;
        Library:AddToRegistry(stroke, { Color = 'FontColor' });
        return box;
    end

    local function make_button(x, tip)
        local button = Library:Create('TextButton', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Position = UDim2.fromOffset(x, 2);
            Size = UDim2.fromOffset(17, 17);
            AutoButtonColor = false;
            Text = "";
            ZIndex = 2;
            Parent = inner;
        });
        Library:AddToRegistry(button, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });
        button.MouseEnter:Connect(function()
            button.BorderColor3 = Library.AccentColor;
        end);
        button.MouseLeave:Connect(function()
            button.BorderColor3 = Library.OutlineColor;
        end);
        if Library.AddToolTip and tip then
            pcall(Library.AddToolTip, Library, tip, button);
        end;
        Library.DragBlockers = Library.DragBlockers or {};
        table.insert(Library.DragBlockers, button);
        return button;
    end

    local minimise_button = make_button(3, "Minimise / unfold");
    local minimise_icon = icon_bar(minimise_button);
    local maximise_button = make_button(23, "Maximise / restore");
    local maximise_icon = icon_box(maximise_button);

    minimise_button.MouseButton1Click:Connect(function()
        if not state.maximised then
            -- Keep wherever the user has dragged it to.
            state.normal_position = outer.Position;
            if not state.minimised then
                state.normal_size = outer.Size;
            end;
        end;
        state.minimised = not state.minimised;
        -- Bar sits low when unfolded ("_"), centred when folded.
        minimise_icon.Position = UDim2.fromScale(0.5, state.minimised and 0.5 or 0.62);
        apply();
    end);

    local controls = {};
    function controls.set_minimised(on, instant)
        if state.minimised == on then return end;
        if not state.maximised then
            state.normal_position = outer.Position;
            if not state.minimised then
                state.normal_size = outer.Size;
            end;
        end;
        state.minimised = on;
        minimise_icon.Position = UDim2.fromScale(0.5, on and 0.5 or 0.62);
        apply(instant);
    end

    maximise_button.MouseButton1Click:Connect(function()
        if not state.maximised then
            -- Remember where the user had it (they may have dragged it since load).
            state.normal_position = outer.Position;
            if not state.minimised then
                state.normal_size = outer.Size;
            end;
        end;
        state.maximised = not state.maximised;
        -- Smaller box while maximised = "restore".
        maximise_icon.Size = state.maximised and UDim2.fromOffset(6, 6) or UDim2.fromOffset(8, 8);
        apply();
    end);

    return controls
end

--------------------------------------------------------------------------- settings UI

function Appearance.build(ui_tab)
    build_font_list();

    -- Text created after this point (notifications, dropdown lists, tooltips, ...).
    Library:GiveSignal(Library.ScreenGui.DescendantAdded:Connect(function(obj)
        if current_family then
            task.defer(retarget, obj);
        end;
    end));

    local saved_font = isfile(FONT_SAVE_FILE) and readfile(FONT_SAVE_FILE) or "Lexend";
    if not families[saved_font] then saved_font = "Lexend" end;

    local box = ui_tab:newGroupBox("Appearance", false);

    box:newToggle("edge_glow", "Edge Glow", glow.enabled, "Soft glow around the window border in your accent colour.", function(on)
        glow.enabled = on;
        update_glow();
    end);

    box:newSlider("edge_glow_size", "Glow Size", glow.size, 2, 40, 0, true, "px", function(value)
        aztup.flags.edge_glow_size = value;
        glow.size = value;
        update_glow();
    end, "How far the glow reaches out from the border.");

    box:newSlider("edge_glow_intensity", "Glow Intensity", glow.intensity, 5, 95, 0, true, "%", function(value)
        aztup.flags.edge_glow_intensity = value;
        glow.intensity = value;
        update_glow();
    end, "How bright the glow is right at the border.");

    box:newDropdown("ui_font", "UI Font", font_order, saved_font, false,
        "Font for the whole menu. Drop a .ttf/.otf into workspace/Vanta/Fonts/Custom and re-execute to add your own.",
        function(value)
            apply_font(value);
        end);

    -- Start Hidden: menu, watermark and keybind list stay hidden after executing
    -- until the menu is opened for the first time. Saved outside configs
    -- (fflag "dont_auto_show_ui", read when the window is created).
    box:newToggle("start_hidden", "Start Hidden", fflags:get("dont_auto_show_ui") == true,
        "When you execute, nothing shows (no menu, watermark, keybind list or 'config loaded' popup) until you press your menu key. Takes effect next execute.",
        function(on)
            fflags:set("dont_auto_show_ui", on == true);
        end);

    if fflags:get("dont_auto_show_ui") and not Library.Toggled then
        local hide_conn;
        hide_conn = services.RunService.Heartbeat:Connect(function()
            if Library.Toggled or Library.Unloaded then
                hide_conn:Disconnect();
                -- First time the menu opens: bring back whatever the user has on.
                if aztup_toggles.Watermark then
                    Library:SetWatermarkVisibility(aztup_toggles.Watermark.Value);
                end;
                if Library.KeybindFrame and aztup_toggles.KeybindShower then
                    Library.KeybindFrame.Visible = aztup_toggles.KeybindShower.Value;
                end;
                return;
            end;
            if Library.Watermark and Library.Watermark.Visible then
                Library.Watermark.Visible = false;
            end;
            if Library.KeybindFrame and Library.KeybindFrame.Visible then
                Library.KeybindFrame.Visible = false;
            end;
        end);
        Library:GiveSignal(hide_conn);
    end;

    create_glow(Library.PRWindow.Holder);
    local controls_ok, controls = pcall(add_window_controls, Library.PRWindow);
    if not controls_ok then
        warn("[vanta] window controls: " .. tostring(controls));
        controls = nil;
    end;

    -- Start Minimized: the menu opens folded up to just its title bar.
    box:newToggle("start_minimized", "Start Minimized", fflags:get("start_minimized") == true,
        "When you execute, the menu starts folded up to its title bar (click the bar button to unfold). Takes effect next execute.",
        function(on)
            fflags:set("start_minimized", on == true);
        end);
    if controls and fflags:get("start_minimized") then
        controls.set_minimised(true, true);
    end;

    if saved_font ~= "Lexend" then
        apply_font(saved_font);
    end;
end

return Appearance;
