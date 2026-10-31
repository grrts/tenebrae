extends Node
## Sfx (autoload): the Godot build's sound, music and voices.
##
## The audio files in res://audio are rendered from the browser build's procedural
## sound (web/audio.js) by tools/render_audio.js, so both builds sound the same and
## every sound is original. Like the browser build, this node never asks the game
## to call it: once per frame it compares the Game's state with the last frame and
## plays what changed. M mutes.
##
##   audio/sfx/*.ogg    one-shot sounds
##   audio/music/chN_{base,drums,boss}.ogg   loop stems per chapter, mixed live
##   audio/vo/<md5 of the line>.ogg          a gibberish voice for each spoken line in story.gd

const POOL := 24
const MUSIC_DB := -9.0

var pool: Array[AudioStreamPlayer] = []
var next_p := 0
var cache := {}
var last := {}
var muted := false
var played := 0

var layers := {}
var layer_db := {"base": -80.0, "drums": -80.0, "boss": -80.0}
var music_ch := -1
var music_bus := -1
var lowpass: AudioEffectLowPassFilter
var voice: AudioStreamPlayer
var inten := 0.0

var game: Node = null
var P := {}
var hp_of := {}
var seen_e := {}
var prev_hexes: Array = []
var wax_n := 0
var wax_t := 0.0
var step_ph := 0
var card_key := ""
var death_stage := -1
var fall_v := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# music runs through its own bus, so menus and the death can muffle it
	music_bus = AudioServer.bus_count
	AudioServer.add_bus(music_bus)
	AudioServer.set_bus_name(music_bus, "Music")
	AudioServer.set_bus_send(music_bus, "Master")
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000
	AudioServer.add_bus_effect(music_bus, lowpass)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for k in ["base", "drums", "boss"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		add_child(p)
		layers[k] = p
	voice = AudioStreamPlayer.new()
	voice.volume_db = 2.0
	add_child(voice)


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)


func _stream(path: String) -> AudioStream:
	if cache.has(path):
		return cache[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	cache[path] = s
	return s


## Plays res://audio/sfx/<sound>.ogg. A sound can't restart within gap seconds.
func play(sound: String, db := 0.0, pitch := 1.0, gap := 0.03) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(sound, -9.0)) < gap:
		return
	last[sound] = now
	var s := _stream("res://audio/sfx/%s.ogg" % sound)
	if s == null:
		return
	var p := pool[next_p]
	next_p = (next_p + 1) % POOL
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
	played += 1


func say(text: String) -> void:
	voice.stop()
	var s := _stream("res://audio/vo/%s.ogg" % text.md5_text().substr(0, 10))
	if s != null:
		voice.stream = s
		voice.play()
		played += 1


func _set_chapter(ch: int) -> void:
	music_ch = ch
	for k in layers:
		var s := _stream("res://audio/music/ch%d_%s.ogg" % [ch, k])
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		var p: AudioStreamPlayer = layers[k]
		p.stream = s
		if s != null:
			p.play()


func _g(o: Object, k: String, d = null):
	if o == null:
		return d
	var v = o.get(k)
	return d if v == null else v


