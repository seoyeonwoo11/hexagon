class_name OrbitRing
extends Node2D
## ORBIT 타일의 도는 구체를 그린다. 이웃 타일과 적 위에 보이도록 z_index를 높인다.
## 움직임과 피해 계산은 HexTile이 하고, 여기서는 그리기만 한다.
## 성능: 구체는 각도 0 기준으로 한 번만 그리고, 회전은 노드 rotation으로 한다 (HexTile이 맞춤).

const TRAIL_STEPS := 6
const TRAIL_ARC := 0.5

var tile: HexTile
var _drawn := []


func _ready() -> void:
	z_index = 2


## 구체 수나 반지름이 바뀌었을 때만 다시 그린다.
func sync() -> void:
	var state := [tile.orb_count(), tile.effective_range(), tile.color]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	# 그리기 호출 1번으로 (NeonDraw 묶어 그리기)
	NeonDraw.begin(self)
	_draw_parts()
	NeonDraw.flush()


func _draw_parts() -> void:
	if tile == null:
		return
	var c := tile.color
	var r := tile.effective_range()
	# 희미한 궤도선
	NeonDraw.arc(self, Vector2.ZERO, r, 0.0, TAU, 96, Color(c, 0.10), 1.0)
	var n := tile.orb_count()
	for i in n:
		var a := TAU * i / n
		# 꼬리: 지나온 자리에 점점 옅어지는 원호
		var trail := PackedVector2Array()
		for s in TRAIL_STEPS + 1:
			var ta := a - TRAIL_ARC * s / TRAIL_STEPS
			trail.append(Vector2(cos(ta), sin(ta)) * r)
		NeonDraw.polyline(self, trail, c, 0.45, 2.0)
		var p := Vector2(cos(a), sin(a)) * r
		var orb_r := HexTile.ORB_RADIUS
		NeonDraw.circle(self, p, orb_r * 1.9, Color(c, 0.10))
		NeonDraw.circle(self, p, orb_r * 1.35, Color(c, 0.22))
		NeonDraw.circle(self, p, orb_r, Color(c, 0.85))
		NeonDraw.circle(self, p, orb_r * 0.5, Color(1, 1, 1, 0.9))
