extends RigidBody3D
class_name StretcherController

## Arcade-style driving with independent front and rear caster swivel locks.

@export var maximum_speed: float = 2.2
@export var drive_acceleration: float = 8.0
@export var maximum_turn_speed: float = 1.2
@export var turn_acceleration: float = 6.0
@export var caster_swivel_speed: float = 14.0
@export var maximum_steer_angle: float = 0.6
@export var minimum_bump_speed: float = 0.8
@export var bump_impulse_scale: float = 0.12
@export var maximum_bump_impulse: float = 16.0
@export var bump_cooldown: float = 0.3

const WHEELBASE: float = 1.6
const PAD_TOP_LOCAL_Y: float = 0.82

@onready var _pad_area: Area3D = $PadArea

var operator: CharacterBody3D
var operator_input: Vector2 = Vector2.ZERO
var operator_offset: Vector3 = Vector3(0.0, 0.0, 1.625)
var operator_forward_local: Vector3 = Vector3(0.0, 0.0, -1.0)
var operator_right_local: Vector3 = Vector3(1.0, 0.0, 0.0)
var operator_facing_yaw_offset: float = 0.0
var front_casters_locked: bool = false
var rear_casters_locked: bool = false

var _front_casters: Array[Node3D] = []
var _rear_casters: Array[Node3D] = []
var _front_wheel_colliders: Array[CollisionShape3D] = []
var _rear_wheel_colliders: Array[CollisionShape3D] = []
var _current_steer_angle: float = 0.0
var _bump_cooldown_remaining: float = 0.0
var _front_width_tween: Tween
var _rear_width_tween: Tween
var _front_lever_tween: Tween
var _rear_lever_tween: Tween


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


func grab(player: CharacterBody3D) -> bool:
	if is_instance_valid(operator):
		return false

	operator = player
	operator_input = Vector2.ZERO
	operator_offset = _nearest_operator_offset(player.global_position)
	operator_facing_yaw_offset = wrapf(player.rotation.y - rotation.y, -PI, PI)
	operator_forward_local = global_basis.inverse() * (-player.global_basis.z)
	operator_forward_local.y = 0.0
	if operator_forward_local.length_squared() < 0.01:
		operator_forward_local = Vector3(0.0, 0.0, -1.0)
	operator_forward_local = operator_forward_local.normalized()
	operator_right_local = operator_forward_local.cross(Vector3.UP).normalized()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	can_sleep = false
	sleeping = false
	add_collision_exception_with(player)
	player.call("enter_stretcher_mode", self, operator_facing_yaw_offset)
	return true


func release(player: CharacterBody3D) -> void:
	if not is_instance_valid(operator) or operator != player:
		return

	remove_collision_exception_with(player)
	operator.call("exit_stretcher_mode")
	operator = null
	operator_input = Vector2.ZERO
	can_sleep = true


