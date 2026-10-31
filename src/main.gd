class_name Game
extends Node2D
## Prototype root. Builds the scene in code so the repo stays text-only.

const MAPS := ["pit", "spire", "well", "blade", "throne"]
const SPAWN_EVERY := 2.4
const BRAZIER_TIME := 20.0
const BRAZIER_DMG := 1.15

## Seconds per depth. The real game uses 2-3 minutes; shorter here so a test run sees the whole curve.
@export var depth_time := 40.0

var world: World
var fx: Fx
var player: Player
var camera: Camera2D
var overlay: DebugOverlay
var dbg: Node2D
var hud: Hud
var enemies: Array[Enemy] = []
var hexes: Array = []
var hex_layer: Node2D
var lights: Node2D
var dark: CanvasModulate
var player_light: PointLight2D
var brazier_lights: Array[PointLight2D] = []
var brazier_t: Array[float] = []
var light_tex: GradientTexture2D

var depth := 1
var depth_t := 0.0
var hidden_candle := true
var boss: Boss = null
var frozen := false
# true between a boss kill and the end of its cutscene and shop, so the depth clock waits
var story_hold := false
var won := false

# run state
var weapon := ""
var runes: Array[String] = []
var lvl := 1
var xp := 0
var run_wax := 0
var temper := 0
var bosses := 0
var run_time := 0.0
var pickups: Array = []
# meta, saved between sessions
const SAVE_PATH := "user://wickbearer.cfg"
var bank := 0
var earned := 0
var seen: Array = []
var vigil := 0
var vigil_max := 0
var best_depth := 0
var wins := 0
var sets_done: Array[String] = []
var unlocked_vigil := 0
var achieved: Array = []
var elite_kills := 0
var run_braziers := 0
var boss_untouched := false
# playtest log: every rune offered, so pick rates can be measured
var offered: Array = []
const RUNS_PATH := "user://runs.jsonl"
# options, saved with the meta progress
var opt_shake := 1.0 ## 1, 0.5 or 0
var opt_fullscreen := false
var opt_flashes := true ## false is photosensitivity mode: no full-screen flashes
var opt_hitstop := true
var opt_speed := 1.0 ## game speed: 1, 0.85 or 0.7
var opt_hearts := false ## assist: +40 HP; achievements still count

# --smoke (used by CI): a bot mashes inputs, depths fly by, and the run is forced
# through the boss, the hidden candle and a death, then the game quits.
var smoke := false
var smoke_t := 0.0
var smoke_held := ""
var smoke_map := 0
var smoke_boss_t := 0.0
var smoke_phase := 0
var smoke_elites: Array[String] = []
var smoke_p_t := 0.0

var map_i := 1
var hitstop := 0.0
var dash_id := 0
var kills := 0
var spawn_t := 1.0
var dead_t := 0.0
var shake_t := 0.0
var shake_mag := 0.0
var show_debug := true
var show_boxes := false
var boxes: Array = []


func _ready() -> void:
	_setup_input()
	world = World.new()
	add_child(world)
	fx = Fx.new()
	fx.z_index = 5
	dbg = Node2D.new()
	dbg.z_index = 100
	dbg.draw.connect(_draw_debug)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	hex_layer = Node2D.new()
	hex_layer.z_index = 6
	hex_layer.draw.connect(_draw_hexes)
	dark = CanvasModulate.new()
	add_child(dark)
	light_tex = GradientTexture2D.new()
	light_tex.width = 256
	light_tex.height = 256
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.85, 0.7, 1))
	grad.set_color(1, Color(1, 0.85, 0.7, 0))
	light_tex.gradient = grad
	overlay = DebugOverlay.new()
	overlay.game = self
	add_child(overlay)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	smoke = "--smoke" in OS.get_cmdline_user_args()
	if smoke:
		depth_time = 2.0
		print("smoke test: start")
	_load_meta()
	_apply_options()
	start(0, not smoke)


func _smoke(dt: float) -> void:
	smoke_t += dt
	var actions := ["left", "right", "jump", "attack", "dash", "down"]
	for a in actions:
		Input.action_release(a)
	if smoke_held != "":
		Input.action_press(smoke_held)
	if randf() < dt * 2:
		smoke_held = ["left", "right", ""][randi() % 3]
	if randf() < dt * 6:
		Input.action_press(actions[2 + randi() % 4])
	if smoke_t > 170:
		print("smoke test: timed out in phase %d at depth %d" % [smoke_phase, depth])
		get_tree().quit(1)
	match smoke_phase:
		0:
			# play the whole story: the bot cannot die, and each boss gets 2 s before it is killed
			player.hp = player.max_hp
			if boss != null:
				smoke_boss_t += dt
				if smoke_boss_t > 2.0:
					smoke_boss_t = 0.0
					print("smoke test: killing %s at depth %d" % [boss.boss_name, depth])
					hit_enemy(boss, 99999, Vector2.ZERO)
			if won:
				print("smoke test: reached the dawn after %d s" % int(smoke_t))
				smoke_phase = 1
		1:
			# the victory summary closes on a press, which starts a new run
			if not won and not hud.busy():
				smoke_phase = 2
				smoke_p_t = 0.0
		2:
			smoke_p_t += dt
			if smoke_p_t > 3 and hidden_candle and not hud.busy():
				print("smoke test: forcing the hidden candle")
				_smoke_hit()
			elif smoke_p_t > 5 and not hidden_candle and not player.dead and not hud.busy():
				print("smoke test: forcing death")
				_smoke_hit()
			elif player.dead and hud.summary != null:
				print("smoke test: death summary shown")
				hud.summary = null
				smoke_phase = 3
				smoke_p_t = 0.0
				player.dead = false
				player.hp = player.max_hp
				Engine.time_scale = 1.0
				open_pause()
				var m = hud.menu
				hud.menu = null
				m.cb.call(1)
				for k in 3:
					# shake off, shake on, back to pause, then resume
					m = hud.menu
					hud.menu = null
					m.cb.call([0, 0, m.opts.size() - 1][k] if k < 2 else hud_last(m))
				m = hud.menu
				hud.menu = null
				m.cb.call(0)
				print("smoke test: options ok, shake %.1f" % opt_shake)
				opt_shake = 1.0
				# controls: rebind jump to L, check the map and the dev keys, then back to defaults
				open_controls()
				m = hud.menu
				hud.menu = null
				m.cb.call(REBINDABLE.find("jump"))
				var kev := InputEventKey.new()
				kev.physical_keycode = KEY_L
				kev.pressed = true
				_input(kev)
				var kl := InputEventKey.new()
				kl.physical_keycode = KEY_L
				var ok_bind: bool = keys_of("jump")[0] == KEY_L and InputMap.action_has_event("jump", kl) and is_bound(KEY_L) and rebinding == ""
				binds.clear()
				_setup_input()
				_save_meta()
				hud.menu = null
				print("smoke test: controls %s, jump keys %s" % ["ok" if ok_bind and keys_of("jump")[0] == KEY_SPACE else "FAILED", " / ".join(keys_of("jump").map(key_name))])
				hud.open_title(_smoke_title_ok)
		3:
			# every arena loads and runs briefly
			smoke_p_t += dt
			if smoke_map < MAPS.size() and smoke_p_t > smoke_map * 0.8:
				print("smoke test: map %s" % MAPS[smoke_map])
				hud.menu = null
				_load_arena(smoke_map)
				smoke_map += 1
			if smoke_p_t > MAPS.size() * 0.8 + 1:
				print("smoke test: done, depth %d, kills %d" % [depth, kills])
				get_tree().quit()


