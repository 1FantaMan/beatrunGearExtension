# Beatrun External Modding — AI Context Brief

Context document for an AI assistant helping build GMod addons that hook into
**Beatrun** (github.com/JonnyBro/beatrun, a third-party parkour movement
gamemode) from outside its own source. Read this fully before responding to
any request in this domain.

## Ground rules

- **Never edit Beatrun's own gamemode files.** All addon code lives in a
  separate addon folder, under `lua/autorun/`. This is a hard constraint, not
  a preference.
- **Never assert a Beatrun method/hook/ConVar exists unless it appears in
  this document or you've verified it directly against the live source.**
  Guessing plausible-sounding names has produced real, shipped bugs in this
  project before — see section 10. If unsure, say so and offer to check the
  source rather than asserting.
- This document is a point-in-time snapshot. If it conflicts with the live
  Beatrun source, trust the source.

---

## 1. Loading rules (GMod autorun)

| Path | Realm |
|---|---|
| `lua/autorun/server/*.lua` | Server only |
| `lua/autorun/client/*.lua` | Client only |
| `lua/autorun/*.lua` (no subfolder) | Shared — runs independently on both realms |

No `include()`/`AddCSLuaFile()` needed for autorun files themselves; only for
files loaded *from* one (e.g. a shared module in `lua/modules/`).

---

## 2. Primary hook: OnParkour

```lua
hook.Add("OnParkour", "UniqueID", function(action, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    -- action is one of the strings in section 3
end)
```

Fires server-side once per trick. The `IsValid`/`IsPlayer` guard is
mandatory — the movement library can pass a non-player `ply` for some events.

---

## 3. OnParkour event strings (`action` values)

**Jump & Fall:** `jump`, `jumpfar`, `jumpstill`, `fall`, `falluncontrolled`, `fallrecover`, `land`

**Sliding & Diving:** `slide`, `slide45`, `divestart`, `diveslidestart`, `diveslideend`, `diveslideendcrouch`, `jumpslide`

**Climbing & Hanging:** `hangfoldedstart`, `hangfoldedheaveup`, `hangfoldedendhang`, `hangjump`, `hangend`, `hangstrafeleft`, `hangstraferight`, `climbheave`, `climbhard`

**Ladder:** `ladderenter`, `ladderenterhang`, `ladderclimbleft`, `ladderclimbright`, `ladderclimbdownfast`, `ladderexittoplefthand`, `ladderexittoprighthand`

**Wall & Vault:** `wallrunv`, `wallrunh`, `jumpwallrun`, `jumpwallrunleft`, `jumpwallrunright`, `vault`, `vaultonto`, `vaulthigh`, `vaultontohigh`, `vaultkong`, `springboard`, `stepup`

**Balance:** `walkbalancefwd`, `walkbalancestill`, `walkbalancefalloffleft`, `walkbalancefalloffright`

**Swing:** `swingbar`, `swingjump`, `swingpipeleft`, `swingpiperight`

**Crouch & Roll:** `coil`, `landcoil`, `roll`, `disarmscar`

**Melee:** `meleeslide`, `meleeairstill`, `meleeair`, `meleewrleft`, `meleewrright`, `meleeairhit`, `jumpslow`

**Other:** `ziplinestart`, `jumpturnlandcrouch`, `jumpturnlandstand`, `sidestepleft`, `sidestepright`, `step`

---

## 4. Player state (NetworkVar getters, readable both realms)

