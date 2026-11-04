
extends Node3D

const V = preload("res://scripts/visuals.gd")
const S = preload("res://scripts/game_state.gd")

var state: Node
var player: Node3D

var arrow: Node3D
var marker: Node3D

var trail: Array[Node3D] = []
var current_hint: String = ""


func setup(
	game_state: Node,
	controlled_player: Node3D
) -> void:
	state = game_state
	player = controlled_player


func _ready() -> void:
	arrow = Node3D.new()
	arrow.name = "DirectionArrow"
	add_child(arrow)

	V.box(
		arrow,
		Vector3(0.18, 0.08, 0.5),
		Vector3(0, 0, -0.22),
		Color("#E5B65D")
	)

	V.box(
		arrow,
		Vector3(0.42, 0.08, 0.28),
		Vector3(0, 0, -0.55),
		Color("#E5B65D")
	)

	marker = Node3D.new()
	marker.name = "TargetMarker"
	add_child(marker)

	V.cylinder(
		marker,
		0.85,
		0.07,
		Vector3.ZERO,
		Color("#E5B65D")
	)

	for i in range(13):
		var a := Node3D.new()
		add_child(a)

		V.box(
			a,
			Vector3(0.3, 0.06, 0.65),
			Vector3.ZERO,
			Color("#F0C878")
		)

		V.box(
			a,
			Vector3(0.6, 0.06, 0.22),
			Vector3(0, 0, -0.35),
			Color("#F0C878")
		)

		trail.append(a)


func _process(_delta: float) -> void:
	if state == null or not is_instance_valid(player):
		return

	var target: Vector3 = S.FISHING
	current_hint = "Иди на синий квадрат и поймай рыбу"

	if player.fishing:
		target = S.FISHING
		current_hint = "Ловим рыбу... Подожди 3 секунды"

	elif state.player_fish > 0:
		target = S.FISH_BOX
		current_hint = "Отнеси рыбу в ящик у причала"

	elif state.player_fillets > 0:
		target = S.FILLET_BOX
		current_hint = "Положи филе в ящик у кассы"

	elif state.machine_output > 0 and state.hired[2] == 0:
		target = S.MACHINE_ZONE
		current_hint = "Забери готовое филе со станка"

	elif state.fish_box > 0 and state.hired[1] == 0:
		target = S.MACHINE_ZONE
		current_hint = "Перенеси рыбу из ящика к станку"

	elif (
		state.fillet_box > 0
		and state.boat_state == "ordering"
		and state.fillet_box >= state.boat_order
		and state.hired[3] == 0
	):
		target = S.CASH
		current_hint = "Иди на зелёный квадрат и продай заказ"

	elif state.machine_input > 0 or state.processing:
		target = S.MACHINE_ZONE
		current_hint = "Станок разделывает рыбу — дождись филе"

	elif state.coins >= state.prices[0] and state.hired[0] == 0:
		target = S.HIRE_FISHER
		current_hint = (
			"Найми рыбака за %d монет" % state.prices[0]
		)

	elif (
		state.coins >= state.prices[1]
		and state.hired[1] == 0
		and state.hired[0] > 0
	):
		target = S.HIRE_FISH_CARRIER
		current_hint = (
            "Найми грузчика рыбы за %d монет"
			% state.prices[1]
		)

	elif (
		state.coins >= state.prices[2]
		and state.hired[2] == 0
		and state.hired[1] > 0
	):
		target = S.HIRE_FILLET_CARRIER
		current_hint = (
            "Найми грузчика филе за %d монет"
			% state.prices[2]
		)

	elif (
		state.coins >= state.prices[3]
		and state.hired[3] == 0
		and state.hired[2] > 0
	):
		target = S.HIRE_SELLER
		current_hint = (
            "Найми продавца за %d монет"
			% state.prices[3]
		)

	elif not player.armed and player.near(S.FISHING):
		target = S.FISHING
		current_hint = (
            "Выйди из синего квадрата и зайди снова"
		)

	var start: Vector3 = player.global_position
	start.y = 0.0

	var finish: Vector3 = target
	finish.y = 0.0

	var direction: Vector3 = finish - start
	var distance: float = direction.length()

	arrow.position = (
		player.global_position
		+ Vector3(
			0,
			2.65 + sin(Time.get_ticks_msec() * 0.004) * 0.08,
			0
		)
	)

	arrow.visible = distance > 1.4
	marker.visible = distance > 1.4
	marker.position = finish + Vector3(0, 0.76, 0)

	if distance > 0.01:
		arrow.rotation.y = atan2(
			-direction.x,
			-direction.z
		)

	for i in range(trail.size()):
		var a: Node3D = trail[i]
		var step: float = float(i + 1) * 1.6

		a.visible = step < distance - 0.8

		if a.visible:
			a.position = (
				start
				+ direction.normalized() * step
				+ Vector3(0, 0.65, 0)
			)

			a.rotation.y = atan2(
				-direction.x,
				-direction.z
			)
