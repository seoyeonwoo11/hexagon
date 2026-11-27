class_name ResultsScreen
extends CanvasLayer
## 판이 끝났을 때 (코어 파괴, 또는 클리어 뒤 END RUN) 시작 화면 전에 뜨는 결과창.
##
## 배치 (1920x1080 기준):
##   위    : 한 줄 설명 (CORE DESTROYED / OVERLORD DEFEATED) + 큰 제목 (GAME OVER / VICTORY)
##   가운데: 숫자 카드 5장 (도달 웨이브, 처치 수, 플레이 시간, 번 돈, 받은 SHARD)
##   아래  : 왼쪽 타일별 총 피해 순위 (막대 + 몫), 오른쪽 적 종류별 처치 수
##   맨 아래: RETRY (R, 바로 새 판), CONTINUE (Enter/Space, 시작 화면으로)
## 게임이 멈춘 채로 뜨므로 PROCESS_MODE_ALWAYS. 열릴 때 숫자가 0부터 차오른다.

signal continue_pressed
signal retry_pressed

const W := 1920.0
const H := 1080.0
const CONTENT_W := 1400.0
const LEFT := (W - CONTENT_W) / 2.0
const CARD_Y := 330.0
const CARD_H := 150.0
const CARD_GAP := 25.0
const LIST_Y := 545.0
const ROW_H := 42.0
const TILE_ROWS := 8
const KILL_ROWS := 8
const DAMAGE_W := 840.0
const KILLS_X := LEFT + DAMAGE_W + 60.0
const COUNT_UP := 0.9
const INK := Color(1, 1, 1, 0.88)
const DIM := Color(1, 1, 1, 0.45)
const RULE := Color(1, 1, 1, 0.1)
const GOLD_COLOR := Color(1.0, 0.85, 0.1)
const SHARD_COLOR := Color(0.55, 1.0, 0.75)
const LOSS_COLOR := Color(1.0, 0.2, 0.8)

## show_results에 넘긴 결과 (Game._run_results 참고)
var data := {}
## 숫자가 차오르는 정도 (0 -> 1)
var reveal := 1.0

