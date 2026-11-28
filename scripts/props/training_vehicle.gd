@tool
extends StaticBody3D
class_name TrainingVehicleProp

@export_enum("car", "pickup_truck") var vehicle_style: String = "car"


func _ready() -> void:
	_build_vehicle()


func _build_vehicle() -> void:
	if vehicle_style == "pickup_truck":
		_build_pickup_truck()
	else:
		_build_car()


func _build_car() -> void:
	var paint := Color(0.06, 0.38, 0.78, 1.0)
	var glass := Color(0.12, 0.25, 0.32, 1.0)
	var dark := Color(0.08, 0.1, 0.12, 1.0)
	var chrome := Color(0.58, 0.64, 0.66, 1.0)

	_add_box("LowerBody", Vector3(1.95, 0.55, 3.6), Vector3(0.0, 0.67, 0.0), paint)
	_add_box("Hood", Vector3(1.84, 0.28, 1.1), Vector3(0.0, 0.98, -1.12), paint)
	_add_box("Trunk", Vector3(1.84, 0.28, 0.72), Vector3(0.0, 0.98, 1.38), paint)
	_add_box("Cabin", Vector3(1.5, 0.78, 1.62), Vector3(0.0, 1.28, 0.05), paint)
	_add_box("Roof", Vector3(1.5, 0.12, 1.14), Vector3(0.0, 1.72, 0.05), paint)
	_add_box("Windshield", Vector3(1.36, 0.43, 0.055), Vector3(0.0, 1.36, -0.78), glass, Vector3(-0.32, 0.0, 0.0))
	_add_box("RearWindow", Vector3(1.34, 0.4, 0.055), Vector3(0.0, 1.36, 0.88), glass, Vector3(0.32, 0.0, 0.0))
	_add_box("LeftWindow", Vector3(0.055, 0.42, 0.78), Vector3(-0.76, 1.36, 0.05), glass)
	_add_box("RightWindow", Vector3(0.055, 0.42, 0.78), Vector3(0.76, 1.36, 0.05), glass)
	_add_box("FrontBumper", Vector3(1.95, 0.16, 0.14), Vector3(0.0, 0.4, -1.84), dark)
	_add_box("RearBumper", Vector3(1.95, 0.16, 0.14), Vector3(0.0, 0.4, 1.84), dark)
	_add_box("FrontGrille", Vector3(0.72, 0.23, 0.06), Vector3(0.0, 0.72, -1.84), dark)
	_add_box("HeadlightLeft", Vector3(0.3, 0.17, 0.07), Vector3(-0.68, 0.83, -1.84), Color(1.0, 0.88, 0.56, 1.0))
	_add_box("HeadlightRight", Vector3(0.3, 0.17, 0.07), Vector3(0.68, 0.83, -1.84), Color(1.0, 0.88, 0.56, 1.0))
	_add_box("TailLightLeft", Vector3(0.25, 0.2, 0.07), Vector3(-0.7, 0.82, 1.84), Color(0.82, 0.08, 0.05, 1.0))
	_add_box("TailLightRight", Vector3(0.25, 0.2, 0.07), Vector3(0.7, 0.82, 1.84), Color(0.82, 0.08, 0.05, 1.0))
	_add_wheels(1.0, 1.08, 1.08, chrome)

	_add_collision_box("BodyCollision", Vector3(1.98, 0.78, 3.7), Vector3(0.0, 0.68, 0.0))
	_add_collision_box("CabinCollision", Vector3(1.52, 0.8, 1.65), Vector3(0.0, 1.27, 0.05))


