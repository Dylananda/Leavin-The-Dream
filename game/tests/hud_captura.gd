extends SceneTree
## Captura del mapa del barrio o del panel de pausa, para revisarlos sin jugar.
## Uso: godot --path game --resolution 1600x900 --script res://tests/hud_captura.gd -- <salida.png> mapa|pausa [rótulo]

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
	if what == "pausa":
		w.hud.toggle_pause()
	else:
		w.hud.toggle_map()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
