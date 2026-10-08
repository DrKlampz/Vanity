-- Settings: backgrounds, camera, and display options, in a panel inside the showcase.
local ADDON_NAME, V = ...
local S = {}
V.Settings = S
local View, P = V.View, V.Photo

local panel
local refreshers = {}

local function Label(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    return fs
end

local function Check(parent, text, key, after)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = Label(parent, "GameFontHighlight", text)
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb:SetScript("OnClick", function(self)
        V.db[key] = self:GetChecked() and true or false
        if after then after() end
    end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(V.db[key] and true or false) end
    return cb
end

-- A button that steps through choices: { {value, label}, ... }
local function Cycle(parent, text, choices, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 24)
    local fs = Label(row, "GameFontHighlight", text)
    fs:SetPoint("LEFT", 4, 0)
    local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:SetPoint("RIGHT", 0, 0)
    local function show()
        local cur = get()
        for _, c in ipairs(choices) do if c[1] == cur then b:SetText(c[2]) return end end
        b:SetText(choices[1][2])
    end
    b:SetScript("OnClick", function()
        local cur, idx = get(), 1
        for i, c in ipairs(choices) do if c[1] == cur then idx = i end end
        local nxt = choices[idx % #choices + 1]
        set(nxt[1])
        show()
    end)
    refreshers[#refreshers + 1] = show
    row.show = show
    return row
end

local function Build()
    if panel then return end
    View.Build()
    panel = CreateFrame("Frame", "VanitySettings", View.GetFrame())
    panel:SetSize(310, 640)
    panel:SetPoint("TOPLEFT", View.GetFrame(), "TOPLEFT", 40, -100)
    panel:SetFrameLevel((tonumber(View.GetFrame():GetFrameLevel()) or 1) + 20)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.72)
    panel.bg = bg
    panel:Hide()

    local y = -12
    local function Header(text)
        local fs = Label(panel, "GameFontNormal", text)
        fs:SetPoint("TOPLEFT", 12, y)
        y = y - 22
    end

    Header("Background")
    panel.swatches = {}
    local col, row = 0, 0
    for _, t in ipairs(P.THEMES) do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(92, 26)
        b:SetPoint("TOPLEFT", 12 + col * 96, y - row * 30)
        local tex = b:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        local c = t.flat or (t.floor) or { 0.4, 0.4, 0.45 }
        if t.flat == false then c = { 0.2, 0.3, 0.2 } end
        tex:SetColorTexture(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1)
        local sel = b:CreateTexture(nil, "OVERLAY")
        sel:SetPoint("TOPLEFT", -2, 2) sel:SetPoint("BOTTOMRIGHT", 2, -2)
        sel:SetColorTexture(1, 0.82, 0.2, 1)
        sel:SetDrawLayer("BACKGROUND", -1)
        b.sel = sel
        local fs = Label(b, "GameFontNormalSmall", t.label)
        fs:SetPoint("CENTER")
        b:SetScript("OnClick", function() P.SetBackground(t.id) S.Refresh() end)
        b.id = t.id
        panel.swatches[#panel.swatches + 1] = b
        col = col + 1
        if col == 3 then col = 0 row = row + 1 end
    end
    y = y - (row + (col > 0 and 1 or 0)) * 30 - 8

    local function Place(w) w:SetPoint("TOPLEFT", 12, y) y = y - 28 end
    Place(Cycle(panel, "Brightness", { { 0.7, "Dim" }, { 1, "Normal" }, { 1.4, "Bright" } },
        function() return V.db.brightness end, function(v) V.db.brightness = v P.ApplyBackground() end))
    Place(Check(panel, "Floor glow", "stageLight", P.ApplyBackground))
    Place(Check(panel, "Darkened edges", "vignette", P.ApplyBackground))

    y = y - 6
    Header("Camera")
    local choices = {}
    for _, c in ipairs(P.CAMERAS) do choices[#choices + 1] = { c[1], c[2] } end
    Place(Cycle(panel, "Framing", choices, function() return V.db.camera end, function(v) P.SetCamera(v) end))
    Place(Cycle(panel, "Turntable", { { true, "On" }, { false, "Off" } },
        function() return V.db.spin end, function(v) V.db.spin = v end))
    Place(Cycle(panel, "Turntable speed", { { 0.2, "Slow" }, { 0.35, "Normal" }, { 0.7, "Fast" } },
        function() return V.db.spinSpeed end, function(v) V.db.spinSpeed = v end))

    y = y - 6
    Header("Showcase")
    Place(Check(panel, "Stats panel", "showStats", View.ApplyPrefs))
    Place(Check(panel, "Slot names", "showLabels", View.ApplyPrefs))
    Place(Check(panel, "Controls hint", "showHint", View.ApplyPrefs))
    Place(Check(panel, "Button on the character window", "charButton", function()
        if View.charBtn then View.charBtn:SetShown(V.db.charButton) end
    end))

    y = y - 6
    Header("AFK screen")
    Place(Check(panel, "Show Vanity when I go AFK", "afkScreen"))
    Place(Cycle(panel, "Game interface", { { "auto", "Hide in AFK/photo" }, { "never", "Leave it on" } },
        function() return V.db.hideUI end, function(v) V.db.hideUI = v View.UpdateUI() end))
    Place(Check(panel, "Cycle poses while AFK", "afkPoses"))
    Place(Check(panel, "24-hour clock", "clock24"))
    local prev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    prev:SetSize(140, 22)
    prev:SetPoint("TOPLEFT", 12, y)
    prev:SetText("Preview AFK screen")
    prev:SetScript("OnClick", function() panel:Hide() if V.AFK then V.AFK.manual = true V.AFK.Enter() end end)
    panel:SetHeight(-y + 40)
end

function S.Refresh()
    if not panel then return end
    for _, fn in ipairs(refreshers) do fn() end
    for _, b in ipairs(panel.swatches) do b.sel:SetShown(b.id == V.db.background) end
end

function S.Toggle()
    Build()
    if panel:IsShown() then panel:Hide() else panel:Show() S.Refresh() end
end

function S.IsShown() return panel and panel:IsShown() end
P.OnThemeChanged = S.Refresh
