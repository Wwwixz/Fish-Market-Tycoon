
extends Node3D

const V = preload("res://scripts/visuals.gd")

const SUN_COLOR := Color("#F4DFC5")
const AMBIENT_COLOR := Color("#A5B5AD")
const SKY_COLOR := Color("#85B1B7")

var clock: float = 0.0

var waves: Array[Node3D] = []
var water_ripples: Array[Dictionary] = []
var gulls: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var plants: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2909

	_setup_lighting()
	_create_shore()
	_create_water_ripples()
	_create_trees()
	_create_flowers()
	_create_rocks()
	_create_props()
	_create_extra_details()
	_create_dock_details()
	_create_buoys()
	_create_gulls()
	_create_clouds()
	var animated: Array[Node3D] = []
	animated.append_array(waves)
	for entries in [water_ripples, gulls, clouds, plants]:
		for entry in entries:
			animated.append(entry["node"])
	preload("res://scripts/static_batch.gd").build(self, animated)
	for entries in [water_ripples, clouds, plants]:
		for entry in entries:
			preload("res://scripts/static_batch.gd").build(entry["node"], [])


func _setup_lighting() -> void:
	var main := get_parent()

	if main == null:
		return

	var world := main.get_node_or_null("World")

	if world == null:
		return

	var sun := world.get_node_or_null(
        "MainSun"
	) as DirectionalLight3D

	if sun != null:
		sun.rotation_degrees = Vector3(-52, -35, 0)

		sun.light_color = SUN_COLOR
		sun.light_energy = 0.48

		sun.shadow_enabled = true
		sun.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_ORTHOGONAL if OS.has_feature("android")
			else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		)
		sun.directional_shadow_max_distance = 65.0

	var world_environment := world.get_node_or_null(
        "MainWorldEnvironment"
	) as WorldEnvironment

	if world_environment == null:
		return

	var env := world_environment.environment

	if env == null:
		env = Environment.new()
		world_environment.environment = env

	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR

	env.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = 0.20

	env.reflected_light_source = (
		Environment.REFLECTION_SOURCE_DISABLED
	)

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	env.fog_enabled = false


func _create_shore() -> void:
	for i in range(48):
		var angle: float = TAU * float(i) / 48.0

		var wave := Node3D.new()

		wave.position = Vector3(
			cos(angle) * 19.0,
			0.13,
			sin(angle) * 17.0 + 5.0
		)

		wave.rotation.y = -angle
		add_child(wave)

		var foam := V.box(
			wave,
			Vector3(1.8, 0.025, 0.09),
			Vector3.ZERO,
			Color("#D6E6DF")
		)

		foam.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

		waves.append(wave)


func _create_water_ripples() -> void:
	for i in range(36):
		var x: float = rng.randf_range(
			-42.0,
			42.0
		)

		var z: float = rng.randf_range(
			-42.0,
			42.0
		)

		if (
			absf(x) < 22.0
			and z > -16.0
			and z < 24.0
		):
			continue

		var ripple := Node3D.new()
		ripple.position = Vector3(x, -0.46, z)
		ripple.rotation.y = rng.randf_range(
			0.0,
			TAU
		)
		add_child(ripple)

		var line := V.box(
			ripple,
			Vector3(
				rng.randf_range(0.8, 2.2),
				0.012,
				0.045
			),
			Vector3.ZERO,
			Color("#B5D6D5")
		)

		line.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

		water_ripples.append({
			"node": ripple,
			"phase": rng.randf_range(0.0, TAU)
		})


func _create_trees() -> void:
	var positions := [
		Vector3(-15, 0, -10),
		Vector3(-14, 0, 1),
		Vector3(-14, 0, 13),
		Vector3(15, 0, 12),
		Vector3(15, 0, 3),
		Vector3(-7, 0, 14),
		Vector3(7, 0, 14)
	]

	for pos in positions:
		_make_tree(pos)


