class_name Conversation
extends Node
## Conversación libre con los bots que tienen ficha (ver fichas.gd). El juego propone y la IA
## habla: en cada frase el juego calcula lo que puede pasar de verdad (las acciones de su menú
## en interactions.gd, datos ciertos que conoce, sitios cercanos) y el modelo solo elige entre
## esos ids, que el esquema de la respuesta no le deja inventar, y lo pone en palabras.
## Lleva además la memoria corta de lo hablado y de lo que ha pasado con cada uno.

const G := preload("res://scripts/game_state.gd")

## La respuesta, para la interfaz: lo que dice, lo que te ofrece ([{"id", "label"}], para
## aceptarlo o no) y si da la conversación por terminada.
signal replied(npc: Npc, text: String, offers: Array, ended: bool)
signal failed(npc: Npc, error: String)

const MAX_MESSAGES := 12  ## Frases de la memoria corta con cada personaje (las más antiguas se olvidan)
const MAX_FACTS := 8  ## Hechos que recuerda (lo que te ofreció, lo que te contó...)
const MAX_DATA := 4  ## Datos ciertos que puede contar en cada frase
const MINUTES_PER_LINE := 2.0  ## Lo que pasa el reloj por cada frase
const POLICE_RADIUS := 60  ## Casillas a las que ve a los agentes
const TOURIST_RADIUS := 40  ## Casillas a las que se fija en los guiris
const POLICE_HEAT := 50.0  ## Lo que sube la búsqueda si te echa a la policía encima
## Acciones del menú que el personaje nunca te propondría (las haces tú contra él, o ya están aquí).
const NOT_OFFERED := ["Hablar", "Escuchar", "Robar", "Pelear", "Insultar"]
const REACTIONS := ["ninguna", "enfadarse", "llamar_a_la_policia", "despedirse"]

var world: World
var client: LlmClient
var busy := false
## "tipo|nombre" -> {"messages": [{"role", "content"}], "facts": [String]}. Si vuelve a salir
## alguien con el mismo nombre, se acuerda de ti.
var _memory := {}
## Lo que puede pasar en esta frase, con sus ids: "options" (o1... -> acción del menú),
## "data" (d1... -> texto cierto) y "sites" (s1... -> lugar). Se recalcula en cada frase.
var _turn := {"options": {}, "data": {}, "sites": {}}
var _warned := false  ## Solo se avisa una vez en el registro de que la IA no responde


func _init(p_world: World) -> void:
	world = p_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	client = LlmClient.new()
	add_child(client)


static func can_talk(npc: Npc) -> bool:
	return Fichas.has_npc(npc) and not npc.has_meta("enemigo")


func _key(npc: Npc) -> String:
	return "%s|%s" % [npc.kind, npc.display_name]


func _mem(npc: Npc) -> Dictionary:
	var k := _key(npc)
	if not _memory.has(k):
		_memory[k] = {"messages": [], "facts": []}
	return _memory[k]


## Lo hablado con él, para pintarlo en la interfaz: [[quién, texto]] ("tu" o "el").
func history(npc: Npc) -> Array:
	var out := []
	for m in _mem(npc)["messages"]:
		if m["role"] == "user":
			out.append(["tu", m["content"]])
		else:
			out.append(["el", _parse(m["content"])["dice"]])
	return out


## Lo que dice el jugador. La respuesta llega luego por `replied` o `failed`.
func say(npc: Npc, text: String) -> void:
	if busy or not can_talk(npc):
		return
	busy = true
	GameState.advance(MINUTES_PER_LINE)
	var mem := _mem(npc)
	mem["messages"].append({"role": "user", "content": text})
	var messages := [{"role": "system", "content": system_prompt(npc)}]
	messages.append_array(mem["messages"])
	client.ask(messages, schema(), func(ok: bool, content: String):
		busy = false
		if not is_instance_valid(npc):
			return
		if ok:
			handle_reply(npc, content)
		else:
			mem["messages"].pop_back()  # que no se acuerde de algo que no ha oído
			if not _warned:
				_warned = true
				GameState.log_msg("La IA de las conversaciones (%s) %s. El juego sigue sin ella." % [client.describe(), content], G.C_BAD)
			print("IA: ", content)
			failed.emit(npc, content))


