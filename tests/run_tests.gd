extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Workers = preload("res://scripts/worker_manager.gd")
const Progression = preload("res://scripts/progression_manager.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Daily = preload("res://scripts/daily_manager.gd")
const Saves = preload("res://scripts/save_manager.gd")
const Schema = preload("res://scripts/save_schema.gd")
const Visuals = preload("res://scripts/visuals.gd")
const StaticBatch = preload("res://scripts/static_batch.gd")

var failures: int = 0
var checks: int = 0
var artifacts: String
var fixtures: Array[Node] = []


func _initialize() -> void:
	artifacts = ProjectSettings.globalize_path("res://test-artifacts/regression-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(artifacts)
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func fixture(name: String, restore: bool = false, date_provider: Callable = Callable()) -> Dictionary:
	var holder := Node.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(holder)
	fixtures.append(holder)
	var state := State.new()
	holder.add_child(state)
	var player := Node3D.new()
	player.position = Vector3(0, 0.5, 8)
	holder.add_child(player)
	var workers := Workers.new()
	workers.setup(state)
	holder.add_child(workers)
	var progression := Progression.new()
	progression.setup(state)
	holder.add_child(progression)
	var quests := Quests.new()
	quests.setup(state)
	holder.add_child(quests)
	var daily := Daily.new()
	if date_provider.is_valid():
		daily.date_provider = date_provider
	daily.setup(state)
	holder.add_child(daily)
	var saves := Saves.new()
	saves.save_path = artifacts.path_join(name + ".json")
	saves.setup(state, player, workers)
	saves.progression = progression
	saves.quest_manager = quests
	saves.daily_manager = daily
	holder.add_child(saves)
	if restore:
		saves.load_game()
	quests.finish_loading()
	daily.finish_loading()
	saves.start_saving()
	return {"state": state, "player": player, "workers": workers, "progression": progression,
		"quests": quests, "daily": daily, "saves": saves}


func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "test can write its isolated fixture")
	if file != null:
		file.store_string(value)
		file.close()


func envelope(data: Dictionary) -> String:
	var payload := JSON.stringify(data)
	return JSON.stringify({"version": data["version"], "payload": payload, "checksum": payload.sha256_text()})


func test_visual_resource_reuse() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var first := Visuals.box(parent, Vector3.ONE, Vector3.ZERO, Color.RED)
	var second := Visuals.box(parent, Vector3.ONE, Vector3.RIGHT, Color.RED)
	var different := Visuals.box(parent, Vector3(2, 1, 1), Vector3.ZERO, Color.BLUE)
	check(first.mesh == second.mesh and first.material_override == second.material_override, "identical primitives reuse geometry and material resources")
	check(first.mesh != different.mesh and first.material_override != different.material_override, "different geometry and colors remain distinct")
	second.position = Vector3.UP
	second.scale = Vector3(2, 2, 2)
	check(first.position == Vector3.ZERO and first.scale == Vector3.ONE, "shared geometry preserves independent animation transforms")
	check(Visuals.material(Color.RED, true) != Visuals.material(Color.RED), "lit and unshaded materials stay separate")
	var sphere := Visuals.sphere(parent, 0.3, Vector3.ZERO, Color.RED)
	var sphere_copy := Visuals.sphere(parent, 0.3, Vector3.UP, Color.BLUE)
	var cylinder := Visuals.cylinder(parent, 0.3, 1.0, Vector3.ZERO, Color.RED)
	var cylinder_copy := Visuals.cylinder(parent, 0.3, 1.0, Vector3.UP, Color.BLUE)
	check(sphere.mesh == sphere_copy.mesh and cylinder.mesh == cylinder_copy.mesh, "rounded primitives share immutable geometry")
	parent.free()


func test_static_batch_preserves_animation() -> void:
	var parent := Node3D.new()
	parent.position = Vector3(3, 2, 1)
	root.add_child(parent)
	var nested := Node3D.new()
	nested.position = Vector3(2, 0, 0)
	parent.add_child(nested)
	var originals: Array[MeshInstance3D] = []
	for i in range(3):
		originals.append(Visuals.box(nested, Vector3.ONE, Vector3(i, 0, 0), Color.RED))
	var animated := Node3D.new()
	parent.add_child(animated)
	var moving := Visuals.box(animated, Vector3.ONE, Vector3.ZERO, Color.RED)
	var hidden := Visuals.box(parent, Vector3.ONE, Vector3.ZERO, Color.RED)
	hidden.hide()
	StaticBatch.build(parent, [animated])
	var batch := parent.get_node_or_null("StaticBatch") as MeshInstance3D
	check(batch != null, "static geometry is merged")
	if batch != null:
		var bounds: AABB = originals[0].global_transform * originals[0].mesh.get_aabb()
		for source in originals:
			bounds = bounds.merge(source.global_transform * source.mesh.get_aabb())
		var actual: AABB = batch.global_transform * batch.mesh.get_aabb()
		check(actual.position.is_equal_approx(bounds.position) and actual.size.is_equal_approx(bounds.size), "merged geometry preserves nested world bounds and excludes hidden/animated sources")
	check(not originals[0].visible and moving.visible and not hidden.visible, "static sources hide while excluded animation and hidden objects retain visibility")
	animated.position = Vector3.UP
	check(moving.global_position == animated.global_position, "excluded geometry still follows animation parent")
	check(batch != null and batch.material_override.vertex_color_use_as_albedo and batch.material_override.roughness == originals[0].material_override.roughness, "merged surface preserves source shading and uses vertex colors")
	parent.free()


func test_harbor_progression_and_save() -> void:
	var f := fixture("harbor")
	var harbor: Node = f.state.harbor
	f.state.coins = 1000
	f.quests.completed.assign([true, true, true])
	f.quests.progress.assign([10, 5, 3])
	f.daily.daily_done.assign([true, true, true])
	f.daily.daily_progress.assign([15, 5, 3])
	check(not harbor.buy_equipment(0) and f.state.coins == 1000, "gear level gate preserves money")
	check(not harbor.catch_special(0) and not harbor.open_market(), "new fisheries and market start locked")
	f.progression.level = 2
	check(harbor.buy_equipment(0) and f.state.coins == 900, "rod purchase pays its milestone once")
	check(not harbor.buy_equipment(0) and f.state.coins == 900, "owned equipment cannot be bought again")
	check(not harbor.catch_special(1) and not harbor.catch_special(2), "higher species stay gated by level")
	for _i in range(3):
		check(harbor.catch_special(0), "unlocked perch can be caught")
	check(harbor.raw_stock == [3, 0, 0] and harbor.caught == [3, 0, 0], "special catch records distinct stock and lifetime total")
	check(f.state.player_fish_caught == 3 and f.state.player_fish == 0, "special catches advance personal statistics without entering generic inventory")
	check(f.state.coins == 975, "first three special catches pay one milestone")
	f.progression.level = 7
	f.state.coins = 5000
	check(harbor.buy_equipment(1) and harbor.buy_equipment(2) and harbor.open_market(), "advanced level unlocks cooler, smoker and premium market")
	check(not harbor.open_market(), "premium market cannot be purchased twice")
	check(harbor.select_species(2) and harbor.catch_special(2) and harbor.raw_stock[2] == 2, "cooler doubles tuna yield and selection is usable")
	check(harbor.start_smoking(0) and not harbor.start_smoking(0), "smoker consumes one fish and blocks concurrent work")
	harbor._process(4.0)
	var money: int = f.state.coins
	check(f.saves.save_game(), "new content and in-flight smoking save")
	var g := fixture("harbor", true)
	var restored: Node = g.state.harbor
	check(g.state.coins == money and restored.equipment == [true, true, true] and restored.zone_open, "new content reload preserves purchases without rewards")
	check(restored.smoking_species == 0 and restored.smoking_elapsed == 4.0 and restored.raw_stock[0] == 2, "in-flight smoking reload does not consume fish twice")
	check(restored.selected_species == 2 and restored.raw_stock[2] == 2, "selected species and separate stocks survive reload")
	restored._process(4.0)
	check(restored.smoking_species == -1 and restored.smoked_stock[0] == 1 and restored.smoked_total == 1, "restored smoking finishes exactly once")
	restored._process(20.0)
	check(restored.smoked_stock[0] == 1, "idle smoker does not duplicate output")
	var before: int = g.state.coins
	check(restored.sell_order(0, 1, true, true) and g.state.coins == before + 54, "chef pays premium for smoked perch")
	check(not restored.sell_order(0, 1, true, true) and g.state.coins == before + 54, "fulfilled stock cannot be sold twice")
	check(not restored.sell_order(-1, 1, false, false) and not restored.sell_order(0, -1, false, false), "invalid orders cannot create money or stock")
	check(Schema.valid(g.saves.get_save_data()), "new content snapshot satisfies full schema")
	for field in ["raw_stock", "equipment", "smoking_elapsed", "zone_open"]:
		var invalid: Dictionary = g.saves.get_save_data().duplicate(true)
		invalid["harbor"][field] = "invalid"
		check(not Schema.valid(invalid), "new content schema rejects invalid " + field)
	var legacy: Dictionary = g.saves.get_save_data()
	legacy["version"] = 3
	legacy["revision"] = 100
	legacy.erase("harbor")
	write_text(g.saves.save_path, envelope(legacy))
	g.saves.load_game()
	check(g.state.coins == before + 54 and not restored.zone_open and restored.raw_stock == [0, 0, 0], "version 3 migration starts new content without changing old economy")
	g.saves.start_saving()
	check(g.saves.save_game() and g.saves._read_snapshot(g.saves.save_path).get("revision") == 101, "content migration preserves revision chronology")


func test_harbor_world_interactions() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = artifacts.path_join("harbor-world.json")
	root.add_child(scene)
	fixtures.append(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.save_manager.ready_to_save = false
	scene.progression.level = 7
	var harbor: Node = scene.state.harbor
	harbor.equipment.assign([true, true, true])
	harbor.goal_done.assign([true, true, true, true, true])
	harbor.zone_open = true
	harbor.updated.emit()
	scene.player.position = harbor.RIVER + Vector3(0, 0.5, 0)
	scene.harbor_world._process(3.1)
	check(harbor.raw_stock[0] == 2, "real river pier catches selected perch")
	scene.state.controls_blocked = true
	scene.harbor_world._process(6.0)
	check(harbor.raw_stock[0] == 2, "modal blocks special fishing")
	scene.state.controls_blocked = false
	scene.player.position = harbor.REEF + Vector3(0, 0.5, 0)
	scene.harbor_world._process(3.1)
	check(harbor.raw_stock[0] == 2, "river species cannot be caught at sea pier")
	harbor.select_species(2)
	scene.harbor_world._process(3.1)
	check(harbor.raw_stock[2] == 2, "real sea pier catches unlocked tuna")
	check(scene.harbor_world.market_root.visible, "purchased premium market appears in world")
	scene.state.hired[3] = 1
	check(not scene.harbor_world.visitors.is_empty(), "opened market spawns visible special visitors")
	var visitor: Dictionary = scene.harbor_world.visitors[0]
	visitor["node"].position = harbor.MARKET + Vector3(0, 0.5, 1.4)
	var before: int = scene.state.coins
	scene.harbor_world._update_visitor(visitor, 2.1)
	check(visitor["leaving"] and harbor.orders == 1 and scene.state.coins > before, "seller fulfills real visitor order from premium stock")
	var actor := Visuals.animated_person(scene, Color("#527A91"))
	check(actor["body"].get_child_count() == 6 and actor["left_arm"].get_child_count() == 1, "actor keeps animation pivots with compact rigid meshes")


func test_worker_restoration() -> void:
	var f := fixture("workers")
	f.state.coins = 1234
	f.state.hired.assign([2, 1, 1, 1])
	f.state.prices.assign([77, 81, 109, 155])
	f.quests.completed.assign([true, true, true])
	f.quests.progress.assign([10, 5, 3])
	f.daily.achievement_done.assign([false, false, true])
	var events := [0]
	f.state.changed.connect(func(): events[0] += 1)
	f.state.reward.connect(func(_a, _b, _c, _d): events[0] += 1)
	f.state.notice.connect(func(_text): events[0] += 1)
	f.workers.restore_workers()
	f.workers.restore_workers()
	check(f.workers.workers.size() == 5 and f.workers.get_child_count() == 5, "restoration is idempotent")
	check(f.state.coins == 1234 and f.state.prices == [77, 81, 109, 155], "restoration preserves money and prices")
	check(events[0] == 0, "restoration emits no purchase, reward or state events")
	f.workers.workers[0]["cargo"] = 3
	f.workers.workers[2]["cargo"] = 2
	f.workers.workers[3]["cargo"] = 4
	f.state.fish_box = 7
	f.state.machine_output = 9
	f.progression.level = 6
	f.progression.xp = 42
	f.progression.total_xp = 800
	check(f.saves.save_game(), "worker fixture saves")
	var g := fixture("workers", true)
	check(g.state.coins == 1234 and g.state.prices == [77, 81, 109, 155], "reload preserves worker economy")
	check(g.workers.workers.size() == 5, "reload creates exactly the hired workers")
	check(g.state.fish_box == 12 and g.state.machine_output == 13, "cargo is returned to stock exactly once")
	check(g.progression.level == 6 and g.progression.xp == 42 and g.progression.total_xp == 800, "XP survives reload without level rewards")
	check(g.saves.save_game(), "restored worker snapshot saves")
	var h := fixture("workers", true)
	check(h.state.fish_box == 12 and h.state.machine_output == 13, "second reload does not duplicate cargo")
	check(h.state.coins == 1234, "completed worker quests and achievements do not pay on reload")


func test_fishing_and_rewards() -> void:
	var f := fixture("fishing")
	var completion_snapshots: Array[Dictionary] = []
	f.quests.quests_updated.connect(func(): completion_snapshots.append(f.saves.get_save_data()))
	f.state.record_fish_caught(50, false)
	f.state.reward.emit(999, "🐟", Color.WHITE, Vector3.ZERO)
	check(f.quests.progress[0] == 0 and f.daily.daily_progress[0] == 0, "worker catches and popups do not advance personal quests")
	f.state.record_fish_caught(10, true)
	check(f.quests.completed[0] and f.state.coins == 50, "personal fishing quest pays once")
	for snapshot in completion_snapshots:
		if snapshot["quests"]["progress"][0] == 10:
			check(snapshot["quests"]["completed"][0] and snapshot["coins"] >= 50, "completion observers see flags and coins committed together")
	f.state.record_fish_caught(5, true)
	check(f.daily.daily_done[0] and f.state.coins == 125, "daily fishing quest pays once")
	check(f.state.player_fish_caught == 15 and f.state.worker_fish_caught == 50, "separate lifetime fishing counters")
	f.state.changed.emit()
	check(f.saves.save_game(), "quest completion snapshot saves")
	for _reload in range(3):
		f.saves.load_game()
		f.quests.finish_loading()
		f.daily.finish_loading()
		f.saves.start_saving()
		f.state.changed.emit()
		check(f.state.coins == 125, "reloading cannot pay fishing rewards again")
		check(f.quests.completed[0] and f.daily.daily_done[0], "quest completion flags survive reload")
	check(f.state.player_fish_caught == 15 and f.state.worker_fish_caught == 50, "catch counters survive reload")
	f.daily.day = "2000-01-01"
	f.daily._check_day()
	check(f.daily.daily_progress == [0, 0, 0] and not f.daily.daily_done[0], "a new day resets only daily quests")
	f.daily.day = "2099-12-31"
	f.daily.daily_done[0] = true
	f.daily._check_day()
	check(f.daily.daily_done[0], "clock rollback cannot reset paid daily rewards")
	var w := fixture("actual-worker")
	w.state.hired[0] = 1
	w.workers.restore_workers()
	w.workers.workers[0]["step"] = "fishing"
	w.workers.workers[0]["timer"] = 3.0
	w.workers._fisher(w.workers.workers[0], 0.0)
	check(w.state.worker_fish_caught == 1 and w.quests.progress[0] == 0, "actual worker fishing uses the worker catch event")


func test_daily_achievement_roundtrip() -> void:
	var f := fixture("daily-achievements")
	f.state.customers_served = 10
	f.state.served = 25
	f.state.hired.assign([2, 1, 1, 1])
	f.state.changed.emit()
	# Worker quest = 150, three achievements = 200 + 350 + 500.
	check(f.state.coins == 1200, "all eligible achievements and worker quest pay once")
	f.daily.daily_progress.assign([7, 2, 1])
	f.quests.progress[0] = 4
	f.quests.progress[1] = 2
	check(f.saves.save_game(), "achievement snapshot saves")
	var g := fixture("daily-achievements", true)
	check(g.state.coins == 1200, "completed achievements do not pay on load")
	check(g.daily.achievement_done == [true, true, true], "all achievement flags survive")
	check(g.daily.daily_progress == [7, 2, 1], "partial daily progress survives")
	check(g.quests.progress == [4, 2, 3], "partial main quest progress survives")
	var legacy: Dictionary = g.saves.get_save_data()
	legacy["quests"]["progress"][0] = 10
	legacy["quests"]["completed"][0] = false
	legacy["daily"]["daily_progress"][0] = 15
	legacy["daily"]["daily_done"][0] = false
	write_text(g.saves.save_path, envelope(legacy))
	g.saves.load_game()
	g.quests.finish_loading()
	g.daily.finish_loading()
	check(g.state.coins == 1200 and g.quests.completed[0] and g.daily.daily_done[0], "legacy completion boundary is normalized without paying twice")


func test_recovery_and_validation() -> void:
	var f := fixture("recovery")
	f.state.coins = 100
	check(f.saves.save_game(), "first atomic save creates primary and backup")
	f.state.coins = 200
	check(f.saves.save_game(), "second atomic save rotates the backup")
	var backup_text := FileAccess.get_file_as_string(f.saves.save_path + ".bak")
	var primary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(f.saves.save_path))
	primary["payload"] += " "
	write_text(f.saves.save_path, JSON.stringify(primary))
	var g := fixture("recovery", true)
	check(g.state.coins == 100 and not g.saves.recovery_notice.is_empty(), "checksum mismatch recovers previous backup")
	check(g.saves.save_game(), "recovered state can save again")
	check(FileAccess.get_file_as_string(g.saves.save_path + ".bak") == backup_text, "corrupt primary cannot overwrite the healthy backup")
	write_text(g.saves.save_path, "{broken")
	g.saves.load_game()
	check(g.state.coins == 100, "truncated JSON falls back to backup")
	var baseline: Dictionary = g.saves.get_save_data()
	for mutate in ["wrong_type", "missing_key", "too_many_workers", "wrong_flags", "invalid_progression", "nonfinite", "fraction", "position"]:
		var invalid: Dictionary = baseline.duplicate(true)
		match mutate:
			"wrong_type": invalid["coins"] = "200"
			"missing_key": invalid.erase("hired")
			"too_many_workers": invalid["hired"][0] = 9999999
			"wrong_flags": invalid["quests"]["completed"] = ["false", false, false]
			"invalid_progression": invalid["progression"]["level"] = -2
			"nonfinite": invalid["boat_time"] = INF
			"fraction": invalid["coins"] = 2.5
			"position": invalid["player_position"][0] = []
		check(not Schema.valid(invalid), "schema rejects " + mutate)
	# No partially applied state, and no silent replacement when every copy is bad.
	write_text(g.saves.save_path, "{broken-primary")
	write_text(g.saves.save_path + ".bak", "{broken-backup")
	g.state.coins = 777
	check(g.saves.load_game().is_empty() and g.state.coins == 777, "invalid copies leave live state untouched")
	g.saves.start_saving()
	check(g.saves.write_blocked and not g.saves.save_game(), "invalid copies block destructive autosave")
	check(FileAccess.get_file_as_string(g.saves.save_path) == "{broken-primary", "corrupt files remain available for manual recovery")
	# Unsupported future versions are preserved even when an older backup exists.
	write_text(g.saves.save_path, JSON.stringify({"version": 999}))
	write_text(g.saves.save_path + ".bak", envelope(baseline))
	check(g.saves.load_game().is_empty() and g.saves.write_blocked, "newer save versions are never downgraded")
	# A complete .tmp snapshot is recoverable after interruption before rename.
	var pending := fixture("pending")
	write_text(pending.saves.save_path + ".tmp", envelope(baseline))
	check(not pending.saves.load_game().is_empty() and pending.state.coins == 100, "pending snapshot recovers interrupted first save")
	var failed := fixture("write-failure")
	failed.state.coins = 300
	check(failed.saves.save_game(), "write failure fixture has an existing save")
	var original := FileAccess.get_file_as_string(failed.saves.save_path)
	DirAccess.make_dir_absolute(failed.saves.save_path + ".tmp")
	failed.state.coins = 400
	check(not failed.saves.save_game(), "failed temporary write reports failure")
	check(FileAccess.get_file_as_string(failed.saves.save_path) == original, "write failure preserves existing primary")


func test_stale_pending_recovery() -> void:
	var f := fixture("stale-pending")
	f.state.coins = 100
	f.daily.daily_progress.assign([7, 2, 1])
	var older := envelope(f.saves.get_save_data())
	f.state.coins = 200
	f.daily.daily_progress.assign([9, 3, 2])
	var newer_data: Dictionary = f.saves.get_save_data()
	newer_data["revision"] = 2
	var newer := envelope(newer_data)
	write_text(f.saves.save_path, newer)
	write_text(f.saves.save_path + ".tmp", older)
	write_text(f.saves.save_path + ".bak", newer)
	check(not f.saves.load_game().is_empty() and f.state.coins == 200, "healthy primary takes priority over stale pending snapshot")
	check(f.saves.recovery_notice.is_empty(), "healthy primary does not report recovery")
	write_text(f.saves.save_path, "{corrupt-newer-primary")
	var g := fixture("stale-pending", true)
	check(g.state.coins == 200 and g.daily.daily_progress == [9, 3, 2], "newer backup wins over stale pending progress")
	check(not g.saves.write_blocked and not g.saves.recovery_notice.is_empty(), "newest backup recovery is reported and allows saving")
	check(FileAccess.get_file_as_string(g.saves.save_path + ".tmp") == older, "loading does not modify the recovery source")
	check(g.saves.save_game(), "newest recovered progress can replace corrupt primary")
	check(not FileAccess.file_exists(g.saves.save_path + ".tmp"), "successful recovery save commits pending file")
	check(FileAccess.get_file_as_string(g.saves.save_path + ".bak") == newer, "saving recovered progress preserves a healthy existing backup")
	var h := fixture("stale-pending", true)
	check(h.state.coins == 200 and h.daily.daily_progress == [9, 3, 2], "second launch keeps newest recovered progress without reward duplication")
	write_text(h.saves.save_path, "{broken")
	write_text(h.saves.save_path + ".tmp", "{incomplete")
	check(not h.saves.load_game().is_empty() and h.state.coins == 200, "invalid pending snapshot falls through to healthy backup")


func test_snapshot_revisions() -> void:
	var f := fixture("revision-order")
	var baseline: Dictionary = f.saves.get_save_data()
	var paths := [f.saves.save_path, f.saves.save_path + ".tmp", f.saves.save_path + ".bak"]
	for order in [[1, 2, 3], [1, 3, 2], [2, 1, 3], [2, 3, 1], [3, 1, 2], [3, 2, 1]]:
		for i in range(3):
			var data: Dictionary = baseline.duplicate(true)
			data["revision"] = order[i]
			# Spending can reduce coins in the newest snapshot.
			data["coins"] = 400 - order[i] * 100
			write_text(paths[i], envelope(data))
		var loaded: Dictionary = f.saves.load_game()
		check(loaded.get("revision") == 3 and f.state.coins == 100, "highest revision wins for permutation %s" % [order])
	for i in range(3):
		var tied: Dictionary = baseline.duplicate(true)
		tied["revision"] = 5
		tied["coins"] = 100 + i
		write_text(paths[i], envelope(tied))
	check(f.saves.load_game().get("coins") == 100, "equal protected revisions prefer primary deterministically")
	# Only pending survives; failure to back it up must leave it untouched.
	write_text(paths[0], "{broken")
	write_text(paths[2], "{broken")
	var newest: Dictionary = baseline.duplicate(true)
	newest["revision"] = 10
	newest["coins"] = 42
	var pending_text := envelope(newest)
	write_text(paths[1], pending_text)
	check(f.saves.load_game().get("revision") == 10, "sole valid pending snapshot loads")
	f.saves.start_saving()
	DirAccess.make_dir_absolute(paths[2] + ".tmp")
	check(not f.saves.save_game(), "backup failure aborts before replacing recovered pending source")
	check(FileAccess.get_file_as_string(paths[1]) == pending_text, "backup failure preserves sole valid pending snapshot")
	DirAccess.remove_absolute(paths[2] + ".tmp")
	check(f.saves.save_game(), "pending recovery saves after backup becomes writable")
	check(f.saves._read_snapshot(paths[0]).get("revision") == 11, "revision advances from recovered pending snapshot")
	check(f.saves._read_snapshot(paths[2]).get("revision") == 10, "newest pending is backed up before replacement")
	f.state.coins = 12
	check(f.saves.save_game() and f.saves._read_snapshot(paths[0]).get("revision") == 12, "changed snapshot advances revision again")
	for invalid_revision in [0, -1, 1.5, "99", INF, Schema.MAX_VALUE + 1]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid["revision"] = invalid_revision
		write_text(paths[1], envelope(invalid))
		check(not f.saves._read_snapshot(paths[1]).has("data"), "invalid revision is rejected: %s" % invalid_revision)
	# Equal legacy revisions have no reliable chronology; keep stable path priority.
	var legacy: Dictionary = baseline.duplicate(true)
	legacy["version"] = 2
	legacy.erase("revision")
	for i in range(3):
		legacy["coins"] = 100 + i
		write_text(paths[i], envelope(legacy))
	check(f.saves.load_game().get("coins") == 100, "legacy ties prefer primary without using coins or file times")
	f.saves.start_saving()
	check(f.saves.save_game() and f.saves._read_snapshot(paths[0]).get("revision") == 1, "version 2 migrates to first protected revision")
	var tampered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths[0]))
	var tampered_data: Dictionary = JSON.parse_string(tampered["payload"])
	tampered_data["revision"] = 999
	tampered["payload"] = JSON.stringify(tampered_data)
	write_text(paths[1], JSON.stringify(tampered))
	check(not f.saves._read_snapshot(paths[1]).has("data"), "revision tampering invalidates checksum")
	for path in [paths[1], paths[2]]:
		var original := FileAccess.get_file_as_string(path)
		f.saves.load_game()
		f.saves.start_saving()
		write_text(path, JSON.stringify({"version": 999}))
		check(not f.saves.save_game() and FileAccess.get_file_as_string(path) == JSON.stringify({"version": 999}), "future source appearing after load is preserved on save")
		f.state.coins = 777
		check(f.saves.load_game().is_empty() and f.saves.write_blocked and f.state.coins == 777, "future version in any recovery source blocks partial loading")
		f.saves.start_saving()
		check(not f.saves.save_game(), "future recovery source blocks writes")
		write_text(path, original)
	# Exhaustion fails without changing any valid snapshot.
	newest["revision"] = Schema.MAX_VALUE
	write_text(paths[1], envelope(newest))
	f.saves.load_game()
	f.saves.start_saving()
	check(not f.saves.save_game() and f.saves._read_snapshot(paths[1]).get("revision") == Schema.MAX_VALUE, "revision exhaustion preserves recoverable source")


