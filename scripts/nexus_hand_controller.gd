extends XRController3D

## Attach this same script to LeftController and RightController.
## Set is_left_hand=true on the left and false on the right.

@export var is_left_hand: bool = true
@export_range(0.5, 10.0, 0.1) var laser_length: float = 5.0
@export var show_laser: bool = true

var hand_root: Node3D
var ray: RayCast3D
var laser: MeshInstance3D
var laser_dot: MeshInstance3D
var finger_joints: Array[Array] = []
var thumb_joints: Array[Node3D] = []
var hand_material: StandardMaterial3D
var laser_material: StandardMaterial3D
var trigger_was_pressed := false
var index_finger_index := 3

# Desktop mouse input is supplied by main.gd when no headset is connected.
var desktop_trigger_value: float = 0.0
var desktop_grip_value: float = 0.0


func _ready() -> void:
	tracker = &"left_hand" if is_left_hand else &"right_hand"
	pose = &"aim"
	_create_materials()
	_create_hand()
	_create_laser()


func _create_materials() -> void:
	hand_material = StandardMaterial3D.new()
	hand_material.albedo_color = Color(0.58, 0.82, 0.96, 0.24)
	hand_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hand_material.roughness = 0.22
	hand_material.metallic = 0.0
	hand_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hand_material.emission_enabled = true
	hand_material.emission = Color(0.025, 0.09, 0.16)
	hand_material.emission_energy_multiplier = 0.08

	laser_material = StandardMaterial3D.new()
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.albedo_color = Color(0.18, 0.82, 1.0)
	laser_material.emission_enabled = true
	laser_material.emission = Color(0.10, 0.70, 1.0)
	laser_material.emission_energy_multiplier = 2.5


func _create_hand() -> void:
	hand_root = Node3D.new()
	hand_root.name = "NEXUS_Hand_Model"
	hand_root.position = Vector3(0.0, -0.012, -0.045)
	hand_root.scale = Vector3.ONE * 0.88
	add_child(hand_root)

	var thumb_side := -1.0 if is_left_hand else 1.0
	_add_ellipsoid("Palm", Vector3(0.040, 0.013, 0.052), Vector3(0, 0, -0.025))
	_add_ellipsoid("Wrist", Vector3(0.025, 0.010, 0.030), Vector3(0, 0, 0.035))
	# Soft thumb mound gives the palm a more natural silhouette.
	_add_ellipsoid("Thumb_Palm_Mound", Vector3(0.018, 0.010, 0.027), Vector3(thumb_side * 0.027, 0.0, -0.006))

	# Four fingers are ordered from the little-finger edge to the index edge.
	var x_positions: Array[float] = [-0.029, -0.010, 0.010, 0.029]
	var lengths: Array[float] = [0.061, 0.071, 0.077, 0.069]
	var widths: Array[float] = [0.0050, 0.0055, 0.0058, 0.0052]

	for i in range(4):
		var finger := Node3D.new()
		finger.name = "Finger_%d" % i
		finger.position = Vector3(x_positions[i] * thumb_side, 0.0, -0.067)
		hand_root.add_child(finger)

		var joints: Array[Node3D] = []
		var parent: Node3D = finger
		var total := lengths[i]
		var parts: Array[float] = [total * 0.43, total * 0.32, total * 0.25]

		for j in range(3):
			var pivot := Node3D.new()
			pivot.name = "Joint_%d" % j
			parent.add_child(pivot)
			joints.append(pivot)
			_add_finger_piece(pivot, parts[j], widths[i] * (1.0 - 0.10 * j))
			var next_pivot := Node3D.new()
			next_pivot.position.z = -parts[j]
			pivot.add_child(next_pivot)
			parent = next_pivot

		finger_joints.append(joints)

	# Thumb grows diagonally from the side of the palm and moves independently.
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(thumb_side * 0.038, 0.0, -0.012)
	thumb.rotation.y = -thumb_side * 0.72
	thumb.rotation.x = -0.18
	hand_root.add_child(thumb)

	var thumb_parent: Node3D = thumb
	for j in range(2):
		var pivot := Node3D.new()
		pivot.name = "ThumbJoint_%d" % j
		thumb_parent.add_child(pivot)
		thumb_joints.append(pivot)
		var part_length := 0.038 if j == 0 else 0.030
		_add_finger_piece(pivot, part_length, 0.0060 - float(j) * 0.0006)
		var next_pivot := Node3D.new()
		next_pivot.position.z = -part_length
		pivot.add_child(next_pivot)
		thumb_parent = next_pivot


