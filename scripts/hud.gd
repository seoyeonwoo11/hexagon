class_name Hud
extends CanvasLayer
## 화면 위 정보와 버튼 (기준 해상도 1920x1080).
## - 왼쪽 위: 웨이브, 돈, 코어 체력 바
## - 오른쪽 위: 일시정지/배속 버튼
## - 아래 가운데: "WAVE 3", "WAVE CLEAR" 같은 짧은 안내
## - 가운데: 일시정지/게임 오버 오버레이 (화면을 어둡게 덮음)
## 일시정지 중에도 동작해야 하므로 PROCESS_MODE_ALWAYS.
## 일시정지 중에는 화면 아무 데나 누르거나 PLAY 버튼으로 이어서 한다.
## 단축키: Space = 일시정지, F = 배속 전환, R = 게임 오버 후 재시작, F11 = 전체 화면.
## 터치(태블릿/웹): 모든 조작에 화면 버튼이 있다 (스킬, 옮기기, 정보 창 CLOSE, 전체 화면 FULL).
## 탭은 왼쪽 클릭으로 처리된다 (Godot의 터치 → 마우스 흉내).

signal pause_pressed
signal speed_pressed
signal restart_pressed
signal option_chosen(index: int)
signal upgrade_pressed
signal skill_pressed
signal move_pressed
signal endless_pressed
signal end_run_pressed
signal close_tile_pressed

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
var _stats_panel: StatsPanel
var _pause_button: Button
## 왼쪽 아래: 코어 스킬 버튼(+쿨다운 막대), 타일 옮기기 버튼
var _actions: VBoxContainer
var _skill_box: VBoxContainer
var _skill_button: Button
var _skill_bar: ProgressBar
var _skill_color := Color(0, 0, 0, 0)
var _move_button: Button
var _speed_button: Button
var _choice_overlay: ColorRect
var _choice_row: HBoxContainer
var _tile_panel: PanelContainer
var _tile_title: Label
var _tile_stats: Label
var _tile_gear: Label
var _tile_next: Label
var _upgrade_button: Button
## 위 가운데: 최종 보스 체력 막대
var _boss_box: VBoxContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _boss_color := Color(0, 0, 0, 0)
var _boss_name := ""
## 최종 보스 클리어 화면
var _victory: ColorRect
var _victory_sub: Label


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
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 6)
	root.add_child(info)
	_wave_label = _make_label(NEON_CYAN, 44, 800, 0.25)
	_money_label = _make_label(NEON_YELLOW, 30, 700)
	info.add_child(_wave_label)
	info.add_child(_money_label)
	var core_row := HBoxContainer.new()
	core_row.add_theme_constant_override("separation", 14)
	info.add_child(core_row)
	_core_label = _make_label(NEON_PINK, 24, 700)
	_core_label.text = "CORE"
	_core_bar = _make_bar(NEON_PINK)
	core_row.add_child(_core_label)
	core_row.add_child(_core_bar)

	# 오른쪽 위 버튼
	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	_pause_button = _make_button("PAUSE", pause_pressed)
	_speed_button = _make_button("1x", speed_pressed)
	if wants_fullscreen_button():
		buttons.add_child(make_fullscreen_button())
	buttons.add_child(SoundPanel.make_button())
	buttons.add_child(_pause_button)
	buttons.add_child(_speed_button)

	# 아래 가운데 안내 문구
	_banner_label = _make_label(Color.WHITE, 56, 900, 0.3)
	_banner_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.visible = false
	root.add_child(_banner_label)

	_build_boss_bar(root)
	_build_tile_panel(root)
	_build_actions(root)
	_build_choice_overlay()

	# 가운데 오버레이
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 일시정지 화면은 아무 데나 누르면(탭) 이어서 한다. 키보드가 없는 모바일용.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	_overlay.visible = false
	add_child(_overlay)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	_overlay.add_child(center)
	_overlay_title = _make_label(NEON_CYAN, 96, 900, 0.35)
	_overlay_sub = _make_label(Color(1, 1, 1, 0.85), 28, 500)
	for l in [_overlay_title, _overlay_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(l)
	# 일시정지 때만: 타일별 웨이브 피해 표
	_stats_panel = StatsPanel.new()
	_stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_panel.visible = false
	center.add_child(_stats_panel)
	# 오른쪽 위 버튼(PAUSE/PLAY, 배속)은 어두운 일시정지 화면 위에 그려서 밝게 보이게 한다.
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		top.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(top)
	buttons.reparent(top, false)
	_build_victory()


func set_money(value: int) -> void:
	_money_label.text = "$ %d" % value


## 목표(FINAL_WAVE)까지는 "WAVE 12 / 30", 무한 모드에서는 "WAVE 31  ENDLESS".
func set_wave(value: int, endless := false) -> void:
	if endless:
		_wave_label.text = "WAVE %d  ENDLESS" % value
	else:
		_wave_label.text = "WAVE %d / %d" % [value, EnemyDefs.FINAL_WAVE]


func _build_boss_bar(root: MarginContainer) -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_theme_constant_override("separation", 8)
	_boss_box.visible = false
	root.add_child(_boss_box)


func show_boss_bar(boss_name: String, color: Color) -> void:
	if not color.is_equal_approx(_boss_color):
		_boss_color = color
		for c in _boss_box.get_children():
			c.queue_free()
		_boss_label = _make_label(color, 30, 800, 0.25)
		_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_box.add_child(_boss_label)
		_boss_bar = _make_bar(color)
		_boss_bar.custom_minimum_size = Vector2(720, 18)
		_boss_box.add_child(_boss_bar)
	_boss_name = boss_name
	_boss_label.text = boss_name
	_boss_box.visible = true


## enraged: 체력 절반 아래 (이름 옆에 ENRAGED)
func set_boss_hp(hp: float, max_hp: float, enraged := false) -> void:
	if _boss_bar == null:
		return
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	_boss_label.text = "%s  -  ENRAGED" % _boss_name if enraged else _boss_name


func hide_boss_bar() -> void:
	_boss_box.visible = false


func is_boss_bar_visible() -> bool:
	return _boss_box.visible


func _build_victory() -> void:
	var gold := EnemyDefs.get_def("overlord")["color"] as Color
	_victory = ColorRect.new()
	_victory.color = Color(0, 0, 0, 0.75)
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.mouse_filter = Control.MOUSE_FILTER_STOP
	_victory.visible = false
	add_child(_victory)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 22)
	_victory.add_child(center)
	var tag := _make_label(Color(gold, 0.75), 26, 600)
	tag.text = "OVERLORD DEFEATED"
	var title := _make_label(gold, 120, 900, 0.4)
	title.text = "VICTORY"
	_victory_sub = _make_label(Color(1, 1, 1, 0.9), 30, 500)
	_victory_sub.label_settings.line_spacing = 10
	for l in [tag, title, _victory_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	center.add_child(row)
	var endless := make_neon_button("CONTINUE  ENDLESS", gold)
	endless.custom_minimum_size = Vector2(380, 72)
	endless.add_theme_font_size_override("font_size", 26)
	endless.tooltip_text = "Keep this run going. Every wave after %d adds shards." \
			% EnemyDefs.FINAL_WAVE
	endless.pressed.connect(func() -> void: endless_pressed.emit())
	var end := make_neon_button("END RUN", NEON_CYAN)
	end.custom_minimum_size = Vector2(300, 72)
	end.add_theme_font_size_override("font_size", 26)
	end.pressed.connect(func() -> void: end_run_pressed.emit())
	row.add_child(endless)
	row.add_child(end)


## 최종 보스 클리어 화면. shards: 이번에 받은 SHARD, clears: 지금까지 클리어 횟수.
func show_victory(wave: int, shards: int, clears: int) -> void:
	_victory_sub.text = "All %d waves cleared   -   +%d shards\nClears  %d" % [wave, shards, clears]
	_victory.visible = true


func hide_victory() -> void:
	_victory.visible = false


func is_victory_visible() -> bool:
	return _victory.visible


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
## stats를 주면 아래에 타일별 웨이브 피해 표를 같이 보여 준다 (일시정지).
func show_overlay(title: String, subtitle: String, color := NEON_CYAN,
		stats: DamageStats = null) -> void:
	_overlay_title.text = title
	_overlay_sub.text = subtitle
	_set_label_color(_overlay_title, color)
	_stats_panel.visible = stats != null
	if stats != null:
		_stats_panel.show_stats(stats)
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func is_overlay_visible() -> bool:
	return _overlay.visible


## 일시정지 화면 안내 문구: 터치 화면이면 탭, 아니면 Space/클릭.
static func resume_hint() -> String:
	if DisplayServer.is_touchscreen_available():
		return "TAP TO RESUME"
	return "SPACE OR CLICK TO RESUME"


func _on_overlay_input(event: InputEvent) -> void:
	# 탭은 Godot가 왼쪽 클릭으로 바꿔 준다 (터치 → 마우스 흉내).
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_overlay.accept_event()
		pause_pressed.emit()


## 웨이브 클리어 카드 3장. options의 각 항목: {title, desc, color, ...}
func show_choices(options: Array) -> void:
	for child in _choice_row.get_children():
		child.queue_free()
	for i in options.size():
		_choice_row.add_child(_make_card(options[i], i))
	_choice_overlay.visible = true


func hide_choices() -> void:
	_choice_overlay.visible = false


func is_choosing() -> bool:
	return _choice_overlay.visible


## 선택한 타일 정보 창. tile이 null이면 숨긴다.
func show_tile_panel(tile: HexTile, money: int) -> void:
	if tile == null or not is_instance_valid(tile):
		_tile_panel.visible = false
		return
	_tile_panel.visible = true
	_tile_title.text = "%s  LV %d" % [tile.display_name, tile.level]
	_set_label_color(_tile_title, tile.color)
	var lines: Array[String] = []
	if tile.attack != "none":
		lines.append("DMG %.1f    RANGE %d" % [tile.damage(), roundi(tile.effective_range())])
		if tile.attack == "orbit":
			lines.append("ORBS %d    HIT EVERY %.2f S" % [tile.orb_count(), tile.interval()])
		else:
			lines.append("RATE %.1f / S" % (1.0 / tile.interval()))
	if tile.haste > 0.0:
		lines.append("ADJACENT TILES +%d%% SPEED" % roundi(tile.haste * 100.0))
	elif tile.attack != "none" and tile.haste_bonus() > 0.0:
		lines.append("BOOSTED +%d%% SPEED" % roundi(tile.haste_bonus() * 100.0))
	if tile.income > 0:
		lines.append("INCOME $%d / WAVE" % tile.income)
		lines.append("INTEREST %d%% OF YOUR $ (MAX $%d)" % [
				roundi((Game.BANK_INTEREST + Game.BANK_INTEREST_STEP * (tile.level - 1)) * 100.0),
				tile.income * Game.BANK_INTEREST_CAP])
	if tile.attack == "laser" and tile.target_count() > 1:
		lines.append("BEAMS %d" % tile.target_count())
	if tile.beam:
		lines.append("LOCK-ON BEAM")
	if tile.focus_max > 0:
		lines.append("FOCUS +%d%% / HIT (MAX x%.1f)" % [roundi(tile.focus_step * 100.0),
				1.0 + tile.focus_step * tile.focus_max])
	if tile.attack == "spark":
		lines.append("BOUNCES %d" % tile.bounces)
	if tile.attack == "drone":
		lines.append("DRONES %d" % tile.drone_count())
	if tile.pack_bonus > 0.0:
		lines.append("PACK %d ARCHERS (+%d%% DMG)" % [tile.linked_archers(),
				roundi(tile.pack_bonus * tile.linked_archers() * 100.0)])
	if tile.attack == "frost":
		lines.append("SLOW %d%%" % roundi((1.0 - tile.frost_slow) * 100.0))
	if tile.attack == "burn":
		if tile.target_count() > 1:
			lines.append("FLAMES %d" % tile.target_count())
		lines.append("BURN %.1f / S FOR %.1f S" % [tile.damage() * FlameJet.BURN_DPS_RATIO, tile.burn_time])
		lines.append("FIRE SPREADS ON TOUCH (%d%%)" % roundi(FlameJet.SPREAD_RATIO * 100.0))
	lines.append("HP %d / %d" % [ceili(tile.hp), ceili(tile.max_hp)])
	_tile_stats.text = "\n".join(lines)
	if not tile.gears.is_empty():
		var lines_g: Array[String] = []
		for id in tile.gears:
			lines_g.append("GEAR  %s" % GearDefs.get_def(id)["name"])
		if tile.gears.size() < tile.gear_slots():
			lines_g.append("GEAR  EMPTY SLOT")
		_tile_gear.text = "\n".join(lines_g)
		_set_label_color(_tile_gear, GearDefs.get_def(tile.gears[-1])["color"])
		_tile_gear.visible = true
	else:
		_tile_gear.visible = false
	_tile_next.text = "NEXT LEVEL\n" + "\n".join(tile.upgrade_preview())
	var cost := tile.upgrade_cost()
	_upgrade_button.text = "UPGRADE  $%d" % cost
	_upgrade_button.disabled = money < cost


func _build_actions(root: MarginContainer) -> void:
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_actions.size_flags_vertical = Control.SIZE_SHRINK_END
	_actions.add_theme_constant_override("separation", 14)
	root.add_child(_actions)
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 6)
	_actions.add_child(_skill_box)
	_move_button = make_neon_button("MOVE", Color.WHITE)
	_move_button.custom_minimum_size = Vector2(300, 52)
	_move_button.tooltip_text = "Move or swap one tile per wave. Right-click cancels."
	_move_button.pressed.connect(func() -> void: move_pressed.emit())
	_actions.add_child(_move_button)


