
extends Node3D
class_name NexusLuxuryOffice

# ============================================================
# NEXUS VR — COMPLETE SPATIAL OFFICE
# Godot 4.x
# Attach to LuxuryOffice Node3D.
# ============================================================

const GOLD := Color("#D5AD75")
const GOLD_LIGHT := Color("#F4D9A8")
const IVORY := Color("#F5F0E8")
const MUTED := Color("#B9B2A8")
const WALNUT := Color("#493326")

const PANEL_DEPTH := -1.35

var office_root: Node3D
var productivity_root: Node3D
var productivity_visible: bool = false

var task_list: VBoxContainer
var task_input: LineEdit
var notes_editor: TextEdit
var timer_label: Label

var keyboard_node: Node3D
var active_editor: Control

var timer_seconds: float = 1500.0
var timer_running: bool = false
var timer_last_second: int = -1

var task_data: Array[String] = []

# ============================================================
# PANEL COLLISION TARGET
# ============================================================

class NexusPanelTarget extends Area3D:

	var office: Node
	var panel_viewport: SubViewport
	var panel_size: Vector2 = Vector2.ONE

	func interact() -> void:
		if office == null or panel_viewport == null:
			return

		office._send_panel_click(
			panel_viewport,
			Vector2(panel_viewport.size) * 0.5
		)

	func interact_at(world_point: Vector3) -> void:
		if office == null or panel_viewport == null:
			return

		var local_point: Vector3 = to_local(world_point)

		var uv := Vector2(
			clampf(local_point.x / panel_size.x + 0.5, 0.0, 1.0),
			clampf(0.5 - local_point.y / panel_size.y, 0.0, 1.0)
		)

		var pixel_point: Vector2 = uv * Vector2(panel_viewport.size)

		office._send_panel_click(panel_viewport, pixel_point)


# ============================================================
# STARTUP
# ============================================================

func _ready() -> void:
	for child in get_children():
		if child.name == "NEXUS_GENERATED":
			child.free()

	office_root = Node3D.new()
	office_root.name = "NEXUS_GENERATED"
	add_child(office_root)

	var camera := get_tree().root.find_child(
		"XRCamera3D", true, false
	) as Camera3D

	if camera != null:
		var yaw: float = camera.global_rotation.y
		office_root.global_transform = Transform3D(
			Basis(Vector3.UP, yaw),
			camera.global_position
		)
	else:
		office_root.global_transform = global_transform

	_load_data()
	# Build a navigable 3D room rather than a single flat room image.
	_build_environment()
	_build_furniture()
	_build_lighting()
	productivity_root = Node3D.new()
	productivity_root.name = "NEXUS_PRODUCTIVITY_WORKSPACE"
	office_root.add_child(productivity_root)
	_build_productivity_panels()
	_build_virtual_keyboard()
	set_productivity_visible(false)


func set_productivity_visible(is_visible: bool) -> void:
	productivity_visible = is_visible
	if is_instance_valid(productivity_root):
		productivity_root.visible = is_visible


func _process(delta: float) -> void:
	if timer_running:
		timer_seconds = maxf(0.0, timer_seconds - delta)

		if timer_seconds <= 0.0:
			timer_running = false

	var displayed: int = int(ceil(timer_seconds))

	if displayed != timer_last_second:
		timer_last_second = displayed

		if is_instance_valid(timer_label):
			timer_label.text = _time_string(displayed)


# ============================================================
# REFERENCE ROOM BACKGROUND
# Cinematic interior backdrop matching the supplied reference.
# Interactive panels and keyboard remain separate 3D elements.
# ============================================================

func _build_reference_room_background() -> void:
	var room_texture := load("res://assets/luxury_living_room.png") as Texture2D
	if room_texture == null:
		push_warning("Luxury living-room background image is missing.")
		return

	var room := MeshInstance3D.new()
	room.name = "Luxury Living Room Reference Background"
	var room_mesh := QuadMesh.new()
	room_mesh.size = Vector2(42.0, 23.625)
	room.mesh = room_mesh
	room.position = Vector3(0.0, 0.0, -15.0)

	var room_material := StandardMaterial3D.new()
	room_material.albedo_texture = room_texture
	room_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	room_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	room_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room_material.roughness = 1.0
	room.material_override = room_material
	office_root.add_child(room)

	var world := WorldEnvironment.new()
	world.name = "NEXUS Room World Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#17131A")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D4B38E")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	office_root.add_child(world)


