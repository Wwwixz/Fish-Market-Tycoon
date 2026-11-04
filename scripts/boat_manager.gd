
extends Node3D

const V = preload("res://scripts/visuals.gd")

const ARRIVAL_SPEED := 4.0
const DEPARTURE_SPEED := 4.8
const WAIT_DURATION := 120.0
const SPAWN_DELAY := 8.0
const DOCK_Z := -17.0
const START_Z := -35.0
const EXIT_Z := -42.0

var state: Node

var boat: Node3D
var boat_visual: Node3D
var boat_label: Label3D
var wake_left: Node3D
var wake_right: Node3D
var navigation_light: MeshInstance3D

var timer: float = 0.0
var clock: float = 0.0
var departure_angle: float = 0.0
var previous_state: String = ""

var rng := RandomNumberGenerator.new()


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if state == null:
		return

	clock += delta

	if not is_instance_valid(boat):
		if state.boat_state != "none":
			_restore_boat()
		else:
			timer += delta

			if timer >= SPAWN_DELAY:
				_spawn()

		return

	if not is_instance_valid(boat_visual):
		return

	_animate_boat(delta)

	match String(state.boat_state):
		"arriving":
			_arriving(delta)

		"ordering":
			_ordering(delta)

		"leaving":
			_leaving(delta)

	previous_state = String(state.boat_state)


func _make_boat() -> void:
	_clear_boat()

	boat = Node3D.new()
	boat.name = "DeliveryBoat"
	boat.position = Vector3(9, -0.2, START_Z)
	add_child(boat)

	boat_visual = Node3D.new()
	boat_visual.name = "BoatVisual"
	boat.add_child(boat_visual)

	_build_hull()
	_build_cabin()
	_build_details()
	_build_cargo()
	_build_wake()

	boat_label = V.label(
		boat_visual,
		"ЗАКАЗ",
		Vector3(0, 3.55, 0),
		38
	)

	boat_label.no_depth_test = true


func _build_hull() -> void:
	var hull := Color("#A96855")
	var trim := Color("#E1D1B5")
	var dark := Color("#684E44")

	V.box(
		boat_visual,
		Vector3(3.1, 0.65, 5.1),
		Vector3(0, 0.05, 0),
		hull
	)

	V.box(
		boat_visual,
		Vector3(2.65, 0.3, 5.5),
		Vector3(0, 0, -0.05),
		hull.darkened(0.12)
	)

	V.box(
		boat_visual,
		Vector3(3.25, 0.12, 4.65),
		Vector3(0, 0.45, 0),
		trim
	)

	V.box(
		boat_visual,
		Vector3(2.8, 0.12, 4.1),
		Vector3(0, 0.53, 0),
		Color("#B99D7A")
	)

	for x in [-1.53, 1.53]:
		V.box(
			boat_visual,
			Vector3(0.14, 0.38, 4.6),
			Vector3(x, 0.65, 0),
			trim
		)

		V.box(
			boat_visual,
			Vector3(0.12, 0.14, 4.8),
			Vector3(x, 0.88, 0),
			dark
		)

	V.box(
		boat_visual,
		Vector3(2.8, 0.35, 0.65),
		Vector3(0, 0.58, -2.15),
		hull
	)

	V.box(
		boat_visual,
		Vector3(2.6, 0.18, 0.4),
		Vector3(0, 0.84, 2.23),
		trim
	)


