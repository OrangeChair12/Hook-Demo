extends HookablePointBase
class_name HookablePoint



func _ready():
	add_to_group("hookable")

func get_distance():
	return get_global_mouse_position().distance_to(global_position)
