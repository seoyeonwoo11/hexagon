class_name Explosion
extends Node2D
## DETONATOR 장비의 폭발 효과 (그림만, 피해는 타일이 처리).

const DURATION := 0.3

var color := Color(1.0, 0.75, 0.3)
var radius := 100.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var r := radius * (0.3 + 0.7 * k)
	draw_circle(Vector2.ZERO, r, Color(color, 0.18 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 1.0 - k), 3.0, true)
	draw_arc(Vector2.ZERO, r + 6.0, 0.0, TAU, 48, Color(color, 0.3 * (1.0 - k)), 8.0, true)
