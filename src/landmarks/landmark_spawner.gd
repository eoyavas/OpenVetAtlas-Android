class_name LandmarkSpawner
extends Node
## LandmarkSpawner — Tahribatsız 3B Yüzey Küresi (PinMarker3D) Üretici ve Seçim Yöneticisi.
##
## - 2B ekran rozetleri veya numaralar kullanılmaz; yalnızca doğrudan kemik yüzeyindeki
##   3B küreler (PinMarker3D) ve dokunma alanları (PinArea3D) kullanılır.
## - Ana kemik MeshInstance3D düğümüne prosedürel MatCap (veya Albedo + MatCap) materyali
##   ve StaticBody3D (Layer 1) trimesh çarpıştırıcısı ekler.
## - Alt Node3D landmark düğümlerinin yerel dönüşümlerini bozmadan her birine
##   dünya uzayında normalize edilmiş Area3D + SphereShape3D (Layer 2) ve 3B küre ekler.

signal landmark_selected(term_data: Dictionary)
signal landmarks_populated(terms_list: Array[Dictionary], total_pin_count: int)

const LAYER_BONE_OCCLUDER: int = 1
const LAYER_LANDMARK_AREA: int = 2

const COLOR_PIN_DEFAULT := Color(0.14, 0.56, 0.88, 1.0)
const COLOR_PIN_SELECTED := Color(0.98, 0.58, 0.12, 1.0)
const COLOR_PIN_CORRECT := Color(0.14, 0.82, 0.44, 1.0)
const COLOR_PIN_WRONG := Color(0.92, 0.24, 0.28, 1.0)

var dictionary: LandmarkDictionary = null
var active_mesh_instance: MeshInstance3D = null
var active_bone_static_body: StaticBody3D = null

var pins_visible: bool = true
var pins: Array[Dictionary] = []
var canonical_terms: Array[Dictionary] = []
var _canonical_map: Dictionary = {}
var selected_canonical_id: String = ""

var _desired_pin_world_radius: float = 1.0
var _occlusion_tolerance: float = 0.06
var _mat_pin_default: StandardMaterial3D = null
var _mat_pin_selected: StandardMaterial3D = null
var _mat_pin_correct: StandardMaterial3D = null
var _mat_pin_wrong: StandardMaterial3D = null


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_init_shared_resources()


func _init_shared_resources() -> void:
	if dictionary == null:
		dictionary = LandmarkDictionary.new()
		dictionary.load_dictionary()

	if _mat_pin_default == null:
		_mat_pin_default = StandardMaterial3D.new()
		_mat_pin_default.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_pin_default.albedo_color = COLOR_PIN_DEFAULT

	if _mat_pin_selected == null:
		_mat_pin_selected = StandardMaterial3D.new()
		_mat_pin_selected.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_pin_selected.albedo_color = COLOR_PIN_SELECTED

	if _mat_pin_correct == null:
		_mat_pin_correct = StandardMaterial3D.new()
		_mat_pin_correct.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_pin_correct.albedo_color = COLOR_PIN_CORRECT

	if _mat_pin_wrong == null:
		_mat_pin_wrong = StandardMaterial3D.new()
		_mat_pin_wrong.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_pin_wrong.albedo_color = COLOR_PIN_WRONG


func clear_current_landmarks() -> void:
	pins.clear()
	canonical_terms.clear()
	_canonical_map.clear()
	selected_canonical_id = ""
	active_mesh_instance = null
	active_bone_static_body = null


## 3B yüzey kürelerini açıp kapatır (Kemiği çıplak inceleme modu).
func set_pins_visible(visible_state: bool) -> void:
	pins_visible = visible_state
	for pin in pins:
		var marker: MeshInstance3D = pin["marker_mesh"] as MeshInstance3D
		var area: Area3D = pin["area_3d"] as Area3D
		if marker != null:
			marker.visible = pins_visible
		if area != null:
			area.monitorable = pins_visible


