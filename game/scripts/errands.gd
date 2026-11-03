class_name Errands
extends RefCounted
## Encargos con plazo de los personajes y la libreta en la que los apuntas.
##
## El juego decide qué encargos hay, dónde (un lugar real del mapa) y hasta cuándo; los
## personajes solo los ofrecen en su menú y se cumplen en el menú del lugar. Los plazos se
## pisan entre sí y los sitios se eligen lejos unos de otros, para obligar a elegir.
## La libreta es fiable casi siempre, pero según lo ido que vas (GameState.befuddlement())
## a veces apuntas mal un dato al aceptar el encargo, se te borra con las horas o no lo lees.
## El equilibrio está en Defs.ERRANDS; el estado, en GameState.errands y GameState.notes.
## Las misiones de los personajes del editor también son encargos (con la clave "mision"):
## lo que tienen de propio lo resuelve Misiones.

const G := preload("res://scripts/game_state.gd")

## Lo que se apunta de cada encargo: qué hay que hacer y la preposición del sitio.
const WHAT := {
	"paquete": "llevar el paquete a",
	"cartera": "dejar la cartera caliente en",
	"juerga": "llevar a la despedida de fiesta a",
	"cita": "cita en",
	"receta": "recoger la receta en",
	"camino": "llevar al turista a",
	"compra": "hacer la compra en",
}
## Cómo se puede apuntar mal un dato: sin sitio, sin hora, otra hora u otro sitio.
const SLIPS := ["sin_sitio", "sin_hora", "otra_hora", "otro_sitio"]

var world: World
var _last_hour := -1


func _init(p_world: World) -> void:
	world = p_world


## El encargo `id` que tienes en marcha, o {} si no hay.
func active(id: String) -> Dictionary:
	for e in GameState.errands:
		if e["id"] == id and e["state"] == "activo":
			return e
	return {}


# ------------------------------------------------------------------- ofrecer

## Encargos que ofrece `npc` en su menú: uno por tipo a la vez y uno por personaje y día.
func offers_for(npc: Npc) -> Array:
	var acts := []
	for id in Defs.ERRANDS:
		var d: Dictionary = Defs.ERRANDS[id]
		if d["giver"] != npc.kind or not active(id).is_empty() or npc.has_meta("enemigo") or not _asks(npc, id):
			continue
		if npc.get_meta("encargo_dia", -1) == GameState.day:
			continue
		var plan := _plan(id)
		if plan.is_empty():
			continue
		acts.append(Interactions._act("Encargo: " + _offer_text(id, plan), func(): accept(npc, id, plan)))
	return acts


## Si `npc` es de los de su tipo que piden el encargo `id` (Defs.ERRANDS[id]["share"]).
func _asks(npc: Npc, id: String) -> bool:
	return npc._trait("encargo") < Defs.ERRANDS[id].get("share", 1.0)


## Sitio y horas de un encargo nuevo, o {} si el mapa no tiene dónde.
func _plan(id: String) -> Dictionary:
	var d: Dictionary = Defs.ERRANDS[id]
	var poi := _pick_place(d["place"])
	if poi.is_empty():
		return {}
	var from: float
	var until: float
	if d.has("at"):
		var tomorrow := GameState.day * 1440.0  # medianoche de hoy, en minutos de now()
		from = tomorrow + d["at"][0] * 60.0
		until = tomorrow + d["at"][1] * 60.0
	else:
		var now := GameState.now()
		from = now + d["window"][0] * 60.0
		until = now + d["window"][1] * 60.0
		# horas redondas de cinco en cinco, como las diría cualquiera
		if d["window"][0] > 0.0:
			from = ceilf(from / 5.0) * 5.0
		until = ceilf(until / 5.0) * 5.0
	return {"poi": poi, "from": from, "until": until}


