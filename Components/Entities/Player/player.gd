class_name Player
extends CharacterBody2D

@export var health_gained_per_heal: int = 5
@export var range_lost_per_heal: int = 20
@export var hook_range = 100
@export var acceleration: float = 1500.0  # How fast the player accelerates
@export var deceleration: float = 1000.0  # How fast the player slows down
@export var max_speed: float = 250.0      # Maximum running speed
@export var attack_deceleration: float = 800.0
@export var attack_slide_duration: float = 0.5
@export var standing_attack_duration: float = 0.12  # Duration for standing attack
const SPEED = 250.0
const JUMP_VELOCITY = -400.0
const STEP_DURATION: float = 0.165
enum STATES {NORMAL, HOOK, CLIMBING}
var jump_buffer_time: float = 0.15  # Adjust this for buffer duration
var jump_buffer_timer: float = 0.0
var coyote_time: float = 0.2
var coyote_timer: float = 0.0
var jump_timer: float = 0.0
var held_time: float = 0.0  # Tracks how long the button is held
var move_hold_timer: float = 0.0
var attack_slide_timer: float = 0.0
var is_standing_attack: bool = false
var standing_attack_timer: float = 0.0
var current_state: STATES = STATES.NORMAL
var hook: Hook = null
var hook_scene = preload("res://Components/Components/Hook/hook.tscn")
var health: int = 50
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var was_on_floor: bool = false
var jump_animation_played = false
var is_attack_sliding: bool = false
var attack_slide_lock: bool = false
var current_animation: String = ""
var animation_locked: bool = false
@onready var anim = get_node("AnimationPlayer")
@onready var ready_timer = $ReadyTimer
@onready var throw_timer = Timer.new()

func _ready():
	#Global.player = self
	if ready_timer == null:  # Ensures the timer is initialized
		ready_timer = $ReadyTimer
	ready_timer.connect("timeout", Callable(self, "_on_ready_timer_timeout"))
	
	throw_timer.one_shot = true
	throw_timer.wait_time = 0.3
	add_child(throw_timer)

func _physics_process(delta):
	match current_state:
		STATES.NORMAL:
			normal_state(delta)
		STATES.HOOK:
			hooking_state(delta)
		STATES.CLIMBING:
			climbing_state(delta)
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	

func normal_state(_delta):
	if animation_locked:
		move_and_slide()
		return 
	# First, handle attack slide state and locks
	if attack_slide_lock:
		velocity.x = move_toward(velocity.x, 0, attack_deceleration * _delta)
		attack_slide_timer -= _delta
		if attack_slide_timer <= 0:
			if abs(velocity.x) < 10:  # When almost stopped
				attack_slide_lock = false
				is_attack_sliding = false
				anim.play("Idle_R")
		move_and_slide()
		return  # Skip all other processing while locked
		
	var mouse_position = get_global_mouse_position()
	get_node("AnimatedSprite2D").flip_h = mouse_position.x < global_position.x

	# Apply gravity when not on the floor
	if not is_on_floor():
		velocity.y += gravity * _delta

	# Only process jumps if not attack sliding
	if !is_attack_sliding:
		if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote_timer > 0):
			velocity.y = JUMP_VELOCITY
			anim.play("Jump_R")
			jump_animation_played = true
			coyote_timer = 0
		

		if Input.is_action_just_pressed("jump"):
			jump_buffer_timer = jump_buffer_time

		if is_on_floor() and !was_on_floor:
			if jump_buffer_timer > 0:
				velocity.y = JUMP_VELOCITY
				jump_buffer_timer = 0
				anim.play("Jump_R")
				jump_animation_played = true

	was_on_floor = is_on_floor()

	# Get the input direction and handle movement/deceleration
	var direction = Input.get_axis("left", "right")
	if direction == -1:
		get_node("AnimatedSprite2D").flip_h = true
	elif direction == 1:
		get_node("AnimatedSprite2D").flip_h = false

	if direction != 0 and !attack_slide_lock:
		move_hold_timer += _delta
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * _delta)
		if move_hold_timer < STEP_DURATION and anim.current_animation != "Step_R":
			anim.play("Step_R")
		elif move_hold_timer >= STEP_DURATION:
			if velocity.y == 0 and anim.current_animation not in ["Running_R", "Ready_R", "Sliding_attack_R"]:
				if ready_timer.is_stopped():
					anim.play("Ready_R")
					ready_timer.start(0.18)
					
		# Check for attack input during running
		if Input.is_action_just_pressed("attack") and abs(velocity.x) > max_speed * 0.5:
			anim.play("Sliding_attack_R")
			is_attack_sliding = true
			attack_slide_lock = true  # Lock other actions
			attack_slide_timer = attack_slide_duration
	else:
		if !attack_slide_lock:  # Only handle normal slide if not attack sliding
			if move_hold_timer >= STEP_DURATION and velocity.x != 0:
				if anim.current_animation != "Slide_R" and anim.current_animation != "Sliding_attack_R" and is_on_floor():
					anim.play("Slide_R")
			else:
				move_hold_timer = 0.0
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
				# Check for standing attack when velocity is near zero
				if abs(velocity.x) < 10 and Input.is_action_just_pressed("attack") and !is_standing_attack:
					anim.play("Attack_standing_R")
					is_standing_attack = true
					standing_attack_timer = standing_attack_duration
				elif is_standing_attack:
					standing_attack_timer -= _delta
					if standing_attack_timer <= 0:
						is_standing_attack = false
						anim.play("Idle_R")
				if velocity.x == 0 and is_on_floor() and !is_standing_attack and !jump_animation_played:
					if anim.current_animation != "Idle_R":
						anim.play("Idle_R")  # Play the body animation



	# Only allow hook if not attack sliding
	if Input.is_action_just_pressed("hook") and !attack_slide_lock:
		launch_hook()

	if is_on_floor():
		coyote_timer = coyote_time
		jump_animation_played = false
	else:
		coyote_timer = max(coyote_timer - _delta, 0)
	
	
	
	move_and_slide()

