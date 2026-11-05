class_name World
extends Node3D
## Escena de juego: el barrio en 3D, el jugador, los bots y el HUD.
## Gestiona el paso del tiempo, la cámara isométrica, la entrada y los eventos del barrio.

## Bots por tipo en un barrio "mediano"; se multiplican por el índice de criminalidad.
## Solo salen a la calle en sus horas (Npc.KINDS[...]["hours"]).
const BASE_NPCS := {
	"turista": [55, ""],
	"vecino": [35, ""],
	"urbano": [4, "total"],
	"mosso": [3, "total"],
	"urbano_secreta": [2, ""],
	"mosso_secreta": [2, "vulnerables"],
	"yonki": [10, "vulnerables"],
	"camello": [4, "vulnerables"],
	"mantero": [3, "venta_ambulante"],
	"educador": [4, ""],
	"fiestero": [8, "locales"],
	"latero": [3, "venta_ambulante"],
	"trilero": [2, ""],
	"carterista": [4, ""],
	"chaval": [4, ""],
	"nino": [14, ""],
	"anciano": [14, ""],
	"mensajero": [10, ""],
	"pudiente": [12, ""],
	"musico": [5, ""],
	"estatua": [4, ""],
	"mendigo": [8, "vulnerables"],
	"skater": [6, ""],
	"captador": [4, ""],
	"rosero": [4, "locales"],
	"chatarrero": [4, ""],
	"trabajadora_sexual": [5, ""],
	"guia": [2, ""],
	"caricaturista": [3, ""],
	"punki": [3, ""],
}
## Calles de cada zona de Npc.KINDS (nombres de OpenStreetMap).
const ZONE_STREETS := {
	"rambla": ["La Rambla"],
	"rambla_raval": ["Rambla del Raval", "Carrer de Sant Pau", "Carrer d'en Robador"],
	"robadors": ["Carrer d'en Robador", "Carrer de Sant Ramon", "Carrer de Sant Pau"],
	# los puntos donde se toca: la Rambla y las plazas del Pi (más los edificios de abajo)
	"musica": ["La Rambla", "Plaça del Pi", "Plaça de Sant Josep Oriol", "Pla de la Boqueria"],
	"pintores": ["Plaça de Sant Josep Oriol", "Plaça del Pi", "La Rambla"],
}
## Zonas junto a un edificio con rótulo (CityMap.landmark_cell), a menos de LANDMARK_RADIUS
## casillas: la plaça dels Àngels del MACBA, la puerta del Liceu, el CCCB.
const ZONE_LANDMARKS := {
	"macba": ["MACBA"],
	"musica": ["MACBA", "Liceu", "CCCB"],
}
const LANDMARK_RADIUS := 10
## Las estatuas humanas, en el tramo de abajo de la Rambla (desde 2019): esta parte de sus
## casillas, las más cercanas a Colom.
const STATUE_STRETCH := 0.3
const DESPAWN_DISTANCE := 30  ## casillas: fuera de su horario se van cuando no los ves
const PLAYER_SPEED := 18.0  ## metros por segundo
const RUN_FACTOR := 1.7  ## multiplicador de velocidad con Shift
const INTERACT_RANGE := 4  ## casillas
const CAMERA_PITCH := -40.0  ## grados; vista isométrica algo más cenital que la clásica
const CAMERA_DISTANCE := 160.0
const ZOOM_RANGE := Vector2(10.0, 110.0)  ## tamaño ortográfico (metros de alto en pantalla)
const PICK_RADIUS_PX := 28.0
const WITNESS_KINDS := ["vecino", "turista", "anciano", "nino", "pudiente"]  ## gente que se escandaliza si te ve consumiendo
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
const ON_SCREEN_MARGIN_PX := 200.0  ## los bots a menos de esto del borde cuentan como en pantalla
const GRAB_SECONDS := 1.5  ## lo que te retiene un transeúnte que te agarra

var city: CityMap
var player: Actor
var camera: Camera3D
var hud: Hud
var interactions: Interactions
var errands: Errands  ## Encargos con plazo y libreta
var misiones: Misiones  ## Misiones de los personajes del editor
var relaciones: Relaciones  ## Lo que le haces a un personaje lo saben los suyos
var proposito: Proposito  ## Lo que quiere conseguir el yonki de ahora
var sucesos: Sucesos  ## Lo que le pasa al barrio unos días (fentanilo, redadas, fiesta, obras)
var vinculos: Vinculos  ## Amistades y enemistades entre los bots
var street_items: StreetItems  ## Objetos tirados por la calle
var trade: Trade  ## Trapicheo: revender y cambiar cosas con otros yonkis
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
var _personajes: Array[Dictionary] = []  ## personajes del editor (ver Personajes)
var censo: Censo  ## todos los bots del barrio, con cuerpo o latentes (ver Censo)
var _street_real := ""  ## la calle en la que estás de verdad
var _street_shown := ""  ## la que dice la placa (ido, a veces otra)
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
var _autoguardado_pendiente := false


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
	misiones = Misiones.new(self)
	relaciones = Relaciones.new(self)
	proposito = Proposito.new(self)
	sucesos = Sucesos.new(self)
	vinculos = Vinculos.new(self)
	street_items = StreetItems.new(self)
	trade = Trade.new(self)
	street_items.populate()
	conversation = Conversation.new(self)
	add_child(conversation)
	_place_markers()
	# los altares de los yonkis de antes que murieron (una partida cargada)
	for i in GameState.historia.size():
		if Defs.DESTINOS.get(GameState.historia[i]["destino"], {}).get("queda", "") == "altar":
			_altar(i)
	_personajes = Personajes.cargar_todos()
	if Partida.pendiente.is_empty():
		misiones.preparar()  # (una partida cargada ya trae lo que debes)
	Npc.reservados.clear()
	for d in _personajes:
		Npc.reservados[d["tipo"] + "|" + d["nombre"]] = true
	# el censo: todos los del barrio en el registro; cuerpo solo los que andan cerca
	censo = Censo.new(self)
	for kind in BASE_NPCS:
		_npc_targets[kind] = _target_count(kind)
		if Npc.active_at(kind, GameState.hour()):
			for i in _npc_targets[kind]:
				censo.nuevo(kind)
	var probar := _probar_id()
	for d in _personajes:
		if Npc.KINDS.has(d["tipo"]) and d.get("amo", "") == "":
			var r := censo.de_personaje(d)
			if d["id"] == probar:
				censo.despertar(r, player.cell).say("¡Aquí estoy!", 4.0)
	# los perros del editor van con su dueño (sin dueño en el censo, solos)
	for d in _personajes:
		if Npc.KINDS.has(d["tipo"]) and d.get("amo", "") != "" and not censo.con_amo(d):
			censo.de_personaje(d)
	censo.repasar(0, 0, true)

	hud = Hud.new()
	add_child(hud)
	hud.menu_closed.connect(func(): get_tree().paused = false)
	hud.restart_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hud.relevo_requested.connect(func(id: String):
		get_tree().paused = false
		relevo(id))
	hud.use_item_requested.connect(use_item)
	hud.find_place_requested.connect(highlight_poi)
	GameState.game_over.connect(_on_game_over)
	GameState.relocated.connect(_on_relocated)
	GameState.new_day.connect(proposito.nuevo_dia)
	GameState.new_day.connect(sucesos.nuevo_dia)
	GameState.new_day.connect(Fama.nuevo_dia)
	GameState.new_day.connect(_autoguardar)
	GameState.new_day.connect(_contagio_diario)
	hud.save_requested.connect(guardar_partida)

	if not Partida.pendiente.is_empty():
		Partida.aplicar_mundo(self)
		sucesos.reaplicar()
		GameState.log_msg("Partida cargada: día %d, %s. Sigues donde lo dejaste." % [GameState.day, Partida.hora()])
	else:
		_intro()


