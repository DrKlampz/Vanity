-- View: the full-screen showcase window.
local ADDON_NAME, V = ...
local View = {}
V.View = View
local G = V.Gear

local GOLD = { 0.85, 0.65, 0.25 }
local frame, model, bg, header, stats, hint
local slots = {}
local looking = "player"       -- "player" or "target"
local panelsOn = true          -- false in photo mode, so refreshes do not bring the slots back
local facing, zoom, panX, panY = 0, 1, 0, 0
local dragging

local function Font(parent, template, text, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
    if text then fs:SetText(text) end
    return fs
end

------------------------------------------------------------------------
-- Model camera
------------------------------------------------------------------------
local function ApplyCamera()
    if not model then return end
    pcall(model.SetFacing, model, facing)
    pcall(model.SetCamDistanceScale, model, zoom)
    pcall(model.SetPosition, model, 0, panX, panY)
end

function View.SetCamera(z, x, y)
    zoom, panX, panY = z, x or 0, y or 0
    ApplyCamera()
end

function View.ResetCamera()
    local id = V.db and V.db.camera or "full"
    facing = 0
    if V.Photo then V.Photo.SetCamera(id) else zoom, panX, panY = 1, 0, 0 ApplyCamera() end
end

function View.AddFacing(d) facing = facing + d; if model then pcall(model.SetFacing, model, facing) end end
function View.GetModel() return model end
function View.GetFrame() return frame end

local function SetModelUnit()
    if not model then return end
    if looking == "target" and UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
        pcall(model.SetUnit, model, "target")
    else
        looking = "player"
        pcall(model.SetUnit, model, "player")
    end
    ApplyCamera()
end

------------------------------------------------------------------------
-- Slot buttons
------------------------------------------------------------------------
-- The game's own tooltip lives under UIParent, which is hidden on the AFK screen, so
-- Vanity uses its own tooltip (a child of the Vanity window) whenever the interface is hidden.
local ownTip
function View.Tip()
    if not (View.UIHidden and View.UIHidden()) then return GameTooltip end
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "VanityTooltip", frame, "GameTooltipTemplate")
        ownTip:SetFrameStrata("TOOLTIP")
    end
    return ownTip
end
function View.HideTips() GameTooltip:Hide() if ownTip then ownTip:Hide() end end

local function SlotTooltip(self)
    local info = self.info
    local GameTooltip = View.Tip()
    GameTooltip:SetOwner(self, self.side == "right" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if info and info.link then
        local ok = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot)
        if not ok then GameTooltip:SetHyperlink(info.link) end
        for _, p in ipairs(info.problems or {}) do
            GameTooltip:AddLine("|cffff5555" .. p .. "|r")
        end
        GameTooltip:AddLine("|cff999999Shift-click: link in chat|r")
    else
        GameTooltip:AddLine(G.NAMES[self.slot] or "Slot", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Empty", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local SLOT_API = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot",
    [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
    [19] = "TabardSlot",
}
local function EmptyTexture(slot)
    if not GetInventorySlotInfo then return nil end
    local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_API[slot])
    if ok and type(tex) == "string" then return tex end
end

