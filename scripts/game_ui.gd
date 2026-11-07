
extends CanvasLayer

signal modal_opened

const UITheme = preload("res://scripts/ui_theme.gd")

const BG := Color("#172B32")
const PANEL := Color("#203941")
const CARD := Color("#2A4850")
const TEXT := Color("#F2EDE2")
const MUTED := Color("#A7BCBD")
const ACCENT := Color("#8BC9B4")
const GOLD := Color("#E4BE79")
const WARNING := Color("#D98E78")

const WORKER_NAMES := [
	"Рыбак",
	"Грузчик рыбы",
	"Грузчик филе",
	"Продавец"
]

var state: Node
var navigation: Node3D
var workers: Node3D
var progression: Node

var root: Control
var top_panel: PanelContainer
var inventory: Label
var menu_tabs: Array[Button] = []
var money: Label
var xp_label: Label
var xp_progress: ProgressBar

var boat_panel: PanelContainer
var boat_title: Label
var boat_info: Label
var boat_progress: ProgressBar

var bottom_panel: PanelContainer
var task: Label
var message: Label

var menu_button: Button
var overlay: Control
var menu_window: PanelContainer
var menu_content: VBoxContainer
var menu_title: Label
var menu_tab: int = 0

var notice_time: float = 0.0
var update_time: float = 0.0


func setup(
	game_state: Node,
	guide: Node3D,
	manager: Node3D
) -> void:
	state = game_state
	navigation = guide
	workers = manager


func _style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(0 if radius <= 6 else 14)
	return s


func _label(
	parent: Node,
	value: String,
	font_size: int,
	color: Color = TEXT
) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", maxi(16, font_size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 3
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(l)
	return l


