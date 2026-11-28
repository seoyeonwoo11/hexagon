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
## CORE: 이 레벨에 도달하면 광선 +1 (LASER는 한 적에 꽂는 광선이라 대신 집중이 세짐)
const EXTRA_BEAM_LEVELS: Array[int] = [3, 5]
## LASER: 대상이 없을 때 새 대상을 찾는 간격(초), 강화마다 집중 보너스 +3%p
const BEAM_RETARGET := 0.1
const UPG_FOCUS := 0.03
## DRONE HIVE: 최대 드론 수, 이 레벨에 도달하면 드론 +1
const MAX_DRONES := 6
const DRONE_LEVELS: Array[int] = [2, 4, 6]
## ARCHER: 강화마다 맞닿은 ARCHER 1개당 공격력 보너스 +10%p
const UPG_PACK := 0.05
## FROST: 강화마다 감속이 강해진다 (남는 속도 비율 ×0.88, 최저 0.25)
const FROST_SLOW_STEP := 0.88
const FROST_SLOW_MIN := 0.25
## BOOSTER: 강화마다 맞닿은 타일 공격 속도 보너스 +10%p
const UPG_HASTE := 0.05
## BOOSTER 여러 개가 맞닿으면 가장 센 것만 전부, 나머지는 이 비율만큼 더해진다
const EXTRA_BOOSTER_RATIO := 0.5

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
## LASER: 한 적에게 광선을 꽂은 채 계속 피해 (대상이 죽거나 사거리를 벗어나면 다음 적)
var beam := false
## LASER: 같은 적을 연속으로 맞힐 때마다 공격력 +focus_step, 최대 focus_max번
var focus_step := 0.0
var focus_max := 0
## DRONE HIVE: 띄우는 드론 수
var drones := 0
## CORE: 코어 종류 (CoreDefs). 가운데 모양만 달라진다.
var core_type := "core"
## ARCHER: 맞닿은 ARCHER 1개당 공격력 보너스 (0.4 = +40%)
var pack_bonus := 0.0
## FROST: 감속 시 남는 속도 비율 (낮을수록 강함)
var frost_slow := FROST_SLOW
## BOOSTER: 맞닿은 타일에 주는 공격 속도 보너스 (0.25 = 25% 빠르게)
var haste := 0.0
## BURN: 불길 부채꼴의 반각(라디안)과 화상 시간(초)
var cone := 0.0
var burn_time := 0.0
## SHOCK: 충격파 스턴 시간(초)과 링이 퍼지는 속도 배율 (강화마다 빨라짐)
var stun_time := 0.0
var wave_speed := 1.0
var level := 1
var selected := false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
## 장착한 장비 id들 (GearDefs), 먼저 단 것부터. 최대 gear_slots()개.
var gears: Array[String] = []

var coord := Vector2i.ZERO
var size := 48.0
## 전체 강화 배율(damage_mult, rate_mult)을 읽어 오는 보드.
var board: Board

var _time := 0.0
var _cooldown := 0.0
var _shot_targets: Array[Vector2] = []
var _shot_time := 0.0
## LASER: 적 id별 집중 횟수
var _focus := {}
## LASER: 광선을 꽂은 적들 (최대 target_count()명). 풀린 적이 섞일 수 있어 타입 없는 배열.
var beam_targets: Array = []
var _retarget_cd := 0.0
var _beam_fx: BeamFx
var _hit_flash := 0.0
var _destroyed := false
## ORBIT: 현재 회전 각도와 (구체, 적)마다 다시 때리기까지 남은 시간
var orbit_angle := 0.0
var _orb_hit_cd := {}
var _orbit_ring: OrbitRing
var _frost_field: FrostField
var _drones: Array[Drone] = []
var _flame: FlameJet
var _shock: ShockWave
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
	beam = def.get("beam", false)
	focus_step = def.get("focus_step", 0.0)
	focus_max = def.get("focus_max", 0)
	drones = def.get("drones", 0)
	pack_bonus = def.get("pack", 0.0)
	cone = def.get("cone", 0.0)
	burn_time = def.get("burn_time", 0.0)
	stun_time = def.get("stun", 0.0)
	if attack == "shock" and _shock == null:
		_shock = ShockWave.new()
		_shock.tile = self
		add_child(_shock)
	if attack == "burn" and _flame == null:
		_flame = FlameJet.new()
		_flame.tile = self
		add_child(_flame)
	if attack == "frost" and _frost_field == null:
		_frost_field = FrostField.new()
		_frost_field.tile = self
		add_child(_frost_field)
	if attack == "orbit" and _orbit_ring == null:
		_orbit_ring = OrbitRing.new()
		_orbit_ring.tile = self
		add_child(_orbit_ring)
	if beam and _beam_fx == null:
		_beam_fx = BeamFx.new()
		_beam_fx.tile = self
		add_child(_beam_fx)


