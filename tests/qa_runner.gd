extends Node3D

## Device-runnable smoke tests for the current training prototype.
## Open res://tests/qa_runner.tscn and run it from Xogot.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const MAX_TRANSITION_FRAMES := 90
const TOUCH_ID_FOR_TEST := 71

var _main: Node3D
var _player: CharacterBody3D
var _stretcher: RigidBody3D
var _patient: RigidBody3D
var _bag: RigidBody3D
var _kole: RigidBody3D
var _interactor: Node
var _mobile_controls: Control
var _camera: Camera3D
var _results: Array[String] = []
var _passes: int = 0
var _failures: int = 0
var _running: bool = false
var _summary_label: Label
var _results_label: Label
var _run_button: Button


func _ready() -> void:
	_build_report_ui()
	await get_tree().process_frame
	await _run_suite()


func _build_report_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "QAReportLayer"
	canvas.layer = 100
	add_child(canvas)

	var blocker := ColorRect.new()
	blocker.name = "InputBlocker"
	blocker.color = Color(0.025, 0.045, 0.06, 0.52)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(blocker)

	var panel := PanelContainer.new()
	panel.name = "ReportPanel"
	panel.anchor_left = 0.04
	panel.anchor_top = 0.04
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.96
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	blocker.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "PARAMEDIC SIMULATOR — QA RUNNER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	_summary_label = Label.new()
	_summary_label.text = "Preparing tests…"
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary_label)

	var results_scroll := ScrollContainer.new()
	results_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(results_scroll)

	_results_label = Label.new()
	_results_label.text = ""
	_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_label.custom_minimum_size = Vector2(0.0, 260.0)
	results_scroll.add_child(_results_label)

	_run_button = Button.new()
	_run_button.text = "RUN AGAIN"
	_run_button.custom_minimum_size = Vector2(0.0, 56.0)
	_run_button.pressed.connect(_on_run_again_pressed)
	column.add_child(_run_button)


func _run_suite() -> void:
	if _running:
		return
	_running = true
	_run_button.disabled = true
	_results.clear()
	_passes = 0
	_failures = 0
	_summary_label.text = "Loading the main scene and running checks…"
	_results_label.text = ""

	if is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await get_tree().process_frame

	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_record("Main scene can be loaded", false, MAIN_SCENE_PATH + " did not load.")
		await _finish_suite()
		return

	_main = packed_scene.instantiate() as Node3D
	if _main == null:
		_record("Main scene root", false, "Expected a Node3D main-scene root.")
		await _finish_suite()
		return
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame

	_resolve_main_nodes()
	var required_nodes_ok := (
		is_instance_valid(_player)
		and is_instance_valid(_stretcher)
		and is_instance_valid(_patient)
		and is_instance_valid(_bag)
		and is_instance_valid(_kole)
		and is_instance_valid(_interactor)
		and is_instance_valid(_mobile_controls)
		and is_instance_valid(_camera)
	)
	_record(
		"Main-scene setup",
		required_nodes_ok,
		"Player, camera, interactor, controls, stretcher, patient, bags, and KOLE are present."
	)
	if not required_nodes_ok:
		await _finish_suite()
		return

	_mobile_controls.set_process_input(false)
	_test_camera_and_world()
	await _test_stretcher_collision_shapes()
	await _test_patient_ray_target()
	_test_touch_id_reuse()
	await _test_kole_impacts()
	await _test_stretcher_patient_and_pad()
	await _test_bumps_with_caster_locks()
	await _test_push_button()

	_results.append("MANUAL: Real multitouch, app-switch recovery, visual feel, and Xogot-level black-screen behavior still need an iPad check.")
	await _finish_suite()


