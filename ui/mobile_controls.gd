extends Control

## Touch-only movement and look controls. Keep gameplay input here; the player
## controller receives plain vectors and does not depend on this UI node.

@export var player_path: NodePath
@export var interactor_path: NodePath
@export_range(0.0005, 0.02, 0.0005) var look_sensitivity: float = 0.003

const JOYSTICK_RADIUS: float = 68.0
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

var player: PlayerController
var interactor: Node
var interaction_button: Button
var status_panel: PanelContainer
var status_label: Label
var toss_button: Button
var push_button: Button
var height_button: Button
var front_lock_button: Button
var rear_lock_button: Button
var pause_button: Button
var pause_menu: Control
var joystick_touch_id: int = -1
var look_touch_id: int = -1
var joystick_offset: Vector2 = Vector2.ZERO
var look_offset: Vector2 = Vector2.ZERO
var _last_stretcher_grabbed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node(player_path) as PlayerController
	interactor = get_node(interactor_path)
	look_sensitivity = GameState.look_sensitivity
	GameState.settings_changed.connect(_on_settings_changed)
	_build_interaction_button()
	_build_status_panel()
	_build_toss_button()
	_build_lock_buttons()
	_build_push_button()
	_build_height_button()
	_build_pause_button()
	pause_menu = PAUSE_MENU_SCENE.instantiate() as Control
	add_child(pause_menu)
	_last_stretcher_grabbed = bool(interactor.call("is_stretcher_grabbed"))
	resized.connect(_reset_touch_state)
	queue_redraw()


func _process(_delta: float) -> void:
	var action_label := str(interactor.call("get_action_label"))
	if interaction_button.text != action_label:
		interaction_button.text = action_label
	var current_status := str(interactor.call("get_status_text"))
	var objective := GameState.get_current_objective()
	if not objective.is_empty():
		current_status = "OBJECTIVE: %s\n%s" % [objective, current_status]
	if status_label.text != current_status:
		status_label.text = current_status
	toss_button.visible = bool(interactor.call("has_held_object"))
	var stretcher_grabbed := bool(interactor.call("is_stretcher_grabbed"))
	if stretcher_grabbed != _last_stretcher_grabbed:
		_last_stretcher_grabbed = stretcher_grabbed
		_reset_touch_state()
	front_lock_button.visible = stretcher_grabbed
	rear_lock_button.visible = stretcher_grabbed
	front_lock_button.text = str(interactor.call("get_front_lock_label"))
	rear_lock_button.text = str(interactor.call("get_rear_lock_label"))
	push_button.visible = stretcher_grabbed
	push_button.text = str(interactor.call("get_push_label"))
	push_button.disabled = not bool(interactor.call("can_push_stretcher"))
	height_button.visible = stretcher_grabbed
	height_button.text = str(interactor.call("get_stretcher_height_label"))
	height_button.disabled = not bool(interactor.call("can_change_stretcher_height"))
	if look_touch_id != -1 and bool(interactor.call("look_control_moves")):
		player.set_look_movement_input(look_offset / JOYSTICK_RADIUS)
	else:
		player.set_look_movement_input(Vector2.ZERO)
	queue_redraw()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
		or what == NOTIFICATION_WM_WINDOW_FOCUS_IN
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_RESUMED
	):
		_reset_touch_state()


func _exit_tree() -> void:
	_reset_touch_state()
	if GameState.settings_changed.is_connected(_on_settings_changed):
		GameState.settings_changed.disconnect(_on_settings_changed)


func _on_settings_changed() -> void:
	look_sensitivity = GameState.look_sensitivity
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled or not event.pressed:
		_release_touch(event.index)
		return
	if event.index == joystick_touch_id or event.index == look_touch_id:
		_release_touch(event.index)
	if _touch_hits_control(event.position):
		return

	if event.position.x < size.x * 0.5:
		if joystick_touch_id == -1:
			joystick_touch_id = event.index
			_update_joystick(event.position)
	elif event.position.x >= size.x * 0.5 and look_touch_id == -1:
		look_touch_id = event.index
		look_offset = Vector2.ZERO
		player.set_look_movement_input(Vector2.ZERO)
		queue_redraw()


func _touch_hits_control(touch_position: Vector2) -> bool:
	if status_panel.get_global_rect().has_point(touch_position):
		return true
	if interaction_button.get_global_rect().has_point(touch_position):
		return true
	if toss_button.visible and toss_button.get_global_rect().has_point(touch_position):
		return true
	if front_lock_button.visible and front_lock_button.get_global_rect().has_point(touch_position):
		return true
	if rear_lock_button.visible and rear_lock_button.get_global_rect().has_point(touch_position):
		return true
	if push_button.visible and push_button.get_global_rect().has_point(touch_position):
		return true
	if height_button.visible and height_button.get_global_rect().has_point(touch_position):
		return true
	if pause_button.get_global_rect().has_point(touch_position):
		return true
	return false


