extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func count_drawables(node: Node) -> int:
	var result := 0
	if node is GeometryInstance3D and node.is_visible_in_tree():
		result += 1
	for child in node.get_children():
		result += count_drawables(child)
	return result


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "res://test-artifacts/profile-unused.json"
	root.add_child(scene)
	scene.save_manager.ready_to_save = false
	for child in scene.get_children():
		var count := count_drawables(child)
		if count > 0:
			print(child.name, ": ", count)
	scene.free()
	quit()
