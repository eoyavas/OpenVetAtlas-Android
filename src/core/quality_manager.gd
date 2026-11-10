extends Node
## QualityManager — "Potato-to-Flagship" dinamik kalite ve pil tasarrufu yöneticisi.
##
## Düşük seviye ("potato") Android telefon/tabletler ile amiral gemisi cihazlar
## arasında 3B çözünürlük ölçeği (scaling_3d_scale), MSAA ve düşük işlemci kullanım
## modunu (On-Demand Rendering) yönetir.

enum QualityTier {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2
}

signal quality_tier_changed(new_tier: QualityTier)

var current_tier: QualityTier = QualityTier.LOW


func _ready() -> void:
	# Pil tasarrufu: Dokunma veya kamera hareketi yokken GPU kullanımını ~%0'a düşür.
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	_detect_and_apply_initial_tier()


func _detect_and_apply_initial_tier() -> void:
	var adapter_name: String = RenderingServer.get_video_adapter_name().to_lower()
	# Giriş seviyesi / eski mobil GPU sezgisel tespiti; şüphe durumunda güvenli taban LOW/MEDIUM seçilir.
	if adapter_name.contains("mali-4") or adapter_name.contains("mali-t") or adapter_name.contains("adreno (tm) 3") or adapter_name.contains("adreno (tm) 4") or adapter_name.contains("powervr"):
		apply_quality_tier(QualityTier.LOW)
	elif OS.has_feature("mobile") or OS.has_feature("android"):
		apply_quality_tier(QualityTier.MEDIUM)
	else:
		apply_quality_tier(QualityTier.HIGH)


func apply_quality_tier(tier: QualityTier) -> void:
	current_tier = tier
	var root_vp: Viewport = get_viewport()
	if root_vp == null:
		return

	match tier:
		QualityTier.LOW:
			root_vp.scaling_3d_scale = 0.75
			root_vp.msaa_3d = Viewport.MSAA_DISABLED
		QualityTier.MEDIUM:
			root_vp.scaling_3d_scale = 0.90
			root_vp.msaa_3d = Viewport.MSAA_2X
		QualityTier.HIGH:
			root_vp.scaling_3d_scale = 1.0
			root_vp.msaa_3d = Viewport.MSAA_4X

	quality_tier_changed.emit(current_tier)
