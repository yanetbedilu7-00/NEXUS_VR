extends Node3D

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var fallback_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var luxury_office: NexusLuxuryOffice = $LuxuryOffice

@export var desktop_mouse_controls: bool = true
@export var room_move_speed: float = 2.8
@export var room_mouse_sensitivity: float = 0.0022

var desktop_mode: bool = true
var selected_controller: XRController3D
var keyboard_panel: Node3D
var keyboard_move_mode: bool = false
var productivity_mode: bool = false
var room_look_active: bool = false
var camera_pitch: float = 0.0
var mouse_sensitivity: float = 0.0025
var controller_move_limit := Vector3(2.10, 1.30, 0.15)
var controller_rotation_limit := Vector2(1.85, 2.65)

func _ready() -> void:
	# Hands are hidden until the productivity workspace is opened with F9.
	left_controller.position = Vector3(-0.34, 1.28, -0.58)
	right_controller.position = Vector3(0.34, 1.28, -0.58)
	left_controller.rotation = Vector3(0.38, 0.62, 0.0)
	right_controller.rotation = Vector3(-0.42, -0.48, 0.0)
	left_controller.visible = false
	right_controller.visible = false
	left_controller.show_when_tracked = false
	right_controller.show_when_tracked = false
	selected_controller = right_controller
	keyboard_panel = find_child("FloatingVirtualKeyboard", true, false) as Node3D
	luxury_office.set_productivity_visible(false)

	if desktop_mouse_controls:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not desktop_mouse_controls:
		var xr_interface := XRServer.find_interface("OpenXR")
		if xr_interface and not xr_interface.is_initialized():
			var initialized: bool = xr_interface.initialize()
			if initialized:
				get_viewport().use_xr = true
				desktop_mode = false
			else:
				push_warning("OpenXR did not initialize. Desktop navigation mode is active.")
		elif xr_interface and xr_interface.is_initialized():
			get_viewport().use_xr = true
			desktop_mode = false

func _process(delta: float) -> void:
	if not desktop_mode:
		return

	# Room navigation: WASD or arrow keys. Movement follows the room-facing direction.
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var forward := -xr_origin.global_transform.basis.z
		var right := xr_origin.global_transform.basis.x
		var movement := (right * input_dir.x + forward * -input_dir.y)
		xr_origin.global_position += movement * room_move_speed * delta

func _set_productivity_mode(enabled: bool) -> void:
	productivity_mode = enabled
	luxury_office.set_productivity_visible(enabled)
	left_controller.visible = enabled
	right_controller.visible = enabled
	if not enabled:
		keyboard_move_mode = false
		room_look_active = false

func _input(event: InputEvent) -> void:
	if not desktop_mode:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_set_productivity_mode(not productivity_mode)
			return
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if not productivity_mode:
			return
		match event.keycode:
			KEY_Q, KEY_1, KEY_F1:
				selected_controller = left_controller
				return
			KEY_E, KEY_2, KEY_F2:
				selected_controller = right_controller
				return
			KEY_T:
				keyboard_move_mode = not keyboard_move_mode
				return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			room_look_active = event.pressed
			return
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	if event is InputEventMouseMotion:
		# Hold the middle mouse button to look around the 3D room in either mode.
		if room_look_active:
			xr_origin.rotation.y -= event.relative.x * room_mouse_sensitivity
			camera_pitch = clampf(camera_pitch - event.relative.y * room_mouse_sensitivity, -1.15, 1.15)
			fallback_camera.rotation.x = camera_pitch
			return

		if not productivity_mode:
			return
		if keyboard_move_mode and is_instance_valid(keyboard_panel):
			keyboard_panel.position.x = clampf(keyboard_panel.position.x + event.relative.x * 0.0015, -0.8, 0.8)
			keyboard_panel.position.y = clampf(keyboard_panel.position.y - event.relative.y * 0.0015, -1.0, 0.2)
			return
		if selected_controller == null:
			return
		if Input.is_key_pressed(KEY_SHIFT):
			selected_controller.rotation.y = clampf(selected_controller.rotation.y - event.relative.x * 0.004, -controller_rotation_limit.y, controller_rotation_limit.y)
			selected_controller.rotation.x = clampf(selected_controller.rotation.x - event.relative.y * 0.004, -controller_rotation_limit.x, controller_rotation_limit.x)
		else:
			selected_controller.position.x = clampf(selected_controller.position.x + event.relative.x * mouse_sensitivity, -controller_move_limit.x, controller_move_limit.x)
			selected_controller.position.y = clampf(selected_controller.position.y - event.relative.y * mouse_sensitivity, 0.25, 2.45)

	elif event is InputEventMouseButton and productivity_mode:
		if selected_controller == null:
			return
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if keyboard_move_mode and is_instance_valid(keyboard_panel):
					keyboard_panel.position.z = minf(keyboard_panel.position.z + 0.08, -0.35)
				else:
					selected_controller.position.z = minf(selected_controller.position.z + 0.08, -0.12)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if keyboard_move_mode and is_instance_valid(keyboard_panel):
					keyboard_panel.position.z = maxf(keyboard_panel.position.z - 0.08, -1.6)
				else:
					selected_controller.position.z = maxf(selected_controller.position.z - 0.08, -2.20)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				selected_controller.set("desktop_trigger_value", 1.0)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				selected_controller.set("desktop_grip_value", 1.0)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				selected_controller.set("desktop_trigger_value", 0.0)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				selected_controller.set("desktop_grip_value", 0.0)
