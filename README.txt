NEXUS VR — Godot project
========================
Target: Godot 4.7.x

CONTENTS
- project.godot: project configuration
- scenes/main.tscn: complete starting scene with XROrigin3D, camera, and both controllers
- scripts/luxury_office.gd: room, lighting, furniture, three spatial UI panels, notes, tasks, timer, and floating keyboard
- scripts/nexus_hand_controller.gd: shared left/right hand model, articulated fingers, thumb, laser, and pointer click interaction
- scripts/main.gd: attempts OpenXR initialization when available

OPEN
1. Extract the ZIP.
2. In Godot Project Manager choose Import.
3. Select the extracted folder and open project.godot.
4. Open Project > Project Settings > XR and make sure OpenXR is enabled for your runtime.
5. Run the project using your configured OpenXR runtime or Godot XR emulator.

CONTROLLER SETTINGS
The left and right nodes already share nexus_hand_controller.gd.
LeftController: is_left_hand = true.
RightController: is_left_hand = false.

IMPORTANT
This is a procedural 3D prototype. The hand geometry is generated from smooth ellipsoids and joint pivots; it is not a scanned human hand or a rigged imported character model. OpenXR emulator input names and tracking behavior can vary by emulator/runtime. The script reads the standard grip, trigger, grip_click, and trigger_click values; if your emulator uses different action names, those bindings must be matched to its configuration.

UPDATE: The desktop fallback now places both hand models in front of the camera so they are visible when hand tracking is unavailable. The floating keyboard is visible at startup, and panel backgrounds use a lower-alpha smoked-glass tint so the room can show through.

For desktop testing, leave `desktop_mouse_controls` enabled on the NEXUS_VR root node. For a real headset, disable it and use OpenXR tracking.

The project has not been executed in Godot in this environment, so please treat it as a project build for first-run testing, not as a claim of a verified runtime build. If Godot reports an error, send the exact error text and I will patch that file.


DESKTOP HAND TEST CONTROLS (no headset)
- Hold Q and move the mouse to move the LEFT hand.
- Hold E and move the mouse to move the RIGHT hand.
- Hold Shift while moving the mouse to rotate the selected hand.
- Press T to enter/exit keyboard-move mode; move the mouse to reposition the keyboard and scroll to move it nearer/farther.
- Scroll up/down to move the selected hand closer/farther.
- Left mouse button = trigger / point-and-click.
- Right mouse button = grip / curl fingers.
- The keyboard is a fixed floating panel in front of you; move a hand to a key and left-click to activate it.
- The keyboard has been raised so it should fit better in the view.
- Hand material alpha has been reduced for a more transparent holographic appearance.

LATEST PATCH — LEFT/RIGHT REACH, HAND SHAPE, NOTES
- Q selects the LEFT hand; E selects the RIGHT hand. Press once to select; move the mouse to move that hand. You can also hold Q/E while moving.
- Shift + mouse movement rotates the selected hand. Rotation is clamped to a comfortable range rather than locking it into a narrow forward-only pose.
- Hand travel range has been widened horizontally and vertically, and the depth range has been extended so the pointer can reach the far-right FOCUS timer panel.
- The hand keeps the same translucent blue alpha (0.24) but uses rounded capsule finger sections and a soft thumb mound to reduce the segmented robot appearance.
- Notes now auto-save whenever text changes. The SAVE NOTES button still works too.
- On Windows, notes are stored at: %APPDATA%\Godot\app_userdata\NEXUS VR\nexus_notes.txt
- To find them quickly, press Win+R, enter %APPDATA%\Godot\app_userdata\NEXUS VR, and press Enter.


LATEST DESKTOP CONTROL UPDATE
------------------------------
Select LEFT hand: Q, 1, or F1
Select RIGHT hand: E, 2, or F2
Move selected hand: move mouse
Aim/rotate selected hand: hold SHIFT and move mouse
Move selected hand closer/farther: mouse wheel
Left mouse button: trigger / click
Right mouse button: grip / curl fingers
T: toggle floating-keyboard reposition mode

The left hand now starts angled toward the Tasks panel. Its panel is slightly
closer to the center and closer to the user, and the aim rotation range is wider.
The garden has brighter layered foliage, a stone path, flower beds, and warm
path lighting. Notes remain saved in user://nexus_notes.txt.


FINAL VISUAL / DESKTOP INPUT UPDATE
- The desktop mouse cursor is captured and hidden while steering the hands.
- Press ESC to release/show the cursor; click the game window to capture/hide it again.
- The panoramic window now uses the included photorealistic twilight garden image at assets/twilight_garden.png.
- Existing task, notes, focus timer, keyboard, hand movement, and laser scripts are retained.


FINAL REQUESTED VISUAL PATCH
----------------------------
- Replaced the garden/box-room environment with a full-view cinematic luxury living-room background matching the reference: cream sofa, warm recessed lighting, floor-to-ceiling dusk windows, illuminated shelves, plants, polished floor, rug, and fireplace.
- Kept the interactive task, notes, and focus panels, floating keyboard, left/right hands, laser interaction, desktop controls, and note persistence scripts.
- Desktop mouse mode starts CAPTURED, hiding the operating-system cursor while preserving relative mouse movement for hand steering. Press ESC to release the cursor; click the game window to capture it again.
- The background is a textured 3D panorama quad; panels and keyboard remain separate interactive 3D elements in front.

The archive is checked for completeness, but this environment does not have the Godot runtime, so a live emulator run could not be performed here.


NEXUS VR — F9 ROOM / PRODUCTIVITY MODE UPDATE
--------------------------------------------
Startup:
- The project opens in ROOM MODE. Only the navigable 3D room is shown.
- Press F9 to show the productivity workspace, both hand controllers, lasers,
  Tasks, Notes, Focus timer, and floating keyboard.
- Press F9 again to hide the workspace and return to room-only mode.

Room navigation (desktop):
- W / Up Arrow: move forward.
- S / Down Arrow: move backward.
- A / Left Arrow: move left.
- D / Right Arrow: move right.
- Hold the MIDDLE mouse button and move the mouse to look/rotate around.
- ESC releases/captures the mouse cursor.

Productivity mode retains the existing desktop hand controls:
- Q / 1 / F1 selects the LEFT hand.
- E / 2 / F2 selects the RIGHT hand.
- Move mouse to move selected hand; Shift + mouse to rotate it.
- Mouse wheel moves the hand closer/farther.
- Left mouse button triggers/clicks; right mouse button grips.
- T toggles floating-keyboard reposition mode.

The room is assembled from 3D floor, walls, window, furniture, plants,
fireplace, lighting, and garden elements. The productivity objects are
parented under a separate workspace node so F9 can hide them without hiding
the room. Existing task and notes persistence code is retained.

VALIDATION NOTE
---------------
The archive structure and script edits were checked in this environment.
Godot is not installed here, so a live engine parse or XR-emulator runtime
test could not be performed. Please open the project in Godot and run it once.


PATCH NOTE (2026-11-17)
-----------------------
Fixed a formatting corruption in scripts/main.gd: literal backslash-t
characters were converted to real GDScript indentation tabs. This was a
script parse blocker in the previous archive.
