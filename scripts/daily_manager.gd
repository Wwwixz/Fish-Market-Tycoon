
extends Node

signal updated

const DAILY := [
	{"title": "Рыбный день", "target": 15, "reward": 75},
	{"title": "Постоянные клиенты", "target": 5, "reward": 100},
	{"title": "Морские поставки", "target": 3, "reward": 125}
]

const ACHIEVEMENTS := [
	{"title": "Первые 10 покупателей", "target": 10, "reward": 200},
	{"title": "25 морских заказов", "target": 25, "reward": 350},
	{"title": "Команда из 5 работников", "target": 5, "reward": 500}
]

var state: Node
var day: String = ""
var daily_progress: Array[int] = [0, 0, 0]
var daily_done: Array[bool] = [false, false, false]
var achievement_done: Array[bool] = [false, false, false]
var day_timer: float = 0.0
var loading: bool = true


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	day = Time.get_date_string_from_system()

	if state == null:
		return

	state.fish_caught.connect(_on_fish_caught)
	state.customer_sale_completed.connect(_on_customer_sale)
	state.sale_completed.connect(_on_boat_sale)
	state.changed.connect(_check_achievements)


func finish_loading() -> void:
	loading = false
	_check_day()
	_check_achievements()
	updated.emit()


func _process(delta: float) -> void:
	if loading:
		return

	day_timer += delta

	if day_timer >= 10.0:
		day_timer = 0.0
		_check_day()


func _check_day() -> void:
	var today: String = Time.get_date_string_from_system()

	# Moving the clock backwards must not make the same rewards available again.
	if today <= day:
		return

	day = today
	daily_progress = [0, 0, 0]
	daily_done = [false, false, false]
	updated.emit()


func _on_fish_caught(amount: int, by_player: bool) -> void:
	if not loading and by_player:
		_add_daily(0, amount)


func _on_customer_sale(
	_earned: int,
	_fillets: int
) -> void:
	if loading:
		return

	_add_daily(1, 1)
	_check_achievements()


func _on_boat_sale(
	_earned: int,
	_fillets: int
) -> void:
	if loading:
		return

	_add_daily(2, 1)
	_check_achievements()


func _add_daily(index: int, amount: int) -> void:
	if loading or amount <= 0:
		return
	_check_day()

	if daily_done[index]:
		return

	var target: int = int(DAILY[index]["target"])

	daily_progress[index] = mini(
		target,
		daily_progress[index] + amount
	)

	if daily_progress[index] >= target:
		daily_done[index] = true
		_pay(
			String(DAILY[index]["title"]),
			int(DAILY[index]["reward"])
		)

	updated.emit()


func _check_achievements() -> void:
	if loading or state == null:
		return

	var total_workers: int = 0

	for amount in state.hired:
		total_workers += int(amount)

	var values: Array[int] = [
		int(state.customers_served),
		int(state.served),
		total_workers
	]

	for i in range(ACHIEVEMENTS.size()):
		if achievement_done[i]:
			continue

		if values[i] >= int(ACHIEVEMENTS[i]["target"]):
			achievement_done[i] = true
			_pay(
				String(ACHIEVEMENTS[i]["title"]),
				int(ACHIEVEMENTS[i]["reward"])
			)
			updated.emit()


func _pay(title: String, amount: int) -> void:
	state.coins += amount

	state.notice.emit(
		"%s выполнено! +%d монет" % [title, amount]
	)

	state.reward.emit(
		amount,
		"🪙",
		Color("#E4BE79"),
		Vector3(0, 1, 0)
	)

	state.changed.emit()


func get_achievement_progress(index: int) -> int:
	match index:
		0:
			return int(state.customers_served)
		1:
			return int(state.served)
		2:
			var total: int = 0
			for amount in state.hired:
				total += int(amount)
			return total

	return 0


func get_save_data() -> Dictionary:
	if not loading:
		_check_day()
	return {
		"day": day,
		"daily_progress": daily_progress.duplicate(),
		"daily_done": daily_done.duplicate(),
		"achievement_done": achievement_done.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	loading = true
	daily_progress = [0, 0, 0]
	daily_done = [false, false, false]
	achievement_done = [false, false, false]
	day = str(data.get("day", day))

	var saved_progress: Variant = data.get("daily_progress", [])
	var saved_daily: Variant = data.get("daily_done", [])
	var saved_achievements: Variant = data.get(
		"achievement_done", []
	)

	if saved_progress is Array and saved_progress.size() == 3:
		for i in range(3):
			daily_progress[i] = clampi(
				int(saved_progress[i]),
				0,
				int(DAILY[i]["target"])
			)

	if saved_daily is Array and saved_daily.size() == 3:
		for i in range(3):
			daily_done[i] = bool(saved_daily[i])

	if (
		saved_achievements is Array
		and saved_achievements.size() == 3
	):
		for i in range(3):
			achievement_done[i] = bool(saved_achievements[i])
	for i in range(DAILY.size()):
		daily_done[i] = daily_done[i] or daily_progress[i] >= int(DAILY[i]["target"])
		if daily_done[i]:
			daily_progress[i] = int(DAILY[i]["target"])
