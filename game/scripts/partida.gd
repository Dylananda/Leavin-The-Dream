class_name Partida
extends RefCounted
## Partidas guardadas: un archivo JSON por partida en user://partidas/<id>.json.
##
## El archivo lleva una cabecera legible (versión, perfil, día y hora de juego, cuándo se
## guardó, si sigue viva) y los datos en "datos", pasados por JSON.from_native para que
## vuelvan con sus tipos (enteros, casillas, colores, plazos infinitos):
## - "estado": los campos de GameState de CAMPOS, por nombre. Al cargar se empieza una partida
##   nueva del mismo perfil y se le ponen los que haya: un campo que no estaba en una partida
##   vieja se queda como en una partida nueva, y uno que ya no existe se ignora.
## - "censo": todos los registros (Censo), también los de los personajes del editor (por su id);
##   los que tienen cuerpo se guardan como si se durmieran (Censo.foto).
## - "jugador": dónde estás. "conversacion": la memoria de lo hablado con la IA.
## Los encargos y misiones guardan a quien te los dio como el número de su registro del censo;
## las notas de la libreta, el número de su encargo.
##
## Se guarda sola al dormir y al empezar un día (World._autoguardar), y a mano desde la pausa.
## «Continuar», en el menú de inicio, carga la más reciente que siga viva.

const VERSION := 1
const DIR := "user://partidas/"
## Lo que se guarda de GameState (el perfil va aparte, por su id).
const CAMPOS := ["money", "bank", "health", "hunger", "fatigue", "starving", "vitality", "riding",
	"exhausted", "sanity", "dignity", "heat", "caida", "debt", "wanted_until", "wanted_crime",
	"inventory", "fakes", "milestones", "arrests", "fines", "admissions", "subs", "resacas", "errands", "notes",
	"pistas", "misiones", "favores", "debe_a", "apartados", "clock_skew", "_clock_lie_left",
	"_clock_blank", "day", "minute_of_day", "alive", "ending_title", "papa_cut",
	"_next_income_day", "_last_meds_day", "_last_methadone_day", "_next_receta_day"]
## Claves del registro del censo que no se guardan tal cual (se rehacen al cargar).
const REGISTRO_APARTE := ["npc", "personaje", "zona", "perros", "_d"]

## Lo cargado que falta por poner en el mundo: World lo aplica al montarse (aplicar_mundo).
static var pendiente := {}
## Si se guarda sola (las pruebas lo apagan para no llenar user:// de partidas).
static var automatico := true


static func ruta(id: String) -> String:
	return DIR + id + ".json"


## Las partidas guardadas, de la más reciente a la más vieja: la cabecera de cada una más su
## "ruta" (sin los datos, que pueden ser grandes... aunque hay que leer el archivo entero).
static func lista() -> Array:
	var out := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var head := cabecera(DIR + f)
		if not head.is_empty():
			head["ruta"] = DIR + f
			head["mtime"] = FileAccess.get_modified_time(DIR + f)
			out.append(head)
	out.sort_custom(func(a, b): return a["mtime"] > b["mtime"])
	return out


## La partida más reciente que sigue viva (su cabecera con "ruta"), o {}.
static func ultima() -> Dictionary:
	for p in lista():
		if p.get("vivo", false) and int(p.get("version", 0)) <= VERSION:
			return p
	return {}


