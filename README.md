# Tenebrae prototype

Grey-box feel test for the Prototype phase (Nov 2026 to Jan 2027). The gate for this phase is "fun with no art": the movement and katana combat have to feel good with flat shapes before any art is made.

Open the folder in **Godot 4.3** (or newer 4.x) and press F5. The whole scene is built in code, so the repo is plain text.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or arrows | Left stick or D-pad |
| Jump, double jump, wall jump | Space or Z | A |
| Drop through a bridge | Down + jump | Down + A |
| Katana (3-hit combo) | J or X | X |
| Slam | Down + attack in the air | Down + X |
| Dash (i-frames, cancels attacks) | K, Shift or C | RB or RT |
| Pause | Escape or P | Start |
| Switch arena | 1 to 5 | |
| Restart | R | |
| Debug panel / hitboxes | F1 / F2 | |
| Skip to next depth / next boss | F3 / F4 | |
| Skip a cutscene | Escape | |

## What's here

- `src/world.gd` loads an ASCII arena from `maps/` and does tile collision (solid rock, one-way bridges).
- `src/player.gd` is the controller. Physics runs at 120 Hz with coyote time, a jump buffer, variable jump height, double jump, wall slide and wall jump, dash, drop-through, slam and the 3-step katana combo. Every tuning value is an `@export`, so it can be changed in the inspector while the game runs.
- `src/rig.gd` is the procedural stick rig ported from the web pitch. Every joint is driven by a damped spring, so pose changes get real in-betweens.
- `src/enemy.gd` has the four regular enemies: the Hollow (grunt), Gloomwing (flyer that dives, from depth II), Hexer (lobs violet hexes in arcs, from depth III) and Brute (heavy, telegraphed club swing, from depth V). Each lower dungeon adds its own: the Drowned (the Well) crouch and pounce, the Forged (the Bladeworks) throw spinning blades along their floor, and Snuffers (the Throne) blink next to you, slash, and shrink your light while they're near. From depth III some come as gold-ringed elites with 2.2x health and triple wax: Swift (faster), Shielded (half damage from the front, so hit them from behind or slam) and Volatile (bursts when it dies). Enemies come out of the portals nearest you, and their health rises 30% per depth.
- `src/boss.gd` holds the four bosses on one body. The Chain Warden smashes the floor and sends shockwaves both ways. The Hollow King leaps and lands in a crash. The Ashen Jarl's forge-waves run faster and he starts leaping when hurt. Saint Umber leaps, casts hexes on every landing and wears a crown of candles.
- `src/story.gd` is the story from `docs/STORY.md` as data: the chapters, the prologue, the boss reveals, the chapter intros and endings, and the finale.
- `src/hud.gd` draws the hearts, the depth title, the candle hearse, the cutscene cards (letterbox, focus lines, name plates, title cards), the death band and the summaries.
- `src/fx.gd` holds grey-box particles, rings and the double-jump wing burst.
- `src/debug_overlay.gd` shows the player state, timers and FPS.

## The run

- **Weapon draw:** each run starts with a pick of 1 of 2 weapons (katana, greatsword, spear, twin daggers). The chain sickle unlocks once you have banked 400 wax in total.
- **Wax:** enemies drop wax that flies to you. It's your run currency and your XP.
- **Rune drafts:** every level-up, pick 1 of 3 runes. Runes change your moves (Updraft, Ember Dash, Heavy Shadow, Second Wind, Requiem and more), and three are cursed. Two runes with the same sigil complete a set: EDGE +15% damage, GALE faster dashes, EMBER more wax per pickup, ECHO wider slams.
- **Title screen:** shows your banked wax, deepest depth and dawns (wins), and the Vigil picker once you've won.
- **Vigils:** each win unlocks the next of five harder levels, and each level keeps the ones below it: more enemy health, faster spawns, no hidden candle, shorter braziers, one less heart.
- **Shade merchant:** opens after each boss. Mend, Temper, or walk on.
- **Death:** souls-like. The world slows and drains, the Wick crumbles into embers, and **EXTINGUISHED** fades in. 40% of your wax (plus 50 per boss) is banked to `user://tenebrae.cfg`, then a new run.
- **Victory:** beat Saint Umber at depth XVI to see the finale and **THE DAWN RETURNS**. A won run keeps all its wax.

