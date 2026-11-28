class_name Enemy
extends Node2D
## 화면 밖에서 나타나 가장 가까운 타일로 다가가는 적.
## 타일에 닿으면 피해를 주고 사라지며, 처치되면 보상금을 준다.
## 종류(kind)별 모양과 능력은 EnemyDefs 참고. armor는 받는 피해 감소 비율(0~1).
## 기믹: 돌진(DASHER, COMET), 주변 회복/보호막(MENDER, AEGIS, BASTION), 은신(PHANTOM, WRAITH),
## 체력 구간 소환(MONOLITH). 은신 중에는 is_alive()가 false라 타일이 노리지 않고 피해도 안 받는다.

signal died(enemy: Enemy, reward: int)
## 보스가 부하를 부를 때 (시간마다, 은신할 때, 체력 구간). Game이 받아서 enemy 주변에 kind를 count마리 만든다.
signal summoned(enemy: Enemy, kind: String, count: int)

const GROUP := &"enemies"
## 화상 피해를 몰아서 주는 간격(초). 매 프레임 주면 불붙은 적이 많을 때 체력 막대를 계속 다시 그려 렉이 걸린다.
const BURN_TICK := 0.25
## SHOCK 스턴: 보스는 이 비율만큼만 멈춘다. 스턴이 풀린 뒤 이 시간(초) 동안은 다시 스턴되지 않는다
## (SHOCK 여러 개로 계속 묶어 두지 못하게).
const BOSS_STUN_MULT := 0.35
const STUN_GRACE := 1.0
## 은신 중 투명도. 타일은 못 노리지만 플레이어 눈에는 흐릿하게 보인다
const CLOAK_ALPHA := 0.4
## 회복/보호막 파동이 퍼지는 연출 시간(초)
const PULSE_TIME := 0.45
## 보호막 색
const SHIELD_COLOR := Color(0.65, 0.85, 1.0)

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
## 스테이지 마지막 보스 (화면 위 체력 막대, 잡으면 클리어)
var is_final := false
## 돌지 않고 가는 방향을 본다 (DASHER)
var face := false
var _heading := Vector2.RIGHT
## 돌진: dash_every초마다 dash_time초 동안 dash_speed배. dash_windup초 멈춘 뒤 돌진, 첫 근접 타격 dash_hit배
var dash_every := 0.0
var dash_time := 0.0
var dash_speed := 1.0
var dash_windup := 0.0
var dash_hit := 1.0
## 돌진 준비와 돌진 중에는 감속, 빙결(FREEZE), 스턴(SHOCK), WARP 밀치기를 무시한다 (COMET)
var dash_unstoppable := false
var _dash_cd := 0.0
var _dash_left := 0.0
var _windup_left := 0.0
var _dash_hit_ready := false
const DASH_CHASE_MAX := 1.5
var _dash_over := 0.0
## 들이받은 뒤 튕겨 돌아가기 (COMET): 돌진을 시작한 자리로 RECOIL_TIME초 동안 빠르게, 끝에서 느려지게.
## 그동안은 때리지도 쫓지도 않는다.
const RECOIL_TIME := 0.85
## 들이받는 순간 잠깐 멈추는 시간(히트스톱)과 화면 흔들림 세기(픽셀)
const HITSTOP := 0.14
const SHAKE := 14.0
## COMET 꼬리가 몸 회전을 따라가는 빠르기(클수록 빨리 따라옴)와 최대로 휘는 각도
const TAIL_FOLLOW := 9.0
const TAIL_BEND_MAX := 1.3
var _hitstop := 0.0
var _dash_origin := Vector2.ZERO
var _recoil_from := Vector2.ZERO
var _recoil_left := 0.0
## 주변 회복/보호막 ("heal", "shield")
var aura := ""
var aura_every := 0.0
var aura_radius := 0.0
var aura_amount := 0.0
var aura_boss := 0.0
var _aura_cd := 0.0
var _pulse := 0.0
## 보호막: 체력보다 먼저 깎인다 (장갑은 먼저 적용)
var shield := 0.0
## 은신: cloak_every초 보이다가 cloak_time초 숨는다
var cloak_every := 0.0
var cloak_time := 0.0
var cloak_regen := 0.0
var cloak_summon := false
var _cloak_cd := 0.0
var _cloak_left := 0.0
## 체력 구간 소환: quake_at 비율 아래로 처음 떨어질 때마다 quake_kind를 quake_count마리
var quake_at: Array = []
var quake_kind := ""
var quake_count := 0
var _quake_next := 0
var crown := false
## 몸체 회전 속도 배율 (0이면 안 돎), 좌우로 흔들리는 폭 (라디안, WRAITH)
var spin_rate := 1.0
var sway := 0.0
## 보스 장식: 몸체 밖에서 따로 도는 부품 (MONOLITH 돌조각, WRAITH 룬 고리, BASTION 방패판, OVERLORD 위성)
var deco_spin := 0.0
var _deco: _Deco
## COMET 조준선 길이 (돌진 준비 중 목표 타일까지)
var _aim_len := 0.0

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
## SHOCK 스턴 면역이 남은 시간 (스턴 시간 + STUN_GRACE)
var _stun_immune := 0.0
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
	is_final = def.get("final", false)
	crown = def.get("crown", false)
	spin_rate = def.get("spin", 1.0)
	sway = def.get("sway", 0.0)
	deco_spin = def.get("deco_spin", 0.0)
	face = def.get("face", false)
	dash_every = def.get("dash_every", 0.0)
	dash_time = def.get("dash_time", 0.0)
	dash_speed = def.get("dash_speed", 1.0)
	dash_windup = def.get("dash_windup", 0.0)
	dash_hit = def.get("dash_hit", 1.0)
	dash_unstoppable = def.get("dash_unstoppable", false)
	# 같은 종류가 한꺼번에 돌진하지 않게 첫 주기는 조금씩 다르게
	_dash_cd = dash_every * randf_range(0.5, 1.0)
	aura = def.get("aura", "")
	aura_every = def.get("aura_every", 0.0)
	aura_radius = def.get("aura_radius", 0.0)
	aura_amount = def.get("aura_amount", 0.0)
	aura_boss = def.get("aura_boss", 0.0)
	_aura_cd = aura_every * randf_range(0.6, 1.0)
	cloak_every = def.get("cloak_every", 0.0)
	cloak_time = def.get("cloak_time", 0.0)
	cloak_regen = def.get("cloak_regen", 0.0)
	cloak_summon = def.get("cloak_summon", false)
	_cloak_cd = cloak_every * randf_range(0.7, 1.0)
	quake_at = def.get("quake_at", [])
	quake_kind = def.get("quake", "")
	quake_count = def.get("quake_count", 0)


