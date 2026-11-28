extends Node
class_name CrashDetector

## Detects crashes on its parent RigidBody3D or VehicleBody3D, the same way KOLE detects
## hard impacts: a big change in velocity while touching something.
## STARTER (driving research, section 4, 2026-11-27). Untested.
##
## Setup: add as a child of the ambulance (or any vehicle). It turns on contact
## monitoring for you. Connect "crashed" to damage states (method A: swap damaged meshes,
## detach parts), sound, the patient's state and the event log.

signal crashed(severity: float, contact_point: Vector3)

@export var minor_speed_change: float = 3.0    # m/s: a bump worth logging
@export var cooldown: float = 0.5              # one bounce should not count twice

var _body: RigidBody3D
var _previous_velocity: Vector3 = Vector3.ZERO
var _cooldown_left: float = 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	if _body == null:
		push_warning("CrashDetector must be a child of a RigidBody3D or VehicleBody3D.")
		return
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, 4)


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var velocity := _body.linear_velocity
	var velocity_change := velocity - _previous_velocity
	_previous_velocity = velocity
	var change := velocity_change.length()
	if _cooldown_left > 0.0 or change < minor_speed_change:
		return
	var colliding := _body.get_colliding_bodies()
	if colliding.is_empty():
		return  # hard braking alone is not a crash
	# A mostly vertical change is a pothole, curb or landing, not a crash.
	if Vector2(velocity_change.x, velocity_change.z).length() < change * 0.5:
		return
	_cooldown_left = cooldown
	# Approximate: the other body's position. For the exact contact point, move this check
	# into the vehicle's own _integrate_forces() and use state.get_contact_collider_position().
	var contact_point := (colliding[0] as Node3D).global_position if colliding[0] is Node3D else _body.global_position
	crashed.emit(change, contact_point)
	EventBus.vehicle_crashed.emit(change, contact_point)
