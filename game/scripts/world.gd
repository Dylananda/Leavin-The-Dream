class_name World
extends Node3D
## Escena de juego: el barrio en 3D, el jugador, los bots y el HUD.
## Gestiona el paso del tiempo, la cámara isométrica, la entrada y los eventos del barrio.

## Bots por tipo en un barrio "mediano"; se multiplican por el índice de criminalidad.
const BASE_NPCS := {
	"turista": [40, ""],
	"vecino": [25, ""],
	"policia": [6, "total"],
	"yonki": [10, "vulnerables"],
	"camello": [4, "vulnerables"],
	"mantero": [3, "venta_ambulante"],
	"educador": [4, ""],
}
const PLAYER_SPEED := 18.0  ## metros por segundo
const RUN_FACTOR := 1.7  ## multiplicador de velocidad con Shift
const INTERACT_RANGE := 4  ## casillas
const CAMERA_PITCH := -40.0  ## grados; vista isométrica algo más cenital que la clásica
const CAMERA_DISTANCE := 160.0
const ZOOM_RANGE := Vector2(10.0, 110.0)  ## tamaño ortográfico (metros de alto en pantalla)
const PICK_RADIUS_PX := 28.0

var city: CityMap
var player: Actor
var camera: Camera3D
var hud: Hud
var interactions: Interactions
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

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34.0
	camera.near = 1.0
	camera.far = 600.0
	add_child(camera)
	_camera_focus = player.position
	_update_camera(1.0)

	interactions = Interactions.new(self)
	_place_markers()
	for kind in BASE_NPCS:
		_npc_targets[kind] = _target_count(kind)
		for i in _npc_targets[kind]:
			_spawn_npc(kind)

	hud = Hud.new()
	add_child(hud)
	hud.menu_closed.connect(func(): get_tree().paused = false)
	hud.restart_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hud.use_item_requested.connect(use_item)
	GameState.game_over.connect(_on_game_over)

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
	npc.home = home
	city.entities.add_child(npc)
	npc.setup(city, city.random_walkable_near(home, 8))
	npc.caught_player.connect(func(_n): arrest_player())
	npcs.append(npc)


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
	_update_player_state()
	_update_player_input()
	_update_camera(delta)
	_update_daylight()
	_update_xray()
	_update_hover()
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


func _update_player_state() -> void:
	var slow := 1.0
	if GameState.mono > 70.0:
		slow *= 0.7
	if GameState.high > 80.0:
		slow *= 0.75
	player.slow_factor = slow


## WASD (o las flechas) mueven al jugador respecto a la pantalla; Shift para correr.
func _update_player_input() -> void:
	var v := Vector2.ZERO
	if GameState.alive and not hud.is_menu_open():
		v.x = float(_held(KEY_D, KEY_RIGHT)) - float(_held(KEY_A, KEY_LEFT))
		v.y = float(_held(KEY_S, KEY_DOWN)) - float(_held(KEY_W, KEY_UP))
	player.run_factor = RUN_FACTOR if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if v == Vector2.ZERO:
		player.input_dir = Vector3.ZERO
		return
	_pending = null
	# ejes de la cámara aplanados sobre el suelo: +X a la derecha de la pantalla, +Z hacia abajo
	var b := camera.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var down := Vector3(b.z.x, 0, b.z.z).normalized()
	player.input_dir = (right * v.x + down * v.y).normalized()


func _held(letter: Key, arrow: Key) -> bool:
	return Input.is_physical_key_pressed(letter) or Input.is_key_pressed(arrow)


