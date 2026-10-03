extends Node3D

const N := 341
const ISLA_RADIO := 50.0
const ISLA_AMP := 18.0
const COSTA_NIVEL := -9.2
const RADIOS_ISLA: Array[float] = [50.0, 48.0, 46.0, 44.0, 42.0, 40.0, 38.0, 36.0]

var alturas := PackedFloat32Array()
var ISLAS: Array[Vector2] = []
var ISLAS_RAD: Array[float] = []


func _ready() -> void:
	_generar_alturas()
	_construir_malla()
	_construir_colision()


func _generar_alturas() -> void:
	alturas.resize(N * N)

	var base_ruido := FastNoiseLite.new()
	base_ruido.seed = 20261002
	base_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	base_ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_ruido.fractal_octaves = 5
	base_ruido.frequency = 0.019

	var crestas := FastNoiseLite.new()
	crestas.seed = 777
	crestas.noise_type = FastNoiseLite.TYPE_SIMPLEX
	crestas.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crestas.fractal_octaves = 4
	crestas.frequency = 0.026

	var detalle := FastNoiseLite.new()
	detalle.seed = 31
	detalle.noise_type = FastNoiseLite.TYPE_PERLIN
	detalle.frequency = 0.067

	var costa := FastNoiseLite.new()
	costa.seed = 505
	costa.noise_type = FastNoiseLite.TYPE_SIMPLEX
	costa.fractal_type = FastNoiseLite.FRACTAL_FBM
	costa.fractal_octaves = 4
	costa.frequency = 0.028

	var lagunas: Array[Vector2] = [Vector2(-45, 31.5), Vector2(48, -28.5), Vector2(12, 60)]
	var medio := (N - 1) * 0.5
	var base := PackedFloat32Array()
	base.resize(N * N)

	for z in N:
		for x in N:
			var px := float(x) - medio
			var pz := float(z) - medio
			var d := Vector2(px, pz).length() / (medio * 0.92)
			d *= 1.0 + 0.14 * costa.get_noise_2d(px, pz)
			var mascara := 1.0 - smoothstep(0.55, 1.0, d)
			var factor_mont := 1.0 - smoothstep(0.05, 0.75, d)
			var cresta := clampf((crestas.get_noise_2d(px, pz) + 1.0) * 0.5, 0.0, 1.0)
			var suave := (base_ruido.get_noise_2d(px, pz) + 1.0) * 0.5

			var h := mascara * 4.5 + mascara * factor_mont * cresta * 24.0
			h += mascara * (suave - 0.5) * 3.0
			h += mascara * detalle.get_noise_2d(px, pz) * 1.6
			h -= (1.0 - mascara) * 14.0

			for lg in lagunas:
				var g := exp(-Vector2(px, pz).distance_squared_to(lg) / 165.0)
				h = lerpf(h, -5.5, g)

			base[x + z * N] = h

	_elegir_islas(base)

	for z in N:
		for x in N:
			var px := float(x) - medio
			var pz := float(z) - medio
			var h := base[x + z * N]
			for k in ISLAS.size():
				var sig := ISLAS_RAD[k] * 0.35
				var d2 := Vector2(px, pz).distance_squared_to(ISLAS[k])
				h += ISLA_AMP * exp(-d2 / (2.0 * sig * sig))
			alturas[x + z * N] = clampf(h, -14.0, 34.0)


func _h_en(base: PackedFloat32Array, px: float, pz: float) -> float:
	var medio := (N - 1) * 0.5
	var ix := clampi(int(round(px + medio)), 0, N - 1)
	var iz := clampi(int(round(pz + medio)), 0, N - 1)
	return base[ix + iz * N]