func _resolve_main_nodes() -> void:
	_player = _main.get_node_or_null("Player") as CharacterBody3D
	_stretcher = _main.get_node_or_null("Stretcher") as RigidBody3D
	_patient = _main.get_node_or_null("TrainingPatient") as RigidBody3D
	_bag = _main.get_node_or_null("PrimaryBag") as RigidBody3D
	_kole = _main.get_node_or_null("KOLEDefibrillator") as RigidBody3D
	if is_instance_valid(_player):
		_interactor = _player.get_node_or_null("Interactor")
		_camera = _player.get_node_or_null("Camera3D") as Camera3D
	_mobile_controls = _main.get_node_or_null("MobileControlsLayer/MobileControls") as Control


func _test_camera_and_world() -> void:
	var environment_node := _main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_record(
		"Active camera and environment",
		_camera.current and environment_node != null and environment_node.environment != null,
		"Checks engine setup; it cannot detect an Xogot host-rendering failure."
	)


func _test_patient_ray_target() -> void:
	var saved_player_transform := _player.global_transform
	var saved_camera_transform := _camera.global_transform
	_player.velocity = Vector3.ZERO
	_player.call("set_movement_input", Vector2.ZERO)
	_player.call("set_look_movement_input", Vector2.ZERO)
	_player.global_position = _patient.global_position + Vector3(0.0, 0.0, 1.8)
	_camera.look_at(_patient.global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP)
	await get_tree().physics_frame
	_interactor.call("_refresh_aim_target")
	var aimed_patient: Node = _interactor.call("_get_aimed_patient") as Node
	_record(
		"Patient Area3D aim resolves to patient",
		aimed_patient == _patient,
		"The ray can hit the interaction area and find its grouped parent."
	)
	await get_tree().process_frame
	var aimed_distance := float(_interactor.get("_aimed_distance"))
	var action_distance := float(_interactor.get("bag_interaction_distance"))
	var expected_action := "APPROACH PATIENT" if aimed_distance > action_distance else "ASSESS PATIENT"
	var interaction_button := _mobile_controls.get_node_or_null("InteractionButton") as Button
	_record(
		"Patient target updates mobile action label",
		aimed_patient == _patient
			and str(_interactor.call("get_action_label")) == expected_action
			and interaction_button != null
			and interaction_button.text == expected_action,
		"Action: %s." % expected_action
	)
	_patient.call("assess_patient")
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_hint := str(_patient.call("get_transfer_hint", _stretcher))
	_record(
		"Assessment leads to a TRANSFER hint, never PICK UP",
		interaction_button != null
			and not expected_hint.is_empty()
			and str(_interactor.call("get_action_label")) == expected_hint
			and interaction_button.text == expected_hint,
		"Action: %s." % expected_hint
	)
	_patient.set("assessment_started", false)
	_player.global_transform = saved_player_transform
	_camera.global_transform = saved_camera_transform
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame


func _test_touch_id_reuse() -> void:
	var viewport_size := _mobile_controls.size
	var joystick_center := Vector2(92.0, viewport_size.y - 92.0)
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = TOUCH_ID_FOR_TEST
	first_touch.pressed = true
	first_touch.position = joystick_center + Vector2(0.0, -36.0)
	_mobile_controls.call("_handle_touch", first_touch)

	var reuse_touch := InputEventScreenTouch.new()
	reuse_touch.index = TOUCH_ID_FOR_TEST
	reuse_touch.pressed = true
	reuse_touch.position = joystick_center + Vector2(36.0, 0.0)
	_mobile_controls.call("_handle_touch", reuse_touch)

	var reused_id := int(_mobile_controls.get("joystick_touch_id")) == TOUCH_ID_FOR_TEST
	var movement: Vector2 = _player.get("movement_input")
	_record(
		"Reused touch ID updates joystick",
		reused_id and movement.x > 0.1 and absf(movement.y) < 0.1,
		"Synthetic touch events exercise the UI handler, not the physical iPad digitizer."
	)

	var second_finger := InputEventScreenTouch.new()
	second_finger.index = TOUCH_ID_FOR_TEST + 1
	second_finger.pressed = true
	second_finger.position = joystick_center + Vector2(-30.0, 0.0)
	_mobile_controls.call("_handle_touch", second_finger)
	_record(
		"Second touch does not steal joystick",
		int(_mobile_controls.get("joystick_touch_id")) == TOUCH_ID_FOR_TEST,
		"The original joystick finger remains assigned."
	)

	_mobile_controls.call("_release_touch", TOUCH_ID_FOR_TEST + 1)
	_mobile_controls.call("_release_touch", TOUCH_ID_FOR_TEST)
	var released_movement: Vector2 = _player.get("movement_input")
	_record(
		"Joystick release clears movement",
		int(_mobile_controls.get("joystick_touch_id")) == -1 and released_movement == Vector2.ZERO,
		""
	)

	_mobile_controls.call("_handle_touch", first_touch)
	_mobile_controls.notification(NOTIFICATION_APPLICATION_PAUSED)
	var paused_movement: Vector2 = _player.get("movement_input")
	_record(
		"Application-pause notification clears touch state",
		int(_mobile_controls.get("joystick_touch_id")) == -1 and paused_movement == Vector2.ZERO,
		"This exercises the handler directly; actual app switching remains a device check."
	)