func _on_ready_timer_timeout():
	if !animation_locked and velocity.x != 0:
		anim.play("Running_R")
		ready_timer.stop()

func hooking_state(delta):
	if is_on_floor():
		if anim.current_animation != "Throw_on_ground_R":
			animation_locked = true
			anim.play("Throw_on_ground_R")
			await anim.animation_finished
			animation_locked = false
			current_state = STATES.CLIMBING
	else:
		if anim.current_animation != "Throw_in_air_R":
			anim.play("Throw_in_air_R")
		velocity.y += gravity * delta
		move_and_slide()

func climbing_state(_delta):
	# Check if the hook exists and is valid
	if !hook or !is_instance_valid(hook) or !hook.target:
		if hook and is_instance_valid(hook) and !hook.is_retracting:
			hook.hook_retract()
		current_state = STATES.NORMAL
		return
	
	# Check if we've reached the hook point
	var distance_to_target = global_position.distance_to(hook.target.global_position)
	if hook.target is HookablePoint and distance_to_target <= 10:  # When close enough to the target
		velocity = Vector2.ZERO  # Stop movement
	
	if Input.is_action_just_released("hook"):
		current_state = STATES.NORMAL
		if hook and is_instance_valid(hook) and !hook.is_retracting:
			hook.hook_retract()
		return
	
	move_and_slide()


func launch_hook():
	if !Global.selected_hook: return
	
	var mouse_position = get_global_mouse_position()
	var distance_to_mouse = global_position.distance_to(mouse_position)
	
	# Check if the mouse position is within hook range
	if distance_to_mouse > hook_range:
		# Limit the hook to the maximum range
		var direction = (mouse_position - global_position).normalized()
		mouse_position = global_position + direction * hook_range
	
	hook = hook_scene.instantiate()
	add_child(hook)
	hook.shoot_towards(mouse_position, hook_range)
	hook.finished_hooking.connect(_on_hooking_finished)
	current_state = STATES.HOOK


func _on_hooking_finished(reached: bool, direction: Vector2, length: float, is_climbing: bool):
	if !reached:
		hook.hook_retract()
		if is_on_floor():
			anim.play("Retract_on_ground_R")  # Then play retract
		else:
			anim.play("Retract_in_air_R")
		current_state = STATES.NORMAL
		#hook.queue_free()
		return
	# Special handling for normal hook points
	var launch_power = min(SPEED * (length / 50), 650)
	if hook.target is HookablePoint and !(hook.target is FallHookablePoint):
		velocity = direction * launch_power
		current_state = STATES.CLIMBING
		return
	# For falling points and other cases, use original behavior
	if is_climbing:
		current_state = STATES.CLIMBING
		velocity = direction * SPEED * 2.3
	else:
		hook.queue_free()
		velocity = direction * launch_power
		current_state = STATES.NORMAL
