extends Node

signal updated

const SPECIES := [
	{"name": "Окунь", "level": 2, "price": 18, "color": Color("#83B99A")},
	{"name": "Лосось", "level": 4, "price": 35, "color": Color("#DD9D88")},
	{"name": "Тунец", "level": 7, "price": 65, "color": Color("#819FC5")}
]
const EQUIPMENT := [
	{"name": "Спортивная удочка", "level": 2, "price": 200, "hint": "Открывает ловлю ценных видов рыбы"},
	{"name": "Холодильный ящик", "level": 4, "price": 450, "hint": "+1 рыба за улов; покупатели ждут дольше"},
	{"name": "Коптильня", "level": 5, "price": 900, "hint": "Копчёная рыба продаётся вдвое дороже"}
]
const GOALS := [
	{"name": "Поймать 3 ценные рыбы", "target": 3, "reward": 75},
	{"name": "Купить первое оборудование", "target": 1, "reward": 100},
	{"name": "Открыть гастрономический рынок", "target": 1, "reward": 150},
	{"name": "Выполнить 5 особых заказов", "target": 5, "reward": 200},
	{"name": "Закоптить 3 рыбы", "target": 3, "reward": 250}
]
const ZONE_PRICE := 600
const ZONE_LEVEL := 3
const MARKET := Vector3(-8, 0, 11)
const RIVER := Vector3(-15, 0, 1)
const REEF := Vector3(15, 0, 12)
const SMOKING_SECONDS := 8.0
const MAX_VALUE := 1_000_000_000_000

var state: Node
var progression: Node
var equipment: Array[bool] = [false, false, false]
var raw_stock: Array[int] = [0, 0, 0]
var smoked_stock: Array[int] = [0, 0, 0]
var caught: Array[int] = [0, 0, 0]
var goal_done: Array[bool] = [false, false, false, false, false]
var zone_open := false
var selected_species := 0
var orders := 0
var smoked_total := 0
var smoking_species := -1
var smoking_elapsed := 0.0


func setup(game_state: Node) -> void:
	state = game_state


func level() -> int:
	return int(progression.level) if progression != null else 1


func can_catch(index: int) -> bool:
	return index >= 0 and index < SPECIES.size() and equipment[0] and level() >= int(SPECIES[index]["level"])


func select_species(index: int) -> bool:
	if not can_catch(index):
		return false
	selected_species = index
	updated.emit()
	return true


func buy_equipment(index: int) -> bool:
	if index < 0 or index >= EQUIPMENT.size() or equipment[index]:
		return false
	var item: Dictionary = EQUIPMENT[index]
	if level() < int(item["level"]) or state.coins < int(item["price"]):
		return false
	state.coins -= int(item["price"])
	equipment[index] = true
	_commit("Куплено: " + str(item["name"]))
	return true


func open_market() -> bool:
	if zone_open or level() < ZONE_LEVEL or state.coins < ZONE_PRICE:
		return false
	state.coins -= ZONE_PRICE
	zone_open = true
	_commit("Гастрономический рынок открыт! Наймите продавца или обслуживайте заказы у прилавка.")
	return true


func catch_special(index: int) -> bool:
	if not can_catch(index):
		return false
	var amount := 2 if equipment[1] else 1
	if raw_stock[index] > MAX_VALUE - amount or caught[index] > MAX_VALUE - amount or state.player_fish_caught > MAX_VALUE - amount:
		return false
	raw_stock[index] += amount
	caught[index] += amount
	state.record_fish_caught(amount, true)
	if progression != null:
		progression.add_xp(6 + index * 3)
	_commit("%s: +%d. Запас для особых заказов: %d" % [SPECIES[index]["name"], amount, raw_stock[index]])
	return true


