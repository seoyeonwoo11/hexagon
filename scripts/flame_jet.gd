class_name FlameJet
extends Node2D
## BURN 타일의 화염방사기. 가장 가까운 적 쪽으로 돌아가며 부채꼴 불길을 뿜는다.
## 공격(fire)마다 불길 안의 모든 적에게 피해 + 화상. 불붙은 적이 다른 적과 맞닿으면 불이 옮겨붙는다
## (옮겨붙을 때마다 화상이 SPREAD_RATIO배로 약해지고, 최대 SPREAD_HOPS번).
## 성능: 파티클 노드나 투사체 없이 불길마다 그리기 3번 (색이 번지는 부채꼴 1번 + 불씨 선 묶음 2번).
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
## 빛 부채꼴: 각도 칸 수, 고리마다 [노즐~끝 위치, 색, 진하기]
const GLOW_SEGS := 10
const GLOW_RINGS := [[0.35, Color(1.0, 0.7, 0.25), 0.55], [0.7, Color(1.0, 0.42, 0.12), 0.3],
		[1.0, Color(1.0, 0.18, 0.1), 0.0]]
## 불씨 선 수 (불길마다)
const EMBERS := 16

## 불 색: 노즐 쪽 흰 노랑 > 주황 > 끝의 빨강
const HOT := Color(1.0, 0.92, 0.6)
const MID := Color(1.0, 0.5, 0.12)
const TIP := Color(1.0, 0.2, 0.12)

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


## 불길 하나. 두 부분으로 그린다:
## 1) 빛: 노즐에서 흰 노랑으로 밝고 끝과 양옆으로 갈수록 주황, 빨강으로 옅어지는 부채꼴 (꼭짓점 색 보간, 삼각형 묶음 1번)
## 2) 불씨: 노즐에서 끝으로 흩날리는 짧은 네온 선들 (선 묶음 2번: 번짐 + 밝은 선)
func _draw_flame(a: float, reach: float, fade: float) -> void:
	_draw_glow(a, reach, fade)
	_draw_embers(a, reach, fade)


func _draw_glow(a: float, reach: float, fade: float) -> void:
	var half := tile.cone
	var nozzle := tile.size * 0.42
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(Vector2.from_angle(a) * nozzle)
	cols.append(Color(HOT, 0.75 * fade))
	# 고리 RINGS개 × 각도 GLOW_SEGS+1개. 끝은 살짝 숨 쉬듯 늘었다 줄었다
	var breathe := 1.0 + 0.04 * sin(_t * 11.0)
	for ring in GLOW_RINGS.size():
		var g: Array = GLOW_RINGS[ring]
		var rr: float = lerpf(nozzle, reach * breathe, g[0])
		var gc: Color = g[1]
		for i in GLOW_SEGS + 1:
			var u := float(i) / GLOW_SEGS
			var da := lerpf(-half, half, u)
			# 가운데가 조금 더 길고, 양옆은 투명하게
			var edge := sin(PI * u)
			pts.append(Vector2.from_angle(a + da) * rr * (0.86 + 0.14 * edge))
			cols.append(Color(gc, float(g[2]) * fade * pow(edge, 0.6)))
	var row := GLOW_SEGS + 1
	for i in GLOW_SEGS:
		idx.append_array([0, 1 + i, 2 + i])
	for ring in GLOW_RINGS.size() - 1:
		var b0 := 1 + ring * row
		var b1 := b0 + row
		for i in GLOW_SEGS:
			idx.append_array([b0 + i, b1 + i, b1 + i + 1, b0 + i, b1 + i + 1, b0 + i + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


func _draw_embers(a: float, reach: float, fade: float) -> void:
	var half := tile.cone
	var nozzle := tile.size * 0.42
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var glow := PackedColorArray()
	for i in EMBERS:
		# 불씨마다 정해진 속도, 출발 시점, 방향 (황금비로 고르게 흩어 놓음)
		var seed_u := fmod(i * 0.618034, 1.0)
		var speed := 1.7 + 0.9 * fmod(i * 0.381966, 1.0)
		var f := fmod(_t * speed + seed_u, 1.0)
		var off := (seed_u * 2.0 - 1.0) * half * (0.35 + 0.6 * f)
		off += 0.06 * sin(_t * 9.0 + i * 1.3)
		var dir := Vector2.from_angle(a + off)
		var r := lerpf(nozzle, reach * 0.95, f)
		var length := 8.0 + 20.0 * f * (1.0 - f) * 2.0
		pts.append(dir * r)
		pts.append(dir * (r + length))
		var col := HOT.lerp(MID, minf(f * 1.6, 1.0)).lerp(TIP, clampf(f * 1.6 - 0.6, 0.0, 1.0))
		var alpha := fade * pow(1.0 - f, 0.8)
		cols.append(Color(col.lightened(0.2), alpha))
		glow.append(Color(col, 0.22 * alpha))
	draw_multiline_colors(pts, glow, 7.0)
	draw_multiline_colors(pts, cols, 2.0, true)
