class_name DebugOverlay
extends CanvasLayer
## F1 toggles this panel, F2 toggles hitboxes. Values update every frame.

var game: Game
var label: Label


func _ready() -> void:
	layer = 10
	label = Label.new()
	label.position = Vector2(12, 10)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#f2e6da"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)


func _process(_dt: float) -> void:
	visible = game.show_debug
	if not visible:
		return
	var p := game.player
	var alive := game.enemies.filter(func(e): return not e.dead).size()
	label.text = "\n".join([
		"TENEBRAE PROTOTYPE   map %s (1-5)   R restart   F1 panel   F2 hitboxes   F3 next depth" % game.world.map_name,
		"fps %d   physics %d Hz" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second],
		"state  %s" % p.state_name(),
		"pos    %.0f, %.0f" % [p.position.x, p.position.y],
		"vel    %.0f, %.0f" % [p.vel.x, p.vel.y],
		"ground %s  one-way %s  wall %d" % [p.ground, p.on_one_way, p.wall],
		"coyote %.2f  buffer %.2f  dash cd %.2f" % [p.coyote, p.buffer, p.dash_cd],
		"hp %d/%d   kills %d   enemies %d" % [p.hp, p.max_hp, game.kills, alive],
		"depth %d (%.0fs)   candles out %d   darkness %.2f   hidden candle %s   brazier buff %s" % [game.depth, game.depth_t, game.candles_out(), game.darkness(), game.hidden_candle, game.brazier_buff()],
	])
