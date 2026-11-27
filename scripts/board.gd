class_name Board
extends Node2D
## 육각형 보드: 배경 그리드, 타일 목록, 배치 규칙, 타일 선택을 관리한다.
## 배치 규칙: 비어 있고, 이미 놓인 타일과 면이 맞닿은 칸에만 놓을 수 있다.
## 배치 모드(begin_placement) 중에만 놓을 수 있는 칸을 표시하고 클릭으로 배치한다.
## 평소에는 타일을 클릭하면 선택되고(tile_selected), 빈 곳을 클릭하면 선택이 풀린다.

signal tile_placed(tile: HexTile)
signal tile_destroyed(tile: HexTile)
signal tile_selected(tile: HexTile)
signal placement_finished(tile: HexTile)
signal core_destroyed

const CORE := Vector2i.ZERO

@export var hex_size := 48.0
@export var grid_radius := 5
@export var grid_color := Color(0.3, 0.35, 0.7, 0.25)
@export var placeable_color := Color(1.0, 0.2, 0.8)
@export var hover_color := Color(1.0, 1.0, 1.0)

var tiles: Dictionary[Vector2i, HexTile] = {}
## 적은 이 레이어에 추가한다 (보드와 같은 좌표계, 타일 위에 그려짐).
var enemy_layer: Node2D
## 전체 강화 배율 (웨이브 클리어 카드로 오른다).
var damage_mult := 1.0
var rate_mult := 1.0
## 배치 중인 타일 종류. 빈 문자열이면 배치 모드가 아님.
var placing_kind := ""
var selected_tile: HexTile

var _hover := Vector2i.ZERO
var _has_hover := false


func _ready() -> void:
	enemy_layer = Node2D.new()
	enemy_layer.name = "Enemies"
	enemy_layer.z_index = 1
	add_child(enemy_layer)
	place_tile(CORE, "core")


func _process(_delta: float) -> void:
	var cell := HexGrid.pixel_to_axial(get_local_mouse_position(), hex_size)
	var inside := is_inside(cell)
	if inside != _has_hover or cell != _hover:
		_hover = cell
		_has_hover = inside
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var cell := HexGrid.pixel_to_axial(get_local_mouse_position(), hex_size)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if is_placing():
			try_place(cell)
		else:
			select_tile(tiles.get(cell))
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not is_placing():
		select_tile(null)
		get_viewport().set_input_as_handled()


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
func place_tile(coord: Vector2i, kind := "laser") -> HexTile:
	if not tiles.is_empty() and not can_place(coord):
		return null
	var tile := HexTile.new()
	tile.name = "Tile_%d_%d" % [coord.x, coord.y]
	tile.setup(kind)
	tile.coord = coord
	tile.size = hex_size
	tile.board = self
	tile.position = HexGrid.axial_to_pixel(coord, hex_size)
	tile.destroyed.connect(_on_tile_destroyed)
	add_child(tile)
	tiles[coord] = tile
	queue_redraw()
	tile_placed.emit(tile)
	return tile


func begin_placement(kind: String) -> void:
	select_tile(null)
	placing_kind = kind
	queue_redraw()


func is_placing() -> bool:
	return placing_kind != ""


## 배치 모드에서 coord에 타일을 놓는다. 놓을 수 없는 칸이면 null.
func try_place(coord: Vector2i) -> HexTile:
	if not is_placing():
		return null
	var tile := place_tile(coord, placing_kind)
	if tile != null:
		placing_kind = ""
		queue_redraw()
		placement_finished.emit(tile)
	return tile


func select_tile(tile: HexTile) -> void:
	if selected_tile == tile:
		return
	if is_instance_valid(selected_tile):
		selected_tile.selected = false
	selected_tile = tile
	if tile != null:
		tile.selected = true
	tile_selected.emit(tile)


func core_tile() -> HexTile:
	return tiles.get(CORE)


## 전역 좌표 기준으로 가장 가까운 타일.
func nearest_tile(global_point: Vector2) -> HexTile:
	var best: HexTile = null
	var best_dist := INF
	for tile in tiles.values():
		var d := global_point.distance_squared_to(tile.global_position)
		if d < best_dist:
			best = tile
			best_dist = d
	return best


func _on_tile_destroyed(tile: HexTile) -> void:
	if tile.coord == CORE:
		core_destroyed.emit()
		return
	if selected_tile == tile:
		select_tile(null)
	tiles.erase(tile.coord)
	tile.queue_free()
	queue_redraw()
	tile_destroyed.emit(tile)


func _draw() -> void:
	var outline := HexGrid.corners(hex_size * 0.97)
	outline.append(outline[0])
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, grid_radius):
		var center := HexGrid.axial_to_pixel(cell, hex_size)
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(p + center)
		draw_polyline(pts, grid_color, 1.0, true)
	if not is_placing():
		return
	var kind_color: Color = TileDefs.get_def(placing_kind)["color"]
	for cell in placeable_cells():
		NeonDraw.hexagon(self, HexGrid.axial_to_pixel(cell, hex_size), hex_size * 0.85,
				placeable_color, 0.45, 1.5)
	if _has_hover and not tiles.has(_hover):
		var c := kind_color if can_place(_hover) else hover_color
		NeonDraw.hexagon(self, HexGrid.axial_to_pixel(_hover, hex_size), hex_size * 0.85,
				c, 0.9, 2.5)
