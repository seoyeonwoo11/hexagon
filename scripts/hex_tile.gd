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
## CORE: 이 레벨에 도달하면 광선 +1 (LASER는 관통 광선이라 대신 집중이 세짐)
const EXTRA_BEAM_LEVELS: Array[int] = [3, 5]
## LASER: 광선이 남아 보이는 시간, 관통 판정 폭, 강화마다 집중 보너스 +3%p
const BEAM_TIME := 0.16
const BEAM_HALF_WIDTH := 14.0
const UPG_FOCUS := 0.03
## LASER: 관통당한 (조준하지 않은) 적이 받는 피해 비율
const PIERCE_RATIO := 0.4
## DRONE HIVE: 최대 드론 수, 이 레벨에 도달하면 드론 +1
const MAX_DRONES := 6
const DRONE_LEVELS: Array[int] = [3, 5, 7]
## ARCHER: 강화마다 맞닿은 ARCHER 1개당 공격력 보너스 +10%p
const UPG_PACK := 0.10
## PRISM: 굴절된 세 갈래 사이 각도, 강화마다 갈래 피해 비율 +10%p, 굴절 광선 색 (빨강, 초록, 파랑)
const PRISM_SPREAD := 0.42
const UPG_SPLIT := 0.10
const PRISM_RAY_COLORS: Array[Color] = [Color(1.0, 0.35, 0.5), Color(0.4, 1.0, 0.55), Color(0.4, 0.6, 1.0)]
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
## LASER: 광선이 사거리 끝까지 뻗어 줄 위 모든 적을 맞힘
var pierce := false
## LASER: 같은 적을 연속으로 맞힐 때마다 공격력 +focus_step, 최대 focus_max번
var focus_step := 0.0
var focus_max := 0
## DRONE HIVE: 띄우는 드론 수
var drones := 0
## ARCHER: 맞닿은 ARCHER 1개당 공격력 보너스 (0.4 = +40%)
var pack_bonus := 0.0
## PRISM: 굴절된 갈래 하나가 원래 공격의 몇 배 피해인지 (0.4 = 40%)
var split := 0.0
## FROST: 감속 시 남는 속도 비율 (낮을수록 강함)
var frost_slow := FROST_SLOW
## BOOSTER: 맞닿은 타일에 주는 공격 속도 보너스 (0.25 = 25% 빠르게)
var haste := 0.0
var level := 1
var selected := false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
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
## LASER: 광선마다 집중 정도(0~1), 맞힌 지점들, 적 id별 집중 횟수
var _shot_focus: Array[float] = []
var _shot_hits: Array[Vector2] = []
var _focus := {}
var _hit_flash := 0.0
var _destroyed := false
## ORBIT: 현재 회전 각도와 (구체, 적)마다 다시 때리기까지 남은 시간
var orbit_angle := 0.0
var _orb_hit_cd := {}
var _orbit_ring: OrbitRing
var _frost_field: FrostField
var _drones: Array[Drone] = []
## 다시 그리기 판단용: 마지막으로 그렸을 때의 상태
var _drawn_state := []
var _anim_active := false


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
	pierce = def.get("pierce", false)
	focus_step = def.get("focus_step", 0.0)
	focus_max = def.get("focus_max", 0)
	drones = def.get("drones", 0)
	pack_bonus = def.get("pack", 0.0)
	split = def.get("split", 0.0)
	if attack == "frost" and _frost_field == null:
		_frost_field = FrostField.new()
		_frost_field.tile = self
		add_child(_frost_field)
	if attack == "orbit" and _orbit_ring == null:
		_orbit_ring = OrbitRing.new()
		_orbit_ring.tile = self
		add_child(_orbit_ring)


## 전체 강화 배율까지 반영한 실제 공격력.
func damage() -> float:
	var d := base_damage * (board.damage_mult if board != null else 1.0)
	if pack_bonus > 0.0:
		d *= 1.0 + pack_bonus * linked_archers()
	return d


## ARCHER: 면이 맞닿은 다른 ARCHER 수.
func linked_archers() -> int:
	if board == null or pack_bonus <= 0.0:
		return 0
	var n := 0
	for c in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(c)
		if t != null and t != self and is_instance_valid(t) and t.kind == "archer":
			n += 1
	return n


