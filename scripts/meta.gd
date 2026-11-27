class_name Meta
extends RefCounted
## 판과 판 사이에 남는 성장 (메타 진행). 게임이 끝나면 버틴 웨이브만큼 SHARD를 받고,
## 시작 화면(Shop)에서 SHARD로 기본 능력치를 영구 강화하거나 새 타일을 구매한다.
## 저장 위치: user://meta.cfg (Windows: %APPDATA%/Godot/app_userdata/<프로젝트 이름>/)

## 영구 강화. 비용은 cost_base + cost_step × 현재 레벨.
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
]

## 처음부터 쓸 수 있는 타일과 SHARD로 사야 하는 타일 (가격).
const STARTER_TILES: Array[String] = ["laser", "frost", "bank"]
const TILE_PRICES := {"spark": 12, "archer": 15, "orbit": 20, "drone": 25}
## 한 판에 들고 갈 수 있는 타일 종류 수 (출정 타일). 카드에는 이 타일들만 나온다.
const MAX_LOADOUT := 6

## 효과 수치 (레벨당)
const CORE_HP_PER_LV := 25.0
const DAMAGE_PER_LV := 0.08
const RATE_PER_LV := 0.05
const TILE_HP_PER_LV := 0.10
const MONEY_PER_LV := 10

static var save_path := "user://meta.cfg"
static var shards := 0
static var best_wave := 0
static var levels := {}
static var unlocked: Array[String] = []
## 출정 타일 (최대 MAX_LOADOUT개)
static var loadout: Array[String] = ["laser", "frost", "booster", "bank"]
## 마지막 판 결과 (시작 화면 안내용). wave가 0이면 아직 끝난 판이 없음.
static var last_run_wave := 0
static var last_run_shards := 0


## 버틴 웨이브(다 처리한 웨이브 수)만큼 SHARD. 보스 웨이브(10, 20, ...)는 +5.
static func shards_for_run(reached_wave: int) -> int:
	var cleared := maxi(reached_wave - 1, 0)
	return cleared + 5 * (cleared / EnemyDefs.BOSS_EVERY)


## 판이 끝났을 때 한 번 호출. 받은 SHARD를 더하고 저장한다.
static func finish_run(reached_wave: int) -> int:
	var earned := shards_for_run(reached_wave)
	shards += earned
	best_wave = maxi(best_wave, reached_wave)
	last_run_wave = reached_wave
	last_run_shards = earned
	save_data()
	return earned


static func level(id: String) -> int:
	return levels.get(id, 0)


static func get_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## 다음 레벨 비용. 이미 최대면 -1.
static func upgrade_cost(id: String) -> int:
	var u := get_upgrade(id)
	var lv := level(id)
	if lv >= u["max"]:
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
	if loadout.size() < MAX_LOADOUT:
		loadout.append(kind)
	save_data()
	return true


## 출정 타일에 들어 있는지 (풀린 타일만).
static func in_loadout(kind: String) -> bool:
	return loadout.has(kind) and is_tile_unlocked(kind)


static func loadout_full() -> bool:
	return loadout.size() >= MAX_LOADOUT


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


## 기본 출정 타일: 풀린 타일을 TileDefs.PLACEABLE 순서로 MAX_LOADOUT개까지.
static func default_loadout() -> Array[String]:
	var result: Array[String] = []
	for kind in TileDefs.PLACEABLE:
		if is_tile_unlocked(kind) and result.size() < MAX_LOADOUT:
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


static func reset() -> void:
	shards = 0
	best_wave = 0
	levels = {}
	unlocked = []
	loadout = default_loadout()
	last_run_wave = 0
	last_run_shards = 0


static func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "best_wave", best_wave)
	cfg.set_value("meta", "levels", levels)
	cfg.set_value("meta", "unlocked", Array(unlocked))
	cfg.set_value("meta", "loadout", Array(loadout))
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
	levels = cfg.get_value("meta", "levels", {})
	for kind in cfg.get_value("meta", "unlocked", []):
		unlocked.append(String(kind))
	# 예전 저장 파일에는 출정 타일이 없다 -> 기본값
	if cfg.has_section_key("meta", "loadout"):
		loadout.clear()
		for kind in cfg.get_value("meta", "loadout", []):
			if TileDefs.DEFS.has(String(kind)) and is_tile_unlocked(String(kind)):
				loadout.append(String(kind))
	if loadout.is_empty():
		loadout = default_loadout()
