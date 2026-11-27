class_name NeonDraw
extends RefCounted
## 네온사인 느낌의 선 그리기 도우미.
## 넓고 옅은 선을 여러 겹 겹친 뒤 밝은 중심선을 그려 빛 번짐을 흉내 낸다.
## (WorldEnvironment 글로우가 켜져 있으면 그 위에 실제 블룸이 더해진다.)

const GLOW_LAYERS := 3


static func polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color,
		intensity: float = 1.0, width: float = 3.0) -> void:
	for i in range(GLOW_LAYERS, 0, -1):
		canvas.draw_polyline(points, Color(color, 0.10 * intensity), width + i * 5.0, true)
	canvas.draw_polyline(points, Color(color.lightened(0.45), intensity), width, true)


static func hexagon(canvas: CanvasItem, center: Vector2, radius: float, color: Color,
		intensity: float = 1.0, width: float = 3.0, fill_alpha: float = 0.0) -> void:
	var pts := HexGrid.corners(radius)
	for i in pts.size():
		pts[i] += center
	if fill_alpha > 0.0:
		canvas.draw_colored_polygon(pts, Color(color, fill_alpha * intensity))
	var closed := pts.duplicate()
	closed.append(pts[0])
	polyline(canvas, closed, color, intensity, width)
