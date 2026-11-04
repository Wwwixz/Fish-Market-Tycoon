extends Node3D

const SPEED := 6.0
const REACH := 3.0
const WORLD_SIZE := 42.0

var player: CharacterBody3D
var camera: Camera3D
var trees: Array[Node3D] = []
var rocks: Array[Node3D] = []
var plots: Array[Node3D] = []
var wood := 0
var stone := 0
var coins := 20
var built := 0
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch := -1
var action_touch := -1
var joystick_knob: ColorRect
var joystick_ring: ColorRect
var resources_label: Label
var prompt_label: Label
var progress_label: Label
var message_label: Label
var action_button: Button
var nearest: Node3D
var current_action := ""
var message_timer := 0.0
var anim_time := 0.0
var follow_target := Vector3.ZERO
var key_action_latched := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 22091
	_create_world()
	_create_player()
	_create_ui()
	_update_ui()

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.position = pos
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	obj.mesh = mesh
	obj.position = pos
	obj.material_override = _material(color)
	parent.add_child(obj)
	return obj

func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> void:
	var obj := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = radius
	mesh.height = height
	obj.mesh = mesh
	obj.position = pos
	obj.material_override = _material(color)
	parent.add_child(obj)

func _create_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ed6fb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.75
	world_env.environment = env
	add_child(world_env)
	_box(self, Vector3(120, 0.4, 120), Vector3(0, -0.48, 0), Color("249dd5"))
	_box(self, Vector3(WORLD_SIZE, 0.7, WORLD_SIZE), Vector3(0, -0.12, 0), Color("70dc79"))
	# Soft paths between the first three construction plots.
	_box(self, Vector3(18, 0.05, 3.1), Vector3(0, 0.27, 0), Color("ce9981"))
	_box(self, Vector3(3.1, 0.05, 13), Vector3(-6, 0.28, 0), Color("ce9981"))
	_create_house(Vector3(-6, 0, -5), true)
	for p in [Vector3(1, 0, -5), Vector3(8, 0, -5), Vector3(-6, 0, 7)]:
		_create_plot(p)
	for x in range(-19, 20, 3):
		for z in range(-19, 20, 3):
			if abs(x) < 15 and abs(z) < 15:
				continue
			if rng.randf() < 0.24:
				_create_tree(Vector3(float(x) + rng.randf_range(-0.5, 0.5), 0, float(z) + rng.randf_range(-0.5, 0.5)))
	for i in range(13):
		var p := Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
		if p.length() > 11:
			_create_rock(p)
	for i in range(3):
		var p := Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-18, 18))
		if p.length() > 17:
			_create_tree(p)

