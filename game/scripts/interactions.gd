class_name Interactions
extends RefCounted
## Acciones disponibles con cada bot y en cada lugar del barrio.
## Cada acción es {"label": String, "do": Callable}; el menú las muestra tal cual.
## Cada bot se acuerda de lo que le haces (Npc.remember): pedirle, robarle, ayudarle o pegarle
## cambia cómo reacciona cuando te vuelve a ver. Un robo visto acaba en escándalo (World.scandal).

const G := preload("res://scripts/game_state.gd")

var world: World


func _init(p_world: World) -> void:
	world = p_world


static func _act(label: String, fn: Callable) -> Dictionary:
	return {"label": label, "do": fn}


func _chance(p: float) -> bool:
	return randf() < clampf(p, 0.02, 0.95)


func _beg_bonus() -> float:
	return 0.25 if GameState.profile.get("id") == "jubilado" else 0.0


## Sube la búsqueda policial (al jubilado le cuesta más parecer sospechoso).
func _heat(amount: float) -> void:
	if GameState.profile.get("id") == "jubilado":
		amount *= 0.5
	GameState.heat = minf(100.0, GameState.heat + amount)


## Un robo a `victim` que ha salido bien. Si lo ha visto un agente, va a por ti; si lo ha
## visto otro, grita y se monta el escándalo; si no, la víctima quizá se da cuenta al rato
## y se queda con tu cara.
func _after_theft(victim: Npc) -> void:
	if world.police_watching() > 0:
		victim.remember("robado")
		_heat(60)
		GameState.log_msg("Un agente lo ha visto todo.", G.C_BAD)
		return
	var seen := world.robbery_witnesses(victim)
	if not seen.is_empty():
		victim.remember("robado")
		world.scandal(seen[0], ["¡Eh! ¡Ese le ha robado!", "¡Al ladrón!"].pick_random())
	elif _chance(0.4):
		victim.remember("robado")


## Te han pillado robando a `victim`: se acuerda de ti y grita `text`.
func _caught_stealing(victim: Npc, text: String) -> void:
	victim.remember("robado")
	world.scandal(victim, text)


# --------------------------------------------------------------------- bots

func for_npc(npc: Npc) -> Array:
	var acts: Array = []
	match npc.kind:
		"turista": acts = _turista(npc)
		"camello": acts = _camello(npc)
		"policia": acts = _policia(npc)
		"yonki": acts = _yonki(npc)
		"educador": acts = _educador(npc)
		"vecino": acts = _vecino(npc)
		"mantero": acts = _mantero(npc)
		"fiestero": acts = _fiestero(npc)
		"latero": acts = _latero(npc)
		"trilero": acts = _trilero(npc)
		"carterista": acts = _carterista(npc)
		"chaval": acts = _chaval(npc)
		"nino": acts = _nino(npc)
		"anciano": acts = _anciano(npc)
		"perro": acts = _perro(npc)
		"mensajero": acts = _mensajero(npc)
		"pudiente": acts = _pudiente(npc)
	acts.append_array(world.trade.offers_for(npc))
	acts.append_array(world.errands.offers_for(npc))
	if npc.bio() != "":
		acts.append(_act("Escuchar su historia", func():
			GameState.advance(15)
			GameState.log_msg("%s: %s" % [npc.display_name, npc.bio()])
			GameState.change_sanity(1)))
	if Conversation.can_talk(npc):
		acts.insert(0, _act("Hablar", func(): world.open_chat(npc)))
	return acts


func _turista(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle una moneda", func():
			gs.advance(10)
			npc.remember("pedido")
			if not npc.robbed and _chance(0.35 + _beg_bonus()):
				var n := randi_range(1, 5)
				gs.add_money(n)
				npc.say("Here... take it")
				gs.log_msg("El guiri te da %d €." % n, G.C_GOOD)
			else:
				npc.say("No, sorry, no cash")
			gs.change_dignity(-2, "Pedir a un guiri")),
		_act("Contarle tu drama", func():
			gs.advance(20)
			npc.remember("pedido")
			npc.say("Oh my god...")
			if _chance(0.25 + _beg_bonus()):
				var n := randi_range(8, 20)
				gs.add_money(n)
				gs.log_msg("Le das tanta pena que te suelta %d €." % n, G.C_GOOD)
			gs.change_dignity(-4, "Llorarle a un desconocido")),
	]
	if not npc.robbed and not npc.has_meta("receloso"):
		acts.append(_act("Robarle la cartera", func(): _rob_tourist(npc)))
	return acts


## Probabilidad de que salga bien un robo al descuido con `base` de partida: la bajan los
## agentes que te ven y el colocón, la suben la noche y el oficio. En el minijuego es su
## dificultad; sin pantalla, la tirada.
func _pickpocket_chance(base: float) -> float:
	var gs := GameState
	var p := base - 0.2 * world.police_watching() + (0.1 if gs.is_night() else 0.0)
	if "aprendiz" in gs.milestones:
		p += 0.15  # un carterista te ha enseñado el oficio
	if gs.high > 60.0:
		p -= 0.15
	return clampf(p, 0.02, 0.95)


