# Code Already Applied (archive)

**What this is:** every code sketch from Claude Code's earlier files that ChatGPT has already applied, so that "everything ever suggested" is in one place. **Do not apply these again.** They are copied exactly as first written, so details may differ from the current game.

Checked against game code at `9ae595b`. One item (C1) was never applied because it is not needed yet.

## A1. One steering formula for wheels and yaw (item 3)

**From:** Code review 1 (`2026-11-25-code-review.md`) · **Status:** Applied

```gdscript
# drive_speed: signed speed along local -Z.
# steer: signed caster angle in radians; positive rotates the caster left.
# wheelbase = 1.44 (casters at z = -0.72 and +0.72). Positive yaw is left.
var yaw_rate := drive_speed * tan(steer) / wheelbase  # front pair steers
# If the rear pair steers: -drive_speed * tan(steer) / wheelbase
```

## A1 (part 2). One steering formula for wheels and yaw (item 3)

**From:** Code review 1 (`2026-11-25-code-review.md`) · **Status:** Applied

```gdscript
var steer := -lateral_input * max_steer_angle  # try 0.4 radians
# Ease the free casters toward rotation.y = steer. Do not flip it in reverse;
# the sign of drive_speed already reverses the turn.
```

## A2. Drive along the stretcher when locked, and side steering (item 4)

**From:** Code review 1 (`2026-11-25-code-review.md`) · **Status:** Applied

```gdscript
var desired_local := operator_forward_local * longitudinal_input + operator_right_local * lateral_input
var drive_speed := -desired_local.z * maximum_speed  # along local -Z
```

## A2 (part 2). Drive along the stretcher when locked, and side steering (item 4)

**From:** Code review 1 (`2026-11-25-code-review.md`) · **Status:** Applied

```gdscript
# Side operators, exactly one pair locked. desired_local and drive_speed as above.
# Near zero speed, keep the previous steer value.
if absf(drive_speed) > 0.05:
	steer = -desired_local.x * signf(drive_speed) * max_steer_angle
# Then use the same yaw formulas as item 3.
```

## A3. Wheel rules while coasting (item 11)

**From:** Code review 1 (`2026-11-25-code-review.md`) · **Status:** Applied (moved into `_integrate_forces` by review 2 N1)

```gdscript
# Casters are at z = -0.72 (front) and +0.72 (rear).
# Locked means swivel lock, not a brake: forward rolling is kept.
func _apply_wheel_constraints() -> void:
	if are_both_casters_unlocked():
		return
	var local_velocity := global_basis.inverse() * linear_velocity
	if front_casters_locked and rear_casters_locked:
		angular_velocity.y = 0.0
		local_velocity.x = 0.0
	else:
		var axle_z := -0.72 if front_casters_locked else 0.72
		# No sideways motion at the locked axle: v.x + yaw_rate * axle_z = 0
		local_velocity.x = -angular_velocity.y * axle_z
	linear_velocity = global_basis * local_velocity
```

## A4. Release a stale touch index (N6)

**From:** Code review 2 (`2026-11-25-code-review-2.md`) · **Status:** Applied

```gdscript
# After the not-pressed check in _handle_touch:
if event.index == joystick_touch_id or event.index == look_touch_id:
	_release_touch(event.index)
```

## A5. Operator facing from the chosen handle (N5)

**From:** Code review 2 (`2026-11-25-code-review-2.md`) · **Status:** Applied

```gdscript
operator_forward_local = Vector3(-operator_offset.x, 0.0, -operator_offset.z).normalized()
operator_facing_yaw_offset = atan2(-operator_forward_local.x, -operator_forward_local.z)
```

## A6. KOLE cracks on a hard impact (N11)

**From:** Code review 2 (`2026-11-25-code-review-2.md`) · **Status:** Applied (plus the pad check, A9)