## DRONE HIVE: 실제 드론 수 (SPLITTER면 +1).
func drone_count() -> int:
	return mini(drones + (1 if gear == "splitter" else 0), MAX_DRONES)


## DRONE HIVE: 드론이 노릴 적. 벌집 사거리 안에서, 다른 드론이 안 노리는 적 중 그 드론에 가장 가까운 적.
## 모두 노려지고 있으면 그냥 가장 가까운 적.
func drone_pick_target(drone: Drone) -> Enemy:
	var taken := {}
	for d in _drones:
		if d != drone and is_instance_valid(d) and d.target != null and is_instance_valid(d.target):
			taken[d.target] = true
	var best: Enemy = null
	var best_free: Enemy = null
	var bd := INF
	var bfd := INF
	for e in enemies_in_range():
		var dist := drone.global_position.distance_squared_to(e.global_position)
		if dist < bd:
			bd = dist
			best = e
		if not taken.has(e) and dist < bfd:
			bfd = dist
			best_free = e
	return best_free if best_free != null else best


## DRONE HIVE: 드론 수를 drone_count()에 맞춘다.
func _sync_drones() -> void:
	_drones = _drones.filter(func(d: Drone) -> bool: return is_instance_valid(d))
	var want := drone_count()
	while _drones.size() > want:
		_drones.pop_back().queue_free()
	if _drones.size() < want and board != null and board.enemy_layer != null:
		while _drones.size() < want:
			var d := Drone.new()
			d.hive = self
			d.index = _drones.size()
			board.enemy_layer.add_child(d)
			d.global_position = global_position
			_drones.append(d)


func _exit_tree() -> void:
	for d in _drones:
		if is_instance_valid(d):
			d.queue_free()
	_drones.clear()


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
	return roundi(25.0 * pow(1.8, level - 1))


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
		"drone":
			if DRONE_LEVELS.has(level):
				drones = mini(drones + 1, MAX_DRONES)
		"archer":
			pack_bonus += UPG_PACK
		"prism":
			split += UPG_SPLIT
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level) and not pierce:
				extra_beams += 1
			if focus_max > 0:
				focus_step += UPG_FOCUS
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
			lines.append("INTEREST +%d%%" % roundi(Game.BANK_INTEREST_STEP * 100.0))
		"spark":
			lines.append("+1 BOUNCE")
		"booster":
			lines.append("HASTE +%d%% > +%d%%" % [roundi(haste * 100.0),
					roundi((haste + UPG_HASTE) * 100.0)])
		"orbit":
			if orbs < MAX_ORBS:
				lines.append("+1 ORB")
		"drone":
			if DRONE_LEVELS.has(level + 1) and drones < MAX_DRONES:
				lines.append("+1 DRONE")
		"archer":
			lines.append("PACK +%d%% > +%d%% PER ARCHER" % [roundi(pack_bonus * 100.0),
					roundi((pack_bonus + UPG_PACK) * 100.0)])
		"prism":
			lines.append("SPLIT %d%% > %d%% PER RAY" % [roundi(split * 100.0),
					roundi((split + UPG_SPLIT) * 100.0)])
		"frost":
			lines.append("SLOW %d%% > %d%%" % [roundi((1.0 - frost_slow) * 100.0),
					roundi((1.0 - maxf(frost_slow * FROST_SLOW_STEP, FROST_SLOW_MIN)) * 100.0)])
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level + 1) and not pierce:
				lines.append("+1 BEAM")
			if focus_max > 0:
				lines.append("FOCUS +%d%% > +%d%% / HIT" % [roundi(focus_step * 100.0),
						roundi((focus_step + UPG_FOCUS) * 100.0)])
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
	elif attack == "drone":
		_sync_drones()
	elif _cooldown <= 0.0:
		_fire()
	# 밝기 맥동은 다시 그리지 않고 투명도로만
	self_modulate.a = 0.85 + 0.15 * sin(_time * 2.5)
	_redraw_if_needed()


