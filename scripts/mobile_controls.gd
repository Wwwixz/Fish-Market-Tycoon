
extends CanvasLayer

const Joystick = preload(
	"res://scripts/mobile_joystick.gd"
)

var player: Node3D
var joystick: Control


func setup(game_player: Node3D) -> void:
	player = game_player


func _ready() -> void:
	layer = 10

	joystick = Joystick.new()
	joystick.name = "MovementJoystick"
	add_child(joystick)

	get_viewport().size_changed.connect(_resize)

	_resize()


func _resize() -> void:
	if joystick == null:
		return

	var screen: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var joystick_size: float = minf(
		170.0,
		screen.x * 0.34
	)

	joystick.release()

	joystick.size = Vector2(
		joystick_size,
		joystick_size
	)


func _process(_delta: float) -> void:
	if player == null or joystick == null:
		return

	player.set(
		"mobile_input",
		joystick.get_direction()
	)
