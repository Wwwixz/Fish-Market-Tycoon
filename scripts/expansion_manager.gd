
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const RADIUS := 1.25
const LABEL_DISTANCE := 4.0
const INFO_DISTANCE := 2.8

var state: Node
var player: Node3D
var world: Node

var pads: Array[Node3D] = []
var labels: Array[Label3D] = []
var inside: Array[bool] = [false, false, false]

var land_root: Node3D
var land_labels: Array[Label3D] = []

var clock: float = 0.0

var colors := [
	Color("#72B6A1"),
	Color("#7EA7D4"),
	Color("#D5A96C")
]


func setup(game_state: Node, game_player: Node3D) -> void:
	state = game_state
	player = game_player


func _ready() -> void:
	land_root = Node3D.new()
	land_root.name = "ExpandedLand"
	add_child(land_root)

	for i in range(3):
		_build_pad(i)

	if state != null:
		state.changed.connect(refresh)
		state.expansion_purchased.connect(_on_purchase)
		refresh()
		_build_land()


func _build_pad(index: int) -> void:
	var pad := Node3D.new()
	pad.name = "ExpansionPad_%d" % index
	pad.position = S.EXPANSION_POSITIONS[index]
	add_child(pad)
	pads.append(pad)

	V.box(
		pad,
		Vector3(2.8, 0.15, 2.8),
		Vector3(0, 0.43, 0),
		Color("#34464A")
	)

	V.box(
		pad,
		Vector3(2.55, 0.12, 2.55),
		Vector3(0, 0.55, 0),
		colors[index]
	)

	for x in [-1.2, 1.2]:
		V.box(
			pad,
			Vector3(0.09, 0.09, 2.5),
			Vector3(x, 0.66, 0),
			Color("#E8F2E9")
		)

	for z in [-1.2, 1.2]:
		V.box(
			pad,
			Vector3(2.5, 0.09, 0.09),
			Vector3(0, 0.66, z),
			Color("#E8F2E9")
		)

	var icon_root := Node3D.new()
	icon_root.name = "Icon"
	icon_root.position = Vector3(0, 1.3, 0)
	pad.add_child(icon_root)

	match index:
		0:
			V.box(
				icon_root,
				Vector3(1.1, 0.65, 0.7),
				Vector3.ZERO,
				Color("#C68F5F")
			)

			V.box(
				icon_root,
				Vector3(1.4, 0.15, 1.0),
				Vector3(0, 0.42, 0),
				Color("#F0D7AE")
			)

		1:
			V.box(
				icon_root,
				Vector3(0.9, 0.6, 0.65),
				Vector3.ZERO,
				Color("#527F91")
			)

			V.box(
				icon_root,
				Vector3(0.6, 0.22, 0.06),
				Vector3(0, 0.1, -0.35),
				Color("#B3E5C0")
			)

		2:
			V.box(
				icon_root,
				Vector3(1.3, 0.22, 1.0),
				Vector3.ZERO,
				Color("#79AC74")
			)

			V.cylinder(
				icon_root,
				0.12,
				0.8,
				Vector3(0, 0.48, 0),
				Color("#805D42")
			)

			V.sphere(
				icon_root,
				0.42,
				Vector3(0, 1.0, 0),
				Color("#5B9B69")
			)

	var label_node := V.label(
		pad,
		S.EXPANSION_NAMES[index],
		Vector3(0, 2.6, 0),
		30
	)

	label_node.visible = false
	labels.append(label_node)


func refresh() -> void:
	if state == null:
		return

	for i in range(mini(3, labels.size())):
		labels[i].text = S.EXPANSION_NAMES[i]


func _find_world() -> void:
	if is_instance_valid(world):
		return

	var main := get_parent()

	if main != null:
		world = main.get_node_or_null("World")


func _distance_to_hire() -> float:
	if not is_instance_valid(world):
		return INF

	var positions: Array = world.get("hire_positions")
	var p: Vector3 = player.global_position
	var result: float = INF

	for pos in positions:
		var distance: float = Vector2(
			p.x - pos.x,
			p.z - pos.z
		).length()

		result = minf(result, distance)

	return result


func _distance_to_upgrade() -> float:
	var main := get_parent()

	if main == null:
		return INF

	var manager := main.get_node_or_null("UpgradeManager")

	if manager == null:
		return INF

	var positions: Array = S.UPGRADE_POSITIONS
	var p: Vector3 = player.global_position
	var result: float = INF

	for pos in positions:
		var distance: float = Vector2(
			p.x - pos.x,
			p.z - pos.z
		).length()

		result = minf(result, distance)

	return result