## 성능: 모양이 바뀔 때만 다시 그린다 (매 프레임 다시 그리면 타일이 많을 때 렉이 걸림).
## 광선, 피격 깜빡임, BOOSTER 화살표는 움직이는 동안만 매 프레임 그린다.
func _redraw_if_needed() -> void:
	var anim := _shot_time > 0.0 or _hit_flash > 0.0 or (haste > 0.0 and not boosted_neighbors().is_empty())
	var state := [level, hp, max_hp, gear, focus_stacks(), linked_archers(), prism_sources().size(),
			effective_range() if selected else 0.0]
	if anim or _anim_active or state != _drawn_state:
		_drawn_state = state
		queue_redraw()
	_anim_active = anim
	if _orbit_ring != null:
		_orbit_ring.rotation = orbit_angle
		_orbit_ring.sync()
	if _frost_field != null:
		_frost_field.sync()


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
			var key := enemy.get_instance_id() * 8 + i
			if _orb_hit_cd.has(key):
				continue
			if orb.distance_to(enemy.global_position) <= ORB_RADIUS + enemy.radius:
				_orb_hit_cd[key] = interval()
				apply_hit(enemy, damage())


func _fire() -> void:
	match attack:
		"laser":
			_fire_laser()
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
		"archer":
			var targets := nearest_targets(target_count())
			if not targets.is_empty() and board != null:
				_cooldown = interval()
				for enemy in targets:
					var arrow := Arrow.new()
					arrow.color = color
					arrow.damage = damage()
					arrow.source = self
					board.enemy_layer.add_child(arrow)
					arrow.launch(global_position, enemy)
				for p in adjacent_prisms():
					p.refract(self, damage())
		"frost":
			var targets := enemies_in_range()
			_cooldown = interval()
			for enemy in targets:
				enemy.apply_slow(frost_slow, FROST_SLOW_TIME)
				apply_hit(enemy, damage())


## LASER/CORE: 가까운 적들에게 광선. pierce면 사거리 끝까지 뻗어 줄 위 적도 맞힌다.
## 같은 적을 연속으로 맞히면 집중이 쌓여 그 적에게 주는 피해가 커진다 (관통당한 적은 기본 피해 × PIERCE_RATIO).
func _fire_laser() -> void:
	var targets := nearest_targets(target_count())
	if targets.is_empty():
		_focus.clear()
		return
	_shot_targets.clear()
	_shot_focus.clear()
	_shot_hits.clear()
	_shot_time = BEAM_TIME if pierce else SHOT_TIME
	_cooldown = interval()
	var new_focus := {}
	var hits: Array = []
	for enemy in targets:
		var id := enemy.get_instance_id()
		var stacks := 0
		if focus_max > 0:
			stacks = mini(int(_focus.get(id, -1)) + 1, focus_max)
		new_focus[id] = stacks
		_shot_focus.append(float(stacks) / focus_max if focus_max > 0 else 0.0)
		var main_dmg := damage() * (1.0 + focus_step * stacks)
		if not pierce:
			_shot_targets.append(to_local(enemy.global_position))
			hits.append([enemy, main_dmg])
			continue
		var dir := global_position.direction_to(enemy.global_position)
		var end := global_position + dir * effective_range()
		_shot_targets.append(to_local(end))
		for other in enemies_on_line(global_position, end):
			hits.append([other, main_dmg if other == enemy else damage() * PIERCE_RATIO])
			_shot_hits.append(to_local(other.global_position))
	_focus = new_focus
	for h in hits:
		var e: Enemy = h[0]
		if e.is_alive():
			apply_hit(e, h[1])
	if kind == "laser":
		for p in adjacent_prisms():
			p.refract(self, damage())


## 선분 a-b에 닿는 살아있는 적들 (전역 좌표).
func enemies_on_line(a: Vector2, b: Vector2) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var p := Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
		if p.distance_to(enemy.global_position) <= BEAM_HALF_WIDTH + enemy.radius:
			result.append(enemy)
	return result


## 면이 맞닿은 PRISM들.
func adjacent_prisms() -> Array[HexTile]:
	var result: Array[HexTile] = []
	if board == null:
		return result
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t != null and t != self and is_instance_valid(t) and t.split > 0.0:
			result.append(t)
	return result


