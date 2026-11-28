class_name Shop
extends CanvasLayer
## 시작 화면. 게임을 켤 때와 판이 끝났을 때 나온다.
## 한눈에 보이게 가운데 한 줄로: 스테이지 고르기 -> 큰 START -> 버튼 3개.
##
## 배치 (1920x1080 기준):
##   위 왼쪽 : 게임 이름        위 오른쪽: 가진 SHARD, 언어, 소리
##   가운데  : 스테이지 고르기, 고른(또는 마우스를 올린) 스테이지 설명 한 줄
##             큰 START 육각형 (고른 코어 색)
##             버튼 3개: 가져갈 타일 / 코어 / 상점. 누르면 창(ShopWindow)이 열린다
##   아래    : 지난 판 결과 한 줄

signal start_pressed

const SHARD_COLOR := Color(0.55, 1.0, 0.75)
const LOCKED_COLOR := Color(0.36, 0.40, 0.47)
const INK := Color(1, 1, 1, 0.85)
const INK_DIM := Color(1, 1, 1, 0.5)
const RULE := Color(1, 1, 1, 0.12)
## 임시(테스트용): + 키나 SHARD 옆 + 버튼으로 SHARD 지급. 출시 전에 false로.
const DEBUG_FREE_SHARDS := true
const DEBUG_SHARD_AMOUNT := 10

var _root: ColorRect
var _window: ShopWindow
var _stage_picker: StagePicker
var _stage_info: Label
var _start: StartButton
var _shards_label: Label
var _result_label: Label
var _loadout_button: HubButton
var _core_button: HubButton
var _shop_button: HubButton


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	_root.color = Color.BLACK
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_build_top_bar(_root)
	_build_center(_root)
	_build_bottom(_root)
	_window = ShopWindow.new()
	# 창이 떠 있는 동안 시작 화면은 숨긴다 (글로우가 비쳐 보이지 않게)
	_window.closed.connect(func() -> void:
		_root.visible = true
		refresh())
	add_child(_window)
	refresh()


# ---------------------------------------------------------------- 위 줄

func _build_top_bar(parent: Control) -> void:
	var title := Hud.make_label(Hud.NEON_CYAN, 46, 900, 0.35)
	title.text = "HEXAGON"
	title.position = Vector2(48, 40)
	parent.add_child(title)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 16)
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -1100
	bar.offset_right = -40
	bar.offset_top = 40
	bar.offset_bottom = 100
	parent.add_child(bar)
	_shards_label = Hud.make_label(SHARD_COLOR, 34, 900, 0.3)
	_shards_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_shards_label)
	if DEBUG_FREE_SHARDS:
		var plus := Hud.make_neon_button("+%d" % DEBUG_SHARD_AMOUNT, SHARD_COLOR)
		plus.custom_minimum_size = Vector2(76, 50)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.tooltip_text = Loc.t("Test only: +%d shards") % DEBUG_SHARD_AMOUNT
		plus.pressed.connect(add_debug_shards)
		bar.add_child(plus)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	bar.add_child(gap)
	var lang := Hud.make_neon_button(Loc.other_lang_name(), Color(1, 1, 1, 0.75))
	lang.name = "LanguageButton"
	lang.custom_minimum_size = Vector2(160, 56)
	lang.add_theme_font_size_override("font_size", 20)
	lang.tooltip_text = "Language / 언어"
	lang.pressed.connect(switch_language)
	bar.add_child(lang)
	var sound := SoundPanel.make_button()
	sound.custom_minimum_size = Vector2(140, 56)
	bar.add_child(sound)
	if Hud.wants_fullscreen_button():
		var full := Hud.make_fullscreen_button()
		full.custom_minimum_size = Vector2(120, 56)
		bar.add_child(full)


func switch_language() -> void:
	Loc.toggle()
	if is_inside_tree():
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- 가운데

