-- Client-side effect state and implementations

PM_ClientEffects = {}   -- effectID -> { endTime, startTime, ... }

-- ─── Effect registry ──────────────────────────────────────────────────────────
net.Receive("PM_ClientEffect", function()
    local id       = net.ReadUInt(8)
    local duration = net.ReadFloat()
    PM_StartClientEffect(id, duration)
end)

net.Receive("PM_ClientEffectEnd", function()
    local id = net.ReadUInt(8)
    if id == 0 then
        PM_ClearAllClientEffects()
    else
        PM_EndClientEffect(id)
    end
end)

local function HasEffect(id)
    local fx = PM_ClientEffects[id]
    return fx and CurTime() < fx.endTime
end

-- Ringing sound (looping ambient) ─────────────────────────────────────────────
local RING_SOUND = "ambient/alarms/klaxon1.wav"

function PM_StartClientEffect(id, duration)
    local endTime = (duration > 0) and (CurTime() + duration) or (CurTime() + 9999)
    PM_ClientEffects[id] = { endTime = endTime, startTime = CurTime() }

    -- Immediate side-effects on activation
    if id == CHAOS_RINGING then
        -- Looping ringing: play immediately then repeat every 3 s until effect ends
        local function playRing()
            local ply = LocalPlayer()
            if IsValid(ply) then ply:EmitSound(RING_SOUND, 75, 80, 0.7, CHAN_STATIC) end
        end
        playRing()
        timer.Create("PM_RingLoop", 3, 0, function()
            if not HasEffect(CHAOS_RINGING) then
                timer.Remove("PM_RingLoop")
                return
            end
            playRing()
        end)
    elseif id == CHAOS_RANDOM_SENS then
        local s = math.Rand(0.1, 8.0)
        RunConsoleCommand("sensitivity", tostring(s))
    elseif id == CHAOS_LINKEDIN then
        gui.OpenURL("https://www.linkedin.com")
        PM_ClientEffects[id] = nil  -- one-shot
    elseif id == CHAOS_FAFA then
        -- Pick a random but consistent screen position for the duration
        PM_FafaPos = {
            x = math.random(15, 65) / 100,   -- centre-x as fraction of screen width
            y = math.random(15, 65) / 100,   -- centre-y as fraction of screen height
        }
    elseif id == CHAOS_LOW_GRAPHICS then
        PM_ApplyLowGraphics()
    elseif id == CHAOS_FLASHBANG then
        -- HL2 explosion crack used as flashbang bang (see asset note at bottom)
        surface.PlaySound("ambient/explosions/explode_3.wav")
    end

    -- Schedule auto-cleanup for timed effects
    if duration > 0 then
        timer.Simple(duration, function()
            PM_EndClientEffect(id)
        end)
    end
end

function PM_EndClientEffect(id)
    PM_ClientEffects[id] = nil
    -- Cleanup
    if id == CHAOS_RINGING then
        timer.Remove("PM_RingLoop")
        local ply = LocalPlayer()
        if IsValid(ply) then ply:StopSound(RING_SOUND) end
    elseif id == CHAOS_RANDOM_SENS then
        RunConsoleCommand("sensitivity", "3")
    elseif id == CHAOS_LOW_GRAPHICS then
        PM_RestoreGraphics()
    elseif id == CHAOS_FAFA then
        PM_FafaPos = nil
    elseif id == CHAOS_HALLUC_PLAYERS then
        PM_ClearHallucPlayers()
    elseif id == CHAOS_HALLUC_ITEMS then
        PM_ClearHallucItems()
    end
end

