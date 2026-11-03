class_name Misiones
extends RefCounted
## Misiones de los personajes del editor (fase 2 del diseñador de personajes). Cada personaje
## guarda las suyas en "misiones" (ver Personajes y nueva()): cuándo la ofrece (condiciones),
## qué hay que hacer (objetivo, con los mismos encargos y minijuegos que ya hay), en cuánto
## tiempo (plazo) y qué pasa al cumplirla o al fallarla (efectos).
##
## En la partida, una misión aceptada es un encargo más (GameState.errands, con la clave
## "mision"): se apunta en la libreta (y se apunta mal igual), vence con su plazo, ancla a
## quien te la dio en el censo y lleva la «★». Errands le pasa a esta clase lo que es propio
## de las misiones: cumplirla, fallarla y lo que se lee en la libreta.
##
## Lo que queda de cada misión, los favores y lo que debes a cada personaje está en
## GameState.misiones, GameState.favores y GameState.debe_a (por id de personaje).

const G := preload("res://scripts/game_state.gd")

## Qué hay que hacer. `campos` = lo que se rellena en el editor (ver nueva()); `con` = con quién
## se cumple: "lugar" (en el menú de un sitio del mapa), "objetivo" (en el menú del otro
## personaje) o "quien" (en el menú del que te la da).
const OBJETIVOS := {
	"llevar_lugar": {"label": "Llevar algo a un sitio", "con": "lugar",
		"campos": ["objeto", "lo_da", "lugar"]},
	"llevar_personaje": {"label": "Llevarle algo a otro personaje", "con": "objetivo",
		"campos": ["objeto", "lo_da", "personaje"]},
	"traer": {"label": "Conseguirle algo", "con": "quien", "campos": ["objeto"]},
	"cita": {"label": "Estar en un sitio mañana a una hora", "con": "lugar",
		"campos": ["lugar", "desde", "hasta"]},
	"convencer": {"label": "Convencer a otro personaje", "con": "objetivo",
		"campos": ["personaje", "prueba", "dificultad"]},
	"robar": {"label": "Robarle la cartera a otro personaje (minijuego)", "con": "objetivo",
		"campos": ["personaje", "dificultad"]},
	"vigilar": {"label": "Hacerle de vigía (minijuego)", "con": "quien",
		"campos": ["minutos", "dificultad"]},
	"pelear": {"label": "Darle una lección a otro personaje (minijuego)", "con": "objetivo",
		"campos": ["personaje"]},
}
## Lo que puede pasar al cumplir o al fallar. `valor` = lleva una cifra (con su texto);
## `quien` = a qué personaje le toca ("" en la misión = al que te la da); `que` = qué objeto,
## qué favor o por qué delito.
const EFECTOS := {
	"dinero": {"label": "Dinero", "valor": "€"},
	"objeto": {"label": "Te da un objeto", "valor": "unidades", "que": "objeto"},
	"deuda": {"label": "Le debes dinero (12 h para pagar)", "valor": "€", "quien": true},
	"deuda_ya": {"label": "Le debes y viene a cobrar ya", "valor": "€", "quien": true},
	"saldar": {"label": "Saldas lo que le debes", "quien": true},
	"favor": {"label": "Te hace un favor", "valor": "días (0 = siempre)", "que": "favor", "quien": true},
	"amigo": {"label": "Se acuerda de que le ayudaste", "quien": true},
	"enemigo": {"label": "No vuelve a tratar contigo", "quien": true},
	"dignidad": {"label": "Dignidad", "valor": "puntos"},
	"mente": {"label": "Salud mental", "valor": "puntos"},
	"salud": {"label": "Salud", "valor": "puntos"},
	"busqueda": {"label": "Búsqueda policial (− discreción)", "valor": "puntos"},
	"fichado": {"label": "Te fichan un día", "que": "delito"},
}
## Favores que te puede hacer un personaje (efecto "favor").
const FAVORES := {
	"curar": "Te cura las heridas (una vez al día)",
	"soplo": "Te cuenta por dónde anda la policía",
	"vista_gorda": "(Policía) Hace la vista gorda: no te persigue, no te multa, no te despierta",
}
## Delitos por los que te pueden fichar (efecto "fichado"; ver Defs.CRIME_CORPS).
const DELITOS := {"civismo": "Civismo (Urbana)", "hurto": "Hurto (los dos)",
	"violencia": "Violencia (Mossos)", "drogas": "Drogas (Mossos)"}
