class_name Meta
extends RefCounted
## 판과 판 사이에 남는 성장 (메타 진행). 게임이 끝나면 버틴 웨이브만큼 SHARD를 받고,
## 시작 화면(Shop)에서 SHARD로 기본 능력치를 영구 강화하거나 새 타일을 구매한다.
## 저장 위치: user://meta.cfg (Windows: %APPDATA%/Godot/app_userdata/<프로젝트 이름>/)

## 영구 강화. 비용은 cost_base + cost_step × 현재 레벨.
## 상한은 max + 깬 스테이지 수 × CAP_PER_STAGE (upgrade_max). "fixed": true면 max에서 멈춘다.
## "unlock"이 있으면 그 스테이지 보상(StageDefs의 "upgrade:<id>")으로 풀린다.
const UPGRADES := [
	{"id": "core_hp", "title": "CORE PLATING", "desc": "Core +25 max HP", "max": 5,
			"cost_base": 5, "cost_step": 5, "color": Color(0.0, 0.95, 1.0)},
	{"id": "damage", "title": "POWER GRID", "desc": "All tiles +8% damage", "max": 5,
			"cost_base": 6, "cost_step": 6, "color": Color(1.0, 0.35, 0.45)},
	{"id": "rate", "title": "FAST CYCLE", "desc": "All tiles attack 5% faster", "max": 5,
			"cost_base": 6, "cost_step": 6, "color": Color(0.3, 1.0, 0.85)},
	{"id": "tile_hp", "title": "HARD SHELL", "desc": "All tiles +10% max HP", "max": 5,
			"cost_base": 4, "cost_step": 4, "color": Color(0.55, 0.75, 1.0)},
	{"id": "money", "title": "SEED FUND", "desc": "Start each run with +$10", "max": 5,
			"cost_base": 4, "cost_step": 4, "color": Color(1.0, 0.85, 0.1)},
	{"id": "bounty", "title": "BOUNTY", "desc": "Enemies drop +8% money", "max": 5,
			"cost_base": 10, "cost_step": 8, "color": Color(1.0, 0.65, 0.2), "fixed": true,
			"unlock": "upgrade:bounty"},
	{"id": "tuning", "title": "SKILL TUNING", "desc": "Core skill cooldown -7%", "max": 5,
			"cost_base": 12, "cost_step": 10, "color": Color(0.75, 0.55, 1.0), "fixed": true,
			"unlock": "upgrade:tuning"},
]
## 스테이지를 처음 깰 때마다 영구 강화 상한이 오르는 단계 수
const CAP_PER_STAGE := 3

## 처음부터 쓸 수 있는 타일과 SHARD로 사야 하는 타일 (가격).
const STARTER_TILES: Array[String] = ["laser", "frost", "bank"]
const TILE_PRICES := {"spark": 12, "archer": 15, "orbit": 20, "drone": 25}
## 게임에서 빠진 타일과 그때 가격. 예전 저장 파일에서 산 적이 있으면 SHARD로 돌려준다.
const REMOVED_TILES := {"prism": 20}
## 한 판에 들고 갈 수 있는 타일 종류 수 (출정 타일). 카드에는 이 타일들만 나온다.
## 스테이지 보상 "loadout"을 받으면 +1 (max_loadout).
const MAX_LOADOUT := 6

## 효과 수치 (레벨당)
const CORE_HP_PER_LV := 25.0
const DAMAGE_PER_LV := 0.08
const RATE_PER_LV := 0.05
const TILE_HP_PER_LV := 0.10
const MONEY_PER_LV := 10
const BOUNTY_PER_LV := 0.08
const TUNING_PER_LV := 0.07

