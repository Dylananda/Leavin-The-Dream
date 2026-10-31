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
			if gs.alive:
				world.use_item(id)
		world._rummage()
		world._sleep_here()
		if gs.alive:
			world.arrest_player()
		print("  día %d, caída %d, dignidad %d, salud %d, vivo=%s, hitos=%s" % [
			gs.day, gs.caida, gs.dignity, gs.health, gs.alive, gs.milestones])
		get_root().get_tree().paused = false
	quit()
