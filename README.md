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
| Left click (hold to chain) | M1 combo, 4 hits, a little over a third of a second apart. The 4th hit ragdolls (it doesn't break a guard). |
| Hold **Space** on the 4th hit | Uppercut finisher: a launcher. They go limp and tumble about 10 studs up on heavier gravity, so it snaps up and straight back down, and can still be hit on the way: let go of Space, jump after them and keep swinging (the 4th air hit is the downslam). Holding Space for the uppercut never makes you jump. Short recovery after it. |
| 4th hit while in the air | Downslam finisher with a crater: 3 hits, jump, hit. The 3rd hit stuns long enough for it, the jump is free almost right away, and the swing reaches the ground below you |
| **1 2 3 4** | Character skills. Most have an air version: use them mid-jump. |
| **R** | Character special (each character has their own). Its cooldown is the small gold bar under your health, beside the cyan Evasive bar: bright when it's ready |
| **G** | Awaken when the red meter is full. It fills as you fight: about 90 damage dealt. |
| **Q** + WASD | Dash. Front and back dashes share a 2s cooldown. Side dashes (A / D) are a smaller, quicker hop, about 10 studs to the front dash's 19, on their own 1.5s cooldown, so you can side-dash right after a front dash. A front dash goes into an M1: if it reaches someone it stops and swings at them, and clicking mid-dash cuts it short into the swing |
| Hold **F** | Block. Only works facing the attacker. |
| Tap **F** right before a hit | Perfect block: stuns the attacker |
| **Q** while stunned or ragdolled | Evasive breakout (needs a full cyan bar) |
| **LeftShift** | Toggle shift lock (or the SHIFT LOCK button in the top bar) |

The **CHARACTERS** button in the top bar, next to chat, opens the character picker. Switching is blocked for 5 seconds after combat. When you die you respawn as the same character, with your awakening bar where it was. If you died while awakened, the bar keeps what was left of the form, but you come back unawakened. Picking a different character while dead starts the bar from empty.

**Play testing:** the **INFINITE AWAKENING** button in the top bar keeps your awakening bar full. Awakened forms never run out, and the second stage (Yuno's Full-Crown) is always ready, so you can press G again straight away. Anyone in the server can press it. Turn it off before release by setting `Config.PlayTest.InfiniteAwakening = false` in `src/shared/Config.luau`, which hides the button and disables it on the server.

## Characters

### Anti-Magic Knight (Asta)

A close-range rushdown character built like Vessel (Jujutsu Shenanigans) and Hero Hunter (The Strongest Battlegrounds). He swings the Demon-Slayer Sword as it looks in the series: a huge, broad black greatsword about as tall as he is, battered and stained, with a pointed tip, worn edges, a thin bronze crossbar and a long two-handed grip with a round pommel. (Only the look is big: hitboxes are the same as before.)

| Key | Base | Black Form (after G) |
|---|---|---|
| 1 | **Bull Thrust**: rockets forward on anti-magic. **Steer it mid-move** with WASD or the camera to curve around and chase people. Catches the target in a five-hit sword combo: a rising cut, a backhand, a spinning backhand, an overhead chop, then a beat coiled with the sword drawn back before a thrust that drives them back still stunned, so you can M1 straight into them. **Air:** a diving thrust (also steerable), only during **Anti-Magic Leap (R)** or from well above the ground; a plain jump does the normal version. The dive **breaks guards** and carries straight on into the combo. If the dive catches no one, he drives the sword into the ground where he lands and blows out a crater that reaches about 11 studs around him (black dome, red shockwave, cracks, flying rocks, a black pillar, black lightning) that breaks guards and throws everyone in it far up and away. If the slam hits nobody either, the sword sticks in the ground for a moment (about 1.1s of end lag). | **Sword move 1**: depends on the sword in his hand (see *Black Form swords* below). With the Demon-Slayer Sword it's **Black Hurricane**. |
| 2 | **Black Meteorite** (grab): a standing grab, no dash. He plants and his free hand shoots out for their throat, anti-magic winding round it and black lightning crawling down his arm. It seizes whoever is within about 6 studs in front of him, unblockable. He hoists them up as anti-magic surges through them, then a vortex of anti-magic swallows them both: he whirls round three times holding them out at arm's length, leaning back and banking into the spin, bobbing up and down as it carries them into the sky. At the top he flips over head-down and dives, spinning like a drill (several full turns, faster as he falls, like TSB's "Head First"), drives them head-first into the ground in a huge crater (shockwave dome, ground cracks, flying debris, black lightning) that also hits everyone else within about 9 studs of them, and rolls back over onto his feet. **Air:** hangs in the air, grabs whoever is in front of him, spins them in a shorter vortex and dives head-first, spinning, into the ground. | **Sword move 2**: depends on the sword in his hand. With the Demon-Slayer Sword it's **Slayer Recall**. |
| 3 | **Black Divider**: anti-magic streams into the blade, then a huge sweeping crescent cleave. Press **3** again on the red glint for a Perfect Divider: bigger cut, impact frame, and a black crescent that keeps flying. **Air:** hangs in the air while charging, then front-flips the blade down onto whoever's below and spikes them into the ground. It reaches all the way down and also hits people lying on the floor. The ground version can't hit downed players, but hits harder. | **Grand Divider**: he raises the sword to the sky and a giant blade of anti-magic grows out of it as pillars and lightning build. Then he brings it down in one guard-breaking cleave that splits the ground open in a fissure, and a giant wave rolls on. **Air:** a full front flip of the giant blade that cleaves down onto whoever's below, splitting the ground beneath. |
| 4 | **Anti-Magic Deflect**: raises an anti-magic barrier on the blade that counters every attack type. Melee attackers get a frozen impact frame, then a diagonal slash that throws them aside. Projectiles get sent back. **Air:** hangs in the air with the guard up. | **Black Moon** (a roughly 6-second cutscene grab): a standing grab like Black Meteorite (no dash, his hand shoots out for whoever is right in front of him), seizes them by the throat and hurls them into the sky. Night falls, and he hovers in the sky in front of a giant moon, shadowed with a red rim (you can still see your avatar), both wings spread wide. Stars come out, clouds drift across the moon, mist creeps over the ground and rocks float up. He levels his sword at them, the blade catches the moonlight, then he flies straight through them in one backhand cut and stops past them, sword out at his side, everything freezes, and the cut lands: an X slash, the moon splits in half and they're cut down into a crater. The two players get a cinematic camera with letterbox bars; everyone nearby sees night fall. |
| R | **Anti-Magic Leap**: blasts off the ground in a big steerable leap. Press **R** again in the air (or use it while already airborne) for **Meteor Plunge**: hangs for a beat, then dives behind the sword and stabs it into the ground, blasting everyone nearby away. | **Swap Sword**: the grimoire opens and he draws one of his other three swords at random (10s cooldown). The old sword dissolves into black smoke, the new one forms in his hand out of anti-magic and its name flashes up. Moves 1 and 2 change with it. Black Form always starts, and ends, with the Demon-Slayer Sword. |
| G | **Black Form**: a 2-second transformation. Anti-magic gathers as the world darkens, then explodes into a black pillar that blows everyone away, and he drops into his stance. For 55s you get +25% damage, more speed and new moves, plus the look: black flames, a horn, a black arm and sword, and a devil wing with its own idle (it breathes, stretches, tucks back when you run and beats in the air). His grimoire comes out and circles him, open, its pages fluttering, for as long as Black Form lasts. | |

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
| M1 string | 4 / 4 / 4 / 6 | | 4th hit ragdolls; blocking stops it |
| Bull Thrust | 11.5 (2 + 1.5 + 1.5 + 1.5 + 2 + 3), air landing slam 6 AoE | 10s | Blockable on the ground; the air dive (after R, or from more than about 6 studs up) breaks guards. Combo starter. Long recovery if it whiffs (0.9s for the dive, 1.1s if the landing slam hits nobody). The air landing slam guard-breaks and ragdolls everyone within about 11 studs, with big knockback. |
| Black Meteorite | 12 (1 + 2 + 4.5 in the vortex + 4.5 slam), air 10 (2.5 slam); the slam also hits everyone within 9 studs of them (blockable) | 13s | Unblockable standing grab, no dash: about 0.16s startup, reaches about 6 studs. Counters and i-frames beat it. Long recovery if it whiffs. |
| Black Divider | 11, perfect 17 (air 7 / 12) | 11s | Normal guard-breaks, perfect is unblockable. The air version reaches the ground below and also hits people lying on the floor; the ground version can't, but hits harder |
| Anti-Magic Deflect | 7 counter, 6 reflected | 14s | 0.65s window. Long recovery if nothing hits it. |
| Anti-Magic Leap (R) | 5 AoE plunge | 10s | Blockable |
| Black Form (G) | ×1.25 damage | ×0.8 cooldowns | +6 speed for 55s. About 90 damage dealt to charge. |
| Swap Sword (R in Black Form) | | 10s | Random other sword; per-slot cooldowns carry over |
| Black Hurricane (Slayer) | up to 9 + 5 | 9s | |
| Slayer Recall (Slayer) | 8 out, 6 back | 12s | The return drags them to him |
| Black Slash (Dweller) | 9 | 7s | Piercing projectile |
| Conquering Eon (Dweller) | 2 siphon, then 8 + 2 per charge | 15s | Absorbs spells; up to 4 charges; guard-breaks at 3 or more |
| Causality Break (Destroyer) | 10 | 15s | Unblockable; 4 closest within 18 studs; clears their counters and guard |
| Severance (Destroyer) | 11 | 12s | Seals all their moves for 3s |
| Infinite Slash (Slasher) | 11 | 13s | Unblockable line, up to 60 studs |
| Zetten (Slasher) | 15 (7 if nobody moves) | 16s | Counter stance: reacts to skills within 20 studs and melee hits |
| Grand Divider | 10 + 9 wave | 13s | Guard-breaks. The wave skips whoever the slash hit. |
| Black Moon | 29 (1 + 3 + 25) | 25s | Unblockable cutscene grab. Asta can't be hit while it plays. |

#### Animations

All of Asta's animations are generated from `tools/anim/asta_anims.py` and checked against an R6 model of the rig:

- The blade never passes through his body or the floor.
- On grounded animations the body is lowered or raised so his soles rest on the floor. That's what lets lunges sink into their stance and runs bob.
- The run and walk are smooth loops sampled from curves (no stalling at keyframes). Their speed follows the ground covered: a foot passing under him sweeps back as fast as he moves, about 11 studs a loop for the sprint (the same pace as Roblox's own R6 run), so the legs never scurry. The sprint leans in with a runner's bob: the foot is flat on the floor as each leg passes under him, and he lifts off between steps. His shoulders turn with the pumping free arm while his hips stay square, and his head stays level. The walk stays planted and rides over each step.

Run `python3 tools/anim/asta_anims.py`, then `python3 tools/anim/emit.py src/client/Kits/AntiMagic/Animations.luau`. Yuno's are in `tools/anim/yuno_anims.py`: run it to check them, then `python3 tools/anim/yuno_anims.py src/client/Kits/Wind/Animations.luau` to write them.

Grabs pin the victim to the grabber's actual hand on every screen, so the hold looks solid at any ping. The victim plays a struggling "held by the throat" animation.

### Prince of Wind (Yuno)

Wind, spirit and star magic, built as Asta's opposite: a mid-range zoner who pins people down and pushes them around from where a sword can't reach. Star magic lets him be somewhere else in an instant. Each move does less damage than Asta's, but from range and with more control. His spells are Bolt, Swarm and Zone attacks, so Asta's Deflect sends them back and Conquering Eon drinks them in. Wind is pale green with a white core, star magic gold-white.

| Key | Base: Prince of Wind | Half-Crown Spirit of Zephyr (G) | Full-Crown Spirit of Zephyr (G again) |
|---|---|---|---|
| 1 | **Wind Blades Shower**: wind blades fill the sky over whoever he faces (or a way ahead; a circle on the ground shows where) and rain down in six waves. The waves pin people in place and the last one pops them up. The blades keep falling even if he's hit. | **Spirit Storm**: Sylph's mana gathers in his palm as an orb of storm (rings of wind whirling round it, wind streaming in, a ring drawn in along the ground). Then a dense beam of swirling wind tears out: a white-hot core in a green column inside a shimmering sheath, three helices of wind twisting and spinning round it, rings tearing off along it and streaks racing down it. It drags people along it, scars the ground it passes over and bursts where it ends; the last of it blows them away. | **Spirit of Notos**: the south wind bursts out of him and throws everyone near away. For a moment after, spells thrown at him are blown back at whoever threw them. |
| 2 | **Swift White Hawk**: a hawk of wind, wings beating, curves after whoever he faced and blows them away when it strikes. **Air:** it holds them up there instead and pulls him in after them, for an air string. | **Tempest Dive** (a grab and a 3-second cutscene): his hand shoots out, and he flies straight up dragging whoever it catches by the collar, about 34 studs into the sky. After a beat at the top he swings over them and drives them head-first, spinning, back down. As he turns them over, a full tornado rises out of the ground under them: a hollow funnel of dense, whirling wind you can barely see through, dust pouring off it and debris spinning round inside. He drives them down through its eye, and the tornado cuts them three times; the camera goes inside the tornado for the way down. They hit hard enough to bounce, and the tornado stands over the crater a moment before blowing apart. **Landing it twice is what unlocks the Full-Crown.** | **Spirit of Zephyrus**: the west wind. He leaps into the sky on a burst of wind and hangs there, arms flung wide over a turning ring of wind. 14 wind arrows form one by one, floating in a ring around him and pointed at the ground, then rain down one after another on whoever is nearest. The first arrows land around them and close in, keeping them pinned; the last knocks them down. Then he glides back down. |
| 3 | **Heavenly Wind Ark** (block breaker): a great crescent of wind rises out of the ground ahead and carries them about 14 studs up on a spiral of wind, with him right behind them. Both hang there for an air string: air M1s keep you both up, and the 4th slams them down. **Air:** the ark sweeps down beneath him and spikes them into the ground. | **Quartile Scutum**: four stars in a rectangle in front of him, with beams of light between them and a pane of starlight. For 2.5s it stops every hit from the front, even guard breaks (grabs still get through), and **sends it back for double damage**: straight back into close attackers, and as a bolt of starlight at ranged ones. A reflected hit is never reflected again. Hits from behind still land. He can walk slowly but not attack. | **Spirit of Euros**: a recurve bow of wind, drawn (and rooted) while the wind spirals into the arrow. Loosed, it's too fast to see: everyone along the line is hit at once, unblockable. |
| 4 | **Gale White Bow**: turned side-on like an archer with a great wind bow, he fires six big arrows, each aimed at whoever he faces. Five keep them stunned, the sixth knocks them back. Against someone in the air, the arrows pin them there and the sixth spikes them down. **Held (on the ground):** he keeps drawing. The arrow on the string becomes one great arrow, the bow grows and wind spirals into its head. Let go (or after 0.6s) and it flies through everyone in its path, hitting harder the longer he drew. | **Quartile Hasta**: a sigil of starlight opens in front of his hand: a gold ring and a counter-turning outer ring, with four stars at the corners of a square of light (the quartile) and a cross between them, starlight drawn in. What happens next depends on the key. **Tapped:** a mini barrage. The stars loose five star bolts one after another at whoever he faces: comets of starlight with a star for a head and a tail burning gold to orange, each bursting into a star where it strikes. **Held:** the stars pour their light into one great lance, which he keeps on them for as long as the key is down (up to 1.6s, turning with him). It has a white-hot core, a gold glow, a shimmering sheath and four strands of starlight twisting round it, with rings bursting off along it and a star flaring where it strikes. When he lets go it ends in a guard-breaking blast. **In the air:** the sigil opens face-down under his feet, a turning circle of gold opens on the ground below, and star-fire rains into it: burning bolts that burst into flames where they land. | **Neverland** (cutscene grab): his hand shoots out, and whoever it catches is caught in stopped time inside a dome of pale light, the world drained of colour. Three stars stand round them, joined by beams, and the triangle rises with them. He flashes from star to star, punching them up through it six times, then appears above them and hammers them down through a great triangle of stars into the ground. Afterwards the dome lingers over the crater for 4s: enemies inside are slowed and weakened, and he hits harder. |
| R | **Conjunction**: a star goes down 22 studs the way he's moving (to the side or back for a dodge), or straight ahead when he's still. Press **R** again within 4s to be there in a flash of starlight. | (same) | (same) |
| G | **Half-Crown**: Sylph circles in and merges into his left side. Green mana coats his left side (arm, leg and that half of his body) in a shimmer of wind. A wing grows from his left shoulder blade: long glowing feathers in two layers, shimmering, beating slowly, with wisps streaming off the tips. Half a crown of gold leaf-spikes forms over his left temple, with a green gem. His grimoire comes out and circles him, open, pages fluttering, a four-leaf clover of light over it. 45s. | **Full-Crown**: once Tempest Dive has landed twice in the Half-Crown (the awakening bar shows 0/2, 1/2, then [G]), press **G** again. Both sides transform, he gets both wings, the full crown and a two-handed sword of wind, and the timer restarts at 30s. | |

**Air combos:** Yuno rides the wind, so he gets a small double jump (about 4 studs) to chase people. On spawn, his grimoire comes down out of the sky to him and circles him as it opens, Sylph darts around him, and the wind bursts out as he reaches for it. Most moves have an air version: he hangs while casting and aims down at an angle. Several set up air strings: the Ark (carries you both up), the Hawk from the air (holds them and pulls him in), Wind Blades on someone in the air (holds them, then throws them higher), the Bow on someone in the air (pins them, then spikes them) and Tempest Dive (carries you both up). His dashes are green. His M1s are wind-wrapped strikes: the shared punch-and-kick string with a little more reach and gusts off every hit.

**Wind arrows:** every arrow he shoots (Gale White Bow, Spirit of Zephyrus and Spirit of Euros) is the same wind arrow. It has a white-hot shaft in a shimmer of wind, a four-bladed head of light (two blades white, two gold), three green fins and a glow at the head. It spins in flight with a ribbon of wind streaming off the tail and bursts into a ring of wind where it strikes. The bow keeps the next arrow nocked between shots. Zephyrus's floating arrows are the real arrows that fly, with the last one bigger. Euros draws a great one with a glow swelling at its head. The Wind Blades Shower's blades are pointed now, and streak wind as they fall.

#### Yuno numbers

| Move | Damage | Cooldown | Notes |
|---|---|---|---|
| M1 string | 3.5 / 3.5 / 3.5 / 5 | | Fists, a little more reach than default |
| Wind Blades Shower | 9.5 (5 × 1.4 + 2.5) | 11s | Swarm. Soft-locks on whoever he faces within 40 studs. 0.6s wind-up (hand raised, wind streaming into it) before the first wave |
| Swift White Hawk | 8 | 8s | Bolt. Homing (140° a second), 75 studs |
| Heavenly Wind Ark | 7, air 8 | 12s | Zone. Breaks guards (ground and air) and hits people who are down. Carries both up and holds you there 0.9s for an air string; the air version spikes |
| Gale White Bow | 13 (5 × 2 + 3); held: one great arrow, 9 to 12 by how long he draws | 15s | Bolt. Each arrow aims at whoever he faces. 0.5s draw before the first arrow. The great arrow (held on the ground, 0.2 to 0.6s more draw) goes through everyone in its path and knocks them back |
| Conjunction (R) | | 10s | Teleport to the star: dodge or gap close |
| Half-Crown (G) | ×1.15 damage | ×0.85 cooldowns | +4 speed for 45s. Weaker than Black Form (×1.25, 55s), but it leads to the Full-Crown |
| Spirit Storm | 11 (5 × 1.6 + 3) | 12s | Bolt beam, 50 studs |
| Tempest Dive | 18 (2 + 3 × 1.4 + 12) | 16s | Unblockable grab; each landing is 1 of the 2 the Full-Crown needs |
| Quartile Scutum | double whatever it stops | 16s | Front-only wall for 2.5s; everything it stops goes back at double damage |
| Quartile Hasta | tap 11 (4 × 2 + 3); held 8 to 18 (1.1 a tick + 4); air up to 21.6 (12 × 1.8) | 14s | Tap: 5 star bolts. Held past 0.25s: a 60-stud beam for as long as the key is down (0.4 to 1.6s), ending in a guard-breaking blast. Air: star-fire rains on an 11-stud circle below him |
| Full-Crown (G again) | ×1.3 damage | ×0.75 cooldowns | +8 speed for 30s. Needs Tempest Dive landed twice in the Half-Crown |
| Spirit of Notos | 6 burst, 7 reflected | 12s | Reflects spells for 0.8s |
| Spirit of Zephyrus | up to 22 (13 × 1.4 + 4) | 13s | Arrows close in on the nearest enemy; the last knocks down |
| Spirit of Euros | 16 | 18s | Unblockable instant line, 120 studs, 0.8s draw |
| Neverland | 28 (2 + 6 × 2 + 14) | 30s | Unblockable cutscene grab, untouchable while it plays. Then a 20-stud dome for 4s: they're slowed to 60% and deal 75%, he deals 115% |

How he compares with Asta:

- **Damage:** Yuno's base moves average about 9.5 damage on about 11.5s cooldowns, against Asta's 12 on 12s. He makes up for it with range, soft-lock aim and a 10s teleport.
- **Ultimates:** the Half-Crown is weaker than Black Form, but reaching the Full-Crown takes Yuno past it for 30 seconds.
- **Matchup:** Asta's Deflect and Conquering Eon punish careless spell spam, and Yuno's Scutum and his range answer Asta's rushdown.

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