## Robo al descuido (minijuego Pickpocket). `on_ok` y `on_caught` hacen lo de cada víctima;
## si no hay ocasión, se queda mosca y no se deja intentar otra vez.
func _pickpocket(npc: Npc, loot: String, chance: float, on_ok: Callable, on_caught: Callable) -> void:
	world.play_minigame(Pickpocket.new(npc, loot), chance, func(result: String, _stats: Dictionary):
		_pickpocket_done(result, npc, loot, on_ok, on_caught))


func _pickpocket_done(result: String, npc: Npc, loot: String, on_ok: Callable, on_caught: Callable) -> void:
	match result:
		"ok":
			npc.robbed = true
			GameState.add_item(loot)
			on_ok.call()
			GameState.milestone("primer_robo")
			_after_theft(npc)
		"pillado":
			npc.robbed = true
			on_caught.call()
		_:
			npc.set_meta("receloso", true)
			npc.say(["Hm?", "What...?", "¿Qué pasa?"].pick_random())
			GameState.log_msg("%s se aleja mirándote raro." % npc.display_name)


## Hacer de vigía para `npc` durante `minutes` (minijuego Lookout). `chance` = que no haya
## redada. `on_ok(share, tips)` cobra: `share` (0..1) es la parte de la paga que queda tras
## las falsas alarmas y `tips`, los euros de los clientes que atraes. `on_raid` es la redada.
func _lookout(npc: Npc, minutes: float, chance: float, on_ok: Callable, on_raid: Callable) -> void:
	world.play_minigame(Lookout.new(npc), chance, func(result: String, stats: Dictionary):
		_lookout_done(result, stats, npc, minutes, on_ok, on_raid))


func _lookout_done(result: String, stats: Dictionary, npc: Npc, minutes: float, on_ok: Callable, on_raid: Callable) -> void:
	var gs := GameState
	match result:
		"ok":
			gs.advance(minutes)
			var falsas: int = stats.get("falsas", 0)
			if falsas > 0:
				gs.log_msg("%d falsas alarmas: cada vez que recoge pierde ventas." % falsas, G.C_BAD)
			on_ok.call(maxf(0.0, 1.0 - Defs.LOOKOUT_FALSE_PENALTY * falsas),
				int(stats.get("clientes", 0)) * Defs.LOOKOUT_CLIENT_TIP)
		"redada":
			gs.advance(minutes * 0.5)
			on_raid.call()
		_:
			gs.advance(15)
			npc.say("¿Ya te vas? Pues no cobras")
			gs.log_msg("Lo dejas a medias y %s no te paga." % npc.display_name)


func _rob_tourist(npc: Npc) -> void:
	var gs := GameState
	gs.advance(5)
	var loot := "movil" if randf() < 0.4 else "cartera"
	_pickpocket(npc, loot, _pickpocket_chance(0.6), func():
		if loot == "movil":
			gs.log_msg("Le sacas el móvil del bolsillo sin que se entere.", G.C_GOOD)
		else:
			gs.log_msg("¡Cartera! Ábrela en el inventario.", G.C_GOOD)
		_heat(20)
		gs.change_dignity(-3),
	func():
		_heat(70)
		_caught_stealing(npc, "THIEF! ¡Al ladrón!")
		gs.log_msg("Te ha pillado. Ahora la policía te busca.", G.C_BAD)
		gs.change_dignity(-2))


func _camello(npc: Npc) -> Array:
	var gs := GameState
	var acts := []
	if npc.debt > 0:
		npc.say("Primero me pagas lo que me debes")
		if gs.money > 0:
			acts.append(_act("Pagarle la deuda (%d €)" % npc.debt, func():
				var paid := mini(gs.money, npc.debt)
				gs.add_money(-paid)
				npc.debt -= paid
				gs.debt = maxi(0, gs.debt - paid)
				gs.log_msg("Le pagas %d €. Debes %d €." % [paid, npc.debt])))
		acts.append(_act("Hacerle de aguador (2 h) para saldar", func():
			_lookout(npc, 120, 0.85, func(share: float, tips: int):
				var off := roundi(15 * share) + tips
				npc.debt = maxi(0, npc.debt - off)
				gs.debt = maxi(0, gs.debt - off)
				_heat(15)
				gs.log_msg("Dos horas vigilando la esquina. Te descuenta %d €." % off)
				gs.change_dignity(-2),
			func():
				_heat(60)
				gs.log_msg("¡Redada! Sales corriendo con la policía detrás. Y sigues debiéndole.", G.C_BAD)
				gs.change_dignity(-2))))
		return acts
	for id in Defs.DEALER_STOCK:
		var s: Dictionary = Defs.SUBSTANCES[id]
		var price: int = s["price"]
		if gs.money >= price:
			acts.append(_act("Comprar %s (%d €)" % [s["name"], price], func():
				gs.add_money(-price)
				gs.add_item(id)
				npc.say("Va, rápido")
				gs.log_msg("Compras: %s." % s["name"])))
		elif price <= 15:
			acts.append(_act("Pedirle fiado: %s" % s["name"], func():
				if _chance(0.4):
					gs.add_item(id)
					npc.add_debt(price, Defs.DEBT_GRACE_HOURS)
					gs.debt += price
					npc.say("Mañana me lo pagas. Sé dónde duermes")
					gs.milestone("deuda")
				else:
					npc.say("Sin pasta no hay fiesta")
				gs.change_dignity(-2)))
	acts.append(_act("Hacerle de aguador (2 h)", func():
		_lookout(npc, 120, 0.85, func(share: float, tips: int):
			var got := roundi(15 * share) + tips
			_heat(15)
			gs.add_money(got)
			gs.add_item("porro")
			gs.log_msg("Te paga %d € y un porro por vigilar." % got, G.C_GOOD)
			gs.change_dignity(-2),
		func():
			_heat(75)
			gs.log_msg("¡Redada! Sales corriendo con la policía detrás.", G.C_BAD)
			gs.change_dignity(-2))))
	return acts