func _smoke_title_ok() -> void:
	print("smoke test: pause and title screen ok")


func _smoke_hit() -> void:
	player.hp = 1
	player.invuln = 0
	player.dash = 0
	player.take_hit(player.position.x)


## Depth numbers read as Roman numerals, like psalm numbers in the service.
static func roman(n: int) -> String:
	var r := ""
	for pair in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= pair[0]:
			r += pair[1]
			n -= pair[0]
	return r


## Candles out on the hearse. One per depth, and they stay out: at depth XVI all fifteen are dark.
func candles_out() -> int:
	return mini(15, depth - 1)


## 0 at depth I, 1 in the throne room, lit only by the Wick.
func darkness() -> float:
	return clampf(candles_out() / 13.0, 0, 1)


func chapter() -> int:
	return Story.chapter_of(depth)


## A new run. i is the map; the story always begins in the Pit, the number keys can start elsewhere for testing.
func start(i: int, show_title := false) -> void:
	Engine.time_scale = opt_speed
	if player:
		player.queue_free()
	for n in [fx, dbg, camera, hex_layer]:
		if n.get_parent():
			n.get_parent().remove_child(n)
	player = Player.new()
	player.game = self
	add_child(player)
	add_child(fx)
	add_child(hex_layer)
	add_child(dbg)
	player.add_child(camera)
	player_light = _make_light(player, Vector2(0, -30), 4.5, 1.0)
	depth = 1
	depth_t = 0.0
	hidden_candle = true
	story_hold = false
	won = false
	runes.clear()
	sets_done.clear()
	offered.clear()
	run_braziers = 0
	lvl = 1
	xp = 0
	run_wax = 0
	temper = 0
	bosses = 0
	run_time = 0.0
	kills = 0
	dead_t = 0.0
	hitstop = 0.0
	_load_meta()
	_load_arena(i)
	if show_title:
		hud.open_title(_begin)
	else:
		_begin()


## The run proper: Vigil rules apply, then the prologue (first time) and the weapon draw.
func _begin() -> void:
	hidden_candle = vigil < 3
	if vigil >= 5:
		player.max_hp -= 1
	if opt_hearts:
		player.max_hp += 2
	player.hp = player.max_hp
	_play_once("prologue", Story.PROLOGUE, _weapon_draw)


func open_pause() -> void:
	var opts := [
		{"id": "resume", "name": "RESUME", "desc": "Back into the dark.", "tag": ""},
		{"id": "options", "name": "OPTIONS", "desc": "Screen shake, fullscreen and controls.", "tag": ""},
		{"id": "restart", "name": "RESTART", "desc": "Abandon this run. Ash you carry is lost.", "tag": ""},
		{"id": "title", "name": "TITLE", "desc": "Abandon this run and return to the title.", "tag": ""},
	]
	hud.open_choice("PAUSED", "DEPTH %s  ·  %s" % [roman(depth), Story.CHAPTERS[chapter()].name], opts, _pause_pick.bind(opts), _resume)


func _resume() -> void:
	pass


func _pause_pick(i: int, opts: Array) -> void:
	match opts[i].id:
		"restart":
			start(0)
		"title":
			start(0, true)
		"options":
			open_options()


func hud_last(m) -> int:
	return m.opts.size() - 1


func open_options() -> void:
	var opts := [
		{"id": "shake", "name": "SHAKE %d%%" % roundi(opt_shake * 100), "desc": "Screen shake on hits, slams and bosses: 100, 50 or 0%.", "tag": "OPTION"},
		{"id": "flash", "name": "FLASHES %s" % ("ON" if opt_flashes else "OFF"), "desc": "Off is photosensitivity mode: no full-screen flashes.", "tag": "OPTION"},
		{"id": "stop", "name": "HIT-STOP %s" % ("ON" if opt_hitstop else "OFF"), "desc": "The tiny freeze when a hit lands.", "tag": "OPTION"},
		{"id": "speed", "name": "SPEED %d%%" % roundi(opt_speed * 100), "desc": "Assist: slow the whole game to 85 or 70%. Achievements still count.", "tag": "ASSIST"},
		{"id": "hearts", "name": "+40 HP %s" % ("ON" if opt_hearts else "OFF"), "desc": "Assist: start each run with 40 extra HP. Applies next run.", "tag": "ASSIST"},
		{"id": "full", "name": "FULLSCREEN %s" % ("ON" if opt_fullscreen else "OFF"), "desc": "Fill the screen, or play in a window.", "tag": "OPTION"},
		{"id": "controls", "name": "CONTROLS", "desc": "Rebind keys and mouse buttons. A controller always works.", "tag": "OPTION"},
		{"id": "back", "name": "BACK", "desc": "Return to the pause menu.", "tag": ""},
	]
	hud.open_choice("OPTIONS", "SAVED BETWEEN SESSIONS", opts, _option_pick.bind(opts), open_pause)


