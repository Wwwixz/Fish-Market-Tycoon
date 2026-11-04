
extends Node3D

const V = preload("res://scripts/visuals.gd")

var clock: float = 0.0
var waves: Array[Node3D] = []
var gulls: Array[Dictionary] = []
var clouds: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 2909

	_create_shore()
	_create_trees()
	_create_flowers()
	_create_props()
	_create_gulls()
	_create_clouds()

func _create_shore() -> void:
	for i in range(32):
		var angle := TAU * float(i) / 32.0

		var wave := Node3D.new()
		wave.position = Vector3(
			cos(angle) * 19.0,
			0.13,
			sin(angle) * 19.0
		)
		wave.rotation.y = -angle
		add_child(wave)

		V.box(
			wave,
			Vector3(2.4, 0.025, 0.12),
			Vector3.ZERO,
			Color("#B5D1CC")
		)

		waves.append(wave)

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

	for p in positions:
		_make_tree(p)

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

	for i in range(3):
		V.sphere(
			tree,
			1.15 - float(i) * 0.15,
			Vector3(
				rng.randf_range(-0.35, 0.35),
				2.7 + float(i) * 0.55,
				rng.randf_range(-0.35, 0.35)
			),
			Color("#648A6D") if i % 2 == 0
			else Color("#7F9D79")
		)

func _create_flowers() -> void:
	var colors := [
		Color("#D2B879"),
		Color("#D6A09D"),
		Color("#E2D8C3"),
		Color("#AEA0C0")
	]

	for i in range(65):
		var x := rng.randf_range(-15.0, 15.0)
		var z := rng.randf_range(-11.0, 15.0)

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

func _create_props() -> void:
	var crate_positions := [
		Vector3(-9, 0, -3),
		Vector3(-8, 0, -3),
		Vector3(11, 0, -3),
		Vector3(12, 0, -3)
	]

	for p in crate_positions:
		V.box(
			self,
			Vector3(0.9, 0.8, 0.9),
			p + Vector3(0, 0.8, 0),
			Color("#A98D6D")
		)

		V.box(
			self,
			Vector3(0.95, 0.12, 0.95),
			p + Vector3(0, 1.25, 0),
			Color("#796148")
		)

	for p in [
		Vector3(-12, 0, -7),
		Vector3(12, 0, 10)
	]:
		V.cylinder(
			self,
			0.5,
			1.1,
			p + Vector3(0, 0.9, 0),
			Color("#806B55")
		)

		V.cylinder(
			self,
			0.52,
			0.08,
			p + Vector3(0, 1.3, 0),
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
			V.sphere(
				cloud,
				rng.randf_range(1.0, 1.7),
				Vector3(
					float(j) * 1.5,
					rng.randf_range(-0.2, 0.2),
					rng.randf_range(-0.4, 0.4)
				),
				Color("#D6DFDB")
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

	for gull in gulls:
		var node: Node3D = gull["node"]
		var phase: float = (
			clock * float(gull["speed"])
			+ float(gull["phase"])
		)

		node.position = Vector3(
			cos(phase) * float(gull["radius"]),
			float(gull["height"]) + sin(clock * 2.0) * 0.3,
			sin(phase) * float(gull["radius"])
		)

		node.rotation.y = -phase

		var flap := sin(clock * 8.0 + phase) * 0.45

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