func _policia(npc: Npc) -> Array:
	var gs := GameState
	return [
		_act("Pedirle ayuda", func():
			gs.advance(5)
			npc.say("Pásate por el Baluard, hombre")
			gs.change_dignity(-1)),
		_act("Chivarte de un camello", func():
			npc.say("Gracias por la información")
			gs.heat = 0.0
			world.remove_random_npc("camello")
			gs.change_dignity(-10, "Chivato")
			gs.milestone("chivato")),
		_act("Insultarle", func():
			npc.say("¿Perdona? Las manos donde las vea")
			gs.change_dignity(-3)
			world.arrest_player()),
	]


func _yonki(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle algo", func():
			gs.advance(5)
			npc.remember("pedido")
			if _chance(0.2):
				gs.add_item("sobras")
				npc.say("Toma, que hoy estoy generoso")
			else:
				npc.say("Ni pa' mí, primo")
			gs.change_dignity(-2, "Pedirle a otro yonki")),
		_act("Pelearte con él", func(): _fight(npc)),
	]
	var mine := gs.inventory.keys().filter(func(id): return Defs.SUBSTANCES.has(id))
	if not mine.is_empty():
		var id: String = mine[0]
		acts.insert(0, _act("Compartir tu %s" % Defs.item_name(id).to_lower(), func():
			gs.remove_item(id)
			npc.say("Eres un hermano, tío")
			npc.set_meta("colega", true)
			npc.remember("ayudado")
			gs.change_dignity(2, "Compartir es vivir")
			if _chance(0.4):
				gs.add_money(randi_range(2, 8))
				gs.log_msg("Te devuelve el favor con unas monedas.", G.C_GOOD)))
	if gs.money >= 8:
		acts.append(_act("Comprarle un móvil robado (8 €)", func():
			gs.add_money(-8)
			gs.add_item("movil" if _chance(0.5) else "movil_roto")
			npc.say("Está como nuevo")))
	return acts


func _fight(npc: Npc) -> void:
	var gs := GameState
	gs.advance(10)
	_heat(30)
	npc.remember("pegado")
	world.play_minigame(Fight.new(npc), _fight_chance(), func(result: String, _stats: Dictionary):
		_fight_done(npc, result == "ok"))


## Probabilidad de ganar una pelea a un yonki: la salud y el colocón ayudan, el mono no.
## (La tirada de antes: tú, salud + colocón·0,3 − mono·0,3 ± 20, contra él, entre 30 y 70.)
func _fight_chance() -> float:
	var gs := GameState
	return clampf(0.5 + (gs.health + gs.high * 0.3 - gs.mono * 0.3 - 50.0) / 80.0, 0.05, 0.95)


func _fight_done(npc: Npc, won: bool) -> void:
	var gs := GameState
	if won:
		var loot := npc.money + randi_range(0, 5)
		npc.money = 0
		gs.add_money(loot)
		npc.say("¡Vale, vale, ya está!")
		gs.change_health(-randf_range(3, 10), "Una pelea de más")
		gs.log_msg("Ganas la pelea y le quitas %d €." % loot, G.C_GOOD)
		gs.change_dignity(-3)
	else:
		var lost := int(gs.money * 0.3)
		gs.add_money(-lost)
		npc.say("¡Toma ya!")
		gs.change_health(-20, "Te mató a palos un yonki")
		gs.log_msg("Te revienta y te quita %d €." % lost, G.C_BAD)
		gs.change_dignity(-6)
		gs.milestone("pelea_perdida")


func _educador(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Hablar un rato", func():
			gs.advance(30)
			npc.say("Cuídate, ¿vale?")
			gs.ease_mono(5.0)
			gs.change_sanity(5)
			gs.change_dignity(4, "Alguien te trata como a una persona")),
		_act("Preguntar dónde dan metadona", func():
			var cas := world.city.pois_of_kind("cas")
			if cas.is_empty():
				npc.say("Ve al CAP")
			else:
				var c: Dictionary = cas[0]
				npc.say("En el Baluard, cerca de %s" % world.city.street_name_near(Vector2i(c["x"], c["y"])), 5.0)
				world.highlight_poi(c)),
	]
	if npc.last_interaction_day != gs.day:
		acts.insert(0, _act("Pedirle un bocadillo", func():
			npc.last_interaction_day = gs.day
			gs.add_item("bocadillo")
			npc.say("Toma, de chorizo")
			gs.change_dignity(-1)))
	return acts


