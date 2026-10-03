extends Node3D

const PASO := 1.5
const ANCHO_INICIO := 12.0
const ANCHO_FIN := 18.0
const ELEVACION := 0.35
const BORDE := 120.0
const MARGEN := 4.0
const PESO_SUBIR := 2.5
const PESO_CIUDAD := 4.0
const UMBRAL_CAIDA := -1.0
const RESALTO := 0.8
const BULGE := 2.0


var _heap_c := PackedFloat32Array()
var _heap_x := PackedInt32Array()
var _heap_z := PackedInt32Array()

var camino: Array[Vector2] = []


func _ready() -> void:
	var terreno := get_parent().get_node_or_null("Terreno")
	if terreno == null:
		push_error("Cascada: no encuentra Terreno")
		return
	if terreno.alturas.is_empty():
		push_error("Cascada: alturas vacias")
		return

	var pico := _buscar_pico(terreno)
	camino = _ruta(terreno, pico)
	if camino.size() < 2:
		push_error("Cascada: ruta demasiado corta (%d)" % camino.size())
		return
	_construir_cinta(terreno, camino)
	var dmin := 9999.0
	for p in camino:
		dmin = minf(dmin, p.distance_to(terreno.CIUDAD_CENTRO))
	print("Cascada: pico=", pico, " final=", camino[camino.size() - 1],
			" puntos=", camino.size(), " alt_pico=", terreno.altura_en(pico.x, pico.y),
			" dist_ciudad=", snappedf(dmin, 0.1))


func _buscar_pico(terreno: Node3D) -> Vector2:
	var N: int = terreno.N
	var medio: float = (N - 1) * 0.5
	var mejor := Vector2.ZERO
	var mejor_h := -INF
	for z in N:
		for x in N:
			var px: float = float(x) - medio
			var pz: float = float(z) - medio
			if absf(px) > medio - MARGEN or absf(pz) > medio - MARGEN:
				continue
			var h: float = terreno.alturas[x + z * N]
			if h > mejor_h:
				mejor_h = h
				mejor = Vector2(px, pz)
	return mejor


func _heap_push(c: float, x: int, z: int) -> void:
	var i := _heap_c.size()
	_heap_c.append(c)
	_heap_x.append(x)
	_heap_z.append(z)
	while i > 0:
		var p := (i - 1) >> 1
		if _heap_c[p] <= _heap_c[i]:
			break
		_heap_swap(i, p)
		i = p


func _heap_swap(a: int, b: int) -> void:
	var c := _heap_c[a]
	_heap_c[a] = _heap_c[b]
	_heap_c[b] = c
	var x := _heap_x[a]
	_heap_x[a] = _heap_x[b]
	_heap_x[b] = x
	var z := _heap_z[a]
	_heap_z[a] = _heap_z[b]
	_heap_z[b] = z


func _heap_pop() -> Array:
	var res := [_heap_c[0], _heap_x[0], _heap_z[0]]
	var last := _heap_c.size() - 1
	_heap_c[0] = _heap_c[last]
	_heap_x[0] = _heap_x[last]
	_heap_z[0] = _heap_z[last]
	_heap_c.resize(last)
	_heap_x.resize(last)
	_heap_z.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < _heap_c.size() and _heap_c[l] < _heap_c[m]:
			m = l
		if r < _heap_c.size() and _heap_c[r] < _heap_c[m]:
			m = r
		if m == i:
			break
		_heap_swap(i, m)
		i = m
	return res


