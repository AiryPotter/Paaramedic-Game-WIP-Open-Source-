extends RigidBody3D
class_name HoldableObject

## A reusable physical object that can be held, released, or secured to the stretcher pad.

@export var pad_resting_height: float = 0.3
@export var pad_resting_offset_y: float = 0.0

var is_held: bool = false
var is_stuck: bool = false
var stuck_to: RigidBody3D
var _saved_collision_layer: int
var _saved_collision_mask: int
var _stuck_collision_mask: int
var _stuck_local_transform: Transform3D


func pick_up(hold_transform: Transform3D) -> void:
	if is_held:
		return

	unstick_from_surface()
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	is_held = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	global_transform = hold_transform


func follow_hold_point(hold_transform: Transform3D) -> void:
	if is_held:
		global_transform = hold_transform


func stick_to_surface(surface: RigidBody3D, local_transform: Transform3D) -> void:
	if is_held or is_stuck:
		return
	is_stuck = true
	stuck_to = surface
	_stuck_local_transform = local_transform
	_stuck_collision_mask = collision_mask
	collision_mask = 0
	add_collision_exception_with(surface)
	surface.add_collision_exception_with(self)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_follow_stuck_surface()


func get_stuck_local_position_y() -> float:
	return _stuck_local_transform.origin.y


func set_stuck_local_position_y(value: float) -> void:
	if not is_stuck:
		return
	_stuck_local_transform.origin.y = value


func unstick_from_surface() -> void:
	if not is_stuck:
		return
	if is_instance_valid(stuck_to):
		remove_collision_exception_with(stuck_to)
		stuck_to.remove_collision_exception_with(self)
	stuck_to = null
	is_stuck = false
	collision_mask = _stuck_collision_mask
	if not is_held:
		freeze = false
		sleeping = false


func _follow_stuck_surface(delta: float = 0.0) -> void:
	if not is_instance_valid(stuck_to):
		unstick_from_surface()
		return

	var predicted_surface := stuck_to.global_transform
	predicted_surface.origin += stuck_to.linear_velocity * delta
	predicted_surface.basis = Basis(Vector3.UP, stuck_to.angular_velocity.y * delta) * predicted_surface.basis
	global_transform = predicted_surface * _stuck_local_transform


func _physics_process(delta: float) -> void:
	if is_stuck:
		_follow_stuck_surface(delta)


func release(hold_transform: Transform3D, inherited_velocity: Vector3) -> void:
	if not is_held:
		return

	global_transform = hold_transform
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	is_held = false
	freeze = false
	sleeping = false
	linear_velocity = inherited_velocity
	angular_velocity = Vector3.ZERO
