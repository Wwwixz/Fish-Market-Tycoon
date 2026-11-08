extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Workers = preload("res://scripts/worker_manager.gd")
const Progression = preload("res://scripts/progression_manager.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Daily = preload("res://scripts/daily_manager.gd")
const Saves = preload("res://scripts/save_manager.gd")
const Schema = preload("res://scripts/save_schema.gd")

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
	return JSON.stringify({"version": 2, "payload": payload, "checksum": payload.sha256_text()})


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
	var newer := envelope(f.saves.get_save_data())
	write_text(f.saves.save_path, newer)
	write_text(f.saves.save_path + ".tmp", older)
	write_text(f.saves.save_path + ".bak", newer)
	check(not f.saves.load_game().is_empty() and f.state.coins == 200, "healthy primary takes priority over stale pending snapshot")
	check(f.saves.recovery_notice.is_empty(), "healthy primary does not report recovery")
	write_text(f.saves.save_path, "{corrupt-newer-primary")
	var g := fixture("stale-pending", true)
	check(g.state.coins == 100 and g.daily.daily_progress == [7, 2, 1], "corrupt primary recovers internally consistent older pending progress")
	check(not g.saves.write_blocked and not g.saves.recovery_notice.is_empty(), "older pending recovery is reported and allows saving")
	check(FileAccess.get_file_as_string(g.saves.save_path + ".tmp") == older, "loading does not modify the recovery source")
	check(g.saves.save_game(), "older recovered progress can replace corrupt primary")
	check(not FileAccess.file_exists(g.saves.save_path + ".tmp"), "successful recovery save commits pending file")
	check(FileAccess.get_file_as_string(g.saves.save_path + ".bak") == newer, "saving recovered progress preserves a healthy existing backup")
	var h := fixture("stale-pending", true)
	check(h.state.coins == 100 and h.daily.daily_progress == [7, 2, 1], "second launch keeps recovered progress without reward duplication")
	write_text(h.saves.save_path, "{broken")
	write_text(h.saves.save_path + ".tmp", "{incomplete")
	check(not h.saves.load_game().is_empty() and h.state.coins == 200, "invalid pending snapshot falls through to healthy backup")


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
	check(g.saves.save_game(), "migrated save writes version 2")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(g.saves.save_path))
	check(migrated["version"] == 2 and migrated.has("checksum"), "migration adds version and checksum envelope")
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
		for tab in range(3):
			scene.ui._open_menu()
			scene.ui._select_menu(tab)
			scene.quest_ui._open()
			scene.quest_ui._select_tab(tab)
			await settle()
			check(scene.quest_ui.window.get_global_rect().end.x <= viewport_size.x, "quest tabs fit viewport width")
			check(scene.quest_ui.window.get_global_rect().end.y <= viewport_size.y, "quest tabs fit viewport height")
			scene.quest_ui._close()
	check(not scene.state.controls_blocked, "repeated window switches leave controls enabled")


func _run() -> void:
	test_worker_restoration()
	test_fishing_and_rewards()
	test_daily_achievement_roundtrip()
	test_recovery_and_validation()
	test_stale_pending_recovery()
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
