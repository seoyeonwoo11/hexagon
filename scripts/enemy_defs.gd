class_name EnemyDefs
extends RefCounted
## 적 종류. 능력치는 웨이브 기본값(Game.wave_enemy_*)에 곱하는 배율이다.
## sides: 모양 (3 삼각형, 4 사각형, 5 오각형 ...), star: true면 별 모양.
## from_wave: 이 웨이브부터 등장, weight: 기본 등장 비중 (스테이지마다 StageDefs "enemies"가 덮어씀).
## melee: true면 타일에 닿아도 사라지지 않고 그 자리에서 hit_interval초마다 contact 피해를 준다.
##        타일이 부서지면 다음으로 가까운 타일로 이동한다.
##
## 기믹 (없으면 안 씀):
##   face: true면 빙빙 돌지 않고 가는 방향을 바라본다
##   dash_every/dash_time/dash_speed: dash_every초마다 dash_time초 동안 dash_speed배로 돌진.
##       dash_windup초 동안 멈춰 번쩍인 뒤 돌진, 돌진 중 처음 때리는 근접 공격은 dash_hit배 (COMET)
##   aura: "heal" 또는 "shield". aura_every초마다 aura_radius 안 적(자기 포함)에게
##       최대 체력의 aura_amount (보스는 aura_boss)만큼 회복 / 보호막. 보호막은 먼저 깎이고 쌓이지 않음
##   cloak_every/cloak_time: cloak_every초 보이다가 cloak_time초 동안 은신 (맞지도, 노려지지도 않음).
##       cloak_regen: 은신 중 초당 회복 (최대 체력 비율), cloak_summon: 은신할 때 summon을 부름
##   quake_at: 체력이 이 비율들 아래로 처음 떨어질 때마다 quake를 quake_count마리 둥글게 부름
##   final: 스테이지 마지막(FINAL_WAVE) 보스. 화면 위 체력 막대, 잡으면 클리어
##   crown: OVERLORD 왕관 고리를 그림
##   spin: 몸체 회전 속도 배율 (기본 1), sway: 돌지 않고 좌우로 흔들리는 폭, deco_spin: 보스 바깥 장식 회전 속도

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
	## 돌진: 평소엔 GRUNT 속도, 2.2초마다 0.45초 동안 3.2배로 튀어나간다. 가는 쪽을 보는 화살촉.
	"dasher": {
		"name": "DASHER", "color": Color(1.0, 0.35, 0.75), "sides": 3, "star": false,
		"radius": 11.0, "hp": 0.6, "speed": 0.95, "reward": 1.0, "contact": 0.8,
		"armor": 0.0, "from_wave": 3, "weight": 0.0, "face": true,
		"dash_every": 2.2, "dash_time": 0.45, "dash_speed": 3.2,
	},
	## 회복 엘리트: 2.5초마다 주변(150) 적의 체력을 12% 채운다 (보스는 2%). 초록 십자.
	"mender": {
		"name": "MENDER", "color": Color(0.3, 1.0, 0.55), "sides": 4, "star": false,
		"radius": 15.0, "hp": 1.5, "speed": 0.7, "reward": 2.5, "contact": 1.0,
		"armor": 0.0, "from_wave": 8, "weight": 0.0,
		"aura": "heal", "aura_every": 2.5, "aura_radius": 150.0, "aura_amount": 0.12, "aura_boss": 0.02,
	},
	## 투명: 2.2초 보이다가 1.6초 동안 사라진다 (그동안 맞지 않음). 마름모 안에 눈.
	"phantom": {
		"name": "PHANTOM", "color": Color(0.8, 0.6, 1.0), "sides": 4, "star": false,
		"radius": 12.0, "hp": 0.8, "speed": 1.1, "reward": 1.5, "contact": 1.0,
		"armor": 0.0, "from_wave": 4, "weight": 0.0,
		"cloak_every": 2.2, "cloak_time": 1.6,
	},
	## 큰 분열: 처치되면 SPLITTER 2마리 (그게 또 RUNNER로 갈라짐).
	"hydra": {
		"name": "HYDRA", "color": Color(0.4, 1.0, 0.85), "sides": 5, "star": true,
		"radius": 20.0, "hp": 1.8, "speed": 0.6, "reward": 2.0, "contact": 1.8,
		"armor": 0.0, "from_wave": 11, "weight": 0.0, "splits_into": "splitter", "split_count": 2,
	},
	## 보호막 엘리트: 4초마다 주변(160) 적에게 최대 체력 30% 보호막 (보스는 8%).
	"aegis": {
		"name": "AEGIS", "color": Color(0.55, 0.7, 1.0), "sides": 6, "star": false,
		"radius": 16.0, "hp": 1.4, "speed": 0.7, "reward": 2.5, "contact": 1.2,
		"armor": 0.1, "from_wave": 7, "weight": 0.0,
		"aura": "shield", "aura_every": 4.0, "aura_radius": 160.0, "aura_amount": 0.3, "aura_boss": 0.08,
	},
	"boss": {
		"name": "BOSS", "color": Color(1.0, 0.15, 0.6), "sides": 6, "star": true,
		"radius": 34.0, "hp": 18.0, "speed": 0.45, "reward": 20.0, "contact": 2.0,
		"armor": 0.2, "from_wave": 10, "weight": 0.0, "melee": true, "hit_interval": 1.0,
		"is_boss": true,
	},
	## ---- 스테이지 마지막 보스 (StageDefs "boss") ----
	## 1스테이지: 무거운 돌기둥. 2초마다 GRUNT 1마리, 체력 75/50/25%에서 GRUNT 6마리를 둥글게.
	"monolith": {
		"name": "MONOLITH", "color": Color(1.0, 0.28, 0.22), "sides": 4, "star": false,
		"radius": 44.0, "hp": 46.0, "speed": 0.33, "reward": 60.0, "contact": 2.5,
		"armor": 0.25, "from_wave": 999, "weight": 0.0, "melee": true, "hit_interval": 0.9,
		"is_boss": true, "final": true, "summon": "grunt", "summon_count": 1, "summon_every": 2.0,
		"quake_at": [0.75, 0.5, 0.25], "quake": "grunt", "quake_count": 6,
		"enrage_at": 0.25, "enrage_speed": 1.4, "spin": 0.12, "deco_spin": 0.7,
	},
	## 2스테이지: 혜성. 3.5초마다 0.8초 멈춰 번쩍인 뒤 6배로 들이받는다 (첫 타격 4.5배).
	## 들이받으면 돌진을 시작한 자리로 튕겨 돌아간다. 돌진 준비와 돌진 중에는 감속, 빙결, 스턴, 밀치기 무시.
	## 6초마다 DASHER 2마리.
	"comet": {
		"name": "COMET", "color": Color(1.0, 0.4, 0.8), "sides": 3, "star": false, "face": true,
		"radius": 40.0, "hp": 46.0, "speed": 0.38, "reward": 60.0, "contact": 2.2,
		"armor": 0.2, "from_wave": 999, "weight": 0.0, "melee": true, "hit_interval": 1.0,
		"is_boss": true, "final": true, "summon": "dasher", "summon_count": 2, "summon_every": 6.0,
		"dash_every": 3.5, "dash_time": 0.9, "dash_speed": 6.0, "dash_windup": 0.8, "dash_hit": 4.5,
		"dash_unstoppable": true,
		"enrage_at": 0.4, "enrage_speed": 1.3, "deco_spin": 1.2,
	},
	## 3스테이지: 망령. 5초 보이다가 2.5초 은신 (은신 중 초당 2.5% 회복), 숨을 때마다 PHANTOM 3마리.
	"wraith": {
		"name": "WRAITH", "color": Color(0.75, 0.55, 1.0), "sides": 5, "star": false,
		"radius": 42.0, "hp": 44.0, "speed": 0.38, "reward": 60.0, "contact": 2.4,
		"armor": 0.2, "from_wave": 999, "weight": 0.0, "melee": true, "hit_interval": 0.9,
		"is_boss": true, "final": true, "summon": "phantom", "summon_count": 3,
		"cloak_every": 5.0, "cloak_time": 2.5, "cloak_regen": 0.025, "cloak_summon": true,
		"enrage_at": 0.35, "enrage_speed": 1.4, "sway": 0.15, "deco_spin": -0.5,
	},
	## 4스테이지: 요새. 6초마다 자기와 주변(200) 적에게 보호막 (자기는 8%, 다른 적은 20%),
	## 7초마다 ARMORED 2마리.
	"bastion": {
		"name": "BASTION", "color": Color(1.0, 0.55, 0.15), "sides": 6, "star": false,
		"radius": 46.0, "hp": 40.0, "speed": 0.3, "reward": 60.0, "contact": 2.6,
		"armor": 0.3, "from_wave": 999, "weight": 0.0, "melee": true, "hit_interval": 0.9,
		"is_boss": true, "final": true, "summon": "armored", "summon_count": 2, "summon_every": 7.0,
		"aura": "shield", "aura_every": 6.0, "aura_radius": 200.0, "aura_amount": 0.2, "aura_boss": 0.08,
		"enrage_at": 0.3, "enrage_speed": 1.5, "spin": 0.08, "deco_spin": -0.35,
	},
	## 5스테이지 최종 보스. summon_every초마다 summon을 summon_count마리 부르고,
	## 체력이 enrage_at 아래로 떨어지면 enrage_speed배 빨라지고 두 배 자주 부른다.
	"overlord": {
		"name": "OVERLORD", "color": Color(1.0, 0.82, 0.25), "sides": 8, "star": true,
		"radius": 46.0, "hp": 52.0, "speed": 0.35, "reward": 60.0, "contact": 2.5,
		"armor": 0.3, "from_wave": 999, "weight": 0.0, "melee": true, "hit_interval": 0.8,
		"is_boss": true, "summon": "runner", "summon_count": 4, "summon_every": 5.0,
		"enrage_at": 0.5, "enrage_speed": 1.6, "final": true, "crown": true, "deco_spin": 0.4,
	},
}

