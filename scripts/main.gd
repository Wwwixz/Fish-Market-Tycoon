
extends Node3D

const State = preload("res://scripts/game_state.gd")
const World = preload("res://scripts/world_builder.gd")
const Player = preload("res://scripts/player_controller.gd")
const Workers = preload("res://scripts/worker_manager.gd")
const Boats = preload("res://scripts/boat_manager.gd")
const Guide = preload("res://scripts/navigation_guide.gd")
const UI = preload("res://scripts/game_ui.gd")
const Visuals = preload("res://scripts/visuals.gd")
const DockDetails = preload("res://scripts/dock_details.gd")
const Progression = preload("res://scripts/progression_manager.gd")
const ProductionVisuals = preload("res://scripts/production_visuals.gd")
const StorageVisuals = preload("res://scripts/storage_visuals.gd")
const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const MarketVisuals = preload("res://scripts/market_visuals.gd")
const CustomerManager = preload("res://scripts/customer_manager.gd")
const ExpansionManager = preload("res://scripts/expansion_manager.gd")
const EnvironmentVisuals = preload("res://scripts/environment_visuals.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

const QuestManager = preload("res://scripts/quest_manager.gd")
const QuestUI = preload("res://scripts/quest_ui.gd")
const DailyManager = preload("res://scripts/daily_manager.gd")
const MobileControls = preload("res://scripts/mobile_controls.gd")

@export var save_path: String = SaveManager.SAVE_PATH

var state: Node
var world: Node3D
var player: Node3D
var workers: Node3D
var boats: Node3D
var guide: Node3D
var ui: CanvasLayer

var dock_details: Node3D
var progression: Node
var production_visuals: Node3D
var storage_visuals: Node3D
var upgrade_manager: Node3D
var market_visuals: Node3D
var customer_manager: Node3D
var expansion_manager: Node3D
var environment_visuals: Node3D
var save_manager: Node

var quest_manager: Node
var quest_ui: CanvasLayer
var daily_manager: Node
var mobile_controls: CanvasLayer


func _ready() -> void:
	get_tree().quit_on_go_back = false
	state = State.new()
	state.name = "GameState"
	add_child(state)

	world = World.new()
	world.name = "World"
	add_child(world)

	dock_details = DockDetails.new()
	dock_details.name = "DockDetails"
	add_child(dock_details)

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

	mobile_controls = MobileControls.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.call("setup", player)
	add_child(mobile_controls)

	progression = Progression.new()
	progression.name = "ProgressionManager"
	progression.call("setup", state)
	add_child(progression)

	quest_manager = QuestManager.new()
	quest_manager.name = "QuestManager"
	quest_manager.call("setup", state)
	add_child(quest_manager)

	daily_manager = DailyManager.new()
	daily_manager.name = "DailyManager"
	daily_manager.call("setup", state)
	add_child(daily_manager)

	save_manager = SaveManager.new()
	save_manager.save_path = save_path
	save_manager.name = "SaveManager"
	save_manager.call("setup", state, player, workers)
	save_manager.set("progression", progression)
	save_manager.set("quest_manager", quest_manager)
	save_manager.set("daily_manager", daily_manager)
	add_child(save_manager)

	var loaded_data: Dictionary = save_manager.call("load_game")

	if not loaded_data.is_empty():
		player.prime_hire_zones()
		if player.has_method("_update_camera"):
			player.call("_update_camera", 1.0, true)

	quest_manager.call("finish_loading")
	daily_manager.call("finish_loading")

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
	ui.set("progression", progression)
	add_child(ui)

	quest_ui = QuestUI.new()
	quest_ui.name = "QuestUI"
	quest_ui.call(
		"setup",
		quest_manager,
		daily_manager
	)
	add_child(quest_ui)
	ui.bottom_panel.resized.connect(_position_context_info)
	get_viewport().size_changed.connect(_position_context_info)
	_position_context_info.call_deferred()
	ui.modal_opened.connect(_open_game_window.bind(ui))
	quest_ui.modal_opened.connect(_open_game_window.bind(quest_ui))
	ui.modal_closed.connect(_sync_controls)
	quest_ui.modal_closed.connect(_sync_controls)
	save_manager.save_failed.connect(ui._notice)

	state.reward.connect(_reward)
	state.changed.connect(_refresh)

	save_manager.start_saving()
	if not save_manager.last_error.is_empty():
		ui._notice(save_manager.last_error)
	elif not save_manager.recovery_notice.is_empty():
		ui._notice(save_manager.recovery_notice)
	_refresh()
	print("Fish Market Tycoon: ready")


func _open_game_window(active_window: CanvasLayer) -> void:
	if active_window != ui:
		ui._close_menu()
	if active_window != quest_ui:
		quest_ui._close()
	state.controls_blocked = true
	mobile_controls.set_enabled(false)
	player.velocity = Vector3.ZERO
	player.mobile_input = Vector2.ZERO
	world.info_panel.hide()


func _position_context_info() -> void:
	if is_instance_valid(ui) and is_instance_valid(world):
		world.layout_info_panel(ui.bottom_panel.get_global_rect())


func _sync_controls() -> void:
	state.controls_blocked = ui.overlay.visible or quest_ui.overlay.visible
	mobile_controls.set_enabled(not state.controls_blocked)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(quest_ui):
		if quest_ui.overlay.visible:
			quest_ui._close()
		elif ui.overlay.visible:
			ui._close_menu()
		else:
			save_manager.save_game()
			get_tree().quit()


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
