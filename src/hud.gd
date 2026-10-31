class_name Hud
extends CanvasLayer
## Hearts, the candle hearse (depth meter), depth title and banners.
## The hearse follows the Tenebrae service: 15 candles on a triangle go out
## one per depth, alternating from the two ends toward the top. The small
## crimson candle under it is the hidden candle, the one revive per run.

var game: Game
var canvas: Node2D
var banner := ""
var banner_sub := ""
var banner_t := 0.0
var font: Font
# an open choice: {title, sub, opts: [{name, desc, tag, col}], pick, cb, t}
var menu = null
# the death screen: {depth, time, kills, bosses, wax, kept, bank, unlocked, t}
var summary = null


func busy() -> bool:
	return menu != null or summary != null


func open_choice(title: String, sub: String, opts: Array, cb: Callable) -> void:
	menu = {"title": title, "sub": sub, "opts": opts, "pick": 0, "cb": cb, "t": 0.0}


func open_summary(data: Dictionary) -> void:
	summary = data
	summary.t = 0.0


func _ready() -> void:
	layer = 5
	font = ThemeDB.fallback_font
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_paint)


func show_banner(text: String, sub: String, t := 1.6) -> void:
	banner = text
	banner_sub = sub
	banner_t = t


func _process(dt: float) -> void:
	banner_t = maxf(0, banner_t - dt)
	if menu != null:
		menu.t += dt
		var n: int = menu.opts.size()
		if Input.is_action_just_pressed("left"):
			menu.pick = (menu.pick + n - 1) % n
		if Input.is_action_just_pressed("right"):
			menu.pick = (menu.pick + 1) % n
		if menu.t > 0.3 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
			var m = menu
			menu = null
			m.cb.call(m.pick)
	elif summary != null:
		summary.t += dt
		if summary.t > 1.2 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
			summary = null
			game.start(game.map_i)
	canvas.queue_redraw()


func _text(s: String, pos: Vector2, size: int, col: Color, center := false) -> void:
	var x := pos.x
	if center:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	canvas.draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color.BLACK)
	canvas.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _paint() -> void:
	var vp := canvas.get_viewport_rect().size
	var p := game.player
	if p == null:
		return
	# hearts
	for i in int(p.max_hp):
		var c := Color("#e5383b") if i < p.hp else Color(0.25, 0.2, 0.2)
		canvas.draw_circle(Vector2(vp.x - 30 - i * 24, 30), 8, c)
	# depth title
	var title := "DEPTH %s" % Game.roman(game.depth)
	_text(title, Vector2(vp.x / 2, 52), 34, Color("#e5383b") if game.depth >= 7 else Color("#f3ebe0"), true)
	var k := game.depth_t / game.depth_time
	canvas.draw_rect(Rect2(vp.x / 2 - 110, 64, 220, 5), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(vp.x / 2 - 110, 64, 220 * k, 5), Color("#e5383b"))
	_hearse(Vector2(vp.x - 200, 110))
	# wax and level
	_text("%d WAX" % game.run_wax, Vector2(vp.x - 200, 160), 14, Color("#3fd6c4"))
	_text("LV %d" % game.lvl, Vector2(vp.x - 200, 180), 14, Color(0.6, 0.57, 0.54))
	canvas.draw_rect(Rect2(0, vp.y - 6, vp.x, 6), Color(0, 0, 0, 0.7))
	canvas.draw_rect(Rect2(0, vp.y - 6, vp.x * game.xp / game.xp_need(), 6), Color("#3fd6c4"))
	var build: String = RunData.WEAPONS[game.weapon].name if game.weapon != "" else ""
	for r in game.runes:
		build += "  ·  " + r
	_text(build, Vector2(16, vp.y - 16), 13, Color(0.8, 0.76, 0.7))
	if banner_t > 0:
		var a := clampf(banner_t * 3, 0, 1)
		_text(banner, Vector2(vp.x / 2, vp.y * 0.36), 42, Color(1, 0.95, 0.9, a), true)
		_text(banner_sub, Vector2(vp.x / 2, vp.y * 0.36 + 30), 16, Color(0.95, 0.7, 0.4, a), true)


	if menu != null:
		_paint_menu(vp)
	elif summary != null:
		_paint_summary(vp)


