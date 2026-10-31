# Balance baseline

`godot --headless -- --balance <runs> <vigil>` (or the **balance** workflow in the Actions tab, also nightly) runs a simple bot through real runs with no cheats. It walks to the nearest enemy, swings at the edge of reach, dodges any nearby wind-up with a dash and fires the weapon skill. Each hit it takes is logged with what was nearby, so the log shows *what* is killing it.

The bot is a floor rather than a player model. It never reads projectiles or plans routes. It's useful for regressions and for spotting unfair hits, not for setting the final difficulty.

## 2026-10-31, Vigil 0, 6 runs

| Build | Median depth | Range | Mean run | Notes |
| --- | --- | --- | --- | --- |
| Before fixes | 1 | 1 to 2 | 35 s | Every hit was a Hollow overlapping the player with no wind-up |
| Hollows lose contact damage | 3 | 2 to 4 | 90 s | Remaining hits: Gloomwing dives and Hollow lunges, both telegraphed. Found a crash when a VOLATILE burst hits the player mid-swing |
| Crash fixed, bot dodges dives | 3 | 3 to 4 | 110 s | No errors in 6 runs |

## What changed because of it

- Hollows only hurt with their telegraphed lunge and vault, never by standing in you.
- Fixed a script error when a kill hurt the player during a swing.

## Performance (smoke test, headless)

Physics tick: 1.0 ms average against an 8.3 ms budget at 120 Hz. The worst tick is about 35 ms, during an arena load. Peak node count is 60.
