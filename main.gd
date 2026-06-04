extends Node3D

enum SimRate { UNCAPPED, HZ_60, HZ_30, HZ_1 }

var phase_timer:  float = 0.0
var phase_index:  int   = -1  # -1 = warmup phase

@export var phase_duration:  float = 30.0
@export var warmup_duration: float = 30.0
@export var bench:           bool  = false

signal sim_rate_changed(new_rate)

@export var sim_rate: SimRate = SimRate.UNCAPPED:
	set(value):
		sim_rate = value
		sim_rate_changed.emit(value)

const SCENES = [
	"res://scenes/main.tscn",
	"res://scenes/terrain.tscn",
	"res://scenes/donut.tscn"
]

const PHASES: Array = [SimRate.UNCAPPED, SimRate.HZ_60, SimRate.HZ_30, SimRate.HZ_1]

func _ready() -> void:
	if bench:
		print("Warmup phase — waiting %.0f seconds before benchmark starts" % warmup_duration)

func _process(delta: float) -> void:

	if not bench:
		return

	phase_timer += delta

	# Warmup phase
	if phase_index == -1:
		if phase_timer >= warmup_duration:
			phase_timer  = 0.0
			phase_index  = 0
			sim_rate     = PHASES[0]
			print("Warmup done — starting bench phase 0: ", SimRate.keys()[PHASES[0]])
		else:
			# Show countdown every 5 seconds
			if int(phase_timer) % 5 == 0 and fmod(phase_timer, 1.0) < delta:
				print("Warmup: %.0f / %.0f" % [phase_timer, warmup_duration])
		return

	# Bench phases
	if phase_timer >= phase_duration:
		phase_timer  = 0.0
		phase_index += 1

		if phase_index >= PHASES.size():
			print("Bench complete — all phases done")
			get_tree().quit()
			return

		sim_rate = PHASES[phase_index]
		print("Bench phase %d: %s" % [phase_index, SimRate.keys()[PHASES[phase_index]]])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scene"):
		var current := get_tree().current_scene.scene_file_path
		var idx     := SCENES.find(current)
		var next    := (idx + 1) % SCENES.size()
		get_tree().change_scene_to_file(SCENES[next])

	elif event.is_action_pressed("rate"):
		var next_idx := (sim_rate + 1) % SimRate.size()
		sim_rate      = next_idx as SimRate
		print("Sim rate: ", SimRate.keys()[sim_rate])