func _add_ellipsoid(label: String, dimensions: Vector3, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 20
	mesh_instance.mesh = sphere
	mesh_instance.scale = dimensions
	mesh_instance.position = position
	mesh_instance.material_override = hand_material
	hand_root.add_child(mesh_instance)


func _add_finger_piece(parent: Node3D, length: float, radius: float) -> void:
	# Rounded capsule segments overlap slightly, avoiding the robotic
	# disconnected-cylinder appearance while keeping the same hand scale.
	var segment := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length + radius * 1.8
	capsule.radial_segments = 20
	capsule.rings = 8
	segment.mesh = capsule
	segment.rotation.x = PI / 2.0
	segment.position.z = -length * 0.5
	segment.material_override = hand_material
	parent.add_child(segment)

	# Small, soft knuckle blend at the end of each segment.
	var knuckle := MeshInstance3D.new()
	var knuckle_mesh := SphereMesh.new()
	knuckle_mesh.radius = radius * 0.92
	knuckle_mesh.height = radius * 1.84
	knuckle_mesh.radial_segments = 20
	knuckle_mesh.rings = 12
	knuckle.mesh = knuckle_mesh
	knuckle.position.z = -length
	knuckle.material_override = hand_material
	parent.add_child(knuckle)

func _create_laser() -> void:
	ray = RayCast3D.new()
	ray.name = "NEXUS_Interaction_Ray"
	ray.position = Vector3(0, 0, -0.075)
	ray.target_position = Vector3(0, 0, -laser_length)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = 1
	add_child(ray)

	var beam := CylinderMesh.new()
	beam.top_radius = 0.0010
	beam.bottom_radius = 0.0018
	beam.height = 1.0
	beam.radial_segments = 10
	laser = MeshInstance3D.new()
	laser.name = "NEXUS_Laser_Beam"
	laser.mesh = beam
	laser.rotation.x = PI / 2.0
	laser.material_override = laser_material
	add_child(laser)

	var dot := SphereMesh.new()
	dot.radius = 0.006
	dot.height = 0.012
	dot.radial_segments = 16
	dot.rings = 10
	laser_dot = MeshInstance3D.new()
	laser_dot.name = "NEXUS_Laser_Dot"
	laser_dot.mesh = dot
	laser_dot.material_override = laser_material
	add_child(laser_dot)


func _process(_delta: float) -> void:
	if not is_instance_valid(hand_root):
		return

	var grip_value := maxf(desktop_grip_value, maxf(get_float("grip"), 1.0 if is_button_pressed("grip_click") else 0.0))
	var trigger_value := maxf(desktop_trigger_value, maxf(get_float("trigger"), 1.0 if is_button_pressed("trigger_click") else 0.0))
	_animate_fingers(grip_value, trigger_value)

	ray.target_position = Vector3(0, 0, -laser_length)
	ray.force_raycast_update()
	var distance := laser_length
	if ray.is_colliding():
		distance = ray.to_global(Vector3.ZERO).distance_to(ray.get_collision_point())
	distance = clampf(distance, 0.04, laser_length)

	laser.visible = show_laser
	laser_dot.visible = show_laser
	laser.position = Vector3(0, 0, -0.075 - distance * 0.5)
	laser.scale = Vector3(1.0, distance, 1.0)
	if ray.is_colliding():
		laser_dot.global_position = ray.get_collision_point()
	else:
		laser_dot.global_position = ray.to_global(Vector3(0, 0, -laser_length))

	if trigger_value > 0.75 and not trigger_was_pressed:
		_interact_with_target()
	trigger_was_pressed = trigger_value > 0.75


func _animate_fingers(grip: float, trigger: float) -> void:
	var grip_amount := clampf(grip, 0.0, 1.0)
	var trigger_amount := clampf(trigger, 0.0, 1.0)
	index_finger_index = 3

	for i in range(finger_joints.size()):
		var curl := 0.55
		if i == index_finger_index:
			curl = 0.0
		else:
			curl = 0.72 - float(abs(i - index_finger_index)) * 0.07
		curl = lerpf(curl, 1.18, grip_amount)
		if i == index_finger_index:
			curl = lerpf(curl, 1.12, trigger_amount)
		var joints: Array[Node3D] = finger_joints[i]
		for j in range(joints.size()):
			var weight := 1.0 if j == 0 else (0.82 if j == 1 else 0.66)
			joints[j].rotation.x = -curl * weight

	var thumb_curl := grip_amount * 0.95
	for j in range(thumb_joints.size()):
		thumb_joints[j].rotation.x = -thumb_curl * (0.85 if j == 0 else 0.65)


func _interact_with_target() -> void:
	if not ray.is_colliding():
		return
	var target := ray.get_collider()
	if target == null:
		return
	if target.has_method("interact_at"):
		target.call("interact_at", ray.get_collision_point())
	elif target.has_method("interact"):
		target.call("interact")