## Tipos de sitio del mapa a los que puede mandarte una misión (Interactions.POI_LABELS).
const LUGARES := ["bar", "compraventa", "super", "farmacia", "kebab", "cajero", "iglesia",
	"albergue", "cap", "cas", "comisaria", "banco"]
const CURAR_SALUD := 25.0  ## lo que te cura quien te hace ese favor
const CURAR_HASTA := 90.0  ## por encima de esta salud no hace falta que te cure
const CONVENCER_DIGNIDAD := 0.004  ## lo que suma a colar una mentira cada punto de dignidad sobre 50
const CONVENCER_MENTE := 0.003  ## ... y cada punto de salud mental sobre 50

var world: World


func _init(p_world: World) -> void:
	world = p_world


# ------------------------------------------------------------------- formato

## Plantilla de una misión nueva (el formato está en Personajes, que no depende del juego).
static func nueva() -> Dictionary:
	return Personajes.nueva_mision()


## Un efecto nuevo del tipo `tipo`.
static func efecto(tipo := "dinero") -> Dictionary:
	return Personajes.nuevo_efecto(tipo)


## Clave de una misión en GameState.misiones y en las condiciones "tras": "personaje/misión".
static func clave(pid: String, m: Dictionary) -> String:
	return pid + "/" + m["id"]


## Lo que hay que hacer, en pocas palabras (para el editor, la libreta y el menú).
## `nombres` = {id de personaje: nombre}; `donde` = el sitio, si ya se sabe cuál; `horas` = con
## las horas de la cita (en la libreta van aparte, que se pueden apuntar mal).
static func resumen(m: Dictionary, nombres: Dictionary, donde := "", horas := true) -> String:
	var o: Dictionary = m["objetivo"]
	var obj := Defs.item_name(o["objeto"]).to_lower()
	var quien: String = nombres.get(o["personaje"], o["personaje"] if o["personaje"] != "" else "¿?")
	var sitio := donde if donde != "" else "un %s" % Interactions.POI_LABELS.get(o["lugar"], o["lugar"]).to_lower()
	match o["tipo"]:
		"llevar_lugar": return "llevar a %s: %s" % [sitio, obj]
		"llevar_personaje": return "llevarle a %s: %s" % [quien, obj]
		"traer": return "conseguirle: %s" % obj
		"cita":
			if not horas:
				return "estar en %s" % sitio
			return "estar en %s mañana de %02d:00 a %02d:00" % [sitio, o["desde"], o["hasta"]]
		"convencer":
			if o["prueba"] != "":
				return "convencer a %s (con %s, o mintiendo)" % [quien, Defs.item_name(o["prueba"]).to_lower()]
			return "convencer a %s" % quien
		"robar": return "robarle la cartera a %s" % quien
		"vigilar": return "hacerle de vigía (%d min)" % o["minutos"]
		"pelear": return "darle una lección a %s" % quien
	return o["tipo"]