## Guarda la partida (desde la pausa) y lo dice en el registro.
func guardar_partida() -> void:
	var err := Partida.guardar(self)
	if err == OK:
		GameState.log_msg("Partida guardada (día %d, %s)." % [GameState.day, Partida.hora()], GameState.C_GOOD)
	else:
		GameState.log_msg("No se ha podido guardar la partida (%s)." % error_string(err), GameState.C_BAD)


## Guardado automático al dormir y al empezar un día: al final del frame, una sola vez aunque
## pasen las dos cosas a la vez (dormir hasta el día siguiente).
func _autoguardar() -> void:
	if not Partida.automatico or not GameState.alive or _autoguardado_pendiente:
		return
	_autoguardado_pendiente = true
	(func():
		_autoguardado_pendiente = false
		if GameState.alive and is_inside_tree():
			Partida.guardar(self)).call_deferred()


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
	_anunciar_proposito()


## Lo que quiere conseguir el yonki de ahora (Proposito), en el registro.
func _anunciar_proposito() -> void:
	var d := Proposito.def()
	if not d.is_empty():
		GameState.log_msg("Lo que de verdad quieres: %s. Empieza por %s (lo tienes en la libreta, L)." % [
			d["titulo"].to_lower(), d["pasos"][0]["texto"]], Color("f0c060"))


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## Cuántos de este tipo hay en el censo: la base, por el índice de criminalidad que toca y
## por lo que se multiplica la gente (Defs.CROWD).
func _target_count(kind: String) -> int:
	var base: float = BASE_NPCS[kind][0] * Defs.CROWD.get(kind, 1.0)
	var category: String = BASE_NPCS[kind][1]
	if category != "":
		base *= city.crime_factor(category)
	if kind == "yonki":
		base *= 1.0 + Defs.RELEVO_YONKIS * GameState.historia.size()  # cada vez hay más
	# los sucesos del barrio (más policía en las redadas, más gente en la Fiesta Mayor...)
	for id in GameState.sucesos:
		base *= Defs.SUCESOS[id].get("gente", {}).get(kind, 1.0)
	return roundi(base)


## Vuelve a calcular cuántos tiene que haber de cada tipo (al empezar o acabar un suceso): los
## que faltan los repone el repaso de cada hora; los que sobran se van al acabar su horario.
func recalcular_gente() -> void:
	for kind in _npc_targets:
		_npc_targets[kind] = _target_count(kind)


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


## Un bot nuevo del tipo `kind`, en el censo y ya con cuerpo, junto a su casa.
func _spawn_npc(kind: String) -> Npc:
	var r := censo.nuevo(kind)
	return censo.despertar(r, city.random_walkable_near(r["home"], 8))


## Uno que va detrás de `amo` (su perro, un turista del grupo del guía); se va cuando se va él.
func _spawn_follower(kind: String, amo: Npc, personaje := {}) -> void:
	var f := Npc.new()
	if personaje.is_empty():
		f.init_kind(kind)
	else:
		f.init_personaje(personaje)  # un perro del editor que va con su dueño (Personajes «amo»)
	f.player = player
	f.world = self
	f.amo = amo
	f.home = amo.cell
	city.entities.add_child(f)
	f.setup(city, city.random_walkable_near(amo.cell, 2))
	f.caught_player.connect(_on_caught)
	npcs.append(f)


## Dónde pasa la noche `npc` (KINDS[...]["bed"]): el lugar de ese tipo más cercano a su casa o,
## si no hay ninguno cerca, un portal escondido de los alrededores.
func _bed_for(npc: Npc) -> Vector2i:
	var best := Vector2i(-1, -1)
	for p in city.pois_of_kind(Npc.KINDS[npc.kind]["bed"]):
		var c := city.nearest_walkable(Vector2i(p["x"], p["y"]))
		if npc.distance_to_cell(c) < 60 and (best.x < 0 or npc.distance_to_cell(c) < npc.distance_to_cell(best)):
			best = c
	if best.x >= 0 and randf() < 0.6:
		return best
	for i in 30:
		var c := city.random_walkable_near(npc.home, 25)
		if hidden_spot(c):
			return c
	return best if best.x >= 0 else city.random_walkable_near(npc.home, 10)


## Si `cell` es un rincón escondido: poca calle alrededor (un callejón, un portal al fondo de
## un pasaje). Ahí la Urbana no te ve dormir tan fácilmente.
func hidden_spot(cell: Vector2i) -> bool:
	var open := 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if city.is_walkable(cell + Vector2i(dx, dy)):
				open += 1
	return open < Defs.HIDDEN_OPEN_CELLS


## Dónde vive un personaje del editor: el lugar de su rutina a esta hora, su casa, o una
## casilla de su zona.
func _personaje_home(d: Dictionary, zona: Array) -> Vector2i:
	var l := Personajes.lugar_a(d, GameState.hour())
	if not l.is_empty():
		return city.nearest_walkable(Vector2i(l["x"], l["y"]))
	var casa: Array = d["zona"]["casa"]
	if casa.size() == 2:
		return city.nearest_walkable(Vector2i(casa[0], casa[1]))
	if not zona.is_empty():
		return zona.pick_random()
	if d["zona"]["tipo"] in ["barrio", "poligono"]:
		return city.random_walkable()
	return _zone_cell(d["zona"]["tipo"])


