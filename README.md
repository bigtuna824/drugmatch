# Drugmatch

A chaotic Garry's Mod deathmatch gamemode where luck matters as much as skill. Press **Q** to consume a Chaos Pill and trigger one of **58 random effects** — anything from double speed to instant death to opening LinkedIn.

## Gameplay

- First player to **30 kills** wins the round
- Rounds reset 10 seconds after a winner is crowned; kill counts persist by SteamID within a round
- Every spawn gives you a **random loadout**, **random player model**, and **random color tint**
- Each life comes with **30–60 pills** — run out and you die
- Sit still for **20 seconds** and you get force-fed a pill

## Chaos Pills

Pills are consumed by pressing **Q**. Effects are weighted — common effects roll at weight 10, rare ones (like Tactical Nuke) at weight 1.

### Effect Categories

| Category | Examples |
|---|---|
| Instant | Instant Death, Kick, Flashbang, Tactical Nuke |
| Movement | Speed x2, No Friction, Inverted Controls, Double Jump, Shaky Aim |
| Perception | Blindness, Darkness, Low Resolution, Nausea, Fake Lag/FPS Drop |
| Combat | Mario Star (invincibility aura), Infinite Ammo, Double Fire Rate, Rage Virus |
| World | Spawn zombies, skeletons, explosive barrels, Hot Potato |
| Weird | Italian Dinosaur, LinkedIn, Fentanyl, Weeping Angel, Uh Oh |
| Meta | Permadeath, Triple Threat (3 random effects at once) |

### Notable Effects

- **Permadeath** — You're dead until 10 other players die first
- **Hot Potato** — A potato that passes to nearby players and explodes after 30 seconds
- **Weeping Angel** — An AI pursuer that freezes when you look at it
- **Rage Virus** — Melee-only; spreads to players you hit
- **Italian Dinosaur** — Touch other players to turn them into watermelons
- **Tactical Nuke** — Kills everyone on the server with explosions
- **Triple Threat** — Rolls 3 random effects simultaneously
- **Fentanyl** — Exponential speed increase until you die

## File Structure

```
drugmatch/
├── gamemode/
│   ├── init.lua          # Round logic, kill tracking, spawning
│   ├── shared.lua        # Weapon definitions, effect weight table
│   ├── sv_pills.lua      # Server-side pill effects (58 total)
│   ├── sv_effects.lua    # Server-side effect helpers
│   ├── sv_entities.lua   # Hot Potato, Weeping Angel server logic
│   ├── cl_init.lua       # Client initialization
│   ├── cl_hud.lua        # Kill counter HUD
│   ├── cl_effects.lua    # Client-side visual effects
│   └── cl_entities.lua   # Client-side entity rendering
├── entities/
│   └── weapons/
│       └── weapon_pill_bottle/  # The Q-press pill weapon
└── content/
    └── materials/drugmatch/     # Textures and materials
```

## Installation

1. Clone or download this repo into your GMod gamemodes folder:
   ```
   garrysmod/gamemodes/drugmatch/
   ```
2. Launch Garry's Mod, create a server, and select **Drugmatch** from the gamemode list.