func _option_pick(i: int, opts: Array) -> void:
	match opts[i].id:
		"shake":
			opt_shake = 0.5 if opt_shake > 0.75 else (0.0 if opt_shake > 0.25 else 1.0)
		"flash":
			opt_flashes = not opt_flashes
		"stop":
			opt_hitstop = not opt_hitstop
		"speed":
			opt_speed = 0.85 if opt_speed > 0.9 else (0.7 if opt_speed > 0.75 else 1.0)
			Engine.time_scale = opt_speed
		"hearts":
			opt_hearts = not opt_hearts
		"full":
			opt_fullscreen = not opt_fullscreen
			_apply_options()
		"controls":
			open_controls()
			return
		"back":
			open_pause()
			return
	_save_meta()
	open_options()


const CONTROL_NAMES := {"left": "MOVE LEFT", "right": "MOVE RIGHT", "up": "UP", "down": "DOWN", "jump": "JUMP", "attack": "ATTACK", "dash": "DASH"}
const CONTROL_DESC := {"left": "", "right": "", "up": "Also jumps while UP JUMPS is on.", "down": "Drop through bridges (with jump), slam (with attack in the air).",
	"jump": "Jump, double jump, wall jump. Hold for height.", "attack": "Tap to swing, hold to keep the combo going.", "dash": "I-frames. Cancels any swing."}


func open_controls() -> void:
	var opts := []
	for a in REBINDABLE:
		var names := []
		for k in keys_of(a):
			names.append(key_name(k))
		opts.append({"id": a, "name": "%s  %s" % [CONTROL_NAMES[a], " / ".join(names)],
			"desc": "PRESS A KEY OR MOUSE BUTTON  ·  ESC CANCELS" if rebinding == a else "%s Pick to rebind." % CONTROL_DESC[a], "tag": "REBIND"})
	opts.append({"id": "upjump", "name": "UP JUMPS %s" % ("ON" if opt_up_jump else "OFF"), "desc": "W and Up also jump.", "tag": "OPTION"})
	opts.append({"id": "reset", "name": "DEFAULTS", "desc": "WASD + Space / J / K or mouse, and arrows + Z / X / C.", "tag": "OPTION"})
	opts.append({"id": "back", "name": "BACK", "desc": "Return to the options.", "tag": ""})
	hud.open_choice("CONTROLS", "WAITING FOR A KEY" if rebinding != "" else "SAVED BETWEEN SESSIONS", opts, _controls_pick.bind(opts), open_options)
	if rebinding != "":
		hud.menu.pick = REBINDABLE.find(rebinding)
		hud.menu.locked = true


func _controls_pick(i: int, opts: Array) -> void:
	var id: String = opts[i].id
	match id:
		"upjump":
			opt_up_jump = not opt_up_jump
			_setup_input()
			_save_meta()
		"reset":
			binds.clear()
			opt_up_jump = true
			_setup_input()
			_save_meta()
		"back":
			open_options()
			return
		_:
			rebinding = id
	open_controls()


func _apply_options() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if opt_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Swaps the arena under a running game: chapters move the run to a new dungeon.
func _load_arena(i: int) -> void:
	map_i = i
	for e in enemies:
		e.queue_free()
	enemies.clear()
	boss = null
	hexes.clear()
	pickups.clear()
	if lights:
		lights.queue_free()
	world.load_map("res://maps/%s.txt" % MAPS[i])
	player.position = world.spawn
	player.vel = Vector2.ZERO
	player.reset_physics_interpolation()
	lights = Node2D.new()
	add_child(lights)
	brazier_lights.clear()
	brazier_t.clear()
	for b in world.braziers:
		brazier_lights.append(_make_light(lights, b, 1.5, 0.35))
		brazier_t.append(0.0)
	camera.position = Vector2(0, -60)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.size.x)
	camera.limit_bottom = int(world.size.y)
	camera.reset_smoothing()
	spawn_t = 1.0


## Story scenes that set the scene play once per save; boss reveals and the finale always play.
func _play_once(id: String, cards: Array, cb: Callable) -> void:
	if id in seen and not smoke:
		cb.call()
		return
	if not id in seen:
		seen.append(id)
		_save_meta()
	hud.play(cards, cb)


func _weapon_draw() -> void:
	var pool := RunData.WEAPONS.keys().filter(func(k): return not RunData.WEAPONS[k].get("locked", false) or earned >= 400)
	pool.shuffle()
	var opts := []
	for k in pool.slice(0, 2):
		var wd: Dictionary = RunData.WEAPONS[k]
		opts.append({"id": k, "name": wd.name, "desc": wd.desc, "tag": "WEAPON", "col": Color("#f3ebe0")})
	hud.open_choice("CHOOSE YOUR WEAPON", "A NEW DRAW EVERY RUN", opts, func(i): _pick_weapon(opts[i]))


func _pick_weapon(o: Dictionary) -> void:
	_equip(o.id)
	hud.show_banner("DEPTH I", "%s · %s" % [o.name, Story.CHAPTERS[0].name], 1.8)


func _equip(id: String) -> void:
	weapon = id
	var wd: Dictionary = RunData.WEAPONS[id]
	player.reach = wd.reach
	player.step_time = wd.step
	player.damage = wd.damage
	player.blade_len = wd.blade
	player.slam_radius = 160.0 * wd.get("slam_mul", 1.0)


## Unlocks an achievement once and shows a toast. A Steam build calls SetAchievement(id) here.
func unlock(id: String) -> void:
	if id in achieved:
		return
	achieved.append(id)
	_save_meta()
	for a in Achievements.LIST:
		if a.id == id:
			hud.toasts.append({"name": a.name, "t": 0.0})
	if smoke:
		print("smoke test: achievement %s" % id)


