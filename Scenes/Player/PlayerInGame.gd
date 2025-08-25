extends CharacterBody3D

# =========================
# ARMA / WEAPON LOGIC
# =========================

enum WeaponType { SNIPER = 1, RIFLE = 2, MELEE = 3 }

# Propiedades
@export var weapon_type: WeaponType = WeaponType.RIFLE
var damage: float
var cooldown: float
var max_ammo: int
var current_ammo: int
var can_fire = true
var cooldown_timer = 0.0

# Recarga
var is_reloading = false
var reload_time = 2.0
var reload_timer = 0.0

# Almacenamiento de balas
var ammo_dict = {
	WeaponType.SNIPER: 5,
	WeaponType.RIFLE: 30,
	WeaponType.MELEE: -1
}

# Referencias de armas (visual)
@onready var rifle_model: MeshInstance3D = null
@onready var sniper_model: MeshInstance3D = null
@onready var melee_model: MeshInstance3D = null

@export var muzzle_flash_scene: PackedScene
@export var impact_particles_scene: PackedScene

# Referencias globales
@onready var hud_global = get_tree().current_scene.get_node_or_null("HUD_Global")
var skin_hud: Control = null

@onready var camera: Camera3D = $CameraPivot/Camera3D
var player_node = null

# FOV para apuntado
var aim_fov: float = 70.0
var is_aiming = false

# =========================
# PLAYER LOGIC
# =========================

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

var current_model: Node3D = null
var selected_skin_index: int = 0
var camera_pivot: Node3D = null
var collision_shape: CollisionShape3D = null

# Offset visual del modelo
var visual_offset: Vector3 = Vector3.ZERO

# =========================
# READY
# =========================
func _ready():
	player_node = self

	# Cargar skin index
	var config := ConfigFile.new()
	if config.load("user://player.cfg") == OK:
		selected_skin_index = config.get_value("player", "skin_index", 0)
	else:
		selected_skin_index = 0

	# Debug: listar singletons
	print("Singletons cargados:")
	for name in Engine.get_singleton_list():
		print(name)

	# Intentar aplicar skin usando GameData
	if Engine.has_singleton("GameData"):
		var game_data = Engine.get_singleton("GameData")
		print("GameData encontrado, ruta skin seleccionada:", game_data.get_skin_path(selected_skin_index))
		apply_skin(selected_skin_index)
	else:
		push_warning("GameData NO encontrado, instanciando PlayerBase directo como fallback.")
		var fallback_path = "res://scenes/player/PlayerBase.tscn"
		var resource := load(fallback_path)
		if resource and resource is PackedScene:
			current_model = resource.instantiate() as Node3D
			var holder = $ModelHolder if has_node("ModelHolder") else null
			if holder:
				holder.add_child(current_model)
				current_model.transform.origin = Vector3.ZERO
				mesh_instance = get_mesh_from_model(current_model)
				if mesh_instance and not mesh_instance.material_override:
					mesh_instance.material_override = StandardMaterial3D.new()
		else:
			push_error("No se pudo cargar el fallback PlayerBase en " + fallback_path)

	update_weapon()
	update_health_bar()

	camera_pivot = $CameraPivot
	collision_shape = $CollisionShape3D
	visual_offset = Vector3(0, stand_height/2, 0)

