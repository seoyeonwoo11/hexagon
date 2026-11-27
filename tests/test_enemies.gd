extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_enemies.gd
## 적 종류: 능력치 배율, 등장 웨이브, 장갑, 분열, 보스 웨이브.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_game.set_process(false)  # 자동 웨이브 진행을 멈추고 직접 확인
		_run()
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _run() -> void:
	# 등장 웨이브: 1웨이브엔 GRUNT만, 보스는 일반 뽑기에 안 나옴
	for i in 200:
		_check(EnemyDefs.pick_kind(1) == "grunt", "wave 1 only grunts")
	var seen := {}
	for i in 2000:
		seen[EnemyDefs.pick_kind(12)] = true
	for kind in ["grunt", "runner", "tank", "splitter", "armored"]:
		_check(seen.has(kind), "%s appears by wave 12" % kind)
	_check(not seen.has("boss"), "boss never picked randomly")
	_check(EnemyDefs.is_boss_wave(10) and EnemyDefs.is_boss_wave(20), "boss waves")
	_check(not EnemyDefs.is_boss_wave(9), "wave 9 no boss")

	# 능력치 배율
	_game.wave = 5
	var grunt := _game.spawn_enemy("grunt", Vector2(-2000, 0))
	var tank := _game.spawn_enemy("tank", Vector2(-2000, 100))
	var runner := _game.spawn_enemy("runner", Vector2(-2000, 200))
	_check(tank.max_hp > grunt.max_hp * 2.0, "tank has more hp")
	_check(runner.speed > grunt.speed * 1.5, "runner is faster")
	_check(tank.reward > grunt.reward, "tank gives more money")
	_check(grunt.shape_points().size() == 4 and tank.shape_points().size() == 5, "shapes")

	# 장갑: 받는 피해 감소
	var armored := _game.spawn_enemy("armored", Vector2(-2000, 300))
	armored.take_damage(10.0)
	_check(is_equal_approx(armored.max_hp - armored.hp, 10.0 * (1.0 - armored.armor)) \
			and armored.armor > 0.0, "armor reduces damage")

	# 분열: SPLITTER를 처치하면 RUNNER 2마리, 살아있는 적 수도 맞게 늘어남
	var splitter := _game.spawn_enemy("splitter", Vector2(-2000, 400))
	var alive_before := _game.alive_enemies()
	splitter.take_damage(99999.0)
	_check(_game.alive_enemies() == alive_before - 1 + 2, "split adds 2 enemies (alive %d -> %d)" \
			% [alive_before, _game.alive_enemies()])
	var runners := 0
	for node in get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.kind == "runner" and e.global_position.distance_to(Vector2(-2000, 400)) < 40.0:
			runners += 1
	_check(runners == 2, "two runners near splitter (got %d)" % runners)

	# 타일에 부딪혀 사라지면 분열하지 않음
	var splitter2 := _game.spawn_enemy("splitter", Vector2(-2000, 600))
	var alive2 := _game.alive_enemies()
	splitter2._die(false)
	_check(_game.alive_enemies() == alive2 - 1, "no split on contact")

	# 불을 붙인 타일이 부서진 뒤에도 화상이 오류 없이 계속된다
	var burner := HexTile.new()
	burner.setup("laser")
	var burning := _game.spawn_enemy("grunt", Vector2(-2000, 800))
	burning.max_hp = 1000.0
	burning.hp = 1000.0
	burning.apply_burn(10.0, 3.0, burner)
	burner.free()
	burning._process(0.5)
	_check(burning.hp < 1000.0, "burn continues after source freed")

	# 보스 웨이브: 일반 적 다음에 보스 1마리
	_game._begin_wave()  # wave 5 -> 6
	_game.wave = 9
	_game._begin_wave()  # -> 10
	_check(_game._boss_pending, "boss pending on wave 10")