## Casillas transitables dentro de un polígono ([[x, y], ...] en casillas).
func _cells_in_polygon(poly: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if poly.size() < 3:
		return out
	var r := Rect2i(Vector2i(poly[0][0], poly[0][1]), Vector2i.ZERO)
	for v in poly:
		r = r.expand(Vector2i(v[0], v[1]))
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			if city.is_walkable(Vector2i(x, y)) and Personajes.dentro(Vector2(x, y), poly):
				out.append(Vector2i(x, y))
	return out


## El id del personaje que pide probar el editor (`-- --probar=<id>`), o "".
func _probar_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probar="):
			return a.trim_prefix("--probar=")
	return ""


## Casilla al azar de una zona: sus calles, o cerca de los bares para la noche.
func _zone_cell(zone: String) -> Vector2i:
	if zone == "plazas":
		return _random_cell_of(CityMap.Cell.PLAZA)
	if zone == "estatuas":
		var rambla := city.street_cells("La Rambla")
		var colom := city.landmark_cell("Colom")
		if not rambla.is_empty() and colom.x >= 0:
			rambla.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(colom) < b.distance_squared_to(colom))
			return rambla[randi() % maxi(1, int(rambla.size() * STATUE_STRETCH))]
	if zone == "bares":
		var bars := city.pois_of_kind("bar")
		if not bars.is_empty():
			var b: Dictionary = bars.pick_random()
			return city.random_walkable_near(Vector2i(b["x"], b["y"]), 6)
	var cells: Array[Vector2i] = []
	for street in ZONE_STREETS.get(zone, []):
		cells.append_array(city.street_cells(street))
	var spots: Array[Vector2i] = []
	for text in ZONE_LANDMARKS.get(zone, []):
		var c := city.landmark_cell(text)
		if c.x >= 0:
			spots.append(c)
	# un edificio cuenta tanto como una calle entera
	var streets: int = ZONE_STREETS.get(zone, []).size()
	if not spots.is_empty() and (cells.is_empty() or randf() < float(spots.size()) / (spots.size() + streets)):
		return city.random_walkable_near(spots.pick_random(), LANDMARK_RADIUS)
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
		"mendigo":
			# pide en la puerta de una iglesia o de un súper
			var spots := city.pois_of_kind("iglesia") + city.pois_of_kind("super")
			if spots.is_empty():
				home = city.random_walkable()
			else:
				var p: Dictionary = spots.pick_random()
				home = city.nearest_walkable(Vector2i(p["x"], p["y"]))
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
		misiones.update()
		proposito.update()
		vinculos.tick(delta)
		street_items.update()
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
		_update_street()
		_check_bike_owners()
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = randf_range(15.0, 35.0) / city.crime_factor("peleas")
		_random_event()
	censo.tick(delta)
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
	# correr gasta vitalidad; agotado, no se corre hasta recuperarla (Defs.VITALITY_*). En bici
	# se va más rápido sin gastarla (y sin correr: no se pedalea más fuerte con Shift)
	var gs := GameState
	if gs.riding and not gs.has_item("bici"):
		toggle_bike()  # la has vendido o te la han quitado
	var moving := v != Vector2.ZERO or player.is_moving()
	var wants_run := Input.is_key_pressed(KEY_SHIFT) and moving and not gs.exhausted and not gs.riding
	player.run_factor = Defs.BIKE_SPEED if gs.riding else (RUN_FACTOR if wants_run else 1.0)
	if wants_run:
		gs.change_vitality(-Defs.VITALITY_RUN_COST * delta)
	elif moving:
		gs.change_vitality(Defs.VITALITY_REGEN_WALK * delta)
	else:
		gs.change_vitality(Defs.VITALITY_REGEN_STILL * delta)
	if gs.exhausted and Input.is_key_pressed(KEY_SHIFT) and moving and randf() < delta * 0.4:
		player.say(["*jadea*", "No puedo más...", "Un momento, un momento"].pick_random(), 1.5)
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
	var screen := get_viewport().get_visible_rect().grow(ON_SCREEN_MARGIN_PX)
	for npc in npcs:
		npc.on_screen = screen.has_point(camera.unproject_position(npc.global_position))
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
		npc.cone_visible = near and (_all_cones or npc.looks_police() or npc.mode != "" or npc.alert > 0.05)
		if color == C_HUNTER:
			npc.set_silhouette(Color(C_HUNTER, 0.75))
		elif mark != "":
			npc.set_silhouette(Color(color, 0.75))
		elif npc.looks_police():
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
			text = Interactions.poi_title(p, ": ")
		else:
			var item := street_items.item_at(m)
			if item:
				text = street_items.label(item)
	hud.set_hover(text, m)


## Selección por pantalla: el bot cuyo cuerpo proyectado queda más cerca del ratón.
func _npc_at(screen_pos: Vector2) -> Npc:
	var best: Npc = null
	var best_d := PICK_RADIUS_PX
	for npc in npcs:
		if not npc.on_screen:
			continue
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
			KEY_B:
				toggle_bike()
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
	var item := street_items.item_at(screen_pos)
	if item:
		_approach(item)
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
	if target is Npc or target is StreetItem:
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
	if target is StreetItem:
		street_items.pick_up(target)
		return
	var title := ""
	var actions: Array
	if target is Npc:
		var npc := target as Npc
		npc.stop()
		if not npc.is_police():
			npc.known = true  # las secretas no se descubren porque les hables
		title = npc.label()
		actions = interactions.for_npc(npc)
	else:
		var p: Dictionary = (target as PoiMarker).poi
		title = Interactions.poi_title(p)
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
	if id == "bici":
		toggle_bike()
		return
	if id == "cartera":
		if street_items.take_fake("cartera", "La abres: es %s. Ni una moneda."):
			return
		GameState.remove_item("cartera")
		var cash := Defs.WALLET_FAT if randf() < Defs.WALLET_FAT_CHANCE else Defs.WALLET_CASH
		var n := randi_range(cash.x, cash.y)
		GameState.add_money(n)
		if n == 0:
			GameState.log_msg("La cartera solo tiene tarjetas y un abono de metro. Las fotos de sus hijos las tiras a la papelera.", GameState.C_BAD)
		else:
			GameState.log_msg("La cartera tenía %d €. Las fotos de sus hijos las tiras a la papelera." % n, GameState.C_GOOD)
		GameState.change_dignity(-1)
		return
	if Defs.SUBSTANCES.has(id):
		var seen := watching(_police_kinds())
		var urbana := seen.filter(func(n: Npc): return n.corps() == "urbana" and not n.vista_gorda())
		if id == "litrona" and not urbana.is_empty():
			# beber en la calle es cosa de la ordenanza: la Urbana multa
			var agent: Npc = urbana[0]
			agent.reveal()
			agent.say("Aquí no se puede beber. Documentación.", 3.0)
			GameState.fine(Defs.FINE_DRINKING, "beber en la calle")
		elif not seen.is_empty():
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
	var hidden := hidden_spot(player.cell)
	if hidden:
		GameState.log_msg("Te metes en un rincón donde no se te ve desde la calle.")
	sleep(6 * 60, 0.25 if hidden else 0.35, 10.0, 0.5, "calle")
	GameState.change_dignity(-5, "Dormir en el suelo de %s" % city.street_name_near(player.cell))
	GameState.milestone("primera_calle")


