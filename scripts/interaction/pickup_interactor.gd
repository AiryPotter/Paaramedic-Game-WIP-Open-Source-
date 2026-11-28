extends Node
class_name PickupInteractor

## What the player is aiming at, and what the action buttons do with it.
##
##   - The touch UI calls request_*() when a button is tapped. The request is carried out
##     on the next physics tick, so it never races the physics engine.
##   - Only one request is kept at a time; a newer tap replaces an older one.
##   - get_*_label(), get_status_text() and can_*() tell the UI what each button and the
##     status panel should say, and whether a button is enabled.
## Child of the Player node. See documentation/ARCHITECTURE.md.

enum Request { NONE, INTERACT, TOSS, PUSH, CHANGE_HEIGHT }

@export var bag_interaction_distance: float = 2.8       ## m reach for bags, KOLE and the patient
@export var stretcher_interaction_distance: float = 5.5 ## m reach for the stretcher (maintainer decision)
@export_range(0.5, 4.0, 0.1) var maximum_toss_speed: float = 2.8

const PATIENT_AIM_LAYER: int = 2           ## the patient's InteractionArea is on layer 2
const TOSS_UPWARD_SHARE: float = 0.35      ## gives tosses a slight arc
const DROP_INHERITED_VELOCITY: float = 0.25 ## share of walking speed a dropped item keeps

var player: PlayerController
var player_camera: Camera3D
var hold_point: Node3D
var held_object: HoldableObject             ## item in hand, or null
var grabbed_stretcher: StretcherController   ## stretcher being operated, or null

var _pending_request: Request = Request.NONE
var _aimed_collider: Object                 ## what the center of the screen points at
var _aimed_distance: float = INF
var _training_patient: TrainingPatient
var _stretcher: StretcherController         ## the scene's stretcher, for patient hints
var _ambulance: AmbulanceController         ## may be null in scenes without one


func _ready() -> void:
	player = get_parent() as PlayerController
	player_camera = player.get_node("Camera3D") as Camera3D
	hold_point = player_camera.get_node("HoldPoint") as Node3D
	_training_patient = get_tree().get_first_node_in_group("training_patient") as TrainingPatient
	_stretcher = get_tree().get_first_node_in_group("grabbable_stretcher") as StretcherController
	_ambulance = get_tree().get_first_node_in_group("ambulance") as AmbulanceController


# ======================================================================================
# Requests from the touch UI
# ======================================================================================

func request_interaction() -> void:
	_pending_request = Request.INTERACT


func request_toss() -> void:
	if is_instance_valid(held_object):
		_pending_request = Request.TOSS


func request_push() -> void:
	if is_instance_valid(grabbed_stretcher):
		_pending_request = Request.PUSH


func request_height_toggle() -> void:
	if can_change_stretcher_height():
		_pending_request = Request.CHANGE_HEIGHT


func toggle_front_caster_lock() -> void:
	if is_instance_valid(grabbed_stretcher):
		grabbed_stretcher.toggle_front_caster_lock()


func toggle_rear_caster_lock() -> void:
	if is_instance_valid(grabbed_stretcher):
		grabbed_stretcher.toggle_rear_caster_lock()


# ======================================================================================
# Button labels and states for the touch UI
# ======================================================================================

func has_held_object() -> bool:
	return is_instance_valid(held_object)


func is_stretcher_grabbed() -> bool:
	return is_instance_valid(grabbed_stretcher)


## Always false: the right-hand pad orbits the camera while operating the stretcher.
## (Kept because ui/mobile_controls.gd still checks it.)
func look_control_moves() -> bool:
	return false


## Text for the main INTERACT button, based on what is held or aimed at.
func get_action_label() -> String:
	if is_instance_valid(held_object):
		return "DROP ITEM"
	if is_instance_valid(grabbed_stretcher):
		if is_instance_valid(_ambulance):
			var load_action := _ambulance.get_load_action_label(grabbed_stretcher)
			if not load_action.is_empty():
				return load_action
		return "RELEASE STRETCHER"
	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		if _aimed_distance > bag_interaction_distance:
			return "APPROACH PATIENT"
		if patient.is_loaded:
			return "PATIENT SECURED"
		if not patient.assessment_started:
			return "ASSESS PATIENT"
		return patient.get_transfer_hint(_stretcher)
	return "INTERACT"


## Text for the status panel at the top of the screen. Walks through the mission in
## order: transfer, ambulance loading, then the patient's own text.
func get_status_text() -> String:
	if is_instance_valid(_training_patient) and _training_patient.is_loading_to_stretcher:
		return "Transferring the mannequin onto the stretcher..."
	if is_instance_valid(_stretcher) and _stretcher.is_being_loaded:
		return "Loading the stretcher into the ambulance..."
	if is_instance_valid(_stretcher) and _stretcher.is_loaded_in_ambulance:
		return "Mission complete. The stretcher is secured in the ambulance."
	if is_instance_valid(_training_patient) and _training_patient.is_loaded:
		if is_instance_valid(grabbed_stretcher) and is_instance_valid(_ambulance):
			var loading_hint := _ambulance.get_loading_hint(grabbed_stretcher)
			if not loading_hint.is_empty():
				return "Ambulance loading: %s" % loading_hint
		if is_instance_valid(_stretcher) and _stretcher.is_lowered:
			return "Mannequin secured. Raise the stretcher deck before transport."
		return "Mannequin secured. Wheel the stretcher to the ambulance rear."
	if not is_instance_valid(_training_patient):
		return "TRAINING CASE 01\nFind the patient and assess them."
	if not _training_patient.assessment_started:
		return _training_patient.get_hud_text()
	if not is_instance_valid(_stretcher):
		return "Assessment recorded. Bring the stretcher to the mannequin."
	var transfer_hint := _training_patient.get_transfer_hint(_stretcher)
	match transfer_hint:
		"LOWER STRETCHER":
			return "Assessment recorded. Lower the stretcher before transfer."
		"STOP STRETCHER":
			return "Stop the stretcher before transferring the mannequin."
		"LINE UP STRETCHER":
			return "Bring the lowered stretcher alongside the mannequin and line up its center."
		"ALIGN STRETCHER":
			return "Align the stretcher's long axis with the mannequin."
		"TRANSFER PATIENT":
			return "Stretcher aligned. Tap TRANSFER to move the mannequin onto it."
		"BRING STRETCHER":
			return "Assessment recorded. Bring the stretcher alongside the mannequin."
	return "Assessment recorded. %s." % transfer_hint.capitalize()


