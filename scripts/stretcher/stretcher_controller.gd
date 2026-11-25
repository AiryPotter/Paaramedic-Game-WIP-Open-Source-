extends RigidBody3D
class_name StretcherController

## Arcade-style driving with independent front and rear caster swivel locks.

@export var maximum_speed: float = 2.2
@export var drive_acceleration: float = 8.0
@export var maximum_turn_speed: float = 0.8
@export var turn_acceleration: float = 3.5
@export var caster_swivel_speed: float = 8.0

var operator: CharacterBody3D
var operator_input: Vector2 = Vector2.ZERO
var operator_offset: Vector3 = Vector3(0.0, 0.0, 1.45)
var operator_forward_local: Vector3 = Vector3(0.0, 0.0, -1.0)
var operator_right_local: Vector3 = Vector3(1.0, 0.0, 0.0)
var operator_facing_yaw_offset: float = 0.0
var front_casters_locked: bool = false
var rear_casters_locked: bool = false

var _front_casters: Array[Node3D] = []
var _rear_casters: Array[Node3D] = []
var _front_width_tween: Tween
var _rear_width_tween: Tween
var _front_lever_tween: Tween
var _rear_lever_tween: Tween


func _ready() -> void:
	_front_casters = [$CasterFrontLeft as Node3D, $CasterFrontRight as Node3D]
	_rear_casters = [$CasterRearLeft as Node3D, $CasterRearRight as Node3D]


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
		Vector3(0.0, 0.0, 1.45),
		Vector3(0.0, 0.0, -1.45),
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
	if local_direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(-local_direction.x, -local_direction.z)
	for caster in casters:
		caster.rotation.y = lerp_angle(
			caster.rotation.y,
			target_yaw,
			clampf(caster_swivel_speed * delta, 0.0, 1.0)
		)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(operator):
		operator = null
		operator_input = Vector2.ZERO
		return

	var longitudinal_input := -operator_input.y
	var lateral_input := operator_input.x
	var local_forward_motion := operator_forward_local * longitudinal_input
	var target_horizontal_velocity := Vector3.ZERO
	var target_turn_speed := 0.0

	if are_both_casters_unlocked():
		var free_direction := local_forward_motion + operator_right_local * lateral_input
		if free_direction.length_squared() > 0.01:
			var world_direction := global_basis * free_direction.normalized()
			target_horizontal_velocity = world_direction * maximum_speed
		_steer_free_casters(_front_casters, free_direction, delta)
		_steer_free_casters(_rear_casters, free_direction, delta)
	else:
		# The operator's facing at grab time defines forward/reverse for the drive.
		var world_forward := global_basis * operator_forward_local
		target_horizontal_velocity = world_forward * (longitudinal_input * maximum_speed)

		if front_casters_locked and not rear_casters_locked:
			# Rear pair is the drive/steering pair when the front is locked.
			var rear_steer_direction := local_forward_motion - operator_right_local * (lateral_input * 0.4)
			_steer_free_casters(_rear_casters, rear_steer_direction, delta)
			target_turn_speed = lateral_input * maximum_turn_speed * _body_drive_sign(longitudinal_input)
		elif rear_casters_locked and not front_casters_locked:
			# Front pair is the drive/steering pair when the rear is locked.
			var front_steer_direction := local_forward_motion + operator_right_local * (lateral_input * 0.4)
			_steer_free_casters(_front_casters, front_steer_direction, delta)
			target_turn_speed = -lateral_input * maximum_turn_speed * _body_drive_sign(longitudinal_input)
		# With both pairs locked, it rolls straight along the operator's facing axis.

	linear_velocity.x = move_toward(linear_velocity.x, target_horizontal_velocity.x, drive_acceleration * delta)
	linear_velocity.z = move_toward(linear_velocity.z, target_horizontal_velocity.z, drive_acceleration * delta)
	angular_velocity.y = move_toward(angular_velocity.y, target_turn_speed, turn_acceleration * delta)


func _body_drive_sign(longitudinal_input: float) -> float:
	if is_zero_approx(longitudinal_input) or absf(operator_forward_local.z) < 0.1:
		return 0.0
	return signf(-operator_forward_local.z) * signf(longitudinal_input)
