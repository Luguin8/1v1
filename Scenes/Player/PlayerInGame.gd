extends CharacterBody3D

# =========================
# TIPOS / REFERENCIAS
# =========================
enum WeaponType { SNIPER = 1, RIFLE = 2, MELEE = 3 }

# HUD global (killfeed)
@onready var hud_global = get_tree().current_scene.get_node_or_null("HUD_Global")

# Cámara
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot

# Nodo de colisión/visual
var collision_shape: CollisionShape3D = null

# =========================
# PLAYER MOVEMENT / ESTADO
var walk_speed = 3.5
var run_speed = 7.0
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var dash_speed = 20.0
var dash_time = 0.2
var is_dashing = false
var dash_timer = 0.0
var dash_direction = Vector3.ZERO
var dash_cooldown = 2.0
var dash_cooldown_timer = 0.0
var is_dash_on_cd = false

var is_crouching = false
var is_sliding = false
var crouch_height = 1.0
var stand_height = 2.0
var slide_speed = 15.0
var slide_time = 0.4
var slide_timer = 0.0
var slide_direction = Vector3.ZERO
var slide_cooldown = 2.0
var slide_cooldown_timer = 0.0
var is_slide_on_cd = false

var can_double_jump = true

var max_health = 100
var health = max_health
var idle_damage_per_second = 5.0
var idle_timer = 0.0
var idle_threshold = 2.0

var damage_flash_time = 0.2
var flash_timer = 0.0
var is_flashing = false
var flash_color = Color(1,0,0)
var original_color = Color(1,1,1)
var mesh_instance: MeshInstance3D = null

# =========================
# SKIN / MODEL / HUD / WEAPON
var current_model: Node3D = null
var selected_skin_index: int = 0
var visual_offset: Vector3 = Vector3.ZERO

var skin_hud: Control = null   # HUD local (barra vida, ammo, crosshair...) - solo jugador local
var weapon: Node = null        # nodo con Weapon.gd
var player_node: Node = null

# Referencias a labels (para evitar buscar cada frame)
var cross: Control = null
var melee_cross: Control = null
var ammo_label: Label = null
var dash_label_ref: Label = null
var slide_label_ref: Label = null
var health_bar: ProgressBar = null

# =========================
# READY
func _ready():
	player_node = self

	# Cargar skin index
	var config := ConfigFile.new()
	if config.load("user://player.cfg") == OK:
		selected_skin_index = config.get_value("player", "skin_index", 0)
	else:
		selected_skin_index = 0

	# Esperar un frame para asegurar jerarquía
	await get_tree().process_frame
	spawn_model()

	# referencias
	collision_shape = $CollisionShape3D
	visual_offset = Vector3(0, stand_height/2, 0)

	# Solo input local si este nodo es controlado por el cliente
	if not _is_local_player():
		set_process_input(false)

# =========================
# SPAWN DEL MODELO Y SETUP
func spawn_model() -> void:
	# Instanciar modelo
	var fallback_path = "res://scenes/player/PlayerBase.tscn"
	var path = fallback_path
	if Engine.has_singleton("GameData"):
		var game_data = Engine.get_singleton("GameData")
		path = game_data.get_skin_path(selected_skin_index)

	var resource = load(path)
	if resource and resource is PackedScene:
		current_model = resource.instantiate() as Node3D
	else:
		push_error("No se pudo cargar la skin: " + str(path))
		return

	var holder = $ModelHolder if has_node("ModelHolder") else self
	holder.add_child(current_model)
	current_model.transform.origin = Vector3.ZERO

	# Obtener mesh_instance para efectos visuales
	mesh_instance = _get_mesh_from_model(current_model)
	if mesh_instance and not mesh_instance.material_override:
		mesh_instance.material_override = StandardMaterial3D.new()

	# Instanciar SkinHUD solo para jugador local
	if _is_local_player():
		if current_model.has_node("HUD_Skin") and current_model.get_node("HUD_Skin").get_child_count() > 0:
			var hud_node = current_model.get_node("HUD_Skin") as Node
			skin_hud = hud_node.duplicate() as Control
			get_tree().current_scene.add_child(skin_hud)
		else:
			var fallback_hud_scene = load("res://scenes/player/DefaultSkinHUD.tscn")
			if fallback_hud_scene:
				skin_hud = fallback_hud_scene.instantiate() as Control
				get_tree().current_scene.add_child(skin_hud)

		# Inicializar referencias a HUD
		if skin_hud:
			cross = skin_hud.get_node_or_null("Crosshair")
			melee_cross = skin_hud.get_node_or_null("MeleeCrosshair")
			ammo_label = skin_hud.get_node_or_null("AmmoLabel")
			dash_label_ref = skin_hud.get_node_or_null("DashLabel")
			slide_label_ref = skin_hud.get_node_or_null("SlideLabel")
			health_bar = skin_hud.get_node_or_null("HealthBar")
			if health_bar:
				health_bar.max_value = max_health
				health_bar.value = health

	# Buscar nodo Weapon
	weapon = _find_weapon_node(current_model)
	if weapon:
		weapon.player_node = self
		weapon.camera = camera
		weapon.hud = skin_hud if _is_local_player() else null
		if weapon.has_method("update_weapon"):
			weapon.update_weapon()
			weapon.update_hud_ammo()

