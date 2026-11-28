extends Node3D
class_name StairChair

## Tracked stair chair guided by one paramedic (maintainer decisions: alone on every call;
## tracked stair chair). STARTER (milestone plan, Milestone 11). Untested.
##
## Flow: the patient is moved onto the chair (same TRANSFER idea as the stretcher), then
## SECURE. At the top of a flight, TILT tips the chair onto its tracks. Holding the
## joystick back rolls it down the stairs along a Path3D. The tracks only work going down.
##
## Setup per flight of stairs: a Path3D named "StairPath" in the level, from the top step
## to the bottom, with a Marker3D "TopLanding" at its start. The chair model goes under
## this node; give it a CollisionShape3D on an AnimatableBody3D if it must block the player.
## All speeds are placeholders to tune, and how a lone paramedic moves a patient follows
## the maintainer's service protocols.

signal reached_bottom

enum State { ROLLING, TILTED_AT_TOP, DESCENDING, AT_BOTTOM }

@export var stair_path: Path3D
@export var tilt_range: float = 0.8           # m from the top landing to allow TILT
@export var max_descent_speed: float = 0.35   # m/s along the stairs
@export var too_fast_speed: float = 0.3       # above this, it is logged as too fast
@export var tilt_angle: float = 0.35          # radians the chair tips back

var state: State = State.ROLLING
var patient_seated: bool = false
var patient_secured: bool = false
var _progress: float = 0.0
var _input: Vector2 = Vector2.ZERO
var _logged_too_fast: bool = false


func set_operator_input(input_vector: Vector2) -> void:
	_input = input_vector.limit_length(1.0)


func seat_patient() -> void:
	patient_seated = true
	patient_secured = false


func secure_patient() -> void:
	if patient_seated:
		patient_secured = true


## Returns "" when TILT is allowed, or a hint for the button.
func get_tilt_hint() -> String:
	if state != State.ROLLING:
		return ""
	if not patient_seated:
		return "SEAT PATIENT"
	if stair_path == null or stair_path.curve == null:
		return "NO STAIRS HERE"
	var top := stair_path.to_global(stair_path.curve.get_point_position(0))
	if global_position.distance_to(top) > tilt_range:
		return "MOVE TO TOP STEP"
	return ""


func tilt() -> bool:
	if not get_tilt_hint().is_empty():
		return false
	if not patient_secured:
		# Starting before the patient is secured is logged for the debrief.
		GameState.log_event("stair_chair_unsecured", "Tilted before securing the patient")
	state = State.TILTED_AT_TOP
	_progress = 0.0
	rotation.x = -tilt_angle
	return true


func _physics_process(delta: float) -> void:
	if state == State.TILTED_AT_TOP and _input.y > 0.1:
		state = State.DESCENDING
	if state != State.DESCENDING:
		return

	# Joystick pulled back (positive y) rolls down; letting go holds the chair still.
	var speed := clampf(_input.y, 0.0, 1.0) * max_descent_speed
	if speed > too_fast_speed and not _logged_too_fast:
		_logged_too_fast = true
		GameState.log_event("stair_chair_too_fast", "%.2f m/s" % speed)
	_progress += speed * delta

	var length := stair_path.curve.get_baked_length()
	_progress = minf(_progress, length)
	var path_transform := stair_path.curve.sample_baked_with_rotation(_progress)
	global_transform = stair_path.global_transform * path_transform
	rotation.x = -tilt_angle

	if _progress >= length:
		state = State.AT_BOTTOM
		rotation.x = 0.0
		EventBus.patient_moved.emit("stair_chair")
		reached_bottom.emit()
