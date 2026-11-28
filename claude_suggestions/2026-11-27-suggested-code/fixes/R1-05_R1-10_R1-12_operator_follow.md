# Operator following, gravity, and stick input across mode changes

**Source:** Code review 1, items 5, 10 and 12 · **Status:** Open · **Priority:** Medium to High
**Files:** `scripts/player/player_controller.gd`, `scripts/interaction/pickup_interactor.gd`
**Written against:** `9ae595b`. Untested. Each part can be picked on its own.

---

## Item 5. Walk to the stretcher instead of being yanked (and let go if blocked)
**Why:** the player's follow velocity is `gap / delta`, so a grab from 5.5 m asks for over 300 m/s. If an obstacle stops the player, the stretcher still drives away. (The 5.5 m reach is a maintainer decision and stays.)

In `player_controller.gd`, add:
```gdscript
const MAX_FOLLOW_SPEED: float = 5.0   # m/s while walking to the handle
const ARRIVE_DISTANCE: float = 0.25   # within this, driving is allowed
const LEAVE_DISTANCE: float = 1.5     # after arriving, a bigger gap means the player was blocked
var _operator_arrived: bool = false
```
In `enter_stretcher_mode()`, add:
```gdscript
	_operator_arrived = false
```
Replace the stretcher block at the top of `_physics_process()` with:
```gdscript
	if is_instance_valid(grabbed_stretcher):
		rotation.y = grabbed_stretcher.rotation.y + _stretcher_facing_yaw_offset
		var target_position: Vector3 = grabbed_stretcher.call("get_operator_position")
		var to_target := target_position - global_position
		to_target.y = 0.0
		var gap := to_target.length()
		if gap <= ARRIVE_DISTANCE:
			_operator_arrived = true
		elif _operator_arrived and gap > LEAVE_DISTANCE:
			# Blocked by something: let go rather than letting the stretcher leave without us.
			$Interactor.call("force_release_stretcher")
			return
		var follow_velocity := (to_target / maxf(delta, 0.001)).limit_length(MAX_FOLLOW_SPEED)
		velocity.x = follow_velocity.x
		velocity.z = follow_velocity.z
		# Item 12: keep gravity while operating.
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		var drive_input := _combined_movement_input() if _operator_arrived else Vector2.ZERO
		grabbed_stretcher.call("set_operator_input", drive_input)
		move_and_slide()
		return
```
In `pickup_interactor.gd`, add:
```gdscript
func force_release_stretcher() -> void:
	if is_instance_valid(grabbed_stretcher):
		grabbed_stretcher.call("release", player)
	grabbed_stretcher = null
```

---

## Item 12. Gravity and ground height while operating
Covered by the `velocity.y` lines above. `get_operator_position()` in the stretcher still sets `y = 0.0`, which is fine because `to_target.y` is ignored. Remove that line from `get_operator_position()` later, when ramps or the ambulance floor are added.

---

## Item 10. Stick input when entering and leaving stretcher mode
**Why:** entering keeps the old stick value, so a held stick drives at once. Leaving clears it while the finger is still down, so walking stops until the finger moves.

Fix: after a mode change, ignore the stick until it returns to center.

In `player_controller.gd`, add:
```gdscript
var _wait_for_stick_center: bool = false
```
Replace `set_movement_input()`:
```gdscript
func set_movement_input(input_vector: Vector2) -> void:
	var adjusted := _apply_movement_deadzone(input_vector)
	if _wait_for_stick_center:
		if adjusted == Vector2.ZERO:
			_wait_for_stick_center = false
		movement_input = Vector2.ZERO
		return
	movement_input = adjusted
```
In both `enter_stretcher_mode()` and `exit_stretcher_mode()`, add:
```gdscript
	_wait_for_stick_center = movement_input != Vector2.ZERO
	movement_input = Vector2.ZERO
```
(and remove the old `movement_input = Vector2.ZERO` line in `exit_stretcher_mode()`).

Lifting the finger sends `Vector2.ZERO`, which also clears the wait.

## Test
- Grab from 5 m: the player walks over in about a second, then the stick drives.
- Drive into a wall so the player is blocked: the player lets go.
- Hold the stick while grabbing: nothing moves until you re-center it. Same when releasing.
