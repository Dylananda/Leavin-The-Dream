extends SceneTree
## Prueba de humo: carga el barrio con cada perfil y ejecuta todas las acciones
## de todos los tipos de bot y de lugar, más el inventario. Falla si algo lanza error.
## Uso: godot --headless --path game --script res://tests/smoke.gd

func _initialize() -> void:
	var gs = root.get_node("GameState")
	for profile in Defs.PROFILES:
		gs.new_game(profile["id"])
		gs.money = 500
		change_scene_to_file("res://scenes/world.tscn")
		await process_frame
		await process_frame
		var world = current_scene
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
		if profile == Defs.PROFILES[0]:
			_test_vision(gs, world)
		_test_street_items(gs, world)
		_test_trade(gs, world)
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
		gs.sanity = 0.0
		gs.advance(1)
		_check(gs.sanity > 0.0 and "psiquiatrico" in gs.milestones, "la salud mental a 0 no acaba en ingreso")
		await process_frame
		print("  día %d, caída %d, dignidad %d, salud %d, hambre %d, sueño %d, mente %d, vivo=%s, hitos=%s" % [
			gs.day, gs.caida, gs.dignity, gs.health, gs.hunger, gs.fatigue, gs.sanity, gs.alive, gs.milestones])
		get_root().get_tree().paused = false
	print("FALLOS: %d" % _failures if _failures > 0 else "OK")
	quit(1 if _failures > 0 else 0)


var _failures := 0


## Conversación con IA sin depender de Ollama: contra un puerto en el que no escucha nadie
## (el juego debe seguir y avisar en el registro) y con una respuesta inventada que usa
## todas las acciones de juego.
## Género según el nombre, etiquetas en femenino y el mismo aspecto para el mismo nombre.
func _test_looks(world) -> void:
	var npc_script = load("res://scripts/actors/npc.gd")  # cargado aquí: usa los autoloads
	_check(Defs.PROFILES.filter(func(p): return p["name"] == "Mari Loli")[0]["look"]["gender"] == "f", "Mari Loli no es mujer")
	for npc in world.npcs:
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
		var npc = world.npcs.filter(func(n): return n.kind == kind and is_instance_valid(n))
		if npc.is_empty():
			world._spawn_npc(kind)
			npc = [world.npcs[-1]]
		npc = npc[0]
		npc.remove_meta("encargo_dia")
		npc.remove_meta("enemigo")
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
	_check(gs.notes.size() == 4 and gs.has_item("paquete") and gs.has_item("cartera_caliente"), "no se apuntan los encargos o no te dan lo que hay que llevar")
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
	# fallar por el plazo: la cartera y la cita con la educadora
	gs.alive = true
	for id in ["cartera", "cita"]:
		errands.active(id)["until"] = gs.now() - 1.0
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
	var cop = world.npcs.filter(func(n): return n.kind == "policia")[0]
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
	var police: Array = world.npcs.filter(func(n): return n.kind == "policia")
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


## Un bot nuevo del tipo `kind`, sin pasado contigo.
func _fresh(world, kind: String):
	world._spawn_npc(kind)
	var npc = world.npcs[-1]
	npc.known = true
	return npc


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
