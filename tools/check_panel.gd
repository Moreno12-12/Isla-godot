extends SceneTree

# Verifica colocacion + animacion del panel solar sin capturar imagenes.

var _frames := 0


func _initialize() -> void:
	var err := change_scene_to_file("res://scenes/isla.tscn")
	if err != OK:
		push_error("escena: %d" % err)
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames != 40:
		return false
	var modelos := current_scene.get_node_or_null("Modelos")
	var terreno := current_scene.get_node_or_null("Terreno")
	if modelos == null or terreno == null:
		push_error("faltan nodos")
		quit(1)
		return true
	# sitio plano y seco
	var x := 20.0
	var z := 25.0
	for i in 80:
		var tx := lerpf(-50.0, 50.0, float(randi() % 1000) / 1000.0)
		var tz := lerpf(-50.0, 50.0, float(randi() % 1000) / 1000.0)
		if terreno.normal_en(tx, tz).y > 0.95 and terreno.altura_en(tx, tz) > 2.0:
			x = tx
			z = tz
			break
	modelos.auto_colocar(0, x, z)
	_comprobar(modelos)
	quit()
	return true


func _comprobar(modelos: Node) -> void:
	var n: Node = null
	for h in modelos.get_children():
		if h is Node3D and h.name != "Marcador":
			n = h
	if n == null:
		push_error("no se coloco nada")
		return
	print("COLOCADO ", n.name, " pos=", n.global_position, " rot_y=", snappedf(n.rotation.y, 0.01), " escala=", n.scale)
	var players: Array[AnimationPlayer] = []
	_buscar(n, players)
	for ap in players:
		for c in ap.get_animation_list():
			var anim := ap.get_animation(c)
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(c)
			print("  clip=", c, " dur=", anim.length, " tracks=", anim.get_track_count(), " reproduciendo=", ap.is_playing())
	# deja correr la animacion y comprueba que avanza
	await create_timer(1.5).timeout
	for ap in players:
		print("  tras 1.5s clip=", ap.get_assigned_animation(), " tiempo=", snappedf(ap.current_animation_position, 0.01))
	print("OK_PANEL")


func _buscar(n: Node, out: Array[AnimationPlayer]) -> void:
	if n is AnimationPlayer:
		out.append(n)
	for h in n.get_children():
		_buscar(h, out)