## One JSON line per run in user://runs.jsonl. tools/runs_report.py turns a folder of these into the playtest numbers.
func _log_run() -> void:
	var rec := {
		"at": Time.get_datetime_string_from_system(), "build": ProjectSettings.get_setting("application/config/version", "dev"),
		"won": won, "depth": depth, "time": snappedf(run_time, 0.1), "kills": kills, "bosses": bosses,
		"weapon": weapon, "runes": runes, "offered": offered, "lvl": lvl, "wax": run_wax, "vigil": vigil,
		"revived": not hidden_candle and vigil < 3, "assist": opt_speed < 1.0 or opt_hearts, "smoke": smoke,
	}
	var f := FileAccess.open(RUNS_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(RUNS_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))
	f.close()
	if smoke:
		print("smoke test: run logged, won %s, depth %d" % [won, depth])


func on_player_hit() -> void:
	boss_untouched = false


func has_rune(r: String) -> bool:
	return r in runes


## Multiplier applied to every hit the player lands.
func damage_mul() -> float:
	var m := 1.0 + 0.15 * temper
	if has_rune("WHETSTONE"):
		m *= 1.25
	if has_rune("GLASS EDGE"):
		m *= 1.6
	if "EDGE" in sets_done:
		m *= 1.15
	if brazier_buff():
		m *= BRAZIER_DMG
	return m


func xp_need() -> int:
	return 6 + lvl * 4


func _open_draft() -> void:
	var pool := RunData.RUNES.keys().filter(func(k): return not (k in runes))
	pool.shuffle()
	var opts := []
	for k in pool.slice(0, 3):
		var rd: Dictionary = RunData.RUNES[k]
		opts.append({"id": k, "name": k, "desc": rd.desc, "tag": "%s · %s" % [rd.sig, rd.rar.to_upper()], "col": RunData.RARITY_COL[rd.rar]})
	if opts.is_empty():
		return
	for o in opts:
		offered.append(o.id)
	hud.open_choice("LEVEL %d · DRAFT A RUNE" % lvl, "RUNES CHANGE HOW YOUR MOVES WORK", opts, func(i): _take_rune(opts[i].id))


func _take_rune(id: String) -> void:
	runes.append(id)
	match id:
		"GALE STEP":
			player.dash_cooldown *= 0.6
		"HEAVY SHADOW":
			player.slam_radius *= 1.6
		"VIGIL":
			player.max_hp += 1
			heal(1)
		"GLASS EDGE":
			player.max_hp = 3
			player.hp = minf(player.hp, 3)
	var rd: Dictionary = RunData.RUNES[id]
	hud.show_banner(id, String(rd.desc).to_upper(), 1.4)
	if rd.rar == "cursed":
		unlock("CURSED")
	var sg: String = rd.sig
	if not sg in sets_done and runes.filter(func(r): return RunData.RUNES[r].sig == sg).size() >= 2:
		sets_done.append(sg)
		match sg:
			"GALE":
				player.dash_cooldown *= 0.75
			"ECHO":
				player.slam_radius *= 1.25
		hud.show_banner("%s SET" % sg, String(RunData.SETS[sg]).to_upper(), 2.0)
		unlock("FULL_SET")


func heal(n: int) -> void:
	if has_rune("HUNGER"):
		return
	player.hp = minf(player.max_hp, player.hp + n)


func _open_shop() -> void:
	var opts := []
	for it in RunData.SHOP:
		var afford: bool = run_wax >= it.cost
		opts.append({"id": it.id, "name": it.name, "desc": it.desc, "tag": ("%d ASH" % it.cost) if it.cost > 0 else "FREE", "col": Color("#f3ebe0") if afford else Color(0.4, 0.37, 0.35), "cost": it.cost})
	hud.open_choice("SHADE MERCHANT", "YOU HAVE %d ASH · SPEND IT OR LOSE 60%% OF IT ON DEATH" % run_wax, opts, func(i): _buy(opts[i]))


func _buy(o: Dictionary) -> void:
	story_hold = false
	if run_wax < o.cost:
		hud.show_banner("NOT ENOUGH ASH", "YOU WALK ON", 1.2)
		return
	run_wax -= o.cost
	if o.id == "MEND":
		heal(2)
	elif o.id == "TEMPER":
		temper += 1


func _load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		bank = cfg.get_value("meta", "bank", 0)
		earned = cfg.get_value("meta", "earned", 0)
		seen = cfg.get_value("story", "seen", [])
		vigil_max = cfg.get_value("meta", "vigil_max", 0)
		best_depth = cfg.get_value("meta", "best_depth", 0)
		wins = cfg.get_value("meta", "wins", 0)
		achieved = cfg.get_value("achievements", "unlocked", [])
		elite_kills = cfg.get_value("achievements", "elite_kills", 0)
		var sh = cfg.get_value("options", "shake", 1.0)
		opt_shake = (1.0 if sh else 0.0) if typeof(sh) == TYPE_BOOL else float(sh)
		opt_fullscreen = cfg.get_value("options", "fullscreen", false)
		opt_flashes = cfg.get_value("options", "flashes", true)
		opt_hitstop = cfg.get_value("options", "hitstop", true)
		opt_speed = cfg.get_value("options", "speed", 1.0)
		opt_hearts = cfg.get_value("options", "hearts", false)
		opt_up_jump = cfg.get_value("controls", "up_jump", true)
		binds = cfg.get_value("controls", "binds", {})
		_setup_input()


