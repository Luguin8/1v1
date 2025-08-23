extends CharacterBody3D
var health = 100

func take_damage(amount):
	health -= amount
	print("Dummy recibió daño:", amount, "Vida restante:", health)
	if health <= 0:
		print("Dummy muerto")
		queue_free()
