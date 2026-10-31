extends SceneTree
## Lanza una escena, espera unos frames y guarda capturas. Para revisar el aspecto sin abrir el editor.
## Uso: godot --path game --script res://tests/screenshot.gd -- <escena> <salida.png> [perfil] [sitio] [hora] [sustancias]
## `sustancias` (separadas por comas) se consumen antes de la captura, para ver sus efectos.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/world.tscn"
	var out := args[1] if args.size() > 1 else "user://shot.png"
	var profile := args[2] if args.size() > 2 else "parado"
	var place := args[3] if args.size() > 3 else ""
	var hour := float(args[4]) if args.size() > 4 else -1.0
	var take := args[5].split(",", false) if args.size() > 5 else PackedStringArray()
	root.get_node("GameState").new_game(profile)
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	if place != "":
		# coloca al jugador junto a un rótulo (monumento) cuyo texto contenga `place`
		var w := current_scene
		for l in w.city._data["labels"]:
			if place in l["text"]:
				w.player.setup(w.city, w.city.world_to_cell(Vector3(l["x"], 0, l["z"])))
				w._camera_focus = w.player.position
				break
	if hour >= 0.0:
		root.get_node("GameState").minute_of_day = hour * 60.0
	for id in take:
		root.get_node("GameState").add_item(id)
		root.get_node("GameState").consume(id, true)
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	# segunda captura más alejada para ver el barrio
	var world := current_scene
	if world.get("camera"):
		world._camera_zoom = 90.0
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_far.png"))
	quit()
