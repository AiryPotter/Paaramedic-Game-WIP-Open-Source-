# Review 1 item 14. UI that scales with the iPad screen

**Source:** Code review 1, item 14 · **Status:** Open · **Priority:** Medium
**Files:** `project.godot`, `ui/mobile_controls.gd` · **Written against:** `9ae595b`. Untested.

**Why:** buttons and joystick sizes are raw pixels, and there is no stretch mode, base size or orientation. On a high-resolution iPad they can be tiny, and look speed changes with resolution. Rounded corners and the home bar (safe area) are not handled.

## Step 1: `project.godot`
Add a `[display]` section (Xogot's Project Settings > Display > Window does the same):
```ini
[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4
```
`orientation=4` is "sensor landscape": either landscape way up. Because of `expand`, a 4:3 iPad shows extra space at the top and bottom instead of black bars.

## Step 2: safe-area margins in `ui/mobile_controls.gd`
Add, and call `_apply_safe_area()` at the end of `_ready()` and in the existing `resized` handler:
```gdscript
func _apply_safe_area() -> void:
	# Keep controls inside the screen's safe area (rounded corners, home indicator).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var screen_size := Vector2(DisplayServer.screen_get_size())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var to_view := get_viewport_rect().size / screen_size
	offset_left = safe.position.x * to_view.x
	offset_top = safe.position.y * to_view.y
	offset_right = -(screen_size.x - safe.end.x) * to_view.x
	offset_bottom = -(screen_size.y - safe.end.y) * to_view.y
```
Changing the offsets resizes the control, which fires `resized` and resets touches. That is fine at startup. Avoid calling it every frame.

## Step 3: retune
After the change, re-check `look_sensitivity`, the joystick radius and button sizes on the iPad. They are now in 1280x720 units.

**Test:** on the iPad, controls are a comfortable size, nothing sits under the rounded corners or home bar, and rotating the iPad either landscape way works.
