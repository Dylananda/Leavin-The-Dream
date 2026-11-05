extends SceneTree
## Prueba de humo: carga el barrio con cada perfil y ejecuta todas las acciones
## de todos los tipos de bot y de lugar, más el inventario. Falla si algo lanza error.
## Uso: godot --headless --path game --script res://tests/smoke.gd

func _initialize() -> void:
	var gs = root.get_node("GameState")
	load("res://scripts/partida.gd").automatico = false  # que no se guarde sola en user:// durante la prueba
	for profile in Defs.PROFILES:
		gs.new_game(profile["id"])
		gs.money = 500
		change_scene_to_file("res://scenes/world.tscn")
		await process_frame
		await process_frame
		var world = current_scene
		world.censo.pausado = true  # que no se duerma nadie a media prueba (el censo se prueba aparte)
		_test_censo(world)
		_test_personajes(world)
		_test_vitalidad(world)
		# los que no salen a esta hora (despedidas, lateros...) se crean a mano para probarlos
		for kind in world.BASE_NPCS:
			if world.npcs.filter(func(n): return n.kind == kind).is_empty():
				world._spawn_npc(kind)
		for npc in world.npcs:
			npc.known = true
		var thief = world.npcs.filter(func(n): return n.kind == "carterista")[0]
		var guiri = world.npcs.filter(func(n): return n.kind == "turista" and not n.robbed)[0]
		guiri.setup(world.city, thief.cell)
		_check(world.pickpocket_event(), "los carteristas no roban a nadie")
		_test_looks(world)
		var counts := {}
		for npc in world.npcs:
			counts[npc.kind] = counts.get(npc.kind, 0) + 1
		print("%s: %d bots %s" % [profile["id"], world.npcs.size(), counts])

		var done_kinds := {}
		for npc in world.npcs.duplicate():
			if done_kinds.has(npc.kind) or not is_instance_valid(npc):
				continue
			done_kinds[npc.kind] = true
			for a in world.interactions.for_npc(npc):
				if a["label"] == "Insultarle" or not gs.alive:
					continue
				a["do"].call()
		# (sin referencias estáticas a clases que usan el autoload: --script las compila antes de que exista)
		var first_of_kind := {}
		for p in world.city.pois:
			if not first_of_kind.has(p["kind"]):
				first_of_kind[p["kind"]] = p
		for kind in first_of_kind:
			for a in world.interactions.for_poi(first_of_kind[kind]):
				if gs.alive:
					a["do"].call()
		for id in gs.inventory.keys():
			if gs.alive and Defs.usable(id):
				world.use_item(id)
		if profile == Defs.PROFILES[0]:
			await _test_conversation(gs, world)
		await _test_errands(gs, world)
		_test_peticiones(world)
		_test_misiones(gs, world)
		if profile == Defs.PROFILES[0]:
			_test_cadenas(gs, world)
		if profile == Defs.PROFILES[0]:
			_test_vision(gs, world)
		_test_street_items(gs, world)
		_test_trade(gs, world)
		if profile == Defs.PROFILES[0]:
			_test_consumo(gs, world)
			_test_resacas(gs, world)
			_test_clubs(gs, world)
		if profile == Defs.PROFILES[0]:
			_test_police_and_fauna(gs, world)
		world._rummage()
		world._sleep_here()
		if gs.alive:
			world.arrest_player()

		# cada sustancia (con un frame para que la cámara, el movimiento y el HUD apliquen sus efectos)
		gs.alive = true
		for id in Defs.SUBSTANCES:
			_steady(gs)
			gs.add_item(id)
			world.use_item(id)
			await process_frame
			_check(gs.knows(id), "%s: no aparece como conocida" % id)
			_check(not gs.effects()["causes"].is_empty(), "%s: no da ningún efecto" % id)
		print("  efectos: %s" % [", ".join(gs.effects()["fx"].keys())])
		# el bajón de la base al acabarse el colocón
		_steady(gs)
		gs.subs["base"]["high"] = 12.0
		gs.advance(10)
		_check(gs.subs["base"]["crash"] > 0.0, "la base no da bajón")
		# extremos: desmayo de hambre, quedarse frito, brote
		_steady(gs)
		gs.hunger = 100.0
		gs.advance(1)
		_check(gs.hunger < 100.0 and "desmayo" in gs.milestones, "el hambre al máximo no te desmaya")
		_steady(gs)
		gs.fatigue = 100.0
		gs.advance(1)
		_check(gs.fatigue < 100.0 and "frito" in gs.milestones, "el sueño al máximo no te tumba")
		_steady(gs)
		for id in gs.subs:
			gs.subs[id]["high"] = 0.0  # (los antidepresivos, tomados, subirían la mente)
		gs.resacas = {}
		gs.sanity = 0.0
		gs.advance(1)
		_check(gs.sanity > 0.0 and "psiquiatrico" in gs.milestones, "la salud mental a 0 no acaba en ingreso")
		await process_frame
		print("  día %d, caída %d, dignidad %d, salud %d, hambre %d, sueño %d, mente %d, vivo=%s, hitos=%s" % [
			gs.day, gs.caida, gs.dignity, gs.health, gs.hunger, gs.fatigue, gs.sanity, gs.alive, gs.milestones])
		get_root().get_tree().paused = false
	await _test_finales()
	await _test_relevo()
	await _test_partida()
	await _test_proposito()
	await _test_editor()
	await _test_sustancias()
	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	quit(1 if _failures > 0 else 0)


var _failures := 0


## Conversación con IA sin depender de Ollama: contra un puerto en el que no escucha nadie
## (el juego debe seguir y avisar en el registro) y con una respuesta inventada que usa
## todas las acciones de juego.
## Vitalidad: correr la gasta hasta agotarte, el hambre baja su máximo y pelear la gasta.
## La pausa y el mapa se abren y se cierran.
func _test_vitalidad(world) -> void:
	var gs = root.get_node("GameState")
	gs.vitality = gs.vitality_max()
	gs.change_vitality(-1000.0)
	_check(gs.exhausted and gs.vitality == 0.0, "vitalidad: vaciarla no te deja agotado")
	gs.change_vitality(Defs.VITALITY_RECOVER + 1.0)
	_check(not gs.exhausted, "vitalidad: no te recuperas")
	var full: float = gs.vitality_max()
	gs.hunger = 95.0
	_check(gs.vitality_max() < full, "vitalidad: el hambre no baja el máximo")
	gs.hunger = 30.0
	gs.vitality = 100.0
	world.interactions._fight(world._spawn_npc("yonki"))
	_check(gs.vitality < 100.0, "vitalidad: pelear no la gasta")
	gs.vitality = 100.0
	gs.exhausted = false
	world.hud.toggle_pause()
	_check(world.get_tree().paused and world.hud.is_menu_open(), "pausa: no para el juego")
	world.hud.toggle_map()
	_check(is_instance_valid(world.hud._map), "mapa: no se abre desde la pausa")
	world.hud.toggle_map()
	world.hud.toggle_pause()
	_check(not world.get_tree().paused and not world.hud.is_menu_open(), "pausa: no se quita")
	# la bici: te subes con B (o desde el inventario), vas más rápido y te bajas al venderla
	gs.add_item("bici")
	world.toggle_bike()
	world._update_player_input(0.016)
	_check(gs.riding and world.player.look.get("bici", false) and world.player.run_factor == Defs.BIKE_SPEED, "bici: no te subes o no corre más")
	# el dueño de la bici te ve, va a por ti y, si te alcanza, se la lleva
	var owner = world._spawn_npc("vecino")
	owner.set_meta("dueno_bici", true)
	owner.chase_reason = "venganza"
	world._on_caught(owner)
	_check(not gs.has_item("bici"), "bici: el dueño no se la lleva al alcanzarte")
	world._update_player_input(0.016)
	_check(not gs.riding and not world.player.look.get("bici", false), "bici: sigues montado en una bici que ya no tienes")
	print("  vitalidad, pausa y mapa: OK")


## Peticiones de la gente corriente: alguien de cada tipo las pide, se apuntan y se cumplen
## en su sitio (algunas pagan, todas dan algo de dignidad).
func _test_peticiones(world) -> void:
	var gs = root.get_node("GameState")
	var errands = world.errands
	gs.errands = []
	gs.notes = []
	gs.money = 100
	for id in ["receta", "camino", "compra", "perro", "pelota", "direccion"]:
		var kind: String = Defs.ERRANDS[id]["giver"]
		var npc = null
		for tries in 150:
			var fresh = world._spawn_npc(kind)
			if errands._asks(fresh, id):
				npc = fresh
				break
		if npc == null:
			_check(false, "%s: nadie pide la petición" % id)
			continue
		npc.known = true
		_check(errands.offers_for(npc).size() >= 1, "%s: no la ofrece en su menú" % id)
		errands.accept(npc, id, errands._plan(id))
		var e: Dictionary = errands.active(id)
		var before: int = gs.money
		var acts = world.interactions.for_poi(e["poi"]).filter(func(a): return a["label"] == errands._deliver_label(e))
		_check(acts.size() == 1, "%s: no se puede cumplir en su sitio" % id)
		if not acts.is_empty():
			acts[0]["do"].call()
		_check(e["state"] == "hecho" and gs.money >= before - Defs.ERRANDS[id].get("advance", 0), "%s: cumplirla no paga" % id)
	# pistas de las conversaciones en la libreta, que caducan; y la placa de la calle, que
	# miente cuando vas ido
	gs.pistas = []
	var before: int = errands.notebook_entries().size()
	gs.add_pista("Toni", "dos agentes en la Rambla")
	_check(errands.notebook_entries().size() == before + 1, "pistas: no salen en la libreta")
	gs.advance((Defs.PISTA_HOURS + 1.0) * 60.0)
	_check(errands.notebook_entries().size() <= before, "pistas: no caducan")
	world.player.setup(world.city, world.city.street_cells("La Rambla")[0])
	var count_lies := func() -> int:
		var lies := 0
		for i in 60:
			world._street_real = "?"
			world._update_street()
			if world._street_shown != world._street_real:
				lies += 1
		return lies
	var was_fatigue: float = gs.fatigue
	var was_sanity: float = gs.sanity
	for id in gs.subs:
		gs.subs[id]["high"] = 0.0
		gs.subs[id]["mono"] = 0.0
	gs.fatigue = 0.0
	gs.sanity = 100.0
	_check(gs.befuddlement() > 0.0 or count_lies.call() == 0, "calle: la placa miente estando sereno")
	gs.fatigue = 95.0  # ido de sueño (sin pasar el tiempo, para no quedarse frito)
	_check(count_lies.call() > 0, "calle: la placa no miente nunca aunque vayas ido")
	gs.fatigue = was_fatigue
	gs.sanity = was_sanity
	print("  peticiones: OK")


## Personajes del editor: su fuerza cuenta en las peleas, venden lo que pone su ficha y los
## perros salen con su dueño.
func _test_personajes(world) -> void:
	var censo = world.censo
	var me: Vector2i = world.player.cell
	var quique = null
	var txell = null
	for r in censo.registros:
		match r["personaje"].get("id", ""):
			"quique_el_nano":
				quique = censo.despertar(r, me) if r["npc"] == null else r["npc"]
			"txell":
				txell = censo.despertar(r, me) if r["npc"] == null else r["npc"]
	if quique == null or txell == null:
		print("  personajes: sin los de ejemplo, no se prueban")
		return
	var gs = root.get_node("GameState")
	var plain = world._spawn_npc("yonki")
	plain.consumo = {}  # (lo que lleva encima también cuenta en las peleas: aquí solo la fuerza)
	var quique_consumo: Dictionary = quique.consumo
	quique.consumo = {}
	_check(world.interactions._fight_chance(quique) <= world.interactions._fight_chance(plain),
		"personajes: la fuerza no cuenta en las peleas")
	quique.consumo = quique_consumo
	gs.money = 100
	var buy: Array = world.trade.offers_for(quique).filter(func(a): return a["label"].begins_with("Comprarle base"))
	_check(not buy.is_empty(), "personajes: Quique no vende lo que pone su ficha")
	if not buy.is_empty():
		buy[0]["do"].call()
		_check(gs.has_item("base"), "personajes: comprar no te da la sustancia")
	_check(world.npcs.any(func(n): return n.amo == txell and n.display_name == "Tula"), "personajes: Tula no sale con Txell")
	print("  personajes: OK")


