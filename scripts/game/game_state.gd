extends Node

## Small session state and event log for the first playable scenario.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MOVE_JOYSTICK_POSITION := Vector2(0.09, 0.67)
const DEFAULT_LOOK_JOYSTICK_POSITION := Vector2(0.91, 0.67)
const LEGACY_MOVE_JOYSTICK_POSITION := Vector2(0.09, 0.88)
const LEGACY_LOOK_JOYSTICK_POSITION := Vector2(0.91, 0.88)

signal pause_changed(is_paused: bool)
signal event_recorded(event: Dictionary)
signal objective_changed(index: int, total: int, text: String)
signal settings_changed

var active_scenario: ScenarioDefinition
var event_log: Array[Dictionary] = []
var objective_index: int = 0
var look_sensitivity: float = 0.003
var master_volume: float = 1.0
var move_joystick_position: Vector2 = DEFAULT_MOVE_JOYSTICK_POSITION
var look_joystick_position: Vector2 = DEFAULT_LOOK_JOYSTICK_POSITION
var _session_started_at_msec: int = 0


func _ready() -> void:
	_session_started_at_msec = Time.get_ticks_msec()
	_load_settings()


func start_scenario(scenario: ScenarioDefinition) -> void:
	active_scenario = scenario
	event_log.clear()
	objective_index = 0
	_session_started_at_msec = Time.get_ticks_msec()
	record_event("scenario_started", {"scenario_id": scenario.scenario_id})
	objective_changed.emit(objective_index, scenario.objectives.size(), get_current_objective())
	get_tree().paused = false
	pause_changed.emit(false)


func record_event(event_name: String, details: Dictionary = {}) -> void:
	var entry := {
		"event": event_name,
		"time_seconds": (Time.get_ticks_msec() - _session_started_at_msec) / 1000.0,
		"details": details.duplicate(true),
	}
	event_log.append(entry)
	_advance_objective(event_name)
	event_recorded.emit(entry)


func get_current_objective() -> String:
	if active_scenario == null:
		return ""
	if objective_index >= active_scenario.objectives.size():
		return "Mission complete."
	return active_scenario.objectives[objective_index]


func _advance_objective(event_name: String) -> void:
	if active_scenario == null or objective_index >= active_scenario.objective_event_names.size():
		return
	if active_scenario.objective_event_names[objective_index] != event_name:
		return
	objective_index += 1
	objective_changed.emit(
		objective_index,
		active_scenario.objectives.size(),
		get_current_objective()
	)


func get_event_log() -> Array[Dictionary]:
	return event_log.duplicate(true)


func set_paused(should_pause: bool) -> void:
	get_tree().paused = should_pause
	pause_changed.emit(should_pause)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func restart_scenario() -> void:
	if active_scenario == null:
		return
	start_scenario(active_scenario)
	get_tree().reload_current_scene()


func return_to_menu() -> void:
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func save_settings() -> void:
	var config := ConfigFile.new()
	_clamp_joystick_positions()
	config.set_value("controls", "look_sensitivity", look_sensitivity)
	config.set_value("controls", "move_joystick_position", move_joystick_position)
	config.set_value("controls", "look_joystick_position", look_joystick_position)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	_apply_audio_settings()
	settings_changed.emit()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		look_sensitivity = clampf(float(config.get_value("controls", "look_sensitivity", look_sensitivity)), 0.0005, 0.02)
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		var saved_move_position: Variant = config.get_value(
			"controls", "move_joystick_position", DEFAULT_MOVE_JOYSTICK_POSITION
		)
		var saved_look_position: Variant = config.get_value(
			"controls", "look_joystick_position", DEFAULT_LOOK_JOYSTICK_POSITION
		)
		if saved_move_position is Vector2:
			move_joystick_position = saved_move_position
			if move_joystick_position.is_equal_approx(LEGACY_MOVE_JOYSTICK_POSITION):
				move_joystick_position = DEFAULT_MOVE_JOYSTICK_POSITION
		if saved_look_position is Vector2:
			look_joystick_position = saved_look_position
			if look_joystick_position.is_equal_approx(LEGACY_LOOK_JOYSTICK_POSITION):
				look_joystick_position = DEFAULT_LOOK_JOYSTICK_POSITION
	_clamp_joystick_positions()
	_apply_audio_settings()


func _clamp_joystick_positions() -> void:
	move_joystick_position.x = clampf(move_joystick_position.x, 0.05, 0.32)
	move_joystick_position.y = clampf(move_joystick_position.y, 0.38, 0.92)
	look_joystick_position.x = clampf(look_joystick_position.x, 0.68, 0.95)
	look_joystick_position.y = clampf(look_joystick_position.y, 0.38, 0.92)


func _apply_audio_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.0)