## Duerme `minutes` minutos. `robbery_risk` es la probabilidad de que te roben si llevas dinero;
## `quality` (0..1), lo que se descansa en ese sitio (ver GameState.rest). `place` = "calle",
## "banco", "cajero" (a la vista: la Urbana te puede despertar y echar, ver urbana_wakes) o ""
## (bajo techo).
func sleep(minutes: float, robbery_risk: float, heal: float, quality: float, place := "") -> void:
	player.stop()
	if place != "" and urbana_wakes(place):
		var slept := minutes * randf_range(0.2, 0.6)
		GameState.rest(slept, quality, robbery_risk * 0.5, heal * 0.5)
		var agent := _nearest_of(["urbano"], player.cell)
		var who := agent.display_name if agent else "Un agente de la Guàrdia Urbana"
		if agent:
			agent.say("Aquí no se puede dormir. Recoja y circule.", 4.0)
		GameState.log_msg("%s te despierta con la linterna a las %02d:00: «Aquí no se puede dormir. Recoja y circule.» Te vas con las mantas a cuestas." % [who, GameState.hour()], GameState.C_BAD)
		GameState.change_dignity(-3, "Que te echen de donde dormías")
		GameState.milestone("desalojo")
		player.setup(city, city.random_walkable_near(player.cell, 15))
		_camera_focus = player.position
		_autoguardar()
		return
	GameState.rest(minutes, quality, robbery_risk, heal)
	_autoguardar()


## Si, durmiendo a la vista en `place`, la Guàrdia Urbana te despierta y te echa: casi seguro
## si un agente ya te ve, y si no según el sitio (Defs.SLEEP_WAKE), los agentes que patrullan
## cerca y si es un rincón escondido.
func urbana_wakes(place: String) -> bool:
	# los que te hacen la vista gorda (un favor de misión) no te despiertan
	var urbanos := npcs.filter(func(n: Npc): return n.corps() == "urbana" and not n.vista_gorda())
	if urbanos.any(func(n: Npc): return n.can_see(player)):
		return randf() < Defs.SLEEP_WAKE_SEEN
	var p: float = Defs.SLEEP_WAKE.get(place, 0.0)
	p += Defs.SLEEP_WAKE_PER_AGENT * urbanos.filter(func(n: Npc): return n.distance_to_cell(player.cell) <= Defs.SLEEP_PATROL_CELLS).size()
	if place == "calle" and hidden_spot(player.cell):
		p *= Defs.SLEEP_HIDDEN_FACTOR
	return randf() < p


## El bot de los tipos `kinds` más cercano a `cell`; null si no hay ninguno.
func _nearest_of(kinds: Array, cell: Vector2i) -> Npc:
	var best: Npc = null
	for n in npcs:
		if n.kind in kinds and (best == null or n.distance_to_cell(cell) < best.distance_to_cell(cell)):
			best = n
	return best


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


## Agentes que te están viendo ahora (su cono te alcanza y no hay edificios en medio), de uniforme
## o de paisano; con `corps`, solo los de ese cuerpo ("urbana" o "mossos").
func police_watching(corps := "") -> int:
	return watching(_police_kinds(corps)).size()


## Tipos de bot de la policía, de los dos cuerpos o solo de `corps`.
static func _police_kinds(corps := "") -> Array:
	return Npc.POLICE.keys().filter(func(k): return corps == "" or Npc.POLICE[k] == corps)


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
## si no, quedas fichado. En cualquier caso, la policía que te vea irá a por ti. `crime` (clave de
## Defs.CRIME_CORPS) decide a qué cuerpo llega la llamada y quién te persigue si te fichan.
func scandal(shouter: Npc, text: String, crime := "hurto") -> void:
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
		if npc.is_police():
			npc.investigate(player.cell)  # en flagrante interviene cualquiera
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
			if npc.corps() in Defs.CRIME_CORPS[crime] and npc.distance_to_cell(at) <= Defs.SCANDAL_CALL and (best == null or npc.distance_to_cell(at) < best.distance_to_cell(at)):
				best = npc
		if best:
			best.investigate(player.cell)
			police = true
	var where := city.street_name_near(at)
	var msg := "%s Se monta un escándalo en %s." % [text if shouter == null else "«%s»" % text, where]
	if stoppers > 0:
		msg += " %s intenta pararte." % ("Alguien" if stoppers == 1 else "Un par de valientes")
	if police:
		var corps: Array = Defs.CRIME_CORPS[crime]
		msg += " Viene la Urbana." if corps == ["urbana"] else (" Vienen los Mossos." if corps == ["mossos"] else " Viene la policía.")
	gs.log_msg(msg, GameState.C_BAD)
	if not police:
		gs.mark_wanted("te han visto en %s y han dado tu descripción" % where, crime)


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
			police_caught(npc)
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
				_beating(npc, func():
					gs.change_health(-15, "Te mataron a palos por una deuda con un camello")
					gs.change_dignity(-3)
					gs.log_msg("No llevas nada. %s te da una paliza para que no se te olvide." % npc.display_name, GameState.C_BAD)
					gs.milestone("pelea_perdida"))
			npc.debt_due = gs.now() + Defs.DEBT_GRACE_HOURS * 60.0
		"venganza":
			npc.memory.erase("robado")
			npc.memory.erase("timado")
			npc.memory.erase("oido_mal")
			npc.remove_meta("venganza")
			var loot := ""
			if npc.has_meta("dueno_bici") and gs.has_item("bici"):
				npc.remove_meta("dueno_bici")
				gs.remove_item("bici")
				npc.say("¡Mi bici! ¡Ladrón!", 3.0)
				gs.log_msg("%s te alcanza y se lleva su bici. (−dignidad)" % npc.display_name, GameState.C_BAD)
				gs.change_dignity(-4)
				return
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
				# no llevas nada que devolverle: se cobra a golpes (pelea, minijuego)
				npc.say("Asshole! ¡Te vas a enterar!", 3.0)
				_beating(npc, func():
					gs.change_health(-8, "Te mató a golpes alguien a quien habías robado")
					gs.log_msg("No llevas nada que devolverle. %s te deja tirado a puñetazos." % npc.display_name, GameState.C_BAD))
			gs.change_dignity(-3)
		"territorio":
			npc.memory.erase("pisado")
			var taken := gs.inventory.keys().filter(func(id): return id in Defs.DEALER_STOCK)
			if not taken.is_empty():
				for id in taken:
					gs.remove_item(id, gs.inventory[id])
				npc.say("Esto se queda aquí. Y tú, a otra esquina.", 3.0)
				gs.log_msg("%s te alcanza y se queda con toda tu mercancía." % npc.display_name, GameState.C_BAD)
			elif gs.money > 0:
				var n := mini(gs.money, 30)
				gs.add_money(-n)
				npc.say("El impuesto de la esquina.", 3.0)
				gs.log_msg("%s te alcanza y se cobra %d € por vender en su esquina." % [npc.display_name, n], GameState.C_BAD)
			else:
				npc.say("Que no te vuelva a ver por aquí.", 3.0)
				_beating(npc, func():
					gs.change_health(-12, "Te mataron a palos por vender en la esquina de otro")
					gs.log_msg("%s te alcanza y te da una paliza por vender en su esquina." % npc.display_name, GameState.C_BAD))
			gs.change_dignity(-3)
		"parar":
			player.stop()
			_pending = null
			_grabbed = GRAB_SECONDS
			npc.say("¡Te tengo, ladrón!", 2.0)
			gs.heat = minf(100.0, gs.heat + 10.0)
			gs.log_msg("%s te agarra del brazo. Te sueltas como puedes." % npc.display_name, GameState.C_BAD)
		"bronca":
			_bronca(npc)
		"tiron":
			_tiron(npc)


