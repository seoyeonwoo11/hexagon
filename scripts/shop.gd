class_name Shop
extends CanvasLayer
## 시작 화면. 게임을 켤 때와 판이 끝났을 때 나온다. 사는 것은 따로 연 상점 창(ShopWindow)에서.
## 설명 글은 두지 않는다 (모양과 색, 숫자로만 보여 줌).
##
## 배치 (1920x1080 기준):
##   위    : 스테이지 고르기 (깬 스테이지 다음까지 열림, 깬 스테이지는 아래 점)
##   왼쪽  : 게임 이름과 메뉴 버튼 3개 (게임 시작 / 상점 / 설정)를 한 군데에
##           게임 시작은 코어를 고르는 창(StartPanel)을 열고, 거기서 판을 시작
##   가운데: 벌집 모양 보드. 가운데 육각형은 고른 코어, 둘레가 타일. 아래에 가져갈 타일 수
##           풀린 타일은 클릭해서 가져갈 타일(최대 6종)에 넣거나 빼고, 잠긴 타일은 클릭하면 상점 창
##   오른쪽: 가진 SHARD

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

var _shards_value: FixedDigits
var _honeycomb: Honeycomb
var _window: ShopWindow
var _settings: SettingsPanel
var _start: StartPanel
var _root: ColorRect
var _stage_picker: StagePicker


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = bg
	_build_left(bg)
	_build_center(bg)
	_build_top(bg)
	_build_right(bg)
	_window = ShopWindow.new()
	# 상점 창이 떠 있는 동안 시작 화면은 숨긴다 (글로우가 비쳐 보이지 않게)
	_window.closed.connect(func() -> void:
		_root.visible = true
		refresh())
	add_child(_window)
	# 언어, 소리, 전체 화면은 설정 창 안에
	_settings = SettingsPanel.new()
	add_child(_settings)
	_start = StartPanel.new()
	_start.start_pressed.connect(func() -> void: start_pressed.emit())
	_start.shop_requested.connect(func() -> void: open_window("cores"))
	add_child(_start)
	refresh()


func open_settings() -> void:
	_settings.open()


## 게임 시작 창 (코어 고르기)
func open_start() -> void:
	_start.open()


func is_start_open() -> bool:
	return _start != null and _start.is_open()


func switch_language() -> void:
	Loc.toggle()
	if is_inside_tree():
		get_tree().reload_current_scene()


func open() -> void:
	visible = true
	Sfx.music("menu")
	refresh()


func close() -> void:
	visible = false
	if _window != null:
		_window.visible = false
		_root.visible = true
	if _start != null:
		_start.close()
		_settings.close()


## 상점 창 열기. tab: "upgrades", "tiles", "cores" ("" 이면 마지막 탭)
func open_window(tab := "") -> void:
	Sfx.play("click")
	_root.visible = false
	_window.open(tab)


func is_window_open() -> bool:
	return _window != null and _window.is_open()


func is_open() -> bool:
	return visible


func refresh() -> void:
	if _shards_value == null:
		return
	_shards_value.set_value(Meta.shards)
	_honeycomb.queue_redraw()
	if _start != null and _start.is_open():
		_start.refresh()
	if _stage_picker != null:
		_stage_picker.queue_redraw()
	if _window != null and _window.is_open():
		_window.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_window_open() or _settings.is_open() or is_start_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		open_start()
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
	col.add_child(_spacer(70))
	var menu := VBoxContainer.new()
	menu.name = "Menu"
	menu.add_theme_constant_override("separation", 18)
	col.add_child(menu)
	menu.add_child(_menu_button("StartButton", Loc.t("NEW GAME"), Hud.NEON_CYAN, open_start))
	menu.add_child(_menu_button("ShopButton", Loc.t("SHOP"), SHARD_COLOR, func() -> void: open_window()))
	menu.add_child(_menu_button("SettingsButton", Loc.t("SETTINGS"), Color(1, 1, 1, 0.8), open_settings))


func _menu_button(id: String, text: String, color: Color, action: Callable) -> Button:
	var b := Hud.make_neon_button(text, color)
	b.name = id
	b.custom_minimum_size = Vector2(440, 86)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(action)
	return b


## 산 코어는 고르고, 안 산 코어는 상점 창의 CORES 탭을 연다. (게임 시작 창에서 씀)
func _on_core_clicked(id: String) -> void:
	_start._on_core_clicked(id)


# ---------------------------------------------------------------- 위 (스테이지)

