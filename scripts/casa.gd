extends Node3D

const LAGUNAS: Array[Vector2] = [Vector2(-30, 21), Vector2(32, -19), Vector2(8, 40)]

var _semilla := 24681357


func _ready() -> void:
	call_deferred("_colocar")


func _azar(min_v: float, max_v: float) -> float:
	_semilla = (1103515245 * _semilla + 12345) % 2147483648
	return min_v + (max_v - min_v) * (float(_semilla) / 2147483648.0)


func _colocar() -> void:
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("No se encontró el nodo Terreno")
		return

	var ocupadas: Array[Vector2] = []
	var objetos := get_node_or_null("../Objetos")
	if objetos != null:
		for hijo in objetos.get_children():
			ocupadas.append(Vector2(hijo.position.x, hijo.position.z))

	var px := 0.0
	var pz := 0.0
	var h := 0.0
	var hay_respaldo := false
	var intentos := 0
	var encontrado := false
	while intentos < 30000 and not encontrado:
		intentos += 1
		var cx := _azar(-76.0, 76.0)
		var cz := _azar(-76.0, 76.0)
		var ch: float = terreno.altura_en(cx, cz)
		if ch < 0.15 or ch > 1.0:
			continue
		if terreno.normal_en(cx, cz).y < 0.9:
			continue
		var en_laguna := false
		for lg in LAGUNAS:
			if Vector2(cx, cz).distance_to(lg) < 14.0:
				en_laguna = true
		if en_laguna:
			continue
		if not hay_respaldo:
			px = cx
			pz = cz
			h = ch
			hay_respaldo = true
		var libre := true
		for oc in ocupadas:
			if Vector2(cx, cz).distance_to(oc) < 5.0:
				libre = false
		if libre:
			px = cx
			pz = cz
			h = ch
			encontrado = true

	if not encontrado and not hay_respaldo:
		push_error("No se encontró ubicación para la casa")
		return

	var h_base: float = terreno.altura_en(px, pz)
	for esq in [Vector2(3.2, 2.7), Vector2(-3.2, 2.7), Vector2(3.2, -2.7), Vector2(-3.2, -2.7)]:
		h_base = minf(h_base, terreno.altura_en(px + esq.x, pz + esq.y))

	position = Vector3(px, h_base - 0.15, pz)
	rotation.y = atan2(px, pz)
	_construir()
	print("Casa colocada en (", snappedf(px, 0.1), ", ", snappedf(h, 0.1), ", ", snappedf(pz, 0.1), ") intentos=", intentos, " libre=", encontrado)


func _construir() -> void:
	# Paredes
	_agregar(BoxMesh.new(), Vector3(6, 4, 5), Vector3(0, 2, 0), _mat_pared())
	# Cimientos
	var cim := BoxMesh.new()
	cim.size = Vector3(6.4, 0.5, 5.4)
	_agregar(cim, Vector3(6.4, 0.5, 5.4), Vector3(0, 0.1, 0), _mat_cimiento())

	# Puerta (fachada +Z)
	_agregar(BoxMesh.new(), Vector3(1.4, 2.5, 0.1), Vector3(0, 1.25, 2.52), _mat_puerta())
	_agregar(BoxMesh.new(), Vector3(1.7, 2.7, 0.08), Vector3(0, 1.35, 2.51), _mat_marco())

	# Ventanas: 2 fachada frontal, 2 laterales
	for x in [-1.9, 1.9]:
		_agregar(BoxMesh.new(), Vector3(1.3, 1.3, 0.08), Vector3(x, 2.7, 2.51), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(1.0, 1.0, 0.12), Vector3(x, 2.7, 2.53), _mat_vidrio())
	for lado in [-1.0, 1.0]:
		_agregar(BoxMesh.new(), Vector3(0.08, 1.3, 1.3), Vector3(lado * 3.01, 2.7, -0.6), _mat_marco())
		_agregar(BoxMesh.new(), Vector3(0.12, 1.0, 1.0), Vector3(lado * 3.03, 2.7, -0.6), _mat_vidrio())

	# Tejado a dos aguas (PrismMesh: cumbrera a lo largo de Z -> rotar 90° en Y)
	var techo := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(5.8, 2.2, 6.6)
	techo.mesh = prism
	techo.material_override = _mat_teja()
	techo.position = Vector3(0, 5.1, 0)
	techo.rotation.y = PI / 2.0
	add_child(techo)

	# Chimenea
	_agregar(BoxMesh.new(), Vector3(0.6, 2.2, 0.6), Vector3(-1.8, 5.6, -0.8), _mat_cimiento())

	_panel_solar()


