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
## ORBIT: 구체 회전 속도(라디안/초), 구체 반지름, 최대 구체 수
const ORBIT_SPEED := 3.5
const ORB_RADIUS := 12.0
const MAX_ORBS := 6
## 강화 1번마다: 공격력 ×1.5, 공격 간격 ×0.9 (초당 피해 약 1.67배), 사거리 +20, 최대 체력 +20
const UPG_DAMAGE := 1.5
const UPG_INTERVAL := 0.9
const UPG_RANGE := 20.0
const UPG_HP := 20.0
const UPG_INCOME := 6
## LASER/CORE: 이 레벨에 도달하면 광선 +1
const EXTRA_BEAM_LEVELS: Array[int] = [3, 5]
## FROST: 강화마다 감속이 강해진다 (남는 속도 비율 ×0.88, 최저 0.25)
const FROST_SLOW_STEP := 0.88
const FROST_SLOW_MIN := 0.25
## BOOSTER: 강화마다 맞닿은 타일 공격 속도 보너스 +10%p
const UPG_HASTE := 0.10

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
## ORBIT: 도는 구체 수
var orbs := 0
## LASER/CORE: 레벨로 얻은 추가 광선 수
var extra_beams := 0
## FROST: 감속 시 남는 속도 비율 (낮을수록 강함)
var frost_slow := FROST_SLOW
## BOOSTER: 맞닿은 타일에 주는 공격 속도 보너스 (0.25 = 25% 빠르게)
var haste := 0.0
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
## ORBIT: 현재 회전 각도와 (구체, 적)마다 다시 때리기까지 남은 시간
var orbit_angle := 0.0
var _orb_hit_cd := {}
var _orbit_ring: OrbitRing


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
	orbs = def.get("orbs", 0)
	haste = def.get("haste", 0.0)
	if attack == "orbit" and _orbit_ring == null:
		_orbit_ring = OrbitRing.new()
		_orbit_ring.tile = self
		add_child(_orbit_ring)


## 전체 강화 배율까지 반영한 실제 공격력.
func damage() -> float:
	return base_damage * (board.damage_mult if board != null else 1.0)


## 전체 강화 배율까지 반영한 실제 공격 간격(초).
func interval() -> float:
	return fire_interval / ((board.rate_mult if board != null else 1.0) * (1.0 + haste_bonus()))


## 맞닿은 BOOSTER들이 주는 공격 속도 보너스 합 (여러 개면 더해진다).
func haste_bonus() -> float:
	if board == null:
		return 0.0
	var total := 0.0
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t != null and t != self and is_instance_valid(t) and t.haste > 0.0:
			total += t.haste
	return total


## BOOSTER: 버프를 받는 맞닿은 공격 타일들.
func boosted_neighbors() -> Array[HexTile]:
	var result: Array[HexTile] = []
	if board == null or haste <= 0.0:
		return result
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t != null and t != self and is_instance_valid(t) and t.attack != "none":
			result.append(t)
	return result


## 장비까지 반영한 실제 사거리.
func effective_range() -> float:
	return attack_range * (GearDefs.SCOPE_RANGE_MULT if gear == "scope" else 1.0)


## 한 번 공격할 때 노리는 대상 수 (SPLITTER면 +1).
func target_count() -> int:
	return 1 + extra_beams + (1 if gear == "splitter" else 0)


## ORBIT: 실제로 도는 구체 수 (SPLITTER면 +1).
func orb_count() -> int:
	return orbs + (1 if gear == "splitter" else 0)


## ORBIT: i번째 구체의 위치 (타일 기준 로컬 좌표).
func orb_position(i: int) -> Vector2:
	var a := orbit_angle + TAU * i / orb_count()
	return Vector2(cos(a), sin(a)) * effective_range()


## 장비 장착. 이미 있으면 교체한다.
func equip(gear_id: String) -> void:
	gear = gear_id
	queue_redraw()


## 적 하나를 맞혔을 때: 피해 + 장비 효과.
func apply_hit(enemy: Enemy, amount: float) -> void:
	if gear == "crit" and randf() < GearDefs.CRIT_CHANCE:
		amount *= GearDefs.CRIT_MULT
		enemy.flash_crit()
	var was_alive := enemy.is_alive()
	enemy.take_damage(amount, self)
	if gear == "detonator" and was_alive and not enemy.is_alive():
		_detonate(enemy.global_position)
	match gear:
		"igniter":
			enemy.apply_burn(amount * GearDefs.IGNITE_DPS_RATIO, GearDefs.IGNITE_TIME, self)
		"cryo":
			enemy.apply_slow(GearDefs.CRYO_SLOW, GearDefs.CRYO_TIME)


