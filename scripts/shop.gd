class_name Shop
extends CanvasLayer
## 시작 화면 겸 상점. 게임을 켤 때와 판이 끝났을 때 나온다.
## SHARD로 영구 강화(Meta.UPGRADES)와 타일(Meta.TILE_PRICES)을 사고 START로 판을 시작한다.

signal start_pressed

const SHARD_COLOR := Color(0.55, 1.0, 0.75)
const DIM := Color(1, 1, 1, 0.35)

var _root: ColorRect
var _result_label: Label
var _shards_label: Label
var _upgrade_list: VBoxContainer
var _tile_list: VBoxContainer


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.88)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	_root.add_child(col)

	var title := _label(Hud.NEON_CYAN, 88, 900, 0.35)
	title.text = "HEXAGON"
	_result_label = _label(Hud.NEON_PINK, 26, 700)
	_shards_label = _label(SHARD_COLOR, 36, 800, 0.2)
	for l in [title, _result_label, _shards_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 48)
	col.add_child(columns)
	_upgrade_list = _section(columns, "UPGRADES")
	_tile_list = _section(columns, "TILES")

	var start := Hud.make_neon_button("START", Hud.NEON_CYAN)
	start.custom_minimum_size = Vector2(320, 76)
	start.add_theme_font_size_override("font_size", 32)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func() -> void: start_pressed.emit())
	col.add_child(start)
	var hint := _label(DIM, 16, 500)
	hint.text = "ENTER TO START"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	refresh()


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func refresh() -> void:
	if _shards_label == null:
		return
	_shards_label.text = "SHARDS  %d" % Meta.shards
	if Meta.last_run_wave > 0:
		_result_label.text = "RUN OVER  -  REACHED WAVE %d  -  +%d SHARDS" \
				% [Meta.last_run_wave, Meta.last_run_shards]
	elif Meta.best_wave > 0:
		_result_label.text = "BEST WAVE  %d" % Meta.best_wave
	else:
		_result_label.text = "SURVIVE WAVES TO EARN SHARDS"
	for child in _upgrade_list.get_children():
		child.queue_free()
	for child in _tile_list.get_children():
		child.queue_free()
	for u in Meta.UPGRADES:
		_upgrade_list.add_child(_upgrade_row(u))
	for kind in TileDefs.PLACEABLE:
		_tile_list.add_child(_tile_row(kind))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		start_pressed.emit()


func _section(parent: Control, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	var h := _label(Color(1, 1, 1, 0.7), 20, 700)
	h.text = heading
	box.add_child(h)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	box.add_child(list)
	return list


func _upgrade_row(u: Dictionary) -> Control:
	var id: String = u["id"]
	var lv := Meta.level(id)
	var pips := "LV %d / %d" % [lv, u["max"]]
	var cost := Meta.upgrade_cost(id)
	var button_text := "MAX" if cost < 0 else "%d" % cost
	var can_buy := cost >= 0 and Meta.shards >= cost
	return _row(u["color"], u["title"], "%s   %s" % [u["desc"], pips],
			button_text, can_buy, func() -> void:
				if Meta.buy_upgrade(id):
					refresh())


func _tile_row(kind: String) -> Control:
	var def := TileDefs.get_def(kind)
	if Meta.is_tile_unlocked(kind):
		return _row(def["color"], def["name"], def["desc"], "OWNED", false, Callable())
	var price: int = Meta.TILE_PRICES[kind]
	return _row(def["color"], def["name"], def["desc"], "%d" % price, Meta.shards >= price,
			func() -> void:
				if Meta.buy_tile(kind):
					refresh())


func _row(color: Color, title: String, desc: String, button_text: String, enabled: bool,
		on_buy: Callable) -> Control:
	var panel := PanelContainer.new()
	var box := Hud.neon_box(color, 0.7, 6)
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.content_margin_left = 18
	box.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(560, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var t := _label(color, 24, 800)
	t.text = title
	var d := _label(Color(1, 1, 1, 0.8), 16, 500)
	d.text = desc
	text.add_child(t)
	text.add_child(d)
	var b := Hud.make_neon_button(button_text, SHARD_COLOR)
	b.custom_minimum_size = Vector2(120, 52)
	b.disabled = not enabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if on_buy.is_valid():
		b.pressed.connect(on_buy)
	row.add_child(b)
	return panel


func _label(color: Color, size: int, weight: int, glow := 0.0) -> Label:
	return Hud.make_label(color, size, weight, glow)
