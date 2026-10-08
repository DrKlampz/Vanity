-- Photo: the studio. Backgrounds, poses, turntable, and a screenshot that hides the UI.
local ADDON_NAME, V = ...
local P = {}
V.Photo = P
local View = V.View

local BACKGROUNDS = { "dark", "class", "light", "green", "world" }
local BG_LABEL = { dark = "Dark", class = "Class color", light = "Light", green = "Green screen", world = "The world" }
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
    if c then return c.r * 0.35, c.g * 0.35, c.b * 0.35 end
    return 0.1, 0.1, 0.1
end

function P.ApplyBackground()
    local bg = View.bg
    if not bg then return end
    local kind = V.db.background
    if kind == "world" then bg:SetColorTexture(0, 0, 0, 0)
    elseif kind == "light" then bg:SetColorTexture(0.85, 0.85, 0.85, 1)
    elseif kind == "green" then bg:SetColorTexture(0, 0.9, 0.1, 1)
    elseif kind == "class" then local r, g, b = ClassColor() bg:SetColorTexture(r, g, b, 1)
    else bg:SetColorTexture(0.03, 0.03, 0.05, 1) end
end

function P.CycleBackground()
    local idx = 1
    for i, k in ipairs(BACKGROUNDS) do if k == V.db.background then idx = i end end
    V.db.background = BACKGROUNDS[idx % #BACKGROUNDS + 1]
    P.ApplyBackground()
    if bar and bar.bgBtn then bar.bgBtn:SetText(BG_LABEL[V.db.background]) end
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
    P.ApplyBackground()
end

function P.Leave()
    if not active then return end
    active = false
    if bar then bar:Hide() end
    View.SetPanels(true)
    View.Refresh()
    local model = View.GetModel()
    if model then pcall(model.SetAnimation, model, 0) end
    poseIndex = 1
    if V.db and V.db.background == "world" then P.ApplyBackground() end
end

function P.Toggle()
    if active then P.Leave() else P.Enter() end
end

function P.IsActive() return active end

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
