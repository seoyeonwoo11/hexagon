class_name ShopWindow
extends CanvasLayer
## 시작 화면(Shop) 버튼으로 여는 창. 두 묶음이 있다:
##   출전 준비 (prep): 가져갈 타일 넣고 빼기 (loadout), 코어 고르기 (core)
##   상점 (shop)     : SHARD로 영구 강화 (upgrades), 타일 (tiles), 코어 (cores) 사기
##
## 배치 (1920x1080 기준):
##   위    : 제목, 그 묶음의 탭, 가진 SHARD, 닫기 (Esc, 오른쪽 클릭)
##   가운데: 고른 탭의 카드들 (3칸씩). 카드마다 이름, 설명, 버튼
## 시작 화면 위에 덮어 그리고, 닫으면 시작 화면을 새로 그린다.

signal closed

const GROUPS := {"prep": ["loadout", "core"], "shop": ["upgrades", "tiles", "cores"]}
const GROUP_TITLES := {"prep": "PREPARE", "shop": "SHOP"}
const TAB_TITLES := {"loadout": "TILES TO BRING", "core": "CORE",
		"upgrades": "UPGRADES", "tiles": "TILES", "cores": "CORES"}
const W := 1920.0
## 카드 3장 + 간격 2개 = 1680 (양옆 여백 120)
const CARD := Vector2(541, 196)
const COLUMNS := 3
const GAP := 28

var tab := "upgrades"

var _shards: Label
var _title: Label
var _tab_buttons := {}
var _grid: GridContainer
var _hint: Label


func _init() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	# 1920 폭 판을 가운데에
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.offset_left = -W / 2.0
	frame.offset_right = W / 2.0
	frame.offset_bottom = 1080
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(frame)

	_title = Hud.make_label(Shop.SHARD_COLOR, 64, 900, 0.35)
	_title.position = Vector2(120, 56)
	frame.add_child(_title)

	var shard_box := HBoxContainer.new()
	shard_box.add_theme_constant_override("separation", 14)
	shard_box.alignment = BoxContainer.ALIGNMENT_END
	shard_box.position = Vector2(W - 120 - 700, 70)
	shard_box.size = Vector2(700, 60)
	frame.add_child(shard_box)
	_shards = Hud.make_label(Shop.SHARD_COLOR, 44, 900, 0.3)
	var unit := Hud.make_label(Color(Shop.SHARD_COLOR, 0.7), 22, 600)
	unit.text = Loc.t("shards")
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := Hud.make_neon_button(Loc.t("BACK  (ESC)"), Hud.NEON_CYAN)
	back.custom_minimum_size = Vector2(210, 60)
	back.pressed.connect(close)
	var space := Control.new()
	space.custom_minimum_size = Vector2(30, 0)
	for c in [_shards, unit, space, back]:
		shard_box.add_child(c)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	tabs.position = Vector2(120, 172)
	frame.add_child(tabs)
	for id in TAB_TITLES:
		var b := Hud.make_neon_button(Loc.t(TAB_TITLES[id]), Color.WHITE)
		b.custom_minimum_size = Vector2(250, 58)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			show_tab(id))
		tabs.add_child(b)
		_tab_buttons[id] = b
	var rule := ColorRect.new()
	rule.color = Shop.RULE
	rule.position = Vector2(120, 254)
	rule.size = Vector2(W - 240, 1)
	frame.add_child(rule)

	_hint = Hud.make_label(Shop.INK_DIM, 19, 500)
	_hint.position = Vector2(120, 272)
	frame.add_child(_hint)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	var grid_w := CARD.x * COLUMNS + GAP * (COLUMNS - 1)
	_grid.position = Vector2((W - grid_w) / 2.0, 330)
	frame.add_child(_grid)


func open(which := "") -> void:
	if which != "":
		tab = which
	visible = true
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play("click")
	closed.emit()


func is_open() -> bool:
	return visible


func show_tab(id: String) -> void:
	tab = id
	refresh()


## 지금 탭이 속한 묶음: "prep" 또는 "shop"
func group() -> String:
	return "prep" if GROUPS["prep"].has(tab) else "shop"


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


