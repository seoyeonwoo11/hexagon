class_name Game
extends Node2D
## 게임 진행: 돈, 웨이브, 적 생성, 웨이브 클리어 카드, 타일 강화, 일시정지/배속, 게임 오버.
##
## 상태 흐름:
##   INTERMISSION (잠깐 대기) -> WAVE (적 생성/전투) -> 모든 적 처치 ->
##   CHOOSING (카드 3장 중 선택) -> [타일 카드면 PLACING (칸 클릭해 배치),
##   장비 카드면 EQUIPPING (타일 클릭해 장착)] -> INTERMISSION ...

signal money_changed(money: int)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal choices_offered(options: Array)
signal game_over

enum State { INTERMISSION, WAVE, CHOOSING, PLACING, EQUIPPING }

const FIRST_WAVE_DELAY := 1.5
const INTERMISSION := 1.5
const SPAWN_MARGIN := 40.0
const CARD_TAG_TILE := "NEW TILE"
const CARD_TAG_BOOST := "BOOST"
const CARD_TAG_GEAR := "GEAR"
## 카드 풀에 한 번에 넣는 장비 수 (전체 장비 중 무작위)
const GEAR_CARDS_IN_POOL := 3

## 강화 카드 종류. 새 카드는 여기와 _apply_boost에 추가한다.
const BOOSTS := [
	{"id": "damage", "title": "OVERCHARGE", "desc": "All tiles deal +10% damage.",
			"color": Color(1.0, 0.35, 0.45)},
	{"id": "rate", "title": "OVERCLOCK", "desc": "All tiles attack 8% faster.",
			"color": Color(0.3, 1.0, 0.85)},
	{"id": "repair", "title": "REINFORCE", "desc": "Core +15 max HP and repairs half its HP.",
			"color": Color(0.0, 0.95, 1.0)},
]

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


func _ready() -> void:
	Engine.time_scale = 1.0
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
	hud.show_banner("READY", Hud.NEON_CYAN)


func _process(delta: float) -> void:
	if is_over:
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
		for kind in TileDefs.PLACEABLE:
			var def := TileDefs.get_def(kind)
			pool.append({"type": "tile", "kind": kind, "tag": CARD_TAG_TILE,
					"title": def["name"], "desc": def["desc"], "color": def["color"]})
	for boost in BOOSTS:
		var opt: Dictionary = boost.duplicate()
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


func _apply_boost(id: String) -> void:
	match id:
		"damage":
			board.damage_mult *= 1.1
		"rate":
			board.rate_mult *= 1.08
		"repair":
			var core := board.core_tile()
			core.max_hp += 15.0
			core.hp = minf(core.hp + core.max_hp * 0.5, core.max_hp)


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
	if is_over:
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
	Engine.time_scale = speed_multiplier
	hud.set_speed(speed_multiplier)


## 웨이브 번호에 따른 적 수/능력치. 밸런스 조정은 여기서.
func wave_enemy_count(n: int) -> int:
	return mini(3 + n * 2, 45)


func wave_enemy_hp(n: int) -> float:
	return 6.0 * pow(1.23, n - 1) + n


func wave_enemy_reward(n: int) -> int:
	return 1 + n / 8


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
	for tile in board.tiles.values():
		if tile.income > 0:
			add_money(tile.income)
	hud.hide_banner()
	state = State.CHOOSING
	current_options = make_options()
	hud.show_choices(current_options)
	choices_offered.emit(current_options)


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
			spawn_enemy(enemy.splits_into, enemy.global_position + offset)


func _on_core_destroyed() -> void:
	if is_over:
		return
	is_over = true
	hud.set_core(0, board.core_tile().max_hp)
	hud.hide_banner()
	hud.hide_choices()
	hud.show_tile_panel(null, 0)
	hud.show_overlay("GAME OVER", "REACHED WAVE %d  -  PRESS R TO RESTART" % wave, Hud.NEON_PINK)
	get_tree().paused = true
	game_over.emit()


func _on_restart_pressed() -> void:
	if not is_over:
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
