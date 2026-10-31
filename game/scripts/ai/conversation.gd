class_name Conversation
extends Node
## Conversación libre con los bots que tienen ficha (ver fichas.gd): arma el contexto
## (quién es, qué sabe, la hora, la policía y los sitios de alrededor, cómo te ve), lleva
## la memoria corta de lo hablado con cada uno y convierte las acciones que devuelve el
## modelo en cosas que pasan en la partida: pistas, sitios marcados, tratos, regalos,
## enfados y llamadas a la policía.

const G := preload("res://scripts/game_state.gd")

## La respuesta, para la interfaz: lo que dice, los tratos que propone (para aceptarlos o no)
## y si da la conversación por terminada.
signal replied(npc: Npc, text: String, deals: Array, ended: bool)
signal failed(npc: Npc, error: String)

const MAX_MESSAGES := 12  ## Frases de la memoria corta con cada personaje (las más antiguas se olvidan)
const MAX_FACTS := 8  ## Hechos que recuerda (tratos, pistas, enfados...)
const MINUTES_PER_LINE := 2.0  ## Lo que pasa el reloj por cada frase
const POLICE_RADIUS := 60  ## Casillas a las que ve a los agentes
const MAX_DEAL_MINUTES := 180
const POLICE_HEAT := 50.0  ## Lo que sube la búsqueda si te echa a la policía encima

## Formato de la respuesta que se le exige al modelo: primero lo que dice, luego el trato
## (siempre presente, con texto vacío si no propone ninguno) y luego las demás acciones.
## Probado con qwen2.5:7b: si el trato es una acción opcional más, lo ofrece de palabra y no
## lo apunta; si las acciones van antes de lo que dice, se las inventa y pierde el hilo.
const SCHEMA := {
	"type": "object",
	"properties": {
		"dice": {"type": "string"},
		"trato": {
			"type": "object",
			"properties": {
				"texto": {"type": "string"},
				"euros_para_el": {"type": "integer"},
				"euros_para_ti": {"type": "integer"},
				"objeto": {"type": "string"},
				"minutos": {"type": "integer"},
			},
			"required": ["texto", "euros_para_el", "euros_para_ti", "objeto", "minutos"],
		},
		"acciones": {"type": "array", "items": {
			"type": "object",
			"properties": {
				"tipo": {"type": "string", "enum": ["dar_pista", "marcar_sitio", "regalar", "enfadarse", "llamar_a_la_policia_contra_el", "despedirse"]},
				"texto": {"type": "string"},
				"sitio": {"type": "string"},
				"objeto": {"type": "string"},
			},
			"required": ["tipo"],
		}},
	},
	"required": ["dice", "trato", "acciones"],
}
const NO_DEAL := {"texto": "", "euros_para_el": 0, "euros_para_ti": 0, "objeto": "", "minutos": 0}

var world: World
var client: LlmClient
var busy := false
## "tipo|nombre" -> {"messages": [{"role", "content"}], "facts": [String]}. Si vuelve a salir
## alguien con el mismo nombre, se acuerda de ti.
var _memory := {}
var _sites := {}  ## id ("s1"...) -> lugar, de la última vez que se armó el contexto
var _warned := false  ## Solo se avisa una vez en el registro de que la IA no responde


func _init(p_world: World) -> void:
	world = p_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	client = LlmClient.new()
	add_child(client)


