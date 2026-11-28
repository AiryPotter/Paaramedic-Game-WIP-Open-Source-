# Small fixes from code review 4 (S4, S5, S7, S8)

**Source:** Code review 4 · **Status:** Open · **Written against:** `9ae595b`. Untested.
Each section below can be picked on its own.

---

## S4. Lower only the deck, not the frame (Visual)
**File:** `scenes/stretcher/stretcher.tscn`

Lowering moves `DeckAssembly` down 0.22 m, and the rails and crossbars are inside it, so they sink into the floor and casters. Move these four nodes back under the root:

Find each of these lines:
```
[node name="SideRailLeft" type="MeshInstance3D" parent="DeckAssembly"]
[node name="SideRailRight" type="MeshInstance3D" parent="DeckAssembly"]
[node name="CrossbarFront" type="MeshInstance3D" parent="DeckAssembly"]
[node name="CrossbarBack" type="MeshInstance3D" parent="DeckAssembly"]
```
Change `parent="DeckAssembly"` to `parent="."` on each. Their positions stay the same.

**Test:** lowered, the rails stay clear of the floor and the casters.

---

## S5. Put reach distances back (needs maintainer approval)
**File:** `scripts/interaction/pickup_interactor.gd`

The maintainer set 5.5 m for the stretcher. After S1 the deck can be aimed at again, so the 6.5 m workaround is not needed:
```gdscript
@export var bag_interaction_distance: float = 2.0     # was 2.8; ask the maintainer
@export var stretcher_interaction_distance: float = 5.5  # was 6.5; maintainer decision
```

---

## S7. Don't stick items during a height change (Low)
**File:** `scripts/stretcher/stretcher_controller.gd`

Add at the top of `_stick_holdables_to_pad()`:
```gdscript
	# Items that land mid-transition would be left at the wrong height.
	if is_instance_valid(_height_tween) and _height_tween.is_running():
		return
```
An item landing during the 0.55 s change sticks right after it finishes.

---

## S8. Project settings Xogot added
**File:** `project.godot`, section `[input_devices]`

Joystick driving was chosen, so the motion sensors are not needed:
```ini
sensors/enable_accelerometer=false
sensors/enable_gravity=false
sensors/enable_gyroscope=false
sensors/enable_magnetometer=false
```
Pan and zoom gestures: **test first.** Hold the joystick and LOOK with two fingers. Only if either acts up, change:
```ini
pointing/ios/enable_pan_and_scale_gestures=false
```
Leave `xogot/project/editorState` alone; Xogot rewrites it.
