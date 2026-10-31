class_name Hud
extends CanvasLayer
## Health bar, the candle hearse (depth meter), depth title and banners.
## The hearse follows the Tenebrae service (the rite behind Wickbearer): 15 candles on a triangle go out
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
# the death screen: {depth, time, kills, bosses, wax (ash), kept, bank, unlocked, t}
var summary = null
# a cutscene: {cards, i, t, cb}
var scene = null
# the title screen: {t, cb}
var title_screen = null
# the Reliquary, opened from the title screen: {pick, t, msg, msg_t}
var reliquary = null
# the Codex screen over the title: {pick, t}
var codex = null
# true after the last input came from a gamepad, so prompts show pad buttons
var pad := false

const PAD_NAMES := {"jump": "A", "attack": "X", "dash": "RB", "pause": "START", "skill": "Y", "cancel": "B"}
const KEY_NAMES := {"jump": "SPACE", "attack": "J", "dash": "SHIFT", "pause": "ESC", "skill": "L", "cancel": "ESC"}
# achievement toasts: [{name, t}]
var toasts: Array = []
var hp_show := 1.0
var flash_col := Color.WHITE
var flash_t := 0.0


func busy() -> bool:
	return menu != null or summary != null or scene != null or title_screen != null


func open_title(cb: Callable) -> void:
	title_screen = {"t": 0.0, "cb": cb}


## Plays Story cards one by one. Jump or attack advances, Escape skips, and each card also moves on by itself.
func play(cards: Array, cb: Callable) -> void:
	if cards.is_empty():
		cb.call()
		return
	scene = {"cards": cards, "i": 0, "t": 0.0, "cb": cb}
	_card_start()


func flash(col: Color, t := 0.25) -> void:
	if not game.opt_flashes:
		return
	flash_col = col
	flash_t = t


func _card_dur(c: Dictionary) -> float:
	if game.smoke:
		return 0.35
	return 3.2 if c.has("title") else 1.6 + String(c.get("text", "")).length() * 0.045


func _card_start() -> void:
	var c: Dictionary = scene.cards[scene.i]
	if c.has("flash"):
		flash(c.flash, 0.22)
	if c.has("sfx"):
		game.shake(0.35, 14)


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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false


## The on-screen name of the button for an action, for whichever device was used last.
func btn(action: String) -> String:
	return PAD_NAMES[action] if pad else KEY_NAMES[action]


