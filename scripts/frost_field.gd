class_name FrostField
extends Node2D
## FROST 타일의 감속 범위. 타일과 이웃 타일 뒤에 깔리도록 z_index를 낮춘다.
## 옅게 채운 원, 또렷한 테두리, 천천히 도는 눈금, 공격 때마다 바깥으로 퍼지는 냉기 파동.

const TICKS := 18

var tile: HexTile


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	if tile == null:
		return
	var c := tile.color
	var r := tile.effective_range()
	var t := tile._time
	# 범위 안을 옅게 채움 (가장자리로 갈수록 조금 진하게)
	draw_circle(Vector2.ZERO, r, Color(c, 0.05))
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 96, Color(c, 0.05), r * 0.14, true)
	# 테두리: 넓고 흐린 빛 + 얇고 밝은 선
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, Color(c, 0.12), 8.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 128, Color(c, 0.6), 1.8, true)
	# 테두리 안쪽으로 천천히 도는 눈금
	for i in TICKS:
		var a := t * 0.25 + TAU * i / TICKS
		var d := Vector2(cos(a), sin(a))
		draw_line(d * (r - 10.0), d * (r - 2.0), Color(c, 0.55), 1.5, true)
	# 냉기 파동: 공격 주기에 맞춰 타일에서 테두리까지 퍼짐
	var iv := tile.interval()
	if iv > 0.0:
		var phase := clampf(1.0 - tile._cooldown / iv, 0.0, 1.0)
		var pr := lerpf(tile.size * 0.8, r, phase)
		draw_arc(Vector2.ZERO, pr, 0.0, TAU, 96, Color(c, 0.35 * (1.0 - phase)), 3.0, true)
