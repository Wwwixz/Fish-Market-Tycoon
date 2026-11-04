
extends CanvasLayer

const BG := Color("#172B32")
const PANEL := Color("#203941")
const PANEL_LIGHT := Color("#2A4850")
const TEXT := Color("#F2EDE2")
const MUTED := Color("#A7BCBD")
const ACCENT := Color("#8BC9B4")
const GOLD := Color("#E4BE79")
const WARNING := Color("#D98E78")

var state: Node
var navigation: Node3D
var workers: Node3D

var root: Control
var money: Label
var stocks: Label
var boat_title: Label
var boat_info: Label
var boat_progress: ProgressBar
var task: Label
var message: Label
var stats: Label

var buttons: Array[Button] = []
var notice_time: float = 0.0

var worker_names := [
	"Рыбак",
	"Грузчик рыбы",
	"Грузчик филе",
    "Продавец"
]

var worker_icons := [
	"01",
	"02",
	"03",
    "04"
]


func setup(
	game_state: Node,
	guide: Node3D,
	manager: Node3D
) -> void:
	state = game_state
	navigation = guide
	workers = manager


func _style(
	color: Color = PANEL,
	radius: int = 14
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.border_color = Color("#38565C")
	s.set_border_width_all(1)
	return s


func _button_style(
	color: Color
) -> StyleBoxFlat:
	var s := _style(color, 9)
	s.set_content_margin_all(9)
	s.border_color = color.lightened(0.12)
	return s


func _label(
	parent: Node,
	size: int,
	color: Color = TEXT
) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _stack(
	parent: Node,
	gap: int = 8
) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	parent.add_child(v)
	return v


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	parent.add_child(p)
	return p


func _section_title(
	parent: Node,
	title_text: String
) -> Label:
	var l := _label(parent, 13, MUTED)
	l.text = title_text
	return l


func _ready() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_left()
	_build_right()
	_build_bottom()

	if state != null:
		state.notice.connect(_notice)
		refresh()


func _build_left() -> void:
	var left := VBoxContainer.new()
	left.name = "LeftHUD"
	left.position = Vector2(18, 18)
	left.custom_minimum_size = Vector2(325, 0)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)

	var resource_panel := _panel(left)
	var resource_stack := _stack(resource_panel, 8)

	_section_title(
		resource_stack,
        "FISH MARKET  /  РЕСУРСЫ"
	)

	money = _label(resource_stack, 29, GOLD)
	money.text = "0 монет"

	var separator := HSeparator.new()
	resource_stack.add_child(separator)

	stocks = _label(resource_stack, 15)
	stocks.custom_minimum_size.y = 105

	var boat_panel := _panel(left)
	var boat_stack := _stack(boat_panel, 9)

	_section_title(
		boat_stack,
        "МОРСКИЕ ЗАКАЗЫ"
	)

	boat_title = _label(boat_stack, 20)
	boat_info = _label(boat_stack, 14, MUTED)

	boat_progress = ProgressBar.new()
	boat_progress.custom_minimum_size.y = 12
	boat_progress.min_value = 0.0
	boat_progress.max_value = 120.0
	boat_progress.show_percentage = false

	boat_progress.add_theme_stylebox_override(
		"background",
		_button_style(BG)
	)

	boat_progress.add_theme_stylebox_override(
		"fill",
		_button_style(ACCENT)
	)

	boat_stack.add_child(boat_progress)

	var stats_panel := _panel(left)
	var stats_stack := _stack(stats_panel, 7)

	_section_title(
		stats_stack,
        "СТАТИСТИКА"
	)

	stats = _label(stats_stack, 14, MUTED)


func _build_right() -> void:
	var right := PanelContainer.new()
	right.name = "WorkersPanel"

	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -354
	right.offset_right = -18
	right.offset_top = 18

	right.add_theme_stylebox_override(
		"panel",
		_style()
	)

	root.add_child(right)

	var stack := _stack(right, 10)

	_section_title(
		stack,
        "УПРАВЛЕНИЕ КОМАНДОЙ"
	)

	var heading := _label(stack, 23)
	heading.text = "Работники"

	var description := _label(stack, 13, MUTED)
	description.text = (
        "Нанимай команду, чтобы автоматизировать производство."
	)

	for i in range(4):
		var row := VBoxContainer.new()
		row.add_theme_constant_override(
			"separation",
			4
		)
		stack.add_child(row)

		var worker_title := _label(
			row,
			13,
			MUTED
		)

		worker_title.text = (
			worker_icons[i] + "  " + worker_names[i]
		)

		var b := Button.new()
		b.custom_minimum_size = Vector2(286, 44)

		b.add_theme_font_size_override(
			"font_size",
			15
		)

		b.add_theme_color_override(
			"font_color",
			BG
		)

		b.add_theme_color_override(
			"font_hover_color",
			BG
		)

		b.add_theme_color_override(
			"font_pressed_color",
			BG
		)

		b.add_theme_color_override(
			"font_disabled_color",
			MUTED
		)

		b.add_theme_stylebox_override(
			"normal",
			_button_style(ACCENT)
		)

		b.add_theme_stylebox_override(
			"hover",
			_button_style(ACCENT.lightened(0.12))
		)

		b.add_theme_stylebox_override(
			"pressed",
			_button_style(ACCENT.darkened(0.15))
		)

		b.add_theme_stylebox_override(
			"disabled",
			_button_style(PANEL_LIGHT)
		)

		b.pressed.connect(_buy.bind(i))

		row.add_child(b)
		buttons.append(b)

	var note := _label(stack, 12, MUTED)
	note.text = (
        "Стоимость каждого следующего работника увеличивается."
	)


