class_name Actor
extends Node3D
## Personaje que se mueve por la cuadrícula del barrio. Lo usan el jugador y los bots.
## Se modela con primitivas caricaturizadas (cabezón, cuerpo de bloque) a partir de `look`.
## Cada uno tiene género y rasgos propios (peinado, barba, gafas, chaqueta, falda) para que
## se distingan entre sí, y una silueta que se ve a través de los edificios que lo tapan.

signal arrived

const SCALE := 1.35  ## más grandes que en la realidad para que se lean bien desde arriba
const WALL_PROBE := 0.6  ## margen hasta la pared al moverse con WASD, para no meterse en las fachadas
## Peinados según el género (los dos primeros de cada lista son los más corrientes).
const HAIR_STYLES := {
	"m": ["corto", "rapado", "calvo", "tupe", "rizos", "coleta"],
	"f": ["melena", "coleta", "moño", "corta", "rizos", "rapado"],
}
## Silueta a través de las paredes: color y opacidad por defecto (ver set_silhouette).
const SILHOUETTE := Color(0.85, 0.88, 1.0, 0.35)
const MARKER_Y := 6.2  ## altura del icono flotante, por encima del bocadillo de texto
## Holgura del giro hacia la calle con WASD: se prueban direcciones hasta este ángulo
## a cada lado de la pedida y se elige la libre más parecida.
const STEER_MAX_DEG := 70.0
const STEER_STEP_DEG := 10.0
const STEER_LOOKAHEAD := 3.0  ## metros que tiene que estar libre una dirección para seguirla

var city: CityMap
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var speed := 14.0  ## metros por segundo
var display_name := ""
## Colores y rasgos. Además de skin, shirt, pants y hair, admite (todos opcionales):
## gender ("m"/"f"), hair_style (ver HAIR_STYLES), facial ("", "barba", "bigote"),
## glasses (bool), jacket (color de la chaqueta abierta) y skirt (bool, falda en vez de pantalón).
var look := {
	"skin": Color("d9a77c"), "shirt": Color.GRAY, "pants": Color.DIM_GRAY, "hair": Color.BLACK,
}
var accessory := ""  ## "", "gorra_poli", "mochila", "capucha", "chaleco", "despedida", "bolsa", "caja", "gorra"
var body_size := 1.0  ## multiplicador de tamaño (los chavales son más bajos)
var slow_factor := 1.0
var run_factor := 1.0  ## > 1 al correr (Shift)
var wobble := 0.0  ## 0..1: eses al seguir un camino (alcohol)
## Movimiento directo (WASD) en el plano, de longitud 0..1. Mientras no es cero manda sobre `path`.
var input_dir := Vector3.ZERO

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _bubble: Label3D
var _bubble_time := 0.0
var _walk_phase := 0.0
var _silhouette: ShaderMaterial  ## pasada que pinta al personaje donde lo tapa un edificio
var _marker: Label3D  ## icono flotante (encargos)

static var _materials := {}
static var _outline: StandardMaterial3D
static var _silhouette_shader: Shader = preload("res://shaders/silhouette.gdshader")


func _ready() -> void:
	_build_body()


func setup(p_city: CityMap, p_cell: Vector2i) -> void:
	city = p_city
	cell = city.nearest_walkable(p_cell)
	path.clear()
	position = city.cell_to_world(cell)


func walk_to(target: Vector2i) -> void:
	var p := city.find_path(cell, target)
	if p.size() > 1:
		p.remove_at(0)
		path = p
	else:
		path.clear()
		arrived.emit()


func stop() -> void:
	path.clear()


func is_moving() -> bool:
	return not path.is_empty()


func say(text: String, seconds := 3.0) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = seconds


## Hacia dónde mira, en el plano (unitario). Los bots ven en un cono en esta dirección.
func facing() -> Vector3:
	return Vector3(sin(_body.rotation.y), 0, cos(_body.rotation.y))


func distance_to_cell(other: Vector2i) -> int:
	return maxi(absi(other.x - cell.x), absi(other.y - cell.y))


## Punto de la cabeza, para mostrar cosas encima y para seleccionar con el ratón.
func head_position() -> Vector3:
	return global_position + Vector3(0, 2.2 * SCALE, 0)


## Color de la silueta que se ve a través de los edificios (con su opacidad en `a`).
func set_silhouette(color: Color) -> void:
	if _silhouette:
		_silhouette.set_shader_parameter("color", color)


## Icono flotante sobre la cabeza que se ve a través de todo; "" lo quita.
func set_marker(text: String, color := Color("ffd23c")) -> void:
	if _marker == null:
		return
	_marker.visible = text != ""
	_marker.text = text
	_marker.outline_modulate = color.darkened(0.6)
	_marker.modulate = color


