
extends Node

signal saved
signal loaded
signal save_failed(message: String)

const SAVE_PATH := "user://fish_market_save.json"
const AUTO_SAVE_INTERVAL := 30.0
const SAVE_VERSION := 1

var state: Node
var player: Node3D
var workers: Node3D

var elapsed: float = 0.0
var ready_to_save: bool = false

func setup(
	game_state: Node,
	game_player: Node3D,
	worker_manager: Node3D
) -> void:
	state = game_state
	player = game_player
	workers = worker_manager

func _process(delta: float) -> void:
	if not ready_to_save:
		return

	elapsed += delta

	if elapsed >= AUTO_SAVE_INTERVAL:
		elapsed = 0.0
		save_game()

func _notification(what: int) -> void:
	if not ready_to_save:
		return

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

	elif what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func _restore_int_array(
	key: String,
	data: Dictionary,
	target: Array[int],
	minimum: int = 0
) -> void:
	var raw: Variant = data.get(key, null)

	if not raw is Array:
		return

	if raw.size() != target.size():
		return

	for i in range(target.size()):
		target[i] = maxi(
			minimum,
			int(raw[i])
		)

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		save_failed.emit("Не удалось открыть сохранение")
		return {}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)

	file.close()

	if not parsed is Dictionary:
		save_failed.emit("Сохранение повреждено")
		return {}

	var data: Dictionary = parsed

	if int(data.get("version", 0)) != SAVE_VERSION:
		save_failed.emit("Неизвестная версия сохранения")
		return {}

	state.coins = maxi(
		0, int(data.get("coins", 0))
	)

	state.player_fish = maxi(
		0, int(data.get("player_fish", 0))
	)

	state.player_fillets = maxi(
		0, int(data.get("player_fillets", 0))
	)

	state.fish_box = maxi(
		0, int(data.get("fish_box", 0))
	)

	state.machine_input = maxi(
		0, int(data.get("machine_input", 0))
	)

	state.machine_output = maxi(
		0, int(data.get("machine_output", 0))
	)

	state.fillet_box = maxi(
		0, int(data.get("fillet_box", 0))
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
		0, int(data.get("boat_order", 0))
	)

	state.boat_time = maxf(
		0.0,
		float(data.get("boat_time", 0.0))
	)

	state.served = maxi(
		0, int(data.get("served", 0))
	)

	state.customers_served = maxi(
		0, int(data.get("customers_served", 0))
	)

	state.customers_lost = maxi(
		0, int(data.get("customers_lost", 0))
	)

	state.market_queue = 0

	var hired_values: Array[int] = state.hired
	var price_values: Array[int] = state.prices
	var upgrade_level_values: Array[int] = state.upgrade_levels
	var upgrade_price_values: Array[int] = state.upgrade_prices
	var expansion_level_values: Array[int] = state.expansion_levels
	var expansion_price_values: Array[int] = state.expansion_prices

	_restore_int_array(
		"hired", data, hired_values
	)

	_restore_int_array(
		"prices", data, price_values, 1
	)

	_restore_int_array(
		"upgrade_levels", data,
		upgrade_level_values, 1
	)

	_restore_int_array(
		"upgrade_prices", data,
		upgrade_price_values, 1
	)

	_restore_int_array(
		"expansion_levels", data,
		expansion_level_values
	)

	_restore_int_array(
		"expansion_prices", data,
		expansion_price_values, 1
	)

	var position_data: Variant = data.get(
		"player_position",
		[0.0, 0.5, 8.0]
	)

	if position_data is Array:
		if position_data.size() == 3:
			player.position = Vector3(
				float(position_data[0]),
				float(position_data[1]),
				float(position_data[2])
			)

	loaded.emit()
	return data

func save_game() -> void:
	if state == null or player == null:
		return

	var data: Dictionary = {
		"version": SAVE_VERSION,
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
		"upgrade_levels": state.upgrade_levels.duplicate(),
		"upgrade_prices": state.upgrade_prices.duplicate(),
		"expansion_levels": state.expansion_levels.duplicate(),
		"expansion_prices": state.expansion_prices.duplicate(),
		"player_position": [
			player.position.x,
			player.position.y,
			player.position.z
		]
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		save_failed.emit("Ошибка записи сохранения")
		return

	file.store_string(
		JSON.stringify(data, "\t")
	)

	file.close()
	saved.emit()
