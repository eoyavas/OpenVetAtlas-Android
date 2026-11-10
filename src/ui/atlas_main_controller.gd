class_name AtlasMainController
extends Node3D
## AtlasMainController — Veteriner Anatomi Atlası Sahne, Taksonomik Katalog ve Quiz Kontrolcüsü.
##
## - Veri güdümlü, genişletilebilir taksonomik katalog (TAXON_CATALOG: Canidae, Equidae vb.) sunar.
## - Sadece Latince (Nomina Anatomica Veterinaria) terimleri ve doğrudan kemik yüzeyindeki
##   3B küreleri (PinMarker3D) kullanır; 2B ekran rozeti veya sıra numarası kullanılmaz.
## - Listeden bir anatomik terime tıklandığında kemiği o 3B noktayı gösterecek şekilde döndürür.
## - Hem dikey (Portrait) hem yatay (Landscape) modda anatomik terimler menüsü küçültülüp büyütülebilir.

const TAXON_CATALOG: Array[Dictionary] = [
	{
		"taxon_id": "canidae",
		"latin_title": "Canidae",
		"specimens": [
			{
				"id": "dog_humerus",
				"latin_title": "Humerus",
				"path": "res://Assets/Models/Bones/Dog_humerus.fbx",
				"texture_path": ""
			},
			{
				"id": "dog_scapula",
				"latin_title": "Scapula",
				"path": "res://Assets/Models/Bones/Dog_scapula.fbx",
				"texture_path": ""
			},
			{
				"id": "dog_radius",
				"latin_title": "Radius",
				"path": "res://Assets/Models/Bones/Dog_Radius.fbx",
				"texture_path": ""
			},
			{
				"id": "dog_ulna",
				"latin_title": "Ulna",
				"path": "res://Assets/Models/Bones/Dog_ulna.fbx",
				"texture_path": ""
			}
		]
	},
	{
		"taxon_id": "equidae",
		"latin_title": "Equidae",
		"specimens": [
			{
				"id": "horse_cranium",
				"latin_title": "Cranium",
				"path": "res://Assets/Models/Bones/horse_cranium.fbx",
				"texture_path": "res://Assets/Models/Bones/horse_cranium.png"
			}
		]
	}
]

@onready var specimen_holder: Node3D = $SpecimenHolder
@onready var orbit_camera: TouchOrbitCamera = $TouchOrbitCamera
@onready var landmark_spawner: LandmarkSpawner = $LandmarkSpawner
@onready var safe_area_root: Control = $UILayer/SafeAreaRoot
@onready var top_bar_panel: PanelContainer = $UILayer/SafeAreaRoot/TopBar
@onready var top_bar_grid: GridContainer = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid
@onready var taxon_selector: OptionButton = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/NavRow/TaxonSelector
@onready var bone_selector: OptionButton = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/NavRow/BoneSelector
@onready var pins_toggle_button: Button = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/ToolRow/PinsToggleButton
@onready var quiz_mode_button: Button = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/ToolRow/QuizModeButton
@onready var quality_button: OptionButton = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/ToolRow/QualitySelector
@onready var reset_cam_button: Button = $UILayer/SafeAreaRoot/TopBar/TopBarMargin/TopBarGrid/ToolRow/ResetCamButton

@onready var info_drawer: PanelContainer = $UILayer/SafeAreaRoot/InfoDrawer
@onready var toggle_sheet_button: Button = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/HeaderHBox/ToggleSheetButton
@onready var selected_latin_label: Label = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/HeaderHBox/SelectedLatinLabel
@onready var drawer_body_vbox: VBoxContainer = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox
@onready var landmark_scroll: ScrollContainer = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/LandmarkScroll
@onready var landmark_list_vbox: VBoxContainer = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/LandmarkScroll/LandmarkListVBox

@onready var quiz_box: VBoxContainer = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox
@onready var quiz_feedback_card: PanelContainer = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizFeedbackCard
@onready var feedback_symbol_label: Label = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizFeedbackCard/CardMargin/CardHBox/FeedbackSymbolLabel
@onready var feedback_latin_label: Label = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizFeedbackCard/CardMargin/CardHBox/FeedbackLatinLabel
@onready var quiz_restart_button: Button = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizActionsHBox/QuizRestartButton
@onready var quiz_next_button: Button = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizActionsHBox/QuizNextButton
@onready var quiz_exit_button: Button = $UILayer/SafeAreaRoot/InfoDrawer/DrawerMargin/DrawerVBox/DrawerBodyVBox/QuizBox/QuizActionsHBox/QuizExitButton

