extends Line2D
class_name Hook

signal finished_hooking
const hook_speed := 800

@onready var hook_end: Marker2D = $HookEnd # Marker use to identify where is the line supposed to end.
@onready var ray_cast: RayCast2D = $RayCast # Reference to the raycast

var target: HookablePointBase = null #Hook point detected.
var target_pos = Vector2.ZERO

#STATES
var reachable = true #Is the point inside the hook range?
var reached_hook: bool = false #Has the hook reached a hookable target?

var climb_ended: bool = false #Has the hook finished climbing to the point?

func _ready():
	width = 3  # Set line width to 1 pixel
	antialiased = false  # Disable anti-aliasing

func shoot_towards(target_position: Vector2, hook_range: float):
	target_pos = target_position  # Assign the hookable point
	var tween: Tween = get_tree().create_tween()
	var distance := global_position.distance_to(target_pos)
	
	if distance > hook_range:
		var diff_vector = target_pos - global_position
		target_pos = global_position + diff_vector.limit_length(hook_range)
		reachable = false
	
	#Use raycast to see if target is available
	ray_cast.target_position = target_pos - global_position
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		check_raycast_collision(ray_cast.get_collider())
	var travel_time = distance / hook_speed
	tween.tween_method(tweener_method, global_position, target_pos, travel_time)
	tween.tween_callback(hook_callback)
	var direction = target_pos - hook_end.global_position
	hook_end.rotation = direction.angle()

#Checks if the raycast collided with a Hookable point
func check_raycast_collision(area: Area2D):
	if area.get_parent() is HookablePointBase:  # Replace `HookablePoint` with your specific class
		target = area.get_parent()
		if target is FallHookablePoint:
			target.on_fallen_hooked()  # Signal the point to start falling
			target.attached_hook = self
			target.attached_player = self.get_parent()  # Attach the player to the falling point
		target_pos = target.global_position
		reached_hook = true
		reachable = true
	else:
		reached_hook = false

func tweener_method(pos: Vector2):
	hook_end.global_position = pos
	set_point_position(1, hook_end.position)

func _process(_delta):
	if target != null and is_instance_valid(target):
		# Check if the target is a FallHookablePoint
		# TIP: Move hookable logic into methods inside the different hooks to avoid making too many if statements
		# Example: target.hook_logic()
		if target is FallHookablePoint:
			falling_hook_func(_delta)
		elif target is HookablePoint:
			normal_hook_func()
	else:
		# Fallback for when no valid target exists
		if reached_hook:
			hook_end.global_position = target_pos
	# Update the visual position of the hook
	set_point_position(1, hook_end.position)

func falling_hook_func(_delta):
	var rope_length = global_position.distance_to(hook_end.global_position)  # Calculate the rope length
	if rope_length > get_parent().hook_range:  # Check if the rope length exceeds the defined range
		detach_hook(_delta)  # Detach if the range is exceeded
		return
	hook_end.global_position = target.global_position

func normal_hook_func():
	hook_end.global_position = target_pos

func hook_callback():
	var climbing = Input.is_action_pressed("hook")
	var hook_dir = (get_point_position(1) - get_point_position(0)).normalized()
	var hook_length = abs(get_point_position(0).distance_to(get_point_position(1)))
	if target != null:  # Only pull the player if a valid hookable point is detected
		if target is FallHookablePoint:
			finished_hooking.emit(true, hook_dir, hook_length, climbing)
		else:
			finished_hooking.emit(reached_hook, hook_dir, hook_length, climbing)
	else:
		finished_hooking.emit(reached_hook, hook_dir, hook_length, false)

func detach_hook(_delta):
	target = null  # Clear the target
	reachable = false  # Mark the hook as unreachable
	reached_hook = false  # Mark the hook as not reached
	climb_ended = true  # End any climbing process
	hook_end.global_position = global_position  # Reset hook to the player
	set_process(false)  # Stop processing the hook mechanics
	# Reset player's state to normal
	#hook_retract()
	if get_parent() is Player:
		var player = get_parent()
		player.current_state = Player.STATES.NORMAL
		player.velocity.y += player.gravity * _delta  # Apply gravity to ensure falling


func hook_retract():
	var player = get_parent()  # Get the parent player
	var target_position = player.global_position  # Target position is the player's current position
	# Start the tween to gradually move hook_end to the player's position
	var tween = get_tree().create_tween()
	tween.tween_property(hook_end, "global_position", target_position, 0.5)
	# Optionally, you can set an event when the tween finishes
	tween.connect("tween_completed", Callable(self, "_on_hook_retract_completed"))
