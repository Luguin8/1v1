extends CanvasLayer  # Script del HUD

@onready var killfeed_container = $KillFeedContainer
@export var killfeed_duration := 3.0  # segundos que dura cada mensaje

func add_killfeed_message(attacker_name: String, weapon_name: String, victim_name: String):
	var label = Label.new()
	label.text = "%s [%s] -> %s" % [attacker_name, weapon_name, victim_name]
	killfeed_container.add_child(label)
	
	# Timer para eliminarlo después de unos segundos
	var timer = Timer.new()
	timer.wait_time = killfeed_duration
	timer.one_shot = true
	timer.autostart = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)