# ============================================================
# MATERIALS AND MESHES
# ============================================================

func _mat(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.55,
	emission: float = 0.0
) -> StandardMaterial3D:

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness

	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission

	return material


func _box(
	parent: Node3D,
	label: String,
	size: Vector3,
	pos: Vector3,
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.55
) -> MeshInstance3D:

	var item := MeshInstance3D.new()
	item.name = label

	var mesh := BoxMesh.new()
	mesh.size = size

	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color, metallic, roughness)

	parent.add_child(item)
	return item


func _sphere(
	parent: Node3D,
	label: String,
	radius: float,
	pos: Vector3,
	color: Color,
	scale_value: Vector3 = Vector3.ONE
) -> MeshInstance3D:

	var item := MeshInstance3D.new()
	item.name = label

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12

	item.mesh = mesh
	item.position = pos
	item.scale = scale_value
	item.material_override = _mat(color)

	parent.add_child(item)
	return item


func _cylinder(
	parent: Node3D,
	label: String,
	radius: float,
	height: float,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:

	var item := MeshInstance3D.new()
	item.name = label

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20

	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color)

	parent.add_child(item)
	return item


# ============================================================
# ROOM
# ============================================================

func _build_environment() -> void:

	_box(
		office_root, "Walnut Floor",
		Vector3(14, 0.16, 18),
		Vector3(0, -1.68, -3.8),
		Color("#38291F"), 0.05, 0.34
	)

	_box(
		office_root, "Ceiling",
		Vector3(14, 0.18, 18),
		Vector3(0, 3.45, -3.8),
		Color("#29231F")
	)

	_box(
		office_root, "Left Wall",
		Vector3(0.18, 5.1, 18),
		Vector3(-7, 0.86, -3.8),
		Color("#514237")
	)

	_box(
		office_root, "Right Wall",
		Vector3(0.18, 5.1, 18),
		Vector3(7, 0.86, -3.8),
		Color("#514237")
	)

	_box(
		office_root, "Rear Wall",
		Vector3(14, 5.1, 0.2),
		Vector3(0, 0.86, 5.2),
		Color("#302721")
	)

	_box(
		office_root, "Feature Wall",
		Vector3(13.5, 3.5, 0.1),
		Vector3(0, 0.72, 5.04),
		Color("#493326")
	)

	_build_window()
	_build_garden()

	_box(
		office_root, "Large Wool Rug",
		Vector3(6.4, 0.025, 5.0),
		Vector3(-2.3, -1.575, -4.8),
		Color("#75604D")
	)


func _build_window() -> void:
	# Transparent glass: the garden scenery remains visible behind it.
	var glass := MeshInstance3D.new()
	glass.name = "Panoramic Glass"
	var glass_mesh := QuadMesh.new()
	glass_mesh.size = Vector2(11.5, 3.55)
	glass.mesh = glass_mesh
	glass.position = Vector3(0, 0.75, -10.4)

	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.42, 0.58, 0.68, 0.10)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.18
	glass_material.roughness = 0.12
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glass.material_override = glass_material
	office_root.add_child(glass)

	for x in [-5.75, -2.9, 0.0, 2.9, 5.75]:
		_box(
			office_root, "Bronze Window Frame",
			Vector3(0.055, 3.75, 0.09),
			Vector3(x, 0.75, -10.32),
			Color("#44372D"), 0.75, 0.26
		)

	for y in [-1.02, 2.52]:
		_box(
			office_root, "Window Rail",
			Vector3(11.6, 0.06, 0.09),
			Vector3(0, y, -10.32),
			Color("#44372D"), 0.75, 0.26
		)

	_box(
		office_root, "Window Sill",
		Vector3(11.8, 0.13, 0.38),
		Vector3(0, -1.13, -10.12),
		WALNUT
	)

	_box(
		office_root, "Curtain Left",
		Vector3(0.72, 3.9, 0.16),
		Vector3(-6.0, 0.68, -10.05),
		Color("#8C7661")
	)

	_box(
		office_root, "Curtain Right",
		Vector3(0.72, 3.9, 0.16),
		Vector3(6.0, 0.68, -10.05),
		Color("#8C7661")
	)


