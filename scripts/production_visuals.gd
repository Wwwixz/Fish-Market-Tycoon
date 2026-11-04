
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

var state: Node

var active_fish: Node3D
var cutter: Node3D
var conveyor: Node3D
var fillet_display: Node3D
var register: Node3D
var sale_effects: Node3D

var status_label: Label3D
var sale_label: Label3D

var time_passed: float = 0.0
var sale_count: int = 0

func setup(game_state: Node) -> void:
	state = game_state

func _ready() -> void:
	_build_processing_machine()
	_build_cash_register()

	state.processing_started.connect(_start_processing)
	state.processing_finished.connect(_finish_processing)
	state.sale_completed.connect(_start_sale)
	state.changed.connect(_update_stock_visuals)

	_update_stock_visuals()

func _build_processing_machine() -> void:
	conveyor = Node3D.new()
	conveyor.position = S.MACHINE
	add_child(conveyor)

	# Конвейер поверх существующего станка
	V.box(
		conveyor,
		Vector3(3.6, 0.14, 1.25),
		Vector3(0, 1.94, 0),
		Color("#344F55")
	)

	for i in range(9):
		V.box(
			conveyor,
			Vector3(0.045, 0.02, 1.12),
			Vector3(-1.55 + i * 0.38, 2.025, 0),
			Color("#709397")
		)

	for z in [-0.7, 0.7]:
		V.box(
			conveyor,
			Vector3(3.8, 0.18, 0.12),
			Vector3(0, 2.06, z),
			Color("#A7C1BC")
		)

	# Рама ножа
	for x in [-0.28, 0.28]:
		V.box(
			conveyor,
			Vector3(0.14, 1.1, 0.15),
			Vector3(x, 2.58, 0),
			Color("#D3D9D1")
		)

	V.box(
		conveyor,
		Vector3(0.9, 0.16, 0.3),
		Vector3(0, 3.14, 0),
		Color("#789B9B")
	)

	cutter = Node3D.new()
	cutter.position = Vector3(0, 2.72, 0)
	conveyor.add_child(cutter)

	V.box(
		cutter,
		Vector3(0.14, 0.65, 1.0),
		Vector3.ZERO,
		Color("#E5ECE7")
	)

	V.box(
		cutter,
		Vector3(0.17, 0.1, 1.06),
		Vector3(0, -0.35, 0),
		Color("#A9C5CA")
	)

	# Выходной лоток
	V.box(
		conveyor,
		Vector3(1.3, 0.14, 1.4),
		Vector3(2.25, 1.91, 0),
		Color("#D2D9D2")
	)

	status_label = V.label(
		conveyor,
		"ГОТОВ К РАБОТЕ",
		Vector3(0, 3.65, 0),
		32
	)

	fillet_display = Node3D.new()
	fillet_display.position = (
		S.MACHINE + Vector3(2.25, 1.99, 0)
	)
	add_child(fillet_display)

func _build_cash_register() -> void:
	register = Node3D.new()
	register.position = S.CASH + Vector3(0, 0, 2.2)
	add_child(register)

	V.box(
		register,
		Vector3(2.6, 1.1, 1.5),
		Vector3(0, 0.65, 0),
		Color("#987452")
	)

	V.box(
		register,
		Vector3(2.8, 0.16, 1.7),
		Vector3(0, 1.27, 0),
		Color("#E0C59D")
	)

	# Кассовый аппарат
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

	V.box(
		register,
		Vector3(0.95, 0.13, 0.8),
		Vector3(0.65, 1.38, 0),
		Color("#344F55")
	)

	sale_label = V.label(
		register,
		"КАССА",
		Vector3(0, 2.65, 0),
		35
	)

	sale_effects = Node3D.new()
	add_child(sale_effects)

func _make_fish(
	parent: Node3D,
	fish_color: Color
) -> Node3D:
	var fish := Node3D.new()
	parent.add_child(fish)

	var body := V.sphere(
		fish,
		0.32,
		Vector3.ZERO,
		fish_color
	)
	body.scale = Vector3(1.7, 0.65, 0.85)

	var tail := V.box(
		fish,
		Vector3(0.36, 0.42, 0.09),
		Vector3(-0.58, 0, 0),
		fish_color.darkened(0.12)
	)
	tail.rotation.z = 0.45

	V.sphere(
		fish,
		0.045,
		Vector3(0.38, 0.09, -0.22),
		Color("#1D3038")
	)

	var fin := V.box(
		fish,
		Vector3(0.28, 0.22, 0.08),
		Vector3(0, 0.24, 0),
		fish_color.darkened(0.15)
	)
	fin.rotation.z = 0.35

	return fish

func _make_fillet(
	parent: Node3D,
	pos: Vector3
) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	var fillet := V.box(
		root,
		Vector3(0.58, 0.14, 0.32),
		Vector3.ZERO,
		Color("#F4A98A")
	)
	fillet.rotation.y = 0.12

	V.box(
		root,
		Vector3(0.5, 0.025, 0.035),
		Vector3(0, 0.085, 0),
		Color("#F9D3B7")
	)

	return root

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
		Color("#F5C65C")
	)

	V.cylinder(
		coin,
		0.12,
		0.075,
		Vector3(0, 0.005, 0),
		Color("#E4A93F")
	)

	return coin

func _start_processing() -> void:
	if is_instance_valid(active_fish):
		active_fish.queue_free()

	active_fish = _make_fish(
		conveyor,
		Color("#79B7C4")
	)

	active_fish.position = Vector3(
		-1.35, 2.18, 0
	)

	status_label.text = "ОБРАБОТКА РЫБЫ..."

func _finish_processing() -> void:
	if is_instance_valid(active_fish):
		active_fish.queue_free()
		active_fish = null

	cutter.position.y = 2.72
	status_label.text = "ГОТОВО: +3 ФИЛЕ"

	_update_stock_visuals()

func _update_stock_visuals() -> void:
	if not is_instance_valid(fillet_display):
		return

	for child in fillet_display.get_children():
		child.queue_free()

	# Показываем до девяти готовых филе
	var amount: int = mini(
		state.machine_output,
		9
	)

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
	sale_label.text = (
		"ПРОДАНО: %d ФИЛЕ" % fillets
	)

	# Филе движется от прилавка к покупателю
	for i in range(mini(fillets, 9)):
		var item := _make_fillet(
			sale_effects,
			S.CASH + Vector3(
				-0.6 + float(i % 3) * 0.35,
				1.55 + float(i / 3) * 0.12,
				2.2
			)
		)

		var destination := (
			S.CASH
			+ Vector3(
				0,
				1.7,
				-5.0
			)
		)

		var tween := create_tween()
		tween.set_parallel(true)

		tween.tween_property(
			item,
			"position",
			destination,
			1.15
		).set_delay(float(i) * 0.1)

		tween.tween_property(
			item,
			"scale",
			Vector3(0.2, 0.2, 0.2),
			1.15
		).set_delay(float(i) * 0.1)

		tween.chain().tween_callback(
			item.queue_free
		)

	# Монеты летят обратно к кассе
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
			S.CASH + Vector3(
				0.65,
				1.75,
				2.2
			),
			0.8
		).set_delay(
			0.45 + float(i) * 0.12
		)

		tween.tween_property(
			coin,
			"rotation:y",
			TAU * 2,
			0.8
		).set_delay(
			0.45 + float(i) * 0.12
		)

		tween.chain().tween_callback(
			coin.queue_free
		)

	var sale_id := sale_count
	get_tree().create_timer(2.2).timeout.connect(
		func() -> void:
			if sale_id == sale_count:
				sale_label.text = "КАССА"
	)

func _process(_delta: float) -> void:
	if state == null:
		return

	time_passed += _delta

	if state.processing:
		var progress: float = clampf(
			state.process_timer / 3.6,
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
				sin(time_passed * 7.0) * 0.04
			)

			if progress > 0.72:
				active_fish.scale = Vector3(
					1.0 - (progress - 0.72) * 3.0,
					1.0,
					1.0
				)

		if progress > 0.45:
			cutter.position.y = (
				2.72
				- absf(sin(time_passed * 12.0)) * 0.32
			)
		else:
			cutter.position.y = 2.72

		status_label.text = (
            "РАЗДЕЛКА: %d%%"
			% int(progress * 100.0)
		)

	else:
		cutter.position.y = lerpf(
			cutter.position.y,
			2.72,
			minf(1.0, _delta * 8.0)
		)

		if state.machine_output == 0:
			status_label.text = "ГОТОВ К РАБОТЕ"
