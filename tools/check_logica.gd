extends SceneTree

var _ok := true


func _initialize() -> void:
	_ejecutar()


func _fallo(msg: String) -> void:
	_ok = false
	print("FALLO: ", msg)


func _ejecutar() -> void:
	var escena: PackedScene = load("res://scenes/isla.tscn")
	var raiz := escena.instantiate()
	get_root().add_child(raiz)
	await process_frame
	await process_frame

	var logica := raiz.get_node("Logica")
	var modelos := raiz.get_node("Modelos")
	var cascada := raiz.get_node("Cascada")
	var ui := raiz.get_node("CapaUI")

	if logica == null or modelos == null or cascada == null or ui == null:
		_fallo("faltan nodos")
		_fin()
		return

	# 1) clima forzado + HUD
	logica.forzar_clima(0)
	if not logica.panel_activo:
		_fallo("panel debe estar activo en SOL")
	if logica.molino_activo:
		_fallo("molino no debe estar activo en SOL")
	logica.forzar_clima(1)
	if logica.panel_activo:
		_fallo("panel NO debe funcionar en NUBLADO")
	if logica.molino_activo:
		_fallo("molino no debe funcionar en NUBLADO")
	logica.forzar_clima(2)
	if logica.panel_activo:
		_fallo("panel NO debe funcionar en LLUVIOSO")
	if not logica.molino_activo:
		_fallo("molino debe funcionar en LLUVIOSO (viento)")
	if not ui.has_method("set_clima_ui"):
		_fallo("UI sin set_clima_ui")

	# 2) cambio aleatorio de clima (siempre distinto del anterior)
	var c0: int = logica.clima
	for i in 6:
		logica.cambiar_clima()
		if logica.clima == c0:
			_fallo("cambiar_clima repitió clima")
		c0 = logica.clima

	# 3) turbina cerca vs lejos de la cascada
	var puntos: Array[Vector2] = cascada.puntos
	if puntos.is_empty():
		_fallo("cascada sin puntos")
		_fin()
		return
	var medio: Vector2 = puntos[puntos.size() / 2]
	modelos.auto_colocar(2, medio.x + 4.0, medio.y)
	modelos.auto_colocar(2, -32.5, -56.3)
	logica.refrescar()
	var tipos: Array[int] = modelos.tipos()
	if tipos.size() != 2:
		_fallo("tipos() debe tener 2 turbina, tiene %d" % tipos.size())
	if not logica.turbina_activa:
		_fallo("turbina junto a cascada debe estar activa")

	# quitar la turbina lejana: sigue activa por la cercana
	var insts: Array[Node3D] = modelos.instancias()
	modelos._eliminar(insts[1])
	logica.refrescar()
	if not logica.turbina_activa:
		_fallo("turbina cercana debe seguir activa")

	# quitar la cercana: ninguna activa
	insts = modelos.instancias()
	modelos._eliminar(insts[0])
	logica.refrescar()
	if logica.turbina_activa:
		_fallo("sin turbinas no puede haber turbina activa")
	if not tipos.is_empty() and not modelos.tipos().is_empty():
		_fallo("tipos() debería quedar vacío")

	# 4) panel + molino juntos
	modelos.auto_colocar(0, 10.0, 40.0)
	modelos.auto_colocar(1, -60.0, 30.0)
	logica.forzar_clima(0)
	if not logica.panel_activo:
		_fallo("panel con SOL")
	logica.forzar_clima(2)
	if not logica.molino_activo:
		_fallo("molino con LLUVIOSO")

	print("check_logica: ", "OK" if _ok else "HAY FALLOS")
	_fin()


func _fin() -> void:
	quit(0 if _ok else 1)
