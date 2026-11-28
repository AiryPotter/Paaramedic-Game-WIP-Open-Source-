extends Control

## Touch-safe pause and settings overlay; remains interactive while the tree is paused.

const CONTROL_LAYOUT_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/control_layout_editor.tscn")

var _shade: ColorRect
var _content: VBoxContainer
var _settings_box: VBoxContainer
var _look_slider: HSlider
var _volume_slider: HSlider
var _look_value: Label
var _volume_value: Label
var _control_layout_editor: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_control_layout_editor = CONTROL_LAYOUT_EDITOR_SCENE.instantiate() as Control
	add_child(_control_layout_editor)
	_control_layout_editor.connect("saved", _on_control_layout_closed)
	_control_layout_editor.connect("cancelled", _on_control_layout_closed)
	_control_layout_editor.connect("return_to_game", _resume_from_control_layout)
	visible = false


func open() -> void:
	visible = true
	_show_settings(false)
	GameState.set_paused(true)


func close() -> void:
	visible = false
	GameState.set_paused(false)


func _build_ui() -> void:
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.015, 0.025, 0.035, 0.82)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 420.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	panel.add_child(panel_content)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 14)
	panel_content.add_child(_content)
	_add_title(_content, "PAUSED")
	_add_button(_content, "RESUME", close)
	_add_button(_content, "RESTART TRAINING", _restart)
	_add_button(_content, "SETTINGS", func(): _show_settings(true))
	_add_button(_content, "MAIN MENU", _return_to_menu)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	panel_content.add_child(_settings_box)
	_build_settings()
	_settings_box.visible = false


func _build_settings() -> void:
	_add_title(_settings_box, "SETTINGS")
	_look_slider = _add_slider(_settings_box, "Look sensitivity", 0.5, 20.0, GameState.look_sensitivity * 1000.0)
	_look_value = _settings_box.get_child(_settings_box.get_child_count() - 1) as Label
	_volume_slider = _add_slider(_settings_box, "Master volume", 0.0, 100.0, GameState.master_volume * 100.0)
	_volume_value = _settings_box.get_child(_settings_box.get_child_count() - 1) as Label
	_look_slider.value_changed.connect(_on_look_changed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_look_slider.drag_ended.connect(_on_settings_drag_ended)
	_volume_slider.drag_ended.connect(_on_settings_drag_ended)
	_add_button(_settings_box, "CUSTOMIZE TOUCH CONTROLS", _open_control_layout)
	_add_button(_settings_box, "BACK", func(): _show_settings(false))


func _add_slider(parent: VBoxContainer, caption: String, minimum: float, maximum: float, value: float) -> HSlider:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.5
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 36.0)
	parent.add_child(slider)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(value_label)
	return slider


func _open_control_layout() -> void:
	_content.visible = false
	_settings_box.visible = false
	_control_layout_editor.call("begin_edit", true)


func _resume_from_control_layout() -> void:
	visible = false
	GameState.set_paused(false)


func _on_control_layout_closed() -> void:
	_show_settings(true)


func _on_look_changed(value: float) -> void:
	GameState.look_sensitivity = value / 1000.0
	_look_value.text = "%.1f" % value
	GameState.apply_settings()


func _on_volume_changed(value: float) -> void:
	GameState.master_volume = value / 100.0
	_volume_value.text = "%d%%" % roundi(value)
	GameState.apply_settings()


func _on_settings_drag_ended(value_changed: bool) -> void:
	if value_changed:
		GameState.save_settings()


func _show_settings(show_settings: bool) -> void:
	if not is_instance_valid(_content) or not is_instance_valid(_settings_box):
		return
	_content.visible = not show_settings
	_settings_box.visible = show_settings
	if show_settings:
		_look_slider.set_value_no_signal(GameState.look_sensitivity * 1000.0)
		_volume_slider.set_value_no_signal(GameState.master_volume * 100.0)
		_look_value.text = "%.1f" % (GameState.look_sensitivity * 1000.0)
		_volume_value.text = "%d%%" % roundi(GameState.master_volume * 100.0)


func _restart() -> void:
	visible = false
	GameState.restart_scenario()


func _return_to_menu() -> void:
	visible = false
	GameState.return_to_menu()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.15, 0.98)
	style.border_color = Color(0.55, 0.72, 0.74, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	return style


func _add_title(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	parent.add_child(label)


func _add_button(parent: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(300.0, 54.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
