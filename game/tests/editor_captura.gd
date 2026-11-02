extends SceneTree
## Abre el editor de personajes y guarda una captura de cada pestaña. Para revisarlo sin abrirlo a mano.
## Uso: godot --path game --resolution 1600x900 --script res://tests/editor_captura.gd -- <salida.png> [id de personaje]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://editor.png"
	change_scene_to_file("res://editor/editor_personajes.tscn")
	await process_frame
	await process_frame
	var ed = current_scene
	if args.size() > 1:
		ed._editar(Personajes.cargar(Personajes.DIR + args[1] + ".json"), args[1])
	var tabs: TabContainer = ed.find_children("*", "TabContainer", true, false)[0]
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		for f in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
	quit()
