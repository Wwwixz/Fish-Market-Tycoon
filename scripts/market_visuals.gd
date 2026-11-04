
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

var state: Node
var market_root: Node3D
var display_root: Node3D
var queue_root: Node3D
var extensions_root: Node3D

var status: Label3D
var stock_label: Label3D
var speed_label: Label3D

var last_capacity: int = -1
var last_stock: int = -1
var last_market_level: int = -1

func setup(game_state: Node) -> void:
	state = game_state

func _ready() -> void:
	_build_market()
	state.changed.connect(refresh)
	refresh()

func _build_market() -> void:
	market_root = Node3D.new()
	market_root.name = "FishMarket"
	market_root.position = S.MARKET
	add_child(market_root)

	V.box(
		market_root, Vector3(4.8, 0.22, 3.1),
		Vector3(0, 0.18, 0),
		Color("#BFA78B")
	)

	V.box(
		market_root, Vector3(3.6, 1.0, 1.0),
		Vector3(0, 0.75, 0),
		Color("#987150")
	)

	V.box(
		market_root, Vector3(3.9, 0.15, 1.2),
		Vector3(0, 1.32, 0),
		Color("#E4C89E")
	)

	for x in [-1.9, 1.9]:
		V.box(
			market_root, Vector3(0.13, 3.0, 0.13),
			Vector3(x, 1.6, 0),
			Color("#76543F")
		)

	V.box(
		market_root, Vector3(4.4, 0.2, 2.5),
		Vector3(0, 3.0, 0),
		Color("#E7D4B1")
	)

	for i in range(5):
		V.box(
			market_root, Vector3(0.7, 0.05, 2.55),
			Vector3(-1.7 + float(i) * 0.85, 3.13, 0),
			(
				Color("#6E9E94")
				if i % 2 == 0
				else Color("#F2E2C7")
			)
		)

	V.box(
		market_root, Vector3(0.7, 0.42, 0.55),
		Vector3(1.2, 1.62, 0),
		Color("#456F73")
	)

	V.box(
		market_root, Vector3(0.5, 0.2, 0.05),
		Vector3(1.2, 1.72, -0.29),
		Color("#A9E3B9")
	)

	V.box(
		market_root, Vector3(2.0, 0.12, 0.8),
		Vector3(-0.65, 1.46, 0),
		Color("#D3DEE0")
	)

	display_root = Node3D.new()
	display_root.position = Vector3(-0.65, 1.56, 0)
	market_root.add_child(display_root)

	extensions_root = Node3D.new()
	market_root.add_child(extensions_root)

	queue_root = Node3D.new()
	queue_root.name = "QueueMarkers"
	add_child(queue_root)

	V.label(
		market_root, "РЫБНЫЙ МАГАЗИН",
		Vector3(0, 3.8, 0), 42
	)

	status = V.label(
		market_root, "",
		Vector3(0, 4.35, 0), 27
	)

	stock_label = V.label(
		market_root, "",
		Vector3(0, 2.45, 0), 28
	)

	speed_label = V.label(
		market_root, "",
		Vector3(0, 4.85, 0), 24
	)

func refresh() -> void:
	if state == null:
		return

	status.text = "ОЧЕРЕДЬ: %d/%d" % [
		state.market_queue,
		state.market_capacity()
	]

	stock_label.text = "ФИЛЕ: %d | %d МОНЕТ" % [
		state.fillet_box,
		state.fillet_price()
	]

	speed_label.text = "КАССА УР. %d | %.1f СЕК" % [
		state.expansion_levels[1],
		state.customer_service_duration()
	]

	if last_stock != state.fillet_box:
		last_stock = state.fillet_box
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
			0.09 + float(row) * 0.17,
			0
		)
		display_root.add_child(fillet)

		V.box(
			fillet, Vector3(0.45, 0.13, 0.3),
			Vector3.ZERO, Color("#F2A98B")
		)

		V.box(
			fillet, Vector3(0.37, 0.025, 0.035),
			Vector3(0, 0.08, 0),
			Color("#FFE0C2")
		)

func _refresh_queue() -> void:
	for child in queue_root.get_children():
		child.queue_free()

	for i in range(state.market_capacity()):
		var marker := Node3D.new()
		marker.position = S.MARKET + Vector3(
			0, 0, 2.0 + float(i) * 1.25
		)
		queue_root.add_child(marker)

		V.box(
			marker, Vector3(1.5, 0.05, 1.0),
			Vector3(0, 0.27, 0),
			Color("#7FAE9A")
		)

		V.label(
			marker, str(i + 1),
			Vector3(0, 0.5, 0), 25
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
		Color("#A67D58")
	)

	V.box(
		extensions_root,
		Vector3(2.1, 0.13, 1.3),
		Vector3(x, 1.2, 0),
		Color("#E7CFA9")
	)

	for i in range(3):
		V.box(
			extensions_root,
			Vector3(0.38, 0.12, 0.27),
			Vector3(x - 0.5 + float(i) * 0.5, 1.35, 0),
			Color("#F3AC90")
		)
