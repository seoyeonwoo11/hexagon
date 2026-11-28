class_name Enemy
extends Node2D
## 화면 밖에서 나타나 가장 가까운 타일로 다가가는 적.
## 타일에 닿으면 피해를 주고 사라지며, 처치되면 보상금을 준다.
## 종류(kind)별 모양과 능력은 EnemyDefs 참고. armor는 받는 피해 감소 비율(0~1).

signal died(enemy: Enemy, reward: int)
## 보스가 부하를 부를 때. Game이 받아서 enemy 주변에 kind를 count마리 만든다.
signal summoned(enemy: Enemy, kind: String, count: int)

const GROUP := &"enemies"
## 화상 피해를 몰아서 주는 간격(초). 매 프레임 주면 불붙은 적이 많을 때 체력 막대를 계속 다시 그려 렉이 걸린다.
const BURN_TICK := 0.25

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
## 보스 (BOSS, OVERLORD): NOVA 스킬이 덜 아프고 위에 체력 막대가 뜬다
var is_boss := false
## 부하 소환 (OVERLORD)
var summon_kind := ""
var summon_count := 0
var summon_every := 0.0
var _summon_cd := 0.0
## 분노: 체력이 enrage_at 비율 아래면 enrage_speed배 빨라지고 두 배 자주 부른다
var enrage_at := 0.0
var enrage_speed := 1.0
var enraged := false
## 처치당해 죽었는지 (타일에 부딪혀 사라지면 false)
var killed := false

var _dead := false
var _spin := 0.0
var _slow_factor := 1.0
var _slow_timer := 0.0
var _burn_dps := 0.0
var _burn_timer := 0.0
var _burn_source: HexTile
var _burn_acc := 0.0
## BURN 타일의 불: 맞닿은 적에게 몇 번 더 옮겨붙을 수 있는지 (0이면 안 옮겨붙음)
var burn_spread := 0
## 마지막으로 피해를 준 타일
var _last_source: HexTile
var _crit_flash := 0.0
## 코어 스킬 FREEZE: 남은 정지 시간. 그동안 움직이지도 때리지도 않는다.
var _freeze_timer := 0.0
## 성능: 도는 몸체는 자식 노드로 그리고 회전은 rotation으로. 색/모양이 바뀔 때만 다시 그린다.
var _body: _Body


## 종류와 웨이브 기본 능력치로 설정한다. add_child 전에 호출.
func setup(enemy_kind: String, base_hp: float, base_speed: float, base_reward: float,
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
	is_boss = def.get("is_boss", false)
	summon_kind = def.get("summon", "")
	summon_count = def.get("summon_count", 0)
	summon_every = def.get("summon_every", 0.0)
	_summon_cd = summon_every
	enrage_at = def.get("enrage_at", 0.0)
	enrage_speed = def.get("enrage_speed", 1.0)


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp
	_body = _Body.new()
	_body.enemy = self
	add_child(_body)
	_body.sync()


func _process(delta: float) -> void:
	if _dead or board == null:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	if _burn_timer > 0.0:
		var dt := minf(delta, _burn_timer)
		_burn_timer -= delta
		_burn_acc += dt
		if _burn_acc >= BURN_TICK - 0.001 or _burn_timer <= 0.0:
			# 불을 붙인 타일이 이미 부서졌을 수 있다
			var src: HexTile = _burn_source if is_instance_valid(_burn_source) else null
			take_damage(_burn_dps * _burn_acc, src)
			_burn_acc = 0.0
			if _dead:
				return
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _body != null:
			_body.sync()
		return
	if summon_kind != "":
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = summon_every * (0.5 if enraged else 1.0)
			_lunge = 1.0
			summoned.emit(self, summon_kind, summon_count)
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
			_update_body(delta)
			return
	elif to_target.length() <= board.hex_size * 0.8:
		target.take_damage(contact_damage)
		_die(false)
		return
	global_position += to_target.normalized() * speed * _slow_factor * delta
	_update_body(delta)


func _update_body(delta: float) -> void:
	_spin += delta * 3.0
	_crit_flash = maxf(_crit_flash - delta, 0.0)
	if _body == null:
		return
	_body.rotation = _spin * 0.5 if star else _spin
	_body.sync()


## 코어 스킬 FREEZE: duration초 동안 멈춘다.
func freeze(duration: float) -> void:
	_freeze_timer = maxf(_freeze_timer, duration)
	if _body != null:
		_body.sync()


func is_frozen() -> bool:
	return _freeze_timer > 0.0


## 몸체 색: 정지(하얀 얼음), 감속(파랑), 치명타(하양), 화상(주황 깜빡임).
func body_color() -> Color:
	if is_frozen():
		return Color(0.8, 0.95, 1.0)
	if enraged and _crit_flash <= 0.0:
		# 분노: 붉게 맥동
		return color.lerp(Color(1.0, 0.15, 0.2), 0.55 + 0.35 * sin(_spin * 4.0))
	var c := color.lerp(Color(0.6, 0.8, 1.0), 0.6) if is_slowed() else color
	if _crit_flash > 0.0:
		c = Color.WHITE
	elif is_burning():
		c = c.lerp(Color(1.0, 0.6, 0.1), 0.5 + 0.3 * sin(_spin * 6.0))
	return c


## factor 배 속도로 duration초 동안 느려진다 (여러 번 걸리면 가장 강한 감속 유지).
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)


