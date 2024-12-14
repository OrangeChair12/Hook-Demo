extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	Global.hook_range_updated.connect(on_hook_range_updated)
	
func on_hook_range_updated(new_range: float):
	text = "Hook Range: " +  str(new_range)
