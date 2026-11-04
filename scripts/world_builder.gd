
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const LABEL_DISTANCE := 4.0
const HIRE_INFO_DISTANCE := 2.7

var fish_label: Label3D
var machine_label: Label3D
var fillet_label: Label3D

var hire_labels: Array[Label3D] = []
var world_labels: Array[Label3D] = []
var animated_props: Array[Dictionary] = []

var player: Node3D
var current_state: Node
var time_passed: float = 0.0

var hire_positions: Array[Vector3] = []
var hire_prices: Array[int] = [0, 0, 0, 0]

var hire_names := [
	"РЫБАК",
	"ГРУЗЧИК РЫБЫ",
	"ГРУЗЧИК ФИЛЕ",
    "ПРОДАВЕЦ"
]

var hire_descriptions := [
	"Автоматически ловит рыбу",
	"Переносит рыбу на станок",
	"Переносит филе к кассе",
    "Продаёт готовую продукцию"
]

var info_layer: CanvasLayer
var info_panel: PanelContainer
var info_title: Label
var info_description: Label
var info_price: Label


func _ready() -> void:
	_environment()
	_island()
	_decorations()

	_dock(S.FISHING)
	_dock(S.CASH)

	_fishing_zone()
	_processing_zone()
	_cash_zone()

	fish_label = _storage(
		S.FISH_BOX,
		"СКЛАД РЫБЫ",
		Color("#729EAD")
	)

	fillet_label = _storage(
		S.FILLET_BOX,
		"СКЛАД ФИЛЕ",
		Color("#B99173")
	)

	_machine()

	_hire_zone(
		S.HIRE_FISHER,
		0,
		Color("#638FA7")
	)

	_hire_zone(
		S.HIRE_FISH_CARRIER,
		1,
		Color("#B39470")
	)

	_hire_zone(
		S.HIRE_FILLET_CARRIER,
		2,
		Color("#9686A8")
	)

	_hire_zone(
		S.HIRE_SELLER,
		3,
		Color("#719C82")
	)

	_build_info_panel()


func _environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "MainSun"
	light.add_to_group("main_sun")
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_color = Color("#EADFCB")
	light.light_energy = 0.45
	light.shadow_enabled = true
	add_child(light)

	var world := WorldEnvironment.new()
	world.name = "MainWorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#91B4B6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#AABCB2")
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world.environment = env
	add_child(world)


func _island() -> void:
	V.box(
		self,
		Vector3(100, 0.3, 100),
		Vector3(0, -0.65, 0),
		Color("#729FA7")
	)

	V.box(
		self,
		Vector3(39, 0.5, 32),
		Vector3(0, -0.2, 5),
		Color("#C8B58F")
	)

	V.box(
		self,
		Vector3(35, 0.1, 23),
		Vector3(0, 0.1, 8),
		Color("#819C78")
	)

	V.box(
		self,
		Vector3(21, 0.08, 2.6),
		Vector3(0, 0.2, 3),
		Color("#AA9C83")
	)

	V.box(
		self,
		Vector3(2.7, 0.08, 14),
		Vector3(-5, 0.2, -3),
		Color("#AA9C83")
	)

	V.box(
		self,
		Vector3(2.7, 0.08, 14),
		Vector3(9, 0.2, -3),
		Color("#AA9C83")
	)


func _decorations() -> void:
	for i in range(8):
		var tree := Node3D.new()
		tree.position = Vector3(
			-17.0 + float(i) * 4.7,
			0,
			17
		)
		add_child(tree)

		V.cylinder(
			tree,
			0.25,
			2.0,
			Vector3(0, 1, 0),
			Color("#79634E")
		)

		V.sphere(
			tree,
			1.2,
			Vector3(0, 2.5, 0),
			Color("#587E62")
		)

		V.sphere(
			tree,
			0.85,
			Vector3(0.5, 3.2, 0),
			Color("#739776")
		)


