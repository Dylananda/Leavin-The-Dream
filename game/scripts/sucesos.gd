class_name Sucesos
extends RefCounted
## Sucesos del barrio (docs/ideas.md, «Sucesos de la historia del barrio»): cosas que le pasan
## al Raval durante unos días y lo cambian para todos. Llega el fentanilo, redadas fuertes, la
## Fiesta Mayor y obras que cortan una calle (Defs.SUCESOS).
##
## Cada día (GameState.new_day) se mira si se acaba alguno y si empieza otro: por fecha
## (Defs.CALENDARIO_INICIO) o al azar. Al empezar se anuncia en el registro, se apunta como
## rumor en la libreta (GameState.add_pista) y la gente lo comenta al pasar (frase()); la IA de
## las conversaciones también lo sabe. Lo que está en marcha va en GameState.sucesos
## ({id: {"hasta": now(), ...}}), que se guarda en la partida y sobrevive a un relevo, y
## GameState.sucesos_fin guarda cuándo acabó cada uno (para no repetirlo enseguida).
##
## Cómo se nota (lo leen otros sistemas con las funciones de GameState):
## - Cuántos bots hay de cada tipo (`gente`, World._target_count) y qué camellos se esconden
##   en las redadas (escondido, Censo.activo).
## - Lo que cuesta la droga (`precio`, GameState.factor_precio) y lo que te dan pidiendo (`pedir`).
## - El fentanilo: se vende, viene cortado en el caballo (GameState.consume), los bots que se
##   meten opiáceos caen (Npc.pasa_consumo: delante de ti se les puede salvar con naloxona) y
##   cada día aparece alguno muerto en un portal; las educadoras reparten naloxona.
## - Las obras: casillas que no se pueden pisar (CityMap.bloquear) y vallas alrededor.

const G := preload("res://scripts/game_state.gd")

## Si empiezan sucesos al azar (las pruebas lo apagan; los de fecha empiezan igual).
static var azar := true

var world: World
var _vallas := {}  ## id -> Node3D con las vallas de unas obras


func _init(p_world: World) -> void:
	world = p_world


static func activo(id: String) -> bool:
	return GameState.sucesos.has(id)


## Si el camello del registro `r` está escondido por las redadas (siempre los mismos: los
## demás se arriesgan y siguen vendiendo).
static func escondido(r: Dictionary) -> bool:
	if r.get("kind", "") != "camello" or not activo("redadas"):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(r.get("name", "")) + "|redada")
	return rng.randf() < Defs.REDADA_ESCONDIDOS


## Algo que dice la gente al pasar sobre lo que está pasando, o "" si no hay nada.
static func frase() -> String:
	var lines := []
	for id in GameState.sucesos:
		lines.append_array(Defs.SUCESOS[id].get("frases", []))
	return lines.pick_random() if not lines.is_empty() else ""


## Lo que pasa estos días, en una frase (para la IA de las conversaciones), o "".
static func resumen() -> String:
	return ", ".join(GameState.sucesos.keys().map(func(id): return Defs.SUCESOS[id]["titulo"].to_lower()))


# ------------------------------------------------------------------- empezar y acabar

## Al empezar un día: acaban los que tocan y empieza alguno nuevo (por fecha o al azar).
func nuevo_dia() -> void:
	var gs := GameState
	if not gs.alive:
		return
	for id in gs.sucesos.keys():
		if gs.now() >= gs.sucesos[id]["hasta"]:
			terminar(id)
	var hoy := gs.fecha()
	for id in Defs.SUCESOS:
		if activo(id):
			continue
		var s: Dictionary = Defs.SUCESOS[id]
		if s.has("fecha"):
			if s["fecha"][0] == hoy[0] and s["fecha"][1] == hoy[1]:
				empezar(id)
			continue
		var desde_fin: float = (gs.now() - gs.sucesos_fin.get(id, -INF)) / 1440.0
		if azar and gs.day >= s.get("desde_dia", 1) and desde_fin >= s.get("pausa", 0) and randf() < s["prob_dia"]:
			empezar(id)
	if activo("fentanilo"):
		_muertes_latentes()


