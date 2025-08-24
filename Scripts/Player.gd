extends CharacterBody3D

# =========================
# HUD
# =========================
@onready var hud = get_tree().current_scene.get_node_or_null("HUD")

# =========================
# Weapon / WeaponHolder
# =========================
@onready var weapon_holder = $WeaponHolder
var current_weapon: Node = null  # Apuntará al WeaponHolder completo

# =========================
# Movimiento
# =========================
var walk_speed = 3.5
var run_speed = 7.0
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Dash
var dash_speed = 20.0
var dash_time = 0.2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = Vector3.ZERO

# Crouch / Slide
var is_crouching = false
var is_sliding = false
var crouch_height = 1.0
var stand_height = 2.0
var slide_speed = 15.0
var slide_time = 0.4
var slide_timer = 0.0
var slide_direction = Vector3.ZERO

# Saltos
var can_double_jump = true

# =========================
# Vida / daño por inactividad
# =========================
var max_health = 100
var health = max_health
var idle_damage_per_second = 5.0
var idle_timer = 0.0
var idle_threshold = 2.0

# =========================
# Feedback visual
# =========================
var damage_flash_time = 0.2
var flash_timer = 0.0
var is_flashing = false
var flash_color = Color(1,0,0)
var original_color = Color(1,1,1)

# =========================
# Modelo 3D / Skin
# =========================
var current_model: Node3D = null
var mesh_instance: MeshInstance3D = null
var selected_skin_index: int = 0   # índice de skin elegida

# =========================
# Referencias
# =========================
var camera_pivot: Node3D = null
var collision_shape: CollisionShape3D = null

# =========================
# READY
# =========================
func _ready():
	# Cargar skin_index guardado en disco
	var config := ConfigFile.new()
	var err := config.load("user://player.cfg")
	if err == OK:
		selected_skin_index = config.get_value("player", "skin_index", 0)
	else:
		selected_skin_index = 0

	apply_skin(selected_skin_index)

	# Weapon system
	if weapon_holder:
		current_weapon = weapon_holder
		current_weapon.update_weapon()
		current_weapon.player_node = self

	# Referencias
	camera_pivot = $camerapivot
	if not camera_pivot:
		push_error("CameraPivot no encontrado en PlayerBase!")

	collision_shape = $CollisionShape3D
	if not collision_shape:
		push_error("CollisionShape3D no encontrado en PlayerBase!")

	update_health_bar()

# =========================
# Aplicar Skin
# =========================
func apply_skin(index: int) -> void:
	selected_skin_index = index

	# Eliminar modelo anterior
	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null

	# Verificar que GameData exista
	if not Engine.has_singleton("GameData"):
		push_error("GameData autoload no está cargado")
		return

	var game_data = Engine.get_singleton("GameData")
	if index < 0 or index >= game_data.player_models.size():
		push_error("Skin index inválido: %s" % index)
		return

	var path: String = game_data.player_models[index]
	var resource := load(path)
	if resource == null:
		push_error("No se pudo cargar skin en " + str(path))
		return

	# Instanciar modelo
	var instance: Node3D
	if resource is PackedScene:
		instance = (resource as PackedScene).instantiate() as Node3D
	else:
		push_error("El recurso no es una PackedScene")
		return

	# Montar dentro de ModelHolder
	var holder := $ModelHolder if has_node("ModelHolder") else null
	if holder:
		holder.add_child(instance)
		current_model = instance
		current_model.transform.origin = Vector3.ZERO

		# Buscar un Mesh para aplicar flashes de daño
		mesh_instance = get_mesh_from_model(current_model)
		if mesh_instance and not mesh_instance.material_override:
			mesh_instance.material_override = StandardMaterial3D.new()

# Función recursiva para mesh
func get_mesh_from_model(model: Node) -> MeshInstance3D:
	if model is MeshInstance3D:
		return model
	for child in model.get_children():
		var mesh = get_mesh_from_model(child)
		if mesh:
			return mesh
	return null

# =========================
# PHYSICS PROCESS CORREGIDO
# =========================
func _physics_process(delta):
	if not collision_shape:
		return

	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_back"):    input_dir.z += 1
	if Input.is_action_pressed("move_left"):    input_dir.x -= 1
	if Input.is_action_pressed("move_right"):   input_dir.x += 1
	input_dir = input_dir.normalized()

	# Daño por inactividad
	if input_dir == Vector3.ZERO:
		idle_timer += delta
		if idle_timer >= idle_threshold:
			health -= idle_damage_per_second * delta
			health = max(health,1)
			is_flashing = true
			flash_timer = damage_flash_time
			update_health_bar()
	else:
		idle_timer = 0

	# Dash
	if Input.is_action_just_pressed("dash") and not is_dashing and input_dir != Vector3.ZERO:
		is_dashing = true
		dash_timer = dash_time
		var forward = -transform.basis.z
		var right = transform.basis.x
		dash_direction = (forward * input_dir.z + right * input_dir.x).normalized()

	if is_dashing:
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	else:
		# Crouch / Slide
		if Input.is_action_pressed("crouch"):
			if Input.is_action_pressed("run") and input_dir != Vector3.ZERO and not is_sliding:
				is_sliding = true
				slide_timer = slide_time
				var forward = -transform.basis.z
				var right = transform.basis.x
				slide_direction = (forward * input_dir.z + right * input_dir.x).normalized()
				if collision_shape: collision_shape.shape.height = crouch_height
				is_crouching = false
			elif not is_sliding and collision_shape:
				collision_shape.shape.height = crouch_height
				is_crouching = true
		else:
			if not is_sliding and collision_shape: collision_shape.shape.height = stand_height
			is_crouching = false

		# Aplicar slide
		if is_sliding:
			velocity.x = slide_direction.x * slide_speed
			velocity.z = slide_direction.z * slide_speed
			slide_timer -= delta
			if slide_timer <= 0:
				is_sliding = false
				if collision_shape: collision_shape.shape.height = stand_height
		else:
			# Movimiento normal
			if input_dir != Vector3.ZERO:
				var forward = transform.basis.z
				var right = transform.basis.x
				var move_dir = (forward * input_dir.z + right * input_dir.x).normalized()
				var speed = run_speed if Input.is_action_pressed("run") else walk_speed
				velocity.x = move_dir.x * speed
				velocity.z = move_dir.z * speed
			else:
				velocity.x = 0
				velocity.z = 0

	# Gravedad
	if not is_on_floor(): velocity.y -= gravity * delta

	# Saltos
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			can_double_jump = true
		elif can_double_jump:
			velocity.y = jump_velocity
			can_double_jump = false

	# Aplicar movimiento
	move_and_slide()

	# Flash visual
	if is_flashing and mesh_instance:
		flash_timer -= delta
		mesh_instance.material_override.albedo_color = flash_color if flash_timer > 0 else original_color
		is_flashing = flash_timer > 0

# =========================
# PROCESS: armas
# =========================
func _process(delta):
	if current_weapon:
		if Input.is_action_just_pressed("fire"): current_weapon.fire()
		if Input.is_action_just_pressed("weapon_rifle"): current_weapon.switch_weapon(2)
		elif Input.is_action_just_pressed("weapon_sniper"): current_weapon.switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_melee"): current_weapon.switch_weapon(3)

# =========================
# VIDA
# =========================
func take_damage(amount: float):
	health -= amount
	health = max(health,0)
	is_flashing = true
	flash_timer = damage_flash_time
	update_health_bar()

func update_health_bar():
	if hud:
		var bar = hud.get_node_or_null("ProgressBar")
		if bar:
			bar.value = health
