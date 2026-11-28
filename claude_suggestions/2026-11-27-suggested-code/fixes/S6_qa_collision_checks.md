# S6. QA checks that would have caught the deck bug

**Source:** Code review 4, S6 · **Status:** Open · **Priority:** Medium
**File:** `tests/qa_runner.gd` · **Written against:** `9ae595b`. Untested.

Add this function, and call it from `_run_suite()` right after `_resolve_main_nodes()`:
```gdscript
	await _test_stretcher_collision_shapes()
```

```gdscript
func _test_stretcher_collision_shapes() -> void:
	# 1. Every CollisionShape3D under the stretcher must have a physics body or area as its
	#    direct parent, or Godot ignores it.
	var orphans: Array[String] = []
	var pending: Array[Node] = [_stretcher]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if child is CollisionShape3D and not (child.get_parent() is CollisionObject3D):
				orphans.append(str(_stretcher.get_path_to(child)))
	_record(
		"Stretcher collision shapes are all active",
		orphans.is_empty(),
		"Inactive: " + ", ".join(orphans) if not orphans.is_empty() else ""
	)

	# 2. A ray aimed straight down at the deck center must hit the stretcher itself.
	await _wait_physics_frames(2)
	var deck_center := _stretcher.to_global(Vector3(0.0, 0.73, 0.0))
	var query := PhysicsRayQueryParameters3D.create(
		deck_center + Vector3.UP * 1.5,
		deck_center + Vector3.DOWN * 0.5
	)
	var hit := _stretcher.get_world_3d().direct_space_state.intersect_ray(query)
	# Without the deck collider the ray still hits the low floor support, so check the height too.
	var hit_local_y := _stretcher.to_local(hit.get("position")).y if not hit.is_empty() else -INF
	_record(
		"Ray at the deck hits the deck top",
		not hit.is_empty() and hit.get("collider") == _stretcher and hit_local_y > 0.6,
		"Hit %s at local y %.2f." % [str(hit.get("collider")), hit_local_y] if not hit.is_empty() else "Hit nothing."
	)
```

The ray starts above the deck, so make sure nothing stuck to the pad is at the center when this runs, or it may hit that item first. Running it before the pad tests avoids this.

**Test:** at `9ae595b` both checks should **fail**. After fix S1, both should pass.