func _dock(pos: Vector3) -> void:
	var dock := Node3D.new()
	dock.position = pos
	add_child(dock)

	for i in range(8):
		V.box(
			dock,
			Vector3(4.2, 0.25, 0.7),
			Vector3(
				0,
				0.4,
				-2.5 + float(i) * 0.75
			),
			Color("#927457")
		)

	for x in [-1.8, 1.8]:
		for z in [-2.2, 2.2]:
			V.box(
				dock,
				Vector3(0.35, 1.7, 0.35),
				Vector3(x, -0.1, z),
				Color("#6F5845")
			)


func _platform(
	pos: Vector3,
	color: Color,
	size: float = 2.6
) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	V.box(
		root,
		Vector3(size + 0.3, 0.12, size + 0.3),
		Vector3(0, 0.51, 0),
		Color("#344B4C")
	)

	V.box(
		root,
		Vector3(size, 0.1, size),
		Vector3(0, 0.63, 0),
		color
	)

	var edge := color.lightened(0.12)
	var half: float = size * 0.5

	for z in [-half, half]:
		V.box(
			root,
			Vector3(size + 0.08, 0.06, 0.09),
			Vector3(0, 0.71, z),
			edge
		)

	for x in [-half, half]:
		V.box(
			root,
			Vector3(0.09, 0.06, size + 0.08),
			Vector3(x, 0.71, 0),
			edge
		)

	for x in [-half, half]:
		for z in [-half, half]:
			V.box(
				root,
				Vector3(0.24, 0.12, 0.24),
				Vector3(x, 0.76, z),
				Color("#BDB5A2")
			)

	return root


func _floating_prop(
	parent: Node3D,
	offset: Vector3
) -> Node3D:
	var holder := Node3D.new()
	holder.position = offset
	parent.add_child(holder)

	animated_props.append({
		"node": holder,
		"base_y": offset.y,
		"phase": float(animated_props.size()) * 1.7
	})

	return holder


func _fish_model(
	parent: Node3D,
	color: Color,
	scale_value: float = 1.0
) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * scale_value
	parent.add_child(root)

	var body := V.sphere(
		root,
		0.32,
		Vector3.ZERO,
		color
	)
	body.scale = Vector3(1.65, 0.7, 0.85)

	var tail := V.box(
		root,
		Vector3(0.34, 0.42, 0.1),
		Vector3(-0.56, 0, 0),
		color.darkened(0.15)
	)
	tail.rotation.z = 0.6

	V.sphere(
		root,
		0.045,
		Vector3(0.38, 0.08, -0.2),
		Color("#263B40")
	)

	return root


func _crate_model(
	parent: Node3D,
	color: Color
) -> void:
	V.box(
		parent,
		Vector3(0.95, 0.52, 0.72),
		Vector3.ZERO,
		color
	)

	for x in [-0.35, 0.35]:
		V.box(
			parent,
			Vector3(0.08, 0.56, 0.76),
			Vector3(x, 0, 0),
			color.darkened(0.22)
		)

	V.box(
		parent,
		Vector3(1, 0.08, 0.78),
		Vector3(0, 0.29, 0),
		color.lightened(0.12)
	)


func _add_world_label(
	parent: Node3D,
	value: String,
	pos: Vector3,
	size: int = 30
) -> Label3D:
	var node: Label3D = V.label(
		parent,
		value,
		pos,
		size
	)

	node.visible = false
	node.no_depth_test = false
	world_labels.append(node)

	return node


func _fishing_zone() -> void:
	var root := _platform(
		S.FISHING,
		Color("#6A9CB1")
	)

	var prop := _floating_prop(
		root,
		Vector3(0, 1.7, 0)
	)

	_fish_model(
		prop,
		Color("#91B8BF"),
		0.9
	)

	_add_world_label(
		root,
		"РЫБАЛКА",
		Vector3(0, 2.7, 0)
	)


