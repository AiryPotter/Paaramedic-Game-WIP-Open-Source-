extends StaticBody3D
class_name TrainingPatient

## Static training mannequin used for the first patient-assessment interaction.

@export var heart_rate_bpm: int = 112
@export var respiratory_rate_per_minute: int = 28
@export_range(0, 100, 1) var oxygen_saturation_percent: int = 91

var assessment_complete: bool = false


func assess_patient() -> void:
	assessment_complete = true


func get_hud_text() -> String:
	if not assessment_complete:
		return "TRAINING CASE 01\nFind the patient and tap ASSESS PATIENT."

	var vitals_text := "Pulse %d bpm  •  RR %d/min  •  SpO₂ %d%%" % [
		heart_rate_bpm,
		respiratory_rate_per_minute,
		oxygen_saturation_percent
	]
	return (
		"TRAINING CASE 01 • INITIAL ASSESSMENT\n"
		+ "Alert; reports breathing discomfort.\n"
		+ vitals_text
		+ "\nSimulated training values, not clinical guidance."
	)
