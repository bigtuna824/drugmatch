AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function TryTakePill(wep, pillID)
    local ply = wep:GetOwner()
    if not IsValid(ply) or not ply:Alive() then return end

    -- Pill limit: kill the player when they hit their random threshold
    ply.PM_PillsLeft = ply.PM_PillsLeft or math.random(30, 60)
    if ply.PM_PillsLeft <= 0 then return end

    ply.PM_PillsLeft = ply.PM_PillsLeft - 1
    wep:SetNextUseTime(ply.PM_PillsLeft)  -- reuse NetworkVar to sync count to client

    if ply.PM_PillsLeft == 0 then
        PM_BroadcastChat(ply:Nick() .. " took too many pills...")
        timer.Simple(0.5, function()
            if IsValid(ply) then ply:Kill() end
        end)
        return
    end

    if pillID == PILL_STIMULANT then
        PM_ApplyStimulant(ply)
        PM_BroadcastChat(ply:Nick() .. " took a Stimulant Pill")
    elseif pillID == PILL_DEPRESSANT then
        PM_ApplyDepressant(ply)
        PM_BroadcastChat(ply:Nick() .. " took a Depressant Pill")
    elseif pillID == PILL_CHAOS then
        local idx = ply.PM_NextChaosEffect or math.random(CHAOS_COUNT)
        ply.PM_NextChaosEffect = nil
        PM_ApplyChaos(ply, idx)
    end
end

function SWEP:PrimaryAttack()
    TryTakePill(self, PILL_STIMULANT)
end

function SWEP:SecondaryAttack()
    TryTakePill(self, PILL_DEPRESSANT)
end

-- R key (IN_RELOAD) fires chaos pill
function SWEP:Think()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    if ply:KeyPressed(IN_RELOAD) then
        TryTakePill(self, PILL_CHAOS)
    end
end
