class_name Player
extends Actor
## The Scarf Kid. All movement runs in _physics_process at 120 Hz.
## Every number a designer may want to tune is an @export.

@export_group("Run")
@export var run_speed := 330.0
@export var ground_accel := 3600.0
@export var ground_decel := 4200.0
@export var air_accel := 2400.0
@export_group("Jump")
@export var gravity := 2100.0
@export var fall_gravity_mul := 1.3
@export var max_fall := 1400.0
@export var jump_v := 800.0
@export var double_jump_v := 760.0
@export var jump_cut := 0.45 ## vy multiplier when jump is released early
@export var coyote_time := 0.10
@export var jump_buffer := 0.12
@export_group("Wall")
@export var wall_slide_max := 170.0
@export var wall_jump_v := Vector2(430, 800)
@export var wall_lock := 0.14 ## seconds of reduced air control after a wall jump
@export_group("Dash")
@export var dash_speed := 860.0
@export var dash_time := 0.2
@export var dash_cooldown := 0.6
@export_group("Combat")
@export var reach := 92.0
@export var step_time := 0.13 ## one katana swing
@export var combo_window := 0.22
@export var slam_speed := 1750.0
@export var slam_radius := 160.0
@export var damage := 1.0
@export var blade_len := 58.0

var game: Game

# timers
var coyote := 0.0
var buffer := 0.0
var dash := 0.0
var dash_cd := 0.0
var air_dash_used := false
var dj_used := false
var wall_lock_t := 0.0
var drop_t := 0.0
var invuln := 0.0
var land := 0.0
var fall_v := 0.0
var stretch := 0.0
var flip := 0.0
var kick := 0.0
var slam := false

# attack state: null or {step, t, hit: Array, queued}
var atk = null
var run_ph := 0.0
var sliding := false

# animation spring state
var ps := PackedFloat32Array()
var pd := PackedFloat32Array()
var hip_off := -42.0
var hip_v := 0.0
var J := {}


func _ready() -> void:
	w = 18
	h = 52
	max_hp = 6
	hp = max_hp


func state_name() -> String:
	if dead: return "dead"
	if dash > 0: return "dash"
	if slam: return "slam"
	if atk != null: return "attack %d" % (atk.step + 1)
	if not ground:
		if sliding: return "wall slide"
		if flip > 0: return "double jump"
		return "rise" if vel.y < 0 else "fall"
	return "idle" if absf(vel.x) < 30 else "run"