var _bg: ColorRect
var _tag: Label
var _title: Label
var _body: _Body
var _retry: Button
var _continue: Button


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.9)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	# 1920x1080 판을 화면 가운데에 둔다 (화면이 더 넓으면 양옆이 빈다)
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -W / 2.0
	frame.offset_right = W / 2.0
	frame.offset_top = -H / 2.0
	frame.offset_bottom = H / 2.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(frame)

	_tag = Hud.make_label(INK, 26, 600)
	_title = Hud.make_label(INK, 116, 900, 0.4)
	for l in [_tag, _title]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 0)
		l.size = Vector2(W, 0)
		frame.add_child(l)
	_tag.position.y = 92
	_title.position.y = 128

	_body = _Body.new()
	_body.screen = self
	_body.size = Vector2(W, H)
	frame.add_child(_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	row.position = Vector2(0, 950)
	row.size = Vector2(W, 72)
	frame.add_child(row)
	_retry = Hud.make_neon_button("RETRY  (R)", Hud.NEON_PINK)
	_retry.custom_minimum_size = Vector2(300, 72)
	_retry.add_theme_font_size_override("font_size", 26)
	_retry.tooltip_text = "Start a new run right away with the same setup."
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_continue = Hud.make_neon_button("CONTINUE  (ENTER)", Hud.NEON_CYAN)
	_continue.custom_minimum_size = Vector2(380, 72)
	_continue.add_theme_font_size_override("font_size", 26)
	_continue.tooltip_text = "Go to the start screen to spend shards."
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	row.add_child(_retry)
	row.add_child(_continue)


## 결과창을 연다. d의 키:
##   victory (클리어했나), endless (무한 모드까지 갔나), wave, best_wave, new_best,
##   kills ({적 종류: 수}), time (실제 플레이 초), gold (번 돈), shards (받은 SHARD),
##   stats (DamageStats)
func show_results(d: Dictionary) -> void:
	data = d
	var won: bool = d.get("victory", false)
	var color := _accent()
	if won and d.get("endless", false):
		_tag.text = "ENDLESS RUN OVER  -  OVERLORD DEFEATED"
	elif won:
		_tag.text = "OVERLORD DEFEATED"
	else:
		_tag.text = "CORE DESTROYED"
	_title.text = "VICTORY" if won else "GAME OVER"
	_set_color(_tag, Color(color, 0.75))
	_set_color(_title, color)
	visible = true
	reveal = 0.0
	_bg.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(self, "reveal", 1.0, COUNT_UP) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_body.queue_redraw()


func hide_results() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if visible and reveal < 1.0:
		_body.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			continue_pressed.emit()
		KEY_R:
			get_viewport().set_input_as_handled()
			retry_pressed.emit()


func _accent() -> Color:
	if data.get("victory", false):
		return EnemyDefs.get_def("overlord")["color"]
	return LOSS_COLOR


func total_kills() -> int:
	var sum := 0
	for v in data.get("kills", {}).values():
		sum += v
	return sum


## 처치한 적 종류, 많은 순.
func ranked_kills() -> Array:
	var kills: Dictionary = data.get("kills", {})
	var kinds := kills.keys()
	kinds.sort_custom(func(a, b) -> bool: return kills[a] > kills[b])
	return kinds


static func format_time(seconds: float) -> String:
	var s := maxi(roundi(seconds), 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func _set_color(label: Label, color: Color) -> void:
	var glow := label.label_settings.shadow_color.a
	label.label_settings.font_color = color
	label.label_settings.shadow_color = Color(color, glow)


## 숫자 카드와 두 목록을 직접 그린다.
class _Body extends Control:
	var screen: ResultsScreen
	var _font: Font
	var _bold: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Hud.font_weight(500)
		_bold = Hud.font_weight(800)

	func _draw() -> void:
		if screen == null or screen.data.is_empty():
			return
		var d := screen.data
		var t := screen.reveal
		_draw_cards(d, t)
		_draw_damage(d.get("stats"), t)
		_draw_kills(t)

	# ------------------------------------------------------------ 숫자 카드

	func _draw_cards(d: Dictionary, t: float) -> void:
		var wave: int = d.get("wave", 0)
		var best_note := ""
		var best_color := DIM
		if d.get("new_best", false):
			best_note = "NEW BEST"
			best_color = ResultsScreen.GOLD_COLOR
		elif d.get("best_wave", 0) > 0:
			best_note = "BEST  %d" % d["best_wave"]
		var cards := [
			["WAVE", "%d" % roundi(wave * t), Hud.NEON_CYAN, best_note, best_color],
			["KILLS", "%d" % roundi(screen.total_kills() * t), Color(1.0, 0.35, 0.45), "", DIM],
			["TIME", ResultsScreen.format_time(d.get("time", 0.0) * t), Color(0.75, 0.6, 1.0),
					"", DIM],
			["GOLD EARNED", "%d" % roundi(d.get("gold", 0) * t), ResultsScreen.GOLD_COLOR, "", DIM],
			["SHARDS", "+%d" % roundi(d.get("shards", 0) * t), ResultsScreen.SHARD_COLOR, "", DIM],
		]
		var cw := (ResultsScreen.CONTENT_W - ResultsScreen.CARD_GAP * 4) / 5.0
		for i in cards.size():
			var c: Array = cards[i]
			var col: Color = c[2]
			var r := Rect2(ResultsScreen.LEFT + (cw + ResultsScreen.CARD_GAP) * i,
					ResultsScreen.CARD_Y, cw, ResultsScreen.CARD_H)
			draw_rect(r, Color(col, 0.06))
			_neon_rect(r, col)
			_text_c(Vector2(r.get_center().x, r.position.y + 32), c[0], 17, Color(col, 0.75), _bold)
			_text_c(Vector2(r.get_center().x, r.position.y + 84), c[1], 50, Color.WHITE, _bold)
			if c[3] != "":
				_text_c(Vector2(r.get_center().x, r.end.y - 24), c[3], 16, c[4], _bold)

	func _neon_rect(r: Rect2, col: Color) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y), r.position])
		NeonDraw.polyline(self, pts, col, 0.8, 2.0)

	# ------------------------------------------------------------ 타일별 피해

	func _draw_damage(stats: DamageStats, t: float) -> void:
		var x := ResultsScreen.LEFT
		var w := ResultsScreen.DAMAGE_W
		var y := ResultsScreen.LIST_Y
		_text(Vector2(x, y), "DAMAGE BY TILE", 18, DIM, _bold)
		var ids: Array = [] if stats == null else stats.ranked_ids()
		var grand := 0.0
		for id in ids:
			grand += stats.total(id)
		_text_r(Vector2(x + w, y), "TOTAL  " + DamageStats.short(grand * t), 18, INK, _bold)
		var top := y + 26.0
		draw_line(Vector2(x, top), Vector2(x + w, top), RULE, 1.0)
		if ids.is_empty():
			_text(Vector2(x + 14, top + ResultsScreen.ROW_H * 0.6), "No damage dealt", 18, DIM,
					_font)
			return
		var shown := ids.slice(0, ResultsScreen.TILE_ROWS)
		var best := maxf(stats.total(shown[0]), 1.0)
		var bar_x := x + 330.0
		var bar_w := w - 330.0 - 190.0
		for r in shown.size():
			var id: int = shown[r]
			var info: Dictionary = stats.tiles[id]
			var alive: bool = info["alive"]
			var c: Color = info["color"]
			var a := 1.0 if alive else 0.45
			var mid := top + ResultsScreen.ROW_H * (r + 0.5)
			# 1위 칸은 살짝 밝게
			if r == 0:
				draw_rect(Rect2(x, mid - ResultsScreen.ROW_H / 2.0, w, ResultsScreen.ROW_H),
						Color(c, 0.07))
			_text_r(Vector2(x + 30, mid), "%d" % (r + 1), 16, DIM, _bold)
			draw_set_transform(Vector2(x + 58, mid))
			HexTile.draw_glyph(self, info["kind"], 11.0, Color(c, a), a)
			draw_set_transform(Vector2.ZERO)
			var label := "%s  LV%d" % [info["name"], info["level"]]
			if not alive:
				label += "  X"
			_text(Vector2(x + 82, mid), label, 18, Color(c, 0.95 * a), _bold)
			var tot := stats.total(id)
			var bw := bar_w * tot / best * t
			draw_rect(Rect2(bar_x, mid - 6, bar_w, 12), Color(c, 0.08))
			draw_rect(Rect2(bar_x, mid - 6, maxf(bw, 2.0), 12), Color(c, 0.8 * a))
			_text_r(Vector2(x + w - 80, mid), DamageStats.short(tot * t), 18, Color(INK, a), _bold)
			_text_r(Vector2(x + w, mid), "%d%%" % roundi(100.0 * tot / maxf(grand, 1.0)), 16,
					Color(DIM, a), _font)
		if ids.size() > shown.size():
			_text(Vector2(x + 82, top + ResultsScreen.ROW_H * (shown.size() + 0.45)),
					"+%d more" % (ids.size() - shown.size()), 15, DIM, _font)

	# ------------------------------------------------------------ 적 처치

	func _draw_kills(t: float) -> void:
		var x := ResultsScreen.KILLS_X
		var w := ResultsScreen.LEFT + ResultsScreen.CONTENT_W - x
		var y := ResultsScreen.LIST_Y
		_text(Vector2(x, y), "ENEMIES KILLED", 18, DIM, _bold)
		var top := y + 26.0
		draw_line(Vector2(x, top), Vector2(x + w, top), RULE, 1.0)
		var kinds := screen.ranked_kills()
		if kinds.is_empty():
			_text(Vector2(x + 14, top + ResultsScreen.ROW_H * 0.6), "None", 18, DIM, _font)
			return
		var kills: Dictionary = screen.data["kills"]
		var shown := kinds.slice(0, ResultsScreen.KILL_ROWS)
		for r in shown.size():
			var kind: String = shown[r]
			var def := EnemyDefs.get_def(kind)
			var c: Color = def["color"]
			var mid := top + ResultsScreen.ROW_H * (r + 0.5)
			_draw_enemy_icon(Vector2(x + 22, mid), def, c)
			_text(Vector2(x + 50, mid), def["name"], 18, c, _bold)
			_text_r(Vector2(x + w, mid), "%d" % roundi(kills[kind] * t), 18, INK, _bold)

	## 적과 같은 모양의 작은 아이콘 (Enemy.shape_points와 같은 방식).
	func _draw_enemy_icon(center: Vector2, def: Dictionary, c: Color) -> void:
		var sides: int = def["sides"]
		var r := 11.0
		var pts := PackedVector2Array()
		if def["star"]:
			for i in sides * 2 + 1:
				var a := PI * i / sides - PI / 2.0
				pts.append(center + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.5))
		else:
			for i in sides + 1:
				var a := TAU * i / sides - PI / 2.0
				pts.append(center + Vector2(cos(a), sin(a)) * r)
		NeonDraw.polyline(self, pts, c, 0.9, 2.0)

	# ------------------------------------------------------------ 글자

	func _text(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		draw_string(font, pos + Vector2(0, font_size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, color)

	func _text_c(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_text(pos - Vector2(w / 2.0, 0), s, font_size, color, font)

	func _text_r(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_text(pos - Vector2(w, 0), s, font_size, color, font)
