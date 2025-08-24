extends CanvasLayer  # Script del HUD

@onready var killfeed_container = $KillFeedContainer
@export var killfeed_duration := 3.0  # segundos que dura cada mensaje
@onready var hit_marker_label = $HitMarkerLabel
@onready var kill_marker_label = $KillMarkerLabel  # NUEVO

var player_name = "Jugador"  # Nombre del jugador local

func _ready():
	load_player_name()
	print("HUD listo. Nombre del jugador:", player_name)  # debug

# --- Cargar nombre del jugador desde ConfigFile ---
func load_player_name():
	var config = ConfigFile.new()
	if config.load("user://player.cfg") == OK:
		player_name = config.get_value("player", "name", "Jugador")

# --- Mostrar HIT ---
func show_hitmarker() -> void:
	hit_marker_label.text = "HIT"
	hit_marker_label.show()
	await get_tree().create_timer(0.3).timeout
	hit_marker_label.hide()
	hit_marker_label.text = ""

# --- Mostrar KILL ---
func show_killmarker() -> void:
	kill_marker_label.text = "KILL"
	kill_marker_label.show()
	await get_tree().create_timer(0.5).timeout
	kill_marker_label.hide()
	kill_marker_label.text = ""

# --- Killfeed ---
func add_killfeed_message(weapon_name: String, victim_name: String, attacker_name: String = ""):
	# Si attacker_name no se pasa, usar el jugador local
	if attacker_name == "":
		attacker_name = player_name

	# Crear label
	var label = Label.new()
	label.text = "%s [%s] -> %s" % [attacker_name, weapon_name, victim_name]
	killfeed_container.add_child(label)

	# Timer para eliminarlo después de killfeed_duration
	var timer = Timer.new()
	timer.wait_time = killfeed_duration
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)
