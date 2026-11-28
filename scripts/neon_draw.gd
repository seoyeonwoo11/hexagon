class_name NeonDraw
extends RefCounted
## 네온사인 느낌의 선 그리기 도우미.
## 넓고 옅은 선을 여러 겹 겹친 뒤 밝은 중심선을 그려 빛 번짐을 흉내 낸다.
## (WorldEnvironment 글로우가 켜져 있으면 그 위에 실제 블룸이 더해진다.)
##
## 성능 (묶어 그리기): draw_polyline, draw_arc 같은 굵은 선 하나하나가 그리기 호출 1번이라
## 타일 하나가 50번 넘게 호출했다 (타일 37개면 프레임마다 2000번 넘음, 웹에서 특히 느림).
## begin(canvas) ~ flush() 사이의 polyline / hexagon / line / arc / circle / fill 은
## 삼각형 배열 하나에 모았다가 flush()에서 한 번에 그린다. 그린 순서는 그대로 지켜진다.
## 묶지 않을 때 (begin 없이 부르면) 는 예전처럼 바로 그린다.
##
## 성능 (한 번만 그리기): 같은 모양을 매번 GDScript로 삼각형으로 다시 쪼개면 웹에서 특히 느리다.
## cached(canvas, key, build)는 key 모양을 처음 한 번만 build로 만들어 메시로 저장해 두고,
## 다음부터는 저장된 메시를 그대로 그린다 (같은 종류의 적, 같은 레벨의 타일은 메시 하나를 같이 씀).
## 움직임(회전, 크기, 깜빡임)은 노드의 rotation / scale / modulate로만 바꾸고 다시 그리지 않는다.
## 색이 계속 변하는 경우(화상 깜빡임 등)는 quantize()로 색을 1/64 단계로 맞춰 저장된 모양을 다시 쓴다.

## 성능: 겹 수가 그리기 양에 그대로 곱해진다. 실제 빛 번짐은 WorldEnvironment 글로우가 더해 줌.
const GLOW_LAYERS := 2
## 뾰족한 꺾임에서 모서리가 너무 길게 튀어나가지 않게 (선 굵기의 몇 배까지)
const MITER_LIMIT := 2.5

static var _canvas: CanvasItem = null
static var _pts := PackedVector2Array()
static var _cols := PackedColorArray()
static var _idx := PackedInt32Array()
## key -> ArrayMesh (빈 모양이면 null). 너무 많아지면 비우고 다시 쌓는다.
static var _meshes := {}
const CACHE_MAX := 1500


## canvas의 _draw 안에서 부른다. 이후 NeonDraw 그리기는 모았다가 flush()에서 한 번에.
static func begin(canvas: CanvasItem) -> void:
	_canvas = canvas
	_pts.clear()
	_cols.clear()
	_idx.clear()


static func flush() -> void:
	if _canvas != null:
		_emit()
	_canvas = null
	_pts.clear()
	_cols.clear()
	_idx.clear()


## begin()~flush() 사이에서: key 모양을 저장해 둔 메시로 그린다. 없으면 build를 한 번 불러 만든다.
## build 안의 NeonDraw 그리기만 저장된다. key에는 모양과 색을 바꾸는 값이 모두 들어 있어야 한다.
## 그린 순서는 그대로 지켜진다 (앞에 모아 둔 것을 먼저 그린 다음 메시를 그림).
static func cached(canvas: CanvasItem, key: String, build: Callable) -> void:
	if not _batching(canvas):
		build.call()
		return
	var mesh: ArrayMesh
	if _meshes.has(key):
		mesh = _meshes[key]
	else:
		var pts := _pts
		var cols := _cols
		var idx := _idx
		_pts = PackedVector2Array()
		_cols = PackedColorArray()
		_idx = PackedInt32Array()
		build.call()
		mesh = _make_mesh()
		_pts = pts
		_cols = cols
		_idx = idx
		if _meshes.size() >= CACHE_MAX:
			_meshes.clear()
		_meshes[key] = mesh
	if mesh == null:
		return
	_emit()
	canvas.draw_mesh(mesh, null)


## 지금까지 모은 삼각형을 그리기 명령 하나로 내보낸다.
static func _emit() -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _idx, _pts, _cols)
	_pts.clear()
	_cols.clear()
	_idx.clear()


static func _make_mesh() -> ArrayMesh:
	if _idx.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pts
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 계속 변하는 색을 1/64 단계로 맞춘다 (눈으로는 구분 안 됨). 저장된 모양을 다시 쓰기 위해.
static func quantize(c: Color) -> Color:
	return Color(roundf(c.r * 64.0) / 64.0, roundf(c.g * 64.0) / 64.0, roundf(c.b * 64.0) / 64.0,
			roundf(c.a * 64.0) / 64.0)


