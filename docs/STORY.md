# Wickbearer: story bible

The game was called Tenebrae until Oct 31, 2026. It was renamed after an exact-name game turned up on Steam. Tenebrae is still the rite at the heart of the story.

A short, dark arc that runs underneath the roguelike loop. One run is the whole story: four dungeons, fifteen candles, one throne at the bottom.

## Tone and research

The story borrows mood, not material, from three places. Every name, character and event here is original.

- **The Witcher**: a monster-slayer who was *made*, not born, for a job nobody thanks them for. Curses that are really old grudges. Villains who were once the hero of their own story.
- **The Lord of the Rings**: a long descent into a dark that was dug too deep (the Well, the stair). A small bearer carrying a light that matters more than they do. Fallen kings who bargained for forever.
- **Vikings / the sagas**: fate you walk into with open eyes. Longships, ravens, jarls. A good death is worth a song, and a death in bed earns you nothing.
- **Tenebrae itself**: fifteen candles on the hearse, snuffed one by one; the last flame hidden behind the altar; the *strepitus*, the great noise of struck pews; the hidden candle brought back out. The game mechanics (depth = a candle goes out, the boss strepitus, the hidden-candle revive) are the story.

## The world

**The Norrow** is a northern country of fjords and black pine where, this winter, the sun has stopped rising. On a cliff above the **Underdeep** stands the Abbey of the Vigil. For three hundred winters its brothers have kept the rite: fifteen candles hold back **the Hush**, the dark beneath the world. Each winter they snuff the candles one by one, hide the last flame behind the altar, strike the pews until the stones shake, and carry the hidden flame back out. It always comes home.

This winter it did not.

## Characters

- **The Wick** (the player). A stick figure made of burnt-out candle wicks and soot, given a spark by Abbess Hild. Silent. Gold eyes, a red scarf, a borrowed blade. That spark is why they can come back once (the hidden-candle revive).
- **Abbess Hild**. The warrior abbess who keeps the rite and makes the wicks. Dies in the prologue, giving the Wick her blade and one order: bring it home.
- **Saint Umber, the Candle-Eater** (final boss). The *first* wick Hild ever made. For three hundred winters he carried the hidden flame into the dark and back, and every winter nobody was waiting at the door. This winter he kept it. He swallowed the flame and went down to the Hollow Throne, where he means to wear the dark when the last candle dies.
- **Brother Halvard, the Chain Warden** (boss, chapter I). The Abbey's gaoler, who chained himself into the Pit a hundred winters ago to keep it shut. Umber promised him the chains would come off.
- **Rurik the Drowned, the Hollow King** (boss, chapter II). A sea-king who rowed his longships down the Well to plunder the dark. The dark kept the crown and the king. Umber gave him that crown, and Rurik is the one who tells the Wick who Umber really is.
- **Jarl Sigvald, the Ashen Jarl** (boss, chapter III). A jarl who refused to die in his bed and fed himself to the forge, so he never died at all. He forges Umber's endless war and only wants a death worth a song.

## Structure in the game

| Chapter | Dungeon | Depths | Boss | Story beat |
|---|---|---|---|---|
| Prologue + I | The Pit of Psalms | I-IV | The Chain Warden | The flame is stolen, Hild dies, the Wick descends |
| II | The Drowned Well | V-VIII | The Hollow King | Revelation: Umber was a wick, the first one |
| III | The Bladeworks | IX-XII | The Ashen Jarl | Three candles remain; the throne is below |
| IV (endgame) | The Hollow Throne | XIII-XVI | Saint Umber | The fifteenth candle dies at depth XVI; total dark; final fight |

One candle goes out per depth, and they stay out. At depth XVI all fifteen are dark and the throne room is lit only by the Wick.

## Cutscenes

Each one plays once per browser and can be skipped. Style: anime action. Letterbox bars, focus lines, impact frames (white or red flash with black silhouettes), big manga sound effects (GASHAN!, DOBAAN!, GAKIIN!, DOM!), extreme close-ups of eyes, diagonal boss name plates, and serif chapter title cards.

1. **Prologue** (opens the run): the Norrow; the Abbey; the hearse going dark; *GONE*; Umber bursts through the doors; Hild's last stand (ZAN); Umber walks into the dark with the flame; the Wick's eyes open in the soot; Hild hands over her blade; title card **TENEBRAE · Chapter I · The Pit of Psalms**.
2. **Boss reveals** (start of each boss fight, the strepitus): a sound-effect impact, a close-up of the boss's eyes, then the name plate and a line.
3. **Dungeon endings** (after each boss): the boss's last words carry the story forward, then a chapter-end card.
4. **Dungeon intros** (entering depths V, IX, XIII): the history of the next place and a chapter title card.
5. **Finale** (after Saint Umber): the clash and the frozen moment after it; Umber's last words ("Not once was anyone waiting at the door"); the Wick takes the hidden flame into their own chest; the brothers strike the pews; dawn over the Abbey, and this time someone is waiting at the door. A last shot of a cracked crown and a violet eye in the deep: the Hush only sleeps. Then **The hidden candle returns · The End** and a victory summary (**THE DAWN RETURNS**).
6. **Hidden candle** (the once-per-run revive): a white impact frame and a flame igniting: *NOT YET*.

## Death

Souls-like. On the killing blow: hit-stop, a red flash, the world drains of colour and slows down. The Wick staggers back, drops to one knee on their planted blade, then crumbles into ash and embers that drift upward. A black band fades in across the screen with **EXTINGUISHED** in large crimson serif capitals, slowly growing, and then a line under it: *The dark keeps what it takes.* Then the run summary.

## Testing links

Add these to the playtest URL:

- `?story` replays every cutscene, even ones you have seen
- `?chapter=2`, `?chapter=3`, `?chapter=4` start a run at that dungeon
- `?final` starts two seconds before the Saint Umber fight

## Files

- `web/story.js`: the cutscene engine, the script, and the death sequence
- `web/build_story.py`: hooks story.js into the playtest build (run automatically at the end of `web/build_play.py`)
- `src/story.gd`, `src/hud.gd` and `src/main.gd`: the Godot port of the same layer (the cards, chapters, bosses, NOT YET, EXTINGUISHED and the victory)
