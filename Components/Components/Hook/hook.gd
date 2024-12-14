extends Line2D
class_name Hook

signal finished_hooking
const hook_speed := 2250

@onready var hook_end: Marker2D = $HookEnd
var target: HookablePointBase = null
var target_pos = Vector2.ZERO
var reachable = true
var reached_hook: bool = false
var climb_ended: bool = false

func shoot_towards(hookable: HookablePointBase, hook_range: float):
	target = hookable  # Assign the hookable point
	target_pos = hookable.global_position
	var tween: Tween = get_tree().create_tween()
	var distance := global_position.distance_to(target_pos)
	if distance > hook_range:
		var diff_vector = target_pos - global_position
		target_pos = global_position + diff_vector.limit_length(hook_range)
		reachable = false
	tween.tween_property(hook_end, 'global_position', target_pos, distance / hook_speed)
	tween.tween_callback(hook_callback)

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
	finished_hooking.emit(reachable, hook_dir, hook_length, climbing)
