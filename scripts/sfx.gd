class_name Sfx
extends Node
## 효과음과 배경음. 어디서든 Sfx.play("kill"), Sfx.music("battle")처럼 부른다.
##
## 처음 부를 때 루트에 노드 하나를 만들어 붙인다 (씬을 다시 불러와도 남아서 배경음이 끊기지 않음).
## 소리 파일은 tools/gen_sounds.py가 코드로 합성한 것 (assets/sounds/).
##
## 렉 방지:
##   - 효과음 재생기는 VOICES개를 미리 만들어 돌려 쓴다 (재생할 때마다 노드를 만들지 않음)
##   - 소리마다 동시에 울릴 수 있는 수(max)와 최소 간격(gap, 실제 시간 ms)이 있다.
##     2배속이어도 간격은 실제 시간 기준이라 소리가 두 배로 쌓이지 않는다
##   - 전투 소리(priority 0)는 다 합쳐 COMBAT_VOICES개까지. 나머지 자리는 UI, 보스, 웨이브 알림용
##
## 설정(음악/효과음 볼륨, 음소거)은 user://settings.cfg에 저장 (SHARD 저장 파일과 따로).

signal settings_changed

const SFX_DIR := "res://assets/sounds/sfx/"
const MUSIC_DIR := "res://assets/sounds/music/"
const VOICES := 14
const COMBAT_VOICES := 7
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## 일시정지 중에는 배경음을 이만큼(dB) 줄인다.
const PAUSE_DUCK_DB := -9.0
const MUSIC_FADE := 1.2

## 이름: [볼륨 dB, 동시에 최대 몇 개, 최소 간격 ms, 음높이 흔들림, 우선순위]
## 우선순위: 0 전투(자주 남), 1 처치/피격, 2 UI와 알림, 3 중요한 순간 (자리가 없으면 낮은 것을 끊고 울림)
const SOUNDS := {
	"click": [-8.0, 2, 40, 0.03, 2],
	"deny": [-9.0, 1, 150, 0.0, 2],
	"laser": [-17.0, 3, 90, 0.08, 0],
	"core_shot": [-15.0, 2, 110, 0.06, 0],
	"spark": [-14.0, 3, 80, 0.10, 0],
	"arrow": [-14.0, 3, 70, 0.10, 0],
	"frost": [-16.0, 2, 220, 0.05, 0],
	"flame": [-15.0, 2, 180, 0.10, 0],
	"shock": [-14.0, 2, 200, 0.08, 0],
	"orbit": [-18.0, 2, 90, 0.12, 0],
	"drone": [-16.0, 2, 80, 0.12, 0],
	"explode": [-13.0, 2, 130, 0.10, 0],
	"crit": [-14.0, 2, 120, 0.05, 0],
	"kill": [-11.0, 3, 45, 0.15, 1],
	"tile_hit": [-13.0, 2, 160, 0.10, 1],
	"tile_break": [-4.0, 2, 150, 0.05, 3],
	"boss_kill": [-3.0, 1, 300, 0.0, 3],
	"boss_appear": [-3.0, 1, 1000, 0.0, 3],
	"overlord": [-2.0, 1, 1000, 0.0, 3],
	"dash": [-15.0, 2, 120, 0.12, 0],
	"cloak": [-15.0, 2, 200, 0.10, 0],
	"heal": [-14.0, 1, 300, 0.05, 0],
	"shield": [-13.0, 1, 300, 0.05, 0],
	"boss_charge": [-4.0, 1, 500, 0.0, 3],
	"quake": [-3.0, 1, 400, 0.0, 3],
	"wave": [-8.0, 1, 500, 0.0, 2],
	"wave_clear": [-7.0, 1, 500, 0.0, 2],
	"card": [-6.0, 1, 100, 0.0, 2],
	"place": [-6.0, 1, 100, 0.03, 2],
	"equip": [-6.0, 1, 100, 0.0, 2],
	"levelup": [-5.0, 2, 80, 0.0, 2],
	"coin": [-9.0, 2, 80, 0.02, 2],
	"skill_overdrive": [-3.0, 1, 300, 0.0, 3],
	"skill_freeze": [-3.0, 1, 300, 0.0, 3],
	"skill_repair": [-3.0, 1, 300, 0.0, 3],
	"skill_nova": [-3.0, 1, 300, 0.0, 3],
	"skill_warp": [-3.0, 1, 300, 0.0, 3],
	"gameover": [-2.0, 1, 1000, 0.0, 3],
	"victory": [-2.0, 1, 1000, 0.0, 3],
}
## 배경음: 이름 -> 볼륨 dB
const TRACKS := {"menu": -6.0, "battle": -7.0, "boss": -6.0}