static var save_path := "user://meta.cfg"
static var shards := 0
static var best_wave := 0
static var levels := {}
static var unlocked: Array[String] = []
## 고른 코어 종류 (CoreDefs)와 산 코어들
static var core_type := "core"
static var unlocked_cores: Array[String] = []
## 출정 타일 (최대 MAX_LOADOUT개)
static var loadout: Array[String] = ["laser", "frost", "booster", "bank"]
## 마지막 판 결과 (시작 화면 안내용). wave가 0이면 아직 끝난 판이 없음.
static var last_run_wave := 0
static var last_run_shards := 0
## 마지막 판이 최종 보스를 잡았는지, 최종 보스를 잡은 횟수
static var last_run_victory := false
static var clears := 0
## 최종 보스를 잡으면 웨이브 몫에 더해 받는 SHARD
const VICTORY_BONUS := 30
## 스테이지: 깬 가장 높은 스테이지(0이면 아직 없음), 고른 스테이지, 스테이지별 최고 웨이브,
## 마지막 판의 스테이지, 마지막 판에서 새로 풀린 것 (StageDefs.reward_lines, 클리어 화면용)
static var stage_cleared := 0
static var stage := 1
static var stage_best := {}
static var last_run_stage := 1
static var last_unlocks: Array[String] = []


## 버틴 웨이브(다 처리한 웨이브 수)만큼 SHARD. 보스 웨이브(10, 20, ...)는 +5.
## 높은 스테이지일수록 StageDefs.shard_mult배.
static func shards_for_run(reached_wave: int, in_stage := 1) -> int:
	var cleared := maxi(reached_wave - 1, 0)
	return roundi((cleared + 5 * (cleared / EnemyDefs.BOSS_EVERY)) * StageDefs.shard_mult(in_stage))


## 최종 보스를 잡으면 받는 SHARD: 30웨이브 몫 + 클리어 보너스, 둘 다 스테이지 배율.
static func shards_for_victory(in_stage := 1) -> int:
	return shards_for_run(EnemyDefs.FINAL_WAVE + 1, in_stage) \
			+ roundi(VICTORY_BONUS * StageDefs.shard_mult(in_stage))


## 판이 끝났을 때 한 번 호출. 받은 SHARD를 더하고 저장한다.
## 클리어 뒤 무한 모드였다면 banked(이미 계산된 웨이브 몫)는 빼고 주고,
## prior(클리어 때 받은 SHARD)는 결과 안내에만 합쳐 보여 준다.
static func finish_run(reached_wave: int, banked := 0, prior := 0, in_stage := 1) -> int:
	var earned := maxi(shards_for_run(reached_wave, in_stage) - banked, 0)
	shards += earned
	best_wave = maxi(best_wave, reached_wave)
	stage_best[in_stage] = maxi(stage_best_wave(in_stage), reached_wave)
	last_run_wave = reached_wave
	last_run_shards = earned + prior
	last_run_victory = prior > 0
	last_run_stage = in_stage
	if prior == 0:
		last_unlocks = []
	save_data()
	return earned


## 최종 보스를 잡았을 때 한 번 호출: 웨이브 몫 + VICTORY_BONUS (스테이지 배율).
## 그 스테이지를 처음 깼다면 다음 스테이지와 보상이 풀린다 (last_unlocks에 적힘).
static func finish_victory(in_stage := 1) -> int:
	var earned := shards_for_victory(in_stage)
	shards += earned
	clears += 1
	best_wave = maxi(best_wave, EnemyDefs.FINAL_WAVE)
	stage_best[in_stage] = maxi(stage_best_wave(in_stage), EnemyDefs.FINAL_WAVE)
	last_run_wave = EnemyDefs.FINAL_WAVE
	last_run_shards = earned
	last_run_victory = true
	last_run_stage = in_stage
	last_unlocks = []
	if in_stage > stage_cleared:
		stage_cleared = in_stage
		last_unlocks = StageDefs.reward_lines(in_stage)
	save_data()
	return earned


## 스테이지 n이 열렸는지 (1은 처음부터, 그 뒤는 앞 스테이지를 깨야 열림).
static func is_stage_unlocked(n: int) -> bool:
	return n >= 1 and n <= mini(stage_cleared + 1, StageDefs.count())


static func is_stage_cleared(n: int) -> bool:
	return n <= stage_cleared


static func select_stage(n: int) -> bool:
	if not is_stage_unlocked(n) or stage == n:
		return false
	stage = n
	save_data()
	return true


## 결과창에서 시작 화면으로 갈 때: 방금 처음 깬 스테이지라면 다음 스테이지를 골라 둔다.
static func advance_after_clear() -> void:
	if last_run_victory and last_run_stage == stage_cleared and stage == last_run_stage \
			and not last_unlocks.is_empty():
		select_stage(stage_cleared + 1)


