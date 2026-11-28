extends HoldableObject
class_name Defibrillator

## KOLE, the defibrillator (a fictional brand). Its screen cracks, for looks only, on a
## hard impact such as a hard drop or a toss onto the floor. Landing on the stretcher
## pad never cracks it, because the pad cushions it.
##
## How a hard impact is detected: while touching something, compare this step's velocity
## with the last one. A big sudden change means a hard hit.

@export var crack_speed_change: float = 3.0   ## m/s; a 30 cm drop stays under, a chest-height drop goes over

const PAD_EDGE_TOLERANCE: float = 0.03        ## contacts this close below the pad top still count as pad

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


## True if any contact is on top of the stretcher's pad (not its sides or legs).
func _is_touching_stretcher_pad(state: PhysicsDirectBodyState3D) -> bool:
	for contact_index in range(state.get_contact_count()):
		var stretcher := state.get_contact_collider_object(contact_index) as StretcherController
		if stretcher == null:
			continue
		var local_contact := stretcher.to_local(state.get_contact_collider_position(contact_index))
		if local_contact.y >= stretcher.get_pad_top_local_y() - PAD_EDGE_TOLERANCE:
			return true
	return false