## Alguien que va acelerado (Consumo) te ha alcanzado buscando bronca: pelea (minijuego Fight)
## con la probabilidad de una pelea normal. Si ganas, se le pasa; si no, te deja tocado.
func _bronca(npc: Npc) -> void:
	var gs := GameState
	gs.change_vitality(-Defs.VITALITY_FIGHT)
	play_minigame(Fight.new(npc), interactions._fight_chance(npc), func(result: String, _stats: Dictionary):
		if result == "ok":
			npc.say("Vale, vale... Ya está, tío.", 3.0)
			gs.change_health(-randf_range(2, 6), "Una bronca de más")
			gs.log_msg("Te quitas de encima a %s, que iba hasta arriba." % npc.display_name, GameState.C_GOOD)
		else:
			gs.change_health(-12, "Te mató a golpes alguien que iba hasta arriba")
			gs.change_dignity(-3)
			gs.log_msg("%s iba hasta arriba y te ha tocado a ti. Te deja en el suelo." % npc.display_name, GameState.C_BAD)
			gs.milestone("pelea_perdida"))


## Alguien con mono y sin nada con qué pagar (Consumo) te ha alcanzado: te arranca una dosis de
## lo suyo (o de lo que lleves) o unos euros, y se lo mete en cuanto puede.
func _tiron(npc: Npc) -> void:
	var gs := GameState
	var c: Dictionary = npc.consumo
	var take := ""
	if not c.is_empty() and gs.has_item(c["id"]):
		take = c["id"]
	else:
		for id in gs.inventory.keys():
			if Defs.SUBSTANCES.has(id):
				take = id
				break
	if take != "":
		gs.remove_item(take)
		if not c.is_empty() and take == c["id"]:
			c["dosis"] += 1
		npc.say("Lo siento, tío... lo necesito.", 3.0)
		gs.log_msg("%s te da el tirón y se lleva tu %s." % [npc.display_name, Defs.item_name(take).to_lower()], GameState.C_BAD)
	elif gs.money > 0:
		var n := mini(gs.money, Defs.NPC_TIRON_MAX)
		gs.add_money(-n)
		npc.money += n
		npc.say("Lo siento... lo necesito.", 3.0)
		gs.log_msg("%s te mete la mano en el bolsillo y sale corriendo con %d €." % [npc.display_name, n], GameState.C_BAD)
	else:
		npc.say("¿No llevas nada? Mierda...", 3.0)
		gs.log_msg("%s te registra a empujones. No llevas nada." % npc.display_name, GameState.C_BAD)
	gs.change_dignity(-2)


## Te van a dar una paliza (`npc` te ha alcanzado y no llevas nada): se pelea (minijuego
## Fight), cuesta arriba. Si ganas, te lo quitas de encima con algún golpe; si no, `lose`.
func _beating(npc: Npc, lose: Callable) -> void:
	var chance := Defs.BEATING_FIGHT_CHANCE - (npc.stat("fuerza") - 5) * Defs.STAT_FIGHT
	chance -= (1.0 - GameState.vitality / 100.0) * Defs.VITALITY_FIGHT_CHANCE
	GameState.change_vitality(-Defs.VITALITY_FIGHT)
	play_minigame(Fight.new(npc), chance, func(result: String, _stats: Dictionary):
		if result != "ok":
			lose.call()
			return
		var gs := GameState
		gs.change_health(-5, "Quitarte de encima a %s" % npc.display_name)
		npc.say("Esto no se acaba aquí.", 3.0)
		gs.log_msg("Te quitas de encima a %s a golpes y sales corriendo." % npc.display_name, GameState.C_GOOD))


## Te ha alcanzado un agente. Los Mossos te detienen y te llevan a comisaría. La Urbana, si te
## buscaban por un delito, te retiene hasta que llegan los Mossos; si solo era por la ordenanza
## o porque llamabas la atención, te identifica, te requisa la bebida y te multa.
func police_caught(agent: Npc) -> void:
	var gs := GameState
	agent.reveal()
	if agent.corps() == "mossos" or (gs.is_wanted() and gs.wanted_crime != "civismo"):
		if agent.corps() == "urbana":
			gs.log_msg("%s te pone contra la pared y llama a los Mossos. Te llevan a comisaría." % agent.display_name, GameState.C_BAD)
		arrest_player()
		return
	agent.say("Documentación. Y esto se queda aquí.", 3.0)
	if gs.has_item("litrona"):
		gs.remove_item("litrona", gs.inventory["litrona"])
	gs.heat = minf(gs.heat, Defs.CHASE_HEAT - 10.0)
	gs.wanted_until = -1.0
	gs.fine(Defs.FINE_DRINKING, "incumplir la ordenanza de civismo")


## Agentes a menos de `radius` casillas de `cell` (de uniforme o de paisano); con `corps`, solo
## los de ese cuerpo.
func police_near(cell: Vector2i, radius: int, corps := "") -> int:
	var n := 0
	for npc in npcs:
		if npc.is_police() and (corps == "" or npc.corps() == corps) and npc.distance_to_cell(cell) <= radius:
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
	# referencia débil: el temporizador es del árbol y puede saltar con la partida ya cerrada
	var ref: WeakRef = weakref(npc)
	get_tree().create_timer(seconds, false).timeout.connect(func():
		var n = ref.get_ref()
		if n != null:
			n.queue_free())


## Conversación libre (IA) con un bot que tiene ficha.
## Juega `game` (un Minigame) en vez de tirar los dados; `done` recibe el resultado y las
## cuentas del minijuego (result, stats). El barrio se queda en pausa mientras tanto. Sin
## pantalla (tests --headless) se decide al momento con la probabilidad `chance`.
func play_minigame(game: Minigame, chance: float, done: Callable) -> void:
	chance = clampf(chance, 0.0, 1.0)
	game.difficulty = 1.0 - chance
	if DisplayServer.get_name() == "headless":
		var result := game.auto_result(chance)
		var stats := game.stats
		game.free()
		done.call(result, stats)
		return
	game.fx = _fx.get("fx", {})
	_pending = null
	player.stop()
	player.input_dir = Vector3.ZERO
	_input_smooth = Vector3.ZERO
	get_tree().paused = true
	game.finished.connect(func(result: String):
		get_tree().paused = false
		var stats := game.stats
		game.queue_free()
		done.call(result, stats))
	hud.open_minigame(game)


