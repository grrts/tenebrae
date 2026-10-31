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
| Switch arena | 1 to 5 | |
| Restart | R | |
| Debug panel / hitboxes | F1 / F2 | |
| Skip to next depth | F3 | |

## What's here

- `src/world.gd` loads an ASCII arena from `maps/` and does tile collision (solid rock, one-way bridges).
- `src/player.gd` is the controller. Physics runs at 120 Hz with coyote time, a jump buffer, variable jump height, double jump, wall slide and wall jump, dash, drop-through, slam and the 3-step katana combo. Every tuning value is an `@export`, so it can be changed in the inspector while the game runs.
- `src/rig.gd` is the procedural stick rig ported from the web pitch. Every joint is driven by a damped spring, so pose changes get real in-betweens.
- `src/enemy.gd` has the four regular enemies: the Hollow (grunt), Gloomwing (flyer that dives, from depth II), Hexer (lobs violet hexes in arcs, from depth III) and Brute (heavy, telegraphed club swing, from depth V). Enemies come out of the portals nearest you, and their health rises 30% per depth.
- `src/hud.gd` draws the hearts, the depth title and the candle hearse.
- `src/fx.gd` holds grey-box particles, rings and the double-jump wing burst.
- `src/debug_overlay.gd` shows the player state, timers and FPS.

## The Tenebrae ritual

The name comes from an old church service where 15 candles on a triangular stand are put out one by one until the church is dark. The run follows it:

- **The hearse is the depth meter.** One candle goes out per depth (40 s here, 2 to 3 minutes in the real game). After 15 the stand relights and the count restarts darker.
- **The church darkens.** A `CanvasModulate` dims the world as candles go out, and the light around the player shrinks.
- **Braziers push the dark back.** Strike one to relight it for 20 s: it lights its area, and you deal +15% damage with a wider light.
- **The hidden candle** under the hearse is your one revive per run, at half health.
- **The strepitus** (the crash that cues bosses) comes with the first boss.

## Map legend

`#` rock, `=` bridge, `-` chained platform, `~` belt (all three are one-way), `w` water, `P` portal, `b` brazier, `I` pillar, `B` bell, `T` throne, `S` saw.

## Notes

- Maps are read with `FileAccess` from `res://maps`. For an exported build, add `maps/*.txt` to the export preset's non-resource include filter.
- There's no render interpolation yet. At 120 Hz physics this is fine on 60 and 120 Hz screens; add interpolation before testing on 144 Hz or higher.

## Playable browser build

`web/tenebrae-play.html` is a playable browser version of the same design (keyboard or controller), published as a link with every update. It is generated from the pitch page source with `python3 web/build_play.py` run inside `web/`. A Godot web export will replace it once the build is hosted.
