extends SceneTree
## 실행: godot --headless --fixed-fps 60 --path . -s res://tests/test_stage_enemies.gd
## 스테이지별 적 구성과 새 적 기믹 (DASHER, MENDER, PHANTOM, HYDRA, AEGIS),
## 스테이지 보스 (MONOLITH, COMET, WRAITH, BASTION, OVERLORD).

var _failures := 0
var _frame := 0
var _game: Game


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _initialize() -> void:
	Game.hub_enabled = false
	Meta.save_path = "user://test_stage_enemies.cfg"
	Meta.reset()
	Meta.loaded = true
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_game = current_scene as Game
		_game.set_process(false)
		_rosters()
		_gimmicks()
		_bosses()
		if _failures == 0:
			print("ALL TESTS PASSED")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
		quit(1 if _failures > 0 else 0)
	return false


func _far(i: int) -> Vector2:
	return Vector2(-4000 - i * 300, 3000)


func _clear() -> void:
	for node in get_nodes_in_group(Enemy.GROUP):
		(node as Enemy)._die(false)


func _rosters() -> void:
	var bosses := {}
	for n in range(1, StageDefs.count() + 1):
		var boss := StageDefs.boss(n)
		_check(EnemyDefs.DEFS.has(boss) and EnemyDefs.DEFS[boss].get("final", false),
				"stage %d boss is a final boss" % n)
		bosses[boss] = true
		for kind in StageDefs.roster(n):
			_check(EnemyDefs.DEFS.has(kind) and not EnemyDefs.DEFS[kind].get("is_boss", false),
					"stage %d roster kind %s is a normal enemy" % [n, kind])
	_check(bosses.size() == StageDefs.count(), "every stage has its own boss")
	# 1스테이지는 예전 적 구성 그대로
	_check(StageDefs.roster(1).is_empty() and StageDefs.new_enemies(1).is_empty(), "stage 1 roster unchanged")
	var seen := {}
	for i in 3000:
		seen[EnemyDefs.pick_kind(30)] = true
	_check(not seen.has("dasher") and not seen.has("phantom") and seen.has("armored"),
			"default roster has only the old kinds")
	# 뒤 스테이지에서 새 적이 나온다
	for n in [2, 3, 4]:
		_check(not StageDefs.new_enemies(n).is_empty(), "stage %d brings new enemies" % n)
	_check(StageDefs.new_enemies(2).has("dasher") and StageDefs.new_enemies(3).has("phantom")
			and StageDefs.new_enemies(4).has("aegis"), "new enemies per stage")
	var s3 := {}
	for i in 4000:
		s3[EnemyDefs.pick_kind(20, StageDefs.roster(3))] = true
	for kind in StageDefs.roster(3):
		_check(s3.has(kind), "stage 3 spawns %s by wave 20" % kind)
	_check(not s3.has("aegis"), "stage 3 never spawns kinds outside its roster")
	# 등장 웨이브는 지킨다
	for i in 500:
		_check(EnemyDefs.pick_kind(1, StageDefs.roster(5)) == "grunt", "wave 1 only grunts in stage 5")
	_check(StageDefs.tooltip(2).contains("COMET") and StageDefs.tooltip(2).contains("DASHER"),
			"stage tooltip names boss and new enemies")
	# 게임이 스테이지 구성대로 뽑는다
	_game.stage = 2
	_game.wave = 15
	seed(7)
	_game.set_process(true)
	_game.state = Game.State.WAVE
	_game._to_spawn = 200
	_game._spawn_timer = 0.0
	var kinds := {}
	for i in 200:
		_game._spawn_timer = 0.0
		_game._process(0.01)
	for node in get_nodes_in_group(Enemy.GROUP):
		kinds[(node as Enemy).kind] = true
	_game.set_process(false)
	_game._to_spawn = 0
	_check(kinds.has("dasher") and kinds.has("mender") and not kinds.has("phantom"),
			"stage 2 run spawns its roster (%s)" % str(kinds.keys()))
	_clear()
	_game.stage = 1


