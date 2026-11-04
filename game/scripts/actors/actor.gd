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
	"m": ["corto", "rapado", "calvo", "tupe", "rizos", "coleta", "media_melena"],
	"f": ["melena", "coleta", "moño", "corta", "rizos", "rapado", "flequillo"],
}
## Silueta a través de las paredes: color y opacidad por defecto (ver set_silhouette).
const SILHOUETTE := Color(0.85, 0.88, 1.0, 0.35)
## Anchura del cuerpo según la complexión (look["build"]); sin ella, 1.
const BUILDS := {"delgado": 0.85, "grueso": 1.3}
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
## glasses (bool), jacket (color de la chaqueta abierta), skirt (bool, falda en vez de pantalón)
## bici (bool, va montado en una) y build ("delgado", "" o "grueso": la complexión).
var look := {
	"skin": Color("d9a77c"), "shirt": Color.GRAY, "pants": Color.DIM_GRAY, "hair": Color.BLACK,
}
var accessory := ""  ## "", "gorra_poli", "mochila", "capucha", "chaleco", "despedida", "bolsa", "caja", "gorra",
## "baston", "reparto", "guitarra", "platillo", "carton", "skate", "folletos", "rosas", "carro",
## "paraguas", "caballete", "cresta"
var body_size := 1.0  ## multiplicador de tamaño (los chavales son más bajos)
var slow_factor := 1.0
var run_factor := 1.0  ## > 1 al correr (Shift)
var wobble := 0.0  ## 0..1: eses al seguir un camino (alcohol)
## Movimiento directo (WASD) en el plano, de longitud 0..1. Mientras no es cero manda sobre `path`.
var input_dir := Vector3.ZERO
## Marionetas de los minijuegos, que no andan por el mapa: las mueve quien las usa.
var puppet_walk := false  ## anda en el sitio (piernas y brazos), aunque no tenga camino
var arm_pose: Array[float] = [0.0, 0.0]  ## giro extra de cada brazo (negativo: hacia delante y arriba)

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _bubble: Label3D
var _bubble_time := 0.0
var _walk_phase := 0.0
var _silhouette: ShaderMaterial  ## pasada que pinta al personaje donde lo tapa un edificio
var _marker: Label3D  ## icono flotante (encargos)

static var _materials := {}
## Mallas ya montadas por aspecto (ver _build_body): hay muchos bots iguales (mismo tipo y
## nombre) y montar uno de cero cuesta unos milisegundos; así, el segundo sale casi gratis.
static var _mesh_cache := {}
const MESH_CACHE_MAX := 600
## Montar a las personas con el cuerpo con más detalle (scripts/actors/cuerpo.gd); false, el
## muñeco de antes, más sencillo.
static var cuerpo_nuevo := true
static var _toon_material: StandardMaterial3D
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
		_animate(delta, puppet_walk)
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
	_arms[0].rotation.x = -swing * 0.8 + arm_pose[0]
	_arms[1].rotation.x = swing * 0.8 + arm_pose[1]
	_body.position.y = absf(sin(_walk_phase)) * 0.08 if moving else 0.0



# ------------------------------------------------------------------ modelo

## Material de una pieza de color `color` (mientras se monta el modelo; luego se juntan
## todas en `_merge_parts`, que se queda con el color).
static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[key] = m
	return _materials[key]


## El único material de los personajes ya montados: toon, con el color en los vértices,
## el contorno negro (otra pasada que crece hacia fuera, shaders/contorno.gdshader) y la
## marca en el stencil. Una pieza de color con alfa 0 no lleva contorno.
static func _toon() -> StandardMaterial3D:
	if _toon_material == null:
		# contorno: crece según el alfa del color del vértice (las piezas con alfa 0, sin contorno)
		var outline := ShaderMaterial.new()
		outline.shader = load("res://shaders/contorno.gdshader")
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_stencil_write(m)
		m.next_pass = outline
		_toon_material = m
	return _toon_material