## 설정 (0~1). 테스트는 settings_path를 바꿔서 쓴다.
static var settings_path := "user://settings.cfg"
static var music_volume := 0.6
static var sfx_volume := 0.8
static var muted := false
static var _settings_loaded := false
static var _inst: Sfx

var _streams := {}
var _tracks := {}
var _players: Array[AudioStreamPlayer] = []
## 재생기마다 지금 울리는 소리 이름, 우선순위, 시작 시각(ms)
var _voice_name: Array[String] = []
var _voice_prio: Array[int] = []
var _voice_start: Array[int] = []
var _last_ms := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var current_track := ""
var _ducked := false
var _panel: SoundPanel


## 효과음 하나. 간격이나 동시 재생 수에 걸려서 안 울리면 false.
static func play(sound: String, pitch := 1.0) -> bool:
	var s := instance()
	return s != null and s._play(sound, pitch)


## 배경음 바꾸기 (천천히 겹쳐 바뀜). ""이면 끈다. 같은 곡이면 그대로 둔다.
static func music(track: String) -> void:
	var s := instance()
	if s != null:
		s._set_music(track)


static func instance() -> Sfx:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = Sfx.new()
	_inst.name = "Sfx"
	# 씬이 자식을 붙이는 도중일 수 있어서 다음 틈에 붙인다
	tree.root.add_child.call_deferred(_inst)
	return _inst


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_ensure_buses()
	for sound in SOUNDS:
		var path: String = SFX_DIR + sound + ".wav"
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
	for track in TRACKS:
		var path: String = MUSIC_DIR + track + ".ogg"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStreamOggVorbis
			stream.loop = true
			_tracks[track] = stream
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
		_voice_name.append("")
		_voice_prio.append(0)
		_voice_start.append(0)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_panel = SoundPanel.new()
	add_child(_panel)
	apply_settings()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = MUSIC_BUS
	p.volume_db = -80.0
	add_child(p)
	return p


func _ready() -> void:
	var tree := get_tree()
	tree.node_added.connect(_on_node_added)
	_hook_buttons(tree.root)
	# 붙기 전에 부탁받은 배경음
	if current_track != "":
		var want := current_track
		current_track = ""
		_set_music(want)


## 끌 때 울리던 소리를 멈춘다. (헤드리스 테스트는 소리 장치가 없어 종료 때 "leaked" 경고가 남지만 무해함)
func _exit_tree() -> void:
	for p in _players:
		p.stop()
	_music_a.stop()
	_music_b.stop()
	if _inst == self:
		_inst = null


func _process(_delta: float) -> void:
	var duck := get_tree().paused and not _panel.visible
	if duck != _ducked:
		_ducked = duck
		_apply_music_bus()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_N:
		set_muted(not muted)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 효과음

func _play(sound: String, pitch: float) -> bool:
	if not _streams.has(sound) or not is_inside_tree():
		return false
	if muted or sfx_volume <= 0.0:
		return false
	var def: Array = SOUNDS[sound]
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < int(def[2]):
		return false
	var prio: int = def[4]
	var same := 0
	var combat := 0
	var free := -1
	for i in VOICES:
		if not _players[i].playing:
			_voice_name[i] = ""
			if free < 0:
				free = i
			continue
		if _voice_name[i] == sound:
			same += 1
		if _voice_prio[i] == 0:
			combat += 1
	if same >= int(def[1]):
		return false
	if prio == 0 and combat >= COMBAT_VOICES:
		return false
	if free < 0:
		free = _steal_voice(prio)
		if free < 0:
			return false
	_last_ms[sound] = now
	var p := _players[free]
	p.stream = _streams[sound]
	p.volume_db = def[0]
	var jitter: float = def[3]
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.play()
	_voice_name[free] = sound
	_voice_prio[free] = prio
	_voice_start[free] = now
	return true


