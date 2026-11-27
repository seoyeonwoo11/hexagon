extends SceneTree
## 실행: godot --headless --path . -s res://tests/test_hex_grid.gd

var _failures := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


var _done := false


## 첫 프레임에서 실행해야 노드의 _ready가 호출된 상태가 된다.
func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	var size := 48.0
	# 픽셀 <-> 칸 좌표 왕복
	for cell in HexGrid.cells_in_radius(Vector2i.ZERO, 5):
		var back := HexGrid.pixel_to_axial(HexGrid.axial_to_pixel(cell, size), size)
		_check(back == cell, "round trip %s -> %s" % [cell, back])
	_check(HexGrid.cells_in_radius(Vector2i.ZERO, 2).size() == 19, "radius 2 has 19 cells")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(2, -1)) == 2, "distance")
	for n in HexGrid.neighbors(Vector2i(3, -2)):
		_check(HexGrid.distance(n, Vector2i(3, -2)) == 1, "neighbor distance 1")
	# 이웃 칸 중심 사이 거리 = sqrt(3) * size (면이 맞닿음)
	var d := HexGrid.axial_to_pixel(Vector2i(1, 0), size).distance_to(Vector2.ZERO)
	_check(absf(d - HexGrid.SQRT3 * size) < 0.001, "neighbor spacing")

	# 보드 배치 규칙
	var board := Board.new()
	root.add_child(board)
	_check(board.is_node_ready(), "board ready")
	_check(board.tiles.size() == 1 and board.tiles.has(Vector2i.ZERO), "starts with one tile")
	_check(board.placeable_cells().size() == 6, "6 placeable cells around start")
	_check(board.place_tile(Vector2i(2, 0)) == null, "cannot place non-adjacent")
	_check(board.place_tile(Vector2i.ZERO) == null, "cannot place on occupied")
	_check(board.place_tile(Vector2i(1, 0)) != null, "can place adjacent")
	_check(board.place_tile(Vector2i(2, 0)) != null, "chain placement")
	_check(board.place_tile(Vector2i(board.grid_radius + 1, 0)) == null, "cannot place outside grid")

	if _failures == 0:
		print("ALL TESTS PASSED")
	quit(1 if _failures > 0 else 0)