func _paint_menu(vp: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.015, 0.88))
	_text(menu.title, Vector2(vp.x / 2, 110), 40, Color("#f3ebe0"), true)
	_text(menu.sub, Vector2(vp.x / 2, 140), 14, Color(0.6, 0.57, 0.54), true)
	var n: int = menu.opts.size()
	var cw := 240.0
	var gap := 26.0
	var x0 := (vp.x - n * cw - (n - 1) * gap) / 2
	for i in n:
		var o: Dictionary = menu.opts[i]
		var r := Rect2(x0 + i * (cw + gap), 180, cw, 280)
		var sel: bool = i == menu.pick
		canvas.draw_rect(r, Color(0.06, 0.05, 0.07, 1))
		canvas.draw_rect(r, Color("#f2b43a") if sel else Color(0.35, 0.3, 0.28), false, 3.0 if sel else 1.5)
		var col: Color = o.get("col", Color("#f3ebe0"))
		_text(o.get("tag", ""), Vector2(r.position.x + cw / 2, r.position.y + 34), 12, col, true)
		_text(o.name, Vector2(r.position.x + cw / 2, r.position.y + 120), 26, col, true)
		var words: PackedStringArray = String(o.desc).split(" ")
		var line := ""
		var y := r.position.y + 160
		for wd in words:
			if font.get_string_size(line + " " + wd, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > cw - 30:
				_text(line.strip_edges(), Vector2(r.position.x + cw / 2, y), 15, Color(0.85, 0.8, 0.75), true)
				y += 22
				line = ""
			line += " " + wd
		_text(line.strip_edges(), Vector2(r.position.x + cw / 2, y), 15, Color(0.85, 0.8, 0.75), true)
	_text("LEFT / RIGHT  CHOOSE      SPACE / J  CONFIRM", Vector2(vp.x / 2, 500), 13, Color(0.5, 0.47, 0.44), true)


func _paint_summary(vp: Vector2) -> void:
	var s: Dictionary = summary
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.015, minf(0.92, s.t * 2)))
	_text("LIGHTS OUT", Vector2(vp.x / 2, 120), 64, Color("#e5383b"), true)
	var cols := [["DEPTH", Game.roman(s.depth)], ["TIME", "%d:%02d" % [int(s.time) / 60, int(s.time) % 60]], ["BOSSES", str(s.bosses)], ["KILLS", str(s.kills)]]
	for i in cols.size():
		var x := vp.x / 2 + (i - 1.5) * 160
		_text(cols[i][0], Vector2(x, 190), 13, Color(0.6, 0.57, 0.54), true)
		_text(cols[i][1], Vector2(x, 236), 40, Color("#f3ebe0"), true)
	_text("WAX COLLECTED %d   ·   40%% KEPT%s +%d" % [s.wax, " + BOSS BONUS" if s.bosses > 0 else "", s.kept], Vector2(vp.x / 2, 300), 16, Color("#3fd6c4"), true)
	_text("BANKED WAX %d" % s.bank, Vector2(vp.x / 2, 330), 16, Color("#f3ebe0"), true)
	if s.unlocked != "":
		_text("UNLOCKED · %s" % s.unlocked, Vector2(vp.x / 2, 380), 30, Color("#f2b43a"), true)
	if s.t > 1.2:
		_text("PRESS SPACE OR J TO RELIGHT THE CANDLES", Vector2(vp.x / 2, vp.y - 60), 14, Color(0.6, 0.57, 0.54), true)


func _hearse(o: Vector2) -> void:
	var w := 170.0
	var top := 52.0
	var out := game.candles_out()
	var t := Time.get_ticks_msec() / 1000.0
	var wood := Color("#3a2f2a")
	canvas.draw_polyline(PackedVector2Array([o, o + Vector2(w / 2, -top), o + Vector2(w, 0)]), wood, 3)
	canvas.draw_line(o + Vector2(w / 2, 0), o + Vector2(w / 2, 14), wood, 3)
	for i in 15:
		var order := 14 - (i >> 1) if i % 2 == 1 else i >> 1
		var lit := i >= out
		var cx := o.x + 5 + order * (w - 10) / 14.0
		var cy := o.y - top * (1 - absf(order - 7) / 7.0) - 2
		canvas.draw_rect(Rect2(cx - 1.5, cy - 9, 3, 9), Color("#e8dccb") if lit else Color("#5a524c"))
		if lit:
			var fl := 1 + sin(t * 13 + i * 1.7) * 0.15
			canvas.draw_circle(Vector2(cx, cy - 12), 5 * fl, Color(1, 0.7, 0.25, 0.25))
			canvas.draw_circle(Vector2(cx, cy - 12), 2.4 * fl, Color("#f2b43a"))
		else:
			canvas.draw_line(Vector2(cx, cy - 10), Vector2(cx + sin(t * 2 + i) * 3, cy - 20), Color(0.8, 0.75, 0.7, 0.25), 1)
	var hc := o + Vector2(w / 2, 28)
	canvas.draw_rect(Rect2(hc.x - 1.5, hc.y - 7, 3, 7), Color("#e8dccb") if game.hidden_candle else Color("#5a524c"))
	if game.hidden_candle:
		canvas.draw_circle(hc + Vector2(0, -10), 2.6, Color("#e5383b"))
	_text("%d OF 15 LIT" % (15 - out), o + Vector2(w / 2 + 12, 26), 12, Color(0.6, 0.57, 0.54))
