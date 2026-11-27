class_name Shop
extends CanvasLayer
## 시작 화면 겸 상점. 게임을 켤 때와 판이 끝났을 때 나온다.
##
## 배치 (1920x1080 기준):
##   왼쪽  : 게임 이름, 지난 판 결과, 가진 SHARD
##   가운데: 벌집 모양 보드. 가운데 육각형이 START, 둘레가 타일.
##           잠긴 타일은 클릭해서 구매, 풀린 타일은 클릭해서 출정 타일(최대 6종)에 넣거나 뺀다
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
const NUMBER_SIZE := 132

var _result_label: Label
var _best_label: Label
var _shards_value: FixedDigits
var _honeycomb: Honeycomb
var _caption_title: Label
var _caption_body: Label
var _upgrade_list: VBoxContainer
var _core_picker: CorePicker


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
	if Hud.wants_fullscreen_button():
		var full := Hud.make_fullscreen_button()
		full.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		full.offset_left = -40 - 130
		full.offset_right = -40
		full.offset_top = 40
		full.offset_bottom = 100
		bg.add_child(full)
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
	_shards_value.set_value(Meta.shards)
	if Meta.last_run_victory and Meta.last_run_wave > EnemyDefs.FINAL_WAVE:
		_result_label.text = "Cleared! Endless until wave %d\n+%d shards" \
				% [Meta.last_run_wave, Meta.last_run_shards]
	elif Meta.last_run_victory:
		_result_label.text = "OVERLORD defeated!\n+%d shards" % Meta.last_run_shards
	elif Meta.last_run_wave > 0:
		_result_label.text = "Run ended on wave %d\n+%d shards" \
				% [Meta.last_run_wave, Meta.last_run_shards]
	else:
		_result_label.text = "Beat the OVERLORD on wave %d.\nClear waves to earn shards." % EnemyDefs.FINAL_WAVE
	_best_label.text = "Best wave  %d" % Meta.best_wave if Meta.best_wave > 0 else ""
	if Meta.clears > 0:
		_best_label.text += "    Clears  %d" % Meta.clears
	_honeycomb.queue_redraw()
	if _core_picker != null:
		_core_picker.queue_redraw()
	_show_caption(_honeycomb.hovered if _core_picker == null or _core_picker.hovered == "" \
			else "core:" + _core_picker.hovered)
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
	col.add_child(_spacer(44))
	var shard_row := HBoxContainer.new()
	shard_row.add_theme_constant_override("separation", 24)
	col.add_child(shard_row)
	_shards_value = FixedDigits.new()
	_shards_value.font_size = NUMBER_SIZE
	_shards_value.color = SHARD_COLOR
	_shards_value.min_digits = 3
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
	col.add_child(_spacer(44))
	var core_head := Hud.make_label(INK_DIM, 22, 600)
	core_head.text = "Core and skill"
	col.add_child(core_head)
	col.add_child(_spacer(10))
	_core_picker = CorePicker.new()
	_core_picker.core_clicked.connect(_on_core_clicked)
	_core_picker.hover_changed.connect(func(id: String) -> void:
		_show_caption("none" if id == "" else "core:" + id))
	col.add_child(_core_picker)


