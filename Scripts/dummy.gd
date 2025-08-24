extends Node3D

var health = 100
var max_health = 100
var respawn_time = 5.0
var start_position

func _ready():
	start_position = global_transform.origin

func take_damage(amount):
	health -= amount
	print("Dummy recibió daño:", amount, "Vida restante:", health)
	if health <= 0:
		print("Dummy muerto")
		hide()               # Oculta el dummy
		set_process(false)   # Detiene procesos
		# Espera 5 segundos antes de respawnear
		await get_tree().create_timer(respawn_time).timeout
		respawn()

func respawn():
	health = max_health
	global_transform.origin = start_position
	show()
	set_process(true)
	print("Dummy reapareció")
