extends Node3D

# =========================
# TIPOS DE ARMA
# =========================
enum WeaponType { SNIPER = 1, RIFLE = 2, MELEE = 3 }

# =========================
# PROPIEDADES
# =========================
@export var weapon_type: WeaponType = WeaponType.RIFLE

var damage: float
var cooldown: float
var max_ammo: int
var current_ammo: int

var can_fire = true
var cooldown_timer = 0.0

# =========================
# ALMACENAMIENTO DE BALAS POR ARMA
# =========================
var ammo_dict = {
	WeaponType.SNIPER: 5,
	WeaponType.RIFLE: 30,
	WeaponType.MELEE: -1
}

# =========================
# REFERENCIAS
# =========================
@onready var raycast = $RayCast3D
@onready var melee_area = $Area3D

@onready var rifle_model = $RifleModel
@onready var sniper_model = $SniperModel
@onready var melee_model = $MeleeModel

@export var muzzle_flash_scene: PackedScene
@export var impact_particles_scene: PackedScene

# =========================
# READY
# =========================
func _ready():
	set_process(true)
	update_weapon()
	print("Weapon listo:", weapon_type, "Ammo:", current_ammo)

# =========================
# PROCESS PARA COOLDOWN
# =========================
func _process(delta):
	# Cambio de arma por teclado
	if Input.is_action_just_pressed("weapon_sniper"):
		switch_weapon(WeaponType.SNIPER)
	elif Input.is_action_just_pressed("weapon_rifle"):
		switch_weapon(WeaponType.RIFLE)
	elif Input.is_action_just_pressed("weapon_melee"):
		switch_weapon(WeaponType.MELEE)

	# Cooldown
	if not can_fire:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_fire = true
			cooldown_timer = 0

# =========================
# FUNCION PRINCIPAL DE DISPARO
# =========================
func fire():
	if not can_fire:
		return
	if weapon_type != WeaponType.MELEE and current_ammo <= 0:
		print("Sin munición")
		return

	can_fire = false
	cooldown_timer = cooldown

	if weapon_type != WeaponType.MELEE:
		current_ammo -= 1
		ammo_dict[weapon_type] = current_ammo

	match weapon_type:
		WeaponType.RIFLE, WeaponType.SNIPER:
			shoot_ray()
		WeaponType.MELEE:
			swing_melee()

# =========================
# FUNCIONES DE DISPARO
# =========================
func shoot_ray():
	# Muzzle flash
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		raycast.add_child(flash)
		flash.global_transform = raycast.global_transform
		flash.one_shot = true
		flash.emitting = true
		flash.queue_free()

	# Raycast
	if raycast.is_colliding():
		var target = raycast.get_collider()
		var impact_pos = raycast.get_collision_point()
		
		# Impact particles
		if impact_particles_scene:
			var impact = impact_particles_scene.instantiate()
			get_tree().current_scene.add_child(impact)
			impact.global_transform.origin = impact_pos
			impact.one_shot = true
			impact.emitting = true
			impact.queue_free()
		
		if target.has_method("take_damage"):
			target.take_damage(damage)
	else:
		print("No colisiona con nada")

func swing_melee():
	for body in melee_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

# =========================
# CAMBIO DE ARMA
# =========================
func switch_weapon(new_type: int):
	if weapon_type == new_type:
		return
	# Guardar munición actual
	if weapon_type != WeaponType.MELEE:
		ammo_dict[weapon_type] = current_ammo

	# Cambiar arma
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

	# Restaurar munición guardada
	if weapon_type != WeaponType.MELEE:
		current_ammo = ammo_dict[weapon_type]
	else:
		current_ammo = -1

	# Actualizar modelos
	rifle_model.visible = weapon_type == WeaponType.RIFLE
	sniper_model.visible = weapon_type == WeaponType.SNIPER
	melee_model.visible = weapon_type == WeaponType.MELEE