## Empieza el suceso `id` durante `dias` días (-1: los de Defs.SUCESOS, al azar).
func empezar(id: String, dias := -1) -> void:
	var gs := GameState
	var s: Dictionary = Defs.SUCESOS[id]
	if dias < 0:
		dias = randi_range(s["dias"][0], s["dias"][1])
	var data := {"hasta": (gs.day - 1 + dias) * 1440.0 + 6.0 * 60.0}  # hasta las 6:00 del último día
	var donde := ""
	if id == "obras":
		var obra := _elegir_obra()
		if obra.is_empty():
			return
		data.merge(obra)
		donde = obra["calle"]
	gs.sucesos[id] = data
	var anuncio: String = s["anuncio"] % donde if "%s" in s["anuncio"] else s["anuncio"]
	gs.log_msg("%s (%s). %s" % [s["titulo"], gs.fecha_texto(), anuncio], G.C_FALL)
	gs.add_pista("la gente del barrio", s["rumor"] % donde if "%s" in s["rumor"] else s["rumor"])
	_aplicar(id)
	gs.changed.emit()


func terminar(id: String) -> void:
	var gs := GameState
	if not activo(id):
		return
	var data: Dictionary = gs.sucesos[id]
	var s: Dictionary = Defs.SUCESOS[id]
	gs.sucesos.erase(id)
	gs.sucesos_fin[id] = gs.now()
	if id == "obras":
		world.city.desbloquear(_celdas(data))
		if _vallas.has(id):
			_vallas[id].queue_free()
			_vallas.erase(id)
	gs.log_msg(s["fin"] % data.get("calle", "") if "%s" in s["fin"] else s["fin"])
	world.recalcular_gente()
	gs.changed.emit()


## Pone en el mundo lo que está en marcha (al empezar, y al cargar una partida o tras un relevo).
func reaplicar() -> void:
	for id in GameState.sucesos:
		_aplicar(id)


func _aplicar(id: String) -> void:
	var data: Dictionary = GameState.sucesos[id]
	if id == "obras" and not _vallas.has(id):
		world.city.bloquear(_celdas(data))
		_vallas[id] = _poner_vallas(_celdas(data))
	if id == "redadas":
		# los camellos que se esconden desaparecen de la calle (si no tienen asuntos contigo)
		for r in world.censo.registros:
			if escondido(r) and r["npc"] != null and is_instance_valid(r["npc"]) and not world.censo.anclado(r["npc"]):
				world.censo.dormir(r)
	world.recalcular_gente()


# ------------------------------------------------------------------- obras

## Un tramo de calle para cortar: un punto de una calle con nombre, lejos de ti. {} si no hay.
func _elegir_obra() -> Dictionary:
	var city := world.city
	var me: Vector2i = world.player.cell
	var opciones := city.streets.filter(func(s): return s["name"] != "" and s["name"] != "La Rambla" 		and Vector2(Vector2i(s["x"], s["y"]) - me).length() > Defs.OBRAS_LEJOS 		and city.cell_type(Vector2i(s["x"], s["y"])) in CityMap.WALKABLE)
	opciones.shuffle()
	for s in opciones.slice(0, 20):
		var obra := {"calle": s["name"], "centro": Vector2i(s["x"], s["y"]), "radio": Defs.OBRAS_RADIO}
		if _celdas(obra).size() >= 4:
			return obra
	return {}


