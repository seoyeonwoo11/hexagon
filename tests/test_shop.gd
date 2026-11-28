extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_shop.gd
## 상점 창: 시작 화면의 SHOP 버튼으로 열고 닫기, 탭, 카드 버튼으로 강화/타일/코어 구매,
## 시작 화면의 잠긴 타일/코어를 누르면 그 탭이 열림, 창이 떠 있는 동안 Enter로 판이 시작되지 않음.

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
	var button := shop.find_child("ShopButton", true, false) as Shop.HubButton
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

	# 가져갈 타일 창: 산 타일은 넣고 빼고, 안 산 타일은 상점 타일 탭으로
	shop._loadout_button.pressed.emit()
	_check(shop.is_window_open() and win.tab == "loadout" and win.group() == "prep",
			"tiles-to-bring button opens the prep window")
	_check(win._grid.get_child_count() == TileDefs.PLACEABLE.size(), "one card per tile")
	var spark_i := TileDefs.PLACEABLE.find("spark")
	var had := Meta.in_loadout("spark")
	_card_button(win, spark_i).pressed.emit()
	_check(Meta.in_loadout("spark") != had, "loadout card toggles the tile")
	var before := Meta.shards
	_card_button(win, TileDefs.PLACEABLE.find("drone")).pressed.emit()
	_check(win.tab == "tiles" and win.group() == "shop" and not Meta.is_tile_unlocked("drone")
			and Meta.shards == before, "locked tile sends you to the shop, without buying")
	_check(not (win._tab_buttons["loadout"] as Button).visible
			and (win._tab_buttons["tiles"] as Button).visible, "only the shop tabs in the shop")
	win.close()

	# 코어 창: 산 코어는 고르기, 안 산 코어는 상점 코어 탭으로
	shop._core_button.pressed.emit()
	_check(win.tab == "core", "core button opens the core tab")
	_card_button(win, CoreDefs.ORDER.find("core")).pressed.emit()
	_check(Meta.core_type == "core", "owned core is picked")
	_card_button(win, CoreDefs.ORDER.find("nova")).pressed.emit()
	_check(win.tab == "cores" and not Meta.is_core_unlocked("nova"), "locked core sends you to the shop")
	win.close()
	_check(shop._root.visible and not shop.is_window_open(), "start screen back after closing")

	# 판을 시작하면 창도 닫힌다
	shop.open_window()
	_game.start_run()
	_check(not shop.is_open() and not shop.is_window_open(), "starting a run closes everything")
