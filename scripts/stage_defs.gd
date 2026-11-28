class_name StageDefs
extends RefCounted
## 스테이지. 적 종류와 등장 순서, 30웨이브 OVERLORD는 모든 스테이지가 같고 난이도만 올라간다.
## 한 스테이지의 OVERLORD를 잡으면 다음 스테이지가 열린다.
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
	{"hp": 0.8, "damage": 1.0, "shards": 1.0, "color": Color(0.0, 0.95, 1.0),
			"unlock": "upgrade:bounty"},
	{"hp": 1.4, "damage": 1.2, "shards": 1.5, "color": Color(0.4, 1.0, 0.3),
			"unlock": "core:warp"},
	{"hp": 2.4, "damage": 1.35, "shards": 2.0, "color": Color(1.0, 0.85, 0.1),
			"unlock": "loadout"},
	{"hp": 2.95, "damage": 1.5, "shards": 2.5, "color": Color(1.0, 0.5, 0.1),
			"unlock": "upgrade:tuning"},
	{"hp": 4.0, "damage": 1.65, "shards": 3.0, "color": Color(1.0, 0.15, 0.6),
			"unlock": ""},
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