## 전체 강화 배율까지 반영한 실제 공격력.
func damage() -> float:
	var d := base_damage * (board.damage_mult * board.skill_damage_mult if board != null else 1.0)
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
	return mini(drones + (1 if has_gear("splitter") else 0), MAX_DRONES)


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
## SHOCK은 파장 주기가 고정이라 공격 속도가 올라도 그대로 (대신 링이 빨리 퍼짐, ShockWave.speed).
func interval() -> float:
	if attack == "shock":
		return fire_interval
	return fire_interval / speed_mult()


## 맞닿은 BOOSTER들이 주는 공격 속도 보너스. 가장 센 것은 전부, 나머지는 EXTRA_BOOSTER_RATIO만큼.
func haste_bonus() -> float:
	if board == null:
		return 0.0
	var hastes: Array[float] = []
	for n in HexGrid.neighbors(coord):
		var t: HexTile = board.tiles.get(n)
		if t != null and t != self and is_instance_valid(t) and t.haste > 0.0:
			hastes.append(t.haste)
	return stack_haste(hastes)


## BOOSTER 보너스 여러 개를 합친 값: 가장 센 것 + 나머지 × EXTRA_BOOSTER_RATIO.
static func stack_haste(hastes: Array[float]) -> float:
	if hastes.is_empty():
		return 0.0
	var sorted := hastes.duplicate()
	sorted.sort()
	var top: float = sorted.pop_back()
	var rest := 0.0
	for h in sorted:
		rest += h
	return top + rest * EXTRA_BOOSTER_RATIO


## 공격 속도 배율 (전체 강화 × BOOSTER). ORBIT 구슬이 도는 속도에도 쓴다.
func speed_mult() -> float:
	return (board.rate_mult if board != null else 1.0) * (1.0 + haste_bonus())


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
	return attack_range * (GearDefs.SCOPE_RANGE_MULT if has_gear("scope") else 1.0)


## 한 번 공격할 때 노리는 대상 수 (SPLITTER면 +1).
func target_count() -> int:
	return 1 + extra_beams + (1 if has_gear("splitter") else 0)


## ORBIT: 실제로 도는 구체 수 (SPLITTER면 +1).
func orb_count() -> int:
	return orbs + (1 if has_gear("splitter") else 0)


## ORBIT: i번째 구체의 위치 (타일 기준 로컬 좌표).
func orb_position(i: int) -> Vector2:
	var a := orbit_angle + TAU * i / orb_count()
	return Vector2(cos(a), sin(a)) * effective_range()


## DETONATOR 폭발 그림을 마지막으로 띄운 시각 (ms)
var _last_blast_ms := -100000


## 장비 칸 수. 기본 1칸, 레벨 GearDefs.SECOND_SLOT_LEVEL부터 2칸.
func gear_slots() -> int:
	return 2 if level >= GearDefs.SECOND_SLOT_LEVEL else 1


func has_gear(gear_id: String) -> bool:
	return gears.has(gear_id)


## 장비 장착. 빈 칸이 있으면 채우고, 칸이 꽉 찼으면 가장 먼저 단 장비를 뺀다.
## 이미 단 장비는 다시 달지 않는다 (같은 장비 2개는 겹치지 않음).
func equip(gear_id: String) -> void:
	if has_gear(gear_id):
		return
	while gears.size() >= gear_slots():
		gears.pop_front()
	gears.append(gear_id)
	queue_redraw()


