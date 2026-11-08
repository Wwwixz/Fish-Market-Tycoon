extends RefCounted

const BG := Color("#172B32")
const PANEL := Color("#203941")
const CARD := Color("#2A4850")
const GOLD := Color("#E4BE79")
const WARNING := Color("#D98E78")
const TEXT := Color("#F2EDE2")
const MUTED := Color("#A7BCBD")
const ACCENT := Color("#8BC9B4")

const TOUCH_SIZE := 64.0
const EDGE_MARGIN := 16.0

static var _navigation_icons: Dictionary = {}


static func navigation_icon(index: int) -> Texture2D:
	if _navigation_icons.has(index):
		return _navigation_icons[index]
	var path := "M3 7h18v14H3z M8 7V3h8v4 M3 12h18 M10 12v3h4v-3" if index == 0 else "M9 5h12 M9 12h12 M9 19h12 M2 5l2 2 3-4 M2 12l2 2 3-4 M2 19l2 2 3-4"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#172B32" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>' % path
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	_navigation_icons[index] = texture
	return texture


static func safe_rect(viewport: Viewport) -> Rect2:
	var screen := viewport.get_visible_rect()
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return screen
	var physical_safe := Rect2(DisplayServer.get_display_safe_area())
	if not physical_safe.has_area():
		return screen
	var local_safe: Rect2 = viewport.get_screen_transform().affine_inverse() * physical_safe
	var usable := screen.intersection(local_safe)
	return usable if usable.has_area() else screen

static func panel(color: Color, radius: int = 14, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_font_size("font_size", "Button", 16)
	theme.set_constant("scroll_deadzone", "ScrollContainer", 12)
	theme.set_constant("minimum_grab_thickness", "VScrollBar", 6)
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
		theme.set_stylebox(state, "OptionButton", style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", TEXT)
		theme.set_color(state, "OptionButton", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED)
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
	theme.set_stylebox("panel", "PopupMenu", panel(PANEL, 12, 8))
	theme.set_stylebox("hover", "PopupMenu", panel(ACCENT, 8, 8))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", BG)
	theme.set_constant("v_separation", "PopupMenu", 40)
	return theme


static func passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			passthrough(child)


# Shared geometry keeps the two navigation buttons clear of the home indicator.
static func navigation_rect(viewport: Viewport, index: int) -> Rect2:
	var safe := safe_rect(viewport)
	var width := minf(560.0, safe.size.x - EDGE_MARGIN * 2.0)
	var half := (width - 10.0) * 0.5
	return Rect2(Vector2(safe.get_center().x - width * 0.5 + index * (half + 10.0), safe.end.y - EDGE_MARGIN - TOUCH_SIZE), Vector2(half, TOUCH_SIZE))


static func reveal(control: Control) -> void:
	var previous: Tween = control.get_meta("reveal_tween") if control.has_meta("reveal_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	control.modulate.a = 0.0
	var tween := control.create_tween()
	control.set_meta("reveal_tween", tween)
	tween.tween_property(control, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD)


static func select_tab(button: Button, selected: bool) -> void:
	button.theme_type_variation = "PrimaryButton" if selected else "Button"
	button.set_meta("selected", selected)


static func button_feedback(button: Button) -> void:
	# Modulate does not affect container layout or touch geometry.
	button.button_down.connect(func(): button.modulate = Color(0.82, 0.88, 0.86))
	button.button_up.connect(func(): button.modulate = Color.WHITE)


static func feedback_tree(control: Node) -> void:
	if control is Button and not control.has_meta("feedback"):
		control.set_meta("feedback", true)
		button_feedback(control)
	for child in control.get_children():
		feedback_tree(child)


static func number(value: int) -> String:
	if value >= 1_000_000_000:
		return "%.1f млрд" % (float(value) / 1_000_000_000.0)
	if value >= 1_000_000:
		return "%.1f млн" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1f тыс." % (float(value) / 1_000.0)
	return str(value)