var current_bone_instance: Node3D = null
var current_taxon_index: int = 0
var current_bone_index: int = 0
var is_bottom_sheet_collapsed: bool = false
var _term_list_buttons: Dictionary = {}

# Quiz durumu
var is_quiz_mode: bool = false
var quiz_queue: Array[Dictionary] = []
var quiz_current_index: int = 0
var quiz_correct_count: int = 0
var quiz_current_question_solved: bool = false
var _quiz_had_wrong_attempt: bool = false

# Klinik UI Stilleri
var _style_ctrl_normal: StyleBoxFlat = null
var _style_ctrl_hover: StyleBoxFlat = null
var _style_ctrl_pressed: StyleBoxFlat = null
var _style_ctrl_active_teal: StyleBoxFlat = null
var _style_ctrl_active_amber: StyleBoxFlat = null
var _style_list_row_normal: StyleBoxFlat = null
var _style_list_row_selected: StyleBoxFlat = null

var _style_card_neutral: StyleBoxFlat = null
var _style_card_correct: StyleBoxFlat = null
var _style_card_wrong: StyleBoxFlat = null
var _style_card_complete: StyleBoxFlat = null


func _ready() -> void:
	set_process(false)
	set_physics_process(false)

	_apply_ui_styles()
	_populate_top_bar_controls()
	_update_pins_toggle_text()

	# Olay güdümlü (Event-Driven) sinyal bağlantıları
	orbit_camera.quick_tap_performed.connect(_on_quick_tap_performed)
	landmark_spawner.landmark_selected.connect(_on_landmark_selected)
	landmark_spawner.landmarks_populated.connect(_on_landmarks_populated)

	taxon_selector.item_selected.connect(_on_taxon_selected)
	bone_selector.item_selected.connect(_on_bone_selected)
	pins_toggle_button.pressed.connect(_on_pins_toggle_pressed)
	quiz_mode_button.pressed.connect(_on_quiz_mode_button_pressed)
	reset_cam_button.pressed.connect(func() -> void: orbit_camera.reset_view())
	quality_button.item_selected.connect(_on_quality_selected)
	toggle_sheet_button.pressed.connect(_on_toggle_sheet_pressed)

	quiz_restart_button.pressed.connect(func() -> void: start_quiz(true))
	quiz_next_button.pressed.connect(func() -> void: advance_quiz_question())
	quiz_exit_button.pressed.connect(func() -> void: stop_quiz())

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_responsive_layout()

	# İlk taksonun ilk kemiğini (Canidae -> Humerus) yükle
	load_specimen(0, 0)


func _populate_top_bar_controls() -> void:
	taxon_selector.clear()
	for t_idx in range(TAXON_CATALOG.size()):
		var taxon_entry: Dictionary = TAXON_CATALOG[t_idx]
		taxon_selector.add_item(String(taxon_entry["latin_title"]), t_idx)

	_populate_bone_selector_for_taxon(0)

	quality_button.clear()
	quality_button.add_item("Low", 0)
	quality_button.add_item("Med", 1)
	quality_button.add_item("High", 2)
	var qm: Node = get_node_or_null("/root/QualityManager")
	if qm != null and "current_tier" in qm:
		quality_button.selected = int(qm.get("current_tier"))
	else:
		quality_button.selected = 0

	_style_option_popup(taxon_selector)
	_style_option_popup(bone_selector)
	_style_option_popup(quality_button)


func _populate_bone_selector_for_taxon(taxon_index: int) -> void:
	if bone_selector == null or taxon_index < 0 or taxon_index >= TAXON_CATALOG.size():
		return
	bone_selector.clear()
	var specimens: Array = TAXON_CATALOG[taxon_index]["specimens"] as Array
	for b_idx in range(specimens.size()):
		var spec: Dictionary = specimens[b_idx] as Dictionary
		bone_selector.add_item(String(spec["latin_title"]), b_idx)


