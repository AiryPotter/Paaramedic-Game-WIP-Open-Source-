extends Node
class_name WorldBounds

## Invisible walls around the training floor, plus a reset for anything that falls off.
## Add as a child of Main (scenes/main/main.tscn). Fix R1-15 from Claude Code review 1.
## Written against 9ae595b. Untested.

@export var half_extent: float = 12.0   # training floor is 24 x 24 m
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.5
@export var reset_below_y: float = -5.0

var _start_transforms: Dictionary = {}


func _ready() -> void:
	_build_walls()
	# Remember where each body started, so a fallen one can go back there.
	for child in get_parent().get_children():
		if child is RigidBody3D or child is CharacterBody3D:
			_start_transforms[child] = (child as Node3D).global_transform


func _build_walls() -> void:
	var walls := StaticBody3D.new()
	walls.name = "BoundaryWalls"
	get_parent().add_child.call_deferred(walls)
	var long_side := half_extent * 2.0 + wall_thickness * 2.0
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, -half_extent - wall_thickness * 0.5),
		Vector3(0.0, 0.0, half_extent + wall_thickness * 0.5),
		Vector3(-half_extent - wall_thickness * 0.5, 0.0, 0.0),
		Vector3(half_extent + wall_thickness * 0.5, 0.0, 0.0),
	]
	for index in range(offsets.size()):
		var box := BoxShape3D.new()
		var along_x := index < 2
		box.size = Vector3(
			long_side if along_x else wall_thickness,
			wall_height,
			wall_thickness if along_x else long_side
		)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = offsets[index] + Vector3.UP * wall_height * 0.5
		walls.add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in _start_transforms.keys():
		if not is_instance_valid(body):
			_start_transforms.erase(body)
			continue
		var node := body as Node3D
		if node.global_position.y >= reset_below_y:
			continue
		if body is HoldableObject and ((body as HoldableObject).is_held or (body as HoldableObject).is_stuck):
			continue
		if node.get_parent() != get_parent():
			continue  # Moved under another node (for example a loaded patient); it follows its parent.
		node.global_transform = _start_transforms[body]
		if body is RigidBody3D:
			(body as RigidBody3D).linear_velocity = Vector3.ZERO
			(body as RigidBody3D).angular_velocity = Vector3.ZERO
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