func _build_garden() -> void:
	# Photorealistic twilight garden panorama, used as the view beyond
	# the office's existing panoramic window. The image is intentionally
	# separate from the glass so the window remains transparent.
	var garden_image := load("res://assets/twilight_garden.png") as Texture2D
	if garden_image == null:
		push_warning("NEXUS garden image was not found; using the plain twilight backdrop.")
		return

	var panorama := MeshInstance3D.new()
	panorama.name = "Photorealistic Twilight Garden Panorama"
	var panorama_mesh := QuadMesh.new()
	panorama_mesh.size = Vector2(18.0, 10.125)
	panorama.mesh = panorama_mesh
	panorama.position = Vector3(0.0, 0.75, -16.15)

	var panorama_material := StandardMaterial3D.new()
	panorama_material.albedo_texture = garden_image
	panorama_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panorama_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panorama_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	panorama_material.roughness = 1.0
	panorama.material_override = panorama_material
	office_root.add_child(panorama)


# ============================================================
# FURNITURE
# ============================================================

func _build_furniture() -> void:
	_build_desk()
	_build_sofa()
	_build_shelves()
	_build_plants()
	_build_fireplace()


func _build_desk() -> void:

	_box(
		office_root, "Walnut Desktop",
		Vector3(3.3, 0.14, 1.25),
		Vector3(0, -0.82, -3.55),
		Color("#5A3D2B"), 0.08, 0.24
	)

	for x in [-1.42, 1.42]:
		_box(
			office_root, "Desk Pedestal",
			Vector3(0.48, 0.76, 0.9),
			Vector3(x, -1.27, -3.55),
			Color("#38291F")
		)

	_box(
		office_root, "Monitor Housing",
		Vector3(1.45, 0.84, 0.075),
		Vector3(2.35, -0.18, -4.02),
		Color("#15191D"), 0.5, 0.22
	)

	_box(
		office_root, "Monitor Display",
		Vector3(1.37, 0.76, 0.012),
		Vector3(2.35, -0.18, -3.975),
		Color("#263747")
	)

	_box(
		office_root, "Monitor Stand",
		Vector3(0.11, 0.32, 0.12),
		Vector3(2.35, -0.66, -3.98),
		Color("#343638")
	)

	_box(
		office_root, "Monitor Base",
		Vector3(0.55, 0.035, 0.28),
		Vector3(2.35, -0.82, -3.98),
		GOLD, 0.8, 0.22
	)

	_box(
		office_root, "Chair Seat",
		Vector3(0.82, 0.17, 0.78),
		Vector3(0, -1.12, -1.85),
		Color("#373A3D")
	)

	_box(
		office_root, "Chair Back",
		Vector3(0.82, 0.95, 0.17),
		Vector3(0, -0.57, -2.14),
		Color("#303336")
	)

	_cylinder(
		office_root, "Chair Column",
		0.055, 0.55,
		Vector3(0, -1.43, -1.85),
		Color("#393A3B")
	)


func _build_sofa() -> void:

	_box(
		office_root, "Sofa Base",
		Vector3(2.8, 0.42, 0.95),
		Vector3(-4.35, -1.28, -4.7),
		Color("#746457")
	)

	_box(
		office_root, "Sofa Back",
		Vector3(2.8, 0.95, 0.24),
		Vector3(-4.35, -0.82, -5.08),
		Color("#66564A")
	)

	_box(
		office_root, "Coffee Table",
		Vector3(1.65, 0.09, 0.78),
		Vector3(-4.2, -1.05, -3.1),
		Color("#634630")
	)


