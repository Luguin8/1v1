extends Control

signal skin_changed(new_skin_index: int)

# =========================
# Variables
# =========================
var selected_skin_index := 0
var current_model: Node3D = null
var preview_root: Node3D = null
var player_models := [
	"res://scenes/PlayerBase.tscn"  # Solo PlayerBase
]

var rotating := false
var last_mouse_pos := Vector2.ZERO
var rotation_speed := 0.01

# =========================
# Referencias a nodos
# =========================
@onready var skin_grid := $GridContainer
@onready var confirm_button := $Confirmar
@onready var volver_button := $Volver
@onready var alert_label := $AlertLabel
@onready var preview_viewport := $PreviewContainer/PreviewViewport
@onready var preview_model_holder := $PreviewContainer/PreviewViewport/ModelHolder

# =========================
# READY
# =========================
func _ready() -> void:
	await get_tree().process_frame

	if not preview_model_holder:
		push_error("ModelHolder no encontrado en PreviewViewport")
		return

	# Nodo central para mantener modelo fijo
	preview_root = Node3D.new()
	preview_model_holder.add_child(preview_root)
	preview_root.position = Vector3.ZERO
	preview_root.rotation = Vector3.ZERO

	load_selected_skin()

	# Solo primer botón activo por ahora
	for i in skin_grid.get_child_count():
		var btn = skin_grid.get_child(i)
		if btn and i == 0:
			btn.pressed.connect(func(idx=i): select_skin(idx))

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if volver_button:
		volver_button.pressed.connect(_on_volver_pressed)
	if alert_label:
		alert_label.visible = false

	# Mouse siempre visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# =========================
# Selección de skin
# =========================
func select_skin(index: int) -> void:
	if index >= player_models.size():
		return
	selected_skin_index = index
	load_selected_skin()

func load_selected_skin() -> void:
	if current_model and current_model.is_inside_tree():
		current_model.queue_free()
		current_model = null

	var resource = load(player_models[selected_skin_index])
	if resource == null:
		push_error("Modelo no encontrado: " + str(player_models[selected_skin_index]))
		return

	var instance: Node3D = null
	if resource is PackedScene:
		instance = resource.instantiate() as Node3D
	else:
		push_error("El recurso no es un PackedScene")
		return

	# Convertir a Node3D puro si es CharacterBody3D
	if instance is CharacterBody3D:
		var tmp = Node3D.new()
		for child in instance.get_children():
			tmp.add_child(child.duplicate())
		instance.queue_free()
		instance = tmp

	# Eliminar armas si existen
	if instance.has_node("WeaponHolder"):
		instance.get_node("WeaponHolder").queue_free()

	# Desactivar física si tiene
	if instance.has_method("set_physics_process"):
		instance.set_physics_process(false)

	current_model = instance
	preview_root.add_child(current_model)
	current_model.transform.origin = Vector3(0,0,0)
	current_model.rotation = Vector3.ZERO
	current_model.scale = Vector3(1,1,1)

# =========================
# Rotación con click derecho
# =========================
func _gui_input(event: InputEvent) -> void:
	if not current_model:
		return

	# Solo rotar si click derecho sobre el viewport
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			last_mouse_pos = event.position
	elif event is InputEventMouseMotion and rotating:
		var delta = event.position - last_mouse_pos
		current_model.rotate_y(-delta.x * rotation_speed)
		last_mouse_pos = event.position

# =========================
# Confirmar selección
# =========================
func _on_confirm_pressed() -> void:
	var config = ConfigFile.new()
	config.set_value("player","skin_index", selected_skin_index)
	config.save("user://player.cfg")

	var player = get_tree().get_root().get_node_or_null("Main/Player")
	if player and player.has_node("MeshInstance3D"):
		var old_mesh = player.get_node("MeshInstance3D")
		var new_model_res = load(player_models[selected_skin_index])
		if new_model_res and new_model_res is PackedScene:
			var new_model: Node3D = new_model_res.instantiate() as Node3D
			if new_model.has_node("WeaponHolder"):
				new_model.get_node("WeaponHolder").queue_free()
			player.remove_child(old_mesh)
			old_mesh.queue_free()
			player.add_child(new_model)
			new_model.name = "MeshInstance3D"
			player.mesh_instance = new_model
			player.selected_skin_index = selected_skin_index

	emit_signal("skin_changed", selected_skin_index)

	if alert_label:
		alert_label.text = "Skin cambiada correctamente"
		alert_label.visible = true
		await get_tree().create_timer(2.0).timeout
		alert_label.visible = false

# =========================
# Botón volver
# =========================
func _on_volver_pressed() -> void:
	var scene = load("res://Scenes/MainMenu.tscn") as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_error("MainMenu.tscn no encontrado")
