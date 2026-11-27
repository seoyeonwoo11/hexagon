class_name OrbitRing
extends Node2D
## ORBIT 타일의 도는 구체를 그린다. 이웃 타일과 적 위에 보이도록 z_index를 높인다.
## 움직임과 피해 계산은 HexTile이 하고, 여기서는 그리기만 한다.

const TRAIL_STEPS := 6
const TRAIL_ARC := 0.5

var tile: HexTile


func _ready() -> void:
	z_index = 2


func _draw() -> void:
	if tile == null:
		return
	var c := tile.color
	var r := tile.effective_range()
	# 희미한 궤도선
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(c, 0.10), 1.0, true)
	var n := tile.orb_count()
	for i in n:
		var a := tile.orbit_angle + TAU * i / n
		# 꼬리: 지나온 자리에 점점 옅어지는 원호
		var trail := PackedVector2Array()
		for s in TRAIL_STEPS + 1:
			var ta := a - TRAIL_ARC * s / TRAIL_STEPS
			trail.append(Vector2(cos(ta), sin(ta)) * r)
		NeonDraw.polyline(self, trail, c, 0.45, 2.0)
		var p := Vector2(cos(a), sin(a)) * r
		var orb_r := HexTile.ORB_RADIUS
		draw_circle(p, orb_r * 1.9, Color(c, 0.10))
		draw_circle(p, orb_r * 1.35, Color(c, 0.22))
		draw_circle(p, orb_r, Color(c, 0.85))
		draw_circle(p, orb_r * 0.5, Color(1, 1, 1, 0.9))
