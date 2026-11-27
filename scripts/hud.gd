class_name Hud
extends CanvasLayer
## 화면 위 정보와 버튼 (기준 해상도 1920x1080).
## - 왼쪽 위: 웨이브, 돈, 코어 체력 바
## - 오른쪽 위: 일시정지/배속 버튼
## - 아래 가운데: "WAVE 3", "WAVE CLEAR" 같은 짧은 안내
## - 가운데: 일시정지/게임 오버 오버레이 (화면을 어둡게 덮음)
## 일시정지 중에도 동작해야 하므로 PROCESS_MODE_ALWAYS.
## 단축키: Space = 일시정지, F = 배속 전환, R = 게임 오버 후 재시작, F11 = 전체 화면.

signal pause_pressed
signal speed_pressed
signal restart_pressed

const NEON_CYAN := Color(0.0, 0.95, 1.0)
const NEON_PINK := Color(1.0, 0.2, 0.8)
const NEON_YELLOW := Color(1.0, 0.85, 0.1)
const MARGIN := 40
const FONT := preload("res://assets/fonts/Orbitron.ttf")

var _money_label: Label
var _wave_label: Label
var _core_label: Label
var _core_bar: ProgressBar
var _banner_label: Label
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_sub: Label
var _pause_button: Button
var _speed_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(root)

	# 왼쪽 위 정보
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.add_theme_constant_override("separation", 6)
	root.add_child(info)
	_wave_label = _make_label(NEON_CYAN, 44, 800)
	_money_label = _make_label(NEON_YELLOW, 28, 600)
	info.add_child(_wave_label)
	info.add_child(_money_label)
	var core_row := HBoxContainer.new()
	core_row.add_theme_constant_override("separation", 14)
	info.add_child(core_row)
	_core_label = _make_label(NEON_PINK, 22, 600)
	_core_label.text = "CORE"
	_core_bar = _make_bar(NEON_PINK)
	core_row.add_child(_core_label)
	core_row.add_child(_core_bar)

	# 오른쪽 위 버튼
	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	_pause_button = _make_button("PAUSE", pause_pressed)
	_speed_button = _make_button("1x", speed_pressed)
	buttons.add_child(_pause_button)
	buttons.add_child(_speed_button)

	# 아래 가운데 안내 문구
	_banner_label = _make_label(Color.WHITE, 56, 900)
	_banner_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.visible = false
	root.add_child(_banner_label)

	# 가운데 오버레이
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	_overlay.add_child(center)
	_overlay_title = _make_label(NEON_CYAN, 96, 900)
	_overlay_sub = _make_label(Color(1, 1, 1, 0.85), 28, 500)
	for l in [_overlay_title, _overlay_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(l)


func set_money(value: int) -> void:
	_money_label.text = "$ %d" % value


func set_wave(value: int) -> void:
	_wave_label.text = "WAVE %d" % value


func set_core(hp: float, max_hp: float) -> void:
	_core_bar.max_value = max_hp
	_core_bar.value = hp


func set_paused(paused: bool) -> void:
	_pause_button.text = "PLAY" if paused else "PAUSE"


func set_speed(multiplier: float) -> void:
	_speed_button.text = "%dx" % int(multiplier)


## 아래쪽 짧은 안내 ("WAVE 3", "WAVE CLEAR" 등).
func show_banner(text: String, color := Color.WHITE) -> void:
	_banner_label.text = text
	_set_label_color(_banner_label, color)
	_banner_label.visible = true


func hide_banner() -> void:
	_banner_label.visible = false


## 화면 가운데 큰 오버레이 (일시정지, 게임 오버).
func show_overlay(title: String, subtitle: String, color := NEON_CYAN) -> void:
	_overlay_title.text = title
	_overlay_sub.text = subtitle
	_set_label_color(_overlay_title, color)
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			pause_pressed.emit()
		KEY_F:
			speed_pressed.emit()
		KEY_R:
			restart_pressed.emit()
		KEY_F11:
			_toggle_fullscreen()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_MAXIMIZED
	else:
		w.mode = Window.MODE_FULLSCREEN


static func font_weight(weight: int) -> Font:
	var f := FontVariation.new()
	f.base_font = FONT
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	f.variation_opentype = {tag: weight}
	return f


func _make_label(color: Color, font_size: int, weight: int) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font = font_weight(weight)
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_color = Color(color, 0.45)
	settings.shadow_size = 10
	settings.shadow_offset = Vector2.ZERO
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _set_label_color(label: Label, color: Color) -> void:
	label.label_settings.font_color = color
	label.label_settings.shadow_color = Color(color, 0.45)


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(color, 0.08)
	bg.border_color = Color(color, 0.6)
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.shadow_color = Color(color, 0.5)
	fill.shadow_size = 8
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_button(text: String, sig: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 60)
	button.add_theme_font_override("font", font_weight(700))
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", NEON_CYAN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.6)
	normal.border_color = NEON_CYAN
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(NEON_CYAN, 0.35)
	normal.shadow_size = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(NEON_CYAN, 0.15)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: sig.emit())
	return button
