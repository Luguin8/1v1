extends Control

signal skin_changed(new_skin_index: int)

# =========================
# Configuración de skins
# =========================
var player_models: Array[String] = [
	"res://Scenes/Player/PlayerModel.tscn"  # Modelo base para preview
]

# =========================
# Estado
# =========================
var selected_skin_index: int = 0
var current_model: Node3D
var preview_root: Node3D

var rotating_auto: bool = false
var auto_rotation_speed: float = 0.003

# =========================
# Referencias a nodos
# =========================
@onready var skin_grid: GridContainer = $GridContainer
@onready var confirm_button: Button = $Confirmar
@onready var volver_button: Button = $Volver
@onready var rotar_button: Button = $Rotar if has_node("Rotar") else null
@onready var alert_label: Label = $AlertLabel if has_node("AlertLabel") else null
@onready var preview_viewport: Node = $PreviewContainer/PreviewViewport
var preview_model_holder: Node3D

var skin_buttons: Array[Button] = []

# =========================
# READY
# =========================
func _ready() -> void:
	await get_tree().process_frame

	if preview_viewport:
		preview_model_holder = preview_viewport.get_node_or_null("ModelHolder") as Node3D
		if preview_model_holder == null:
			preview_model_holder = preview_viewport.get_node_or_null("modelholder") as Node3D
	if preview_model_holder == null:
		push_error("ModelHolder no encontrado dentro de PreviewViewport")
		return

	preview_root = Node3D.new()
	preview_model_holder.add_child(preview_root)
	preview_root.position = Vector3.ZERO
	preview_root.rotation = Vector3.ZERO

	_setup_buttons()
	load_selected_skin()

	if confirm_button: confirm_button.pressed.connect(_on_confirm_pressed)
	if volver_button: volver_button.pressed.connect(_on_volver_pressed)
	if rotar_button: rotar_button.pressed.connect(_on_rotar_pressed)
	if alert_label: alert_label.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# =========================
# Botones de la grilla
# =========================
func _setup_buttons() -> void:
	skin_buttons.clear()
	for i in range(skin_grid.get_child_count()):
		var btn = skin_grid.get_child(i)
		if btn is Button:
			var idx: int = i
			btn.pressed.connect(func(): select_skin(idx))
			skin_buttons.append(btn)
			if idx >= player_models.size():
				btn.disabled = true
				btn.tooltip_text = "Próximamente"
	selected_skin_index = clamp(0, 0, max(player_models.size() - 1, 0))

# =========================
# Selección de skin
# =========================
func select_skin(index: int) -> void:
	if index < 0 or index >= player_models.size():
		_show_alert("Esa skin todavía no está disponible.")
		return
	selected_skin_index = index
	load_selected_skin()

func load_selected_skin() -> void:
	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

	var path: String = player_models[selected_skin_index]
	var resource = load(path)
	if resource == null:
		push_error("Modelo no encontrado: " + str(path))
		_show_alert("No se pudo cargar la skin.")
		return

	var instance: Node3D
	if resource is PackedScene:
		instance = resource.instantiate() as Node3D
	else:
		push_error("El recurso no es un PackedScene")
		_show_alert("Recurso inválido.")
		return

	# Aplicar skin del PlayerModel
	if instance.has_method("apply_skin"):
		instance.apply_skin(selected_skin_index)

	current_model = instance
	preview_root.add_child(current_model)
	current_model.transform.origin = Vector3.ZERO
	current_model.rotation = Vector3.ZERO
	current_model.scale = Vector3.ONE

# =========================
# Rotación automática
# =========================
func _process(delta: float) -> void:
	if rotating_auto and current_model:
		current_model.rotate_y(auto_rotation_speed)

func _on_rotar_pressed() -> void:
	rotating_auto = !rotating_auto

func _on_confirm_pressed() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "skin_index", selected_skin_index)
	if config.save("user://player.cfg") != OK:
		_show_alert("No se pudo guardar la skin.")
		return
	emit_signal("skin_changed", selected_skin_index)
	_show_alert("Skin guardada correctamente.", 1.6)

func _on_volver_pressed() -> void:
	var scene = load("res://Scenes/MainMenu.tscn") as PackedScene
	if scene: get_tree().change_scene_to_packed(scene)
	else: push_error("MainMenu.tscn no encontrado")

func _show_alert(text: String, seconds: float = 2.0) -> void:
	if alert_label:
		alert_label.text = text
		alert_label.visible = true
		await get_tree().create_timer(seconds).timeout
		alert_label.visible = false