func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp
	_body = _Body.new()
	_body.enemy = self
	add_child(_body)
	_body.sync()
	if deco_spin != 0.0:
		_deco = _Deco.new()
		_deco.enemy = self
		add_child(_deco)
		_deco.sync()


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
	if _stun_immune > 0.0:
		_stun_immune -= delta
	# 은신은 얼어 있어도 풀린다 (FREEZE로 계속 숨어 있지 않게)
	if cloak_every > 0.0:
		_process_cloak(delta)
	_pulse = maxf(_pulse - delta / PULSE_TIME, 0.0)
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _body != null:
			_body.sync()
		return
	if summon_kind != "" and summon_every > 0.0:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = summon_every * (0.5 if enraged else 1.0)
			_lunge = 1.0
			summoned.emit(self, summon_kind, summon_count)
	if aura != "":
		_aura_cd -= delta
		if _aura_cd <= 0.0:
			_aura_cd = aura_every
			pulse_aura()
	if _hitstop > 0.0:
		_hitstop -= delta
		if _body != null:
			_body.sync()
		return
	if _recoil_left > 0.0:
		_process_recoil(delta)
		return
	var target := board.nearest_tile(global_position)
	if target == null:
		return
	var to_target := target.global_position - global_position
	_lunge = maxf(_lunge - delta * 4.0, 0.0)
	if face and to_target.length_squared() > 1.0:
		_heading = to_target.normalized()
	var move_mult := 1.0
	if dash_every > 0.0:
		move_mult = _process_dash(delta)
		_aim_len = to_target.length() if _windup_left > 0.0 else 0.0
	if melee:
		# 타일 가장자리에 붙어서 hit_interval초마다 때린다. 사라지지 않는다.
		# 돌진하다 닿으면 기다리지 않고 바로 dash_hit배로 들이받고 돌진이 끝난다.
		_hit_cd -= delta
		if to_target.length() <= board.hex_size * 0.85 + radius * 0.6:
			if _hit_cd <= 0.0 or _dash_hit_ready:
				_hit_cd = hit_interval
				_lunge = 1.0
				target.take_damage(contact_damage * (dash_hit if _dash_hit_ready else 1.0))
				if _dash_hit_ready:
					_dash_hit_ready = false
					_dash_left = 0.0
					_impact(global_position + to_target.normalized() * radius)
			_update_body(delta)
			return
	elif to_target.length() <= board.hex_size * 0.8:
		target.take_damage(contact_damage)
		_die(false)
		return
	var slow := 1.0 if cc_immune() else _slow_factor
	global_position += to_target.normalized() * speed * slow * move_mult * delta
	_update_body(delta)


## 돌진 타이머. 이번 프레임 이동 속도 배율을 돌려준다 (기를 모으는 동안은 0).
func _process_dash(delta: float) -> float:
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_start_dash()
		return 0.0
	if _dash_left > 0.0:
		_dash_left -= delta
		if _dash_left <= 0.0:
			if _dash_hit_ready and _dash_over < DASH_CHASE_MAX:
				# 들이받는 돌진은 dash_time이 지나도 타일에 닿을 때까지 이어간다 (최대 DASH_CHASE_MAX초 더)
				_dash_over += delta
				_dash_left = 0.001
			else:
				_dash_hit_ready = false
		return dash_speed
	_dash_cd -= delta
	if _dash_cd <= 0.0:
		_dash_cd = dash_every
		if dash_windup > 0.0:
			_windup_left = dash_windup
			if dash_unstoppable:
				_slow_timer = 0.0
				_slow_factor = 1.0
			Sfx.play("boss_charge")
			return 0.0
		_start_dash()
		return dash_speed
	return 1.0


## 돌진 첫 타격: 히트스톱(잠깐 멈춤) + 화면 흔들림 + 충격 고리 세 겹 + 낮은 쿵 소리,
## 그다음 돌진을 시작한 자리로 튕겨 돌아가기 시작.
func _impact(at: Vector2) -> void:
	Sfx.play("quake")
	Sfx.play("explode")
	Sfx.play("tile_hit")
	var layer := get_parent()
	if layer != null:
		for k in 3:
			var fx := Explosion.new()
			fx.color = color.lerp(Color.WHITE, 0.3 * k)
			fx.radius = radius * (3.0 - k * 0.9)
			layer.add_child(fx)
			fx.global_position = at
	_shake_camera()
	_hitstop = HITSTOP
	_recoil_from = global_position
	_recoil_left = RECOIL_TIME
	_lunge = 1.0


## 화면을 짧게 흔든다 (카메라 offset, 점점 약하게). 카메라가 없으면 (테스트) 아무것도 안 함.
func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return
	var tw := cam.create_tween()
	for i in 7:
		var power := SHAKE * (1.0 - i / 7.0)
		tw.tween_property(cam, "offset", Vector2.from_angle(randf() * TAU) * power, 0.035)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


## 튕겨 돌아가는 중: 무거운 물체처럼 처음에 확 튕겨 나갔다가 길게 미끄러지며 멈춘다 (ease out quart).
## 몸은 위치와 따로 한 바퀴 돈다. 부딪히자마자 적당한 속도로 돌기 시작해 천천히 멈춘다 (sine ease-out).
## 끝나면 정확히 한 바퀴라 다시 목표를 바라보는 방향과 이어진다.
func _process_recoil(delta: float) -> void:
	_recoil_left = maxf(_recoil_left - delta, 0.0)
	var k := 1.0 - _recoil_left / RECOIL_TIME
	var heavy := 1.0 - pow(1.0 - k, 4.0)
	global_position = _recoil_from.lerp(_dash_origin, heavy)
	_lunge = maxf(_lunge - delta * 1.5, 0.0)
	_update_body(delta)
	if _body != null and face:
		var spin := sin(k * PI * 0.5)
		_body.rotation = _heading.angle() + TAU * spin


