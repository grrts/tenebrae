class_name World
extends Node2D
## Loads an ASCII arena and owns tile collision.
## Legend: # rock, = bridge, - chained platform, ~ belt (all three one-way),
## w water, P portal, b brazier, I pillar, B bell, T throne, S saw.

const TS := 40.0
const ONE_WAY := "=-~"

var map_name := ""
var g: PackedStringArray = []
var cols := 0
var rows := 0
var size := Vector2.ZERO
var portals: Array[Vector2] = []
var braziers: Array[Vector2] = []
var spawn := Vector2.ZERO


func load_map(path: String) -> void:
	map_name = path.get_file().get_basename()
	var text := FileAccess.get_file_as_string(path)
	g = PackedStringArray()
	for line in text.split("\n"):
		var l := line.strip_edges(false, true)
		if l.length() > 0:
			g.append(l)
	rows = g.size()
	cols = 0
	for l in g:
		cols = maxi(cols, l.length())
	for r in rows:
		g[r] = g[r].rpad(cols, "#")
	size = Vector2(cols * TS, rows * TS)
	portals.clear()
	braziers.clear()
	for r in rows:
		for c in cols:
			var ch := g[r][c]
			var center := Vector2((c + 0.5) * TS, (r + 0.5) * TS)
			if ch == "P":
				portals.append(center)
			elif ch == "b":
				braziers.append(center)
	spawn = _find_spawn()
	queue_redraw()


## Lowest standable cell nearest the horizontal middle.
func _find_spawn() -> Vector2:
	for r in range(rows - 1, 0, -1):
		for i in cols:
			var c := cols / 2 + (i / 2 if i % 2 == 0 else -(i / 2) - 1)
			if is_solid(c, r) and not is_solid(c, r - 1) and not is_solid(c, r - 2):
				return Vector2((c + 0.5) * TS, r * TS)
	return size * 0.5


func tile(c: int, r: int) -> String:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return "#"
	return g[r][c]


func is_solid(c: int, r: int) -> bool:
	return tile(c, r) == "#"


func is_one(c: int, r: int) -> bool:
	return ONE_WAY.contains(tile(c, r))


func cell(v: float) -> int:
	return floori(v / TS)


## Moves an actor whose origin is at its feet. Solids block from every side,
## one-way tiles only catch from above (and not while dropping through).
func move(a: Actor, dt: float, drop: bool) -> void:
	var w := a.w
	var h := a.h
	a.position.x += a.vel.x * dt
	var r0 := cell(a.position.y - h + 2)
	var r1 := cell(a.position.y - 2)
	if a.vel.x >= 0 and _col_hits(cell(a.position.x + w / 2), r0, r1):
		a.position.x = cell(a.position.x + w / 2) * TS - w / 2 - 0.01
		a.vel.x = minf(a.vel.x, 0)
	if a.vel.x <= 0 and _col_hits(cell(a.position.x - w / 2), r0, r1):
		a.position.x = (cell(a.position.x - w / 2) + 1) * TS + w / 2 + 0.01
		a.vel.x = maxf(a.vel.x, 0)
	var rm := cell(a.position.y - h * 0.5)
	if is_solid(cell(a.position.x + w / 2 + 2), rm):
		a.wall = 1
	elif is_solid(cell(a.position.x - w / 2 - 2), rm):
		a.wall = -1
	else:
		a.wall = 0

	var py := a.position.y
	a.position.y += a.vel.y * dt
	a.ground = false
	var ca := cell(a.position.x - w / 2 + 1)
	var cb := cell(a.position.x + w / 2 - 1)
	if a.vel.y >= 0:
		for r in range(ceili((py - 0.5) / TS), cell(a.position.y) + 1):
			var solid := false
			var one := false
			for c in range(ca, cb + 1):
				if is_solid(c, r):
					solid = true
				elif is_one(c, r):
					one = true
			if solid or (one and not drop):
				a.position.y = r * TS
				a.vel.y = 0
				a.ground = true
				a.on_one_way = not solid
				return
	else:
		var rh := cell(a.position.y - h)
		for c in range(ca, cb + 1):
			if is_solid(c, rh):
				a.position.y = (rh + 1) * TS + h
				a.vel.y = 0
				break


func _col_hits(c: int, r0: int, r1: int) -> bool:
	for r in range(r0, r1 + 1):
		if is_solid(c, r):
			return true
	return false


# ---------- grey-box drawing ----------

const COL_BACK := Color("#2a1416")
const COL_ROCK := Color("#141017")
const COL_RIM := Color(1.0, 0.5, 0.35, 0.8)
const COL_BRIDGE := Color("#3b2a22")
const COL_CHAIN := Color("#5a5560")
const COL_WATER := Color(0.2, 0.45, 0.6, 0.35)
const COL_PORTAL := Color("#e5383b")


func _draw() -> void:
	if rows == 0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COL_BACK)
	for r in rows:
		for c in cols:
			var ch := g[r][c]
			var p := Vector2(c * TS, r * TS)
			match ch:
				"#":
					draw_rect(Rect2(p, Vector2(TS, TS)), COL_ROCK)
					if not is_solid(c, r - 1):
						draw_rect(Rect2(p, Vector2(TS, 3)), COL_RIM)
				"=", "~":
					draw_rect(Rect2(p, Vector2(TS, 10)), COL_BRIDGE)
					draw_line(p + Vector2(0, 1), p + Vector2(TS, 1), COL_RIM, 2)
				"-":
					draw_rect(Rect2(p, Vector2(TS, 6)), COL_CHAIN)
				"w":
					draw_rect(Rect2(p, Vector2(TS, TS)), COL_WATER)
				"P":
					draw_arc(p + Vector2(TS, TS) * 0.5, 16, 0, TAU, 24, COL_PORTAL, 3)
				"b":
					draw_circle(p + Vector2(TS * 0.5, TS * 0.6), 7, Color("#f2b43a"))
				"I":
					draw_rect(Rect2(p + Vector2(TS * 0.3, 0), Vector2(TS * 0.4, TS)), Color("#221a20"))
