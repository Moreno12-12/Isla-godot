extends Node3D

const LAGUNAS: Array[Vector2] = [Vector2(-45, 31.5), Vector2(48, -28.5), Vector2(12, 60)]
const NUM_EDIFICIOS := 8
const TIPOS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
const NOMBRES: Array[String] = [
	"chalet", "cabana", "moderna", "casa-4aguas",
	"edificio-2p", "torre-4p", "chalet-variante", "cabana-variante",
]

var _semilla := 24681357
var _actual: Node3D


func _ready() -> void:
	call_deferred("_colocar")


func _azar(min_v: float, max_v: float) -> float:
	_semilla = (1103515245 * _semilla + 12345) % 2147483648
	return min_v + (max_v - min_v) * (float(_semilla) / 2147483648.0)


func _huella(tipo: int) -> Vector2:
	match tipo:
		0, 6:
			return Vector2(6.4, 5.4)
		1, 7:
			return Vector2(4.6, 4.6)
		2:
			return Vector2(6.6, 5.6)
		3:
			return Vector2(5.6, 5.6)
		4:
			return Vector2(7.4, 6.4)
		5:
			return Vector2(5.4, 5.4)
	return Vector2(6.0, 6.0)


func _colocar() -> void:
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("No se encontró el nodo Terreno")
		return

	var objetos_ocup: Array[Vector2] = []
	var objetos := get_node_or_null("../Objetos")
	if objetos != null:
		for hijo in objetos.get_children():
			objetos_ocup.append(Vector2(hijo.position.x, hijo.position.z))

	var centro := Vector2.ZERO
	var hay_centro := false
	var puestos: Array[Vector2] = []
	var huellas_puestas: Array[Vector2] = []
	var colocados := 0

	for i in NUM_EDIFICIOS:
		var tipo: int = TIPOS[i]
		var huella := _huella(tipo)
		var banda := Vector2(0.15, 1.0) if i == 0 else Vector2(0.15, 4.0)
		var px := 0.0
		var pz := 0.0
		var h := 0.0
		var encontrado := false
		var intentos := 0
		while intentos < 12000 and not encontrado:
			intentos += 1
			var cx := 0.0
			var cz := 0.0
			if not hay_centro:
				cx = _azar(-76.0, 76.0)
				cz = _azar(-76.0, 76.0)
			else:
				cx = centro.x + _azar(-30.0, 30.0)
				cz = centro.y + _azar(-30.0, 30.0)
				var dist := Vector2(cx, cz).distance_to(centro)
				if dist < 8.0 or dist > 30.0:
					continue
			var ch: float = terreno.altura_en(cx, cz)
			if ch < banda.x or ch > banda.y:
				continue
			if terreno.normal_en(cx, cz).y < 0.9:
				continue
			var en_laguna := false
			for lg in LAGUNAS:
				if Vector2(cx, cz).distance_to(lg) < 14.0:
					en_laguna = true
			if en_laguna:
				continue
			var sep_obj: float = 4.0 + maxf(huella.x, huella.y) * 0.5
			var ok := true
			for oc in objetos_ocup:
				if Vector2(cx, cz).distance_to(oc) < sep_obj:
					ok = false
			if ok:
				for j in puestos.size():
					var sep_ed: float = (maxf(huella.x, huella.y) + maxf(huellas_puestas[j].x, huellas_puestas[j].y)) * 0.5 + 2.0
					if Vector2(cx, cz).distance_to(puestos[j]) < sep_ed:
						ok = false
			if not ok:
				continue
			px = cx
			pz = cz
			h = ch
			encontrado = true

		if not encontrado:
			print("Aviso: no hay sitio para edificio ", i + 1, "/", NUM_EDIFICIOS, " (", NOMBRES[tipo], ")")
			continue

		if not hay_centro:
			centro = Vector2(px, pz)
			hay_centro = true

		var h_base: float = terreno.altura_en(px, pz)
		var meta := huella * 0.5 + Vector2(0.2, 0.2)
		for esq in [Vector2(meta.x, meta.y), Vector2(-meta.x, meta.y), Vector2(meta.x, -meta.y), Vector2(-meta.x, -meta.y)]:
			h_base = minf(h_base, terreno.altura_en(px + esq.x, pz + esq.y))

		var raiz := Node3D.new()
		raiz.name = "Edificio%d" % (i + 1)
		add_child(raiz)
		raiz.position = Vector3(px, h_base - 0.15, pz)
		if i == 0:
			raiz.rotation.y = atan2(px, pz)
		else:
			raiz.rotation.y = atan2(px - centro.x, pz - centro.y)
		_actual = raiz
		_construir(tipo)

		puestos.append(Vector2(px, pz))
		huellas_puestas.append(huella)
		colocados += 1
		print("Edificio ", i + 1, "/", NUM_EDIFICIOS, " (", NOMBRES[tipo], ") en (", snappedf(px, 0.1), ", ", snappedf(h, 0.1), ", ", snappedf(pz, 0.1), ") intentos=", intentos)

	print("Pueblo: ", colocados, "/", NUM_EDIFICIOS, " edificios")
	for hijo in get_children():
		print("  ", hijo.name, " pos=(", snappedf(hijo.position.x, 0.1), ", ", snappedf(hijo.position.y, 0.1), ", ", snappedf(hijo.position.z, 0.1), ")")