## Belirtilen takson ve kemik indeksindeki modeli (ve varsa dokusunu) sahneye yükler.
func load_specimen(taxon_index: int, bone_index: int) -> bool:
	if taxon_index < 0 or taxon_index >= TAXON_CATALOG.size():
		return false
	var taxon_entry: Dictionary = TAXON_CATALOG[taxon_index]
	var specimens: Array = taxon_entry["specimens"] as Array
	if bone_index < 0 or bone_index >= specimens.size():
		return false

	var taxon_changed: bool = (current_taxon_index != taxon_index) or (bone_selector.item_count != specimens.size())
	current_taxon_index = taxon_index
	current_bone_index = bone_index

	if taxon_selector != null and taxon_selector.selected != taxon_index:
		taxon_selector.selected = taxon_index
	if taxon_changed:
		_populate_bone_selector_for_taxon(taxon_index)
	if bone_selector != null and bone_selector.selected != bone_index:
		bone_selector.selected = bone_index

	var spec: Dictionary = specimens[bone_index] as Dictionary

	landmark_spawner.clear_current_landmarks()
	if current_bone_instance != null and is_instance_valid(current_bone_instance):
		specimen_holder.remove_child(current_bone_instance)
		current_bone_instance.queue_free()
		current_bone_instance = null

	var fbx_path: String = String(spec["path"])
	if not ResourceLoader.exists(fbx_path):
		push_error("[AtlasMainController] FBX dosyası bulunamadı: " + fbx_path)
		return false

	var packed: PackedScene = load(fbx_path) as PackedScene
	if packed == null:
		push_error("[AtlasMainController] FBX sahnesi yüklenemedi: " + fbx_path)
		return false

	var albedo_tex: Texture2D = null
	var tex_path: String = String(spec.get("texture_path", ""))
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		albedo_tex = load(tex_path) as Texture2D

	current_bone_instance = packed.instantiate() as Node3D
	specimen_holder.add_child(current_bone_instance)

	var mesh_inst: MeshInstance3D = landmark_spawner.setup_bone_hierarchy(current_bone_instance, albedo_tex)
	if mesh_inst == null:
		return false

	orbit_camera.frame_mesh_instance(mesh_inst)

	if is_quiz_mode:
		start_quiz(true)
	elif not landmark_spawner.canonical_terms.is_empty():
		var first_cid: String = String(landmark_spawner.canonical_terms[0]["canonical_id"])
		landmark_spawner.select_canonical_landmark(first_cid)

	return true


## Specimen ID (ör. "dog_humerus", "horse_cranium") üzerinden doğrudan model yükler.
func load_specimen_by_id(specimen_id: String) -> bool:
	for t_idx in range(TAXON_CATALOG.size()):
		var specimens: Array = TAXON_CATALOG[t_idx]["specimens"] as Array
		for b_idx in range(specimens.size()):
			var spec: Dictionary = specimens[b_idx] as Dictionary
			if String(spec.get("id", "")) == specimen_id:
				return load_specimen(t_idx, b_idx)
	return false


## Aktif kemik sözlüğünü döndürür.
func get_current_specimen() -> Dictionary:
	if current_taxon_index >= 0 and current_taxon_index < TAXON_CATALOG.size():
		var specimens: Array = TAXON_CATALOG[current_taxon_index]["specimens"] as Array
		if current_bone_index >= 0 and current_bone_index < specimens.size():
			return specimens[current_bone_index] as Dictionary
	return {}


## Aktif takson sözlüğünü döndürür.
func get_current_taxon() -> Dictionary:
	if current_taxon_index >= 0 and current_taxon_index < TAXON_CATALOG.size():
		return TAXON_CATALOG[current_taxon_index]
	return {}


func _on_quick_tap_performed(screen_pos: Vector2) -> void:
	landmark_spawner.handle_screen_tap(screen_pos, orbit_camera)


func _on_taxon_selected(taxon_index: int) -> void:
	load_specimen(taxon_index, 0)


func _on_bone_selected(bone_index: int) -> void:
	load_specimen(current_taxon_index, bone_index)


func _on_pins_toggle_pressed() -> void:
	if is_quiz_mode:
		return
	set_pins_enabled(not landmark_spawner.pins_visible)


