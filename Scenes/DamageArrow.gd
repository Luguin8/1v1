extends TextureRect

var fade_timer = 0.0

func _process(delta):
	if fade_timer > 0:
		fade_timer -= delta
		if fade_timer <= 0:
			hide()
