class_name SettingsPanel
extends CanvasLayer
## 설정 창: 시작 화면 오른쪽 위 설정 버튼으로 연다.
## 언어 (한국어 <-> ENGLISH, 누르면 씬을 다시 불러옴), 소리 (소리 설정 창), 전체 화면,
## 빛 번짐(글로우) 켜기/끄기 (Graphics), 닫기.
## Esc, 오른쪽 클릭, 빈 곳 클릭으로 닫는다.

const COLOR := Color(1, 1, 1, 0.85)

var _full: Button
var _glow: Button


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			close())
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(center)
	var box := PanelContainer.new()
	var style := Hud.neon_box(Hud.NEON_CYAN, 0.92, 16)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 36
	style.content_margin_bottom = 40
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	box.add_child(col)
	var title := Hud.make_label(Hud.NEON_CYAN, 44, 900, 0.3)
	title.text = Loc.t("SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(_gap(6))

	var lang := _button(Loc.other_lang_name(), COLOR)
	lang.name = "LanguageButton"
	lang.tooltip_text = "Language / 언어"
	lang.pressed.connect(func() -> void:
		var shop := get_parent() as Shop
		if shop != null:
			shop.switch_language())
	col.add_child(lang)

	var sound := _button(Loc.t("SOUND"), Hud.NEON_CYAN)
	sound.name = "SoundButton"
	sound.pressed.connect(func() -> void:
		close()
		Sfx.open_panel())
	col.add_child(sound)

	_full = _button("", COLOR)
	_full.name = "FullscreenButton"
	_full.pressed.connect(func() -> void:
		Hud.toggle_fullscreen()
		_sync())
	col.add_child(_full)

	_glow = _button("", COLOR)
	_glow.name = "GlowButton"
	_glow.tooltip_text = Loc.t("Screen-wide light bloom. Turning it off reduces lag.")
	_glow.pressed.connect(func() -> void:
		Graphics.set_glow(not Graphics.glow)
		_sync())
	col.add_child(_glow)

	col.add_child(_gap(6))
	var done := _button(Loc.t("CLOSE"), Hud.NEON_PINK)
	done.pressed.connect(close)
	col.add_child(done)


func _button(text: String, color: Color) -> Button:
	var b := Hud.make_neon_button(text, color)
	b.custom_minimum_size = Vector2(380, 64)
	b.add_theme_font_size_override("font_size", 24)
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _sync() -> void:
	if _glow != null:
		Graphics.load_settings()
		_glow.text = Loc.t("GLOW: ON") if Graphics.glow else Loc.t("GLOW: OFF")
	if _full == null:
		return
	var on := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	_full.text = Loc.t("WINDOWED") if on else Loc.t("FULLSCREEN")


func open() -> void:
	_sync()
	visible = true
	Sfx.play("click")


func close() -> void:
	if not visible:
		return
	visible = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close()
