class_name Enemy
extends Actor
## All four regular enemy types share one class; `kind` picks the behaviour.
##   hollow     basic grunt: shuffles toward you, walks off ledges, hops short steps
##   gloomwing  flyer: ignores tiles, drifts toward you, then dives; dies in one hit
##   brute      heavy: can't jump, holds its floor, long telegraphed club swing
##   hexer      caster: stays put and lobs hexes in an arc; you climb to reach it
## One enemy belongs to each lower dungeon:
##   drowned    (the Well) crouches, then pounces at you across the floor
##   forged     (the Bladeworks) throws spinning blades straight along its floor
##   snuffer    (the Throne) blinks next to you and slashes; near it your light shrinks
##
## The brain on top (mirrors web/ai.js): ground enemies climb to your platform and
## drop down to you, sidestep your swings (more often the deeper you go), and a
## crowded side sends one vaulting over you so you get surrounded. Hollows lunge,
## brutes charge from range, hexers lead their shots and hop away when you close
## in, forged aim their blades, and gloomwings circle behind you before diving at
## where you're going. A few attack tokens stop everyone striking at once, and
## every wind-up shows a red mark over the enemy, so the danger stays readable.

enum Kind { HOLLOW, GLOOMWING, BRUTE, HEXER, DROWNED, FORGED, SNUFFER }

const STATS := {
	Kind.HOLLOW: {"hp": 3.0, "speed": 120.0, "w": 18.0, "h": 52.0, "scale": 0.6},
	Kind.GLOOMWING: {"hp": 1.0, "speed": 170.0, "w": 26.0, "h": 24.0, "scale": 0.5},
	Kind.BRUTE: {"hp": 9.0, "speed": 70.0, "w": 30.0, "h": 70.0, "scale": 0.85},
	Kind.HEXER: {"hp": 2.0, "speed": 0.0, "w": 18.0, "h": 52.0, "scale": 0.6},
	Kind.DROWNED: {"hp": 4.0, "speed": 90.0, "w": 20.0, "h": 50.0, "scale": 0.62},
	Kind.FORGED: {"hp": 4.0, "speed": 55.0, "w": 22.0, "h": 56.0, "scale": 0.7},
	Kind.SNUFFER: {"hp": 3.0, "speed": 0.0, "w": 18.0, "h": 56.0, "scale": 0.66},
}

@export var gravity := 2100.0

var game: Game
var kind := Kind.HOLLOW
var speed := 120.0
var scale_k := 0.6
var dashed := -1
var hit_t := 0.0
var stun := 0.0
var hop_cd := 0.0
var ph := 0.0
# action timer: dive for gloomwings, swing wind-up for brutes, cast for hexers
var act := 0.0
var act_cd := 1.5
var dive_dir := Vector2.ZERO
# "" or SWIFT (60% faster), SHIELDED (half damage from the front), VOLATILE (bursts on death)
var elite := ""
# the brain: "" or hop, vault, wind, lunge, charge, recover
var mode := ""
var next_move := ""
var tele := 0.0
var tele_max := 1.0
var mt := 0.0
var air_t := 0.0
var ai_cd := 1.0
var dodge_cd := 0.0
var jump_cd := 0.0
var drop_t := 0.0
var side_off := 0.0
var feinted := false
# one vault at a time across the whole pack
static var vault_at := 0.0


func setup(k: Kind, hp_mul: float) -> void:
	kind = k
	var s: Dictionary = STATS[k]
	speed = s.speed
	w = s.w
	h = s.h
	scale_k = s.scale
	max_hp = s.hp * hp_mul
	hp = max_hp
	ph = randf() * TAU
	act_cd = randf_range(1.0, 2.5)
	ai_cd = randf_range(0.6, 1.6)


## From depth III some enemies come as elites: more health, a gold ring and one twist.
func make_elite(kind_name: String) -> void:
	elite = kind_name
	max_hp *= 2.2
	hp = max_hp
	scale_k *= 1.18
	h *= 1.18
	if elite == "SWIFT":
		speed *= 1.6