func _physics_process(dt: float) -> void:
	if game == null or game.hitstop > 0 or game.frozen:
		return
	if dead:
		vel.x = move_toward(vel.x, 0, 1600 * dt)
		vel.y = minf(vel.y + gravity * dt, max_fall)
		game.world.move(self, dt, false)
		return

	var ix := Input.get_axis("left", "right")
	var down := Input.get_action_strength("down") > 0.5
	if Input.is_action_just_pressed("jump"):
		buffer = jump_buffer
	for t in ["coyote", "buffer", "dash_cd", "wall_lock_t", "drop_t", "invuln", "land", "stretch", "flip", "kick"]:
		set(t, maxf(0, get(t) - dt))
	if ground:
		coyote = coyote_time
		air_dash_used = false
		dj_used = false

	# --- dash cancels everything
	if Input.is_action_just_pressed("dash") and dash_cd <= 0 and not (air_dash_used and not ground):
		dash = dash_time
		dash_cd = dash_cooldown
		atk = null
		slam = false
		if absf(ix) > 0.2:
			facing = int(signf(ix))
		if not ground:
			air_dash_used = true
		game.dash_id += 1
		game.fx.burst(position + Vector2(0, -26), 10, Color(0.9, 0.22, 0.23), 160)
	if dash > 0:
		dash -= dt
		vel = Vector2(dash_speed * facing, 0)
		invuln = maxf(invuln, 0.02)
		for e in game.enemies:
			if not e.dead and e.dashed != game.dash_id and absf(e.position.x - position.x) < 34 and absf(e.position.y - position.y) < 70:
				e.dashed = game.dash_id
				game.hit_enemy(e, damage * (3.0 if game.has_rune("EMBER DASH") else 1.0), Vector2(facing * 260, -260))
		if dash <= 0:
			vel.x = run_speed * facing * 0.6
		_move(dt, false)
		return

	# --- slam: down + attack in the air
	if slam:
		vel = Vector2(0, slam_speed)
		_move(dt, false)
		if ground:
			slam = false
			land = 0.18
			game.shake(0.22, 10)
			game.hitstop = 0.06
			game.fx.ring(position, slam_radius, Color("#f2b43a"))
			for e in game.enemies:
				if not e.dead and absf(e.position.x - position.x) < slam_radius and absf(e.position.y - position.y) < 90:
					game.hit_enemy(e, damage * 2 * (1.7 if game.has_rune("HEAVY SHADOW") else 1.0), Vector2(signf(e.position.x - position.x) * 320, -520))
		return

	# --- attack input
	if Input.is_action_just_pressed("attack"):
		if not ground and down:
			slam = true
			atk = null
			vel.y = -180
		elif atk == null:
			atk = {"step": 0, "t": 0.0, "hit": [], "queued": false}
			if absf(ix) > 0.2:
				facing = int(signf(ix))
		else:
			atk.queued = true
	if atk != null:
		atk.t += dt
		_attack_hits()
		if atk.t >= step_time + combo_window or (atk.t >= step_time and not atk.queued and atk.t >= step_time + 0.06):
			if atk.queued and atk.step < 2:
				atk = {"step": atk.step + 1, "t": 0.0, "hit": [], "queued": false}
				if absf(ix) > 0.2:
					facing = int(signf(ix))
			else:
				atk = null

	# --- horizontal
	var target := ix * run_speed
	if atk != null and ground:
		target *= 0.25
	var accel := ground_accel if ground else air_accel
	if ground and absf(target) < absf(vel.x):
		accel = ground_decel
	if wall_lock_t > 0:
		accel *= 0.25
	vel.x = move_toward(vel.x, target, accel * dt)
	if absf(ix) > 0.2 and atk == null:
		facing = int(signf(ix))

	# --- wall slide
	sliding = not ground and wall != 0 and vel.y > 0 and signf(ix) == wall
	if sliding:
		vel.y = minf(vel.y, wall_slide_max)
		if randf() < dt * 30:
			game.fx.spark(position + Vector2(wall * 9, -30))

	# --- jumps (buffered)
	if buffer > 0:
		if (ground or coyote > 0) and down and on_one_way:
			drop_t = 0.22
			buffer = 0
			ground = false
			vel.y = 80
		elif ground or coyote > 0:
			_do_jump(jump_v)
		elif wall != 0 and not ground:
			buffer = 0
			vel = Vector2(-wall * wall_jump_v.x, -wall_jump_v.y)
			facing = -wall
			wall_lock_t = wall_lock
			kick = 0.22
			dj_used = false
			game.fx.burst(position + Vector2(wall * 8, -10), 8, Color(0.67, 0.47, 0.41, 0.6), 100)
			if game.has_rune("UPDRAFT"):
				game.fx.ring(position + Vector2(0, -30), 160, Color("#3fd6c4"))
				for e in game.enemies:
					if not e.dead and absf(e.position.x - position.x) < 160 and absf(e.position.y - position.y) < 170:
						game.hit_enemy(e, 2, Vector2(facing * 220, -720))
		elif not dj_used:
			buffer = 0
			dj_used = true
			vel.y = -double_jump_v
			flip = 0.4
			game.fx.wing(position, facing)
	if Input.is_action_just_released("jump") and vel.y < -300 and flip <= 0:
		vel.y *= jump_cut

	# --- gravity
	var gmul := fall_gravity_mul if vel.y > 0 else 1.0
	vel.y = minf(vel.y + gravity * gmul * dt, max_fall)
	_move(dt, drop_t > 0)
	run_ph += absf(vel.x) * dt * 0.034


func _do_jump(v: float) -> void:
	buffer = 0
	coyote = 0
	ground = false
	vel.y = -v
	stretch = 0.16
	game.fx.dust(position)


func _move(dt: float, drop: bool) -> void:
	var was_ground := ground
	var vy := vel.y
	game.world.move(self, dt, drop)
	if ground and not was_ground:
		fall_v = vy
		land = clampf(vy / 1400.0, 0.3, 1.0) * 0.14
		if vy > 500:
			game.fx.dust(position)


func _attack_hits() -> void:
	if atk.t > step_time * 0.75:
		return
	var box := Rect2(position.x + (0.0 if facing > 0 else -reach), position.y - 64, reach, 64)
	game.debug_box(box, Color(1, 0.8, 0.2, 0.35))
	game.strike_braziers(box)
	for e in game.enemies:
		if e.dead or atk.hit.has(e):
			continue
		if box.intersects(e.hurtbox()):
			atk.hit.append(e)
			var up := -420.0 if atk.step == 2 else -160.0
			game.hit_enemy(e, damage * (1.5 if atk.step == 2 else 1.0) * (2.0 if atk.step == 2 and game.has_rune("FINISHER") else 1.0), Vector2(facing * (380 if atk.step == 2 else 220), up))


func take_hit(from_x: float) -> void:
	if invuln > 0 or dash > 0 or dead:
		return
	hp -= 1
	invuln = 1.0
	vel = Vector2(signf(position.x - from_x) * 360, -420)
	atk = null
	slam = false
	game.shake(0.25, 12)
	game.hitstop = 0.08
	if hp <= 0 and not game.try_revive():
		dead = true
		game.on_player_dead()


# ---------- animation (runs every rendered frame) ----------

func _process(dt: float) -> void:
	_animate(dt)
	var blink := invuln > 0 and int(invuln * 20) % 2 == 1 and not dead
	modulate.a = 0.45 if blink else 1.0
	queue_redraw()


