class_name MapaBarrio
extends Control
## Mapa del barrio a pantalla completa (tecla M): el suelo del juego visto desde arriba, con
## el norte arriba, dónde estás y hacia dónde miras, los sitios por tipo y los de los encargos
## en marcha tal como los apuntaste en la libreta (si los apuntaste mal, aquí también están mal).
## Rueda: zoom (hacia el ratón). Arrastrar: mover el mapa. M o Esc: cerrar. El barrio se pausa.

signal closed

const ZOOM_MIN := 0.8  ## píxeles de pantalla por casilla
const ZOOM_MAX := 16.0
const ZOOM_START := 2.2  ## al abrir, centrado en ti
## Color y letra de cada tipo de sitio (los bares, sin letra: son muchos).
const KINDS := {
	"comisaria": [Color("5a7cff"), "P", "Comisaría"],
	"cas": [Color("40d080"), "C", "CAS Baluard"],
	"albergue": [Color("40d080"), "A", "Albergue / servicio social"],
	"cap": [Color("ff6a6a"), "+", "Centro de salud"],
	"farmacia": [Color("70e070"), "F", "Farmacia"],
	"compraventa": [Color("e0b040"), "€", "Compraventa"],
	"club": [Color("60c060"), "*", "Club cannábico"],
	"cajero": [Color("f0f0f0"), "$", "Cajero"],
	"super": [Color("70d0ff"), "S", "Súper"],
	"kebab": [Color("e09040"), "K", "Kebab"],
	"iglesia": [Color("c0a080"), "†", "Iglesia"],
	"bar": [Color("ff70a0"), "", "Bar"],
}
const C_PLAYER := Color("ffd23c")
const C_NOTE := Color("ffd23c")

var world: World
var _tex: Texture2D
var _px := 6.0  ## píxeles de la textura por casilla
var _scale := ZOOM_START
var _origin := Vector2.ZERO
var _drag := false
var _hover := ""


func _init(p_world: World) -> void:
	world = p_world


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tex = load("res://assets/ground.png")
	_px = _tex.get_width() / float(world.city.width)
	# toda la ventana, aunque el HUD tenga el tamaño base del proyecto
	_fit()
	get_viewport().size_changed.connect(_fit)
	_center_on_player()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _center_on_player() -> void:
	_origin = size / 2.0 - _player_cell() * _scale
	queue_redraw()


func _player_cell() -> Vector2:
	var p := world.player.position / world.city.cell_m
	return Vector2(p.x, p.z)


func _to_screen(cell: Vector2) -> Vector2:
	return _origin + cell * _scale


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.06, 0.97))
	var city := world.city
	draw_texture_rect(_tex, Rect2(_origin, Vector2(city.width, city.height) * _scale), false)
	# sitios (los bares, más pequeños y sin letra)
	var r := clampf(_scale * 1.6, 5.0, 11.0)
	for p in city.pois:
		var k: Array = KINDS.get(p["kind"], [])
		if k.is_empty() or (p["kind"] == "club" and not p["name"] in GameState.clubs_conocidos):
			continue
		var at := _to_screen(Vector2(p["x"], p["y"]) + Vector2(0.5, 0.5))
		if k[1] == "":
			draw_circle(at, r * 0.45, k[0])
			continue
		draw_circle(at, r + 1.5, Color.BLACK)
		draw_circle(at, r, k[0])
		draw_string(font, at + Vector2(-r * 0.55, r * 0.55), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.4), Color.BLACK)
	# encargos en marcha, según la libreta
	for n in world.errands.noted_places():
		var poi: Dictionary = n["poi"]
		var at := _to_screen(Vector2(poi["x"], poi["y"]) + Vector2(0.5, 0.5))
		draw_arc(at, 16.0, 0, TAU, 32, C_NOTE, 3.0, true)
		_label(at + Vector2(20, 6), world.errands.place_name(poi), C_NOTE)
	# tú, con una flecha hacia donde miras
	var me := _to_screen(_player_cell())
	var f := world.player.facing()
	var dir := Vector2(f.x, f.z).normalized()
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([me + dir * 16, me - dir * 9 + side * 10, me - dir * 4, me - dir * 9 - side * 10]), C_PLAYER)
	draw_arc(me, 22.0, 0, TAU, 32, C_PLAYER, 2.0, true)
	_label(me + Vector2(26, -12), "Tú", C_PLAYER)
	_draw_legend(font)


func _label(at: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


## Leyenda arriba a la izquierda y ayuda abajo.
func _draw_legend(font: Font) -> void:
	var box := Rect2(16, 16, 250, 30 + KINDS.size() * 22 + 30)
	draw_rect(box, Color(0.07, 0.06, 0.08, 0.88))
	draw_string(font, box.position + Vector2(12, 24), "MAPA DEL RAVAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e07a30"))
	var y := box.position.y + 50
	for kind in KINDS:
		var k: Array = KINDS[kind]
		draw_circle(Vector2(box.position.x + 20, y - 5), 7, k[0])
		draw_string(font, Vector2(box.position.x + 36, y), k[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
		y += 22
	draw_arc(Vector2(box.position.x + 20, y - 5), 7, 0, TAU, 20, C_NOTE, 2.0)
	draw_string(font, Vector2(box.position.x + 36, y), "Encargo (según la libreta)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
	var help := "Rueda: zoom  ·  Arrastrar: mover  ·  M o Esc: cerrar"
	if _hover != "":
		help = _hover + "      " + help
	draw_string_outline(font, Vector2(16, size.y - 18), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
	draw_string(font, Vector2(16, size.y - 18), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var s := clampf(_scale * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.2), ZOOM_MIN, ZOOM_MAX)
			_origin = event.position - (event.position - _origin) * (s / _scale)
			_scale = s
			queue_redraw()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_drag = event.pressed
		accept_event()
	elif event is InputEventMouseMotion:
		if _drag:
			_origin += event.relative
		var cell := Vector2i(((event.position - _origin) / _scale).floor())
		_hover = world.city.street_name_near(cell, 6)
		queue_redraw()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		closed.emit()
