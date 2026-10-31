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
