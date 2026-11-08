
extends CanvasLayer

const UITheme = preload("res://scripts/ui_theme.gd")

const Joystick = preload(
	"res://scripts/mobile_joystick.gd"
)

var player: Node3D
var joystick: Control
var zoom_controls: VBoxContainer
var zoom_buttons: Array[Button] = []


func setup(game_player: Node3D) -> void:
	player = game_player


func _ready() -> void:
	layer = 10

	joystick = Joystick.new()
	joystick.name = "MovementJoystick"
	joystick.direction_changed.connect(_on_direction_changed)
	add_child(joystick)
	_build_zoom_controls()

	get_viewport().size_changed.connect(_resize)

	_resize()


func _build_zoom_controls() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.create()
	add_child(root)
	zoom_controls = VBoxContainer.new()
	zoom_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_controls.add_theme_constant_override("separation", 12)
	root.add_child(zoom_controls)
	for amount in [-3.0, 3.0]:
		var button := Button.new()
		button.text = "+" if amount < 0.0 else "−"
		button.tooltip_text = "Приблизить" if amount < 0.0 else "Отдалить"
		button.custom_minimum_size = Vector2(UITheme.TOUCH_SIZE, UITheme.TOUCH_SIZE)
		button.add_theme_font_size_override("font_size", 30)
		button.focus_mode = Control.FOCUS_NONE
		UITheme.button_feedback(button)
		button.pressed.connect(_zoom.bind(amount))
		zoom_controls.add_child(button)
		zoom_buttons.append(button)


func _zoom(amount: float) -> void:
	if player != null:
		player.adjust_camera_zoom(amount)


func _resize() -> void:
	if joystick == null:
		return

	var screen: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var joystick_size: float = minf(
		140.0,
		screen.x * 0.30
	)
	var safe := UITheme.safe_rect(get_viewport())
	zoom_controls.position = Vector2(safe.end.x - UITheme.EDGE_MARGIN - UITheme.TOUCH_SIZE, safe.position.y + 104.0)

	joystick.release()

	joystick.size = Vector2(
		joystick_size,
		joystick_size
	)


func _on_direction_changed(value: Vector2) -> void:
	if player == null or joystick == null:
		return

	player.set(
		"mobile_input",
		value
	)


func set_enabled(value: bool) -> void:
	joystick.set_enabled(value)
	zoom_controls.visible = value
	for button in zoom_buttons:
		button.disabled = not value
