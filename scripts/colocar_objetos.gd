extends Node3D

const NUM_PALMERAS := 36
const NUM_ROCAS := 22

var _semilla := 987654321


func _ready() -> void:
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("No se encontrÃ³ el nodo Terreno")
		return
	_colocar_palmeras(terreno)
	_colocar_rocas(terreno)
	_poblar_islas(terreno)


func _poblar_islas(terreno: Node) -> void:
	var total := 0
	for k in terreno.ISLAS.size():
		var centro: Vector2 = terreno.ISLAS[k]
		var rad: float = terreno.ISLAS_RAD[k]
		var puestas := 0
		var intentos := 0
		while puestas < 4 and intentos < 300:
			intentos += 1
			var ang := _azar(0.0, TAU)
			var rr := sqrt(_azar(0.0, 1.0)) * rad * 0.35
			var px: float = centro.x + cos(ang) * rr
			var pz: float = centro.y + sin(ang) * rr
			var h: float = terreno.altura_en(px, pz)
			if h < 0.6 or h > 8.0:
				continue
			var n: Vector3 = terreno.normal_en(px, pz)
			if n.y < 0.65:
				continue
			var palmera := _crear_palmera(px, h, pz)
			palmera.name = "PalmeraIsl%d_%d" % [k, puestas]
			add_child(palmera)
			puestas += 1
		total += puestas
	print("Palmeras en islas: ", total, "/", terreno.ISLAS.size() * 4)


func _azar(min_v: float, max_v: float) -> float:
	_semilla = (1103515245 * _semilla + 12345) % 2147483648
	return min_v + (max_v - min_v) * (float(_semilla) / 2147483648.0)


func _colocar_palmeras(terreno: Node) -> void:
	var zona: float = 76.0 * float(terreno.N) / 241.0
	var puestas := 0
	var intentos := 0
	while puestas < NUM_PALMERAS and intentos < NUM_PALMERAS * 200:
		intentos += 1
		var px := _azar(-zona, zona)
		var pz := _azar(-zona, zona)
		var h: float = terreno.altura_en(px, pz)
		if h < 0.5 or h > 7.0:
			continue
		var n: Vector3 = terreno.normal_en(px, pz)
		if n.y < 0.9:
			continue
		var palmera := _crear_palmera(px, h, pz)
		palmera.name = "Palmera%d" % puestas
		add_child(palmera)
		puestas += 1
	print("Palmeras colocadas: ", puestas, " (intentos: ", intentos, ")")


func _colocar_rocas(terreno: Node) -> void:
	var zona: float = 76.0 * float(terreno.N) / 241.0
	var puestas := 0
	var intentos := 0
	while puestas < NUM_ROCAS and intentos < NUM_ROCAS * 60:
		intentos += 1
		var px := _azar(-zona, zona)
		var pz := _azar(-zona, zona)
		var h: float = terreno.altura_en(px, pz)
		if h < 4.0:
			continue
		var roca := _crear_roca(px, h, pz)
		roca.name = "Roca%d" % puestas
		add_child(roca)
		puestas += 1
	print("Rocas colocadas: ", puestas, " (intentos: ", intentos, ")")


func _crear_palmera(px: float, h: float, pz: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = Vector3(px, h - 0.2, pz)
	raiz.rotation.y = _azar(0.0, TAU)

	var altura := _azar(4.5, 7.0)
	var inclin := Vector3(_azar(-0.08, 0.08), 0.0, _azar(-0.08, 0.08))

	var tronco := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.3
	cm.height = altura
	cm.radial_segments = 8
	tronco.mesh = cm
	tronco.material_override = _mat_tronco()
	tronco.rotation = inclin
	tronco.position = Vector3(0, altura * 0.5, 0)
	raiz.add_child(tronco)

	var copa := Node3D.new()
	copa.rotation = inclin
	copa.position = Vector3(0, altura, 0)
	raiz.add_child(copa)

	for i in 6:
		var hoja := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.06, 2.6)
		hoja.mesh = bm
		hoja.material_override = _mat_hoja()
		var ang := TAU * float(i) / 6.0 + _azar(-0.2, 0.2)
		hoja.position = Vector3(sin(ang) * 1.2, _azar(-0.2, 0.1), cos(ang) * 1.2)
		hoja.rotation = Vector3(_azar(0.25, 0.55), ang, 0.0)
		copa.add_child(hoja)

	var cocotero := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.35
	esfera.height = 0.5
	esfera.radial_segments = 8
	esfera.rings = 4
	cocotero.mesh = esfera
	cocotero.material_override = _mat_hoja()
	cocotero.position = Vector3(0, 0.15, 0)
	copa.add_child(cocotero)

	return raiz


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


func _mat_tronco() -> StandardMaterial3D:
	if _mat_tronco_cache == null:
		_mat_tronco_cache = StandardMaterial3D.new()
		_mat_tronco_cache.albedo_color = Color(0.42, 0.3, 0.18)
		_mat_tronco_cache.roughness = 1.0
	return _mat_tronco_cache


func _mat_hoja() -> StandardMaterial3D:
	if _mat_hoja_cache == null:
		_mat_hoja_cache = StandardMaterial3D.new()
		_mat_hoja_cache.albedo_color = Color(0.15, 0.45, 0.18)
		_mat_hoja_cache.roughness = 0.9
	return _mat_hoja_cache


func _mat_roca() -> StandardMaterial3D:
	if _mat_roca_cache == null:
		_mat_roca_cache = StandardMaterial3D.new()
		_mat_roca_cache.albedo_color = Color(0.45, 0.43, 0.4)
		_mat_roca_cache.roughness = 1.0
	return _mat_roca_cache