func _build_pickup_truck() -> void:
	var paint := Color(0.82, 0.16, 0.08, 1.0)
	var glass := Color(0.12, 0.24, 0.3, 1.0)
	var dark := Color(0.08, 0.1, 0.12, 1.0)
	var chrome := Color(0.58, 0.64, 0.66, 1.0)

	_add_box("LowerBody", Vector3(2.0, 0.56, 4.2), Vector3(0.0, 0.66, 0.0), paint)
	_add_box("Hood", Vector3(1.9, 0.3, 1.15), Vector3(0.0, 0.98, -1.42), paint)
	_add_box("Cab", Vector3(1.68, 0.92, 1.55), Vector3(0.0, 1.32, -0.62), paint)
	_add_box("CabRoof", Vector3(1.68, 0.13, 1.25), Vector3(0.0, 1.84, -0.62), paint)
	_add_box("Windshield", Vector3(1.5, 0.46, 0.055), Vector3(0.0, 1.42, -1.4), glass, Vector3(-0.28, 0.0, 0.0))
	_add_box("RearWindow", Vector3(1.42, 0.4, 0.055), Vector3(0.0, 1.43, 0.17), glass)
	_add_box("LeftWindow", Vector3(0.055, 0.48, 0.66), Vector3(-0.85, 1.44, -0.62), glass)
	_add_box("RightWindow", Vector3(0.055, 0.48, 0.66), Vector3(0.85, 1.44, -0.62), glass)

	_add_box("BedFloor", Vector3(1.76, 0.12, 1.58), Vector3(0.0, 1.0, 1.25), paint)
	_add_box("BedRailLeft", Vector3(0.12, 0.38, 1.72), Vector3(-0.88, 1.22, 1.25), paint)
	_add_box("BedRailRight", Vector3(0.12, 0.38, 1.72), Vector3(0.88, 1.22, 1.25), paint)
	_add_box("Tailgate", Vector3(1.76, 0.38, 0.12), Vector3(0.0, 1.22, 2.05), paint)
	_add_box("FrontBumper", Vector3(2.08, 0.17, 0.14), Vector3(0.0, 0.4, -2.14), dark)
	_add_box("RearBumper", Vector3(2.08, 0.17, 0.14), Vector3(0.0, 0.4, 2.14), dark)
	_add_box("FrontGrille", Vector3(0.8, 0.25, 0.06), Vector3(0.0, 0.73, -2.14), dark)
	_add_box("HeadlightLeft", Vector3(0.3, 0.18, 0.07), Vector3(-0.72, 0.84, -2.14), Color(1.0, 0.88, 0.56, 1.0))
	_add_box("HeadlightRight", Vector3(0.3, 0.18, 0.07), Vector3(0.72, 0.84, -2.14), Color(1.0, 0.88, 0.56, 1.0))
	_add_box("TailLightLeft", Vector3(0.24, 0.22, 0.07), Vector3(-0.8, 0.84, 2.14), Color(0.9, 0.08, 0.04, 1.0))
	_add_box("TailLightRight", Vector3(0.24, 0.22, 0.07), Vector3(0.8, 0.84, 2.14), Color(0.9, 0.08, 0.04, 1.0))
	_add_wheels(1.05, 1.35, 1.35, chrome)

	_add_collision_box("BodyCollision", Vector3(2.05, 0.82, 4.25), Vector3(0.0, 0.68, 0.0))
	_add_collision_box("CabCollision", Vector3(1.7, 0.94, 1.58), Vector3(0.0, 1.32, -0.62))
	_add_collision_box("BedCollision", Vector3(1.76, 0.14, 1.58), Vector3(0.0, 1.0, 1.25))


func _add_wheels(side_offset: float, front_z: float, rear_z: float, hub_material_color: Color) -> void:
	for side in [-1.0, 1.0]:
		_add_wheel(side * side_offset, front_z, hub_material_color)
		_add_wheel(side * side_offset, -rear_z, hub_material_color)


func _add_wheel(x: float, z: float, hub_color: Color) -> void:
	_add_cylinder("Tire", 0.34, 0.2, Vector3(x, 0.36, z), Color(0.07, 0.08, 0.09, 1.0), true)
	_add_cylinder(
		"WheelHub",
		0.16,
		0.035,
		Vector3(x + signf(x) * 0.11, 0.36, z),
		hub_color,
		true
	)


func _add_box(
	part_name: String,
	box_size: Vector3,
	part_position: Vector3,
	color: Color,
	part_rotation: Vector3 = Vector3.ZERO
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _material(color)
	mesh_instance.position = part_position
	mesh_instance.rotation = part_rotation
	add_child(mesh_instance)


func _add_cylinder(
	part_name: String,
	radius: float,
	cylinder_height: float,
	part_position: Vector3,
	color: Color,
	rotate_to_axle: bool = false
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = cylinder_height
	cylinder_mesh.radial_segments = 12
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.material_override = _material(color)
	mesh_instance.position = part_position
	if rotate_to_axle:
		mesh_instance.rotation.z = PI * 0.5
	add_child(mesh_instance)


func _add_collision_box(shape_name: String, shape_size: Vector3, shape_position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = shape_name
	var box_shape := BoxShape3D.new()
	box_shape.size = shape_size
	collision.shape = box_shape
	collision.position = shape_position
	add_child(collision)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
