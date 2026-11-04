
extends Node

signal changed
signal notice(message: String)
signal reward(
	amount: int,
	icon: String,
	color: Color,
	position: Vector3
)

signal processing_started
signal processing_finished
signal sale_completed(amount: int, fillets: int)

const FISHING := Vector3(-8, 0, -9)
const FISH_BOX := Vector3(-5, 0, -5)
const MACHINE := Vector3(5, 0, 3)
const MACHINE_ZONE := Vector3(5, 0, 5.6)
const FILLET_BOX := Vector3(9, 0, -5)
const CASH := Vector3(9, 0, -9)

const HIRE_FISHER := Vector3(-12, 0, -4)
const HIRE_FISH_CARRIER := Vector3(-1, 0, 3)
const HIRE_FILLET_CARRIER := Vector3(10, 0, 7)
const HIRE_SELLER := Vector3(13, 0, -8)

const HIRE_POSITIONS := [
	HIRE_FISHER,
	HIRE_FISH_CARRIER,
	HIRE_FILLET_CARRIER,
	HIRE_SELLER
]

var coins: int = 0
var player_fish: int = 0
var player_fillets: int = 0

var fish_box: int = 0
var machine_input: int = 0
var machine_output: int = 0
var fillet_box: int = 0

var processing: bool = false
var process_timer: float = 0.0

var boat_state: String = "none"
var boat_order: int = 0
var boat_time: float = 0.0
var served: int = 0

var hired: Array[int] = [0, 0, 0, 0]
var prices: Array[int] = [30, 50, 70, 100]

func _process(delta: float) -> void:
	if not processing and machine_input > 0:
		machine_input -= 1
		processing = true
		process_timer = 0.0

		processing_started.emit()
		changed.emit()

	if processing:
		process_timer += delta

		if process_timer >= 3.6:
			processing = false
			process_timer = 0.0
			machine_output += 3

			processing_finished.emit()

			reward.emit(
				3,
				"🍣",
				Color("#FFD38B"),
				MACHINE
			)

			changed.emit()

func sell() -> bool:
	if boat_state != "ordering":
		return false

	if fillet_box < boat_order:
		return false

	var count: int = boat_order
	fillet_box -= count

	var earned: int = count * 5
	coins += earned
	served += 1

	boat_state = "leaving"

	sale_completed.emit(earned, count)

	reward.emit(
		earned,
		"🪙",
		Color("#A4E7A2"),
		CASH
	)

	notice.emit(
		"Заказ выполнен! +%d монет" % earned
	)

	changed.emit()
	return true

func hire(role: int) -> bool:
	if role < 0 or role >= 4:
		return false

	if coins < prices[role]:
		return false

	coins -= prices[role]
	hired[role] += 1

	prices[role] = int(
		ceil(float(prices[role]) * 1.6)
	)

	notice.emit("Работник нанят!")
	changed.emit()
	return true