function PM_ClearAllClientEffects()
    for id, _ in pairs(PM_ClientEffects) do
        PM_EndClientEffect(id)
    end
    PM_ClientEffects = {}
    PM_FutureVisionEffect = nil  -- clear future vision display on death

    -- Stop Mario Star music if it's playing on this client (covers the case
    -- where the local player dies before the 10 s star timer expires)
    if PM_MarioStarMusic then
        local ply = LocalPlayer()
        if IsValid(ply) then ply:StopSound(PM_MarioStarMusic) end
        PM_MarioStarMusic = nil
    end

    -- Clear any active jumpscare model
    if IsValid(PM_JumpscareModel) then
        PM_JumpscareModel:Remove()
        PM_JumpscareModel = nil
    end
end

-- ─── Graphics settings ────────────────────────────────────────────────────────
local PM_GraphicsBackup = {}
local PM_LowConvars = {
    mat_picmip            = "4",
    r_shadows             = "0",
    r_flashlightdepthtexture = "0",
    mat_reduceparticles   = "1",
    r_drawdetailprops     = "0",
    r_waterdrawreflection = "0",
}

function PM_ApplyLowGraphics()
    for cv, val in pairs(PM_LowConvars) do
        local c = GetConVar(cv)
        if c then PM_GraphicsBackup[cv] = c:GetString() end
        RunConsoleCommand(cv, val)
    end
end

function PM_RestoreGraphics()
    for cv, old in pairs(PM_GraphicsBackup) do
        RunConsoleCommand(cv, old)
    end
    PM_GraphicsBackup = {}
end

-- ─── Invert controls (movement-only: WASD reversed, camera unchanged) ────────
hook.Add("CreateMove", "PM_InvertControls", function(cmd)
    if not HasEffect(CHAOS_INVERT_CONTROLS) then return end
    cmd:SetForwardMove(-cmd:GetForwardMove())
    cmd:SetSideMove(-cmd:GetSideMove())
end)

-- ─── Shaky aim (gentle offset, updated every 0.1 s) ─────────────────────────
local PM_ShakeOff  = Angle(0, 0, 0)
local PM_ShakeNext = 0

hook.Add("CreateMove", "PM_ShakyAim", function(cmd)
    if not HasEffect(CHAOS_SHAKY_AIM) then
        PM_ShakeOff = Angle(0, 0, 0)
        return
    end
    local now = CurTime()
    if now > PM_ShakeNext then
        PM_ShakeOff  = Angle(math.Rand(-1.2, 1.2), math.Rand(-1.2, 1.2), 0)
        PM_ShakeNext = now + 0.1
    end
    local ang = cmd:GetViewAngles()
    ang.p = ang.p + PM_ShakeOff.p
    ang.y = ang.y + PM_ShakeOff.y
    cmd:SetViewAngles(ang)
end)

-- ─── Random movement ─────────────────────────────────────────────────────────
local PM_RandMoveDir  = { fwd = 0, side = 0 }
local PM_RandMoveNext = 0

hook.Add("CreateMove", "PM_RandomMovement", function(cmd)
    if not HasEffect(CHAOS_RANDOM_MOVEMENT) then return end
    if CurTime() > PM_RandMoveNext then
        PM_RandMoveDir.fwd  = math.random(-1, 1) * 200
        PM_RandMoveDir.side = math.random(-1, 1) * 200
        PM_RandMoveNext = CurTime() + 0.6
    end
    cmd:SetForwardMove(PM_RandMoveDir.fwd)
    cmd:SetSideMove(PM_RandMoveDir.side)
end)

-- ─── Boogie (spin view + forced third-person, no sv_cheats required) ─────────
hook.Add("CreateMove", "PM_Boogie", function(cmd)
    if not PM_BoogieActive then return end
    local ang = cmd:GetViewAngles()
    ang.y = ang.y + 8
    cmd:SetViewAngles(ang)
end)

hook.Add("CalcView", "PM_BoogieView", function(ply, origin, angles, fov)
    if not PM_BoogieActive then return end
    local view         = {}
    view.origin        = origin - angles:Forward() * 110 + angles:Up() * 25
    view.angles        = angles
    view.fov           = fov
    view.drawviewer    = true   -- render the local player model (third-person)
    return view
end)

