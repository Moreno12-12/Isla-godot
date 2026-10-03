extends SceneTree

func _initialize() -> void:
	for path in ["res://models/molino_eolico.glb", "res://models/turbina_pelton.glb", "res://models/panel_solar.glb", "res://models/bateria.glb"]:
		var escena: PackedScene = load(path)
		if escena == null:
			print("FALLO_CARGA ", path)
			continue
		var nodo: Node = escena.instantiate()
		print("=== ", path, " raiz=", nodo.get_class(), " nombre=", nodo.name)
		_buscar_anim(nodo)
		nodo.free()
	quit()

func _buscar_anim(n: Node) -> void:
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		var clips: PackedStringArray = ap.get_animation_list()
		print("  ANIM_PLAYER clips=", clips)
		for c in clips:
			var anim := ap.get_animation(c)
			print("    clip=", c, " dur=", anim.length, " loop=", anim.loop_mode, " tracks=", anim.get_track_count())
	for h in n.get_children():
		_buscar_anim(h)
