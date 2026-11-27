class_name LevelUpFx
extends Node2D
## 강화 순간 연출: 타일 모양 고리가 커지며 사라지고, 위로 떠오르는 "LV n" 글자.

const DURATION := 0.7

var color := Color.WHITE
var radius := 48.0
var level := 2

var _t := 0.0
var _font: Font


func _ready() -> void:
	z_index = 3
	_font = Hud.font_weight(800)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var fade := 1.0 - k
	# 바깥으로 퍼지는 고리 두 개
	NeonDraw.hexagon(self, Vector2.ZERO, radius * (0.9 + 0.9 * k), color, fade * 1.2, 3.0)
	NeonDraw.hexagon(self, Vector2.ZERO, radius * (0.9 + 0.45 * k), Color.WHITE, fade * 0.8, 2.0)
	# 처음 잠깐 하얗게 번쩍
	if k < 0.3:
		var flash := 1.0 - k / 0.3
		var pts := HexGrid.corners(radius * 0.9)
		draw_colored_polygon(pts, Color(1, 1, 1, 0.35 * flash))
	var text := "LV %d" % level
	var fs := 26
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(-w / 2.0, -radius - 10.0 - 40.0 * k)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, fade))
