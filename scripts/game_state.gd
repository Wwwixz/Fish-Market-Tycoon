
extends Node

const Harbor = preload("res://scripts/harbor_manager.gd")
var harbor: Node


func _ready() -> void:
	harbor = Harbor.new()
	harbor.setup(self)
	add_child(harbor)

signal changed
signal notice(message: String)
signal reward(amount: int, icon: String, color: Color, position: Vector3)
signal processing_started
signal processing_finished
signal sale_completed(amount: int, fillets: int)
signal customer_sale_completed(amount: int, fillets: int)
signal upgrade_purchased(role: int, level: int)
signal expansion_purchased(role: int, level: int)
signal fish_caught(amount: int, by_player: bool)
signal worker_hired(role: int)

const MAX_WORKERS_PER_ROLE := 100
const MAX_UPGRADE_LEVEL := 100
const MAX_PRICE := 1_000_000_000_000

const FISHING := Vector3(-8, 0, -9)
const FISH_BOX := Vector3(-5, 0, -5)
const MACHINE := Vector3(5, 0, 3)
const MACHINE_ZONE := Vector3(5, 0, 5.6)
const FILLET_BOX := Vector3(9, 0, -5)
const CASH := Vector3(9, 0, -9)

const MARKET := Vector3(3, 0, -7)
const MARKET_ENTRANCE := Vector3(-2, 0, 14)

const HIRE_FISHER := Vector3(-12, 0, -4)
const HIRE_FISH_CARRIER := Vector3(-1, 0, 3)
const HIRE_FILLET_CARRIER := Vector3(10, 0, 7)
const HIRE_SELLER := Vector3(13, 0, -8)

const HIRE_POSITIONS := [
	HIRE_FISHER, HIRE_FISH_CARRIER,
	HIRE_FILLET_CARRIER, HIRE_SELLER
]

const UPGRADE_POSITIONS := [
	Vector3(1, 0, 7),
	Vector3(-11, 0, 5),
	Vector3(-3, 0, 9),
	Vector3(13, 0, -2)
]

const UPGRADE_NAMES := [
	"СТАНОК", "СКОРОСТЬ", "ПЕРЕНОСКА", "ДОХОД"
]

const EXPANSION_POSITIONS := [
	Vector3(0, 0, -11),
	Vector3(7, 0, 10),
	Vector3(-13, 0, 10)
]

const EXPANSION_NAMES := [
	"РАСШИРИТЬ МАГАЗИН",
	"БЫСТРАЯ КАССА",
    "НОВАЯ ТЕРРИТОРИЯ"
]

const EXPANSION_MAX_LEVELS := [3, 5, 2]

var coins: int = 0
var player_fish: int = 0
var player_fillets: int = 0
var player_fish_caught: int = 0
var worker_fish_caught: int = 0
var controls_blocked: bool = false
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

var customers_served: int = 0
var customers_lost: int = 0
var market_queue: int = 0

var hired: Array[int] = [0, 0, 0, 0]
var prices: Array[int] = [30, 50, 70, 100]

var upgrade_levels: Array[int] = [1, 1, 1, 1]
var upgrade_prices: Array[int] = [50, 75, 100, 125]

var expansion_levels: Array[int] = [1, 1, 0]
var expansion_prices: Array[int] = [150, 120, 200]

func processing_duration() -> float:
	return maxf(
		1.0,
		3.6 * pow(0.85, upgrade_levels[0] - 1)
	)

func worker_speed() -> float:
	return 3.5 * pow(1.15, upgrade_levels[1] - 1)

func carrying_capacity() -> int:
	return upgrade_levels[2]

func fillet_price() -> int:
	return 5 + upgrade_levels[3] - 1

func market_capacity() -> int:
	return 3 + (expansion_levels[0] - 1) * 2

func customer_service_duration() -> float:
	return maxf(
		0.45,
		1.8 * pow(0.78, expansion_levels[1] - 1)
	)

func customer_spawn_interval() -> float:
	return maxf(
		3.0,
		7.0 - float(expansion_levels[0] - 1) * 1.5
	)

func upgrade(role: int) -> bool:
	if role < 0 or role >= 4:
		return false
	if upgrade_levels[role] >= MAX_UPGRADE_LEVEL:
		return false

	var price: int = upgrade_prices[role]
	if coins < price:
		return false

	coins -= price
	upgrade_levels[role] += 1
	upgrade_prices[role] = mini(MAX_PRICE, int(ceil(float(price) * 1.65)))

	upgrade_purchased.emit(role, upgrade_levels[role])
	notice.emit("%s: уровень %d!" % [
		UPGRADE_NAMES[role], upgrade_levels[role]
	])
	changed.emit()
	return true

func buy_expansion(role: int) -> bool:
	if role < 0 or role >= 3:
		return false

	if expansion_levels[role] >= EXPANSION_MAX_LEVELS[role]:
		return false

	var price: int = expansion_prices[role]
	if coins < price:
		return false

	coins -= price
	expansion_levels[role] += 1
	expansion_prices[role] = int(ceil(float(price) * 1.8))

	expansion_purchased.emit(role, expansion_levels[role])
	notice.emit("%s: уровень %d!" % [
		EXPANSION_NAMES[role], expansion_levels[role]
	])
	changed.emit()
	return true

func hire(role: int) -> bool:
	if role < 0 or role >= 4:
		return false
	if hired[role] >= MAX_WORKERS_PER_ROLE:
		return false
	if coins < prices[role]:
		return false

	coins -= prices[role]
	hired[role] += 1
	prices[role] = mini(MAX_PRICE, int(ceil(float(prices[role]) * 1.6)))
	notice.emit("Работник нанят!")
	worker_hired.emit(role)
	changed.emit()
	return true

func record_fish_caught(amount: int, by_player: bool) -> void:
	if amount <= 0:
		return
	if by_player:
		player_fish_caught += amount
	else:
		worker_fish_caught += amount
	fish_caught.emit(amount, by_player)
	changed.emit()

func _process(delta: float) -> void:
	if not processing and machine_input > 0:
		machine_input -= 1
		processing = true
		process_timer = 0.0
		processing_started.emit()
		changed.emit()

	if processing:
		process_timer += delta
		if process_timer >= processing_duration():
			processing = false
			process_timer = 0.0
			machine_output += 3
			processing_finished.emit()
			reward.emit(3, "🍣", Color("#FFD38B"), MACHINE)
			changed.emit()

func sell() -> bool:
	if boat_state != "ordering":
		return false
	if boat_order <= 0 or fillet_box < boat_order:
		return false

	var count: int = boat_order
	var earned: int = count * fillet_price()

	fillet_box -= count
	coins += earned
	served += 1
	boat_state = "leaving"

	sale_completed.emit(earned, count)
	reward.emit(earned, "🪙", Color("#A4E7A2"), CASH)
	notice.emit("Заказ лодки: +%d монет" % earned)
	changed.emit()
	return true

func sell_to_customer(count: int) -> bool:
	if count <= 0 or fillet_box < count:
		return false

	var earned: int = count * fillet_price()
	fillet_box -= count
	coins += earned
	customers_served += 1

	customer_sale_completed.emit(earned, count)
	reward.emit(earned, "🪙", Color("#A4E7A2"), MARKET)
	notice.emit("Покупатель: +%d монет" % earned)
	changed.emit()
	return true