## Las casillas cortadas por unas obras (las de calle dentro de su radio).
func _celdas(data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c: Vector2i = data["centro"]
	var r: int = data["radio"]
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= r + 0.5 and world.city.cell_type(p) in CityMap.WALKABLE:
				out.append(p)
	return out


## Vallas de obra (blancas y rojas) en el borde del tramo cortado.
func _poner_vallas(cells: Array[Vector2i]) -> Node3D:
	var node := Node3D.new()
	node.name = "Obras"
	world.city.entities.add_child(node)
	var dentro := {}
	for c in cells:
		dentro[c] = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(world.city.cell_m * 0.9, 1.0, 0.15)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f0f0e8")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("d03028")
	var i := 0
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if dentro.has(c + d) or not world.city.cell_type(c + d) in CityMap.WALKABLE:
				continue
			var v := MeshInstance3D.new()
			v.mesh = mesh
			v.material_override = white if i % 2 == 0 else red
			var pos := world.city.cell_to_world(c) + Vector3(d.x, 0, d.y) * world.city.cell_m * 0.45
			v.position = pos + Vector3(0, 0.5, 0)
			v.rotation.y = PI / 2.0 if d.x != 0 else 0.0
			node.add_child(v)
			i += 1
	return node


# ------------------------------------------------------------------- fentanilo

## Cada día de fentanilo, alguno de los latentes que se mete opiáceos aparece muerto en un
## portal (Defs.FENTA_MUERTOS_DIA): sale del censo y se comenta.
func _muertes_latentes() -> void:
	var posibles := world.censo.registros.filter(func(r): return r["npc"] == null and r["personaje"].is_empty() 		and r["estado"].get("consumo", {}).get("id", "") in Defs.OPIACEOS)
	posibles.shuffle()
	var n := randi_range(Defs.FENTA_MUERTOS_DIA.x, Defs.FENTA_MUERTOS_DIA.y)
	for r in posibles.slice(0, n):
		var nombre: String = r["estado"].get("display_name", r["name"])
		world.censo.registros.erase(r)
		GameState.log_msg("Han encontrado a %s en un portal de %s. Dicen que era fentanilo." % [nombre,
			world.city.street_name_near(r.get("home", Vector2i.ZERO))], G.C_FALL)


## Un bot ha caído de sobredosis delante de ti: si no le ponen naloxona en un rato, muere.
## Lejos de ti, muere sin más (y se comenta).
func cae(npc: Npc) -> void:
	if npc.has_meta("sobredosis"):
		return
	if npc.on_screen and world.player and npc.distance_to_cell(world.player.cell) < 30:
		npc.stop()
		npc.mode = "caido"
		npc.set_meta("sobredosis", npc._clock() + Defs.FENTA_CAIDO_SEGUNDOS)
		npc.say("...", Defs.FENTA_CAIDO_SEGUNDOS)
		GameState.log_msg("¡%s se ha caído al suelo y no respira! (naloxona, o llamar al 112)" % npc.display_name, G.C_BAD)
	else:
		muere(npc)


## Muere de sobredosis: sale del censo (y de la calle).
func muere(npc: Npc) -> void:
	var r: Dictionary = world.censo.de(npc)
	if not r.is_empty():
		world.censo.registros.erase(r)
	GameState.log_msg("%s ha muerto de sobredosis en %s." % [npc.display_name, world.city.street_name_near(npc.cell)], G.C_FALL)
	world.npcs.erase(npc)
	npc.queue_free()


## Le pones la naloxona a `npc`, que se ha caído: vuelve de golpe (con un mono brutal).
func salvar(npc: Npc) -> void:
	var gs := GameState
	gs.remove_item("naloxona")
	gs.advance(5)
	npc.remove_meta("sobredosis")
	npc.calm_down()
	if not npc.consumo.is_empty():
		npc.consumo["colocon"] = 0.0
		npc.consumo["mono"] = 80.0
	npc.remember("ayudado")
	npc.say("¿Qué... qué ha pasado? Joder...", 4.0)
	gs.log_msg("Le clavas la naloxona en el muslo. %s vuelve de golpe, temblando. Le has salvado la vida." % npc.display_name, G.C_GOOD)
	gs.change_dignity(6, "Salvarle la vida a alguien")
	gs.change_sanity(5)
	gs.milestone("salvar_vida")
