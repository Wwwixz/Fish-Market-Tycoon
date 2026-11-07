extends RefCounted

const TEXT := Color("#F2EDE2")
const MUTED := Color("#A7BCBD")
const ACCENT := Color("#8BC9B4")

static func panel(color: Color, radius: int = 14, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_constant("separation", "VBoxContainer", 10)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := Color("#304D56")
		if state == "hover":
			color = color.lightened(0.12)
		elif state == "pressed":
			color = color.darkened(0.18)
		elif state == "disabled":
			color = Color("#263C43")
		var style := panel(color, 12, 12)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = ACCENT
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		var color := ACCENT
		if state == "hover":
			color = color.lightened(0.1)
		elif state == "pressed":
			color = color.darkened(0.12)
		theme.set_stylebox(state, "PrimaryButton", panel(color, 12, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "PrimaryButton", Color("#172B32"))
	theme.set_stylebox("background", "ProgressBar", panel(Color("#142830"), 4, 0))
	theme.set_stylebox("fill", "ProgressBar", panel(ACCENT, 4, 0))
	return theme


static func passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			passthrough(child)