func open_chat(npc: Npc) -> void:
	npc.stop()
	hud.open_chat(npc, conversation)


func highlight_poi(poi: Dictionary) -> void:
	for m in markers:
		if m.poi == poi:
			m.highlighted = true
			var ref: WeakRef = weakref(m)  # (ver remove_npc_later)
			get_tree().create_timer(12.0, false).timeout.connect(func():
				if ref.get_ref() != null:
					ref.get_ref().highlighted = false)


## Retira, lejos de tu vista, a los que ya no están en su horario y repone en el censo los
## que faltan (latentes: se materializan cuando te acercas, ver Censo).
func _respawn() -> void:
	var h := GameState.hour()
	for npc in npcs.duplicate():
		# el perro se va con su dueño, y el grupo con su guía
		# (los perros del editor de personajes van solos, de momento)
		var follows: bool = (npc.kind == "perro" and npc.personaje.is_empty()) or npc.amo != null
		if follows and (npc.amo == null or not is_instance_valid(npc.amo) or npc.amo not in npcs):
			npcs.erase(npc)
			npc.queue_free()
			continue
		if not npc.active(h) and npc.distance_to_cell(player.cell) > DESPAWN_DISTANCE and npc.mode == "":
			var r := censo.de(npc)
			if r.is_empty():
				npcs.erase(npc)
				npc.queue_free()
			else:
				censo.dormir(r)
	_check_redemption()
	# los que no te conocen se van del barrio al acabar su horario; los demás esperan latentes
	censo.olvidar(h)
	for kind in _npc_targets:
		if not Npc.active_at(kind, h):
			continue
		var missing: int = _npc_targets[kind] - censo.registros.filter(func(r): return r["kind"] == kind and r["personaje"].is_empty()).size()
		for i in missing:
			censo.nuevo(kind)


## Yendo en una bici robada, quien te ve puede ser su dueño (Defs.BIKE_OWNER_*): va a por ti
## para recuperarla o busca a un agente. Cada uno se mira una sola vez.
func _check_bike_owners() -> void:
	if not GameState.riding:
		return
	for npc in npcs:
		if not npc.kind in Defs.BIKE_OWNERS or npc.mode != "" or not npc.sees_player or npc.has_meta("visto_en_bici"):
			continue
		npc.set_meta("visto_en_bici", true)
		if randf() >= Defs.BIKE_OWNER_CHANCE:
			continue
		npc.set_meta("dueno_bici", true)
		npc.remember("robado")
		GameState.log_msg("%s se te queda mirando: esa bici es suya." % npc.display_name, GameState.C_BAD)
		npc.react("venganza" if npc.avenger() else "denuncia")
		return


## Subirte o bajarte de la bici que llevas en el inventario (una robada, o la que encuentres).
## En bici vas mucho más rápido y no te cansas, pero se te ve: llamas un poco la atención.
func toggle_bike() -> void:
	var gs := GameState
	if not gs.riding and not gs.has_item("bici"):
		gs.log_msg("No llevas ninguna bici.")
		return
	gs.riding = not gs.riding
	var look: Dictionary = player.look.duplicate()  # (el del perfil es de solo lectura)
	look["bici"] = gs.riding
	player.look = look
	player.rebuild()
	if gs.riding:
		gs.heat = minf(100.0, gs.heat + 3.0)
		gs.log_msg("Te subes a la bici. (B para bajarte)")
	else:
		gs.log_msg("Te bajas de la bici.")


## La placa con el nombre de la calle. Ido, al cambiar de calle a veces dice otra (otra de las
## mentiras de la cabeza, como el reloj y la libreta; Defs.STREET_LIE), hasta la siguiente.
func _update_street() -> void:
	var real := city.street_name_near(player.cell, 12)
	if real != _street_real:
		_street_real = real
		_street_shown = real
		if real != "" and randf() < Defs.STREET_LIE * GameState.befuddlement():
			for i in 20:
				var other: String = city.streets.pick_random()["name"]
				if other != real:
					_street_shown = other
					break
	hud.set_street(_street_shown)


## Redención (perder, el más difícil; Defs.REDEMPTION_*): limpio, con la dignidad muy alta y
## gente en el barrio que te aprecia, alguien a quien ayudaste se enamora de ti. Sales del
## pozo... y el objetivo era caer. true si ha llegado.
func _check_redemption() -> bool:
	var gs := GameState
	if not gs.alive or gs.dignity < Defs.REDEMPTION_DIGNITY or gs.mono > 0.5:
		return false
	for id in gs.subs:
		if gs.subs[id]["addiction"] > Defs.REDEMPTION_ADDICTION:
			return false
	var friends := censo.amigos(Defs.REDEMPTION_HELPS)
	if friends.size() < Defs.REDEMPTION_FRIENDS:
		return false
	var partners := friends.filter(func(r): return r["kind"] in Defs.PARTNER_KINDS)
	if partners.is_empty():
		return false
	var p: Dictionary = partners.pick_random()
	var who: String = p["name"]
	gs.finish("%s te invita a cenar, y luego a quedarte. Encuentras curro descargando en la Boqueria, la metadona baja hasta cero y al año siguiente hay un crío llorando en un piso de la calle de la Cera. Has salido del pozo. Y el objetivo era caer: has perdido." % who,
		"REDENCIÓN", "redimido")
	return true


## Ajuste de cuentas: si hay mucha gente a la que la has liado (Defs.AMBUSH_*), uno de ellos y
## unos cuantos más te cortan el paso. Una pelea muy cuesta arriba: si la pierdes, te dejan
## tirado y sin la mitad del dinero, o muerto. false si no hay bastantes enemigos.
func ambush() -> bool:
	var enemies := censo.rencorosos()
	if enemies.size() < Defs.AMBUSH_ENEMIES or not GameState.alive:
		return false
	var r: Dictionary = enemies.pick_random()
	var npc: Npc = r["npc"]
	if npc == null or not is_instance_valid(npc):
		npc = censo.despertar(r, player.cell)
	var gs := GameState
	gs.log_msg("%s y unos cuantos a los que la has liado te cortan el paso en un callejón." % npc.display_name, gs.C_BAD)
	npc.say("Ahora vas a ver.", 3.0)
	_beating(npc, func():
		gs.change_health(-25, "Te mataron a palos entre varios a los que la habías liado")
		if gs.alive:
			var lost := int(gs.money * 0.5)
			gs.add_money(-lost)
			gs.log_msg("Te dejan en el suelo, sangrando y sin %d €." % lost, gs.C_BAD))
	return true


