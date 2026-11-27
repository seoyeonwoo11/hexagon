extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_progression.gd
## 성장 시스템: 타일 종류, 강화, 웨이브 클리어 카드, 배치 모드.

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
		_run()
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _run() -> void:
	var board := _game.board
	var core := board.core_tile()
	_check(core.kind == "core" and core.max_hp == 100.0, "core tile setup")

	# 모든 타일 종류가 만들어지는지
	for kind in TileDefs.PLACEABLE:
		var t := HexTile.new()
		t.setup(kind)
		_check(t.display_name == TileDefs.get_def(kind)["name"], "setup %s" % kind)
		t.free()

	# 강화: 돈이 모자라면 실패, 충분하면 레벨업 + 돈 차감
	var cost := core.upgrade_cost()
	_check(not _game.try_upgrade(core), "upgrade fails without money")
	_game.add_money(cost + 5)
	var dmg_before := core.damage()
	_check(_game.try_upgrade(core), "upgrade succeeds")
	_check(core.level == 2, "level 2")
	_check(_game.money == 5, "money deducted")
	_check(core.damage() > dmg_before, "damage increased")
	_check(core.upgrade_cost() > cost, "next upgrade costs more")

	# 타일 선택
	board.select_tile(core)
	_check(board.selected_tile == core and core.selected, "select tile")
	board.select_tile(null)
	_check(board.selected_tile == null and not core.selected, "deselect tile")

	# 웨이브 클리어 카드
	_game.state = Game.State.CHOOSING
	_game.current_options = _game.make_options()
	_check(_game.current_options.size() == 3, "3 options")
	var tile_idx := -1
	var boost_idx := -1
	for i in _game.current_options.size():
		if _game.current_options[i]["type"] == "tile":
			tile_idx = i
		else:
			boost_idx = i
	_check(tile_idx >= 0 and boost_idx >= 0, "has tile and boost options")
	var tile_cards := _game.current_options.filter(func(o: Dictionary) -> bool: return o["type"] == "tile")
	_check(tile_cards.size() == 1, "one tile card")

	# 강화 카드: 바로 다음 웨이브 대기로
	var opts_copy := _game.current_options.duplicate()
	_game.choose_option(boost_idx)
	_check(_game.state == Game.State.INTERMISSION, "boost -> intermission")

	# 타일 카드: 배치 모드 -> 맞닿지 않은 칸은 실패 -> 맞닿은 칸에 배치
	_game.state = Game.State.CHOOSING
	_game.current_options = opts_copy
	var kind: String = opts_copy[tile_idx]["kind"]
	_game.choose_option(tile_idx)
	_check(_game.state == Game.State.PLACING and board.is_placing(), "tile -> placing")
	_check(board.try_place(Vector2i(3, 0)) == null, "cannot place far away")
	_check(board.is_placing(), "still placing after invalid click")
	var placed := board.try_place(Vector2i(0, 1))
	_check(placed != null and placed.kind == kind, "placed chosen kind")
	_check(not board.is_placing(), "placement ends")
	_check(_game.state == Game.State.INTERMISSION, "placement -> intermission")

	# 전체 강화 배율이 타일에 반영되는지
	var before := placed.damage()
	_game._apply_boost("damage")
	if placed.attack != "none":
		_check(placed.damage() > before, "damage boost applies")

	# SPARK: 번개가 가까운 적들 사이를 튕긴다
	var e1 := _spawn_enemy_at(Vector2(150, 0))
	var e2 := _spawn_enemy_at(Vector2(250, 0))
	var e3 := _spawn_enemy_at(Vector2(350, 0))
	var far := _spawn_enemy_at(Vector2(-900, 0))
	var bolt := ChainBolt.new()
	bolt.damage = 1.0
	bolt.bounces = 3
	board.enemy_layer.add_child(bolt)
	bolt.launch(Vector2.ZERO, e1)
	for i in 60:
		if bolt.is_queued_for_deletion() or bolt._done:
			break
		bolt._process(1.0 / 60.0)
	_check(bolt.hit_count() == 3, "bolt hit 3 nearby enemies (hit %d)" % bolt.hit_count())
	_check(e1.hp < e1.max_hp and e2.hp < e2.max_hp and e3.hp < e3.max_hp, "chain damaged all")
	_check(far.hp == far.max_hp, "far enemy untouched")
	for e in [e1, e2, e3, far]:
		e.queue_free()

	# BANK: 웨이브 클리어 때 돈
	var bank := HexTile.new()
	bank.setup("bank")
	_check(bank.income > 0, "bank has income")
	bank.free()

	# 그리드가 꽉 차면 타일 카드 없음
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, board.grid_radius):
		if not board.tiles.has(cell):
			board.tiles[cell] = core  # 자리만 채움
	var full_opts := _game.make_options()
	_check(full_opts.all(func(o: Dictionary) -> bool: return o["type"] == "boost"),
			"no tile cards when board is full")


func _spawn_enemy_at(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.max_hp = 100.0
	e.speed = 0.0
	_game.board.enemy_layer.add_child(e)
	e.global_position = _game.board.to_global(pos)
	return e
