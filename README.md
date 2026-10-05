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
| **Q** + WASD | Dash. Front and back dashes share a 2s cooldown. Side dashes (A / D) are a smaller, quicker hop, about 10 studs to the front dash's 19, on their own 1.5s cooldown, so you can side-dash right after a front dash. Every front dash ends in an M1. If it reaches someone it stops and swings at them, clicking mid-dash cuts it short into the swing, and otherwise it swings at the end. Side and back dashes don't swing |
| Hold **F** | Block. Only works facing the attacker. |
| Tap **F** right before a hit | Perfect block: stuns the attacker. 10s cooldown after one lands, shown by the small diamond icon under the R bar (bright when ready, the seconds left while not). Blocks in between are plain blocks |
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
| R | **Anti-Magic Leap**: blasts off the ground in a big steerable leap. Press **R** again in the air (or use it while already airborne) for **Meteor Plunge**: hangs for a beat, then dives behind the sword and stabs it into the ground, blasting everyone nearby away. | **Swap Sword**: the grimoire opens and he draws his next sword, in order: Demon-Slayer, then Demon-Destroyer, then Demon-Slasher Katana, then round again. No cooldown, so tap R to scroll through them. The old sword dissolves into black smoke, the new one forms in his hand out of anti-magic and its name flashes up. Moves 1 and 2 change with it. Black Form always starts, and ends, with the Demon-Slayer Sword. |
| G | **Black Form**: a 2-second transformation. Anti-magic gathers as the world darkens, then explodes into a black pillar that blows everyone away, and he drops into his stance. For 55s you get +25% damage, more speed and new moves, plus the look: black flames, a horn, a black arm and sword, and a devil wing with its own idle (it breathes, stretches, tucks back when you run and beats in the air). His grimoire comes out and circles him, open, its pages fluttering, for as long as Black Form lasts. | |

#### Black Form swords (R)

In Black Form, **R** scrolls through Asta's three swords in order (no cooldown), and moves 1 and 2 belong to the sword in his hand. Each sword has its own model, built after its look in the series, and its moves after what it does there.

| Sword | Move 1 | Move 2 |
| --- | --- | --- |
| **Demon-Slayer Sword**: his first, huge greatsword | **Black Hurricane**: four full spins with the blade out, wrapped in a black tornado, dragging enemies along and finishing with an outward blast. **Air:** drills down out of the sky and spikes them into the ground. | **Slayer Recall**: hurls the sword like a boomerang. It spins out about 34 studs, cutting whoever it passes, and hangs there. Press **2** again (or wait 1.2s) and it flies back to his hand through whoever's in the way, dragging them to him, with black lightning pulling it in. No M1s until he catches it. Starting another move snaps it straight back. |
| **Demon-Destroyer Sword**: a curved blade with a clover on the guard | **Causality Break**: drives the Destroyer point-first into the ground. Curse-breaking anti-magic runs through the earth to the 4 closest enemies within 18 studs. It cuts them (unblockable) and breaks whatever they had up: counters, guard and Zetten-style stances. | **Black Comet** (short grab cutscene, about 1.4s): his free hand seizes whoever is in front of him (unblockable). Both wings beat him forward low over the ground, dragging them along on their back at his side (they hang from his hand with real weight, so they swing and scrape). Three times he lifts them and hammers them flat into the ground, harder each time: a glowing trench, dirt and sparks behind them, a bigger crater with every slam. He lands skidding, hauls them round and heaves them away as a black comet. Walls cut the flight short. |
| **Demon-Slasher Katana**: Yami's katana, turned anti-magic | **Black Ascent**: a rising cut that launches whoever is in front of him (blockable). He springs up after them, glides across in front of them cutting right to left, sweeps back up the other way, comes over the top and cuts them straight down into a crater, landing beside it. The two air cuts hang in the air as an X that bursts on the last cut. A short air combo with its own camera, every move eased (no jumps between sides). | **Zetten**: a still iai stance, reading ki for 1s. The first enemy within 20 studs to start a move (or swing at him) gets cut down before it lands: he flashes past them with a guard-breaking cut. If nobody moves, it ends in one quick cut ahead. |

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
| Swap Sword (R in Black Form) | | none | Next sword in order (Slayer, Destroyer, Slasher); per-slot cooldowns carry over |
| Black Hurricane (Slayer) | up to 9 + 5 | 9s | |
| Slayer Recall (Slayer) | 8 out, 6 back | 12s | The return drags them to him |
| Causality Break (Destroyer) | 10 | 15s | Unblockable; 4 closest within 18 studs; clears their counters and guard |
| Black Comet (Destroyer) | 12 (1 + 3 × 2 + 5) | 14s | Unblockable grab cutscene, untouchable while it plays; about 1.4s |
| Black Ascent (Slasher) | 10 (2 + 2 + 2 + 4) | 12s | Blockable launcher; once it lands, the air combo can't be escaped |
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

