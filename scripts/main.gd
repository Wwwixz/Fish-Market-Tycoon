
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

var state: Node
var world: Node3D
var player: Node3D
var workers: Node3D
var boats: Node3D
var guide: Node3D
var ui: CanvasLayer
var production_visuals: Node3D
var storage_visuals: Node3D

func _ready() -> void:
	state = State.new()
	state.name = "GameState"
	add_child(state)

	world = World.new()
	world.name = "World"
	add_child(world)

	player = Player.new()
	player.name = "Player"
	player.setup(state)
	add_child(player)

	workers = Workers.new()
	workers.name = "Workers"
	workers.setup(state)
	add_child(workers)

	player.worker_manager = workers

	boats = Boats.new()
	boats.name = "Boats"
	boats.setup(state)
	add_child(boats)

	production_visuals = ProductionVisuals.new()
	production_visuals.name = "ProductionVisuals"
	production_visuals.setup(state)
	add_child(production_visuals)

	storage_visuals = StorageVisuals.new()
	storage_visuals.name = "StorageVisuals"
	storage_visuals.setup(state)
	add_child(storage_visuals)

	guide = Guide.new()
	guide.name = "NavigationGuide"
	guide.setup(state, player)
	add_child(guide)

	ui = UI.new()
	ui.name = "GameUI"
	ui.setup(state, guide, workers)
	add_child(ui)

	state.reward.connect(_reward)
	state.changed.connect(_refresh)

	_refresh()

func _reward(
	amount: int,
	icon: String,
	color: Color,
	pos: Vector3
) -> void:
	Visuals.popup(
		self,
		amount,
		icon,
		color,
		pos
	)

func _refresh() -> void:
	world.refresh(state)
	ui.refresh()
