extends HoldableObject
class_name Defibrillator

## A hard impact cracks the display; the stretcher pad cushions the device.

@export var crack_speed_change: float = 3.0

const PAD_TOP_LOCAL_Y: float = 0.82

var screen_cracked: bool = false
var _previous_velocity: Vector3 = Vector3.ZERO


func release(hold_transform: Transform3D, inherited_velocity: Vector3) -> void:
	super.release(hold_transform, inherited_velocity)
	_previous_velocity = inherited_velocity


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not screen_cracked and state.get_contact_count() > 0:
		var speed_change := (state.linear_velocity - _previous_velocity).length()
		if speed_change >= crack_speed_change and not _is_touching_stretcher_pad(state):
			screen_cracked = true
			$CrackedScreen.set_deferred("visible", true)
	_previous_velocity = state.linear_velocity


func _is_touching_stretcher_pad(state: PhysicsDirectBodyState3D) -> bool:
	for contact_index in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(contact_index)
		if collider is Node3D and collider.is_in_group("grabbable_stretcher"):
			var local_contact := (collider as Node3D).to_local(
				state.get_contact_collider_position(contact_index)
			)
			var pad_top_local_y := PAD_TOP_LOCAL_Y
			if (collider as Node3D).has_method("get_pad_top_local_y"):
				pad_top_local_y = float((collider as Node3D).call("get_pad_top_local_y"))
			if local_contact.y >= pad_top_local_y - 0.03:
				return true
	return false