| Getter | Values | Meaning |
|---|---|---|
| `ply:GetMantle()` | Int: `0`=none, `1`=vault, `2`=mantle/high | Vaulting or mantling |
| `ply:GetWallrun()` | Int: `0`=none, nonzero=active | Wall running |
| `ply:GetClimbing()` | Int: `0`=none, nonzero=active | Climbing a surface |
| `ply:GetMelee()` | Int: `0`=none, nonzero=active | Melee animation |
| `ply:GetSliding()` | Bool | Sliding |
| `ply:GetDive()` | Bool | Diving |
| `ply:GetGrappling()` | Bool | Grappling hook active |
| `ply:GetRolling()` | Bool | Safety-roll in progress |
| `ply:GetCrouchJump()` | Bool | Crouch-jump charged |
| `ply:GetLadderEntering()` | Bool | Entering a ladder |
| `ply:GetWallrunElevated()` | Bool | Elevated wallrun variant |
| `ply:InOverdrive()` | Bool | True whenever `GetOverdriveMult() ~= 1` |
| `ply:GetOverdriveMult()` / `SetOverdriveMult()` | Float, default `1` | Active speed multiplier |
| `ply:GetOverdriveCharge()` / `SetOverdriveCharge()` | Float, default `0` | Charge meter feeding overdrive activation |
| `ply:GetLevel()` / `ply:GetXP()` | int / int | Beatrun's own native level & XP |
| `ply:ShouldDrawLocalPlayer()` | client only, Bool | True = own body renders in first person |

Combined "is this player actively doing parkour right now" check used
throughout this addon:
```lua
local function IsInParkourAction(ply)
    return ply:GetMantle() ~= 0
        or ply:GetWallrun() ~= 0
        or ply:GetClimbing() ~= 0
        or ply:GetSliding()
        or ply:GetDive()
end
```

State reset/snapshot methods: `ply:ResetParkourState()`,
`ply:SaveParkourState()` / `LoadParkourState()`, `ply:ResetParkourTimes()`.

---

## 5. XP/leveling realm split — critical gotcha

Beatrun has **two separate implementations** of `ply:AddXP()` and related
methods:

- `sv/XP.lua` — real implementation, but the entire file is gated behind
  `if not game.IsDedicated() then return end`. Only loads/works on a real
  dedicated server.
- `cl/XP.lua` — a parallel client-side implementation, only actually acts
  when `not game.IsDedicated()` (singleplayer/listen server).

**Implication:** calling `ply:AddXP()` unconditionally from server-side addon
code silently no-ops in singleplayer/listen-server mode, because the real
server file never loaded there. Correct pattern: guard the server call with
`if ply.AddXP then ply:AddXP(amount) end`, AND net the value to the client so
it can call its own `ply:AddXP()` there too, covering both cases.

XP curve: `CalcXPForNextLevel(level) = round(0.25·level³ + 0.8·level² + 2·level)`.
Per-trick base XP (`ParkourXP` table): `climb`/`swingbar`=4, `roll`=3,
`vault`/`wallrunh`/`wallrunv`/`springboard`=2, `sidestep`/`slide`/`coil`/`step`=1,
scaled by `max(round(ply:GetLevel() * 0.05), 1)`.

**General lesson:** if something Beatrun-native doesn't seem to work, check
whether it has a client/server split like this before assuming it's broken
or absent.

---

## 6. Relevant ConVars

All `FCVAR_REPLICATED` (readable via `GetConVar` on both realms) unless noted.

| ConVar | Default | Purpose |
|---|---|---|
| `Beatrun_SpeedLimit` | 325 | Use this to compute speed *ratios* rather than hardcoding raw velocity thresholds |
| `Beatrun_QuakeJump`, `Beatrun_SideStep`, `Beatrun_Disarm` | 1 | Movement toggles |
| `Beatrun_AllowOverdriveInMultiplayer` | 0 | Off by default in multiplayer |
| `Beatrun_PuristWallrun` | 1 | "Realistic" wallrunning toggle |
| `Beatrun_KickGlitch` | 2 | 0=disabled, 1=velocity-multiplier, 2=Mirror's Edge-style |
| `Beatrun_LeRealisticClimbing`, `Beatrun_LedgeGrabDamage` | 0 | Server-only, not replicated |

---

## 7. Custom hooks besides OnParkour