func can_change_stretcher_height() -> bool:
	return is_instance_valid(grabbed_stretcher) and grabbed_stretcher.can_change_height()


func get_stretcher_height_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return grabbed_stretcher.get_height_action_label()
	return "LOWER"


func can_push_stretcher() -> bool:
	return is_instance_valid(grabbed_stretcher) and grabbed_stretcher.can_push_from_operator(player)


func get_push_label() -> String:
	if is_instance_valid(grabbed_stretcher) and grabbed_stretcher.is_lowered:
		return "RAISE TO MOVE"
	return "PUSH" if can_push_stretcher() else "FACE ALONG TO PUSH"


func get_front_lock_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return grabbed_stretcher.get_front_lock_label()
	return "FRONT: FREE"


func get_rear_lock_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return grabbed_stretcher.get_rear_lock_label()
	return "REAR: FREE"


# ======================================================================================
# Physics tick: carry out the pending request
# ======================================================================================

func _physics_process(_delta: float) -> void:
	_refresh_aim_target()
	if is_instance_valid(held_object):
		held_object.follow_hold_point(hold_point.global_transform)

	var request := _pending_request
	_pending_request = Request.NONE
	match request:
		Request.CHANGE_HEIGHT:
			if is_instance_valid(grabbed_stretcher):
				grabbed_stretcher.toggle_height()
		Request.PUSH:
			_push_stretcher()
		Request.TOSS:
			if is_instance_valid(held_object):
				_toss_held_object()
		Request.INTERACT:
			_interact()


## INTERACT does one thing, in this order: drop what is held; while operating the
## stretcher, LOAD it into the ambulance if lined up, otherwise let go; or act on what
## is aimed at.
func _interact() -> void:
	if is_instance_valid(held_object):
		_release_held_object()
	elif is_instance_valid(grabbed_stretcher):
		if _try_load_stretcher():
			return
		grabbed_stretcher.release(player)
		grabbed_stretcher = null
	else:
		_try_pick_up_object()


## Casts a ray from the camera's center up to the stretcher reach, hitting bodies and the
## patient's interaction area.
func _refresh_aim_target() -> void:
	_aimed_collider = null
	_aimed_distance = INF
	var origin := player_camera.global_position
	var forward := -player_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * stretcher_interaction_distance,
		player.collision_mask | PATIENT_AIM_LAYER,
		[player.get_rid()]
	)
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_aimed_collider = hit.get("collider")
	_aimed_distance = origin.distance_to(hit.get("position"))


## The patient if the ray hit the patient or any of its child areas.
func _get_aimed_patient() -> TrainingPatient:
	if not _aimed_collider is Node:
		return null
	var target := _aimed_collider as Node
	while target != null:
		if target is TrainingPatient:
			return target as TrainingPatient
		target = target.get_parent()
	return null


func _try_pick_up_object() -> void:
	if not is_instance_valid(_aimed_collider):
		return

	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		# Patients are never picked up: first ASSESS, then TRANSFER when lined up.
		if _aimed_distance > bag_interaction_distance:
			return
		if not patient.assessment_started:
			patient.assess_patient()
			return
		patient.transfer_to_stretcher(_stretcher)
		return

	if _aimed_collider is HoldableObject:
		if _aimed_distance <= bag_interaction_distance:
			held_object = _aimed_collider as HoldableObject
			held_object.pick_up(hold_point.global_transform)
	elif _aimed_collider is StretcherController:
		var stretcher := _aimed_collider as StretcherController
		if _aimed_distance <= stretcher_interaction_distance and stretcher.grab(player):
			grabbed_stretcher = stretcher


## LOAD: only when the ambulance says the stretcher is lined up at its rear.
func _try_load_stretcher() -> bool:
	if not is_instance_valid(grabbed_stretcher) or not is_instance_valid(_ambulance):
		return false
	if _ambulance.get_load_action_label(grabbed_stretcher).is_empty():
		return false
	if not _ambulance.load_stretcher(grabbed_stretcher):
		return false
	grabbed_stretcher = null  # the stretcher released the operator itself
	return true


func _push_stretcher() -> void:
	if not is_instance_valid(grabbed_stretcher):
		grabbed_stretcher = null
		return
	if not can_push_stretcher():
		return

	var stretcher_to_push := grabbed_stretcher
	grabbed_stretcher = null
	stretcher_to_push.push_from_operator(player)


func _release_held_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return

	held_object.release(hold_point.global_transform, player.velocity * DROP_INHERITED_VELOCITY)
	held_object = null


func _toss_held_object() -> void:
	var forward := -player_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var toss_velocity := (forward + Vector3.UP * TOSS_UPWARD_SHARE).normalized() * maximum_toss_speed
	held_object.release(hold_point.global_transform, toss_velocity)
	held_object = null