func _vecino(npc: Npc) -> Array:
	var gs := GameState
	return [
		_act("Pedirle una moneda", func():
			gs.advance(5)
			npc.remember("pedido")
			if _chance(0.1 + _beg_bonus()):
				gs.add_money(1)
				npc.say("Toma, y vete")
			else:
				npc.say(["¡Búscate un trabajo!", "¡Que llamo a la policía!", "Ay, pobre..."].pick_random())
			gs.change_dignity(-3, "Que te miren así")),
		_act("Pedirle el móvil «para llamar a tu madre»", func():
			gs.advance(5)
			if _chance(0.15):
				gs.add_item("movil")
				_heat(40)
				gs.log_msg("Sales corriendo con su móvil.", G.C_GOOD)
				gs.milestone("primer_robo")
				_caught_stealing(npc, "¡Mi móvil! ¡Policía!")
			else:
				_heat(25)
				npc.remember("pedido")
				npc.say("¡Ni se te ocurra!", 3.0)
			gs.change_dignity(-3)),
	]


func _mantero(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Hacerle de vigía (2 h)", func():
			var pay := 20 if gs.profile.get("id") == "sin_papeles" else 8
			_lookout(npc, 120, 0.9 - 0.1 * world.police_near(npc.cell, 30), func(share: float, tips: int):
				var got := roundi(pay * share) + tips
				gs.add_money(got)
				_heat(10)
				npc.remember("ayudado")
				npc.say("Gracias, hermano")
				gs.log_msg("Vigilas por si viene la policía. Te da %d €." % got, G.C_GOOD),
			func():
				_heat(25)
				npc.say("¡Corre, corre!", 3.0)
				gs.log_msg("La Urbana se lleva la manta de %s. Hoy no cobra nadie." % npc.display_name, G.C_BAD))),
	]
	if gs.money >= 5:
		acts.append(_act("Comprarle unas gafas (5 €)", func():
			gs.add_money(-5)
			gs.add_item("gafas")
			npc.say("Ray-Ban, original")))
	return acts


func _fiestero(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirles para una cerveza", func():
			gs.advance(5)
			npc.remember("pedido")
			if npc.money > 0 and _chance(0.5 + _beg_bonus()):
				var n := mini(npc.money, randi_range(2, 10))
				npc.money -= n
				gs.add_money(n)
				npc.say("¡Toma, hombre! ¡Que se casa!")
				gs.log_msg("Borrachos y generosos: %d €." % n, G.C_GOOD)
			else:
				npc.say("Bro, no tengo ni para el taxi")
			gs.change_dignity(-2, "Pedirle a una despedida")),
		_act("Unirte a la juerga (1 h)", func():
			gs.advance(60)
			gs.add_item("litrona")
			gs.consume("litrona")
			npc.remember("ayudado")
			npc.say("¡Este tío es el mejor!")
			gs.change_sanity(3)
			gs.change_dignity(-3, "Bailar con una peluca rosa")
			gs.milestone("despedida")),
	]
	if gs.has_item("gafas"):
		acts.append(_act("Venderles unas gafas de mantero (10 €)", func():
			gs.remove_item("gafas")
			gs.add_money(10)
			npc.say("Ray-Ban! Originals!")
			gs.log_msg("Les vendes las gafas por el doble de lo que te costaron.", G.C_GOOD)))
	if not npc.robbed and not npc.has_meta("receloso"):
		acts.append(_act("Robarle el móvil", func():
			gs.advance(5)
			# va tan ciego que es más fácil (y la noche ni la nota)
			_pickpocket(npc, "movil", clampf(0.75 - 0.2 * world.police_watching(), 0.02, 0.95), func():
				_heat(15)
				gs.log_msg("Va tan ciego que ni se entera.", G.C_GOOD)
				gs.change_dignity(-3),
			func():
				_heat(40)
				_caught_stealing(npc, "OI! ¡Chicos, a por él!")
				gs.change_health(-15, "Una paliza de despedida")
				gs.log_msg("Sus colegas te rodean. Te llevas una buena.", G.C_BAD)
				gs.change_dignity(-3))))
	return acts


func _latero(npc: Npc) -> Array:
	var gs := GameState
	var acts := []
	if npc.has_meta("enemigo"):
		npc.say("Tú no. Fuera.")
		return acts
	if gs.money >= 1:
		acts.append(_act("Comprarle una lata (1 €)", func():
			gs.add_money(-1)
			gs.add_item("litrona")
			npc.say("Fría, amigo")))
	acts.append(_act("Ayudarle a esconder el alijo (1 h)", func():
		gs.advance(60)
		_heat(10)
		gs.add_money(5)
		npc.set_meta("alijo", true)
		npc.remember("ayudado")
		npc.say("Gracias. Aquí no lo encuentra la Urbana")
		gs.log_msg("Bajáis las latas a una alcantarilla de %s. Te da 5 €." % world.city.street_name_near(npc.cell), G.C_GOOD)))
	if npc.has_meta("alijo"):
		acts.append(_act("Robarle el alijo de la alcantarilla", func():
			gs.advance(10)
			gs.add_item("litrona", 4)
			npc.set_meta("enemigo", true)
			npc.remember("robado")
			npc.say("¡Ladrón! ¡Eso era para mi familia!", 4.0)
			gs.log_msg("Cuatro latas. Él sabe perfectamente quién ha sido.", G.C_GOOD)
			gs.change_dignity(-6, "Robarle a uno que está peor que tú")
			gs.change_sanity(-3)))
	if world.police_near(npc.cell, 25) > 0:
		acts.append(_act("Avisarle de que viene la Urbana", func():
			npc.remember("ayudado")
			npc.say("¡Gracias, hermano! Toma, invita la casa")
			gs.add_item("litrona")
			gs.change_dignity(1, "Echar un cable")
			npc.walk_to(world.city.random_walkable_near(npc.home, 30))))
	return acts


