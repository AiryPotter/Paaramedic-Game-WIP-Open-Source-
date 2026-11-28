extends SceneTree

## Runs the QA suite from a computer without opening a window. Not used by the game.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/run_qa_headless.gd --quit-after 30000
##
## Why the extra steps:
##   - A headless window is only 64 x 64 px, which breaks the touch-zone tests, so the
##     suite runs inside an iPad-sized SubViewport.
##   - --fixed-fps 60 makes time pass like a 60 Hz iPad. Without it, frames run as fast
##     as the computer can go and the camera-transition tests finish too early.
## Results print as [QA] lines and are saved to user://qa_runner_latest.txt.

const IPAD_VIEW_SIZE := Vector2i(1366, 1024)


func _initialize() -> void:
	var holder := SubViewport.new()
	holder.size = IPAD_VIEW_SIZE
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(holder)
	await process_frame
	holder.add_child(load("res://tests/qa_runner.tscn").instantiate())
