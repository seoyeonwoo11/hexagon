class_name HexTile
extends Node2D
## 보드 위에 놓인 육각형 타일 하나. 기능(공격 등)은 2단계 이후 추가한다.

@export var color := Color(0.0, 0.95, 1.0)

var coord := Vector2i.ZERO
var size := 48.0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.5)
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.9, color, pulse, 3.0, 0.10)
	# 가운데 작은 육각형: 타일 "코어" 표시
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.3, color, pulse * 0.8, 2.0)
