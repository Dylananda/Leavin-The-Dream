class_name World
extends Node3D
## Escena de juego: el barrio en 3D, el jugador, los bots y el HUD.
## Gestiona el paso del tiempo, la cámara isométrica, la entrada y los eventos del barrio.

## Bots por tipo en un barrio "mediano"; se multiplican por el índice de criminalidad.
## Solo salen a la calle en sus horas (Npc.KINDS[...]["hours"]).
const BASE_NPCS := {
	"turista": [40, ""],
	"vecino": [25, ""],
	"policia": [6, "total"],
	"yonki": [10, "vulnerables"],
	"camello": [4, "vulnerables"],
	"mantero": [3, "venta_ambulante"],
	"educador": [4, ""],
	"fiestero": [8, "locales"],
	"latero": [3, "venta_ambulante"],
	"trilero": [2, ""],
	"carterista": [4, ""],
	"chaval": [4, ""],
}
## Calles de cada zona de Npc.KINDS (nombres de OpenStreetMap).
const ZONE_STREETS := {
	"rambla": ["La Rambla"],
	"rambla_raval": ["Rambla del Raval", "Carrer de Sant Pau", "Carrer d'en Robador"],
}
const DESPAWN_DISTANCE := 30  ## casillas: fuera de su horario se van cuando no los ves
const PLAYER_SPEED := 18.0  ## metros por segundo
const RUN_FACTOR := 1.7  ## multiplicador de velocidad con Shift
const INTERACT_RANGE := 4  ## casillas
const CAMERA_PITCH := -40.0  ## grados; vista isométrica algo más cenital que la clásica
const CAMERA_DISTANCE := 160.0
const ZOOM_RANGE := Vector2(10.0, 110.0)  ## tamaño ortográfico (metros de alto en pantalla)
const PICK_RADIUS_PX := 28.0
const WITNESS_KINDS := ["vecino", "turista"]  ## gente que se escandaliza si te ve consumiendo
## Para encontrar a la gente tras los edificios: color de la silueta (con su opacidad) y del
## icono flotante de cada caso. El resto de bots usan Actor.SILHOUETTE, más tenue.
const C_PLAYER_SILHOUETTE := Color(1.0, 0.85, 0.2, 0.85)
const C_POLICE_SILHOUETTE := Color(0.35, 0.55, 1.0, 0.6)
const C_OFFER := Color("ffd23c")  ## te puede dar un encargo («!»)
const C_GIVER := Color("ff9a3c")  ## te ha dado un encargo en marcha («★»)
const C_POINTER := Color("ffd23c")  ## flechas hacia los sitios apuntados en la libreta
## Rayos X alrededor del jugador: radio en metros (sobre el tamaño de la cámara),
## más grande al andar con WASD para ver bien la calle por la que vas.
const XRAY_RADIUS_M := 6.0
const XRAY_RADIUS_WALKING_M := 9.0
## Conos de visión en el suelo: se dibujan los de la policía y los de quien va a por ti a
## menos de esta distancia (casillas); con V, los de todos.
const CONE_SHOW_DISTANCE := 40
const C_SUSPECT := Color("ffd23c")  ## «?» de quien te está viendo y sospecha
const C_HUNTER := Color("ff4a3c")  ## «!» de quien te persigue (y su silueta)
const GRAB_SECONDS := 1.5  ## lo que te retiene un transeúnte que te agarra

var city: CityMap
var player: Actor
var camera: Camera3D
var hud: Hud
var interactions: Interactions
var errands: Errands  ## Encargos con plazo y libreta
var conversation: Conversation  ## Conversación libre con IA (scripts/ai/)
var npcs: Array[Npc] = []
var markers: Array[PoiMarker] = []

var _sun: DirectionalLight3D
var _env: Environment
var _camera_yaw := 45.0
var _camera_yaw_target := 45.0
var _camera_focus := Vector3.ZERO
var _street_timer := 0.0
var _pending: Variant = null  ## Npc o PoiMarker al que vamos a interactuar
var _pending_tries := 0
var _npc_targets := {}
var _event_timer := 20.0
var _respawn_timer := 30.0
var _last_rummage := -999.0
var _time := 0.0
var _camera_zoom := 34.0  ## zoom elegido con la rueda; las sustancias lo alteran por encima
var _fx := {}  ## efectos de GameState.effects() en este frame
var _input_smooth := Vector3.ZERO  ## dirección de WASD con el retraso del alcohol
var _stumble := 0.0  ## segundos que quedan de tropiezo
var _stumble_timer := 3.0
var _marker_timer := 0.0
var _xray_m := XRAY_RADIUS_M
var _all_cones := false  ## tecla V: ver los conos de visión de todos los cercanos
var _grabbed := 0.0  ## segundos que te quedan agarrado por un transeúnte