## DETONATOR: pos(전역)에서 폭발. 폭발 피해로는 다시 폭발하지 않는다.
func _detonate(pos: Vector2) -> void:
	if board == null:
		return
	var color: Color = GearDefs.get_def("detonator")["color"]
	var fx := Explosion.new()
	fx.color = color
	fx.radius = GearDefs.DETONATE_RADIUS
	board.enemy_layer.add_child(fx)
	fx.global_position = pos
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var other := node as Enemy
		if other != null and other.is_alive() \
				and pos.distance_to(other.global_position) <= GearDefs.DETONATE_RADIUS:
			other.take_damage(damage() * GearDefs.DETONATE_RATIO, self)


func upgrade_cost() -> int:
	return roundi(25.0 * pow(2.0, level - 1))


func upgrade() -> void:
	level += 1
	base_damage *= UPG_DAMAGE
	if attack_range > 0.0:
		attack_range += UPG_RANGE
	fire_interval *= UPG_INTERVAL
	max_hp += UPG_HP
	hp = minf(hp + UPG_HP, max_hp)
	match kind:
		"bank":
			income += UPG_INCOME
		"spark":
			bounces += 1
		"orbit":
			orbs = mini(orbs + 1, MAX_ORBS)
		"frost":
			frost_slow = maxf(frost_slow * FROST_SLOW_STEP, FROST_SLOW_MIN)
		"booster":
			haste += UPG_HASTE
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level):
				extra_beams += 1
	_show_level_up()
	queue_redraw()


## 다음 강화로 무엇이 좋아지는지 한 줄씩 (정보 창 미리보기용).
func upgrade_preview() -> Array[String]:
	var lines: Array[String] = []
	var mult := board.damage_mult if board != null else 1.0
	if attack != "none":
		lines.append("DMG %.1f > %.1f" % [damage(), base_damage * UPG_DAMAGE * mult])
		lines.append("RANGE +%d    SPEED +%d%%" % [roundi(UPG_RANGE),
				roundi((1.0 / UPG_INTERVAL - 1.0) * 100.0)])
	match kind:
		"bank":
			lines.append("INCOME $%d > $%d" % [income, income + UPG_INCOME])
		"spark":
			lines.append("+1 BOUNCE")
		"booster":
			lines.append("HASTE +%d%% > +%d%%" % [roundi(haste * 100.0),
					roundi((haste + UPG_HASTE) * 100.0)])
		"orbit":
			if orbs < MAX_ORBS:
				lines.append("+1 ORB")
		"frost":
			lines.append("SLOW %d%% > %d%%" % [roundi((1.0 - frost_slow) * 100.0),
					roundi((1.0 - maxf(frost_slow * FROST_SLOW_STEP, FROST_SLOW_MIN)) * 100.0)])
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level + 1):
				lines.append("+1 BEAM")
	lines.append("HP +%d" % roundi(UPG_HP))
	return lines


func _show_level_up() -> void:
	if not is_inside_tree():
		return
	var fx := LevelUpFx.new()
	fx.color = color
	fx.radius = size
	fx.level = level
	add_child(fx)


