-- Photo: the studio. Backgrounds, poses, turntable, and a screenshot that hides the UI.
local ADDON_NAME, V = ...
local P = {}
V.Photo = P
local View = V.View

-- Each theme: stage colors (base, floor glow) or a flat color. "class" and "faction" are computed.
local THEMES = {
    { id = "dark",     label = "Midnight",     base = { 0.05, 0.05, 0.08 }, floor = { 0.30, 0.28, 0.40 } },
    { id = "class",    label = "Class color" },
    { id = "faction",  label = "Faction" },
    { id = "ember",    label = "Ember",        base = { 0.10, 0.04, 0.02 }, floor = { 0.95, 0.40, 0.08 } },
    { id = "frost",    label = "Frost",        base = { 0.03, 0.07, 0.12 }, floor = { 0.30, 0.65, 0.95 } },
    { id = "forest",   label = "Forest",       base = { 0.03, 0.09, 0.05 }, floor = { 0.30, 0.80, 0.35 } },
    { id = "void",     label = "Void",         base = { 0.06, 0.03, 0.10 }, floor = { 0.65, 0.30, 0.95 } },
    { id = "gold",     label = "Gilded",       base = { 0.10, 0.08, 0.03 }, floor = { 0.95, 0.75, 0.25 } },
    { id = "sunset",   label = "Sunset",       base = { 0.12, 0.05, 0.08 }, floor = { 1.00, 0.45, 0.45 } },
    { id = "slate",    label = "Slate",        base = { 0.10, 0.11, 0.13 }, floor = { 0.55, 0.60, 0.68 } },
    { id = "black",    label = "Pure black",   flat = { 0, 0, 0 } },
    { id = "light",    label = "Studio white", flat = { 0.86, 0.86, 0.88 } },
    { id = "green",    label = "Green screen", flat = { 0, 0.9, 0.1 } },
    { id = "world",    label = "The world",    flat = false },
}
P.THEMES = THEMES
local BY_ID = {}
for _, t in ipairs(THEMES) do BY_ID[t.id] = t end
local BG_LABEL = setmetatable({}, { __index = function(_, k) return BY_ID[k] and BY_ID[k].label or tostring(k) end })

-- Animation ids the player model understands
local POSES = {
    { "Stand", 0 }, { "Walk", 4 }, { "Run", 5 }, { "Wave", 67 }, { "Cheer", 68 }, { "Dance", 69 },
    { "Laugh", 70 }, { "Bow", 66 }, { "Kneel", 75 }, { "Roar", 74 }, { "Sit", 72 }, { "Applaud", 80 },
}
local poseIndex = 1
local bar, active = nil, false

local function ClassColor()
    local _, cls = UnitClass("player")
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return c.r, c.g, c.b end
    return 0.85, 0.65, 0.25
end

