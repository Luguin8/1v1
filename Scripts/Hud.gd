extends CanvasLayer  # Script del HUD

@onready var killfeed_container = $KillFeedContainer
@export var killfeed_duration := 3.0  # segundos que dura cada mensaje
@onready var hit_marker_label = $HitMarkerLabel
@onready var kill_marker_label = $KillMarkerLabel  # <--- NUEVO

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
func add_killfeed_message(attacker_name: String, weapon_name: String, victim_name: String):
	var label = Label.new()
	label.text = "%s [%s] -> %s" % [attacker_name, weapon_name, victim_name]
	killfeed_container.add_child(label)

	var timer = Timer.new()
	timer.wait_time = killfeed_duration
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)
