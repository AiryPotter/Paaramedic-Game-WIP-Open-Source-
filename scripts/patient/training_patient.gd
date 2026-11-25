extends StaticBody3D
class_name TrainingPatient

## Static training mannequin for the patient-interaction prototype.
## Clinical case data is intentionally omitted until supplied and reviewed.

var assessment_started: bool = false


func assess_patient() -> void:
	assessment_started = true


func get_hud_text() -> String:
	if not assessment_started:
		return "TRAINING CASE 01\nFind the patient and tap ASSESS PATIENT."

	return (
		"TRAINING CASE 01\n"
		+ "Patient interaction is working.\n"
		+ "Case findings and clinical steps await maintainer protocols and clinician review."
	)