func _ready() -> void:
	if GameState.profile.is_empty():
		GameState.new_game("parado")  # al lanzar la escena directamente desde el editor

	city = CityMap.new()
	add_child(city)
	_setup_lighting()

	player = Actor.new()
	player.display_name = GameState.profile["name"]
	player.look = GameState.profile["look"]
	player.speed = PLAYER_SPEED
	city.entities.add_child(player)
	var benches := city.pois_of_kind("banco")
	var start: Vector2i = city.random_walkable()
	if not benches.is_empty():
		var b: Dictionary = benches.pick_random()
		start = Vector2i(b["x"], b["y"])
	player.setup(city, start)
	player.arrived.connect(_on_player_arrived)
	# aro bajo los pies para encontrarte entre la multitud
	var ring := CityProps.part(player, CityProps.cylinder(1.1, 1.1, 0.05, 24), Color(1.0, 0.85, 0.2), Vector3(0, 0.05, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.set_silhouette(C_PLAYER_SILHOUETTE)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _camera_zoom
	camera.near = 1.0
	camera.far = 600.0
	add_child(camera)
	_camera_focus = player.position
	_fx = GameState.effects()
	_update_camera(1.0)

	interactions = Interactions.new(self)
	errands = Errands.new(self)
	conversation = Conversation.new(self)
	add_child(conversation)
	_place_markers()
	for kind in BASE_NPCS:
		_npc_targets[kind] = _target_count(kind)
		if Npc.active_at(kind, GameState.hour()):
			for i in _npc_targets[kind]:
				_spawn_npc(kind)

	hud = Hud.new()
	add_child(hud)
	hud.menu_closed.connect(func(): get_tree().paused = false)
	hud.restart_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hud.use_item_requested.connect(use_item)
	hud.find_place_requested.connect(highlight_poi)
	GameState.game_over.connect(_on_game_over)
	GameState.relocated.connect(_on_relocated)

	_intro()


func _setup_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 320.0
	_sun.shadow_bias = 0.05
	add_child(_sun)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)


func _intro() -> void:
	var c := city.crime
	GameState.log_msg("Bienvenido a %s, %s." % [city.barrio_name, GameState.profile["name"]])
	if not c.is_empty():
		GameState.log_msg("Datos reales: nº%d de %d barrios de Barcelona en incidentes de la Guàrdia Urbana (%s en %d)." % [
			c["rank"], c["barrios"], _thousands(c["total_incidents"]), c["year"]], Color("e0c080"))
	GameState.log_msg("Objetivo: caer lo más bajo posible... sin morirte antes de tiempo.", GameState.C_FALL)
	GameState.log_msg(GameState.profile["perk"])


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _target_count(kind: String) -> int:
	var base: int = BASE_NPCS[kind][0]
	var category: String = BASE_NPCS[kind][1]
	if category == "":
		return base
	return roundi(base * city.crime_factor(category))


func _place_markers() -> void:
	var used := {}
	for p in city.pois:
		var key := Vector2i(p["x"], p["y"])
		if used.has(key):
			continue
		used[key] = true
		var m := PoiMarker.new()
		m.setup(p, city.cell_to_world(key))
		city.entities.add_child(m)
		markers.append(m)


func _spawn_npc(kind: String) -> void:
	var npc := Npc.new()
	npc.init_kind(kind)
	npc.player = player
	npc.world = self
	var home: Vector2i
	var zone: String = Npc.KINDS[kind].get("zone", "")
	if zone != "":
		home = _zone_cell(zone)
	else:
		home = _default_home(kind)
	npc.home = home
	city.entities.add_child(npc)
	npc.setup(city, city.random_walkable_near(home, 8))
	npc.caught_player.connect(_on_caught)
	npcs.append(npc)


## Casilla al azar de una zona: sus calles, o cerca de los bares para la noche.
func _zone_cell(zone: String) -> Vector2i:
	if zone == "bares":
		var bars := city.pois_of_kind("bar")
		if not bars.is_empty():
			var b: Dictionary = bars.pick_random()
			return city.random_walkable_near(Vector2i(b["x"], b["y"]), 6)
	var cells: Array[Vector2i] = []
	for street in ZONE_STREETS.get(zone, []):
		cells.append_array(city.street_cells(street))
	return cells.pick_random() if not cells.is_empty() else city.random_walkable()


func _default_home(kind: String) -> Vector2i:
	var home: Vector2i
	match kind:
		"camello":
			home = _random_cell_of(CityMap.Cell.STREET)
		"mantero":
			home = _random_cell_of(CityMap.Cell.PLAZA)
		"educador", "yonki":
			var near := city.pois_of_kind("cas") + city.pois_of_kind("albergue")
			if kind == "yonki" and randf() < 0.5:
				home = city.random_walkable()
			elif not near.is_empty():
				var p: Dictionary = near.pick_random()
				home = city.random_walkable_near(Vector2i(p["x"], p["y"]), 20)
			else:
				home = city.random_walkable()
		"turista":
			var spots := city.pois_of_kind("bar") + city.pois_of_kind("kebab")
			var p: Dictionary = spots.pick_random()
			home = Vector2i(p["x"], p["y"])
		_:
			home = city.random_walkable()
	return home


func _random_cell_of(type: int) -> Vector2i:
	for i in 200:
		var c := city.random_walkable()
		if city.cell_type(c) == type:
			return c
	return city.random_walkable()


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	_time += delta
	if GameState.alive:
		GameState.advance(delta * Defs.GAME_MINUTES_PER_SECOND)
		errands.update()
	_fx = GameState.effects()
	hud.show_effects(_fx)
	_update_player_state(delta)
	_update_player_input(delta)
	_update_camera(delta)
	_update_daylight()
	_update_xray(delta)
	_update_hover()
	_update_pointers()
	_marker_timer -= delta
	if _marker_timer <= 0.0:
		_marker_timer = 0.25
		_update_markers()
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = 0.4
		hud.set_street(city.street_name_near(player.cell, 12))
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = randf_range(15.0, 35.0) / city.crime_factor("peleas")
		_random_event()
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = 30.0
		_respawn()


## Velocidad, eses, tropiezos y ritmo del tiempo según las sustancias, el mono y el cuerpo
## (los efectos y sus intensidades vienen de GameState.effects() y se equilibran en Defs).
func _update_player_state(delta: float) -> void:
	var fx: Dictionary = _fx["fx"]
	var slow := clampf(1.0 + fx.get("speed", 0.0), 0.35, 1.7)
	# torpeza (mono): de vez en cuando tropiezas y casi te paras
	_stumble = maxf(0.0, _stumble - delta)
	var clumsy: float = fx.get("clumsy", 0.0)
	if clumsy > 0.0 and (player.is_moving() or player.input_dir != Vector3.ZERO):
		_stumble_timer -= delta * clumsy
		if _stumble_timer <= 0.0:
			_stumble_timer = randf_range(2.5, 6.0)
			_stumble = 0.45
			player.say(["¡Uy!", "Mierda...", "*tropieza*"].pick_random(), 1.0)
	if _stumble > 0.0:
		slow *= 0.15
	_grabbed = maxf(0.0, _grabbed - delta)
	if _grabbed > 0.0:
		slow = 0.0
	player.slow_factor = slow
	# andando por clic también se hacen eses
	player.wobble = clampf(fx.get("drift", 0.0), 0.0, 1.0)
	# el porro estira el tiempo: todo el barrio (y el reloj) va más lento
	Engine.time_scale = lerpf(1.0, 0.6, clampf(fx.get("slowmo", 0.0), 0.0, 1.0))


## WASD (o las flechas) mueven al jugador respecto a la pantalla; Shift para correr.
## Con alcohol la dirección se desvía (eses) y responde con retraso.
func _update_player_input(delta: float) -> void:
	var fx: Dictionary = _fx["fx"]
	var v := Vector2.ZERO
	if GameState.alive and not hud.is_menu_open():
		v.x = float(_held(KEY_D, KEY_RIGHT)) - float(_held(KEY_A, KEY_LEFT))
		v.y = float(_held(KEY_S, KEY_DOWN)) - float(_held(KEY_W, KEY_UP))
	player.run_factor = RUN_FACTOR if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var target := Vector3.ZERO
	if v != Vector2.ZERO:
		_pending = null
		var drift := clampf(fx.get("drift", 0.0), 0.0, 1.0)
		v = v.rotated((sin(_time * 0.9) * 0.7 + sin(_time * 2.3) * 0.3) * 0.8 * drift)
		# ejes de la cámara aplanados sobre el suelo: +X a la derecha de la pantalla, +Z hacia abajo
		var b := camera.global_transform.basis
		var right := Vector3(b.x.x, 0, b.x.z).normalized()
		var down := Vector3(b.z.x, 0, b.z.z).normalized()
		target = (right * v.x + down * v.y).normalized()
	var lag := clampf(fx.get("lag", 0.0), 0.0, 1.0)
	_input_smooth = _input_smooth.lerp(target, minf(1.0, delta * lerpf(30.0, 2.5, lag)))
	if target == Vector3.ZERO and _input_smooth.length() < 0.08:
		_input_smooth = Vector3.ZERO
	player.input_dir = _input_smooth


func _held(letter: Key, arrow: Key) -> bool:
	return Input.is_physical_key_pressed(letter) or Input.is_key_pressed(arrow)


## Cámara ortográfica que sigue al jugador; Q/E la giran de 90 en 90 grados.
## Las sustancias la alteran: el caballo la balancea, la farlopa y el mono la hacen temblar,
## el porro la acerca y la base la aleja.
func _update_camera(delta: float) -> void:
	var fx: Dictionary = _fx["fx"]
	_camera_focus = _camera_focus.lerp(player.position, minf(1.0, delta * 6.0))
	_camera_yaw = lerpf(_camera_yaw, _camera_yaw_target, minf(1.0, delta * 8.0))
	var zoom := clampf(fx.get("zoom", 0.0), -0.5, 1.0)
	camera.size = lerpf(camera.size, _camera_zoom * (1.0 - 0.35 * zoom), minf(1.0, delta * 3.0))
	var sway := clampf(fx.get("sway", 0.0), 0.0, 1.5)
	var yaw := deg_to_rad(_camera_yaw + sin(_time * 1.1) * 6.0 * sway)
	var pitch := deg_to_rad(CAMERA_PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	camera.position = _camera_focus + dir * CAMERA_DISTANCE
	camera.look_at(_camera_focus, Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD, sin(_time * 1.3) * 0.05 * sway)
	var shake := clampf(fx.get("shake", 0.0), 0.0, 1.5)
	if shake > 0.0:
		var jitter := Vector3(sin(_time * 37.0) + sin(_time * 23.3), cos(_time * 31.0) + sin(_time * 19.7), 0.0)
		camera.translate_object_local(jitter * shake * 0.004 * camera.size)


## Luz según la hora: sol que cruza el cielo, atardecer naranja, noche azul con ventanas encendidas.
func _update_daylight() -> void:
	var h := GameState.minute_of_day / 60.0
	var day := clampf(sin((h - 6.5) / 13.0 * PI), 0.0, 1.0)  # 0 de noche, 1 a mediodía
	var dusk := clampf(1.0 - absf(h - 19.5) / 1.5, 0.0, 1.0) + clampf(1.0 - absf(h - 7.0) / 1.0, 0.0, 1.0) * 0.6
	var sun_color := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.6, 0.35), dusk)
	_sun.light_color = sun_color if day > 0.0 else Color(0.55, 0.62, 0.9)
	_sun.light_energy = lerpf(0.2, 0.95, day)
	_sun.rotation = Vector3(deg_to_rad(-25.0 - 45.0 * day), deg_to_rad(-60.0 + (h - 12.0) * 6.0), 0)
	var ambient := Color(0.16, 0.18, 0.34).lerp(Color(0.5, 0.5, 0.54), day)
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = 0.8
	_env.background_color = Color(0.05, 0.05, 0.1).lerp(Color(0.32, 0.42, 0.55), day)
	city.building_material.set_shader_parameter("night", clampf(1.0 - day * 2.5, 0.0, 1.0))