## Örneklenmiş (instantiated) FBX kök düğümünü tarar, ana MeshInstance3D'yi bulur,
## MatCap (veya Albedo + MatCap) materyalini ve StaticBody3D occlusion kalkanını ekler,
## tüm alt Node3D landmark noktalarını dünya uzayında normalize edilmiş 3B yüzey kürelerine dönüştürür.
func setup_bone_hierarchy(bone_root: Node3D, custom_albedo_tex: Texture2D = null) -> MeshInstance3D:
	_init_shared_resources()
	clear_current_landmarks()

	active_mesh_instance = _find_first_mesh_instance(bone_root)
	if active_mesh_instance == null:
		push_error("[LandmarkSpawner] Sahne içinde MeshInstance3D bulunamadı!")
		return null

	# 1. Kemik materyalini ata (Dokulu modelse Albedo+MatCap, değilse Prosedürel 256x256 Ivory MatCap)
	active_mesh_instance.material_override = MatCapGenerator.get_or_create_bone_material(custom_albedo_tex)

	# 2. Dünya AABB boyutuna göre 3B küre yarıçapını (%0.255 — önceki %0.85 boyutunun %30'u) ölçekle
	var local_aabb: AABB = active_mesh_instance.get_aabb()
	var world_aabb: AABB = active_mesh_instance.global_transform * local_aabb
	var world_max_extent: float = maxf(world_aabb.get_longest_axis_size(), 0.1)
	_desired_pin_world_radius = world_max_extent * 0.00255
	_occlusion_tolerance = world_max_extent * 0.020

	# 3. Ana kemik MeshInstance3D altına çalışma zamanı StaticBody3D (Trimesh Occlusion Kalkanı) ekle
	_attach_bone_occlusion_collider(active_mesh_instance)

	# 4. Doğrudan alt Node3D landmark düğümlerini tara (yerel Transform3D değiştirilmez)
	var raw_landmark_nodes: Array[Node3D] = []
	for child in active_mesh_instance.get_children():
		if child is Node3D and not (child is VisualInstance3D) and not (child is CollisionObject3D):
			raw_landmark_nodes.append(child as Node3D)

	var unit_sphere_mesh := SphereMesh.new()
	unit_sphere_mesh.radius = 1.0
	unit_sphere_mesh.height = 2.0
	unit_sphere_mesh.radial_segments = 16
	unit_sphere_mesh.rings = 8

	# Görsel 3B küre %30 boyutuna küçültüldüğü için dokunma alanı (görünmez) ters orantılı geniş tutulur
	var unit_sphere_shape := SphereShape3D.new()
	unit_sphere_shape.radius = 7.5

	for landmark_node in raw_landmark_nodes:
		var raw_name: String = String(landmark_node.name)
		var resolved: Dictionary = dictionary.resolve(raw_name)
		var canonical_id: String = String(resolved.get("canonical_id", ""))

		var term_entry: Dictionary
		if _canonical_map.has(canonical_id):
			term_entry = _canonical_map[canonical_id] as Dictionary
		else:
			term_entry = {
				"canonical_id": canonical_id,
				"latin": String(resolved.get("latin", raw_name)),
				"is_mapped": bool(resolved.get("is_mapped", false)),
				"pin_ids": []
			}
			_canonical_map[canonical_id] = term_entry
			canonical_terms.append(term_entry)

		var pin_id: int = pins.size()
		(term_entry["pin_ids"] as Array).append(pin_id)

		var parent_world_scale: Vector3 = landmark_node.global_transform.basis.get_scale()
		var normalized_local_scale := Vector3(
			_desired_pin_world_radius / maxf(absf(parent_world_scale.x), 0.0001),
			_desired_pin_world_radius / maxf(absf(parent_world_scale.y), 0.0001),
			_desired_pin_world_radius / maxf(absf(parent_world_scale.z), 0.0001)
		)

		var area := Area3D.new()
		area.name = "PinArea3D"
		area.collision_layer = LAYER_LANDMARK_AREA
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = pins_visible
		area.scale = normalized_local_scale
		area.set_meta("pin_id", pin_id)
		area.set_meta("canonical_id", canonical_id)

		var col_shape := CollisionShape3D.new()
		col_shape.shape = unit_sphere_shape
		area.add_child(col_shape)
		landmark_node.add_child(area)

		var marker_mesh := MeshInstance3D.new()
		marker_mesh.name = "PinMarker3D"
		marker_mesh.mesh = unit_sphere_mesh
		marker_mesh.material_override = _mat_pin_default
		marker_mesh.scale = normalized_local_scale
		marker_mesh.visible = pins_visible
		landmark_node.add_child(marker_mesh)

		pins.append({
			"pin_id": pin_id,
			"canonical_id": canonical_id,
			"raw_name": raw_name,
			"node_3d": landmark_node,
			"area_3d": area,
			"marker_mesh": marker_mesh,
			"base_local_scale": normalized_local_scale
		})

	landmarks_populated.emit(canonical_terms, pins.size())
	return active_mesh_instance