func _processing_zone() -> void:
	var root := _platform(
		S.MACHINE_ZONE,
		Color("#BE986E")
	)

	var prop := _floating_prop(
		root,
		Vector3(0, 1.65, 0)
	)

	V.box(
		prop,
		Vector3(1.1, 0.12, 0.65),
		Vector3.ZERO,
		Color("#99785B")
	)

	V.box(
		prop,
		Vector3(0.65, 0.15, 0.34),
		Vector3(0, 0.14, 0),
		Color("#D6A08E")
	)

	_add_world_label(
		root,
		"РАЗДЕЛКА",
		Vector3(0, 2.7, 0)
	)


func _cash_zone() -> void:
	var root := _platform(
		S.CASH,
		Color("#78A087")
	)

	var prop := _floating_prop(
		root,
		Vector3(0, 1.75, 0)
	)

	V.cylinder(
		prop,
		0.42,
		0.12,
		Vector3.ZERO,
		Color("#D9B96C")
	)

	_add_world_label(
		root,
		"ПРОДАЖА",
		Vector3(0, 2.75, 0)
	)


func _storage(
	pos: Vector3,
	title: String,
	color: Color
) -> Label3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	V.box(
		root,
		Vector3(2.6, 1, 2),
		Vector3(0, 0.65, 0),
		Color("#927457")
	)

	V.box(
		root,
		Vector3(2.8, 0.2, 2.2),
		Vector3(0, 1.2, 0),
		color
	)

	for x in [-1.2, 1.2]:
		for z in [-0.9, 0.9]:
			V.box(
				root,
				Vector3(0.14, 0.85, 0.14),
				Vector3(x, 0.72, z),
				Color("#B5B3A3")
			)

	return _add_world_label(
		root,
		title,
		Vector3(0, 2.25, 0)
	)


func _machine() -> void:
	var machine := Node3D.new()
	machine.position = S.MACHINE
	add_child(machine)

	V.box(
		machine,
		Vector3(4, 1.4, 2.7),
		Vector3(0, 0.9, 0),
		Color("#829B98")
	)

	V.box(
		machine,
		Vector3(4.3, 0.2, 3),
		Vector3(0, 1.7, 0),
		Color("#B5BDB2")
	)

	V.box(
		machine,
		Vector3(2.7, 0.12, 1.2),
		Vector3(0, 1.85, 0),
		Color("#5D8584")
	)

	V.box(
		machine,
		Vector3(0.7, 0.5, 0.1),
		Vector3(-1.3, 1.15, 1.4),
		Color("#3E585A")
	)

	machine_label = _add_world_label(
		machine,
		"СТАНОК",
		Vector3(0, 3.75, 0)
	)


func _hire_zone(
	pos: Vector3,
	role: int,
	color: Color
) -> void:
	var root := _platform(pos, color)
	hire_positions.append(pos)

	V.cylinder(
		root,
		0.72,
		0.16,
		Vector3(0, 0.85, 0),
		Color("#C8C0AB")
	)

	var prop := _floating_prop(
		root,
		Vector3(0, 1.7, 0)
	)

	match role:
		0:
			_fish_model(
				prop,
				Color("#8BB6BE"),
				0.8
			)

		1:
			_crate_model(
				prop,
				Color("#9F8062")
			)

			var fish := _fish_model(
				prop,
				Color("#85B0BA"),
				0.45
			)
			fish.position.y = 0.36

		2:
			_crate_model(
				prop,
				Color("#987760")
			)

			for i in range(3):
				V.box(
					prop,
					Vector3(0.35, 0.1, 0.2),
					Vector3(
						-0.26 + float(i) * 0.26,
						0.36,
						0
					),
					Color("#D9A28D")
				)

		3:
			V.box(
				prop,
				Vector3(0.85, 0.48, 0.62),
				Vector3.ZERO,
				Color("#527576")
			)

			V.box(
				prop,
				Vector3(0.65, 0.23, 0.06),
				Vector3(0, 0.09, -0.34),
				Color("#94B9A1")
			)

	var title_label := _add_world_label(
		root,
		hire_names[role],
		Vector3(0, 2.75, 0),
		30
	)

	hire_labels.append(title_label)