## Junta las piezas de cada parte rígida (el cuerpo y cada extremidad, que se mueven aparte)
## en una sola malla con el color en los vértices. Cada pieza suelta se dibujaba tres veces
## (ella, su contorno y su silueta): con decenas por personaje, con muchos bots era lo que
## más pesaba. Así quedan cinco mallas por personaje.
func _merge_parts() -> void:
	var holders: Array[Node3D] = [_body]
	holders.append_array(_legs)
	holders.append_array(_arms)
	for holder in holders:
		var parts: Array[MeshInstance3D] = []
		for c in holder.get_children():
			if c is MeshInstance3D:
				parts.append(c)
		if parts.is_empty():
			continue
		var merged := MeshInstance3D.new()
		merged.mesh = _merged_mesh(parts)
		merged.material_override = _toon()
		merged.material_overlay = _silhouette
		for p in parts:
			holder.remove_child(p)
			p.free()
		holder.add_child(merged)


## Lo que se guarda de un cuerpo montado: la malla del tronco y, de cada extremidad, dónde
## va el pivote y su malla.
func _to_cache() -> Dictionary:
	var limbs := func(list: Array[Node3D]) -> Array:
		return list.map(func(j): return [j.position, _merged_of(j)])
	return {"body": _merged_of(_body), "legs": limbs.call(_legs), "arms": limbs.call(_arms)}


## Monta el cuerpo con mallas ya hechas (ver _to_cache).
func _from_cache(c: Dictionary) -> void:
	_add_merged(_body, c["body"])
	for list in [["legs", _legs], ["arms", _arms]]:
		for entry in c[list[0]]:
			var j := Node3D.new()
			j.position = entry[0]
			_body.add_child(j)
			_add_merged(j, entry[1])
			list[1].append(j)


func _add_merged(holder: Node3D, mesh: Mesh) -> void:
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _toon()
	mi.material_overlay = _silhouette
	holder.add_child(mi)


## La malla juntada de una parte (su único MeshInstance3D), o null.
static func _merged_of(holder: Node3D) -> Mesh:
	for c in holder.get_children():
		if c is MeshInstance3D:
			return c.mesh
	return null


