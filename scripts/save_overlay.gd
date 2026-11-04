
extends CanvasLayer

var state: Node
var save_manager: Node

var stats_label: Label
var status_label: Label
var save_button: Button
var status_timer: float = 0.0

func setup(game_state: Node, manager: Node) -> void:
	state = game_state
	save_manager = manager

func _ready() -> void:
	layer = 10

	var root := Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = 185
	root.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20363D", 0.93)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "FISH MARKET"
	title.add_theme_color_override(
		"font_color", Color("#E4D8B5")
	)
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	stats_label = Label.new()
	stats_label.add_theme_color_override(
		"font_color", Color("#F4F1E7")
	)
	stats_label.add_theme_font_size_override("font_size", 14)
	column.add_child(stats_label)

	save_button = Button.new()
	save_button.text = "СОХРАНИТЬ"
	save_button.pressed.connect(_save_pressed)
	column.add_child(save_button)

	status_label = Label.new()
	status_label.text = "Автосохранение: 30 сек."
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override(
		"font_color", Color("#A7C5BD")
	)
	column.add_child(status_label)

	state.changed.connect(refresh)
	save_manager.saved.connect(_on_saved)
	save_manager.loaded.connect(_on_loaded)
	save_manager.save_failed.connect(_on_error)

	refresh()

func refresh() -> void:
	if state == null or stats_label == null:
		return

	stats_label.text = (
        "Монеты: %d\n"
		+ "Лодки: %d  |  Покупатели: %d\n"
		+ "Филе на складе: %d"
	) % [
		state.coins,
		state.served,
		state.customers_served,
		state.fillet_box
	]

func _save_pressed() -> void:
	save_manager.save_game()

func _on_saved() -> void:
	_show_status("Игра сохранена", Color("#A5E3B3"))

func _on_loaded() -> void:
	_show_status("Прогресс загружен", Color("#A5E3B3"))
	refresh()

func _on_error(message: String) -> void:
	_show_status(message, Color("#F1A5A0"))

func _show_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
	status_timer = 3.0

func _process(delta: float) -> void:
	if status_timer <= 0.0:
		return

	status_timer -= delta

	if status_timer <= 0.0:
		status_label.text = "Автосохранение: 30 сек."
		status_label.add_theme_color_override(
			"font_color", Color("#A7C5BD")
		)