func _trilero(npc: Npc) -> Array:
	var gs := GameState
	var acts := []
	if gs.money >= 10:
		acts.append(_act("Apostar 10 € a la bolita", func():
			gs.advance(5)
			gs.milestone("trile")
			# la bolita casi nunca está donde crees: solo «gana» el gancho
			if _chance(0.08):
				gs.add_money(10)
				npc.say("¡Suerte de principiante!")
				gs.log_msg("Ganas 10 €. Te dejan ganar para que vuelvas.", G.C_GOOD)
			else:
				gs.add_money(-10)
				npc.say("Uy, casi. ¿Otra?")
				gs.log_msg("Estabas seguro de que era la de la izquierda. Adiós, 10 €.", G.C_BAD)
			gs.change_dignity(-1)))
	acts.append(_act("Hacerle de gancho (1 h)", func():
		gs.advance(60)
		_heat(15)
		var pay := randi_range(8, 15)
		gs.add_money(pay)
		npc.remember("ayudado")
		gs.log_msg("Finges ganar una y otra vez para que piquen los guiris. %d €." % pay, G.C_GOOD)
		gs.change_dignity(-3, "Engañar a los turistas")))
	acts.append(_act("Hacerle de vigía (1 h)", func():
		_lookout(npc, 60, 0.6 if world.police_near(npc.cell, 30) > 0 else 0.95, func(share: float, tips: int):
			var got := roundi(6 * share) + tips
			gs.add_money(got)
			_heat(5)
			gs.log_msg("Una hora mirando a los dos lados de la Rambla. %d €." % got, G.C_GOOD),
		func():
			_heat(30)
			npc.say("¡Agua! ¡Recoge!", 3.0)
			gs.log_msg("No has visto venir a la Urbana. %s recoge la caja y se larga sin pagarte." % npc.display_name, G.C_BAD))))
	return acts


func _carterista(npc: Npc) -> Array:
	var gs := GameState
	if npc.has_meta("enemigo"):
		npc.say("Por tu culpa casi me pillan. Piérdete.")
		return []
	npc.say("Shhh. Tú no me has visto")
	var acts := [
		_act("Hacerle de pantalla (1 h)", func():
			gs.advance(60)
			npc.remember("ayudado")
			if _chance(0.65 - 0.15 * world.police_watching()):
				var n := randi_range(10, 35)
				gs.add_money(n)
				_heat(20)
				gs.log_msg("Tú le preguntas por la Boqueria a una guiri; %s le vacía el bolso. Tu parte: %d €." % [npc.display_name, n], G.C_GOOD)
				gs.milestone("primer_robo")
			else:
				_heat(60)
				gs.log_msg("%s se esfuma entre la gente. Tú no." % npc.display_name, G.C_BAD)
				world.scandal(null, "«¡Al ladrón!»")
			gs.change_dignity(-3)),
	]
	if not "aprendiz" in gs.milestones and gs.money >= 20:
		acts.append(_act("Pagarle para que te enseñe (20 €)", func():
			gs.add_money(-20)
			gs.advance(120)
			gs.milestone("aprendiz")
			npc.say("Dos dedos, nunca tres. Y mira a los ojos")
			gs.log_msg("Dos horas de clase en un banco de la Rambla. Ahora robas mejor a los turistas.", G.C_GOOD)))
	if gs.has_item("cartera"):
		acts.append(_act("Venderle la cartera con los papeles (12 €)", func():
			if world.street_items.take_fake("cartera", "«¿Esto qué es?» Te la tira a la cara: es %s."):
				npc.say("No me hagas perder el tiempo")
				return
			gs.remove_item("cartera")
			gs.add_money(12)
			npc.say("Los pasaportes se pagan bien")
			gs.change_dignity(-2)))
	return acts


