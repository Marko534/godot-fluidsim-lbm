extends CharacterBody3D

# ============================================================================
# EXPORT VARIABLES - Configurable in the Inspector
# ============================================================================

# Movement Settings
@export_group("Movement")
@export var SPEED_WALK: float = 3.0
@export var SPEED_SPRINT: float = 6.0

# Camera Settings
@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var mouse_y_inversion: float = -1.0
@export var controller_look_enabled: bool = true
@export var controller_look_sensitivity: float = 2.0

# Zoom/Aim Settings
@export_group("Zoom")
@export var zoom_enabled: bool = true
@export var zoom_fov: float = 50.0  # FOV when zoomed in (lower = more zoom)
@export var zoom_speed: float = 10.0  # How fast the zoom transition happens
@export var zoom_mouse_sensitivity_multiplier: float = 0.5  # Reduces sensitivity while aiming

# Headbob Settings
@export_group("Headbob")
@export var headbob_enabled: bool = true
@export var headbob_freq: float = 2.0
@export var headbob_amp: float = 0.04

# Flashlight Shake Settings
@export_group("Flashlight Shake")
@export var light_shake_enabled: bool = true
@export var light_shake_intensity: float = 0.15
@export var light_shake_freq: float = 3.0

# Blinking Settings
@export_group("Flashlight Blinking")
@export var blinking_enabled: bool = true
@export var min_blink_interval: float = 2.0
@export var max_blink_interval: float = 8.0
@export var blink_duration: float = 0.1

# ============================================================================
# CONSTANTS
# ============================================================================

const CAMERA_MAX_PITCH: float = deg_to_rad(70)
const CAMERA_MIN_PITCH: float = deg_to_rad(-89.9)
const CAMERA_RATIO: float = 0.625
const COYOTE_TIME_THRESHOLD: float = 0.1

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var _camera_yaw: Node3D = self
@onready var _camera_pitch: Node3D = $Camera3D
@onready var _camera: Camera3D = $Camera3D
@onready var spotlight_node: SpotLight3D = $Camera3D/SpotLight3D

# ============================================================================
# INTERNAL STATE VARIABLES
# ============================================================================

# Movement State
var sprint: bool = false
var coyote_timer: float = 0.0

# Headbob State
var headbob_time: float = 0.0
var current_headbob_offset: Vector3 = Vector3.ZERO
var headbob_was_moving_last_frame: bool = false

# Footstep Audio State
var foot_sound: bool = true
var foot_land: bool = true

# Flashlight Shake State
var light_shake_time: float = 0.0
var light_original_pos: Vector3
var current_shake_offset: Vector3 = Vector3.ZERO
var light_was_moving_last_frame: bool = false

# Blinking State
var blink_timer: float = 0.0
var next_blink_time: float = 0.0
var is_blinking: bool = false

# Zoom State
var is_aiming: bool = false
var default_fov: float = 75.0
var current_fov: float = 75.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize camera FOV
	if _camera:
		default_fov = _camera.fov
		current_fov = default_fov
	
	# Initialize flashlight
	if spotlight_node:
		light_original_pos = spotlight_node.position
		spotlight_node.visible = true
		next_blink_time = randf_range(min_blink_interval, max_blink_interval)

# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_sprint()
	_handle_zoom(delta)
	_handle_movement(delta)
	_handle_controller_look(delta)
	_handle_blinking(delta)
	_handle_headbob(delta)
	_handle_flashlight_shake(delta)
	_handle_footstep_landing()
	
	move_and_slide()

# ============================================================================
# MOVEMENT FUNCTIONS
# ============================================================================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_sprint() -> void:
	if Input.is_action_just_pressed("sprint"):
		sprint = true
	elif Input.is_action_just_released("sprint"):
		sprint = false

