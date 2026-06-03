extends Node3D

enum SimRate {UNCAPPED, HZ_60, HZ_30, HZ_1}
#@export var sim_rate: SimRate = SimRate.UNCAPPED
var run_timer: float = 0.0

@export var run_duration: float = 30.0
@export var bench: bool = false

signal sim_rate_changed(new_rate)

var sim_rate: SimRate = SimRate.UNCAPPED:
	set(value):
		sim_rate = value
		sim_rate_changed.emit(value)

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
	if event.is_action_pressed("scene"):
		var current := get_tree().current_scene.scene_file_path
		var idx := SCENES.find(current)
		var next := (idx + 1) % SCENES.size()
		get_tree().change_scene_to_file(SCENES[next])
	elif event.is_action_pressed("rate"):
		var current_idx = sim_rate
		var next_idx = (current_idx + 1) % SimRate.size()
		sim_rate = next_idx as SimRate
