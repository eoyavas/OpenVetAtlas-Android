class_name MatCapGenerator
extends RefCounted
## MatCapGenerator — Prosedürel 256x256 Kemik/Fildişi (Ivory) MatCap ve Dokulu Kemik Materyali Üreticisi.
##
## - Dokusu olmayan kemikler için 256x256 prosedürel fildişi MatCap materyali döndürür.
## - Harici dokusu olan kemikler (ör. horse_cranium.png) için Albedo + MatCap hibrit
##   ShaderMaterial oluşturur.

const MATCAP_SHADER_PATH: String = "res://Assets/materials/bone_matcap.gdshader"
const TEXTURE_SIZE: int = 256

static var _cached_texture: ImageTexture = null
static var _cached_material: ShaderMaterial = null


static func get_or_create_bone_material(custom_albedo_tex: Texture2D = null) -> ShaderMaterial:
	var shader: Shader = load(MATCAP_SHADER_PATH) as Shader
	var matcap_tex: ImageTexture = get_or_create_ivory_matcap_texture()

	if custom_albedo_tex != null:
		var textured_mat := ShaderMaterial.new()
		textured_mat.shader = shader
		textured_mat.set_shader_parameter("matcap_texture", matcap_tex)
		textured_mat.set_shader_parameter("albedo_texture", custom_albedo_tex)
		textured_mat.set_shader_parameter("use_albedo_texture", true)
		textured_mat.set_shader_parameter("bone_tint", Color(1.0, 1.0, 1.0))
		textured_mat.set_shader_parameter("rim_strength", 0.16)
		return textured_mat

	if _cached_material != null:
		return _cached_material

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("matcap_texture", matcap_tex)
	mat.set_shader_parameter("use_albedo_texture", false)
	mat.set_shader_parameter("bone_tint", Color(1.0, 0.99, 0.96))
	mat.set_shader_parameter("rim_strength", 0.22)
	_cached_material = mat
	return _cached_material


static func get_or_create_ivory_matcap_texture() -> ImageTexture:
	if _cached_texture != null:
		return _cached_texture

	var img: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var key_dir: Vector3 = Vector3(0.36, 0.54, 0.76).normalized()
	var fill_dir: Vector3 = Vector3(-0.48, -0.28, 0.52).normalized()
	var half_vec: Vector3 = (key_dir + Vector3(0.0, 0.0, 1.0)).normalized()

	var shadow_col := Color(0.45, 0.40, 0.34, 1.0)
	var mid_ivory := Color(0.86, 0.81, 0.72, 1.0)
	var warm_ivory := Color(0.96, 0.93, 0.86, 1.0)
	var spec_col := Color(1.0, 0.99, 0.95, 1.0)

	var inv_half: float = 2.0 / float(TEXTURE_SIZE - 1)

	for y in range(TEXTURE_SIZE):
		var ny: float = 1.0 - float(y) * inv_half
		for x in range(TEXTURE_SIZE):
			var nx: float = float(x) * inv_half - 1.0
			var r2: float = nx * nx + ny * ny
			var n: Vector3
			if r2 <= 1.0:
				n = Vector3(nx, ny, sqrt(maxf(0.0, 1.0 - r2))).normalized()
			else:
				var edge_xy: Vector2 = Vector2(nx, ny).normalized()
				n = Vector3(edge_xy.x, edge_xy.y, 0.0)

			var key_dot: float = clampf(n.dot(key_dir) * 0.5 + 0.5, 0.0, 1.0)
			var fill_dot: float = clampf(n.dot(fill_dir) * 0.5 + 0.5, 0.0, 1.0) * 0.24
			var shade_t: float = clampf(pow(key_dot, 1.22) + fill_dot, 0.0, 1.0)

			var base_col: Color
			if shade_t < 0.55:
				base_col = shadow_col.lerp(mid_ivory, shade_t / 0.55)
			else:
				base_col = mid_ivory.lerp(warm_ivory, (shade_t - 0.55) / 0.45)

			var spec: float = pow(clampf(n.dot(half_vec), 0.0, 1.0), 24.0) * 0.22
			var cavity_ao: float = clampf(0.78 + 0.22 * n.z, 0.72, 1.0)

			var final_r: float = clampf(base_col.r * cavity_ao + spec_col.r * spec, 0.0, 1.0)
			var final_g: float = clampf(base_col.g * cavity_ao + spec_col.g * spec, 0.0, 1.0)
			var final_b: float = clampf(base_col.b * cavity_ao + spec_col.b * spec, 0.0, 1.0)

			img.set_pixel(x, y, Color(final_r, final_g, final_b, 1.0))

	_cached_texture = ImageTexture.create_from_image(img)
	return _cached_texture
