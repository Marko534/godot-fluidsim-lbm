extends Node3D

@export var cameras: Array[Camera3D] = []
var current_camera: int = 0

func _ready() -> void:
	# Make sure first camera is active
	if cameras.size() > 0:
		cameras[0].make_current()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("view"):
		current_camera = (current_camera + 1) % cameras.size()
		cameras[current_camera].make_current()
		