func set_pins_enabled(enabled: bool) -> void:
	landmark_spawner.set_pins_visible(enabled)
	_update_pins_toggle_text()


func _update_pins_toggle_text() -> void:
	if pins_toggle_button == null:
		return
	var active: bool = landmark_spawner.pins_visible
	pins_toggle_button.text = "● Pins" if active else "○ Pins"
	pins_toggle_button.disabled = is_quiz_mode
	if _style_ctrl_active_teal != null and _style_ctrl_normal != null:
		pins_toggle_button.add_theme_stylebox_override("normal", _style_ctrl_active_teal if active else _style_ctrl_normal)


func _on_quiz_mode_button_pressed() -> void:
	if is_quiz_mode:
		stop_quiz()
	else:
		start_quiz(true)


## Etkileşimli Latince Quiz modunu başlatır.
func start_quiz(shuffle_terms: bool = true) -> void:
	if landmark_spawner.canonical_terms.is_empty():
		return

	is_quiz_mode = true
	if not landmark_spawner.pins_visible:
		set_pins_enabled(true)
	_update_pins_toggle_text()

	_update_quiz_mode_button()
	landmark_scroll.visible = false
	quiz_box.visible = true

	if is_bottom_sheet_collapsed:
		is_bottom_sheet_collapsed = false
		_update_responsive_layout()

	quiz_queue.clear()
	for term in landmark_spawner.canonical_terms:
		quiz_queue.append(term)
	if shuffle_terms and quiz_queue.size() > 1:
		quiz_queue.shuffle()

	quiz_current_index = 0
	quiz_correct_count = 0
	_present_current_quiz_question()


## Quiz modundan çıkar ve normal atlas inceleme moduna döner.
func stop_quiz() -> void:
	is_quiz_mode = false
	_update_pins_toggle_text()
	_update_quiz_mode_button()

	quiz_box.visible = false
	landmark_scroll.visible = true

	if not landmark_spawner.canonical_terms.is_empty():
		var first_cid: String = String(landmark_spawner.canonical_terms[0]["canonical_id"])
		landmark_spawner.select_canonical_landmark(first_cid)


func _update_quiz_mode_button() -> void:
	if quiz_mode_button == null:
		return
	quiz_mode_button.text = "× Quiz" if is_quiz_mode else "Quiz"
	if _style_ctrl_active_amber != null and _style_ctrl_normal != null:
		quiz_mode_button.add_theme_stylebox_override("normal", _style_ctrl_active_amber if is_quiz_mode else _style_ctrl_normal)


func _present_current_quiz_question() -> void:
	landmark_spawner.clear_pin_selection()
	quiz_current_question_solved = false
	_quiz_had_wrong_attempt = false

	var total_q: int = quiz_queue.size()
	if quiz_current_index >= total_q:
		var spec: Dictionary = get_current_specimen()
		var bone_title: String = String(spec.get("latin_title", ""))
		selected_latin_label.text = "✔  %d / %d" % [quiz_correct_count, total_q]
		quiz_feedback_card.add_theme_stylebox_override("panel", _style_card_complete)
		feedback_symbol_label.text = "✔"
		feedback_symbol_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.32, 1.0))
		feedback_latin_label.text = "%s — %d / %d" % [
			bone_title,
			quiz_correct_count,
			total_q
		]
		quiz_next_button.disabled = true
		return

	quiz_next_button.disabled = false
	var target_term: Dictionary = quiz_queue[quiz_current_index]
	var target_latin: String = String(target_term["latin"])

	selected_latin_label.text = "%d / %d — %s" % [quiz_current_index + 1, total_q, target_latin]

	quiz_feedback_card.add_theme_stylebox_override("panel", _style_card_neutral)
	feedback_symbol_label.text = "◎"
	feedback_symbol_label.add_theme_color_override("font_color", Color(0.56, 0.78, 0.98, 1.0))
	feedback_latin_label.text = target_latin


## Sıradaki Quiz sorusuna geçer.
func advance_quiz_question() -> void:
	if not is_quiz_mode:
		return
	if quiz_current_index < quiz_queue.size():
		quiz_current_index += 1
	_present_current_quiz_question()


