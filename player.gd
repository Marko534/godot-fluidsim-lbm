extends CharacterBody3D

@export var mouse_y_inversion: float = -1.0

@onready var _camera_yaw: Node3D = self
@onready var _camera_pitch: Node3D = $Camera3D
@onready var spotlight_node: SpotLight3D = $Camera3D/SpotLight3D

@export var SPEED_WALK = 3.0      # Horizontal movement speed (units/second)
var SPEED_SPRINT = SPEED_WALK * 2.0       # Sprint speed (units/second)

const CAMERA_MAX_PITCH: float = deg_to_rad(70)
const CAMERA_MIN_PITCH: float = deg_to_rad(-89.9)
const CAMERA_RATIO: float = .625

# Variables for "game feel" techniques (we'll initialize them later)
var sprint = false
var coyote_timer = 0.0
const COYOTE_TIME_THRESHOLD = 0.1 # 100 milliseconds of coyote time

var mouse_sensitivity = 0.002

# Headbob variables (like flashlight shake)
@export var headbob_enabled: bool = true
@export var headbob_freq: float = 2.0
@export var headbob_amp: float = 0.04
var headbob_time := 0.0
var current_headbob_offset: Vector3 = Vector3.ZERO
var headbob_was_moving_last_frame: bool = false
var foot_sound := true
var foot_land := true

# Flashlight shaking variables
@export var light_shake_enabled: bool = true
@export var light_shake_intensity: float = 0.15  # Much stronger than headbob
@export var light_shake_freq: float = 3.0  # Different frequency from headbob
var light_shake_time := 0.0
var light_original_pos: Vector3
var current_shake_offset: Vector3 = Vector3.ZERO  # Store current shake position
var light_was_moving_last_frame: bool = false  # Track movement state

# Random blinking variables
@export var blinking_enabled: bool = true
@export var min_blink_interval: float = 2.0  # Minimum time between blinks (seconds)
@export var max_blink_interval: float = 8.0  # Maximum time between blinks (seconds)
@export var blink_duration: float = 0.1  # How long each blink lasts (seconds)
var blink_timer: float = 0.0
var next_blink_time: float = 0.0
var is_blinking: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize flashlight
	if spotlight_node:
		light_original_pos = spotlight_node.position
		# Ensure flashlight is initially enabled
		spotlight_node.visible = true
		# Set up first random blink time
		next_blink_time = randf_range(min_blink_interval, max_blink_interval)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var current_max_speed = SPEED_WALK
	# Handle sprint.
	if Input.is_action_just_pressed("sprint"):
		sprint = true
		current_max_speed = SPEED_SPRINT
	elif Input.is_action_just_released("sprint"):
		sprint = false
		current_max_speed = SPEED_WALK
	elif sprint:
		current_max_speed = SPEED_SPRINT
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calculate movement speed based on input magnitude
	var input_magnitude: float = input_dir.length()
	# Prevent diagonal speed boost by capping at 1.0
	var speed_factor: float = min(input_magnitude, 1.0)
	var target_speed: float = speed_factor * current_max_speed
	
	# Calculate acceleration/deceleration rates
	var acceleration_rate: float = delta * input_magnitude * 10.0
	var deceleration_rate: float = delta * SPEED_SPRINT * 2.0

	if move_direction and input_magnitude > 0:
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, acceleration_rate)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, acceleration_rate)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration_rate)
		velocity.z = move_toward(velocity.z, 0, deceleration_rate)
	
	# Handle random blinking
	if blinking_enabled:
		update_blinking(delta)
	
	# Check if we're moving
	var is_moving = velocity.length() > 0.1
	
	# Handle headbob (like flashlight shake)
	if headbob_enabled and is_on_floor():
		if is_moving:
			# Continue headbob animation when moving
			headbob_time += delta * velocity.length() * headbob_freq
			current_headbob_offset = calculate_headbob_offset()
			headbob_was_moving_last_frame = true
			
			# Footstep sound logic (from second code)
			var foot_tresh = -headbob_amp + .002
			if current_headbob_offset.y > foot_tresh:
				foot_sound = true
			elif current_headbob_offset.y < foot_tresh and foot_sound:
				foot_sound = false
				# You would play footstep audio here
				# %FootAudio3D.play()
		else:
			# When stopping, keep current offset but don't update headbob_time
			if headbob_was_moving_last_frame:
				# Just stopped moving - keep current offset
				headbob_was_moving_last_frame = false
			# else: already stopped, do nothing (keep current offset)
		
		# Apply headbob offset to camera pitch
		_camera_pitch.position = current_headbob_offset
	else:
		# Reset headbob when not on floor or disabled
		_camera_pitch.position = Vector3.ZERO
		current_headbob_offset = Vector3.ZERO
		headbob_was_moving_last_frame = false
	
	# Handle flashlight shake - always update position, but only update shake offset when moving
	if light_shake_enabled and spotlight_node and spotlight_node.visible and (not is_blinking):
		if is_moving:
			# Continue shake animation when moving
			light_shake_time += delta * light_shake_freq
			current_shake_offset = calculate_shake_offset()
			light_was_moving_last_frame = true
		else:
			# When stopping, keep current offset but don't update shake_time
			if light_was_moving_last_frame:
				# Just stopped moving - keep current offset
				light_was_moving_last_frame = false
		
		# Always apply the current shake offset (whether moving or stopped)
		spotlight_node.position = light_original_pos + current_shake_offset
	elif spotlight_node and not is_blinking:
		# Reset to original position if shake is disabled or flashlight is off
		spotlight_node.position = light_original_pos
		current_shake_offset = Vector3.ZERO
		light_was_moving_last_frame = false
	
	# Foot landing audio (from second code)
	if not foot_land and is_on_floor(): # Landed
		# %FootAudio3D.play()
		pass
	elif foot_land and not is_on_floor(): # Jumped 
		# %FootAudio3D.play()
		pass
	foot_land = is_on_floor()
	
	# Debug print
	print("Target Speed: %.2f\t Current Velocity: %.2f\t Moving: %s" % [
		target_speed,
		velocity.length(),
		is_moving
	])
	
	move_and_slide()

