extends Node3D
class_name AmbulanceController

## Parked vehicle with a forgiving but deliberate rear-loading interaction.

const LOAD_STAGING_Z: float = 3.4
const LOAD_ALIGNMENT_X: float = 0.42
const LOAD_ALIGNMENT_Z: float = 0.7
const LOAD_ALIGNMENT_ANGLE: float = 0.35

@onready var _cargo_pose: Marker3D = $CargoPose

var _is_loading: bool = false
var _loaded_stretcher: StretcherController


func get_loading_hint(stretcher: StretcherController) -> String:
	if not is_instance_valid(stretcher):
		return ""
	var local_position := to_local(stretcher.global_position)
	if absf(local_position.x) > 2.0 or absf(local_position.z - LOAD_STAGING_Z) > 2.0:
		return ""
	if _is_loading:
		return "LOADING STRETCHER..."
	if stretcher.is_loaded_in_ambulance:
		return "STRETCHER ALREADY LOADED"
	var patient := get_tree().get_first_node_in_group("training_patient")
	if not is_instance_valid(patient) or not bool(patient.get("is_loaded")):
		return "SECURE THE MANNEQUIN ON THE STRETCHER FIRST"
	if bool(patient.get("is_loading_to_stretcher")):
		return "WAIT FOR THE MANNEQUIN TO SECURE"
	if patient.get_parent() != stretcher.get_node_or_null("DeckAssembly"):
		return "SECURE THE MANNEQUIN ON THIS STRETCHER FIRST"
	if stretcher.is_lowered:
		return "RAISE THE STRETCHER DECK BEFORE LOADING"
	if stretcher.is_height_transitioning():
		return "WAIT FOR THE STRETCHER DECK TO FINISH MOVING"
	if Vector2(stretcher.linear_velocity.x, stretcher.linear_velocity.z).length() > 0.2:
		return "STOP THE STRETCHER BEFORE LOADING"
	if absf(stretcher.angular_velocity.y) > 0.15:
		return "LET THE STRETCHER SETTLE BEFORE LOADING"
	if not _is_aligned_for_loading(stretcher, local_position):
		return "ALIGN THE STRETCHER WITH THE REAR RAMP"
	return "LOAD STRETCHER"


func get_load_action_label(stretcher: StretcherController) -> String:
	return "LOAD STRETCHER" if is_ready_to_load(stretcher) else ""


func is_ready_to_load(stretcher: StretcherController) -> bool:
	return get_loading_hint(stretcher) == "LOAD STRETCHER"


func load_stretcher(stretcher: StretcherController) -> bool:
	if not is_ready_to_load(stretcher):
		return false
	_is_loading = true
	if not stretcher.begin_ambulance_load(self, _cargo_pose):
		_is_loading = false
		return false
	GameState.record_event("stretcher_loading_started")
	return true


func is_stretcher_loaded(stretcher: StretcherController) -> bool:
	return is_instance_valid(_loaded_stretcher) and _loaded_stretcher == stretcher


func notify_stretcher_loaded(stretcher: StretcherController) -> void:
	_loaded_stretcher = stretcher
	_is_loading = false


func _is_aligned_for_loading(stretcher: StretcherController, local_position: Vector3) -> bool:
	var yaw_difference := wrapf(stretcher.global_rotation.y - global_rotation.y, -PI, PI)
	var yaw_error := minf(absf(yaw_difference), absf(PI - absf(yaw_difference)))
	return (
		absf(local_position.x) <= LOAD_ALIGNMENT_X
		and absf(local_position.y) <= 0.2
		and absf(local_position.z - LOAD_STAGING_Z) <= LOAD_ALIGNMENT_Z
		and yaw_error <= LOAD_ALIGNMENT_ANGLE
	)
