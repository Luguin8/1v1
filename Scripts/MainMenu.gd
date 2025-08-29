extends Control

func _on_perfil_pressed():
	var scene = load("res://scenes/ProfileScreen.tscn") as PackedScene
	get_tree().change_scene_to_packed(scene)

func _on_entrenar_pressed():
	var scene = load("res://scenes/test.tscn") as PackedScene
	get_tree().change_scene_to_packed(scene)

func _on_skin_pressed():
	var scene = load("res://scenes/CharacterSelectScreen/CharacterSelectScreen.tscn") as PackedScene
	get_tree().change_scene_to_packed(scene)


func _on_jugar_online_pressed():
	show_message("Próximamente: Jugar online")

func _on_opciones_pressed():
	show_message("Próximamente: Opciones")

func _on_salir_pressed():
	get_tree().quit()

func show_message(text):
	var dialog = ConfirmationDialog.new()
	add_child(dialog)
	dialog.dialog_text = text
	dialog.popup_centered()