func _build_shelves() -> void:

	_box(
		office_root, "Bookcase Back",
		Vector3(1.55, 3.0, 0.13),
		Vector3(5.65, 0.0, 3.95),
		Color("#3A2A20")
	)

	for y in [-1.25, -0.35, 0.55, 1.45]:
		_box(
			office_root, "Bookcase Shelf",
			Vector3(1.6, 0.075, 0.42),
			Vector3(5.65, y, 3.7),
			WALNUT
		)

	var book_colors: Array[Color] = [
		Color("#8A5D46"),
		Color("#C0A17A"),
		Color("#465B58"),
		Color("#8B7861"),
		Color("#A17A55")
	]

	for shelf in range(3):
		for j in range(5):
			var h: float = 0.36 + float((j + shelf) % 3) * 0.08

			_box(
				office_root, "Book",
				Vector3(0.11, h, 0.22),
				Vector3(
					5.08 + float(j) * 0.24,
					-0.82 + float(shelf) * 0.9 + h * 0.5,
					3.66
				),
				book_colors[(j + shelf) % book_colors.size()]
			)


func _build_plants() -> void:

	for x in [-6.0, 4.8]:
		_cylinder(
			office_root, "Planter",
			0.32, 0.45,
			Vector3(x, -1.35, -7.0),
			Color("#38332C")
		)

		for i in range(5):
			var angle: float = float(i) * TAU / 5.0

			_sphere(
				office_root, "Plant Leaf",
				0.24,
				Vector3(
					x + cos(angle) * 0.22,
					-0.52,
					-7.0 + sin(angle) * 0.2
				),
				Color("#496348"),
				Vector3(1.0, 0.45, 0.7)
			)


func _build_fireplace() -> void:

	_box(
		office_root, "Fireplace Surround",
		Vector3(2.0, 1.35, 0.35),
		Vector3(0, -0.78, 4.75),
		Color("#292521")
	)

	_box(
		office_root, "Fireplace Opening",
		Vector3(1.35, 0.65, 0.08),
		Vector3(0, -0.9, 4.54),
		Color("#100E0D")
	)

	var fire := _box(
		office_root, "Fireplace Glow",
		Vector3(0.9, 0.13, 0.025),
		Vector3(0, -1.1, 4.48),
		Color("#FF9B4A")
	)

	fire.material_override = _mat(
		Color("#FF9B4A"), 0.0, 0.25, 2.0
	)


# ============================================================
# LIGHTING
# ============================================================

func _build_lighting() -> void:

	var world := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#211D1A")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#A6A0A0")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.3

	world.environment = environment
	office_root.add_child(world)

	_add_light(
		Vector3(0, 2.35, -2.5),
		Color("#FFD5A0"), 2.0, 8.5
	)

	_add_light(
		Vector3(-4.8, 1.4, -3.8),
		Color("#F1C18B"), 1.15, 5.5
	)

	_add_light(
		Vector3(4.7, 1.5, 1.5),
		Color("#E9C99F"), 1.0, 5.0
	)


func _add_light(
	pos: Vector3,
	tint: Color,
	energy: float,
	radius: float
) -> void:

	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = true
	office_root.add_child(light)


# ============================================================
# 3D PANEL CREATION
# ============================================================

func _glass_material(texture: ViewportTexture) -> StandardMaterial3D:

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	return material


