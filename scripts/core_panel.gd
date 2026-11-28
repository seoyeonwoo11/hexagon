class_name CorePanel
extends CanvasLayer
## 코어 고르기 창: 시작 화면 벌집 한가운데 코어를 누르면 연다.
## 산 코어는 누르면 고르고, 안 산 코어는 상점 창의 코어 탭으로 넘어간다.
## Esc, Enter, 오른쪽 클릭, 빈 곳 클릭, 닫기 버튼으로 닫는다.

## 안 산 코어를 눌렀을 때 (상점 창을 연다)
signal shop_requested
signal closed

var _picker: Shop.CorePicker
var _desc: Label


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
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
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 36
	style.content_margin_bottom = 44
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	box.add_child(col)

	var title := Hud.make_label(Hud.NEON_CYAN, 44, 900, 0.3)
	title.text = Loc.t("CORES")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_picker = Shop.CorePicker.new()
	_picker.name = "PanelCorePicker"
	_picker.r = 58.0
	_picker.gap = 150.0
	_picker.show_names = true
	_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker.core_clicked.connect(_on_core_clicked)
	col.add_child(_picker)

	_desc = Hud.make_label(Color(1, 1, 1, 0.75), 22, 500)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_desc)

	var done := Hud.make_neon_button(Loc.t("CLOSE"), Hud.NEON_PINK)
	done.custom_minimum_size = Vector2(320, 70)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 26)
	done.pressed.connect(close)
	col.add_child(done)


## 산 코어는 고르고, 안 산 코어는 상점 창으로.
func _on_core_clicked(id: String) -> void:
	if not Meta.is_core_unlocked(id):
		close()
		shop_requested.emit()
		return
	var changed := Meta.select_core(id)
	Sfx.play("click" if changed else "deny")
	refresh()


func refresh() -> void:
	if _desc == null:
		return
	_desc.text = Loc.t(CoreDefs.get_def(Meta.core_type)["desc"])
	_picker.queue_redraw()


func open() -> void:
	refresh()
	visible = true
	Sfx.play("click")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		close()
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close()
