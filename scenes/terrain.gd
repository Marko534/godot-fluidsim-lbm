extends Node3D

var run_timer: float = 0.0
@export var run_duration: float = 30.0
@export var bench: bool = false

const SCENE_A = "res://scenes/weather.tscn"
const SCENE_B = "res://scenes/main.tscn"

func _process(delta: float) -> void:
	run_timer += delta
	if bench and run_timer >= run_duration:
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Enter key
		var current := get_tree().current_scene.scene_file_path
		if current == SCENE_A:
			get_tree().change_scene_to_file(SCENE_B)
		else:
			get_tree().change_scene_to_file(SCENE_A)
