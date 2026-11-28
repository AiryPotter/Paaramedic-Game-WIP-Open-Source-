extends Control

## All touch input and on-screen buttons. Gameplay scripts never read touches directly.
##
##   - Left half: movement joystick        -> PlayerController.set_movement_input()
##   - Right half: LOOK pad (drag to look)  -> PlayerController.apply_look()
##   - Buttons                              -> PickupInteractor.request_*() and toggles
##   - PAUSE opens the pause menu (scenes/ui/pause_menu.tscn).
##   - Every frame, button text, visibility and enabled state are refreshed from the
##     PickupInteractor, so the UI always shows what an action would do right now.
##   - Where the two pads are drawn, and look sensitivity, come from the player's saved
##     settings in the GameState autoload (changed in the main menu's control editor).
## Each finger is tracked by its touch index, so moving and looking work together.
## See documentation/ARCHITECTURE.md.

@export var player_path: NodePath
@export var interactor_path: NodePath
@export_range(0.0005, 0.02, 0.0005) var look_sensitivity: float = 0.003  ## overwritten by GameState

const JOYSTICK_RADIUS: float = 68.0     ## px; full stick deflection
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

# Button colors: [background, border]
const COLORS_INTERACT := [Color(0.05, 0.23, 0.31, 0.94), Color(0.78, 0.88, 0.94, 0.9)]
const COLORS_TOSS := [Color(0.48, 0.25, 0.06, 0.96), Color(1.0, 0.78, 0.42, 0.95)]
const COLORS_PUSH := [Color(0.08, 0.34, 0.32, 0.96), Color(0.65, 0.9, 0.83, 0.95)]
const COLORS_HEIGHT := [Color(0.28, 0.22, 0.08, 0.96), Color(1.0, 0.84, 0.48, 0.95)]
const COLORS_LOCK := [Color(0.18, 0.22, 0.24, 0.96), Color(0.78, 0.86, 0.88, 0.95)]

var player: PlayerController
var interactor: PickupInteractor
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
var joystick_touch_id: int = -1          ## finger on the joystick, or -1
var look_touch_id: int = -1              ## finger on the LOOK pad, or -1
var joystick_offset: Vector2 = Vector2.ZERO
var look_offset: Vector2 = Vector2.ZERO
var _last_stretcher_grabbed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node(player_path) as PlayerController
	interactor = get_node(interactor_path) as PickupInteractor
	look_sensitivity = GameState.look_sensitivity
	GameState.settings_changed.connect(_on_settings_changed)
	_build_buttons()
	_build_status_panel()
	_build_pause_button()
	pause_menu = PAUSE_MENU_SCENE.instantiate() as Control
	add_child(pause_menu)
	_last_stretcher_grabbed = interactor.is_stretcher_grabbed()
	resized.connect(_reset_touch_state)
	queue_redraw()


## Refreshes every button from the interactor's current state.
func _process(_delta: float) -> void:
	var action_label := interactor.get_action_label()
	if interaction_button.text != action_label:
		interaction_button.text = action_label
	var current_status := interactor.get_status_text()
	var objective := GameState.get_current_objective()
	if not objective.is_empty():
		current_status = "OBJECTIVE: %s\n%s" % [objective, current_status]
	if status_label.text != current_status:
		status_label.text = current_status
	toss_button.visible = interactor.has_held_object()

	var stretcher_grabbed := interactor.is_stretcher_grabbed()
	if stretcher_grabbed != _last_stretcher_grabbed:
		_last_stretcher_grabbed = stretcher_grabbed
		_reset_touch_state()  # a held stick must not carry over between modes
	front_lock_button.visible = stretcher_grabbed
	rear_lock_button.visible = stretcher_grabbed
	front_lock_button.text = interactor.get_front_lock_label()
	rear_lock_button.text = interactor.get_rear_lock_label()
	push_button.visible = stretcher_grabbed
	push_button.text = interactor.get_push_label()
	push_button.disabled = not interactor.can_push_stretcher()
	height_button.visible = stretcher_grabbed
	height_button.text = interactor.get_stretcher_height_label()
	height_button.disabled = not interactor.can_change_stretcher_height()

	if look_touch_id != -1 and interactor.look_control_moves():
		player.set_look_movement_input(look_offset / JOYSTICK_RADIUS)
	else:
		player.set_look_movement_input(Vector2.ZERO)
	queue_redraw()


## iPad apps can lose touches when switching apps or rotating; start clean.
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


# ======================================================================================
# Touch handling
# ======================================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled or not event.pressed:
		_release_touch(event.index)
		return
	# Touch indexes are reused: a new press with a stored index means the old touch ended
	# without us hearing about it.
	if event.index == joystick_touch_id or event.index == look_touch_id:
		_release_touch(event.index)
	if _touch_hits_control(event.position):
		return  # buttons handle their own taps

	if event.position.x < size.x * 0.5:
		if joystick_touch_id == -1:  # a second finger cannot steal the joystick
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
	for button in [interaction_button, toss_button, front_lock_button, rear_lock_button, push_button, height_button]:
		if button.visible and button.get_global_rect().has_point(touch_position):
			return true
	return pause_button.get_global_rect().has_point(touch_position)


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
		if interactor.look_control_moves():
			player.set_look_movement_input(look_offset / JOYSTICK_RADIUS)
		else:
			player.set_look_movement_input(Vector2.ZERO)
			player.apply_look(event.relative * look_sensitivity)
		queue_redraw()


