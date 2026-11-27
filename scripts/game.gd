class_name Game
extends Node2D
## 게임 진행: 돈, 웨이브, 적 생성, 웨이브 클리어 카드, 타일 강화, 일시정지/배속, 게임 오버.
##
## 상태 흐름:
##   INTERMISSION (잠깐 대기) -> WAVE (적 생성/전투) -> 모든 적 처치 ->
##   CHOOSING (카드 3장 중 선택) -> [타일 카드면 PLACING (칸 클릭해 배치),
##   장비 카드면 EQUIPPING (타일 클릭해 장착)] -> INTERMISSION ...
##
## 판 시작 전과 끝난 뒤에는 시작 화면(Shop)이 뜬다. 판이 끝나면 버틴 웨이브만큼 SHARD를 받고
## (Meta.finish_run), 결과창(ResultsScreen)을 거쳐 Shop에서 영구 강화와 타일 구매를 한 뒤 START로 새 판을 시작한다.

signal money_changed(money: int)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal choices_offered(options: Array)
signal game_over
## FINAL_WAVE를 깼을 때 (클리어 화면이 뜬 순간)
signal victory

enum State { INTERMISSION, WAVE, CHOOSING, PLACING, EQUIPPING }

## 게임 기본 속도. 화면의 "1x"가 이 속도이고 "2x"는 그 두 배.
const BASE_TIME_SCALE := 1.5
const FIRST_WAVE_DELAY := 1.5
const INTERMISSION := 1.5
const SPAWN_MARGIN := 40.0
const CARD_TAG_TILE := "NEW TILE"
const CARD_TAG_BOOST := "BOOST"
const CARD_TAG_GEAR := "GEAR"
## 카드 풀에 한 번에 넣는 장비 수 (전체 장비 중 무작위)
const GEAR_CARDS_IN_POOL := 3

## 강화 카드 종류. 새 카드는 여기와 _apply_boost에 추가한다.
## desc의 {v}는 boost_value(id)로 바뀐다 (웨이브가 높을수록 효과가 커짐).
const BOOSTS := [
	{"id": "damage", "title": "OVERCHARGE", "desc": "All tiles deal +{v}% damage.",
			"color": Color(1.0, 0.35, 0.45)},
	{"id": "rate", "title": "OVERCLOCK", "desc": "All tiles attack {v}% faster.",
			"color": Color(0.3, 1.0, 0.85)},
	{"id": "repair", "title": "REINFORCE",
			"desc": "Core +{v} max HP, other tiles +15% max HP. Repairs all tiles.",
			"color": Color(0.0, 0.95, 1.0)},
	{"id": "resonance", "title": "RESONANCE",
			"desc": "From now on, all tiles gain +{v}% damage after every wave.",
			"color": Color(1.0, 0.55, 0.95)},
]
## 강화 카드 효과: 기본값 + 웨이브당 증가량 (후반 카드일수록 강하다).
## OVERCHARGE/OVERCLOCK/RESONANCE는 모두 더하기로 쌓인다 (곱하면 몰아 먹을 때 끝없이 불어남).
const BOOST_BASE := {"damage": 10.0, "rate": 10.0, "repair": 25.0, "resonance": 1.0}
const BOOST_PER_WAVE := {"damage": 0.3, "rate": 0.3, "repair": 4.0, "resonance": 0.0}
## REINFORCE: 코어 말고 지금 있는 타일들의 최대 체력 증가 비율
const REINFORCE_TILE_HP := 0.15
## BANK 이자: 웨이브 클리어 때 가진 돈의 BANK_INTEREST(강화마다 +1%p), 최대 수입 × BANK_INTEREST_CAP
const BANK_INTEREST := 0.04
const BANK_INTEREST_STEP := 0.01
const BANK_INTEREST_CAP := 3

@onready var board: Board = $Board
@onready var hud: Hud = $HUD
@onready var camera: Camera2D = $Camera2D

var money := 0
var wave := 0
var is_over := false
var speed_multiplier := 1.0
var state := State.INTERMISSION
## 지금 화면에 떠 있는 카드들.
var current_options: Array = []