## 적 하나를 맞혔을 때: 피해 + 장비 효과.
func apply_hit(enemy: Enemy, amount: float) -> void:
	if has_gear("crit") and randf() < GearDefs.CRIT_CHANCE:
		amount *= GearDefs.CRIT_MULT
		enemy.flash_crit()
		Sfx.play("crit")
	var pos := enemy.global_position
	enemy.take_damage(amount, self)
	if has_gear("detonator"):
		_detonate(pos, amount, enemy)
	if has_gear("igniter"):
		enemy.apply_burn(amount * GearDefs.IGNITE_DPS_RATIO, GearDefs.IGNITE_TIME, self)


## DETONATOR: 맞힌 자리 pos(전역)에서 폭발해 주변의 다른 적에게 (맞힌 피해 × 비율).
## 폭발 피해로는 다시 폭발하지 않는다. 성능: 폭발 그림은 타일마다 DETONATE_FX_GAP초에 1번만.
func _detonate(pos: Vector2, amount: float, hit: Enemy) -> void:
	if board == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_blast_ms >= GearDefs.DETONATE_FX_GAP * 1000.0:
		_last_blast_ms = now
		Sfx.play("explode")
		var fx := Explosion.new()
		fx.color = GearDefs.get_def("detonator")["color"]
		fx.radius = GearDefs.DETONATE_RADIUS
		board.enemy_layer.add_child(fx)
		fx.global_position = pos
	var splash := amount * GearDefs.DETONATE_RATIO
	var r2 := GearDefs.DETONATE_RADIUS * GearDefs.DETONATE_RADIUS
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var other := node as Enemy
		if other != null and other != hit and other.is_alive() \
				and pos.distance_squared_to(other.global_position) <= r2:
			other.take_damage(splash, self)


func upgrade_cost() -> int:
	return roundi(25.0 * pow(1.8, level - 1))


func upgrade() -> void:
	level += 1
	base_damage *= UPG_DAMAGE
	if attack_range > 0.0:
		attack_range += UPG_RANGE
	if attack != "shock":
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
		"burn":
			burn_time += FlameJet.UPG_BURN_TIME
		"shock":
			stun_time = minf(stun_time + ShockWave.UPG_STUN, ShockWave.STUN_MAX)
			wave_speed /= UPG_INTERVAL
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level) and not beam:
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
		lines.append(Loc.t("DMG %.1f > %.1f") % [damage(), base_damage * UPG_DAMAGE * mult])
		if attack == "shock":
			lines.append(Loc.t("RANGE +%d    WAVE SPEED +%d%%") % [roundi(UPG_RANGE),
					roundi((1.0 / UPG_INTERVAL - 1.0) * 100.0)])
		else:
			lines.append(Loc.t("RANGE +%d    SPEED +%d%%") % [roundi(UPG_RANGE),
					roundi((1.0 / UPG_INTERVAL - 1.0) * 100.0)])
	match kind:
		"bank":
			lines.append(Loc.t("INCOME $%d > $%d") % [income, income + UPG_INCOME])
			lines.append(Loc.t("INTEREST +%d%%") % roundi(Game.BANK_INTEREST_STEP * 100.0))
		"spark":
			lines.append(Loc.t("+1 BOUNCE"))
		"booster":
			lines.append(Loc.t("HASTE +%d%% > +%d%%") % [roundi(haste * 100.0),
					roundi((haste + UPG_HASTE) * 100.0)])
		"orbit":
			if orbs < MAX_ORBS:
				lines.append(Loc.t("+1 ORB"))
		"drone":
			if DRONE_LEVELS.has(level + 1) and drones < MAX_DRONES:
				lines.append(Loc.t("+1 DRONE"))
		"archer":
			lines.append(Loc.t("PACK +%d%% > +%d%% PER ARCHER") % [roundi(pack_bonus * 100.0),
					roundi((pack_bonus + UPG_PACK) * 100.0)])
		"burn":
			lines.append(Loc.t("BURN %.1f S > %.1f S") % [burn_time, burn_time + FlameJet.UPG_BURN_TIME])
		"shock":
			if stun_time < ShockWave.STUN_MAX:
				lines.append(Loc.t("STUN %.1f S > %.1f S") % [stun_time,
						minf(stun_time + ShockWave.UPG_STUN, ShockWave.STUN_MAX)])
		"frost":
			lines.append(Loc.t("SLOW %d%% > %d%%") % [roundi((1.0 - frost_slow) * 100.0),
					roundi((1.0 - maxf(frost_slow * FROST_SLOW_STEP, FROST_SLOW_MIN)) * 100.0)])
		"laser", "core":
			if EXTRA_BEAM_LEVELS.has(level + 1) and not beam:
				lines.append(Loc.t("+1 BEAM"))
			if focus_max > 0:
				lines.append(Loc.t("FOCUS +%d%% > +%d%% / HIT") % [roundi(focus_step * 100.0),
						roundi((focus_step + UPG_FOCUS) * 100.0)])
	if level + 1 == GearDefs.SECOND_SLOT_LEVEL and takes_gear():
		lines.append(Loc.t("+1 GEAR SLOT"))
	lines.append(Loc.t("HP +%d") % roundi(UPG_HP))
	return lines