## 이 웨이브의 마지막 적이 스테이지 보스. 잡으면 클리어 (그 뒤는 고르면 무한 모드).
const FINAL_WAVE := 30

## 이 웨이브마다 마지막에 보스 1마리 추가
const BOSS_EVERY := 10

static func get_def(kind: String) -> Dictionary:
	return DEFS[kind]


## wave에서 등장할 수 있는 일반 적 중 비중에 따라 하나를 고른다.
## roster: {종류: 비중} (StageDefs.roster). 비어 있으면 DEFS의 weight. 등장 웨이브는 DEFS의 from_wave.
static func pick_kind(wave: int, roster: Dictionary = {}) -> String:
	var weights := roster
	if weights.is_empty():
		weights = {}
		for kind in DEFS:
			weights[kind] = DEFS[kind]["weight"]
	var total := 0.0
	for kind in weights:
		if DEFS[kind]["from_wave"] <= wave:
			total += weights[kind]
	var roll := randf() * total
	for kind in weights:
		if DEFS[kind]["from_wave"] <= wave and weights[kind] > 0.0:
			roll -= weights[kind]
			if roll <= 0.0:
				return kind
	return "grunt"


static func is_boss_wave(wave: int) -> bool:
	return wave > 0 and wave % BOSS_EVERY == 0


## 웨이브 마지막에 나오는 보스 종류. FINAL_WAVE는 스테이지 보스(final_boss), 그 밖의 보스 웨이브는 BOSS.
static func boss_kind(wave: int, final_boss := "overlord") -> String:
	return final_boss if wave == FINAL_WAVE else "boss"