## Quiz modunda bir 3B küreye tıklandığında Doğru (✔) / Yanlış (×) kartını günceller.
func _evaluate_quiz_selection(term_data: Dictionary) -> void:
	if quiz_current_index >= quiz_queue.size():
		return

	if quiz_current_question_solved:
		advance_quiz_question()
		if quiz_current_index >= quiz_queue.size():
			return

	var tapped_cid: String = String(term_data.get("canonical_id", ""))
	var tapped_latin: String = String(term_data.get("latin", ""))
	var target_term: Dictionary = quiz_queue[quiz_current_index]
	var target_cid: String = String(target_term["canonical_id"])
	var target_latin: String = String(target_term["latin"])

	if tapped_cid == target_cid:
		quiz_current_question_solved = true
		if not _quiz_had_wrong_attempt:
			quiz_correct_count += 1
		landmark_spawner.highlight_quiz_pin(tapped_cid, true)

		quiz_feedback_card.add_theme_stylebox_override("panel", _style_card_correct)
		feedback_symbol_label.text = "✔"
		feedback_symbol_label.add_theme_color_override("font_color", Color(0.32, 1.0, 0.62, 1.0))
		feedback_latin_label.text = target_latin
	else:
		_quiz_had_wrong_attempt = true
		landmark_spawner.highlight_quiz_pin(tapped_cid, false)

		quiz_feedback_card.add_theme_stylebox_override("panel", _style_card_wrong)
		feedback_symbol_label.text = "×"
		feedback_symbol_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.44, 1.0))
		feedback_latin_label.text = tapped_latin


func _on_quality_selected(index: int) -> void:
	var qm: Node = get_node_or_null("/root/QualityManager")
	if qm != null and qm.has_method("apply_quality_tier"):
		qm.call("apply_quality_tier", index)


func _on_landmarks_populated(terms_list: Array[Dictionary], _total_pin_count: int) -> void:
	_term_list_buttons.clear()
	for child in landmark_list_vbox.get_children():
		child.queue_free()

	for term in terms_list:
		var cid: String = String(term["canonical_id"])
		var latin_name: String = String(term["latin"])
		var pin_count: int = (term["pin_ids"] as Array).size()

		var item_btn := Button.new()
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.custom_minimum_size = Vector2(0.0, 40.0)
		item_btn.focus_mode = Control.FOCUS_NONE
		item_btn.clip_text = true
		item_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_btn.add_theme_font_size_override("font_size", 15)
		item_btn.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 1.0))
		item_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		item_btn.add_theme_stylebox_override("normal", _style_list_row_normal)
		item_btn.add_theme_stylebox_override("hover", _style_ctrl_hover)
		item_btn.add_theme_stylebox_override("pressed", _style_list_row_selected)

		var multi_suffix: String = ("  · ×%d" % pin_count) if pin_count > 1 else ""
		item_btn.text = "%s%s" % [latin_name, multi_suffix]
		item_btn.pressed.connect(func() -> void:
			focus_and_select_landmark(cid, true)
		)
		landmark_list_vbox.add_child(item_btn)
		_term_list_buttons[cid] = item_btn


## Menüden bir anatomik oluşum seçildiğinde ilgili 3B küreyi vurgular ve
## kemiği döndürerek o noktayı kullanıcının tam karşısına getirir.
func focus_and_select_landmark(canonical_id: String, animate_camera: bool = true) -> void:
	if not landmark_spawner.pins_visible:
		set_pins_enabled(true)
	landmark_spawner.select_canonical_landmark(canonical_id)
	var focus_pos: Vector3 = landmark_spawner.get_canonical_focus_position(canonical_id)
	orbit_camera.focus_on_world_point(focus_pos, landmark_spawner.get_occlusion_tolerance(), animate_camera)


func _on_landmark_selected(term_data: Dictionary) -> void:
	if is_quiz_mode:
		_evaluate_quiz_selection(term_data)
		return

	var latin_name: String = String(term_data.get("latin", ""))
	var pin_count: int = (term_data.get("pin_ids", []) as Array).size()

	selected_latin_label.text = latin_name + ((" (×%d)" % pin_count) if pin_count > 1 else "")

	var active_cid: String = String(term_data.get("canonical_id", ""))
	for cid in _term_list_buttons.keys():
		var btn: Button = _term_list_buttons[cid] as Button
		if btn != null:
			var is_sel: bool = (cid == active_cid)
			btn.add_theme_stylebox_override("normal", _style_list_row_selected if is_sel else _style_list_row_normal)
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0) if is_sel else Color(0.90, 0.94, 0.98, 1.0))


