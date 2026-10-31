class_name Codex
extends RefCounted
## Lore entries for the Codex on the title screen. Each one unlocks the first
## time something happens in play: Game.learn(id) records it and shows a toast.
## Plain data, like RunData and Story.

const LORE := "LORE"
const PLACE := "PLACE"
const FOE := "FOE"
const BOSS := "BOSS"

const ENTRIES := [
	{"id": "norrow", "cat": LORE, "name": "THE NORROW",
		"text": "A country of fjords and long winters, where the sun once forgot to rise for forty days. Ever since, the Abbey has kept a vigil of candles through the darkest month, and the Norrow has never forgotten what the dark is like."},
	{"id": "hild", "cat": LORE, "name": "ABBESS HILD",
		"text": "Keeper of the Abbey and maker of wicks. She braids them from the burnt-out ends of three hundred winters of candles. Each one walks where light cannot, and each one she sends down, she waits for."},
	{"id": "hush", "cat": LORE, "name": "THE HUSH",
		"text": "The dark below the Abbey is not empty. It listens. Every candle that goes out lets it listen a little closer. When the fifteenth falls, the Hush begins to speak."},
	{"id": "strepitus", "cat": LORE, "name": "THE STREPITUS",
		"text": "The great noise at the end of the vigil. The brothers strike the pews until the stones shake, and the hidden flame comes home. Down here the noise has another meaning: something old has noticed you."},
	{"id": "umber", "cat": LORE, "name": "THE FIRST WICK",
		"text": "Before the Saint, there was a wick named Umber. For three hundred winters he carried the hidden flame into the dark and back. No one ever met him at the door. One winter he stopped coming back."},
	{"id": "dawn", "cat": LORE, "name": "THE DAWN",
		"text": "The flame came home, and someone was waiting at the door. The sun rose over the Norrow on the forty-first day. Far below, the Hush turned over in its sleep. It will wake again."},

	{"id": "place_0", "cat": PLACE, "name": "THE PIT OF PSALMS",
		"text": "The Abbey's oldest crypt, where the brothers who sang too loud were buried with their mouths sewn shut. The chains on the walls were meant for the dead. Some of them still pull."},
	{"id": "place_1", "cat": PLACE, "name": "THE DROWNED WELL",
		"text": "A cistern that swallowed a fleet. Rurik's longships still drift in the black water, their oars rising and falling for a crew that never stopped rowing."},
	{"id": "place_2", "cat": PLACE, "name": "THE BLADEWORKS",
		"text": "The forge where the Norrow's swords were made, until the forge started making smiths instead. The anvils still ring when no one strikes them."},
	{"id": "place_3", "cat": PLACE, "name": "THE HOLLOW THRONE",
		"text": "The bottom of the world, where the last candle burns. Umber built a throne from everything the dark ever took. He sits in it and waits for someone to come and take it back."},

	{"id": "foe_0", "cat": FOE, "name": "HOLLOW",
		"text": "Pilgrims who came down to pray and stayed too long. The dark wore away everything but the shape of a person, and the habit of walking toward light."},
	{"id": "foe_1", "cat": FOE, "name": "GLOOMWING",
		"text": "Bats of soot and silence that roost in the vaults. They do not see you. They hear the small crackle of your flame and dive for it."},
	{"id": "foe_2", "cat": FOE, "name": "BRUTE",
		"text": "Bell-ringers, once. They hauled the great bells for a lifetime, and their arms remember. Stand clear when one raises its fists."},
	{"id": "foe_3", "cat": FOE, "name": "HEXER",
		"text": "Brothers who learned the dark's own prayers. They throw them back at the light in slow, burning words. Close the distance and they forget their verses."},
	{"id": "foe_4", "cat": FOE, "name": "DROWNED",
		"text": "Rurik's oarsmen, still in their mail. They crouch in the shallows and leap at anything warm, as if it were the shore they never reached."},
	{"id": "foe_5", "cat": FOE, "name": "FORGED",
		"text": "Smiths the Bladeworks remade in iron. They hurl the blades they were made to finish, and every one comes back hot."},
	{"id": "foe_6", "cat": FOE, "name": "SNUFFER",
		"text": "Umber's own servants, made to put out candles. They step through shadow and close in on the flame. Every vigil has a snuffer. This one has many."},
	{"id": "elite", "cat": FOE, "name": "THE MARKED",
		"text": "Some of the dark's creatures burn with a stolen spark: swift, shielded or ready to burst. They carry three times the ash, and they know it."},

	{"id": "boss_0", "cat": BOSS, "name": "THE CHAIN WARDEN",
		"text": "Jailer of the Pit for a hundred winters. Umber promised him the chains would come off if he guarded the way down. They came off when you broke them."},
	{"id": "boss_1", "cat": BOSS, "name": "THE HOLLOW KING",
		"text": "Rurik Sea-Wolf came to plunder the dark and stayed to rule it. The crown Umber gave him was heavier than the sea. He knew what the Saint was, and told you with his last breath."},
	{"id": "boss_2", "cat": BOSS, "name": "THE ASHEN JARL",
		"text": "Jarl Sigvald fed himself to the forge so he would never die in his bed. He got his endless war. He wanted only one good death to end it, and you gave him one worth a song."},
	{"id": "boss_3", "cat": BOSS, "name": "SAINT UMBER",
		"text": "The first wick, the Candle-Eater, the Saint of the Hollow Throne. He was not cruel. He was only tired of coming home to an empty door."},
]


static func find(id: String) -> Dictionary:
	for e in ENTRIES:
		if e.id == id:
			return e
	return {}
