class_name FlameJet
extends Node2D
## BURN 타일의 화염방사기. 가장 가까운 적 쪽으로 돌아가며 부채꼴 불길을 뿜는다.
## 공격(fire)마다 불길 안의 모든 적에게 피해 + 화상. 불붙은 적이 다른 적과 맞닿으면 불이 옮겨붙는다
## (옮겨붙을 때마다 화상이 SPREAD_RATIO배로 약해지고, 최대 SPREAD_HOPS번).
## 성능: 파티클이나 투사체 없이 불길마다 다각형 3겹 + 바깥 테두리 1줄 + 밀려 나가는 호 3개.
## 뿜는 동안만 매 프레임 다시 그리고, 옮겨붙기 검사는 SPREAD_EVERY초에 1번.

## 불길이 적을 따라 도는 속도(라디안/초)
const TURN_SPEED := 7.0
## 마지막 공격 뒤 불길이 남아 보이는 시간, 켜질 때 불길이 뻗어 나가는 시간
const LINGER := 0.22
const GROW_TIME := 0.12
## 화상 초당 피해 = 공격 1번의 피해 × BURN_DPS_RATIO
const BURN_DPS_RATIO := 1.2
## 옮겨붙기: 최대 횟수, 옮겨붙을 때 화상 세기 비율, "맞닿음"으로 보는 몸 사이 여유 거리, 검사 간격
const SPREAD_HOPS := 2
const SPREAD_RATIO := 0.6
const SPREAD_GAP := 14.0
const SPREAD_EVERY := 0.25
## 옮겨붙는 순간 두 적 사이에 잠깐 보이는 불씨 선
const SPARK_TIME := 0.25
const MAX_SPARKS := 12
## 강화 1번마다 화상 시간 +0.5초
const UPG_BURN_TIME := 0.5
## 불길 테두리 점 수
const EDGE_POINTS := 10

const HOT := Color(1.0, 0.92, 0.55)

var tile: HexTile
## 불길마다 지금 향한 각도와 따라가는 적
var _angles: Array[float] = []
var _targets: Array[Enemy] = []
var _on := 0.0
var _grow := 0.0
var _t := 0.0
var _spread_cd := 0.0
## [시작(전역), 끝(전역), 남은 시간]
var _sparks: Array = []
var _was_drawn := false
## 지금까지 옮겨붙은 횟수 (테스트/측정용)
var spreads := 0


func _ready() -> void:
	z_index = 1


## 타일이 매 프레임 부른다: 불길 방향 돌리기, 옮겨붙기, 다시 그리기.
func tick(delta: float) -> void:
	_t += delta
	_on = maxf(_on - delta, 0.0)
	_grow = minf(_grow + delta / GROW_TIME, 1.0) if _on > 0.0 else 0.0
	for i in _angles.size():
		var e: Enemy = _targets[i] if i < _targets.size() else null
		if e != null and is_instance_valid(e) and e.is_alive():
			var want := (e.global_position - tile.global_position).angle()
			_angles[i] = rotate_toward(_angles[i], want, TURN_SPEED * delta)
	_spread_cd -= delta
	if _spread_cd <= 0.0:
		_spread_cd = SPREAD_EVERY
		_spread()
	for s in _sparks:
		s[2] -= delta
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	var show := _on > 0.0 or not _sparks.is_empty()
	if show or _was_drawn:
		queue_redraw()
	_was_drawn = show


## 공격 한 번. 사거리 안에 적이 없으면 false (쿨다운을 쓰지 않음).
func fire() -> bool:
	var targets := tile.nearest_targets(tile.target_count())
	if targets.is_empty():
		return false
	var fresh := _on <= 0.0
	_targets = targets
	var old := _angles.size()
	_angles.resize(targets.size())
	for i in targets.size():
		var want := (targets[i].global_position - tile.global_position).angle()
		# 꺼져 있다가 켜지면 바로 적을 향하고, 뿜는 중에는 TURN_SPEED로 따라간다
		if fresh or i >= old:
			_angles[i] = want
	_on = LINGER + tile.interval()
	var dmg := tile.damage()
	var reach := tile.effective_range()
	var half := tile.cone
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to_e := e.global_position - tile.global_position
		var dist := to_e.length()
		if dist > reach + e.radius:
			continue
		# 몸이 불길 가장자리에 걸쳐도 맞는다
		var slack := atan2(e.radius, maxf(dist, 1.0))
		var ang := to_e.angle()
		var inside := false
		for a in _angles:
			if absf(angle_difference(a, ang)) <= half + slack:
				inside = true
				break
		if not inside:
			continue
		tile.apply_hit(e, dmg)
		if e.is_alive():
			e.apply_burn(dmg * BURN_DPS_RATIO, tile.burn_time, tile, SPREAD_HOPS)
	return true