## 코어 스킬 버튼. cooldown이 0이면 쓸 수 있음, active면 지속 중.
func set_skill(skill_name: String, color: Color, cooldown: float, max_cooldown: float,
		active: bool) -> void:
	if _skill_box == null:
		return
	if not color.is_equal_approx(_skill_color):
		# 코어 색이 바뀌면 버튼과 막대를 그 색으로 새로 만든다
		_skill_color = color
		for c in _skill_box.get_children():
			c.queue_free()
		_skill_button = make_neon_button(skill_name, color)
		_skill_button.custom_minimum_size = Vector2(300, 60)
		_skill_button.add_theme_font_size_override("font_size", 24)
		_skill_button.pressed.connect(func() -> void: skill_pressed.emit())
		_skill_box.add_child(_skill_button)
		_skill_bar = _make_bar(color)
		_skill_bar.custom_minimum_size = Vector2(300, 8)
		_skill_box.add_child(_skill_bar)
	if active:
		_skill_button.text = "%s  ON" % skill_name
	elif cooldown > 0.0:
		_skill_button.text = "%s  %ds" % [skill_name, ceili(cooldown)]
	else:
		_skill_button.text = "%s  [Q]" % skill_name
	_skill_button.disabled = cooldown > 0.0 and not active
	_skill_bar.max_value = max_cooldown
	_skill_bar.value = max_cooldown - cooldown


