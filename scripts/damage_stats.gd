class_name DamageStats
extends RefCounted
## 타일별, 웨이브별로 적에게 실제로 준 피해 기록 (일시정지 화면 통계용).
## 넘친 피해(남은 체력보다 큰 부분)는 빼고, 장갑으로 깎인 뒤의 값을 센다.
## 부서진 타일도 기록은 남는다 (alive = false).

## 웨이브 번호 -> {타일 id: 피해}
var by_wave := {}
## 타일 id -> {kind, name, color, coord, level, alive}
var tiles := {}
var current_wave := 0


func reset() -> void:
	by_wave.clear()
	tiles.clear()
	current_wave = 0


func record(tile: HexTile, amount: float) -> void:
	if amount <= 0.0:
		return
	var id := tile.get_instance_id()
	var info: Dictionary = tiles.get(id, {})
	if info.is_empty():
		info = {"kind": tile.kind, "name": tile.display_name, "color": tile.color,
				"coord": tile.coord, "alive": true}
		tiles[id] = info
	info["level"] = tile.level
	var w: Dictionary = by_wave.get(current_wave, {})
	if w.is_empty():
		by_wave[current_wave] = w
	w[id] = w.get(id, 0.0) + amount


func mark_dead(tile: HexTile) -> void:
	var id := tile.get_instance_id()
	if tiles.has(id):
		tiles[id]["alive"] = false


func damage(id: int, wave: int) -> float:
	return by_wave.get(wave, {}).get(id, 0.0)


func total(id: int) -> float:
	var sum := 0.0
	for w in by_wave.values():
		sum += w.get(id, 0.0)
	return sum


func wave_total(wave: int) -> float:
	var sum := 0.0
	for v in by_wave.get(wave, {}).values():
		sum += v
	return sum


## 피해를 준 타일 id, 총 피해 많은 순.
func ranked_ids() -> Array:
	var ids := tiles.keys()
	var totals := {}
	for id in ids:
		totals[id] = total(id)
	ids.sort_custom(func(a, b) -> bool: return totals[a] > totals[b])
	return ids


## 짧은 숫자 (1234 -> 1.2K)
static func short(v: float) -> String:
	if v < 1000.0:
		return "%d" % roundi(v)
	if v < 1000000.0:
		return "%.1fK" % (v / 1000.0)
	return "%.1fM" % (v / 1000000.0)
