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
	_check(absf(core.damage() / dmg_before - HexTile.UPG_DAMAGE) < 0.01, "upgrade damage x1.5")
	_check(core.upgrade_preview().has("+1 BEAM"), "preview shows beam at next level")
	core.upgrade()
	_check(core.target_count() == 2, "laser/core gets extra beam at lv 3")
	var frost := HexTile.new()
	frost.setup("frost")
	var slow_before := frost.frost_slow
	frost.upgrade()
	_check(frost.frost_slow < slow_before, "frost upgrade slows more")
	frost.free()
	_game.add_money(-_game.money)

	# 타일 선택
	board.select_tile(core)
	_check(board.selected_tile == core and core.selected, "select tile")
	board.select_tile(null)
	_check(board.selected_tile == null and not core.selected, "deselect tile")

	# 웨이브 클리어 카드: 무작위 구성 (서로 다른 3장, 타일 카드 수가 매번 달라질 수 있음)
	var tile_counts := {}
	for i in 300:
		var opts := _game.make_options()
		_check(opts.size() == 3, "3 options")
		var titles := {}
		var n_tiles := 0
		for o in opts:
			titles[o["title"]] = true
			if o["type"] == "tile":
				n_tiles += 1
		_check(titles.size() == 3, "options are distinct")
		tile_counts[n_tiles] = true
	_check(tile_counts.size() >= 3, "card mix varies (tile counts seen: %s)" % [tile_counts.keys()])
	# 타일 카드와 강화 카드가 모두 있는 구성을 골라 아래 흐름을 확인
	_game.state = Game.State.CHOOSING
	var tile_idx := -1
	var boost_idx := -1
	while tile_idx < 0 or boost_idx < 0:
		_game.current_options = _game.make_options()
		tile_idx = -1
		boost_idx = -1
		for i in _game.current_options.size():
			if _game.current_options[i]["type"] == "tile":
				tile_idx = i
			elif _game.current_options[i]["type"] == "boost":
				boost_idx = i

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

	# ORBIT: 도는 구체가 궤도 위의 적을 때리고, 궤도 밖의 적은 건드리지 않는다
	# 다른 타일 사거리 밖에 보드 규칙 없이 직접 놓는다
	var orbit := HexTile.new()
	orbit.setup("orbit")
	orbit.board = board
	orbit.position = Vector2(0, -600)
	board.add_child(orbit)
	_check(orbit.orb_count() == 3, "orbit starts with 3 orbs")
	var on_path := _spawn_enemy_at(orbit.position + Vector2(orbit.effective_range(), 0))
	var off_path := _spawn_enemy_at(orbit.position + Vector2(orbit.effective_range() + 90.0, 0))
	var inside := _spawn_enemy_at(orbit.position + Vector2(30, 0))
	for i in 120:
		orbit._process_orbit(1.0 / 60.0)
	var hits := roundi((on_path.max_hp - on_path.hp) / orbit.damage())
	_check(hits >= 2 and hits <= 5, "orbs hit enemy on orbit path (hits %d)" % hits)
	_check(off_path.hp == off_path.max_hp, "enemy outside orbit untouched")
	_check(inside.hp == inside.max_hp, "enemy inside orbit untouched")
	orbit.equip("splitter")
	_check(orbit.orb_count() == 4, "splitter adds an orb")
	orbit.upgrade()
	_check(orbit.orb_count() == 5, "upgrade adds an orb")
	_check(GearDefs.can_equip("detonator", orbit), "orbit takes attack gear")
	for e in [on_path, off_path, inside]:
		e.queue_free()
	orbit.queue_free()

	# 장비: 카드 -> 장착 모드 -> 맞지 않는 타일은 실패 -> 맞는 타일에 장착
	var bank_tile := board.place_tile(Vector2i(-1, 0), "bank")
	_game.state = Game.State.CHOOSING
	_game.current_options = [{"type": "gear", "gear": "scope", "title": "SCOPE",
			"color": Color.WHITE}]
	_game.choose_option(0)
	_check(_game.state == Game.State.EQUIPPING and board.is_equipping(), "gear -> equipping")
	_check(not board.equippable_tiles().has(bank_tile), "scope not equippable on bank")
	_check(board.try_equip(bank_tile.coord) == null, "cannot equip scope on bank")
	var range_before := core.effective_range()
	_check(board.try_equip(core.coord) == core, "equip scope on core")
	_check(core.gear == "scope" and core.effective_range() > range_before, "scope adds range")
	_check(_game.state == Game.State.INTERMISSION, "equip -> intermission")

	# 장비 교체
	core.equip("splitter")
	_check(core.gear == "splitter" and core.target_count() == 2 + core.extra_beams, "splitter replaces scope")
	_check(core.effective_range() == core.attack_range, "scope bonus gone after replace")
	_check(not board.tiles.values().any(func(t: HexTile) -> bool:
			return t.kind == "bank" and GearDefs.ids().any(func(id: String) -> bool:
				return GearDefs.can_equip(id, t))), "bank takes no gear")

	# CRIT LENS: 평균 피해가 늘어난다 (25% 확률로 3.5배 → 기대값 1.625배)
	core.equip("crit")
	var tank := _spawn_enemy_at(Vector2(-700, 400))
	tank.max_hp = 100000.0
	tank.hp = tank.max_hp
	for i in 1000:
		core.apply_hit(tank, 1.0)
	var dealt := tank.max_hp - tank.hp
	var crit_avg := 1000.0 * (1.0 - GearDefs.CRIT_CHANCE + GearDefs.CRIT_CHANCE * GearDefs.CRIT_MULT)
	_check(absf(dealt - crit_avg) < crit_avg * 0.12, "crit average damage (dealt %.0f, expected %.0f)" % [dealt, crit_avg])
	tank.queue_free()

	# DETONATOR: 맞힐 때마다 폭발해 근처 다른 적에게 맞힌 피해의 35%, 멀리 있는 적은 무사
	core.equip("detonator")
	var target := _spawn_enemy_at(Vector2(600, 400))
	var near := _spawn_enemy_at(Vector2(660, 400))
	var away := _spawn_enemy_at(Vector2(900, 400))
	core.apply_hit(target, 2.0)
	_check(target.is_alive(), "detonator works without a kill")
	_check(is_equal_approx(target.max_hp - target.hp, 2.0), "hit enemy takes no extra blast")
	_check(is_equal_approx(near.max_hp - near.hp, 2.0 * GearDefs.DETONATE_RATIO),
			"explosion hurts nearby enemy (%.2f)" % (near.max_hp - near.hp))
	_check(away.hp == away.max_hp, "explosion misses far enemy")
	target.queue_free()
	near.queue_free()
	away.queue_free()

	# 장비 효과: IGNITER 화상
	var victim := _spawn_enemy_at(Vector2(-700, -400))
	core.equip("igniter")
	core.apply_hit(victim, 1.0)
	_check(victim.is_burning(), "igniter burns")
	victim.queue_free()
	_check(not GearDefs.DEFS.has("cryo") and not GearDefs.DEFS.has("collector"),
			"removed gear stays removed")

	# 카드 풀에 장비 카드가 등장
	var saw_gear := false
	for i in 100:
		for o in _game.make_options():
			if o["type"] == "gear":
				saw_gear = true
	_check(saw_gear, "gear cards appear in draws")

	# BANK: 웨이브 클리어 때 돈
	var bank := HexTile.new()
	bank.setup("bank")
	_check(bank.income > 0, "bank has income")
	bank.free()

	# 후반 성장: 강화 카드는 웨이브가 높을수록 세다
	var saved_wave := _game.wave
	_game.wave = 1
	var early_v := _game.boost_value("damage")
	_game.wave = 21
	_check(_game.boost_value("damage") > early_v * 1.4, "late boost cards are stronger")
	_game.wave = saved_wave
	# OVERCHARGE / OVERCLOCK는 더하기로 쌓인다 (두 번 고르면 같은 양씩 늘어남)
	var dm0 := board.damage_mult
	var dv := _game.boost_value("damage") / 100.0
	_game._apply_boost("damage")
	_game._apply_boost("damage")
	_check(absf(board.damage_mult - dm0 - dv * 2.0) < 0.001, "overcharge stacks additively")
	board.damage_mult = dm0
	var rm0 := board.rate_mult
	_game._apply_boost("rate")
	_check(absf(board.rate_mult - rm0 - _game.boost_value("rate") / 100.0) < 0.001,
			"overclock stacks additively")
	board.rate_mult = rm0
	# REINFORCE: 코어 최대 체력 +v, 다른 타일 최대 체력 +15%, 모두 완전 수리
	var some: HexTile = null
	for t in board.tiles.values():
		if t != board.core_tile():
			some = t
	_check(some != null, "a non-core tile exists for the reinforce test")
	if some != null:
		var hp0 := some.max_hp
		some.hp = 1.0
		var core_t := board.core_tile()
		var core_max := core_t.max_hp
		core_t.hp = 1.0
		_game._apply_boost("repair")
		_check(is_equal_approx(some.max_hp, hp0 * (1.0 + Game.REINFORCE_TILE_HP))
				and is_equal_approx(some.hp, some.max_hp), "reinforce boosts and repairs tiles")
		_check(is_equal_approx(core_t.max_hp, core_max + _game.boost_value("repair"))
				and is_equal_approx(core_t.hp, core_t.max_hp), "reinforce boosts and repairs core")
	# RESONANCE: 이후 웨이브를 넘길 때마다 공격력이 더해진다
	_game.resonance = 0.0
	_game._apply_boost("resonance")
	var res_v := _game.resonance
	var mult_before := board.damage_mult
	_game.state = Game.State.WAVE
	_game._on_wave_cleared()
	_check(absf(board.damage_mult - mult_before - res_v) < 0.001 and res_v > 0.0, "resonance grows damage per wave")
	_game.hud.hide_choices()
	_game.state = Game.State.INTERMISSION
	_game.resonance = 0.0
	# BANK 이자: 가진 돈의 4%, 최대 수입 × 4
	var bank_t := HexTile.new()
	bank_t.setup("bank")
	_game.add_money(-_game.money + 500)
	_check(_game.bank_interest(bank_t) == 20, "bank interest 4%% (got %d)" % _game.bank_interest(bank_t))
	_game.add_money(10000)
	_check(_game.bank_interest(bank_t) == bank_t.income * Game.BANK_INTEREST_CAP, "interest capped")
	bank_t.free()
	_game.add_money(-_game.money)

	# BOOSTER: 맞닿은 타일만 공격 속도 +25%, 강화하면 +35%, 여러 개면 더해짐
	var free_cells: Array[Vector2i] = []
	for n in HexGrid.neighbors(core.coord):
		if not board.tiles.has(n):
			free_cells.append(n)
	# 앞에서 무작위 카드로 BOOSTER가 이미 놓였을 수 있으므로 기존 보너스를 기준으로 비교
	var bonus0 := core.haste_bonus()
	var base_interval := core.interval() * (1.0 + bonus0)
	var far_tile: HexTile = null
	for t in board.tiles.values():
		if HexGrid.distance(t.coord, core.coord) >= 2 and t.attack != "none":
			far_tile = t
	var far_before := far_tile.interval() if far_tile != null else 0.0
	var booster := board.place_tile(free_cells[0], "booster")
	_check(booster != null and booster.attack == "none", "booster placed")
	_check(absf(base_interval / core.interval() - (1.25 + bonus0)) < 0.001, "adjacent tile 25% faster")
	if far_tile != null and HexGrid.distance(far_tile.coord, booster.coord) > 1:
		_check(far_tile.interval() == far_before, "non-adjacent tile unaffected")
	_check(booster.boosted_neighbors().has(core), "booster lists core as boosted")
	booster.upgrade()
	_check(absf(base_interval / core.interval() - (1.35 + bonus0)) < 0.001, "upgraded booster +35%")
	var booster2 := board.place_tile(free_cells[1], "booster")
	_check(absf(base_interval / core.interval() - (1.60 + bonus0)) < 0.001, "two boosters stack")
	_check(not GearDefs.ids().any(func(id: String) -> bool: return GearDefs.can_equip(id, booster2)),
			"booster takes no gear")

	# 그리드가 꽉 차면 타일 카드 없음
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, board.grid_radius):
		if not board.tiles.has(cell):
			board.tiles[cell] = core  # 자리만 채움
	var full_opts := _game.make_options()
	_check(full_opts.all(func(o: Dictionary) -> bool: return o["type"] != "tile"),
			"no tile cards when board is full")


func _spawn_enemy_at(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.max_hp = 100.0
	e.speed = 0.0
	_game.board.enemy_layer.add_child(e)
	e.global_position = _game.board.to_global(pos)
	return e
