extends Control
class_name ControlLayoutEditor

signal saved
signal cancelled
signal return_to_game

const PAD_RADIUS: float = 68.0
const DRAG_RADIUS: float = 92.0
const CENTER_UI_HALF_WIDTH: float = 110.0
const UI_GAP: float = 12.0
const MOVE_CONTROL: int = 1
const LOOK_CONTROL: int = 2

var _move_position: Vector2 = Vector2(0.09, 0.67)
var _look_position: Vector2 = Vector2(0.91, 0.67)
var _dragging_control: int = 0
var _dragging_touch_index: int = -1
var _mouse_dragging: bool = false
var _save_resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_actions()
	resized.connect(_on_resized)
	visible = false


func begin_edit(show_resume_button: bool = false) -> void:
	_save_resume_button.visible = show_resume_button
	_move_position = GameState.move_joystick_position
	_look_position = GameState.look_joystick_position
	_clamp_positions_to_viewport()
	visible = true
	queue_redraw()


func _build_actions() -> void:
	var title := Label.new()
	title.text = "CUSTOMIZE TOUCH CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.1
	title.anchor_right = 0.9
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_top = 24.0
	title.offset_bottom = 64.0
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)

	var instructions := Label.new()
	instructions.text = "Drag each pad to reposition it. MOVE stays on the left; LOOK stays on the right."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.anchor_left = 0.08
	instructions.anchor_right = 0.92
	instructions.anchor_top = 0.0
	instructions.anchor_bottom = 0.0
	instructions.offset_top = 70.0
	instructions.offset_bottom = 118.0
	instructions.add_theme_font_size_override("font_size", 16)
	add_child(instructions)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	var button_width := minf(170.0, maxf(132.0, (get_viewport_rect().size.x - 52.0) * 0.5 - 6.0))
	var actions_width := button_width * 2.0 + 12.0
	actions.anchor_left = 0.5
	actions.anchor_right = 0.5
	actions.anchor_top = 0.0
	actions.anchor_bottom = 0.0
	actions.offset_left = -actions_width * 0.5
	actions.offset_right = actions_width * 0.5
	actions.offset_top = 124.0
	actions.offset_bottom = 238.0
	add_child(actions)

	var primary_row := HBoxContainer.new()
	primary_row.name = "PrimaryActions"
	primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_row.add_theme_constant_override("separation", 12)
	actions.add_child(primary_row)
	_add_action_button(primary_row, "ResetButton", "RESET", _reset_positions, button_width)
	_add_action_button(primary_row, "CancelButton", "CANCEL", _cancel, button_width)

	var save_row := HBoxContainer.new()
	save_row.name = "SaveActions"
	save_row.alignment = BoxContainer.ALIGNMENT_CENTER
	save_row.add_theme_constant_override("separation", 12)
	actions.add_child(save_row)
	_add_action_button(save_row, "SaveButton", "SAVE", _save, button_width)
	_save_resume_button = _add_action_button(
		save_row, "SaveResumeButton", "SAVE & RESUME", _save_and_resume, button_width
	)
	_save_resume_button.visible = false


func _add_action_button(
	parent: HBoxContainer,
	button_name: String,
	label: String,
	callback: Callable,
	button_width: float
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.custom_minimum_size = Vector2(button_width, 52.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position, event.index)
		elif event.index == _dragging_touch_index:
			_end_drag()
	elif event is InputEventScreenDrag and event.index == _dragging_touch_index:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position, -2)
			_mouse_dragging = _dragging_control != 0
		elif _mouse_dragging:
			_end_drag()
			_mouse_dragging = false
	elif event is InputEventMouseMotion and _mouse_dragging:
		_drag_to(event.position)


func _begin_drag(pointer_position: Vector2, touch_index: int) -> void:
	if _dragging_control != 0:
		return
	var move_center := _move_position * size
	var look_center := _look_position * size
	if pointer_position.distance_to(move_center) <= DRAG_RADIUS:
		_dragging_control = MOVE_CONTROL
		_dragging_touch_index = touch_index
		_drag_to(pointer_position)
	elif pointer_position.distance_to(look_center) <= DRAG_RADIUS:
		_dragging_control = LOOK_CONTROL
		_dragging_touch_index = touch_index
		_drag_to(pointer_position)


