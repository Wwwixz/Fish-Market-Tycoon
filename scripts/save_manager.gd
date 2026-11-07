extends Node

signal saved
signal loaded
signal save_failed(message: String)

const Schema = preload("res://scripts/save_schema.gd")
const SAVE_PATH := "user://fish_market_save.json"
const AUTO_SAVE_INTERVAL := 30.0
const SAVE_VERSION := 2
const MIN_CHECKPOINT_INTERVAL := 5.0
const CHECKPOINT_DELAY := 0.75
const MAX_SAVE_BYTES := 2 * 1024 * 1024

# Overridable for isolated regression tests, never change the production path there.
var save_path: String = SAVE_PATH
var state: Node
var player: Node3D
var workers: Node3D
var progression: Node
var quest_manager: Node
var daily_manager: Node
var elapsed: float = 0.0
var ready_to_save: bool = false
var write_blocked: bool = false
var last_error: String = ""
var recovery_notice: String = ""
var _checkpoint_delay: float = -1.0
var _since_last_save: float = MIN_CHECKPOINT_INTERVAL
var _last_hash: String = ""
var _saving: bool = false


func setup(game_state: Node, game_player: Node3D, worker_manager: Node3D) -> void:
	state = game_state
	player = game_player
	workers = worker_manager


func _ready() -> void:
	if state != null:
		for event in ["worker_hired", "upgrade_purchased", "expansion_purchased", "sale_completed", "customer_sale_completed"]:
			state.connect(event, request_save)
	if quest_manager != null:
		quest_manager.quests_updated.connect(request_save)
	if daily_manager != null:
		daily_manager.updated.connect(request_save)
	if progression != null:
		progression.level_up.connect(request_save)


func start_saving() -> void:
	ready_to_save = true
	request_save()


# Signals can supply up to two arguments; capture only after their transaction ends.
func request_save(_first: Variant = null, _second: Variant = null) -> void:
	if ready_to_save and not write_blocked and _checkpoint_delay < 0.0:
		_checkpoint_delay = CHECKPOINT_DELAY


func _process(delta: float) -> void:
	if not ready_to_save or write_blocked:
		return
	elapsed += delta
	_since_last_save += delta
	if _checkpoint_delay >= 0.0:
		_checkpoint_delay = maxf(0.0, _checkpoint_delay - delta)
	if elapsed >= AUTO_SAVE_INTERVAL or (_checkpoint_delay == 0.0 and _since_last_save >= MIN_CHECKPOINT_INTERVAL):
		elapsed = 0.0
		_checkpoint_delay = -1.0
		if not save_game():
			# Retry at a bounded rate, rather than writing or reporting errors every frame.
			_since_last_save = 0.0
			_checkpoint_delay = CHECKPOINT_DELAY


func _notification(what: int) -> void:
	if ready_to_save and what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save_game()


func _fail(message: String) -> bool:
	last_error = message
	save_failed.emit(message)
	return false