func _test_kole_impacts() -> void:
	var cracked_screen := _kole.get_node_or_null("CrackedScreen") as Node3D
	if cracked_screen == null:
		_record("KOLE impact test setup", false, "CrackedScreen node was not found.")
		return

	_kole.freeze = false
	_kole.sleeping = false
	_kole.set("screen_cracked", false)
	_kole.set("_previous_velocity", Vector3.ZERO)
	cracked_screen.visible = false
	_kole.linear_velocity = Vector3.ZERO
	_kole.angular_velocity = Vector3.ZERO
	_kole.global_position = Vector3(2.0, 0.45, 2.7)
	await _wait_physics_frames(45)
	_record(
		"KOLE soft floor drop stays intact",
		not bool(_kole.get("screen_cracked")),
		""
	)

	_kole.global_position = Vector3(2.0, 2.0, 2.7)
	_kole.linear_velocity = Vector3.ZERO
	_kole.angular_velocity = Vector3.ZERO
	_kole.set("_previous_velocity", Vector3.ZERO)
	var hard_drop_cracked := await _wait_for_property_bool(
		_kole, "screen_cracked", true, MAX_TRANSITION_FRAMES
	)
	_record(
		"KOLE hard floor impact cracks on contact",
		hard_drop_cracked and cracked_screen.visible,
		""
	)

	_kole.set("screen_cracked", false)
	_kole.set("_previous_velocity", Vector3.ZERO)
	cracked_screen.visible = false
	_kole.freeze = false
	_kole.sleeping = false
	_kole.linear_velocity = Vector3.ZERO
	_kole.angular_velocity = Vector3.ZERO
	_kole.global_position = _stretcher.to_global(Vector3(0.0, 2.0, 0.0))
	var secured_on_pad := await _wait_for_property_bool(
		_kole, "is_stuck", true, MAX_TRANSITION_FRAMES
	)
	_record(
		"KOLE pad landing is cushioned and secures it",
		secured_on_pad and not bool(_kole.get("screen_cracked")),
		""
	)