func refresh() -> void:
	if _grid == null:
		return
	_shards.text = "%d" % Meta.shards
	var g := group()
	_title.text = Loc.t(GROUP_TITLES[g])
	_title.label_settings.font_color = Shop.SHARD_COLOR if g == "shop" else Hud.NEON_CYAN
	_title.label_settings.shadow_color = Color(_title.label_settings.font_color, 0.35)
	for id in _tab_buttons:
		var b: Button = _tab_buttons[id]
		b.visible = GROUPS[g].has(id)
		var on: bool = id == tab
		b.add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.55))
		var box := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.border_color = Shop.SHARD_COLOR if on else Color(1, 1, 1, 0.25)
		box.bg_color = Color(Shop.SHARD_COLOR, 0.14) if on else Color(0, 0, 0, 0.6)
		box.shadow_size = 8 if on else 0
		b.add_theme_stylebox_override("normal", box)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	match tab:
		"loadout":
			_hint.text = Loc.t("Pick up to %d tiles to bring. Only these show up as cards.") % Meta.max_loadout() \
					+ "   %d / %d" % [Meta.loadout.size(), Meta.max_loadout()]
			for kind in TileDefs.PLACEABLE:
				_grid.add_child(_loadout_card(kind))
		"core":
			_hint.text = Loc.t("Each core has its own skill. Press Q in a run to use it.")
			for id in CoreDefs.ORDER:
				_grid.add_child(_core_pick_card(id))
		"upgrades":
			_hint.text = Loc.t("Permanent upgrades apply to every run. Clearing a stage for the first time raises every limit by %d.") \
					% Meta.CAP_PER_STAGE
			for u in Meta.UPGRADES:
				_grid.add_child(_upgrade_card(u))
		"tiles":
			_hint.text = Loc.t("Bought tiles can be added to your loadout on the start screen.")
			for kind in TileDefs.PLACEABLE:
				if Meta.TILE_PRICES.has(kind):
					_grid.add_child(_tile_card(kind))
		"cores":
			_hint.text = Loc.t("Pick the core for your run on the start screen. Each core has its own skill (Q).")
			for id in CoreDefs.ORDER:
				if CoreDefs.get_def(id)["price"] > 0:
					_grid.add_child(_core_card(id))


# ---------------------------------------------------------------- 카드

## 카드 틀: 테두리 색 color, 왼쪽에 아이콘(있으면), 오른쪽에 글. 아래 줄에 버튼.
func _card(color: Color, dim: bool) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD
	var style := Hud.neon_box(Color(color, 0.45 if dim else 0.9), 0.9, 0 if dim else 6)
	style.bg_color = Color(color.darkened(0.85), 0.9) if not dim else Color(0.03, 0.03, 0.04, 0.9)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return [panel, col]


