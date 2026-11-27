extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_burn.gd
## BURN 타일 (화염방사기): 부채꼴 불길, 화상, 옮겨붙기, 강화, 장비, 카드.

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
	_check(TileDefs.PLACEABLE.has("burn"), "burn is a card tile")
	_check(Meta.TILE_PRICES.has("burn") and not Meta.is_tile_unlocked("burn"), "burn is bought with shards")

	var burn := HexTile.new()
	burn.setup("burn")
	burn.board = board
	burn.position = Vector2(0, -700)
	board.add_child(burn)
	_check(burn.attack == "burn" and burn._flame != null, "burn tile has a flame jet")
	_check(burn.burn_time == 2.5 and burn.cone > 0.0, "burn time and cone from defs")

	# 가장 가까운 적(0도) 쪽으로 불길. 25도 적은 불길 안, 37도 적은 밖, 뒤쪽과 사거리 밖도 밖.
	var aim := _spawn_at(burn.position + Vector2(60, 0))
	var edge_pos := burn.position + Vector2.from_angle(deg_to_rad(25.0)) * 150.0
	var edge := _spawn_at(edge_pos)
	var outward := -Vector2.from_angle(deg_to_rad(25.0)).orthogonal()
	var touching := _spawn_at(edge_pos + outward * 32.0)
	var behind := _spawn_at(burn.position + Vector2(-130, 0))
	var far := _spawn_at(burn.position + Vector2(burn.effective_range() + 60.0, 0))
	_check(burn._flame.fire(), "fires when enemies are in range")
	_check(aim.hp < aim.max_hp and aim.is_burning(), "aimed enemy hit and burning")
	_check(edge.hp < edge.max_hp and edge.is_burning(), "enemy inside the cone hit")
	_check(touching.hp == touching.max_hp and not touching.is_burning(), "enemy outside the cone untouched")
	_check(behind.hp == behind.max_hp, "enemy behind untouched")
	_check(far.hp == far.max_hp, "enemy out of range untouched")
	var dps := burn.damage() * FlameJet.BURN_DPS_RATIO
	_check(is_equal_approx(edge.burn_dps(), dps), "burn dps = damage x ratio")
	_check(edge.burn_spread == FlameJet.SPREAD_HOPS, "flame burn can spread")

	# 옮겨붙기: 맞닿은 적에게 약해진 불
	burn._flame._spread()
	_check(touching.is_burning(), "fire spread to touching enemy")
	_check(is_equal_approx(touching.burn_dps(), dps * FlameJet.SPREAD_RATIO), "spread fire is weaker")
	_check(touching.burn_spread == FlameJet.SPREAD_HOPS - 1, "spread uses up a hop")
	_check(not behind.is_burning() and not far.is_burning(), "fire does not jump to far enemies")
	_check(burn._flame.spreads >= 1, "spread counted")

	# 화상은 BURN_TICK마다 몰아서 들어가고 총량은 같다
	var e := _spawn_at(burn.position + Vector2(0, 400))
	e.board = board
	e.apply_burn(10.0, 2.0)
	var hp0 := e.hp
	for i in 60:
		e._process(1.0 / 60.0)
	_check(absf((hp0 - e.hp) - 10.0) < 0.6, "burn deals dps over a second (%.2f)" % (hp0 - e.hp))
	for i in 120:
		e._process(1.0 / 60.0)
	_check(not e.is_burning() and absf((hp0 - e.hp) - 20.0) < 0.6, "burn ends after its time (%.2f)" % (hp0 - e.hp))

	# 강화: 화상 시간 +0.5초
	_check(burn.upgrade_preview().has("BURN 2.5 S > 3.0 S"), "preview shows burn time")
	burn.upgrade()
	_check(is_equal_approx(burn.burn_time, 3.0), "upgrade adds burn time")

	# 장비: 점화기는 못 달고, SPLITTER는 불길 하나 더
	_check(not GearDefs.can_equip("igniter", burn), "igniter not for burn")
	for id in ["scope", "splitter", "crit", "detonator"]:
		_check(GearDefs.can_equip(id, burn), "burn takes %s" % id)
	burn.equip("splitter")
	_check(burn.target_count() == 2, "splitter adds a flame")
	burn._flame.fire()
	_check(burn._flame._angles.size() == 2, "two flames with splitter")

	# 출정 타일에 넣으면 카드로 나온다
	Meta.unlocked.append("burn")
	Meta.loadout = ["burn"]
	var seen := false
	for i in 40:
		for o in _game.make_options():
			if o["type"] == "tile" and o["kind"] == "burn":
				seen = true
	_check(seen, "burn card shows up when in loadout")
	burn.queue_free()


func _spawn_at(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.max_hp = 1000.0
	e.speed = 0.0
	_game.board.enemy_layer.add_child(e)
	e.global_position = _game.board.to_global(pos)
	return e
