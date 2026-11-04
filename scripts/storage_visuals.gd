
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const MAX_VISIBLE := 12
const LABEL_DISTANCE := 5.0

const WOOD := Color("#987657")
const DARK_WOOD := Color("#6E5543")
const METAL := Color("#829C9B")
const DARK_METAL := Color("#405A60")
const ICE := Color("#C5DCD9")

var state: Node
var player: Node3D

var fish_root: Node3D
var fillet_root: Node3D

var fish_items: Array[Node3D] = []
var fillet_items: Array[Node3D] = []

var fish_count: int = -1
var fillet_count: int = -1

var fish_counter: Label3D
var fillet_counter: Label3D

var fish_indicator: MeshInstance3D
var fillet_indicator: MeshInstance3D

var time_passed: float = 0.0


func setup(game_state: Node) -> void:
	state = game_state


func _ready() -> void:
	fish_root = Node3D.new()
	fish_root.name = "FishStorageContents"
	fish_root.position = S.FISH_BOX
	add_child(fish_root)

	fillet_root = Node3D.new()
	fillet_root.name = "FilletStorageContents"
	fillet_root.position = S.FILLET_BOX
	add_child(fillet_root)

	_build_storage(fish_root, true)
	_build_storage(fillet_root, false)

	fish_counter = V.label(
		fish_root,
		"СКЛАД РЫБЫ",
		Vector3(0, 3.0, 0),
		30
	)

	fillet_counter = V.label(
		fillet_root,
		"СКЛАД ФИЛЕ",
		Vector3(0, 3.0, 0),
		30
	)

	fish_counter.visible = false
	fillet_counter.visible = false

	if state != null:
		state.changed.connect(_refresh)
		_refresh()


func _build_storage(
	root: Node3D,
	is_fish: bool
) -> void:
	# Основание стеллажа
	V.box(
		root,
		Vector3(2.8, 0.16, 1.8),
		Vector3(0, 0.62, 0),
		DARK_WOOD
	)

	# Четыре вертикальные опоры
	for x in [-1.2, 1.2]:
		for z in [-0.75, 0.75]:
			V.box(
				root,
				Vector3(0.12, 1.7, 0.12),
				Vector3(x, 1.45, z),
				DARK_METAL
			)

	# Нижняя и верхняя полки
	for y in [0.82, 2.2]:
		V.box(
			root,
			Vector3(2.65, 0.13, 1.65),
			Vector3(0, y, 0),
			WOOD
		)

		V.box(
			root,
			Vector3(2.7, 0.06, 0.08),
			Vector3(0, y + 0.08, -0.8),
			DARK_WOOD
		)

	# Контейнер для продукции
	var container_color := (
		Color("#648B94")
		if is_fish
		else Color("#8A9C87")
	)

	V.box(
		root,
		Vector3(2.35, 0.16, 1.4),
		Vector3(0, 1.0, 0),
		container_color
	)

	for z in [-0.67, 0.67]:
		V.box(
			root,
			Vector3(2.4, 0.38, 0.1),
			Vector3(0, 1.17, z),
			container_color.darkened(0.18)
		)

	for x in [-1.12, 1.12]:
		V.box(
			root,
			Vector3(0.1, 0.38, 1.35),
			Vector3(x, 1.17, 0),
			container_color.darkened(0.18)
		)

	# Лёд под рыбой или подложка под филе
	V.box(
		root,
		Vector3(2.05, 0.05, 1.13),
		Vector3(0, 1.12, 0),
		ICE if is_fish else Color("#D9C7AD")
	)

	# Декоративные ящики на верхней полке
	for x in [-0.7, 0.7]:
		V.box(
			root,
			Vector3(0.9, 0.42, 0.75),
			Vector3(x, 2.48, 0),
			WOOD
		)

		for z in [-0.31, 0.31]:
			V.box(
				root,
				Vector3(0.94, 0.06, 0.07),
				Vector3(x, 2.48, z),
				DARK_WOOD
			)

	# Небольшая табличка на передней стороне
	V.box(
		root,
		Vector3(1.15, 0.35, 0.08),
		Vector3(0, 1.75, -0.83),
		DARK_METAL
	)

	var title := V.label(
		root,
		"РЫБА" if is_fish else "ФИЛЕ",
		Vector3(0, 1.76, -0.9),
		24
	)

	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.rotation.y = PI
	title.pixel_size = 0.004
	title.no_depth_test = false

	# Индикатор заполнения
	V.box(
		root,
		Vector3(1.5, 0.11, 0.08),
		Vector3(0, 0.75, -0.94),
		DARK_METAL
	)

	var indicator := V.box(
		root,
		Vector3(1.42, 0.065, 0.09),
		Vector3(0, 0.75, -1.0),
		Color("#81B8A2")
	)

	if is_fish:
		fish_indicator = indicator
	else:
		fillet_indicator = indicator


func _refresh() -> void:
	if state == null:
		return

	var new_fish: int = int(state.fish_box)
	var new_fillets: int = int(state.fillet_box)

	fish_counter.text = "РЫБА: %d" % new_fish
	fillet_counter.text = "ФИЛЕ: %d" % new_fillets

	if new_fish != fish_count:
		fish_count = new_fish
		_sync_fish(mini(new_fish, MAX_VISIBLE))
		_update_indicator(fish_indicator, new_fish)

	if new_fillets != fillet_count:
		fillet_count = new_fillets
		_sync_fillets(mini(new_fillets, MAX_VISIBLE))
		_update_indicator(fillet_indicator, new_fillets)


