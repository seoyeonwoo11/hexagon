class_name ShockWave
extends Node2D
## SHOCK 타일의 충격파. 타일 가운데에서 사거리 끝까지 퍼지는 링이 지나간 적을 잠깐 스턴시킨다.
## 파장 주기는 공격 속도와 상관없이 고정 (tile.fire_interval). 공격 속도(BOOSTER, 전체 강화, 레벨)는
## 링이 퍼지는 속도만 올린다 (speed()).
## 성능: 링이 퍼지는 동안만 다시 그리고, 그리기 호출은 1번 (NeonDraw 묶어 그리기).
## 적 목록은 링이 퍼지는 짧은 동안만 훑는다.

## 링이 퍼지는 기본 속도 (픽셀/초). 공격 속도 배율과 레벨이 곱해진다.
const BASE_SPEED := 700.0
## 링이 끝에 닿은 뒤 사라지는 시간
const FADE := 0.18
## 강화마다 스턴 시간 +, 최대
const UPG_STUN := 0.1
const STUN_MAX := 2.0

var tile: HexTile
## 지금 링 반지름. 0 이하면 쉬는 중.
var radius := 0.0
var _active := false
var _fade := 0.0
var _hit := {}
## 이 링이 스턴시킨 적 수 (테스트, 통계용)
var stunned := 0


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
	radius = tile.size * 0.6
	_sweep()
	queue_redraw()
	return true


func tick(delta: float) -> void:
	if _active:
		radius = minf(radius + speed() * delta, tile.effective_range())
		_sweep()
		if radius >= tile.effective_range():
			_active = false
			_fade = FADE
		queue_redraw()
	elif _fade > 0.0:
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
			tile.apply_hit(e, tile.damage())


func _draw() -> void:
	if tile == null or (not _active and _fade <= 0.0):
		return
	NeonDraw.begin(self)
	var c := tile.color
	var reach := tile.effective_range()
	var k := 1.0 if _active else _fade / FADE
	var r := radius if _active else reach
	# 가운데에서 멀어질수록 조금 옅게
	var a := k * (1.0 - 0.35 * clampf(r / maxf(reach, 1.0), 0.0, 1.0))
	NeonDraw.arc(self, Vector2.ZERO, r, 0.0, TAU, 72, Color(c, 0.10 * a), 16.0)
	NeonDraw.arc(self, Vector2.ZERO, r, 0.0, TAU, 72, Color(c, 0.85 * a), 3.0)
	NeonDraw.arc(self, Vector2.ZERO, r * 0.82, 0.0, TAU, 56, Color(c, 0.3 * a), 1.5)
	NeonDraw.flush()