# =========================
# SKINS
# =========================
func apply_skin(index: int) -> void:
	selected_skin_index = index

	if current_model and is_instance_valid(current_model):
		current_model.queue_free()
		current_model = null
	if skin_hud and is_instance_valid(skin_hud):
		skin_hud.queue_free()
		skin_hud = null

	if not Engine.has_singleton("GameData"):
		push_error("GameData autoload no está cargado")
		return
	var game_data = Engine.get_singleton("GameData")
	if index < 0 or index >= game_data.player_models.size():
		push_error("Skin index inválido: %s" % index)
		return

	var path: String = game_data.get_skin_path(index)
	var resource := load(path)
	if resource == null:
		push_error("No se pudo cargar skin en " + str(path))
		return

	if resource is PackedScene:
		current_model = (resource as PackedScene).instantiate() as Node3D
	else:
		push_error("El recurso no es una PackedScene")
		return

	var holder := $ModelHolder if has_node("ModelHolder") else null
	if holder:
		holder.add_child(current_model)
		current_model.transform.origin = Vector3.ZERO
		mesh_instance = get_mesh_from_model(current_model)
		if mesh_instance and not mesh_instance.material_override:
			mesh_instance.material_override = StandardMaterial3D.new()
		if current_model.has_node("HUD_Skin"):
			skin_hud = current_model.get_node("HUD_Skin").duplicate() as Control
			add_child(skin_hud)

	rifle_model = current_model.get_node_or_null("RifleModel")
	sniper_model = current_model.get_node_or_null("SniperModel")
	melee_model = current_model.get_node_or_null("MeleeModel")


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
# PHYSICS PROCESS
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
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_dash_on_cd and input_dir != Vector3.ZERO:
		is_dashing = true
		dash_timer = dash_time
		var forward = transform.basis.z
		var right = transform.basis.x
		dash_direction = (forward * input_dir.z + right * input_dir.x).normalized()
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
				var forward = transform.basis.z
				var right = transform.basis.x
				slide_direction = (forward * input_dir.z + right * input_dir.x).normalized()
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

	move_and_slide()

	# Actualizar posición del modelo visual
	if current_model:
		var pos = current_model.transform.origin
		pos.y = collision_shape.shape.height / 2 + visual_offset.y - stand_height/2
		current_model.transform.origin = pos
	# Reducir cooldowns
	if is_dash_on_cd:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			is_dash_on_cd = false
			dash_cooldown_timer = 0.0
	if is_slide_on_cd:
		slide_cooldown_timer -= delta
		if slide_cooldown_timer <= 0:
			is_slide_on_cd = false
			slide_cooldown_timer = 0.0

# =========================
# PROCESS: armas y flash visual
# =========================
func _process(delta):
	# Flash visual de daño
	if is_flashing and mesh_instance:
		flash_timer -= delta
		mesh_instance.material_override.albedo_color = flash_color if flash_timer > 0 else original_color
		is_flashing = flash_timer > 0

	# Manejar apuntado sniper y crosshair
	if weapon_type == WeaponType.SNIPER:
		is_aiming = Input.is_action_pressed("aim")
	else:
		is_aiming = false

	if skin_hud:
		var crosshair = skin_hud.get_node_or_null("Crosshair")
		var melee_crosshair = skin_hud.get_node_or_null("MeleeCrosshair")
		if crosshair:
			match weapon_type:
				WeaponType.SNIPER:
					crosshair.visible = is_aiming
					if melee_crosshair: melee_crosshair.visible = false
				WeaponType.RIFLE:
					crosshair.visible = true
					if melee_crosshair: melee_crosshair.visible = false
				WeaponType.MELEE:
					crosshair.visible = false
					if melee_crosshair: melee_crosshair.visible = true

	# Manejar fuego y cambio de arma
	if Input.is_action_just_pressed("fire"): fire()
	if Input.is_action_just_pressed("weapon_rifle"): switch_weapon(2)
	elif Input.is_action_just_pressed("weapon_sniper"): switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_melee"): switch_weapon(3)

	# Cooldowns de arma
	if not can_fire:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_fire = true
			cooldown_timer = 0
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			current_ammo = max_ammo
			ammo_dict[weapon_type] = current_ammo
			update_hud_ammo()

# =========================
# FUNCIONES DE ARMA
# =========================

