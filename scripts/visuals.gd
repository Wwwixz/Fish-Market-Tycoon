
extends RefCounted


static func material(
	color: Color,
	unshaded: bool = false
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color

	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.roughness = 1.0
		return m

	var saturation: float = color.s
	var brightness: float = color.v

	if saturation < 0.18 and brightness > 0.25:
		m.metallic = 0.22
		m.roughness = 0.48
	elif saturation < 0.3 and brightness < 0.65:
		m.metallic = 0.08
		m.roughness = 0.66
	else:
		m.metallic = 0.0
		m.roughness = 0.83

	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY

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

	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

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
	mesh.radial_segments = 16
	mesh.rings = 8

	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)

	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

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
	mesh.radial_segments = 16

	n.mesh = mesh
	n.position = pos
	n.material_override = material(color)

	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

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

	n.font_size = clampi(size, 30, 48)
	n.pixel_size = 0.009

	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	n.modulate = Color("#F9F6ED")
	n.outline_modulate = Color("#24363B")
	n.outline_size = 7

	n.no_depth_test = false
	n.fixed_size = false
	n.alpha_cut = Label3D.ALPHA_CUT_DISCARD

	n.shaded = false
	n.double_sided = true

	parent.add_child(n)
	return n


static func person(
	parent: Node3D,
	color: Color
) -> void:
	animated_person(parent, color)


static func animated_person(
	parent: Node3D,
	color: Color
) -> Dictionary:
	var body := Node3D.new()
	body.name = "AnimatedBody"
	parent.add_child(body)

	cylinder(
		body,
		0.34,
		0.8,
		Vector3(0, 0.75, 0),
		color
	)

	box(
		body,
		Vector3(0.65, 0.12, 0.4),
		Vector3(0, 0.4, 0),
		color.darkened(0.22)
	)

	sphere(
		body,
		0.31,
		Vector3(0, 1.42, 0),
		Color("#D9B18D")
	)

	box(
		body,
		Vector3(0.72, 0.13, 0.72),
		Vector3(0, 1.72, 0),
		color.darkened(0.3)
	)

	box(
		body,
		Vector3(0.48, 0.19, 0.27),
		Vector3(0, 1.67, -0.24),
		color.darkened(0.35)
	)

	for x in [-0.12, 0.12]:
		sphere(
			body,
			0.035,
			Vector3(x, 1.46, -0.285),
			Color("#28383B")
		)

	var left_arm := Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.43, 1.04, 0)
	body.add_child(left_arm)

	box(
		left_arm,
		Vector3(0.2, 0.56, 0.22),
		Vector3(0, -0.25, 0),
		color.darkened(0.12)
	)

	sphere(
		left_arm,
		0.11,
		Vector3(0, -0.57, 0),
		Color("#D9B18D")
	)

	var right_arm := Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.43, 1.04, 0)
	body.add_child(right_arm)

	box(
		right_arm,
		Vector3(0.2, 0.56, 0.22),
		Vector3(0, -0.25, 0),
		color.darkened(0.12)
	)

	sphere(
		right_arm,
		0.11,
		Vector3(0, -0.57, 0),
		Color("#D9B18D")
	)

	var left_leg := Node3D.new()
	left_leg.name = "LeftLeg"
	left_leg.position = Vector3(-0.18, 0.36, 0)
	body.add_child(left_leg)

	box(
		left_leg,
		Vector3(0.23, 0.58, 0.27),
		Vector3(0, -0.25, 0),
		Color("#34464A")
	)

	box(
		left_leg,
		Vector3(0.26, 0.14, 0.4),
		Vector3(0, -0.54, -0.07),
		Color("#263538")
	)

	var right_leg := Node3D.new()
	right_leg.name = "RightLeg"
	right_leg.position = Vector3(0.18, 0.36, 0)
	body.add_child(right_leg)

	box(
		right_leg,
		Vector3(0.23, 0.58, 0.27),
		Vector3(0, -0.25, 0),
		Color("#34464A")
	)

	box(
		right_leg,
		Vector3(0.26, 0.14, 0.4),
		Vector3(0, -0.54, -0.07),
		Color("#263538")
	)

	var cargo_anchor := Node3D.new()
	cargo_anchor.name = "CargoAnchor"
	cargo_anchor.position = Vector3(0, 0.95, -0.62)
	body.add_child(cargo_anchor)

	var crate := Node3D.new()
	crate.name = "Crate"
	cargo_anchor.add_child(crate)

	box(
		crate,
		Vector3(0.75, 0.5, 0.55),
		Vector3.ZERO,
		Color("#946D50")
	)

	box(
		crate,
		Vector3(0.79, 0.08, 0.6),
		Vector3(0, 0.25, 0),
		Color("#B68B60")
	)

	for x in [-0.28, 0.28]:
		box(
			crate,
			Vector3(0.08, 0.52, 0.6),
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

	n.font_size = 65
	n.pixel_size = 0.009
	n.modulate = color
	n.no_depth_test = true

	var tween := parent.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		n,
		"position",
		n.position + Vector3(0, 1.6, 0),
		1.3
	)

	tween.tween_property(
		n,
		"modulate:a",
		0.0,
		0.6
	).set_delay(0.7)

	tween.chain().tween_callback(n.queue_free)