func start_smoking(index: int) -> bool:
	if index < 0 or index >= SPECIES.size() or not equipment[2] or smoking_species != -1 or raw_stock[index] <= 0:
		return false
	if smoked_stock[index] >= MAX_VALUE or smoked_total >= MAX_VALUE:
		return false
	raw_stock[index] -= 1
	smoking_species = index
	smoking_elapsed = 0.0
	_commit("Коптильня: " + str(SPECIES[index]["name"]))
	return true


func _process(delta: float) -> void:
	if smoking_species < 0:
		return
	smoking_elapsed += delta
	if smoking_elapsed >= SMOKING_SECONDS:
		var index := smoking_species
		smoking_species = -1
		smoking_elapsed = 0.0
		smoked_stock[index] += 1
		smoked_total += 1
		_commit("Копчёная рыба готова: " + str(SPECIES[index]["name"]))


func sell_order(index: int, amount: int, smoked: bool, premium: bool) -> bool:
	if not zone_open or index < 0 or index >= SPECIES.size() or amount < 1 or amount > 5 or orders >= MAX_VALUE:
		return false
	var stock := smoked_stock if smoked else raw_stock
	if stock[index] < amount:
		return false
	var earned := int(SPECIES[index]["price"]) * amount * (2 if smoked else 1)
	if premium:
		earned += earned / 2
	if state.coins > MAX_VALUE - earned:
		return false
	stock[index] -= amount
	state.coins += earned
	orders += 1
	if progression != null:
		progression.add_xp(15 + amount * 5)
	state.reward.emit(earned, "🪙", Color("#E4BE79"), MARKET)
	_commit("Особый заказ: +%d монет" % earned)
	return true


func goal_values() -> Array[int]:
	var gear := 0
	for owned in equipment:
		gear += int(owned)
	return [caught[0] + caught[1] + caught[2], gear, int(zone_open), orders, smoked_total]


func next_goal() -> String:
	var values := goal_values()
	for i in range(GOALS.size()):
		if not goal_done[i]:
			return "%s: %d/%d" % [GOALS[i]["name"], mini(values[i], GOALS[i]["target"]), GOALS[i]["target"]]
	return "Гастрономический рынок: развивайте промысел и выполняйте особые заказы"


func _commit(message: String) -> void:
	var values := goal_values()
	for i in range(GOALS.size()):
		if not goal_done[i] and values[i] >= int(GOALS[i]["target"]):
			goal_done[i] = true # Set the flag before any observer or nested transaction.
			state.coins += int(GOALS[i]["reward"])
			state.notice.emit("%s: +%d монет" % [GOALS[i]["name"], GOALS[i]["reward"]])
	state.notice.emit(message)
	updated.emit()
	state.changed.emit()


func get_save_data() -> Dictionary:
	return {"equipment": equipment.duplicate(), "raw_stock": raw_stock.duplicate(),
		"smoked_stock": smoked_stock.duplicate(), "caught": caught.duplicate(),
		"goal_done": goal_done.duplicate(), "zone_open": zone_open, "selected_species": selected_species,
		"orders": orders, "smoked_total": smoked_total, "smoking_species": smoking_species,
		"smoking_elapsed": smoking_elapsed}


func load_save_data(data: Dictionary) -> void:
	# Missing content in old versions migrates to a fresh harbor without rewards.
	equipment.assign(data.get("equipment", [false, false, false]))
	raw_stock.assign(data.get("raw_stock", [0, 0, 0]))
	smoked_stock.assign(data.get("smoked_stock", [0, 0, 0]))
	caught.assign(data.get("caught", [0, 0, 0]))
	goal_done.assign(data.get("goal_done", [false, false, false, false, false]))
	zone_open = bool(data.get("zone_open", false))
	selected_species = int(data.get("selected_species", 0))
	orders = int(data.get("orders", 0))
	smoked_total = int(data.get("smoked_total", 0))
	smoking_species = int(data.get("smoking_species", -1))
	smoking_elapsed = float(data.get("smoking_elapsed", 0.0))
	var values := goal_values()
	for i in range(GOALS.size()):
		goal_done[i] = goal_done[i] or values[i] >= int(GOALS[i]["target"])