## Los chavales que esnifan cola: solo se les puede ayudar (o no), nunca aprovecharse de ellos.
func _chaval(npc: Npc) -> Array:
	var gs := GameState
	var acts := []
	for food in ["bocadillo", "durum", "sobras"]:
		if gs.has_item(food):
			acts.append(_act("Darle tu %s" % Defs.item_name(food).to_lower(), func():
				gs.remove_item(food)
				npc.remember("ayudado")
				npc.say("Gracias, hermano. De verdad")
				gs.change_sanity(5)
				gs.change_dignity(3, "Compartir lo poco que tienes")))
			break
	if gs.money >= 1:
		acts.append(_act("Darle un euro", func():
			gs.add_money(-1)
			npc.money += 1
			npc.remember("ayudado")
			npc.say("Dios te lo pague")
			gs.change_dignity(1)))
	acts.append(_act("Preguntarle por la Urbana", func():
		gs.advance(5)
		npc.say("Hay dos en la plaza. Por aquí no pases")
		gs.heat = maxf(0.0, gs.heat - 10.0)
		gs.log_msg("Te dice por dónde patrulla la Urbana. Los chavales lo saben todo.", G.C_GOOD)))
	var educators: Array = world.npcs.filter(func(n): return n.kind == "educador" and n.distance_to_cell(npc.cell) < 60)
	if not educators.is_empty():
		acts.append(_act("Llevarle con la educadora", func():
			gs.advance(20)
			var edu: Npc = educators[0]
			edu.walk_to(npc.cell)
			edu.say("¡%s! ¿Vienes a cenar?" % npc.display_name, 4.0)
			npc.walk_to(edu.cell)
			gs.log_msg("%s se va con %s. Hoy duerme bajo techo." % [npc.display_name, edu.display_name], G.C_GOOD)
			gs.change_sanity(5)
			gs.change_dignity(4, "Hacer algo bien por alguien")
			world.remove_npc_later(npc, 4.0)))
	return acts


func _nino(npc: Npc) -> Array:
	var gs := GameState
	return [
		_act("Jugar a la pelota con ellos (20 min)", func():
			gs.advance(20)
			# con mala pinta, una madre se los lleva
			if gs.dignity < 30 or gs.high > 50.0 or gs.mono > 50.0:
				npc.say("¡Mamá!", 2.0)
				_heat(5)
				gs.change_dignity(-4, "Que una madre aparte a su hijo de ti")
				gs.log_msg("Una madre se lleva a %s de la mano sin quitarte el ojo de encima." % npc.display_name, G.C_BAD)
				world.remove_npc_later(npc, 2.0)
			else:
				npc.remember("ayudado")
				npc.say(["¡Gooool!", "¡Otra, otra!", "¡Eres malísimo!"].pick_random())
				gs.change_sanity(4)
				gs.change_dignity(2, "Un rato de pelota en la plaza")
				gs.log_msg("Durante veinte minutos eres otra persona.", G.C_GOOD)),
	]


func _anciano(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Ayudarle con la compra (30 min)", func():
			gs.advance(30)
			npc.remember("ayudado")
			npc.say("Qué majo eres, hijo")
			gs.change_dignity(3, "Ayudar a alguien mayor")
			gs.change_sanity(2)
			if _chance(0.35):
				var n := randi_range(2, 5)
				gs.add_money(n)
				gs.log_msg("Te da %d € para un café. No hay forma de decirle que no." % n, G.C_GOOD)),
		_act("Darle conversación (30 min)", func():
			gs.advance(30)
			npc.say(["En mis tiempos...", "Aquí había una lechería", "¿Tú de quién eres?"].pick_random(), 4.0)
			gs.change_sanity(4)
			gs.ease_mono(3.0)),
		_act("Pedirle una moneda", func():
			gs.advance(5)
			npc.remember("pedido")
			if _chance(0.3 + _beg_bonus()):
				gs.add_money(randi_range(1, 2))
				npc.say("Toma, y come algo")
			else:
				npc.say("Ay, hijo, si no llego a fin de mes")
			gs.change_dignity(-3, "Pedirle a un jubilado")),
	]
	if not npc.robbed and not npc.has_meta("receloso"):
		acts.append(_act("Robarle el monedero", func():
			gs.advance(5)
			_pickpocket(npc, "cartera", _pickpocket_chance(0.75), func():
				_heat(20)
				gs.log_msg("Le sacas el monedero. Lleva la pensión del mes.", G.C_GOOD)
				gs.change_dignity(-10, "Robarle a alguien mayor"),
			func():
				_heat(60)
				_caught_stealing(npc, "¡Al ladrón! ¡Socorro!")
				gs.log_msg("Se agarra al bolso y grita. Todo el mundo te mira.", G.C_BAD)
				gs.change_dignity(-8, "Que te pillen robándole a alguien mayor"))))
	return acts


func _perro(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Acariciarlo", func():
			gs.advance(2)
			npc.say("*mueve la cola*")
			gs.change_sanity(3)
			if gs.mono > 50.0:
				gs.log_msg("Por un momento se te olvida el mono.", G.C_GOOD)
				gs.ease_mono(2.0)),
	]
	for id in ["sobras", "bocadillo"]:
		if gs.has_item(id):
			acts.append(_act("Darle tus %s" % Defs.item_name(id).to_lower(), func():
				gs.remove_item(id)
				npc.remember("ayudado")
				if npc.amo != null and is_instance_valid(npc.amo):
					npc.amo.remember("ayudado")
					npc.amo.say("Mira, le has caído bien")
				npc.say("*se lo zampa*")
				gs.change_dignity(2, "Compartir la comida con un perro")))
			break
	return acts