## 이 타일에 달 수 있는 장비가 하나라도 있는지 (BANK, BOOSTER 등은 없음).
func takes_gear() -> bool:
	return GearDefs.ids().any(func(id: String) -> bool:
		return (GearDefs.get_def(id)["attacks"] as Array).has(attack))


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
	if beam:
		_process_beam(delta)
	elif attack == "orbit":
		_process_orbit(delta)
	elif attack == "drone":
		_sync_drones()
	elif _cooldown <= 0.0:
		_fire()
	if _flame != null:
		_flame.tick(delta)
	if _shock != null:
		_shock.tick(delta)
	# 밝기 맥동은 다시 그리지 않고 투명도로만
	self_modulate.a = 0.85 + 0.15 * sin(_time * 2.5)
	_redraw_if_needed()


## 성능: 모양이 바뀔 때만 다시 그린다 (매 프레임 다시 그리면 타일이 많을 때 렉이 걸림).
## 광선, 피격 깜빡임, BOOSTER 화살표는 움직이는 동안만 매 프레임 그린다.
func _redraw_if_needed() -> void:
	var anim := _shot_time > 0.0 or _hit_flash > 0.0 or (haste > 0.0 and not boosted_neighbors().is_empty())
	var state := [level, hp, max_hp, gears.duplicate(), focus_stacks(), linked_archers(),
			board != null and board.skill_damage_mult > 1.0, color,
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
	# 공격 속도가 오르면 구슬도 빨리 돈다 (BOOSTER, 전체 강화)
	orbit_angle = fmod(orbit_angle + ORBIT_SPEED * speed_mult() * delta, TAU)
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
				Sfx.play("orbit")
				apply_hit(enemy, damage())


func _fire() -> void:
	match attack:
		"laser":
			_fire_laser()
		"spark":
			var targets := nearest_targets(target_count())
			if not targets.is_empty() and board != null:
				_cooldown = interval()
				Sfx.play("spark")
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
				Sfx.play("arrow")
				for enemy in targets:
					var arrow := Arrow.new()
					arrow.color = color
					arrow.damage = damage()
					arrow.source = self
					board.enemy_layer.add_child(arrow)
					arrow.launch(global_position, enemy)
		"burn":
			if _flame.fire():
				_cooldown = interval()
				Sfx.play("flame")
		"shock":
			if _shock.fire():
				_cooldown = interval()
				Sfx.play("shock")
		"frost":
			var targets := enemies_in_range()
			_cooldown = interval()
			if not targets.is_empty():
				Sfx.play("frost")
			for enemy in targets:
				enemy.apply_slow(frost_slow, FROST_SLOW_TIME)
				apply_hit(enemy, damage())


## CORE: 가까운 적들에게 짧게 번쩍이는 광선.
func _fire_laser() -> void:
	var targets := nearest_targets(target_count())
	if targets.is_empty():
		return
	_shot_targets.clear()
	_shot_time = SHOT_TIME
	_cooldown = interval()
	Sfx.play("core_shot")
	for enemy in targets:
		_shot_targets.append(to_local(enemy.global_position))
	for enemy in targets:
		if enemy.is_alive():
			apply_hit(enemy, damage())


## LASER: 꽂은 광선 유지. 대상이 죽거나 사거리를 벗어나면 놓고, 빈 자리는 가장 가까운 적으로 채운다.
## 피해는 interval()마다 한 번씩. 같은 적에 오래 꽂을수록 집중이 쌓여 세진다.
## 성능: 대상이 꽉 차 있으면 적 전체를 훑지 않고, 빈 자리가 있을 때만 BEAM_RETARGET초마다 찾는다.
func _process_beam(delta: float) -> void:
	_retarget_cd -= delta
	var r := effective_range()
	var lost := false
	for i in range(beam_targets.size() - 1, -1, -1):
		var e = beam_targets[i]
		if not is_instance_valid(e) or not e.is_alive() \
				or global_position.distance_to(e.global_position) > r:
			beam_targets.remove_at(i)
			lost = true
	var want := target_count()
	if beam_targets.size() > want:
		beam_targets.resize(want)
		lost = true
	elif beam_targets.size() < want and (lost or _retarget_cd <= 0.0):
		_retarget_cd = BEAM_RETARGET
		for e in nearest_targets(want + beam_targets.size()):
			if beam_targets.size() >= want:
				break
			if not beam_targets.has(e):
				beam_targets.append(e)
	if lost:
		_prune_focus()
	if beam_targets.is_empty():
		_focus.clear()
		return
	if _cooldown <= 0.0:
		_beam_tick()


## LASER: 꽂힌 적마다 피해 한 번. 집중은 한 번 맞힐 때마다 +1 (최대 focus_max).
func _beam_tick() -> void:
	_cooldown = interval()
	Sfx.play("laser")
	var base := damage()
	var new_focus := {}
	for e in beam_targets:
		var id: int = e.get_instance_id()
		new_focus[id] = mini(int(_focus.get(id, -1)) + 1, focus_max) if focus_max > 0 else 0
	_focus = new_focus
	for e in beam_targets.duplicate():
		if is_instance_valid(e) and e.is_alive():
			apply_hit(e, base * (1.0 + focus_step * int(_focus[e.get_instance_id()])))


## LASER: 더는 꽂혀 있지 않은 적의 집중을 지운다 (새 대상은 0부터).
func _prune_focus() -> void:
	var keep := {}
	for e in beam_targets:
		var id: int = e.get_instance_id()
		if _focus.has(id):
			keep[id] = _focus[id]
	_focus = keep


## LASER: 적 e에 쌓인 집중 정도 (0~1).
func beam_focus(e: Enemy) -> float:
	if focus_max <= 0:
		return 0.0
	return float(_focus.get(e.get_instance_id(), 0)) / focus_max


## LASER: 광선이 지금 누군가에게 꽂혀 있는지. BeamFx가 이걸 보고 그린다.
func beam_active() -> bool:
	return beam and not beam_targets.is_empty()


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
	Sfx.play("tile_hit")
	if hp <= 0.0:
		hp = 0.0
		_destroyed = true
		destroyed.emit(self)


func _draw() -> void:
	# 타일 하나를 그리기 호출 1번으로 (NeonDraw 묶어 그리기)
	NeonDraw.begin(self)
	_draw_parts()
	NeonDraw.flush()


func _draw_parts() -> void:
	var pulse := 1.0
	var c := color.lerp(Color(1.0, 0.15, 0.2), _hit_flash / HIT_FLASH_TIME)
	if selected:
		NeonDraw.arc(self, Vector2.ZERO, effective_range(), 0.0, TAU, 96, Color(c, 0.35), 1.5)
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
		NeonDraw.circle(self, Vector2(x, -size * 0.62), 2.2, c)
	# 체력이 깎였으면 남은 체력을 원호로 표시
	if hp < max_hp:
		var frac := hp / max_hp
		NeonDraw.arc(self, Vector2.ZERO, size * 0.55, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(c, 0.8), 2.0)
	if _shot_time > 0.0:
		for target in _shot_targets:
			NeonDraw.polyline(self, PackedVector2Array([Vector2.ZERO, target]), c,
					_shot_time / SHOT_TIME, minf(2.0 + 0.8 * (level - 1), 6.0))
	if focus_max > 0:
		_draw_focus_meter(c)
	if haste > 0.0:
		_draw_boost_links(c)
	if pack_bonus > 0.0:
		_draw_pack_links(c)
	if not gears.is_empty():
		_draw_gear_badges()


## LASER: 집중 게이지. 가운데 삼각형 둘레에 쌓인 만큼 짧은 호가 켜진다.
func _draw_focus_meter(c: Color) -> void:
	var stacks := focus_stacks()
	if stacks <= 0:
		return
	var r := size * 0.46
	var seg := TAU / focus_max
	for i in stacks:
		var a0 := -PI / 2.0 + seg * i + 0.08
		NeonDraw.arc(self, Vector2.ZERO, r, a0, a0 + seg - 0.16, 8, Color(c.lerp(Color.WHITE, 0.3), 0.9), 2.5)


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


## 장비 표시: 타일 아래쪽 꼭짓점 근처의 작은 다이아몬드 배지. 칸마다 하나씩 나란히,
## 장비를 하나라도 단 타일에 빈 칸이 남아 있으면 그 칸은 흐린 테두리만.
func _draw_gear_badges() -> void:
	var slots := gear_slots()
	var r := 6.0
	var gap := r * 2.6
	for i in slots:
		var center := Vector2((i - (slots - 1) * 0.5) * gap, size * 0.62)
		var dia := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0),
				center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
		if i < gears.size():
			var gc: Color = GearDefs.get_def(gears[i])["color"]
			NeonDraw.fill(self, dia, Color(gc, 0.35))
			NeonDraw.polyline(self, dia, gc, 1.0, 1.5)
		else:
			NeonDraw.polyline(self, dia, Color(1, 1, 1, 0.35), 0.6, 1.0)


