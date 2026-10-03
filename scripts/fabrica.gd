extends Node3D

const LAGUNAS: Array[Vector2] = [Vector2(-45, 31.5), Vector2(48, -28.5), Vector2(12, 60)]

var _semilla := 13579246


func _ready() -> void:
	call_deferred("_colocar")


func _azar(min_v: float, max_v: float) -> float:
	_semilla = (1103515245 * _semilla + 12345) % 2147483648
	return min_v + (max_v - min_v) * (float(_semilla) / 2147483648.0)


func _colocar() -> void:
	print("Fabrica: _colocar inicio")
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("No se encontró el nodo Terreno")
		return

	var edificios: Array[Vector2] = []
	var casa := get_node_or_null("../Casa")
	if casa != null:
		for hijo in casa.get_children():
			edificios.append(Vector2(hijo.global_position.x, hijo.global_position.z))

	var objetitos := get_node_or_null("../Objetos")

	var px := 0.0
	var pz := 0.0
	var hay_respaldo := false
	var encontrado := false
	var intentos := 0
	var mejor_relieve := 10000.0
	var esquinas: Array[Vector2] = [Vector2(15, 11), Vector2(-15, 11), Vector2(15, -11), Vector2(-15, -11)]
	var f_h := 0
	var f_n := 0
	var f_r := 0
	var f_l := 0
	var f_c := 0
	while intentos < 40000 and not encontrado:
		intentos += 1
		var cx := _azar(-64.0, 64.0)
		var cz := _azar(-64.0, 64.0)
		var ch: float = terreno.altura_en(cx, cz)
		if ch < 1.2 or ch > 8.0:
			f_h += 1
			continue
		if terreno.normal_en(cx, cz).y < 0.9:
			f_n += 1
			continue
		if terreno.en_zona_ciudad(cx, cz):
			f_c += 1
			continue
		var hs: Array[float] = [ch]
		for esq in esquinas:
			hs.append(terreno.altura_en(cx + esq.x, cz + esq.y))
		var relieve: float = hs.max() - hs.min()
		if relieve > 10.0:
			f_r += 1
			continue
		var en_laguna := false
		for lg in LAGUNAS:
			if Vector2(cx, cz).distance_to(lg) < 24.0:
				en_laguna = true
		if en_laguna:
			f_l += 1
			continue
		var sin_edif := true
		for ed in edificios:
			if absf(ed.x - cx) < 19.0 and absf(ed.y - cz) < 15.0:
				sin_edif = false
		if not sin_edif:
			continue
		if relieve < mejor_relieve:
			mejor_relieve = relieve
			px = cx
			pz = cz
			hay_respaldo = true
		if relieve <= 4.0:
			px = cx
			pz = cz
			encontrado = true

	if not hay_respaldo:
		push_error("No se encontro ubicacion para la fabrica (h=", f_h, " n=", f_n, " r=", f_r, " l=", f_l, " c=", f_c, " intentos=", intentos, ")")
		return

	var h_base: float = terreno.altura_en(px, pz)

	position = Vector3(px, h_base - 0.1, pz)
	rotation.y = atan2(px, pz)

	var movidos := _despejar(terreno, px, pz)

	var quitados := 0
	if objetitos != null and objetitos.has_method("despejar_en"):
		quitados = objetitos.despejar_en(px, pz, 16.5, 12.5)

	var hs_f: Array[float] = [h_base]
	for esq in esquinas:
		hs_f.append(terreno.altura_en(px + esq.x, pz + esq.y))
	var h_min: float = hs_f.min()
	var fondo: float = h_base - h_min + 1.5

	_construir(fondo)
	print("Fabrica colocada en (", snappedf(px, 0.1), ", ", snappedf(h_base, 0.1), ", ", snappedf(pz, 0.1), ") intentos=", intentos, " libre=", encontrado, " relieve=", snappedf(mejor_relieve, 0.01), " fondo=", snappedf(fondo, 0.1), " despejados=", movidos, " vegetales=", quitados)


