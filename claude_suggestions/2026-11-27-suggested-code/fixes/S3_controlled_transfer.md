# S3. Controlled patient TRANSFER (no tossing, no solo carrying)

**Source:** Code review 4, S3 (maintainer decision: controlled transfer) · **Status:** Open · **Priority:** High
**Files:** `scripts/patient/training_patient.gd` (full replacement below), `scripts/interaction/pickup_interactor.gd`, `scripts/stretcher/stretcher_controller.gd`, `ui/mobile_controls.gd`
**Written against:** `9ae595b`. Untested.

**Behavior:** after ASSESS, the patient cannot be picked up. When the stretcher is lowered, stopped and lined up beside the patient, INTERACT on the patient reads **TRANSFER** and slides the patient onto the deck. Otherwise the button shows what is missing. The loaded patient adds weight to the stretcher.

## Step 1: replace `scripts/patient/training_patient.gd`

Use [`../new_files/training_patient.gd`](../new_files/training_patient.gd) as the whole file.

## Step 2: `scripts/interaction/pickup_interactor.gd`

In `get_action_label()`, replace the patient block:
```gdscript
	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		if _aimed_distance > bag_interaction_distance:
			return "APPROACH PATIENT"
		if bool(patient.get("is_loaded")):
			return "PATIENT LOADED"
		if not bool(patient.get("assessment_started")):
			return "ASSESS PATIENT"
		var hint := str(patient.call("get_transfer_hint", _stretcher))
		return "TRANSFER" if hint.is_empty() else hint
```

Replace `get_status_text()` with:
```gdscript
func get_status_text() -> String:
	if not is_instance_valid(_training_patient) or not _training_patient.has_method("get_hud_text"):
		return "TRAINING CASE 01\nFind the patient and assess them."
	return str(_training_patient.call("get_hud_text", _stretcher))
```

In `_try_pick_up_object()`, replace the patient block:
```gdscript
	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		if _aimed_distance > bag_interaction_distance or bool(patient.get("is_loaded")):
			return
		if not bool(patient.get("assessment_started")):
			patient.call("assess_patient")
			return
		if str(patient.call("get_transfer_hint", _stretcher)).is_empty():
			patient.call("load_onto_stretcher", _stretcher)
		return
```

In `get_action_label()`, the first line can go back to:
```gdscript
	if is_instance_valid(held_object):
		return "DROP ITEM"
```

## Step 3: `scripts/stretcher/stretcher_controller.gd`

In `_stick_holdables_to_pad()`, replace the patient branch:
```gdscript
		if item.is_in_group("training_patient"):
			if item.has_method("can_load_onto") and bool(item.call("can_load_onto", self)):
				item.call("load_onto_stretcher", self)
			continue
```
with:
```gdscript
		if item.is_in_group("training_patient"):
			continue  # The patient is moved only by TRANSFER.
```

## Step 4: `ui/mobile_controls.gd`

Update tooltips that mention tossing the mannequin:
```gdscript
	interaction_button.tooltip_text = "Aim at the patient to assess them, or TRANSFER them onto a lowered, lined-up stretcher."
	toss_button.tooltip_text = "Toss the held item toward the crosshair."
```
(Tooltips only show on iPad with a trackpad or Apple Pencil.)

## Tuning values (in `training_patient.gd`)
- `TRANSFER_MAX_SIDE_DISTANCE = 1.2` m, `TRANSFER_MIN_SIDE_DISTANCE = 0.5` m: how far the stretcher's center may be to the side of the patient's.
- `TRANSFER_MAX_ALONG_OFFSET = 0.5` m: how far it may be shifted toward head or feet.
- `TRANSFER_MAX_ANGLE_DEGREES = 25`: how far the two may be out of line (either direction counts, head-first or feet-first).

## Test
- No PICK UP or TOSS on the patient at any time.
- TRANSFER appears only when lowered, stopped and lined up. Each missing condition shows its own hint.
- The patient slides onto the deck. Raising the stretcher carries them. Pushing feels heavier with the patient on.
