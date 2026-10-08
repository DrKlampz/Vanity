-- AFK: when you go AFK, Vanity takes over the screen with your character, a timer and a clock.
local ADDON_NAME, V = ...
local A = {}
V.AFK = A
local View = V.View

local POSES = { 72, 67, 70, 69, 68, 66, 75, 80 }   -- sit, wave, laugh, dance, cheer, bow, kneel, applaud
local active, startedAt = false, 0
local overlay, nextPose, poseIdx, standing = nil, 0, 0, true
local openedByUs = false

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
    local function Text(template, point, x, y)
        local fs = overlay:CreateFontString(nil, "OVERLAY", template)
        fs:SetPoint(point, f, point, x, y)
        return fs
    end
    overlay.title = Text("GameFontNormalHuge", "BOTTOM", 0, 190)
    overlay.title:SetText("|cffff5555AFK|r")
    overlay.timer = Text("GameFontNormalHuge", "BOTTOM", 0, 150)
    overlay.clock = Text("GameFontHighlightLarge", "TOPRIGHT", -50, -40)
    overlay.name = Text("GameFontNormalHuge", "BOTTOMLEFT", 50, 80)
    overlay.sub = Text("GameFontHighlight", "BOTTOMLEFT", 50, 56)
    overlay.stat = Text("GameFontHighlight", "BOTTOMRIGHT", -50, 56)
    overlay.stat:SetJustifyH("RIGHT")
    overlay.tip = Text("GameFontDisableSmall", "BOTTOM", 0, 40)
    overlay.tip:SetText("Move or press a key to come back")
    overlay.name:SetJustifyH("LEFT") overlay.sub:SetJustifyH("LEFT")
    local acc = 0
    overlay:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
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
    nextPose, poseIdx, standing = GetTime() + 4, 0, true
    if openedByUs then f:Show() end
    View.SetPanels(false)
    View.forceSpin = true
    local ilvl = V.Gear.AverageItemLevel()
    overlay.name:SetText(UnitName("player") or "")
    local cls = UnitClass and UnitClass("player") or ""
    overlay.sub:SetText(("Level %s %s %s"):format(tostring(UnitLevel("player")), tostring(UnitRace("player")), tostring(cls)))
    overlay.stat:SetText(("Item level %.1f"):format(ilvl))
    overlay:Show()
    View.UpdateUI()
    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then pcall(f.SetPropagateKeyboardInput, f, true) end
    f:SetScript("OnKeyDown", function() A.Leave() end)
    A.Update()
end

function A.Leave()
    if not active then return end
    active = false
    View.forceSpin = false
    if overlay then overlay:Hide() end
    local f = View.GetFrame()
    f:EnableKeyboard(false)
    f:SetScript("OnKeyDown", nil)
    local model = View.GetModel()
    if model then pcall(model.SetAnimation, model, 0) end
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
V.AddHook("viewHidden", function() if active then active = false View.forceSpin = false if overlay then overlay:Hide() end openedByUs = false end end)