func _handle_movement(delta: float) -> void:
	var current_max_speed: float = SPEED_SPRINT if sprint else SPEED_WALK
	
	# Get movement input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calculate speed based on input magnitude (prevents diagonal speed boost)
	var input_magnitude: float = input_dir.length()
	var speed_factor: float = min(input_magnitude, 1.0)
	var target_speed: float = speed_factor * current_max_speed
	
	# Calculate acceleration/deceleration rates
	var acceleration_rate: float = delta * input_magnitude * 10.0
	var deceleration_rate: float = delta * SPEED_SPRINT * 2.0
	
	# Apply movement
	if move_direction and input_magnitude > 0:
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, acceleration_rate)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, acceleration_rate)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration_rate)
		velocity.z = move_toward(velocity.z, 0, deceleration_rate)

# ============================================================================
# CAMERA FUNCTIONS
# ============================================================================

func _handle_controller_look(delta: float) -> void:
	if not controller_look_enabled:
		return
	
	# Get right analog stick input
	var look_horizontal := Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_vertical := Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
	
	# Only process if there's significant input
	if abs(look_horizontal) > 0 or abs(look_vertical) > 0:
		# Apply sensitivity multiplier when aiming
		var effective_controller_sensitivity := controller_look_sensitivity
		if is_aiming and zoom_enabled:
			effective_controller_sensitivity *= zoom_mouse_sensitivity_multiplier
		
		var look_vector := Vector2(look_horizontal, look_vertical) * effective_controller_sensitivity * delta
		
		# Apply camera rotation
		_camera_yaw.rotation.y -= look_vector.x
		_camera_yaw.orthonormalize()
		_camera_pitch.rotation.x += look_vector.y * CAMERA_RATIO
		_camera_pitch.rotation.x = clamp(_camera_pitch.rotation.x, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

func rotate_camera(p_relative: Vector2) -> void:
	# Apply sensitivity multiplier when aiming
	var effective_sensitivity := mouse_sensitivity
	if is_aiming and zoom_enabled:
		print("=== Camera Info ===")
		print("Position: ", _camera.global_position)
		print("Rotation: ", _camera.global_rotation)
		print("FOV: ", _camera.fov)
		print("==================")
		effective_sensitivity *= zoom_mouse_sensitivity_multiplier
	
	_camera_yaw.rotation.y -= p_relative.x * effective_sensitivity
	_camera_yaw.orthonormalize()
	_camera_pitch.rotation.x += p_relative.y * effective_sensitivity * CAMERA_RATIO * mouse_y_inversion
	_camera_pitch.rotation.x = clamp(_camera_pitch.rotation.x, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

# ============================================================================
# ZOOM FUNCTIONS
# ============================================================================

func _handle_zoom(delta: float) -> void:
	if not zoom_enabled or not _camera:
		return
	
	# Check if aim button is held
	is_aiming = Input.is_action_pressed("aim")

	# Smoothly transition FOV
	var target_fov := zoom_fov if is_aiming else default_fov
	current_fov = lerp(current_fov, target_fov, delta * zoom_speed)
	_camera.fov = current_fov

# ============================================================================
# HEADBOB FUNCTIONS
# ============================================================================

func _handle_headbob(delta: float) -> void:
	if not headbob_enabled or not is_on_floor():
		_reset_headbob()
		return
	
	var is_moving := velocity.length() > 0.1
	
	if is_moving:
		# Continue headbob animation when moving
		headbob_time += delta * velocity.length() * headbob_freq
		current_headbob_offset = _calculate_headbob_offset()
		headbob_was_moving_last_frame = true
		
		# Footstep sound logic
		var foot_threshold := -headbob_amp + 0.002
		if current_headbob_offset.y > foot_threshold:
			foot_sound = true
		elif current_headbob_offset.y < foot_threshold and foot_sound:
			foot_sound = false
			# Play footstep audio here: %FootAudio3D.play()
	else:
		# When stopping, keep current offset but don't update headbob_time
		if headbob_was_moving_last_frame:
			headbob_was_moving_last_frame = false
	
	# Apply headbob offset to camera pitch
	_camera_pitch.position = current_headbob_offset

func _calculate_headbob_offset() -> Vector3:
	var headbob_pos := Vector3.ZERO
	headbob_pos.y = sin(headbob_time * headbob_freq) * headbob_amp
	headbob_pos.x = cos(headbob_time * headbob_freq / 2) * headbob_amp
	return headbob_pos

func _reset_headbob() -> void:
	_camera_pitch.position = Vector3.ZERO
	current_headbob_offset = Vector3.ZERO
	headbob_was_moving_last_frame = false

# ============================================================================
# FLASHLIGHT SHAKE FUNCTIONS
# ============================================================================

func _handle_flashlight_shake(delta: float) -> void:
	if not light_shake_enabled or not spotlight_node or not spotlight_node.visible or is_blinking:
		_reset_flashlight_shake()
		return
	
	var is_moving := velocity.length() > 0.1
	
	if is_moving:
		# Continue shake animation when moving
		light_shake_time += delta * light_shake_freq
		current_shake_offset = _calculate_shake_offset()
		light_was_moving_last_frame = true
	else:
		# When stopping, keep current offset
		if light_was_moving_last_frame:
			light_was_moving_last_frame = false
	
	# Always apply the current shake offset
	spotlight_node.position = light_original_pos + current_shake_offset

func _calculate_shake_offset() -> Vector3:
	var shake_pos := Vector3.ZERO
	shake_pos.x = sin(light_shake_time * 1.3) * light_shake_intensity
	shake_pos.y = cos(light_shake_time * 1.7) * light_shake_intensity * 0.8
	shake_pos.z = sin(light_shake_time * 2.1) * light_shake_intensity * 0.6
	return shake_pos

func _reset_flashlight_shake() -> void:
	if spotlight_node and not is_blinking:
		spotlight_node.position = light_original_pos
		current_shake_offset = Vector3.ZERO
		light_was_moving_last_frame = false

# ============================================================================
# FLASHLIGHT BLINKING FUNCTIONS
# ============================================================================

func _handle_blinking(delta: float) -> void:
	if not blinking_enabled or not spotlight_node:
		return
	
	if not is_blinking:
		blink_timer += delta
		
		if blink_timer >= next_blink_time:
			_start_blink()
	# Currently blinking, managed by tween

func _start_blink() -> void:
	is_blinking = true
	blink_timer = 0
	spotlight_node.visible = false
	
	var blink_tween := create_tween()
	
	# Turn flashlight back on after blink duration
	blink_tween.tween_callback(func():
		if spotlight_node and is_blinking:
			spotlight_node.visible = true
	).set_delay(blink_duration)
	
	# End blink and schedule next one
	blink_tween.tween_callback(func():
		if spotlight_node:
			is_blinking = false
			blink_timer = 0
			next_blink_time = randf_range(min_blink_interval, max_blink_interval)
	).set_delay(blink_duration)

func toggle_flashlight() -> void:
	if spotlight_node:
		spotlight_node.visible = not spotlight_node.visible
		if spotlight_node.visible:
			current_shake_offset = Vector3.ZERO
			light_shake_time = 0.0

# ============================================================================
# FOOTSTEP FUNCTIONS
# ============================================================================

func _handle_footstep_landing() -> void:
	if not foot_land and is_on_floor():
		# Landed - play landing audio: %FootAudio3D.play()
		pass
	elif foot_land and not is_on_floor():
		# Jumped - play jump audio: %FootAudio3D.play()
		pass
	
	foot_land = is_on_floor()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(p_event: InputEvent) -> void:
	# Handle mouse look
	if p_event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(p_event.relative)
		get_viewport().set_input_as_handled()
		return
	
	# Handle keyboard shortcuts
	if p_event is InputEventKey and p_event.pressed:
		match p_event.keycode:
			KEY_F:
				toggle_flashlight()
			KEY_B:
				blinking_enabled = not blinking_enabled
