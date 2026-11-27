class_name SoundPanel
extends CanvasLayer
## 소리 설정 창: 배경음/효과음 볼륨 막대, 음소거, 닫기.
## 시작 화면과 게임 화면 오른쪽 위의 SOUND 버튼으로 연다 (N 키는 바로 음소거).
## 열려 있는 동안은 게임을 멈추고, 닫으면 원래 상태로 돌린다.

const COLOR := Hud.NEON_CYAN
const MUTED_COLOR := Hud.NEON_PINK

var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value: Label
var _sfx_value: Label
var _mute_button: Button
var _was_paused := false
var _syncing := false
## 창을 만든 때의 언어. 언어를 바꾸면(씬을 다시 불러와도 이 창은 남아 있음) 다음에 열 때 다시 만든다.
var _built_lang := ""


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var owner_sfx := get_parent() as Sfx
	if owner_sfx != null:
		owner_sfx.settings_changed.connect(_sync)
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	Loc.ensure_loaded()
	_built_lang = Loc.lang
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(center)
	var box := PanelContainer.new()
	var style := Hud.neon_box(COLOR, 0.92, 16)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 36
	style.content_margin_bottom = 36
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	box.add_child(col)
	var title := Hud.make_label(COLOR, 40, 800, 0.25)
	title.text = Loc.t("SOUND")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var music := _slider_row(Loc.t("MUSIC"), Sfx.music_volume)
	_music_slider = music[0]
	_music_value = music[1]
	col.add_child(music[2])
	var sfx := _slider_row(Loc.t("EFFECTS"), Sfx.sfx_volume)
	_sfx_slider = sfx[0]
	_sfx_value = sfx[1]
	col.add_child(sfx[2])
	_music_slider.value_changed.connect(func(v: float) -> void: _on_slider(true, v))
	_sfx_slider.value_changed.connect(func(v: float) -> void: _on_slider(false, v))
	_music_slider.drag_ended.connect(func(_c: bool) -> void: Sfx.save_settings())
	_sfx_slider.drag_ended.connect(func(_c: bool) -> void:
		Sfx.save_settings()
		Sfx.play("coin"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_mute_button = Hud.make_neon_button(Loc.t("MUTE"), MUTED_COLOR)
	_mute_button.custom_minimum_size = Vector2(240, 64)
	_mute_button.add_theme_font_size_override("font_size", 24)
	_mute_button.pressed.connect(func() -> void: Sfx.set_muted(not Sfx.muted))
	var close := Hud.make_neon_button(Loc.t("CLOSE"), COLOR)
	close.custom_minimum_size = Vector2(240, 64)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(close_panel)
	row.add_child(_mute_button)
	row.add_child(close)
	var hint := Hud.make_label(Color(1, 1, 1, 0.45), 18, 500)
	hint.text = Loc.t("N  -  MUTE / UNMUTE")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.visible = not DisplayServer.is_touchscreen_available()
	col.add_child(hint)
	_sync()


## [막대, 값 글자, 줄 전체]
func _slider_row(label_text: String, value: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var name_label := Hud.make_label(Color(1, 1, 1, 0.85), 24, 700)
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(value * 100.0)
	slider.custom_minimum_size = Vector2(420, 48)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	_style_slider(slider)
	var value_label := Hud.make_label(COLOR, 24, 700)
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	return [slider, value_label, row]


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(COLOR, 0.12)
	track.border_color = Color(COLOR, 0.5)
	track.set_border_width_all(2)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR
	fill.set_corner_radius_all(6)
	fill.shadow_color = Color(COLOR, 0.35)
	fill.shadow_size = 6
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _circle_texture(30, Color.WHITE)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)


static func _circle_texture(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c, clampf(r - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _on_slider(is_music: bool, v: float) -> void:
	if _syncing:
		return
	if is_music:
		Sfx.set_music_volume(v / 100.0, false)
	else:
		Sfx.set_sfx_volume(v / 100.0, false)
	_update_labels()


func _sync() -> void:
	if _music_slider == null:
		return
	_syncing = true
	_music_slider.value = roundf(Sfx.music_volume * 100.0)
	_sfx_slider.value = roundf(Sfx.sfx_volume * 100.0)
	_syncing = false
	_mute_button.text = Loc.t("UNMUTE") if Sfx.muted else Loc.t("MUTE")
	_update_labels()


func _update_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value)
	var dim := 0.35 if Sfx.muted else 1.0
	_music_slider.modulate.a = dim
	_sfx_slider.modulate.a = dim


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	if Loc.lang != _built_lang:
		_build()
	_sync()
	visible = true


func close_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func is_open() -> bool:
	return visible


func _on_bg_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close_panel()


## 열려 있는 동안은 게임 단축키(Space 등)가 밑에서 먹히지 않게 막는다.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close_panel()
	elif key.pressed and not key.echo and key.keycode == KEY_N:
		Sfx.set_muted(not Sfx.muted)
	get_viewport().set_input_as_handled()


## 게임 화면과 시작 화면 오른쪽 위에 다는 SOUND 버튼. 음소거면 MUTED로 바뀐다.
static func make_button() -> Button:
	var b := Hud.make_neon_button(Loc.t("SOUND"), COLOR)
	b.custom_minimum_size = Vector2(150, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(Sfx.open_panel)
	var sync := ButtonSync.new()
	sync.button = b
	b.add_child(sync)
	sync.refresh()
	return b


## SOUND 버튼 글자를 음소거 상태에 맞춘다. 버튼의 자식이라 버튼과 함께 사라지고, 신호 연결도 같이 풀린다.
class ButtonSync extends Node:
	var button: Button

	func _ready() -> void:
		var s := Sfx.instance()
		if s != null:
			s.settings_changed.connect(refresh)

	func refresh() -> void:
		button.text = Loc.t("MUTED") if Sfx.muted else Loc.t("SOUND")
		button.add_theme_color_override("font_color", MUTED_COLOR if Sfx.muted else COLOR)
