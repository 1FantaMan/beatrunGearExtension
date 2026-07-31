# Beatrun Player API Reference

Everything below is readable/callable on a `Player` entity (`ply:GetXxx()` etc.),
based on reading JonnyBro/beatrun's own gamemode source. Realm is noted per
section — shared NetworkVars are readable both client and server; a few
methods only exist in one realm (their file only runs there).

## Contents

1. [XP & Leveling](#1-xp--leveling)
2. [Overdrive (speed-boost state)](#2-overdrive-speed-boost-state)
3. [Movement state NetworkVars](#3-movement-state-networkvars)
4. [Parkour state management](#4-parkour-state-management)
5. [View/animation](#5-viewanimation)
6. [OnParkour trick events](#6-onparkour-trick-events)
7. [Custom hooks](#7-custom-hooks)
8. [Relevant ConVars](#8-relevant-convars)
9. [Notes for our combo mod](#9-notes-for-our-combo-mod)

---

## 1. XP & Leveling

Two parallel implementations exist — which one is "live" depends on the server type:

| Realm  | File        | Active when                                                                               |
| ------ | ----------- | ----------------------------------------------------------------------------------------- |
| Server | `sv/XP.lua` | Real dedicated server only (`if not game.IsDedicated() then return end` at the top)       |
| Client | `cl/XP.lua` | Always loaded, but only _acts_ when `not game.IsDedicated()` (singleplayer/listen server) |

This is exactly the split we already had to work around for our own bonus-XP feature.

**Methods:**
| Method | Realm | Purpose |
|---|---|---|
| `ply:GetLevel()` | both | Current Beatrun level |
| `ply:GetXP()` | both | Current raw XP total |
| `ply:AddXP(amount)` | both (different implementations) | Adds XP and re-checks for level-ups |
| `ply:SetLevel(level)` | both | Force-sets level (recalculates XP to match) |
| `ply:GetLevelRatio()` | client only | Progress fraction (0–1) toward the next level |
| `ply:LevelUp()` | both | Re-checks XP against the curve and applies any pending level-ups |

**The leveling curve** (`sh/!Helpers.lua`) — XP required to _reach_ a given level:

```
CalcXPForNextLevel(level) = round(0.25·level³ + 0.8·level² + 2·level)
```

This is a cubic curve, so the XP cost per level grows quickly — level 5 needs noticeably more than 5× what level 1 needs, not a flat multiple.

**Per-trick XP awards** (`ParkourXP` table, same file) — this is the _base_ amount before Beatrun's own level-scaling multiplier is applied:

| Trick                                          | Base XP |
| ---------------------------------------------- | ------- |
| `climb`, `swingbar`                            | 4       |
| `roll`                                         | 3       |
| `vault`, `wallrunh`, `wallrunv`, `springboard` | 2       |
| `sidestep`, `slide`, `coil`, `step`            | 1       |

That base amount then gets scaled by the player's own level in both the server and client award paths:

```
xp = ParkourXP[event] * max(round(ply:GetLevel() * 0.05), 1)
```

So a level-20 player earns roughly the same per-trick XP as a level-1 player earns from a mid-tier trick — the level-scaling is a slow ramp (5% per level), not a big multiplier. This is the actual reference point behind "1–3 XP per trick" you compared our bonus against.

---

## 2. Overdrive (speed-boost state)

A temporary boosted-movement state, separate from our own flow system, but conceptually similar — worth knowing about since it already exists and might overlap or interact with what we're building.

| Method                                              | Purpose                                                             |
| --------------------------------------------------- | ------------------------------------------------------------------- |
| `ply:InOverdrive()`                                 | Bool — true whenever `GetOverdriveMult() ~= 1`                      |
| `ply:GetOverdriveMult()` / `SetOverdriveMult()`     | The active speed multiplier (defaults to `1`, i.e. off)             |
| `ply:GetOverdriveCharge()` / `SetOverdriveCharge()` | A charge meter (starts at `0`) feeding into when overdrive turns on |

What it actually does mechanically: `GetOverdriveMult()` is multiplied directly into velocity in wallrun, sliding, and springboard/vault code (e.g. `vel:Mul(ply:GetOverdriveMult())` shows up in `Wallrun.lua`, `Sliding.lua`, `Vaulting.lua`, `WallrunME.lua`). Elsewhere it's used as a flat multiplier on other things — e.g. `runnerhands/shared.lua` uses `1.25` while in overdrive vs `1` normally for a couple of effects. It also gates a few safety mechanics: `SafetyRoll.lua` skips its "you're going too fast, force a roll" logic while `InOverdrive()` is true, and disables high-speed fall damage the same way.

Net effect: overdrive is Beatrun's own "you're in the zone" state — faster movement, some safety checks relaxed. It's a reasonable candidate to sync with or trigger off of, if we want our flow state to feel connected to Beatrun's native systems rather than existing in total isolation.

---

## 3. Movement state NetworkVars

All declared in `player_class/player_beatrun.lua` unless noted otherwise. Each `NetworkVar("Type", n, "Name")` call generates a `Get`/`Set` pair automatically (e.g. `NetworkVar("Int", 0, "Climbing")` → `ply:GetClimbing()` / `ply:SetClimbing()`).

### Climbing

| Var                                                | Type   | Notes                                                                            |
| -------------------------------------------------- | ------ | -------------------------------------------------------------------------------- |
| `Climbing`                                         | Int    | `0` = not climbing, nonzero = active (matches the trick-event list in section 6) |
| `ClimbingTime`                                     | Float  |                                                                                  |
| `ClimbingDelay`                                    | Float  | Cooldown-style timer                                                             |
| `ClimbingStart` / `ClimbingEnd` / `ClimbingEndOld` | Vector | The ledge positions involved in the current/previous climb                       |
| `ClimbingAngle`                                    | Angle  |                                                                                  |

### Wallrun

| Var                                | Type   | Notes                                                         |
| ---------------------------------- | ------ | ------------------------------------------------------------- |
| `Wallrun`                          | Int    | `0` = none, nonzero = active (values documented in section 6) |
| `WallrunTime` / `WallrunSoundTime` | Float  |                                                               |
| `WallrunDir` / `WallrunOrigVel`    | Vector |                                                               |
| `WallrunCount`                     | Int    | Consecutive wallrun counter                                   |
| `WallrunElevated`                  | Bool   |                                                               |

### Sliding

| Var                                                             | Type   | Notes                                                 |
| --------------------------------------------------------------- | ------ | ----------------------------------------------------- |
| `Sliding`                                                       | Bool   |                                                       |
| `SlidingTime` / `SlidingDelay` / `SlidingVel` / `SlidingStrafe` | Float  |                                                       |
| `SlidingLastPos`                                                | Vector |                                                       |
| `SlidingSlippery`                                               | Bool   | Whether the current slide surface is slippery terrain |
| `SlidingSlipperyUpdate`                                         | Float  |                                                       |
| `SlidingAngle`                                                  | Angle  |                                                       |

### Diving

| Var    | Type | Notes |
| ------ | ---- | ----- |
| `Dive` | Bool |       |

### Vaulting/Mantling (`sh/Vaulting.lua` — separate custom getters, not raw NetworkVar)

| Method                                            | Notes                                      |
| ------------------------------------------------- | ------------------------------------------ |
| `ply:GetMantle()` / `SetMantle()`                 | `0` = none, `1` = vault, `2` = mantle/high |
| `ply:GetMantleLerp()` / `SetMantleLerp()`         | Blend/animation progress                   |
| `ply:GetMantleStartPos()` / `SetMantleStartPos()` |                                            |
| `ply:GetMantleEndPos()` / `SetMantleEndPos()`     | Start/end of the vault arc                 |

### Grappling, swinging, towing

| Var                                                      | Type   | Notes                                     |
| -------------------------------------------------------- | ------ | ----------------------------------------- |
| `Grappling`                                              | Bool   |                                           |
| `GrapplePos`                                             | Vector |                                           |
| `GrappleLength`                                          | Float  |                                           |
| `Swingbar` / `SwingbarLast`                              | Entity | Current / most-recent swingbar entity     |
| `Swingpipe`                                              | Entity |                                           |
| `SBOffset` / `SBOffsetSpeed` / `SBStartLerp` / `SBDelay` | Float  | Swingbar physics tuning                   |
| `SBPeak`                                                 | Int    |                                           |
| `SBDir`                                                  | Bool   |                                           |
| `Rabbit`                                                 | Entity | Appears to be a tow/vehicle-like mechanic |
| `RabbitSeat`                                             | Int    |                                           |

### Ladders

| Var                                           | Type   | Notes                       |
| --------------------------------------------- | ------ | --------------------------- |
| `Ladder`                                      | Entity | The ladder currently in use |
| `LadderDelay` / `LadderHeight` / `LadderLerp` | Float  |                             |
| `LadderEntering` / `LadderHand`               | Bool   |                             |
| `LadderStartPos` / `LadderEndPos`             | Vector |                             |

### Zipline

| Var                                                                  | Type   | Notes |
| -------------------------------------------------------------------- | ------ | ----- |
| `Zipline`                                                            | Entity |       |
| `ZiplineStart` / `ZiplineFraction` / `ZiplineSpeed` / `ZiplineDelay` | Float  |       |

### Melee

| Var                        | Type  | Notes                                                                       |
| -------------------------- | ----- | --------------------------------------------------------------------------- |
| `MeleeDamage`              | Int   |                                                                             |
| `MeleeTime` / `MeleeDelay` | Float |                                                                             |
| `Melee`                    | Int   | `0` = none, nonzero = attacking (matches the trick-event list in section 6) |

### Balance (beams)

| Var             | Type   | Notes |
| --------------- | ------ | ----- |
| `Balance`       | Float  |       |
| `BalanceEntity` | Entity |       |

### Misc movement

| Var                                       | Type  | Notes                                                                   |
| ----------------------------------------- | ----- | ----------------------------------------------------------------------- |
| `MEMoveLimit` / `MESprintDelay` / `MEAng` | Float | Mirror's Edge-style camera-lock tuning used by the BodyAnim/view system |
| `StepRight`                               | Bool  | Footstep alternation                                                    |
| `StepRelease`                             | Float |                                                                         |
| `CrouchJump`                              | Bool  |                                                                         |
| `CrouchJumpTime`                          | Float |                                                                         |
| `CrouchJumpBlocked`                       | Bool  |                                                                         |
| `SafetyRollKeyTime` / `SafetyRollTime`    | Float |                                                                         |
| `SafetyRollAng`                           | Angle |                                                                         |
| `Quickturn`                               | Bool  |                                                                         |
| `QuickturnTime`                           | Float |                                                                         |
| `QuickturnAng`                            | Angle |                                                                         |
| `JumpTurn`                                | Bool  |                                                                         |
| `JumpTurnRecovery`                        | Float |                                                                         |
| `WasOnGround`                             | Bool  |                                                                         |

---

## 4. Parkour state management

Also in `player_class/player_beatrun.lua`:

| Method                                          | Purpose                                                                      |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| `ply:ResetParkourState()`                       | Resets all the movement NetworkVars above back to defaults                   |
| `ply:SaveParkourState()` / `LoadParkourState()` | Snapshot/restore all of them at once (used around things like vehicle entry) |
| `ply:ResetParkourTimes()`                       | Resets just the timer-style vars                                             |
| `ply:InOverdrive()`                             | See section 2                                                                |
| `ply:GetRolling()`                              | Whether currently in a safety-roll                                           |

---

## 5. View/animation

| Method                        | Realm  | Purpose                                                                                                                                                                                         |
| ----------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ply:ShouldDrawLocalPlayer()` | client | Standard GMod method; true = your own body renders in first person. Beatrun's BodyAnim system checks this constantly — this is the one we already used for the trail's first/third-person split |
| `ply:CLViewPunch(angle)`      | client |                                                                                                                                                                                                 |
| `ply:GetCLViewPunchAngles()`  | client |                                                                                                                                                                                                 |

---

## 6. OnParkour trick events

All event strings fired via `hook.Run("OnParkour", event, ply)` — this is the full set of `event` values you'll see in our own `OnParkour(action, ply)` handler.

### Jump & Fall

| Event              | When                           |
| ------------------ | ------------------------------ |
| `jump`             | Standard jump from ground      |
| `jumpfar`          | Long jump (no ground beneath)  |
| `jumpstill`        | Jump while stationary          |
| `fall`             | Loses ground contact and falls |
| `falluncontrolled` | Uncontrolled descent           |
| `fallrecover`      | Stabilizes after fall          |
| `land`             | Lands on ground after airtime  |

### Sliding & Diving

| Event                | When                            |
| -------------------- | ------------------------------- |
| `slide`              | Standard slide                  |
| `slide45`            | Slide on slippery terrain       |
| `divestart`          | Initiates dive                  |
| `diveslidestart`     | Dive-to-slide transition begins |
| `diveslideend`       | Dive-slide ends standing        |
| `diveslideendcrouch` | Dive-slide ends crouching       |
| `jumpslide`          | Jumps during a slide            |

### Climbing & Hanging

| Event               | When                        |
| ------------------- | --------------------------- |
| `hangfoldedstart`   | Grabs ledge in folded hang  |
| `hangfoldedheaveup` | Heaves up from folded hang  |
| `hangfoldedendhang` | Folded to standard hang     |
| `hangjump`          | Jumps off a hang            |
| `hangend`           | Exits hanging               |
| `hangstrafeleft`    | Strafes left while hanging  |
| `hangstraferight`   | Strafes right while hanging |
| `climbheave`        | Heave action while climbing |
| `climbhard`         | Difficult climb movement    |

### Ladder

| Event                    | When                      |
| ------------------------ | ------------------------- |
| `ladderenter`            | Enters ladder from ground |
| `ladderenterhang`        | Enters ladder from air    |
| `ladderclimbleft`        | Climbs with left hand     |
| `ladderclimbright`       | Climbs with right hand    |
| `ladderclimbdownfast`    | Rapidly descends          |
| `ladderexittoplefthand`  | Exits top with left hand  |
| `ladderexittoprighthand` | Exits top with right hand |

### Wall & Vault

| Event              | When                     |
| ------------------ | ------------------------ |
| `wallrunv`         | Vertical wall run        |
| `wallrunh`         | Horizontal wall run      |
| `jumpwallrun`      | Jumps off wall run       |
| `jumpwallrunleft`  | Jumps left off wall run  |
| `jumpwallrunright` | Jumps right off wall run |
| `vault`            | Vaults low obstacle      |
| `vaultonto`        | Vaults onto surface      |
| `vaulthigh`        | Vaults high obstacle     |
| `vaultontohigh`    | Vaults onto high surface |
| `vaultkong`        | Kong vault               |
| `springboard`      | Springboard / trampoline |
| `stepup`           | Small step-up            |

### Balance

| Event                     | When                    |
| ------------------------- | ----------------------- |
| `walkbalancefwd`          | Walking forward on beam |
| `walkbalancestill`        | Standing still on beam  |
| `walkbalancefalloffleft`  | Falls off beam left     |
| `walkbalancefalloffright` | Falls off beam right    |

### Swing

| Event            | When              |
| ---------------- | ----------------- |
| `swingbar`       | Swinging on bar   |
| `swingjump`      | Jumps off swing   |
| `swingpipeleft`  | Swings pipe left  |
| `swingpiperight` | Swings pipe right |

### Crouch & Roll

| Event        | When                    |
| ------------ | ----------------------- |
| `coil`       | Charges crouch jump     |
| `landcoil`   | Lands after coil jump   |
| `roll`       | Safety roll / breakfall |
| `disarmscar` | Disarm scar technique   |

### Melee

| Event           | When                                   |
| --------------- | -------------------------------------- |
| `meleeslide`    | Punch while sliding                    |
| `meleeairstill` | Kick while stationary in air           |
| `meleeair`      | Drop kick in air                       |
| `meleewrleft`   | Punch during left wallrun              |
| `meleewrright`  | Punch during right wallrun             |
| `meleeairhit`   | Melee hit connects in air              |
| `jumpslow`      | Jump with reduced velocity after melee |

### Other Movement

| Event                | When                         |
| -------------------- | ---------------------------- |
| `ziplinestart`       | Starts zipline               |
| `jumpturnlandcrouch` | Quick turn lands crouching   |
| `jumpturnlandstand`  | Quick turn lands standing    |
| `sidestepleft`       | Sidestep dodge left          |
| `sidestepright`      | Sidestep dodge right         |
| `step`               | Random footstep (10% chance) |

---

## 7. Custom hooks

| Hook                                                                                            | Notes                                                                                                                                                       |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OnParkour(event, ply)`                                                                         | Fires per trick — the one we already use, `event` is one of the strings in section 6                                                                        |
| `PlayerFootstep` / `PlayerFootstepME`                                                           | Footstep events                                                                                                                                             |
| `BeatrunSpawn`                                                                                  | Beatrun-specific spawn hook, separate from `PlayerSpawn`/`PlayerInitialSpawn` — worth checking whether it fires more reliably for our respawn-reset logic   |
| `BeatrunDrawHUD` / `BeatrunHUDCourse`                                                           | HUD-related — likely intended for addons that want to draw alongside Beatrun's own HUD without clashing                                                     |
| `BodyAnimPreStart` / `BodyAnimStart` / `BodyAnimThink` / `BodyAnimRemove` / `BodyAnimPreRemove` | Lifecycle hooks around the `BodyAnim`/`BodyAnimMDLarm` system used for trick animations — the same system behind our (abandoned) first-person trail attempt |
| `BodyAnimCalcView` / `CalcViewBA` / `BodyAnimDrawArm`                                           | Lower-level hooks into that same view/arm system                                                                                                            |
| `Infection_LastManGun` / `BuildModeState`                                                       | Gamemode-variant-specific, likely not relevant to a combo mod                                                                                               |

---

## 8. Relevant ConVars

All `FCVAR_REPLICATED` (readable via `GetConVar` on both realms) unless noted.

| ConVar                                                    | Default | Purpose                                                              |
| --------------------------------------------------------- | ------- | -------------------------------------------------------------------- |
| `Beatrun_SpeedLimit`                                      | 325     | Already used in our speed-ratio math                                 |
| `Beatrun_QuakeJump`, `Beatrun_SideStep`, `Beatrun_Disarm` | 1       | Movement toggles                                                     |
| `Beatrun_AllowOverdriveInMultiplayer`                     | 0       | Off by default in multiplayer                                        |
| `Beatrun_PuristWallrun`                                   | 1       | "Realistic" wallrunning toggle                                       |
| `Beatrun_RollSpeedLoss`                                   | 1       |                                                                      |
| `Beatrun_Totsugeki*`                                      | varies  | Dive-related toggles                                                 |
| `Beatrun_HealthRegen`                                     | 1       |                                                                      |
| `Beatrun_KickGlitch`                                      | 2       | 0 = disabled, 1 = velocity-multiplier style, 2 = Mirror's Edge-style |
| `Beatrun_LeRealisticClimbing`, `Beatrun_LedgeGrabDamage`  | 0       | Server-only, not replicated                                          |