Wind, spirit and star magic, built as Asta's opposite: a mid-range zoner who pins people down and pushes them around from where a sword can't reach. Star magic lets him be somewhere else in an instant. Each move does less damage than Asta's, but from range and with more control. His spells are Bolt, Swarm and Zone attacks, so Asta's Deflect sends them back. Wind is pale green with a white core, star magic gold-white.

| Key | Base: Prince of Wind | Half-Crown Spirit of Zephyr (G) | Full-Crown Spirit of Zephyr (G again) |
|---|---|---|---|
| 1 | **Wind Blades Shower**: wind blades fill the sky over whoever he faces (or a way ahead; a circle on the ground shows where) and rain down in six waves. The waves pin people in place and the last one pops them up. The blades keep falling even if he's hit. | **Spirit Storm**: Sylph's mana gathers in his palm as an orb of storm (rings of wind whirling round it, wind streaming in, a ring drawn in along the ground). Then a dense beam of swirling wind tears out: a white-hot core in a green column inside a shimmering sheath, three helices of wind twisting and spinning round it, rings tearing off along it and streaks racing down it. It drags people along it, scars the ground it passes over and bursts where it ends; the last of it blows them away. | **Spirit of Boreas**: the north wind. A great axe of wind forms in his raised hands: a haft of light and a crescent head, a white-hot edge round a see-through blade of wind with wind pouring off it. He brings it down in one huge chop and the ground splits in a line about 28 studs ahead. The earth bursts up along it in a wave, a seam of wind runs down it, and cracks and rocks fly. It breaks guards and throws everyone on the line into the air. **Air:** it chops down at the ground ahead and below and spikes them. |
| 2 | **Swift White Hawk**: a hawk of wind, wings beating, curves after whoever he faced and blows them away when it strikes. **Air:** it holds them up there instead and pulls him in after them, for an air string. | **Tempest Dive** (a grab and a 3-second cutscene): his hand shoots out, and he flies straight up dragging whoever it catches by the collar, about 34 studs into the sky. After a beat at the top he swings over them and drives them head-first, spinning, back down. As he turns them over, a full tornado rises out of the ground under them: a hollow funnel of dense, whirling wind you can barely see through, dust pouring off it and debris spinning round inside. He drives them down through its eye, and the tornado cuts them three times; the camera goes inside the tornado for the way down. They hit hard enough to bounce, and the tornado stands over the crater a moment before blowing apart. **Landing it twice is what unlocks the Full-Crown.** | **Spirit of Zephyrus**: the west wind. His sword of wind grows long, a blade of wind far out past its point, and he lunges at whoever he's facing on a burst of wind (steerable), afterimages behind him. Caught, they're held in front of him and cut three times in a blur, each a crescent of wind through them, then run through with a thrust that sends a seam of wind straight through them and blows them away. **Air:** the lunge dives at them. |
| 3 | **Heavenly Wind Ark** (block breaker): a great crescent of wind rises out of the ground ahead and carries them about 14 studs up on a spiral of wind, with him right behind them. Both hang there for an air string: air M1s keep you both up, and the 4th slams them down. **Air:** the ark sweeps down beneath him and spikes them into the ground. | **Quartile Scutum**: four stars in a rectangle in front of him, with beams of light between them and a pane of starlight. For 2.5s it stops every hit from the front, even guard breaks (grabs still get through), and **sends it back for double damage**: straight back into close attackers, and as a bolt of starlight at ranged ones. A reflected hit is never reflected again. Hits from behind still land. He can walk slowly but not attack. | **Spirit of Euros**: a recurve bow of wind and a **giant** wind arrow (over 3 times the size of his other arrows, its head far out past the bow), drawn (and rooted) while the wind spirals into it and a glow swells at its head. Loosed, it's too fast to see: everyone along the line is hit at once, unblockable. |
| 4 | **Gale White Bow**: turned side-on like an archer with a great wind bow, he fires six big arrows, each aimed at whoever he faces. Five keep them stunned, the sixth knocks them back. Against someone in the air, the arrows pin them there and the sixth spikes them down. **Held (on the ground):** he keeps drawing. The arrow on the string becomes one great arrow, the bow grows and wind spirals into its head. Let go (or after 0.6s) and it flies through everyone in its path. It **breaks guards** and leaves them **slowed** for a moment, but it's light on damage. | **Quartile Hasta**: a sigil of starlight opens in front of his hand: a gold ring and a counter-turning outer ring, with four stars at the corners of a square of light (the quartile) and a cross between them, starlight drawn in. What happens next depends on the key. **Tapped:** a mini barrage. The stars loose five star bolts one after another at whoever he faces: comets of starlight with a star for a head and a tail burning gold to orange, each bursting into a star where it strikes. **Held:** the stars pour their light into one great lance, which he keeps on them for as long as the key is down (up to 1.6s, turning with him). It has a white-hot core, a gold glow, a shimmering sheath and four strands of starlight twisting round it, with rings bursting off along it and a star flaring where it strikes. When he lets go it ends in a guard-breaking blast. **In the air:** the sigil opens face-down under his feet, a turning circle of gold opens on the ground below, and star-fire rains into it: burning bolts that burst into flames where they land. | **Saint Spirit of Zephyr** (about a 6-second cutscene, from the manga: the blow that cut Zenon in half): he flicks a star at whoever is in front of him (about 15 studs) on a thread of starlight. It binds them in a seal of starlight (rings of light and wind turning round them, little stars riding the rings). A magic circle opens on the ground under them, rings of starlight and wind round an eight-pointed star, and a column of wind tears up out of it. Wind streams up round a bright core with ribbons of wind spiralling up it, and it carries them 32 studs into the sky while he flies up beside them. Eight stars open round them, joined in one line by streams of sparkles (an eight-pointed star), over turning rings of starlight, wind and glitter, and light pours from every star into them. He waits at his own star, sword drawn back, then charges straight through them. After that he never stops, and every move is one smooth curve: out round a star, back through them, out round the next, eight cuts that come faster and faster. Each pass is a cut you see him make: the swing, a stroke of light through them, his sword sweeping a sheet of wind, and a crescent of wind left hanging in the air. Round each star he leaves a ghost of himself, and the long ribbon of wind he trails paints a flower of eight petals round them. He finishes with a rising X. He sweeps up and over to the top, turning back to face them. Wings of wind open, Sylph circles him and dives into his raised hands, and a 40-stud blade of wind grows out of them: a white-hot core in a glittering edge inside layers of wind, with ribbons of wind spiralling up it. The light of every star in the constellation pours into its point, and a shaft of wind and starlight opens into the sky over him. Then he dives straight down through them in one strike, and time slows right down as the blade goes through them before it picks up again. The swing leaves a crescent of wind the height of the sky and a seam of light from the heavens to the ground, with a black-and-white impact frame, and he lands on his side of them with his back to them. Every hanging cut bursts one after another, the stars burst and the rings blow apart. They fall like a meteor, trailing a comet's tail of wind, smoke and glitter, into a crater. A tornado of wind tears up out of it, starlight sifts down and feathers drift round him. All of it is see-through wind and light (beams, trails and particles), and both fighters are outlined through it, so you can always see them. **No snaps:** his flight is one continuous curve (speed never jumps, he always turns smoothly and leans into the flight), it starts right where his hovering body is (no dip as the cutscene takes over, in Tempest Dive too), the victim's jolts never teleport them, and the camera only eases. A light rides with him as he flies, so the stars and the wind light up as he passes. Dust lifts off the ground far below, and the camera breathes with each blow: a gentle zoom in and out, never a shake. The camera pushes in over his shoulder, cranes up the column with them, then watches from behind him at his star as he charges away through them. It circles them wide through the dance, takes the X side-on, looks up at him and the blade from below them, goes wide for the strike, falls with them, and comes round to his face with the tornado behind him. It always eases in and out of each move, with depth of field on him and a soft bloom. While it plays, the light shifts ever so slightly (a touch brighter, greener and richer, never darker). |
| R | **Conjunction**: a star goes down 22 studs the way he's moving (to the side or back for a dodge), or straight ahead when he's still. Press **R** again within 4s to be there in a flash of starlight. | (same) | (same) |
| G | **Half-Crown**: Sylph circles in and merges into his left side. Green mana coats his left side (arm, leg and that half of his body) in a shimmer of wind. A wing grows from his left shoulder blade: long glowing feathers in two layers, shimmering, beating slowly, with wisps streaming off the tips. Half a crown of gold leaf-spikes forms over his left temple, with a green gem. His grimoire comes out and circles him, open, pages fluttering, a four-leaf clover of light over it. 45s. | **Full-Crown**: once Tempest Dive has landed twice in the Half-Crown (the awakening bar shows 0/2, 1/2, then [G]), press **G** again. Both sides transform, he gets both wings, the full crown and a two-handed sword of wind, and the timer restarts at 30s. | |