func _gimmicks() -> void:
	_game.wave = 12
	var core := _game.board.core_tile()

	# DASHER: 주기마다 dash_speed배로 튀어나간다
	var d := _game.spawn_enemy("dasher", _far(0))
	d._dash_cd = 0.0
	var p0 := d.global_position
	d._process(0.1)
	_check(d.is_dashing(), "dasher dashes")
	var dashed := d.global_position.distance_to(p0)
	_check(absf(dashed - d.speed * d.dash_speed * 0.1) < 0.5, "dash moves dash_speed times faster")
	d._dash_left = 0.0
	d._dash_cd = 99.0
	p0 = d.global_position
	d._process(0.1)
	_check(absf(d.global_position.distance_to(p0) - d.speed * 0.1) < 0.5, "normal speed between dashes")
	_check(absf(d._body.rotation - (core.global_position - d.global_position).angle()) < 0.05,
			"dasher faces where it goes")

	# MENDER: 주변 적 회복, 멀리 있는 적은 그대로, 보스는 조금만
	var m := _game.spawn_enemy("mender", _far(1))
	var hurt := _game.spawn_enemy("grunt", _far(1) + Vector2(60, 0))
	var far := _game.spawn_enemy("grunt", _far(1) + Vector2(600, 0))
	var boss := _game.spawn_enemy("boss", _far(1) + Vector2(0, 80))
	for e in [hurt, far, boss]:
		e.hp = e.max_hp * 0.5
	m.pulse_aura()
	_check(is_equal_approx(hurt.hp, hurt.max_hp * (0.5 + m.aura_amount)), "mender heals nearby")
	_check(is_equal_approx(far.hp, far.max_hp * 0.5), "mender range limited")
	_check(is_equal_approx(boss.hp, boss.max_hp * (0.5 + m.aura_boss)), "mender heals bosses less")
	hurt.hp = hurt.max_hp - 1.0
	m.pulse_aura()
	_check(is_equal_approx(hurt.hp, hurt.max_hp), "heal caps at max hp")

	# AEGIS: 보호막이 먼저 깎이고, 쌓이지 않는다. 통계에는 보호막 몫도 준 피해로
	var a := _game.spawn_enemy("aegis", _far(2))
	var g := _game.spawn_enemy("grunt", _far(2) + Vector2(50, 0))
	a.pulse_aura()
	var sh := g.max_hp * a.aura_amount
	_check(is_equal_approx(g.shield, sh), "aegis shields nearby")
	a.pulse_aura()
	_check(is_equal_approx(g.shield, sh), "shield does not stack")
	g.take_damage(sh * 0.5)
	_check(is_equal_approx(g.hp, g.max_hp) and is_equal_approx(g.shield, sh * 0.5), "shield absorbs first")
	g.take_damage(sh)
	_check(g.shield == 0.0 and is_equal_approx(g.hp, g.max_hp - sh * 0.5), "overflow goes to hp")

	# PHANTOM: 은신 중에는 노려지지도 맞지도 않는다
	var ph := _game.spawn_enemy("phantom", _far(3))
	ph.cloak()
	_check(ph.is_cloaked() and not ph.is_alive() and ph.exists(), "phantom cloaks")
	_check(ph.modulate.a < 0.5, "cloaked phantom is faint")
	var hp0 := ph.hp
	ph.take_damage(1000.0)
	_check(ph.hp == hp0 and ph.exists(), "cloaked phantom takes no damage")
	var tile := HexTile.new()
	tile.setup("laser")
	_game.board.add_child(tile)
	tile.global_position = ph.global_position + Vector2(80, 0)
	_check(not tile.enemies_in_range().has(ph), "tiles do not target a cloaked phantom")
	ph._process(ph.cloak_time + 0.01)
	_check(not ph.is_cloaked() and ph.is_alive() and ph.modulate.a == 1.0, "phantom reappears")
	_check(tile.enemies_in_range().has(ph), "targetable again")
	tile.queue_free()

	# HYDRA: SPLITTER 2마리 -> 각각 RUNNER 2마리
	_clear()
	var h := _game.spawn_enemy("hydra", _far(4))
	h.take_damage(1e9)
	var splitters := get_nodes_in_group(Enemy.GROUP).filter(func(e: Enemy) -> bool:
			return e.kind == "splitter")
	_check(splitters.size() == 2, "hydra splits into 2 splitters")
	for s in splitters:
		(s as Enemy).take_damage(1e9)
	var runners := get_nodes_in_group(Enemy.GROUP).filter(func(e: Enemy) -> bool:
			return e.kind == "runner")
	_check(runners.size() == 4, "then into 4 runners")
	_clear()


