class_name StageDefs
extends RefCounted
## 스테이지. 스테이지마다 나오는 적 구성(enemies)과 30웨이브 마지막 보스(boss)가 다르고,
## 적 체력과 피해 배율이 올라간다. 한 스테이지의 마지막 보스를 잡으면 다음 스테이지가 열린다.
## enemies: {적 종류: 등장 비중} (비어 있으면 EnemyDefs의 기본 비중). 등장 웨이브는 EnemyDefs from_wave.
##
## 스테이지 하나를 처음 깰 때마다:
##   - 영구 강화 상한이 Meta.CAP_PER_STAGE씩 오른다 (Meta.upgrade_max)
##   - "unlock"에 적힌 것이 풀린다 (새 영구 강화, 새 코어, 출정 칸 +1)
##
## hp: 적 체력 배율 (보스와 OVERLORD 포함), damage: 적이 타일에 주는 피해 배율,
## shards: 이 스테이지에서 받는 SHARD 배율 (웨이브 몫과 클리어 보너스 모두).
## 처치 보상(돈)은 스테이지와 상관없이 같다. 강해지는 몫은 영구 강화가 맡는다.
## 1, 2스테이지 체력은 영구 강화가 거의 없는 첫 판도 깰 만하게 낮춰 두었다
## (봇, 강화 없음: 1스테이지 승률 약 63%, 2스테이지는 강화 3레벨로 약 53%).

const STAGES := [
	# 1: 기본 적 5종 (예전 그대로), 보스 MONOLITH
	{"hp": 0.8, "damage": 1.0, "shards": 1.0, "color": Color(0.0, 0.95, 1.0),
			"unlock": "upgrade:bounty", "boss": "monolith", "enemies": {}},
	# 2: 돌진하는 DASHER, 회복 MENDER. 보스 COMET
	{"hp": 1.4, "damage": 1.2, "shards": 1.5, "color": Color(0.4, 1.0, 0.3),
			"unlock": "core:warp", "boss": "comet",
			"enemies": {"grunt": 9.0, "runner": 3.0, "dasher": 4.0, "tank": 2.0, "splitter": 2.0,
				"armored": 1.5, "mender": 1.2}},
	# 3: 사라지는 PHANTOM, 두 번 갈라지는 HYDRA. 보스 WRAITH
	{"hp": 2.4, "damage": 1.35, "shards": 2.0, "color": Color(1.0, 0.85, 0.1),
			"unlock": "loadout", "boss": "wraith",
			"enemies": {"grunt": 8.0, "runner": 2.0, "dasher": 2.0, "phantom": 4.0, "tank": 2.0,
				"splitter": 1.5, "armored": 1.5, "hydra": 1.5, "mender": 1.0}},
	# 4: 보호막 AEGIS, 단단한 적 많이. 보스 BASTION
	{"hp": 2.95, "damage": 1.5, "shards": 2.5, "color": Color(1.0, 0.5, 0.1),
			"unlock": "upgrade:tuning", "boss": "bastion",
			"enemies": {"grunt": 9.0, "runner": 2.5, "dasher": 2.0, "phantom": 2.0, "tank": 2.0,
				"splitter": 1.5, "armored": 2.0, "hydra": 1.2, "mender": 1.0, "aegis": 1.0}},
	# 5: 전부. 보스 OVERLORD
	{"hp": 4.0, "damage": 1.65, "shards": 3.0, "color": Color(1.0, 0.15, 0.6),
			"unlock": "", "boss": "overlord",
			"enemies": {"grunt": 8.0, "runner": 3.0, "dasher": 2.5, "phantom": 2.5, "tank": 2.0,
				"splitter": 1.5, "armored": 2.0, "hydra": 1.5, "mender": 1.2, "aegis": 1.2}},
]


static func count() -> int:
	return STAGES.size()


## n은 1부터. 범위를 벗어나면 가장 가까운 스테이지.
static func get_def(n: int) -> Dictionary:
	return STAGES[clampi(n, 1, STAGES.size()) - 1]


static func hp_mult(n: int) -> float:
	return get_def(n)["hp"]


static func damage_mult(n: int) -> float:
	return get_def(n)["damage"]


static func shard_mult(n: int) -> float:
	return get_def(n)["shards"]


## 스테이지 n의 30웨이브 마지막 보스 종류 (EnemyDefs).
static func boss(n: int) -> String:
	return get_def(n)["boss"]


## 스테이지 n의 일반 적 구성 {종류: 비중} (빈 사전이면 기본).
static func roster(n: int) -> Dictionary:
	return get_def(n)["enemies"]


## 이 스테이지에서 처음 나오는 일반 적 종류 (앞 스테이지 구성에 없던 것).
static func new_enemies(n: int) -> Array[String]:
	var result: Array[String] = []
	if n <= 1:
		return result
	var before := _kinds(n - 1)
	for kind in _kinds(n):
		if not before.has(kind):
			result.append(kind)
	return result


static func _kinds(n: int) -> Array:
	var r := roster(n)
	if r.is_empty():
		return EnemyDefs.DEFS.keys().filter(func(k: String) -> bool:
				return EnemyDefs.DEFS[k]["weight"] > 0.0)
	return r.keys()


## 시작 화면 스테이지 육각형에 마우스를 올렸을 때: 마지막 보스와 새로 나오는 적. 번역된 글.
static func tooltip(n: int) -> String:
	var lines: Array[String] = [title(n), Loc.t("BOSS  %s") % EnemyDefs.get_def(boss(n))["name"]]
	var fresh := new_enemies(n)
	if not fresh.is_empty():
		var names: Array[String] = []
		for kind in fresh:
			names.append(EnemyDefs.get_def(kind)["name"])
		lines.append(Loc.t("NEW ENEMIES  %s") % ", ".join(names))
	return "\n".join(lines)


static func color(n: int) -> Color:
	return get_def(n)["color"]


static func title(n: int) -> String:
	return Loc.t("STAGE %d") % n


## 스테이지 n을 처음 깼을 때 풀리는 것들의 짧은 이름 (클리어 화면, 시작 화면 안내). 번역된 글.
## 다음 스테이지 해금과 강화 상한 증가가 먼저, 그 뒤에 unlock.
static func reward_lines(n: int) -> Array[String]:
	var lines: Array[String] = []
	if n < count():
		lines.append(Loc.t("%s unlocked") % title(n + 1))
	lines.append(Loc.t("Upgrade limit +%d") % Meta.CAP_PER_STAGE)
	var unlock: String = get_def(n)["unlock"]
	if unlock.begins_with("upgrade:"):
		lines.append(Loc.t("New upgrade: %s") % Meta.get_upgrade(unlock.substr(8))["title"])
	elif unlock.begins_with("core:"):
		lines.append(Loc.t("New core: %s") % CoreDefs.get_def(unlock.substr(5))["name"])
	elif unlock == "loadout":
		lines.append(Loc.t("Loadout +1 slot"))
	return lines


## 이 unlock을 풀려면 깨야 하는 스테이지 (없으면 0).
static func stage_for_unlock(unlock: String) -> int:
	for i in STAGES.size():
		if STAGES[i]["unlock"] == unlock:
			return i + 1
	return 0
