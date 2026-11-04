
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

const WALK_SPEED := 3.5
const FISH_TIME := 3.0

var state: Node
var workers: Array[Dictionary] = []
var elapsed: float = 0.0

func setup(game_state: Node) -> void:
	state = game_state

func hire(role: int) -> void:
	if not state.hire(role):
		state.notice.emit("Недостаточно монет!")
		return

	var colors := [
		Color("#428DB6"),
		Color("#D19A60"),
		Color("#9A84B9"),
		Color("#63A881")
	]

	var names := [
		"РЫБАК",
		"ГРУЗЧИК РЫБЫ",
		"ГРУЗЧИК ФИЛЕ",
        "ПРОДАВЕЦ"
	]

	var starts := [
		S.FISHING,
		S.FISH_BOX,
		S.MACHINE,
		S.CASH
	]

	var node := Node3D.new()
	node.position = starts[role] + Vector3(0, 0.5, 0)
	add_child(node)

	var model: Dictionary = V.animated_person(
		node, colors[role]
	)

	V.label(
		node,
		names[role],
		Vector3(0, 2.55, 0),
		30
	)

	var rod := Node3D.new()
	rod.name = "FishingRod"
	model["right_arm"].add_child(rod)

	V.cylinder(
		rod,
		0.035,
		2.0,
		Vector3(0, -0.65, -0.45),
		Color("#79553E")
	)

	rod.rotation.x = -0.5
	rod.visible = false

	var worker := {
		"node": node,
		"role": role,
		"step": "idle",
		"timer": 0.0,
		"cargo": 0,
		"model": model,
		"rod": rod,
		"moving": false,
		"route": [],
		"route_index": 0,
		"phase": randf() * TAU,
		"action": 0.0
	}

	workers.append(worker)

	state.reward.emit(
		1, "👷",
		Color("#F2D58D"),
		node.global_position
	)

func _process(delta: float) -> void:
	if state == null:
		return

	elapsed += delta

	for w in workers:
		w["moving"] = false
		_tick(w, delta)
		_animate(w, delta)

func _tick(w: Dictionary, delta: float) -> void:
	match int(w["role"]):
		0:
			_fisher(w, delta)
		1:
			_fish_carrier(w, delta)
		2:
			_fillet_carrier(w, delta)
		3:
			_seller(w, delta)

func _set_route(
	w: Dictionary,
	points: Array
) -> void:
	w["route"] = points
	w["route_index"] = 0

func _travel(w: Dictionary, delta: float) -> bool:
	var route: Array = w["route"]
	var index: int = w["route_index"]

	if index >= route.size():
		return true

	var node: Node3D = w["node"]
	var target: Vector3 = route[index]
	var destination := Vector3(
		target.x, 0.5, target.z
	)

	var direction: Vector3 = destination - node.position
	direction.y = 0.0

	if direction.length() <= 0.18:
		node.position = destination
		w["route_index"] = index + 1
		return w["route_index"] >= route.size()

	var dir := direction.normalized()
	var step := minf(
		direction.length(),
		WALK_SPEED * delta
	)

	node.position += dir * step
	node.rotation.y = lerp_angle(
		node.rotation.y,
		atan2(-dir.x, -dir.z),
		minf(1.0, delta * 9.0)
	)

	w["moving"] = true
	return false

func _carry(w: Dictionary, amount: int) -> void:
	w["cargo"] = amount
	var model: Dictionary = w["model"]
	var crate: Node3D = model["crate"]
	crate.visible = amount > 0
	w["action"] = 0.35

func _fisher(w: Dictionary, delta: float) -> void:
	match String(w["step"]):
		"idle":
			_set_route(w, [S.FISHING])
			w["step"] = "to_water"

		"to_water":
			if _travel(w, delta):
				w["step"] = "fishing"
				w["timer"] = 0.0
				w["rod"].visible = true

		"fishing":
			w["timer"] += delta

			if w["timer"] >= FISH_TIME:
				w["rod"].visible = false
				_carry(w, 1)

				state.reward.emit(
					1, "🐟",
					Color("#83D8EF"),
					w["node"].global_position
				)

				_set_route(w, [
					Vector3(-8, 0, -5),
					S.FISH_BOX
				])
				w["step"] = "to_box"

		"to_box":
			if _travel(w, delta):
				state.fish_box += int(w["cargo"])
				_carry(w, 0)
				state.changed.emit()

				_set_route(w, [
					Vector3(-8, 0, -5),
					S.FISHING
				])
				w["step"] = "to_water"