static func can_talk(npc: Npc) -> bool:
	return Fichas.has(npc.kind) and not npc.has_meta("enemigo")


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
			out.append(["el", _parse(m["content"]).get("dice", "")])
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
	client.ask(messages, SCHEMA, func(ok: bool, content: String):
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


## Aplica la respuesta del modelo (JSON con "dice" y "acciones") y avisa a la interfaz.
## Devuelve lo mismo que manda por `replied`: {"text", "deals", "ended"}.
func handle_reply(npc: Npc, content: String) -> Dictionary:
	var data := _parse(content)
	var text: String = data.get("dice", "").strip_edges().left(500)
	var mem := _mem(npc)
	mem["messages"].append({"role": "assistant", "content": JSON.stringify({"dice": text, "trato": data["trato"], "acciones": data["acciones"]})})
	while mem["messages"].size() > MAX_MESSAGES:
		mem["messages"].pop_front()
	GameState.advance(MINUTES_PER_LINE)
	if text != "":
		npc.say(text.left(80), 4.0)
	var deals := []
	var ended := false
	var offered := _deal(npc, data["trato"])
	if not offered.is_empty():
		deals.append(offered)
	for a in data.get("acciones", []):
		if not a is Dictionary:
			continue
		match a.get("tipo", ""):
			"dar_pista":
				var clue: String = str(a.get("texto", "")).strip_edges()
				if clue != "":
					GameState.log_msg("Pista de %s: %s" % [npc.display_name, clue], G.C_GOOD)
					_fact(npc, "Le diste esta pista: " + clue)
			"marcar_sitio":
				var poi: Dictionary = _sites.get(str(a.get("sitio", "")), {})
				if not poi.is_empty():
					world.highlight_poi(poi)
					GameState.log_msg("%s te señala %s." % [npc.display_name, _site_text(poi)], G.C_GOOD)
					_fact(npc, "Le señalaste " + _site_text(poi))
			"regalar":
				var item := str(a.get("objeto", ""))
				if item in Fichas.of(npc.kind)["puede_dar"] and npc.get_meta("regalo_dia", -1) != GameState.day:
					npc.set_meta("regalo_dia", GameState.day)
					GameState.add_item(item)
					GameState.log_msg("%s te da: %s." % [npc.display_name, Defs.item_name(item)], G.C_GOOD)
					_fact(npc, "Le regalaste " + Defs.item_name(item))
			"enfadarse":
				npc.set_meta("enemigo", true)
				GameState.log_msg("%s no quiere saber nada más de ti." % npc.display_name, G.C_BAD)
				GameState.change_dignity(-2, "Ganarte un enemigo")
				ended = true
			"llamar_a_la_policia_contra_el":
				npc.set_meta("enemigo", true)
				npc.say("¡Policía! ¡Este de aquí!", 4.0)
				GameState.heat = minf(100.0, GameState.heat + POLICE_HEAT)
				GameState.log_msg("%s te echa a la policía encima." % npc.display_name, G.C_BAD)
				ended = true
			"despedirse":
				ended = true
	replied.emit(npc, text, deals, ended)
	return {"text": text, "deals": deals, "ended": ended}


## Un trato propuesto por el modelo, con las cifras dentro de lo que permite su ficha
## (vacío si no propone ninguno).
func _deal(npc: Npc, a: Dictionary) -> Dictionary:
	var f := Fichas.of(npc.kind)
	var item := str(a.get("objeto", ""))
	var deal := {
		"text": str(a.get("texto", "")).strip_edges().left(160).trim_suffix("."),
		"pays": clampi(int(a.get("euros_para_el", 0)), 0, mini(f["max_pago"], npc.money)),
		"costs": clampi(int(a.get("euros_para_ti", 0)), 0, 100),
		"item": item if item in f["puede_dar"] else "",
		"minutes": clampi(int(a.get("minutos", 0)), 0, MAX_DEAL_MINUTES),
	}
	if deal["text"] == "" or (deal["pays"] == 0 and deal["costs"] == 0 and deal["item"] == "" and deal["minutes"] == 0):
		return {}
	return deal


## Texto del botón de un trato.
static func deal_label(deal: Dictionary) -> String:
	var parts := []
	if deal["minutes"] > 0:
		parts.append("%d min" % deal["minutes"])
	if deal["costs"] > 0:
		parts.append("pagas %d €" % deal["costs"])
	if deal["pays"] > 0:
		parts.append("te da %d €" % deal["pays"])
	if deal["item"] != "":
		parts.append("te da %s" % Defs.item_name(deal["item"]).to_lower())
	return "Aceptar: %s (%s)" % [deal["text"], ", ".join(parts)]


## El jugador acepta un trato: se cumple al momento y queda en la memoria del personaje.
func accept_deal(npc: Npc, deal: Dictionary) -> bool:
	var gs := GameState
	if gs.money < deal["costs"]:
		gs.log_msg("No te llega para ese trato.", G.C_BAD)
		return false
	var f := Fichas.of(npc.kind)
	gs.add_money(-deal["costs"])
	var pays := mini(deal["pays"], npc.money)
	npc.money -= pays
	gs.add_money(pays)
	if deal["item"] != "":
		gs.add_item(deal["item"])
	if deal["minutes"] > 0:
		gs.advance(deal["minutes"])
		gs.heat = minf(100.0, gs.heat + f["trato_calor"] * deal["minutes"] / 60.0)
		if f["trato_dignidad"] != 0.0:
			gs.change_dignity(f["trato_dignidad"], "Un trato con %s" % npc.display_name.to_lower())
	gs.log_msg("Trato con %s: %s." % [npc.display_name, deal["text"]], G.C_GOOD)
	_fact(npc, "Aceptó tu trato: %s" % deal_label(deal).trim_prefix("Aceptar: "))
	return true


func _fact(npc: Npc, text: String) -> void:
	var facts: Array = _mem(npc)["facts"]
	facts.append("Día %d, %s: %s" % [GameState.day, GameState.clock_text().get_slice(" ", 0), text])
	while facts.size() > MAX_FACTS:
		facts.pop_front()


static func _parse(content: String) -> Dictionary:
	var json := JSON.new()  # (JSON.parse_string llena la consola de errores si no es JSON)
	var data = json.data if json.parse(content) == OK else null
	if data is Dictionary:
		if not data.get("acciones", []) is Array:
			data["acciones"] = []
		if not data.get("trato") is Dictionary:
			data["trato"] = NO_DEAL
		data["dice"] = str(data.get("dice", ""))
		return data
	# un modelo que no respeta el formato: se toma el texto tal cual
	return {"dice": content.strip_edges(), "trato": NO_DEAL, "acciones": []}


# ------------------------------------------------------------------ contexto

func _site_text(poi: Dictionary) -> String:
	var name: String = Interactions.POI_LABELS.get(poi["kind"], poi["kind"])
	if poi.get("name", "") != "":
		name += " «%s»" % poi["name"]
	return "%s en %s" % [name, world.city.street_name_near(Vector2i(poi["x"], poi["y"]))]


## El más cercano de cada tipo de sitio, con un id para que el modelo pueda marcarlo.
func _nearby_sites(npc: Npc) -> String:
	_sites = {}
	var lines := []
	for kind in Fichas.SITE_KINDS:
		var best: Dictionary = {}
		var best_d := INF
		for p in world.city.pois_of_kind(kind):
			var d := npc.distance_to_cell(Vector2i(p["x"], p["y"]))
			if d < best_d:
				best_d = d
				best = p
		if best.is_empty():
			continue
		var id := "s%d" % (_sites.size() + 1)
		_sites[id] = best
		lines.append("- %s: %s, a unos %d m" % [id, _site_text(best), int(best_d * world.city.cell_m)])
	return "\n".join(lines)


func _police_text(npc: Npc) -> String:
	var lines := []
	for n in world.npcs:
		if n.kind == "policia" and n.distance_to_cell(npc.cell) <= POLICE_RADIUS:
			lines.append("un agente por %s (a unos %d m)" % [world.city.street_name_near(n.cell), int(n.distance_to_cell(npc.cell) * world.city.cell_m)])
	if lines.is_empty():
		return "No ves a ningún agente cerca."
	return "Policía a la vista: " + "; ".join(lines) + "."


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


func system_prompt(npc: Npc) -> String:
	var f := Fichas.of(npc.kind)
	var bio: String = npc.bio() if npc.bio() != "" else f["historia"]
	var facts: Array = _mem(npc)["facts"]
	var gives: Array = f["puede_dar"]
	var gives_text := ", ".join(gives) if not gives.is_empty() else "nada (deja objeto vacío)"
	return "\n".join([
		"Eres %s, %s en el Raval de Barcelona, dentro de un videojuego. Hablas con otro del barrio, un yonki (el jugador)." % [npc.display_name, Npc.KINDS[npc.kind]["label"].to_lower()],
		"Responde SIEMPRE con un objeto JSON: {\"dice\": \"...\", \"trato\": {...}, \"acciones\": [...]}. «dice» es lo que dices en voz alta: de una a tres frases cortas, con tu forma de hablar, sin narrar lo que haces, sin emojis. No rompas nunca el personaje ni digas que eres una IA.",
		"",
		"QUIÉN ERES: " + f["quien"],
		"TU HISTORIA: " + bio,
		"CÓMO HABLAS: " + f["habla"],
		"QUÉ SABES: " + f["sabe"],
		"QUÉ NO SABES: " + f["no_sabe"] + " No te inventes calles ni sitios: usa solo los de la lista.",
		"QUÉ QUIERES: " + f["quiere"],
		"TRATOS QUE PUEDES PROPONER: " + f["tratos"],
		"",
		"AHORA: son las %s del día %d y estás en %s. %s" % [GameState.clock_text().get_slice(" ", 0), GameState.day, world.city.street_name_near(npc.cell), _police_text(npc)],
		"LLEVAS ENCIMA: %d €." % npc.money,
		"SITIOS CERCANOS (usa su id para señalarlos):",
		_nearby_sites(npc),
		"EL JUGADOR: " + _player_text(),
		"LO QUE YA HA PASADO ENTRE VOSOTROS: " + ("\n- ".join([""] + facts) if not facts.is_empty() else "nada, no le conoces de antes."),
		"",
		"TRATO: si en «dice» propones un trato concreto (un trabajo, un intercambio, dinero o latas por algo), o aceptas el que te propone él, ponlo en «trato» con sus cifras; él podrá aceptarlo o no. Si no, deja texto vacío y todo a 0.",
		"  texto = qué propones, en pocas palabras; euros_para_el = euros que le das tú a él (máximo %d); euros_para_ti = euros que él te tiene que dar a ti; objeto = lo que le das (%s); minutos = lo que dura el trabajo." % [f["max_pago"], gives_text],
		"",
		"ACCIONES: lo normal es una charla sin acciones (\"acciones\": []). Usa una solo cuando lo que dices la hace ocurrir de verdad, nunca por rellenar:",
		"- {\"tipo\": \"dar_pista\", \"texto\": \"...\"}: le das un dato útil y concreto (dónde está la policía, dónde esconderse, dónde sacar algo). Solo si te lo pregunta o te cae bien; no para contar cómo estás.",
		"- {\"tipo\": \"marcar_sitio\", \"sitio\": \"s3\"}: le dices dónde está un sitio de la lista y se le marca en el mapa (solo uno).",
		"- {\"tipo\": \"regalar\", \"objeto\": \"...\"}: le das algo gratis (%s). Solo si te cae muy bien." % gives_text,
		"- {\"tipo\": \"enfadarse\"}: te enfadas y no vuelves a hablarle. Si te insulta, te amenaza o te ha robado.",
		"- {\"tipo\": \"llamar_a_la_policia_contra_el\"}: llamas a gritos a la policía para que lo detengan. Solo si te ataca o te amenaza en serio. Que la policía le busque a él NO es motivo: entre los de la calle no os chiváis.",
		"- {\"tipo\": \"despedirse\"}: das la conversación por terminada.",
		"",
		"EJEMPLOS (con otros datos; SIN_TRATO = {\"texto\": \"\", \"euros_para_el\": 0, \"euros_para_ti\": 0, \"objeto\": \"\", \"minutos\": 0}):",
		"«Hola, ¿qué tal?» → {\"dice\": \"Aquí, tirando. ¿Y tú?\", \"trato\": SIN_TRATO, \"acciones\": []}",
		"«¿Viene la Urbana?» → {\"dice\": \"Hay uno por Carrer X. Tú ve por la otra punta.\", \"trato\": SIN_TRATO, \"acciones\": [{\"tipo\": \"dar_pista\", \"texto\": \"Hay un agente por Carrer X\"}]}",
		"«¿Dónde hay un súper?» → {\"dice\": \"Ahí, en Carrer Y, a dos minutos.\", \"trato\": SIN_TRATO, \"acciones\": [{\"tipo\": \"marcar_sitio\", \"sitio\": \"s2\"}]}",
		"«Necesito pasta» → {\"dice\": \"Vigílame esto una hora y te doy cinco.\", \"trato\": {\"texto\": \"Vigilar una hora\", \"euros_para_el\": 5, \"euros_para_ti\": 0, \"objeto\": \"\", \"minutos\": 60}, \"acciones\": []}",
		"«Te enseño un atajo por tres euros» → {\"dice\": \"Vale, pero rápido.\", \"trato\": {\"texto\": \"Enseñarme el atajo\", \"euros_para_el\": 3, \"euros_para_ti\": 0, \"objeto\": \"\", \"minutos\": 15}, \"acciones\": []}",
		"«¿Me vendes una lata?» → {\"dice\": \"Un euro, amigo.\", \"trato\": {\"texto\": \"Una lata\", \"euros_para_el\": 0, \"euros_para_ti\": 1, \"objeto\": \"litrona\", \"minutos\": 0}, \"acciones\": []}",
		"«Te voy a robar» → {\"dice\": \"¿Qué dices? Lárgate de aquí.\", \"trato\": SIN_TRATO, \"acciones\": [{\"tipo\": \"enfadarse\"}]}",
	])
