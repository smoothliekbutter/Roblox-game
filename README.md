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
| Left click (hold to chain) | M1 combo, 4 hits, a little over a third of a second apart. The 4th hit ragdolls and guard-breaks. |
| Hold **Space** on the 4th hit | Uppercut finisher: a launcher. They go limp and tumble about 10 studs up on heavier gravity, so it snaps up and straight back down, and can still be hit on the way: let go of Space, jump after them and keep swinging (the 4th air hit is the downslam). Holding Space for the uppercut never makes you jump. Short recovery after it. |
| 4th hit while in the air | Downslam finisher with a crater: 3 hits, jump, hit. The 3rd hit stuns long enough for it, the jump is free almost right away, and the swing reaches the ground below you |
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

A close-range rushdown character built like Vessel (Jujutsu Shenanigans) and Hero Hunter (The Strongest Battlegrounds). He swings the Demon-Slayer Sword as it looks in the series: a huge, broad black greatsword about as tall as he is, battered and stained, with a pointed tip, worn edges, a thin bronze crossbar and a long two-handed grip with a round pommel. (Only the look is big: hitboxes are the same as before.)

| Key | Base | Black Form (after G) |
|---|---|---|
| 1 | **Bull Thrust**: rockets forward on anti-magic. **Steer it mid-move** with WASD or the camera to curve around and chase people. Catches the target in a five-hit sword combo: a rising cut, a backhand, a spinning backhand, an overhead chop, then a beat coiled with the sword drawn back before a thrust that drives them back still stunned, so you can M1 straight into them. **Air:** a diving thrust (also steerable). If the dive catches no one, he drives the sword into the ground where he lands and blows out a crater that reaches about 11 studs around him (black dome, red shockwave, cracks, flying rocks, a black pillar, black lightning) that breaks guards and throws everyone in it up and away. | **Sword move 1**: depends on the sword in his hand (see *Black Form swords* below). With the Demon-Slayer Sword it's **Black Hurricane**. |
| 2 | **Black Meteorite** (grab): a standing grab, no dash. He plants and his free hand shoots out for their throat, anti-magic winding round it and black lightning crawling down his arm. It seizes whoever is within about 6 studs in front of him, unblockable. He hoists them up as anti-magic surges through them, then a vortex of anti-magic swallows them both: he whirls round three times holding them out at arm's length, leaning back and banking into the spin, bobbing up and down as it carries them into the sky. At the top he flips over head-down and dives, spinning like a drill (several full turns, faster as he falls, like TSB's "Head First"), drives them head-first into the ground in a huge crater (shockwave dome, ground cracks, flying debris, black lightning), and rolls back over onto his feet. **Air:** hangs in the air, grabs whoever is in front of him, spins them in a shorter vortex and dives head-first, spinning, into the ground. | **Sword move 2**: depends on the sword in his hand. With the Demon-Slayer Sword it's **Slayer Recall**. |
| 3 | **Black Divider**: anti-magic streams into the blade, then a huge sweeping crescent cleave. Press **3** again on the red glint for a Perfect Divider: bigger cut, impact frame, and a black crescent that keeps flying. **Air:** hangs in the air while charging, then front-flips the blade down onto whoever's below and spikes them into the ground. It reaches all the way down and also hits people lying on the floor. The ground version can't hit downed players, but hits harder. | **Grand Divider**: he raises the sword to the sky and a giant blade of anti-magic grows out of it as pillars and lightning build. Then he brings it down in one guard-breaking cleave that splits the ground open in a fissure, and a giant wave rolls on. **Air:** a full front flip of the giant blade that cleaves down onto whoever's below, splitting the ground beneath. |
| 4 | **Anti-Magic Deflect**: raises an anti-magic barrier on the blade that counters every attack type. Melee attackers get a frozen impact frame, then a diagonal slash that throws them aside. Projectiles get sent back. **Air:** hangs in the air with the guard up. | **Black Moon** (a roughly 6-second cutscene grab): a standing grab like Black Meteorite (no dash, his hand shoots out for whoever is right in front of him), seizes them by the throat and hurls them into the sky. Night falls, and he hovers in the sky in front of a giant moon, shadowed with a red rim (you can still see your avatar), both wings spread wide. Stars come out, clouds drift across the moon, mist creeps over the ground and rocks float up. He levels his sword at them, the blade catches the moonlight, then he flies straight through them in one backhand cut and stops past them, sword out at his side, everything freezes, and the cut lands: an X slash, the moon splits in half and they're cut down into a crater. The two players get a cinematic camera with letterbox bars; everyone nearby sees night fall. |
| R | **Anti-Magic Leap**: blasts off the ground in a big steerable leap. Press **R** again in the air (or use it while already airborne) for **Meteor Plunge**: hangs for a beat, then dives behind the sword and stabs it into the ground, blasting everyone nearby away. | **Swap Sword**: the grimoire opens and he draws one of his other three swords at random (10s cooldown). The old sword dissolves into black smoke, the new one forms in his hand out of anti-magic and its name flashes up. Moves 1 and 2 change with it. Black Form always starts, and ends, with the Demon-Slayer Sword. |
| G | **Black Form**: a 2-second transformation. Anti-magic gathers as the world darkens, then explodes into a black pillar that blows everyone away, and he drops into his stance. For 40s you get +25% damage, more speed and new moves, plus the look: black flames, a horn, a black arm and sword, and a devil wing with its own idle (it breathes, stretches, tucks back when you run and beats in the air). His grimoire comes out and circles him, open, its pages fluttering, for as long as Black Form lasts. | |

#### Black Form swords (R)

