class_name BalanceBot
extends RefCounted
## Plays real runs for balance numbers: `godot --headless -- --balance [runs] [vigil]`.
## Unlike the smoke test it never cheats. It walks to the nearest enemy, swings,
## jumps at enemies above, dashes out of telegraphs and fires the weapon skill.
## Menus get a random pick, so drafts and shops vary run to run. Every run is
## logged to user://runs.jsonl and printed; the last line is a summary.

var game: Game
var runs := 8
var results: Array = []
var frame := 0
var run_t := 0.0
var drop_cd := 0.0
var dash_cd := 0.0
var stuck_t := 0.0
var last_x := 0.0
var wander := 1
var last_hp := -1.0
var hits_logged := 0
const ACTIONS := ["left", "right", "up", "down", "jump", "attack", "dash", "skill"]
const RUN_LIMIT := 900.0 ## game seconds before a run counts as stalled


func _init(g: Game, n: int) -> void:
	game = g
	runs = n


func step(dt: float) -> void:
	frame += 1
	Engine.time_scale = 4.0
	game.vigil_max = maxi(game.vigil_max, game.vigil)
	for a in ACTIONS:
		Input.action_release(a)
	var hud: Hud = game.hud
	var pulse := frame % 2 == 0
	if hud.title_screen != null or hud.scene != null:
		if pulse:
			Input.action_press("jump")
		return
	if hud.menu != null:
		if hud.menu.t < 0.35:
			if frame % 7 == 0:
				hud.menu.pick = randi() % hud.menu.opts.size()
			return
		if pulse:
			Input.action_press("jump")
		return
	if hud.summary != null:
		if pulse and hud.summary.t > 1.3:
			Input.action_press("jump")
		return
	var p := game.player
	if p == null or p.dead:
		return
	run_t += dt
	if last_hp >= 0 and p.hp < last_hp and hits_logged < 40:
		hits_logged += 1
		var near := []
		for e in game.enemies:
			if not e.dead and e.position.distance_to(p.position) < 260:
				near.append("%s%s d(%d,%d) tele %.2f act %.2f %s" % [Enemy.Kind.keys()[e.kind] if e != game.boss else "BOSS", "*" + e.elite if e.elite != "" else "",
					int(e.position.x - p.position.x), int(e.position.y - p.position.y), e.tele, e.act, e.mode])
		print("balance: HIT at %.1fs hp %.0f ground %s dash %.2f dashcd %.2f | %s" % [run_t, p.hp, p.ground, p.dash, p.dash_cd, "; ".join(near)])
	last_hp = p.hp
	if run_t > RUN_LIMIT:
		print("balance: run stalled at depth %d, ending it" % game.depth)
		p.hp = 0
		p.take_hit(p.position.x + 1)
		return
	_fight(p, dt)


func _fight(p: Player, dt: float) -> void:
	drop_cd -= dt
	dash_cd -= dt
	var target: Enemy = null
	var best := INF
	for e in game.enemies:
		if e.dead:
			continue
		var d := e.position.distance_to(p.position) + absf(e.position.y - p.position.y) * 1.5
		if d < best:
			best = d
			target = e
	if target == null:
		# nothing alive: roam so the spawns find us
		if absf(p.position.x - last_x) < 2:
			stuck_t += dt
		else:
			stuck_t = 0.0
		last_x = p.position.x
		if stuck_t > 0.6:
			wander = -wander
			stuck_t = 0.0
			Input.action_press("jump")
		Input.action_press("right" if wander > 0 else "left")
		return
	var dx := target.position.x - p.position.x
	var dy := (target.position.y - target.h / 2) - (p.position.y - 28)
	var near := absf(dx) < p.reach + 10 and absf(dy) < 70
	# any enemy close by winding up or mid-attack: dash through it, or back off while the dash recharges
	for e in game.enemies:
		if e.dead or (e.tele <= 0 and e.act <= 0):
			continue
		var ex := e.position.x - p.position.x
		if absf(ex) < 170 and absf(e.position.y - p.position.y) < 110:
			if dash_cd <= 0 and p.dash_cd <= 0:
				Input.action_press("right" if ex > 0 else "left")
				Input.action_press("dash")
				dash_cd = 0.5
			elif p.invuln <= 0:
				Input.action_press("left" if ex > 0 else "right")
			return
	if game.skill_meter >= 1.0 and absf(dx) < 260 and absf(dy) < 120:
		Input.action_press("skill")
	if not near:
		if absf(dx) > 30:
			Input.action_press("right" if dx > 0 else "left")
		if dy < -90 and frame % 12 < 2:
			Input.action_press("jump")
		elif dy > 110 and p.ground and drop_cd <= 0:
			Input.action_press("down")
			Input.action_press("jump")
			drop_cd = 0.6
		elif not p.ground and dy > 60 and absf(dx) < 60:
			Input.action_press("down")
			Input.action_press("attack")
		# walls in the way: jump over them
		if p.wall != 0 and frame % 10 == 0:
			Input.action_press("jump")
	else:
		# fight at the edge of reach, not inside the enemy's body
		if absf(dx) < p.reach * 0.35 and p.invuln <= 0:
			Input.action_press("left" if dx > 0 else "right")
		elif (dx > 0) != (p.facing > 0):
			Input.action_press("right" if dx > 0 else "left")
		if frame % 3 == 0:
			Input.action_press("attack")


## Game calls this from _log_run with the record it just wrote.
func on_run_end(rec: Dictionary) -> void:
	results.append(rec)
	run_t = 0.0
	print("balance: run %d/%d  %s  depth %d  %ds  kills %d  bosses %d  %s  lvl %d" % [results.size(), runs, "WON" if rec.won else "died",
		rec.depth, int(rec.time), rec.kills, rec.bosses, rec.weapon, rec.lvl])
	if results.size() >= runs:
		var depths: Array = results.map(func(r): return r.depth)
		depths.sort()
		var wins_n := results.filter(func(r): return r.won).size()
		var mean_t := 0.0
		for r in results:
			mean_t += r.time
		print("balance: summary  runs %d  wins %d  median depth %d  min %d  max %d  mean time %ds" % [runs, wins_n, depths[depths.size() / 2], depths[0], depths[-1], int(mean_t / runs)])
		print("balance: done")
		game.get_tree().quit()
