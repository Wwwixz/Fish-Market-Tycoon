
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

var state: Node
var worker_manager: Node3D

var camera: Camera3D
var rod: Node3D

var fishing: bool = false
var timer: float = 0.0
var armed: bool = true
var cooldown: float = 0.0

var camera_target: Vector3 = Vector3.ZERO

var hire_inside: Array[bool] = [
	false, false, false, false
]

func setup(game_state: Node) -> void:
	state = game_state

func _ready() -> void:
	position = Vector3(0, 0.5, 8)

	V.person(self, Color("#527A91"))

	V.label(
		self,
		"ИГРОК",
		Vector3(0, 2.3, 0)
	)

	rod = Node3D.new()
	rod.position = Vector3(0.5, 0.7, 0)
	add_child(rod)

	V.cylinder(
		rod,
		0.04,
		2.1,
		Vector3(0, 1, 0),
		Color("#946D50")
	)

	rod.visible = false

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 31
	camera.current = true

	get_parent().add_child(camera)

	camera_target = position
	_camera()

func _camera() -> void:
	camera.position = (
		camera_target + Vector3(20, 29, 20)
	)

	camera.look_at(
		camera_target + Vector3(0, 0.5, 0),
		Vector3.UP
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(
				14,
				camera.size - 1.5
			)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(
				45,
				camera.size + 1.5
			)

func _process(delta: float) -> void:
	if state == null:
		return

	cooldown = maxf(0.0, cooldown - delta)

	if fishing:
		timer += delta

		rod.rotation.z = (
			sin(Time.get_ticks_msec() * 0.009) * 0.4
		)

		if timer >= 3.0:
			fishing = false
			rod.visible = false
			rod.rotation.z = 0.0

			state.player_fish += 1

			state.reward.emit(
				1,
				"🐟",
				Color("#83D8EF"),
				global_position
			)

			state.changed.emit()
	else:
		_move(delta)
		_interact()

	_check_hire_zones()

	camera_target = camera_target.lerp(
		position,
		minf(1.0, delta * 5)
	)

	_camera()

func _move(delta: float) -> void:
	var input_dir := Vector2.ZERO

	if (
		Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_LEFT)
	):
		input_dir.x -= 1

	if (
		Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_RIGHT)
	):
		input_dir.x += 1

	if (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_UP)
	):
		input_dir.y -= 1

	if (
		Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_DOWN)
	):
		input_dir.y += 1

	input_dir = input_dir.limit_length(1.0)

	var right: Vector3 = camera.global_transform.basis.x
	var forward: Vector3 = -camera.global_transform.basis.z

	right.y = 0.0
	forward.y = 0.0

	var direction: Vector3 = (
		right.normalized() * input_dir.x
		+ forward.normalized() * -input_dir.y
	)

	position += direction * 6.0 * delta

	position.x = clampf(position.x, -17, 17)
	position.z = clampf(position.z, -12, 17)

	if direction.length() > 0.1:
		rotation.y = lerp_angle(
			rotation.y,
			atan2(direction.x, direction.z),
			delta * 10.0
		)

func near(
	target: Vector3,
	radius: float = 1.5
) -> bool:
	return Vector2(
		position.x - target.x,
		position.z - target.z
	).length() <= radius

func _interact() -> void:
	if not near(S.FISHING):
		armed = true

	if cooldown > 0.0:
		return

	if near(S.FISHING) and armed:
		armed = false
		fishing = true
		timer = 0.0
		rod.visible = true

		state.notice.emit(
            "Ловим рыбу... 3 секунды"
		)
		return

	if near(S.FISH_BOX, 1.8):
		if state.player_fish > 0:
			state.fish_box += state.player_fish
			state.player_fish = 0
			state.changed.emit()
			cooldown = 0.4

	if near(S.MACHINE_ZONE):
		if state.player_fish > 0:
			state.machine_input += state.player_fish
			state.player_fish = 0
			state.changed.emit()

		if state.fish_box > 0:
			state.fish_box -= 1
			state.machine_input += 1
			state.changed.emit()
			cooldown = 0.4

		if state.machine_output > 0:
			var amount: int = state.machine_output

			state.player_fillets += amount
			state.machine_output = 0

			state.reward.emit(
				amount,
				"🍣",
				Color("#FFD38B"),
				global_position
			)

			state.changed.emit()

	if near(S.FILLET_BOX, 1.8):
		if state.player_fillets > 0:
			state.fillet_box += state.player_fillets
			state.player_fillets = 0
			state.changed.emit()

	if near(S.CASH):
		if state.player_fillets > 0:
			state.fillet_box += state.player_fillets
			state.player_fillets = 0
			state.changed.emit()

		state.sell()

func _check_hire_zones() -> void:
	if worker_manager == null:
		return

	for i in range(4):
		var target: Vector3 = S.HIRE_POSITIONS[i]
		var inside: bool = near(target, 1.25)

		if inside and not hire_inside[i]:
			worker_manager.hire(i)

		hire_inside[i] = inside
