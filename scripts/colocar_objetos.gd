extends Node3D

const NUM_ROCAS := 22

const CUOTA_PRINCIPAL: Dictionary = {
	"palmera": 100,
	"arbol": 90,
	"pino": 70,
	"arbusto": 110,
}
const CUOTA_ISLA: Dictionary = {
	"palmera": 10,
	"arbol": 8,
	"pino": 6,
	"arbusto": 12,
}
const TIPOS: Dictionary = {
	"palmera": {"h_min": 0.4, "h_max": 7.0, "ny": 0.72, "sep": 2.4},
	"arbol": {"h_min": 1.0, "h_max": 15.0, "ny": 0.6, "sep": 2.8},
	"pino": {"h_min": 7.0, "h_max": 40.0, "ny": 0.5, "sep": 2.6},
	"arbusto": {"h_min": 0.4, "h_max": 22.0, "ny": 0.45, "sep": 1.6},
}
const LAGUNAS: Array[Vector2] = [Vector2(-45, 31.5), Vector2(48, -28.5), Vector2(12, 60)]
const DIST_LAGUNA := 13.0
const MARGEN_CIUDAD := 8.0

const GRID_CELDA := 3.0

var _semilla := 987654321
var _zona := 107.0
var _grid := PackedByteArray()
var _grid_n := 0
var _grid_ext := 0.0
var _listas: Dictionary = {}
var _conteos: Dictionary = {}


func _ready() -> void:
	print("Objetos: _ready")
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("No se encontro el nodo Terreno")
		return
	call_deferred("_sembrar", terreno)


func _sembrar(terreno: Node) -> void:
	print("Objetos: _sembrar inicio")
	_zona = 76.0 * float(terreno.N) / 241.0
	_iniciar_grid(terreno)
	for tipo in TIPOS:
		_listas[tipo] = []
		_conteos[tipo] = 0
	_colocar_rocas(terreno)
	_marcas_cascada()

	for tipo in TIPOS:
		_sembrar_zona(terreno, tipo, TIPOS[tipo], CUOTA_PRINCIPAL[tipo])

	for k in terreno.ISLAS.size():
		var centro: Vector2 = terreno.ISLAS[k]
		var radio: float = terreno.ISLAS_RAD[k] * 0.92
		for tipo in TIPOS:
			var bandas := {
				"h_min": 0.35,
				"h_max": 10.0,
				"ny": 0.55,
				"sep": TIPOS[tipo]["sep"],
			}
			_sembrar_zona(terreno, tipo, bandas, CUOTA_ISLA[tipo], centro, radio)

	_crear_multimeshes()

	var total := 0
	for tipo in _conteos:
		total += int(_conteos[tipo])
	print("Vegetacion: ", _conteos, " total=", total,
			" grid=", _grid_n, "x", _grid_n)


func _sembrar_zona(terreno: Node, tipo: String, bandas: Dictionary,
		cuota: int, centro := Vector2.ZERO, radio := 0.0) -> int:
	var puestas := 0
	var intentos := 0
	while puestas < cuota and intentos < cuota * 250:
		intentos += 1
		var px: float
		var pz: float
		if radio > 0.0:
			var ang := _azar(0.0, TAU)
			var rr := sqrt(_azar(0.0, 1.0)) * radio
			px = centro.x + cos(ang) * rr
			pz = centro.y + sin(ang) * rr
		else:
			px = _azar(-_zona, _zona)
			pz = _azar(-_zona, _zona)
		if not _sitio_valido(terreno, px, pz, bandas):
			continue
		_plantar(tipo, px, terreno.altura_en(px, pz), pz)
		puestas += 1
	return puestas


func _sitio_valido(terreno: Node, px: float, pz: float, bandas: Dictionary) -> bool:
	var h: float = terreno.altura_en(px, pz)
	if h < float(bandas["h_min"]) or h > float(bandas["h_max"]):
		return false
	if terreno.en_zona_ciudad(px, pz, MARGEN_CIUDAD):
		return false
	for lg in LAGUNAS:
		if Vector2(px, pz).distance_to(lg) < DIST_LAGUNA:
			return false
	var n: Vector3 = terreno.normal_en(px, pz)
	if n.y < float(bandas["ny"]):
		return false
	if _grid_n > 0 and _ocupado(px, pz, float(bandas["sep"])):
		return false
	return true


