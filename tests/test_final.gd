extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_final.gd
## 30웨이브 최종 보스(OVERLORD), 클리어 화면과 SHARD, 무한 모드.

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
		_meta_math()
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _enemies() -> Array:
	return _game.get_tree().get_nodes_in_group(Enemy.GROUP)


func _run() -> void:
	var final := EnemyDefs.FINAL_WAVE
	_check(EnemyDefs.boss_kind(final) == "overlord", "final wave boss is the overlord")
	_check(EnemyDefs.boss_kind(10) == "boss" and EnemyDefs.boss_kind(20) == "boss",
			"other boss waves keep the normal boss")
	_check(EnemyDefs.is_boss_wave(final), "final wave is a boss wave")
	_check(not EnemyDefs.DEFS["overlord"]["weight"] > 0.0, "overlord never picked randomly")

	_game.hud.set_wave(12)
	_check(_game.hud._wave_label.text == "WAVE 12 / %d" % final, "wave label shows the goal")

	_game.wave = final - 1
	_game._begin_wave()
	_check(_game.wave == final and _game._boss_pending, "final wave has a boss pending")
	_game._to_spawn = 0
	_game._boss_pending = false
	var boss := _game._spawn_boss()
	_check(boss.kind == "overlord" and boss.is_boss, "overlord spawned")
	_check(_game.final_boss == boss and _game.hud.is_boss_bar_visible(), "boss bar shown")
	var normal_boss_hp := _game.wave_enemy_hp(final) * EnemyDefs.DEFS["boss"]["hp"]
	_check(boss.max_hp > normal_boss_hp * 2.0, "overlord much tougher than a normal boss")

	# 소환: 타이머가 다 되면 부하 summon_count마리
	var before := _game.alive_enemies()
	boss._summon_cd = 0.0
	boss._process(0.016)
	_check(_game.alive_enemies() == before + boss.summon_count, "overlord summons minions")

	# 일반 적만 더 단단해지고, 보스와 OVERLORD 부하는 wave_enemy_hp 그대로
	var base := _game.wave_enemy_hp(final)
	_check(is_equal_approx(boss.max_hp, base * EnemyDefs.DEFS["overlord"]["hp"]),
			"overlord hp not scaled by the normal multiplier")
	var minion: Enemy = _enemies().filter(func(e: Enemy) -> bool: return e.kind == "runner")[0]
	_check(is_equal_approx(minion.max_hp, base * EnemyDefs.DEFS["runner"]["hp"]),
			"overlord minions not scaled by the normal multiplier")
	var grunt := _game.spawn_enemy("grunt", Vector2(-3000, 0))
	_check(_game.normal_hp_mult(final) > 1.5
			and is_equal_approx(grunt.max_hp, base * _game.normal_hp_mult(final)),
			"normal enemies tougher in the late waves")
	_check(is_equal_approx(_game.normal_hp_mult(1), 1.0)
			and is_equal_approx(_game.normal_hp_mult(Game.NORMAL_HP_FROM), 1.0),
			"early waves unchanged")
	_check(is_equal_approx(_game.normal_hp_mult(final + 20), _game.normal_hp_mult(final)),
			"multiplier stops growing in endless")
	grunt.take_damage(1e12)
	_check(is_equal_approx(boss._summon_cd, boss.summon_every), "summon timer reset")

	# 분노: 체력 절반 아래로 빨라지고 더 자주 부른다
	var speed := boss.speed
	boss.take_damage(boss.max_hp * 0.4 / (1.0 - boss.armor))
	_check(not boss.enraged, "not enraged above half HP")
	boss.take_damage(boss.max_hp * 0.2 / (1.0 - boss.armor))
	_check(boss.enraged and is_equal_approx(boss.speed, speed * boss.enrage_speed), "enraged below half")
	boss._summon_cd = 0.0
	boss._process(0.016)
	_check(is_equal_approx(boss._summon_cd, boss.summon_every * 0.5), "enraged summons twice as often")

	# 다 잡으면 클리어 화면 (카드 대신)
	for e in _enemies():
		(e as Enemy).take_damage(1e12)
	_check(_game.alive_enemies() == 0, "all enemies dead")
	_game._process(0.016)
	var expected := Meta.shards_for_run(final + 1) + Meta.VICTORY_BONUS
	_check(_game.get_tree().paused and _game.hud.is_victory_visible(), "victory screen shown")
	_check(not _game.hud.is_choosing(), "no cards on the victory screen")
	_check(not _game.hud.is_boss_bar_visible(), "boss bar hidden after victory")
	_check(Meta.shards == expected and Meta.clears == 1 and Meta.last_run_victory,
			"victory shards awarded at once (%d)" % Meta.shards)
	_check(_game.victory_shards == expected, "victory shards remembered")
	_game.toggle_pause()
	_check(_game.get_tree().paused and _game.hud.is_victory_visible(), "space does not close victory")

	# 무한 모드: 카드 3장부터 이어서
	_game.continue_endless()
	_check(_game.endless and not _game.get_tree().paused, "endless resumes the game")
	_check(not _game.hud.is_victory_visible() and _game.hud.is_choosing(), "endless offers cards")
	_check(_game.state == Game.State.CHOOSING, "endless starts in choosing")
	_check(_game.hud._wave_label.text.ends_with("ENDLESS"), "wave label shows endless")
	_game.continue_endless()
	_check(_game.endless, "second continue is a no-op")

	# 무한 모드에서 끝나면 클리어 뒤 웨이브 몫만 더
	_game.hud.hide_choices()
	_game.wave = final + 3
	_game._on_core_destroyed()
	var extra := Meta.shards_for_run(final + 3) - Meta.shards_for_run(final + 1)
	_check(extra > 0 and Meta.shards == expected + extra, "endless pays only the extra waves")
	_check(Meta.last_run_shards == expected + extra and Meta.last_run_wave == final + 3
			and Meta.last_run_victory, "result shows the whole run")

	# END RUN: 시작 화면으로, SHARD는 이미 받은 그대로
	_game.is_over = false
	_game.endless = false
	_game.get_tree().paused = false
	_game.shop.close()
	var shards := Meta.shards
	_game._on_victory()
	_game.end_run_after_victory()
	_check(_game.is_over and _game.results.is_open() and not _game.hud.is_victory_visible(),
			"end run opens the results screen")
	_check(_game.results.data["victory"] and _game.results.data["wave"] == _game.wave,
			"results show the victory")
	_game.results.continue_pressed.emit()
	_check(_game.shop.is_open() and not _game.results.is_open(), "continue opens the start screen")
	_check(Meta.shards == shards + expected and Meta.clears == 2, "end run keeps victory shards")
	_game.get_tree().paused = false


func _meta_math() -> void:
	Meta.reset()
	Meta.finish_run(12)
	_check(not Meta.last_run_victory and Meta.last_run_shards == Meta.shards_for_run(12),
			"normal run unaffected")
	Meta.clears = 3
	Meta.save_data()
	Meta.clears = 0
	Meta.load_data()
	_check(Meta.clears == 3, "clears saved")
