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
signal equip_finished(tile: HexTile)
signal move_finished(tile: HexTile)
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
## 코어 스킬(OVERDRIVE) 동안만 곱하는 공격력 배율
var skill_damage_mult := 1.0
## 타일 옮기기 모드. move_from이 null이면 옮길 타일을 고르는 중, 아니면 갈 칸을 고르는 중.
var moving := false
var move_from: HexTile
## 타일별/웨이브별 준 피해 (일시정지 화면 통계)
var stats := DamageStats.new()
## 배치 중인 타일 종류. 빈 문자열이면 배치 모드가 아님.
var placing_kind := ""
## 장착 중인 장비 id. 빈 문자열이면 장착 모드가 아님.
var equipping_gear := ""
var selected_tile: HexTile
## 영구 강화(HARD SHELL)로 새 타일 최대 체력에 곱하는 값
var tile_hp_mult := 1.0

var _hover := Vector2i.ZERO
var _has_hover := false


func _ready() -> void:
	enemy_layer = Node2D.new()
	enemy_layer.name = "Enemies"
	enemy_layer.z_index = 1
	add_child(enemy_layer)
	place_tile(CORE, "core")


func _process(_delta: float) -> void:
	if is_equipping() or moving:
		queue_redraw()  # 장착/옮기기 가능한 타일 테두리 깜빡임
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
		elif is_equipping():
			try_equip(cell)
		elif moving:
			click_move(cell)
		else:
			select_tile(tiles.get(cell))
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and moving:
		cancel_move()
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not is_placing() and not is_equipping():
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
	if kind != "core":
		tile.max_hp *= tile_hp_mult
		tile.hp = tile.max_hp
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


func begin_equip(gear_id: String) -> void:
	select_tile(null)
	equipping_gear = gear_id
	queue_redraw()


func is_equipping() -> bool:
	return equipping_gear != ""


## 장착 가능한 타일들 (장착 모드의 장비 기준).
func equippable_tiles() -> Array[HexTile]:
	var result: Array[HexTile] = []
	if not is_equipping():
		return result
	for tile in tiles.values():
		if GearDefs.can_equip(equipping_gear, tile):
			result.append(tile)
	return result


## 장착 모드에서 coord의 타일에 장비를 단다. 장착할 수 없으면 null.
func try_equip(coord: Vector2i) -> HexTile:
	if not is_equipping():
		return null
	var tile: HexTile = tiles.get(coord)
	if tile == null or not GearDefs.can_equip(equipping_gear, tile):
		return null
	tile.equip(equipping_gear)
	equipping_gear = ""
	queue_redraw()
	equip_finished.emit(tile)
	return tile


# ---------------------------------------------------------------- 타일 옮기기

func begin_move() -> void:
	select_tile(null)
	moving = true
	move_from = null
	queue_redraw()


func cancel_move() -> void:
	moving = false
	move_from = null
	queue_redraw()


## 옮길 수 있는 타일 (코어는 제자리).
func movable_tiles() -> Array[HexTile]:
	var result: Array[HexTile] = []
	for t in tiles.values():
		if t.coord != CORE:
			result.append(t)
	return result


## tile을 coord로 옮길 수 있는지. 다른 타일이 있으면 자리 바꾸기(코어 제외),
## 빈 칸이면 tile 말고 다른 타일과 면이 맞닿아 있어야 한다.
func can_move_to(tile: HexTile, coord: Vector2i) -> bool:
	if tile == null or coord == tile.coord or coord == CORE or not is_inside(coord):
		return false
	if tiles.has(coord):
		return true
	for n in HexGrid.neighbors(coord):
		if tiles.has(n) and tiles[n] != tile:
			return true
	return false


## 옮기기 모드에서 칸을 클릭: 처음엔 옮길 타일을 집고, 다음엔 갈 칸(또는 바꿀 타일)을 고른다.
func click_move(coord: Vector2i) -> void:
	if not moving:
		return
	if move_from == null or coord == move_from.coord:
		var t: HexTile = tiles.get(coord)
		move_from = t if t != null and t.coord != CORE and move_from == null else null
		queue_redraw()
		return
	move_tile(move_from, coord)


## tile을 coord로 옮긴다 (그 자리에 타일이 있으면 서로 바꿈). 성공하면 옮기기 모드가 끝난다.
func move_tile(tile: HexTile, coord: Vector2i) -> bool:
	if not can_move_to(tile, coord):
		return false
	var from := tile.coord
	var other: HexTile = tiles.get(coord)
	tiles.erase(from)
	if other != null:
		_set_coord(other, from)
	_set_coord(tile, coord)
	moving = false
	move_from = null
	queue_redraw()
	move_finished.emit(tile)
	return true


func _set_coord(tile: HexTile, coord: Vector2i) -> void:
	tile.coord = coord
	tile.position = HexGrid.axial_to_pixel(coord, hex_size)
	tile.name = "Tile_%d_%d" % [coord.x, coord.y]
	tiles[coord] = tile
	tile.queue_redraw()


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
	stats.mark_dead(tile)
	Sfx.play("tile_break")
	tiles.erase(tile.coord)
	tile.queue_free()
	queue_redraw()
	tile_destroyed.emit(tile)


func _draw() -> void:
	var outline := HexGrid.corners(hex_size * 0.97)
	outline.append(outline[0])
	# 성능: 배경 격자 전체를 선분 묶음 하나로 그린다 (칸마다 따로 그리면 호출이 수백 개)
	var segs := PackedVector2Array()
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, grid_radius):
		var center := HexGrid.axial_to_pixel(cell, hex_size)
		for i in outline.size() - 1:
			segs.append(outline[i] + center)
			segs.append(outline[i + 1] + center)
	draw_multiline(segs, grid_color, 1.0, true)
	if moving:
		_draw_move()
		return
	if is_equipping():
		var gear_color: Color = GearDefs.get_def(equipping_gear)["color"]
		for tile in equippable_tiles():
			var hovered := _has_hover and _hover == tile.coord
			var pulse := 0.6 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
			NeonDraw.hexagon(self, tile.position, hex_size * 1.08, gear_color,
					1.0 if hovered else pulse, 3.0 if hovered else 2.0)
		return
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


## 옮기기 모드 표시: 집을 수 있는 타일은 흰 테두리 깜빡임, 집은 뒤에는 갈 수 있는 빈 칸과 바꿀 수 있는 타일.
func _draw_move() -> void:
	var pulse := 0.6 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
	var c := Color(1.0, 1.0, 1.0)
	if move_from == null:
		for t in movable_tiles():
			var hot := _has_hover and _hover == t.coord
			NeonDraw.hexagon(self, t.position, hex_size * 1.05, c, 1.0 if hot else pulse * 0.7,
					3.0 if hot else 1.5)
		return
	NeonDraw.hexagon(self, move_from.position, hex_size * 1.08, c, 1.2, 3.5)
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, grid_radius):
		if not can_move_to(move_from, cell):
			continue
		var pos := HexGrid.axial_to_pixel(cell, hex_size)
		var hot := _has_hover and _hover == cell
		if tiles.has(cell):
			NeonDraw.hexagon(self, pos, hex_size * 1.02, c, 0.9 if hot else 0.35, 2.5 if hot else 1.2)
		else:
			NeonDraw.hexagon(self, pos, hex_size * 0.85, move_from.color, 0.95 if hot else 0.45,
					2.5 if hot else 1.5)