func _test_stretcher_patient_and_pad() -> void:
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO
	var grabbed := bool(_stretcher.call("grab", _player))
	_record("Stretcher grab succeeds", grabbed, "")
	if not grabbed:
		return
	_interactor.set("grabbed_stretcher", _stretcher)

	var entry_started := bool(_player.get("_camera_transitioning"))
	var yaw_before_transition_look := float(_player.get("_stretcher_camera_yaw"))
	_player.call("apply_look", Vector2(0.2, 0.1))
	_record(
		"LOOK is ignored during camera entry tween",
		entry_started and is_equal_approx(float(_player.get("_stretcher_camera_yaw")), yaw_before_transition_look),
		""
	)
	var entry_finished := await _wait_for_property_bool(
		_player, "_camera_transitioning", false, MAX_TRANSITION_FRAMES
	)
	_player.call("apply_look", Vector2(0.2, 0.0))
	_record(
		"Camera entry completes and orbit responds",
		entry_finished and not is_equal_approx(float(_player.get("_stretcher_camera_yaw")), yaw_before_transition_look),
		""
	)

	var operator_offset: Vector3 = _stretcher.get("operator_offset")
	var operator_forward: Vector3 = _stretcher.get("operator_forward_local")
	var player_forward_local := _stretcher.global_basis.inverse() * (-_player.global_basis.z)
	_record(
		"Operator facing aligns to selected handle",
		player_forward_local.is_equal_approx(operator_forward)
			and operator_forward.is_equal_approx(Vector3(-operator_offset.x, 0.0, -operator_offset.z).normalized()),
		""
	)

	_player.call("set_movement_input", Vector2(1.0, 0.0))
	await _wait_physics_frames(2)
	var swing_rate := _stretcher.angular_velocity.y
	var sideways_speed := _stretcher.linear_velocity.x
	_record(
		"Free end swings and slides from end operation",
		swing_rate > 0.01 and sideways_speed > 0.05,
		"Yaw %.3f rad/s; sideways speed %.2f m/s." % [swing_rate, sideways_speed]
	)
	_player.call("set_movement_input", Vector2.ZERO)
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO

	await get_tree().process_frame
	var height_button := _mobile_controls.get_node_or_null("StretcherHeightButton") as Button
	_record(
		"LOWER control appears with correct action label",
		height_button != null
			and height_button.visible
			and not height_button.disabled
			and height_button.text == "LOWER",
		""
	)

	var original_bag_mask := _bag.collision_mask
	_bag.freeze = true
	_bag.linear_velocity = Vector3.ZERO
	_bag.angular_velocity = Vector3.ZERO
	_bag.global_transform = _stretcher.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, -0.5))
	await _wait_physics_frames(8)
	_record(
		"Bag above the pad does not stick (touch only)",
		not bool(_bag.get("is_stuck")),
		"Held still 0.35 m above the pad."
	)
	# 0.8 m wide bag centered at x 0.75: overhangs the 0.5 m edge but its base touches the pad.
	_bag.global_transform = _stretcher.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.75, 1.06, -0.5))
	_bag.freeze = false
	_bag.sleeping = false
	await _wait_physics_frames(20)
	var bag_stuck: bool = bool(_bag.get("is_stuck")) and _bag.get("stuck_to") == _stretcher
	var bag_local_position := _stretcher.to_local(_bag.global_position)
	_record(
		"Pad sensor secures an overhanging bag that touches it",
		bag_stuck and bag_local_position.x > 0.5,
		"Local x %.2f." % bag_local_position.x
	)
	var bag_y_before_lower := bag_local_position.y

	_patient.global_position = _stretcher.to_global(Vector3(1.0, 0.0, 0.0))
	_patient.global_rotation = Vector3(0.0, _stretcher.global_rotation.y, 0.0)
	_patient.linear_velocity = Vector3.ZERO
	_patient.angular_velocity = Vector3.ZERO
	var patient_not_assessed := not bool(_patient.call("can_load_onto", _stretcher))
	_patient.call("assess_patient")
	var patient_cannot_load_high := not bool(_patient.call("can_load_onto", _stretcher))
	_record(
		"Patient load is gated by assessment and low deck",
		patient_not_assessed and patient_cannot_load_high,
		"The placeholder assessment contains no clinical data."
	)

	_stretcher.linear_velocity = Vector3(0.5, 0.0, 0.0)
	var height_blocked_while_moving := not bool(_stretcher.call("can_change_height"))
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO
	_record(
		"Height transition is blocked while moving",
		height_blocked_while_moving,
		""
	)
	if height_button != null and not height_button.disabled:
		height_button.emit_signal("pressed")
	else:
		_interactor.call("request_height_toggle")
	await get_tree().physics_frame
	var lowered := await _wait_for_method_bool(
		_stretcher, "is_lowered_for_loading", true, MAX_TRANSITION_FRAMES
	)
	await get_tree().process_frame
	height_button = _mobile_controls.get_node_or_null("StretcherHeightButton") as Button
	_record(
		"Height action label changes to RAISE",
		height_button != null and height_button.visible and height_button.text == "RAISE",
		""
	)
	var pad_top := float(_stretcher.call("get_pad_top_local_y"))
	_record(
		"LOWER completes and pad height follows",
		lowered and absf(pad_top - 0.6) < 0.02,
		"Expected deck/pad top near 0.60 m."
	)

	if bag_stuck:
		var bag_y_lowered := _stretcher.to_local(_bag.global_position).y
		_record(
			"Secured bag follows deck lowering",
			absf(bag_y_lowered - (bag_y_before_lower - 0.22)) < 0.03,
			""
		)
	else:
		_record("Secured bag follows deck lowering", false, "Skipped because the pad did not secure the bag.")

	var patient_can_load := bool(_patient.call("can_load_onto", _stretcher))
	_record(
		"Assessment, lowered deck and alignment permit TRANSFER",
		lowered and patient_can_load,
		"Hint: '%s'." % str(_patient.call("get_transfer_hint", _stretcher))
	)
	var hold_point := _player.get_node_or_null("Camera3D/HoldPoint") as Node3D
	if hold_point != null:
		_patient.call("pick_up", hold_point.global_transform)
	_record("Patient can never be picked up or carried", not bool(_patient.get("is_held")), "")

	var aligned_rotation := _patient.global_rotation
	_patient.global_rotation = aligned_rotation + Vector3(0.0, PI * 0.5, 0.0)
	_record(
		"Crossways patient asks to line up the stretcher",
		str(_patient.call("get_transfer_hint", _stretcher)) == "LINE UP STRETCHER",
		""
	)
	_patient.global_rotation = aligned_rotation

	var mass_before := _stretcher.mass
	var transfer_started := bool(_patient.call("load_onto_stretcher", _stretcher))
	await _wait_physics_frames(40)
	var deck := _stretcher.get_node_or_null("DeckAssembly") as Node3D
	var patient_loaded := (
		transfer_started
		and bool(_patient.get("is_loaded"))
		and deck != null
		and _patient.get_parent() == deck
	)
	_record(
		"TRANSFER slides the patient onto the deck",
		patient_loaded,
		""
	)
	_record(
		"Loaded patient adds weight to the stretcher",
		patient_loaded and _stretcher.mass > mass_before,
		"Mass %.1f -> %.1f kg." % [mass_before, _stretcher.mass]
	)
	await get_tree().process_frame
	await get_tree().process_frame
	var status_label := _mobile_controls.get_node_or_null("StatusPanel/StatusText") as Label
	_record(
		"Mobile status reports loaded state",
		status_label != null and status_label.text.contains("PATIENT LOADED"),
		""
	)
	var patient_y_before_raise := _patient.global_position.y

	await get_tree().process_frame
	height_button = _mobile_controls.get_node_or_null("StretcherHeightButton") as Button
	if height_button != null and not height_button.disabled:
		height_button.emit_signal("pressed")
	else:
		_interactor.call("request_height_toggle")
	await get_tree().physics_frame
	var raised := await _wait_for_property_bool(
		_stretcher, "is_lowered", false, MAX_TRANSITION_FRAMES
	)
	await _wait_physics_frames(2)
	var patient_y_after_raise := _patient.global_position.y
	_record(
		"RAISE carries loaded patient",
		raised and patient_loaded and absf((patient_y_after_raise - patient_y_before_raise) - 0.22) < 0.04,
		""
	)
	if bag_stuck:
		var bag_y_raised := _stretcher.to_local(_bag.global_position).y
		_record(
			"Secured bag follows deck raising",
			absf(bag_y_raised - bag_y_before_lower) < 0.03,
			""
		)

	if hold_point != null:
		_bag.call("pick_up", hold_point.global_transform)
		_bag.call("release", hold_point.global_transform, Vector3.ZERO)
		_record(
			"Picking up secured bag restores collision mask",
			not bool(_bag.get("is_stuck")) and _bag.collision_mask == original_bag_mask,
			""
		)
	else:
		_record("Picking up secured bag restores collision mask", false, "HoldPoint was not found.")

	_stretcher.call("release", _player)
	_interactor.set("grabbed_stretcher", null)
	var exit_started := bool(_player.get("_camera_transitioning"))
	var saved_walk_pose := bool(_player.get("_walk_camera_saved"))
	var regrabbed := bool(_stretcher.call("grab", _player))
	if regrabbed:
		_interactor.set("grabbed_stretcher", _stretcher)
	var walk_pose_preserved := bool(_player.get("_walk_camera_saved"))
	var regrab_transition_finished := await _wait_for_property_bool(
		_player, "_camera_transitioning", false, MAX_TRANSITION_FRAMES
	)
	_record(
		"Quick camera re-grab preserves walk pose",
		exit_started and saved_walk_pose and regrabbed and walk_pose_preserved and regrab_transition_finished,
		""
	)
	_stretcher.call("release", _player)
	_interactor.set("grabbed_stretcher", null)
	await _wait_for_property_bool(_player, "_camera_transitioning", false, MAX_TRANSITION_FRAMES)


