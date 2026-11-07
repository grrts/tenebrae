# Wickbearer on Steam

Everything Steam-related is wired up and waits for one thing: the Steamworks app.

## What needs doing once (the only manual step)

1. Create the app in Steamworks (Steam Direct fee). Note the app id.
2. In the GitHub repo, add:
   - variable `STEAM_APP_ID` (the app id),
   - secret `STEAM_USERNAME` (a Steam build account with Steam Guard via email or authenticator),
   - secret `STEAM_CONFIG_VDF` (base64 of `config/config.vdf` after one `steamcmd +login` on that account; see game-ci/steam-deploy).
3. In Steamworks, create depots `app+1` (Windows) and `app+2` (Linux), and a branch named `beta`.

Until then the `steam` job in `.github/workflows/check.yml` leaves a notice and skips. Once they exist, every green push to main uploads the Windows and Linux builds to the `beta` branch. Setting a build live on the default branch stays a manual click in Steamworks.

## Achievements and stats

Create these in Steamworks with exactly these API names (from `src/achievements.gd`):

WARDEN_FREED, KING_DROWNED, JARL_SONG, DAWN, DAWN_UNAIDED, VIGIL_V, NOT_YET, UNTOUCHED, FULL_SET, CURSED, LAMPLIGHTER, RELIQUARY, ELITE_HUNTER, CODEX

Integer stats: `BEST_DEPTH` (max, deepest depth reached), `DAWNS` (increment, runs won).

Rich presence: add a localization token `#Status` with value `%status%`. The game sets `status` to e.g. "Depth IX · The Bladeworks".

## The Steam build

`src/steam_bridge.gd` talks to the GodotSteam singleton when it exists. The plain Godot 4.3 export has no Steam singleton, so every call is a no-op. For the shipped build, export with the GodotSteam 4.3 export templates (godotsteam.com) and place `steam_api64.dll` / `libsteam_api.so` next to the executable. The app id comes from `steam_appid.txt` next to the executable or the project setting `steam/app_id` (480, Valve's test app, until the real id is set).

On start, achievements already earned in the local save are pushed to Steam, so earlier progress carries over.

## Steam Cloud (Auto-Cloud)

Root: `WinAppDataRoaming` path `Godot/app_userdata/Wickbearer`, pattern `wickbearer.cfg*`. Linux: `LinuxHome` path `.local/share/godot/app_userdata/Wickbearer`, same pattern. Saves are written atomically with a `.bak` copy, and saves from the old "Wickbearer Prototype" folder are migrated on first launch.

## Steam Deck checklist

- Controller only: every menu, the Codex and the options work with a pad, prompts switch to pad buttons.
- 1280 × 800: the window uses `stretch/aspect=expand`, so 16:10 fills the screen.
- Text: HUD size and subtitle size go to 150%.
- Performance: about 1 ms per physics tick headless, far under the 8.3 ms budget.
- Linux build is native; no Proton needed.
