class_name GearDefs
extends RefCounted
## 타일 장비. 타일마다 1칸, 레벨 SECOND_SLOT_LEVEL부터 2칸.
## 칸이 꽉 찬 타일에 새로 달면 가장 먼저 단 장비가 빠진다. 같은 장비는 한 타일에 1개만.
## attacks: 장착할 수 있는 타일의 공격 방식 (TileDefs의 attack 값).

const DEFS := {
	"scope": {
		"name": "SCOPE", "color": Color(0.6, 1.0, 0.95),
		"desc": "+40% attack range.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer", "burn", "shock"],
	},
	"splitter": {
		"name": "SPLITTER", "color": Color(1.0, 0.6, 0.2),
		"desc": "Hits one extra target each attack (ORBIT: +1 orb, HIVE: +1 drone, BURN: +1 flame).",
		"attacks": ["laser", "spark", "orbit", "drone", "archer", "burn"],
	},
	"igniter": {
		"name": "IGNITER", "color": Color(1.0, 0.4, 0.15),
		"desc": "Hits set enemies on fire for 3 seconds.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer", "shock"],
	},
	"crit": {
		"name": "CRIT LENS", "color": Color(1.0, 0.3, 0.6),
		"desc": "25% chance to deal 3.5x damage.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer", "burn", "shock"],
	},
	"detonator": {
		"name": "DETONATOR", "color": Color(1.0, 0.75, 0.3),
		"desc": "Every hit explodes, dealing 45% of it to enemies nearby.",
		"attacks": ["laser", "spark", "frost", "orbit", "drone", "archer", "burn", "shock"],
	},
}

## 이 레벨부터 장비를 하나 더 달 수 있다
const SECOND_SLOT_LEVEL := 5

const SCOPE_RANGE_MULT := 1.4
const IGNITE_DPS_RATIO := 0.4
const IGNITE_TIME := 3.0
const CRIT_CHANCE := 0.25
const CRIT_MULT := 3.5
## 폭발: 맞힌 적 위치에서 반경 안 다른 적들에게 (맞힌 피해 × 비율) 피해
const DETONATE_RADIUS := 90.0
const DETONATE_RATIO := 0.45
const DETONATE_FX_GAP := 0.08


static func get_def(id: String) -> Dictionary:
	return DEFS[id]


static func ids() -> Array:
	return DEFS.keys()


## 타일에 이 장비를 달 수 있는지. 이미 단 장비는 다시 달 수 없다.
static func can_equip(id: String, tile: HexTile) -> bool:
	return tile != null and (DEFS[id]["attacks"] as Array).has(tile.attack) and not tile.has_gear(id)
