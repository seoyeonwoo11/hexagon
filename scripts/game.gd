class_name Game
extends Node2D
## 게임 진행: 돈, 웨이브, 적 생성, 일시정지/배속, 게임 오버.
## (3단계에서 웨이브 클리어 시 3택 옵션 화면이 _on_wave_cleared에 들어간다.)

signal money_changed(money: int)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal game_over

const FIRST_WAVE_DELAY := 1.5
const INTERMISSION := 3.0
const SPAWN_MARGIN := 40.0

@onready var board: Board = $Board
@onready var hud: Hud = $HUD
@onready var camera: Camera2D = $Camera2D

var money := 0
var wave := 0
var is_over := false
var speed_multiplier := 1.0

var _to_spawn := 0
var _spawn_timer := 0.0
var _spawn_interval := 1.0
var _alive := 0
var _intermission := FIRST_WAVE_DELAY


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	board.core_destroyed.connect(_on_core_destroyed)
	hud.pause_pressed.connect(toggle_pause)
	hud.speed_pressed.connect(toggle_speed)
	hud.restart_pressed.connect(_on_restart_pressed)
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

	if _intermission > 0.0:
		_intermission -= delta
		if _intermission <= 0.0:
			_begin_wave()
		return

	if _to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_to_spawn -= 1
			_spawn_timer = _spawn_interval
	elif _alive == 0:
		_on_wave_cleared()


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
	return 3 + n * 2


func _begin_wave() -> void:
	wave += 1
	_to_spawn = wave_enemy_count(wave)
	_spawn_interval = maxf(0.3, 1.2 - wave * 0.05)
	_spawn_timer = 0.0
	hud.set_wave(wave)
	hud.show_banner("WAVE %d" % wave, Hud.NEON_CYAN)
	get_tree().create_timer(1.2, false).timeout.connect(_hide_wave_message.bind(wave))
	wave_started.emit(wave)


func _hide_wave_message(for_wave: int) -> void:
	if for_wave == wave and not is_over and not get_tree().paused:
		hud.hide_banner()


func _on_wave_cleared() -> void:
	wave_cleared.emit(wave)
	hud.show_banner("WAVE CLEAR", Hud.NEON_YELLOW)
	_intermission = INTERMISSION


func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	enemy.board = board
	enemy.max_hp = 6.0 + wave * 2.0
	enemy.speed = 55.0 + wave * 3.0
	enemy.reward = 3 + wave / 2
	enemy.contact_damage = 10.0
	enemy.color = Color(1.0, 0.3, 0.35) if wave % 2 == 1 else Color(1.0, 0.55, 0.1)
	enemy.died.connect(_on_enemy_died)
	board.enemy_layer.add_child(enemy)
	enemy.global_position = _random_spawn_point()
	_alive += 1


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


func _on_enemy_died(_enemy: Enemy, reward: int) -> void:
	_alive -= 1
	if reward > 0:
		add_money(reward)


func _on_core_destroyed() -> void:
	if is_over:
		return
	is_over = true
	hud.set_core(0, board.core_tile().max_hp)
	hud.hide_banner()
	hud.show_overlay("GAME OVER", "REACHED WAVE %d  -  PRESS R TO RESTART" % wave, Hud.NEON_PINK)
	get_tree().paused = true
	game_over.emit()


func _on_restart_pressed() -> void:
	if not is_over:
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
