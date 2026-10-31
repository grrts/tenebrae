class_name Rig
extends RefCounted
## Procedural stick rig, ported from the web pitch demo.
## Angles are measured from straight down; positive points toward facing.
## A pose is {lean, tilt, legs: [[thigh, knee], [thigh, knee]], arms: [[upper, elbow], ...]}.

const COL_SHADE := Color("#0a0a0d")
const COL_BACK := Color("#26232b")
const COL_RIM := Color(1.0, 0.5, 0.345, 0.92)

const IDLE := {"lean": 0.06, "tilt": -0.05, "legs": [[-0.24, 0.1], [0.28, -0.18]], "arms": [[-0.2, 0.34], [0.42, 0.7]]}
const RISE := {"lean": 0.18, "tilt": -0.12, "legs": [[-0.5, -1.05], [0.95, -1.55]], "arms": [[-1.5, 0.9], [2.1, 0.5]]}
const APEX := {"lean": 0.3, "tilt": -0.05, "legs": [[0.3, -1.65], [1.0, -1.85]], "arms": [[-1.1, 1.0], [1.5, 0.8]]}
const FALL := {"lean": 0.1, "tilt": 0.02, "legs": [[-0.3, -0.45], [0.45, -0.8]], "arms": [[-2.1, 0.5], [1.9, 0.45]]}
const CROUCH := {"lean": 0.42, "tilt": -0.05, "legs": [[0.8, -1.5], [1.0, -1.65]], "arms": [[-0.55, 0.9], [0.75, 1.1]]}
const DASH := {"lean": 0.78, "tilt": -0.25, "legs": [[-0.95, -1.25], [0.55, -1.75]], "arms": [[-1.95, 0.35], [-1.6, 0.25]]}
const SLAM := {"lean": 0.0, "tilt": -0.1, "legs": [[0.3, -1.6], [0.7, -1.8]], "arms": [[-1.3, 0.5], [0.05, 0.0]]}
const WALL := {"lean": 0.02, "tilt": -0.1, "legs": [[-0.55, -0.95], [0.3, -1.25]], "arms": [[-1.55, 0.25], [0.6, 1.1]]}
const HURT := {"lean": -0.3, "tilt": 0.3, "legs": [[-0.4, -0.3], [0.5, -0.6]], "arms": [[-1.8, 0.6], [-1.2, 0.4]]}
# double jump scissor kick keyframes (t = 0..1 over 0.4 s)
const FLIP := [
	{"t": 0.0, "lean": 0.3, "tilt": -0.05, "legs": [[0.95, -1.9], [1.25, -2.05]], "arms": [[-1.2, 0.9], [-0.8, 1.1]]},
	{"t": 0.3, "lean": -0.12, "tilt": -0.15, "legs": [[-0.35, -0.05], [1.45, -1.7]], "arms": [[2.3, 0.35], [2.7, 0.25]]},
	{"t": 0.65, "lean": 0.05, "tilt": -0.1, "legs": [[1.2, -1.6], [-0.25, -0.35]], "arms": [[1.6, 0.7], [2.2, 0.5]]},
	{"t": 1.0, "lean": 0.22, "tilt": -0.08, "legs": [[0.35, -1.55], [1.0, -1.8]], "arms": [[-1.1, 1.0], [1.5, 0.8]]},
]
# katana combo: [from, to] angle of the sword arm per step
const SWINGS := [[-2.5, 1.8], [1.6, -1.2], [1.2, -2.7]]


static func ease_io(u: float) -> float:
	return 2 * u * u if u < 0.5 else 1 - pow(-2 * u + 2, 2) / 2


static func ease_out(u: float) -> float:
	return 1 - pow(1 - u, 3)


static func run_pose(ph: float) -> Dictionary:
	var legs := []
	var arms := []
	for i in 2:
		var q := ph + i * PI
		legs.append([sin(q) * 0.82, -(0.28 + 1.4 * maxf(0, cos(q)))])
		arms.append([-sin(q) * 0.95, 1.45])
	return {"lean": 0.32, "tilt": -0.12, "legs": legs, "arms": [arms[0], [arms[1][0] * 0.6 + 0.2, 1.2]]}


## Pose <-> flat vector, so a spring can smooth every joint at once.
static func to_vec(p: Dictionary) -> PackedFloat32Array:
	var l: Array = p.legs
	var a: Array = p.arms
	return PackedFloat32Array([p.lean, p.get("tilt", 0.0), l[0][0], l[0][1], l[1][0], l[1][1], a[0][0], a[0][1], a[1][0], a[1][1]])


static func from_vec(v: PackedFloat32Array) -> Dictionary:
	return {"lean": v[0], "tilt": v[1], "legs": [[v[2], v[3]], [v[4], v[5]]], "arms": [[v[6], v[7]], [v[8], v[9]]]}


static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var va := to_vec(a)
	var vb := to_vec(b)
	for i in va.size():
		va[i] = lerpf(va[i], vb[i], u)
	return from_vec(va)


static func keyframes(k: Array, u: float) -> Dictionary:
	var i := 0
	while i < k.size() - 2 and u > k[i + 1].t:
		i += 1
	var a: Dictionary = k[i]
	var b: Dictionary = k[i + 1]
	return blend(a, b, ease_io(clampf((u - a.t) / (b.t - a.t), 0, 1)))


