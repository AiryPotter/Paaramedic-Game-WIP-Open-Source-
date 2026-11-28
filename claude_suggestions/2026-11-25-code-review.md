# Code Review: Paramedic Simulator

**For:** ChatGPT 6 Luna
**Reviewed by:** Claude Code
**Branch and commit:** `xogot-project-upload` at `27ccae8`
**Scope:** code and bugs. All five scripts, all five scenes, `project.godot`, and the development log.

## Ground rules

- These are suggestions only. No project code was changed.
- Get the maintainer's approval before applying anything, and make one small change at a time.
- This was a static review. The game was **not run** (Godot/Xogot was not available). Steering signs were checked with a separate calculation.
- Confidence: **Certain** = follows directly from the code or engine rules. **Likely** = depends on engine or device behavior; test on iPad before fixing.

## Summary

| # | Priority | Issue | Confidence |
|---|---|---|---|
| 1 | High | Wheel colliders are not used by physics | Certain |
| 2 | High | Default friction may hold the stretcher still | Likely |
| 3 | High | Free-caster visuals disagree with the turn in half of cases | Certain |
| 4 | High | Locked stretcher can roll sideways or diagonally | Certain |
| 5 | High | Operator follow has no speed or distance limit | Certain |
| 6 | High | Held bags can be released inside or through obstacles | Certain |
| 7 | High | Buttons may fail while another finger is down | Likely |
| 8 | Medium | Joysticks lose analog speed and have no dead zone | Certain |
| 9 | Medium | Camera transitions can corrupt rotation or FOV | Certain |
| 10 | Medium | Movement input is wrong entering/leaving stretcher mode | Certain |
| 11 | Medium | Add push-and-coast behavior based on wheel locks | Requested feature |
| 12 | Medium | No gravity or ground height while operating | Certain |
| 13 | Medium | A second touch steals the joystick from the first | Certain |
| 14 | Medium | UI uses fixed pixels, with no stretch or orientation settings | Certain (impact depends on device) |
| 15 | Medium | Player and objects can fall off the map forever | Certain |
| 16 | Low | Cleanup and maintainability items | Mixed |

## High priority

### 1. Wheel colliders are not used by physics
- **Files:** `scenes/stretcher/stretcher.tscn:119-172`, `documentation/DEVELOPMENT_LOG.md:56`
- **Issue:** Each wheel `CollisionShape3D` is a child of a `Node3D` caster. Godot only uses collision shapes that are **direct children** of the physics body, so only `CollisionDeck` and `CollisionFloorSupport` work.
- **Effect:** The support box bottom is at local y = 0.12 and the wheel bottoms are at y = 0. At rest the wheels should sit about 0.12 m **below** the floor. The log's claim that the wheels carry the stretcher does not match the scene.
- **Proposed change:** Put four wheel colliders directly under the `Stretcher` root, and raise or shrink the support box so it clears the floor. Spheres of radius 0.18 at y = 0.18 are a simple option. Keep them separate from the animated caster visuals, and spawn the stretcher at floor height.

### 2. Default friction may hold the stretcher still
- **Files:** `scenes/stretcher/stretcher.tscn:47-53`, `scripts/stretcher/stretcher_controller.gd:225-226`
- **Issue:** No `PhysicsMaterial` is set, so default friction (1.0) applies. With default gravity of 9.8, sliding friction can remove about 9.8 m/s² while `drive_acceleration` adds 8.0.
- **Effect:** In a simple 60 Hz model, speed after 2 s is **0** with friction 1.0 and about **2.2 m/s** with 0.05. The engine's solver may differ, so confirm on device.
- **Proposed change:** Try a low-friction `PhysicsMaterial` (0.05). Item 11 (coasting) depends on this, because high friction would stop the stretcher almost at once. Re-tune after item 1.

### 3. Free-caster visuals disagree with the turn
- **File:** `scripts/stretcher/stretcher_controller.gd:213-222`
- **Issue:** Wheel heading and body yaw come from separate formulas. Checked in eight cases with stick right:

| Free pair | Moving forward | Moving in reverse |
|---|---|---|
| Front (rear locked) | Match | **Mismatch** |
| Rear (front locked) | **Mismatch** | Match |