static func stage_best_wave(n: int) -> int:
	return stage_best.get(n, 0)


## 스테이지 보상(StageDefs의 "unlock")을 받았는지.
static func has_unlock(unlock: String) -> bool:
	var n := StageDefs.stage_for_unlock(unlock)
	return n > 0 and stage_cleared >= n


static func level(id: String) -> int:
	return levels.get(id, 0)


static func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## 지금 살 수 있는 최대 레벨: 기본 max + 깬 스테이지 × CAP_PER_STAGE ("fixed"면 max 그대로).
static func upgrade_max(id: String) -> int:
	var u := get_upgrade(id)
	if u.get("fixed", false):
		return u["max"]
	return u["max"] + CAP_PER_STAGE * stage_cleared


## 스테이지 보상으로 풀리는 강화면 그 보상을 받았는지. 아니면 늘 true.
static func is_upgrade_unlocked(id: String) -> bool:
	var unlock: String = get_upgrade(id).get("unlock", "")
	return unlock == "" or has_unlock(unlock)


## 다음 레벨 비용. 이미 최대거나 아직 안 풀렸으면 -1.
static func upgrade_cost(id: String) -> int:
	var u := get_upgrade(id)
	var lv := level(id)
	if lv >= upgrade_max(id) or not is_upgrade_unlocked(id):
		return -1
	return u["cost_base"] + u["cost_step"] * lv


static func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or shards < cost:
		return false
	shards -= cost
	levels[id] = level(id) + 1
	save_data()
	return true


static func is_tile_unlocked(kind: String) -> bool:
	return STARTER_TILES.has(kind) or unlocked.has(kind) or not TILE_PRICES.has(kind)


static func buy_tile(kind: String) -> bool:
	if is_tile_unlocked(kind) or shards < TILE_PRICES[kind]:
		return false
	shards -= TILE_PRICES[kind]
	unlocked.append(kind)
	# 자리가 있으면 바로 출정 타일에 넣는다
	if loadout.size() < max_loadout():
		loadout.append(kind)
	save_data()
	return true


static func is_core_unlocked(id: String) -> bool:
	return CoreDefs.get_def(id)["price"] == 0 or unlocked_cores.has(id)


## 살 수 있는 코어인지: 스테이지 보상("core:<id>")으로 풀리는 코어는 그 스테이지를 깨야 한다.
static func is_core_available(id: String) -> bool:
	var n := StageDefs.stage_for_unlock("core:" + id)
	return n == 0 or stage_cleared >= n


## 코어 구매. 사면 바로 그 코어를 고른다.
static func buy_core(id: String) -> bool:
	var price: int = CoreDefs.get_def(id)["price"]
	if is_core_unlocked(id) or not is_core_available(id) or shards < price:
		return false
	shards -= price
	unlocked_cores.append(id)
	core_type = id
	save_data()
	return true


## 판에 쓸 코어를 고른다 (산 코어만).
static func select_core(id: String) -> bool:
	if not is_core_unlocked(id) or core_type == id:
		return false
	core_type = id
	save_data()
	return true


## 출정 타일에 들어 있는지 (풀린 타일만).
static func in_loadout(kind: String) -> bool:
	return loadout.has(kind) and is_tile_unlocked(kind)


## 출정 칸 수: MAX_LOADOUT, 스테이지 보상 "loadout"을 받으면 +1.
static func max_loadout() -> int:
	return MAX_LOADOUT + (1 if has_unlock("loadout") else 0)


static func loadout_full() -> bool:
	return loadout.size() >= max_loadout()


## 출정 타일에 넣거나 뺀다. 마지막 1개는 뺄 수 없고, 가득 차면 넣을 수 없다. 바뀌면 true.
static func toggle_loadout(kind: String) -> bool:
	if not is_tile_unlocked(kind):
		return false
	if loadout.has(kind):
		if loadout.size() <= 1:
			return false
		loadout.erase(kind)
	elif loadout_full():
		return false
	else:
		loadout.append(kind)
	save_data()
	return true


