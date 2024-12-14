extends ProgressBar


# Called when the node enters the scene tree for the first time.
func _ready():
	Global.health_updated.connect(_on_health_changed)


func _on_health_changed(hp: int):
	value = hp