func _mensajero(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle algo de comer", func():
			gs.advance(5)
			npc.remember("pedido")
			if npc.last_interaction_day != gs.day and _chance(0.3):
				npc.last_interaction_day = gs.day
				gs.add_item("bocadillo")
				npc.say("Un pedido cancelado. Tómalo, que lo iba a tirar")
			else:
				npc.say("Lo siento, hermano, llego tarde")
			gs.change_dignity(-2)),
	]
	if not npc.robbed:
		acts.append(_act("Robarle el pedido", func():
			gs.advance(5)
			npc.robbed = true
			if _chance(0.55 - 0.2 * world.police_watching()):
				gs.add_item("bocadillo")
				_heat(15)
				gs.log_msg("Le abres la mochila mientras mira el móvil. Hoy le descuentan el pedido a él.", G.C_GOOD)
				_after_theft(npc)
			else:
				_heat(35)
				_caught_stealing(npc, "¡Eh! ¡Que es mi trabajo!")
				gs.log_msg("Se da la vuelta justo a tiempo.", G.C_BAD)
			gs.change_dignity(-5, "Robarle la cena a un currante")))
	return acts


func _pudiente(npc: Npc) -> Array:
	var gs := GameState
	var acts := [
		_act("Pedirle una moneda", func():
			gs.advance(5)
			npc.remember("pedido")
			if not npc.robbed and _chance(0.15 + _beg_bonus()):
				var n := randi_range(5, 20)
				gs.add_money(n)
				npc.say("Toma... y no te lo gastes en eso")
				gs.log_msg("Te da %d € sin mirarte a la cara." % n, G.C_GOOD)
			else:
				npc.say(["No llevo suelto", "Ahora no", "*hace como que no te oye*"].pick_random())
			gs.change_dignity(-3, "Que te miren como a un mueble")),
		_act("Contarle tu drama", func():
			gs.advance(20)
			npc.remember("pedido")
			if _chance(0.1 + _beg_bonus()):
				var n := randi_range(20, 50)
				gs.add_money(n)
				gs.log_msg("Le remueves algo por dentro: %d €. Mañana lo contará en una cena." % n, G.C_GOOD)
			else:
				npc.say("Hay servicios sociales para eso")
			gs.change_dignity(-4, "Llorarle a alguien con pasta")),
	]
	if not npc.robbed and not npc.has_meta("receloso"):
		acts.append(_act("Robarle la cartera", func():
			gs.advance(5)
			var loot := "movil" if randf() < 0.5 else "cartera"
			# va con el bolso cruzado y mirando a todos lados: más difícil que un guiri
			_pickpocket(npc, loot, _pickpocket_chance(0.45), func():
				_heat(25)
				gs.log_msg("Dentro hay más de lo que ganas en un mes.", G.C_GOOD)
				gs.change_dignity(-2),
			func():
				_heat(75)
				_caught_stealing(npc, "¡Policía! ¡Me roban!")
				gs.log_msg("Te ha visto. Ya está llamando al 112.", G.C_BAD)
				gs.change_dignity(-2))))
	return acts


# ------------------------------------------------------------------- lugares

const POI_LABELS := {
	"super": "Súper", "farmacia": "Farmacia", "bar": "Bar", "kebab": "Kebab",
	"cajero": "Cajero", "iglesia": "Iglesia", "banco": "Banco de la calle",
	"albergue": "Servicio social", "cap": "Centro de salud", "cas": "CAS Baluard",
	"comisaria": "Comisaría", "compraventa": "Compraventa",
}


