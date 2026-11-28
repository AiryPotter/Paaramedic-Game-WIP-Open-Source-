extends Resource
class_name ScenarioData

## One call, stored as a .tres file so new scenarios need no new code.
## STARTER (milestone plan, Milestone 10). Untested.
## Clinical fields stay empty until the maintainer's service protocols are supplied
## and a qualified paramedic or instructor has reviewed them.

@export var scenario_id: String = "case_01"
@export var title: String = "Training case 01"
@export_multiline var dispatch_text: String = ""
@export var location_scene: PackedScene

@export_group("Scene")
@export var scene_is_violent: bool = false          # police needed before entering
@export var has_stairs: bool = false                # tracked stair chair needed
@export var is_vehicle_crash: bool = false
@export var patient_is_trapped: bool = false        # maintainer: no trapped patients yet

@export_group("Backup")
## Units the scenario needs, for example ["ACP", "police"]. Unneeded requests are a
## debrief note only (maintainer decision); missing needed ones lose points.
@export var backup_needed: Array[String] = []
## Placeholder ETAs; set real ones per scenario.
@export var backup_eta_seconds: Dictionary = {"ACP": 300.0, "CCP": 480.0, "police": 240.0}

@export_group("Patient (protocol content only)")
@export var patient_case: Resource                   # filled from approved protocols later

@export_group("Handover")
## MIST items the student should report, written from approved content.
@export var mist_mechanism: String = ""
@export var mist_injuries: String = ""
@export var mist_signs: String = ""
@export var mist_treatment: String = ""
