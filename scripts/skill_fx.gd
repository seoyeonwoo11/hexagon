class_name SkillFx
extends Node2D
## 코어 스킬 연출: 코어에서 radius까지 퍼지는 굵은 고리 두 겹 + 잠깐 번쩍이는 원.

const TIME := 0.7

var color := Color.WHITE
var radius := 600.0
var _t := 0.0


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	if _t >= TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / TIME
	var ease := 1.0 - pow(1.0 - k, 3.0)
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, radius * ease, Color(color, 0.08 * a))
	NeonDraw.polyline(self, _ring(radius * ease), color, a, 4.0)
	NeonDraw.polyline(self, _ring(radius * ease * 0.7), color, a * 0.5, 2.0)


func _ring(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 65:
		pts.append(Vector2.from_angle(TAU * i / 64.0) * r)
	return pts