func _build_cabin() -> void:
	var cabin := Color("#E3DAC7")
	var glass := Color("#789EA4")
	var roof := Color("#6B8584")

	V.box(
		boat_visual,
		Vector3(2.15, 1.5, 1.85),
		Vector3(0, 1.34, 0.55),
		cabin
	)

	V.box(
		boat_visual,
		Vector3(2.45, 0.2, 2.15),
		Vector3(0, 2.2, 0.55),
		roof
	)

	V.box(
		boat_visual,
		Vector3(1.65, 0.7, 0.08),
		Vector3(0, 1.62, -0.42),
		glass
	)

	V.box(
		boat_visual,
		Vector3(0.08, 0.75, 0.15),
		Vector3(0, 1.62, -0.47),
		cabin
	)

	for x in [-1.12, 1.12]:
		V.box(
			boat_visual,
			Vector3(0.08, 0.65, 0.9),
			Vector3(x, 1.55, 0.6),
			glass
		)

	V.box(
		boat_visual,
		Vector3(0.65, 0.9, 0.08),
		Vector3(0, 1.35, 1.53),
		Color("#A58A6C")
	)

	V.box(
		boat_visual,
		Vector3(0.35, 0.28, 0.09),
		Vector3(0, 1.65, 1.59),
		glass
	)


func _build_details() -> void:
	var metal := Color("#748584")

	V.cylinder(
		boat_visual,
		0.055,
		1.15,
		Vector3(0, 2.75, 0.6),
		metal
	)

	V.box(
		boat_visual,
		Vector3(0.9, 0.06, 0.06),
		Vector3(0, 3.15, 0.6),
		metal
	)

	navigation_light = V.sphere(
		boat_visual,
		0.13,
		Vector3(0, 3.4, 0.6),
		Color("#D9B97C")
	)

	for x in [-1.45, 1.45]:
		for z in [-1.5, 1.5]:
			V.cylinder(
				boat_visual,
				0.09,
				0.48,
				Vector3(x, 1.05, z),
				metal
			)


func _build_cargo() -> void:
	for x in [-0.55, 0.55]:
		for z in [-1.65, -0.85]:
			V.box(
				boat_visual,
				Vector3(0.85, 0.65, 0.65),
				Vector3(x, 0.91, z),
				Color("#997859")
			)

			V.box(
				boat_visual,
				Vector3(0.9, 0.08, 0.7),
				Vector3(x, 1.25, z),
				Color("#C2A17A")
			)

			V.box(
				boat_visual,
				Vector3(0.09, 0.7, 0.7),
				Vector3(x, 0.91, z),
				Color("#765840")
			)


func _build_wake() -> void:
	wake_left = Node3D.new()
	wake_left.name = "WakeLeft"
	add_child(wake_left)

	wake_right = Node3D.new()
	wake_right.name = "WakeRight"
	add_child(wake_right)

	for i in range(4):
		var z := float(i) * 0.9

		V.box(
			wake_left,
			Vector3(0.65 + float(i) * 0.22, 0.025, 0.09),
			Vector3(-1.8 - float(i) * 0.22, 0, z),
			Color("#B5D1CC")
		)

		V.box(
			wake_right,
			Vector3(0.65 + float(i) * 0.22, 0.025, 0.09),
			Vector3(1.8 + float(i) * 0.22, 0, z),
			Color("#B5D1CC")
		)


func _animate_boat(delta: float) -> void:
	if not is_instance_valid(boat):
		return

	if not is_instance_valid(boat_visual):
		return

	boat.position.y = (
		-0.2 + sin(clock * 1.65) * 0.065
	)

	boat_visual.rotation.z = (
		sin(clock * 1.25) * 0.025
	)

	boat_visual.rotation.x = (
		sin(clock * 1.05 + 0.8) * 0.018
	)

	var moving: bool = (
		state.boat_state == "arriving"
		or state.boat_state == "leaving"
	)

	if moving:
		boat_visual.rotation.x -= 0.025

	if is_instance_valid(navigation_light):
		var light_color := Color("#D9B97C")

		if sin(clock * 3.0) > 0.0:
			light_color = Color("#F1D99A")

		navigation_light.material_override = V.material(
			light_color,
			true
		)

	if is_instance_valid(wake_left):
		wake_left.visible = moving

		if moving:
			wake_left.position = Vector3(
				boat.position.x,
				-0.32,
				boat.position.z + 2.2
			)

			wake_left.rotation.y = boat.rotation.y

	if is_instance_valid(wake_right):
		wake_right.visible = moving

		if moving:
			wake_right.position = Vector3(
				boat.position.x,
				-0.32,
				boat.position.z + 2.2
			)

			wake_right.rotation.y = boat.rotation.y


