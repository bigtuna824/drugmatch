-- Server entry point
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_effects.lua")
AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_entities.lua")

include("shared.lua")
include("sv_pills.lua")
include("sv_effects.lua")
include("sv_entities.lua")

-- ─── Kill-count persistence across kicks / disconnects ───────────────────────
-- Keyed by SteamID; cleared on round reset so normal round boundaries still work.
PM_KillCache = {}

-- ─── Weapon pools (HL2 loadout — random primary + sidearm + melee each spawn) ──
-- Excluded by design: weapon_rpg (one-shot, unbalanced), weapon_smg1 (grenade launcher).
-- Rage Virus melee enforcement relies on Slot 0 (crowbar / stunstick).
local PM_PRIMARIES = {
    "weapon_ar2",
    "weapon_shotgun",
    "weapon_crossbow",
}

local PM_SECONDARIES = {
    "weapon_pistol",
    "weapon_357",
}

local PM_MELEE = {
    "weapon_crowbar",
    "weapon_stunstick",
}

-- ─── Random player model pool ────────────────────────────────────────────────
-- Built once when the map initialises by recursively scanning models/player/.
-- Models that lack the standard HL2 biped (ValveBiped.Bip01_Spine) show a
-- reference/T-pose at runtime. We validate lazily: when a model is first chosen
-- we create a temp ragdoll to check for that bone; result is cached so each
-- model is only ever checked once per server session.
local PM_ModelPool  = nil
local PM_BadModels  = {}   -- [path] = true → known bad, skip

