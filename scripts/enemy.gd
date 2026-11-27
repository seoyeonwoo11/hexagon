class_name Enemy
extends Node2D
## 화면 밖에서 나타나 가장 가까운 타일로 다가가는 적.
## 타일에 닿으면 피해를 주고 사라지며, 처치되면 보상금을 준다.

signal died(enemy: Enemy, reward: int)

const GROUP := &"enemies"

@export var color := Color(1.0, 0.3, 0.35)

var max_hp := 10.0
var hp := 10.0
var speed := 60.0
var reward := 5
var contact_damage := 10.0
var radius := 12.0
var board: Board

var _dead := false
var _spin := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp


func _process(delta: float) -> void:
	if _dead or board == null:
		return
	var target := board.nearest_tile(global_position)
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= board.hex_size * 0.8:
		target.take_damage(contact_damage)
		_die(false)
		return
	global_position += to_target.normalized() * speed * delta
	_spin += delta * 3.0
	queue_redraw()


func is_alive() -> bool:
	return not _dead


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	if hp <= 0.0:
		_die(true)
	else:
		queue_redraw()


func _die(killed: bool) -> void:
	_dead = true
	remove_from_group(GROUP)
	died.emit(self, reward if killed else 0)
	queue_free()


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 4:
		var a := _spin + TAU * i / 3.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	NeonDraw.polyline(self, pts, color, 1.0, 2.5)
	if hp < max_hp:
		var w := radius * 2.0
		var y := radius + 6.0
		draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Color(color, 0.25), 2.0)
		draw_line(Vector2(-w / 2.0, y), Vector2(-w / 2.0 + w * hp / max_hp, y), color, 2.0)