func is_recoiling() -> bool:
	return _recoil_left > 0.0


func _start_dash() -> void:
	_dash_origin = global_position
	_dash_over = 0.0
	_dash_left = dash_time
	_dash_hit_ready = dash_hit > 1.0
	_lunge = 1.0
	Sfx.play("dash")


## 돌진 준비나 돌진 중이라 군중 제어(감속, 빙결, 스턴, 밀치기)가 안 먹히는지.
func cc_immune() -> bool:
	return dash_unstoppable and (_windup_left > 0.0 or _dash_left > 0.0)


func is_dashing() -> bool:
	return _dash_left > 0.0


func is_winding_up() -> bool:
	return _windup_left > 0.0


## 은신 타이머. 숨을 때 cloak_summon이면 부하를 부르고, 숨어 있는 동안 cloak_regen만큼 회복.
func _process_cloak(delta: float) -> void:
	if _cloak_left > 0.0:
		_cloak_left -= delta
		if cloak_regen > 0.0 and hp < max_hp:
			hp = minf(hp + max_hp * cloak_regen * delta, max_hp)
			queue_redraw()
		if _cloak_left <= 0.0:
			_cloak_cd = cloak_every
			modulate.a = 1.0
		return
	_cloak_cd -= delta
	if _cloak_cd <= 0.0:
		cloak()


## 지금부터 cloak_time초 동안 숨는다.
func cloak() -> void:
	_cloak_left = cloak_time
	modulate.a = CLOAK_ALPHA
	Sfx.play("cloak")
	if cloak_summon and summon_kind != "":
		summoned.emit(self, summon_kind, summon_count)


func is_cloaked() -> bool:
	return _cloak_left > 0.0


## 주변 aura_radius 안 적(자기 포함)에게 회복이나 보호막. 보스는 aura_boss 비율만.
func pulse_aura() -> void:
	var r2 := aura_radius * aura_radius
	for node in get_tree().get_nodes_in_group(GROUP):
		var e := node as Enemy
		if e == null or e._dead or e.global_position.distance_squared_to(global_position) > r2:
			continue
		var amount := e.max_hp * (aura_boss if e.is_boss else aura_amount)
		if aura == "heal":
			e.heal(amount)
		else:
			e.add_shield(amount)
	_pulse = 1.0
	Sfx.play("heal" if aura == "heal" else "shield")


func heal(amount: float) -> void:
	if _dead or hp >= max_hp:
		return
	hp = minf(hp + amount, max_hp)
	queue_redraw()


## 보호막: 쌓이지 않고 더 큰 쪽으로.
func add_shield(amount: float) -> void:
	if _dead or amount <= shield:
		return
	shield = amount
	queue_redraw()
	if _body != null:
		_body.sync()


func _update_body(delta: float) -> void:
	_spin += delta * 3.0
	_crit_flash = maxf(_crit_flash - delta, 0.0)
	if _body == null:
		return
	if face:
		_body.rotation = _heading.angle()
	elif sway > 0.0:
		_body.rotation = sin(_spin * 0.5) * sway
	else:
		_body.rotation = (_spin * 0.5 if star else _spin) * spin_rate
	_body.sync()
	if _deco != null:
		_deco.rotation += delta * deco_spin
		_deco.sync()


## 코어 스킬 FREEZE: duration초 동안 멈춘다.
func freeze(duration: float) -> void:
	if cc_immune():
		return
	_freeze_timer = maxf(_freeze_timer, duration)
	if _body != null:
		_body.sync()


## SHOCK 충격파: duration초 스턴 (보스는 BOSS_STUN_MULT배). 그동안 움직이지도 때리지도 않는다.
## 스턴이 풀린 뒤 STUN_GRACE초 동안은 다시 안 걸린다. 걸렸으면 true.
func stun(duration: float) -> bool:
	if _stun_immune > 0.0 or duration <= 0.0 or cc_immune():
		return false
	var d := duration * (BOSS_STUN_MULT if is_boss else 1.0)
	freeze(d)
	_stun_immune = d + STUN_GRACE
	return true


func is_frozen() -> bool:
	return _freeze_timer > 0.0


## 몸체 색: 정지(하얀 얼음), 돌진 준비(하얗게 깜빡임), 감속(파랑), 치명타(하양), 화상(주황 깜빡임).
func body_color() -> Color:
	if is_frozen():
		return Color(0.8, 0.95, 1.0)
	if _windup_left > 0.0:
		return color.lerp(Color.WHITE, 0.4 + 0.4 * sin(_windup_left * 40.0))
	if enraged and _crit_flash <= 0.0:
		# 분노: 붉게 맥동
		return color.lerp(Color(1.0, 0.15, 0.2), 0.55 + 0.35 * sin(_spin * 4.0))
	var c := color.lerp(Color(0.6, 0.8, 1.0), 0.6) if is_slowed() else color
	if _crit_flash > 0.0:
		c = Color.WHITE
	elif is_burning():
		c = c.lerp(Color(1.0, 0.6, 0.1), 0.5 + 0.3 * sin(_spin * 6.0))
	return c


## 그릴 때 쓰는 몸체 색. 계속 깜빡이는 동안(화상, 돌진 준비, 분노)은 1/64 단계로 맞춰서
## 저장해 둔 모양(NeonDraw.cached)을 다시 쓴다. 눈으로는 차이가 안 보인다.
func drawn_body_color() -> Color:
	var c := body_color()
	if not is_frozen() and (_windup_left > 0.0 or _crit_flash <= 0.0 and (enraged or is_burning())):
		return NeonDraw.quantize(c)
	return c


## factor 배 속도로 duration초 동안 느려진다 (여러 번 걸리면 가장 강한 감속 유지).
func apply_slow(factor: float, duration: float) -> void:
	if cc_immune():
		return
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


