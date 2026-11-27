extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_sound.gd
## 소리 파일이 다 있는지, 동시 재생 제한, 배경음 전환, 볼륨/음소거 저장, SOUND 버튼과 설정 창.

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = false
	Meta.save_path = "user://test_meta.cfg"
	Meta.reset()
	Meta.loaded = true
	Sfx.settings_path = "user://test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.settings_path))
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_game = current_scene as Game
		_run()
		if _failures == 0:
			print("ALL TESTS PASSED")
		quit(1 if _failures > 0 else 0)
	return false


func _run() -> void:
	var s := Sfx.instance()
	_check(s != null and s.is_inside_tree(), "sound node lives under root")
	_check(s.get_parent() == root, "sound node survives scene reloads (child of root)")

	# 모든 효과음, 배경음 파일
	for sound in Sfx.SOUNDS:
		_check(s._streams.has(sound), "sfx loaded: " + sound)
	for track in Sfx.TRACKS:
		_check(s._tracks.has(track), "music loaded: " + track)
		_check((s._tracks[track] as AudioStreamOggVorbis).loop, "music loops: " + track)

	# 판이 시작되면 전투 배경음
	_check(s.current_track == "battle", "battle music once the run starts")
	Sfx.music("boss")
	_check(s.current_track == "boss", "switch to boss music")
	Sfx.music("")
	_check(s.current_track == "", "music off")
	Sfx.music("battle")

	# 같은 소리는 최소 간격 안에 다시 안 울림
	_check(Sfx.play("wave"), "wave sound plays")
	_check(not Sfx.play("wave"), "same sound inside its gap is skipped")
	_check(not Sfx.play("nope"), "unknown sound is ignored")

	# 동시 재생 수 제한: 간격을 지워 가며 같은 소리를 마구 불러도 max개까지만
	var max_kill: int = Sfx.SOUNDS["kill"][1]
	for i in 20:
		s._last_ms.erase("kill")
		Sfx.play("kill")
	_check(s.active_voices("kill") == max_kill, "kill capped at %d voices (got %d)" \
			% [max_kill, s.active_voices("kill")])
	# 전투 소리는 다 합쳐 COMBAT_VOICES까지
	for sound in ["laser", "spark", "arrow", "orbit", "drone", "core_shot", "frost", "explode", "crit"]:
		for i in 4:
			s._last_ms.erase(sound)
			Sfx.play(sound)
	var combat := 0
	for i in Sfx.VOICES:
		if s._players[i].playing and s._voice_prio[i] == 0:
			combat += 1
	_check(combat <= Sfx.COMBAT_VOICES, "combat voices capped (%d)" % combat)
	_check(s.active_voices() <= Sfx.VOICES, "never more than VOICES players")
	# 중요한 소리는 자리가 없어도 낮은 소리를 끊고 울린다
	_check(Sfx.play("tile_break"), "important sound steals a voice")

	# 볼륨/음소거: 버스에 반영되고 저장된다
	Sfx.set_music_volume(0.25)
	Sfx.set_sfx_volume(0.5)
	Sfx.set_muted(true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "mute mutes master bus")
	_check(not Sfx.play("levelup"), "no sfx while muted")
	var cfg := ConfigFile.new()
	_check(cfg.load(Sfx.settings_path) == OK, "settings saved")
	_check(is_equal_approx(float(cfg.get_value("sound", "music")), 0.25), "music volume saved")
	_check(is_equal_approx(float(cfg.get_value("sound", "sfx")), 0.5), "sfx volume saved")
	_check(cfg.get_value("sound", "muted") == true, "mute saved")
	Sfx.music_volume = 1.0
	Sfx.muted = false
	Sfx._settings_loaded = false
	Sfx.load_settings()
	_check(is_equal_approx(Sfx.music_volume, 0.25) and Sfx.muted, "settings load back")
	Sfx.set_muted(false)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "unmute")
	Sfx.set_sfx_volume(0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.SFX_BUS)), "0% sfx mutes the sfx bus")
	Sfx.set_sfx_volume(0.8)
	Sfx.set_music_volume(0.6)

	# SOUND 버튼: HUD에 있고 음소거면 MUTED
	var button := _find_button(_game.hud, "SOUND")
	_check(button != null, "SOUND button in the HUD")
	Sfx.set_muted(true)
	_check(button != null and button.text == "MUTED", "button shows MUTED")
	Sfx.set_muted(false)
	_check(button != null and button.text == "SOUND", "button back to SOUND")

	# 설정 창: 열면 멈추고, 닫으면 원래대로
	var panel := Sfx.panel()
	paused = false
	Sfx.open_panel()
	_check(panel.is_open() and paused, "panel pauses the game")
	panel.close_panel()
	_check(not panel.is_open() and not paused, "closing restores play")
	paused = true
	Sfx.open_panel()
	panel.close_panel()
	_check(paused, "closing keeps an earlier pause")
	paused = false
	Sfx.open_panel()
	panel._music_slider.value = 40
	_check(is_equal_approx(Sfx.music_volume, 0.4), "music slider sets volume")
	panel._sfx_slider.value = 70
	_check(is_equal_approx(Sfx.sfx_volume, 0.7), "sfx slider sets volume")
	panel.close_panel()

	# 일시정지 중에는 배경음을 줄인다
	var idx := AudioServer.get_bus_index(Sfx.MUSIC_BUS)
	var normal := AudioServer.get_bus_volume_db(idx)
	paused = true
	s._process(0.0)
	_check(AudioServer.get_bus_volume_db(idx) < normal - 3.0, "music ducks while paused")
	paused = false
	s._process(0.0)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(idx), normal), "music back after pause")

	# 게임 쪽 연결: 강화 실패/성공, 게임 오버
	var core := _game.board.core_tile()
	_game.money = 0
	s._last_ms.clear()
	_check(not _game.try_upgrade(core), "upgrade fails without money")
	_check(s.active_voices("deny") == 1, "deny sound on failed upgrade")
	_game.money = 1000
	_check(_game.try_upgrade(core), "upgrade")
	_check(s.active_voices("levelup") == 1, "level up sound")
	core.take_damage(core.hp + 1.0)
	_check(_game.is_over, "game over")
	_check(s.current_track == "" and s.active_voices("gameover") == 1, "game over: music stops, jingle plays")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.settings_path))


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null
