class_name GearDefs
extends RefCounted
## 타일 장비. 타일마다 1개 장착 (새로 장착하면 기존 장비는 교체).
## attacks: 장착할 수 있는 타일의 공격 방식 (TileDefs의 attack 값).

const DEFS := {
	"scope": {
		"name": "SCOPE", "color": Color(0.6, 1.0, 0.95),
		"desc": "+40% attack range.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer"],
	},
	"splitter": {
		"name": "SPLITTER", "color": Color(1.0, 0.6, 0.2),
		"desc": "Hits one extra target each attack (ORBIT: +1 orb, HIVE: +1 drone).",
		"attacks": ["laser", "spark", "orbit", "drone", "archer"],
	},
	"igniter": {
		"name": "IGNITER", "color": Color(1.0, 0.4, 0.15),
		"desc": "Hits set enemies on fire for 3 seconds.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer"],
	},
	"crit": {
		"name": "CRIT LENS", "color": Color(1.0, 0.3, 0.6),
		"desc": "25% chance to deal 3.5x damage.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer"],
	},
	"detonator": {
		"name": "DETONATOR", "color": Color(1.0, 0.75, 0.3),
		"desc": "Every hit explodes, dealing 35% of it to enemies nearby.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer"],
	},
}

const SCOPE_RANGE_MULT := 1.4
const IGNITE_DPS_RATIO := 0.4
const IGNITE_TIME := 3.0
const CRIT_CHANCE := 0.25
const CRIT_MULT := 3.5
## 폭발: 맞힌 적 위치에서 반경 안 다른 적들에게 (맞힌 피해 × 비율) 피해
const DETONATE_RADIUS := 90.0
const DETONATE_RATIO := 0.35
const DETONATE_FX_GAP := 0.08


static func get_def(id: String) -> Dictionary:
	return DEFS[id]


static func ids() -> Array:
	return DEFS.keys()


static func can_equip(id: String, tile: HexTile) -> bool:
	return tile != null and (DEFS[id]["attacks"] as Array).has(tile.attack)
