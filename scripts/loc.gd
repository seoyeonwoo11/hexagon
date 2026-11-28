class_name Loc
extends RefCounted
## 화면 글자 번역 (한국어 / 영어). 기본은 한국어.
##
## 쓰는 법: 화면에 보이는 영어 원문을 그대로 키로 Loc.t("PAUSE").
## 숫자가 들어가는 글은 형식 문자열째로 감싼다: Loc.t("WAVE %d") % wave.
## 표(KO)에 없는 글은 영어 그대로 나온다. 새 글자를 추가하면 KO에도 한 줄 넣는다.
## 타일, 장비, 적, 코어, 스킬, 카드 이름(LASER, SCOPE, OVERLORD ...)은 고유 이름이라 번역하지 않는다.
##
## 한글은 Orbitron에 없어서 Orbit(assets/fonts/Orbit-Regular.ttf, OFL)을 대체 폰트로 붙인다.
## Hud.font_weight로 만든 폰트는 같은 굵기의 한글 대체 폰트를 갖는다.
## 언어 설정은 user://language.cfg에 저장 (meta.cfg, settings.cfg와 따로).

const LANGS: Array[String] = ["ko", "en"]
const DEFAULT_LANG := "ko"
const KO_FONT := preload("res://assets/fonts/Orbit-Regular.ttf")
const BASE_FONT := preload("res://assets/fonts/Orbitron.ttf")

static var save_path := "user://language.cfg"
static var lang := ""
static var _ko_fonts := {}


static func t(text: String) -> String:
	ensure_loaded()
	if lang == "ko":
		return KO.get(text, text)
	return text


static func ensure_loaded() -> void:
	if lang != "":
		return
	lang = DEFAULT_LANG
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		var saved: String = cfg.get_value("language", "lang", DEFAULT_LANG)
		if LANGS.has(saved):
			lang = saved
	setup_fonts()


static func set_lang(value: String) -> void:
	if not LANGS.has(value):
		return
	lang = value
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("language", "lang", value)
	cfg.save(save_path)


## 언어 전환 버튼에 쓸 글자: 바꿀 언어를 그 언어로 쓴다.
static func other_lang_name() -> String:
	ensure_loaded()
	return "ENGLISH" if lang == "ko" else "한국어"


static func toggle() -> void:
	ensure_loaded()
	set_lang("en" if lang == "ko" else "ko")


## 굵기별 한글 대체 폰트. Orbit은 굵기가 하나뿐이라 굵은 글자는 embolden으로 두껍게 한다.
static func korean_font(weight: int) -> Font:
	var bold := clampf((weight - 500) / 400.0, 0.0, 1.0) * 0.7
	var key := snappedf(bold, 0.05)
	if not _ko_fonts.has(key):
		var f := FontVariation.new()
		f.base_font = KO_FONT
		f.variation_embolden = key
		_ko_fonts[key] = f
	return _ko_fonts[key]


## 기본 테마 폰트(Orbitron)에도 한글 대체 폰트를 붙인다 (툴팁 등 Hud.font_weight를 안 거치는 글자).
static func setup_fonts() -> void:
	var base: Font = BASE_FONT
	if base.fallbacks.is_empty():
		base.fallbacks = [korean_font(500)]