func _process(dt: float) -> void:
	banner_t = maxf(0, banner_t - dt)
	flash_t = maxf(0, flash_t - dt)
	for tst in toasts:
		tst.t += dt
	toasts = toasts.filter(func(tst): return tst.t < 4.0)
	if title_screen != null and reliquary != null:
		_step_reliquary(dt)
	elif title_screen != null and codex != null:
		_step_codex(dt)
	elif title_screen != null:
		title_screen.t += dt
		if title_screen.t > 0.4 and Input.is_action_just_pressed("dash"):
			reliquary = {"pick": 0, "t": 0.0, "msg": "", "msg_t": 0.0}
		if title_screen.t > 0.4 and Input.is_action_just_pressed("skill"):
			codex = {"pick": 0, "t": 0.0}
		if Input.is_action_just_pressed("left"):
			game.vigil = maxi(0, game.vigil - 1)
		if Input.is_action_just_pressed("right"):
			game.vigil = mini(game.vigil_max, game.vigil + 1)
		if title_screen.t > 0.4 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
			var tcb: Callable = title_screen.cb
			title_screen = null
			tcb.call()
	elif scene != null:
		scene.t += dt
		var c: Dictionary = scene.cards[scene.i]
		var press: bool = scene.t > 0.35 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"))
		var skip := Input.is_action_just_pressed("ui_cancel")
		if skip or press or scene.t > _card_dur(c):
			scene.i += 1
			scene.t = 0.0
			if skip or scene.i >= scene.cards.size():
				var cb: Callable = scene.cb
				scene = null
				cb.call()
			else:
				_card_start()
	elif menu != null:
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
			game.start(0)
	elif Input.is_action_just_pressed("pause") and game.player != null and not game.player.dead:
		game.open_pause()
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
	# health bar: the gold trail shows recent damage. HP shows as 20 per internal hit point
	var mh := int(p.max_hp)
	var bw := 34.0 * mh
	var bx := vp.x - 30 - bw
	var hk := clampf(p.hp / p.max_hp, 0, 1)
	hp_show = move_toward(hp_show, hk, get_process_delta_time() * 0.6) if hp_show > hk else hk
	canvas.draw_rect(Rect2(bx - 2, 20, bw + 4, 18), Color(0, 0, 0, 0.75))
	canvas.draw_rect(Rect2(bx, 22, bw * hp_show, 14), Color(0.95, 0.7, 0.23, 0.55))
	canvas.draw_rect(Rect2(bx, 22, bw * hk, 14), Color("#e5383b"))
	_text("%d / %d HP" % [int(p.hp) * 20, mh * 20], Vector2(bx - 104, 35), 13, Color("#f3ebe0"))
	# weapon skill meter under the health bar
	if game.weapon != "":
		var full := game.skill_meter >= 1.0
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01) if full else 1.0
		canvas.draw_rect(Rect2(bx - 2, 42, bw + 4, 8), Color(0, 0, 0, 0.75))
		canvas.draw_rect(Rect2(bx, 44, bw * game.skill_meter, 4), Color(0.95, 0.7, 0.23, pulse))
		_text(("%s  ·  L" % RunData.SKILLS[game.weapon].name) if full else RunData.SKILLS[game.weapon].name, Vector2(bx, 64), 10, Color("#f2b43a") if full else Color(0.6, 0.57, 0.54))
	# depth title
	var title := "DEPTH %s" % Game.roman(game.depth)
	_text(title, Vector2(vp.x / 2, 52), 34, Color("#e5383b") if game.depth >= 7 else Color("#f3ebe0"), true)
	var k := game.depth_t / game.depth_time
	canvas.draw_rect(Rect2(vp.x / 2 - 110, 64, 220, 5), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(vp.x / 2 - 110, 64, 220 * k, 5), Color("#e5383b"))
	var ch: Dictionary = Story.CHAPTERS[Story.chapter_of(game.depth)]
	_text(ch.name, Vector2(vp.x / 2, 88), 12, ch.col, true)
	_hearse(Vector2(vp.x - 200, 110))
	# ash and level
	_text("%d ASH" % game.run_wax, Vector2(vp.x - 200, 160), 14, Color("#3fd6c4"))
	_text("LV %d" % game.lvl, Vector2(vp.x - 200, 180), 14, Color(0.6, 0.57, 0.54))
	canvas.draw_rect(Rect2(0, vp.y - 6, vp.x, 6), Color(0, 0, 0, 0.7))
	canvas.draw_rect(Rect2(0, vp.y - 6, vp.x * game.xp / game.xp_need(), 6), Color("#3fd6c4"))
	var build: String = RunData.WEAPONS[game.weapon].name if game.weapon != "" else ""
	for r in game.runes:
		build += "  ·  " + r
	for sg in game.sets_done:
		build += "  ·  %s SET" % sg
	if game.vigil > 0:
		build = "VIGIL %s  ·  %s" % [Game.roman(game.vigil), build]
	_text(build, Vector2(16, vp.y - 16), 13, Color(0.8, 0.76, 0.7))
	if banner_t > 0:
		var a := clampf(banner_t * 3, 0, 1)
		_text(banner, Vector2(vp.x / 2, vp.y * 0.36), 42, Color(1, 0.95, 0.9, a), true)
		_text(banner_sub, Vector2(vp.x / 2, vp.y * 0.36 + 30), 16, Color(0.95, 0.7, 0.4, a), true)


	if p.dead and summary == null:
		_paint_death(vp)
	if title_screen != null:
		_paint_title(vp)
		if reliquary != null:
			_paint_reliquary(vp)
		elif codex != null:
			_paint_codex(vp)
	elif scene != null:
		_paint_scene(vp)
	elif menu != null:
		_paint_menu(vp)
	elif summary != null:
		_paint_summary(vp)
	for i in toasts.size():
		var tst: Dictionary = toasts[i]
		var a := clampf(minf(tst.t * 4, (4.0 - tst.t) * 2), 0, 1)
		var r := Rect2(vp.x - 330, vp.y - 110 - i * 64, 310, 54)
		canvas.draw_rect(r, Color(0.04, 0.03, 0.05, 0.9 * a))
		canvas.draw_rect(r, Color(0.95, 0.7, 0.23, a), false, 1.5)
		_text(tst.get("head", "ACHIEVEMENT"), r.position + Vector2(14, 20), 11, Color(0.95, 0.7, 0.23, a))
		_text(tst.name, r.position + Vector2(14, 42), 18, Color(0.95, 0.92, 0.88, a))
	if flash_t > 0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(flash_col, clampf(flash_t * 4, 0, 1) * 0.85))


