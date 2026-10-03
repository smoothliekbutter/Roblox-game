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
| Left click (hold to chain) | M1 combo: jab, cross, hook, then a front kick that ragdolls and guard-breaks |
| Hold **Space** on the 4th hit | Rising uppercut that launches both of you into the air |
| 4th hit while in the air | Double-fist hammer downslam with a crater |
| **Q** + WASD | Dash: front, back, left or right. Front dash steers with the camera. |
| Hold **F** | Block. Only works facing the attacker. |
| Tap **F** right before a hit | Perfect block: stuns the attacker |
| **Q** while stunned or ragdolled | Evasive breakout (needs a full cyan bar) |

Gamepad: R2 attack, B dash, L2 block. On mobile, on-screen buttons appear automatically.

Turn on **Shift Lock** (Settings → Shift Lock Switch, then press Shift) for the battlegrounds feel.

## Test dummies

Three dummies spawn in front of you:

- **Dummy** (white) stands still and heals after 3 seconds.
- **Blocking Dummy** (blue) always blocks and faces you. Use it to practice guard breaks.
- **Attacking Dummy** (red) throws full M1 strings at you. Use it to practice blocks, perfect blocks and Evasive.

## Project layout

```
src/
  shared/   ReplicatedStorage.Shared: Config, CombatState, Remotes, Impulse
  server/   ServerScriptService.Server: CombatService, Hitbox, Ragdoll, Dummies, CharacterLoader
  client/   StarterPlayerScripts.Client: Input, Moves, PoseAnimator, M1Animations, VFX, CameraShake, HUD
```

- **Balancing:** every number lives in `src/shared/Config.luau`. Set `Config.Debug.ShowHitboxes = true` to see hitboxes.
- **Server-authoritative:** the server decides every hit, block and cooldown. Clients only send inputs and draw effects.
- **Animations are code:** `src/client/M1Animations.luau` holds keyframed R6 poses, played by `PoseAnimator` by overriding Motor6Ds. Nothing needs uploading and there are no animation-permission problems. Uploaded animation IDs can replace them later.
- **VFX are client-side:** the server sends `("EffectName", data)` and `src/client/VFX.luau` draws it. Effects use only textures built into Roblox, so nothing needs uploading.