func _plantar(tipo: String, px: float, h: float, pz: float) -> void:
	var esc := _azar(0.8, 1.3)
	var escy := _azar(0.75, 1.2)
	var rot := Vector3(_azar(-0.05, 0.05), _azar(0.0, TAU), _azar(-0.05, 0.05))
	var xf := Transform3D(
		Basis.from_euler(rot).scaled(Vector3(esc, esc * escy, esc)),
		Vector3(px, h - 0.15, pz))
	_listas[tipo].append(xf)
	_marcar(px, pz, float(TIPOS[tipo]["sep"]))
	_conteos[tipo] = int(_conteos.get(tipo, 0)) + 1


func _crear_multimeshes() -> void:
	for hijo in get_children():
		if hijo is MultiMeshInstance3D:
			hijo.free()
	var mallas := _mallas_plantilla()
	for tipo in _listas:
		var lista: Array = _listas[tipo]
		if lista.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mallas[tipo]
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Vegetacion_" + tipo
		mmi.multimesh = mm
		add_child(mmi)


func despejar_en(px: float, pz: float, semiancho: float, semiprofundo: float) -> int:
	var quitadas := 0
	for tipo in _listas:
		var lista: Array = _listas[tipo]
		var i := lista.size() - 1
		while i >= 0:
			var t: Transform3D = lista[i]
			if absf(t.origin.x - px) <= semiancho and absf(t.origin.z - pz) <= semiprofundo:
				lista.remove_at(i)
				_conteos[tipo] = int(_conteos[tipo]) - 1
				quitadas += 1
			i -= 1
	if quitadas > 0:
		_crear_multimeshes()
		print("Vegetacion despejada en (", snappedf(px, 0.1), ", ", snappedf(pz, 0.1),
				"): ", quitadas, " plantas | ", _conteos)
	return quitadas


func _mallas_plantilla() -> Dictionary:
	var mallas := {}
	mallas["palmera"] = _malla_palmera()
	mallas["arbol"] = _malla_arbol()
	mallas["pino"] = _malla_pino()
	mallas["arbusto"] = _malla_arbusto()
	for tipo in mallas:
		var m: ArrayMesh = mallas[tipo]
		var mats := PackedStringArray()
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			if mat == null:
				mats.append("null")
			else:
				mats.append(str((mat as StandardMaterial3D).albedo_color))
		print("Malla ", tipo, ": superficies=", m.get_surface_count(), " ", mats)
	return mallas


func _parte(partes: Array, mesh: Mesh, pos: Vector3,
		rot := Vector3.ZERO, esc := Vector3.ONE, mat: Material = null) -> void:
	partes.append([mesh, pos, rot, esc, mat])


