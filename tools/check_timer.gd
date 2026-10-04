extends SceneTree


func _initialize() -> void:
	_ejecutar()


func _ejecutar() -> void:
	var escena: PackedScene = load("res://scenes/isla.tscn")
	var raiz := escena.instantiate()
	get_root().add_child(raiz)
	await process_frame
	var logica := raiz.get_node("Logica")
	var c0: int = logica.clima
	print("check_timer: esperando cambio automatico (180s)...")
	await create_timer(200.0).timeout
	print("check_timer: clima antes=", c0, " ahora=", logica.clima)
	var ok: bool = logica.clima != c0
	print("check_timer: ", "OK" if ok else "FALLO")
	quit(0 if ok else 1)
