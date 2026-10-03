extends SceneTree

const OUT := "C:/Users/stive/AppData/Local/Temp/opencode/"

var _f := 0
var _escena: Node
var _cam: Camera3D


func _initialize() -> void:
	_escena = load("res://scenes/isla.tscn").instantiate()
	root.add_child(_escena)
	_cam = _escena.get_node("Camara")
	print("Captura: escena cargada")


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		30:
			_disparar("veg_01_general.png")
			_mover(Vector3(-32.5, 13.6, -56.3), 70.0, 0.6, -0.45)
		70:
			_disparar("veg_02_ciudad.png")
			_mover(Vector3(0, 14, 0), 110.0, 0.0, -0.45)
		110:
			_disparar("veg_03_cascada.png")
			_mover(Vector3(134.4, 4, -134.4), 75.0, 0.7, -0.5)
		150:
			_disparar("veg_04_isla_pequena.png")
			quit()
	return false


func _mover(obj: Vector3, dist: float, yaw: float, pitch: float) -> void:
	_cam.set("objetivo", obj)
	_cam.set("distancia", dist)
	_cam.set("angulo_yaw", yaw)
	_cam.set("angulo_pitch", pitch)
	_cam.call("_actualizar")


func _disparar(nombre: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + nombre)
	print("Captura guardada: ", nombre, " ", img.get_width(), "x", img.get_height())
