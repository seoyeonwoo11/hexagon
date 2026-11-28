class_name CoinIcon
extends Control
## 판 안 돈($) 아이콘: 네온 노랑 동전 (바깥 테두리 + 안쪽 육각형). "$" 글자 대신 쓴다.
## dim이면 흐리게 (돈이 모자랄 때 등).

const NEON_YELLOW := Color(1.0, 0.85, 0.1)

var color := NEON_YELLOW
var dim := false:
	set(value):
		if dim != value:
			dim = value
			queue_redraw()


func _init(px := 30.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	var col := Color(1, 1, 1, 0.3) if dim else color
	var w := maxf(r * 0.16, 1.5)
	if not dim:
		draw_circle(c, r + w, Color(col, 0.16))
	draw_circle(c, r, Color(col.darkened(0.75), 0.9))
	draw_arc(c, r, 0.0, TAU, 40, col.lightened(0.0 if dim else 0.25), w, true)
	# 가운데 육각형 각인 (게임 타일 모양)
	var hex := PackedVector2Array()
	for i in 7:
		hex.append(c + Vector2.from_angle(TAU * i / 6.0) * r * 0.52)
	draw_polyline(hex, col, w * 0.8, true)
	draw_colored_polygon(hex.slice(0, 6), Color(col, 0.35))
