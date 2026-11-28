# S1. Restore the deck's collision

**Source:** Code review 4, S1 · **Status:** Open · **Priority:** Critical
**Files:** `scenes/stretcher/stretcher.tscn`, `scripts/stretcher/stretcher_controller.gd`
**Written against:** game code at `9ae595b`. Untested.

**Why:** `CollisionDeck` sits under `DeckAssembly` (a plain `Node3D`). Godot ignores a `CollisionShape3D` unless its direct parent is a physics body, so the deck has no collision.

## Step 1: scene

In `scenes/stretcher/stretcher.tscn`, change the parent of `CollisionDeck`:

Find:
```
[node name="CollisionDeck" type="CollisionShape3D" parent="DeckAssembly"]
```
Replace with:
```
[node name="CollisionDeck" type="CollisionShape3D" parent="."]
```
Keep its `position = Vector3(0, 0.73, 0)` and `shape` lines. In Xogot, you can instead drag `CollisionDeck` onto `Stretcher` in the scene tree. Check that no warning icon remains.

## Step 2: script

In `scripts/stretcher/stretcher_controller.gd`, add next to the other `@onready` lines:
```gdscript
@onready var _deck_collision: CollisionShape3D = $CollisionDeck
const DECK_COLLISION_Y: float = 0.73
```

Replace `_set_height_progress()` with:
```gdscript
func _set_height_progress(progress: float) -> void:
	var current_offset := lerpf(_height_starting_offset, _height_target_offset, progress)
	_deck_assembly.position.y = current_offset
	_deck_collision.position.y = DECK_COLLISION_Y + current_offset
	var height_delta := current_offset - _height_starting_offset
	for index in range(_height_stuck_items.size()):
		var item := _height_stuck_items[index]
		if is_instance_valid(item):
			item.set_stuck_local_position_y(_height_stuck_start_heights[index] + height_delta)
```

## Test
- Walk into the side of the deck: you stop at the deck, not at the low frame.
- Aim at the deck from 5 m: INTERACT grabs the stretcher.
- Lower and raise: items on the pad, and the deck collision, move together.
