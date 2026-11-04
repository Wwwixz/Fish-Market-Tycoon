
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const WATER := Color("#729FA7")
const SAND := Color("#C8B58F")
const GRASS := Color("#819C78")
const PATH := Color("#AA9C83")
const WOOD := Color("#927457")
const DARK_WOOD := Color("#6F5845")
const METAL := Color("#829B98")

var fish_label: Label3D
var machine_label: Label3D
var fillet_label: Label3D

var hire_labels: Array[Label3D] = []
var animated_props: Array[Dictionary] = []
var time_passed: float = 0.0

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
		"РЫБАК",
		"ЛОВИТ РЫБУ",
		0,
		Color("#638FA7")
	)

	_hire_zone(
		S.HIRE_FISH_CARRIER,
		"ГРУЗЧИК РЫБЫ",
		"РЫБА -> СТАНОК",
		1,
		Color("#B39470")
	)

	_hire_zone(
		S.HIRE_FILLET_CARRIER,
		"ГРУЗЧИК ФИЛЕ",
		"ФИЛЕ -> КАССА",
		2,
		Color("#9686A8")
	)

	_hire_zone(
		S.HIRE_SELLER,
		"ПРОДАВЕЦ",
		"ПРОДАЁТ ЗАКАЗЫ",
		3,
		Color("#719C82")
	)

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
		WATER
	)

	V.box(
		self,
		Vector3(39, 0.5, 32),
		Vector3(0, -0.2, 5),
		SAND
	)

	V.box(
		self,
		Vector3(35, 0.1, 23),
		Vector3(0, 0.1, 8),
		GRASS
	)

	V.box(
		self,
		Vector3(21, 0.08, 2.6),
		Vector3(0, 0.2, 3),
		PATH
	)

	V.box(
		self,
		Vector3(2.7, 0.08, 14),
		Vector3(-5, 0.2, -3),
		PATH
	)

	V.box(
		self,
		Vector3(2.7, 0.08, 14),
		Vector3(9, 0.2, -3),
		PATH
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
			WOOD
		)

	for x in [-1.8, 1.8]:
		for z in [-2.2, 2.2]:
			V.box(
				dock,
				Vector3(0.35, 1.7, 0.35),
				Vector3(x, -0.1, z),
				DARK_WOOD
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

	var edge: Color = color.lightened(0.12)
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
	position_offset: Vector3
) -> Node3D:
	var holder := Node3D.new()
	holder.position = position_offset
	parent.add_child(holder)

	animated_props.append({
		"node": holder,
		"base_y": position_offset.y,
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
) -> Node3D:
	var crate := Node3D.new()
	parent.add_child(crate)

	V.box(
		crate,
		Vector3(0.95, 0.52, 0.72),
		Vector3.ZERO,
		color
	)

	for x in [-0.35, 0.35]:
		V.box(
			crate,
			Vector3(0.08, 0.56, 0.76),
			Vector3(x, 0, 0),
			color.darkened(0.22)
		)

	V.box(
		crate,
		Vector3(1.0, 0.08, 0.78),
		Vector3(0, 0.29, 0),
		color.lightened(0.12)
	)

	return crate

func _coin_model(parent: Node3D) -> void:
	V.cylinder(
		parent,
		0.42,
		0.12,
		Vector3.ZERO,
		Color("#D9B96C")
	)

	V.cylinder(
		parent,
		0.27,
		0.13,
		Vector3(0, 0.02, 0),
		Color("#BD9851")
	)

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

	V.label(
		root,
		"ЛОВИТЬ РЫБУ",
		Vector3(0, 2.7, 0),
		34
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

	var fillet := V.box(
		prop,
		Vector3(0.65, 0.15, 0.34),
		Vector3(0, 0.14, 0),
		Color("#D6A08E")
	)
	fillet.rotation.y = 0.2

	V.label(
		root,
		"РАЗДЕЛКА",
		Vector3(0, 2.7, 0),
		34
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

	_coin_model(prop)

	V.label(
		root,
		"ПРОДАТЬ",
		Vector3(0, 2.75, 0),
		36
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
		WOOD
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

	return V.label(
		root,
		title,
		Vector3(0, 2.25, 0),
		36
	)

func _machine() -> void:
	var machine := Node3D.new()
	machine.position = S.MACHINE
	add_child(machine)

	V.box(
		machine,
		Vector3(4, 1.4, 2.7),
		Vector3(0, 0.9, 0),
		METAL
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

	for x in [-1.48, -1.26, -1.04]:
		V.sphere(
			machine,
			0.065,
			Vector3(x, 1.15, 1.47),
			Color("#8BAE94")
		)

	machine_label = V.label(
		machine,
		"СТАНОК",
		Vector3(0, 3.75, 0),
		38
	)

func _hire_zone(
	pos: Vector3,
	title: String,
	description: String,
	role: int,
	color: Color
) -> void:
	var root := _platform(pos, color)

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

			var rod := V.cylinder(
				prop,
				0.035,
				1.5,
				Vector3(0.55, 0.3, 0),
				Color("#785E47")
			)
			rod.rotation.z = -0.3

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

			V.box(
				prop,
				Vector3(0.95, 0.1, 0.75),
				Vector3(0, -0.27, 0),
				Color("#354F50")
			)

	var title_label := V.label(
		root,
		title,
		Vector3(0, 2.75, 0),
		32
	)

	hire_labels.append(title_label)

	V.label(
		root,
		description,
		Vector3(0, 3.22, 0),
		23
	)

func refresh_hire_prices(state: Node) -> void:
	if hire_labels.size() < 4:
		return

	var names := [
		"РЫБАК",
		"ГРУЗЧИК РЫБЫ",
		"ГРУЗЧИК ФИЛЕ",
        "ПРОДАВЕЦ"
	]

	for i in range(4):
		hire_labels[i].text = (
            "%s\n%d МОНЕТ"
			% [names[i], state.prices[i]]
		)

		if state.coins >= state.prices[i]:
			hire_labels[i].modulate = Color("#E8E2D6")
		else:
			hire_labels[i].modulate = Color("#B9ACA0")

func refresh(state: Node) -> void:
	if not is_instance_valid(fish_label):
		return

	fish_label.text = "РЫБА: %d" % state.fish_box
	fillet_label.text = "ФИЛЕ: %d" % state.fillet_box

	machine_label.text = (
        "СТАНОК: %d / %d"
		% [
			state.machine_input,
			state.machine_output
		]
	)

	refresh_hire_prices(state)

func _process(delta: float) -> void:
	time_passed += delta

	for item in animated_props:
		var node: Node3D = item["node"]
		var base_y: float = item["base_y"]
		var phase: float = item["phase"]

		node.position.y = (
			base_y
			+ sin(time_passed * 2.4 + phase) * 0.12
		)

		node.rotation.y += delta * 0.55