func _despejar(terreno: Node, px: float, pz: float) -> int:
	var movidos := 0
	var objetitos := get_node_or_null("../Objetos")
	if objetitos == null:
		return 0
	for hijo in objetitos.get_children():
		if hijo is MultiMeshInstance3D:
			continue
		var gx: float = hijo.global_position.x
		var gz: float = hijo.global_position.z
		if absf(gx - px) >= 16.5 or absf(gz - pz) >= 12.5:
			continue
		var intento := 0
		while intento < 500:
			intento += 1
			var nx := _azar(-70.0, 70.0)
			var nz := _azar(-70.0, 70.0)
			if absf(nx - px) < 20.0 and absf(nz - pz) < 16.0:
				continue
			var nh: float = terreno.altura_en(nx, nz)
			if nh < 0.5 or nh > 22.0:
				continue
			if terreno.en_zona_ciudad(nx, nz):
				continue
			var en_laguna := false
			for lg in LAGUNAS:
				if Vector2(nx, nz).distance_to(lg) < 14.0:
					en_laguna = true
			if en_laguna:
				continue
			var dy: float = hijo.position.y - terreno.altura_en(gx, gz)
			hijo.position = Vector3(nx, nh + dy, nz)
			movidos += 1
			break
	return movidos


func _construir(fondo: float) -> void:
	# Losa de cimientos (plataforma que se hunde hasta el punto más bajo)
	_agregar(BoxMesh.new(), Vector3(30, fondo, 22), Vector3(0, 0.3 - fondo * 0.5, 0), _mat_loza())

	# Nave industrial
	_agregar(BoxMesh.new(), Vector3(16, 7, 10), Vector3(-3, 3.7, 0), _mat_nave())
	# Tejado nave
	_agregar(BoxMesh.new(), Vector3(16.4, 0.4, 10.4), Vector3(-3, 7.4, 0), _mat_oscuro())
	# Ventanas (fachada +Z)
	for i in 6:
		_agregar(BoxMesh.new(), Vector3(1.6, 1.4, 0.15), Vector3(-9.5 + float(i) * 2.6, 5.2, 5.05), _mat_vidrio())
	# Puerta de carga
	_agregar(BoxMesh.new(), Vector3(4.5, 3.6, 0.2), Vector3(-3, 2.0, 5.1), _mat_puerta())

	# Chimenea
	_agregar(CylinderMesh.new(), Vector3(2.6, 22, 2.6), Vector3(6.5, 11.2, -3.5), _mat_chimenea())
	_agregar(CylinderMesh.new(), Vector3(2.9, 2.9, 1.6), Vector3(6.5, 21.4, -3.5), _mat_roja())
	_agregar(CylinderMesh.new(), Vector3(2.7, 2.7, 1.2), Vector3(6.5, 22.6, -3.5), _mat_oscuro())

	# Humo estático
	var humo_pos := Vector3(6.5, 23.5, -3.5)
	for i in 6:
		var tam := 1.2 + float(i) * 0.75
		var esfera := SphereMesh.new()
		esfera.radius = tam
		esfera.height = tam * 1.6
		esfera.radial_segments = 8
		esfera.rings = 5
		var desplaz := Vector3(float(i) * 1.1, float(i) * 1.5, -float(i) * 0.8)
		_agregar(esfera, Vector3(tam * 2, tam * 1.6, tam * 2), humo_pos + desplaz, _mat_humo(i))

	# Torres de refrigeración (cilindros truncados: boca arriba estrecha)
	_torre(Vector3(8, 0, 6))
	_torre(Vector3(12, 0, -8))

	# Piles de carbón
	for p in [Vector3(-11, 0.4, 7.5), Vector3(-14.5, 0.4, 4), Vector3(-9, 0.4, 10)]:
		var carbon := SphereMesh.new()
		carbon.radius = 2.4
		carbon.height = 3.2
		carbon.radial_segments = 8
		carbon.rings = 5
		_agregar(carbon, Vector3(4.8, 3.2, 4.8), p, _mat_carbon())

	# Cinta transportadora (inclinada: nave -> pilas)
	var cinta := _agregar(BoxMesh.new(), Vector3(12, 0.4, 1.4), Vector3(-8.5, 3.2, 6), _mat_oscuro())
	cinta.rotation.z = -0.35
	for pata_x in [-13.0, -8.0, -4.0]:
		var alt: float = 3.2 + (pata_x + 8.5) * -0.35 * -1.0
		_agregar(BoxMesh.new(), Vector3(0.3, maxf(alt, 0.5), 0.3), Vector3(pata_x, maxf(alt, 0.5) * 0.5, 6), _mat_oscuro())

	# Tuberías nave -> torres
	for dest in [Vector3(8, 4.5, 6), Vector3(12, 4.5, -8)]:
		var origen := Vector3(5, 4.5, 0)
		var dir: Vector3 = dest - origen
		var tubo := _agregar(CylinderMesh.new(), Vector3(0.7, dir.length(), 0.7), origen + dir * 0.5, _mat_tubo())
		tubo.rotation = _rotacion_cilindro(dir)

	# Tubería horizontal decorativa a lo largo de la nave
	_agregar(CylinderMesh.new(), Vector3(0.8, 14, 0.8), Vector3(-3, 7.9, 4), _mat_tubo()).rotation.z = PI / 2.0