func _test_stretcher_collision_shapes() -> void:
	# Godot ignores a CollisionShape3D unless its direct parent is a physics body or area.
	var orphans: Array[String] = []
	var pending: Array[Node] = [_stretcher]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if child is CollisionShape3D and not (child.get_parent() is CollisionObject3D):
				orphans.append(str(_stretcher.get_path_to(child)))
	_record(
		"Stretcher collision shapes are all active",
		orphans.is_empty(),
		("Inactive: " + ", ".join(orphans)) if not orphans.is_empty() else ""
	)

	await _wait_physics_frames(2)
	var deck_center := _stretcher.to_global(Vector3(0.0, 0.73, 0.0))
	var query := PhysicsRayQueryParameters3D.create(
		deck_center + Vector3.UP * 1.5,
		deck_center + Vector3.DOWN * 0.5
	)
	var hit := _stretcher.get_world_3d().direct_space_state.intersect_ray(query)
	# Without the deck collider the ray would still hit the low floor support, so check height.
	var hit_local_y := -INF
	if not hit.is_empty():
		hit_local_y = _stretcher.to_local(hit.get("position")).y
	_record(
		"Ray at the deck hits the deck top",
		not hit.is_empty() and hit.get("collider") == _stretcher and hit_local_y > 0.6,
		"Local hit height %.2f m." % hit_local_y
	)


