
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const STEEL := Color("#80999A")
const DARK_STEEL := Color("#354E55")
const LIGHT_STEEL := Color("#B8C9C5")
const WOOD := Color("#997554")

var state: Node
var player: Node3D

var conveyor: Node3D
var cutter: Node3D
var active_fish: Node3D
var fillet_display: Node3D
var register: Node3D
var sale_effects: Node3D

var status_label: Label3D
var sale_label: Label3D
var indicator: MeshInstance3D

var belt_marks: Array[Node3D] = []

var clock: float = 0.0
var sale_count: int = 0
var sale_label_timer: float = 0.0


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	_build_machine()
	_build_register()

	if state != null:
		state.processing_started.connect(_start_processing)
		state.processing_finished.connect(_finish_processing)
		state.sale_completed.connect(_start_sale)
		state.changed.connect(_update_stock)
		_update_stock()

		if state.processing:
			_start_processing()


func _build_machine() -> void:
	conveyor = Node3D.new()
	conveyor.position = S.MACHINE
	add_child(conveyor)

	# Конвейерная лента
	V.box(
		conveyor,
		Vector3(3.65, 0.16, 1.3),
		Vector3(0, 1.94, 0),
		DARK_STEEL
	)

	for x in [-1.55, 1.55]:
		for z in [-0.53, 0.53]:
			V.box(
				conveyor,
				Vector3(0.14, 1.4, 0.14),
				Vector3(x, 1.17, z),
				STEEL
			)

	for z in [-0.71, 0.71]:
		V.box(
			conveyor,
			Vector3(3.9, 0.2, 0.12),
			Vector3(0, 2.06, z),
			LIGHT_STEEL
		)

	for i in range(10):
		var mark := Node3D.new()
		mark.position = Vector3(
			-1.65 + float(i) * 0.36,
			2.035,
			0
		)
		conveyor.add_child(mark)

		V.box(
			mark,
			Vector3(0.045, 0.025, 1.12),
			Vector3.ZERO,
			Color("#71969A")
		)

		belt_marks.append(mark)

	# Опоры режущего механизма
	for x in [-0.35, 0.35]:
		V.box(
			conveyor,
			Vector3(0.14, 1.12, 0.15),
			Vector3(x, 2.6, 0),
			LIGHT_STEEL
		)

	V.box(
		conveyor,
		Vector3(1.0, 0.22, 1.25),
		Vector3(0, 3.12, 0),
		DARK_STEEL
	)

	cutter = Node3D.new()
	cutter.position = Vector3(0, 2.72, 0)
	conveyor.add_child(cutter)

	V.box(
		cutter,
		Vector3(0.14, 0.65, 1.0),
		Vector3.ZERO,
		Color("#D7E1DF")
	)

	V.box(
		cutter,
		Vector3(0.17, 0.1, 1.06),
		Vector3(0, -0.35, 0),
		Color("#A9C5CA")
	)

	# Панель управления
	V.box(
		conveyor,
		Vector3(0.65, 0.6, 0.25),
		Vector3(-1.35, 2.52, -0.78),
		DARK_STEEL
	)

	V.box(
		conveyor,
		Vector3(0.48, 0.28, 0.04),
		Vector3(-1.35, 2.59, -0.93),
		Color("#8BAFA5")
	)

	indicator = V.sphere(
		conveyor,
		0.09,
		Vector3(-1.35, 2.35, -0.96),
		Color("#8AB79B")
	)

	# Выходной лоток
	V.box(
		conveyor,
		Vector3(1.3, 0.14, 1.4),
		Vector3(2.25, 1.91, 0),
		Color("#D2D9D2")
	)

	for z in [-0.67, 0.67]:
		V.box(
			conveyor,
			Vector3(1.4, 0.2, 0.07),
			Vector3(2.25, 2.02, z),
			STEEL
		)

	status_label = V.label(
		conveyor,
		"РАЗДЕЛКА",
		Vector3(0, 3.65, 0),
		30
	)
	status_label.visible = false

	fillet_display = Node3D.new()
	fillet_display.position = (
		S.MACHINE + Vector3(2.25, 1.99, 0)
	)
	add_child(fillet_display)