var _to_spawn := 0
var _spawn_timer := 0.0
var _spawn_interval := 1.0
var _alive := 0
var _intermission := FIRST_WAVE_DELAY
var _boss_pending := false
## RESONANCE 카드로 쌓인, 웨이브마다 공격력 배율에 더해지는 값 (0.02 = +2%p)
var resonance := 0.0
## 판이 시작됐는지 (시작 화면이 떠 있는 동안은 false)
var started := false
## 코어 종류와 스킬: 남은 쿨다운(게임 시간 초), OVERDRIVE처럼 지속되는 스킬의 남은 시간
var core_type := "core"
var skill_cooldown := 0.0
var _skill_active := 0.0
## 타일 옮기기: 웨이브마다 MOVES_PER_WAVE번 (쌓이지 않음)
const MOVES_PER_WAVE := 1
var move_charges := 0
var shop: Shop
## 최종 보스와 클리어: endless면 FINAL_WAVE 뒤로 계속 (무한 모드).
## victory_shards: 클리어 때 이미 받은 SHARD (무한 모드에서 끝나면 그 뒤 웨이브 몫만 더 준다)
var endless := false
var victory_shards := 0
var final_boss: Enemy
var _victory_open := false
## 결과창용 판 기록: 적 종류별 처치 수, 번 돈(쓴 돈은 안 뺌), 실제 플레이 시간(초, 배속 무관)
var kills := {}
var money_earned := 0
var run_time := 0.0
var results: ResultsScreen
## 판 시작 때의 최고 웨이브 (결과창의 NEW BEST 판단)
var best_at_start := 0

## false면 시작 화면 없이 바로 판을 시작한다 (테스트, 자동 플레이용).
static var hub_enabled := true
## 시작 화면에서 START를 눌러 씬을 다시 불러왔을 때 한 번 시작 화면을 건너뛴다.
static var _skip_hub_once := false


func _ready() -> void:
	Loc.ensure_loaded()
	Engine.time_scale = BASE_TIME_SCALE
	get_tree().paused = false
	board.core_destroyed.connect(_on_core_destroyed)
	board.placement_finished.connect(_on_placement_finished)
	board.equip_finished.connect(_on_equip_finished)
	hud.pause_pressed.connect(toggle_pause)
	hud.speed_pressed.connect(toggle_speed)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.option_chosen.connect(choose_option)
	hud.upgrade_pressed.connect(upgrade_selected)
	hud.skill_pressed.connect(use_skill)
	hud.move_pressed.connect(toggle_move)
	hud.close_tile_pressed.connect(func() -> void: board.select_tile(null))
	board.move_finished.connect(_on_move_finished)
	hud.endless_pressed.connect(continue_endless)
	hud.end_run_pressed.connect(end_run_after_victory)
	hud.set_money(money)
	hud.set_wave(wave)
	hud.set_speed(speed_multiplier)
	hud.set_paused(false)
	Meta.ensure_loaded()
	shop = Shop.new()
	shop.start_pressed.connect(_on_shop_start)
	add_child(shop)
	results = ResultsScreen.new()
	results.continue_pressed.connect(_on_results_continue)
	results.retry_pressed.connect(_on_restart_pressed)
	add_child(results)
	if hub_enabled and not _skip_hub_once:
		shop.open()
	else:
		start_run()
	_skip_hub_once = false


## 판 시작: 시작 화면을 닫고 영구 강화를 적용한다.
func start_run() -> void:
	if started:
		return
	started = true
	shop.close()
	Sfx.music("battle")
	board.stats.reset()
	best_at_start = Meta.best_wave
	board.damage_mult *= Meta.damage_mult()
	board.rate_mult *= Meta.rate_mult()
	board.tile_hp_mult = Meta.tile_hp_mult()
	var core := board.core_tile()
	core.max_hp = (core.max_hp + Meta.core_hp_bonus()) * Meta.tile_hp_mult()
	core.hp = core.max_hp
	add_money(Meta.start_money(), false)
	_apply_core_type(Meta.core_type)
	move_charges = MOVES_PER_WAVE
	_update_actions()
	hud.show_banner(Loc.t("READY"), Hud.NEON_CYAN)


