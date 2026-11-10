shader_type spatial;
render_mode unshaded, cull_back;

// "Potato-to-Flagship" MatCap + Albedo Texture Hibrit Bone Shader (gl_compatibility uyumlu).
// - Dokusu olmayan kemiklerde (use_albedo_texture = false) 256x256 prosedürel fildişi MatCap kullanır.
// - Dokulu kemiklerde (ör. horse_cranium.png, use_albedo_texture = true) modelin UV dokusunu
//   MatCap küresel aydınlatmasıyla birleştirerek sıfıra yakın GPU maliyetinde gerçekçi 3B derinlik üretir.

uniform sampler2D matcap_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform vec3 bone_tint : source_color = vec3(1.0, 0.99, 0.96);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec2 matcap_uv = clamp(n.xy * vec2(0.49, -0.49) + vec2(0.5), vec2(0.01), vec2(0.99));
	vec3 matcap_sample = texture(matcap_texture, matcap_uv).rgb;
	float fresnel = pow(1.0 - clamp(abs(n.z), 0.0, 1.0), 2.4) * rim_strength;

	if (use_albedo_texture) {
		vec3 tex_col = texture(albedo_texture, UV).rgb;
		vec3 lighting = mix(vec3(0.65), matcap_sample * 1.15, 0.72);
		ALBEDO = clamp(tex_col * lighting + vec3(fresnel * 0.45), vec3(0.0), vec3(1.0));
	} else {
		ALBEDO = clamp(matcap_sample * bone_tint + vec3(fresnel), vec3(0.0), vec3(1.0));
	}
}
