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

## What's here

- `src/world.gd` loads an ASCII arena from `maps/` and does tile collision (solid rock, one-way bridges).
- `src/player.gd` is the controller. Physics runs at 120 Hz with coyote time, a jump buffer, variable jump height, double jump, wall slide and wall jump, dash, drop-through, slam and the 3-step katana combo. Every tuning value is an `@export`, so it can be changed in the inspector while the game runs.
- `src/rig.gd` is the procedural stick rig ported from the web pitch. Every joint is driven by a damped spring, so pose changes get real in-betweens.
- `src/enemy.gd` is the Hollow grunt. Enemies come out of the portals nearest you.
- `src/fx.gd` holds grey-box particles, rings and the double-jump wing burst.
- `src/debug_overlay.gd` shows the player state, timers and FPS.

## Map legend

`#` rock, `=` bridge, `-` chained platform, `~` belt (all three are one-way), `w` water, `P` portal, `b` brazier, `I` pillar, `B` bell, `T` throne, `S` saw.

## Notes

- Maps are read with `FileAccess` from `res://maps`. For an exported build, add `maps/*.txt` to the export preset's non-resource include filter.
- There's no render interpolation yet. At 120 Hz physics this is fine on 60 and 120 Hz screens; add interpolation before testing on 144 Hz or higher.
