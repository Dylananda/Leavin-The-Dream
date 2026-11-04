extends SceneTree
## Capturas del relevo, para revisarlo sin jugar: la pantalla final de Paco con los botones
## para seguir con otro (<salida>_final.png) y, tras el relevo, Don Ramón junto al altar de
## Paco con lo que dice el registro (<salida>_altar.png).
## Uso: godot --path game --resolution 1600x900 --script res://tests/relevo_captura.gd -- <salida.png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://relevo.png"
	load("res://scripts/partida.gd").automatico = false
	var gs = root.get_node("GameState")
	gs.new_game("parado")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var w = current_scene
	for i in 30:
		await process_frame
	gs.subs = {}
	gs.change_health(-500, "Te encontraron una mañana en un portal de la calle Robadors")
	await _captura(out.replace(".png", "_final.png"))
	w.relevo("jubilado")
	# Don Ramón va a ver el altar
	var altar: Dictionary = w.city.pois_of_kind("altar")[0]
	var en := Vector2i(altar["x"], altar["y"])
	w.player.setup(w.city, w.city.nearest_walkable(en + Vector2i(-1, -1)))
	w._camera_focus = w.player.position
	w._camera_zoom = 14.0
	for i in 40:
		await process_frame
	await _captura(out.replace(".png", "_altar.png"))
	quit()


func _captura(path: String) -> void:
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
