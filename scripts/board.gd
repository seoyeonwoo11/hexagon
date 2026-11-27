class_name Board
extends Node2D
## 육각형 보드: 배경 그리드, 타일 목록, 배치 규칙을 관리한다.
## 배치 규칙: 비어 있고, 이미 놓인 타일과 면이 맞닿은 칸에만 놓을 수 있다.

signal tile_placed(tile: HexTile)

@export var hex_size := 48.0
@export var grid_radius := 5
@export var grid_color := Color(0.3, 0.35, 0.7, 0.25)
@export var placeable_color := Color(1.0, 0.2, 0.8)
@export var hover_color := Color(1.0, 1.0, 1.0)

var tiles: Dictionary[Vector2i, HexTile] = {}

var _hover := Vector2i.ZERO
var _has_hover := false


func _ready() -> void:
	place_tile(Vector2i.ZERO)


func _process(_delta: float) -> void:
	var cell := HexGrid.pixel_to_axial(get_local_mouse_position(), hex_size)
	var inside := is_inside(cell)
	if inside != _has_hover or cell != _hover:
		_hover = cell
		_has_hover = inside
		queue_redraw()


func is_inside(coord: Vector2i) -> bool:
	return HexGrid.distance(coord, Vector2i.ZERO) <= grid_radius


func can_place(coord: Vector2i) -> bool:
	if tiles.has(coord) or not is_inside(coord):
		return false
	for n in HexGrid.neighbors(coord):
		if tiles.has(n):
			return true
	return false


func placeable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, grid_radius):
		if can_place(cell):
			result.append(cell)
	return result


## 첫 타일(원점)은 규칙 없이 놓고, 이후 타일은 can_place를 통과해야 한다.
func place_tile(coord: Vector2i, color := Color(0.0, 0.95, 1.0)) -> HexTile:
	if not tiles.is_empty() and not can_place(coord):
		return null
	var tile := HexTile.new()
	tile.name = "Tile_%d_%d" % [coord.x, coord.y]
	tile.coord = coord
	tile.size = hex_size
	tile.color = color
	tile.position = HexGrid.axial_to_pixel(coord, hex_size)
	add_child(tile)
	tiles[coord] = tile
	queue_redraw()
	tile_placed.emit(tile)
	return tile


func _draw() -> void:
	var outline := HexGrid.corners(hex_size * 0.97)
	outline.append(outline[0])
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, grid_radius):
		var center := HexGrid.axial_to_pixel(cell, hex_size)
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(p + center)
		draw_polyline(pts, grid_color, 1.0, true)
	for cell in placeable_cells():
		NeonDraw.hexagon(self, HexGrid.axial_to_pixel(cell, hex_size), hex_size * 0.85,
				placeable_color, 0.35, 1.5)
	if _has_hover and not tiles.has(_hover):
		var c := placeable_color if can_place(_hover) else hover_color
		NeonDraw.hexagon(self, HexGrid.axial_to_pixel(_hover, hex_size), hex_size * 0.85,
				c, 0.8, 2.0)