## Lo que está mal o falta en las misiones del personaje `d`: [[es_error, texto], ...].
## `ids` = ids de los personajes guardados (para avisar de los que no existen).
static func comprobar(d: Dictionary, ids: Array) -> Array:
	var out := []
	var vistos := {}
	for m in d.get("misiones", []):
		var t: String = m["titulo"] if m["titulo"] != "" else "(sin título)"
		if m["titulo"].strip_edges() == "":
			out.append([true, "Hay una misión sin título."])
		elif vistos.has(m["id"]):
			out.append([true, "Dos misiones con el mismo título («%s»)." % t])
		vistos[m["id"]] = true
		var o: Dictionary = m["objetivo"]
		var campos: Array = OBJETIVOS.get(o["tipo"], {}).get("campos", [])
		if "personaje" in campos:
			if o["personaje"] == "":
				out.append([true, "Misión «%s»: falta el personaje del objetivo." % t])
			elif o["personaje"] == d["id"]:
				out.append([true, "Misión «%s»: el objetivo es el mismo personaje que la da." % t])
			elif not o["personaje"] in ids:
				out.append([false, "Misión «%s»: el personaje «%s» no está guardado." % [t, o["personaje"]]])
		if "objeto" in campos and o["objeto"] == "":
			out.append([true, "Misión «%s»: falta el objeto." % t])
		if o["tipo"] == "cita" and o["desde"] >= o["hasta"]:
			out.append([true, "Misión «%s»: la cita tiene que acabar después de empezar." % t])
		if m["exito"]["efectos"].is_empty() and m["exito"]["texto"].strip_edges() == "":
			out.append([false, "Misión «%s»: al cumplirla no pasa nada." % t])
		if m["fallo"]["efectos"].is_empty() and m["plazo"] > 0.0:
			out.append([false, "Misión «%s»: fallarla no tiene consecuencias." % t])
		for lado in ["exito", "fallo"]:
			for ef in m[lado]["efectos"]:
				var quien: String = ef["quien"]
				if quien != "" and quien != d["id"] and not quien in ids:
					out.append([false, "Misión «%s»: el personaje «%s» de un resultado no está guardado." % [t, quien]])
				if EFECTOS.get(ef["tipo"], {}).has("que") and ef["que"] == "":
					out.append([true, "Misión «%s»: a un resultado le falta qué (objeto, favor o delito)." % t])
	return out


# ------------------------------------------------------------------- estado

## Si el personaje `pid` te hace ahora el favor `que` (ver FAVORES).
static func favor(pid: String, que: String) -> bool:
	if pid == "":
		return false
	var f: Dictionary = GameState.favores.get(pid, {})
	return f.has(que) and GameState.now() < f[que]


## Lo que le debes al personaje `pid` (no a los camellos: eso va en Npc.debt).
static func debes(pid: String) -> int:
	return GameState.debe_a.get(pid, 0)


## La ficha del personaje `pid`, o {}.
func ficha(pid: String) -> Dictionary:
	for d in world._personajes:
		if d["id"] == pid:
			return d
	return {}


func nombres() -> Dictionary:
	var out := {}
	for d in world._personajes:
		out[d["id"]] = d["nombre"]
	return out


## El cuerpo del personaje `pid`; si está latente y `despertar`, se lo da donde le toca estar.
func npc_de(pid: String, despertar := true) -> Npc:
	if pid == "" or world.censo == null:
		return null
	for r in world.censo.registros:
		if r["personaje"].get("id", "") != pid:
			continue
		var npc = r["npc"]
		if npc != null and is_instance_valid(npc):
			return npc
		return world.censo.despertar(r) if despertar else null
	return null


## Lo que debes a los personajes al empezar (stats "le_debes" del editor).
func preparar() -> void:
	for d in world._personajes:
		var n: int = int(d["stats"].get("le_debes", 0))
		if n > 0 and not GameState.debe_a.has(d["id"]):
			GameState.debe_a[d["id"]] = n


## Las misiones en marcha (encargos con la clave "mision").
func activas() -> Array:
	return GameState.errands.filter(func(e): return e["state"] == "activo" and e.has("mision"))


## Si `m` (de `npc`) se le puede ofrecer ahora.
func disponible(npc: Npc, m: Dictionary) -> bool:
	var gs := GameState
	var pid: String = npc.personaje.get("id", "")
	var key := clave(pid, m)
	if npc.has_meta("enemigo") or activas().any(func(e): return e["key"] == key):
		return false
	var c: Dictionary = m["condiciones"]
	var antes: Dictionary = gs.misiones.get(key, {})
	if not antes.is_empty() and (not c["repetible"] or antes["dia"] == gs.day):
		return false
	if not Personajes._entre(gs.hour(), c["desde"], c["hasta"]) or gs.day < c["dia"]:
		return false
	if c["tras"] != "" and gs.misiones.get(c["tras"], {}).get("estado", "") != "hecho":
		return false
	return gs.dignity >= c["dignidad"]


# ------------------------------------------------------------------- en el menú