local function MakeSlot(slot, side)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(46, 46)
    b.slot, b.side = slot, side
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.03, 0.03, 0.05, 0.88)
    -- thin frame around the slot, tinted with the item's quality
    b.edge = {}
    for i = 1, 4 do b.edge[i] = b:CreateTexture(nil, "BORDER") end
    b.edge[1]:SetPoint("TOPLEFT") b.edge[1]:SetPoint("TOPRIGHT") b.edge[1]:SetHeight(1)
    b.edge[2]:SetPoint("BOTTOMLEFT") b.edge[2]:SetPoint("BOTTOMRIGHT") b.edge[2]:SetHeight(1)
    b.edge[3]:SetPoint("TOPLEFT") b.edge[3]:SetPoint("BOTTOMLEFT") b.edge[3]:SetWidth(1)
    b.edge[4]:SetPoint("TOPRIGHT") b.edge[4]:SetPoint("BOTTOMRIGHT") b.edge[4]:SetWidth(1)
    for i = 1, 4 do b.edge[i]:SetColorTexture(0.5, 0.42, 0.22, 0.9) end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3) b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local hl = b:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 1, 1, 0.18) end
    b.pill = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.pill:SetPoint("BOTTOMLEFT", 3, 3) b.pill:SetPoint("BOTTOMRIGHT", -3, 3) b.pill:SetHeight(13)
    b.pill:SetColorTexture(0, 0, 0, 0.65)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("CENTER")
    b.border:SetSize(46 * 1.9, 46 * 1.9)   -- this glow texture is meant to be about twice the button
    b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.border:SetBlendMode("ADD")
    b.ilvl = Font(b, "GameFontNormalSmall", "")
    b.ilvl:SetPoint("BOTTOM", 0, 2)
    b.warn = Font(b, "GameFontNormalLarge", "|cffff3333!|r")
    b.warn:SetPoint("TOPRIGHT", 5, 3)
    b.warn:Hide()
    b.label = Font(b, "GameFontDisableSmall", G.NAMES[slot] or "")
    if side == "right" then b.label:SetPoint("RIGHT", b, "LEFT", -6, 0) else b.label:SetPoint("LEFT", b, "RIGHT", 6, 0) end
    if side == "bottom" then b.label:ClearAllPoints() b.label:SetPoint("TOP", b, "BOTTOM", 0, -2) end
    -- always-visible item card (name, level, stats, enchant) beside the slot
    b.card = Font(b, "GameFontHighlightSmall", "")
    b.card:SetWidth(215)
    b.card:SetSpacing(2)
    b.card:SetWordWrap(false)
    if side == "right" or side == "bottom" then
        b.card:SetPoint("LEFT", b, "RIGHT", 10, 0) b.card:SetJustifyH("LEFT")
    else
        b.card:SetPoint("RIGHT", b, "LEFT", -10, 0) b.card:SetJustifyH("RIGHT")
    end
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", SlotTooltip)
    b:SetScript("OnLeave", function() View.HideTips() end)
    b:SetScript("OnClick", function(self)
        if IsShiftKeyDown and IsShiftKeyDown() and self.info and self.info.link then
            if ChatEdit_InsertLink then ChatEdit_InsertLink(self.info.link) end
        end
    end)
    slots[slot] = b
    return b
end