## 화상: duration초 동안 초당 dps 피해. 더 센 화상으로 덮어쓴다.
## spread: BURN 타일의 불이면 맞닿은 적에게 옮겨붙을 수 있는 남은 횟수.
func apply_burn(dps: float, duration: float, source: HexTile = null, spread := 0) -> void:
	if dps >= _burn_dps or _burn_timer <= 0.0:
		_burn_dps = dps
		_burn_source = source
		burn_spread = spread
	_burn_timer = maxf(_burn_timer, duration)


## 지금 화상의 초당 피해 (안 타고 있으면 0).
func burn_dps() -> float:
	return _burn_dps if _burn_timer > 0.0 else 0.0


## 화상을 붙인 타일 (안 타고 있거나 그 타일이 부서졌으면 null).
func burn_source() -> HexTile:
	if _burn_timer <= 0.0 or not is_instance_valid(_burn_source):
		return null
	return _burn_source


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
	var dealt := minf(amount * (1.0 - armor), hp)
	if source != null:
		_last_source = source
		if source.board != null:
			source.board.stats.record(source, dealt)
	hp -= amount * (1.0 - armor)
	if hp <= 0.0:
		_die(true)
		return
	if enrage_at > 0.0 and not enraged and hp < max_hp * enrage_at:
		enraged = true
		speed *= enrage_speed
	queue_redraw()


func _die(was_killed: bool) -> void:
	_dead = true
	killed = was_killed
	remove_from_group(GROUP)
	died.emit(self, reward if was_killed else 0)
	queue_free()


## 종류에 따른 외곽선 점들 (닫힌 도형).
func shape_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if star:
		for i in sides * 2 + 1:
			var a := PI * i / sides
			var r := radius if i % 2 == 0 else radius * 0.5
			pts.append(Vector2(cos(a), sin(a)) * r)
	else:
		for i in sides + 1:
			var a := TAU * i / sides
			pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


## 체력 막대만 여기서 그린다 (피해를 받을 때만 다시 그림). 몸체는 _Body.
func _draw() -> void:
	if hp < max_hp:
		var w := radius * 2.0
		var y := radius + 6.0
		draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Color(color, 0.25), 2.0)
		draw_line(Vector2(-w / 2.0, y), Vector2(-w / 2.0 + w * hp / max_hp, y), color, 2.0)


## 적의 몸체 (도는 도형). 근접 공격 때 잠깐 부풀어 오른다 (scale).
class _Body extends Node2D:
	var enemy: Enemy
	var _drawn_color := Color(0, 0, 0, 0)

	func sync() -> void:
		scale = Vector2.ONE * (1.0 + 0.2 * enemy._lunge)
		var c := enemy.body_color()
		if not c.is_equal_approx(_drawn_color):
			_drawn_color = c
			queue_redraw()

	func _draw() -> void:
		NeonDraw.begin(self)
		_draw_parts()
		NeonDraw.flush()

	func _draw_parts() -> void:
		var pts := enemy.shape_points()
		var c := _drawn_color
		NeonDraw.polyline(self, pts, c, 1.0, 3.5 if enemy.is_boss else 2.5)
		if enemy.summon_kind != "":
			# 최종 보스: 바깥 왕관 고리 (별 끝마다 작은 삼각형)
			var ring := PackedVector2Array()
			var r := enemy.radius * 1.3
			for i in 33:
				ring.append(Vector2.from_angle(TAU * i / 32.0) * r)
			NeonDraw.polyline(self, ring, c, 0.6, 2.0)
			for i in enemy.sides:
				var a := TAU * i / enemy.sides + PI / enemy.sides
				var d := Vector2.from_angle(a)
				var n := d.orthogonal() * 7.0
				var tip := PackedVector2Array([d * r + n, d * (r + 14.0), d * r - n])
				NeonDraw.polyline(self, tip, c, 0.9, 2.0)
		if enemy.armor > 0.0:
			# 장갑: 안쪽에 같은 모양을 한 겹 더
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p * 0.55)
			NeonDraw.polyline(self, inner, c, 0.7, 1.5)