## Formato de la respuesta: primero lo que decide (solo entre los ids de esta frase, o nada)
## y luego lo que dice, que tiene que contarlo. Todos los campos son obligatorios: probado con
## qwen2.5:7b, si son opcionales ofrece cosas de palabra y no las apunta.
func schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"ofrece": {"type": "string", "enum": [""] + _turn["options"].keys()},
			"cuenta": {"type": "string", "enum": [""] + _turn["data"].keys()},
			"senala": {"type": "string", "enum": [""] + _turn["sites"].keys()},
			"reaccion": {"type": "string", "enum": REACTIONS},
			"dice": {"type": "string"},
		},
		"required": ["ofrece", "cuenta", "senala", "reaccion", "dice"],
		"additionalProperties": false,  # lo exige la API de Anthropic
	}


## Aplica la respuesta del modelo y avisa a la interfaz. Los ids que no son de esta frase
## se ignoran. Devuelve lo mismo que manda por `replied`: {"text", "offers", "ended"}.
func handle_reply(npc: Npc, content: String) -> Dictionary:
	var data := _parse(content)
	var text: String = data["dice"].strip_edges().left(500)
	var mem := _mem(npc)
	mem["messages"].append({"role": "assistant", "content": JSON.stringify({"dice": text})})
	while mem["messages"].size() > MAX_MESSAGES:
		mem["messages"].pop_front()
	GameState.advance(MINUTES_PER_LINE)
	if text != "":
		npc.say(text.left(80), 4.0)
	var offers := []
	var option: Dictionary = _turn["options"].get(data["ofrece"], {})
	if not option.is_empty():
		offers.append({"id": data["ofrece"], "label": option["label"]})
		_fact(npc, "Le ofreciste: " + option["label"])
	var fact: String = _turn["data"].get(data["cuenta"], "")
	if fact != "":
		GameState.log_msg("Pista de %s: %s" % [npc.display_name, fact], G.C_GOOD)
		GameState.add_pista(npc.display_name, fact)
		_fact(npc, "Le contaste: " + fact)
	var poi: Dictionary = _turn["sites"].get(data["senala"], {})
	if not poi.is_empty():
		world.highlight_poi(poi)
		GameState.log_msg("%s te señala %s." % [npc.display_name, _site_text(poi)], G.C_GOOD)
		GameState.add_pista(npc.display_name, "te señala " + _site_text(poi), poi)
		_fact(npc, "Le señalaste " + _site_text(poi))
	var ended := true
	match data["reaccion"]:
		"enfadarse":
			npc.set_meta("enemigo", true)
			GameState.log_msg("%s no quiere saber nada más de ti." % npc.display_name, G.C_BAD)
			GameState.change_dignity(-2, "Ganarte un enemigo")
		"llamar_a_la_policia":
			npc.set_meta("enemigo", true)
			npc.say("¡Policía! ¡Este de aquí!", 4.0)
			GameState.heat = minf(100.0, GameState.heat + POLICE_HEAT)
			GameState.log_msg("%s te echa a la policía encima." % npc.display_name, G.C_BAD)
		"despedirse":
			pass
		_:
			ended = false
	if ended:
		offers.clear()
	replied.emit(npc, text, offers, ended)
	return {"text": text, "offers": offers, "ended": ended}


## El jugador acepta lo que le ofrece: se hace la acción del menú como si la hubiera elegido allí.
func accept(npc: Npc, id: String) -> bool:
	var option: Dictionary = _turn["options"].get(id, {})
	if option.is_empty():
		return false
	_turn["options"] = {}  # tras hacerla, las demás pueden haber dejado de valer
	_fact(npc, "Hizo contigo: " + option["label"])
	option["do"].call()
	return true


func _fact(npc: Npc, text: String) -> void:
	var facts: Array = _mem(npc)["facts"]
	facts.append("Día %d, %s: %s" % [GameState.day, GameState.clock_text().get_slice(" ", 2), text])
	while facts.size() > MAX_FACTS:
		facts.pop_front()