## 코어 종류를 코어 타일에 입힌다 (색, 이름, 가운데 모양). 스킬은 바로 쓸 수 있는 상태로 시작.
func _apply_core_type(id: String) -> void:
	core_type = id
	var def := CoreDefs.get_def(id)
	var core := board.core_tile()
	core.core_type = id
	core.color = def["color"]
	core.display_name = def["name"]
	core.queue_redraw()
	skill_cooldown = 0.0
	_skill_active = 0.0
	board.skill_damage_mult = 1.0


func skill_ready() -> bool:
	return started and not is_over and skill_cooldown <= 0.0


## 코어 스킬 쓰기 (Q). 쿨다운 중이거나 판 밖이면 false.
func use_skill() -> bool:
	if not skill_ready() or get_tree().paused:
		return false
	var def := CoreDefs.get_def(core_type)
	var core := board.core_tile()
	var power: float = def["power"]
	var fx_radius := 900.0
	match def["skill"]:
		"overdrive":
			board.skill_damage_mult = 1.0 + power
			_skill_active = def["duration"]
		"freeze":
			for node in get_tree().get_nodes_in_group(Enemy.GROUP):
				(node as Enemy).freeze(def["duration"])
		"repair":
			for t in board.tiles.values():
				t.hp = minf(t.hp + t.max_hp * power, t.max_hp)
			fx_radius = 420.0
		"nova":
			fx_radius = def["radius"]
			for node in get_tree().get_nodes_in_group(Enemy.GROUP):
				var e := node as Enemy
				if e.is_alive() and e.global_position.distance_to(core.global_position) <= fx_radius:
					var frac := CoreDefs.NOVA_BOSS_POWER if e.is_boss else power
					# 장갑과 상관없이 최대 체력의 일정 비율
					e.take_damage(e.max_hp * frac / maxf(1.0 - e.armor, 0.01), core)
	skill_cooldown = def["cooldown"]
	Sfx.play("skill_" + def["skill"])
	var fx := SkillFx.new()
	fx.color = def["color"]
	fx.radius = fx_radius
	board.enemy_layer.add_child(fx)
	fx.global_position = core.global_position
	_update_actions()
	return true


## 타일 옮기기 모드 켜기/끄기 (M). 웨이브 중이나 웨이브 사이에만, 남은 횟수가 있을 때.
func toggle_move() -> void:
	if board.moving:
		board.cancel_move()
	elif can_move():
		board.begin_move()
	_update_actions()


func can_move() -> bool:
	return started and not is_over and move_charges > 0 and not get_tree().paused \
			and (state == State.INTERMISSION or state == State.WAVE)


func _on_move_finished(_tile: HexTile) -> void:
	Sfx.play("place")
	move_charges = maxi(move_charges - 1, 0)
	_update_actions()


func _update_actions() -> void:
	var def := CoreDefs.get_def(core_type)
	hud.set_skill(def["skill_name"], def["color"], skill_cooldown, def["cooldown"],
			_skill_active > 0.0)
	hud.set_move(move_charges, board.moving)


func _on_shop_start() -> void:
	if not started:
		start_run()
	else:
		_skip_hub_once = true
		_restart()


func _process(delta: float) -> void:
	if is_over or not started:
		return
	run_time += delta / Engine.time_scale
	var core := board.core_tile()
	if core != null:
		hud.set_core(core.hp, core.max_hp)
	hud.show_tile_panel(board.selected_tile, money)
	if final_boss != null:
		if is_instance_valid(final_boss) and final_boss.is_alive():
			hud.set_boss_hp(final_boss.hp, final_boss.max_hp, final_boss.enraged)
		else:
			final_boss = null
			hud.hide_boss_bar()
	if skill_cooldown > 0.0 or _skill_active > 0.0:
		skill_cooldown = maxf(skill_cooldown - delta, 0.0)
		if _skill_active > 0.0:
			_skill_active -= delta
			if _skill_active <= 0.0:
				board.skill_damage_mult = 1.0
		_update_actions()

	match state:
		State.INTERMISSION:
			_intermission -= delta
			if _intermission <= 0.0:
				_begin_wave()
		State.WAVE:
			if _to_spawn > 0 or _boss_pending:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					if _to_spawn > 0:
						spawn_enemy(EnemyDefs.pick_kind(wave), _random_spawn_point())
						_to_spawn -= 1
					else:
						_spawn_boss()
						_boss_pending = false
					_spawn_timer = _spawn_interval
			elif _alive == 0:
				if wave == EnemyDefs.FINAL_WAVE and not endless:
					_on_victory()
				else:
					_on_wave_cleared()