-- Read an item's tooltip lines through a hidden tooltip and boil them down to a short card.
local scan
local function CardLines(slot, info)
    local out = {}
    local qr, qg, qb = G.QualityColor(info.quality)
    if not scan then
        scan = CreateFrame("GameTooltip", "VanityScanTip", UIParent, "GameTooltipTemplate")
    end
    local armor, stats, mods = nil, {}, {}
    local rgb = ("|cff%02x%02x%02x"):format(math.floor(qr * 255), math.floor(qg * 255), math.floor(qb * 255))
    pcall(function()
        scan:SetOwner(UIParent, "ANCHOR_NONE")
        scan:ClearLines()
        scan:SetInventoryItem("player", slot)
        for i = 2, scan:NumLines() do
            local fs = _G["VanityScanTipTextLeft" .. i]
            local t = fs and fs:GetText()
            if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
                local e = t:match("^Enchanted: (.+)")
                if e then mods[#mods + 1] = "|cff55ff55" .. (#e > 36 and e:sub(1, 35) .. "..." or e) .. "|r"
                elseif t:match("^%d[%d,]* Armor$") or t:match("^%d[%d,]* Block$") then armor = t
                elseif t:match("^%+?%-?%d[%d,]* %a") and not t:match("Damage") then stats[#stats + 1] = t
                elseif t:match("^%d+ %- %d+ .*Damage") or t:match("^Speed ") then stats[#stats + 1] = t
                elseif t:match("^Equip: ") or t:match("^Use: ") or t:match("^Chance on hit") then
                    mods[#mods + 1] = "|cff55ff55" .. (#t > 38 and t:sub(1, 37) .. "..." or t) .. "|r"
                end
            end
        end
    end)
    out = {}
    -- armor and stat values take the item's rarity color
    if armor then out[#out + 1] = rgb .. armor .. "|r" end
    for _, t in ipairs(stats) do if #out < 4 then out[#out + 1] = rgb .. t .. "|r" end end
    for _, t in ipairs(mods) do if #out < 5 then out[#out + 1] = t end end
    for _, p in ipairs(info.problems or {}) do if #out < 5 then out[#out + 1] = "|cffff5555" .. p .. "|r" end end
    return table.concat(out, "\n")
end

local function Place(list, side, anchorX)
    for i, slot in ipairs(list) do
        local b = slots[slot] or MakeSlot(slot, side)
        b:ClearAllPoints()
        if side == "bottom" then
            b:SetPoint("BOTTOM", frame, "BOTTOM", (i - (#list + 1) / 2) * 250 - 100, 40)
        else
            b:SetPoint("TOP", frame, "TOP", anchorX, -140 - (i - 1) * 72)
        end
    end
end

local function RefreshSlots()
    for slot, b in pairs(slots) do
        local info = (looking == "player") and G.Info(slot) or { slot = slot, empty = true }
        b.info = info
        if info.link then
            b.icon:SetTexture(info.texture)
            b.icon:SetDesaturated(false)
            b.icon:SetAlpha(1)
            local r, g, bl = G.QualityColor(info.quality)
            b.border:SetVertexColor(r, g, bl)
            b.border:Show()
            for i = 1, 4 do b.edge[i]:SetColorTexture(r, g, bl, 1) end
            b.pill:Show()
            b.ilvl:SetText(info.ilvl and tostring(info.ilvl) or "")
            b.ilvl:SetTextColor(r, g, bl)
            if #info.problems > 0 then b.warn:Show() else b.warn:Hide() end
        else
            b.icon:SetTexture(EmptyTexture(b.slot))
            b.icon:SetDesaturated(true)
            b.icon:SetAlpha(0.35)
            for i = 1, 4 do b.edge[i]:SetColorTexture(0.35, 0.3, 0.18, 0.8) end
            b.pill:Hide()
            b.border:Hide()
            b.ilvl:SetText("")
            b.warn:Hide()
        end
        b.card:SetText(info.link and CardLines(slot, info) or "")
        b.card:SetShown(V.db.showCards ~= false)
        b.label:SetShown(V.db.showLabels and V.db.showCards == false)
        b:SetShown(panelsOn and looking == "player")
    end
    View.LayoutStats()
end

------------------------------------------------------------------------
-- Header and stats
------------------------------------------------------------------------
local function Money() return "" end

-- Full display name: the game's PvP name (carries any surname/title) when it has one
function View.DisplayName(unit)
    local plain = UnitName and UnitName(unit) or ""
    local full = UnitPVPName and UnitPVPName(unit)
    if type(full) == "string" and full ~= "" then return full end
    return plain
end

local function RefreshHeader()
    local name = View.DisplayName(looking == "target" and "target" or "player")
    header.name:SetText(name)
    local cls = select(2, UnitClass(looking == "target" and "target" or "player"))
    local r, g, b = 1, 1, 1
    local col = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if col then r, g, b = col.r, col.g, col.b end
    header.name:SetTextColor(r, g, b)
    if V.Photo and V.Photo.Grad and header.line then
        V.Photo.Grad(header.line, "HORIZONTAL", r, g, b, 1, r, g, b, 0)
    end
    local unit = looking == "target" and "target" or "player"
    local race = UnitRace and UnitRace(unit) or ""
    local class = UnitClass and UnitClass(unit) or ""
    local lvl = UnitLevel and UnitLevel(unit) or ""
    local guild = GetGuildInfo and GetGuildInfo(unit)
    header.sub:SetText(("Level %s %s %s%s"):format(tostring(lvl), tostring(race), tostring(class), guild and ("   <" .. guild .. ">") or ""))
    if looking == "player" then
        header.ilvl:SetText(("%.1f"):format(G.AverageItemLevel()))
        header.ilvlLabel:SetText("I T E M   L E V E L")
        local avg, low = G.Durability()
        header.dur:SetText(avg and ("Durability %d%% (lowest %d%%)"):format(math.floor(avg * 100 + 0.5), math.floor(low * 100 + 0.5)) or "")
        local probs = G.Problems()
        if #probs == 0 or V.db.showCards ~= false then
            header.problems:SetText("")
        else
            local parts = {}
            for _, p in ipairs(probs) do parts[#parts + 1] = (G.NAMES[p.slot] or "?") .. ": " .. table.concat(p.problems, ", ") end
            header.problems:SetText("|cffff7777" .. table.concat(parts, "\n") .. "|r")
        end
    else
        header.ilvl:SetText("") header.ilvlLabel:SetText("") header.dur:SetText("") header.problems:SetText("")
    end
end

-- With item cards on, the attributes move to the bottom left so the right-hand cards have room
function View.LayoutStats()
    if not stats then return end
    stats:ClearAllPoints()
    if V.db.showCards ~= false then
        stats:SetJustifyH("LEFT")
        stats:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 56, 70)
    else
        stats:SetJustifyH("RIGHT")
        stats:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -56, -176)
    end
end

function View.ShowStats(on)
    on = on and true or false
    if stats then stats:SetShown(on) end
    for _, t in ipairs({ View.statsCard, View.statsTop, View.statsTitle }) do if t then t:SetShown(on) end end
end

local function RefreshStats()
    if looking ~= "player" then stats:SetText("") return end
    local lines = {}
    for _, row in ipairs(G.Stats()) do lines[#lines + 1] = ("|cffbbbbbb%s|r   %s"):format(row[1], row[2]) end
    stats:SetText(table.concat(lines, "\n"))
end

function View.Refresh()
    if not frame or not frame:IsShown() then return end
    RefreshSlots() RefreshHeader() RefreshStats()
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function Button(parent, text, w, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, 24)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "VanityFrame", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetAllPoints(UIParent)
    frame:EnableMouse(true)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "VanityFrame") end

    bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.05, 1)
    View.bg = bg
    -- Stage lighting layered over the base color: dark ceiling, colored floor glow, dark edges
    local function Layer(sub)
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetColorTexture(1, 1, 1, 1)
        return t
    end
    View.top = Layer(1)
    View.top:SetPoint("TOPLEFT") View.top:SetPoint("TOPRIGHT")
    View.top:SetHeight((tonumber(UIParent:GetHeight()) or 900) * 0.45)
    View.floor = Layer(1)
    View.floor:SetPoint("BOTTOMLEFT") View.floor:SetPoint("BOTTOMRIGHT")
    View.floor:SetHeight((tonumber(UIParent:GetHeight()) or 900) * 0.55)
    View.edgeL = Layer(2)
    View.edgeL:SetPoint("TOPLEFT") View.edgeL:SetPoint("BOTTOMLEFT")
    View.edgeL:SetWidth((tonumber(UIParent:GetWidth()) or 1600) * 0.28)
    View.edgeR = Layer(2)
    View.edgeR:SetPoint("TOPRIGHT") View.edgeR:SetPoint("BOTTOMRIGHT")
    View.edgeR:SetWidth((tonumber(UIParent:GetWidth()) or 1600) * 0.28)
    -- spotlight beam behind the model
    View.beamL = Layer(3)
    View.beamL:SetPoint("TOP") View.beamL:SetPoint("BOTTOM") View.beamL:SetPoint("RIGHT", frame, "CENTER", 0, 0)
    View.beamL:SetWidth(300)
    View.beamR = Layer(3)
    View.beamR:SetPoint("TOP") View.beamR:SetPoint("BOTTOM") View.beamR:SetPoint("LEFT", frame, "CENTER", 0, 0)
    View.beamR:SetWidth(300)
    -- cinematic bars, only on the AFK screen
    View.letterTop = Layer(4)
    View.letterTop:SetPoint("TOPLEFT") View.letterTop:SetPoint("TOPRIGHT")
    View.letterTop:SetHeight((tonumber(UIParent:GetHeight()) or 900) * 0.055)
    View.letterTop:SetColorTexture(0, 0, 0, 1) View.letterTop:Hide()
    View.letterBottom = Layer(4)
    View.letterBottom:SetPoint("BOTTOMLEFT") View.letterBottom:SetPoint("BOTTOMRIGHT")
    View.letterBottom:SetHeight((tonumber(UIParent:GetHeight()) or 900) * 0.055)
    View.letterBottom:SetColorTexture(0, 0, 0, 1) View.letterBottom:Hide()
    if V.Photo then V.Photo.ApplyBackground() end

    model = CreateFrame("PlayerModel", "VanityModel", frame)
    model:SetPoint("TOP", frame, "TOP", 0, -90)
    model:SetPoint("BOTTOM", frame, "BOTTOM", 0, 110)
    model:SetWidth(560)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown", function(self, button)
        if V.AFK and V.AFK.IsActive() then V.AFK.Leave() return end
        dragging = { button = button, x = GetCursorPosition(), y = select(2, GetCursorPosition()), facing = facing, px = panX, py = panY }
    end)
    model:SetScript("OnMouseUp", function() dragging = nil end)
    model:SetScript("OnMouseWheel", function(_, delta)
        zoom = math.max(0.35, math.min(3, zoom - delta * 0.12))
        ApplyCamera()
    end)
    model:SetScript("OnUpdate", function(_, elapsed)
        if dragging then
            local x, y = GetCursorPosition()
            if dragging.button == "RightButton" then
                panX = dragging.px + (x - dragging.x) / 300
                panY = dragging.py + (y - dragging.y) / 300
            else
                facing = dragging.facing + (x - dragging.x) / 100
            end
            ApplyCamera()
        elseif V.db and (V.db.spin or View.forceSpin) and not View.photoLock then
            facing = facing + (View.forceSpin and 0.18 or (V.db.spinSpeed or 0.35)) * (elapsed or 0)
            pcall(model.SetFacing, model, facing)
        end
    end)

    -- Header (top left)
    header = {}
    header.name = Font(frame, "GameFontNormalHuge", "")
    header.name:SetPoint("TOPLEFT", 40, -30)
    pcall(header.name.SetFont, header.name, "Fonts\\MORPHEUS.TTF", 34, "OUTLINE")
    header.line = frame:CreateTexture(nil, "ARTWORK")
    header.line:SetPoint("TOPLEFT", header.name, "BOTTOMLEFT", 0, -34)
    header.line:SetSize(300, 2)
    header.line:SetColorTexture(1, 1, 1, 1)
    header.sub = Font(frame, "GameFontHighlight", "")
    header.sub:SetPoint("TOPLEFT", header.name, "BOTTOMLEFT", 0, -4)
    header.ilvl = Font(frame, "GameFontNormalHuge", "")
    header.ilvl:SetPoint("TOP", frame, "TOP", 0, -26)
    pcall(header.ilvl.SetFont, header.ilvl, "Fonts\\MORPHEUS.TTF", 34, "OUTLINE")
    header.ilvl:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    header.ilvlLabel = Font(frame, "GameFontDisableSmall", "")
    header.ilvlLabel:SetPoint("TOP", header.ilvl, "BOTTOM", 0, -2)
    header.dur = Font(frame, "GameFontDisableSmall", "")
    header.dur:SetPoint("TOP", header.ilvlLabel, "BOTTOM", 0, -2)
    header.problems = Font(frame, "GameFontNormalSmall", "")
    header.problems:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 40, 40)
    header.problems:SetJustifyH("LEFT")

    stats = Font(frame, "GameFontHighlight", "")
    stats:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -56, -176)
    stats:SetJustifyH("RIGHT")
    stats:SetSpacing(4)
    View.statsCard = frame:CreateTexture(nil, "BACKGROUND", nil, 5)
    View.statsCard:SetPoint("TOPLEFT", stats, "TOPLEFT", -18, 40)
    View.statsCard:SetPoint("BOTTOMRIGHT", stats, "BOTTOMRIGHT", 16, -14)
    View.statsCard:SetColorTexture(0, 0, 0, 0.42)
    View.statsTop = frame:CreateTexture(nil, "BORDER")
    View.statsTop:SetPoint("TOPLEFT", View.statsCard, "TOPLEFT") View.statsTop:SetPoint("TOPRIGHT", View.statsCard, "TOPRIGHT")
    View.statsTop:SetHeight(2)
    View.statsTop:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    View.statsTitle = Font(frame, "GameFontNormal", "A T T R I B U T E S")
    View.statsTitle:SetPoint("BOTTOM", stats, "TOP", -8, 14)
    View.statsTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    hint = Font(frame, "GameFontDisableSmall", "Drag to rotate - Right-drag to move - Wheel to zoom")
    hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)

    Place(G.LEFT, "left", -(560 / 2) - 90)
    Place(G.RIGHT, "right", (560 / 2) + 90)
    Place(G.BOTTOM, "bottom", 0)

    -- Buttons (top right)
    local close = Button(frame, "Close", 80, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -40, -28)
    local photo = Button(frame, "Photo mode", 100, function() if V.Photo then V.Photo.Toggle() end end)
    photo:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local who = Button(frame, "View target", 100, function(self)
        if looking == "player" then
            if UnitExists("target") and UnitIsPlayer("target") then
                looking = "target" self:SetText("View me")
            else
                V.Print("Target another player first.")
                return
            end
        else
            looking = "player" self:SetText("View target")
        end
        SetModelUnit() View.Refresh()
    end)
    who:SetPoint("RIGHT", photo, "LEFT", -6, 0)
    local reset = Button(frame, "Reset view", 90, View.ResetCamera)
    reset:SetPoint("RIGHT", who, "LEFT", -6, 0)
    local set = Button(frame, "Settings", 90, function() if V.Settings then V.Settings.Toggle() end end)
    set:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    View.buttons = { close = close, photo = photo, who = who, reset = reset, settings = set }

    frame:SetScript("OnShow", function() SetModelUnit() View.Refresh() View.ApplyPrefs() if V.Photo then V.Photo.SetCamera(V.db.camera or "full") end end)
    frame:SetScript("OnHide", function()
        dragging = nil
        if V.Photo then V.Photo.Leave() end
        View.SetUIHidden(false)
        V.Fire("viewHidden")
    end)
end
View.Build = Build

function View.Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Photo mode hides the panels and leaves only the model
function View.SetPanels(shown)
    panelsOn = shown and true or false
    if not frame then return end
    for _, b in pairs(slots) do b:SetShown(shown and looking == "player") end
    for _, k in ipairs({ "name", "sub", "ilvl", "ilvlLabel", "dur", "problems" }) do header[k]:SetShown(shown) end
    View.ShowStats(shown and V.db.showStats)
    for _, b in pairs(slots) do b.label:SetShown(shown and V.db.showLabels and V.db.showCards == false) end
    hint:SetShown(shown and V.db.showHint)
    for _, b in pairs(View.buttons or {}) do b:SetShown(shown) end
end

function View.IsShown() return frame and frame:IsShown() end

-- AFK screen: keep the showcase (gear, stats, item level) but drop the buttons and hint
function View.AFKLayout(on)
    if not frame then return end
    for _, b in pairs(View.buttons or {}) do b:SetShown(not on) end
    hint:SetShown(not on and V.db.showHint)
    if View.letterTop then View.letterTop:SetShown(on and true or false) View.letterBottom:SetShown(on and true or false) end
end

-- Hide the game's own interface (like Alt+Z) while keeping Vanity on screen. Vanity moves to
-- the world frame for the duration so hiding the normal interface doesn't hide it too.
local uiHidden = false
-- Names and nameplates float in the world rather than in the interface, so they are switched
-- off through the game's own settings while the interface is hidden, then put back.
local NAME_CVARS = {
    "nameplateShowFriends", "nameplateShowEnemies", "nameplateShowAll",
    "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameNPC", "UnitNameOwn",
    "UnitNameNonCombatCreatureName", "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName",
    "UnitNameFriendlyTotemName", "UnitNameEnemyGuardianName", "UnitNameEnemyPetName",
    "UnitNameEnemyTotemName", "UnitNameFriendlyMinionName", "UnitNameEnemyMinionName",
}
local savedNames
local function HideNames()
    if savedNames or not (GetCVar and SetCVar) then return end
    savedNames = {}
    for _, name in ipairs(NAME_CVARS) do
        local ok, cur = pcall(GetCVar, name)
        if ok and cur ~= nil then
            savedNames[name] = cur
            pcall(SetCVar, name, 0)
        end
    end
end
local function RestoreNames()
    if not savedNames then return end
    for name, val in pairs(savedNames) do pcall(SetCVar, name, val) end
    savedNames = nil
end
View.RestoreNames = RestoreNames

function View.UIHidden() return uiHidden end
function View.SetUIHidden(on)
    if not frame then return end
    if on and V.db.hideUI == "never" then on = false end
    if on == uiHidden then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if on then
        if WorldFrame then
            frame:SetParent(WorldFrame)
            local ws = tonumber(WorldFrame:GetEffectiveScale()) or 1
            local us = tonumber(UIParent:GetEffectiveScale()) or 1
            frame:SetScale(us / ws)
            frame:ClearAllPoints()
            frame:SetAllPoints(WorldFrame)
        end
        pcall(UIParent.Hide, UIParent)
        HideNames()
    else
        RestoreNames()
        pcall(UIParent.Show, UIParent)
        frame:SetParent(UIParent)
        frame:SetScale(1)
        frame:ClearAllPoints()
        frame:SetAllPoints(UIParent)
    end
    uiHidden = on
    if V.Photo then V.Photo.ApplyBackground() end
end

-- Show or hide the interface to suit what Vanity is doing right now
function View.UpdateUI()
    local want = frame and frame:IsShown() and ((V.AFK and V.AFK.IsActive()) or (V.Photo and V.Photo.IsActive()))
    View.SetUIHidden(want and true or false)
end
V.On("PLAYER_LOGOUT", function() RestoreNames() if uiHidden then pcall(UIParent.Show, UIParent) end end)
V.On("PLAYER_REGEN_DISABLED", function() if uiHidden then RestoreNames() pcall(UIParent.Show, UIParent) uiHidden = false if frame then frame:SetParent(UIParent) frame:SetScale(1) frame:SetAllPoints(UIParent) end end end)

-- Re-apply the display options (stats panel, slot names, hint)
function View.ApplyPrefs()
    if not frame then return end
    local panels = not (V.Photo and V.Photo.IsActive())
    local afk = V.AFK and V.AFK.IsActive()
    View.ShowStats(panels and V.db.showStats)
    hint:SetShown(panels and not afk and V.db.showHint)
    for _, b in pairs(slots) do b.label:SetShown(panels and V.db.showLabels and V.db.showCards == false) b.card:SetShown(panels and V.db.showCards ~= false) end View.LayoutStats()
end

-- Keep the numbers current while the window is open
for _, ev in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UPDATE_INVENTORY_DURABILITY",
                      "PLAYER_LEVEL_UP", "UNIT_STATS", "PLAYER_TARGET_CHANGED" }) do
    V.On(ev, function(event)
        if event == "PLAYER_TARGET_CHANGED" and looking == "target" then SetModelUnit() end
        View.Refresh()
    end)
