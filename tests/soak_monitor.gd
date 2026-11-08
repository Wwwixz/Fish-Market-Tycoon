extends Node

# QA-only autoload. The Android driver copies it into an isolated project.
const SAMPLE_PATH := "user://qa_soak_frames.jsonl"
const DONE_PATH := "user://qa_soak_done.json"
var scene: Node
var output: FileAccess
var frames: Array[float] = []
var active_seconds := 0.0
var window_seconds := 0.0
var action_seconds := 0.0
var previous_tick: int = 0
var cycles := 0
var paused := false
var duration := 3600.0
var snapshot_sequence := 0


func _ready() -> void:
	set_process(false)
	call_deferred("_start")


func _start() -> void:
	scene = get_tree().current_scene
	if scene == null:
		call_deferred("_start")
		return
	if FileAccess.file_exists(_done_path()):
		_snapshot()
		return # Cold-reload validation must not seed or alter progress again.
	duration = float(ProjectSettings.get_setting("qa/soak_seconds", 3600.0))
	DisplayServer.screen_set_keep_on(true)
	output = FileAccess.open(SAMPLE_PATH, FileAccess.WRITE)
	if output == null:
		push_error("QA soak: cannot open telemetry")
		return
	# Repeatable busy market: ten workers, production, visitors and boat sales.
	scene.state.coins = 100000
	scene.state.hired.assign([5, 2, 2, 1])
	scene.state.upgrade_levels.assign([3, 3, 3, 3])
	scene.state.fish_box = 300
	scene.state.machine_output = 300
	scene.state.fillet_box = 300
	scene.player.position = Vector3(0, 0.5, 8)
	scene.player._update_camera(0.0, true)
	scene.progression.level = 10
	scene.progression.xp = 0
	var harbor: Node = scene.state.harbor
	harbor.equipment.assign([true, true, true])
	harbor.zone_open = true
	harbor.raw_stock.assign([40, 40, 40])
	harbor.smoked_stock.assign([20, 20, 20])
	harbor.goal_done.assign([true, true, true, true, true])
	harbor.updated.emit()
	scene.quest_manager.progress.assign([10, 5, 3])
	scene.quest_manager.completed.assign([true, true, true])
	scene.daily_manager.achievement_done.assign([true, true, true])
	scene.workers.restore_workers()
	scene.state.changed.emit()
	scene.save_manager.save_game()
	_snapshot()
	previous_tick = Time.get_ticks_usec()
	set_process(true)
	print("QA soak: started, seconds=", duration)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		paused = true
		_snapshot()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		paused = false
		previous_tick = 0 # Exclude the background gap from frame measurements.


func _process(_delta: float) -> void:
	if paused:
		return
	var tick := Time.get_ticks_usec()
	if previous_tick == 0:
		previous_tick = tick
		return
	var seconds := float(tick - previous_tick) / 1000000.0
	previous_tick = tick
	active_seconds += seconds
	window_seconds += seconds
	action_seconds += seconds
	frames.append(seconds * 1000.0)
	if action_seconds >= 20.0:
		action_seconds = 0.0
		_cycle_ui()
	if window_seconds >= 60.0 or active_seconds >= duration:
		_sample()
	if active_seconds >= duration:
		scene.ui._close_menu()
		scene.quest_ui._close()
		scene.save_manager.save_game()
		var done := {"active_seconds": active_seconds, "cycles": cycles,
			"revision": scene.save_manager.get_save_data()["revision"]}
		var file := FileAccess.open(_done_path(), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(done))
			file.close()
		print("QA soak done: ", JSON.stringify(done))
		_snapshot()
		output.close()
		set_process(false)
		print("QA soak: complete")


func _done_path() -> String:
	return "user://" + str(ProjectSettings.get_setting("qa/soak_marker", "qa_soak_done.json"))


func _snapshot() -> void:
	if is_instance_valid(scene) and is_instance_valid(scene.save_manager):
		if scene.save_manager.save_game():
			var encoded := Marshalls.utf8_to_base64(FileAccess.get_file_as_string(scene.save_manager.save_path))
			snapshot_sequence += 1
			var token := "%d-%d" % [Time.get_ticks_msec(), snapshot_sequence]
			var count := int(ceil(encoded.length() / 700.0))
			for i in range(count):
				print("QA snapshot chunk: %s:%d:%d:%s" % [token, i, count, encoded.substr(i * 700, 700)])
			print("QA snapshot end: ", token)


func _cycle_ui() -> void:
	cycles += 1
	match cycles % 4:
		0:
			scene.ui._close_menu()
			scene.quest_ui._close()
		1:
			scene.ui._open_menu()
			scene.ui._select_menu((cycles / 4) as int % 4)
		2:
			scene.quest_ui._open()
			scene.quest_ui._select_tab((cycles / 4) as int % 3)
		3:
			scene.quest_ui._close()
			scene.player.camera_zoom_target = 20.0 if cycles % 8 == 3 else 26.0
	# QA route transitions exercise real production handlers, not simulated rewards.
	var route := [Vector3(-8, 0.5, -9), Vector3(-5, 0.5, -5),
		Vector3(5, 0.5, 5.6), Vector3(9, 0.5, -5), Vector3(9, 0.5, -9)]
	if not scene.state.controls_blocked:
		scene.player.position = route[cycles % route.size()]


func _sample() -> void:
	frames.sort()
	var slow := 0
	for ms in frames:
		if ms > 1000.0 / 30.0:
			slow += 1
	var sample := {
		"debug_build": OS.is_debug_build(), "render_scale": get_viewport().scaling_3d_scale,
		"active_seconds": active_seconds, "window_seconds": window_seconds,
		"frames": frames.size(), "fps": frames.size() / window_seconds,
		"frame_p95_ms": frames[mini(frames.size() - 1, int(ceil(frames.size() * 0.95)) - 1)],
		"frame_p99_ms": frames[mini(frames.size() - 1, int(ceil(frames.size() * 0.99)) - 1)],
		"slow_frame_fraction": float(slow) / frames.size(),
		"engine_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"cycles": cycles, "workers": scene.workers.workers.size(),
		"coins": scene.state.coins, "customers_served": scene.state.customers_served,
		"boat_sales": scene.state.served, "revision": scene.save_manager.get_save_data()["revision"]
	}
	output.store_line(JSON.stringify(sample))
	output.flush()
	print("QA soak sample: ", JSON.stringify(sample))
	frames.clear()
	window_seconds = 0.0
