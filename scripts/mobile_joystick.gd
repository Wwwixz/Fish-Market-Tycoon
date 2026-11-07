
extends Control

signal direction_changed(value: Vector2)

const BASE_COLOR := Color("#203941", 0.78)
const RING_COLOR := Color("#8BC9B4")
const KNOB_COLOR := Color("#A7D8C7")

const BASE_RADIUS := 72.0
const KNOB_RADIUS := 29.0
const DEAD_ZONE := 0.12

var direction: Vector2 = Vector2.ZERO
var knob_offset: Vector2 = Vector2.ZERO

var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true


func _ready() -> void:
	add_to_group("movement_joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96, 96)
	hide()


func _draw() -> void:
	var center: Vector2 = size * 0.5

	var radius: float = minf(
		BASE_RADIUS,
		minf(size.x, size.y) * 0.43
	)

	draw_circle(
		center,
		radius,
		BASE_COLOR
	)

	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		RING_COLOR,
		3.0,
		true
	)

	draw_circle(
		center + knob_offset,
		minf(KNOB_RADIUS, radius * 0.45),
		KNOB_COLOR
	)


# Start after GUI controls have had a chance to handle the press.
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or touch_id != -1 or mouse_active:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		touch_id = event.index
		_begin(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mouse_active = true
			_begin(event)


func _begin(event: InputEvent) -> void:
	# Convert from viewport coordinates into the joystick parent's space.
	position += make_input_local(event).position - size * 0.5
	_reset()
	show()
	get_viewport().set_input_as_handled()


# Track an active gesture even when the pointer moves over the GUI.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == touch_id and (not event.pressed or event.canceled):
			release()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == touch_id:
			_update_direction(make_input_local(event).position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if mouse_active and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if mouse_active:
			_update_direction(make_input_local(event).position)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release()


func _update_direction(
	local_position: Vector2
) -> void:
	var center: Vector2 = size * 0.5
	var delta: Vector2 = local_position - center

	var radius: float = minf(
		BASE_RADIUS,
		minf(size.x, size.y) * 0.43
	)

	var max_distance: float = maxf(
		1.0,
		radius * 0.8
	)

	knob_offset = delta.limit_length(max_distance)

	var raw: Vector2 = knob_offset / max_distance
	var strength: float = raw.length()

	if strength < DEAD_ZONE:
		direction = Vector2.ZERO
	else:
		var adjusted: float = (
			(strength - DEAD_ZONE)
			/ (1.0 - DEAD_ZONE)
		)

		direction = (
			raw.normalized()
			* clampf(adjusted, 0.0, 1.0)
		)

	queue_redraw()
	direction_changed.emit(direction)


func _reset() -> void:
	direction = Vector2.ZERO
	knob_offset = Vector2.ZERO
	queue_redraw()
	direction_changed.emit(direction)


func get_direction() -> Vector2:
	return direction


func release() -> void:
	touch_id = -1
	mouse_active = false
	_reset()
	hide()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		release()
