extends Node

# =========================
# Skins disponibles
# =========================
var player_models: Array[String] = [
	"res://scenes/Player/PlayerBase.tscn",  # Skin base
	"res://scenes/player/skins/PlayerSkin1.tscn",
	# "res://scenes/player/skins/PlayerSkin2.tscn",
	# "res://scenes/player/skins/PlayerSkin3.tscn"
]

# =========================
# Skin seleccionada por el jugador local
# =========================
var selected_skin_index: int = 0

# =========================
# Datos personalizados por skin
# =========================
var skin_sounds: Array[Dictionary] = [
	{
		"hitmarker": "res://sounds/skin_base/hitmarker.wav",
		"killmarker": "res://sounds/skin_base/killmarker.wav",
		"footsteps": "res://sounds/skin_base/footsteps.wav",
		"jump": "res://sounds/skin_base/jump.wav"
	},
	{
		"hitmarker": "res://sounds/skins/skin1/hitmarker.wav",
		"killmarker": "res://sounds/skins/skin1/killmarker.wav",
		"footsteps": "res://sounds/skins/skin1/footsteps.wav",
		"jump": "res://sounds/skins/skin1/jump.wav"
	}
	# Se pueden agregar más skins aquí
]

# =========================
# Opciones para HUD personalizadas por skin
# =========================
var hud_overrides: Array[Dictionary] = [
	{
		# Ejemplo: color de vida, crosshair, iconos, etc.
		"crosshair_color": Color(1,1,1),
		"health_bar_color": Color(1,0,0),
		"ammo_icon": "res://hud/base_ammo_icon.png"
	},
	{
		"crosshair_color": Color(0,1,0),
		"health_bar_color": Color(0,0.8,1),
		"ammo_icon": "res://hud/skin1_ammo_icon.png"
	}
	# Se pueden agregar más skins aquí
]

# =========================
# Funciones auxiliares
# =========================
func get_selected_skin_path() -> String:
	if selected_skin_index >= 0 and selected_skin_index < player_models.size():
		return player_models[selected_skin_index]
	return player_models[0]

func get_skin_path(index: int) -> String:
	if index >= 0 and index < player_models.size():
		return player_models[index]
	return player_models[0]

func get_skin_sounds(index: int) -> Dictionary:
	if index >= 0 and index < skin_sounds.size():
		return skin_sounds[index]
	return skin_sounds[0]

func get_hud_overrides(index: int) -> Dictionary:
	if index >= 0 and index < hud_overrides.size():
		return hud_overrides[index]
	return hud_overrides[0]
