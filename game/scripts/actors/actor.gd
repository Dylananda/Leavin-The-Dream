class_name Actor
extends Node3D
## Personaje que se mueve por la cuadrícula del barrio. Lo usan el jugador y los bots.
## Se modela con primitivas caricaturizadas (cabezón, cuerpo de bloque) a partir de `look`.

signal arrived

const SCALE := 1.35  ## más grandes que en la realidad para que se lean bien desde arriba
const WALL_PROBE := 0.6  ## margen hasta la pared al moverse con WASD, para no meterse en las fachadas

var city: CityMap
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var speed := 14.0  ## metros por segundo
var display_name := ""
var look := {
	"skin": Color("d9a77c"), "shirt": Color.GRAY, "pants": Color.DIM_GRAY, "hair": Color.BLACK,
}
var accessory := ""  ## "", "gorra_poli", "mochila", "capucha", "chaleco"
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

static var _materials := {}
static var _outline: StandardMaterial3D


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


func distance_to_cell(other: Vector2i) -> int:
	return maxi(absi(other.x - cell.x), absi(other.y - cell.y))


## Punto de la cabeza, para mostrar cosas encima y para seleccionar con el ratón.
func head_position() -> Vector3:
	return global_position + Vector3(0, 2.2 * SCALE, 0)


func _process(delta: float) -> void:
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
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


## Avanza en la dirección de `input_dir` sin salirse de las casillas transitables;
## al chocar de lado contra una pared se desliza a lo largo de ella.
func _move_free(delta: float) -> void:
	var step := input_dir * speed * slow_factor * run_factor * delta
	var next := position
	for s in [step, Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		if s.length_squared() > 0.0 and city.is_walkable(city.world_to_cell(position + s)) \
				and city.is_walkable(city.world_to_cell(position + s + s.normalized() * WALL_PROBE)):
			next = position + s
			break
	position = next
	cell = city.world_to_cell(position)
	_face(step, delta)


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
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.next_pass = _outline
		_materials[key] = m
	return _materials[key]


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
	_body = Node3D.new()
	_body.scale = Vector3.ONE * SCALE
	add_child(_body)
	var shirt: Color = look["shirt"]
	_legs = [
		_limb(_body, Vector3(0.22, 0.75, 0.26), look["pants"], Vector3(-0.14, 0.78, 0)),
		_limb(_body, Vector3(0.22, 0.75, 0.26), look["pants"], Vector3(0.14, 0.78, 0)),
	]
	_part(_body, CityProps.box(Vector3(0.62, 0.7, 0.36)), shirt, Vector3(0, 1.13, 0))
	_arms = [
		_limb(_body, Vector3(0.16, 0.62, 0.18), shirt.darkened(0.12), Vector3(-0.41, 1.44, 0)),
		_limb(_body, Vector3(0.16, 0.62, 0.18), shirt.darkened(0.12), Vector3(0.41, 1.44, 0)),
	]
	# cabezón caricaturesco
	_part(_body, CityProps.sphere(0.36), look["skin"], Vector3(0, 1.86, 0))
	_part(_body, CityProps.sphere(0.06), Color.BLACK, Vector3(-0.12, 1.92, 0.31))
	_part(_body, CityProps.sphere(0.06), Color.BLACK, Vector3(0.12, 1.92, 0.31))
	_part(_body, CityProps.sphere(0.09), look["skin"].darkened(0.15), Vector3(0, 1.82, 0.36))
	match accessory:
		"gorra_poli":
			_part(_body, CityProps.cylinder(0.36, 0.38, 0.22), Color("1d2a5a"), Vector3(0, 2.14, 0))
			_part(_body, CityProps.box(Vector3(0.5, 0.05, 0.3)), Color("111833"), Vector3(0, 2.05, 0.3))
		"capucha":
			_part(_body, CityProps.sphere(0.42), shirt.darkened(0.2), Vector3(0, 1.9, -0.08), Vector3(1, 1, 0.9))
		"mochila":
			_part(_body, CityProps.sphere(0.37), look["hair"], Vector3(0, 1.98, -0.04), Vector3(1, 0.55, 1))
			_part(_body, CityProps.box(Vector3(0.5, 0.55, 0.25)), Color("c04a3a"), Vector3(0, 1.15, -0.3))
			_part(_body, CityProps.cylinder(0.42, 0.42, 0.06), Color("f0e0a0"), Vector3(0, 2.2, 0))  # sombrero de guiri
		"chaleco":
			_part(_body, CityProps.sphere(0.37), look["hair"], Vector3(0, 1.98, -0.04), Vector3(1, 0.55, 1))
			_part(_body, CityProps.box(Vector3(0.66, 0.5, 0.4)), Color("f0d030"), Vector3(0, 1.2, 0))
		_:
			_part(_body, CityProps.sphere(0.37), look["hair"], Vector3(0, 1.98, -0.04), Vector3(1, 0.55, 1))

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