func _build_top(parent: Control) -> void:
	_stage_picker = StagePicker.new()
	_stage_picker.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var w := StagePicker.GAP * StageDefs.count()
	_stage_picker.offset_left = -w / 2.0
	_stage_picker.offset_right = w / 2.0
	_stage_picker.offset_top = 40
	_stage_picker.offset_bottom = 40 + StagePicker.HEIGHT
	_stage_picker.stage_clicked.connect(func(n: int) -> void:
		if Meta.select_stage(n):
			refresh())
	parent.add_child(_stage_picker)


# ---------------------------------------------------------------- 가운데

func _build_center(parent: Control) -> void:
	_honeycomb = Honeycomb.new()
	_honeycomb.set_anchors_preset(Control.PRESET_CENTER)
	_honeycomb.offset_left = -300
	_honeycomb.offset_right = 300
	_honeycomb.offset_top = -330
	_honeycomb.offset_bottom = 230
	_honeycomb.tile_clicked.connect(_on_tile_clicked)
	parent.add_child(_honeycomb)


## 산 타일은 출정 타일에 넣거나 빼고, 안 산 타일은 상점 창의 TILES 탭을 연다.
func _on_tile_clicked(kind: String) -> void:
	if not Meta.is_tile_unlocked(kind):
		open_window("tiles")
		return
	var changed := Meta.toggle_loadout(kind)
	Sfx.play("click" if changed else "deny")
	if changed:
		refresh()


# ---------------------------------------------------------------- 오른쪽

## 가진 SHARD (큰 숫자). 사는 것은 모두 상점 창에서.
func _build_right(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	col.offset_right = -SIDE_MARGIN
	col.offset_left = -SIDE_MARGIN - 420
	col.offset_top = -260
	col.offset_bottom = 260
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)
	var shard_row := HBoxContainer.new()
	shard_row.add_theme_constant_override("separation", 20)
	col.add_child(shard_row)
	_shards_value = FixedDigits.new()
	_shards_value.font_size = NUMBER_SIZE
	_shards_value.color = SHARD_COLOR
	_shards_value.min_digits = 3
	shard_row.add_child(_shards_value)
	if DEBUG_FREE_SHARDS:
		var plus := Hud.make_neon_button("+%d" % DEBUG_SHARD_AMOUNT, SHARD_COLOR)
		plus.custom_minimum_size = Vector2(84, 50)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.tooltip_text = Loc.t("Test only: +%d shards") % DEBUG_SHARD_AMOUNT
		plus.pressed.connect(add_debug_shards)
		shard_row.add_child(plus)
	var unit := Hud.make_label(Color(SHARD_COLOR, 0.7), 24, 600)
	unit.text = Loc.t("shards")
	col.add_child(unit)


## 배율 표시: 1.5 -> "1.5", 2.0 -> "2"
static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _set_color(label: Label, color: Color) -> void:
	label.label_settings.font_color = color