func for_poi(poi: Dictionary) -> Array:
	var gs := GameState
	var acts := world.errands.actions_for_poi(poi)
	match poi["kind"]:
		"super":
			acts.append(_buy("Comprar una litrona", 2, "litrona"))
			acts.append(_buy("Comprar un bocadillo", 3, "bocadillo"))
			acts.append(_act("Robar una litrona", func():
				if _chance(0.6 - 0.2 * world.police_watching()):
					gs.add_item("litrona")
					gs.log_msg("Litrona bajo el abrigo. Nadie ha visto nada.", G.C_GOOD)
					gs.milestone("primer_robo")
				else:
					_heat(40)
					gs.log_msg("El de seguridad te pilla y te echa a empujones.", G.C_BAD)
					world.scandal(null, "«¡Al ladrón!», grita el de seguridad.")
				gs.change_dignity(-2)))
		"farmacia":
			if gs.can_get_meds():
				acts.append(_act("Recoger tu medicación", func():
					gs.got_meds()
					gs.add_item("pastillas", 3)
					gs.log_msg("La farmacéutica te da tus pastillas. Tú sabrás lo que haces con ellas.")))
			acts.append(_act("Pedir un kit de reducción de daños", func():
				gs.advance(10)
				gs.change_health(3)
				gs.log_msg("Agua, gasas y un folleto. Algo es algo.")))
			acts.append(_buy_effect("Comprar ibuprofeno", 3, func(): gs.change_health(5)))
		"bar":
			acts.append(_buy_effect("Tomarte un carajillo", 2, func():
				gs.add_item("litrona")
				gs.consume("litrona")))
			acts.append(_act("Pedir por las mesas de la terraza", func():
				gs.advance(15)
				if _chance(0.3 + _beg_bonus()):
					var n := randi_range(1, 4)
					gs.add_money(n)
					gs.log_msg("Sacas %d € entre las mesas." % n, G.C_GOOD)
				else:
					gs.log_msg("El camarero te echa con un trapo.")
				gs.change_dignity(-3, "Mendigar en una terraza")))
			acts.append(_act("Robar la propina del platito", func():
				if _chance(0.5):
					var n := randi_range(2, 6)
					gs.add_money(n)
					gs.log_msg("%d € de propina ajena." % n, G.C_GOOD)
					gs.milestone("primer_robo")
				else:
					_heat(40)
					world.scandal(null, "«¡Eh, tú! ¡Esa propina!» Sales por patas.")
				gs.change_dignity(-2)))
		"kebab":
			acts.append(_buy_effect("Comerte un dürüm", 4, func():
				gs.add_item("durum")
				gs.consume("durum")))
			acts.append(_act("Pedir las sobras", func():
				gs.add_item("sobras")
				gs.consume("sobras")))
		"cajero":
			if gs.bank > 0:
				acts.append(_act("Sacar dinero (%d €)" % gs.bank, func():
					gs.add_money(gs.bank)
					gs.log_msg("Sacas %d €." % gs.bank, G.C_GOOD)
					gs.bank = 0))
			acts.append(_act("Dormir en el cajero (7 h)", func():
				world.sleep(7 * 60, 0.15, 25.0, 0.7)
				gs.change_dignity(-6, "Dormir entre recibos")
				gs.milestone("cajero")))
		"iglesia":
			acts.append(_act("Pedir en la puerta", func():
				gs.advance(30)
				var p := 0.5 + _beg_bonus() + (0.2 if gs.hour() < 13 else 0.0)
				if _chance(p):
					var n := randi_range(1, 6)
					gs.add_money(n)
					gs.log_msg("Una señora te da %d € y un «que Dios te ayude»." % n, G.C_GOOD)
				gs.change_dignity(-2, "Pedir en la iglesia")))
		"banco":
			acts.append(_act("Dormir en el banco (6 h)", func():
				world.sleep(6 * 60, 0.3, 15.0, 0.6)
				gs.change_dignity(-4, "Dormir al raso")
				gs.milestone("primera_calle")))
		"albergue":
			if gs.hour() >= 19 or gs.hour() < 1:
				acts.append(_act("Pasar la noche en el albergue", func():
					var until_morning := (24 - gs.hour() + 8) % 24 * 60.0
					gs.eat(40.0)
					gs.log_msg("Cena caliente: lentejas y pan.", G.C_GOOD)
					world.sleep(until_morning, 0.0, 35.0, 1.0)
					gs.change_dignity(2, "Una cama de verdad")))
			else:
				acts.append(_act("Preguntar por una cama", func():
					gs.log_msg("Las camas se reparten a partir de las 19:00.")))
			acts.append(_act("Ducharte", func():
				gs.advance(30)
				gs.change_dignity(3, "Agua caliente")))
		"cap":
			acts.append(_act("Ir a urgencias (4 h)", func():
				gs.advance(240)
				gs.change_health(25)
				gs.log_msg("Cuatro horas en la sala de espera, pero te curan.", G.C_GOOD)))
		"cas":
			if gs.can_get_methadone():
				acts.append(_act("Tomar tu dosis de metadona", func():
					gs.got_methadone()
					gs.add_item("metadona")
					gs.consume("metadona")
					gs.log_msg("El mono se calma. Por hoy.", G.C_GOOD)))
			for id in gs.inventory.keys():
				if Defs.SUBSTANCES.has(id):
					acts.append(_act("Consumir %s en la sala supervisada" % Defs.item_name(id).to_lower(), func():
						gs.consume(id, true)))
			acts.append(_act("Café y ducha", func():
				gs.advance(40)
				gs.eat(10.0)
				gs.ease_mono(5.0)
				gs.change_health(5)
				gs.change_dignity(2)))
		"comisaria":
			acts.append(_act("Entregarte", func():
				gs.change_dignity(-2)
				world.arrest_player()))
			acts.append(_act("Denunciar que te han robado", func():
				gs.advance(60)
				gs.log_msg("Te miran de arriba abajo y te hacen esperar una hora para nada.")
				gs.change_dignity(-1)))
		"compraventa":
			for id in gs.inventory.keys():
				var item: Dictionary = Defs.ITEMS.get(id, {})
				if item.get("sell", 0) > 0:
					acts.append(_act("Vender %s (%d €)" % [item["name"].to_lower(), item["sell"]], func():
						if world.street_items.take_fake(id, "«¿Me tomas el pelo?» Lo que querías vender es %s."):
							gs.milestone("piedra")
							return
						gs.remove_item(id)
						gs.add_money(item["sell"])
						gs.log_msg("Vendido: %s." % item["name"], G.C_GOOD)
						if id == "anillo":
							gs.change_dignity(-10, "Adiós, matrimonio")
							gs.milestone("anillo")))
			if acts.is_empty():
				acts.append(_act("Mirar el escaparate", func():
					gs.log_msg("No tienes nada que valga algo. Ni tú.")))
	return acts


func _buy(label: String, price: int, item: String) -> Dictionary:
	return _buy_effect(label, price, func(): GameState.add_item(item))


func _buy_effect(label: String, price: int, effect: Callable) -> Dictionary:
	var gs := GameState
	return _act("%s (%d €)" % [label, price], func():
		if gs.money < price:
			gs.log_msg("No te llega.", G.C_BAD)
			return
		gs.add_money(-price)
		effect.call())