In Black Form, **R** swaps Asta's sword, and moves 1 and 2 belong to the sword in his hand. Each sword has its own model, built after its look in the series, and its moves after what it does there.

| Sword | Move 1 | Move 2 |
| --- | --- | --- |
| **Demon-Slayer Sword**: his first, huge greatsword | **Black Hurricane**: four full spins with the blade out, wrapped in a black tornado, dragging enemies along and finishing with an outward blast. **Air:** drills down out of the sky and spikes them into the ground. | **Slayer Recall**: hurls the sword like a boomerang. It spins out about 34 studs, cutting whoever it passes, and hangs there. Press **2** again (or wait 1.2s) and it flies back to his hand through whoever's in the way, dragging them to him, with black lightning pulling it in. No M1s until he catches it. Starting another move snaps it straight back. |
| **Demon-Dweller Sword**: a slender sword with black diamond markings | **Black Slash**: a huge diagonal cut that throws a piercing anti-magic wave (the Dweller's own technique in the series). **Air:** thrown down at an angle. | **Conquering Eon**: raises the Dweller and it drinks in magic for 0.6s. Spells that hit him are absorbed, and everyone within 18 studs has their mana siphoned (2 damage). Each absorb or siphon is a charge (up to 4) and lights one of the blade's markings. Then he lets it all out as one giant slash wave: bigger and stronger per charge, and it breaks guards from 3 charges. |
| **Demon-Destroyer Sword**: a curved blade with a clover on the guard | **Causality Break**: drives the Destroyer point-first into the ground. Curse-breaking anti-magic runs through the earth to the 4 closest enemies within 18 studs. It cuts them (unblockable) and breaks whatever they had up: counters, guard and Zetten-style stances. | **Severance**: a draw-cut as he dashes straight through them (untouchable during the dash). The cut hangs in the air, then lands a beat later. Whoever it hits is severed from their magic: all their moves are sealed for 3 seconds. |
| **Demon-Slasher Katana**: Yami's katana, turned anti-magic | **Infinite Slash**: Yami's two-handed overhead raise, then one chop. A cut opens along a straight line up to 60 studs ahead. It's unblockable, because it only cuts what Asta means to cut. **Air:** angled down at the ground. | **Zetten**: a still iai stance, reading ki for 1s. The first enemy within 20 studs to start a move (or swing at him) gets cut down before it lands: he flashes past them with a guard-breaking cut. If nobody moves, it ends in one quick cut ahead. |

More grimoires are listed as "coming soon" in the picker.

#### Numbers

Everyone has 100 HP.

| Move | Damage | Cooldown | Notes |
|---|---|---|---|
| M1 string | 4 / 4 / 4 / 6 | | 4th hit ragdolls and guard-breaks |
| Bull Thrust | 11.5 (2 + 1.5 + 1.5 + 1.5 + 2 + 3), air landing slam 6 AoE | 8s | Blockable. Combo starter. Long recovery if it whiffs. The air landing slam guard-breaks and ragdolls everyone within about 11 studs. |
| Black Meteorite | 12 (1 + 2 + 3 in the vortex + 6), air 10 | 13s | Unblockable standing grab, no dash: about 0.16s startup, reaches about 6 studs. Counters and i-frames beat it. Long recovery if it whiffs. |
| Black Divider | 11, perfect 17 (air 7 / 12) | 11s | Normal guard-breaks, perfect is unblockable. The air version reaches the ground below and also hits people lying on the floor; the ground version can't, but hits harder |
| Anti-Magic Deflect | 7 counter, 6 reflected | 14s | 0.65s window. Long recovery if nothing hits it. |
| Anti-Magic Leap (R) | 5 AoE plunge | 10s | Blockable |
| Black Form (G) | ×1.2 damage | ×0.85 cooldowns | +6 speed for 40s. About 90 damage dealt to charge. |
| Swap Sword (R in Black Form) | | 10s | Random other sword; per-slot cooldowns carry over |
| Black Hurricane (Slayer) | up to 9 + 5 | 9s | |
| Slayer Recall (Slayer) | 8 out, 6 back | 12s | The return drags them to him |
| Black Slash (Dweller) | 9 | 7s | Piercing projectile |
| Conquering Eon (Dweller) | 2 siphon, then 6 + 2 per charge | 15s | Absorbs spells; up to 4 charges; guard-breaks at 3 or more |
| Causality Break (Destroyer) | 8 | 15s | Unblockable; 4 closest within 18 studs; clears their counters and guard |
| Severance (Destroyer) | 10 | 12s | Seals all their moves for 3s |
| Infinite Slash (Slasher) | 9 | 13s | Unblockable line, up to 60 studs |
| Zetten (Slasher) | 13 (6 if nobody moves) | 16s | Counter stance: reacts to skills within 20 studs and melee hits |
| Grand Divider | 10 + 9 wave | 13s | Guard-breaks. The wave skips whoever the slash hit. |
| Black Moon | 21 (1 + 2 + 18) | 25s | Unblockable cutscene grab. Asta can't be hit while it plays. |

#### Animations

All of Asta's animations are generated from `tools/anim/asta_anims.py` and checked against an R6 model of the rig:

- The blade never passes through his body or the floor.
- On grounded animations the body is lowered or raised so his soles rest on the floor. That's what lets lunges sink into their stance and runs bob.

Run `python3 tools/anim/asta_anims.py`, then `python3 tools/anim/emit.py src/client/Kits/AntiMagic/Animations.luau`.

Grabs pin the victim to the grabber's actual hand on every screen, so the hold looks solid at any ping. The victim plays a struggling "held by the throat" animation.

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