func _title_row(text: String, color: Color, right: String, glyph := "", glyph_color := Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	if glyph != "":
		var icon := Glyph.new()
		icon.kind = glyph
		icon.color = glyph_color
		row.add_child(icon)
	var name := Hud.make_label(color, 26, 800)
	name.text = text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	if right != "":
		var r := Hud.make_label(Shop.INK_DIM, 18, 600)
		r.text = right
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return row


func _desc(text: String, dim: bool) -> Label:
	var d := Hud.make_label(Shop.INK_DIM if dim else Shop.INK, 18, 500)
	d.text = text
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(CARD.x - 48, 0)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return d


func _buy_button(text: String, enabled: bool, color := Shop.SHARD_COLOR) -> Button:
	var b := Hud.make_neon_button(text, color)
	b.custom_minimum_size = Vector2(0, 50)
	b.disabled = not enabled
	return b


func _upgrade_card(u: Dictionary) -> Control:
	var id: String = u["id"]
	var open := Meta.is_upgrade_unlocked(id)
	var color: Color = u["color"] if open else Shop.LOCKED_COLOR
	var parts := _card(color, not open)
	var col: VBoxContainer = parts[1]
	var lv := Meta.level(id)
	var cap := Meta.upgrade_max(id)
	col.add_child(_title_row(u["title"], color, "LV %d / %d" % [lv, cap] if open else ""))
	col.add_child(_desc(Loc.t(u["desc"]), not open))
	if open:
		var pips := Shop.LevelPips.new()
		pips.level = lv
		pips.max_level = cap
		pips.color = color
		col.add_child(pips)
	var cost := Meta.upgrade_cost(id)
	var b: Button
	if not open:
		b = _buy_button(Loc.t("Clear %s to unlock.") % StageDefs.title(StageDefs.stage_for_unlock(u["unlock"])),
				false, Shop.LOCKED_COLOR)
	elif cost < 0:
		b = _buy_button(Loc.t("Maxed"), false)
		b.tooltip_text = Loc.t("Clear a new stage to raise the limit.")
	else:
		b = _buy_button(Loc.t("UPGRADE   %d shards") % cost, Meta.shards >= cost)
	b.pressed.connect(func() -> void:
		Sfx.play("coin" if Meta.buy_upgrade(id) else "deny")
		refresh())
	col.add_child(b)
	return parts[0]


func _tile_card(kind: String) -> Control:
	var def := TileDefs.get_def(kind)
	var owned := Meta.is_tile_unlocked(kind)
	var price: int = Meta.TILE_PRICES[kind]
	var color: Color = def["color"]
	var parts := _card(color, false)
	var col: VBoxContainer = parts[1]
	col.add_child(_title_row(def["name"], color, "", kind, color))
	col.add_child(_desc(Loc.t(def["desc"]), false))
	var b := _buy_button(Loc.t("OWNED") if owned else Loc.t("BUY   %d shards") % price,
			not owned and Meta.shards >= price)
	b.pressed.connect(func() -> void:
		Sfx.play("coin" if Meta.buy_tile(kind) else "deny")
		refresh())
	col.add_child(b)
	return parts[0]


func _core_card(id: String) -> Control:
	var def := CoreDefs.get_def(id)
	var owned := Meta.is_core_unlocked(id)
	var available := Meta.is_core_available(id)
	var price: int = def["price"]
	var color: Color = def["color"] if available or owned else Shop.LOCKED_COLOR
	var parts := _card(color, not available and not owned)
	var col: VBoxContainer = parts[1]
	col.add_child(_title_row(def["name"], color, Loc.t("COOLDOWN %ds") % int(def["cooldown"]),
			"core_" + id, color))
	col.add_child(_desc(Loc.t(def["desc"]), not available and not owned))
	var b: Button
	if owned:
		b = _buy_button(Loc.t("OWNED"), false)
	elif not available:
		b = _buy_button(Loc.t("Clear %s to unlock.") % StageDefs.title(StageDefs.stage_for_unlock("core:" + id)),
				false, Shop.LOCKED_COLOR)
	else:
		b = _buy_button(Loc.t("BUY   %d shards") % price, Meta.shards >= price)
	b.pressed.connect(func() -> void:
		Sfx.play("coin" if Meta.buy_core(id) else "deny")
		refresh())
	col.add_child(b)
	return parts[0]


## 가져갈 타일 카드: 산 타일은 넣기/빼기, 안 산 타일은 상점의 타일 탭으로.
func _loadout_card(kind: String) -> Control:
	var def := TileDefs.get_def(kind)
	var owned := Meta.is_tile_unlocked(kind)
	var picked := Meta.in_loadout(kind)
	var color: Color = def["color"] if owned else Shop.LOCKED_COLOR
	var parts := _card(color, not picked)
	var col: VBoxContainer = parts[1]
	col.add_child(_title_row(def["name"], color, Loc.t("IN") if picked else "", kind, color))
	col.add_child(_desc(Loc.t(def["desc"]), not owned))
	var b: Button
	if not owned:
		b = _buy_button(Loc.t("Buy in the shop  (%d)") % Meta.TILE_PRICES[kind], true, Shop.SHARD_COLOR)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			show_tab("tiles"))
	elif picked:
		b = _buy_button(Loc.t("REMOVE"), Meta.loadout.size() > 1, Color.WHITE)
	else:
		b = _buy_button(Loc.t("BRING") if not Meta.loadout_full() else Loc.t("LOADOUT FULL"),
				not Meta.loadout_full(), Hud.NEON_CYAN)
	if owned:
		b.pressed.connect(func() -> void:
			Sfx.play("click" if Meta.toggle_loadout(kind) else "deny")
			refresh())
	col.add_child(b)
	return parts[0]


## 코어 고르기 카드: 산 코어는 고르기, 안 산 코어는 상점의 코어 탭으로.
func _core_pick_card(id: String) -> Control:
	var def := CoreDefs.get_def(id)
	var owned := Meta.is_core_unlocked(id)
	var picked := Meta.core_type == id
	var color: Color = def["color"] if owned or Meta.is_core_available(id) else Shop.LOCKED_COLOR
	var parts := _card(color, not picked)
	var col: VBoxContainer = parts[1]
	col.add_child(_title_row(def["name"], color, Loc.t("COOLDOWN %ds") % int(def["cooldown"]),
			"core" if id == "core" else "core_" + id, color))
	col.add_child(_desc(Loc.t(def["desc"]), not owned))
	var b: Button
	if picked:
		b = _buy_button(Loc.t("SELECTED"), false, Color.WHITE)
	elif owned:
		b = _buy_button(Loc.t("SELECT"), true, Hud.NEON_CYAN)
		b.pressed.connect(func() -> void:
			Sfx.play("click" if Meta.select_core(id) else "deny")
			refresh())
	elif not Meta.is_core_available(id):
		b = _buy_button(Loc.t("Clear %s to unlock.") % StageDefs.title(StageDefs.stage_for_unlock("core:" + id)),
				false, Shop.LOCKED_COLOR)
	else:
		b = _buy_button(Loc.t("Buy in the shop  (%d)") % def["price"], true, Shop.SHARD_COLOR)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			show_tab("cores"))
	col.add_child(b)
	return parts[0]


## 카드 제목 옆 작은 아이콘 (타일/코어 모양)
class Glyph extends Control:
	var kind := ""
	var color := Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(size / 2.0)
		HexTile.draw_glyph(self, kind, 15.0, color, 1.0)
		draw_set_transform(Vector2.ZERO)
