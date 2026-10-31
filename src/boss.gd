class_name Boss
extends Enemy
## The Chain Warden, first boss. Enters on the strepitus: drops from above
## with a crash that shakes the whole arena. Pattern: walk toward you, wind up,
## smash the floor, which sends a shockwave running both ways along it. Jump
## the wave, punish the recovery. Below half health the wind-up gets shorter.
##
## The Hollow King (every second boss) uses the same body, bigger: instead of a
## standing smash he leaps at you and lands in a crash that sends waves both
## ways, and below half health he also casts a fan of hexes from the landing.
##
## The Ashen Jarl (chapter III) smashes like the Warden, but his forge-waves run
## faster and below half health he starts leaping too. Saint Umber (the end)
## leaps like the King, casts hexes on every landing, and wears a candle crown.

@export var walk_speed := 75.0
@export var quake_speed := 560.0

var state := "fall"
var t := 1.6
var landed := false
var quakes: Array = []
var king := false
var idx := 0
var boss_name := "THE CHAIN WARDEN"
var accent := Color("#e5383b")


func _ready() -> void:
	w = 44
	h = 120


## i is the chapter (0-3): Warden, Hollow King, Ashen Jarl, Saint Umber.
func setup_boss(hp_mul: float, i := 0) -> void:
	idx = i
	king = i == 1 or i == 3
	var ch: Dictionary = Story.CHAPTERS[i]
	boss_name = ch.boss
	accent = ch.col
	max_hp = [20.0, 26.0, 30.0, 20.0 * 2.2][i] * hp_mul
	hp = max_hp
	if i == 2:
		quake_speed = 720.0
		walk_speed = 95.0
	if king:
		w = 52
		h = 140


func _physics_process(dt: float) -> void:
	if game == null or dead or game.hitstop > 0 or game.frozen:
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
			if t <= 0 and (king or (idx == 2 and enraged and randf() < 0.5)):
				# leap at the player; the landing is the smash
				state = "leap"
				vel = Vector2(clampf(dx * 1.4, -520, 520), -900)
				ground = false
			elif t <= 0:
				state = "smash"
				t = 0.5
				var sx := position.x + facing * 60
				game.shake(0.35, 12)
				game.fx.ring(Vector2(sx, position.y), 300, accent)
				quakes.append({"x": sx, "y": position.y, "dir": -1, "t": 0.0})
				quakes.append({"x": sx, "y": position.y, "dir": 1, "t": 0.0})
		"leap":
			if ground and vel.y >= 0:
				state = "smash"
				t = 0.6
				game.shake(0.45, 16)
				game.fx.ring(position, 320, accent)
				quakes.append({"x": position.x, "y": position.y, "dir": -1, "t": 0.0})
				quakes.append({"x": position.x, "y": position.y, "dir": 1, "t": 0.0})
				if absf(dx) < 110 and absf(p.position.y - position.y) < 60:
					p.take_hit(position.x)
				if enraged or idx == 3:
					var n := 5 if enraged else 3
					for k in n:
						var tgt := p.position + Vector2((k - (n - 1) / 2.0) * 90, -30)
						game.fire_hex(position + Vector2(0, -120), tgt)
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
	if state == "leap":
		pose = {"lean": 0.3, "tilt": -0.1, "legs": [[0.9, -1.8], [1.2, -1.9]], "arms": [[-2.2, 0.4], [-2.6, 0.2]]}
	var sc := 1.55 if king else 1.3
	var J := Rig.build(pose, Vector2(0, -80 * sc / 1.3), facing, sc)
	var rim := Color(accent, 0.7)
	Rig.paint(self, J, body, Color("#1d1a20"), rim, accent)
	var hand: Vector2 = J.armF.e
	var ang: float = J.armF.can
	if idx == 0:
		# the warden's chain: a heavy weight on a swinging line
		var tip := hand + Vector2(cos(ang), sin(ang)) * 90
		draw_line(hand, tip, Color("#5a5560"), 3)
		draw_circle(tip, 14, body)
		draw_arc(tip, 14, 0, TAU, 20, rim, 2)
	else:
		# a long blade; the jarl's still glows from the forge
		Rig.blade(self, hand, ang, 96.0 if idx == 2 else 80.0, 1.0 if idx == 2 else 0.4)
	var hc: Vector2 = J.head
	var hr: float = J.head_r
	if idx == 1 or idx == 3:
		# the drowned crown, or Umber's crown of candles taken from the hearse
		var base := hc + Vector2(0, -hr * 0.8)
		draw_line(base + Vector2(-hr, 0), base + Vector2(hr, 0), Color("#5a524c") if idx == 1 else Color("#3a2f2a"), 4)
		var tk := Time.get_ticks_msec() / 1000.0
		for k in 5:
			var cx := base.x + (k - 2) * hr * 0.45
			if idx == 1:
				draw_line(Vector2(cx, base.y), Vector2(cx, base.y - 10), Color("#5a524c"), 3)
			else:
				draw_rect(Rect2(cx - 2, base.y - 12, 4, 12), Color("#e8dccb"))
				var fl := 1 + sin(tk * 12 + k * 1.9) * 0.18
				draw_circle(Vector2(cx, base.y - 16), 6 * fl, Color(0.7, 0.3, 1, 0.3))
				draw_circle(Vector2(cx, base.y - 16), 3 * fl, accent)
	if state == "wind":
		draw_arc(Vector2(facing * 60, 0), 40, PI, TAU, 24, Color(accent, 0.6), 3)
	# shockwaves are drawn in local space
	for q in quakes:
		var qx: float = q.x + q.dir * q.t * quake_speed - position.x
		var qy: float = q.y - position.y
		var a: float = 1.0 - q.t / 1.1
		draw_line(Vector2(qx - 18, qy), Vector2(qx + 18, qy), Color(accent, a), 5)
		draw_line(Vector2(qx, qy), Vector2(qx, qy - 26 * a), Color(accent, a * 0.6), 3)