func _ruta(terreno: Node3D, pico: Vector2) -> Array[Vector2]:
	var N: int = terreno.N
	var medio: float = (N - 1) * 0.5
	var ix0 := int(round(pico.x + medio))
	var iz0 := int(round(pico.y + medio))

	var dist := PackedFloat32Array()
	dist.resize(N * N)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(N * N)
	prev.fill(-1)

	_heap_c.clear()
	_heap_x.clear()
	_heap_z.clear()
	dist[ix0 + iz0 * N] = 0.0
	_heap_push(0.0, ix0, iz0)

	var vecinos := [
		[1, 0, 1.0], [-1, 0, 1.0], [0, 1, 1.0], [0, -1, 1.0],
		[1, 1, 1.41421], [1, -1, 1.41421], [-1, 1, 1.41421], [-1, -1, 1.41421],
	]
	var objetivo := -1
	var max_iter := N * N * 4
	var iter := 0
	while _heap_c.size() > 0 and iter < max_iter:
		iter += 1
		var top := _heap_pop()
		var c: float = top[0]
		var x: int = top[1]
		var z: int = top[2]
		var idx := x + z * N
		if c > dist[idx]:
			continue
		if x <= 0 or x >= N - 1 or z <= 0 or z >= N - 1:
			objetivo = idx
			break
		var h: float = terreno.alturas[idx]
		for nv in vecinos:
			var nx: int = x + int(nv[0])
			var nz: int = z + int(nv[1])
			var nidx := nx + nz * N
			var h2: float = terreno.alturas[nidx]
			var ec: float = float(nv[2]) + maxf(0.0, h2 - h) * PESO_SUBIR
			# la cascada evita la meseta de la ciudad
			if terreno.en_zona_ciudad(float(nx) - medio, float(nz) - medio, 8.0):
				ec += PESO_CIUDAD
			var nc := c + ec
			if nc < dist[nidx]:
				dist[nidx] = nc
				prev[nidx] = idx
				_heap_push(nc, nx, nz)

	if objetivo < 0:
		return []

	var puntos: Array[Vector2] = []
	var cur := objetivo
	while cur != -1:
		var x := cur % N
		var z := cur / N
		puntos.append(Vector2(float(x) - medio, float(z) - medio))
		cur = prev[cur]
	puntos.reverse()
	return puntos