Results are the same from either end. Moving forward, stick-right also turns the body **left** when the steering pair is trailing (for example, operator at the rear end with the front locked).
- **Proposed change:** Use one signed steering angle for both the wheel visuals and the yaw:

```gdscript
# drive_speed: signed speed along local -Z.
# steer: signed caster angle in radians; positive rotates the caster left.
# wheelbase = 1.44 (casters at z = -0.72 and +0.72). Positive yaw is left.
var yaw_rate := drive_speed * tan(steer) / wheelbase  # front pair steers
# If the rear pair steers: -drive_speed * tan(steer) / wheelbase
```

- **Maintainer decision (2026-11-25): steering depends on which wheels are locked, with forklift style when the trailing casters steer.** Both pairs free: moves in any direction. Both pairs locked: straight only. One pair locked: when the trailing casters steer, stick-right swings the trailing end right and the leading end left. When the leading casters steer, stick-right turns right.
- **What this means:** The current yaw signs for end operators already do this, so **keep them**. Fix the wheel visuals to match. With the formulas above, one steering angle works for either free pair and from either end:

```gdscript
var steer := -lateral_input * max_steer_angle  # try 0.4 radians
# Ease the free casters toward rotation.y = steer. Do not flip it in reverse;
# the sign of drive_speed already reverses the turn.
```

### 4. Locked stretcher can roll sideways or diagonally
- **File:** `scripts/stretcher/stretcher_controller.gd:42-47, 208-223, 230-233`
- **Issue:** Locking sets wheels to yaw 0 (local Z), but drive uses the operator's unsnapped facing at grab time. Grabbing square-on from a side with both pairs locked drives 90 degrees across the wheels. A 30 degree approach drives 30 degrees off-axis. This contradicts log line 52, "current wheel direction".
- **Related:** `_body_drive_sign` gives no steering near side-on, then jumps to full strength past a small threshold.
- **Proposed change:** Snap the forward vector to the chosen approach side. When any pair is locked, use only the local Z part of the requested direction:

```gdscript
var desired_local := operator_forward_local * longitudinal_input + operator_right_local * lateral_input
var drive_speed := -desired_local.z * maximum_speed  # along local -Z
```

  End operators use lateral input to steer (item 3).
- **Maintainer decision (2026-11-25): players can steer from the side with one caster pair locked.**
- **Proposed side rule:** Stick left/right drives along the stretcher. Stick up (away from the player) or down (toward the player) swings the free end that way while the stretcher is rolling. With both pairs locked it still rolls straight; with both free it still moves in any direction.

```gdscript
# Side operators, exactly one pair locked. desired_local and drive_speed as above.
# Near zero speed, keep the previous steer value.
if absf(drive_speed) > 0.05:
	steer = -desired_local.x * signf(drive_speed) * max_steer_angle
# Then use the same yaw formulas as item 3.
```

  Unlike end steering, this includes the sign of `drive_speed`, so "away" always means away when rolling either direction. Ease `steer` so reversing does not snap the casters.
- Replace `_body_drive_sign` with this rule and item 3, so steering no longer disappears at the sides. Apply it to both long sides.

### 5. Operator follow has no speed or distance limit
- **File:** `scripts/player/player_controller.gd:109-116`
- **Issue:** `distance / delta` tries to close the whole gap in one tick. With a 5.5 m reach, a grab can request hundreds of m/s. If an obstacle stops the player, the stretcher still drives away.
- **Proposed change:** Cap follow speed (for example 5 m/s), add a short approach phase before enabling drive, and stop driving or auto-release past a set gap (for example 1.5 m). **Maintainer decision (2026-11-25): the 5.5 m reach is intentional. Keep it.** This makes the capped approach phase important: the player should walk to the stretcher instead of being yanked, and must not pass through obstacles.

### 6. Held bags can be released inside or through obstacles
- **Files:** `scripts/interaction/holdable_object.gd:11-41`, `scripts/interaction/pickup_interactor.gd:125-140`
- **Issue:** Held bags have no collision and release at the hold point unchecked. A bag held into an obstacle drops inside it or beyond it. Looking steeply down can also overlap the floor.
- **Proposed change:** Sweep the bag's shape from the player to the hold point before release (`PhysicsDirectSpaceState3D.cast_motion`), excluding the player and bag. Place it at the last safe point, or refuse with a short message.

