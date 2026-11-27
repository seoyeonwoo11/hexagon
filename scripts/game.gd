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
## (Meta.finish_run), Shop에서 영구 강화와 타일 구매를 한 뒤 START로 새 판을 시작한다.

signal money_changed(money: int)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal choices_offered(options: Array)
signal game_over

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
	{"id": "repair", "title": "REINFORCE", "desc": "Core +{v} max HP and repairs half its HP.",
			"color": Color(0.0, 0.95, 1.0)},
	{"id": "resonance", "title": "RESONANCE",
			"desc": "From now on, all tiles gain +{v}% damage after every wave.",
			"color": Color(1.0, 0.55, 0.95)},
]
## 강화 카드 효과: 기본값 + 웨이브당 증가량 (후반 카드일수록 강하다)
const BOOST_BASE := {"damage": 10.0, "rate": 8.0, "repair": 15.0, "resonance": 2.0}
const BOOST_PER_WAVE := {"damage": 0.3, "rate": 0.2, "repair": 2.0, "resonance": 0.0}
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
var shop: Shop

## false면 시작 화면 없이 바로 판을 시작한다 (테스트, 자동 플레이용).
static var hub_enabled := true
## 시작 화면에서 START를 눌러 씬을 다시 불러왔을 때 한 번 시작 화면을 건너뛴다.
static var _skip_hub_once := false


func _ready() -> void:
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
	hud.set_money(money)
	hud.set_wave(wave)
	hud.set_speed(speed_multiplier)
	hud.set_paused(false)
	Meta.ensure_loaded()
	shop = Shop.new()
	shop.start_pressed.connect(_on_shop_start)
	add_child(shop)
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
	board.damage_mult *= Meta.damage_mult()
	board.rate_mult *= Meta.rate_mult()
	board.tile_hp_mult = Meta.tile_hp_mult()
	var core := board.core_tile()
	core.max_hp = (core.max_hp + Meta.core_hp_bonus()) * Meta.tile_hp_mult()
	core.hp = core.max_hp
	add_money(Meta.start_money())
	hud.show_banner("READY", Hud.NEON_CYAN)


func _on_shop_start() -> void:
	if not started:
		start_run()
	else:
		_skip_hub_once = true
		_restart()


func _process(delta: float) -> void:
	if is_over or not started:
		return
	var core := board.core_tile()
	if core != null:
		hud.set_core(core.hp, core.max_hp)
	hud.show_tile_panel(board.selected_tile, money)

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
						spawn_enemy("boss", _random_spawn_point())
						_boss_pending = false
					_spawn_timer = _spawn_interval
			elif _alive == 0:
				_on_wave_cleared()


## 선택된 타일을 강화한다. 돈이 모자라면 false.
func upgrade_selected() -> bool:
	return try_upgrade(board.selected_tile)


func try_upgrade(tile: HexTile) -> bool:
	if tile == null or not is_instance_valid(tile) or is_over:
		return false
	var cost := tile.upgrade_cost()
	if money < cost:
		return false
	add_money(-cost)
	tile.upgrade()
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
					"title": def["name"], "desc": def["desc"], "color": def["color"]})
	for boost in BOOSTS:
		var opt: Dictionary = boost.duplicate()
		opt["desc"] = (opt["desc"] as String).replace("{v}", "%d" % roundi(boost_value(opt["id"])))
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
				"title": gdef["name"], "desc": gdef["desc"], "color": gdef["color"]})
		added += 1
	pool.shuffle()
	return pool.slice(0, 3)


func choose_option(index: int) -> void:
	if state != State.CHOOSING or index < 0 or index >= current_options.size():
		return
	var opt: Dictionary = current_options[index]
	current_options = []
	hud.hide_choices()
	if opt["type"] == "tile":
		state = State.PLACING
		board.begin_placement(opt["kind"])
		hud.show_banner("PLACE %s" % opt["title"], opt["color"])
	elif opt["type"] == "gear":
		state = State.EQUIPPING
		board.begin_equip(opt["gear"])
		hud.show_banner("EQUIP %s - CLICK A TILE" % opt["title"], opt["color"])
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
			board.damage_mult *= 1.0 + v / 100.0
		"rate":
			board.rate_mult *= 1.0 + v / 100.0
		"repair":
			var core := board.core_tile()
			core.max_hp += v
			core.hp = minf(core.hp + core.max_hp * 0.5, core.max_hp)
		"resonance":
			resonance += v / 100.0


