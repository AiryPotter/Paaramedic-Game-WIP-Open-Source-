extends Control

const TRAINING_SCENARIO: ScenarioDefinition = preload("res://resources/scenarios/training_sandbox.tres")
const TRAINING_SCENE_PATH := "res://scenes/main/main.tscn"
const CONTROL_LAYOUT_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/control_layout_editor.tscn")

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _look_slider: HSlider
var _volume_slider: HSlider
var _look_value: Label
var _volume_value: Label
var _control_layout_editor: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_control_layout_editor = CONTROL_LAYOUT_EDITOR_SCENE.instantiate() as Control
	add_child(_control_layout_editor)
	_control_layout_editor.connect("saved", _on_control_layout_closed)
	_control_layout_editor.connect("cancelled", _on_control_layout_closed)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.07, 0.085, 1.0)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 500.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var panel_content := VBoxContainer.new()
	panel_content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_content.add_theme_constant_override("separation", 18)
	panel.add_child(panel_content)

	_menu_box = VBoxContainer.new()
	_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_theme_constant_override("separation", 16)
	panel_content.add_child(_menu_box)
	_add_label(_menu_box, "PARAMEDIC SIMULATOR", 30)
	_add_label(_menu_box, TRAINING_SCENARIO.title, 22)
	_add_label(_menu_box, TRAINING_SCENARIO.location, 16)
	_add_label(_menu_box, TRAINING_SCENARIO.briefing, 17)
	var objective_text: String = "OBJECTIVES\n• " + "\n• ".join(TRAINING_SCENARIO.objectives)
	_add_label(_menu_box, objective_text, 15)
	_add_button(_menu_box, "START TRAINING", _start_training)
	_add_button(_menu_box, "SETTINGS", func(): _show_settings(true))

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 12)
	panel_content.add_child(_settings_box)
	_build_settings()
	_settings_box.visible = false


func _build_settings() -> void:
	_add_label(_settings_box, "SETTINGS", 26)
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
	_add_label(parent, caption, 17)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.5
	slider.value = value
	slider.custom_minimum_size = Vector2(330.0, 38.0)
	parent.add_child(slider)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(value_label)
	return slider


func _open_control_layout() -> void:
	_menu_box.visible = false
	_settings_box.visible = false
	_control_layout_editor.call("begin_edit", false)


func _on_control_layout_closed() -> void:
	_show_settings(true)


func _show_settings(show_settings: bool) -> void:
	_menu_box.visible = not show_settings
	_settings_box.visible = show_settings
	if show_settings:
		_look_slider.set_value_no_signal(GameState.look_sensitivity * 1000.0)
		_volume_slider.set_value_no_signal(GameState.master_volume * 100.0)
		_look_value.text = "%.1f" % (GameState.look_sensitivity * 1000.0)
		_volume_value.text = "%d%%" % roundi(GameState.master_volume * 100.0)


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


func _start_training() -> void:
	GameState.start_scenario(TRAINING_SCENARIO)
	get_tree().change_scene_to_file(TRAINING_SCENE_PATH)


func _add_label(parent: VBoxContainer, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(330.0, 58.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.16, 0.98)
	style.border_color = Color(0.36, 0.68, 0.72, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	return style
