class_name Achievements
extends RefCounted
## Achievement list. The ids are the API names they will get in Steamworks,
## so the Steam build only has to call SetAchievement(id) where Game.unlock() runs.

const LIST := [
	{"id": "WARDEN_FREED", "name": "Unchained", "desc": "Defeat the Chain Warden."},
	{"id": "KING_DROWNED", "name": "The Well Gives Up Its Dead", "desc": "Defeat the Hollow King."},
	{"id": "JARL_SONG", "name": "Worth a Song", "desc": "Defeat the Ashen Jarl."},
	{"id": "DAWN", "name": "The Dawn Returns", "desc": "Defeat Saint Umber and bring the flame home."},
	{"id": "DAWN_UNAIDED", "name": "No Hidden Candle", "desc": "Win a run without using the hidden candle."},
	{"id": "VIGIL_V", "name": "The Long Vigil", "desc": "Win a run on Vigil V."},
	{"id": "NOT_YET", "name": "Not Yet", "desc": "Be brought back by the hidden candle."},
	{"id": "UNTOUCHED", "name": "Untouched", "desc": "Defeat a boss without being hit during the fight."},
	{"id": "FULL_SET", "name": "Sigil Bound", "desc": "Complete a rune set."},
	{"id": "CURSED", "name": "Bargain in the Dark", "desc": "Take a cursed rune."},
	{"id": "LAMPLIGHTER", "name": "Lamplighter", "desc": "Relight 10 braziers in one run."},
	{"id": "ELITE_HUNTER", "name": "Gold in the Ash", "desc": "Defeat 25 elite enemies."},
]