## La cabecera de un archivo de partida (todo menos los datos), o {} si no se puede leer.
static func cabecera(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("version"):
		return {}
	data.erase("datos")
	return data


## La hora de juego, «09:30».
static func hora() -> String:
	return "%02d:%02d" % [GameState.hour(), int(GameState.minute_of_day) % 60]


# ------------------------------------------------------------------- guardar

## Guarda la partida de `world` en su archivo (lo crea la primera vez). `path` = otro archivo
## (las pruebas). Devuelve el error de escritura, u OK.
static func guardar(world: World, path := "") -> Error:
	var gs := GameState
	if gs.partida_id == "":
		gs.partida_id = "%s_%s" % [gs.profile["id"], Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")]
	if path == "":
		path = ruta(gs.partida_id)
	var datos := {
		"estado": _estado(world),
		"censo": _censo(world),
		"jugador": {"cell": world.player.cell},
		"conversacion": world.conversation._memory.duplicate(true),
	}
	var file := {
		"version": VERSION,
		"id": gs.partida_id,
		"perfil": gs.profile["id"],
		"nombre": gs.profile["name"],
		"dia": gs.day,
		"hora": hora(),
		"caida": roundi(gs.caida),
		"vivo": gs.alive,
		"guardada": Time.get_datetime_string_from_system(false, true),
		"datos": JSON.from_native(datos),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(file))
	return OK


## Los campos de GameState, con los encargos y la libreta sin referencias a objetos.
static func _estado(world: World) -> Dictionary:
	var gs := GameState
	var out := {}
	for k in CAMPOS:
		var v = gs.get(k)
		out[k] = v.duplicate(true) if v is Dictionary or v is Array else v
	var errands := []
	for e in gs.errands:
		var c: Dictionary = e.duplicate(true) if not e.has("giver") else _sin_giver(e)
		c["giver"] = _indice(world, e.get("giver"))
		errands.append(c)
	out["errands"] = errands
	var notes := []
	for n in gs.notes:
		var c: Dictionary = n.duplicate()
		c["errand"] = gs.errands.find(n["errand"])
		c["poi"] = n["poi"].duplicate(true)
		notes.append(c)
	out["notes"] = notes
	return out


## Copia de un encargo sin su `giver` (un Npc no se copia: se guarda su registro aparte).
static func _sin_giver(e: Dictionary) -> Dictionary:
	var c := {}
	for k in e:
		if k != "giver":
			c[k] = e[k].duplicate(true) if e[k] is Dictionary or e[k] is Array else e[k]
	return c


## El número del registro del censo de `npc` (-1 si no tiene: los que van detrás de otro).
static func _indice(world: World, npc) -> int:
	if npc == null or not is_instance_valid(npc):
		return -1
	for i in world.censo.registros.size():
		if is_same(world.censo.registros[i]["npc"], npc):
			return i
	return -1


## Los registros del censo, con lo que les ha pasado a los que tienen cuerpo.
static func _censo(world: World) -> Array:
	var out := []
	for r in world.censo.registros:
		world.censo.foto(r)
		var c := {}
		for k in r:
			if not k in REGISTRO_APARTE:
				c[k] = r[k].duplicate(true) if r[k] is Dictionary or r[k] is Array else r[k]
		c["personaje_id"] = r["personaje"].get("id", "")
		c["perros_ids"] = r.get("perros", []).map(func(d): return d["id"])
		out.append(c)
	return out


# ------------------------------------------------------------------- cargar

## Carga la partida de `path`: pone GameState como estaba y deja el resto en `pendiente`, para
## que lo aplique el mundo al montarse (cambia tú de escena a world.tscn). false si no se puede.
static func cargar(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version", 0)) > VERSION or not data.has("datos"):
		push_warning("Partida ilegible o de una versión más nueva: " + path)
		return false
	var datos = JSON.to_native(data["datos"])
	if not datos is Dictionary:
		return false
	var gs := GameState
	gs.new_game(data.get("perfil", "parado"))
	gs.partida_id = data.get("id", path.get_file().get_basename())
	var estado: Dictionary = datos.get("estado", {})
	for k in estado:
		if not k in CAMPOS:
			continue  # un campo que ya no existe
		if k == "milestones":
			gs.milestones.assign(estado[k])
		elif k == "notes":
			continue  # después de los encargos, para enlazarlas
		else:
			gs.set(k, estado[k])
	var notes := []
	for n in estado.get("notes", []):
		var i: int = n.get("errand", -1)
		if i >= 0 and i < gs.errands.size():
			n["errand"] = gs.errands[i]
			notes.append(n)
	gs.notes = notes
	gs.changed.emit()
	pendiente = datos
	return true


## Pone en `world` (recién montado) lo que se cargó: el censo, quién te dio cada encargo, dónde
## estás, si vas en bici y lo hablado con la IA. Lo llama World._ready al final.
static func aplicar_mundo(world: World) -> void:
	var datos := pendiente
	pendiente = {}
	var censo := world.censo
	# fuera los que ha montado el mundo al empezar: vienen los guardados
	for r in censo.registros:
		censo.dormir(r)
	var fichas := {}
	for d in world._personajes:
		fichas[d["id"]] = d
	var registros: Array[Dictionary] = []
	var indices := {}  # número guardado -> registro cargado (falta si su personaje ya no existe)
	var saved: Array = datos.get("censo", [])
	for i in saved.size():
		var c: Dictionary = saved[i]
		var r := {"kind": "vecino", "name": "", "personaje": {}, "home": Vector2i.ZERO,
			"bed": Vector2i(-1, -1), "zona": [], "seguidores": [], "estado": {}, "visto": GameState.now(), "npc": null}
		for k in c:
			if k != "personaje_id" and k != "perros_ids":
				r[k] = c[k]
		var pid: String = c.get("personaje_id", "")
		if pid != "":
			if not fichas.has(pid):
				continue  # lo han borrado del editor
			r["personaje"] = fichas[pid]
			if fichas[pid]["zona"]["tipo"] == "poligono":
				r["zona"] = world._cells_in_polygon(fichas[pid]["zona"]["poligono"])
		var perros := []
		for dog in c.get("perros_ids", []):
			if fichas.has(dog):
				perros.append(fichas[dog])
		if not perros.is_empty():
			r["perros"] = perros
		if not Npc.KINDS.has(r["kind"]):
			continue
		registros.append(r)
		indices[i] = r
	censo.registros = registros
	var jugador: Dictionary = datos.get("jugador", {})
	if jugador.has("cell"):
		world.player.setup(world.city, world.city.nearest_walkable(jugador["cell"]))
		world._camera_focus = world.player.position
	if GameState.riding:
		var look: Dictionary = world.player.look.duplicate()
		look["bici"] = true
		world.player.look = look
		world.player.rebuild()
	# quien te dio un encargo en marcha tiene cuerpo (como al dármelo: no se duerme)
	for e in GameState.errands:
		var i: int = e.get("giver", -1) if e.get("giver") is int else -1
		e["giver"] = null
		if indices.has(i):
			var r: Dictionary = indices[i]
			e["giver"] = r["npc"] if r["npc"] != null else censo.despertar(r)
	censo.repasar(0, 0, true)
	world.conversation._memory = datos.get("conversacion", {})
