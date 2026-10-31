class_name RunData
extends RefCounted
## Weapons, runes and shop items. Plain data so balance changes are one-line edits.

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
	"BLOODLINE": {"sig": "EMBER", "rar": "common", "desc": "Every 20 kills, heal 1 heart."},
	"HEAVY SHADOW": {"sig": "ECHO", "rar": "rare", "desc": "Slams are 60% wider and hit 70% harder."},
	"VIGIL": {"sig": "ECHO", "rar": "common", "desc": "+1 max heart, and heal it now."},
	"GLASS EDGE": {"sig": "EDGE", "rar": "cursed", "desc": "Damage +60%. Max hearts drop to 3."},
	"HUNGER": {"sig": "EMBER", "rar": "cursed", "desc": "Gain 50% more wax. You can no longer heal."},
}

const SHOP := [
	{"id": "MEND", "name": "MEND", "desc": "Heal 2 hearts.", "cost": 60},
	{"id": "TEMPER", "name": "TEMPER", "desc": "Your weapon deals +15% damage for the rest of the run.", "cost": 80},
	{"id": "LEAVE", "name": "WALK ON", "desc": "Keep your wax.", "cost": 0},
]

const RARITY_COL := {"common": Color("#f3ebe0"), "rare": Color("#f2b43a"), "cursed": Color("#e5383b")}
