extends Node3D

const MODELOS: Dictionary = {
	0: preload("res://models/panel_solar.glb"),
	1: preload("res://models/molino_eolico.glb"),
	2: preload("res://models/turbina_pelton.glb"),
	3: preload("res://models/bateria.glb"),
}
const ESCALAS: Dictionary = {0: 1.5, 1: 1.8, 2: 1.5, 3: 1.5}
const NOMBRES: Dictionary = {0: "Panel solar", 1: "Molino eolico", 2: "Turbina hidraulica", 3: "Bateria", 4: "Eliminar"}
const DESFASE_BASE: Dictionary = {0: 0.0, 1: 0.0, 2: 0.4, 3: 0.0}
const DISTANCIA_MIN := 12.0
const MODO_ELIMINAR := 4
const RADIO_SELECCION := 9.0

var _modo := -1
var _valido := false
var _posicion := Vector3.ZERO
var _marcador: MeshInstance3D
var _material: StandardMaterial3D
var _pista: Label
var _camara: Camera3D
var _terreno: Node
var _colocados: Array[Vector3] = []
var _instanciados: Array[Node3D] = []
var _objetivo: Node3D

const VERDE := Color(0.3, 0.9, 0.4, 0.4)
const ROJO := Color(0.95, 0.3, 0.25, 0.4)


func _ready() -> void:
	_terreno = get_node_or_null("../Terreno")
	_camara = get_node_or_null("../Camara")
	var ui := get_node_or_null("../CapaUI")
	if ui != null and ui.has_signal("tarjeta_pulsada"):
		ui.tarjeta_pulsada.connect(_al_pulsar_tarjeta)
	_crear_marcador()
	_crear_pista()


func _crear_marcador() -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = 3.8
	disco.bottom_radius = 3.8
	disco.height = 0.3
	disco.radial_segments = 32
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = VERDE
	_marcador = MeshInstance3D.new()
	_marcador.name = "Marcador"
	_marcador.mesh = disco
	_marcador.material_override = _material
	_marcador.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marcador.visible = false
	add_child(_marcador)


func _crear_pista() -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaPista"
	capa.layer = 11
	add_child(capa)
	_pista = Label.new()
	_pista.text = "MODO COLOCACION: clic izq colocar | clic der / Esc cancelar"
	_pista.anchor_left = 0.0
	_pista.anchor_top = 1.0
	_pista.anchor_right = 0.0
	_pista.anchor_bottom = 1.0
	_pista.offset_left = 16.0
	_pista.offset_top = -56.0
	_pista.offset_right = 620.0
	_pista.offset_bottom = -16.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.91, 0.78, 0.48, 0.85)
	sb.set_content_margin_all(8)
	_pista.add_theme_stylebox_override("normal", sb)
	_pista.add_theme_color_override("font_color", Color(1, 1, 1))
	_pista.add_theme_font_size_override("font_size", 15)
	_pista.visible = false
	capa.add_child(_pista)


func _al_pulsar_tarjeta(indice: int) -> void:
	if indice != MODO_ELIMINAR and (indice < 0 or indice > 3):
		return
		return
	if _modo == indice:
		_cancelar()
	else:
		_modo = indice
		_marcador.visible = true
		_pista.visible = true
		_pista.text = "MODO ELIMINAR: clic izq sobre molino/turbina para borrar | Esc cancelar" \
			if _modo == MODO_ELIMINAR else \
			"MODO COLOCACION: clic izq colocar | clic der / Esc cancelar"
		if _camara != null:
			_camara.set("bloqueado", true)
		print(NOMBRES[_modo], ": elige sitio en el terreno" if _modo != MODO_ELIMINAR else ": apunta a un elemento colocado")


func _cancelar() -> void:
	_modo = -1
	_objetivo = null
	_marcador.visible = false
	_pista.visible = false
	_pista.text = "MODO COLOCACION: clic izq colocar | clic der / Esc cancelar"
	if _camara != null:
		_camara.set("bloqueado", false)


func _unhandled_input(event: InputEvent) -> void:
	if _modo < 0:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancelar()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _modo == MODO_ELIMINAR:
				_eliminar()
			else:
				_colocar()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancelar()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _modo == MODO_ELIMINAR:
			_buscar_objetivo()
		else:
			_actualizar_marcador()