## Pasa al shader de edificios dónde está el jugador en pantalla y a qué profundidad,
## para hacer transparentes los que lo tapan. Al andar con WASD el agujero crece.
func _update_xray(delta: float) -> void:
	var want := XRAY_RADIUS_WALKING_M if player.input_dir != Vector3.ZERO else XRAY_RADIUS_M
	_xray_m = lerpf(_xray_m, want, minf(1.0, delta * 3.0))
	var vp := get_viewport().get_visible_rect().size
	var target := player.global_position + Vector3(0, 1.2, 0)
	for mat in [city.building_material, CityProps.foliage_material]:
		mat.set_shader_parameter("focus_uv", camera.unproject_position(target) / vp)
		mat.set_shader_parameter("focus_depth", -(camera.global_transform.affine_inverse() * target).z)
		mat.set_shader_parameter("aspect", vp.x / vp.y)
		mat.set_shader_parameter("xray_radius", clampf(_xray_m / camera.size, 0.06, 0.4))


## Iconos, siluetas y conos de los bots: quién te persigue («!») o sospecha de ti («?»),
## quién te puede dar un encargo, quién te lo ha dado y la policía.
func _update_markers() -> void:
	for npc in npcs:
		var mark := errands.marker_for(npc)
		var color := C_GIVER if mark == "★" else C_OFFER
		if npc.mode in ["persigue", "busca"]:
			mark = "!"
			color = C_HUNTER
		elif npc.alert > 0.05:
			mark = "?"
			color = C_SUSPECT
		npc.set_marker(mark, color)
		var near := npc.distance_to_cell(player.cell) <= CONE_SHOW_DISTANCE
		npc.cone_visible = near and (_all_cones or npc.kind == "policia" or npc.mode != "" or npc.alert > 0.05)
		if color == C_HUNTER:
			npc.set_silhouette(Color(C_HUNTER, 0.75))
		elif mark != "":
			npc.set_silhouette(Color(color, 0.75))
		elif npc.kind == "policia":
			npc.set_silhouette(C_POLICE_SILHOUETTE)
		else:
			npc.set_silhouette(Actor.SILHOUETTE)


