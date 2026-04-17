-- Server-side chaos effect implementations

-- Helper: send a client-only effect with optional duration
local function SendClientEffect(ply, id, duration)
    net.Start("PM_ClientEffect")
    net.WriteUInt(id, 8)
    net.WriteFloat(duration or 0)
    net.Send(ply)
end

local function SendClientEffectEnd(ply, id)
    net.Start("PM_ClientEffectEnd")
    net.WriteUInt(id, 8)
    net.Send(ply)
end

-- ─── Dispatch table ──────────────────────────────────────────────────────────
PM_ChaosHandlers = {}

-- 1: Instant Death
PM_ChaosHandlers[1] = function(ply)
    ply:Kill()
end

-- 2: Kick (can rejoin)
PM_ChaosHandlers[2] = function(ply)
    timer.Simple(0.2, function()
        if IsValid(ply) then
            ply:Kick("The Kick Pill booted you. You may rejoin!")
        end
    end)
end

-- 3: Permadeath until 10 other deaths (only with 3+ players; fallback: instant kill)
PM_ChaosHandlers[3] = function(ply)
    if #player.GetAll() < 3 then
        -- Not enough players for permadeath to be meaningful
        ply:Kill()
        return
    end
    PM_PermaCounters[ply:SteamID()] = PERMA_DEATHS_NEEDED
    ply.PM_PermaDead = true
    net.Start("PM_PermaDeathCount")
    net.WriteUInt(PERMA_DEATHS_NEEDED, 8)
    net.Send(ply)
    ply:Kill()
end

-- 4: Big Head (30 s)
PM_ChaosHandlers[4] = function(ply)
    local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
    if not bone then return end
    ply:ManipulateBoneScale(bone, Vector(3, 3, 3))
    ply.PM_Effects.big_head = true
    timer.Simple(30, function()
        if IsValid(ply) then
            ply:ManipulateBoneScale(bone, Vector(1, 1, 1))
            ply.PM_Effects.big_head = nil
        end
    end)
end

-- 5: Loud ringing (GLOBAL, lasts until death / round end)
PM_ChaosHandlers[5] = function(ply)
    for _, p in player.Iterator() do
        SendClientEffect(p, CHAOS_RINGING, 999)
    end
end

-- 6: Random sensitivity (client-side)
PM_ChaosHandlers[6] = function(ply)
    SendClientEffect(ply, CHAOS_RANDOM_SENS, 30)
end

-- 7: Random movement (client-side)
PM_ChaosHandlers[7] = function(ply)
    SendClientEffect(ply, CHAOS_RANDOM_MOVEMENT, 20)
end

-- 8: Blindness (client-side)
PM_ChaosHandlers[8] = function(ply)
    SendClientEffect(ply, CHAOS_BLINDNESS, 20)
end

-- 9: Opens LinkedIn (client-side)
PM_ChaosHandlers[9] = function(ply)
    SendClientEffect(ply, CHAOS_LINKEDIN, 0)
end

-- 10: Petrification (frozen + invincible, 30 s)
PM_ChaosHandlers[10] = function(ply)
    ply:Freeze(true)
    ply.PM_Effects.petrified = true
    SendClientEffect(ply, CHAOS_PETRIFICATION, 30)
    timer.Simple(30, function()
        if IsValid(ply) then
            ply:Freeze(false)
            ply.PM_Effects.petrified = nil
            SendClientEffectEnd(ply, CHAOS_PETRIFICATION)
        end
    end)
end

