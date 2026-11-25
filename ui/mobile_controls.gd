extends Control

## Touch-only movement and look controls. Keep gameplay input here; the player
## controller receives plain vectors and does not depend on this UI node.

@export var player_path: NodePath
@export var interactor_path: NodePath
@export_range(0.0005, 0.02, 0.0005) var look_sensitivity: float = 0.003

const JOYSTICK_RADIUS: float = 68.0
const JOYSTICK_MARGIN: float = 92.0

var player: PlayerController
var interactor: Node
var interaction_button: Button
var toss_button: Button
var front_lock_button: Button
var rear_lock_button: Button
var joystick_touch_id: int = -1
var look_touch_id: int = -1
var joystick_offset: Vector2 = Vector2.ZERO
var look_offset: Vector2 = Vector2.ZERO
var _last_stretcher_grabbed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node(player_path) as PlayerController
	interactor = get_node(interactor_path)
	_build_interaction_button()
	_build_toss_button()
	_build_lock_buttons()
	_last_stretcher_grabbed = bool(interactor.call("is_stretcher_grabbed"))
	resized.connect(_reset_touch_state)
	queue_redraw()


func _process(_delta: float) -> void:
	var action_label := str(interactor.call("get_action_label"))
	if interaction_button.text != action_label:
		interaction_button.text = action_label
	toss_button.visible = bool(interactor.call("has_held_object"))
	var stretcher_grabbed := bool(interactor.call("is_stretcher_grabbed"))
	if stretcher_grabbed != _last_stretcher_grabbed:
		_last_stretcher_grabbed = stretcher_grabbed
		_reset_touch_state()
	front_lock_button.visible = stretcher_grabbed
	rear_lock_button.visible = stretcher_grabbed
	front_lock_button.text = str(interactor.call("get_front_lock_label"))
	rear_lock_button.text = str(interactor.call("get_rear_lock_label"))
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


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled or not event.pressed:
		_release_touch(event.index)
		return
	if _touch_hits_control(event.position):
		return

	if event.position.x < size.x * 0.5 and event.position.y > size.y * 0.45:
		if joystick_touch_id == -1:
			joystick_touch_id = event.index
			_update_joystick(event.position)
	elif event.position.x >= size.x * 0.5 and look_touch_id == -1:
		look_touch_id = event.index
		look_offset = Vector2.ZERO
		player.set_look_movement_input(Vector2.ZERO)
		queue_redraw()


func _touch_hits_control(touch_position: Vector2) -> bool:
	if interaction_button.get_global_rect().has_point(touch_position):
		return true
	if toss_button.visible and toss_button.get_global_rect().has_point(touch_position):
		return true
	if front_lock_button.visible and front_lock_button.get_global_rect().has_point(touch_position):
		return true
	if rear_lock_button.visible and rear_lock_button.get_global_rect().has_point(touch_position):
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
	return Vector2(JOYSTICK_MARGIN, size.y - JOYSTICK_MARGIN)


func _build_interaction_button() -> void:
	interaction_button = Button.new()
	interaction_button.name = "InteractionButton"
	interaction_button.text = "INTERACT"
	interaction_button.tooltip_text = "Aim at a pickupable object to pick it up or release it."
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


func _build_toss_button() -> void:
	toss_button = Button.new()
	toss_button.name = "TossButton"
	toss_button.text = "TOSS"
	toss_button.tooltip_text = "Give the carried bag a short underhand toss."
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

	var look_center := Vector2(size.x - JOYSTICK_MARGIN, size.y - JOYSTICK_MARGIN)
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