## Cámara ortográfica que sigue al jugador; Q/E la giran de 90 en 90 grados.
## Con mucho colocón la cámara se balancea.
func _update_camera(delta: float) -> void:
	_camera_focus = _camera_focus.lerp(player.position, minf(1.0, delta * 6.0))
	_camera_yaw = lerpf(_camera_yaw, _camera_yaw_target, minf(1.0, delta * 8.0))
	var sway := clampf((GameState.high - 50.0) / 50.0, 0.0, 1.0)
	var yaw := deg_to_rad(_camera_yaw + sin(_time * 1.1) * 6.0 * sway)
	var pitch := deg_to_rad(CAMERA_PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	camera.position = _camera_focus + dir * CAMERA_DISTANCE
	camera.look_at(_camera_focus, Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD, sin(_time * 1.3) * 0.05 * sway)


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
## para hacer transparentes los que lo tapan.
func _update_xray() -> void:
	var vp := get_viewport().get_visible_rect().size
	var target := player.global_position + Vector3(0, 1.2, 0)
	for mat in [city.building_material, CityProps.foliage_material]:
		mat.set_shader_parameter("focus_uv", camera.unproject_position(target) / vp)
		mat.set_shader_parameter("focus_depth", -(camera.global_transform.affine_inverse() * target).z)
		mat.set_shader_parameter("aspect", vp.x / vp.y)
		mat.set_shader_parameter("xray_radius", clampf(5.0 / camera.size, 0.06, 0.3))


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
				camera.size = clampf(camera.size / 1.12, ZOOM_RANGE.x, ZOOM_RANGE.y)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.size = clampf(camera.size * 1.12, ZOOM_RANGE.x, ZOOM_RANGE.y)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_camera_yaw_target -= 90.0
			KEY_E:
				_camera_yaw_target += 90.0
			KEY_I:
				hud.toggle_inventory()
			KEY_R:
				_rummage()
			KEY_Z:
				_sleep_here()


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
	if id == "cartera":
		GameState.remove_item("cartera")
		var n := randi_range(5, 90)
		GameState.add_money(n)
		GameState.log_msg("La cartera tenía %d €. Las fotos de sus hijos las tiras a la papelera." % n, GameState.C_GOOD)
		GameState.change_dignity(-1)
		return
	if Defs.SUBSTANCES.has(id) and police_near(player.cell, 14) > 0:
		GameState.heat = minf(100.0, GameState.heat + 35.0)
		GameState.log_msg("Un agente te ha visto consumiendo en plena calle.", GameState.C_BAD)
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
	sleep(6 * 60, 0.35, 10.0)
	GameState.change_dignity(-5, "Dormir en el suelo de %s" % city.street_name_near(player.cell))
	GameState.milestone("primera_calle")


## Duerme `minutes` minutos. `robbery_risk` es la probabilidad de que te roben si llevas dinero.
func sleep(minutes: float, robbery_risk: float, heal: float) -> void:
	player.stop()
	GameState.advance(minutes)
	if not GameState.alive:
		return
	GameState.change_health(heal)
	GameState.log_msg("Duermes %d horas. Son las %02d:%02d." % [int(minutes / 60), GameState.hour(), int(GameState.minute_of_day) % 60])
	if GameState.money > 0 and randf() < robbery_risk:
		GameState.log_msg("Al despertar te faltan los %d € que llevabas." % GameState.money, GameState.C_BAD)
		GameState.money = 0
		GameState.change_dignity(-3)


func arrest_player() -> void:
	if not GameState.alive:
		return
	hud.close_menu()
	_pending = null
	player.stop()
	for npc in npcs:
		npc.chasing = false
	GameState.arrest()
	var stations := city.pois_of_kind("comisaria")
	if not stations.is_empty() and GameState.alive:
		var s: Dictionary = stations.pick_random()
		player.setup(city, Vector2i(s["x"], s["y"]))
		GameState.log_msg("Te sueltan en la puerta de la comisaría.")


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


func highlight_poi(poi: Dictionary) -> void:
	for m in markers:
		if m.poi == poi:
			m.highlighted = true
			get_tree().create_timer(12.0, false).timeout.connect(func(): m.highlighted = false)


func _respawn() -> void:
	for kind in _npc_targets:
		var have := npcs.filter(func(n): return n.kind == kind).size()
		if have < _npc_targets[kind]:
			_spawn_npc(kind)


## Eventos del barrio: peleas entre yonkis y yonkis que vienen a pedirte.
func _random_event() -> void:
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


func _on_game_over(reason: String) -> void:
	player.stop()
	hud.close_menu()
	hud.show_game_over(reason)
