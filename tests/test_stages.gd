extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_stages.gd
## 스테이지: 해금 순서, 스테이지 배율(적 체력/피해, SHARD), 클리어 보상(강화 상한, 새 강화/코어,
## 출정 칸), 저장/불러오기와 예전 저장 파일 변환, 시작 화면 스테이지 고르기, 판에 적용.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = true
	Meta.save_path = "user://test_stages.cfg"
	Meta.reset()
	Meta.loaded = true
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_meta_rules()
		_save_and_migrate()
		_in_game()
		if _failures == 0:
			print("ALL TESTS PASSED")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
		quit(1 if _failures > 0 else 0)
	return false


func _meta_rules() -> void:
	Meta.reset()
	var n := StageDefs.count()
	_check(n >= 3, "several stages")
	for i in range(2, n + 1):
		_check(StageDefs.hp_mult(i) > StageDefs.hp_mult(i - 1)
				and StageDefs.damage_mult(i) > StageDefs.damage_mult(i - 1)
				and StageDefs.shard_mult(i) > StageDefs.shard_mult(i - 1),
				"stage %d harder and pays more than stage %d" % [i, i - 1])
	_check(is_equal_approx(StageDefs.hp_mult(1), 1.0) and is_equal_approx(StageDefs.shard_mult(1), 1.0),
			"stage 1 is the base game")

	# 처음엔 1스테이지만
	_check(Meta.stage == 1 and Meta.is_stage_unlocked(1) and not Meta.is_stage_unlocked(2),
			"only stage 1 open at first")
	_check(not Meta.select_stage(2) and Meta.stage == 1, "cannot pick a locked stage")
	_check(Meta.upgrade_max("damage") == 5, "upgrade cap 5 at first")
	_check(not Meta.is_upgrade_unlocked("bounty") and Meta.upgrade_cost("bounty") == -1,
			"bounty locked before stage 1 clear")
	Meta.shards = 10000
	_check(not Meta.buy_upgrade("bounty"), "cannot buy a locked upgrade")
	_check(not Meta.is_core_available("warp") and not Meta.buy_core("warp"),
			"warp core locked before stage 2 clear")
	_check(Meta.max_loadout() == Meta.MAX_LOADOUT, "base loadout size")
	for i in 5:
		Meta.buy_upgrade("damage")
	_check(Meta.level("damage") == 5 and Meta.upgrade_cost("damage") == -1, "capped at 5")

	# SHARD 배율
	_check(Meta.shards_for_run(21, 1) == Meta.shards_for_run(21), "stage 1 shards unchanged")
	_check(Meta.shards_for_run(21, 2) == roundi(Meta.shards_for_run(21) * StageDefs.shard_mult(2)),
			"stage 2 shards scaled")
	_check(Meta.shards_for_victory(1) == Meta.shards_for_run(EnemyDefs.FINAL_WAVE + 1)
			+ Meta.VICTORY_BONUS, "stage 1 victory pays the old amount")

	# 1스테이지 클리어: 2스테이지, 상한 +3, BOUNTY
	var before := Meta.shards
	var got := Meta.finish_victory(1)
	_check(got == Meta.shards_for_victory(1) and Meta.shards == before + got, "victory shards")
	_check(Meta.stage_cleared == 1 and Meta.is_stage_unlocked(2) and not Meta.is_stage_unlocked(3),
			"stage 2 opens")
	_check(Meta.upgrade_max("damage") == 5 + Meta.CAP_PER_STAGE and Meta.upgrade_cost("damage") > 0,
			"upgrade cap raised")
	_check(Meta.upgrade_max("bounty") == 5, "fixed upgrades do not grow")
	_check(Meta.is_upgrade_unlocked("bounty") and Meta.buy_upgrade("bounty"), "bounty unlocked")
	_check(is_equal_approx(Meta.bounty_mult(), 1.0 + Meta.BOUNTY_PER_LV), "bounty multiplier")
	_check(Meta.last_unlocks.size() == 3 and Meta.last_unlocks[0].contains(StageDefs.title(2))
			and Meta.last_unlocks[2].contains("BOUNTY"), "unlock list for the clear screen")
	_check(Meta.stage == 1, "stage not switched until leaving the results")
	Meta.advance_after_clear()
	_check(Meta.stage == 2, "next stage picked after a first clear")

	# 다시 깨면 보상 없음, 스테이지도 그대로
	Meta.select_stage(1)
	Meta.finish_victory(1)
	_check(Meta.last_unlocks.is_empty() and Meta.stage_cleared == 1, "no rewards for a repeat clear")
	Meta.advance_after_clear()
	_check(Meta.stage == 1, "repeat clear keeps the stage")

	# 2스테이지: 진 판은 그 스테이지 배율로 SHARD, 스테이지별 최고 웨이브
	Meta.select_stage(2)
	before = Meta.shards
	Meta.finish_run(21, 0, 0, 2)
	_check(Meta.shards == before + Meta.shards_for_run(21, 2), "stage 2 run shards")
	_check(Meta.stage_best_wave(2) == 21 and Meta.stage_best_wave(1) == EnemyDefs.FINAL_WAVE,
			"best wave per stage")

	# 2 클리어 -> WARP CORE, 3 클리어 -> 출정 칸 +1, 4 클리어 -> SKILL TUNING
	Meta.finish_victory(2)
	_check(Meta.is_core_available("warp") and Meta.buy_core("warp") and Meta.core_type == "warp",
			"warp core after stage 2")
	Meta.finish_victory(3)
	_check(Meta.max_loadout() == Meta.MAX_LOADOUT + 1, "extra loadout slot after stage 3")
	_check(not Meta.is_upgrade_unlocked("tuning"), "tuning still locked")
	Meta.finish_victory(4)
	_check(Meta.is_upgrade_unlocked("tuning") and Meta.buy_upgrade("tuning"), "tuning after stage 4")
	_check(Meta.cooldown_mult() < 1.0, "tuning shortens cooldowns")
	Meta.finish_victory(n)
	_check(Meta.stage_cleared == n and Meta.upgrade_max("damage") == 5 + Meta.CAP_PER_STAGE * n,
			"last stage raises the cap too")
	_check(not Meta.last_unlocks[0].contains(StageDefs.title(n + 1)), "no stage after the last")
	Meta.advance_after_clear()
	_check(Meta.stage <= n, "stage stays in range")


