extends CanvasLayer

# =========================
# Nodos HUD
# =========================
@onready var killfeed_container = $KillFeedContainer
@export var killfeed_duration := 3.0
@onready var hit_marker_label = $HitMarkerLabel
@onready var kill_marker_label = $KillMarkerLabel  
@onready var dash_label = $DashLabel
@onready var slide_label = $SlideLabel
@onready var cross = $Crosshair
@onready var melee_cross = $MeleeCrosshair
@onready var ammo_label = $AmmoLabel
@onready var health_bar = $HealthBar

var player_node: Node = null
var player_name = "Jugador"

func _ready():
	# Obtener referencia al jugador si fue seteada como meta
	if has_meta("player_node"):
		player_node = get_meta("player_node")
	load_player_name()

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
	if attacker_name == "":
		attacker_name = player_name
	var label = Label.new()
	label.text = "%s [%s] -> %s" % [attacker_name, weapon_name, victim_name]
	killfeed_container.add_child(label)
	var timer = Timer.new()
	timer.wait_time = killfeed_duration
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)

# --- Actualizar texto de cooldowns ---
func update_dash_cd(on_cd: bool) -> void:
	if dash_label:
		dash_label.text = "Dash en CD" if on_cd else ""

func update_slide_cd(on_cd: bool) -> void:
	if slide_label:
		slide_label.text = "Slide en CD" if on_cd else ""
