extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_shop.gd
## 상점 창: 시작 화면의 SHOP 버튼으로 열고 닫기, 탭, 카드 버튼으로 강화/타일/코어 구매,
## 시작 화면의 잠긴 타일/코어를 누르면 그 탭이 열림, 창이 떠 있는 동안 Enter로 판이 시작되지 않음.
## 메뉴 버튼 (게임 시작/상점/설정), 벌집 한가운데 코어로 코어 고르기 창, SHARD 아이콘.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = true
	Meta.save_path = "user://test_shop.cfg"
	Meta.reset()
	Meta.loaded = true
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_run()
		if _failures == 0:
			print("ALL TESTS PASSED")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
		quit(1 if _failures > 0 else 0)
	return false


## 창의 카드 i번째의 (맨 아래) 버튼
func _card_button(win: ShopWindow, i: int) -> Button:
	var col := win._grid.get_child(i).get_child(0) as VBoxContainer
	return col.get_child(col.get_child_count() - 1) as Button


func _run() -> void:
	var shop := _game.shop
	var win := shop._window
	_check(shop.is_open() and not shop.is_window_open(), "start screen without the shop window")
	var button := shop.find_child("ShopButton", true, false) as Button
	_check(button != null, "shop button on the start screen")
	button.pressed.emit()
	_check(shop.is_window_open() and win.tab == "upgrades", "shop button opens the upgrades tab")
	_check(win._grid.get_child_count() == Meta.UPGRADES.size(), "one card per upgrade")

	# 강화 카드: SHARD가 모자라면 버튼이 꺼져 있고, 있으면 사진다
	var first: Button = _card_button(win, 0)
	_check(first.disabled, "upgrade button off without shards")
	Meta.shards = 100
	win.refresh()
	_card_button(win, 0).pressed.emit()
	var id: String = Meta.UPGRADES[0]["id"]
	_check(Meta.level(id) == 1 and Meta.shards == 100 - Meta.UPGRADES[0]["cost_base"],
			"upgrade bought from its card")
	# 잠긴 강화 (BOUNTY)는 버튼이 꺼져 있다
	var bounty := -1
	for i in Meta.UPGRADES.size():
		if Meta.UPGRADES[i]["id"] == "bounty":
			bounty = i
	_check(bounty >= 0 and _card_button(win, bounty).disabled, "locked upgrade cannot be bought")

	# 타일 탭: 산 타일은 출정 타일에 들어간다
	win.show_tab("tiles")
	var kinds: Array = TileDefs.PLACEABLE.filter(func(k: String) -> bool: return Meta.TILE_PRICES.has(k))
	_check(win._grid.get_child_count() == kinds.size(), "one card per tile for sale")
	var spark := kinds.find("spark")
	_card_button(win, spark).pressed.emit()
	_check(Meta.is_tile_unlocked("spark") and Meta.in_loadout("spark"), "tile bought from its card")
	_check(_card_button(win, spark).disabled, "owned tile card is off")

	# 코어 탭: 2스테이지 전에는 WARP CORE를 못 산다
	win.show_tab("cores")
	Meta.shards = 100
	win.refresh()
	var cores: Array = CoreDefs.ORDER.filter(func(c: String) -> bool: return CoreDefs.get_def(c)["price"] > 0)
	_check(win._grid.get_child_count() == cores.size(), "one card per core for sale")
	_check(_card_button(win, cores.find("warp")).disabled, "warp locked by stage")
	_card_button(win, cores.find("cryo")).pressed.emit()
	_check(Meta.is_core_unlocked("cryo") and Meta.core_type == "cryo", "core bought from its card")

	# 창이 떠 있으면 Enter로 판이 시작되지 않고, Esc로 닫힌다
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	shop._unhandled_input(enter)
	_check(not _game.started, "enter does nothing while the shop window is open")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	win._unhandled_input(esc)
	_check(not shop.is_window_open() and shop._root.visible, "escape closes the shop window")

	# 시작 화면에서 안 산 타일/코어를 누르면 그 탭이 열리고, 사지는 않는다
	var before := Meta.shards
	shop._on_tile_clicked("drone")
	_check(shop.is_window_open() and win.tab == "tiles" and not Meta.is_tile_unlocked("drone")
			and Meta.shards == before, "locked tile opens the tiles tab")
	win.close()
	shop._on_core_clicked("nova")
	_check(shop.is_window_open() and win.tab == "cores" and not Meta.is_core_unlocked("nova"),
			"locked core opens the cores tab")
	win.close()
	# 산 타일은 그대로 넣고 빼기, 산 코어는 고르기
	shop._on_tile_clicked("spark")
	_check(not shop.is_window_open() and not Meta.in_loadout("spark"), "owned tile toggles the loadout")
	shop._on_core_clicked("core")
	_check(Meta.core_type == "core" and not shop.is_window_open(), "owned core is picked")

	# 설정 버튼: 언어/소리/전체 화면 버튼이 있고, 떠 있는 동안 Enter로 판이 시작되지 않는다
	var settings := shop.find_child("SettingsButton", true, false) as Button
	_check(settings != null, "settings button on the start screen")
	settings.pressed.emit()
	_check(shop._settings.is_open(), "settings button opens the settings panel")
	for n in ["LanguageButton", "SoundButton", "FullscreenButton"]:
		_check(shop._settings.find_child(n, true, false) is Button, "settings has " + n)
	shop._unhandled_input(enter)
	_check(not _game.started, "enter does nothing while settings is open")
	shop._settings._unhandled_input(esc)
	_check(not shop._settings.is_open(), "escape closes settings")

	# 메뉴 버튼 3개가 한 군데에 모여 있다
	var menu := shop.find_child("Menu", true, false)
	for n in ["StartButton", "ShopButton", "SettingsButton"]:
		var b := shop.find_child(n, true, false)
		_check(b != null and b.get_parent() == menu, n + " in the menu")
	# 시작 화면 아이콘: 글자 대신 SHARD 그림
	_check(shop._root.find_child("ShardIcon", true, false) is TextureRect, "shard icon on the start screen")
	# 벌집 한가운데 코어를 누르면 코어 고르기 창, 거기서 코어를 고른다
	shop._honeycomb.core_pressed.emit()
	_check(shop.is_cores_open() and not _game.started, "center core opens the core panel")
	var picker := shop._cores.find_child("PanelCorePicker", true, false)
	_check(picker != null, "core picker in the core panel")
	picker.core_clicked.emit("cryo")
	_check(Meta.core_type == "cryo" and shop.is_cores_open(), "core picked in the core panel")
	shop._unhandled_input(enter)
	_check(not _game.started, "enter does nothing while the core panel is open")
	picker.core_clicked.emit("nova")
	_check(not shop.is_cores_open() and shop.is_window_open() and win.tab == "cores",
			"locked core in the core panel opens the shop")
	win.close()
	shop.open_cores()
	shop._cores._unhandled_input(esc)
	_check(not shop.is_cores_open() and not _game.started, "escape closes the core panel")
	# 게임 시작 버튼은 바로 판을 시작한다
	(shop.find_child("StartButton", true, false) as Button).pressed.emit()
	_check(_game.started and not shop.is_open() and not shop.is_cores_open(),
			"start button starts the run")