func _on_core_clicked(id: String) -> void:
	var changed := Meta.select_core(id) if Meta.is_core_unlocked(id) else Meta.buy_core(id)
	if changed:
		refresh()


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
	var changed := Meta.toggle_loadout(kind) if Meta.is_tile_unlocked(kind) \
			else Meta.buy_tile(kind)
	if changed:
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
	if kind.begins_with("core:"):
		var id := kind.substr(5)
		var cdef := CoreDefs.get_def(id)
		_caption_title.text = "%s  -  %s" % [cdef["name"], cdef["skill_name"]]
		_set_color(_caption_title, cdef["color"])
		var how := ""
		if Meta.core_type == id:
			how = "Selected. Press Q in a run to use the skill (%ds cooldown)." % int(cdef["cooldown"])
		elif Meta.is_core_unlocked(id):
			how = "Click to use this core."
		elif Meta.shards >= cdef["price"]:
			how = "Click to unlock for %d shards." % cdef["price"]
		else:
			how = "Unlock for %d shards (%d more needed)." % [cdef["price"], cdef["price"] - Meta.shards]
		_caption_body.text = "%s\n%s" % [cdef["desc"], how]
		return
	if kind == "none":
		_caption_title.text = "Pick your tiles"
		_set_color(_caption_title, Color.WHITE)
		_caption_body.text = "Pick up to %d tiles to bring. Only these show up as cards.\nClick a tile to add or remove it." % Meta.MAX_LOADOUT
		return
	var def := TileDefs.get_def(kind)
	_caption_title.text = def["name"]
	_set_color(_caption_title, def["color"])
	var action := ""
	if Meta.in_loadout(kind):
		action = "In your loadout. Click to remove." if Meta.loadout.size() > 1 \
				else "In your loadout (you need at least one)."
	elif Meta.is_tile_unlocked(kind):
		action = "Loadout full (%d/%d). Remove a tile first." % [Meta.loadout.size(), Meta.MAX_LOADOUT] \
				if Meta.loadout_full() else "Click to add to your loadout (%d/%d)." \
				% [Meta.loadout.size(), Meta.MAX_LOADOUT]
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

	const R := 76.0
	## 둘레 6칸 다음에 놓을 칸 (오른쪽 위, 왼쪽 아래, 위, 오른쪽 아래). 타일 종류가 늘면 여기에 추가.
	## 바로 아래 칸은 LOADOUT 글자 자리라 비워 둔다.
	const EXTRA_CELLS: Array[Vector2i] = [Vector2i(2, -1), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(1, 1)]

	var hovered := "none"
	var _time := 0.0
	var _font: Font
	var _cells := {}  # Vector2i -> kind ("" 는 코어)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Hud.font_weight(700)
		_cells[Vector2i.ZERO] = ""
		var slots: Array[Vector2i] = []
		slots.append_array(HexGrid.DIRECTIONS)
		slots.append_array(EXTRA_CELLS)
		var kinds := TileDefs.PLACEABLE
		for i in mini(kinds.size(), slots.size()):
			_cells[slots[i]] = kinds[i]

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
		# 아래쪽: 출정 타일 수 (위쪽 끝 칸은 9번째, 오른쪽 아래 칸은 10번째 타일 자리)
		var full := Meta.loadout_full()
		_text(c0 + Vector2(0, R * 3.05), "LOADOUT  %d / %d" % [Meta.loadout.size(), Meta.MAX_LOADOUT],
				20, Color(1, 1, 1, 0.95) if full else Color(1, 1, 1, 0.7))
		for cell in _cells:
			var kind: String = _cells[cell]
			var pos: Vector2 = c0 + HexGrid.axial_to_pixel(cell, R)
			if kind == "":
				_draw_core(pos)
			else:
				_draw_tile(pos, kind)

	## START: 꽉 찬 밝은 육각형 + 바깥으로 퍼지는 고리. 화면에서 가장 밝은 것. 고른 코어 색.
	func _draw_core(pos: Vector2) -> void:
		var c: Color = CoreDefs.get_def(Meta.core_type)["color"]
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
		var picked := Meta.in_loadout(kind)
		var hot := hovered == kind
		var c: Color = def["color"] if owned else LOCKED_COLOR
		# 출정 타일: 밝고 안이 채워짐 / 풀렸지만 안 넣은 타일: 흐림 / 잠김: 회색
		var intensity := 1.0 if picked else 0.4 if owned else 0.55
		if hot:
			intensity += 0.3
		var fill := 0.2 if picked else 0.03
		NeonDraw.hexagon(self, pos, R * 0.86, c, intensity, 3.0 if picked else 2.0,
				fill + (0.08 if hot else 0.0))
		if hot:
			NeonDraw.hexagon(self, pos, R * 0.96, Color.WHITE, 0.6, 1.5)
		draw_set_transform(pos + Vector2(0, -12))
		HexTile.draw_glyph(self, kind, R * 0.24, c, intensity, _time * 2.4)
		draw_set_transform(Vector2.ZERO)
		var name_size := 13 if def["name"].length() > 7 else 15
		_text(pos + Vector2(0, 24), def["name"], name_size, Color(c, 0.95 if picked else 0.6))
		if not owned:
			var price: int = Meta.TILE_PRICES[kind]
			var afford := Meta.shards >= price
			var pc := SHARD_COLOR if afford else Color(SHARD_COLOR, 0.45)
			_text(pos + Vector2(0, 44), "%d" % price, 17, pc)
		elif picked:
			# 출정 표시: 위쪽 꼭짓점 근처 작은 꽉 찬 육각형
			NeonDraw.hexagon(self, pos + Vector2(0, -R * 0.6), 5.0, c, 1.0, 1.0, 1.0)
		else:
			_text(pos + Vector2(0, 44), "OFF", 13, Color(c, 0.5))

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