func _physics_process(dt: float) -> void:
	if game == null or dead or game.hitstop > 0 or game.frozen:
		return
	if elite == "SWIFT":
		# swift elites think faster too
		act_cd = maxf(0, act_cd - dt * 0.6)
	hit_t = maxf(0, hit_t - dt)
	stun = maxf(0, stun - dt)
	hop_cd = maxf(0, hop_cd - dt)
	act_cd = maxf(0, act_cd - dt)
	if kind == Kind.GLOOMWING:
		_fly(dt)
		return
	if not _brain(dt):
		match kind:
			Kind.BRUTE:
				_brute(dt)
			Kind.HEXER:
				_hexer(dt)
			Kind.DROWNED:
				_drowned(dt)
			Kind.FORGED:
				_forged(dt)
			Kind.SNUFFER:
				_snuffer(dt)
			_:
				_walk(dt, speed, true)
	vel.y = minf(vel.y + gravity * dt, 1400)
	game.world.move(self, dt, drop_t > 0)
	ph += absf(vel.x) * dt * 0.04
	_touch()


# ---------- the brain ----------

## 0 at depth I, 1 by depth XIII
func smarts() -> float:
	return clampf((game.depth - 1) / 12.0, 0, 1)


func _rate() -> float:
	return sqrt(1.6) if elite == "SWIFT" else 1.0


static func busy_count(g: Game) -> int:
	var n := 0
	for o in g.enemies:
		if not o.dead and not (o is Boss) and o.mode in ["wind", "lunge", "charge"]:
			n += 1
	return n


func _tokens() -> int:
	return 2 + int(game.depth / 5.0)


func _side_count(s: int) -> int:
	var p := game.player
	var n := 0
	for o in game.enemies:
		if not o.dead and not (o is Boss) and o.kind != Kind.GLOOMWING and signf(o.position.x - p.position.x) == s \
				and absf(o.position.x - p.position.x) < 260 and absf(o.position.y - p.position.y) < 50:
			n += 1
	return n


func _floor_at(x: float, y: float) -> bool:
	var wd := game.world
	return wd.is_solid(wd.cell(x), wd.cell(y + 2)) or wd.is_one(wd.cell(x), wd.cell(y + 2))


func _wall_at(x: float, y: float) -> bool:
	return game.world.is_solid(game.world.cell(x), game.world.cell(y))


## no ceiling between the head and a target height
func _headroom(to_y: float, dir: float) -> bool:
	var wd := game.world
	var c := wd.cell(position.x + dir * 16)
	var r := wd.cell(position.y - h - 4)
	while r >= wd.cell(to_y - h):
		if wd.is_solid(c, r):
			return false
		r -= 1
	return true


func _body_hit(r: Rect2) -> bool:
	var p := game.player
	if r.intersects(p.hurtbox()):
		p.take_hit(position.x)
		return true
	return false


