extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_combat.gd
## 메인 씬을 실제로 돌려 전투 루프를 확인한다.

## 2배속이므로 게임 시간은 두 배.
const SIM_SECONDS := 30

var _failures := 0
var _frame := 0
var _game: Game
var _cleared := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	# 시작 화면 없이 바로 시작, 실제 저장 파일 대신 테스트용 빈 진행 상태
	Game.hub_enabled = false
	Meta.save_path = "user://test_meta.cfg"
	Meta.reset()
	Meta.loaded = true
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_check(_game != null, "main scene uses Game script")
		_game.wave_cleared.connect(func(_w: int) -> void: _cleared += 1)
		_game.choices_offered.connect(_auto_choose)
		# 일시정지/배속 토글
		_game.toggle_speed()
		_check(Engine.time_scale == Game.BASE_TIME_SCALE * 2.0, "2x speed")
		_game.toggle_speed()
		_check(Engine.time_scale == Game.BASE_TIME_SCALE, "back to 1x")
		_game.toggle_pause()
		_check(paused, "paused")
		_game.toggle_pause()
		_check(not paused, "unpaused")
		# 2배속으로 시뮬레이션 진행
		_game.toggle_speed()
	elif _frame == 2 + SIM_SECONDS * 60:
		_check(_game.wave >= 2, "reached wave 2+ (wave=%d)" % _game.wave)
		_check(_cleared >= 1, "cleared at least one wave")
		_check(_game.money > 0, "earned money (money=%d)" % _game.money)
		_check(not _game.is_over, "single tile survives early waves")
		print("wave=%d money=%d core_hp=%.0f" % [_game.wave, _game.money,
				_game.board.core_tile().hp])
		# 코어 파괴 -> 게임 오버
		_game.board.core_tile().take_damage(99999.0)
		_check(_game.is_over, "game over when core destroyed")
		_check(paused, "tree paused on game over")
		Engine.time_scale = 1.0
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


## 카드가 나오면 첫 번째를 고르고, 타일 카드면 첫 칸에 배치, 장비 카드면 첫 타일에 장착한다.
func _auto_choose(_options: Array) -> void:
	_game.choose_option.call_deferred(0)
	_place_if_needed.call_deferred()


func _place_if_needed() -> void:
	if _game.state == Game.State.PLACING:
		_game.board.try_place(_game.board.placeable_cells()[0])
	elif _game.state == Game.State.EQUIPPING:
		_game.board.try_equip(_game.board.equippable_tiles()[0].coord)
