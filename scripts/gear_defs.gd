class_name GearDefs
extends RefCounted
## 타일 장비. 타일마다 1개 장착 (새로 장착하면 기존 장비는 교체).
## attacks: 장착할 수 있는 타일의 공격 방식 (TileDefs의 attack 값).

const DEFS := {
	"scope": {
		"name": "SCOPE", "color": Color(0.6, 1.0, 0.95),
		"desc": "+40% attack range.",
		"attacks": ["laser", "spark", "frost"],
	},
	"splitter": {
		"name": "SPLITTER", "color": Color(1.0, 0.6, 0.2),
		"desc": "Hits one extra target each attack.",
		"attacks": ["laser", "spark"],
	},
	"igniter": {
		"name": "IGNITER", "color": Color(1.0, 0.4, 0.15),
		"desc": "Hits set enemies on fire for 3 seconds.",
		"attacks": ["laser", "spark", "frost"],
	},
	"cryo": {
		"name": "CRYO COIL", "color": Color(0.5, 0.8, 1.0),
		"desc": "Hits slow enemies by 35%.",
		"attacks": ["laser", "spark"],
	},
	"crit": {
		"name": "CRIT LENS", "color": Color(1.0, 0.3, 0.6),
		"desc": "20% chance to deal triple damage.",
		"attacks": ["laser", "spark", "frost"],
	},
	"detonator": {
		"name": "DETONATOR", "color": Color(1.0, 0.75, 0.3),
		"desc": "Enemies it kills explode, hurting enemies nearby.",
		"attacks": ["laser", "spark", "frost"],
	},
	"collector": {
		"name": "COLLECTOR", "color": Color(1.0, 0.85, 0.1),
		"desc": "Enemies killed by this tile drop +$1.",
		"attacks": ["laser", "spark", "frost"],
	},
}

const SCOPE_RANGE_MULT := 1.4
const IGNITE_DPS_RATIO := 0.4
const IGNITE_TIME := 3.0
const CRYO_SLOW := 0.65
const CRYO_TIME := 1.0
const CRIT_CHANCE := 0.2
const CRIT_MULT := 3.0
## 폭발: 처치한 적 위치에서 반경 안 적들에게 (그 타일 공격력 × 비율) 피해
const DETONATE_RADIUS := 100.0
const DETONATE_RATIO := 0.8
const COLLECTOR_BONUS := 1


static func get_def(id: String) -> Dictionary:
	return DEFS[id]


static func ids() -> Array:
	return DEFS.keys()


static func can_equip(id: String, tile: HexTile) -> bool:
	return tile != null and (DEFS[id]["attacks"] as Array).has(tile.attack)
