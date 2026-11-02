extends SceneTree
## Paseo por el barrio para probar el censo (scripts/censo.gd): lleva al jugador a varios
## sitios lejanos, espera y cuenta cuántos bots tienen cuerpo, cuántos están latentes y los FPS.
## Con `multiplica`, el censo tiene esas veces más gente (para ver cuánta aguanta).
## Uso: godot --path game --resolution 1600x900 --script res://tests/paseo.gd -- [multiplica]

const SITIOS := ["MACBA", "Liceu", "Sant Pau del Camp", "Colom", "CCCB", "La Boqueria", "Antic Hospital", "Filmoteca"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mult := int(args[0]) if args.size() > 0 else 1
	root.get_node("GameState").new_game("parado")
	root.get_node("GameState").minute_of_day = 12 * 60.0
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var w = current_scene
	for i in mult - 1:
		for kind in w.BASE_NPCS:
			if w.censo.activo({"kind": kind, "personaje": {}}, 12):  # (sin Npc: el script se compila antes del autoload)
				for j in w._npc_targets[kind]:
					w.censo.nuevo(kind)
	var t0 := Time.get_ticks_msec()
	w.censo.repasar()
	print("repaso inicial: %d ms" % (Time.get_ticks_msec() - t0))
	for sitio in SITIOS:
		for l in w.city._data["labels"]:
			if sitio in l["text"]:
				w.player.setup(w.city, w.city.world_to_cell(Vector3(l["x"], 0, l["z"])))
				w._camera_focus = w.player.position
				break
		var frames := 0
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 3000:
			await process_frame
			frames += 1
		var t1 := Time.get_ticks_usec()
		w.censo.repasar(w.censo.MAX_DESPERTAR, w.censo.TANDA)
		var repaso_ms := (Time.get_ticks_usec() - t1) / 1000.0
		var n: int = w.censo.registros.size()
		print("  (un repaso con todo despierto: %.2f ms)" % repaso_ms)
		print("%-18s %4d con cuerpo (%3d bots en escena)  %5d latentes  %5.1f FPS" % [
			sitio, n - w.censo.latentes(), w.npcs.size(), w.censo.latentes(), frames / 3.0])
	quit()
