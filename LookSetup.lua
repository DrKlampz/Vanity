local ADDON_NAME, V = ...
-- Window customization (see Look.lua). Opens from the minimap button (Alt-click).
if not V.WinLook then return end
local function Options()
    local L = V.WinLook
    local db = function() return V.db end
    local function ph(fn) return function() local P = V.Photo if P and P[fn] then P[fn]() end end end
    local function vw(fn) return function() local W = V.View if W and W[fn] then W[fn]() end end end
    local function prefs() local W = V.View if W then if W.ApplyPrefs then W.ApplyPrefs() end end end
    return { sections = {
        { id = "bg", title = "Background", open = true, rows = {
            L.Choice("Brightness", db, "brightness", { { 0.7, "Dim" }, { 1, "Normal" }, { 1.4, "Bright" } }, ph("ApplyBackground")),
            L.Koff("Floor glow", db, "stageLight", ph("ApplyBackground")),
            L.Koff("Darkened edges", db, "vignette", ph("ApplyBackground")),
        } },
        { id = "cam", title = "Camera", rows = {
            L.Choice("Turntable", db, "spin", { { true, "On" }, { false, "Off" } }),
            L.Choice("Turntable speed", db, "spinSpeed", { { 0.2, "Slow" }, { 0.35, "Normal" }, { 0.7, "Fast" } }),
            L.Note("Camera framing and background colors are chosen live in the showcase's settings panel."),
        } },
        { id = "show", title = "Showcase", open = true, rows = {
            L.Koff("Stats panel", db, "showStats", prefs),
            L.Koff("Item cards (always show each item's details)", db, "showCards", function() prefs() local W = V.View if W and W.Refresh then W.Refresh() end end),
            L.Koff("Slot names (when cards are off)", db, "showLabels", prefs),
            L.Koff("Controls hint", db, "showHint", prefs),
            L.Koff("Button on the character window", db, "charButton", function(v)
                local W = V.View
                if not W then return end
                if v and W.MakeCharButton then W.MakeCharButton() elseif W.charBtn then W.charBtn:Hide() end
            end),
        } },
        { id = "afk", title = "AFK screen", rows = {
            L.Koff("Show Vanity when I go AFK", db, "afkScreen"),
            L.Choice("Game interface", db, "hideUI", { { "auto", "Hide in AFK and photo mode" }, { "never", "Leave it on" } }, vw("UpdateUI")),
            L.Koff("Cycle poses while AFK", db, "afkPoses"),
            L.Koff("24-hour clock", db, "clock24"),
            L.Button("Preview the AFK screen", function() if V.AFK then V.AFK.manual = true V.AFK.Enter() end end),
        } },
    } }
end

V.WinLook.Setup({
    options = Options,
    title = "Vanity",
    media = "Interface\\AddOns\\Vanity\\Media\\",
    db = function() return VanityDB end,
    windows = {
        { id = "settings", name = "Settings panel", global = "VanitySettings", noScale = true },
    },
})
