class_name HexGrid
extends RefCounted
## 정육각형 그리드 수학 (pointy-top, axial 좌표 q = x, r = y).
## 참고: https://www.redblobgames.com/grids/hexagons/

const SQRT3 := 1.7320508075688772

## 이웃 6방향. 순서는 오른쪽부터 반시계 방향.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


## 칸 좌표 -> 화면(로컬) 픽셀 좌표. size는 중심에서 꼭짓점까지 거리.
static func axial_to_pixel(coord: Vector2i, size: float) -> Vector2:
	var x := size * SQRT3 * (coord.x + coord.y / 2.0)
	var y := size * 1.5 * coord.y
	return Vector2(x, y)


## 픽셀 좌표 -> 가장 가까운 칸 좌표.
static func pixel_to_axial(point: Vector2, size: float) -> Vector2i:
	var q := (SQRT3 / 3.0 * point.x - 1.0 / 3.0 * point.y) / size
	var r := (2.0 / 3.0 * point.y) / size
	return axial_round(q, r)


static func axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## 면이 맞닿은 6개의 이웃 칸.
static func neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(coord + dir)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.x + d.y) + absi(d.y)) / 2


## center로부터 radius 칸 이내의 모든 칸.
static func cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(center + Vector2i(q, r))
	return result


## 원점 기준 육각형 꼭짓점 6개 (pointy-top).
static func corners(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(Vector2(cos(angle), sin(angle)) * size)
	return pts
