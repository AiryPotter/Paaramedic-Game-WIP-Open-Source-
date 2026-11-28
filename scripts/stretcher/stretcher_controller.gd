extends RigidBody3D
class_name StretcherController

## The stretcher: a rigid body the player grabs and drives like a cart.
##
## How it moves
##   - Each end has a pair of casters. A pair can be swivel-LOCKED (wheels stay straight)
##     or FREE (wheels turn to follow the motion). A lock is not a brake.
##   - Both free:    moves in any direction. From an end, sideways input also swings it.
##   - One locked:   steers like a forklift, from the free pair.
##   - Both locked:  rolls straight along its length only.
##   - _physics_process() turns the operator's joystick into target velocities.
##   - _integrate_forces() then enforces the wheel rules on the real physics state, so
##     bumps, pushes and coasting all obey the same locks.
##
## Other features: a sticky pad (items that touch it stay put), LOWER/RAISE for patient
## loading, a PUSH that lets it coast, and bumps from the walking player.
## See documentation/ARCHITECTURE.md for the big picture.

# --- Tuning (editable in the Inspector) -----------------------------------------------
@export var maximum_speed: float = 2.2          ## m/s when driven or pushed
@export var drive_acceleration: float = 8.0     ## m/s² toward the target speed
@export var maximum_turn_speed: float = 1.2     ## rad/s
@export var turn_acceleration: float = 6.0      ## rad/s²
@export var caster_swivel_speed: float = 14.0   ## how fast casters turn to a new angle
@export var maximum_steer_angle: float = 0.6    ## rad; about 2.3 m turning circle with one pair locked
@export var minimum_bump_speed: float = 0.8     ## player must walk into it faster than this
@export var bump_impulse_scale: float = 0.12
@export var maximum_bump_impulse: float = 16.0
@export var bump_cooldown: float = 0.3          ## s between bumps

# --- Fixed dimensions (match scenes/stretcher/stretcher.tscn) -------------------------
const WHEELBASE: float = 1.6                ## m between front and rear casters
const PAD_TOP_LOCAL_Y: float = 0.82         ## top of the pad when raised
const DECK_COLLISION_Y: float = 0.73        ## center of the deck collider when raised
const LOWERED_DECK_OFFSET: float = -0.22    ## how far LOWER drops the deck
const END_HANDLE_Z: float = 1.625           ## operator spots at each end
const SIDE_HANDLE_X: float = 1.0            ## operator spots at each side

# --- Behavior constants ----------------------------------------------------------------
const HEIGHT_CHANGE_TIME: float = 0.55              ## s for LOWER or RAISE
const MAX_SPEED_TO_CHANGE_HEIGHT: float = 0.15      ## m/s; must be nearly stopped
const MIN_PUSH_ALIGNMENT: float = 0.15              ## with locks, facing must be this much along the length
const FREE_END_SLIDE_SHARE: float = 0.5             ## both free, from an end: keep half the sideways slide
const SIDE_STEER_MIN_SPEED: float = 0.05            ## side operators steer only while rolling
const CASTER_WIDTH_LOCKED: float = 0.66             ## casters spread out when locked
const CASTER_WIDTH_FREE: float = 0.48
const CASTER_WIDTH_TIME: float = 0.32
const LEVER_ANGLE_LOCKED: float = 0.85
const LEVER_ANGLE_FREE: float = -0.25
const LEVER_TIME: float = 0.28

# --- Child nodes ----------------------------------------------------------------------
@onready var _deck_assembly: Node3D = $DeckAssembly            ## deck, pad and rails that move with LOWER/RAISE
@onready var _pad_area: Area3D = $DeckAssembly/PadArea           ## thin sensor on top of the pad
@onready var _deck_collision: CollisionShape3D = $CollisionDeck  ## must stay a direct child of the body

