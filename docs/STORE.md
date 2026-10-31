# Wickbearer: Steam store page

Draft copy and asset checklist for the Coming Soon page. Steam's limits are in brackets.

## Short description [300 characters]

The candles are going out. Descend through four dungeons beneath a winter abbey as a living wick, the only one who can walk where light cannot. A fast, vertical stickman action roguelike with wall jumps, slams, weapon skills and a story told in cutscenes between the bosses.

## About this game

**Fifteen candles hold back the Hush. This winter, the Saint stole the last flame.**

You are a wickbearer, braided from burnt-out candle ends by the Abbess who keeps the vigil. Go down through the Pit of Psalms, the Drowned Well, the Bladeworks and the Hollow Throne. Every depth, another candle goes out, the dark closes in and what lives in it gets stronger.

**Move like it matters.** Wall jump, double jump, dash, drop through ledges and slam down onto whatever is waiting below. Every hit lands with weight: hit-stop, trails and afterimages.

**Five weapons, five skills.** Katana, greatsword, spear, twin daggers and chain sickle, each with its own combo and a skill you charge by landing hits: Iaido, Earthsplitter, Skyward, Flurry and Reap.

**Build a different run every time.** Draw a weapon, draft runes as you level, complete rune sets and take cursed runes when you dare. A shade merchant waits after every boss.

**Four bosses, one story.** The Chain Warden, the Hollow King, the Ashen Jarl and Saint Umber, each revealed in a full cutscene. Learn who Umber was, and why no one ever waited at the door.

**Keep what the dark leaves you.** Bank your ash in the Reliquary for new weapons, runes and perks. Fill the Codex with 22 pages of lore. Climb five Vigils of difficulty, and chase 14 achievements.

**Built for Steam Deck.** Full controller support and 16:10 at 60 fps.

## Features list (for the capsule sidebar)

- Fast vertical action across multi-screen arenas
- 5 weapons, 5 weapon skills, rune drafts, sets and curses
- 4 dungeons, 4 bosses, a full story in cutscenes
- The Reliquary, the Codex and 5 Vigils of difficulty
- Full controller support, Steam Deck ready

## Tags (up to 20, most important first)

Action Roguelike, Roguelite, 2D Platformer, Hack and Slash, Stickman, Dark Fantasy, Souls-like, Fast-Paced, Difficult, Replay Value, Stylized, Singleplayer, Story Rich, Gothic, Atmospheric, Controller, Indie, Action, Platformer

## System requirements (minimum, from the Godot 4.3 export)

- OS: Windows 10 64-bit, or a 64-bit Linux with glibc 2.31 or newer
- Processor: dual core, 2 GHz
- Memory: 4 GB RAM
- Graphics: OpenGL 3.3 or Vulkan 1.0 capable
- Storage: 300 MB

## Assets to make

| Asset | Size | Notes |
| --- | --- | --- |
| Header capsule | 920 × 430 | Wickbearer mid-slam above a boss, candle light from below |
| Small capsule | 462 × 174 | Logo must read at this size |
| Main capsule | 1232 × 706 | Same art as header, wider crop |
| Vertical capsule | 748 × 896 | For seasonal sales |
| Library capsule | 600 × 900 | Logo plus figure |
| Library hero | 3840 × 1240 | No logo |
| Library logo | 1280 × 720 max, transparent | |
| Screenshots | 1920 × 1080, at least 5 | One per dungeon plus a boss reveal card |
| Trailer | 1080p, 60 to 90 s | Open on a slam, end on the candle going out |

Drafts of the header, small and main capsules are in `docs/store/`, cut from a real Saint Umber frame of the browser build. `docs/store/capsule.html` lays the logo over any frame saved as `art.png` next to it; open it with `#920x430` (or any size) in the address. Final capsules should be painted at full resolution from the same composition.

## Trailer shot list (75 seconds)

Capture at 1080p60 from the Godot build with the HUD off except where noted. Music: the boss theme, cut to the hits.

| Time | Shot | Notes |
| --- | --- | --- |
| 0:00 to 0:04 | Black. One candle. It goes out. | Sound only: the snuff, then silence |
| 0:04 to 0:10 | Prologue cards: "Fifteen candles hold back the Hush." Umber takes the flame. | The ZAN impact card on the cut |
| 0:10 to 0:14 | The wickbearer opens its eyes in the soot | Hard cut to gameplay on the first footstep |
| 0:14 to 0:26 | Movement montage: wall jump chain, double jump flip, dash through a Gloomwing, drop through a ledge, slam onto a Brute | One move per beat, each about 2 s |
| 0:26 to 0:34 | One weapon each: katana combo, greatsword arc, spear thrust, dagger air combo, sickle pull | Weapon name on screen, small, lower left |
| 0:34 to 0:42 | Weapon skills: Iaido, Earthsplitter, Skyward, Flurry, Reap | Meter full flash with the HUD on for the first one |
| 0:42 to 0:48 | Rune draft, a cursed rune pick, the shade merchant | HUD on |
| 0:48 to 0:52 | Four dungeon establishing shots, one second each | Pit, Well, Bladeworks, Throne |
| 0:52 to 1:04 | Boss reveals: GASHAN! DOBAAN! GAKIIN! then DOM! and Saint Umber's crown lighting | Fast cuts on each impact word |
| 1:04 to 1:10 | Last fight: the wickbearer slams down on Umber, white flash | Hit-stop held two frames longer than in game |
| 1:10 to 1:15 | WICKBEARER logo. "Bring the hidden flame home." Wishlist on Steam. | Logo over the last candle relighting |

## Before the page goes live

- Trademark check on the name WICKBEARER (see the project plan).
- Content survey: fantasy violence, no gore.
- Set the Coming Soon date to the Early Access window.
