class_name TouchOrbitCamera
extends Camera3D
## TouchOrbitCamera — AABB Otomatik Odaklamalı, Landmark Noktasına Döndürmeli ve Hayalet Dokunuş Korumalı Kamera.
##
## - frame_mesh_instance(mesh_inst): Aktif kemiğin dünya uzayındaki AABB merkezini
##   otomatik olarak hedef pivot (target_pivot) alır ve başlangıç zoom mesafesini
##   AABB'nin en uzun kenarına göre otomatik ölçekler.
## - focus_on_world_point(landmark_world_pos, occlusion_tol, animate): Listeden bir anatomik
##   oluşum seçildiğinde kemiğin o noktayı kapatmadığı doğrudan görüş açısını hesaplayarak
##   kamerayı yumuşak bir geçişle (veya anında) o noktaya döndürür.
## - Titreme (Jitter) Koruması: 2 parmakla zoom/pan yapılırken aynı kare içinde peş peşe
##   gelen iki parmak drag olayını birleştirir (frame coalescing).
## - Hayalet Dokunuş Koruması (Freeze Fix): Parmak kaldırma (pressed=false) olaylarını
##   _input() içinde yakalar ve asılı kalan dokunuşları temizler.

signal camera_moved(camera: Camera3D)
signal quick_tap_performed(screen_pos: Vector2)

const TAP_MAX_DURATION_MS: int = 220
const TAP_MAX_DELTA_PX: float = 14.0
const STALE_TOUCH_TIMEOUT_MS: int = 2500
const ORBIT_SENSITIVITY: float = 0.0075
const PITCH_LIMIT_RAD: float = deg_to_rad(84.0)
const PINCH_DEADZONE_PX: float = 0.65
const PAN_DEADZONE_PX: float = 0.55
const LAYER_BONE_OCCLUDER: int = 1

var target_pivot: Vector3 = Vector3.ZERO
var default_pivot: Vector3 = Vector3.ZERO
var yaw: float = deg_to_rad(25.0)
var pitch: float = deg_to_rad(15.0)
var distance: float = 2.2
var default_distance: float = 2.2
var min_distance: float = 0.4
var max_distance: float = 8.0
var model_max_extent: float = 1.5

# Dokunmatik durum takibi
var _active_touches: Dictionary = {}
var _touch_last_seen_ms: Dictionary = {}
var _tap_start_time_ms: int = 0
var _tap_start_pos: Vector2 = Vector2.ZERO
var _tap_moved_distance: float = 0.0
var _was_multi_touch: bool = false
var _last_pinch_distance: float = -1.0
var _last_two_finger_center: Vector2 = Vector2.ZERO
var _two_finger_dirty: bool = false

# Masaüstü fare
var _mouse_orbiting: bool = false
var _mouse_panning: bool = false

# Otomatik döndürme (Tween) durumu
var _focus_tween: Tween = null
var _tween_start_yaw: float = 0.0
var _tween_target_yaw: float = 0.0
var _tween_start_pitch: float = 0.0
var _tween_target_pitch: float = 0.0
var _tween_start_pivot: Vector3 = Vector3.ZERO
var _tween_target_pivot: Vector3 = Vector3.ZERO
var _tween_start_distance: float = 2.2
var _tween_target_distance: float = 2.2


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_apply_camera_transform()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_touch_state()


func _cancel_focus_tween() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null


## Asılı kalan hayalet dokunuşları (ghost touches) tamamen sıfırlar.
func reset_touch_state() -> void:
	_cancel_focus_tween()
	_active_touches.clear()
	_touch_last_seen_ms.clear()
	_was_multi_touch = false
	_last_pinch_distance = -1.0
	_two_finger_dirty = false
	_mouse_orbiting = false
	_mouse_panning = false


## Aktif kemiğin MeshInstance3D düğümünün dünya uzayındaki AABB merkezini ve
## en uzun kenarını hesaplayarak kamerayı otomatik odaklar (AABB Auto-Framing).
func frame_mesh_instance(mesh_inst: MeshInstance3D) -> void:
	reset_touch_state()
	if mesh_inst == null or mesh_inst.mesh == null:
		return

	var local_aabb: AABB = mesh_inst.get_aabb()
	var world_aabb: AABB = mesh_inst.global_transform * local_aabb
	model_max_extent = maxf(world_aabb.get_longest_axis_size(), 0.1)

	default_pivot = world_aabb.get_center()
	target_pivot = default_pivot

	default_distance = model_max_extent * 1.38
	min_distance = model_max_extent * 0.25
	max_distance = model_max_extent * 4.50
	distance = default_distance

	near = clampf(model_max_extent * 0.008, 0.005, 0.5)
	far = maxf(model_max_extent * 22.0, 150.0)

	yaw = deg_to_rad(28.0)
	pitch = deg_to_rad(14.0)
	_apply_camera_transform()