## Acciones con un personaje del editor: misiones que ofrece, lo que se cumple con él, los
## favores que te hace y pagarle lo que le debes.
func for_npc(npc: Npc) -> Array:
	var acts := []
	var pid: String = npc.personaje.get("id", "")
	if pid == "":
		return acts
	var gs := GameState
	for e in activas():
		acts.append_array(_cumplir_con(npc, pid, e))
	if not npc.has_meta("enemigo"):
		for m in npc.personaje.get("misiones", []):
			if disponible(npc, m):
				var plan := _plan(m)
				if not plan.is_empty():
					var mision: Dictionary = m
					acts.append(Interactions._act("Misión «%s»: %s" % [m["titulo"], _oferta(m, plan)], func(): aceptar(npc, mision, plan)))
	var deuda := debes(pid)
	if deuda > 0 and gs.money > 0:
		acts.append(Interactions._act("Pagarle lo que le debes (%d €)" % deuda, func(): _pagar(npc, pid)))
	if favor(pid, "curar") and gs.health < CURAR_HASTA and gs.favores[pid].get("curar_dia", -1) != gs.day:
		acts.append(Interactions._act("Que te cure las heridas", func():
			gs.favores[pid]["curar_dia"] = gs.day
			gs.advance(20)
			gs.change_health(CURAR_SALUD)
			npc.say("Quieto, que escuece.", 3.0)
			gs.log_msg("%s te limpia las heridas y te venda como en el hospital." % npc.display_name, G.C_GOOD)
			gs.change_dignity(1, "Alguien te cuida")))
	if favor(pid, "soplo"):
		acts.append(Interactions._act("Preguntarle qué ha visto", func():
			gs.advance(10)
			npc.say("Yo veo muchas cosas desde aquí...", 3.0)
			var lines: Array = world.conversation._police_data(npc, true)
			gs.log_msg("%s: %s" % [npc.display_name, " ".join(lines)])))
	return acts


## Icono sobre `npc`: "★" si tiene que ver con una misión en marcha (te la dio o es su
## objetivo), "!" si te puede dar una ahora, "" si nada.
func marker_for(npc: Npc) -> String:
	var pid: String = npc.personaje.get("id", "")
	if pid == "":
		return ""
	for e in activas():
		if is_same(e["giver"], npc) or e["key"].begins_with(pid + "/") or e["mision"]["objetivo"]["personaje"] == pid:
			return "★"
	if npc.has_meta("enemigo"):
		return ""
	for m in npc.personaje.get("misiones", []):
		if disponible(npc, m):
			return "!"
	return ""


func _oferta(m: Dictionary, plan: Dictionary) -> String:
	var gs := GameState
	var donde := world.errands.place_name(plan["poi"]) if not plan["poi"].is_empty() else ""
	var text := resumen(m, nombres(), donde)
	if m["objetivo"]["tipo"] != "cita" and plan["until"] < INF:
		text += " antes de las %s" % gs.time_text(plan["until"])
	return text


## Sitio y horas de una misión nueva, o {} si el mapa no tiene dónde.
func _plan(m: Dictionary) -> Dictionary:
	var o: Dictionary = m["objetivo"]
	var gs := GameState
	var poi := {}
	if OBJETIVOS[o["tipo"]]["con"] == "lugar":
		poi = world.errands._pick_place(o["lugar"])
		if poi.is_empty():
			return {}
	if o["tipo"] == "cita":
		var tomorrow := gs.day * 1440.0
		return {"poi": poi, "from": tomorrow + o["desde"] * 60.0, "until": tomorrow + o["hasta"] * 60.0}
	var until := INF
	if m["plazo"] > 0.0:
		until = ceilf((gs.now() + m["plazo"] * 60.0) / 5.0) * 5.0
	return {"poi": poi, "from": gs.now(), "until": until}


func aceptar(npc: Npc, m: Dictionary, plan: Dictionary) -> void:
	var gs := GameState
	var pid: String = npc.personaje["id"]
	var e := {"id": "mision", "mision": m, "key": clave(pid, m), "giver": npc, "who": npc.display_name,
		"poi": plan["poi"], "from": plan["from"], "until": plan["until"], "state": "activo"}
	gs.errands.append(e)
	var o: Dictionary = m["objetivo"]
	if o["tipo"] in ["llevar_lugar", "llevar_personaje"] and o["lo_da"]:
		gs.add_item(o["objeto"])
	if m["dice"] != "":
		npc.say(m["dice"], 6.0)
		gs.log_msg("%s: «%s»" % [npc.display_name, m["dice"]])
	world.errands.jot(e)
	if not plan["poi"].is_empty():
		world.highlight_poi(plan["poi"])
	gs.log_msg("Apuntas la misión «%s» en la libreta (L)." % m["titulo"])