func _release_touch(touch_id: int) -> void:
	if touch_id == joystick_touch_id:
		joystick_touch_id = -1
		joystick_offset = Vector2.ZERO
		player.set_movement_input(Vector2.ZERO)
		queue_redraw()
	elif touch_id == look_touch_id:
		look_touch_id = -1
		look_offset = Vector2.ZERO
		player.set_look_movement_input(Vector2.ZERO)
		queue_redraw()


func _reset_touch_state() -> void:
	joystick_touch_id = -1
	look_touch_id = -1
	joystick_offset = Vector2.ZERO
	look_offset = Vector2.ZERO
	if is_instance_valid(player):
		player.set_movement_input(Vector2.ZERO)
		player.set_look_movement_input(Vector2.ZERO)
	queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_id:
		_update_joystick(event.position)
	elif event.index == look_touch_id:
		look_offset = (look_offset + event.relative).limit_length(JOYSTICK_RADIUS)
		if bool(interactor.call("look_control_moves")):
			player.set_look_movement_input(look_offset / JOYSTICK_RADIUS)
		else:
			player.set_look_movement_input(Vector2.ZERO)
			player.apply_look(event.relative * look_sensitivity)
		queue_redraw()


func _update_joystick(touch_position: Vector2) -> void:
	var center := _joystick_center()
	joystick_offset = (touch_position - center).limit_length(JOYSTICK_RADIUS)
	player.set_movement_input(joystick_offset / JOYSTICK_RADIUS)
	queue_redraw()


func _joystick_center() -> Vector2:
	return GameState.move_joystick_position * size


func _look_joystick_center() -> Vector2:
	return GameState.look_joystick_position * size


func _build_interaction_button() -> void:
	interaction_button = Button.new()
	interaction_button.name = "InteractionButton"
	interaction_button.text = "INTERACT"
	interaction_button.tooltip_text = "Assess the mannequin, then lower and line up the stretcher before tapping TRANSFER."
	interaction_button.focus_mode = Control.FOCUS_NONE
	interaction_button.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_button.anchor_left = 0.5
	interaction_button.anchor_right = 0.5
	interaction_button.anchor_top = 1.0
	interaction_button.anchor_bottom = 1.0
	interaction_button.offset_left = -100.0
	interaction_button.offset_right = 100.0
	interaction_button.offset_top = -145.0
	interaction_button.offset_bottom = -81.0
	interaction_button.add_theme_font_size_override("font_size", 18)
	interaction_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.05, 0.23, 0.31, 0.94)
	normal_style.set_corner_radius_all(12)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.78, 0.88, 0.94, 0.9)
	interaction_button.add_theme_stylebox_override("normal", normal_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.12, 0.42, 0.52, 1.0)
	interaction_button.add_theme_stylebox_override("pressed", pressed_style)
	interaction_button.pressed.connect(_on_interaction_pressed)
	add_child(interaction_button)


func _build_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.anchor_left = 0.0
	status_panel.anchor_right = 1.0
	status_panel.anchor_top = 0.0
	status_panel.anchor_bottom = 0.0
	status_panel.offset_left = 16.0
	status_panel.offset_right = -16.0
	status_panel.offset_top = 16.0
	status_panel.offset_bottom = 158.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.14, 0.19, 0.92)
	panel_style.set_corner_radius_all(12)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.55, 0.72, 0.78, 0.9)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	status_panel.add_theme_stylebox_override("panel", panel_style)

	status_label = Label.new()
	status_label.name = "StatusText"
	status_label.text = str(interactor.call("get_status_text"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.93, 0.96, 0.98, 1.0))
	status_panel.add_child(status_label)
	add_child(status_panel)


func _build_toss_button() -> void:
	toss_button = Button.new()
	toss_button.name = "TossButton"
	toss_button.text = "TOSS"
	toss_button.tooltip_text = "Toss held equipment. Transfer the mannequin with INTERACT after lining up the lowered stretcher."
	toss_button.visible = false
	toss_button.focus_mode = Control.FOCUS_NONE
	toss_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toss_button.anchor_left = 0.5
	toss_button.anchor_right = 0.5
	toss_button.anchor_top = 1.0
	toss_button.anchor_bottom = 1.0
	toss_button.offset_left = -92.0
	toss_button.offset_right = 92.0
	toss_button.offset_top = -222.0
	toss_button.offset_bottom = -158.0
	toss_button.add_theme_font_size_override("font_size", 18)
	toss_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var toss_style := StyleBoxFlat.new()
	toss_style.bg_color = Color(0.48, 0.25, 0.06, 0.96)
	toss_style.set_corner_radius_all(12)
	toss_style.set_border_width_all(2)
	toss_style.border_color = Color(1.0, 0.78, 0.42, 0.95)
	toss_button.add_theme_stylebox_override("normal", toss_style)
	toss_button.pressed.connect(_on_toss_pressed)
	add_child(toss_button)


