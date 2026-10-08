-- Gear: what you are wearing, item levels, missing enchants and gems, durability, stats.
local ADDON_NAME, V = ...
local G = {}
V.Gear = G

-- Paper-doll layout: left column, right column, bottom weapons.
G.LEFT   = { 1, 2, 3, 15, 5, 4, 19, 9 }
G.RIGHT  = { 10, 6, 7, 8, 11, 12, 13, 14 }
G.BOTTOM = { 16, 17, 18 }
G.NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrists", [10] = "Hands", [11] = "Ring", [12] = "Ring",
    [13] = "Trinket", [14] = "Trinket", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand",
    [18] = "Ranged", [19] = "Tabard",
}
-- Slots that count for item level (not shirt or tabard)
local COUNTED = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
-- Slots a player can normally enchant
G.ENCHANTABLE = { [5] = true, [7] = true, [8] = true, [9] = true, [10] = true, [15] = true, [16] = true }

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 },
}
function G.QualityColor(q)
    local c = QUALITY_COLORS[q or 1] or QUALITY_COLORS[1]
    return c[1], c[2], c[3]
end

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function ItemLevel(link)
    if not link or Secret(link) then return nil end
    local fn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if fn then
        local ok, lvl = pcall(fn, link)
        if ok and type(lvl) == "number" and lvl > 0 then return lvl end
    end
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if info then
        local ok, _, _, _, lvl = pcall(info, link)
        if ok and type(lvl) == "number" and lvl > 0 then return lvl end
    end
end

local function EnchantID(link)
    local id = link:match("item:%d+:(%d*)")
    return tonumber(id) or 0
end

local function EmptySockets(link)
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not fn then return 0 end
    local ok, stats = pcall(fn, link)
    if not ok or type(stats) ~= "table" then return 0 end
    local total = 0
    for k, v in pairs(stats) do
        if type(k) == "string" and k:find("EMPTY_SOCKET") then total = total + (tonumber(v) or 0) end
    end
    -- Gems already in the link (item:id:enchant:gem1:gem2:gem3:gem4) fill sockets
    local gems = 0
    local g1, g2, g3, g4 = link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*)")
    for _, g in ipairs({ g1 or "", g2 or "", g3 or "", g4 or "" }) do if g ~= "" and g ~= "0" then gems = gems + 1 end end
    return math.max(0, total - gems)
end

-- Everything the view needs to know about one slot.
function G.Info(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link or Secret(link) then return { slot = slot, empty = true } end
    local info = {
        slot = slot, link = link,
        texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot),
        quality = GetInventoryItemQuality and GetInventoryItemQuality("player", slot),
        ilvl = ItemLevel(link),
        problems = {},
    }
    if not info.quality then
        local gi = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if gi then local ok, _, _, q = pcall(gi, link) if ok then info.quality = q end end
    end
    if G.ENCHANTABLE[slot] and EnchantID(link) == 0 then
        -- Off hand: only weapons and shields can be enchanted; held items can't
        local ok = true
        if slot == 17 then
            local _, _, _, loc = (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(link)
            ok = (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD")
        end
        if ok then info.problems[#info.problems + 1] = "Not enchanted" end
    end
    local empty = EmptySockets(link)
    if empty > 0 then info.problems[#info.problems + 1] = (empty == 1) and "Empty gem socket" or (empty .. " empty gem sockets") end
    if GetInventoryItemDurability then
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            info.durability = cur / max
            if cur == 0 then info.problems[#info.problems + 1] = "Broken" end
        end
    end
    return info
end

-- Average item level (two-handers count twice, shirt and tabard don't count).
function G.AverageItemLevel()
    local sum, count = 0, 0
    local twoHand = false
    local mh = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if mh and not Secret(mh) then
        local gi = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local _, _, _, loc = gi(mh)
        twoHand = (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED")
    end
    for _, slot in ipairs(COUNTED) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if slot == 17 and twoHand and not link then
            local l = ItemLevel(mh)
            if l then sum = sum + l; count = count + 1 end
        elseif link and not Secret(link) then
            local l = ItemLevel(link)
            if l then sum = sum + l; count = count + 1 end
        elseif slot ~= 17 and slot ~= 18 then
            count = count + 1   -- an empty slot drags the average down
        end
    end
    if count == 0 then return 0 end
    return sum / count
end

-- Average and lowest durability across worn gear (0 to 1)
function G.Durability()
    local sum, n, low = 0, 0, 1
    for slot = 1, 18 do
        if slot ~= 4 and GetInventoryItemDurability then
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then
                local p = cur / max
                sum = sum + p; n = n + 1
                if p < low then low = p end
            end
        end
    end
    if n == 0 then return nil end
    return sum / n, low
end

-- Slots with something to fix, for the summary line
function G.Problems()
    local out = {}
    for _, slot in ipairs(COUNTED) do
        local info = G.Info(slot)
        if info.problems and #info.problems > 0 then out[#out + 1] = info end
    end
    return out
end

local function Safe(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

-- Label/value pairs for the stats panel
function G.Stats()
    local out = {}
    local function add(label, value, fmt)
        if value == nil or Secret(value) then return end
        out[#out + 1] = { label, fmt and string.format(fmt, value) or tostring(value) }
    end
    local names = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
    for i = 1, 5 do
        local _, eff = Safe(UnitStat, "player", i)
        add(names[i], eff and math.floor(eff))
    end
    local _, armor = Safe(UnitArmor, "player")
    add("Armor", armor and math.floor(armor))
    local ap = Safe(UnitAttackPower, "player")
    if ap then
        local base, pos, neg = UnitAttackPower("player")
        add("Attack power", base and math.floor(base + (pos or 0) + (neg or 0)))
    end
    add("Melee crit", Safe(GetCritChance), "%.2f%%")
    add("Spell crit", Safe(GetSpellCritChance, 2), "%.2f%%")
    add("Dodge", Safe(GetDodgeChance), "%.2f%%")
    add("Parry", Safe(GetParryChance), "%.2f%%")
    add("Block", Safe(GetBlockChance), "%.2f%%")
    add("Haste", Safe(GetHaste), "%.2f%%")
    add("Health", Safe(UnitHealthMax, "player"))
    local pt = Safe(UnitPowerType, "player")
    local powerName = ({ [0] = "Mana", [1] = "Rage", [3] = "Energy" })[pt or 0] or "Power"
    add(powerName, Safe(UnitPowerMax, "player"))
    return out
end
