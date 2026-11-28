# Stretcher: coasting casters, wheel colliders, leftover state

**Source:** Code review 2, items N4, N7 and N10 · **Status:** Open · **Priority:** Medium to Low
**File:** `scripts/stretcher/stretcher_controller.gd` · **Written against:** `9ae595b`. Untested.
Each part can be picked on its own.

---

## N4. Coasting follows the caster angle
**Why:** with no operator, steering stops being calculated. The body straightens while the casters stay turned, and free casters do not trail the motion.

Add:
```gdscript
const COAST_STEER_RETURN_SPEED: float = 1.5  # rad/s the steering eases back to straight

func _update_coasting_casters(delta: float) -> void:
	var local_velocity := global_basis.inverse() * linear_velocity
	var flat_local := Vector3(local_velocity.x, 0.0, local_velocity.z)
	if are_both_casters_unlocked():
		# Free casters trail the direction of travel.
		if flat_local.length() > 0.05:
			_steer_free_casters(_front_casters, flat_local.normalized(), delta)
			_steer_free_casters(_rear_casters, flat_local.normalized(), delta)
		return
	if front_casters_locked and rear_casters_locked:
		return
	_current_steer_angle = move_toward(_current_steer_angle, 0.0, COAST_STEER_RETURN_SPEED * delta)
	var forward_speed := -local_velocity.z
	var yaw_rate := forward_speed * tan(_current_steer_angle) / WHEELBASE
	if front_casters_locked:
		yaw_rate = -yaw_rate
		_steer_caster_pair_to_angle(_rear_casters, _current_steer_angle, delta)
	else:
		_steer_caster_pair_to_angle(_front_casters, _current_steer_angle, delta)
	if absf(forward_speed) > 0.05:
		angular_velocity.y = clampf(yaw_rate, -maximum_turn_speed, maximum_turn_speed)
```
In `_physics_process()`, call it in the no-operator branch, before `return`:
```gdscript
	if not is_instance_valid(operator):
		operator = null
		operator_input = Vector2.ZERO
		_update_coasting_casters(delta)
		return
```
`_integrate_forces()` still applies the locked-axle rule afterwards.

---

## N7. Stop rewriting the wheel colliders every tick
**Why:** four collider transforms are set every physics tick, which can disturb contacts and costs time. Collision does not need the wheels' yaw.

Replace `_sync_wheel_colliders()`:
```gdscript
func _sync_wheel_colliders() -> void:
	# Position follows the caster (it widens when locked); rotation stays fixed.
	var wheel_basis := Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	for index in range(_front_casters.size()):
		_front_wheel_colliders[index].transform = Transform3D(wheel_basis, _front_casters[index].position)
		_rear_wheel_colliders[index].transform = Transform3D(wheel_basis, _rear_casters[index].position)


func _is_tween_running(tween: Tween) -> bool:
	return is_instance_valid(tween) and tween.is_running()
```
In `_physics_process()`, replace the plain `_sync_wheel_colliders()` call with:
```gdscript
	if _is_tween_running(_front_width_tween) or _is_tween_running(_rear_width_tween):
		_sync_wheel_colliders()
```
In `_animate_caster_pair_width()`, after creating the tween, add one final sync:
```gdscript
	tween.finished.connect(_sync_wheel_colliders)
```
Locking widens the colliders from 0.48 to 0.66. If that pushes into a wall or the player, use one fixed width instead and skip syncing.

---

## N10. Leftover state between grabs and locks
1. Reset steering when a grab starts and when a lock changes. In `grab()`, `_set_front_casters_locked()` and `_set_rear_casters_locked()`, add:
```gdscript
	_current_steer_angle = 0.0
```
2. Remove `can_sleep = true` from `apply_character_bump()`. It is already true whenever there is no operator.
3. Don't shove the player on release. Keep the collision exception until the player is clear of the stretcher:
```gdscript
var _exception_player: CharacterBody3D

func release(player: CharacterBody3D) -> void:
	if not is_instance_valid(operator) or operator != player:
		return
	_exception_player = player  # removed once clear, in _clear_released_player()
	operator.call("exit_stretcher_mode")
	operator = null
	operator_input = Vector2.ZERO
	can_sleep = true


func _clear_released_player() -> void:
	if not is_instance_valid(_exception_player):
		_exception_player = null
		return
	if _exception_player == operator:
		return
	var local := to_local(_exception_player.global_position)
	# Deck is 1.0 x 2.2 m; the player capsule radius is 0.35. Add a little margin.
	if absf(local.x) > 0.95 or absf(local.z) > 1.55:
		remove_collision_exception_with(_exception_player)
		_exception_player = null
```
Call `_clear_released_player()` at the top of `_physics_process()`. In `grab()`, add `_exception_player = null` before `add_collision_exception_with(player)`.

4. Grabbing still stops a rolling stretcher instantly from up to 5.5 m. With the operator-follow fix (`R1-05`), consider stopping it only once `_operator_arrived` is true.