func _stack(parent: Node, gap: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	parent.add_child(v)
	return v


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "MobileHUD"
	root.theme = UITheme.create()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top()
	_build_boat()
	_build_bottom()
	_build_menu_button()
	_build_menu()
	for panel in [top_panel, boat_panel, bottom_panel]:
		UITheme.passthrough(panel)

	get_viewport().size_changed.connect(_resize)
	_resize()

	if state != null:
		state.notice.connect(_notice)

	refresh()


func _build_top() -> void:
	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override(
		"panel", _style(PANEL)
	)
	root.add_child(top_panel)

	var stack := _stack(top_panel, 5)

	var row := HBoxContainer.new()
	stack.add_child(row)

	money = _label(row, "0 монет", 26, GOLD)
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.clip_text = true

	xp_label = _label(row, "Уровень 1", 13, MUTED)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.custom_minimum_size.x = 58

	xp_progress = ProgressBar.new()
	xp_progress.custom_minimum_size.y = 7
	xp_progress.show_percentage = false
	xp_progress.min_value = 0
	xp_progress.max_value = 100
	xp_progress.add_theme_stylebox_override(
		"background", _style(BG, 5)
	)
	xp_progress.add_theme_stylebox_override(
		"fill", _style(ACCENT, 5)
	)
	stack.add_child(xp_progress)


func _build_boat() -> void:
	boat_panel = PanelContainer.new()
	boat_panel.add_theme_stylebox_override(
		"panel", _style(PANEL)
	)
	root.add_child(boat_panel)

	var stack := _stack(boat_panel, 5)

	boat_title = _label(stack, "Ожидаем лодку", 16)
	boat_info = _label(stack, "", 12, MUTED)
	for label in [boat_title, boat_info]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
	boat_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boat_info.max_lines_visible = 2
	boat_info.clip_text = false
	boat_info.custom_minimum_size.y = 40

	boat_progress = ProgressBar.new()
	boat_progress.custom_minimum_size.y = 8
	boat_progress.min_value = 0
	boat_progress.max_value = 120
	boat_progress.show_percentage = false
	boat_progress.add_theme_stylebox_override(
		"background", _style(BG, 5)
	)
	boat_progress.add_theme_stylebox_override(
		"fill", _style(ACCENT, 5)
	)
	stack.add_child(boat_progress)


func _build_bottom() -> void:
	bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override(
		"panel", _style(PANEL)
	)
	root.add_child(bottom_panel)

	var stack := _stack(bottom_panel, 8)
	inventory = _label(stack, "", 17, GOLD)
	inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory.autowrap_mode = TextServer.AUTOWRAP_OFF
	inventory.clip_text = true

	task = _label(stack, "Цель: ловить рыбу", 13)
	task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task.max_lines_visible = 2

	message = _label(stack, "", 12, ACCENT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_menu_button() -> void:
	menu_button = Button.new()
	menu_button.theme_type_variation = "PrimaryButton"
	menu_button.text = "Команда"
	menu_button.add_theme_font_size_override("font_size", 17)
	menu_button.add_theme_color_override("font_color", BG)
	menu_button.add_theme_stylebox_override(
		"normal", _style(ACCENT, 10)
	)
	menu_button.pressed.connect(_open_menu)
	root.add_child(menu_button)


func _build_menu() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	menu_window = PanelContainer.new()
	menu_window.anchor_left = 0.5
	menu_window.anchor_right = 0.5
	menu_window.anchor_top = 0.5
	menu_window.anchor_bottom = 0.5
	menu_window.add_theme_stylebox_override(
		"panel", _style(PANEL, 18)
	)
	overlay.add_child(menu_window)

	var layout := _stack(menu_window, 10)

	var header := HBoxContainer.new()
	layout.add_child(header)

	menu_title = _label(header, "Управление", 24)
	menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(48, 48)
	close.pressed.connect(_close_menu)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	layout.add_child(tabs)

	for i in range(3):
		var b := Button.new()
		b.text = ["Команда", "Ресурсы", "Статистика"][i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 48
		b.add_theme_font_size_override("font_size", 16)
		b.clip_text = true
		menu_tabs.append(b)
		b.pressed.connect(_select_menu.bind(i))
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	layout.add_child(scroll)

	menu_content = VBoxContainer.new()
	menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_content.add_theme_constant_override("separation", 9)
	scroll.add_child(menu_content)

	overlay.visible = false


func _resize() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 16.0
	var actions_width: float = 112.0
	var panel_width: float = minf(370.0, screen.x - margin * 3.0 - actions_width)
	money.add_theme_font_size_override("font_size", 20 if screen.x < 500.0 else 26)

	top_panel.position = Vector2(margin, margin)
	top_panel.size = Vector2(panel_width, 80)
	boat_panel.position = Vector2(margin, 108)
	boat_panel.size = Vector2(panel_width, 100)
	menu_button.position = Vector2(screen.x - margin - actions_width, margin)
	menu_button.size = Vector2(actions_width, 52)

	var bottom_width: float = minf(screen.x - margin * 2.0, 560.0)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_panel.offset_left = (screen.x - bottom_width) * 0.5
	bottom_panel.offset_right = -(screen.x - bottom_width) * 0.5
	bottom_panel.offset_top = -112.0
	bottom_panel.offset_bottom = -16.0

	var window_width: float = minf(540.0, screen.x - 32.0)
	var window_height: float = minf(760.0, screen.y - 40.0)
	menu_window.offset_left = -window_width / 2.0
	menu_window.offset_right = window_width / 2.0
	menu_window.offset_top = -window_height / 2.0
	menu_window.offset_bottom = window_height / 2.0
	for i in range(menu_tabs.size()):
		menu_tabs[i].text = ["Люди", "Запасы", "Итоги"][i] if screen.x < 440.0 else ["Команда", "Ресурсы", "Статистика"][i]
		menu_tabs[i].add_theme_font_size_override("font_size", 14 if screen.x < 440.0 else 16)


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _open_menu() -> void:
	modal_opened.emit()
	get_tree().call_group("movement_joystick", "release")
	layer = 30
	menu_tab = 0
	overlay.visible = true
	menu_button.visible = false
	_rebuild_menu()


func _close_menu() -> void:
	layer = 20
	overlay.visible = false
	menu_button.visible = true


func _select_menu(index: int) -> void:
	menu_tab = index
	_rebuild_menu()


func _clear_menu() -> void:
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()


func _rebuild_menu() -> void:
	if menu_content == null or state == null:
		return

	_clear_menu()
	for i in range(menu_tabs.size()):
		var selected: bool = i == menu_tab
		menu_tabs[i].add_theme_stylebox_override("normal", _style(ACCENT if selected else CARD, 10))
		menu_tabs[i].add_theme_color_override("font_color", BG if selected else TEXT)

	match menu_tab:
		0:
			_build_workers_content()
		1:
			_build_resources_content()
		2:
			_build_stats_content()


func _build_workers_content() -> void:
	_label(
		menu_content,
		"Нанимай работников для автоматизации",
		13,
		MUTED
	)

	for i in range(4):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel", _style(CARD)
		)
		menu_content.add_child(card)

		var stack := _stack(card, 7)

		_label(
			stack,
			WORKER_NAMES[i],
			16
		)

		var count: int = int(state.hired[i])
		var price: int = int(state.prices[i])

		_label(
			stack,
			"Работников: %d" % count,
			13,
			MUTED
		)

		var hire_button := Button.new()
		hire_button.theme_type_variation = "PrimaryButton"
		hire_button.text = "Нанять · %d монет" % price
		hire_button.custom_minimum_size.y = 43
		hire_button.disabled = state.coins < price
		hire_button.add_theme_color_override(
			"font_color", BG
		)
		hire_button.add_theme_stylebox_override(
			"normal", _style(ACCENT, 9)
		)
		hire_button.pressed.connect(_buy.bind(i))
		stack.add_child(hire_button)


func _build_resources_content() -> void:
	var lines := [
		"У игрока — рыба: %d" % state.player_fish,
		"У игрока — филе: %d" % state.player_fillets,
		"Склад рыбы: %d" % state.fish_box,
		"Станок — на входе: %d" % state.machine_input,
		"Станок — готово: %d" % state.machine_output,
		"Склад филе: %d" % state.fillet_box
	]

	for line in lines:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel", _style(CARD)
		)
		menu_content.add_child(card)
		_label(card, line, 15)


func _build_stats_content() -> void:
	var lines := [
		"Монеты: %d" % state.coins,
		"Обслужено лодок: %d" % state.served,
		"Обслужено покупателей: %d" % state.customers_served,
		"Потеряно покупателей: %d" % state.customers_lost
	]

	for line in lines:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel", _style(CARD)
		)
		menu_content.add_child(card)
		_label(card, line, 15)


