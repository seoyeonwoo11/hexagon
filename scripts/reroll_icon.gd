class_name RerollIcon
extends Control
## 카드 다시 뽑기 버튼의 네온 새로고침 아이콘 (둥근 화살표). 글자 대신 쓴다.
## dim이면 흐리게 (이번 웨이브에 이미 썼거나 돈이 모자랄 때).

var color := Color(1.0, 0.85, 0.1)
var dim := false:
	set(value):
		if dim != value:
			dim = value
			queue_redraw()

const ARC_FROM := deg_to_rad(-20.0)
const ARC_TO := deg_to_rad(225.0)


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.34
	var col := Color(1, 1, 1, 0.3) if dim else color
	var glow := 0.0 if dim else 1.0
	# 빛 번짐 한 겹 + 밝은 중심선
	if glow > 0.0:
		draw_arc(c, r, ARC_FROM, ARC_TO, 32, Color(col, 0.18), 9.0, true)
	draw_arc(c, r, ARC_FROM, ARC_TO, 32, col.lightened(0.3 * glow), 3.5, true)
	# 끝에 화살촉 (시계 방향으로 도는 쪽을 가리킴)
	var end := c + Vector2.from_angle(ARC_TO) * r
	var tangent := Vector2.from_angle(ARC_TO + PI / 2.0)
	var normal := Vector2.from_angle(ARC_TO)
	var a := r * 0.62
	var head := PackedVector2Array([
		end + tangent * a * 1.3,
		end + normal * a,
		end - normal * a,
	])
	draw_colored_polygon(head, col.lightened(0.3 * glow))
