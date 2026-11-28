extends Node
class_name PickupInteractor

## Queues touch-triggered pickup/release requests for the physics tick.

@export var bag_interaction_distance: float = 2.8
@export var stretcher_interaction_distance: float = 5.5
@export_range(0.5, 4.0, 0.1) var maximum_toss_speed: float = 2.8

var player: CharacterBody3D
var player_camera: Camera3D
var hold_point: Node3D
var held_object: HoldableObject
var grabbed_stretcher: RigidBody3D
var _interaction_requested: bool = false
var _toss_requested: bool = false
var _push_requested: bool = false
var _aimed_collider: Object
var _aimed_distance: float = INF
var _training_patient: Node
var _stretcher: RigidBody3D
var _ambulance: Node3D
var _height_toggle_requested: bool = false


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	player_camera = player.get_node("Camera3D") as Camera3D
	hold_point = player_camera.get_node("HoldPoint") as Node3D
	_training_patient = get_tree().get_first_node_in_group("training_patient")
	_stretcher = get_tree().get_first_node_in_group("grabbable_stretcher") as RigidBody3D
	_ambulance = get_tree().get_first_node_in_group("ambulance") as Node3D


func request_interaction() -> void:
	_interaction_requested = true
	_toss_requested = false
	_push_requested = false
	_height_toggle_requested = false


func request_toss() -> void:
	if is_instance_valid(held_object):
		_toss_requested = true
		_interaction_requested = false
		_push_requested = false
		_height_toggle_requested = false


func request_push() -> void:
	if is_instance_valid(grabbed_stretcher):
		_push_requested = true
		_interaction_requested = false
		_toss_requested = false
		_height_toggle_requested = false


func can_change_stretcher_height() -> bool:
	return (
		is_instance_valid(grabbed_stretcher)
		and bool(grabbed_stretcher.call("can_change_height"))
	)


func get_stretcher_height_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return str(grabbed_stretcher.call("get_height_action_label"))
	return "LOWER"


func request_height_toggle() -> void:
	if is_instance_valid(grabbed_stretcher) and can_change_stretcher_height():
		_height_toggle_requested = true
		_interaction_requested = false
		_toss_requested = false
		_push_requested = false


func can_push_stretcher() -> bool:
	return (
		is_instance_valid(grabbed_stretcher)
		and bool(grabbed_stretcher.call("can_push_from_operator", player))
	)


func get_push_label() -> String:
	if is_instance_valid(grabbed_stretcher) and bool(grabbed_stretcher.get("is_lowered")):
		return "RAISE TO MOVE"
	return "PUSH" if can_push_stretcher() else "FACE ALONG TO PUSH"


func has_held_object() -> bool:
	return is_instance_valid(held_object)


func is_stretcher_grabbed() -> bool:
	return is_instance_valid(grabbed_stretcher)


func look_control_moves() -> bool:
	# Keep the right-side pad available for camera orbit while operating the stretcher.
	return false


func get_front_lock_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return str(grabbed_stretcher.call("get_front_lock_label"))
	return "FRONT: FREE"


func get_rear_lock_label() -> String:
	if is_instance_valid(grabbed_stretcher):
		return str(grabbed_stretcher.call("get_rear_lock_label"))
	return "REAR: FREE"


func toggle_front_caster_lock() -> void:
	if is_instance_valid(grabbed_stretcher):
		grabbed_stretcher.call("toggle_front_caster_lock")


func toggle_rear_caster_lock() -> void:
	if is_instance_valid(grabbed_stretcher):
		grabbed_stretcher.call("toggle_rear_caster_lock")


func get_action_label() -> String:
	if is_instance_valid(held_object):
		return "DROP ITEM"
	if is_instance_valid(grabbed_stretcher):
		if is_instance_valid(_ambulance):
			var load_action := str(_ambulance.call("get_load_action_label", grabbed_stretcher))
			if not load_action.is_empty():
				return load_action
		return "RELEASE STRETCHER"
	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		if _aimed_distance > bag_interaction_distance:
			return "APPROACH PATIENT"
		if bool(patient.get("is_loaded")):
			return "PATIENT SECURED"
		if not bool(patient.get("assessment_started")):
			return "ASSESS PATIENT"
		if patient.has_method("get_transfer_hint"):
			return str(patient.call("get_transfer_hint", _stretcher))
		return "LINE UP STRETCHER"
	return "INTERACT"