## Censo: el que se aleja se duerme con lo que le ha pasado, el que tiene asuntos contigo no,
## al volver se acuerda (y con el tiempo olvida).
func _test_censo(world) -> void:
	var censo = world.censo
	var me: Vector2i = world.player.cell
	var lejos: Vector2i = me
	while maxi(absi(lejos.x - me.x), absi(lejos.y - me.y)) <= censo.RADIO_DORMIR:
		lejos = world.city.random_walkable()
	var r: Dictionary = censo.nuevo("vecino")
	var npc = censo.despertar(r, me)
	npc.known = true
	npc.money = 7
	npc.remember("pedido")
	npc.remember("pedido")
	var name: String = npc.display_name
	npc.setup(world.city, lejos)
	npc.mode = "busca"
	censo.repasar()
	_check(is_instance_valid(npc) and npc in world.npcs, "censo: se duerme alguien con asuntos contigo")
	npc.mode = ""
	censo.repasar()
	_check(r["npc"] == null and npc not in world.npcs, "censo: el que se aleja no se duerme")
	_check(r["estado"]["memory"].get("pedido", 0) == 2, "censo: al dormirse no guarda lo que le hiciste")
	r["home"] = me
	censo.repasar()
	var back = r["npc"]
	_check(back != null and back.display_name == name and back.known and back.money == 7 and back.remembers("pedido") == 2,
		"censo: al despertar no es el mismo o no se acuerda")
	censo.dormir(r)
	r["visto"] -= Defs.LATENT_MEMORY_FADE * 2.0
	back = censo.despertar(r, me)
	_check(back.remembers("pedido") == 0, "censo: no olvida con el tiempo")
	# despertador: el camello al que debes, latente y lejos, viene a buscarte cuando vence
	var rc: Dictionary = censo.nuevo("camello")
	var dealer = censo.despertar(rc, lejos)
	dealer.add_debt(30, 0.0)
	censo.dormir(rc)
	censo.despertadores()
	var hunter = rc["npc"]
	_check(hunter != null and hunter.mode == "viene" and hunter.distance_to_cell(me) <= censo.RADIO_VISTA + 20,
		"censo: el camello al que debes no viene a buscarte (%s)" % ("nadie" if hunter == null else "%s a %d casillas" % [hunter.mode, hunter.distance_to_cell(me)]))
	censo.despertadores()
	_check(rc["npc"] == hunter, "censo: el despertador salta dos veces seguidas")
	if hunter != null:
		hunter.debt = 0
		hunter.calm_down()
	# grupos: la despedida sale con los suyos detrás
	var party = censo.despertar(censo.nuevo("fiestero"), me)
	var behind: int = world.npcs.filter(func(x): return x.amo == party).size()
	_check(behind >= Defs.PARTY_GROUP.x, "censo: la despedida no va en grupo")
	censo.dormir(censo.de(party))
	_check(world.npcs.all(func(x): return x.amo != party), "censo: el grupo no se va con la despedida")
	var n: int = censo.registros.size()
	print("  censo: OK (%d registros, %d con cuerpo, %d latentes)" % [n, n - censo.latentes(), censo.latentes()])


## Finales: el hambre mata en días (no de golpe) y se nota antes; la cárcel a la quinta
## detención; con muchos enemigos en el barrio te esperan entre varios.
func _test_finales() -> void:
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.censo.pausado = true
	var reason := [""]
	gs.game_over.connect(func(r): reason[0] = r)
	# no come nunca (y sin sustancias, para que no mate el mono)
	gs.subs = {}
	gs.hunger = 95.0
	var start: float = gs.now()
	gs.advance(12 * 60)
	_check(gs.alive and gs.starving > 6.0, "hambre: no se acumula la inanición, o mata de golpe")
	_check(gs.effects()["causes"].any(func(c): return c[0].begins_with("Inanición")), "hambre: la inanición no se nota")
	while gs.alive and gs.now() - start < 24 * 60 * 10:
		gs.hunger = maxf(gs.hunger, 90.0)
		gs.sanity = 100.0  # (sin estallidos ni puñetazos: solo el hambre)
		gs.advance(60)
	var hours := int((gs.now() - start) / 60.0)
	_check(not gs.alive and "hambre" in reason[0] and hours >= 48, "hambre: no mata en días (%d h: %s)" % [hours, reason[0]])
	print("  hambre: muere a las %d h sin comer: %s" % [hours, reason[0]])
	# la cárcel
	gs.new_game("parado")
	reason[0] = ""
	gs.subs = {}
	for i in Defs.PRISON_ARRESTS:
		gs.hunger = 0.0
		gs.fatigue = 0.0
		gs.arrest()
	_check(not gs.alive and "Brians" in reason[0], "cárcel: no entras a la quinta detención (%s)" % reason[0])
	# el ajuste de cuentas
	gs.new_game("parado")
	_check(not world.ambush(), "ajuste de cuentas: te esperan sin tener enemigos")
	for i in Defs.AMBUSH_ENEMIES:
		world._spawn_npc("vecino").remember("robado")
	_check(world.ambush(), "ajuste de cuentas: no te esperan con tantos enemigos")
	# leyenda del barrio: la caída máxima gana
	gs.new_game("parado")
	reason[0] = ""
	gs.add_caida(Defs.LEGEND_CAIDA)
	_check(not gs.alive and gs.ending_title == "LEYENDA DEL BARRIO", "leyenda: llegar al fondo no acaba la partida")
	# te llevan a casa: Borja, sin dignidad, acaba recogido por su familia
	gs.new_game("nino_bien")
	gs.subs = {}
	gs.dignity = 0.0
	for i in 40:
		if not gs.alive:
			break
		gs.hunger = 0.0
		gs.fatigue = 0.0
		gs.sanity = 100.0
		gs.health = 100.0
		gs.dignity = 0.0
		gs.advance(24 * 60)
	_check(not gs.alive and gs.ending_title == "TE LLEVAN A CASA", "casa: a Borja no lo recogen (%s)" % reason[0])
	# redención: limpio, digno y con amigos en el barrio, alguien se enamora de ti (y pierdes)
	gs.new_game("parado")
	gs.subs = {}
	gs.dignity = 95.0
	_check(not world._check_redemption(), "redención: llega sin amigos")
	for i in Defs.REDEMPTION_FRIENDS:
		var f = world._spawn_npc("vecino")
		for k in Defs.REDEMPTION_HELPS:
			f.remember("ayudado")
	_check(world._check_redemption() and gs.ending_title == "REDENCIÓN", "redención: no llega con todo a favor")
	get_root().get_tree().paused = false
	print("  finales: OK")


## El relevo: Paco muere, sigue Don Ramón en el mismo barrio unos días después (con un altar
## donde murió Paco, la gente que le conocía se acuerda de él y no del nuevo, y algunos se han
## enganchado); Don Ramón se hace leyenda y sigue Jordi, con Don Ramón en el censo. Todo vuelve
## al cargar la partida.
func _test_relevo() -> void:
	var gs = root.get_node("GameState")
	var Pa = load("res://scripts/partida.gd")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.censo.pausado = true
	var amigo = _fresh(world, "vecino")
	amigo.remember("ayudado")
	var r_amigo: Dictionary = world.censo.de(amigo)  # (por su registro: hay vecinos que se llaman igual)
	var dolido = _fresh(world, "vecino")
	dolido.remember("robado")
	var dia: int = gs.day
	_steady(gs)
	gs.subs = {}
	gs.change_health(-500, "Prueba del relevo")
	_check(not gs.alive and gs.destino == "muerto" and gs.historia.size() == 1, "relevo: morir no queda en la historia (%s)" % gs.destino)
	_check(world.perfiles_libres().size() == Defs.PROFILES.size() - 1, "relevo: Paco sigue entre los que pueden tomar el relevo")
	_check(world.hud._game_over != null, "relevo: no sale la pantalla final")
	var regs: int = world.censo.registros.size()
	world.relevo("jubilado")
	_check(gs.alive and gs.profile["id"] == "jubilado" and gs.day >= dia + Defs.RELEVO_DIAS.x and gs.dia_inicio == gs.day,
		"relevo: no sigue Don Ramón unos días después (día %d)" % gs.day)
	_check(world.hud._game_over == null and world.player.display_name == "Don Ramón", "relevo: sigue la pantalla final o el muñeco de Paco")
	var altares: Array = world.city.pois_of_kind("altar")
	_check(altares.size() == 1 and altares[0]["name"] == "Paco", "relevo: no hay altar donde murió Paco")
	var antes_money: int = gs.money
	for a in world.interactions.for_poi(altares[0]):
		a["do"].call()
	_check(gs.historia[0]["rebuscado"] and world.interactions.for_poi(altares[0]).size() == 2,
		"relevo: las monedas del altar no se cogen una sola vez")
	var contagiados: Array = world.censo.registros.filter(func(r): return r.has("antes_era"))
	_check(contagiados.size() == mini(Defs.RELEVO_CONTAGIOS, regs) and contagiados.all(func(r): return r["kind"] == "yonki"),
		"relevo: nadie se ha enganchado (%d)" % contagiados.size())
	_check(not r_amigo.is_empty() and r_amigo in world.censo.registros and r_amigo["estado"]["metas"].get("recuerda_a", {}).get("trato", "") == "amigo"
		and r_amigo["estado"]["memory"].is_empty(), "relevo: el vecino al que ayudó Paco no se acuerda de él, o se acuerda de ti")
	if not r_amigo.is_empty():
		var n = world.censo.despertar(r_amigo, world.player.cell)
		var pregunta = world.interactions.for_npc(n).filter(func(a): return a["label"] == "Preguntarle por Paco")
		_check(not pregunta.is_empty() and n.memory.is_empty(), "relevo: no se le puede preguntar por Paco")
		if not pregunta.is_empty():
			pregunta[0]["do"].call()
	_check(world.censo.rencorosos().is_empty(), "relevo: el rencor a Paco pasa al nuevo")
	# también día a día
	var antes_dia: int = world.censo.registros.filter(func(r): return r.has("antes_era")).size()
	for i in 10:
		world._contagio_diario()
	_check(world.censo.registros.filter(func(r): return r.has("antes_era")).size() > antes_dia, "contagio diario: en diez días no se engancha nadie")
	# Don Ramón se hace leyenda: se queda en el barrio cuando sigue Jordi
	gs.add_caida(Defs.LEGEND_CAIDA)
	_check(not gs.alive and gs.destino == "leyenda" and gs.historia.size() == 2, "relevo: la leyenda no queda en la historia")
	world.relevo("divorciado")
	var ramon: Array = world.censo.registros.filter(func(r): return r["name"] == "Don Ramón" and r["kind"] == "yonki")
	_check(ramon.size() == 1, "relevo: Don Ramón, leyenda, no sigue en el barrio")
	if ramon.size() == 1:
		var n = world.censo.despertar(ramon[0], world.player.cell)
		_check(n.display_name == "Don Ramón" and n.look["skin"] == Defs.profile("jubilado")["look"]["skin"] and n.bio() != "",
			"relevo: Don Ramón no tiene su aspecto o su historia")
	# a la partida guardada
	var path := "user://partidas/prueba_relevo.json"
	_check(Pa.guardar(world, path) == OK and Pa.cargar(path), "relevo: no se guarda o no se carga")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	world = current_scene
	world.censo.pausado = true
	_check(gs.historia.size() == 2 and gs.profile["id"] == "divorciado" and world.city.pois_of_kind("altar").size() == 1,
		"relevo: al cargar no vuelven la historia o el altar")
	_check(world.perfiles_libres().size() == Defs.PROFILES.size() - 3, "relevo: los que ya salieron vuelven a estar libres")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_root().get_tree().paused = false
	print("  relevo: OK (Paco → Don Ramón → Jordi, %d enganchados)" % contagiados.size())


## Género según el nombre, etiquetas en femenino y el mismo aspecto para el mismo nombre.
func _test_looks(world) -> void:
	var npc_script = load("res://scripts/actors/npc.gd")  # cargado aquí: usa los autoloads
	_check(Defs.PROFILES.filter(func(p): return p["name"] == "Mari Loli")[0]["look"]["gender"] == "f", "Mari Loli no es mujer")
	for npc in world.npcs:
		if not npc.personaje.is_empty():
			continue  # los del editor de personajes llevan el género que se les puso
		var k: Dictionary = npc_script.KINDS[npc.kind]
		if npc.display_name in k.get("women", []):
			_check(npc.gender == "f" and npc.look["gender"] == "f", "%s no es mujer" % npc.display_name)
		elif not npc.display_name in k.get("either", []):
			_check(npc.gender == "m", "%s no es hombre" % npc.display_name)
	var a = npc_script.new()
	a.init_kind("vecino", "Montse")
	var b = npc_script.new()
	b.init_kind("vecino", "Montse")
	_check(a.look == b.look and a.label() == "Montse (Vecina)", "Montse no sale siempre igual o no es vecina")
	a.free()
	b.free()


