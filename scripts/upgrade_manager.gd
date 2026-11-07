
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const ACTIVATION_RADIUS := 1.25
const INFO_DISTANCE := 3.0
const LABEL_DISTANCE := 4.0

var state: Node
var player: Node3D
var world: Node

var pads: Array[Node3D] = []
var labels: Array[Label3D] = []
var inside: Array[bool] = [false, false, false, false]

var clock: float = 0.0

var colors := [
	Color("#D59C5B"),
	Color("#5A9CC5"),
	Color("#9B83BD"),
	Color("#67AE82")
]


func setup(game_state: Node, game_player: Node3D) -> void:
	state = game_state
	player = game_player


func _ready() -> void:
	for i in range(4):
		_build_pad(i)
		inside[i] = Vector2(player.position.x - S.UPGRADE_POSITIONS[i].x, player.position.z - S.UPGRADE_POSITIONS[i].z).length() < ACTIVATION_RADIUS

	if state != null:
		state.changed.connect(refresh)
		state.upgrade_purchased.connect(_on_purchased)
		refresh()


func _build_pad(role: int) -> void:
	var pad := Node3D.new()
	pad.name = "UpgradePad_%d" % role
	pad.position = S.UPGRADE_POSITIONS[role]
	add_child(pad)
	pads.append(pad)

	V.box(
		pad,
		Vector3(2.75, 0.16, 2.75),
		Vector3(0, 0.43, 0),
		Color("#2C4149")
	)

	V.box(
		pad,
		Vector3(2.5, 0.12, 2.5),
		Vector3(0, 0.56, 0),
		colors[role].darkened(0.25)
	)

	for z in [-1.24, 1.24]:
		V.box(
			pad,
			Vector3(2.55, 0.08, 0.08),
			Vector3(0, 0.66, z),
			colors[role].lightened(0.3)
		)

	for x in [-1.24, 1.24]:
		V.box(
			pad,
			Vector3(0.08, 0.08, 2.55),
			Vector3(x, 0.66, 0),
			colors[role].lightened(0.3)
		)

	V.cylinder(
		pad,
		0.68,
		0.18,
		Vector3(0, 0.76, 0),
		Color("#E7DDC7")
	)

	var prop := Node3D.new()
	prop.name = "UpgradeIcon"
	prop.position = Vector3(0, 1.38, 0)
	pad.add_child(prop)

	match role:
		0:
			_machine_icon(prop)
		1:
			_speed_icon(prop)
		2:
			_cargo_icon(prop)
		3:
			_money_icon(prop)

	var label_node := V.label(
		pad,
		S.UPGRADE_NAMES[role],
		Vector3(0, 2.4, 0),
		30
	)

	label_node.visible = false
	labels.append(label_node)


func _machine_icon(parent: Node3D) -> void:
	V.box(
		parent,
		Vector3(1.05, 0.6, 0.75),
		Vector3.ZERO,
		Color("#527D82")
	)

	V.box(
		parent,
		Vector3(1.18, 0.13, 0.87),
		Vector3(0, 0.37, 0),
		Color("#C6D8D5")
	)

	for x in [-0.3, 0.0, 0.3]:
		V.cylinder(
			parent,
			0.1,
			0.17,
			Vector3(x, 0.48, 0),
			Color("#F0B66F")
		)


func _speed_icon(parent: Node3D) -> void:
	V.box(
		parent,
		Vector3(0.45, 0.2, 0.85),
		Vector3(-0.24, 0, 0),
		Color("#F0E8D8")
	)

	V.box(
		parent,
		Vector3(0.45, 0.2, 0.85),
		Vector3(0.3, 0.25, 0),
		Color("#F0E8D8")
	)

	for i in range(3):
		V.box(
			parent,
			Vector3(0.08, 0.08, 0.55),
			Vector3(-0.75 - i * 0.13, 0, 0),
			Color("#9AD5EC")
		)


