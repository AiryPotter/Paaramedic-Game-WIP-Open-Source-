# Review 3 R2. Ease items flat when they stick (optional)

**Source:** Code review 3, R2 (and the feature plan's 0.1 s ease) · **Status:** Open · **Priority:** Nit
**File:** `scripts/interaction/holdable_object.gd` · **Written against:** `9ae595b`. Untested.

**Why:** an item touching the pad tilted on a corner teleports flat in one tick. Check on device whether that looks wrong before applying.

Add:
```gdscript
const STICK_EASE_TIME: float = 0.1
var _stick_start_local: Transform3D
var _stick_blend: float = 1.0
```
In `stick_to_surface()`, before `freeze = true`, add:
```gdscript
	_stick_start_local = surface.global_transform.affine_inverse() * global_transform
	_stick_blend = 0.0
```
Replace `_follow_stuck_surface()`:
```gdscript
func _follow_stuck_surface(delta: float = 0.0) -> void:
	if not is_instance_valid(stuck_to):
		unstick_from_surface()
		return

	var local := _stuck_local_transform
	if _stick_blend < 1.0:
		_stick_blend = minf(_stick_blend + delta / STICK_EASE_TIME, 1.0)
		local = _stick_start_local.interpolate_with(_stuck_local_transform, _stick_blend)

	var predicted_surface := stuck_to.global_transform
	predicted_surface.origin += stuck_to.linear_velocity * delta
	predicted_surface.basis = Basis(Vector3.UP, stuck_to.angular_velocity.y * delta) * predicted_surface.basis
	global_transform = predicted_surface * local
```
`stick_to_surface()` calls `_follow_stuck_surface()` with no delta, so the first frame stays at the landing pose, and the next 0.1 s ease it flat.
