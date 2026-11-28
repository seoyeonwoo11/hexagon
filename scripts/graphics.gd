class_name Graphics
extends RefCounted
## 그래픽 설정. 지금은 화면 전체 빛 번짐(WorldEnvironment 글로우) 켜기/끄기 하나.
## 글로우는 그리기 시간의 약 2/3를 차지해서 (태블릿 해상도, 2026-11 측정) 기본은 꺼 둔다.
## 선 자체의 네온 번짐(NeonDraw 겹선)은 글로우와 상관없이 남는다.
## 설정은 소리 설정과 같은 파일(Sfx.settings_path)의 [graphics] 칸에 저장.

static var glow := false
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(Sfx.settings_path) != OK:
		return
	glow = bool(cfg.get_value("graphics", "glow", glow))


static func set_glow(on: bool) -> void:
	load_settings()
	glow = on
	var cfg := ConfigFile.new()
	cfg.load(Sfx.settings_path)
	cfg.set_value("graphics", "glow", glow)
	cfg.save(Sfx.settings_path)
	apply()


## 지금 씬의 WorldEnvironment에 설정을 적용한다.
static func apply() -> void:
	load_settings()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var we := tree.current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.glow_enabled = glow
