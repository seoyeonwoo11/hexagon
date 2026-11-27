class_name Shop
extends CanvasLayer
## 시작 화면 겸 상점. 게임을 켤 때와 판이 끝났을 때 나온다.
##
## 배치 (1920x1080 기준):
##   왼쪽  : 게임 이름, 지난 판 결과, 가진 SHARD
##   가운데: 벌집 모양 보드. 가운데 육각형이 START, 둘레 6칸이 타일 (잠긴 타일은 클릭해서 구매)
##   오른쪽: 영구 강화 목록 (이름, 설명, 육각형 레벨 표시, 구매 버튼)
## 벌집 아래 설명 줄은 마우스를 올린 칸을 설명한다.

signal start_pressed

const SHARD_COLOR := Color(0.55, 1.0, 0.75)
const LOCKED_COLOR := Color(0.36, 0.40, 0.47)
const INK := Color(1, 1, 1, 0.85)
const INK_DIM := Color(1, 1, 1, 0.5)
const RULE := Color(1, 1, 1, 0.12)
const SIDE_MARGIN := 120
## 임시(테스트용): + 키나 숫자 옆 + 버튼으로 SHARD 지급. 출시 전에 false로.
const DEBUG_FREE_SHARDS := true
const DEBUG_SHARD_AMOUNT := 10

var _result_label: Label
var _best_label: Label
var _shards_value: Label
var _honeycomb: Honeycomb
var _caption_title: Label
var _caption_body: Label
var _upgrade_list: VBoxContainer


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_build_left(bg)
	_build_center(bg)
	_build_right(bg)
	refresh()


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func refresh() -> void:
	if _shards_value == null:
		return
	_shards_value.text = "%d" % Meta.shards
	if Meta.last_run_wave > 0:
		_result_label.text = "Run ended on wave %d\n+%d shards" \
				% [Meta.last_run_wave, Meta.last_run_shards]
	else:
		_result_label.text = "Clear waves to earn shards.\nSpend them here between runs."
	_best_label.text = "Best wave  %d" % Meta.best_wave if Meta.best_wave > 0 else ""
	_honeycomb.queue_redraw()
	_show_caption(_honeycomb.hovered)
	for child in _upgrade_list.get_children():
		child.queue_free()
	for i in Meta.UPGRADES.size():
		if i > 0:
			var rule := ColorRect.new()
			rule.color = RULE
			rule.custom_minimum_size = Vector2(0, 1)
			_upgrade_list.add_child(rule)
		_upgrade_list.add_child(_upgrade_row(Meta.UPGRADES[i]))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		start_pressed.emit()
	elif DEBUG_FREE_SHARDS and (key.keycode == KEY_KP_ADD or key.keycode == KEY_EQUAL
			or key.keycode == KEY_PLUS or key.unicode == 43):
		get_viewport().set_input_as_handled()
		add_debug_shards()


## 임시: SHARD 10개 지급 (저장됨).
func add_debug_shards() -> void:
	Meta.shards += DEBUG_SHARD_AMOUNT
	Meta.save_data()
	refresh()


# ---------------------------------------------------------------- 왼쪽