## PRISM: 굴절시킬 맞닿은 LASER/ARCHER들.
func prism_sources() -> Array[HexTile]:
	var result: Array[HexTile] = []
	if board == null or split <= 0.0:
		return result
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t != null and is_instance_valid(t) and (t.kind == "laser" or t.kind == "archer"):
			result.append(t)
	return result


## PRISM: 쏜 타일에서 이 PRISM을 지나는 방향으로, 가운데와 좌우 PRISM_SPREAD만큼 벌어진 세 갈래.
## (놓는 위치가 화력 방향을 정한다)
func prism_directions(src: HexTile) -> Array[Vector2]:
	var base := src.position.direction_to(position)
	return [base.rotated(-PRISM_SPREAD), base, base.rotated(PRISM_SPREAD)]


## PRISM: src가 쏠 때마다 불린다. LASER는 관통 광선 세 줄, ARCHER는 곧게 나는 화살 세 개.
## 갈래마다 피해 = 원래 공격력 × split. 굴절된 공격은 다른 PRISM에서 다시 갈라지지 않는다.
func refract(src: HexTile, src_damage: float) -> void:
	if board == null or not is_inside_tree():
		return
	var dmg := src_damage * split
	var reach := src.effective_range()
	if src.kind == "laser":
		_shot_targets.clear()
		_shot_focus.clear()
		_shot_hits.clear()
		_shot_time = BEAM_TIME
		var hits: Array[Enemy] = []
		for d in prism_directions(src):
			var end := global_position + d * reach
			_shot_targets.append(to_local(end))
			for e in enemies_on_line(global_position, end):
				hits.append(e)
				_shot_hits.append(to_local(e.global_position))
		for e in hits:
			if e.is_alive():
				apply_hit(e, dmg)
	else:
		for d in prism_directions(src):
			var arrow := Arrow.new()
			arrow.color = src.color.lerp(Color.WHITE, 0.3)
			arrow.damage = dmg
			arrow.source = self
			board.enemy_layer.add_child(arrow)
			arrow.launch_straight(global_position, d, reach)


## LASER: 지금 가장 많이 쌓인 집중 횟수.
func focus_stacks() -> int:
	var best := 0
	for v in _focus.values():
		best = maxi(best, v)
	return best


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
	var pulse := 1.0
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
		if pierce or split > 0.0:
			_draw_beams(c)
		else:
			for target in _shot_targets:
				NeonDraw.polyline(self, PackedVector2Array([Vector2.ZERO, target]), c,
						_shot_time / SHOT_TIME, minf(2.0 + 0.8 * (level - 1), 6.0))
	if focus_max > 0:
		_draw_focus_meter(c)
	if haste > 0.0:
		_draw_boost_links(c)
	if pack_bonus > 0.0:
		_draw_pack_links(c)
	if split > 0.0:
		_draw_prism_rays()
	if gear != "":
		_draw_gear_badge()


## LASER: 사거리 끝까지 뻗는 굵은 광선. 집중이 쌓일수록 굵고 하얗게, 맞힌 자리엔 불꽃.
func _draw_beams(c: Color) -> void:
	var t := _shot_time / BEAM_TIME
	for i in _shot_targets.size():
		var f: float = _shot_focus[i] if i < _shot_focus.size() else 0.0
		var bc := c.lerp(Color.WHITE, 0.45 * f)
		if split > 0.0:
			bc = PRISM_RAY_COLORS[i % PRISM_RAY_COLORS.size()]
		var w := (3.0 + 0.8 * (level - 1) + 7.0 * f) * (0.4 + 0.6 * t)
		var line := PackedVector2Array([Vector2.ZERO, _shot_targets[i]])
		NeonDraw.polyline(self, line, bc, t, w)
		draw_polyline(line, Color(1, 1, 1, 0.85 * t), maxf(w * 0.3, 1.2), true)
		# 끝부분: 작게 퍼지는 원
		draw_circle(_shot_targets[i], w * 0.6, Color(bc, 0.35 * t))
	for p in _shot_hits:
		var rr := 5.0 + 9.0 * (1.0 - t)
		draw_arc(p, rr, 0.0, TAU, 16, Color(c.lerp(Color.WHITE, 0.6), t), 2.0, true)


