extends SceneTree
## Captura del mapa del barrio, del panel de pausa o del menú de un camello (abierto dos
## veces, con mucho en el bolsillo: el menú largo), para revisarlos sin jugar.
## Uso: godot --path game --resolution 1600x900 --script res://tests/hud_captura.gd -- <salida.png> mapa|pausa|menu [rótulo]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://hud.png"
	var what := args[1] if args.size() > 1 else "mapa"
	var place := args[2] if args.size() > 2 else "MACBA"
	root.get_node("GameState").new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var w = current_scene
	for l in w.city._data["labels"]:
		if place in l["text"]:
			w.player.setup(w.city, w.city.world_to_cell(Vector3(l["x"], 0, l["z"])))
			w._camera_focus = w.player.position
			break
	for i in 30:
		await process_frame
	if what == "menu":
		var gs = root.get_node("GameState")
		gs.money = 500
		for id in Defs.SUBSTANCES:
			gs.add_item(id, 3)
		var camello = w.npcs.filter(func(n): return n.kind == "camello")
		if camello.is_empty():
			camello = w.npcs
		var acts: Array = w.interactions.for_npc(camello[0])
		for i in 30:  # que no quepa en la pantalla, haya o no camello cerca
			acts.append({"label": "Acción de relleno %d" % (i + 1), "do": func(): pass})
		w.hud.show_menu("Camello", acts)
		await process_frame
		w.hud._menu_scroll.scroll_vertical = 400  # bajar con la rueda, cerrar y volver a abrir
		w.hud.close_menu()
		w.hud.show_menu("Camello", acts)
	elif what == "pausa":
		w.hud.toggle_pause()
	else:
		w.hud.toggle_map()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
