class_name StatsPanel
extends Control
## 일시정지 화면의 피해 통계 표. 줄 = 타일(총 피해 많은 순), 칸 = 최근 웨이브.
## 칸 배경은 그 웨이브 전체 피해 중 이 타일 몫만큼 진해진다. 맨 오른쪽은 총합과 막대.

const MAX_ROWS := 10
const WAVE_COLS := 7
const ROW_H := 34.0
const HEAD_H := 40.0
const NAME_W := 250.0
const COL_W := 92.0
const TOTAL_W := 210.0
const INK := Color(1, 1, 1, 0.85)
const DIM := Color(1, 1, 1, 0.45)

var stats: DamageStats
var _font: Font
var _bold: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Hud.font_weight(500)
	_bold = Hud.font_weight(800)


## 표 크기를 기록에 맞춘 뒤 다시 그린다.
func show_stats(s: DamageStats) -> void:
	stats = s
	var rows := clampi(stats.tiles.size(), 1, MAX_ROWS)
	custom_minimum_size = Vector2(NAME_W + COL_W * WAVE_COLS + TOTAL_W,
			HEAD_H + ROW_H * rows + 12.0)
	queue_redraw()


func _waves() -> Array[int]:
	var result: Array[int] = []
	var last := stats.current_wave
	for w in range(maxi(1, last - WAVE_COLS + 1), last + 1):
		result.append(w)
	return result


func _draw() -> void:
	if stats == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var waves := _waves()
	var ids := stats.ranked_ids().slice(0, MAX_ROWS)
	# 머리줄
	_text(Vector2(14, HEAD_H * 0.55), Loc.t("DAMAGE BY WAVE"), 15, DIM, _bold)
	for i in waves.size():
		var w := waves[i]
		var label := "W%d" % w
		_text_c(Vector2(NAME_W + COL_W * (i + 0.5), HEAD_H * 0.55), label, 15,
				Hud.NEON_CYAN if w == stats.current_wave else DIM, _bold)
	_text(Vector2(NAME_W + COL_W * WAVE_COLS + 14, HEAD_H * 0.55), Loc.t("TOTAL"), 15, DIM, _bold)
	draw_line(Vector2(0, HEAD_H), Vector2(size.x, HEAD_H), Color(1, 1, 1, 0.15), 1.0)
	if ids.is_empty():
		_text(Vector2(14, HEAD_H + ROW_H * 0.55), Loc.t("No damage yet"), 17, DIM, _font)
		return
	var best_total := maxf(stats.total(ids[0]), 1.0)
	for r in ids.size():
		var id: int = ids[r]
		var info: Dictionary = stats.tiles[id]
		var alive: bool = info["alive"]
		var c: Color = info["color"]
		var y := HEAD_H + ROW_H * r
		var mid := y + ROW_H * 0.5
		var a := 1.0 if alive else 0.45
		# 이름: 아이콘 + 이름 + 레벨 (부서진 타일은 흐리게, X 표시)
		draw_set_transform(Vector2(24, mid))
		HexTile.draw_glyph(self, info["kind"], 9.0, Color(c, a), a)
		draw_set_transform(Vector2.ZERO)
		var label := "%s  LV%d" % [info["name"], info["level"]]
		if not alive:
			label += "  X"
		_text(Vector2(46, mid), label, 16, Color(c, 0.95 * a), _bold)
		# 웨이브 칸
		for i in waves.size():
			var w := waves[i]
			var d := stats.damage(id, w)
			var cell := Rect2(NAME_W + COL_W * i + 3, y + 3, COL_W - 6, ROW_H - 6)
			if d > 0.0:
				var share := d / maxf(stats.wave_total(w), 1.0)
				draw_rect(cell, Color(c, 0.06 + 0.4 * share))
				_text_c(cell.get_center(), DamageStats.short(d), 15, Color(INK, a), _font)
			else:
				_text_c(cell.get_center(), "-", 15, Color(1, 1, 1, 0.2), _font)
		# 총합 + 막대
		var tot := stats.total(id)
		var bx := NAME_W + COL_W * WAVE_COLS + 14
		var bw := (TOTAL_W - 100.0) * tot / best_total
		draw_rect(Rect2(bx, mid - 5, maxf(bw, 2.0), 10), Color(c, 0.75 * a))
		_text(Vector2(bx + TOTAL_W - 92, mid), DamageStats.short(tot), 16, Color(INK, a), _bold)
		if r < ids.size() - 1:
			draw_line(Vector2(10, y + ROW_H), Vector2(size.x - 10, y + ROW_H),
					Color(1, 1, 1, 0.06), 1.0)


func _text(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
	draw_string(font, pos + Vector2(0, font_size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, color)


func _text_c(pos: Vector2, s: String, font_size: int, color: Color, font: Font) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(pos - Vector2(w / 2.0, 0), s, font_size, color, font)