## true when the brain drove this frame
func _brain(dt: float) -> bool:
	var p := game.player
	var l := smarts()
	var dx := p.position.x - position.x
	var dy := p.position.y - position.y
	var adx := absf(dx)
	var s := 1 if position.x > p.position.x else -1
	ai_cd -= dt * _rate()
	dodge_cd -= dt
	jump_cd -= dt
	drop_t = maxf(0, drop_t - dt)
	if stun > 0 and kind != Kind.BRUTE:
		# a hit staggers them out of whatever they were doing
		if mode != "vault":
			mode = ""
		tele = 0
		return false
	if mode != "":
		return _brain_act(dt, dx, l)
	if kind == Kind.HEXER:
		return _hexer_brain(dt, dx, dy, l)
	if not ground or act > 0:
		return false
	# sidestep the player's swing, read in its first moments
	if p.atk != null and p.atk.t < 0.09 and dodge_cd <= 0 and (position.x - p.position.x) * p.facing > -10 \
			and adx < p.reach + 60 and absf(dy) < 60 and kind != Kind.BRUTE:
		dodge_cd = 1.4
		if randf() < 0.14 + l * 0.36 + (0.2 if elite == "SWIFT" else 0.0) and _floor_at(position.x + s * 60, position.y):
			vel = Vector2(s * 430, -430)
			ground = false
			mode = "hop"
			mt = 0.5
			ai_cd = minf(ai_cd, 0.25)
			return true
	# climb to the player's platform
	if kind != Kind.BRUTE and kind != Kind.SNUFFER and jump_cd <= 0 and dy < -56 and dy > -270 and adx < 240 and p.ground and _headroom(p.position.y, signf(dx)):
		var vy := -minf(1060, sqrt(2 * gravity * (-dy + 34)))
		var t := -vy / gravity
		vel = Vector2(clampf(dx / (t * 1.7), -320, 320), vy)
		ground = false
		jump_cd = randf_range(0.9, 1.5)
		facing = 1 if dx > 0 else -1
		return true
	# or drop through a bridge to reach them
	if dy > 56 and adx < 220 and on_one_way and jump_cd <= 0:
		drop_t = 0.25
		vel.y = 60
		ground = false
		jump_cd = 0.8
		return true
	if absf(dy) < 44:
		# surround: with the player's back open and this side crowded, vault over them
		if (kind == Kind.HOLLOW or kind == Kind.DROWNED) and game.depth >= 2 and adx < 170 and (vault_at <= game.run_time or vault_at > game.run_time + 5.0) \
				and _side_count(s) >= 2 and _side_count(-s) == 0 and _floor_at(p.position.x - s * 80, p.position.y) \
				and not _wall_at(p.position.x - s * 80, p.position.y - 30) and _headroom(position.y - 140, -s):
			vault_at = game.run_time + randf_range(2.2, 3.4) - l
			var T := 2 * 760 / gravity
			vel = Vector2(clampf((p.position.x - s * 80 - position.x) / T, -420, 420), -760)
			ground = false
			mode = "vault"
			mt = T + 0.2
			facing = -s
			return true
		if ai_cd <= 0 and busy_count(game) < _tokens():
			if kind == Kind.HOLLOW and adx > 28 and adx < 175:
				return _windup("lunge", (0.36 - 0.1 * l) / _rate(), dx)
			if kind == Kind.BRUTE and adx > 200 and adx < 560 and game.depth >= 6 and stun <= 0:
				return _windup("charge", 0.65 / _rate(), dx)
			if kind == Kind.FORGED and adx < 640:
				return _windup("throw", 0.45 / _rate(), dx)
	elif kind == Kind.FORGED and ai_cd <= 0 and adx < 520 and dy > -260 and dy < 0 and busy_count(game) < _tokens():
		return _windup("throw", 0.45 / _rate(), dx)
	# hold a little space instead of piling into one spot
	if kind == Kind.HOLLOW and adx < 60 and adx > 26 and ai_cd > 0.4:
		vel.x = move_toward(vel.x, 0, 900 * dt)
		return true
	# the forged only throw through the brain now
	if kind == Kind.FORGED:
		_walk(dt, speed, false)
		return true
	return false


func _windup(k: String, t: float, dx: float) -> bool:
	mode = "wind"
	next_move = k
	tele = t
	tele_max = t
	facing = 1 if dx > 0 else -1
	vel.x *= 0.3
	if k == "throw":
		act = t
	return true


