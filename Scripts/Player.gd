extends CharacterBody3D

# ====== HUD ======
@onready var hud = get_tree().current_scene.get_node("HUD")  # Ajusta si tu HUD no está en la raíz

@onready var current_weapon : Node = $Weapon  # referencia al Weapon que el jugador tiene

func _process(delta):
	if Input.is_action_just_pressed("fire"):
		current_weapon.fire()

# ====== Configuración de movimiento ======
var walk_speed = 3.5
var run_speed = 7.0
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# ====== Dash ======
var dash_speed = 20.0
var dash_time = 0.2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = Vector3.ZERO

# ====== Crouch / Slide ======
var is_crouching = false
var is_sliding = false
var crouch_height = 1.0
var stand_height = 2.0
var slide_speed = 15.0
var slide_time = 0.4
var slide_timer = 0.0
var slide_direction = Vector3.ZERO

# ====== Saltos ======
var can_double_jump = true

# ====== Vida / daño por inactividad ======
var max_health = 100
var health = max_health
var idle_damage_per_second = 5.0
var idle_timer = 0.0
var idle_threshold = 2.0  # segundos para empezar daño por AFK

# ====== Feedback visual ======
@onready var mesh_instance = $MeshInstance3D
var damage_flash_time = 0.2
var flash_timer = 0.0
var is_flashing = false
var flash_color = Color(1,0,0)
var original_color = Color(1,1,1)

# ====== Referencias ======
@onready var camera_pivot = $CameraPivot

func _ready():
	# Asegurar que el MeshInstance3D tenga material_override
	if not mesh_instance.material_override:
		var mat = StandardMaterial3D.new()
		mesh_instance.material_override = mat
	
	update_health_bar()  # Inicializa la barra de vida

func _physics_process(delta):
	var input_dir = Vector3.ZERO

	# ====== Movimiento input ======
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	# ====== Daño por inactividad (AFK) ======
	if input_dir == Vector3.ZERO:
		idle_timer += delta
		if idle_timer >= idle_threshold:
			health -= idle_damage_per_second * delta
			health = max(health, 1)
			is_flashing = true
			flash_timer = damage_flash_time
			update_health_bar()
	else:
		idle_timer = 0

	# ====== Dash ======
	if Input.is_action_just_pressed("dash") and not is_dashing and input_dir != Vector3.ZERO:
		is_dashing = true
		dash_timer = dash_time
		var cam_forward = camera_pivot.global_transform.basis.z
		var cam_right = camera_pivot.global_transform.basis.x
		dash_direction = (cam_forward * input_dir.z + cam_right * input_dir.x).normalized()

	if is_dashing:
		velocity = dash_direction * dash_speed
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	else:
		# ====== Crouch / Slide ======
		if Input.is_action_pressed("crouch"):
			if Input.is_action_pressed("run") and input_dir != Vector3.ZERO and not is_sliding:
				is_sliding = true
				slide_timer = slide_time
				var cam_forward = camera_pivot.global_transform.basis.z
				var cam_right = camera_pivot.global_transform.basis.x
				slide_direction = (cam_forward * input_dir.z + cam_right * input_dir.x).normalized()
				$CollisionShape3D.shape.height = crouch_height
				is_crouching = false
			elif not is_sliding:
				$CollisionShape3D.shape.height = crouch_height
				is_crouching = true
		else:
			if not is_sliding:
				$CollisionShape3D.shape.height = stand_height
				is_crouching = false

		# ====== Aplicar slide ======
		if is_sliding:
			velocity = slide_direction * slide_speed
			slide_timer -= delta
			if slide_timer <= 0:
				is_sliding = false
				$CollisionShape3D.shape.height = stand_height
		else:
			# ====== Movimiento normal ======
			if input_dir != Vector3.ZERO:
				var cam_forward = camera_pivot.global_transform.basis.z
				var cam_right = camera_pivot.global_transform.basis.x
				var move_dir = (cam_forward * input_dir.z + cam_right * input_dir.x).normalized()
				var speed = run_speed if Input.is_action_pressed("run") else walk_speed
				velocity.x = move_dir.x * speed
				velocity.z = move_dir.z * speed
			else:
				velocity.x = 0
				velocity.z = 0

	# ====== Gravedad ======
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# ====== Saltos ======
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			can_double_jump = true
		elif can_double_jump:
			velocity.y = jump_velocity
			can_double_jump = false

	# ====== Aplicar movimiento ======
	move_and_slide()

	# ====== Rotar Player según cámara ======
	var target_rotation = rotation
	target_rotation.y = camera_pivot.global_rotation.y
	rotation = target_rotation

	# ====== Parpadeo visual ======
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			mesh_instance.material_override.albedo_color = original_color
		else:
			mesh_instance.material_override.albedo_color = flash_color

# ====== Función para recibir daño desde enemigos ======
func take_damage(amount: float):
	health -= amount
	health = max(health, 0)
	is_flashing = true
	flash_timer = damage_flash_time
	update_health_bar()

# ====== Actualizar barra de vida ======
func update_health_bar():
	if hud:
		var bar = hud.get_node("ProgressBar")  # Nodo hijo ProgressBar
		bar.value = health
