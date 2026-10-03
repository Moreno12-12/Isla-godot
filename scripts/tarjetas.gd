extends CanvasLayer

const TITULOS: Array[String] = ["PANEL SOLAR", "MOLINO EOLICO", "TURBINA HIDRAULICA", "BATERIA"]


func _ready() -> void:
	layer = 10
	_construir()


func _construir() -> void:
	var contenedor := HBoxContainer.new()
	contenedor.name = "Tarjetas"
	contenedor.add_theme_constant_override("separation", 16)
	add_child(contenedor)

	for i in TITULOS.size():
		contenedor.add_child(_crear_tarjeta(TITULOS[i]))

	await get_tree().process_frame
	contenedor.reset_size()
	var s := contenedor.size
	if s.x < 1.0 or s.y < 1.0:
		s = contenedor.get_combined_minimum_size()
		contenedor.size = s
	_centrar(contenedor)
	get_viewport().size_changed.connect(_centrar.bind(contenedor))
	print("Tarjetas: size=", s, " pos=", contenedor.position, " viewport=", get_viewport().get_visible_rect().size)


func _centrar(contenedor: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	contenedor.position = Vector2(
		(vs.x - contenedor.size.x) * 0.5,
		vs.y - contenedor.size.y - 24.0
	)


func _crear_tarjeta(titulo: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.78)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	panel.add_theme_stylebox_override("panel", sb)

	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.add_theme_font_size_override("font_size", 16)
	lbl_titulo.add_theme_color_override("font_color", Color(0.91, 0.78, 0.48))
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl_titulo)

	return panel