func _on_toggle_sheet_pressed() -> void:
	set_drawer_collapsed(not is_bottom_sheet_collapsed)


## Anatomik terimler menüsünü (hem dikey hem yatay modda) küçültür veya açar.
func set_drawer_collapsed(collapsed: bool) -> void:
	is_bottom_sheet_collapsed = collapsed
	_update_responsive_layout()


func _on_viewport_size_changed() -> void:
	_update_responsive_layout()


## Cihazın Telefon veya Tablet olduğunu, ekran yönünü (Dikey / Yatay) ve menülerin
## minimum genişliğini hesaba katarak menülerin her zaman ekrana tam sığmasını ("Fit-to-Screen")
## garanti eden dinamik ölçek değerini hesaplar.
func _apply_adaptive_ui_scale() -> Vector2:
	var win: Window = get_window()
	var win_size: Vector2i = DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0:
		if win != null and win.size.x > 0 and win.size.y > 0:
			win_size = win.size
		else:
			return Vector2(1080.0, 1920.0)

	if win != null and win.content_scale_size != Vector2i.ZERO:
		win.content_scale_size = Vector2i.ZERO

	var short_edge_px: float = float(mini(win_size.x, win_size.y))
	var is_landscape: bool = win_size.x >= win_size.y

	if top_bar_grid != null:
		top_bar_grid.columns = 2 if is_landscape else 1

	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = 420 if (OS.has_feature("android") or OS.has_feature("mobile")) else 96

	var diag_inches: float = Vector2(float(win_size.x) / float(dpi), float(win_size.y) / float(dpi)).length()
	var is_mobile_platform: bool = OS.has_feature("android") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	var is_tablet: bool = diag_inches >= 6.85 or (not is_mobile_platform and short_edge_px >= 900.0)

	var target_short_edge_logical: float
	if not is_tablet:
		target_short_edge_logical = 420.0 if is_landscape else 410.0
	else:
		target_short_edge_logical = 520.0 if is_landscape else 560.0

	var desired_scale: float = short_edge_px / target_short_edge_logical

	var top_bar_min_w: float = top_bar_panel.get_combined_minimum_size().x if top_bar_panel != null else 260.0
	var min_required_logical_w: float = maxf(top_bar_min_w + 48.0, 740.0 if is_landscape else 410.0)
	var min_required_logical_h: float = 420.0 if is_landscape else 680.0
	var max_fit_scale_x: float = float(win_size.x) / min_required_logical_w
	var max_fit_scale_y: float = float(win_size.y) / min_required_logical_h
	var max_fit_scale: float = minf(max_fit_scale_x, max_fit_scale_y)

	var computed_scale: float = clampf(minf(desired_scale, max_fit_scale), 1.0, 3.4)
	if win != null and absf(win.content_scale_factor - computed_scale) > 0.02:
		win.content_scale_factor = computed_scale

	return Vector2(float(win_size.x) / computed_scale, float(win_size.y) / computed_scale)