## 종류마다 가운데 모양을 다르게 그린다.
func _draw_glyph(c: Color, intensity: float) -> void:
	var glyph := kind
	if kind == "core" and core_type != "core":
		glyph = "core_" + core_type
	draw_glyph(self, glyph, size * 0.3, c, intensity)
	# OVERDRIVE 중인 공격 타일: 바깥 테두리가 하나 더
	if board != null and board.skill_damage_mult > 1.0 and attack != "none":
		NeonDraw.hexagon(self, Vector2.ZERO, size * 1.0, Color(1.0, 0.95, 0.6), 0.8, 2.0)


## 타일 종류별 아이콘. canvas의 원점에 반지름 r 크기로 그린다 (상점 화면에서도 사용).
static func draw_glyph(canvas: CanvasItem, kind: String, r: float, c: Color, intensity: float,
		angle := 0.0) -> void:
	match kind:
		"core":
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
		"core_cryo":
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
			for i in 3:
				var d := Vector2.from_angle(PI * i / 3.0) * r * 0.6
				NeonDraw.line(canvas, PackedVector2Array([-d, d]), Color(c, intensity), 1.5)
		"core_aegis":
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
			NeonDraw.line(canvas, PackedVector2Array([Vector2(0, -r * 0.55), Vector2(0, r * 0.55)]), Color(c, intensity), 2.5)
			NeonDraw.line(canvas, PackedVector2Array([Vector2(-r * 0.55, 0), Vector2(r * 0.55, 0)]), Color(c, intensity), 2.5)
		"core_nova":
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
			NeonDraw.circle(canvas, Vector2.ZERO, r * 0.22, Color(c, intensity))
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0 + PI / 6.0)
				NeonDraw.line(canvas, PackedVector2Array([d * r * 0.35, d * r * 0.7]), Color(c, intensity), 1.5)
		"core_warp":
			# 가운데 점 + 바깥으로 향하는 꺾쇠 셋 (날려 보냄)
			NeonDraw.hexagon(canvas, Vector2.ZERO, r, c, intensity * 0.8, 2.0)
			NeonDraw.circle(canvas, Vector2.ZERO, r * 0.16, Color(c, intensity))
			for i in 3:
				var d := Vector2.from_angle(-PI / 2.0 + TAU * i / 3.0)
				var side := d.orthogonal() * r * 0.2
				var tip := d * r * 0.68
				var back := d * r * 0.42
				NeonDraw.line(canvas, PackedVector2Array([back + side, tip, back - side]), Color(c, intensity), 1.8)
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
			NeonDraw.arc(canvas, Vector2.ZERO, r * 0.85, 0.0, TAU, 32, Color(c, 0.5 * intensity), 1.5)
			NeonDraw.circle(canvas, Vector2.ZERO, r * 0.25, Color(c, intensity))
			var a := angle
			NeonDraw.circle(canvas, Vector2(cos(a), sin(a)) * r * 0.85, r * 0.22, Color(c, intensity))
		"drone":
			# 가운데 작은 육각형(벌집) + 둘레의 드론 세 개
			NeonDraw.hexagon(canvas, Vector2.ZERO, r * 0.45, c, intensity * 0.8, 2.0)
			for i in 3:
				var d := Vector2.from_angle(-PI / 2.0 + TAU * i / 3.0) * r * 0.95
				NeonDraw.circle(canvas, d, r * 0.22, Color(c, intensity))
		"archer":
			# 활: 왼쪽 반원 + 시위, 오른쪽으로 화살
			NeonDraw.arc(canvas, Vector2(r * 0.1, 0), r * 0.85, PI * 0.55, PI * 1.45, 16, Color(c, intensity), 2.0)
			var top := Vector2(r * 0.1, 0) + Vector2.from_angle(PI * 0.55) * r * 0.85
			var bot := Vector2(r * 0.1, 0) + Vector2.from_angle(PI * 1.45) * r * 0.85
			NeonDraw.polyline(canvas, PackedVector2Array([top, Vector2(-r * 0.15, 0), bot]),
					c, intensity * 0.6, 1.5)
			NeonDraw.polyline(canvas, PackedVector2Array([Vector2(-r * 0.15, 0), Vector2(r, 0)]),
					c, intensity * 0.8, 2.0)
			NeonDraw.polyline(canvas, PackedVector2Array([Vector2(r * 0.65, -r * 0.3),
					Vector2(r, 0), Vector2(r * 0.65, r * 0.3)]), c, intensity * 0.8, 2.0)
		"burn":
			# 불꽃: 바깥 불길 + 안쪽 작은 불길
			var outer := PackedVector2Array([Vector2(0, -r * 1.05), Vector2(r * 0.3, -r * 0.45),
					Vector2(r * 0.62, r * 0.05), Vector2(r * 0.55, r * 0.55), Vector2(0, r * 0.88),
					Vector2(-r * 0.55, r * 0.55), Vector2(-r * 0.62, r * 0.05), Vector2(-r * 0.4, -r * 0.3),
					Vector2(-r * 0.22, r * 0.05), Vector2(-r * 0.1, -r * 0.6), Vector2(0, -r * 1.05)])
			NeonDraw.polyline(canvas, outer, c, intensity * 0.8, 2.0)
			var inner := PackedVector2Array([Vector2(0, -r * 0.2), Vector2(r * 0.25, r * 0.3),
					Vector2(0, r * 0.6), Vector2(-r * 0.25, r * 0.3), Vector2(0, -r * 0.2)])
			NeonDraw.polyline(canvas, inner, c.lerp(FlameJet.HOT, 0.6), intensity * 0.7, 1.5)
		"shock":
			# 가운데 점 + 양옆으로 퍼지는 물결 두 겹 (충격파)
			NeonDraw.circle(canvas, Vector2.ZERO, r * 0.2, Color(c, intensity))
			for k in 2:
				var rr := r * (0.55 + 0.42 * k)
				var w := intensity * (0.8 - 0.25 * k)
				for side in 2:
					var pts := PackedVector2Array()
					for j in 9:
						pts.append(Vector2.from_angle(PI * side + lerpf(-0.85, 0.85, j / 8.0)) * rr)
					NeonDraw.polyline(canvas, pts, c, w, 2.0)
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
