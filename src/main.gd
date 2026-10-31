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
	start(map_i)


## Depth numbers read as Roman numerals, like psalm numbers in the service.
static func roman(n: int) -> String:
	var r := ""
	for pair in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= pair[0]:
			r += pair[1]
			n -= pair[0]
	return r


## Candles out on the hearse. After all 15 the stand relights and the count restarts.
func candles_out() -> int:
	return (depth - 1) % 15


## 0 at depth I, 1 when the church is nearly dark. Later cycles start darker.
func darkness() -> float:
	return clampf((candles_out() + floori((depth - 1) / 15.0) * 3) / 11.0, 0, 1)


func start(i: int) -> void:
	map_i = i
	for e in enemies:
		e.queue_free()
	enemies.clear()
	if player:
		player.queue_free()
	hexes.clear()
	if lights:
		lights.queue_free()
	for n in [fx, dbg, camera, hex_layer]:
		if n.get_parent():
			remove_child(n)
	world.load_map("res://maps/%s.txt" % MAPS[i])
	player = Player.new()
	player.game = self
	player.position = world.spawn
	add_child(player)
	add_child(fx)
	add_child(hex_layer)
	add_child(dbg)
	player.add_child(camera)
	lights = Node2D.new()
	add_child(lights)
	player_light = _make_light(player, Vector2(0, -30), 4.5, 1.0)
	brazier_lights.clear()
	brazier_t.clear()
	for b in world.braziers:
		brazier_lights.append(_make_light(lights, b, 1.5, 0.35))
		brazier_t.append(0.0)
	depth = 1
	depth_t = 0.0
	hidden_candle = true
	hud.show_banner("DEPTH I", "FIFTEEN CANDLES · NO END", 1.8)
	camera.position = Vector2(0, -60)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.size.x)
	camera.limit_bottom = int(world.size.y)
	camera.reset_smoothing()
	kills = 0
	spawn_t = 1.0
	dead_t = 0.0
	hitstop = 0.0


func _physics_process(dt: float) -> void:
	if hitstop > 0:
		hitstop -= dt
		return
	boxes.clear()
	# remove the dead here, never mid-loop while the player is still swinging
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].dead:
			enemies[i].queue_free()
			enemies.remove_at(i)
	if player.dead:
		dead_t += dt
		if dead_t > 1.6:
			start(map_i)
		return
	depth_t += dt
	if depth_t >= depth_time:
		next_depth()
	for i in brazier_t.size():
		brazier_t[i] = maxf(0, brazier_t[i] - dt)
	_step_hexes(dt)
	spawn_t -= dt
	var alive := enemies.filter(func(e): return not e.dead).size()
	if spawn_t <= 0 and alive < mini(22, 4 + depth * 2) and world.portals.size() > 0:
		spawn_t = maxf(0.6, SPAWN_EVERY - depth * 0.15)
		_spawn()


func next_depth() -> void:
	depth_t = 0.0
	depth += 1
	if candles_out() == 0:
		hud.show_banner("DEPTH %s" % roman(depth), "THE CANDLES ARE RELIT · THE DARK COMES FASTER", 2.2)
	else:
		var sub: String = {2: "GLOOMWINGS JOIN", 3: "HEXERS APPEAR", 5: "BRUTES APPEAR"}.get(depth, "ENEMIES +%d%% HP" % roundi((hp_mul() - 1) * 100))
		hud.show_banner("DEPTH %s · A CANDLE GOES OUT" % roman(depth), sub)
	shake(0.15, 4)


func hp_mul() -> float:
	return 1.0 + (depth - 1) * 0.3


## Returns true if the hidden candle brought the player back.
func try_revive() -> bool:
	if not hidden_candle:
		return false
	hidden_candle = false
	player.hp = ceilf(player.max_hp / 2)
	player.invuln = 2.2
	hitstop = 0.2
	shake(0.3, 10)
	fx.ring(player.position, 220, Color("#f2b43a"))
	hud.show_banner("THE HIDDEN CANDLE", "RETURNED ONCE · IT WILL NOT RETURN AGAIN", 2.0)
	for e in enemies:
		if not e.dead and e.position.distance_to(player.position) < 200:
			hit_enemy(e, 3, Vector2(signf(e.position.x - player.position.x) * 420, -420))
	return true


func strike_braziers(box: Rect2) -> void:
	for i in world.braziers.size():
		var b: Vector2 = world.braziers[i]
		if brazier_t[i] < BRAZIER_TIME - 0.5 and box.has_point(b):
			brazier_t[i] = BRAZIER_TIME
			fx.burst(b, 16, Color("#f2b43a"), 180)
			hud.show_banner("BRAZIER RELIT", "+15% DAMAGE AND MORE LIGHT FOR 20 S", 1.2)


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


func _step_hexes(dt: float) -> void:
	for h in hexes:
		var v: Vector2 = h.vel
		v.y += 900 * dt
		h.vel = v
		h.pos += v * dt
		h.life -= dt
		var hp_: Vector2 = h.pos
		if world.is_solid(world.cell(hp_.x), world.cell(hp_.y)):
			h.life = 0
			fx.burst(hp_, 8, Color("#b44dff"), 120)
		elif player.hurtbox().grow(6).has_point(hp_):
			h.life = 0
			player.take_hit(hp_.x)
	hexes = hexes.filter(func(h): return h.life > 0)


func _draw_hexes() -> void:
	for h in hexes:
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
	if depth >= 3 and q < 0.14:
		k = Enemy.Kind.HEXER
	elif depth >= 2 and q < 0.34:
		k = Enemy.Kind.GLOOMWING
	elif depth >= 5 and q < 0.48:
		k = Enemy.Kind.BRUTE
	e.setup(k, hp_mul())
	e.position = at + (Vector2.ZERO if k == Enemy.Kind.GLOOMWING else Vector2(0, 18))
	add_child(e)
	move_child(e, world.get_index() + 1)
	enemies.append(e)
	fx.burst(at, 12, Color("#e5383b"), 140)


func hit_enemy(e: Enemy, dmg: float, kb: Vector2) -> void:
	e.hp -= dmg * (BRAZIER_DMG if brazier_buff() else 1.0)
	e.knock(kb)
	hitstop = maxf(hitstop, 0.05)
	shake(0.1, 5)
	fx.shade_burst(e.position + Vector2(0, -28), signf(kb.x))
	if e.hp <= 0:
		e.dead = true
		kills += 1
		fx.burst(e.position + Vector2(0, -28), 18, Color("#0a0a0d"), 260)
		e.visible = false


func on_player_dead() -> void:
	dead_t = 0.0
	shake(0.4, 14)


func shake(t: float, mag: float) -> void:
	shake_t = maxf(shake_t, t)
	shake_mag = maxf(shake_mag, mag)


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
	player_light.texture_scale = lerpf(4.5, 1.6, k) * (1.3 if brazier_buff() else 1.0)
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


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_F1:
				show_debug = not show_debug
			KEY_F2:
				show_boxes = not show_boxes
			KEY_R:
				start(map_i)
			KEY_F3:
				next_depth()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				start(k.physical_keycode - KEY_1)


## Keyboard + controller bindings, created at runtime so project.godot stays readable.
func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "down": [KEY_S, KEY_DOWN], "up": [KEY_W, KEY_UP],
		"jump": [KEY_SPACE, KEY_Z], "attack": [KEY_J, KEY_X], "dash": [KEY_K, KEY_SHIFT, KEY_C],
	}
	var pads := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "dash": JOY_BUTTON_RIGHT_SHOULDER}
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	var dpad := {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if pads.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pads[action]
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
