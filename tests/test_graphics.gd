extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_graphics.gd
## 빛 번짐(글로우) 설정: 기본은 꺼짐, 켜고 끄면 WorldEnvironment에 바로 적용되고 저장됨.
## NeonDraw.cached: 같은 key는 한 번만 만들고, 같은 종류 적끼리 메시를 같이 씀.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = false
	Meta.save_path = "user://test_meta.cfg"
	Meta.reset()
	Meta.loaded = true
	Sfx.settings_path = "user://test_graphics_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.settings_path))
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_game = current_scene as Game
		_run()
	if _frame == 6:
		_run_cache()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.settings_path))
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _env() -> Environment:
	return (_game.get_node("WorldEnvironment") as WorldEnvironment).environment


func _run() -> void:
	_check(not Graphics.glow, "glow is off by default")
	_check(not _env().glow_enabled, "game starts with glow off")
	Graphics.set_glow(true)
	_check(_env().glow_enabled, "turning glow on applies right away")
	var cfg := ConfigFile.new()
	_check(cfg.load(Sfx.settings_path) == OK and cfg.get_value("graphics", "glow") == true, "glow setting saved")
	Graphics.set_glow(false)
	_check(not _env().glow_enabled, "turning glow off applies right away")
	var panel := SettingsPanel.new()
	root.add_child(panel)
	panel.open()
	var b := panel.find_child("GlowButton", true, false) as Button
	_check(b != null, "settings panel has a glow button")
	if b != null:
		b.pressed.emit()
		_check(Graphics.glow and _env().glow_enabled, "glow button turns glow on")
		b.pressed.emit()
		_check(not Graphics.glow, "glow button turns glow off again")
	panel.queue_free()
	# 같은 종류 적 두 마리 (그려지게 다음 프레임까지 둔다)
	for i in 2:
		var e := _game.spawn_enemy("grunt", Vector2(300 + i * 40, 300))
		e.board = null


func _run_cache() -> void:
	var before := NeonDraw.cache_size()
	var calls := [0]
	var c := Node2D.new()
	root.add_child(c)
	NeonDraw.begin(c)
	for i in 3:
		NeonDraw.cached(c, "test|shape", func() -> void:
			calls[0] += 1
			NeonDraw.polyline(c, PackedVector2Array([Vector2.ZERO, Vector2(10, 0)]), Color.RED))
	NeonDraw.flush()
	_check(calls[0] == 1, "cached shape is built only once (built %d times)" % calls[0])
	_check(NeonDraw.cache_size() == before + 1, "one mesh stored for the key")
	var keys := 0
	for k in NeonDraw._meshes.keys():
		if String(k).begins_with("enemy|grunt|"):
			keys += 1
	_check(keys == 1, "two grunts share one stored body mesh (%d)" % keys)
	c.queue_free()