func _on_placement_finished(_tile: HexTile) -> void:
	if state == State.PLACING:
		_start_intermission()


func _on_equip_finished(_tile: HexTile) -> void:
	if state == State.EQUIPPING:
		_start_intermission()


func _start_intermission() -> void:
	state = State.INTERMISSION
	_intermission = INTERMISSION
	hud.show_banner("GET READY", Hud.NEON_CYAN)


func add_money(amount: int) -> void:
	money += amount
	hud.set_money(money)
	money_changed.emit(money)


func alive_enemies() -> int:
	return _alive


func toggle_pause() -> void:
	if is_over or not started:
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	hud.set_paused(tree.paused)
	if tree.paused:
		hud.show_overlay("PAUSED", "SPACE TO RESUME", Hud.NEON_CYAN)
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


func wave_enemy_reward(n: int) -> float:
	return maxf(1.0, REWARD_SCALE * pow(wave_enemy_hp(n), REWARD_POWER))


func _begin_wave() -> void:
	state = State.WAVE
	wave += 1
	_to_spawn = wave_enemy_count(wave)
	_boss_pending = EnemyDefs.is_boss_wave(wave)
	_spawn_interval = maxf(0.3, 1.2 - wave * 0.05)
	_spawn_timer = 0.0
	hud.set_wave(wave)
	if _boss_pending:
		hud.show_banner("WAVE %d  -  BOSS" % wave, EnemyDefs.get_def("boss")["color"])
	else:
		hud.show_banner("WAVE %d" % wave, Hud.NEON_CYAN)
	get_tree().create_timer(1.2, false).timeout.connect(_hide_wave_message.bind(wave))
	wave_started.emit(wave)


func _hide_wave_message(for_wave: int) -> void:
	if for_wave == wave and state == State.WAVE and not is_over and not get_tree().paused:
		hud.hide_banner()


func _on_wave_cleared() -> void:
	wave_cleared.emit(wave)
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
	state = State.CHOOSING
	current_options = make_options()
	hud.show_choices(current_options)
	choices_offered.emit(current_options)


## BANK 한 칸이 이번 웨이브에 줄 이자 (지금 가진 돈 기준).
func bank_interest(tile: HexTile) -> int:
	var rate := BANK_INTEREST + BANK_INTEREST_STEP * (tile.level - 1)
	return mini(floori(money * rate), tile.income * BANK_INTEREST_CAP)


## kind 종류의 적을 전역 위치 pos에 만든다. 능력치 = 웨이브 기본값 × 종류 배율.
func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.board = board
	enemy.setup(kind, wave_enemy_hp(wave), minf(55.0 + wave * 2.5, 140.0),
			wave_enemy_reward(wave), 10.0 + wave * 0.5)
	enemy.died.connect(_on_enemy_died)
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
	if reward > 0:
		add_money(reward)
	# SPLITTER: 처치되면 작은 적으로 갈라진다
	if enemy.killed and enemy.splits_into != "" and not is_over:
		for i in enemy.split_count:
			var offset := Vector2.from_angle(TAU * i / enemy.split_count) * 18.0
			var child := spawn_enemy(enemy.splits_into, enemy.global_position + offset)
			child.inherit_slow(enemy)


func _on_core_destroyed() -> void:
	if is_over:
		return
	is_over = true
	hud.set_core(0, board.core_tile().max_hp)
	hud.hide_banner()
	hud.hide_choices()
	hud.show_tile_panel(null, 0)
	Meta.finish_run(wave)
	get_tree().paused = true
	shop.open()
	game_over.emit()


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