func _make_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos
	add_child(tree)

	V.cylinder(
		tree,
		0.24,
		2.3,
		Vector3(0, 1.3, 0),
		Color("#79634E")
	)

	var crown := Node3D.new()
	crown.position = Vector3(0, 2.7, 0)
	tree.add_child(crown)

	for i in range(3):
		V.sphere(
			crown,
			1.15 - float(i) * 0.15,
			Vector3(
				rng.randf_range(-0.35, 0.35),
				float(i) * 0.55,
				rng.randf_range(-0.35, 0.35)
			),
			Color("#648A6D")
			if i % 2 == 0
			else Color("#7F9D79")
		)

	plants.append({
		"node": crown,
		"phase": rng.randf_range(0.0, TAU)
	})


func _create_flowers() -> void:
	var colors := [
		Color("#D2B879"),
		Color("#D6A09D"),
		Color("#E2D8C3"),
		Color("#AEA0C0")
	]

	for i in range(100):
		var x: float = rng.randf_range(-15.0, 15.0)
		var z: float = rng.randf_range(-11.0, 15.0)

		if absf(x) < 11.0 and absf(z) < 10.0:
			continue

		var flower := Node3D.new()
		flower.position = Vector3(x, 0.4, z)
		add_child(flower)

		V.cylinder(
			flower,
			0.025,
			0.28,
			Vector3(0, 0.12, 0),
			Color("#729575")
		)

		V.sphere(
			flower,
			0.12,
			Vector3(0, 0.3, 0),
			colors[rng.randi_range(0, 3)]
		)


func _create_rocks() -> void:
	for i in range(26):
		var x: float = rng.randf_range(-18.0, 18.0)
		var z: float = rng.randf_range(-10.0, 19.0)

		if absf(x) < 12.0 and z < 13.0:
			continue

		var rock := V.sphere(
			self,
			rng.randf_range(0.2, 0.55),
			Vector3(x, 0.28, z),
			Color("#9BA49A")
		)

		rock.scale = Vector3(
			rng.randf_range(1.0, 1.5),
			rng.randf_range(0.4, 0.8),
			rng.randf_range(0.8, 1.3)
		)


func _create_props() -> void:
	var crate_positions := [
		Vector3(-9, 0, -3),
		Vector3(-8, 0, -3),
		Vector3(11, 0, -3),
		Vector3(12, 0, -3)
	]

	for pos in crate_positions:
		V.box(
			self,
			Vector3(0.9, 0.8, 0.9),
			pos + Vector3(0, 0.8, 0),
			Color("#A98D6D")
		)

		V.box(
			self,
			Vector3(0.95, 0.12, 0.95),
			pos + Vector3(0, 1.25, 0),
			Color("#796148")
		)

	for pos in [
		Vector3(-12, 0, -7),
		Vector3(12, 0, 10)
	]:
		V.cylinder(
			self,
			0.5,
			1.1,
			pos + Vector3(0, 0.9, 0),
			Color("#806B55")
		)

		V.cylinder(
			self,
			0.52,
			0.08,
			pos + Vector3(0, 1.3, 0),
			Color("#667576")
		)


func _create_gulls() -> void:
	for i in range(5):
		var gull := Node3D.new()
		gull.name = "Seagull_%d" % i
		add_child(gull)

		V.sphere(
			gull,
			0.18,
			Vector3.ZERO,
			Color("#E4E5DE")
		)

		var left := V.box(
			gull,
			Vector3(0.7, 0.045, 0.16),
			Vector3(-0.42, 0.08, 0),
			Color("#E4E5DE")
		)

		var right := V.box(
			gull,
			Vector3(0.7, 0.045, 0.16),
			Vector3(0.42, 0.08, 0),
			Color("#E4E5DE")
		)

		V.box(
			gull,
			Vector3(0.18, 0.08, 0.2),
			Vector3(0, -0.03, -0.22),
			Color("#C7A36E")
		)

		gulls.append({
			"node": gull,
			"left": left,
			"right": right,
			"radius": rng.randf_range(12.0, 21.0),
			"speed": rng.randf_range(0.15, 0.32),
			"phase": rng.randf_range(0.0, TAU),
			"height": rng.randf_range(9.0, 14.0)
		})