func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "bank", bank)
	cfg.set_value("meta", "earned", earned)
	cfg.set_value("story", "seen", seen)
	cfg.set_value("meta", "vigil_max", vigil_max)
	cfg.set_value("meta", "best_depth", best_depth)
	cfg.set_value("meta", "wins", wins)
	cfg.set_value("achievements", "unlocked", achieved)
	cfg.set_value("achievements", "elite_kills", elite_kills)
	cfg.set_value("options", "shake", opt_shake)
	cfg.set_value("options", "fullscreen", opt_fullscreen)
	cfg.set_value("options", "flashes", opt_flashes)
	cfg.set_value("options", "hitstop", opt_hitstop)
	cfg.set_value("options", "speed", opt_speed)
	cfg.set_value("options", "hearts", opt_hearts)
	cfg.set_value("controls", "up_jump", opt_up_jump)
	cfg.set_value("controls", "binds", binds)
	cfg.save(SAVE_PATH)


func _drop_wax(at: Vector2, n: int) -> void:
	for i in n:
		pickups.append({"pos": at, "vel": Vector2(randf_range(-160, 160), randf_range(-520, -220)), "t": 0.0})


func _step_pickups(dt: float) -> void:
	var target := player.position + Vector2(0, -28)
	for pk in pickups:
		pk.t += dt
		var v: Vector2 = pk.vel
		var d: Vector2 = target - pk.pos
		if pk.t > 0.35 and d.length() < 220:
			v = v.lerp(d.normalized() * 900, minf(1, dt * 8))
		else:
			v.y += 1400 * dt
			v.x *= maxf(0, 1 - dt * 2)
		pk.vel = v
		var np: Vector2 = pk.pos + v * dt
		if world.is_solid(world.cell(np.x), world.cell(np.y)) and pk.t < 3:
			v.y = -absf(v.y) * 0.3
			pk.vel = v
			np = pk.pos
		pk.pos = np
		if d.length() < 22:
			pk.t = 99.0
			run_wax += (3 if has_rune("HUNGER") else 2) + (1 if "EMBER" in sets_done else 0)
			xp += 1
			if xp >= xp_need():
				xp -= xp_need()
				lvl += 1
				_open_draft()
	pickups = pickups.filter(func(pk): return pk.t < 20)


func _physics_process(dt: float) -> void:
	if smoke:
		_smoke(dt)
	if not opt_hitstop:
		hitstop = 0.0
	if hitstop > 0:
		hitstop -= dt
		return
	boxes.clear()
	# remove the dead here, never mid-loop while the player is still swinging
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].dead:
			enemies[i].queue_free()
			enemies.remove_at(i)
	frozen = hud.busy()
	if frozen:
		return
	if player.dead:
		dead_t += dt
		if randf() < dt * 20:
			fx.burst(player.position + Vector2(randf_range(-14, 14), -20 - randf() * 30), 1, Color("#f2b43a"), 60)
		if dead_t > 2.6 and dead_t - dt <= 2.6:
			_end_run()
		return
	run_time += dt
	_step_pickups(dt)
	if boss == null and not story_hold and depth < 16:
		depth_t += dt
	if depth_t >= depth_time:
		next_depth()
	for i in brazier_t.size():
		brazier_t[i] = maxf(0, brazier_t[i] - dt)
	_step_hexes(dt)
	spawn_t -= dt
	var alive := enemies.filter(func(e): return not e.dead).size()
	if spawn_t <= 0 and alive < (4 if boss else mini(22, 4 + depth * 2)) and world.portals.size() > 0:
		spawn_t = maxf(0.6, SPAWN_EVERY - depth * 0.15) * (0.75 if vigil >= 2 else 1.0)
		_spawn()


func next_depth() -> void:
	if boss != null or story_hold or depth >= 16:
		return
	depth_t = 0.0
	depth += 1
	shake(0.15, 4)
	var ch := chapter()
	if depth % 4 == 0:
		# the strepitus: the boss is revealed, then crashes down
		story_hold = true
		hud.play(Story.REVEALS[ch], _spawn_boss)
	elif depth % 4 == 1:
		story_hold = true
		_play_once("intro%d" % ch, Story.INTROS[ch], _enter_chapter)
	else:
		var sub: String = {2: "GLOOMWINGS JOIN", 3: "HEXERS APPEAR", 6: "BRUTES APPEAR"}.get(depth, "%d OF 15 STILL LIT" % (15 - candles_out()))
		hud.show_banner("DEPTH %s · A CANDLE GOES OUT" % roman(depth), sub)


func _enter_chapter() -> void:
	story_hold = false
	var ch: Dictionary = Story.CHAPTERS[chapter()]
	_load_arena(ch.map)
	hud.show_banner("DEPTH %s" % roman(depth), ch.name, 2.2)


func _spawn_boss() -> void:
	story_hold = false
	var ch := chapter()
	boss = Boss.new()
	boss.game = self
	# bosses scale by chapter, not by depth, so the last fight stays a fight
	boss.setup_boss(1.0 + ch * 0.5, ch)
	var x := clampf(player.position.x + (420.0 if player.position.x < world.size.x / 2 else -420.0), 120, world.size.x - 120)
	var y := player.position.y - 300
	if world.is_solid(world.cell(x), world.cell(y)) or world.is_solid(world.cell(x), world.cell(y - 100)):
		x = player.position.x
	boss.position = Vector2(x, y)
	add_child(boss)
	move_child(boss, world.get_index() + 1)
	boss.reset_physics_interpolation()
	enemies.append(boss)
	boss_untouched = true
	shake(0.7, 18)
	hitstop = 0.15
	hud.show_banner("DEPTH %s · STREPITUS" % roman(depth), "%s DESCENDS" % boss.boss_name, 2.4)


## After a boss: its last words, then the merchant. After Saint Umber: the finale and the dawn.
func _after_boss(ch: int) -> void:
	if ch == 3:
		hud.play(Story.ENDINGS[3], _victory)
	else:
		_play_once("ending%d" % ch, Story.ENDINGS[ch], _open_shop)


func _victory() -> void:
	won = true
	unlock("DAWN")
	if hidden_candle and vigil < 3:
		unlock("DAWN_UNAIDED")
	if vigil >= 5:
		unlock("VIGIL_V")
	_end_run()


func hp_mul() -> float:
	return (1.0 + (depth - 1) * 0.3) * (1.25 if vigil >= 1 else 1.0)