-- Gradient between two RGBA colors, whichever way this client wants the arguments
local function Grad(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    if not tex then return end
    local ok = false
    if CreateColor and tex.SetGradient then
        ok = pcall(tex.SetGradient, tex, orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    end
    if not ok and tex.SetGradientAlpha then
        pcall(tex.SetGradientAlpha, tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    end
end

function P.ApplyBackground()
    local bg = View.bg
    if not bg then return end
    local theme = BY_ID[V.db.background] or BY_ID.dark
    local layers = { View.top, View.floor, View.edgeL, View.edgeR }
    local function showLayers(on) for _, t in ipairs(layers) do if t then t:SetShown(on) end end end
    if theme.flat == false then
        -- the live world: dim the interface behind us, unless it is hidden entirely
        local dim = (View.UIHidden and View.UIHidden()) and 0 or 0.6
        bg:SetColorTexture(0, 0, 0, dim) showLayers(false) return
    elseif theme.flat then
        bg:SetColorTexture(theme.flat[1], theme.flat[2], theme.flat[3], 1) showLayers(false) return
    end
    local base, floor = theme.base, theme.floor
    if theme.id == "class" then
        local cr, cg, cb = ClassColor()
        base, floor = { cr * 0.18 + 0.03, cg * 0.18 + 0.03, cb * 0.18 + 0.04 }, { cr, cg, cb }
    elseif theme.id == "faction" then
        local f = UnitFactionGroup and UnitFactionGroup("player")
        if f == "Alliance" then base, floor = { 0.03, 0.06, 0.14 }, { 0.25, 0.50, 1.0 }
        else base, floor = { 0.12, 0.03, 0.03 }, { 0.95, 0.20, 0.15 } end
    end
    local k = V.db.brightness or 1
    local function c(v) return math.min(1, v * k) end
    bg:SetColorTexture(c(base[1]), c(base[2]), c(base[3]), 1)
    showLayers(true)
    local stage = V.db.stageLight ~= false
    Grad(View.top, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.85)
    if stage then
        Grad(View.floor, "VERTICAL", c(floor[1] * 0.75), c(floor[2] * 0.75), c(floor[3] * 0.75), 0.9, 0, 0, 0, 0)
    else
        Grad(View.floor, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0)
    end
    local e = V.db.vignette ~= false and 0.75 or 0
    Grad(View.edgeL, "HORIZONTAL", 0, 0, 0, e, 0, 0, 0, 0)
    Grad(View.edgeR, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, e)
end

function P.SetBackground(id)
    if not BY_ID[id] then return end
    V.db.background = id
    P.ApplyBackground()
    if bar and bar.bgBtn then bar.bgBtn:SetText(BG_LABEL[id]) end
    if P.OnThemeChanged then P.OnThemeChanged() end
end

function P.CycleBackground()
    local idx = 1
    for i, t in ipairs(THEMES) do if t.id == V.db.background then idx = i end end
    P.SetBackground(THEMES[idx % #THEMES + 1].id)
    V.Print("Background: " .. BG_LABEL[V.db.background])
end

function P.SetPose(i)
    poseIndex = ((i - 1) % #POSES) + 1
    local model = View.GetModel()
    if model then pcall(model.SetAnimation, model, POSES[poseIndex][2]) end
    if bar and bar.poseBtn then bar.poseBtn:SetText(POSES[poseIndex][1]) end
end

local function MakeBar()
    if bar then return end
    bar = CreateFrame("Frame", "VanityStudioBar", View.GetFrame())
    bar:SetSize(560, 36)
    bar:SetPoint("BOTTOM", View.GetFrame(), "BOTTOM", 0, 24)
    bar.bgBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.poseBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.spinBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.shotBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.exitBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    local btns = { bar.bgBtn, bar.poseBtn, bar.spinBtn, bar.shotBtn, bar.exitBtn }
    local x = 0
    for _, b in ipairs(btns) do b:SetSize(104, 24) b:SetPoint("LEFT", bar, "LEFT", x, 0) x = x + 114 end
    bar.bgBtn:SetText(BG_LABEL[V.db.background])
    bar.bgBtn:SetScript("OnClick", P.CycleBackground)
    bar.poseBtn:SetText(POSES[poseIndex][1])
    bar.poseBtn:SetScript("OnClick", function() P.SetPose(poseIndex + 1) end)
    bar.spinBtn:SetText("Turntable")
    bar.spinBtn:SetScript("OnClick", function() V.db.spin = not V.db.spin V.Print("Turntable " .. (V.db.spin and "on" or "off")) end)
    bar.shotBtn:SetText("Screenshot")
    bar.shotBtn:SetScript("OnClick", P.Screenshot)
    bar.exitBtn:SetText("Exit photo mode")
    bar.exitBtn:SetScript("OnClick", P.Leave)
    bar:Hide()
end

function P.Enter()
    View.Build()
    local f = View.GetFrame()
    if not f:IsShown() then f:Show() end
    MakeBar()
    active = true
    View.photoLock = false
    View.SetPanels(false)
    bar:Show()
    View.UpdateUI()
    P.ApplyBackground()
end

function P.Leave()
    if not active then return end
    active = false
    if bar then bar:Hide() end
    View.SetPanels(true)
    View.Refresh()
    View.UpdateUI()
    local model = View.GetModel()
    if model then pcall(model.SetAnimation, model, 0) end
    poseIndex = 1
    if V.db and V.db.background == "world" then P.ApplyBackground() end
end

function P.Toggle()
    if active then P.Leave() else P.Enter() end
end

function P.IsActive() return active end

-- Camera presets: zoom (smaller = closer) and how far the model is lowered so the framing is right.
P.CAMERAS = {
    { "full",  "Full body", 1.0,  0 },
    { "waist", "Waist up",  0.62, -0.30 },
    { "bust",  "Bust",      0.42, -0.50 },
    { "face",  "Portrait",  0.26, -0.62 },
}
function P.SetCamera(id)
    for _, c in ipairs(P.CAMERAS) do
        if c[1] == id then
            V.db.camera = id
            View.SetCamera(c[3], 0, c[4])
            return
        end
    end
end

-- Hide the controls, take the picture, bring them back.
function P.Screenshot()
    if not bar then return end
    bar:Hide()
    C_Timer.After(0.3, function()
        local ok, err = pcall(Screenshot)
        if not ok then V.Print("Couldn't take the screenshot: " .. tostring(err)) end
        C_Timer.After(1.2, function() if active then bar:Show() end end)
    end)
end

V.AddHook("loaded", function() P.ApplyBackground() end)
