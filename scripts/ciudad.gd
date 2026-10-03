extends Node3D

const CIUDAD: PackedScene = preload("res://models/ciudad.glb")
const ESCALA := 0.3
const MARGEN := 0.1
const MEDIO_LOSA := 28.5
const MUESTRAS := 15

var _colocado := false


func _ready() -> void:
	call_deferred("_colocar")


func _colocar() -> void:
	if _colocado:
		return
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_warning("Ciudad: sin terreno")
		return

	var centro: Vector2 = terreno.CIUDAD_CENTRO
	var altura: float = terreno.CIUDAD_ALTURA
	var radio_ext: float = terreno.CIUDAD_RADIO + terreno.CIUDAD_TRANSICION

	# Diagnostico: desnivel bajo la losa (debe ser ~0 en la meseta)
	var h_min := 1000.0
	var h_max := -1000.0
	for i in MUESTRAS:
		for j in MUESTRAS:
			var ox := lerpf(-MEDIO_LOSA, MEDIO_LOSA, float(i) / float(MUESTRAS - 1))
			var oz := lerpf(-MEDIO_LOSA, MEDIO_LOSA, float(j) / float(MUESTRAS - 1))
			var h: float = terreno.altura_en(centro.x + ox, centro.y + oz)
			h_min = minf(h_min, h)
			h_max = maxf(h_max, h)

	# Diagnostico: distancia minima a la costa (radiando en 8 direcciones)
	var dist_costa := 999.0
	for k in 8:
		var ang := TAU * float(k) / 8.0
		var d := radio_ext
		while d < 140.0:
			var v: float = terreno.altura_en(centro.x + cos(ang) * d, centro.y + sin(ang) * d)
			if v < terreno.COSTA_NIVEL:
				break
			d += 1.0
		dist_costa = minf(dist_costa, d)

	# Diagnostico: distancia a lagunas
	var dist_laguna := 999.9
	for lg in [Vector2(-45, 31.5), Vector2(48, -28.5), Vector2(12, 60)]:
		dist_laguna = minf(dist_laguna, centro.distance_to(lg))

	var ciudad: Node3D = CIUDAD.instantiate()
	add_child(ciudad)
	ciudad.scale = Vector3(ESCALA, ESCALA, ESCALA)
	ciudad.position = Vector3(centro.x, altura + MARGEN, centro.y)
	_colocado = true

	print("Ciudad en isla principal (", snappedf(centro.x, 0.1), ", ",
			snappedf(altura + MARGEN, 0.1), ", ", snappedf(centro.y, 0.1),
			") escala=", ESCALA,
			" desnivel=", snappedf(h_max - h_min, 0.2),
			" m | costa_min=", snappedf(dist_costa - radio_ext, 0.1),
			" m | laguna_min=", snappedf(dist_laguna, 0.1), " m")
