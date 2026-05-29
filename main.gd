extends Node3D

var run_timer: float = 0.0

@export var run_duration: float = 30.0
@export var bench: bool = false

const SCENES = [
	"res://scenes/main.tscn",
	"res://scenes/terrain.tscn",
    "res://scenes/donut.tscn"
]

func _process(delta: float) -> void:
	run_timer += delta
	if bench and run_timer >= run_duration:
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var current := get_tree().current_scene.scene_file_path
		var idx      := SCENES.find(current)
		var next     := (idx + 1) % SCENES.size()
		get_tree().change_scene_to_file(SCENES[next])
