class_name Story
extends RefCounted
## The story layer from docs/STORY.md: four chapters, four bosses, and the
## cutscene cards the HUD plays between them. Plain data, like RunData.
##
## A card is {who, text} for a spoken or narrated line, or {title, sub} for a
## title card. Optional: col (accent), sfx (big impact word), flash (Color).

const GOLD := Color("#f2b43a")
const CYAN := Color("#3fd6c4")
const EMBER := Color("#ff8a5c")
const VIOLET := Color("#b44dff")
const RED := Color("#e5383b")

# map is an index into Game.MAPS
const CHAPTERS := [
	{"name": "THE PIT OF PSALMS", "map": 0, "col": RED, "boss": "THE CHAIN WARDEN", "who": "BROTHER HALVARD"},
	{"name": "THE DROWNED WELL", "map": 2, "col": CYAN, "boss": "THE HOLLOW KING", "who": "RURIK THE DROWNED"},
	{"name": "THE BLADEWORKS", "map": 3, "col": EMBER, "boss": "THE ASHEN JARL", "who": "JARL SIGVALD"},
	{"name": "THE HOLLOW THRONE", "map": 4, "col": VIOLET, "boss": "SAINT UMBER", "who": "THE CANDLE-EATER"},
]

const PROLOGUE := [
	{"title": "THE NORROW", "sub": "IN THE WINTER THE SUN FORGOT TO RISE"},
	{"text": "Fifteen candles hold back the Hush. Every winter the Abbey snuffs them, one by one, and hides the last flame behind the altar."},
	{"text": "Then the brothers strike the pews until the stones shake, and the hidden flame comes home. It always comes home."},
	{"who": "???", "text": "Mother. I have come for the light.", "sfx": "GONE", "flash": Color.WHITE},
	{"who": "ABBESS HILD", "text": "Umber. You were the best of us. Put it back."},
	{"who": "SAINT UMBER", "text": "I carried it down every winter. This winter the dark can keep it. And me.", "sfx": "ZAN", "flash": RED},
	{"text": "In the soot beneath the hearse, something made of old wicks opened its eyes."},
	{"who": "ABBESS HILD", "text": "I made you from burnt-out wicks, little one. You can walk where light cannot. Bring it home."},
	{"title": "TENEBRAE", "sub": "CHAPTER I  ·  THE PIT OF PSALMS  ·  DEPTHS I-IV", "col": GOLD},
]

const INTROS := [
	[],
	[
		{"text": "Rurik Sea-Wolf rowed his longships down the Well to plunder the dark."},
		{"text": "The dark plundered him instead. It kept the crown. It kept the king."},
		{"title": "THE DROWNED WELL", "sub": "CHAPTER II  ·  DEPTHS V-VIII", "col": CYAN},
	],
	[
		{"text": "In the Norrow they say a jarl who dies in his bed never drinks in the Long Hall."},
		{"text": "Jarl Sigvald found a way never to die at all. He fed himself to the forge, and the forge kept him burning."},
		{"title": "THE BLADEWORKS", "sub": "CHAPTER III  ·  DEPTHS IX-XII", "col": EMBER},
	],
	[
		{"who": "SAINT UMBER", "text": "So she made another. Of course she did."},
		{"who": "SAINT UMBER", "text": "Turn back, little brother. Down here I am the only one who still remembers what dawn looked like."},
		{"title": "THE HOLLOW THRONE", "sub": "FINAL CHAPTER  ·  DEPTHS XIII-XVI", "col": VIOLET},
	],
]

# the strepitus: an impact word, the boss's eyes, the name plate and a line
const REVEALS := [
	[{"who": "THE CHAIN WARDEN", "text": "A hundred winters I kept the Pit locked. Umber gave me a better lock. You.", "sfx": "GASHAN!", "flash": Color.WHITE}],
	[{"who": "THE HOLLOW KING", "text": "Every king pays for his crown. I paid with my sea. What will you pay, little candle?", "sfx": "DOBAAN!", "flash": Color.WHITE}],
	[{"who": "THE ASHEN JARL", "text": "Umber forges me a war that never ends. Come, wick! Give me a death worth a song!", "sfx": "GAKIIN!", "flash": Color.WHITE}],
	[
		{"text": "The fifteenth candle goes out."},
		{"text": "And in the dark, the noise begins.", "sfx": "DOM!", "flash": RED},
		{"who": "SAINT UMBER", "text": "There is no dawn left to save. Only the dark, and the one who holds it.", "flash": Color.WHITE},
	],
]

const ENDINGS := [
	[
		{"who": "THE CHAIN WARDEN", "text": "He swore the chains would come off... He lied. They come off now."},
		{"who": "THE CHAIN WARDEN", "text": "Go down, wick. The Well remembers everything that drowned in it."},
		{"title": "THE PIT FALLS SILENT", "sub": "THE WARDEN IS FREE  ·  THE DESCENT GOES ON", "col": GOLD},
	],
	[
		{"who": "THE HOLLOW KING", "text": "Ha... your Saint gave me this crown. Did they never tell you? He was a wick. Like you."},
		{"who": "THE HOLLOW KING", "text": "The first she ever made. Three hundred winters he carried her light into the dark... and no one waited at the door."},
		{"title": "THE WELL GIVES UP ITS DEAD", "sub": "THE FIRST WICK HAS A NAME  ·  UMBER", "col": CYAN},
	],
	[
		{"who": "THE ASHEN JARL", "text": "HA! Good... GOOD. That was worth a song."},
		{"who": "THE ASHEN JARL", "text": "He waits on the Hollow Throne. When the last candle dies, he will wear the dark like a cloak."},
		{"title": "THREE CANDLES REMAIN", "sub": "THE THRONE IS BELOW  ·  THERE IS NO WAY BACK", "col": GOLD},
	],
	[
		{"who": "SAINT UMBER", "text": "Every winter... I came back. Not once... was anyone waiting at the door.", "flash": Color.WHITE},
		{"text": "The wick took the flame into itself. A hidden candle needs someone to carry it."},
		{"text": "Above, the brothers struck the pews until the stones shook."},
		{"text": "And for the first time in three hundred winters, someone was waiting at the door."},
		{"text": "Far below, the Hush turned over in its sleep."},
		{"title": "THE HIDDEN CANDLE RETURNS", "sub": "THE END  ·  THANK YOU FOR PLAYING", "col": GOLD},
	],
]


## Chapter index (0-3) for a depth. Depths I-IV are chapter 0.
static func chapter_of(d: int) -> int:
	return clampi((d - 1) / 4, 0, 3)
