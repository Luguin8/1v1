extends Node3D

func _ready():
	var mesh_instances = []
	for child in $Sketchfab_model/XmasPlaza_fbx/RootNode/Plane.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
	
	for mesh_instance in mesh_instances:
		var shape = mesh_instance.mesh.create_trimesh_shape()
		var body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		collision_shape.shape = shape
		body.add_child(collision_shape)
		mesh_instance.add_child(body)
