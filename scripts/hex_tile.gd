class_name HexTile
extends Node2D
## 보드 위에 놓인 육각형 타일 하나. 종류(kind)에 따라 공격 방식이 다르다 (TileDefs 참고).
## 돈으로 강화(upgrade)하면 레벨이 오르고 능력치가 좋아진다.
## 체력이 0이 되면 destroyed 신호를 보낸다 (보드가 제거/게임오버 처리).

signal destroyed(tile: HexTile)

const SHOT_TIME := 0.08
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
## SPARK: 번개가 튕기는 횟수와 거리
var bounces := 0
var bounce_range := 0.0
var level := 1
var selected := false
## 장착한 장비 id (GearDefs). 빈 문자열이면 없음.
var gear := ""

var coord := Vector2i.ZERO
var size := 48.0
## 전체 강화 배율(damage_mult, rate_mult)을 읽어 오는 보드.
var board: Board

var _time := 0.0
var _cooldown := 0.0
var _shot_targets: Array[Vector2] = []
var _shot_time := 0.0
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
	bounces = def.get("bounces", 0)
	bounce_range = def.get("bounce_range", 0.0)


## 전체 강화 배율까지 반영한 실제 공격력.
func damage() -> float:
	return base_damage * (board.damage_mult if board != null else 1.0)


## 전체 강화 배율까지 반영한 실제 공격 간격(초).
func interval() -> float:
	return fire_interval / (board.rate_mult if board != null else 1.0)


## 장비까지 반영한 실제 사거리.
func effective_range() -> float:
	return attack_range * (GearDefs.SCOPE_RANGE_MULT if gear == "scope" else 1.0)


## 한 번 공격할 때 노리는 대상 수 (SPLITTER면 +1).
func target_count() -> int:
	return 2 if gear == "splitter" else 1


## 장비 장착. 이미 있으면 교체한다 (REGENERATOR의 체력 보너스도 같이 정리).
func equip(gear_id: String) -> void:
	if gear == "regen":
		max_hp -= GearDefs.REGEN_HP
		hp = minf(hp, max_hp)
	gear = gear_id
	if gear == "regen":
		max_hp += GearDefs.REGEN_HP
		hp += GearDefs.REGEN_HP
	queue_redraw()


## 적 하나를 맞혔을 때: 피해 + 장비 효과.
func apply_hit(enemy: Enemy, amount: float) -> void:
	enemy.take_damage(amount, self)
	match gear:
		"igniter":
			enemy.apply_burn(amount * GearDefs.IGNITE_DPS_RATIO, GearDefs.IGNITE_TIME, self)
		"cryo":
			enemy.apply_slow(GearDefs.CRYO_SLOW, GearDefs.CRYO_TIME)


func upgrade_cost() -> int:
	return roundi(20.0 * pow(1.7, level - 1))


func upgrade() -> void:
	level += 1
	base_damage *= 1.35
	if attack_range > 0.0:
		attack_range += 15.0
	fire_interval *= 0.92
	max_hp += 15.0
	hp = minf(hp + 15.0, max_hp)
	if kind == "bank":
		income += 5
	if kind == "spark":
		bounces += 1
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	_shot_time = maxf(_shot_time - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if gear == "regen" and hp < max_hp and not _destroyed:
		hp = minf(hp + GearDefs.REGEN_PER_SEC * delta, max_hp)
	if _cooldown <= 0.0:
		_fire()
	queue_redraw()


func _fire() -> void:
	match attack:
		"laser":
			var targets := nearest_targets(target_count())
			if not targets.is_empty():
				_shot_targets.clear()
				for enemy in targets:
					_shot_targets.append(to_local(enemy.global_position))
				_shot_time = SHOT_TIME
				_cooldown = interval()
				for enemy in targets:
					apply_hit(enemy, damage())
		"spark":
			var targets := nearest_targets(target_count())
			if not targets.is_empty() and board != null:
				_cooldown = interval()
				for enemy in targets:
					var bolt := ChainBolt.new()
					bolt.color = color
					bolt.damage = damage()
					bolt.bounces = bounces
					bolt.bounce_range = bounce_range
					bolt.source = self
					board.enemy_layer.add_child(bolt)
					bolt.launch(global_position, enemy)
		"frost":
			var targets := enemies_in_range()
			_cooldown = interval()
			for enemy in targets:
				enemy.apply_slow(FROST_SLOW, FROST_SLOW_TIME)
				apply_hit(enemy, damage())


func enemies_in_range() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() \
				and global_position.distance_to(enemy.global_position) <= effective_range():
			result.append(enemy)
	return result


## 사거리 안에서 가장 가까운 살아있는 적.
func find_target() -> Enemy:
	var targets := nearest_targets(1)
	return targets[0] if not targets.is_empty() else null


## 사거리 안에서 가까운 순서로 최대 n명.
func nearest_targets(n: int) -> Array[Enemy]:
	var enemies := enemies_in_range()
	enemies.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return global_position.distance_squared_to(a.global_position) \
				< global_position.distance_squared_to(b.global_position))
	return enemies.slice(0, n)


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
		draw_arc(Vector2.ZERO, effective_range(), 0.0, TAU, 96, Color(c, 0.35), 1.5, true)
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
		for target in _shot_targets:
			NeonDraw.polyline(self, PackedVector2Array([Vector2.ZERO, target]), c,
					_shot_time / SHOT_TIME, 2.0)
	if attack == "frost":
		draw_arc(Vector2.ZERO, effective_range(), 0.0, TAU, 96, Color(c, 0.12), 1.0, true)
	if gear != "":
		_draw_gear_badge()


## 장비 표시: 타일 아래쪽 꼭짓점 근처의 작은 다이아몬드 배지.
func _draw_gear_badge() -> void:
	var gc: Color = GearDefs.get_def(gear)["color"]
	var center := Vector2(0, size * 0.62)
	var r := 6.0
	var dia := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0),
			center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
	draw_colored_polygon(dia, Color(gc, 0.35))
	NeonDraw.polyline(self, dia, gc, 1.0, 1.5)


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
		"spark":
			var bolt := PackedVector2Array([Vector2(r * 0.25, -r), Vector2(-r * 0.35, r * 0.1),
					Vector2(r * 0.35, -r * 0.1), Vector2(-r * 0.25, r)])
			NeonDraw.polyline(self, bolt, c, intensity * 0.8, 2.0)
		"frost":
			for i in 3:
				var a := PI * i / 3.0
				var d := Vector2(cos(a), sin(a)) * r
				NeonDraw.polyline(self, PackedVector2Array([-d, d]), c, intensity * 0.8, 2.0)
		"bank":
			var dia := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r),
					Vector2(-r * 0.7, 0), Vector2(0, -r)])
			NeonDraw.polyline(self, dia, c, intensity * 0.8, 2.0)