func _build_left(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = SIDE_MARGIN
	col.offset_top = -300
	col.offset_bottom = 300
	col.offset_right = SIDE_MARGIN + 520
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	var title := Hud.make_label(Hud.NEON_CYAN, 92, 900, 0.35)
	title.text = "HEXAGON"
	col.add_child(title)
	col.add_child(_spacer(28))
	_result_label = Hud.make_label(INK, 26, 500)
	_result_label.label_settings.line_spacing = 8
	col.add_child(_result_label)
	col.add_child(_spacer(10))
	_best_label = Hud.make_label(INK_DIM, 20, 500)
	col.add_child(_best_label)
	col.add_child(_spacer(72))
	var shard_row := HBoxContainer.new()
	shard_row.add_theme_constant_override("separation", 24)
	col.add_child(shard_row)
	_shards_value = Hud.make_label(SHARD_COLOR, 132, 900, 0.3)
	shard_row.add_child(_shards_value)
	if DEBUG_FREE_SHARDS:
		var plus := Hud.make_neon_button("+%d" % DEBUG_SHARD_AMOUNT, SHARD_COLOR)
		plus.custom_minimum_size = Vector2(96, 56)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.tooltip_text = "Test only: +%d shards" % DEBUG_SHARD_AMOUNT
		plus.pressed.connect(add_debug_shards)
		shard_row.add_child(plus)
	var unit := Hud.make_label(SHARD_COLOR, 26, 600)
	unit.text = "shards to spend"
	col.add_child(unit)


# ---------------------------------------------------------------- 가운데

func _build_center(parent: Control) -> void:
	_honeycomb = Honeycomb.new()
	_honeycomb.set_anchors_preset(Control.PRESET_CENTER)
	_honeycomb.offset_left = -300
	_honeycomb.offset_right = 300
	_honeycomb.offset_top = -330
	_honeycomb.offset_bottom = 230
	_honeycomb.start_pressed.connect(func() -> void: start_pressed.emit())
	_honeycomb.tile_clicked.connect(_on_tile_clicked)
	_honeycomb.hover_changed.connect(_show_caption)
	parent.add_child(_honeycomb)

	var cap := VBoxContainer.new()
	cap.set_anchors_preset(Control.PRESET_CENTER)
	cap.offset_left = -300
	cap.offset_right = 300
	cap.offset_top = 250
	cap.offset_bottom = 400
	cap.add_theme_constant_override("separation", 8)
	parent.add_child(cap)
	_caption_title = Hud.make_label(Color.WHITE, 26, 800)
	_caption_body = Hud.make_label(INK, 19, 500)
	_caption_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [_caption_title, _caption_body]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(l)


func _on_tile_clicked(kind: String) -> void:
	if Meta.buy_tile(kind):
		refresh()


## 벌집 아래 설명. kind가 ""이면 START 안내, "none"이면 기본 문구.
func _show_caption(kind: String) -> void:
	if _caption_title == null:
		return
	if kind == "":
		_caption_title.text = "Start a run"
		_set_color(_caption_title, Hud.NEON_CYAN)
		_caption_body.text = "Click the core or press Enter."
		return
	if kind == "none":
		_caption_title.text = "Your tiles"
		_set_color(_caption_title, Color.WHITE)
		_caption_body.text = "Unlocked tiles can show up as cards during a run.\nHover a tile for details."
		return
	var def := TileDefs.get_def(kind)
	_caption_title.text = def["name"]
	_set_color(_caption_title, def["color"])
	var action := ""
	if Meta.is_tile_unlocked(kind):
		action = "Unlocked"
	else:
		var price: int = Meta.TILE_PRICES[kind]
		if Meta.shards >= price:
			action = "Click to unlock for %d shards" % price
		else:
			action = "Unlock for %d shards (%d more needed)" % [price, price - Meta.shards]
	_caption_body.text = "%s\n%s" % [def["desc"], action]


# ---------------------------------------------------------------- 오른쪽

func _build_right(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	col.offset_right = -SIDE_MARGIN
	col.offset_left = -SIDE_MARGIN - 470
	col.offset_top = -330
	col.offset_bottom = 330
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	parent.add_child(col)
	var heading := Hud.make_label(INK_DIM, 22, 600)
	heading.text = "Permanent upgrades"
	col.add_child(heading)
	_upgrade_list = VBoxContainer.new()
	_upgrade_list.add_theme_constant_override("separation", 16)
	col.add_child(_upgrade_list)


func _upgrade_row(u: Dictionary) -> Control:
	var id: String = u["id"]
	var lv := Meta.level(id)
	var cost := Meta.upgrade_cost(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	var name_label := Hud.make_label(u["color"], 24, 800)
	name_label.text = u["title"]
	var desc := Hud.make_label(INK, 17, 500)
	desc.text = u["desc"]
	var pips := LevelPips.new()
	pips.level = lv
	pips.max_level = u["max"]
	pips.color = u["color"]
	for c in [name_label, desc, pips]:
		text.add_child(c)
	var b := Hud.make_neon_button("Maxed" if cost < 0 else "%d" % cost, SHARD_COLOR)
	b.custom_minimum_size = Vector2(110, 54)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = cost < 0 or Meta.shards < cost
	b.tooltip_text = "" if cost < 0 else "Buy level %d for %d shards" % [lv + 1, cost]
	b.pressed.connect(func() -> void:
		if Meta.buy_upgrade(id):
			refresh())
	row.add_child(b)
	return row


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _set_color(label: Label, color: Color) -> void:
	label.label_settings.font_color = color


## 가운데 벌집: START 코어 + 둘레 타일 6칸. 게임 보드와 같은 육각형 좌표를 쓴다.
class Honeycomb extends Control:
	signal start_pressed
	signal tile_clicked(kind: String)
	## "" = START 위, "none" = 아무것도 아님, 그 외 = 타일 종류
	signal hover_changed(kind: String)

	const R := 92.0

	var hovered := "none"
	var _time := 0.0
	var _font: Font
	var _cells := {}  # Vector2i -> kind ("" 는 코어)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Hud.font_weight(700)
		_cells[Vector2i.ZERO] = ""
		var kinds := TileDefs.PLACEABLE
		for i in mini(kinds.size(), HexGrid.DIRECTIONS.size()):
			_cells[HexGrid.DIRECTIONS[i]] = kinds[i]

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_time += delta
		queue_redraw()

	func _center() -> Vector2:
		return size / 2.0

	func _kind_at(local: Vector2) -> String:
		var cell := HexGrid.pixel_to_axial(local - _center(), R)
		return _cells.get(cell, "none")

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var k := _kind_at(motion.position)
			if k != hovered:
				hovered = k
				mouse_default_cursor_shape = CURSOR_ARROW if k == "none" \
						else Control.CURSOR_POINTING_HAND
				hover_changed.emit(k)
			return
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var k := _kind_at(mb.position)
			if k == "":
				start_pressed.emit()
			elif k != "none":
				tile_clicked.emit(k)
				hover_changed.emit(k)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hovered != "none":
			hovered = "none"
			hover_changed.emit("none")

	func _draw() -> void:
		var c0 := _center()
		for cell in _cells:
			var kind: String = _cells[cell]
			var pos: Vector2 = c0 + HexGrid.axial_to_pixel(cell, R)
			if kind == "":
				_draw_core(pos)
			else:
				_draw_tile(pos, kind)

	## START: 꽉 찬 밝은 육각형 + 바깥으로 퍼지는 고리. 화면에서 가장 밝은 것.
	func _draw_core(pos: Vector2) -> void:
		var c := Hud.NEON_CYAN
		var hot := hovered == ""
		var k := fmod(_time * 0.8, 1.0)
		NeonDraw.hexagon(self, pos, R * (0.95 + 0.35 * k), c, 0.8 * (1.0 - k), 2.0)
		var fill := c.lightened(0.35) if hot else c
		var pts := HexGrid.corners(R * 0.92)
		for i in pts.size():
			pts[i] += pos
		draw_colored_polygon(pts, fill)
		NeonDraw.hexagon(self, pos, R * 0.92, c, 1.2, 4.0)
		var ink := Color(0, 0, 0)
		var tri := PackedVector2Array([pos + Vector2(-10, -38), pos + Vector2(14, -26),
				pos + Vector2(-10, -14)])
		draw_colored_polygon(tri, ink)
		_text(pos + Vector2(0, 10), "START", 30, ink)
		_text(pos + Vector2(0, 40), "Enter", 15, Color(ink, 0.7))

	func _draw_tile(pos: Vector2, kind: String) -> void:
		var def := TileDefs.get_def(kind)
		var owned := Meta.is_tile_unlocked(kind)
		var hot := hovered == kind
		var c: Color = def["color"] if owned else LOCKED_COLOR
		var intensity := 0.9 if owned else 0.55
		if hot:
			intensity += 0.3
		NeonDraw.hexagon(self, pos, R * 0.86, c, intensity, 2.5, 0.12 if hot else 0.05)
		if hot:
			NeonDraw.hexagon(self, pos, R * 0.96, Color.WHITE, 0.6, 1.5)
		draw_set_transform(pos + Vector2(0, -14))
		HexTile.draw_glyph(self, kind, R * 0.24, c, intensity, _time * 2.4)
		draw_set_transform(Vector2.ZERO)
		_text(pos + Vector2(0, 30), def["name"], 15, Color(c, 0.95 if owned else 0.7))
		if not owned:
			var price: int = Meta.TILE_PRICES[kind]
			var afford := Meta.shards >= price
			var pc := SHARD_COLOR if afford else Color(SHARD_COLOR, 0.45)
			_text(pos + Vector2(0, 54), "%d" % price, 18, pc)

	## pos를 글자 가운데(기준선 근처)로 하여 쓴다.
	func _text(pos: Vector2, s: String, font_size: int, color: Color) -> void:
		var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(_font, pos + Vector2(-w / 2.0, font_size * 0.35), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 영구 강화 레벨: 작은 육각형 max_level개, 산 만큼 채워진다.
class LevelPips extends Control:
	var level := 0
	var max_level := 5
	var color := Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := 8.0
		for i in max_level:
			var pos := Vector2(r + 2 + i * (r * 2.3), size.y / 2.0)
			if i < level:
				NeonDraw.hexagon(self, pos, r, color, 0.9, 1.5, 0.8)
			else:
				NeonDraw.hexagon(self, pos, r, Color(1, 1, 1, 0.3), 0.5, 1.0)
