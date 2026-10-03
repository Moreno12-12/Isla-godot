extends Node3D

const N := 161

var alturas := PackedFloat32Array()


func _ready() -> void:
	_generar_alturas()
	_construir_malla()
	_construir_colision()


func _generar_alturas() -> void:
	alturas.resize(N * N)

	var base := FastNoiseLite.new()
	base.seed = 20261002
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX
	base.fractal_type = FastNoiseLite.FRACTAL_FBM
	base.fractal_octaves = 5
	base.frequency = 0.019

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

	var lagunas: Array[Vector2] = [Vector2(-30, 21), Vector2(32, -19), Vector2(8, 40)]
	var medio := (N - 1) * 0.5

	for z in N:
		for x in N:
			var px := float(x) - medio
			var pz := float(z) - medio
			var d := Vector2(px, pz).length() / (medio * 0.92)
			var mascara := 1.0 - smoothstep(0.55, 1.0, d)
			var factor_mont := 1.0 - smoothstep(0.05, 0.75, d)
			var cresta := clampf((crestas.get_noise_2d(px, pz) + 1.0) * 0.5, 0.0, 1.0)
			var suave := (base.get_noise_2d(px, pz) + 1.0) * 0.5

			var h := mascara * 4.5 + mascara * factor_mont * cresta * 24.0
			h += mascara * (suave - 0.5) * 3.0
			h += mascara * detalle.get_noise_2d(px, pz) * 1.6
			h -= (1.0 - mascara) * 9.0

			for lg in lagunas:
				var g := exp(-Vector2(px, pz).distance_squared_to(lg) / 165.0)
				h = lerpf(h, -5.5, g)

			alturas[x + z * N] = clampf(h, -14.0, 34.0)


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