func _update_indicator(
	indicator: MeshInstance3D,
	amount: int
) -> void:
	if not is_instance_valid(indicator):
		return

	# Индикатор показывает первые 100 единиц запаса.
	var progress: float = clampf(
		float(amount) / 100.0,
		0.0,
		1.0
	)

	indicator.scale.x = maxf(progress, 0.01)

	indicator.position.x = (
		-0.71 + 0.71 * progress
	)

	var color := Color("#C98B76")

	if progress >= 0.65:
		color = Color("#83B8A1")
	elif progress >= 0.25:
		color = Color("#D4B67B")

	indicator.material_override = V.material(color)


func _sync_fish(target: int) -> void:
	while fish_items.size() > target:
		var item: Node3D = fish_items.pop_back()
		_remove_item(item)

	while fish_items.size() < target:
		var index: int = fish_items.size()
		var item := _create_fish(fish_root, index)

		fish_items.append(item)
		_appear_item(item)


func _sync_fillets(target: int) -> void:
	while fillet_items.size() > target:
		var item: Node3D = fillet_items.pop_back()
		_remove_item(item)

	while fillet_items.size() < target:
		var index: int = fillet_items.size()
		var item := _create_fillet(fillet_root, index)

		fillet_items.append(item)
		_appear_item(item)


func _create_fish(
	parent: Node3D,
	index: int
) -> Node3D:
	var item := Node3D.new()
	item.name = "Fish_%d" % index
	parent.add_child(item)

	var col: int = index % 4
	var row: int = index / 4

	item.position = Vector3(
		-0.82 + float(col) * 0.54,
		1.32 + float(row) * 0.16,
		-0.28 + float(row % 2) * 0.24
	)

	item.rotation.y = (
		0.18 if index % 2 == 0 else -0.18
	)

	var colors := [
		Color("#8ACBD6"),
		Color("#72B5C7"),
		Color("#A0CFBF"),
		Color("#D0B58B")
	]

	var color: Color = colors[index % colors.size()]

	var body := V.sphere(
		item,
		0.23,
		Vector3.ZERO,
		color
	)
	body.scale = Vector3(1.6, 0.72, 0.85)

	var tail := V.box(
		item,
		Vector3(0.25, 0.3, 0.08),
		Vector3(-0.39, 0, 0),
		color.darkened(0.16)
	)
	tail.rotation.z = 0.55

	var fin := V.box(
		item,
		Vector3(0.18, 0.17, 0.06),
		Vector3(0, 0.17, 0),
		color.darkened(0.2)
	)
	fin.rotation.z = 0.3

	V.sphere(
		item,
		0.035,
		Vector3(0.26, 0.05, -0.14),
		Color("#263C42")
	)

	return item


func _create_fillet(
	parent: Node3D,
	index: int
) -> Node3D:
	var item := Node3D.new()
	item.name = "Fillet_%d" % index
	parent.add_child(item)

	var col: int = index % 4
	var row: int = index / 4

	item.position = Vector3(
		-0.78 + float(col) * 0.52,
		1.32 + float(row) * 0.16,
		-0.1
	)

	item.rotation.y = (
		-0.12 if index % 2 == 0 else 0.12
	)

	V.box(
		item,
		Vector3(0.46, 0.13, 0.34),
		Vector3.ZERO,
		Color("#EBA68D")
	)

	V.box(
		item,
		Vector3(0.38, 0.025, 0.035),
		Vector3(0, 0.08, 0),
		Color("#F4D0B9")
	)

	V.box(
		item,
		Vector3(0.31, 0.025, 0.035),
		Vector3(0, 0.081, 0.1),
		Color("#F9C8AC")
	)

	return item


func _appear_item(item: Node3D) -> void:
	item.scale = Vector3.ZERO

	var tween := create_tween()

	tween.tween_property(
		item,
		"scale",
		Vector3.ONE,
		0.25
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)


func _remove_item(item: Node3D) -> void:
	if not is_instance_valid(item):
		return

	var tween := create_tween()

	tween.tween_property(
		item,
		"scale",
		Vector3.ZERO,
		0.15
	)

	tween.tween_callback(item.queue_free)


func _find_player() -> void:
	if is_instance_valid(player):
		return

	var main := get_parent()

	if main != null:
		player = main.get_node_or_null("Player") as Node3D


func _process(delta: float) -> void:
	time_passed += delta

	_find_player()

	if is_instance_valid(player):
		var p: Vector3 = player.global_position

		fish_counter.visible = (
			Vector2(
				p.x - S.FISH_BOX.x,
				p.z - S.FISH_BOX.z
			).length() <= LABEL_DISTANCE
		)

		fillet_counter.visible = (
			Vector2(
				p.x - S.FILLET_BOX.x,
				p.z - S.FILLET_BOX.z
			).length() <= LABEL_DISTANCE
		)

	for i in range(fish_items.size()):
		var item: Node3D = fish_items[i]

		if is_instance_valid(item):
			item.rotation.z = (
				sin(time_passed * 1.6 + float(i))
				* 0.025
			)