func _update_responsive_layout() -> void:
	var logical_size: Vector2 = _apply_adaptive_ui_scale()
	if safe_area_root == null or info_drawer == null:
		return

	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var win_size: Vector2i = DisplayServer.window_get_size()

	var margin_left: float = 12.0
	var margin_top: float = 10.0
	var margin_right: float = 12.0
	var margin_bottom: float = 10.0

	if win_size.x > 0 and win_size.y > 0 and safe_rect.size.x > 0 and safe_rect.size.y > 0:
		var scale_x: float = logical_size.x / float(win_size.x)
		var scale_y: float = logical_size.y / float(win_size.y)
		margin_left = maxf(12.0, float(safe_rect.position.x) * scale_x + 4.0)
		margin_top = maxf(10.0, float(safe_rect.position.y) * scale_y + 4.0)
		margin_right = maxf(12.0, float(win_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x + 4.0)
		margin_bottom = maxf(10.0, float(win_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y + 4.0)

	safe_area_root.offset_left = margin_left
	safe_area_root.offset_top = margin_top
	safe_area_root.offset_right = -margin_right
	safe_area_root.offset_bottom = -margin_bottom

	var avail_w: float = maxf(logical_size.x - margin_left - margin_right, 240.0)
	var avail_h: float = maxf(logical_size.y - margin_top - margin_bottom, 240.0)
	var is_landscape: bool = logical_size.x >= logical_size.y

	if top_bar_grid != null:
		top_bar_grid.columns = 2 if (is_landscape and avail_w >= 540.0) else 1

	toggle_sheet_button.visible = true
	drawer_body_vbox.visible = not is_bottom_sheet_collapsed

	if is_landscape:
		toggle_sheet_button.text = "▼" if is_bottom_sheet_collapsed else "▲"
		var panel_width: float = clampf(avail_w * 0.34, 220.0, 320.0)
		var top_bar_height: float = 56.0 if (top_bar_grid != null and top_bar_grid.columns == 2) else 98.0
		info_drawer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		info_drawer.anchor_left = 1.0
		info_drawer.anchor_right = 1.0
		info_drawer.anchor_top = 0.0
		info_drawer.offset_left = -panel_width
		info_drawer.offset_right = 0.0
		info_drawer.offset_top = top_bar_height
		if is_bottom_sheet_collapsed:
			info_drawer.anchor_bottom = 0.0
			info_drawer.offset_bottom = top_bar_height + 54.0
		else:
			info_drawer.anchor_bottom = 1.0
			info_drawer.offset_bottom = 0.0
	else:
		toggle_sheet_button.text = "▲" if is_bottom_sheet_collapsed else "▼"
		var sheet_height: float = 54.0 if is_bottom_sheet_collapsed else clampf(avail_h * 0.35, 180.0, 290.0)
		info_drawer.grow_horizontal = Control.GROW_DIRECTION_END
		info_drawer.anchor_left = 0.0
		info_drawer.anchor_right = 1.0
		info_drawer.anchor_top = 1.0
		info_drawer.anchor_bottom = 1.0
		info_drawer.offset_left = 0.0
		info_drawer.offset_right = 0.0
		info_drawer.offset_top = -sheet_height
		info_drawer.offset_bottom = 0.0


func _style_option_popup(opt_btn: OptionButton) -> void:
	if opt_btn == null:
		return
	var popup: PopupMenu = opt_btn.get_popup()
	if popup == null:
		return
	popup.add_theme_font_size_override("font_size", 15)
	popup.add_theme_constant_override("v_separation", 10)
	popup.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1.0))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.60, 1.0))

	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = Color(0.09, 0.12, 0.16, 0.98)
	popup_panel.border_color = Color(0.28, 0.38, 0.50, 0.90)
	popup_panel.set_border_width_all(1)
	popup_panel.set_corner_radius_all(8)
	popup_panel.content_margin_left = 10
	popup_panel.content_margin_right = 10
	popup_panel.content_margin_top = 8
	popup_panel.content_margin_bottom = 8
	popup.add_theme_stylebox_override("panel", popup_panel)

	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(0.16, 0.23, 0.31, 1.0)
	popup_hover.set_corner_radius_all(6)
	popup.add_theme_stylebox_override("hover", popup_hover)


func _apply_button_style(btn: Control) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _style_ctrl_normal)
	btn.add_theme_stylebox_override("hover", _style_ctrl_hover)
	btn.add_theme_stylebox_override("pressed", _style_ctrl_pressed)
	btn.add_theme_stylebox_override("focus", _style_ctrl_normal)
	btn.add_theme_color_override("font_color", Color(0.92, 0.95, 0.99, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.68, 1.0))