func _bosses() -> void:
	_game.wave = EnemyDefs.FINAL_WAVE
	var board := _game.board
	var core := board.core_tile()
	for n in range(1, StageDefs.count() + 1):
		_game.stage = n
		_game.final_boss = null
		var b := _game._spawn_boss()
		_check(b.kind == StageDefs.boss(n) and b.is_final and _game.final_boss == b
				and _game.hud.is_boss_bar_visible(), "stage %d spawns %s with a boss bar" % [n, b.kind])
		_check(is_equal_approx(b.max_hp, _game.wave_enemy_hp(EnemyDefs.FINAL_WAVE)
				* StageDefs.hp_mult(n) * EnemyDefs.DEFS[b.kind]["hp"]), "%s hp" % b.kind)
		b._die(false)
	_clear()

	# MONOLITH: 75/50/25%에서 한 번씩 GRUNT를 둥글게
	_game.stage = 1
	var mono := _game.spawn_enemy("monolith", Vector2(-5000, -3000))
	var before := _game.alive_enemies()
	mono.take_damage(mono.max_hp * 0.3 / (1.0 - mono.armor))
	_check(_game.alive_enemies() == before + mono.quake_count, "monolith quake at 75%")
	mono.take_damage(1.0)
	_check(_game.alive_enemies() == before + mono.quake_count, "each threshold only once")
	mono.take_damage(mono.max_hp * 0.5 / (1.0 - mono.armor))
	_check(_game.alive_enemies() == before + mono.quake_count * 3, "two thresholds at once -> two quakes")
	_clear()

	# COMET: 멈춰서 기를 모은 뒤 들이받는다. 첫 타격 dash_hit배
	var comet := _game.spawn_enemy("comet", core.global_position + Vector2(220, 0))
	comet._summon_cd = 99.0
	comet._dash_cd = 0.0
	var p0 := comet.global_position
	comet._process(0.05)
	_check(comet.is_winding_up() and comet.global_position == p0, "comet stops to wind up")
	comet._process(comet.dash_windup)
	_check(comet.is_dashing(), "then charges")
	comet.contact_damage = 5.0
	core.hp = core.max_hp
	for i in 60:
		comet._process(1.0 / 60.0)
		if not comet.is_dashing():
			break
	_check(not comet.is_dashing() and is_equal_approx(core.max_hp - core.hp, 5.0 * comet.dash_hit),
			"charge hit deals dash_hit (%.1f)" % (core.max_hp - core.hp))
	core.hp = core.max_hp
	comet._die(false)
	_clear()

	# WRAITH: 숨을 때 PHANTOM을 부르고, 숨어 있는 동안 회복, 체력 막대는 그대로
	_game.stage = 3
	_game.final_boss = null
	var wr := _game._spawn_boss()
	wr.global_position = Vector2(-5000, 3000)
	wr.hp = wr.max_hp * 0.5
	before = _game.alive_enemies()
	wr._cloak_cd = 0.0
	wr._process(0.01)
	_check(wr.is_cloaked() and _game.alive_enemies() == before + wr.summon_count, "wraith cloaks and summons")
	var hp_cloaked := wr.hp
	wr._process(1.0)
	_check(wr.hp > hp_cloaked, "wraith regenerates while cloaked")
	_game.set_process(true)
	_game._process(0.01)
	_game.set_process(false)
	_check(_game.final_boss == wr and _game.hud.is_boss_bar_visible(), "boss bar stays while cloaked")
	wr._die(false)
	_clear()

	# BASTION: 자기와 주변에 보호막
	var bas := _game.spawn_enemy("bastion", Vector2(-6000, 3000))
	var near := _game.spawn_enemy("grunt", Vector2(-6000, 3150))
	bas.pulse_aura()
	_check(is_equal_approx(bas.shield, bas.max_hp * bas.aura_boss)
			and is_equal_approx(near.shield, near.max_hp * bas.aura_amount), "bastion shields itself and allies")
	_clear()

	# 배너와 결과창 글자에 스테이지 보스 이름
	_game.stage = 2
	_game.wave = EnemyDefs.FINAL_WAVE - 1
	_game._begin_wave()
	_check(_game.hud._banner_label.text == Loc.t("FINAL WAVE  -  %s") % "COMET", "final banner names the stage boss")