func _construir_cinta(terreno: Node3D, camino: Array[Vector2]) -> void:
	var n := camino.size()
	var centro_3d := PackedVector3Array()
	var flags := PackedByteArray()
	var pozas := []
	var caidas := 0

	var h0: float = terreno.altura_en(camino[0].x, camino[0].y)
	centro_3d.append(Vector3(camino[0].x, h0 + ELEVACION, camino[0].y))
	flags.append(0)

	for i in range(1, n):
		var p0: Vector2 = camino[i - 1]
		var p1: Vector2 = camino[i]
		var h_a: float = terreno.altura_en(p0.x, p0.y)
		var h_b: float = terreno.altura_en(p1.x, p1.y)
		var d: float = p0.distance_to(p1)
		var pend: float = (h_b - h_a) / d
		if pend < UMBRAL_CAIDA and (h_a - h_b) > 2.0:
			caidas += 1
			var tang2 := (p1 - p0).normalized()
			var pasos := clampi(int(ceil((h_a - h_b) / 2.0)), 3, 10)
			for k in range(1, pasos + 1):
				var u := float(k) / float(pasos)
				var adelanto := RESALTO * (1.0 - u) + BULGE * sin(u * PI)
				var pos2 := p0.lerp(p1, u) + tang2 * adelanto
				var y := lerpf(h_a, h_b, u) + ELEVACION
				centro_3d.append(Vector3(pos2.x, y, pos2.y))
				flags.append(1)
			var drop := h_a - h_b
			var radio := clampf(6.0 + drop * 0.4, 6.0, 14.0)
			pozas.append([Vector3(p1.x, h_b + 0.15, p1.y), radio, drop])
		else:
			centro_3d.append(Vector3(p1.x, h_b + ELEVACION, p1.y))
			flags.append(0)

	var m := centro_3d.size()
	var verts := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var dist := 0.0

	for i in m:
		var a3: Vector3 = centro_3d[maxi(i - 1, 0)]
		var b3: Vector3 = centro_3d[mini(i + 1, m - 1)]
		var t3 := b3 - a3
		var th := Vector2(t3.x, t3.z)
		if th != Vector2.ZERO:
			th = th.normalized()
		var perp := Vector2(-th.y, th.x)
		var f := float(i) / float(maxi(m - 1, 1))
		var ancho := lerpf(ANCHO_INICIO, ANCHO_FIN, f) * 0.5
		if i > 0:
			dist += centro_3d[i].distance_to(centro_3d[i - 1])
		var centro: Vector3 = centro_3d[i]
		var lado := Vector3(perp.x, 0.0, perp.y) * ancho
		verts.append(centro + lado)
		verts.append(centro - lado)
		var nrm: Vector3
		if flags[i] == 1:
			nrm = Vector3(th.x, 0.0, th.y)
		else:
			nrm = terreno.normal_en(centro.x, centro.z)
		normales.append(nrm)
		normales.append(nrm)
		uvs.append(Vector2(0.0, dist))
		uvs.append(Vector2(1.0, dist))
		var marca := Vector2(float(flags[i]), 0.0)
		uvs2.append(marca)
		uvs2.append(marca)

	for i in m - 1:
		var a := i * 2
		idx.append(a)
		idx.append(a + 1)
		idx.append(a + 2)
		idx.append(a + 2)
		idx.append(a + 1)
		idx.append(a + 3)

	for entrada in pozas:
		_agregar_poza(verts, normales, uvs, uvs2, idx, entrada[0], entrada[1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = idx

	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cascada.gdshader")

	var mi := MeshInstance3D.new()
	mi.name = "MallaCascada"
	mi.mesh = malla
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	for entrada in pozas:
		var pos: Vector3 = entrada[0]
		add_child(_hacer_particulas(pos + Vector3(0, 0.4, 0), true))
		add_child(_hacer_particulas(pos + Vector3(0, 0.8, 0), false))

	var lista := ""
	for entrada in pozas:
		lista += str(entrada[0]) + " drop=" + str(entrada[2]) + " | "
	print("Cascada geom: caidas=", caidas, " pozas=", pozas.size(), " pts3d=", m, " en ", lista)


func _agregar_poza(verts: PackedVector3Array, normales: PackedVector3Array,
		uvs: PackedVector2Array, uvs2: PackedVector2Array,
		idx: PackedInt32Array, pos: Vector3, radio: float) -> void:
	var segs := 20
	var centro_i := verts.size()
	verts.append(pos)
	normales.append(Vector3.UP)
	uvs.append(Vector2(0.0, 0.14))
	uvs2.append(Vector2.ZERO)
	for s in segs:
		var ang := TAU * float(s) / float(segs)
		var dir := Vector2(cos(ang), sin(ang))
		verts.append(pos + Vector3(dir.x, 0.0, dir.y) * radio)
		normales.append(Vector3.UP)
		uvs.append(Vector2(1.0, 0.14))
		uvs2.append(Vector2.ZERO)
	for s in segs:
		var sig := (s + 1) % segs
		idx.append(centro_i)
		idx.append(centro_i + 1 + s)
		idx.append(centro_i + 1 + sig)


func _hacer_particulas(pos: Vector3, salpicadura: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 30, 24))
	var proc := ParticleProcessMaterial.new()
	var grad := Gradient.new()
	var tam := 0.5
	if salpicadura:
		p.name = "Salpicadura"
		p.amount = 120
		p.lifetime = 0.9
		p.explosiveness = 0.25
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 1.4
		proc.direction = Vector3(0, 1, 0)
		proc.spread = 55.0
		proc.initial_velocity_min = 5.0
		proc.initial_velocity_max = 11.0
		proc.gravity = Vector3(0, -11, 0)
		proc.scale_min = 0.15
		proc.scale_max = 0.45
		grad.set_color(0, Color(1, 1, 1, 0.95))
		grad.set_color(1, Color(1, 1, 1, 0.0))
	else:
		p.name = "Niebla"
		p.amount = 30
		p.lifetime = 4.0
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 2.5
		proc.direction = Vector3(0, 1, 0)
		proc.spread = 35.0
		proc.initial_velocity_min = 0.5
		proc.initial_velocity_max = 1.6
		proc.gravity = Vector3(0, 0.3, 0)
		proc.scale_min = 1.5
		proc.scale_max = 3.2
		grad.set_color(0, Color(1, 1, 1, 0.3))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		tam = 3.5
	proc.color_ramp = _gradiente_textura(grad)
	p.process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(tam, tam)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func _gradiente_textura(grad: Gradient) -> GradientTexture1D:
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex
