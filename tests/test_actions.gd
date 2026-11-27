extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_actions.gd
## 웨이브마다 1번 타일 옮기기, 코어 종류별 스킬, 코어 구매/선택 저장, 일시정지 탭으로 이어 하기.

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
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_run()
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _run() -> void:
	var board := _game.board
	var laser := board.place_tile(Vector2i(1, 0), "laser")
	var frost := board.place_tile(Vector2i(2, 0), "frost")

	# 옮기기: 한 웨이브에 1번, 코어는 못 집음, 다른 타일과 맞닿은 빈 칸으로만
	_check(_game.move_charges == 1 and _game.can_move(), "one move at start")
	_game.toggle_move()
	_check(board.moving, "move mode on")
	board.click_move(Vector2i.ZERO)
	_check(board.move_from == null, "core cannot be picked up")
	board.click_move(laser.coord)
	_check(board.move_from == laser, "pick up laser")
	_check(not board.can_move_to(laser, Vector2i(4, 0)), "cannot move to an isolated cell")
	board.click_move(Vector2i(4, 0))
	_check(laser.coord == Vector2i(1, 0) and board.moving, "invalid cell keeps move mode")
	board.click_move(Vector2i(-1, 0))
	_check(laser.coord == Vector2i(-1, 0) and board.tiles[Vector2i(-1, 0)] == laser
			and not board.tiles.has(Vector2i(1, 0)), "laser moved")
	_check(is_equal_approx(laser.position.x, HexGrid.axial_to_pixel(Vector2i(-1, 0), board.hex_size).x),
			"moved tile position updated")
	_check(not board.moving and _game.move_charges == 0 and not _game.can_move(), "move used up")
	_game.toggle_move()
	_check(not board.moving, "no second move in the same wave")
	_game._begin_wave()
	_check(_game.move_charges == 1, "move refills each wave (no stacking)")
	_game._begin_wave()
	_check(_game.move_charges == 1, "charges do not stack")
	# 자리 바꾸기: FROST(2,0)는 맞닿은 타일이 없지만 바꾸기는 언제나 된다
	_game.toggle_move()
	board.click_move(frost.coord)
	board.click_move(laser.coord)
	_check(frost.coord == Vector2i(-1, 0) and laser.coord == Vector2i(2, 0), "swap two tiles")
	_check(board.tiles[Vector2i(2, 0)] == laser and board.tiles[Vector2i(-1, 0)] == frost,
			"swap updates board")

	# 스킬: OVERDRIVE (기본 코어) 공격력 +60%, 끝나면 원래대로, 쿨다운 중엔 못 씀
	var base := laser.damage()
	_check(_game.core_type == "core" and _game.skill_ready(), "default core skill ready")
	_check(_game.use_skill(), "use overdrive")
	_check(absf(laser.damage() - base * 1.6) < 0.001, "overdrive +60%% damage")
	_check(not _game.use_skill(), "cooldown blocks reuse")
	_game.state = Game.State.CHOOSING
	_game._process(6.5)
	_check(absf(laser.damage() - base) < 0.001, "overdrive ends")
	_check(_game.skill_cooldown > 0.0, "still cooling down")
	_game._process(40.0)
	_check(_game.skill_ready(), "cooldown finishes")

	# FREEZE: 적이 움직이지 않음
	_game._apply_core_type("cryo")
	_check(board.core_tile().color == CoreDefs.get_def("cryo")["color"], "core recolored")
	var walker := _game.spawn_enemy("grunt", Vector2(-700, 0))
	_game.use_skill()
	var p0 := walker.global_position
	walker._process(1.0)
	_check(walker.global_position == p0 and walker.is_frozen(), "freeze stops enemies")
	walker._process(3.0)
	walker._process(0.5)
	_check(walker.global_position != p0, "enemy moves again after freeze")

	# REPAIR: 모든 타일 체력 회복
	_game._apply_core_type("aegis")
	laser.hp = 10.0
	_game.use_skill()
	_check(is_equal_approx(laser.hp, minf(10.0 + laser.max_hp * 0.5, laser.max_hp)), "repair heals tiles")

	# NOVA: 가까운 적은 최대 체력 30%, 먼 적은 그대로
	_game._apply_core_type("nova")
	var near := _game.spawn_enemy("armored", Vector2(200, 0))
	var far := _game.spawn_enemy("grunt", Vector2(2000, 0))
	near.max_hp = 1000.0
	near.hp = 1000.0
	far.max_hp = 1000.0
	far.hp = 1000.0
	_game.use_skill()
	_check(absf(near.hp - 700.0) < 0.01, "nova takes 30%% max hp through armor (%.1f)" % near.hp)
	_check(far.hp == 1000.0, "nova misses far enemies")

	# 코어 구매와 선택은 저장된다
	Meta.shards = 100
	_check(not Meta.select_core("nova"), "cannot select locked core")
	_check(Meta.buy_core("nova") and Meta.core_type == "nova" and Meta.shards == 75, "buy nova core")
	_check(Meta.select_core("core") and Meta.core_type == "core", "switch back to core")
	Meta.save_data()
	Meta.reset()
	Meta.load_data()
	_check(Meta.is_core_unlocked("nova") and not Meta.is_core_unlocked("cryo")
			and Meta.core_type == "core", "cores saved")

	# 일시정지: 화면 아무 데나 누르면(탭) 이어서 한다. PLAY 버튼은 어두운 화면 위에 있다.
	var hud := _game.hud
	_game.toggle_pause()
	_check(paused and hud.is_overlay_visible(), "paused with overlay")
	_check(hud._pause_button.text == "PLAY", "pause button shows PLAY")
	_check(hud._pause_button.get_parent().get_parent().get_index() > hud._overlay.get_index(),
			"pause button drawn above the pause overlay")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	hud._on_overlay_input(tap)
	_check(not paused and not hud.is_overlay_visible(), "tap on overlay resumes")
	_check(hud._pause_button.text == "PAUSE", "pause button back to PAUSE")
