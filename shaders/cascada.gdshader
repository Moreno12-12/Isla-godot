shader_type spatial;
render_mode cull_disabled, blend_mix;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float across = UV.x;
	float along = UV.y;
	float caida = UV2.x;

	vec3 agua = vec3(0.22, 0.52, 0.75);
	vec3 agua_profunda = vec3(0.10, 0.33, 0.58);
	vec3 espuma = vec3(0.95, 0.98, 1.0);

	float o1 = vnoise(vec2(across * 5.0, along * 0.4 - TIME * 1.3));
	float o2 = vnoise(vec2(across * 9.0 + 17.0, along * 0.7 - TIME * 2.2));
	float oleaje = o1 * 0.6 + o2 * 0.4;

	float flujo = along * 0.5 - TIME * 1.7;
	float rayas = fract(flujo + oleaje * 0.8);
	rayas = smoothstep(0.4, 0.55, rayas) * smoothstep(0.9, 0.6, rayas);

	float espuma_borde = smoothstep(0.32, 0.5, abs(across - 0.5));
	float espuma_caida = caida * smoothstep(0.25, 0.7,
			fract(along * 0.8 - TIME * 2.4) + oleaje * 0.35);
	float espuma_caida_base = caida * 0.45;

	float onda = clamp(0.5 + 0.5 * sin(along * 0.4 + TIME * 1.5)
			+ (oleaje - 0.5) * 0.5, 0.0, 1.0);
	vec3 col = mix(agua_profunda, agua, onda);
	float blanqueo = clamp(rayas * 0.7 + espuma_borde * 0.55
			+ espuma_caida * 0.6 + espuma_caida_base, 0.0, 1.0);
	col = mix(col, espuma, blanqueo);

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.78, 0.88, 1.0), fres * 0.45);

	vec2 celda = floor(vec2(across * 30.0, along * 5.0));
	float destello = step(0.982, hash21(celda + floor(TIME * 2.0)));
	col += vec3(0.5) * destello;

	float borde_a = smoothstep(0.0, 0.16, min(across, 1.0 - across));
	float alpha = mix(0.4, 0.95, borde_a);
	alpha = max(alpha, caida);
	alpha = clamp(alpha + destello * 0.2, 0.0, 1.0);

	ALBEDO = col;
	ROUGHNESS = mix(0.1, 0.35, caida);
	SPECULAR = 0.6;
	EMISSION = col * (0.12 + destello * 0.5);
	ALPHA = alpha;
}
