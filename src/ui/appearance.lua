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

    create_glow(Library.PRWindow.Holder);

    if saved_font ~= "Lexend" then
        apply_font(saved_font);
    end;
end

return Appearance;