func _create_spatial_panel(
	panel_name: String,
	title: String,
	subtitle: String,
	dimensions: Vector2,
	resolution: Vector2i,
	position_3d: Vector3,
	yaw_degrees: float
) -> Dictionary:

	var panel := Node3D.new()
	panel.name = panel_name
	panel.position = position_3d
	panel.rotation.y = deg_to_rad(yaw_degrees)
	productivity_root.add_child(panel)

	# Smoked glass backing.
	var backing := _box(
		panel, "Glass Backing",
		Vector3(dimensions.x, dimensions.y, 0.025),
		Vector3(0, 0, -0.025),
		Color(0.025, 0.035, 0.05, 0.35)
	)

	var backing_material := _mat(
		Color(0.025, 0.035, 0.05, 0.35),
		0.25, 0.2
	)

	backing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	backing.material_override = backing_material

	# Gold edges.
	var edge: float = 0.008

	for x in [-dimensions.x * 0.5, dimensions.x * 0.5]:
		_box(
			panel, "Gold Vertical Edge",
			Vector3(edge, dimensions.y, 0.012),
			Vector3(x, 0, 0),
			GOLD, 0.8, 0.22
		)

	for y in [-dimensions.y * 0.5, dimensions.y * 0.5]:
		_box(
			panel, "Gold Horizontal Edge",
			Vector3(dimensions.x, edge, 0.012),
			Vector3(0, y, 0),
			GOLD, 0.8, 0.22
		)

	# SubViewport for the actual interface.
	var viewport := SubViewport.new()
	viewport.name = panel_name + "Viewport"
	viewport.size = resolution
	viewport.transparent_bg = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.055, 0.075, 0.22)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	root.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 46)
	heading.add_theme_color_override("font_color", GOLD_LIGHT)
	content.add_child(heading)

	var caption := Label.new()
	caption.text = subtitle
	caption.add_theme_font_size_override("font_size", 23)
	caption.add_theme_color_override("font_color", MUTED)
	content.add_child(caption)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = GOLD
	content.add_child(divider)

	# Actual 3D surface showing the live viewport.
	var quad := MeshInstance3D.new()
	quad.name = "Live Interactive Surface"

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = dimensions - Vector2(0.025, 0.025)

	quad.mesh = quad_mesh
	quad.position.z = 0.012
	quad.material_override = _glass_material(viewport.get_texture())
	panel.add_child(quad)

	# Collision target used by the XR controller laser.
	var hit := NexusPanelTarget.new()
	hit.name = "NexusPanelHitTarget"
	hit.office = self
	hit.panel_viewport = viewport
	hit.panel_size = dimensions
	hit.collision_layer = 1
	hit.collision_mask = 1
	hit.monitoring = true
	hit.monitorable = true

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(dimensions.x, dimensions.y, 0.08)
	collision.shape = shape
	hit.add_child(collision)
	panel.add_child(hit)

	return {
		"node": panel,
		"viewport": viewport,
		"content": content,
		"hit": hit
	}


# ============================================================
# TASKS / NOTES / FOCUS PANELS
# ============================================================

func _build_productivity_panels() -> void:

	var tasks := _create_spatial_panel(
		"SpatialTasksPanel",
		"01 / TASKS",
		"PLAN WITH INTENTION",
		Vector2(0.94, 1.38),
		Vector2i(1050, 1550),
		Vector3(-0.82, 0.08, -1.22),
		8.0
	)

	_build_tasks_ui(tasks["content"])

	var notes := _create_spatial_panel(
		"SpatialNotesPanel",
		"02 / NOTES",
		"THINK • WRITE • CREATE",
		Vector2(0.98, 1.42),
		Vector2i(1100, 1600),
		Vector3(0.0, 0.08, PANEL_DEPTH),
		0.0
	)

	_build_notes_ui(notes["content"])

	var focus := _create_spatial_panel(
		"SpatialFocusPanel",
		"03 / FOCUS",
		"PROTECT YOUR ATTENTION",
		Vector2(0.88, 1.35),
		Vector2i(1000, 1500),
		Vector3(0.96, 0.08, PANEL_DEPTH),
		-10.0
	)

	_build_focus_ui(focus["content"])


# ============================================================
# BUTTON STYLING
# ============================================================

func _ui_button(
	label: String,
	callback: Callable
) -> Button:

	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 29)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", GOLD_LIGHT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.12, 0.11, 0.96)
	normal.border_color = Color(0.72, 0.53, 0.32)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 14
	normal.content_margin_right = 14

	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.22, 0.16, 0.98)
	button.add_theme_stylebox_override("hover", hover)

	button.pressed.connect(callback)
	return button


# ============================================================
# TASKS
# ============================================================