## 자리가 없을 때: 우선순위가 더 낮은 소리 중 가장 오래된 것을 끊는다.
func _steal_voice(prio: int) -> int:
	var best := -1
	for i in VOICES:
		if _voice_prio[i] < prio and (best < 0 or _voice_prio[i] < _voice_prio[best] \
				or (_voice_prio[i] == _voice_prio[best] and _voice_start[i] < _voice_start[best])):
			best = i
	if best >= 0:
		_players[best].stop()
	return best


## 지금 울리고 있는 효과음 수 (테스트용).
func active_voices(sound := "") -> int:
	var n := 0
	for i in VOICES:
		if _players[i].playing and (sound == "" or _voice_name[i] == sound):
			n += 1
	return n


## 화면에 새로 생기는 버튼마다 누르면 딸깍 소리.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		if not b.pressed.is_connected(_on_button_pressed):
			b.pressed.connect(_on_button_pressed)


func _hook_buttons(node: Node) -> void:
	_on_node_added(node)
	for c in node.get_children():
		_hook_buttons(c)


func _on_button_pressed() -> void:
	_play("click", 1.0)


# ---------------------------------------------------------------- 배경음

func _set_music(track: String) -> void:
	if track == current_track:
		return
	current_track = track
	if not is_inside_tree():
		return
	var old := _music_a
	var nxt := _music_b
	_music_a = nxt
	_music_b = old
	_fade(old, -80.0, MUSIC_FADE, true)
	if track != "" and _tracks.has(track):
		nxt.stream = _tracks[track]
		nxt.volume_db = -40.0
		nxt.play()
		_fade(nxt, TRACKS[track], MUSIC_FADE * 0.8, false)


func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	if p.has_meta("tween"):
		var old_tw := p.get_meta("tween") as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
	if not p.playing:
		return
	var tw := create_tween()
	# 일시정지와 배속에 상관없이 실제 시간으로
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "volume_db", to_db, time)
	if stop_after:
		tw.tween_callback(p.stop)
	p.set_meta("tween", tw)


# ---------------------------------------------------------------- 설정

func _ensure_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


static func apply_settings() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, muted)
	var sfx_bus := AudioServer.get_bus_index(SFX_BUS)
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, _to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_bus, sfx_volume <= 0.0)
	if _inst != null and is_instance_valid(_inst):
		_inst._apply_music_bus()
		_inst.settings_changed.emit()


func _apply_music_bus() -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, _to_db(music_volume) + (PAUSE_DUCK_DB if _ducked else 0.0))
	AudioServer.set_bus_mute(idx, music_volume <= 0.0)


## 0~1 볼륨을 dB로. 귀에 고르게 들리도록 제곱 곡선.
static func _to_db(v: float) -> float:
	return linear_to_db(maxf(v * v, 0.0001))


static func set_music_volume(v: float, save := true) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_settings()
	if save:
		save_settings()


static func set_sfx_volume(v: float, save := true) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_settings()
	if save:
		save_settings()


static func set_muted(on: bool) -> void:
	muted = on
	apply_settings()
	save_settings()


static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	music_volume = clampf(float(cfg.get_value("sound", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("sound", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("sound", "muted", muted))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("sound", "music", music_volume)
	cfg.set_value("sound", "sfx", sfx_volume)
	cfg.set_value("sound", "muted", muted)
	cfg.save(settings_path)


## 설정 창 열기 (SOUND 버튼).
static func open_panel() -> void:
	var s := instance()
	if s != null and s._panel != null:
		s._panel.open()


static func panel() -> SoundPanel:
	var s := instance()
	return s._panel if s != null else null
