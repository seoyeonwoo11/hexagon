class_name StartPanel
extends CanvasLayer
## 게임 시작 창: 시작 화면의 게임 시작 버튼(또는 Enter)으로 연다.
## 판에 쓸 코어를 고르고 시작한다. 안 산 코어를 누르면 상점 창의 코어 탭으로 넘어간다.
## Enter로 시작, Esc, 오른쪽 클릭, 빈 곳 클릭으로 닫는다.

signal start_pressed
## 안 산 코어를 눌렀을 때 (상점 창을 연다)
signal shop_requested

var _title: Label
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

	_title = Hud.make_label(Hud.NEON_CYAN, 44, 900, 0.3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_picker = Shop.CorePicker.new()
	_picker.name = "StartCorePicker"
	_picker.r = 58.0
	_picker.gap = 150.0
	_picker.show_names = true
	_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker.core_clicked.connect(_on_core_clicked)
	col.add_child(_picker)

	_desc = Hud.make_label(Color(1, 1, 1, 0.75), 22, 500)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_desc)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var back := Hud.make_neon_button(Loc.t("CLOSE"), Hud.NEON_PINK)
	back.custom_minimum_size = Vector2(220, 80)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(close)
	row.add_child(back)
	var go := Hud.make_neon_button(Loc.t("START"), Hud.NEON_CYAN)
	go.name = "GoButton"
	go.custom_minimum_size = Vector2(420, 80)
	go.add_theme_font_size_override("font_size", 34)
	go.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(go)


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
	if _title == null:
		return
	_title.text = StageDefs.title(Meta.stage)
	_title.label_settings.font_color = StageDefs.color(Meta.stage)
	_desc.text = Loc.t(CoreDefs.get_def(Meta.core_type)["desc"])
	_picker.queue_redraw()


func open() -> void:
	refresh()
	visible = true
	Sfx.play("click")


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			start_pressed.emit()
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close()