local function PM_ScanModels(dir, out)
    local files, subdirs = file.Find(dir .. "*.mdl", "GAME")
    for _, f in ipairs(files or {}) do
        local path = dir .. f
        if util.IsValidModel(path) then
            out[#out + 1] = path
        end
    end
    for _, d in ipairs(subdirs or {}) do
        PM_ScanModels(dir .. d .. "/", out)
    end
end

local function PM_BuildModelPool()
    local pool = {}
    PM_ScanModels("models/player/", pool)
    if #pool == 0 then pool = { "models/player/kleiner.mdl" } end
    PM_ModelPool = pool
    print("[Drugmatch] Player model pool built: " .. #pool .. " models")
end

-- Returns true if the model has a standard HL2 player biped.
-- Uses a temporary prop_ragdoll; result is cached after the first check.
local function PM_IsValidPlayerModel(path)
    if PM_BadModels[path] ~= nil then return not PM_BadModels[path] end
    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return true end   -- can't check; assume OK
    ent:SetModel(path)
    ent:Spawn()
    local valid = ent:LookupBone("ValveBiped.Bip01_Spine") ~= nil
    ent:Remove()
    PM_BadModels[path] = not valid
    return valid
end

hook.Add("InitPostEntity", "PM_BuildPools", function()
    PM_BuildModelPool()
end)

-- Disable cheats and noclip
RunConsoleCommand("sv_cheats", "0")
timer.Create("PM_EnforceCheats", 10, 0, function()
    if GetConVar("sv_cheats"):GetInt() ~= 0 then
        RunConsoleCommand("sv_cheats", "0")
    end
end)

-- ─── Player class setup ───────────────────────────────────────────────────────
-- Must be called in PlayerInitialSpawn so player_manager knows the class before
-- the first PlayerSpawn fires (fixes T-pose / missing animations / wrong model).
function GM:PlayerInitialSpawn(ply)
    self.BaseClass.PlayerInitialSpawn(self, ply)
    player_manager.SetPlayerClass(ply, "player_default")
end

-- PlayerSetModel: the base class calls this during spawn.  We let it run but
-- immediately override the result in PlayerSpawn with a random pool model, so
-- the player's Q-menu choice is irrelevant to gameplay.
function GM:PlayerSetModel(ply)
    -- Apply a temporary valid model so the base class doesn't complain.
    -- The real random model is set moments later in PlayerSpawn.
    local mdl = player_manager.TranslatePlayerModel(ply:GetInfo("cl_playermodel"))
    if not mdl or mdl == "" or not util.IsValidModel(mdl) then
        mdl = "models/player/kleiner.mdl"
    end
    ply:SetModel(mdl)
    ply:SetupHands()
end

-- ─── Noclip blocked ───────────────────────────────────────────────────────────
function GM:PlayerNoClip(ply, desiredState)
    return false
end

-- ─── Spawn ────────────────────────────────────────────────────────────────────
function GM:PlayerSpawn(ply, transiton)
    -- Forward transiton so the base class skips the default loadout on map-change transitions
    self.BaseClass.PlayerSpawn(self, ply, transiton)

    ply:SetHealth(100)
    ply:SetArmor(0)
    ply:Freeze(false)   -- clear any leftover freeze from petrify / boogie bomb

    -- Base movement speeds (reset explicitly so effects like Metal Mario don't persist)
    ply:SetRunSpeed(400)
    ply:SetWalkSpeed(200)

    -- ── Random player model ──────────────────────────────────────────────────
    -- Pool is built at map load; fall back to Kleiner if somehow empty.
    -- Lazy bone-check prevents T-pose from models without HL2 biped animations.
    if not PM_ModelPool then PM_BuildModelPool() end
    local mdl = "models/player/kleiner.mdl"
    for _ = 1, 12 do
        local candidate = PM_ModelPool[math.random(#PM_ModelPool)]
        if PM_IsValidPlayerModel(candidate) then
            mdl = candidate
            break
        end
    end
    ply:SetModel(mdl)
    ply:SetupHands()

    -- ── Random tint colour ───────────────────────────────────────────────────
    local hue      = math.random(0, 359)
    local baseCol  = HSVToColor(hue, 0.75, 1.0)
    baseCol.a      = 255
    ply.PM_BaseColor = baseCol
    ply:SetColor(baseCol)
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)

    -- ── Random HL2 loadout: 1 primary + 1 sidearm + 1 melee ────────────────
    ply:StripWeapons()
    ply:Give(PM_PRIMARIES[math.random(#PM_PRIMARIES)])
    ply:Give(PM_SECONDARIES[math.random(#PM_SECONDARIES)])
    ply:Give(PM_MELEE[math.random(#PM_MELEE)])

    -- Generous ammo for all possible weapon types (no hunting for pickups)
    ply:GiveAmmo(300, "AR2")
    ply:GiveAmmo(8,   "AR2AltFire")   -- energy balls
    ply:GiveAmmo(120, "Buckshot")
    ply:GiveAmmo(30,  "XBowBolt")
    ply:GiveAmmo(300, "Pistol")
    ply:GiveAmmo(48,  "357")

    -- Per-life pill limit (Q-key chaos pill)
    ply.PM_PillsLeft = math.random(30, 60)

    -- Preserve kill count across deaths AND across kick/rejoin within a round
    ply.PM_Kills = ply.PM_Kills or PM_KillCache[ply:SteamID()] or 0
    ply.PM_LastPill = CurTime()   -- reset auto-pill countdown fresh each life
    ply.PM_Effects  = {}
    ply.PM_JumpCount = 0

    -- Re-kill permadead players immediately so DeathThink holds them
    if ply.PM_PermaDead then
        timer.Simple(0, function()
            if IsValid(ply) and ply:Alive() then ply:Kill() end
        end)
    end
end

-- ─── Death / kill tracking ────────────────────────────────────────────────────
function GM:PlayerDeath(ply, inflictor, attacker)
    self.BaseClass.PlayerDeath(self, ply, inflictor, attacker)
    PM_OnAnyPlayerDied(ply)
    PM_CleanupPlayerEffects(ply)

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then
        attacker.PM_Kills = (attacker.PM_Kills or 0) + 1
        PM_BroadcastChat(
            attacker:Nick() .. " fragged " .. ply:Nick() ..
            "  [" .. attacker.PM_Kills .. "/" .. PM_KILL_LIMIT .. "]"
        )
        if attacker.PM_Kills >= PM_KILL_LIMIT then
            PM_EndGame()
        end
    end
end

-- ─── Round end ────────────────────────────────────────────────────────────────
PM_RoundEnding = false   -- blocks auto-pill during the inter-round countdown

function PM_EndGame()
    local players = player.GetAll()
    if #players == 0 then return end
    if PM_RoundEnding then return end   -- already counting down; don't double-fire

    PM_RoundEnding = true

    local winner, chud = players[1], players[1]
    for _, p in ipairs(players) do
        local k = p.PM_Kills or 0
        if k > (winner.PM_Kills or 0) then winner = p end
        if k < (chud.PM_Kills  or 0) then chud  = p end
    end

    PM_BroadcastChat("═══════════════════════════════")
    PM_BroadcastChat("ROUND OVER!")
    PM_BroadcastChat("Winner: " .. winner:Nick() .. "  —  " .. (winner.PM_Kills or 0) .. " kills")
    if chud ~= winner then
        PM_BroadcastChat("Chud:   " .. chud:Nick()   .. "  —  " .. (chud.PM_Kills  or 0) .. " kills")
    end
    PM_BroadcastChat("New round in 10 seconds…")
    PM_BroadcastChat("═══════════════════════════════")

    timer.Simple(10, function()
        PM_RoundEnding = false
        PM_KillCache   = {}   -- clear persisted scores; new round, clean slate
        for _, p in player.Iterator() do
            p.PM_Kills = 0
            PM_CleanupPlayerEffects(p)
        end
        PM_PermaCounters = {}
        for _, p in player.Iterator() do
            if IsValid(p) then p:Spawn() end
        end
        PM_BroadcastChat("New round started! First to " .. PM_KILL_LIMIT .. " kills wins.")
    end)
end

-- ─── Hold permadead players dead ─────────────────────────────────────────────
function GM:PlayerDeathThink(ply)
    if ply.PM_PermaDead then return end
    self.BaseClass.PlayerDeathThink(self, ply)
end

function GM:PlayerDisconnected(ply)
    -- Preserve kill count so a kicked player can rejoin with their score intact
    if (ply.PM_Kills or 0) > 0 then
        PM_KillCache[ply:SteamID()] = ply.PM_Kills
    end
    PM_CleanupPlayerEffects(ply)
    PM_PermaCounters[ply:SteamID()] = nil
end

-- ─── Damage overrides ─────────────────────────────────────────────────────────
function GM:EntityTakeDamage(ent, dmginfo)
    if not ent:IsPlayer() then return end
    local fx = ent.PM_Effects
    if not fx then return end

    -- Invincibility checks (order matters: apply first, short-circuit)
    if fx.petrified  then dmginfo:SetDamage(0) return end
    if fx.mario_star then dmginfo:SetDamage(0) return end

    -- AND LIVE: cap damage so the player survives at 5 HP
    if IsValid(ent.PM_AndLiveCar) and dmginfo:GetInflictor() == ent.PM_AndLiveCar then
        local maxDmg = math.max(0, ent:Health() - 5)
        dmginfo:SetDamage(maxDmg)
        ent.PM_AndLiveCar = nil  -- one-time protection
        return
    end

    -- Metal Mario: halve incoming damage
    if fx.metal_mario then dmginfo:ScaleDamage(0.5) end

    -- Rage Virus spread: infect victim if attacker used a Slot-0 (melee) weapon
    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent then
        local atkFx = attacker.PM_Effects
        if atkFx and atkFx.rage_virus then
            local infl = dmginfo:GetInflictor()
            if IsValid(infl) and infl:IsWeapon() and infl:GetSlot() == 0 then
                PM_ApplyRageVirus(ent)
            end
        end
    end
end

-- ─── Post-think effects ───────────────────────────────────────────────────────
function GM:PlayerPostThink(ply)
    local fx = ply.PM_Effects
    if not fx then return end

    if fx.mario_star then
        for _, other in ipairs(ents.FindInSphere(ply:GetPos(), 55)) do
            if IsValid(other) and other:IsPlayer() and other ~= ply and other:Alive() then
                if not other.PM_StarHitTime or CurTime() - other.PM_StarHitTime > 0.5 then
                    other:TakeDamage(25, ply, ply)
                    other.PM_StarHitTime = CurTime()
                end
            end
        end
    end

    if fx.heart_attack then
        for _, other in ipairs(ents.FindInSphere(ply:GetPos(), 50)) do
            if IsValid(other) and other:IsPlayer() and other ~= ply and other:Alive() then
                if not other.PM_Effects or not other.PM_Effects.heart_attack then
                    PM_ApplyHeartAttack(other)
                end
            end
        end
    end

    if fx.double_fire then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then wep:SetNextPrimaryFire(CurTime()) end
    end

    if fx.infinite_ammo then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then
            local clip = wep:GetMaxClip1()
            if clip > 0 then wep:SetClip1(clip) end
        end
    end

    if ply:IsOnGround() then ply.PM_JumpCount = 0 end

    -- ── Rage Virus: force the player to hold their knife (Slot 0) ───────────
    if fx.rage_virus then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetSlot() ~= 0 then
            for _, w in ipairs(ply:GetWeapons()) do
                if w:GetSlot() == 0 then
                    ply:SelectWeapon(w:GetClass())
                    break
                end
            end
        end
    end

    -- ── Italian Dinosaur: touching another player watermelons them ───────────
    if fx.italian_dino then
        for _, other in ipairs(ents.FindInSphere(ply:GetPos(), 55)) do
            if IsValid(other) and other:IsPlayer() and other ~= ply and other:Alive() then
                PM_TurnIntoWatermelon(other, ply)
            end
        end
    end

    -- ── Bounce YOU: auto-jump each time the player touches the ground ────────
    if fx.bounce_you then
        if ply:IsOnGround() then
            local now = CurTime()
            if not ply.PM_BounceTime or now - ply.PM_BounceTime > 0.4 then
                ply.PM_BounceTime = now
                local vel = ply:GetVelocity()
                vel.z = 380
                ply:SetVelocity(vel)
            end
        end
    end
end

-- ─── Double jump ──────────────────────────────────────────────────────────────
hook.Add("KeyPress", "PM_DoubleJump", function(ply, key)
    if key ~= IN_JUMP then return end
    if not ply.PM_Effects or not ply.PM_Effects.double_jump then return end
    if ply:IsOnGround() then return end
    if (ply.PM_JumpCount or 0) >= 1 then return end
    ply.PM_JumpCount = 1
    local vel = ply:GetVelocity()
    vel.z = 300
    ply:SetVelocity(vel)
end)

-- ─── Zero spread / Rage Virus bullet block ────────────────────────────────────
function GM:EntityFireBullets(ent, data)
    if not ent:IsPlayer() then return true end
    local fx = ent.PM_Effects
    if not fx then return true end

    if fx.zero_spread then
        data.Spread = Vector(0, 0, 0)
    end

    -- Rage Virus: only the knife (Slot 0) may fire; cancel all other shots
    if fx.rage_virus then
        local wep = ent:GetActiveWeapon()
        if IsValid(wep) and wep:GetSlot() ~= 0 then
            return false
        end
    end

    return true
end

-- ─── Metal Mario jump cap ─────────────────────────────────────────────────────
function GM:SetupMove(ply, mv, cmd)
    if ply.PM_Effects and ply.PM_Effects.metal_mario then
        local vel = mv:GetVelocity()
        if vel.z > 150 then
            vel.z = 150
            mv:SetVelocity(vel)
        end
    end
    self.BaseClass.SetupMove(self, ply, mv, cmd)
end
