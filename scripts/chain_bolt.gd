class_name ChainBolt
extends Node2D
## SPARK 타일이 쏘는 번개 투사체.
## 첫 적에게 날아가 맞히면, bounce_range 안에서 아직 안 맞힌 가장 가까운 적에게 튕겨 간다.
## bounces번 튕기거나 다음 적이 없으면 사라진다. (전역 좌표로 움직이므로 보드의 enemy_layer에 둔다)

const TRAIL_FADE := 0.25

var color := Color(1.0, 0.85, 0.1)
var damage := 5.0
var bounces := 4
var bounce_range := 170.0
var speed := 1100.0

var _target: Enemy
var _hit: Array[Enemy] = []
## 지나온 지점들 (번개 꼬리). 각 항목: [위치, 남은 시간]
var _trail: Array = []
var _done := false


## from(전역)에서 출발해 first를 향해 날아간다.
func launch(from: Vector2, first: Enemy) -> void:
	global_position = from
	_target = first
	_trail.append([from, TRAIL_FADE])


func _process(delta: float) -> void:
	for p in _trail:
		p[1] -= delta
	_trail = _trail.filter(func(p: Array) -> bool: return p[1] > 0.0)
	if _done:
		if _trail.is_empty():
			queue_free()
		queue_redraw()
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_target = _next_target(global_position)
		if _target == null:
			_finish()
			return
	var to_target := _target.global_position - global_position
	var step := speed * delta
	if to_target.length() <= step:
		global_position = _target.global_position
		_hit_target()
	else:
		global_position += to_target.normalized() * step
	queue_redraw()


func _hit_target() -> void:
	var enemy := _target
	_hit.append(enemy)
	_trail.append([global_position, TRAIL_FADE])
	enemy.take_damage(damage)
	if _hit.size() > bounces:
		_finish()
		return
	_target = _next_target(global_position)
	if _target == null:
		_finish()


func _next_target(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_dist := bounce_range
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or _hit.has(enemy):
			continue
		var d := from.distance_to(enemy.global_position)
		if d <= best_dist:
			best = enemy
			best_dist = d
	return best


func _finish() -> void:
	_done = true
	_trail.append([global_position, TRAIL_FADE])


func hit_count() -> int:
	return _hit.size()


func _draw() -> void:
	# 지나온 지점들을 지그재그 번개로 잇는다 (로컬 좌표로 변환)
	var pts: Array = _trail.duplicate()
	if not _done:
		pts.append([global_position, TRAIL_FADE])
	for i in range(pts.size() - 1):
		var a: Vector2 = to_local(pts[i][0])
		var b: Vector2 = to_local(pts[i + 1][0])
		var alpha := clampf(float(pts[i + 1][1]) / TRAIL_FADE, 0.0, 1.0)
		NeonDraw.polyline(self, _zigzag(a, b), color, alpha, 2.0)
	if not _done:
		draw_circle(Vector2.ZERO, 5.0, color.lightened(0.5))


func _zigzag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var segments := maxi(2, int(a.distance_to(b) / 24.0))
	var normal := (b - a).orthogonal().normalized()
	for i in range(1, segments):
		var t := float(i) / segments
		pts.append(a.lerp(b, t) + normal * randf_range(-7.0, 7.0))
	pts.append(b)
	return pts