### 7. Buttons may fail while another finger is down (Likely)
- **File:** `ui/mobile_controls.gd:154-248`
- **Issue:** `Button` nodes usually receive touch through mouse emulation, which follows one finger. The player may be unable to lock casters, drop or toss while holding the joystick.
- **Test:** Hold the joystick, then press FRONT lock with another finger.
- **If it fails:** Use `TouchScreenButton`, or track button touch IDs in `_handle_touch`. Make sure one tap cannot trigger twice.

## Medium priority

### 8. Joysticks lose analog speed and have no dead zone
- **Files:** `scripts/player/player_controller.gd:118-125`, `scripts/stretcher/stretcher_controller.gd:202-205`, `ui/mobile_controls.gd:143-147`
- **Issue:** Walking and free-caster drive call `normalized()`, so a slight push targets full speed. Free drive also ignores inputs below about 0.1, then jumps to full speed.
- **Proposed change:** Use `limit_length(1.0)` instead, and add a dead zone of about 0.12 that rescales the remaining range.

### 9. Camera transitions can corrupt rotation or FOV
- **File:** `scripts/player/player_controller.gd:46-105`
- **Issues:**
  - Dragging LOOK during entry kills the whole tween, so FOV can stay between 85 and 78 and the camera jumps.
  - Entry ends at pitch -0.28 but orbit starts at -0.36, so the first drag jumps.
  - Re-grabbing within 0.65 s of release saves a half-finished rotation as the walking rotation.
  - Looking during exit fights the tween, and the pickup ray starts from a camera that is still away from the player's head.
- **Proposed change:** Use states (`WALK`, `ENTERING`, `STRETCHER`, `EXITING`). Save walk rotation only from `WALK`, block look and new grabs during transitions, use the orbit pose as the entry target, and tween FOV separately. Consider a `SpringArm3D` so the orbit camera does not pass through obstacles.

### 10. Movement input is wrong entering/leaving stretcher mode
- **File:** `scripts/player/player_controller.gd:62-82`
- **Issue:** Entry keeps old movement input, so a held stick drives at once. Exit clears input while the finger is still down, so walking stops until the finger moves.
- **Proposed change:** Either require the stick to return to center after a mode change, or keep reading its real position in both modes.

### 11. Add push-and-coast behavior based on wheel locks
- **Files:** `scripts/stretcher/stretcher_controller.gd:57-65, 189-193`, `scripts/interaction/pickup_interactor.gd`, `ui/mobile_controls.gd`
- **Maintainer decision (2026-11-25):** The player character can push the stretcher so that it coasts, and the locked or unlocked wheels decide how it moves.
- **Current state:** Release keeps momentum, but the physics function returns early with no operator, so wheel locks do nothing while coasting. The invalid-operator path also leaves `can_sleep` false.
- **Proposed change:**
  - Add a PUSH button, shown only while the stretcher is grabbed. It lets go and gives one capped impulse along the operator's facing (along the stretcher's long axis if any pair is locked). Suggested starting cap: 2.5 m/s.
  - Plain RELEASE adds no impulse. Any existing momentum coasts under the same rules.
  - Apply the wheel rules every physics tick, operator or not, after drive and before the early return:

| Front | Rear | Coasting behavior |
|---|---|---|
| Free | Free | Rolls in any direction and may rotate; casters trail the motion |
| Locked | Free | Front axle cannot slide sideways; the rear end can swing |
| Free | Locked | Rear axle cannot slide sideways; the front end can swing |
| Locked | Locked | Rolls straight along its long axis; no rotation |

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

  - Assigning the sideways speed instantly is a starting point. Ease it in if it feels abrupt. The code assumes a flat floor; re-check it on ramps.
  - With one pair locked, item 3's yaw formula can keep a pushed stretcher turning from its caster angle. Let that angle ease toward trailing as it coasts.
  - Tune coasting distance with `linear_damp` (now 0.5) and spin with `angular_damp` (now 5.0).
  - Restore player collision only once the two no longer overlap, so release does not shove the player.
  - Allow sleeping again after release, using one cleanup function for both paths. Brakes stay a separate future feature.

### 12. No gravity or ground height while operating
- **Files:** `scripts/player/player_controller.gd:113`, `scripts/stretcher/stretcher_controller.gd:92-95`
- **Issue:** Player vertical velocity is forced to 0, and the operator position assumes floor y = 0. Ramps, curbs and ambulance floors will break this.
- **Proposed change:** Keep gravity active, and find ground height with a downward ray where needed.