func _test_conversation(gs, world) -> void:
	gs.alive = true
	var conv = world.conversation
	conv.client.url = "http://127.0.0.1:9/api/chat"
	conv.client.timeout = 5.0
	var logged := []
	var on_msg := func(text: String, _c: Color): logged.append(text)
	gs.message.connect(on_msg)
	for kind in ["latero", "trilero", "carterista", "fiestero"]:
		var npc = world.npcs.filter(func(n): return n.kind == kind and not n.has_meta("enemigo"))
		if npc.is_empty():
			world._spawn_npc(kind)
			npc = [world.npcs[-1]]
		npc = npc[0]
		_check(world.interactions.for_npc(npc).any(func(a): return a["label"] == "Hablar"), "%s: no se le puede hablar" % kind)
		_check(conv.system_prompt(npc).contains(npc.display_name), "%s: la ficha no lleva su nombre" % kind)
		world.open_chat(npc)
		var failed := [false]
		var on_fail := func(_n, _e): failed[0] = true
		conv.failed.connect(on_fail)
		conv.say(npc, "Hola, ¿qué tal?")
		var until := Time.get_ticks_msec() + 15000
		while not failed[0] and Time.get_ticks_msec() < until:
			await process_frame
		conv.failed.disconnect(on_fail)
		_check(failed[0] and not conv.busy, "%s: sin IA, la conversación no termina" % kind)
	_check(logged.any(func(t): return t.contains("no responde") or t.contains("IA")), "sin IA no se avisa en el registro")
	# una respuesta que lo usa todo: el juego propone (acciones del menú, datos, sitios) y la IA elige
	gs.alive = true
	world._spawn_npc("latero")
	var npc = world.npcs[-1]
	npc.set_meta("alijo", true)
	gs.money = 50
	conv.system_prompt(npc)  # prepara las opciones de esta frase
	var options: Dictionary = conv._turn["options"]
	_check(not options.values().any(func(a): return a["label"].begins_with("Robar")), "le ofrece robarse a sí mismo")
	var buy := ""
	for id in options:
		if options[id]["label"].begins_with("Comprarle una lata"):
			buy = id
	_check(buy != "" and not conv._turn["data"].is_empty() and conv._turn["sites"].has("s1"), "no prepara opciones, datos y sitios")
	_check(conv.schema()["properties"]["ofrece"]["enum"].has(buy), "el esquema no deja elegir las opciones")
	var r: Dictionary = conv.handle_reply(npc, JSON.stringify({"ofrece": buy, "cuenta": "d1", "senala": "s1", "reaccion": "ninguna", "dice": "Una lata, amigo"}))
	_check(r["text"] == "Una lata, amigo" and r["offers"].size() == 1 and not r["ended"], "la respuesta de la IA no se interpreta")
	var cans: int = gs.inventory.get("litrona", 0)
	_check(conv.accept(npc, buy) and gs.inventory.get("litrona", 0) == cans + 1, "aceptar lo que ofrece no hace la acción")
	_check(not conv.accept(npc, buy), "se puede aceptar dos veces lo mismo")
	r = conv.handle_reply(npc, JSON.stringify({"ofrece": "o99", "cuenta": "d99", "senala": "s99", "reaccion": "inventada", "dice": "Hmm"}))
	_check(r["offers"].is_empty() and not r["ended"], "acepta ids que no son de esta frase")
	_check(conv.history(npc).size() >= 2, "no se acuerda de lo hablado")
	r = conv.handle_reply(npc, "esto no es JSON")
	_check(r["text"] == "esto no es JSON", "una respuesta sin formato no se muestra tal cual")
	r = conv.handle_reply(npc, JSON.stringify({"ofrece": "", "cuenta": "", "senala": "", "reaccion": "enfadarse", "dice": "¡Fuera!"}))
	_check(r["ended"] and not conv.can_talk(npc), "el enfado no corta la conversación")
	gs.message.disconnect(on_msg)
	world.hud.close_chat()
	# la petición para Claude (sin mandarla) y el aviso inmediato si falta la clave
	var client = conv.client
	client.proveedor = "anthropic"
	var body: Dictionary = client._anthropic_body([
		{"role": "system", "content": "ficha"}, {"role": "assistant", "content": "{}"},
		{"role": "user", "content": "hola"}, {"role": "assistant", "content": "{}"}, {"role": "user", "content": "¿y?"},
	], conv.schema())
	_check(body["system"] == "ficha" and body["messages"].size() == 3 and body["messages"][0]["role"] == "user",
		"la petición a Claude no separa el sistema o no empieza por el jugador")
	_check(body["output_config"]["format"]["schema"]["additionalProperties"] == false, "el esquema no vale para Claude")
	client.clave = ""
	var no_key := [""]
	client.ask([], {}, func(ok, err): no_key[0] = err if not ok else "")
	await process_frame
	_check(no_key[0].contains("clave"), "sin clave no avisa")
	client.proveedor = "ollama"
	print("  conversación: OK sin IA (%d mensajes en el registro)" % logged.size())


## Encargos con plazo y libreta: aceptar los cuatro, cumplir dos (uno esperando), fallar dos por
## el plazo, abrir el paquete, cada forma de apuntar mal, la lectura emborronada, el reloj que
## miente y la libreta en el HUD.
func _test_errands(gs, world) -> void:
	var errands = world.errands
	_steady(gs)
	for id in gs.subs:
		gs.subs[id]["high"] = 0.0
	gs.errands = []
	gs.notes = []
	gs.heat = 0.0
	gs.debt = 0
	# lo que te dieron los encargos que aceptó el bucle de acciones de antes
	for id in ["paquete", "cartera_caliente"]:
		gs.inventory.erase(id)
	_check(gs.befuddlement() == 0.0, "sereno y descansado, la cabeza no está entera")
	var givers := {}
	for id in Defs.ERRANDS:
		var kind: String = Defs.ERRANDS[id]["giver"]
		# solo algunos de cada tipo piden encargos (Defs.ERRANDS[...]["share"]); se busca uno que
		# pida este y ningún otro de su tipo, para contar bien lo que ofrece
		var only_this := func(n) -> bool:
			return n.kind == kind and is_instance_valid(n) and Defs.ERRANDS.keys().all(func(other):
				return (other == id) == (Defs.ERRANDS[other]["giver"] == kind and errands._asks(n, other)) or Defs.ERRANDS[other]["giver"] != kind)
		var npc = world.npcs.filter(only_this)
		var tries := 0
		while npc.is_empty() and tries < 150:
			var fresh = world._spawn_npc(kind)
			if only_this.call(fresh):
				npc = [fresh]
			tries += 1
		if npc.is_empty():
			_check(false, "%s: ninguno pide su encargo" % kind)
			continue
		npc = npc[0]
		npc.remove_meta("encargo_dia")
		npc.remove_meta("enemigo")
		npc.known = true  # (los disfrazados no se delatan hasta que les hablas)
		givers[id] = npc
		var offer = world.interactions.for_npc(npc).filter(func(a): return a["label"].begins_with("Encargo:"))
		_check(offer.size() == 1, "%s: no ofrece su encargo" % kind)
		if offer.is_empty():
			return
		_check(errands.marker_for(npc) == "!", "%s: no lleva el «!» de encargo" % kind)
		offer[0]["do"].call()
		_check(errands.marker_for(npc) == "★", "%s: no lleva la estrella del encargo en marcha" % kind)
		_check(not errands.active(id).is_empty(), "%s: el encargo no queda en marcha" % id)
		_check(world.interactions.for_npc(npc).all(func(a): return not a["label"].begins_with("Encargo:")), "%s: ofrece el encargo dos veces" % id)
	world._update_pointers()
	_check(errands.noted_places().size() == gs.notes.filter(func(n): return not n["poi"].is_empty()).size(), "las flechas no siguen a la libreta")
	_check(gs.notes.size() == Defs.ERRANDS.size() and gs.has_item("paquete") and gs.has_item("cartera_caliente"), "no se apuntan los encargos o no te dan lo que hay que llevar")
	_check(errands.active("paquete")["poi"] != errands.active("juerga")["poi"], "dos encargos en el mismo bar")
	print("  encargos: %s" % " | ".join(gs.notes.map(func(n): return errands.note_text(n))))
	# cumplir: el paquete en su bar, la despedida esperando a que llegue la hora
	var money: int = gs.money
	var e: Dictionary = errands.active("paquete")
	var acts = world.interactions.for_poi(e["poi"]).filter(func(a): return a["label"].begins_with("Entregar"))
	_check(acts.size() == 1, "no se puede entregar el paquete en su bar")
	if not acts.is_empty():
		acts[0]["do"].call()
	_check(e["state"] == "hecho" and gs.money == money + 25 and not gs.has_item("paquete"), "entregar el paquete no paga")
	e = errands.active("juerga")
	acts = world.interactions.for_poi(e["poi"]).filter(func(a): return a["label"].begins_with("Esperar"))
	_check(acts.size() == 1, "llegar pronto a la cita de la despedida no deja esperar")
	if not acts.is_empty():
		acts[0]["do"].call()
	_check(e["state"] == "hecho", "esperar a la despedida no cumple el encargo")
	# fallar por el plazo: la cartera, la cita con la educadora y las peticiones sin cumplir
	gs.alive = true
	for x in gs.errands:
		if x["state"] == "activo":
			x["until"] = gs.now() - 1.0
	errands.update()
	_check(gs.errands.all(func(x): return x["state"] != "activo"), "los plazos vencidos no fallan el encargo")
	_check(givers["cartera"].has_meta("enemigo") and gs.heat >= 40.0, "fallarle a la carterista no tiene consecuencias")
	_check(world.interactions.for_npc(givers["cartera"]).is_empty() or world.interactions.for_npc(givers["cartera"]).all(func(a): return not a["label"].begins_with("Hacerle")), "la carterista enfadada sigue tratando contigo")
	# abrir el paquete: dos rayas y una deuda más gorda
	givers["paquete"].remove_meta("encargo_dia")
	world.interactions.for_npc(givers["paquete"]).filter(func(a): return a["label"].begins_with("Encargo:"))[0]["do"].call()
	var coke: int = gs.inventory.get("farlopa", 0)
	world.use_item("paquete")
	_check(gs.inventory.get("farlopa", 0) == coke + 2 and gs.debt >= 60 and gs.errands[-1]["state"] == "fallado", "abrir el paquete no lo falla ni da la farlopa")
	# cada forma de apuntar mal cambia lo que se lee
	# partiendo de una nota fiel (la de verdad puede haberse apuntado mal ya: Defs.SLIP_BASE)
	var note: Dictionary = gs.notes[-1].duplicate()
	var real: Dictionary = note["errand"]
	note.merge({"poi": real["poi"], "from": real["from"], "until": real["until"], "slip": ""}, true)
	var truth: String = errands.note_text(note)
	for kind in errands.SLIPS:
		var bad: Dictionary = note.duplicate()
		errands.slip(bad, kind)
		_check(errands.note_text(bad) != truth, "apuntar mal (%s) no cambia la nota" % kind)
		if kind.begins_with("sin_"):
			_check(errands.note_text(bad).contains("¿?"), "un dato perdido no sale como ¿?")
	# leer: sobrio se lee tal cual; ido, algunas palabras no
	_check(errands.garble(truth, 0.0, 0.0, 1) == truth.replace("[", "[lb]"), "sobrio, la libreta no se lee tal cual")
	_check(errands.garble(truth, 1.0, 0.0, 1).contains("[color"), "ido, la libreta no se emborrona")
	_check(errands.garble(truth, 1.0, 1.0, 1).contains("[shake"), "con mono, la libreta no tiembla")
	_check(errands.garble(truth, 0.4, 0.5, 7) == errands.garble(truth, 0.4, 0.5, 7), "la lectura cambia sin motivo (parpadea)")
	_check(not errands.notebook_entries().is_empty(), "la libreta no tiene entradas")
	# el reloj: sobrio dice la verdad; mientras miente, no
	gs._clock_lie_left = 0.0
	gs.clock_skew = 0.0
	gs._clock_blank = false
	_check(gs.shown_clock_text() == gs.clock_text(), "sobrio, el reloj miente (%s en vez de %s, minuto %.6f)" % [gs.shown_clock_text(), gs.clock_text(), gs.minute_of_day])
	gs.clock_skew = 45.0
	gs._clock_lie_left = 30.0
	_check(gs.shown_clock_text() != gs.clock_text(), "el reloj no miente cuando toca")
	gs.advance(31.0)
	_check(gs.shown_clock_text() == gs.clock_text(), "el reloj no vuelve a la verdad")
	# muy ido, el reloj acaba mintiendo y la libreta se lee mal
	gs.subs[gs.subs.keys()[0]]["high"] = 120.0
	gs.fatigue = 95.0
	_check(gs.befuddlement() > 0.9, "muy ido, la cabeza sigue entera")
	var lied := false
	for i in 200:
		gs._update_clock_lie(30.0)
		lied = lied or gs.shown_clock_text() != gs.clock_text()
	_check(lied, "muy ido, el reloj nunca miente")
	_check(errands.notebook_entries().any(func(x): return x["text"].contains("[color=#ffffff22]") or x["text"].contains("[shake")), "muy ido, la libreta se lee perfecta")
	# la libreta en el HUD
	_steady(gs)
	world.hud.toggle_notebook(errands)
	await process_frame
	_check(world.hud.is_notebook_open(), "la libreta no se abre")
	world.hud.toggle_notebook(errands)
	print("  encargos y libreta: OK (deuda %d €, %d notas)" % [gs.debt, gs.notes.size()])


