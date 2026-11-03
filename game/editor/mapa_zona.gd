class_name MapaZona
extends Control
## Mapa del barrio en 2D (assets/ground.png, el mismo suelo del juego) para marcar dónde se
## mueve un personaje: el polígono de su zona, su casa y los lugares de su rutina.
## Rueda: zoom. Botón derecho o central arrastrando: mover el mapa. Los puntos ya puestos se
## arrastran con el izquierdo; en el modo polígono, el derecho sin arrastrar quita el último.
## Todo va en casillas de 2 m, como data/raval_map.json.

signal cambiado  ## se ha tocado el polígono, la casa o algún lugar
signal lugar_anadido(lugar: Dictionary)
signal info(texto: String)  ## calle y casilla bajo el ratón

enum Modo { VER, POLIGONO, CASA, LUGAR }

const MAP := "res://data/raval_map.json"
const GROUND := "res://assets/ground.png"
const AGARRE := 9.0  ## píxeles: distancia a la que se agarra un punto para arrastrarlo
const ZOOM_MIN := 0.6  ## píxeles de pantalla por casilla
const ZOOM_MAX := 24.0
const C_POLIGONO := Color(1.0, 0.55, 0.15)
const C_CASA := Color("ffe060")
const C_MAL := Color("ff3030")  ## punto que cae dentro de un edificio
const C_POI := {"comisaria": Color("4060ff"), "cas": Color("40d080"), "albergue": Color("40d080"),
	"iglesia": Color("c0a080"), "bar": Color("ff70a0"), "super": Color("70d0ff"), "cajero": Color("ffffff")}

var modo := Modo.VER
var tipo_lugar := "dormir"
var ver_pois := true
## Datos del personaje que se editan aquí (referencias a su diccionario).
var poligono: Array = []
var casa: Array = []
var lugares: Array = []

var _tex: Texture2D
var _px_por_casilla := 6.0  ## píxeles de ground.png por casilla
var _w := 0
var _h := 0
var _cells := PackedByteArray()
var _streets: Array = []
var _pois: Array = []
var _scale := 1.0  ## píxeles de pantalla por casilla
var _origin := Vector2.ZERO  ## dónde cae en pantalla la casilla (0, 0)
var _pan := false
var _pan_moved := false
var _drag: Array = []  ## el punto que se arrastra ([x, y] o el diccionario de un lugar)
var _hover := Vector2(-1, -1)
var _encuadrado := false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_tex = load(GROUND)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	_w = data["width"]
	_h = data["height"]
	_px_por_casilla = _tex.get_width() / float(_w)
	_cells.resize(_w * _h)
	var rows: Array = data["cells"]
	for y in _h:
		var row: String = rows[y]
		for x in _w:
			_cells[y * _w + x] = row.unicode_at(x) - 48
	_streets = data["streets"]
	_pois = data["pois"]
	# la primera vez que tiene tamaño (está en una pestaña que no se ve al principio)
	resized.connect(func(): if not _encuadrado: enfocar())


## Ajusta el zoom para que se vea todo el barrio.
func encuadrar() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_encuadrado = true
	_scale = minf(size.x / _w, size.y / _h)
	_origin = (size - Vector2(_w, _h) * _scale) / 2.0
	queue_redraw()


## Centra la vista en lo que tenga marcado el personaje.
func enfocar() -> void:
	var pts: Array = poligono + ([casa] if casa.size() == 2 else [])
	for l in lugares:
		pts.append([l["x"], l["y"]])
	if pts.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		encuadrar()
		return
	_encuadrado = true
	var r := Rect2(Vector2(pts[0][0], pts[0][1]), Vector2.ZERO)
	for p in pts:
		r = r.expand(Vector2(p[0], p[1]))
	r = r.grow(25)
	_scale = clampf(minf(size.x / r.size.x, size.y / r.size.y), ZOOM_MIN, ZOOM_MAX)
	_origin = size / 2.0 - r.get_center() * _scale
	queue_redraw()


