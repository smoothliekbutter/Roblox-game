# Clover Battlegrounds

A Black Clover–inspired battlegrounds game for Roblox, in the style of Jujutsu Shenanigans.

All code lives in `src/` as Luau files and gets synced into Roblox Studio with [Rojo](https://rojo.space).

## Quick start: just play it

1. Download [`build/CloverBattlegrounds.rbxlx`](build/CloverBattlegrounds.rbxlx). On GitHub, open the file and click the download button.
2. Double-click it to open it in Roblox Studio.
3. Press **Play** (F5).

Everyone spawns as R6 wearing their own avatar (`src/server/CharacterLoader.luau`). You don't need to change Game Settings.

## Live sync (for development)

With live sync, every code change shows up in Studio instantly, without re-downloading anything.

1. Install [Git](https://git-scm.com/downloads) and clone this repo:
   ```
   git clone https://github.com/smoothliekbutter/Roblox-game.git
   cd Roblox-game
   git checkout claude/black-clover-roblox-design-8fiypn
   ```
2. Install the Rojo command-line tool. The simplest way is to download `rojo` from the
   [Rojo releases page](https://github.com/rojo-rbx/rojo/releases) and put it somewhere on your PATH.
3. Install the **Rojo** plugin in Studio: Toolbox → Plugins → search "Rojo" (by Rojo).
4. In the repo folder, run:
   ```
   rojo serve
   ```
5. Open `build/CloverBattlegrounds.rbxlx` (or any place) in Studio, open the **Rojo** plugin and click **Connect**.
6. To get new changes: `git pull`. Rojo pushes them into Studio automatically.

## Controls

| Input | Action |
|---|---|
| Left click (hold to chain) | M1 combo, 4 hits. The 4th hit ragdolls and guard-breaks. |
| Hold **Space** on the 4th hit | Uppercut finisher that launches the target into the air |
| 4th hit while in the air | Downslam finisher with a crater |
| **1 2 3 4** | Character skills. Most have an air version: use them mid-jump. |
| **R** | Character special (each character has their own) |
| **G** | Awaken when the red meter is full. It fills as you fight: about 90 damage dealt. |
| **Q** + WASD | Dash: front, back, left or right |
| Hold **F** | Block. Only works facing the attacker. |
| Tap **F** right before a hit | Perfect block: stuns the attacker |
| **Q** while stunned or ragdolled | Evasive breakout (needs a full cyan bar) |
| **LeftShift** | Toggle shift lock (or the SHIFT LOCK button in the top bar) |

The **CHARACTERS** button in the top bar, next to chat, opens the character picker. Switching is blocked for 5 seconds after combat.

## Characters

### Anti-Magic Knight (Asta)

A close-range rushdown character built like Vessel (Jujutsu Shenanigans) and Hero Hunter (The Strongest Battlegrounds). He swings a demon-slaying greatsword.

| Key | Base | Black Form (after G) |
|---|---|---|
| 1 | **Bull Thrust**: rockets forward on anti-magic. **Steer it mid-move** with WASD or the camera to curve around and chase people. Catches the target in an 8-hit slash barrage, then pushes them back still stunned so you can M1 straight into them. **Air:** a diving thrust (also steerable). | **Black Hurricane**: spinning charge that drags enemies along |
| 2 | **Black Meteorite**: unblockable lunge grab that rockets you both into the sky, charges the blade at the top, then slams down like a meteor into a huge crater (shockwave dome, ground cracks, flying debris, black lightning). **Air:** dives down at them and spikes them straight into the ground. | **Black Slash**: piercing anti-magic slash wave |
| 3 | **Black Divider**: anti-magic streams into the blade, then a huge sweeping crescent cleave. Press **3** again on the red glint for a Perfect Divider: bigger cut, impact frame, and a black crescent that keeps flying. **Air:** hangs in the air while charging, then front-flips the blade down onto whoever's below and spikes them into the ground. | **Grand Divider**: huge guard-breaking cleave plus a giant slash wave |
| 4 | **Anti-Magic Deflect**: raises an anti-magic barrier on the blade that counters every attack type. Melee attackers get a frozen impact frame, then a diagonal slash that throws them aside. Projectiles get sent back. **Air:** hangs in the air with the guard up. | **Demon-Destroyer**: grab, carve, explosive finisher that heals 30% |
| R | **Anti-Magic Leap**: blasts off the ground in a big steerable leap. Press **R** again in the air (or use it while already airborne) for **Meteor Plunge**: hangs for a beat, then dives behind the sword and stabs it into the ground, blasting everyone nearby away. | (same) |
| G | **Black Form**: a 2-second transformation. Anti-magic gathers as the world darkens, then explodes into a black pillar that blows everyone away, and he drops into his stance. For 40s you get +25% damage, more speed and new moves, plus the look: black flames, a horn, a black arm and sword, and a devil wing with its own idle (it breathes, stretches, tucks back when you run and beats in the air). | |

More grimoires are listed as "coming soon" in the picker.

## Test dummies

Three dummies spawn in front of you:

- **Dummy** (white) stands still and heals after 3 seconds.
- **Blocking Dummy** (blue) always blocks and faces you. Use it to practice guard breaks.
- **Attacking Dummy** (red) throws full M1 strings at you. Use it to practice blocks, perfect blocks and Evasive.

## Project layout

```
src/
  shared/   ReplicatedStorage.Shared: Config, Kits (roster), CombatState, Remotes, Impulse
  server/   ServerScriptService.Server: CombatService, Hitbox, Projectile, Ragdoll, Dummies, CharacterLoader
    Kits/   one module per character: skills, awakening, weapon model
  client/   StarterPlayerScripts.Client: Input, Moves, PoseAnimator, M1Animations, VFX, CameraShake,
            HUD, TopBar, ShiftLock
    Kits/   one module per character: animations and VFX
```

- **Adding a character:** add an entry to `src/shared/Kits.luau`, a server module in `src/server/Kits/` (`Skills`, `AwakenedSkills`, `Awaken`, `Equip`) and a client module in `src/client/Kits/` (`PlayM1`, `OnSkill`, `SetAwakened`), all named after the kit id.
- **Balancing:** general numbers live in `src/shared/Config.luau`, per-character ones in `src/shared/Kits.luau`. Set `Config.Debug.ShowHitboxes = true` to see hitboxes.
- **Server-authoritative:** the server decides every hit, block and cooldown. Clients only send inputs and draw effects.
- **Animations are code:** `src/client/M1Animations.luau` holds keyframed R6 poses, played by `PoseAnimator` by overriding Motor6Ds. Nothing needs uploading and there are no animation-permission problems. Uploaded animation IDs can replace them later.
- **VFX are client-side:** the server sends `("EffectName", data)` and `src/client/VFX.luau` draws it. Effects use only textures built into Roblox, so nothing needs uploading.