func _build_register() -> void:
	register = Node3D.new()
	register.position = S.CASH + Vector3(0, 0, 2.2)
	add_child(register)

	V.box(
		register,
		Vector3(2.6, 1.1, 1.5),
		Vector3(0, 0.65, 0),
		WOOD
	)

	for x in [-1.1, 1.1]:
		V.box(
			register,
			Vector3(0.12, 1.0, 0.12),
			Vector3(x, 0.7, -0.72),
			Color("#73563F")
		)

	V.box(
		register,
		Vector3(2.8, 0.16, 1.7),
		Vector3(0, 1.27, 0),
		Color("#D5BC96")
	)

	V.box(
		register,
		Vector3(0.85, 0.5, 0.7),
		Vector3(0.65, 1.62, 0),
		Color("#4B777A")
	)

	V.box(
		register,
		Vector3(0.65, 0.26, 0.05),
		Vector3(0.65, 1.75, -0.37),
		Color("#A5D9BE")
	)

	# Денежный ящик
	V.box(
		register,
		Vector3(0.9, 0.16, 0.6),
		Vector3(-0.5, 1.43, 0),
		DARK_STEEL
	)

	V.box(
		register,
		Vector3(0.3, 0.05, 0.05),
		Vector3(-0.5, 1.45, -0.32),
		LIGHT_STEEL
	)

	sale_label = V.label(
		register,
		"КАССА",
		Vector3(0, 2.65, 0),
		30
	)
	sale_label.visible = false

	sale_effects = Node3D.new()
	add_child(sale_effects)


func _make_fish(parent: Node3D) -> Node3D:
	var fish := Node3D.new()
	parent.add_child(fish)

	var body := V.sphere(
		fish,
		0.32,
		Vector3.ZERO,
		Color("#79B7C4")
	)
	body.scale = Vector3(1.7, 0.65, 0.85)

	var tail := V.box(
		fish,
		Vector3(0.36, 0.42, 0.09),
		Vector3(-0.58, 0, 0),
		Color("#5797A6")
	)
	tail.rotation.z = 0.45

	V.sphere(
		fish,
		0.045,
		Vector3(0.38, 0.09, -0.22),
		Color("#1D3038")
	)

	return fish


func _make_fillet(
	parent: Node3D,
	pos: Vector3
) -> Node3D:
	var item := Node3D.new()
	item.position = pos
	parent.add_child(item)

	V.box(
		item,
		Vector3(0.58, 0.14, 0.32),
		Vector3.ZERO,
		Color("#EBA68D")
	)

	V.box(
		item,
		Vector3(0.5, 0.025, 0.035),
		Vector3(0, 0.085, 0),
		Color("#F4D0B9")
	)

	return item


func _make_coin(
	parent: Node3D,
	pos: Vector3
) -> Node3D:
	var coin := Node3D.new()
	coin.position = pos
	parent.add_child(coin)

	V.cylinder(
		coin,
		0.2,
		0.07,
		Vector3.ZERO,
		Color("#DDB76D")
	)

	return coin


func _start_processing() -> void:
	if not is_instance_valid(conveyor):
		return

	if is_instance_valid(active_fish):
		active_fish.queue_free()

	active_fish = _make_fish(conveyor)
	active_fish.position = Vector3(-1.35, 2.18, 0)

	if is_instance_valid(status_label):
		status_label.text = "ОБРАБОТКА..."


func _finish_processing() -> void:
	if is_instance_valid(active_fish):
		active_fish.queue_free()
		active_fish = null

	cutter.position.y = 2.72
	status_label.text = "ГОТОВО: +3 ФИЛЕ"

	_update_stock()


func _update_stock() -> void:
	if state == null:
		return

	if not is_instance_valid(fillet_display):
		return

	for child in fillet_display.get_children():
		child.queue_free()

	var amount: int = mini(state.machine_output, 9)

	for i in range(amount):
		var column: int = i % 3
		var row: int = i / 3

		_make_fillet(
			fillet_display,
			Vector3(
				(column - 1) * 0.36,
				row * 0.16 + 0.09,
				0
			)
		)


