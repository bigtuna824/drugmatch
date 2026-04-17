-- Pill Deathmatch HUD
-- All default HUD panels are hidden except the weapon selector and crosshair.
-- No custom health / ammo / badge drawing.

surface.CreateFont("PM_Giant", { font = "Arial", size = 56, weight = 900 })

-- ─── Suppress default HUD elements ───────────────────────────────────────────
local PM_HIDE_HUD = {
    CHudHealth              = true,
    CHudBattery             = true,
    CHudAmmo                = true,
    CHudSecondaryAmmo       = true,
    CHudDamageIndicator     = true,
    CHudSuitPower           = true,
    CHudGeiger              = true,
    CHudFlashlight          = true,
    CHudPoisonDamageIndicator = true,
    CHudSquad               = true,
    CHudZoom                = true,
}

hook.Add("HUDShouldDraw", "PM_HideHUD", function(name)
    if PM_HIDE_HUD[name] then return false end

    -- Suppress crosshair only while the no-crosshair chaos effect is active
    if name == "CHudCrosshair" then
        local fx = PM_ClientEffects[CHAOS_NO_CROSSHAIR]
        if fx and CurTime() < fx.endTime then return false end
    end
    -- Everything else (CHudWeaponSelection, CHudCrosshair, etc.) draws normally
end)

-- ─── Jumpscare font (used by cl_effects.lua) ─────────────────────────────────
-- PM_Giant is declared here so it's available when cl_effects.lua draws it.

-- ─── Hint on first connect ────────────────────────────────────────────────────
hook.Add("InitPostEntity", "PM_SpawnHint", function()
    timer.Simple(3, function()
        chat.AddText(Color(100, 220, 255),
            "[Drugmatch] Press Q to take a Chaos Pill. First to " ..
            PM_KILL_LIMIT .. " kills wins!")
    end)
end)
