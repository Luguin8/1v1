extends CharacterBody3D

# ====== HUD ======
@onready var hud = get_tree().current_scene.get_node("HUD")

# ====== Weapon / WeaponHolder ======
@onready var weapon_holder = $WeaponHolder
var current_weapon : Node = null  # Apuntará al WeaponHolder completo

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
var damage_flash_time = 0.2
var flash_timer = 0.0
var is_flashing = false
var flash_color = Color(1,0,0)
var original_color = Color(1,1,1)

var mesh_instance: MeshInstance3D = null  # Ahora apunta al MeshInstance3D real del modelo
var current_model: Node3D = null          # Nodo raíz del modelo instanciado

# ====== Referencias ======
@onready var camera_pivot = $CameraPivot

# ====== Skin del player ======
var player_models = [
	"res://assets/models/granjero.glb",
	"res://assets/models/ninja.glb"
]
var selected_skin_index := 0

# ====== READY ======
func _ready():
	# Cargar skin guardada
	load_selected_skin_from_file()

	# Asignar WeaponHolder como current_weapon
	current_weapon = weapon_holder
	if current_weapon:
		current_weapon.update_weapon()
		current_weapon.player_node = self  # Referencia al player

	update_health_bar()

# ====== Función para obtener MeshInstance3D dentro del modelo ======
func get_mesh_from_model(model: Node) -> MeshInstance3D:
	if model is MeshInstance3D:
		return model
	for child in model.get_children():
		var mesh = get_mesh_from_model(child)
		if mesh:
			return mesh
	return null

# ====== Función para cargar skin seleccionada ======
func load_selected_skin(index := -1):
	if index != -1:
		selected_skin_index = index

	# Limpiar modelo anterior
	if current_model and current_model.is_inside_tree():
		current_model.queue_free()
		current_model = null
		mesh_instance = null

	var res = load(player_models[selected_skin_index])
	if not res:
		push_error("Modelo no encontrado: " + str(player_models[selected_skin_index]))
		return

	# Instanciar modelo
	if res is PackedScene:
		current_model = res.instantiate()
	elif res is Node:
		current_model = res.duplicate()
	else:
		push_error("El recurso no es un Node ni un PackedScene: " + str(player_models[selected_skin_index]))
		return

	# Agregar al Player
	add_child(current_model)
	current_model.name = "CurrentModel"

	# Buscar MeshInstance3D dentro del modelo
	mesh_instance = get_mesh_from_model(current_model)
	if mesh_instance:
		if not mesh_instance.material_override:
			var mat = StandardMaterial3D.new()
			mesh_instance.material_override = mat
		mesh_instance.rotation_degrees = Vector3(0,0,0)
		mesh_instance.transform.origin = Vector3(0,0,0)
		mesh_instance.scale = Vector3(1,1,1)
	else:
		push_error("No se encontró MeshInstance3D dentro del modelo de la skin")

# ====== Función para cargar skin guardada ======
func load_selected_skin_from_file():
	var cfg = ConfigFile.new()
	if cfg.load("user://player.cfg") == OK:
		var index = cfg.get_value("player","skin_index",0)
		load_selected_skin(index)
	else:
		load_selected_skin(0)

# ====== PHYSICS PROCESS ======
func _physics_process(delta):
	var input_dir = Vector3.ZERO

	# Movimiento
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	# Daño por inactividad
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

	# Dash
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
		# Crouch / Slide
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

		if is_sliding:
			velocity = slide_direction * slide_speed
			slide_timer -= delta
			if slide_timer <= 0:
				is_sliding = false
				$CollisionShape3D.shape.height = stand_height
		else:
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

	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

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

	# Rotar player según cámara
	var target_rotation = rotation
	target_rotation.y = camera_pivot.global_rotation.y
	rotation = target_rotation

	# Parpadeo visual
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			if mesh_instance:
				mesh_instance.material_override.albedo_color = original_color
		else:
			if mesh_instance:
				mesh_instance.material_override.albedo_color = flash_color

# ====== FUNCION PARA DISPARO Y CAMBIO DE ARMAS ======
func _process(delta):
	if current_weapon:
		if Input.is_action_just_pressed("fire"):
			current_weapon.fire()

	# Cambio de armas usando WeaponHolder
	if Input.is_action_just_pressed("weapon_rifle"):
		current_weapon.switch_weapon(2)
	elif Input.is_action_just_pressed("weapon_sniper"):
		current_weapon.switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_melee"):
		current_weapon.switch_weapon(3)

# ====== VIDA ======
func take_damage(amount: float):
	health -= amount
	health = max(health, 0)
	is_flashing = true
	flash_timer = damage_flash_time
	update_health_bar()

func update_health_bar():
	if hud:
		var bar = hud.get_node("ProgressBar")
		bar.value = health

# ====== FUTURA LOGICA MULTIPLAYER ======
# Comentado por ahora: la idea es sincronizar current_model y selected_skin_index
# en los peers cuando se conecten. Se podría usar RPCs o MultiplayerAPI.
# Ejemplo:
# rpc("sync_skin", selected_skin_index)
# func sync_skin(index):
#     load_selected_skin(index)
