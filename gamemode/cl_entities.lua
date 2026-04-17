-- Client-side entity registrations
-- These mirror the server definitions so that models actually render on clients.
-- Only the minimum needed for rendering is defined here; logic stays in sv_entities.lua.

local POTATO_CL = {}
POTATO_CL.Type = "anim"
POTATO_CL.Base = "base_anim"
scripted_ents.Register(POTATO_CL, "pm_hot_potato")

local ANGEL_CL = {}
ANGEL_CL.Type = "anim"
ANGEL_CL.Base = "base_anim"
scripted_ents.Register(ANGEL_CL, "pm_weeping_angel")
