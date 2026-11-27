extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_meta.gd
## 판 사이 성장: SHARD 보상, 영구 강화 구매, 타일 구매, 저장/불러오기, 판 시작 시 적용.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = true
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
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
		quit(1 if _failures > 0 else 0)
	return false


func _run() -> void:
	# SHARD 보상: 다 처리한 웨이브 수, 10웨이브마다 +5
	_check(Meta.shards_for_run(1) == 0, "no shards when dying on wave 1")
	_check(Meta.shards_for_run(8) == 7, "7 cleared waves -> 7 shards")
	_check(Meta.shards_for_run(21) == 20 + 10, "20 cleared waves + 2 boss bonuses")

	# 시작 화면이 떠 있는 동안은 판이 진행되지 않는다
	_check(_game.shop.is_open() and not _game.started, "shop shown before run")
	var wave_before := _game.wave
	_game._process(10.0)
	_check(_game.wave == wave_before, "no waves while in shop")

	# 임시 지급 버튼: +10
	_game.shop.add_debug_shards()
	_check(Meta.shards == Shop.DEBUG_SHARD_AMOUNT, "debug +10 shards")
	Meta.shards = 0

	# 구매: SHARD 부족하면 실패, 충분하면 레벨업 + 차감, 최대 레벨에서 멈춤
	_check(not Meta.buy_upgrade("core_hp"), "cannot buy without shards")
	Meta.shards = 1000
	_check(Meta.buy_upgrade("core_hp"), "buy core plating")
	_check(Meta.level("core_hp") == 1 and Meta.shards == 1000 - 5, "level 1, cost 5")
	_check(Meta.upgrade_cost("core_hp") == 10, "next cost 10")
	for i in 10:
		Meta.buy_upgrade("core_hp")
	_check(Meta.level("core_hp") == 5 and Meta.upgrade_cost("core_hp") == -1, "max level 5")
	Meta.buy_upgrade("damage")
	Meta.buy_upgrade("money")
	Meta.buy_upgrade("tile_hp")

	# 타일 구매: 처음엔 SPARK/ORBIT 잠김, 사면 풀림
	_check(Meta.is_tile_unlocked("laser") and not Meta.is_tile_unlocked("orbit"), "starter tiles")
	_check(Meta.buy_tile("orbit") and Meta.is_tile_unlocked("orbit"), "buy orbit")
	_check(not Meta.buy_tile("orbit"), "cannot buy twice")

	# 출정 타일: 기본은 풀린 타일, 산 타일은 자리가 있으면 바로 들어감, 최대 6종
	_check(Meta.in_loadout("orbit") and Meta.in_loadout("laser") and not Meta.in_loadout("spark"),
			"loadout has unlocked tiles (%s)" % [Meta.loadout])
	_check(Meta.toggle_loadout("bank") and not Meta.in_loadout("bank"), "remove from loadout")
	_check(Meta.toggle_loadout("bank") and Meta.in_loadout("bank"), "add back to loadout")
	_check(not Meta.toggle_loadout("spark"), "locked tile cannot join loadout")
	Meta.buy_tile("spark")
	_check(Meta.loadout.size() == Meta.MAX_LOADOUT and Meta.loadout_full(), "loadout fills to 6")
	Meta.buy_tile("drone")
	_check(Meta.is_tile_unlocked("drone") and not Meta.in_loadout("drone"), "7th tile stays out")
	_check(not Meta.toggle_loadout("drone"), "cannot add when full")
	Meta.toggle_loadout("spark")
	_check(Meta.toggle_loadout("drone"), "swap spark for drone")

	# 저장 후 다시 불러와도 그대로
	var shards := Meta.shards
	Meta.save_data()
	Meta.reset()
	Meta.load_data()
	_check(Meta.shards == shards and Meta.level("core_hp") == 5 and Meta.is_tile_unlocked("orbit")
			and Meta.is_tile_unlocked("spark"), "save/load roundtrip")
	_check(Meta.in_loadout("drone") and not Meta.in_loadout("spark") and Meta.loadout.size() == 6,
			"loadout saved (%s)" % [Meta.loadout])

	# 게임에서 빠진 PRISM을 산 저장 파일: SHARD 20개를 돌려주고 목록에서 뺀다 (한 번만)
	var cfg := ConfigFile.new()
	cfg.load(Meta.save_path)
	cfg.set_value("meta", "unlocked", Array(Meta.unlocked) + ["prism"])
	cfg.set_value("meta", "loadout", Array(Meta.loadout) + ["prism"])
	cfg.save(Meta.save_path)
	Meta.load_data()
	_check(Meta.shards == shards + 20 and not Meta.unlocked.has("prism") and not Meta.loadout.has("prism"),
			"removed prism refunded (%d -> %d)" % [shards, Meta.shards])
	Meta.load_data()
	_check(Meta.shards == shards + 20, "refund only once")
	Meta.shards = shards
	Meta.save_data()

	# START: 영구 강화가 판에 적용된다
	_game.shop.start_pressed.emit()
	var core := _game.board.core_tile()
	_check(_game.started and not _game.shop.is_open(), "start closes shop")
	_check(core.max_hp == (100.0 + 125.0) * 1.1 and core.hp == core.max_hp, "core hp bonus")
	_check(_game.money == 10, "start money bonus")
	_check(absf(_game.board.damage_mult - 1.08) < 0.001, "damage bonus")
	var t := _game.board.place_tile(Vector2i(1, 0), "laser")
	_check(absf(t.max_hp - 60.0 * 1.1) < 0.01, "tile hp bonus")

	# 출정 타일에 없는 타일(SPARK)은 카드에 나오지 않는다
	var saw_spark := false
	var saw_orbit := false
	for i in 300:
		for o in _game.make_options():
			if o["type"] == "tile" and o["kind"] == "spark":
				saw_spark = true
			if o["type"] == "tile" and o["kind"] == "orbit":
				saw_orbit = true
	_check(not saw_spark and saw_orbit, "only loadout tiles in cards (spark %s, orbit %s)"
			% [saw_spark, saw_orbit])

	# 결과창 기록: 처치 수와 번 돈 (시작 돈은 안 셈)
	var earned_before := _game.money_earned
	var foe := _game.spawn_enemy("grunt", Vector2(2000, 0))
	foe.take_damage(99999.0)
	_check(_game.kills.get("grunt", 0) == 1, "kill counted for results")
	_check(_game.money_earned > earned_before, "kill reward counted as earned gold")
	_check(ResultsScreen.format_time(125.0) == "2:05" and ResultsScreen.format_time(3725.0)
			== "1:02:05", "results time format")

	# 게임 오버: 버틴 웨이브만큼 SHARD가 들어오고 결과창 -> 시작 화면
	_game.wave = 12
	var before := Meta.shards
	core.take_damage(99999.0)
	_check(Meta.shards == before + Meta.shards_for_run(12), "shards awarded on game over")
	_check(Meta.last_run_wave == 12 and Meta.best_wave == 12, "run result recorded")
	_check(_game.results.is_open() and not _game.shop.is_open(), "results shown after game over")
	_check(_game.results.data["wave"] == 12 and _game.results.data["new_best"]
			and _game.results.data["shards"] == Meta.shards_for_run(12), "results show the run")
	_game.results.continue_pressed.emit()
	_check(not _game.results.is_open() and _game.shop.is_open(), "continue opens the shop")
	get_root().get_tree().paused = false
