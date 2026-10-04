extends CanvasLayer

signal tarjeta_pulsada(indice: int)

const TITULOS: Array[String] = ["PANEL SOLAR", "MOLINO EOLICO", "TURBINA HIDRAULICA", "BATERIA", "ELIMINAR"]
const CLICKABLE: Array[int] = [0, 1, 2, 3, 4]

const ICONOS: Dictionary = {
	"PANEL SOLAR": "res://ui/panel_solar.png",
	"MOLINO EOLICO": "res://ui/molino_eolico.png",
	"TURBINA HIDRAULICA": "res://ui/turbina_hidraulica.png",
	"BATERIA": "res://ui/bateria.png",
	"ELIMINAR": "res://ui/prohibido.png",
}

var _paneles: Array[PanelContainer] = []
var _estilos: Array[StyleBoxFlat] = []
var _seleccion := -1
var _celdas_clima: Array = []
var _icono_clima_grande: IconoClima = null
var _lbl_tiempo: Label = null

const CAMPOS: Array = [
	["ENERGIA GENERADA", "1.250 kWh"],
	["CONSUMO DE LA CIUDAD", "980 kWh"],
	["CO2/IMPACTO AMBIENTAL", "Bajo -45%"],
	["ALMACENAMIENTO", "75%"],
]

const ESQUINA: Array = [
	["ESTADO AMBIENTAL", "—"],
	["LA CIUDAD NECESITA", "—"],
]

const CLIMA: Array = [
	["SOL", true],
	["NUBES", false],
	["LLUVIA", false],
]

const TEXTOS_TIEMPO: Array[String] = ["TIEMPO SOLEADO", "TIEMPO NUBLADO", "TIEMPO LLUVIOSO"]


class IconoClima extends Control:
	var tipo := 0
	var activo := true
	var escala := 1.0

	func _init(p_tipo: int, p_activo: bool) -> void:
		tipo = p_tipo
		activo = p_activo
		custom_minimum_size = Vector2(30, 27)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centro := Vector2(size.x * 0.5, size.y * 0.45)
		if tipo == 0:
			var col := Color(0.95, 0.75, 0.2) if activo else Color(0.55, 0.55, 0.58, 0.75)
			draw_circle(centro, 6.5 * escala, col)
			for i in 8:
				var ang := TAU * float(i) / 8.0
				var dir := Vector2(cos(ang), sin(ang))
				draw_line(centro + dir * 9.0 * escala, centro + dir * 12.5 * escala, col, 2.0 * escala)
		else:
			var nube := Color(0.85, 0.87, 0.9) if activo else Color(0.55, 0.57, 0.62, 0.75)
			var base_y := 17.0 if tipo == 1 else 14.0
			draw_circle(Vector2(10.0, base_y), 6.0, nube)
			draw_circle(Vector2(18.0, base_y - 3.5), 8.0, nube)
			draw_circle(Vector2(26.0, base_y), 5.5, nube)
			draw_rect(Rect2(9.0, base_y - 1.0, 18.0, 7.0), nube)
			if tipo == 2:
				var gota := Color(0.4, 0.6, 0.95) if activo else Color(0.4, 0.45, 0.55, 0.75)
				for i in 4:
					var gx := 10.0 + float(i) * 5.5
					draw_line(Vector2(gx, base_y + 8.0), Vector2(gx - 2.0, base_y + 13.0), gota, 2.0)


func _ready() -> void:
	layer = 10
	_construir()