```gdscript
@export var crack_speed_change: float = 3.0  # tune on device
var _previous_velocity: Vector3 = Vector3.ZERO

func release(hold_transform: Transform3D, inherited_velocity: Vector3) -> void:
	super.release(hold_transform, inherited_velocity)
	_previous_velocity = inherited_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Contacts are from the last step, so compare this velocity with the previous one.
	if not screen_cracked and state.get_contact_count() > 0:
		if (state.linear_velocity - _previous_velocity).length() >= crack_speed_change:
			screen_cracked = true
			$CrackedScreen.set_deferred("visible", true)
	_previous_velocity = state.linear_velocity
```

## A7. Stuck items predict the stretcher's next pose (R1)

**From:** Code review 3 (`2026-11-25-code-review-3.md`) · **Status:** Applied

```gdscript
func _follow_stuck_surface(delta: float = 0.0) -> void:
	if not is_instance_valid(stuck_to):
		unstick_from_surface()
		return
	var surface := stuck_to.global_transform
	surface.origin += stuck_to.linear_velocity * delta
	surface.basis = Basis(Vector3.UP, stuck_to.angular_velocity.y * delta) * surface.basis
	global_transform = surface * _stuck_local_transform

func _physics_process(delta: float) -> void:
	if is_stuck:
		_follow_stuck_surface(delta)
```

## A8. Sticky pad: stick, unstick, follow (feature plan 2)

**From:** Feature plan (`2026-11-25-feature-plan.md`) · **Status:** Applied (sensor size later changed; see fix S2)

```gdscript
# HoldableObject (sketch to test)
var stuck_to: PhysicsBody3D
var _stuck_local: Transform3D
var _unstuck_mask: int

func stick_to(body: PhysicsBody3D, local_transform: Transform3D) -> void:
	if is_held or is_instance_valid(stuck_to):
		return
	stuck_to = body
	_stuck_local = local_transform
	_unstuck_mask = collision_mask
	collision_mask = 0  # keep the layer so the pickup ray still finds it
	add_collision_exception_with(body)
	body.add_collision_exception_with(self)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true

func unstick() -> void:
	if not is_instance_valid(stuck_to):
		stuck_to = null
		return
	remove_collision_exception_with(stuck_to)
	stuck_to.remove_collision_exception_with(self)
	collision_mask = _unstuck_mask
	stuck_to = null

func follow_surface() -> void:  # the stretcher calls this after its own movement
	if is_instance_valid(stuck_to):
		global_transform = stuck_to.global_transform * _stuck_local
```

## A9. KOLE: landing on the pad never cracks it (feature plan 2)

**From:** Feature plan (`2026-11-25-feature-plan.md`) · **Status:** Applied

```gdscript
# In Defibrillator. PAD_TOP_LOCAL_Y = 0.82; keep it in step with the pad's height.
func _is_touching_pad(state: PhysicsDirectBodyState3D) -> bool:
	for i in range(state.get_contact_count()):
		var body := state.get_contact_collider_object(i) as Node3D
		if body != null and body.is_in_group("grabbable_stretcher"):
			var local_point := body.to_local(state.get_contact_collider_position(i))
			if local_point.y >= PAD_TOP_LOCAL_Y - 0.03:
				return true
	return false
```

## C1. Slow down in tight turns (feature plan 4)

**From:** Feature plan (`2026-11-25-feature-plan.md`) · **Status:** **Conditional, not applied:** not needed at the current 0.6 rad steer angle. Add only if the angle goes above about 0.72 rad.

```gdscript
var turn_factor := absf(tan(_current_steer_angle)) / WHEELBASE
if turn_factor > 0.001:
	var allowed_speed := maximum_turn_speed / turn_factor  # about 1.2 m/s at full lock
	drive_speed = clampf(drive_speed, -allowed_speed, allowed_speed)
# Set target_horizontal_velocity AFTER this limit.
```

## A10. Both pairs free: swing and slide (feature plan 4)

**From:** Feature plan (`2026-11-25-feature-plan.md`) · **Status:** Applied

```gdscript
# Both free, end operator only. Positive yaw is left.
if absf(operator_offset.z) > absf(operator_offset.x):
	target_turn_speed = signf(operator_offset.z) * desired_local.x * maximum_turn_speed
	# Reduce the sideways slide so the swing is noticeable.
	desired_local.x *= 0.5
```