func _build_center(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -560
	col.offset_right = 560
	col.offset_top = -400
	col.offset_bottom = 400
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_stage_picker = StagePicker.new()
	_stage_picker.custom_minimum_size = Vector2(StagePicker.GAP * StageDefs.count(), StagePicker.HEIGHT)
	_stage_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage_picker.stage_clicked.connect(func(n: int) -> void:
		var ok := Meta.select_stage(n)
		Sfx.play("click" if ok or Meta.stage == n else "deny")
		refresh())
	_stage_picker.hover_changed.connect(func(_n: int) -> void: _update_stage_info())
	col.add_child(_stage_picker)
	col.add_child(_spacer(12))
	_stage_info = Hud.make_label(INK, 20, 500)
	_stage_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_info.custom_minimum_size = Vector2(0, 64)
	_stage_info.label_settings.line_spacing = 6
	col.add_child(_stage_info)

	_start = StartButton.new()
	_start.custom_minimum_size = Vector2(340, 330)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(func() -> void: start_pressed.emit())
	col.add_child(_start)
	col.add_child(_spacer(26))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	_loadout_button = HubButton.new()
	_loadout_button.accent = Color.WHITE
	_loadout_button.pressed.connect(func() -> void: open_window("loadout"))
	_core_button = HubButton.new()
	_core_button.pressed.connect(func() -> void: open_window("core"))
	_shop_button = HubButton.new()
	_shop_button.name = "ShopButton"
	_shop_button.accent = SHARD_COLOR
	_shop_button.pressed.connect(func() -> void: open_window("upgrades"))
	for b in [_loadout_button, _core_button, _shop_button]:
		row.add_child(b)


func _build_bottom(parent: Control) -> void:
	_result_label = Hud.make_label(INK_DIM, 20, 500)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_result_label.offset_left = -700
	_result_label.offset_right = 700
	_result_label.offset_top = -70
	_result_label.offset_bottom = -36
	parent.add_child(_result_label)


# ---------------------------------------------------------------- 열고 닫기

func open() -> void:
	visible = true
	Sfx.music("menu")
	refresh()


func close() -> void:
	visible = false
	if _window != null:
		_window.visible = false
		_root.visible = true


func is_open() -> bool:
	return visible


## 창 열기. tab: "loadout", "core" (출전 준비) 또는 "upgrades", "tiles", "cores" (상점)
func open_window(tab := "upgrades") -> void:
	Sfx.play("click")
	_root.visible = false
	_window.open(tab)


func is_window_open() -> bool:
	return _window != null and _window.is_open()


func refresh() -> void:
	if _shards_label == null:
		return
	_shards_label.text = Loc.t("%d shards") % Meta.shards
	_stage_picker.queue_redraw()
	_start.queue_redraw()
	_update_stage_info()
	# 지난 판 결과 + 최고 기록 한 줄
	var last := StageDefs.title(Meta.last_run_stage)
	var line := ""
	if Meta.last_run_victory and Meta.last_run_wave > EnemyDefs.FINAL_WAVE:
		line = Loc.t("Last run: %s cleared, endless until wave %d, +%d shards") \
				% [last, Meta.last_run_wave, Meta.last_run_shards]
	elif Meta.last_run_victory:
		line = Loc.t("Last run: %s cleared, +%d shards") % [last, Meta.last_run_shards]
	elif Meta.last_run_wave > 0:
		line = Loc.t("Last run: %s, wave %d, +%d shards") \
				% [last, Meta.last_run_wave, Meta.last_run_shards]
	else:
		line = Loc.t("Beat the OVERLORD on wave %d to open the next stage.") % EnemyDefs.FINAL_WAVE
	_result_label.text = line
	# 버튼 3개
	_loadout_button.title = Loc.t("TILES TO BRING")
	_loadout_button.sub = "%d / %d" % [Meta.loadout.size(), Meta.max_loadout()]
	_loadout_button.glyphs = Meta.loadout.filter(func(k: String) -> bool: return Meta.is_tile_unlocked(k))
	var cdef := CoreDefs.get_def(Meta.core_type)
	_core_button.title = Loc.t("CORE")
	_core_button.sub = "%s  -  %s" % [cdef["name"], cdef["skill_name"]]
	_core_button.accent = cdef["color"]
	_core_button.glyphs = ["core" if Meta.core_type == "core" else "core_" + Meta.core_type]
	_shop_button.title = Loc.t("SHOP")
	_shop_button.sub = Loc.t("Upgrades  %d / %d") % [_upgrade_levels(), _upgrade_caps()]
	_shop_button.glyphs = ["core"]
	for b in [_loadout_button, _core_button, _shop_button]:
		b.queue_redraw()
	if _window != null and _window.is_open():
		_window.refresh()


## 스테이지 설명 한 줄: 마우스를 올린 스테이지, 없으면 고른 스테이지.
func _update_stage_info() -> void:
	if _stage_info == null:
		return
	var n := _stage_picker.hovered if _stage_picker.hovered > 0 else Meta.stage
	_stage_info.text = stage_info(n)
	_stage_info.label_settings.font_color = Color(StageDefs.color(n), 0.95) \
			if Meta.is_stage_unlocked(n) else INK_DIM


## 스테이지 n 설명 (두 줄): 난이도 / 처음 깨면 받는 것 또는 여는 방법. 최고 기록은 스테이지 칸 아래에.
static func stage_info(n: int) -> String:
	var info := Loc.t("Base difficulty.") if n == 1 \
			else Loc.t("Enemies x%s HP, x%s damage. Shards x%s.") % [_num(StageDefs.hp_mult(n)),
			_num(StageDefs.damage_mult(n)), _num(StageDefs.shard_mult(n))]
	var second := ""
	if not Meta.is_stage_unlocked(n):
		second = Loc.t("Clear %s to unlock.") % StageDefs.title(n - 1)
	elif Meta.is_stage_cleared(n):
		second = Loc.t("Cleared.")
	else:
		second = Loc.t("First clear: %s.") % ", ".join(StageDefs.reward_lines(n))
	return "%s\n%s" % [info, second]


func _upgrade_levels() -> int:
	var n := 0
	for u in Meta.UPGRADES:
		n += Meta.level(u["id"])
	return n


func _upgrade_caps() -> int:
	var n := 0
	for u in Meta.UPGRADES:
		if Meta.is_upgrade_unlocked(u["id"]):
			n += Meta.upgrade_max(u["id"])
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_window_open():
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


## 배율 표시: 1.5 -> "1.5", 2.0 -> "2"
static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 큰 START 육각형: 고른 코어 색으로 꽉 차고 바깥으로 고리가 퍼진다. 화면에서 가장 밝은 것.
class StartButton extends Control:
	signal pressed

	const R := 128.0

	var hovered := false
	var _time := 0.0
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_font = Hud.font_weight(800)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_time += delta
		queue_redraw()

	func _inside(p: Vector2) -> bool:
		return p.distance_to(size / 2.0) <= R * 0.92

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var h := _inside(motion.position)
			if h != hovered:
				hovered = h
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h else CURSOR_ARROW
			return
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _inside(mb.position):
			pressed.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			hovered = false

	func _draw() -> void:
		var pos := size / 2.0
		var c: Color = CoreDefs.get_def(Meta.core_type)["color"]
		for i in 2:
			var k := fmod(_time * 0.6 + i * 0.5, 1.0)
			NeonDraw.hexagon(self, pos, R * (0.95 + 0.3 * k), c, 0.7 * (1.0 - k), 2.0)
		var pts := HexGrid.corners(R * 0.9)
		for i in pts.size():
			pts[i] += pos
		draw_colored_polygon(pts, c.lightened(0.3) if hovered else c)
		NeonDraw.hexagon(self, pos, R * 0.9, c, 1.2, 4.0)
		var ink := Color(0, 0, 0)
		var tri := PackedVector2Array([pos + Vector2(-14, -64), pos + Vector2(20, -46),
				pos + Vector2(-14, -28)])
		draw_colored_polygon(tri, ink)
		_text(pos + Vector2(0, 14), Loc.t("START"), 46, ink)
		_text(pos + Vector2(0, 58), StageDefs.title(Meta.stage), 20, Color(ink, 0.75))

	func _text(p: Vector2, s: String, font_size: int, color: Color) -> void:
		var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(_font, p + Vector2(-w / 2.0, font_size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, color)


## 시작 화면 아래 버튼: 네온 테두리 상자에 제목, 아이콘 줄, 작은 설명. 누르면 pressed.
class HubButton extends Control:
	signal pressed

	const SIZE := Vector2(330, 150)

	var title := ""
	var sub := ""
	var accent := Color.WHITE
	## 아이콘으로 그릴 타일/코어 종류들 (HexTile.draw_glyph)
	var glyphs: Array = []
	var hovered := false
	var _font: Font
	var _font_sub: Font

	func _ready() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_font = Hud.font_weight(800)
		_font_sub = Hud.font_weight(500)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			hovered = true
			queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			hovered = false
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var box := Hud.neon_box(Color(accent, 0.9 if hovered else 0.55), 0.6, 8 if hovered else 0)
		box.bg_color = Color(accent, 0.12) if hovered else Color(accent.darkened(0.85), 0.6)
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		draw_style_box(box, rect)
		_text(Vector2(size.x / 2.0, 34), title, 24, Color.WHITE if hovered else Color(1, 1, 1, 0.9), _font)
		var n := glyphs.size()
		if n > 0:
			var step := minf(44.0, (size.x - 40.0) / n)
			var x0 := size.x / 2.0 - step * (n - 1) / 2.0
			for i in n:
				var kind: String = glyphs[i]
				var c: Color = accent
				if TileDefs.DEFS.has(kind):
					c = TileDefs.get_def(kind)["color"]
				draw_set_transform(Vector2(x0 + step * i, 78))
				HexTile.draw_glyph(self, kind, 15.0, c, 1.0)
				draw_set_transform(Vector2.ZERO)
		_text(Vector2(size.x / 2.0, 122), sub, 18, Color(1, 1, 1, 0.6), _font_sub)

	func _text(p: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, p + Vector2(-w / 2.0, font_size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, color)


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


## 스테이지 고르기: 육각형 StageDefs.count()개를 가로로. 고른 스테이지는 꽉 차고,
## 깬 스테이지는 아래에 CLEAR, 잠긴 스테이지는 회색 + LOCKED, 나머지는 최고 웨이브.
class StagePicker extends Control:
	signal stage_clicked(n: int)
	## 0 = 아무것도 아님
	signal hover_changed(n: int)

	const R := 42.0
	const GAP := 120.0
	const HEIGHT := 136.0

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
		_text(Vector2(size.x / 2.0, 6.0), Loc.t("STAGE"), 18, INK_DIM, _font)
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
			_text(pos + Vector2(0, 2), "%d" % n, 34, num_color, _font_big)
			var below := ""
			var bc := Color(c, 0.75)
			if not open:
				below = Loc.t("LOCKED")
			elif Meta.is_stage_cleared(n):
				below = Loc.t("CLEAR")
				bc = c
			elif Meta.stage_best_wave(n) > 0:
				below = Loc.t("BEST %d") % Meta.stage_best_wave(n)
			else:
				below = Loc.t("NEW")
			_text(pos + Vector2(0, R + 18.0), below, 15, bc, _font)

	func _text(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, pos + Vector2(-w / 2.0, font_size * 0.35), s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
