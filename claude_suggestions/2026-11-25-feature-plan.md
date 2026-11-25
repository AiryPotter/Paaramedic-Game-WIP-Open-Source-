# Feature Plan: KOLE, Sticky Pad, Longer Stretcher, Tighter Turning

**For:** ChatGPT 6 Luna
**Written by:** Claude Code
**Based on:** `xogot-project-upload`, game code at `71372c6`
**Read with:** `2026-11-25-code-review.md` and `2026-11-25-code-review-2.md`

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before applying anything, one feature at a time.
- Nothing here was run. Sizes and turning figures are calculations to test on iPad.

## Maintainer requests (2026-11-25)

1. Name the defibrillator **KOLE**.
2. Make the stretcher pad sticky: something thrown onto it sticks where it lands.
3. Make the stretcher longer.
4. Give the wheels a better turning radius when unlocked.

## 1. Rename to KOLE

| File | Change |
|---|---|
| `scenes/equipment/defibrillator.tscn:39` | Node `ZOLLDefibrillator` to `KOLEDefibrillator` |
| `scenes/equipment/defibrillator.tscn:63` | Label text to `KOLE` |
| `documentation/DEVELOPMENT_LOG.md:60, 62` | Replace ZOLL with KOLE, and drop "ZOLL-style" |

No script refers to the old name. The main-scene instance is already called `Defibrillator`. Avoid copying the real brand's logo, colors or exact product look.

## 2. Sticky pad

**Files:** `scenes/stretcher/stretcher.tscn`, `scripts/stretcher/stretcher_controller.gd`, `scripts/interaction/holdable_object.gd`

**Behavior**
- Any `HoldableObject` that lands on the pad sticks, whether tossed or dropped.
- It keeps its landing spot and travels with the stretcher.
- INTERACT picks it up as usual, which unsticks it.
- Hitting the sides or legs of the stretcher does not stick.

**Detecting a landing**
- Add an `Area3D` named `PadArea` under the stretcher, as a thin box just above the pad. The pad top is at y = 0.82 (0.73 + 0.09), so use a box about 0.10 tall centered at y = 0.87, slightly narrower and shorter than the pad.
- Check `get_overlapping_bodies()` each physics tick. `body_entered` alone can fire while the item's center is still outside the pad.
- Stick only if the object is not held, not already stuck, its center is within the pad's X and Z edges, and its center is above the pad top.

**Sticking**
- Freezing at first contact would leave a bag tilted on one corner. Keep the landing X, Z and yaw, but set the item flat with its base on the pad. A 0.1 s ease hides the correction.
- Do not change its parent. Store its transform relative to the stretcher and update it each physics tick.

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

- Call `unstick()` at the **start** of `pick_up()`, before it saves the collision layer and mask. Otherwise the item keeps a mask of 0 after release.
- If the stretcher could be removed while items are on it, restore their mask and unfreeze them first.
- Scale and rotation: build `local_transform` from yaw plus half the item's collision height. Expose that height on `HoldableObject` (bags 0.46 and 0.38, defibrillator 0.30).
- Items already stuck do not add weight. Revisit this when patient weight is added.

**Defibrillator interaction:** A toss onto the pad could still exceed the 3 m/s crack limit. Suggested rule: the pad is padded, so contacts with the stretcher pad do not crack it. **Maintainer question 1.**

## 3. Longer stretcher

The pad is 1.85 m now. **Suggested length: 2.20 m** (**maintainer question 2**). Width stays at 1.0 m.

| Part | Now | Suggested |
|---|---|---|
| Deck mesh and collider, Z size | 1.85 | 2.20 |
| Floor support collider, Z size | 1.50 | 1.50 (leave) |
| Side rails, Z size | 1.70 | 2.05 |
| Crossbars, Z | +/-0.79 | +/-0.965 |
| Lock levers, Z | +/-0.94 | +/-1.115 |
| Casters and wheel colliders, Z | +/-0.72 | +/-0.80 |
| `WHEELBASE` | 1.44 | 1.60 |
| End operator spots, Z | +/-1.45 | +/-1.625 |

