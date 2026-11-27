class_name BeamFx
extends Node2D
## LASER의 지속 광선을 그린다. 적 위에 보이도록 z_index를 높인다.
## 대상 선택과 피해 계산은 HexTile이 하고, 여기서는 그리기만 한다.
## 성능: 광선이 꽂혀 있는 동안만 이 작은 노드를 매 프레임 다시 그리고, 타일 본체는 다시 그리지 않는다.

## 광선을 따라 대상 -> 타일 쪽으로 흘러가는 빛 알갱이 수와 속도 (빨아들이는 느낌)
const DRIP_COUNT := 3
const DRIP_SPEED := 1.6

var tile: HexTile
var _time := 0.0
var _was_active := false


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	var active := tile != null and tile.beam_active()
	if active:
		_time += delta
	if active or _was_active:
		queue_redraw()
	_was_active = active


func _draw() -> void:
	if tile == null or not tile.beam_active():
		return
	var lv := tile.level - 1
	for i in tile.beam_targets.size():
		var e = tile.beam_targets[i]
		if is_instance_valid(e):
			var f := tile.beam_focus(e)
			var c := tile.color.lerp(Color.WHITE, 0.45 * f)
			_draw_beam(to_local(e.global_position), c, 3.0 + 0.6 * lv + 5.0 * f, float(i))


## 타일 중심에서 end까지 한 줄. 살짝 떨리는 굵기 + 흰 심 + 대상 쪽 불꽃 + 흘러오는 알갱이.
func _draw_beam(end: Vector2, c: Color, width: float, phase: float) -> void:
	var w := width * (0.85 + 0.15 * sin(_time * 40.0 + phase * 2.1))
	var line := PackedVector2Array([Vector2.ZERO, end])
	NeonDraw.polyline(self, line, c, 0.9, w)
	draw_polyline(line, Color(1, 1, 1, 0.8), maxf(w * 0.3, 1.2), true)
	draw_circle(end, w * 1.1, Color(c, 0.35))
	draw_circle(end, w * 0.5, Color(1, 1, 1, 0.7))
	var glow := c.lerp(Color.WHITE, 0.5)
	for k in DRIP_COUNT:
		var t := fmod(_time * DRIP_SPEED + (k + phase * 0.37) / DRIP_COUNT, 1.0)
		draw_circle(end.lerp(Vector2.ZERO, t), w * 0.45, Color(glow, 0.9 * (1.0 - t * 0.6)))