func _animate(dt: float) -> void:
	var pose: Dictionary
	var hip := -42.0
	var quick := false
	if dead:
		pose = {"lean": 0.5, "tilt": 0.4, "legs": [[-0.15, -1.55], [0.95, -1.45]], "arms": [[0.2, 0.3], [0.5, 0.2]]}
		hip = -25
	elif invuln > 0.8:
		pose = Rig.HURT
		hip = -44
	elif dash > 0:
		pose = Rig.DASH
		hip = -48
		quick = true
	elif slam:
		pose = Rig.SLAM
		hip = -34
		quick = true
	elif atk != null:
		var sw: Array = Rig.SWINGS[atk.step]
		var a := lerpf(sw[0], sw[1], Rig.ease_out(clampf(atk.t / (step_time * 0.75), 0, 1)))
		var legs := [[-0.62, -0.05], [0.72, -0.62]] if ground else [[-0.45, -1.1], [0.85, -1.5]]
		pose = {"lean": -0.05 if atk.step == 2 else 0.3, "tilt": -0.1, "legs": legs, "arms": [[-0.8 + 0.2 * atk.step, 1.2], [a, 0.15]]}
		hip = -37 if ground else -44
		quick = true
	elif not ground:
		if sliding:
			pose = Rig.WALL
		elif flip > 0:
			pose = Rig.keyframes(Rig.FLIP, 1 - flip / 0.4)
		elif kick > 0:
			var m := 1 - kick / 0.22
			pose = Rig.blend({"lean": 0.3, "tilt": -0.1, "legs": [[-0.95, -0.15], [0.15, -0.35]], "arms": [[1.7, 0.5], [2.5, 0.2]]},
				{"lean": 0.3, "tilt": -0.1, "legs": [[-0.55, -1.25], [0.95, -1.35]], "arms": [[-1.9, 0.5], [2.0, 0.5]]}, m)
		else:
			# one continuous arc: rise, apex, then legs reach down for the landing
			var k := clampf((vel.y + 650) / 1300, 0, 1)
			var u := Rig.ease_io(k * 2 if k < 0.5 else k * 2 - 1)
			pose = Rig.blend(Rig.RISE, Rig.APEX, u) if k < 0.5 else Rig.blend(Rig.APEX, Rig.FALL, u)
			pose.lean += clampf(vel.x / 310, -1, 1) * facing * 0.12
			if stretch > 0:
				var m := Rig.ease_io(stretch / 0.16)
				pose = Rig.blend(pose, {"lean": 0.05, "tilt": pose.tilt, "legs": [[-0.18, -0.08], [0.22, -0.14]], "arms": [[-2.5, 0.2], [2.6, 0.25]]}, m)
		hip = -46
	elif absf(vel.x) < 30:
		pose = Rig.IDLE.duplicate(true)
		pose.arms[1][0] += sin(Time.get_ticks_msec() * 0.0022) * 0.04
	else:
		pose = Rig.run_pose(run_ph)
		hip = -42 + cos(run_ph * 2) * 1.5
	# landing squash blended over whatever the body was doing
	var cw := clampf(land / 0.12, 0, 1) if ground and atk == null and dash <= 0 and not dead else 0.0
	if cw > 0:
		pose = Rig.blend(pose, Rig.CROUCH, cw)
		hip = lerpf(hip, -28, cw)

	# every joint follows its target on a damped spring, so moves get real in-betweens
	var tg := Rig.to_vec(pose)
	if ps.size() != tg.size():
		ps = tg.duplicate()
		pd.resize(tg.size())
		pd.fill(0)
	var kk := 1100.0 if quick else 300.0
	var zz := 50.0 if quick else 21.0
	var n := ceili(dt / 0.008)
	var hstep := dt / maxf(n, 1)
	for _s in n:
		for i in tg.size():
			pd[i] += ((tg[i] - ps[i]) * kk - pd[i] * zz) * hstep
			ps[i] += pd[i] * hstep
		hip_v += ((hip - hip_off) * kk - hip_v * zz) * hstep
		hip_off += hip_v * hstep
	J = Rig.build(Rig.from_vec(ps), Vector2(0, hip_off), facing, 0.66)


func _draw() -> void:
	if J.is_empty():
		return
	# scarf stub: two crimson strips trailing from the neck
	var nk: Vector2 = J.neck
	for i in 2:
		var tail := nk + Vector2(-facing * (26 + i * 6) - vel.x * 0.03, 8 + i * 6 + sin(Time.get_ticks_msec() * 0.009 + i) * 4 - vel.y * 0.02)
		draw_line(nk, tail, Color("#e5383b"), 4.0 - i)
	Rig.paint(self, J)
	var ang: float
	if atk != null:
		ang = J.armF.can
	elif slam:
		ang = PI / 2
	elif dash > 0:
		ang = PI - 0.15 if facing > 0 else 0.15
	else:
		ang = (2.5 if facing > 0 else 0.64) + (0.0 if ground else -facing * 0.5)
	Rig.blade(self, J.armF.e, ang, blade_len, 1.3 if atk != null or slam else 0.5)
