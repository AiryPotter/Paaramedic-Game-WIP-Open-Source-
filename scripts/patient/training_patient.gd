extends HoldableObject
class_name TrainingPatient

## Neutral training mannequin with physical pickup and forgiving stretcher loading.
## Clinical case data is intentionally omitted until supplied and reviewed.

var assessment_started: bool = false
var is_loaded: bool = false


func assess_patient() -> void:
	assessment_started = true


func can_load_onto(stretcher: Node3D) -> bool:
	if not assessment_started or is_loaded or is_held or not is_instance_valid(stretcher):
		return false
	if not stretcher.has_method("is_lowered_for_loading"):
		return false
	return bool(stretcher.call("is_lowered_for_loading"))


func pick_up(hold_transform: Transform3D) -> void:
	if is_loaded or is_held or not assessment_started:
		return
	var interaction_area := $InteractionArea as Area3D
	interaction_area.set_deferred("collision_layer", 0)
	interaction_area.set_deferred("monitorable", false)
	super.pick_up(hold_transform)


func release(hold_transform: Transform3D, inherited_velocity: Vector3) -> void:
	if not is_held:
		return
	super.release(hold_transform, inherited_velocity)
	if not is_loaded:
		var interaction_area := $InteractionArea as Area3D
		interaction_area.set_deferred("collision_layer", 2)
		interaction_area.set_deferred("monitorable", true)


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
	call_deferred("_finish_stretcher_load", deck_assembly)
	return true


func _finish_stretcher_load(deck_assembly: Node3D) -> void:
	if not is_instance_valid(deck_assembly):
		return
	reparent(deck_assembly, true)
	var transfer_tween := create_tween()
	transfer_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	transfer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transfer_tween.tween_property(self, "position", Vector3(0.0, 0.75, 0.0), 0.45)
	transfer_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.45)


func get_hud_text() -> String:
	if is_loaded:
		return "PATIENT LOADED\nRaise the stretcher before transport."
	if not assessment_started:
		return "TRAINING CASE 01\nFind the patient and tap ASSESS PATIENT."

	return (
		"TRAINING CASE 01\n"
		+ "Assessment recorded. Lower the stretcher, then toss the mannequin onto the deck.\n"
		+ "Clinical findings and protocols await maintainer and clinician review."
	)