func _torre(base: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 2.5
	cm.bottom_radius = 4.0
	cm.height = 9.0
	cm.radial_segments = 16
	_agregar(cm, Vector3(8, 9, 8), base + Vector3(0, 4.7, 0), _mat_torre())
	# Boca superior oscura
	_agregar(CylinderMesh.new(), Vector3(5.2, 5.2, 0.4), base + Vector3(0, 9.3, 0), _mat_oscuro())


func _rotacion_cilindro(dir: Vector3) -> Vector3:
	return Basis(Quaternion(Vector3.UP, dir.normalized())).get_euler()


func _agregar(mesh: Mesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		c.top_radius = size.x * 0.5
		c.bottom_radius = size.z * 0.5
		c.height = size.y
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


var _m_loza: StandardMaterial3D
var _m_nave: StandardMaterial3D
var _m_oscuro: StandardMaterial3D
var _m_vidrio: StandardMaterial3D
var _m_puerta: StandardMaterial3D
var _m_chimenea: StandardMaterial3D
var _m_roja: StandardMaterial3D
var _m_carbon: StandardMaterial3D
var _m_torre: StandardMaterial3D
var _m_tubo: StandardMaterial3D
var _m_humo: Array[StandardMaterial3D] = []


func _mat_simple(color: Color, rug: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rug
	m.metallic = metal
	return m


func _mat_loza() -> StandardMaterial3D:
	if _m_loza == null:
		_m_loza = _mat_simple(Color(0.42, 0.42, 0.44), 1.0)
	return _m_loza


func _mat_nave() -> StandardMaterial3D:
	if _m_nave == null:
		_m_nave = _mat_simple(Color(0.35, 0.36, 0.38), 0.85)
	return _m_nave


func _mat_oscuro() -> StandardMaterial3D:
	if _m_oscuro == null:
		_m_oscuro = _mat_simple(Color(0.2, 0.2, 0.22), 0.8)
	return _m_oscuro


func _mat_vidrio() -> StandardMaterial3D:
	if _m_vidrio == null:
		_m_vidrio = _mat_simple(Color(0.5, 0.72, 0.9), 0.1, 0.4)
	return _m_vidrio


func _mat_puerta() -> StandardMaterial3D:
	if _m_puerta == null:
		_m_puerta = _mat_simple(Color(0.55, 0.4, 0.15), 0.7, 0.3)
	return _m_puerta


func _mat_chimenea() -> StandardMaterial3D:
	if _m_chimenea == null:
		_m_chimenea = _mat_simple(Color(0.75, 0.74, 0.72), 0.9)
	return _m_chimenea


func _mat_roja() -> StandardMaterial3D:
	if _m_roja == null:
		_m_roja = _mat_simple(Color(0.75, 0.15, 0.12), 0.8)
	return _m_roja


func _mat_carbon() -> StandardMaterial3D:
	if _m_carbon == null:
		_m_carbon = _mat_simple(Color(0.08, 0.08, 0.09), 1.0)
	return _m_carbon


func _mat_torre() -> StandardMaterial3D:
	if _m_torre == null:
		_m_torre = _mat_simple(Color(0.65, 0.65, 0.63), 0.9)
	return _m_torre


func _mat_tubo() -> StandardMaterial3D:
	if _m_tubo == null:
		_m_tubo = _mat_simple(Color(0.55, 0.56, 0.58), 0.5, 0.5)
	return _m_tubo


func _mat_humo(i: int) -> StandardMaterial3D:
	while _m_humo.size() <= i:
		var nivel := float(_m_humo.size()) / 6.0
		var g := lerpf(0.55, 0.75, nivel)
		var mat := _mat_simple(Color(g, g, g, 1.0), 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = lerpf(0.85, 0.35, nivel)
		_m_humo.append(mat)
	return _m_humo[i]
