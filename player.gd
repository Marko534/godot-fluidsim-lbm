extends CharacterBody3D

@export var mouse_y_inversion: float = -1.0

@onready var _camera_yaw: Node3D = self
@onready var _camera_pitch: Node3D = $Camera3D

const SPEED_WALK = 3      # Horizontal movement speed (pixels/second)
const SPEED_SPRINT = SPEED_WALK * 2       # Horizontal movement speed (pixels/second)
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
	Input.start_joy_vibration(0,  1,  1,  2) 

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var max_speed = SPEED_WALK
	# Handle sprint.
	if Input.is_action_just_pressed("sprint"):
		sprint = true
		max_speed = SPEED_SPRINT
	elif Input.is_action_just_released("sprint"):
		sprint = false
		max_speed = SPEED_WALK
	elif sprint:
		max_speed = SPEED_SPRINT
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var input_len_sqrt := input_dir.length_squared()
	var input_len_delta := input_len_sqrt/10
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * input_len_sqrt * max_speed , input_len_delta)
		velocity.z = move_toward(velocity.z, direction.z * input_len_sqrt * max_speed , input_len_delta)
	else:
		velocity.x = move_toward(velocity.x, 0, max_speed/3)
		velocity.z = move_toward(velocity.z, 0, max_speed/3)
	print("Max Velocity: ", direction.x * input_len_sqrt * max_speed, " Current Velocity: ", velocity, " Acceleration: ", input_len_delta)
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