func _save_and_migrate() -> void:
	Meta.reset()
	Meta.stage_cleared = 2
	Meta.stage = 3
	Meta.stage_best = {1: 30, 2: 30, 3: 14}
	Meta.save_data()
	Meta.reset()
	Meta.load_data()
	_check(Meta.stage_cleared == 2 and Meta.stage == 3 and Meta.stage_best_wave(3) == 14,
			"stage data saved")

	# 스테이지 전 저장 파일: 클리어가 있으면 1스테이지를 깬 것으로, 최고 웨이브는 1스테이지 몫
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 5)
	cfg.set_value("meta", "best_wave", 30)
	cfg.set_value("meta", "clears", 2)
	cfg.save(Meta.save_path)
	Meta.load_data()
	_check(Meta.stage_cleared == 1 and Meta.stage == 2 and Meta.stage_best_wave(1) == 30,
			"old save with clears -> stage 1 cleared")
	cfg = ConfigFile.new()
	cfg.set_value("meta", "best_wave", 17)
	cfg.save(Meta.save_path)
	Meta.load_data()
	_check(Meta.stage_cleared == 0 and Meta.stage == 1, "old save without clears -> stage 1")


func _in_game() -> void:
	Meta.reset()
	Meta.stage_cleared = 1
	Meta.levels["bounty"] = 2
	var shop := _game.shop
	shop.refresh()
	# 시작 화면에서 스테이지 고르기
	var picker := shop._stage_picker
	_check(picker != null, "stage picker on the start screen")
	picker.stage_clicked.emit(3)
	_check(Meta.stage == 1, "locked stage not picked")
	picker.stage_clicked.emit(2)
	_check(Meta.stage == 2, "stage 2 picked")
	_check(Shop.stage_info(3).contains(Loc.t("Clear %s to unlock.") % StageDefs.title(2)),
			"locked stage explains how to open it")
	_check(shop._stage_info.text == Shop.stage_info(2), "stage line shows the picked stage")
	shop.open_window("core")
	var win := shop._window
	var warp: Control = win._grid.get_child(CoreDefs.ORDER.find("warp"))
	var warp_col := warp.get_child(0)
	var warp_button := warp_col.get_child(warp_col.get_child_count() - 1) as Button
	_check(warp_button.disabled and warp_button.text.contains(StageDefs.title(2)),
			"warp core explains how to open it")
	win.close()

	_game.start_run()
	_check(_game.stage == 2 and _game.hud._stage_label.text == StageDefs.title(2), "run uses the picked stage")
	_game.wave = 5
	var grunt := _game.spawn_enemy("grunt", Vector2(-3000, 0))
	_check(is_equal_approx(grunt.max_hp, _game.wave_enemy_hp(5) * StageDefs.hp_mult(2)),
			"enemy hp scaled by stage")
	_check(is_equal_approx(grunt.contact_damage, (10.0 + 5 * 0.5) * StageDefs.damage_mult(2)),
			"enemy damage scaled by stage")
	_check(grunt.reward == maxi(1, roundi(_game.wave_enemy_reward(5) * Meta.bounty_mult())),
			"reward uses bounty, not stage")

	# 코어 스킬마다 효과음이 있다
	for id in CoreDefs.DEFS:
		_check(Sfx.SOUNDS.has("skill_" + CoreDefs.DEFS[id]["skill"]), "sound for %s skill" % id)

	# WARP: 모든 적을 코어에서 멀리
	Meta.unlocked_cores.append("warp")
	_game._apply_core_type("warp")
	var core := _game.board.core_tile()
	var near := _game.spawn_enemy("grunt", core.global_position + Vector2(200, 0))
	var d0 := near.global_position.distance_to(core.global_position)
	_check(_game.use_skill(), "warp used")
	_check(is_equal_approx(near.global_position.distance_to(core.global_position),
			d0 + CoreDefs.get_def("warp")["power"]), "warp throws enemies away")
	_check(is_equal_approx(_game.skill_cooldown, CoreDefs.get_def("warp")["cooldown"]),
			"cooldown without tuning")
	Meta.levels["tuning"] = 2
	_game.skill_cooldown = 0.0
	_game.use_skill()
	_check(is_equal_approx(_game.skill_cooldown,
			CoreDefs.get_def("warp")["cooldown"] * (1.0 - 2 * Meta.TUNING_PER_LV)), "tuning cooldown")
	for e in _game.get_tree().get_nodes_in_group(Enemy.GROUP):
		(e as Enemy).take_damage(1e12)

	# 2스테이지 클리어 화면: 새로 풀린 것 표시, 결과창과 시작 화면은 다음 스테이지로
	_game.wave = EnemyDefs.FINAL_WAVE
	_game._on_victory()
	_check(Meta.stage_cleared == 2 and _game.hud._victory_unlocks.visible
			and _game.hud._victory_unlocks.text.contains("WARP CORE"), "clear screen lists unlocks")
	_check(_game.hud._victory_tag.text.begins_with(StageDefs.title(2)), "clear screen names the stage")
	_check(_game.victory_shards == Meta.shards_for_victory(2), "stage 2 victory shards")
	_game.end_run_after_victory()
	_check(_game.results.data["stage"] == 2 and _game.results._tag.text.begins_with(StageDefs.title(2)),
			"results show the stage")
	_game.results.continue_pressed.emit()
	_check(_game.shop.is_open() and Meta.stage == 3, "start screen moves on to stage 3")
	_game.get_tree().paused = false