func _build_tasks_ui(content: VBoxContainer) -> void:

	task_input = LineEdit.new()
	task_input.placeholder_text = "Write a new task..."
	task_input.custom_minimum_size = Vector2(0, 78)
	task_input.add_theme_font_size_override("font_size", 29)
	content.add_child(task_input)

	task_input.focus_entered.connect(_show_keyboard_for_task)

	content.add_child(
		_ui_button("+ ADD TASK", _add_task)
	)

	task_list = VBoxContainer.new()
	task_list.add_theme_constant_override("separation", 15)
	content.add_child(task_list)

	for task in task_data:
		_add_task_row(task)


func _add_task() -> void:

	var value: String = task_input.text.strip_edges()

	if value.is_empty():
		return

	task_data.append(value)
	_add_task_row(value)

	task_input.clear()
	task_input.release_focus()
	_save_tasks()


func _add_task_row(value: String) -> void:

	var check := CheckBox.new()
	check.text = value
	check.custom_minimum_size = Vector2(0, 64)
	check.add_theme_font_size_override("font_size", 26)
	check.add_theme_color_override("font_color", IVORY)
	check.add_theme_color_override("font_hover_color", GOLD_LIGHT)
	task_list.add_child(check)


# ============================================================
# NOTES
# ============================================================

func _build_notes_ui(content: VBoxContainer) -> void:

	notes_editor = TextEdit.new()
	notes_editor.placeholder_text = "Your ideas belong here..."
	notes_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_editor.custom_minimum_size = Vector2(0, 850)
	notes_editor.add_theme_font_size_override("font_size", 29)
	notes_editor.add_theme_color_override("font_color", IVORY)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.35)
	style.border_color = Color(0.72, 0.55, 0.34, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	notes_editor.add_theme_stylebox_override("normal", style)
	content.add_child(notes_editor)

	# Save automatically as the user types, as well as with SAVE NOTES.
	notes_editor.text_changed.connect(_save_notes)
	notes_editor.focus_entered.connect(_show_keyboard_for_notes)

	var file := FileAccess.open("user://nexus_notes.txt", FileAccess.READ)

	if file != null:
		notes_editor.text = file.get_as_text()
		file.close()

	content.add_child(
		_ui_button("SAVE NOTES", _save_notes)
	)

	content.add_child(
		_ui_button("HIDE KEYBOARD", _hide_keyboard)
	)


func _save_notes() -> void:

	var file := FileAccess.open(
		"user://nexus_notes.txt",
		FileAccess.WRITE
	)

	if file != null:
		file.store_string(notes_editor.text)
		file.close()


# ============================================================
# FOCUS TIMER
# ============================================================

func _build_focus_ui(content: VBoxContainer) -> void:

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	content.add_child(spacer)

	timer_label = Label.new()
	timer_label.text = "25:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 76)
	timer_label.add_theme_color_override("font_color", GOLD_LIGHT)
	content.add_child(timer_label)

	var description := Label.new()
	description.text = "MINUTES OF DEEP WORK"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 23)
	description.add_theme_color_override("font_color", MUTED)
	content.add_child(description)

	content.add_child(
		_ui_button("START / PAUSE", _toggle_timer)
	)

	content.add_child(
		_ui_button("RESET SESSION", _reset_timer)
	)

	var quote := Label.new()
	quote.text = "Less noise.\nMore intention.\nA better tomorrow."
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.add_theme_font_size_override("font_size", 27)
	quote.add_theme_color_override("font_color", IVORY)
	content.add_child(quote)


func _toggle_timer() -> void:
	timer_running = not timer_running


func _reset_timer() -> void:
	timer_running = false
	timer_seconds = 1500.0
	timer_last_second = -1

	if is_instance_valid(timer_label):
		timer_label.text = "25:00"


func _time_string(seconds: int) -> String:
	var minutes: int = int(seconds / 60)
	var remaining: int = seconds % 60
	return "%02d:%02d" % [minutes, remaining]


# ============================================================
# FLOATING KEYBOARD
# ============================================================

