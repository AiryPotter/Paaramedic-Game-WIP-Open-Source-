extends Node

## Current call, elapsed time, and an event log that scoring and the debrief read later.
## STARTER (milestone plan, Milestones 10 and 17). Untested.
## Add as an autoload named "GameState", after "EventBus".
## Point values are placeholders. The real rubric comes from the maintainer in Milestone 17.

var scenario: Resource                 # a ScenarioData resource
var student_name: String = ""
var elapsed_seconds: float = 0.0
var is_running: bool = false
var events: Array[Dictionary] = []     # {time, type, detail, points}


func _ready() -> void:
	EventBus.backup_requested.connect(func(unit: String): log_event("backup_requested", unit))
	EventBus.backup_arrived.connect(func(unit: String): log_event("backup_arrived", unit))
	EventBus.patient_moved.connect(func(method: String): log_event("patient_moved", method))
	EventBus.stretcher_hit.connect(func(speed: float): log_event("stretcher_hit", "%.1f m/s" % speed))
	EventBus.vehicle_crashed.connect(func(severity: float, _point: Vector3): log_event("vehicle_crashed", "%.1f" % severity))
	# Maintainer decision: unsafe transport loses points and is explained in the debrief.
	EventBus.unsafe_transport.connect(func(reason: String): log_event("unsafe_transport", reason, -5))


func start_call(new_scenario: Resource, student: String) -> void:
	scenario = new_scenario
	student_name = student
	elapsed_seconds = 0.0
	events.clear()
	is_running = true
	EventBus.call_started.emit(str(new_scenario.get("scenario_id")) if new_scenario else "")


func _process(delta: float) -> void:
	if is_running:
		elapsed_seconds += delta


func log_event(type: String, detail: String = "", points: int = 0) -> void:
	events.append({"time": elapsed_seconds, "type": type, "detail": detail, "points": points})


func finish_call() -> void:
	is_running = false
	EventBus.call_finished.emit()
	_save_results()


func total_points() -> int:
	var total := 0
	for event in events:
		total += int(event.get("points", 0))
	return total


func _save_results() -> void:
	# Results stay on the iPad (students share the maintainer's iPad).
	DirAccess.make_dir_recursive_absolute("user://results")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open("user://results/%s.json" % stamp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"student": student_name,
		"scenario": str(scenario.get("scenario_id")) if scenario else "",
		"seconds": elapsed_seconds,
		"points": total_points(),
		"events": events,
	}, "  "))
