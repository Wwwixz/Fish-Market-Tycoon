
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const MOVE_SPEED := 6.0
const MOVE_ACCELERATION := 15.0
const MOVE_FRICTION := 18.0
const ROTATION_SPEED := 12.0

const CAMERA_FOLLOW_SPEED := 5.0
const CAMERA_LOOK_AHEAD := 0.65
const CAMERA_ZOOM_SPEED := 8.0
const CAMERA_ROTATION_SPEED := 2.0

const MIN_ZOOM := 14.0
const MAX_ZOOM := 45.0
const DEFAULT_ZOOM := 31.0

const CAMERA_DISTANCE := 28.0
const CAMERA_ELEVATION := 0.95
const DEFAULT_CAMERA_ANGLE := PI / 4.0

var state: Node
var worker_manager: Node3D

var camera: Camera3D
var rod: Node3D

var model: Dictionary = {}
var animation_time: float = 0.0

var fishing: bool = false
var timer: float = 0.0
var armed: bool = true
var cooldown: float = 0.0

var velocity: Vector3 = Vector3.ZERO

var camera_target: Vector3 = Vector3.ZERO
var camera_zoom_target: float = DEFAULT_ZOOM
var camera_angle: float = DEFAULT_CAMERA_ANGLE
var camera_angle_target: float = DEFAULT_CAMERA_ANGLE

var camera_look_ahead: Vector3 = Vector3.ZERO

var hire_inside: Array[bool] = [
	false, false, false, false
]


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	position = Vector3(0, 0.5, 8)

	model = V.animated_person(
		self,
		Color("#527A91")
	)

	V.label(
		self,
		"ИГРОК",
		Vector3(0, 2.3, 0)
	)

	rod = Node3D.new()
	rod.name = "PlayerFishingRod"

	var right_arm: Node3D = model["right_arm"]
	right_arm.add_child(rod)

	V.cylinder(
		rod,
		0.04,
		2.1,
		Vector3(0, -0.7, -0.5),
		Color("#946D50")
	)

	rod.rotation.x = -0.5
	rod.visible = false

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DEFAULT_ZOOM
	camera.current = true

	get_parent().add_child(camera)

	camera_target = global_position
	camera_zoom_target = DEFAULT_ZOOM
	camera_angle = DEFAULT_CAMERA_ANGLE
	camera_angle_target = DEFAULT_CAMERA_ANGLE

	_update_camera(1.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_zoom_target = maxf(
					MIN_ZOOM,
					camera_zoom_target - 2.0
				)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_zoom_target = minf(
					MAX_ZOOM,
					camera_zoom_target + 2.0
				)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			camera_angle_target -= PI / 4.0

		elif event.keycode == KEY_E:
			camera_angle_target += PI / 4.0

		elif event.keycode == KEY_R:
			camera_angle_target = DEFAULT_CAMERA_ANGLE
			camera_zoom_target = DEFAULT_ZOOM


func _process(delta: float) -> void:
	if state == null:
		return

	cooldown = maxf(0.0, cooldown - delta)

	if fishing:
		velocity = velocity.move_toward(
			Vector3.ZERO,
			MOVE_FRICTION * delta
		)

		timer += delta

		if timer >= 3.0:
			fishing = false
			rod.visible = false
			rod.rotation.x = -0.5

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

	_animate(delta)
	_check_hire_zones()
	_update_camera(delta)


func _animate(delta: float) -> void:
	animation_time += delta

	var body: Node3D = model["body"]
	var left_arm: Node3D = model["left_arm"]
	var right_arm: Node3D = model["right_arm"]
	var left_leg: Node3D = model["left_leg"]
	var right_leg: Node3D = model["right_leg"]

	var speed: float = velocity.length()
	var movement_weight: float = clampf(
		speed / MOVE_SPEED,
		0.0,
		1.0
	)

	if fishing:
		movement_weight = 0.0

	var phase: float = animation_time * 10.0

	var leg_swing: float = (
		sin(phase) * 0.6 * movement_weight
	)

	var arm_swing: float = (
		sin(phase) * 0.45 * movement_weight
	)

	var bob: float = (
		absf(sin(phase))
		* 0.08
		* movement_weight
	)

	if movement_weight < 0.05:
		bob += sin(animation_time * 2.0) * 0.012

	var weight: float = minf(1.0, delta * 12.0)

	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		leg_swing,
		weight
	)

	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		-leg_swing,
		weight
	)

	body.position.y = lerpf(
		body.position.y,
		bob,
		weight
	)

	if fishing:
		left_arm.rotation.x = lerpf(
			left_arm.rotation.x,
			-0.35,
			weight
		)

		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			-0.85 + sin(animation_time * 5.0) * 0.22,
			weight
		)

		rod.rotation.x = (
			-0.5 + sin(animation_time * 5.0) * 0.15
		)
	else:
		left_arm.rotation.x = lerpf(
			left_arm.rotation.x,
			-arm_swing,
			weight
		)

		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			arm_swing,
			weight
		)

		rod.rotation.x = lerpf(
			rod.rotation.x,
			-0.5,
			weight
		)


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

	right = right.normalized()
	forward = forward.normalized()

	var direction: Vector3 = (
		right * input_dir.x
		+ forward * -input_dir.y
	)

	if direction.length() > 1.0:
		direction = direction.normalized()

	var target_velocity: Vector3 = (
		direction * MOVE_SPEED
	)

	var acceleration: float = MOVE_ACCELERATION

	if input_dir.length() < 0.01:
		acceleration = MOVE_FRICTION

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)

	position += velocity * delta

	position.x = clampf(position.x, -17.0, 17.0)
	position.z = clampf(position.z, -12.0, 17.0)

	if position.x <= -17.0 or position.x >= 17.0:
		velocity.x = 0.0

	if position.z <= -12.0 or position.z >= 17.0:
		velocity.z = 0.0

	if velocity.length() > 0.15:
		rotation.y = lerp_angle(
			rotation.y,
			atan2(velocity.x, velocity.z),
			minf(1.0, delta * ROTATION_SPEED)
		)