-- ─── Fake FPS Drop (busy-loop CPU waste, scales with intensity) ───────────────
-- PM_FakeFPSActive and PM_FakeFPSIntensity are set by the net receiver in cl_init.
hook.Add("Think", "PM_FakeFPSDrop", function()
    if not PM_FakeFPSActive then return end
    local intensity = PM_FakeFPSIntensity or 40
    -- Stall for intensity × 0.25 ms per frame (10 % → 2.5 ms, 70 % → 17.5 ms)
    local delayS = intensity * 0.00025
    local t = SysTime()
    repeat until SysTime() - t >= delayS
end)

-- ─── Nausea (screen warp) ────────────────────────────────────────────────────
hook.Add("RenderScreenspaceEffects", "PM_Nausea", function()
    if not HasEffect(CHAOS_NAUSEA) then return end
    local t = CurTime()
    DrawMotionBlur(math.abs(math.sin(t * 2)) * 0.12 + 0.08, 0.6, 0.04)
end)

-- ─── Darkness ────────────────────────────────────────────────────────────────
hook.Add("RenderScreenspaceEffects", "PM_Darkness", function()
    if not HasEffect(CHAOS_DARKNESS) then return end
    DrawColorModify({
        ["$pp_colour_brightness"] = -0.9,
        ["$pp_colour_contrast"]   = 1.0,
        ["$pp_colour_colour"]     = 0.0,
    })
end)

-- ─── Mario Star visual (gold tint) ───────────────────────────────────────────
hook.Add("RenderScreenspaceEffects", "PM_MarioStar", function()
    if not HasEffect(CHAOS_MARIO_STAR) then return end
    local pulse = math.abs(math.sin(CurTime() * 8)) * 0.3
    DrawColorModify({
        ["$pp_colour_brightness"] = pulse,
        ["$pp_colour_colour"]     = 0.0,
    })
end)

-- ─── Flashbang overlay (RenderScreenspaceEffects for reliability) ─────────────
hook.Add("RenderScreenspaceEffects", "PM_Flashbang", function()
    local fx = PM_ClientEffects[CHAOS_FLASHBANG]
    if not fx then return end
    local elapsed = CurTime() - fx.startTime
    local dur     = fx.endTime - fx.startTime
    local frac    = 1 - math.Clamp(elapsed / dur, 0, 1)
    if frac <= 0 then return end
    DrawColorModify({
        ["$pp_colour_brightness"] = frac,
        ["$pp_colour_contrast"]   = 1.0,
        ["$pp_colour_colour"]     = math.max(0, 1 - frac),
    })
end)

-- ─── Blindness overlay (RenderScreenspaceEffects for reliability) ─────────────
hook.Add("RenderScreenspaceEffects", "PM_Blindness", function()
    if not HasEffect(CHAOS_BLINDNESS) then return end
    DrawColorModify({
        ["$pp_colour_brightness"] = -1.0,
        ["$pp_colour_contrast"]   = 1.0,
        ["$pp_colour_colour"]     = 0.0,
    })
end)

-- ─── Low-resolution overlay (dense grid + colour degradation) ────────────────
hook.Add("HUDPaint", "PM_LowResOverlay", function()
    if not HasEffect(CHAOS_LOW_RES) then return end
    local sw, sh = ScrW(), ScrH()
    local gs = 6  -- tighter grid (was 10) for stronger pixelation feel
    draw.NoTexture()
    surface.SetDrawColor(0, 0, 0, 130)
    for y = 0, sh, gs do
        surface.DrawRect(0, y, sw, 1)
    end
    for x = 0, sw, gs do
        surface.DrawRect(x, 0, 1, sh)
    end
end)

hook.Add("RenderScreenspaceEffects", "PM_LowResEffect", function()
    if not HasEffect(CHAOS_LOW_RES) then return end
    -- Desaturate + reduce contrast to sell the "crushed quality" look
    DrawColorModify({
        ["$pp_colour_brightness"] = -0.05,
        ["$pp_colour_contrast"]   = 0.65,
        ["$pp_colour_colour"]     = 0.25,
    })
end)

