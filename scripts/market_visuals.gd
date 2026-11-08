
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const LABEL_DISTANCE := 5.5

const WOOD := Color("#98765A")
const DARK_WOOD := Color("#6E5341")
const CANOPY_GREEN := Color("#72998D")
const CANOPY_CREAM := Color("#E4D6B8")
const METAL := Color("#738D8C")
const ICE := Color("#C8DCD9")

var state: Node
var player: Node3D

var market_root: Node3D
var display_root: Node3D
var queue_root: Node3D
var extensions_root: Node3D

var title_label: Label3D
var status: Label3D
var stock_label: Label3D
var speed_label: Label3D

var last_capacity: int = -1
var last_stock: int = -1
var last_market_level: int = -1

var clock: float = 0.0
var hanging_sign: Node3D


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	_build_market()

	if state != null:
		state.changed.connect(refresh)
		refresh()


func _build_market() -> void:
	market_root = Node3D.new()
	market_root.name = "FishMarket"
	market_root.position = S.MARKET
	add_child(market_root)

	# Основание торговой точки
	V.box(
		market_root,
		Vector3(5.0, 0.2, 3.2),
		Vector3(0, 0.18, 0),
		Color("#B7A48B")
	)

	# Основной деревянный прилавок
	V.box(
		market_root,
		Vector3(3.7, 1.0, 1.1),
		Vector3(0, 0.78, 0),
		WOOD
	)

	for x in [-1.65, -0.85, 0.0, 0.85, 1.65]:
		V.box(
			market_root,
			Vector3(0.065, 0.85, 1.13),
			Vector3(x, 0.78, 0),
			DARK_WOOD
		)

	V.box(
		market_root,
		Vector3(4.0, 0.15, 1.3),
		Vector3(0, 1.35, 0),
		CANOPY_CREAM
	)

	# Опоры навеса
	for x in [-2.0, 2.0]:
		for z in [-0.95, 0.95]:
			V.box(
				market_root,
				Vector3(0.13, 2.9, 0.13),
				Vector3(x, 1.65, z),
				DARK_WOOD
			)

	# Каркас навеса
	V.box(
		market_root,
		Vector3(4.65, 0.13, 2.75),
		Vector3(0, 3.12, 0),
		DARK_WOOD
	)

	# Полосатый тканевый навес
	for i in range(6):
		var color := (
			CANOPY_GREEN
			if i % 2 == 0
			else CANOPY_CREAM
		)

		V.box(
			market_root,
			Vector3(0.76, 0.08, 2.65),
			Vector3(-1.9 + float(i) * 0.76, 3.2, 0),
			color
		)

	# Передний свес ткани
	for i in range(6):
		var color := (
			CANOPY_GREEN
			if i % 2 == 0
			else CANOPY_CREAM
		)

		V.box(
			market_root,
			Vector3(0.76, 0.3, 0.07),
			Vector3(
				-1.9 + float(i) * 0.76,
				3.02,
				-1.34
			),
			color
		)

	# Холодильная витрина
	V.box(
		market_root,
		Vector3(2.2, 0.18, 0.9),
		Vector3(-0.7, 1.5, 0),
		METAL
	)

	V.box(
		market_root,
		Vector3(2.02, 0.05, 0.74),
		Vector3(-0.7, 1.61, 0),
		ICE
	)

	for x in [-1.78, 0.38]:
		V.box(
			market_root,
			Vector3(0.07, 0.2, 0.95),
			Vector3(x, 1.61, 0),
			METAL.darkened(0.2)
		)

	# Кассовый аппарат
	V.box(
		market_root,
		Vector3(0.72, 0.42, 0.55),
		Vector3(1.18, 1.62, 0),
		Color("#466E71")
	)

	V.box(
		market_root,
		Vector3(0.54, 0.22, 0.05),
		Vector3(1.18, 1.72, -0.3),
		Color("#A6CBB6")
	)

	for i in range(3):
		V.box(
			market_root,
			Vector3(0.1, 0.035, 0.1),
			Vector3(
				0.99 + float(i) * 0.19,
				1.85,
				-0.06
			),
			Color("#C5D2C9")
		)

	# Небольшая подвесная вывеска
	hanging_sign = Node3D.new()
	hanging_sign.position = Vector3(0, 2.65, -1.45)
	market_root.add_child(hanging_sign)

	V.box(
		hanging_sign,
		Vector3(2.2, 0.5, 0.1),
		Vector3.ZERO,
		DARK_WOOD
	)

	V.box(
		hanging_sign,
		Vector3(2.05, 0.36, 0.12),
		Vector3(0, 0, -0.015),
		Color("#B9A17E")
	)

	for x in [-0.85, 0.85]:
		V.cylinder(
			market_root,
			0.025,
			0.4,
			Vector3(x, 2.99, -1.45),
			METAL
		)

	# Декоративные ящики сбоку
	for i in range(2):
		var x: float = -2.45
		var z: float = -0.45 + float(i) * 0.9

		V.box(
			market_root,
			Vector3(0.72, 0.55, 0.72),
			Vector3(x, 0.55, z),
			WOOD
		)

		for offset in [-0.25, 0.25]:
			V.box(
				market_root,
				Vector3(0.08, 0.58, 0.76),
				Vector3(x + offset, 0.55, z),
				DARK_WOOD
			)

	# Контейнер с упаковкой
	V.box(
		market_root,
		Vector3(0.65, 0.35, 0.7),
		Vector3(2.3, 0.5, 0.65),
		Color("#829B94")
	)

	for i in range(3):
		V.box(
			market_root,
			Vector3(0.4, 0.04, 0.35),
			Vector3(2.3, 0.72 + float(i) * 0.04, 0.65),
			Color("#E1D5BD")
		)

	display_root = Node3D.new()
	display_root.name = "MarketDisplay"
	display_root.position = Vector3(-0.7, 1.67, 0)
	market_root.add_child(display_root)

	extensions_root = Node3D.new()
	extensions_root.name = "MarketExtensions"
	market_root.add_child(extensions_root)

	queue_root = Node3D.new()
	queue_root.name = "QueueMarkers"
	add_child(queue_root)

	title_label = V.label(
		market_root,
		"РЫБНЫЙ МАГАЗИН",
		Vector3(0, 3.85, 0),
		32
	)

	status = V.label(
		market_root,
		"",
		Vector3(0, 4.3, 0),
		25
	)

	stock_label = V.label(
		market_root,
		"",
		Vector3(0, 2.05, -0.85),
		25
	)

	speed_label = V.label(
		market_root,
		"",
		Vector3(0, 4.7, 0),
		24
	)

	title_label.visible = false
	status.visible = false
	stock_label.visible = false
	speed_label.visible = false