# =========================
# UTILS
func _get_mesh_from_model(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _get_mesh_from_model(child)
		if found:
			return found
	return null

func _find_weapon_node(root: Node) -> Node:
	if not root:
		return null
	if root.has_method("fire"):
		return root
	for child in root.get_children():
		var res = _find_weapon_node(child)
		if res:
			return res
	return null

func _is_local_player() -> bool:
	if not multiplayer:
		return true
	return multiplayer.get_unique_id() == get_multiplayer_authority()

# =========================
# PHYSICS: movimiento, dash, slide, jump
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
			take_damage(idle_damage_per_second * delta)
	else:
		idle_timer = 0

	# Dash
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_dash_on_cd and input_dir != Vector3.ZERO:
		is_dashing = true
		dash_timer = dash_time
		dash_direction = _calculate_move_dir(input_dir)
		is_dash_on_cd = true
		dash_cooldown_timer = dash_cooldown

	if is_dashing:
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	else:
		# Crouch / Slide
		if Input.is_action_pressed("crouch"):
			if Input.is_action_pressed("run") and input_dir != Vector3.ZERO and not is_sliding and not is_slide_on_cd:
				is_sliding = true
				slide_timer = slide_time
				slide_direction = _calculate_move_dir(input_dir)
				if collision_shape: collision_shape.shape.height = crouch_height
				is_crouching = false
				is_slide_on_cd = true
				slide_cooldown_timer = slide_cooldown
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
				var move_dir = _calculate_move_dir(input_dir)
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

	move_and_slide()

	# Actualizar posición del modelo visual
	if current_model:
		var pos = current_model.transform.origin
		pos.y = collision_shape.shape.height / 2 + visual_offset.y - stand_height/2
		current_model.transform.origin = pos

	# Reducir cooldowns dash/slide
	if is_dash_on_cd:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			is_dash_on_cd = false
	if is_slide_on_cd:
		slide_cooldown_timer -= delta
		if slide_cooldown_timer <= 0:
			is_slide_on_cd = false

# =========================
# Apuntado click derecho sniper
func is_aiming() -> bool:
	if weapon:
		#case1: arma tiene el metodo
		if weapon.has_method("is_aiming"):
			return weapon.is_aiming()
		#case2: si el arma solo tiene la propiedad
		elif "is_aiming" in weapon:
			print("Aiming:", weapon.is_aiming)
			return weapon.is_aiming
	return false

# =========================
# PROCESS: visual y HUD
func _process(delta):
	# Flash visual de daño
	if is_flashing and mesh_instance:
		flash_timer -= delta
		mesh_instance.material_override.albedo_color = flash_color if flash_timer > 0 else original_color
		is_flashing = flash_timer > 0

	# Manejar crosshair y ammo
	if _is_local_player() and skin_hud and weapon:
		# Crosshair
		if cross and melee_cross:
			match weapon.weapon_type:
				WeaponType.SNIPER:
					var aiming = weapon.is_aiming if weapon.has_method("is_aiming") else false
					cross.visible = aiming
					melee_cross.visible = false
				WeaponType.RIFLE:
					cross.visible = true
					melee_cross.visible = false
				WeaponType.MELEE:
					cross.visible = false
					melee_cross.visible = true

		# Ammo
		if ammo_label and weapon.has_method("update_hud_ammo"):
			weapon.update_hud_ammo()

	# Inputs de armas solo jugador local
	if _is_local_player():
		if Input.is_action_just_pressed("fire") and weapon and weapon.has_method("fire"):
			weapon.fire()
		if Input.is_action_just_pressed("weapon_rifle") and weapon and weapon.has_method("switch_weapon"):
			weapon.switch_weapon(WeaponType.RIFLE)
		elif Input.is_action_just_pressed("weapon_sniper") and weapon and weapon.has_method("switch_weapon"):
			weapon.switch_weapon(WeaponType.SNIPER)
		elif Input.is_action_just_pressed("weapon_melee") and weapon and weapon.has_method("switch_weapon"):
			weapon.switch_weapon(WeaponType.MELEE)
	# Actualizar estado de apuntado
	if weapon:
		var aiming_input = Input.is_action_pressed("aim")
		weapon.set_aiming(aiming_input)
	# Manejar apuntado SOLO para sniper
	if _is_local_player() and weapon:
		if weapon.weapon_type == WeaponType.SNIPER:
			weapon.set_aiming(Input.is_action_pressed("aim"))
		else:
			weapon.set_aiming(false)

	# Actualizar cooldowns en HUD
	if dash_label_ref:
		dash_label_ref.text = "Dash en CD" if is_dash_on_cd else ""
	if slide_label_ref:
		slide_label_ref.text = "Slide en CD" if is_slide_on_cd else ""

# =========================
# SALUD / HUD
func update_health_bar():
	if health_bar:
		health_bar.value = health

func take_damage(amount: float):
	health -= amount
	health = clamp(health, 0, max_health)
	is_flashing = true
	flash_timer = damage_flash_time
	update_health_bar()

# =========================
# UTIL: calcular dirección de movimiento
func _calculate_move_dir(input_dir: Vector3) -> Vector3:
	var forward = transform.basis.z
	var right = transform.basis.x
	return (forward * input_dir.z + right * input_dir.x).normalized()
