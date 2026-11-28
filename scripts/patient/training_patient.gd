extends RigidBody3D
class_name TrainingPatient

## The training mannequin: ASSESS, then a controlled TRANSFER onto the stretcher.
##
##   - It cannot be picked up or tossed. Once assessed, TRANSFER works only when the
##     stretcher is lowered, stopped, beside it and lined up (get_transfer_hint() says
##     which step is missing, and that text is shown on the INTERACT button).
##   - The transfer is a short animation. The mannequin becomes a child of the
##     stretcher's DeckAssembly, so it rides with the deck and adds its mass.
##   - Clinical case data (findings, vitals, protocols) is intentionally left out until
##     the maintainer supplies it and a clinician reviews it.
## See documentation/ARCHITECTURE.md.

const MAX_SIDE_OFFSET: float = 4.0                         ## m sideways from the stretcher center
const MAX_LENGTH_OFFSET: float = 1.0                       ## m along the stretcher from its center
const MAX_ALIGNMENT_ANGLE_RADIANS: float = 25.0 * PI / 180.0
const MAX_STRETCHER_SPEED: float = 0.15                    ## m/s; "stopped"
const MAX_STRETCHER_TURN_SPEED: float = 0.1                ## rad/s; "stopped"
const TRANSFER_DECK_POSITION := Vector3(0.0, 0.75, 0.0)    ## resting spot, local to DeckAssembly
const TRANSFER_TIME: float = 0.45                          ## s

var assessment_started: bool = false
var is_loaded: bool = false                  ## on the stretcher
var is_loading_to_stretcher: bool = false    ## TRANSFER animation playing


func assess_patient() -> void:
	if assessment_started or is_loaded or is_loading_to_stretcher:
		return
	assessment_started = true
	GameState.record_event("patient_assessed")


# ======================================================================================
# TRANSFER onto the stretcher
# ======================================================================================

## The next thing the player must do, as a button label. "TRANSFER PATIENT" means ready.
func get_transfer_hint(stretcher: StretcherController) -> String:
	if is_loading_to_stretcher:
		return "TRANSFERRING..."
	if is_loaded:
		return "PATIENT SECURED"
	if not assessment_started:
		return "ASSESS PATIENT"
	if not is_instance_valid(stretcher):
		return "BRING STRETCHER"
	if not stretcher.is_lowered_for_loading():
		return "LOWER STRETCHER"
	if Vector2(stretcher.linear_velocity.x, stretcher.linear_velocity.z).length() > MAX_STRETCHER_SPEED:
		return "STOP STRETCHER"
	if absf(stretcher.angular_velocity.y) > MAX_STRETCHER_TURN_SPEED:
		return "STOP STRETCHER"

	var patient_position_on_stretcher := stretcher.to_local(global_position)
	if (
		absf(patient_position_on_stretcher.x) > MAX_SIDE_OFFSET
		or absf(patient_position_on_stretcher.z) > MAX_LENGTH_OFFSET
	):
		return "LINE UP STRETCHER"

	# Long axes parallel, either way round.
	var stretcher_forward := Vector2(-stretcher.global_basis.z.x, -stretcher.global_basis.z.z)
	var patient_forward := Vector2(-global_basis.z.x, -global_basis.z.z)
	if stretcher_forward.length_squared() < 0.001 or patient_forward.length_squared() < 0.001:
		return "ALIGN STRETCHER"
	var alignment := absf(stretcher_forward.normalized().dot(patient_forward.normalized()))
	if alignment < cos(MAX_ALIGNMENT_ANGLE_RADIANS):
		return "ALIGN STRETCHER"
	return "TRANSFER PATIENT"


func can_transfer_to(stretcher: StretcherController) -> bool:
	return get_transfer_hint(stretcher) == "TRANSFER PATIENT"


## Starts the transfer. Collisions are turned off now; the reparent waits until after
## the physics step.
func transfer_to_stretcher(stretcher: StretcherController) -> bool:
	if not can_transfer_to(stretcher):
		return false
	var deck_assembly := stretcher.get_node_or_null("DeckAssembly") as Node3D
	if deck_assembly == null:
		return false

	is_loading_to_stretcher = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var interaction_area := get_node_or_null("InteractionArea") as Area3D
	if interaction_area != null:
		interaction_area.set_deferred("collision_layer", 0)
		interaction_area.set_deferred("monitorable", false)
	call_deferred("_finish_stretcher_transfer", deck_assembly, stretcher)
	return true


func _finish_stretcher_transfer(deck_assembly: Node3D, stretcher: StretcherController) -> void:
	if not is_instance_valid(deck_assembly) or not is_instance_valid(stretcher):
		is_loading_to_stretcher = false
		return
	reparent(deck_assembly, true)
	var transfer_tween := create_tween()
	transfer_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	transfer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transfer_tween.tween_property(self, "position", TRANSFER_DECK_POSITION, TRANSFER_TIME)
	transfer_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, TRANSFER_TIME)
	transfer_tween.finished.connect(_on_stretcher_transfer_finished.bind(stretcher))


func _on_stretcher_transfer_finished(stretcher: StretcherController) -> void:
	is_loading_to_stretcher = false
	is_loaded = true
	stretcher.mass += mass  # pushing feels heavier with the patient aboard
	GameState.record_event("patient_secured_to_stretcher")


# ======================================================================================
# Status panel text
# ======================================================================================

func get_hud_text() -> String:
	if is_loading_to_stretcher:
		return "Transferring mannequin to the stretcher..."
	if is_loaded:
		return "MANNEQUIN SECURED ON STRETCHER\nRaise the deck and transport it to the ambulance."
	if not assessment_started:
		return "TRAINING CASE 01\nFind the mannequin and tap ASSESS PATIENT."

	return (
		"TRAINING CASE 01\n"
		+ "Assessment recorded. Lower and line up the stretcher beside the mannequin, then tap TRANSFER.\n"
		+ "Clinical findings and protocols await maintainer and clinician review."
	)
