shader_type spatial;
render_mode cull_disabled;

varying float v_altura;
varying vec3 v_normal;
varying vec2 v_xz;

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
	v_altura = VERTEX.y;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_xz = VERTEX.xz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float pendiente = 1.0 - clamp(v_normal.y, 0.0, 1.0);
	float h = v_altura;

	vec3 hierba = vec3(0.26, 0.56, 0.20);
	vec3 hierba_oscura = vec3(0.16, 0.43, 0.15);
	vec3 tierra = vec3(0.45, 0.33, 0.20);
	vec3 roca = vec3(0.46, 0.43, 0.39);
	vec3 roca_oscura = vec3(0.31, 0.29, 0.27);
	vec3 montana = vec3(0.52, 0.50, 0.47);
	vec3 nieve = vec3(0.95, 0.96, 0.98);

	vec3 col = mix(hierba_oscura, hierba, vnoise(v_xz * 0.35));

	col = mix(tierra, col, smoothstep(-5.0, 0.5, h));

	float parche = smoothstep(0.62, 0.74, vnoise(v_xz * 0.12));
	col = mix(col, tierra, parche * 0.85 * (1.0 - smoothstep(13.0, 19.0, h)));

	float rocoso = smoothstep(0.30, 0.55, pendiente);
	col = mix(col, mix(roca, roca_oscura, fract(h * 0.37)), rocoso);

	col = mix(col, montana, smoothstep(12.0, 18.0, h) * (1.0 - rocoso * 0.5));

	float nieve_f = smoothstep(18.0, 24.0, h);
	nieve_f = max(nieve_f, parche * smoothstep(24.0, 27.0, h));
	col = mix(col, nieve, nieve_f * (1.0 - rocoso * 0.7));

	float grano = fract(sin(dot(floor(v_xz * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.94 + grano * 0.12;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