## Returns true if the hidden candle brought the player back.
func try_revive() -> bool:
	if not hidden_candle:
		return false
	hidden_candle = false
	unlock("NOT_YET")
	player.hp = ceilf(player.max_hp / 2)
	player.invuln = 2.2
	hitstop = 0.3
	shake(0.3, 10)
	hud.flash(Color.WHITE, 0.3)
	fx.ring(player.position, 220, Color("#f2b43a"))
	fx.burst(player.position + Vector2(0, -30), 24, Color("#f2b43a"), 220)
	hud.show_banner("NOT YET", "THE HIDDEN CANDLE RETURNS · IT WILL NOT RETURN AGAIN", 2.2)
	for e in enemies:
		if not e.dead and e.position.distance_to(player.position) < 200:
			hit_enemy(e, 3, Vector2(signf(e.position.x - player.position.x) * 420, -420))
	return true


func strike_braziers(box: Rect2) -> void:
	for i in world.braziers.size():
		var b: Vector2 = world.braziers[i]
		var dur := BRAZIER_TIME * (2.0 if has_rune("KINDLING") else 1.0) * (0.5 if vigil >= 4 else 1.0)
		if brazier_t[i] < dur - 0.5 and box.has_point(b):
			brazier_t[i] = dur
			fx.burst(b, 16, Color("#f2b43a"), 180)
			if has_rune("KINDLING"):
				heal(1)
			run_braziers += 1
			if run_braziers >= 10:
				unlock("LAMPLIGHTER")
			hud.show_banner("BRAZIER RELIT", "+15%% DAMAGE AND MORE LIGHT FOR %d S" % int(dur), 1.2)


func brazier_buff() -> bool:
	for i in brazier_t.size():
		if brazier_t[i] > 0:
			return true
	return false


func fire_hex(from: Vector2, to: Vector2) -> void:
	# lob in an arc that lands near the target in about 0.9 s
	var t := 0.9
	var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * 900 * t * t) / t)
	hexes.append({"pos": from, "vel": v, "life": 3.0})


## The forged throw spinning blades that fly flat along the floor.
func fire_blade(from: Vector2, dir: int) -> void:
	hexes.append({"pos": from, "vel": Vector2(dir * 520, 0), "life": 2.0, "blade": true})


func _step_hexes(dt: float) -> void:
	for h in hexes:
		var v: Vector2 = h.vel
		if not h.has("blade"):
			v.y += 900 * dt
		h.vel = v
		h.pos += v * dt
		h.life -= dt
		var hp_: Vector2 = h.pos
		if world.is_solid(world.cell(hp_.x), world.cell(hp_.y)):
			h.life = 0
			fx.burst(hp_, 8, Color("#ff8a5c") if h.has("blade") else Color("#b44dff"), 120)
		elif player.hurtbox().grow(6).has_point(hp_):
			h.life = 0
			player.take_hit(hp_.x)
	hexes = hexes.filter(func(h): return h.life > 0)


func _draw_hexes() -> void:
	for pk in pickups:
		var a := 0.5 + 0.5 * sin(pk.t * 10)
		hex_layer.draw_circle(pk.pos, 7, Color(0.25, 0.84, 0.77, 0.25 + 0.15 * a))
		hex_layer.draw_colored_polygon(PackedVector2Array([pk.pos + Vector2(0, -5), pk.pos + Vector2(4, 0), pk.pos + Vector2(0, 5), pk.pos + Vector2(-4, 0)]), Color("#3fd6c4"))
	var tk := Time.get_ticks_msec() / 1000.0
	for h in hexes:
		if h.has("blade"):
			var c: Vector2 = h.pos
			hex_layer.draw_circle(c, 11, Color(1, 0.55, 0.36, 0.25))
			for a in 3:
				var ang := tk * 18 + a * TAU / 3
				hex_layer.draw_line(c, c + Vector2(cos(ang), sin(ang)) * 10, Color("#ffd2b8"), 2.5)
			continue
		hex_layer.draw_circle(h.pos, 9, Color(0.7, 0.3, 1, 0.3))
		hex_layer.draw_circle(h.pos, 5, Color("#b44dff"))