func _cargo_icon(parent: Node3D) -> void:
	V.box(
		parent,
		Vector3(1.1, 0.7, 0.85),
		Vector3.ZERO,
		Color("#AA7D56")
	)

	for x in [-0.4, 0.4]:
		V.box(
			parent,
			Vector3(0.1, 0.75, 0.9),
			Vector3(x, 0, 0),
			Color("#76543E")
		)

	for x in [-0.28, 0.0, 0.28]:
		V.box(
			parent,
			Vector3(0.23, 0.12, 0.4),
			Vector3(x, 0.42, 0),
			Color("#F0A98E")
		)


func _money_icon(parent: Node3D) -> void:
	for i in range(3):
		V.cylinder(
			parent,
			0.4,
			0.13,
			Vector3(0, -0.15 + i * 0.15, 0),
			Color("#F3C45A")
		)

	V.cylinder(
		parent,
		0.24,
		0.14,
		Vector3(0, 0.16, 0),
		Color("#DDA13B")
	)


func refresh() -> void:
	if state == null:
		return

	for i in range(mini(4, labels.size())):
		labels[i].text = S.UPGRADE_NAMES[i]


func _find_world() -> void:
	if is_instance_valid(world):
		return

	var main := get_parent()

	if main != null:
		world = main.get_node_or_null("World")


func _hire_distance() -> float:
	if not is_instance_valid(world):
		return INF

	if not is_instance_valid(player):
		return INF

	var positions: Array = world.get("hire_positions")

	var closest: float = INF
	var player_pos: Vector3 = player.global_position

	for pos in positions:
		var distance: float = Vector2(
			player_pos.x - pos.x,
			player_pos.z - pos.z
		).length()

		closest = minf(closest, distance)

	return closest


func _show_shared_info(role: int) -> void:
	if not is_instance_valid(world):
		return

	var panel: PanelContainer = world.get("info_panel")
	var title: Label = world.get("info_title")
	var description: Label = world.get("info_description")
	var price_label: Label = world.get("info_price")

	if not is_instance_valid(panel):
		return

	var level: int = state.upgrade_levels[role]
	var price: int = state.upgrade_prices[role]

	title.text = S.UPGRADE_NAMES[role]
	description.text = "Текущий уровень: %d" % level

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
	if state.controls_blocked:
		return

	_find_world()

	clock += delta

	var nearest_role: int = -1
	var nearest_distance: float = INF

	var player_pos: Vector3 = player.global_position

	for i in range(4):
		var pad: Node3D = pads[i]
		var pos: Vector3 = pad.global_position

		var distance: float = Vector2(
			player_pos.x - pos.x,
			player_pos.z - pos.z
		).length()

		labels[i].visible = distance <= LABEL_DISTANCE

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_role = i

		var is_near: bool = distance < ACTIVATION_RADIUS

		if is_near and not inside[i]:
			inside[i] = true
			_try_purchase(i)
		elif not is_near:
			inside[i] = false

		var icon_node: Node3D = pad.get_node("UpgradeIcon")

		icon_node.position.y = (
			1.38 + sin(clock * 2.5 + i) * 0.1
		)

		icon_node.rotation.y += delta * 0.55

	if nearest_role < 0:
		return

	if nearest_distance > INFO_DISTANCE:
		return

	if nearest_distance >= _hire_distance():
		return

	_show_shared_info(nearest_role)


func _try_purchase(role: int) -> void:
	if state.upgrade_levels[role] >= S.MAX_UPGRADE_LEVEL:
		state.notice.emit("Достигнут максимальный уровень улучшения")
		return
	if state.upgrade(role):
		return

	var missing: int = (
		state.upgrade_prices[role] - state.coins
	)

	state.notice.emit(
		"Не хватает %d монет!" % missing
	)


func _on_purchased(role: int, level: int) -> void:
	var pos: Vector3 = S.UPGRADE_POSITIONS[role]

	V.popup(
		self,
		level,
		"⬆",
		Color("#A8E5AE"),
		pos
	)

	var pad: Node3D = pads[role]

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
		0.22
	).set_trans(Tween.TRANS_BACK)