func _build_info_panel() -> void:
	info_layer = CanvasLayer.new()
	info_layer.layer = 6
	add_child(info_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_layer.add_child(root)

	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	info_panel.set_anchors_preset(
		Control.PRESET_CENTER_BOTTOM
	)

	info_panel.offset_left = -165
	info_panel.offset_right = 165
	info_panel.offset_top = -205
	info_panel.offset_bottom = -105

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20343B", 0.95)

	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12

	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	info_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	root.add_child(info_panel)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(
		"separation",
		5
	)
	info_panel.add_child(content)

	info_title = Label.new()
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override(
		"font_size",
		18
	)
	info_title.add_theme_color_override(
		"font_color",
		Color("#F5E8D1")
	)
	content.add_child(info_title)

	info_description = Label.new()
	info_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_description.add_theme_font_size_override(
		"font_size",
		14
	)
	info_description.add_theme_color_override(
		"font_color",
		Color("#C9D9D5")
	)
	content.add_child(info_description)

	info_price = Label.new()
	info_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_price.add_theme_font_size_override(
		"font_size",
		15
	)
	content.add_child(info_price)


func refresh_hire_prices(state: Node) -> void:
	current_state = state

	for i in range(4):
		hire_prices[i] = state.prices[i]


func refresh(state: Node) -> void:
	current_state = state

	if is_instance_valid(fish_label):
		fish_label.text = "РЫБА: %d" % state.fish_box

	if is_instance_valid(fillet_label):
		fillet_label.text = "ФИЛЕ: %d" % state.fillet_box

	if is_instance_valid(machine_label):
		machine_label.text = (
            "СТАНОК: %d / %d"
			% [
				state.machine_input,
				state.machine_output
			]
		)

	refresh_hire_prices(state)


func _find_player() -> void:
	if is_instance_valid(player):
		return

	var main := get_parent()

	if main != null:
		player = main.get_node_or_null("Player") as Node3D


func _update_labels() -> void:
	_find_player()

	if not is_instance_valid(player):
		for node in world_labels:
			if is_instance_valid(node):
				node.visible = false
		return

	var player_pos: Vector3 = player.global_position

	for node in world_labels:
		if not is_instance_valid(node):
			continue

		var pos: Vector3 = node.global_position

		var distance: float = Vector2(
			player_pos.x - pos.x,
			player_pos.z - pos.z
		).length()

		node.visible = distance <= LABEL_DISTANCE

		if node.visible:
			node.transparency = 1.0 - clampf(
				(LABEL_DISTANCE - distance) / 1.0,
				0.0,
				1.0
			)


func _update_hire_info() -> void:
	if not is_instance_valid(player):
		info_panel.visible = false
		return

	var nearest: int = -1
	var best_distance: float = HIRE_INFO_DISTANCE

	var player_pos: Vector3 = player.global_position

	for i in range(hire_positions.size()):
		var pos: Vector3 = hire_positions[i]

		var distance: float = Vector2(
			player_pos.x - pos.x,
			player_pos.z - pos.z
		).length()

		if distance < best_distance:
			best_distance = distance
			nearest = i

	if nearest == -1:
		info_panel.visible = false
		return

	info_panel.visible = true

	info_title.text = hire_names[nearest]
	info_description.text = hire_descriptions[nearest]

	var price: int = hire_prices[nearest]

	if current_state != null:
		if current_state.coins >= price:
			info_price.text = "%d монет · Доступно" % price
			info_price.add_theme_color_override(
				"font_color",
				Color("#9DD7AA")
			)
		else:
			info_price.text = "%d монет · Недостаточно средств" % price
			info_price.add_theme_color_override(
				"font_color",
				Color("#E3A39A")
			)
	else:
		info_price.text = "%d монет" % price


func _process(delta: float) -> void:
	time_passed += delta

	for item in animated_props:
		var node: Node3D = item["node"]

		if not is_instance_valid(node):
			continue

		var base_y: float = item["base_y"]
		var phase: float = item["phase"]

		node.position.y = (
			base_y
			+ sin(time_passed * 2.4 + phase) * 0.12
		)

		node.rotation.y += delta * 0.55

	_update_labels()
	_update_hire_info()