func _construir() -> void:
	var recuadro_campos := _crear_recuadro("RecuadroCampos")
	add_child(recuadro_campos)
	var campos := HBoxContainer.new()
	campos.name = "Campos"
	campos.add_theme_constant_override("separation", 0)
	recuadro_campos.add_child(campos)

	for c in CAMPOS:
		campos.add_child(_crear_campo(str(c[0]), str(c[1])))

	var recuadro := PanelContainer.new()
	recuadro.name = "RecuadroTarjetas"
	var sb_rec := StyleBoxFlat.new()
	sb_rec.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	sb_rec.set_corner_radius_all(12)
	sb_rec.set_border_width_all(1)
	sb_rec.border_color = Color(1, 1, 1, 0.3)
	sb_rec.set_content_margin_all(8)
	recuadro.add_theme_stylebox_override("panel", sb_rec)
	add_child(recuadro)

	var contenedor := HBoxContainer.new()
	contenedor.name = "Tarjetas"
	contenedor.add_theme_constant_override("separation", 10)
	recuadro.add_child(contenedor)

	for i in TITULOS.size():
		contenedor.add_child(_crear_tarjeta(TITULOS[i], i))

	var esquina := VBoxContainer.new()
	esquina.name = "Esquina"
	esquina.add_theme_constant_override("separation", 0)
	add_child(esquina)

	for c in ESQUINA:
		esquina.add_child(_crear_campo(str(c[0]), str(c[1])))

	var recuadro_clima := _crear_recuadro("RecuadroClima")
	add_child(recuadro_clima)
	var vbox_clima := VBoxContainer.new()
	vbox_clima.name = "ClimaVBox"
	vbox_clima.add_theme_constant_override("separation", 6)
	vbox_clima.alignment = BoxContainer.ALIGNMENT_CENTER
	recuadro_clima.add_child(vbox_clima)

	var fila_tiempo := HBoxContainer.new()
	fila_tiempo.name = "FilaTiempo"
	fila_tiempo.add_theme_constant_override("separation", 8)
	fila_tiempo.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_clima.add_child(fila_tiempo)

	var sol_grande := IconoClima.new(0, true)
	sol_grande.custom_minimum_size = Vector2(40, 34)
	sol_grande.escala = 1.2
	fila_tiempo.add_child(sol_grande)
	_icono_clima_grande = sol_grande

	_lbl_tiempo = Label.new()
	_lbl_tiempo.text = TEXTOS_TIEMPO[0]
	_lbl_tiempo.add_theme_font_size_override("font_size", 14)
	_lbl_tiempo.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48))
	_lbl_tiempo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila_tiempo.add_child(_lbl_tiempo)

	var clima := HBoxContainer.new()
	clima.name = "Clima"
	clima.add_theme_constant_override("separation", 0)
	vbox_clima.add_child(clima)

	for i in CLIMA.size():
		clima.add_child(_crear_celda_clima(str(CLIMA[i][0]), bool(CLIMA[i][1]), i))

	await get_tree().process_frame
	for pair in [[recuadro_campos, _centrar_arriba], [recuadro, _centrar]]:
		var c: Control = pair[0]
		var centrar: Callable = pair[1]
		c.reset_size()
		var s := c.size
		if s.x < 1.0 or s.y < 1.0:
			s = c.get_combined_minimum_size()
			c.size = s
		centrar.call(c)
		get_viewport().size_changed.connect(centrar.bind(c))

	esquina.reset_size()
	if esquina.size.x < 1.0:
		esquina.size = esquina.get_combined_minimum_size()
	_colocar_esquina(esquina, recuadro)
	get_viewport().size_changed.connect(_colocar_esquina.bind(esquina, recuadro))

	recuadro_clima.reset_size()
	if recuadro_clima.size.x < 1.0:
		recuadro_clima.size = recuadro_clima.get_combined_minimum_size()
	_centrar_arriba_derecha(recuadro_clima)
	get_viewport().size_changed.connect(_centrar_arriba_derecha.bind(recuadro_clima))

	print("Campos: size=", recuadro_campos.size, " pos=", recuadro_campos.position, " viewport=", get_viewport().get_visible_rect().size)
	print("Clima: size=", recuadro_clima.size, " pos=", recuadro_clima.position, " viewport=", get_viewport().get_visible_rect().size)
	print("Esquina: size=", esquina.size, " pos=", esquina.position, " viewport=", get_viewport().get_visible_rect().size)
	print("Tarjetas: size=", recuadro.size, " pos=", recuadro.position, " viewport=", get_viewport().get_visible_rect().size)


