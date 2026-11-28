class_name ShockWave
extends Node2D
## SHOCK 타일의 충격파. 타일 가운데에서 사거리 끝까지 퍼지는 링이 지나간 적을 잠깐 스턴시킨다.
## 파장 주기는 공격 속도와 상관없이 고정 (tile.fire_interval). 공격 속도(BOOSTER, 전체 강화, 레벨)는
## 링이 퍼지는 속도만 올린다 (speed()).
## 그림: 지글거리는 번개 링 (꼭짓점마다 반지름이 흔들리고 CRACKLE초마다 모양이 바뀜) + 바깥으로 튀는
## 작은 번개 가지 + 스턴된 적 위의 작은 스파크.
## 성능: 링이 퍼지는 동안과 이 링에 스턴된 적이 있는 동안만 다시 그리고, 그리기 호출은 1번
## (NeonDraw 묶어 그리기). 적 목록은 링이 퍼지는 동안만 훑는다.

## 링이 퍼지는 기본 속도 (픽셀/초). 공격 속도 배율과 레벨이 곱해진다.
const BASE_SPEED := 220.0
## 링이 끝에 닿은 뒤 사라지는 시간
const FADE := 0.18
## 강화마다 스턴 시간 +, 최대
const UPG_STUN := 0.05
const STUN_MAX := 1.0
## 번개 모양이 바뀌는 간격(초), 링 흔들림 폭(픽셀), 바깥으로 튀는 가지 수
const CRACKLE := 0.05
const JAG := 7.0
const BRANCHES := 7
## 번개 색 (빛 번짐은 이 색, 가운데 선은 더 하얗게)
const ELECTRIC := Color(0.55, 0.82, 1.0)

var tile: HexTile
## 지금 링 반지름. 0 이하면 쉬는 중.
var radius := 0.0
var _active := false
var _fade := 0.0
var _hit := {}
## 이 링이 스턴시킨 적 수 (테스트, 통계용)
var stunned := 0
## 이 링에 스턴된 적들 (스턴이 풀릴 때까지 스파크를 그림). 풀린 적이 섞일 수 있어 타입 없는 배열.
var _zapped: Array = []
var _seed := 1
var _crackle_cd := 0.0
## 지난번에 뭔가 그렸는지 (다 끝나면 한 번 더 그려서 지움)
var _showing := false


func _ready() -> void:
	z_index = -1


## 링이 퍼지는 속도 (픽셀/초).
func speed() -> float:
	return BASE_SPEED * tile.wave_speed * tile.speed_mult()


func is_active() -> bool:
	return _active


## 사거리 안에 적이 있으면 새 링을 낸다. 이전 링이 남아 있으면 바로 끝낸다.
func fire() -> bool:
	if tile.enemies_in_range().is_empty():
		return false
	_active = true
	_fade = 0.0
	_hit.clear()
	stunned = 0
	_zapped.clear()
	radius = tile.size * 0.6
	_sweep()
	queue_redraw()
	return true


func tick(delta: float) -> void:
	_zapped = _zapped.filter(func(e) -> bool:
		return is_instance_valid(e) and e.is_alive() and e.is_frozen())
	if not _active and _fade <= 0.0 and _zapped.is_empty():
		if _showing:
			# 마지막 스파크를 지운다
			_showing = false
			queue_redraw()
		return
	_showing = true
	_crackle_cd -= delta
	if _crackle_cd <= 0.0:
		_crackle_cd = CRACKLE
		_seed = randi()
	if _active:
		radius = minf(radius + speed() * delta, tile.effective_range())
		_sweep()
		if radius >= tile.effective_range():
			_active = false
			_fade = FADE
		queue_redraw()
	else:
		_fade = maxf(_fade - delta, 0.0)
		queue_redraw()


## 링 안으로 들어온 적 중 아직 안 맞은 적: 스턴 + 약한 피해 (장비 효과 포함).
func _sweep() -> void:
	var origin := tile.global_position
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var id := e.get_instance_id()
		if _hit.has(id):
			continue
		if origin.distance_to(e.global_position) <= radius + e.radius:
			_hit[id] = true
			if e.stun(tile.stun_time):
				stunned += 1
				_zapped.append(e)
			tile.apply_hit(e, tile.damage())


func _draw() -> void:
	if tile == null:
		return
	NeonDraw.begin(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	if _active or _fade > 0.0:
		_draw_ring(rng)
	for e in _zapped:
		if is_instance_valid(e):
			_draw_zap(rng, to_local(e.global_position), e.radius)
	NeonDraw.flush()


## 번개 링: 반지름이 꼭짓점마다 흔들리는 닫힌 선 두 가닥 (꼬인 번개처럼) + 바깥으로 튀는 가지.
func _draw_ring(rng: RandomNumberGenerator) -> void:
	var reach := tile.effective_range()
	var k := 1.0 if _active else _fade / FADE
	var r := radius if _active else reach
	# 가운데에서 멀어질수록 조금 옅게
	var a := k * (1.0 - 0.3 * clampf(r / maxf(reach, 1.0), 0.0, 1.0))
	var n := clampi(int(r * 0.3), 18, 72)
	var ring := PackedVector2Array()
	var echo := PackedVector2Array()
	for i in n:
		var d := Vector2.from_angle(TAU * i / n)
		ring.append(d * (r + rng.randf_range(-JAG, JAG)))
		echo.append(d * (r - 3.0 + rng.randf_range(-JAG, JAG) * 1.3))
	ring.append(ring[0])
	echo.append(echo[0])
	NeonDraw.polyline(self, ring, ELECTRIC, a, 2.5)
	NeonDraw.line(self, echo, Color(ELECTRIC.lightened(0.3), 0.55 * a), 1.2)
	# 바깥으로 튀는 작은 번개 가지
	for b in BRANCHES:
		var d := Vector2.from_angle(rng.randf() * TAU)
		var side := d.orthogonal()
		var p := d * r
		var pts := PackedVector2Array([p])
		for s in 3:
			p += d * rng.randf_range(6.0, 11.0) + side * rng.randf_range(-7.0, 7.0)
			pts.append(p)
		NeonDraw.line(self, pts, Color(ELECTRIC.lightened(0.4), 0.8 * a), 1.5)


## 스턴된 적 위의 스파크: 몸을 가로지르는 짧은 지그재그 두 줄.
func _draw_zap(rng: RandomNumberGenerator, center: Vector2, size: float) -> void:
	for z in 2:
		var d := Vector2.from_angle(rng.randf() * TAU)
		var side := d.orthogonal()
		var pts := PackedVector2Array()
		for i in 4:
			var t := lerpf(-1.0, 1.0, i / 3.0)
			pts.append(center + d * t * size * 1.3 + side * rng.randf_range(-0.4, 0.4) * size)
		NeonDraw.line(self, pts, Color(ELECTRIC.lightened(0.5), 0.9), 1.5)
