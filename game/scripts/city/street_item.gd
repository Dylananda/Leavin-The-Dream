class_name StreetItem
extends Node3D
## Un objeto tirado en la calle: un móvil, una bici mal atada, chatarra... o basura.
## Se dibuja como lo *ves* (`seen_as`), que no siempre es lo que es (`id`): ido, la basura
## parece un móvil y un móvil parece basura (ver StreetItems.perceived).

## Objetos pequeños que destellan de vez en cuando para que se puedan encontrar (poco).
const GLINTS := ["movil", "movil_roto", "cartera", "cobre"]
const GLINT_EVERY := Vector2(2.5, 6.0)  ## segundos entre destellos
const GLINT_TIME := 0.35

var id := "basura"  ## lo que es de verdad
var decoy := ""  ## lo que te parece esta basura cuando la confundes
var roll := 0.0  ## tirada fija (0..1): cuanto más baja, antes la confundes al ir ido
var cell := Vector2i.ZERO
var born := 0.0  ## GameState.now() al aparecer
var seen_as := ""  ## lo que te parece ahora (lo que se dibuja)

var _body: Node3D
var _glint: Label3D
var _glint_timer := 0.0


func setup(p_id: String, p_cell: Vector2i, world_pos: Vector3) -> void:
	id = p_id
	cell = p_cell
	# no siempre en el centro de la casilla ni mirando igual
	position = world_pos + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
	rotation.y = randf() * TAU
	_glint_timer = randf_range(GLINT_EVERY.x, GLINT_EVERY.y)


## Cambia el dibujo a `what` (un id de Defs.STREET_ITEMS o "basura").
func show_as(what: String) -> void:
	if what == seen_as:
		return
	seen_as = what
	if _body:
		_body.queue_free()
	_body = Node3D.new()
	add_child(_body)
	_build(what)
	if _glint:
		_glint.queue_free()
		_glint = null
	if what in GLINTS:
		_glint = Label3D.new()
		_glint.text = "✦"
		_glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_glint.font_size = 64
		_glint.pixel_size = 0.008
		_glint.modulate = Color(1.0, 1.0, 0.85)
		_glint.position = Vector3(0, 0.35, 0)
		_glint.visible = false
		add_child(_glint)


func _process(delta: float) -> void:
	if not _glint:
		return
	_glint_timer -= delta
	_glint.visible = _glint_timer < GLINT_TIME
	if _glint_timer <= 0.0:
		_glint_timer = randf_range(GLINT_EVERY.x, GLINT_EVERY.y)


func _build(what: String) -> void:
	var b := _body
	match what:
		"movil", "movil_roto":
			CityProps.part(b, CityProps.box(Vector3(0.18, 0.03, 0.34)), Color("1c1c22"), Vector3(0, 0.02, 0))
			var screen := Color("3a5a8a") if what == "movil" else Color("8a8f98")
			CityProps.part(b, CityProps.box(Vector3(0.15, 0.01, 0.28)), screen, Vector3(0, 0.04, 0))
		"cartera":
			CityProps.part(b, CityProps.box(Vector3(0.26, 0.06, 0.18)), Color("5a3a22"), Vector3(0, 0.03, 0))
		"cobre":
			var coil := TorusMesh.new()
			coil.inner_radius = 0.16
			coil.outer_radius = 0.28
			for i in 3:
				CityProps.part(b, coil, Color("c0703a"), Vector3(0, 0.04 + i * 0.07, 0))
		"chatarra":
			CityProps.part(b, CityProps.box(Vector3(1.4, 0.08, 0.7)), Color("6a6a70"), Vector3(0, 0.25, 0), Vector3(0.35, 0, 0))
			CityProps.part(b, CityProps.cylinder(0.05, 0.05, 1.2), Color("8a8078"), Vector3(0.3, 0.06, 0.5), Vector3(0, 0, PI / 2))
			CityProps.part(b, CityProps.cylinder(0.05, 0.05, 1.0), Color("7a7068"), Vector3(-0.2, 0.06, 0.6), Vector3(0, 0.5, PI / 2))
		"bici":
			var wheel := TorusMesh.new()
			wheel.inner_radius = 0.3
			wheel.outer_radius = 0.35
			for x in [-0.55, 0.55]:
				CityProps.part(b, wheel, Color("1a1a1a"), Vector3(x, 0.35, 0), Vector3(PI / 2, 0, 0))
			var frame := Color("b03a3a")
			CityProps.part(b, CityProps.box(Vector3(1.0, 0.05, 0.05)), frame, Vector3(0, 0.6, 0))
			CityProps.part(b, CityProps.box(Vector3(0.05, 0.4, 0.05)), frame, Vector3(-0.2, 0.45, 0), Vector3(0, 0, 0.4))
			CityProps.part(b, CityProps.box(Vector3(0.05, 0.05, 0.5)), Color("2a2a2a"), Vector3(0.5, 0.85, 0))
			CityProps.part(b, CityProps.box(Vector3(0.22, 0.05, 0.12)), Color("2a2a2a"), Vector3(-0.3, 0.72, 0))
		"patinete":
			CityProps.part(b, CityProps.box(Vector3(0.9, 0.06, 0.18)), Color("2a2a30"), Vector3(0, 0.12, 0))
			CityProps.part(b, CityProps.cylinder(0.03, 0.03, 1.0), Color("4a4a52"), Vector3(0.42, 0.62, 0))
			CityProps.part(b, CityProps.box(Vector3(0.05, 0.05, 0.45)), Color("1a1a1a"), Vector3(0.42, 1.12, 0))
			for x in [-0.4, 0.42]:
				CityProps.part(b, CityProps.cylinder(0.09, 0.09, 0.06), Color("1a1a1a"), Vector3(x, 0.09, 0), Vector3(PI / 2, 0, 0))
		"sobras":
			CityProps.part(b, CityProps.box(Vector3(0.45, 0.05, 0.45)), Color("c8a878"), Vector3(0, 0.03, 0))
			CityProps.part(b, CityProps.box(Vector3(0.45, 0.02, 0.2)), Color("c8a878"), Vector3(0, 0.12, -0.24), Vector3(-1.1, 0, 0))
		_:
			# basura: bolsas negras o cartones, según la tirada (siempre igual para el mismo objeto)
			if roll < 0.5:
				CityProps.part(b, CityProps.sphere(0.3), Color("18181c"), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.1))
				CityProps.part(b, CityProps.sphere(0.22), Color("222228"), Vector3(0.35, 0.16, 0.2), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
			else:
				CityProps.part(b, CityProps.box(Vector3(0.7, 0.03, 0.5)), Color("a08060"), Vector3(0, 0.02, 0), Vector3(0, 0.3, 0))
				CityProps.part(b, CityProps.box(Vector3(0.4, 0.3, 0.35)), Color("b09070"), Vector3(0.2, 0.15, 0.1), Vector3(0, -0.4, 0.2))
