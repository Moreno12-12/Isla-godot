extends Node3D

const INTERVALO_CLIMA := 180.0
const UMBRAL_TURBINA := 18.0
const NOMBRES: Array[String] = ["SOL", "NUBLADO", "LLUVIOSO"]
const LUCES: Array[float] = [1.0, 0.5, 0.35]
const TOPS: Array[Color] = [
	Color(0.25, 0.5, 0.85), Color(0.55, 0.6, 0.65), Color(0.35, 0.4, 0.48),
]
const HORIZONTES: Array[Color] = [
	Color(0.64, 0.66, 0.67), Color(0.7, 0.72, 0.75), Color(0.5, 0.53, 0.58),
]
const NIEBLAS: Array[float] = [0.0012, 0.002, 0.003]

var clima := 0
var panel_activo := true
var molino_activo := false
var turbina_activa := false

var _ui
var _modelos
var _cascada
var _sol: DirectionalLight3D
var _entorno: WorldEnvironment
var _lluvia: GPUParticles3D
var _timer: Timer


func _ready() -> void:
	_ui = get_node_or_null("../CapaUI")
	_modelos = get_node_or_null("../Modelos")
	_cascada = get_node_or_null("../Cascada")
	_sol = get_node_or_null("../Sol")
	_entorno = get_node_or_null("../Entorno")
	_crear_lluvia()
	_timer = Timer.new()
	_timer.wait_time = INTERVALO_CLIMA
	_timer.timeout.connect(cambiar_clima)
	add_child(_timer)
	_timer.start()
	_aplicar_clima()
	refrescar()
	print("Logica: clima inicial ", NOMBRES[clima], " (cambio cada ",
			int(INTERVALO_CLIMA), "s)")


func cambiar_clima() -> void:
	clima = int((clima + 1 + randi_range(0, 1)) % 3)
	_aplicar_clima()
	refrescar()
	print("Logica: clima ahora ", NOMBRES[clima])


func forzar_clima(i: int) -> void:
	clima = clampi(i, 0, 2)
	_aplicar_clima()
	refrescar()
	print("Logica: clima forzado ", NOMBRES[clima])


func _aplicar_clima() -> void:
	if _ui != null and _ui.has_method("set_clima_ui"):
		_ui.set_clima_ui(clima)
	if _sol != null:
		_sol.light_energy = LUCES[clima]
	if _entorno != null:
		var env: Environment = _entorno.environment
		var cielo := env.sky.sky_material as ProceduralSkyMaterial
		if cielo != null:
			cielo.sky_top_color = TOPS[clima]
			cielo.sky_horizon_color = HORIZONTES[clima]
		env.fog_light_color = HORIZONTES[clima]
		env.fog_density = NIEBLAS[clima]
	if _lluvia != null:
		_lluvia.visible = clima == 2
		_lluvia.emitting = clima == 2


func refrescar() -> void:
	panel_activo = clima == 0
	molino_activo = clima == 2
	var n_panel := 0
	var n_molino := 0
	var n_turb := 0
	var cerca := 0
	if _modelos != null and _modelos.has_method("tipos"):
		var tipos: Array[int] = _modelos.tipos()
		var insts: Array[Node3D] = _modelos.instancias()
		for i in tipos.size():
			if i >= insts.size() or not is_instance_valid(insts[i]):
				continue
			match tipos[i]:
				0:
					n_panel += 1
				1:
					n_molino += 1
				2:
					n_turb += 1
					var pos := Vector2(insts[i].global_position.x,
							insts[i].global_position.z)
					if _cerca_cascada(pos):
						cerca += 1
	var act_panel := n_panel if panel_activo else 0
	var act_molino := n_molino if molino_activo else 0
	turbina_activa = cerca > 0
	print("Logica: ", NOMBRES[clima], " | paneles ", act_panel, "/", n_panel,
			" | molinos ", act_molino, "/", n_molino,
			" | turbinas ", cerca, "/", n_turb, " cerca")


func _cerca_cascada(pos: Vector2) -> bool:
	if _cascada == null:
		return false
	var puntos = _cascada.puntos
	if puntos == null:
		return false
	for p in puntos:
		if pos.distance_to(p) <= UMBRAL_TURBINA:
			return true
	return false


func _crear_lluvia() -> void:
	_lluvia = GPUParticles3D.new()
	_lluvia.name = "Lluvia"
	_lluvia.amount = 800
	_lluvia.lifetime = 4.0
	_lluvia.position = Vector3(0.0, 60.0, 0.0)
	_lluvia.visibility_aabb = AABB(Vector3(-200, -80, -200), Vector3(400, 120, 400))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(180, 30, 180)
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 4.0
	proc.initial_velocity_min = 16.0
	proc.initial_velocity_max = 22.0
	proc.gravity = Vector3(0, -1, 0)
	proc.scale_min = 0.8
	proc.scale_max = 1.3
	proc.color = Color(0.78, 0.85, 0.97, 0.5)
	_lluvia.process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.85)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	quad.material = mat
	_lluvia.draw_pass_1 = quad
	_lluvia.visible = false
	_lluvia.emitting = false
	add_child(_lluvia)