## 색을 key에 넣을 문자열로
static func color_key(c: Color) -> String:
	return c.to_html()


static func cache_size() -> int:
	return _meshes.size()


static func _batching(canvas: CanvasItem) -> bool:
	return _canvas != null and _canvas == canvas


static func polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color,
		intensity: float = 1.0, width: float = 3.0) -> void:
	if _batching(canvas):
		for i in range(GLOW_LAYERS, 0, -1):
			_stroke(points, Color(color, 0.13 * intensity), width + i * 6.0)
		_stroke(points, Color(color.lightened(0.45), intensity), width)
		return
	# 번짐 층은 어차피 흐릿해서 안티앨리어싱 없이 그린다 (삼각형 수 절약)
	for i in range(GLOW_LAYERS, 0, -1):
		canvas.draw_polyline(points, Color(color, 0.13 * intensity), width + i * 6.0, false)
	canvas.draw_polyline(points, Color(color.lightened(0.45), intensity), width, true)


static func hexagon(canvas: CanvasItem, center: Vector2, radius: float, color: Color,
		intensity: float = 1.0, width: float = 3.0, fill_alpha: float = 0.0) -> void:
	var pts := HexGrid.corners(radius)
	for i in pts.size():
		pts[i] += center
	if fill_alpha > 0.0:
		fill(canvas, pts, Color(color, fill_alpha * intensity))
	var closed := pts.duplicate()
	closed.append(pts[0])
	polyline(canvas, closed, color, intensity, width)


## 볼록 다각형 채우기
static func fill(canvas: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if not _batching(canvas):
		canvas.draw_colored_polygon(pts, color)
		return
	var base := _pts.size()
	for p in pts:
		_pts.append(p)
		_cols.append(color)
	for i in range(1, pts.size() - 1):
		_idx.append_array([base, base + i, base + i + 1])


## 빛 번짐 없는 선 (draw_line / draw_polyline 대신)
static func line(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if _batching(canvas):
		_stroke(points, color, width)
	else:
		canvas.draw_polyline(points, color, width, true)


static func arc(canvas: CanvasItem, center: Vector2, radius: float, from: float, to: float,
		segments: int, color: Color, width: float) -> void:
	if not _batching(canvas):
		canvas.draw_arc(center, radius, from, to, segments, color, width, true)
		return
	var pts := PackedVector2Array()
	for i in segments + 1:
		pts.append(center + Vector2.from_angle(lerpf(from, to, float(i) / segments)) * radius)
	_stroke(pts, color, width)


static func circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if not _batching(canvas):
		canvas.draw_circle(center, radius, color)
		return
	var n := clampi(int(radius * 0.5), 8, 96)
	var pts := PackedVector2Array()
	for i in n:
		pts.append(center + Vector2.from_angle(TAU * i / n) * radius)
	fill(canvas, pts, color)


## 굵은 선을 삼각형으로 (꺾이는 곳은 마이터 이음). 첫 점과 끝 점이 같으면 닫힌 선.
static func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	var n := points.size()
	if n < 2:
		return
	var closed := n > 2 and points[0].is_equal_approx(points[n - 1])
	var count := n - 1 if closed else n
	var half := width * 0.5
	var base := _pts.size()
	for i in count:
		var p := points[i]
		var prev: Vector2
		var next: Vector2
		if closed:
			prev = points[(i - 1 + count) % count]
			next = points[(i + 1) % count]
		else:
			prev = points[maxi(i - 1, 0)]
			next = points[mini(i + 1, n - 1)]
		var d_in := (p - prev).normalized() if i > 0 or closed else (next - p).normalized()
		var d_out := (next - p).normalized() if i < n - 1 or closed else d_in
		var n_in := d_in.orthogonal()
		var n_out := d_out.orthogonal()
		var miter := n_in + n_out
		var off: Vector2
		if miter.length_squared() < 0.0001:
			off = n_out * half
		else:
			miter = miter.normalized()
			var k := miter.dot(n_out)
			off = miter * minf(half / maxf(k, 0.0001), half * MITER_LIMIT)
		_pts.append(p + off)
		_pts.append(p - off)
		_cols.append(color)
		_cols.append(color)
	var segs := count if closed else count - 1
	for s in segs:
		var a := base + s * 2
		var b := base + ((s + 1) % count) * 2
		_idx.append_array([a, a + 1, b, b, a + 1, b + 1])
