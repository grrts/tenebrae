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
	if banner_t > 0:
		var a := clampf(banner_t * 3, 0, 1)
		_text(banner, Vector2(vp.x / 2, vp.y * 0.36), 42, Color(1, 0.95, 0.9, a), true)
		_text(banner_sub, Vector2(vp.x / 2, vp.y * 0.36 + 30), 16, Color(0.95, 0.7, 0.4, a), true)


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