func _brain_act(dt: float, dx: float, l: float) -> bool:
	var p := game.player
	match mode:
		"hop", "vault":
			mt -= dt
			air_t += dt
			if mode == "vault" and vel.y > 0:
				_body_hit(hurtbox().grow(-4))
			if mt <= 0 or (ground and air_t > 0.12):
				mode = ""
				air_t = 0
			return not ground
		"wind":
			tele -= dt
			vel.x = move_toward(vel.x, 0, 1600 * dt)
			if tele > tele_max * 0.5 and next_move != "charge":
				facing = 1 if dx > 0 else -1
			if tele > 0:
				return true
			tele = 0
			match next_move:
				"lunge":
					var lead := clampf(p.vel.x * 0.18 * l, -60, 60)
					var vx := clampf((dx + lead) * 3.6, -600, 600)
					vel = Vector2(vx if absf(vx) > 1 else facing * 400.0, -230)
					ground = false
					mode = "lunge"
					mt = 0.42
				"charge":
					mode = "charge"
					mt = 1.1
					vel.x = facing * 560 * _rate()
				"throw":
					act = 0
					_throw_blade(l)
					mode = "recover"
					mt = 0.25
			return true
		"lunge":
			mt -= dt
			if _body_hit(hurtbox()):
				mt = minf(mt, 0.05)
			if mt <= 0 or (ground and mt < 0.3):
				mode = ""
				ai_cd = randf_range(1.5, 2.3) - 0.7 * l
			return not ground
		"charge":
			mt -= dt
			vel.x = facing * 560 * _rate()
			if randf() < 0.5:
				game.fx.spark(position + Vector2(-facing * 14, -6))
			if _body_hit(hurtbox().grow(2)):
				mt = 0
			if mt <= 0 or wall == facing or not _floor_at(position.x + facing * 26, position.y):
				mode = "recover"
				mt = 0.6
				vel.x = 0
				game.shake(0.1, 5)
			return true
		"recover":
			mt -= dt
			vel.x = move_toward(vel.x, 0, 1600 * dt)
			if mt <= 0:
				mode = ""
				ai_cd = randf_range(1.6, 2.4) - 0.6 * l
			return true
	mode = ""
	return false


func _throw_blade(l: float) -> void:
	var p := game.player
	var from := position + Vector2(facing * 16, -34)
	var sp := 540.0
	var aim := p.position + Vector2(0, -28)
	var t := from.distance_to(aim) / sp
	aim.x += clampf(p.vel.x * t * (0.4 + 0.5 * l), -200, 200)
	if not p.ground:
		aim.y += clampf(p.vel.y * t * 0.4, -120, 120)
	var dir := (aim - from).normalized()
	var same_floor := absf(p.position.y - position.y) < 44
	if same_floor:
		dir = Vector2(facing, 0)
	game.hexes.append({"pos": from, "vel": dir * sp, "life": 1.8, "blade": true})
	if game.depth >= 10 and same_floor:
		# a high blade too, so a jump alone won't clear both
		game.hexes.append({"pos": from + Vector2(0, -34), "vel": Vector2(facing * sp * 0.85, 0), "life": 2.0, "blade": true})


func _lob(from: Vector2, to: Vector2, t: float) -> void:
	game.hexes.append({"pos": from, "vel": Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * 900 * t * t) / t), "life": 3.0})


func _hexer_brain(dt: float, dx: float, dy: float, l: float) -> bool:
	var p := game.player
	if ground:
		vel.x = move_toward(vel.x, 0, 900 * dt)
	facing = 1 if dx > 0 else -1
	if not ground or stun > 0:
		return true
	# keep its distance: hop away when the player closes in
	if absf(dx) < 150 and absf(dy) < 60 and hop_cd <= 0 and _floor_at(position.x - facing * 90, position.y) and not _wall_at(position.x - facing * 40, position.y - 30):
		hop_cd = 2.6 - l
		vel = Vector2(-facing * 380, -560)
		ground = false
		return true
	if tele > 0:
		tele -= dt
		if tele <= 0:
			var t := 0.9
			var from := position + Vector2(facing * 14, -70)
			var lead := clampf(p.vel.x * t * (0.45 + 0.5 * l), -260, 260)
			var ty := p.position.y - 28
			_lob(from, Vector2(p.position.x + lead, ty), t)
			if game.depth >= 7:
				# bracket: one where you stand, one past where you're heading
				var dir := signf(lead) if absf(lead) > 1 else float(p.facing)
				_lob(from, Vector2(p.position.x, ty), t * 1.1)
				_lob(from, Vector2(p.position.x + lead * 1.8 + dir * 50, ty), t * 0.95)
		return true
	if act_cd <= 0 and position.distance_to(p.position) < 620:
		tele = 0.45
		tele_max = 0.45
		act_cd = randf_range(2.0, 3.0) - 0.5 * l
	return true


