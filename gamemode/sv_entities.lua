-- Inline scripted entity definitions: Hot Potato and Weeping Angel

-- ─── Hot Potato ───────────────────────────────────────────────────────────────
local POTATO = {}
POTATO.Type  = "anim"
POTATO.Base  = "base_anim"

function POTATO:Initialize()
    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(false)
    self.ExpireTime  = CurTime() + 30
    self.LastPass    = 0
    self.PassCooldown = 1.0
end

function POTATO:Think()
    -- Expired → explode
    if CurTime() > self.ExpireTime then
        self:Explode()
        return
    end

    local holder = self.Holder
    if not IsValid(holder) or not holder:Alive() then
        self:Remove()
        return
    end

    -- Float above holder
    self:SetPos(holder:GetPos() + Vector(0, 0, 85))
    self:SetAngles(Angle(0, CurTime() * 120 % 360, 0))

    -- Pass to nearest player in range (1 s cooldown between passes)
    if CurTime() - self.LastPass > self.PassCooldown then
        for _, ent in ipairs(ents.FindInSphere(holder:GetPos(), 70)) do
            if IsValid(ent) and ent:IsPlayer() and ent ~= holder and ent:Alive() then
                self:PassTo(ent)
                break
            end
        end
    end

    self:NextThink(CurTime())
    return true
end

function POTATO:PassTo(newHolder)
    local old = self.Holder
    self.Holder = newHolder
    self.LastPass = CurTime()
    if IsValid(old) then old.PM_Potato = nil end
    newHolder.PM_Potato = self

    PM_BroadcastChat(
        (IsValid(old) and old:Nick() or "???") ..
        " passed the Hot Potato to " .. newHolder:Nick() .. "!"
    )
end

function POTATO:Explode()
    local pos = self:GetPos()

    -- Visual explosion
    local eff = EffectData()
    eff:SetOrigin(pos)
    eff:SetScale(3)
    util.Effect("Explosion", eff)

    -- Kill holder
    local holder = self.Holder
    if IsValid(holder) then
        holder:Kill()
        holder.PM_Potato = nil
    end

    -- Serious (but usually non-lethal) damage to nearby players
    for _, ent in ipairs(ents.FindInSphere(pos, 250)) do
        if IsValid(ent) and ent:IsPlayer() and ent ~= holder then
            local hp = ent:GetHealth()
            -- Deal 75% of current HP, leaving at least 1
            local dmgAmt = math.max(1, math.floor(hp * 0.75))
            ent:TakeDamage(dmgAmt, self, self)
        end
    end

    self:Remove()
end

scripted_ents.Register(POTATO, "pm_hot_potato")

-- ─── Weeping Angel (GMan) ─────────────────────────────────────────────────────
local ANGEL = {}
ANGEL.Type = "anim"
ANGEL.Base = "base_anim"

function ANGEL:Initialize()
    self:SetModel("models/gman.mdl")
    self:SetSolid(SOLID_BBOX)
    -- MOVETYPE_FLY lets us control position directly each Think tick.
    -- MOVETYPE_STEP is for NPCs with nav meshes and ignores SetVelocity on
    -- scripted entities, which is why the angel was frozen before.
    self:SetMoveType(MOVETYPE_FLY)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetSequence(self:LookupSequence("idle01") or 0)
    self.MoveSpeed = 320   -- units per second
    self.Watched   = false
end

function ANGEL:Think()
    local THINK_INTERVAL = 0.05   -- seconds between ticks

    self.Watched = self:IsBeingWatched()

    local target = self.Target
    if not IsValid(target) or not target:Alive() then
        target = self:FindNearestPlayer()
        self.Target = target
    end

    if self.Watched or not IsValid(target) then
        -- Freeze: stay in place and hold idle pose
        self:SetSequence(self:LookupSequence("idle01") or 0)
    else
        -- Move directly toward target by updating position each tick
        local dir = (target:GetPos() - self:GetPos())
        dir.z = 0
        local dist = dir:Length()

        if dist > 0 then
            dir = dir / dist   -- normalise without creating a new vector
            local step = dir * self.MoveSpeed * THINK_INTERVAL
            self:SetPos(self:GetPos() + step)
            self:SetAngles(Angle(0, dir:Angle().y, 0))
            self:SetSequence(self:LookupSequence("walk01") or 0)
        end

        -- Kill target on contact
        if dist < 60 then
            target:Kill()
            PM_BroadcastChat("The Weeping Angel got " .. target:Nick() .. "!")
            self:Remove()
            return
        end
    end

    self:NextThink(CurTime() + THINK_INTERVAL)
    return true
end

-- Returns true if at least one player has LOS to the angel
function ANGEL:IsBeingWatched()
    local angelCenter = self:GetPos() + Vector(0, 0, 50)
    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        local eyePos = ply:EyePos()
        local toAngel = (angelCenter - eyePos):GetNormalized()
        local forward = ply:EyeAngles():Forward()
        if toAngel:Dot(forward) < 0.5 then continue end  -- outside ~60° cone

        local tr = util.TraceLine({
            start  = eyePos,
            endpos = angelCenter,
            filter = function(e)
                return e ~= ply and e ~= self
            end,
            mask   = MASK_OPAQUE,
        })
        if not tr.Hit then
            return true  -- clear line of sight
        end
    end
    return false
end

function ANGEL:FindNearestPlayer()
    local best, bestDist = NULL, math.huge
    for _, ply in player.Iterator() do
        if ply:Alive() then
            local d = self:GetPos():DistToSqr(ply:GetPos())
            if d < bestDist then
                bestDist = d
                best = ply
            end
        end
    end
    return best
end

scripted_ents.Register(ANGEL, "pm_weeping_angel")
