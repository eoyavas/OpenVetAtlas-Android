extends SceneTree
## Headless FBX Landmark Denetim Betiği
## Kullanım:
##   1) godot --headless --import
##   2) godot --headless -s res://scripts/dump_fbx_landmarks.gd
##
## Diskteki gerçek büyük/küçük harf duyarlı (case-sensitive) yolları kullanarak
## Assets/Models/Bones/ altındaki FBX modellerini yükler, ana MeshInstance3D
## ve altındaki Node3D landmark düğümlerini tarayıp .tmp/fbx_landmarks_dump.json dosyasına yazar.

const BONE_FBX_PATHS: Array[String] = [
	"res://Assets/Models/Bones/Dog_humerus.fbx",
	"res://Assets/Models/Bones/Dog_Radius.fbx",
	"res://Assets/Models/Bones/Dog_scapula.fbx",
	"res://Assets/Models/Bones/Dog_ulna.fbx",
	"res://Assets/Models/Bones/horse_cranium.fbx"
]

const OUTPUT_PATH: String = "res://.tmp/fbx_landmarks_dump.json"


func _init() -> void:
	var report: Dictionary = {
		"generated_by": "res://scripts/dump_fbx_landmarks.gd",
		"models": {},
		"all_unique_raw_landmarks": []
	}
	var unique_set: Dictionary = {}

	for fbx_path in BONE_FBX_PATHS:
		if not ResourceLoader.exists(fbx_path):
			push_error("[dump_fbx_landmarks] Kaynak bulunamadı: " + fbx_path)
			report["models"][fbx_path] = {"error": "Resource not found"}
			continue

		var packed: PackedScene = load(fbx_path) as PackedScene
		if packed == null:
			push_error("[dump_fbx_landmarks] PackedScene olarak yüklenemedi: " + fbx_path)
			report["models"][fbx_path] = {"error": "Failed to load PackedScene"}
			continue

		var root_node: Node = packed.instantiate()
		var mesh_nodes: Array[Dictionary] = []
		_inspect_hierarchy(root_node, mesh_nodes, unique_set)

		report["models"][fbx_path] = {
			"root_name": String(root_node.name),
			"root_class": root_node.get_class(),
			"meshes": mesh_nodes
		}
		root_node.free()

	var unique_list: Array = unique_set.keys()
	unique_list.sort()
	report["all_unique_raw_landmarks"] = unique_list

	# LandmarkDictionary doğrulama geçişi (0 eşleşmeyen terim kontrolü)
	var dict := LandmarkDictionary.new()
	var dict_loaded: bool = dict.load_dictionary()
	var resolved_summary: Array[Dictionary] = []
	var unmapped_count: int = 0
	for raw_item in unique_list:
		var raw_str: String = String(raw_item)
		var res: Dictionary = dict.resolve(raw_str)
		if not bool(res.get("is_mapped", false)):
			unmapped_count += 1
		resolved_summary.append({
			"raw_name": raw_str,
			"canonical_id": res.get("canonical_id", ""),
			"latin": res.get("latin", ""),
			"is_mapped": res.get("is_mapped", false)
		})

	report["dictionary_validation"] = {
		"dictionary_loaded": dict_loaded,
		"total_unique_raw_names": unique_list.size(),
		"mapped_count": unique_list.size() - unmapped_count,
		"unmapped_count": unmapped_count,
		"resolved_items": resolved_summary
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("[dump_fbx_landmarks] Başarıyla yazıldı: ", OUTPUT_PATH, " | Toplam ham landmark: ", unique_list.size(), " | Eşleşen: ", unique_list.size() - unmapped_count, " | Eşleşmeyen: ", unmapped_count)
	else:
		push_error("[dump_fbx_landmarks] Dosya yazılamadı: " + OUTPUT_PATH)

	quit(0 if (dict_loaded and unmapped_count == 0) else 1)


func _inspect_hierarchy(node: Node, mesh_nodes: Array[Dictionary], unique_set: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		var landmarks: Array[Dictionary] = []
		for child in mesh_inst.get_children():
			if child is Node3D and not (child is VisualInstance3D):
				var child_3d: Node3D = child as Node3D
				var raw_name: String = String(child_3d.name)
				unique_set[raw_name] = true
				landmarks.append({
					"name": raw_name,
					"class": child_3d.get_class(),
					"local_position": [
						 snappedf(child_3d.position.x, 0.0001),
						 snappedf(child_3d.position.y, 0.0001),
						 snappedf(child_3d.position.z, 0.0001)
					]
				})
		mesh_nodes.append({
			"mesh_node_name": String(mesh_inst.name),
			"landmark_count": landmarks.size(),
			"landmarks": landmarks
		})

	for child in node.get_children():
		_inspect_hierarchy(child, mesh_nodes, unique_set)
