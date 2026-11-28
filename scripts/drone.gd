class_name Drone
extends Node2D
## DRONE HIVE 타일이 띄우는 작은 드론. 벌집 주위를 돌다가 사거리 안 적을 쫓아가 들이받는다.
## 피해와 공격 간격은 벌집 타일 것을 쓴다 (장비 효과, BOOSTER도 그대로 적용).
## 전역 좌표로 움직이므로 보드의 enemy_layer에 둔다. 벌집이 사라지면 같이 사라진다.

const SPEED := 330.0
const TURN := 7.0
const IDLE_RADIUS := 72.0
const IDLE_SPIN := 1.6
const SIZE := 11.0
const FLASH_TIME := 0.15
## 맞힌 뒤 튕겨 나오는 속도 비율
const BOUNCE := 0.3

var hive: HexTile
var index := 0
var target: Enemy

var _cd := 0.0
var _vel := Vector2.ZERO
var _flash := 0.0
var _drawn_flash := false


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	if not is_instance_valid(hive) or hive.is_queued_for_deletion():
		queue_free()
		return
	_cd -= delta
	if not _target_ok(target):
		target = hive.drone_pick_target(self)
	var goal: Vector2
	if target != null:
		goal = target.global_position
	else:
		var n := maxi(hive.drone_count(), 1)
		var a := hive._time * IDLE_SPIN + TAU * index / n
		goal = hive.global_position + Vector2.from_angle(a) * IDLE_RADIUS
	var to_goal := goal - global_position
	_vel = _vel.lerp(to_goal.normalized() * SPEED, minf(1.0, delta * TURN))
	global_position += _vel * delta
	if _vel.length_squared() > 1.0:
		rotation = _vel.angle()
	if target != null and _cd <= 0.0 \
			and to_goal.length() <= SIZE + target.radius:
		_cd = hive.interval()
		_flash = FLASH_TIME
		Sfx.play("drone")
		hive.apply_hit(target, hive.damage())
		# 맞힌 뒤 살짝 튕겨 나온다 (작게 튕겨야 빨리 돌아와 다시 박는다)
		_vel = -_vel * BOUNCE
	_flash = maxf(_flash - delta, 0.0)
	if (_flash > 0.0) != _drawn_flash:
		_drawn_flash = _flash > 0.0
		queue_redraw()


## 벌집 사거리 안에 있는 살아있는 적인지. (이미 지워진 적이 들어올 수 있어 타입을 두지 않음)
func _target_ok(e: Variant) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	var enemy := e as Enemy
	return enemy.is_alive() \
			and hive.global_position.distance_to(enemy.global_position) <= hive.effective_range()


func _draw() -> void:
	# 그리기 호출 1번으로 (NeonDraw 묶어 그리기)
	NeonDraw.begin(self)
	_draw_parts()
	NeonDraw.flush()


func _draw_parts() -> void:
	var c := Color.WHITE if _drawn_flash else hive.color if is_instance_valid(hive) else Color.WHITE
	# 앞을 향한 작은 화살촉 + 꼬리 불빛
	var pts := PackedVector2Array([Vector2(-SIZE * 0.8, -SIZE * 0.7), Vector2(SIZE, 0),
			Vector2(-SIZE * 0.8, SIZE * 0.7), Vector2(-SIZE * 0.35, 0), Vector2(-SIZE * 0.8, -SIZE * 0.7)])
	NeonDraw.polyline(self, pts, c, 1.0, 2.0)
	NeonDraw.circle(self, Vector2(-SIZE * 0.9, 0), 2.5, Color(c, 0.7))