# --- State ----------------------------------------------------------------------------
var operator: CharacterBody3D                                  ## player holding it, or null
var operator_input: Vector2 = Vector2.ZERO                     ## joystick, length 0..1
var operator_offset: Vector3 = Vector3(0.0, 0.0, END_HANDLE_Z) ## which handle (local)
var operator_forward_local: Vector3 = Vector3(0.0, 0.0, -1.0)  ## joystick "up", local
var operator_right_local: Vector3 = Vector3(1.0, 0.0, 0.0)     ## joystick "right", local
var operator_facing_yaw_offset: float = 0.0
var front_casters_locked: bool = false
var rear_casters_locked: bool = false
var is_lowered: bool = false

var _front_casters: Array[Node3D] = []
var _rear_casters: Array[Node3D] = []
var _front_wheel_colliders: Array[CollisionShape3D] = []
var _rear_wheel_colliders: Array[CollisionShape3D] = []
var _current_steer_angle: float = 0.0
var _bump_cooldown_remaining: float = 0.0
var _pending_bump_impulse: Vector3 = Vector3.ZERO   ## applied in _integrate_forces()
var _pending_bump_offset: Vector3 = Vector3.ZERO

var _front_width_tween: Tween
var _rear_width_tween: Tween
var _front_lever_tween: Tween
var _rear_lever_tween: Tween

var _height_tween: Tween
var _height_target_lowered: bool = false
var _height_starting_offset: float = 0.0
var _height_target_offset: float = 0.0
var _height_stuck_items: Array[HoldableObject] = []
var _height_stuck_start_heights: Array[float] = []


func _ready() -> void:
	_front_casters = [$CasterFrontLeft as Node3D, $CasterFrontRight as Node3D]
	_rear_casters = [$CasterRearLeft as Node3D, $CasterRearRight as Node3D]
	_front_wheel_colliders = [
		$WheelCollisionFrontLeft as CollisionShape3D,
		$WheelCollisionFrontRight as CollisionShape3D
	]
	_rear_wheel_colliders = [
		$WheelCollisionRearLeft as CollisionShape3D,
		$WheelCollisionRearRight as CollisionShape3D
	]
	_sync_wheel_colliders()


# ======================================================================================
# Operator: grab, release, input
# ======================================================================================

## Called by PickupInteractor. Snaps the player to the nearest handle and stops the
## stretcher. Returns false if someone already holds it.
func grab(player: CharacterBody3D) -> bool:
	if is_instance_valid(operator):
		return false

	operator = player
	operator_input = Vector2.ZERO
	operator_offset = _nearest_operator_offset(player.global_position)
	# Joystick "up" points from the handle toward the stretcher's center.
	operator_forward_local = Vector3(-operator_offset.x, 0.0, -operator_offset.z).normalized()
	if operator_forward_local.length_squared() < 0.01:
		operator_forward_local = Vector3(0.0, 0.0, -1.0)
	operator_facing_yaw_offset = atan2(-operator_forward_local.x, -operator_forward_local.z)
	operator_right_local = operator_forward_local.cross(Vector3.UP).normalized()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	can_sleep = false
	sleeping = false
	add_collision_exception_with(player)
	(player as PlayerController).enter_stretcher_mode(self, operator_facing_yaw_offset)
	return true


## Lets go. Existing momentum keeps coasting under the wheel rules.
func release(player: CharacterBody3D) -> void:
	if not is_instance_valid(operator) or operator != player:
		return

	remove_collision_exception_with(player)
	(operator as PlayerController).exit_stretcher_mode()
	operator = null
	operator_input = Vector2.ZERO
	can_sleep = true


func set_operator_input(input_vector: Vector2) -> void:
	operator_input = input_vector.limit_length(1.0)


## Where the operator's feet should be, on the floor beside the chosen handle.
func get_operator_position() -> Vector3:
	var position_at_operator_side := global_position + global_basis * operator_offset
	position_at_operator_side.y = 0.0
	return position_at_operator_side


