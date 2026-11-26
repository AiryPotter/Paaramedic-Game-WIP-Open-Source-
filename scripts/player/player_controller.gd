extends CharacterBody3D
class_name PlayerController

## Touch input is supplied by the mobile controls UI through these methods.

@export var move_speed: float = 4.0
@export var ground_acceleration: float = 18.0
@export var gravity: float = 18.0
@export_range(-1.5, -0.2, 0.05) var minimum_look_pitch: float = -1.2
@export_range(0.2, 1.5, 0.05) var maximum_look_pitch: float = 1.2

var movement_input: Vector2 = Vector2.ZERO
var look_movement_input: Vector2 = Vector2.ZERO
var grabbed_stretcher: RigidBody3D
var _camera_tween: Tween
var _camera_transitioning: bool = false
var _walk_camera_saved: bool = false
var _walk_camera_position: Vector3
var _walk_camera_rotation: Vector3
var _walk_camera_fov: float
var _stretcher_camera_yaw: float = 0.0
var _stretcher_camera_pitch: float = -0.36
var _stretcher_facing_yaw_offset: float = 0.0

const STRETCHER_CAMERA_RADIUS: float = 4.5
const STRETCHER_CAMERA_TARGET_HEIGHT: float = 1.0
const MOVEMENT_DEADZONE: float = 0.12
@onready var player_camera: Camera3D = $Camera3D


func _ready() -> void:
	_walk_camera_position = player_camera.position
	_walk_camera_rotation = player_camera.rotation
	_walk_camera_fov = player_camera.fov


func set_movement_input(input_vector: Vector2) -> void:
	movement_input = _apply_movement_deadzone(input_vector)


func set_look_movement_input(input_vector: Vector2) -> void:
	look_movement_input = _apply_movement_deadzone(input_vector)


func _apply_movement_deadzone(input_vector: Vector2) -> Vector2:
	var limited_input := input_vector.limit_length(1.0)
	var input_strength := limited_input.length()
	if input_strength <= MOVEMENT_DEADZONE:
		return Vector2.ZERO
	var adjusted_strength := (input_strength - MOVEMENT_DEADZONE) / (1.0 - MOVEMENT_DEADZONE)
	return limited_input.normalized() * adjusted_strength


func _combined_movement_input() -> Vector2:
	return (movement_input + look_movement_input).limit_length(1.0)


func apply_look(look_delta: Vector2) -> void:
	if _camera_transitioning:
		return
	if is_instance_valid(grabbed_stretcher):
		_stretcher_camera_yaw = wrapf(_stretcher_camera_yaw - look_delta.x, -PI, PI)
		_stretcher_camera_pitch = clampf(_stretcher_camera_pitch - look_delta.y, -0.75, -0.12)
		_update_stretcher_camera_orbit()
		return
	rotation.y -= look_delta.x
	player_camera.rotation.x = clampf(
		player_camera.rotation.x - look_delta.y,
		minimum_look_pitch,
		maximum_look_pitch
	)


func enter_stretcher_mode(stretcher: RigidBody3D, facing_yaw_offset: float = 0.0) -> void:
	if not _walk_camera_saved:
		_walk_camera_position = player_camera.position
		_walk_camera_rotation = player_camera.rotation
		_walk_camera_fov = player_camera.fov
		_walk_camera_saved = true
	grabbed_stretcher = stretcher
	look_movement_input = Vector2.ZERO
	_stretcher_camera_yaw = 0.0
	_stretcher_camera_pitch = -0.36
	_stretcher_facing_yaw_offset = facing_yaw_offset
	rotation.y = stretcher.rotation.y + _stretcher_facing_yaw_offset
	_transition_camera(
		_stretcher_camera_local_position(),
		Vector3(_stretcher_camera_pitch, _stretcher_camera_yaw, 0.0),
		78.0
	)


func exit_stretcher_mode() -> void:
	grabbed_stretcher = null
	movement_input = Vector2.ZERO
	look_movement_input = Vector2.ZERO
	_stretcher_facing_yaw_offset = 0.0
	_transition_camera(_walk_camera_position, _walk_camera_rotation, _walk_camera_fov)


func _stretcher_camera_local_position() -> Vector3:
	var elevation := -_stretcher_camera_pitch
	var horizontal_radius := STRETCHER_CAMERA_RADIUS * cos(elevation)
	return Vector3(
		sin(_stretcher_camera_yaw) * horizontal_radius,
		STRETCHER_CAMERA_TARGET_HEIGHT + STRETCHER_CAMERA_RADIUS * sin(elevation),
		cos(_stretcher_camera_yaw) * horizontal_radius
	)


func _update_stretcher_camera_orbit() -> void:
	player_camera.position = _stretcher_camera_local_position()
	player_camera.rotation = Vector3(_stretcher_camera_pitch, _stretcher_camera_yaw, 0.0)


func _transition_camera(target_position: Vector3, target_rotation: Vector3, target_fov: float) -> void:
	if is_instance_valid(_camera_tween) and _camera_tween.is_running():
		_camera_tween.kill()
	var shortest_rotation := target_rotation
	shortest_rotation.y = player_camera.rotation.y + wrapf(
		target_rotation.y - player_camera.rotation.y,
		-PI,
		PI
	)
	_camera_transitioning = true
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(player_camera, "position", target_position, 0.65)
	_camera_tween.tween_property(player_camera, "rotation", shortest_rotation, 0.65)
	_camera_tween.tween_property(player_camera, "fov", target_fov, 0.65)
	_camera_tween.finished.connect(_on_camera_transition_finished)


func _on_camera_transition_finished() -> void:
	_camera_transitioning = false
	if is_instance_valid(grabbed_stretcher):
		_update_stretcher_camera_orbit()
	else:
		_walk_camera_saved = false


func _apply_stretcher_bump_impulses(impact_velocity: Vector3) -> void:
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider()
		if collider is RigidBody3D and collider.is_in_group("grabbable_stretcher"):
			collider.call(
				"apply_character_bump",
				impact_velocity,
				collision.get_normal(),
				collision.get_position()
			)


func _physics_process(delta: float) -> void:
	if is_instance_valid(grabbed_stretcher):
		rotation.y = grabbed_stretcher.rotation.y + _stretcher_facing_yaw_offset
		var target_position: Vector3 = grabbed_stretcher.call("get_operator_position")
		var follow_velocity := (target_position - global_position) / maxf(delta, 0.001)
		velocity = Vector3(follow_velocity.x, 0.0, follow_velocity.z)
		grabbed_stretcher.call("set_operator_input", _combined_movement_input())
		move_and_slide()
		return

	var current_movement := _combined_movement_input()
	var local_direction := Vector3(current_movement.x, 0.0, current_movement.y)
	var world_direction := global_basis * local_direction
	world_direction.y = 0.0
	var target_velocity := world_direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, ground_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ground_acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var impact_velocity := velocity
	move_and_slide()
	_apply_stretcher_bump_impulses(impact_velocity)
