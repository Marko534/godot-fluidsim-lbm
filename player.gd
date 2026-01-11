extends CharacterBody3D

@export var mouse_y_inversion: float = -1.0

@onready var _camera_yaw: Node3D = self
@onready var _camera_pitch: Node3D = $Camera3D

const SPEED_WALK = 3.0      # Horizontal movement speed (units/second)
const SPEED_SPRINT = SPEED_WALK * 2.0       # Sprint speed (units/second)
const JUMP_VELOCITY = -300.0 # Jump strength (negative because Y goes down)

const CAMERA_MAX_PITCH: float = deg_to_rad(70)
const CAMERA_MIN_PITCH: float = deg_to_rad(-89.9)
const CAMERA_RATIO: float = .625

# Variables for "game feel" techniques (we'll initialize them later)
var sprint = false
var coyote_timer = 0.0
const COYOTE_TIME_THRESHOLD = 0.1 # 100 milliseconds of coyote time

var mouse_sensitivity = 0.002

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	
	print("Target Speed: %.2f\t Current Velocity: %.2f\t Acceleration: %.2f\t Deceleration: %.2f" % [
		target_speed,
		velocity.length(),
		acceleration_rate,
		deceleration_rate
	])
	
	move_and_slide()

func _input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(p_event.relative)
		get_viewport().set_input_as_handled()
		return

func rotate_camera(p_relative:Vector2) -> void:
	_camera_yaw.rotation.y -= p_relative.x * mouse_sensitivity
	_camera_yaw.orthonormalize()
	_camera_pitch.rotation.x += p_relative.y * mouse_sensitivity * CAMERA_RATIO * mouse_y_inversion 
	_camera_pitch.rotation.x = clamp(_camera_pitch.rotation.x, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	
	
