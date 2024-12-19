extends HookablePointBase
class_name FallHookablePoint

@export var fall_speed: float = 975.0
@export var fall_delay: float = 0.35  # Delay before the fall starts
@export var fall_acceleration: float = 50  # Rate of acceleration

var is_falling: bool = false
var velocity: Vector2 = Vector2.ZERO
var attached_player: Player = null
var attached_hook: Hook = null
var target: HookablePointBase = null
var timer: Timer  # Timer node reference
var target_pos: Vector2
var climb_ended: bool = false
var reached_hook: bool = false
var has_fallen: bool = false  # Track if the fall has occurred
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")



signal hooked
signal detached

func _ready():
	# Create and configure the timer
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = fall_delay  # Set the delay time
	timer.one_shot = true  # Ensure the timer only runs once
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	add_to_group("hookable")



func get_distance():
	return get_global_mouse_position().distance_to(global_position)

func _physics_process(_delta):
	if is_falling:
		# Handle the falling logic
		velocity.y = velocity.y * 1.038 + fall_acceleration * _delta
		velocity.y = min(velocity.y, fall_speed)
		position += velocity * _delta  # Update position
		var tween = create_tween()
		tween.tween_property($Rock, "rotation", deg_to_rad(360), 30)
		# Example: Stop falling after reaching the ground or boundaries
		if attached_hook != null and is_instance_valid(attached_hook):
			attached_hook.hook_end.global_position = global_position

func on_hooked():
	# Triggered when the player hooks onto this point
	if !has_fallen:
		timer.start()  # Start the fall delay timer
		has_fallen = true  # Mark that the fall has started at least once
	emit_signal("hooked")  # Emit the hooked signal to notify other systems

func _on_timer_timeout():
	is_falling = true