-- ─── Jumpscare (HL2 corpse model snaps in front of the player) ───────────────
PM_JumpscareModel = nil   -- active ClientsideModel or nil

local JUMPSCARE_SOUNDS = {
    "npc/stalker/stlkr_pain01.wav",
    "npc/stalker/stlkr_pain02.wav",
    "npc/stalker/stlkr_pain03.wav",
    "npc/stalker/stlkr_pain04.wav",
}

local CORPSE_MODELS = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_04.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_02.mdl",
}

function PM_TriggerJumpscare(count, interval)
    if count <= 0 then return end
    surface.PlaySound(JUMPSCARE_SOUNDS[math.random(#JUMPSCARE_SOUNDS)])

    -- Remove any previous corpse
    if IsValid(PM_JumpscareModel) then
        PM_JumpscareModel:Remove()
        PM_JumpscareModel = nil
    end

    local ply = LocalPlayer()
    if IsValid(ply) then
        local corpse = ClientsideModel(
            CORPSE_MODELS[math.random(#CORPSE_MODELS)],
            RENDERGROUP_OPAQUE
        )
        if IsValid(corpse) then
            -- Place it; the Think hook below keeps it glued to the player's view
            local eyePos = ply:EyePos()
            local fwd    = ply:EyeAngles():Forward()
            corpse:SetPos(eyePos + fwd * 70 - Vector(0, 0, 35))
            corpse:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
            -- Try to strike a dead/idle pose
            local seq = corpse:LookupSequence("dead01")
                     or corpse:LookupSequence("death1")
                     or 0
            corpse:SetSequence(seq)
            PM_JumpscareModel = corpse

            -- Auto-remove after 0.55 s then schedule next scare
            timer.Simple(0.55, function()
                if IsValid(PM_JumpscareModel) then
                    PM_JumpscareModel:Remove()
                    PM_JumpscareModel = nil
                end
                if count > 1 and interval > 0 then
                    timer.Simple(interval, function()
                        PM_TriggerJumpscare(count - 1, interval)
                    end)
                end
            end)
        end
    end
end

-- Keep corpse model glued to the player's face while visible
hook.Add("Think", "PM_JumpscareTrack", function()
    if not IsValid(PM_JumpscareModel) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local eyePos = ply:EyePos()
    local fwd    = ply:EyeAngles():Forward()
    PM_JumpscareModel:SetPos(eyePos + fwd * 70 - Vector(0, 0, 35))
    PM_JumpscareModel:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
end)

-- ─── Hallucination Players ────────────────────────────────────────────────────
PM_HallucPlayers = {}

function PM_SpawnHallucPlayer(pos)
    local models = {
        "models/player/combine_soldier.mdl",
        "models/player/group03/male_02.mdl",
        "models/player/group03/female_01.mdl",
    }
    local ent = ClientsideModel(models[math.random(#models)], RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, math.random(360), 0))
    ent:SetNoDraw(false)
    ent.PM_IsHalluc  = true
    ent.PM_MoveDir   = Angle(0, math.random(360), 0):Forward() * 20
    ent.PM_NextMove  = CurTime() + math.Rand(2, 5)
    table.insert(PM_HallucPlayers, ent)
end

function PM_ClearHallucPlayers()
    for _, ent in ipairs(PM_HallucPlayers) do
        if IsValid(ent) then ent:Remove() end
    end
    PM_HallucPlayers = {}
end

hook.Add("Think", "PM_HallucPlayerThink", function()
    for i = #PM_HallucPlayers, 1, -1 do
        local ent = PM_HallucPlayers[i]
        if not IsValid(ent) then
            table.remove(PM_HallucPlayers, i)
        else
            if CurTime() > ent.PM_NextMove then
                ent.PM_MoveDir  = Angle(0, math.random(360), 0):Forward() * 20
                ent.PM_NextMove = CurTime() + math.Rand(2, 4)
            end
            ent:SetPos(ent:GetPos() + ent.PM_MoveDir * FrameTime())
        end
    end
end)

hook.Add("CreateMove", "PM_HallucShoot", function(cmd)
    if not cmd:KeyDown(IN_ATTACK) then return end
    if #PM_HallucPlayers == 0 then return end
    local ply = LocalPlayer()
    local tr  = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * 2000,
        filter = ply,
    })
    for i = #PM_HallucPlayers, 1, -1 do
        local ent = PM_HallucPlayers[i]
        if IsValid(ent) and (ent:GetPos() - tr.HitPos):Length() < 60 then
            ent:Remove()
            table.remove(PM_HallucPlayers, i)
        end
    end
end)

-- ─── Hallucination Items ──────────────────────────────────────────────────────
PM_HallucItems = {}

local HALLUC_ITEM_MODELS = {
    [1] = "models/items/healthkit.mdl",
    [2] = "models/items/battery.mdl",
    [3] = "models/weapons/w_rocket_launcher.mdl",
}

function PM_SpawnHallucItem(pos, itemType)
    local mdl = HALLUC_ITEM_MODELS[itemType] or HALLUC_ITEM_MODELS[1]
    local ent = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
    if not IsValid(ent) then return end
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, math.random(360), 0))
    ent.PM_ItemType = itemType
    table.insert(PM_HallucItems, { ent = ent, type = itemType })
end

function PM_ClearHallucItems()
    for _, item in ipairs(PM_HallucItems) do
        if IsValid(item.ent) then item.ent:Remove() end
    end
    PM_HallucItems = {}
end

hook.Add("Think", "PM_HallucItemPickup", function()
    if #PM_HallucItems == 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local plyPos = ply:GetPos()
    for i = #PM_HallucItems, 1, -1 do
        local item = PM_HallucItems[i]
        if IsValid(item.ent) then
            if (item.ent:GetPos() - plyPos):Length() < 50 then
                net.Start("PM_HallucItemTouch")
                net.WriteUInt(item.type, 4)
                net.SendToServer()
                item.ent:Remove()
                table.remove(PM_HallucItems, i)
            end
        else
            table.remove(PM_HallucItems, i)
        end
    end
end)

-- ─── Lonely — hide all other players from the afflicted player ────────────────
-- Returning true from PrePlayerDraw skips rendering that player entirely for us.
hook.Add("PrePlayerDraw", "PM_LonelyHide", function(drawPly)
    if drawPly == LocalPlayer() then return end   -- always see ourselves
    if HasEffect(CHAOS_LONELY) then return true end
end)

-- ─── Fafa — haunting orange face overlaid at low opacity ─────────────────────
-- Put the image at: gamemodes/drugmatch/content/materials/drugmatch/fafa.png
-- The Material() call below looks for materials/drugmatch/fafa.png in the GFS.
local PM_FafaMat = nil
local function PM_GetFafaMat()
    if not PM_FafaMat then
        PM_FafaMat = Material("drugmatch/fafa.png", "noclamp smooth")
    end
    return PM_FafaMat
end

PM_FafaPos = nil   -- set by PM_StartClientEffect when CHAOS_FAFA activates

hook.Add("HUDPaint", "PM_FafaOverlay", function()
    if not HasEffect(CHAOS_FAFA) then return end
    if not PM_FafaPos           then return end
    local mat = PM_GetFafaMat()
    if not mat or mat:IsError() then return end

    local size = math.min(ScrW(), ScrH()) * 0.32
    local x    = PM_FafaPos.x * ScrW() - size * 0.5
    local y    = PM_FafaPos.y * ScrH() - size * 0.5

    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, 55)   -- low opacity
    surface.DrawTexturedRect(x, y, size, size)
end)