func _make_light(parent: Node, pos: Vector2, scale_: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = pos
	l.texture_scale = scale_
	l.energy = energy
	l.color = Color(1, 0.75, 0.5)
	parent.add_child(l)
	return l


func _spawn() -> void:
	# portals near the player open first, so the fight follows you up the tower
	var ranked := world.portals.duplicate()
	ranked.sort_custom(func(a, b): return a.distance_to(player.position) < b.distance_to(player.position))
	var choices := ranked.filter(func(q): return q.distance_to(player.position) > 160)
	if choices.is_empty():
		return
	var at: Vector2 = choices[randi() % mini(3, choices.size())]
	var e := Enemy.new()
	e.game = self
	var q := randf()
	var k := Enemy.Kind.HOLLOW
	# each lower dungeon has its own enemy
	var own: Array = [Enemy.Kind.HOLLOW, Enemy.Kind.DROWNED, Enemy.Kind.FORGED, Enemy.Kind.SNUFFER]
	var ch := chapter()
	if ch > 0 and q < 0.22:
		k = own[ch]
	elif depth >= 3 and q < 0.34:
		k = Enemy.Kind.HEXER
	elif depth >= 2 and q < 0.52:
		k = Enemy.Kind.GLOOMWING
	elif depth >= 5 and q < 0.64:
		k = Enemy.Kind.BRUTE
	e.setup(k, hp_mul() * (1.3 if has_rune("TALLOW CROWN") else 1.0))
	if depth >= 3 and randf() < 0.04 + depth * 0.025:
		e.make_elite(["SWIFT", "SHIELDED", "VOLATILE"][randi() % 3])
		if smoke and not e.elite in smoke_elites:
			smoke_elites.append(e.elite)
			print("smoke test: first %s elite at depth %d" % [e.elite, depth])
	e.position = at + (Vector2.ZERO if k == Enemy.Kind.GLOOMWING else Vector2(0, 18))
	add_child(e)
	move_child(e, world.get_index() + 1)
	e.reset_physics_interpolation()
	enemies.append(e)
	fx.burst(at, 12, Color("#e5383b"), 140)


func hit_enemy(e: Enemy, dmg: float, kb: Vector2) -> void:
	if e.dead:
		return
	var guard := 0.5 if e.elite == "SHIELDED" and kb.x != 0 and signf(kb.x) == -e.facing else 1.0
	if guard < 1:
		fx.spark(e.position + Vector2(e.facing * 16, -30))
	e.hp -= dmg * damage_mul() * guard * (1.6 if e == boss and has_rune("TALLOW CROWN") else 1.0)
	e.knock(kb)
	hitstop = maxf(hitstop, 0.05)
	shake(0.1, 5)
	fx.shade_burst(e.position + Vector2(0, -28), signf(kb.x))
	if e.hp <= 0:
		e.dead = true
		kills += 1
		fx.burst(e.position + Vector2(0, -28), 18, Color("#0a0a0d"), 260)
		e.visible = false
		_drop_wax(e.position + Vector2(0, -28), 26 if e == boss else (4 if e.kind == Enemy.Kind.BRUTE else 2) * (3 if e.elite != "" else 1))
		if e.elite != "":
			elite_kills += 1
			if elite_kills >= 25:
				unlock("ELITE_HUNTER")
		if e.elite == "VOLATILE":
			fx.ring(e.position + Vector2(0, -20), 90, Color("#ff8a5c"))
			fx.burst(e.position + Vector2(0, -20), 20, Color("#ff8a5c"), 240)
			shake(0.2, 8)
			if e.position.distance_to(player.position) < 90:
				player.take_hit(e.position.x)
		if has_rune("SECOND WIND"):
			player.dash_cd = 0
			player.air_dash_used = false
		if has_rune("REQUIEM") and e != boss:
			fx.ring(e.position + Vector2(0, -28), 120, Color("#b44dff"))
			for o in enemies.duplicate():
				if o != e and not o.dead and o.position.distance_to(e.position) < 120:
					hit_enemy(o, 1, Vector2(signf(o.position.x - e.position.x) * 260, -260))
		if has_rune("BLOODLINE") and kills % 20 == 0:
			heal(1)
			hud.show_banner("BLOODLINE", "+20 HP", 1.0)
		if e == boss:
			bosses += 1
			var bi: int = (e as Boss).idx
			if bi < 3:
				unlock(["WARDEN_FREED", "KING_DROWNED", "JARL_SONG"][bi])
			if boss_untouched and not smoke:
				unlock("UNTOUCHED")
			story_hold = true
			get_tree().create_timer(1.6).timeout.connect(_after_boss.bind((e as Boss).idx))
			boss = null
			hitstop = 0.25
			shake(0.5, 14)
			fx.ring(e.position, 320, Color("#f2b43a"))
			hud.show_banner("%s FALLS" % (e as Boss).boss_name.replace("THE ", ""), "THE DESCENT GOES ON", 2.4)


## The killing blow: hit-stop, a red flash, the world slows and drains, the Wick crumbles to embers.
func on_player_dead() -> void:
	dead_t = 0.0
	shake(0.4, 14)
	hitstop = 0.25
	hud.flash(Color("#e5383b"), 0.35)
	Engine.time_scale = 0.5 * opt_speed
	fx.burst(player.position + Vector2(0, -30), 30, Color("#0a0a0d"), 120)
	fx.burst(player.position + Vector2(0, -30), 22, Color("#f2b43a"), 90)


func _end_run() -> void:
	Engine.time_scale = opt_speed
	_log_run()
	var kept := (run_wax if won else roundi(run_wax * 0.4)) + bosses * 50
	var before := earned
	bank += kept
	earned += kept
	best_depth = maxi(best_depth, depth)
	if won:
		wins += 1
		if vigil == vigil_max and vigil_max < RunData.VIGILS.size() - 1:
			vigil_max += 1
			unlocked_vigil = vigil_max
	_save_meta()
	var unlocked := "CHAIN SICKLE" if before < 400 and earned >= 400 else ""
	if unlocked_vigil > 0:
		unlocked = ("%s  ·  " % unlocked if unlocked != "" else "") + "VIGIL %s" % roman(unlocked_vigil)
		unlocked_vigil = 0
	var title := "THE DAWN RETURNS" if won else "EXTINGUISHED"
	var col := Color("#f2b43a") if won else Color("#e5383b")
	hud.open_summary({"title": title, "col": col, "won": won, "depth": depth, "time": run_time, "kills": kills, "bosses": bosses, "wax": run_wax, "kept": kept, "bank": bank, "unlocked": unlocked})


func shake(t: float, mag: float) -> void:
	if opt_shake <= 0:
		return
	shake_t = maxf(shake_t, t)
	shake_mag = maxf(shake_mag, mag * opt_shake)


func debug_box(r: Rect2, c: Color) -> void:
	if show_boxes:
		boxes.append([r, c])


func _process(dt: float) -> void:
	if shake_t > 0:
		shake_t -= dt
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_mag * clampf(shake_t * 6, 0, 1)
	else:
		camera.offset = Vector2.ZERO
		shake_mag = 0
	dbg.queue_redraw()
	hex_layer.queue_redraw()
	# the church darkens as candles go out; braziers you relight push it back locally
	var k := darkness()
	dark.color = Color(0.85, 0.8, 0.8).lerp(Color(0.09, 0.07, 0.08), k)
	if player.dead:
		var g := dark.color.get_luminance()
		dark.color = dark.color.lerp(Color(g, g, g), clampf(dead_t, 0, 1))
	var snuffed := 1.0
	for e in enemies:
		if e.kind == Enemy.Kind.SNUFFER and not e.dead and e.position.distance_to(player.position) < 300:
			snuffed = 0.7
	player_light.texture_scale = lerpf(4.5, 1.6, k) * (1.3 if brazier_buff() else 1.0) * snuffed
	player_light.energy = lerpf(0.5, 1.1, k)
	for i in brazier_lights.size():
		var lit := brazier_t[i] > 0
		brazier_lights[i].texture_scale = 3.2 if lit else 1.4
		brazier_lights[i].energy = (1.2 if lit else 0.35) + sin(Time.get_ticks_msec() * 0.012 + i) * 0.06


func _draw_debug() -> void:
	if not show_boxes:
		return
	dbg.draw_rect(player.hurtbox(), Color(0.3, 1, 0.5, 0.8), false, 1.5)
	for e in enemies:
		dbg.draw_rect(e.hurtbox(), Color(1, 0.3, 0.3, 0.8), false, 1.5)
	for b in boxes:
		dbg.draw_rect(b[0], b[1])


func is_bound(code: int) -> bool:
	for a in REBINDABLE:
		if keys_of(a).has(code):
			return true
	return false


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	# dev keys never fire while a menu is up or when you have bound that key to a move
	if k and k.pressed and not k.echo and rebinding == "" and not is_bound(k.physical_keycode) \
			and (not hud.busy() or k.physical_keycode in [KEY_F1, KEY_F2]):
		match k.physical_keycode:
			KEY_F1:
				show_debug = not show_debug
			KEY_F2:
				show_boxes = not show_boxes
			KEY_R:
				start(map_i)
			KEY_F3:
				next_depth()
			KEY_F4:
				# jump to the next boss
				if boss == null and not story_hold and not hud.busy():
					depth = mini(15, (depth / 4) * 4 + 3)
					next_depth()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				start(k.physical_keycode - KEY_1)


## Keyboard, mouse and controller bindings, created at runtime so project.godot stays readable.
## Two full hands work out of the box: WASD + Space / J / K (or the mouse), and arrows + Z / X / C.
## Keys are physical, so WASD stays under the same fingers on AZERTY and QWERTZ.
## The first key of jump, attack and dash (and the moves) can be rebound in Options > Controls.
const DEFAULT_KEYS := {
	"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_Z], "attack": [KEY_J, KEY_X, -MOUSE_BUTTON_LEFT], "dash": [KEY_SHIFT, KEY_K, KEY_C, -MOUSE_BUTTON_RIGHT],
	"pause": [KEY_ESCAPE, KEY_P], "confirm": [KEY_ENTER, KEY_KP_ENTER], "back": [KEY_BACKSPACE],
}
const REBINDABLE := ["left", "right", "up", "down", "jump", "attack", "dash"]
var binds := {} ## action -> its first key (a physical keycode, or -mouse button), when the player changed it
var opt_up_jump := true ## W / Up also jump
var rebinding := "" ## the action waiting for a key in Options > Controls


func keys_of(action: String) -> Array:
	var mine := binds.values()
	var d: Array = DEFAULT_KEYS[action]
	var first = binds.get(action, d[0])
	var out := [first]
	for k in d.slice(1):
		if k != first and not mine.has(k):
			out.append(k)
	return out


func key_name(k: int) -> String:
	match k:
		-MOUSE_BUTTON_LEFT: return "LMB"
		-MOUSE_BUTTON_RIGHT: return "RMB"
		-MOUSE_BUTTON_MIDDLE: return "MMB"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
	if k < 0:
		return "MB%d" % -k
	return OS.get_keycode_string(k).to_upper()


func key_label(action: String) -> String:
	return key_name(keys_of(action)[0])


func _setup_input() -> void:
	var pads := {"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "dash": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B], "pause": [JOY_BUTTON_START],
		"confirm": [JOY_BUTTON_A], "back": [JOY_BUTTON_B]}
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	var dpad := {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN}
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		InputMap.action_erase_events(action)
		for k in keys_of(action):
			if k < 0:
				var mb := InputEventMouseButton.new()
				mb.button_index = -k
				InputMap.action_add_event(action, mb)
			else:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)
		for b in pads.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if dpad.has(action):
			var db := InputEventJoypadButton.new()
			db.button_index = dpad[action]
			InputMap.action_add_event(action, db)
		if axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axes[action][0]
			jm.axis_value = axes[action][1]
			InputMap.action_add_event(action, jm)
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_RIGHT
	lt.axis_value = 1.0
	InputMap.action_add_event("dash", lt)
	# keyboard-only Up, so pushing the stick up never jumps
	if not InputMap.has_action("up_jump"):
		InputMap.add_action("up_jump")
	InputMap.action_erase_events("up_jump")
	if opt_up_jump:
		for k in keys_of("up"):
			if k >= 0:
				var uj := InputEventKey.new()
				uj.physical_keycode = k
				InputMap.action_add_event("up_jump", uj)