func _construir(tipo: int) -> void:
	match tipo:
		0:
			_construir_chalet(_mat_pared())
		1:
			_construir_cabana(_mat_teja())
		2:
			_construir_moderna()
		3:
			_construir_cuatro_aguas()
		4:
			_construir_edificio()
		5:
			_construir_torre()
		6:
			_construir_chalet(_mat_pared2())
		7:
			_construir_cabana(_mat_techo_verde())


func _construir_chalet(pared: Material) -> void:
	_agregar(BoxMesh.new(), Vector3(6, 4, 5), Vector3(0, 2, 0), pared)
	_agregar(BoxMesh.new(), Vector3(6.4, 0.5, 5.4), Vector3(0, 0.1, 0), _mat_cimiento())

	# Puerta (fachada +Z)
	_agregar(BoxMesh.new(), Vector3(1.4, 2.5, 0.1), Vector3(0, 1.25, 2.52), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.7, 2.7, 0.08), Vector3(0, 1.35, 2.51), _mat_marco())

	# Ventanas: 2 frontales, 2 laterales
	for x in [-1.9, 1.9]:
		_agregar(BoxMesh.new(), Vector3(1.3, 1.3, 0.08), Vector3(x, 2.7, 2.51), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(1.0, 1.0, 0.12), Vector3(x, 2.7, 2.53), _mat_vidrio())
	for lado in [-1.0, 1.0]:
		_agregar(BoxMesh.new(), Vector3(0.08, 1.3, 1.3), Vector3(lado * 3.01, 2.7, -0.6), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(0.12, 1.0, 1.0), Vector3(lado * 3.03, 2.7, -0.6), _mat_vidrio())

	# Tejado a dos aguas
	var techo := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(5.8, 2.2, 6.6)
	techo.mesh = prism
	techo.material_override = _mat_teja()
	techo.position = Vector3(0, 5.1, 0)
	techo.rotation.y = PI / 2.0
	_actual.add_child(techo)

	# Chimenea
	_agregar(BoxMesh.new(), Vector3(0.6, 2.2, 0.6), Vector3(-1.8, 5.6, -0.8), _mat_cimiento())


func _construir_cabana(techo_mat: Material) -> void:
	_agregar(BoxMesh.new(), Vector3(4.6, 0.4, 4.6), Vector3(0, 0.1, 0), _mat_cimiento())
	_agregar(BoxMesh.new(), Vector3(4, 3, 4), Vector3(0, 1.7, 0), _mat_madera())

	# Tejado piramidal (cilindro de4 segmentos)
	var pir := CylinderMesh.new()
	pir.top_radius = 0.0
	pir.bottom_radius = 3.0
	pir.height = 2.2
	pir.radial_segments = 4
	var techo := _agregar(pir, Vector3(0, 2.2, 6), Vector3(0, 4.3, 0), techo_mat)
	techo.rotation.y = PI / 4.0

	# Puerta y ventana
	_agregar(BoxMesh.new(), Vector3(1.1, 2.1, 0.1), Vector3(0, 1.2, 2.02), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.3, 1.3, 0.08), Vector3(1.3, 2.0, 2.01), _mat_marco())
	_agregar(BoxMesh.new(), Vector3(1.0, 1.0, 0.12), Vector3(1.3, 2.0, 2.03), _mat_vidrio())