## 기본 출정 타일: 풀린 타일을 TileDefs.PLACEABLE 순서로 max_loadout()개까지.
static func default_loadout() -> Array[String]:
	var result: Array[String] = []
	for kind in TileDefs.PLACEABLE:
		if is_tile_unlocked(kind) and result.size() < max_loadout():
			result.append(kind)
	return result


## 판 시작 시 적용할 값들
static func core_hp_bonus() -> float:
	return CORE_HP_PER_LV * level("core_hp")


static func damage_mult() -> float:
	return 1.0 + DAMAGE_PER_LV * level("damage")


static func rate_mult() -> float:
	return 1.0 + RATE_PER_LV * level("rate")


static func tile_hp_mult() -> float:
	return 1.0 + TILE_HP_PER_LV * level("tile_hp")


static func start_money() -> int:
	return MONEY_PER_LV * level("money")


## 처치 보상 배율 (BOUNTY)
static func bounty_mult() -> float:
	return 1.0 + BOUNTY_PER_LV * level("bounty")


## 코어 스킬 쿨다운 배율 (SKILL TUNING)
static func cooldown_mult() -> float:
	return 1.0 - TUNING_PER_LV * level("tuning")


static func reset() -> void:
	shards = 0
	best_wave = 0
	levels = {}
	unlocked = []
	loadout = default_loadout()
	core_type = "core"
	unlocked_cores = []
	last_run_wave = 0
	last_run_shards = 0
	last_run_victory = false
	clears = 0
	stage_cleared = 0
	stage = 1
	stage_best = {}
	last_run_stage = 1
	last_unlocks = []


static func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "best_wave", best_wave)
	cfg.set_value("meta", "clears", clears)
	cfg.set_value("meta", "levels", levels)
	cfg.set_value("meta", "unlocked", Array(unlocked))
	cfg.set_value("meta", "loadout", Array(loadout))
	cfg.set_value("meta", "core", core_type)
	cfg.set_value("meta", "cores", Array(unlocked_cores))
	cfg.set_value("meta", "stage_cleared", stage_cleared)
	cfg.set_value("meta", "stage", stage)
	cfg.set_value("meta", "stage_best", stage_best)
	cfg.save(save_path)


## 게임 실행 후 처음 한 번만 파일에서 읽는다 (씬을 다시 불러와도 메모리 값 유지).
static var loaded := false


static func ensure_loaded() -> void:
	if not loaded:
		load_data()


static func load_data() -> void:
	reset()
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	shards = cfg.get_value("meta", "shards", 0)
	best_wave = cfg.get_value("meta", "best_wave", 0)
	clears = cfg.get_value("meta", "clears", 0)
	levels = cfg.get_value("meta", "levels", {})
	# 스테이지가 생기기 전 저장 파일: OVERLORD를 잡은 적이 있으면 1스테이지를 깬 것으로
	stage_cleared = clampi(cfg.get_value("meta", "stage_cleared", 1 if clears > 0 else 0),
			0, StageDefs.count())
	stage_best = cfg.get_value("meta", "stage_best", {1: best_wave} if best_wave > 0 else {})
	stage = int(cfg.get_value("meta", "stage", mini(stage_cleared + 1, StageDefs.count())))
	if not is_stage_unlocked(stage):
		stage = 1
	var refunded := false
	for kind in cfg.get_value("meta", "unlocked", []):
		var k := String(kind)
		if REMOVED_TILES.has(k):
			shards += REMOVED_TILES[k]
			refunded = true
		elif not unlocked.has(k):
			unlocked.append(k)
	# 예전 저장 파일에는 출정 타일이 없다 -> 기본값
	if cfg.has_section_key("meta", "loadout"):
		loadout.clear()
		for kind in cfg.get_value("meta", "loadout", []):
			if TileDefs.DEFS.has(String(kind)) and is_tile_unlocked(String(kind)):
				loadout.append(String(kind))
	if loadout.is_empty():
		loadout = default_loadout()
	for id in cfg.get_value("meta", "cores", []):
		if CoreDefs.DEFS.has(String(id)):
			unlocked_cores.append(String(id))
	var saved_core := String(cfg.get_value("meta", "core", "core"))
	core_type = saved_core if CoreDefs.DEFS.has(saved_core) and is_core_unlocked(saved_core) else "core"
	if refunded:
		save_data()