## Builds joint positions. hip is the hip point, f the facing, s the scale.
static func build(p: Dictionary, hip: Vector2, f: int, s: float) -> Dictionary:
	var torso := 52.0 * s
	var thigh := 34.0 * s
	var shin := 34.0 * s
	var ua := 25.0 * s
	var fa := 24.0 * s
	var head := 15.0 * s
	var lean: float = p.lean
	var neck := hip + Vector2(sin(lean) * f * torso, -cos(lean) * torso)
	var sh := hip + Vector2(sin(lean) * f * torso * 0.84, -cos(lean) * torso * 0.84)
	var ht: float = lean + p.get("tilt", 0.0)
	var hc := neck + Vector2(sin(ht) * f * (head + 2 * s), -cos(ht) * (head + 2 * s))
	var shapes := []
	var J := {"hip": hip, "neck": neck, "sh": sh, "head": hc, "head_r": head, "f": f, "s": s, "shapes": shapes}
	var l: Array = p.legs
	var a: Array = p.arms
	J.legB = _limb(shapes, hip, l[0][0], l[0][1], thigh, shin, Vector3(5.4, 4.3, 3.1) * s, "B", true, f, s)
	J.armB = _limb(shapes, sh, a[0][0], a[0][1], ua, fa, Vector3(4.4, 3.3, 2.6) * s, "B", false, f, s)
	shapes.append({"a": hip, "b": sh, "r1": 5.6 * s, "r2": 7.0 * s, "p": "T"})
	shapes.append({"a": sh, "b": neck, "r1": 5.0 * s, "r2": 3.2 * s, "p": "T"})
	J.legF = _limb(shapes, hip, l[1][0], l[1][1], thigh, shin, Vector3(5.6, 4.5, 3.2) * s, "F", true, f, s)
	J.armF = _limb(shapes, sh, a[1][0], a[1][1], ua, fa, Vector3(4.6, 3.4, 2.7) * s, "F", false, f, s)
	return J


static func _limb(shapes: Array, o: Vector2, a: float, b: float, l1: float, l2: float, r: Vector3, layer: String, foot: bool, f: int, s: float) -> Dictionary:
	var k := o + Vector2(sin(a) * f * l1, cos(a) * l1)
	var e := k + Vector2(sin(a + b) * f * l2, cos(a + b) * l2)
	shapes.append({"a": o, "b": k, "r1": r.x, "r2": r.y, "p": layer})
	shapes.append({"a": k, "b": e, "r1": r.y, "r2": r.z, "p": layer})
	if foot:
		shapes.append({"a": e, "b": e + Vector2(f * 8 * s, 1.5 * s), "r1": r.z * 1.05, "r2": r.z * 0.8, "p": layer})
	else:
		shapes.append({"a": e, "b": e, "r1": r.z * 1.25, "r2": r.z * 1.25, "p": layer})
	# screen angle of the forearm, used to aim the blade
	return {"k": k, "e": e, "can": atan2(cos(a + b), sin(a + b) * f)}


## Tapered capsule between two circles.
static func cap(ci: CanvasItem, a: Vector2, b: Vector2, r1: float, r2: float, col: Color) -> void:
	if a.distance_squared_to(b) < 0.01:
		ci.draw_circle(a, maxf(r1, r2), col)
		return
	var th := (b - a).angle()
	var pts := PackedVector2Array()
	for i in 9:
		var t := th + PI / 2 + PI * i / 8.0
		pts.append(a + Vector2(cos(t), sin(t)) * r1)
	for i in 9:
		var t := th - PI / 2 + PI * i / 8.0
		pts.append(b + Vector2(cos(t), sin(t)) * r2)
	ci.draw_colored_polygon(pts, col)


static func paint(ci: CanvasItem, J: Dictionary, body := COL_SHADE, back := COL_BACK, rim := COL_RIM, eyes := Color(0, 0, 0, 0)) -> void:
	var s: float = J.s
	for pass_i in 2:
		var off := Vector2(-1.5 * s, -1.4 * s) if pass_i == 0 else Vector2.ZERO
		for layer in ["B", "T", "H", "F"]:
			var col := rim if pass_i == 0 else (back if layer == "B" else body)
			if layer == "H":
				ci.draw_circle(J.head + off, J.head_r, col)
				continue
			for sh in J.shapes:
				if sh.p == layer:
					cap(ci, sh.a + off, sh.b + off, sh.r1, sh.r2, col)
	if eyes.a > 0:
		var hc: Vector2 = J.head
		var r: float = J.head_r
		var f: int = J.f
		for dx in [-0.34, 0.06]:
			ci.draw_circle(hc + Vector2(f * r * (0.42 + dx), r * 0.05), r * 0.14, eyes)


## Simple katana: hilt at hand, blade along angle.
static func blade(ci: CanvasItem, hand: Vector2, ang: float, length: float, glow: float) -> Vector2:
	var dir := Vector2(cos(ang), sin(ang))
	var tip := hand + dir * length
	ci.draw_line(hand - dir * 10, hand, Color("#3a2a20"), 4)
	ci.draw_line(hand, tip, Color(1, 0.76, 0.4, 0.25 * glow), 7)
	ci.draw_line(hand, tip, Color("#d9dde2"), 2.5)
	return tip
