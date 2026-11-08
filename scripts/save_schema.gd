extends RefCounted

# Validate the complete snapshot before changing any live game state.
const MAX_VALUE := 1_000_000_000_000
const COUNT_KEYS := [
	"coins", "player_fish", "player_fillets", "fish_box", "machine_input",
	"machine_output", "fillet_box", "boat_order", "served",
	"customers_served", "customers_lost"
]
const QUEST_TARGETS := [10, 5, 3]
const DAILY_TARGETS := [15, 5, 3]


static func number(value: Variant, minimum: float, maximum: float, whole: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	var n := float(value)
	return is_finite(n) and n >= minimum and n <= maximum and (not whole or n == floor(n))


static func integers(value: Variant, length: int, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item in value:
		if not number(item, minimum, maximum, true):
			return false
	return true


static func flags(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item in value:
		if not item is bool:
			return false
	return true


static func valid(data: Dictionary) -> bool:
	if not number(data.get("version"), 1, 4, true):
		return false
	if int(data["version"]) >= 3 and not number(data.get("revision"), 1, MAX_VALUE, true):
		return false
	if int(data["version"]) >= 4 and not valid_harbor(data.get("harbor")):
		return false
	if data.has("harbor") and not valid_harbor(data["harbor"]):
		return false
	for key in COUNT_KEYS:
		if not number(data.get(key), 0, MAX_VALUE, true):
			return false
	if not data.get("processing") is bool:
		return false
	if not number(data.get("process_timer"), 0, 3600):
		return false
	if not number(data.get("boat_time"), 0, 120):
		return false
	if not data.get("boat_state") in ["none", "arriving", "ordering", "leaving"]:
		return false
	if data["boat_state"] == "ordering" and int(data["boat_order"]) <= 0:
		return false
	if not integers(data.get("hired"), 4, 0, 100):
		return false
	if not integers(data.get("prices"), 4, 1, MAX_VALUE):
		return false
	if not integers(data.get("upgrade_levels"), 4, 1, 100):
		return false
	if not integers(data.get("upgrade_prices"), 4, 1, MAX_VALUE):
		return false
	if not integers(data.get("expansion_levels"), 3, 0, 5):
		return false
	for i in range(3):
		if data["expansion_levels"][i] > [3, 5, 2][i]:
			return false
	if data["expansion_levels"][0] < 1 or data["expansion_levels"][1] < 1:
		return false
	if not integers(data.get("expansion_prices"), 3, 1, MAX_VALUE):
		return false
	var position: Variant = data.get("player_position")
	if not position is Array or position.size() != 3:
		return false
	for component in position:
		if not number(component, -1000, 1000):
			return false
	for key in ["player_fish_caught", "worker_fish_caught"]:
		if not number(data.get(key, 0), 0, MAX_VALUE, true):
			return false
	for key in ["progression", "quests", "daily"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
		if int(data["version"]) >= 2 and not data.has(key):
			return false
	if data.has("progression"):
		var progression: Dictionary = data["progression"]
		if not number(progression.get("level"), 1, 50, true):
			return false
		if not number(progression.get("xp"), 0, MAX_VALUE, true):
			return false
		if not number(progression.get("total_xp"), 0, MAX_VALUE, true):
			return false
	if data.has("quests"):
		var quests: Dictionary = data["quests"]
		if not integers(quests.get("progress"), 3, 0, MAX_VALUE) or not flags(quests.get("completed"), 3):
			return false
		for i in range(3):
			if quests["progress"][i] > QUEST_TARGETS[i]:
				return false
	if data.has("daily"):
		var daily: Dictionary = data["daily"]
		if not daily.get("day") is String:
			return false
		var date_parts: PackedStringArray = daily["day"].split("-")
		if date_parts.size() != 3 or daily["day"].length() != 10:
			return false
		for part in date_parts:
			if not part.is_valid_int():
				return false
		if int(date_parts[1]) < 1 or int(date_parts[1]) > 12 or int(date_parts[2]) < 1 or int(date_parts[2]) > 31:
			return false
		if not integers(daily.get("daily_progress"), 3, 0, MAX_VALUE):
			return false
		if not flags(daily.get("daily_done"), 3) or not flags(daily.get("achievement_done"), 3):
			return false
		for i in range(3):
			if daily["daily_progress"][i] > DAILY_TARGETS[i]:
				return false
	return true


static func valid_harbor(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["raw_stock", "smoked_stock", "caught"]:
		if not integers(value.get(key), 3, 0, MAX_VALUE):
			return false
	if not flags(value.get("equipment"), 3) or not flags(value.get("goal_done"), 5):
		return false
	if not value.get("zone_open") is bool or not number(value.get("selected_species"), 0, 2, true):
		return false
	for key in ["orders", "smoked_total"]:
		if not number(value.get(key), 0, MAX_VALUE, true):
			return false
	if not number(value.get("smoking_species"), -1, 2, true) or not number(value.get("smoking_elapsed"), 0, 8):
		return false
	if value["smoking_species"] == -1 and value["smoking_elapsed"] != 0:
		return false
	return value["smoking_species"] == -1 or value["equipment"][2]