## Achievements

Twelve achievements live in `src/achievements.gd` (bosses, the dawn, a win without the hidden candle, Vigil V, an untouched boss, sets, cursed runes, braziers and elites). They are saved to `user://tenebrae.cfg`, pop up as a toast, and are counted on the title screen. Their ids are the Steamworks API names, so the Steam build only needs a `SetAchievement(id)` call in `Game.unlock()`.

## The story

One run is the whole story (see `docs/STORY.md`). Four chapters of four depths each, and each chapter is its own dungeon:

| Depths | Dungeon (map) | Boss |
| --- | --- | --- |
| I-IV | The Pit of Psalms (`pit`) | The Chain Warden |
| V-VIII | The Drowned Well (`well`) | The Hollow King |
| IX-XII | The Bladeworks (`blade`) | The Ashen Jarl |
| XIII-XVI | The Hollow Throne (`throne`) | Saint Umber, the Candle-Eater |

The prologue, chapter intros and boss endings play once per save (the list is kept in `user://tenebrae.cfg`). Boss reveals and the finale always play. Every card can be advanced with jump or attack, and Escape skips the scene.

All weapon, rune and shop numbers live in `src/run_data.gd`.

## The Tenebrae ritual

The name comes from an old church service where 15 candles on a triangular stand are put out one by one until the church is dark. The run follows it:

- **The hearse is the depth meter.** One candle goes out per depth (40 s here, 2 to 3 minutes in the real game), and they stay out. At depth XVI all fifteen are dark and the throne room is lit only by the Wick.
- **The church darkens.** A `CanvasModulate` dims the world as candles go out, and the light around the player shrinks.
- **Braziers push the dark back.** Strike one to relight it for 20 s: it lights its area, and you deal +15% damage with a wider light.
- **The hidden candle** under the hearse is your one revive per run, at half health: a white flash and *NOT YET*.
- **The strepitus** is the crash that brings a boss down every 4 depths. The depth timer pauses until the boss dies.

## Map legend

`#` rock, `=` bridge, `-` chained platform, `~` belt (all three are one-way), `w` water, `P` portal, `b` brazier, `I` pillar, `B` bell, `T` throne, `S` saw.

## Notes

- Maps are read with `FileAccess` from `res://maps`. For an exported build, add `maps/*.txt` to the export preset's non-resource include filter.
- Physics interpolation is on (Godot 4.3), so movement stays smooth on 144 Hz and faster screens. Anything that teleports calls `reset_physics_interpolation()`.
- The pause menu has Options, saved to `user://tenebrae.cfg`: screen shake (100, 50, 0%), flashes (off is photosensitivity mode), hit-stop, fullscreen, and two assists that never block achievements: game speed (100, 85, 70%) and +2 starting hearts.

## Playable browser build

`web/tenebrae-play.html` is a playable browser version of the same design (keyboard or controller), published as a link with every update. It is generated from the pitch page source with `python3 web/build_play.py` run inside `web/`. A Godot web export will replace it once the build is hosted.

## Sound

All audio is original and procedural. Nothing is sampled or licensed.

- **Browser build:** `web/audio.js` synthesizes everything live with Web Audio. It watches the game state each frame (`AUDIO.watch`) and plays SFX, the score and the cutscene voices. **M** mutes.
- **Godot build:** `src/audio.gd` is the `Sfx` autoload. It watches `Game` the same way and plays the rendered files in `audio/` (`sfx/`, looping score stems per chapter in `music/`, and a gibberish voice per spoken line in `vo/`, named by the line's md5). **M** mutes. Other code can also call `Sfx.play("ui_ok")` directly.
- **Re-rendering:** after changing `web/audio.js` or a spoken line in `src/story.gd`, run `node tools/render_audio.js` from the repo root (needs Playwright's Chromium and ffmpeg). Both builds then sound the same.
- **Voices:** speech is gibberish, formant-synthesized from the letters of each line, with one voice per speaker (`CAST` in `web/audio.js`).
- **Score:** a drone and a choir in a different mode per dungeon. It thins and darkens as the candles go out, drums come in as the fight heats up, and bosses get their own faster stem.