func _construir_moderna() -> void:
	_agregar(BoxMesh.new(), Vector3(6.6, 0.5, 5.6), Vector3(0, 0.1, 0), _mat_cimiento())
	# Planta baja
	_agregar(BoxMesh.new(), Vector3(6, 3, 5), Vector3(0, 1.75, 0), _mat_pared())
	# Techo intermedio volado
	_agregar(BoxMesh.new(), Vector3(6.6, 0.25, 5.6), Vector3(0, 3.4, 0), _mat_techo_mod())
	# Planta alta desplazada
	_agregar(BoxMesh.new(), Vector3(4.2, 2.4, 3.4), Vector3(0.7, 4.7, -0.5), _mat_pared2())
	# Techo superior
	_agregar(BoxMesh.new(), Vector3(4.6, 0.25, 3.8), Vector3(0.7, 6.0, -0.5), _mat_techo_mod())

	# Ventana panorámica
	_agregar(BoxMesh.new(), Vector3(4.6, 1.6, 0.08), Vector3(0, 2.2, 2.51), _mat_marco())
	_agregar(BoxMesh.new(), Vector3(4.3, 1.3, 0.12), Vector3(0, 2.2, 2.53), _mat_vidrio())
	# Puerta
	_agregar(BoxMesh.new(), Vector3(1.2, 2.2, 0.1), Vector3(2.2, 1.3, 2.52), _mat_puerta())


func _construir_cuatro_aguas() -> void:
	_agregar(BoxMesh.new(), Vector3(5.6, 0.5, 5.6), Vector3(0, 0.1, 0), _mat_cimiento())
	_agregar(BoxMesh.new(), Vector3(5, 3.5, 5), Vector3(0, 1.95, 0), _mat_pared())

	# Tejado a4 aguas
	var pir := CylinderMesh.new()
	pir.top_radius = 0.0
	pir.bottom_radius = 3.6
	pir.height = 2.6
	pir.radial_segments = 4
	var techo := _agregar(pir, Vector3(0, 2.6, 7.2), Vector3(0, 5.0, 0), _mat_teja())
	techo.rotation.y = PI / 4.0

	# Puerta y ventanas
	_agregar(BoxMesh.new(), Vector3(1.3, 2.4, 0.1), Vector3(0, 1.3, 2.52), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.6, 2.6, 0.08), Vector3(0, 1.4, 2.51), _mat_marco())
	for x in [-1.7, 1.7]:
		_agregar(BoxMesh.new(), Vector3(1.2, 1.2, 0.08), Vector3(x, 2.4, 2.51), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(0.9, 0.9, 0.12), Vector3(x, 2.4, 2.53), _mat_vidrio())


func _construir_edificio() -> void:
	_agregar(BoxMesh.new(), Vector3(7.4, 0.5, 6.4), Vector3(0, 0.15, 0), _mat_cimiento())
	_agregar(BoxMesh.new(), Vector3(7, 6.5, 6), Vector3(0, 3.6, 0), _mat_pared())

	# Puerta central
	_agregar(BoxMesh.new(), Vector3(1.6, 2.6, 0.1), Vector3(0, 1.5, 3.02), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.9, 2.8, 0.08), Vector3(0, 1.55, 3.01), _mat_marco())

	# Ventanas frontales (2 plantas)
	for y in [2.0, 4.6]:
		for x in [-2.2, 2.2]:
			_agregar(BoxMesh.new(), Vector3(1.4, 1.4, 0.08), Vector3(x, y, 3.01), _mat_marco())
			_agregar(BoxMesh.new(), Vector3(1.1, 1.1, 0.12), Vector3(x, y, 3.03), _mat_vidrio())
	for x in [-2.2, 0.0, 2.2]:
		_agregar(BoxMesh.new(), Vector3(1.4, 1.4, 0.08), Vector3(x, 4.6, 3.01), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(1.1, 1.1, 0.12), Vector3(x, 4.6, 3.03), _mat_vidrio())

	# Ventanas laterales
	for lado in [-1.0, 1.0]:
		for y in [2.0, 4.6]:
			for z in [-1.5, 1.5]:
				_agregar(BoxMesh.new(), Vector3(0.08, 1.4, 1.4), Vector3(lado * 3.51, y, z), _mat_marco())
				_agregar(BoxMesh.new(), Vector3(0.12, 1.1, 1.1), Vector3(lado * 3.53, y, z), _mat_vidrio())

	# Cubierta plana
	_agregar(BoxMesh.new(), Vector3(7.4, 0.3, 6.4), Vector3(0, 7.0, 0), _mat_techo_mod())