func _costa_en(base: PackedFloat32Array, ang: float) -> float:
	var dx := cos(ang)
	var dz := sin(ang)
	var limite := float(medio_global()) - 2.0
	var r := 1.0
	while r < limite:
		if _h_en(base, dx * r, dz * r) < COSTA_NIVEL:
			var j := r + 1.0
			while j < limite + 1.0 and _h_en(base, dx * j, dz * j) < COSTA_NIVEL:
				j += 1.0
			if j - r >= 6.0:
				return r
			r = j
		else:
			r += 1.0
	return 100000.0


func medio_global() -> float:
	return (N - 1) * 0.5


func _elegir_islas(base: PackedFloat32Array) -> void:
	var candidatos := [
		[315.0, 300.0, 330.0, 290.0, 340.0],
		[210.0, 225.0, 195.0, 235.0, 200.0],
		[135.0, 150.0, 120.0, 160.0, 110.0],
	]
	var medio := medio_global()
	for candidatos_ang in candidatos:
		var colocado := false
		for radio in RADIOS_ISLA:
			for grados in candidatos_ang:
				var ang := deg_to_rad(float(grados))
				var costa_r := _costa_en(base, ang)
				if costa_r >= 100000.0:
					continue
				var r_centro := costa_r + 6.0 + radio
				var centro := Vector2(cos(ang) * r_centro, sin(ang) * r_centro)
				var max_centro := medio - 0.5 - 0.57 * radio
				if absf(centro.x) > max_centro or absf(centro.y) > max_centro:
					continue
				if absf(centro.x) < 40.0 and centro.y > 75.0:
					continue
				var choca := false
				for c in ISLAS:
					if c.distance_to(centro) < radio * 2.0 + 30.0:
						choca = true
						break
				if choca:
					continue
				ISLAS.append(centro)
				ISLAS_RAD.append(radio)
				print("Isla ", ISLAS.size(), " en (", snappedf(centro.x, 0.1), ", ",
						snappedf(centro.y, 0.1), ") costa_r=", snappedf(costa_r, 0.1),
						" radio=", radio)
				colocado = true
				break
			if colocado:
				break
	print("Islas totales: ", ISLAS.size())


func altura_en(px: float, pz: float) -> float:
	var medio := (N - 1) * 0.5
	var ix := clampi(int(round(px + medio)), 0, N - 1)
	var iz := clampi(int(round(pz + medio)), 0, N - 1)
	return alturas[ix + iz * N]


func normal_en(px: float, pz: float) -> Vector3:
	var hx0 := altura_en(px - 1.0, pz)
	var hx1 := altura_en(px + 1.0, pz)
	var hz0 := altura_en(px, pz - 1.0)
	var hz1 := altura_en(px, pz + 1.0)
	return Vector3(hx0 - hx1, 2.0, hz0 - hz1).normalized()


func _construir_malla() -> void:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(N * N)
	normales.resize(N * N)
	indices.resize((N - 1) * (N - 1) * 6)

	var medio := (N - 1) * 0.5
	for z in N:
		for x in N:
			var i := x + z * N
			var px := float(x) - medio
			var pz := float(z) - medio
			vertices[i] = Vector3(px, alturas[i], pz)
			normales[i] = normal_en(px, pz)

	var k := 0
	for z in N - 1:
		for x in N - 1:
			var a := x + z * N
			var b := x + 1 + z * N
			var c := x + (z + 1) * N
			var d := x + 1 + (z + 1) * N
			indices[k] = a
			indices[k + 1] = c
			indices[k + 2] = b
			indices[k + 3] = b
			indices[k + 4] = c
			indices[k + 5] = d
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_INDEX] = indices

	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terreno.gdshader")

	var mi := MeshInstance3D.new()
	mi.name = "MallaTerreno"
	mi.mesh = malla
	mi.material_override = mat
	add_child(mi)


func _construir_colision() -> void:
	var forma := HeightMapShape3D.new()
	forma.map_width = N
	forma.map_depth = N
	forma.map_data = alturas

	var cs := CollisionShape3D.new()
	cs.name = "ColisionTerreno"
	cs.shape = forma

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Suelo"
	cuerpo.add_child(cs)
	add_child(cuerpo)
