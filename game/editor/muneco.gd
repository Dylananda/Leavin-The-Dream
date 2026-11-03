class_name VistaMuneco
extends SubViewportContainer
## Muñeco del personaje que se está diseñando, con el mismo modelo que en el juego (Actor).
## Se gira arrastrando con el ratón (o solo, si `girar` está activo) y puede andar en el
## sitio. Con `noche` se ve con la luz de las farolas.

const VUELTA := 0.6  ## radianes por segundo al girar solo
const ARRASTRE := 0.01  ## radianes por píxel al arrastrar

var girar := true
var andar := false:
	set(v):
		andar = v
		if _actor:
			_actor.puppet_walk = v
var noche := false:
	set(v):
		noche = v
		_luz()

var _viewport: SubViewport
var _pivot: Node3D
var _actor: Actor
var _sun: DirectionalLight3D
var _env: Environment
var _drag := false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(300, 380)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.0, 6.4)
	cam.fov = 40.0
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 1.45, 0))

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 30, 0)
	_viewport.add_child(_sun)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = _env
	_viewport.add_child(we)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	# baldosa de acera bajo los pies
	CityProps.part(_pivot, CityProps.cylinder(1.6, 1.6, 0.1, 32), Color("8a8478"), Vector3(0, -0.05, 0))
	_luz()


## Vuelve a montar el muñeco con este aspecto.
func mostrar(look: Dictionary, accesorio: String, tamano: float) -> void:
	if _actor:
		_actor.queue_free()
	_actor = Actor.new()
	_actor.look = look
	_actor.accessory = accesorio
	_actor.body_size = tamano
	_actor.puppet_walk = andar
	_actor.set_process(true)
	_pivot.add_child(_actor)
	_actor.set_silhouette(Color.TRANSPARENT)


func _process(delta: float) -> void:
	if girar and not _drag:
		_pivot.rotation.y += VUELTA * delta


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_pivot.rotation.y += event.relative.x * ARRASTRE


func _luz() -> void:
	if _sun == null:
		return
	if noche:
		_env.background_color = Color("10121c")
		_env.ambient_light_color = Color("4a5070")
		_env.ambient_light_energy = 0.7
		_sun.light_color = Color("ffb060")
		_sun.light_energy = 0.7
	else:
		_env.background_color = Color("2a2830")
		_env.ambient_light_color = Color("b0b0c0")
		_env.ambient_light_energy = 0.6
		_sun.light_color = Color("fff4e0")
		_sun.light_energy = 1.1
