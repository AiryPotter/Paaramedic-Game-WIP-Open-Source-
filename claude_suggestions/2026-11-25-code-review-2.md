# Code Review 2: Paramedic Simulator

**For:** ChatGPT 6 Luna
**Reviewed by:** Claude Code
**Branch and commit:** `xogot-project-upload` at `71372c6` ("Fix stretcher physics and input reliability")
**Follows:** `2026-11-25-code-review.md`
**Scope:** everything changed since `27ccae8`, including the defibrillator (`a08572d`), plus a recheck of every earlier item.

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before applying anything, one small change at a time.
- The game was **not run**. Steering signs and coasting distances were checked with separate calculations.
- **Certain** = follows from the code. **Likely** = depends on engine or device behavior; test before fixing.

## What improved

- Wheel colliders are now direct children of the body, and friction is set to 0.05.
- One steering angle now drives both the wheels and the turn. All 16 cases checked (8 end, 8 side) match the maintainer's forklift and side-steering decisions.
- Locked axles resist sideways slip. Analog speed and the dead zone are correct.
- A second finger no longer steals the joystick, and FOV no longer gets stuck.

## Status of review 1

| # | Issue | Status |
|---|---|---|
| 1 | Wheel colliders | Fixed; confirm on iPad |
| 2 | Friction | Fixed; confirm on iPad |
| 3 | Wheels vs. turn | Fixed while driving |
| 4 | Locked sideways rolling, side steering | Partly: facing is still unsnapped (N5) |
| 5 | Operator follow speed and distance | **Open** |
| 6 | Bags released in obstacles | **Open**; now affects the defibrillator too |
| 7 | Buttons with another finger down | **Open, needs iPad test** |
| 8 | Analog speed and dead zone | Fixed |
| 9 | Camera transitions | Partly (N8) |
| 10 | Input when changing modes | Fixed: the player lifts and touches again |
| 11 | Push and coast | Partly (N1-N4) |
| 12 | Gravity and ground height | **Open** |
| 13 | Second touch steals joystick | Fixed, but see N6 |
| 14 | Fixed-pixel UI | **Open** |
| 15 | Falling off the map | **Open** |
| 16 | Low-priority cleanup | Mostly open |

## New findings

| # | Priority | Issue | Confidence |
|---|---|---|---|
| N1 | High | Bumps may be erased when any casters are locked | Likely |
| N2 | High | With one pair locked, a sideways bump cannot swing the free end | Certain |
| N3 | High | Pushes are weak; no deliberate push control | Certain |
| N6 | High | A missed touch release can leave the joystick stuck | Certain logic; trigger needs testing |
| N4 | Medium | Coasting ignores the caster angle | Certain |
| N5 | Medium | Oblique grabs still mix driving and steering | Certain |
| N7 | Medium | Wheel colliders are rewritten every tick | Likely cost |
| N8 | Medium | Camera transition problems remain | Certain |
| N9 | Medium | Turn rate uses requested speed, not real speed | Certain |
| N10 | Low | State left over between grabs and locks | Certain |
| N11 | Low | Defibrillator notes | Mixed |

### N1. Bumps may be erased when any casters are locked (Likely)
- **Files:** `scripts/stretcher/stretcher_controller.gd:249, 256-260, 311-321`
- **Issue:** `apply_central_impulse` acts on the physics server, but the node's `linear_velocity` is normally refreshed only when physics state syncs. The player runs before the stretcher in the scene tree, so in the same tick the constraint can read the old velocity and write it back over the impulse. With both pairs free it returns early, so bumps work there.
- **Test:** Bump the stretcher with both free, then with both locked, along its long axis. If only the free case moves, this is confirmed.
- **Proposed change:** Apply the wheel constraint in `_integrate_forces(state)`, using `state.linear_velocity` and `state.angular_velocity`. Moving the drive there as well keeps velocity changes in one place. The same code also writes velocity every tick while locked and unattended, which may stop the body from sleeping.

### N2. One pair locked: a sideways bump cannot swing the free end
- **Files:** `scripts/stretcher/stretcher_controller.gd:228-250, 318-320`, `scripts/player/player_controller.gd:127-132`
- **Issue:** The bump is applied at the center, so it creates no rotation. With zero rotation, the constraint then sets sideways velocity to zero, cancelling a sideways bump. The maintainer's table says the free end should swing.
- **Proposed change:** Pass `collision.get_position()` and use `apply_impulse(impulse, contact_point - global_position)`. Do N1 first, or the constraint may erase it. Both-free bumps near an end would then rotate the stretcher naturally.

