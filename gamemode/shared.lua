GM.Name      = "Drugmatch"
GM.Author    = ""
GM.Email     = ""
GM.Website   = ""
GM.TeamBased = false

-- Only chaos pill remains
PILL_CHAOS    = 3

-- Seconds between pill uses
PILL_COOLDOWN = 8

-- Kills required to end the round
PM_KILL_LIMIT = 30

-- Deaths required to escape permadeath
PERMA_DEATHS_NEEDED = 10

-- Chaos effect IDs  (1-43)
CHAOS_INSTANT_DEATH     = 1
CHAOS_KICK              = 2
CHAOS_PERMADEATH        = 3
CHAOS_BIG_HEAD          = 4
CHAOS_RINGING           = 5
CHAOS_RANDOM_SENS       = 6
CHAOS_RANDOM_MOVEMENT   = 7
CHAOS_BLINDNESS         = 8
CHAOS_LINKEDIN          = 9
CHAOS_PETRIFICATION     = 10
CHAOS_HALLUC_PLAYERS    = 11
CHAOS_FAKE_PING         = 12
CHAOS_FAKE_FPS          = 13
CHAOS_LOW_RES           = 14
CHAOS_FLASHBANG         = 15
CHAOS_HEART_ATTACK      = 16
CHAOS_NAUSEA            = 17
CHAOS_JUMPSCARE_REPEAT  = 18
CHAOS_INVERT_CONTROLS   = 19
CHAOS_GROW              = 20
CHAOS_SHAKY_AIM         = 21
CHAOS_HOT_POTATO        = 22
CHAOS_NO_CROSSHAIR      = 23
CHAOS_LOW_GRAPHICS      = 24
CHAOS_NO_FRICTION       = 25
CHAOS_WEEPING_ANGEL     = 26
CHAOS_DARKNESS          = 27
CHAOS_JUMPSCARE_ONE     = 28
CHAOS_SPAWN_ZOMBIES     = 29
CHAOS_SPAWN_PROPS       = 30
CHAOS_BOOGIE_BOMB       = 31
CHAOS_SHRINK            = 32
CHAOS_SPEED_2X          = 33
CHAOS_SPAWN_ITEMS       = 34
CHAOS_DOUBLE_FIRE       = 35
CHAOS_INFINITE_AMMO     = 36
CHAOS_DOUBLE_JUMP       = 37
CHAOS_FUTURE_VISION     = 38
CHAOS_METAL_MARIO       = 39
CHAOS_ZERO_SPREAD       = 40
CHAOS_HALLUC_ITEMS      = 41
CHAOS_MARIO_STAR        = 42
CHAOS_NUKE              = 43

CHAOS_BLOWBACK          = 44
CHAOS_INVISIBLE         = 45
CHAOS_RANDOM_TELEPORT   = 46
CHAOS_SKELETON_ARMY     = 47
CHAOS_RAGE_VIRUS        = 48
CHAOS_BARRELS           = 49
CHAOS_ITALIAN_DINO      = 50
CHAOS_UH_OH             = 51
CHAOS_LONELY            = 52
CHAOS_AND_LIVE          = 53
CHAOS_TRIPLE_THREAT     = 54
CHAOS_BOUNCE_YOU        = 55

CHAOS_PANTS_ON_FIRE     = 56
CHAOS_FENTANYL          = 57
CHAOS_FAFA              = 58

CHAOS_COUNT = 58

CHAOS_NAMES = {
    [1]  = "Instant Death",
    [2]  = "Kicked from Match",
    [3]  = "Permadeath (10 deaths)",
    [4]  = "Big Head",
    [5]  = "Loud Ringing",
    [6]  = "Random Sensitivity",
    [7]  = "Random Movement",
    [8]  = "Blindness",
    [9]  = "Opens LinkedIn",
    [10] = "Petrification (30s)",
    [11] = "Hallucinations",
    [12] = "Ping Spike",
    [13] = "FPS Drop",
    [14] = "Decreased Resolution",
    [15] = "Flashbang",
    [16] = "Contagious Heart Attack",
    [17] = "Nausea",
    [18] = "Random Jumpscares",
    [19] = "Inverted Controls",
    [20] = "Grow x2",
    [21] = "Shaky Aim",
    [22] = "Hot Potato",
    [23] = "No Crosshair",
    [24] = "Lowest Graphics",
    [25] = "No Friction",
    [26] = "Weeping Angel",
    [27] = "Darkness",
    [28] = "Jumpscare",
    [29] = "Zombie Horde",
    [30] = "Prop Flood",
    [31] = "Boogie Bomb",
    [32] = "Shrink x0.5",
    [33] = "Speed x2",
    [34] = "Item Flood",
    [35] = "Double Fire Rate",
    [36] = "Infinite Ammo (20s)",
    [37] = "Double Jump",
    [38] = "Future Vision",
    [39] = "Metal Mario",
    [40] = "Zero Spread",
    [41] = "Hallucinate Items",
    [42] = "Mario Star",
    [43] = "Tactical Nuke",
    [44] = "Blowback",
    [45] = "Invisible (20s)",
    [46] = "Random Teleport",
    [47] = "Skeleton Army",
    [48] = "Rage Virus",
    [49] = "Barrels o' Fun",
    [50] = "Italian Dinosaur (30s)",
    [51] = "Uh Oh",
    [52] = "Lonely (30s)",
    [53] = "AND LIVE",
    [54] = "Triple Threat",
    [55] = "Bounce YOU (20s)",
    [56] = "Pants on Fire",
    [57] = "Fentanyl",
    [58] = "Fafa",
}

-- Ensure clients receive the Fafa image from the gamemode content folder.
-- Place the file at: gamemodes/drugmatch/content/materials/drugmatch/fafa.png
if SERVER then
    resource.AddFile("materials/drugmatch/fafa.png")
end

-- Net strings declared server-side only
if SERVER then
    util.AddNetworkString("PM_TakePill")
    util.AddNetworkString("PM_PillAnnounce")
    util.AddNetworkString("PM_ClientEffect")
    util.AddNetworkString("PM_ClientEffectEnd")
    util.AddNetworkString("PM_FutureVision")
    util.AddNetworkString("PM_PermaDeathCount")
    util.AddNetworkString("PM_FakePing")
    util.AddNetworkString("PM_FakeFPS")
    util.AddNetworkString("PM_Jumpscare")
    util.AddNetworkString("PM_HallucPlayers")
    util.AddNetworkString("PM_HallucItems")
    util.AddNetworkString("PM_HallucItemTouch")
    util.AddNetworkString("PM_BoogieBomb")
    util.AddNetworkString("PM_BoogieEnd")
    util.AddNetworkString("PM_ChatMsg")
end
