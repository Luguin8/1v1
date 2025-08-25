extends Node3D

@export var model_holder: Node3D

var bone_hitbox_sizes := {
	"pelvis": Vector2(0.3,0.3),
	"spine_01": Vector2(0.25,0.4),
	"spine_02": Vector2(0.25,0.4),
	"spine_03": Vector2(0.25,0.4),
	"clavicle_l": Vector2(0.1,0.25),
	"clavicle_r": Vector2(0.1,0.25),
	"upperarm_l": Vector2(0.1,0.35),
	"upperarm_r": Vector2(0.1,0.35),
	"lowerarm_l": Vector2(0.08,0.3),
	"lowerarm_r": Vector2(0.08,0.3),
	"hand_l": Vector2(0.07,0.2),
	"hand_r": Vector2(0.07,0.2),
	"thigh_l": Vector2(0.15,0.5),
	"thigh_r": Vector2(0.15,0.5),
	"calf_l": Vector2(0.12,0.45),
	"calf_r": Vector2(0.12,0.45),
	"foot_l": Vector2(0.1,0.25),
	"foot_r": Vector2(0.1,0.25),
	"head": Vector2(0.15,0.25),
	"neck_01": Vector2(0.12,0.2)
}

func _ready():
	call_deferred("_create_hitboxes_after_ready")

func _create_hitboxes_after_ready():
	# Espera hasta que ModelHolder tenga un hijo (PlayerBase)
	while model_holder.get_child_count() == 0:
		await get_tree().process_frame

	var skeleton = find_skeleton_recursive(model_holder)
	if not skeleton:
		print("No se encontró Skeleton3D.")
		return

	# Espera hasta que Skeleton3D tenga huesos
	while skeleton.get_bone_count() == 0:
		await get_tree().process_frame

	print("Skeleton3D encontrado con huesos:", skeleton.get_bone_count())

	# Crear hitboxes
	for bone_name in bone_hitbox_sizes.keys():
		var bone_index = skeleton.find_bone(bone_name)
		if bone_index == -1:
			print("No se encontró hueso:", bone_name)
			continue

		var attachment = BoneAttachment3D.new()
		attachment.bone_name = bone_name
		attachment.transform = Transform3D.IDENTITY
		skeleton.add_child(attachment)

		var collision = CollisionShape3D.new()
		var capsule = CapsuleShape3D.new()
		var size = bone_hitbox_sizes[bone_name]
		capsule.radius = size.x
		capsule.height = size.y
		collision.shape = capsule
		attachment.add_child(collision)

	print("Hitboxes generadas con éxito.")

func find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = find_skeleton_recursive(child)
		if result:
			return result
	return null