## Misiones de los personajes del editor: todas bien hechas, se ofrecen, se apuntan, se cumplen
## con quien toca y tienen sus consecuencias. «El paquete para Txell» (Quique) y «El cajero de
## Antonio» (convencer a la agente Mas), por los dos lados: cumplirlas y fallarlas.
func _test_misiones(gs, world) -> void:
	var misiones = world.misiones
	var ids: Array = world._personajes.map(func(d): return d["id"])
	for d in world._personajes:
		for a in misiones.comprobar(d, ids):
			_check(not a[0], "misiones de %s: %s" % [d["nombre"], a[1]])
	var quique = misiones.npc_de("quique_el_nano")
	var txell = misiones.npc_de("txell")
	var antonio = misiones.npc_de("antonio")
	var mas = misiones.npc_de("agent_mas")
	if quique == null or txell == null or antonio == null or mas == null:
		print("  misiones: sin los personajes de ejemplo, no se prueban")
		return
	_steady(gs)
	gs.errands = []
	gs.notes = []
	gs.misiones = {}
	gs.favores = {}
	gs.debe_a = {}
	gs.debt = 0
	gs.heat = 0.0
	gs.wanted_until = -1.0
	gs.money = 100
	gs.minute_of_day = 11.0 * 60.0
	gs.inventory.erase("paquete")
	gs.inventory.erase("papeles_albergue")
	misiones.preparar()
	_check(misiones.debes("txell") == 40, "no le debes nada a Txell al empezar")
	for npc in [quique, txell, antonio, mas]:
		npc.debt = 0
		npc.remove_meta("enemigo")
		npc.known = true
	# el paquete para Txell: Quique lo ofrece, te lo da y se cumple en el menú de Txell
	_check(world.errands.marker_for(quique) == "!", "Quique no lleva el «!» de misión")
	var offer = world.interactions.for_npc(quique).filter(func(a): return a["label"].begins_with("Misión «El paquete para Txell»"))
	_check(offer.size() == 1, "Quique no ofrece «El paquete para Txell»")
	if offer.is_empty():
		return
	offer[0]["do"].call()
	_check(gs.has_item("paquete") and misiones.activas().size() == 1, "aceptar la misión no te da el paquete")
	_check(world.errands.marker_for(quique) == "★" and world.errands.marker_for(txell) == "★", "la misión en marcha no marca a Quique y a Txell")
	_check(world.censo.anclado(quique), "Quique se duerme con la misión en marcha")
	_check(world.errands.notebook_entries().any(func(x): return x["text"].contains("Txell")), "la misión no se apunta en la libreta")
	print("  misiones: %s" % world.errands.note_text(gs.notes[-1]))
	var dar = world.interactions.for_npc(txell).filter(func(a): return a["label"].begins_with("Darle: paquete"))
	_check(dar.size() == 1, "no se le puede dar el paquete a Txell")
	if not dar.is_empty():
		dar[0]["do"].call()
	_check(gs.misiones.get("quique_el_nano/el_paquete_para_txell", {}).get("estado", "") == "hecho", "darle el paquete no cumple la misión")
	_check(not gs.has_item("paquete") and misiones.debes("txell") == 0, "Txell no se queda el paquete por tu deuda")
	_check(quique.debt == 40 and gs.debt == 40 and quique.grudge() != "cobrar", "Quique no te cobra el paquete (con plazo) [deuda %d, total %d, %s]" % [quique.debt, gs.debt, quique.grudge()])
	gs.health = 50.0
	var curar = world.interactions.for_npc(txell).filter(func(a): return a["label"] == "Que te cure las heridas")
	_check(curar.size() == 1, "Txell no te cura después de la misión")
	if not curar.is_empty():
		curar[0]["do"].call()
	_check(gs.health > 50.0, "curarte no sube la salud")
	_check(world.interactions.for_npc(quique).all(func(a): return not a["label"].begins_with("Misión")), "Quique vuelve a ofrecer una misión que no es repetible")
	# fallarla: se pasa el plazo y Quique viene a cobrar ya
	gs.misiones.erase("quique_el_nano/el_paquete_para_txell")
	quique.debt = 0
	gs.debt = 0
	world.interactions.for_npc(quique).filter(func(a): return a["label"].begins_with("Misión"))[0]["do"].call()
	misiones.activas()[0]["until"] = gs.now() - 1.0
	world.errands.update()
	_check(misiones.activas().is_empty() and quique.debt == 60 and quique.grudge() == "cobrar", "fallar el paquete no hace que Quique venga a cobrar")
	# abrir el paquete también la falla
	gs.misiones.erase("quique_el_nano/el_paquete_para_txell")
	quique.debt = 0
	gs.debt = 0
	gs.inventory.erase("paquete")
	world.interactions.for_npc(quique).filter(func(a): return a["label"].begins_with("Misión"))[0]["do"].call()
	world.use_item("paquete")
	_check(misiones.activas().is_empty() and quique.debt == 60, "abrir el paquete de Quique no falla la misión")
	quique.debt = 0
	gs.debt = 0
	# el cajero de Antonio: convencer a la agente Mas con los papeles del albergue
	offer = world.interactions.for_npc(antonio).filter(func(a): return a["label"].begins_with("Misión «El cajero de Antonio»"))
	_check(offer.size() == 1, "Antonio no ofrece «El cajero de Antonio»")
	if offer.is_empty():
		return
	offer[0]["do"].call()
	var acts = world.interactions.for_npc(mas).filter(func(a): return a["label"].begins_with("Convencerle"))
	_check(acts.size() == 1, "sin papeles, a la agente Mas solo se le puede mentir")
	gs.add_item("papeles_albergue")
	acts = world.interactions.for_npc(mas).filter(func(a): return a["label"].begins_with("Convencerle: enseñarle"))
	_check(acts.size() == 1, "con los papeles no se le pueden enseñar a la agente Mas")
	if not acts.is_empty():
		acts[0]["do"].call()
	_check(gs.misiones.get("antonio/el_cajero_de_antonio", {}).get("estado", "") == "hecho", "enseñarle los papeles no cumple la misión")
	gs.heat = 100.0
	_check(mas.vista_gorda() and mas.grudge() == "", "la agente Mas no hace la vista gorda")
	_check(world.interactions.for_npc(antonio).any(func(a): return a["label"] == "Preguntarle qué ha visto"), "Antonio no te cuenta lo que ve")
	gs.heat = 0.0
	# mentirle y que no cuele: te ficha
	gs.misiones.erase("antonio/el_cajero_de_antonio")
	gs.favores.erase("agent_mas")
	world.interactions.for_npc(antonio).filter(func(a): return a["label"].begins_with("Misión"))[0]["do"].call()
	misiones.mentira_pillada(mas, misiones.activas()[0])
	_check(gs.is_wanted() and gs.misiones["antonio/el_cajero_de_antonio"]["estado"] == "fallado", "mentirle a la agente Mas y que no cuele no te ficha")
	gs.wanted_until = -1.0
	gs.inventory.erase("papeles_albergue")
	print("  misiones: OK")


## Un propósito para cada yonki: el de Paco (recuperar a Laia), paso a paso hasta el final
## «CUMPLIDO», que deja relevo y queda en la historia; luego el de Don Ramón, perdido para siempre.
func _test_proposito() -> void:
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.censo.pausado = true
	var prop = world.proposito
	_check(gs.proposito.get("estado", "") == "activo" and gs.proposito["paso"] == 0, "propósito: Paco no empieza con el suyo")
	_check(world.errands.notebook_entries()[0]["text"].contains("Tu propósito"), "propósito: no sale en la libreta")
	# paso 1: tres días sin emborracharse (un día con litrona no cuenta)
	_steady(gs)
	gs.dignity = 80.0
	for id in gs.subs:
		gs.subs[id]["high"] = 0.0
	gs.subs["litrona"]["high"] = 50.0
	prop.update()
	_check(not gs.proposito["hoy_ok"], "propósito: emborracharse no rompe el día")
	prop.nuevo_dia()
	_check(gs.proposito["racha"] == 0, "propósito: un día borracho cuenta")
	gs.subs["litrona"]["high"] = 0.0
	for i in 3:
		prop.update()
		prop.nuevo_dia()
	_check(gs.proposito["paso"] == 1, "propósito: tres días limpio no pasan al siguiente paso (%s)" % gs.proposito)
	# paso 2: ingresar 100 € en el cajero, en dos veces
	var cajero: Dictionary = world.city.pois_of_kind("cajero")[0]
	gs.caida = 50.0  # (empezando de cero no puede bajar)
	var caida: float = gs.caida
	gs.money = 30
	var ingresar = world.interactions.for_poi(cajero).filter(func(a): return a["label"].begins_with("Ingresar para la pensión de Laia: 30"))
	_check(ingresar.size() == 1, "propósito: no se puede ingresar en el cajero")
	if not ingresar.is_empty():
		ingresar[0]["do"].call()
	_check(gs.proposito["progreso"] == 30 and gs.money == 0, "propósito: ingresar no cuenta o no cuesta")
	gs.money = 200
	world.interactions.for_poi(cajero).filter(func(a): return a["label"].begins_with("Ingresar para la pensión"))[0]["do"].call()
	_check(gs.proposito["paso"] == 2 and gs.money == 130, "propósito: los 100 € no pasan al siguiente paso")
	# paso 3: comer con Laia, sereno, de 13 a 15
	var kebab: Dictionary = world.city.pois_of_kind("kebab")[0]
	gs.minute_of_day = 10.0 * 60.0
	_check(world.interactions.for_poi(kebab).any(func(a): return a["label"].begins_with("Comer con Laia (de 13")), "propósito: la cita no dice la hora")
	gs.minute_of_day = 13.0 * 60.0 + 30.0
	for id in gs.subs:
		gs.subs[id]["high"] = 0.0
	var comer = world.interactions.for_poi(kebab).filter(func(a): return a["label"] == "Comer con Laia")
	_check(comer.size() == 1, "propósito: no se puede comer con Laia a su hora")
	if not comer.is_empty():
		comer[0]["do"].call()
	_check(not gs.alive and gs.ending_title == "CUMPLIDO" and gs.destino == "cumplido", "propósito: cumplirlo no es un final")
	_check(gs.caida < caida, "propósito: avanzar no baja la caída")
	_check(not gs.historia.is_empty() and gs.historia[-1]["proposito_estado"] == "hecho", "propósito: no queda en la historia")
	# relevo: Don Ramón, con el suyo; Paco se queda de vecino
	world.relevo("jubilado")
	_check(gs.alive and gs.proposito.get("estado", "") == "activo" and gs.proposito["paso"] == 0, "propósito: el relevo no empieza el suyo")
	_check(world.censo.registros.any(func(r): return r["kind"] == "vecino" and r["name"] == "Paco"), "propósito: Paco no se queda en el barrio de vecino")
	# el de Don Ramón: con la dignidad por los suelos, los nietos dejan de llamar para siempre
	gs.dignity = 20.0
	prop.update()
	_check(gs.proposito["estado"] == "perdido" and "proposito_perdido" in gs.milestones, "propósito: perderlo no es un hito")
	_check(world.errands.notebook_entries()[0]["text"].contains("Ya no puede ser"), "propósito: la libreta no dice que se ha perdido")
	_check(load("res://scripts/partida.gd")._estado(world).has("proposito"), "propósito: no se guarda en la partida")
	print("  propósitos: OK")


