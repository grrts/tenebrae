class_name Hollow
extends Actor
## Basic grunt: shuffles toward the player, walks off ledges to follow,
## hops up short steps. Contact damage only.

@export var speed := 120.0
@export var gravity := 2100.0

var game: Game
var dashed := -1
var hit_t := 0.0
var stun := 0.0
var hop_cd := 0.0
var ph := 0.0
var ps := PackedFloat32Array()


func _ready() -> void:
	w = 18
	h = 52
	ph = randf() * TAU


func _physics_process(dt: float) -> void:
	if game == null or dead or game.hitstop > 0:
		return
	hit_t = maxf(0, hit_t - dt)
	stun = maxf(0, stun - dt)
	hop_cd = maxf(0, hop_cd - dt)
	var p := game.player
	var dx := p.position.x - position.x
	var dy := p.position.y - position.y
	if stun <= 0:
		var dir := signf(dx) if absf(dx) > 12 else 0.0
		# only chase when roughly on the same floor or below; otherwise wander
		if dy < -120 and absf(dx) < 200:
			dir = facing
		vel.x = move_toward(vel.x, dir * speed, 900 * dt)
		if dir != 0:
			facing = int(dir)
		if ground and wall == facing and hop_cd <= 0:
			vel.y = -620
			hop_cd = 0.8
	else:
		vel.x = move_toward(vel.x, 0, 600 * dt)
	vel.y = minf(vel.y + gravity * dt, 1400)
	game.world.move(self, dt, false)
	ph += absf(vel.x) * dt * 0.04
	if not p.dead and hurtbox().grow(-2).intersects(p.hurtbox()) and stun <= 0:
		p.take_hit(position.x)


func knock(v: Vector2) -> void:
	vel = v
	stun = 0.35
	hit_t = 0.12
	ground = false


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	var pose: Dictionary
	if stun > 0:
		pose = Rig.HURT
	elif not ground:
		pose = Rig.FALL
	else:
		pose = Rig.run_pose(ph)
		pose.lean = 0.15
	var J := Rig.build(pose, Vector2(0, -40), facing, 0.6)
	var flash := Color(1, 1, 1) if hit_t > 0 else Rig.COL_SHADE
	Rig.paint(self, J, flash, Color("#1d1a20"), Color(0.9, 0.22, 0.23, 0.6), Color("#e5383b"))
	if hp < max_hp:
		draw_rect(Rect2(-16, -h - 12, 32, 4), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-15, -h - 11, 30 * clampf(hp / max_hp, 0, 1), 2), Color("#e5383b"))
