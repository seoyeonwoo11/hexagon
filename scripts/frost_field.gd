class_name FrostField
extends Node2D
## FROST 타일의 감속 범위. 타일과 이웃 타일 뒤에 깔리도록 z_index를 낮춘다.
## 옅게 채운 원, 또렷한 테두리, 천천히 도는 눈금, 공격 때마다 바깥으로 퍼지는 냉기 파동.
## 성능: 범위 그림은 사거리가 바뀔 때만 다시 그리고, 눈금 회전은 노드 rotation으로 한다.
## 매 프레임 다시 그리는 건 파동 원 하나뿐 (_Pulse).

const TICKS := 18

var tile: HexTile
var _drawn := []
var _pulse: _Pulse


func _ready() -> void:
	z_index = -1
	_pulse = _Pulse.new()
	_pulse.tile = tile
	add_child(_pulse)


func sync() -> void:
	rotation = tile._time * 0.25
	var state := [tile.effective_range(), tile.color]
	if state != _drawn:
		_drawn = state
		queue_redraw()
	if _pulse != null:
		_pulse.rotation = -rotation
		_pulse.queue_redraw()


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
	# 범위 안을 옅게 채움 (가장자리로 갈수록 조금 진하게)
	NeonDraw.circle(self, Vector2.ZERO, r, Color(c, 0.05))
	NeonDraw.arc(self, Vector2.ZERO, r * 0.93, 0.0, TAU, 96, Color(c, 0.05), r * 0.14)
	# 테두리: 넓고 흐린 빛 + 얇고 밝은 선
	NeonDraw.arc(self, Vector2.ZERO, r, 0.0, TAU, 128, Color(c, 0.12), 8.0)
	NeonDraw.arc(self, Vector2.ZERO, r, 0.0, TAU, 128, Color(c, 0.6), 1.8)
	# 테두리 안쪽 눈금
	for i in TICKS:
		var d := Vector2.from_angle(TAU * i / TICKS)
		NeonDraw.line(self, PackedVector2Array([d * (r - 10.0), d * (r - 2.0)]), Color(c, 0.55), 1.5)


## 냉기 파동: 공격 주기에 맞춰 타일에서 테두리까지 퍼지는 원.
class _Pulse extends Node2D:
	var tile: HexTile

	func _draw() -> void:
		if tile == null:
			return
		var iv := tile.interval()
		if iv <= 0.0:
			return
		var phase := clampf(1.0 - tile._cooldown / iv, 0.0, 1.0)
		var pr := lerpf(tile.size * 0.8, tile.effective_range(), phase)
		NeonDraw.arc(self, Vector2.ZERO, pr, 0.0, TAU, 64, Color(tile.color, 0.35 * (1.0 - phase)), 3.0)