## Un lugar con nombre del tipo `kind`, ni muy cerca ni muy lejos de ti y lo más lejos posible
## de los demás encargos que tienes en marcha (así se pisan). El CAS es siempre el Baluard.
func _pick_place(kind: String) -> Dictionary:
	var all := world.city.pois_of_kind(kind)
	if kind == "cas":
		return all[0] if not all.is_empty() else {}
	var named := all.filter(func(p):
		# con nombre, y que quepa en el cartel para que se lea desde la calle
		return p["name"] != "" and (not kind in PoiMarker.NAMED_KINDS or p["name"].length() <= 16))
	if named.is_empty():
		return {}
	var me := world.player.cell
	var in_reach := named.filter(func(p):
		var dist := _dist(_cell(p), me)
		return dist >= Defs.ERRAND_MIN_DISTANCE and dist <= Defs.ERRAND_MAX_DISTANCE)
	if not in_reach.is_empty():
		named = in_reach
	var taken := []
	for e in GameState.errands:
		if e["state"] == "activo" and not e["poi"].is_empty():
			taken.append(_cell(e["poi"]))
	var best: Dictionary = {}
	var best_score := -INF
	for p in named:
		var score := randf() * 60.0
		if not taken.is_empty():
			score += taken.map(func(c): return _dist(_cell(p), c)).min()
		if score > best_score:
			best_score = score
			best = p
	return best


func accept(npc: Npc, id: String, plan: Dictionary) -> void:
	var gs := GameState
	var e := {"id": id, "giver": npc, "who": npc.display_name, "poi": plan["poi"],
		"from": plan["from"], "until": plan["until"], "state": "activo"}
	gs.errands.append(e)
	npc.set_meta("encargo_dia", gs.day)
	match id:
		"paquete":
			gs.add_item("paquete")
			npc.say("Al %s antes de las %s. Y ni se te ocurra abrirlo" % [place_name(e["poi"]), gs.time_text(e["until"])], 5.0)
		"cartera":
			gs.add_item("cartera_caliente")
			npc.say("Llévala a %s antes de las %s. Pregunta por el de atrás" % [place_name(e["poi"]), gs.time_text(e["until"])], 5.0)
		"juerga":
			npc.say("Bro! A las %s en el %s, ¿vale? ¡Tú eres el guía!" % [gs.time_text(e["from"]), place_name(e["poi"])], 5.0)
		"cita":
			npc.say("Mañana a las %s en el Baluard. Te espero, ¿eh?" % gs.time_text(e["from"]).left(5), 5.0)
		"receta":
			npc.say("Ay, hijo, que no llego. La receta está a mi nombre en %s" % place_name(e["poi"]), 5.0)
		"camino":
			npc.say("%s? Yes, yes, please, I follow you!" % place_name(e["poi"]), 5.0)
		"compra":
			gs.add_money(Defs.ERRANDS["compra"]["advance"])
			npc.say("Toma %d €: pan, leche y fruta del %s. Y me traes el cambio, ¿eh?" % [Defs.ERRANDS["compra"]["advance"], place_name(e["poi"])], 5.0)
	jot(e)
	world.highlight_poi(e["poi"])
	gs.log_msg("Apuntas el encargo de %s en la libreta (L)." % e["who"])


func _offer_text(id: String, plan: Dictionary) -> String:
	var d: Dictionary = Defs.ERRANDS[id]
	var gs := GameState
	var where := place_name(plan["poi"])
	match id:
		"paquete":
			return "llevar un paquete al %s antes de las %s (%d € y una raya)" % [where, gs.time_text(plan["until"]), d["money"]]
		"cartera":
			return "dejar una cartera caliente en %s antes de las %s (%d €)" % [where, gs.time_text(plan["until"]), d["money"]]
		"juerga":
			return "llevarlos de fiesta al %s, de %s a %s (%d €)" % [where, gs.time_text(plan["from"]), gs.time_text(plan["until"]), d["money"]]
		"receta":
			return "recogerle la receta en %s antes de las %s (%d €)" % [where, gs.time_text(plan["until"]), d["money"]]
		"camino":
			return "llevarle a %s, que se ha perdido, antes de las %s (propina)" % [where, gs.time_text(plan["until"])]
		"compra":
			return "hacerle la compra en %s antes de las %s (te da %d € para ella)" % [where, gs.time_text(plan["until"]), d["advance"]]
		"cita":
			return "cita mañana en el CAS Baluard de %s a %s por lo del albergue" % [
				gs.time_text(plan["from"]).left(5), gs.time_text(plan["until"]).left(5)]
	return id


