class_name Player
extends CharacterBody2D

@export var health_gained_per_heal: int = 5
@export var range_lost_per_heal: int = 20
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
enum STATES {NORMAL, HOOK, CLIMBING}
var current_state: STATES = STATES.NORMAL
var hook: Hook = null
var hook_range = 500
var hook_scene = preload("res://Components/Components/Hook/hook.tscn")
var health: int = 50
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_move = false

@onready var anim = get_node("AnimationPlayer")
@onready var ready_timer = $ReadyTimer

func _ready():
	Global.player = self
	if ready_timer == null:  # Ensures the timer is initialized
		ready_timer = $ReadyTimer
	ready_timer.connect("timeout", Callable(self, "_on_ready_timer_timeout"))

func _physics_process(delta):
	match current_state:
		STATES.NORMAL:
			normal_state(delta)
		STATES.HOOK:
			hooking_state(delta)
		STATES.CLIMBING:
			climbing_state(delta)

func normal_state(_delta):
	if not is_on_floor():
		velocity.y += gravity * _delta
	# Handle jump.
	if Input.is_action_just_pressed("healup"):
		health += health_gained_per_heal
		hook_range -= range_lost_per_heal
		Global.health_updated.emit(health)
		Global.hook_range_updated.emit(hook_range)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		anim.play("Jump_R")
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("left", "right")
	if direction == -1:
		get_node("AnimatedSprite2D").flip_h = true
	elif direction == 1: 
		get_node("AnimatedSprite2D").flip_h = false
	if direction != 0:
		velocity.x = direction * SPEED
		if velocity.y == 0 and anim.current_animation not in ["Running_R", "Ready_R"]:
			if ready_timer.is_stopped():
				if velocity.y == 0:
					anim.play("Ready_R")
					ready_timer.start(0.18)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if anim.current_animation != "Idle_R" and ready_timer.is_stopped():
				if velocity.y == 0:
					anim.play("Idle_R")
	move_and_slide()
	if Input.is_action_just_pressed("hook"):
		launch_hook()

func _on_ready_timer_timeout():
	if velocity.x != 0:
		anim.play("Running_R")
		ready_timer.stop()

func hooking_state(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = 0
	move_and_slide()

func climbing_state(_delta):
	if hook.climb_ended:
		velocity = Vector2.ZERO
	#While holding move towards goal if reached stopped, if released go to normal state 
	if Input.is_action_just_released("hook"):
		current_state = STATES.NORMAL
		hook.queue_free()
	move_and_slide()


func launch_hook():
	if !Global.selected_hook: return
	hook = hook_scene.instantiate()
	add_child(hook)
	hook.shoot_towards(get_global_mouse_position(), hook_range)
	hook.finished_hooking.connect(_on_hooking_finished)
	current_state = STATES.HOOK

func _on_hooking_finished(reached: bool, direction: Vector2, length: float, is_climbing: bool):
	if !reached:
		hook.queue_free()
		current_state = STATES.NORMAL
		return
	# Handle FallHookablePoint special case
	if reached and Global.selected_hook is FallHookablePoint:
		# Only start the fall if it hasn't started yet
		if not Global.selected_hook.has_fallen:
			Global.selected_hook.on_hooked()  # Signal the point to start falling
			Global.selected_hook.attached_hook = hook
			Global.selected_hook.attached_player = self  # Attach the player to the falling point
	# Handle climbing state (if applicable)
	if is_climbing:
		current_state = STATES.CLIMBING
		velocity = direction * SPEED * 2.3
	else:
		# For non-climbing, launch player towards hook's direction
		hook.queue_free()
		var launch_power = min(SPEED * (length / 10), 100)
		velocity = direction * launch_power