static func _parse(content: String) -> Dictionary:
	var out := {"dice": "", "ofrece": "", "cuenta": "", "senala": "", "reaccion": "ninguna"}
	var json := JSON.new()  # (JSON.parse_string llena la consola de errores si no es JSON)
	if json.parse(content) == OK and json.data is Dictionary:
		for k in out:
			out[k] = str(json.data.get(k, out[k]))
	else:  # un modelo que no respeta el formato: se toma el texto tal cual
		out["dice"] = content.strip_edges()
	return out


# ------------------------------------------------------------------ contexto

## Calcula lo que puede pasar en esta frase (opciones, datos y sitios, con sus ids).
func _prepare(npc: Npc) -> void:
	_turn = {"options": {}, "data": {}, "sites": {}}
	for a in world.interactions.for_npc(npc):
		if not NOT_OFFERED.any(func(w): return a["label"].begins_with(w)):
			_turn["options"]["o%d" % (_turn["options"].size() + 1)] = a
	var data := []
	var f := Fichas.of_npc(npc)
	if "policia" in f["datos"]:
		data.append_array(_police_data(npc, "secretas" in f["datos"]))
	if "turistas" in f["datos"]:
		data.append_array(_tourist_data(npc))
	for d in data.slice(0, MAX_DATA):
		_turn["data"]["d%d" % (_turn["data"].size() + 1)] = d
	for kind in Fichas.SITE_KINDS:
		var best: Dictionary = {}
		var best_d := INF
		for p in world.city.pois_of_kind(kind):
			var d := npc.distance_to_cell(Vector2i(p["x"], p["y"]))
			if d < best_d:
				best_d = d
				best = p
		if not best.is_empty():
			_turn["sites"]["s%d" % (_turn["sites"].size() + 1)] = best


func _site_text(poi: Dictionary) -> String:
	var name: String = Interactions.POI_LABELS.get(poi["kind"], poi["kind"])
	if poi.get("name", "") != "":
		name += " «%s»" % poi["name"]
	return "%s en %s" % [name, world.city.street_name_near(Vector2i(poi["x"], poi["y"]))]


func _meters(a: Npc, cell: Vector2i) -> int:
	return int(a.distance_to_cell(cell) * world.city.cell_m)


## Agentes cerca de `npc`, con su cuerpo; los de paisano, solo si `secretas` (quien vive de
## la calle aprende a reconocerlos).
func _police_data(npc: Npc, secretas: bool) -> Array:
	const WHO := {"urbano": "un agente de la Urbana", "mosso": "una pareja de Mossos",
		"urbano_secreta": "uno de la Urbana de paisano", "mosso_secreta": "uno de los Mossos de paisano"}
	var out := []
	for n in world.npcs:
		if n.is_police() and (n.looks_police() or secretas) and n.distance_to_cell(npc.cell) <= POLICE_RADIUS:
			out.append("Hay %s por %s, a unos %d m." % [WHO[n.kind], world.city.street_name_near(n.cell), _meters(npc, n.cell)])
	if out.is_empty():
		out.append("Ahora mismo no hay ningún agente por aquí cerca.")
	return out


func _tourist_data(npc: Npc) -> Array:
	var streets := {}
	for n in world.npcs:
		if n.kind == "turista" and not n.robbed and n.distance_to_cell(npc.cell) <= TOURIST_RADIUS:
			var s := world.city.street_name_near(n.cell)
			streets[s] = streets.get(s, 0) + 1
	var out := []
	for s in streets:
		out.append("Hay %d %s con pinta de llevar pasta por %s." % [streets[s], "guiri" if streets[s] == 1 else "guiris", s])
	return out


## Cómo ve el personaje al jugador (no sabe sus cifras, solo lo que se nota).
func _player_text() -> String:
	var gs := GameState
	var p := gs.profile
	var looks := []
	if gs.high > 50.0:
		looks.append("va muy colocado")
	elif gs.high > 20.0:
		looks.append("va algo colocado")
	if gs.mono > 50.0:
		looks.append("tiene mono: suda y tiembla")
	if gs.hunger > 70.0:
		looks.append("se le ve muerto de hambre")
	if gs.fatigue > 70.0:
		looks.append("se cae de sueño")
	if gs.dignity < 30.0:
		looks.append("tiene una pinta lamentable")
	if gs.heat > 60.0:
		looks.append("está claro que la policía le busca")
	var text := "Se llama %s (%s). %s" % [p["name"], p["title"].to_lower(), p["desc"]]
	if not looks.is_empty():
		text += " Ahora mismo " + ", ".join(looks) + "."
	return text


