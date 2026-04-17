-- Client entry point
include("shared.lua")
include("cl_effects.lua")
include("cl_hud.lua")
include("cl_entities.lua")

-- ─── Q-key chaos pill ─────────────────────────────────────────────────────────
-- Edge detection: fires exactly once per Q press, no cooldown on the client.
-- The server enforces a 0.1 s anti-spam; the only real gameplay limit is the
-- per-life overdose count (PM_PillsLeft).
local PM_QWasDown = false

hook.Add("Think", "PM_QKeyPill", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsPlayer() then
        PM_QWasDown = false
        return
    end

    local isDown = input.IsKeyDown(KEY_Q)
    if isDown and not PM_QWasDown then
        if ply:Alive() then
            net.Start("PM_TakePill")
            net.SendToServer()
        end
    end
    PM_QWasDown = isDown
end)

-- ─── Net receivers ────────────────────────────────────────────────────────────
net.Receive("PM_ChatMsg", function()
    local msg = net.ReadString()
    chat.AddText(Color(220, 200, 50), "[Pills] ", color_white, msg)
end)

-- Pill announce: only used to clear the future-vision HUD display
net.Receive("PM_PillAnnounce", function()
    local ply    = net.ReadEntity()
    local pillID = net.ReadUInt(2)
    -- Clear future vision display when the local player uses a chaos pill
    if pillID == PILL_CHAOS and IsValid(LocalPlayer()) and ply == LocalPlayer() then
        PM_FutureVisionEffect = nil
    end
end)

-- Future Vision notification (index 0 = clear the display)
net.Receive("PM_FutureVision", function()
    local idx = net.ReadUInt(8)
    if idx == 0 then
        PM_FutureVisionEffect = nil
    else
        PM_FutureVisionEffect = CHAOS_NAMES[idx] or "Unknown"
        chat.AddText(Color(255, 255, 100), "[Future Vision] Next Chaos Pill: " .. PM_FutureVisionEffect)
    end
end)

-- Permadeath counter
net.Receive("PM_PermaDeathCount", function()
    PM_PermaDeathRemaining = net.ReadUInt(8)
    if PM_PermaDeathRemaining <= 0 then
        PM_PermaDeathRemaining = nil
    end
end)

-- Fake ping
net.Receive("PM_FakePing", function()
    local dur = net.ReadFloat()
    PM_FakePingActive = true
    timer.Simple(dur, function() PM_FakePingActive = false end)
end)

-- Fake FPS
net.Receive("PM_FakeFPS", function()
    local dur       = net.ReadFloat()
    local intensity = net.ReadUInt(7)   -- 10–70 %
    PM_FakeFPSActive    = true
    PM_FakeFPSIntensity = intensity
    timer.Simple(dur, function()
        PM_FakeFPSActive    = false
        PM_FakeFPSIntensity = nil
    end)
end)

-- Jumpscare
net.Receive("PM_Jumpscare", function()
    local _repeating = net.ReadBool()
    local count      = net.ReadUInt(4)
    local interval   = net.ReadFloat()
    PM_TriggerJumpscare(count, interval)
end)

-- Hallucination players
net.Receive("PM_HallucPlayers", function()
    PM_ClearHallucPlayers()
    local count = net.ReadUInt(8)
    for i = 1, count do
        PM_SpawnHallucPlayer(net.ReadVector())
    end
end)

-- Hallucination items
net.Receive("PM_HallucItems", function()
    PM_ClearHallucItems()
    local count = net.ReadUInt(8)
    for i = 1, count do
        local pos      = net.ReadVector()
        local itemType = net.ReadUInt(4)
        PM_SpawnHallucItem(pos, itemType)
    end
end)

-- Boogie bomb — server sends this DIRECTLY to affected players only, no payload.
-- Third-person is provided by CalcView in cl_effects.lua (no sv_cheats needed).
net.Receive("PM_BoogieBomb", function()
    PM_BoogieActive = true
end)

net.Receive("PM_BoogieEnd", function()
    PM_BoogieActive = false
end)
