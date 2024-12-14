extends Node2D

var hookable_points: Array = []
var selected_hook = null

# Called when the node enters the scene tree for the first time.
func _ready():
	hookable_points = get_tree().get_nodes_in_group('Hookable')

func _input(event):
	if event is InputEventMouseMotion:
		var shortest_length: float = hookable_points[0].get_distance()
		selected_hook = hookable_points[0]
		
		for hook in hookable_points:
			var distance_to_hook = hook.get_distance()
			
			
			if distance_to_hook < shortest_length:
				selected_hook = hook
	
		Global.selected_hook = selected_hook