## 선택된 타일을 강화한다. 돈이 모자라면 false.
func upgrade_selected() -> bool:
	return try_upgrade(board.selected_tile)


func try_upgrade(tile: HexTile) -> bool:
	if tile == null or not is_instance_valid(tile) or is_over:
		return false
	var cost := tile.upgrade_cost()
	if money < cost:
		Sfx.play("deny")
		return false
	add_money(-cost)
	tile.upgrade()
	Sfx.play("levelup")
	return true


## 카드 3장 만들기: 타일 카드, 강화 카드, 장비 카드(무작위 GEAR_CARDS_IN_POOL개)를 한데 섞어
## 서로 다른 3장을 무작위로 뽑는다. 보드에 놓을 칸이 없으면 타일 카드는 빼고 뽑는다.
## 장착할 타일이 하나도 없는 장비는 넣지 않는다.
func make_options() -> Array:
	var pool: Array = []
	if not board.placeable_cells().is_empty():
		# 출정 타일(시작 화면에서 고른 최대 6종)만 카드로 나온다
		for kind in TileDefs.PLACEABLE:
			if not Meta.in_loadout(kind):
				continue
			var def := TileDefs.get_def(kind)
			pool.append({"type": "tile", "kind": kind, "tag": CARD_TAG_TILE,
					"title": def["name"], "desc": Loc.t(def["desc"]), "color": def["color"]})
	for boost in BOOSTS:
		var opt: Dictionary = boost.duplicate()
		opt["desc"] = Loc.t(opt["desc"]).replace("{v}", "%d" % roundi(boost_value(opt["id"])))
		opt["type"] = "boost"
		opt["tag"] = CARD_TAG_BOOST
		pool.append(opt)
	var gear_ids := GearDefs.ids()
	gear_ids.shuffle()
	var added := 0
	for id in gear_ids:
		if added >= GEAR_CARDS_IN_POOL:
			break
		if not board.tiles.values().any(func(t: HexTile) -> bool: return GearDefs.can_equip(id, t)):
			continue
		var gdef := GearDefs.get_def(id)
		pool.append({"type": "gear", "gear": id, "tag": CARD_TAG_GEAR,
				"title": gdef["name"], "desc": Loc.t(gdef["desc"]), "color": gdef["color"]})
		added += 1
	pool.shuffle()
	return pool.slice(0, 3)


func choose_option(index: int) -> void:
	if state != State.CHOOSING or index < 0 or index >= current_options.size():
		return
	var opt: Dictionary = current_options[index]
	current_options = []
	Sfx.play("card")
	hud.hide_choices()
	if opt["type"] == "tile":
		state = State.PLACING
		board.begin_placement(opt["kind"])
		hud.show_banner(Loc.t("PLACE %s") % opt["title"], opt["color"])
	elif opt["type"] == "gear":
		state = State.EQUIPPING
		board.begin_equip(opt["gear"])
		hud.show_banner(Loc.t("EQUIP %s - CLICK A TILE") % opt["title"], opt["color"])
	else:
		_apply_boost(opt["id"])
		_start_intermission()


## 강화 카드 수치 (퍼센트 또는 체력). 웨이브가 오를수록 커진다.
func boost_value(id: String) -> float:
	return BOOST_BASE[id] + BOOST_PER_WAVE[id] * maxi(wave - 1, 0)


func _apply_boost(id: String) -> void:
	var v := boost_value(id)
	match id:
		"damage":
			board.damage_mult += v / 100.0
		"rate":
			board.rate_mult += v / 100.0
		"repair":
			var core := board.core_tile()
			core.max_hp += v
			for t in board.tiles.values():
				if t != core:
					t.max_hp *= 1.0 + REINFORCE_TILE_HP
				t.hp = t.max_hp
		"resonance":
			resonance += v / 100.0