func _buscar_objetivo() -> void:
	_objetivo = null
	_valido = false
	if _camara == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origen: Vector3 = _camara.project_ray_origin(mouse)
	var dir: Vector3 = _camara.project_ray_normal(mouse)
	var mejor := RADIO_SELECCION
	for n in _instanciados:
		if not is_instance_valid(n):
			continue
		var centro: Vector3 = n.global_position + Vector3(0, 4.0, 0)
		var v := centro - origen
		var proj := v.dot(dir)
		if proj <= 0.0:
			continue
		var mas_cerca := origen + dir * proj
		var d := centro.distance_to(mas_cerca)
		if d < mejor:
			mejor = d
			_objetivo = n
	_valido = _objetivo != null
	_material.albedo_color = ROJO if _valido else Color(0.6, 0.6, 0.65, 0.25)
	_marcador.visible = _valido
	if _valido:
		_marcador.position = _objetivo.global_position + Vector3(0, 0.3, 0)


func _eliminar(obj: Node3D = null) -> void:
	_objetivo = obj
	if _objetivo == null:
		_buscar_objetivo()
	if _objetivo == null:
		return
	var pos: Vector3 = _objetivo.position
	var i := _instanciados.find(_objetivo)
	if i >= 0:
		_colocados.remove_at(i)
		_instanciados.remove_at(i)
	print("Elemento eliminado en (", snappedf(pos.x, 0.1), ", ", snappedf(pos.y, 0.1), ", ", snappedf(pos.z, 0.1), ")")
	_objetivo.queue_free()
	_objetivo = null
	_valido = false
	_material.albedo_color = Color(0.6, 0.6, 0.65, 0.25)


func _actualizar_marcador() -> void:
	if _camara == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origen: Vector3 = _camara.project_ray_origin(mouse)
	var dir: Vector3 = _camara.project_ray_normal(mouse)
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + dir * 2000.0)
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		_valido = false
		_material.albedo_color = ROJO
		return
	_posicion = golpe.position
	var normal: Vector3 = golpe.normal
	_valido = normal.y >= 0.85 and _posicion.y >= 1.5
	if _valido:
		for c in _colocados:
			if Vector2(c.x, c.z).distance_to(Vector2(_posicion.x, _posicion.z)) < DISTANCIA_MIN:
				_valido = false
				break
	_material.albedo_color = VERDE if _valido else ROJO
	_marcador.position = _posicion + Vector3(0, 0.25, 0)


func _colocar() -> void:
	_actualizar_marcador()
	if not _valido:
		return
	var objetitos := get_node_or_null("../Objetos")
	if objetitos != null and objetitos.has_method("despejar_en"):
		objetitos.despejar_en(_posicion.x, _posicion.z, 5.0, 5.0)
	_instanciar(_modo, _posicion)


func _instanciar(indice: int, pos: Vector3) -> Node3D:
	var modelo: Node3D = MODELOS[indice].instantiate()
	add_child(modelo)
	var escala: float = ESCALAS[indice]
	modelo.scale = Vector3(escala, escala, escala)
	var desfase: float = DESFASE_BASE[indice] * escala
	modelo.position = pos + Vector3(0, desfase, 0)
	if _camara != null:
		var d := _camara.global_position - pos
		if Vector2(d.x, d.z).length() > 0.01:
			modelo.rotation.y = atan2(d.x, d.z)
	_activar_animaciones(modelo)
	_colocados.append(pos)
	_instanciados.append(modelo)
	print(NOMBRES[indice], " colocado en (", snappedf(pos.x, 0.1), ", ", snappedf(pos.y, 0.1), ", ", snappedf(pos.z, 0.1), ")")
	return modelo


# Utilidad de depuracion: usada por tools/captura_modelos.gd
func auto_colocar(indice: int, px: float, pz: float) -> void:
	if _terreno == null:
		return
	var h: float = _terreno.altura_en(px, pz)
	_instanciar(indice, Vector3(px, h, pz))


func _activar_animaciones(raiz: Node) -> void:
	var players: Array[AnimationPlayer] = []
	_recolectar(raiz, players)
	if players.is_empty():
		return
	var principal := players[0]
	var primero := true
	for nombre_sz: StringName in principal.get_animation_list():
		var nombre := String(nombre_sz)
		var anim := principal.get_animation(nombre)
		anim.loop_mode = Animation.LOOP_LINEAR
		if primero:
			principal.play(nombre)
			primero = false
		else:
			var base: Node = principal.get_node(principal.root_node)
			var ap := AnimationPlayer.new()
			ap.name = "Anim_%s" % nombre
			base.add_child(ap)
			var lib := AnimationLibrary.new()
			lib.add_animation(nombre, anim)
			ap.add_animation_library("", lib)
			ap.play(nombre)


func _recolectar(n: Node, salida: Array[AnimationPlayer]) -> void:
	if n is AnimationPlayer:
		salida.append(n)
	for h in n.get_children():
		_recolectar(h, salida)
