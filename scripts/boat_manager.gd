
extends Node3D

const V = preload("res://scripts/visuals.gd")

var state
var boat: Node3D
var boat_label: Label3D
var timer := 0.0
var rng := RandomNumberGenerator.new()

func setup(game_state: Node) -> void:
	state = game_state

func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	if state == null:
		return

	if not is_instance_valid(boat):
		timer += delta

		if timer >= 8.0:
			_spawn()

		return

	boat.position.y = (
		-0.2
		+ sin(Time.get_ticks_msec() * 0.002) * 0.07
	)

	match String(state.boat_state):
		"arriving":
			boat.position.z += 4.0 * delta

			if boat.position.z >= -17:
				boat.position.z = -17
				state.boat_state = "ordering"
				timer = 0.0

				state.notice.emit(
                    "Лодка прибыла! Подготовь заказ"
				)

				state.changed.emit()

		"ordering":
			timer += delta

			state.boat_time = maxf(
				0.0,
				120.0 - timer
			)

			if timer >= 120.0:
				state.boat_state = "leaving"

				state.notice.emit(
                    "Покупатель не дождался заказа"
				)

		"leaving":
			boat_label.text = (
                "СПАСИБО!"
				if state.boat_time > 0
				else "УПЛЫВАЕМ"
			)

			boat.position.z -= 4.0 * delta

			if boat.position.z < -40:
				boat.queue_free()
				boat = null
				state.boat_state = "none"
				timer = 0.0
				state.changed.emit()

func _spawn() -> void:
	boat = Node3D.new()
	boat.position = Vector3(9, -0.2, -35)
	add_child(boat)

	V.box(
		boat,
		Vector3(3.6, 0.7, 5.4),
		Vector3(0, 0.1, 0),
		Color("#C77E66")
	)

	V.box(
		boat,
		Vector3(2.6, 0.2, 4.5),
		Vector3(0, 0.5, 0),
		Color("#E0CEAE")
	)

	V.box(
		boat,
		Vector3(2, 1.4, 1.8),
		Vector3(0, 1.3, 0.5),
		Color("#F1E7D6")
	)

	V.box(
		boat,
		Vector3(1.5, 0.6, 0.1),
		Vector3(0, 1.5, -0.45),
		Color("#83B9BD")
	)

	state.boat_order = rng.randi_range(1, 3) * 3
	state.boat_state = "arriving"
	state.boat_time = 120.0

	boat_label = V.label(
		boat,
		"ЗАКАЗ: %d ФИЛЕ" % state.boat_order,
		Vector3(0, 3.3, 0)
	)

	timer = 0.0
	state.changed.emit()
