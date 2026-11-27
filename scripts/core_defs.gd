class_name CoreDefs
extends RefCounted
## 코어 종류. 시작 화면에서 하나를 골라 판을 시작한다 (SHARD로 구매).
## 코어마다 액티브 스킬이 하나 있고, 쓰면 cooldown초(게임 시간) 동안 다시 못 쓴다.
## skill: "overdrive" (공격력 증가), "freeze" (적 정지), "nova" (충격파), "repair" (수리)

const DEFS := {
	"core": {
		"name": "CORE", "color": Color(0.0, 0.95, 1.0), "price": 0,
		"skill": "overdrive", "skill_name": "OVERDRIVE", "cooldown": 35.0,
		"duration": 6.0, "power": 0.6,
		"desc": "OVERDRIVE: all tiles deal +60% damage for 6 seconds.",
	},
	"cryo": {
		"name": "CRYO CORE", "color": Color(0.65, 0.9, 1.0), "price": 15,
		"skill": "freeze", "skill_name": "FREEZE", "cooldown": 30.0,
		"duration": 3.5, "power": 0.0,
		"desc": "FREEZE: every enemy stops moving and attacking for 3.5 seconds.",
	},
	"aegis": {
		"name": "AEGIS CORE", "color": Color(0.7, 1.0, 0.35), "price": 20,
		"skill": "repair", "skill_name": "REPAIR", "cooldown": 40.0,
		"duration": 0.0, "power": 0.5,
		"desc": "REPAIR: every tile recovers 50% of its max HP.",
	},
	"nova": {
		"name": "NOVA CORE", "color": Color(1.0, 0.5, 0.25), "price": 25,
		"skill": "nova", "skill_name": "NOVA", "cooldown": 40.0,
		"duration": 0.0, "power": 0.3, "radius": 560.0,
		"desc": "NOVA: a shockwave takes 30% of max HP from nearby enemies (bosses 10%).",
	},
}

## 시작 화면에 보이는 순서
const ORDER: Array[String] = ["core", "cryo", "aegis", "nova"]
## NOVA가 보스에게 주는 최대 체력 비율
const NOVA_BOSS_POWER := 0.1


static func get_def(id: String) -> Dictionary:
	return DEFS[id]
