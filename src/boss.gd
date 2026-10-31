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
##
## Each boss picks its moves by range (mirrors web/ai.js), and every wind-up
## paints its danger zone on the floor:
##   Warden  smash, a low chain sweep you jump (both sides when hurt), a double smash when hurt
##   King    leaps at where you're going, smash, hex rain when hurt
##   Jarl    a dash across the arena from range, smash, sweep, leaps when hurt
##   Umber   blinks behind you and slashes, leaps, hex rain, smash
## All of them punish standing on their head with an uppercut.

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
	var dy := p.position.y - position.y
	var enraged := hp < max_hp / 2
	var l := smarts()
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
			var want := 0.0 if absf(dx) < 70 else facing * walk_speed * (1.25 if enraged else 1.0)
			vel.x = move_toward(vel.x, want, 400 * dt)
			if t <= 0 and ground:
				var k := _pick(dx, dy, enraged)
				last = k
				_wind(k, enraged)
				if k == "leap":
					var T := 2 * 900 / gravity
					leap_to = Vector2(clampf(p.position.x + p.vel.x * T * (0.5 + 0.4 * l), 60, game.world.size.x - 60), position.y)
				elif k == "rain":
					var n := 7 if enraged else 5
					var c := p.position.x + clampf(p.vel.x * 0.5, -160, 160)
					rain_x.clear()
					rain_y = p.position.y
					for i in n:
						rain_x.append(clampf(c + (i - (n - 1) / 2.0) * 68, 40, game.world.size.x - 40))
		"wind":
			vel.x = move_toward(vel.x, 0, 1600 * dt)
			if next_move in ["sweep", "upper", "smash"] and t > wind_t * 0.5:
				facing = 1 if dx > 0 else -1
			if t <= 0:
				_do(next_move, dx, enraged)
		"leap":
			if t <= 0:
				state = "walk"
				t = 0.6
			elif ground and vel.y >= 0 and t < 1.85:
				state = "smash"
				t = 0.6
				game.shake(0.45, 16)
				game.fx.ring(position, 320, accent)
				_quake(position.x)
				if absf(p.position.x - position.x) < 120 and absf(p.position.y - position.y) < 70:
					p.take_hit(position.x)
				if idx == 3 or (enraged and idx == 1):
					var n := 5 if enraged else 3
					for k in n:
						var tgt := p.position + Vector2((k - (n - 1) / 2.0) * 90 + clampf(p.vel.x * 0.5, -120, 120), -30)
						game.fire_hex(position + Vector2(0, -120), tgt)
		"dash":
			vel.x = facing * 940
			if randf() < 0.8:
				game.fx.spark(position + Vector2(-facing * 20, -40))
			_zone(Rect2(position.x - 30, position.y - 120, 60, 120))
			if t <= 0 or wall == facing or position.x < 70 or position.x > game.world.size.x - 70:
				vel.x = facing * 120
				state = "smash"
				t = 0.7
				game.shake(0.2, 8)
		"smash":
			if t <= 0:
				if chain > 0:
					chain -= 1
					chained = true
					_wind("smash", true)
					t = 0.38
					wind_t = 0.38
				else:
					state = "walk"
					t = (randf_range(0.7, 1.2) if enraged else randf_range(1.1, 1.8)) - 0.3 * l
	vel.y = minf(vel.y + gravity * dt, 1400)
	game.world.move(self, dt, true)
	_step_quakes(dt)
	# contact damage while walking
	if state == "walk" and hurtbox().grow(-6).intersects(p.hurtbox()):
		p.take_hit(position.x)


const WIND := {"smash": 0.75, "sweep": 0.55, "leap": 0.45, "dash": 0.6, "slash": 0.4, "rain": 0.6, "upper": 0.32, "blink": 0.2}
var last := ""
var wind_t := 0.75
var chain := 0
var chained := false
var leap_to := Vector2.ZERO
var rain_x: Array[float] = []
var rain_y := 0.0


## Each boss has its own moves and picks them by range, never the same one twice running if it can help it.
func _pick(dx: float, dy: float, enraged: bool) -> String:
	var adx := absf(dx)
	if adx < 90 and dy < -70:
		return "upper"  # no standing on its head
	var o: Array = []
	match idx:
		0:
			o.append(["smash", 1.4])
			if adx < 240:
				o.append(["sweep", 2.2])
			if enraged:
				o.append(["leap", 0.8])
		1:
			o.append_array([["leap", 2.6], ["smash", 1.0]])
			if enraged:
				o.append(["rain", 1.4])
		2:
			o.append(["smash", 1.2])
			if adx > 170:
				o.append(["dash", 2.8])
			if enraged:
				o.append(["leap", 1.2])
			if adx < 200:
				o.append(["sweep", 1.0])
		_:
			o.append_array([["leap", 1.8], ["rain", 1.5], ["smash", 0.7]])
			if absf(dy) < 40:
				o.append(["blink", 2.4])
	var total := 0.0
	for q in o:
		if q[0] == last:
			q[1] *= 0.3
		total += q[1]
	var r := randf() * total
	for q in o:
		r -= q[1]
		if r <= 0:
			return q[0]
	return "smash"


func _wind(k: String, enraged: bool) -> void:
	state = "wind"
	next_move = k
	wind_t = WIND[k] * (0.72 if enraged else 1.0)
	t = wind_t