## 타일 옮기기 버튼. charges: 이번 웨이브에 남은 횟수, active: 옮기기 모드 중.
func set_move(charges: int, active: bool) -> void:
	if _move_button == null:
		return
	if active:
		_move_button.text = "CANCEL MOVE  [M]"
	else:
		_move_button.text = "MOVE TILE  %d  [M]" % charges
	_move_button.disabled = charges <= 0 and not active


func _build_tile_panel(root: MarginContainer) -> void:
	_tile_panel = PanelContainer.new()
	_tile_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_tile_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_tile_panel.custom_minimum_size = Vector2(340, 0)
	_tile_panel.add_theme_stylebox_override("panel", _neon_box(NEON_CYAN, 0.75, 18))
	_tile_panel.visible = false
	root.add_child(_tile_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_tile_panel.add_child(box)
	_tile_title = _make_label(NEON_CYAN, 30, 800)
	_tile_stats = _make_label(Color(1, 1, 1, 0.85), 20, 500)
	_tile_gear = _make_label(Color.WHITE, 20, 700)
	_tile_next = _make_label(Color(0.45, 1.0, 0.5), 18, 600)
	var close := make_neon_button("CLOSE", Color(1, 1, 1, 0.7))
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(func() -> void: close_tile_pressed.emit())
	_upgrade_button = _make_button("UPGRADE", upgrade_pressed)
	_upgrade_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	var disabled := _neon_box(Color(1, 1, 1, 0.3), 0.6, 0)
	_upgrade_button.add_theme_stylebox_override("disabled", disabled)
	_upgrade_button.custom_minimum_size = Vector2(0, 64)
	for c in [_tile_title, _tile_stats, _tile_gear, _tile_next, _upgrade_button, close]:
		box.add_child(c)


func _build_choice_overlay() -> void:
	_choice_overlay = ColorRect.new()
	_choice_overlay.color = Color(0, 0, 0, 0.55)
	_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_overlay.visible = false
	add_child(_choice_overlay)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 36)
	_choice_overlay.add_child(center)
	var title := _make_label(Color.WHITE, 44, 800, 0.25)
	title.text = "CHOOSE ONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 32)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_choice_row)