## 이 타일이 붙인 불이 맞닿은 다른 적에게 옮겨붙는다. 더 센 불이 이미 붙은 적은 그대로.
func _spread() -> void:
	var all: Array[Enemy] = []
	var burners: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		all.append(e)
		if e.burn_spread > 0 and e.burn_source() == tile:
			burners.append(e)
	for b in burners:
		var dps := b.burn_dps() * SPREAD_RATIO
		for o in all:
			if o == b or not o.is_alive() or o.burn_dps() >= dps:
				continue
			var touch := b.radius + o.radius + SPREAD_GAP
			if b.global_position.distance_squared_to(o.global_position) > touch * touch:
				continue
			o.apply_burn(dps, tile.burn_time, tile, b.burn_spread - 1)
			spreads += 1
			if _sparks.size() < MAX_SPARKS:
				_sparks.append([b.global_position, o.global_position, SPARK_TIME])


func _draw() -> void:
	if tile == null:
		return
	if _on > 0.0:
		var fade := clampf(_on / LINGER, 0.0, 1.0)
		var reach := tile.effective_range() * (0.35 + 0.65 * ease(_grow, 0.5))
		for a in _angles:
			_draw_flame(a, reach, fade)
	if not _sparks.is_empty():
		var lines := PackedVector2Array()
		for s in _sparks:
			lines.append(to_local(s[0]))
			lines.append(to_local(s[1]))
		draw_multiline(lines, Color(HOT, 0.8), 2.5, true)


## 불길 하나: 바깥(타일 색) > 가운데(주황) > 안쪽(노란 흰빛) 세 겹 부채꼴.
## 끝은 시간에 따라 일렁이고, 노즐에서 끝까지 밝은 호가 계속 밀려 나간다.
func _draw_flame(a: float, reach: float, fade: float) -> void:
	var c := tile.color
	var half := tile.cone
	var nozzle := tile.size * 0.45
	var layers := [[1.0, 1.0, c, 0.3], [0.75, 0.68, c.lerp(HOT, 0.45), 0.36], [0.48, 0.38, HOT, 0.5]]
	for li in layers.size():
		var L: Array = layers[li]
		var lc: Color = L[2]
		var pts := _cone_points(a, nozzle, reach * float(L[0]), half * float(L[1]), li)
		draw_colored_polygon(pts, Color(lc, float(L[3]) * fade))
		if li == 0:
			# 바깥 테두리 (노즐 점은 빼고)
			draw_polyline(pts.slice(1), Color(c.lightened(0.3), 0.55 * fade), 2.0, true)
	# 밀려 나가는 불길 띠: 노즐에서 끝으로 가며 넓어지고 옅어진다
	for k in 3:
		var f := fmod(_t * 2.6 + k / 3.0, 1.0)
		var r := lerpf(nozzle, reach * 0.95, f)
		var w := half * (0.35 + 0.6 * f)
		draw_arc(Vector2.ZERO, r, a - w, a + w, 10, Color(HOT.lerp(c, f), 0.55 * (1.0 - f) * fade),
				3.0 + 5.0 * f, true)


## 부채꼴 다각형: 노즐 + 일렁이는 바깥 끝.
func _cone_points(a: float, nozzle: float, length: float, half: float, layer: int) -> PackedVector2Array:
	# 노즐 한 점에서 퍼지는 부채꼴 (끝점들이 노즐보다 늘 멀어서 다각형이 꼬이지 않음)
	var pts := PackedVector2Array([Vector2.from_angle(a) * nozzle * 0.5])
	for i in EDGE_POINTS + 1:
		var u := float(i) / EDGE_POINTS
		var da := lerpf(half, -half, u)
		# 가운데가 길고 양끝이 짧은 혀 모양 + 시간에 따른 일렁임
		var shape := 0.78 + 0.22 * sin(PI * u)
		var flicker := 0.08 * sin(_t * 15.0 + i * 2.1 + layer * 1.7) + 0.05 * sin(_t * 23.0 + i * 4.3)
		pts.append(Vector2.from_angle(a + da) * maxf(length * (shape + flicker), nozzle + 8.0))
	return pts