func fire():
	if is_reloading or not can_fire:
		return
	if weapon_type != WeaponType.MELEE and current_ammo <= 0:
		start_reload()
		return

	can_fire = false
	cooldown_timer = cooldown

	if weapon_type != WeaponType.MELEE:
		current_ammo -= 1
		ammo_dict[weapon_type] = current_ammo
		update_hud_ammo()
		if current_ammo <= 0:
			start_reload()

	match weapon_type:
		WeaponType.RIFLE, WeaponType.SNIPER:
			shoot_ray()
		WeaponType.MELEE:
			swing_melee()

func shoot_ray():
	if not camera:
		return

	var viewport = get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2
	var from = camera.project_ray_origin(screen_center)
	var to = from + camera.project_ray_normal(screen_center) * 1000.0

	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = from
	ray_params.to = to
	ray_params.exclude = [player_node]

	var result = space_state.intersect_ray(ray_params)

	# Muzzle flash
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		add_child(flash)
		flash.global_transform.origin = rifle_model.global_transform.origin if rifle_model else from
		flash.one_shot = true
		flash.emitting = true
		flash.queue_free()

	# Aplicar daño
	if result:
		var target = result.collider
		if target != player_node and target.has_method("take_damage"):
			target.take_damage(damage)
			if hud_global and hud_global.has_method("show_hitmarker"):
				hud_global.show_hitmarker()
			if target.health <= 0 and hud_global:
				var attacker_name = name
				var victim_name = target.name
				var weapon_name = weapon_type_to_string(weapon_type)
				hud_global.add_killfeed_message(weapon_name, victim_name, attacker_name)
				if hud_global.has_method("show_killmarker"):
					hud_global.show_killmarker()

func swing_melee():
	for body in melee_model.get_overlapping_bodies() if melee_model else []:
		if body != player_node and body.has_method("take_damage"):
			body.take_damage(damage)
			if hud_global and hud_global.has_method("show_hitmarker"):
				hud_global.show_hitmarker()
			if body.health <= 0 and hud_global:
				var attacker_name = name
				var victim_name = body.name
				var weapon_name = weapon_type_to_string(weapon_type)
				hud_global.add_killfeed_message(weapon_name, victim_name, attacker_name)
				if hud_global.has_method("show_killmarker"):
					hud_global.show_killmarker()

func switch_weapon(new_type: int):
	if weapon_type == new_type:
		return
	if weapon_type != WeaponType.MELEE:
		ammo_dict[weapon_type] = current_ammo
	@warning_ignore("int_as_enum_without_cast")
	weapon_type = new_type
	update_weapon()

func update_weapon():
	match weapon_type:
		WeaponType.RIFLE:
			damage = 35
			cooldown = 0.2
			max_ammo = 30
		WeaponType.SNIPER:
			damage = 100
			cooldown = 1.5
			max_ammo = 5
		WeaponType.MELEE:
			damage = 100
			cooldown = 0.5
			max_ammo = -1

	if weapon_type != WeaponType.MELEE:
		current_ammo = ammo_dict[weapon_type]
	else:
		current_ammo = -1

	if rifle_model: rifle_model.visible = weapon_type == WeaponType.RIFLE
	if sniper_model: sniper_model.visible = weapon_type == WeaponType.SNIPER
	if melee_model: melee_model.visible = weapon_type == WeaponType.MELEE

	update_hud_ammo()

func start_reload():
	is_reloading = true
	reload_timer = reload_time

func update_hud_ammo():
	if skin_hud:
		var ammo_label = skin_hud.get_node_or_null("AmmoLabel")
		if ammo_label:
			if weapon_type == WeaponType.MELEE:
				ammo_label.text = "-"
			else:
				ammo_label.text = str(current_ammo) + " / " + str(max_ammo)

func weapon_type_to_string(type):
	match type:
		WeaponType.RIFLE: return "Rifle"
		WeaponType.SNIPER: return "Sniper"
		WeaponType.MELEE: return "Melee"

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
	if hud_global and hud_global.has_method("update_health_bar"):
		hud_global.update_health_bar(health)