func test_daily_clock_transitions() -> void:
	var clock := ["2026-11-08"]
	var provider := func() -> String: return clock[0]
	var f := fixture("daily-clock", false, provider)
	f.daily._add_daily(0, 15)
	check(f.state.coins == 75 and f.daily.daily_done[0], "controlled date pays first daily reward once")
	clock[0] = "2026-11-07"
	f.daily._process(10.0)
	f.daily._add_daily(0, 15)
	check(f.daily.day == "2026-11-08" and f.state.coins == 75, "rollback during play preserves paid day and reward")
	check(f.saves.save_game(), "rollback state saves")
	var g := fixture("daily-clock", true, provider)
	g.daily._add_daily(0, 15)
	check(g.daily.day == "2026-11-08" and g.daily.daily_done[0] and g.state.coins == 75, "rollback across restart does not reopen rewards")
	clock[0] = "2026-11-08"
	g.daily._check_day()
	check(g.daily.daily_done[0], "returning to saved date does not reset rewards")
	clock[0] = "2026-11-09"
	g.daily._process(10.0)
	check(g.daily.daily_progress == [0, 0, 0] and g.daily.daily_done == [false, false, false], "next calendar day resets all daily progress")
	g.daily._add_daily(0, 15)
	g.daily._add_daily(0, 15)
	check(g.state.coins == 150, "next day pays exactly one additional reward")
	clock[0] = "2026-12-01"
	g.daily._check_day()
	check(g.state.coins == 150 and g.daily.daily_progress == [0, 0, 0], "skipped days do not award unearned catch-up rewards")
	check(g.saves.save_game(), "forward date saves its high-water mark")
	clock[0] = "2026-11-09"
	var h := fixture("daily-clock", true, provider)
	check(h.daily.day == "2026-12-01", "restart retains future day until device calendar catches up")