## Lo que se hace con `npc` para cumplir la misión en marcha `e`, si es con él.
func _cumplir_con(npc: Npc, pid: String, e: Dictionary) -> Array:
	var gs := GameState
	var m: Dictionary = e["mision"]
	var o: Dictionary = m["objetivo"]
	var de := " (misión de %s)" % e["who"]
	var con: String = OBJETIVOS[o["tipo"]]["con"]
	if con == "quien" and not is_same(e["giver"], npc) and not e["key"].begins_with(pid + "/"):
		return []
	if con == "objetivo" and o["personaje"] != pid:
		return []
	if con == "lugar":
		return []
	match o["tipo"]:
		"llevar_personaje", "traer":
			if not gs.has_item(o["objeto"]):
				return []
			return [Interactions._act("Darle: %s%s" % [Defs.item_name(o["objeto"]).to_lower(), de], func(): cumplir(e))]
		"convencer":
			var acts := []
			if o["prueba"] != "" and gs.has_item(o["prueba"]):
				acts.append(Interactions._act("Convencerle: enseñarle %s%s" % [Defs.item_name(o["prueba"]).to_lower(), de], func():
					gs.advance(15)
					cumplir(e)))
			var lie := "Convencerle sin pruebas (mentir)" if o["prueba"] != "" else "Convencerle"
			acts.append(Interactions._act(lie + de, func(): _convencer(npc, e)))
			return acts
		"robar":
			var ints := world.interactions
			return [Interactions._act("Robarle la cartera" + de, func():
				ints._pickpocket(npc, "cartera", ints._pickpocket_chance(1.0 - o["dificultad"]), func():
					cumplir(e),
				func():
					ints._caught_stealing(npc, "¡Eh! ¡Al ladrón!")
					fallar(e)))]
		"vigilar":
			var ints := world.interactions
			return [Interactions._act("Hacerle de vigía (%d min)%s" % [o["minutos"], de], func():
				ints._lookout(npc, o["minutos"], 1.0 - o["dificultad"], func(_share: float, tips: int):
					gs.add_money(tips)
					cumplir(e),
				func():
					ints._heat(40)
					gs.log_msg("¡Viene la policía y no la has visto venir!", G.C_BAD)
					fallar(e)))]
		"pelear":
			return [Interactions._act("Darle una lección" + de, func(): _pelear(npc, e))]
	return []


## Convencer sin pruebas: cuela según la dificultad, tu dignidad y tu cabeza. Si no cuela, se
## da cuenta de que le mientes: no vuelve a tratar contigo y, si es policía, te ficha.
func _convencer(npc: Npc, e: Dictionary) -> void:
	var gs := GameState
	gs.advance(15)
	var p := 1.0 - float(e["mision"]["objetivo"]["dificultad"])
	p += (gs.dignity - 50.0) * CONVENCER_DIGNIDAD + (gs.sanity - 50.0) * CONVENCER_MENTE
	if randf() < clampf(p, 0.05, 0.95):
		cumplir(e)
	else:
		mentira_pillada(npc, e)


func mentira_pillada(npc: Npc, e: Dictionary) -> void:
	var gs := GameState
	npc.say("¿Me tomas por tonta? Esto no cuela." if npc.gender == "f" else "¿Me tomas por tonto? Esto no cuela.", 4.0)
	gs.log_msg("%s no se lo traga." % npc.display_name, G.C_BAD)
	if npc.is_police():
		npc.reveal()
		gs.mark_wanted("%s te ha pillado mintiendo" % npc.display_name, "civismo")
	else:
		npc.set_meta("enemigo", true)
	fallar(e)