func _fish_carrier(
	w: Dictionary,
	delta: float
) -> void:
	match String(w["step"]):
		"idle":
			_set_route(w, [S.FISH_BOX])
			w["step"] = "to_box"

		"to_box":
			if _travel(w, delta) and state.fish_box > 0:
				state.fish_box -= 1
				_carry(w, 1)
				state.changed.emit()

				_set_route(w, [
					Vector3(-5, 0, 0),
					Vector3(0, 0, 0),
					Vector3(3, 0, 0),
					S.MACHINE
				])
				w["step"] = "to_machine"

		"to_machine":
			if _travel(w, delta):
				state.machine_input += int(w["cargo"])
				_carry(w, 0)
				state.changed.emit()

				_set_route(w, [
					Vector3(3, 0, 0),
					Vector3(0, 0, 0),
					Vector3(-5, 0, 0),
					S.FISH_BOX
				])
				w["step"] = "to_box"

func _fillet_carrier(
	w: Dictionary,
	delta: float
) -> void:
	match String(w["step"]):
		"idle":
			_set_route(w, [S.MACHINE])
			w["step"] = "to_machine"

		"to_machine":
			if _travel(w, delta) and state.machine_output > 0:
				var amount: int = mini(
					state.machine_output, 3
				)

				state.machine_output -= amount
				_carry(w, amount)
				state.changed.emit()

				_set_route(w, [
					Vector3(9, 0, 3),
					S.FILLET_BOX
				])
				w["step"] = "to_box"

		"to_box":
			if _travel(w, delta):
				state.fillet_box += int(w["cargo"])
				_carry(w, 0)
				state.changed.emit()

				_set_route(w, [
					Vector3(9, 0, 3),
					S.MACHINE
				])
				w["step"] = "to_machine"

func _seller(w: Dictionary, delta: float) -> void:
	match String(w["step"]):
		"idle":
			_set_route(w, [S.CASH])
			w["step"] = "to_cash"

		"to_cash":
			if _travel(w, delta):
				w["step"] = "waiting"

		"waiting":
			if (
				state.boat_state == "ordering"
				and state.fillet_box >= state.boat_order
			):
				if state.sell():
					w["step"] = "serving"
					w["timer"] = 0.0
					w["action"] = 0.8

		"serving":
			w["timer"] += delta

			if w["timer"] >= 0.8:
				w["step"] = "waiting"

func _animate(w: Dictionary, delta: float) -> void:
	var model: Dictionary = w["model"]

	var body: Node3D = model["body"]
	var left_arm: Node3D = model["left_arm"]
	var right_arm: Node3D = model["right_arm"]
	var left_leg: Node3D = model["left_leg"]
	var right_leg: Node3D = model["right_leg"]
	var cargo_anchor: Node3D = model["cargo_anchor"]

	var phase: float = elapsed * 10.0 + float(w["phase"])
	var moving: bool = w["moving"]
	var carrying: bool = int(w["cargo"]) > 0
	var fishing: bool = String(w["step"]) == "fishing"
	var serving: bool = String(w["step"]) == "serving"

	var target_leg := 0.0
	var target_arm := 0.0
	var target_bob := 0.0

	if moving:
		target_leg = sin(phase) * 0.55
		target_arm = sin(phase) * 0.42
		target_bob = absf(sin(phase)) * 0.08

	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		target_leg,
		minf(1.0, delta * 12.0)
	)

	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		-target_leg,
		minf(1.0, delta * 12.0)
	)

	body.position.y = lerpf(
		body.position.y,
		target_bob,
		minf(1.0, delta * 10.0)
	)

	if carrying:
		left_arm.rotation.x = lerpf(
			left_arm.rotation.x,
			-0.95,
			minf(1.0, delta * 12.0)
		)

		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			-0.95,
			minf(1.0, delta * 12.0)
		)

		cargo_anchor.position.y = (
			0.95 + sin(phase) * 0.025
		)

	elif fishing:
		left_arm.rotation.x = -0.35
		right_arm.rotation.x = (
			-0.85 + sin(elapsed * 5.0) * 0.22
		)

		var rod: Node3D = w["rod"]
		rod.rotation.x = (
			-0.5 + sin(elapsed * 5.0) * 0.15
		)

	elif serving:
		left_arm.rotation.x = -0.65
		right_arm.rotation.x = (
			-0.7 + sin(elapsed * 14.0) * 0.25
		)

	else:
		left_arm.rotation.x = lerpf(
			left_arm.rotation.x,
			-target_arm,
			minf(1.0, delta * 10.0)
		)

		right_arm.rotation.x = lerpf(
			right_arm.rotation.x,
			target_arm,
			minf(1.0, delta * 10.0)
		)

	w["action"] = maxf(
		0.0,
		float(w["action"]) - delta
	)