## Menus: Enter, jump or attack confirm (not the Up alias for jump).
func ok_pressed() -> bool:
	return Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")


## Catches the next key or mouse button for Options > Controls.
func _input(ev: InputEvent) -> void:
	if rebinding == "":
		return
	var code := 0
	if ev is InputEventKey and ev.pressed and not ev.echo:
		code = (ev as InputEventKey).physical_keycode
		if code == 0:
			code = (ev as InputEventKey).keycode
	elif ev is InputEventMouseButton and ev.pressed:
		code = -(ev as InputEventMouseButton).button_index
	else:
		return
	get_viewport().set_input_as_handled()
	var action := rebinding
	rebinding = ""
	if code != KEY_ESCAPE and code != KEY_ENTER and code != KEY_KP_ENTER:
		for a in binds.keys():
			if binds[a] == code and a != action:
				binds.erase(a)
		if code == DEFAULT_KEYS[action][0]:
			binds.erase(action)
		else:
			binds[action] = code
		_setup_input()
		_save_meta()
	# swallow the press so it does not also confirm the menu
	Input.action_release("confirm")
	call_deferred("open_controls")


func _notification(what: int) -> void:
	# alt-tabbing out pauses the run instead of letting it play on without you
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not smoke and player != null and not player.dead and not hud.busy():
		open_pause()
