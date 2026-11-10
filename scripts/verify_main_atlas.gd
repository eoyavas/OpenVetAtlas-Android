extends SceneTree
## Headless Entegrasyon Doğrulama Betiği — main_atlas.tscn (v0.4.0: 3B Yüzey Küreleri, Yatay/Dikey Küçültme & Kamera Odaklama)
## Kullanım:
##   godot --headless -s res://scripts/verify_main_atlas.gd

const MAIN_SCENE_PATH: String = "res://scenes/main_atlas.tscn"
const REPORT_PATH: String = "res://.tmp/atlas_verification_report.json"

const EXPECTED_SPECIMEN_METRICS: Array[Dictionary] = [
	{"id": "dog_humerus", "taxon": "Canidae", "expected_pins": 18, "expected_canonical_terms": 18, "expects_albedo_tex": false},
	{"id": "dog_scapula", "taxon": "Canidae", "expected_pins": 13, "expected_canonical_terms": 12, "expects_albedo_tex": false},
	{"id": "dog_radius", "taxon": "Canidae", "expected_pins": 7, "expected_canonical_terms": 7, "expects_albedo_tex": false},
	{"id": "dog_ulna", "taxon": "Canidae", "expected_pins": 9, "expected_canonical_terms": 9, "expects_albedo_tex": false},
	{"id": "horse_cranium", "taxon": "Equidae", "expected_pins": 29, "expected_canonical_terms": 26, "expects_albedo_tex": true}
]


func _init() -> void:
	_run_verification.call_deferred()


