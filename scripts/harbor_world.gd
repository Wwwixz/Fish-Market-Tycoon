extends Node3D

const V = preload("res://scripts/visuals.gd")
const Harbor = preload("res://scripts/harbor_manager.gd")
var state: Node
var player: Node3D
var harbor: Node
var market_root: Node3D
var market_label: Label3D
var river_label: Label3D
var reef_label: Label3D
var visitors: Array[Dictionary] = []
var spawn_timer := 3.0
var catch_timer := 0.0
var clock := 0.0
var next_visitor := 0
var inside_spot := -1


func setup(game_state: Node, game_player: Node3D) -> void:
	state = game_state
	player = game_player
	harbor = state.harbor


func _ready() -> void:
	market_root = Node3D.new()
	market_root.position = Harbor.MARKET
	add_child(market_root)
	V.box(market_root, Vector3(4.5, 0.1, 3.0), Vector3(0, 0.15, 0), Color("#B7C9AC"))
	V.box(market_root, Vector3(3.2, 1.1, 0.8), Vector3(0, 0.8, 0), Color("#967A62"))
	V.box(market_root, Vector3(3.5, 0.15, 1.7), Vector3(0, 2.6, 0), Color("#D4B675"))
	for x in [-1.4, 1.4]:
		V.cylinder(market_root, 0.07, 2.2, Vector3(x, 1.4, 0.5), Color("#655744"))
	market_label = V.label(self, "", Harbor.MARKET + Vector3(0, 3.1, 0), 32)
	river_label = _pier(Harbor.RIVER, "РЕЧНОЙ ПРИЧАЛ", Color("#83B99A"))
	reef_label = _pier(Harbor.REEF, "МОРСКОЙ ПРИЧАЛ", Color("#819FC5"))
	harbor.updated.connect(_refresh)
	_refresh()


func _pier(pos: Vector3, title: String, color: Color) -> Label3D:
	V.box(self, Vector3(2.5, 0.2, 2.5), pos + Vector3(0, 0.2, 0), Color("#A58666"))
	V.cylinder(self, 0.65, 0.06, pos + Vector3(0, 0.34, 0), color)
	return V.label(self, title, pos + Vector3(0, 2.0, 0), 30)


func _refresh() -> void:
	market_root.visible = harbor.zone_open
	market_label.text = "ГАСТРОНОМИЧЕСКИЙ РЫНОК" if harbor.zone_open else "НОВЫЙ РЫНОК: ур. 3 · 600 монет\nБизнес → Развитие"


func _process(delta: float) -> void:
	clock += delta
	_fish(delta)
	for label in [river_label, reef_label, market_label]:
		label.visible = player.position.distance_to(label.position) < 10.0
	if not harbor.zone_open:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0 and visitors.size() < 2:
		_spawn()
		spawn_timer = 15.0
	for visitor in visitors:
		_update_visitor(visitor, delta)
	for i in range(visitors.size() - 1, -1, -1):
		if visitors[i]["done"]:
			visitors[i]["node"].queue_free()
			visitors.remove_at(i)


func _fish(delta: float) -> void:
	var spot := -1
	if player.position.distance_to(Harbor.RIVER + Vector3(0, 0.5, 0)) < 1.5:
		spot = 0
	elif player.position.distance_to(Harbor.REEF + Vector3(0, 0.5, 0)) < 1.5:
		spot = 1
	if spot != inside_spot:
		catch_timer = 0.0
		inside_spot = spot
	if spot == -1 or state.controls_blocked or player.fishing:
		return
	var index: int = harbor.selected_species
	var label := river_label if spot == 0 else reef_label
	if not harbor.can_catch(index):
		label.text = "Нужна спортивная удочка и уровень %d\nБизнес → Развитие" % Harbor.SPECIES[index]["level"]
		catch_timer = 0.0
		return
	if (index == 2) != (spot == 1):
		label.text = "Тунец — морской причал\nОкунь и лосось — речной причал"
		catch_timer = 0.0
		return
	catch_timer += delta
	label.text = "%s · ловля %.1f / 3 сек." % [Harbor.SPECIES[index]["name"], minf(catch_timer, 3.0)]
	if catch_timer >= 3.0:
		catch_timer = 0.0
		if harbor.catch_special(index):
			state.reward.emit(2 if harbor.equipment[1] else 1, "🐟", Harbor.SPECIES[index]["color"], player.position)


func _spawn() -> void:
	var available: Array[int] = []
	for i in range(Harbor.SPECIES.size()):
		if harbor.level() >= int(Harbor.SPECIES[i]["level"]):
			available.append(i)
	if available.is_empty():
		return
	var index := available[next_visitor % available.size()]
	var kind := next_visitor % 3
	next_visitor += 1
	var smoked: bool = harbor.equipment[2] and next_visitor % 3 == 0
	var node := Node3D.new()
	node.position = Vector3(-2, 0.5, 14)
	add_child(node)
	var model := V.animated_person(node, [Color("#94A47C"), Color("#E2D3A7"), Color("#847CA7")][kind])
	var title: String = ["Постоянный покупатель", "Шеф-повар", "Ресторатор"][kind]
	var amount := 2 if kind == 2 else 1
	var text := "%s\n%s%s ×%d" % [title, "Копчёный " if smoked else "", Harbor.SPECIES[index]["name"], amount]
	var label := V.label(node, text, Vector3(0, 2.8, 0), 28)
	visitors.append({"node": node, "model": model, "label": label, "title": text,
		"species": index, "amount": amount, "smoked": smoked, "premium": kind > 0,
		"wait": 0.0, "service": 0.0, "leaving": false, "done": false})


func _update_visitor(visitor: Dictionary, delta: float) -> void:
	var node: Node3D = visitor["node"]
	var target := Vector3(-2, 0.5, 16) if visitor["leaving"] else Harbor.MARKET + Vector3(visitors.find(visitor) * 1.2, 0.5, 1.4)
	var difference := target - node.position
	var moving := difference.length() > 0.2
	if moving:
		node.position = node.position.move_toward(target, 2.8 * delta)
		node.rotation.y = atan2(difference.x, difference.z)
	else:
		if visitor["leaving"]:
			visitor["done"] = true
			return
		visitor["wait"] += delta
		var can_serve: bool = state.hired[3] > 0 or (not state.controls_blocked and player.position.distance_to(Harbor.MARKET + Vector3(0, 0.5, 0)) < 2.7)
		if can_serve:
			visitor["service"] += delta
			if visitor["service"] >= 2.0:
				visitor["service"] = 0.0
				if harbor.sell_order(visitor["species"], visitor["amount"], visitor["smoked"], visitor["premium"]):
					visitor["leaving"] = true
					visitor["label"].text = "Спасибо! До встречи!"
		if visitor["wait"] > (90.0 if harbor.equipment[1] else 60.0):
			visitor["leaving"] = true
			visitor["label"].text = "Вернусь позже"
	visitor["label"].visible = player.position.distance_to(node.position) < 9.0
	var model: Dictionary = visitor["model"]
	var swing := sin(clock * 8.0) * 0.4 if moving else 0.0
	model["left_leg"].rotation.x = swing
	model["right_leg"].rotation.x = -swing
