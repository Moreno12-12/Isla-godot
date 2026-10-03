extends Node3D

const PASO := 1.5
const ANCHO_INICIO := 12.0
const ANCHO_FIN := 18.0
const ELEVACION := 0.35
const BORDE := 120.0
const MARGEN := 4.0
const PESO_SUBIR := 2.5


var _heap_c := PackedFloat32Array()
var _heap_x := PackedInt32Array()
var _heap_z := PackedInt32Array()


func _ready() -> void:
	var terreno := get_parent().get_node_or_null("Terreno")
	if terreno == null:
		push_error("Cascada: no encuentra Terreno")
		return
	if terreno.alturas.is_empty():
		push_error("Cascada: alturas vacias")
		return

	var pico := _buscar_pico(terreno)
	var camino := _ruta(terreno, pico)
	if camino.size() < 2:
		push_error("Cascada: ruta demasiado corta (%d)" % camino.size())
		return
	_construir_cinta(terreno, camino)
	print("Cascada: pico=", pico, " final=", camino[camino.size() - 1],
			" puntos=", camino.size(), " alt_pico=", terreno.altura_en(pico.x, pico.y))


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
	var verts := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	var tang := Vector2.RIGHT

	for i in n:
		var p := camino[i]
		var a := camino[maxi(i - 1, 0)]
		var b := camino[mini(i + 1, n - 1)]
		var t := b - a
		if t != Vector2.ZERO:
			tang = t.normalized()
		var perp := Vector2(-tang.y, tang.x)
		var f := float(i) / float(maxi(n - 1, 1))
		var ancho := lerpf(ANCHO_INICIO, ANCHO_FIN, f) * 0.5
		if i > 0:
			dist += p.distance_to(camino[i - 1])
		var h: float = terreno.altura_en(p.x, p.y)
		var centro := Vector3(p.x, h + ELEVACION, p.y)
		var lado := Vector3(perp.x, 0.0, perp.y) * ancho
		verts.append(centro + lado)
		verts.append(centro - lado)
		var nrm: Vector3 = terreno.normal_en(p.x, p.y)
		normales.append(nrm)
		normales.append(nrm)
		uvs.append(Vector2(0.0, dist))
		uvs.append(Vector2(1.0, dist))

	for i in n - 1:
		var a := i * 2
		idx.append(a)
		idx.append(a + 1)
		idx.append(a + 2)
		idx.append(a + 2)
		idx.append(a + 1)
		idx.append(a + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
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
