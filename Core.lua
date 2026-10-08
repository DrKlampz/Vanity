-- Vanity: a character showcase for WoW: Forever.
-- Core.lua holds settings, events and the slash command.
local ADDON_NAME, V = ...
V.name = ADDON_NAME

V.DEFAULTS = {
    background = "dark",     -- dark | class | light | green | world
    spin = true,             -- slow turntable while you are not dragging the model
    spinSpeed = 0.35,        -- radians per second
    showHint = true,
    showStats = true,        -- the stats panel on the right
    showLabels = true,       -- slot names next to the gear
    brightness = 1,          -- 0.7 / 1 / 1.4 stage brightness
    stageLight = true,       -- colored glow on the floor
    vignette = true,         -- darkened edges
    camera = "full",         -- full | waist | bust | face
    afkScreen = true,        -- show the showcase while you are AFK
    afkPoses = true,         -- cycle poses (sit, wave, laugh ...) on the AFK screen
    clock24 = false,         -- 24-hour clock on the AFK screen
    charButton = true,       -- a Vanity button on the character window
    minimap = { show = true, angle = 200 },
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function V.Print(msg) print("|cffd9a441Vanity:|r " .. tostring(msg)) end

local reported = {}
function V.ReportError(what, err)
    if reported[what] then return end
    reported[what] = true
    V.Print(("|cffff5555Something went wrong in %s:|r %s"):format(what, tostring(err)))
end

local hooks, handlers = {}, {}
function V.AddHook(name, fn) hooks[name] = hooks[name] or {}; table.insert(hooks[name], fn) end
function V.Fire(name, ...)
    for _, fn in ipairs(hooks[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then V.ReportError("Vanity (" .. name .. ")", err) end
    end
end
local frame = CreateFrame("Frame")
function V.On(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= ADDON_NAME then return end
        VanityDB = VanityDB or {}
        V.db = Merge(VanityDB, V.DEFAULTS)
        V.Fire("loaded")
        return
    end
    for _, fn in ipairs(handlers[event] or {}) do
        local ok, err = pcall(fn, event, ...)
        if not ok then V.ReportError("Vanity (" .. event .. ")", err) end
    end
end)
frame:RegisterEvent("ADDON_LOADED")

function Vanity_Toggle() if V.View then V.View.Toggle() end end
function Vanity_TogglePhoto() if V.Photo then V.Photo.Toggle() end end
function Vanity_OnAddonCompartmentClick() Vanity_Toggle() end

SLASH_VANITY1 = "/vanity"
SLASH_VANITY2 = "/vain"
SlashCmdList.VANITY = function(input)
    local cmd = tostring(input or ""):match("^%s*(%S*)"):lower()
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        Vanity_Toggle()
    elseif cmd == "photo" then
        Vanity_TogglePhoto()
    elseif cmd == "spin" then
        V.db.spin = not V.db.spin
        V.Print("Turntable " .. (V.db.spin and "on" or "off"))
    elseif cmd == "bg" or cmd == "background" then
        if V.Photo then V.Photo.CycleBackground() end
    elseif cmd == "minimap" then
        V.db.minimap.show = not V.db.minimap.show
        V.Print("Minimap button " .. (V.db.minimap.show and "shown." or "hidden."))
        if V.View and V.View.UpdateMinimap then V.View.UpdateMinimap() end
    elseif cmd == "afk" then
        if V.AFK then V.AFK.Toggle() end
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if V.View then V.View.Build() V.View.GetFrame():Show() end
        if V.Settings then V.Settings.Toggle() end
    elseif cmd == "reset" then
        if V.View then V.View.ResetCamera() end
    else
        V.Print("/vanity - open the showcase")
        V.Print("/vanity photo - photo mode (hides the panels, shows the studio bar)")
        V.Print("/vanity bg - cycle the background")
        V.Print("/vanity afk - preview the AFK screen")
        V.Print("/vanity settings - backgrounds, camera and AFK options")
        V.Print("/vanity spin - turntable on/off")
        V.Print("/vanity reset - reset the camera")
        V.Print("/vanity minimap - show or hide the minimap button")
    end
end