func _walk(dt: float, spd: float, can_hop: bool) -> void:
	var p := game.player
	var dx := p.position.x - position.x
	var dy := p.position.y - position.y
	if stun > 0:
		vel.x = move_toward(vel.x, 0, 600 * dt)
		return
	var dir := signf(dx) if absf(dx) > 12 else 0.0
	# when the player is far above, keep walking to find a way up instead of jittering below them
	if dy < -120 and absf(dx) < 200:
		dir = facing
	vel.x = move_toward(vel.x, dir * spd, 900 * dt)
	if dir != 0:
		facing = int(dir)
	if can_hop and ground and wall == facing and hop_cd <= 0:
		vel.y = -620
		hop_cd = 0.8


func _fly(dt: float) -> void:
	var p := game.player
	var target := p.position + Vector2(0, -40)
	if stun > 0:
		vel = vel.move_toward(Vector2.ZERO, 900 * dt)
		act = 0
		tele = 0
	elif act > 0:
		act -= dt
		vel = dive_dir * 560 * _rate()
		if act <= 0:
			act_cd = randf_range(1.5, 2.6) - 0.6 * smarts()
	elif tele > 0:
		# shudder, then dive at where the player is going
		tele -= dt
		vel = vel.move_toward(Vector2.ZERO, 1200 * dt)
		position.x += randf_range(-2, 2)
		if tele <= 0:
			var l := smarts()
			var aim := target + Vector2(clampf(p.vel.x * 0.3 * (0.5 + 0.5 * l), -120, 120), 0.0 if p.ground else clampf(p.vel.y * 0.15, -80, 80))
			dive_dir = (aim - position).normalized()
			act = 0.5
	else:
		# circle to the player's back, each wing on its own slot
		side_off = lerpf(side_off, -p.facing * (70.0 + float(get_instance_id() % 5) * 14.0), 0.02 + 0.03 * smarts())
		var hover := target + Vector2(side_off, -110)
		vel = vel.move_toward((hover - position).normalized() * speed, 600 * dt)
		vel.y += sin(ph * 3) * 40
		if act_cd <= 0 and position.distance_to(target) < 230 and busy_count(game) < _tokens() + 1:
			tele = 0.32
			tele_max = 0.32
			# the rest of the flock joins in, a beat apart
			var n := 0
			for o in game.enemies:
				if n < 2 and o != self and not o.dead and o.kind == Kind.GLOOMWING and o.tele <= 0 and o.act <= 0 and game.depth >= 4 and o.position.distance_to(position) < 240:
					n += 1
					o.tele = 0.32 + 0.14 * n
					o.tele_max = o.tele
	facing = 1 if p.position.x > position.x else -1
	position += vel * dt
	position = position.clamp(Vector2(20, 20), game.world.size - Vector2(20, 20))
	ph += dt
	_touch()


func _brute(dt: float) -> void:
	var p := game.player
	var near := absf(p.position.x - position.x) < 90 and absf(p.position.y - position.y) < 50
	if act > 0:
		# wind-up then swing: the hit lands when act crosses 0.15
		var before := act
		act -= dt
		vel.x = move_toward(vel.x, 0, 1200 * dt)
		if before > 0.15 and act <= 0.15:
			var box := Rect2(position.x + (0.0 if facing > 0 else -110.0), position.y - 70, 110, 70)
			game.debug_box(box, Color(1, 0.2, 0.2, 0.4))
			game.shake(0.12, 6)
			game.fx.ring(position + Vector2(facing * 60, 0), 70, Color("#e5383b"))
			if box.intersects(p.hurtbox()):
				p.take_hit(position.x)
		return
	if near and act_cd <= 0 and stun <= 0:
		act = 0.75
		act_cd = 2.2
		facing = 1 if p.position.x > position.x else -1
		return
	_walk(dt, speed, false)


