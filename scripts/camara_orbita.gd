extends Camera3D

@export var objetivo := Vector3(0.0, 4.0, 0.0)
@export var distancia := 150.0
@export var angulo_yaw := 0.6
@export var angulo_pitch := -0.55
@export var sensibilidad := 0.005
@export var vel_zoom := 8.0

var _arrastrando := false


func _ready() -> void:
	_actualizar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distancia = clampf(distancia - vel_zoom, 30.0, 260.0)
			_actualizar()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distancia = clampf(distancia + vel_zoom, 30.0, 260.0)
			_actualizar()
	elif event is InputEventMouseMotion and _arrastrando:
		angulo_yaw -= event.relative.x * sensibilidad
		angulo_pitch = clampf(angulo_pitch - event.relative.y * sensibilidad, -1.35, -0.08)
		_actualizar()


func _actualizar() -> void:
	var offset := Vector3(
		cos(angulo_pitch) * sin(angulo_yaw),
		-sin(angulo_pitch),
		cos(angulo_pitch) * cos(angulo_yaw)
	) * distancia
	global_position = objetivo + offset
	look_at(objetivo, Vector3.UP)