func _construir_torre() -> void:
	_agregar(BoxMesh.new(), Vector3(5.4, 0.5, 5.4), Vector3(0, 0.15, 0), _mat_cimiento())
	_agregar(BoxMesh.new(), Vector3(5, 14, 5), Vector3(0, 7.4, 0), _mat_pared2())

	# Puerta
	_agregar(BoxMesh.new(), Vector3(1.5, 2.6, 0.1), Vector3(0, 1.5, 2.52), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.8, 2.8, 0.08), Vector3(0, 1.55, 2.51), _mat_marco())

	# Rejilla de ventanas (5 plantas)
	for y in [4.2, 6.8, 9.4, 12.0]:
		for x in [-1.4, 0.0, 1.4]:
			_agregar(BoxMesh.new(), Vector3(1.1, 1.4, 0.08), Vector3(x, y, 2.51), _mat_marco())
			_agregar(BoxMesh.new(), Vector3(0.85, 1.1, 0.12), Vector3(x, y, 2.53), _mat_vidrio())
		for lado in [-1.0, 1.0]:
			_agregar(BoxMesh.new(), Vector3(0.08, 1.4, 1.1), Vector3(lado * 2.51, y, 0.0), _mat_marco())
			_agregar(BoxMesh.new(), Vector3(0.12, 1.1, 0.85), Vector3(lado * 2.53, y, 0.0), _mat_vidrio())

	# Remate
	_agregar(BoxMesh.new(), Vector3(5.4, 0.3, 5.4), Vector3(0, 14.5, 0), _mat_techo_mod())
	_agregar(BoxMesh.new(), Vector3(1.8, 0.8, 1.8), Vector3(0, 15.0, 0), _mat_cimiento())


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
	_actual.add_child(mi)
	return mi


var _m_pared: StandardMaterial3D
var _m_pared2: StandardMaterial3D
var _m_cimiento: StandardMaterial3D
var _m_puerta: StandardMaterial3D
var _m_marco: StandardMaterial3D
var _m_vidrio: StandardMaterial3D
var _m_teja: StandardMaterial3D
var _m_madera: StandardMaterial3D
var _m_techo_mod: StandardMaterial3D
var _m_techo_verde: StandardMaterial3D


func _mat_simple(color: Color, rug: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rug
	m.metallic = metal
	return m


func _mat_pared() -> StandardMaterial3D:
	if _m_pared == null:
		_m_pared = _mat_simple(Color(0.93, 0.9, 0.82))
	return _m_pared


func _mat_pared2() -> StandardMaterial3D:
	if _m_pared2 == null:
		_m_pared2 = _mat_simple(Color(0.72, 0.78, 0.84))
	return _m_pared2


func _mat_cimiento() -> StandardMaterial3D:
	if _m_cimiento == null:
		_m_cimiento = _mat_simple(Color(0.5, 0.47, 0.43), 1.0)
	return _m_cimiento


func _mat_puerta() -> StandardMaterial3D:
	if _m_puerta == null:
		_m_puerta = _mat_simple(Color(0.4, 0.26, 0.15), 0.8)
	return _m_puerta


func _mat_marco() -> StandardMaterial3D:
	if _m_marco == null:
		_m_marco = _mat_simple(Color(0.95, 0.95, 0.95), 0.7)
	return _m_marco


func _mat_vidrio() -> StandardMaterial3D:
	if _m_vidrio == null:
		_m_vidrio = _mat_simple(Color(0.55, 0.75, 0.9), 0.05, 0.4)
	return _m_vidrio


func _mat_teja() -> StandardMaterial3D:
	if _m_teja == null:
		_m_teja = _mat_simple(Color(0.62, 0.25, 0.18))
	return _m_teja


func _mat_madera() -> StandardMaterial3D:
	if _m_madera == null:
		_m_madera = _mat_simple(Color(0.5, 0.33, 0.2))
	return _m_madera


func _mat_techo_mod() -> StandardMaterial3D:
	if _m_techo_mod == null:
		_m_techo_mod = _mat_simple(Color(0.32, 0.33, 0.35))
	return _m_techo_mod


func _mat_techo_verde() -> StandardMaterial3D:
	if _m_techo_verde == null:
		_m_techo_verde = _mat_simple(Color(0.3, 0.45, 0.32))
	return _m_techo_verde