**Air combos:** Yuno rides the wind, so he gets a small double jump (about 4 studs) to chase people. On spawn, his grimoire comes down out of the sky to him and circles him as it opens, Sylph darts around him, and the wind bursts out as he reaches for it. Most moves have an air version: he hangs while casting and aims down at an angle. Several set up air strings: the Ark (carries you both up), the Hawk from the air (holds them and pulls him in), Wind Blades on someone in the air (holds them, then throws them higher), the Bow on someone in the air (pins them, then spikes them) and Tempest Dive (carries you both up). His dashes are green. Awakened (Half-Crown or Full-Crown) he doesn't walk: he hovers about 1.8 studs off the ground on the wind (through every move, not only standing, so he never drops to the ground and pops back up), rising and settling slowly, legs loose and arms drifting out in the updraft. A ring of wind turns on the ground under him and a soft downdraft comes off his feet. When he moves he glides, leaning into it with his legs swept back and arms back like wings. His M1s are wind-wrapped strikes: the shared punch-and-kick string with a little more reach and gusts off every hit.

**Wind arrows:** every arrow he shoots (Gale White Bow and Spirit of Euros) is the same wind arrow. It has a white-hot shaft in a shimmer of wind, a four-bladed head of light (two blades white, two gold), three green fins and a glow at the head. It spins in flight with a bright ribbon off the tail inside a broad soft contrail of wind, and sheds glitter from its head. Where it strikes, rings of wind and light burst out with a glint of starlight. The bow keeps the next arrow nocked between shots, and its limbs glow with wind flowing along them and sparkles along the edge. Held, starlight and wind are drawn into the great arrow's head. Euros draws a giant one with ribbons of wind spiralling up it into the head. Loosed, it leaves a glittering line with wind streaming down it and the air ringing all along it.

