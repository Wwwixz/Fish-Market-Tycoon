
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

var quest_manager: Node
var daily_manager: Node

var open_button: Button
var overlay: Control
var window: PanelContainer
var cards: VBoxContainer
var tab_buttons: Array[Button] = []

var active_tab: int = 0


func setup(
	quests: Node,
	daily: Node
) -> void:
	quest_manager = quests
	daily_manager = daily


func _ready() -> void:
	layer = 20

	_build_button()
	_build_window()

	if quest_manager != null:
		quest_manager.quests_updated.connect(refresh)

	if daily_manager != null:
		daily_manager.updated.connect(refresh)

	get_viewport().size_changed.connect(_resize)

	_resize()
	refresh()


func _style(
	color: Color,
	radius: int = 12
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(0 if radius <= 6 else 14)
	return style


func _label(
	parent: Node,
	value: String,
	size: int,
	color: Color = TEXT
) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override(
		"font_size", maxi(16, size)
	)
	label.add_theme_color_override(
		"font_color", color
	)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 4
	parent.add_child(label)
	return label


func _build_button() -> void:
	open_button = Button.new()
	open_button.theme = UITheme.create()
	open_button.theme_type_variation = "PrimaryButton"
	open_button.text = "Задания"

	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.anchor_top = 0.0
	open_button.anchor_bottom = 0.0

	open_button.offset_left = -128
	open_button.offset_right = -16
	open_button.offset_top = 80
	open_button.offset_bottom = 132

	open_button.add_theme_font_size_override(
		"font_size", 17
	)
	open_button.add_theme_color_override(
		"font_color", BG
	)
	open_button.add_theme_stylebox_override(
		"normal", _style(ACCENT)
	)
	open_button.add_theme_stylebox_override(
		"hover", _style(ACCENT.lightened(0.1))
	)

	open_button.pressed.connect(_open)
	add_child(open_button)


func _build_window() -> void:
	overlay = Control.new()
	overlay.theme = UITheme.create()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	window = PanelContainer.new()
	window.anchor_left = 0.5
	window.anchor_right = 0.5
	window.anchor_top = 0.5
	window.anchor_bottom = 0.5

	window.add_theme_stylebox_override(
		"panel", _style(PANEL, 18)
	)
	overlay.add_child(window)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(
		"separation", 12
	)
	window.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := _label(
		header,
		"ЗАДАНИЯ",
		23
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(48, 48)
	close.add_theme_stylebox_override(
		"normal", _style(CARD)
	)
	close.pressed.connect(_close)
	header.add_child(close)

	var subtitle := _label(
		layout,
		"Развивай бизнес и получай награды",
		13,
		MUTED
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(
		"separation", 5
	)
	layout.add_child(tabs)

	var names := [
		"Основные",
		"Ежедневные",
		"Достижения"
	]

	for i in range(3):
		var button := Button.new()
		button.text = names[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.clip_text = true
		button.add_theme_font_size_override(
			"font_size", 16
		)
		button.pressed.connect(
			_select_tab.bind(i)
		)

		tabs.add_child(button)
		tab_buttons.append(button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	layout.add_child(scroll)

	cards = VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(
		"separation", 10
	)
	scroll.add_child(cards)

	overlay.visible = false


func _resize() -> void:
	if window == null:
		return

	var screen: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var width: float = minf(
		540.0,
		maxf(220.0, screen.x - 32.0)
	)

	var height: float = minf(
		760.0,
		maxf(220.0, screen.y - 40.0)
	)

	window.offset_left = -width / 2.0
	window.offset_right = width / 2.0
	window.offset_top = -height / 2.0
	window.offset_bottom = height / 2.0
	for i in range(tab_buttons.size()):
		tab_buttons[i].text = ["Цели", "На день", "Награды"][i] if screen.x < 440.0 else ["Основные", "Ежедневные", "Достижения"][i]
		tab_buttons[i].add_theme_font_size_override("font_size", 14 if screen.x < 440.0 else 16)


func _open() -> void:
	modal_opened.emit()
	get_tree().call_group("movement_joystick", "release")
	layer = 30
	refresh()
	overlay.visible = true
	open_button.visible = false


func _close() -> void:
	layer = 20
	overlay.visible = false
	open_button.visible = true


func _select_tab(index: int) -> void:
	active_tab = index
	refresh()


func _update_tabs() -> void:
	for i in range(tab_buttons.size()):
		var button: Button = tab_buttons[i]
		var selected: bool = i == active_tab

		var color: Color = (
			ACCENT if selected else CARD
		)

		var font_color: Color = (
			BG if selected else TEXT
		)

		button.add_theme_stylebox_override(
			"normal", _style(color, 9)
		)
		button.add_theme_stylebox_override(
			"hover", _style(color.lightened(0.08), 9)
		)
		button.add_theme_stylebox_override(
			"pressed", _style(color.darkened(0.08), 9)
		)

		button.add_theme_color_override(
			"font_color", font_color
		)
		button.add_theme_color_override(
			"font_hover_color", font_color
		)
		button.add_theme_color_override(
			"font_pressed_color", font_color
		)


func refresh() -> void:
	if cards == null:
		return

	_update_tabs()

	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()

	match active_tab:
		0:
			_show_main_quests()
		1:
			_show_daily_quests()
		2:
			_show_achievements()


func _show_main_quests() -> void:
	if quest_manager == null:
		return

	for i in range(quest_manager.QUESTS.size()):
		var data: Dictionary = quest_manager.QUESTS[i]
		var current: int = quest_manager.progress[i]
		var done: bool = quest_manager.completed[i]

		_make_card(data, current, done)


func _show_daily_quests() -> void:
	if daily_manager == null:
		return

	_label(
		cards,
		"Обновляются каждый день",
		13,
		MUTED
	)

	for i in range(daily_manager.DAILY.size()):
		var data: Dictionary = daily_manager.DAILY[i]
		var current: int = daily_manager.daily_progress[i]
		var done: bool = daily_manager.daily_done[i]

		_make_card(data, current, done)


func _show_achievements() -> void:
	if daily_manager == null:
		return

	_label(
		cards,
		"Постоянные награды за развитие бизнеса",
		13,
		MUTED
	)

	for i in range(daily_manager.ACHIEVEMENTS.size()):
		var data: Dictionary = daily_manager.ACHIEVEMENTS[i]
		var current: int = (
			daily_manager.get_achievement_progress(i)
		)
		var done: bool = daily_manager.achievement_done[i]

		_make_card(data, current, done)


func _make_card(
	data: Dictionary,
	current: int,
	done: bool
) -> void:
	var target: int = int(data["target"])
	var reward_amount: int = int(data["reward"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel", _style(CARD)
	)
	cards.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(
		"separation", 8
	)
	card.add_child(stack)

	var title := _label(
		stack,
		String(data["title"]),
		17
	)

	if done:
		title.add_theme_color_override(
			"font_color", ACCENT
		)

	if data.has("description"):
		_label(
			stack,
			String(data["description"]),
			13,
			MUTED
		)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 11

	bar.value = clampf(
		float(current) / float(maxi(1, target)) * 100.0,
		0.0,
		100.0
	)

	bar.add_theme_stylebox_override(
		"background", _style(BG, 6)
	)
	bar.add_theme_stylebox_override(
		"fill", _style(ACCENT, 6)
	)

	stack.add_child(bar)

	var footer := HBoxContainer.new()
	stack.add_child(footer)

	var progress_text: String = (
		"ВЫПОЛНЕНО ✓"
		if done
		else "%d / %d" % [current, target]
	)

	var counter := _label(
		footer,
		progress_text,
		13,
		ACCENT if done else MUTED
	)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var reward_text: String = (
		"ПОЛУЧЕНО"
		if done
		else "+%d монет" % reward_amount
	)

	_label(
		footer,
		reward_text,
		13,
		GOLD
	)


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