func _paint_title(vp: Vector2) -> void:
	var t: float = title_screen.t
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.02, 0.96))
	var mid := vp / 2
	# a slow candle glow behind the name
	for i in 6:
		canvas.draw_circle(Vector2(mid.x, mid.y - 70), 40.0 + i * 34, Color(1, 0.65, 0.25, 0.035))
	_text("WICKBEARER", Vector2(mid.x, mid.y - 50), 84, Color(0.95, 0.92, 0.88, clampf(t * 1.5, 0, 1)), true)
	_text("FIFTEEN CANDLES  ·  ONE HIDDEN FLAME  ·  BRING IT HOME", Vector2(mid.x, mid.y - 10), 14, Color("#f2b43a"), true)
	if game.vigil_max > 0:
		var v := game.vigil
		_text("<   VIGIL %s   >" % (Game.roman(v) if v > 0 else "0"), Vector2(mid.x, mid.y + 50), 22, Color("#e5383b") if v > 0 else Color("#f3ebe0"), true)
		_text(RunData.VIGILS[v] if v == 0 else "Every Vigil up to %s:  %s" % [Game.roman(v), RunData.VIGILS[v]], Vector2(mid.x, mid.y + 76), 14, Color(0.7, 0.66, 0.62), true)
	var stats := "BANKED ASH %d   ·   DEEPEST %s   ·   DAWNS %d" % [game.bank, Game.roman(maxi(1, game.best_depth)), game.wins]
	_text(stats + "   ·   ACHIEVEMENTS %d / %d" % [game.achieved.size(), Achievements.LIST.size()], Vector2(mid.x, vp.y - 110), 13, Color(0.6, 0.57, 0.54), true)
	var blink := 0.5 + 0.5 * sin(t * 4)
	_text("PRESS %s TO DESCEND" % btn("jump"), Vector2(mid.x, vp.y - 70), 16, Color(0.95, 0.92, 0.88, 0.4 + 0.6 * blink), true)
	var open := RunData.RELICS.filter(func(r): return not r.id in game.relics).size()
	var rq := "%s  THE RELIQUARY  ·  %d TO BUY" % [btn("dash"), open] if open > 0 else "THE RELIQUARY IS COMPLETE"
	var cx := "%s  THE CODEX  ·  %d / %d" % [btn("skill"), game.codex.size(), Codex.ENTRIES.size()]
	_text(rq + "      " + cx, Vector2(mid.x, vp.y - 44), 12, Color("#3fd6c4"), true)


func _step_codex(dt: float) -> void:
	var c: Dictionary = codex
	c.t += dt
	var n := Codex.ENTRIES.size()
	if Input.is_action_just_pressed("up"):
		c.pick = (c.pick + n - 1) % n
	if Input.is_action_just_pressed("down"):
		c.pick = (c.pick + 1) % n
	if c.t > 0.25 and (Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("skill")):
		codex = null


