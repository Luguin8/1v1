extends CPUParticles3D

# Script para configurar automáticamente el muzzle flash
# Asociarlo directamente al CPUParticles3D

func _ready():
	emitting = false
	one_shot = true
	lifetime = 0.2
	amount = 15

	# Crear material si no existe
	if process_material_override == null:
		process_material_override = ParticleProcessMaterial.new()

	var mat := process_material_override as ParticleProcessMaterial

	# Configuración correcta
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.initial_velocity = 12.0
	mat.spread = deg_to_rad(15.0)
	mat.gravity = Vector3.ZERO
	mat.angle = Vector2(0, 0)
	mat.angular_velocity = Vector2(0, 0)
	mat.orbit_velocity = Vector2(0, 0)
	mat.scale = Vector2(0.2, 0.2)
	mat.color = Color(1, 0.8, 0.2)
	mat.color_ramp = null

# Función para disparar el muzzle flash
func shoot_flash():
	restart()
	emitting = true
