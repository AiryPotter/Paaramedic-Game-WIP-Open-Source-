@tool
extends StaticBody3D
class_name TrainingBystander

@export var shirt_color: Color = Color(0.18, 0.42, 0.58, 1.0)
@export var pants_color: Color = Color(0.16, 0.2, 0.25, 1.0)
@export var skin_color: Color = Color(0.68, 0.47, 0.34, 1.0)


func _ready() -> void:
	_add_body_collision()
	_add_torso()
	_add_head()
	_add_arms()
	_add_legs()


func _add_body_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "BystanderCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.82
	collision.shape = capsule
	collision.position.y = 0.91
	add_child(collision)


func _add_torso() -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 0.27
	torso.height = 0.98
	torso.radial_segments = 8
	_add_mesh("Shirt", torso, Vector3(0.0, 1.12, 0.0), shirt_color)


func _add_head() -> void:
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.radial_segments = 10
	head.rings = 6
	_add_mesh("Head", head, Vector3(0.0, 1.74, 0.0), skin_color)
	_add_box("Nose", Vector3(0.07, 0.08, 0.1), Vector3(0.0, 1.73, -0.19), skin_color.darkened(0.12))
	_add_sphere("EyeLeft", 0.025, Vector3(-0.07, 1.78, -0.18), Color(0.08, 0.07, 0.06, 1.0))
	_add_sphere("EyeRight", 0.025, Vector3(0.07, 1.78, -0.18), Color(0.08, 0.07, 0.06, 1.0))


func _add_arms() -> void:
	for side in [-1.0, 1.0]:
		_add_cylinder("Arm", 0.095, 0.76, Vector3(side * 0.36, 1.05, 0.0), skin_color)
		_add_sphere("Hand", 0.105, Vector3(side * 0.36, 0.64, 0.0), skin_color)


func _add_legs() -> void:
	for side in [-1.0, 1.0]:
		_add_cylinder("TrouserLeg", 0.13, 0.8, Vector3(side * 0.14, 0.4, 0.0), pants_color)
		_add_box("Shoe", Vector3(0.2, 0.11, 0.34), Vector3(side * 0.14, 0.07, -0.04), Color(0.08, 0.09, 0.1, 1.0))


func _add_mesh(mesh_name: String, mesh: Mesh, mesh_position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = _material(color)
	add_child(instance)


func _add_cylinder(mesh_name: String, radius: float, height: float, mesh_position: Vector3, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	_add_mesh(mesh_name, cylinder, mesh_position, color)


func _add_sphere(mesh_name: String, radius: float, mesh_position: Vector3, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_add_mesh(mesh_name, sphere, mesh_position, color)


func _add_box(mesh_name: String, box_size: Vector3, mesh_position: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	_add_mesh(mesh_name, box, mesh_position, color)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