func _paint_codex(vp: Vector2) -> void:
	var c: Dictionary = codex
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.02, 0.95))
	var mid := vp / 2
	_text("THE CODEX", Vector2(mid.x, 70), 40, Color("#f3ebe0"), true)
	_text("%d OF %d PAGES  ·  EVERYTHING THE DARK HAS SHOWN YOU" % [game.codex.size(), Codex.ENTRIES.size()], Vector2(mid.x, 96), 13, Color("#3fd6c4"), true)
	var cols := {Codex.LORE: Color("#f2b43a"), Codex.PLACE: Color("#3fd6c4"), Codex.FOE: Color("#e5383b"), Codex.BOSS: Color("#b44dff")}
	var x0 := mid.x - 440
	var rows := 14
	var top := clampi(c.pick - rows / 2, 0, maxi(0, Codex.ENTRIES.size() - rows))
	for j in mini(rows, Codex.ENTRIES.size()):
		var i := top + j
		var e: Dictionary = Codex.ENTRIES[i]
		var y := 124.0 + j * 30
		var known: bool = e.id in game.codex
		if i == c.pick:
			canvas.draw_rect(Rect2(x0, y, 300, 26), Color(0.08, 0.06, 0.09, 1))
			canvas.draw_rect(Rect2(x0, y, 300, 26), Color("#f2b43a"), false, 2)
		_text(e.cat, Vector2(x0 + 10, y + 17), 9, cols[e.cat])
		_text(e.name if known else "? ? ?", Vector2(x0 + 64, y + 18), 14, Color("#f3ebe0") if known else Color(0.4, 0.37, 0.35))
	var sel: Dictionary = Codex.ENTRIES[c.pick]
	var bx := x0 + 330
	canvas.draw_rect(Rect2(bx, 124, 550, 400), Color(0.05, 0.04, 0.06, 1))
	if sel.id in game.codex:
		_text(sel.name, Vector2(bx + 24, 164), 24, cols[sel.cat])
		var y2 := 200.0
		for line in _wrap(sel.text, 500, 16):
			_text(line, Vector2(bx + 24, y2), 16, Color(0.85, 0.8, 0.76))
			y2 += 24
	else:
		_text("This page is still dark.", Vector2(bx + 24, 164), 18, Color(0.5, 0.46, 0.43))
		_text("Keep descending.", Vector2(bx + 24, 192), 14, Color(0.4, 0.37, 0.35))
	_text("UP / DOWN  CHOOSE      %s  BACK" % btn("dash"), Vector2(mid.x, vp.y - 30), 12, Color(0.55, 0.5, 0.47), true)


func _step_reliquary(dt: float) -> void:
	var r: Dictionary = reliquary
	r.t += dt
	r.msg_t = maxf(0, r.msg_t - dt)
	var n := RunData.RELICS.size()
	if Input.is_action_just_pressed("up"):
		r.pick = (r.pick + n - 1) % n
	if Input.is_action_just_pressed("down"):
		r.pick = (r.pick + 1) % n
	if r.t > 0.25 and (Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("pause")):
		reliquary = null
		return
	if r.t > 0.25 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
		var rel: Dictionary = RunData.RELICS[r.pick]
		if rel.id in game.relics:
			r.msg = "ALREADY YOURS"
		elif game.buy_relic(r.pick):
			r.msg = "%s IS YOURS" % rel.name
		else:
			r.msg = "NOT ENOUGH ASH"
		r.msg_t = 1.6