## Eventos del barrio: peleas entre yonkis, yonkis que vienen a pedirte y carteristas trabajando.
func _random_event() -> void:
	if randf() < Defs.AMBUSH_CHANCE and ambush():
		return
	if randf() < 0.2 and pickpocket_event():
		return
	if randf() < Defs.URBANA_SWEEP + Defs.MOSSOS_SWEEP and police_event():
		return
	if randf() < 0.3 and vinculos.suceso():
		return  # entre bots: el tirón, o alguien que le pasa una dosis a otro (Vinculos)
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
		vinculos.pelea(a, closest)  # quedan enemigos
		# una pelea es cosa de los Mossos
		var mosso := _nearest_of(["mosso"], a.cell)
		if mosso and mosso.distance_to_cell(a.cell) < 80:
			mosso.walk_to(a.cell)


## La policía hace su ronda: la Urbana va a por un mantero, un latero o un trilero (les requisa
## la manta, las latas o la mesa) y los Mossos, a por un camello. El que lo ve venir, recoge y
## se larga. Devuelve false si no hay a quién.
func police_event() -> bool:
	var urbana := randf() < Defs.URBANA_SWEEP / (Defs.URBANA_SWEEP + Defs.MOSSOS_SWEEP)
	var targets := ["mantero", "latero", "trilero"] if urbana else ["camello"]
	var agent_kind := "urbano" if urbana else "mosso"
	for target in npcs.filter(func(n): return n.kind in targets and n.mode == "").duplicate():
		var agent := _nearest_of([agent_kind], target.cell)
		if agent == null or agent.mode != "" or agent.distance_to_cell(target.cell) > 90:
			continue
		agent.walk_to(target.cell)
		target.say(["¡Agua!", "¡Agua, agua!", "¡La Urbana!"].pick_random() if urbana else "¡Los mossos! ¡Abrimos!", 3.0)
		target.walk_to(city.random_walkable_near(target.home, 30))
		if target.distance_to_cell(player.cell) < 40:
			var what: String = {"mantero": "la manta", "latero": "las latas", "trilero": "la mesa del trile"}.get(target.kind, "")
			if urbana:
				GameState.log_msg("La Urbana le requisa %s a %s cerca de %s." % [what, target.display_name, city.street_name_near(target.cell)])
			else:
				GameState.log_msg("Los Mossos paran a %s cerca de %s. Se va sin nada encima." % [target.display_name, city.street_name_near(target.cell)])
		return true
	return false


## Un carterista le vacía el bolsillo a un turista cercano (que luego ya no tiene nada que robarle).
## Si le estaba viendo un agente de paisano de la Urbana, se lo lleva. Devuelve false si no hay a quién.
func pickpocket_event() -> bool:
	for thief in npcs.filter(func(n): return n.kind == "carterista").duplicate():
		var cop := _nearest_of(["urbano_secreta"], thief.cell)
		if cop and cop.can_see(thief) and randf() < Defs.UNDERCOVER_CATCH:
			cop.walk_to(thief.cell)
			cop.say("Guàrdia Urbana. Quieto.", 3.0)
			if thief.distance_to_cell(player.cell) < 30:
				GameState.log_msg("Un «turista» agarra de la muñeca a %s y saca una placa: Urbana de paisano." % thief.display_name)
			remove_npc_later(thief, 3.0)
			return true
		for victim in npcs:
			if victim.kind in ["turista", "fiestero"] and not victim.robbed and victim.distance_to_cell(thief.cell) < 60:
				victim.robbed = true
				thief.money += victim.money
				victim.money = 0
				if randf() < 0.5:  # se ha dado cuenta: no se lo perdona
					Vinculos.cambiar(censo, victim.reg, thief.reg, Defs.VINCULO_ROBO, false)
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
	var gs := GameState
	# el yonki que acaba pasa a la historia de la partida (ver relevo)
	gs.historia.append({"perfil": gs.profile["id"], "nombre": gs.profile["name"],
		"destino": gs.destino, "titulo": gs.ending_title, "motivo": reason, "desde": gs.dia_inicio,
		"dia": gs.day, "caida": roundi(gs.caida), "celda": player.cell, "look": gs.profile["look"].duplicate(),
		"calle": city.street_name_near(player.cell), "rebuscado": false,
		"proposito": Defs.PROPOSITOS.get(gs.profile["id"], {}).get("titulo", ""), "fama": gs.fama.duplicate(true),
		"proposito_estado": gs.proposito.get("estado", "")})
	# la partida guardada queda como terminada: «Continuar» ya no la ofrece (hasta un relevo)
	if Partida.automatico and gs.partida_id != "":
		Partida.guardar(self)
	player.stop()
	hud.close_menu()
	hud.show_game_over(reason)


# ------------------------------------------------------------------- relevo

## Los perfiles con los que se puede tomar el relevo: los que aún no han salido en esta
## partida (ni el de ahora).
static func perfiles_libres() -> Array:
	var usados := GameState.historia.map(func(h): return h["perfil"]) + [GameState.profile.get("id", "")]
	return Defs.PROFILES.filter(func(p): return not p["id"] in usados)


## Sigues con otro yonki (`profile_id`) en este mismo barrio unos días después
## (Defs.RELEVO_DIAS). El de antes se queda según cómo acabó (Defs.DESTINOS: un altar donde
## murió, o en el censo); quien le conocía se acuerda de él, pero a ti no te conoce; y en
## esos días algunos se han enganchado.
func relevo(profile_id: String) -> void:
	var gs := GameState
	var antes: Dictionary = gs.historia.back()
	var dias := randi_range(Defs.RELEVO_DIAS.x, Defs.RELEVO_DIAS.y)
	# todos a dormir: así el censo guarda lo que les ha pasado y nadie sigue persiguiendo al de antes
	for r in censo.registros:
		censo.dormir(r)
	for n in npcs.duplicate():
		npcs.erase(n)
		n.queue_free()
	_olvidan(antes)
	gs.relevo(profile_id, dias)
	gs.minute_of_day = 9.0 * 60.0
	var contagiados := _contagio()
	_queda_en_el_barrio(antes)
	_npc_targets["yonki"] = _target_count("yonki")
	# el nuevo, en un banco
	player.display_name = gs.profile["name"]
	player.look = gs.profile["look"]
	player.rebuild()
	var benches := city.pois_of_kind("banco")
	var start: Vector2i = city.random_walkable()
	if not benches.is_empty():
		var b: Dictionary = benches.pick_random()
		start = Vector2i(b["x"], b["y"])
	player.setup(city, city.nearest_walkable(start))
	_camera_focus = player.position
	misiones.preparar()
	hud.close_game_over()
	censo.repasar(0, 0, true)
	gs.log_msg("Han pasado %d días desde que %s %s." % [dias, antes["nombre"], Defs.DESTINOS[antes["destino"]]["texto"]], gs.C_FALL)
	for r in contagiados.slice(0, 2):
		gs.log_msg("En estos días, %s se ha enganchado: ahora va con los yonkis." % _quien(r), gs.C_INFO)
	gs.log_msg("Ahora eres %s, %s." % [gs.profile["name"], gs.profile["title"].to_lower()])
	gs.log_msg(gs.profile["perk"])
	_anunciar_proposito()
	gs.milestone("relevo")
	gs.changed.emit()
	if Partida.automatico:
		Partida.guardar(self)


