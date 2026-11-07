class_name SteamBridge
extends RefCounted
## Thin layer over GodotSteam (https://godotsteam.com). When the game runs from
## Steam with a GodotSteam build, achievements, stats and rich presence go to
## Steam. In any other build (the plain Godot export, CI, the editor) every call
## does nothing, so the game never depends on Steam being there.
##
## The app id comes from steam_appid.txt next to the executable (Steam writes
## it for local testing) or the project setting steam/app_id. 480 is Valve's
## public Spacewar test app, fine for local tests and never shipped.

static var steam: Object = null
static var ready := false
static var app_id := 480


static func init() -> void:
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	app_id = int(ProjectSettings.get_setting("steam/app_id", 480))
	var f := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("steam_appid.txt"), FileAccess.READ)
	if f != null:
		app_id = int(f.get_as_text().strip_edges())
	var res = steam.call("steamInitEx", true, app_id)
	# GodotSteam returns {"status": 0, "verbal": "..."} on success
	ready = typeof(res) == TYPE_DICTIONARY and int(res.get("status", 1)) == 0
	if not ready:
		push_warning("Steam not initialised: %s" % str(res))


## Call every frame so Steam's callbacks run.
static func tick() -> void:
	if ready:
		steam.call("run_callbacks")


## Achievement ids in Achievements.LIST are the Steamworks API names.
static func achieve(id: String) -> void:
	if not ready:
		return
	steam.call("setAchievement", id)
	steam.call("storeStats")


## Integer stats, also created in Steamworks with the same API names.
static func stat(name: String, value: int) -> void:
	if not ready:
		return
	steam.call("setStatInt", name, value)
	steam.call("storeStats")


## What friends see in their Steam list, e.g. "Depth IX · The Bladeworks".
static func presence(text: String) -> void:
	if not ready:
		return
	steam.call("setRichPresence", "steam_display", "#Status")
	steam.call("setRichPresence", "status", text)