func _start_sale(
	earned: int,
	fillets: int
) -> void:
	sale_count += 1
	sale_label_timer = 2.2

	sale_label.text = "ПРОДАНО: %d" % fillets

	for i in range(mini(fillets, 9)):
		var item := _make_fillet(
			sale_effects,
			S.CASH + Vector3(
				-0.6 + float(i % 3) * 0.35,
				1.55 + float(i / 3) * 0.12,
				2.2
			)
		)

		var tween := create_tween()
		tween.set_parallel(true)

		tween.tween_property(
			item,
			"position",
			S.CASH + Vector3(0, 1.7, -5),
			1.15
		).set_delay(float(i) * 0.1)

		tween.tween_property(
			item,
			"scale",
			Vector3.ZERO,
			1.15
		).set_delay(float(i) * 0.1)

		tween.chain().tween_callback(item.queue_free)

	for i in range(5):
		var coin := _make_coin(
			sale_effects,
			S.CASH + Vector3(
				randf_range(-0.5, 0.5),
				1.6,
				-3.7
			)
		)

		var tween := create_tween()
		tween.set_parallel(true)

		tween.tween_property(
			coin,
			"position",
			S.CASH + Vector3(0.65, 1.75, 2.2),
			0.8
		).set_delay(0.45 + float(i) * 0.12)

		tween.tween_property(
			coin,
			"rotation:y",
			TAU * 2,
			0.8
		).set_delay(0.45 + float(i) * 0.12)

		tween.chain().tween_callback(coin.queue_free)


func _find_player() -> void:
	if is_instance_valid(player):
		return

	var main := get_parent()

	if main != null:
		player = main.get_node_or_null("Player") as Node3D


func _update_labels() -> void:
	_find_player()

	if not is_instance_valid(player):
		status_label.visible = false
		sale_label.visible = false
		return

	var p: Vector3 = player.global_position

	var machine_distance: float = Vector2(
		p.x - S.MACHINE.x,
		p.z - S.MACHINE.z
	).length()

	var cash_distance: float = Vector2(
		p.x - register.global_position.x,
		p.z - register.global_position.z
	).length()

	status_label.visible = (
		state.processing
		and machine_distance <= 5.0
	)

	sale_label.visible = (
		sale_label_timer > 0.0
		and cash_distance <= 5.0
	)


func _process(delta: float) -> void:
	if state == null:
		return

	clock += delta

	if sale_label_timer > 0.0:
		sale_label_timer = maxf(
			0.0,
			sale_label_timer - delta
		)

		if sale_label_timer == 0.0:
			sale_label.text = "КАССА"

	if state.processing:
		var duration: float = maxf(
			state.processing_duration(),
			0.01
		)

		var progress: float = clampf(
			state.process_timer / duration,
			0.0,
			1.0
		)

		if is_instance_valid(active_fish):
			active_fish.position.x = lerpf(
				-1.35,
				0.1,
				progress
			)

			active_fish.rotation.z = (
				sin(clock * 7.0) * 0.04
			)

			if progress > 0.72:
				active_fish.scale.x = maxf(
					0.1,
					1.0 - (progress - 0.72) * 3.0
				)

		if progress > 0.45:
			var cutting_speed: float = (
				12.0 * 3.6 / duration
			)

			cutter.position.y = (
				2.72
				- absf(sin(clock * cutting_speed)) * 0.32
			)
		else:
			cutter.position.y = 2.72

		status_label.text = (
            "РАЗДЕЛКА: %d%%"
			% int(progress * 100.0)
		)

		for i in range(belt_marks.size()):
			var mark: Node3D = belt_marks[i]

			mark.position.x = (
				fposmod(
					-1.65
					+ float(i) * 0.36
					+ clock * 0.8,
					3.6
				)
				- 1.8
			)

	else:
		cutter.position.y = lerpf(
			cutter.position.y,
			2.72,
			minf(1.0, delta * 8.0)
		)

		if state.machine_output == 0:
			status_label.text = "ГОТОВ К РАБОТЕ"

	if is_instance_valid(indicator):
		var color := (
			Color("#E4BA72")
			if state.processing
			else Color("#86B89A")
		)

		indicator.material_override = V.material(color)

	_update_labels()