## Flechas del HUD hacia los sitios de los encargos en marcha, según la libreta.
func _update_pointers() -> void:
	var list := []
	for n in errands.noted_places():
		var poi: Dictionary = n["poi"]
		var at := city.cell_to_world(Vector2i(poi["x"], poi["y"]))
		var meters := snappedi(int(player.position.distance_to(at)), 10)
		list.append({
			"pos": camera.unproject_position(at + Vector3(0, PoiMarker.SIGN_Y + 1.5, 0)),
			"label": "%s · %d m" % [errands.place_name(poi), meters],
			"color": C_POINTER,
		})
	hud.set_pointers(list)


func _update_hover() -> void:
	var m := get_viewport().get_mouse_position()
	var npc := _npc_at(m)
	var text := ""
	if npc:
		text = npc.label()
	else:
		var marker := _marker_at(m)
		if marker:
			var p: Dictionary = marker.poi
			text = Interactions.POI_LABELS.get(p["kind"], p["kind"])
			if p["name"] != "":
				text += ": " + p["name"]
	hud.set_hover(text, m)


## Selección por pantalla: el bot cuyo cuerpo proyectado queda más cerca del ratón.
func _npc_at(screen_pos: Vector2) -> Npc:
	var best: Npc = null
	var best_d := PICK_RADIUS_PX
	for npc in npcs:
		var body := npc.global_position + Vector3(0, 1.4, 0)
		if camera.is_position_behind(body):
			continue
		var d := camera.unproject_position(body).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = npc
	return best