## Icono sobre `npc` para encontrarlo: "★" si te ha dado un encargo que tienes en marcha,
## "!" si te puede dar uno ahora, "" si nada. Los disfrazados no se delatan hasta que les hablas.
func marker_for(npc: Npc) -> String:
	for e in GameState.errands:
		if e["state"] == "activo" and is_same(e["giver"], npc):
			return "★"
	var mision := world.misiones.marker_for(npc)
	if mision != "":
		return mision
	if npc.has_meta("enemigo") or npc.get_meta("encargo_dia", -1) == GameState.day:
		return ""
	if not npc.known and Npc.KINDS[npc.kind].has("disguise"):
		return ""
	for id in Defs.ERRANDS:
		if Defs.ERRANDS[id]["giver"] == npc.kind and active(id).is_empty() and _asks(npc, id):
			return "!"
	return ""


## Notas de la libreta de los encargos en marcha que tienen sitio apuntado. Las flechas
## del HUD llevan a ese sitio: si lo apuntaste mal, te llevan al sitio equivocado.
func noted_places() -> Array:
	return GameState.notes.filter(func(n): return n["errand"]["state"] == "activo" and not n["poi"].is_empty())


## Nombre de un lugar para los textos: el suyo, o el tipo de sitio y la calle.
func place_name(poi: Dictionary) -> String:
	if poi.get("kind") == "cas":
		return "CAS Baluard"
	if poi["name"] != "":
		return poi["name"]
	return "%s de %s" % [Interactions.POI_LABELS.get(poi["kind"], poi["kind"]), world.city.street_name_near(_cell(poi))]


# ------------------------------------------------------------------- cumplir

## Acciones en el menú de un lugar para los encargos que se cumplen ahí.
func actions_for_poi(poi: Dictionary) -> Array:
	var acts := []
	var gs := GameState
	for e in gs.errands:
		if e["state"] != "activo" or e["poi"].is_empty() or _cell(e["poi"]) != _cell(poi):
			continue
		if e.has("mision"):
			acts.append_array(world.misiones.actions_for_poi(e))
			continue
		if (e["id"] == "paquete" and not gs.has_item("paquete")) or (e["id"] == "cartera" and not gs.has_item("cartera_caliente")):
			continue
		if e["id"] == "compra" and gs.money < Defs.ERRANDS["compra"]["advance"]:
			continue  # el dinero de la compra ya no lo tienes
		var errand: Dictionary = e
		if gs.now() < e["from"]:
			acts.append(Interactions._act("Esperar a %s (hasta las %s)" % [e["who"], gs.time_text(e["from"])], func():
				gs.advance(errand["from"] - gs.now())
				if errand["state"] == "activo" and gs.alive:
					complete(errand)))
		else:
			acts.append(Interactions._act(_deliver_label(e), func(): complete(errand)))
	return acts


func _deliver_label(e: Dictionary) -> String:
	match e["id"]:
		"paquete": return "Entregar el paquete de %s" % e["who"]
		"cartera": return "Dejar la cartera de %s" % e["who"]
		"juerga": return "Llevar a la despedida de %s de fiesta (1 h)" % e["who"]
		"cita": return "Tu cita con %s" % e["who"]
		"receta": return "Recoger la receta de %s" % e["who"]
		"camino": return "Dejar al turista (%s) en la puerta" % e["who"]
		"compra": return "Hacer la compra de %s" % e["who"]
	return e["id"]