## 숫자를 Orbitron 그대로 쓰되, 글자마다 같은 폭의 칸에 가운데 맞춰 그린다.
## Orbitron은 숫자 폭이 제각각(1이 좁음)이라 Label로 쓰면 값이 바뀔 때 폭이 흔들린다.
## min_digits 자리만큼 폭을 미리 잡아 옆 요소도 움직이지 않는다.
class FixedDigits extends Control:
	var font_size := 132
	var color := Color.WHITE
	var min_digits := 3
	var _text := "0"
	var _font: Font
	var _cell := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Hud.font_weight(900)
		for d in "0123456789":
			_cell = maxf(_cell, _font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size).x)
		_cell *= 0.96
		_update_size()

	func set_value(v: int) -> void:
		_text = "%d" % v
		_update_size()
		queue_redraw()

	func _update_size() -> void:
		if _font == null:
			return
		custom_minimum_size = Vector2(_cell * maxi(min_digits, _text.length()),
				_font.get_height(font_size) * 0.82)

	func _draw() -> void:
		var base := _font.get_ascent(font_size) * 0.9
		for i in _text.length():
			var ch := _text[i]
			var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var x := _cell * i + (_cell - w) / 2.0
			# 바깥 빛 번짐 두 겹 + 본 글자
			for k in [10, 5]:
				draw_string_outline(_font, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
						font_size, k, Color(color, 0.12))
			draw_string(_font, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					color)


## 코어 고르기: 작은 육각형 4개. 고른 코어는 꽉 차고, 잠긴 코어는 회색 + 가격.
class CorePicker extends Control:
	signal core_clicked(id: String)
	signal hover_changed(id: String)

	const R := 40.0
	const GAP := 112.0

	var hovered := ""
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Hud.font_weight(700)
		custom_minimum_size = Vector2(GAP * CoreDefs.ORDER.size(), R * 2.0 + 44.0)

	func _center(i: int) -> Vector2:
		return Vector2(GAP * (i + 0.5) - (GAP - R * 2.2) * 0.5, R + 4.0)

	func _id_at(p: Vector2) -> String:
		for i in CoreDefs.ORDER.size():
			if p.distance_to(_center(i)) <= R:
				return CoreDefs.ORDER[i]
		return ""

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var id := _id_at(motion.position)
			if id != hovered:
				hovered = id
				mouse_default_cursor_shape = CURSOR_ARROW if id == "" else Control.CURSOR_POINTING_HAND
				hover_changed.emit(id)
				queue_redraw()
			return
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var id := _id_at(mb.position)
			if id != "":
				core_clicked.emit(id)
				hover_changed.emit(id)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hovered != "":
			hovered = ""
			hover_changed.emit("")
			queue_redraw()

	func _draw() -> void:
		for i in CoreDefs.ORDER.size():
			var id: String = CoreDefs.ORDER[i]
			var def := CoreDefs.get_def(id)
			var pos := _center(i)
			var owned := Meta.is_core_unlocked(id)
			var picked := Meta.core_type == id
			var hot := hovered == id
			var c: Color = def["color"] if owned else LOCKED_COLOR
			NeonDraw.hexagon(self, pos, R * 0.92, c, (1.1 if picked else 0.5) + (0.3 if hot else 0.0),
					3.0 if picked else 2.0, 0.35 if picked else (0.08 if hot else 0.02))
			draw_set_transform(pos)
			HexTile.draw_glyph(self, "core" if id == "core" else "core_" + id, R * 0.42, c, 1.0)
			draw_set_transform(Vector2.ZERO)
			var label: String = def["skill_name"] if owned else "%d" % def["price"]
			var lc := Color(c, 0.95 if picked else 0.6) if owned \
					else (SHARD_COLOR if Meta.shards >= def["price"] else Color(SHARD_COLOR, 0.45))
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(_font, pos + Vector2(-w / 2.0, R + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 14, lc)
