--[[
    automation/panel_style.lua (Vanta)

    Restyles the automation on-screen panels (the "Stop Current" panel and the echo
    farm stats panels) to match Vanta: dark card, rounded corners, accent-coloured
    outline / top bar / title (follows your accent colour live), Vanta's UI font,
    and a proper "Stop Current" button that turns red on hover.

    style.apply(frame) is called on each panel's main Frame after it's built.
]]

local style = {};

local BG = Color3.fromRGB(15, 15, 19);
local TEXT = Color3.fromRGB(226, 226, 234);
local STOP_IDLE = Color3.fromRGB(34, 34, 42);
local STOP_HOVER = Color3.fromRGB(160, 48, 60);

local function accent()
    return (Library and Library.AccentColor) or Color3.fromRGB(160, 195, 229)
end

local function register(inst, props)
    if Library and Library.AddToRegistry then
        pcall(Library.AddToRegistry, Library, inst, props);
    end;
end

local function font(weight)
    local family = lexend and lexend.regular and lexend.regular.Family;
    return Font.new(family or "rbxassetid://12187365364", weight, Enum.FontStyle.Normal)
end

local function corner(inst, radius)
    local c = inst:FindFirstChildOfClass("UICorner") or Instance.new("UICorner");
    c.CornerRadius = UDim.new(0, radius);
    c.Parent = inst;
end

local function style_stop_button(button)
    button.BackgroundTransparency = 0;
    button.BackgroundColor3 = STOP_IDLE;
    button.AutoButtonColor = false;
    button.TextColor3 = TEXT;
    button.FontFace = font(Enum.FontWeight.SemiBold);
    button.TextSize = 15;
    button.Size = UDim2.new(1, 0, 0, 24);
    corner(button, 4);

    local stroke = Instance.new("UIStroke");
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
    stroke.Color = accent();
    stroke.Transparency = 0.55;
    stroke.Parent = button;
    register(stroke, { Color = "AccentColor" });

    local TweenService = game:GetService("TweenService");
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
    button.MouseEnter:Connect(function()
        TweenService:Create(button, info, { BackgroundColor3 = STOP_HOVER }):Play();
        TweenService:Create(stroke, info, { Transparency = 1 }):Play();
    end);
    button.MouseLeave:Connect(function()
        TweenService:Create(button, info, { BackgroundColor3 = STOP_IDLE }):Play();
        TweenService:Create(stroke, info, { Transparency = 0.55 }):Play();
    end);
end

function style.apply(frame)
    if not frame then return end;

    -- Card
    frame.BackgroundColor3 = BG;
    frame.BackgroundTransparency = 0.08;
    corner(frame, 6);

    local stroke = Instance.new("UIStroke");
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
    stroke.Color = accent();
    stroke.Transparency = 0.5;
    stroke.Thickness = 1;
    stroke.Parent = frame;
    register(stroke, { Color = "AccentColor" });

    local shade = Instance.new("UIGradient");
    shade.Rotation = 90;
    shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212));
    shade.Parent = frame;

    -- Side padding for the content list
    local objects = frame:FindFirstChild("Objects");
    if objects then
        local padding = objects:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding");
        padding.PaddingLeft = UDim.new(0, 10);
        padding.PaddingRight = UDim.new(0, 10);
        padding.PaddingTop = UDim.new(0, 8);
        padding.PaddingBottom = UDim.new(0, 8);
        padding.Parent = objects;
    end;

    for _, child in frame:GetDescendants() do
        if child:IsA("Frame") and child.Parent == frame and child.Name ~= "Objects" and child.Size.Y.Offset <= 4 then
            -- the thin top bar
            child.BackgroundColor3 = accent();
            child.Position = UDim2.new(0, 8, 0, 0);
            child.Size = UDim2.new(1, -16, 0, 2);
            register(child, { BackgroundColor3 = "AccentColor" });
        elseif child:IsA("TextLabel") then
            child.FontFace = font(child.Name == "title" and Enum.FontWeight.Bold or Enum.FontWeight.Medium);
            if child.Name == "title" then
                child.TextColor3 = accent();
                child.TextXAlignment = Enum.TextXAlignment.Left;
                child.TextSize = 16;
                register(child, { TextColor3 = "AccentColor" });
                local fade = child:FindFirstChildOfClass("UIGradient");
                if fade then fade:Destroy() end;
            elseif child.Name == "time" then
                child.TextColor3 = accent();
                child.TextXAlignment = Enum.TextXAlignment.Right;
                register(child, { TextColor3 = "AccentColor" });
            elseif child.Name == "cycles" then
                child.TextColor3 = TEXT;
                child.TextXAlignment = Enum.TextXAlignment.Right;
            else
                child.TextColor3 = TEXT;
                child.TextXAlignment = Enum.TextXAlignment.Left;
            end;
        elseif child:IsA("TextButton") then
            style_stop_button(child);
        end;
    end;
end

-- "12.34e/m" -> "12.3 / min  ·  741 / hr"
function style.rate_text(per_min)
    return string.format("%.1f / min  ·  %d / hr", per_min, math.floor(per_min * 60 + 0.5))
end

return style;
