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
var _slow_factor := 1.0
var _slow_timer := 0.0
var _burn_dps := 0.0
var _burn_timer := 0.0
var _burn_source: HexTile
## 마지막으로 피해를 준 타일 (COLLECTOR 장비 보상용)
var _last_source: HexTile
var _crit_flash := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp


func _process(delta: float) -> void:
	if _dead or board == null:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	if _burn_timer > 0.0:
		_burn_timer -= delta
		take_damage(_burn_dps * delta, _burn_source)
		if _dead:
			return
	var target := board.nearest_tile(global_position)
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= board.hex_size * 0.8:
		target.take_damage(contact_damage)
		_die(false)
		return
	global_position += to_target.normalized() * speed * _slow_factor * delta
	_spin += delta * 3.0
	_crit_flash = maxf(_crit_flash - delta, 0.0)
	queue_redraw()


## factor 배 속도로 duration초 동안 느려진다 (여러 번 걸리면 가장 강한 감속 유지).
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)


## 화상: duration초 동안 초당 dps 피해. 더 센 화상으로 덮어쓴다.
func apply_burn(dps: float, duration: float, source: HexTile = null) -> void:
	if dps >= _burn_dps or _burn_timer <= 0.0:
		_burn_dps = dps
		_burn_source = source
	_burn_timer = maxf(_burn_timer, duration)


func is_burning() -> bool:
	return _burn_timer > 0.0


## 치명타 맞았을 때 잠깐 하얗게 번쩍인다.
func flash_crit() -> void:
	_crit_flash = 0.15


func is_slowed() -> bool:
	return _slow_timer > 0.0


func is_alive() -> bool:
	return not _dead


func take_damage(amount: float, source: HexTile = null) -> void:
	if _dead:
		return
	if source != null:
		_last_source = source
	hp -= amount
	if hp <= 0.0:
		_die(true)
	else:
		queue_redraw()


func _die(killed: bool) -> void:
	_dead = true
	remove_from_group(GROUP)
	var bonus := 0
	if killed and is_instance_valid(_last_source) and _last_source.gear == "collector":
		bonus = GearDefs.COLLECTOR_BONUS
	died.emit(self, reward + bonus if killed else 0)
	queue_free()


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 4:
		var a := _spin + TAU * i / 3.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var c := color.lerp(Color(0.6, 0.8, 1.0), 0.6) if is_slowed() else color
	if _crit_flash > 0.0:
		c = Color.WHITE
	elif is_burning():
		c = c.lerp(Color(1.0, 0.6, 0.1), 0.5 + 0.3 * sin(_spin * 6.0))
	NeonDraw.polyline(self, pts, c, 1.0, 2.5)
	if hp < max_hp:
		var w := radius * 2.0
		var y := radius + 6.0
		draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Color(color, 0.25), 2.0)
		draw_line(Vector2(-w / 2.0, y), Vector2(-w / 2.0 + w * hp / max_hp, y), color, 2.0)
