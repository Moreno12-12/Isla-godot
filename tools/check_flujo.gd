extends SceneTree

# Verifica el flujo real: pulsar tarjeta -> modo colocacion -> marcador -> colocar -> eliminar.

var _frames := 0
var _hecho := false


func _initialize() -> void:
	var err := change_scene_to_file("res://scenes/isla.tscn")
	if err != OK:
		push_error("escena: %d" % err)
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40 and not _hecho:
		_hecho = true
		_flujo()
	return false


func _flujo() -> void:
	var modelos: Node = current_scene.get_node_or_null("Modelos")
	var ui: Node = current_scene.get_node_or_null("CapaUI")
	var terreno: Node = current_scene.get_node_or_null("Terreno")
	if modelos == null or ui == null or terreno == null:
		push_error("faltan nodos")
		quit(1)
		return
	var marcador: Node = modelos.get_node_or_null("Marcador")

	for indice in [0, 1, 2, 3]:
		_probar_indice(indice, modelos, ui, terreno, marcador)

	var quedan := 0
	for h in modelos.get_children():
		if h is Node3D and h.name != "Marcador" and not h.is_queued_for_deletion():
			quedan += 1
	print("elementos tras probar todos=", quedan, " (esperado 0)")
	print("OK_FLUJO")
	quit()


func _probar_indice(indice: int, modelos: Node, ui: Node, terreno: Node, marcador: Node) -> void:
	print("=== INDICE ", indice, " ===")
	ui.tarjeta_pulsada.emit(indice)
	print("  tras pulsar tarjeta: modo=", modelos.get("_modo"), " marcador_visible=", marcador.visible if marcador else null)
	modelos.call("_actualizar_marcador")

	var x := 0.0
	var z := 0.0
	for i in 80:
		var tx := lerpf(-50.0, 50.0, float(randi() % 1000) / 1000.0)
		var tz := lerpf(-50.0, 50.0, float(randi() % 1000) / 1000.0)
		if terreno.normal_en(tx, tz).y > 0.95 and terreno.altura_en(tx, tz) > 2.0:
			var libre := true
			for c in modelos.get("_colocados"):
				if Vector2(c.x, c.z).distance_to(Vector2(tx, tz)) < 20.0:
					libre = false
					break
			if libre:
				x = tx
				z = tz
				break
	var alto: float = terreno.altura_en(x, z)
	var colocado: Node = modelos.call("_instanciar", indice, Vector3(x, alto, z))
	print("  colocado=", colocado.name if colocado else "NINGUNO",
		" pos=", colocado.global_position if colocado else null)
	_ver_anim(colocado)

	# toggle: segunda pulsacion cancela
	ui.tarjeta_pulsada.emit(indice)
	print("  toggle -> modo=", modelos.get("_modo"))

	# eliminar
	ui.tarjeta_pulsada.emit(4)
	modelos.call("_eliminar", colocado)


func _ver_anim(n: Node) -> void:
	if n is AnimationPlayer:
		for c in n.get_animation_list():
			var ap := n as AnimationPlayer
			print("    clip=", c, " reproduciendo=", ap.is_playing(), " loop=", ap.get_animation(c).loop_mode)
	for h in n.get_children():
		_ver_anim(h)