func _paint_reliquary(vp: Vector2) -> void:
	var r: Dictionary = reliquary
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.02, 0.95))
	var mid := vp / 2
	_text("THE RELIQUARY", Vector2(mid.x, 80), 40, Color("#f3ebe0"), true)
	_text("BANKED ASH %d  ·  WHAT YOU BUY HERE STAYS FOREVER" % game.bank, Vector2(mid.x, 108), 13, Color("#3fd6c4"), true)
	var x0 := mid.x - 360
	for i in RunData.RELICS.size():
		var rel: Dictionary = RunData.RELICS[i]
		var y := 140.0 + i * 46
		var sel: bool = i == r.pick
		var owned: bool = rel.id in game.relics
		var can: bool = game.bank >= rel.cost
		canvas.draw_rect(Rect2(x0, y, 720, 40), Color(0.08, 0.06, 0.09, 1) if sel else Color(0.05, 0.04, 0.06, 1))
		if sel:
			canvas.draw_rect(Rect2(x0, y, 720, 40), Color("#f2b43a"), false, 2)
		var col := Color(0.55, 0.52, 0.5) if owned else (Color("#f3ebe0") if can else Color(0.45, 0.42, 0.4))
		_text(rel.kind, Vector2(x0 + 14, y + 25), 10, Color("#3fd6c4") if rel.kind == "PERK" else (Color("#f2b43a") if rel.kind == "WEAPON" else Color("#b44dff")))
		_text(rel.name, Vector2(x0 + 80, y + 18), 15, col)
		_text(rel.desc, Vector2(x0 + 80, y + 35), 11, Color(0.75, 0.7, 0.66) if not owned else Color(0.5, 0.47, 0.45))
		_text("OWNED" if owned else "%d ASH" % rel.cost, Vector2(x0 + 650, y + 26), 13, Color("#3fd6c4") if owned else (Color("#f2b43a") if can else Color(0.5, 0.45, 0.4)))
	if r.msg_t > 0:
		_text(r.msg, Vector2(mid.x, vp.y - 70), 20, Color("#f2b43a"), true)
	_text("UP / DOWN  CHOOSE      %s  BUY      %s  BACK" % [btn("jump"), btn("dash")], Vector2(mid.x, vp.y - 30), 12, Color(0.55, 0.5, 0.47), true)


## Souls-like death: a black band fades in and EXTINGUISHED slowly grows in it.
func _paint_death(vp: Vector2) -> void:
	var t := game.dead_t
	var a := clampf((t - 0.5) * 1.5, 0, 1)
	if a <= 0:
		return
	var cy := vp.y * 0.46
	canvas.draw_rect(Rect2(0, cy - 70, vp.x, 140), Color(0, 0, 0, 0.82 * a))
	var size := int(58 + t * 6)
	_text("EXTINGUISHED", Vector2(vp.x / 2, cy + 18), size, Color(0.75, 0.1, 0.12, a), true)
	_text("The dark keeps what it takes.", Vector2(vp.x / 2, cy + 52), 16, Color(0.75, 0.7, 0.66, clampf((t - 1.4) * 2, 0, 1)), true)


func _wrap(s: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for wd in s.split(" "):
		if line != "" and font.get_string_size(line + " " + wd, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = wd
		else:
			line = wd if line == "" else line + " " + wd
	if line != "":
		out.append(line)
	return out


## Anime-style card: letterbox bars, focus lines behind impact words, a title card or a line of dialogue.
func _paint_scene(vp: Vector2) -> void:
	var c: Dictionary = scene.cards[scene.i]
	var t: float = scene.t
	var col: Color = c.get("col", Color("#f2b43a"))
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.02, 0.94))
	var mid := vp / 2
	if c.has("sfx"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 20)
		for i in 48:
			var ang := rng.randf() * TAU
			var r0 := rng.randf_range(140, 260)
			canvas.draw_line(mid + Vector2(cos(ang), sin(ang)) * r0, mid + Vector2(cos(ang), sin(ang)) * vp.length(), Color(1, 1, 1, 0.08), rng.randf_range(1, 4))
		var k := 1.0 + maxf(0, 0.4 - t) * 1.5
		_text(c.sfx, Vector2(mid.x, vp.y * 0.3), int(70 * k), Color("#e5383b"), true)
	var bar := 70.0
	canvas.draw_rect(Rect2(0, 0, vp.x, bar), Color.BLACK)
	canvas.draw_rect(Rect2(0, vp.y - bar, vp.x, bar), Color.BLACK)
	var a := clampf(t * 4, 0, 1)
	if c.has("title"):
		canvas.draw_line(Vector2(mid.x - 200 * a, mid.y + 12), Vector2(mid.x + 200 * a, mid.y + 12), Color(col, 0.6), 1.5)
		_text(c.title, Vector2(mid.x, mid.y - 6), 52, Color(0.95, 0.92, 0.88, a), true)
		_text(c.sub, Vector2(mid.x, mid.y + 42), 15, Color(col, a), true)
	else:
		var y := mid.y + 10
		if c.has("who"):
			# diagonal name plate
			var nw := font.get_string_size(c.who, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40
			var px := mid.x - nw / 2
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(px + 12, y - 72), Vector2(px + nw + 12, y - 72), Vector2(px + nw - 12, y - 42), Vector2(px - 12, y - 42)]), Color(col, 0.9 * a))
			_text(c.who, Vector2(mid.x, y - 50), 18, Color(0.05, 0.03, 0.04, a), true)
		var lines := _wrap(String(c.text), minf(760, vp.x - 80), 22)
		for i in lines.size():
			_text(lines[i], Vector2(mid.x, y + i * 32), 22, Color(0.92, 0.88, 0.84, a), true)
	_text("%s  NEXT      %s  SKIP" % [btn("jump"), btn("cancel")], Vector2(vp.x - 130, vp.y - 30), 11, Color(0.55, 0.5, 0.47), true)


