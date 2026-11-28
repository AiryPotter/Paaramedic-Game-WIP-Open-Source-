# Map bounds (item 15) and cleanup (item 16)

**Source:** Code review 1, items 15 and 16 · **Status:** Open · **Priority:** Medium / Low
**Written against:** `9ae595b`. Untested. Each part can be picked on its own.

---

## Item 15. Walls and fall recovery
**Why:** the 24 x 24 m floor has no edges, and anything that falls off falls forever.

1. Copy [`../new_files/world_bounds.gd`](../new_files/world_bounds.gd) to `scripts/world/world_bounds.gd`.
2. In `scenes/main/main.tscn`, add a plain `Node` child of `Main` named `WorldBounds`, and attach the script.

It builds four invisible walls at the floor's edges, and puts the player, bags, KOLE, stretcher and patient back at their start if they drop below y = -5. Items being held or stuck to the pad are skipped.

The walls will not be needed in the house scene (Milestone 11), which has its own walls. Keep the fall reset.

---

## Item 16. Cleanup (pick any)

**a. Choose the physics engine explicitly** so tuning stays the same across Godot versions. In `project.godot`:
```ini
[physics]

3d/physics_engine="Jolt Physics"
```
If the stretcher tuning was done on Godot's default engine, test again after switching, or set `"GodotPhysics3D"` to keep it.

**b. Name the collision layers.** In `project.godot`:
```ini
[layer_names]

3d_physics/layer_1="world_and_bodies"
3d_physics/layer_2="interaction_areas"
```
(Layer 2 is already used by the patient's `InteractionArea`.) Split equipment, stretcher and player onto their own layers before more people and vehicles are added.

**c. Typed calls instead of strings.** For example in `pickup_interactor.gd`:
```gdscript
var grabbed_stretcher: StretcherController
# ...
if grabbed_stretcher.can_change_height():   # instead of grabbed_stretcher.call("can_change_height")
```
Typos then show as errors in the editor instead of failing at runtime.

**d. Dead code.** `look_control_moves()` in `pickup_interactor.gd` always returns `false`. Remove it and the branches that check it in `mobile_controls.gd`, or give it a real use. Remove only with the maintainer's approval.

**e. Caster visuals.** The legs turn with the wheels and can swing away from the frame. Put each wheel mesh under a child `WheelPivot` node, and turn only that. Wheels also do not spin; rotate the wheel mesh around its axle by `forward_speed / 0.18` radians per second (0.18 m is the wheel radius).

**f. Development log wording.** It says drive uses "rigid-body force", but the code sets velocity directly. Update the log, or switch to forces when patient weight should affect acceleration.
