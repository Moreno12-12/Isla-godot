shader_type spatial;
render_mode cull_disabled;

varying vec2 v_uv;

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

void vertex() {
	v_uv = UV;
}

void fragment() {
	float across = v_uv.x;
	float along = v_uv.y;

	vec3 agua = vec3(0.22, 0.52, 0.75);
	vec3 agua_profunda = vec3(0.12, 0.35, 0.60);
	vec3 espuma = vec3(0.95, 0.98, 1.0);

	float flujo = along * 6.0 - TIME * 2.4;
	float rayas = fract(flujo + vnoise(vec2(across * 3.0, along * 8.0)) * 0.6);
	rayas = smoothstep(0.45, 0.55, rayas) * smoothstep(0.85, 0.65, rayas);

	float espuma_borde = smoothstep(0.32, 0.5, abs(across - 0.5));
	float espuma_alto = smoothstep(0.85, 1.0, fract(along * 0.35 - TIME * 0.8));

	vec3 col = mix(agua_profunda, agua, 0.5 + 0.5 * sin(along * 2.0 + TIME * 1.5));
	col = mix(col, espuma, rayas * 0.75);
	col = mix(col, espuma, espuma_borde * 0.6);
	col = mix(col, espuma, espuma_alto * 0.5);

	ALBEDO = col;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	EMISSION = col * 0.12;
}