const KO := {
	# ---------------------------------------------------------------- HUD
	"PAUSE": "일시정지",
	"PLAY": "계속",
	"FULL": "전체화면",
	"WAVE %d  ENDLESS": "웨이브 %d  무한",
	"WAVE %d / %d": "웨이브 %d / %d",
	"%s  -  ENRAGED": "%s  -  분노",
	"OVERLORD DEFEATED": "OVERLORD 처치",
	"VICTORY": "승리",
	"CONTINUE  ENDLESS": "무한 모드로 계속",
	"Keep this run going. Every wave after %d adds shards.":
			"이 판을 이어서 합니다. %d웨이브 뒤로 웨이브마다 샤드를 더 받습니다.",
	"END RUN": "판 끝내기",
	"All %d waves cleared   -   +%d shards\nClears  %d":
			"%d웨이브 모두 클리어   -   샤드 +%d\n클리어  %d번",
	"TAP TO RESUME": "탭하면 계속",
	"SPACE OR CLICK TO RESUME": "SPACE 또는 클릭으로 계속",
	"PAUSED": "일시정지",
	"CHOOSE ONE": "하나를 고르세요",
	"CLOSE": "닫기",
	"SETTINGS": "설정",
	"NEW GAME": "게임 시작",
	"WINDOWED": "창 모드",
	"FULLSCREEN": "전체 화면",
	"UPGRADE": "강화",
	"UPGRADE  $%d": "강화  $%d",
	"NEXT LEVEL": "다음 레벨",
	"MOVE": "옮기기",
	"Move or swap one tile per wave. Right-click cancels.":
			"웨이브마다 타일 1개를 옮기거나 자리를 바꿉니다. 오른쪽 클릭으로 취소.",
	"CANCEL MOVE  [M]": "옮기기 취소  [M]",
	"MOVE TILE  %d  [M]": "타일 옮기기  %d  [M]",
	"%s  ON": "%s  사용 중",
	"%s  %ds": "%s  %d초",
	# 타일 정보 창
	"DMG %.1f    RANGE %d": "피해 %.1f    사거리 %d",
	"ORBS %d    HIT EVERY %.2f S": "구체 %d개    %.2f초마다 타격",
	"RATE %.1f / S": "공격 초당 %.1f번",
	"ADJACENT TILES +%d%% SPEED": "맞닿은 타일 공격 속도 +%d%%",
	"BOOSTED +%d%% SPEED": "BOOSTER 효과 공격 속도 +%d%%",
	"INCOME $%d / WAVE": "수입 웨이브마다 $%d",
	"INTEREST %d%% OF YOUR $ (MAX $%d)": "이자 가진 돈의 %d%% (최대 $%d)",
	"BEAMS %d": "광선 %d개",
	"LOCK-ON BEAM": "고정 광선",
	"FOCUS +%d%% / HIT (MAX x%.1f)": "집중 맞힐 때마다 +%d%% (최대 x%.1f)",
	"BOUNCES %d": "튕김 %d번",
	"DRONES %d": "드론 %d대",
	"PACK %d ARCHERS (+%d%% DMG)": "무리 ARCHER %d개 (피해 +%d%%)",
	"SLOW %d%%": "감속 %d%%",
	"FLAMES %d": "불길 %d갈래",
	"BURN %.1f / S FOR %.1f S": "화상 초당 %.1f, %.1f초 동안",
	"FIRE SPREADS ON TOUCH (%d%%)": "닿으면 불이 번짐 (%d%%)",
	"HP %d / %d": "체력 %d / %d",
	"GEAR  %s": "장비  %s",
	"GEAR  EMPTY SLOT": "장비  빈 칸",
	# 다음 레벨 미리보기
	"DMG %.1f > %.1f": "피해 %.1f > %.1f",
	"RANGE +%d    SPEED +%d%%": "사거리 +%d    공격 속도 +%d%%",
	"INCOME $%d > $%d": "수입 $%d > $%d",
	"INTEREST +%d%%": "이자 +%d%%",
	"+1 BOUNCE": "튕김 +1",
	"HASTE +%d%% > +%d%%": "가속 +%d%% > +%d%%",
	"+1 ORB": "구체 +1",
	"+1 DRONE": "드론 +1",
	"PACK +%d%% > +%d%% PER ARCHER": "무리 ARCHER 1개당 +%d%% > +%d%%",
	"SLOW %d%% > %d%%": "감속 %d%% > %d%%",
	"+1 BEAM": "광선 +1",
	"FOCUS +%d%% > +%d%% / HIT": "집중 맞힐 때마다 +%d%% > +%d%%",
	"BURN %.1f S > %.1f S": "화상 시간 %.1f초 > %.1f초",
	"+1 GEAR SLOT": "장비 칸 +1",
	"HP +%d": "체력 +%d",
	# ---------------------------------------------------------------- 게임 진행
	"READY": "준비",
	"GET READY": "다음 웨이브 준비",
	"WAVE %d": "웨이브 %d",
	"WAVE %d  -  BOSS": "웨이브 %d  -  BOSS",
	"FINAL WAVE  -  OVERLORD": "마지막 웨이브  -  OVERLORD",
	"PLACE %s": "%s 놓기 - 빛나는 칸을 클릭",
	"EQUIP %s - CLICK A TILE": "%s 장착 - 타일을 클릭",
	"NEW TILE": "새 타일",
	"BOOST": "버프",
	"GEAR": "장비",
	"All tiles deal +{v}% damage.": "모든 타일 피해 +{v}%.",
	"All tiles attack {v}% faster.": "모든 타일 공격 속도 +{v}%.",
	"Core +{v} max HP, other tiles +15% max HP. Repairs all tiles.":
			"코어 최대 체력 +{v}, 다른 타일 최대 체력 +15%. 모든 타일을 수리합니다.",
	"From now on, all tiles gain +{v}% damage after every wave.":
			"이제부터 웨이브가 끝날 때마다 모든 타일 피해 +{v}%.",
	# ---------------------------------------------------------------- 타일 설명
	"Your base. Lose it and the run is over.": "기지입니다. 부서지면 판이 끝납니다.",
	"Locks a beam onto one enemy until it dies or leaves range. Gets stronger the longer it holds.":
			"적 하나에 광선을 꽂아 죽거나 사거리를 벗어날 때까지 쏩니다. 오래 꽂을수록 강해집니다.",
	"Fires a bolt that bounces between nearby enemies.": "가까운 적 사이를 튕기는 번개를 쏩니다.",
	"Slows every enemy in range.": "범위 안의 모든 적을 느리게 합니다.",
	"Glowing orbs circle the tile and hit enemies they touch.":
			"빛나는 구체가 타일 둘레를 돌며 닿은 적을 때립니다.",
	"Launches drones that roam nearby and ram enemies they find.":
			"드론을 내보내 주변을 돌다가 찾은 적을 들이받습니다.",
	"Long-range arrows. +40% damage for every ARCHER touching it.":
			"멀리 화살을 쏩니다. 맞닿은 ARCHER 1개마다 피해 +40%.",
	"Adjacent tiles attack 25% faster.": "맞닿은 타일의 공격 속도 +25%.",
	"Flamethrower. Sprays a cone of fire at the nearest enemy and sets it ablaze. Fire spreads between enemies that touch.":
			"화염방사기. 가장 가까운 적에게 부채꼴 불길을 뿜어 불태웁니다. 불은 맞닿은 적에게 번집니다.",
	"Earns money after every wave, plus interest on your savings.":
			"웨이브가 끝날 때마다 돈을 벌고, 가진 돈에 이자도 붙습니다.",
	# ---------------------------------------------------------------- 장비 설명
	"+40% attack range.": "사거리 +40%.",
	"Hits one extra target each attack (ORBIT: +1 orb, HIVE: +1 drone, BURN: +1 flame).":
			"공격마다 대상 1명 추가 (ORBIT은 구체 +1, HIVE는 드론 +1, BURN은 불길 +1).",
	"Hits set enemies on fire for 3 seconds.": "맞은 적에게 3초 동안 불을 붙입니다.",
	"25% chance to deal 3.5x damage.": "25% 확률로 3.5배 피해.",
	"Every hit explodes, dealing 45% of it to enemies nearby.":
			"맞힐 때마다 폭발해 주변 적에게 그 피해의 45%를 줍니다.",
	# ---------------------------------------------------------------- 코어 설명
	"OVERDRIVE: all tiles deal +60% damage for 6 seconds.": "OVERDRIVE: 6초 동안 모든 타일 피해 +60%.",
	"FREEZE: every enemy stops moving and attacking for 3.5 seconds.":
			"FREEZE: 3.5초 동안 모든 적이 멈추고 공격하지 못합니다.",
	"REPAIR: every tile recovers 50% of its max HP.": "REPAIR: 모든 타일이 최대 체력의 50%를 회복합니다.",
	"NOVA: a shockwave takes 30% of max HP from nearby enemies (bosses 10%).":
			"NOVA: 충격파가 주변 적의 최대 체력 30%를 깎습니다 (보스는 10%).",
	# ---------------------------------------------------------------- 영구 강화
	"Core +25 max HP": "코어 최대 체력 +25",
	"All tiles +8% damage": "모든 타일 피해 +8%",
	"All tiles attack 5% faster": "모든 타일 공격 속도 +5%",
	"All tiles +10% max HP": "모든 타일 최대 체력 +10%",
	"Start each run with +$10": "판을 시작할 때 돈 +$10",
	# ---------------------------------------------------------------- 시작 화면
	"Cleared! Endless until wave %d\n+%d shards": "클리어! 무한 모드 %d웨이브까지\n샤드 +%d",
	"OVERLORD defeated!\n+%d shards": "OVERLORD 처치!\n샤드 +%d",
	"Run ended on wave %d\n+%d shards": "%d웨이브에서 끝났습니다\n샤드 +%d",
	"Beat the OVERLORD on wave %d.\nClear waves to earn shards.":
			"%d웨이브의 OVERLORD를 잡으세요.\n웨이브를 깨면 샤드를 받습니다.",
	"Best wave  %d": "최고 웨이브  %d",
	"    Clears  %d": "    클리어  %d번",
	"Test only: +%d shards": "테스트용: 샤드 +%d",
	"shards to spend": "쓸 수 있는 샤드",
	"Core and skill": "코어와 스킬",
	"Start a run": "판 시작",
	"Click the core or press Enter.": "가운데 코어를 클릭하거나 Enter를 누르세요.",
	"Selected. Press Q in a run to use the skill (%ds cooldown).":
			"선택됨. 판에서 Q를 누르면 스킬을 씁니다 (재사용 %d초).",
	"Click to use this core.": "클릭하면 이 코어를 씁니다.",
	"Click to unlock for %d shards.": "클릭하면 샤드 %d개로 잠금 해제.",
	"Unlock for %d shards (%d more needed).": "샤드 %d개로 잠금 해제 (%d개 더 필요).",
	"Click to unlock for %d shards": "클릭하면 샤드 %d개로 잠금 해제",
	"Unlock for %d shards (%d more needed)": "샤드 %d개로 잠금 해제 (%d개 더 필요)",
	"Pick your tiles": "가져갈 타일 고르기",
	"Pick up to %d tiles to bring. Only these show up as cards.\nClick a tile to add or remove it.":
			"판에 가져갈 타일을 %d개까지 고르세요. 고른 타일만 카드로 나옵니다.\n타일을 클릭하면 넣거나 뺍니다.",
	"In your loadout. Click to remove.": "가져가는 타일. 클릭하면 뺍니다.",
	"In your loadout (you need at least one).": "가져가는 타일 (최소 1개는 있어야 합니다).",
	"Loadout full (%d/%d). Remove a tile first.": "가득 찼습니다 (%d/%d). 먼저 타일을 빼세요.",
	"Click to add to your loadout (%d/%d).": "클릭하면 가져갑니다 (%d/%d).",
	"Permanent upgrades": "영구 강화",
	"Maxed": "최대",
	"Buy level %d for %d shards": "레벨 %d 구매 (샤드 %d개)",
	"LOADOUT  %d / %d": "가져갈 타일  %d / %d",
	"START": "시작",
	"OFF": "빠짐",
	# ---------------------------------------------------------------- 결과창
	"RETRY  (R)": "다시 하기  (R)",
	"Start a new run right away with the same setup.": "같은 설정으로 바로 새 판을 시작합니다.",
	"CONTINUE  (ENTER)": "계속  (ENTER)",
	"Go to the start screen to spend shards.": "시작 화면으로 가서 샤드를 씁니다.",
	"ENDLESS RUN OVER  -  OVERLORD DEFEATED": "무한 모드 끝  -  OVERLORD 처치",
	"CORE DESTROYED": "코어 파괴",
	"GAME OVER": "게임 오버",
	"NEW BEST": "최고 기록",
	"BEST  %d": "최고  %d",
	"WAVE": "웨이브",
	"KILLS": "처치",
	"TIME": "시간",
	"GOLD EARNED": "번 돈",
	"SHARDS": "샤드",
	"DAMAGE BY TILE": "타일별 피해",
	"TOTAL  ": "합계  ",
	"No damage dealt": "준 피해 없음",
	"+%d more": "+%d개 더",
	"ENEMIES KILLED": "처치한 적",
	"None": "없음",
	# ---------------------------------------------------------------- 소리 설정 (sound_panel.gd, PR #17)
	"SOUND": "소리",
	"MUSIC": "배경음",
	"EFFECTS": "효과음",
	"MUTE": "음소거",
	"UNMUTE": "소리 켜기",
	"MUTED": "음소거됨",
	"N  -  MUTE / UNMUTE": "N  -  음소거 / 켜기",
	# ---------------------------------------------------------------- 일시정지 피해 표
	"DAMAGE BY WAVE": "웨이브별 피해",
	"TOTAL": "합계",
	"No damage yet": "아직 피해 없음",
	# 스테이지
	"STAGE": "스테이지",
	"STAGE %d": "스테이지 %d",
	"%s  -  READY": "%s  -  준비",
	"%s CLEARED  -  OVERLORD DEFEATED": "%s 클리어  -  OVERLORD 처치",
	"%s unlocked": "%s 열림",
	"Upgrade limit +%d": "영구 강화 상한 +%d",
	"New upgrade: %s": "새 영구 강화: %s",
	"New core: %s": "새 코어: %s",
	"Loadout +1 slot": "가져갈 타일 칸 +1",
	"%s cleared! Endless until wave %d\n+%d shards": "%s 클리어! 무한 모드 %d웨이브까지\n샤드 +%d",
	"%s cleared!\n+%d shards": "%s 클리어!\n샤드 +%d",
	"%s ended on wave %d\n+%d shards": "%s, %d웨이브에서 끝났습니다\n샤드 +%d",
	"Beat the OVERLORD on wave %d\nto open the next stage.":
			"%d웨이브의 OVERLORD를 잡으면\n다음 스테이지가 열립니다.",
	"%s best wave  %d": "%s 최고 웨이브  %d",
	"Clear %s to unlock (then %d shards).": "%s를 깨면 열립니다 (그 뒤 샤드 %d개).",
	"Enemies x%s HP, x%s damage. Shards x%s.": "적 체력 x%s, 피해 x%s. 샤드 x%s.",
	"Base difficulty.": "기본 난이도.",
	"First clear: %s.": "처음 깨면: %s.",
	"Cleared.": "클리어함.",
	"Clear %s to unlock.": "%s를 깨면 열립니다.",
	"Selected.": "선택됨.",
	"Click to select.": "클릭하면 고릅니다.",
	"CLEAR %d": "%d 클리어",
	"LOCKED": "잠김",
	"CLEAR": "클리어",
	"BEST %d": "최고 %d",
	"NEW": "처음",
	"Enemies drop +8% money": "적 처치 돈 +8%",
	"Core skill cooldown -7%": "코어 스킬 쿨다운 -7%",
	"WARP: throws every enemy 380 away from the core (bosses 150).":
			"WARP: 모든 적을 코어 반대쪽으로 380 날려 보냅니다 (보스 150).",
	# 상점 창
	"SHOP": "상점",
	"shards": "샤드",
	"BACK  (ESC)": "돌아가기  (ESC)",
	"UPGRADES": "영구 강화",
	"TILES": "타일",
	"CORES": "코어",
	"Permanent upgrades apply to every run. Clearing a stage for the first time raises every limit by %d.": "영구 강화는 모든 판에 적용됩니다. 스테이지를 처음 깰 때마다 상한이 %d씩 오릅니다.",
	"Bought tiles can be added to your loadout on the start screen.": "산 타일은 시작 화면에서 가져갈 타일에 넣을 수 있습니다.",
	"Pick the core for your run on the start screen. Each core has its own skill (Q).": "판에 쓸 코어는 시작 화면에서 고릅니다. 코어마다 스킬(Q)이 다릅니다.",
	"Clear a new stage to raise the limit.": "새 스테이지를 깨면 상한이 오릅니다.",
	"UPGRADE   %d shards": "강화   샤드 %d",
	"OWNED": "보유",
	"BUY   %d shards": "구매   샤드 %d",
	"Upgrades  %d / %d": "영구 강화  %d / %d",
	"Upgrades, tiles and cores": "영구 강화, 타일, 코어",
	"Buy it in the shop for %d shards. Click to open the shop.": "상점에서 샤드 %d개로 살 수 있습니다. 클릭하면 상점이 열립니다.",
	"COOLDOWN %ds": "쿨다운 %d초",
	# 시작 화면, 출전 준비 창
	"PREPARE": "출전 준비",
	"TILES TO BRING": "가져갈 타일",
	"CORE": "코어",
	"Pick up to %d tiles to bring. Only these show up as cards.": "판에 가져갈 타일을 %d개까지 고르세요. 고른 타일만 카드로 나옵니다.",
	"Each core has its own skill. Press Q in a run to use it.": "코어마다 스킬이 다릅니다. 판에서 Q로 씁니다.",
	"IN": "넣음",
	"Buy in the shop  (%d)": "상점에서 사기  (%d)",
	"REMOVE": "빼기",
	"BRING": "가져가기",
	"SELECTED": "선택됨",
	"SELECT": "고르기",
	"%d shards": "샤드 %d",
	"Last run: %s cleared, endless until wave %d, +%d shards": "지난 판: %s 클리어, 무한 모드 %d웨이브까지, 샤드 +%d",
	"Last run: %s cleared, +%d shards": "지난 판: %s 클리어, 샤드 +%d",
	"Last run: %s, wave %d, +%d shards": "지난 판: %s, %d웨이브, 샤드 +%d",
	"Beat the OVERLORD on wave %d to open the next stage.": "%d웨이브의 OVERLORD를 잡으면 다음 스테이지가 열립니다.",
	"LOADOUT FULL": "가득 참",
}