func _nearest_operator_offset(player_position: Vector3) -> Vector3:
	var local_player_position := to_local(player_position)
	var approach_points: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.625),
		Vector3(0.0, 0.0, -1.625),
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0)
	]
	var nearest_point := approach_points[0]
	var nearest_distance := INF
	for point in approach_points:
		var distance := Vector2(local_player_position.x, local_player_position.z).distance_squared_to(
			Vector2(point.x, point.z)
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_point = point
	return nearest_point


func set_operator_input(input_vector: Vector2) -> void:
	operator_input = input_vector.limit_length(1.0)


func get_operator_position() -> Vector3:
	var position_at_operator_side := global_position + global_basis * operator_offset
	position_at_operator_side.y = 0.0
	return position_at_operator_side


func are_both_casters_unlocked() -> bool:
	return not front_casters_locked and not rear_casters_locked


func toggle_front_caster_lock() -> void:
	_set_front_casters_locked(not front_casters_locked)


func toggle_rear_caster_lock() -> void:
	_set_rear_casters_locked(not rear_casters_locked)


func get_front_lock_label() -> String:
	return "FRONT: LOCKED" if front_casters_locked else "FRONT: FREE"


func get_rear_lock_label() -> String:
	return "REAR: LOCKED" if rear_casters_locked else "REAR: FREE"


func can_push_from_operator(player: CharacterBody3D) -> bool:
	if not is_instance_valid(operator) or operator != player:
		return false
	var push_direction := -player.global_basis.z
	push_direction.y = 0.0
	if push_direction.length_squared() < 0.01:
		return false
	if are_both_casters_unlocked():
		return true
	var local_direction := global_basis.inverse() * push_direction.normalized()
	return absf(local_direction.z) >= 0.15


func push_from_operator(player: CharacterBody3D) -> bool:
	if not can_push_from_operator(player):
		return false

	var push_direction := -player.global_basis.z
	push_direction.y = 0.0
	push_direction = push_direction.normalized()
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


func _set_front_casters_locked(locked: bool) -> void:
	if front_casters_locked == locked:
		return
	front_casters_locked = locked
	if locked:
		_straighten_caster_pair(_front_casters)
	_animate_caster_pair_width(_front_casters, locked, true)
	_animate_lock_lever(NodePath("FrontLockLever/Lever"), locked, true)


func _set_rear_casters_locked(locked: bool) -> void:
	if rear_casters_locked == locked:
		return
	rear_casters_locked = locked
	if locked:
		_straighten_caster_pair(_rear_casters)
	_animate_caster_pair_width(_rear_casters, locked, false)
	_animate_lock_lever(NodePath("RearLockLever/Lever"), locked, false)


func _straighten_caster_pair(casters: Array[Node3D]) -> void:
	for caster in casters:
		caster.rotation.y = 0.0


func _animate_caster_pair_width(casters: Array[Node3D], locked: bool, is_front: bool) -> void:
	var old_tween: Tween = _front_width_tween if is_front else _rear_width_tween
	if is_instance_valid(old_tween) and old_tween.is_running():
		old_tween.kill()

	var tween := create_tween().set_parallel(true)
	if is_front:
		_front_width_tween = tween
	else:
		_rear_width_tween = tween

	var target_width := 0.66 if locked else 0.48
	for caster in casters:
		var target_position := caster.position
		target_position.x = signf(caster.position.x) * target_width
		tween.tween_property(caster, "position", target_position, 0.32)


func _animate_lock_lever(path: NodePath, locked: bool, is_front: bool) -> void:
	var lever := get_node(path) as Node3D
	var old_tween: Tween = _front_lever_tween if is_front else _rear_lever_tween
	if is_instance_valid(old_tween) and old_tween.is_running():
		old_tween.kill()

	var target_rotation := Vector3(0.0, 0.0, 0.85 if locked else -0.25)
	var tween := create_tween()
	if is_front:
		_front_lever_tween = tween
	else:
		_rear_lever_tween = tween
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lever, "rotation", target_rotation, 0.28)


func _steer_free_casters(casters: Array[Node3D], local_direction: Vector3, delta: float) -> void:
	if local_direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-local_direction.x, -local_direction.z)
	for caster in casters:
		caster.rotation.y = lerp_angle(
			caster.rotation.y,
			target_yaw,
			clampf(caster_swivel_speed * delta, 0.0, 1.0)
		)


func _steer_caster_pair_to_angle(casters: Array[Node3D], target_angle: float, delta: float) -> void:
	for caster in casters:
		caster.rotation.y = lerp_angle(
			caster.rotation.y,
			target_angle,
			clampf(caster_swivel_speed * delta, 0.0, 1.0)
		)


func _sync_wheel_colliders() -> void:
	var wheel_local_transform := Transform3D(
		Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5),
		Vector3.ZERO
	)
	for index in range(_front_casters.size()):
		_front_wheel_colliders[index].transform = _front_casters[index].transform * wheel_local_transform
		_rear_wheel_colliders[index].transform = _rear_casters[index].transform * wheel_local_transform


func apply_character_bump(player_velocity: Vector3, surface_normal: Vector3) -> void:
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
	apply_central_impulse(push_direction * impulse_strength)
	_bump_cooldown_remaining = bump_cooldown