func test_migration_and_autosave() -> void:
	var f := fixture("legacy")
	f.state.coins = 321
	f.quests.progress[0] = 6
	var legacy: Dictionary = f.saves.get_save_data()
	legacy["version"] = 1
	legacy.erase("player_fish_caught")
	legacy.erase("worker_fish_caught")
	legacy["daily"]["fish_total"] = 123
	write_text(f.saves.save_path, JSON.stringify(legacy))
	var g := fixture("legacy", true)
	check(g.state.coins == 321 and g.quests.progress[0] == 6, "version 1 migrates money and quest progress")
	check(g.state.player_fish_caught == 0 and g.state.worker_fish_caught == 0, "ambiguous legacy catches are not attributed to the player")
	check(g.saves.save_game(), "migrated save writes current version")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.saves.save_path))
	check(migrated["version"] == Saves.SAVE_VERSION and migrated.has("checksum"), "migration adds current version and checksum envelope")
	var auto := fixture("autosave")
	var writes := [0]
	auto.saves.saved.connect(func(): writes[0] += 1)
	auto.state.coins = 10
	for _request in range(20):
		auto.saves.request_save()
	auto.saves._process(1.0)
	check(writes[0] == 1, "checkpoint requests coalesce into one committed snapshot")
	auto.state.coins = 20
	auto.saves.request_save()
	auto.saves._process(1.0)
	check(writes[0] == 1, "checkpoints respect minimum write interval")
	auto.saves._process(4.0)
	check(writes[0] == 2, "queued checkpoint eventually commits")
	auto.state.coins = 30
	auto.saves._process(30.0)
	check(writes[0] == 3, "periodic autosave commits changes without a checkpoint event")
	auto.state.coins = 40
	auto.saves._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(writes[0] == 4, "application pause saves immediately")
	auto.saves._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(writes[0] == 4, "duplicate lifecycle notifications do not rewrite identical snapshots")


