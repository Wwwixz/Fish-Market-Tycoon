
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const WAIT_LIMIT := 40.0
const PLAYER_SERVICE_DISTANCE := 2.4
const LABEL_DISTANCE := 4.5

var state: Node
var player: Node3D

var customers: Array[Dictionary] = []
var spawn_timer: float = 3.0
var service_timer: float = 0.0
var clock: float = 0.0
var next_id: int = 0
var current_served_id: int = -1

var colors := [
	Color("#5A91BB"),
	Color("#B88A63"),
	Color("#8B77B2"),
	Color("#6CA78B"),
	Color("#C27D86"),
	Color("#D0B46C"),
	Color("#648F98"),
	Color("#A98577")
]


func setup(game_state: Node, game_player: Node3D) -> void:
	state = game_state
	player = game_player


func _process(delta: float) -> void:
	if state == null:
		return

	clock += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_timer = state.customer_spawn_interval()

		if _active_count() < state.market_capacity():
			_spawn_customer()

	_update_queue()

	for customer in customers:
		_update_customer(customer, delta)

	_serve_queue(delta)
	_cleanup_customers()
	_update_queue_count()


func _active_count() -> int:
	var count: int = 0

	for c in customers:
		if String(c["status"]) != "leaving":
			count += 1

	return count


func _spawn_customer() -> void:
	next_id += 1

	var node := Node3D.new()
	node.name = "Customer_%d" % next_id
	node.position = S.MARKET_ENTRANCE + Vector3(
		randf_range(-0.5, 0.5),
		0.5,
		0
	)
	add_child(node)

	var color: Color = colors[
		randi() % colors.size()
	]

	var model: Dictionary = V.animated_person(
		node,
		color
	)

	_decorate_customer(node, next_id)

	var amount: int = randi_range(1, 3)

	var order_label := V.label(
		node,
		"ХОЧУ %d ФИЛЕ" % amount,
		Vector3(0, 2.45, 0),
		27
	)
	order_label.visible = false

	customers.append({
		"id": next_id,
		"node": node,
		"model": model,
		"label": order_label,
		"amount": amount,
		"status": "arriving",
		"wait": 0.0,
		"queue_index": -1,
		"phase": randf() * TAU,
		"moving": false,
		"done": false,
		"accessory": next_id % 4
	})


func _decorate_customer(
	node: Node3D,
	id: int
) -> void:
	var style: int = id % 4

	match style:
		0:
			_make_cap(node)
		1:
			_make_bag(node)
		2:
			_make_hat(node)
		3:
			_make_backpack(node)


func _make_cap(node: Node3D) -> void:
	V.cylinder(
		node,
		0.3,
		0.16,
		Vector3(0, 1.96, 0),
		Color("#526E86")
	)

	V.box(
		node,
		Vector3(0.48, 0.06, 0.2),
		Vector3(0, 1.93, -0.23),
		Color("#40596F")
	)


func _make_bag(node: Node3D) -> void:
	V.box(
		node,
		Vector3(0.35, 0.45, 0.2),
		Vector3(-0.48, 0.82, 0),
		Color("#B99B73")
	)

	V.box(
		node,
		Vector3(0.06, 0.38, 0.06),
		Vector3(-0.48, 1.17, 0),
		Color("#81674E")
	)


func _make_hat(node: Node3D) -> void:
	V.cylinder(
		node,
		0.35,
		0.22,
		Vector3(0, 2.02, 0),
		Color("#B9A17C")
	)

	V.cylinder(
		node,
		0.48,
		0.055,
		Vector3(0, 1.94, 0),
		Color("#927A5D")
	)


func _make_backpack(node: Node3D) -> void:
	V.box(
		node,
		Vector3(0.5, 0.68, 0.27),
		Vector3(0, 1.02, 0.32),
		Color("#607C76")
	)

	for x in [-0.2, 0.2]:
		V.box(
			node,
			Vector3(0.07, 0.65, 0.08),
			Vector3(x, 1.06, 0.17),
			Color("#455D58")
		)


func _queue_position(index: int) -> Vector3:
	return S.MARKET + Vector3(
		0,
		0.5,
		2.0 + float(index) * 1.25
	)


func _update_queue() -> void:
	var index: int = 0

	for c in customers:
		if String(c["status"]) == "leaving":
			c["queue_index"] = -1
			continue

		c["queue_index"] = index
		index += 1


func _update_customer(
	c: Dictionary,
	delta: float
) -> void:
	c["moving"] = false

	if String(c["status"]) == "leaving":
		var exit_position: Vector3 = (
			S.MARKET_ENTRANCE + Vector3(0, 0.5, 0)
		)

		if _move_to(c, exit_position, delta):
			c["done"] = true

		_animate(c, delta)
		_update_label_visibility(c)
		return

	var queue_index: int = int(c["queue_index"])
	var target: Vector3 = _queue_position(queue_index)

	if _move_to(c, target, delta):
		c["status"] = "waiting"
		c["wait"] = float(c["wait"]) + delta

		if float(c["wait"]) >= WAIT_LIMIT:
			c["status"] = "leaving"
			var label: Label3D = c["label"]
			label.text = "СЛИШКОМ ДОЛГО!"
			state.customers_lost += 1
			state.changed.emit()
	else:
		c["status"] = "arriving"

	_animate(c, delta)
	_update_label_visibility(c)