## Partidas guardadas: se guarda a media partida (con un encargo en marcha, un vecino que te
## recuerda, lo hablado con la IA...), se carga en un mundo nuevo y todo coincide.
func _test_partida() -> void:
	var gs = root.get_node("GameState")
	var Pa = load("res://scripts/partida.gd")
	gs.new_game(Defs.PROFILES[1]["id"])
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.censo.pausado = true
	_steady(gs)
	gs.money = 123
	gs.add_item("bici")
	gs.add_item("speed", 2)
	gs.day = 3
	gs.minute_of_day = 15.0 * 60.0 + 20.0
	gs.milestone("chivato")
	gs.mark_wanted("prueba de la partida", "hurto")
	gs.apartados["vera"] = INF
	gs.favores = {"txell": {"curar": INF}}
	gs.misiones = {"antonio/el_cajero_de_antonio": {"estado": "hecho", "dia": 2}}
	var npc = _fresh(world, "vecino")
	npc.remember("ayudado")
	npc.remember("ayudado")
	npc.consumo = {"id": "litrona", "enganche": 33.0, "colocon": 20.0, "mono": 5.0, "dosis": 1, "t": gs.now()}
	var name: String = npc.display_name
	var dealer = _npc_of(world, "camello")
	dealer.known = true
	dealer.debt = 0
	dealer.remove_meta("encargo_dia")
	dealer.remove_meta("enemigo")
	var offer = world.interactions.for_npc(dealer).filter(func(a): return a["label"].begins_with("Encargo:"))
	_check(not offer.is_empty(), "partida: el camello no ofrece su encargo")
	if not offer.is_empty():
		offer[0]["do"].call()
	var dealer_name: String = dealer.display_name
	world.conversation._memory["yonki|Paco"] = {"messages": [{"role": "user", "content": "Hola"}], "facts": ["Le has caído bien"]}
	var cell: Vector2i = world.player.cell
	var regs: int = world.censo.registros.size()
	var path := "user://partidas/prueba_humo.json"
	_check(Pa.guardar(world, path) == OK, "partida: no se guarda")
	_check(not Pa.cabecera(path).is_empty() and Pa.cabecera(path)["dia"] == 3, "partida: la cabecera no dice el día")
	gs.money = 0
	_check(Pa.cargar(path), "partida: no se carga")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	world = current_scene
	world.censo.pausado = true
	_check(gs.money == 123 and gs.inventory.get("speed", 0) == 2 and gs.has_item("bici"), "partida: no vuelven el dinero o el inventario")
	_check(gs.day == 3 and gs.hour() == 15 and "chivato" in gs.milestones and gs.is_wanted(), "partida: no vuelven el día, la hora, los hitos o el fichaje")
	_check(gs.apartados.get("vera", 0.0) == INF and gs.favores["txell"]["curar"] == INF and gs.misiones.has("antonio/el_cajero_de_antonio"),
		"partida: no vuelven los detenidos, los favores o las misiones")
	_check(world.player.cell == cell, "partida: no vuelves a donde estabas")
	_check(world.censo.registros.size() == regs, "partida: el censo no es el mismo (%d de %d)" % [world.censo.registros.size(), regs])
	var found := false
	for r in world.censo.registros:
		if r["kind"] == "vecino" and r["name"] == name:
			var mem: Dictionary = r["npc"].memory if r["npc"] != null else r["estado"].get("memory", {})
			var con: Dictionary = r["npc"].consumo if r["npc"] != null else r["estado"].get("consumo", {})
			if mem.get("ayudado", 0) == 2 and con.get("id", "") == "litrona":
				found = true
	_check(found, "partida: el vecino al que ayudaste no se acuerda (o no consume lo suyo)")
	var active: Array = gs.errands.filter(func(e): return e["state"] == "activo")
	_check(active.size() == 1 and is_instance_valid(active[0]["giver"]) and active[0]["giver"].display_name == dealer_name,
		"partida: el encargo en marcha no vuelve con quien te lo dio")
	if not active.is_empty() and is_instance_valid(active[0]["giver"]):
		_check(world.errands.marker_for(active[0]["giver"]) == "★", "partida: quien te dio el encargo no lleva la estrella")
	_check(not gs.notes.is_empty() and is_same(gs.notes[-1]["errand"], gs.errands[-1]), "partida: la libreta no apunta a sus encargos")
	_check(world.conversation._memory.has("yonki|Paco"), "partida: no vuelve lo hablado con la IA")
	_check(Pa.pendiente.is_empty(), "partida: queda algo por aplicar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("  partida guardada y cargada: OK")


## Fase 3: relaciones entre personajes y misiones encadenadas y cruzadas. Te chivas de Vera
## por el pasaporte de Grzegorz (El Mudo se entera y ya no te vende el acordeón; sin Vera,
## nadie le roba a Margit por el camino), el Sr. Feliu o Pol (una u otra), las pruebas del
## piso de Quique para Serra (Quique detenido, La Rubia a por ti) y Joy (Rosi, Ortega).
func _test_cadenas(gs, world) -> void:
	var misiones = world.misiones
	var R = load("res://scripts/relaciones.gd")
	var ids: Array = world._personajes.map(func(d): return d["id"])
	for d in world._personajes:
		for a in R.comprobar(d, ids):
			_check(not a[0], "relaciones de %s: %s" % [d["nombre"], a[1]])
	var need := ["grzegorz", "vera", "xavi", "el_mudo", "vasile", "margit", "sr_feliu", "pol", "sra_encarna",
		"quique_el_nano", "agent_serra", "la_rubia", "rosi", "joy", "agent_ortega"]
	var n := {}
	for pid in need:
		n[pid] = misiones.npc_de(pid)
		if n[pid] == null:
			print("  cadenas: sin %s, no se prueban" % pid)
			return
		n[pid].known = true
		n[pid].memory = {}
		n[pid].debt = 0
		for meta in ["enemigo", "venganza", "receloso"]:
			n[pid].remove_meta(meta)
	_steady(gs)
	gs.errands = []
	gs.notes = []
	gs.misiones = {}
	gs.favores = {}
	gs.apartados = {}
	gs.heat = 0.0
	gs.wanted_until = -1.0
	gs.arrests = 0
	gs.money = 300
	gs.debt = 0
	gs.dignity = 80.0
	gs.minute_of_day = 12.0 * 60.0
	for id in ["pasaporte", "acordeon", "pruebas_piso", "bici"]:
		gs.inventory.erase(id)
	# el pasaporte: se le puede comprar a Vera; te chivas a Xavi
	_take(world, n["grzegorz"], "Misión «El pasaporte de Grzegorz»")
	_check(_labels(world, n["vera"]).any(func(l): return l.begins_with("Comprarle: pasaporte")), "cadenas: Vera no te vende el pasaporte")
	_check(_labels(world, n["vera"]).any(func(l): return l.begins_with("Robarle: pasaporte")), "cadenas: no se le puede robar el pasaporte a Vera")
	_take(world, n["xavi"], "Chivarte: Vera")
	_check(gs.has_item("pasaporte") and misiones.apartado("vera"), "cadenas: chivarte no te da el pasaporte ni detiene a Vera")
	_check(world.censo.registros.filter(func(r): return r["personaje"].get("id", "") == "vera" and r["npc"] != null).is_empty(), "cadenas: Vera detenida sigue en la calle")
	_check(n["el_mudo"].remembers("oido_mal") > 0 and n["xavi"].remembers("oido_bien") > 0, "cadenas: los amigos y enemigos de Vera no se enteran")
	_take(world, n["grzegorz"], "Darle: pasaporte")
	_check(_estado(gs, "grzegorz/el_pasaporte_de_grzegorz") == "hecho" and gs.has_item("bici"), "cadenas: darle el pasaporte no cumple ni te da la bici")
	# el acordeón: El Mudo ya no se fía (no te lo vende), pero se le puede robar
	_take(world, n["vasile"], "Misión «El acordeón de Vasile»")
	var mudo: Array = _labels(world, n["el_mudo"])
	_check(not mudo.any(func(l): return l.begins_with("Comprarle")) and mudo.any(func(l): return l.begins_with("Robarle: acordeón")),
		"cadenas: El Mudo te vende el acordeón aunque te chivaste de Vera %s" % [mudo])
	_check(n["el_mudo"].grudge() in ["aparta", "venganza"], "cadenas: El Mudo no se aparta de ti")
	# Margit: sin Vera, nadie os acecha; va contigo y se cumple al llegar al bar con ella
	_take(world, n["margit"], "Misión «El bar de 1979»")
	var e: Dictionary = misiones.activas().filter(func(x): return x["key"] == "margit/el_bar_de_1979")[0]
	n["margit"].setup(world.city, world.player.cell)
	misiones.update()
	_check(n["margit"].mode == "acompana", "cadenas: Margit no va contigo")
	var money: int = gs.money
	var llegar = misiones.actions_for_poi(e).filter(func(a): return a["label"].begins_with("Llegar aquí"))
	_check(llegar.size() == 1, "cadenas: no se puede llegar al bar con Margit")
	if not llegar.is_empty():
		llegar[0]["do"].call()
	_check(_estado(gs, "margit/el_bar_de_1979") == "hecho" and gs.money == money + 60 and n["margit"].mode == "", "cadenas: llegar con Margit no paga o no la suelta")
	# el Sr. Feliu o Pol: una u otra
	_check(_labels(world, n["pol"]).any(func(l): return l.begins_with("Misión «El edificio del Sr. Feliu»")), "cadenas: Pol no ofrece su misión")
	_take(world, n["sr_feliu"], "Misión «Que no me echen»")
	e = misiones.activas().filter(func(x): return x["key"] == "sr_feliu/que_no_me_echen")[0]
	misiones.actions_for_poi(e)[0]["do"].call()  # esperar a la cita y cumplirla
	_check(_estado(gs, "sr_feliu/que_no_me_echen") == "hecho", "cadenas: la cita con el Sr. Feliu no se cumple")
	_check(not _labels(world, n["pol"]).any(func(l): return l.begins_with("Misión")), "cadenas: Pol sigue ofreciendo su misión después de ayudar a Feliu")
	_check(n["sra_encarna"].remembers("oido_bien") > 0, "cadenas: la Sra. Encarna no se entera de que ayudaste a Feliu")
	# las pruebas del piso: si Quique te pilla, va a por ti; si no, a Serra
	var hecho := false
	for i in 12:
		gs.misiones.erase("sra_encarna/las_pruebas_del_piso")
		n["quique_el_nano"].remove_meta("venganza")
		n["quique_el_nano"].remove_meta("enemigo")
		_steady(gs)
		_take(world, n["sra_encarna"], "Misión «Las pruebas del piso»")
		_take(world, n["quique_el_nano"], "Espiarle")
		if _estado(gs, "sra_encarna/las_pruebas_del_piso") == "hecho":
			hecho = true
			break
		_check(n["quique_el_nano"].grudge() == "venganza", "cadenas: Quique te pilla espiando y no va a por ti")
	_check(hecho and gs.has_item("pruebas_piso"), "cadenas: espiar a Quique nunca sale bien")
	if hecho:
		n["quique_el_nano"].add_debt(30, 12.0)
		gs.debt = 30
		_take(world, n["agent_serra"], "Misión «El piso de Quique»")
		_take(world, n["agent_serra"], "Darle: pruebas")
		_check(misiones.apartado("quique_el_nano") and gs.debt == 0, "cadenas: Serra no detiene a Quique o no se va tu deuda")
		_check(n["la_rubia"].grudge() == "venganza", "cadenas: La Rubia no va a por ti")
	# Joy: vigilar con Rosi, convencer a Joy (Ortega) y testigo en comisaría
	for i in 12:
		if _estado(gs, "rosi/que_joy_no_trabaje_sola") == "hecho":
			break
		gs.misiones.erase("rosi/que_joy_no_trabaje_sola")
		gs.minute_of_day = 20.0 * 60.0
		_steady(gs)
		_take(world, n["rosi"], "Misión «Que Joy no trabaje sola»")
		_take(world, n["rosi"], "Hacerle de vigía")
	_check(_estado(gs, "rosi/que_joy_no_trabaje_sola") == "hecho", "cadenas: vigilar para Rosi nunca sale bien")
	for i in 12:
		if _estado(gs, "agent_ortega/la_denuncia_de_joy") == "hecho":
			break
		gs.misiones.erase("agent_ortega/la_denuncia_de_joy")
		n["joy"].remove_meta("enemigo")
		gs.dignity = 90.0
		gs.sanity = 90.0
		_take(world, n["agent_ortega"], "Misión «La denuncia de Joy»")
		_take(world, n["joy"], "Convencerle")
	_check(_estado(gs, "agent_ortega/la_denuncia_de_joy") == "hecho", "cadenas: nunca se convence a Joy")
	gs.wanted_until = -1.0
	gs.arrests = 0
	_take(world, n["agent_ortega"], "Misión «Testigo en comisaría»")
	e = misiones.activas().filter(func(x): return x["key"] == "agent_ortega/testigo_en_comisaria")[0]
	misiones.actions_for_poi(e)[0]["do"].call()
	_check(_estado(gs, "agent_ortega/testigo_en_comisaria") == "hecho" and gs.arrests == 0, "cadenas: ir de testigo no se cumple (o te detienen sin estar fichado)")
	_check(misiones.favor("rosi", "soplo"), "cadenas: Rosi no te hace el favor después del juicio")
	_steady(gs)
	gs.apartados = {}
	print("  relaciones y misiones encadenadas: OK")


func _labels(world, npc) -> Array:
	return world.interactions.for_npc(npc).map(func(a): return a["label"])


## Hace la acción del menú de `npc` que empieza por `prefix` (y falla si no la hay).
func _take(world, npc, prefix: String) -> void:
	for a in world.interactions.for_npc(npc):
		if a["label"].begins_with(prefix):
			a["do"].call()
			return
	_check(false, "%s no tiene la acción «%s...» %s" % [npc.display_name, prefix, _labels(world, npc)])


func _estado(gs, key: String) -> String:
	return gs.misiones.get(key, {}).get("estado", "")


## La pestaña de misiones del diseñador de personajes: monta los paneles de las misiones de
## ejemplo y de cada tipo de objetivo y de resultado sin errores (no guarda nada).
func _test_editor() -> void:
	change_scene_to_file("res://editor/editor_personajes.tscn")
	await process_frame
	await process_frame
	var ed = current_scene
	# (cargados a mano: ver la nota de _initialize sobre las clases que usan el autoload)
	var P = load("res://scripts/personajes.gd")
	var M = load("res://scripts/misiones.gd")
	ed._editar(P.cargar(P.DIR + "quique_el_nano.json"), "quique_el_nano")
	_check(ed._comprobar().all(func(a): return not a[0]), "editor: Quique tiene errores")
	var m: Dictionary = M.nueva()
	m["titulo"] = "Prueba"
	m["id"] = "prueba"
	ed._def["misiones"].append(m)
	for tipo in M.OBJETIVOS:
		m["objetivo"]["tipo"] = tipo
		m["objetivo"]["personaje"] = "txell"
		m["exito"]["efectos"] = M.EFECTOS.keys().map(func(t): return M.efecto(t))
		ed._rehacer_misiones()
		await process_frame
	_check(ed._misiones_box.get_child_count() == 2, "editor: no salen los paneles de las misiones")
	_check(ed._comprobar().any(func(a): return a[1].contains("le falta qué")), "editor: no avisa de los resultados a medias")
	# relaciones y esquema de las cadenas
	ed._editar(P.cargar(P.DIR + "vera.json"), "vera")
	_check(ed._comprobar().all(func(a): return not a[0]), "editor: Vera tiene errores %s" % [ed._comprobar()])
	ed._def["relaciones"].append(P.nueva_relacion())
	ed._rehacer_relaciones()
	await process_frame
	_check(ed._comprobar().any(func(a): return a[1].contains("relación sin personaje")), "editor: no avisa de una relación sin personaje")
	ed._rehacer_esquema()
	var cajas: Array = ed._esquema.cajas()
	_check(cajas.size() >= 12, "editor: el esquema no tiene todas las misiones (%d)" % cajas.size())
	_check(cajas.any(func(c): return c["key"] == "agent_serra/el_piso_de_quique" and c["tras"] == "sra_encarna/las_pruebas_del_piso"),
		"editor: el esquema no encadena «El piso de Quique» tras «Las pruebas del piso»")
	ed._esquema.queue_redraw()
	await process_frame
	print("  editor de misiones, relaciones y esquema: OK")


## El diseñador de sustancias: monta todas las tablas, un retoque cambia el valor (con su
## tipo) y quitarlo lo devuelve al de Defs; y Equilibrio pone los retoques encima de una tabla.
## No toca data/equilibrio.json.
func _test_sustancias() -> void:
	change_scene_to_file("res://editor/editor_sustancias.tscn")
	await process_frame
	await process_frame
	var ed = current_scene
	_check(ed._tabs.get_tab_count() == ed.PESTANAS.size(), "sustancias: faltan pestañas")
	_check(ed._celdas.all(func(r): return not r.is_empty()), "sustancias: hay una pestaña sin columnas")
	ed._ajustes = {}
	ed._retocar("sustancias", "speed", "price", 9.0)
	_check(ed._valor("sustancias", "speed", "price") is int and ed._valor("sustancias", "speed", "price") == 9, "sustancias: el retoque del precio no vale")
	ed._retocar("sustancias", "speed", "fx.psico", 0.5)
	ed._retocar("habitos", "yonki", "enganche.1", 95.0)
	_check(ed._ajustes["habitos"]["yonki"]["enganche"]["1"] == 95.0, "sustancias: no se retoca dentro de una lista")
	ed._retocar("sustancias", "speed", "price", float(Defs.SUBSTANCES["speed"]["price"]))
	_check(not ed._ajustes["sustancias"]["speed"].has("price"), "sustancias: volver al valor de Defs no quita el retoque")
	ed._retocar("sustancias", "speed", "fx.psico", null)
	_check(not ed._ajustes.has("sustancias"), "sustancias: no se limpian los retoques vacíos")
	var tabla := {"a": {"n": 1, "fx": {"x": 0.5}, "l": [10.0, 20.0]}}
	Equilibrio.mezclar(tabla, {"a": {"n": 3.0, "fx": {"y": 0.2}, "l": {"1": 25.0}}, "b": {"n": 1}})
	_check(tabla["a"]["n"] is int and tabla["a"]["n"] == 3 and tabla["a"]["fx"]["y"] == 0.2 and tabla["a"]["l"][1] == 25.0,
		"sustancias: Equilibrio no mezcla bien %s" % [tabla])
	_check(not tabla.has("b") or tabla["b"] is Dictionary, "sustancias: Equilibrio rompe con ids nuevos")
	ed._sucio = false
	ed._quitar_pestana()
	await process_frame
	print("  diseñador de sustancias: OK")


## Visión en cono tapada por los edificios, memoria de cada personaje, policía que solo
## persigue si te ve, escándalo al robar, camellos que cobran y robados que te reconocen.
func _test_vision(gs, world) -> void:
	var city = world.city
	var player = world.player
	_steady(gs)
	gs.heat = 0.0
	gs.wanted_until = -1.0
	gs.money = 50
	for npc in world.npcs:
		npc.calm_down()
	# una calle recta de 7 casillas y dos casillas de calle con un edificio en medio
	var line := _find_line(city, 7)
	var wall := _find_wall(city)
	_check(line.size() == 2 and wall.size() == 2, "no hay calle recta o pared para probar la visión")
	if line.size() < 2 or wall.size() < 2:
		return
	_check(city.line_of_sight(line[0], line[1]) and not city.line_of_sight(wall[0], wall[1]), "la línea de visión no ve la calle o atraviesa edificios")
	var cop = world.npcs.filter(func(n): return n.kind == "urbano")[0]
	# delante y en la calle: lo ve; a la espalda o tras la pared, no
	_place(cop, line[0], line[1])
	player.setup(city, line[1])
	_check(cop.can_see(player) and world.police_watching() >= 1, "un agente no ve lo que tiene delante")
	_place(cop, line[0] + Vector2i(3, 0), line[1])
	player.setup(city, line[0])
	_check(not cop.can_see(player), "un agente ve a su espalda")
	_place(cop, wall[0], wall[1])
	player.setup(city, wall[1])
	_check(not cop.can_see(player), "un agente ve a través de los edificios")
	# la policía no persigue por estar cerca: solo si te ve y estás fichado (o muy buscado)
	_place(cop, line[0], line[1])
	player.setup(city, line[1])
	cop.perceive(3.0)
	_check(cop.mode == "", "la policía te persigue sin motivo")
	gs.mark_wanted("prueba")
	_place(cop, wall[0], wall[1])
	player.setup(city, wall[1])
	cop.perceive(3.0)
	_check(cop.mode == "" and cop.alert == 0.0, "la policía te persigue sin verte")
	_place(cop, line[0], line[1])
	player.setup(city, line[1])
	cop.perceive(3.0)
	_check(cop.mode == "persigue" and cop.chase_reason == "policia", "fichado y a la vista, la policía no te persigue")
	# si te pierde de vista, busca donde te vio y, si no te encuentra, te quedas fichado
	gs.wanted_until = -1.0
	gs.heat = 80.0
	player.setup(city, wall[1])
	_place(cop, wall[0], wall[1])
	cop.start_chase("policia")
	cop.perceive(0.25)
	cop._follow_mode(Defs.LOSE_SIGHT_TIME + 0.1)
	_check(cop.mode == "busca", "la policía no va a buscarte donde te perdió")
	cop.stop()
	cop._follow_mode(Defs.SEARCH_TIME * 2.0)
	_check(cop.mode == "" and gs.is_wanted(), "escaparte de la policía no te deja fichado")
	# el cono se dibuja (recortado por los edificios)
	cop.cone_visible = true
	cop._update_cone()
	_check(cop._cone != null and cop._cone.visible and cop._cone_mesh.get_surface_count() == 1, "no se dibuja el cono de visión")
	cop.cone_visible = false
	cop._update_cone()
	world.hud.refresh()
	_check(world.hud._wanted_label.visible, "el HUD no dice que estás fichado")
	cop.calm_down()
	cop._calm_until = 0.0
	gs.wanted_until = -1.0
	gs.heat = 0.0

	# memoria: al que le pides mucho se aparta; al que ayudas se acerca
	var guiri = _fresh(world, "turista")
	for i in Defs.BEG_ANNOY:
		_do(world, guiri, "Pedirle una moneda")
	_check(guiri.remembers("pedido") == Defs.BEG_ANNOY and guiri.grudge() == "aparta", "no se acuerda de que le has pedido")
	_place(guiri, line[0], line[1])
	player.setup(city, line[1])
	guiri.perceive(3.0)
	_check(guiri.mode == "aparta", "al que le has pedido mucho no se aparta al verte")
	var kid = _fresh(world, "chaval")
	_do(world, kid, "Darle un euro")
	_place(kid, line[0], line[1])
	kid.perceive(3.0)
	_check(kid.remembers("ayudado") == 1 and kid.mode == "acerca", "al que has ayudado no se acerca")
	var yonki = _fresh(world, "yonki")
	_do(world, yonki, "Pelearte con él")
	_check(yonki.grudge() == "aparta", "al que le has pegado no se aparta")

	# robados que te reconocen: unos van a por lo suyo, otros a por un agente
	var avenger = null
	var snitch = null
	for name in load("res://scripts/actors/npc.gd").KINDS["turista"]["names"]:
		var t = _fresh(world, "turista")
		t.display_name = name
		if t.avenger() and avenger == null:
			avenger = t
		elif not t.avenger() and snitch == null:
			snitch = t
	_check(avenger != null and snitch != null, "todos los turistas reaccionan igual al reconocerte")
	if avenger and snitch:
		avenger.remember("robado")
		_place(avenger, line[0], line[1])
		avenger.perceive(3.0)
		_check(avenger.mode == "persigue" and avenger.chase_reason == "venganza", "el turista robado no va a por ti")
		gs.add_item("cartera")
		var n: int = gs.inventory.get("cartera", 0)
		avenger._follow_mode(0.25)  # está a menos de dos casillas: te alcanza
		player.setup(city, avenger.cell)
		avenger._follow_mode(0.25)
		_check(gs.inventory.get("cartera", 0) == n - 1 and avenger.mode == "", "el turista que te alcanza no recupera lo suyo")
		snitch.remember("robado")
		player.setup(city, line[1])
		_place(snitch, line[0], line[1])
		snitch.perceive(3.0)
		_check(snitch.mode == "denuncia", "el turista robado no busca a un agente")
		cop.setup(city, snitch.cell)
		snitch._denounce_to = cop
		snitch._follow_mode(0.25)
		_check(snitch.mode == "" and cop.mode == "busca" and gs.is_wanted(), "la denuncia no llega a la policía")
	cop.calm_down()
	gs.wanted_until = -1.0

	# camellos: con la deuda vencida te persiguen y te cobran; sin dinero, paliza
	var dealer = _fresh(world, "camello")
	dealer.add_debt(10, Defs.DEBT_GRACE_HOURS)
	_check(dealer.grudge() == "", "el camello viene a cobrar antes de tiempo")
	dealer.debt = 0
	dealer.add_debt(20, 0.0)
	gs.debt = 20
	_place(dealer, line[0], line[1])
	player.setup(city, line[1])
	dealer.perceive(3.0)
	_check(dealer.mode == "persigue" and dealer.chase_reason == "deuda", "el camello al que debes no va a por ti")
	gs.money = 50
	player.setup(city, dealer.cell)
	dealer._follow_mode(0.25)
	_check(gs.money == 30 and dealer.debt == 0 and gs.debt == 0, "el camello no se cobra la deuda")
	dealer.add_debt(20, 0.0)
	gs.money = 0
	var health: float = gs.health
	dealer.chase_reason = "deuda"
	world._on_caught(dealer)
	_check(gs.health < health and dealer.grudge() == "", "sin dinero, el camello no te pega (o vuelve enseguida)")
	_steady(gs)

	# escándalo: si lo oye un agente, viene; si no, quedas fichado; unos valientes te paran
	var brave = null
	var caller = null
	for kind in ["vecino", "turista"]:
		for name in load("res://scripts/actors/npc.gd").KINDS[kind]["names"]:
			var b = _fresh(world, kind)
			b.display_name = name
			if b.temper() == "valiente" and brave == null:
				brave = b
			elif b.temper() == "llama" and caller == null:
				caller = b
	_check(brave != null and caller != null, "nadie es valiente o nadie llama a la policía")
	var victim = _fresh(world, "turista")
	player.setup(city, line[1])
	for b in [victim, brave, caller]:
		if b:
			b.setup(city, line[0])
			b.calm_down()
	cop.setup(city, line[0])
	gs.heat = 0.0
	world.scandal(victim, "THIEF! ¡Al ladrón!")
	_check(cop.mode == "busca" and not gs.is_wanted() and gs.heat > Defs.CHASE_HEAT, "el agente que oye el escándalo no viene")
	if brave:
		_check(brave.mode == "persigue" and brave.chase_reason == "parar", "el valiente no intenta pararte")
		world._on_caught(brave)
		_check(world._grabbed > 0.0, "el valiente que te alcanza no te agarra")
	var police: Array = world.npcs.filter(func(n): return n.is_police())
	for p in police:
		world.npcs.erase(p)
	for b in [victim, brave, caller]:
		if b:
			b.calm_down()
	world.scandal(victim, "THIEF! ¡Al ladrón!")
	_check(gs.is_wanted(), "sin policía que lo oiga, no quedas fichado")
	world.npcs.append_array(police)
	# un robo a la vista de un testigo acaba en escándalo; y la víctima se acuerda de ti
	gs.wanted_until = -1.0
	for p in police:
		p.calm_down()
		p.setup(city, wall[0])
	var mark = _fresh(world, "turista")
	mark.setup(city, line[1])
	if caller:
		_place(caller, line[0], line[1])
		caller.calm_down()
		world.interactions._after_theft(mark)
		_check(mark.remembers("robado") == 1, "robar a la vista de un testigo no se sabe")
	world._grabbed = 0.0
	for npc in world.npcs:
		npc.calm_down()
	gs.wanted_until = -1.0
	gs.heat = 0.0
	print("  visión, memoria y escándalo: OK")


## Los bots también consumen (scripts/consumo.gd): su sustancia es siempre la misma para el
## mismo nombre; sin nada encima les sube el mono y vienen a pedirte, comprarte o darte el
## tirón; colocados cabecean o buscan bronca; el censo los pone al día al despertarlos.
## Speed y MDMA: se venden, se compran y tienen sus efectos de pantalla.
func _test_consumo(gs, world) -> void:
	var C = load("res://scripts/consumo.gd")  # (ver la nota de _initialize sobre el autoload)
	_steady(gs)
	gs.heat = 0.0
	gs.wanted_until = -1.0
	_check(C.habito("yonki", "Paco", {}) == C.habito("yonki", "Paco", {}), "consumo: el mismo yonki cambia de sustancia")
	var ids := {}
	for i in 200:
		var id: String = C.habito("fiestero", "Fiestero %d" % i, {})
		ids[id] = ids.get(id, 0) + 1
	_check(ids.has("mdma") and ids.has("litrona"), "consumo: las despedidas no consumen lo suyo %s" % ids)
	_check(C.habito("chaval", "Nadie", {}) == "" and C.habito("urbano", "Nadie", {}) == "", "consumo: los chavales o la policía consumen")
	_check(C.habito("vecino", "X", {"stats": {"quiere": ["caballo"]}}) == "caballo", "consumo: un personaje no consume lo que quiere")
	# sin nada encima y sin dinero, le sube el mono hasta pedirte
	var npc = _fresh(world, "yonki")
	npc.money = 100
	npc.consumo = {"id": "caballo", "enganche": 80.0, "colocon": 0.0, "mono": 0.0, "dosis": 0, "t": gs.now()}
	var price0: int = world.trade.price_for(npc, "caballo")
	C.avanzar(npc.consumo, 600.0, 0)
	_check(C.necesita(npc.consumo) and C.estado(npc.consumo) == "mono", "consumo: sin nada encima no le sube el mono (%s)" % npc.consumo)
	_check(npc.grudge() == "pide", "consumo: con mono no viene a pedirte (%s)" % npc.grudge())
	_check(world.trade.price_for(npc, "caballo") > price0, "consumo: con mono no paga más")
	gs.add_item("caballo", 2)
	var sale = world.interactions.for_npc(npc).filter(func(a): return a["label"].begins_with("Venderle caballo ("))
	_check(sale.size() == 1, "consumo: con mono no te compra lo suyo")
	if not sale.is_empty():
		sale[0]["do"].call()
	_check(C.estado(npc.consumo) == "colocado", "consumo: no se mete lo que le vendes")
	_check(C.cabecea(npc.consumo) or C.intensidad(npc.consumo) < 0.7, "consumo: colocado de caballo no cabecea")
	npc.pasa_consumo()
	_check(npc.slow_factor < 1.0, "consumo: con caballo no va más lento")
	# darle una dosis a quien tiene mono
	npc.consumo["colocon"] = 0.0
	npc.consumo["mono"] = 80.0
	var gift = world.interactions.for_npc(npc).filter(func(a): return a["label"].begins_with("Darle caballo"))
	_check(gift.size() == 1, "consumo: no se le puede dar una dosis a quien tiene mono")
	if not gift.is_empty():
		gift[0]["do"].call()
	_check(npc.remembers("ayudado") > 0 and npc.consumo["mono"] < 80.0, "consumo: darle una dosis no le alivia ni se acuerda")
	# el tirón: con mono a tope y sin dinero
	npc.consumo["colocon"] = 0.0
	npc.consumo["mono"] = 95.0
	npc.money = 0
	var tiron := false
	for i in 30:
		var y = _fresh(world, "yonki")
		y.money = 0
		y.consumo = {"id": "caballo", "enganche": 80.0, "colocon": 0.0, "mono": 95.0, "dosis": 0, "t": gs.now()}
		if y.grudge() == "tiron":
			tiron = true
			gs.add_item("caballo")
			var had: int = gs.inventory.get("caballo", 0)
			world._tiron(y)
			_check(gs.inventory.get("caballo", 0) == had - 1 and y.consumo["dosis"] == 1, "consumo: el tirón no se lleva lo suyo")
			break
	_check(tiron, "consumo: nadie con mono y sin dinero da el tirón")
	# acelerado busca bronca (alguno) y pega más fuerte
	var bronca := false
	for i in 30:
		var y = _fresh(world, "yonki")
		y.consumo = {"id": "base", "enganche": 50.0, "colocon": 50.0, "mono": 0.0, "dosis": 1, "t": gs.now()}
		if y.grudge() == "bronca":
			bronca = true
			_check(world.interactions._fight_chance(y) < world.interactions._fight_chance(_fresh(world, "vecino")) + 0.01, "consumo: acelerado no pega más fuerte")
			_steady(gs)
			world._bronca(y)
			break
	_check(bronca, "consumo: nadie acelerado busca bronca")
	# el censo: al despertar a un latente, lo que le ha pasado mientras tanto
	_steady(gs)
	var r: Dictionary = world.censo.nuevo("yonki")
	var z = world.censo.despertar(r, world.player.cell)
	z.consumo = {"id": "caballo", "enganche": 70.0, "colocon": 50.0, "mono": 0.0, "dosis": 0, "t": gs.now()}
	z.money = 0  # (sin dinero no pilla: que no se vuelva a colocar mientras está latente)
	world.censo.dormir(r)
	r["estado"]["consumo"]["t"] -= 600.0
	r["visto"] -= 600.0
	z = world.censo.despertar(r, world.player.cell)
	_check(z.consumo["colocon"] < 50.0 and (z.consumo["mono"] > 0.0 or z.consumo["colocon"] > 0.0), "censo: al despertar no ha pasado el tiempo para lo que consume (%s)" % z.consumo)
	# speed y MDMA: los vende el camello, los compran las despedidas, y tienen sus efectos
	gs.money = 200
	var dealer = _npc_of(world, "camello")
	dealer.debt = 0
	var labels: Array = world.interactions.for_npc(dealer).map(func(a): return a["label"])
	_check(labels.any(func(l): return l.begins_with("Comprar Speed")) and labels.any(func(l): return l.begins_with("Comprar MDMA")), "consumo: el camello no vende speed ni MDMA (%s)" % [labels])
	_check("mdma" in Defs.CLIENTS["fiestero"]["wants"] and "speed" in Defs.CLIENTS["fiestero"]["wants"], "consumo: nadie quiere speed ni MDMA")
	for id in ["speed", "mdma"]:
		_steady(gs)
		gs.add_item(id)
		world.use_item(id)
		_check(("probar_" + id) in gs.milestones, "%s: no es un hito probarlo" % id)
		_check(gs.effects()["fx"].has("sharp" if id == "speed" else "love"), "%s: no tiene su efecto de pantalla" % id)
		gs.subs[id]["high"] = 12.0
		gs.advance(60)
		_check(gs.subs[id]["crash"] > 0.0, "%s: no da bajón" % id)
	_steady(gs)
	print("  consumo de los bots, speed y MDMA: OK")


## Las sustancias nuevas (setas, LSD, ketamina, ansiolíticos, antidepresivos, tramadol, tabaco)
## y las resacas: empiezan al dormir tras consumir, se notan y se pasan; mal viaje, mezclas de
## depresores, la receta del CAP y la farmacia, el tabaco del bar.
## Asociaciones cannábicas: están en el mapa, son una puerta sin rótulo hasta que llamas, el
## captador te hace socio del más cercano, venden con tope por día y una redada las precinta.
func _test_clubs(gs, world) -> void:
	var I = world.interactions
	var clubs: Array = world.city.pois_of_kind("club")
	_check(clubs.size() >= 10, "clubs: hay %d en el mapa" % clubs.size())
	if clubs.is_empty():
		return
	gs.alive = true
	gs.money = 200
	gs.dignity = 60.0
	gs.clubs_conocidos = []
	gs.clubs_socio = []
	gs.clubs_cerrados = {}
	gs.club_compras = {}
	var club: Dictionary = clubs[0]
	var nombre: String = club["name"]
	_check(I.poi_title(club) == "Puerta sin rótulo", "clubs: se ve el nombre sin conocerlo")
	var acts: Array = I.for_poi(club)
	_check(acts.size() == 1 and acts[0]["label"] == "Llamar al timbre", "clubs: sin conocerlo no es solo el timbre")
	acts[0]["do"].call()
	_check(nombre in gs.clubs_conocidos and I.poi_title(club).ends_with(nombre), "clubs: llamar no te lo descubre")
	_check(I.for_poi(club).any(func(a): return a["label"].begins_with("Pedir que te hagan socio")), "clubs: no se puede pedir ser socio")
	# el captador te lleva al más cercano
	var cerca: Dictionary = I._club_cercano(Vector2i(club["x"], club["y"]))
	_check(cerca.get("name", "") == nombre, "clubs: el más cercano a un club no es él mismo")
	I._hacer_socio(nombre)
	_check(nombre in gs.clubs_socio and "socio_club" in gs.milestones, "clubs: hacerse socio no cuenta")
	gs.inventory.erase("porro")
	for i in Defs.CLUB_LIMITE_DIA + 1:
		var comprar = I.for_poi(club).filter(func(a): return a["label"].begins_with("Comprar un porro"))
		if i < Defs.CLUB_LIMITE_DIA:
			_check(comprar.size() == 1, "clubs: no vende el porro %d" % (i + 1))
			if not comprar.is_empty():
				gs.clubs_cerrados = {}
				comprar[0]["do"].call()
		else:
			_check(comprar.is_empty(), "clubs: vende por encima del tope del día")
	if not gs.clubs_cerrados.has(nombre):  # (si una redada se los llevó, no hay que contarlos)
		_check(gs.inventory.get("porro", 0) == Defs.CLUB_LIMITE_DIA, "clubs: no da los porros comprados")
	gs.day += 1
	_check(I._club_hoy() == 0, "clubs: el tope no vuelve a empezar al día siguiente")
	gs.add_item("porro", 2)
	I._redada(nombre, true)
	_check(not gs.has_item("porro") and gs.clubs_cerrados.get(nombre, 0) > gs.day, "clubs: la redada no precinta ni se lleva los porros")
	_check(I.for_poi(club).size() == 1 and I.for_poi(club)[0]["label"] == "Mirar el precinto", "clubs: precintado sigue abierto")
	_check(I._club_cercano(Vector2i(club["x"], club["y"])).get("name", "") != nombre, "clubs: el captador te lleva a uno precintado")
	gs.clubs_cerrados = {}
	print("  clubs cannábicos: OK")


func _test_resacas(gs, world) -> void:
	var C = load("res://scripts/consumo.gd")
	for id in ["setas", "lsd", "ketamina", "ansioliticos", "antidepresivos", "tramadol", "tabaco"]:
		_check(Defs.SUBSTANCES.has(id) and Defs.MILESTONES.has("probar_" + id), "%s: no existe o no tiene su hito" % id)
	# resaca de litrona: no al consumir, sí al dormir; se nota y se pasa
	_steady(gs)
	gs.resacas = {}
	for id in gs.subs:
		gs.subs[id]["resaca_pend"] = 0.0
		gs.subs[id]["high"] = 0.0
		gs.subs[id]["crash"] = 0.0
	gs.add_item("litrona", 3)
	for i in 3:
		world.use_item("litrona")
	_check(gs.resacas.is_empty(), "resaca: empieza sin haber dormido")
	gs.rest(480, 1.0)
	_check(gs.resacas.has("litrona"), "resaca: tres latas y una noche no dan resaca")
	var fx: Dictionary = gs.effects()
	_check(fx["fx"].get("resaca", 0.0) > 0.0 and fx["causes"].any(func(c): return c[0].begins_with("Resaca de litrona")), "resaca: no se nota (%s)" % [fx["causes"]])
	_check(gs.vitality_max() < 100.0, "resaca: no baja la vitalidad máxima")
	var left: float = gs.resacas["litrona"]["left"]
	gs.add_item("litrona")
	world.use_item("litrona")
	_check(gs.resacas["litrona"]["left"] < left, "resaca: la del perro no la quita a medias")
	gs.advance(24 * 60)
	_check(not gs.resacas.has("litrona"), "resaca: no se pasa con las horas")
	# el caballo no da resaca (da mono)
	_steady(gs)
	gs.resacas = {}
	gs.add_item("caballo")
	world.use_item("caballo")
	gs.rest(480, 1.0)
	_check(not gs.resacas.has("caballo"), "resaca: el caballo da resaca")
	# el MDMA: martes negro, baja la mente
	_steady(gs)
	gs.resacas = {}
	gs.add_item("mdma")
	world.use_item("mdma")
	gs.subs["mdma"]["high"] = 0.0
	gs.rest(480, 1.0)
	_check(gs.resacas.has("mdma"), "resaca: el MDMA no da resaca")
	gs.sanity = 80.0
	gs.advance(120)
	_check(gs.sanity < 80.0, "resaca: la del MDMA no baja la mente")
	# mal viaje con la cabeza mal
	var trip := false
	for i in 30:
		_steady(gs)
		gs.sanity = 20.0
		gs.subs.get("lsd", {})["malviaje"] = 0.0
		gs.add_item("lsd")
		world.use_item("lsd")
		gs.subs["lsd"]["high"] = 0.0
		if gs.subs["lsd"]["malviaje"] > 0.0:
			trip = true
			break
	_check(trip and gs.effects()["causes"].any(func(c): return c[0].begins_with("Mal viaje")), "lsd: con la cabeza mal nunca hay mal viaje")
	# mezclar depresores
	_steady(gs)
	gs.add_item("litrona", 2)
	world.use_item("litrona")
	world.use_item("litrona")
	gs.add_item("ansioliticos")
	world.use_item("ansioliticos")
	_check("mezcla" in gs.milestones, "ansiolíticos: mezclarlos con alcohol no cuenta como mezcla")
	# receta del CAP y farmacia; tabaco del bar
	_steady(gs)
	gs.alive = true
	gs.money = 100
	gs._next_receta_day = 0
	gs.inventory.erase("receta")
	gs.inventory.erase("antidepresivos")
	var cap: Dictionary = world.city.pois_of_kind("cap")[0]
	var farmacia: Dictionary = world.city.pois_of_kind("farmacia")[0]
	var bar: Dictionary = world.city.pois_of_kind("bar")[0]
	var cita = world.interactions.for_poi(cap).filter(func(a): return a["label"].begins_with("Pedir cita con el médico"))
	_check(cita.size() == 1, "CAP: no se puede pedir cita con el médico")
	if not cita.is_empty():
		cita[0]["do"].call()
	_check(gs.has_item("receta"), "CAP: el médico no hace receta")
	_check(world.interactions.for_poi(cap).all(func(a): return not a["label"].begins_with("Pedir cita")), "CAP: te hace otra receta el mismo día")
	var caja = world.interactions.for_poi(farmacia).filter(func(a): return a["label"].begins_with("Con la receta: antidepresivos"))
	_check(caja.size() == 1, "farmacia: no se compra con receta")
	if not caja.is_empty():
		caja[0]["do"].call()
	_check(gs.inventory.get("antidepresivos", 0) == Defs.RECETA["antidepresivos"]["cantidad"] and not gs.has_item("receta"), "farmacia: la receta no da la caja")
	var tabaco: int = gs.inventory.get("tabaco", 0)
	var maquina = world.interactions.for_poi(bar).filter(func(a): return a["label"].begins_with("Sacar tabaco"))
	_check(maquina.size() == 1, "bar: no hay máquina de tabaco")
	if not maquina.is_empty():
		maquina[0]["do"].call()
	_check(gs.inventory.get("tabaco", 0) == tabaco + Defs.PRECIOS["bar_tabaco"]["cantidad"], "bar: la máquina no da tabaco")
	# los bots también: alguno fuma, alguno toma ansiolíticos
	var habitos := {}
	for i in 300:
		habitos[C.habito("vecino", "Vecino %d" % i, {})] = true
		habitos[C.habito("fiestero", "Fiestero %d" % i, {})] = true
	for id in ["tabaco", "ansioliticos", "antidepresivos", "ketamina"]:
		_check(habitos.has(id), "consumo: ningún bot consume %s" % id)
	_steady(gs)
	gs.resacas = {}
	print("  sustancias nuevas y resacas: OK")


## Un bot nuevo del tipo `kind`, sin pasado contigo.
func _fresh(world, kind: String):
	var npc = world._spawn_npc(kind)  # (el último de npcs puede ser su perro o su grupo)
	npc.known = true
	return npc


## Los dos cuerpos de policía con sus competencias, la Urbana que te despierta si duermes a la
## vista, las secretas y la fauna nueva (estatuas, el grupo del guía, los que tienen cama).
func _test_police_and_fauna(gs, world) -> void:
	var city = world.city
	var player = world.player
	_steady(gs)
	gs.heat = 0.0
	gs.wanted_until = -1.0
	for npc in world.npcs:
		npc.calm_down()
	var line := _find_line(city, 7)
	if line.size() < 2:
		return
	var urbano = _fresh(world, "urbano")
	var mosso = _fresh(world, "mosso")
	# fichado por violencia: te persiguen los Mossos, no la Urbana; por drogas, los dos; por
	# civismo, solo la Urbana
	gs.mark_wanted("prueba", "violencia")
	_check(mosso.grudge() == "persigue" and urbano.grudge() == "", "fichado por violencia, persigue la Urbana o no los Mossos")
	gs.wanted_until = -1.0
	gs.wanted_crime = ""
	gs.mark_wanted("prueba", "drogas")
	_check(mosso.grudge() == "persigue" and urbano.grudge() == "persigue", "fichado por drogas, no te persiguen los dos")
	gs.wanted_until = -1.0
	gs.wanted_crime = ""
	gs.mark_wanted("prueba", "civismo")
	_check(urbano.grudge() == "persigue" and mosso.grudge() == "", "fichado por civismo, persiguen los Mossos o no la Urbana")
	# si te alcanza la Urbana por la ordenanza, multa; si te alcanzan los Mossos, comisaría
	var arrests: int = gs.arrests
	var fines: int = gs.fines
	world.police_caught(urbano)
	_check(gs.fines == fines + 1 and gs.arrests == arrests and not gs.is_wanted(), "la Urbana no multa (o detiene) por la ordenanza")
	world.police_caught(mosso)
	_check(gs.arrests == arrests + 1, "los Mossos no te detienen")
	_steady(gs)
	# dormir a la vista de la Urbana: te despierta y te echa
	_place(urbano, line[0], line[1])
	player.setup(city, line[1])
	var woken := 0
	for i in 40:
		if world.urbana_wakes("calle"):
			woken += 1
	_check(woken > 25, "un agente de la Urbana que te ve dormir no te despierta")
	urbano.setup(city, line[0])
	_place(urbano, line[0] + Vector2i(3, 0), line[1])  # de espaldas
	var hidden := Vector2i(-1, -1)
	for i in 4000:
		var c = city.random_walkable()
		if world.hidden_spot(c):
			hidden = c
			break
	_check(hidden.x >= 0, "no hay rincones escondidos para dormir")
	gs.advance(1)
	var milestones: int = gs.milestones.size()
	world.sleep(60, 0.0, 0.0, 0.5, "calle")
	world.sleep(60, 0.0, 0.0, 0.5, "")
	_check(gs.alive, "dormir con la Urbana cerca mata")
	# beber a la vista de la Urbana: multa
	_place(urbano, line[0], line[1])
	player.setup(city, line[1])
	fines = gs.fines
	gs.add_item("litrona")
	world.use_item("litrona")
	_check(gs.fines == fines + 1, "beber delante de la Urbana no trae multa")
	# la secreta: parece un guiri hasta que le intentas robar
	var sec = _fresh(world, "urbano_secreta")
	sec.known = false
	_check(sec.undercover() and sec.label().contains("Turista") and not sec.looks_police(), "la Urbana de paisano no parece un guiri")
	arrests = gs.arrests
	_steady(gs)
	_do(world, sec, "Robarle la cartera")
	_check(gs.arrests == arrests + 1 and sec.known, "robarle a la secreta no acaba en detención")
	_steady(gs)
	# la estatua no se mueve hasta que le echan una moneda
	var statue = _fresh(world, "estatua")
	var spot: Vector2i = statue.cell
	statue._idle = 0.0
	statue._process(0.5)
	_check(not statue.is_moving() and statue.cell == spot, "la estatua se mueve sola")
	gs.money = 10
	_do(world, statue, "Echarle una moneda en el platillo (1 €)")
	_check(statue._still_until > statue._clock(), "la estatua no se mueve con la moneda")
	# el guía sale con su grupo, y el grupo se va con él
	var guide = _fresh(world, "guia")
	var group: Array = world.npcs.filter(func(n): return n.amo == guide)
	_check(group.size() >= Defs.GUIDE_GROUP.x and group.all(func(n): return n.kind == "turista"), "el guía sale sin su grupo")
	_check(group[0].label().contains(guide.display_name), "el turista del grupo no dice de quién es")
	world.npcs.erase(guide)
	world._respawn()
	_check(world.npcs.filter(func(n): return n.amo == guide).is_empty(), "el grupo se queda sin guía")
	guide.queue_free()
	# el sin techo tiene dónde dormir; el punki, perro
	var homeless = _fresh(world, "mendigo")
	_check(homeless.bed.x >= 0 and city.is_walkable(homeless.bed), "el sin techo no tiene dónde dormir")
	var punk = _fresh(world, "punki")
	_check(world.npcs.any(func(n): return n.kind == "perro" and n.amo == punk), "el punki va sin perro")
	# los skaters, en el MACBA; las trabajadoras sexuales, en Robadors
	var macba = city.landmark_cell("MACBA")
	_check(macba.x >= 0 and _fresh(world, "skater").home.distance_to(macba) <= world.LANDMARK_RADIUS * 1.5, "los skaters no están en el MACBA")
	# la ronda de la policía y las secretas que se llevan a un carterista
	world.police_event()
	_check(world.npcs.filter(func(n): return n.kind == "mosso_secreta").all(func(n): return n.undercover() or n.known), "una secreta de los Mossos va de uniforme")
	gs.wanted_until = -1.0
	gs.heat = 0.0
	print("  policía y fauna: OK (%d multas, %d hitos nuevos)" % [gs.fines, gs.milestones.size() - milestones])


## Pone a `npc` en `at` mirando hacia `toward`.
func _place(npc, at: Vector2i, toward: Vector2i) -> void:
	npc.setup(npc.city, at)
	npc.calm_down()
	npc._calm_until = 0.0
	var d := Vector2(toward - at)
	npc._body.rotation.y = atan2(d.x, d.y)


## Ejecuta la acción de menú `label` con `npc`.
func _do(world, npc, label: String) -> void:
	for a in world.interactions.for_npc(npc):
		if a["label"] == label:
			a["do"].call()
			return
	_check(false, "%s: no tiene la acción «%s»" % [npc.kind, label])


## Dos casillas de una calle recta (`n` casillas libres en horizontal entre ellas).
func _find_line(city, n: int) -> Array:
	for y in city.height:
		for x in city.width - n:
			var ok := true
			for k in n + 1:
				if not city.is_walkable(Vector2i(x + k, y)) or not city.is_walkable(Vector2i(x + k, y + 1)) or not city.is_walkable(Vector2i(x + k, y - 1)):
					ok = false
					break
			if ok:
				return [Vector2i(x, y), Vector2i(x + n, y)]
	return []


## Dos casillas de calle cercanas (a 3–5 casillas) con un edificio en medio.
func _find_wall(city) -> Array:
	for y in range(2, city.height - 6):
		for x in range(2, city.width - 6):
			var a := Vector2i(x, y)
			if not city.is_walkable(a):
				continue
			for d in [Vector2i(4, 0), Vector2i(0, 4), Vector2i(3, 3), Vector2i(5, 0), Vector2i(0, 5)]:
				var b: Vector2i = a + d
				if city.is_walkable(b) and not city.line_of_sight(a, b):
					return [a, b]
	return []
## Objetos de la calle: se recogen, ido se confunden (basura que parece un móvil, y al revés)
## y las piedras se descubren al venderlas o al volver a estar sereno.
func _test_street_items(gs, world) -> void:
	var si = world.street_items
	_steady(gs)
	for id in gs.subs:
		gs.subs[id]["high"] = 0.0
	_check(si.items.size() == Defs.STREET_ITEMS_COUNT, "no hay objetos por la calle")
	_check(si.items.any(func(it): return it.id != "basura"), "en la calle solo hay basura")
	var by_id := {}
	for it in si.items:
		by_id[it.id] = it
	# sereno, cada cosa es lo que parece
	si._refresh()
	_check(si.items.all(func(it): return it.seen_as == it.id), "sereno, confundes lo que ves")
	for id in Defs.STREET_ITEMS:
		if not by_id.has(id):
			si._spawn(0)
			si.items[-1].id = id
			by_id[id] = si.items[-1]
		var it = by_id[id]
		it.show_as(id)
		var had: int = gs.inventory.get(id, 0)
		si.pick_up(it)
		_check(gs.inventory.get(id, 0) == had + 1, "al recoger %s no va al inventario" % id)
		_check(not it in si.items, "%s sigue en el suelo tras recogerlo" % id)
	# del todo ido, una basura con la tirada baja parece un móvil y te la llevas
	gs.subs[gs.subs.keys()[0]]["high"] = 200.0
	_check(gs.befuddlement() >= 1.0, "con 200 de colocón no vas ido")
	si._spawn(0)
	var junk = si.items[-1]
	junk.id = "basura"
	junk.decoy = "movil"
	junk.roll = 0.0
	si._refresh()
	_check(junk.seen_as == "movil", "ido, la basura no parece un móvil")
	_check(si.label(junk).begins_with("Móvil"), "el rótulo no dice lo que crees ver")
	var moviles: int = gs.inventory.get("movil", 0)
	si.pick_up(junk)
	_check(gs.inventory.get("movil", 0) == moviles + 1 and gs.fakes.get("movil", 0) == 1, "la piedra no entra como móvil")
	# un móvil de verdad, ido, parece basura
	si._spawn(0)
	var real = si.items[-1]
	real.id = "movil"
	real.roll = 0.0
	si._refresh()
	_check(real.seen_as == "basura", "ido, un móvil no parece basura")
	# venderla en el compraventa: siempre descubres la piedra si solo te queda esa
	for id in gs.inventory.keys():
		if id == "movil":
			gs.inventory[id] = 1
	gs.fakes["movil"] = 1
	var money: int = gs.money
	var shop: Dictionary = world.city.pois_of_kind("compraventa")[0]
	for a in world.interactions.for_poi(shop):
		if a["label"].begins_with("Vender móvil ("):
			a["do"].call()
	_check(gs.money == money and not gs.fakes.has("movil") and not gs.has_item("movil"), "el compraventa te compra una piedra")
	_check("piedra" in gs.milestones, "vender una piedra no es un hito")
	# sereno otra vez, descubres las que te queden
	var carteras: int = gs.inventory.get("cartera", 0)
	gs.add_item("cartera", 2)
	gs.fakes["cartera"] = 1
	gs.subs[gs.subs.keys()[0]]["high"] = 0.0
	si._next_refresh = 0.0
	si.update()
	_check(not gs.fakes.has("cartera") and gs.inventory.get("cartera", 0) == carteras + 1, "sereno, no descubres la cartera falsa")
	world._update_hover()
	print("  objetos de la calle: OK (%d en el suelo)" % si.items.size())


## Trapicheo: vender a clientes (que pagan más si repiten), cortarla (y que no te vuelvan a
## comprar), el guiri secreta, el camello al que le pisas la esquina y el trueque con yonkis.
func _test_trade(gs, world) -> void:
	var trade = world.trade
	_steady(gs)
	gs.alive = true
	var client = _npc_of(world, "fiestero")
	client.memory = {}
	client.money = 1000
	client.consumo = {}  # (sin mono que le haga pagar más: se prueba lo de repetir)
	gs.add_item("farlopa", 3)
	var p0: int = trade.price_for(client, "farlopa")
	_check(p0 > Defs.SUBSTANCES["farlopa"]["price"], "la despedida no paga más que el camello")
	var sell = world.interactions.for_npc(client).filter(func(a): return a["label"].begins_with("Venderle farlopa ("))
	_check(sell.size() == 1, "no se le puede vender farlopa a una despedida")
	var money: int = gs.money
	var coke: int = gs.inventory.get("farlopa", 0)
	trade.sell(client, "farlopa", false)
	_check(gs.money == money + p0 and gs.inventory.get("farlopa", 0) == coke - 1, "vender no paga o no gasta la dosis")
	_check(client.remembers("cliente") == 1 and client.grudge() == "acerca", "el cliente no se acuerda de ti")
	_check(trade.price_for(client, "farlopa") > p0, "el cliente que repite no paga más")
	trade.sell(client, "farlopa", true)
	_check(client.remembers("timado") == 1 and client.grudge() in ["venganza", "aparta"], "cortarla no tiene consecuencias")
	_check(trade.offers_for(client).is_empty(), "el timado te sigue comprando")
	# el camello que te ha visto vender en su esquina
	var dealer = _npc_of(world, "camello")
	dealer.memory = {}
	dealer.debt = 0
	dealer.remember("pisado")
	_check(dealer.grudge() == "territorio", "el camello no se toma a mal que vendas en su esquina")
	gs.add_item("porro", 2)
	dealer.chase_reason = "territorio"
	world._on_caught(dealer)
	_check(not gs.has_item("porro") and dealer.remembers("pisado") == 0, "el camello no se cobra la esquina")
	# trueque con un yonki: un móvil por lo que lleve encima; una piedra, no
	var yonki = _npc_of(world, "yonki")
	yonki.memory = {}
	var s: Dictionary = trade.stash(yonki)
	s["n"] = 2
	gs.fakes = {}
	gs.add_item("movil")
	var swaps = trade.offers_for(yonki).filter(func(a): return a["label"].begins_with("Cambiarle tu móvil"))
	_check(swaps.size() == 1, "el yonki no te cambia el móvil")
	var had: int = gs.inventory.get(s["id"], 0)
	var moviles: int = gs.inventory.get("movil", 0)
	if not swaps.is_empty():
		swaps[0]["do"].call()
	_check(gs.inventory.get(s["id"], 0) > had and gs.inventory.get("movil", 0) == moviles - 1, "el trueque no cambia nada")
	s["n"] = 2
	for id in gs.inventory.keys():
		if id == "movil":
			gs.remove_item(id, gs.inventory[id])
	gs.add_item("movil")
	gs.fakes["movil"] = 1
	trade.swap(yonki, "movil")
	_check(yonki.remembers("timado") == 1 and not gs.has_item("movil"), "al yonki se le cuela una piedra")
	# un guiri secreta: venderle es acabar detenido
	var guiri = _npc_of(world, "turista")
	var i := 0
	while not trade.undercover(guiri) and i < 2000:
		i += 1
		guiri.display_name = "Prueba %d" % i
	_check(trade.undercover(guiri), "no hay guiris secretas")
	guiri.memory = {}
	guiri.money = 1000
	gs.add_item("porro")
	var arrests: int = gs.arrests
	trade.sell(guiri, "porro", false)
	_check(gs.arrests == arrests + 1 and "secreta" in gs.milestones, "venderle a un secreta no acaba en detención")
	print("  trapicheo: OK (farlopa a %d €, el yonki lleva %s)" % [p0, s["id"]])


func _npc_of(world, kind: String):
	var of_kind = world.npcs.filter(func(n): return n.kind == kind and is_instance_valid(n))
	if of_kind.is_empty():
		world._spawn_npc(kind)
		return world.npcs[-1]
	return of_kind[0]


## Deja el cuerpo en calma para que una prueba no dispare otra consecuencia por el camino.
func _steady(gs) -> void:
	gs.alive = true
	gs.health = 100.0
	gs.hunger = 0.0
	gs.fatigue = 0.0
	gs.sanity = 100.0
	for id in gs.subs:
		gs.subs[id]["mono"] = 0.0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FALLO: " + what)
