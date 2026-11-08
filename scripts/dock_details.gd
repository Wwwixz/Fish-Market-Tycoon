
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const WOOD := Color("#947357")
const DARK_WOOD := Color("#654C3B")
const ROPE := Color("#C5AD84")
const METAL := Color("#667C7B")
const RED := Color("#C76F62")
const WHITE := Color("#E7DECB")

var time_passed: float = 0.0
var water_details: Array[Node3D] = []


func _ready() -> void:
	_create_dock_details(S.FISHING)
	_create_dock_details(S.CASH)
	_create_water_details()
	preload("res://scripts/static_batch.gd").build(self, water_details)


func _create_dock_details(center: Vector3) -> void:
	var root := Node3D.new()
	root.position = center
	add_child(root)

	for x in [-2.25, 2.25]:
		for z in [-2.25, 2.25]:
			_make_post(root, Vector3(x, 0, z))

	for x in [-2.25, 2.25]:
		_make_rope(
			root,
			Vector3(x, 1.25, -2.25),
			Vector3(x, 1.25, 2.25)
		)

	_make_lamp(
		root,
		Vector3(-2.25, 0, -2.25)
	)

	_make_lifebuoy(
		root,
		Vector3(2.25, 1.3, 0)
	)

	_make_barrel(
		root,
		Vector3(-1.65, 0.55, 1.7)
	)

	_make_crate(
		root,
		Vector3(1.55, 0.65, 1.7)
	)

	_make_bollard(
		root,
		Vector3(1.7, 0.55, -1.7)
	)

	_make_fishing_nets(root)
	_make_rope_coil(root)


func _make_post(
	parent: Node3D,
	pos: Vector3
) -> void:
	V.box(
		parent,
		Vector3(0.28, 1.8, 0.28),
		pos + Vector3(0, 0.65, 0),
		DARK_WOOD
	)

	V.box(
		parent,
		Vector3(0.38, 0.15, 0.38),
		pos + Vector3(0, 1.58, 0),
		WOOD
	)

	V.box(
		parent,
		Vector3(0.3, 0.08, 0.3),
		pos + Vector3(0, 1.69, 0),
		METAL
	)


func _make_rope(
	parent: Node3D,
	start: Vector3,
	finish: Vector3
) -> void:
	var segments := 12

	for i in range(segments):
		var t1 := float(i) / float(segments)
		var t2 := float(i + 1) / float(segments)

		var a := start.lerp(finish, t1)
		var b := start.lerp(finish, t2)

		a.y -= sin(t1 * PI) * 0.3
		b.y -= sin(t2 * PI) * 0.3

		var middle := (a + b) * 0.5
		var direction := b - a

		var rope := V.cylinder(
			parent,
			0.035,
			direction.length(),
			middle,
			ROPE
		)

		rope.quaternion = Quaternion(
			Vector3.UP,
			direction.normalized()
		)


func _make_lamp(
	parent: Node3D,
	pos: Vector3
) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	V.cylinder(
		root,
		0.09,
		2.5,
		Vector3(0, 1.75, 0),
		METAL
	)

	V.box(
		root,
		Vector3(0.65, 0.12, 0.65),
		Vector3(0, 3.05, 0),
		DARK_WOOD
	)

	V.box(
		root,
		Vector3(0.45, 0.5, 0.45),
		Vector3(0, 2.75, 0),
		Color("#D4B98B")
	)

	V.box(
		root,
		Vector3(0.7, 0.12, 0.7),
		Vector3(0, 3.3, 0),
		DARK_WOOD
	)

	for x in [-0.23, 0.23]:
		V.box(
			root,
			Vector3(0.05, 0.53, 0.05),
			Vector3(x, 2.75, 0),
			METAL
		)

	for z in [-0.23, 0.23]:
		V.box(
			root,
			Vector3(0.05, 0.53, 0.05),
			Vector3(0, 2.75, z),
			METAL
		)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.75, 0)
	light.light_color = Color("#E8C79C")
	light.light_energy = 0.08
	light.omni_range = 2.5
	light.shadow_enabled = false
	root.add_child(light)