func _run_verification() -> void:
	var qm_script: Script = load("res://src/core/quality_manager.gd") as Script
	if qm_script != null and root.get_node_or_null("QualityManager") == null:
		var qm_node: Node = qm_script.new()
		qm_node.name = "QualityManager"
		root.add_child(qm_node)

	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[verify_main_atlas] Sahne yüklenemedi: " + MAIN_SCENE_PATH)
		quit(1)
		return

	var atlas: AtlasMainController = packed.instantiate() as AtlasMainController
	if atlas == null:
		push_error("[verify_main_atlas] AtlasMainController örneklendirilemedi!")
		quit(1)
		return

	root.add_child(atlas)
	await process_frame
	await physics_frame

	# Yatay/Dikey menü küçültme (collapse) testi
	atlas.set_drawer_collapsed(true)
	var drawer_collapsed_ok: bool = atlas.toggle_sheet_button.visible and (not atlas.drawer_body_vbox.visible)
	atlas.set_drawer_collapsed(false)
	var drawer_expanded_ok: bool = atlas.toggle_sheet_button.visible and atlas.drawer_body_vbox.visible
	var drawer_collapse_verified: bool = drawer_collapsed_ok and drawer_expanded_ok

	var all_passed: bool = drawer_collapse_verified
	var specimen_results: Array[Dictionary] = []

	for i in range(EXPECTED_SPECIMEN_METRICS.size()):
		var exp_info: Dictionary = EXPECTED_SPECIMEN_METRICS[i]
		var spec_id: String = String(exp_info["id"])
		var loaded_ok: bool = atlas.load_specimen_by_id(spec_id)
		await process_frame
		await physics_frame

		var spawner: LandmarkSpawner = atlas.landmark_spawner
		var cam: TouchOrbitCamera = atlas.orbit_camera
		var mesh_inst: MeshInstance3D = spawner.active_mesh_instance

		var pin_count: int = spawner.pins.size()
		var term_count: int = spawner.canonical_terms.size()
		var ui_list_btn_count: int = atlas.landmark_list_vbox.get_child_count()
		var taxon_ui_ok: bool = String(atlas.get_current_taxon().get("latin_title", "")) == String(exp_info["taxon"])

		# 2B rozetlerin ve numaraların tamamen kaldırıldığını doğrula
		var first_btn: Button = atlas.landmark_list_vbox.get_child(0) as Button if ui_list_btn_count > 0 else null
		var no_numbers_in_list_ok: bool = (first_btn != null and not first_btn.text.begins_with("01") and not first_btn.text.begins_with("1."))

		var matcap_valid: bool = false
		var albedo_tex_ok: bool = false
		if mesh_inst != null and mesh_inst.material_override is ShaderMaterial:
			var smat := mesh_inst.material_override as ShaderMaterial
			var tex: Texture2D = smat.get_shader_parameter("matcap_texture") as Texture2D
			if tex is ImageTexture and tex.get_width() == 256 and tex.get_height() == 256:
				matcap_valid = true
			var use_albedo: bool = bool(smat.get_shader_parameter("use_albedo_texture"))
			var albedo_tex: Texture2D = smat.get_shader_parameter("albedo_texture") as Texture2D
			if bool(exp_info["expects_albedo_tex"]):
				albedo_tex_ok = use_albedo and albedo_tex != null and albedo_tex.get_width() > 0
			else:
				albedo_tex_ok = not use_albedo

		var occlusion_body_valid: bool = (spawner.active_bone_static_body != null and spawner.active_bone_static_body.collision_layer == 1)
		var world_aabb: AABB = mesh_inst.global_transform * mesh_inst.get_aabb() if mesh_inst != null else AABB()
		var pivot_matches_aabb: bool = cam.target_pivot.distance_to(world_aabb.get_center()) < 0.001

		# Dünya uzayı 3B küre yarıçapı normalizasyonu kontrolü (%0.255 — %30 boyut)
		var expected_world_radius: float = world_aabb.get_longest_axis_size() * 0.00255
		var pin_world_scales_normalized: bool = true
		var sample_world_radius: float = 0.0
		for p in spawner.pins:
			var base_s: Vector3 = p["base_local_scale"] as Vector3
			var node_3d: Node3D = p["node_3d"] as Node3D
			var unhighlighted_world_r: float = (node_3d.global_transform.basis.get_scale().x * base_s.x)
			sample_world_radius = unhighlighted_world_r
			if absf(unhighlighted_world_r - expected_world_radius) > 0.05:
				pin_world_scales_normalized = false

		# Listeden bir terime tıklandığında kemiğin ortalandığını, zoom-out yaptığını ve o noktaya döndüğünü doğrula
		var sample_cid: String = String(spawner.canonical_terms[term_count - 1]["canonical_id"])
		atlas.focus_and_select_landmark(sample_cid, false)
		var focus_pos: Vector3 = spawner.get_canonical_focus_position(sample_cid)
		var centered_xz_ok: bool = (absf(cam.target_pivot.x - cam.default_pivot.x) < 0.001 and absf(cam.target_pivot.z - cam.default_pivot.z) < 0.001)
		var zoom_out_ok: bool = (cam.distance >= cam.default_distance * 1.10)
		var camera_focus_ok: bool = (spawner.selected_canonical_id == sample_cid and focus_pos != Vector3.ZERO and centered_xz_ok and zoom_out_ok)

		# Çift landmark özel testleri (Dog_scapula: facies_serrata, horse_cranium: condylus_occipitalis)
		var duplicate_landmark_ok: bool = true
		if spec_id == "dog_scapula":
			spawner.select_canonical_landmark("facies_serrata")
			var highlighted_pin_count: int = 0
			for p in spawner.pins:
				if String(p["canonical_id"]) == "facies_serrata":
					var m: MeshInstance3D = p["marker_mesh"] as MeshInstance3D
					var base_s: Vector3 = p["base_local_scale"] as Vector3
					if m != null and m.scale.x > base_s.x * 1.2:
						highlighted_pin_count += 1
			duplicate_landmark_ok = (
				highlighted_pin_count == 2
				and atlas.selected_latin_label.text == "Facies serrata (×2)"
			)
		elif spec_id == "horse_cranium":
			spawner.select_canonical_landmark("condylus_occipitalis")
			var highlighted_pin_count: int = 0
			for p in spawner.pins:
				if String(p["canonical_id"]) == "condylus_occipitalis":
					var m: MeshInstance3D = p["marker_mesh"] as MeshInstance3D
					var base_s: Vector3 = p["base_local_scale"] as Vector3
					if m != null and m.scale.x > base_s.x * 1.2:
						highlighted_pin_count += 1
			duplicate_landmark_ok = (
				highlighted_pin_count == 2
				and atlas.selected_latin_label.text == "Condylus occipitalis (×2)"
			)

		# 3B Küre Aç/Kapat testi
		atlas.set_pins_enabled(false)
		var hidden_ok: bool = not (spawner.pins[0]["marker_mesh"] as MeshInstance3D).visible
		atlas.set_pins_enabled(true)
		var shown_ok: bool = (spawner.pins[0]["marker_mesh"] as MeshInstance3D).visible
		var pin_toggle_ok: bool = hidden_ok and shown_ok

		# Quiz Modu (✔ / × kartı, tüm terimleri bitirme ve istediğinde çıkma) testi
		atlas.start_quiz(false)
		var quiz_started_ok: bool = atlas.is_quiz_mode and atlas.quiz_box.visible and (not atlas.landmark_scroll.visible)

		var first_target_cid: String = String(atlas.quiz_queue[0]["canonical_id"])
		var wrong_cid: String = String(atlas.quiz_queue[1]["canonical_id"])
		spawner.select_canonical_landmark(wrong_cid)
		var wrong_card_ok: bool = (atlas.feedback_symbol_label.text == "×")

		spawner.select_canonical_landmark(first_target_cid)
		var correct_card_ok: bool = (atlas.feedback_symbol_label.text == "✔")

		for q_idx in range(1, atlas.quiz_queue.size()):
			atlas.advance_quiz_question()
			var target_cid: String = String(atlas.quiz_queue[q_idx]["canonical_id"])
			spawner.select_canonical_landmark(target_cid)
		atlas.advance_quiz_question()
		var quiz_completed_ok: bool = (atlas.selected_latin_label.text.begins_with("✔") and atlas.quiz_next_button.disabled)

		atlas.stop_quiz()
		var quiz_exited_ok: bool = (not atlas.is_quiz_mode) and (not atlas.quiz_box.visible) and atlas.landmark_scroll.visible
		var quiz_all_ok: bool = quiz_started_ok and wrong_card_ok and correct_card_ok and quiz_completed_ok and quiz_exited_ok

		var spec_pass: bool = (
			loaded_ok
			and taxon_ui_ok
			and no_numbers_in_list_ok
			and pin_count == int(exp_info["expected_pins"])
			and term_count == int(exp_info["expected_canonical_terms"])
			and ui_list_btn_count == term_count
			and matcap_valid
			and albedo_tex_ok
			and occlusion_body_valid
			and pivot_matches_aabb
			and pin_world_scales_normalized
			and camera_focus_ok
			and duplicate_landmark_ok
			and pin_toggle_ok
			and quiz_all_ok
		)
		if not spec_pass:
			all_passed = false

		var cur_spec: Dictionary = atlas.get_current_specimen()
		specimen_results.append({
			"specimen_id": spec_id,
			"taxon": exp_info["taxon"],
			"latin_title": String(cur_spec.get("latin_title", "")),
			"passed": spec_pass,
			"pin_count": pin_count,
			"canonical_term_count": term_count,
			"albedo_texture_verified": albedo_tex_ok,
			"no_2d_badges_or_numbers": no_numbers_in_list_ok,
			"camera_focus_on_click_verified": camera_focus_ok,
			"normalized_pin_world_radius": snappedf(sample_world_radius, 0.001),
			"pin_world_scales_normalized": pin_world_scales_normalized,
			"pin_toggle_verified": pin_toggle_ok,
			"quiz_mode_verified": quiz_all_ok
		})

	var report: Dictionary = {
		"version": "0.4.0",
		"all_passed": all_passed,
		"drawer_collapse_verified": drawer_collapse_verified,
		"specimens_tested": specimen_results
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()

	print("[verify_main_atlas] v0.4.0 Doğrulaması tamamlandı | all_passed=", all_passed)
	atlas.free()
	quit(0 if all_passed else 1)