func _build_push_button() -> void:
	push_button = Button.new()
	push_button.name = "PushButton"
	push_button.text = "PUSH"
	push_button.tooltip_text = "Release and push the stretcher along the direction you face."
	push_button.visible = false
	push_button.focus_mode = Control.FOCUS_NONE
	push_button.mouse_filter = Control.MOUSE_FILTER_STOP
	push_button.anchor_left = 0.5
	push_button.anchor_right = 0.5
	push_button.anchor_top = 1.0
	push_button.anchor_bottom = 1.0
	push_button.offset_left = -110.0
	push_button.offset_right = 110.0
	push_button.offset_top = -366.0
	push_button.offset_bottom = -302.0
	push_button.add_theme_font_size_override("font_size", 16)
	push_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.34, 0.32, 0.96)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.65, 0.9, 0.83, 0.95)
	push_button.add_theme_stylebox_override("normal", style)
	push_button.pressed.connect(_on_push_pressed)
	add_child(push_button)


func _on_push_pressed() -> void:
	interactor.call("request_push")


func _build_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "PAUSE"
	pause_button.tooltip_text = "Pause the training session."
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	pause_button.offset_left = -112.0
	pause_button.offset_right = -24.0
	pause_button.offset_top = 166.0
	pause_button.offset_bottom = 220.0
	pause_button.add_theme_font_size_override("font_size", 16)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)


func _on_pause_pressed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.call("open")


func _build_height_button() -> void:
	height_button = Button.new()
	height_button.name = "StretcherHeightButton"
	height_button.text = "LOWER"
	height_button.tooltip_text = "Lower the stretcher for patient loading, or raise it for transport."
	height_button.visible = false
	height_button.focus_mode = Control.FOCUS_NONE
	height_button.mouse_filter = Control.MOUSE_FILTER_STOP
	height_button.anchor_left = 0.5
	height_button.anchor_right = 0.5
	height_button.anchor_top = 1.0
	height_button.anchor_bottom = 1.0
	height_button.offset_left = -110.0
	height_button.offset_right = 110.0
	height_button.offset_top = -438.0
	height_button.offset_bottom = -374.0
	height_button.add_theme_font_size_override("font_size", 16)
	height_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.22, 0.08, 0.96)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.84, 0.48, 0.95)
	height_button.add_theme_stylebox_override("normal", style)
	height_button.pressed.connect(_on_height_pressed)
	add_child(height_button)


func _on_height_pressed() -> void:
	interactor.call("request_height_toggle")


func _build_lock_buttons() -> void:
	front_lock_button = _make_lock_button(
		"FrontLockButton", "FRONT: FREE", -294.0, _on_front_lock_pressed
	)
	rear_lock_button = _make_lock_button(
		"RearLockButton", "REAR: FREE", -222.0, _on_rear_lock_pressed
	)


func _make_lock_button(button_name: String, label: String, top_offset: float, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.visible = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -110.0
	button.offset_right = 110.0
	button.offset_top = top_offset
	button.offset_bottom = top_offset + 64.0
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.24, 0.96)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.78, 0.86, 0.88, 0.95)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(pressed_callback)
	add_child(button)
	return button


func _on_front_lock_pressed() -> void:
	interactor.call("toggle_front_caster_lock")


func _on_rear_lock_pressed() -> void:
	interactor.call("toggle_rear_caster_lock")


func _on_interaction_pressed() -> void:
	interactor.call("request_interaction")


func _on_toss_pressed() -> void:
	interactor.call("request_toss")


func _draw() -> void:
	var screen_center := size * 0.5
	draw_line(screen_center + Vector2(-8, 0), screen_center + Vector2(-3, 0), Color(1, 1, 1, 0.8), 2.0)
	draw_line(screen_center + Vector2(3, 0), screen_center + Vector2(8, 0), Color(1, 1, 1, 0.8), 2.0)
	draw_line(screen_center + Vector2(0, -8), screen_center + Vector2(0, -3), Color(1, 1, 1, 0.8), 2.0)
	draw_line(screen_center + Vector2(0, 3), screen_center + Vector2(0, 8), Color(1, 1, 1, 0.8), 2.0)
	var center := _joystick_center()
	draw_circle(center, JOYSTICK_RADIUS, Color(0.08, 0.10, 0.13, 0.48))
	draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.85, 0.9, 0.95, 0.75), 3.0)
	draw_circle(center + joystick_offset, 25.0, Color(0.76, 0.84, 0.91, 0.88))

	var look_center := _look_joystick_center()
	draw_circle(look_center, JOYSTICK_RADIUS, Color(0.08, 0.10, 0.13, 0.48))
	draw_arc(look_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.85, 0.9, 0.95, 0.75), 3.0)
	draw_circle(look_center + look_offset, 25.0, Color(0.76, 0.84, 0.91, 0.88))
	draw_string(
		ThemeDB.fallback_font,
		look_center + Vector2(0, -JOYSTICK_RADIUS - 12),
		"MOVE" if bool(interactor.call("look_control_moves")) else "LOOK",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		15,
		Color(0.9, 0.94, 1.0, 0.9)
	)
