
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

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
		node,
		colors[role]
	)
	_decorate_worker(model, role)

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
		"phase": randf() * TAU
	}

	workers.append(worker)

	state.reward.emit(
		1,
		"👷",
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

func _set_route(w: Dictionary, points: Array) -> void:
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
		target.x,
		0.5,
		target.z
	)

	var direction: Vector3 = destination - node.position
	direction.y = 0.0

	if direction.length() <= 0.18:
		node.position = destination
		w["route_index"] = index + 1
		return int(w["route_index"]) >= route.size()

	var dir: Vector3 = direction.normalized()
	var speed: float = state.worker_speed()

	var step: float = minf(
		direction.length(),
		speed * delta
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

	if amount > 0:
		var size_factor: float = (
			1.0 + minf(float(amount - 1) * 0.08, 0.4)
		)
		crate.scale = Vector3.ONE * size_factor
	else:
		crate.scale = Vector3.ONE

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

			if float(w["timer"]) >= FISH_TIME:
				w["rod"].visible = false

				var amount: int = state.carrying_capacity()
				_carry(w, amount)

				state.reward.emit(
					amount,
					"🐟",
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
				var amount: int = mini(
					state.fish_box,
					state.carrying_capacity()
				)

				state.fish_box -= amount
				_carry(w, amount)
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
					state.machine_output,
					state.carrying_capacity()
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
				and state.boat_order > 0
			):
				if state.sell():
					w["step"] = "serving"
					w["timer"] = 0.0

		"serving":
			w["timer"] += delta

			if float(w["timer"]) >= 0.8:
				w["step"] = "waiting"


func _animate(w: Dictionary, delta: float) -> void:
	var model: Dictionary = w["model"]

	var body: Node3D = model["body"]
	var left_arm: Node3D = model["left_arm"]
	var right_arm: Node3D = model["right_arm"]
	var left_leg: Node3D = model["left_leg"]
	var right_leg: Node3D = model["right_leg"]
	var cargo_anchor: Node3D = model["cargo_anchor"]
	var rod: Node3D = w["rod"]

	var role: int = int(w["role"])
	var step_name: String = String(w["step"])

	var phase: float = elapsed * 9.0 + float(w["phase"])
	var blend: float = minf(1.0, delta * 10.0)

	var moving: bool = bool(w["moving"])
	var carrying: bool = int(w["cargo"]) > 0
	var fishing: bool = step_name == "fishing"
	var serving: bool = step_name == "serving"

	var leg_swing: float = 0.0
	var left_target: float = 0.0
	var right_target: float = 0.0
	var bob: float = 0.0
	var body_tilt: float = 0.0

	if moving:
		leg_swing = sin(phase) * 0.52
		bob = absf(sin(phase)) * 0.07

		left_target = -sin(phase) * 0.35
		right_target = sin(phase) * 0.35

		if carrying:
			leg_swing *= 0.75
			bob *= 0.65
			left_target = -0.95
			right_target = -0.95
			body_tilt = -0.05

	elif carrying:
		left_target = -0.95
		right_target = -0.95
		body_tilt = -0.04

	elif fishing:
		left_target = -0.45
		right_target = -0.9 + sin(elapsed * 4.0) * 0.16
		body_tilt = sin(elapsed * 2.0) * 0.035

	elif serving:
		left_target = -0.55 + sin(elapsed * 9.0) * 0.12
		right_target = -0.8 + sin(elapsed * 12.0) * 0.24
		body_tilt = -0.045

	else:
		bob = sin(elapsed * 1.8 + float(w["phase"])) * 0.012

		if role == 3:
			left_target = -0.12
			right_target = -0.12

	left_leg.rotation.x = lerpf(
		left_leg.rotation.x,
		leg_swing,
		blend
	)

	right_leg.rotation.x = lerpf(
		right_leg.rotation.x,
		-leg_swing,
		blend
	)

	left_arm.rotation.x = lerpf(
		left_arm.rotation.x,
		left_target,
		blend
	)

	right_arm.rotation.x = lerpf(
		right_arm.rotation.x,
		right_target,
		blend
	)

	body.position.y = lerpf(
		body.position.y,
		bob,
		blend
	)

	body.rotation.x = lerpf(
		body.rotation.x,
		body_tilt,
		blend
	)

	if carrying:
		cargo_anchor.position.y = (
			0.95 + sin(phase) * 0.018
		)
	else:
		cargo_anchor.position.y = lerpf(
			cargo_anchor.position.y,
			0.95,
			blend
		)

	if fishing:
		rod.rotation.x = lerpf(
			rod.rotation.x,
			-0.5 + sin(elapsed * 4.0) * 0.22,
			blend
		)

		rod.rotation.z = lerpf(
			rod.rotation.z,
			sin(elapsed * 2.5) * 0.08,
			blend
		)
	else:
		rod.rotation.x = lerpf(
			rod.rotation.x,
			-0.5,
			blend
		)

		rod.rotation.z = lerpf(
			rod.rotation.z,
			0.0,
			blend
		)

func _decorate_worker(model: Dictionary, role: int) -> void:
	var body: Node3D = model["body"]

	match role:
		0:
			# Рыбак: широкополая шляпа
			V.cylinder(
				body,
				0.52,
				0.10,
				Vector3(0, 1.78, 0),
				Color("#B49A70")
			)

			V.cylinder(
				body,
				0.32,
				0.28,
				Vector3(0, 1.94, 0),
				Color("#9C815C")
			)

		1:
			# Грузчик рыбы: рабочий фартук
			V.box(
				body,
				Vector3(0.52, 0.65, 0.08),
				Vector3(0, 0.78, -0.33),
				Color("#4D7E91")
			)

			V.box(
				body,
				Vector3(0.40, 0.08, 0.09),
				Vector3(0, 0.62, -0.39),
				Color("#A4C4CA")
			)

		2:
			# Грузчик филе: светлый жилет
			V.box(
				body,
				Vector3(0.57, 0.57, 0.09),
				Vector3(0, 0.93, -0.33),
				Color("#D1C9B6")
			)

			for x in [-0.20, 0.20]:
				V.box(
					body,
					Vector3(0.07, 0.56, 0.11),
					Vector3(x, 0.93, -0.39),
					Color("#9C8D7D")
				)

		3:
			# Продавец: фартук и бейдж
			V.box(
				body,
				Vector3(0.52, 0.67, 0.08),
				Vector3(0, 0.80, -0.33),
				Color("#4B8068")
			)

			V.box(
				body,
				Vector3(0.22, 0.12, 0.05),
				Vector3(0.16, 1.10, -0.39),
				Color("#E1C58B")
			)