func _create_tree(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Tree"
	root.position = p
	root.set_meta("kind", "tree")
	add_child(root)
	_cylinder(root, 0.21, 1.6, Vector3(0, 0.8, 0), Color("9c6c46"))
	_cone(root, 1.15, 2.3, Vector3(0, 2.0, 0), Color("139e67"))
	_cone(root, 0.88, 1.9, Vector3(0, 3.05, 0), Color("17b879"))
	_cone(root, 0.56, 1.45, Vector3(0, 4.0, 0), Color("1ac889"))
	trees.append(root)

func _create_rock(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Rock"
	root.position = p
	root.set_meta("kind", "rock")
	add_child(root)
	_box(root, Vector3(1.3, 1.1, 1.1), Vector3(0, 0.53, 0), Color("a6b6b8"))
	_box(root, Vector3(0.6, 0.7, 0.7), Vector3(0.65, 0.36, 0.25), Color("c8d1cc"))
	rocks.append(root)

func _create_house(p: Vector3, initial: bool = false) -> void:
	var root := Node3D.new()
	root.name = "Headquarters" if initial else "Workshop"
	root.position = p
	add_child(root)
	_box(root, Vector3(3.4, 2.5, 3.0), Vector3(0, 1.4, 0), Color("d7a270"))
	_box(root, Vector3(3.9, 0.5, 3.5), Vector3(0, 2.9, 0), Color("137d61") if initial else Color("a75b81"))
	_box(root, Vector3(0.85, 1.55, 0.12), Vector3(0, 0.78, 1.56), Color("704c3b"))
	_box(root, Vector3(0.7, 0.7, 0.13), Vector3(-1.05, 1.75, 1.56), Color("a6dcf2"))
	for sx in [-1.6, 1.6]:
		for sz in [-1.35, 1.35]:
			_box(root, Vector3(0.25, 2.8, 0.25), Vector3(sx, 1.4, sz), Color("8d5d3c"))

func _create_plot(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BuildingPlot"
	root.position = p
	root.set_meta("kind", "plot")
	root.set_meta("level", 0)
	add_child(root)
	_box(root, Vector3(3.8, 0.15, 3.8), Vector3(0, 0.18, 0), Color("d4b28c"))
	_box(root, Vector3(3.3, 0.06, 3.3), Vector3(0, 0.28, 0), Color("e9c8a3"))
	plots.append(root)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.65, 3)
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	player.add_child(shape)
	_cylinder(player, 0.38, 0.8, Vector3(0, 0.1, 0), Color("3487df"))
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.37
	sphere.height = 0.74
	head.mesh = sphere
	head.position = Vector3(0, 0.85, 0)
	head.material_override = _material(Color("ffd1a4"))
	player.add_child(head)
	_box(player, Vector3(0.65, 0.18, 0.6), Vector3(0, 1.23, 0), Color("2775bf"))
	# Bright location marker and a name label keep the player easy to find.
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.7
	marker_mesh.bottom_radius = 0.7
	marker_mesh.height = 0.035
	marker.mesh = marker_mesh
	marker.position = Vector3(0, -0.58, 0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color("ffde59")
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_mat
	player.add_child(marker)
	var name_tag := Label3D.new()
	name_tag.text = "ИГРОК"
	name_tag.font_size = 56
	name_tag.pixel_size = 0.007
	name_tag.position = Vector3(0, 2.2, 0)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.modulate = Color("ffffff")
	name_tag.outline_modulate = Color("1b3430")
	player.add_child(name_tag)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 38.0
	camera.rotation_degrees = Vector3(-59, -45, 0)
	camera.current = true
	add_child(camera)
	follow_target = player.position
	camera.position = follow_target + Vector3(20, 34, 20)

func _make_label(parent: Control, txt: String, pos: Vector2, size: Vector2, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = txt
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("172a26"))
	parent.add_child(label)
	return label

func _create_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -520
	top.offset_right = -18
	top.offset_top = 18
	top.offset_bottom = 80
	root.add_child(top)
	resources_label = Label.new()
	resources_label.add_theme_font_size_override("font_size", 22)
	resources_label.add_theme_color_override("font_color", Color("202a25"))
	resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(resources_label)
	var mission := PanelContainer.new()
	mission.offset_left = 18
	mission.offset_top = 18
	mission.offset_right = 305
	mission.offset_bottom = 75
	root.add_child(mission)
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 19)
	progress_label.add_theme_color_override("font_color", Color("244638"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission.add_child(progress_label)
	prompt_label = _make_label(root, "", Vector2.ZERO, Vector2(680, 52), 24)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -340
	prompt_label.offset_right = 340
	prompt_label.offset_top = -138
	prompt_label.offset_bottom = -85
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color("ffffff"))
	prompt_label.add_theme_color_override("font_shadow_color", Color("18332e"))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	message_label = _make_label(root, "", Vector2.ZERO, Vector2(500, 42), 22)
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.offset_left = -250
	message_label.offset_right = 250
	message_label.offset_top = 85
	message_label.offset_bottom = 128
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick_ring = ColorRect.new()
	joystick_ring.color = Color(1, 1, 1, 0.20)
	joystick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_ring.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_ring.anchor_top = 1
	joystick_ring.anchor_bottom = 1
	joystick_ring.offset_left = 35
	joystick_ring.offset_top = -205
	joystick_ring.offset_right = 205
	joystick_ring.offset_bottom = -35
	root.add_child(joystick_ring)
	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(1, 1, 1, 0.65)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_knob.anchor_top = 1
	joystick_knob.anchor_bottom = 1
	joystick_knob.offset_left = 88
	joystick_knob.offset_top = -152
	joystick_knob.offset_right = 152
	joystick_knob.offset_bottom = -88
	root.add_child(joystick_knob)
	action_button = Button.new()
	action_button.text = "СОБРАТЬ"
	action_button.add_theme_font_size_override("font_size", 23)
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.anchor_left = 1
	action_button.anchor_right = 1
	action_button.anchor_top = 1
	action_button.anchor_bottom = 1
	action_button.offset_left = -220
	action_button.offset_right = -30
	action_button.offset_top = -145
	action_button.offset_bottom = -65
	action_button.pressed.connect(_do_action)
	root.add_child(action_button)
	var help := _make_label(root, "WASD / стрелки — ходить   •   E — действие   •   Колесо — масштаб", Vector2.ZERO, Vector2(650, 30), 15)
	help.set_anchors_preset(Control.PRESET_CENTER_TOP)
	help.anchor_left = 0.5
	help.anchor_right = 0.5
	help.offset_left = -325
	help.offset_right = 325
	help.offset_top = 12
	help.offset_bottom = 42
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var viewport_size := get_viewport().get_visible_rect().size
		if e.pressed and e.position.x < viewport_size.x * 0.35 and e.position.y > viewport_size.y * 0.5 and joystick_touch == -1:
			joystick_touch = e.index
			joystick_origin = Vector2(120, viewport_size.y - 120)
			_set_joystick(e.position)
		elif not e.pressed and e.index == joystick_touch:
			joystick_touch = -1
			joystick_vector = Vector2.ZERO
			_move_knob()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == joystick_touch:
			_set_joystick(e.position)
	elif event is InputEventMouseButton and event.pressed:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(12.0, camera.size - 1.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(44.0, camera.size + 1.5)

func _set_joystick(pos: Vector2) -> void:
	joystick_vector = ((pos - joystick_origin) / 70.0).limit_length(1.0)
	_move_knob()

func _move_knob() -> void:
	joystick_knob.offset_left = 88 + joystick_vector.x * 60
	joystick_knob.offset_right = 152 + joystick_vector.x * 60
	joystick_knob.offset_top = -152 + joystick_vector.y * 60
	joystick_knob.offset_bottom = -88 + joystick_vector.y * 60

func _process(delta: float) -> void:
	anim_time += delta
	var input_dir := joystick_vector
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	input_dir = input_dir.limit_length(1)
	# Camera-relative movement on the ground plane.
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0
	forward.y = 0
	right = right.normalized()
	forward = forward.normalized()
	var movement := right * input_dir.x + forward * -input_dir.y
	player.position += movement * SPEED * delta
	player.position.x = clampf(player.position.x, -19.5, 19.5)
	player.position.z = clampf(player.position.z, -19.5, 19.5)
	if movement.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(movement.x, movement.z), delta * 10)
	follow_target = follow_target.lerp(player.position, minf(1, delta * 5))
	camera.position = follow_target + Vector3(20, 34, 20)
	_update_nearest()
	var action_key := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE)
	if action_key and not key_action_latched:
		_do_action()
	key_action_latched = action_key
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.text = ""

func _update_nearest() -> void:
	nearest = null
	var best := REACH
	for item in trees + rocks + plots:
		if not is_instance_valid(item):
			continue
		var dist := player.position.distance_to(item.position + Vector3(0, 0.65, 0))
		if dist < best:
			best = dist
			nearest = item
	if nearest == null:
		current_action = ""
		prompt_label.text = "Подойди к дереву, камню или участку"
		action_button.disabled = true
		return
	var kind: String = nearest.get_meta("kind")
	match kind:
		"tree":
			current_action = "tree"
			prompt_label.text = "Дерево  •  +5 древесины"
			action_button.text = "РУБИТЬ"
		"rock":
			current_action = "rock"
			prompt_label.text = "Камень  •  +3 камня"
			action_button.text = "ДОБЫТЬ"
		"plot":
			current_action = "plot"
			var level: int = nearest.get_meta("level")
			if level == 0:
				prompt_label.text = "Построить мастерскую: 15 дерева + 6 камня"
				action_button.text = "СТРОИТЬ"
			else:
				prompt_label.text = "Улучшить мастерскую: 20 дерева + 10 камня"
				action_button.text = "УЛУЧШИТЬ"
	action_button.disabled = false

func _do_action() -> void:
	if nearest == null or not is_instance_valid(nearest):
		return
	match current_action:
		"tree":
			wood += 5
			trees.erase(nearest)
			nearest.queue_free()
			_show_message("+5 древесины")
		"rock":
			stone += 3
			rocks.erase(nearest)
			nearest.queue_free()
			_show_message("+3 камня")
		"plot":
			var level: int = nearest.get_meta("level")
			var cost_wood := 15 if level == 0 else 20
			var cost_stone := 6 if level == 0 else 10
			if level >= 2:
				_show_message("Максимальный уровень в прототипе")
			elif wood < cost_wood or stone < cost_stone:
				_show_message("Недостаточно ресурсов!")
			else:
				wood -= cost_wood
				stone -= cost_stone
				var position_of_plot := nearest.position
				if level == 0:
					_create_house(position_of_plot)
					built += 1
				else:
					var marker := Node3D.new()
					marker.position = position_of_plot + Vector3(0, 3.5, 0)
					add_child(marker)
					_box(marker, Vector3(3.8, 0.35, 3.5), Vector3.ZERO, Color("e3b55c"))
				nearest.set_meta("level", level + 1)
				_show_message("Здание улучшено!" if level > 0 else "Мастерская построена!")
	_update_ui()
	_update_nearest()

func _update_ui() -> void:
	resources_label.text = "ДЕРЕВО  %d     КАМЕНЬ  %d     МОНЕТЫ  %d" % [wood, stone, coins]
	progress_label.text = "ПОСЕЛЕНИЕ  •  %d / 3 мастерских" % built

func _show_message(msg: String) -> void:
	message_label.text = msg
	message_timer = 2.5
