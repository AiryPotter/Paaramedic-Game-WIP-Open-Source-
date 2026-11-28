extends Resource
class_name ScenarioDefinition

## Data-only scenario metadata. Clinical findings and actions must come from approved content.

@export var scenario_id: String = ""
@export var title: String = ""
@export var location: String = ""
@export_multiline var briefing: String = ""
@export_multiline var patient_case: String = ""
@export var objectives: PackedStringArray = PackedStringArray()
@export var objective_event_names: PackedStringArray = PackedStringArray()
@export var hazards: PackedStringArray = PackedStringArray()
@export var scoring_criteria: Dictionary = {}
