extends Node3D

# =========================
# Nodo que contendrá el modelo cargado
# =========================
var current_model: Node3D = null
var mesh_instance: MeshInstance3D = null

# Índice de skin seleccionada
var selected_skin_index: int = 0

# =========================
# READY
# =========================
func _ready():
	apply_skin(selected_skin_index)

# =========================
# Aplicar skin visual
# =========================
func apply_skin(index: int) -> void:
	selected_skin_index = index

	# Liberar modelo anterior
	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

	# =========================
	# Lista de skins disponibles
	# =========================
	var skins = [
		"res://scenes/player/PlayerSkin1.tscn",
		# "res://scenes/player/PlayerSkin2.tscn",
		# "res://scenes/player/PlayerSkin3.tscn"
	]

	# Validar índice
	if index < 0 or index >= skins.size():
		push_error("Índice de skin inválido: %s" % index)
		return

	# Cargar recurso
	var path: String = skins[index]
	var resource = load(path)
	if resource == null:
		push_error("No se pudo cargar la skin en: " + str(path))
		return

	# Instanciar modelo
	var instance: Node3D
	if resource is PackedScene:
		instance = resource.instantiate() as Node3D
	else:
		push_error("El recurso no es una PackedScene")
		return

	# Montar dentro de este Node3D
	add_child(instance)
	current_model = instance
	current_model.transform.origin = Vector3.ZERO
	current_model.rotation = Vector3.ZERO
	current_model.scale = Vector3.ONE

	# Obtener primer MeshInstance3D para efectos visuales
	mesh_instance = get_mesh_from_model(current_model)

# =========================
# Función recursiva para encontrar MeshInstance3D
# =========================
func get_mesh_from_model(model: Node) -> MeshInstance3D:
	if model is MeshInstance3D:
		return model
	for child in model.get_children():
		var mesh = get_mesh_from_model(child)
		if mesh:
			return mesh
	return null