func settle() -> void:
	for _frame in range(3):
		await process_frame


func test_purchase_zones_after_load() -> void:
	for kind in ["hire", "upgrade", "expansion"]:
		var data := fixture("zone-" + kind)
		data.state.coins = 600
		data.quests.completed.assign([true, true, true])
		data.quests.progress.assign([10, 5, 3])
		data.daily.achievement_done.assign([true, true, true])
		var target: Vector3 = State.HIRE_POSITIONS[0] if kind == "hire" else (State.UPGRADE_POSITIONS[0] if kind == "upgrade" else State.EXPANSION_POSITIONS[0])
		data.player.position = target + Vector3(0, 0.5, 0)
		check(data.saves.save_game(), "zone fixture saves")
		var scene = load("res://scenes/main.tscn").instantiate()
		scene.save_path = data.saves.save_path
		root.add_child(scene)
		fixtures.append(scene)
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		scene.save_manager.ready_to_save = false
		scene.player._check_hire_zones()
		scene.upgrade_manager._process(0.0)
		scene.expansion_manager._process(0.0)
		check(scene.state.coins == 600, "loading inside " + kind + " zone does not buy again")
		check(scene.state.hired == [0, 0, 0, 0] and scene.state.upgrade_levels == [1, 1, 1, 1] and scene.state.expansion_levels == [1, 1, 0], "restored zone does not alter purchases")
		scene.player.position = Vector3(0, 0.5, 15)
		scene.player._check_hire_zones()
		scene.upgrade_manager._process(0.0)
		scene.expansion_manager._process(0.0)
		scene.player.position = target + Vector3(0, 0.5, 0)
		scene.player._check_hire_zones()
		scene.upgrade_manager._process(0.0)
		scene.expansion_manager._process(0.0)
		check(scene.state.coins < 600, "leaving and reentering " + kind + " zone still buys")