func complete(e: Dictionary) -> void:
	if e.has("mision"):
		world.misiones.cumplir(e)
		return
	var gs := GameState
	var d: Dictionary = Defs.ERRANDS[e["id"]]
	e["state"] = "hecho"
	match e["id"]:
		"paquete":
			gs.advance(5)
			gs.remove_item("paquete")
			gs.add_money(d["money"])
			gs.add_item("farlopa")
			gs.log_msg("El del %s coge el paquete sin mirarte. %d € y una raya de propina." % [place_name(e["poi"]), d["money"]], G.C_GOOD)
		"cartera":
			gs.advance(5)
			gs.remove_item("cartera_caliente")
			gs.add_money(d["money"])
			gs.log_msg("El del mostrador la mete en un cajón sin preguntar. %d €." % d["money"], G.C_GOOD)
		"juerga":
			gs.advance(60)
			gs.add_money(d["money"])
			gs.add_item("litrona")
			gs.change_sanity(3)
			gs.log_msg("Les enseñas el Raval «auténtico». Te sueltan %d € y una lata." % d["money"], G.C_GOOD)
			gs.change_dignity(-2, "Hacer de guía a una despedida")
			gs.milestone("despedida")
		"cita":
			gs.advance(45)
			gs.ease_mono(d["mono"])
			gs.change_sanity(d["sanity"])
			gs.add_item("bocadillo")
			gs.add_item("papeles_albergue")
			gs.log_msg("%s te estaba esperando. Café, papeles para el albergue y un bocadillo para luego." % e["who"], G.C_GOOD)
			gs.change_dignity(d["dignity"], "Alguien cuenta contigo")
		"receta", "camino", "compra":
			gs.advance(15)
			if e["id"] == "compra":
				gs.add_money(-d["advance"])
			var tip: int = d["money"] if e["id"] != "camino" else randi_range(2, d["money"])
			gs.add_money(tip)
			gs.change_dignity(d["dignity"], "Hacer un favor")
			_remember_giver(e, "ayudado")
			match e["id"]:
				"receta": gs.log_msg("La farmacéutica te da la bolsa de %s. Se la dejas en el portal: %d € y un «Dios te lo pague»." % [e["who"], tip], G.C_GOOD)
				"camino": gs.log_msg("%s hace una foto a la iglesia y te da %d € de propina." % [e["who"], tip], G.C_GOOD)
				"compra": gs.log_msg("Le subes la compra a %s. Te da %d € por las molestias." % [e["who"], tip], G.C_GOOD)


## Abrir el paquete del camello: dos rayas para ti y una deuda más gorda. Si es el de una
## misión, la misión se da por fallada.
func open_package() -> void:
	var gs := GameState
	if not gs.has_item("paquete"):
		return
	gs.remove_item("paquete")
	gs.add_item("farlopa", 2)
	gs.milestone("paquete")
	var e := active("paquete")
	if e.is_empty():
		e = world.misiones.con_objeto("paquete")
		if not e.is_empty():
			gs.log_msg("Dentro hay dos rayas. %s se va a enterar." % e["who"], G.C_BAD)
			world.misiones.fallar(e)
			return
	if e.is_empty():
		gs.log_msg("Dentro hay dos rayas. Ya no lo espera nadie... o eso crees.", G.C_GOOD)
	else:
		gs.log_msg("Dentro hay dos rayas. %s se va a enterar." % e["who"], G.C_BAD)
		_fail(e, true)


## Vence los plazos y, cada hora de juego, deja que se borre algún dato de la libreta.
## Se llama en cada frame desde World.
func update() -> void:
	var gs := GameState
	var now := gs.now()
	for e in gs.errands:
		if e["state"] == "activo" and now > e["until"]:
			_fail(e)
	var h := int(now / 60.0)
	if h != _last_hour:
		if _last_hour >= 0:
			_forget_tick()
		_last_hour = h


