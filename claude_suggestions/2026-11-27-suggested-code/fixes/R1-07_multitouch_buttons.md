# Review 1 item 7. Buttons that work while another finger is down

**Source:** Code review 1, item 7 · **Status:** Open, **test first** · **Priority:** High if the test fails
**File:** `ui/mobile_controls.gd` · **Written against:** `9ae595b`. Untested.

**Test first:** hold the joystick with one thumb, then tap FRONT, PUSH, TOSS and INTERACT with the other. If they all work, skip this fix.

**Why it may fail:** `Button` nodes get touches through mouse emulation, which follows only one finger.

**Fix:** handle button taps directly from the touch events.

Add:
```gdscript
func _button_at(touch_position: Vector2) -> Button:
	for button in [interaction_button, toss_button, front_lock_button, rear_lock_button, push_button, height_button]:
		if button.visible and not button.disabled and button.get_global_rect().has_point(touch_position):
			return button
	return null
```
In `_handle_touch()`, right after the stale-index release lines, add:
```gdscript
	var tapped := _button_at(event.position)
	if tapped != null:
		tapped.pressed.emit()
		return
```
In every button builder (`_build_interaction_button`, `_build_toss_button`, `_build_push_button`, `_build_height_button`, `_make_lock_button`), change:
```gdscript
	button.mouse_filter = Control.MOUSE_FILTER_STOP
```
to:
```gdscript
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps come from _handle_touch
```
This stops one tap from firing twice. The buttons no longer show a pressed look; add a short color flash in `_button_at`'s caller if that is missed.

On a computer, turn on "Emulate Touch From Mouse" to test.