func _process(delta: float) -> void:
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
	if _marker and _marker.visible:
		_marker.position.y = MARKER_Y * body_size + sin(Time.get_ticks_msec() * 0.004) * 0.25
	if input_dir != Vector3.ZERO:
		path.clear()
		_move_free(delta)
		_animate(delta, true)
		return
	if path.is_empty():
		_animate(delta, false)
		return
	var target := city.cell_to_world(path[0])
	var to := target - position
	var step := speed * slow_factor * run_factor * delta
	if to.length() <= step:
		position = target
		cell = path.pop_front()
		if path.is_empty():
			arrived.emit()
	else:
		var dir := to.normalized()
		if wobble > 0.0:
			dir = dir.rotated(Vector3.UP, sin(_walk_phase * 0.35) * 0.6 * wobble)
		position += dir * step
		_face(dir, delta)
	_animate(delta, true)


## Avanza en la dirección de `input_dir` sin salirse de las casillas transitables.
## Las calles no siguen las teclas: si de frente hay pared, sigue la dirección libre más
## parecida (hasta STEER_MAX_DEG a cada lado), así que el muñeco toma la calle en vez de
## pararse contra la fachada; y si aun así choca de lado, se desliza a lo largo de la pared.
func _move_free(delta: float) -> void:
	var dir := _steer(input_dir.normalized())
	var step := dir * input_dir.length() * speed * slow_factor * run_factor * delta
	var next := position
	for s in [step, Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		if s.length_squared() > 0.0 and _free(position + s) and _free(position + s + s.normalized() * WALL_PROBE):
			next = position + s
			break
	position = next
	cell = city.world_to_cell(position)
	_face(step if step != Vector3.ZERO else input_dir, delta)


## La dirección libre más parecida a `want`: la misma si está despejada, o la que menos
## se aparta de ella entre las que dejan andar STEER_LOOKAHEAD metros.
func _steer(want: Vector3) -> Vector3:
	if _free_run(want) >= STEER_LOOKAHEAD:
		return want
	var best := want
	var best_score := 0.0
	var a := STEER_STEP_DEG
	while a <= STEER_MAX_DEG:
		for side in [-1.0, 1.0]:
			var d := want.rotated(Vector3.UP, deg_to_rad(a * side))
			var run := _free_run(d)
			if run >= STEER_LOOKAHEAD:
				return d
			var score := run * cos(deg_to_rad(a))
			if score > best_score:
				best_score = score
				best = d
		a += STEER_STEP_DEG
	return best


## Metros que se pueden andar en línea recta en `dir` (hasta STEER_LOOKAHEAD).
func _free_run(dir: Vector3) -> float:
	var d := 0.0
	while d < STEER_LOOKAHEAD:
		if not _free(position + dir * (d + 0.5 + WALL_PROBE)):
			return d
		d += 0.5
	return d


func _free(pos: Vector3) -> bool:
	return city.is_walkable(city.world_to_cell(pos))


func _face(dir: Vector3, delta: float) -> void:
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))


func _animate(delta: float, moving: bool) -> void:
	if moving:
		_walk_phase += delta * 10.0 * slow_factor * run_factor
	else:
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase / PI) * PI, minf(1.0, delta * 10.0))
	var swing := sin(_walk_phase) * 0.7
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	_body.position.y = absf(sin(_walk_phase)) * 0.08 if moving else 0.0



# ------------------------------------------------------------------ modelo

static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		if _outline == null:
			_outline = StandardMaterial3D.new()
			_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_outline.albedo_color = Color(0.08, 0.06, 0.06)
			_outline.cull_mode = BaseMaterial3D.CULL_FRONT
			_outline.grow = true
			_outline.grow_amount = 0.035
			_stencil_write(_outline)
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_stencil_write(m)
		m.next_pass = _outline
		_materials[key] = m
	return _materials[key]


