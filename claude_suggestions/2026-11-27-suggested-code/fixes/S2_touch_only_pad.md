# S2. Touch-only pad sensor

**Source:** Code review 4, S2 (maintainer decision: touch only) · **Status:** Open · **Priority:** High
**Files:** `scenes/stretcher/stretcher.tscn`, `tests/qa_runner.gd`
**Depends on:** S1 (without the deck collider, items would fall through a thin sensor)
**Written against:** `9ae595b`. Untested.

## Step 1: shrink the sensor

Find:
```
[sub_resource type="BoxShape3D" id="BoxShape3D_pad_area"]
size = Vector3(1.45, 0.66, 2.7)
```
Replace with:
```
[sub_resource type="BoxShape3D" id="BoxShape3D_pad_area"]
size = Vector3(1.0, 0.06, 2.2)
```

Find (the shape under `DeckAssembly/PadArea`):
```
[node name="Collision" type="CollisionShape3D" parent="DeckAssembly/PadArea"]
position = Vector3(0, 1.15, 0)
```
Replace with:
```
[node name="Collision" type="CollisionShape3D" parent="DeckAssembly/PadArea"]
position = Vector3(0, 0.84, 0)
```
The sensor now spans y 0.81 to 0.87. It starts 1 cm below the pad top (0.82) so resting items still overlap it.

## Step 2: update the QA test

In `tests/qa_runner.gd`, test "Pad sensor secures an overhanging bag" freezes the bag in mid-air at y 1.2. That will no longer stick. Drop the bag onto the deck edge instead:

```gdscript
	_bag.freeze = false
	_bag.linear_velocity = Vector3.ZERO
	_bag.angular_velocity = Vector3.ZERO
	# Bag is 0.8 wide: centered at x 0.75 it overhangs the 0.5 edge but still touches the pad.
	_bag.global_position = _stretcher.to_global(Vector3(0.75, 1.1, -0.5))
	await _wait_physics_frames(30)
```
Keep the existing `_record(...)` check after it.

## Test
- A bag tossed past the side, or over the top, flies by without sticking.
- A bag landing on the pad sticks. A bag clipping the edge sticks hanging off (maintainer decision).
- A bag dropped on a stuck bag does not stick (no stacking).