func _buy(role: int) -> void:
	if workers == null:
		return

	workers.call("hire", role)
	refresh()
	_rebuild_menu()


func _notice(value: String) -> void:
	if message == null:
		return

	message.text = value
	message.show()
	notice_time = 3.5


func _process(delta: float) -> void:
	update_time += delta

	if update_time >= 0.2:
		update_time = 0.0
		refresh()

	if notice_time > 0.0:
		notice_time -= delta

		if notice_time <= 0.0:
			message.text = ""
			message.hide()


func refresh() -> void:
	if state == null or money == null:
		return

	money.text = ("%d" if get_viewport().get_visible_rect().size.x < 500.0 else "%d монет") % state.coins
	money.tooltip_text = "%d монет" % state.coins
	inventory.text = "Рыба: %d    ·    Филе: %d    ·    Склад: %d" % [state.player_fish, state.player_fillets, state.fillet_box]
	message.visible = notice_time > 0.0

	if navigation != null:
		task.text = "ЦЕЛЬ: " + str(
			navigation.current_hint
		)

	_refresh_xp()
	_refresh_boat()


func _refresh_xp() -> void:
	if progression == null:
		return

	var level: int = int(progression.level)
	var xp: int = int(progression.xp)
	var required: int = int(progression.xp_required())

	xp_label.text = "Ур. %d" % level
	xp_progress.tooltip_text = "Опыт: %d / %d" % [xp, required]

	if required > 0:
		xp_progress.value = (
			float(xp) / float(required) * 100.0
		)
	else:
		xp_progress.value = 100.0


func _refresh_boat() -> void:
	match String(state.boat_state):
		"none":
			boat_title.text = "Ожидаем лодку"
			boat_info.text = "Следующий заказ скоро появится"
			boat_progress.visible = false

		"arriving":
			boat_title.text = "Лодка приближается"
			boat_info.text = "Заказ: %d филе" % state.boat_order
			boat_progress.visible = false

		"ordering":
			boat_title.text = (
				"Заказ: %d филе" % state.boat_order
			)

			boat_info.text = (
				"Осталось %d сек. · На складе %d"
			) % [
				maxi(0, int(ceil(state.boat_time))),
				state.fillet_box
			]

			boat_progress.visible = true
			boat_progress.value = clampf(
				float(state.boat_time),
				0.0,
				120.0
			)

			var fill_color: Color = (
				WARNING
				if state.boat_time <= 30.0
				else ACCENT
			)

			boat_progress.add_theme_stylebox_override(
				"fill", _style(fill_color, 5)
			)

		"leaving":
			boat_title.text = "Лодка отплывает"
			boat_info.text = "Ожидаем следующий заказ"
			boat_progress.visible = false

		_:
			boat_title.text = "Морские заказы"
			boat_info.text = "Ожидание"
			boat_progress.visible = false