func _make_lifebuoy(
	parent: Node3D,
	pos: Vector3
) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.x = PI / 2.0
	parent.add_child(root)

	for i in range(16):
		var angle := TAU * float(i) / 16.0

		var color := WHITE

		if i % 4 == 0 or i % 4 == 1:
			color = RED

		V.sphere(
			root,
			0.13,
			Vector3(
				cos(angle) * 0.43,
				0,
				sin(angle) * 0.43
			),
			color
		)


func _make_barrel(
	parent: Node3D,
	pos: Vector3
) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	V.cylinder(
		root,
		0.38,
		0.85,
		Vector3.ZERO,
		WOOD
	)

	for y in [-0.3, 0.3]:
		V.cylinder(
			root,
			0.4,
			0.08,
			Vector3(0, y, 0),
			METAL
		)

	V.cylinder(
		root,
		0.37,
		0.07,
		Vector3(0, 0.45, 0),
		DARK_WOOD
	)


func _make_crate(
	parent: Node3D,
	pos: Vector3
) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	V.box(
		root,
		Vector3(0.9, 0.7, 0.8),
		Vector3.ZERO,
		WOOD
	)

	for x in [-0.35, 0.35]:
		V.box(
			root,
			Vector3(0.08, 0.75, 0.85),
			Vector3(x, 0, 0),
			DARK_WOOD
		)

	for z in [-0.3, 0.3]:
		V.box(
			root,
			Vector3(0.95, 0.1, 0.08),
			Vector3(0, 0, z),
			DARK_WOOD
		)

	V.box(
		root,
		Vector3(0.95, 0.08, 0.85),
		Vector3(0, 0.38, 0),
		ROPE
	)


func _make_bollard(
	parent: Node3D,
	pos: Vector3
) -> void:
	V.cylinder(
		parent,
		0.22,
		0.55,
		pos + Vector3(0, 0.27, 0),
		METAL
	)

	V.box(
		parent,
		Vector3(0.75, 0.15, 0.22),
		pos + Vector3(0, 0.57, 0),
		METAL.darkened(0.15)
	)


func _make_fishing_nets(parent: Node3D) -> void:
	var net := Node3D.new()
	net.position = Vector3(-1.25, 0.68, 0.15)
	parent.add_child(net)

	for i in range(6):
		var offset := -0.55 + float(i) * 0.22

		V.box(
			net,
			Vector3(1.25, 0.025, 0.025),
			Vector3(0, 0.03, offset),
			Color("#9BAE9D")
		)

		V.box(
			net,
			Vector3(0.025, 0.025, 1.25),
			Vector3(offset, 0.03, 0),
			Color("#9BAE9D")
		)

	for x in [-0.65, 0.65]:
		for z in [-0.65, 0.65]:
			V.sphere(
				net,
				0.1,
				Vector3(x, 0.08, z),
				Color("#C8A36E")
			)


func _make_rope_coil(parent: Node3D) -> void:
	var coil := Node3D.new()
	coil.position = Vector3(0.95, 0.65, 0.9)
	parent.add_child(coil)

	for i in range(3):
		var ring := Node3D.new()
		ring.position.y = float(i) * 0.055
		coil.add_child(ring)

		for j in range(16):
			var angle := TAU * float(j) / 16.0

			V.sphere(
				ring,
				0.055,
				Vector3(
					cos(angle) * 0.32,
					0,
					sin(angle) * 0.32
				),
				ROPE
			)


func _create_water_details() -> void:
	for dock_center in [S.FISHING, S.CASH]:
		for i in range(12):
			var angle := TAU * float(i) / 12.0

			var wave := Node3D.new()
			wave.position = Vector3(
				dock_center.x + cos(angle) * 3.2,
				-0.43,
				dock_center.z + sin(angle) * 3.2
			)

			wave.rotation.y = angle
			add_child(wave)

			var foam := V.box(
				wave,
				Vector3(0.8, 0.025, 0.07),
				Vector3.ZERO,
				Color("#B8D5D0")
			)

			foam.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)

			water_details.append(wave)


func _process(delta: float) -> void:
	time_passed += delta

	for i in range(water_details.size()):
		var wave := water_details[i]

		if not is_instance_valid(wave):
			continue

		wave.position.y = (
			-0.43
			+ sin(time_passed * 2.0 + float(i)) * 0.025
		)

		wave.scale.x = (
			1.0
			+ sin(time_passed * 1.5 + float(i)) * 0.15
		)