## 맞힐 수 있는 상태인지: 살아 있고 숨어 있지 않음. 타일, 드론, 번개, 불길이 모두 이걸로 노릴 적을 고른다.
func is_alive() -> bool:
	return not _dead and _cloak_left <= 0.0


## 숨어 있어도 살아 있으면 true (보스 체력 막대 등).
func exists() -> bool:
	return not _dead


func take_damage(amount: float, source: HexTile = null) -> void:
	if _dead or _cloak_left > 0.0:
		return
	var left := amount * (1.0 - armor)
	var absorbed := 0.0
	if shield > 0.0:
		absorbed = minf(shield, left)
		shield -= absorbed
		left -= absorbed
		if shield <= 0.0 and _body != null:
			_body.sync()
	var dealt := absorbed + minf(left, hp)
	if source != null:
		_last_source = source
		if source.board != null:
			source.board.stats.record(source, dealt)
	hp -= left
	if hp <= 0.0:
		_die(true)
		return
	if enrage_at > 0.0 and not enraged and hp < max_hp * enrage_at:
		enraged = true
		speed *= enrage_speed
	while _quake_next < quake_at.size() and hp < max_hp * float(quake_at[_quake_next]):
		_quake_next += 1
		_lunge = 1.0
		Sfx.play("quake")
		summoned.emit(self, quake_kind, quake_count)
	queue_redraw()


func _die(was_killed: bool) -> void:
	_dead = true
	killed = was_killed
	remove_from_group(GROUP)
	died.emit(self, reward if was_killed else 0)
	queue_free()


## 종류에 따른 외곽선 점들 (닫힌 도형). face(가는 방향을 봄)면 +x를 향한 화살촉.
## COMET(혜성 머리)과 WRAITH(두건 쓴 망령)는 따로 그린 모양.
func shape_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := radius
	match kind:
		"comet":
			# 길쭉한 연 모양 머리 (코가 +x)
			return _closed([Vector2(1.5, 0), Vector2(0.2, 0.58), Vector2(-0.5, 0.36),
					Vector2(-0.3, 0), Vector2(-0.5, -0.36), Vector2(0.2, -0.58)], rr)
		"wraith":
			# 뾰족한 두건, 아래는 대칭 톱니 자락
			return _closed([Vector2(0, -1.35), Vector2(0.42, -0.95), Vector2(0.78, -0.3),
					Vector2(0.9, 0.55), Vector2(0.62, 0.35), Vector2(0.5, 0.95), Vector2(0.25, 0.6),
					Vector2(0, 1.1), Vector2(-0.25, 0.6), Vector2(-0.5, 0.95), Vector2(-0.62, 0.35),
					Vector2(-0.9, 0.55), Vector2(-0.78, -0.3), Vector2(-0.42, -0.95)], rr)
	if face:
		var r := radius
		return PackedVector2Array([Vector2(r * 1.2, 0), Vector2(-r * 0.8, r * 0.8),
				Vector2(-r * 0.3, 0), Vector2(-r * 0.8, -r * 0.8), Vector2(r * 1.2, 0)])
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


static func _closed(unit: Array, scale_by: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in unit:
		pts.append(p * scale_by)
	pts.append(unit[0] * scale_by)
	return pts


## 체력 막대만 여기서 그린다 (피해를 받을 때만 다시 그림). 몸체는 _Body.
## 보호막이 있으면 체력 막대 위에 하늘색 막대 (최대 체력 대비).
func _draw() -> void:
	var w := radius * 2.0
	var y := radius + 6.0
	if hp < max_hp:
		draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Color(color, 0.25), 2.0)
		draw_line(Vector2(-w / 2.0, y), Vector2(-w / 2.0 + w * hp / max_hp, y), color, 2.0)
	if shield > 0.0:
		var sw := w * minf(shield / max_hp, 1.0)
		draw_line(Vector2(-w / 2.0, y + 3.5), Vector2(-w / 2.0 + sw, y + 3.5), SHIELD_COLOR, 2.0)


