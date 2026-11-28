# Code Review 4: Patient, Stretcher Height, PUSH, Physics Fixes

**For:** ChatGPT 6 Luna
**Written by:** Claude Code
**Reviewed:** `xogot-project-upload` at `9ae595b` (game commits `b682539`, `d9bde68`, `96fab74`, `78c5a2f`, `d905340`, `9ae595b`, compared with `d9dd5ae`)
**Read with:** `2026-11-25-code-review-3.md`, `2026-11-25-milestone-plan.md`. If files disagree, the later file wins.

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before applying anything.
- Nothing was run here. This is a static review. Test in Xogot on iPad.

## Summary

A big step. Most earlier items are fixed, and the fixes follow the suggested sketches closely:

- Bumps are now applied inside `_integrate_forces` before the wheel rules, and a sideways bump at the contact point can swing a free end (review 2 N1, N2).
- Turning uses actual speed (N9). Grab aligns the player to the chosen handle (N5).
- PUSH button added. Both-free swing and slide added (review 3 R5).
- Stuck items predict the stretcher's next pose (review 3 R1).
- Camera transitions no longer fight LOOK, and take the shortest turn (N8).
- A reused touch index now releases its stale joystick or look state first (N6, partly).
- `GAME_DESIGN.md` matches the milestone plan, and the patient is kept clinically neutral, as asked.
- `tests/qa_runner.gd` is a good addition. See S6 for gaps.

**One serious bug (S1)** breaks the stretcher's deck collision. It also explains why the pad sensor was enlarged.

## Maintainer decisions (2026-11-25)

| Topic | Decision |
|---|---|
| Moving the patient onto the stretcher | **Controlled transfer.** No tossing and no solo carrying. Line the lowered stretcher up beside the patient, tap TRANSFER, and a short animation moves the patient on. |
| Pad catch zone | **Touch only.** Items stick only when they actually touch the pad. Hanging off the edge is still allowed (review 3 R3). |

## Findings

### S1. The deck no longer collides (Critical, high confidence)

**File:** `scenes/stretcher/stretcher.tscn`

`CollisionDeck` was moved under the new `DeckAssembly` node, which is a plain `Node3D`. **A `CollisionShape3D` only works as a direct child of a physics body** such as `RigidBody3D` or `Area3D`. Nested deeper, it is ignored. Xogot's scene tree should show a warning icon on `CollisionDeck`.

What breaks now (the deck slab from y 0.64 to 0.82 has no collider):
- Items and the KOLE pass through the deck. Today they are caught only because the enlarged pad sensor sticks them before they reach it.
- The player can walk into the upper part of the stretcher. Only the low floor support (y 0.12 to 0.36) and the wheels still collide.
- The pickup ray passes through the deck, so aiming at the deck does not grab the stretcher. The increase from 5.5 m to 6.5 m reach may be a workaround for this (see S5).
- The KOLE "cushioned by the pad" check never sees a deck contact.

**Proposed change:**
- Move `CollisionDeck` back to be a direct child of `Stretcher`.
- Move it with the deck in `_set_height_progress()`:

```gdscript
@onready var _deck_collision: CollisionShape3D = $CollisionDeck
const DECK_COLLISION_Y: float = 0.73

func _set_height_progress(progress: float) -> void:
	var current_offset := lerpf(_height_starting_offset, _height_target_offset, progress)
	_deck_assembly.position.y = current_offset
	_deck_collision.position.y = DECK_COLLISION_Y + current_offset
	# ...existing stuck-item code unchanged
```

- `PadArea` can stay under `DeckAssembly`, because it is an `Area3D` with its own direct shape child.
- Add a QA check: every `CollisionShape3D` under the stretcher has a `CollisionObject3D` as its direct parent. Also check that a ray aimed at the deck center hits the stretcher.

### S2. Pad catch zone: back to touch only (maintainer decision)

**File:** `scenes/stretcher/stretcher.tscn` (`BoxShape3D_pad_area`)

The sensor is now 1.45 x 0.66 x 2.7 m, centered at y 1.15. Items stick when they pass near the pad, up to 0.66 m above it and 0.225 m beyond each side. That snaps items down from mid-air. It also sticks items landing on a stuck bag, which goes against the "no stacking" decision (review 3 R4), and pushes them down into the bag.

**Proposed change (after S1):**
- Size the box `Vector3(1.0, 0.06, 2.2)` and center it at y `0.84`, so it spans 0.81 to 0.87. Starting it 1 cm below the pad top (0.82) makes sure items resting on the pad still overlap it. It follows lowering because it sits under `DeckAssembly`.
- Update the QA test "Pad sensor secures an overhanging bag". Rest the bag on the deck edge so it really touches the pad, instead of freezing it in mid-air at y 1.2.

### S3. Patient loading: controlled transfer (maintainer decision)

**Files:** `scripts/patient/training_patient.gd`, `scripts/interaction/pickup_interactor.gd`, `scripts/stretcher/stretcher_controller.gd`

Now, after ASSESS, the player picks up the 18 kg patient alone and tosses it onto the deck. The development log says loading is an aligned INTERACT transfer, so the **log and code disagree.** For a paramedic trainer, tossing a patient also teaches the wrong habit.

