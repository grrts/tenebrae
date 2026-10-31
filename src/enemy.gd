class_name Enemy
extends Actor
## All four regular enemy types share one class; `kind` picks the behaviour.
##   hollow     basic grunt: shuffles toward you, walks off ledges, hops short steps
##   gloomwing  flyer: ignores tiles, drifts toward you, then dives; dies in one hit
##   brute      heavy: can't jump, holds its floor, long telegraphed club swing
##   hexer      caster: stays put and lobs hexes in an arc; you climb to reach it

enum Kind { HOLLOW, GLOOMWING, BRUTE, HEXER }

const STATS := {
	Kind.HOLLOW: {"hp": 3.0, "speed": 120.0, "w": 18.0, "h": 52.0, "scale": 0.6},
	Kind.GLOOMWING: {"hp": 1.0, "speed": 170.0, "w": 26.0, "h": 24.0, "scale": 0.5},
	Kind.BRUTE: {"hp": 9.0, "speed": 70.0, "w": 30.0, "h": 70.0, "scale": 0.85},
	Kind.HEXER: {"hp": 2.0, "speed": 0.0, "w": 18.0, "h": 52.0, "scale": 0.6},
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


func _physics_process(dt: float) -> void:
	if game == null or dead or game.hitstop > 0:
		return
	hit_t = maxf(0, hit_t - dt)
	stun = maxf(0, stun - dt)
	hop_cd = maxf(0, hop_cd - dt)
	act_cd = maxf(0, act_cd - dt)
	match kind:
		Kind.GLOOMWING:
			_fly(dt)
			return
		Kind.BRUTE:
			_brute(dt)
		Kind.HEXER:
			_hexer(dt)
		_:
			_walk(dt, speed, true)
	vel.y = minf(vel.y + gravity * dt, 1400)
	game.world.move(self, dt, false)
	ph += absf(vel.x) * dt * 0.04
	_touch()


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
	elif act > 0:
		act -= dt
		vel = dive_dir * 520
	else:
		var hover := target + Vector2(0, -110)
		vel = vel.move_toward((hover - position).normalized() * speed, 600 * dt)
		vel.y += sin(ph * 3) * 40
		if act_cd <= 0 and position.distance_to(target) < 260:
			dive_dir = (target - position).normalized()
			act = 0.45
			act_cd = randf_range(1.6, 2.6)
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


func _touch() -> void:
	var p := game.player
	if kind == Kind.HEXER or kind == Kind.BRUTE:
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
	act = 0.0 if kind != Kind.BRUTE else act
	ground = false


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	var body := Color(1, 1, 1) if hit_t > 0 else Rig.COL_SHADE
	var rim := Color(0.9, 0.22, 0.23, 0.6)
	var eyes := Color("#b44dff") if kind == Kind.HEXER else Color("#e5383b")
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
		if kind == Kind.HEXER and act > 0:
			draw_circle(Vector2(facing * 10, -40 - 30), 6 + (0.5 - act) * 10, Color(0.7, 0.3, 1, 0.8))
	if hp < max_hp:
		var top := -h / 2 - 14 if kind == Kind.GLOOMWING else -h - 12
		draw_rect(Rect2(-16, top, 32, 4), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-15, top + 1, 30 * clampf(hp / max_hp, 0, 1), 2), Color("#e5383b"))


func _draw_wing(body: Color, eyes: Color) -> void:
	var flap := sin(ph * 18) * 0.6
	for sd in [-1, 1]:
		var tip := Vector2(sd * 30, -10 + flap * 14 * sd * sd)
		var mid := Vector2(sd * 16, 4 + flap * 6)
		draw_colored_polygon(PackedVector2Array([Vector2(sd * 4, -4), tip, mid, Vector2(sd * 4, 6)]), body)
	draw_circle(Vector2.ZERO, 9, body)
	draw_circle(Vector2(facing * 3 - 2, -1), 1.8, eyes)
	draw_circle(Vector2(facing * 3 + 3, -1), 1.8, eyes)
