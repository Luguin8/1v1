extends Node3D

# =========================
# Sensibilidad y límites
# =========================
var sensitivity = 0.003
var min_pitch = -1.2
var max_pitch = 1.2

var yaw = 0.0
var pitch = 0.0

# =========================
# Referencias
# =========================
@onready var player = get_parent()  # CameraController dentro del Player
@onready var camera = $Camera3D

# =========================
# Posiciones de cámara
var default_position: Vector3
var aim_position: Vector3

# =========================
# READY
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	default_position = camera.transform.origin
	# Ajusta esta posición según la mira del sniper
	aim_position = Vector3(0, 1.5, 0.2)

# =========================
# Input mouse
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

		# Solo afecta al pitch de la cámara
		rotation.x = pitch

		# El yaw se aplica al Player
		player.rotation.y = yaw

# =========================
# PROCESS: actualizar cámara
func _process(delta):
	if player.is_aiming:
		# Zoom de posición hacia la mira
		var target_pos = aim_position
		camera.transform.origin = camera.transform.origin.lerp(target_pos, 0.1)
	else:
		# Volver a tercera persona
		var target_pos = default_position
		camera.transform.origin = camera.transform.origin.lerp(target_pos, 0.1)
