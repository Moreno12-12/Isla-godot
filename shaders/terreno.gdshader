shader_type spatial;
render_mode cull_disabled;

const float COSTA_NIVEL = -9.2;

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

	vec3 agua = vec3(0.01, 0.16, 0.38);
	vec3 hierba = vec3(0.22, 0.58, 0.12);
	vec3 hierba_clara = vec3(0.34, 0.70, 0.18);
	vec3 hierba_oscura = vec3(0.10, 0.42, 0.08);
	vec3 roca = vec3(0.46, 0.43, 0.39);
	vec3 roca_oscura = vec3(0.31, 0.29, 0.27);
	vec3 montana = vec3(0.52, 0.50, 0.47);
	vec3 nieve = vec3(0.95, 0.96, 0.98);

	if (h < COSTA_NIVEL) {
		ALBEDO = agua;
		ROUGHNESS = 0.15;
		SPECULAR = 0.6;
	}

	vec3 col = mix(hierba_oscura, hierba, vnoise(v_xz * 0.35));

	float parche = smoothstep(0.62, 0.74, vnoise(v_xz * 0.12));
	col = mix(col, hierba_clara, parche * 0.75 * (1.0 - smoothstep(13.0, 19.0, h)));

	float borde_mar = 1.0 - smoothstep(COSTA_NIVEL, COSTA_NIVEL + 2.7, h);
	col = mix(col, hierba_oscura * 0.7, borde_mar * 0.65);

	float rocoso = smoothstep(0.42, 0.62, pendiente);
	col = mix(col, mix(roca, roca_oscura, fract(h * 0.37)), rocoso);

	col = mix(col, montana, smoothstep(14.0, 20.0, h) * (1.0 - rocoso * 0.5));

	float nieve_f = smoothstep(20.0, 26.0, h);
	nieve_f = max(nieve_f, parche * smoothstep(26.0, 29.0, h));
	col = mix(col, nieve, nieve_f * (1.0 - rocoso * 0.7));

	float grano = fract(sin(dot(floor(v_xz * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.94 + grano * 0.12;

	float bajo_agua = float(h < COSTA_NIVEL);
	ALBEDO = mix(col, agua, bajo_agua);
	ROUGHNESS = mix(1.0, 0.15, bajo_agua);
	SPECULAR = mix(0.1, 0.6, bajo_agua);
}