static func _list(d: Dictionary, describe: Callable, empty: String) -> String:
	if d.is_empty():
		return "- (" + empty + ")"
	var lines := []
	for id in d:
		lines.append("- %s: %s" % [id, describe.call(d[id])])
	return "\n".join(lines)


## Instrucciones para el modelo. También prepara las opciones de esta frase (ver `schema`).
func system_prompt(npc: Npc) -> String:
	_prepare(npc)
	var f := Fichas.of_npc(npc)
	var bio: String = npc.bio() if npc.bio() != "" else f["historia"]
	var facts: Array = _mem(npc)["facts"]
	return "\n".join([
		"Eres %s, %s en el Raval de Barcelona, dentro de un videojuego. Hablas con otro del barrio, un yonki (el jugador). No rompas nunca el personaje ni digas que eres una IA." % [npc.display_name, Npc.kind_label(npc.kind, npc.gender).to_lower()],
		"",
		"QUIÉN ERES: " + f["quien"],
		"TU HISTORIA: " + bio,
		"CÓMO HABLAS: " + f["habla"],
		"QUÉ QUIERES: " + f["quiere"],
		"QUÉ NO SABES: " + f["no_sabe"],
		"AHORA: son las %s y estás en %s. Llevas %d € encima." % [GameState.clock_text().get_slice(" ", 2), world.city.street_name_near(npc.cell), npc.money],
		"EL JUGADOR: " + _player_text(),
		"LO QUE HA PASADO ENTRE VOSOTROS (nada más; si él dice otra cosa, no te acuerdas o no es verdad):",
		"
".join(facts.map(func(x): return "- " + x)) if not facts.is_empty() else "- (nada, no le conoces de antes)",
		"",
		"Cada vez que hablas, decides con ids de estas listas y luego lo dices. Lo normal es \"\" en las tres: elige algo solo si responde a lo que él acaba de decir o pedir.",
		"«ofrece»: algo que le propones o aceptas hacer con él. Solo esto existe: ni otros tratos, ni otros precios, ni otras cosas. Si te pide algo que no está, no puedes; dilo a tu manera.",
		_list(_turn["options"], func(a): return a["label"], "nada que ofrecerle ahora"),
		"«cuenta»: un dato cierto que le cuentas, solo si te pregunta por eso (la policía, los guiris). No te inventes otros.",
		_list(_turn["data"], func(d): return d, "no sabes nada útil ahora"),
		"«senala»: un sitio que te pide o al que le mandas (se le marca en el mapa). No hables de otros sitios.",
		_list(_turn["sites"], func(p): return "%s, a unos %d m" % [_site_text(p), _meters(npc, Vector2i(p["x"], p["y"]))], "ninguno"),
		"«reaccion»: ninguna (lo normal); enfadarse (si te insulta, te amenaza o te roba: ya no le hablas más); llamar_a_la_policia (solo si te ataca o amenaza en serio; que a él le busque la policía NO es motivo, entre los de la calle no os chiváis); despedirse.",
		"«dice»: lo que dices en voz alta, de una a tres frases cortas, con tu forma de hablar, sin narrar lo que haces ni emojis. Tiene que cuadrar con lo que has elegido: si ofreces algo, propónselo; si cuentas o señalas algo, dilo.",
		"",
		"Ejemplo (con otros datos): «¿Hay algo de curro?» → {\"ofrece\": \"o2\", \"cuenta\": \"\", \"senala\": \"\", \"reaccion\": \"ninguna\", \"dice\": \"Pues mira, vigílame la esquina una hora y algo te caerá.\"}",
		"Ejemplo: «¿Qué tal?» → {\"ofrece\": \"\", \"cuenta\": \"\", \"senala\": \"\", \"reaccion\": \"ninguna\", \"dice\": \"Aquí, tirando. ¿Y tú qué?\"}",
	])
