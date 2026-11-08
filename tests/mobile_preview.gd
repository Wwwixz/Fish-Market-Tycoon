extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func settle() -> void:
	for _frame in range(12):
		await process_frame


func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-artifacts/mobile-" + name + ".png")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "res://test-artifacts/mobile-preview-unused.json"
	root.add_child(scene)
	scene.save_manager.ready_to_save = false
	for viewport_size in [Vector2i(480, 1067), Vector2i(320, 568), Vector2i(360, 640), Vector2i(1280, 720)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await settle()
		scene.player._update_camera(0.0, true)
		await capture("hud-%dx%d" % [viewport_size.x, viewport_size.y])
		scene.ui._open_menu()
		scene.ui._select_menu(0)
		await capture("menu-%dx%d" % [viewport_size.x, viewport_size.y])
		for tab in [1, 2]:
			scene.ui._select_menu(tab)
			await capture("tab%d-%dx%d" % [tab, viewport_size.x, viewport_size.y])
		scene.ui._select_menu(3)
		await capture("development-%dx%d" % [viewport_size.x, viewport_size.y])
		for tab in range(1, 4):
			scene.ui._select_development(tab)
			await capture("development%d-%dx%d" % [tab, viewport_size.x, viewport_size.y])
		scene.ui._select_development(0)
		scene.quest_ui._open()
		await capture("quests-%dx%d" % [viewport_size.x, viewport_size.y])
		scene.quest_ui._close()
	print("Mobile previews saved to test-artifacts")
	quit()