func _paint_menu(vp: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.015, 0.88))
	_text(menu.title, Vector2(vp.x / 2, 110), 40, Color("#f3ebe0"), true)
	_text(menu.sub, Vector2(vp.x / 2, 140), 14, Color(0.6, 0.57, 0.54), true)
	var n: int = menu.opts.size()
	var gap := 26.0 if n <= 4 else 14.0
	var cw := minf(240.0, (vp.x - 60 - (n - 1) * gap) / n)
	var x0 := (vp.x - n * cw - (n - 1) * gap) / 2
	for i in n:
		var o: Dictionary = menu.opts[i]
		var r := Rect2(x0 + i * (cw + gap), 180, cw, 280)
		var sel: bool = i == menu.pick
		canvas.draw_rect(r, Color(0.06, 0.05, 0.07, 1))
		canvas.draw_rect(r, Color("#f2b43a") if sel else Color(0.35, 0.3, 0.28), false, 3.0 if sel else 1.5)
		var col: Color = o.get("col", Color("#f3ebe0"))
		_text(o.get("tag", ""), Vector2(r.position.x + cw / 2, r.position.y + 34), 12, col, true)
		_text(o.name, Vector2(r.position.x + cw / 2, r.position.y + 120), 26 if n <= 4 else 17, col, true)
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
	_text("LEFT / RIGHT  CHOOSE      %s  CONFIRM" % btn("jump"), Vector2(vp.x / 2, 500), 13, Color(0.5, 0.47, 0.44), true)


func _paint_summary(vp: Vector2) -> void:
	var s: Dictionary = summary
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.015, minf(0.92, s.t * 2)))
	_text(s.title, Vector2(vp.x / 2, 120), 64, s.col, true)
	var cols := [["DEPTH", Game.roman(s.depth)], ["TIME", "%d:%02d" % [int(s.time) / 60, int(s.time) % 60]], ["BOSSES", str(s.bosses)], ["KILLS", str(s.kills)]]
	for i in cols.size():
		var x := vp.x / 2 + (i - 1.5) * 160
		_text(cols[i][0], Vector2(x, 190), 13, Color(0.6, 0.57, 0.54), true)
		_text(cols[i][1], Vector2(x, 236), 40, Color("#f3ebe0"), true)
	_text("ASH COLLECTED %d   ·   %s%s +%d" % [s.wax, "ALL KEPT" if s.won else "40% KEPT", " + BOSS BONUS" if s.bosses > 0 else "", s.kept], Vector2(vp.x / 2, 300), 16, Color("#3fd6c4"), true)
	_text("BANKED ASH %d" % s.bank, Vector2(vp.x / 2, 330), 16, Color("#f3ebe0"), true)
	if s.unlocked != "":
		_text("UNLOCKED · %s" % s.unlocked, Vector2(vp.x / 2, 380), 30, Color("#f2b43a"), true)
	if s.t > 1.2:
		_text("PRESS %s TO RELIGHT THE CANDLES" % btn("jump"), Vector2(vp.x / 2, vp.y - 60), 14, Color(0.6, 0.57, 0.54), true)


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