func _on_placement_finished(_tile: HexTile) -> void:
	Sfx.play("place")
	if state == State.PLACING:
		_start_intermission()


func _on_equip_finished(_tile: HexTile) -> void:
	Sfx.play("equip")
	if state == State.EQUIPPING:
		_start_intermission()


func _start_intermission() -> void:
	state = State.INTERMISSION
	_intermission = INTERMISSION
	hud.show_banner(Loc.t("GET READY"), Hud.NEON_CYAN)


## earned: 결과창의 GOLD EARNED에 셀지 (시작 돈은 안 셈)
func add_money(amount: int, earned := true) -> void:
	money += amount
	if earned and amount > 0:
		money_earned += amount
	hud.set_money(money)
	money_changed.emit(money)


func alive_enemies() -> int:
	return _alive


func toggle_pause() -> void:
	if is_over or not started or _victory_open:
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	hud.set_paused(tree.paused)
	if tree.paused:
		hud.show_overlay(Loc.t("PAUSED"), Hud.resume_hint(), Hud.NEON_CYAN, board.stats)
	else:
		hud.hide_overlay()


func toggle_speed() -> void:
	speed_multiplier = 2.0 if speed_multiplier == 1.0 else 1.0
	Engine.time_scale = BASE_TIME_SCALE * speed_multiplier
	hud.set_speed(speed_multiplier)


## 웨이브 번호에 따른 적 수/능력치. 밸런스 조정은 여기서.
func wave_enemy_count(n: int) -> int:
	return mini(3 + n * 2, 45)


## 적 체력: LATE_FROM 웨이브까지는 HP_GROWTH배씩, 그 뒤로는 HP_LATE_GROWTH배씩 늘어난다.
const HP_GROWTH := 1.23
const HP_LATE_GROWTH := 1.17
const LATE_FROM := 15
## 처치 보상: 적 체력^REWARD_POWER × REWARD_SCALE. 적이 강해질수록 보상도 같이 커진다.
const REWARD_SCALE := 0.3
const REWARD_POWER := 0.38


func wave_enemy_hp(n: int) -> float:
	var early := mini(n, LATE_FROM) - 1
	var late := maxi(n - LATE_FROM, 0)
	return 6.0 * pow(HP_GROWTH, early) * pow(HP_LATE_GROWTH, late) + n


## 일반 적(보스와 OVERLORD 부하 제외)만 더 단단하게: NORMAL_HP_FROM 웨이브 뒤로 웨이브마다
## NORMAL_HP_STEP씩 더해져 FINAL_WAVE에서 최대가 된다 (무한 모드에서는 그 값 유지).
## 보스 체력은 wave_enemy_hp 그대로라 보스 난이도는 바뀌지 않는다. 보상도 wave_enemy_hp 기준.
const NORMAL_HP_FROM := 10
const NORMAL_HP_STEP := 0.035


func normal_hp_mult(n: int) -> float:
	var steps := clampi(n, NORMAL_HP_FROM, EnemyDefs.FINAL_WAVE) - NORMAL_HP_FROM
	return 1.0 + NORMAL_HP_STEP * steps


func wave_enemy_reward(n: int) -> float:
	return maxf(1.0, REWARD_SCALE * pow(wave_enemy_hp(n), REWARD_POWER))


func _begin_wave() -> void:
	state = State.WAVE
	wave += 1
	move_charges = MOVES_PER_WAVE
	_update_actions()
	board.stats.current_wave = wave
	_to_spawn = wave_enemy_count(wave)
	_boss_pending = EnemyDefs.is_boss_wave(wave)
	_spawn_interval = maxf(0.3, 1.2 - wave * 0.05)
	_spawn_timer = 0.0
	hud.set_wave(wave, endless)
	Sfx.play("wave")
	Sfx.music("boss" if _boss_pending else "battle")
	if _boss_pending and wave == EnemyDefs.FINAL_WAVE:
		hud.show_banner(Loc.t("FINAL WAVE  -  OVERLORD"), EnemyDefs.get_def("overlord")["color"])
	elif _boss_pending:
		hud.show_banner(Loc.t("WAVE %d  -  BOSS") % wave, EnemyDefs.get_def("boss")["color"])
	else:
		hud.show_banner(Loc.t("WAVE %d") % wave, Hud.NEON_CYAN)
	get_tree().create_timer(1.2, false).timeout.connect(_hide_wave_message.bind(wave))
	wave_started.emit(wave)


