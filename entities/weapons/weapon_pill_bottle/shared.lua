SWEP.PrintName       = "Pill Bottle"
SWEP.Author          = ""
SWEP.Purpose         = "Take pills. What could go wrong?"
SWEP.Instructions    = "LMB: Stimulant  RMB: Depressant  R: Chaos"

SWEP.Spawnable       = false
SWEP.AdminSpawnable  = false

SWEP.HoldType        = "normal"

-- No view/world model needed; use a placeholder so GMod doesn't complain
SWEP.ViewModel       = "models/weapons/v_pistol.mdl"
SWEP.WorldModel      = "models/props_lab/jar01a.mdl"
SWEP.DrawAmmo        = false
SWEP.DrawCrosshair   = true

SWEP.Primary   = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

-- Shared cooldown (mirrors server PILL_COOLDOWN for client feedback)
SWEP.NextUse = 0

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextUseTime")
end

function SWEP:Initialize()
    self:SetNextUseTime(0)
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    self:SetHoldType("normal")
    return true
end

-- Suppress default fire animations / sounds
function SWEP:PrimaryAttack()   end
function SWEP:SecondaryAttack() end

function SWEP:DrawHUD()
    draw.SimpleTextOutlined(
        "LMB Stimulant  |  RMB Depressant  |  R Chaos",
        "DermaDefault", ScrW() * 0.5, ScrH() - 80,
        Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black
    )
end

-- Hide the viewmodel entirely
function SWEP:DrawWorldModel() end
function SWEP:DrawViewModel()  end
