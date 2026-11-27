class_name TileDefs
extends RefCounted
## 타일 종류별 기본 능력치. 새 타일 종류는 여기에 추가한다.
## attack: "laser" (가장 가까운 적 1명), "spark" (적 사이를 튕기는 번개), "frost" (전체 감속 + 약한 피해),
##         "orbit" (타일 주위를 도는 구체가 닿은 적에게 피해), "drone" (드론이 쫓아가 들이받음),
##         "archer" (화살, 맞닿은 ARCHER 수만큼 강해짐), "none" (공격 안 함. BOOSTER, PRISM, BANK)

const DEFS := {
	"core": {
		"name": "CORE", "color": Color(0.0, 0.95, 1.0), "attack": "laser",
		"max_hp": 100.0, "damage": 5.0, "range": 260.0, "interval": 0.4, "income": 0,
		"desc": "Your base. Lose it and the run is over.",
	},
	"laser": {
		"name": "LASER", "color": Color(0.4, 1.0, 0.3), "attack": "laser",
		"max_hp": 60.0, "damage": 6.0, "range": 290.0, "interval": 0.45, "income": 0,
		"pierce": true, "focus_step": 0.12, "focus_max": 6,
		"desc": "Piercing beam that hits everything in a line. Gets stronger the longer it stays on one target.",
	},
	"spark": {
		"name": "SPARK", "color": Color(1.0, 0.85, 0.1), "attack": "spark",
		"max_hp": 60.0, "damage": 8.0, "range": 300.0, "interval": 1.0, "income": 0,
		"bounces": 3, "bounce_range": 220.0,
		"desc": "Fires a bolt that bounces between nearby enemies.",
	},
	"frost": {
		"name": "FROST", "color": Color(0.55, 0.75, 1.0), "attack": "frost",
		"max_hp": 60.0, "damage": 1.5, "range": 210.0, "interval": 0.5, "income": 0,
		"desc": "Slows every enemy in range.",
	},
	"orbit": {
		"name": "ORBIT", "color": Color(1.0, 0.3, 0.9), "attack": "orbit",
		"max_hp": 60.0, "damage": 17.0, "range": 145.0, "interval": 0.35, "income": 0,
		"orbs": 3,
		"desc": "Glowing orbs circle the tile and hit enemies they touch.",
	},
	"drone": {
		"name": "DRONE HIVE", "color": Color(0.45, 0.55, 1.0), "attack": "drone",
		"max_hp": 60.0, "damage": 5.0, "range": 330.0, "interval": 0.5, "income": 0,
		"drones": 2,
		"desc": "Launches drones that roam nearby and ram enemies they find.",
	},
	"archer": {
		"name": "ARCHER", "color": Color(0.2, 1.0, 0.7), "attack": "archer",
		"max_hp": 60.0, "damage": 12.0, "range": 360.0, "interval": 0.7, "income": 0,
		"pack": 0.35,
		"desc": "Long-range arrows. +40% damage for every ARCHER touching it.",
	},
	"prism": {
		"name": "PRISM", "color": Color(0.92, 0.88, 1.0), "attack": "none",
		"max_hp": 60.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 0,
		"split": 0.6,
		"desc": "Splits the shots of touching LASER and ARCHER tiles into 3 rays, fired away from the shooter.",
	},
	"booster": {
		"name": "BOOSTER", "color": Color(1.0, 0.6, 0.15), "attack": "none",
		"max_hp": 60.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 0,
		"haste": 0.25,
		"desc": "Adjacent tiles attack 25% faster.",
	},
	"bank": {
		"name": "BANK", "color": Color(0.8, 0.45, 1.0), "attack": "none",
		"max_hp": 50.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 12,
		"desc": "Earns money after every wave, plus interest on your savings.",
	},
}

## 웨이브 클리어 카드로 얻을 수 있는 타일.
const PLACEABLE: Array[String] = ["laser", "spark", "frost", "orbit", "booster", "bank", "drone", "archer", "prism"]


static func get_def(kind: String) -> Dictionary:
	return DEFS[kind]