func get_status_text() -> String:
	if is_instance_valid(_training_patient) and bool(_training_patient.get("is_loading_to_stretcher")):
		return "Transferring the mannequin onto the stretcher..."
	if is_instance_valid(_stretcher) and bool(_stretcher.get("is_being_loaded")):
		return "Loading the stretcher into the ambulance..."
	if is_instance_valid(_stretcher) and bool(_stretcher.get("is_loaded_in_ambulance")):
		return "Mission complete. The stretcher is secured in the ambulance."
	if is_instance_valid(_training_patient) and bool(_training_patient.get("is_loaded")):
		if is_instance_valid(grabbed_stretcher) and is_instance_valid(_ambulance):
			var loading_hint := str(_ambulance.call("get_loading_hint", grabbed_stretcher))
			if not loading_hint.is_empty():
				return "Ambulance loading: %s" % loading_hint
		if is_instance_valid(_stretcher) and bool(_stretcher.get("is_lowered")):
			return "Mannequin secured. Raise the stretcher deck before transport."
		return "Mannequin secured. Wheel the stretcher to the ambulance rear."
	if not is_instance_valid(_training_patient) or not _training_patient.has_method("get_hud_text"):
		return "TRAINING CASE 01\nFind the patient and assess them."
	if not bool(_training_patient.get("assessment_started")):
		return str(_training_patient.call("get_hud_text"))
	if not is_instance_valid(_stretcher):
		return "Assessment recorded. Bring the stretcher to the mannequin."
	var transfer_hint := str(_training_patient.call("get_transfer_hint", _stretcher))
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


func _physics_process(_delta: float) -> void:
	_refresh_aim_target()
	if is_instance_valid(held_object):
		held_object.follow_hold_point(hold_point.global_transform)

	if _height_toggle_requested:
		_height_toggle_requested = false
		if is_instance_valid(grabbed_stretcher):
			grabbed_stretcher.call("toggle_height")
		return

	if _push_requested:
		_push_requested = false
		_push_stretcher()
		return

	if _toss_requested:
		_toss_requested = false
		if is_instance_valid(held_object):
			_toss_held_object()
		return

	if not _interaction_requested:
		return
	_interaction_requested = false

	if is_instance_valid(held_object):
		_release_held_object()
	elif is_instance_valid(grabbed_stretcher):
		if _try_load_stretcher():
			return
		grabbed_stretcher.call("release", player)
		grabbed_stretcher = null
	else:
		_try_pick_up_object()


func _refresh_aim_target() -> void:
	_aimed_collider = null
	_aimed_distance = INF
	var origin := player_camera.global_position
	var forward := -player_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * stretcher_interaction_distance,
		player.collision_mask | 2,
		[player.get_rid()]
	)
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_aimed_collider = hit.get("collider")
	_aimed_distance = origin.distance_to(hit.get("position"))


func _get_aimed_patient() -> Node:
	if not _aimed_collider is Node:
		return null
	var target := _aimed_collider as Node
	while target != null:
		if target.is_in_group("training_patient"):
			return target
		target = target.get_parent()
	return null


func _try_pick_up_object() -> void:
	if not is_instance_valid(_aimed_collider):
		return

	var patient := _get_aimed_patient()
	if is_instance_valid(patient):
		if _aimed_distance > bag_interaction_distance:
			return
		if not bool(patient.get("assessment_started")):
			patient.call("assess_patient")
			return
		if patient.has_method("transfer_to_stretcher"):
			patient.call("transfer_to_stretcher", _stretcher)
		return

	var collider: Object = _aimed_collider
	if collider is HoldableObject:
		if _aimed_distance <= bag_interaction_distance:
			held_object = collider as HoldableObject
			held_object.pick_up(hold_point.global_transform)
	elif collider is RigidBody3D and collider.is_in_group("grabbable_stretcher"):
		if _aimed_distance <= stretcher_interaction_distance and bool(collider.call("grab", player)):
			grabbed_stretcher = collider as RigidBody3D


func _try_load_stretcher() -> bool:
	if not is_instance_valid(grabbed_stretcher) or not is_instance_valid(_ambulance):
		return false
	if str(_ambulance.call("get_load_action_label", grabbed_stretcher)).is_empty():
		return false
	var stretcher_to_load := grabbed_stretcher
	if not bool(_ambulance.call("load_stretcher", stretcher_to_load)):
		return false
	grabbed_stretcher = null
	return true


func _push_stretcher() -> void:
	if not is_instance_valid(grabbed_stretcher):
		grabbed_stretcher = null
		return
	if not can_push_stretcher():
		return

	var stretcher_to_push := grabbed_stretcher
	grabbed_stretcher = null
	stretcher_to_push.call("push_from_operator", player)


func _release_held_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return

	held_object.release(hold_point.global_transform, player.velocity * 0.25)
	held_object = null


func _toss_held_object() -> void:
	var forward := -player_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var toss_velocity := (forward + Vector3.UP * 0.35).normalized() * maximum_toss_speed
	held_object.release(hold_point.global_transform, toss_velocity)
	held_object = null
