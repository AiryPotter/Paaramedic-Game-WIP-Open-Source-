extends HoldableObject
class_name TrainingPatient

## Neutral training mannequin. It is never picked up or tossed: after assessment,
## TRANSFER moves it onto a lowered, stopped, lined-up stretcher.
## Clinical case data is intentionally omitted until supplied and reviewed.
## Suggested by Claude Code (fix S3). Written against 9ae595b. Untested.

const TRANSFER_MAX_SIDE_DISTANCE: float = 1.2
const TRANSFER_MIN_SIDE_DISTANCE: float = 0.5
const TRANSFER_MAX_ALONG_OFFSET: float = 0.5
const TRANSFER_MAX_ANGLE_DEGREES: float = 25.0
const TRANSFER_MAX_STRETCHER_SPEED: float = 0.15
const LOADED_LOCAL_POSITION: Vector3 = Vector3(0.0, 0.75, 0.0)

var assessment_started: bool = false
var is_loaded: bool = false
var _loaded_on: RigidBody3D


func assess_patient() -> void:
	assessment_started = true


## Returns "" when TRANSFER is allowed, or a short hint saying what is missing.
func get_transfer_hint(stretcher: Node3D) -> String:
	if is_loaded:
		return "PATIENT LOADED"
	if not assessment_started:
		return "ASSESS PATIENT"
	if not is_instance_valid(stretcher):
		return "BRING STRETCHER"
	if stretcher.has_method("is_lowered_for_loading") and not bool(stretcher.call("is_lowered_for_loading")):
		return "LOWER STRETCHER"
	if stretcher is RigidBody3D:
		var body := stretcher as RigidBody3D
		if Vector2(body.linear_velocity.x, body.linear_velocity.z).length() > TRANSFER_MAX_STRETCHER_SPEED:
			return "STOP STRETCHER"

	# Patient's center in the stretcher's frame: x is sideways, z is along its length.
	var local_patient := stretcher.to_local(global_position)
	var side_distance := absf(local_patient.x)
	if side_distance > TRANSFER_MAX_SIDE_DISTANCE or absf(local_patient.z) > TRANSFER_MAX_ALONG_OFFSET:
		return "BRING STRETCHER CLOSER"
	if side_distance < TRANSFER_MIN_SIDE_DISTANCE:
		return "PARK BESIDE PATIENT"

	# Both long axes are local Z. Head-first and feet-first both count as lined up.
	var angle := absf(wrapf(global_rotation.y - stretcher.global_rotation.y, -PI, PI))
	angle = minf(angle, PI - angle)
	if rad_to_deg(angle) > TRANSFER_MAX_ANGLE_DEGREES:
		return "LINE UP STRETCHER"
	return ""


func can_load_onto(stretcher: Node3D) -> bool:
	return get_transfer_hint(stretcher).is_empty()


## The patient is never held: no solo carrying and no tossing.
func pick_up(_hold_transform: Transform3D) -> void:
	return


func load_onto_stretcher(stretcher: Node3D) -> bool:
	if not can_load_onto(stretcher):
		return false

	var deck_assembly := stretcher.get_node_or_null("DeckAssembly") as Node3D
	if deck_assembly == null:
		return false

	is_loaded = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var interaction_area := $InteractionArea as Area3D
	interaction_area.set_deferred("collision_layer", 0)
	interaction_area.set_deferred("monitorable", false)

	# Add the patient's weight so pushing and bumping feel heavier.
	if stretcher is RigidBody3D:
		_loaded_on = stretcher as RigidBody3D
		_loaded_on.mass += mass

	call_deferred("_finish_stretcher_load", deck_assembly)
	return true


func _finish_stretcher_load(deck_assembly: Node3D) -> void:
	if not is_instance_valid(deck_assembly):
		return
	reparent(deck_assembly, true)
	var transfer_tween := create_tween()
	transfer_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	transfer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transfer_tween.tween_property(self, "position", LOADED_LOCAL_POSITION, 0.45)
	transfer_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.45)


func get_hud_text(stretcher: Node3D = null) -> String:
	if is_loaded:
		return "PATIENT LOADED\nRaise the stretcher before moving."
	if not assessment_started:
		return "TRAINING CASE 01\nFind the patient and tap ASSESS PATIENT."
	var hint := get_transfer_hint(stretcher)
	if hint.is_empty():
		return "TRAINING CASE 01\nStretcher in position. Aim at the patient and tap TRANSFER."
	return (
		"TRAINING CASE 01\n"
		+ "Assessment recorded. Next: " + hint.to_lower() + ", then TRANSFER.\n"
		+ "Clinical findings and protocols await maintainer and clinician review."
	)
