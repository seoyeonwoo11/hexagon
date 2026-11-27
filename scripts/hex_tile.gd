class_name HexTile
extends Node2D
## 보드 위에 놓인 육각형 타일 하나.
## 기본 기능: 사거리 안의 가장 가까운 적을 자동으로 레이저 공격한다.
## 체력이 0이 되면 destroyed 신호를 보낸다 (보드가 제거/게임오버 처리).

signal destroyed(tile: HexTile)

const SHOT_TIME := 0.08
const HIT_FLASH_TIME := 0.2

@export var color := Color(0.0, 0.95, 1.0)
@export var max_hp := 60.0
@export var attack_range := 260.0
@export var damage := 5.0
@export var fire_interval := 0.4

var coord := Vector2i.ZERO
var size := 48.0
var hp := 60.0

var _time := 0.0
var _cooldown := 0.0
var _shot_target := Vector2.ZERO
var _shot_time := 0.0
var _hit_flash := 0.0
var _destroyed := false


func _ready() -> void:
	hp = max_hp


func _process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	_shot_time = maxf(_shot_time - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _cooldown <= 0.0:
		var enemy := find_target()
		if enemy != null:
			_shot_target = to_local(enemy.global_position)
			_shot_time = SHOT_TIME
			_cooldown = fire_interval
			enemy.take_damage(damage)
	queue_redraw()


## 사거리 안에서 가장 가까운 살아있는 적.
func find_target() -> Enemy:
	var best: Enemy = null
	var best_dist := attack_range
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= best_dist:
			best = enemy
			best_dist = d
	return best


func take_damage(amount: float) -> void:
	if _destroyed:
		return
	hp -= amount
	_hit_flash = HIT_FLASH_TIME
	if hp <= 0.0:
		hp = 0.0
		_destroyed = true
		destroyed.emit(self)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.5)
	var c := color.lerp(Color(1.0, 0.15, 0.2), _hit_flash / HIT_FLASH_TIME)
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.9, c, pulse, 3.0, 0.10)
	# 가운데 작은 육각형: 타일 "코어" 표시
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.3, c, pulse * 0.8, 2.0)
	# 체력이 깎였으면 남은 체력을 원호로 표시
	if hp < max_hp:
		var frac := hp / max_hp
		draw_arc(Vector2.ZERO, size * 0.55, -PI / 2.0, -PI / 2.0 + TAU * frac, 32,
				Color(c, 0.8), 2.0, true)
	if _shot_time > 0.0:
		NeonDraw.polyline(self, PackedVector2Array([Vector2.ZERO, _shot_target]), c,
				_shot_time / SHOT_TIME, 2.0)