func _read_snapshot(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	if not Schema.number(parsed.get("version"), 1, 1_000_000, true):
		return {}
	var version := int(parsed["version"])
	if version > SAVE_VERSION:
		return {"newer_version": true}
	var data: Dictionary = parsed
	if version == SAVE_VERSION:
		var payload: Variant = parsed.get("payload")
		var checksum: Variant = parsed.get("checksum")
		if not payload is String or not checksum is String or payload.sha256_text() != checksum:
			return {}
		if parser.parse(payload) != OK:
			return {}
		var decoded: Variant = parser.data
		if not decoded is Dictionary or not Schema.number(decoded.get("version"), SAVE_VERSION, SAVE_VERSION, true):
			return {}
		data = decoded
	if not Schema.valid(data):
		return {}
	return {"data": data, "checksum": parsed.get("checksum", "")}


func load_game() -> Dictionary:
	ready_to_save = false
	last_error = ""
	recovery_notice = ""
	write_blocked = false
	_last_hash = ""
	var found_file := false
	# A fully written pending snapshot can survive a crash before its final rename.
	for path in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		found_file = true
		var snapshot := _read_snapshot(path)
		if snapshot.get("newer_version", false):
			write_blocked = true
			_fail("Сохранение от более новой версии игры. Автосохранение отключено.")
			return {}
		if not snapshot.has("data"):
			continue
		var data: Dictionary = snapshot["data"]
		_apply_data(data)
		if workers != null:
			workers.restore_workers()
		if path != save_path:
			recovery_notice = "Прогресс восстановлен из резервной копии"
		loaded.emit()
		return data
	if found_file:
		write_blocked = true
		_fail("Файлы сохранения повреждены. Автосохранение отключено, исходные файлы сохранены.")
	return {}


func _restore_int_array(key: String, data: Dictionary, target: Array[int], minimum: int = 0) -> void:
	var raw: Variant = data.get(key, [])
	if raw is Array and raw.size() == target.size():
		for i in range(target.size()):
			target[i] = maxi(minimum, int(raw[i]))


func _apply_data(data: Dictionary) -> void:
	state.coins = maxi(
		0,
		int(data.get("coins", 0))
	)

	state.player_fish = maxi(
		0,
		int(data.get("player_fish", 0))
	)

	state.player_fillets = maxi(
		0,
		int(data.get("player_fillets", 0))
	)

	state.fish_box = maxi(
		0,
		int(data.get("fish_box", 0))
	)

	state.machine_input = maxi(
		0,
		int(data.get("machine_input", 0))
	)

	state.machine_output = maxi(
		0,
		int(data.get("machine_output", 0))
	)

	state.fillet_box = maxi(
		0,
		int(data.get("fillet_box", 0))
	)

	state.processing = bool(
		data.get("processing", false)
	)

	state.process_timer = maxf(
		0.0,
		float(data.get("process_timer", 0.0))
	)

	state.boat_state = str(
		data.get("boat_state", "none")
	)

	state.boat_order = maxi(
		0,
		int(data.get("boat_order", 0))
	)

	state.boat_time = maxf(
		0.0,
		float(data.get("boat_time", 0.0))
	)

	state.served = maxi(
		0,
		int(data.get("served", 0))
	)

	state.customers_served = maxi(
		0,
		int(data.get("customers_served", 0))
	)

	state.customers_lost = maxi(
		0,
		int(data.get("customers_lost", 0))
	)

	state.market_queue = 0
	state.player_fish_caught = int(data.get("player_fish_caught", 0))
	state.worker_fish_caught = int(data.get("worker_fish_caught", 0))

	var hired_values: Array[int] = state.hired
	var price_values: Array[int] = state.prices

	var upgrade_level_values: Array[int] = (
		state.upgrade_levels
	)

	var upgrade_price_values: Array[int] = (
		state.upgrade_prices
	)

	var expansion_level_values: Array[int] = (
		state.expansion_levels
	)

	var expansion_price_values: Array[int] = (
		state.expansion_prices
	)

	_restore_int_array(
		"hired",
		data,
		hired_values
	)

	_restore_int_array(
		"prices",
		data,
		price_values,
		1
	)

	_restore_int_array(
		"upgrade_levels",
		data,
		upgrade_level_values,
		1
	)

	_restore_int_array(
		"upgrade_prices",
		data,
		upgrade_price_values,
		1
	)

	_restore_int_array(
		"expansion_levels",
		data,
		expansion_level_values
	)

	_restore_int_array(
		"expansion_prices",
		data,
		expansion_price_values,
		1
	)

	var position_data: Variant = data.get(
		"player_position",
		[0.0, 0.5, 8.0]
	)

	if (
		position_data is Array
		and position_data.size() == 3
	):
		player.position = Vector3(
			float(position_data[0]),
			float(position_data[1]),
			float(position_data[2])
		)

	if progression != null:
		var progression_data: Variant = data.get(
			"progression",
			{}
		)

		if progression_data is Dictionary:
			progression.call(
				"load_save_data",
				progression_data
			)

	if quest_manager != null:
		var quest_data: Variant = data.get(
			"quests",
			{}
		)

		if quest_data is Dictionary:
			quest_manager.call(
				"load_save_data",
				quest_data
			)

	if daily_manager != null:
		var daily_data: Variant = data.get(
			"daily",
			{}
		)

		if daily_data is Dictionary:
			daily_manager.call(
				"load_save_data",
				daily_data
			)



func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"player_fish_caught": state.player_fish_caught,
		"worker_fish_caught": state.worker_fish_caught,

		"coins": state.coins,
		"player_fish": state.player_fish,
		"player_fillets": state.player_fillets,

		"fish_box": state.fish_box,
		"machine_input": state.machine_input,
		"machine_output": state.machine_output,
		"fillet_box": state.fillet_box,

		"processing": state.processing,
		"process_timer": state.process_timer,

		"boat_state": state.boat_state,
		"boat_order": state.boat_order,
		"boat_time": state.boat_time,
		"served": state.served,

		"customers_served": state.customers_served,
		"customers_lost": state.customers_lost,

		"hired": state.hired.duplicate(),
		"prices": state.prices.duplicate(),

		"upgrade_levels": (
			state.upgrade_levels.duplicate()
		),

		"upgrade_prices": (
			state.upgrade_prices.duplicate()
		),

		"expansion_levels": (
			state.expansion_levels.duplicate()
		),

		"expansion_prices": (
			state.expansion_prices.duplicate()
		),

		"player_position": [
			player.position.x,
			player.position.y,
			player.position.z
		]
	}

	if progression != null:
		data["progression"] = progression.call(
			"get_save_data"
		)

	if quest_manager != null:
		data["quests"] = quest_manager.call(
			"get_save_data"
		)

	if daily_manager != null:
		data["daily"] = daily_manager.call(
			"get_save_data"
		)

	if workers != null:
		var cargo: Dictionary = workers.get_carried_resources()
		data["fish_box"] += int(cargo["fish"])
		data["machine_output"] += int(cargo["fillets"])
	return data


