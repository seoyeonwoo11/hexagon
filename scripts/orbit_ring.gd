class_name OrbitRing
extends Node2D
## ORBIT 타일의 도는 구체를 그린다. 이웃 타일과 적 위에 보이도록 z_index를 높인다.
## 움직임과 피해 계산은 HexTile이 하고, 여기서는 그리기만 한다.
## 성능: 구체는 각도 0 기준으로 한 번만 그리고, 회전은 노드 rotation으로 한다 (HexTile이 맞춤).

const TRAIL_STEPS := 12
const TRAIL_ARC := 0.75

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
		var orb_r := HexTile.ORB_RADIUS
		# 꼬리: 지나온 자리에 뒤로 갈수록 가늘고 옅어지는 원호 조각들
		for s in TRAIL_STEPS:
			var k := float(s) / TRAIL_STEPS
			var t0 := a - TRAIL_ARC * k
			var t1 := a - TRAIL_ARC * (k + 1.0 / TRAIL_STEPS)
			var seg := PackedVector2Array([Vector2.from_angle(t0) * r, Vector2.from_angle(t1) * r])
			NeonDraw.line(self, seg, Color(c, 0.35 * (1.0 - k)), orb_r * 1.1 * (1.0 - k * 0.8))
		var p := Vector2(cos(a), sin(a)) * r
		# 큰 구체: 옅은 빛 번짐 2겹 + 속이 비치는 몸통 + 밝은 테두리 고리 + 가운데 육각형 핵
		NeonDraw.circle(self, p, orb_r * 1.6, Color(c, 0.08))
		NeonDraw.circle(self, p, orb_r * 1.25, Color(c, 0.16))
		NeonDraw.circle(self, p, orb_r, Color(c, 0.35))
		NeonDraw.arc(self, p, orb_r, 0.0, TAU, 40, Color(c.lightened(0.35), 0.95), 3.0)
		NeonDraw.hexagon(self, p, orb_r * 0.55, c.lightened(0.2), 1.0, 2.5, 0.5)
		NeonDraw.circle(self, p, orb_r * 0.22, Color(1, 1, 1, 0.95))