func _process(dt: float) -> void:
	var cs := get_tree().current_scene
	if cs == null or not cs.has_method("next_depth"):
		return
	if cs != game:
		game = cs
		P.clear()
		hp_of.clear()
		seen_e.clear()
		prev_hexes = []
	var pl: Node2D = _g(game, "player")
	var hud: Node = _g(game, "hud")
	if pl == null or hud == null:
		return
	var first := P.is_empty()
	var enemies: Array = _g(game, "enemies", [])
	var boss: Node2D = _g(game, "boss")
	var hexes: Array = _g(game, "hexes", [])
	var menu = _g(hud, "menu")
	var scene = _g(hud, "scene")
	var summary = _g(hud, "summary")
	var title = _g(hud, "title_screen")
	var banner: String = _g(hud, "banner", "")
	var pdead: bool = _g(pl, "dead", false)
	var busy: bool = menu != null or scene != null or summary != null or title != null

	if not first:
		# ---- cutscene cards: a cue per card, and the speaker's voice
		if scene != null:
			var i: int = scene.i
			var key := "%d:%d" % [scene.cards.hash(), i]
			if key != card_key:
				card_key = key
				var c: Dictionary = scene.cards[i]
				if c.has("flash"):
					var fc: Color = c.flash
					play("flash_red" if fc.g < 0.5 else "flash_white")
				else:
					play("shot", -4)
				if c.has("sfx"):
					play("rumble")
					play("focus", -3)
				if c.has("title"):
					play("card")
					voice.stop()
				if c.has("text"):
					say(String(c.text))
		elif card_key != "":
			card_key = ""
			voice.stop()
		# ---- title, menus, the summary
		if title != null and P.title == null:
			play("card", -4)
		if title == null and P.title != null:
			play("ui_ok")
		if menu != null and P.menu == null:
			play("ui_open")
		elif menu != null and menu.pick != P.pick:
			play("ui_move", -2)
		if menu == null and P.menu != null:
			play("ui_ok")
		if summary != null and P.summary == null:
			play("over_victory" if summary.get("won", false) else "over")

		if not busy and not pdead:
			# ---- the player
			var atk = _g(pl, "atk")
			if atk != null and (P.atk_step == -1 or atk.step != P.atk_step or float(atk.t) < P.atk_t):
				var w: String = _g(game, "weapon", "katana")
				play("swing_%s%s" % [w if w != "" else "katana", "_big" if atk.step == 2 else ""], 0.0, randf_range(0.95, 1.05), 0.02)
			var gr: bool = _g(pl, "ground", false)
			var vel: Vector2 = _g(pl, "vel", Vector2.ZERO)
			if float(_g(pl, "dash", 0.0)) > 0 and P.dash <= 0:
				play("dash")
			if _g(pl, "dj_used", false) and not P.dj:
				play("djump")
			elif float(_g(pl, "kick", 0.0)) > P.kick + 0.05:
				play("wall")
			elif P.ground and not gr and vel.y < -500:
				play("jump")
			if float(_g(pl, "drop_t", 0.0)) > P.drop + 0.05:
				play("drop")
			var slam: bool = _g(pl, "slam", false)
			if slam and not P.slam:
				play("slam_start")
			if not gr:
				fall_v = maxf(fall_v, vel.y)
			if gr and not P.ground:
				if P.slam:
					play("slam_heavy" if game.call("has_rune", "HEAVY SHADOW") else "slam")
				else:
					play("land", linear_to_db(clampf(fall_v / 1400.0, 0.15, 1.0)))
				fall_v = 0.0
			if gr and absf(vel.x) > 70 and float(_g(pl, "dash", 0.0)) <= 0:
				var ph := int(floor(float(_g(pl, "run_ph", 0.0)) / PI))
				if ph != step_ph:
					step_ph = ph
					play("step", -4, randf_range(0.9, 1.1), 0.09)

		# ---- hearts, the hidden candle, levels, wax
		var hp: float = _g(pl, "hp", 0.0)
		if hp < P.hp and hp > 0:
			play("hurt")
		elif hp > P.hp and P.hidden == _g(game, "hidden_candle", false):
			play("heal")
		if P.hidden and not _g(game, "hidden_candle", true):
			play("revive")
		if int(_g(game, "lvl", 1)) > P.lvl:
			play("level")
		if int(_g(game, "run_wax", 0)) > P.wax:
			var now := Time.get_ticks_msec() / 1000.0
			wax_n = wax_n + 1 if now - wax_t < 0.45 else 0
			wax_t = now
			play("wax", -3, pow(2.0, [0, 3, 5, 7, 10, 12, 15, 17][mini(7, wax_n)] / 12.0), 0.03)
		if int(_g(game, "bosses", 0)) > P.bosses:
			play("boss_death")

	# ---- enemies: spawns, hits, kills, telegraphs, the boss
	var hits := 0
	var now_ids := {}
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var id: int = e.get_instance_id()
		now_ids[id] = true
		var is_boss: bool = e == boss or e.has_method("setup_boss")
		var kind := "boss" if is_boss else _kind(e)
		var ehp: float = e.hp
		if not seen_e.has(id):
			seen_e[id] = {"act": 0.0, "state": "", "landed": false, "quakes": 0}
			if not first:
				if is_boss:
					play("roar")
				else:
					play("spawn_" + kind, -6, 1.0, 0.2)
		elif not first:
			if ehp < float(hp_of.get(id, ehp)):
				hits += 1
				if hits <= 3:
					play("hit_crit" if float(hp_of[id]) - ehp >= 1.5 else "hit", 0.0, randf_range(0.92, 1.08), 0.025)
			if e.dead and not seen_e[id].get("dead", false):
				seen_e[id]["dead"] = true
				if not is_boss:
					play("kill_" + kind, 0.0, randf_range(0.95, 1.05), 0.04)
			var s: Dictionary = seen_e[id]
			if is_boss:
				var bs: String = e.get("state")
				if bs != s.state:
					if bs == "wind":
						play("wind")
					elif bs == "smash":
						play("big")
				var landed: bool = e.get("landed")
				if landed and not s.landed:
					play("big")
				var qn: int = (e.get("quakes") as Array).size()
				if qn > s.quakes:
					play("quake")
				s.state = bs
				s.landed = landed
				s.quakes = qn
			elif kind in ["dr", "fg", "sn"]:
				var a: float = e.get("act")
				if a > 0 and s.act <= 0:
					play("tele_" + kind, -2)
				if kind == "dr" and a <= 0 and s.act > 0:
					play("pounce")
				s.act = a
		hp_of[id] = ehp
	for id in seen_e.keys():
		if not now_ids.has(id):
			seen_e.erase(id)
			hp_of.erase(id)
	# ---- hexes and thrown blades
	for h in hexes:
		if not h.has("_a"):
			h["_a"] = true
			if not first:
				play("blade" if h.get("blade", false) else "hex_cast", -2, 1.0, 0.1)
	for h in prev_hexes:
		if float(h.life) <= 0 and not first:
			play("blade_end" if h.get("blade", false) else "hex_burst", -2, 1.0, 0.08)
	prev_hexes = hexes.duplicate()

	# ---- banners: candles, the strepitus, braziers, bosses slain
	if banner != P.get("banner", banner) and banner != "" and float(_g(hud, "banner_t", 0.0)) > 0:
		if "STREPITUS" in banner:
			play("strepitus")
		elif "CANDLE GOES OUT" in banner:
			var left: int = 15 - int(game.call("candles_out"))
			play("candle_hi" if left > 10 else "candle_mid" if left > 4 else "candle_lo")
		elif "BRAZIER" in banner:
			play("brazier")
		elif "SLAIN" in banner or "FALLS" in banner:
			play("slain")
		elif banner != "NOT YET":
			play("banner", -4)

	# ---- the death: stagger, the blade in the stone, ash, EXTINGUISHED
	if pdead:
		var t: float = _g(game, "dead_t", 0.0)
		if not P.get("dead", false):
			death_stage = -1
			voice.stop()
		var stage := 3 if t >= 1.8 else 2 if t >= 1.2 else 1 if t >= 0.5 else 0
		while death_stage < stage:
			death_stage += 1
			play("die%d" % death_stage)

	# ---- the score: chapter stems, drums with the fight, the boss layer
	var ch: int = game.call("chapter")
	if ch != music_ch:
		_set_chapter(ch)
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	inten = lerpf(inten, clampf(alive / 10.0, 0, 1), clampf(dt * 0.6, 0, 1))
	var in_boss := boss != null
	var tgt := {"base": MUSIC_DB if not in_boss else -60.0, "drums": (MUSIC_DB - 2 if inten > 0.3 else -60.0) if not in_boss else -60.0, "boss": MUSIC_DB if in_boss else -60.0}
	if scene != null:
		tgt.drums = -60.0
	for k in layers:
		layer_db[k] = move_toward(layer_db[k], tgt[k], dt * (30.0 if tgt[k] > layer_db[k] else 20.0))
		(layers[k] as AudioStreamPlayer).volume_db = layer_db[k]
	var cut := 260.0 if pdead else 1100.0 if (menu != null or summary != null or title != null) else 20000.0
	lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz, cut, clampf(dt * 3, 0, 1))
	AudioServer.set_bus_volume_db(music_bus, -10.0 if scene != null else -4.0 if pdead else 0.0)

	var atk2 = _g(pl, "atk")
	P = {"title": title, "menu": menu, "pick": menu.pick if menu != null else -1, "summary": summary,
		"atk_step": atk2.step if atk2 != null else -1, "atk_t": float(atk2.t) if atk2 != null else 0.0,
		"dash": float(_g(pl, "dash", 0.0)), "dj": _g(pl, "dj_used", false), "kick": float(_g(pl, "kick", 0.0)), "drop": float(_g(pl, "drop_t", 0.0)),
		"ground": _g(pl, "ground", false), "slam": _g(pl, "slam", false), "hp": float(_g(pl, "hp", 0.0)), "hidden": _g(game, "hidden_candle", true),
		"lvl": int(_g(game, "lvl", 1)), "wax": int(_g(game, "run_wax", 0)), "bosses": int(_g(game, "bosses", 0)), "banner": banner, "dead": pdead}


func _kind(e: Node) -> String:
	# Enemy.Kind { HOLLOW, GLOOMWING, BRUTE, HEXER, DROWNED, FORGED, SNUFFER }
	return ["sh", "bat", "br", "sp", "dr", "fg", "sn"][clampi(int(e.get("kind")), 0, 6)]


func _exit_tree() -> void:
	# CI reads this line to check that the sound files load and the watcher fires
	if game != null and is_instance_valid(game) and game.get("smoke"):
		print("smoke test: audio played %d sounds" % played)