func _stick_holdables_to_pad() -> void:
	for overlapping_body in _pad_area.get_overlapping_bodies():
		if not overlapping_body is HoldableObject:
			continue
		var item := overlapping_body as HoldableObject
		if item.is_held or item.is_stuck:
			continue

		var local_center := to_local(item.global_position)
		var local_yaw := wrapf(item.global_rotation.y - global_rotation.y, -PI, PI)
		var resting_center_y := PAD_TOP_LOCAL_Y + item.pad_resting_height * 0.5

		var local_transform := Transform3D(
			Basis(Vector3.UP, local_yaw),
			Vector3(local_center.x, resting_center_y, local_center.z)
		)
		item.stick_to_surface(self, local_transform)


func _physics_process(delta: float) -> void:
	_bump_cooldown_remaining = maxf(_bump_cooldown_remaining - delta, 0.0)
	_sync_wheel_colliders()
	_stick_holdables_to_pad()
	if not is_instance_valid(operator):
		operator = null
		operator_input = Vector2.ZERO
		return

	var longitudinal_input := -operator_input.y
	var lateral_input := operator_input.x
	var desired_local := operator_forward_local * longitudinal_input + operator_right_local * lateral_input
	var target_horizontal_velocity := Vector3.ZERO
	var target_turn_speed := 0.0

	if are_both_casters_unlocked():
		var world_direction := global_basis * desired_local
		target_horizontal_velocity = world_direction * maximum_speed
		_steer_free_casters(_front_casters, desired_local, delta)
		_steer_free_casters(_rear_casters, desired_local, delta)
	else:
		# Caster locks hold swivel angle only; wheels still roll along the stretcher axis.
		var drive_speed := -desired_local.z * maximum_speed
		target_horizontal_velocity = global_basis * Vector3(0.0, 0.0, -drive_speed)

		var actual_local_velocity := global_basis.inverse() * linear_velocity
		var actual_forward_speed := -actual_local_velocity.z
		var exactly_one_pair_locked := front_casters_locked != rear_casters_locked
		if exactly_one_pair_locked:
			var is_side_operator := absf(operator_offset.x) > absf(operator_offset.z)
			var target_steer_angle := _current_steer_angle
			if is_side_operator:
				if absf(actual_forward_speed) > 0.05:
					target_steer_angle = -desired_local.x * signf(actual_forward_speed) * maximum_steer_angle
			else:
				target_steer_angle = -lateral_input * maximum_steer_angle
			_current_steer_angle = move_toward(
				_current_steer_angle,
				target_steer_angle,
				caster_swivel_speed * delta
			)

			var yaw_rate := actual_forward_speed * tan(_current_steer_angle) / WHEELBASE
			if front_casters_locked:
				# Rear steering swings the trailing end in forklift style.
				_steer_caster_pair_to_angle(_rear_casters, _current_steer_angle, delta)
				yaw_rate = -yaw_rate
			else:
				_steer_caster_pair_to_angle(_front_casters, _current_steer_angle, delta)
			target_turn_speed = clampf(yaw_rate, -maximum_turn_speed, maximum_turn_speed)
		else:
			_current_steer_angle = 0.0
		# With both pairs locked, constraints below still allow straight rolling.

	linear_velocity.x = move_toward(linear_velocity.x, target_horizontal_velocity.x, drive_acceleration * delta)
	linear_velocity.z = move_toward(linear_velocity.z, target_horizontal_velocity.z, drive_acceleration * delta)
	angular_velocity.y = move_toward(angular_velocity.y, target_turn_speed, turn_acceleration * delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if are_both_casters_unlocked():
		return

	var local_velocity := global_basis.inverse() * state.linear_velocity
	var constrained_angular_velocity := state.angular_velocity
	if front_casters_locked and rear_casters_locked:
		constrained_angular_velocity.y = 0.0
		local_velocity.x = 0.0
	else:
		var locked_axle_z := -WHEELBASE * 0.5 if front_casters_locked else WHEELBASE * 0.5
		local_velocity.x = -constrained_angular_velocity.y * locked_axle_z
	state.linear_velocity = global_basis * local_velocity
	state.angular_velocity = constrained_angular_velocity
