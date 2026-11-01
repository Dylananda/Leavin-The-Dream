class_name Minigame
extends Control
## Minijuego de habilidad para una acción (robar, vigilar...): tapa el barrio con otra vista y
## otros controles mientras el juego está en pausa, y termina con un resultado (`finished`).
## La vista es un escenario 3D propio (SubViewport) con marionetas de los personajes, más una
## capa 2D encima para las manos, los iconos y los avisos. Cada minijuego pone su escenario
## (`_setup_stage`), su lógica (`_tick`) y su dibujo (`_draw_overlay`).
## Sin pantalla (tests --headless) no se juega: World.play_minigame lo decide al momento con
## `auto_result` y la probabilidad de siempre, así que el equilibrio es el mismo.

signal finished(result: String)

const FRAME := Vector2(900, 520)  ## tamaño de la vista (unidades del HUD, que se escala en 4K)
const END_SECONDS := 1.6  ## lo que se ve el cartel del resultado antes de volver al barrio
const C_SUSPECT := Color("ffd23c")
const C_HUNTER := Color("ff4a3c")
const C_GOOD := Color("8fe07a")

var title := ""
var help := ""  ## controles, debajo de la vista
var difficulty := 0.5  ## 0..1 (1 - probabilidad de la acción)
var fx := {}  ## GameState.effects()["fx"]: el temblor, el retraso o el sueño también juegan
var stats := {}  ## cuentas del minijuego para quien lo lanzó (clientes, falsas alarmas...)
var give_up_result := "nada"  ## lo que pasa si te echas atrás con Esc
var test_mouse := Vector2.INF  ## (tests) ratón fijo en este punto de la vista

var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _overlay: Control
var _status: Label
var _time := 0.0
var _over := false
var _end_left := 0.0
var _end_text := ""
var _end_color := Color.WHITE
var _result := ""
var _blink := 0.0  ## 0..1: párpados que se cierran de sueño


## Resultado sin jugar, con la probabilidad `chance` de que salga bien (tests sin pantalla).
func auto_result(chance: float) -> String:
	return "ok" if randf() < chance else "mal"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# el padre es un CanvasLayer: las anclas no bastan, se ajusta a la pantalla a mano
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.9)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	box.add_child(t)
	# la vista: la imagen del escenario 3D y, encima, la capa de dibujo
	var holder := Control.new()
	holder.custom_minimum_size = FRAME
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	# a la resolución de la pantalla (en 4K, el triple), no a la del HUD
	var px := maxf(1.0, get_viewport().get_final_transform().get_scale().x)
	_viewport.size = Vector2i(FRAME * px)
	add_child(_viewport)
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(view)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_on_overlay_draw)
	holder.add_child(_overlay)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	box.add_child(_status)
	var h := Label.new()
	h.text = help + "   ·   Esc: dejarlo"
	h.modulate = Color(1, 1, 1, 0.7)
	box.add_child(h)
	box.reset_size()
	box.position = (get_viewport().get_visible_rect().size - box.size) / 2.0

	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_setup_stage()


func _process(delta: float) -> void:
	_time += delta
	if _over:
		_end_left -= delta
		_overlay.queue_redraw()
		if _end_left <= 0.0:
			set_process(false)
			finished.emit(_result)
		return
	# con sueño, los párpados se cierran a ratos
	var drowsy := clampf(fx.get("drowsy", 0.0), 0.0, 1.0)
	_blink = clampf(sin(_time * 0.7) * 1.4 - 1.4 + drowsy * 1.6, 0.0, 0.9) if drowsy > 0.1 else 0.0
	_tick(delta)
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if _over:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		finish(give_up_result, "Lo dejas estar.", Color(0.85, 0.85, 0.85))


## Termina el minijuego con `result`; `text` se ve en grande un momento antes de volver.
func finish(result: String, text: String, color: Color) -> void:
	if _over:
		return
	_over = true
	_result = result
	_end_text = text
	_end_color = color
	_end_left = END_SECONDS


## La posición en la vista (unidades del HUD) de un punto del escenario 3D.
func to_frame(p: Vector3) -> Vector2:
	return _camera.unproject_position(p) * FRAME / Vector2(_viewport.size)


## Ratón en la vista, con el temblor de manos del mono o la farlopa.
func shaky_mouse() -> Vector2:
	var shake := clampf(fx.get("shake", 0.0), 0.0, 1.5)
	var jitter := Vector2(sin(_time * 23.0) + sin(_time * 37.0) * 0.5, cos(_time * 19.0) + cos(_time * 31.0) * 0.5)
	var m := test_mouse if test_mouse.is_finite() else _overlay.get_local_mouse_position()
	return m + jitter * shake * 9.0


## Una marioneta con el aspecto de `who` (un Npc o el jugador): mismo cuerpo, sin cerebro.
static func puppet_of(who: Actor) -> Actor:
	var a := Actor.new()
	a.display_name = who.display_name
	a.look = who.look.duplicate()
	a.accessory = who.accessory
	a.body_size = who.body_size
	return a


## Una marioneta de un bot de tipo `kind` cualquiera (su aspecto sale del nombre, como en el barrio).
static func puppet_of_kind(kind: String) -> Actor:
	var npc := Npc.new()
	npc.init_kind(kind)
	var a := puppet_of(npc)
	npc.free()
	return a


## Luz, cielo y suelo del escenario: de día o de noche según la hora del juego.
func _lighting(wall: Color) -> void:
	var night := GameState.is_night()
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-30), 0)
	sun.light_energy = 0.45 if night else 1.0
	sun.light_color = Color(1.0, 0.8, 0.55) if night else Color(1.0, 0.97, 0.9)
	_stage.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.12) if night else Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.3, 0.42) if night else Color(0.6, 0.6, 0.62)
	_stage.add_child(env)
	_box(Vector3(60, 0.1, 30), Color(0.32, 0.31, 0.3) if night else Color(0.55, 0.53, 0.5), Vector3(0, -0.05, -5))
	_box(Vector3(60, 14, 0.5), wall.darkened(0.45) if night else wall, Vector3(0, 7, -14))


## Una caja de color en el escenario (paredes, escaparates, la manta...).
func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CityProps.box(size)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	_stage.add_child(mi)
	return mi


func _on_overlay_draw() -> void:
	_draw_overlay(_overlay)
	if _blink > 0.0:
		var h := FRAME.y * 0.5 * _blink
		_overlay.draw_rect(Rect2(0, 0, FRAME.x, h), Color.BLACK)
		_overlay.draw_rect(Rect2(0, FRAME.y - h, FRAME.x, h), Color.BLACK)
	if _over:
		var font := _overlay.get_theme_default_font()
		var ts := font.get_string_size(_end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
		var at := Vector2((FRAME.x - ts.x) / 2.0, FRAME.y / 2.0)
		_overlay.draw_rect(Rect2(0, at.y - 46, FRAME.x, 66), Color(0, 0, 0, 0.6))
		_overlay.draw_string_outline(font, at, _end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color.BLACK)
		_overlay.draw_string(font, at, _end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, _end_color)


## Texto con contorno, centrado en `at` (para los «?» y «!» de las marionetas).
func _icon(c: Control, at: Vector2, text: String, color: Color, font_size := 30) -> void:
	var font := c.get_theme_default_font()
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var p := at - Vector2(s.x / 2.0, -s.y / 3.0)
	c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color.BLACK)
	c.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# -------------------------------------------------- lo que pone cada minijuego

func _setup_stage() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _draw_overlay(_c: Control) -> void:
	pass
