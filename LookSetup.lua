local ADDON_NAME, V = ...
-- Window customization (see Look.lua). Opens with /vanitylook.
if not V.WinLook then return end
V.WinLook.Setup({
    title = "Vanity",
    slash = "vanitylook",
    media = "Interface\\AddOns\\Vanity\\Media\\",
    db = function() return VanityDB end,
    windows = {
        { id = "settings", name = "Settings panel", global = "VanitySettings", noScale = true },
    },
})