func _hide_wave_message(for_wave: int) -> void:
	if for_wave == wave and state == State.WAVE and not is_over and not get_tree().paused:
		hud.hide_banner()


func _on_wave_cleared() -> void:
	wave_cleared.emit(wave)
	Sfx.play("wave_clear")
	# RESONANCE는 더하기로 쌓인다 (곱하면 후반에 끝없이 불어남)
	if resonance > 0.0:
		board.damage_mult += resonance
	var interest := 0
	for tile in board.tiles.values():
		if tile.income > 0:
			interest += bank_interest(tile)
			add_money(tile.income)
	add_money(interest)
	hud.hide_banner()
	if board.moving:
		board.cancel_move()
		_update_actions()
	state = State.CHOOSING
	current_options = make_options()
	hud.show_choices(current_options)
	choices_offered.emit(current_options)


## BANK 한 칸이 이번 웨이브에 줄 이자 (지금 가진 돈 기준).
func bank_interest(tile: HexTile) -> int:
	var rate := BANK_INTEREST + BANK_INTEREST_STEP * (tile.level - 1)
	return mini(floori(money * rate), tile.income * BANK_INTEREST_CAP)


## kind 종류의 적을 전역 위치 pos에 만든다. 능력치 = 웨이브 기본값 × 종류 배율.
## normal이면(보스도 OVERLORD 부하도 아니면) normal_hp_mult를 더 곱한다.
func spawn_enemy(kind: String, pos: Vector2, normal := true) -> Enemy:
	var enemy := Enemy.new()
	enemy.board = board
	var base_hp := wave_enemy_hp(wave)
	if normal and not EnemyDefs.get_def(kind).get("is_boss", false):
		base_hp *= normal_hp_mult(wave)
	enemy.setup(kind, base_hp, minf(55.0 + wave * 2.5, 140.0),
			wave_enemy_reward(wave), 10.0 + wave * 0.5)
	enemy.died.connect(_on_enemy_died)
	if enemy.summon_kind != "":
		enemy.summoned.connect(_on_enemy_summoned)
	board.enemy_layer.add_child(enemy)
	enemy.global_position = pos
	_alive += 1
	return enemy


## 카메라에 보이는 영역의 테두리 바로 바깥, 사방 중 임의의 한 점.
func _random_spawn_point() -> Vector2:
	var half := get_viewport_rect().size / camera.zoom / 2.0 + Vector2.ONE * SPAWN_MARGIN
	var center := camera.get_screen_center_position()
	var perimeter := 4.0 * (half.x + half.y)
	var t := randf() * perimeter
	var p: Vector2
	if t < 2.0 * half.x:
		p = Vector2(-half.x + t, -half.y)
	elif t < 2.0 * half.x + 2.0 * half.y:
		p = Vector2(half.x, -half.y + (t - 2.0 * half.x))
	elif t < 4.0 * half.x + 2.0 * half.y:
		p = Vector2(half.x - (t - 2.0 * half.x - 2.0 * half.y), half.y)
	else:
		p = Vector2(-half.x, half.y - (t - 4.0 * half.x - 2.0 * half.y))
	return center + p


func _on_enemy_died(enemy: Enemy, reward: int) -> void:
	_alive -= 1
	if enemy.killed:
		kills[enemy.kind] = kills.get(enemy.kind, 0) + 1
		Sfx.play("boss_kill" if enemy.is_boss else "kill")
	if reward > 0:
		add_money(reward)
	# SPLITTER: 처치되면 작은 적으로 갈라진다
	if enemy.killed and enemy.splits_into != "" and not is_over:
		for i in enemy.split_count:
			var offset := Vector2.from_angle(TAU * i / enemy.split_count) * 18.0
			var child := spawn_enemy(enemy.splits_into, enemy.global_position + offset)
			child.inherit_slow(enemy)


