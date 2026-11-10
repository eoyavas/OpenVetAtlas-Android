class_name LandmarkDictionary
extends RefCounted
## LandmarkDictionary — Saf Latince (Nomina Anatomica Veterinaria) Sözlük ve Yazım Hatası Düzeltme Katmanı.
##
## Blender'dan yeniden FBX export almaya gerek kalmadan, FBX içindeki ham Node3D
## landmark adlarını (ör. "tubeculum majoris", "incusura radialis") normalize eder
## ve aliases_and_typos tablosu üzerinden resmi Latince terime ("Tuberculum majus") çözümler.

const DICTIONARY_PATH: String = "res://Assets/data/landmark_dictionary.json"
const UNMAPPED_LOG_PATH: String = "res://.tmp/unmapped_landmarks.json"

var _aliases_and_typos: Dictionary = {}
var _landmarks: Dictionary = {}
var _unmapped_raw_names: Dictionary = {}
var _is_loaded: bool = false


func load_dictionary(json_path: String = DICTIONARY_PATH) -> bool:
	_aliases_and_typos.clear()
	_landmarks.clear()
	_is_loaded = false

	if not FileAccess.file_exists(json_path):
		push_warning("[LandmarkDictionary] Sözlük dosyası bulunamadı: " + json_path)
		return false

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("[LandmarkDictionary] Sözlük dosyası açılamadı: " + json_path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[LandmarkDictionary] Geçersiz JSON formatı: " + json_path)
		return false

	var data: Dictionary = parsed as Dictionary
	_aliases_and_typos = data.get("aliases_and_typos", {}) as Dictionary
	_landmarks = data.get("landmarks", {}) as Dictionary
	_is_loaded = true
	return true


## Ham FBX Node3D düğüm adını ("caput humeri", "tubeculum majoris" vb.) normalize eder.
static func normalize_raw_name(raw_name: String) -> String:
	var cleaned: String = raw_name.strip_edges().to_lower()
	var dot_idx: int = cleaned.rfind(".")
	if dot_idx > 0 and cleaned.substr(dot_idx + 1).is_valid_int():
		cleaned = cleaned.substr(0, dot_idx).strip_edges()
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	return cleaned


## Ham FBX düğüm adını kanonik Latince sözlük girdisine çözümler.
## Dönen Dictionary:
## {
##   "raw_name": String,
##   "canonical_id": String,
##   "latin": String,
##   "is_mapped": bool
## }
func resolve(raw_name: String) -> Dictionary:
	if not _is_loaded:
		load_dictionary()

	var normalized: String = normalize_raw_name(raw_name)

	var canonical_id: String = ""
	if _aliases_and_typos.has(normalized):
		canonical_id = String(_aliases_and_typos[normalized])
	else:
		var snake_key: String = normalized.replace(" ", "_").replace("-", "_")
		if _landmarks.has(snake_key):
			canonical_id = snake_key

	if not canonical_id.is_empty() and _landmarks.has(canonical_id):
		var entry: Dictionary = _landmarks[canonical_id] as Dictionary
		var latin_term: String = String(entry.get("latin", _format_fallback_latin(normalized)))
		return {
			"raw_name": raw_name,
			"canonical_id": canonical_id,
			"latin": latin_term,
			"is_mapped": true
		}

	_unmapped_raw_names[raw_name] = normalized
	var fallback_latin: String = _format_fallback_latin(normalized)
	return {
		"raw_name": raw_name,
		"canonical_id": normalized.replace(" ", "_"),
		"latin": fallback_latin,
		"is_mapped": false
	}


func flush_unmapped_log() -> void:
	if _unmapped_raw_names.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var file: FileAccess = FileAccess.open(UNMAPPED_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_unmapped_raw_names, "\t"))
		file.close()


static func _format_fallback_latin(normalized: String) -> String:
	if normalized.is_empty():
		return "Unnamed Landmark"
	return normalized.left(1).to_upper() + normalized.substr(1)
