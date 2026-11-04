class_name Relaciones
extends RefCounted
## Relaciones entre los personajes del editor (fase 3 del diseñador): con quién se lleva bien o
## mal, quién es familia o pareja de quién, quién trabaja para quién y quién le debe dinero a
## quién. Cada personaje guarda las suyas en "relaciones" (Personajes.nueva_relacion), pero
## valen en los dos sentidos: si Vera se lleva bien con El Mudo, El Mudo con Vera.
##
## En la partida, lo que le haces a uno lo saben los suyos: si le ayudas, sus amigos, su
## familia y su gente te miran mejor (se acercan a saludarte) y sus enemigos peor; si le robas,
## le pegas, le timas o te chivas de él, al revés (se apartan o, los de mala sangre, van a por
## ti), y no te dan misiones. Se apunta en su memoria (Npc.memory "oido_bien" y "oido_mal"),
## que se guarda en el censo y se olvida con el tiempo como lo demás.

const G := preload("res://scripts/game_state.gd")

## Relaciones de «los suyos»: lo que le haces a uno, se lo haces a ellos.
const SUYOS := ["amigo", "familia", "pareja", "trabaja_para"]
## Lo que se cuenta: lo que le haces y si es bueno o malo para él (ver Npc.remember).
const SE_CUENTA := {"ayudado": true, "robado": false, "pegado": false, "timado": false, "chivato": false}

var world: World


func _init(p_world: World) -> void:
	world = p_world


## Las relaciones de `pid` en los dos sentidos: [{"pid", "tipo", "nota"}] (sin repetir).
## `personajes` = las fichas de todos (World._personajes o, en el editor, las guardadas).
static func de(pid: String, personajes: Array) -> Array:
	var out := []
	var vistos := {}
	for d in personajes:
		if d["id"] == pid:
			for r in d.get("relaciones", []):
				if r["con"] != "" and not vistos.has(r["con"]):
					vistos[r["con"]] = true
					out.append({"pid": r["con"], "tipo": r["tipo"], "nota": r.get("nota", "")})
	for d in personajes:
		if d["id"] == pid or vistos.has(d["id"]):
			continue
		for r in d.get("relaciones", []):
			if r["con"] == pid:
				vistos[d["id"]] = true
				out.append({"pid": d["id"], "tipo": r["tipo"], "nota": r.get("nota", "")})
				break
	return out


## Se corre la voz: le has hecho `que` (SE_CUENTA) al personaje `pid`. Sus amigos, familia y
## gente se lo toman como propio; sus enemigos, al revés. No se encadena (lo que oyen no se
## vuelve a contar). Devuelve los nombres de los que se han enterado.
func propagar(pid: String, que: String) -> Array:
	if pid == "" or not SE_CUENTA.has(que):
		return []
	var bueno: bool = SE_CUENTA[que]
	var nombres := []
	for rel in de(pid, world._personajes):
		if rel["tipo"] == "le_debe":
			continue
		var suyo: bool = rel["tipo"] in SUYOS
		var key := "oido_bien" if bueno == suyo else "oido_mal"
		if _apuntar(rel["pid"], key):
			nombres.append(world.misiones.ficha(rel["pid"]).get("nombre", rel["pid"]))
	if not nombres.is_empty():
		var quien: String = world.misiones.ficha(pid).get("nombre", pid)
		GameState.log_msg("Se corre la voz de lo de %s: %s %s." % [quien, _lista(nombres),
			"ya lo sabe" if nombres.size() == 1 else "ya lo saben"], G.C_FALL if not bueno else G.C_INFO)
	return nombres


## Le apunta `key` en la memoria al personaje `pid`: al cuerpo si lo tiene, si no al registro
## del censo (lo recuerda al despertar). false si no está en el censo.
func _apuntar(pid: String, key: String) -> bool:
	if world.censo == null:
		return false
	for r in world.censo.registros:
		if r["personaje"].get("id", "") != pid:
			continue
		var npc = r["npc"]
		var memory: Dictionary
		if npc != null and is_instance_valid(npc):
			memory = npc.memory
		else:
			if not r["estado"].has("memory"):
				r["estado"]["memory"] = {}
			memory = r["estado"]["memory"]
		memory[key] = memory.get(key, 0) + 1
		return true
	return false


## Lo que está mal en las relaciones del personaje `d`: [[es_error, texto], ...].
static func comprobar(d: Dictionary, ids: Array) -> Array:
	var out := []
	var vistos := {}
	for r in d.get("relaciones", []):
		if r["con"] == "":
			out.append([true, "Hay una relación sin personaje."])
		elif r["con"] == d["id"]:
			out.append([true, "Una relación consigo mismo."])
		elif vistos.has(r["con"]):
			out.append([false, "Dos relaciones con el mismo personaje (%s): solo cuenta la primera." % r["con"]])
		elif not r["con"] in ids:
			out.append([false, "La relación con «%s»: no está guardado." % r["con"]])
		vistos[r["con"]] = true
	return out


static func _lista(nombres: Array) -> String:
	if nombres.size() == 1:
		return nombres[0]
	return ", ".join(nombres.slice(0, -1)) + " y " + nombres[-1]