func _fail(e: Dictionary, opened := false) -> void:
	if e.has("mision"):
		world.misiones.fallar(e)
		return
	var gs := GameState
	var d: Dictionary = Defs.ERRANDS[e["id"]]
	var giver = e["giver"]
	var npc: Npc = giver if is_instance_valid(giver) else null
	e["state"] = "fallado"
	match e["id"]:
		"paquete":
			var debt: int = d["debt_opened"] if opened else d["debt"]
			gs.debt += debt
			if npc:
				npc.add_debt(debt, 0.0)  # ya va tarde: viene a cobrar en cuanto te vea
			gs.heat = minf(100.0, gs.heat + d["heat"])
			if not opened:
				gs.log_msg("Se te ha pasado la hora del paquete. %s dice que ahora le debes %d €." % [e["who"], debt], G.C_BAD)
			else:
				gs.log_msg("%s ya sabe que el paquete no ha llegado. Le debes %d €." % [e["who"], debt], G.C_BAD)
			gs.milestone("deuda")
		"cartera":
			gs.heat = minf(100.0, gs.heat + d["heat"])
			if npc:
				npc.set_meta("enemigo", true)
			gs.log_msg("No has dejado la cartera a tiempo. %s le da tu descripción a la Urbana. (−discreción)" % e["who"], G.C_BAD)
		"juerga":
			gs.log_msg("La despedida de %s se ha ido de fiesta sin ti." % e["who"])
		"cita":
			gs.log_msg("%s te esperó una hora en el Baluard." % e["who"], G.C_BAD)
			gs.change_sanity(d["sanity_fail"])
			gs.change_dignity(d["dignity_fail"], "Dejar plantada a quien te ayuda")
		"receta":
			gs.log_msg("%s se ha quedado sin sus pastillas." % e["who"], G.C_BAD)
			gs.change_dignity(d["dignity_fail"], "Dejar tirada a una abuela")
		"camino":
			gs.log_msg("El turista (%s) se ha cansado de esperarte." % e["who"])
		"compra":
			# te quedaste los 20 €: no se le olvida
			_remember_giver(e, "timado")
			gs.log_msg("%s se ha quedado sin compra y tú con sus %d €." % [e["who"], d["advance"]], G.C_BAD)
			gs.change_dignity(d["dignity_fail"], "Quedarte el dinero de la compra de una vecina")


## Que quien te dio el encargo se acuerde de `what` («ayudado», «timado»...), si sigue por ahí.
func _remember_giver(e: Dictionary, what: String) -> void:
	var giver = e["giver"]
	if is_instance_valid(giver):
		giver.remember(what)


# ------------------------------------------------------------------- libreta

## Apunta un encargo en la libreta. Casi siempre bien; ido, a veces mal (ver slip()).
func jot(e: Dictionary) -> Dictionary:
	var note := {"errand": e, "poi": e["poi"], "from": e["from"], "until": e["until"], "slip": ""}
	if randf() < Defs.SLIP_BASE + Defs.SLIP_PER_BEFUDDLEMENT * GameState.befuddlement():
		slip(note, _slip_kind())
	GameState.notes.append(note)
	return note


## Qué tipo de error toca según lo que llevas encima: con caballo, pastillas o sueño se te
## escapan datos; con farlopa, base o la cabeza mal los apuntas cambiados sin darte cuenta.
func _slip_kind() -> String:
	var gs := GameState
	var lose := gs.intensity("caballo") + gs.intensity("pastillas") + maxf(0.0, (gs.fatigue - 70.0) / 30.0)
	var alter := gs.intensity("farlopa") + gs.intensity("base") + maxf(0.0, (40.0 - gs.sanity) / 40.0)
	if lose + alter <= 0.0:
		return SLIPS.pick_random()
	if randf() * (lose + alter) < lose:
		return ["sin_sitio", "sin_hora"].pick_random()
	return ["otra_hora", "otro_sitio"].pick_random()


## Estropea un dato de una nota. `kind` es uno de SLIPS.
func slip(note: Dictionary, kind: String) -> void:
	match kind:
		"sin_sitio":
			note["poi"] = {}
		"sin_hora":
			note["from"] = -1.0
			note["until"] = -1.0
		"otra_hora":
			if note["until"] < 0.0:
				return
			var shift: float = [-90.0, -60.0, -30.0, 30.0, 60.0, 90.0].pick_random()
			note["from"] += shift
			note["until"] += shift
		"otro_sitio":
			if note["poi"].is_empty():
				return
			var real: Dictionary = note["poi"]
			var others := world.city.pois_of_kind(real["kind"]).filter(func(p):
				return p["name"] != "" and p["name"] != real["name"] and _dist(_cell(p), _cell(real)) > 40)
			if others.is_empty():
				slip(note, "otra_hora")
				return
			note["poi"] = others.pick_random()
	note["slip"] = kind


## Cada hora, ido, puede borrarse algún dato de lo que tienes apuntado (la tinta se corre,
## la página se moja...).
func _forget_tick() -> void:
	var b := GameState.befuddlement()
	if b <= 0.0:
		return
	for note in GameState.notes:
		if note["errand"]["state"] == "activo" and randf() < Defs.FORGET_PER_HOUR * b:
			slip(note, ["sin_sitio", "sin_hora"].pick_random())