func reset_view() -> void:
	reset_touch_state()
	target_pivot = default_pivot
	distance = default_distance
	yaw = deg_to_rad(28.0)
	pitch = deg_to_rad(14.0)
	_apply_camera_transform()


## Seçilen 3B anatomik noktanın (landmark_world_pos) ve kemiğin ekranın tam ortasında,
## dik ve net görünmesi için kamerayı zoom-out yaparak o noktaya döndürür.
func focus_on_world_point(landmark_world_pos: Vector3, _occlusion_tol: float = 0.1, animate: bool = true) -> void:
	_cancel_focus_tween()

	# Kemiğin sağa/sola kaymaması için X ve Z ekseni her zaman kemik merkezine (default_pivot) kilitlenir;
	# Y ekseni ise kemiği ortada tutarken seçilen noktayı merkeze yaklaştırır.
	var desired_pivot := Vector3(
		default_pivot.x,
		lerpf(default_pivot.y, landmark_world_pos.y, 0.35),
		default_pivot.z
	)

	# Noktanın daha rahat ortalanması ve kemiğin bütünüyle görünmesi için zoom-out mesafesi
	var desired_distance: float = clampf(default_distance * 1.18, min_distance, max_distance)

	var dx: float = landmark_world_pos.x - default_pivot.x
	var dy: float = landmark_world_pos.y - default_pivot.y
	var dz: float = landmark_world_pos.z - default_pivot.z
	var horiz_len: float = Vector2(dx, dz).length()

	var target_yaw_raw: float = yaw
	if horiz_len > 0.0001:
		target_yaw_raw = atan2(dx, dz)

	var norm_y: float = clampf(dy / maxf(model_max_extent * 0.45, 0.01), -1.0, 1.0)
	var target_p: float = clampf(norm_y * deg_to_rad(26.0), deg_to_rad(-32.0), deg_to_rad(32.0))
	var target_y: float = yaw + angle_difference(yaw, target_yaw_raw)

	if not animate or not is_inside_tree():
		yaw = target_y
		pitch = target_p
		target_pivot = desired_pivot
		distance = desired_distance
		_apply_camera_transform()
		return

	_tween_start_yaw = yaw
	_tween_target_yaw = target_y
	_tween_start_pitch = pitch
	_tween_target_pitch = target_p
	_tween_start_pivot = target_pivot
	_tween_target_pivot = desired_pivot
	_tween_start_distance = distance
	_tween_target_distance = desired_distance

	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_apply_focus_tween_step, 0.0, 1.0, 0.34)