func _update_camera(
	delta: float,
	instant: bool = false
) -> void:
	if camera == null:
		return

	var follow_weight: float = minf(
		1.0,
		delta * CAMERA_FOLLOW_SPEED
	)

	var zoom_weight: float = minf(
		1.0,
		delta * CAMERA_ZOOM_SPEED
	)

	var rotation_weight: float = minf(
		1.0,
		delta * CAMERA_ROTATION_SPEED
	)

	if instant:
		follow_weight = 1.0
		zoom_weight = 1.0
		rotation_weight = 1.0

	camera_angle = lerp_angle(
		camera_angle,
		camera_angle_target,
		rotation_weight
	)

	camera.size = lerpf(
		camera.size,
		camera_zoom_target,
		zoom_weight
	)

	var desired_look_ahead: Vector3 = (
		velocity * CAMERA_LOOK_AHEAD
	)

	camera_look_ahead = camera_look_ahead.lerp(
		desired_look_ahead,
		follow_weight
	)

	var desired_target: Vector3 = (
		global_position + camera_look_ahead
	)

	camera_target = camera_target.lerp(
		desired_target,
		follow_weight
	)

	var offset := Vector3(
		sin(camera_angle) * CAMERA_DISTANCE,
		CAMERA_DISTANCE * CAMERA_ELEVATION,
		cos(camera_angle) * CAMERA_DISTANCE
	)

	camera.global_position = camera_target + offset

	camera.look_at(
		camera_target + Vector3(0, 0.5, 0),
		Vector3.UP
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
		velocity = Vector3.ZERO
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
			worker_manager.call("hire", i)

		hire_inside[i] = inside