func save_game() -> bool:
	if not ready_to_save or write_blocked or _saving or state == null or player == null:
		return false
	_saving = true
	var result := _write_snapshot()
	_saving = false
	return result


func _write_snapshot() -> bool:
	var data := get_save_data()
	if not Schema.valid(data):
		return _fail("Не удалось проверить прогресс. Предыдущее сохранение сохранено.")
	var payload := JSON.stringify(data)
	var checksum := payload.sha256_text()
	var primary := _read_snapshot(save_path) if FileAccess.file_exists(save_path) else {}
	if primary.get("newer_version", false):
		write_blocked = true
		return _fail("Сохранение от более новой версии игры. Автосохранение отключено.")
	if checksum == _last_hash and primary.get("checksum", "") == checksum:
		_checkpoint_delay = -1.0
		elapsed = 0.0
		return true
	var pending := save_path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return _fail("Не удалось открыть временный файл сохранения")
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "payload": payload, "checksum": checksum}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not _read_snapshot(pending).has("data"):
		return _fail("Ошибка проверки записи. Предыдущее сохранение сохранено.")
	var backup := save_path + ".bak"
	# Never rotate a corrupt primary over a healthy backup.
	if primary.has("data") or not _read_snapshot(backup).has("data"):
		var source := save_path if primary.has("data") else pending
		var backup_pending := backup + ".tmp"
		if DirAccess.copy_absolute(source, backup_pending) != OK:
			return _fail("Не удалось записать резервную копию. Предыдущее сохранение сохранено.")
		if not _read_snapshot(backup_pending).has("data") or DirAccess.rename_absolute(backup_pending, backup) != OK:
			return _fail("Не удалось обновить резервную копию. Предыдущее сохранение сохранено.")
	if DirAccess.rename_absolute(pending, save_path) != OK:
		return _fail("Не удалось обновить сохранение. Копия для восстановления сохранена.")
	_last_hash = checksum
	last_error = ""
	elapsed = 0.0
	_since_last_save = 0.0
	_checkpoint_delay = -1.0
	saved.emit()
	return true
