
extends CanvasLayer

const BG := Color("#172B32")
const PANEL := Color("#203941")
const CARD := Color("#2A4850")
const TEXT := Color("#F2EDE2")
const MUTED := Color("#A7BCBD")
const ACCENT := Color("#8BC9B4")
const GOLD := Color("#E4BE79")

var manager: Node
var overlay: Control
var panel: PanelContainer
var open_button: Button
var rows: Array[Dictionary] = []


func setup(daily_manager: Node) -> void:
	manager = daily_manager


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style


func _label(
	parent: Node,
	value: String,
	size: int,
	color: Color = TEXT
) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _ready() -> void:
	layer = 16

	open_button = Button.new()
	open_button.text = "ЕЖЕДНЕВНО"
	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.anchor_top = 0.58
	open_button.anchor_bottom = 0.58
	open_button.offset_left = -142
	open_button.offset_right = -12
	open_button.offset_top = 54
	open_button.offset_bottom = 100
	open_button.add_theme_stylebox_override(
		"normal", _style(GOLD)
	)
	open_button.add_theme_color_override(
		"font_color", BG
	)
	open_button.pressed.connect(_open)
	add_child(open_button)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(shade)

	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.add_theme_stylebox_override(
		"panel", _style(PANEL)
	)
	overlay.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := _label(header, "ЦЕЛИ И НАГРАДЫ", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(44, 42)
	close.pressed.connect(_close)
	header.add_child(close)

	_label(content, "ЕЖЕДНЕВНЫЕ ЗАДАНИЯ", 16, GOLD)

	for i in range(3):
		_make_row(content, i, true)

	_label(content, "ДОСТИЖЕНИЯ", 16, GOLD)

	for i in range(3):
		_make_row(content, i, false)

	overlay.visible = false
	_resize()
	get_viewport().size_changed.connect(_resize)

	if manager != null:
		manager.updated.connect(refresh)

	refresh()


func _make_row(
	parent: Node,
	index: int,
	is_daily: bool
) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel", _style(CARD)
	)
	parent.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)

	var title := _label(stack, "", 15)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9
	bar.add_theme_stylebox_override(
		"background", _style(BG)
	)
	bar.add_theme_stylebox_override(
		"fill", _style(ACCENT)
	)
	stack.add_child(bar)

	var footer := _label(stack, "", 12, MUTED)

	rows.append({
		"index": index,
		"daily": is_daily,
		"title": title,
		"bar": bar,
		"footer": footer
	})


func _resize() -> void:
	if panel == null:
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(440.0, screen.x - 24.0)
	var height: float = minf(650.0, screen.y - 40.0)

	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0


func _open() -> void:
	refresh()
	overlay.visible = true
	open_button.visible = false


func _close() -> void:
	overlay.visible = false
	open_button.visible = true


func refresh() -> void:
	if manager == null:
		return

	for row in rows:
		var index: int = int(row["index"])
		var is_daily: bool = bool(row["daily"])

		var data: Dictionary
		var current: int
		var done: bool

		if is_daily:
			data = manager.DAILY[index]
			current = manager.daily_progress[index]
			done = manager.daily_done[index]
		else:
			data = manager.ACHIEVEMENTS[index]
			current = manager.get_achievement_progress(index)
			done = manager.achievement_done[index]

		var target: int = int(data["target"])
		var title: Label = row["title"]
		var bar: ProgressBar = row["bar"]
		var footer: Label = row["footer"]

		title.text = String(data["title"])
		bar.value = clampf(
			float(current) / float(target) * 100.0,
			0.0,
			100.0
		)

		if done:
			footer.text = "ВЫПОЛНЕНО ✓"
		else:
			footer.text = "%d/%d   ·   +%d монет" % [
				current, target, int(data["reward"])
			]