## Una malla con todas las `parts` (en el espacio de su padre), con su color en los vértices.
static func _merged_mesh(parts: Array[MeshInstance3D]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for p in parts:
		var a := p.mesh.surface_get_arrays(0)
		var t := p.transform
		var nb := t.basis.inverse().transposed()
		var color: Color = (p.material_override as StandardMaterial3D).albedo_color
		var base := verts.size()
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in pv.size():
			verts.append(t * pv[i])
			normals.append((nb * pn[i]).normalized())
			colors.append(color)
		var pi = a[Mesh.ARRAY_INDEX]
		if pi == null or (pi as PackedInt32Array).is_empty():
			for i in pv.size():
				index.append(base + i)
		else:
			for i in pi:
				index.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
	_build_model()

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


## Una persona: cuerpo según el género, brazos y piernas, cabezón, pelo, cara y accesorio.
func _build_person() -> void:
	var female: bool = look.get("gender", "m") == "f"
	var shirt: Color = look["shirt"]
	var jacket: Color = look.get("jacket", Color.TRANSPARENT)
	var sleeves := jacket if jacket.a > 0.0 else shirt.darkened(0.12)
	var skirt: bool = look.get("skirt", false)
	var build: float = BUILDS.get(look.get("build", ""), 1.0)
	var shoulders := (0.54 if female else 0.64) * build
	var leg_w := (0.19 if female else 0.22) * lerpf(1.0, build, 0.6)
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
		_part(_body, CityProps.box(Vector3(shoulders, 0.42, 0.34 * build)), shirt, Vector3(0, 1.27, 0))
		_part(_body, CityProps.cylinder(0.25 * build, 0.3 * build, 0.28), shirt, Vector3(0, 0.93, 0))
	else:
		_part(_body, CityProps.box(Vector3(shoulders, 0.7, 0.36 * build)), shirt, Vector3(0, 1.13, 0))
	if build > 1.1:
		# barriga
		_part(_body, CityProps.sphere(0.3), shirt, Vector3(0, 1.0, 0.1 * build), Vector3(1.0, 0.85, 0.8))
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
	if accessory == "cresta":
		_build_hair("rapado", true)  # rapado por los lados; la cresta va abajo
	elif accessory != "capucha":
		_build_hair(look.get("hair_style", "melena" if female else "corto"), accessory in ["gorra_poli", "gorra", "mochila"])
	_build_face()
	_accesorio({"arm_x": arm_x, "hombros": shoulders, "mangas": sleeves,
		"cabeza": Vector3(0, 1.86, 0), "k": 1.0})


## El accesorio (`accessory`) sobre el cuerpo ya montado, con sus anclas en `an`: arm_x (dónde
## cuelgan los brazos), hombros (anchura), mangas (color), cabeza (su centro) y k (lo grande
## que es la cabeza respecto a la del muñeco de siempre); el cuerpo nuevo (Cuerpo) añade
## tronco ([hombro, cintura, fondo]) y nuevo.
func _accesorio(an: Dictionary) -> void:
	var arm_x: float = an["arm_x"]
	var shoulders: float = an["hombros"]
	var sleeves: Color = an["mangas"]
	var c: Vector3 = an["cabeza"]
	var k: float = an["k"]
	var nuevo: bool = an.get("nuevo", false)
	var shirt: Color = look["shirt"]
	match accessory:
		"gorra_poli":
			# gorra de plato con la banda de su cuerpo: cuadros blancos la Urbana, roja los Mossos
			var cap_color: Color = look.get("cap", Color("1d2a5a"))
			_part(_body, CityProps.cylinder(0.36, 0.38, 0.22), cap_color, c + Vector3(0, 0.28, 0) * k, Vector3.ONE * k)
			_part(_body, CityProps.box(Vector3(0.5, 0.05, 0.3)), cap_color.darkened(0.4), c + Vector3(0, 0.19, 0.3) * k, Vector3.ONE * k)
			if look.has("cap_band"):
				_part(_body, CityProps.cylinder(0.385, 0.385, 0.07), look["cap_band"], c + Vector3(0, 0.23, 0) * k, Vector3.ONE * k)
		"capucha":
			_part(_body, CityProps.sphere(0.42), sleeves.darkened(0.2), c + Vector3(0, 0.04, -0.08 - 0.04 * float(nuevo)) * k, Vector3(1, 1, 0.9) * k)
		"mochila":
			_part(_body, CityProps.box(Vector3(0.5, 0.55, 0.25)), Color("c04a3a"), Vector3(0, 1.15, -0.3))
			_part(_body, CityProps.cylinder(0.42, 0.42, 0.06), Color("f0e0a0"), c + Vector3(0, 0.34, 0) * k, Vector3.ONE * k)  # sombrero de guiri
		"chaleco":
			if nuevo:
				var t: Array = an["tronco"]  # [hombro, cintura, fondo]: el chaleco se ciñe al tronco
				_part(_body, CityProps.cylinder(t[0] * 1.09, t[1] * 1.16, 0.5, 14), Color("f0d030"), Vector3(0, 1.24, 0), Vector3(1, 1, t[2] * 1.08))
			else:
				_part(_body, CityProps.box(Vector3(shoulders + 0.04, 0.5, 0.4)), Color("f0d030"), Vector3(0, 1.2, 0))
		"despedida":
			# banda cruzada y diadema de despedida de soltero
			var sash := _part(_body, CityProps.box(Vector3(0.18, 0.95, 0.4)), Color("fff0f8"), Vector3(0, 1.13, 0))
			sash.rotation.z = deg_to_rad(40.0)
			_part(_body, CityProps.sphere(0.1), Color("ff3c96"), c + Vector3(-0.18, 0.44, 0) * k, Vector3.ONE * k)
			_part(_body, CityProps.sphere(0.1), Color("ff3c96"), c + Vector3(0.18, 0.44, 0) * k, Vector3.ONE * k)
		"bolsa":
			# bolsa de plástico con las latas, colgando de la mano
			_part(_body, CityProps.box(Vector3(0.34, 0.4, 0.22)), Color("f4f4ee"), Vector3(arm_x + 0.07, 0.62, 0))
		"caja":
			# la caja de cartón que hace de mesa del trile
			_part(_body, CityProps.box(Vector3(0.7, 0.6, 0.5)), Color("b08850"), Vector3(0, 0.3, 0.6))
		"gorra":
			# gorra del revés
			_part(_body, CityProps.cylinder(0.36, 0.38, 0.16), shirt.lightened(0.3), c + Vector3(0, 0.24, 0) * k, Vector3.ONE * k)
			_part(_body, CityProps.box(Vector3(0.4, 0.04, 0.26)), shirt.lightened(0.2), c + Vector3(0, 0.18, -0.32) * k, Vector3.ONE * k)
		"baston":
			# bastón en la mano, apoyado en el suelo
			_part(_body, CityProps.cylinder(0.035, 0.035, 1.0), Color("4a3020"), Vector3(arm_x + 0.1, 0.5, 0.12))
		"reparto":
			# la mochila cúbica del reparto, del color de la camiseta
			_part(_body, CityProps.box(Vector3(0.62, 0.62, 0.5)), shirt.darkened(0.1), Vector3(0, 1.3, -0.45))
		"guitarra":
			# guitarra cruzada por delante: caja, boca y mástil
			var body := _part(_body, CityProps.box(Vector3(0.5, 0.6, 0.14)), Color("a0602a"), Vector3(-0.08, 1.0, 0.28))
			body.rotation.z = deg_to_rad(-30.0)
			var hole := _part(_body, CityProps.cylinder(0.09, 0.09, 0.02), Color("2a1a10"), Vector3(-0.08, 1.02, 0.36))
			hole.rotation.x = deg_to_rad(90.0)
			var neck := _part(_body, CityProps.box(Vector3(0.08, 0.6, 0.06)), Color("3a2414"), Vector3(0.22, 1.5, 0.3))
			neck.rotation.z = deg_to_rad(-30.0)
		"platillo":
			# el sombrero en el suelo, boca arriba, para las monedas
			_part(_body, CityProps.cylinder(0.3, 0.3, 0.04), look["shirt"].darkened(0.3), Vector3(0, 0.02, 0.7))
			_part(_body, CityProps.cylinder(0.17, 0.19, 0.14), look["shirt"].darkened(0.3), Vector3(0, 0.08, 0.7))
		"carton":
			# cartón escrito a mano y el vaso, en el suelo delante
			var board := _part(_body, CityProps.box(Vector3(0.6, 0.42, 0.03)), Color("c8a46a"), Vector3(0, 0.22, 0.62))
			board.rotation.x = deg_to_rad(-20.0)
			_part(_body, CityProps.box(Vector3(0.44, 0.05, 0.035)), Color("2a2a2a"), Vector3(0, 0.26, 0.64))
			_part(_body, CityProps.cylinder(0.06, 0.05, 0.13), Color("f0f0e8"), Vector3(0.42, 0.07, 0.5))
		"skate":
			# la tabla bajo el brazo
			var deck := _part(_body, CityProps.box(Vector3(0.08, 0.22, 0.85)), Color("e04a2a"), Vector3(arm_x + 0.12, 1.05, 0.05))
			deck.rotation.x = deg_to_rad(15.0)
			for z in [-0.28, 0.28]:
				_part(_body, CityProps.box(Vector3(0.1, 0.18, 0.06)), Color("f0f0f0"), Vector3(arm_x + 0.2, 1.05, z + 0.05))
		"folletos":
			# un taco de flyers en la mano
			_part(_body, CityProps.box(Vector3(0.18, 0.04, 0.26)), Color("ff3ca0"), Vector3(arm_x + 0.05, 0.86, 0.2))
			_part(_body, CityProps.box(Vector3(0.18, 0.04, 0.26)), Color("40e0f0"), Vector3(arm_x + 0.05, 0.9, 0.21))
		"rosas":
			# el ramo de rosas, envueltas en celofán
			_part(_body, CityProps.cylinder(0.04, 0.12, 0.5), Color(0.9, 0.95, 1.0, 1.0), Vector3(arm_x + 0.08, 0.95, 0.2))
			for i in 5:
				var a := TAU * i / 5.0
				_part(_body, CityProps.sphere(0.07), Color("c01830"), Vector3(arm_x + 0.08 + cos(a) * 0.08, 1.24, 0.2 + sin(a) * 0.08))
		"carro":
			# carro de supermercado delante, cargado de chatarra
			var metal := Color("a8acb0")
			_part(_body, CityProps.box(Vector3(0.75, 0.5, 0.95)), metal, Vector3(0, 0.8, 1.05))
			_part(_body, CityProps.box(Vector3(0.65, 0.3, 0.8)), Color("5a4a3a"), Vector3(0, 1.1, 1.05))  # somier y trastos
			_part(_body, CityProps.box(Vector3(0.12, 0.4, 0.5)), Color("8a3a20"), Vector3(0.18, 1.3, 1.0))  # radiador oxidado
			_part(_body, CityProps.box(Vector3(0.8, 0.05, 0.05)), metal.darkened(0.3), Vector3(0, 1.0, 0.5))  # el asa
			for x in [-0.3, 0.3]:
				for z in [0.65, 1.45]:
					_part(_body, CityProps.cylinder(0.025, 0.025, 0.55), metal.darkened(0.2), Vector3(x, 0.28, z))
					_part(_body, CityProps.sphere(0.06), Color("202020"), Vector3(x, 0.06, z))
		"paraguas":
			# el paraguas cerrado en alto para que el grupo no le pierda
			_part(_body, CityProps.cylinder(0.025, 0.025, 1.5), Color("303030"), Vector3(arm_x + 0.05, 1.7, 0.1))
			_part(_body, CityProps.cylinder(0.02, 0.12, 0.5), Color("ffd020"), Vector3(arm_x + 0.05, 2.35, 0.1))
		"caballete":
			# caballete con el lienzo, de cara a la calle, y el taburete
			for x in [-0.3, 0.3]:
				var leg := _part(_body, CityProps.box(Vector3(0.04, 1.5, 0.04)), Color("6a4a2a"), Vector3(x, 0.75, 0.75))
				leg.rotation.z = deg_to_rad(8.0 * signf(-x))
			_part(_body, CityProps.box(Vector3(0.7, 0.55, 0.03)), Color("f4f0e4"), Vector3(0, 1.25, 0.73))
			_part(_body, CityProps.sphere(0.13), Color("e0a080"), Vector3(0, 1.28, 0.75), Vector3(1, 1.2, 0.2))  # la caricatura
		"cresta":
			# cresta de colores de la frente a la nuca
			for i in 6:
				var a := PI * (0.15 + 0.7 * i / 5.0)
				_part(_body, CityProps.box(Vector3(0.07, 0.24, 0.1)), look["hair"], c + Vector3(0, sin(a) * 0.4, cos(a) * 0.36) * k, Vector3.ONE * k)


## El muñeco (cuerpo y extremidades) según `look`, `accessory` y `body_size`.
func _build_model() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE * SCALE * body_size
	add_child(_body)
	var key := "%d|%s|%s|%s" % [var_to_str(look).hash(), accessory, body_size, cuerpo_nuevo]
	if _mesh_cache.has(key):
		_from_cache(_mesh_cache[key])
	else:
		if look.get("species", "") == "perro":
			_build_dog()
		else:
			if cuerpo_nuevo:
				Cuerpo.persona(self)
			else:
				_build_person()
			if look.get("bici", false):
				_build_bike()
		_merge_parts()
		if _mesh_cache.size() < MESH_CACHE_MAX:
			_mesh_cache[key] = _to_cache()


## Vuelve a montar el muñeco tras cambiar `look` (subir o bajar de la bici), mirando hacia
## el mismo lado.
func rebuild() -> void:
	var yaw := _body.rotation.y
	remove_child(_body)
	_body.free()
	_legs.clear()
	_arms.clear()
	_build_model()
	_body.rotation.y = yaw


## Una bici bajo el personaje (los repartidores): dos ruedas, cuadro, sillín y manillar.
## Las piernas van por encima, como si pedaleara.
func _build_bike() -> void:
	var tyre := Color("1a1a1e")
	var frame := Color("2a2e36")
	for z in [-0.55, 0.55]:
		var w := _part(_body, CityProps.cylinder(0.34, 0.34, 0.07, 16), tyre, Vector3(0, 0.34, z))
		w.rotation.z = PI / 2.0
		_part(_body, CityProps.cylinder(0.08, 0.08, 0.09, 8), Color("8a8a90"), Vector3(0, 0.34, z)).rotation.z = PI / 2.0
	_part(_body, CityProps.box(Vector3(0.06, 0.06, 1.0)), frame, Vector3(0, 0.62, 0))
	var seat_tube := _part(_body, CityProps.box(Vector3(0.06, 0.45, 0.06)), frame, Vector3(0, 0.55, -0.2))
	seat_tube.rotation.x = deg_to_rad(-15.0)
	_part(_body, CityProps.box(Vector3(0.14, 0.05, 0.24)), Color("111111"), Vector3(0, 0.8, -0.24))
	_part(_body, CityProps.box(Vector3(0.06, 0.5, 0.06)), frame, Vector3(0, 0.8, 0.5))
	_part(_body, CityProps.box(Vector3(0.6, 0.05, 0.05)), frame, Vector3(0, 1.05, 0.5))


## Un perro: cuerpo, cabeza con hocico y orejas, cola y cuatro patas (las de delante hacen
## de brazos y las de atrás de piernas, para que ande con el mismo balanceo).
func _build_dog() -> void:
	var fur: Color = look.get("fur", Color("6b4426"))
	_legs = [
		_limb(_body, Vector3(0.11, 0.42, 0.11), fur.darkened(0.1), Vector3(-0.12, 0.42, -0.26)),
		_limb(_body, Vector3(0.11, 0.42, 0.11), fur.darkened(0.1), Vector3(0.12, 0.42, -0.26)),
	]
	_arms = [
		_limb(_body, Vector3(0.11, 0.42, 0.11), fur.darkened(0.1), Vector3(-0.12, 0.42, 0.26)),
		_limb(_body, Vector3(0.11, 0.42, 0.11), fur.darkened(0.1), Vector3(0.12, 0.42, 0.26)),
	]
	_part(_body, CityProps.box(Vector3(0.36, 0.32, 0.8)), fur, Vector3(0, 0.56, 0))
	_part(_body, CityProps.sphere(0.21), fur, Vector3(0, 0.84, 0.46))
	_part(_body, CityProps.box(Vector3(0.16, 0.13, 0.2)), fur.lightened(0.15), Vector3(0, 0.78, 0.66))
	_part(_body, CityProps.sphere(0.045), Color.BLACK, Vector3(0, 0.82, 0.77))
	_part(_body, CityProps.sphere(0.035), Color.BLACK, Vector3(-0.08, 0.9, 0.63))
	_part(_body, CityProps.sphere(0.035), Color.BLACK, Vector3(0.08, 0.9, 0.63))
	for x in [-0.13, 0.13]:
		var ear := _part(_body, CityProps.box(Vector3(0.08, 0.16, 0.06)), fur.darkened(0.3), Vector3(x, 1.0, 0.42))
		ear.rotation.z = deg_to_rad(25.0 * signf(x))
	var tail := _part(_body, CityProps.box(Vector3(0.06, 0.06, 0.32)), fur, Vector3(0, 0.74, -0.5))
	tail.rotation.x = deg_to_rad(-35.0)
	# collar
	_part(_body, CityProps.cylinder(0.15, 0.17, 0.05), Color("c03030"), Vector3(0, 0.74, 0.36))


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
