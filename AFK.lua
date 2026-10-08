-- AFK: when you go AFK, Vanity takes over the screen with your character, a timer and a clock.
local ADDON_NAME, V = ...
local A = {}
V.AFK = A
local View = V.View

-- Keys that should not count as "I'm back": taking a screenshot, and modifier keys
local IGNORED_KEYS = {
    PRINTSCREEN = true, LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, CAPSLOCK = true, SCROLLLOCK = true, NUMLOCK = true,
}

local POSES = { 72, 67, 70, 69, 68, 66, 75, 80 }   -- sit, wave, laugh, dance, cheer, bow, kneel, applaud
local active, startedAt = false, 0
local overlay, nextPose, poseIdx, standing = nil, 0, 0, true
local openedByUs = false
local fade = 1
local tipIdx, nextTip = 0, 0

local function Format(sec)
    sec = math.floor(sec)
    local h, m = math.floor(sec / 3600), math.floor(sec / 60) % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, sec % 60) end
    return ("%d:%02d"):format(m, sec % 60)
end

local function Build()
    if overlay then return end
    local f = View.GetFrame()
    overlay = CreateFrame("Frame", "VanityAFK", f)
    overlay:SetAllPoints(f)
    overlay:Hide()
    local function Text(template, point, x, y, size)
        local fs = overlay:CreateFontString(nil, "OVERLAY", template)
        fs:SetPoint(point, f, point, x, y)
        if size then pcall(fs.SetFont, fs, "Fonts\\MORPHEUS.TTF", size, "OUTLINE") end
        return fs
    end
    overlay.title = Text("GameFontNormalHuge", "BOTTOM", 0, 262, 40)
    overlay.title:SetText("A  F  K")
    overlay.title:SetTextColor(1, 0.35, 0.3)
    overlay.timer = Text("GameFontNormalHuge", "BOTTOM", 0, 208, 48)
    overlay.timer:SetTextColor(0.95, 0.8, 0.4)
    overlay.clock = Text("GameFontHighlightLarge", "TOPRIGHT", -56, -52, 26)
    overlay.date = Text("GameFontDisableSmall", "TOPRIGHT", -56, -84)
    overlay.tip = Text("GameFontHighlight", "BOTTOM", 0, 150)
    -- gold rules either side of the title
    local function Rule(side)
        local t = overlay:CreateTexture(nil, "ARTWORK")
        t:SetSize(170, 2)
        if side == "L" then t:SetPoint("RIGHT", overlay.title, "LEFT", -18, 0) else t:SetPoint("LEFT", overlay.title, "RIGHT", 18, 0) end
        t:SetColorTexture(1, 1, 1, 1)
        if V.Photo and V.Photo.Grad then
            if side == "L" then V.Photo.Grad(t, "HORIZONTAL", 0.9, 0.7, 0.3, 0, 0.9, 0.7, 0.3, 1)
            else V.Photo.Grad(t, "HORIZONTAL", 0.9, 0.7, 0.3, 1, 0.9, 0.7, 0.3, 0) end
        end
        return t
    end
    overlay.ruleL, overlay.ruleR = Rule("L"), Rule("R")
    local acc = 0
    overlay:SetScript("OnUpdate", function(_, elapsed)
        elapsed = elapsed or 0
        acc = acc + elapsed
        -- fade the whole screen in, and let the AFK title breathe
        if fade < 1 then
            fade = math.min(1, fade + elapsed / 1.2)
            View.GetFrame():SetAlpha(fade)
        end
        local pulse = 0.65 + 0.35 * math.sin(GetTime() * 1.6)
        overlay.title:SetAlpha(pulse)
        if acc < 0.25 then return end
        acc = 0
        A.Update()
    end)
end

function A.Update()
    if not active or not overlay then return end
    local now = GetTime()
    overlay.timer:SetText(Format(now - startedAt))
    overlay.clock:SetText(date(V.db.clock24 and "%H:%M" or "%I:%M %p"))
    overlay.date:SetText(date("%A, %B %d"))
    if now >= nextTip then
        local avg, low = V.Gear.Durability()
        local tips = {
            ("Item level %.1f"):format(V.Gear.AverageItemLevel()),
            avg and ("Durability %d%%"):format(math.floor(avg * 100 + 0.5)) or nil,
            (GetRealZoneText and GetRealZoneText() or "") ~= "" and GetRealZoneText() or nil,
            "Move or press a key to come back  -  Print Screen is safe",
        }
        local list = {}
        for i = 1, 4 do if tips[i] then list[#list + 1] = tips[i] end end
        tipIdx = tipIdx % #list + 1
        overlay.tip:SetText(list[tipIdx])
        nextTip = now + 6
    end
    if V.db.afkPoses and now >= nextPose then
        local model = View.GetModel()
        standing = not standing
        if standing then
            if model then pcall(model.SetAnimation, model, 0) end
            nextPose = now + 6
        else
            poseIdx = poseIdx % #POSES + 1
            if model then pcall(model.SetAnimation, model, POSES[poseIdx]) end
            nextPose = now + 10
        end
    end
end

function A.Enter()
    if active then return end
    View.Build()
    Build()
    local f = View.GetFrame()
    openedByUs = not f:IsShown()
    if V.Photo and V.Photo.IsActive() then V.Photo.Leave() end
    active = true
    startedAt = GetTime()
    fade, tipIdx, nextTip = 0, 0, 0
    f:SetAlpha(0)
    nextPose, poseIdx, standing = GetTime() + 4, 0, true
    if openedByUs then f:Show() end
    View.SetPanels(true)       -- gear, stats and item level stay up; only the buttons go
    View.AFKLayout(true)
    View.Refresh()
    View.forceSpin = true
    overlay:Show()
    View.UpdateUI()
    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then pcall(f.SetPropagateKeyboardInput, f, true) end
    f:SetScript("OnKeyDown", function(_, key) if key and IGNORED_KEYS[key] then return end A.Leave() end)
    A.Update()
end

function A.Leave()
    if not active then return end
    active = false
    View.forceSpin = false
    if overlay then overlay:Hide() end
    local f = View.GetFrame()
    fade = 1
    f:SetAlpha(1)
    f:EnableKeyboard(false)
    f:SetScript("OnKeyDown", nil)
    local model = View.GetModel()
    if model then pcall(model.SetAnimation, model, 0) end
    View.AFKLayout(false)
    View.SetPanels(true)
    View.Refresh()
    View.ApplyPrefs()
    View.UpdateUI()
    if openedByUs and f:IsShown() then f:Hide() end
    openedByUs = false
end

function A.IsActive() return active end
function A.Toggle() if active then A.Leave() else A.manual = true A.Enter() end end

V.On("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit ~= "player" or not V.db then return end
    local afk = UnitIsAFK and UnitIsAFK("player")
    if afk and V.db.afkScreen and not (InCombatLockdown and InCombatLockdown()) then
        if not active then A.manual = false end
        A.Enter()
    elseif not afk and active and not A.manual then
        A.Leave()
    end
end)

V.On("PLAYER_REGEN_DISABLED", function() if active then A.Leave() end end)
V.AddHook("viewHidden", function() fade = 1 if View.GetFrame() then View.GetFrame():SetAlpha(1) end if active then active = false View.forceSpin = false if overlay then overlay:Hide() end openedByUs = false end end)