end

------------------------------------------------------------------------
-- Entry points: character window button, minimap button
------------------------------------------------------------------------
local function CharButton()
    if not (V.db.charButton and CharacterFrame) or View.charBtn then return end
    local b = CreateFrame("Button", "VanityCharButton", CharacterFrame, "UIPanelButtonTemplate")
    b:SetSize(64, 20)
    b:SetText("Vanity")
    b:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -50, -30)
    b:SetScript("OnClick", function() View.Toggle() end)
    View.charBtn = b
end

local mm
local function Place_(angle)
    angle = math.rad(angle or V.db.minimap.angle or 200)
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function MakeMinimap()
    if mm or not Minimap or not V.db.minimap.show then return end
    mm = CreateFrame("Button", "VanityMinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("HIGH")
    mm:SetFrameLevel((tonumber(Minimap:GetFrameLevel()) or 1) + 8)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mm:RegisterForDrag("LeftButton")
    local bgt = mm:CreateTexture(nil, "BACKGROUND")
    bgt:SetSize(22, 22) bgt:SetPoint("CENTER")
    bgt:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = mm:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20) icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\Vanity\\Media\\Icon")
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52) border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    mm:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local s = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            local atan2 = math.atan2 or atan2
            V.db.minimap.angle = math.deg(atan2(cy / s - my, cx / s - mx)) % 360
            Place_(V.db.minimap.angle)
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnClick", function(_, b)
        GameTooltip:Hide()
        if b == "RightButton" then if V.Photo then View.Build() V.Photo.Enter() end else View.Toggle() end
    end)
    mm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffd9a441Vanity|r")
        GameTooltip:AddLine("Left-click: showcase", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right-click: photo mode", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place_()
end

function View.UpdateMinimap()
    if V.db.minimap.show then MakeMinimap() if mm then mm:Show() end elseif mm then mm:Hide() end
end

V.AddHook("loaded", function() CharButton() MakeMinimap() end)