- **Keep the wheels closer in than the pad ends.** Stretching the wheelbase by the same 0.35 m would widen the turn from 3.4 m to 4.2 m. The X and Z rotation locks prevent tipping.
- Use one constant for the axle: `stretcher_controller.gd:319` repeats 0.72, so make it `WHEELBASE * 0.5`.
- Mesh and collider sub-resources are separate. Change both.
- Size `PadArea` from the new length.
- The operator already starts close to the defibrillator at z = 2.7. Move the stretcher back in `scenes/main/main.tscn` (about z = 0.0) to leave room.

## 4. Tighter turning

"Unlocked" covers two cases, so both are below.

### One pair unlocked
Radius = wheelbase / tan(steer angle).

| Setup | Tightest turn (geometric) |
|---|---|
| Now: 1.44 m wheelbase, 0.4 rad | 3.4 m |
| Longer, same angle: 1.60 m, 0.4 rad | 3.8 m |
| **Suggested: 1.60 m, 1.0 rad (about 57 degrees)** | **1.0 m** |

- Set `maximum_steer_angle` to 1.0 and `maximum_turn_speed` to 1.2 rad/s.
- **The turn-speed cap would undo this.** At 2.2 m/s it limits the turn to 1.8 m. Slow the stretcher in tight turns so the path matches the wheels:

```gdscript
var turn_factor := absf(tan(_current_steer_angle)) / WHEELBASE
if turn_factor > 0.001:
	var allowed_speed := maximum_turn_speed / turn_factor  # about 1.2 m/s at full lock
	drive_speed = clampf(drive_speed, -allowed_speed, allowed_speed)
# Set target_horizontal_velocity AFTER this limit.
```

- Review 2 item N9 (use real speed for yaw) goes well with this. Apply N9 before tuning.
- Forklift and side-steering directions do not change.

### Both pairs unlocked
Now `target_turn_speed` is always 0, so the stretcher **cannot be turned at all** with everything free. Suggested: pushing sideways from an end swings that end, as on real casters.

```gdscript
# Both free, end operator only. Positive yaw is left.
if absf(operator_offset.z) > absf(operator_offset.x):
	target_turn_speed = signf(operator_offset.z) * desired_local.x * maximum_turn_speed
	# Reduce the sideways slide so the swing is noticeable.
	desired_local.x *= 0.5
```

- Compute this before `target_horizontal_velocity`.
- Stick-right from the rear end swings the rear end right, consistent with the forklift choice. From a side, the stretcher still slides without turning.
- The tradeoff is that a pure sideways slide is then only available from the sides. **Maintainer question 3.**
- While coasting with both free, spin already continues and fades through `angular_damp`.

## Suggested order

1. Review 2 items N6 and N1 (stuck touch, and wheel rules in `_integrate_forces`).
2. KOLE rename.
3. Longer stretcher, then test wheel contact again.
4. Review 2 items N5 and N9, then tighter turning.
5. Review 1 item 6, then the sticky pad.
6. Review 2 items N2-N4 (push and coast), since size and turning affect the tuning.

## iPad test checklist

- [ ] The device reads KOLE.
- [ ] Toss each bag and the defibrillator onto the pad. Each sticks flat where it landed.
- [ ] Throw something at the side of the stretcher. It does not stick.
- [ ] Drive, turn, push and coast with items stuck. They stay in place.
- [ ] Pick up a stuck item, then drop it on the floor. It collides normally.
- [ ] The wheels still touch the floor, and the pad looks the right length.
- [ ] Turn at full lock with each pair locked, forward and reverse, from both ends and sides.
- [ ] Both free: swing from each end, and slide from each side.

## Questions for the maintainer

1. Should the pad cushion the defibrillator so landing there never cracks it?
2. Is 2.20 m long enough?
3. With both pairs free, should pushing sideways from an end swing the stretcher, slide it, or both (suggested)?