func _nearest_operator_offset(player_position: Vector3) -> Vector3:
	var local_player_position := to_local(player_position)
	var handles: Array[Vector3] = [
		Vector3(0.0, 0.0, END_HANDLE_Z),
		Vector3(0.0, 0.0, -END_HANDLE_Z),
		Vector3(SIDE_HANDLE_X, 0.0, 0.0),
		Vector3(-SIDE_HANDLE_X, 0.0, 0.0)
	]
	var nearest_handle := handles[0]
	var nearest_distance := INF
	for handle in handles:
		var distance := Vector2(local_player_position.x, local_player_position.z).distance_squared_to(
			Vector2(handle.x, handle.z)
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_handle = handle
	return nearest_handle


func _is_end_operator() -> bool:
	return absf(operator_offset.z) > absf(operator_offset.x)


# ======================================================================================
# Caster locks
# ======================================================================================

func are_both_casters_unlocked() -> bool:
	return not front_casters_locked and not rear_casters_locked


func toggle_front_caster_lock() -> void:
	_set_casters_locked(true, not front_casters_locked)


func toggle_rear_caster_lock() -> void:
	_set_casters_locked(false, not rear_casters_locked)


func get_front_lock_label() -> String:
	return "FRONT: LOCKED" if front_casters_locked else "FRONT: FREE"


func get_rear_lock_label() -> String:
	return "REAR: LOCKED" if rear_casters_locked else "REAR: FREE"


func _set_casters_locked(is_front: bool, locked: bool) -> void:
	var current := front_casters_locked if is_front else rear_casters_locked
	if current == locked:
		return
	if is_front:
		front_casters_locked = locked
	else:
		rear_casters_locked = locked
	var casters := _front_casters if is_front else _rear_casters
	if locked:
		for caster in casters:
			caster.rotation.y = 0.0  # a locked pair always points straight
	_animate_caster_pair_width(casters, locked, is_front)
	_animate_lock_lever(NodePath("FrontLockLever/Lever" if is_front else "RearLockLever/Lever"), locked, is_front)


# ======================================================================================
# LOWER / RAISE
# ======================================================================================

## Pad top in the stretcher's local space, following LOWER/RAISE.
func get_pad_top_local_y() -> float:
	return PAD_TOP_LOCAL_Y + _deck_assembly.position.y


## True only when fully lowered and not moving between heights.
func is_lowered_for_loading() -> bool:
	return is_lowered and not _is_tween_running(_height_tween)


func can_change_height() -> bool:
	if not is_instance_valid(operator) or _is_tween_running(_height_tween):
		return false
	return Vector2(linear_velocity.x, linear_velocity.z).length() <= MAX_SPEED_TO_CHANGE_HEIGHT


func get_height_action_label() -> String:
	if _is_tween_running(_height_tween):
		return "LOWERING..." if _height_target_lowered else "RAISING..."
	if not can_change_height():
		return "STOP TO RAISE" if is_lowered else "STOP TO LOWER"
	return "RAISE" if is_lowered else "LOWER"


## Starts LOWER or RAISE. Items stuck to the pad move with the deck.
func toggle_height() -> bool:
	if not can_change_height():
		return false

	_height_target_lowered = not is_lowered
	_height_starting_offset = _deck_assembly.position.y
	_height_target_offset = LOWERED_DECK_OFFSET if _height_target_lowered else 0.0
	_height_stuck_items.clear()
	_height_stuck_start_heights.clear()
	for candidate in get_tree().get_nodes_in_group("pickupable"):
		if candidate is HoldableObject:
			var item := candidate as HoldableObject
			if item.is_stuck and item.stuck_to == self:
				_height_stuck_items.append(item)
				_height_stuck_start_heights.append(item.get_stuck_local_position_y())

	_height_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_height_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_height_tween.tween_method(_set_height_progress, 0.0, 1.0, HEIGHT_CHANGE_TIME)
	_height_tween.finished.connect(_finish_height_transition)
	return true


func _set_height_progress(progress: float) -> void:
	var current_offset := lerpf(_height_starting_offset, _height_target_offset, progress)
	_deck_assembly.position.y = current_offset
	_deck_collision.position.y = DECK_COLLISION_Y + current_offset
	var height_delta := current_offset - _height_starting_offset
	for index in range(_height_stuck_items.size()):
		var item := _height_stuck_items[index]
		if is_instance_valid(item):
			item.set_stuck_local_position_y(_height_stuck_start_heights[index] + height_delta)


func _finish_height_transition() -> void:
	is_lowered = _height_target_lowered
	_height_stuck_items.clear()
	_height_stuck_start_heights.clear()


# ======================================================================================
# PUSH and bumps
# ======================================================================================

## PUSH needs the operator facing enough along the stretcher when any pair is locked.
func can_push_from_operator(player: CharacterBody3D) -> bool:
	if not is_instance_valid(operator) or operator != player:
		return false
	if _is_tween_running(_height_tween):
		return false
	var push_direction := _flat_facing(player)
	if push_direction.length_squared() < 0.01:
		return false
	if are_both_casters_unlocked():
		return true
	var local_direction := global_basis.inverse() * push_direction.normalized()
	return absf(local_direction.z) >= MIN_PUSH_ALIGNMENT


## Lets go and shoves the stretcher toward full speed in the facing direction (along its
## length if any pair is locked). It then coasts.
func push_from_operator(player: CharacterBody3D) -> bool:
	if not can_push_from_operator(player):
		return false

	var push_direction := _flat_facing(player).normalized()
	if not are_both_casters_unlocked():
		var local_direction := global_basis.inverse() * push_direction
		push_direction = global_basis * Vector3(0.0, 0.0, local_direction.z).normalized()
		push_direction.y = 0.0
		push_direction = push_direction.normalized()

	var current_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_velocity := (current_velocity + push_direction * maximum_speed).limit_length(maximum_speed)
	release(player)
	apply_central_impulse((target_velocity - current_velocity) * mass)
	sleeping = false
	return true


## Called by PlayerController when the walking player runs into the stretcher. The impulse
## is queued and applied at the contact point in _integrate_forces(), so a hit near an end
## can swing it.
func apply_character_bump(
	player_velocity: Vector3,
	surface_normal: Vector3,
	contact_position: Vector3
) -> void:
	if is_instance_valid(operator) or _bump_cooldown_remaining > 0.0:
		return
	var push_direction := -surface_normal
	push_direction.y = 0.0
	if push_direction.length_squared() < 0.001:
		return
	push_direction = push_direction.normalized()
	var impact_velocity := Vector3(player_velocity.x, 0.0, player_velocity.z)
	var impact_speed := impact_velocity.dot(push_direction)
	if impact_speed < minimum_bump_speed:
		return
	var impulse_strength := clampf(
		(impact_speed - minimum_bump_speed) * mass * bump_impulse_scale,
		0.0,
		maximum_bump_impulse
	)
	if impulse_strength <= 0.0:
		return
	can_sleep = true
	sleeping = false
	_pending_bump_impulse += push_direction * impulse_strength
	_pending_bump_offset = contact_position - global_position
	_bump_cooldown_remaining = bump_cooldown


func _flat_facing(player: CharacterBody3D) -> Vector3:
	var facing := -player.global_basis.z
	facing.y = 0.0
	return facing


# ======================================================================================
# Physics loop
# ======================================================================================

func _physics_process(delta: float) -> void:
	_bump_cooldown_remaining = maxf(_bump_cooldown_remaining - delta, 0.0)
	_sync_wheel_colliders()
	_stick_holdables_to_pad()
	if not is_instance_valid(operator):
		operator = null
		operator_input = Vector2.ZERO
		return
	if _is_tween_running(_height_tween):
		# Hold still while the deck moves.
		operator_input = Vector2.ZERO
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		angular_velocity.y = 0.0
		return

	# Joystick in the stretcher's local frame: up = toward the center from the handle.
	var desired_local := operator_forward_local * -operator_input.y + operator_right_local * operator_input.x
	var target_velocity: Vector3
	var target_turn_speed: float
	if are_both_casters_unlocked():
		var result := _drive_all_free(desired_local, delta)
		target_velocity = result[0]
		target_turn_speed = result[1]
	else:
		var result := _drive_with_locks(desired_local, operator_input.x, delta)
		target_velocity = result[0]
		target_turn_speed = result[1]

	linear_velocity.x = move_toward(linear_velocity.x, target_velocity.x, drive_acceleration * delta)
	linear_velocity.z = move_toward(linear_velocity.z, target_velocity.z, drive_acceleration * delta)
	angular_velocity.y = move_toward(angular_velocity.y, target_turn_speed, turn_acceleration * delta)


## Both pairs free: move in any direction. From an end, sideways input also swings that
## end ("swing and slide"). Returns [target world velocity, target turn speed].
func _drive_all_free(desired_local: Vector3, delta: float) -> Array:
	var turn_speed := 0.0
	if _is_end_operator():
		turn_speed = signf(operator_offset.z) * desired_local.x * maximum_turn_speed
		desired_local.x *= FREE_END_SLIDE_SHARE
	var target_velocity := global_basis * desired_local * maximum_speed
	_steer_free_casters(_front_casters, desired_local, delta)
	_steer_free_casters(_rear_casters, desired_local, delta)
	return [target_velocity, turn_speed]


## At least one pair locked: drive only along the stretcher's length. With exactly one
## pair locked, the free pair steers (forklift style when it is the trailing pair).
## Returns [target world velocity, target turn speed].
func _drive_with_locks(desired_local: Vector3, lateral_input: float, delta: float) -> Array:
	var drive_speed := -desired_local.z * maximum_speed
	var target_velocity := global_basis * Vector3(0.0, 0.0, -drive_speed)
	var exactly_one_pair_locked := front_casters_locked != rear_casters_locked
	if not exactly_one_pair_locked:
		_current_steer_angle = 0.0
		return [target_velocity, 0.0]  # both locked: _integrate_forces keeps it straight

	var actual_forward_speed := -(global_basis.inverse() * linear_velocity).z
	var target_steer_angle := _current_steer_angle
	if _is_end_operator():
		target_steer_angle = -lateral_input * maximum_steer_angle
	elif absf(actual_forward_speed) > SIDE_STEER_MIN_SPEED:
		# From a side, stick toward or away from the player swings the free end, and keeps
		# meaning the same thing whichever way it is rolling.
		target_steer_angle = -desired_local.x * signf(actual_forward_speed) * maximum_steer_angle
	_current_steer_angle = move_toward(_current_steer_angle, target_steer_angle, caster_swivel_speed * delta)

	# Bicycle model: turn rate = speed * tan(steer angle) / wheelbase.
	var yaw_rate := actual_forward_speed * tan(_current_steer_angle) / WHEELBASE
	if front_casters_locked:
		_steer_caster_pair_to_angle(_rear_casters, _current_steer_angle, delta)
		yaw_rate = -yaw_rate  # rear steering swings the trailing end, forklift style
	else:
		_steer_caster_pair_to_angle(_front_casters, _current_steer_angle, delta)
	return [target_velocity, clampf(yaw_rate, -maximum_turn_speed, maximum_turn_speed)]


## Runs inside the physics step. Applies queued bumps, then the wheel rules, so bumps,
## pushes and coasting all respect the caster locks.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_bump_impulse.length_squared() > 0.0:
		state.apply_impulse(_pending_bump_impulse, _pending_bump_offset)
		_pending_bump_impulse = Vector3.ZERO
		_pending_bump_offset = Vector3.ZERO
	if are_both_casters_unlocked():
		return

	var local_velocity := global_basis.inverse() * state.linear_velocity
	var spin := state.angular_velocity
	if front_casters_locked and rear_casters_locked:
		# Both locked: no sideways sliding and no turning.
		spin.y = 0.0
		local_velocity.x = 0.0
	else:
		# One locked: that axle cannot slide sideways, so sideways speed must match the
		# turning around it (v.x + yaw_rate * axle_z = 0).
		var locked_axle_z := -WHEELBASE * 0.5 if front_casters_locked else WHEELBASE * 0.5
		local_velocity.x = -spin.y * locked_axle_z
	state.linear_velocity = global_basis * local_velocity
	state.angular_velocity = spin


# ======================================================================================
# Sticky pad
# ======================================================================================

## Any loose HoldableObject touching the pad sensor sticks where it landed: same X, Z and
## turn, set flat on the pad. The patient is skipped; it moves only by TRANSFER.
func _stick_holdables_to_pad() -> void:
	for overlapping_body in _pad_area.get_overlapping_bodies():
		if not overlapping_body is HoldableObject:
			continue
		var item := overlapping_body as HoldableObject
		if item.is_held or item.is_stuck:
			continue
		if item.is_in_group("training_patient"):
			continue

		var local_center := to_local(item.global_position)
		var local_yaw := wrapf(item.global_rotation.y - global_rotation.y, -PI, PI)
		var resting_center_y := (
			get_pad_top_local_y()
			+ item.pad_resting_height * 0.5
			+ item.pad_resting_offset_y
		)
		var local_transform := Transform3D(
			Basis(Vector3.UP, local_yaw),
			Vector3(local_center.x, resting_center_y, local_center.z)
		)
		item.stick_to_surface(self, local_transform)


# ======================================================================================
# Caster visuals and wheel colliders
# ======================================================================================

func _animate_caster_pair_width(casters: Array[Node3D], locked: bool, is_front: bool) -> void:
	var old_tween: Tween = _front_width_tween if is_front else _rear_width_tween
	if _is_tween_running(old_tween):
		old_tween.kill()

	var tween := create_tween().set_parallel(true)
	if is_front:
		_front_width_tween = tween
	else:
		_rear_width_tween = tween

	var target_width := CASTER_WIDTH_LOCKED if locked else CASTER_WIDTH_FREE
	for caster in casters:
		var target_position := caster.position
		target_position.x = signf(caster.position.x) * target_width
		tween.tween_property(caster, "position", target_position, CASTER_WIDTH_TIME)


func _animate_lock_lever(path: NodePath, locked: bool, is_front: bool) -> void:
	var lever := get_node(path) as Node3D
	var old_tween: Tween = _front_lever_tween if is_front else _rear_lever_tween
	if _is_tween_running(old_tween):
		old_tween.kill()

	var target_rotation := Vector3(0.0, 0.0, LEVER_ANGLE_LOCKED if locked else LEVER_ANGLE_FREE)
	var tween := create_tween()
	if is_front:
		_front_lever_tween = tween
	else:
		_rear_lever_tween = tween
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lever, "rotation", target_rotation, LEVER_TIME)


## Free casters turn to face the direction of travel.
func _steer_free_casters(casters: Array[Node3D], local_direction: Vector3, delta: float) -> void:
	if local_direction.length_squared() < 0.0001:
		return
	_steer_caster_pair_to_angle(casters, atan2(-local_direction.x, -local_direction.z), delta)


func _steer_caster_pair_to_angle(casters: Array[Node3D], target_angle: float, delta: float) -> void:
	for caster in casters:
		caster.rotation.y = lerp_angle(
			caster.rotation.y,
			target_angle,
			clampf(caster_swivel_speed * delta, 0.0, 1.0)
		)


## Wheel colliders are direct children of the body (so physics uses them) and copy the
## caster positions, which widen when a pair is locked.
func _sync_wheel_colliders() -> void:
	var wheel_local_transform := Transform3D(
		Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5),
		Vector3.ZERO
	)
	for index in range(_front_casters.size()):
		_front_wheel_colliders[index].transform = _front_casters[index].transform * wheel_local_transform
		_rear_wheel_colliders[index].transform = _rear_casters[index].transform * wheel_local_transform


func _is_tween_running(tween: Tween) -> bool:
	return is_instance_valid(tween) and tween.is_running()