func _arriving(delta: float) -> void:
	if not is_instance_valid(boat):
		return

	var distance: float = DOCK_Z - boat.position.z

	var speed: float = minf(
		ARRIVAL_SPEED,
		maxf(0.65, distance * 0.75)
	)

	boat.position.z = minf(
		DOCK_Z,
		boat.position.z + speed * delta
	)

	boat.rotation.y = lerp_angle(
		boat.rotation.y,
		0.0,
		minf(1.0, delta * 2.0)
	)

	if boat.position.z >= DOCK_Z - 0.02:
		boat.position.z = DOCK_Z
		state.boat_state = "ordering"
		state.boat_time = WAIT_DURATION
		timer = 0.0

		state.notice.emit(
            "Лодка прибыла! Подготовь заказ"
		)

		state.changed.emit()


func _ordering(delta: float) -> void:
	if previous_state != "ordering":
		timer = clampf(
			WAIT_DURATION - state.boat_time,
			0.0,
			WAIT_DURATION
		)

	timer += delta

	state.boat_time = maxf(
		0.0,
		WAIT_DURATION - timer
	)

	if is_instance_valid(boat_label):
		boat_label.text = (
            "ЗАКАЗ: %d ФИЛЕ\n%d СЕК."
			% [state.boat_order, int(ceil(state.boat_time))]
		)

	if timer >= WAIT_DURATION:
		state.boat_state = "leaving"
		state.boat_time = 0.0

		state.notice.emit(
            "Покупатель не дождался заказа"
		)

		state.changed.emit()


func _leaving(delta: float) -> void:
	if not is_instance_valid(boat):
		return

	if is_instance_valid(boat_label):
		boat_label.text = (
            "СПАСИБО!"
			if state.boat_time > 0.0
			else "УПЛЫВАЕМ"
		)

	departure_angle = move_toward(
		departure_angle,
		1.0,
		delta * 0.65
	)

	boat.rotation.y = lerp_angle(
		boat.rotation.y,
		PI,
		minf(1.0, delta * 1.8)
	)

	boat.position.z -= (
		DEPARTURE_SPEED
		* (0.55 + departure_angle * 0.45)
		* delta
	)

	if boat.position.z <= EXIT_Z:
		_clear_boat()

		state.boat_state = "none"
		state.boat_order = 0
		state.boat_time = 0.0

		timer = 0.0
		departure_angle = 0.0
		previous_state = ""

		state.changed.emit()


func _spawn() -> void:
	_make_boat()

	state.boat_order = rng.randi_range(1, 3) * 3
	state.boat_state = "arriving"
	state.boat_time = WAIT_DURATION

	if is_instance_valid(boat_label):
		boat_label.text = (
			"ЗАКАЗ: %d ФИЛЕ" % state.boat_order
		)

	timer = 0.0
	departure_angle = 0.0
	previous_state = "arriving"

	state.changed.emit()


func _restore_boat() -> void:
	_make_boat()

	match String(state.boat_state):
		"arriving":
			boat.position.z = START_Z

		"ordering":
			boat.position.z = DOCK_Z

		"leaving":
			boat.position.z = DOCK_Z

		_:
			_clear_boat()
			return

	if is_instance_valid(boat_label):
		boat_label.text = (
			"ЗАКАЗ: %d ФИЛЕ" % state.boat_order
		)

	timer = clampf(
		WAIT_DURATION - state.boat_time,
		0.0,
		WAIT_DURATION
	)

	departure_angle = 0.0
	previous_state = String(state.boat_state)


func _clear_boat() -> void:
	if is_instance_valid(boat):
		boat.queue_free()

	if is_instance_valid(wake_left):
		wake_left.queue_free()

	if is_instance_valid(wake_right):
		wake_right.queue_free()

	boat = null
	boat_visual = null
	boat_label = null
	navigation_light = null
	wake_left = null
	wake_right = null
