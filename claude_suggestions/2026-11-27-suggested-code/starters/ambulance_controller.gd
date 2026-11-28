extends VehicleBody3D
class_name AmbulanceController

## Joystick driving for the ambulance (maintainer decision: joystick, like walking).
## STARTER (driving research, 2026-11-27). Driving comes after the first demo. Untested.
##
## Scene setup: VehicleBody3D with this script, four VehicleWheel3D children
## (front two: use_as_steering = true; rear two: use_as_traction = true), a body
## MeshInstance3D without wheels, and a CollisionShape3D. Kenney Car Kit's ambulance
## (CC0) is a good model. Set mass around 3000 and tune.
##
## Input: the mobile controls call set_drive_input() with the left joystick
## (x = steer, y = up is negative, like walking).

signal siren_changed(is_on: bool)
signal lights_changed(is_on: bool)

@export var max_engine_force: float = 6000.0
@export var max_brake_force: float = 120.0
@export var max_steer_angle: float = 0.5           # radians at low speed
@export var high_speed_steer_angle: float = 0.15   # radians at high_speed
@export var high_speed: float = 25.0               # m/s (about 90 km/h)
@export var steer_speed: float = 2.5               # how fast the wheels turn, rad/s
@export var reverse_delay: float = 0.3             # hold back this long after stopping to reverse
@export var stopped_speed: float = 0.5             # m/s

@export_group("Patient comfort")
## Jolt limits for "harsh driving with a patient on board". Placeholders: the maintainer
## and clinical reviewer set the real limits.
@export var harsh_acceleration: float = 4.0        # m/s², forward/back or sideways
@export var harsh_cooldown: float = 2.0

var siren_on: bool = false
var lights_on: bool = false
var parking_brake_on: bool = true
var patient_on_board: bool = false
var stretcher_secured: bool = false

var _input: Vector2 = Vector2.ZERO
var _reverse_hold: float = 0.0
var _reversing: bool = false
var _previous_velocity: Vector3 = Vector3.ZERO
var _harsh_cooldown_left: float = 0.0
var _reported_unsecured: bool = false


func set_drive_input(input_vector: Vector2) -> void:
	_input = input_vector.limit_length(1.0)


func toggle_siren() -> void:
	siren_on = not siren_on
	if siren_on:
		lights_on = true
		lights_changed.emit(true)
	siren_changed.emit(siren_on)


func toggle_lights() -> void:
	lights_on = not lights_on
	if not lights_on and siren_on:
		siren_on = false
		siren_changed.emit(false)
	lights_changed.emit(lights_on)


func set_parking_brake(on: bool) -> void:
	parking_brake_on = on


func forward_speed() -> float:
	# Godot vehicles drive along their local +Z.
	return (global_basis.inverse() * linear_velocity).z


func _physics_process(delta: float) -> void:
	var speed := forward_speed()
	var throttle := -_input.y          # stick up = positive
	var steer_input := -_input.x       # stick right = negative steering (turns right)

	# Less steering at speed keeps a heavy, top-heavy vehicle stable.
	var speed_ratio := clampf(absf(speed) / high_speed, 0.0, 1.0)
	var steer_limit := lerpf(max_steer_angle, high_speed_steer_angle, speed_ratio)
	steering = move_toward(steering, steer_input * steer_limit, steer_speed * delta)

	if parking_brake_on:
		engine_force = 0.0
		brake = max_brake_force
		_check_unsafe_departure(speed)
		_previous_velocity = linear_velocity
		return

	# Stick back brakes while moving forward; held back after stopping, it reverses.
	if _reversing and throttle >= 0.0:
		_reversing = false

	if _reversing:
		brake = 0.0
		engine_force = throttle * max_engine_force * 0.5     # throttle < 0: backwards
	elif throttle < 0.0:
		engine_force = 0.0
		if speed > stopped_speed:
			_reverse_hold = 0.0
			brake = -throttle * max_brake_force
		else:
			brake = max_brake_force * 0.3                      # hold still while waiting
			_reverse_hold += delta
			if _reverse_hold >= reverse_delay:
				_reversing = true
				_reverse_hold = 0.0
	else:
		_reverse_hold = 0.0
		if speed < -stopped_speed and throttle > 0.0:
			engine_force = 0.0                                 # rolling backwards: brake first
			brake = throttle * max_brake_force
		else:
			brake = 0.0
			engine_force = throttle * max_engine_force

	_check_unsafe_departure(speed)
	_check_patient_comfort(delta)
	_previous_velocity = linear_velocity


func _check_unsafe_departure(speed: float) -> void:
	# Maintainer decision: driving off with the stretcher unsecured loses points.
	if patient_on_board and not stretcher_secured and absf(speed) > 1.0 and not _reported_unsecured:
		_reported_unsecured = true
		EventBus.unsafe_transport.emit("unsecured_stretcher")
	if stretcher_secured:
		_reported_unsecured = false


func _check_patient_comfort(delta: float) -> void:
	_harsh_cooldown_left = maxf(_harsh_cooldown_left - delta, 0.0)
	if not patient_on_board or _harsh_cooldown_left > 0.0 or delta <= 0.0:
		return
	var acceleration := (linear_velocity - _previous_velocity) / delta
	acceleration.y = 0.0
	if acceleration.length() >= harsh_acceleration:
		_harsh_cooldown_left = harsh_cooldown
		EventBus.unsafe_transport.emit("harsh_driving")
