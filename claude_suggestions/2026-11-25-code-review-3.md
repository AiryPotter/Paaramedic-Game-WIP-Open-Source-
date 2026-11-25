# Code Review 3: KOLE, Longer Stretcher, Sticky Pad, Steering

**For:** ChatGPT 6 Luna
**Written by:** Claude Code
**Reviewed:** `xogot-project-upload` at `d9dd5ae` (commits `cc70ad4`, `2509136` and `d9dd5ae`, compared with `71372c6`)
**Read with:** `2026-11-25-code-review-2.md` and `2026-11-25-feature-plan.md`. If files disagree, the later file wins.

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before applying anything.
- Nothing was run. This is a static review with numeric checks. Test on iPad in Xogot.

## Summary

The work follows the feature plan closely and is clean. Done well:

- **KOLE rename** is complete. No script used the old node name, and `on_tossed()` was removed from both files.
- **2.20 m stretcher:** every part in the plan's size table was updated. The axle now uses `WHEELBASE * 0.5`. Spawning at y = 0 puts the wheel bottoms (y 0.18, radius 0.18) exactly on the floor top (y 0).
- **Crack on hard impact** (review 2 N11) matches the sketch, including the pad check and `contact_monitor`.
- **Sticky pad** has the right structure: kinematic freeze, collision exceptions both ways, mask restored on pickup, and `unstick` runs before `pick_up()` saves the mask.
- **Steering:** a 0.6 rad steer angle gives a 2.34 m turn (was 3.4 m). At top speed (2.2 m/s) that turn needs 0.94 rad/s, under the new 1.2 cap. **The tight-turn speed limit from the feature plan is not needed at this angle.** Add it only if the angle goes above about 0.72 rad.

## New findings

### R1. Stuck items trail the stretcher by one physics step (Likely, visible at speed)

**Files:** `scripts/interaction/holdable_object.gd` (`_follow_stuck_surface`, `_physics_process`)

- `_physics_process` runs **before** the physics step. The item copies the stretcher's pose, then the stretcher moves, then the frame is drawn.
- At 2.2 m/s and 60 ticks per second, items sit about **3.7 cm behind** their spot while moving. When turning at 1.2 rad/s, an item at the end of the pad lags about 2 cm sideways. They jump back when the stretcher stops.
- **Proposed change:** follow the stretcher's predicted pose for the end of this step.

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

- Keep the call in `stick_to_surface()` with no argument (delta 0). Damping makes the prediction slightly off, by under 1 mm per step.
- **Test:** drive at full speed and turn with a bag at the pad's end. The bag should not drift or jump on stopping.

### R2. Snapping flat is instant (Nit)

An item that touches the pad tilted on a corner teleports flat in one tick. The feature plan suggested a 0.1 s ease. Optional; check on device whether the snap looks wrong.

### R3. Items stuck past the edge (maintainer decision, no change)

**Maintainer decision (2026-11-25): keep it hanging.** An item that clips the pad's edge sticks exactly where it touched, even if most of it hangs off the side. The current code already does this. Do not clamp to the pad.

### R4. No stacking (maintainer decision, no change)

**Maintainer decision (2026-11-25): no stacking.** An item that lands on a stuck item, not the pad, stays a normal rigid body. It can slide off when the stretcher moves, and the KOLE can crack on such a landing. The current code already does this.

- Side effect to know about: stuck items keep their collision layer but have mask 0. Two items that both touch the pad never collide with each other, so a bag that straddles a stuck bag and touches the pad snaps down **into** it. Accept this for now, or skip sticking when the new spot overlaps a stuck item.

### R5. Steering, both pairs free: still cannot turn

The feature plan's "swing and slide" decision (section 4) is not implemented yet. The development log lists broader turning as deferred. Apply it when steering is next worked on.

### R6. Feature plan figures to update

- Feature plan section 4 suggested 1.0 rad. The code uses 0.6 rad, a fine middle step. Tune on device before going higher.
- Review 2 item N9 (turn rate uses requested speed, not actual speed) is still open, and matters more now that turning accelerates faster (`turn_acceleration` 6.0).

## Status of earlier items

| Item | Status at `d9dd5ae` |
|---|---|
| Review 2 N11, defibrillator crack | **Fixed** (hard impact, pad cushions) |
| Feature plan 1, KOLE rename | **Done** |
| Feature plan 2, sticky pad | **Done.** See R1 to R4. |
| Feature plan 3, 2.20 m stretcher | **Done** |
| Feature plan 4, tighter turning | **Partly done.** One pair locked: 2.34 m. Both free: not started (R5). |
| Review 2 N6, joystick stuck after a missed release | **Open.** Top priority. See `2026-11-25-open-source-borrowing.md` for a ready-made joystick. |
| Review 2 N1, bumps erased by wheel rules | **Open.** `_apply_wheel_constraints()` still runs every tick, with or without an operator. |
| Review 2 N2 to N5, N7 to N10 | **Open,** code unchanged |
| Review 1 item 6, releasing inside an obstacle | **Open.** It now matters more: an item pushed out fast can crack the KOLE. Releasing just above the pad now sticks the item, which is fine. |

## Suggested order

1. Review 2 N6 (joystick), using the Virtual Joystick add-on.
2. R1 (stuck items trailing).
3. Review 2 N1, then N9.
4. Feature plan section 4, both pairs free (R5).
5. Review 1 item 6.

## iPad test checklist

- [ ] Stretcher spawns resting on its wheels, with no drop or bounce.
- [ ] Each bag and the KOLE stick where they land, flat, with yaw kept.
- [ ] An item that clips the pad edge sticks hanging off the side (R3).
- [ ] Full-speed drive and turn with a bag at the pad's end: no drift or jump on stopping (R1).
- [ ] Pick up a stuck item and drop it on the floor: it collides normally.
- [ ] KOLE: 30 cm floor drop (no crack), chest-height floor drop (crack), toss onto the pad (no crack), toss onto a stuck bag (may crack; see R4).
- [ ] One pair locked: full-lock turn about 2.3 m across, forward and reverse, from both ends and both sides.
