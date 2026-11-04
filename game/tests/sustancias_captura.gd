extends SceneTree
## Abre el diseñador de sustancias y guarda una captura de cada pestaña. Para revisarlo sin abrirlo a mano.
## Uso: godot --path game --resolution 1600x900 --script res://tests/sustancias_captura.gd -- <salida.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://sustancias.png"
	change_scene_to_file("res://editor/editor_sustancias.tscn")
	await process_frame
	await process_frame
	var ed = current_scene
	# un retoque de muestra (sin guardar), para ver cómo se marca
	ed._retocar("sustancias", "speed", "price", 9.0)
	ed._construir()
	var tabs: TabContainer = ed._tabs
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		for f in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
	quit()