### N3. Pushes are weak, and there is no deliberate push
- **Files:** `scripts/stretcher/stretcher_controller.gd:12-15, 228-250`, `scenes/stretcher/stretcher.tscn:55`
- **Issue:** A full-speed bump gives about **0.38 m/s**, which coasts about **9 cm**. While blocked, the player only regains about 0.3 m/s per tick, below the 0.8 threshold, so leaning on it does little more. Raising `linear_damp` from 0.5 to 1.2 also shortened a full-speed release from about 1.9 m to 1.1 m. (Estimates include Godot's default 0.1 damping.)
- **Also:** Bump strength uses player speed, not speed relative to the stretcher.
- **Maintainer decision (2026-11-25): keep bumping and add a PUSH button.** Bumping is there; the PUSH button from review 1 item 11 is not.
- **Proposed change:**
  - Show PUSH only while the stretcher is grabbed. Add it to `_touch_hits_control`, and keep it clear of the existing buttons.
  - Queue the request like TOSS, for the physics tick. Release the stretcher, then apply one impulse along the operator's facing: `mass * push_speed`, capped so total speed stays within `maximum_speed` (2.2 m/s).
  - With any pair locked, project the direction onto the stretcher's long axis. If the operator faces straight across it, a push has no effect, so disable PUSH there or show why.
  - Clear any queued INTERACT after a PUSH, so it cannot re-grab.
  - Use relative speed for bumps, and tune both after N1 and N2.
  - **Maintainer decision (2026-11-25): a full-speed push should coast about 1 m.** Keep `linear_damp` at 1.2 and cap the push at 2.2 m/s, which is estimated at about 1.1 m. (The 2.5 m/s cap in review 1 is replaced; it would be about 1.3 m.) Adjust after iPad testing.
  - With this cap, PUSH gives a full shove from a standstill but adds nothing when already at full speed; it then acts like RELEASE.
- **Estimates:** Coasting from 2.2 m/s is 1.1 m at damping 1.2 and 1.9 m at 0.5.

### N6. A missed touch release can leave the joystick stuck
- **File:** `ui/mobile_controls.gd:86-94`
- **Issue:** The takeover was removed. If Xogot swallows a release without a focus or resize event, the stored ID never clears: movement continues and new touches are ignored. This is the problem the old takeover was added to solve.
- **Proposed change:** Touch indexes are reused, so a new press with a stored index means the old touch ended. Clear it first:

```gdscript
# After the not-pressed check in _handle_touch:
if event.index == joystick_touch_id or event.index == look_touch_id:
	_release_touch(event.index)
```

  This keeps second-finger protection. It does not help if the next touch gets a different index.

### N4. Coasting ignores the caster angle
- **File:** `scripts/stretcher/stretcher_controller.gd:256-260`
- **Issue:** With no operator, steering is not calculated. Yaw fades quickly (angular damping 5.0) and the stretcher straightens, while its casters stay visually turned. Both-free casters also do not trail the motion.
- **Proposed change:** While coasting with one pair locked, compute yaw from actual speed and the current angle, easing the angle toward zero. With both free, steer caster visuals from local velocity.

### N5. Oblique grabs still mix driving and steering
- **File:** `scripts/stretcher/stretcher_controller.gd:54-74, 262-286`
- **Issue:** Operator position snaps to an end or side, but facing does not. At an end with a 45-degree facing, pushing right steers **and** drives, and forward gives only about 71% speed. Facing nearly across the stretcher, forward barely drives.
- **Proposed change:** Derive the forward vector from the chosen spot, and use the same yaw for the player:

```gdscript
operator_forward_local = Vector3(-operator_offset.x, 0.0, -operator_offset.z).normalized()
operator_facing_yaw_offset = atan2(-operator_forward_local.x, -operator_forward_local.z)
```

### N7. Wheel colliders are rewritten every tick (Likely cost)
- **File:** `scripts/stretcher/stretcher_controller.gd:218-225, 255`
- **Issue:** Four collider transforms are assigned every physics tick, even when nothing moved. This can rebuild the body's shape, disturb contacts and cost performance. Locking also widens colliders, possibly into a wall or the player.
- **Proposed change:** Keep the colliders fixed (the wheels do not need to yaw for collision), or sync only during the 0.32 s width animation. A fixed compromise width is simplest.

### N8. Camera transition problems remain
- **File:** `scripts/player/player_controller.gd:56-97`
- Each LOOK drag during entry restarts the 0.65 s tween, so the camera keeps easing from a near stop.
- Crossing the yaw wrap at +/-PI during a transition makes the camera spin the long way.
- Re-grabbing within 0.65 s still saves a half-finished rotation as the walking rotation.
- Looking during exit still fights the tween.
- **Proposed change:** The state approach from review 1 item 9. At minimum, save walk rotation only when no tween is running, and ignore look input during transitions.

### N9. Turn rate uses requested speed
- **File:** `scripts/stretcher/stretcher_controller.gd:275-300`
- **Issue:** Yaw uses stick-requested speed. A stretcher blocked by a wall still turns, and it turns before it has built up speed.
- **Proposed change:** Use actual forward speed, `-(global_basis.inverse() * linear_velocity).z`. Use its sign for the side rule too, keeping the 0.05 threshold.

### N10. Leftover state
- **File:** `scripts/stretcher/stretcher_controller.gd`
- `_current_steer_angle` is not reset on grab, release or lock change (only when both are locked while driving).
- The invalid-operator path (256-260) still leaves `can_sleep` false.
- Removing the collision exception at release while overlapping can still shove the player.
- `apply_character_bump` sets `can_sleep = true`, which is unrelated to bumping.
- Grabbing stops a rolling stretcher instantly from up to 5.5 m away. The reach is intentional, but consider stopping it only once the player arrives.

### N11. Defibrillator
- **Files:** `scripts/equipment/defibrillator.gd`, `scenes/equipment/defibrillator.tscn`, `scripts/interaction/pickup_interactor.gd:139`
- The current crack logic matches the log (TOSS cracks it once; dropping does not). The decision below replaces it, so update the log too.
- **Maintainer decision (2026-11-25): crack only on a hard impact.** It now cracks the moment TOSS is pressed, before any impact.
- **Speed alone cannot separate a toss from a drop.** Holding level, estimated floor impact is about 4.0 m/s for a toss and 4.1 m/s for a drop. A threshold low enough to catch tosses may also catch chest-height drops.
- **Proposed change:** Until the maintainer answers question 5, keep the logged rule that an ordinary drop does not crack it. Make TOSS only arm the damage, then crack on a hard hit. Set `contact_monitor = true` and `max_contacts_reported = 4` on the body, and treat this as a sketch to test:

```gdscript
@export var crack_speed_change: float = 3.0  # tune on device
var _armed: bool = false
var _previous_velocity: Vector3 = Vector3.ZERO

func on_tossed() -> void:
	_armed = true  # no longer cracks here

func pick_up(hold_transform: Transform3D) -> void:
	_armed = false
	super.pick_up(hold_transform)

func release(hold_transform: Transform3D, inherited_velocity: Vector3) -> void:
	super.release(hold_transform, inherited_velocity)
	_previous_velocity = inherited_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Contacts are from the last step, so compare this velocity with the previous one.
	if _armed and not screen_cracked and state.get_contact_count() > 0:
		if (state.linear_velocity - _previous_velocity).length() >= crack_speed_change:
			screen_cracked = true
			$CrackedScreen.set_deferred("visible", true)
	_previous_velocity = state.linear_velocity
```

  The armed flag stays set until pickup, so a later hard hit can also crack it. Disarm it once the device is at rest if that is not wanted.
- `has_method`/`call` can become an empty `on_tossed()` on `HoldableObject` that `Defibrillator` overrides.
- The TOSS tooltip still says "bag".
- "ZOLL" is a real company's brand, shown on a device that breaks, in a public repository. Consider a fictional or generic name unless there is permission. **Maintainer's choice.**

### Small scene note
- The stretcher spawns at y = 0.12, but its wheels now touch at y = 0, so it drops 12 cm at start. Spawn it at y = 0 (`scenes/main/main.tscn`, Stretcher node).

## Suggested order

1. iPad tests below, before more changes.
2. N6, a small safe fix.
3. N1, N2, then N3 and N4: push and coast.
4. N5 and N9: driving feel.
5. Review 1 item 5, then 12: operator following.
6. N8 and N7, then review 1 items 6, 14 and 15.

## iPad test checklist

- [ ] Wheels rest on the floor and the stretcher drives at a reasonable speed.
- [ ] Bump it with both free, front locked, rear locked, and both locked. Note which ones move.
- [ ] Bump the free end sideways with one pair locked. Does it swing?
- [ ] After PUSH is added: push in all four lock states, from both ends and both sides.
- [ ] Release at full speed in all four lock states. Is the distance about 1 m?
- [ ] Steer from both ends and both sides with each pair locked.
- [ ] Grab at an angle, then push straight forward.
- [ ] Hold the joystick and press every button with another finger.
- [ ] Interrupt a held joystick with Xogot's interface. Does movement stop, and does the stick work again?
- [ ] Grab, release, re-grab quickly; drag LOOK during each.
- [ ] Defibrillator: low drop (no crack), toss onto the floor (crack on landing, not before), gentle landing (no crack), pick up again (still cracked).

## Questions for the maintainer

1. Answered: bumping plus a PUSH button (see N3).
2. Answered: about 1 m (see N3).
3. Answered: only on a hard impact (see N11).
4. Keep the ZOLL name, or use a generic one?
5. Can a hard drop from chest height also crack the defibrillator, or only a toss?
