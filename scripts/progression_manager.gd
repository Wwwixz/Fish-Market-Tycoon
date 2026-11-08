
extends Node

const S = preload("res://scripts/game_state.gd")
signal experience_gained(amount: int)
signal level_up(new_level: int)

const MAX_LEVEL := 50

var state: Node
var level: int = 1
var xp: int = 0
var total_xp: int = 0

var initialized: bool = false


func setup(game_state: Node) -> void:
	state = game_state
	state.harbor.progression = self


func _ready() -> void:
	if state == null:
		return

	state.sale_completed.connect(_on_boat_sale)
	state.customer_sale_completed.connect(_on_customer_sale)
	state.upgrade_purchased.connect(_on_upgrade)
	state.expansion_purchased.connect(_on_expansion)

	initialized = true


func xp_required(current_level: int = level) -> int:
	if current_level >= MAX_LEVEL:
		return 0

	return 50 + (current_level - 1) * 35



func add_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return

	xp += amount
	total_xp += amount

	experience_gained.emit(amount)

	while level < MAX_LEVEL:
		var required: int = xp_required()

		if xp < required:
			break

		xp -= required
		level += 1

		level_up.emit(level)

		if state != null:
			state.notice.emit(
				"Новый уровень: %d!" % level
			)

			if level % 5 == 0:
				var bonus: int = level * 25
				state.coins += bonus

				state.notice.emit(
					"Награда за уровень %d: +%d монет!" %
					[level, bonus]
				)

				state.reward.emit(
					bonus,
					"🪙",
					Color("#E9C77C"),
					S.CASH
				)

				state.changed.emit()

		if level >= MAX_LEVEL:
			xp = 0
			break



func get_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0

	var required := xp_required()

	if required <= 0:
		return 1.0

	return clampf(
		float(xp) / float(required),
		0.0,
		1.0
	)


func get_rank_name() -> String:
	if level >= 40:
		return "Легенда рыбного рынка"

	if level >= 30:
		return "Морской магнат"

	if level >= 20:
		return "Владелец сети"

	if level >= 10:
		return "Опытный торговец"

	if level >= 5:
		return "Предприниматель"

	return "Начинающий рыбак"


func _on_boat_sale(
	_earned: int,
	fillets: int
) -> void:
	add_xp(15 + fillets * 2)


func _on_customer_sale(
	_earned: int,
	fillets: int
) -> void:
	add_xp(3 + fillets * 2)


func _on_upgrade(
	_role: int,
	_new_level: int
) -> void:
	add_xp(20)


func _on_expansion(
	_role: int,
	_new_level: int
) -> void:
	add_xp(40)


func get_save_data() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"total_xp": total_xp
	}


func load_save_data(data: Dictionary) -> void:
	level = clampi(
		int(data.get("level", 1)),
		1,
		MAX_LEVEL
	)

	xp = maxi(
		0,
		int(data.get("xp", 0))
	)

	total_xp = maxi(
		0,
		int(data.get("total_xp", 0))
	)

	if level >= MAX_LEVEL:
		xp = 0
	else:
		xp = mini(
			xp,
			xp_required() - 1
		)