## Quien conocía al de antes se acuerda de él (meta «recuerda_a»: su nombre y cómo le
## trataba), pero al nuevo no le conoce: sin memoria, sin deudas, sin rencor.
func _olvidan(antes: Dictionary) -> void:
	var fama: Dictionary = antes.get("fama", {})
	for r in censo.registros:
		var e: Dictionary = r["estado"]
		# quien no le conoció pero vive donde tenía fama, se acuerda de él de oídas (Fama)
		var home: Vector2i = r.get("home", Vector2i.ZERO)
		var oidas := ""
		if Fama.de(home, "mala", fama) >= Defs.FAMA_RECUERDO:
			oidas = "fama_mala"
		elif Fama.de(home, "buena", fama) >= Defs.FAMA_RECUERDO:
			oidas = "fama_buena"
		if e.is_empty():
			if oidas != "":
				r["estado"] = {"metas": {"recuerda_a": {"nombre": antes["nombre"], "trato": oidas, "destino": antes["destino"]}}}
			continue  # nunca ha tenido cuerpo: no conoció a nadie
		var mem: Dictionary = e.get("memory", {})
		if not mem.is_empty() or e.get("known", false):
			var trato := "conocido"
			if Defs.LATENT_GRUDGES.any(func(g): return mem.get(g, 0) > 0):
				trato = "enemigo"
			elif mem.get("ayudado", 0) > 0:
				trato = "amigo"
			if not e.has("metas"):
				e["metas"] = {}
			e["metas"]["recuerda_a"] = {"nombre": antes["nombre"], "trato": trato, "destino": antes["destino"]}
		elif oidas != "":
			if not e.has("metas"):
				e["metas"] = {}
			e["metas"]["recuerda_a"] = {"nombre": antes["nombre"], "trato": oidas, "destino": antes["destino"]}
		e["memory"] = {}
		e["known"] = false
		e["debt"] = 0
		if e.has("metas"):
			e["metas"].erase("enemigo")


## Entre relevo y relevo, algunos de la gente corriente se enganchan (`n`, Defs.RELEVO_CONTAGIOS):
## pasan a ser yonkis con el aspecto de siempre. Solo los latentes (sin cuerpo: no cambia nadie
## delante de ti). Devuelve sus registros.
func _contagio(n := Defs.RELEVO_CONTAGIOS) -> Array:
	var posibles := censo.registros.filter(func(r): return r["kind"] in Defs.RELEVO_CONTAGIABLES 		and r["personaje"].is_empty() and r["npc"] == null)
	posibles.shuffle()
	var out := posibles.slice(0, n)
	for r in out:
		var k: Dictionary = Npc.KINDS[r["kind"]]
		var nombre: String = r["estado"].get("display_name", r["name"])
		var gender: String = r["estado"].get("gender", "f" if nombre in k.get("women", []) else "m")
		var antes_era := Npc.kind_label(r["kind"], gender).to_lower()
		r["antes_era"] = antes_era
		r["kind"] = "yonki"
		var e: Dictionary = r["estado"]
		# el aspecto se queda; la sustancia, el paso y lo que lleva encima son ya de yonki
		for campo in ["consumo", "speed", "wander_radius", "accessory"]:
			e.erase(campo)
		if not e.has("metas"):
			e["metas"] = {}
		e["metas"]["historia_propia"] = "Hasta hace unos días era %s del barrio, de los de toda la vida. Primero fue una vez, para aguantar. Ahora ya no se acuerda de por qué." % antes_era
	return out


## Cada día, a veces, alguien más se engancha (Defs.CONTAGIO_DIARIO), y te llega el rumor.
func _contagio_diario() -> void:
	var gs := GameState
	if not gs.alive or randf() >= Defs.CONTAGIO_DIARIO + Defs.CONTAGIO_DIARIO_RELEVO * gs.historia.size():
		return
	for r in _contagio(1):
		gs.log_msg("Se comenta por el barrio que %s se ha enganchado." % _quien(r), gs.C_INFO)


## «Jaume, vecino del barrio,»: cómo se llama en el registro a uno que se ha enganchado.
func _quien(r: Dictionary) -> String:
	var nombre: String = r["estado"].get("display_name", r["name"])
	return "%s, %s del barrio," % [nombre, r["antes_era"]] if r.has("antes_era") else nombre


## Lo que queda en el barrio del yonki de antes: su altar, o él mismo en el censo.
func _queda_en_el_barrio(antes: Dictionary) -> void:
	var queda: String = Defs.DESTINOS.get(antes["destino"], {}).get("queda", "")
	if queda == "altar":
		_altar(GameState.historia.size() - 1)
	elif queda != "":
		var r := {"kind": queda, "name": antes["nombre"], "personaje": {}, "home": city.nearest_walkable(antes["celda"]),
			"bed": Vector2i(-1, -1), "zona": [], "seguidores": [], "visto": GameState.now(), "npc": null,
			"estado": {"display_name": antes["nombre"], "look": antes["look"].duplicate(),
				"gender": antes["look"].get("gender", "m"), "accessory": "", "known": true, "memory": {},
				"metas": {"historia_propia": Defs.DESTINO_BIO.get(antes["destino"], ""), "relevo": antes["perfil"]}}}
		if queda == "vecino":
			r["estado"]["consumo"] = {}  # limpio
		censo.registros.append(r)


## El altar de la calle donde murió el yonki `i` de la historia: velas, flores y su nombre
## (un lugar más del mapa, kind "altar"). Lo rehace World._ready al cargar una partida.
func _altar(i: int) -> void:
	var h: Dictionary = GameState.historia[i]
	# junto a donde murió, sin pisar otro sitio (si murió en un banco, al lado del banco)
	var ocupadas := {}
	for q in city.pois:
		ocupadas[Vector2i(q["x"], q["y"])] = true
	var cell := city.nearest_walkable(h["celda"])
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var c: Vector2i = cell + d
		if city.is_walkable(c) and not ocupadas.has(c):
			cell = c
			break
	var p := {"kind": "altar", "name": h["nombre"], "x": cell.x, "y": cell.y, "historia": i}
	city.pois.append(p)
	var m := PoiMarker.new()
	m.setup(p, city.cell_to_world(cell))
	city.entities.add_child(m)
	markers.append(m)
