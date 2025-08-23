extends Node3D

# =========================
# TIPOS DE ARMA
# =========================
enum WeaponType { RIFLE, SNIPER, MELEE }

@export var weapon_type: WeaponType = WeaponType.RIFLE

# =========================
# PROPIEDADES
# =========================
var damage: float
var cooldown: float
var max_ammo: int
var current_ammo: int

# =========================
# CONTROL DE DISPARO
# =========================
var can_fire = true
var cooldown_timer = 0.0

# =========================
# REFERENCIAS
# =========================
@onready var raycast = $RayCast3D
@onready var melee_area = $Area3D

# =========================
# READY
# =========================
func _ready():
	set_process(true)        # Procesar _process desde el inicio
	update_stats()
	print("Weapon listo:", weapon_type, "Ammo:", current_ammo)

func update_stats():
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
			max_ammo = -1  # infinito

	current_ammo = max_ammo
	can_fire = true
	cooldown_timer = 0

# =========================
# PROCESS PARA COOLDOWN
# =========================
func _process(delta):
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
		print("En cooldown")
		return
	if weapon_type != WeaponType.MELEE and current_ammo <= 0:
		print("Sin munición")
		return

	can_fire = false
	cooldown_timer = cooldown

	if weapon_type != WeaponType.MELEE:
		current_ammo -= 1

	print("Disparando! Ammo restante:", current_ammo)

	match weapon_type:
		WeaponType.RIFLE, WeaponType.SNIPER:
			shoot_ray()
		WeaponType.MELEE:
			swing_melee()

# =========================
# FUNCIONES DE DISPARO
# =========================
func shoot_ray():
	if raycast.is_colliding():
		var target = raycast.get_collider()
		print("Colisión con:", target.name)
		if target.has_method("take_damage"):
			target.take_damage(damage)
	else:
		print("No colisiona con nada")

func swing_melee():
	for body in melee_area.get_overlapping_bodies():
		print("Melee colisión con:", body.name)
		if body.has_method("take_damage"):
			body.take_damage(damage)
