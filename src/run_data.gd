class_name RunData
extends RefCounted
## Weapons, runes and shop items. Plain data so balance changes are one-line edits.

# each weapon's skill: charged by landing hits, fired with L / Q / Y
const SKILLS := {
	"katana": {"name": "IAIDO", "desc": "Flash through everything ahead of you."},
	"greatsword": {"name": "EARTHSPLITTER", "desc": "Split the floor both ways."},
	"spear": {"name": "SKYWARD", "desc": "Launch straight up through everything above."},
	"daggers": {"name": "FLURRY", "desc": "Eight cuts on everything close."},
	"sickle": {"name": "REAP", "desc": "Drag every enemy nearby to you and cut."},
}

const WEAPONS := {
	"katana": {"name": "KATANA", "desc": "Fast 3-hit combo. A dash cancels any swing.", "reach": 92.0, "step": 0.13, "damage": 1.0, "blade": 58.0},
	"greatsword": {"name": "GREATSWORD", "desc": "Slow, huge arcs. Slams hit twice as wide.", "reach": 112.0, "step": 0.2, "damage": 1.8, "blade": 74.0, "slam_mul": 2.0},
	"spear": {"name": "SPEAR", "desc": "Longest reach. Thrusts pierce the whole line.", "reach": 122.0, "step": 0.14, "damage": 1.1, "blade": 84.0},
	"daggers": {"name": "TWIN DAGGERS", "desc": "Very fast, short reach. Every third hit crits.", "reach": 70.0, "step": 0.085, "damage": 0.75, "blade": 36.0},
	"sickle": {"name": "CHAIN SICKLE", "desc": "Hooks enemies toward you on the third hit.", "reach": 108.0, "step": 0.15, "damage": 1.1, "blade": 50.0, "locked": true},
}

# sig groups runes into sets; cursed runes are strong with a real downside
const RUNES := {
	"WHETSTONE": {"sig": "EDGE", "rar": "common", "desc": "All damage +25%."},
	"FINISHER": {"sig": "EDGE", "rar": "common", "desc": "The third hit of a combo deals double damage."},
	"GALE STEP": {"sig": "GALE", "rar": "common", "desc": "Dash cooldown -40%."},
	"UPDRAFT": {"sig": "GALE", "rar": "rare", "desc": "Wall jumps blast nearby enemies upward."},
	"EMBER DASH": {"sig": "EMBER", "rar": "rare", "desc": "Dashing through enemies deals triple damage."},
	"BLOODLINE": {"sig": "EMBER", "rar": "common", "desc": "Every 20 kills, restore 20 HP."},
	"HEAVY SHADOW": {"sig": "ECHO", "rar": "rare", "desc": "Slams are 60% wider and hit 70% harder."},
	"VIGIL": {"sig": "ECHO", "rar": "common", "desc": "+20 max HP, and restore it now."},
	"GLASS EDGE": {"sig": "EDGE", "rar": "cursed", "desc": "Damage +60%. Max HP drops to 60."},
	"HUNGER": {"sig": "EMBER", "rar": "cursed", "desc": "Gain 50% more ash. You can no longer heal."},
	"SECOND WIND": {"sig": "GALE", "rar": "rare", "desc": "Every kill resets your dash.", "locked": true},
	"KINDLING": {"sig": "EMBER", "rar": "common", "desc": "Braziers burn twice as long and restore 20 HP when you relight them.", "locked": true},
	"REQUIEM": {"sig": "ECHO", "rar": "common", "desc": "Kills burst into shade that hits everything close by.", "locked": true},
	"TALLOW CROWN": {"sig": "EDGE", "rar": "cursed", "desc": "Bosses take 60% more damage. Every other enemy has 30% more health.", "locked": true},
}

# The Reliquary: permanent unlocks bought with banked ash on the title screen
const RELICS := [
	{"id": "sickle", "kind": "WEAPON", "name": "CHAIN SICKLE", "desc": "Adds the chain sickle to the weapon draw. Its third hit hooks enemies to you.", "cost": 250},
	{"id": "SECOND WIND", "kind": "RUNE", "name": "SECOND WIND", "desc": "Adds the rune to the draft pool: every kill resets your dash.", "cost": 120},
	{"id": "KINDLING", "kind": "RUNE", "name": "KINDLING", "desc": "Adds the rune to the draft pool: braziers burn longer and restore HP.", "cost": 120},
	{"id": "REQUIEM", "kind": "RUNE", "name": "REQUIEM", "desc": "Adds the rune to the draft pool: kills burst and hit nearby enemies.", "cost": 150},
	{"id": "TALLOW CROWN", "kind": "RUNE", "name": "TALLOW CROWN", "desc": "Adds the cursed rune to the draft pool: bosses take far more damage.", "cost": 150},
	{"id": "second_draw", "kind": "PERK", "name": "SECOND DRAW", "desc": "The weapon draw offers three weapons instead of two.", "cost": 180},
	{"id": "ashen_skin", "kind": "PERK", "name": "ASHEN SKIN", "desc": "Start every run with 20 more max HP.", "cost": 220},
	{"id": "spare_rune", "kind": "PERK", "name": "SPARE RUNE", "desc": "Draft one free rune at the start of every run.", "cost": 300},
	{"id": "ember_flask", "kind": "PERK", "name": "EMBER FLASK", "desc": "Restore 20 HP after every boss.", "cost": 200},
]

# two runes with the same sigil complete a set
const SETS := {
	"EDGE": "All damage +15%.",
	"GALE": "Dash cooldown -25%.",
	"EMBER": "Every ash pickup is worth 1 more.",
	"ECHO": "Slams are 25% wider.",
}

# Vigils: harder runs, unlocked one at a time by winning
const VIGILS := [
	"The rite as it was written.",
	"Enemies have 25% more health.",
	"Enemies come faster.",
	"The hidden candle starts unlit.",
	"Braziers burn for half as long.",
	"20 less max HP.",
]

const SHOP := [
	{"id": "MEND", "name": "MEND", "desc": "Restore 40 HP.", "cost": 60},
	{"id": "TEMPER", "name": "TEMPER", "desc": "Your weapon deals +15% damage for the rest of the run.", "cost": 80},
	{"id": "LEAVE", "name": "WALK ON", "desc": "Keep your ash.", "cost": 0},
]

const RARITY_COL := {"common": Color("#f3ebe0"), "rare": Color("#f2b43a"), "cursed": Color("#e5383b")}
