class_name HexTile
extends Node2D
## 보드 위에 놓인 육각형 타일 하나. 종류(kind)에 따라 공격 방식이 다르다 (TileDefs 참고).
## 돈으로 강화(upgrade)하면 레벨이 오르고 능력치가 좋아진다.
## 체력이 0이 되면 destroyed 신호를 보낸다 (보드가 제거/게임오버 처리).

signal destroyed(tile: HexTile)

const SHOT_TIME := 0.08
const PULSE_TIME := 0.35
const HIT_FLASH_TIME := 0.2
const FROST_SLOW := 0.5
const FROST_SLOW_TIME := 0.6

var kind := "laser"
var display_name := "LASER"
var color := Color(0.4, 1.0, 0.3)
var attack := "laser"
var max_hp := 60.0
var hp := 60.0
var base_damage := 5.0
var attack_range := 260.0
var fire_interval := 0.4
var income := 0
var level := 1
var selected := false

var coord := Vector2i.ZERO
var size := 48.0
## 전체 강화 배율(damage_mult, rate_mult)을 읽어 오는 보드.
var board: Board

var _time := 0.0
var _cooldown := 0.0
var _shot_target := Vector2.ZERO
var _shot_time := 0.0
var _pulse_time := 0.0
var _hit_flash := 0.0
var _destroyed := false


func setup(tile_kind: String) -> void:
	var def := TileDefs.get_def(tile_kind)
	kind = tile_kind
	display_name = def["name"]
	color = def["color"]
	attack = def["attack"]
	max_hp = def["max_hp"]
	hp = max_hp
	base_damage = def["damage"]
	attack_range = def["range"]
	fire_interval = def["interval"]
	income = def["income"]


## 전체 강화 배율까지 반영한 실제 공격력.
func damage() -> float:
	return base_damage * (board.damage_mult if board != null else 1.0)


## 전체 강화 배율까지 반영한 실제 공격 간격(초).
func interval() -> float:
	return fire_interval / (board.rate_mult if board != null else 1.0)


func upgrade_cost() -> int:
	return roundi(15.0 * pow(1.6, level - 1))


func upgrade() -> void:
	level += 1
	base_damage *= 1.35
	if attack_range > 0.0:
		attack_range += 15.0
	fire_interval *= 0.92
	max_hp += 15.0
	hp = minf(hp + 15.0, max_hp)
	if kind == "bank":
		income += 8
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	_shot_time = maxf(_shot_time - delta, 0.0)
	_pulse_time = maxf(_pulse_time - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _cooldown <= 0.0:
		_fire()
	queue_redraw()


func _fire() -> void:
	match attack:
		"laser":
			var enemy := find_target()
			if enemy != null:
				_shot_target = to_local(enemy.global_position)
				_shot_time = SHOT_TIME
				_cooldown = interval()
				enemy.take_damage(damage())
		"pulse":
			var targets := enemies_in_range()
			if not targets.is_empty():
				_pulse_time = PULSE_TIME
				_cooldown = interval()
				for enemy in targets:
					enemy.take_damage(damage())
		"frost":
			var targets := enemies_in_range()
			_cooldown = interval()
			for enemy in targets:
				enemy.apply_slow(FROST_SLOW, FROST_SLOW_TIME)
				enemy.take_damage(damage())


func enemies_in_range() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() \
				and global_position.distance_to(enemy.global_position) <= attack_range:
			result.append(enemy)
	return result


## 사거리 안에서 가장 가까운 살아있는 적.
func find_target() -> Enemy:
	var best: Enemy = null
	var best_dist := attack_range
	for enemy in enemies_in_range():
		var d := global_position.distance_to(enemy.global_position)
		if d <= best_dist:
			best = enemy
			best_dist = d
	return best


func take_damage(amount: float) -> void:
	if _destroyed:
		return
	hp -= amount
	_hit_flash = HIT_FLASH_TIME
	if hp <= 0.0:
		hp = 0.0
		_destroyed = true
		destroyed.emit(self)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.5)
	var c := color.lerp(Color(1.0, 0.15, 0.2), _hit_flash / HIT_FLASH_TIME)
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(c, 0.35), 1.5, true)
		NeonDraw.hexagon(self, Vector2.ZERO, size * 0.98, Color.WHITE, 0.9, 2.0)
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.9, c, pulse, 3.0, 0.10)
	_draw_glyph(c, pulse)
	# 레벨 표시: 위쪽에 작은 점
	for i in range(level - 1):
		var x := (i - (level - 2) / 2.0) * 8.0
		draw_circle(Vector2(x, -size * 0.62), 2.2, c)
	# 체력이 깎였으면 남은 체력을 원호로 표시
	if hp < max_hp:
		var frac := hp / max_hp
		draw_arc(Vector2.ZERO, size * 0.55, -PI / 2.0, -PI / 2.0 + TAU * frac, 32,
				Color(c, 0.8), 2.0, true)
	if _shot_time > 0.0:
		NeonDraw.polyline(self, PackedVector2Array([Vector2.ZERO, _shot_target]), c,
				_shot_time / SHOT_TIME, 2.0)
	if _pulse_time > 0.0:
		var t := 1.0 - _pulse_time / PULSE_TIME
		draw_arc(Vector2.ZERO, attack_range * t, 0.0, TAU, 64, Color(c, 1.0 - t), 4.0, true)
	if attack == "frost":
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(c, 0.12), 1.0, true)


## 종류마다 가운데 모양을 다르게 그린다.
func _draw_glyph(c: Color, intensity: float) -> void:
	var r := size * 0.3
	match kind:
		"core":
			NeonDraw.hexagon(self, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
		"laser":
			var tri := PackedVector2Array()
			for i in 4:
				var a := -PI / 2.0 + TAU * i / 3.0
				tri.append(Vector2(cos(a), sin(a)) * r)
			NeonDraw.polyline(self, tri, c, intensity * 0.8, 2.0)
		"pulse":
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 2.0, true)
			draw_arc(Vector2.ZERO, r * 0.45, 0.0, TAU, 24, c, 2.0, true)
		"frost":
			for i in 3:
				var a := PI * i / 3.0
				var d := Vector2(cos(a), sin(a)) * r
				NeonDraw.polyline(self, PackedVector2Array([-d, d]), c, intensity * 0.8, 2.0)
		"bank":
			var dia := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r),
					Vector2(-r * 0.7, 0), Vector2(0, -r)])
			NeonDraw.polyline(self, dia, c, intensity * 0.8, 2.0)
