class_name Boss
extends Enemy
## The Chain Warden, first boss. Enters on the strepitus: drops from above
## with a crash that shakes the whole arena. Pattern: walk toward you, wind up,
## smash the floor, which sends a shockwave running both ways along it. Jump
## the wave, punish the recovery. Below half health the wind-up gets shorter.

@export var walk_speed := 75.0
@export var quake_speed := 560.0

var state := "fall"
var t := 1.6
var landed := false
var quakes: Array = []


func _ready() -> void:
	w = 44
	h = 120


func setup_boss(hp_mul: float) -> void:
	max_hp = 20 * hp_mul
	hp = max_hp


func _physics_process(dt: float) -> void:
	if game == null or dead or game.hitstop > 0:
		return
	hit_t = maxf(0, hit_t - dt)
	t -= dt
	var p := game.player
	var dx := p.position.x - position.x
	var enraged := hp < max_hp / 2
	match state:
		"fall":
			if ground and not landed:
				landed = true
				game.shake(0.5, 16)
				game.fx.ring(position, 300, Color("#e5383b"))
				state = "walk"
				t = 1.2
		"walk":
			facing = 1 if dx > 0 else -1
			vel.x = move_toward(vel.x, facing * walk_speed, 400 * dt)
			if t <= 0 and ground:
				state = "wind"
				t = 0.5 if enraged else 0.75
		"wind":
			vel.x = move_toward(vel.x, 0, 1600 * dt)
			if t <= 0:
				state = "smash"
				t = 0.5
				var sx := position.x + facing * 60
				game.shake(0.35, 12)
				game.fx.ring(Vector2(sx, position.y), 300, Color("#e5383b"))
				quakes.append({"x": sx, "y": position.y, "dir": -1, "t": 0.0})
				quakes.append({"x": sx, "y": position.y, "dir": 1, "t": 0.0})
		"smash":
			if t <= 0:
				state = "walk"
				t = randf_range(1.2, 1.8) if enraged else randf_range(1.6, 2.4)
	vel.y = minf(vel.y + gravity * dt, 1400)
	game.world.move(self, dt, true)
	_step_quakes(dt)
	# contact damage while walking
	if state == "walk" and hurtbox().grow(-6).intersects(p.hurtbox()):
		p.take_hit(position.x)


func _step_quakes(dt: float) -> void:
	var p := game.player
	var wd := game.world
	for q in quakes:
		q.t += dt
		var qx: float = q.x + q.dir * q.t * quake_speed
		# a wave dies at a wall or where the floor ends
		if wd.is_solid(wd.cell(qx), wd.cell(q.y - 20)) or not wd.is_solid(wd.cell(qx), wd.cell(q.y + 20)):
			q.t = 9.0
			continue
		if randf() < 0.7:
			game.fx.spark(Vector2(qx, q.y - 2))
		if p.ground and absf(q.y - p.position.y) < 4 and absf(qx - p.position.x) < 24:
			p.take_hit(qx)
	quakes = quakes.filter(func(q): return q.t < 1.1)


func knock(_v: Vector2) -> void:
	hit_t = 0.12


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	var body := Color(1, 1, 1) if hit_t > 0 else Rig.COL_SHADE
	var pose: Dictionary
	match state:
		"wind":
			pose = {"lean": -0.2, "tilt": -0.1, "legs": [[-0.5, -0.2], [0.6, -0.5]], "arms": [[-1.2, 0.6], [-2.8, 0.3]]}
		"smash":
			pose = {"lean": 0.45, "tilt": 0.1, "legs": [[-0.7, -0.1], [0.9, -0.9]], "arms": [[-0.5, 0.5], [1.4, 0.1]]}
		_:
			pose = Rig.run_pose(position.x * 0.03)
			pose.lean = 0.2
	var J := Rig.build(pose, Vector2(0, -80), facing, 1.3)
	Rig.paint(self, J, body, Color("#1d1a20"), Color(0.9, 0.22, 0.23, 0.7), Color("#e5383b"))
	# the warden's chain: a heavy weight on a swinging line
	var hand: Vector2 = J.armF.e
	var ang: float = J.armF.can
	var tip := hand + Vector2(cos(ang), sin(ang)) * 90
	draw_line(hand, tip, Color("#5a5560"), 3)
	draw_circle(tip, 14, body)
	draw_arc(tip, 14, 0, TAU, 20, Color(0.9, 0.22, 0.23, 0.7), 2)
	if state == "wind":
		draw_arc(Vector2(facing * 60, 0), 40, PI, TAU, 24, Color(0.9, 0.22, 0.23, 0.6), 3)
	# shockwaves are drawn in local space
	for q in quakes:
		var qx: float = q.x + q.dir * q.t * quake_speed - position.x
		var qy: float = q.y - position.y
		var a := 1.0 - q.t / 1.1
		draw_line(Vector2(qx - 18, qy), Vector2(qx + 18, qy), Color(0.9, 0.22, 0.23, a), 5)
		draw_line(Vector2(qx, qy), Vector2(qx, qy - 26 * a), Color(0.9, 0.22, 0.23, a * 0.6), 3)