func _build_bottom() -> void:
	var bottom := PanelContainer.new()
	bottom.name = "BottomHUD"

	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0

	bottom.offset_left = -355
	bottom.offset_right = 355
	bottom.offset_top = -116
	bottom.offset_bottom = -15

	bottom.add_theme_stylebox_override(
		"panel",
		_style()
	)

	root.add_child(bottom)

	var stack := _stack(bottom, 5)

	task = _label(stack, 15)
	task.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	task.custom_minimum_size.y = 22

	var controls := _label(stack, 12, MUTED)
	controls.text = (
        "WASD — движение    "
		+ "Q / E — камера    "
		+ "Колёсико — масштаб    "
		+ "R — сброс"
	)

	controls.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	message = _label(stack, 14, ACCENT)
	message.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	message.custom_minimum_size.y = 21


func _buy(role: int) -> void:
	if workers == null:
		return

	workers.call("hire", role)
	refresh()


func _notice(value: String) -> void:
	if message == null:
		return

	message.text = value
	notice_time = 3.5


func _process(delta: float) -> void:
	if state == null:
		return

	refresh()

	if notice_time > 0.0:
		notice_time -= delta

		if notice_time <= 0.0 and message != null:
			message.text = ""


func refresh() -> void:
	if state == null:
		return

	if money == null or buttons.size() < 4:
		return

	money.text = (
		"%d  МОНЕТ" % state.coins
	)

	stocks.text = (
        "У игрока       %d рыбы  /  %d филе\n"
		+ "Склад рыбы    %d\n"
		+ "Станок           %d на входе  /  %d готово\n"
		+ "Склад филе     %d"
	) % [
		state.player_fish,
		state.player_fillets,
		state.fish_box,
		state.machine_input,
		state.machine_output,
		state.fillet_box
	]

	_refresh_boat()

	if navigation != null:
		task.text = (
			"ЦЕЛЬ: " + str(navigation.current_hint)
		)

	stats.text = (
        "Лодок обслужено: %d\n"
		+ "Покупателей обслужено: %d\n"
		+ "Потеряно покупателей: %d"
	) % [
		state.served,
		state.customers_served,
		state.customers_lost
	]

	for i in range(4):
		var price: int = state.prices[i]
		var count: int = state.hired[i]

		buttons[i].text = (
            "Нанять  ·  %d монет   |   %d чел."
		) % [
			price,
			count
		]

		buttons[i].disabled = (
			state.coins < price
		)


func _refresh_boat() -> void:
	match String(state.boat_state):
		"none":
			boat_title.text = "Ожидаем лодку"
			boat_info.text = (
                "Следующий заказ скоро появится."
			)
			boat_progress.value = 0.0
			boat_progress.visible = false

		"arriving":
			boat_title.text = "Лодка приближается"
			boat_info.text = (
                "Заказ: %d филе"
				% state.boat_order
			)
			boat_progress.visible = false

		"ordering":
			boat_title.text = (
                "Заказ: %d филе"
				% state.boat_order
			)

			var seconds: int = maxi(
				0,
				int(ceil(state.boat_time))
			)

			boat_info.text = (
                "Осталось %d сек.  ·  На складе %d"
			) % [
				seconds,
				state.fillet_box
			]

			boat_progress.visible = true
			boat_progress.value = clampf(
				state.boat_time,
				0.0,
				120.0
			)

			var progress_color := ACCENT

			if state.boat_time <= 30.0:
				progress_color = WARNING

			boat_progress.add_theme_stylebox_override(
				"fill",
				_button_style(progress_color)
			)

		"leaving":
			boat_title.text = "Лодка отплывает"
			boat_info.text = (
                "Ожидаем следующего покупателя."
			)
			boat_progress.visible = false

		_:
			boat_title.text = "Морские заказы"
			boat_info.text = "Ожидание..."
			boat_progress.visible = false
