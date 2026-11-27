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

	# 빙결(감속) 상태에서 분열하면 갈라진 적도 같은 감속을 남은 시간만큼 이어받음
	var frozen := _game.spawn_enemy("splitter", Vector2(-2000, -400))
	frozen.apply_slow(0.5, 0.6)
	frozen.take_damage(99999.0)
	var kids: Array[Enemy] = []
	for node in get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.kind == "runner" and e.global_position.distance_to(Vector2(-2000, -400)) < 40.0:
			kids.append(e)
	_check(kids.size() == 2 and kids.all(func(k: Enemy) -> bool:
			return k.is_slowed() and k._slow_factor == 0.5 and absf(k._slow_timer - 0.6) < 0.01),
			"split children keep parent's slow")
	var plain := _game.spawn_enemy("splitter", Vector2(-2000, -700))
	plain.take_damage(99999.0)
	var plain_kids := 0
	for node in get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.kind == "runner" and e.global_position.distance_to(Vector2(-2000, -700)) < 40.0 \
				and not e.is_slowed():
			plain_kids += 1
	_check(plain_kids == 2, "children of unslowed splitter are not slowed")

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

	# 보스는 타일에 닿아도 죽지 않고 계속 때린다. 타일이 부서지면 다음 타일로 간다
	var board := _game.board
	var weak := board.place_tile(Vector2i(1, 0), "laser")
	weak.hp = 15.0
	var boss := _game.spawn_enemy("boss", weak.global_position + Vector2(60, 0))
	boss.contact_damage = 10.0
	var core := board.core_tile()
	var core_hp := core.hp
	var dist_before := boss.global_position.distance_to(core.global_position)
	for i in 150:
		boss._process(1.0 / 60.0)
	_check(boss.is_alive(), "boss survives hitting a tile")
	_check(not board.tiles.has(Vector2i(1, 0)), "boss destroyed the weak tile")
	_check(core.hp == core_hp, "boss hit only the tile it was touching")
	_check(boss.global_position.distance_to(core.global_position) < dist_before,
			"boss moves on to the next tile")
	var bumper := _game.spawn_enemy("grunt", core.global_position + Vector2(30, 0))
	bumper._process(1.0 / 60.0)
	_check(not bumper.is_alive(), "normal enemy still dies on contact")
	boss.queue_free()
	core.hp = core.max_hp

	# LASER: 광선이 줄 위 적을 관통하고, 같은 적을 계속 맞히면 피해가 커진다
	var las := HexTile.new()
	las.setup("laser")
	board.add_child(las)
	las.global_position = Vector2(-3000, -2000)
	var front := _game.spawn_enemy("grunt", las.global_position + Vector2(100, 0))
	var back := _game.spawn_enemy("grunt", las.global_position + Vector2(220, 0))
	var side := _game.spawn_enemy("grunt", las.global_position + Vector2(100, 160))
	for e in [front, back, side]:
		e.max_hp = 10000.0
		e.hp = 10000.0
	las._fire_laser()
	var first_hit := 10000.0 - front.hp
	_check(first_hit > 0.0 and back.hp < 10000.0, "laser pierces enemies in a line")
	_check(side.hp == 10000.0, "laser misses enemies off the line")
	for i in 8:
		las._fire_laser()
	var hp_before := front.hp
	las._fire_laser()
	var focused_hit := hp_before - front.hp
	_check(absf(focused_hit - first_hit * (1.0 + las.focus_step * las.focus_max)) < 0.01,
			"focus caps at x%.1f (first %.1f, now %.1f)" % [1.0 + las.focus_step * las.focus_max,
			first_hit, focused_hit])
	front.global_position += Vector2(0, 5000)
	las._fire_laser()
	_check(las.focus_stacks() == 0, "focus resets on a new target")
	for e in [front, back, side]:
		e.queue_free()
	las.queue_free()

	# DRONE HIVE: 드론 2기가 사거리 안 적을 쫓아가 들이받는다. 강화하면 +1기
	var hive := HexTile.new()
	hive.setup("drone")
	hive.board = board
	board.add_child(hive)
	hive.global_position = Vector2(-3000, 2000)
	hive._sync_drones()
	_check(hive._drones.size() == 2, "hive launches 2 drones")
	var prey := _game.spawn_enemy("grunt", hive.global_position + Vector2(160, 0))
	prey.max_hp = 10000.0
	prey.hp = 10000.0
	for i in 120:
		for d in hive._drones:
			d._process(1.0 / 60.0)
	_check(prey.hp < 10000.0, "drones chase and hit enemies")
	_check(hive._drones.all(func(d: Drone) -> bool: return d.target == prey), "drones lock on")
	# 통계: 준 피해가 타일별로 기록된다 (장갑 반영, 넘친 피해 제외)
	var recorded := board.stats.damage(hive.get_instance_id(), board.stats.current_wave)
	_check(absf(recorded - (10000.0 - prey.hp)) < 0.01, "damage stats per tile (%.1f)" % recorded)
	var tiny := _game.spawn_enemy("grunt", Vector2(-2000, 3000))
	tiny.hp = 3.0
	var before_total := board.stats.total(hive.get_instance_id())
	hive.apply_hit(tiny, 50.0)
	_check(absf(board.stats.total(hive.get_instance_id()) - before_total - 3.0) < 0.01,
			"overkill not counted")
	# 쫓던 적이 사라져도 오류 없이 다음 목표를 찾는다
	prey.free()
	for d in hive._drones:
		d._process(1.0 / 60.0)
	_check(hive._drones.all(func(d: Drone) -> bool: return d.target == null), "drones drop freed target")
	hive.upgrade()
	hive.upgrade()
	hive._sync_drones()
	_check(hive._drones.size() == 3, "level 3 adds a drone")
	hive.queue_free()

	# ARCHER: 맞닿은 ARCHER 1개당 공격력 +40%
	var a1 := board.place_tile(board.placeable_cells()[0], "archer")
	var a2: HexTile = null
	for n in HexGrid.neighbors(a1.coord):
		if board.can_place(n):
			a2 = board.place_tile(n, "archer")
			break
	_check(a2 != null and a1.linked_archers() == 1 and a2.linked_archers() == 1, "archers link")
	_check(absf(a1.damage() - a1.base_damage * board.damage_mult * 1.4) < 0.001,
			"linked archer +40%% dmg (%.2f)" % a1.damage())
	a2.take_damage(1e9)
	_check(a1.linked_archers() == 0, "link breaks when neighbor archer dies")
	a1.take_damage(1e9)

	# PRISM: 맞닿은 LASER가 쏘면 LASER -> PRISM 방향으로 세 갈래 광선 (갈래마다 40%)
	var beam := board.place_tile(board.placeable_cells()[0], "laser")
	var prism: HexTile = null
	for n in HexGrid.neighbors(beam.coord):
		if board.can_place(n) and HexGrid.distance(n, Vector2i.ZERO) > HexGrid.distance(beam.coord, Vector2i.ZERO):
			prism = board.place_tile(n, "prism")
			break
	_check(prism != null and beam.adjacent_prisms() == [prism] and prism.prism_sources() == [beam],
			"prism sees adjacent laser")
	var ray_dir := beam.position.direction_to(prism.position)
	var in_line := _game.spawn_enemy("grunt", prism.global_position + ray_dir * 150.0)
	var bait := _game.spawn_enemy("grunt", beam.global_position - ray_dir * 120.0)
	for e in [in_line, bait]:
		e.max_hp = 10000.0
		e.hp = 10000.0
		e.speed = 0.0
	beam._fire_laser()
	_check(absf((10000.0 - in_line.hp) - beam.damage() * prism.split) < 0.01,
			"refracted ray hits in prism direction (%.2f)" % (10000.0 - in_line.hp))
	_check(prism._shot_targets.size() == 3, "prism splits into 3 rays")
	# ARCHER + PRISM: 곧게 나는 화살 세 개, 같은 방향
	beam.take_damage(1e9)
	var bow := board.place_tile(beam.coord, "archer")
	ray_dir = bow.position.direction_to(prism.position)
	in_line.global_position = prism.global_position + ray_dir * 150.0
	in_line.hp = 10000.0
	bait.global_position = bow.global_position - ray_dir * 120.0
	bow._fire()
	var prism_arrows: Array = board.enemy_layer.get_children().filter(func(n: Node) -> bool:
		return n is Arrow and n.source == prism)
	_check(prism_arrows.size() == 3, "prism splits archer shot into 3 arrows")
	for i in 30:
		for ar in prism_arrows:
			if is_instance_valid(ar):
				ar._process(1.0 / 60.0)
	_check(absf((10000.0 - in_line.hp) - bow.damage() * prism.split) < 0.01,
			"straight arrow hits enemy in line (%.2f)" % (10000.0 - in_line.hp))
	for t in [bow, prism]:
		t.take_damage(1e9)
	for e in [in_line, bait]:
		e.queue_free()

	# 보스 웨이브: 일반 적 다음에 보스 1마리
	_game._begin_wave()  # wave 5 -> 6
	_game.wave = 9
	_game._begin_wave()  # -> 10
	_check(_game._boss_pending, "boss pending on wave 10")