| Hook | Notes |
|---|---|
| `PlayerFootstep` / `PlayerFootstepME` | Footstep events |
| `BeatrunSpawn` | Beatrun-specific spawn hook, separate from `PlayerSpawn`/`PlayerInitialSpawn` — check this if a respawn-reset via `PlayerSpawn` isn't firing reliably |
| `BeatrunDrawHUD` / `BeatrunHUDCourse` | For drawing alongside Beatrun's own HUD without clashing |
| `BodyAnimPreStart` / `BodyAnimStart` / `BodyAnimThink` / `BodyAnimRemove` / `BodyAnimPreRemove` | Lifecycle of the `BodyAnim`/`BodyAnimMDLarm` trick-animation system |
| `BodyAnimCalcView` / `CalcViewBA` / `BodyAnimDrawArm` | Lower-level hooks into that same view/arm system |

---

## 8. Adding your own synced per-player state

Beatrun's player NetworkVars can't be extended from outside its source — they
are declared at gamemode load in `player_class/player_beatrun.lua`. For your
own addon's state (a counter, a meter, a flag), use GMod's `NW2` system
instead:

```lua
-- server
ply:SetNW2Float("MyValue", value)   -- also SetNW2Int / SetNW2Bool

-- client, any file
local value = ply:GetNW2Float("MyValue", 0)  -- default if unset
```

---

## 9. Admin-configurable settings — verified working pattern

Beatrun itself uses a custom spawnmenu tool tab (`cl/ToolMenuSettings.lua` +
`sv/ReplicatedConvars.lua`) rather than the generic "Options" menu. The
working pattern, confirmed against that source:

1. Server: `CreateConVar(name, default, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY}, "", min, max)` per tunable, plus a server-side whitelist table of adjustable names.
2. Client: `spawnmenu.AddToolTab` / `AddToolCategory` / `AddToolMenuOption` to build a custom tab, with a slider per setting.
3. **A client cannot set a server-owned `FCVAR_REPLICATED` ConVar just by dragging a bound slider** — that silently fails. Net the new value to the server instead; server handler checks `ply:IsAdmin()`, checks the whitelist, then `GetConVar(name):SetString(value)`.
4. **Don't pass the ConVar name directly into `panel:NumSlider(label, convarName, ...)`** if you're handling the sync yourself — its internal auto-binding can fire `OnValueChanged` once during construction, before the slider has synced to the real value, and if you forward every `OnValueChanged` to the server, that spurious first call stomps the real value (often to `0`). Instead: pass `nil` for the ConVar arg, manually `slider:SetValue(GetConVar(name):GetFloat())` to seed it, and only *after* that attach your own `OnValueChanged` override.

---

## 10. Verified vs. hallucinated — do not repeat these

| Claim | Status |
|---|---|
| `ply:GetMantle()` returns `0`/`1`/`2` | **Real.** Verified against source. |
| `ply:GetVaulting()` | **Does not exist.** A plausible-sounding invented method that actually appeared in this project's code and had to be corrected to `ply:GetMantle() == 1`. |
| `for _, ply in player.Iterator() do` | **Correct usage.** |
| `for _, ply in ipairs(player.Iterator())` | **Wrong** — `player.Iterator()` is already an iterator function, wrapping it in `ipairs` is a real bug that shipped in this project before being caught. |
| `PlayersHandler:RemovePlayer` using `table.remove(self.plys, steamid)` | **Wrong** — `self.plys` is a hash table keyed by SteamID string, not an array; `table.remove` is for arrays. Use `self.plys[steamid] = nil`. |
| Sliders bound via `panel:NumSlider(label, convarName, ...)` auto-sync correctly with no side effects | **Wrong** — see section 9, point 4. This shipped as a real bug (all admin settings silently reset toward 0 on panel open) before being fixed. |

---

## 11. Where to look for more

- `beatrun_info.md` (this addon's repo root) — fuller exhaustive API reference this brief was condensed from, including all NetworkVar fields not just the getters, and more detail per section.
- `modding_beatrun_externally.md` (same repo) — narrative walkthrough of these same patterns, written for a human reading top-to-bottom rather than as a lookup reference.
- Beatrun source: https://github.com/JonnyBro/beatrun — ground truth for anything not covered above or anything that seems to have changed.
