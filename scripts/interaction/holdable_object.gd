extends RigidBody3D
class_name HoldableObject

## A reusable physical object that can be held and released by the player.

var is_held: bool = false
var _saved_collision_layer: int
var _saved_collision_mask: int


func pick_up(hold_transform: Transform3D) -> void:
	if is_held:
		return

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