**How his spells look:** everything is drawn from soft wind and starlight you can see through: glowing beams with wind flowing along them or a chain of sparkles running down them, rings of wind and light, trails, and particles of wind and glitter. Solid shapes are kept for the small hard things like star points and blade edges.
- **Base moves:** the Wind Blades Shower opens a vortex of wind in the sky over a circle of wind on the ground, with wind and glitter pouring down. Each blade streaks a soft trail and bursts into a puff and a ring of light where it lands.
- **Hawk and Ark:** the Hawk trails a long ribbon of wind, with wind off each wingtip, and bursts into feathers of wind. The Ark's crescent is a soft crescent of wind carried up on a column of wind.
- **Conjunction:** the star flies out on a thread of starlight and hangs in a ring of glitter. The warp leaves a stream of starlight along the way he went.
- **Half-Crown:** Spirit Storm's orb draws wind and glitter in from all round, with a ring of wind whirling round it and a circle of wind closing in on the ground. Its beam adds a broad stream of wind racing down it, a chain of glitter, a haze, ribbons of wind spiralling down it, rings of light along it and blasts of wind where it strikes. Tempest Dive carries them up on a whirl of ribbons, and its tornado gets a soft heart of wind streaming up its eye with ribbons whirling up its wall. Scutum's edges run with streams of starlight and its pane glitters. Hasta's sigil gets a glittering ring, a ring of wind and a glow, and its bolts shed glitter. The lance gets a chain of glitter, a warm haze and spiralling ribbons, and the star-fire circle gets a glittering rim and a warm haze.
- **Full-Crown:** the axe's edge glitters, its head glows, and the chop sweeps a sheet of wind, with blades of wind bursting up out of the split ground. Zephyrus's long sword glitters along its edge with a glow at its point, the lunge leaves a wake, and the thrust rings the air behind them. His crown sword has wind flowing up the blade.
- **Transformations:** a circle of wind closes in round him and ribbons whirl up him while wind and glitter are drawn in. Then a column of wind and starlight blasts up, rings race out and feathers of wind fly everywhere.

#### Yuno numbers