**Proposed change:**
- The patient can no longer be picked up or tossed. Remove the "PICK UP PATIENT" path in `_try_pick_up_object()`, and make `TrainingPatient.pick_up()` always return.
- Remove the patient branch from `_stick_holdables_to_pad()`.
- Add a **TRANSFER** action, shown when the player aims at the patient after ASSESS and all of these hold:
  - the stretcher is lowered and stopped (`is_lowered_for_loading()`),
  - the stretcher's center is within about 1.2 m sideways of the patient's center, and within 0.5 m along its length,
  - the stretcher's long axis is within about 25 degrees of the patient's.
- When not aligned, show a hint, for example "LINE UP STRETCHER" or "LOWER STRETCHER".
- On TRANSFER, call the existing `load_onto_stretcher()`. Its reparent and 0.45 s tween are already a good transfer animation.
- Update the HUD and status texts that say "toss the mannequin", and the TOSS tooltip.
- When the patient is loaded, add their mass to the stretcher (`mass += patient.mass`) so pushes and bumps feel heavier. Subtract it on unload later.

### S4. Lowering moves the whole frame (Visual, nit)

`SideRailLeft`, `SideRailRight` and both crossbars are now under `DeckAssembly`, so they drop 0.22 m too. Lowered, the rails reach the floor (y 0.00 to 0.42) and pass through the casters. Lower only the deck, its collider, the pad sensor and the patient. Keep the base frame where it is, or add a simple scissor-leg mesh between them.

### S5. Reach distances changed without a decision

`stretcher_interaction_distance` went from 5.5 to 6.5 m and `bag_interaction_distance` from 2.0 to 2.8 m. The maintainer set 5.5 m deliberately. After S1, set the stretcher back to 5.5 m unless the maintainer approves the change. Ask the maintainer about the 2.8 m bag reach.

### S6. QA runner gaps

- Tests call `grab()` directly and drop items from above, so they cannot catch S1. Add the checks listed under S1.
- KOLE "cushioned by the pad" passes only because the large sensor catches the device first. After S1 and S2, the test should show it landing on the deck itself.
- Keep `tests/` out of the demo build: launch the demo through `main.tscn` only, and exclude `tests/*` in the export settings later.

### S7. Items that stick during a height change end at the wrong height (Low)

`toggle_height()` collects stuck items when lowering starts. An item that sticks during the 0.55 s transition is not in the list, so it stays at the mid-transition height, up to 0.22 m off. Simplest fix: in `_stick_holdables_to_pad()`, skip sticking while `_height_tween` is running.

### S8. New project settings to check

Xogot added these to `project.godot`:
- **Pan and scale gestures on** (`pointing/ios/enable_pan_and_scale_gestures`). **Plausible:** two-finger touches may also produce pan or zoom gesture events. Test joystick and LOOK held together. If either acts up, turn this off.
- **Accelerometer, gravity, gyroscope and magnetometer on.** The game does not use them. Turn them off to save battery.
- `xogot/project/editorState` now records the last open file, so it will change in most commits. Harmless; ignore it in reviews.

## Status of earlier items

| Item | Status at `9ae595b` |
|---|---|
| Review 2 N1, bumps erased by wheel rules | **Fixed.** Verify on device. |
| Review 2 N2, sideways bump cannot swing the free end | **Fixed.** Verify on device. |
| Review 2 N3, weak push, no deliberate push | **Fixed** (PUSH button, impulse up to 2.2 m/s) |
| Review 2 N4, coasting ignores caster angle | Open |
| Review 2 N5, oblique grabs | **Fixed** |
| Review 2 N6, stuck joystick | **Improved** (stale index released). The Virtual Joystick add-on is still an option if device tests show problems. |
| Review 2 N7, wheel colliders rewritten every tick | Open |
| Review 2 N8, camera transitions | **Fixed.** Verify on device. |
| Review 2 N9, turn rate from requested speed | **Fixed** |
| Review 3 R1, stuck items trailing | **Fixed** |
| Review 3 R2, instant flat snap | Open (nit) |
| Review 3 R5, both free cannot turn | **Fixed** (swing and slide) |
| Review 1 item 6, release inside an obstacle | Open |

## Suggested order

1. S1, the deck collider. Then retest grabbing, bumping and KOLE landings.
2. S2, touch-only pad.
3. S3, controlled transfer.
4. S5, reach distances.
5. S6 QA updates, then S4, S7, S8.

## iPad test checklist

- [ ] No warning icon on any stretcher collision shape.
- [ ] Walking into the deck side stops the player at the deck, not at the low frame.
- [ ] Aiming at the deck from 5 m grabs the stretcher.
- [ ] A bag tossed just past the side, or over the top, flies by without sticking. A bag that lands on the pad sticks. A bag that clips the edge sticks hanging off.
- [ ] A bag dropped on a stuck bag does not stick.
- [ ] KOLE dropped on the deck lands on it, sticks and does not crack.
- [ ] Patient: no PICK UP or TOSS. TRANSFER appears only when the stretcher is lowered, stopped and lined up. The patient slides onto the deck.
- [ ] Lowered, the frame rails stay clear of the floor and casters.
- [ ] Joystick and LOOK held together with two fingers both keep working.