func _create_clouds() -> void:
	for i in range(6):
		var cloud := Node3D.new()
		cloud.name = "Cloud_%d" % i
		add_child(cloud)

		for j in range(4):
			var puff := V.sphere(
				cloud,
				rng.randf_range(1.0, 1.7),
				Vector3(
					float(j) * 1.5,
					rng.randf_range(-0.2, 0.2),
					rng.randf_range(-0.4, 0.4)
				),
				Color("#E1E7DE")
			)

			puff.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)

		cloud.position = Vector3(
			rng.randf_range(-30.0, 30.0),
			rng.randf_range(15.0, 21.0),
			rng.randf_range(-30.0, 30.0)
		)

		clouds.append({
			"node": cloud,
			"speed": rng.randf_range(0.2, 0.5)
		})


func _process(delta: float) -> void:
	clock += delta

	for i in range(waves.size()):
		var wave: Node3D = waves[i]

		wave.position.y = (
			0.13
			+ sin(clock * 2.0 + float(i) * 0.7) * 0.06
		)

		wave.scale.x = (
			1.0
			+ sin(clock * 1.5 + float(i)) * 0.12
		)

	for ripple in water_ripples:
		var node: Node3D = ripple["node"]
		var phase: float = ripple["phase"]

		node.position.y = (
			-0.46
			+ sin(clock * 1.8 + phase) * 0.025
		)

		node.scale.x = (
			1.0
			+ sin(clock * 1.4 + phase) * 0.2
		)

	for plant in plants:
		var crown: Node3D = plant["node"]
		var phase: float = plant["phase"]

		crown.rotation.z = (
			sin(clock * 0.8 + phase) * 0.025
		)

	for gull in gulls:
		var node: Node3D = gull["node"]

		var phase: float = (
			clock * float(gull["speed"])
			+ float(gull["phase"])
		)

		node.position = Vector3(
			cos(phase) * float(gull["radius"]),
			float(gull["height"])
			+ sin(clock * 2.0) * 0.3,
			sin(phase) * float(gull["radius"])
		)

		node.rotation.y = -phase

		var flap: float = (
			sin(clock * 8.0 + phase) * 0.45
		)

		var left: Node3D = gull["left"]
		var right: Node3D = gull["right"]

		left.rotation.z = flap
		right.rotation.z = -flap

	for cloud_data in clouds:
		var cloud: Node3D = cloud_data["node"]

		cloud.position.x += (
			float(cloud_data["speed"]) * delta
		)

		if cloud.position.x > 38.0:
			cloud.position.x = -38.0


func _create_extra_details() -> void:
	var bush_positions := [
		Vector3(-15.5, 0, 6.0),
		Vector3(-13.0, 0, 10.0),
		Vector3(-10.0, 0, 14.0),
		Vector3(11.5, 0, 13.0),
		Vector3(14.0, 0, 8.0),
		Vector3(15.5, 0, -5.0)
	]

	for pos in bush_positions:
		_make_bush(pos)

	var grass_positions := [
		Vector3(-15, 0, -4),
		Vector3(-13, 0, 5),
		Vector3(-11, 0, 12),
		Vector3(-8, 0, 15),
		Vector3(10, 0, 15),
		Vector3(13, 0, 11),
		Vector3(16, 0, 5),
		Vector3(15, 0, -7)
	]

	for pos in grass_positions:
		_make_grass(pos)

	_make_sign(
		Vector3(-12.5, 0, -8.5),
		"РЫБНЫЙ РЫНОК"
	)


func _make_bush(pos: Vector3) -> void:
	var bush := Node3D.new()
	bush.position = pos
	add_child(bush)

	var colors := [
		Color("#65896B"),
		Color("#779875"),
		Color("#557A63")
	]

	for i in range(4):
		var angle := float(i) * TAU / 4.0
		var leaf := V.sphere(
			bush,
			0.48,
			Vector3(
				cos(angle) * 0.32,
				0.48,
				sin(angle) * 0.32
			),
			colors[i % colors.size()]
		)

		leaf.scale = Vector3(1.0, 0.75, 1.0)