## 적의 몸체 (도는 도형). 근접 공격 때 잠깐 부풀어 오른다 (scale).
## 색이나 상태(보호막, 돌진)가 바뀔 때만 다시 그린다. 회복/보호막 파동이 퍼지는 짧은 동안만 매 프레임.
class _Body extends Node2D:
	var enemy: Enemy
	var _drawn_color := Color(0, 0, 0, 0)
	var _drawn_state := -1
	## COMET 꼬리: 꼬리 끝이 몸의 회전을 늦게 따라온다. 몸 기준 꼬리 끝의 휘어진 각도 (라디안).
	var tail_bend := 0.0
	var _tail_world := NAN

	func _ready() -> void:
		set_process(enemy.kind == "comet")

	## 꼬리 끝 방향이 몸 방향을 지수적으로 따라간다. 휘는 정도가 바뀔 때만 다시 그린다.
	func _process(delta: float) -> void:
		var target := global_rotation
		if is_nan(_tail_world):
			_tail_world = target
		_tail_world = lerp_angle(_tail_world, target, 1.0 - exp(-delta * TAIL_FOLLOW))
		var bend := clampf(wrapf(_tail_world - target, -PI, PI), -TAIL_BEND_MAX, TAIL_BEND_MAX)
		if absf(bend - tail_bend) > 0.003:
			tail_bend = bend
			queue_redraw()

	## 꼬리 뿌리(x = -0.6r)에서 멀수록 더 많이 돌려서 꼬리가 활처럼 휜다.
	func _bend(p: Vector2, r: float) -> Vector2:
		var root := Vector2(-r * 0.6, 0)
		var d := root.x - p.x
		if d <= 0.0 or tail_bend == 0.0:
			return p
		var t := minf(d / (r * 2.8), 1.0)
		return root + (p - root).rotated(tail_bend * t * (0.6 + 0.4 * t))

	func _bent(pts: PackedVector2Array, r: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(_bend(p, r))
		return out

	func sync() -> void:
		scale = Vector2.ONE * (1.0 + 0.2 * enemy._lunge)
		var c := enemy.drawn_body_color()
		var state := (1 if enemy.shield > 0.0 else 0) | (2 if enemy.is_dashing() else 0)
		if not c.is_equal_approx(_drawn_color) or state != _drawn_state or enemy._pulse > 0.0 \
				or _drawn_state & 4:
			_drawn_color = c
			_drawn_state = state | (4 if enemy._pulse > 0.0 else 0)
			queue_redraw()

	## 성능: 변하지 않는 부분은 NeonDraw.cached로 한 번만 만들어 같은 종류의 적끼리 같이 쓴다.
	## 다시 그릴 때마다 바뀌는 것(COMET 꼬리와 조준선, 회복/보호막 파동)만 새로 그린다.
	func _draw() -> void:
		NeonDraw.begin(self)
		var key := _shape_key()
		if enemy.kind == "comet":
			NeonDraw.cached(self, key + "a", _draw_parts)
			_draw_comet_motion(enemy.radius, _drawn_color)
			NeonDraw.cached(self, key + "b", _draw_marks)
		else:
			NeonDraw.cached(self, key, _draw_static)
		_draw_pulse()
		NeonDraw.flush()

	## 저장된 모양을 가려 쓰는 열쇠: 모양과 색을 바꾸는 값 전부.
	func _shape_key() -> String:
		return "enemy|%s|%s|%s|%d|%d|%d|%d" % [enemy.kind, enemy.radius, NeonDraw.color_key(_drawn_color),
				enemy.sides, _drawn_state & 3, enemy._quake_next,
				(1 if enemy.armor > 0.0 else 0) | (2 if enemy.crown else 0) | (4 if enemy.is_boss else 0) \
				| (8 if enemy.is_final else 0) | (16 if enemy.star else 0) | (32 if enemy.face else 0)]

	func _draw_static() -> void:
		_draw_parts()
		_draw_marks()

	func _draw_parts() -> void:
		var pts := enemy.shape_points()
		var c := _drawn_color
		var r := enemy.radius
		NeonDraw.polyline(self, pts, c, 1.0, 3.5 if enemy.is_boss else 2.5)
		match enemy.kind:
			"mender":
				# 십자
				NeonDraw.line(self, PackedVector2Array([Vector2(-r * 0.45, 0), Vector2(r * 0.45, 0)]), c, 2.5)
				NeonDraw.line(self, PackedVector2Array([Vector2(0, -r * 0.45), Vector2(0, r * 0.45)]), c, 2.5)
			"phantom":
				# 가운데 눈
				NeonDraw.circle(self, Vector2.ZERO, r * 0.25, Color(c, 0.9))
			"hydra":
				_inner(pts, 0.5, c)
			"aegis":
				# 바깥 방패 조각 3개
				for i in 3:
					var a := TAU * i / 3.0
					NeonDraw.arc(self, Vector2.ZERO, r * 1.35, a - 0.55, a + 0.55, 8, Color(c, 0.8), 2.0)
			"monolith":
				_draw_monolith(r, c)
			"comet":
				_draw_comet(r, c)
			"wraith":
				_draw_wraith(r, c)
			"bastion":
				_draw_bastion(r, c)
			"overlord":
				_draw_overlord(r, c)

	## 몸 위의 표시: 왕관 고리, 장갑, DASHER 돌진 꼬리, 보호막 고리.
	func _draw_marks() -> void:
		var pts := enemy.shape_points()
		var c := _drawn_color
		var r := enemy.radius
		if enemy.crown:
			# 최종 보스: 바깥 왕관 고리 (별 끝마다 작은 삼각형)
			var ring := PackedVector2Array()
			var cr := r * 1.3
			for i in 33:
				ring.append(Vector2.from_angle(TAU * i / 32.0) * cr)
			NeonDraw.polyline(self, ring, c, 0.6, 2.0)
			NeonDraw.arc(self, Vector2.ZERO, cr - 6.0, 0.0, TAU, 40, Color(c, 0.4), 1.2)
			for i in enemy.sides:
				var a := TAU * i / enemy.sides + PI / enemy.sides
				var d := Vector2.from_angle(a)
				var n := d.orthogonal() * 7.0
				var tip := PackedVector2Array([d * cr + n, d * (cr + 14.0), d * cr - n])
				NeonDraw.polyline(self, tip, c, 0.9, 2.0)
		if enemy.armor > 0.0 and not enemy.is_final:
			# 장갑: 안쪽에 같은 모양을 한 겹 더 (스테이지 보스는 자기 무늬가 있음)
			_inner(pts, 0.55, c, 0.7)
		if enemy.is_dashing() and enemy.kind == "dasher":
			# 돌진 꼬리 (뒤쪽 = -x)
			for k in [-0.4, 0.0, 0.4]:
				NeonDraw.line(self, PackedVector2Array([Vector2(-r * 0.6, r * k),
						Vector2(-r * 2.6, r * k * 1.4)]), Color(c, 0.55), 1.5)
		if enemy.shield > 0.0:
			NeonDraw.arc(self, Vector2.ZERO, r * 1.55 + 4.0, 0.0, TAU, 28,
					Color(Enemy.SHIELD_COLOR, 0.75), 2.0)

	func _draw_pulse() -> void:
		var r := enemy.radius
		if enemy._pulse > 0.0:
			# 회복/보호막 파동: 가운데에서 aura_radius까지 퍼지는 고리
			var t := 1.0 - enemy._pulse
			var pc := Color(0.3, 1.0, 0.55) if enemy.aura == "heal" else Enemy.SHIELD_COLOR
			NeonDraw.arc(self, Vector2.ZERO, lerpf(r, enemy.aura_radius, t) / scale.x, 0.0, TAU, 40,
					Color(pc, 0.6 * enemy._pulse), 2.5)

	## MONOLITH: 바깥 네모 + 안쪽 네모 두 겹 (같은 방향 0.7배, 45도 돌린 0.86배), 모서리마다 안으로 꺾인 쐐기,
	## 네 방향 눈금선, 가운데 두 겹 마름모 핵. 체력 구간을 넘을 때마다 금이 하나씩.
	func _draw_monolith(r: float, c: Color) -> void:
		_ring(r * 0.86, 4, c, 0.85)
		var frame := PackedVector2Array()
		for i in 5:
			frame.append(Vector2.from_angle(TAU * i / 4.0) * r * 0.7)
		NeonDraw.polyline(self, frame, c, 0.6, 1.5)
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0)
			var n := d.orthogonal()
			# 모서리 쐐기
			NeonDraw.line(self, PackedVector2Array([d * r * 0.78 + n * r * 0.1, d * r * 0.62,
					d * r * 0.78 - n * r * 0.1]), c.lightened(0.2), 2.0)
			# 핵에서 뻗는 눈금 (45도 방향, 안쪽 네모 변 가운데까지)
			var e := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
			NeonDraw.line(self, PackedVector2Array([e * r * 0.38, e * r * 0.5]), Color(c, 0.8), 2.0)
			NeonDraw.line(self, PackedVector2Array([e * r * 0.53 + e.orthogonal() * 5.0,
					e * r * 0.53 - e.orthogonal() * 5.0]), Color(c, 0.8), 1.5)
		var core := PackedVector2Array()
		for i in 4:
			core.append(Vector2.from_angle(TAU * i / 4.0) * r * 0.3)
		NeonDraw.fill(self, core, Color(c, 0.35))
		core.append(core[0])
		NeonDraw.polyline(self, core, c.lightened(0.3), 1.0, 2.0)
		var gem := PackedVector2Array()
		for i in 4:
			gem.append(Vector2.from_angle(TAU * i / 4.0) * r * 0.13)
		NeonDraw.fill(self, gem, Color(c.lightened(0.6), 0.95))
		for i in enemy._quake_next:
			var a := 0.5 + i * 2.2
			var d := Vector2.from_angle(a)
			var n := d.orthogonal()
			var crack := PackedVector2Array([d * r * 0.32, d * r * 0.55 + n * r * 0.12,
					d * r * 0.72 - n * r * 0.08, d * r * 0.98 + n * r * 0.06])
			NeonDraw.line(self, crack, Color(1.0, 0.85, 0.6, 0.95), 2.0)

	## COMET: 연 모양 머리 세 겹 (바깥, 안쪽 0.62배, 꽉 찬 핵), 양옆 칼날 날개 두 장, 가운데 등뼈 선,
	## 뒤로 이어지는 겹 갈매기(>) 꼬리 (돌진 중엔 길고 밝게 + 속도선).
	## 돌진 준비 중엔 목표 타일까지 끊긴 조준선과 끝에 과녁.
	func _draw_comet(r: float, c: Color) -> void:
		var head := enemy.shape_points()
		_inner(head, 0.62, c, 0.8)
		var core := PackedVector2Array()
		for p in head:
			core.append(p * 0.28 + Vector2(r * 0.2, 0))
		NeonDraw.fill(self, core, Color(c.lightened(0.5), 0.9))
		NeonDraw.line(self, PackedVector2Array([Vector2(-r * 0.3, 0), Vector2(r * 1.2, 0)]),
				Color(c.lightened(0.3), 0.6), 1.2)
		for sy in [-1.0, 1.0]:
			# 머리 뒷변 바깥에 붙은 가는 칼날 날개
			var wing := PackedVector2Array([Vector2(r * 0.05, sy * r * 0.68),
					Vector2(-r * 1.0, sy * r * 1.12), Vector2(-r * 0.62, sy * r * 0.62),
					Vector2(r * 0.05, sy * r * 0.68)])
			NeonDraw.polyline(self, wing, c, 0.85, 2.0)

	## COMET에서 휘는 꼬리와 조준선 (다시 그릴 때마다 새로 만든다)
	func _draw_comet_motion(r: float, c: Color) -> void:
		var dashing := enemy.is_dashing()
		var count := 5 if dashing else 3
		var gap := r * (0.55 if dashing else 0.42)
		for k in count:
			var x := -r * 0.75 - gap * k
			var h := r * (0.42 - 0.06 * k)
			var chev := PackedVector2Array([Vector2(x - h * 0.9, h), Vector2(x, 0), Vector2(x - h * 0.9, -h)])
			NeonDraw.polyline(self, _bent(chev, r), c, (1.0 if dashing else 0.7) * (1.0 - k * 0.16), 2.0)
		if dashing or absf(tail_bend) > 0.05:
			# 돌진 중 꼬리 줄기. 튕겨 돌 때는 휘어진 꼬리를 따라 흐릿하게 남는다.
			var a := 0.9 if dashing else minf(absf(tail_bend) * 1.2, 0.9)
			for sy in [-0.75, 0.75]:
				var streak := PackedVector2Array()
				for i in 7:
					streak.append(_bend(Vector2(-r * (0.9 + 2.5 * i / 6.0), sy * r), r))
				# 끝으로 갈수록 흐려지게 마디마다 따로
				for i in 6:
					NeonDraw.polyline(self, PackedVector2Array([streak[i], streak[i + 1]]),
							c, a * (1.0 - i / 7.0), 1.5)
		if enemy.is_winding_up() and enemy._aim_len > r * 1.6:
			var end := enemy._aim_len / scale.x
			var x := r * 1.7
			while x < end - 22.0:
				NeonDraw.line(self, PackedVector2Array([Vector2(x, 0), Vector2(x + 14.0, 0)]),
						Color(1.0, 1.0, 1.0, 0.75), 2.0)
				x += 26.0
			var tip := Vector2(end, 0)
			NeonDraw.arc(self, tip, 16.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.8), 2.0)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				NeonDraw.line(self, PackedVector2Array([tip + d * 9.0, tip + d * 24.0]),
						Color(1.0, 1.0, 1.0, 0.8), 2.0)

	## WRAITH: 바깥 두건과 안쪽 두건 테, 이마의 꽉 찬 마름모 보석, 역삼각형 얼굴판에 기울어진 두 눈,
	## 얼굴판 아래로 내려오는 선 세 줄.
	func _draw_wraith(r: float, c: Color) -> void:
		var rim := PackedVector2Array([Vector2(-r * 0.62, r * 0.05), Vector2(-r * 0.55, -r * 0.4),
				Vector2(-r * 0.3, -r * 0.78), Vector2(0, -r * 1.05), Vector2(r * 0.3, -r * 0.78),
				Vector2(r * 0.55, -r * 0.4), Vector2(r * 0.62, r * 0.05)])
		NeonDraw.polyline(self, rim, c, 0.7, 1.5)
		var gem := PackedVector2Array([Vector2(0, -r * 0.95), Vector2(r * 0.12, -r * 0.78),
				Vector2(0, -r * 0.6), Vector2(-r * 0.12, -r * 0.78)])
		NeonDraw.fill(self, gem, Color(c.lightened(0.5), 0.95))
		var plate := PackedVector2Array([Vector2(-r * 0.5, -r * 0.48), Vector2(r * 0.5, -r * 0.48),
				Vector2(0, r * 0.32), Vector2(-r * 0.5, -r * 0.48)])
		NeonDraw.polyline(self, plate, c, 0.9, 2.0)
		for sx in [-1.0, 1.0]:
			var eye := PackedVector2Array([Vector2(sx * r * 0.08, -r * 0.3),
					Vector2(sx * r * 0.36, -r * 0.4), Vector2(sx * r * 0.32, -r * 0.27),
					Vector2(sx * r * 0.1, -r * 0.2)])
			NeonDraw.fill(self, eye, Color(1.0, 0.95, 1.0, 0.95))
		for k in [-1.0, 0.0, 1.0]:
			NeonDraw.line(self, PackedVector2Array([Vector2(k * r * 0.16, r * (0.2 - absf(k) * 0.1)),
					Vector2(k * r * 0.22, r * (0.75 - absf(k) * 0.15))]), Color(c, 0.6), 1.5)

	## BASTION: 두 겹 육각 성벽 (0.84배 안쪽 벽, 변마다 벽돌 눈금 2개), 안쪽에 육각별(삼각형 두 개),
	## 가운데 두 겹 육각 핵, 모서리마다 포탑 (받침 선 + 네모 머리 + 포신).
	func _draw_bastion(r: float, c: Color) -> void:
		var wall := PackedVector2Array()
		for i in 7:
			wall.append(Vector2.from_angle(TAU * i / 6.0) * r * 0.84)
		NeonDraw.polyline(self, wall, c, 0.65, 1.5)
		for i in 6:
			var p0 := Vector2.from_angle(TAU * i / 6.0)
			var p1 := Vector2.from_angle(TAU * (i + 1) / 6.0)
			for t in [0.33, 0.67]:
				var m: Vector2 = p0.lerp(p1, t)
				NeonDraw.line(self, PackedVector2Array([m * r * 0.84, m * r]), Color(c, 0.7), 1.5)
		for k in 2:
			var tri := PackedVector2Array()
			for i in 4:
				tri.append(Vector2.from_angle(TAU * i / 3.0 + PI / 6.0 + k * PI / 3.0) * r * 0.6)
			NeonDraw.polyline(self, tri, c, 0.75, 1.5)
		_ring(r * 0.3, 6, c, 0.9)
		var core := PackedVector2Array()
		for i in 6:
			core.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.18)
		NeonDraw.fill(self, core, Color(c.lightened(0.3), 0.75))
		for i in 6:
			var d := Vector2.from_angle(TAU * i / 6.0)
			var n := d.orthogonal() * r * 0.09
			var base := d * r
			NeonDraw.line(self, PackedVector2Array([base, base + d * r * 0.2]), c, 3.0)
			var cap := PackedVector2Array([base + d * r * 0.2 + n, base + d * r * 0.36 + n,
					base + d * r * 0.36 - n, base + d * r * 0.2 - n, base + d * r * 0.2 + n])
			NeonDraw.polyline(self, cap, c, 0.9, 1.5)
			NeonDraw.line(self, PackedVector2Array([base + d * r * 0.36, base + d * r * 0.5]),
					c.lightened(0.3), 2.0)

	## OVERLORD: 바깥 별 안에 반 칸 돌린 별 (0.6배), 가운데 팔각 핵과 핵에서 뻗는 살 8개.
	## 왕관 고리는 아래 crown에서.
	func _draw_overlord(r: float, c: Color) -> void:
		var inner := PackedVector2Array()
		for i in enemy.sides * 2 + 1:
			var a := PI * i / enemy.sides + PI / enemy.sides
			inner.append(Vector2.from_angle(a) * r * (0.6 if i % 2 == 0 else 0.32))
		NeonDraw.polyline(self, inner, c, 0.8, 1.8)
		for i in enemy.sides:
			var d := Vector2.from_angle(TAU * i / enemy.sides)
			NeonDraw.line(self, PackedVector2Array([d * r * 0.2, d * r * 0.5]), Color(c, 0.65), 1.2)
		var core := PackedVector2Array()
		for i in 8:
			core.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * r * 0.17)
		NeonDraw.fill(self, core, Color(c.lightened(0.4), 0.85))
		NeonDraw.arc(self, Vector2.ZERO, r * 0.24, 0.0, TAU, 24, Color(c, 0.8), 1.5)

	func _inner(pts: PackedVector2Array, k: float, c: Color, intensity := 0.7) -> void:
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(p * k)
		NeonDraw.polyline(self, inner, c, intensity, 1.5)

	## 정다각형 고리 (sides 4면 사각형, 6이면 육각형)
	func _ring(rr: float, n: int, c: Color, intensity: float) -> void:
		var ring := PackedVector2Array()
		for i in n + 1:
			ring.append(Vector2.from_angle(TAU * i / n + PI / n) * rr)
		NeonDraw.polyline(self, ring, c, intensity, 2.0)


