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
	print("  conversación: OK sin IA (%d mensajes en el registro)" % logged.size())


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