## 웨이브 마지막 보스. FINAL_WAVE의 OVERLORD는 화면 위에 체력 막대를 띄운다.
func _spawn_boss() -> Enemy:
	var kind := EnemyDefs.boss_kind(wave)
	var boss := spawn_enemy(kind, _random_spawn_point())
	Sfx.play("overlord" if kind == "overlord" else "boss_appear")
	if kind == "overlord":
		final_boss = boss
		hud.show_boss_bar(EnemyDefs.get_def(kind)["name"], boss.color)
	return boss


## OVERLORD가 부하를 부른다: 주변에 둥글게.
func _on_enemy_summoned(enemy: Enemy, kind: String, count: int) -> void:
	if is_over:
		return
	for i in count:
		var offset := Vector2.from_angle(TAU * (i + randf() * 0.5) / count) * (enemy.radius + 30.0)
		spawn_enemy(kind, enemy.global_position + offset, false)


## FINAL_WAVE 클리어: SHARD를 바로 받고(앱을 꺼도 남음) 클리어 화면.
## 화면에서 ENDLESS를 고르면 continue_endless, END RUN이면 end_run_after_victory.
func _on_victory() -> void:
	state = State.CHOOSING
	if board.moving:
		board.cancel_move()
	_victory_open = true
	victory_shards = Meta.finish_victory()
	hud.hide_banner()
	hud.hide_boss_bar()
	hud.show_tile_panel(null, 0)
	get_tree().paused = true
	Sfx.music("")
	Sfx.play("victory")
	hud.show_victory(wave, victory_shards, Meta.clears)
	victory.emit()


## 클리어 뒤 계속: 무한 모드. 평소처럼 카드 3장부터.
func continue_endless() -> void:
	if not _victory_open:
		return
	_victory_open = false
	endless = true
	hud.hide_victory()
	get_tree().paused = false
	hud.set_wave(wave, endless)
	Sfx.music("battle")
	_on_wave_cleared()


## 클리어 뒤 그만두기: 시작 화면으로 (SHARD는 이미 받음).
func end_run_after_victory() -> void:
	if not _victory_open:
		return
	_victory_open = false
	is_over = true
	hud.hide_victory()
	hud.show_tile_panel(null, 0)
	_show_results()
	game_over.emit()


func _on_core_destroyed() -> void:
	if is_over:
		return
	is_over = true
	hud.set_core(0, board.core_tile().max_hp)
	hud.hide_banner()
	hud.hide_choices()
	hud.show_tile_panel(null, 0)
	hud.hide_boss_bar()
	if endless:
		# 클리어 때 받은 몫은 빼고 그 뒤 웨이브만큼 더
		Meta.finish_run(wave, Meta.shards_for_run(EnemyDefs.FINAL_WAVE + 1), victory_shards)
	else:
		Meta.finish_run(wave)
	get_tree().paused = true
	Sfx.music("")
	Sfx.play("gameover")
	_show_results()
	game_over.emit()


## 결과창에 넘길 이번 판 기록.
func run_results() -> Dictionary:
	return {
		"victory": Meta.last_run_victory,
		"endless": endless,
		"wave": wave,
		"best_wave": Meta.best_wave,
		"new_best": wave > best_at_start,
		"kills": kills,
		"time": run_time,
		"gold": money_earned,
		"shards": Meta.last_run_shards,
		"stats": board.stats,
	}


## 판이 끝나면 결과창 -> CONTINUE로 시작 화면 (RETRY/R은 바로 새 판).
func _show_results() -> void:
	results.show_results(run_results())


func _on_results_continue() -> void:
	if not results.is_open():
		return
	results.hide_results()
	shop.open()


## R 키: 판이 끝났으면 시작 화면을 건너뛰고 바로 새 판.
func _on_restart_pressed() -> void:
	if not is_over:
		return
	_skip_hub_once = true
	_restart()


func _restart() -> void:
	Engine.time_scale = BASE_TIME_SCALE
	get_tree().paused = false
	get_tree().reload_current_scene()