func _quake(x: float) -> void:
	quakes.append({"x": x, "y": position.y, "dir": -1, "t": 0.0})
	quakes.append({"x": x, "y": position.y, "dir": 1, "t": 0.0})


## hits the player if they're inside the world-space box
func _zone(r: Rect2) -> bool:
	var p := game.player
	if r.intersects(p.hurtbox()):
		p.take_hit(position.x)
		return true
	return false


func _do(k: String, dx: float, enraged: bool) -> void:
	var p := game.player
	match k:
		"smash":
			state = "smash"
			t = 0.5
			var sx := position.x + facing * 60
			game.shake(0.35, 12)
			game.fx.ring(Vector2(sx, position.y), 300, accent)
			_quake(sx)
			_zone(Rect2(sx - 70, position.y - 90, 140, 90))
			if enraged and idx == 0 and not chained:
				chain = 1  # the warden smashes twice when hurt
			chained = false
		"sweep":
			# a low sweep along the floor: jump it
			state = "smash"
			t = 0.55
			game.shake(0.2, 8)
			var sides := [-1, 1] if enraged else [facing]
			for sd in sides:
				for i in range(1, 7):
					game.fx.spark(position + Vector2(sd * i * 40, -16))
				_zone(Rect2(minf(position.x, position.x + sd * 250), position.y - 54, 250, 58))
		"leap":
			var T := 2 * 900 / gravity
			state = "leap"
			t = 2.0
			vel = Vector2(clampf((leap_to.x - position.x) / T, -660, 660), -900)
			ground = false
			if absf(vel.x) > 1:
				facing = 1 if vel.x > 0 else -1
		"dash":
			state = "dash"
			t = 0.55
			facing = 1 if dx > 0 else -1
		"upper":
			state = "smash"
			t = 0.5
			game.shake(0.25, 10)
			game.fx.ring(position + Vector2(0, -150), 90, accent)
			_zone(Rect2(position.x - 80, position.y - 300, 160, 300))
		"blink":
			# step out of the dark behind the player, then cut
			var wd := game.world
			for tx in [p.position.x - p.facing * 110, p.position.x + p.facing * 110]:
				if tx > 60 and tx < wd.size.x - 60 and (wd.is_solid(wd.cell(tx), wd.cell(position.y + 2)) or wd.is_one(wd.cell(tx), wd.cell(position.y + 2))) \
						and not wd.is_solid(wd.cell(tx), wd.cell(position.y - 40)) and not wd.is_solid(wd.cell(tx), wd.cell(position.y - 100)):
					game.fx.burst(position + Vector2(0, -60), 16, accent, 160)
					position.x = tx
					reset_physics_interpolation()
					vel.x = 0
					facing = 1 if p.position.x > position.x else -1
					game.fx.burst(position + Vector2(0, -60), 16, accent, 160)
					break
			_wind("slash", enraged)
		"slash":
			state = "smash"
			t = 0.45
			game.shake(0.2, 8)
			game.fx.ring(position + Vector2(facing * 70, -50), 80, accent)
			_zone(Rect2(minf(position.x, position.x + facing * 160), position.y - 130, 160, 134))
		"rain":
			state = "smash"
			t = 0.8
			var wd := game.world
			for x in rain_x:
				var y := p.position.y - 380
				while y < p.position.y - 80 and wd.is_solid(wd.cell(x), wd.cell(y)):
					y += World.TS
				game.hexes.append({"pos": Vector2(x, maxf(30, y)), "vel": Vector2(0, 40), "life": 3.0})
		_:
			state = "walk"
			t = 1.0


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
		# the danger zone of the coming move, brighter as it lands
		var kk := clampf(1.0 - t / wind_t, 0, 1)
		var zc := Color(0.9, 0.22, 0.23, 0.18 + 0.34 * kk)
		match next_move:
			"sweep":
				for sd in ([-1, 1] if hp < max_hp / 2 else [facing]):
					draw_rect(Rect2(minf(0, sd * 250), -54, 250, 54), zc)
			"slash":
				draw_rect(Rect2(minf(0, facing * 160), -130, 160, 130), zc)
			"upper":
				draw_rect(Rect2(-80, -300, 160, 300), zc)
			"dash":
				draw_rect(Rect2(minf(0, facing * 520), -110 * kk, 520, 110 * kk), zc)
			"smash":
				draw_rect(Rect2(facing * 60 - 70, -6, 140, 6), zc)
			"leap":
				_ellipse(leap_to - position, 120 * (0.4 + 0.6 * kk), zc)
			"rain":
				for x in rain_x:
					_ellipse(Vector2(x, rain_y) - position, 18, zc)
	if state == "leap":
		_ellipse(leap_to - position, 120, Color(0.9, 0.22, 0.23, 0.3))
	# shockwaves are drawn in local space
	for q in quakes:
		var qx: float = q.x + q.dir * q.t * quake_speed - position.x
		var qy: float = q.y - position.y
		var a: float = 1.0 - q.t / 1.1
		draw_line(Vector2(qx - 18, qy), Vector2(qx + 18, qy), Color(accent, a), 5)
		draw_line(Vector2(qx, qy), Vector2(qx, qy - 26 * a), Color(accent, a * 0.6), 3)


func _ellipse(c: Vector2, rx: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * 0.1 - 2))
	draw_colored_polygon(pts, col)
