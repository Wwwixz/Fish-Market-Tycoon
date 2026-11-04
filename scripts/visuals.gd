
extends RefCounted

static func material(
	color: Color,
	unshaded: bool = false
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)
	parent.add_child(n)
	return n

static func sphere(
	parent: Node3D,
	radius: float,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)
	parent.add_child(n)
	return n

static func cylinder(
	parent: Node3D,
	radius: float,
	height: float,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)
	parent.add_child(n)
	return n

static func label(
	parent: Node3D,
	value: String,
	pos: Vector3,
	size: int = 44
) -> Label3D:
	var n := Label3D.new()
	n.text = value
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.008
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = Color("#F6EEE1")
	n.outline_modulate = Color("#243B42")
	n.outline_size = 9
	parent.add_child(n)
	return n

static func person(
	parent: Node3D,
	color: Color
) -> void:
	cylinder(
		parent, 0.36, 0.85,
		Vector3(0, 0.55, 0), color
	)
	sphere(
		parent, 0.32,
		Vector3(0, 1.35, 0),
		Color("#D9B18D")
	)
	box(
		parent, Vector3(0.75, 0.15, 0.75),
		Vector3(0, 1.66, 0),
		color.darkened(0.3)
	)
	box(
		parent, Vector3(0.22, 0.55, 0.26),
		Vector3(-0.18, -0.1, 0),
		Color("#253D43")
	)
	box(
		parent, Vector3(0.22, 0.55, 0.26),
		Vector3(0.18, -0.1, 0),
		Color("#253D43")
	)

static func animated_person(
	parent: Node3D,
	color: Color
) -> Dictionary:
	var body := Node3D.new()
	body.name = "AnimatedBody"
	parent.add_child(body)

	cylinder(
		body, 0.34, 0.8,
		Vector3(0, 0.75, 0), color
	)
	sphere(
		body, 0.31,
		Vector3(0, 1.42, 0),
		Color("#D9B18D")
	)
	box(
		body, Vector3(0.72, 0.13, 0.72),
		Vector3(0, 1.72, 0),
		color.darkened(0.3)
	)

	var left_arm := Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.43, 1.04, 0)
	body.add_child(left_arm)
	box(
		left_arm, Vector3(0.2, 0.62, 0.22),
		Vector3(0, -0.28, 0),
		color.darkened(0.12)
	)

	var right_arm := Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.43, 1.04, 0)
	body.add_child(right_arm)
	box(
		right_arm, Vector3(0.2, 0.62, 0.22),
		Vector3(0, -0.28, 0),
		color.darkened(0.12)
	)

	var left_leg := Node3D.new()
	left_leg.name = "LeftLeg"
	left_leg.position = Vector3(-0.18, 0.36, 0)
	body.add_child(left_leg)
	box(
		left_leg, Vector3(0.23, 0.58, 0.27),
		Vector3(0, -0.25, 0),
		Color("#253D43")
	)

	var right_leg := Node3D.new()
	right_leg.name = "RightLeg"
	right_leg.position = Vector3(0.18, 0.36, 0)
	body.add_child(right_leg)
	box(
		right_leg, Vector3(0.23, 0.58, 0.27),
		Vector3(0, -0.25, 0),
		Color("#253D43")
	)

	var cargo_anchor := Node3D.new()
	cargo_anchor.name = "CargoAnchor"
	cargo_anchor.position = Vector3(0, 0.95, -0.62)
	body.add_child(cargo_anchor)

	var crate := Node3D.new()
	crate.name = "Crate"
	cargo_anchor.add_child(crate)

	box(
		crate, Vector3(0.75, 0.5, 0.55),
		Vector3.ZERO, Color("#946D50")
	)
	box(
		crate, Vector3(0.79, 0.08, 0.6),
		Vector3(0, 0.25, 0),
		Color("#B68B60")
	)
	for x in [-0.28, 0.28]:
		box(
			crate, Vector3(0.08, 0.52, 0.6),
			Vector3(x, 0, 0),
			Color("#76543E")
		)
	crate.visible = false

	return {
		"body": body,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"cargo_anchor": cargo_anchor,
		"crate": crate
	}

static func popup(
	parent: Node3D,
	amount: int,
	icon: String,
	color: Color,
	position: Vector3
) -> void:
	var n := label(
		parent,
		"+%d %s" % [amount, icon],
		position + Vector3(0, 2.3, 0),
		80
	)
	n.modulate = color
	n.no_depth_test = true

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		n, "position",
		n.position + Vector3(0, 1.6, 0),
		1.3
	)
	tween.tween_property(
		n, "modulate:a",
		0.0, 0.6
	).set_delay(0.7)
	tween.chain().tween_callback(n.queue_free)
