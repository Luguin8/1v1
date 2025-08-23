extends CharacterBody3D

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
var crouch_height = 1.0       # Altura de collider al agacharse
var stand_height = 2.0        # Altura normal del collider
var slide_speed = 15.0
var slide_time = 0.4
var slide_timer = 0.0
var slide_direction = Vector3.ZERO

# ====== Saltos ======
var can_double_jump = true

# ====== Referencia a la cámara ======
@onready var camera_pivot = $CameraPivot

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
				# Inicia slide
				is_sliding = true
				slide_timer = slide_time
				var cam_forward = camera_pivot.global_transform.basis.z
				var cam_right = camera_pivot.global_transform.basis.x
				slide_direction = (cam_forward * input_dir.z + cam_right * input_dir.x).normalized()
				$CollisionShape3D.shape.height = crouch_height
				is_crouching = false
			elif not is_sliding:
				# Solo agacharse
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
			# ====== Movimiento normal relativo a la cámara ======
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
