extends SceneTree

# Captura la isla con molino y turbina auto-colocados (3 vistas).
# Uso: Godot_v4.7.2-stable_win64.exe --path <proyecto> --script tools/captura_modelos.gd

var _frames := 0
var _fase := 0
var _modelos: Node3D
var _terreno: Node
var _camara: Camera3D
var _base := "C:/Users/stive/AppData/Local/Temp/opencode/molino/test/"


func _initialize() -> void:
	var err := change_scene_to_file("res://scenes/isla.tscn")
	if err != OK:
		push_error("No se pudo cargar la escena: %d" % err)
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	match _fase:
		0:
			if _frames < 30:
				return false
			if !_arrancar():
				return true
			_colocar()
			_encuadrar(_molino_pos, 60.0, _molino_pos.y + 6.0)
			_fase = 1
		1:
			if _frames < 90:
				return false
			_guardar("godot_molino.png")
			_encuadrar(_turbina_pos, 34.0, _turbina_pos.y + 4.0)
			_fase = 2
		2:
			if _frames < 150:
				return false
			_guardar("godot_turbina.png")
			_encuadrar(Vector3.ZERO, 260.0, 4.0)
			_fase = 3
		3:
			if _frames < 210:
				return false
			_guardar("godot_captura.png")
			quit()
			return true
	return false


func _arrancar() -> bool:
	if _modelos != null:
		return true
	_modelos = current_scene.get_node_or_null("Modelos")
	_terreno = current_scene.get_node_or_null("Terreno")
	_camara = current_scene.get_node_or_null("Camara")
	if _modelos == null or _terreno == null or _camara == null:
		push_error("Faltan nodos Modelos/Terreno/Camara")
		quit(1)
		return false
	return true


var _molino_pos := Vector3.ZERO
var _turbina_pos := Vector3.ZERO


func _colocar() -> void:
	# molino: sitio alto y expuesto
	var mejor := Vector2(0, 0)
	var mejor_h := -1000.0
	for i in 150:
		var x := lerpf(-60.0, 60.0, float(randi() % 1000) / 1000.0)
		var z := lerpf(-60.0, 60.0, float(randi() % 1000) / 1000.0)
		var h: float = _terreno.altura_en(x, z)
		if h > mejor_h and _terreno.normal_en(x, z).y > 0.9:
			mejor_h = h
			mejor = Vector2(x, z)
	_molino_pos = Vector3(mejor.x, mejor_h, mejor.y)
	_modelos.auto_colocar(1, mejor.x, mejor.y)
	print("Captura: molino en ", mejor, " h=", mejor_h)

	# turbina: sitio bajo y plano
	var mejor2 := Vector2(12, 60)
	var mejor_h2 := 1000.0
	for i in 150:
		var x := lerpf(-64.0, 64.0, float(randi() % 1000) / 1000.0)
		var z := lerpf(-64.0, 64.0, float(randi() % 1000) / 1000.0)
		var h: float = _terreno.altura_en(x, z)
		if h > 1.5 and h < mejor_h2 and _terreno.normal_en(x, z).y > 0.9:
			mejor_h2 = h
			mejor2 = Vector2(x, z)
	_turbina_pos = Vector3(mejor2.x, mejor_h2, mejor2.y)
	_modelos.auto_colocar(2, mejor2.x, mejor2.y)
	_leer_reales()
	print("Captura: turbina en ", mejor2, " h=", mejor_h2)


# Encuadra usando la posicion real de los nodos instanciados (evita cruces).
func _leer_reales() -> void:
	for h in _modelos.get_children():
		if h is not Node3D or h.name == "Marcador":
			continue
		var p: Vector3 = h.global_position
		var n := String(h.name).to_lower()
		print("  hijo: ", h.name, " en ", p)
		if n.find("molino") >= 0:
			_molino_pos = p
		elif n.find("turbina") >= 0:
			_turbina_pos = p
	print("  encuadres: molino=", _molino_pos, " turbina=", _turbina_pos)


# Dibuja un punto de referencia visible para saber donde queda cada modelo.
func _reportar(nombre: String) -> void:
	var tam := _camara.get_viewport().get_visible_rect().size
	for h in _modelos.get_children():
		if h is not Node3D or h.name == "Marcador":
			continue
		var centro: Vector3 = h.global_position + Vector3(0, 6, 0)
		var pantalla: Vector2 = _camara.unproject_position(centro)
		var dentro := pantalla.x >= 0 and pantalla.y >= 0 and pantalla.x <= tam.x and pantalla.y <= tam.y
		var dist := _camara.global_position.distance_to(h.global_position)
		print("  [%s] %s -> pantalla=(%.0f, %.0f) dentro=%s dist=%.1f" % [nombre, h.name, pantalla.x, pantalla.y, dentro, dist])


func _encuadrar(objetivo: Vector3, dist: float, alto: float) -> void:
	var cam := _camara
	if cam.has_method("set"):
		cam.set("objetivo", Vector3(objetivo.x, alto, objetivo.z))
		cam.set("distancia", dist)
		cam.set("angulo_yaw", 0.7)
		cam.set("angulo_pitch", -0.35)
		if cam.has_method("_actualizar"):
			cam.call("_actualizar")


func _guardar(nombre: String) -> void:
	_reportar(nombre)
	var vp := _camara.get_viewport()
	var t: Texture2D = vp.get_texture()
	var img: Image = t.get_image() if t != null else null
	if img == null:
		push_error("Sin textura de viewport: " + nombre)
		quit(1)
		return
	var destino := _base + nombre
	var err := img.save_png(destino)
	if err != OK:
		push_error("No se pudo guardar " + nombre + ": %d" % err)
		quit(1)
		return
	print("Captura guardada en ", destino)