| Move | Damage | Cooldown | Notes |
|---|---|---|---|
| M1 string | 3.5 / 3.5 / 3.5 / 5 | | Fists, a little more reach than default |
| Wind Blades Shower | 9.5 (5 × 1.4 + 2.5) | 11s | Swarm. Soft-locks on whoever he faces within 40 studs. 0.6s wind-up (hand raised, wind streaming into it) before the first wave |
| Swift White Hawk | 8 | 8s | Bolt. Homing (140° a second), 75 studs |
| Heavenly Wind Ark | 7, air 8 | 12s | Zone. Breaks guards (ground and air) and hits people who are down. Carries both up and holds you there 0.9s for an air string; the air version spikes |
| Gale White Bow | 13 (5 × 2 + 3); held: one great arrow, 6 to 8 by how long he draws | 15s | Bolt. Each arrow aims at whoever he faces. 0.5s draw before the first arrow. The great arrow (held on the ground, 0.2 to 0.6s more draw) goes through everyone in its path, breaks guards, knocks them back and slows them (40%) for 2.5s from the hit |
| Conjunction (R) | | 10s | Teleport to the star: dodge or gap close |
| Half-Crown (G) | ×1.15 damage | ×0.85 cooldowns | +4 speed for 45s. Weaker than Black Form (×1.25, 55s), but it leads to the Full-Crown |
| Spirit Storm | 11 (5 × 1.6 + 3) | 12s | Bolt beam, 50 studs |
| Tempest Dive | 18 (2 + 3 × 1.4 + 12) | 16s | Unblockable grab; each landing is 1 of the 2 the Full-Crown needs |
| Quartile Scutum | double whatever it stops | 16s | Front-only wall for 2.5s; everything it stops goes back at double damage |
| Quartile Hasta | tap 11 (4 × 2 + 3); held 8 to 18 (1.1 a tick + 4); air up to 21.6 (12 × 1.8) | 14s | Tap: 5 star bolts. Held past 0.25s: a 60-stud beam for as long as the key is down (0.4 to 1.6s), ending in a guard-breaking blast. Air: star-fire rains on an 11-stud circle below him |
| Full-Crown (G again) | ×1.3 damage | ×0.75 cooldowns | +8 speed for 30s. Needs Tempest Dive landed twice in the Half-Crown |
| Spirit of Boreas | 10 | 12s | Guard-breaking line, about 28 studs ahead and 7 wide; launches (air: spikes) |
| Spirit of Zephyrus | 11.5 (3 + 3 × 1.5 + 4) | 13s | Blockable lunge (about 34 studs, steerable, soft-locks on whoever he faces); caught, the combo can't be escaped |
| Spirit of Euros | 16 | 18s | Unblockable instant line, 120 studs, 0.8s draw |
| Saint Spirit of Zephyr | 27.8 (2 + 8 × 1.35 + 2 + 3 + 10) | 30s | Unblockable cutscene, about 6.5s, untouchable while it plays. The star reaches about 15 studs |

How he compares with Asta:

- **Damage:** Yuno's base moves average about 9.5 damage on about 11.5s cooldowns, against Asta's 12 on 12s. He makes up for it with range, soft-lock aim and a 10s teleport.
- **Ultimates:** the Half-Crown is weaker than Black Form, but reaching the Full-Crown takes Yuno past it for 30 seconds.
- **Matchup:** Asta's Deflect and Causality Break punish careless spell spam and counters, and Yuno's Scutum and his range answer Asta's rushdown.

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
  client/   StarterPlayerScripts.Client: Input, Moves, PoseAnimator, M1Animations, VFX, Soft (the
            soft-light toolkit both kits draw with), CameraShake, HUD, TopBar, ShiftLock
    Kits/   one module per character: animations and VFX (Wind/Saint: Yuno's Full-Crown
            ultimate; AntiMagic/Comet and AntiMagic/Ascent: Asta's Black Form cutscenes)
```

- **Adding a character:** add an entry to `src/shared/Kits.luau`, a server module in `src/server/Kits/` (`Skills`, `AwakenedSkills`, `Awaken`, `Equip`) and a client module in `src/client/Kits/` (`PlayM1`, `OnSkill`, `SetAwakened`), all named after the kit id.
- **Balancing:** general numbers live in `src/shared/Config.luau`, per-character ones in `src/shared/Kits.luau`. Set `Config.Debug.ShowHitboxes = true` to see hitboxes.
- **Server-authoritative:** the server decides every hit, block and cooldown. Clients only send inputs and draw effects.
- **Animations are code:** `src/client/M1Animations.luau` holds keyframed R6 poses, played by `PoseAnimator` by overriding Motor6Ds. Nothing needs uploading and there are no animation-permission problems. Uploaded animation IDs can replace them later.
- **VFX are client-side:** the server sends `("EffectName", data)` and `src/client/VFX.luau` draws it. Effects use only textures built into Roblox, so nothing needs uploading.
