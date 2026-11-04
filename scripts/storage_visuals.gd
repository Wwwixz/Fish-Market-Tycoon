
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const MAX_VISIBLE := 12

var state: Node

var fish_root: Node3D
var fillet_root: Node3D

var fish_items: Array[Node3D] = []
var fillet_items: Array[Node3D] = []

var fish_count: int = -1
var fillet_count: int = -1

var fish_counter: Label3D
var fillet_counter: Label3D

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

	fish_counter = V.label(
		fish_root,
		"0 РЫБ",
		Vector3(0, 2.9, 0),
		34
	)

	fillet_counter = V.label(
		fillet_root,
		"0 ФИЛЕ",
		Vector3(0, 2.9, 0),
		34
	)

	if state != null:
		state.changed.connect(_refresh)
		_refresh()


func _refresh() -> void:
	if state == null:
		return

	var new_fish: int = int(state.fish_box)
	var new_fillets: int = int(state.fillet_box)

	fish_counter.text = "%d РЫБ" % new_fish
	fillet_counter.text = "%d ФИЛЕ" % new_fillets

	if new_fish != fish_count:
		fish_count = new_fish
		_sync_fish(mini(new_fish, MAX_VISIBLE))

	if new_fillets != fillet_count:
		fillet_count = new_fillets
		_sync_fillets(mini(new_fillets, MAX_VISIBLE))


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
	var row: int = (index / 4) % 3

	item.position = Vector3(
		-0.82 + float(col) * 0.54,
		1.42 + float(row) * 0.22,
		-0.38 + float(row % 2) * 0.25
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
		1.43 + float(row) * 0.17,
		-0.1
	)

	item.rotation.y = (
		-0.12 if index % 2 == 0 else 0.12
	)

	V.box(
		item,
		Vector3(0.46, 0.13, 0.34),
		Vector3.ZERO,
		Color("#F1A58A")
	)

	V.box(
		item,
		Vector3(0.38, 0.025, 0.035),
		Vector3(0, 0.08, 0),
		Color("#FFE0C2")
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
	).set_trans(Tween.TRANS_BACK).set_ease(
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


func _process(delta: float) -> void:
	time_passed += delta

	for i in range(fish_items.size()):
		var item: Node3D = fish_items[i]

		if is_instance_valid(item):
			item.rotation.z = (
				sin(time_passed * 1.6 + float(i))
				* 0.025
			)
