extends Area3D
class_name AmbulanceLoadZone

## Loading the stretcher into the ambulance: line up, PARK, LOAD, then SECURE.
## STARTER (driving research, section 3, 2026-11-27; SnowRunner-style "confirm loaded").
## Nothing uses loose physics inside the moving vehicle: the stretcher is frozen and
## reparented, the same pattern as the sticky pad. Untested.
##
## Setup: an Area3D (this script) at the ambulance's rear doors, child of the ambulance,
## with a box shape about 1.4 x 1.2 x 1.5 m. Add a Marker3D named "StretcherMount"
## inside the ambulance where the stretcher should end up. Collision mask: layer 1.

signal loaded
signal unloaded

@export var max_angle_degrees: float = 15.0
@export var max_stretcher_speed: float = 0.2
@export var load_time: float = 1.2

@onready var _ambulance: Node3D = get_parent() as Node3D
@onready var _mount: Marker3D = $"../StretcherMount" as Marker3D

var loaded_stretcher: RigidBody3D
var is_secured: bool = false
var _rear_doors_open: bool = true


func set_rear_doors_open(open: bool) -> void:
	_rear_doors_open = open


## Returns "" when LOAD is allowed, or a short hint for the button.
func get_load_hint(stretcher: RigidBody3D) -> String:
	if is_instance_valid(loaded_stretcher):
		return "SECURE" if not is_secured else "LOADED"
	if not is_instance_valid(stretcher) or not overlaps_body(stretcher):
		return "BRING STRETCHER TO DOORS"
	if bool(_ambulance.get("parking_brake_on")) == false:
		return "SET PARKING BRAKE"
	if not _rear_doors_open:
		return "OPEN DOORS"
	if stretcher.has_method("is_lowered_for_loading") and bool(stretcher.call("is_lowered_for_loading")):
		return "RAISE STRETCHER"
	if Vector2(stretcher.linear_velocity.x, stretcher.linear_velocity.z).length() > max_stretcher_speed:
		return "SLOW DOWN"
	var angle := absf(wrapf(stretcher.global_rotation.y - _mount.global_rotation.y, -PI, PI))
	if rad_to_deg(angle) > max_angle_degrees:
		return "LINE UP"
	return ""


func load_stretcher(stretcher: RigidBody3D, operator: CharacterBody3D) -> bool:
	if not get_load_hint(stretcher).is_empty():
		return false
	if stretcher.has_method("release"):
		stretcher.call("release", operator)
	loaded_stretcher = stretcher
	is_secured = false
	stretcher.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	stretcher.freeze = true
	stretcher.reparent(_ambulance, true)
	# After reparenting, the stretcher's transform is relative to the ambulance, like the mount's.
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(stretcher, "transform", _mount.transform, load_time)
	tween.finished.connect(func(): loaded.emit())
	EventBus.patient_moved.emit("load_ambulance")
	return true


func secure() -> void:
	if not is_instance_valid(loaded_stretcher):
		return
	is_secured = true
	_ambulance.set("stretcher_secured", true)
	EventBus.stretcher_secured.emit(true)


func unload_stretcher(drop_point: Node3D) -> void:
	if not is_instance_valid(loaded_stretcher):
		return
	var stretcher := loaded_stretcher
	loaded_stretcher = null
	is_secured = false
	_ambulance.set("stretcher_secured", false)
	stretcher.reparent(_ambulance.get_parent(), true)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(stretcher, "global_transform", drop_point.global_transform, load_time)
	tween.finished.connect(func():
		stretcher.freeze = false
		unloaded.emit())
