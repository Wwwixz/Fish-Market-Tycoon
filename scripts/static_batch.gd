extends RefCounted

# Batch only explicitly static decorations; animated subtrees stay independent.
static func build(root: Node3D, excluded: Array[Node3D]) -> void:
	var groups: Dictionary = {}
	_collect(root, excluded, groups)
	var inverse := root.global_transform.affine_inverse()
	for instances: Array in groups.values():
		if instances.size() < 2:
			continue
		var source: MeshInstance3D = instances[0]
		var batch := MeshInstance3D.new()
		batch.name = "StaticBatch"
		var material: StandardMaterial3D = source.material_override.duplicate()
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		batch.material_override = material
		batch.cast_shadow = source.cast_shadow
		batch.layers = source.layers
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for instance: MeshInstance3D in instances:
			var transform := inverse * instance.global_transform
			var normals_basis := transform.basis.inverse().transposed()
			var arrays := instance.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(indices.size() if not indices.is_empty() else vertices.size()):
				var index := indices[i] if not indices.is_empty() else i
				surface.set_color(instance.material_override.albedo_color)
				surface.set_normal((normals_basis * normals[index]).normalized())
				surface.add_vertex(transform * vertices[index])
			instance.hide()
		surface.index()
		batch.mesh = surface.commit()
		root.add_child(batch)


static func _collect(node: Node, excluded: Array[Node3D], groups: Dictionary) -> void:
	if node is Node3D and (node in excluded or not node.is_visible_in_tree()):
		return
	if node is MeshInstance3D and node.mesh != null and node.material_override is StandardMaterial3D and not node.material_override.vertex_color_use_as_albedo:
		var material: StandardMaterial3D = node.material_override
		var key := "%s:%s:%s:%s:%s:%d:%d" % [material.shading_mode, material.roughness,
			material.metallic, material.transparency, material.cull_mode, node.cast_shadow, node.layers]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	for child in node.get_children():
		_collect(child, excluded, groups)
