extends SceneTree
## OVA Kurumsal Logo, Splash ve Android İkon Üretici Betiği
## Kullanım:
##   .\Godot_v4.7.2-stable_win64_console.exe --headless --quit -s res://scripts/generate_branding_assets.gd

const SOURCE_JPG: String = "res://.tmp/source_logo.jpg"
const OUT_DIR: String = "res://Assets/branding"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var src_img := Image.new()
	var err: Error = src_img.load(ProjectSettings.globalize_path(SOURCE_JPG))
	if err != OK:
		push_error("[generate_branding_assets] Kaynak görsel yüklenemedi: " + SOURCE_JPG)
		quit(1)
		return

	src_img.convert(Image.FORMAT_RGBA8)

	var w: int = src_img.get_width()
	var h: int = src_img.get_height()
	var bg_color: Color = src_img.get_pixel(10, 10)

	# 1. Boot Splash (ova_splash.png)
	src_img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/ova_splash.png"))

	# 2. Üst Bar Logosu (ova_header_logo.png) - "OVA" amblemini kırp ve arka planı yumuşak şeffaflaştır
	var crop_rect := Rect2i(int(w * 0.24), int(h * 0.30), int(w * 0.50), int(h * 0.38))
	var header_raw: Image = src_img.get_region(crop_rect)
	header_raw.convert(Image.FORMAT_RGBA8)
	for y in range(header_raw.get_height()):
		for x in range(header_raw.get_width()):
			var c: Color = header_raw.get_pixel(x, y)
			var dist: float = Vector3(c.r - bg_color.r, c.g - bg_color.g, c.b - bg_color.b).length()
			if dist < 0.045:
				header_raw.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			elif dist < 0.11:
				var alpha: float = clampf((dist - 0.045) / (0.11 - 0.045), 0.0, 1.0)
				header_raw.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	header_raw.resize(196, 84, Image.INTERPOLATE_LANCZOS)
	header_raw.save_png(ProjectSettings.globalize_path(OUT_DIR + "/ova_header_logo.png"))

	# 3. Kare Uygulama İkonu (icon_512.png & icon_192.png) ve Android Adaptive İkonlar (432x432)
	var logo_full_crop := Rect2i(int(w * 0.21), int(h * 0.26), int(w * 0.58), int(h * 0.50))
	var emblem: Image = src_img.get_region(logo_full_crop)

	var icon_432_bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	icon_432_bg.fill(bg_color)
	icon_432_bg.save_png(ProjectSettings.globalize_path(OUT_DIR + "/icon_432_bg.png"))

	var icon_432_fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	icon_432_fg.fill(bg_color)
	var scaled_emblem: Image = emblem.duplicate() as Image
	var target_w: int = 290
	var target_h: int = int(float(emblem.get_height()) * (float(target_w) / float(emblem.get_width())))
	scaled_emblem.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	var dst_pos := Vector2i((432 - target_w) / 2, (432 - target_h) / 2)
	icon_432_fg.blit_rect(scaled_emblem, Rect2i(0, 0, target_w, target_h), dst_pos)
	icon_432_fg.save_png(ProjectSettings.globalize_path(OUT_DIR + "/icon_432_fg.png"))

	var icon_192: Image = icon_432_fg.duplicate() as Image
	var scaled_192: Image = emblem.duplicate() as Image
	var w192: int = 166
	var h192: int = int(float(emblem.get_height()) * (float(w192) / float(emblem.get_width())))
	scaled_192.resize(w192, h192, Image.INTERPOLATE_LANCZOS)
	icon_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	icon_192.fill(bg_color)
	icon_192.blit_rect(scaled_192, Rect2i(0, 0, w192, h192), Vector2i((192 - w192) / 2, (192 - h192) / 2))
	icon_192.save_png(ProjectSettings.globalize_path(OUT_DIR + "/icon_192.png"))

	print("[generate_branding_assets] OVA logo, splash ve ikon dosyaları üretildi: ", OUT_DIR)
	quit(0)