func _update_joystick(touch_position: Vector2) -> void:
	joystick_offset = (touch_position - _joystick_center()).limit_length(JOYSTICK_RADIUS)
	player.set_movement_input(joystick_offset / JOYSTICK_RADIUS)
	queue_redraw()


## Pad centers are saved as a share of the screen size, so they fit any iPad.
func _joystick_center() -> Vector2:
	return GameState.move_joystick_position * size


func _look_joystick_center() -> Vector2:
	return GameState.look_joystick_position * size


# ======================================================================================
# Buttons (all anchored to the bottom center of the screen)
# ======================================================================================

func _build_buttons() -> void:
	interaction_button = _make_button(
		"InteractionButton", "INTERACT",
		"Assess the mannequin, then lower and line up the stretcher before tapping TRANSFER.",
		200.0, -145.0, 18, 12, COLORS_INTERACT, true, interactor.request_interaction
	)
	var pressed_style := interaction_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.12, 0.42, 0.52, 1.0)
	interaction_button.add_theme_stylebox_override("pressed", pressed_style)

	toss_button = _make_button(
		"TossButton", "TOSS", "Toss held equipment. Transfer the mannequin with INTERACT after lining up the lowered stretcher.",
		184.0, -222.0, 18, 12, COLORS_TOSS, false, interactor.request_toss
	)
	# Lock buttons share space with TOSS; they show only while operating the stretcher.
	front_lock_button = _make_button(
		"FrontLockButton", "FRONT: FREE", "",
		220.0, -294.0, 16, 10, COLORS_LOCK, false, interactor.toggle_front_caster_lock
	)
	rear_lock_button = _make_button(
		"RearLockButton", "REAR: FREE", "",
		220.0, -222.0, 16, 10, COLORS_LOCK, false, interactor.toggle_rear_caster_lock
	)
	push_button = _make_button(
		"PushButton", "PUSH", "Release and push the stretcher along the direction you face.",
		220.0, -366.0, 16, 10, COLORS_PUSH, false, interactor.request_push
	)
	height_button = _make_button(
		"StretcherHeightButton", "LOWER", "Lower the stretcher for patient loading, or raise it for transport.",
		220.0, -438.0, 16, 10, COLORS_HEIGHT, false, interactor.request_height_toggle
	)


## A 64 px tall button centered horizontally, top_offset px above the screen's bottom.
## colors is [background, border]. (Tooltips only show on iPad with a trackpad or pencil.)
func _make_button(
	button_name: String,
	label: String,
	tooltip: String,
	width: float,
	top_offset: float,
	font_size: int,
	corner_radius: int,
	colors: Array,
	starts_visible: bool,
	on_pressed: Callable
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.tooltip_text = tooltip
	button.visible = starts_visible
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -width * 0.5
	button.offset_right = width * 0.5
	button.offset_top = top_offset
	button.offset_bottom = top_offset + 64.0
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0]
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(2)
	style.border_color = colors[1]
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(on_pressed)
	add_child(button)
	return button


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
	status_panel.offset_bottom = 158.0  # room for the OBJECTIVE line
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
	status_label.text = interactor.get_status_text()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.93, 0.96, 0.98, 1.0))
	status_panel.add_child(status_label)
	add_child(status_panel)


## PAUSE sits at the top right, just under the status panel.
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


# ======================================================================================
# Drawing: crosshair, joystick and LOOK pad
# ======================================================================================

func _draw() -> void:
	var screen_center := size * 0.5
	var crosshair := Color(1, 1, 1, 0.8)
	draw_line(screen_center + Vector2(-8, 0), screen_center + Vector2(-3, 0), crosshair, 2.0)
	draw_line(screen_center + Vector2(3, 0), screen_center + Vector2(8, 0), crosshair, 2.0)
	draw_line(screen_center + Vector2(0, -8), screen_center + Vector2(0, -3), crosshair, 2.0)
	draw_line(screen_center + Vector2(0, 3), screen_center + Vector2(0, 8), crosshair, 2.0)

	_draw_pad(_joystick_center(), joystick_offset)
	var look_center := _look_joystick_center()
	_draw_pad(look_center, look_offset)
	draw_string(
		ThemeDB.fallback_font,
		look_center + Vector2(0, -JOYSTICK_RADIUS - 12),
		"MOVE" if interactor.look_control_moves() else "LOOK",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		15,
		Color(0.9, 0.94, 1.0, 0.9)
	)


func _draw_pad(center: Vector2, thumb_offset: Vector2) -> void:
	draw_circle(center, JOYSTICK_RADIUS, Color(0.08, 0.10, 0.13, 0.48))
	draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.85, 0.9, 0.95, 0.75), 3.0)
	draw_circle(center + thumb_offset, 25.0, Color(0.76, 0.84, 0.91, 0.88))