### 13. A second touch steals the joystick
- **File:** `ui/mobile_controls.gd:81-91`
- **Issue:** Any new touch in the zone takes over even if the first finger is still down. Lifting the second finger then stops movement. LOOK does the same.
- **Proposed change:** Keep the stale-touch recovery, but replace a touch only when it is likely stale, such as after focus loss. This is a tradeoff, so test it with the Xogot release problem.

### 14. Fixed-pixel UI
- **Files:** `project.godot`, `ui/mobile_controls.gd:10-11, 154-248`
- **Issue:** Control sizes are raw pixels, and no stretch mode, base size or orientation is set. Controls may be tiny on high-resolution iPads, and look speed varies with resolution. Safe areas are not handled.
- **Proposed change:** Set landscape orientation, a base size such as 1280x720, `canvas_items` stretch mode and `expand` aspect. Apply safe-area margins from `DisplayServer.get_display_safe_area()`. Re-tune look sensitivity afterward.

### 15. Falling off the map
- **File:** `scenes/main/main.tscn:57-72`
- **Issue:** The 24 x 24 m floor has no walls and there is no fall recovery.
- **Proposed change:** Add invisible boundary walls, plus a reset to spawn for anything below y = -5.

## Low priority (16)

- **Untyped calls:** Many `.call("...")` uses hide typos until runtime. Use `StretcherController` and `PlayerController` types.
- **Duplicate state:** The grab is tracked in the player, interactor and stretcher. Choose one owner and use signals.
- **Dead code:** `look_control_moves()` always returns false, no script uses the `pickupable` group, and `test_pickup.tscn` is not in the main scene. Remove only with approval.
- **Request ordering:** TOSS returns before a queued INTERACT, so the leftover request can grab something next tick. Clear both after handling one.
- **Feedback:** INTERACT looks the same with nothing in range. Show the target name or "too far".
- **LOOK label:** `draw_string` has width -1, so center alignment has no width to center within. Give it a width and offset the start by half.
- **Floating joystick:** The log calls it floating, but its center is fixed. Update one or the other.
- **Caster visuals:** Legs rotate with the wheels and can swing away from the frame. Rotate a child wheel pivot instead. Wheels also do not spin.
- **"Rigid-body force":** Log line 44 says force, but code sets velocity directly, so mass and patient load do not affect drive acceleration. Revisit when patients are added.
- **Physics engine and layers:** Choose a 3D physics engine explicitly so tuning stays consistent. Name collision layers for world, player, equipment and stretcher before adding patients.

## Suggested order

1. Items 1 and 2: stretcher contact and friction.
2. Items 3 and 4: one steering model. Then item 11: push and coast.
3. Items 5 and 12: operator following.
4. Items 7, 8, 10 and 13: touch input.
5. Items 6, 9, 14 and 15.
6. Low-priority cleanup before patient work begins.

## iPad test checklist

- [ ] Wheels rest on the floor, neither sinking nor floating.
- [ ] Stretcher reaches its set speed and coasts to a stop after release.
- [ ] PUSH in all four lock combinations, from both ends, matches the coasting table.
- [ ] Grab from near 5.5 m: the player walks over without being yanked or passing through obstacles.
- [ ] Release or PUSH does not shove the player.
- [ ] All four lock combinations, forward and reverse, from both ends and both sides.
- [ ] Wheel direction matches the turn every time.
- [ ] Locked stretcher never slides sideways.
- [ ] From each long side with one pair locked: stick away swings the free end away, rolling either direction.
- [ ] If an obstacle blocks the operator, the stretcher does not leave without them.
- [ ] Grab, release, and re-grab quickly; drag LOOK during each transition.
- [ ] Hold the joystick while pressing every button.
- [ ] Place a second finger in each touch zone, then lift in either order.
- [ ] Drop and toss bags against obstacles and the floor.
- [ ] Walk to every edge of the map.

## Questions for the maintainer

1. Answered: depends on the wheel locks, with forklift style when the trailing casters steer (see item 3).
2. Answered: yes, they can steer from the side with one pair locked (see item 4).
3. Answered: it coasts, and the player can push it (see item 11).
4. Answered: yes, keep 5.5 m (see item 5).
