class_name Fx
extends Node2D
## Cheap immediate-mode particles and rings. Grey-box only.

var parts := []
var rings := []


func _process(dt: float) -> void:
	for p in parts:
		p.life -= dt
		var v: Vector2 = p.vel * maxf(0, 1 - p.drag * dt)
		v.y += p.grav * dt
		p.vel = v
		p.pos += v * dt
	parts = parts.filter(func(p): return p.life > 0)
	for r in rings:
		r.t += dt
	rings = rings.filter(func(r): return r.t < r.dur)
	queue_redraw()


func _emit(pos: Vector2, vel: Vector2, col: Color, size: float, life: float, drag := 3.0, grav := 0.0) -> void:
	parts.append({"pos": pos, "vel": vel, "col": col, "size": size, "life": life, "max": life, "drag": drag, "grav": grav})


func burst(pos: Vector2, n: int, col: Color, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		_emit(pos, Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed), col, randf_range(2.5, 5), randf_range(0.3, 0.55))


func dust(pos: Vector2) -> void:
	for i in 7:
		_emit(pos, Vector2(randf_range(-90, 90), randf_range(-50, 0)), Color(0.67, 0.47, 0.41, 0.35), randf_range(3, 6), 0.4)


func spark(pos: Vector2) -> void:
	_emit(pos, Vector2(randf_range(-60, 60), randf_range(-120, -20)), Color("#f2b43a"), 2, 0.25, 1, 900)


func shade_burst(pos: Vector2, dir: float) -> void:
	for i in 14:
		_emit(pos, Vector2(dir * randf_range(60, 340), randf_range(-320, 40)), Color("#0a0a0d") if i % 3 else Color("#e5383b"), randf_range(2.5, 6), randf_range(0.4, 0.8), 1.5, 900)


func ring(pos: Vector2, radius: float, col: Color) -> void:
	rings.append({"pos": pos, "radius": radius, "col": col, "t": 0.0, "dur": 0.45, "kind": "flat"})


func wing(pos: Vector2, f: int) -> void:
	rings.append({"pos": pos, "radius": 70.0, "col": Color("#e5383b"), "t": 0.0, "dur": 0.5, "kind": "wing", "f": f})


func _draw() -> void:
	for p in parts:
		var k: float = p.life / p.max
		var c: Color = p.col
		c.a *= minf(1, k * 2)
		draw_circle(p.pos, p.size * (0.4 + 0.6 * k), c)
	for r in rings:
		var k: float = r.t / r.dur
		var e := 1 - pow(1 - k, 3)
		var c: Color = r.col
		c.a = 1 - k
		if r.kind == "flat":
			draw_set_transform(r.pos, 0, Vector2(1, 0.22))
			draw_arc(Vector2.ZERO, 20 + e * r.radius, 0, TAU, 48, c, 12 * (1 - k) + 2)
		else:
			draw_set_transform(r.pos, 0, Vector2.ONE)
			for sd in [-1, 1]:
				var pts := PackedVector2Array()
				for i in 9:
					var u := i / 8.0
					var a := Vector2(sd * 6, 0)
					var ctrl := Vector2(sd * (24 + e * 50), -6)
					var b := Vector2(sd * (40 + e * 70), 14 + e * 26)
					pts.append(a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u))
				draw_polyline(pts, c, 5 * (1 - k) + 1)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
