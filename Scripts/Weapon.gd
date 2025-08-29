extends Node3D

# =========================
# TIPOS DE ARMA
# =========================
enum WeaponType { SNIPER = 1, RIFLE = 2, MELEE = 3 }

# =========================
# PROPIEDADES
@export var weapon_type: WeaponType = WeaponType.RIFLE
var damage: float
var cooldown: float
var max_ammo: int
var current_ammo: int
var can_fire = true
var cooldown_timer = 0.0

# =========================
# RECARGA
var is_reloading = false
var reload_time = 2.0
var reload_timer = 0.0

# =========================
# ALMACENAMIENTO DE BALAS POR ARMA
var ammo_dict = {
	WeaponType.SNIPER: 5,
	WeaponType.RIFLE: 30,
	WeaponType.MELEE: -1
}

# =========================
# REFERENCIAS
@onready var raycast: RayCast3D = $RayCast3D
@onready var melee_area: Area3D = $Area3D
@onready var rifle_model: MeshInstance3D = $RifleModel
@onready var sniper_model: MeshInstance3D = $SniperModel
@onready var melee_model: MeshInstance3D = $MeleeModel

@export var muzzle_flash_scene: PackedScene
@export var impact_particles_scene: PackedScene

# Cámara y Player (se asignan en runtime desde PlayerInGame tras spawn)
var camera: Camera3D = null
var player_node: Node = null
var hud: Node = null

# =========================
# PROPIEDAD SNIPER
var is_aiming: bool = false

func set_aiming(value: bool) -> void:
	is_aiming = value

# =========================
# READY
func _ready():
	set_process(true)
	update_weapon()
	current_ammo = max_ammo

# =========================
# PROCESS
func _process(delta):
	if not can_fire:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_fire = true
			cooldown_timer = 0.0

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			current_ammo = max_ammo
			ammo_dict[weapon_type] = current_ammo
			update_hud_ammo()

# =========================
# FUNCION PRINCIPAL DE DISPARO
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

# =========================
# FUNCIONES DE DISPARO
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
	if player_node:
		ray_params.exclude = [player_node]

	var result = space_state.intersect_ray(ray_params)

	# Muzzle flash
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		get_tree().current_scene.add_child(flash)
		flash.global_transform.origin = raycast.global_transform.origin if raycast else from
		flash.one_shot = true
		flash.emitting = true
		flash.queue_free()

	# Impacto
	if result:
		var target = result.collider
		if target != player_node and target.has_method("take_damage"):
			target.take_damage(damage)
			if hud and hud.has_method("show_hitmarker"):
				hud.show_hitmarker()

# =========================
# FUNCION MELEE
func swing_melee():
	for body in melee_area.get_overlapping_bodies():
		if body != player_node and body.has_method("take_damage"):
			body.take_damage(damage)
			if hud and hud.has_method("show_hitmarker"):
				hud.show_hitmarker()

# =========================
# CAMBIO DE ARMA
func switch_weapon(new_type: int):
	if weapon_type == new_type:
		return
	if weapon_type != WeaponType.MELEE:
		ammo_dict[weapon_type] = current_ammo
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

	# Modelos visibles
	if rifle_model: rifle_model.visible = weapon_type == WeaponType.RIFLE
	if sniper_model: sniper_model.visible = weapon_type == WeaponType.SNIPER
	if melee_model: melee_model.visible = weapon_type == WeaponType.MELEE

	update_hud_ammo()
	is_aiming = false  # Reiniciar apuntado al cambiar arma

# =========================
# RECARGA
func start_reload():
	if weapon_type == WeaponType.MELEE or is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time

# =========================
# HUD
func update_hud_ammo():
	if hud:
		var ammo_label = hud.get_node_or_null("AmmoLabel")
		if ammo_label:
			if weapon_type == WeaponType.MELEE:
				ammo_label.text = "-"
			else:
				ammo_label.text = str(current_ammo) + " / " + str(max_ammo)