func es_calle(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return false
	return _cells[c.y * _w + c.x] in CityMap.WALKABLE


## Nombre de la calle más cercana a la casilla `c` ("" si no hay ninguna cerca).
func calle_cerca(c: Vector2, radio := 8.0) -> String:
	var best := ""
	var best_d := radio * radio
	for s in _streets:
		var d := c.distance_squared_to(Vector2(s["x"], s["y"]))
		if d < best_d:
			best_d = d
			best = s["name"]
	return best


func _a_pantalla(c: Vector2) -> Vector2:
	return _origin + (c + Vector2(0.5, 0.5)) * _scale


func _a_casilla(p: Vector2) -> Vector2i:
	return Vector2i(((p - _origin) / _scale).floor())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("15141a"))
	draw_texture_rect(_tex, Rect2(_origin, Vector2(_w, _h) * _scale), false)
	if ver_pois:
		for p in _pois:
			if C_POI.has(p["kind"]):
				draw_circle(_a_pantalla(Vector2(p["x"], p["y"])), maxf(2.0, _scale * 0.8), C_POI[p["kind"]])
	# zona dibujada
	if poligono.size() >= 3:
		var pts := PackedVector2Array()
		for v in poligono:
			pts.append(_a_pantalla(Vector2(v[0], v[1])))
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, Color(C_POLIGONO, 0.22))
	for i in poligono.size():
		var a := _a_pantalla(Vector2(poligono[i][0], poligono[i][1]))
		if i > 0 or poligono.size() >= 3:
			var b := _a_pantalla(Vector2(poligono[i - 1][0], poligono[i - 1][1]))
			draw_line(a, b, C_POLIGONO, 2.0, true)
		draw_circle(a, 5.0, C_POLIGONO)
	# rutina y casa
	for l in lugares:
		var c := Vector2(l["x"], l["y"])
		var col: Color = Personajes.LUGARES.get(l["tipo"], Personajes.LUGARES["otro"])["color"]
		_punto(_a_pantalla(c), col, "%s %02d-%02d" % [Personajes.LUGARES.get(l["tipo"], {"label": "?"})["label"], l["desde"], l["hasta"]], es_calle(Vector2i(c)))
	if casa.size() == 2:
		_punto(_a_pantalla(Vector2(casa[0], casa[1])), C_CASA, "Casa", es_calle(Vector2i(casa[0], casa[1])))


## Marcador con su texto; con un aro rojo si cae donde no se puede andar.
func _punto(p: Vector2, col: Color, texto: String, bien: bool) -> void:
	draw_circle(p, 8.0, Color.BLACK)
	draw_circle(p, 6.0, col)
	if not bien:
		draw_arc(p, 11.0, 0, TAU, 20, C_MAL, 2.5, true)
	var font := get_theme_default_font()
	draw_string_outline(font, p + Vector2(11, 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, p + Vector2(11, 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_boton(event)
	elif event is InputEventMouseMotion:
		if _pan:
			_origin += event.relative
			_pan_moved = true
			queue_redraw()
		elif not _drag.is_empty():
			_mover_agarrado(_a_casilla(event.position))
		var c := _a_casilla(event.position)
		if Vector2(c) != _hover:
			_hover = Vector2(c)
			var calle := calle_cerca(_hover)
			info.emit("Casilla %d, %d%s%s" % [c.x, c.y, "   ·   " + calle if calle != "" else "",
				"" if es_calle(c) else "   (edificio o fuera del mapa)"])


func _boton(e: InputEventMouseButton) -> void:
	if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
		var f := 1.2 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.2
		var s := clampf(_scale * f, ZOOM_MIN, ZOOM_MAX)
		_origin = e.position - (e.position - _origin) * (s / _scale)
		_scale = s
		queue_redraw()
		accept_event()
		return
	if e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if e.pressed:
			_pan = true
			_pan_moved = false
		else:
			_pan = false
			# clic derecho sin arrastrar: quita el último vértice
			if e.button_index == MOUSE_BUTTON_RIGHT and not _pan_moved and modo == Modo.POLIGONO and not poligono.is_empty():
				poligono.pop_back()
				_cambio()
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if not e.pressed:
		_drag = []
		return
	_drag = _agarrar(e.position)
	if not _drag.is_empty():
		return
	var c := _a_casilla(e.position)
	match modo:
		Modo.POLIGONO:
			poligono.append([c.x, c.y])
			_cambio()
		Modo.CASA:
			casa.clear()
			casa.append_array([c.x, c.y])
			_cambio()
		Modo.LUGAR:
			var l := {"tipo": tipo_lugar, "x": c.x, "y": c.y, "desde": 0, "hasta": 0, "nota": calle_cerca(Vector2(c))}
			lugares.append(l)
			lugar_anadido.emit(l)
			_cambio()


## El punto bajo el ratón que se puede arrastrar: [lista_o_diccionario, índice] o [].
func _agarrar(p: Vector2) -> Array:
	for l in lugares:
		if _a_pantalla(Vector2(l["x"], l["y"])).distance_to(p) < AGARRE:
			return [l]
	if casa.size() == 2 and _a_pantalla(Vector2(casa[0], casa[1])).distance_to(p) < AGARRE:
		return [casa]
	for v in poligono:
		if _a_pantalla(Vector2(v[0], v[1])).distance_to(p) < AGARRE:
			return [v]
	return []


func _mover_agarrado(c: Vector2i) -> void:
	var what = _drag[0]
	if what is Dictionary:
		what["x"] = c.x
		what["y"] = c.y
	else:
		what[0] = c.x
		what[1] = c.y
	_cambio()


func _cambio() -> void:
	queue_redraw()
	cambiado.emit()
