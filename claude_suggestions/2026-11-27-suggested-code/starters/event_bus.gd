extends Node

## Global signals so systems can react to each other without direct links.
## STARTER (milestone plan, Milestone 10). Untested.
## Add as an autoload named "EventBus": Project Settings > Globals (Autoload).

signal call_started(scenario_id: String)
signal call_stage_changed(stage: String)
signal patient_assessed(check_name: String)
signal treatment_given(treatment_name: String)
signal backup_requested(unit: String)
signal backup_arrived(unit: String)
signal patient_moved(method: String)          # "transfer", "stair_chair", "load_ambulance"
signal stretcher_hit(impact_speed: float)
signal stretcher_secured(is_secured: bool)
signal vehicle_crashed(severity: float, contact_point: Vector3)
signal unsafe_transport(reason: String)       # "unsecured_stretcher", "harsh_driving"
signal call_finished()
