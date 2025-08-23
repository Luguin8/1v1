extends Node3D

var sensitivity = 0.003
var min_pitch = -1.2
var max_pitch = 1.2

var yaw = 0.0
var pitch = 0.0

@onready var player = get_parent() # Asumo que CameraController está dentro del Player

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

		# Solo afecta al pitch de la cámara
		rotation.x = pitch

		# El yaw se aplica al Player
		player.rotation.y = yaw
