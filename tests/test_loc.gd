extends SceneTree
## 실행: godot --headless --path . -s res://tests/test_loc.gd
## 번역: 표에 없는 Loc.t 글자, 형식(%d 등) 개수가 다른 번역, 한글 폰트, 언어 저장/전환, 시작 화면 버튼.

var _failures := 0
var _frame := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Loc.save_path = "user://test_language.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Loc.save_path))
	Loc.lang = ""
	Meta.save_path = "user://test_loc_meta.cfg"
	Meta.reset()
	Meta.loaded = true
	Game.hub_enabled = true
	_run_static()
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_run_scene()
	elif _frame == 4:
		# 언어 버튼을 누르면 씬을 다시 불러온다: 새 시작 화면은 영어
		var shop := (current_scene as Game).shop
		_check(Loc.lang == "en", "language switched to English")
		_check(_find_button(shop).text == "한국어", "button offers Korean after switching")
		Loc.set_lang("ko")
		if _failures == 0:
			print("ALL TESTS PASSED")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Loc.save_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
		quit(1 if _failures > 0 else 0)
	return false


func _run_static() -> void:
	# 기본은 한국어, 표에 없는 글은 그대로
	_check(Loc.t("PAUSE") == "일시정지", "default language is Korean")
	_check(Loc.t("LASER") == "LASER", "unknown text passes through")
	Loc.set_lang("en")
	_check(Loc.t("PAUSE") == "PAUSE", "English shows the source text")
	Loc.lang = ""
	_check(Loc.t("PAUSE") == "PAUSE", "language is saved and loaded")
	Loc.set_lang("xx")
	_check(Loc.lang == "en", "unknown language ignored")
	Loc.set_lang("ko")

	# 번역마다 형식 지정자(%d, %s, %.1f, %%, {v})가 원문과 같은 순서로 있어야 한다
	var spec := RegEx.create_from_string("%(?:%|[-+0-9.]*[dsfx])|\\{v\\}")
	for key in Loc.KO:
		var a := spec.search_all(key).map(func(m: RegExMatch) -> String: return m.get_string())
		var b := spec.search_all(Loc.KO[key]).map(func(m: RegExMatch) -> String: return m.get_string())
		_check(a == b, "format specifiers match: %s" % key)

	# 코드의 Loc.t("...") 글자는 모두 표에 있어야 한다
	var call := RegEx.create_from_string("Loc\\.t\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	var used := 0
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + file)
		for m in call.search_all(src):
			used += 1
			var text := m.get_string(1).c_unescape()
			_check(Loc.KO.has(text), "missing Korean for \"%s\" (%s)" % [text, file])
	_check(used > 100, "found Loc.t calls (%d)" % used)

	# 정의 파일의 설명도 모두 번역돼 있어야 한다
	for defs in [TileDefs.DEFS, GearDefs.DEFS, CoreDefs.DEFS]:
		for id in defs:
			_check(Loc.KO.has(defs[id]["desc"]), "missing Korean desc for %s" % id)
	for u in Meta.UPGRADES:
		_check(Loc.KO.has(u["desc"]), "missing Korean desc for %s" % u["id"])
	for b in Game.BOOSTS:
		_check(Loc.KO.has(b["desc"]), "missing Korean desc for %s" % b["id"])

	# 한글 폰트: Hud 폰트와 기본 테마 폰트 모두 한글 글자를 그릴 수 있어야 한다
	var f := Hud.font_weight(800)
	_check(f.fallbacks.size() == 1 and f.fallbacks[0].has_char("웨".unicode_at(0)),
			"HUD font has a Korean fallback")
	var base: Font = Loc.BASE_FONT
	_check(base.fallbacks.size() == 1 and base.has_char("웨".unicode_at(0)),
			"theme font gets a Korean fallback")
	_check(Loc.korean_font(900).variation_embolden > Loc.korean_font(500).variation_embolden,
			"bold Korean is thicker")


func _run_scene() -> void:
	var game := current_scene as Game
	_check(game.shop.is_open(), "start screen is open")
	var button := _find_button(game.shop)
	_check(button != null and button.text == "ENGLISH", "language button offers English")
	_check(game.hud._pause_button.text == "일시정지", "HUD is in Korean")
	if button != null:
		button.pressed.emit()


func _find_button(shop: Shop) -> Button:
	return shop.find_child("LanguageButton", true, false) as Button
