extends Node3D

const Y_TARIMA := -8.4
const Y_PLANO := -9.2
const COSTA_NIVEL := -9.2
const ANCHO := 3.4
const MADERA := Color(0.5, 0.33, 0.2)
const MADERA_OSCURA := Color(0.4, 0.26, 0.15)


func _ready() -> void:
	call_deferred("_construir")


func _construir() -> void:
	var terreno := get_node_or_null("../Terreno")
	if terreno == null:
		push_error("Puentes: no encuentra Terreno")
		return
	for k in terreno.ISLAS.size():
		_puente(terreno, terreno.ISLAS[k], k)


func _puente(terreno: Node3D, isla: Vector2, idx: int) -> void:
	var u := isla.normalized()
	var p_isla := Vector2.ZERO
	var p_main := Vector2.ZERO
	var fase := 0
	var racha := 0
	var s := 1.0
	while s < 90.0 and fase < 2:
		var p := isla - u * s
		var h: float = terreno.altura_en(p.x, p.y)
		if fase == 0:
			if h < COSTA_NIVEL:
				p_isla = p
				fase = 1
				racha = 0
		else:
			if h >= COSTA_NIVEL:
				racha += 1
				if racha >= 6:
					p_main = isla - u * (s - 5.0)
					fase = 2
			else:
				racha = 0
		s += 1.0
	if fase < 2:
		push_warning("Puente %d: no se encontró el hueco (isla=%s)" % [idx, isla])
		return

	var a := p_isla + u * 3.0
	var b := p_main - u * 3.0
	var d2 := b - a
	var largo := d2.length()
	var hueco := p_isla.distance_to(p_main)
	if largo < 4.0:
		push_warning("Puente %d: hueco demasiado corto (%.1f)" % [idx, largo])
		return

	var raiz := Node3D.new()
	raiz.name = "Puente%d" % (idx + 1)
	raiz.position = Vector3((a.x + b.x) * 0.5, 0.0, (a.y + b.y) * 0.5)
	raiz.rotation.y = atan2(-d2.y, d2.x)
	add_child(raiz)

	var madera := _mat(MADERA)
	var oscura := _mat(MADERA_OSCURA)

	var x := -largo * 0.5 + 0.55
	while x < largo * 0.5:
		_caja(raiz, Vector3(1.0, 0.16, ANCHO), Vector3(x, Y_TARIMA, 0.0), madera)
		x += 1.1

	for lado in [-1.0, 1.0]:
		var z: float = lado * (ANCHO * 0.5 - 0.06)
		_caja(raiz, Vector3(largo, 0.1, 0.12), Vector3(0.0, -7.5, z), oscura)
		var px := -largo * 0.5 + 0.3
		while px <= largo * 0.5:
			_caja(raiz, Vector3(0.14, 1.0, 0.14), Vector3(px, -7.9, z), oscura)
			px += 2.4

	var pilares := 0
	var qx := -largo * 0.5 + 2.0
	while qx <= largo * 0.5 - 1.0:
		for lado in [-1.0, 1.0]:
			_caja(raiz, Vector3(0.35, 0.95, 0.35),
					Vector3(qx, (Y_PLANO + Y_TARIMA) * 0.5 - 0.08, lado * (ANCHO * 0.5 - 0.4)),
					oscura)
		pilares += 1
		qx += 4.5

	print("Puente ", idx + 1, ": largo=", snappedf(largo, 0.1),
			" hueco=", snappedf(hueco, 0.1),
			" pares_pilares=", pilares, " en (",
			snappedf(raiz.position.x, 0.1), ", ", snappedf(raiz.position.z, 0.1), ")")


func _caja(raiz: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	raiz.add_child(mi)


var _madera_cache: StandardMaterial3D
var _oscura_cache: StandardMaterial3D


func _mat(color: Color) -> StandardMaterial3D:
	if color == MADERA:
		if _madera_cache == null:
			_madera_cache = StandardMaterial3D.new()
			_madera_cache.albedo_color = color
			_madera_cache.roughness = 1.0
		return _madera_cache
	if _oscura_cache == null:
		_oscura_cache = StandardMaterial3D.new()
		_oscura_cache.albedo_color = color
		_oscura_cache.roughness = 1.0
	return _oscura_cache