## LASER: 집중 게이지. 가운데 삼각형 둘레에 쌓인 만큼 짧은 호가 켜진다.
func _draw_focus_meter(c: Color) -> void:
	var stacks := focus_stacks()
	if stacks <= 0:
		return
	var r := size * 0.46
	var seg := TAU / focus_max
	for i in stacks:
		var a0 := -PI / 2.0 + seg * i + 0.08
		draw_arc(Vector2.ZERO, r, a0, a0 + seg - 0.16, 8,
				Color(c.lerp(Color.WHITE, 0.3), 0.9), 2.5, true)


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


## PRISM: 굴절 방향 미리보기. 맞닿은 LASER/ARCHER마다 바깥쪽으로 흐린 세 갈래 짧은 선.
func _draw_prism_rays() -> void:
	for src in prism_sources():
		var dirs := prism_directions(src)
		for i in dirs.size():
			var d := dirs[i]
			NeonDraw.polyline(self, PackedVector2Array([d * size * 0.55, d * size * 1.25]),
					PRISM_RAY_COLORS[i], 0.45, 1.5)


## ARCHER: 맞닿은 ARCHER와 공유하는 변에 밝은 연결 막대. (두 타일이 같은 막대를 겹쳐 그림)
func _draw_pack_links(c: Color) -> void:
	if board == null:
		return
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t == null or t == self or t.kind != "archer":
			continue
		var dir := (t.position - position).normalized()
		var side := Vector2(-dir.y, dir.x)
		var mid := dir * size * 0.80
		NeonDraw.polyline(self, PackedVector2Array([mid - side * size * 0.32,
				mid + side * size * 0.32]), c.lerp(Color.WHITE, 0.4), 1.0, 3.0)


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
	draw_glyph(self, kind, size * 0.3, c, intensity)


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
		"drone":
			# 가운데 작은 육각형(벌집) + 둘레의 드론 세 개
			NeonDraw.hexagon(canvas, Vector2.ZERO, r * 0.45, c, intensity * 0.8, 2.0)
			for i in 3:
				var d := Vector2.from_angle(-PI / 2.0 + TAU * i / 3.0) * r * 0.95
				canvas.draw_circle(d, r * 0.22, Color(c, intensity))
		"archer":
			# 활: 왼쪽 반원 + 시위, 오른쪽으로 화살
			canvas.draw_arc(Vector2(r * 0.1, 0), r * 0.85, PI * 0.55, PI * 1.45, 16,
					Color(c, intensity), 2.0, true)
			var top := Vector2(r * 0.1, 0) + Vector2.from_angle(PI * 0.55) * r * 0.85
			var bot := Vector2(r * 0.1, 0) + Vector2.from_angle(PI * 1.45) * r * 0.85
			NeonDraw.polyline(canvas, PackedVector2Array([top, Vector2(-r * 0.15, 0), bot]),
					c, intensity * 0.6, 1.5)
			NeonDraw.polyline(canvas, PackedVector2Array([Vector2(-r * 0.15, 0), Vector2(r, 0)]),
					c, intensity * 0.8, 2.0)
			NeonDraw.polyline(canvas, PackedVector2Array([Vector2(r * 0.65, -r * 0.3),
					Vector2(r, 0), Vector2(r * 0.65, r * 0.3)]), c, intensity * 0.8, 2.0)
		"prism":
			# 삼각형 프리즘 + 왼쪽에서 들어온 빛이 오른쪽으로 세 갈래
			var tri := PackedVector2Array()
			for i in 4:
				var a := -PI / 2.0 + TAU * i / 3.0
				tri.append(Vector2(cos(a), sin(a)) * r * 0.75)
			NeonDraw.polyline(canvas, tri, c, intensity * 0.8, 2.0)
			canvas.draw_line(Vector2(-r * 1.1, r * 0.1), Vector2(-r * 0.2, 0), Color(c, intensity), 1.5, true)
			for i in 3:
				var end := Vector2(r * 1.15, (i - 1) * r * 0.45)
				canvas.draw_line(Vector2(r * 0.2, 0), end,
						Color(PRISM_RAY_COLORS[i], intensity), 1.5, true)
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