func _make_card(option: Dictionary, index: int) -> Button:
	var color: Color = option["color"]
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(340, 260)
	card.add_theme_stylebox_override("normal", _neon_box(color, 0.85, 12))
	var hover := _neon_box(color, 0.85, 24)
	hover.bg_color = Color(color, 0.14)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.pressed.connect(func() -> void: option_chosen.emit(index))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_right = -28
	box.offset_top = 28
	box.offset_bottom = -28
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var tag := _make_label(Color(color, 0.7), 16, 600)
	tag.text = option.get("tag", "")
	var title := _make_label(color, 34, 800, 0.2)
	title.text = option["title"]
	var desc := _make_label(Color(1, 1, 1, 0.85), 19, 500)
	desc.text = option["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(284, 0)
	for c in [tag, title, desc]:
		box.add_child(c)
	return card


func _neon_box(color: Color, bg_alpha: float, glow: int) -> StyleBoxFlat:
	return neon_box(color, bg_alpha, glow)


static func neon_box(color: Color, bg_alpha: float, glow: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, bg_alpha)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(color, 0.3)
	box.shadow_size = glow
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box


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
		KEY_Q:
			skill_pressed.emit()
		KEY_M:
			move_pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


## 전체 화면 버튼을 보여 줄지: 웹(브라우저)이거나 터치 화면이면.
static func wants_fullscreen_button() -> bool:
	return OS.has_feature("web") or DisplayServer.is_touchscreen_available()


## FULL 버튼 (F11과 같음). 브라우저에서는 주소창을 없애 태블릿 화면을 넓게 쓴다.
static func make_fullscreen_button() -> Button:
	var b := make_neon_button("FULL", NEON_CYAN)
	b.custom_minimum_size = Vector2(130, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(toggle_fullscreen)
	return b


func _toggle_fullscreen() -> void:
	toggle_fullscreen()


static func toggle_fullscreen() -> void:
	var w := (Engine.get_main_loop() as SceneTree).root
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


## glow: 글자 뒤 빛 번짐의 세기 (0이면 없음). 작은 글자에 번짐을 주면 뿌옇게 보이므로
## 큰 제목에만 약하게 쓴다.
func _make_label(color: Color, font_size: int, weight: int, glow: float = 0.0) -> Label:
	return make_label(color, font_size, weight, glow)


static func make_label(color: Color, font_size: int, weight: int, glow: float = 0.0) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font = font_weight(weight)
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_color = Color(color, glow)
	settings.shadow_size = 6 if glow > 0.0 else 0
	settings.shadow_offset = Vector2.ZERO
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _set_label_color(label: Label, color: Color) -> void:
	var glow := label.label_settings.shadow_color.a
	label.label_settings.font_color = color
	label.label_settings.shadow_color = Color(color, glow)


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
	fill.shadow_color = Color(color, 0.3)
	fill.shadow_size = 4
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


## 다른 화면(Shop)에서도 쓰는 네온 버튼. 비활성 상태는 흐리게.
static func make_neon_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font_weight(700))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.6)
	normal.border_color = color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(color, 0.35)
	normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color, 0.15)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(1, 1, 1, 0.25)
	disabled.shadow_size = 0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	return button
