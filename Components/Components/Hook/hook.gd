extends Line2D
class_name Hook

signal finished_hooking
const hook_speed := 2250

@onready var hook_end: Marker2D = $HookEnd
@onready var hook_area: Area2D = $Area2D  # Reference to the Area2D node
var target: HookablePointBase = null
var target_pos = Vector2.ZERO
var reachable = true
var reached_hook: bool = false
var climb_ended: bool = false

func _ready():
	width = 3  # Set line width to 1 pixel
	antialiased = false  # Disable anti-aliasing
	hook_area.connect("area_entered", Callable(self, "_on_area_entered"))  # Connect Area2D signal

func _on_area_entered(area: Area2D):
	if area.get_parent() is HookablePointBase:  # Replace `HookablePoint` with your specific class
		target = area.get_parent()
		target_pos = target.global_position
		reachable = true
	else:
		reachable = false

func shoot_towards(target_position: Vector2, hook_range: float):
	target_pos = target_position  # Assign the hookable point
	var tween: Tween = get_tree().create_tween()
	var distance := global_position.distance_to(target_pos)
	if distance > hook_range:
		var diff_vector = target_pos - global_position
		target_pos = global_position + diff_vector.limit_length(hook_range)
		reachable = false
	tween.tween_method(tweener_method, global_position, target_pos, .2)
	tween.tween_callback(hook_callback)

func tweener_method(pos: Vector2):
	hook_end.global_position = pos
	set_point_position(1, hook_end.position)

func _process(_delta):
	if target != null and is_instance_valid(target):
		# Check if the target is a FallHookablePoint
		if target is FallHookablePoint:
			# Dynamic code for FallHookablePoint
			hook_end.global_position = target.global_position
		elif target is HookablePoint:
			# Static code for HookablePoint
			hook_end.global_position = target_pos
			if global_position.distance_to(target_pos) <= 25:
				climb_ended = true
				set_process(false)
	else:
		# Fallback for when no valid target exists
		if reached_hook:
			hook_end.global_position = target_pos

	# Update the visual position of the hook
	set_point_position(1, hook_end.position)


func hook_callback():
	reached_hook = true
	var climbing = Input.is_action_pressed("hook")
	var hook_dir = (get_point_position(1) - get_point_position(0)).normalized()
	var hook_length = abs(get_point_position(0).distance_to(get_point_position(1)))

	if target != null:  # Only pull the player if a valid hookable point is detected
		finished_hooking.emit(true, hook_dir, hook_length, climbing)
	else:
		finished_hooking.emit(reachable, hook_dir, hook_length, climbing)
