extends Control

var player_name = "Jugador"

func _ready():
	load_player_name()
	$LineEdit.text = player_name
	$LineEdit.text_changed.connect(_on_name_changed)

func _on_name_changed(new_name):
	player_name = new_name
	save_player_name()

func save_player_name():
	var config = ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.save("user://player.cfg")

func load_player_name():
	var config = ConfigFile.new()
	if config.load("user://player.cfg") == OK:
		player_name = config.get_value("player", "name", "Jugador")

func _on_volver_pressed() -> void:
	var scene = load("res://Scenes/MainMenu.tscn") as PackedScene
	get_tree().change_scene_to_packed(scene)