## 보스 장식: 몸체와 따로 천천히 도는 바깥 부품. 회전은 rotation, 모양이 바뀔 때만 다시 그린다.
##   MONOLITH: 둘레를 도는 돌조각 (체력 구간을 넘을 때마다 하나씩 떨어져 나감)
##   WRAITH: 끊긴 룬 고리 + 떠도는 영혼 3개
##   BASTION: 방패판 6장 (보호막이 있으면 밝고 두껍게)
##   OVERLORD: 위성 8개
class _Deco extends Node2D:
	var enemy: Enemy
	var _drawn_color := Color(0, 0, 0, 0)
	var _drawn_state := -1

	func sync() -> void:
		var c := enemy.drawn_body_color()
		var state := enemy._quake_next * 2 + (1 if enemy.shield > 0.0 else 0)
		if not c.is_equal_approx(_drawn_color) or state != _drawn_state:
			_drawn_color = c
			_drawn_state = state
			queue_redraw()

	## 장식 전체가 변하지 않는 모양이라 한 번만 만들어 저장해 둔다 (NeonDraw.cached).
	func _draw() -> void:
		NeonDraw.begin(self)
		NeonDraw.cached(self, "deco|%s|%s|%s|%d|%d" % [enemy.kind, enemy.radius,
				NeonDraw.color_key(_drawn_color), _drawn_state, enemy.quake_at.size()], _draw_parts)
		NeonDraw.flush()

	func _draw_parts() -> void:
		var c := _drawn_color
		var r := enemy.radius
		match enemy.kind:
			"monolith":
				# 궤도 원 + 눈금 8개, 남은 돌조각 (두 겹 네모 + 가운데 점)
				var left := enemy.quake_at.size() + 1 - enemy._quake_next
				NeonDraw.arc(self, Vector2.ZERO, r * 1.6, 0.0, TAU, 48, Color(c, 0.22), 1.5)
				for i in 8:
					var d := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
					NeonDraw.line(self, PackedVector2Array([d * r * 1.52, d * r * 1.68]), Color(c, 0.45), 1.5)
				for i in left:
					var at := Vector2.from_angle(TAU * i / 4.0) * r * 1.6
					var sq := PackedVector2Array()
					var sq2 := PackedVector2Array()
					for k in 5:
						var d := Vector2.from_angle(TAU * k / 4.0 + PI / 4.0)
						sq.append(at + d * r * 0.22)
						sq2.append(at + d.rotated(PI / 4.0) * r * 0.13)
					NeonDraw.polyline(self, sq, c, 0.9, 2.0)
					NeonDraw.line(self, sq2, Color(c, 0.7), 1.2)
					NeonDraw.circle(self, at, 2.5, c.lightened(0.5))
			"comet":
				# 자이로 고리: 얇은 원 + 바깥을 향한 이빨 6개
				NeonDraw.arc(self, Vector2.ZERO, r * 1.75, 0.0, TAU, 48, Color(c, 0.35), 1.5)
				for i in 6:
					var d := Vector2.from_angle(TAU * i / 6.0)
					var n := d.orthogonal() * 6.0
					var tooth := PackedVector2Array([d * r * 1.75 + n, d * (r * 1.75 + 12.0), d * r * 1.75 - n])
					NeonDraw.polyline(self, tooth, c, 0.8, 1.5)
			"wraith":
				# 두 겹 룬 고리: 바깥은 끊긴 호 6개와 눈금, 안쪽은 안을 향한 가시 12개. 영혼 3개
				for i in 6:
					var a := TAU * i / 6.0
					NeonDraw.arc(self, Vector2.ZERO, r * 1.6, a + 0.1, a + 0.9, 10, Color(c, 0.7), 2.0)
					var d := Vector2.from_angle(a + 0.98)
					NeonDraw.line(self, PackedVector2Array([d * r * 1.48, d * r * 1.72]), Color(c, 0.9), 2.0)
				for i in 12:
					var d := Vector2.from_angle(TAU * i / 12.0 + 0.26)
					var n := d.orthogonal() * 4.0
					NeonDraw.line(self, PackedVector2Array([d * r * 1.42 + n, d * r * 1.3, d * r * 1.42 - n]),
							Color(c, 0.55), 1.2)
				for i in 3:
					var at := Vector2.from_angle(TAU * i / 3.0 + 0.5) * r * 2.0
					var soul := PackedVector2Array([at + Vector2(0, -9), at + Vector2(5, 0),
							at + Vector2(0, 9), at + Vector2(-5, 0), at + Vector2(0, -9)])
					NeonDraw.polyline(self, soul, c.lightened(0.3), 0.9, 1.5)
					NeonDraw.circle(self, at, 2.0, Color(1.0, 1.0, 1.0, 0.9))
			"bastion":
				# 방패판 6장: 두 호를 이은 판 + 가운데 리벳. 보호막이 있으면 하늘색으로 밝고 판 안이 채워짐
				var on := enemy.shield > 0.0
				var pc := Enemy.SHIELD_COLOR if on else c
				for i in 6:
					var a := TAU * i / 6.0 + PI / 6.0
					var plate := PackedVector2Array()
					for k in 7:
						plate.append(Vector2.from_angle(a - 0.36 + 0.72 * k / 6.0) * r * 1.62)
					for k in 7:
						plate.append(Vector2.from_angle(a + 0.3 - 0.6 * k / 6.0) * r * 1.42)
					plate.append(plate[0])
					if on:
						NeonDraw.fill(self, PackedVector2Array([plate[0], plate[6], plate[7], plate[13]]),
								Color(pc, 0.25))
					NeonDraw.polyline(self, plate, pc, 0.95 if on else 0.5, 2.5 if on else 1.5)
					NeonDraw.circle(self, Vector2.from_angle(a) * r * 1.52, 2.5, Color(pc, 0.9))
			"overlord":
				# 위성 8개: 두 겹 마름모 + 가운데 점, 몸 쪽으로 짧은 끈
				for i in 8:
					var d := Vector2.from_angle(TAU * i / 8.0)
					var at := d * r * 1.9
					var n := d.orthogonal()
					var dia := PackedVector2Array([at + d * 8.0, at + n * 5.0, at - d * 8.0, at - n * 5.0, at + d * 8.0])
					NeonDraw.polyline(self, dia, c, 0.85, 1.5)
					NeonDraw.circle(self, at, 1.8, c.lightened(0.5))
					NeonDraw.line(self, PackedVector2Array([at - d * 11.0, at - d * 19.0]), Color(c, 0.5), 1.2)