## 가운데 벌집: 고른 코어 + 둘레 타일. 게임 보드와 같은 육각형 좌표를 쓴다.
class Honeycomb extends Control:
	signal tile_clicked(kind: String)
	## "none" = 아무것도 아님 (가운데 코어 포함), 그 외 = 타일 종류
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
		var k: String = _cells.get(cell, "none")
		return "none" if k == "" else k

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
			if k != "none":
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
		_text(c0 + Vector2(0, R * 3.05), "%d / %d" % [Meta.loadout.size(), Meta.max_loadout()],
				20, Color(1, 1, 1, 0.95) if full else Color(1, 1, 1, 0.7))
		for cell in _cells:
			var kind: String = _cells[cell]
			var pos: Vector2 = c0 + HexGrid.axial_to_pixel(cell, R)
			if kind == "":
				_draw_core(pos)
			else:
				_draw_tile(pos, kind)

	## 고른 코어: 밝은 육각형 + 바깥으로 퍼지는 고리 + 코어 모양. 고르기는 게임 시작 창에서.
	func _draw_core(pos: Vector2) -> void:
		var id := Meta.core_type
		var c: Color = CoreDefs.get_def(id)["color"]
		var k := fmod(_time * 0.8, 1.0)
		NeonDraw.hexagon(self, pos, R * (0.95 + 0.35 * k), c, 0.8 * (1.0 - k), 2.0)
		NeonDraw.hexagon(self, pos, R * 0.92, c, 1.2, 4.0, 0.3)
		draw_set_transform(pos)
		HexTile.draw_glyph(self, "core" if id == "core" else "core_" + id, R * 0.4, c, 1.0)
		draw_set_transform(Vector2.ZERO)

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
		# 스테이지를 깰수록 칸이 늘어난다 (최대 20칸). 많으면 작게 그려 한 줄에 맞춘다.
		var r := 8.0 if max_level <= 12 else 6.0
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

	var r := 40.0
	var gap := 102.0
	## 육각형 아래에 코어 이름을 쓴다 (게임 시작 창)
	var show_names := false

	var hovered := ""
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Hud.font_weight(700)
		custom_minimum_size = Vector2(gap * CoreDefs.ORDER.size(), r * 2.0 + (70.0 if show_names else 44.0))

	func _center(i: int) -> Vector2:
		return Vector2(gap * (i + 0.5), r + 4.0)

	func _id_at(p: Vector2) -> String:
		for i in CoreDefs.ORDER.size():
			if p.distance_to(_center(i)) <= r:
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
			var available := Meta.is_core_available(id)
			var picked := Meta.core_type == id
			var hot := hovered == id
			var c: Color = def["color"] if owned else LOCKED_COLOR
			NeonDraw.hexagon(self, pos, r * 0.92, c, (1.1 if picked else 0.5) + (0.3 if hot else 0.0),
					3.0 if picked else 2.0, 0.35 if picked else (0.08 if hot else 0.02))
			draw_set_transform(pos)
			HexTile.draw_glyph(self, "core" if id == "core" else "core_" + id, r * 0.42, c, 1.0)
			draw_set_transform(Vector2.ZERO)
			var below := r + 22.0
			if show_names:
				var nm: String = def["name"]
				var nw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
				draw_string(_font, pos + Vector2(-nw / 2.0, r + 26.0), nm, HORIZONTAL_ALIGNMENT_LEFT,
						-1, 17, Color(c, 0.95 if picked else 0.6))
				below = r + 54.0
			var label: String = "" if owned else "%d" % def["price"]
			var lc := Color(c, 0.95 if picked else 0.6) if owned \
					else (SHARD_COLOR if Meta.shards >= def["price"] else Color(SHARD_COLOR, 0.45))
			if not owned and not available:
				# 스테이지를 깨야 살 수 있다
				label = ""
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(_font, pos + Vector2(-w / 2.0, below), label, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 14, lc)


## 스테이지 고르기: 육각형 StageDefs.count()개를 가로로. 고른 스테이지는 꽉 차고,
## 깬 스테이지는 아래에 CLEAR, 잠긴 스테이지는 회색 + LOCKED, 나머지는 최고 웨이브.
class StagePicker extends Control:
	signal stage_clicked(n: int)
	## 0 = 아무것도 아님
	signal hover_changed(n: int)

	const R := 36.0
	const GAP := 104.0
	const HEIGHT := 122.0

	var hovered := 0
	var _font: Font
	var _font_big: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Hud.font_weight(700)
		_font_big = Hud.font_weight(900)

	func _center(i: int) -> Vector2:
		return Vector2(GAP * (i + 0.5), 26.0 + R)

	func _stage_at(p: Vector2) -> int:
		for i in StageDefs.count():
			if p.distance_to(_center(i)) <= R:
				return i + 1
		return 0

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var n := _stage_at(motion.position)
			if n != hovered:
				hovered = n
				mouse_default_cursor_shape = CURSOR_ARROW if n == 0 else Control.CURSOR_POINTING_HAND
				hover_changed.emit(n)
				queue_redraw()
			return
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var n := _stage_at(mb.position)
			if n > 0:
				stage_clicked.emit(n)
				hover_changed.emit(n)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hovered != 0:
			hovered = 0
			hover_changed.emit(0)
			queue_redraw()

	func _draw() -> void:
		for i in StageDefs.count():
			var n := i + 1
			var pos := _center(i)
			var open := Meta.is_stage_unlocked(n)
			var picked := Meta.stage == n
			var hot := hovered == n
			var c: Color = StageDefs.color(n) if open else LOCKED_COLOR
			NeonDraw.hexagon(self, pos, R * 0.92, c, (1.1 if picked else 0.5) + (0.3 if hot else 0.0),
					3.0 if picked else 2.0, 0.85 if picked else (0.08 if hot else 0.02))
			var num_color := Color.BLACK if picked else Color(c, 0.95 if open else 0.6)
			_text(pos + Vector2(0, 2), "%d" % n, 30, num_color, _font_big)
			# 깬 스테이지: 아래에 작은 꽉 찬 육각형
			if Meta.is_stage_cleared(n):
				NeonDraw.hexagon(self, pos + Vector2(0, R + 14.0), 5.0, c, 1.0, 1.0, 1.0)

	func _text(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, pos + Vector2(-w / 2.0, font_size * 0.35), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