func refresh() -> void:
	if state == null:
		return

	status.text = "ОЧЕРЕДЬ: %d/%d" % [
		state.market_queue,
		state.market_capacity()
	]

	stock_label.text = "ФИЛЕ: %d · %d МОНЕТ" % [
		state.fillet_box,
		state.fillet_price()
	]

	speed_label.text = "КАССА: %.1f С" % [
		state.customer_service_duration()
	]

	if last_stock != mini(state.fillet_box, 6):
		last_stock = mini(state.fillet_box, 6)
		_refresh_display()

	if last_capacity != state.market_capacity():
		last_capacity = state.market_capacity()
		_refresh_queue()

	if last_market_level != state.expansion_levels[0]:
		last_market_level = state.expansion_levels[0]
		_refresh_extensions()


func _refresh_display() -> void:
	for child in display_root.get_children():
		child.queue_free()

	var amount: int = mini(state.fillet_box, 6)

	for i in range(amount):
		var col: int = i % 3
		var row: int = i / 3

		var fillet := Node3D.new()
		fillet.position = Vector3(
			-0.55 + float(col) * 0.55,
			0.08 + float(row) * 0.17,
			0
		)
		display_root.add_child(fillet)

		V.box(
			fillet,
			Vector3(0.45, 0.13, 0.3),
			Vector3.ZERO,
			Color("#E9A58D")
		)

		V.box(
			fillet,
			Vector3(0.37, 0.025, 0.035),
			Vector3(0, 0.08, 0),
			Color("#F4D2BD")
		)


func _refresh_queue() -> void:
	for child in queue_root.get_children():
		child.queue_free()

	var capacity: int = state.market_capacity()

	for i in range(capacity):
		var marker := Node3D.new()
		marker.name = "Queue_%d" % i
		marker.position = S.MARKET + Vector3(
			0,
			0,
			2.0 + float(i) * 1.25
		)
		queue_root.add_child(marker)

		V.box(
			marker,
			Vector3(1.3, 0.025, 0.85),
			Vector3(0, 0.26, 0),
			Color("#92AB9D")
		)

		# Маленькие боковые отметки вместо цифр
		for x in [-0.58, 0.58]:
			V.box(
				marker,
				Vector3(0.07, 0.035, 0.6),
				Vector3(x, 0.29, 0),
				Color("#C8D7CA")
			)


func _refresh_extensions() -> void:
	for child in extensions_root.get_children():
		child.queue_free()

	var level: int = state.expansion_levels[0]

	if level >= 2:
		_add_side_counter(-3.2)

	if level >= 3:
		_add_side_counter(3.2)


func _add_side_counter(x: float) -> void:
	V.box(
		extensions_root,
		Vector3(1.9, 0.85, 1.1),
		Vector3(x, 0.7, 0),
		WOOD
	)

	V.box(
		extensions_root,
		Vector3(2.1, 0.13, 1.3),
		Vector3(x, 1.2, 0),
		CANOPY_CREAM
	)

	for i in range(3):
		var item_x: float = (
			x - 0.5 + float(i) * 0.5
		)

		V.box(
			extensions_root,
			Vector3(0.38, 0.12, 0.27),
			Vector3(item_x, 1.35, 0),
			Color("#E8A58D")
		)

		V.box(
			extensions_root,
			Vector3(0.3, 0.025, 0.03),
			Vector3(item_x, 1.43, 0),
			Color("#F4D1BB")
		)

	# Небольшой деревянный бортик
	V.box(
		extensions_root,
		Vector3(2.1, 0.16, 0.1),
		Vector3(x, 1.32, -0.62),
		DARK_WOOD
	)


func _find_player() -> void:
	if is_instance_valid(player):
		return

	var main := get_parent()

	if main != null:
		player = main.get_node_or_null("Player") as Node3D


func _process(delta: float) -> void:
	clock += delta
	_find_player()

	if not is_instance_valid(player):
		return

	var p: Vector3 = player.global_position
	var distance: float = Vector2(
		p.x - S.MARKET.x,
		p.z - S.MARKET.z
	).length()

	var nearby: bool = distance <= LABEL_DISTANCE

	title_label.visible = nearby
	status.visible = nearby
	stock_label.visible = nearby

	# Подробная информация только совсем рядом
	speed_label.visible = distance <= 2.8

	if is_instance_valid(hanging_sign):
		hanging_sign.rotation.z = (
			sin(clock * 0.8) * 0.015
		)
