extends Node
class_name PickupInteractor

## Queues touch-triggered pickup/release requests for the physics tick.

@export var bag_interaction_distance: float = 2.0
@export var stretcher_interaction_distance: float = 5.5
@export_range(0.5, 4.0, 0.1) var maximum_toss_speed: float = 2.8

var player: CharacterBody3D
var player_camera: Camera3D
var hold_point: Node3D
var held_object: HoldableObject
var grabbed_stretcher: RigidBody3D
var _interaction_requested: bool = false
var _toss_requested: bool = false


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	player_camera = player.get_node("Camera3D") as Camera3D
	hold_point = player_camera.get_node("HoldPoint") as Node3D


func request_interaction() -> void:
	_interaction_requested = true


func request_toss() -> void:
	if is_instance_valid(held_object):
		_toss_requested = true


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
		return "RELEASE STRETCHER"
	return "INTERACT"


func _physics_process(_delta: float) -> void:
	if is_instance_valid(held_object):
		held_object.follow_hold_point(hold_point.global_transform)

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
		grabbed_stretcher.call("release", player)
		grabbed_stretcher = null
	else:
		_try_pick_up_object()


func _try_pick_up_object() -> void:
	var origin := player_camera.global_position
	var forward := -player_camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * stretcher_interaction_distance,
		player.collision_mask,
		[player.get_rid()]
	)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	var hit_position: Vector3 = hit.get("position")
	var hit_distance := origin.distance_to(hit_position)
	if collider is HoldableObject:
		if hit_distance <= bag_interaction_distance:
			held_object = collider as HoldableObject
			held_object.pick_up(hold_point.global_transform)
	elif collider is RigidBody3D and collider.is_in_group("grabbable_stretcher"):
		if hit_distance <= stretcher_interaction_distance and bool(collider.call("grab", player)):
			grabbed_stretcher = collider as RigidBody3D


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
	if held_object.has_method("on_tossed"):
		held_object.call("on_tossed")
	held_object.release(hold_point.global_transform, toss_velocity)
	held_object = null
