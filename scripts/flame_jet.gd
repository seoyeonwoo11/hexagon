class_name FlameJet
extends Node2D
## BURN 타일의 화염방사기. 가장 가까운 적 쪽으로 돌아가며 부채꼴 불길을 뿜는다.
## 공격(fire)마다 불길 안의 모든 적에게 피해 + 화상. 불붙은 적이 다른 적과 맞닿으면 불이 옮겨붙는다
## (옮겨붙을 때마다 화상이 SPREAD_RATIO배로 약해지고, 최대 SPREAD_HOPS번).
## 그림: 노즐에서 작은 네온 정육각형 입자들이 부채꼴로 쏟아져 나가고, 밑에 옅게 번지는 빛 부채꼴.
## 성능: 입자는 노드가 아니라 배열 하나 (타일마다 최대 MAX_PARTICLES개). 피해 판정은 입자와 상관없이 부채꼴로 한다.
## 그리기는 타일마다 4번 (빛 부채꼴 1번 + 모든 입자 채우기 1번 + 번짐 1번 + 테두리 1번).
## 뿜거나 입자가 남아 있는 동안만 매 프레임 다시 그리고, 옮겨붙기 검사는 SPREAD_EVERY초에 1번.

## 불길이 적을 따라 도는 속도(라디안/초)
const TURN_SPEED := 7.0
## 마지막 공격 뒤 불길이 남아 보이는 시간, 켜질 때 불길이 뻗어 나가는 시간
const LINGER := 0.22
const GROW_TIME := 0.12
## 화상 초당 피해 = 공격 1번의 피해 × BURN_DPS_RATIO
const BURN_DPS_RATIO := 1.5
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
## 빛 부채꼴 진하기 (입자가 주인공이라 옅게)
const GLOW_ALPHA := 0.55
## 육각형 입자: 불길마다 초당 수, 타일마다 최대 수, 수명(초), 크기(처음 > 끝, 꼭짓점까지 반지름)
const EMIT_RATE := 70.0
const MAX_PARTICLES := 80
const PARTICLE_LIFE := 0.42
const PARTICLE_SIZE_START := 3.5
const PARTICLE_SIZE_END := 10.5

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
## 육각형 입자: [위치(타일 기준), 속도, 나이, 수명, 회전, 회전 속도]
var _particles: Array = []
var _emit_acc := 0.0
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
	_update_particles(delta)
	var show := _on > 0.0 or not _sparks.is_empty() or not _particles.is_empty()
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
			_draw_glow(a, reach, fade * GLOW_ALPHA)
	if not _particles.is_empty():
		_draw_particles()
	if not _sparks.is_empty():
		var lines := PackedVector2Array()
		for s in _sparks:
			lines.append(to_local(s[0]))
			lines.append(to_local(s[1]))
		draw_multiline(lines, Color(HOT, 0.8), 2.5, true)


## 육각형 입자 움직이기. 불길을 뿜는 동안 노즐에서 새 입자를 쏜다.
func _update_particles(delta: float) -> void:
	for p in _particles:
		p[0] += p[1] * delta
		p[2] += delta
		p[4] += p[5] * delta
	_particles = _particles.filter(func(p: Array) -> bool: return p[2] < p[3])
	# 다음 공격까지 끊기지 않도록 남은 시간의 절반까지는 계속 쏜다
	if _on <= LINGER * 0.5 or _angles.is_empty():
		_emit_acc = 0.0
		return
	_emit_acc += delta * EMIT_RATE * _angles.size()
	var reach := tile.effective_range()
	var nozzle := tile.size * 0.42
	while _emit_acc >= 1.0:
		_emit_acc -= 1.0
		if _particles.size() >= MAX_PARTICLES:
			continue
		var a: float = _angles[randi() % _angles.size()]
		var dir := Vector2.from_angle(a + randf_range(-1.0, 1.0) * tile.cone * 0.8)
		var life := PARTICLE_LIFE * randf_range(0.7, 1.0)
		var speed := reach * 0.95 / PARTICLE_LIFE * randf_range(0.85, 1.1)
		var start := Vector2.from_angle(a) * nozzle + dir * randf_range(0.0, 10.0)
		_particles.append([start, dir * speed, 0.0, life, randf() * TAU, randf_range(-6.0, 6.0)])


## 불길 밑에 깔리는 빛. 노즐에서 흰 노랑으로 밝고 끝과 양옆으로 갈수록 주황, 빨강으로 옅어진다
## (꼭짓점 색 보간, 삼각형 묶음 1번).
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


## 육각형 입자 전부를 한 번에: 옅게 채운 육각형 + 넓고 흐린 번짐 + 밝은 테두리.
## 나이가 들수록 커지고, 흰 노랑 > 주황 > 빨강으로 바뀌며 옅어진다.
func _draw_particles() -> void:
	var fill_pts := PackedVector2Array()
	var fill_cols := PackedColorArray()
	var fill_idx := PackedInt32Array()
	var edge_pts := PackedVector2Array()
	var edge_cols := PackedColorArray()
	var glow_cols := PackedColorArray()
	for p in _particles:
		var k: float = p[2] / p[3]
		var size := lerpf(PARTICLE_SIZE_START, PARTICLE_SIZE_END, sqrt(k))
		var col := HOT.lerp(MID, minf(k * 1.8, 1.0)).lerp(TIP, clampf(k * 1.8 - 0.8, 0.0, 1.0))
		var alpha := 1.0 - k * k
		var center: Vector2 = p[0]
		var base := fill_pts.size()
		fill_pts.append(center)
		fill_cols.append(Color(col, 0.45 * alpha))
		var corners: Array[Vector2] = []
		for i in 6:
			corners.append(center + Vector2.from_angle(p[4] + TAU * i / 6.0) * size)
		for i in 6:
			fill_pts.append(corners[i])
			fill_cols.append(Color(col, 0.2 * alpha))
			fill_idx.append_array([base, base + 1 + i, base + 1 + (i + 1) % 6])
			edge_pts.append(corners[i])
			edge_pts.append(corners[(i + 1) % 6])
			edge_cols.append(Color(col.lightened(0.25), alpha))
			glow_cols.append(Color(col, 0.18 * alpha))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), fill_idx, fill_pts, fill_cols)
	draw_multiline_colors(edge_pts, glow_cols, 5.0)
	draw_multiline_colors(edge_pts, edge_cols, 1.6, true)
