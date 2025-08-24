extends Control

# =========================
# Señales
# =========================
signal skin_changed(new_skin_index: int)   # Para sincronización futura en multiplayer

# =========================
# Variables
# =========================
var selected_skin_index := 0                  # Índice de la skin seleccionada
var current_model: Node3D = null              # Referencia al modelo 3D instanciado
var player_models := [                        # Rutas a los modelos
	"res://assets/models/granjero.glb",       # Skin 0
	"res://assets/models/ninja.glb"           # Skin 1
]
var preview_node: Node3D                      # Nodo donde se instanciará el modelo 3D

# =========================
# Referencias a nodos
# =========================
@onready var skin_grid := $GridContainer
@onready var confirm_button := $Confirmar
@onready var volver_button := $Volver
@onready var title_label := $Titulo
@onready var alert_label := $AlertLabel        # Label para mostrar "Skin cambiada correctamente"

# =========================
# _ready: inicialización
# =========================
func _ready() -> void:
	# Esperar un frame para asegurarnos que todos los nodos estén inicializados
	await get_tree().process_frame
	preview_node = $PreviewContainer/PreviewViewport/ModelHolder
	if not preview_node:
		push_error("Error: CharacterDisplay (ModelHolder) no encontrado en PreviewViewport")
		return

	# Instanciar skin inicial
	load_selected_skin()

	# Conectar botones de skins, comprobando que existan
	for i in skin_grid.get_child_count():
		var btn = skin_grid.get_child(i)
		if btn:
			btn.pressed.connect(func(idx=i): select_skin(idx))

	# Conectar botón confirmar
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	else:
		push_error("ConfirmButton no encontrado")

	# Conectar botón volver
	if volver_button:
		volver_button.pressed.connect(_on_volver_pressed)
	else:
		push_error("BackButton no encontrado")

	# Inicializar alerta invisible
	if alert_label:
		alert_label.visible = false

# =========================
# Funciones de selección
# =========================
func select_skin(index: int) -> void:
	if index >= player_models.size():
		return
	selected_skin_index = index
	load_selected_skin()

func load_selected_skin() -> void:
	# Eliminar modelo anterior
	if current_model and current_model.is_inside_tree():
		current_model.queue_free()
		current_model = null

	# Cargar nuevo modelo
	var resource = load(player_models[selected_skin_index])
	if resource == null:
		push_error("Modelo no encontrado: " + str(player_models[selected_skin_index]))
		return

	# Instanciar según tipo de recurso
	if resource is PackedScene:
		current_model = resource.instantiate()
	elif resource is Node:
		current_model = resource.duplicate()
	else:
		push_error("El recurso no es un Node ni un PackedScene: " + str(player_models[selected_skin_index]))
		return

	# Agregar al preview_node
	if preview_node:
		preview_node.add_child(current_model)
		current_model.transform.origin = Vector3(0, 0, 0)
		current_model.rotation_degrees = Vector3(0, 0, 0)
		current_model.scale = Vector3(1, 1, 1)
	else:
		push_error("preview_node es null, no se puede agregar modelo")

# =========================
# Confirmar selección
# =========================
func _on_confirm_pressed() -> void:
	# Guardar skin seleccionada en archivo local
	var config = ConfigFile.new()
	config.set_value("player","skin_index", selected_skin_index)
	var err = config.save("user://player.cfg")
	if err != OK:
		print("Error guardando skin:", err)
		return

	# ===============================
	# Aplicar cambio al player actual
	# ===============================
	var player = get_tree().get_root().get_node("Main/Player") # Ajusta path según tu escena
	if player and player.has_node("MeshInstance3D"):
		var mesh_node = player.get_node("MeshInstance3D")
		var new_model_res = load(player_models[selected_skin_index])
		if new_model_res is PackedScene:
			var new_model = new_model_res.instantiate()
			# Reemplazar MeshInstance3D
			player.remove_child(mesh_node)
			mesh_node.queue_free()
			player.add_child(new_model)
			new_model.name = "MeshInstance3D"
			# Actualizar referencia interna del player
			player.mesh_instance = new_model
			player.selected_skin_index = selected_skin_index  # Preparado para sincronización online

	# ===============================
	# Señal para futura sincronización multiplayer
	# ===============================
	emit_signal("skin_changed", selected_skin_index)
	# NOTA: Cuando implementes online, podes conectar esta señal a la lógica de red para que otros jugadores vean el cambio

	# Mostrar alerta
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