## Darle una lección a `npc` (minijuego Fight): si ganas, cumplida; si no, te la llevas tú.
func _pelear(npc: Npc, e: Dictionary) -> void:
	var gs := GameState
	var ints := world.interactions
	gs.advance(10)
	ints._heat(30)
	npc.remember("pegado")
	if world.police_watching() > 0:
		gs.mark_wanted("un agente te ha visto pelearte", "violencia")
	world.play_minigame(Fight.new(npc), ints._fight_chance(npc), func(result: String, _stats: Dictionary):
		if result == "ok":
			npc.say("¡Vale, vale! ¡Ya lo he entendido!", 3.0)
			gs.change_health(-randf_range(3, 10), "Una pelea de más")
			cumplir(e)
		else:
			gs.change_health(-randf_range(10, 20), "Perder una pelea")
			gs.log_msg("%s te tumba. La lección te la llevas tú." % npc.display_name, G.C_BAD)
			fallar(e))


func _pagar(npc: Npc, pid: String) -> void:
	var gs := GameState
	var paid := mini(gs.money, debes(pid))
	gs.add_money(-paid)
	gs.debe_a[pid] = debes(pid) - paid
	if debes(pid) <= 0:
		gs.debe_a.erase(pid)
		npc.remember("ayudado")
		npc.say("Así me gusta. Estamos en paz.", 3.0)
		gs.log_msg("Le pagas a %s lo que le debías (%d €)." % [npc.display_name, paid], G.C_GOOD)
		gs.change_dignity(2, "Pagar lo que debes")
	else:
		gs.log_msg("Le das %d € a %s. Aún le debes %d €." % [paid, npc.display_name, debes(pid)])


# ------------------------------------------------------------------- resolver

## Misión cumplida (Errands.complete la manda aquí cuando se cumple en un sitio).
func cumplir(e: Dictionary) -> void:
	if e["state"] != "activo":
		return
	var gs := GameState
	var m: Dictionary = e["mision"]
	var o: Dictionary = m["objetivo"]
	e["state"] = "hecho"
	if o["tipo"] in ["llevar_lugar", "llevar_personaje", "traer"]:
		gs.remove_item(o["objeto"])
	gs.advance(45 if o["tipo"] == "cita" else 5)
	gs.misiones[e["key"]] = {"estado": "hecho", "dia": gs.day}
	gs.log_msg("Misión cumplida: «%s»." % m["titulo"], G.C_GOOD)
	if m["exito"]["texto"] != "":
		gs.log_msg(m["exito"]["texto"], G.C_GOOD)
	aplicar(m["exito"]["efectos"], e)


## Misión fallada: se pasó el plazo, se perdió el minijuego o no coló la mentira.
func fallar(e: Dictionary) -> void:
	if e["state"] != "activo":
		return
	var gs := GameState
	var m: Dictionary = e["mision"]
	e["state"] = "fallado"
	gs.misiones[e["key"]] = {"estado": "fallado", "dia": gs.day}
	gs.log_msg("Misión fallada: «%s»." % m["titulo"], G.C_BAD)
	if m["fallo"]["texto"] != "":
		gs.log_msg(m["fallo"]["texto"], G.C_BAD)
	aplicar(m["fallo"]["efectos"], e)