func _panel_solar() -> void:
	# Vertiente +Z: cae de y=6.2 (cumbrera) a y=4.0 (alero) en 2.8 de Z -> 0.372 rad
	var inclin := 0.372
	var soporte := _agregar(BoxMesh.new(), Vector3(0.1, 0.7, 0.1), Vector3(-1.1, 4.75, 1.55), _mat_marco())
	soporte.rotation.x = inclin
	var soporte2 := _agregar(BoxMesh.new(), Vector3(0.1, 0.7, 0.1), Vector3(1.1, 4.75, 1.55), _mat_marco())
	soporte2.rotation.x = inclin

	# Marco del panel
	var marco := _agregar(BoxMesh.new(), Vector3(3.2, 0.08, 1.9), Vector3(0, 5.15, 1.45), _mat_marco_panel())
	marco.rotation.x = inclin
	# Celdas
	var panel := _agregar(BoxMesh.new(), Vector3(3.0, 0.1, 1.7), Vector3(0, 5.2, 1.45), _mat_panel())
	panel.rotation.x = inclin


func _agregar(mesh: Mesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


var _m_pared: StandardMaterial3D
var _m_cimiento: StandardMaterial3D
var _m_puerta: StandardMaterial3D
var _m_marco: StandardMaterial3D
var _m_vidrio: StandardMaterial3D
var _m_teja: StandardMaterial3D
var _m_panel: StandardMaterial3D
var _m_marco_panel: StandardMaterial3D


func _mat_pared() -> StandardMaterial3D:
	if _m_pared == null:
		_m_pared = StandardMaterial3D.new()
		_m_pared.albedo_color = Color(0.93, 0.9, 0.82)
		_m_pared.roughness = 0.9
	return _m_pared


func _mat_cimiento() -> StandardMaterial3D:
	if _m_cimiento == null:
		_m_cimiento = StandardMaterial3D.new()
		_m_cimiento.albedo_color = Color(0.5, 0.47, 0.43)
		_m_cimiento.roughness = 1.0
	return _m_cimiento


func _mat_puerta() -> StandardMaterial3D:
	if _m_puerta == null:
		_m_puerta = StandardMaterial3D.new()
		_m_puerta.albedo_color = Color(0.4, 0.26, 0.15)
		_m_puerta.roughness = 0.8
	return _m_puerta


func _mat_marco() -> StandardMaterial3D:
	if _m_marco == null:
		_m_marco = StandardMaterial3D.new()
		_m_marco.albedo_color = Color(0.95, 0.95, 0.95)
		_m_marco.roughness = 0.7
	return _m_marco


func _mat_vidrio() -> StandardMaterial3D:
	if _m_vidrio == null:
		_m_vidrio = StandardMaterial3D.new()
		_m_vidrio.albedo_color = Color(0.55, 0.75, 0.9)
		_m_vidrio.roughness = 0.05
		_m_vidrio.metallic = 0.4
	return _m_vidrio


func _mat_teja() -> StandardMaterial3D:
	if _m_teja == null:
		_m_teja = StandardMaterial3D.new()
		_m_teja.albedo_color = Color(0.62, 0.25, 0.18)
		_m_teja.roughness = 0.9
	return _m_teja


func _mat_panel() -> StandardMaterial3D:
	if _m_panel == null:
		_m_panel = StandardMaterial3D.new()
		_m_panel.albedo_color = Color(0.05, 0.08, 0.2)
		_m_panel.roughness = 0.25
		_m_panel.metallic = 0.6
	return _m_panel


func _mat_marco_panel() -> StandardMaterial3D:
	if _m_marco_panel == null:
		_m_marco_panel = StandardMaterial3D.new()
		_m_marco_panel.albedo_color = Color(0.6, 0.6, 0.62)
		_m_marco_panel.roughness = 0.5
		_m_marco_panel.metallic = 0.5
	return _m_marco_panel