## Texto de una nota tal como la apuntaste (sin el emborronado de la lectura).
func note_text(note: Dictionary) -> String:
	var gs := GameState
	var e: Dictionary = note["errand"]
	var where := "¿?" if note["poi"].is_empty() else place_name(note["poi"])
	if not note["poi"].is_empty() and note["poi"].get("kind") != "cas":
		where += " (%s)" % world.city.street_name_near(_cell(note["poi"]))
	var when := "¿?"
	if e.has("mision"):
		var donde := "" if note["poi"].is_empty() else where
		if note["poi"].is_empty() and Misiones.OBJETIVOS[e["mision"]["objetivo"]["tipo"]]["con"] == "lugar":
			donde = "¿?"
		if note["until"] == INF:
			when = "sin prisa"
		elif note["until"] >= 0.0:
			when = "antes de las %s" % gs.time_text(note["until"])
			if e["mision"]["objetivo"]["tipo"] == "cita":
				when = "de %s a %s" % [gs.time_text(note["from"]), gs.time_text(note["until"])]
		return "%s: %s, %s." % [e["who"], world.misiones.que_apuntar(e, donde), when]
	if note["until"] >= 0.0:
		var d: Dictionary = Defs.ERRANDS[e["id"]]
		if d.has("window") and d["window"][0] == 0.0:
			when = "antes de las %s" % gs.time_text(note["until"])
		else:
			var from := gs.time_text(note["from"])
			var until := gs.time_text(note["until"])
			if from.length() > 5 and from.substr(5) == until.substr(5):  # el mismo día, que no es hoy
				from = from.left(5)
			when = "de %s a %s" % [from, until]
	return "%s: %s %s, %s." % [e["who"], WHAT[e["id"]], where, when]


## Lo que se lee ahora en la libreta, de lo más nuevo a lo más viejo: [{"text": bbcode, "poi"}]
## (`poi` = el sitio apuntado, para buscarlo en el mapa, o {}). Lo apuntado puede estar mal
## desde el principio; además, ido, hay palabras que no se leen (borrosas o temblando).
func notebook_entries() -> Array:
	var gs := GameState
	var b := gs.befuddlement()
	var amount := clampf((b - Defs.BLUR_FROM) / (1.0 - Defs.BLUR_FROM), 0.0, 1.0) * Defs.BLUR_MAX
	var mono_share := clampf(maxf(0.0, (gs.mono - 50.0) / 100.0) / maxf(b, 0.01), 0.0, 1.0)
	var hour_seed := int(gs.now() / 60.0)  # la misma lectura durante una hora
	var entries := []
	for i in range(gs.notes.size() - 1, -1, -1):
		var note: Dictionary = gs.notes[i]
		var state: String = note["errand"]["state"]
		var text := garble(note_text(note), amount, mono_share, hash([hour_seed, i]))
		if state == "hecho":
			text = "[color=#80a080][s]%s[/s] hecho[/color]" % text
		elif state == "fallado":
			text = "[color=#a08080][s]%s[/s] se te pasó[/color]" % text
		entries.append({"text": text, "poi": note["poi"] if state == "activo" else {}})
	return entries


## Emborrona `text` para leerlo ido: una proporción `amount` de palabras sale borrosa o, en la
## parte `tremble` (el mono), temblando y con letras cambiadas. Devuelve BBCode.
## Con la misma `seed` sale lo mismo, para que la libreta no parpadee.
static func garble(text: String, amount: float, tremble: float, seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var words := text.split(" ")
	for i in words.size():
		var w := words[i]
		if amount > 0.0 and rng.randf() < amount:
			if rng.randf() < tremble:
				if w.length() > 3:
					var k := rng.randi_range(1, w.length() - 3)
					w = w.substr(0, k) + w[k + 1] + w[k] + w.substr(k + 2)
				w = "[shake rate=18 level=6]%s[/shake]" % w.replace("[", "[lb]")
			else:
				w = "[color=#ffffff22]%s[/color]" % w.replace("[", "[lb]")
		else:
			w = w.replace("[", "[lb]")
		words[i] = w
	return " ".join(words)


static func _cell(poi: Dictionary) -> Vector2i:
	return Vector2i(poi["x"], poi["y"])


static func _dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()