func _process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	_shot_time = maxf(_shot_time - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if attack == "orbit":
		_process_orbit(delta)
	elif _cooldown <= 0.0:
		_fire()
	queue_redraw()


## ORBIT: 구체를 돌리고, 닿은 적을 때린다. 같은 구체는 같은 적을 interval()마다 한 번만 때린다.
func _process_orbit(delta: float) -> void:
	orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
	for key in _orb_hit_cd.keys():
		_orb_hit_cd[key] -= delta
		if _orb_hit_cd[key] <= 0.0:
			_orb_hit_cd.erase(key)
	var reach := effective_range() + ORB_RADIUS + 30.0
	var nearby: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() \
				and global_position.distance_to(enemy.global_position) <= reach + enemy.radius:
			nearby.append(enemy)
	if nearby.is_empty():
		return
	for i in orb_count():
		var orb := global_position + orb_position(i)
		for enemy in nearby:
			if not enemy.is_alive():
				continue
			var key := "%d:%d" % [i, enemy.get_instance_id()]
			if _orb_hit_cd.has(key):
				continue
			if orb.distance_to(enemy.global_position) <= ORB_RADIUS + enemy.radius:
				_orb_hit_cd[key] = interval()
				apply_hit(enemy, damage())


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
				enemy.apply_slow(frost_slow, FROST_SLOW_TIME)
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
	var lv := level - 1
	NeonDraw.hexagon(self, Vector2.ZERO, size * 0.9, c, minf(pulse + 0.08 * lv, 1.4),
			minf(3.0 + 0.5 * lv, 6.0), minf(0.10 + 0.04 * lv, 0.35))
	# 레벨 3, 5, 7...: 안쪽 테두리가 하나씩 늘어난다
	for i in range(lv / 2):
		NeonDraw.hexagon(self, Vector2.ZERO, size * (0.78 - 0.08 * i), c, 0.5, 1.5)
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
					_shot_time / SHOT_TIME, minf(2.0 + 0.8 * (level - 1), 6.0))
	if attack == "frost":
		draw_arc(Vector2.ZERO, effective_range(), 0.0, TAU, 96, Color(c, 0.12), 1.0, true)
	if attack == "orbit" and _orbit_ring != null:
		_orbit_ring.queue_redraw()
	if haste > 0.0:
		_draw_boost_links(c)
	if gear != "":
		_draw_gear_badge()


## BOOSTER: 버프를 주는 이웃 쪽 변 위에 바깥으로 흐르는 작은 화살표.
func _draw_boost_links(c: Color) -> void:
	var flow := fmod(_time * 1.5, 1.0)
	for t in boosted_neighbors():
		var dir := (t.position - position).normalized()
		var side := Vector2(-dir.y, dir.x)
		var center := dir * size * (0.62 + 0.3 * flow)
		var w := size * 0.16
		var chev := PackedVector2Array([center - dir * w + side * w, center,
				center - dir * w - side * w])
		NeonDraw.polyline(self, chev, c, 0.9 * (1.0 - flow * 0.6), 2.0)


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
	draw_glyph(self, kind, size * 0.3, c, intensity, orbit_angle)


## 타일 종류별 아이콘. canvas의 원점에 반지름 r 크기로 그린다 (상점 화면에서도 사용).
static func draw_glyph(canvas: CanvasItem, kind: String, r: float, c: Color, intensity: float,
		angle := 0.0) -> void:
	match kind:
		"core":
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
		"laser":
			var tri := PackedVector2Array()
			for i in 4:
				var a := -PI / 2.0 + TAU * i / 3.0
				tri.append(Vector2(cos(a), sin(a)) * r)
			NeonDraw.polyline(canvas, tri, c, intensity * 0.8, 2.0)
		"spark":
			var bolt := PackedVector2Array([Vector2(r * 0.25, -r), Vector2(-r * 0.35, r * 0.1),
					Vector2(r * 0.35, -r * 0.1), Vector2(-r * 0.25, r)])
			NeonDraw.polyline(canvas, bolt, c, intensity * 0.8, 2.0)
		"frost":
			for i in 3:
				var a := PI * i / 3.0
				var d := Vector2(cos(a), sin(a)) * r
				NeonDraw.polyline(canvas, PackedVector2Array([-d, d]), c, intensity * 0.8, 2.0)
		"orbit":
			canvas.draw_arc(Vector2.ZERO, r * 0.85, 0.0, TAU, 32, Color(c, 0.5 * intensity), 1.5, true)
			canvas.draw_circle(Vector2.ZERO, r * 0.25, Color(c, intensity))
			var a := angle
			canvas.draw_circle(Vector2(cos(a), sin(a)) * r * 0.85, r * 0.22, Color(c, intensity))
		"booster":
			# 위로 향한 겹 화살표 두 개
			for k in 2:
				var y := r * (0.35 - 0.6 * k)
				var chev := PackedVector2Array([Vector2(-r * 0.6, y + r * 0.35),
						Vector2(0, y - r * 0.15), Vector2(r * 0.6, y + r * 0.35)])
				NeonDraw.polyline(canvas, chev, c, intensity * 0.8, 2.0)
		"bank":
			var dia := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r),
					Vector2(-r * 0.7, 0), Vector2(0, -r)])
			NeonDraw.polyline(canvas, dia, c, intensity * 0.8, 2.0)
