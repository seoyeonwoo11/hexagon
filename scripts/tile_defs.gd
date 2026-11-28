class_name TileDefs
extends RefCounted
## 타일 종류별 기본 능력치. 새 타일 종류는 여기에 추가한다.
## attack: "laser" (CORE: 가까운 적에게 번쩍이는 광선, LASER: 한 적에게 꽂는 지속 광선), "spark" (적 사이를 튕기는 번개), "frost" (전체 감속 + 약한 피해),
##         "orbit" (타일 주위를 도는 구체가 닿은 적에게 피해), "drone" (드론이 쫓아가 들이받음),
##         "archer" (화살, 맞닿은 ARCHER 수만큼 강해짐), "burn" (가까운 적 쪽으로 부채꼴 불길, 화상),
##         "shock" (몇 초마다 퍼지는 충격파가 범위 안 적을 잠깐 스턴, 피해는 아주 약함),
##         "none" (공격 안 함. BOOSTER, BANK)

const DEFS := {
	"core": {
		"name": "CORE", "color": Color(0.0, 0.95, 1.0), "attack": "laser",
		"max_hp": 100.0, "damage": 5.0, "range": 260.0, "interval": 0.4, "income": 0,
		"desc": "Your base. Lose it and the run is over.",
	},
	"laser": {
		"name": "LASER", "color": Color(0.4, 1.0, 0.3), "attack": "laser",
		"max_hp": 60.0, "damage": 6.6, "range": 290.0, "interval": 0.45, "income": 0,
		"beam": true, "focus_step": 0.2, "focus_max": 6,
		"desc": "Locks a beam onto one enemy until it dies or leaves range. Gets stronger the longer it holds.",
	},
	"spark": {
		"name": "SPARK", "color": Color(1.0, 0.85, 0.1), "attack": "spark",
		"max_hp": 60.0, "damage": 9.0, "range": 300.0, "interval": 0.75, "income": 0,
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
		"max_hp": 60.0, "damage": 65.0, "range": 145.0, "interval": 0.35, "income": 0,
		"orbs": 3,
		"desc": "Glowing orbs circle the tile and hit enemies they touch.",
	},
	"drone": {
		"name": "DRONE HIVE", "color": Color(0.45, 0.55, 1.0), "attack": "drone",
		"max_hp": 60.0, "damage": 7.0, "range": 330.0, "interval": 0.5, "income": 0,
		"drones": 2,
		"desc": "Launches drones that roam nearby and ram enemies they find.",
	},
	"archer": {
		"name": "ARCHER", "color": Color(0.2, 1.0, 0.7), "attack": "archer",
		"max_hp": 60.0, "damage": 10.0, "range": 360.0, "interval": 0.7, "income": 0,
		"pack": 0.25,
		"desc": "Long-range arrows. +25% damage for every ARCHER touching it.",
	},
	"burn": {
		"name": "BURN", "color": Color(1.0, 0.42, 0.12), "attack": "burn",
		"max_hp": 60.0, "damage": 4.0, "range": 230.0, "interval": 0.2, "income": 0,
		"cone": 0.5, "burn_time": 2.5,
		"desc": "Flamethrower. Sprays a cone of fire at the nearest enemy and sets it ablaze. Fire spreads between enemies that touch.",
	},
	"shock": {
		"name": "SHOCK", "color": Color(0.9, 0.92, 1.0), "attack": "shock",
		"max_hp": 60.0, "damage": 8.0, "range": 230.0, "interval": 2.5, "income": 0,
		"stun": 1.0,
		"desc": "Every 2.5 seconds sends out a shockwave that briefly stuns enemies it passes. Attack speed makes the wave spread faster. Bosses are stunned for less.",
	},
	"booster": {
		"name": "BOOSTER", "color": Color(1.0, 0.6, 0.15), "attack": "none",
		"max_hp": 60.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 0,
		"haste": 0.25,
		"desc": "Adjacent tiles attack 25% faster. A second BOOSTER on the same tile adds half.",
	},
	"bank": {
		"name": "BANK", "color": Color(0.8, 0.45, 1.0), "attack": "none",
		"max_hp": 50.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "income": 12,
		"desc": "Earns money after every wave, plus interest on your savings.",
	},
}

## 웨이브 클리어 카드로 얻을 수 있는 타일.
const PLACEABLE: Array[String] = ["laser", "spark", "frost", "orbit", "booster", "bank", "drone", "archer", "burn", "shock"]


static func get_def(kind: String) -> Dictionary:
	return DEFS[kind]
