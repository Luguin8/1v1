extends Node3D

# Sensibilidad del mouse
var sensitivity = 0.003

# Limites verticales (en radianes)
var min_pitch = -1.2
var max_pitch = 1.2

# Variables internas
var yaw = 0
var pitch = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0)