func _apply_ui_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.12, 0.16, 0.94)
	panel_style.border_color = Color(0.22, 0.30, 0.40, 0.78)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)

	if top_bar_panel != null:
		top_bar_panel.add_theme_stylebox_override("panel", panel_style)
	if info_drawer != null:
		info_drawer.add_theme_stylebox_override("panel", panel_style)

	# Klinik Kontrol / Buton Stilleri
	_style_ctrl_normal = StyleBoxFlat.new()
	_style_ctrl_normal.bg_color = Color(0.13, 0.17, 0.22, 1.0)
	_style_ctrl_normal.border_color = Color(0.24, 0.32, 0.42, 0.82)
	_style_ctrl_normal.set_border_width_all(1)
	_style_ctrl_normal.set_corner_radius_all(6)
	_style_ctrl_normal.content_margin_left = 8
	_style_ctrl_normal.content_margin_right = 8
	_style_ctrl_normal.content_margin_top = 4
	_style_ctrl_normal.content_margin_bottom = 4

	_style_ctrl_hover = _style_ctrl_normal.duplicate() as StyleBoxFlat
	_style_ctrl_hover.bg_color = Color(0.17, 0.22, 0.29, 1.0)
	_style_ctrl_hover.border_color = Color(0.34, 0.46, 0.60, 0.95)

	_style_ctrl_pressed = _style_ctrl_normal.duplicate() as StyleBoxFlat
	_style_ctrl_pressed.bg_color = Color(0.10, 0.14, 0.18, 1.0)
	_style_ctrl_pressed.border_color = Color(0.45, 0.62, 0.80, 1.0)

	_style_ctrl_active_teal = _style_ctrl_normal.duplicate() as StyleBoxFlat
	_style_ctrl_active_teal.bg_color = Color(0.11, 0.22, 0.27, 1.0)
	_style_ctrl_active_teal.border_color = Color(0.24, 0.62, 0.74, 0.92)

	_style_ctrl_active_amber = _style_ctrl_normal.duplicate() as StyleBoxFlat
	_style_ctrl_active_amber.bg_color = Color(0.26, 0.19, 0.11, 1.0)
	_style_ctrl_active_amber.border_color = Color(0.86, 0.62, 0.24, 0.95)

	_style_list_row_normal = StyleBoxFlat.new()
	_style_list_row_normal.bg_color = Color(0.12, 0.15, 0.20, 0.78)
	_style_list_row_normal.border_color = Color(0.19, 0.25, 0.33, 0.60)
	_style_list_row_normal.set_border_width_all(1)
	_style_list_row_normal.set_corner_radius_all(6)
	_style_list_row_normal.content_margin_left = 10
	_style_list_row_normal.content_margin_right = 10
	_style_list_row_normal.content_margin_top = 5
	_style_list_row_normal.content_margin_bottom = 5

	_style_list_row_selected = _style_list_row_normal.duplicate() as StyleBoxFlat
	_style_list_row_selected.bg_color = Color(0.22, 0.18, 0.12, 0.95)
	_style_list_row_selected.border_color = Color(0.88, 0.64, 0.24, 0.95)

	for ctrl in [
		taxon_selector, bone_selector, pins_toggle_button, quiz_mode_button,
		quality_button, reset_cam_button, toggle_sheet_button,
		quiz_restart_button, quiz_next_button, quiz_exit_button
	]:
		_apply_button_style(ctrl)

	# Estetik Evrensel Quiz Geri Bildirim Kartı Stilleri (◎ / ✔ / ×)
	_style_card_neutral = StyleBoxFlat.new()
	_style_card_neutral.bg_color = Color(0.12, 0.16, 0.22, 0.95)
	_style_card_neutral.border_color = Color(0.28, 0.42, 0.58, 0.85)
	_style_card_neutral.set_border_width_all(2)
	_style_card_neutral.set_corner_radius_all(10)

	_style_card_correct = StyleBoxFlat.new()
	_style_card_correct.bg_color = Color(0.08, 0.30, 0.19, 0.96)
	_style_card_correct.border_color = Color(0.24, 0.86, 0.52, 0.95)
	_style_card_correct.set_border_width_all(2)
	_style_card_correct.set_corner_radius_all(10)

	_style_card_wrong = StyleBoxFlat.new()
	_style_card_wrong.bg_color = Color(0.34, 0.10, 0.13, 0.96)
	_style_card_wrong.border_color = Color(0.92, 0.32, 0.36, 0.95)
	_style_card_wrong.set_border_width_all(2)
	_style_card_wrong.set_corner_radius_all(10)

	_style_card_complete = StyleBoxFlat.new()
	_style_card_complete.bg_color = Color(0.12, 0.25, 0.20, 0.98)
	_style_card_complete.border_color = Color(0.92, 0.74, 0.28, 0.95)
	_style_card_complete.set_border_width_all(2)
	_style_card_complete.set_corner_radius_all(10)