func _fusionar(partes: Array) -> ArrayMesh:
	var orden: Array = []
	var buckets: Dictionary = {}
	for p in partes:
		var mesh: Mesh = p[0]
		var rot: Vector3 = p[2]
		var esc: Vector3 = p[3]
		var mat: Material = p[4]
		var basis := Basis.from_euler(rot).scaled(esc)
		var xf := Transform3D(basis, p[1])
		if not buckets.has(mat):
			buckets[mat] = {
				"pos": PackedVector3Array(),
				"norm": PackedVector3Array(),
				"uv": PackedVector2Array(),
				"idx": PackedInt32Array(),
			}
			orden.append(mat)
		var b: Dictionary = buckets[mat]
		var arrays := mesh.surface_get_arrays(0)
		var pos_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norm_v: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv_v: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx_v: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var base: int = (b["pos"] as PackedVector3Array).size()
		var norm_basis := basis.inverse().transposed()
		var bp: PackedVector3Array = b["pos"]
		for v in pos_v:
			bp.append(xf * v)
		var bn: PackedVector3Array = b["norm"]
		for n in norm_v:
			bn.append((norm_basis * n).normalized())
		var bu: PackedVector2Array = b["uv"]
		bu.append_array(uv_v)
		var bi: PackedInt32Array = b["idx"]
		for i in idx_v:
			bi.append(base + i)
		b["pos"] = bp
		b["norm"] = bn
		b["uv"] = bu
		b["idx"] = bi
	var am := ArrayMesh.new()
	for mat in orden:
		var b: Dictionary = buckets[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b["pos"]
		arrays[Mesh.ARRAY_NORMAL] = b["norm"]
		arrays[Mesh.ARRAY_TEX_UV] = b["uv"]
		arrays[Mesh.ARRAY_INDEX] = b["idx"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


func _malla_palmera() -> ArrayMesh:
	var partes: Array = []
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.14
	tronco.bottom_radius = 0.3
	tronco.height = 6.0
	tronco.radial_segments = 8
	_parte(partes, tronco, Vector3(0, 3, 0), Vector3.ZERO, Vector3.ONE, _mat_tronco())
	for i in 6:
		var caja := BoxMesh.new()
		caja.size = Vector3(0.35, 0.06, 2.6)
		var ang := TAU * float(i) / 6.0
		_parte(partes, caja, Vector3(sin(ang) * 1.2, 5.95, cos(ang) * 1.2),
			Vector3(0.4, ang, 0), Vector3.ONE, _mat_hoja())
	var coco := SphereMesh.new()
	coco.radius = 0.35
	coco.height = 0.5
	coco.radial_segments = 8
	coco.rings = 4
	_parte(partes, coco, Vector3(0, 6.15, 0), Vector3.ZERO, Vector3.ONE, _mat_hoja())
	return _fusionar(partes)


func _malla_arbol() -> ArrayMesh:
	var partes: Array = []
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.12
	tronco.bottom_radius = 0.28
	tronco.height = 2.4
	tronco.radial_segments = 8
	_parte(partes, tronco, Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, _mat_tronco())
	var copas := [
		[Vector3(0, 3.4, 0), 1.6],
		[Vector3(0.9, 3.0, 0.5), 1.1],
		[Vector3(-0.8, 3.2, -0.5), 1.0],
	]
	for c in copas:
		var esfera := SphereMesh.new()
		esfera.radius = float(c[1])
		esfera.height = float(c[1]) * 1.9
		esfera.radial_segments = 8
		esfera.rings = 5
		_parte(partes, esfera, c[0], Vector3.ZERO, Vector3(1, 0.85, 1), _mat_arbol())
	return _fusionar(partes)


func _malla_pino() -> ArrayMesh:
	var partes: Array = []
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.18
	tronco.bottom_radius = 0.3
	tronco.height = 1.4
	tronco.radial_segments = 8
	_parte(partes, tronco, Vector3(0, 0.7, 0), Vector3.ZERO, Vector3.ONE, _mat_tronco())
	var conos := [
		[2.4, 1.7, 2.6],
		[3.7, 1.3, 2.2],
		[4.9, 0.9, 1.8],
	]
	for c in conos:
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = float(c[1])
		cono.height = float(c[2])
		cono.radial_segments = 8
		_parte(partes, cono, Vector3(0, float(c[0]), 0), Vector3.ZERO, Vector3.ONE, _mat_pino())
	return _fusionar(partes)


func _malla_arbusto() -> ArrayMesh:
	var partes: Array = []
	var bultos := [
		[Vector3(0, 0.55, 0), 0.95, 0.8],
		[Vector3(0.6, 0.45, 0.35), 0.65, 0.8],
		[Vector3(-0.55, 0.42, -0.3), 0.6, 0.75],
	]
	for b in bultos:
		var esfera := SphereMesh.new()
		esfera.radius = float(b[1])
		esfera.height = float(b[1]) * 2.0
		esfera.radial_segments = 8
		esfera.rings = 5
		_parte(partes, esfera, b[0], Vector3.ZERO,
			Vector3(1, float(b[2]), 1), _mat_arbusto())
	return _fusionar(partes)


func _iniciar_grid(terreno: Node) -> void:
	_grid_ext = 115.0
	for k in terreno.ISLAS.size():
		var c: Vector2 = terreno.ISLAS[k]
		var r: float = terreno.ISLAS_RAD[k]
		_grid_ext = maxf(_grid_ext, maxf(absf(c.x), absf(c.y)) + r + 8.0)
	_grid_n = int(ceil(_grid_ext * 2.0 / GRID_CELDA)) + 1
	_grid = PackedByteArray()
	_grid.resize(_grid_n * _grid_n)


func _celda(v: float) -> int:
	return clampi(int(floor((v + _grid_ext) / GRID_CELDA)), 0, _grid_n - 1)


func _marcar(px: float, pz: float, radio: float) -> void:
	if _grid_n == 0:
		return
	var x0 := _celda(px - radio)
	var x1 := _celda(px + radio)
	var z0 := _celda(pz - radio)
	var z1 := _celda(pz + radio)
	for iz in range(z0, z1 + 1):
		var base := iz * _grid_n
		for ix in range(x0, x1 + 1):
			_grid[base + ix] = 1


func _ocupado(px: float, pz: float, radio: float) -> bool:
	if _grid_n == 0:
		return false
	var x0 := _celda(px - radio)
	var x1 := _celda(px + radio)
	var z0 := _celda(pz - radio)
	var z1 := _celda(pz + radio)
	for iz in range(z0, z1 + 1):
		var base := iz * _grid_n
		for ix in range(x0, x1 + 1):
			if _grid[base + ix] != 0:
				return true
	return false


func ocupado_en(px: float, pz: float, radio: float) -> bool:
	return _ocupado(px, pz, radio)


func _marcas_cascada() -> void:
	var cascada := get_node_or_null("../Cascada")
	if cascada == null:
		return
	var camino = cascada.get("camino")
	if camino == null:
		return
	for p in camino:
		_marcar(p.x, p.y, 8.5)


func _azar(min_v: float, max_v: float) -> float:
	_semilla = (1103515245 * _semilla + 12345) % 2147483648
	return min_v + (max_v - min_v) * (float(_semilla) / 2147483648.0)


func _colocar_rocas(terreno: Node) -> void:
	var puestas := 0
	var intentos := 0
	while puestas < NUM_ROCAS and intentos < NUM_ROCAS * 60:
		intentos += 1
		var px := _azar(-_zona, _zona)
		var pz := _azar(-_zona, _zona)
		var h: float = terreno.altura_en(px, pz)
		if h < 4.0:
			continue
		if terreno.en_zona_ciudad(px, pz):
			continue
		if _grid_n > 0 and _ocupado(px, pz, 2.0):
			continue
		var roca := _crear_roca(px, h, pz)
		roca.name = "Roca%d" % puestas
		add_child(roca)
		_marcar(px, pz, 1.8)
		puestas += 1
	print("Rocas colocadas: ", puestas, " (intentos: ", intentos, ")")


func _crear_roca(px: float, h: float, pz: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = Vector3(px, h - 0.3, pz)
	raiz.rotation.y = _azar(0.0, TAU)
	raiz.scale = Vector3(_azar(0.7, 1.6), _azar(0.5, 1.1), _azar(0.7, 1.6))

	var caja := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.0, 1.2)
	caja.mesh = bm
	caja.material_override = _mat_roca()
	caja.rotation = Vector3(_azar(-0.4, 0.4), 0.0, _azar(-0.4, 0.4))
	caja.position = Vector3(0, 0.3, 0)
	raiz.add_child(caja)
	return raiz


var _mat_tronco_cache: StandardMaterial3D
var _mat_hoja_cache: StandardMaterial3D
var _mat_roca_cache: StandardMaterial3D
var _mat_arbol_cache: StandardMaterial3D
var _mat_pino_cache: StandardMaterial3D
var _mat_arbusto_cache: StandardMaterial3D


func _mat_simple(color: Color, rug: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rug
	return m


func _mat_tronco() -> StandardMaterial3D:
	if _mat_tronco_cache == null:
		_mat_tronco_cache = _mat_simple(Color(0.42, 0.3, 0.18), 1.0)
	return _mat_tronco_cache


func _mat_hoja() -> StandardMaterial3D:
	if _mat_hoja_cache == null:
		_mat_hoja_cache = _mat_simple(Color(0.15, 0.45, 0.18), 0.9)
	return _mat_hoja_cache


func _mat_roca() -> StandardMaterial3D:
	if _mat_roca_cache == null:
		_mat_roca_cache = _mat_simple(Color(0.45, 0.43, 0.4), 1.0)
	return _mat_roca_cache


func _mat_arbol() -> StandardMaterial3D:
	if _mat_arbol_cache == null:
		_mat_arbol_cache = _mat_simple(Color(0.13, 0.5, 0.22), 0.9)
	return _mat_arbol_cache


func _mat_pino() -> StandardMaterial3D:
	if _mat_pino_cache == null:
		_mat_pino_cache = _mat_simple(Color(0.08, 0.32, 0.16), 0.9)
	return _mat_pino_cache


func _mat_arbusto() -> StandardMaterial3D:
	if _mat_arbusto_cache == null:
		_mat_arbusto_cache = _mat_simple(Color(0.2, 0.42, 0.14), 0.95)
	return _mat_arbusto_cache