func _hexer(dt: float) -> void:
	var p := game.player
	vel.x = move_toward(vel.x, 0, 900 * dt)
	facing = 1 if p.position.x > position.x else -1
	if stun > 0:
		return
	if act > 0:
		act -= dt
		if act <= 0:
			game.fire_hex(position + Vector2(facing * 10, -40), p.position + Vector2(0, -30))
		return
	if act_cd <= 0 and position.distance_to(p.position) < 620:
		act = 0.5
		act_cd = randf_range(2.0, 3.0)


func _drowned(dt: float) -> void:
	var p := game.player
	var dx := p.position.x - position.x
	if act > 0:
		# crouched, about to spring
		act -= dt
		vel.x = move_toward(vel.x, 0, 1600 * dt)
		if act <= 0:
			# pounce at where the player is going
			vel = Vector2(clampf((dx + clampf(p.vel.x * 0.35, -140, 140)) * 1.6, -600, 600), -640)
			ground = false
		return
	if ground and stun <= 0 and act_cd <= 0 and absf(dx) < 300 and absf(p.position.y - position.y) < 80:
		act = 0.4
		act_cd = randf_range(2.0, 2.8)
		facing = 1 if dx > 0 else -1
		return
	if ground:
		_walk(dt, speed, true)


func _forged(dt: float) -> void:
	var p := game.player
	if act > 0:
		act -= dt
		vel.x = move_toward(vel.x, 0, 1200 * dt)
		if act <= 0:
			game.fire_blade(position + Vector2(facing * 16, -34), facing)
		return
	if stun <= 0 and act_cd <= 0 and absf(p.position.y - position.y) < 50 and absf(p.position.x - position.x) < 640:
		facing = 1 if p.position.x > position.x else -1
		act = 0.45
		act_cd = randf_range(2.2, 3.2)
		return
	_walk(dt, speed, false)


func _snuffer(dt: float) -> void:
	var p := game.player
	vel.x = move_toward(vel.x, 0, 900 * dt)
	if stun > 0:
		return
	if act > 0:
		# at the Throne they feint: turn to face the blink and they blink again to your back
		if act > 0.2 and not feinted and game.depth >= 13 and signf(position.x - p.position.x) == p.facing and randf() < dt * 6:
			feinted = true
			var to := p.position + Vector2(-p.facing * 70, 0)
			var wd := game.world
			if not wd.is_solid(wd.cell(to.x), wd.cell(to.y - 20)) and wd.is_solid(wd.cell(to.x), wd.cell(to.y + 20)):
				game.fx.burst(position + Vector2(0, -28), 10, Color("#b44dff"), 120)
				position = to
				reset_physics_interpolation()
				facing = -p.facing
				act = 0.45
				game.fx.burst(position + Vector2(0, -28), 10, Color("#b44dff"), 120)
		var before := act
		act -= dt
		if act <= 0:
			feinted = false
		if before > 0.1 and act <= 0.1:
			var box := Rect2(position.x + (0.0 if facing > 0 else -90.0), position.y - 64, 90, 64)
			game.debug_box(box, Color(0.7, 0.3, 1, 0.4))
			game.fx.ring(position + Vector2(facing * 45, -30), 60, Color("#b44dff"))
			if box.intersects(p.hurtbox()):
				p.take_hit(position.x)
		return
	if act_cd <= 0 and p.ground and position.distance_to(p.position) < 700:
		# blink to whichever side of the player has floor
		for side in [-p.facing, p.facing]:
			var to := p.position + Vector2(side * 70, 0)
			var wd := game.world
			if not wd.is_solid(wd.cell(to.x), wd.cell(to.y - 20)) and wd.is_solid(wd.cell(to.x), wd.cell(to.y + 20)):
				game.fx.burst(position + Vector2(0, -28), 10, Color("#b44dff"), 120)
				position = to
				reset_physics_interpolation()
				vel = Vector2.ZERO
				facing = 1 if p.position.x > position.x else -1
				act = 0.5
				act_cd = randf_range(2.6, 3.6)
				game.fx.burst(position + Vector2(0, -28), 10, Color("#b44dff"), 120)
				break


func _touch() -> void:
	var p := game.player
	# hollows only hurt with their telegraphed lunge and vault, never by standing in you
	if kind == Kind.HOLLOW or kind == Kind.HEXER or kind == Kind.BRUTE or kind == Kind.SNUFFER or kind == Kind.FORGED:
		return
	if not p.dead and stun <= 0 and hurtbox().grow(-2).intersects(p.hurtbox()):
		p.take_hit(position.x)


func hurtbox() -> Rect2:
	if kind == Kind.GLOOMWING:
		return Rect2(position.x - w / 2, position.y - h / 2, w, h)
	return super()


func knock(v: Vector2) -> void:
	vel = v * (0.35 if kind == Kind.BRUTE else 1.0)
	stun = 0.15 if kind == Kind.BRUTE else 0.35
	hit_t = 0.12
	act = 0.0 if kind != Kind.BRUTE and kind != Kind.DROWNED else act
	ground = false


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	var body := Color(1, 1, 1) if hit_t > 0 else Rig.COL_SHADE
	var rim := Color(0.9, 0.22, 0.23, 0.6)
	var gold := Color("#f2b43a")
	if elite != "":
		var pulse := 0.55 + 0.2 * sin(Time.get_ticks_msec() * 0.006 + ph)
		draw_arc(Vector2(0, -2) if kind != Kind.GLOOMWING else Vector2(0, 14), 22, 0, TAU, 28, Color(gold, pulse), 2)
	var eyes: Color = gold if elite != "" else {Kind.HEXER: Color("#b44dff"), Kind.SNUFFER: Color("#b44dff"), Kind.DROWNED: Color("#3fd6c4"), Kind.FORGED: Color("#ff8a5c")}.get(kind, Color("#e5383b"))
	if kind == Kind.GLOOMWING:
		_draw_wing(body, eyes)
	else:
		var pose: Dictionary
		if stun > 0:
			pose = Rig.HURT
		elif not ground:
			pose = Rig.FALL
		elif kind == Kind.BRUTE and act > 0:
			var k := clampf((0.75 - act) / 0.6, 0, 1)
			var a := lerpf(-2.6, 1.6, Rig.ease_out(k)) if act < 0.15 else -2.6
			pose = {"lean": 0.25 if act < 0.15 else -0.15, "tilt": 0.0, "legs": [[-0.6, -0.1], [0.7, -0.6]], "arms": [[-0.6, 0.6], [a, 0.2]]}
		elif kind == Kind.DROWNED and act > 0:
			pose = Rig.CROUCH
		elif kind == Kind.FORGED and act > 0:
			pose = {"lean": -0.1, "tilt": 0.0, "legs": [[-0.5, -0.1], [0.6, -0.5]], "arms": [[-0.4, 0.5], [-2.6 + (0.45 - act) * 8, 0.3]]}
		elif kind == Kind.SNUFFER:
			var sw := 1.6 if act > 0 and act <= 0.1 else -2.4 if act > 0 else 0.4
			pose = {"lean": 0.25 if act > 0 else 0.05, "tilt": -0.1, "legs": [[-0.45, -0.2], [0.5, -0.5]], "arms": [[-0.4, 0.6], [sw, 0.2]]}
		elif kind == Kind.HEXER:
			var raise := 1.0 if act > 0 else 0.0
			pose = {"lean": 0.0, "tilt": -0.1, "legs": [[-0.2, 0.05], [0.25, -0.1]], "arms": [[-0.3 - raise * 2.4, 0.4], [0.4 + raise * 2.2, 0.3]]}
		else:
			pose = Rig.run_pose(ph)
			pose.lean = 0.15 if kind == Kind.HOLLOW else 0.3
		var hip := -40.0 * scale_k / 0.6
		var J := Rig.build(pose, Vector2(0, hip), facing, scale_k)
		Rig.paint(self, J, body, Color("#1d1a20"), rim, eyes)
		if kind == Kind.BRUTE:
			# club
			var hand: Vector2 = J.armF.e
			Rig.blade(self, hand, J.armF.can, 54, 0.0)
			if act > 0.15:
				draw_arc(Vector2(facing * 50, -30), 30, 0, TAU, 24, Color(0.9, 0.22, 0.23, 0.5 * (1 - act)), 3)
		if kind == Kind.SNUFFER:
			# a snuffer: a cone on a long pole
			var hand: Vector2 = J.armF.e
			var ang: float = J.armF.can
			var dir := Vector2(cos(ang), sin(ang))
			var tip := hand + dir * 50
			draw_line(hand, tip, Color("#5a524c"), 2.5)
			var n := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip, tip + dir * 12 + n * 7, tip + dir * 12 - n * 7]), body)
		if kind == Kind.FORGED:
			draw_circle(Vector2(facing * 14, -36), 5, Color(1, 0.55, 0.36, 0.5))
		if kind == Kind.HEXER and act > 0:
			draw_circle(Vector2(facing * 10, -40 - 30), 6 + (0.5 - act) * 10, Color(0.7, 0.3, 1, 0.8))
	if tele > 0:
		# danger mark over the head during every wind-up
		var k := clampf(1.0 - tele / tele_max, 0, 1)
		var c := Color(1, 0.27, 0.24, 0.35 + 0.55 * k)
		var top3 := (-h / 2 - 30) if kind == Kind.GLOOMWING else (-h - 30)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, top3), Vector2(4, top3), Vector2(1.5, top3 + 12), Vector2(-1.5, top3 + 12)]), c)
		draw_circle(Vector2(0, top3 + 17), 2.2, c)
		if next_move == "charge" or next_move == "lunge":
			var len := 300.0 if next_move == "charge" else 150.0
			draw_rect(Rect2(minf(0, facing * len), -4, len, 4), Color(0.9, 0.22, 0.23, 0.35 * k))
	if hp < max_hp:
		var top := -h / 2 - 14 if kind == Kind.GLOOMWING else -h - 12
		draw_rect(Rect2(-16, top, 32, 4), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-15, top + 1, 30 * clampf(hp / max_hp, 0, 1), 2), Color("#f2b43a") if elite != "" else Color("#e5383b"))
	if elite != "":
		var top2 := -h / 2 - 22 if kind == Kind.GLOOMWING else -h - 20
		var f := ThemeDB.fallback_font
		var sw := f.get_string_size(elite, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string_outline(f, Vector2(-sw / 2, top2), elite, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color.BLACK)
		draw_string(f, Vector2(-sw / 2, top2), elite, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f2b43a"))


func _draw_wing(body: Color, eyes: Color) -> void:
	var flap := sin(ph * 18) * 0.6
	for sd in [-1, 1]:
		var tip := Vector2(sd * 30, -10 + flap * 14 * sd * sd)
		var mid := Vector2(sd * 16, 4 + flap * 6)
		draw_colored_polygon(PackedVector2Array([Vector2(sd * 4, -4), tip, mid, Vector2(sd * 4, 6)]), body)
	draw_circle(Vector2.ZERO, 9, body)
	draw_circle(Vector2(facing * 3 - 2, -1), 1.8, eyes)
	draw_circle(Vector2(facing * 3 + 3, -1), 1.8, eyes)
