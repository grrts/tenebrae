class_name Game
extends Node2D
## Prototype root. Builds the scene in code so the repo stays text-only.

const MAPS := ["pit", "spire", "well", "blade", "throne"]
const SPAWN_EVERY := 2.4

var world: World
var fx: Fx
var player: Player
var camera: Camera2D
var overlay: DebugOverlay
var dbg: Node2D
var enemies: Array[Hollow] = []

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
	overlay = DebugOverlay.new()
	overlay.game = self
	add_child(overlay)
	start(map_i)


func start(i: int) -> void:
	map_i = i
	for e in enemies:
		e.queue_free()
	enemies.clear()
	if player:
		player.queue_free()
	for n in [fx, dbg, camera]:
		if n.get_parent():
			remove_child(n)
	world.load_map("res://maps/%s.txt" % MAPS[i])
	player = Player.new()
	player.game = self
	player.position = world.spawn
	add_child(player)
	add_child(fx)
	add_child(dbg)
	player.add_child(camera)
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
	spawn_t -= dt
	var alive := enemies.filter(func(e): return not e.dead).size()
	if spawn_t <= 0 and alive < 5 + kills / 8 and world.portals.size() > 0:
		spawn_t = SPAWN_EVERY
		_spawn()


func _spawn() -> void:
	# portals near the player open first, so the fight follows you up the tower
	var ranked := world.portals.duplicate()
	ranked.sort_custom(func(a, b): return a.distance_to(player.position) < b.distance_to(player.position))
	var choices := ranked.filter(func(q): return q.distance_to(player.position) > 160)
	if choices.is_empty():
		return
	var at: Vector2 = choices[randi() % mini(3, choices.size())]
	var e := Hollow.new()
	e.game = self
	e.position = at + Vector2(0, 18)
	e.max_hp = 3 + kills / 10
	e.hp = e.max_hp
	add_child(e)
	move_child(e, world.get_index() + 1)
	enemies.append(e)
	fx.burst(at, 12, Color("#e5383b"), 140)


func hit_enemy(e: Hollow, dmg: float, kb: Vector2) -> void:
	e.hp -= dmg
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