func _show_info(index: int) -> void:
	if not is_instance_valid(world):
		return

	var panel: PanelContainer = world.get("info_panel")
	var title: Label = world.get("info_title")
	var description: Label = world.get("info_description")
	var price_label: Label = world.get("info_price")

	if not is_instance_valid(panel):
		return

	var level: int = state.expansion_levels[index]
	var max_level: int = S.EXPANSION_MAX_LEVELS[index]

	title.text = S.EXPANSION_NAMES[index]

	description.text = (
        "Уровень %d из %d"
		% [level, max_level]
	)

	if level >= max_level:
		price_label.text = "Максимальный уровень"
		price_label.add_theme_color_override(
			"font_color",
			Color("#9DD7AA")
		)
	else:
		var price: int = state.expansion_prices[index]

		if state.coins >= price:
			price_label.text = "%d монет · Доступно" % price
			price_label.add_theme_color_override(
				"font_color",
				Color("#9DD7AA")
			)
		else:
			price_label.text = (
                "%d монет · Не хватает %d"
				% [price, price - state.coins]
			)

			price_label.add_theme_color_override(
				"font_color",
				Color("#E3A39A")
			)

	panel.visible = true


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(player):
		return

	_find_world()
	clock += delta

	var nearest_index: int = -1
	var nearest_distance: float = INF

	var p: Vector3 = player.global_position

	for i in range(3):
		var pad: Node3D = pads[i]
		var pos: Vector3 = pad.global_position

		var distance: float = Vector2(
			p.x - pos.x,
			p.z - pos.z
		).length()

		labels[i].visible = distance <= LABEL_DISTANCE

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i

		var entered: bool = distance < RADIUS

		if entered and not inside[i]:
			inside[i] = true
			_try_buy(i)
		elif not entered:
			inside[i] = false

		var icon_node: Node3D = pad.get_node("Icon")

		icon_node.position.y = (
			1.3 + sin(clock * 2.0 + i) * 0.1
		)

		icon_node.rotation.y += delta * 0.4

	_update_land_labels()

	if nearest_index < 0:
		return

	if nearest_distance > INFO_DISTANCE:
		return

	if nearest_distance >= _distance_to_hire():
		return

	if nearest_distance >= _distance_to_upgrade():
		return

	_show_info(nearest_index)


func _try_buy(index: int) -> void:
	if (
		state.expansion_levels[index]
		>= S.EXPANSION_MAX_LEVELS[index]
	):
		state.notice.emit("Уже максимальный уровень!")
		return

	if state.buy_expansion(index):
		return

	var missing: int = (
		state.expansion_prices[index] - state.coins
	)

	state.notice.emit(
		"Не хватает %d монет!" % missing
	)


func _on_purchase(index: int, level: int) -> void:
	V.popup(
		self,
		level,
		"⬆",
		Color("#A9E5B7"),
		S.EXPANSION_POSITIONS[index]
	)

	var pad: Node3D = pads[index]

	var tween := create_tween()

	tween.tween_property(
		pad,
		"scale",
		Vector3(1.12, 1.0, 1.12),
		0.12
	)

	tween.tween_property(
		pad,
		"scale",
		Vector3.ONE,
		0.2
	)

	if index == 2:
		_build_land()


func _build_land() -> void:
	for child in land_root.get_children():
		child.queue_free()

	land_labels.clear()

	var level: int = state.expansion_levels[2]

	if level <= 0:
		return

	var center := Vector3(-11, 0, 11)

	V.box(
		land_root,
		Vector3(10.0, 0.2, 7.0),
		center + Vector3(0, 0.27, 0),
		Color("#B5C78C")
	)

	V.box(
		land_root,
		Vector3(8.0, 0.12, 5.2),
		center + Vector3(0, 0.4, 0),
		Color("#DCC8A6")
	)

	V.box(
		land_root,
		Vector3(3.4, 1.0, 1.5),
		center + Vector3(0, 1.0, -1.1),
		Color("#A67E59")
	)

	V.box(
		land_root,
		Vector3(4.0, 0.2, 2.2),
		center + Vector3(0, 1.6, -1.1),
		Color("#6F9D92")
	)

	var land_title := V.label(
		land_root,
		"ТОРГОВАЯ ЗОНА",
		center + Vector3(0, 3.1, -1.1),
		30
	)

	land_title.visible = false
	land_labels.append(land_title)

	if level >= 2:
		for i in range(3):
			var x: float = -2.7 + float(i) * 2.7

			V.box(
				land_root,
				Vector3(1.8, 0.7, 1.0),
				center + Vector3(x, 0.8, 2.0),
				Color("#C19A6F")
			)

			V.box(
				land_root,
				Vector3(2.0, 0.15, 1.2),
				center + Vector3(x, 1.2, 2.0),
				Color("#E4D3B3")
			)

			var stall_label := V.label(
				land_root,
				"РЫБА",
				center + Vector3(x, 1.9, 2.0),
				24
			)

			stall_label.visible = false
			land_labels.append(stall_label)


func _update_land_labels() -> void:
	var p: Vector3 = player.global_position

	for label_node in land_labels:
		if not is_instance_valid(label_node):
			continue

		var pos: Vector3 = label_node.global_position

		var distance: float = Vector2(
			p.x - pos.x,
			p.z - pos.z
		).length()

		label_node.visible = distance <= LABEL_DISTANCE