## Marca en el stencil dónde se ve al personaje (también su contorno), para que su
## silueta no se pinte encima de él (ver shaders/silhouette.gdshader).
static func _stencil_write(m: BaseMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.material_overlay = _silhouette
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Una extremidad con el pivote arriba, para poder balancearla al andar.
func _limb(parent: Node3D, size: Vector3, color: Color, pivot: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pivot
	parent.add_child(j)
	_part(j, CityProps.box(size), color, Vector3(0, -size.y / 2.0, 0))
	return j


func _build_body() -> void:
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = _silhouette_shader
	_silhouette.set_shader_parameter("color", SILHOUETTE)
	_body = Node3D.new()
	_body.scale = Vector3.ONE * SCALE * body_size
	add_child(_body)
	var female: bool = look.get("gender", "m") == "f"
	var shirt: Color = look["shirt"]
	var jacket: Color = look.get("jacket", Color.TRANSPARENT)
	var sleeves := jacket if jacket.a > 0.0 else shirt.darkened(0.12)
	var skirt: bool = look.get("skirt", false)
	var shoulders := 0.54 if female else 0.64
	var leg_w := 0.19 if female else 0.22
	# con falda, las piernas van al aire (el color de la piel, algo más oscuro, como unas medias)
	var legs_color: Color = look["skin"].darkened(0.1) if skirt else look["pants"]
	_legs = [
		_limb(_body, Vector3(leg_w, 0.75, 0.24), legs_color, Vector3(-0.13, 0.78, 0)),
		_limb(_body, Vector3(leg_w, 0.75, 0.24), legs_color, Vector3(0.13, 0.78, 0)),
	]
	if skirt:
		_part(_body, CityProps.cylinder(0.27, 0.38, 0.48), look["pants"], Vector3(0, 0.66, 0))
	if female:
		# talle: el cuerpo se estrecha en la cintura y se abre en la cadera
		_part(_body, CityProps.box(Vector3(shoulders, 0.42, 0.34)), shirt, Vector3(0, 1.27, 0))
		_part(_body, CityProps.cylinder(0.25, 0.3, 0.28), shirt, Vector3(0, 0.93, 0))
	else:
		_part(_body, CityProps.box(Vector3(shoulders, 0.7, 0.36)), shirt, Vector3(0, 1.13, 0))
	if jacket.a > 0.0:
		# chaqueta abierta: por delante se ve una franja de la camiseta
		_part(_body, CityProps.box(Vector3(shoulders + 0.06, 0.74, 0.42)), jacket, Vector3(0, 1.13, 0))
		_part(_body, CityProps.box(Vector3(0.18, 0.68, 0.04)), shirt, Vector3(0, 1.15, 0.21))
	var arm_x := shoulders / 2.0 + 0.09
	var arm := Vector3(0.15 if female else 0.17, 0.62, 0.18)
	_arms = [
		_limb(_body, arm, sleeves, Vector3(-arm_x, 1.44, 0)),
		_limb(_body, arm, sleeves, Vector3(arm_x, 1.44, 0)),
	]
	# cabezón caricaturesco
	_part(_body, CityProps.sphere(0.36), look["skin"], Vector3(0, 1.86, 0))
	_part(_body, CityProps.sphere(0.06), Color.BLACK, Vector3(-0.12, 1.92, 0.31))
	_part(_body, CityProps.sphere(0.06), Color.BLACK, Vector3(0.12, 1.92, 0.31))
	_part(_body, CityProps.sphere(0.09), look["skin"].darkened(0.15), Vector3(0, 1.82, 0.36))
	if accessory != "capucha":
		_build_hair(look.get("hair_style", "melena" if female else "corto"), accessory in ["gorra_poli", "gorra", "mochila"])
	_build_face()
	match accessory:
		"gorra_poli":
			_part(_body, CityProps.cylinder(0.36, 0.38, 0.22), Color("1d2a5a"), Vector3(0, 2.14, 0))
			_part(_body, CityProps.box(Vector3(0.5, 0.05, 0.3)), Color("111833"), Vector3(0, 2.05, 0.3))
		"capucha":
			_part(_body, CityProps.sphere(0.42), sleeves.darkened(0.2), Vector3(0, 1.9, -0.08), Vector3(1, 1, 0.9))
		"mochila":
			_part(_body, CityProps.box(Vector3(0.5, 0.55, 0.25)), Color("c04a3a"), Vector3(0, 1.15, -0.3))
			_part(_body, CityProps.cylinder(0.42, 0.42, 0.06), Color("f0e0a0"), Vector3(0, 2.2, 0))  # sombrero de guiri
		"chaleco":
			_part(_body, CityProps.box(Vector3(shoulders + 0.04, 0.5, 0.4)), Color("f0d030"), Vector3(0, 1.2, 0))
		"despedida":
			# banda cruzada y diadema de despedida de soltero
			var sash := _part(_body, CityProps.box(Vector3(0.18, 0.95, 0.4)), Color("fff0f8"), Vector3(0, 1.13, 0))
			sash.rotation.z = deg_to_rad(40.0)
			_part(_body, CityProps.sphere(0.1), Color("ff3c96"), Vector3(-0.18, 2.3, 0))
			_part(_body, CityProps.sphere(0.1), Color("ff3c96"), Vector3(0.18, 2.3, 0))
		"bolsa":
			# bolsa de plástico con las latas, colgando de la mano
			_part(_body, CityProps.box(Vector3(0.34, 0.4, 0.22)), Color("f4f4ee"), Vector3(arm_x + 0.07, 0.62, 0))
		"caja":
			# la caja de cartón que hace de mesa del trile
			_part(_body, CityProps.box(Vector3(0.7, 0.6, 0.5)), Color("b08850"), Vector3(0, 0.3, 0.6))
		"gorra":
			# gorra del revés
			_part(_body, CityProps.cylinder(0.36, 0.38, 0.16), shirt.lightened(0.3), Vector3(0, 2.1, 0))
			_part(_body, CityProps.box(Vector3(0.4, 0.04, 0.26)), shirt.lightened(0.2), Vector3(0, 2.04, -0.32))

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 3.4 * SCALE, 0)
	_bubble.font_size = 44
	_bubble.pixel_size = 0.018
	_bubble.outline_size = 14
	_bubble.modulate = Color("fffbe8")
	_bubble.outline_modulate = Color(0.08, 0.06, 0.06)
	_bubble.no_depth_test = true
	_bubble.render_priority = 3
	_bubble.outline_render_priority = 2
	_bubble.visible = false
	add_child(_bubble)

	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.position = Vector3(0, MARKER_Y * body_size, 0)
	_marker.font_size = 150
	_marker.pixel_size = 0.02
	_marker.outline_size = 40
	_marker.no_depth_test = true
	_marker.render_priority = 5
	_marker.outline_render_priority = 4
	_marker.visible = false
	add_child(_marker)


## Pelo según el peinado. Con gorra o sombrero (`hat`) no se pinta lo que asomaría por encima.
func _build_hair(style: String, hat: bool) -> void:
	var hair: Color = look["hair"]
	var cap := func(): _part(_body, CityProps.sphere(0.37), hair, Vector3(0, 1.98, -0.04), Vector3(1, 0.55, 1))
	match style:
		"calvo":
			# solo la corona de pelo de los lados y la nuca
			_part(_body, CityProps.sphere(0.37), hair, Vector3(0, 1.8, -0.14), Vector3(1.03, 0.35, 0.85))
		"rapado":
			_part(_body, CityProps.sphere(0.365), hair.lerp(look["skin"], 0.35), Vector3(0, 1.9, -0.02), Vector3(1, 0.75, 1))
		"tupe":
			cap.call()
			if not hat:
				var quiff := _part(_body, CityProps.sphere(0.2), hair, Vector3(0, 2.14, 0.18), Vector3(1.3, 0.7, 1.0))
				quiff.rotation.x = deg_to_rad(-30.0)
		"rizos":
			# bucles por arriba y por detrás, sin tapar la cara
			for i in 9:
				var a := PI * (0.9 + 1.2 * i / 8.0)
				_part(_body, CityProps.sphere(0.16), hair, Vector3(cos(a) * 0.3, 1.86 + 0.18 * absf(sin(a)), sin(a) * 0.22 - 0.12))
			if not hat:
				for x in [-0.14, 0.14]:
					_part(_body, CityProps.sphere(0.17), hair, Vector3(x, 2.13, -0.02))
				_part(_body, CityProps.sphere(0.17), hair, Vector3(0, 2.18, -0.16))
		"coleta":
			cap.call()
			_part(_body, CityProps.sphere(0.12), hair, Vector3(0, 2.02, -0.38))
			_part(_body, CityProps.box(Vector3(0.13, 0.4, 0.13)), hair, Vector3(0, 1.78, -0.44))
		"melena":
			cap.call()
			_part(_body, CityProps.box(Vector3(0.78, 0.66, 0.34)), hair, Vector3(0, 1.72, -0.2))
		"moño":
			cap.call()
			if not hat:
				_part(_body, CityProps.sphere(0.18), hair, Vector3(0, 2.26, -0.16))
		"corta":
			# media melena por la barbilla
			cap.call()
			_part(_body, CityProps.box(Vector3(0.82, 0.36, 0.6)), hair, Vector3(0, 1.82, -0.1))
		_:
			cap.call()


## Barba, bigote y gafas.
func _build_face() -> void:
	match look.get("facial", ""):
		"barba":
			_part(_body, CityProps.sphere(0.3), look["hair"], Vector3(0, 1.67, 0.15), Vector3(1.05, 0.7, 0.8))
		"bigote":
			_part(_body, CityProps.box(Vector3(0.26, 0.06, 0.07)), look["hair"], Vector3(0, 1.75, 0.34))
	if look.get("glasses", false):
		var frame := Color("1a1a1e")
		for x in [-0.13, 0.13]:
			_part(_body, CityProps.box(Vector3(0.15, 0.11, 0.03)), frame, Vector3(x, 1.92, 0.36))
		_part(_body, CityProps.box(Vector3(0.1, 0.03, 0.03)), frame, Vector3(0, 1.94, 0.36))
