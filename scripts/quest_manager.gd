
extends Node

signal quests_updated

const QUESTS := [
	{
		"title": "Первый улов",
		"description": "Поймай 10 рыб",
		"target": 10,
		"reward": 50
	},
	{
		"title": "Успешный торговец",
		"description": "Обслужи 5 покупателей",
		"target": 5,
		"reward": 100
	},
	{
		"title": "Собственная команда",
		"description": "Найми 3 работников",
		"target": 3,
		"reward": 150
	}
]

var state: Node
var progress: Array[int] = [0, 0, 0]
var completed: Array[bool] = [false, false, false]
var initialized: bool = false
var loading: bool = true


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	if state == null:
		return

	state.fish_caught.connect(_on_fish_caught)
	state.customer_sale_completed.connect(_on_customer_sale)
	state.changed.connect(_on_state_changed)

	initialized = true


func finish_loading() -> void:
	loading = false
	_update_workers()
	quests_updated.emit()


func _on_fish_caught(amount: int, by_player: bool) -> void:
	if not loading and by_player:
		_add_progress(0, amount)


func _on_customer_sale(
	_earned: int,
	_fillets: int
) -> void:
	_add_progress(1, 1)


func _on_state_changed() -> void:
	_update_workers()


func _update_workers() -> void:
	if state == null:
		return

	var total: int = 0

	for count in state.hired:
		total += int(count)

	_set_progress(2, total)


func _add_progress(index: int, amount: int) -> void:
	if loading or completed[index] or amount <= 0:
		return

	_set_progress(index, progress[index] + amount)


func _set_progress(index: int, amount: int) -> void:
	if loading or completed[index]:
		return

	var target: int = int(QUESTS[index]["target"])
	var new_progress: int = clampi(amount, 0, target)

	if progress[index] == new_progress:
		return

	progress[index] = new_progress
	if progress[index] >= target:
		_complete(index)
	else:
		quests_updated.emit()


func _complete(index: int) -> void:
	if completed[index]:
		return

	completed[index] = true

	var quest: Dictionary = QUESTS[index]
	var bonus: int = int(quest["reward"])

	state.coins += bonus

	state.notice.emit(
		"Задание выполнено: %s! +%d монет" %
		[String(quest["title"]), bonus]
	)

	state.reward.emit(
		bonus,
		"🪙",
		Color("#E9C77C"),
		Vector3(0, 1.0, 0)
	)

	quests_updated.emit()
	state.changed.emit()


func get_quest_text(index: int) -> String:
	if index < 0 or index >= QUESTS.size():
		return ""

	var quest: Dictionary = QUESTS[index]

	if completed[index]:
		return "%s — ВЫПОЛНЕНО" % String(quest["title"])

	return "%s: %d/%d" % [
		String(quest["title"]),
		progress[index],
		int(quest["target"])
	]


func get_save_data() -> Dictionary:
	return {
		"progress": progress.duplicate(),
		"completed": completed.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	loading = true
	progress = [0, 0, 0]
	completed = [false, false, false]
	var saved_progress: Variant = data.get("progress", [])
	var saved_completed: Variant = data.get("completed", [])

	if saved_progress is Array:
		if saved_progress.size() == QUESTS.size():
			for i in range(QUESTS.size()):
				progress[i] = clampi(
					int(saved_progress[i]),
					0,
					int(QUESTS[i]["target"])
				)

	if saved_completed is Array:
		if saved_completed.size() == QUESTS.size():
			for i in range(QUESTS.size()):
				completed[i] = bool(saved_completed[i])

	for i in range(QUESTS.size()):
		# Old snapshots could be taken between progress and reward notifications.
		completed[i] = completed[i] or progress[i] >= int(QUESTS[i]["target"])
		if completed[i]:
			progress[i] = int(QUESTS[i]["target"])

	quests_updated.emit()