func _marker_at(screen_pos: Vector2) -> PoiMarker:
	var best: PoiMarker = null
	var best_d := PICK_RADIUS_PX
	for m in markers:
		var d := camera.unproject_position(m.sign_position()).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = m
	return best


## Punto del suelo (Y = 0) bajo el ratón.
func _ground_at(screen_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	return hit if hit != null else player.position


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.alive or hud.is_menu_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_click(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				_camera_zoom = clampf(_camera_zoom / 1.12, ZOOM_RANGE.x, ZOOM_RANGE.y)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera_zoom = clampf(_camera_zoom * 1.12, ZOOM_RANGE.x, ZOOM_RANGE.y)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_camera_yaw_target -= 90.0
			KEY_E:
				_camera_yaw_target += 90.0
			KEY_I:
				hud.toggle_inventory()
			KEY_L:
				hud.toggle_notebook(errands)
			KEY_R:
				_rummage()
			KEY_Z:
				_sleep_here()
			KEY_V:
				_all_cones = not _all_cones
				_update_markers()


func _on_click(screen_pos: Vector2) -> void:
	var npc := _npc_at(screen_pos)
	if npc:
		_approach(npc)
		return
	var marker := _marker_at(screen_pos)
	if marker:
		_approach(marker)
		return
	_pending = null
	player.walk_to(city.world_to_cell(_ground_at(screen_pos)))


func _approach(target: Node3D) -> void:
	_pending = target
	_pending_tries = 0
	if _target_cell(target) == player.cell or player.distance_to_cell(_target_cell(target)) <= INTERACT_RANGE:
		player.stop()
		_open_pending()
	else:
		player.walk_to(_target_cell(target))


func _target_cell(target: Node3D) -> Vector2i:
	if target is Npc:
		return target.cell
	return Vector2i(target.poi["x"], target.poi["y"])


func _on_player_arrived() -> void:
	if _pending == null or not is_instance_valid(_pending):
		_pending = null
		return
	if player.distance_to_cell(_target_cell(_pending)) <= INTERACT_RANGE:
		_open_pending()
	elif _pending_tries < 6:
		_pending_tries += 1
		player.walk_to(_target_cell(_pending))
	else:
		_pending = null


func _open_pending() -> void:
	var target: Node3D = _pending
	_pending = null
	var title := ""
	var actions: Array
	if target is Npc:
		var npc := target as Npc
		npc.stop()
		npc.known = true
		title = npc.label()
		actions = interactions.for_npc(npc)
	else:
		var p: Dictionary = (target as PoiMarker).poi
		title = Interactions.POI_LABELS.get(p["kind"], p["kind"])
		if p["name"] != "":
			title += " · " + p["name"]
		actions = interactions.for_poi(p)
	get_tree().paused = true
	hud.show_menu(title, actions)


# ------------------------------------------------------------------ acciones

func use_item(id: String) -> void:
	if not Defs.usable(id):
		return
	if id == "paquete":
		errands.open_package()
		return
	if id == "cartera":
		GameState.remove_item("cartera")
		var n := randi_range(5, 90)
		GameState.add_money(n)
		GameState.log_msg("La cartera tenía %d €. Las fotos de sus hijos las tiras a la papelera." % n, GameState.C_GOOD)
		GameState.change_dignity(-1)
		return
	if Defs.SUBSTANCES.has(id):
		if police_watching() > 0:
			GameState.heat = minf(100.0, GameState.heat + 35.0)
			GameState.log_msg("Un agente te ha visto consumiendo en plena calle.", GameState.C_BAD)
		elif not watching(WITNESS_KINDS).is_empty():
			GameState.heat = minf(100.0, GameState.heat + 10.0)
			GameState.change_dignity(-2, "Te ven metiéndote en plena calle")
	GameState.consume(id)


func _rummage() -> void:
	if _time - _last_rummage < 8.0:
		GameState.log_msg("Ya has revuelto toda la basura de por aquí.")
		return
	_last_rummage = _time
	GameState.advance(15)
	var r := randf()
	if r < 0.3:
		GameState.log_msg("Nada. Solo cáscaras y una paloma muerta.")
	elif r < 0.5:
		GameState.add_item("sobras")
		GameState.log_msg("Medio bocadillo. Casi sin morder.", GameState.C_GOOD)
	elif r < 0.65:
		GameState.add_item("cobre")
		GameState.log_msg("¡Un cable de cobre! Esto se vende.", GameState.C_GOOD)
	elif r < 0.75:
		GameState.add_item("movil_roto")
		GameState.log_msg("Un móvil con la pantalla hecha añicos.", GameState.C_GOOD)
	elif r < 0.9:
		var n := randi_range(1, 3)
		GameState.add_money(n)
		GameState.log_msg("%d € entre la mierda." % n, GameState.C_GOOD)
	else:
		GameState.change_health(-6, "Una jeringuilla en la basura")
		GameState.log_msg("Te pinchas con una jeringuilla usada.", GameState.C_BAD)
	GameState.change_dignity(-2)
	GameState.milestone("rebuscar")


func _sleep_here() -> void:
	sleep(6 * 60, 0.35, 10.0, 0.5)
	GameState.change_dignity(-5, "Dormir en el suelo de %s" % city.street_name_near(player.cell))
	GameState.milestone("primera_calle")


## Duerme `minutes` minutos. `robbery_risk` es la probabilidad de que te roben si llevas dinero;
## `quality` (0..1), lo que se descansa en ese sitio (ver GameState.rest).
func sleep(minutes: float, robbery_risk: float, heal: float, quality: float) -> void:
	player.stop()
	GameState.rest(minutes, quality, robbery_risk, heal)


func arrest_player() -> void:
	if not GameState.alive:
		return
	hud.close_menu()
	_pending = null
	player.stop()
	for npc in npcs:
		npc.calm_down()
	GameState.arrest()
	var stations := city.pois_of_kind("comisaria")
	if not stations.is_empty() and GameState.alive:
		var s: Dictionary = stations.pick_random()
		player.setup(city, Vector2i(s["x"], s["y"]))
		GameState.log_msg("Te sueltan en la puerta de la comisaría.")


## Tras un desmayo o un ingreso apareces en otro sitio (por ahora, el centro de salud más cercano).
func _on_relocated(place: String) -> void:
	hud.close_menu()
	_pending = null
	player.stop()
	for npc in npcs:
		npc.calm_down()
	var spots := city.pois_of_kind(place)
	if spots.is_empty():
		return
	var best: Dictionary = spots[0]
	for p in spots:
		if player.distance_to_cell(Vector2i(p["x"], p["y"])) < player.distance_to_cell(Vector2i(best["x"], best["y"])):
			best = p
	player.setup(city, Vector2i(best["x"], best["y"]))
	_camera_focus = player.position


## Bots de los tipos `kinds` (todos, si está vacío) que te están viendo ahora, menos `except`.
func watching(kinds: Array = [], except: Npc = null) -> Array[Npc]:
	var out: Array[Npc] = []
	for npc in npcs:
		if npc != except and (kinds.is_empty() or npc.kind in kinds) and npc.can_see(player):
			out.append(npc)
	return out


## Agentes que te están viendo ahora (su cono te alcanza y no hay edificios en medio).
func police_watching() -> int:
	return watching(["policia"]).size()


## Testigos de un robo a `victim`: los que te ven y no viven de la calle (esos miran a otro lado).
func robbery_witnesses(victim: Npc) -> Array[Npc]:
	var out: Array[Npc] = []
	for npc in watching([], victim):
		if npc.kind not in Defs.NEVER_INTERVENE:
			out.append(npc)
	return out


## Escándalo: `shouter` (la víctima o un testigo; null si es un guardia de seguridad o alguien
## a quien no ves) grita `text`. Quien lo oye reacciona según su carácter (Npc.temper()):
## unos intentan pararte, otros llaman a la policía, otros pasan. Si lo oye un agente, viene;
## si no, quedas fichado. En cualquier caso, la policía que te vea irá a por ti.
func scandal(shouter: Npc, text: String) -> void:
	var gs := GameState
	var at := player.cell
	if shouter:
		at = shouter.cell
		shouter.say(text, 4.0)
		shouter.last_seen = player.cell
	_shout_ring(city.cell_to_world(at))
	gs.heat = maxf(gs.heat, Defs.CHASE_HEAT + 20.0)
	var police := false
	var stoppers := 0
	var callers := 0
	for npc in npcs:
		if npc == shouter or npc.distance_to_cell(at) > Defs.SCANDAL_HEAR:
			continue
		if npc.kind == "policia":
			npc.investigate(player.cell)
			police = true
			continue
		if npc.mode != "":
			continue
		match npc.temper():
			"valiente":
				npc.say("¡Quieto ahí!", 3.0)
				npc.start_chase("parar")
				stoppers += 1
			"llama":
				npc.say(["¡Policía! ¡Al ladrón!", "*llama al 112*", "¡Que alguien avise a la Urbana!"].pick_random(), 3.0)
				callers += 1
			_:
				if randf() < 0.3:
					npc.say(["Yo no he visto nada", "Uf, yo no me meto", "Otra vez..."].pick_random(), 2.5)
	if not police and callers > 0:
		# la llamada llega al agente más cercano, si está en el barrio
		var best: Npc = null
		for npc in npcs:
			if npc.kind == "policia" and npc.distance_to_cell(at) <= Defs.SCANDAL_CALL and (best == null or npc.distance_to_cell(at) < best.distance_to_cell(at)):
				best = npc
		if best:
			best.investigate(player.cell)
			police = true
	var where := city.street_name_near(at)
	var msg := "%s Se monta un escándalo en %s." % [text if shouter == null else "«%s»" % text, where]
	if stoppers > 0:
		msg += " %s intenta pararte." % ("Alguien" if stoppers == 1 else "Un par de valientes")
	if police:
		msg += " Viene la policía."
	gs.log_msg(msg, GameState.C_BAD)
	if not police:
		gs.mark_wanted("te han visto robar en %s y han dado tu descripción" % where)


## Onda roja en el suelo que muestra hasta dónde llega un grito.
func _shout_ring(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.2, 0.8)
	mat.no_depth_test = true
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = pos + Vector3(0, 0.2, 0)
	ring.scale = Vector3(1.0, 0.05, 1.0)
	city.entities.add_child(ring)
	var r := Defs.SCANDAL_HEAR * city.cell_m
	var tw := ring.create_tween()
	tw.set_parallel()
	tw.tween_property(ring, "scale", Vector3(r, 0.05, r), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


## Alguien que te perseguía te ha alcanzado. Según por qué: la policía te detiene, el camello
## se cobra, el robado recupera lo suyo y el transeúnte valiente te agarra un momento.
func _on_caught(npc: Npc) -> void:
	var gs := GameState
	match npc.chase_reason:
		"policia":
			arrest_player()
		"deuda":
			var paid := mini(gs.money, npc.debt)
			if paid > 0:
				gs.add_money(-paid)
				npc.debt -= paid
				gs.debt = maxi(0, gs.debt - paid)
				npc.say("Esto es mío.")
				gs.log_msg("%s te alcanza y te vacía los bolsillos: %d €. Le debes %d €." % [npc.display_name, paid, npc.debt], GameState.C_BAD)
			else:
				npc.say("¿No tienes nada? Pues toma.", 3.0)
				gs.change_health(-15, "Una paliza por una deuda")
				gs.change_dignity(-3)
				gs.log_msg("No llevas nada. %s te da una paliza para que no se te olvide." % npc.display_name, GameState.C_BAD)
				gs.milestone("pelea_perdida")
			npc.debt_due = gs.now() + Defs.DEBT_GRACE_HOURS * 60.0
		"venganza":
			npc.memory.erase("robado")
			var loot := ""
			for id in ["cartera", "movil"]:
				if gs.has_item(id):
					loot = id
					break
			if loot != "":
				gs.remove_item(loot)
				npc.say("Mine! ¡Es mío!", 3.0)
				gs.log_msg("%s te alcanza y te arranca %s." % [npc.display_name, Defs.item_name(loot).to_lower()], GameState.C_BAD)
			elif gs.money > 0:
				var n := mini(gs.money, 40)
				gs.add_money(-n)
				npc.say("Give me that! ¡Dame!", 3.0)
				gs.log_msg("%s te alcanza y se cobra lo suyo: %d €." % [npc.display_name, n], GameState.C_BAD)
			else:
				npc.say("Asshole!", 3.0)
				gs.change_health(-8, "El puño de alguien a quien robaste")
				gs.log_msg("No llevas nada que devolverle. %s te suelta un puñetazo." % npc.display_name, GameState.C_BAD)
			gs.change_dignity(-3)
		"parar":
			player.stop()
			_pending = null
			_grabbed = GRAB_SECONDS
			npc.say("¡Te tengo, ladrón!", 2.0)
			gs.heat = minf(100.0, gs.heat + 10.0)
			gs.log_msg("%s te agarra del brazo. Te sueltas como puedes." % npc.display_name, GameState.C_BAD)


func police_near(cell: Vector2i, radius: int) -> int:
	var n := 0
	for npc in npcs:
		if npc.kind == "policia" and npc.distance_to_cell(cell) <= radius:
			n += 1
	return n


func remove_random_npc(kind: String) -> void:
	var of_kind := npcs.filter(func(n): return n.kind == kind)
	if of_kind.is_empty():
		return
	var npc: Npc = of_kind.pick_random()
	npcs.erase(npc)
	npc.queue_free()


## Quita un bot de la calle al cabo de unos segundos (se va con alguien, se mete en un portal...).
func remove_npc_later(npc: Npc, seconds: float) -> void:
	npcs.erase(npc)
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if is_instance_valid(npc):
			npc.queue_free())


## Conversación libre (IA) con un bot que tiene ficha.
func open_chat(npc: Npc) -> void:
	npc.stop()
	hud.open_chat(npc, conversation)


func highlight_poi(poi: Dictionary) -> void:
	for m in markers:
		if m.poi == poi:
			m.highlighted = true
			get_tree().create_timer(12.0, false).timeout.connect(func(): m.highlighted = false)


## Repone los bots que faltan y retira, lejos de tu vista, los que ya no están en su horario.
func _respawn() -> void:
	var h := GameState.hour()
	for npc in npcs.duplicate():
		if not Npc.active_at(npc.kind, h) and npc.distance_to_cell(player.cell) > DESPAWN_DISTANCE and npc.mode == "":
			npcs.erase(npc)
			npc.queue_free()
	for kind in _npc_targets:
		if not Npc.active_at(kind, h):
			continue
		var missing: int = _npc_targets[kind] - npcs.filter(func(n): return n.kind == kind).size()
		for i in mini(missing, ceili(_npc_targets[kind] / 4.0)):
			_spawn_npc(kind)


## Eventos del barrio: peleas entre yonkis, yonkis que vienen a pedirte y carteristas trabajando.
func _random_event() -> void:
	if randf() < 0.2 and pickpocket_event():
		return
	var yonkis := npcs.filter(func(n): return n.kind == "yonki")
	if yonkis.is_empty():
		return
	var a: Npc = yonkis.pick_random()
	if randf() < 0.5 and a.distance_to_cell(player.cell) < 60:
		a.walk_to(player.cell)
		a.say("¡Eh, primo! ¿Tienes un euro?", 4.0)
		return
	var closest: Npc = null
	for b in yonkis:
		if b != a and b.distance_to_cell(a.cell) < 30:
			closest = b
			break
	if closest:
		closest.walk_to(a.cell)
		a.say(["¡Me has robado la base!", "¡Esa esquina es mía!", "¡Devuélveme el mechero!"].pick_random(), 4.0)
		closest.say("¡Ven aquí si tienes huevos!", 4.0)
		if a.distance_to_cell(player.cell) < 40:
			GameState.log_msg("Pelea de yonkis cerca de %s." % city.street_name_near(a.cell))
		for npc in npcs:
			if npc.kind == "policia" and npc.distance_to_cell(a.cell) < 80:
				npc.walk_to(a.cell)
				break


## Un carterista le vacía el bolsillo a un turista cercano (que luego ya no tiene nada que robarle).
## Devuelve false si no hay a quién.
func pickpocket_event() -> bool:
	for thief in npcs.filter(func(n): return n.kind == "carterista").duplicate():
		for victim in npcs:
			if victim.kind in ["turista", "fiestero"] and not victim.robbed and victim.distance_to_cell(thief.cell) < 60:
				victim.robbed = true
				thief.money += victim.money
				victim.money = 0
				thief.walk_to(victim.cell)
				if victim.distance_to_cell(player.cell) < 20:
					victim.say(["My wallet!", "¿Y mi móvil?", "Where is my bag?!"].pick_random(), 4.0)
					GameState.log_msg("A un guiri le acaban de vaciar el bolsillo cerca de %s. No has sido tú." % city.street_name_near(victim.cell))
				return true
	return false


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_game_over(reason: String) -> void:
	Engine.time_scale = 1.0
	player.stop()
	hud.close_menu()
	hud.show_game_over(reason)
