
extends CanvasLayer

const S = preload("res://scripts/game_state.gd")

var state
var navigation
var workers

var money: Label
var stocks: Label
var boat: Label
var task: Label
var message: Label

var buttons: Array[Button] = []
var notice_time := 0.0

func setup(
	game_state: Node,
	guide: Node3D,
	manager: Node3D
) -> void:
	state = game_state
	navigation = guide
	workers = manager

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.17, 0.2, 0.93)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	return style

func _text(
	parent: Node,
	size: int
) -> Label:
	var l := Label.new()

	l.add_theme_font_size_override(
		"font_size",
		size
	)

	l.add_theme_color_override(
		"font_color",
		Color("#F1E7D6")
	)

	parent.add_child(l)
	return l

func _ready() -> void:
	var root := Control.new()
	add_child(root)

	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := PanelContainer.new()
	left.position = Vector2(16, 16)
	left.custom_minimum_size = Vector2(345, 175)

	left.add_theme_stylebox_override(
		"panel",
		_panel()
	)

	root.add_child(left)

	var stack := VBoxContainer.new()
	left.add_child(stack)

	money = _text(stack, 24)
	stocks = _text(stack, 17)
	boat = _text(stack, 17)
	task = _text(stack, 16)

	var right := PanelContainer.new()

	right.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)

	right.offset_left = -340
	right.offset_right = -16
	right.offset_top = 16
	right.offset_bottom = 335

	right.add_theme_stylebox_override(
		"panel",
		_panel()
	)

	root.add_child(right)

	var hire_stack := VBoxContainer.new()

	hire_stack.add_theme_constant_override(
		"separation",
		8
	)

	right.add_child(hire_stack)

	var title := _text(hire_stack, 23)
	title.text = "НАЙМ РАБОТНИКОВ"

	for i in range(4):
		var b := Button.new()

		b.custom_minimum_size = Vector2(290, 48)

		b.add_theme_font_size_override(
			"font_size",
			17
		)

		b.pressed.connect(_buy.bind(i))

		hire_stack.add_child(b)
		buttons.append(b)

	var note := _text(hire_stack, 14)
	note.text = (
        "Каждый следующий работник дороже"
	)

	var bottom := PanelContainer.new()

	bottom.set_anchors_preset(
		Control.PRESET_CENTER_BOTTOM
	)

	bottom.offset_left = -390
	bottom.offset_right = 390
	bottom.offset_top = -100
	bottom.offset_bottom = -15

	bottom.add_theme_stylebox_override(
		"panel",
		_panel()
	)

	root.add_child(bottom)

	var bottom_stack := VBoxContainer.new()
	bottom.add_child(bottom_stack)

	var controls := _text(bottom_stack, 16)
	controls.text = (
        "WASD — движение  |  "
		+ "Колёсико — масштаб"
	)

	controls.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	message = _text(bottom_stack, 17)

	message.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	state.notice.connect(_notice)
	refresh()

func _buy(role: int) -> void:
	workers.hire(role)
	refresh()

func _notice(value: String) -> void:
	message.text = value
	notice_time = 3.0

func _process(delta: float) -> void:
	if state == null:
		return

	refresh()

	if notice_time > 0:
		notice_time -= delta

		if notice_time <= 0:
			message.text = ""

func refresh() -> void:
	if money == null or buttons.size() < 4:
		return

	money.text = (
		"МОНЕТЫ: %d" % state.coins
	)

	stocks.text = (
        "У тебя: %d 🐟 | %d 🍣\n"
		+ "Ящик рыбы: %d | Станок: %d / %d\n"
		+ "Ящик филе: %d"
	) % [
		state.player_fish,
		state.player_fillets,
		state.fish_box,
		state.machine_input,
		state.machine_output,
		state.fillet_box
	]

	if state.boat_state == "ordering":
		boat.text = (
            "Лодка: нужно %d филе | "
			+ "осталось %d сек."
		) % [
			state.boat_order,
			int(state.boat_time)
		]
	else:
		boat.text = (
			"Лодка: %s" % state.boat_state
		)

	task.text = (
		"ЦЕЛЬ: " + navigation.current_hint
	)

	var names := [
		"Рыбак",
		"Грузчик рыбы",
		"Грузчик филе",
        "Продавец"
	]

	for i in range(4):
		buttons[i].text = (
            "%s (%d) — %d монет"
		) % [
			names[i],
			state.hired[i],
			state.prices[i]
		]

		buttons[i].disabled = (
			state.coins < state.prices[i]
		)