func _update_label_visibility(c: Dictionary) -> void:
	var label: Label3D = c["label"]
	var node: Node3D = c["node"]

	if not is_instance_valid(player):
		label.visible = false
		return

	var a := Vector2(
		player.global_position.x,
		player.global_position.z
	)

	var b := Vector2(
		node.global_position.x,
		node.global_position.z
	)

	var nearby: bool = (
		a.distance_to(b) <= LABEL_DISTANCE
	)

	var status: String = String(c["status"])
	var important: bool = (
		status == "waiting"
		and int(c["queue_index"]) == 0
	)

	label.visible = nearby and (
		important or status == "leaving"
	)


func _move_to(
	c: Dictionary,
	target: Vector3,
	delta: float
) -> bool:
	var node: Node3D = c["node"]
	var direction: Vector3 = target - node.position
	direction.y = 0.0

	if direction.length() < 0.12:
		return true

	var dir: Vector3 = direction.normalized()
	var speed: float = 2.3

	node.position += dir * minf(
		speed * delta,
		direction.length()
	)

	node.rotation.y = lerp_angle(
		node.rotation.y,
		atan2(-dir.x, -dir.z),
		minf(1.0, delta * 9.0)
	)

	c["moving"] = true
	return false


func _animate(c: Dictionary, delta: float) -> void:
	var model: Dictionary = c["model"]

	var body: Node3D = model["body"]
	var left_leg: Node3D = model["left_leg"]
	var right_leg: Node3D = model["right_leg"]
	var left_arm: Node3D = model["left_arm"]
	var right_arm: Node3D = model["right_arm"]

	var phase: float = (
		clock * 9.0 + float(c["phase"])
	)

	var swing: float = 0.0
	var bob: float = 0.0

	if bool(c["moving"]):
		swing = sin(phase) * 0.5
		bob = absf(sin(phase)) * 0.06
	else:
		# Небольшие движения во время ожидания
		var idle_phase: float = (
			clock * 1.5 + float(c["phase"])
		)

		swing = sin(idle_phase) * 0.035
		bob = sin(idle_phase) * 0.012

	var blend: float = minf(1.0, delta * 12.0)

	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		swing,
		blend
	)

	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		-swing,
		blend
	)

	left_arm.rotation.x = lerpf(
		left_arm.rotation.x,
		-swing * 0.7,
		blend
	)

	right_arm.rotation.x = lerpf(
		right_arm.rotation.x,
		swing * 0.7,
		blend
	)

	body.position.y = lerpf(
		body.position.y,
		bob,
		blend
	)


func _serve_queue(delta: float) -> void:
	var first: Dictionary = {}

	for c in customers:
		if (
			int(c["queue_index"]) == 0
			and String(c["status"]) == "waiting"
		):
			first = c
			break

	if first.is_empty():
		service_timer = 0.0
		current_served_id = -1
		return

	var id: int = int(first["id"])

	if id != current_served_id:
		current_served_id = id
		service_timer = 0.0

	var automatic: bool = state.hired[3] > 0
	var manual: bool = false

	if is_instance_valid(player):
		var a := Vector2(
			player.global_position.x,
			player.global_position.z
		)

		var b := Vector2(
			S.MARKET.x,
			S.MARKET.z
		)

		manual = (
			a.distance_to(b)
			<= PLAYER_SERVICE_DISTANCE
		)

	var label: Label3D = first["label"]

	if not automatic and not manual:
		label.text = "НУЖЕН ПРОДАВЕЦ"
		service_timer = 0.0
		return

	var amount: int = int(first["amount"])

	if state.fillet_box < amount:
		label.text = "ЖДУ ФИЛЕ: %d" % amount
		service_timer = 0.0
		return

	label.text = "ОБСЛУЖИВАНИЕ..."
	service_timer += delta

	var duration: float = (
		state.customer_service_duration()
	)

	if automatic:
		duration = maxf(
			0.35,
			duration / float(state.hired[3])
		)

	if service_timer < duration:
		return

	service_timer = 0.0

	if state.sell_to_customer(amount):
		first["status"] = "leaving"
		label.text = "СПАСИБО!"
		current_served_id = -1


func _cleanup_customers() -> void:
	for i in range(
		customers.size() - 1,
		-1,
		-1
	):
		var c: Dictionary = customers[i]

		if bool(c["done"]):
			var node: Node3D = c["node"]
			node.queue_free()
			customers.remove_at(i)


func _update_queue_count() -> void:
	var count: int = _active_count()

	if state.market_queue != count:
		state.market_queue = count
		state.changed.emit()
