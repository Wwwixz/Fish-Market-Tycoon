
extends Node3D

const State = preload("res://scripts/game_state.gd")
const World = preload("res://scripts/world_builder.gd")
const Player = preload("res://scripts/player_controller.gd")
const Workers = preload("res://scripts/worker_manager.gd")
const Boats = preload("res://scripts/boat_manager.gd")
const Guide = preload("res://scripts/navigation_guide.gd")
const UI = preload("res://scripts/game_ui.gd")
const Visuals = preload("res://scripts/visuals.gd")

const ProductionVisuals = preload(
    "res://scripts/production_visuals.gd"
)
const StorageVisuals = preload(
    "res://scripts/storage_visuals.gd"
)
const UpgradeManager = preload(
    "res://scripts/upgrade_manager.gd"
)
const MarketVisuals = preload(
    "res://scripts/market_visuals.gd"
)
const CustomerManager = preload(
    "res://scripts/customer_manager.gd"
)
const ExpansionManager = preload(
    "res://scripts/expansion_manager.gd"
)
const EnvironmentVisuals = preload(
    "res://scripts/environment_visuals.gd"
)
const SaveManager = preload(
    "res://scripts/save_manager.gd"
)

var state: Node
var world: Node3D
var player: Node3D
var workers: Node3D
var boats: Node3D
var guide: Node3D
var ui: CanvasLayer

var production_visuals: Node3D
var storage_visuals: Node3D
var upgrade_manager: Node3D
var market_visuals: Node3D
var customer_manager: Node3D
var expansion_manager: Node3D
var environment_visuals: Node3D
var save_manager: Node

func _ready() -> void:
	state = State.new()
	state.name = "GameState"
	add_child(state)

	world = World.new()
	world.name = "World"
	add_child(world)

	environment_visuals = EnvironmentVisuals.new()
	environment_visuals.name = "EnvironmentVisuals"
	add_child(environment_visuals)

	player = Player.new()
	player.name = "Player"
	player.call("setup", state)
	add_child(player)

	workers = Workers.new()
	workers.name = "Workers"
	workers.call("setup", state)
	add_child(workers)

	player.set("worker_manager", workers)

	save_manager = SaveManager.new()
	save_manager.name = "SaveManager"
	save_manager.call("setup", state, player, workers)
	add_child(save_manager)

	var loaded_data: Dictionary = save_manager.call("load_game")

	if not loaded_data.is_empty():
		_restore_worker_models()

		if player.has_method("_update_camera"):
			player.call("_update_camera", 1.0, true)

	boats = Boats.new()
	boats.name = "Boats"
	boats.call("setup", state)
	add_child(boats)

	production_visuals = ProductionVisuals.new()
	production_visuals.name = "ProductionVisuals"
	production_visuals.call("setup", state)
	add_child(production_visuals)

	if state.processing:
		if production_visuals.has_method("_start_processing"):
			production_visuals.call("_start_processing")

	storage_visuals = StorageVisuals.new()
	storage_visuals.name = "StorageVisuals"
	storage_visuals.call("setup", state)
	add_child(storage_visuals)

	upgrade_manager = UpgradeManager.new()
	upgrade_manager.name = "UpgradeManager"
	upgrade_manager.call("setup", state, player)
	add_child(upgrade_manager)

	market_visuals = MarketVisuals.new()
	market_visuals.name = "MarketVisuals"
	market_visuals.call("setup", state)
	add_child(market_visuals)

	customer_manager = CustomerManager.new()
	customer_manager.name = "CustomerManager"
	customer_manager.call("setup", state, player)
	add_child(customer_manager)

	expansion_manager = ExpansionManager.new()
	expansion_manager.name = "ExpansionManager"
	expansion_manager.call("setup", state, player)
	add_child(expansion_manager)

	guide = Guide.new()
	guide.name = "NavigationGuide"
	guide.call("setup", state, player)
	add_child(guide)

	ui = UI.new()
	ui.name = "GameUI"
	ui.call("setup", state, guide, workers)
	add_child(ui)

	state.reward.connect(_reward)
	state.changed.connect(_refresh)

	save_manager.ready_to_save = true
	_refresh()

func _restore_worker_models() -> void:
	var saved_hired: Array[int] = []
	var saved_prices: Array[int] = []

	for value in state.hired:
		saved_hired.append(int(value))

	for value in state.prices:
		saved_prices.append(int(value))

	var saved_coins: int = state.coins

	var default_prices: Array[int] = [30, 50, 70, 100]

	for role in range(4):
		state.hired[role] = 0
		state.prices[role] = default_prices[role]

	state.coins = 1000000000

	for role in range(4):
		for i in range(saved_hired[role]):
			workers.call("hire", role)

	for role in range(4):
		state.hired[role] = saved_hired[role]
		state.prices[role] = saved_prices[role]

	state.coins = saved_coins

func _reward(
	amount: int,
	icon: String,
	color: Color,
	pos: Vector3
) -> void:
	Visuals.popup(self, amount, icon, color, pos)

func _refresh() -> void:
	world.call("refresh", state)
	ui.call("refresh")
