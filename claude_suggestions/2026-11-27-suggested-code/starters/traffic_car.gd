extends PathFollow3D
class_name TrafficCar

## A traffic car that drives along a lane (Path3D) and pulls aside for the ambulance.
## STARTER (driving research, 2026-11-27): the yield rule is modeled on the settings of
## GTA V siren mods, because players criticized games where cars stop in the middle of
## the road. Driving comes after the first demo. Untested.
##
## Setup: Path3D (the lane) > TrafficCar (this script, loop = true) > a car model.
## Add an AnimatableBody3D with a CollisionShape3D under the model so the ambulance can
## hit it. Put the ambulance in the "ambulance" group.

enum State { DRIVING, WAITING_TO_YIELD, YIELDING, PULLED_OVER, RETURNING }

@export var cruise_speed: float = 11.0          # m/s (about 40 km/h)
@export var acceleration: float = 3.0
@export var siren_range: float = 40.0           # m, siren on
@export var lights_only_range: float = 20.0     # m, lights without siren
@export var min_reaction_delay: float = 0.5
@export var max_reaction_delay: float = 1.5
@export var pull_over_offset: float = 2.2       # m to the right of the lane
@export var pull_over_speed: float = 2.0        # m/s while pulled over
@export var return_delay: float = 1.5           # wait after the ambulance passes

var state: State = State.DRIVING
var _speed: float = 0.0
var _timer: float = 0.0
var _side_offset: float = 0.0
var _ambulance: Node3D


func _ready() -> void:
	_speed = cruise_speed
	_ambulance = get_tree().get_first_node_in_group("ambulance") as Node3D


func _physics_process(delta: float) -> void:
	var alerted := _ambulance_is_coming()
	match state:
		State.DRIVING:
			if alerted:
				state = State.WAITING_TO_YIELD
				_timer = randf_range(min_reaction_delay, max_reaction_delay)
		State.WAITING_TO_YIELD:
			_timer -= delta
			if _timer <= 0.0:
				state = State.YIELDING
		State.YIELDING:
			if absf(_side_offset - pull_over_offset) < 0.05:
				state = State.PULLED_OVER
				_timer = return_delay
		State.PULLED_OVER:
			if not alerted:
				_timer -= delta
				if _timer <= 0.0:
					state = State.RETURNING
			else:
				_timer = return_delay
		State.RETURNING:
			if alerted:
				state = State.YIELDING
			elif absf(_side_offset) < 0.05:
				state = State.DRIVING

	# Slow down and move to the side of the lane, never stopping in the middle of it.
	var target_speed := cruise_speed
	var target_offset := 0.0
	if state in [State.YIELDING, State.PULLED_OVER]:
		target_speed = pull_over_speed
		target_offset = pull_over_offset
	_speed = move_toward(_speed, target_speed, acceleration * delta)
	_side_offset = move_toward(_side_offset, target_offset, 1.5 * delta)
	h_offset = _side_offset    # if cars pull to the wrong side, flip pull_over_offset's sign
	progress += _speed * delta


func _ambulance_is_coming() -> bool:
	if not is_instance_valid(_ambulance):
		return false
	var siren := bool(_ambulance.get("siren_on"))
	var lights := bool(_ambulance.get("lights_on"))
	if not siren and not lights:
		return false
	var range_limit := siren_range if siren else lights_only_range
	var to_ambulance := _ambulance.global_position - global_position
	if to_ambulance.length() > range_limit:
		return false
	# Behind us and heading the same way. Check on device that PathFollow3D faces -Z
	# along the path with the default rotation mode; flip my_forward if not.
	var my_forward := -global_basis.z
	var ambulance_forward := _ambulance.global_basis.z    # vehicles drive along +Z
	return to_ambulance.dot(my_forward) < 0.0 and ambulance_forward.dot(my_forward) > 0.5