# Calculate headbob offset based on current headbob time
func calculate_headbob_offset() -> Vector3:
	var headbob_pos = Vector3.ZERO
	
	# Headbob pattern from second code
	headbob_pos.y = sin(headbob_time * headbob_freq) * headbob_amp
	headbob_pos.x = cos(headbob_time * headbob_freq / 2) * headbob_amp
	
	return headbob_pos

# Calculate shake offset based on current shake time
func calculate_shake_offset() -> Vector3:
	var shake_pos = Vector3.ZERO
	
	# Different patterns for more chaotic shake
	shake_pos.x = sin(light_shake_time * 1.3) * light_shake_intensity
	shake_pos.y = cos(light_shake_time * 1.7) * light_shake_intensity * 0.8
	shake_pos.z = sin(light_shake_time * 2.1) * light_shake_intensity * 0.6
	
	return shake_pos

# Handle random blinking
func update_blinking(delta: float):
	if not spotlight_node:
		return
	
	if not is_blinking:
		# Count down to next blink
		blink_timer += delta
		
		if blink_timer >= next_blink_time:
			# Start blinking
			is_blinking = true
			blink_timer = 0
			spotlight_node.visible = false
			
			# Schedule blink to turn back on
			var blink_tween = create_tween()
			blink_tween.tween_callback(func():
				if spotlight_node and is_blinking:
					spotlight_node.visible = true
			).set_delay(blink_duration)
			
			# Schedule blink to end
			blink_tween.tween_callback(func():
				if spotlight_node:
					is_blinking = false
					blink_timer = 0
					# Set next random blink time
					next_blink_time = randf_range(min_blink_interval, max_blink_interval)
			).set_delay(blink_duration)
	else:
		# Currently blinking, do nothing
		pass

# Toggle flashlight function
func toggle_flashlight():
	if spotlight_node:
		spotlight_node.visible = not spotlight_node.visible
		# Reset shake when toggling
		if spotlight_node.visible:
			current_shake_offset = Vector3.ZERO
			light_shake_time = 0.0

func _input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(p_event.relative)
		get_viewport().set_input_as_handled()
		return
	
	# Handle flashlight controls
	if p_event is InputEventKey and p_event.pressed:
		if p_event.keycode == KEY_F:  # Toggle flashlight with F key
			toggle_flashlight()
		elif p_event.keycode == KEY_B:  # Toggle blinking with B key (optional)
			blinking_enabled = not blinking_enabled

func rotate_camera(p_relative:Vector2) -> void:
	_camera_yaw.rotation.y -= p_relative.x * mouse_sensitivity
	_camera_yaw.orthonormalize()
	_camera_pitch.rotation.x += p_relative.y * mouse_sensitivity * CAMERA_RATIO * mouse_y_inversion 
	_camera_pitch.rotation.x = clamp(_camera_pitch.rotation.x, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

# Start/stop light shake functions (can be called from other scripts)
func start_light_shake():
	light_shake_enabled = true

func stop_light_shake():
	light_shake_enabled = false
	# Reset to original position when stopping shake
	if spotlight_node:
		spotlight_node.position = light_original_pos
	current_shake_offset = Vector3.ZERO

# Toggle headbob function
func toggle_headbob():
	headbob_enabled = not headbob_enabled
	if not headbob_enabled:
		_camera_pitch.position = Vector3.ZERO
		current_headbob_offset = Vector3.ZERO

# Toggle blinking function (optional)
func toggle_blinking():
	blinking_enabled = not blinking_enabled
