class_name Hud
extends CanvasLayer
## 화면 위 정보(돈, 웨이브, 코어 체력)와 일시정지/배속 버튼.
## 일시정지 중에도 동작해야 하므로 PROCESS_MODE_ALWAYS.
## 단축키: Space = 일시정지, F = 배속 전환, R = 게임 오버 후 재시작.

signal pause_pressed
signal speed_pressed
signal restart_pressed

const NEON_CYAN := Color(0.0, 0.95, 1.0)
const NEON_PINK := Color(1.0, 0.2, 0.8)
const NEON_YELLOW := Color(1.0, 0.85, 0.1)

var _money_label: Label
var _wave_label: Label
var _core_label: Label
var _message_label: Label
var _pause_button: Button
var _speed_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var info := VBoxContainer.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_wave_label = _make_label(NEON_CYAN, 26)
	_money_label = _make_label(NEON_YELLOW, 22)
	_core_label = _make_label(NEON_PINK, 22)
	for l in [_wave_label, _money_label, _core_label]:
		info.add_child(l)

	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons.offset_right = -24
	buttons.offset_top = 16
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	_pause_button = _make_button("PAUSE", pause_pressed)
	_speed_button = _make_button("1x", speed_pressed)
	buttons.add_child(_pause_button)
	buttons.add_child(_speed_button)

	_message_label = _make_label(Color.WHITE, 48)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.offset_top = 90
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)


func set_money(value: int) -> void:
	_money_label.text = "$ %d" % value


func set_wave(value: int) -> void:
	_wave_label.text = "WAVE %d" % value


func set_core(hp: float, max_hp: float) -> void:
	_core_label.text = "CORE %d / %d" % [ceili(hp), ceili(max_hp)]


func set_paused(paused: bool) -> void:
	_pause_button.text = "PLAY" if paused else "PAUSE"


func set_speed(multiplier: float) -> void:
	_speed_button.text = "%dx" % int(multiplier)


func show_message(text: String, color := Color.WHITE) -> void:
	_message_label.text = text
	_message_label.label_settings.font_color = color
	_message_label.visible = true


func hide_message() -> void:
	_message_label.visible = false


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
		_:
			return
	get_viewport().set_input_as_handled()


func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_color = Color(color, 0.5)
	settings.shadow_size = 8
	settings.shadow_offset = Vector2.ZERO
	label.label_settings = settings
	return label


func _make_button(text: String, sig: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", NEON_CYAN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.6)
	normal.border_color = NEON_CYAN
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(NEON_CYAN, 0.35)
	normal.shadow_size = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(NEON_CYAN, 0.15)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: sig.emit())
	return button
