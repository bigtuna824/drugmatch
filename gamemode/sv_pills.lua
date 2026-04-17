-- Server-side pill system (chaos-only, triggered by Q key)

PM_PermaCounters = PM_PermaCounters or {}

-- Shared pill application (used by both voluntary Q-press and auto-pill timer)
local function PM_DoTakePill(ply)
    -- Per-life pill budget: kill silently when exhausted
    ply.PM_PillsLeft = (ply.PM_PillsLeft or 1) - 1
    if ply.PM_PillsLeft <= 0 then
        ply:Kill()
        return
    end

    -- Announce to all players (clients use this to clear future-vision display)
    net.Start("PM_PillAnnounce")
    net.WriteEntity(ply)
    net.WriteUInt(PILL_CHAOS, 2)
    net.Broadcast()

    -- Roll and apply chaos effect
    local idx = ply.PM_NextChaosEffect or PM_RollChaosEffect()
    ply.PM_NextChaosEffect = nil
    PM_ApplyChaos(ply, idx)
end

-- Client sends this when Q is pressed
net.Receive("PM_TakePill", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- 0.1 s anti-spam only — no gameplay cooldown
    local now = CurTime()
    if now - (ply.PM_LastPill or 0) < 0.1 then return end
    ply.PM_LastPill = now

    PM_DoTakePill(ply)
end)

-- ─── Auto-pill: force-feed a pill after 20 s of inactivity ──────────────────
local PM_AUTO_PILL_DELAY = 20   -- seconds before a passive player is force-fed

timer.Create("PM_AutoPill", 1, 0, function()
    -- Suspend during the inter-round countdown so effects don't fire mid-reset
    if PM_RoundEnding then return end

    for _, ply in player.Iterator() do
        if not IsValid(ply) or not ply:Alive() then continue end
        if ply.PM_PermaDead then continue end
        if not ply.PM_Effects then continue end   -- not yet fully initialised

        local lastPill = ply.PM_LastPill or CurTime()
        if CurTime() - lastPill >= PM_AUTO_PILL_DELAY then
            ply.PM_LastPill = CurTime()   -- reset before applying (prevents double-fire)

            net.Start("PM_ChatMsg")
            net.WriteString("You were too passive! A Chaos Pill was forced on you.")
            net.Send(ply)

            PM_BroadcastChat(ply:Nick() .. " was force-fed a Chaos Pill for being too passive!")

            -- pcall so a broken effect handler can't permanently kill the timer
            local ok, err = pcall(PM_DoTakePill, ply)
            if not ok then
                print("[Drugmatch] Auto-pill error for " .. ply:Nick() .. ": " .. tostring(err))
            end
        end
    end
end)

-- Hallucination item touched on client → server gives real reward
net.Receive("PM_HallucItemTouch", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local itemType = net.ReadUInt(4)
    PM_ApplyHallucItem(ply, itemType)
end)

-- ─── Halluc item reward ───────────────────────────────────────────────────────
function PM_ApplyHallucItem(ply, itemType)
    if itemType == 1 then
        ply:SetHealth(math.min(ply:GetHealth() + 25, 100))
    elseif itemType == 2 then
        ply:GiveAmmo(30, "ar2", true)
    elseif itemType == 3 then
        ply:Give("weapon_rpg")
    end
end

-- ─── Permadeath helpers ───────────────────────────────────────────────────────
function PM_OnAnyPlayerDied(dyingPly)
    local dyingSID = dyingPly:SteamID()
    for sid, remaining in pairs(PM_PermaCounters) do
        if sid ~= dyingSID then
            local newRemaining = remaining - 1
            PM_PermaCounters[sid] = newRemaining
            local owner = PM_FindBySteamID(sid)
            if IsValid(owner) then
                net.Start("PM_PermaDeathCount")
                net.WriteUInt(math.max(newRemaining, 0), 8)
                net.Send(owner)
                if newRemaining <= 0 then
                    PM_PermaCounters[sid] = nil
                    owner.PM_PermaDead = false
                    owner:Spawn()
                end
            end
        end
    end
end

function PM_FindBySteamID(sid)
    for _, p in player.Iterator() do
        if p:SteamID() == sid then return p end
    end
    return NULL
end

-- ─── Global cleanup on death / round end ─────────────────────────────────────
function PM_CleanupPlayerEffects(ply)
    if not IsValid(ply) then return end
    local uid = ply:UserID()

    -- Remove all effect timers (brute-force for numbered stim/dep timers)
    for n = 1, 100 do
        timer.Remove("PM_stim_end_" .. uid .. "_" .. n)
        timer.Remove("PM_dep_end_"  .. uid .. "_" .. n)
    end
    timer.Remove("PM_cha_ha_" .. uid)
    timer.Remove("PM_props_"  .. uid)
    timer.Remove("PM_items_"  .. uid)
    timer.Remove("PM_rage_"   .. uid)
    timer.Remove("PM_fent_"   .. uid)

    -- Restore base movement speeds
    ply:SetRunSpeed(400)
    ply:SetWalkSpeed(200)
    ply:SetFriction(1)
    ply:SetModelScale(1, 0.1)
    ply:Freeze(false)

    -- Restore head bone scale
    local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
    if bone then ply:ManipulateBoneScale(bone, Vector(1, 1, 1)) end

    -- Remove any owned entities
    if IsValid(ply.PM_Potato) then ply.PM_Potato:Remove() end
    ply.PM_Potato = nil
    if IsValid(ply.PM_Angel) then ply.PM_Angel:Remove() end
    ply.PM_Angel = nil
    if IsValid(ply.PM_AndLiveCar) then ply.PM_AndLiveCar:Remove() end
    ply.PM_AndLiveCar = nil

    -- Restore invisible state (use the player's tint colour, not plain white)
    if ply.PM_Effects and ply.PM_Effects.invisible then
        ply:SetColor(ply.PM_BaseColor or Color(255, 255, 255, 255))
        ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    end

    -- If this player had the Mario Star, stop the global music for everyone
    if ply.PM_Effects and ply.PM_Effects.mario_star then
        PM_StopMarioStarMusic()
    end

    -- Rage virus / Fentanyl: restore movement speeds
    if ply.PM_Effects and (ply.PM_Effects.rage_virus or ply.PM_Effects.fentanyl) then
        ply:SetRunSpeed(400)
        ply:SetWalkSpeed(200)
    end
    ply.PM_FentanylStart = nil

    ply.PM_BounceTime = nil
    ply.PM_Effects    = {}
    -- NOTE: PM_PermaDead is NOT cleared here; only cleared when counter reaches 0.
    ply.PM_JumpCount = 0

    -- Tell client to cancel all its visual effects
    net.Start("PM_ClientEffectEnd")
    net.WriteUInt(0, 8)   -- 0 = cancel all
    net.Send(ply)
end

-- ─── Broadcast chat helper ────────────────────────────────────────────────────
function PM_BroadcastChat(msg)
    net.Start("PM_ChatMsg")
    net.WriteString(msg)
    net.Broadcast()
end
