extends Camera3D

## Free fly camera with mouse look and keyboard controls
## Uses your defined input mappings

@export var mouse_sensitivity: float = 0.001
@export var base_speed: float = 1.0
@export var sprint_speed_multiplier: float = 5.0
#@export var slow_speed_multiplier: float = 0.3  # Optional, for focus

var current_speed: float = base_speed
var mouse_captured: bool = false

func _ready():
	# Capture mouse for first-person control
	capture_mouse()

func _input(event: InputEvent):
	# Handle mouse capture toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		release_mouse()
	
	# Click to capture mouse
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		capture_mouse()
	
	# Mouse look
	if mouse_captured and event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)

func _process(delta: float):
	# Handle movement
	_handle_movement(delta)

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func _handle_mouse_look(mouse_delta: Vector2):
	# Horizontal rotation (Yaw)
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	
	# Vertical rotation (Pitch)
	var pitch_change = -mouse_delta.y * mouse_sensitivity
	var current_rotation = rotation.x
	var new_rotation = current_rotation + pitch_change
	
	# Clamp pitch to prevent flipping
	new_rotation = clamp(new_rotation, -PI/2 + 0.01, PI/2 - 0.01)
	rotation.x = new_rotation

func _handle_movement(delta: float):
	# Calculate current speed (with sprint)
	current_speed = base_speed
	if Input.is_action_pressed("sprint"):
		current_speed *= sprint_speed_multiplier
	
	# Get movement input
	var input_dir := Vector3.ZERO
	
	# Forward/Back
	if Input.is_action_pressed("move_forward"):
		input_dir.z += 1
	elif Input.is_action_pressed("move_back"):
		input_dir.z -= 1
	
	# Left/Right
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	elif Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# Up/Down (Q/E or Space/Ctrl)
	if Input.is_action_pressed("move_up"):  # Space or V for up
		input_dir.y += 1
	elif Input.is_action_pressed("move_down"):  # Right mouse for down
		input_dir.y -= 1
		
	if Input.is_action_just_pressed("aim"):
		self.fov = 35
	elif Input.is_action_just_released("aim"):
		self.fov = 75
	
	# Normalize diagonal movement
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
	
	# Transform input direction to camera orientation
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var up = global_transform.basis.y
	
	var movement = (right * input_dir.x + up * input_dir.y + forward * input_dir.z) * current_speed * delta
	
	global_translate(movement)