-- 11: Hallucinations - fake player models (client-side)
PM_ChaosHandlers[11] = function(ply)
    local count = 5
    local positions = {}
    local center = ply:GetPos()
    for i = 1, count do
        local ang = math.random(360)
        local dist = math.random(150, 400)
        local pos = center + Vector(
            math.cos(math.rad(ang)) * dist,
            math.sin(math.rad(ang)) * dist,
            0
        )
        -- Trace down to find floor
        local tr = util.TraceLine({
            start  = pos + Vector(0,0,100),
            endpos = pos + Vector(0,0,-200),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        positions[i] = tr.Hit and tr.HitPos or pos
    end

    net.Start("PM_HallucPlayers")
    net.WriteUInt(count, 8)
    for _, p in ipairs(positions) do
        net.WriteVector(p)
    end
    net.Send(ply)
    SendClientEffect(ply, CHAOS_HALLUC_PLAYERS, 30)
end

-- 12: Fake Ping Spike
PM_ChaosHandlers[12] = function(ply)
    net.Start("PM_FakePing")
    net.WriteFloat(30)
    net.Send(ply)
end

-- 13: Fake FPS Drop (random 10–70 % intensity)
PM_ChaosHandlers[13] = function(ply)
    local intensity = math.random(10, 70)
    net.Start("PM_FakeFPS")
    net.WriteFloat(30)
    net.WriteUInt(intensity, 7)
    net.Send(ply)
end

-- 14: Decrease resolution (client-side)
PM_ChaosHandlers[14] = function(ply)
    SendClientEffect(ply, CHAOS_LOW_RES, 30)
end

-- 15: Flashbang (client-side)
PM_ChaosHandlers[15] = function(ply)
    SendClientEffect(ply, CHAOS_FLASHBANG, 3)
end

-- 16: Contagious Heart Attack
PM_ChaosHandlers[16] = function(ply)
    PM_ApplyHeartAttack(ply)
end

function PM_ApplyHeartAttack(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply.PM_Effects then return end             -- not yet initialised
    if ply.PM_Effects.heart_attack then return end    -- already infected

    ply.PM_Effects.heart_attack = { damage = 1.0 }
    local uid = ply:UserID()

    timer.Create("PM_cha_ha_" .. uid, 1, 0, function()
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("PM_cha_ha_" .. uid) return
        end
        local state = ply.PM_Effects.heart_attack
        if not state then timer.Remove("PM_cha_ha_" .. uid) return end

        local dmg = DamageInfo()
        dmg:SetDamage(state.damage)
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        ply:TakeDamageInfo(dmg)

        state.damage = state.damage * 2  -- exponential growth
    end)
end

-- 17: Nausea (client-side)
PM_ChaosHandlers[17] = function(ply)
    SendClientEffect(ply, CHAOS_NAUSEA, 20)
end

-- 18: Repeating jumpscares (client-side)
PM_ChaosHandlers[18] = function(ply)
    net.Start("PM_Jumpscare")
    net.WriteBool(true)   -- repeating
    net.WriteUInt(6, 4)   -- count
    net.WriteFloat(4)     -- interval
    net.Send(ply)
end

-- 19: Invert mouse/controls (client-side)
PM_ChaosHandlers[19] = function(ply)
    SendClientEffect(ply, CHAOS_INVERT_CONTROLS, 30)
end

-- 20: Grow x2
PM_ChaosHandlers[20] = function(ply)
    ply:SetModelScale(2, 0.2)
    ply.PM_Effects.grown = true
    timer.Simple(30, function()
        if IsValid(ply) then
            ply:SetModelScale(1, 0.2)
            ply.PM_Effects.grown = nil
        end
    end)
end

-- 21: Shaky Aim (client-side)
PM_ChaosHandlers[21] = function(ply)
    SendClientEffect(ply, CHAOS_SHAKY_AIM, 20)
end

-- 22: Hot Potato
PM_ChaosHandlers[22] = function(ply)
    if IsValid(ply.PM_Potato) then ply.PM_Potato:Remove() end
    local potato = ents.Create("pm_hot_potato")
    if not IsValid(potato) then return end
    potato.Holder = ply
    potato:SetPos(ply:GetPos() + Vector(0, 0, 85))
    potato:Spawn()
    ply.PM_Potato = potato
    PM_BroadcastChat(ply:Nick() .. " has the Hot Potato! 30 seconds...")
end

-- 23: No crosshair (client-side)
PM_ChaosHandlers[23] = function(ply)
    SendClientEffect(ply, CHAOS_NO_CROSSHAIR, 20)
end

-- 24: Lowest graphics (client-side)
PM_ChaosHandlers[24] = function(ply)
    SendClientEffect(ply, CHAOS_LOW_GRAPHICS, 30)
end

-- 25: No friction
PM_ChaosHandlers[25] = function(ply)
    ply:SetFriction(0)
    ply.PM_Effects.no_friction = true
    timer.Simple(15, function()
        if IsValid(ply) then
            ply:SetFriction(1)
            ply.PM_Effects.no_friction = nil
        end
    end)
end

-- 26: Weeping Angel (GMan)
PM_ChaosHandlers[26] = function(ply)
    if IsValid(ply.PM_Angel) then ply.PM_Angel:Remove() end
    local angel = ents.Create("pm_weeping_angel")
    if not IsValid(angel) then return end
    angel.Target = ply
    -- Spawn 500 units away in a random horizontal direction
    local spawnAng = math.random(360)
    local spawnOffset = Vector(
        math.cos(math.rad(spawnAng)) * 500,
        math.sin(math.rad(spawnAng)) * 500,
        0
    )
    angel:SetPos(ply:GetPos() + spawnOffset)
    angel:Spawn()
    ply.PM_Angel = angel
    PM_BroadcastChat("A Weeping Angel is hunting " .. ply:Nick() .. "!")
end

-- 27: Darkness (client-side)
PM_ChaosHandlers[27] = function(ply)
    SendClientEffect(ply, CHAOS_DARKNESS, 20)
end

-- 28: One jumpscare (client-side)
PM_ChaosHandlers[28] = function(ply)
    net.Start("PM_Jumpscare")
    net.WriteBool(false)  -- single
    net.WriteUInt(1, 4)
    net.WriteFloat(0)
    net.Send(ply)
end

-- 29: Spawn one zombie per player
PM_ChaosHandlers[29] = function(ply)
    local count = #player.GetAll()
    for i = 1, count do
        local npc = ents.Create("npc_zombie")
        if not IsValid(npc) then break end
        local ang = math.random(360)
        local offset = Vector(
            math.cos(math.rad(ang)) * math.random(100, 200),
            math.sin(math.rad(ang)) * math.random(100, 200),
            0
        )
        npc:SetPos(ply:GetPos() + offset)
        npc:Spawn()
        npc:SetTarget(ply)
    end
end

-- 30: Spawn props at feet for 10 s (large validated HL2 model pool)
PM_ChaosHandlers[30] = function(ply)
    local candidates = {
        "models/props_c17/oildrum001a.mdl",
        "models/props_c17/tv_monitor01.mdl",
        "models/props_c17/chair_office01a.mdl",
        "models/props_c17/trashbin01a.mdl",
        "models/props_c17/furniturechair001a.mdl",
        "models/props_c17/furniturecouch001a.mdl",
        "models/props_c17/lockers001a.mdl",
        "models/props_c17/bench001a.mdl",
        "models/props_c17/playgroundswing01.mdl",
        "models/props_borealis/bluebarrel001a.mdl",
        "models/props_junk/metal_paintcan001a.mdl",
        "models/props_junk/wood_crate001a.mdl",
        "models/props_junk/garbage_metalcan001a.mdl",
        "models/props_junk/garbage_glassbottle001a.mdl",
        "models/props_junk/garbage_bag001a.mdl",
        "models/props_junk/popcan01a.mdl",
        "models/props_junk/watermelon01.mdl",
        "models/props_junk/iBeam001a.mdl",
        "models/props_interiors/furniture_table001a.mdl",
        "models/props_interiors/furniture_fridge001a.mdl",
        "models/props_interiors/tv001.mdl",
        "models/props_c17/sheetrock001a.mdl",
        "models/props_c17/gate_door01.mdl",
        "models/props_c17/gravestone001a.mdl",
    }
    -- Filter to only models that exist in this install
    local models = {}
    for _, m in ipairs(candidates) do
        if util.IsValidModel(m) then
            table.insert(models, m)
        end
    end
    if #models == 0 then models = { "models/props_c17/oildrum001a.mdl" } end

    local uid = ply:UserID()
    timer.Create("PM_props_" .. uid, 0.5, 20, function()
        if not IsValid(ply) then return end
        local prop = ents.Create("prop_physics")
        if not IsValid(prop) then return end
        prop:SetModel(models[math.random(#models)])
        prop:SetPos(ply:GetPos() + Vector(math.Rand(-40,40), math.Rand(-40,40), 20))
        prop:Spawn()
        timer.Simple(20, function() if IsValid(prop) then prop:Remove() end end)
    end)
end

-- 31: Boogie Bomb (all nearby players spin in third-person for 5 s)
-- Net message is sent DIRECTLY to each victim so the client just sets the flag
-- with no entity-list parsing (which was the source of the previous bug).
PM_ChaosHandlers[31] = function(ply)
    local victims = {}
    for _, p in ipairs(ents.FindInSphere(ply:GetPos(), 400)) do
        if IsValid(p) and p:IsPlayer() and p:Alive() then
            table.insert(victims, p)
        end
    end
    if #victims == 0 then return end

    for _, v in ipairs(victims) do
        net.Start("PM_BoogieBomb")
        net.Send(v)           -- direct send; no payload needed
        v:Freeze(true)
        v.PM_Boogied = true
    end
    timer.Simple(5, function()
        for _, v in ipairs(victims) do
            if IsValid(v) then
                v:Freeze(false)
                v.PM_Boogied = nil
                -- Tell the client to end the boogie
                net.Start("PM_BoogieEnd")
                net.Send(v)
            end
        end
    end)
end

-- 32: Shrink x0.5
PM_ChaosHandlers[32] = function(ply)
    ply:SetModelScale(0.5, 0.2)
    ply.PM_Effects.shrunk = true
    timer.Simple(30, function()
        if IsValid(ply) then
            ply:SetModelScale(1, 0.2)
            ply.PM_Effects.shrunk = nil
        end
    end)
end

-- 33: Speed x2 (base 400/200 → 800/400)
PM_ChaosHandlers[33] = function(ply)
    ply:SetRunSpeed(800)
    ply:SetWalkSpeed(400)
    ply.PM_Effects.speed2x = true
    timer.Simple(20, function()
        if IsValid(ply) then
            ply:SetRunSpeed(400)
            ply:SetWalkSpeed(200)
            ply.PM_Effects.speed2x = nil
        end
    end)
end

-- 34: Spawn items at feet for 10 s
PM_ChaosHandlers[34] = function(ply)
    local items = { "item_healthkit", "item_battery", "item_ammo_ar2" }
    local uid = ply:UserID()
    timer.Create("PM_items_" .. uid, 0.8, 12, function()
        if not IsValid(ply) then return end
        local item = ents.Create(items[math.random(#items)])
        if not IsValid(item) then return end
        item:SetPos(ply:GetPos() + Vector(math.Rand(-50,50), math.Rand(-50,50), 10))
        item:Spawn()
        timer.Simple(15, function() if IsValid(item) then item:Remove() end end)
    end)
end

-- 35: Double fire rate (20 s)
PM_ChaosHandlers[35] = function(ply)
    ply.PM_Effects.double_fire = true
    timer.Simple(20, function()
        if IsValid(ply) then ply.PM_Effects.double_fire = nil end
    end)
end

-- 36: Infinite ammo (20 s)
PM_ChaosHandlers[36] = function(ply)
    ply.PM_Effects.infinite_ammo = true
    timer.Simple(20, function()
        if IsValid(ply) then ply.PM_Effects.infinite_ammo = nil end
    end)
end

-- 37: Double jump (20 s)
PM_ChaosHandlers[37] = function(ply)
    ply.PM_Effects.double_jump = true
    ply.PM_JumpCount = 0
    timer.Simple(20, function()
        if IsValid(ply) then ply.PM_Effects.double_jump = nil end
    end)
end

-- 38: Future Vision (pre-select next chaos effect via the same weighted roll)
PM_ChaosHandlers[38] = function(ply)
    local nextIdx = PM_RollChaosEffect()
    ply.PM_NextChaosEffect = nextIdx
    net.Start("PM_FutureVision")
    net.WriteUInt(nextIdx, 8)
    net.Send(ply)
end

-- 39: Metal Mario (20 s)
PM_ChaosHandlers[39] = function(ply)
    ply:SetRunSpeed(80)
    ply:SetWalkSpeed(60)
    ply.PM_Effects.metal_mario = true
    timer.Simple(20, function()
        if IsValid(ply) then
            ply:SetRunSpeed(400)
            ply:SetWalkSpeed(200)
            ply.PM_Effects.metal_mario = nil
        end
    end)
end

-- 40: Zero spread (20 s)
PM_ChaosHandlers[40] = function(ply)
    ply.PM_Effects.zero_spread = true
    timer.Simple(20, function()
        if IsValid(ply) then ply.PM_Effects.zero_spread = nil end
    end)
end

-- 41: Hallucinate items (client-side visuals + server gives real effect on touch)
PM_ChaosHandlers[41] = function(ply)
    local itemTypes = { 1, 2, 3 }  -- maps to PM_ApplyHallucItem types
    local count = 5

    net.Start("PM_HallucItems")
    net.WriteUInt(count, 8)
    for i = 1, count do
        local ang = math.random(360)
        local dist = math.random(80, 250)
        local pos = ply:GetPos() + Vector(
            math.cos(math.rad(ang)) * dist,
            math.sin(math.rad(ang)) * dist,
            10
        )
        local tr = util.TraceLine({
            start  = pos + Vector(0,0,100),
            endpos = pos - Vector(0,0,200),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        net.WriteVector(tr.Hit and (tr.HitPos + Vector(0,0,5)) or pos)
        net.WriteUInt(itemTypes[math.random(#itemTypes)], 4)
    end
    net.Send(ply)
end

-- 42: Mario Star (invincibility + damage on touch, 10 s)
-- Sound: Valve startup jingle played globally via EmitSound so it can be stopped.
-- If "sound/music/valve_stinger.mp3" doesn't exist in your install, replace the
-- path with the correct one (e.g. drop a custom file at sound/pm_valve.mp3).
local PM_STAR_MUSIC = "music/valve_stinger.mp3"

PM_ChaosHandlers[42] = function(ply)
    ply.PM_Effects.mario_star = true
    SendClientEffect(ply, CHAOS_MARIO_STAR, 10)
    -- Emit on every client's own entity so StopSound can cancel it
    BroadcastLua(string.format([[
        PM_MarioStarMusic = %q
        local p = LocalPlayer()
        if IsValid(p) then p:EmitSound(PM_MarioStarMusic, 75, 100, 1, CHAN_STATIC) end
    ]], PM_STAR_MUSIC))
    timer.Simple(10, function()
        if IsValid(ply) then
            ply.PM_Effects.mario_star = nil
            SendClientEffectEnd(ply, CHAOS_MARIO_STAR)
        end
        PM_StopMarioStarMusic()
    end)
end

-- Shared stop helper (called on timer expiry AND on the star-holder's death)
function PM_StopMarioStarMusic()
    BroadcastLua([[
        if PM_MarioStarMusic then
            local p = LocalPlayer()
            if IsValid(p) then p:StopSound(PM_MarioStarMusic) end
            PM_MarioStarMusic = nil
        end
    ]])
end

-- 43: Tactical Nuke - kills everyone with visual explosions
PM_ChaosHandlers[43] = function(ply)
    PM_BroadcastChat("☢ TACTICAL NUKE INCOMING ☢  (" .. ply:Nick() .. ")")
    timer.Simple(3, function()
        for _, p in player.Iterator() do
            if IsValid(p) then
                -- Spawn a visible explosion at each player before killing them
                local eff = EffectData()
                eff:SetOrigin(p:GetPos() + Vector(0, 0, 40))
                eff:SetScale(5)
                util.Effect("Explosion", eff)
                p:Kill()
            end
        end
    end)
end

-- ─── Weighted chaos roll ──────────────────────────────────────────────────────
-- Normal effects: 1–42 + 44–58 = 57 effects × weight 10 = 570 slots
-- Nuke (#43):     weight 1 → 1 slot      Total: 571
-- Slot map:  1–420  → effects 1–42   ceil(roll/10)
--           421–540 → effects 44–55   ceil((roll-420)/10) + 43
--           541–570 → effects 56–58   ceil((roll-540)/10) + 55
--               571 → nuke (#43)
function PM_RollChaosEffect()
    local roll = math.random(571)
    if roll == 571 then return CHAOS_NUKE end
    if roll <= 420  then return math.ceil(roll / 10) end
    if roll <= 540  then return math.ceil((roll - 420) / 10) + 43 end
    return math.ceil((roll - 540) / 10) + 55
end

-- ─── Helpers for new effects ──────────────────────────────────────────────────

-- Rage Virus: applied to target (also called from init.lua EntityTakeDamage spread)
function PM_ApplyRageVirus(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply.PM_Effects then return end          -- not yet initialised
    if ply.PM_Effects.rage_virus then return end   -- already infected

    ply.PM_Effects.rage_virus = true
    ply:SetRunSpeed(800)
    ply:SetWalkSpeed(400)
    ply:SetHealth(math.max(1, math.floor(ply:GetHealth() / 2)))
    PM_BroadcastChat(ply:Nick() .. " has the Rage Virus!")

    local uid = ply:UserID()
    timer.Create("PM_rage_" .. uid, 1, 0, function()
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("PM_rage_" .. uid) return
        end
        if not ply.PM_Effects or not ply.PM_Effects.rage_virus then
            timer.Remove("PM_rage_" .. uid) return
        end
        local dmg = DamageInfo()
        dmg:SetDamage(2)
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        ply:TakeDamageInfo(dmg)
    end)
end

-- Italian Dino / Uh Oh: turn a player into an exploding watermelon prop
function PM_TurnIntoWatermelon(victim, attacker)
    if not IsValid(victim) or not victim:Alive() then return end
    local pos = victim:GetPos() + Vector(0, 0, 20)
    victim:Kill()

    local melon = ents.Create("prop_physics")
    if not IsValid(melon) then return end
    melon:SetModel("models/props_junk/watermelon01.mdl")
    melon:SetPos(pos)
    melon:Spawn()

    timer.Simple(math.random(2, 5), function()
        if IsValid(melon) then
            local eff = EffectData()
            eff:SetOrigin(melon:GetPos())
            eff:SetScale(2)
            util.Effect("Explosion", eff)
            util.BlastDamage(
                melon,
                IsValid(attacker) and attacker or melon,
                melon:GetPos(), 150, 80
            )
            melon:Remove()
        end
    end)
end

-- ─── New effect handlers (44–55) ──────────────────────────────────────────────

-- 44: Blowback — launch all nearby players away from the pill-taker
PM_ChaosHandlers[44] = function(ply)
    for _, other in ipairs(ents.FindInSphere(ply:GetPos(), 600)) do
        if IsValid(other) and other:IsPlayer() and other ~= ply and other:Alive() then
            local dir = (other:GetPos() - ply:GetPos())
            dir:Normalize()
            dir.z = 0.6   -- add some upward arc
            other:SetVelocity(dir * 900)
        end
    end
end

-- 45: Invisible (20 s) — fully transparent to other players
PM_ChaosHandlers[45] = function(ply)
    ply:SetColor(Color(255, 255, 255, 0))
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    ply.PM_Effects.invisible = true
    timer.Simple(20, function()
        if IsValid(ply) then
            -- Restore the player's random tint colour, not plain white
            ply:SetColor(ply.PM_BaseColor or Color(255, 255, 255, 255))
            ply:SetRenderMode(RENDERMODE_TRANSALPHA)
            ply.PM_Effects.invisible = nil
        end
    end)
end

-- 46: Random Teleport — warp to a random spawn point
PM_ChaosHandlers[46] = function(ply)
    local spawnPoints = ents.FindByClass("info_player_start")
    if #spawnPoints == 0 then
        spawnPoints = ents.FindByClass("info_player_deathmatch")
    end
    if #spawnPoints == 0 then
        spawnPoints = ents.FindByClass("info_player_teamspawn")
    end
    if #spawnPoints > 0 then
        local sp = spawnPoints[math.random(#spawnPoints)]
        ply:SetPos(sp:GetPos() + Vector(0, 0, 10))
    else
        -- Last resort: random offset
        ply:SetPos(ply:GetPos() + Vector(math.Rand(-600, 600), math.Rand(-600, 600), 50))
    end
    PM_BroadcastChat(ply:Nick() .. " was randomly teleported!")
end

-- 47: Skeleton Army — four fast zombies (the most skeletal NPC in HL2) hunt the pill-taker.
-- npc_fastzombie are emaciated, bone-white, fast-moving, and pounce at targets.
PM_ChaosHandlers[47] = function(ply)
    for i = 1, 4 do
        local npc = ents.Create("npc_fastzombie")
        if not IsValid(npc) then break end
        local ang = (i - 1) * 90
        local offset = Vector(
            math.cos(math.rad(ang)) * 160,
            math.sin(math.rad(ang)) * 160,
            0
        )
        npc:SetPos(ply:GetPos() + offset)
        npc:Spawn()
        npc:SetEnemy(ply)
        npc:UpdateEnemyMemory(ply, ply:GetPos())
    end
    PM_BroadcastChat("A Skeleton Army is hunting " .. ply:Nick() .. "!")
end

-- 48: Rage Virus — doubled speed, halved health, -2 HP/s, melee-only; spreads on hit
PM_ChaosHandlers[48] = function(ply)
    PM_ApplyRageVirus(ply)
end

-- 49: Barrels o' Fun — random explosive barrel drop across the map.
-- We trace downward from an open-air start to avoid spawning inside brushes
-- (StartSolid == true was the "ERROR model" bug: entity can't initialise in solid).
PM_ChaosHandlers[49] = function(ply)
    local BARREL_MDL = "models/props_c17/oildrum001a.mdl"
    local count      = math.random(5, 15)
    local spawned    = 0

    for attempt = 1, count * 4 do   -- extra attempts in case spots are bad
        if spawned >= count then break end

        local ang  = math.random(360)
        local dist = math.random(200, 1000)
        local base = ply:GetPos() + Vector(
            math.cos(math.rad(ang)) * dist,
            math.sin(math.rad(ang)) * dist,
            0
        )

        -- Shoot upward to find the sky/ceiling, then downward to find the floor.
        -- Starting from 'base' + lots of height avoids beginning inside a brush.
        local trDown = util.TraceLine({
            start  = base + Vector(0, 0, 2048),
            endpos = base - Vector(0, 0, 256),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if not trDown.Hit or trDown.StartSolid then continue end

        local spawnPos = trDown.HitPos + Vector(0, 0, 40)

        -- Sanity-check: make sure our spawn point isn't inside a solid itself
        local sanity = util.TraceLine({
            start  = spawnPos,
            endpos = spawnPos + Vector(0, 0, 1),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if sanity.StartSolid then continue end

        local barrel = ents.Create("prop_physics")
        if not IsValid(barrel) then continue end
        barrel:SetModel(BARREL_MDL)
        barrel:SetPos(spawnPos)
        barrel:Spawn()
        spawned = spawned + 1

        timer.Simple(math.random(3, 15), function()
            if IsValid(barrel) then
                local eff = EffectData()
                eff:SetOrigin(barrel:GetPos())
                eff:SetScale(3)
                util.Effect("Explosion", eff)
                util.BlastDamage(barrel, ply, barrel:GetPos(), 220, 120)
                barrel:Remove()
            end
        end)
    end

    PM_BroadcastChat(ply:Nick() .. " scattered " .. spawned .. " explosive barrels!")
end

-- 50: Italian Dinosaur (30 s) — touching another player turns them into a watermelon
PM_ChaosHandlers[50] = function(ply)
    ply.PM_Effects.italian_dino = true
    timer.Simple(30, function()
        if IsValid(ply) then
            ply.PM_Effects.italian_dino = nil
        end
    end)
    PM_BroadcastChat(ply:Nick() .. " is the ITALIAN DINOSAUR! Don't let them touch you!")
end

-- 51: Uh Oh — the pill-taker themselves becomes an exploding watermelon
PM_ChaosHandlers[51] = function(ply)
    PM_TurnIntoWatermelon(ply, nil)
end

-- 52: Lonely (30 s) — every other player is invisible only to the afflicted (client-side)
PM_ChaosHandlers[52] = function(ply)
    SendClientEffect(ply, CHAOS_LONELY, 30)
end

-- 53: AND LIVE — a drivable jeep drops 500 units above the player.
-- If it crushes them, damage is capped so they survive at 5 HP.
-- The jeep stays for 60 s so players can drive it afterward.
PM_ChaosHandlers[53] = function(ply)
    local car = ents.Create("prop_vehicle_jeep")
    if not IsValid(car) then return end

    car:SetModel("models/buggy.mdl")
    car:SetKeyValue("vehiclescript", "scripts/vehicles/jeep_test.txt")
    car:SetPos(ply:GetPos() + Vector(0, 0, 500))
    car:Spawn()
    car:Activate()

    ply.PM_AndLiveCar = car

    -- Despawn after 60 s
    timer.Simple(60, function()
        if IsValid(car) then car:Remove() end
        if IsValid(ply) then ply.PM_AndLiveCar = nil end
    end)

    PM_BroadcastChat("A vehicle has been dropped on " .. ply:Nick() .. ". AND LIVE!")
end

-- 54: Triple Threat — roll and apply 3 different random effects simultaneously
PM_ChaosHandlers[54] = function(ply)
    local chosen    = {}
    local chosenSet = {}
    local attempts  = 0
    while #chosen < 3 and attempts < 30 do
        attempts = attempts + 1
        local idx = PM_RollChaosEffect()
        if idx ~= CHAOS_TRIPLE_THREAT and not chosenSet[idx] then
            chosenSet[idx] = true
            table.insert(chosen, idx)
        end
    end
    for _, idx in ipairs(chosen) do
        local h = PM_ChaosHandlers[idx]
        if h then h(ply) end
        PM_BroadcastChat("  └ Triple Threat sub-effect: " .. (CHAOS_NAMES[idx] or "???"))
    end
end

-- 55: Bounce YOU (20 s) — player cannot stop jumping; PostThink in init.lua does the impulse
PM_ChaosHandlers[55] = function(ply)
    ply.PM_Effects.bounce_you = true
    ply.PM_BounceTime = nil
    timer.Simple(20, function()
        if IsValid(ply) then
            ply.PM_Effects.bounce_you = nil
            ply.PM_BounceTime = nil
        end
    end)
end

-- ─── New effect handlers (56–58) ──────────────────────────────────────────────

-- 56: Pants on Fire — ignites the player and floods chat with fake pill reports
-- to confuse everyone about what's actually happening.
local PM_FAKE_PILL_NAMES = {
    "Tactical Nuke", "Permadeath (10 deaths)", "Instant Death",
    "Zombie Horde", "Barrels o' Fun", "Skeleton Army",
    "Rage Virus", "Italian Dinosaur (30s)", "AND LIVE",
    "Blowback", "Triple Threat", "Fentanyl",
}

PM_ChaosHandlers[56] = function(ply)
    ply:Ignite(20, 0)
    local allPlayers = player.GetAll()
    for _, p in ipairs(allPlayers) do
        local fake = PM_FAKE_PILL_NAMES[math.random(#PM_FAKE_PILL_NAMES)]
        PM_BroadcastChat(p:Nick() .. " took the Chaos Pill: " .. fake)
    end
end

-- 57: Fentanyl — speed doubles every second for 5 s, then instant death.
PM_ChaosHandlers[57] = function(ply)
    ply.PM_Effects.fentanyl    = true
    ply.PM_FentanylStart       = CurTime()
    local uid = ply:UserID()

    -- Speed update every 0.25 s (speed = 400 × 2^elapsed, capped at 8000)
    timer.Create("PM_fent_" .. uid, 0.25, 0, function()
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove("PM_fent_" .. uid) return
        end
        if not ply.PM_Effects or not ply.PM_Effects.fentanyl then
            timer.Remove("PM_fent_" .. uid) return
        end
        local elapsed = CurTime() - (ply.PM_FentanylStart or CurTime())
        local spd = math.min(400 * math.pow(2, elapsed), 8000)
        ply:SetRunSpeed(spd)
        ply:SetWalkSpeed(spd)
    end)

    -- Kill after 5 s
    timer.Simple(5, function()
        timer.Remove("PM_fent_" .. uid)
        if IsValid(ply) and ply.PM_Effects and ply.PM_Effects.fentanyl then
            ply.PM_Effects.fentanyl = nil
            ply:Kill()
        end
    end)
end

-- 58: Fafa — places a haunting image on the afflicted player's screen for 30 s (client-side).
-- Image file: gamemodes/drugmatch/content/materials/drugmatch/fafa.png
PM_ChaosHandlers[58] = function(ply)
    SendClientEffect(ply, CHAOS_FAFA, 30)
end

-- ─── Apply chaos (dispatcher) ─────────────────────────────────────────────────
function PM_ApplyChaos(ply, idx)
    local handler = PM_ChaosHandlers[idx]
    if handler then
        handler(ply)
        PM_BroadcastChat(ply:Nick() .. " took the Chaos Pill: " .. (CHAOS_NAMES[idx] or "???"))
    end
end
