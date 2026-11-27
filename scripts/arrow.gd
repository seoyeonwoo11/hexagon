class_name Arrow
extends Node2D
## ARCHER 타일이 쏘는 화살. 빠르게 날아가 목표를 맞힌다. 목표가 먼저 죽으면 그대로 날아가다 사라진다.
## 전역 좌표로 움직이므로 보드의 enemy_layer에 둔다.

const SPEED := 1000.0
const LIFE := 1.2
const LENGTH := 22.0

var color := Color.WHITE
var damage := 1.0
var source: HexTile

var _target: Enemy
var _dir := Vector2.RIGHT
var _life := LIFE
var _straight := false
var _done := false


func launch(from: Vector2, target: Enemy) -> void:
	global_position = from
	_target = target
	_dir = from.direction_to(target.global_position)
	rotation = _dir.angle()


## PRISM 굴절 화살: 목표 없이 dir 방향으로 곧게 날아가다 처음 닿은 적을 맞힌다. reach 거리까지.
func launch_straight(from: Vector2, dir: Vector2, reach: float) -> void:
	global_position = from
	_target = null
	_straight = true
	_dir = dir.normalized()
	rotation = _dir.angle()
	_life = reach / SPEED


func _process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var step := SPEED * delta
	if _straight:
		global_position += _dir * step
		for node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var e := node as Enemy
			if e != null and e.is_alive() \
					and global_position.distance_to(e.global_position) <= e.radius + 6.0:
				if is_instance_valid(source):
					source.apply_hit(e, damage)
				_finish()
				return
		return
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		var to_target := _target.global_position - global_position
		if to_target.length() <= step + _target.radius:
			if is_instance_valid(source):
				source.apply_hit(_target, damage)
			_finish()
			return
		_dir = to_target.normalized()
		rotation = _dir.angle()
	global_position += _dir * step


## 한 번만 맞히고 사라진다.
func _finish() -> void:
	_done = true
	queue_free()


func _draw() -> void:
	NeonDraw.polyline(self, PackedVector2Array([Vector2(-LENGTH, 0), Vector2.ZERO]), color, 0.9, 2.0)
	NeonDraw.polyline(self, PackedVector2Array([Vector2(-7, -5), Vector2.ZERO, Vector2(-7, 5)]),
			color, 1.0, 2.0)