func _apply_focus_tween_step(t: float) -> void:
	yaw = lerpf(_tween_start_yaw, _tween_target_yaw, t)
	pitch = lerpf(_tween_start_pitch, _tween_target_pitch, t)
	target_pivot = _tween_start_pivot.lerp(_tween_target_pivot, t)
	distance = lerpf(_tween_start_distance, _tween_target_distance, t)
	_apply_camera_transform()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and _active_touches.has(touch.index):
			_on_touch_released(touch)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _mouse_orbiting:
				_mouse_orbiting = false
				var elapsed_ms: int = Time.get_ticks_msec() - _tap_start_time_ms
				if elapsed_ms <= TAP_MAX_DURATION_MS and _tap_moved_distance <= TAP_MAX_DELTA_PX:
					quick_tap_performed.emit(mb.position)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_mouse_panning = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_pressed(touch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		_handle_mouse_motion(event as InputEventMouseMotion)


func _prune_stale_touches(now_ms: int) -> void:
	var stale_keys: Array = []
	for idx in _touch_last_seen_ms.keys():
		if now_ms - int(_touch_last_seen_ms[idx]) > STALE_TOUCH_TIMEOUT_MS:
			stale_keys.append(idx)
	for idx in stale_keys:
		_active_touches.erase(idx)
		_touch_last_seen_ms.erase(idx)


func _on_touch_pressed(touch: InputEventScreenTouch) -> void:
	_cancel_focus_tween()
	var now_ms: int = Time.get_ticks_msec()
	_prune_stale_touches(now_ms)

	if touch.index == 0 and _active_touches.has(0):
		reset_touch_state()

	_active_touches[touch.index] = touch.position
	_touch_last_seen_ms[touch.index] = now_ms

	if _active_touches.size() == 1:
		_tap_start_time_ms = now_ms
		_tap_start_pos = touch.position
		_tap_moved_distance = 0.0
		_was_multi_touch = false
	elif _active_touches.size() >= 2:
		_was_multi_touch = true
		_init_two_finger_state()


func _on_touch_released(touch: InputEventScreenTouch) -> void:
	_active_touches.erase(touch.index)
	_touch_last_seen_ms.erase(touch.index)

	if _active_touches.size() < 2:
		_last_pinch_distance = -1.0
		_two_finger_dirty = false

	if _active_touches.is_empty():
		var elapsed_ms: int = Time.get_ticks_msec() - _tap_start_time_ms
		if not _was_multi_touch and elapsed_ms <= TAP_MAX_DURATION_MS and _tap_moved_distance <= TAP_MAX_DELTA_PX:
			quick_tap_performed.emit(touch.position)
		_was_multi_touch = false


func _handle_screen_drag(drag: InputEventScreenDrag) -> void:
	var now_ms: int = Time.get_ticks_msec()
	_prune_stale_touches(now_ms)

	if not _active_touches.has(drag.index):
		return

	_active_touches[drag.index] = drag.position
	_touch_last_seen_ms[drag.index] = now_ms
	var touch_count: int = _active_touches.size()

	if touch_count == 1 and not _was_multi_touch:
		_tap_moved_distance += drag.relative.length()
		yaw -= drag.relative.x * ORBIT_SENSITIVITY
		pitch = clampf(pitch + drag.relative.y * ORBIT_SENSITIVITY, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
		_apply_camera_transform()
	elif touch_count >= 2:
		_was_multi_touch = true
		if not _two_finger_dirty:
			_two_finger_dirty = true
			_process_coalesced_two_finger_gesture.call_deferred()


func _process_coalesced_two_finger_gesture() -> void:
	_two_finger_dirty = false
	if _active_touches.size() < 2:
		return

	var keys: Array = _active_touches.keys()
	var p0: Vector2 = _active_touches[keys[0]]
	var p1: Vector2 = _active_touches[keys[1]]
	var cur_dist: float = p0.distance_to(p1)
	var cur_center: Vector2 = (p0 + p1) * 0.5

	if _last_pinch_distance <= 1.0:
		_last_pinch_distance = cur_dist
		_last_two_finger_center = cur_center
		return

	var changed: bool = false
	var dist_diff: float = absf(cur_dist - _last_pinch_distance)
	if dist_diff > PINCH_DEADZONE_PX and cur_dist > 4.0:
		var pinch_ratio: float = _last_pinch_distance / cur_dist
		var target_dist: float = clampf(distance * pinch_ratio, min_distance, max_distance)
		distance = lerpf(distance, target_dist, 0.82)
		_last_pinch_distance = cur_dist
		changed = true

	var center_delta: Vector2 = cur_center - _last_two_finger_center
	if center_delta.length() > PAN_DEADZONE_PX:
		_pan_by_screen_delta(-center_delta * 0.85)
		_last_two_finger_center = cur_center
		changed = true

	if changed:
		_apply_camera_transform()


func _init_two_finger_state() -> void:
	var keys: Array = _active_touches.keys()
	if keys.size() >= 2:
		var p0: Vector2 = _active_touches[keys[0]]
		var p1: Vector2 = _active_touches[keys[1]]
		_last_pinch_distance = p0.distance_to(p1)
		_last_two_finger_center = (p0 + p1) * 0.5


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	_cancel_focus_tween()
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		distance = clampf(distance * 0.90, min_distance, max_distance)
		_apply_camera_transform()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		distance = clampf(distance * 1.10, min_distance, max_distance)
		_apply_camera_transform()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_mouse_panning = true
	elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_mouse_orbiting = true
		_tap_start_time_ms = Time.get_ticks_msec()
		_tap_start_pos = mb.position
		_tap_moved_distance = 0.0


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _mouse_orbiting:
		_tap_moved_distance += mm.relative.length()
		yaw -= mm.relative.x * ORBIT_SENSITIVITY
		pitch = clampf(pitch + mm.relative.y * ORBIT_SENSITIVITY, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
		_apply_camera_transform()
	elif _mouse_panning:
		_pan_by_screen_delta(-mm.relative)
		_apply_camera_transform()


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vp_height: float = maxf(vp.get_visible_rect().size.y, 1.0)
	var world_per_pixel: float = (2.0 * distance * tan(deg_to_rad(fov * 0.5))) / vp_height
	var right_vec: Vector3 = global_transform.basis.x.normalized()
	var up_vec: Vector3 = global_transform.basis.y.normalized()
	target_pivot += (right_vec * screen_delta.x - up_vec * screen_delta.y) * world_per_pixel


func _apply_camera_transform() -> void:
	var rot_basis := Basis.from_euler(Vector3(-pitch, yaw, 0.0))
	var offset: Vector3 = rot_basis.z * distance
	global_transform = Transform3D(rot_basis, target_pivot + offset)
	camera_moved.emit(self)
