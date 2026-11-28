# Review 1 item 6. Don't release items inside or through obstacles

**Source:** Code review 1, item 6 (also noted in reviews 2 and 4) · **Status:** Open · **Priority:** High
**File:** `scripts/interaction/pickup_interactor.gd` · **Written against:** `9ae595b`. Untested.

**Why:** held items have no collision. Releasing one while it is pushed into a wall or the floor drops it inside or beyond the obstacle. The physics engine then shoves it out fast, which can also crack the KOLE by mistake.

**How:** before letting go, sweep the item's own shape from the camera to the hold point and stop at the last clear spot.

Add this function:
```gdscript
## Returns where the held item can safely be released, moving it back toward the camera
## if the hold point is inside or behind an obstacle.
func _safe_release_transform(target: Transform3D) -> Transform3D:
	if not is_instance_valid(held_object):
		return target
	var shape_node: CollisionShape3D = null
	for child in held_object.get_children():
		if child is CollisionShape3D:
			shape_node = child as CollisionShape3D
			break
	if shape_node == null or shape_node.shape == null:
		return target

	var start := target
	start.origin = player_camera.global_position
	var motion := target.origin - start.origin

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = start * shape_node.transform
	query.motion = motion
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid(), held_object.get_rid()]

	var result := player.get_world_3d().direct_space_state.cast_motion(query)
	if result.size() < 2 or result[0] >= 1.0:
		return target
	var safe := target
	safe.origin = start.origin + motion * maxf(result[0] - 0.02, 0.0)
	return safe
```

Use it in both release paths:
```gdscript
func _release_held_object() -> void:
	if not is_instance_valid(held_object):
		held_object = null
		return

	held_object.release(_safe_release_transform(hold_point.global_transform), player.velocity * 0.25)
	held_object = null


func _toss_held_object() -> void:
	var forward := -player_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var toss_velocity := (forward + Vector3.UP * 0.35).normalized() * maximum_toss_speed
	held_object.release(_safe_release_transform(hold_point.global_transform), toss_velocity)
	held_object = null
```

**Note:** in stretcher mode the camera is behind the player. Items cannot be held while operating the stretcher, so this does not come up.

**Test:** hold a bag against an obstacle and drop it; it lands in front of the obstacle. Look steeply down and drop; it does not sink into the floor. Drop the KOLE against a wall; it does not crack.
