class_name Enemy
extends Node2D
## 화면 밖에서 나타나 가장 가까운 타일로 다가가는 적.
## 타일에 닿으면 피해를 주고 사라지며, 처치되면 보상금을 준다.
## 종류(kind)별 모양과 능력은 EnemyDefs 참고. armor는 받는 피해 감소 비율(0~1).

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
var kind := "grunt"
var sides := 3
var star := false
var armor := 0.0
## 처치되면 이 종류의 적으로 split_count마리 갈라진다 (빈 문자열이면 없음)
var splits_into := ""
var split_count := 0
## 근접형(보스): 닿아도 사라지지 않고 hit_interval초마다 때린다
var melee := false
var hit_interval := 1.0
var _hit_cd := 0.0
var _lunge := 0.0
## 처치당해 죽었는지 (타일에 부딪혀 사라지면 false)
var killed := false

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


## 종류와 웨이브 기본 능력치로 설정한다. add_child 전에 호출.
func setup(enemy_kind: String, base_hp: float, base_speed: float, base_reward: int,
		base_contact: float) -> void:
	var def := EnemyDefs.get_def(enemy_kind)
	kind = enemy_kind
	color = def["color"]
	sides = def["sides"]
	star = def["star"]
	radius = def["radius"]
	armor = def["armor"]
	max_hp = base_hp * def["hp"]
	hp = max_hp
	speed = base_speed * def["speed"]
	reward = maxi(1, roundi(base_reward * def["reward"]))
	contact_damage = base_contact * def["contact"]
	splits_into = def.get("splits_into", "")
	split_count = def.get("split_count", 0)
	melee = def.get("melee", false)
	hit_interval = def.get("hit_interval", 1.0)


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
		# 불을 붙인 타일이 이미 부서졌을 수 있다
		var src: HexTile = _burn_source if is_instance_valid(_burn_source) else null
		take_damage(_burn_dps * delta, src)
		if _dead:
			return
	var target := board.nearest_tile(global_position)
	if target == null:
		return
	var to_target := target.global_position - global_position
	_lunge = maxf(_lunge - delta * 4.0, 0.0)
	if melee:
		# 타일 가장자리에 붙어서 hit_interval초마다 때린다. 사라지지 않는다.
		_hit_cd -= delta
		if to_target.length() <= board.hex_size * 0.85 + radius * 0.6:
			if _hit_cd <= 0.0:
				_hit_cd = hit_interval
				_lunge = 1.0
				target.take_damage(contact_damage)
			_spin += delta * 3.0
			_crit_flash = maxf(_crit_flash - delta, 0.0)
			queue_redraw()
			return
	elif to_target.length() <= board.hex_size * 0.8:
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


## 분열로 태어난 적이 부모의 감속(빙결) 상태를 남은 시간 그대로 이어받는다.
func inherit_slow(parent: Enemy) -> void:
	if parent.is_slowed():
		apply_slow(parent._slow_factor, parent._slow_timer)


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
	hp -= amount * (1.0 - armor)
	if hp <= 0.0:
		_die(true)
	else:
		queue_redraw()


func _die(was_killed: bool) -> void:
	_dead = true
	killed = was_killed
	remove_from_group(GROUP)
	var bonus := 0
	if was_killed and is_instance_valid(_last_source) and _last_source.gear == "collector":
		bonus = GearDefs.COLLECTOR_BONUS
	died.emit(self, reward + bonus if was_killed else 0)
	queue_free()


## 종류에 따른 외곽선 점들 (닫힌 도형).
func shape_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if star:
		for i in sides * 2 + 1:
			var a := _spin * 0.5 + PI * i / sides
			var r := radius if i % 2 == 0 else radius * 0.5
			pts.append(Vector2(cos(a), sin(a)) * r)
	else:
		for i in sides + 1:
			var a := _spin + TAU * i / sides
			pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _draw() -> void:
	var pts := shape_points()
	if _lunge > 0.0:
		# 근접 공격 순간 잠깐 부풀었다 돌아온다
		for i in pts.size():
			pts[i] *= 1.0 + 0.2 * _lunge
	var c := color.lerp(Color(0.6, 0.8, 1.0), 0.6) if is_slowed() else color
	if _crit_flash > 0.0:
		c = Color.WHITE
	elif is_burning():
		c = c.lerp(Color(1.0, 0.6, 0.1), 0.5 + 0.3 * sin(_spin * 6.0))
	NeonDraw.polyline(self, pts, c, 1.0, 3.5 if kind == "boss" else 2.5)
	if armor > 0.0:
		# 장갑: 안쪽에 같은 모양을 한 겹 더
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(p * 0.55)
		NeonDraw.polyline(self, inner, c, 0.7, 1.5)
	if hp < max_hp:
		var w := radius * 2.0
		var y := radius + 6.0
		draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Color(color, 0.25), 2.0)
		draw_line(Vector2(-w / 2.0, y), Vector2(-w / 2.0 + w * hp / max_hp, y), color, 2.0)
