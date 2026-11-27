class_name EnemyDefs
extends RefCounted
## 적 종류. 능력치는 웨이브 기본값(Game.wave_enemy_*)에 곱하는 배율이다.
## sides: 모양 (3 삼각형, 4 사각형, 5 오각형 ...), star: true면 별 모양.
## from_wave: 이 웨이브부터 등장, weight: 등장 비중.
## melee: true면 타일에 닿아도 사라지지 않고 그 자리에서 hit_interval초마다 contact 피해를 준다.
##        타일이 부서지면 다음으로 가까운 타일로 이동한다.

const DEFS := {
	"grunt": {
		"name": "GRUNT", "color": Color(1.0, 0.3, 0.35), "sides": 3, "star": false,
		"radius": 12.0, "hp": 1.0, "speed": 1.0, "reward": 1.0, "contact": 1.0,
		"armor": 0.0, "from_wave": 1, "weight": 10.0,
	},
	"runner": {
		"name": "RUNNER", "color": Color(1.0, 0.95, 0.3), "sides": 4, "star": false,
		"radius": 9.0, "hp": 0.45, "speed": 1.8, "reward": 1.0, "contact": 0.6,
		"armor": 0.0, "from_wave": 2, "weight": 4.0,
	},
	"tank": {
		"name": "TANK", "color": Color(1.0, 0.5, 0.1), "sides": 4, "star": false,
		"radius": 20.0, "hp": 2.8, "speed": 0.55, "reward": 3.0, "contact": 2.5,
		"armor": 0.0, "from_wave": 4, "weight": 2.0,
	},
	"splitter": {
		"name": "SPLITTER", "color": Color(0.75, 1.0, 0.3), "sides": 5, "star": false,
		"radius": 15.0, "hp": 1.2, "speed": 0.85, "reward": 1.0, "contact": 1.2,
		"armor": 0.0, "from_wave": 6, "weight": 2.0, "splits_into": "runner", "split_count": 2,
	},
	"armored": {
		"name": "ARMORED", "color": Color(0.7, 0.75, 0.85), "sides": 6, "star": false,
		"radius": 15.0, "hp": 1.2, "speed": 0.8, "reward": 2.0, "contact": 1.5,
		"armor": 0.3, "from_wave": 8, "weight": 2.0,
	},
	"boss": {
		"name": "BOSS", "color": Color(1.0, 0.15, 0.6), "sides": 6, "star": true,
		"radius": 34.0, "hp": 18.0, "speed": 0.45, "reward": 20.0, "contact": 2.0,
		"armor": 0.2, "from_wave": 10, "weight": 0.0, "melee": true, "hit_interval": 1.0,
	},
}

## 이 웨이브마다 마지막에 보스 1마리 추가
const BOSS_EVERY := 10


static func get_def(kind: String) -> Dictionary:
	return DEFS[kind]


## wave에서 등장할 수 있는 일반 적 중 비중에 따라 하나를 고른다.
static func pick_kind(wave: int) -> String:
	var total := 0.0
	for kind in DEFS:
		if DEFS[kind]["from_wave"] <= wave:
			total += DEFS[kind]["weight"]
	var roll := randf() * total
	for kind in DEFS:
		if DEFS[kind]["from_wave"] <= wave and DEFS[kind]["weight"] > 0.0:
			roll -= DEFS[kind]["weight"]
			if roll <= 0.0:
				return kind
	return "grunt"


static func is_boss_wave(wave: int) -> bool:
	return wave > 0 and wave % BOSS_EVERY == 0