func _drag_to(pointer_position: Vector2) -> void:
	var safe_margin := minf(PAD_RADIUS, minf(size.x, size.y) * 0.2)
	var min_y := maxf(safe_margin, size.y * 0.38)
	var center := Vector2(
		clampf(pointer_position.x, safe_margin, size.x - safe_margin),
		clampf(pointer_position.y, min_y, size.y - safe_margin)
	)
	if _dragging_control == MOVE_CONTROL:
		var left_max := maxf(
			safe_margin,
			minf(size.x * 0.32, size.x * 0.5 - CENTER_UI_HALF_WIDTH - PAD_RADIUS - UI_GAP)
		)
		center.x = clampf(center.x, safe_margin, left_max)
		_move_position = center / size
	elif _dragging_control == LOOK_CONTROL:
		var right_min := minf(
			size.x - safe_margin,
			maxf(size.x * 0.68, size.x * 0.5 + CENTER_UI_HALF_WIDTH + PAD_RADIUS + UI_GAP)
		)
		center.x = clampf(center.x, right_min, size.x - safe_margin)
		_look_position = center / size
	queue_redraw()


func _end_drag() -> void:
	_dragging_control = 0
	_dragging_touch_index = -1


func _reset_positions() -> void:
	_move_position = GameState.DEFAULT_MOVE_JOYSTICK_POSITION
	_look_position = GameState.DEFAULT_LOOK_JOYSTICK_POSITION
	_clamp_positions_to_viewport()
	queue_redraw()


func _clamp_positions_to_viewport() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe_margin := minf(PAD_RADIUS, minf(size.x, size.y) * 0.2)
	var min_y := maxf(safe_margin, size.y * 0.38)
	var left_max := maxf(
		safe_margin,
		minf(size.x * 0.32, size.x * 0.5 - CENTER_UI_HALF_WIDTH - PAD_RADIUS - UI_GAP)
	)
	var right_min := minf(
		size.x - safe_margin,
		maxf(size.x * 0.68, size.x * 0.5 + CENTER_UI_HALF_WIDTH + PAD_RADIUS + UI_GAP)
	)
	var move_center := _move_position * size
	var look_center := _look_position * size
	move_center.x = clampf(move_center.x, safe_margin, left_max)
	move_center.y = clampf(move_center.y, min_y, size.y - safe_margin)
	look_center.x = clampf(look_center.x, right_min, size.x - safe_margin)
	look_center.y = clampf(look_center.y, min_y, size.y - safe_margin)
	_move_position = move_center / size
	_look_position = look_center / size


func _on_resized() -> void:
	_clamp_positions_to_viewport()
	queue_redraw()


func _save() -> void:
	_commit_layout()
	visible = false
	saved.emit()


func _save_and_resume() -> void:
	_commit_layout()
	visible = false
	return_to_game.emit()


func _commit_layout() -> void:
	GameState.move_joystick_position = _move_position
	GameState.look_joystick_position = _look_position
	GameState.save_settings()


func _cancel() -> void:
	cancelled.emit()
	visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.035, 0.94), true)
	_draw_pad(_move_position * size, "MOVE", Color(0.18, 0.55, 0.48, 0.85))
	_draw_pad(_look_position * size, "LOOK", Color(0.26, 0.44, 0.68, 0.85))


func _draw_pad(center: Vector2, label: String, color: Color) -> void:
	draw_circle(center, PAD_RADIUS, Color(color.r, color.g, color.b, 0.28))
	draw_arc(center, PAD_RADIUS, 0.0, TAU, 48, color, 4.0)
	draw_circle(center, 28.0, Color(color.r, color.g, color.b, 0.75))
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(0.0, 6.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color(1.0, 1.0, 1.0, 1.0)
	)