func _test_bumps_with_caster_locks() -> void:
	for front_locked in [false, true]:
		for rear_locked in [false, true]:
			_set_lock_state(front_locked, rear_locked)
			_stretcher.linear_velocity = Vector3.ZERO
			_stretcher.angular_velocity = Vector3.ZERO
			var contact := _stretcher.global_position + Vector3(0.0, 0.0, -0.8)
			_stretcher.call(
				"apply_character_bump",
				Vector3(0.0, 0.0, -4.0),
				Vector3(0.0, 0.0, 1.0),
				contact
			)
			await _wait_physics_frames(2)
			var forward_speed := _stretcher.linear_velocity.dot(Vector3(0.0, 0.0, -1.0))
			_record(
				"Longitudinal bump moves stretcher (front %s, rear %s)" % [front_locked, rear_locked],
				forward_speed > 0.05,
				"Forward speed %.2f m/s." % forward_speed
			)
			await _wait_physics_frames(20)

	_set_lock_state(true, false)
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO
	var side_contact := _stretcher.global_position + Vector3(0.0, 0.0, 0.8)
	_stretcher.call(
		"apply_character_bump",
		Vector3(4.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		side_contact
	)
	await _wait_physics_frames(2)
	_record(
		"Side bump can swing free end with one axle locked",
		absf(_stretcher.angular_velocity.y) > 0.001,
		"Yaw rate %.3f rad/s." % _stretcher.angular_velocity.y
	)
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO
	_set_lock_state(false, false)
	await _wait_physics_frames(20)


func _test_push_button() -> void:
	_stretcher.linear_velocity = Vector3.ZERO
	_stretcher.angular_velocity = Vector3.ZERO
	_set_lock_state(false, false)
	var grabbed := bool(_stretcher.call("grab", _player))
	if grabbed:
		_interactor.set("grabbed_stretcher", _stretcher)
	await get_tree().process_frame
	await get_tree().process_frame
	var push_button := _mobile_controls.get_node_or_null("PushButton") as Button
	var button_ready := (
		grabbed
		and push_button != null
		and push_button.visible
		and not push_button.disabled
		and push_button.text == "PUSH"
	)
	_record("PUSH button is available when aligned", button_ready, "")
	if button_ready:
		push_button.emit_signal("pressed")
		await _wait_physics_frames(2)
		var released := not bool(_interactor.call("is_stretcher_grabbed"))
		var speed := Vector2(_stretcher.linear_velocity.x, _stretcher.linear_velocity.z).length()
		_record(
			"PUSH releases and moves stretcher",
			released and speed > 0.2,
			"Horizontal speed %.2f m/s." % speed
		)
	else:
		if grabbed:
			_stretcher.call("release", _player)
			await get_tree().physics_frame


func _set_lock_state(front_locked: bool, rear_locked: bool) -> void:
	if bool(_stretcher.get("front_casters_locked")) != front_locked:
		_stretcher.call("toggle_front_caster_lock")
	if bool(_stretcher.get("rear_casters_locked")) != rear_locked:
		_stretcher.call("toggle_rear_caster_lock")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await get_tree().physics_frame


func _wait_for_method_bool(
	target: Object,
	method_name: String,
	expected: bool,
	max_frames: int
) -> bool:
	for _frame_index in range(max_frames):
		await get_tree().physics_frame
		if bool(target.call(method_name)) == expected:
			return true
	return false


func _wait_for_property_bool(
	target: Object,
	property_name: String,
	expected: bool,
	max_frames: int
) -> bool:
	for _frame_index in range(max_frames):
		await get_tree().process_frame
		if bool(target.get(property_name)) == expected:
			return true
	return false


func _record(test_name: String, passed: bool, details: String) -> void:
	var state := "PASS" if passed else "FAIL"
	var line := "%s: %s" % [state, test_name]
	if not details.is_empty():
		line += " — " + details
	_results.append(line)
	if passed:
		_passes += 1
	else:
		_failures += 1
	print("[QA] " + line)
	_refresh_report()


func _refresh_report() -> void:
	if not is_instance_valid(_results_label):
		return
	_results_label.text = "\n".join(_results)
	_summary_label.text = "Running…  %d passed, %d failed" % [_passes, _failures]


func _finish_suite() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null
	await get_tree().process_frame
	_running = false
	_run_button.disabled = false
	_refresh_report()
	_summary_label.text = "Finished: %d passed, %d failed" % [_passes, _failures]
	_save_report()


func _save_report() -> void:
	var report := "Paramedic Simulator QA Runner\n"
	report += "Result: %d passed, %d failed\n\n" % [_passes, _failures]
	report += "\n".join(_results)
	var file := FileAccess.open("user://qa_runner_latest.txt", FileAccess.WRITE)
	if file == null:
		_summary_label.text += " (Could not save user://qa_runner_latest.txt)"
		return
	file.store_string(report)


func _on_run_again_pressed() -> void:
	if not _running:
		await _run_suite()