func _attach_bone_occlusion_collider(mesh_inst: MeshInstance3D) -> void:
	if mesh_inst.mesh == null:
		return
	var trimesh_shape: ConcavePolygonShape3D = mesh_inst.mesh.create_trimesh_shape()
	if trimesh_shape == null:
		return
	trimesh_shape.backface_collision = true

	var static_body := StaticBody3D.new()
	static_body.name = "BoneOcclusionStaticBody3D"
	static_body.collision_layer = LAYER_BONE_OCCLUDER
	static_body.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	col_shape.shape = trimesh_shape
	static_body.add_child(col_shape)
	mesh_inst.add_child(static_body)
	active_bone_static_body = static_body


## Hızlı dokunuşta (Quick Tap < 220ms) 3B ışın izleme ile kemik ön yüzeyindeki 3B küreyi seçer.
func handle_screen_tap(screen_pos: Vector2, camera: Camera3D) -> bool:
	if not pins_visible or camera == null or pins.is_empty():
		return false

	var world_3d: World3D = camera.get_world_3d()
	if world_3d == null:
		return false
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return false

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	var ray_end: Vector3 = ray_origin + ray_dir * camera.far

	var bone_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, LAYER_BONE_OCCLUDER)
	bone_query.collide_with_bodies = true
	bone_query.collide_with_areas = false
	var bone_hit: Dictionary = space_state.intersect_ray(bone_query)
	var max_allowed_dist: float = INF
	if not bone_hit.is_empty():
		max_allowed_dist = ray_origin.distance_to(bone_hit["position"]) + _occlusion_tolerance * 1.45

	var area_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, LAYER_LANDMARK_AREA)
	area_query.collide_with_bodies = false
	area_query.collide_with_areas = true

	var area_hit: Dictionary = space_state.intersect_ray(area_query)
	if not area_hit.is_empty():
		var hit_dist: float = ray_origin.distance_to(area_hit["position"])
		var collider: Object = area_hit.get("collider")
		if hit_dist <= max_allowed_dist and collider is Area3D:
			var hit_area := collider as Area3D
			if hit_area.has_meta("canonical_id"):
				var cid: String = String(hit_area.get_meta("canonical_id"))
				select_canonical_landmark(cid)
				return true

	return false


## Kanonik terim kimliğine (ör. "facies_serrata" veya "condylus_occipitalis") göre ilgili tüm 3B yüzey kürelerini vurgular.
func select_canonical_landmark(canonical_id: String) -> void:
	if not _canonical_map.has(canonical_id):
		return

	selected_canonical_id = canonical_id
	for pin in pins:
		var is_match: bool = (String(pin["canonical_id"]) == canonical_id)
		var marker: MeshInstance3D = pin["marker_mesh"] as MeshInstance3D
		var base_scale: Vector3 = pin["base_local_scale"] as Vector3

		if marker != null:
			marker.material_override = _mat_pin_selected if is_match else _mat_pin_default
			marker.scale = base_scale * (1.45 if is_match else 1.0)

	var term_data: Dictionary = _canonical_map[canonical_id] as Dictionary
	landmark_selected.emit(term_data)


## Seçilen kanonik terime ait 3B noktanın dünya uzayı koordinatını döndürür (kamera döndürme için).
func get_canonical_focus_position(canonical_id: String) -> Vector3:
	for pin in pins:
		if String(pin["canonical_id"]) == canonical_id:
			var node_3d: Node3D = pin["node_3d"] as Node3D
			if node_3d != null:
				return node_3d.global_position
	return Vector3.ZERO


func get_occlusion_tolerance() -> float:
	return _occlusion_tolerance


func clear_pin_selection() -> void:
	selected_canonical_id = ""
	for pin in pins:
		var marker: MeshInstance3D = pin["marker_mesh"] as MeshInstance3D
		var base_scale: Vector3 = pin["base_local_scale"] as Vector3
		if marker != null:
			marker.material_override = _mat_pin_default
			marker.scale = base_scale


func highlight_quiz_pin(canonical_id: String, is_correct: bool) -> void:
	selected_canonical_id = canonical_id
	var target_mat: StandardMaterial3D = _mat_pin_correct if is_correct else _mat_pin_wrong

	for pin in pins:
		var is_match: bool = (String(pin["canonical_id"]) == canonical_id)
		var marker: MeshInstance3D = pin["marker_mesh"] as MeshInstance3D
		var base_scale: Vector3 = pin["base_local_scale"] as Vector3

		if marker != null:
			marker.material_override = target_mat if is_match else _mat_pin_default
			marker.scale = base_scale * (1.48 if is_match else 1.0)


func get_term_by_canonical_id(canonical_id: String) -> Dictionary:
	return _canonical_map.get(canonical_id, {}) as Dictionary


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
