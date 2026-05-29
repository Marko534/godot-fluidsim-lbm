extends Node3D

var run_timer: float = 0.0
@export var run_duration: float = 30.0
@export var bench: bool = false


func _process(delta: float) -> void:
	run_timer += delta
	if bench and run_timer >= run_duration:
		get_tree().quit()