func _make_grass(pos: Vector3) -> void:
	var grass := Node3D.new()
	grass.position = pos
	add_child(grass)

	for i in range(5):
		var blade := V.box(
			grass,
			Vector3(0.045, 0.32, 0.06),
			Vector3(
				(float(i) - 2.0) * 0.11,
				0.27,
				sin(float(i) * 2.0) * 0.09
			),
			Color("#648A64")
		)

		blade.rotation.z = (float(i) - 2.0) * 0.15


func _make_sign(pos: Vector3, title: String) -> void:
	var sign := Node3D.new()
	sign.position = pos
	add_child(sign)

	V.box(
		sign,
		Vector3(0.18, 1.8, 0.18),
		Vector3(0, 1.0, 0),
		Color("#765A43")
	)

	V.box(
		sign,
		Vector3(2.6, 0.75, 0.16),
		Vector3(0, 1.85, 0),
		Color("#927153")
	)

	V.box(
		sign,
		Vector3(2.45, 0.6, 0.04),
		Vector3(0, 1.85, -0.1),
		Color("#B9956C")
	)

	var text_label := V.label(
		sign,
		title,
		Vector3(0, 1.85, -0.17),
		30
	)

	text_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	text_label.rotation.y = 0.0
	text_label.pixel_size = 0.004


func _create_dock_details() -> void:
	var dock_positions := [
		Vector3(-5.0, 0, -11.0),
		Vector3(9.0, 0, -11.0)
	]

	for pos in dock_positions:
		_make_dock_details(pos)


func _make_dock_details(pos: Vector3) -> void:
	var dock := Node3D.new()
	dock.position = pos
	add_child(dock)

	var wood := Color("#876A50")
	var wood_light := Color("#A48765")
	var rope := Color("#C6B18B")

	for side in [-1.0, 1.0]:
		for i in range(3):
			var z := float(i) * 1.8 - 1.8

			V.cylinder(
				dock,
				0.13,
				1.25,
				Vector3(side * 1.85, 0.55, z),
				wood
			)

			V.cylinder(
				dock,
				0.17,
				0.12,
				Vector3(side * 1.85, 1.22, z),
				wood_light
			)

	for side in [-1.0, 1.0]:
		for i in range(2):
			var z := float(i) * 1.8 - 0.9

			var rail := V.box(
				dock,
				Vector3(0.06, 0.06, 1.75),
				Vector3(side * 1.85, 0.95, z),
				rope
			)

			rail.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)

	for i in range(3):
		var z := float(i) * 1.3 - 1.3

		V.box(
			dock,
			Vector3(0.85, 0.09, 0.12),
			Vector3(-0.95, 0.53, z),
			wood_light
		)


func _create_buoys() -> void:
	var positions := [
		Vector3(-23, -0.4, -9),
		Vector3(-21, -0.4, 5),
		Vector3(23, -0.4, -8),
		Vector3(21, -0.4, 8),
		Vector3(-8, -0.4, -19),
		Vector3(9, -0.4, -19)
	]

	for i in range(positions.size()):
		_make_buoy(
			positions[i],
			i % 2 == 0
		)


func _make_buoy(
	pos: Vector3,
	is_red: bool
) -> void:
	var buoy := Node3D.new()
	buoy.position = pos
	add_child(buoy)

	var main_color := Color("#C47768")
	if not is_red:
		main_color = Color("#D6BE83")

	var body := V.sphere(
		buoy,
		0.34,
		Vector3.ZERO,
		main_color
	)

	body.scale = Vector3(1.0, 1.15, 1.0)

	V.cylinder(
		buoy,
		0.045,
		0.5,
		Vector3(0, 0.48, 0),
		Color("#E4DFCF")
	)

	V.sphere(
		buoy,
		0.09,
		Vector3(0, 0.76, 0),
		Color("#F2E6CC")
	)

	water_ripples.append({
		"node": buoy,
		"phase": rng.randf_range(0.0, TAU)
	})