func _centrar_arriba(contenedor: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	contenedor.position = Vector2(
		(vs.x - contenedor.size.x) * 0.5,
		20.0
	)


func _centrar_arriba_derecha(clima: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	clima.position = Vector2(
		vs.x - clima.size.x - 24.0,
		20.0
	)


func _colocar_esquina(esquina: Control, tarjetas: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	esquina.position = Vector2(
		vs.x - esquina.size.x - 24.0,
		vs.y - esquina.size.y - 24.0
	)


func _centrar(contenedor: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	contenedor.position = Vector2(
		(vs.x - contenedor.size.x) * 0.5,
		vs.y - contenedor.size.y - 24.0
	)


func _crear_recuadro(nombre: String) -> PanelContainer:
	var recuadro := PanelContainer.new()
	recuadro.name = nombre
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_content_margin_all(6)
	recuadro.add_theme_stylebox_override("panel", sb)
	return recuadro


func _crear_campo(titulo: String, valor: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(0)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.add_theme_font_size_override("font_size", 11)
	lbl_titulo.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48, 0.85))
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_titulo)

	var lbl_valor := Label.new()
	lbl_valor.text = valor
	lbl_valor.add_theme_font_size_override("font_size", 14)
	lbl_valor.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_valor)

	return panel


func _crear_celda_clima(titulo: String, activo: bool, tipo: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if activo:
		sb.bg_color = Color(0.16, 0.17, 0.2, 0.92)
		sb.border_color = Color(0.91, 0.78, 0.48, 0.85)
	else:
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.7)
		sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icono := IconoClima.new(tipo, activo)
	icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icono)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 10)
	if activo:
		lbl.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48))
	else:
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	_celdas_clima.append([panel, sb, icono, lbl])

	return panel


func set_clima_ui(i: int) -> void:
	for idx in _celdas_clima.size():
		var c: Array = _celdas_clima[idx]
		var activo := idx == i
		var sb: StyleBoxFlat = c[1]
		if activo:
			sb.bg_color = Color(0.16, 0.17, 0.2, 0.92)
			sb.border_color = Color(0.91, 0.78, 0.48, 0.85)
		else:
			sb.bg_color = Color(0.08, 0.09, 0.12, 0.7)
			sb.border_color = Color(1, 1, 1, 0.15)
		var icono: IconoClima = c[2]
		icono.activo = activo
		icono.queue_redraw()
		var lbl: Label = c[3]
		lbl.add_theme_color_override("font_color",
				Color(0.91, 0.78, 0.48) if activo else Color(1, 1, 1, 0.45))
	if _icono_clima_grande != null:
		_icono_clima_grande.tipo = i
		_icono_clima_grande.queue_redraw()
	if _lbl_tiempo != null:
		_lbl_tiempo.text = TEXTOS_TIEMPO[clampi(i, 0, TEXTOS_TIEMPO.size() - 1)]


func _crear_tarjeta(titulo: String, indice: int = -1) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.78)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	if titulo in ICONOS:
		var icono := TextureRect.new()
		icono.texture = load(ICONOS[titulo])
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.custom_minimum_size = Vector2(40, 40)
		icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		vbox.add_child(icono)

	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.add_theme_font_size_override("font_size", 13)
	if titulo == "ELIMINAR":
		lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
	else:
		lbl_titulo.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48))
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_titulo)

	if indice >= 0:
		_paneles.append(panel)
		_estilos.append(sb)
	if indice in CLICKABLE:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_al_pulsar.bind(indice))

	return panel


func _al_pulsar(event: InputEvent, indice: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resaltar(indice)
		tarjeta_pulsada.emit(indice)


func _resaltar(indice: int) -> void:
	_seleccion = indice
	for i in _estilos.size():
		var seleccionada := _paneles[i] != null and _seleccion == i
		_estilos[i].border_color = Color(0.91, 0.78, 0.48, 1.0) if seleccionada else Color(1, 1, 1, 0.15)
		_estilos[i].border_width_top = 2 if seleccionada else 1
		_estilos[i].border_width_bottom = 2 if seleccionada else 1
		_estilos[i].border_width_left = 2 if seleccionada else 1
		_estilos[i].border_width_right = 2 if seleccionada else 1