func test_input_and_windows() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = artifacts.path_join("integration.json")
	root.add_child(scene)
	fixtures.append(scene)
	scene.save_manager.ready_to_save = false
	for node in [scene.state, scene.workers, scene.player, scene.boats, scene.customer_manager]:
		node.set_process(false)
	await settle()
	var joystick = scene.mobile_controls.joystick
	var initial_zoom: float = scene.player.camera_zoom_target
	scene.mobile_controls._zoom(-3.0)
	check(scene.player.camera_zoom_target == initial_zoom - 3.0, "touch zoom control brings camera closer")
	scene.mobile_controls._zoom(3.0)
	check(scene.player.camera_zoom_target == initial_zoom, "touch zoom control moves camera away")
	scene.player.fishing = true
	scene.player.timer = 2.9
	scene.player._process(0.2)
	check(scene.state.player_fish == 1 and scene.state.player_fish_caught == 1, "actual player fishing increments personal inventory and catch total")
	check(scene.quest_manager.progress[0] == 1 and scene.daily_manager.daily_progress[0] == 1, "actual player catch advances personal quests")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(160, 360)
	touch.index = 0
	touch.pressed = true
	root.push_input(touch, true)
	await settle()
	check(joystick.visible and joystick.touch_id == 0, "unhandled touch creates floating joystick")
	check((joystick.position + joystick.size * 0.5).is_equal_approx(touch.position), "joystick is centered at the touch")
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(80, 0)
	drag.index = 1
	root.push_input(drag, true)
	check(joystick.get_direction() == Vector2.ZERO, "second finger cannot steer active joystick")
	drag.index = 0
	root.push_input(drag, true)
	check(scene.player.mobile_input.x > 0.9, "active finger updates player input immediately")
	joystick._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not joystick.visible and scene.player.mobile_input == Vector2.ZERO, "focus loss releases player input immediately")
	var synthetic := InputEventMouseButton.new()
	synthetic.device = InputEvent.DEVICE_ID_EMULATION
	synthetic.position = touch.position
	synthetic.button_index = MOUSE_BUTTON_LEFT
	synthetic.pressed = true
	joystick._unhandled_input(synthetic)
	check(not joystick.visible, "emulated mouse cannot restart a released touch gesture")
	joystick._unhandled_input(touch)
	touch.canceled = true
	joystick._input(touch)
	check(not joystick.visible, "canceled touch releases joystick")
	touch.canceled = false
	joystick._unhandled_input(touch)
	scene.ui._open_menu()
	check(not joystick.visible and not joystick.enabled and scene.state.controls_blocked, "menu opening blocks movement and joystick")
	check(not scene.mobile_controls.zoom_controls.visible, "modal hides camera controls")
	scene.quest_ui._open()
	check(not scene.ui.overlay.visible and scene.quest_ui.overlay.visible, "quest window closes competing menu")
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.quest_ui.overlay.visible and joystick.enabled and not scene.state.controls_blocked, "Android Back closes window and restores controls")
	var mouse := InputEventMouseButton.new()
	mouse.position = scene.ui.menu_button.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse, true)
	check(not joystick.visible, "GUI button press does not start joystick")
	mouse.pressed = false
	root.push_input(mouse, true)
	await settle()
	check(scene.ui.overlay.visible, "GUI button still opens its menu")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape, true)
	check(not scene.ui.overlay.visible and not scene.state.controls_blocked, "Escape closes modal and unblocks controls")
	for viewport_size in [Vector2i(320, 568), Vector2i(360, 640), Vector2i(480, 1067),
			Vector2i(720, 1280), Vector2i(800, 1280), Vector2i(1024, 768), Vector2i(1280, 720)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await settle()
		scene.ui._resize()
		scene.quest_ui._resize()
		await settle()
		check(not scene.ui.top_panel.get_global_rect().intersects(scene.ui.menu_button.get_global_rect()), "HUD has no overlapping buttons at %s" % viewport_size)
		check(scene.ui.menu_button.size.y >= 64 and scene.quest_ui.open_button.size.y >= 64, "main buttons have large touch targets")
		check(not scene.ui.menu_button.get_global_rect().intersects(scene.quest_ui.open_button.get_global_rect()), "main buttons stay separate")
		scene._position_context_info()
		check(scene.world.info_panel.get_global_rect().end.y <= scene.ui.bottom_panel.get_global_rect().position.y, "context panel stays above HUD")
		scene.player._update_camera(0.0, true)
		check(scene.player.camera.keep_aspect == (Camera3D.KEEP_WIDTH if viewport_size.y > viewport_size.x else Camera3D.KEEP_HEIGHT), "camera preserves short axis on phones")
		for tab in range(4):
			scene.ui._open_menu()
			scene.ui._select_menu(tab)
			await settle()
			check(scene.ui.menu_window.get_global_rect().end.x <= viewport_size.x and scene.ui.menu_window.get_global_rect().end.y <= viewport_size.y, "all menu tabs including development fit viewport")
			if tab == 1:
				var resource_row = scene.ui.menu_content.get_child(0).get_child(0).get_child(1)
				check(resource_row.get_child(1).size.x >= 8.0, "resource counter remains visible at %s" % viewport_size)
			if tab == 3:
				for section in range(4):
					scene.ui._select_development(section)
					await settle()
					check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(scene.ui.menu_window.get_global_rect()), "development section %d fits %s" % [section, viewport_size])
			scene.quest_ui._open()
			scene.quest_ui._select_tab(tab % 3)
			await settle()
			check(scene.quest_ui.window.get_global_rect().end.x <= viewport_size.x, "quest tabs fit viewport width")
			check(scene.quest_ui.window.get_global_rect().end.y <= viewport_size.y, "quest tabs fit viewport height")
			scene.quest_ui._close()
	scene.ui._open_menu()
	scene.state.coins = 1000
	scene.ui._select_menu(3)
	scene.ui._select_development(2)
	var upgrade_level: int = scene.state.upgrade_levels[0]
	var upgrade_price: int = scene.state.upgrade_prices[0]
	for button in scene.ui.menu_content.find_children("*", "Button", true, false):
		if button.text.begins_with("Купить") and not button.disabled:
			button.pressed.emit()
			break
	check(scene.state.upgrade_levels[0] == upgrade_level + 1 and scene.state.coins == 1000 - upgrade_price, "upgrade card uses existing purchase and charges once")
	var coins_before: int = scene.state.coins
	var expansion_level: int = scene.state.expansion_levels[0]
	var expansion_price: int = scene.state.expansion_prices[0]
	scene.ui._upgrade(0, true)
	check(scene.state.expansion_levels[0] == expansion_level + 1 and scene.state.coins == coins_before - expansion_price, "expansion shortcut uses existing purchase")
	scene.ui._select_menu(1)
	scene.ui._open_species()
	check(scene.ui.menu_tab == 3 and scene.ui.development_tab == 1, "inventory shortcut opens special fish stocks")
	var section_selector = scene.ui.menu_content.get_child(0)
	section_selector.show_popup()
	await settle()
	check(section_selector.get_popup().visible and scene.ui._menu_interacting(), "development dropdown stays interactive")
	scene.state.coins += 1
	scene.ui._queue_development_refresh()
	await settle()
	check(is_instance_valid(section_selector) and section_selector.get_popup().visible, "income does not interrupt an open section selector")
	scene.ui._close_menu()
	check(not section_selector.get_popup().visible, "closing business also closes its section selector")
	check(not scene.state.controls_blocked, "repeated window switches leave controls enabled")


func _run() -> void:
	test_visual_resource_reuse()
	test_static_batch_preserves_animation()
	test_harbor_progression_and_save()
	test_harbor_world_interactions()
	test_worker_restoration()
	test_fishing_and_rewards()
	test_daily_achievement_roundtrip()
	test_recovery_and_validation()
	test_stale_pending_recovery()
	test_snapshot_revisions()
	test_daily_clock_transitions()
	test_migration_and_autosave()
	test_purchase_zones_after_load()
	await test_input_and_windows()
	for holder in fixtures:
		holder.free()
	await process_frame
	print("Regression checks: %d, failures: %d" % [checks, failures])
	print("Isolated save fixtures: ", artifacts)
	quit(1 if failures > 0 else 0)