func _build_virtual_keyboard() -> void:

	var data := _create_spatial_panel(
		"FloatingVirtualKeyboard",
		"NEXUS KEYBOARD",
		"POINT AT A KEY AND PRESS TRIGGER",
		Vector2(1.20, 0.60),
		Vector2i(1300, 650),
		Vector3(0.0, -0.48, -0.92),
		0.0
	)

	keyboard_node = data["node"]
	keyboard_node.visible = true

	var content: VBoxContainer = data["content"]
	content.add_theme_constant_override("separation", 9)

	var rows: Array = [
		["Q","W","E","R","T","Y","U","I","O","P"],
		["A","S","D","F","G","H","J","K","L"],
		["Z","X","C","V","B","N","M","⌫"],
		["SPACE",".,?!","DONE"]
	]

	for row_data in rows:

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)

		for key in row_data:

			var button := Button.new()
			button.text = key
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 68)
			button.add_theme_font_size_override("font_size", 25)

			button.pressed.connect(
				_on_virtual_key.bind(key)
			)

			row.add_child(button)


func _show_keyboard_for_notes() -> void:
	active_editor = notes_editor
	_show_keyboard()


func _show_keyboard_for_task() -> void:
	active_editor = task_input
	_show_keyboard()


func _show_keyboard() -> void:

	if is_instance_valid(keyboard_node):
		keyboard_node.visible = true


func _hide_keyboard() -> void:

	if is_instance_valid(keyboard_node):
		keyboard_node.visible = false


func _on_virtual_key(key: String) -> void:

	if key == "DONE":
		_hide_keyboard()
		return

	if key == "SPACE":
		_insert_text(" ")
	elif key == "⌫":
		_backspace()
	elif key == ".,?!":
		_insert_text(".,?!")
	else:
		_insert_text(key.to_lower())


func _insert_text(value: String) -> void:

	if not is_instance_valid(active_editor):
		return

	if active_editor is TextEdit:
		var editor := active_editor as TextEdit
		editor.insert_text_at_caret(value)

	elif active_editor is LineEdit:
		var line := active_editor as LineEdit
		line.insert_text_at_caret(value)


func _backspace() -> void:

	if not is_instance_valid(active_editor):
		return

	if active_editor is TextEdit:
		var editor := active_editor as TextEdit
		var caret: int = editor.get_caret_column()
		var line: int = editor.get_caret_line()

		if caret > 0:
			editor.remove_text(
				line, caret - 1,
				line, caret
			)

	elif active_editor is LineEdit:
		var line_edit := active_editor as LineEdit
		var caret: int = line_edit.caret_column

		if caret > 0:
			line_edit.delete_text(caret - 1, caret)
			line_edit.caret_column = caret - 1


# ============================================================
# LASER CLICK → EXACT SUBVIEWPORT POSITION
# ============================================================

func _send_panel_click(
	viewport: SubViewport,
	point: Vector2
) -> void:

	if viewport == null:
		return

	var safe_point := Vector2(
		clampf(point.x, 0.0, float(viewport.size.x - 1)),
		clampf(point.y, 0.0, float(viewport.size.y - 1))
	)

	var motion := InputEventMouseMotion.new()
	motion.position = safe_point
	motion.global_position = safe_point
	viewport.push_input(motion, true)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = safe_point
	press.global_position = safe_point
	press.pressed = true
	viewport.push_input(press, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = safe_point
	release.global_position = safe_point
	release.pressed = false
	viewport.push_input(release, true)


# ============================================================
# SAVE AND LOAD TASKS
# ============================================================

func _save_tasks() -> void:

	var file := FileAccess.open(
		"user://nexus_tasks.txt",
		FileAccess.WRITE
	)

	if file != null:
		for task in task_data:
			file.store_line(task)
		file.close()


func _load_data() -> void:

	var file := FileAccess.open(
		"user://nexus_tasks.txt",
		FileAccess.READ
	)

	if file != null:
		task_data.clear()

		while not file.eof_reached():
			var line: String = file.get_line().strip_edges()

			if not line.is_empty():
				task_data.append(line)

		file.close()

	if task_data.is_empty():
		task_data = [
			"Set today's priorities",
			"Make progress on NEXUS",
			"Take a mindful break"
		]
