extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_shock.gd
## SHOCK 타일 (충격파): 퍼지는 링, 스턴, 보스 감소, 다시 스턴 면역, 고정 주기, 강화, 장비, 카드.

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
	_check(TileDefs.PLACEABLE.has("shock"), "shock is a card tile")
	_check(Meta.TILE_PRICES.has("shock") and not Meta.is_tile_unlocked("shock"), "shock is bought with shards")

	var shock := HexTile.new()
	shock.setup("shock")
	shock.board = board
	shock.position = Vector2(0, -700)
	board.add_child(shock)
	_check(shock.attack == "shock" and shock._shock != null, "shock tile has a wave node")
	var wave := shock._shock

	# 적이 없으면 안 쏜다
	_check(not wave.fire(), "no wave without enemies")

	# 링이 퍼지면서 가까운 적부터 스턴, 사거리 밖은 안 맞음
	var near := _spawn_at(shock.position + Vector2(30, 0))
	var mid := _spawn_at(shock.position + Vector2(0, 160))
	var far := _spawn_at(shock.position + Vector2(shock.effective_range() + 80.0, 0))
	_check(wave.fire() and wave.is_active(), "fires when an enemy is in range")
	_check(near.is_frozen() and not mid.is_frozen(), "ring reaches the near enemy first")
	_check(near.hp < near.max_hp and near.hp > near.max_hp - 10.0, "tiny damage on hit")
	for i in 30:
		wave.tick(1.0 / 60.0)
	_check(mid.is_frozen(), "ring reaches the farther enemy later")
	_check(not far.is_frozen() and far.hp == far.max_hp, "enemy outside range untouched")
	_check(not wave.is_active(), "ring ends at the edge of range")
	_check(wave.stunned == 2, "two enemies stunned (%d)" % wave.stunned)

	# 스턴 시간, 보스는 짧게
	_check(absf(near._freeze_timer - shock.stun_time) < 0.01, "stun lasts stun_time")
	var boss := _spawn_at(shock.position + Vector2(-60, 0))
	boss.is_boss = true
	_check(boss.stun(1.0) and absf(boss._freeze_timer - Enemy.BOSS_STUN_MULT) < 0.01, "boss stun is shorter")

	# 스턴이 풀린 뒤 잠깐은 다시 안 걸린다
	var e := _spawn_at(shock.position + Vector2(0, 400))
	_check(e.stun(0.5), "first stun lands")
	_check(not e.stun(0.5), "no restun while immune")
	e._stun_immune = 0.0
	_check(e.stun(0.5), "stun again after immunity")

	# 공격 속도는 파장 주기를 바꾸지 않고 링 속도만 올린다
	var iv := shock.interval()
	var sp := wave.speed()
	board.rate_mult = 2.0
	_check(absf(shock.interval() - iv) < 0.001, "attack speed keeps the wave period")
	_check(absf(wave.speed() - sp * 2.0) < 0.01, "attack speed makes the ring faster")
	board.rate_mult = 1.0

	# 강화: 주기는 그대로, 스턴 +, 링 속도 +
	var stun0 := shock.stun_time
	_check(shock.upgrade_preview().has(Loc.t("STUN %.1f S > %.1f S") % [stun0, stun0 + ShockWave.UPG_STUN]),
			"preview shows stun time")
	shock.upgrade()
	_check(absf(shock.interval() - iv) < 0.001, "upgrade keeps the wave period")
	_check(absf(shock.stun_time - (stun0 + ShockWave.UPG_STUN)) < 0.001, "upgrade adds stun")
	_check(wave.speed() > sp * 1.05, "upgrade makes the ring faster")
	for i in 20:
		shock.upgrade()
	_check(shock.stun_time <= ShockWave.STUN_MAX + 0.001, "stun time is capped")

	# 장비
	_check(not GearDefs.can_equip("splitter", shock), "splitter not for shock")
	for id in ["scope", "igniter", "crit", "detonator"]:
		_check(GearDefs.can_equip(id, shock), "shock takes %s" % id)
	shock.equip("igniter")
	var lit := _spawn_at(shock.position + Vector2(30, 20))
	wave.fire()
	_check(lit.is_burning(), "igniter sets shocked enemies on fire")

	# 출정 타일에 넣으면 카드로 나온다
	Meta.unlocked.append("shock")
	Meta.loadout = ["shock"]
	var seen := false
	for i in 40:
		for o in _game.make_options():
			if o["type"] == "tile" and o["kind"] == "shock":
				seen = true
	_check(seen, "shock card shows up when in loadout")
	shock.queue_free()


func _spawn_at(pos: Vector2) -> Enemy:
	var en := Enemy.new()
	en.max_hp = 1000.0
	en.speed = 0.0
	_game.board.enemy_layer.add_child(en)
	en.global_position = _game.board.to_global(pos)
	return en
