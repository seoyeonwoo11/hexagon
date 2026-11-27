class_name TileDefs
extends RefCounted
## 타일 종류별 기본 능력치. 새 타일 종류는 여기에 추가한다.
## attack: "laser" (가장 가까운 적 1명), "pulse" (사거리 안 전체), "frost" (전체 감속 + 약한 피해),
##         "none" (공격 안 함)

const DEFS := {
	"core": {
		"name": "CORE", "color": Color(0.0, 0.95, 1.0), "attack": "laser",
		"max_hp": 100.0, "damage": 5.0, "range": 260.0, "interval": 0.4, "income": 0,
		"desc": "Your base. Lose it and the run is over.",
	},
	"laser": {
		"name": "LASER", "color": Color(0.4, 1.0, 0.3), "attack": "laser",
		"max_hp": 60.0, "damage": 6.0, "range": 290.0, "interval": 0.45, "income": 0,
		"desc": "Fires at the nearest enemy.",
	},
	"pulse": {
		"name": "PULSE", "color": Color(1.0, 0.85, 0.1), "attack": "pulse",
		"max_hp": 70.0, "damage": 7.0, "range": 170.0, "interval": 1.4, "income": 0,
		"desc": "Shockwave hits every enemy nearby.",
	},
	"frost": {
		"name": "FROST", "color": Color(0.55, 0.75, 1.0), "attack": "frost",
		"max_hp": 60.0, "damage": 1.5, "range": 210.0, "interval": 0.5, "income": 0,
		"desc": "Slows every enemy in range.",
	},
	"bank": {
		"name": "BANK", "color": Color(0.8, 0.45, 1.0), "attack": "none",
		"max_hp": 50.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 6,
		"desc": "Earns money after every wave.",
	},
}

## 웨이브 클리어 카드로 얻을 수 있는 타일.
const PLACEABLE: Array[String] = ["laser", "pulse", "frost", "bank"]


static func get_def(kind: String) -> Dictionary:
	return DEFS[kind]
