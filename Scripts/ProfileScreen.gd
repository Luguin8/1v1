extends Control

# =========================
# Variables
# =========================
var player_name = "Jugador"              # Nombre del jugador

@onready var line_edit = $LineEdit       # LineEdit para editar el nombre
@onready var confirm_button = $Confirm   # Botón para confirmar cambio de nombre
@onready var stats_label = $StatsLabel   # Placeholder para estadísticas
@onready var volver_button = $Volver     # Botón para volver al menú
@onready var feedback_label = $NameChangedLabel   # Label para mostrar mensaje de éxito

# =========================
# _ready: inicialización de la pantalla
# =========================
func _ready():
	# --- Cargar nombre guardado ---
	line_edit.custom_minimum_size = Vector2(400, 50)  # ancho 400, alto 50
	load_player_name()
	if line_edit:
		line_edit.text = player_name
	else:
		push_error("LineEdit no encontrado en la escena.")

	# --- Conectar botón Confirmar ---
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	else:
		push_error("Confirm button no encontrado en la escena.")

	# --- Inicializar estadísticas (placeholder) ---
	if stats_label:
		stats_label.text = "Partidas jugadas: 0\nVictorias: 0\nDerrotas: 0"
	else:
		push_error("StatsLabel no encontrado en la escena.")

	# --- Conectar botón Volver ---
	if volver_button:
		volver_button.pressed.connect(_on_volver_pressed)
	else:
		push_error("Botón Volver no encontrado en la escena.")

# =========================
# Función para confirmar cambio de nombre
# =========================
func _on_confirm_pressed():
	var new_name = line_edit.text.strip_edges()
	
	if new_name == "":
		line_edit.text = player_name
		return

	if new_name.length() > 12:
		new_name = new_name.substr(0, 12)
		line_edit.text = new_name

	player_name = new_name
	save_player_name()

	# Mostrar mensaje de éxito
	if feedback_label:
		feedback_label.text = "Nombre cambiado correctamente ✅"
		feedback_label.show()
		# Desaparece después de 2 segundos
		await get_tree().create_timer(2.0).timeout
		feedback_label.text = ""



# =========================
# Guardar nombre en archivo local
# =========================
func save_player_name():
	var config = ConfigFile.new()
	config.set_value("player", "name", player_name)
	var err = config.save("user://player.cfg")
	if err != OK:
		print("Error guardando player.cfg:", err)

# =========================
# Cargar nombre desde archivo local
# =========================
func load_player_name():
	var config = ConfigFile.new()
	if config.load("user://player.cfg") == OK:
		player_name = config.get_value("player", "name", "Jugador")

# =========================
# Función para volver al menú principal
# =========================
func _on_volver_pressed() -> void:
	var scene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_error("Error: MainMenu.tscn no encontrado.")