## Aplica los efectos de una misión. Los que son con un personaje ("quien" vacío = el que te la
## dio) le dan cuerpo si está latente, para que venga a cobrar o se acuerde de verdad.
func aplicar(efectos: Array, e: Dictionary) -> void:
	var gs := GameState
	var m: Dictionary = e["mision"]
	var giver_pid: String = e["key"].get_slice("/", 0)
	for ef in efectos:
		var pid: String = ef["quien"] if ef["quien"] != "" else giver_pid
		var valor := int(ef["valor"])
		match ef["tipo"]:
			"dinero":
				gs.add_money(valor)
			"objeto":
				gs.add_item(ef["que"], maxi(1, valor))
			"deuda", "deuda_ya":
				var npc := _npc_efecto(pid, e)
				if npc != null and npc.kind == "camello":
					npc.add_debt(valor, 0.0 if ef["tipo"] == "deuda_ya" else Defs.DEBT_GRACE_HOURS)
					gs.debt += valor
					gs.milestone("deuda")
				else:
					gs.debe_a[pid] = debes(pid) + valor
				gs.log_msg("Le debes %d € a %s." % [valor, _nombre(pid)], G.C_BAD)
			"saldar":
				gs.debe_a.erase(pid)
				var npc := _npc_efecto(pid, e)
				if npc != null and npc.debt > 0:
					gs.debt = maxi(0, gs.debt - npc.debt)
					npc.debt = 0
			"favor":
				if not gs.favores.has(pid):
					gs.favores[pid] = {}
				gs.favores[pid][ef["que"]] = gs.now() + valor * 1440.0 if valor > 0 else INF
				gs.log_msg("%s: %s." % [_nombre(pid), FAVORES.get(ef["que"], ef["que"]).to_lower()], G.C_GOOD)
			"amigo":
				var npc := _npc_efecto(pid, e)
				if npc != null:
					npc.remove_meta("enemigo")
					npc.remember("ayudado")
			"enemigo":
				var npc := _npc_efecto(pid, e)
				if npc != null:
					npc.set_meta("enemigo", true)
			"dignidad":
				gs.change_dignity(valor, m["titulo"])
			"mente":
				gs.change_sanity(valor, m["titulo"])
			"salud":
				gs.change_health(valor, m["titulo"])
			"busqueda":
				gs.heat = clampf(gs.heat + valor, 0.0, 100.0)
			"fichado":
				gs.mark_wanted("«%s»" % m["titulo"], ef["que"] if Defs.CRIME_CORPS.has(ef["que"]) else "civismo")


## El cuerpo del personaje `pid` para un efecto: el que te dio la misión, si es él.
func _npc_efecto(pid: String, e: Dictionary) -> Npc:
	var giver = e["giver"]
	if is_instance_valid(giver) and giver.personaje.get("id", "") == pid:
		return giver
	return npc_de(pid)


func _nombre(pid: String) -> String:
	return ficha(pid).get("nombre", pid)


## El paquete de una misión que llevas encima (para abrirlo: World.use_item), o {}.
func con_objeto(id: String) -> Dictionary:
	for e in activas():
		var o: Dictionary = e["mision"]["objetivo"]
		if o["tipo"] in ["llevar_lugar", "llevar_personaje"] and o["objeto"] == id:
			return e
	return {}


# ------------------------------------------------------------------- libreta y sitios

## Lo que se apunta en la libreta de una misión, sin el sitio ni la hora (ver Errands.note_text).
## Si es con otro personaje, dónde suele estar (los lugares de su rutina).
func que_apuntar(e: Dictionary, donde: String) -> String:
	var m: Dictionary = e["mision"]
	var text := "«%s», %s" % [m["titulo"], resumen(m, nombres(), donde, false)]
	var pid: String = m["objetivo"]["personaje"]
	if OBJETIVOS[m["objetivo"]["tipo"]]["con"] == "objetivo" and pid != "":
		var sitios := []
		for l in ficha(pid).get("lugares", []):
			if l.get("nota", "") != "":
				sitios.append("%s de %d a %d h" % [l["nota"], l["desde"], l["hasta"]])
		if not sitios.is_empty():
			text += " (suele estar: %s)" % ", ".join(sitios)
	return text


## Lo que se hace en el sitio `poi` para la misión `e` (llevar algo o la cita).
func actions_for_poi(e: Dictionary) -> Array:
	var gs := GameState
	var m: Dictionary = e["mision"]
	var o: Dictionary = m["objetivo"]
	if o["tipo"] == "llevar_lugar":
		if not gs.has_item(o["objeto"]):
			return []
		return [Interactions._act("Dejar aquí: %s (misión de %s)" % [Defs.item_name(o["objeto"]).to_lower(), e["who"]], func(): cumplir(e))]
	if gs.now() < e["from"]:
		return [Interactions._act("Esperar a la cita de %s (hasta las %s)" % [e["who"], gs.time_text(e["from"])], func():
			gs.advance(e["from"] - gs.now())
			if e["state"] == "activo" and gs.alive:
				cumplir(e))]
	return [Interactions._act("Tu cita «%s» (misión de %s)" % [m["titulo"], e["who"]], func(): cumplir(e))]
